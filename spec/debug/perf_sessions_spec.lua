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
    perfSessions._logoutHooked = nil
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
      local pipe = io.popen("find animations bags config core data debug forms frames integrations themes util views -name '*.lua'")
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
      local session = perfSessions:StopCapture()
      assert.are.equal("reload", session.meta.reason)

      assert.is_false(perfSessions:StartIfArmed())
      assert.is_false(perfSessions:IsCapturing())
    end)
  end)
end)
