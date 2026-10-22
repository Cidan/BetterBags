-- perf_sessions_spec.lua -- Capture control and SavedVariables storage for the profiler
-- (debug/perf/sessions.lua).

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Earlier spec files stub or patch the shared Context and Events modules without restoring
-- them; these tests need real message delivery, so they load fresh copies.
LoadFreshBetterBagsModule("Context", "core/context.lua")
local events = LoadFreshBetterBagsModule("Events", "core/events.lua")

LoadBetterBagsModule("debug/perf/format.lua")
LoadFreshBetterBagsModule("PerfSessions", "debug/perf/sessions.lua")

local perf = addon:GetModule("Perf")
local perfSessions = addon:GetModule("PerfSessions")

describe("PerfSessions", function()
  local now
  local sent
  local registered
  local origSendMessage, origRegisterEvent

  before_each(function()
    now = 0
    _G.BetterBagsPerfDB = nil
    events:Init()
    sent = {}
    registered = {}
    origSendMessage = events.SendMessage
    origRegisterEvent = events.RegisterEvent
    events.SendMessage = function(_, _, event, ...)
      table.insert(sent, { event = event, args = { ... } })
    end
    events.RegisterEvent = function(_, event, fn)
      registered[event] = fn
    end
    perf:Init()
    perf:SetClock(function() return now end)
    perfSessions._eventsHooked = nil
    perfSessions:Init()
    -- Calibration needs a moving clock; these tests are about storage, not overhead.
    perfSessions:SetSetting("calibrate", false)
    sent = {}
  end)

  after_each(function()
    if perf:IsActive() then perf:Stop() end
    events.SendMessage = origSendMessage
    events.RegisterEvent = origRegisterEvent
    _G.C_AddOnProfiler = nil
  end)

  local function sentEvents()
    local names = {}
    for _, s in ipairs(sent) do names[#names + 1] = s.event end
    return names
  end

  describe("storage", function()
    it("creates BetterBagsPerfDB with default settings and no sessions", function()
      assert.is_table(_G.BetterBagsPerfDB)
      assert.are.same({}, _G.BetterBagsPerfDB.sessions)
      local settings = perfSessions:GetSettings()
      assert.are.equal(10, settings.maxSessions)
      assert.are.equal(5000, settings.maxNodes)
      assert.are.equal(10, settings.worstFrames)
      assert.are.equal(16, settings.spikeThresholdMs)
      assert.are.equal("full", settings.preset)
      assert.is_false(settings.trackAllocations)
      assert.is_false(settings.pauseGC)
    end)

    it("keeps saved sessions and settings across a reload", function()
      _G.BetterBagsPerfDB = {
        version = 1,
        settings = { maxSessions = 3 },
        sessions = { { id = 4, stats = {} } },
        nextId = 5,
      }
      perfSessions:Init()
      assert.are.equal(3, perfSessions:GetSettings().maxSessions)
      assert.are.equal(5000, perfSessions:GetSettings().maxNodes)
      assert.are.equal(4, perfSessions:GetSessions()[1].id)
    end)

    it("is declared as a SavedVariable in every TOC", function()
      local pipe = io.popen("ls *.toc")
      local count = 0
      for path in pipe:lines() do
        count = count + 1
        local f = assert(io.open(path, "r"))
        local declared
        for line in f:lines() do
          local list = line:match("^## SavedVariables:%s*(.-)%s*$")
          if list then declared = list end
        end
        f:close()
        assert.is_truthy(declared and declared:find("BetterBagsPerfDB", 1, true), path)
        assert.is_truthy(declared:find("BetterBagsDB", 1, true), path)
      end
      pipe:close()
      assert.are.equal(5, count)
    end)

    it("never resumes capturing on load, whatever was saved", function()
      _G.BetterBagsPerfDB = { version = 1, capturing = true, settings = {}, sessions = {} }
      perfSessions:Init()
      assert.is_false(perfSessions:IsCapturing())
      assert.is_false(perf:IsActive())
    end)
  end)

  describe("settings", function()
    it("clamps numeric settings to their limits", function()
      perfSessions:SetSetting("maxSessions", 500)
      assert.are.equal(50, perfSessions:GetSettings().maxSessions)
      perfSessions:SetSetting("maxNodes", 1)
      assert.are.equal(500, perfSessions:GetSettings().maxNodes)
      perfSessions:SetSetting("spikeThresholdMs", "33")
      assert.are.equal(33, perfSessions:GetSettings().spikeThresholdMs)
    end)

    it("rejects an unknown preset", function()
      perfSessions:SetSetting("preset", "bogus")
      assert.are.equal("full", perfSessions:GetSettings().preset)
      perfSessions:SetSetting("preset", "pipeline")
      assert.are.equal("pipeline", perfSessions:GetSettings().preset)
    end)

    it("errors on an unknown setting", function()
      assert.has_error(function() perfSessions:SetSetting("nope", 1) end)
    end)

    it("builds engine options from the settings", function()
      perfSessions:SetSetting("excludedModules", " Database,  Themes ,,Debug ")
      perfSessions:SetSetting("worstFrames", 3)
      perfSessions:SetSetting("trackAllocations", true)
      local options = perfSessions:BuildOptions()
      assert.are.same({ "Database", "Themes", "Debug" }, options.exclude)
      assert.are.equal(3, options.worstFrames)
      assert.is_true(options.trackAllocations)
      assert.is_nil(options.modules)
      perfSessions:SetSetting("preset", "pipeline")
      options = perfSessions:BuildOptions()
      assert.is_table(options.modules)
      assert.is_table(options.prototypes)
    end)

    it("trims stored sessions immediately when the session limit is lowered", function()
      for _ = 1, 4 do
        perfSessions:StartCapture("manual")
        perfSessions:StopCapture()
      end
      perfSessions:SetSetting("maxSessions", 2)
      local sessions = perfSessions:GetSessions()
      assert.are.equal(2, #sessions)
      assert.are.equal(4, sessions[1].id)
      assert.are.equal(3, sessions[2].id)
    end)
  end)

  describe("capturing", function()
    it("starts and stops a capture and saves the session with metadata", function()
      assert.is_true(perfSessions:StartCapture("manual"))
      assert.is_true(perfSessions:IsCapturing())
      now = 1234
      local session = perfSessions:StopCapture()
      assert.is_false(perfSessions:IsCapturing())
      assert.are.equal(1, session.id)
      assert.are.equal("manual", session.meta.reason)
      assert.are.equal("TestChar", session.meta.character)
      assert.are.equal("TestRealm", session.meta.realm)
      assert.are.equal("10.0.0", session.meta.gameVersion)
      assert.is_number(session.meta.startedAt)
      assert.are.equal(1234, session.stats.durationMs)
      assert.are.equal(session, perfSessions:GetSession(1))
      assert.are.same({ "perf/StateChanged", "perf/StateChanged", "perf/SessionsChanged" }, sentEvents())
    end)

    it("refuses to start twice", function()
      assert.is_true(perfSessions:StartCapture("manual"))
      assert.is_false(perfSessions:StartCapture("manual"))
    end)

    it("returns nil when stopping with nothing running", function()
      assert.is_nil(perfSessions:StopCapture())
    end)

    it("drops the oldest sessions past the session limit", function()
      perfSessions:SetSetting("maxSessions", 2)
      for _ = 1, 3 do
        perfSessions:StartCapture("manual")
        perfSessions:StopCapture()
      end
      local sessions = perfSessions:GetSessions()
      assert.are.equal(2, #sessions)
      assert.are.equal(3, sessions[1].id)
      assert.are.equal(2, sessions[2].id)
    end)

    it("saves a running capture on logout", function()
      perfSessions:StartCapture("manual")
      assert.is_function(registered["PLAYER_LOGOUT"])
      registered["PLAYER_LOGOUT"]()
      assert.is_false(perf:IsActive())
      assert.are.equal(1, #perfSessions:GetSessions())
    end)

    it("stops on its own once the maximum duration passes", function()
      perfSessions:SetSetting("maxDurationSec", 5)
      perfSessions:StartCapture("manual")
      now = 6000
      perf:_OnFrame()
      assert.is_false(perf:IsActive())
      assert.are.equal(1, #perfSessions:GetSessions())
      assert.are.equal("maxDuration", perfSessions:GetSessions()[1].stats.stopReason)
    end)

    it("records a call trace with arguments by default", function()
      local settings = perfSessions:GetSettings()
      assert.is_true(settings.traceCalls)
      assert.is_true(settings.traceArgs)
      assert.are.equal(1000000, settings.traceMaxCalls)
      perfSessions:StartCapture("manual")
      local token = perf:Enter("[event] TEST", 1)
      perf:Exit(token)
      local session = perfSessions:StopCapture()
      local trace = addon:GetModule("PerfFormat"):OpenTrace(session)
      local event
      for i = 1, trace:Count() do
        if trace:Get(i).name == "[event] TEST" then event = trace:Get(i) end
      end
      assert.is_not_nil(event)
      assert.are.equal("1", trace:Text(event.args))
    end)

    it("builds trace options from the settings", function()
      perfSessions:SetSetting("traceCalls", false)
      perfSessions:SetSetting("traceArgs", false)
      perfSessions:SetSetting("traceMaxCalls", 5)
      local options = perfSessions:BuildOptions()
      assert.is_false(options.trace)
      assert.is_false(options.traceArgs)
      assert.are.equal(10000, options.traceMaxCalls)
      perfSessions:SetSetting("traceMaxCalls", 99999999)
      assert.are.equal(2000000, perfSessions:GetSettings().traceMaxCalls)
    end)

    it("stops on its own once the trace is full, and saves why", function()
      perfSessions:SetSetting("traceMaxCalls", 10000)
      perfSessions:StartCapture("manual")
      for _ = 1, 10001 do
        local token = perf:Enter("[event] TEST")
        perf:Exit(token)
      end
      assert.is_true(perfSessions:IsCapturing())
      perf:_OnFrame()
      assert.is_false(perfSessions:IsCapturing())
      local session = perfSessions:GetSessions()[1]
      assert.are.equal("traceFull", session.stats.stopReason)
      assert.are.equal(10000, session.stats.traceCalls)
      assert.is_true(session.trace.full)
    end)
  end)

  describe("trimming traces", function()
    local function captureOne()
      perfSessions:StartCapture("manual")
      local token = perf:Enter("[event] TEST")
      perf:Exit(token)
      return perfSessions:StopCapture()
    end

    it("removes one session's trace and keeps the rest of the session", function()
      local first = captureOne()
      local second = captureOne()
      sent = {}
      assert.is_true(perfSessions:RemoveTrace(first.id))
      assert.is_nil(perfSessions:GetSession(first.id).trace)
      assert.is_true(perfSessions:GetSession(first.id).stats.traceRemoved)
      assert.is_table(perfSessions:GetSession(first.id).nodes)
      assert.is_table(perfSessions:GetSession(second.id).trace)
      assert.are.same({ "perf/SessionsChanged" }, sentEvents())
      assert.is_false(perfSessions:RemoveTrace(first.id), "nothing left to remove")
    end)

    it("removes every session's trace", function()
      captureOne()
      captureOne()
      perfSessions:RemoveAllTraces()
      for _, session in ipairs(perfSessions:GetSessions()) do
        assert.is_nil(session.trace)
        assert.is_true(session.stats.traceRemoved)
      end
    end)

    it("records Blizzard's addon profiler metrics when the client has them", function()
      local metricCalls = {}
      _G.C_AddOnProfiler = {
        IsEnabled = function() return true end,
        GetAddOnMetric = function(name, metric)
          table.insert(metricCalls, { name = name, metric = metric })
          return metric == _G.Enum.AddOnProfilerMetric.LastTime and 25 or 1
        end,
      }
      perfSessions:StartCapture("manual")
      perf:_OnFrame()
      local session = perfSessions:StopCapture()
      assert.are.equal("BetterBags", metricCalls[1].name)
      assert.are.equal(1, session.meta.blizzardStart.PeakTime)
      assert.are.equal(1, session.meta.blizzardStop.CountTimeOver5Ms)
      assert.are.same({ 25 }, addon:GetModule("PerfFormat"):DecodeTimeline(session).blizzard)
    end)

    -- Raids and dungeons switch on addon restrictions (C_RestrictedActions, 12.x); a capture
    -- records which were active, and where the player was.
    it("records the addon restrictions and the instance when it starts and stops", function()
      local savedEnum = { _G.Enum.AddOnRestrictionType, _G.Enum.AddOnRestrictionState }
      local savedApi, savedInstance = _G.C_RestrictedActions, _G.GetInstanceInfo
      _G.Enum.AddOnRestrictionType = { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4, Chat = 5 }
      _G.Enum.AddOnRestrictionState = { Inactive = 0, Activating = 1, Active = 2 }
      local states = { [0] = 2, [4] = 2 }
      _G.C_RestrictedActions = { GetAddOnRestrictionState = function(t) return states[t] or 0 end }
      local where = { "Tichondrius Halls", "party", 8, "Mythic Keystone", 5 }
      _G.GetInstanceInfo = function() return unpack(where) end
      perfSessions:StartCapture("manual")
      states[1] = 2
      where = { "Dornogal", "none", 0, "", 5 }
      local session = perfSessions:StopCapture()
      _G.Enum.AddOnRestrictionType, _G.Enum.AddOnRestrictionState = savedEnum[1], savedEnum[2]
      _G.C_RestrictedActions, _G.GetInstanceInfo = savedApi, savedInstance
      assert.are.same({ Combat = "Active", Encounter = "Inactive", ChallengeMode = "Inactive", PvPMatch = "Inactive",
        Map = "Active", Chat = "Inactive" }, session.meta.restrictionsStart)
      assert.are.equal("Active", session.meta.restrictionsStop.Encounter)
      assert.are.same({ name = "Tichondrius Halls", instanceType = "party", difficultyID = 8,
        difficultyName = "Mythic Keystone" }, session.meta.instanceStart)
      assert.are.equal("none", session.meta.instanceStop.instanceType)
    end)

    it("leaves the restrictions out on clients without them", function()
      local savedApi = _G.C_RestrictedActions
      _G.C_RestrictedActions = nil
      perfSessions:StartCapture("manual")
      local session = perfSessions:StopCapture()
      _G.C_RestrictedActions = savedApi
      assert.is_nil(session.meta.restrictionsStart)
      assert.is_nil(session.meta.restrictionsStop)
    end)

    it("records Blizzard's per-frame time for all addons and the whole client, and the slowest addons", function()
      _G.C_AddOnProfiler = {
        IsEnabled = function() return true end,
        GetAddOnMetric = function() return 1 end,
        GetOverallMetric = function(metric)
          return metric == _G.Enum.AddOnProfilerMetric.LastTime and 4 or 0
        end,
        GetApplicationMetric = function(metric)
          return metric == _G.Enum.AddOnProfilerMetric.LastTime and 160 or 0
        end,
        GetTopKAddOnsForMetric = function(metric, k)
          assert.are.equal(_G.Enum.AddOnProfilerMetric.PeakTime, metric)
          assert.are.equal(10, k)
          return { { addOnName = "BetterBags", metricValue = 56.7 }, { addOnName = "Other", metricValue = 3 } }
        end,
      }
      perfSessions:StartCapture("manual")
      perf:_OnFrame()
      local session = perfSessions:StopCapture()
      local timeline = addon:GetModule("PerfFormat"):DecodeTimeline(session)
      assert.are.same({ 4 }, timeline.series.all)
      assert.are.same({ 160 }, timeline.series.app)
      assert.are.same({ { name = "BetterBags", ms = 56.7 }, { name = "Other", ms = 3 } }, session.meta.topAddonsStop)
      assert.are.same(session.meta.topAddonsStop, session.meta.topAddonsStart)
    end)

    it("traces addon restriction changes on clients that have them", function()
      local savedUtils = _G.C_EventUtils
      _G.C_EventUtils = { IsEventValid = function(name) return name == "ADDON_RESTRICTION_STATE_CHANGED" end }
      perfSessions._eventsHooked = nil
      registered = {}
      perfSessions:Init()
      assert.is_function(registered.ADDON_RESTRICTION_STATE_CHANGED)
      _G.C_EventUtils = { IsEventValid = function() return false end }
      perfSessions._eventsHooked = nil
      registered = {}
      perfSessions:Init()
      _G.C_EventUtils = savedUtils
      assert.is_nil(registered.ADDON_RESTRICTION_STATE_CHANGED)
    end)

    -- When the pet journal, the toy box and the appearance collection have loaded, against the bag
    -- reads (docs/vendor-compat.md, "Needs an in-game check"): their counts at the start and the
    -- end, and each collection event with the counts at that moment, in the trace.
    local function collections()
      local saved = { _G.C_PetJournal, _G.C_ToyBox, _G.C_TransmogCollection }
      _G.C_PetJournal = { GetNumPets = function() return 1200, 850 end }
      _G.C_ToyBox = { GetNumTotalDisplayedToys = function() return 900 end,
        GetNumLearnedDisplayedToys = function() return 410 end }
      _G.C_TransmogCollection = { GetNumTransmogSources = function() return 31000 end }
      return function() _G.C_PetJournal, _G.C_ToyBox, _G.C_TransmogCollection = saved[1], saved[2], saved[3] end
    end

    it("records the collections' counts when it starts and stops", function()
      local restore = collections()
      perfSessions:StartCapture("manual")
      _G.C_PetJournal.GetNumPets = function() return 1201, 851 end
      local session = perfSessions:StopCapture()
      restore()
      assert.are.same({ pets = 1200, petsOwned = 850, toys = 900, toysLearned = 410, transmogSources = 31000 },
        session.meta.collectionsStart)
      assert.are.equal(851, session.meta.collectionsStop.petsOwned)
    end)

    it("leaves out what a client has no collection for", function()
      local saved = { _G.C_PetJournal, _G.C_ToyBox, _G.C_TransmogCollection }
      _G.C_PetJournal, _G.C_ToyBox = nil, nil
      _G.C_TransmogCollection = { GetNumTransmogSources = function() return 5 end }
      perfSessions:StartCapture("manual")
      local session = perfSessions:StopCapture()
      _G.C_TransmogCollection = nil
      perfSessions:StartCapture("manual")
      local none = perfSessions:StopCapture()
      _G.C_PetJournal, _G.C_ToyBox, _G.C_TransmogCollection = saved[1], saved[2], saved[3]
      assert.are.same({ transmogSources = 5 }, session.meta.collectionsStart)
      assert.is_nil(none.meta.collectionsStart)
    end)

    it("traces each collection event with the counts at that moment", function()
      local restore = collections()
      local savedUtils = _G.C_EventUtils
      _G.C_EventUtils = { IsEventValid = function() return true end }
      perfSessions._eventsHooked = nil
      registered = {}
      perfSessions:Init()
      _G.C_EventUtils = savedUtils
      for _, name in ipairs({ "PET_JOURNAL_LIST_UPDATE", "NEW_PET_ADDED", "PET_JOURNAL_PET_DELETED",
        "TRANSMOG_COLLECTION_UPDATED", "TRANSMOG_COLLECTION_SOURCE_ADDED", "TRANSMOG_COLLECTION_SOURCE_REMOVED",
        "NEW_TOY_ADDED", "TOYS_UPDATED" }) do
        assert.is_function(registered[name], name)
      end
      perfSessions:StartCapture("manual")
      registered.PET_JOURNAL_LIST_UPDATE("PET_JOURNAL_LIST_UPDATE")
      local session = perfSessions:StopCapture()
      restore()
      local trace = addon:GetModule("PerfFormat"):OpenTrace(session)
      local sample
      for i = 1, trace:Count() do
        if trace:Get(i).name == "[collections]" then sample = trace:Get(i) end
      end
      assert.is_not_nil(sample)
      local text = trace:Text(sample.args)
      assert.is_truthy(text:find("petsOwned=850", 1, true), text)
      assert.is_truthy(text:find("toysLearned=410", 1, true), text)
    end)

    it("listens to no collection event a client does not have", function()
      local savedUtils = _G.C_EventUtils
      _G.C_EventUtils = { IsEventValid = function(name) return name == "ADDON_RESTRICTION_STATE_CHANGED" end }
      perfSessions._eventsHooked = nil
      registered = {}
      perfSessions:Init()
      _G.C_EventUtils = savedUtils
      for _, name in ipairs(perfSessions.COLLECTION_EVENTS) do
        assert.is_nil(registered[name], name)
      end
    end)

    it("samples nothing while no capture runs", function()
      local restore = collections()
      local savedUtils = _G.C_EventUtils
      _G.C_EventUtils = { IsEventValid = function() return true end }
      perfSessions._eventsHooked = nil
      registered = {}
      perfSessions:Init()
      _G.C_EventUtils = savedUtils
      local asked = 0
      _G.C_PetJournal.GetNumPets = function() asked = asked + 1 return 1, 1 end
      registered.PET_JOURNAL_LIST_UPDATE("PET_JOURNAL_LIST_UPDATE")
      restore()
      assert.are.equal(0, asked)
    end)

    it("keeps metadata the starter adds, such as the simulation it runs", function()
      perfSessions:StartCapture("simulate", { simulation = { event = "BAG_UPDATE_COOLDOWN", rate = 12 } })
      local session = perfSessions:StopCapture()
      assert.are.equal("simulate", session.meta.reason)
      assert.are.same({ event = "BAG_UPDATE_COOLDOWN", rate = 12 }, session.meta.simulation)
      local format = addon:GetModule("PerfFormat")
      assert.are.equal("simulate", format:ReasonLabel("simulate"))
      assert.are.equal("by the event simulator", format:ReasonPhrase("simulate"))
    end)

    it("leaves Blizzard metrics out on clients without the addon profiler", function()
      perfSessions:StartCapture("manual")
      local session = perfSessions:StopCapture()
      assert.is_nil(session.meta.blizzardStart)
      assert.is_nil(session.timeline.blizzard)
    end)
  end)

  describe("deleting", function()
    it("deletes one session or all of them", function()
      for _ = 1, 3 do
        perfSessions:StartCapture("manual")
        perfSessions:StopCapture()
      end
      sent = {}
      perfSessions:DeleteSession(2)
      assert.is_nil(perfSessions:GetSession(2))
      assert.are.equal(2, #perfSessions:GetSessions())
      assert.are.same({ "perf/SessionsChanged" }, sentEvents())
      perfSessions:DeleteAllSessions()
      assert.are.equal(0, #perfSessions:GetSessions())
    end)
  end)

  describe("presets", function()
    local function sourceFiles()
      local files = {}
      local pipe = io.popen("find animations bags config core data debug forms frames integrations render sonata util views window -name '*.lua'")
      for path in pipe:lines() do files[#files + 1] = path end
      pipe:close()
      return files
    end

    it("only names modules and prototypes that exist in the addon", function()
      local modules, prototypes = {}, {}
      for _, path in ipairs(sourceFiles()) do
        local f = assert(io.open(path, "r"))
        local src = f:read("*a")
        f:close()
        for name in src:gmatch("addon:NewModule%(['\"]([%w_]+)['\"]") do modules[name] = true end
        for name in src:gmatch("RegisterPrototype%([^,]+,%s*['\"]([%w_]+)['\"]%)") do prototypes[name] = true end
        -- Drawable prototypes register through drawable:Extend(proto, name).
        for name in src:gmatch("drawable:Extend%([^,]+,%s*['\"]([%w_]+)['\"]%)") do prototypes[name] = true end
      end
      for presetName, preset in pairs(perfSessions.PRESETS) do
        for _, name in ipairs(preset.modules or {}) do
          assert.is_true(modules[name] == true, presetName .. " preset names unknown module " .. name)
        end
        for _, name in ipairs(preset.prototypes or {}) do
          assert.is_true(prototypes[name] == true, presetName .. " preset names unknown prototype " .. name)
        end
      end
    end)
  end)

  describe("capture on next reload", function()
    it("is a one-shot switch consumed at load", function()
      assert.is_false(perfSessions:IsArmedForNextReload())
      perfSessions:SetArmedForNextReload(true)
      assert.is_true(perfSessions:IsArmedForNextReload())
      assert.is_true(_G.BetterBagsPerfDB.armNextReload)

      perfSessions:Init()
      assert.is_true(perfSessions:StartIfArmed())
      assert.is_true(perfSessions:IsCapturing())
      assert.is_false(perfSessions:IsArmedForNextReload())
      perfSessions:StopCapture()

      assert.is_false(perfSessions:StartIfArmed())
      assert.is_false(perfSessions:IsCapturing())
    end)

    -- The switch applies to the next load, a full relaunch as much as a /reload. Which one it
    -- was is known at the first PLAYER_ENTERING_WORLD (isInitialLogin, isReloadingUi).
    for _, case in ipairs({ { true, false, "login" }, { false, true, "reload" } }) do
      it("labels the capture a " .. case[3] .. " once the game says how it started", function()
        perfSessions:SetArmedForNextReload(true)
        perfSessions:Init()
        assert.is_true(perfSessions:StartIfArmed())
        assert.is_function(registered["PLAYER_ENTERING_WORLD"])
        registered["PLAYER_ENTERING_WORLD"]({}, "PLAYER_ENTERING_WORLD", case[1], case[2])
        local session = perfSessions:StopCapture()
        assert.are.equal(case[3], session.meta.reason)
      end)
    end

    it("labels a capture stopped before the game finished loading a startup", function()
      perfSessions:SetArmedForNextReload(true)
      perfSessions:Init()
      assert.is_true(perfSessions:StartIfArmed())
      local session = perfSessions:StopCapture()
      assert.are.equal("startup", session.meta.reason)
    end)

    it("keeps the label through later loading screens, and never relabels a manual capture", function()
      perfSessions:SetArmedForNextReload(true)
      perfSessions:Init()
      perfSessions:StartIfArmed()
      registered["PLAYER_ENTERING_WORLD"]({}, "PLAYER_ENTERING_WORLD", true, false)
      registered["PLAYER_ENTERING_WORLD"]({}, "PLAYER_ENTERING_WORLD", false, false)
      assert.are.equal("login", perfSessions:StopCapture().meta.reason)

      perfSessions:StartCapture()
      registered["PLAYER_ENTERING_WORLD"]({}, "PLAYER_ENTERING_WORLD", false, true)
      assert.are.equal("manual", perfSessions:StopCapture().meta.reason)
    end)
  end)
end)
