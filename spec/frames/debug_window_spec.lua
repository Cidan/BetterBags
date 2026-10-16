-- debug_window_spec.lua -- The /bbdb debug window's tabs (frames/debug.lua).

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Earlier spec files stub or patch the shared Context and Events modules without restoring
-- them; these tests need real message delivery, so they load fresh copies.
local context = LoadFreshBetterBagsModule("Context", "core/context.lua")
local events = LoadFreshBetterBagsModule("Events", "core/events.lua")

-- Stub modules registered here are torn down again so later spec files can load the real
-- ones (AceAddon refuses to NewModule a name that already exists).
local createdStubs = {}
local function stubModule(name)
  local mod, created = StubBetterBagsModule(name)
  if created then
    table.insert(createdStubs, name)
  end
  return mod
end

stubModule("Constants")
local database = stubModule("Database")
local fonts = stubModule("Fonts")
fonts.UnitFrame12Yellow = fonts.UnitFrame12Yellow or CreateFont("BetterBagsDebugSpecYellow")
local tabs = stubModule("Tabs")
local list = stubModule("List")
local itemBrowser = stubModule("ItemBrowser")
local perfPane = stubModule("PerfPane")
local simulatePane = stubModule("SimulatePane")

local libWindow = LibStub:NewLibrary("LibWindow-1.1", 1) or LibStub("LibWindow-1.1")
libWindow.RegisterConfig = libWindow.RegisterConfig or function() end
libWindow.RestorePosition = libWindow.RestorePosition or function() end
libWindow.SavePosition = libWindow.SavePosition or function() end

LoadBetterBagsModule("render/render.lua")
LoadBetterBagsModule("render/drawable.lua")
LoadBetterBagsModule("sonata/engine.lua")
LoadBetterBagsModule("sonata/apply.lua")
LoadBetterBagsModule("sonata/decoration.lua")
LoadBetterBagsModule("window/window.lua")
ResetModuleStub("DebugWindow", "frames/debug.lua")
LoadBetterBagsModule("frames/debug.lua")

local debugWindow = addon:GetModule("DebugWindow")
local sonata = addon:GetModule("Sonata")
local render = addon:GetModule("Render")

describe("DebugWindow", function()
  local saved
  local tabNames
  local pane, simPane
  local debugMode, originalThemes

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, tbl[key] })
    tbl[key] = value
  end

  local function content()
    local c = { frame = CreateFrame("Frame"), updates = 0 }
    function c:Show() self.frame:Show() end
    function c:Hide() self.frame:Hide() end
    function c:IsShown() return self.frame:IsShown() end
    function c:Update() self.updates = self.updates + 1 end
    function c:GetFrame() return self.frame end
    function c:SetupDataSource() end
    function c:InsertTable() end
    function c:ScrollToEnd() end
    function c:Wipe() end
    return c
  end

  before_each(function()
    saved = {}
    tabNames = {}
    events:Init()
    render:Init()
    originalThemes = sonata.themes
    sonata.themes = {}
    sonata:Init()
    assert(loadfile("sonata/themes/base.lua"))("BetterBags")
    assert(loadfile("sonata/themes/default.lua"))("BetterBags")
    debugMode = false
    override(database, "GetTheme", function() return "Default" end)
    override(database, "SetTheme", function() end)
    override(database, "SetDebugMode", function(_, enabled) debugMode = enabled end)
    sonata:ApplyTheme(context:New("Test"), "Default")
    local realCreateFrame = _G.CreateFrame
    override(_G, "CreateFrame", function(frameType, name, parent, template)
      local f = realCreateFrame(frameType, name, parent, template)
      if template == "DefaultPanelFlatTemplate" then
        function f:SetTitle(title) self._title = title end
        function f:SetMovable() end
        f.StartMoving = function() end
        f.StopMovingOrSizing = function() end
      end
      return f
    end)
    override(_G, "CreateDataProvider", function() return {} end)
    override(database, "GetDebugMode", function() return false end)
    override(tabs, "Create", function(_, parent)
      local t = { frame = CreateFrame("Frame", nil, parent) }
      function t:SetClickHandler(fn) self.click = fn end
      function t:AddTab(_, name) table.insert(tabNames, name) end
      function t:SetTabByIndex() end
      return t
    end)
    override(list, "Create", function() return content() end)
    override(itemBrowser, "Create", function() return content() end)
    override(perfPane, "Create", function()
      pane = content()
      return pane
    end)
    override(simulatePane, "Create", function()
      simPane = content()
      return simPane
    end)
    debugWindow:Create(context:New("Test"))
  end)

  after_each(function()
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
    sonata.themes = originalThemes
  end)

  teardown(function()
    ResetModuleStub("DebugWindow", "frames/debug.lua")
    for i = #createdStubs, 1, -1 do
      ResetModuleStub(createdStubs[i])
    end
  end)

  it("is a titled Flat window of a fixed size the player can move", function()
    local w = debugWindow.window
    assert.are.equal("Flat", w.kind)
    assert.are.equal(debugWindow.frame, w.frame)
    assert.are.equal("BetterBagsDebugWindow", w.frame:GetName())
    assert.are.equal("BetterBags Debug Window", w:GetTitle())
    assert.are.same({ 800, 600 }, { w.frame:GetWidth(), w.frame:GetHeight() })
    assert.is_false(w.frame._resizable)
    assert.is_true(w.frame._movable)
  end)

  it("puts every tab's content in the window's content box", function()
    local box = debugWindow.window.content
    for i = 1, 5 do
      local frame = debugWindow.contentFrames[i].frame or debugWindow.contentFrames[i]
      assert.are.same({ "TOPLEFT", box, "TOPLEFT", 0, 0 }, { frame:GetPoint(1) }, "tab " .. i)
      assert.are.same({ "BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0 }, { frame:GetPoint(2) }, "tab " .. i)
    end
  end)

  it("turns debug mode off on a left click of its close button, and clears the log on a right click", function()
    local received = {}
    events:RegisterMessage("config/DebugMode", function(_, enabled) table.insert(received, { "mode", enabled }) end)
    events:RegisterMessage("debug/ClearLog", function() table.insert(received, { "clear" }) end)
    local close = debugWindow.window.decoration:GetCloseButton()
    assert.are.same({ "LeftButtonUp", "RightButtonUp" }, close._registeredClicks)
    close:GetScript("OnClick")(close, "RightButton")
    assert.are.same({ { "clear" } }, received)
    close:GetScript("OnClick")(close, "LeftButton")
    assert.is_false(debugMode)
    assert.are.same({ "mode", false }, received[#received])
  end)

  it("shows and hides with debug mode, at once", function()
    events:SendMessage(context:New("Test"), "config/DebugMode", true)
    assert.is_true(debugWindow.frame:IsShown())
    assert.are.equal(1, debugWindow.frame:GetAlpha())
    events:SendMessage(context:New("Test"), "config/DebugMode", false)
    assert.is_false(debugWindow.frame:IsShown())
  end)

  it("has a Performance tab after the existing ones, then the Simulate tab", function()
    assert.are.same({ "Debug Log", "Items", "Dump", "Performance", "Simulate" }, tabNames)
  end)

  it("keeps the Simulate pane hidden until its tab is chosen, then lists the events again", function()
    assert.is_false(simPane:IsShown())
    debugWindow:SwitchTab(5)
    assert.is_true(simPane:IsShown())
    assert.are.equal(1, simPane.updates)
    assert.is_false(pane:IsShown())
    debugWindow:SwitchTab(4)
    assert.is_false(simPane:IsShown())
  end)

  it("keeps the Performance pane hidden until its tab is chosen, then refreshes it", function()
    assert.is_false(pane:IsShown())
    debugWindow:SwitchTab(4)
    assert.is_true(pane:IsShown())
    assert.are.equal(1, pane.updates)
    debugWindow:SwitchTab(1)
    assert.is_false(pane:IsShown())
  end)
end)
