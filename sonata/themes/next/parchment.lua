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
    -- The settings window's controls (next-settings.md §6): fields a lighter paper than the page, a
    -- darker one when pressed and for a slider's or switch's empty track; Blizzard's parchment red
    -- (PARCHMENT_ACCESSIBILITY_RED, as the bags' Parchment theme uses) for what deletes.
    ControlFill = { 0.86, 0.82, 0.74, 1 },
    ControlHover = { 0.9, 0.86, 0.78, 1 },
    ControlPressed = { 0.78, 0.72, 0.63, 1 },
    Track = { 0.7, 0.63, 0.53, 1 },
    Danger = { 172 / 255, 3 / 255, 3 / 255, 1 },
    -- A tracked currency's gain and its count at a cap (currency.md): Blizzard's parchment green
    -- (PARCHMENT_ACCESSIBILITY_GREEN, as the bags' Parchment theme's good text) and the sealing wax.
    Gain = { 19 / 255, 68 / 255, 4 / 255, 1 },
    Capped = { 0.55, 0.12, 0.06, 1 },
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
    CurrencyNone = { Color = "InkMuted" },
    CurrencyName = { Color = "Ink" },
    CurrencyLoss = { Color = "InkMuted" },
    CurrencyMore = { Color = "InkSoft" },
    Stack = { Shadow = { Color = "Black", X = 1, Y = -1 } },
    DragHint = { Shadow = { Color = "Black", X = 1, Y = -1 } },
    -- The settings window and its controls, in ink; sealing wax for what leads (a primary button, a
    -- heading in the sidebar, a link under the pointer).
    ControlText = { Color = "Ink" },
    ControlMuted = { Color = "InkMuted" },
    ControlHelp = { Color = "InkMuted" },
    Button = { Color = "Ink" },
    ButtonPrimary = { Color = "Seal" },
    ButtonDanger = { Color = "Danger" },
    Link = { Color = "InkSoft" },
    LinkHover = { Color = "Seal" },
    MenuItem = { Color = "Ink" },
    MenuItemSelected = { Color = "Seal" },
    DialogTitle = { Color = "Ink" },
    DialogText = { Color = "InkSoft" },
    TopTab = { Color = "InkMuted" },
    TopTabHover = { Color = "InkSoft" },
    TopTabSelected = { Color = "Ink" },
    SettingsBrand = { Color = "Ink" },
    SettingsNavGroup = { Color = "Seal" },
    SettingsNav = { Color = "InkSoft" },
    SettingsNavHover = { Color = "Ink" },
    SettingsNavSelected = { Color = "Ink" },
    SettingsVersion = { Color = "InkMuted" },
    SettingsTitle = { Color = "Ink" },
    SettingsDescription = { Color = "InkSoft" },
    SettingsSection = { Color = "InkMuted" },
    SettingsSectionNote = { Color = "InkMuted" },
    SettingsLabel = { Color = "Ink" },
    SettingsText = { Color = "InkSoft" },
    SettingsLink = { Color = "Seal" },
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

  -- Tracked currencies in ink on the paper, their caps in sealing wax; no light: no glow round a gain, the strip lit
  -- in wax while a tracker would be put away; the tracker a slip of the paper (currency.md).
  Currency = {
    Bar = { Track = { Color = "Ink", Alpha = 0.15 }, Fill = { Color = "Ink", Alpha = 0.75 }, Capped = { Color = "Seal" } },
    Hover = { Color = "Ink", Alpha = 0.06 },
    Flash = false,
    Drop = { BlendMode = "BLEND", Color = "Seal", Alpha = 0.22 },
    Slot = { Color = "Seal" },
    Tracker = {
      Fill = { Texture = "Paper", TexCoords = { 0.25, 0.75, 0.3, 0.5 }, Color = "White" },
      Edge = { Color = "Ink", Alpha = 0.35 },
    },
  },

  -- The settings window on the paper art, its lines and lights in ink, its marks in sealing wax.
  Settings = {
    Fill = { Texture = "Paper", TexCoords = { 0.25, 0.75, 0.3, 0.5 }, Color = "White" },
    Wash = false,
    Edge = { Color = "Ink", Alpha = 0.5 },
    Sidebar = { Fill = { Color = "Ink", Alpha = 0.06 }, Line = { Color = "Ink", Alpha = 0.25 } },
    Brand = { IconColor = "Seal", Line = { Color = "Seal" } },
    Search = { IconColor = "Ink" },
    Back = { IconColor = "Ink" },
    Nav = {
      Indicator = { Color = "Seal" },
      SelectedFill = { Color = "Ink", Alpha = 0.08 },
      HoverFill = { Color = "Ink", Alpha = 0.04 },
    },
    Header = { Close = { Color = "Ink", HoverColor = "Seal" } },
    Content = {
      Card = { Color = "Ink", Alpha = 0.04 },
      Divider = { Color = "Ink", Alpha = 0.15 },
      Hover = { Color = "Ink", Alpha = 0.05 },
    },
    Footer = { Line = { Color = "Ink", Alpha = 0.25 } },
    Cards = {
      Fill = { Color = "Ink", Alpha = 0.04 }, HoverFill = { Color = "Ink", Alpha = 0.08 },
      Edge = { Color = "Ink", Alpha = 0.25 }, SelectedEdge = { Color = "Seal", Alpha = 0.9 },
    },
    Categories = {
      Indicator = { Color = "Seal" },
      SelectedFill = { Color = "Ink", Alpha = 0.08 },
      HoverFill = { Color = "Ink", Alpha = 0.04 },
    },
    BagCategories = {
      Fill = { Color = "Ink", Alpha = 0.035 },
      HoverFill = { Color = "Ink", Alpha = 0.04 },
    },
  },

  -- Its controls: paper fields edged in ink, sealing wax where Default is gold; a menu and a dialog are
  -- slips of the same paper.
  Controls = {
    ScrollBar = {
      Track = { Color = "Ink", Alpha = 0.06 }, Thumb = { Color = "Ink", Alpha = 0.3 },
      ThumbHover = { Color = "Ink", Alpha = 0.55 }, ThumbDrag = { Color = "Seal", Alpha = 0.85 },
    },
    Toggle = {
      On = { Color = "Seal", Alpha = 0.9 }, Edge = { Color = "Ink", Alpha = 0.35 },
      Knob = { Color = "PaperLight" }, KnobOn = { Color = "PaperLight" }, Hover = { Color = "Ink", Alpha = 0.06 },
    },
    Button = {
      Plain = { Edge = { Color = "Ink", Alpha = 0.35 }, HoverEdge = { Color = "Ink", Alpha = 0.6 } },
      Primary = {
        Fill = { Color = "Seal", Alpha = 0.12 }, HoverFill = { Color = "Seal", Alpha = 0.2 },
        PressedFill = { Color = "Seal", Alpha = 0.06 },
        Edge = { Color = "Seal", Alpha = 0.6 }, HoverEdge = { Color = "Seal", Alpha = 1 },
      },
    },
    Input = { Edge = { Color = "Ink" } },
    Slider = { Fill = { Color = "Seal" }, Thumb = { Color = "Ink" }, ThumbHover = { Color = "Seal" } },
    Dropdown = { Edge = { Color = "Ink" }, Chevron = { Color = "Ink" } },
    Menu = {
      Fill = { Texture = "Paper", TexCoords = { 0.25, 0.75, 0.3, 0.5 }, Color = "White" },
      Edge = { Color = "Ink", Alpha = 0.5 },
      HoverFill = { Color = "Ink", Alpha = 0.08 },
      Check = { Color = "Seal" },
    },
    Swatch = { Edge = { Color = "Ink", Alpha = 0.5 }, HoverEdge = { Color = "Ink", Alpha = 0.9 } },
    TopTabs = { Indicator = { Color = "Seal" }, Line = { Color = "Ink", Alpha = 0.2 } },
    Dialog = {
      Card = { Texture = "Paper", TexCoords = { 0.25, 0.75, 0.3, 0.5 }, Color = "White" },
      Edge = { Color = "Seal", Alpha = 0.6 },
    },
  },

  Vendor = {
    Highlight = { 0, 0, 0, 0.12 },
    -- Cards inked faintly on the paper.
    CardFill = { 46 / 255, 31 / 255, 15 / 255, 0.06 },
    CardHover = { 46 / 255, 31 / 255, 15 / 255, 0.08 },
  },
})
