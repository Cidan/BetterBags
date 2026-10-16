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
    BagButton = { Portrait = PORTRAIT, Highlight = PORTRAIT },
  },
})
