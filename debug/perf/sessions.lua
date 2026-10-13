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
      'BackpackBehavior', 'BankBehavior', 'Themes', 'SearchBox', 'Masque', 'Pawn',
      'SimpleItemLevel', 'Pool', 'Currency', 'MoneyFrame', 'BagSlots', 'BankSlots',
    },
    prototypes = {
      'Bag', 'Backpack', 'Bank', 'Item', 'ItemRow', 'Section', 'GridFrame', 'View', 'SlotInfo',
      'Stack', 'PoolItem', 'IntervalTree', 'SearchBoxFrame', 'TabFrame', 'Header', 'Money',
      'BagSlotsPanel', 'BankSlotsPanel', 'BankSlotButton', 'CurrencyIconGrid',
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

---@param reason? string "manual" (default), or "startup" for a capture armed for the next load
---@return boolean started
function perfSessions:StartCapture(reason)
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
  }
  if not perf:Start(self:BuildOptions()) then
    return false
  end
  self.pendingMeta = meta
  send('perf/StateChanged', true)
  return true
end

---@return table|nil session
function perfSessions:StopCapture()
  local session = perf:Stop()
  if not session then return nil end
  local meta = self.pendingMeta or {}
  self.pendingMeta = nil
  meta.stoppedAt = time()
  meta.blizzardStop = blizzardMetrics()
  meta.memoryStopKB = addonMemoryKB()
  meta.luaMemoryStopKB = collectgarbage('count')
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
  send('perf/StateChanged', perf:IsActive())
end

---@return boolean
function perfSessions:IsArmedForNextReload()
  return self.db.armNextReload == true
end

-- StartIfArmed consumes the one-shot "capture next reload" switch. The switch applies to
-- the next load, a full relaunch as much as a /reload; the capture is labeled 'startup'
-- until the first PLAYER_ENTERING_WORLD says which it was (OnEnteringWorld).
---@return boolean started
function perfSessions:StartIfArmed()
  if not self:IsArmedForNextReload() then return false end
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
end

function perfSessions:OnLogout()
  if perf:IsActive() then
    self:StopCapture()
  end
end
