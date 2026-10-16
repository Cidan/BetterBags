local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

-- The Moonlight set, from BetterBags' sister addon Moonlight: every window drawn in one
-- nine-sliced frame of art (textures/moonlight), titled in white at the top left, with a
-- lettered close button. The hidden Moonlight theme holds the geometry; Dark, Dark Round and
-- Parchment choose the art ($Frame, $SliceMode), and Parchment hangs a ribbon over the bag.
local ART = "Interface\\AddOns\\BetterBags\\textures\\moonlight\\"

local BACKGROUND = {
  Texture = "$Frame",
  SliceMode = "$SliceMode",
  SliceMargins = { Left = 24, Right = 24, Top = 24, Bottom = 24 },
}

local INSETS = { Left = 18, Right = 24, Top = 40, Bottom = 12 }

-- The title sits right of the menu button.
local TITLE = {
  Font = { Object = "GameFontHighlight" },
  Points = { { Point = "TOPLEFT", X = 44, Y = -15 } },
  Height = 24,
  Justify = "LEFT",
}

local CLOSE = { Size = 32, Text = "X" }

---@param noClose? boolean
---@return table
local function framed(noClose)
  return { Background = BACKGROUND, Insets = INSETS, Title = TITLE, CloseButton = not noClose and CLOSE or nil }
end

local bag = framed()
bag.Layout = {
  Search = {
    Points = {
      { Point = "TOPLEFT", X = 18, Y = -40 },
      { Point = "BOTTOMRIGHT", RelativePoint = "TOPRIGHT", X = -24, Y = -60 },
    },
    Reserve = 24,
  },
  Footer = { Left = 18, Right = 24, Bottom = 12, Height = 20, Reserve = 26 },
  MenuButton = { Points = { { Point = "TOPLEFT", X = 8, Y = -6 } } },
}

local dialog = framed(true)
dialog.Title = { Font = TITLE.Font, Points = { { Point = "TOPLEFT", X = 20, Y = -15 } }, Height = 24, Justify = "LEFT" }

sonata:RegisterTheme({
  Name = "Moonlight",
  Hidden = true,
  Variables = {
    Frame = ART .. "dark-frame.png",
    SliceMode = "Tiled",
  },
  Windows = {
    Bag = bag,
    Panel = framed(),
    Flat = framed(),
    Dialog = dialog,
    Slots = { Background = BACKGROUND, Insets = { Left = 14, Right = 14, Top = 14, Bottom = 14 } },
    Search = { Background = BACKGROUND, Insets = { Left = 18, Right = 24, Top = 12, Bottom = 12 } },
  },
  Elements = {
    -- A smaller menu button that fits inside the frame.
    BagButton = { Size = 32, Portrait = { Width = 32, Height = 40 }, Highlight = { Width = 32, Height = 40 } },
  },
})

sonata:RegisterTheme({
  Name = "MoonlightDark",
  DisplayName = "Moonlight Dark",
  Description = "A dark frame, from Moonlight.",
  Parent = "Moonlight",
})

sonata:RegisterTheme({
  Name = "MoonlightDarkRound",
  DisplayName = "Moonlight Dark Round",
  Description = "A dark frame with round corners, from Moonlight.",
  Parent = "Moonlight",
  Variables = { Frame = ART .. "dark-round.png" },
})

sonata:RegisterTheme({
  Name = "MoonlightParchment",
  DisplayName = "Moonlight Parchment",
  Description = "A parchment frame under a ribbon, from Moonlight.",
  Parent = "Moonlight",
  Variables = {
    Frame = ART .. "parchment.png",
    SliceMode = "Stretched",
  },
  Windows = {
    Bag = {
      Textures = {
        {
          Name = "Ribbon",
          Texture = ART .. "parchment-ribbon.png",
          Layer = "ARTWORK",
          Points = { { Point = "BOTTOM", RelativePoint = "TOP", Y = -40 } },
          Size = { Width = 281, Height = 84 },
        },
      },
      Title = { Points = { { Point = "BOTTOM", RelativeTo = "Ribbon", RelativePoint = "BOTTOM", Y = 25 } }, Justify = "CENTER" },
    },
  },
})
