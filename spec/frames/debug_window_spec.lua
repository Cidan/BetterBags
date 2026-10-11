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
local tabs = stubModule("Tabs")
local list = stubModule("List")
local itemBrowser = stubModule("ItemBrowser")
local perfPane = stubModule("PerfPane")

LoadBetterBagsModule("frames/debug.lua")

local debugWindow = addon:GetModule("DebugWindow")

describe("DebugWindow", function()
  local saved
  local tabNames
  local pane

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
    debugWindow:Create(context:New("Test"))
  end)

  after_each(function()
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
  end)

  teardown(function()
    ResetModuleStub("DebugWindow", "frames/debug.lua")
    for i = #createdStubs, 1, -1 do
      ResetModuleStub(createdStubs[i])
    end
  end)

  it("has a Performance tab after the existing ones", function()
    assert.are.same({ "Debug Log", "Items", "Dump", "Performance" }, tabNames)
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
