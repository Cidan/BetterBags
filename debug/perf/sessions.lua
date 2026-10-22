local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Perf: AceModule
local perf = addon:GetModule('Perf')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Context: AceModule
local context = addon:GetModule('Context')

-- PerfSessions starts and stops profiler captures and keeps the finished sessions in the
-- BetterBagsPerfDB SavedVariable. That variable is separate from the AceDB profile so
-- profile resets and copies never touch it. Whether a capture is running is never saved:
-- every load starts with profiling off, except for the one-shot "capture next reload".
---@class PerfSessions: AceModule
---@field db table
---@field pendingMeta table|nil
---@field _logoutHooked boolean|nil
local perfSessions = addon:NewModule('PerfSessions')

perfSessions.DEFAULTS = {
  preset = 'full',
  excludedModules = 'Debug, Localization',
  maxSessions = 10,
  maxNodes = 5000,
  worstFrames = 10,
  spikeThresholdMs = 16,
  timelineFrames = 18000,
  maxDurationSec = 0,
  trackAllocations = false,
  pauseGC = false,
  calibrate = true,
  traceCalls = true,
  traceArgs = true,
  traceMaxCalls = 1000000,
}

perfSessions.LIMITS = {
  maxSessions = { 1, 50 },
  maxNodes = { 500, 50000 },
  worstFrames = { 0, 50 },
  spikeThresholdMs = { 1, 1000 },
  timelineFrames = { 0, 216000 },
  maxDurationSec = { 0, 3600 },
  traceMaxCalls = { 10000, 2000000 },
}

-- The pipeline preset covers everything between a bag event and the finished draw:
-- event dispatch, the refresh queue, the data sweep, and the render.
perfSessions.PRESETS = {
  full = {
    label = 'Everything',
  },
  pipeline = {
    label = 'Data and draw pipeline',
    modules = {
      'Events', 'Async', 'Bucket', 'Refresh', 'ItemLoader', 'Items', 'Search', 'QueryParser',
      'Categories', 'Groups', 'EquipmentSets', 'TooltipScanner', 'Stacks', 'Binding', 'Sort',
      'Database', 'Views', 'BagFrame', 'ItemFrame', 'ItemRowFrame', 'SectionFrame', 'Grid',
      'BackpackBehavior', 'BankBehavior', 'Render', 'Window', 'Sonata', 'SonataElements',
      'SonataDecoration', 'BagCanvas', 'SearchBox', 'Masque', 'Pawn',
      'SimpleItemLevel', 'Pool', 'Currency', 'MoneyFrame', 'BagSlots', 'BankSlots',
    },
    prototypes = {
      'Bag', 'Backpack', 'Bank', 'Item', 'ItemRow', 'Section', 'GridFrame', 'View', 'SlotInfo',
      'Stack', 'PoolItem', 'IntervalTree', 'SearchBoxFrame', 'TabFrame', 'Header', 'Money',
      'BagSlotsPanel', 'BankSlotsPanel', 'BankSlotButton', 'CurrencyIconGrid',
      'WindowFrame', 'ScrollboxFrame', 'BagCanvasFrame', 'SonataWindowDecoration',
    },
  },
}

perfSessions.PRESET_ORDER = { 'full', 'pipeline' }

local function send(event, ...)
  events:SendMessage(context:New('PerfSessions'), event, ...)
end

local function profilerAvailable()
  return C_AddOnProfiler ~= nil and C_AddOnProfiler.GetAddOnMetric ~= nil
    and Enum ~= nil and Enum.AddOnProfilerMetric ~= nil
    and (C_AddOnProfiler.IsEnabled == nil or C_AddOnProfiler.IsEnabled())
end

local function blizzardMetrics()
  if not profilerAvailable() then return nil end
  local out = {}
  for name, metric in pairs(Enum.AddOnProfilerMetric) do
    out[name] = C_AddOnProfiler.GetAddOnMetric(addonName, metric)
  end
  return out
end

-- LastTime is "total time in the most recent tick"; read at our frame boundary it is the
-- addon profiler's view of a whole frame of BetterBags work, including code the wrappers
-- cannot see.
local function blizzardFrameMetric()
  if not profilerAvailable() then return nil end
  local metric = Enum.AddOnProfilerMetric.LastTime
  return function()
    return C_AddOnProfiler.GetAddOnMetric(addonName, metric)
  end
end

-- frameSeries are Blizzard's per-frame readings for all addons and for the whole client
-- (GetOverallMetric, GetApplicationMetric: LastTime), recorded beside BetterBags' own so a
-- slow frame shows whose it was.
local function frameSeries()
  if not profilerAvailable() then return nil end
  local metric = Enum.AddOnProfilerMetric.LastTime
  local series = {}
  if C_AddOnProfiler.GetOverallMetric then
    series.all = function() return C_AddOnProfiler.GetOverallMetric(metric) end
  end
  if C_AddOnProfiler.GetApplicationMetric then
    series.app = function() return C_AddOnProfiler.GetApplicationMetric(metric) end
  end
  return next(series) and series or nil
end

-- topAddons lists the addons with the slowest single tick since the client started
-- (PeakTime), slowest first.
local function topAddons()
  if not profilerAvailable() or C_AddOnProfiler.GetTopKAddOnsForMetric == nil then return nil end
  local out = {}
  for _, r in ipairs(C_AddOnProfiler.GetTopKAddOnsForMetric(Enum.AddOnProfilerMetric.PeakTime, 10) or {}) do
    table.insert(out, { name = r.addOnName, ms = r.metricValue })
  end
  return out
end

-- restrictionStates reads every addon restriction type's state (C_RestrictedActions, 12.x:
-- combat, encounters, Mythic+, PvP, and the maps of dungeons and raids), by name.
---@return table<string, string>?
function perfSessions:RestrictionStates()
  local api = _G.C_RestrictedActions
  local types = Enum and Enum.AddOnRestrictionType
  local states = Enum and Enum.AddOnRestrictionState
  if api == nil or api.GetAddOnRestrictionState == nil or types == nil or states == nil then
    return nil
  end
  local names = {}
  for name, value in pairs(states) do
    names[value] = name
  end
  local out = {}
  for name, value in pairs(types) do
    local state = api.GetAddOnRestrictionState(value)
    out[name] = names[state] or tostring(state)
  end
  return out
end

-- COLLECTION_EVENTS are the pet journal's, the appearance collection's and the toy box's: recorded
-- during a capture with the collections' counts at that moment, so a capture shows when each has
-- loaded against the bag reads. BetterBags does not listen to them otherwise.
perfSessions.COLLECTION_EVENTS = {
  'PET_JOURNAL_LIST_UPDATE', 'NEW_PET_ADDED', 'PET_JOURNAL_PET_DELETED',
  'TRANSMOG_COLLECTION_UPDATED', 'TRANSMOG_COLLECTION_SOURCE_ADDED', 'TRANSMOG_COLLECTION_SOURCE_REMOVED',
  'NEW_TOY_ADDED', 'TOYS_UPDATED',
}

-- DIAGNOSTICS is a diagnostics run (ArmDiagnostics): the loads it captures, how long after entering
-- the world each capture stops, and how often it samples (TakeSample).
perfSessions.DIAGNOSTICS = { loads = 2, stopAfterSec = 60, sampleEverySec = 0.25 }

-- SAMPLE_EVENTS change what a diagnostics capture samples (the player values and the items'
-- usability), so it samples when they fire too; the collection events do as well.
perfSessions.SAMPLE_EVENTS = {
  'LOADING_SCREEN_DISABLED', 'PLAYER_SPECIALIZATION_CHANGED', 'SKILL_LINES_CHANGED', 'PLAYER_LEVEL_UP',
  'PLAYER_AVG_ITEM_LEVEL_UPDATE', 'SPELLS_CHANGED', 'PLAYER_EQUIPMENT_CHANGED',
}

-- serialize writes a value with sorted keys, so two equal states compare equal.
---@param value any
---@return string
local function serialize(value)
  if type(value) ~= 'table' then
    return tostring(value)
  end
  local keys = {}
  for k in pairs(value) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for _, k in ipairs(keys) do
    parts[#parts + 1] = tostring(k) .. '=' .. serialize(value[k])
  end
  return '{' .. table.concat(parts, ',') .. '}'
end

-- CollectionCounts reads how many pets, toys and appearances the account has: pets and toys as
-- Blizzard's collection panels count them (C_PetJournal.GetNumPets, Blizzard_PetCollection.lua; the
-- toy box's learned and total counts, Blizzard_ToyBox.lua), appearances as the unfiltered
-- C_TransmogCollection.GetCategoryCollectedCount summed over every category but None (the wardrobe's
-- progress bar reads the filtered one, Blizzard_Wardrobe.lua). Nil when the client has none of them.
---@return table?
function perfSessions:CollectionCounts()
  local out = {}
  local pets = _G.C_PetJournal
  if pets and pets.GetNumPets then
    out.pets, out.petsOwned = pets.GetNumPets()
  end
  local toys = _G.C_ToyBox
  if toys and toys.GetNumTotalDisplayedToys and toys.GetNumLearnedDisplayedToys then
    out.toys, out.toysLearned = toys.GetNumTotalDisplayedToys(), toys.GetNumLearnedDisplayedToys()
  end
  local transmog = _G.C_TransmogCollection
  local categories = Enum and Enum.TransmogCollectionType
  if transmog and transmog.GetCategoryCollectedCount and categories then
    local collected = 0
    for _, category in pairs(categories) do
      if category ~= categories.None then
        collected = collected + (transmog.GetCategoryCollectedCount(category) or 0)
      end
    end
    out.appearances = collected
  end
  if next(out) == nil then
    return nil
  end
  return out
end

-- instanceInfo says where the player is (GetInstanceInfo).
local function instanceInfo()
  if GetInstanceInfo == nil then return nil end
  local name, instanceType, difficultyID, difficultyName = GetInstanceInfo()
  return { name = name, instanceType = instanceType, difficultyID = difficultyID, difficultyName = difficultyName }
end

local function addonMemoryKB()
  if UpdateAddOnMemoryUsage == nil or GetAddOnMemoryUsage == nil then return nil end
  UpdateAddOnMemoryUsage()
  return GetAddOnMemoryUsage(addonName)
end

local function flavor()
  if addon.isForever then return 'forever' end
  if addon.isRetail then return 'retail' end
  return 'classic'
end

local function itemCount(kind)
  local items = addon:GetModule('Items', true)
  local slotInfo = items and items.slotInfo and items.slotInfo[kind]
  return slotInfo and slotInfo.totalItems or nil
end

function perfSessions:Init()
  local db = BetterBagsPerfDB
  if type(db) ~= 'table' then db = {} end
  db.version = 1
  db.capturing = nil
  if type(db.settings) ~= 'table' then db.settings = {} end
  for key, value in pairs(self.DEFAULTS) do
    if db.settings[key] == nil then db.settings[key] = value end
  end
  if type(db.sessions) ~= 'table' then db.sessions = {} end
  if type(db.nextId) ~= 'number' then
    local maxId = 0
    for _, session in ipairs(db.sessions) do
      if type(session.id) == 'number' and session.id > maxId then maxId = session.id end
    end
    db.nextId = maxId + 1
  end
  BetterBagsPerfDB = db
  self.db = db
  self.pendingMeta = nil

  if not self._eventsHooked then
    self._eventsHooked = true
    events:RegisterEvent('PLAYER_LOGOUT', function()
      self:OnLogout()
    end)
    events:RegisterEvent('PLAYER_ENTERING_WORLD', function(_, _, isInitialLogin, isReloadingUi)
      self:OnEnteringWorld(isInitialLogin, isReloadingUi)
      self:TakeSample('PLAYER_ENTERING_WORLD')
    end)
    -- Listening is enough: the event dispatcher records each change, with its type and
    -- state, as an "[event] ADDON_RESTRICTION_STATE_CHANGED" call in a capture's trace.
    if _G.C_EventUtils and _G.C_EventUtils.IsEventValid
      and _G.C_EventUtils.IsEventValid('ADDON_RESTRICTION_STATE_CHANGED') then
      events:RegisterEvent('ADDON_RESTRICTION_STATE_CHANGED', function() end)
    end
    -- The dispatcher records each as an "[event]" call; inside it, a "[collections]" call carries
    -- the counts, read only while a capture runs.
    for _, name in ipairs(self.COLLECTION_EVENTS) do
      if _G.C_EventUtils and _G.C_EventUtils.IsEventValid and _G.C_EventUtils.IsEventValid(name) then
        events:RegisterEvent(name, function()
          if perf:IsActive() then
            perf:Exit(perf:Enter('[collections]', self:CollectionCounts()))
          end
          self:TakeSample(name)
        end)
      end
    end
    for _, name in ipairs(self.SAMPLE_EVENTS) do
      if _G.C_EventUtils and _G.C_EventUtils.IsEventValid and _G.C_EventUtils.IsEventValid(name) then
        events:RegisterEvent(name, function()
          self:TakeSample(name)
        end)
      end
    end
    -- The first backpack read at login is the startup read: sample right after each.
    events:RegisterMessage('items/RefreshBackpack/Done', function()
      self:TakeSample('items/RefreshBackpack/Done')
    end)
  end
end

---@return table
function perfSessions:GetSettings()
  return self.db.settings
end

---@param key string
---@param value any
function perfSessions:SetSetting(key, value)
  local default = self.DEFAULTS[key]
  if default == nil then
    error('unknown profiler setting: ' .. tostring(key))
  end
  if type(default) == 'number' then
    value = tonumber(value) or default
    local limit = self.LIMITS[key]
    if limit then
      if value < limit[1] then value = limit[1] end
      if value > limit[2] then value = limit[2] end
    end
  elseif type(default) == 'boolean' then
    value = value == true
  elseif key == 'preset' then
    if not self.PRESETS[value] then value = default end
  else
    value = tostring(value or '')
  end
  self.db.settings[key] = value
  if key == 'maxSessions' then
    self:EnforceSessionLimit()
  end
  send('perf/SettingsChanged', key, value)
end

---@param text string
---@return string[]
local function parseNames(text)
  local names = {}
  for name in string.gmatch(text or '', '[^,%s]+') do
    names[#names + 1] = name
  end
  return names
end

---@return PerfOptions
function perfSessions:BuildOptions()
  local s = self.db.settings
  local preset = self.PRESETS[s.preset] or self.PRESETS.full
  return {
    modules = preset.modules,
    prototypes = preset.prototypes,
    includeRoot = true,
    exclude = parseNames(s.excludedModules),
    maxNodes = s.maxNodes,
    worstFrames = s.worstFrames,
    spikeThresholdMs = s.spikeThresholdMs,
    timelineFrames = s.timelineFrames,
    maxDurationSec = s.maxDurationSec,
    trackAllocations = s.trackAllocations,
    pauseGC = s.pauseGC,
    calibrate = s.calibrate,
    trace = s.traceCalls,
    traceArgs = s.traceArgs,
    traceMaxCalls = s.traceMaxCalls,
    frameMetric = blizzardFrameMetric(),
    frameSeries = frameSeries(),
    -- The engine asks once, on a frame, when the maximum duration passed or the call
    -- trace filled; the session records which.
    onAutoStop = function()
      self:StopCapture()
    end,
  }
end

---@return boolean
function perfSessions:IsCapturing()
  return perf:IsActive()
end

---@param reason? string "manual" (default), "startup" for a capture armed for the next load, or "simulate" for the event simulator's
---@param extra? table More metadata to save with the session (the simulation a capture records)
---@return boolean started
function perfSessions:StartCapture(reason, extra)
  if perf:IsActive() then return false end
  local gameVersion, gameBuild, _, tocVersion = GetBuildInfo()
  local meta = {
    reason = reason or 'manual',
    startedAt = time(),
    character = UnitName('player'),
    realm = GetRealmName(),
    gameVersion = gameVersion,
    gameBuild = gameBuild,
    tocVersion = tocVersion,
    flavor = flavor(),
    addonVersion = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, 'Version') or nil,
    preset = self.db.settings.preset,
    blizzardStart = blizzardMetrics(),
    memoryStartKB = addonMemoryKB(),
    luaMemoryStartKB = collectgarbage('count'),
    restrictionsStart = self:RestrictionStates(),
    collectionsStart = self:CollectionCounts(),
    instanceStart = instanceInfo(),
    topAddonsStart = topAddons(),
  }
  for key, value in pairs(extra or {}) do
    meta[key] = value
  end
  if not perf:Start(self:BuildOptions()) then
    return false
  end
  self.pendingMeta = meta
  local token = {}
  self.captureToken = token
  if meta.diagnostics then
    self.samples, self.lastSampleKey = {}, nil
    self:TakeSample('start', true)
    self:ScheduleSample(token)
  end
  send('perf/StateChanged', true)
  return true
end

-- ScheduleSample samples again in a quarter of a second, for as long as the capture of token runs.
---@param token table
function perfSessions:ScheduleSample(token)
  C_Timer.After(self.DIAGNOSTICS.sampleEverySec, function()
    if self.captureToken ~= token or not perf:IsActive() then return end
    self:TakeSample('tick')
    self:ScheduleSample(token)
  end)
end

-- TakeSample records, in a diagnostics capture, the collections' counts and what the item probe
-- samples (ItemProbe:Sample), with when (the capture's clock) and why; kept only when it differs
-- from the last sample, except at the start and the stop.
---@param why string
---@param always? boolean
function perfSessions:TakeSample(why, always)
  if not self.samples or not perf:IsActive() then return end
  local state = { collections = self:CollectionCounts() }
  local probe = addon:GetModule('ItemProbe', true)
  if probe and probe.Sample then
    local ok, sample = pcall(probe.Sample, probe)
    if ok then
      state.probe = sample
    else
      state.probeError = tostring(sample)
    end
  end
  local key = serialize(state)
  if always or key ~= self.lastSampleKey then
    table.insert(self.samples, { at = perf:ElapsedMs(), why = why, state = state })
    self.lastSampleKey = key
  end
end

---@return table|nil session
function perfSessions:StopCapture()
  local samples = self.samples
  if samples then
    self:TakeSample('stop', true)
  end
  self.samples, self.lastSampleKey, self.captureToken = nil, nil, nil
  local session = perf:Stop()
  if not session then return nil end
  session.samples = samples
  local meta = self.pendingMeta or {}
  self.pendingMeta = nil
  meta.stoppedAt = time()
  meta.blizzardStop = blizzardMetrics()
  meta.memoryStopKB = addonMemoryKB()
  meta.luaMemoryStopKB = collectgarbage('count')
  meta.restrictionsStop = self:RestrictionStates()
  meta.collectionsStop = self:CollectionCounts()
  meta.instanceStop = instanceInfo()
  meta.topAddonsStop = topAddons()
  meta.backpackItems = itemCount(0)
  meta.bankItems = itemCount(1)
  session.meta = meta
  session.id = self.db.nextId
  self.db.nextId = self.db.nextId + 1
  table.insert(self.db.sessions, session)
  self:EnforceSessionLimit()
  send('perf/StateChanged', false)
  send('perf/SessionsChanged')
  return session
end

function perfSessions:EnforceSessionLimit()
  local sessions = self.db.sessions
  local limit = self.db.settings.maxSessions
  while #sessions > limit do
    table.remove(sessions, 1)
  end
end

-- GetSessions lists the saved sessions, newest first.
---@return table[]
function perfSessions:GetSessions()
  local out = {}
  local sessions = self.db.sessions
  for i = #sessions, 1, -1 do
    out[#out + 1] = sessions[i]
  end
  return out
end

---@param id number
---@return table|nil
function perfSessions:GetSession(id)
  for _, session in ipairs(self.db.sessions) do
    if session.id == id then return session end
  end
  return nil
end

---@param id number
function perfSessions:DeleteSession(id)
  local sessions = self.db.sessions
  for i = #sessions, 1, -1 do
    if sessions[i].id == id then
      table.remove(sessions, i)
    end
  end
  send('perf/SessionsChanged')
end

function perfSessions:DeleteAllSessions()
  wipe(self.db.sessions)
  send('perf/SessionsChanged')
end

-- RemoveTrace deletes a session's call trace, the bulk of its size in SavedVariables, and
-- keeps everything else. Returns false when the session has no trace.
---@param id number
---@return boolean
function perfSessions:RemoveTrace(id)
  local session = self:GetSession(id)
  if not session or not session.trace then return false end
  session.trace = nil
  session.stats = session.stats or {}
  session.stats.traceRemoved = true
  send('perf/SessionsChanged')
  return true
end

function perfSessions:RemoveAllTraces()
  local removed = false
  for _, session in ipairs(self.db.sessions) do
    if session.trace then
      session.trace = nil
      session.stats = session.stats or {}
      session.stats.traceRemoved = true
      removed = true
    end
  end
  if removed then
    send('perf/SessionsChanged')
  end
end

---@param armed boolean
function perfSessions:SetArmedForNextReload(armed)
  self.db.armNextReload = armed and true or nil
  if not armed then
    self.db.armLoads = nil
  end
  send('perf/StateChanged', perf:IsActive())
end

---@return boolean
function perfSessions:IsArmedForNextReload()
  return self:GetArmedLoads() > 0
end

-- ArmDiagnostics arms a diagnostics run: the next DIAGNOSTICS.loads loads (a fresh login, then a
-- /reload) are each captured, sampled (TakeSample), and stopped on their own DIAGNOSTICS.stopAfterSec
-- after entering the world, so one play session answers every open in-game question.
function perfSessions:ArmDiagnostics()
  self.db.armNextReload = nil
  self.db.armLoads = self.DIAGNOSTICS.loads
  send('perf/StateChanged', perf:IsActive())
end

-- GetArmedLoads says how many of the next loads will be captured.
---@return number
function perfSessions:GetArmedLoads()
  if (self.db.armLoads or 0) > 0 then
    return self.db.armLoads
  end
  return self.db.armNextReload == true and 1 or 0
end

-- StartIfArmed consumes the one-shot "capture next reload" switch, or one load of a diagnostics
-- run. It applies to the next load, a full relaunch as much as a /reload; the capture is labeled
-- 'startup' until the first PLAYER_ENTERING_WORLD says which it was (OnEnteringWorld).
---@return boolean started
function perfSessions:StartIfArmed()
  if (self.db.armLoads or 0) > 0 then
    self.db.armLoads = self.db.armLoads - 1
    if self.db.armLoads == 0 then
      self.db.armLoads = nil
    end
    return self:StartCapture('startup', { diagnostics = true })
  end
  if self.db.armNextReload ~= true then return false end
  self.db.armNextReload = nil
  return self:StartCapture('startup')
end

-- OnEnteringWorld labels a capture armed for this load a 'login' or a 'reload'. Later
-- loading screens, and manual captures, keep their label.
---@param isInitialLogin boolean
---@param isReloadingUi boolean
function perfSessions:OnEnteringWorld(isInitialLogin, isReloadingUi)
  local meta = self.pendingMeta
  if not meta or meta.reason ~= 'startup' then return end
  if isInitialLogin then
    meta.reason = 'login'
  elseif isReloadingUi then
    meta.reason = 'reload'
  end
  -- A diagnostics capture stops on its own a while after entering the world (once: the label is
  -- set only once).
  if meta.diagnostics then
    local token = self.captureToken
    C_Timer.After(self.DIAGNOSTICS.stopAfterSec, function()
      if self.captureToken == token and perf:IsActive() then
        self:StopCapture()
      end
    end)
  end
end

function perfSessions:OnLogout()
  if perf:IsActive() then
    self:StopCapture()
  end
end
