local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

-- Guild Wars 2: BetterBags in GW2_UI's look, as data. Nothing of GW2_UI's is called
-- (CreateFrameHeaderWithBody, GwSkinButton, SkinBagSearchBox); its art is drawn from its own
-- files, and the variables read GW2_UI's font settings when the theme is applied.
--   The bag: GW2's window header (bagheader on the left, capped at 512 pixels, and
--     bagheader-right) with the bag icon at the corner, the world map background under it, the
--     side panel along the left with BetterBags' actions in it (Show Bags, Sort, Settings, the
--     menu) in place of the menu button, the footer, the title in GW2's header font on the
--     header, and GW2's close button.
--   Other windows: GW2's tooltip backdrop, titled in its header font.
--   The search box: GW2's search bar, in its font.
local GW = "Interface\\AddOns\\GW2_UI\\Textures\\"

-- GW2_UI's LightHeader text color, and its accent (GW.Colors.Accent, Core/color.lua).
local LIGHT_HEADER = { 1, 0.9450, 0.8196, 1 }
local ACCENT = { 150 / 255, 50 / 255, 50 / 255, 1 }
local NO_SHADOW = { X = 0, Y = 0, Color = { 0, 0, 0, 0 } }
-- Tabs hang 2 pixels into the window; their art starts just below it.
local TAB_INSET = { Left = 0, Right = 0, Top = 2, Bottom = 0 }

---@return table
local function fontSettings()
  local gw = _G.GW2_ADDON
  return type(gw) == "table" and gw.settings and gw.settings.fonts or {}
end

local CLOSE_NORMAL = { Texture = GW .. "uistuff\\window-close-button-normal.png" }
local CLOSE_HOVER = { Texture = GW .. "uistuff\\window-close-button-hover.png" }

-- GwSkinButton(button, true) on Blizzard's close button.
---@param points table
---@return table
local function close(points)
  return {
    Template = "UIPanelCloseButtonNoScripts",
    Points = points,
    Normal = CLOSE_NORMAL,
    Highlight = CLOSE_HOVER,
    Pushed = CLOSE_HOVER,
    Disabled = CLOSE_NORMAL,
  }
end

-- GW.BackdropTemplates.Default.
local BACKDROP = {
  BgFile = GW .. "uistuff\\ui-tooltip-background.png",
  EdgeFile = GW .. "uistuff\\ui-tooltip-border.png",
  Tile = false,
  TileSize = 64,
  EdgeSize = 32,
  Insets = { Left = 2, Right = 2, Top = 2, Bottom = 2 },
  Color = { 1, 1, 1, 1 },
  BorderColor = { 1, 1, 1, 1 },
  Opacity = false,
}

local TITLE = {
  Font = { Path = "$DamageFont", Size = 16, Flags = "", Color = LIGHT_HEADER },
  Points = { { Point = "TOP", X = 0, Y = -5 } },
}

---@param noClose? boolean
---@return table
local function windowStyle(noClose)
  return {
    Backdrop = BACKDROP,
    Title = TITLE,
    CloseButton = not noClose and close({ { Point = "TOPRIGHT", X = -1, Y = -1 } }) or nil,
  }
end

---@param file string
---@param name string The action (frames/bagactions.lua).
---@return table
local function action(file, name)
  local art = { Texture = GW .. file }
  return { Action = name, Normal = art, Highlight = art }
end

local BAG = {
  Background = {
    Texture = GW .. "character\\worldmap-background.png",
    Points = { { Point = "TOPLEFT", X = 0, Y = -25 }, { Point = "BOTTOMRIGHT" } },
    Opacity = false,
  },
  Textures = {
    {
      Name = "HeaderLeft",
      Texture = GW .. "bag\\bagheader.png",
      Layer = "BACKGROUND",
      SubLevel = 2,
      Points = { { Point = "BOTTOMLEFT", RelativePoint = "TOPLEFT", X = 0, Y = -25 } },
      Size = { MaxWidth = 512, WidthOffset = -20, Height = 64 },
    },
    {
      Name = "HeaderRight",
      Texture = GW .. "bag\\bagheader-right.png",
      Layer = "BACKGROUND",
      SubLevel = 2,
      Points = { { Point = "BOTTOMRIGHT", RelativePoint = "TOPRIGHT", X = 0, Y = -25 } },
      Size = { Width = 512, Height = 64 },
    },
    {
      Name = "Icon",
      Texture = GW .. "bag\\bagicon.png",
      Layer = "ARTWORK",
      SubLevel = 1,
      Points = { { Point = "CENTER", RelativePoint = "TOPLEFT", X = -16, Y = 0 } },
      Size = { Width = 84, Height = 84 },
    },
    {
      Name = "Footer",
      Texture = GW .. "bag\\bagfooter.png",
      Layer = "BACKGROUND",
      SubLevel = 7,
      Points = {
        { Point = "TOPLEFT", RelativePoint = "BOTTOMLEFT", X = 0, Y = 30 },
        { Point = "TOPRIGHT", RelativePoint = "BOTTOMRIGHT", X = -3, Y = 30 },
      },
      Size = { Height = 55 },
    },
    {
      Name = "LeftPanel",
      Texture = GW .. "bag\\bagleftpanel.png",
      Layer = "BACKGROUND",
      SubLevel = 7,
      Points = {
        { Point = "TOPRIGHT", RelativePoint = "TOPLEFT", X = 0, Y = 25 },
        { Point = "BOTTOMRIGHT", RelativePoint = "BOTTOMLEFT", X = 0, Y = 25 },
      },
      Size = { Width = 40 },
    },
  },
  Title = {
    Font = { Path = "$DamageFont", Size = "$HeaderSize", Flags = "$FontFlags", Color = LIGHT_HEADER },
    Points = { { Point = "BOTTOMLEFT", RelativeTo = "HeaderLeft", RelativePoint = "BOTTOMLEFT", X = 35, Y = 10 } },
  },
  -- On the header: 25 below its top, which is 39 above the window's.
  CloseButton = close({ { Point = "TOPRIGHT", X = -5, Y = 14 } }),
  Layout = {
    Search = {
      Points = {
        { Point = "TOPLEFT", X = 0, Y = -40 },
        { Point = "BOTTOMRIGHT", RelativePoint = "TOPRIGHT", X = -10, Y = -60 },
      },
    },
    MenuButton = false,
    Actions = {
      Points = { { Point = "TOPLEFT", X = -35, Y = -40 } },
      Size = 32,
      Spacing = 5,
      Buttons = {
        action("icons\\bagmicrobutton-up.png", "ShowBags"),
        action("icons\\microicons\\collectionsmicrobutton-up.png", "Sort"),
        action("icons\\microicons\\questlogmicrobutton-up.png", "Settings"),
        action("icons\\microicons\\mainmenumicrobutton-up.png", "Menu"),
      },
    },
  },
}

sonata:RegisterTheme({
  Name = "GW2",
  DisplayName = "Guild Wars 2",
  Description = "A theme using the GW2_UI style.",
  Available = function()
    return type(_G.GW2_ADDON) == "table"
  end,
  Variables = {
    DamageFont = function() return _G.DAMAGE_TEXT_FONT or "Fonts\\FRIZQT__.TTF" end,
    NameFont = function() return _G.UNIT_NAME_FONT or "Fonts\\FRIZQT__.TTF" end,
    -- GwSetFontTemplate: BigHeader, two larger, in the outline setting ("NONE" is none).
    HeaderSize = function() return ((fontSettings().size or {}).bigHeader or 18) + 2 end,
    NormalSize = function() return (fontSettings().size or {}).normal or 14 end,
    SmallSize = function() return (fontSettings().size or {}).small or 12 end,
    FontFlags = function()
      local outline = fontSettings().outline or ""
      return outline == "NONE" and "" or outline
    end,
  },
  Windows = {
    Bag = BAG,
    Panel = windowStyle(),
    Flat = windowStyle(),
    Dialog = windowStyle(true),
    Slots = { Backdrop = BACKDROP },
    Search = { Backdrop = BACKDROP },
  },
  Elements = {
    SectionHeader = { Font = { Object = "UnitFrame12White" } },
    -- GwSkinTab(tab, "down"): GW2's downward tab art, text without a shadow; GW2's wine-red
    -- accent along the bottom of the selected tab, whose text is LightHeader.
    Tab = {
      Art = "Flat",
      Height = 26,
      Background = { Texture = GW .. "units\\unittab_down.png", Inset = TAB_INSET },
      Hover = { Color = { 1, 1, 1, 0.05 }, Inset = TAB_INSET },
      Selected = {
        Background = { Color = { 1, 1, 1, 0.08 }, Inset = TAB_INSET },
        Bar = {
          Color = ACCENT,
          Height = 2,
          Points = { { Point = "BOTTOMLEFT", X = 1, Y = 1 }, { Point = "BOTTOMRIGHT", X = -1, Y = 1 } },
        },
      },
      Font = { Path = "$NameFont", Size = "$SmallSize", Flags = "$FontFlags", Color = { 0.78, 0.76, 0.7, 1 }, Shadow = NO_SHADOW },
      HighlightFont = { Path = "$NameFont", Size = "$SmallSize", Flags = "$FontFlags", Color = LIGHT_HEADER, Shadow = NO_SHADOW },
      SelectedFont = { Path = "$NameFont", Size = "$SmallSize", Flags = "$FontFlags", Color = LIGHT_HEADER, Shadow = NO_SHADOW },
      TextOffset = { X = 0, Y = -1 },
      SelectedTextOffset = { X = 0, Y = -1 },
    },
    -- SkinBagSearchBox: no caps, GW2's search bar across the box, the magnifier 6 in.
    SearchBox = {
      HideCaps = true,
      Middle = {
        Texture = GW .. "bag\\bagsearchbg.png",
        Points = { { Point = "LEFT" }, { Point = "RIGHT" } },
        Height = 24,
      },
      SearchIcon = { Atlas = "common-search-magnifyingglass", Width = 10, Height = 10, Points = { { Point = "LEFT", X = 6 } } },
      TextInsets = { Left = 20, Right = 20, Top = 0, Bottom = 0 },
      Font = { Path = "$NameFont", Size = "$NormalSize", Flags = "$FontFlags", Color = { 1, 1, 1, 1 } },
    },
  },
})
