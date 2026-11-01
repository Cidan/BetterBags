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
    -- Appearances collected: GetCategoryCollectedCount summed over every category (TransmogCollectionType,
    -- TransmogSharedDocumentation.lua) but None. (GetNumTransmogSources, used at first, is the number of
    -- source filters, Blizzard_Wardrobe.lua:67: 7 in a login capture whatever was collected.)
    describe("what the client does", function()
      local savedUtils, savedProfiler, savedAddOns, savedEnum, savedCharacter, savedGw
      local metrics

      before_each(function()
        savedUtils, savedProfiler, savedAddOns = _G.C_EventUtils, _G.C_AddOnProfiler, _G.C_AddOns
        savedEnum = _G.Enum and _G.Enum.AddOnProfilerMetric
        savedCharacter, savedGw = _G.CharacterFrame, _G.GwCharacterWindow
        _G.C_EventUtils = { IsEventValid = function() return true end }
        metrics = { BetterBags = 1, GW2_UI = 40, Pawn = 0.2, NotLoaded = 99 }
      end)

      after_each(function()
        _G.C_EventUtils, _G.C_AddOnProfiler, _G.C_AddOns = savedUtils, savedProfiler, savedAddOns
        _G.CharacterFrame, _G.GwCharacterWindow = savedCharacter, savedGw
        if _G.Enum then _G.Enum.AddOnProfilerMetric = savedEnum end
        if perf:IsActive() then perf:Stop() end
      end)

      local function installProfiler(appMs, allMs)
        _G.Enum = _G.Enum or {}
        _G.Enum.AddOnProfilerMetric = _G.Enum.AddOnProfilerMetric or { LastTime = 1, PeakTime = 2 }
        _G.C_AddOnProfiler = {
          IsEnabled = function() return true end,
          GetAddOnMetric = function(name) return metrics[name] or 0 end,
          GetOverallMetric = function() return type(allMs) == "function" and allMs() or allMs or 41 end,
          GetApplicationMetric = function() return type(appMs) == "function" and appMs() or appMs end,
        }
        local names = { "BetterBags", "GW2_UI", "Pawn", "NotLoaded" }
        _G.C_AddOns = setmetatable({
          GetNumAddOns = function() return #names end,
          GetAddOnInfo = function(i) return names[i] end,
          IsAddOnLoaded = function(name) return name ~= "NotLoaded" end,
        }, { __index = savedAddOns })
      end

      it("listens to the client's events only while a capture runs", function()
        local frame = perfSessions.clientEventFrame
        assert.is_false(frame:IsEventRegistered("ITEM_LOCKED"))
        perfSessions:StartCapture()
        assert.is_truthy(frame:IsEventRegistered("ITEM_LOCKED"))
        assert.is_truthy(frame:IsEventRegistered("UNIT_MODEL_CHANGED"))
        perfSessions:StopCapture()
        assert.is_false(frame:IsEventRegistered("ITEM_LOCKED"))
        assert.is_false(frame:IsEventRegistered("UNIT_MODEL_CHANGED"))
      end)

      it("leaves out an event the client does not have", function()
        _G.C_EventUtils = { IsEventValid = function(name) return name ~= "UNIT_MODEL_CHANGED" and name ~= "ITEM_UNLOCKED" end }
        local frame = perfSessions.clientEventFrame
        perfSessions:StartCapture()
        assert.is_false(frame:IsEventRegistered("UNIT_MODEL_CHANGED"))
        assert.is_false(frame:IsEventRegistered("ITEM_UNLOCKED"))
        assert.is_truthy(frame:IsEventRegistered("ITEM_LOCKED"))
        perfSessions:StopCapture()
      end)

      it("names each in the trace, with what shows and its payload", function()
        _G.CharacterFrame = CreateFrame("Frame")
        _G.CharacterFrame:Show()
        perfSessions:StartCapture()
        perfSessions.clientEventFrame:GetScript("OnEvent")(perfSessions.clientEventFrame, "UNIT_MODEL_CHANGED", "player")
        local session = perfSessions:StopCapture()
        local trace = addon:GetModule("PerfFormat"):OpenTrace(session)
        local found
        for i = 1, trace:Count() do
          if trace:Get(i).name == "[client] UNIT_MODEL_CHANGED" then found = trace:Get(i) end
        end
        assert.is_truthy(found)
        local text = trace:Text(found.args)
        assert.is_truthy(text:find("Blizzard's character pane", 1, true))
        assert.is_truthy(text:find("player", 1, true))
      end)

      it("says which character pane shows", function()
        _G.CharacterFrame, _G.GwCharacterWindow = nil, nil
        assert.equal("no character pane", perfSessions:CharacterPane())
        _G.CharacterFrame = CreateFrame("Frame")
        _G.CharacterFrame:Hide()
        assert.equal("no character pane", perfSessions:CharacterPane())
        _G.CharacterFrame:Show()
        assert.equal("Blizzard's character pane", perfSessions:CharacterPane())
        _G.GwCharacterWindow = CreateFrame("Frame")
        _G.GwCharacterWindow:Hide()
        assert.equal("Blizzard's character pane", perfSessions:CharacterPane())
        _G.GwCharacterWindow:Show()
        assert.equal("GW2_UI's character pane", perfSessions:CharacterPane())
      end)

      it("names what each addon took in a slow tick, slowest first, and the pane", function()
        installProfiler(70)
        _G.CharacterFrame = CreateFrame("Frame")
        _G.CharacterFrame:Show()
        perfSessions:StartCapture()
        perf:_OnFrame()
        local session = perfSessions:StopCapture()
        local slow = session.timeline.slow[1]
        assert.equal(1, slow.frame)
        assert.equal(70, slow.ms)
        assert.equal("Blizzard's character pane", slow.detail.pane)
        assert.are.same({ { frame = 1, allMs = 41, addons = { { name = "GW2_UI", ms = 40 }, { name = "BetterBags", ms = 1 } } } },
          slow.detail.readings)
      end)

      -- A capture of a sort: the frame the client read 80 ms for came a frame after the addons' readings for it.
      it("names what each addon took a frame before the client's reading, and says which frame", function()
        local frame = 0
        installProfiler(function() return frame == 2 and 80 or 13 end, function() return frame == 1 and 69 or 1.3 end)
        perfSessions:StartCapture()
        frame = 1
        metrics = { BetterBags = 65, GW2_UI = 3 }
        perf:_OnFrame()
        frame = 2
        metrics = { BetterBags = 1.2 }
        perf:_OnFrame()
        local slow = perfSessions:StopCapture().timeline.slow[1]
        assert.equal(2, slow.frame)
        assert.are.same({ { frame = 1, allMs = 69, addons = { { name = "BetterBags", ms = 65 }, { name = "GW2_UI", ms = 3 } } } },
          slow.detail.readings)
      end)

      it("names both frames when both were busy, so neither's work is dropped", function()
        local frame = 0
        installProfiler(function() return frame == 2 and 100 or 13 end, function() return frame == 1 and 40 or 20 end)
        perfSessions:StartCapture()
        frame = 1
        metrics = { Pawn = 38 }
        perf:_OnFrame()
        frame = 2
        metrics = { GW2_UI = 19 }
        perf:_OnFrame()
        assert.are.same({
          { frame = 1, allMs = 40, addons = { { name = "Pawn", ms = 38 } } },
          { frame = 2, allMs = 20, addons = { { name = "GW2_UI", ms = 19 } } },
        }, perfSessions:StopCapture().timeline.slow[1].detail.readings)
      end)

      it("keeps a frame that names somebody beside a busier one that names nobody", function()
        local frame = 0
        installProfiler(function() return frame == 2 and 80 or 13 end, function() return frame == 1 and 6 or 7 end)
        perfSessions:StartCapture()
        frame = 1
        metrics = { Pawn = 5.5 }
        perf:_OnFrame()
        frame = 2
        metrics = { GW2_UI = 0.4 }
        perf:_OnFrame()
        assert.are.same({
          { frame = 1, allMs = 6, addons = { { name = "Pawn", ms = 5.5 } } },
          { frame = 2, allMs = 7, addons = {} },
        }, perfSessions:StopCapture().timeline.slow[1].detail.readings)
      end)

      it("names an addon of 0.5 ms or more, and not one under", function()
        installProfiler(80, 41)
        metrics = { Pawn = 0.5, GW2_UI = 0.49 }
        perfSessions:StartCapture()
        perf:_OnFrame()
        assert.are.same({ { frame = 1, allMs = 41, addons = { { name = "Pawn", ms = 0.5 } } } },
          perfSessions:StopCapture().timeline.slow[1].detail.readings)
      end)

      it("reads no frame when the addons took little in that tick", function()
        installProfiler(80, 2)
        perfSessions:StartCapture()
        perf:_OnFrame()
        local slow = perfSessions:StopCapture().timeline.slow[1]
        assert.are.same({}, slow.detail.readings)
        assert.is_nil(slow.detail.error)
      end)

      it("reads a frame all addons took 5 ms or more in, and not one under", function()
        installProfiler(80, 5)
        perfSessions:StartCapture()
        perf:_OnFrame()
        assert.equal(1, #perfSessions:StopCapture().timeline.slow[1].detail.readings)
        installProfiler(80, 4.9)
        perfSessions:StartCapture()
        perf:_OnFrame()
        assert.equal(0, #perfSessions:StopCapture().timeline.slow[1].detail.readings)
      end)

      it("keeps a tick of 33 ms or more, and not one under", function()
        installProfiler(32.9, 41)
        perfSessions:StartCapture()
        perf:_OnFrame()
        assert.is_nil(perfSessions:StopCapture().timeline.slow)
        installProfiler(33, 41)
        perfSessions:StartCapture()
        perf:_OnFrame()
        assert.equal(1, #perfSessions:StopCapture().timeline.slow)
      end)

      it("keeps the slowest 64", function()
        local ms = 40
        installProfiler(function() ms = ms + 1 return ms end, 1)
        perfSessions:StartCapture()
        for _ = 1, 65 do perf:_OnFrame() end
        assert.equal(64, #perfSessions:StopCapture().timeline.slow)
      end)

      it("says so when it could not read what the addons took in a frame", function()
        installProfiler(80, 41)
        _G.C_AddOnProfiler.GetAddOnMetric = function(name)
          if name == "GW2_UI" then error("no reading") end
          return 1
        end
        perfSessions:StartCapture()
        perf:_OnFrame()
        local reading = perfSessions:StopCapture().timeline.slow[1].detail.readings[1]
        assert.equal(1, reading.frame)
        assert.equal(41, reading.allMs)
        assert.is_truthy(reading.error:find("no reading", 1, true))
        assert.is_nil(reading.addons)
      end)

      it("asks about no addon in an ordinary tick", function()
        installProfiler(12, 2)
        spy.on(_G.C_AddOnProfiler, "GetAddOnMetric")
        perfSessions:StartCapture()
        local before = #_G.C_AddOnProfiler.GetAddOnMetric.calls
        perf:_OnFrame()
        assert.equal(before + 1, #_G.C_AddOnProfiler.GetAddOnMetric.calls, "only BetterBags' own reading")
        assert.is_nil(perfSessions:StopCapture().timeline.slow)
      end)

      it("works without Blizzard's addon list", function()
        installProfiler(70)
        _G.C_AddOns = setmetatable({ GetNumAddOns = false }, { __index = savedAddOns })
        perfSessions:StartCapture()
        perf:_OnFrame()
        assert.are.same({ { frame = 1, allMs = 41, addons = {} } }, perfSessions:StopCapture().timeline.slow[1].detail.readings)
      end)
    end)

    local function collections()
      local saved = { _G.C_PetJournal, _G.C_ToyBox, _G.C_TransmogCollection, _G.Enum.TransmogCollectionType }
      _G.C_PetJournal = { GetNumPets = function() return 1200, 850 end }
      _G.C_ToyBox = { GetNumTotalDisplayedToys = function() return 900 end,
        GetNumLearnedDisplayedToys = function() return 410 end }
      _G.Enum.TransmogCollectionType = { None = 0, Head = 1, Shoulder = 2, Paired = 29 }
      local collected = { [0] = 1000000, [1] = 300, [2] = 250, [29] = 50 }
      _G.C_TransmogCollection = { GetCategoryCollectedCount = function(category) return collected[category] end }
      return function()
        _G.C_PetJournal, _G.C_ToyBox, _G.C_TransmogCollection = saved[1], saved[2], saved[3]
        _G.Enum.TransmogCollectionType = saved[4]
      end
    end

    it("records the collections' counts when it starts and stops", function()
      local restore = collections()
      perfSessions:StartCapture("manual")
      _G.C_PetJournal.GetNumPets = function() return 1201, 851 end
      local session = perfSessions:StopCapture()
      restore()
      assert.are.same({ pets = 1200, petsOwned = 850, toys = 900, toysLearned = 410, appearances = 600 },
        session.meta.collectionsStart)
      assert.are.equal(851, session.meta.collectionsStop.petsOwned)
    end)

    it("leaves out what a client has no collection for", function()
      local restore = collections()
      _G.C_PetJournal, _G.C_ToyBox = nil, nil
      perfSessions:StartCapture("manual")
      local session = perfSessions:StopCapture()
      _G.Enum.TransmogCollectionType = nil
      perfSessions:StartCapture("manual")
      local none = perfSessions:StopCapture()
      restore()
      assert.are.same({ appearances = 600 }, session.meta.collectionsStart)
      assert.is_nil(none.meta.collectionsStart, "no categories to count")
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

    -- Leaving the world and coming back (a loading screen: a dungeon, a portal), against the bag events
    -- and BetterBags' reads (refresh-scheduler.md §8): each world event in the trace with what the bags
    -- hold at that moment, by kind: slots, items by ID, and items that exist at their location (what
    -- C_Item.GetItemGUID needs). Added when a window closing as a player went into a dungeon asked the
    -- client about slots it had emptied, and no capture could show when the items leave and come back.
    describe("the world", function()
      local saved, bags, exist, slotsAsked

      local const, createdConst

      before_each(function()
        const, createdConst = StubBetterBagsModule("Constants")
        saved = { _G.C_Container, _G.C_Item.DoesItemExist, const.BACKPACK_BAGS, const.BANK_BAGS, const.ACCOUNT_BANK_BAGS }
        const.BACKPACK_BAGS, const.BANK_BAGS, const.ACCOUNT_BANK_BAGS = { [0] = 0, [1] = 1 }, { [6] = 6 }, { [13] = 13 }
        -- bag -> slot -> itemID; exist: bag -> slot -> whether the item is at its location.
        bags = { [0] = { 101, nil, 102 }, [1] = { 201 }, [6] = {}, [13] = { 301 } }
        exist = { [0] = { true, false, true }, [1] = { true }, [13] = { true } }
        slotsAsked = 0
        _G.C_Container = setmetatable({
          GetContainerNumSlots = function(bag)
            slotsAsked = slotsAsked + 1
            return ({ [0] = 3, [1] = 1, [6] = 0, [13] = 2 })[bag] or 0
          end,
          GetContainerItemID = function(bag, slot) return bags[bag] and bags[bag][slot] end,
        }, { __index = saved[1] })
        _G.C_Item.DoesItemExist = function(location)
          local bag, slot = location:GetBagAndSlot()
          return exist[bag] ~= nil and exist[bag][slot] == true
        end
      end)

      after_each(function()
        _G.C_Container, _G.C_Item.DoesItemExist = saved[1], saved[2]
        const.BACKPACK_BAGS, const.BANK_BAGS, const.ACCOUNT_BANK_BAGS = saved[3], saved[4], saved[5]
        if createdConst then ResetModuleStub("Constants") end
      end)

      -- Every handler of an event, called as the events module calls them: (ctx, event, ...).
      local handlers

      local function hook(valid)
        local savedUtils = _G.C_EventUtils
        _G.C_EventUtils = { IsEventValid = valid or function() return true end }
        handlers = {}
        events.RegisterEvent = function(_, event, fn)
          handlers[event] = handlers[event] or {}
          table.insert(handlers[event], fn)
        end
        perfSessions._eventsHooked = nil
        perfSessions:Init()
        _G.C_EventUtils = savedUtils
      end

      local function fire(name, ...)
        for _, fn in ipairs(handlers[name] or {}) do
          fn({}, name, ...)
        end
      end

      local function bagCalls(session)
        local trace = addon:GetModule("PerfFormat"):OpenTrace(session)
        local list = {}
        for i = 1, trace:Count() do
          local call = trace:Get(i)
          if call.name == "[bags]" then table.insert(list, trace:Text(call.args)) end
        end
        return list
      end

      it("counts what each kind of bag holds: slots, items, and items at their location", function()
        assert.are.same({
          backpack = { slots = 4, items = 3, exist = 3 },
          bank = { slots = 2, items = 1, exist = 1 },
        }, perfSessions:BagCounts())
        exist[0][1] = false
        assert.are.same({ bag = 0, slots = 3, items = 2, exist = 1 }, perfSessions:BagCounts(0))
      end)

      it("traces leaving the world, the loading screen and windows closing with what the bags hold", function()
        hook()
        for _, name in ipairs(perfSessions.WORLD_EVENTS) do
          assert.is_not_nil(handlers[name], name)
        end
        perfSessions:StartCapture("manual")
        fire("PLAYER_LEAVING_WORLD")
        -- The client takes the items away: their IDs read, their objects gone.
        exist[0] = { false, false, false }
        exist[1] = { false }
        fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 5)
        fire("LOADING_SCREEN_ENABLED")
        fire("LOADING_SCREEN_DISABLED")
        fire("BAG_CONTAINER_UPDATE")
        fire("PLAYER_ENTERING_WORLD", false, false)
        local calls = bagCalls(perfSessions:StopCapture())
        assert.are.equal(6, #calls)
        assert.is_truthy(calls[1]:find("exist=3", 1, true), calls[1])
        assert.is_truthy(calls[2]:find("exist=0", 1, true), calls[2])
        assert.is_truthy(calls[2]:find("items=3", 1, true), calls[2])
      end)

      it("traces each bag event with what its bag holds", function()
        hook()
        perfSessions:StartCapture("manual")
        fire("BAG_UPDATE", 1)
        local calls = bagCalls(perfSessions:StopCapture())
        assert.are.equal(1, #calls)
        assert.is_truthy(calls[1]:find("bag=1", 1, true), calls[1])
        assert.is_truthy(calls[1]:find("slots=1", 1, true), calls[1])
      end)

      it("reads nothing while no capture runs", function()
        hook()
        fire("PLAYER_LEAVING_WORLD")
        fire("BAG_UPDATE", 0)
        fire("PLAYER_ENTERING_WORLD", false, false)
        assert.are.equal(0, slotsAsked)
      end)

      it("listens to no world event the client does not have", function()
        hook(function(name) return name ~= "LOADING_SCREEN_ENABLED" end)
        assert.is_nil(handlers.LOADING_SCREEN_ENABLED)
        assert.is_not_nil(handlers.PLAYER_LEAVING_WORLD)
      end)
    end)

    -- One play session answers every open in-game question (docs/vendor-compat.md): a diagnostics
    -- run captures the next two loads (a fresh login, then a /reload), each stopping on its own a
    -- minute after entering the world, sampling what follows the character and the account.
    describe("diagnostics", function()
      local timers, probeState, probe, probeCreated, savedSample, savedAfter

      local function fireTimers(delay)
        local pending = timers
        timers = {}
        for _, t in ipairs(pending) do
          if t.delay == delay then t.fn() else table.insert(timers, t) end
        end
      end

      local function scheduled(delay)
        local n = 0
        for _, t in ipairs(timers) do if t.delay == delay then n = n + 1 end end
        return n
      end

      before_each(function()
        timers = {}
        savedAfter = _G.C_Timer.After
        _G.C_Timer.After = function(delay, fn) table.insert(timers, { delay = delay, fn = fn }) end
        probe, probeCreated = StubBetterBagsModule("ItemProbe")
        savedSample = probe.Sample
        probeState = { level = 90 }
        probe.Sample = function() return { level = probeState.level } end
      end)

      after_each(function()
        _G.C_Timer.After = savedAfter
        probe.Sample = savedSample
        if probeCreated then ResetModuleStub("ItemProbe") end
      end)

      it("arms the next two loads", function()
        perfSessions:ArmDiagnostics()
        assert.is_true(perfSessions:IsArmedForNextReload())
        assert.are.equal(2, perfSessions:GetArmedLoads())
        assert.is_true(perfSessions:StartIfArmed())
        assert.is_true(perfSessions.pendingMeta.diagnostics)
        assert.are.equal(1, perfSessions:GetArmedLoads())
        perfSessions:StopCapture()
        assert.is_true(perfSessions:StartIfArmed())
        assert.are.equal(0, perfSessions:GetArmedLoads())
        assert.is_false(perfSessions:IsArmedForNextReload())
        perfSessions:StopCapture()
        assert.is_false(perfSessions:StartIfArmed())
      end)

      it("stops each capture on its own a minute after entering the world", function()
        perfSessions:ArmDiagnostics()
        perfSessions:StartIfArmed()
        assert.are.equal(0, scheduled(perfSessions.DIAGNOSTICS.stopAfterSec))
        perfSessions:OnEnteringWorld(true, false)
        assert.are.equal(1, scheduled(perfSessions.DIAGNOSTICS.stopAfterSec))
        perfSessions:OnEnteringWorld(false, false)
        assert.are.equal(1, scheduled(perfSessions.DIAGNOSTICS.stopAfterSec), "later loading screens add none")
        fireTimers(perfSessions.DIAGNOSTICS.stopAfterSec)
        assert.is_false(perf:IsActive())
        local sessions = perfSessions:GetSessions()
        assert.are.equal("login", sessions[#sessions].meta.reason)
      end)

      it("leaves a later capture running when an earlier one's stop comes due", function()
        perfSessions:ArmDiagnostics()
        perfSessions:StartIfArmed()
        perfSessions:OnEnteringWorld(true, false)
        perfSessions:StopCapture()
        perfSessions:StartCapture("manual")
        fireTimers(perfSessions.DIAGNOSTICS.stopAfterSec)
        assert.is_true(perf:IsActive())
      end)

      it("leaves Capture next reload as it was: one load, no stop of its own, no samples", function()
        perfSessions:SetArmedForNextReload(true)
        assert.are.equal(1, perfSessions:GetArmedLoads())
        perfSessions:StartIfArmed()
        perfSessions:OnEnteringWorld(true, false)
        assert.are.equal(0, scheduled(perfSessions.DIAGNOSTICS.stopAfterSec))
        assert.are.equal(0, scheduled(perfSessions.DIAGNOSTICS.sampleEverySec))
        local session = perfSessions:StopCapture()
        assert.is_nil(session.meta.diagnostics)
        assert.is_nil(session.samples)
      end)

      it("is disarmed by unticking Capture next reload", function()
        perfSessions:ArmDiagnostics()
        perfSessions:SetArmedForNextReload(false)
        assert.is_false(perfSessions:IsArmedForNextReload())
        assert.are.equal(0, perfSessions:GetArmedLoads())
      end)

      it("samples every quarter second, keeping only changes, with the time on the capture's clock", function()
        now = 1000
        perfSessions:ArmDiagnostics()
        perfSessions:StartIfArmed()
        now = 1250
        fireTimers(perfSessions.DIAGNOSTICS.sampleEverySec)
        now = 1500
        probeState.level = 91
        fireTimers(perfSessions.DIAGNOSTICS.sampleEverySec)
        now = 1600
        local session = perfSessions:StopCapture()
        local whys, ats, levels = {}, {}, {}
        for i, sample in ipairs(session.samples) do
          whys[i], ats[i], levels[i] = sample.why, sample.at, sample.state.probe.level
        end
        assert.are.same({ "start", "tick", "stop" }, whys)
        assert.are.same({ 0, 500, 600 }, ats)
        assert.are.same({ 90, 91, 91 }, levels)
        fireTimers(perfSessions.DIAGNOSTICS.sampleEverySec)
        assert.are.equal(0, scheduled(perfSessions.DIAGNOSTICS.sampleEverySec), "no ticks once stopped")
      end)

      it("leaves an earlier capture's sampling behind when a new capture starts", function()
        perfSessions:ArmDiagnostics()
        perfSessions:StartIfArmed()
        perfSessions:StopCapture()
        perfSessions:StartIfArmed()
        assert.are.equal(2, scheduled(perfSessions.DIAGNOSTICS.sampleEverySec), "the old tick and the new one")
        fireTimers(perfSessions.DIAGNOSTICS.sampleEverySec)
        assert.are.equal(1, scheduled(perfSessions.DIAGNOSTICS.sampleEverySec), "only the new capture samples on")
        perfSessions:StopCapture()
      end)

      it("samples the collections' counts with the probe's state", function()
        local saved = _G.C_PetJournal
        _G.C_PetJournal = { GetNumPets = function() return 10, 4 end }
        perfSessions:ArmDiagnostics()
        perfSessions:StartIfArmed()
        local session = perfSessions:StopCapture()
        _G.C_PetJournal = saved
        assert.are.equal(4, session.samples[1].state.collections.petsOwned)
      end)

      it("samples on the events it listens to, and once the backpack has been read", function()
        local savedUtils, messages = _G.C_EventUtils, {}
        local savedRegisterMessage = events.RegisterMessage
        events.RegisterMessage = function(_, name, fn) messages[name] = fn end
        _G.C_EventUtils = { IsEventValid = function() return true end }
        perfSessions._eventsHooked = nil
        registered = {}
        perfSessions:Init()
        _G.C_EventUtils = savedUtils
        events.RegisterMessage = savedRegisterMessage
        for _, name in ipairs(perfSessions.SAMPLE_EVENTS) do
          assert.is_function(registered[name], name)
        end
        perfSessions:ArmDiagnostics()
        perfSessions:StartIfArmed()
        probeState.level = 91
        registered.SKILL_LINES_CHANGED("SKILL_LINES_CHANGED")
        probeState.level = 92
        registered.PET_JOURNAL_LIST_UPDATE("PET_JOURNAL_LIST_UPDATE")
        probeState.level = 93
        messages["items/RefreshBackpack/Done"]()
        local session = perfSessions:StopCapture()
        local whys = {}
        for i, sample in ipairs(session.samples) do whys[i] = sample.why end
        assert.are.same({ "start", "SKILL_LINES_CHANGED", "PET_JOURNAL_LIST_UPDATE", "items/RefreshBackpack/Done",
          "stop" }, whys)
      end)

      it("records a probe that fails, and keeps capturing", function()
        probe.Sample = function() error("not ready") end
        perfSessions:ArmDiagnostics()
        perfSessions:StartIfArmed()
        local session = perfSessions:StopCapture()
        assert.is_truthy(tostring(session.samples[1].state.probeError):find("not ready", 1, true))
      end)
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
