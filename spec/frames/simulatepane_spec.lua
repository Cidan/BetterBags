-- simulatepane_spec.lua -- The Simulate tab of the /bbdb debug window (frames/simulatepane.lua):
-- pick one of the events BetterBags listens to, a rate and a duration, and fire it through the
-- event simulator (debug/simulator.lua), with the bags opened and a capture when asked.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local context = LoadFreshBetterBagsModule("Context", "core/context.lua")
local events = LoadFreshBetterBagsModule("Events", "core/events.lua")
events:Init()

local createdStubs = {}
local function stubModule(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local list = stubModule("List")
local sessions = stubModule("PerfSessions")

ResetModuleStub("Simulator", "debug/simulator.lua")
LoadBetterBagsModule("debug/simulator.lua")
local simulator = addon:GetModule("Simulator")
ResetModuleStub("SimulatePane", "frames/simulatepane.lua")
LoadBetterBagsModule("frames/simulatepane.lua")
local simulatePane = addon:GetModule("SimulatePane")

describe("SimulatePane", function()
  local saved, started, savedBags

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  local function fakeList()
    local l = { frame = CreateFrame("Frame"), items = {} }
    function l:SetupDataSource(template, init) self.template, self.init = template, init end
    function l:InsertTable(t) for _, v in ipairs(t) do table.insert(self.items, v) end end
    function l:Wipe() self.items = {} end
    function l:GetAllItems() return self.items end
    return l
  end

  before_each(function()
    saved, started = {}, {}
    events:Init()
    simulator:Init()
    events:RegisterEvent("BAG_UPDATE_COOLDOWN", function() end)
    events:RegisterEvent("SPELLS_CHANGED", function() end)
    override(list, "Create", function() return fakeList() end)
    override(sessions, "IsCapturing", function() return false end)
    override(sessions, "StartCapture", function() return true end)
    override(sessions, "StopCapture", function() end)
    override(sessions, "RestrictionStates", function() return nil end)
    savedBags = addon.Bags
    addon.Bags = { Backpack = { Show = function() end } }
  end)

  after_each(function()
    if simulator:IsRunning() then simulator:Stop(context:New("spec")) end
    addon.Bags = savedBags
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
  end)

  teardown(function()
    ResetModuleStub("SimulatePane", "frames/simulatepane.lua")
    ResetModuleStub("Simulator", "debug/simulator.lua")
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  local function newPane()
    local pane = simulatePane:Create(CreateFrame("Frame", nil, UIParent))
    pane:Update()
    return pane
  end

  local function click(button)
    button:GetScript("OnClick")(button, "LeftButton")
  end

  it("lists the events BetterBags listens to, and picks one when clicked", function()
    local pane = newPane()
    local names = {}
    for _, entry in ipairs(pane.eventList.items) do table.insert(names, entry.event) end
    assert.are.same({ "BAG_UPDATE_COOLDOWN", "SPELLS_CHANGED" }, names)
    local button = CreateFrame("Button")
    button.Text = button:CreateFontString()
    pane.eventList.init(button, pane.eventList.items[2])
    click(button)
    assert.are.equal("SPELLS_CHANGED", pane.selected)
    assert.are.equal("SPELLS_CHANGED", pane.eventLabel:GetText())
  end)

  it("starts the simulator with what the fields say", function()
    override(simulator, "Start", function(_, _, opts) table.insert(started, opts) return true end)
    local pane = newPane()
    pane:SelectEvent("BAG_UPDATE_COOLDOWN")
    pane.rateBox:SetText("15")
    pane.durationBox:SetText("8")
    pane.payloadBox:SetText("3, x")
    pane.openBagsCheck:SetChecked(false)
    pane.captureCheck:SetChecked(true)
    click(pane.startButton)
    local opts = started[1]
    assert.are.same({ "BAG_UPDATE_COOLDOWN", 15, 8, false, true, "3, x", 2 },
      { opts.event, opts.rate, opts.duration, opts.openBags, opts.capture, opts.payloadText, opts.payloadCount })
    assert.are.same({ 3, "x" }, opts.payload)
  end)

  it("fills in the Dream Breath test from the user's captures", function()
    local pane = newPane()
    pane.openBagsCheck:SetChecked(false)
    click(pane.presetButton)
    assert.are.equal("BAG_UPDATE_COOLDOWN", pane.selected)
    assert.are.same({ "22", "30", "" }, { pane.rateBox:GetText(), pane.durationBox:GetText(), pane.payloadBox:GetText() })
    assert.is_true(pane.openBagsCheck:GetChecked())
    assert.is_true(pane.captureCheck:GetChecked())
  end)

  it("turns its button into Stop while a run goes, and shows the run's progress", function()
    local pane = newPane()
    pane:SelectEvent("BAG_UPDATE_COOLDOWN")
    pane.rateBox:SetText("10")
    pane.durationBox:SetText("2")
    pane.captureCheck:SetChecked(false)
    click(pane.startButton)
    assert.is_true(simulator:IsRunning())
    assert.are.equal("Stop", pane.startButton:GetText())
    simulator.frame:GetScript("OnUpdate")(simulator.frame, 0.5)
    pane:UpdateStatus()
    assert.are.equal("Firing BAG_UPDATE_COOLDOWN at 10/s: 5 of 20, 1.5 s left", pane.status:GetText())
    click(pane.startButton)
    assert.is_false(simulator:IsRunning())
    assert.are.equal("Start", pane.startButton:GetText())
    assert.are.equal("Fired BAG_UPDATE_COOLDOWN 5 times at 10/s", pane.status:GetText())
  end)

  it("says which addon restrictions are active, so a test in a dungeon can be checked", function()
    local pane = newPane()
    assert.are.equal("Addon restrictions: not available on this client", pane.restrictions:GetText())
    sessions.RestrictionStates = function()
      return { Combat = "Active", Encounter = "Inactive", Map = "Active", Chat = "Activating" }
    end
    pane:UpdateStatus()
    assert.are.equal("Addon restrictions: Chat (activating), Combat, Map", pane.restrictions:GetText())
    sessions.RestrictionStates = function() return { Combat = "Inactive", Map = "Inactive" } end
    pane:UpdateStatus()
    assert.are.equal("Addon restrictions: none active", pane.restrictions:GetText())
  end)

  it("asks for an event before starting", function()
    local pane = newPane()
    click(pane.startButton)
    assert.is_false(simulator:IsRunning())
    assert.are.equal("Pick an event to simulate.", pane.status:GetText())
  end)
end)
