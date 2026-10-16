local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

-- Simple Dark: every window a black backdrop with a one-pixel gray edge that fades, border and
-- all, with the opacity; white UnitFrame12White titles; BetterBags' small close button.
local CLOSE_ART = "Interface\\AddOns\\BetterBags\\textures\\close.png"

local BACKDROP = {
  BgFile = "Interface\\ChatFrame\\ChatFrameBackground",
  EdgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
  EdgeSize = 1,
  Color = { 0, 0, 0, 1 },
  BorderColor = { 0.5, 0.5, 0.5, 1 },
  BorderOpacity = true,
}

local TITLE = { Font = { Object = "UnitFrame12White" }, Points = { { Point = "TOP", X = 0, Y = 0 } }, Height = 30 }

local CLOSE = {
  Size = 12,
  Points = { { Point = "TOPRIGHT", X = -8, Y = -8 } },
  Normal = { Texture = CLOSE_ART },
  Highlight = { Texture = CLOSE_ART },
}

-- A window with a title and, unless noClose, a close button.
---@param noClose? boolean
---@return table
local function titled(noClose)
  return { Backdrop = BACKDROP, Title = TITLE, CloseButton = not noClose and CLOSE or nil }
end

-- Tabs hang 2 pixels into the window: inset 1 from the top, a tab's top edge lies on the
-- window's bottom edge. Black like the window, in its gray edge; the selected tab lighter.
local TAB_INSET = { Left = 0, Right = 0, Top = 1, Bottom = 0 }
local TAB = {
  Art = "Flat",
  Height = 26,
  Background = { Color = { 0, 0, 0, 1 }, Inset = TAB_INSET },
  Border = { Color = { 0.5, 0.5, 0.5, 1 }, EdgeSize = 1, Inset = TAB_INSET },
  Hover = { Color = { 1, 1, 1, 0.06 }, Inset = TAB_INSET },
  Selected = { Background = { Color = { 0.12, 0.12, 0.12, 1 }, Inset = TAB_INSET } },
  Font = { Object = "GameFontHighlightSmall", Color = { 0.7, 0.7, 0.7, 1 } },
  HighlightFont = { Object = "GameFontHighlightSmall" },
  SelectedFont = { Object = "GameFontHighlightSmall" },
  TextOffset = { X = 0, Y = -1 },
  SelectedTextOffset = { X = 0, Y = -1 },
}

-- The menu button's portrait and highlight at 85%.
local PORTRAIT = { Width = 40.8, Height = 51 }

local bag = titled()
bag.Layout = {
  Search = {
    Points = {
      { Point = "TOPLEFT", X = 20, Y = -40 },
      { Point = "BOTTOMRIGHT", RelativePoint = "TOPRIGHT", X = -10, Y = -60 },
    },
  },
  MenuButton = { Points = { { Point = "TOPLEFT", X = 4, Y = -6 } } },
}

sonata:RegisterTheme({
  Name = "SimpleDark",
  DisplayName = "Simple Dark",
  Description = "A simple dark theme.",
  Windows = {
    Bag = bag,
    Panel = titled(),
    Flat = titled(),
    Dialog = titled(true),
    Slots = { Backdrop = BACKDROP },
    Search = { Backdrop = BACKDROP },
  },
  Elements = {
    SectionHeader = { Font = { Object = "UnitFrame12White" } },
    Tab = TAB,
    BagButton = { Portrait = PORTRAIT, Highlight = PORTRAIT },
  },
})
