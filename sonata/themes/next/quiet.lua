local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- Quiet: BetterBags Next calm and compact. Cool grays; smaller icons, nine to a row; a shorter header,
-- its button icons smaller with its smaller title; no ribbon, cloud, spark, sparkles or braid; panels
-- that open and come in without a bounce, a little quicker; a fainter border round a small panel.
-- Data only (next-themes.md).
sonataNext:RegisterTheme({
  Name = "Quiet",
  DisplayName = "Quiet",
  Description = "Calm and compact: smaller icons, no sparkles or shimmer, quicker motion without a bounce.",

  Palette = {
    Body = { 0.07, 0.075, 0.09, 0.95 },
    Wash = { 0.6, 0.7, 0.9, 0.08 },
    Gold = { 0.85, 0.87, 0.92, 1 },
    Lavender = { 0.7, 0.75, 0.85, 1 },
    Text = { 0.94, 0.95, 0.97, 1 },
    Muted = { 0.6, 0.62, 0.68, 1 },
    Tab = { 0.1, 0.11, 0.13, 0.92 },
    TabSelected = { 0.18, 0.2, 0.24, 0.96 },
    Card = { 0.1, 0.11, 0.14, 0.98 },
    SearchFill = { 0.12, 0.13, 0.16, 1 },
    SearchFillFocus = { 0.16, 0.17, 0.21, 1 },
    ButtonIcon = { 0.8, 0.82, 0.88, 1 },
  },

  Fonts = {
    Title = { Size = 20 },
    Section = { Size = 13 },
    SectionRecent = { Size = 13 },
  },

  Layout = {
    Icon = 38,
    Gap = 4,
    PerRow = 9,
    Feather = 48,
    TitleTop = 18,
    HeaderButtonTop = 18,
    SearchTop = 56,
    ContentTop = 92,
    SectionHeader = 22,
    SectionSpacing = 12,
  },

  Motion = {
    Time = { Open = 0.3, Enter = 0.35, Cascade = 0.2, Stagger = 0.02, Hover = 0.1 },
    Ease = { Open = "outCubic", Enter = "outCubic" },
    Rise = 6,
  },

  Panel = {
    Edge = { Color = "Lavender", Alpha = 0.18 },
  },

  Header = {
    Ribbon = false,
    Cloud = false,
    Spark = false,
    TitleGlow = false,
    -- Its title is 20 against Default's 26: its icons keep Default's share of the title's size.
    Buttons = { Scale = 0.8 },
  },

  Sparkles = false,

  Chain = { Braid = false },

  Dock = { Halo = false },
})
