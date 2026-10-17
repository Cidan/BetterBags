local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

-- The Moonlight set, from BetterBags' sister addon Moonlight: every window drawn in one
-- nine-sliced frame of art (textures/moonlight), titled in white at the top left, with a
-- lettered close button. The hidden Moonlight theme holds the geometry; Dark, Dark Round and
-- Parchment choose the art ($Frame, $SliceMode), and Parchment hangs a ribbon over the bag.
-- Slate is Moonlight's own default: Blizzard's marble, tiled, with no frame art.
local ART = "Interface\\AddOns\\BetterBags\\textures\\moonlight\\"

local BACKGROUND = {
  Texture = "$Frame",
  SliceMode = "$SliceMode",
  SliceMargins = { Left = 24, Right = 24, Top = 24, Bottom = 24 },
}

local INSETS = { Left = 18, Right = 24, Top = 40, Bottom = 12 }

-- The title sits right of the menu button, in the theme's text color.
local TITLE = {
  Font = { Object = "GameFontHighlight", Color = "$TextColor", Shadow = "$TextShadow" },
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

-- Tabs hang 2 pixels into the window; inset is how far into the tab its art starts (2 puts
-- its top edge just below the window, 1 lays a 1-pixel edge on the window's own). Each theme
-- gives the rest; the text sits centered in the art.
---@param inset number
---@param style table
---@return table
local function tab(inset, style)
  local i = { Left = 0, Right = 0, Top = inset, Bottom = 0 }
  local t = {
    Art = "Flat",
    Height = 26,
    Hover = { Color = { 1, 1, 1, 0.06 }, Inset = i },
    TextOffset = { X = 0, Y = -1 },
    SelectedTextOffset = { X = 0, Y = -1 },
  }
  for k, v in pairs(style) do
    t[k] = v
  end
  local parts = { t.Background, t.Border, t.Hover, t.Selected and t.Selected.Background }
  for n = 1, 4 do
    if parts[n] then
      parts[n].Inset = i
    end
  end
  return t
end

-- The close button's letter in black on the paper.
local PARCHMENT_CLOSE = { Font = { Object = "GameFontBlack" } }

local GRAY_TEXT = { Object = "GameFontHighlightSmall", Color = { 0.7, 0.7, 0.7, 1 } }
local NO_SHADOW = { X = 0, Y = 0, Color = { 0, 0, 0, 0 } }
-- The plain middle of parchment.png, away from its burnt edges.
local PAPER = { 0.25, 0.75, 0.3, 0.5 }
local WHITE_TEXT = { Object = "GameFontHighlightSmall" }

-- A bar along the bottom of the selected tab.
---@param color number[]
---@return table
local function bottomBar(color)
  return {
    Color = color,
    Height = 2,
    Points = { { Point = "BOTTOMLEFT", X = 1, Y = 1 }, { Point = "BOTTOMRIGHT", X = -1, Y = 1 } },
  }
end

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
  Name = "Dark",
  DisplayName = "Dark",
  Description = "A dark frame, from Moonlight.",
  Parent = "Moonlight",
  Elements = {
    -- The frame's translucent black inside its heavy black edge; the selected tab lighter.
    Tab = tab(2, {
      Background = { Color = { 0, 0, 0, 0.55 } },
      Border = { Color = { 0.01, 0.01, 0.01, 1 }, EdgeSize = 3 },
      Selected = { Background = { Color = { 1, 1, 1, 0.1 } } },
      Font = GRAY_TEXT,
      HighlightFont = WHITE_TEXT,
      SelectedFont = WHITE_TEXT,
    }),
  },
})

sonata:RegisterTheme({
  Name = "DarkRound",
  DisplayName = "Dark Round",
  Description = "A dark frame with round corners, from Moonlight.",
  Parent = "Moonlight",
  Variables = { Frame = ART .. "dark-round.png" },
  Elements = {
    -- The frame's dark fill inside its #3c3b3c rim; the selected tab's rim brighter.
    Tab = tab(2, {
      Background = { Color = { 0, 0, 0, 0.75 } },
      Border = { Color = { 0.235, 0.231, 0.235, 1 }, EdgeSize = 2 },
      Selected = {
        Background = { Color = { 1, 1, 1, 0.06 } },
        Border = { Color = { 0.55, 0.55, 0.55, 1 } },
      },
      Font = GRAY_TEXT,
      HighlightFont = WHITE_TEXT,
      SelectedFont = WHITE_TEXT,
    }),
  },
})

sonata:RegisterTheme({
  Name = "Parchment",
  DisplayName = "Parchment",
  Description = "A parchment frame under a ribbon, from Moonlight.",
  Parent = "Moonlight",
  Variables = {
    Frame = ART .. "parchment.png",
    SliceMode = "Stretched",
    -- Dark text on the paper, in Blizzard's parchment text colors (GlobalColor): body text
    -- PARCHMENT_MATERIAL_TEXT_COLOR, titles PARCHMENT_MATERIAL_TITLETEXT_COLOR, the hovered
    -- entry PARCHMENTLARGE_MATERIAL_TITLETEXT_COLOR, good and bad states
    -- PARCHMENT_ACCESSIBILITY_GREEN and _RED. Secondary and muted text take the browns of the
    -- tabs' text and of the paper's burnt edge. No shadow; a faint gold glow marks the open
    -- settings entry.
    TextColor = { 46 / 255, 31 / 255, 15 / 255, 1 },
    TextSoftColor = { 0.36, 0.22, 0.1, 1 },
    TextMutedColor = { 0.455, 0.286, 0.176, 1 },
    TextAccentColor = { 0, 0, 0, 1 },
    TextAccentHoverColor = { 53 / 255, 0, 0, 1 },
    TextPositiveColor = { 19 / 255, 68 / 255, 4 / 255, 1 },
    TextNegativeColor = { 172 / 255, 3 / 255, 3 / 255, 1 },
    TextShadow = { Color = { 0, 0, 0, 0 }, X = 0, Y = 0 },
    TextGlow = { Color = { 1, 0.82, 0, 0.35 }, X = 0, Y = 0 },
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
      CloseButton = PARCHMENT_CLOSE,
    },
    Panel = { CloseButton = PARCHMENT_CLOSE },
    Flat = { CloseButton = PARCHMENT_CLOSE },
  },
  Elements = {
    SectionHeader = { Font = { Object = "GameFontNormal", Color = "$TextAccentColor", Shadow = "$TextShadow" } },
    -- A strip of the paper, dimmed until the tab is selected, in the burnt edge's brown, with
    -- dark brown text and no shadow.
    Tab = tab(2, {
      Background = { Texture = ART .. "parchment.png", TexCoords = PAPER, VertexColor = { 0.8, 0.76, 0.7, 1 } },
      Border = { Color = { 0.455, 0.286, 0.176, 1 }, EdgeSize = 2 },
      Selected = { Background = { Texture = ART .. "parchment.png", TexCoords = PAPER } },
      Hover = { Color = { 1, 1, 1, 0.12 } },
      Font = { Object = "GameFontNormalSmall", Color = { 0.36, 0.22, 0.1, 1 }, Shadow = NO_SHADOW },
      HighlightFont = { Object = "GameFontNormalSmall", Color = { 0.18, 0.09, 0.03, 1 }, Shadow = NO_SHADOW },
      SelectedFont = { Object = "GameFontNormalSmall", Color = { 0.18, 0.09, 0.03, 1 }, Shadow = NO_SHADOW },
    }),
  },
})

-- Blizzard tiles the marble across a frame (CommunitiesMemberList.xml); it has no edge to slice.
local MARBLE_FILE = "Interface\\FrameGeneral\\UI-Background-Marble"
local MARBLE = { SliceMargins = false, HorizTile = true, VertTile = true }

sonata:RegisterTheme({
  Name = "Slate",
  DisplayName = "Slate",
  Description = "Dark marble, Moonlight's own look.",
  Parent = "Moonlight",
  Variables = { Frame = MARBLE_FILE },
  Windows = {
    Bag = { Background = MARBLE },
    Panel = { Background = MARBLE },
    Flat = { Background = MARBLE },
    Dialog = { Background = MARBLE },
    Slots = { Background = MARBLE },
    Search = { Background = MARBLE },
  },
  Elements = {
    -- The marble in a thin dark edge; a cool gray bar under the selected tab.
    Tab = tab(1, {
      Background = { Texture = MARBLE_FILE, HorizTile = true, VertTile = true },
      Border = { Color = { 0.18, 0.18, 0.18, 1 }, EdgeSize = 1 },
      Selected = {
        Background = { Color = { 1, 1, 1, 0.04 } },
        Bar = bottomBar({ 0.54, 0.56, 0.6, 1 }),
      },
      Font = GRAY_TEXT,
      HighlightFont = WHITE_TEXT,
      SelectedFont = WHITE_TEXT,
    }),
  },
})
