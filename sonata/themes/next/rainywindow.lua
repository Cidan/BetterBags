local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- Rainy Window: BetterBags Next as a pane of smoked glass with rain on it, lamplight inside (next-themes-glass.md §26).
-- Asked, of a tech demo's rainy pane: "that rainy glass pane was... chefs kiss. clarity might be a problem though
-- (transparent bag)"; then smoked glass, "let's let people adjust the tint strength", and of opening and closing, "let's
-- have fun with that", then, of a fog and a wash first tried, "something more... elegant?".
--   The glass (NextGlass): a smoke the world is multiplied by, as dark as the player's Glass Tint (Appearance > Theme;
--     60 until set), so nothing bright behind a bag washes its items out; a veil that softens the world's detail; a
--     grain of condensation; bands of reflected light, uneven and once a screen (asked, of a first art: "repeating a bit
--     too much"), that hold still on the screen as a bag moves; the pointer a warm lamp, glinting along the glass's edges
--     and lighting the drops from its side; drops behind the items, beading up as a bag opens, a few running down in fits
--     and leaving beads that dry; lightning now and then.
--   Opening and closing (NextSheen): the pane catches the light, a soft band sweeping across it as it fades in (from its
--     inner side out) and out (back again).
--   Readable over anything: a dark bed under every icon, light text with shadows, the settings window on solid smoke.
-- The palette redefines Default's names (Gold, Lavender, Text, Muted...) in its lamplight and rain, so everything this
-- theme leaves to Default follows. Its art is tools/textures/next_rain.py's. Data only.
local TEXTURES = "Interface\\AddOns\\BetterBags\\textures\\next\\rain\\"

sonataNext:RegisterTheme({
  Name = "RainyWindow",
  DisplayName = "Rainy Window",
  Description = "A pane of smoked glass with rain running down it and lamplight inside, catching the light as it opens "
    .. "and closes.",

  Palette = {
    Body = { 0.07, 0.085, 0.105, 0.92 },
    -- The sky reflected at the top of the glass.
    Wash = { 0.55, 0.68, 0.85, 0.1 },
    -- The smoke the world behind is multiplied by, at full strength; the veil scattering light; the rain's light.
    Smoke = { 0.14, 0.17, 0.22, 1 },
    Mist = { 0.78, 0.84, 0.92, 1 },
    Rain = { 0.72, 0.84, 1, 1 },
    -- Lamplight where Default is gold; rain-blue where it is lavender.
    Gold = { 1, 0.8, 0.52, 1 },
    Lavender = { 0.62, 0.74, 0.88, 1 },
    Silver = { 0.9, 0.93, 0.97, 1 },
    Text = { 0.94, 0.96, 0.99, 1 },
    Muted = { 0.68, 0.74, 0.82, 1 },
    Warbank = { 0.55, 0.85, 1, 1 },
    WarbankWash = { 0.55, 0.85, 1, 0.1 },
    Guild = { 0.55, 1, 0.75, 1 },
    GuildWash = { 0.55, 1, 0.75, 0.1 },
    Tab = { 0.07, 0.085, 0.11, 0.9 },
    TabSelected = { 0.13, 0.16, 0.21, 0.95 },
    Card = { 0.08, 0.1, 0.13, 0.97 },
    Scrim = { 0, 0.01, 0.03, 0.6 },
    SearchFill = { 0.09, 0.11, 0.14, 0.92 },
    SearchFillFocus = { 0.12, 0.15, 0.19, 0.96 },
    Shadow = { 0, 0, 0, 0.95 },
    ButtonIcon = { 0.84, 0.9, 0.97, 1 },
    Bead = { 0.85, 0.92, 1, 1 },
    -- Derived from the search fill, as Default's are from its own (0.89, 1.15, 0.71 of it; the track 1.5).
    ControlFill = { 0.08, 0.098, 0.125, 1 },
    ControlHover = { 0.104, 0.127, 0.161, 1 },
    ControlPressed = { 0.064, 0.078, 0.099, 1 },
    Track = { 0.135, 0.165, 0.21, 1 },
    Danger = { 1, 0.5, 0.5, 1 },
    Crimson = { 0.95, 0.32, 0.38, 1 },
    Emerald = { 0.45, 0.95, 0.75, 1 },
    Sidebar = { 0, 0.01, 0.03, 0.3 },
    -- The settings window: solid smoke, no glass, for a window of text.
    SettingsGlass = { 0.075, 0.09, 0.115, 0.96 },
  },

  Textures = {
    Drop = TEXTURES .. "drop.png",
    Fog = TEXTURES .. "fog.png",
    Reflection = TEXTURES .. "reflection.png",
    Sheen = TEXTURES .. "sheen.png",
  },

  -- Every role over the glass has a shadow, so it reads over a bright world.
  FontShadow = { Color = "Shadow", X = 1, Y = -1 },
  Fonts = {
    Title = { Size = 24, Color = "Silver", Shadow = true },
    SectionFree = { Size = 13, Color = "Muted", Shadow = true },
    Count = { Size = 11, Color = "Muted", Shadow = true },
    Tab = { Size = 12, Color = "Muted", Shadow = true },
    Footer = { Size = 12, Color = "Muted", Shadow = true },
    Empty = { Size = 12, Color = "Muted", Shadow = true },
    Search = { Size = 12, Color = "Muted", Shadow = true },
  },

  Motion = {
    -- Sections settle in like drops, a touch past and back.
    Time = { Cascade = 0.36, Stagger = 0.04 },
    Ease = { Cascade = "outBackSoft" },
  },

  Panel = {
    -- Nothing over the world but the glass (NextGlass draws it over the fill's place).
    Fill = { Color = { 0, 0, 0, 0 } },
    Feather = false,
    Wash = { Height = 260, BlendMode = "ADD" },
    Edge = { Color = "Rain", Alpha = 0.4, Size = 1 },
    DropGlow = { Color = "Rain", Alpha = 0.12, BlendMode = "ADD" },
    -- The glass (NextGlass). Appearance > Theme > Glass Tint sets its Strength; Appearance > Animation > Rain on Glass
    -- and Lightning take those out.
    Glass = {
      Tint = { Color = "Smoke", Strength = 0.6, Veil = { Color = "Mist", Alpha = 0.16 } },
      Grain = { Texture = "Fog", Color = "Mist", Alpha = 0.05, BlendMode = "ADD", Size = 256 },
      Reflections = { Texture = "Reflection", Color = "Mist", Alpha = 0.3, BlendMode = "ADD", Angle = 64, Period = 1600,
        Parallax = 0.85 },
      Lamp = { Texture = "Glow", Color = "Gold", Alpha = 0.09, BlendMode = "ADD", Size = 260, Reach = 170 },
      Rim = { Color = "Mist", Alpha = { 0.06, 0.6 }, Size = 1, Piece = 24 },
      Rain = { Texture = "Drop", Color = "White", Alpha = 0.85, Density = 0.7, Size = { 3, 10 }, Appear = { 0.15, 0.9 },
        Highlight = { Texture = "Glow", Color = "White", Alpha = 0.85 },
        Caustic = { Texture = "Glow", Color = "Rain", Alpha = 0.35 },
        Runners = { Count = 3, Size = { 7, 11 }, Speed = { 30, 80 }, Wait = { 1.5, 5 }, Slide = { 0.25, 1.1 },
          Catch = { 0.15, 0.9 }, Every = 7, Beads = 48, BeadSize = { 1.6, 3.2 }, BeadLife = { 8, 14 } } },
      Lightning = { Every = { 35, 90 }, Time = 0.5, Color = "Mist", Alpha = 0.22 },
    },
    -- Catching the light as it opens and closes (NextSheen): a soft band sweeping across the pane from its inner side
    -- out, a little downhill, as it fades in, and back as it fades out. Appearance > Animation > Glass Sheen turns it
    -- off. Shown in 0.32 seconds: a bank waits for its panel to have shown before it loads, 1 second at most.
    Sheen = {
      Band = { Texture = "Sheen", Color = "Mist", Alpha = 0.5, BlendMode = "ADD", Width = 340, Angle = 24 },
      Glow = { Color = "Mist", Alpha = 0.05, BlendMode = "ADD" },
      Open = { Time = 0.55, Reveal = 0.32 },
      Close = { Time = 0.45, Fade = 0.28 },
    },
  },

  Header = {
    TitleGlow = { Texture = "Glow", Color = "Rain", Alpha = 0.12, X = 24, Y = 14, BlendMode = "ADD" },
    Ribbon = false,
    Spark = false,
    Cloud = false,
    Buttons = { HoverColor = "Gold" },
  },

  Search = {
    Edge = { Color = "Rain", Size = 1, Idle = 0.3, Hover = 0.55, Focus = 0.9 },
    Icon = { Color = "Rain", Idle = 0.8, Active = 1, FocusColor = "White" },
  },

  Sections = {
    Line = { Color = "Rain", From = 0.35, To = 0, Size = 1 },
    Highlight = { Color = "Rain", From = 0.1, To = 0 },
  },

  Tabs = {
    Edge = { Color = "Rain", Alpha = 0.3, Size = 1 },
    SelectedEdge = { Color = "Gold", Alpha = 0.7, Size = 1 },
    Glow = { Color = "Gold", BlendMode = "ADD", Drop = 0.25, Pulse = 0.7 },
  },

  Footer = {
    Line = { Color = "Rain", Inner = 0.1, Outer = 0.45, Size = 1 },
  },

  -- The glass is the motion: no sparkles.
  Sparkles = false,

  Chain = {
    Color = "Rain",
    BeadColor = "Bead",
    KnotColor = "Gold",
  },

  Drag = {
    Shadow = { Color = "Black", Alpha = 0.3, Spread = 10 },
  },

  Vendor = {
    Highlight = { 0.72, 0.84, 1, 0.14 },
    CardFill = { 0.03, 0.04, 0.05, 0.55 },
    CardHover = { 0.72, 0.84, 1, 0.1 },
  },

  -- Item buttons on a dark bed, so an icon reads over any world behind the glass: the icon cropped in a dark cell, a
  -- thin rain-light edge, an item's quality on its icon's border.
  ItemButton = {
    Icon = { Inset = 1, TexCoords = { 0.08, 0.92, 0.08, 0.92 } },
    Backdrop = { Color = { 0.02, 0.025, 0.035, 0.62 }, BorderColor = { 0.72, 0.84, 1, 0.28 }, EdgeSize = 1 },
    Highlight = { Color = { 0.72, 0.84, 1, 0.16 } },
    Pushed = { Color = { 0.72, 0.84, 1, 0.26 } },
  },

  Settings = {
    Fill = { Color = "SettingsGlass" },
    Edge = { Color = "Rain", Alpha = 0.35, Size = 1 },
  },
})
