-- theme_ports_spec.lua -- The themes BetterBags ships besides Default, as Sonata data
-- (sonata/themes/*.lua): Simple Dark, the Moonlight set, ElvUI and Guild Wars 2, resolved by the
-- real engine and built by the real decoration builder and element styles on real windows.
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
local savedTheme = "Default"
local originalGetTheme, originalSetTheme = db.GetTheme, db.SetTheme

local fonts = trackStub("Fonts")
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

local THEME_FILES = { "base", "default", "simpledark", "moonlight", "elvui", "gw2" }

describe("BetterBags' other themes", function()
  local originalSend, originalThemes

  before_each(function()
    originalThemes = sonata.themes
    sonata.themes = {}
    sonata:Init()
    for _, file in ipairs(THEME_FILES) do
      assert(loadfile("sonata/themes/" .. file .. ".lua"))("BetterBags")
    end
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

    -- Dark Round was folded into Dark: Dark kept its square frame and tabs and took Dark Round's
    -- darker fill (black at 0.75, baked into dark-frame.png).
    it("lists Dark and Parchment, built on a hidden Moonlight base, and no Dark Round", function()
      local all = sonata:GetAllThemes()
      assert.is_nil(all.Moonlight)
      assert.is_nil(sonata:GetTheme("DarkRound"))
      for key, name in pairs({ Dark = "Dark", Parchment = "Parchment" }) do
        assert.is_not_nil(all[key], key)
        assert.are.equal(name, sonata:GetTheme(key).DisplayName)
        assert.are.equal("Moonlight", sonata:GetTheme(key).Parent)
      end
    end)

    it("frames every window in its art, nine-sliced, with Moonlight's content box", function()
      for key, art in pairs({ Dark = { "dark-frame.png", "Tiled", 48 }, Parchment = { "parchment.png", "Stretched", 40 } }) do
        local bag, panel = newWindow("Bag"), newWindow("Panel")
        apply(key)
        for _, w in ipairs({ bag, panel }) do
          local bg = w.decoration:GetTexture("Background")
          assert.are.equal(ART .. art[1], bg:GetTexture(), key)
          assert.are.same({ left = 24, top = 24, right = 24, bottom = 24 }, bg._sliceMargins, key)
          assert.are.equal(Enum.UITextureSliceMode[art[2]], bg._sliceMode, key)
          assert.is_nil(w.decoration:GetTemplateFrame(), key)
        end
        assert.are.same({ Left = 18, Right = 24, Top = art[3], Bottom = 12 }, bag.decoration:GetInsets(), key)
      end
    end)

    -- Dark's frame has a heavy border whose inside starts about 16 in (dark-frame.png): its menu
    -- button sits inside it, the title and search box move to make room, and the money and
    -- currencies sit on its footer, inside the border too.
    it("keeps Dark's menu button inside its frame's border, with the title and search box clear of it", function()
      local bag = newWindow("Bag")
      apply("Dark")
      local layout = bag.decoration:GetLayout()
      assert.are.same({ { Point = "TOPLEFT", X = 14, Y = -12 } }, layout.MenuButton.Points)
      assert.are.same({ "TOPLEFT", bag.frame, "TOPLEFT", 50, -15 }, { bag.decoration:GetTitleText():GetPoint(1) })
      assert.are.same({
        { Point = "TOPLEFT", X = 18, Y = -48 },
        { Point = "BOTTOMRIGHT", RelativePoint = "TOPRIGHT", X = -24, Y = -68 },
      }, layout.Search.Points)
      assert.are.equal(24, layout.Search.Reserve)
      assert.are.same({ Left = 18, Right = 24, Bottom = 12, Height = 20, Reserve = 26 }, layout.Footer)
      -- Only Dark: Parchment and Slate keep Moonlight's.
      apply("Slate")
      assert.are.same({ { Point = "TOPLEFT", X = 8, Y = -6 } }, bag.decoration:GetLayout().MenuButton.Points)
      assert.are.same({ "TOPLEFT", bag.frame, "TOPLEFT", 44, -15 }, { bag.decoration:GetTitleText():GetPoint(1) })
    end)

    -- Slate is Moonlight's own default theme: Blizzard's marble, tiled the way Blizzard tiles it
    -- (CommunitiesMemberList.xml: horizTile and vertTile), with no border art.
    it("draws Slate, Moonlight's default, in Blizzard's tiled marble, fading with the opacity", function()
      assert.are.equal("Slate", sonata:GetTheme("Slate").DisplayName)
      assert.are.equal("Moonlight", sonata:GetTheme("Slate").Parent)
      local windows = {}
      for _, kind in ipairs({ "Bag", "Panel", "Flat", "Dialog", "Slots", "Search" }) do
        windows[kind] = newWindow(kind, 60)
      end
      apply("Slate")
      for kind, w in pairs(windows) do
        local bg = w.decoration:GetTexture("Background")
        assert.are.equal("Interface\\FrameGeneral\\UI-Background-Marble", bg:GetTexture(), kind)
        assert.is_true(bg:GetHorizTile(), kind)
        assert.is_true(bg:GetVertTile(), kind)
        assert.are.same({ "REPEAT", "REPEAT" }, { bg._wrapH, bg._wrapV }, kind)
        assert.is_nil(bg._sliceMargins, kind)
        assert.are.equal(0.6, bg:GetAlpha(), kind)
      end
      assert.are.same({ Left = 18, Right = 24, Top = 40, Bottom = 12 }, windows.Bag.decoration:GetInsets())
      assert.are.equal("X", windows.Bag.decoration:GetCloseButton():GetText())
    end)

    -- The set's own geometry, which Slate keeps (Dark moves its button, title and search box in).
    it("titles at the top left in white, with a lettered close button and the corner grip", function()
      local bag = newWindow("Bag")
      apply("Slate")
      local title = bag.decoration:GetTitleText()
      assert.are.same({ "TOPLEFT", bag.frame, "TOPLEFT", 44, -15 }, { title:GetPoint(1) })
      assert.are.same({ 1, 1, 1, 1 }, { title:GetTextColor() })
      local close = bag.decoration:GetCloseButton()
      assert.are.equal("X", close:GetText())
      assert.are.same({ 32, 32 }, { close:GetWidth(), close:GetHeight() })
      local layout = sonata:Resolve("Slate").Windows.Bag.Layout
      assert.are.same({ { Point = "TOPLEFT", X = 8, Y = -6 } }, layout.MenuButton.Points)
      assert.are.equal(32, sonata:Resolve("Slate").Elements.BagButton.Size)
      assert.are.equal(32, sonata:Resolve("Dark").Elements.BagButton.Size)
    end)

    it("hangs Parchment's ribbon over the top, under a centered title", function()
      local bag = newWindow("Bag")
      apply("Parchment")
      local ribbon = bag.decoration:GetTexture("Ribbon")
      assert.are.equal(ART .. "parchment-ribbon.png", ribbon:GetTexture())
      assert.are.same({ "BOTTOM", bag.frame, "TOP", 0, -40 }, { ribbon:GetPoint(1) })
      assert.are.same({ 281, 84 }, { ribbon:GetWidth(), ribbon:GetHeight() })
      local title = bag.decoration:GetTitleText()
      assert.are.same({ "BOTTOM", ribbon, "BOTTOM", 0, 25 }, { title:GetPoint(1) })
    end)

    it("ships the art it uses with BetterBags, and not Dark Round's frame", function()
      for _, file in ipairs({ "dark-frame.png", "parchment.png", "parchment-ribbon.png" }) do
        local f = io.open("textures/moonlight/" .. file, "rb")
        assert.is_not_nil(f, file)
        f:close()
      end
      assert.is_nil(io.open("textures/moonlight/dark-round.png", "rb"))
    end)
  end)

  describe("ElvUI", function()
    local savedElvUI

    -- elvui stands in for ElvUI's engine (unpack(ElvUI) is E): the media, textures and pixel
    -- settings the theme reads.
    local function elvui(opts)
      opts = opts or {}
      local E = {
        media = {
          blankTex = "Interface\\ElvUIBlank",
          glossTex = "Interface\\ElvUINorm",
          bordercolor = { 0.1, 0.1, 0.1 },
          backdropcolor = { 0.2, 0.2, 0.2 },
          backdropfadecolor = { 0.06, 0.06, 0.06, 0.8 },
          rgbvaluecolor = { 0.1, 0.6, 0.9 },
        },
        Media = { Textures = { Close = "Interface\\ElvUIClose", BagQuestIcon = "Interface\\ElvUIQuest",
          BagUpgradeIcon = "Interface\\ElvUIUpgrade" } },
        PixelMode = opts.pixel ~= false,
        twoPixelsPlease = opts.two == true,
        Modern = opts.modern ~= false,
        Border = opts.pixel == false and 2 or 1,
        TexCoords = { 0.08, 0.92, 0.08, 0.92 },
      }
      function E:Scale(n) return n end
      _G.ElvUI = { E }
      return E
    end

    before_each(function()
      savedElvUI = _G.ElvUI
      _G.ElvUI = nil
    end)

    after_each(function()
      _G.ElvUI = savedElvUI
    end)

    it("keeps its saved key and is offered only while ElvUI is loaded", function()
      assert.are.equal("ElvUI", sonata:GetTheme("elvui").DisplayName)
      assert.is_false(sonata:IsAvailable("elvui"))
      elvui()
      assert.is_true(sonata:IsAvailable("elvui"))
    end)

    it("draws every window in ElvUI's transparent template, which ElvUI's opacity owns", function()
      elvui()
      local windows = {}
      for _, kind in ipairs({ "Bag", "Panel", "Flat", "Dialog", "Slots", "Search" }) do
        windows[kind] = newWindow(kind, 40)
      end
      apply("elvui")
      for kind, w in pairs(windows) do
        local backdrop = w.frame._backdrop
        assert.are.equal("Interface\\ElvUIBlank", backdrop.bgFile, kind)
        assert.are.equal("Interface\\ElvUIBlank", backdrop.edgeFile, kind)
        assert.are.equal(1, backdrop.edgeSize, kind)
        assert.are.same({ 0.06, 0.06, 0.06, 0.8 }, color(w.frame._backdropColor), kind)
        assert.are.same({ 0.1, 0.1, 0.1, 1 }, color(w.frame._backdropBorderColor), kind)
        assert.are.equal(0, #w.decoration:GetOutlineFrames(), kind)
      end
    end)

    it("draws two-pixel edges, and black inner and outer lines outside pixel mode", function()
      elvui({ pixel = false, two = true })
      local w = newWindow("Bag")
      apply("elvui")
      assert.are.equal(2, w.frame._backdrop.edgeSize)
      local outlines = w.decoration:GetOutlineFrames()
      assert.are.equal(2, #outlines)
      assert.are.same({ "TOPLEFT", w.frame, "TOPLEFT", 1, -1 }, { outlines[1]:GetPoint(1) })
      assert.are.same({ "TOPLEFT", w.frame, "TOPLEFT", -1, 1 }, { outlines[2]:GetPoint(1) })
      for _, o in ipairs(outlines) do
        assert.are.same({ 0, 0, 0, 1 }, color(o._backdropBorderColor))
      end
    end)

    it("titles windows in white at the top, with ElvUI's close button", function()
      elvui()
      local bag, dialog = newWindow("Bag"), newWindow("Dialog")
      apply("elvui")
      local title = bag.decoration:GetTitleText()
      assert.are.equal(GameFontWhite, title:GetFontObject())
      assert.are.same({ "TOP", bag.frame, "TOP", 0, 0 }, { title:GetPoint(1) })
      local close = bag.decoration:GetCloseButton()
      assert.are.same({ 24, 24 }, { close:GetWidth(), close:GetHeight() })
      assert.are.same({ "TOPRIGHT", bag.frame, "TOPRIGHT", -4, -4 }, { close:GetPoint(1) })
      local art = close:GetNormalTexture()
      assert.are.equal("Interface\\ElvUIClose", art:GetTexture())
      assert.are.same({ "TOPLEFT", close, "TOPLEFT", 6, -6 }, { art:GetPoint(1) })
      assert.are.same({ 6, 6, 7, 7 }, { close:GetHitRectInsets() })
      close:GetScript("OnEnter")(close)
      assert.are.same({ 0.1, 0.6, 0.9, 1 }, { art:GetVertexColor() })
      assert.is_nil(dialog.decoration:GetCloseButton())
    end)

    it("keeps Masque off its buttons, and draws them like ElvUI's bags", function()
      elvui()
      apply("elvui")
      assert.is_false(sonata:UsesMasque())
      local item = sonata:GetElementStyle("ItemButton")
      assert.are.same({ Inset = 1, TexCoords = { 0.08, 0.92, 0.08, 0.92 } }, item.Icon)
      assert.are.same({ 0.2, 0.2, 0.2, 1 }, item.Backdrop.Color)
      assert.are.same({ 0.1, 0.1, 0.1, 1 }, item.Backdrop.BorderColor)
      assert.are.equal("Backdrop", item.QualityBorder)
      assert.are.same({ 0, 0, 0, 1 }, item.QualityColors[1])
      assert.are.same({ Texture = "Interface\\ElvUIQuest" }, item.QuestIcon)
      assert.are.same({ 1, 0.8, 0, 1 }, item.QuestBorderColor)
      assert.are.same({ Texture = "Interface\\ElvUIUpgrade", Scale = 1.2 }, item.UpgradeIcon)
      local inside = { Left = 1, Right = 1, Top = 1, Bottom = 1 }
      assert.are.same({ Color = { 1, 1, 1, 0.3 }, BlendMode = "ADD", Inset = inside }, item.Highlight)
      assert.are.same({ Color = { 1, 1, 1, 0.3 }, BlendMode = "ADD", Inset = inside }, item.Pushed)
    end)

    it("flattens tabs, the search box and dialog buttons into ElvUI's template", function()
      elvui({ modern = false, pixel = false })
      apply("elvui")
      local tab = sonata:GetElementStyle("Tab")
      assert.are.equal("Flat", tab.Art)
      assert.are.same({ Left = 10, Right = 10, Top = 3, Bottom = 3 }, tab.Background.Inset)
      assert.are.same({ 0.2, 0.2, 0.2, 1 }, tab.Background.Color)
      assert.are.same({ Color = { 0.1, 0.1, 0.1, 1 }, EdgeSize = 1, Inset = { Left = 10, Right = 10, Top = 3, Bottom = 3 } }, tab.Border)
      assert.are.same({ X = 0, Y = 0 }, tab.TextOffset)
      assert.are.same({ X = 0, Y = 0 }, tab.SelectedTextOffset)
      local search = sonata:GetElementStyle("SearchBox")
      assert.is_true(search.Strip)
      assert.are.same({ Color = { 0.2, 0.2, 0.2, 1 }, Inset = { Left = -4, Right = -4, Top = 0, Bottom = 0 } }, search.Background)
      local button = sonata:GetElementStyle("Button")
      assert.is_true(button.Strip)
      assert.are.same({ Texture = "Interface\\ElvUINorm", VertexColor = { 0.2, 0.2, 0.2, 1 } }, button.Background)
      assert.are.same({ 0.1, 0.6, 0.9, 1 }, button.HoverBorderColor)
      assert.is_false(button.Highlight)
      assert.is_true(sonata:GetElementStyle("EditBox").Strip)
    end)

    it("puts the search box and menu button where its bag drew them", function()
      elvui()
      local layout = sonata:Resolve("elvui").Windows.Bag.Layout
      assert.are.same({
        { Point = "TOPLEFT", X = 10, Y = -40 },
        { Point = "BOTTOMRIGHT", RelativePoint = "TOPRIGHT", X = -10, Y = -60 },
      }, layout.Search.Points)
      assert.are.same({ { Point = "TOPLEFT", X = 4, Y = -6 } }, layout.MenuButton.Points)
    end)
  end)

  describe("Guild Wars 2", function()
    local GW = "Interface\\AddOns\\GW2_UI\\Textures\\"
    local LIGHT_HEADER = { 1, 0.9450, 0.8196, 1 }
    local savedGW

    before_each(function()
      savedGW = _G.GW2_ADDON
      _G.GW2_ADDON = nil
    end)

    after_each(function()
      _G.GW2_ADDON = savedGW
    end)

    -- gw2 stands in for GW2_UI's namespace: the font settings the theme reads.
    local function gw2()
      _G.GW2_ADDON = { settings = { fonts = { size = { bigHeader = 20, normal = 13 }, outline = "NONE" } } }
    end

    local function sized(kind, width)
      local w = newWindow(kind)
      w.frame:SetSize(width or 400, 300)
      return w
    end

    it("keeps its saved key and is offered only while GW2_UI is loaded", function()
      assert.are.equal("Guild Wars 2", sonata:GetTheme("GW2").DisplayName)
      assert.is_false(sonata:IsAvailable("GW2"))
      gw2()
      assert.is_true(sonata:IsAvailable("GW2"))
    end)

    it("frames the bag in GW2's header, side panel, footer and world map background", function()
      gw2()
      local bag, wide = sized("Bag", 400), sized("Bag", 800)
      apply("GW2")
      local d = bag.decoration
      local bg = d:GetTexture("Background")
      assert.are.equal(GW .. "character\\worldmap-background.png", bg:GetTexture())
      assert.are.same({ "TOPLEFT", bag.frame, "TOPLEFT", 0, -25 }, { bg:GetPoint(1) })
      local left = d:GetTexture("HeaderLeft")
      assert.are.equal(GW .. "bag\\bagheader.png", left:GetTexture())
      assert.are.same({ "BOTTOMLEFT", bag.frame, "TOPLEFT", 0, -25 }, { left:GetPoint(1) })
      assert.are.same({ 380, 64 }, { left:GetWidth(), left:GetHeight() })
      assert.are.equal(512, wide.decoration:GetTexture("HeaderLeft"):GetWidth())
      local right = d:GetTexture("HeaderRight")
      assert.are.equal(GW .. "bag\\bagheader-right.png", right:GetTexture())
      assert.are.same({ "BOTTOMRIGHT", bag.frame, "TOPRIGHT", 0, -25 }, { right:GetPoint(1) })
      local icon = d:GetTexture("Icon")
      assert.are.equal(GW .. "bag\\bagicon.png", icon:GetTexture())
      assert.are.same({ "CENTER", bag.frame, "TOPLEFT", -16, 0 }, { icon:GetPoint(1) })
      assert.are.same({ 84, 84 }, { icon:GetWidth(), icon:GetHeight() })
      local footer = d:GetTexture("Footer")
      assert.are.equal(GW .. "bag\\bagfooter.png", footer:GetTexture())
      assert.are.same({ "TOPLEFT", bag.frame, "BOTTOMLEFT", 0, 30 }, { footer:GetPoint(1) })
      assert.are.equal(55, footer:GetHeight())
      local panel = d:GetTexture("LeftPanel")
      assert.are.equal(GW .. "bag\\bagleftpanel.png", panel:GetTexture())
      assert.are.same({ "TOPRIGHT", bag.frame, "TOPLEFT", 0, 25 }, { panel:GetPoint(1) })
      assert.are.equal(40, panel:GetWidth())
    end)

    it("titles the bag on its header in GW2's header font, with GW2's close button", function()
      gw2()
      local bag = sized("Bag")
      apply("GW2")
      local title = bag.decoration:GetTitleText()
      assert.are.same({ DAMAGE_TEXT_FONT, 22, "" }, { title:GetFont() })
      assert.are.same(LIGHT_HEADER, { title:GetTextColor() })
      assert.are.same({ "BOTTOMLEFT", bag.decoration:GetTexture("HeaderLeft"), "BOTTOMLEFT", 35, 10 }, { title:GetPoint(1) })
      local close = bag.decoration:GetCloseButton()
      assert.is_truthy(close._template:find("UIPanelCloseButtonNoScripts"))
      assert.are.same({ "TOPRIGHT", bag.frame, "TOPRIGHT", -5, 14 }, { close:GetPoint(1) })
      assert.are.equal(GW .. "uistuff\\window-close-button-normal.png", close:GetNormalTexture():GetTexture())
      assert.are.equal(GW .. "uistuff\\window-close-button-hover.png", close:GetHighlightTexture():GetTexture())
    end)

    it("replaces the menu button with GW2's side buttons", function()
      gw2()
      local layout = sonata:Resolve("GW2").Windows.Bag.Layout
      -- false removes the menu button Base places; the bag hides it.
      assert.is_nil(layout.MenuButton)
      assert.are.same({ { Point = "TOPLEFT", X = -35, Y = -40 } }, layout.Actions.Points)
      assert.are.equal(32, layout.Actions.Size)
      assert.are.equal(5, layout.Actions.Spacing)
      local actions, art = {}, {}
      for _, b in ipairs(layout.Actions.Buttons) do
        table.insert(actions, b.Action)
        table.insert(art, b.Normal.Texture)
        assert.are.same(b.Normal, b.Highlight)
      end
      assert.are.same({ "ShowBags", "Sort", "Settings", "Menu" }, actions)
      assert.are.same({
        GW .. "icons\\bagmicrobutton-up.png",
        GW .. "icons\\microicons\\collectionsmicrobutton-up.png",
        GW .. "icons\\microicons\\questlogmicrobutton-up.png",
        GW .. "icons\\microicons\\mainmenumicrobutton-up.png",
      }, art)
      assert.are.same({
        { Point = "TOPLEFT", X = 0, Y = -40 },
        { Point = "BOTTOMRIGHT", RelativePoint = "TOPRIGHT", X = -10, Y = -60 },
      }, layout.Search.Points)
    end)

    it("draws the other windows in GW2's tooltip backdrop and header font", function()
      gw2()
      local panel, flat, dialog, slots = sized("Panel"), sized("Flat"), sized("Dialog"), sized("Slots")
      apply("GW2")
      for _, w in ipairs({ panel, flat, dialog, slots }) do
        local backdrop = w.frame._backdrop
        assert.are.equal(GW .. "uistuff\\ui-tooltip-background.png", backdrop.bgFile)
        assert.are.equal(GW .. "uistuff\\ui-tooltip-border.png", backdrop.edgeFile)
        assert.are.equal(32, backdrop.edgeSize)
        assert.are.same({ left = 2, right = 2, top = 2, bottom = 2 }, backdrop.insets)
      end
      local title = panel.decoration:GetTitleText()
      assert.are.same({ DAMAGE_TEXT_FONT, 16, "" }, { title:GetFont() })
      assert.are.same(LIGHT_HEADER, { title:GetTextColor() })
      assert.are.same({ "TOP", panel.frame, "TOP", 0, -5 }, { title:GetPoint(1) })
      for _, w in ipairs({ panel, flat }) do
        assert.are.same({ "TOPRIGHT", w.frame, "TOPRIGHT", -1, -1 }, { w.decoration:GetCloseButton():GetPoint(1) })
      end
      assert.is_nil(dialog.decoration:GetCloseButton())
      assert.is_true(slots.decoration:GetTitleText() == nil or not slots.decoration:GetTitleText():IsShown())
    end)

    it("draws the search box on GW2's search bar, in its font", function()
      gw2()
      local style = sonata:Resolve("GW2").Elements.SearchBox
      assert.is_true(style.HideCaps)
      assert.are.equal(GW .. "bag\\bagsearchbg.png", style.Middle.Texture)
      assert.are.same({ { Point = "LEFT" }, { Point = "RIGHT" } }, style.Middle.Points)
      assert.are.equal(24, style.Middle.Height)
      assert.are.same({ Atlas = "common-search-magnifyingglass", Width = 10, Height = 10,
        Points = { { Point = "LEFT", X = 6 } } }, style.SearchIcon)
      assert.are.same({ Left = 20, Right = 20, Top = 0, Bottom = 0 }, style.TextInsets)
      assert.are.same({ Path = UNIT_NAME_FONT, Size = 13, Flags = "", Color = { 1, 1, 1, 1 } }, style.Font)
      assert.are.same({ Object = "UnitFrame12White" }, sonata:Resolve("GW2").Elements.SectionHeader.Font)
    end)
  end)

  -- Parchment's light paper needs dark text: its text roles take Blizzard's parchment text
  -- colors (GlobalColor: PARCHMENT_MATERIAL_TEXT_COLOR, PARCHMENT_MATERIAL_TITLETEXT_COLOR,
  -- PARCHMENTLARGE_MATERIAL_TITLETEXT_COLOR, PARCHMENT_ACCESSIBILITY_GREEN/RED) and drop the
  -- black shadow; the dark themes keep Base's white text.
  describe("text", function()
    local function roleColor(role)
      local r, g, b, a = sonata:GetTextFont(role):GetTextColor()
      return { r, g, b, a }
    end
    local function roleShadow(role)
      local font = sonata:GetTextFont(role)
      local r, g, b, a = font:GetShadowColor()
      local x, y = font:GetShadowOffset()
      return { r, g, b, a, x, y }
    end

    it("draws Parchment's text in Blizzard's parchment colors, without a shadow", function()
      apply("Parchment")
      local BODY, TITLE = { 46 / 255, 31 / 255, 15 / 255, 1 }, { 0, 0, 0, 1 }
      for _, role in ipairs({ "Heading", "Body", "BodySmall", "BodyLarge", "Nav", "NavSub", "Search", "Count", "Money" }) do
        assert.are.same(BODY, roleColor(role), role)
      end
      for _, role in ipairs({ "Title", "Field", "FieldSmall", "NavActive", "NavSubActive" }) do
        assert.are.same(TITLE, roleColor(role), role)
      end
      assert.are.same({ 0.36, 0.22, 0.1, 1 }, roleColor("Label"))
      assert.are.same({ 0.36, 0.22, 0.1, 1 }, roleColor("Description"))
      assert.are.same({ 0.455, 0.286, 0.176, 1 }, roleColor("Muted"))
      assert.are.same({ 0.455, 0.286, 0.176, 1 }, roleColor("Empty"))
      assert.are.same({ 53 / 255, 0, 0, 1 }, roleColor("NavHover"))
      assert.are.same({ 19 / 255, 68 / 255, 4 / 255, 1 }, roleColor("Positive"))
      assert.are.same({ 172 / 255, 3 / 255, 3 / 255, 1 }, roleColor("Negative"))
      assert.are.same({ 0, 0, 0, 0, 0, 0 }, roleShadow("Body"))
      assert.are.same({ 1, 0.82, 0, 0.35, 0, 0 }, roleShadow("NavActive"))
    end)

    it("titles Parchment's windows in its text color without a shadow, and letters its close button in black", function()
      local panel, bag = newWindow("Panel"), newWindow("Bag")
      apply("Parchment")
      for _, w in ipairs({ panel, bag }) do
        local title = w.decoration:GetTitleText()
        assert.are.same({ 46 / 255, 31 / 255, 15 / 255, 1 }, { title:GetTextColor() })
        assert.are.same({ 0, 0, 0, 0 }, { title:GetShadowColor() })
        assert.are.equal(GameFontBlack, w.decoration:GetCloseButton():GetNormalFontObject())
      end
      local section = sonata:Resolve("Parchment").Elements.SectionHeader.Font
      assert.are.same({ Object = "GameFontNormal", Color = { 0, 0, 0, 1 }, Shadow = { Color = { 0, 0, 0, 0 }, X = 0, Y = 0 } },
        section)
    end)

    it("keeps Base's white text on the dark themes", function()
      for _, key in ipairs({ "Dark", "Slate", "SimpleDark" }) do
        apply(key)
        assert.are.same({ 1, 1, 1, 1 }, roleColor("Body"), key)
        assert.are.same({ 1, 0.82, 0, 1 }, roleColor("Title"), key)
        assert.are.same({ 0, 0, 0, 1, 1, -1 }, roleShadow("Body"), key)
        if key ~= "SimpleDark" then
          local w = newWindow("Panel")
          apply(key)
          assert.are.same({ 1, 1, 1, 1 }, { w.decoration:GetTitleText():GetTextColor() }, key)
          assert.are.same({ 0, 0, 0, 1 }, { w.decoration:GetTitleText():GetShadowColor() }, key)
          assert.are.equal(GameFontNormal, w.decoration:GetCloseButton():GetNormalFontObject(), key)
        end
      end
    end)
  end)

  -- Every built-in theme but Default (Blizzard's tabs) and ElvUI (ElvUI's flat tabs, covered
  -- above) draws its own flat tabs, styled here on a real tab through the real styler.
  describe("tabs", function()
    local elements = addon:GetModule("SonataElements")
    local MOONLIGHT = "Interface\\AddOns\\BetterBags\\textures\\moonlight\\"
    local savedGW

    before_each(function()
      savedGW = _G.GW2_ADDON
      _G.GW2_ADDON = { settings = { fonts = { size = { bigHeader = 20, normal = 13, small = 11 }, outline = "NONE" } } }
    end)

    after_each(function()
      _G.GW2_ADDON = savedGW
    end)

    local function tabFor(key)
      apply(key)
      local tab = CreateFrame("Button", nil, UIParent, "PanelTabButtonTemplate")
      sonata:RegisterElement("Tab", tab)
      return tab
    end

    local function textColor(tab)
      return { tab._normalFontObject:GetTextColor() }
    end

    local function rgba(t)
      return { t.r, t.g, t.b, t.a }
    end

    it("hides Blizzard's tab art on every theme with its own tabs, and sizes them alike", function()
      for _, key in ipairs({ "SimpleDark", "Dark", "Parchment", "GW2", "Slate" }) do
        local tab = tabFor(key)
        assert.are.equal(0, tab.Left:GetAlpha(), key)
        assert.are.equal(0, tab.LeftActive:GetAlpha(), key)
        assert.are.equal(26, tab:GetHeight(), key)
        assert.is_true(tab.sonataSkin.fill:IsShown(), key)
        elements:SetTabState(tab, "selected")
        local _, _, _, x, y = tab.Text:GetPoint(1)
        assert.are.same({ 0, -1 }, { x, y }, key)
      end
    end)

    it("draws Simple Dark's tabs black in the window's gray edge, the selected one lighter and white", function()
      local tab = tabFor("SimpleDark")
      local skin = tab.sonataSkin
      assert.are.same({ 0, 0, 0, 1 }, rgba(skin.fill._colorTexture))
      assert.are.same({ 0.5, 0.5, 0.5, 1 }, rgba(skin.edges[1]._colorTexture))
      assert.are.equal(1, skin.edges[1]:GetHeight())
      assert.are.same({ 0.7, 0.7, 0.7, 1 }, textColor(tab))
      elements:SetTabState(tab, "selected")
      assert.is_true(skin.selectedFill:IsShown())
      assert.are.same({ 0.12, 0.12, 0.12, 1 }, rgba(skin.selectedFill._colorTexture))
      assert.are.same({ 1, 1, 1, 1 }, textColor(tab))
    end)

    it("draws Dark's tabs in the frame's translucent black and heavy black edge", function()
      local tab = tabFor("Dark")
      local skin = tab.sonataSkin
      assert.are.same({ 0, 0, 0, 0.55 }, rgba(skin.fill._colorTexture))
      assert.are.same({ 0.01, 0.01, 0.01, 1 }, rgba(skin.edges[1]._colorTexture))
      assert.are.equal(3, skin.edges[1]:GetHeight())
      elements:SetTabState(tab, "selected")
      assert.are.same({ 1, 1, 1, 0.1 }, rgba(skin.selectedFill._colorTexture))
      assert.are.same({ 1, 1, 1, 1 }, textColor(tab))
    end)

    it("cuts Parchment's tabs from its paper, dimmed until selected, in a burnt edge and brown text", function()
      local tab = tabFor("Parchment")
      local skin = tab.sonataSkin
      assert.are.equal(MOONLIGHT .. "parchment.png", skin.fill:GetTexture())
      -- GetTexCoord returns the corners: upper left, lower left, upper right, lower right.
      assert.are.same({ 0.25, 0.3, 0.25, 0.5, 0.75, 0.3, 0.75, 0.5 }, { skin.fill:GetTexCoord() })
      assert.are.same({ 0.8, 0.76, 0.7, 1 }, { skin.fill:GetVertexColor() })
      assert.are.same({ 0.455, 0.286, 0.176, 1 }, rgba(skin.edges[1]._colorTexture))
      -- Its own hover starts where its art does, not over the window.
      assert.are.same({ "TOPLEFT", tab, "TOPLEFT", 0, -2 }, { skin.hover:GetPoint(1) })
      assert.are.same({ 0.36, 0.22, 0.1, 1 }, textColor(tab))
      assert.are.same({ 0, 0 }, { tab._normalFontObject:GetShadowOffset() })
      elements:SetTabState(tab, "selected")
      assert.are.equal(MOONLIGHT .. "parchment.png", skin.selectedFill:GetTexture())
      assert.are.same({ 1, 1, 1, 1 }, { skin.selectedFill:GetVertexColor() })
      assert.are.same({ 0.18, 0.09, 0.03, 1 }, textColor(tab))
    end)

    it("draws GW2's tabs with GW2's downward tab art, its font, and its accent under the selected one", function()
      local tab = tabFor("GW2")
      local skin = tab.sonataSkin
      assert.are.equal("Interface\\AddOns\\GW2_UI\\Textures\\units\\unittab_down.png", skin.fill:GetTexture())
      assert.is_true(skin.edges == nil or not skin.edges[1]:IsShown())
      local file, size = tab._normalFontObject:GetFont()
      assert.are.same({ UNIT_NAME_FONT, 11 }, { file, size })
      assert.are.same({ 0.78, 0.76, 0.7, 1 }, textColor(tab))
      elements:SetTabState(tab, "selected")
      assert.is_true(skin.bar:IsShown())
      assert.are.same({ 150 / 255, 50 / 255, 50 / 255, 1 }, rgba(skin.bar._colorTexture))
      assert.are.same({ "BOTTOMLEFT", tab, "BOTTOMLEFT", 1, 1 }, { skin.bar:GetPoint(1) })
      assert.are.same({ 1, 0.9450, 0.8196, 1 }, textColor(tab))
    end)

    it("draws Slate's tabs in the tiled marble, with a cool gray bar under the selected one", function()
      local tab = tabFor("Slate")
      local skin = tab.sonataSkin
      assert.are.equal("Interface\\FrameGeneral\\UI-Background-Marble", skin.fill:GetTexture())
      assert.is_true(skin.fill:GetHorizTile())
      assert.is_true(skin.fill:GetVertTile())
      assert.are.same({ "REPEAT", "REPEAT" }, { skin.fill._wrapH, skin.fill._wrapV })
      assert.are.same({ 0.18, 0.18, 0.18, 1 }, rgba(skin.edges[1]._colorTexture))
      elements:SetTabState(tab, "selected")
      assert.are.same({ 0.54, 0.56, 0.6, 1 }, rgba(skin.bar._colorTexture))
      assert.are.same({ "BOTTOMLEFT", tab, "BOTTOMLEFT", 1, 1 }, { skin.bar:GetPoint(1) })
      assert.are.same({ 1, 1, 1, 1 }, textColor(tab))
    end)

    it("leaves Default with Blizzard's tabs", function()
      local tab = tabFor("Default")
      assert.are.equal(1, tab.Left:GetAlpha())
      assert.is_true(tab.sonataSkin == nil or tab.sonataSkin.fill == nil or not tab.sonataSkin.fill:IsShown())
    end)
  end)
end)

teardown(function()
  for i = #createdStubs, 1, -1 do
    ResetModuleStub(createdStubs[i])
  end
end)
