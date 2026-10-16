-- elements_spec.lua -- Element styles applied by Sonata (sonata/elements.lua): item button
-- decorations, tabs and their states, section headers, the in-bag search box, the bag menu
-- button, and dialog buttons and edit boxes. Every style sets everything it controls, so
-- switching themes leaves nothing of the last one behind.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")

-- Stubs this file creates are removed after it (the teardown at the end), so a later spec
-- file can load the real modules.
local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local db = trackStub("Database")
db.GetTheme = db.GetTheme or function() return "Default" end
db.SetTheme = db.SetTheme or function() end

local fonts = trackStub("Fonts")
fonts.UnitFrame12Yellow = fonts.UnitFrame12Yellow or { name = "UnitFrame12Yellow" }
fonts.UnitFrame12White = fonts.UnitFrame12White or { name = "UnitFrame12White" }

LoadBetterBagsModule("sonata/engine.lua")
LoadBetterBagsModule("sonata/apply.lua")
LoadBetterBagsModule("sonata/elements.lua")

local sonata = addon:GetModule("Sonata")
local elements = addon:GetModule("SonataElements")

_G.GameFontNormalSmall = _G.GameFontNormalSmall or { name = "GameFontNormalSmall" }
_G.GameFontHighlightSmall = _G.GameFontHighlightSmall or { name = "GameFontHighlightSmall" }
_G.NumberFontNormal = _G.NumberFontNormal or { name = "NumberFontNormal" }
_G.GameFontNormal = _G.GameFontNormal or { name = "GameFontNormal" }
_G.GameFontDisableSmall = _G.GameFontDisableSmall or { name = "GameFontDisableSmall" }

-- itemDecoration builds what ContainerFrameItemButtonTemplate gives a decoration: the icon,
-- count, quality border, state textures, quest icon and upgrade arrow.
local function itemDecoration()
  local b = CreateFrame("ItemButton", nil, UIParent)
  b:SetSize(37, 37)
  b.icon = b:CreateTexture(nil, "BORDER")
  b.IconTexture = b.icon
  b.Count = b:CreateFontString(nil, "ARTWORK", "NumberFontNormal")
  b.Count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -5, 2)
  b.IconBorder = b:CreateTexture(nil, "OVERLAY")
  b.IconQuestTexture = b:CreateTexture(nil, "OVERLAY")
  b.UpgradeIcon:SetAtlas("bags-greenarrow")
  return b
end

-- tabDecoration builds what PanelTabButtonTemplate gives a tab.
local function tabDecoration()
  local t = CreateFrame("Button", nil, UIParent)
  for _, key in ipairs({ "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive",
    "LeftHighlight", "MiddleHighlight", "RightHighlight" }) do
    t[key] = t:CreateTexture(nil, "BACKGROUND")
  end
  t.LeftHighlight:SetAlpha(0.4)
  t.MiddleHighlight:SetAlpha(0.4)
  t.RightHighlight:SetAlpha(0.4)
  t.Text = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  return t
end

describe("SonataElements", function()
  before_each(function()
    sonata:Init()
  end)

  it("registers a styler for every element kind", function()
    for _, kind in ipairs({ "ItemButton", "Tab", "SectionHeader", "SearchBox", "BagButton", "Button", "EditBox" }) do
      assert.is_function(sonata.elementStylers[kind], kind)
    end
  end)

  describe("item buttons", function()
    it("insets and crops the icon", function()
      local b = itemDecoration()
      elements:StyleItemButton(b, { Icon = { Inset = 1, TexCoords = { 0.08, 0.92, 0.08, 0.92 } } })
      local point, relativeTo, _, x, y = b.icon:GetPoint(1)
      assert.are.same({ "TOPLEFT", b, 1, -1 }, { point, relativeTo, x, y })
      assert.are.same({ 0.08, 0.92, 0.08, 0.92 }, b.icon._texCoords)
      elements:StyleItemButton(b, {})
      assert.are.equal(b, b.icon._allPoints)
      assert.are.same({ 0, 1, 0, 1 }, b.icon._texCoords)
    end)

    it("sets the highlight and pushed art, back to Blizzard's without a style", function()
      local b = itemDecoration()
      elements:StyleItemButton(b, {
        Highlight = { Color = { 1, 1, 1, 0.3 }, BlendMode = "ADD", Inset = { Left = 1, Right = 1, Top = 1, Bottom = 1 } },
        Pushed = { Color = { 0.9, 0.8, 0.1, 0.3 }, BlendMode = "ADD" },
      })
      assert.are.same({ r = 1, g = 1, b = 1, a = 0.3 }, b:GetHighlightTexture()._vertexColor)
      assert.are.equal("ADD", b:GetHighlightTexture():GetBlendMode())
      elements:StyleItemButton(b, {})
      assert.are.equal("Interface\\Buttons\\ButtonHilight-Square", b:GetHighlightTexture():GetTexture())
      assert.are.equal("", b:GetPushedTexture():GetTexture())
      assert.are.same({ r = 1, g = 1, b = 1, a = 1 }, b:GetHighlightTexture()._vertexColor)
    end)

    it("draws a backdrop behind the icon with a pixel border, and removes it", function()
      local b = itemDecoration()
      elements:StyleItemButton(b, {
        Backdrop = { Color = { 0.1, 0.1, 0.1, 1 }, BorderColor = { 0, 0, 0, 1 }, EdgeSize = 1 },
      })
      local skin = b.sonataSkin
      assert.are.equal("BACKGROUND", skin.fill._drawLayer)
      assert.are.same({ r = 0.1, g = 0.1, b = 0.1, a = 1 }, skin.fill._colorTexture)
      assert.is_true(skin.fill:IsShown())
      for _, edge in ipairs(skin.edges) do
        assert.is_true(edge:IsShown())
        assert.are.same({ r = 0, g = 0, b = 0, a = 1 }, edge._colorTexture)
      end
      assert.are.equal(1, skin.edges[1]:GetHeight())
      elements:StyleItemButton(b, {})
      assert.is_false(skin.fill:IsShown())
      for _, edge in ipairs(skin.edges) do
        assert.is_false(edge:IsShown())
      end
    end)

    it("colors the backdrop border by quality when the style says the border shows quality", function()
      local b = itemDecoration()
      elements:StyleItemButton(b, {
        Backdrop = { BorderColor = { 0, 0, 0, 1 } },
        QualityBorder = "Backdrop",
      })
      assert.is_true(elements:DrawItemQuality(b, { 0.1, 1, 0.1, 1 }))
      assert.are.same({ r = 0.1, g = 1, b = 0.1, a = 1 }, b.sonataSkin.edges[1]._colorTexture)
      assert.is_false(b.IconBorder:IsShown())
      assert.is_true(elements:DrawItemQuality(b, nil))
      assert.are.same({ r = 0, g = 0, b = 0, a = 1 }, b.sonataSkin.edges[1]._colorTexture)
    end)

    it("leaves quality to BetterBags' glow when the style does not take it", function()
      local b = itemDecoration()
      elements:StyleItemButton(b, {})
      assert.is_false(elements:DrawItemQuality(b, { 1, 0, 0, 1 }))
    end)

    it("restyles the upgrade arrow and the count, back to Blizzard's", function()
      local b = itemDecoration()
      elements:StyleItemButton(b, {
        UpgradeIcon = { Texture = "Interface\\AddOns\\ElvUI\\BagUpgradeIcon", Scale = 1.2 },
        Count = { Font = { Object = "UnitFrame12White" } },
      })
      assert.are.equal("Interface\\AddOns\\ElvUI\\BagUpgradeIcon", b.UpgradeIcon:GetTexture())
      assert.are.equal(1.2, b.UpgradeIcon:GetScale())
      assert.are.equal(fonts.UnitFrame12White, b.Count._fontObject)
      elements:StyleItemButton(b, {})
      assert.are.equal("bags-greenarrow", b.UpgradeIcon:GetAtlas())
      assert.are.equal(1, b.UpgradeIcon:GetScale())
      assert.are.equal(_G.NumberFontNormal, b.Count._fontObject)
    end)

    it("swaps a quest item's icon art after Blizzard draws it, and leaves Blizzard's otherwise", function()
      local b = itemDecoration()
      elements:StyleItemButton(b, { QuestIcon = { Texture = "elv-quest.tga" }, QuestBorderColor = { 1, 0.8, 0, 1 } })
      b.IconQuestTexture:SetTexture("Interface\\ContainerFrame\\UI-Icon-QuestBorder")
      b.IconBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
      b.IconBorder:SetBlendMode("ADD")
      b.IconBorder:SetTexCoord(0.2, 0.8, 0.2, 0.8)
      elements:DrawItemQuest(b, { isQuestItem = true, isActive = false })
      assert.are.equal("elv-quest.tga", b.IconQuestTexture:GetTexture())
      assert.are.same({ r = 1, g = 0.8, b = 0, a = 1 }, b.IconBorder._vertexColor)
      assert.are.equal("Interface\\Common\\WhiteIconFrame", b.IconBorder:GetTexture())
      assert.are.equal("BLEND", b.IconBorder:GetBlendMode())
      assert.are.same({ 0, 1, 0, 1 }, b.IconBorder._texCoords)
      assert.is_true(b.IconBorder:IsShown())
      elements:StyleItemButton(b, {})
      b.IconQuestTexture:SetTexture("Interface\\ContainerFrame\\UI-Icon-QuestBorder")
      elements:DrawItemQuest(b, { isQuestItem = true, isActive = false })
      assert.are.equal("Interface\\ContainerFrame\\UI-Icon-QuestBorder", b.IconQuestTexture:GetTexture())
    end)

    it("uses the quest starter art for an item that starts a quest", function()
      local b = itemDecoration()
      elements:StyleItemButton(b, { QuestIcon = { Texture = "quest.tga" }, QuestStarterIcon = { Texture = "bang.tga" } })
      elements:DrawItemQuest(b, { isQuestItem = false, questID = 123, isActive = false })
      assert.are.equal("bang.tga", b.IconQuestTexture:GetTexture())
      elements:DrawItemQuest(b, { isQuestItem = false, questID = 123, isActive = true })
      assert.are.equal("quest.tga", b.IconQuestTexture:GetTexture())
    end)

    it("never marks an item that is not a quest item, even when its quest texture is shown (Classic)", function()
      local b = itemDecoration()
      elements:StyleItemButton(b, { QuestIcon = { Texture = "elv-quest.tga" }, QuestBorderColor = { 1, 0.8, 0, 1 } })
      b.IconQuestTexture:Show()
      b.IconBorder:Hide()
      elements:DrawItemQuest(b, { isQuestItem = false, isActive = false })
      assert.is_nil(b.IconQuestTexture:GetTexture())
      assert.is_false(b.IconBorder:IsShown())
    end)

    it("leaves the upgrade arrow's art when a style only scales it", function()
      local b = itemDecoration()
      elements:StyleItemButton(b, { UpgradeIcon = { Scale = 1.2 } })
      assert.are.equal("bags-greenarrow", b.UpgradeIcon:GetAtlas())
      assert.are.equal(1.2, b.UpgradeIcon:GetScale())
    end)

    it("puts the count where the style says, and back for the next theme", function()
      local b = itemDecoration()
      elements:StyleItemButton(b, { Count = { Points = { { Point = "BOTTOMRIGHT", X = -1, Y = 1 } } } })
      assert.are.same({ "BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1 }, { b.Count:GetPoint(1) })
      elements:StyleItemButton(b, {})
      assert.are.same({ "BOTTOMRIGHT", b, "BOTTOMRIGHT", -5, 2 }, { b.Count:GetPoint(1) })
    end)

    it("draws no border for a backdrop that only fills", function()
      local b = itemDecoration()
      elements:StyleItemButton(b, { Backdrop = { Color = { 0, 0, 0, 1 } } })
      assert.is_true(b.sonataSkin.fill:IsShown())
      assert.is_true(b.sonataSkin.edges == nil or not b.sonataSkin.edges[1]:IsShown())
    end)

    it("insets a backdrop border per side, or by one number for all sides", function()
      local b = itemDecoration()
      elements:StyleItemButton(b, { Backdrop = { BorderColor = { 0, 0, 0, 1 }, BorderInset = { Left = -1, Right = -2, Top = -3, Bottom = -4 } } })
      local top = b.sonataSkin.edges[1]
      assert.are.same({ "TOPLEFT", b, "TOPLEFT", -1, 3 }, { top:GetPoint(1) })
      assert.are.same({ "TOPRIGHT", b, "TOPRIGHT", 2, 3 }, { top:GetPoint(2) })
      elements:StyleItemButton(b, { Backdrop = { BorderColor = { 0, 0, 0, 1 }, BorderInset = 2 } })
      assert.are.same({ "TOPLEFT", b, "TOPLEFT", 2, -2 }, { top:GetPoint(1) })
    end)

    it("does not take quality for a backdrop border it has no border for", function()
      local b = itemDecoration()
      elements:StyleItemButton(b, { QualityBorder = "Backdrop", Backdrop = { Color = { 0, 0, 0, 1 } } })
      assert.is_false(elements:DrawItemQuality(b, { 1, 0, 0, 1 }))
      elements:StyleItemButton(b, { QualityBorder = "Backdrop" })
      assert.is_false(elements:DrawItemQuality(b, { 1, 0, 0, 1 }))
    end)

    it("colors qualities the style overrides, such as common items", function()
      local b = itemDecoration()
      elements:StyleItemButton(b, { QualityBorder = "Backdrop", Backdrop = { BorderColor = { 0, 0, 0, 1 } },
        QualityColors = { [1] = { 0.2, 0.2, 0.2, 1 } } })
      assert.is_true(elements:DrawItemQuality(b, { 1, 1, 1, 1 }, 1))
      assert.are.same({ r = 0.2, g = 0.2, b = 0.2, a = 1 }, b.sonataSkin.edges[1]._colorTexture)
      elements:DrawItemQuality(b, { 0, 0.44, 0.87, 1 }, 3)
      assert.are.same({ r = 0, g = 0.44, b = 0.87, a = 1 }, b.sonataSkin.edges[1]._colorTexture)
    end)

    it("gives the item highlight and pushed art back their blend modes", function()
      local b = itemDecoration()
      elements:StyleItemButton(b, { Pushed = { Color = { 1, 1, 1, 0.3 }, BlendMode = "ADD" },
        Highlight = { Color = { 1, 1, 1, 0.3 }, BlendMode = "BLEND" } })
      assert.are.equal("ADD", b:GetPushedTexture():GetBlendMode())
      elements:StyleItemButton(b, {})
      assert.are.equal("BLEND", b:GetPushedTexture():GetBlendMode())
      assert.are.equal("ADD", b:GetHighlightTexture():GetBlendMode())
    end)
  end)

  describe("tabs", function()
    it("shows Blizzard's tab art by state", function()
      local t = tabDecoration()
      elements:StyleTab(t, {})
      elements:SetTabState(t, "selected")
      assert.is_true(t.LeftActive:IsShown())
      assert.is_false(t.Left:IsShown())
      local _, _, _, x, y = t.Text:GetPoint(1)
      assert.are.same({ 0, -3 }, { x, y })
      assert.are.equal(_G.GameFontHighlightSmall, t._disabledFontObject)
      elements:SetTabState(t, "normal")
      assert.is_false(t.LeftActive:IsShown())
      assert.is_true(t.Left:IsShown())
      _, _, _, x, y = t.Text:GetPoint(1)
      assert.are.same({ 0, 2 }, { x, y })
    end)

    it("uses the template's own text offsets when it has them", function()
      local t = tabDecoration()
      t.deselectedTextX, t.deselectedTextY = 1, 10
      t.selectedTextX, t.selectedTextY = 2, 6
      elements:StyleTab(t, {})
      elements:SetTabState(t, "selected")
      local _, _, _, x, y = t.Text:GetPoint(1)
      assert.are.same({ 2, 6 }, { x, y })
      elements:SetTabState(t, "normal")
      _, _, _, x, y = t.Text:GetPoint(1)
      assert.are.same({ 1, 10 }, { x, y })
    end)

    it("highlights a drop target like a selected tab without moving its text", function()
      local t = tabDecoration()
      elements:StyleTab(t, {})
      elements:SetTabState(t, "normal")
      elements:SetTabState(t, "drop")
      assert.is_true(t.LeftActive:IsShown())
      local _, _, _, x, y = t.Text:GetPoint(1)
      assert.are.same({ 0, 2 }, { x, y })
    end)

    it("draws flat tabs: the template art hidden, its own fill, border, bar and fonts by state", function()
      local t = tabDecoration()
      elements:StyleTab(t, {
        Art = "Flat",
        Background = { Color = { 0.08, 0.08, 0.08, 0.92 }, Inset = { Left = 1, Right = 1, Top = 2, Bottom = 2 } },
        Border = { Color = { 0.2, 0.2, 0.2, 1 }, EdgeSize = 1 },
        Font = { Object = "UnitFrame12White" },
        SelectedFont = { Object = "UnitFrame12Yellow" },
        TextOffset = { X = 0, Y = 0 },
        SelectedTextOffset = { X = 0, Y = 0 },
        Selected = {
          Background = { Color = { 0.2, 0.6, 1, 0.1 } },
          Bar = { Color = { 0.2, 0.6, 1, 0.9 }, Height = 2 },
        },
      })
      for _, key in ipairs({ "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive", "LeftHighlight" }) do
        assert.are.equal(0, t[key]:GetAlpha(), key)
      end
      local skin = t.sonataSkin
      assert.is_true(skin.fill:IsShown())
      assert.is_false(skin.selectedFill:IsShown())
      assert.are.equal(fonts.UnitFrame12White, t._normalFontObject)

      elements:SetTabState(t, "selected")
      assert.is_true(skin.selectedFill:IsShown())
      assert.is_true(skin.bar:IsShown())
      assert.are.equal(2, skin.bar:GetHeight())
      assert.are.equal(fonts.UnitFrame12Yellow, t._normalFontObject)
      local _, _, _, x, y = t.Text:GetPoint(1)
      assert.are.same({ 0, 0 }, { x, y })

      elements:SetTabState(t, "normal")
      assert.is_false(skin.selectedFill:IsShown())
      assert.is_false(skin.bar:IsShown())
    end)

    it("restores Blizzard's art and alphas when the next theme uses it", function()
      local t = tabDecoration()
      elements:StyleTab(t, { Art = "Flat", Background = { Color = { 0, 0, 0, 1 } } })
      elements:StyleTab(t, {})
      elements:SetTabState(t, "normal")
      assert.are.equal(1, t.Left:GetAlpha())
      assert.are.equal(0.4, t.LeftHighlight:GetAlpha())
      assert.is_false(t.sonataSkin.fill:IsShown())
    end)

    it("keeps the tab's state across a restyle", function()
      local t = tabDecoration()
      elements:StyleTab(t, {})
      elements:SetTabState(t, "selected")
      elements:StyleTab(t, { Art = "Flat", Selected = { Bar = { Color = { 1, 1, 1, 1 }, Height = 2 } } })
      assert.is_true(t.sonataSkin.bar:IsShown())
    end)

    it("starts every theme from the template's fonts and height", function()
      local t = tabDecoration()
      elements:StyleTab(t, { Art = "Flat", Height = 24, Font = { Object = "UnitFrame12White" }, SelectedFont = { Object = "UnitFrame12Yellow" } })
      elements:SetTabState(t, "selected")
      elements:StyleTab(t, {})
      elements:SetTabState(t, "normal")
      assert.are.equal(32, t:GetHeight())
      assert.are.equal(_G.GameFontNormalSmall, t._normalFontObject)
      assert.are.equal(_G.GameFontHighlightSmall, t._highlightFontObject)
      assert.are.equal(_G.GameFontNormalSmall, t.Text._fontObject)
    end)

    it("goes back to the normal font when deselected with only a selected font", function()
      local t = tabDecoration()
      elements:StyleTab(t, { SelectedFont = { Object = "UnitFrame12Yellow" } })
      elements:SetTabState(t, "selected")
      assert.are.equal(fonts.UnitFrame12Yellow, t._normalFontObject)
      elements:SetTabState(t, "normal")
      assert.are.equal(_G.GameFontNormalSmall, t._normalFontObject)
    end)

    it("turns a font made of a path and color into a font object, so hovering keeps it", function()
      local t = tabDecoration()
      elements:StyleTab(t, { Font = { Path = "f.ttf", Size = 11, Flags = "OUTLINE", Color = { 0.8, 0.8, 0.8, 1 } } })
      local object = t._normalFontObject
      assert.are.same({ "f.ttf", 11, "OUTLINE" }, { object:GetFont() })
      assert.are.same({ 0.8, 0.8, 0.8, 1 }, { object:GetTextColor() })
      assert.are.equal(object, t._highlightFontObject)
      local again = tabDecoration()
      elements:StyleTab(again, { Font = { Path = "f.ttf", Size = 11, Flags = "OUTLINE", Color = { 0.8, 0.8, 0.8, 1 } } })
      assert.are.equal(object, again._normalFontObject)
    end)

    it("sets separate highlight fonts for the tab when the style gives one", function()
      local t = tabDecoration()
      elements:StyleTab(t, { Font = { Object = "UnitFrame12White" }, HighlightFont = { Object = "UnitFrame12Yellow" } })
      assert.are.equal(fonts.UnitFrame12White, t._normalFontObject)
      assert.are.equal(fonts.UnitFrame12Yellow, t._highlightFontObject)
    end)

    it("draws a flat tab's selected fill above its normal fill", function()
      local t = tabDecoration()
      elements:StyleTab(t, { Art = "Flat", Background = { Color = { 0, 0, 0, 1 } },
        Selected = { Background = { Color = { 1, 1, 1, 0.1 } } } })
      assert.are.equal(-8, t.sonataSkin.fill._sublevel)
      assert.are.equal(-7, t.sonataSkin.selectedFill._sublevel)
    end)

    it("draws a flat tab's hover fill while the pointer is on it", function()
      local t = tabDecoration()
      elements:StyleTab(t, { Art = "Flat", Hover = { Color = { 1, 1, 1, 0.06 } } })
      assert.are.equal("HIGHLIGHT", t.sonataSkin.hover._drawLayer)
      assert.is_true(t.sonataSkin.hover:IsShown())
      elements:StyleTab(t, {})
      assert.is_false(t.sonataSkin.hover:IsShown())
    end)

    it("keeps the selected tab's art when a section is dragged over it", function()
      local t = tabDecoration()
      elements:StyleTab(t, {})
      elements:SetTabState(t, "selected")
      elements:SetTabState(t, "drop")
      assert.is_false(t.Left:IsShown())
      assert.is_true(t.LeftActive:IsShown())
      elements:SetTabState(t, "normal")
      elements:SetTabState(t, "drop")
      assert.is_true(t.Left:IsShown())
      assert.is_true(t.LeftActive:IsShown())
    end)

    it("says which state a tab is in, a drop never being one", function()
      local t = tabDecoration()
      assert.are.equal("normal", elements:GetTabState(t))
      elements:StyleTab(t, {})
      elements:SetTabState(t, "selected")
      elements:SetTabState(t, "drop")
      assert.are.equal("selected", elements:GetTabState(t))
    end)

    it("errors on an unknown state", function()
      local t = tabDecoration()
      elements:StyleTab(t, {})
      assert.has_error(function() elements:SetTabState(t, "bogus") end)
    end)
  end)

  describe("section headers", function()
    it("keeps the color it gave a header, for titles that drop a custom color", function()
      local fs = UIParent:CreateFontString()
      elements:StyleSectionHeader(fs, { Font = { Object = "GameFontNormal", Color = { 0.2, 0.4, 0.6, 1 } } })
      fs:SetTextColor(1, 0, 0, 1)
      assert.are.same({ 0.2, 0.4, 0.6, 1 }, { elements:GetSectionHeaderColor(fs) })
      elements:StyleSectionHeader(fs, { Font = { Object = "GameFontNormal" } })
      assert.are.same({ GameFontNormal:GetTextColor() }, { elements:GetSectionHeaderColor(fs) })
    end)

    it("sets the header font, and its color when the style gives one", function()
      local fs = UIParent:CreateFontString()
      elements:StyleSectionHeader(fs, { Font = { Object = "UnitFrame12Yellow" } })
      assert.are.equal(fonts.UnitFrame12Yellow, fs._fontObject)
      elements:StyleSectionHeader(fs, { Font = { Path = "f.ttf", Size = 12, Color = { 1, 1, 1, 1 } } })
      assert.are.equal("f.ttf", fs._font)
      assert.are.same({ r = 1, g = 1, b = 1, a = 1 }, fs._textColor)
    end)
  end)

  describe("search boxes", function()
    local function searchBox()
      local box = CreateFrame("EditBox", nil, UIParent)
      box.Left = box:CreateTexture(nil, "BACKGROUND")
      box.Middle = box:CreateTexture(nil, "BACKGROUND")
      box.Right = box:CreateTexture(nil, "BACKGROUND")
      box.Middle:SetAtlas("common-search-border-middle")
      box.Instructions = box:CreateFontString()
      box.searchIcon = box:CreateTexture(nil, "OVERLAY")
      return box
    end

    it("hides the template's art and draws a fill, border and fonts", function()
      local box = searchBox()
      elements:StyleSearchBox(box, {
        Strip = true,
        Background = { Color = { 0.02, 0.02, 0.02, 1 } },
        Border = { Color = { 0.2, 0.2, 0.2, 1 } },
        Font = { Path = "f.ttf", Size = 12 },
        Instructions = { Color = { 0.4, 0.4, 0.4, 1 } },
        TextInsets = { Left = 5, Right = 20, Top = 0, Bottom = 0 },
      })
      assert.are.equal(0, box.Left:GetAlpha())
      assert.are.equal(0, box.Middle:GetAlpha())
      assert.is_true(box.sonataSkin.fill:IsShown())
      assert.are.equal("f.ttf", box._font)
      assert.are.same({ r = 0.4, g = 0.4, b = 0.4, a = 1 }, box.Instructions._textColor)
      assert.are.same({ 5, 20, 0, 0 }, box._textInsets)
    end)

    it("gives Blizzard's middle art back everything its own art changed", function()
      local box = searchBox()
      box.Middle:SetDrawLayer("BACKGROUND", 0)
      elements:StyleSearchBox(box, { Middle = { Texture = "m.png", Layer = "ARTWORK", VertexColor = { 1, 0, 0, 1 },
        Alpha = 0.5, BlendMode = "ADD", Desaturated = true, HorizTile = true } })
      elements:StyleSearchBox(box, {})
      assert.are.equal("common-search-border-middle", box.Middle:GetAtlas())
      assert.are.equal("BACKGROUND", box.Middle._drawLayer)
      assert.are.same({ r = 1, g = 1, b = 1, a = 1 }, box.Middle._vertexColor)
      assert.are.equal(1, box.Middle:GetAlpha())
      assert.are.equal("BLEND", box.Middle:GetBlendMode())
      assert.is_false(box.Middle:IsDesaturated())
      assert.is_falsy(box.Middle._horizTile)
      assert.is_nil(box.Middle._texCoords)
    end)

    it("hides or restyles the search icon and the clear button, and places the instructions", function()
      local box = searchBox()
      box.Instructions:SetPoint("TOPLEFT", box, "TOPLEFT", 16, 0)
      box.Instructions:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -20, 0)
      box.searchIcon:SetAtlas("common-search-magnifyingglass")
      box.clearButton = CreateFrame("Button", nil, box)
      box.clearButton.Icon = box.clearButton:CreateTexture(nil, "ARTWORK")
      box.clearButton.Icon:SetAtlas("common-search-clearbutton")
      box.clearButton.Icon:SetAlpha(0.5)
      elements:StyleSearchBox(box, { SearchIcon = false, ClearButton = { Icon = { Texture = "x.png" } },
        InstructionsPoints = { { Point = "LEFT", X = 5 } } })
      assert.are.equal(0, box.searchIcon:GetAlpha())
      assert.are.equal("x.png", box.clearButton.Icon:GetTexture())
      assert.are.same({ "LEFT", box, "LEFT", 5, 0 }, { box.Instructions:GetPoint(1) })
      elements:StyleSearchBox(box, { SearchIcon = { Texture = "glass.png" } })
      assert.are.equal(1, box.searchIcon:GetAlpha())
      assert.are.equal("glass.png", box.searchIcon:GetTexture())
      assert.are.equal("common-search-clearbutton", box.clearButton.Icon:GetAtlas())
      assert.are.equal(0.5, box.clearButton.Icon:GetAlpha())
      assert.are.same({ "TOPLEFT", box, "TOPLEFT", 16, 0 }, { box.Instructions:GetPoint(1) })
      elements:StyleSearchBox(box, {})
      assert.are.equal(1, box.searchIcon:GetAlpha())
      assert.are.equal("common-search-magnifyingglass", box.searchIcon:GetAtlas())
    end)

    it("replaces the middle art with its own, and puts Blizzard's back", function()
      local box = searchBox()
      elements:StyleSearchBox(box, {
        HideCaps = true,
        Middle = { Texture = "Interface/AddOns/GW2_UI/textures/bag/bagsearchbg.png", Height = 24,
          Points = { { Point = "LEFT" }, { Point = "RIGHT" } } },
      })
      assert.are.equal(0, box.Left:GetAlpha())
      assert.are.equal(0, box.Right:GetAlpha())
      assert.are.equal(1, box.Middle:GetAlpha())
      assert.are.equal("Interface/AddOns/GW2_UI/textures/bag/bagsearchbg.png", box.Middle:GetTexture())
      assert.are.equal(24, box.Middle:GetHeight())
      elements:StyleSearchBox(box, {})
      assert.are.equal(1, box.Left:GetAlpha())
      assert.are.equal("common-search-border-middle", box.Middle:GetAtlas())
    end)
  end)

  describe("the bag menu button", function()
    local function bagButton()
      local b = CreateFrame("Button", nil, UIParent)
      b.portrait = b:CreateTexture()
      b.highlightTex = b:CreateTexture()
      return b
    end

    it("keeps the default art of a portrait style that only sizes it, at the overlay layer", function()
      local b = bagButton()
      elements:StyleBagButton(b, { Portrait = { Width = 40, Height = 50 } })
      assert.are.equal("Interface\\Containerframe\\Bagslots2x", b.portrait:GetTexture())
      assert.are.same({ 0, 0.2, 0, 1 }, b.portrait._texCoords)
      assert.are.same({ 40, 50 }, { b.portrait:GetWidth(), b.portrait:GetHeight() })
      assert.are.equal("OVERLAY", b.portrait._drawLayer)
      assert.are.equal(7, b.portrait._sublevel)
      assert.are.equal("OVERLAY", b.highlightTex._drawLayer)
    end)

    it("sizes and textures the portrait and its highlight", function()
      local b = bagButton()
      elements:StyleBagButton(b, {
        Size = 40,
        Portrait = { Texture = "Interface\\Containerframe\\Bagslots2x", TexCoords = { 0, 0.2, 0, 1 }, Width = 48, Height = 60 },
        Highlight = { Texture = "Interface\\Containerframe\\Bagslots2x", TexCoords = { 0.2, 0.3992, 0, 1 }, Width = 48, Height = 60, X = 2 },
      })
      assert.are.equal(40, b:GetWidth())
      assert.are.equal(48, b.portrait:GetWidth())
      assert.are.equal(60, b.portrait:GetHeight())
      assert.are.same({ 0, 0.2, 0, 1 }, b.portrait._texCoords)
      local point, _, _, x = b.highlightTex:GetPoint(1)
      assert.are.same({ "CENTER", 2 }, { point, x })
    end)
  end)

  describe("dialog buttons and edit boxes", function()
    -- panelButton builds what UIPanelButtonTemplate / InputBoxTemplate give a button or an
    -- edit box: the three caps and the template's fonts.
    local function panelButton()
      local b = CreateFrame("Button", nil, UIParent)
      b.Left = b:CreateTexture(nil, "BACKGROUND")
      b.Middle = b:CreateTexture(nil, "BACKGROUND")
      b.Right = b:CreateTexture(nil, "BACKGROUND")
      b:SetNormalFontObject(_G.GameFontNormal)
      b:SetHighlightFontObject(_G.GameFontHighlight)
      b:SetDisabledFontObject(_G.GameFontDisable)
      b:SetFontObject(_G.ChatFontNormal)
      return b
    end

    it("keeps Blizzard's button without a style", function()
      local b = panelButton()
      elements:StyleButton(b, {})
      assert.are.equal(1, b.Left:GetAlpha())
      assert.is_nil(b.sonataSkin)
    end)

    it("flattens a button: template art hidden, fill, border, hover", function()
      local b = panelButton()
      elements:StyleButton(b, {
        Strip = true,
        Background = { Color = { 0.1, 0.1, 0.1, 1 } },
        Border = { Color = { 0, 0, 0, 1 } },
        Highlight = { Color = { 1, 1, 1, 0.3 }, BlendMode = "ADD" },
      })
      assert.are.equal(0, b.Middle:GetAlpha())
      assert.is_true(b.sonataSkin.fill:IsShown())
      assert.are.same({ r = 1, g = 1, b = 1, a = 0.3 }, b:GetHighlightTexture()._vertexColor)
      elements:StyleButton(b, {})
      assert.are.equal(1, b.Middle:GetAlpha())
      assert.is_false(b.sonataSkin.fill:IsShown())
    end)

    it("gives a button back its template fonts and highlight for the next theme", function()
      local b = panelButton()
      b:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight", "ADD")
      local highlight = b:GetHighlightTexture()
      highlight:SetPoint("TOPLEFT")
      elements:StyleButton(b, { Font = { Object = "UnitFrame12White" }, HighlightFont = { Object = "UnitFrame12Yellow" },
        DisabledFont = { Object = "UnitFrame12White" }, Highlight = { Color = { 1, 1, 1, 0.3 }, Alpha = 0.5,
        Inset = { Left = 1, Right = 1, Top = 1, Bottom = 1 } } })
      elements:StyleButton(b, {})
      assert.are.equal(_G.GameFontNormal, b._normalFontObject)
      assert.are.equal(_G.GameFontHighlight, b._highlightFontObject)
      assert.are.equal(_G.GameFontDisable, b._disabledFontObject)
      assert.are.equal("Interface\\Buttons\\UI-Panel-Button-Highlight", highlight:GetTexture())
      assert.are.equal("ADD", highlight:GetBlendMode())
      assert.are.equal(1, highlight:GetAlpha())
      assert.are.same({ "TOPLEFT" }, { (highlight:GetPoint(1)) })
      assert.are.same({ r = 1, g = 1, b = 1, a = 1 }, highlight._vertexColor)
    end)

    it("takes away a highlight the button never had", function()
      local b = panelButton()
      elements:StyleButton(b, { Highlight = { Color = { 1, 1, 1, 0.3 } } })
      elements:StyleButton(b, {})
      assert.is_nil(b:GetHighlightTexture():GetTexture())
    end)

    it("gives an edit box back its template font", function()
      local box = panelButton()
      elements:StyleEditBox(box, { Font = { Object = "UnitFrame12White" } })
      elements:StyleEditBox(box, {})
      assert.are.equal(_G.ChatFontNormal, box._fontObject)
    end)

    it("flattens an edit box the same way", function()
      local box = panelButton()
      elements:StyleEditBox(box, { Strip = true, Background = { Color = { 0, 0, 0, 1 } } })
      assert.are.equal(0, box.Left:GetAlpha())
      assert.is_true(box.sonataSkin.fill:IsShown())
    end)

    it("colors the border another color while the mouse is over the button", function()
      local b = panelButton()
      elements:StyleButton(b, { Border = { Color = { 0, 0, 0, 1 } }, HoverBorderColor = { 1, 0.8, 0, 1 } })
      local edge = b.sonataSkin.edges[1]
      assert.are.same({ r = 0, g = 0, b = 0, a = 1 }, edge._colorTexture)
      b:GetScript("OnEnter")(b)
      assert.are.same({ r = 1, g = 0.8, b = 0, a = 1 }, edge._colorTexture)
      b:GetScript("OnLeave")(b)
      assert.are.same({ r = 0, g = 0, b = 0, a = 1 }, edge._colorTexture)
      -- A later style without it leaves the border alone on hover.
      elements:StyleButton(b, { Border = { Color = { 0.2, 0.2, 0.2, 1 } } })
      b:GetScript("OnEnter")(b)
      assert.are.same({ r = 0.2, g = 0.2, b = 0.2, a = 1 }, edge._colorTexture)
      b:GetScript("OnLeave")(b)
      assert.are.same({ r = 0.2, g = 0.2, b = 0.2, a = 1 }, edge._colorTexture)
    end)

    it("hides the button's highlight for a style that turns it off, and gives it back after", function()
      local b = panelButton()
      local highlight = b:GetHighlightTexture()
      highlight:SetAlpha(0.7)
      elements:StyleButton(b, { Highlight = false })
      assert.are.equal(0, highlight:GetAlpha())
      elements:StyleButton(b, {})
      assert.are.equal(0.7, highlight:GetAlpha())
    end)

    it("draws borders that never take the mouse", function()
      local b = panelButton()
      elements:StyleButton(b, { Border = { Color = { 0, 0, 0, 1 } } })
      assert.are.equal(4, #b.sonataSkin.edges)
      for _, edge in ipairs(b.sonataSkin.edges) do
        assert.are.equal("Texture", edge._type)
      end
    end)
  end)

  describe("through the engine", function()
    local events = addon:GetModule("Events")
    local originalSend, originalThemes

    before_each(function()
      originalSend = events.SendMessage
      originalThemes = sonata.themes
      events.SendMessage = function() end
    end)

    after_each(function()
      events.SendMessage = originalSend
      sonata.themes = originalThemes
    end)

    it("styles a registered item decoration with the current theme and restyles it on apply", function()
      sonata.themes = {}
      sonata:RegisterTheme({ Name = "Base", Hidden = true, Elements = { ItemButton = {} } })
      sonata:RegisterTheme({ Name = "Default" })
      sonata:RegisterTheme({ Name = "Cropped", Elements = { ItemButton = { Icon = { TexCoords = { 0.1, 0.9, 0.1, 0.9 } } } } })
      local b = itemDecoration()
      sonata:RegisterElement("ItemButton", b)
      sonata:ApplyTheme(addon:GetModule("Context"):New("test"), "Cropped")
      assert.are.same({ 0.1, 0.9, 0.1, 0.9 }, b.icon._texCoords)
      sonata:ApplyTheme(addon:GetModule("Context"):New("test"), "Default")
      assert.are.same({ 0, 1, 0, 1 }, b.icon._texCoords)
    end)
  end)
end)

teardown(function()
  for i = #createdStubs, 1, -1 do
    ResetModuleStub(createdStubs[i])
  end
end)
