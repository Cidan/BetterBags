-- themes_spec.lua -- BetterBags' Sonata themes as data (sonata/themes/*.lua), resolved by the
-- real engine and built by the real decoration builder on a real window.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")

local db = StubBetterBagsModule("Database")
local savedTheme = "Default"
local originalGetTheme, originalSetTheme = db.GetTheme, db.SetTheme

local fonts = StubBetterBagsModule("Fonts")
fonts.UnitFrame12Yellow = fonts.UnitFrame12Yellow or CreateFont("BetterBagsUnitFrame12Yellow")

local libWindow = LibStub:NewLibrary("LibWindow-1.1", 1) or LibStub("LibWindow-1.1")
libWindow.RegisterConfig = libWindow.RegisterConfig or function() end
libWindow.RestorePosition = libWindow.RestorePosition or function() end
libWindow.SavePosition = libWindow.SavePosition or function() end

LoadBetterBagsModule("render/render.lua")
LoadBetterBagsModule("render/drawable.lua")
LoadBetterBagsModule("sonata/engine.lua")
LoadBetterBagsModule("sonata/apply.lua")
LoadBetterBagsModule("sonata/decoration.lua")
LoadBetterBagsModule("sonata/elements.lua")
LoadBetterBagsModule("window/window.lua")

local sonata = addon:GetModule("Sonata")
local window = addon:GetModule("Window")
local events = addon:GetModule("Events")
local context = addon:GetModule("Context")

describe("BetterBags' Sonata themes", function()
  local originalSend, originalThemes

  before_each(function()
    originalThemes = sonata.themes
    sonata.themes = {}
    assert(loadfile("sonata/themes/base.lua"))("BetterBags")
    assert(loadfile("sonata/themes/default.lua"))("BetterBags")
    sonata:Init()
    savedTheme = "Default"
    db.GetTheme = function() return savedTheme end
    db.SetTheme = function(_, key) savedTheme = key end
    originalSend = events.SendMessage
    events.SendMessage = function() end
  end)

  after_each(function()
    events.SendMessage = originalSend
    sonata.themes = originalThemes
    db.GetTheme, db.SetTheme = originalGetTheme, originalSetTheme
  end)

  local count = 0
  local function bagWindow(level)
    count = count + 1
    return window:Create({ Name = "BetterBagsThemeSpecBag" .. count, Kind = "Bag", Title = "Backpack", Level = level or 500,
      Opacity = function() return 40 end })
  end

  describe("Base", function()
    it("is hidden and never listed", function()
      assert.is_nil(sonata:GetAllThemes().Base)
      assert.is_not_nil(sonata:GetAllThemes().Default)
    end)

    it("gives every theme the bag's geometry and the default fade", function()
      local bag = sonata:Resolve("Default").Windows.Bag
      assert.are.same({ Left = 6, Right = 6, Top = 42, Bottom = 3 }, bag.Insets)
      assert.are.equal(20, bag.Layout.Search.Reserve)
      assert.are.equal(26, bag.Layout.Footer.Reserve)
      assert.are.same({ { Point = "TOPLEFT", X = -10, Y = 7 } }, bag.Layout.MenuButton.Points)
      assert.are.equal("Alpha", bag.Animations.Show[1].Type)
      assert.are.equal(0.10, bag.Animations.Hide[1].Duration)
    end)
  end)

  describe("Default", function()
    it("draws the bag as Blizzard's portrait-less panel with its close button", function()
      local w = bagWindow()
      sonata:ApplyTheme(context:New("spec"), "Default")
      local deco = w.decoration
      local panel = deco:GetTemplateFrame()
      assert.is_truthy(panel._template:find("DefaultPanelTemplate"))
      assert.are.equal(499, panel:GetFrameLevel())
      assert.are.equal(1000, panel.NineSlice:GetFrameLevel())
      assert.are.equal(1001, panel.TitleContainer:GetFrameLevel())
      assert.are.equal("Backpack", panel.TitleContainer.TitleText:GetText())
      assert.are.equal(fonts.UnitFrame12Yellow, panel.TitleContainer.TitleText._fontObject)
      assert.are.equal(0.4, panel.Bg:GetAlpha())
      local close = deco:GetCloseButton()
      assert.is_truthy(close._template:find("UIPanelCloseButtonDefaultAnchors"))
      assert.are.same({ "TOPLEFT", w.frame, "TOPLEFT", 6, -42 }, { w.content:GetPoint(1) })
    end)

    it("puts the content above its background and below its border", function()
      local w = bagWindow()
      sonata:ApplyTheme(context:New("spec"), "Default")
      local panel = w.decoration:GetTemplateFrame()
      assert.is_true(panel:GetFrameLevel() < w.content:GetFrameLevel())
      assert.is_true(panel.NineSlice:GetFrameLevel() > w.content:GetFrameLevel())
    end)

    it("titles sections in BetterBags' yellow unit-frame font", function()
      local font = UIParent:CreateFontString()
      sonata:RegisterElement("SectionHeader", font)
      sonata:ApplyTheme(context:New("spec"), "Default")
      assert.are.equal(fonts.UnitFrame12Yellow, font._fontObject)
    end)
  end)
end)
