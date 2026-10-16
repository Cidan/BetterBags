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

    it("gives every kind of window its content box and a fade", function()
      local windows = sonata:Resolve("Default").Windows
      assert.are.same({ Left = 4, Right = 0, Top = 30, Bottom = 4 }, windows.Panel.Insets)
      assert.are.same({ Left = 5, Right = 5, Top = 25, Bottom = 5 }, windows.Flat.Insets)
      assert.are.same({ Left = 5, Right = 5, Top = 25, Bottom = 5 }, windows.Dialog.Insets)
      for _, kind in ipairs({ "Panel", "Flat", "Dialog", "Slots" }) do
        assert.are.equal("Alpha", windows[kind].Animations.Show[1].Type, kind)
      end
      local slide = windows.Slots.Animations.Hide
      assert.are.equal("Translation", slide[2].Type)
      assert.are.same({ 0, -10 }, { slide[2].X, slide[2].Y })
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

    it("draws forms and other panels like the bag", function()
      local w = window:Create({ Kind = "Panel", Title = "Settings", Level = 500 })
      sonata:ApplyTheme(context:New("spec"), "Default")
      local panel = w.decoration:GetTemplateFrame()
      assert.is_truthy(panel._template:find("DefaultPanelTemplate"))
      assert.is_truthy(w.decoration:GetCloseButton()._template:find("UIPanelCloseButtonDefaultAnchors"))
      assert.are.same({ "TOPLEFT", w.frame, "TOPLEFT", 4, -30 }, { w.content:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", w.frame, "BOTTOMRIGHT", 0, 4 }, { w.content:GetPoint(2) })
    end)

    it("draws flat windows with a title and a close button in the corner", function()
      local w = window:Create({ Kind = "Flat", Title = "Debug" })
      sonata:ApplyTheme(context:New("spec"), "Default")
      local panel = w.decoration:GetTemplateFrame()
      assert.is_truthy(panel._template:find("DefaultPanelFlatTemplate"))
      assert.are.equal("Debug", panel.TitleContainer.TitleText:GetText())
      local close = w.decoration:GetCloseButton()
      assert.is_truthy(close._template:find("UIPanelCloseButton"))
      assert.are.same({ "TOPRIGHT", w.frame, "TOPRIGHT", 2, 2 }, { close:GetPoint(1) })
      assert.are.same({ "TOPLEFT", w.frame, "TOPLEFT", 5, -25 }, { w.content:GetPoint(1) })
    end)

    it("draws dialogs as flat windows with a title and no close button", function()
      local w = window:Create({ Kind = "Dialog", Title = "Delete?" })
      sonata:ApplyTheme(context:New("spec"), "Default")
      assert.is_truthy(w.decoration:GetTemplateFrame()._template:find("DefaultPanelFlatTemplate"))
      assert.is_nil(w.decoration:GetCloseButton())
    end)

    describe("the slots panels", function()
      local saved

      before_each(function()
        saved = { isRetail = addon.isRetail, isForever = addon.isForever, isClassic = addon.isClassic,
          isMists = addon.isMists, isAnniversary = addon.isAnniversary }
      end)

      after_each(function()
        for k, v in pairs(saved) do addon[k] = v end
      end)

      local function slots()
        local w = window:Create({ Kind = "Slots", Title = "" })
        sonata:ApplyTheme(context:New("spec"), "Default")
        return w
      end

      it("are headerless flat panels on retail, with room left for the panel's band", function()
        addon.isRetail, addon.isForever = true, false
        local w = slots()
        local panel = w.decoration:GetTemplateFrame()
        assert.is_truthy(panel._template:find("DefaultPanelFlatTemplate"))
        assert.is_false(panel.TitleContainer:IsShown())
        assert.is_nil(w.decoration:GetCloseButton())
        assert.are.same({ Left = 10, Right = 6, Top = 30, Bottom = 12 }, w:GetContentInsets())
      end)

      it("are a tooltip backdrop on the window itself on Classic, with even padding", function()
        addon.isRetail, addon.isForever, addon.isClassic = false, false, true
        local w = slots()
        assert.is_nil(w.decoration:GetTemplateFrame())
        local backdrop = w.frame._backdrop
        assert.are.equal("Interface/Tooltips/UI-Tooltip-Background", backdrop.bgFile)
        assert.are.equal("Interface/Tooltips/UI-Tooltip-Border", backdrop.edgeFile)
        assert.are.equal(16, backdrop.edgeSize)
        assert.are.same({ left = 4, right = 4, top = 4, bottom = 4 }, backdrop.insets)
        assert.are.same({ Left = 8, Right = 8, Top = 8, Bottom = 8 }, w:GetContentInsets())
      end)

      it("are Blizzard's dark tooltip frame below the window on WoW: Forever, with even padding", function()
        addon.isRetail, addon.isForever = true, true
        local w = slots()
        local panel = w.decoration:GetTemplateFrame()
        assert.is_truthy(panel._template:find("TooltipBorderedFrameTemplate"))
        assert.are.same({ r = 0, g = 0, b = 0, a = 0.9 }, panel._backdropColor)
        assert.are.same({ r = 1, g = 1, b = 1, a = 1 }, panel._backdropBorderColor)
        assert.is_true(panel:GetFrameLevel() < w.content:GetFrameLevel())
        assert.are.same({ Left = 8, Right = 8, Top = 8, Bottom = 8 }, w:GetContentInsets())
      end)
    end)

    it("titles sections in BetterBags' yellow unit-frame font", function()
      local font = UIParent:CreateFontString()
      sonata:RegisterElement("SectionHeader", font)
      sonata:ApplyTheme(context:New("spec"), "Default")
      assert.are.equal(fonts.UnitFrame12Yellow, font._fontObject)
    end)
  end)
end)
