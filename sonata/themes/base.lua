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

-- The overlay search panel slides 10 pixels right as it fades out.
local FADE_AND_SLIDE = {
  Show = FADE.Show,
  Hide = {
    { Type = "Alpha", From = 1, To = 0, Duration = 0.10, Smoothing = "IN" },
    { Type = "Translation", X = 10, Y = 0, Duration = 0.10, Smoothing = "IN" },
  },
}

-- Text roles (Sonata:GetTextFont): the fonts of BetterBags' own text, by what the text is.
-- Their colors come from the Text* variables, so a theme recolors all of its text by setting
-- those; it can also restyle a single role under Text. Each role here is the client font and
-- color its text was drawn with before roles existed.
---@param object string
---@param color string
---@param shadow? string
---@return SonataFont
local function role(object, color, shadow)
  return { Object = object, Color = color, Shadow = shadow }
end

local TEXT = {
  -- Settings: section headings, option titles and their descriptions.
  Heading = role("GameFontNormalLarge", "$TextColor", "$TextShadow"),
  Label = role("GameFontNormalLarge", "$TextSoftColor", "$TextShadow"),
  Description = role("GameFontHighlight", "$TextSoftColor", "$TextShadow"),
  -- The name at the top of a settings detail pane, and field labels in panes and editors.
  Title = role("GameFontNormalLarge", "$TextAccentColor", "$TextShadow"),
  Field = role("GameFontNormal", "$TextAccentColor", "$TextShadow"),
  -- Body text and values, dialog text.
  Body = role("GameFontHighlight", "$TextColor", "$TextShadow"),
  BodySmall = role("GameFontHighlightSmall", "$TextColor", "$TextShadow"),
  BodyLarge = role("GameFontNormalLarge", "$TextColor", "$TextShadow"),
  -- Small headers and captions (column headers, timeline captions).
  FieldSmall = role("GameFontNormalSmall", "$TextAccentColor", "$TextShadow"),
  MutedSmall = role("GameFontNormalSmall", "$TextMutedColor", "$TextShadow"),
  -- The text typed into the search panel.
  Search = role("GameFontNormalHuge", "$TextColor", "$TextShadow"),
  -- Notes and hints, and the message of an empty list or pane.
  Muted = role("GameFontNormal", "$TextMutedColor", "$TextShadow"),
  Empty = role("GameFontNormalLarge", "$TextMutedColor", "$TextShadow"),
  -- A good or bad state (a theme in use, an error).
  Positive = role("GameFontHighlight", "$TextPositiveColor", "$TextShadow"),
  Negative = role("GameFontHighlight", "$TextNegativeColor", "$TextShadow"),
  -- The settings navigation: sections and their entries, normal, under the cursor, and open.
  Nav = role("GameFontNormalLarge", "$TextColor", "$TextShadow"),
  NavHover = role("GameFontNormalLarge", "$TextAccentHoverColor", "$TextGlow"),
  NavActive = role("GameFontNormalLarge", "$TextAccentColor", "$TextGlow"),
  NavSub = role("GameFontNormal", "$TextColor", "$TextShadow"),
  NavSubHover = role("GameFontNormal", "$TextAccentHoverColor", "$TextGlow"),
  NavSubActive = role("GameFontNormal", "$TextAccentColor", "$TextGlow"),
  -- The bag footer: currency counts and money (number fonts, no shadow).
  Count = role("Number12Font", "$TextColor"),
  Money = role("Number12Font", "$TextColor"),
}

-- Window kinds: Bag (the backpack and bank), Panel (forms, the group dialog), Flat (the debug
-- window), Dialog (questions, the search category editor), Slots (the Show Bags and bank tab
-- panels), Search (the overlay search panel).

sonata:RegisterTheme({
  Name = "Base",
  Hidden = true,
  Variables = {
    TextColor = { 1, 1, 1, 1 },
    TextSoftColor = { 0.75, 0.75, 0.75, 1 },
    TextMutedColor = { 0.6, 0.6, 0.6, 1 },
    TextAccentColor = { 1, 0.82, 0, 1 },
    TextAccentHoverColor = { 1, 0.9, 0.5, 1 },
    TextPositiveColor = { 0.2, 0.8, 0.2, 1 },
    -- RED_FONT_COLOR (GlobalColor).
    TextNegativeColor = { 1, 0.125, 0.125, 1 },
    TextShadow = { Color = { 0, 0, 0, 1 }, X = 1, Y = -1 },
    -- A shadow with no offset glows around the text.
    TextGlow = { Color = { 1, 0.8, 0.3, 0.8 }, X = 0, Y = 0 },
  },
  Text = TEXT,
  -- Outside retail the money was drawn in NumberFontNormalRight (frames/money.lua).
  Clients = { Classic = { Text = { Money = { Object = "NumberFontNormalRight" } } } },
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
    -- A slots panel hangs below its bag: Offset is where its top left sits from the bag's
    -- bottom left.
    Slots = {
      Insets = { Left = 8, Right = 8, Top = 8, Bottom = 8 },
      Animations = FADE_AND_DROP,
      Layout = { Offset = { X = 0, Y = -2 } },
    },
    Search = { Insets = { Left = 10, Right = 10, Top = 0, Bottom = 0 }, Animations = FADE_AND_SLIDE },
  },
  Elements = {
    SectionHeader = { Font = { Object = "GameFontNormal" } },
  },
})
