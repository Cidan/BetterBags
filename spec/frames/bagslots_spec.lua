-- bagslots_spec.lua -- The "Show Bags" slots panel (frames/bagslots.lua): a Slots window
-- (window/window.lua) hanging below its bag, sized to its bag buttons plus the theme's padding,
-- shown in place of the bag's group tabs. The theme decides its chrome per client (Default:
-- a headerless flat panel on retail, a tooltip backdrop on Classic, Blizzard's tooltip frame on
-- WoW: Forever; sonata.md section 3b).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")

local events = addon:GetModule("Events")
events:Init()
local context = addon:GetModule("Context")

local createdStubs = {}
local function stubModule(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local L = stubModule("Localization")
L.G = function(_, key) return key end

local database = stubModule("Database")
local savedTheme = "Default"
local originals = { GetGroupsEnabled = database.GetGroupsEnabled, GetTheme = database.GetTheme, SetTheme = database.SetTheme }

local const = stubModule("Constants")
const.BAG_KIND = const.BAG_KIND or { BACKPACK = 0, BANK = 1 }
const.BACKPACK_ONLY_BAGS_LIST = { 1, 2, 3, 4 }
const.BANK_ONLY_BAGS_LIST = { 5, 6, 7, 8 }

local debug = stubModule("Debug")
debug.Log = function() end

local fonts = stubModule("Fonts")
fonts.UnitFrame12Yellow = fonts.UnitFrame12Yellow or CreateFont("BetterBagsBagSlotsSpecYellow")

-- Bag buttons record their draws.
local bagButton = stubModule("BagButton")
local madeButtons = {}
local originalButtonCreate = bagButton.Create

-- The grid lays its cells out at a size the test sets.
local grid = stubModule("Grid")
local gridSize = { 200, 37 }
local originalGridCreate = grid.Create

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
ResetModuleStub("BagSlots", "frames/bagslots.lua")
LoadBetterBagsModule("frames/bagslots.lua")

local sonata = addon:GetModule("Sonata")
local render = addon:GetModule("Render")
local bagSlots = addon:GetModule("BagSlots")

describe("BagSlots panel", function()
  local savedFlags, savedBags, originalThemes, originalSend, originalPlaySound
  local tabsShown, groupsEnabled, bagInvalidations

  before_each(function()
    render:Init()
    originalThemes = sonata.themes
    sonata.themes = {}
    sonata:Init()
    assert(loadfile("sonata/themes/base.lua"))("BetterBags")
    assert(loadfile("sonata/themes/default.lua"))("BetterBags")
    savedTheme = "Default"
    database.GetTheme = function() return savedTheme end
    database.SetTheme = function(_, key) savedTheme = key end
    groupsEnabled = false
    database.GetGroupsEnabled = function() return groupsEnabled end
    originalSend = events.SendMessage
    events.SendMessage = function() end
    originalPlaySound = _G.PlaySound
    _G.PlaySound = function() end
    savedFlags = { isRetail = addon.isRetail, isForever = addon.isForever, isClassic = addon.isClassic }
    addon.isRetail, addon.isForever, addon.isClassic = true, false, false
    madeButtons = {}
    bagButton.Create = function()
      local button = { frame = CreateFrame("Button"), draws = 0 }
      function button:SetBag(_, bag) self.bag = bag end
      function button:Draw() self.draws = self.draws + 1 end
      table.insert(madeButtons, button)
      return button
    end
    gridSize = { 200, 37 }
    grid.Create = function(_, parent)
      local g = { cells = {}, container = CreateFrame("Frame", nil, parent) }
      function g:GetContainer() return self.container end
      function g:HideScrollBar() end
      function g:EnableMouseWheelScroll(enabled) self.wheel = enabled end
      function g:Show() end
      function g:AddCell(_, cell) table.insert(self.cells, cell) end
      function g:Draw() return gridSize[1], gridSize[2] end
      return g
    end
    tabsShown, bagInvalidations = true, 0
    savedBags = addon.Bags
    addon.Bags = { Backpack = {
      tabs = { frame = {
        IsShown = function() return tabsShown end,
        Show = function() tabsShown = true end,
        Hide = function() tabsShown = false end,
      } },
      window = { Invalidate = function() bagInvalidations = bagInvalidations + 1 end },
    } }
  end)

  after_each(function()
    events.SendMessage = originalSend
    _G.PlaySound = originalPlaySound
    sonata.themes = originalThemes
    bagButton.Create, grid.Create = originalButtonCreate, originalGridCreate
    for k, v in pairs(savedFlags) do addon[k] = v end
    addon.Bags = savedBags
    for k, v in pairs(originals) do database[k] = v end
  end)

  teardown(function()
    ResetModuleStub("BagSlots", "frames/bagslots.lua")
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  local function apply()
    sonata:ApplyTheme(context:New("spec"), "Default")
  end

  local function newPanel(kind)
    local bagFrame = CreateFrame("Frame", nil, UIParent)
    local panel = bagSlots:CreatePanel(context:New("spec"), kind or const.BAG_KIND.BACKPACK, bagFrame)
    apply()
    return panel, bagFrame
  end

  local function showNow(panel)
    panel:Draw(context:New("spec"))
    panel:Show()
    if panel.window.showAnimation then panel.window.showAnimation:_complete() end
  end

  -- texture-sharpening.md: its bag buttons' art, without the client's sharpening.
  it("draws its textures without the client's sharpening", function()
    local panel = newPanel()
    local parts = { panel.frame:CreateTexture(), CreateFrame("Button", nil, panel.window.content):CreateTexture() }
    for _, t in ipairs(parts) do
      t:SetSnapToPixelGrid(true)
      t:SetTexelSnappingBias(1)
    end
    panel:Draw(context:New("spec"))
    for i, t in ipairs(parts) do
      assert.is_false(t:IsSnappingToPixelGrid(), "part " .. i)
      assert.are.equal(0, t:GetTexelSnappingBias(), "part " .. i)
    end
  end)

  it("is a Slots window hanging below its bag, hidden until shown", function()
    local panel, bagFrame = newPanel()
    assert.are.equal("Slots", panel.window.kind)
    assert.are.equal(panel.window.frame, panel.frame)
    assert.are.equal("BackpackBagSlots", panel.frame:GetName())
    assert.are.equal(bagFrame, panel.frame:GetParent())
    assert.are.same({ "TOPLEFT", bagFrame, "BOTTOMLEFT", 0, -2 }, { panel.frame:GetPoint(1) })
    assert.is_nil(panel.frame:GetScript("OnDragStart"))
    assert.is_false(panel:IsShown())
  end)

  it("holds a bag button for each bag of its kind, in a grid that does not scroll", function()
    local panel = newPanel(const.BAG_KIND.BANK)
    assert.are.equal("BankBagSlots", panel.frame:GetName())
    assert.are.equal(4, #madeButtons)
    assert.are.same({ 5, 6, 7, 8 }, { madeButtons[1].bag, madeButtons[2].bag, madeButtons[3].bag, madeButtons[4].bag })
    assert.are.equal(4, #panel.content.cells)
    assert.is_false(panel.content.wheel)
  end)

  it("is as big as its bags plus the theme's room around them on retail", function()
    local panel = newPanel()
    showNow(panel)
    assert.are.same({ 200 + 10 + 6, 37 + 30 + 12 }, { panel.frame:GetWidth(), panel.frame:GetHeight() })
  end)

  it("centers its bags with even padding on Classic and on WoW: Forever", function()
    for _, flags in ipairs({ { false, false, true }, { true, true, false } }) do
      addon.isRetail, addon.isForever, addon.isClassic = flags[1], flags[2], flags[3]
      local panel = newPanel()
      showNow(panel)
      assert.are.same({ 200 + 16, 37 + 16 }, { panel.frame:GetWidth(), panel.frame:GetHeight() })
    end
  end)

  it("keeps its chrome below its bags: a backdrop on its own frame on Classic, a frame below it on Forever", function()
    addon.isRetail, addon.isForever, addon.isClassic = false, false, true
    local panel = newPanel()
    assert.is_not_nil(panel.frame._backdrop)
    assert.is_nil(panel.window.decoration:GetTemplateFrame())
    addon.isRetail, addon.isForever, addon.isClassic = true, true, false
    panel = newPanel()
    local tmpl = panel.window.decoration:GetTemplateFrame()
    assert.is_true(tmpl:GetFrameLevel() < panel.content:GetContainer():GetFrameLevel())
  end)

  it("draws its bag buttons, and lays out again at once while shown", function()
    local panel = newPanel()
    showNow(panel)
    assert.are.equal(1, madeButtons[1].draws)
    gridSize = { 300, 37 }
    panel:Draw(context:New("spec"))
    assert.are.equal(2, madeButtons[1].draws)
    assert.are.equal(300 + 16, panel.frame:GetWidth())
  end)

  it("shows below its bag where the theme says, in place of the bag's tabs, and calls back once shown", function()
    addon.isRetail, addon.isForever = true, true
    local panel, bagFrame = newPanel()
    local shown = false
    panel:Show(function() shown = true end)
    assert.are.same({ "TOPLEFT", bagFrame, "BOTTOMLEFT", 4, -2 }, { panel.frame:GetPoint(1) })
    assert.is_false(tabsShown)
    assert.is_true(panel.tabsWereShown)
    assert.is_true(panel.window.showAnimation:IsPlaying())
    assert.is_false(shown)
    panel.window.showAnimation:_complete()
    assert.is_true(shown)
  end)

  -- A theme may place the panel anywhere around its bag (Layout.Points, relative to the bag),
  -- above it for instance, instead of hanging it below (Layout.Offset).
  it("sits where the theme's Layout.Points say, relative to its bag", function()
    sonata:RegisterTheme({ Name = "Above", Windows = { Slots = { Layout = {
      Points = { { Point = "BOTTOMLEFT", RelativePoint = "TOPLEFT", X = 3, Y = 5 } },
    } } } })
    local panel, bagFrame = newPanel()
    sonata:ApplyTheme(context:New("spec"), "Above")
    panel:Show()
    assert.are.equal(1, panel.frame:GetNumPoints())
    assert.are.same({ "BOTTOMLEFT", bagFrame, "TOPLEFT", 3, 5 }, { panel.frame:GetPoint(1) })
  end)

  it("remembers the tabs were shown across a second Show", function()
    local panel = newPanel()
    panel:Show()
    panel:Show()
    assert.is_true(panel.tabsWereShown)
  end)

  it("hides with the theme's fade, then gives the bag its tabs back and calls back", function()
    local panel = newPanel()
    showNow(panel)
    local hidden = false
    panel:Hide(function() hidden = true end)
    assert.is_true(panel.window:IsClosing())
    assert.is_false(tabsShown)
    panel.window.hideAnimation:_complete()
    assert.is_false(panel:IsShown())
    assert.is_true(tabsShown)
    assert.is_true(hidden)
  end)

  it("gives the bag its tabs back on close when groups are on, even if they were hidden", function()
    local panel = newPanel()
    tabsShown = false
    panel:Show()
    groupsEnabled = true
    panel:OnClose(context:New("spec"))
    assert.is_true(tabsShown)
  end)

  it("lays its bag out again after it renders, since the bag is never narrower than the panel", function()
    local panel = newPanel()
    showNow(panel)
    local before = bagInvalidations
    panel:Draw(context:New("spec"))
    assert.are.equal(before + 1, bagInvalidations)
  end)
end)
