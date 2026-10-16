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

-- The slots panels drop 10 pixels as they fade out.
local FADE_AND_DROP = {
  Show = FADE.Show,
  Hide = {
    { Type = "Alpha", From = 1, To = 0, Duration = 0.10, Smoothing = "IN" },
    { Type = "Translation", X = 0, Y = -10, Duration = 0.10, Smoothing = "IN" },
  },
}

-- Window kinds: Bag (the backpack and bank), Panel (forms, theme config, the group dialog),
-- Flat (the debug window), Dialog (questions, the search category editor), Slots (the Show
-- Bags and bank tab panels).

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
      },
    },
    Panel = { Insets = { Left = 4, Right = 0, Top = 30, Bottom = 4 }, Animations = FADE },
    Flat = { Insets = { Left = 5, Right = 5, Top = 25, Bottom = 5 }, Animations = FADE },
    Dialog = { Insets = { Left = 5, Right = 5, Top = 25, Bottom = 5 }, Animations = FADE },
    Slots = { Insets = { Left = 8, Right = 8, Top = 8, Bottom = 8 }, Animations = FADE_AND_DROP },
  },
  Elements = {
    SectionHeader = { Font = { Object = "GameFontNormal" } },
  },
})
