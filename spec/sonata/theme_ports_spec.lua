-- theme_ports_spec.lua -- The themes BetterBags ships besides Default, as Sonata data
-- (sonata/themes/*.lua): Simple Dark, the Moonlight set, ElvUI and Guild Wars 2, resolved by the
-- real engine and built by the real decoration builder and element styles on real windows.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")

local db = StubBetterBagsModule("Database")
local savedTheme = "Default"
local originalGetTheme, originalSetTheme = db.GetTheme, db.SetTheme

local fonts = StubBetterBagsModule("Fonts")
fonts.UnitFrame12Yellow = fonts.UnitFrame12Yellow or CreateFont("BetterBagsUnitFrame12Yellow")
fonts.UnitFrame12White = fonts.UnitFrame12White or CreateFont("BetterBagsUnitFrame12White")

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

local THEME_FILES = { "base", "default", "simpledark", "moonlight" }

describe("BetterBags' other themes", function()
  local originalSend, originalThemes

  before_each(function()
    originalThemes = sonata.themes
    sonata.themes = {}
    for _, file in ipairs(THEME_FILES) do
      assert(loadfile("sonata/themes/" .. file .. ".lua"))("BetterBags")
    end
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
  local function newWindow(kind, opacity)
    count = count + 1
    return window:Create({ Name = "BetterBagsThemePortsSpec" .. count, Kind = kind, Title = kind,
      Opacity = function() return opacity or 100 end })
  end

  local function apply(key)
    sonata:ApplyTheme(context:New("spec"), key)
  end

  local function color(t)
    return { t.r, t.g, t.b, t.a }
  end

  describe("Simple Dark", function()
    it("keeps the key saved profiles chose it by", function()
      assert.is_not_nil(sonata:GetAllThemes().SimpleDark)
      assert.are.equal("Simple Dark", sonata:GetTheme("SimpleDark").DisplayName)
    end)

    it("draws every window as a black backdrop with a gray edge, fading border and all", function()
      local windows = {}
      for _, kind in ipairs({ "Bag", "Panel", "Flat", "Dialog", "Slots", "Search" }) do
        windows[kind] = newWindow(kind, 50)
      end
      apply("SimpleDark")
      for kind, w in pairs(windows) do
        local backdrop = w.frame._backdrop
        assert.are.equal("Interface\\ChatFrame\\ChatFrameBackground", backdrop.bgFile, kind)
        assert.are.equal("Interface\\ChatFrame\\ChatFrameBackground", backdrop.edgeFile, kind)
        assert.are.equal(1, backdrop.edgeSize, kind)
        assert.are.same({ 0, 0, 0, 0.5 }, color(w.frame._backdropColor), kind)
        assert.are.same({ 0.5, 0.5, 0.5, 0.5 }, color(w.frame._backdropBorderColor), kind)
        assert.is_nil(w.decoration:GetTemplateFrame(), kind)
      end
    end)

    it("titles windows in white at the top, and has a small close button where windows close", function()
      local bag, dialog, slots = newWindow("Bag"), newWindow("Dialog"), newWindow("Slots")
      apply("SimpleDark")
      local title = bag.decoration:GetTitleText()
      assert.are.equal(fonts.UnitFrame12White, title:GetFontObject())
      assert.are.same({ "TOP", bag.frame, "TOP", 0, 0 }, { title:GetPoint(1) })
      assert.are.equal(30, title:GetHeight())
      local close = bag.decoration:GetCloseButton()
      assert.are.same({ 12, 12 }, { close:GetWidth(), close:GetHeight() })
      assert.are.same({ "TOPRIGHT", bag.frame, "TOPRIGHT", -8, -8 }, { close:GetPoint(1) })
      assert.are.equal("Interface\\AddOns\\BetterBags\\textures\\close.png", close:GetNormalTexture():GetTexture())
      assert.are.equal("Interface\\AddOns\\BetterBags\\textures\\close.png", close:GetHighlightTexture():GetTexture())
      assert.is_nil(dialog.decoration:GetCloseButton())
      assert.is_true(dialog.decoration:GetTitleText():IsShown())
      assert.is_true(slots.decoration:GetTitleText() == nil or not slots.decoration:GetTitleText():IsShown())
      assert.is_nil(slots.decoration:GetCloseButton())
    end)

    it("puts the search box and menu button where its bag drew them, with a smaller portrait", function()
      local resolved = sonata:Resolve("SimpleDark")
      local layout = resolved.Windows.Bag.Layout
      assert.are.same({
        { Point = "TOPLEFT", X = 20, Y = -40 },
        { Point = "BOTTOMRIGHT", RelativePoint = "TOPRIGHT", X = -10, Y = -60 },
      }, layout.Search.Points)
      assert.are.same({ { Point = "TOPLEFT", X = 4, Y = -6 } }, layout.MenuButton.Points)
      assert.are.same({ Width = 40.8, Height = 51 }, resolved.Elements.BagButton.Portrait)
      assert.are.same({ Width = 40.8, Height = 51 }, resolved.Elements.BagButton.Highlight)
      assert.are.same({ Object = "UnitFrame12White" }, resolved.Elements.SectionHeader.Font)
    end)
  end)

  describe("the Moonlight set", function()
    local ART = "Interface\\AddOns\\BetterBags\\textures\\moonlight\\"

    it("lists Dark, Dark Round and Parchment, built on a hidden Moonlight base", function()
      local all = sonata:GetAllThemes()
      assert.is_nil(all.Moonlight)
      for key, name in pairs({ MoonlightDark = "Moonlight Dark", MoonlightDarkRound = "Moonlight Dark Round",
        MoonlightParchment = "Moonlight Parchment" }) do
        assert.is_not_nil(all[key], key)
        assert.are.equal(name, sonata:GetTheme(key).DisplayName)
        assert.are.equal("Moonlight", sonata:GetTheme(key).Parent)
      end
    end)

    it("frames every window in its art, nine-sliced, with Moonlight's content box", function()
      for key, art in pairs({ MoonlightDark = { "dark-frame.png", "Tiled" },
        MoonlightDarkRound = { "dark-round.png", "Tiled" }, MoonlightParchment = { "parchment.png", "Stretched" } }) do
        local bag, panel = newWindow("Bag"), newWindow("Panel")
        apply(key)
        for _, w in ipairs({ bag, panel }) do
          local bg = w.decoration:GetTexture("Background")
          assert.are.equal(ART .. art[1], bg:GetTexture(), key)
          assert.are.same({ left = 24, top = 24, right = 24, bottom = 24 }, bg._sliceMargins, key)
          assert.are.equal(Enum.UITextureSliceMode[art[2]], bg._sliceMode, key)
          assert.is_nil(w.decoration:GetTemplateFrame(), key)
        end
        assert.are.same({ Left = 18, Right = 24, Top = 40, Bottom = 12 }, bag.decoration:GetInsets(), key)
      end
    end)

    it("titles at the top left in white, with a lettered close button and the corner grip", function()
      local bag = newWindow("Bag")
      apply("MoonlightDark")
      local title = bag.decoration:GetTitleText()
      assert.are.same({ "TOPLEFT", bag.frame, "TOPLEFT", 44, -15 }, { title:GetPoint(1) })
      assert.are.same({ 1, 1, 1, 1 }, { title:GetTextColor() })
      local close = bag.decoration:GetCloseButton()
      assert.are.equal("X", close:GetText())
      assert.are.same({ 32, 32 }, { close:GetWidth(), close:GetHeight() })
      local layout = sonata:Resolve("MoonlightDark").Windows.Bag.Layout
      assert.are.same({ { Point = "TOPLEFT", X = 8, Y = -6 } }, layout.MenuButton.Points)
      assert.are.equal(32, sonata:Resolve("MoonlightDark").Elements.BagButton.Size)
    end)

    it("hangs Parchment's ribbon over the top, under a centered title", function()
      local bag = newWindow("Bag")
      apply("MoonlightParchment")
      local ribbon = bag.decoration:GetTexture("Ribbon")
      assert.are.equal(ART .. "parchment-ribbon.png", ribbon:GetTexture())
      assert.are.same({ "BOTTOM", bag.frame, "TOP", 0, -40 }, { ribbon:GetPoint(1) })
      assert.are.same({ 281, 84 }, { ribbon:GetWidth(), ribbon:GetHeight() })
      local title = bag.decoration:GetTitleText()
      assert.are.same({ "BOTTOM", ribbon, "BOTTOM", 0, 25 }, { title:GetPoint(1) })
    end)

    it("ships its art with BetterBags", function()
      for _, file in ipairs({ "dark-frame.png", "dark-round.png", "parchment.png", "parchment-ribbon.png" }) do
        local f = io.open("textures/moonlight/" .. file, "rb")
        assert.is_not_nil(f, file)
        f:close()
      end
    end)
  end)
end)
