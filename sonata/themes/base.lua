local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

-- Base holds what every theme inherits: the window geometry BetterBags' own parts are laid out
-- with (the content box, and where the bag's search box, menu button and footer go), the
-- default fade, and Blizzard's fonts for the elements. A theme sets only what it changes.
local FADE = {
  Show = { { Type = "Alpha", From = 0, To = 1, Duration = 0.10, Smoothing = "IN" } },
  Hide = { { Type = "Alpha", From = 1, To = 0, Duration = 0.10, Smoothing = "IN" } },
}

sonata:RegisterTheme({
  Name = "Base",
  Hidden = true,
  Windows = {
    Bag = {
      Insets = { Left = 6, Right = 6, Top = 42, Bottom = 3 },
      Animations = FADE,
      Layout = {
        -- The in-bag search box, and the room it takes above the content when shown.
        Search = {
          Points = {
            { Point = "TOPLEFT", X = 20, Y = -30 },
            { Point = "BOTTOMRIGHT", RelativePoint = "TOPRIGHT", X = -10, Y = -50 },
          },
          Reserve = 20,
        },
        -- The bar along the bottom with the money and currencies, and the room it takes.
        Footer = { Left = 6, Right = 6, Bottom = 6, Height = 20, Reserve = 26 },
        MenuButton = { Points = { { Point = "TOPLEFT", X = -10, Y = 7 } } },
        -- How far left of the window the side panels (theme config) sit.
        SideOffset = 0,
      },
    },
  },
  Elements = {
    SectionHeader = { Font = { Object = "GameFontNormal" } },
  },
})
