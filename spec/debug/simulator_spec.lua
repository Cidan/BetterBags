-- simulator_spec.lua -- The event simulator (debug/simulator.lua): fires one of the WoW events
-- BetterBags listens to through BetterBags' own dispatcher, at a rate, for a duration, with
-- the bags opened and a profiler capture around it when asked. It reproduces BetterBags' side
-- of an event storm (Dream Breath's BAG_UPDATE_COOLDOWN fires) wherever the player stands.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadFreshBetterBagsModule("Context", "core/context.lua")
local events = LoadFreshBetterBagsModule("Events", "core/events.lua")
events:Init()
local context = addon:GetModule("Context")
local perf = addon:GetModule("Perf")

local sessions, createdSessions = StubBetterBagsModule("PerfSessions")

ResetModuleStub("Simulator", "debug/simulator.lua")
LoadBetterBagsModule("debug/simulator.lua")
local simulator = addon:GetModule("Simulator")

describe("Simulator", function()
  local saved, received, captures, savedBags, shown

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  before_each(function()
    saved, received, captures, shown = {}, {}, {}, 0
    events:Init()
    simulator:Init()
    events:RegisterEvent("BAG_UPDATE_COOLDOWN", function(ctx, ...)
      table.insert(received, { ctx = ctx, args = { ... } })
    end)
    events:RegisterEvent("SPELLS_CHANGED", function() end)
    events:RegisterEvent("PLAYER_LOGOUT", function() end)
    events:RegisterEvent("ADDON_LOADED", function() end)
    local capturing = false
    override(sessions, "IsCapturing", function() return capturing end)
    override(sessions, "StartCapture", function(_, reason, extra)
      capturing = true
      table.insert(captures, { "start", reason, extra })
      return true
    end)
    override(sessions, "StopCapture", function()
      capturing = false
      table.insert(captures, { "stop" })
    end)
    savedBags = addon.Bags
    addon.Bags = { Backpack = { Show = function() shown = shown + 1 end } }
  end)

  after_each(function()
    if simulator:IsRunning() then simulator:Stop(context:New("spec")) end
    addon.Bags = savedBags
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
  end)

  teardown(function()
    ResetModuleStub("Simulator", "debug/simulator.lua")
    if createdSessions then ResetModuleStub("PerfSessions") end
  end)

  -- tick runs the driver's OnUpdate for one frame of elapsed seconds.
  local function tick(elapsed)
    local frame = simulator.frame
    local script = frame:GetScript("OnUpdate")
    if script then script(frame, elapsed) end
  end

  it("offers the events BetterBags listens to, sorted, but not its load and logout events", function()
    assert.are.same({ "BAG_UPDATE_COOLDOWN", "SPELLS_CHANGED" }, simulator:GetEvents())
  end)

  it("fires the event through BetterBags' own dispatcher at the rate, for the duration", function()
    assert.is_true(simulator:Start(context:New("spec"), { event = "BAG_UPDATE_COOLDOWN", rate = 10, duration = 2 }))
    assert.is_true(simulator:IsRunning())
    tick(0.05)
    assert.are.equal(0, #received)
    tick(0.05)
    assert.are.equal(1, #received)
    -- A slow frame catches up with every fire due in it.
    tick(0.5)
    assert.are.equal(6, #received)
    assert.are.equal("BAG_UPDATE_COOLDOWN", received[1].ctx:Event())
    local status = simulator:GetStatus()
    assert.are.same({ "BAG_UPDATE_COOLDOWN", 6, 20, 10, 2 }, { status.event, status.fired, status.total, status.rate, status.duration })
    tick(5)
    assert.are.equal(20, #received)
    assert.is_false(simulator:IsRunning())
    assert.is_nil(simulator.frame:GetScript("OnUpdate"))
  end)

  it("hands each fire the payload, after the event's name, as a real event does", function()
    simulator:Start(context:New("spec"), { event = "BAG_UPDATE_COOLDOWN", rate = 1, duration = 1, payload = { 3, "x", true } })
    tick(1)
    -- As for a real event, handlers get the event's name first, then its payload.
    assert.are.same({ "BAG_UPDATE_COOLDOWN", 3, "x", true }, received[1].args)
  end)

  it("marks simulated fires in the profiler's call trace", function()
    local spans = {}
    override(perf, "active", true)
    override(perf, "Enter", function(_, label) table.insert(spans, label) return #spans end)
    override(perf, "Exit", function() end)
    simulator:Start(context:New("spec"), { event = "BAG_UPDATE_COOLDOWN", rate = 1, duration = 1 })
    tick(1)
    assert.are.equal("[simulate] BAG_UPDATE_COOLDOWN", spans[1])
    assert.are.equal("[event] BAG_UPDATE_COOLDOWN", spans[2])
  end)

  it("opens the bags first, and captures the run when asked, stopping the capture it started", function()
    simulator:Start(context:New("spec"), { event = "BAG_UPDATE_COOLDOWN", rate = 12, duration = 1, openBags = true, capture = true })
    assert.are.equal(1, shown)
    assert.are.equal("start", captures[1][1])
    assert.are.equal("simulate", captures[1][2])
    assert.are.same({ event = "BAG_UPDATE_COOLDOWN", rate = 12, duration = 1, payload = "", openBags = true },
      captures[1][3].simulation)
    tick(1)
    assert.are.same({ "stop" }, captures[2])
  end)

  it("leaves a capture it did not start running, and stops early on Stop", function()
    sessions:StartCapture("manual")
    simulator:Start(context:New("spec"), { event = "BAG_UPDATE_COOLDOWN", rate = 10, duration = 5, capture = true })
    tick(0.25)
    simulator:Stop(context:New("spec"))
    assert.is_false(simulator:IsRunning())
    assert.are.equal(2, #received)
    assert.are.equal(1, #captures)
  end)

  it("refuses an event BetterBags does not listen to, a second run, and clamps the rate and duration", function()
    assert.is_false(simulator:Start(context:New("spec"), { event = "UNIT_SPELLCAST_START", rate = 10, duration = 1 }))
    assert.is_false(simulator:Start(context:New("spec"), { event = "PLAYER_LOGOUT", rate = 10, duration = 1 }))
    assert.is_true(simulator:Start(context:New("spec"), { event = "BAG_UPDATE_COOLDOWN", rate = 100000, duration = 0 }))
    assert.is_false(simulator:Start(context:New("spec"), { event = "SPELLS_CHANGED", rate = 1, duration = 1 }))
    local status = simulator:GetStatus()
    assert.are.equal(simulator.RATE.max, status.rate)
    assert.are.equal(simulator.DURATION.min, status.duration)
  end)

  it("reads a payload typed as comma-separated values", function()
    local values, n = simulator:ParsePayload(' 3, -1.5, true, false, nil, hello , "quoted" ')
    assert.are.equal(7, n)
    assert.are.same({ 3, -1.5, true, false, nil, "hello", "quoted" }, { values[1], values[2], values[3], values[4], values[5], values[6], values[7] })
    local empty, none = simulator:ParsePayload("  ")
    assert.are.equal(0, none)
    assert.are.same({}, empty)
  end)
end)
