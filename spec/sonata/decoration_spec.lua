-- decoration_spec.lua -- Window chrome built from a Sonata window style (sonata/decoration.lua):
-- Blizzard templates, backdrops, sliced textures, extra textures, titles, close buttons and
-- opacity, rebuilt cleanly on every theme switch.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")

local db = StubBetterBagsModule("Database")
db.GetTheme = db.GetTheme or function() return "Default" end
db.SetTheme = db.SetTheme or function() end

local fonts = StubBetterBagsModule("Fonts")
fonts.UnitFrame12Yellow = fonts.UnitFrame12Yellow or { name = "UnitFrame12Yellow" }

LoadBetterBagsModule("sonata/engine.lua")
LoadBetterBagsModule("sonata/apply.lua")
LoadBetterBagsModule("sonata/decoration.lua")

local sonata = addon:GetModule("Sonata")
local decoration = addon:GetModule("SonataDecoration")
local context = addon:GetModule("Context")

local windowCount = 0
local function newWindow(opts)
  opts = opts or {}
  windowCount = windowCount + 1
  local frame = CreateFrame("Frame", "SonataTestWindow" .. windowCount, UIParent, "BackdropTemplate")
  frame:SetFrameLevel(opts.level or 500)
  frame:SetSize(400, 300)
  local window = {
    frame = frame,
    title = opts.title or "My Window",
    opacity = opts.opacity or 100,
    closed = 0,
  }
  function window:GetTitle() return self.title end
  function window:GetOpacity() return self.opacity end
  function window:OnCloseClicked() self.closed = self.closed + 1 end
  return window
end

local function decorate(window, style)
  return decoration:Decorate(window, style, { Name = "Test" })
end

describe("SonataDecoration", function()
  local events = addon:GetModule("Events")
  local originalSend

  before_each(function()
    sonata:Init()
    originalSend = events.SendMessage
    events.SendMessage = function() end
  end)

  after_each(function()
    events.SendMessage = originalSend
  end)

  it("registers itself as Sonata's window decorator", function()
    sonata.themes = {}
    sonata:RegisterTheme({ Name = "Base", Hidden = true, Windows = { Bag = { Insets = { Top = 9 } } } })
    sonata:RegisterTheme({ Name = "Default" })
    local window = newWindow()
    sonata:RegisterWindow(window, "Bag")
    sonata:ApplyTheme(context:New("test"), "Default")
    assert.is_not_nil(window.decoration)
    assert.are.equal(window.decoration, sonata:GetDecoration(window))
    assert.are.equal(9, window.decoration:GetInsets().Top)
  end)

  describe("insets and layout", function()
    it("hands out the style's insets, zero for unset sides", function()
      local window = newWindow()
      local deco = decorate(window, { Insets = { Left = 6, Top = 42 } })
      assert.are.same({ Left = 6, Right = 0, Top = 42, Bottom = 0 }, deco:GetInsets())
    end)

    it("hands out the layout table, empty when the style has none", function()
      local window = newWindow()
      assert.are.same({}, decorate(window, {}):GetLayout())
      local deco = decorate(window, { Layout = { Search = { Top = 30 } } })
      assert.are.equal(30, deco:GetLayout().Search.Top)
    end)

    it("reuses one decoration per window", function()
      local window = newWindow()
      local first = decorate(window, {})
      local second = decorate(window, {})
      assert.are.equal(first, second)
      assert.are.equal(first, window.decoration)
    end)
  end)

  describe("Blizzard templates", function()
    local style = {
      Template = {
        Name = "DefaultPanelTemplate",
        Level = -1,
        Levels = { NineSlice = 500, TitleContainer = 501 },
        TitleFont = { Object = "UnitFrame12Yellow" },
      },
    }

    it("draws the template behind the window and titles it", function()
      local window = newWindow({ title = "Backpack" })
      local deco = decorate(window, style)
      local panel = deco:GetTemplateFrame()

      assert.are.equal(window.frame, panel:GetParent())
      assert.is_true(panel:IsShown())
      assert.are.equal(499, panel:GetFrameLevel())
      assert.are.equal(1000, panel.NineSlice:GetFrameLevel())
      assert.are.equal(1001, panel.TitleContainer:GetFrameLevel())
      assert.are.equal("Backpack", panel.TitleContainer.TitleText:GetText())
      assert.are.equal(fonts.UnitFrame12Yellow, panel.TitleContainer.TitleText._fontObject)
    end)

    it("never puts the template below level 0", function()
      local window = newWindow({ level = 0 })
      local deco = decorate(window, style)
      assert.are.equal(0, deco:GetTemplateFrame():GetFrameLevel())
    end)

    it("retitles the template", function()
      local window = newWindow()
      local deco = decorate(window, style)
      deco:SetTitle("Bank")
      assert.are.equal("Bank", deco:GetTemplateFrame().TitleContainer.TitleText:GetText())
    end)

    it("hides the template's title bar for an empty title when asked", function()
      local window = newWindow({ title = "" })
      local deco = decorate(window, {
        Template = { Name = "DefaultPanelFlatTemplate", HideTitleWhenEmpty = true },
      })
      assert.is_false(deco:GetTemplateFrame().TitleContainer:IsShown())
      deco:SetTitle("Now titled")
      assert.is_true(deco:GetTemplateFrame().TitleContainer:IsShown())
    end)

    it("fades the template's background with the window opacity", function()
      local window = newWindow({ opacity = 40 })
      local deco = decorate(window, { Template = { Name = "DefaultPanelTemplate", Opacity = "Bg" } })
      assert.are.equal(0.4, deco:GetTemplateFrame().Bg:GetAlpha())
      deco:SetOpacity(75)
      assert.are.equal(0.75, deco:GetTemplateFrame().Bg:GetAlpha())
    end)

    it("hides the template and reuses it when switching away and back", function()
      local window = newWindow()
      local deco = decorate(window, style)
      local panel = deco:GetTemplateFrame()
      decorate(window, {})
      assert.is_false(panel:IsShown())
      assert.is_nil(deco:GetTemplateFrame())
      decorate(window, style)
      assert.are.equal(panel, deco:GetTemplateFrame())
      assert.is_true(panel:IsShown())
    end)
  end)

  describe("backdrops", function()
    it("sets the backdrop and colors on the window frame itself", function()
      local window = newWindow()
      decorate(window, {
        Backdrop = {
          BgFile = "Interface\\ChatFrame\\ChatFrameBackground",
          EdgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
          EdgeSize = 1,
          Insets = { Left = 1, Right = 2, Top = 3, Bottom = 4 },
          Color = { 0, 0, 0, 1 },
          BorderColor = { 0.5, 0.5, 0.5, 1 },
        },
      })
      local backdrop = window.frame._backdrop
      assert.are.equal("Interface\\ChatFrame\\ChatFrameBackground", backdrop.bgFile)
      assert.are.equal(1, backdrop.edgeSize)
      assert.are.same({ left = 1, right = 2, top = 3, bottom = 4 }, backdrop.insets)
      assert.are.same({ r = 0, g = 0, b = 0, a = 1 }, window.frame._backdropColor)
      assert.are.same({ r = 0.5, g = 0.5, b = 0.5, a = 1 }, window.frame._backdropBorderColor)
    end)

    it("fades the backdrop fill with the window opacity but not its border", function()
      local window = newWindow({ opacity = 50 })
      local deco = decorate(window, {
        Backdrop = { BgFile = "bg", Color = { 0.1, 0.1, 0.1, 0.8 }, BorderColor = { 1, 1, 1, 1 } },
      })
      assert.are.equal(0.4, window.frame._backdropColor.a)
      assert.are.equal(1, window.frame._backdropBorderColor.a)
      deco:SetOpacity(100)
      assert.are.equal(0.8, window.frame._backdropColor.a)
    end)

    it("keeps the backdrop fill when opacity is turned off for it", function()
      local window = newWindow({ opacity = 50 })
      decorate(window, { Backdrop = { BgFile = "bg", Color = { 0, 0, 0, 1 }, Opacity = false } })
      assert.are.equal(1, window.frame._backdropColor.a)
    end)

    it("clears the backdrop when the next theme has none", function()
      local window = newWindow()
      decorate(window, { Backdrop = { BgFile = "bg" } })
      decorate(window, {})
      assert.is_nil(window.frame._backdrop)
    end)

    it("draws outline borders around or inside the window", function()
      local window = newWindow()
      local deco = decorate(window, {
        Backdrop = {
          BgFile = "bg",
          Outlines = {
            { Offset = 1, EdgeFile = "edge", EdgeSize = 1, Color = { 0, 0, 0, 1 } },
            { Offset = -1, EdgeFile = "edge", EdgeSize = 1, Color = { 0, 0, 0, 1 } },
          },
        },
      })
      local outlines = deco:GetOutlineFrames()
      assert.are.equal(2, #outlines)
      local _, _, _, x, y = outlines[1]:GetPoint(1)
      assert.are.same({ -1, 1 }, { x, y })
      _, _, _, x, y = outlines[2]:GetPoint(1)
      assert.are.same({ 1, -1 }, { x, y })
      assert.are.equal("edge", outlines[1]._backdrop.edgeFile)
      assert.is_false(outlines[1]._mouseEnabled)
      decorate(window, {})
      assert.is_false(outlines[1]:IsShown())
    end)
  end)

  describe("background, border and textures", function()
    it("draws a sliced background on the window frame, below everything else", function()
      local window = newWindow()
      local deco = decorate(window, {
        Background = {
          Texture = "Interface\\AddOns\\BetterBags\\textures\\dark.png",
          SliceMode = "Tiled",
          SliceMargins = { Left = 24, Top = 24, Right = 24, Bottom = 24 },
          VertexColor = { 1, 1, 1, 0.9 },
          Inset = { Left = 2, Right = 2, Top = 2, Bottom = 2 },
        },
      })
      local bg = deco:GetTexture("Background")
      assert.are.equal(window.frame, bg:GetParent())
      assert.are.equal("BACKGROUND", bg._drawLayer)
      assert.are.equal("Interface\\AddOns\\BetterBags\\textures\\dark.png", bg:GetTexture())
      assert.are.equal(Enum.UITextureSliceMode.Tiled, bg._sliceMode)
      assert.are.same({ left = 24, top = 24, right = 24, bottom = 24 }, bg._sliceMargins)
      assert.are.same({ r = 1, g = 1, b = 1, a = 0.9 }, bg._vertexColor)
      local point, relativeTo, relativePoint, x, y = bg:GetPoint(1)
      assert.are.same({ "TOPLEFT", window.frame, "TOPLEFT", 2, -2 }, { point, relativeTo, relativePoint, x, y })
      point, relativeTo, relativePoint, x, y = bg:GetPoint(2)
      assert.are.same({ "BOTTOMRIGHT", window.frame, "BOTTOMRIGHT", -2, 2 }, { point, relativeTo, relativePoint, x, y })
    end)

    it("fades the background with the window opacity", function()
      local window = newWindow({ opacity = 25 })
      local deco = decorate(window, { Background = { Color = { 0, 0, 0, 1 } } })
      assert.are.same({ r = 0, g = 0, b = 0, a = 1 }, deco:GetTexture("Background")._colorTexture)
      assert.are.equal(0.25, deco:GetTexture("Background"):GetAlpha())
    end)

    it("draws the border above the content when asked", function()
      local window = newWindow()
      local deco = decorate(window, { Border = { Texture = "border", Above = true } })
      local border = deco:GetTexture("Border")
      assert.are.equal(deco:GetOverlayFrame(), border:GetParent())
      assert.is_true(deco:GetOverlayFrame():GetFrameLevel() > window.frame:GetFrameLevel())
      assert.is_false(deco:GetOverlayFrame()._mouseEnabled)
    end)

    it("draws extra textures anchored to the window or to an earlier texture", function()
      local window = newWindow()
      local deco = decorate(window, {
        Textures = {
          { Name = "Header", Texture = "header.png", Layer = "ARTWORK", SubLevel = 2,
            Points = { { Point = "BOTTOMLEFT", RelativePoint = "TOPLEFT", X = 0, Y = -25 } },
            Size = { Width = 512, Height = 64 }, TexCoords = { 0, 1, 0, 0.5 } },
          { Name = "Icon", Atlas = "bags-icon", Points = { { Point = "CENTER", RelativeTo = "Header", RelativePoint = "LEFT", X = 21 } },
            Size = { Width = 84, Height = 84 } },
        },
      })
      local header = deco:GetTexture("Header")
      assert.are.equal("header.png", header:GetTexture())
      assert.are.equal("ARTWORK", header._drawLayer)
      assert.are.equal(2, header._sublevel)
      assert.are.equal(512, header:GetWidth())
      assert.are.same({ 0, 1, 0, 0.5 }, header._texCoords)
      local point, relativeTo, relativePoint, x, y = header:GetPoint(1)
      assert.are.same({ "BOTTOMLEFT", window.frame, "TOPLEFT", 0, -25 }, { point, relativeTo, relativePoint, x, y })
      local icon = deco:GetTexture("Icon")
      assert.are.equal("bags-icon", icon:GetAtlas())
      point, relativeTo, relativePoint, x = icon:GetPoint(1)
      assert.are.same({ "CENTER", header, "LEFT", 21 }, { point, relativeTo, relativePoint, x })
    end)

    it("errors on a texture anchored to a name it does not know", function()
      local window = newWindow()
      assert.has_error(function()
        decorate(window, { Textures = { { Name = "A", Texture = "a", Points = { { Point = "TOP", RelativeTo = "Nope" } } } } })
      end)
    end)

    it("caps a texture's width at a maximum that follows the window width", function()
      local window = newWindow()
      local deco = decorate(window, {
        Textures = { { Name = "Strip", Texture = "s", Size = { Height = 64, MaxWidth = 512, WidthOffset = -20 } } },
      })
      assert.are.equal(380, deco:GetTexture("Strip"):GetWidth())
      window.frame:SetWidth(800)
      window.frame:GetScript("OnSizeChanged")(window.frame, 800, 300)
      assert.are.equal(512, deco:GetTexture("Strip"):GetWidth())
    end)

    it("releases every texture of the previous theme", function()
      local window = newWindow()
      local deco = decorate(window, {
        Background = { Texture = "bg" },
        Textures = { { Name = "Extra", Texture = "x" } },
      })
      local bg, extra = deco:GetTexture("Background"), deco:GetTexture("Extra")
      decorate(window, {})
      assert.is_false(bg:IsShown())
      assert.is_false(extra:IsShown())
      assert.is_nil(bg:GetTexture())
      assert.is_nil(deco:GetTexture("Background"))
    end)

    it("reuses released textures instead of creating new ones", function()
      local window = newWindow()
      decorate(window, { Background = { Texture = "a" } })
      local created = #window.frame._textures
      decorate(window, { Background = { Texture = "b" } })
      assert.are.equal(created, #window.frame._textures)
    end)
  end)

  describe("titles", function()
    it("draws its own title when there is no template title", function()
      local window = newWindow({ title = "Settings" })
      local deco = decorate(window, {
        Title = {
          Font = { Path = "Fonts\\FRIZQT__.TTF", Size = 14, Flags = "OUTLINE" },
          Color = { 1, 0.9, 0.8, 1 },
          Points = { { Point = "TOP", Y = -5 } },
          Height = 30,
          Justify = "CENTER",
        },
      })
      local title = deco:GetTitleText()
      assert.are.equal("Settings", title:GetText())
      assert.are.equal("Fonts\\FRIZQT__.TTF", title._font)
      assert.are.equal(14, title._fontSize)
      assert.are.equal("OUTLINE", title._fontFlags)
      assert.are.same({ r = 1, g = 0.9, b = 0.8, a = 1 }, title._textColor)
      assert.are.equal(30, title:GetHeight())
      assert.are.equal("CENTER", title:GetJustifyH())
      deco:SetTitle("Other")
      assert.are.equal("Other", title:GetText())
    end)

    it("uses a named font object, BetterBags' own first", function()
      local window = newWindow()
      local deco = decorate(window, { Title = { Font = { Object = "UnitFrame12Yellow" } } })
      assert.are.equal(fonts.UnitFrame12Yellow, deco:GetTitleText()._fontObject)
      _G.SonataTestFont = { name = "global" }
      deco = decorate(window, { Title = { Font = { Object = "SonataTestFont" } } })
      assert.are.equal(_G.SonataTestFont, deco:GetTitleText()._fontObject)
    end)

    it("hides its title for a theme without one", function()
      local window = newWindow()
      local deco = decorate(window, { Title = {} })
      local title = deco:GetTitleText()
      decorate(window, {})
      assert.is_false(title:IsShown())
    end)
  end)

  describe("close buttons", function()
    it("builds the close button from a template and routes clicks to the window", function()
      local window = newWindow()
      local deco = decorate(window, { CloseButton = { Template = "UIPanelCloseButtonDefaultAnchors" } })
      local close = deco:GetCloseButton()
      assert.is_true(close._template:find("UIPanelCloseButtonDefaultAnchors") ~= nil)
      assert.is_true(close:IsShown())
      assert.is_true(close:GetFrameLevel() > deco:GetOverlayFrame():GetFrameLevel())
      close:GetScript("OnClick")(close, "LeftButton")
      assert.are.equal(1, window.closed)
      assert.is_true(window.frame:IsShown())
    end)

    it("sizes, places and textures a plain close button", function()
      local window = newWindow()
      local deco = decorate(window, {
        CloseButton = {
          Size = 12,
          Points = { { Point = "TOPRIGHT", X = -8, Y = -8 } },
          Normal = { Texture = "close.png" },
          Highlight = { Texture = "close.png" },
        },
      })
      local close = deco:GetCloseButton()
      assert.are.equal(12, close:GetWidth())
      assert.are.equal(12, close:GetHeight())
      assert.are.equal("close.png", close:GetNormalTexture():GetTexture())
      assert.are.equal("close.png", close:GetHighlightTexture():GetTexture())
      local point, relativeTo, relativePoint, x, y = close:GetPoint(1)
      assert.are.same({ "TOPRIGHT", window.frame, "TOPRIGHT", -8, -8 }, { point, relativeTo, relativePoint, x, y })
    end)

    it("replaces a template's art when the style says to", function()
      local window = newWindow()
      local deco = decorate(window, {
        CloseButton = {
          Template = "UIPanelCloseButtonNoScripts",
          Normal = { Texture = "gw-normal.png" },
          Highlight = { Texture = "gw-hover.png" },
          Pushed = { Texture = "gw-hover.png" },
          Disabled = { Texture = "gw-normal.png" },
        },
      })
      local close = deco:GetCloseButton()
      assert.are.equal("gw-normal.png", close:GetNormalTexture():GetTexture())
      assert.are.equal("gw-hover.png", close:GetPushedTexture():GetTexture())
      assert.are.equal("gw-normal.png", close:GetDisabledTexture():GetTexture())
    end)

    it("tints the close button while hovered", function()
      local window = newWindow()
      local deco = decorate(window, {
        CloseButton = { Normal = { Texture = "x.tga" }, HoverColor = { 0.09, 0.52, 0.82, 1 } },
      })
      local close = deco:GetCloseButton()
      close:GetScript("OnEnter")(close)
      assert.are.same({ r = 0.09, g = 0.52, b = 0.82, a = 1 }, close:GetNormalTexture()._vertexColor)
      close:GetScript("OnLeave")(close)
      assert.are.same({ r = 1, g = 1, b = 1, a = 1 }, close:GetNormalTexture()._vertexColor)
    end)

    it("hides the close button for a theme without one, and keeps one per template", function()
      local window = newWindow()
      local deco = decorate(window, { CloseButton = { Template = "UIPanelCloseButton" } })
      local templated = deco:GetCloseButton()
      deco = decorate(window, { CloseButton = { Size = 12 } })
      local plain = deco:GetCloseButton()
      assert.are_not.equal(templated, plain)
      assert.is_false(templated:IsShown())
      decorate(window, {})
      assert.is_false(plain:IsShown())
      assert.is_nil(deco:GetCloseButton())
      deco = decorate(window, { CloseButton = { Template = "UIPanelCloseButton" } })
      assert.are.equal(templated, deco:GetCloseButton())
    end)
  end)

  describe("telling the window", function()
    it("tells its window after every apply", function()
      local window = newWindow()
      local told = {}
      function window:OnDecorated(deco) table.insert(told, deco) end
      local deco = decorate(window, {})
      decorate(window, { Insets = { Top = 5 } })
      assert.are.same({ deco, deco }, told)
    end)
  end)

  describe("switching themes", function()
    it("leaves nothing of a templated theme behind when the next one is flat", function()
      local window = newWindow()
      decorate(window, {
        Template = { Name = "DefaultPanelTemplate" },
        CloseButton = { Template = "UIPanelCloseButtonDefaultAnchors" },
        Title = {},
      })
      local deco = decorate(window, { Backdrop = { BgFile = "bg" } })
      assert.is_nil(deco:GetTemplateFrame())
      assert.is_nil(deco:GetCloseButton())
      assert.is_false(deco:GetTitleText():IsShown())
      assert.are.equal("bg", window.frame._backdrop.bgFile)
    end)
  end)
end)
