-- tabs_spec.lua -- The tab bars (frames/tabs.lua). Every tab has one decoration, made from
-- BetterBags' tab template on the tab and styled by Sonata as a Tab element: the theme draws
-- the tab and its states (normal, selected, a drop target), its fonts and its height, and the
-- bars measure their tabs again whenever a theme is applied.

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

local sectionFrame = stubModule("SectionFrame")
local database = stubModule("Database")
local groups = stubModule("Groups")
local const = stubModule("Constants")
const.BAG_KIND = const.BAG_KIND or { UNDEFINED = -1, BACKPACK = 0, BANK = 1 }
local fonts = stubModule("Fonts")
fonts.UnitFrame12Yellow = fonts.UnitFrame12Yellow or CreateFont("BetterBagsTabsSpecYellow")

LoadBetterBagsModule("core/async.lua")
LoadBetterBagsModule("render/render.lua")
LoadBetterBagsModule("render/drawable.lua")
LoadBetterBagsModule("sonata/engine.lua")
LoadBetterBagsModule("sonata/apply.lua")
LoadBetterBagsModule("sonata/decoration.lua")
ResetModuleStub("SonataElements", "sonata/elements.lua")
LoadBetterBagsModule("sonata/elements.lua")

ResetModuleStub("Tabs", "frames/tabs.lua")
LoadBetterBagsModule("frames/tabs.lua")
local tabs = addon:GetModule("Tabs")
local sonata = addon:GetModule("Sonata")
local elements = addon:GetModule("SonataElements")

describe("Tabs", function()
  local saved, originalThemes

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  -- withTheme registers a theme whose Tab style is style and applies it.
  local function withTheme(key, style)
    sonata:RegisterTheme({ Name = key, Elements = { Tab = style } })
    sonata:ApplyTheme(context:New("spec"), key)
  end

  before_each(function()
    saved = {}
    override(database, "GetTheme", function() return "Default" end)
    override(database, "SetTheme", function() end)
    originalThemes = sonata.themes
    sonata.themes = {}
    sonata:Init()
    assert(loadfile("sonata/themes/base.lua"))("BetterBags")
    assert(loadfile("sonata/themes/default.lua"))("BetterBags")
    override(groups, "IsDefaultGroup", function() return false end)
    sonata:ApplyTheme(context:New("spec"), "Default")
    override(sectionFrame, "draggingCategory", nil)
    override(sectionFrame, "draggingKind", nil)
    override(sectionFrame, "dragTargetTab", nil)
    tabs:Init()
  end)

  after_each(function()
    sonata.themes = originalThemes
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
  end)

  teardown(function()
    ResetModuleStub("Tabs", "frames/tabs.lua")
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  local bars = 0
  local function newBar(kind)
    bars = bars + 1
    return tabs:Create(CreateFrame("Frame", "TabsSpecBag" .. bars, UIParent), kind or const.BAG_KIND.BACKPACK)
  end

  it("makes each tab's decoration once, from BetterBags' tab template, on the tab, styled by Sonata", function()
    local registered = {}
    local register = sonata.RegisterElement
    override(sonata, "RegisterElement", function(self, kind, element)
      table.insert(registered, { kind, element })
      return register(self, kind, element)
    end)
    local bar = newBar()
    bar:AddTab(context:New("spec"), "Bags", 1)
    local tab = bar.tabIndex[1]
    local decoration = tabs:GetDecoration(context:New("spec"), tab)
    assert.are.equal(decoration, tabs:GetDecoration(context:New("spec"), tab))
    assert.is_truthy(decoration._template:find("BetterBagsSecureBagTabTemplate"))
    assert.are.equal(tab, decoration:GetParent())
    assert.are.same({ "TOPLEFT", tab, "TOPLEFT", 0, 0 }, { decoration:GetPoint(1) })
    local count = 0
    for _, entry in ipairs(registered) do
      if entry[2] == decoration then
        count = count + 1
        assert.are.equal("Tab", entry[1])
      end
    end
    assert.are.equal(1, count)
    assert.is_true(decoration:IsShown())
  end)

  it("draws the reorder marker as tall as the tab it sits beside", function()
    withTheme("Short", { Art = "Flat", Height = 26, Background = { Color = { 0, 0, 0, 1 } } })
    local bar = newBar()
    local ctx = context:New("spec")
    bar:AddTab(ctx, "Bags", 1)
    bar:AddTab(ctx, "Herbs", 2)
    tabs.currentTabFrame = bar
    tabs.draggingTab = bar.tabIndex[2]
    tabs:CreateDropPlaceholder()
    tabs:UpdateDropPlaceholder(1, false)
    assert.are.equal(26, tabs.dropPlaceholder:GetHeight())
    assert.are.equal(3, tabs.dropPlaceholder:GetWidth())
    tabs:HideDropPlaceholder()
    tabs.currentTabFrame, tabs.draggingTab = nil, nil
  end)

  it("shows the selected tab selected and the others normal, through the theme", function()
    local bar = newBar()
    local ctx = context:New("spec")
    bar:AddTab(ctx, "Bags", 1)
    bar:AddTab(ctx, "Herbs", 2)
    bar:SetTabByIndex(ctx, 2)
    local first = tabs:GetDecoration(ctx, bar.tabIndex[1])
    local second = tabs:GetDecoration(ctx, bar.tabIndex[2])
    assert.are.equal("normal", elements:GetTabState(first))
    assert.are.equal("selected", elements:GetTabState(second))
    assert.is_true(first.Left:IsShown())
    assert.is_false(first.LeftActive:IsShown())
    assert.is_false(second.Left:IsShown())
    assert.is_true(second.LeftActive:IsShown())
    bar:SetTabByIndex(ctx, 1)
    assert.are.equal("selected", elements:GetTabState(first))
    assert.are.equal("normal", elements:GetTabState(second))
  end)

  it("lights a tab up while a section is dragged over it, and puts its state back after", function()
    local bar = newBar()
    local ctx = context:New("spec")
    bar:AddTab(ctx, "Bags", 1)
    bar:AddTab(ctx, "Herbs", 2)
    bar:SetTabByIndex(ctx, 1)
    sectionFrame.draggingCategory = "Herbalism"
    sectionFrame.draggingKind = const.BAG_KIND.BACKPACK
    for index, state in ipairs({ "selected", "normal" }) do
      local decoration = tabs:GetDecoration(ctx, bar.tabIndex[index])
      decoration:GetScript("OnEnter")(decoration)
      assert.is_true(decoration.LeftActive:IsShown())
      assert.are.equal(bar.tabIndex[index].id, sectionFrame.dragTargetTab)
      decoration:GetScript("OnLeave")(decoration)
      assert.are.equal(state, elements:GetTabState(decoration))
      assert.are.equal(state == "selected", decoration.LeftActive:IsShown())
      assert.is_nil(sectionFrame.dragTargetTab)
    end
  end)

  it("takes the drop highlight off every tab when a drag ends", function()
    local bar = newBar()
    local ctx = context:New("spec")
    bar:AddTab(ctx, "Bags", 1)
    bar:AddTab(ctx, "Herbs", 2)
    bar:SetTabByIndex(ctx, 1)
    local herbs = tabs:GetDecoration(ctx, bar.tabIndex[2])
    elements:SetTabState(herbs, "drop")
    tabs:ResetDropHighlights(bar)
    assert.is_false(herbs.LeftActive:IsShown())
    assert.is_true(tabs:GetDecoration(ctx, bar.tabIndex[1]).LeftActive:IsShown())
  end)

  it("keeps the theme's tab font, and makes the tab as tall as the theme's", function()
    withTheme("Tall", { Height = 40, Font = { Object = "GameFontHighlight" } })
    local bar = newBar()
    local ctx = context:New("spec")
    bar:AddTab(ctx, "Bags", 1)
    local tab = bar.tabIndex[1]
    local decoration = tabs:GetDecoration(ctx, tab)
    assert.are.equal(GameFontHighlight, decoration.Text:GetFontObject())
    assert.are.equal(40, tab:GetHeight())
    assert.are.equal(decoration:GetWidth(), tab:GetWidth())
  end)

  it("measures every bar's tabs again after a theme is applied", function()
    local bar = newBar()
    local other = newBar(const.BAG_KIND.BANK)
    local ctx = context:New("spec")
    bar:AddTab(ctx, "Bags", 1)
    other:AddTab(ctx, "Bank", 1)
    other:SetTabByIndex(ctx, 1)
    assert.are.equal(32, bar.tabIndex[1]:GetHeight())
    withTheme("Short", { Height = 24 })
    assert.are.equal(24, bar.tabIndex[1]:GetHeight())
    assert.are.equal(24, other.tabIndex[1]:GetHeight())
    assert.are.equal("selected", elements:GetTabState(tabs:GetDecoration(ctx, other.tabIndex[1])))
  end)

  describe("icon tabs", function()
    -- The "+" (new group) tab draws an atlas icon instead of a label, in the tab template's
    -- content region: on Classic ~10px above the frame center (deselectedTextY), on retail
    -- the center.
    local function resizeWith(deselectedTextY)
      local bar = newBar()
      local ctx = context:New("resize")
      bar:AddTab(ctx, "New Group", 0)
      local tab = bar.tabIndex[1]
      local decoration = tabs:GetDecoration(ctx, tab)
      decoration.deselectedTextY = deselectedTextY
      tab.icon = "communities-icon-addchannelplus"
      bar:ResizeTabByIndex(ctx, 1)
      return decoration
    end

    it("anchors the '+' icon to the content region on Classic (deselectedTextY)", function()
      local decoration = resizeWith(10)
      assert.are.same({ "CENTER", decoration, "CENTER", 0, 6 }, { decoration.tabIcon:GetPoint(1) })
      assert.are.equal("communities-icon-addchannelplus", decoration.tabIcon:GetAtlas())
      assert.are.equal("", decoration.Text:GetText())
      assert.are.equal(50, decoration:GetWidth())
    end)

    it("keeps the retail anchor when the template has no deselectedTextY", function()
      local decoration = resizeWith(nil)
      assert.are.same({ "CENTER", decoration, "CENTER", 0, 1 }, { decoration.tabIcon:GetPoint(1) })
    end)
  end)
end)
