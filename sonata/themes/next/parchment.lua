local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- Parchment: BetterBags Next on paper, inked. The body and the confirmation card are the plain middle
-- of Moonlight's parchment art (textures/moonlight/parchment.png, away from its burnt edges); the text
-- is dark, in Blizzard's parchment text colors (PARCHMENT_MATERIAL_TEXT_COLOR and its title color, as
-- the bags' Parchment theme uses), with no shadow; lines, bars and glows are ink and sealing wax, drawn
-- normally rather than added as light; and there are no sparkles, shimmer or cloud. The paper's color,
-- for the feather and the tabs, is the art's average (measured: 0.83, 0.78, 0.70). Data only
-- (next-themes.md).
sonataNext:RegisterTheme({
  Name = "Parchment",
  DisplayName = "Parchment",
  Description = "Paper and ink: Moonlight's parchment art, dark text, and no sparkles.",

  Textures = {
    Paper = "Interface\\AddOns\\BetterBags\\textures\\moonlight\\parchment.png",
  },

  Palette = {
    Paper = { 0.83, 0.78, 0.70, 0.97 },
    PaperDark = { 0.74, 0.67, 0.57, 0.95 },
    PaperLight = { 0.9, 0.86, 0.78, 1 },
    Ink = { 46 / 255, 31 / 255, 15 / 255, 1 },
    InkSoft = { 0.36, 0.22, 0.1, 1 },
    InkMuted = { 0.455, 0.286, 0.176, 1 },
    -- Sealing wax: the accent.
    Seal = { 0.55, 0.12, 0.06, 1 },
    -- Full-color icons keep their colors on the paper, a touch dimmed until hovered.
    Art = { 0.9, 0.88, 0.85, 1 },
    Body = { 0.83, 0.78, 0.70, 0.97 },
    Tab = { 0.74, 0.67, 0.57, 0.95 },
    TabSelected = { 0.9, 0.86, 0.78, 1 },
    SearchFill = { 0.74, 0.67, 0.57, 1 },
    SearchFillFocus = { 0.9, 0.86, 0.78, 1 },
    Scrim = { 0, 0, 0, 0.35 },
  },

  -- No shadow on the paper; the numbers drawn over item icons keep one of their own.
  FontShadow = { Color = { 0, 0, 0, 0 }, X = 0, Y = 0 },
  Fonts = {
    Title = { Color = "Ink" },
    Section = { Color = "Ink" },
    SectionRecent = { Color = "Seal" },
    SectionFree = { Color = "InkMuted" },
    Count = { Color = "InkMuted" },
    Tab = { Color = "InkSoft" },
    TabSelected = { Color = "Ink" },
    Footer = { Color = "InkSoft" },
    Empty = { Color = "InkMuted" },
    ConfirmTitle = { Color = "Ink" },
    ConfirmWarning = { Color = "Seal" },
    ConfirmHint = { Color = "InkSoft" },
    Search = { Color = "InkMuted" },
    SearchText = { Color = "Ink" },
    Price = { Color = "Ink" },
    PriceUnaffordable = { Color = "Seal" },
    VendorName = { Color = "Ink", Shadow = false },
    Stack = { Shadow = { Color = "Black", X = 1, Y = -1 } },
    DragHint = { Shadow = { Color = "Black", X = 1, Y = -1 } },
  },

  Panel = {
    Fill = { Texture = "Paper", TexCoords = { 0.25, 0.75, 0.3, 0.5 }, Color = "White" },
    Feather = { Color = "Paper" },
    Wash = false,
    Edge = { Color = "Ink", Alpha = 0.5 },
    DropGlow = { Color = "Seal", Alpha = 0.12, BlendMode = "BLEND" },
  },

  Header = {
    TitleGlow = { Color = "Seal", Alpha = 0.12, BlendMode = "BLEND" },
    Ribbon = { Color = "Seal", BlendMode = "BLEND", Glow = { { 0, 0.8 }, { 1, 0.3 }, { -1, 0.3 } } },
    Spark = false,
    Cloud = false,
    -- The glyphs (settings, close) in ink; the colored icons in their own colors (inked, they turned
    -- into black shapes: asked, with a screenshot).
    Buttons = { Color = "Ink", HoverColor = "Seal", ArtColor = "Art", ArtHoverColor = "White" },
  },

  Search = {
    Edge = { Color = "Ink", Idle = 0.35, Hover = 0.6, Focus = 0.9 },
    Icon = { Color = "Ink", FocusColor = "Seal" },
  },

  Sections = {
    Line = { Color = "Ink", From = 0.35 },
    Highlight = { Color = "Seal", From = 0.1 },
  },

  Tabs = {
    Fade = 0.6,
    Glow = { Color = "Seal", BlendMode = "BLEND", Drop = 0.15, Pulse = 0.35 },
    Indicator = { Color = "Seal" },
  },

  Footer = {
    Line = { Color = "Ink", Inner = 0.05, Outer = 0.35 },
  },

  Sparkles = false,

  Chain = { Color = "Seal", BeadColor = "Seal", KnotColor = "Seal" },

  Drag = { Shadow = { Color = "Black", Alpha = 0.25 } },

  Dock = {
    Card = { Texture = "Paper", TexCoords = { 0.25, 0.75, 0.3, 0.5 }, Color = "White" },
    Glow = { Color = "Seal" },
    Halo = false,
  },

  Vendor = {
    Highlight = { 0, 0, 0, 0.12 },
    -- Cards inked faintly on the paper.
    CardFill = { 46 / 255, 31 / 255, 15 / 255, 0.06 },
    CardHover = { 46 / 255, 31 / 255, 15 / 255, 0.08 },
  },
})
