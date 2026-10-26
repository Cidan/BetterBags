local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- Glitch: BetterBags Next as a terminal that will not hold still (next-themes.md §21). Asked: "the bag sort of glitches
-- into existence when opening, glitches out when closing. think flickers, glitched blinking textures that wobble suddenly
-- and harshly, think green mesh ... push the limits of what's possible here".
--   Opening: a CRT warming up, a beam across the body opening to its height, then the panel flickering into view while
--     bands of the frame tear across it, datamosh blocks and static flash over it, its sections are shoved sideways and
--     the title's colours split and its letters corrupt (NextGlitch). Closing: the same backwards, ending in the CRT
--     turning off to a line and a point. Now and then while it shows, a short burst of the same.
--   At rest: phosphor green on near black, a faint grid behind the content, a wireframe floor along the bottom, a CRT's
--     vignette and scanlines, a rolling bar, HUD brackets at the corners that twitch now and then, the title's cyan and
--     magenta ghosts, data raining down the feather and faintly behind the items (NextRain), tabs as HUD boxes, dashed
--     section lines, square pixel sparks (Sparkles.Upright).
--   Text in two terminal fonts shipped with BetterBags (fonts/glitch, SIL Open Font License): VT323 for titles and
--     display text, Share Tech Mono for the rest. Both cover Latin alphabets only, so in other locales each role draws
--     the client's own font (Locales).
-- The palette redefines Default's names (Gold, Lavender, Text, Muted...) in phosphor greens, so everything this theme
-- leaves to Default follows. Its art is tools/textures/next_glitch.py's. Data only.
local FONTS = "Interface\\AddOns\\BetterBags\\fonts\\glitch\\"
local TEXTURES = "Interface\\AddOns\\BetterBags\\textures\\next\\glitch\\"
-- The locales whose alphabets both fonts cover (Latin: basic, Latin-1).
local LATIN = { "enUS", "enGB", "deDE", "frFR", "esES", "esMX", "itIT", "ptBR" }

-- vt is a role in VT323, mono one in Share Tech Mono: size, color, shadow (true: FontShadow; a table: its own).
local function vt(size, color, shadow)
  return { File = FONTS .. "VT323-Regular.ttf", Locales = LATIN, Size = size, Color = color, Shadow = shadow }
end
local function mono(size, color, shadow)
  return { File = FONTS .. "ShareTechMono-Regular.ttf", Locales = LATIN, Size = size, Color = color, Shadow = shadow }
end

-- What the rain writes and a glitch corrupts the title with: ASCII, which every client's fonts have.
local RAIN = "0123456789ABCDEF<>/\\|=+*#$%&@?!"
local CORRUPT = "#@%&$*!?/\\<>=+_01"

-- A HUD bracket at each corner of the body, 5 in from it: one L (the art's top left), flipped for the others, twitching now
-- and then. A corner piece's X is toward the body's middle and its Y down whatever its corner (next-themes.md §12), so a
-- bottom corner's goes in with a Y up.
local function bracket(point, coords)
  local y = point:find("^BOTTOM") and -5 or 5
  return { Texture = "Bracket", Point = point, Width = 22, Height = 22, X = 5, Y = y, TexCoords = coords, Color = "Gold",
    Alpha = 0.9, Above = true, Layer = "OVERLAY",
    Motion = { Glitch = { Every = 7, Hold = 0.14, Jump = 4, Blink = 0.15 } } }
end

sonataNext:RegisterTheme({
  Name = "Glitch",
  DisplayName = "Glitch",
  Description = "A terminal that will not hold still: phosphor green, glitching into view and out, data raining down "
    .. "its edge.",

  Palette = {
    Body = { 0.008, 0.03, 0.016, 0.95 },
    Wash = { 0.25, 1, 0.5, 0.08 },
    -- Bright phosphor where Default is gold; dim phosphor where it is lavender.
    Gold = { 0.42, 1, 0.58, 1 },
    Lavender = { 0.22, 0.72, 0.4, 1 },
    Phosphor = { 0.3, 1, 0.5, 1 },
    -- The colour split's two sides.
    Cyan = { 0.1, 0.95, 1, 1 },
    Magenta = { 1, 0.15, 0.7, 1 },
    Text = { 0.78, 1, 0.84, 1 },
    Muted = { 0.36, 0.64, 0.45, 1 },
    -- Text on a lit (phosphor) fill: the selected tab, a primary button.
    Ink = { 0, 0.07, 0.03, 1 },
    Warbank = { 0.1, 0.9, 1, 1 },
    WarbankWash = { 0.1, 0.9, 1, 0.08 },
    Guild = { 0.8, 1, 0.25, 1 },
    GuildWash = { 0.8, 1, 0.25, 0.08 },
    Tab = { 0.01, 0.06, 0.03, 0.92 },
    TabSelected = { 0.3, 1, 0.5, 0.95 },
    Card = { 0.01, 0.05, 0.025, 0.98 },
    Scrim = { 0, 0.02, 0.01, 0.7 },
    SearchFill = { 0.01, 0.045, 0.022, 1 },
    SearchFillFocus = { 0.02, 0.08, 0.04, 1 },
    Shadow = { 0, 0, 0, 0.9 },
    ButtonIcon = { 0.42, 1, 0.58, 1 },
    Bead = { 0.75, 1, 0.82, 1 },
    ControlFill = { 0.015, 0.06, 0.03, 1 },
    ControlHover = { 0.03, 0.1, 0.05, 1 },
    ControlPressed = { 0.01, 0.04, 0.02, 1 },
    Track = { 0.06, 0.18, 0.1, 1 },
    Danger = { 1, 0.25, 0.45, 1 },
    Crimson = { 1, 0.12, 0.45, 1 },
    Emerald = { 0.1, 0.95, 1, 1 },
    Sidebar = { 0, 0, 0, 0.4 },
    Gain = { 0.55, 1, 0.65, 1 },
    Capped = { 1, 0.78, 0.2, 1 },
  },

  Textures = {
    Grid = TEXTURES .. "grid.png",
    Mesh = TEXTURES .. "mesh.png",
    Scanlines = TEXTURES .. "scanlines.png",
    Bar = TEXTURES .. "bar.png",
    Vignette = TEXTURES .. "vignette.png",
    Noise = TEXTURES .. "noise.png",
    Blocks = TEXTURES .. "blocks.png",
    Tear = TEXTURES .. "tear.png",
    Bracket = TEXTURES .. "bracket.png",
    Dash = TEXTURES .. "dash.png",
    -- A square of light: the pixel sparks.
    Pixel = "Interface\\Buttons\\WHITE8X8",
  },

  FontShadow = { Color = "Shadow", X = 1, Y = -1 },
  Fonts = {
    Title = vt(32, "Gold", true),
    -- The title's colour ghosts (Header.Title.Ghosts).
    TitleCyan = vt(32, "Cyan"),
    TitleMagenta = vt(32, "Magenta"),
    Section = vt(20, "Text", true),
    SectionRecent = vt(20, "Gold", true),
    SectionFree = vt(19, "Muted"),
    Count = mono(11, "Muted"),
    Tab = mono(12, "Text"),
    TabSelected = mono(12, "Ink"),
    Footer = mono(12, "Muted"),
    Empty = vt(22, "Muted"),
    DragHint = mono(12, "Gold", true),
    ConfirmTitle = vt(24, "Gold", true),
    ConfirmWarning = mono(12, "Gold"),
    ConfirmHint = mono(12, "Lavender"),
    Search = mono(12, "Muted"),
    SearchText = mono(13, "Text"),
    Price = mono(13, "White", true),
    PriceUnaffordable = mono(13, "Unaffordable", true),
    VendorName = mono(12, "Text", true),
    ControlText = mono(12, "Text"),
    ControlMuted = mono(12, "Muted"),
    ControlHelp = mono(12, "Muted"),
    Button = mono(12, "Text"),
    ButtonPrimary = mono(12, "Ink"),
    ButtonDanger = mono(12, "Danger"),
    Link = mono(12, "Lavender"),
    LinkHover = mono(12, "Gold"),
    MenuItem = mono(12, "Text"),
    MenuItemSelected = mono(12, "Gold"),
    DialogTitle = vt(24, "Gold", true),
    DialogText = mono(12, "Text"),
    TopTab = mono(13, "Muted"),
    TopTabHover = mono(13, "Text"),
    TopTabSelected = mono(13, "Gold"),
    SettingsBrand = vt(28, "Gold", true),
    SettingsNavGroup = mono(11, "Lavender"),
    SettingsNav = mono(13, "Muted"),
    SettingsNavHover = mono(13, "Text"),
    SettingsNavSelected = mono(13, "Gold"),
    SettingsVersion = mono(10, "Muted"),
    SettingsTitle = vt(34, "Gold", true),
    SettingsDescription = mono(13, "Muted"),
    SettingsSection = mono(11, "Lavender"),
    SettingsSectionNote = mono(11, "Muted"),
    SettingsLabel = mono(13, "Text"),
    SettingsText = mono(12, "Muted"),
    SettingsLink = mono(12, "Gold"),
    CurrencyCount = mono(12, "Text", true),
    CurrencyCapped = mono(12, "Capped", true),
    CurrencyNone = mono(12, "Muted"),
    CurrencyName = mono(12, "Text"),
    CurrencyGain = vt(18, "Gain", true),
    CurrencyLoss = mono(12, "Muted", true),
    CurrencyMore = mono(11, "Lavender"),
    -- The data rain: its trail, and the bright head writing it.
    RainGlyph = vt(16, "Phosphor"),
    RainHead = vt(16, "White"),
  },

  Layout = {
    SectionHeader = 26,
    SectionSpacing = 18,
    TabHeight = 28,
  },

  Motion = {
    -- Sections flicker into place rather than ease, without rising.
    Time = { Cascade = 0.3, Stagger = 0.04, Hover = 0.08, Toggle = 0.1, TabMarker = 0.12 },
    Ease = { Cascade = "flicker" },
    Rise = 0,
  },

  Panel = {
    -- A HUD's frame round full panels too.
    Edge = { Color = "Lavender", Alpha = 0.55, Size = 1, Full = true },
    DropGlow = { Color = "Gold", Alpha = 0.12, BlendMode = "ADD" },
    -- Each piece drawn for the backpack (its inner side on the left) and mirrored on the panels across the screen.
    Ornaments = {
      -- A phosphor grid behind everything, over the body's fill.
      { Texture = "Grid", Point = "BODY", Tile = 64, Color = "Phosphor", Alpha = 0.06, BlendMode = "ADD",
        Layer = "BACKGROUND", SubLevel = 2 },
      -- The wireframe floor along the bottom, breathing.
      { Texture = "Mesh", Point = "BOTTOM", Height = 150, Color = "Phosphor", BlendMode = "ADD",
        Layer = "BACKGROUND", SubLevel = 3, Motion = { Pulse = { 0.12, 0.24 }, Period = 3.2 } },
      -- The CRT's glass darkening toward its edges, under the content.
      { Texture = "Vignette", Point = "BODY", Color = "Black", Alpha = 0.6 },
      -- Scanlines and a rolling bar over everything, the items included (Above).
      { Texture = "Scanlines", Point = "BODY", Tile = 6, Color = "Black", Alpha = 0.22, Above = true, Layer = "OVERLAY",
        SubLevel = -2 },
      { Texture = "Bar", Point = "BODY", Tile = 420, Color = "Phosphor", Alpha = 0.05, BlendMode = "ADD", Above = true,
        Layer = "OVERLAY", SubLevel = -1, Motion = { Scroll = { Y = -70 } } },
      bracket("TOPINNER", { 0, 1, 0, 1 }),
      bracket("TOPOUTER", { 1, 0, 0, 1 }),
      bracket("BOTTOMINNER", { 0, 1, 1, 0 }),
      bracket("BOTTOMOUTER", { 1, 0, 1, 0 }),
    },
    -- Glitching in, out, and now and then (NextGlitch). Flicker can be hard on some players' eyes: Appearance >
    -- Animation > Glitch Effects turns it off.
    Glitch = {
      Open = { Time = 0.5, PowerOn = 0.18 },
      Close = { Time = 0.28, PowerOff = 0.22 },
      Bursts = { Every = 14, Time = 0.3 },
      Step = 0.06,
      Jitter = 14,
      Flicker = { 0.3, 1 },
      Sections = 26,
      Ghosts = 8,
      Tears = { Count = 5, Texture = "Tear", Height = { 3, 14 }, Alpha = 0.9, BlendMode = "ADD" },
      Blocks = { Count = 4, Texture = "Blocks", Size = { 24, 96 }, Colors = { "Magenta", "Phosphor", "Cyan" },
        Alpha = 0.5, BlendMode = "ADD" },
      Noise = { Texture = "Noise", Color = "Phosphor", Alpha = 0.32, BlendMode = "ADD" },
      Corrupt = { Glyphs = CORRUPT, Chance = 0.45 },
      Beam = { Color = "White", Alpha = 1, Height = 2, BlendMode = "ADD" },
    },
    -- Data raining down the feather, and faintly behind the items (NextRain).
    Rain = {
      { Where = "Feather", Font = "RainGlyph", HeadFont = "RainHead", Glyphs = RAIN, Spacing = 18, Speed = { 6, 16 },
        Trail = { 8, 20 }, Alpha = 0.7, Swap = 3 },
      { Where = "Body", Font = "RainGlyph", HeadFont = "RainHead", Glyphs = RAIN, Spacing = 38, Speed = { 3, 9 },
        Trail = { 6, 14 }, Alpha = 0.1, Swap = 1 },
    },
  },

  Header = {
    -- The title's colour split, at rest a pixel or two either side; a glitch spreads it.
    Title = { Font = "Title", Ghosts = {
      { Font = "TitleCyan", X = -2, Alpha = 0.45 },
      { Font = "TitleMagenta", X = 2, Alpha = 0.45 },
    } },
    TitleGlow = { Texture = "Glow", Color = "Gold", Alpha = 0.18, X = 24, Y = 14, BlendMode = "ADD" },
    -- A thin trace out of the window.
    Ribbon = { Length = 300, Thickness = 1, Color = "Gold", BlendMode = "ADD",
      Glow = { { 0, 0.9 }, { 2, 0.2 }, { -2, 0.2 } } },
    Spark = false,
    Cloud = false,
  },

  Search = {
    Edge = { Color = "Gold", Size = 1, Idle = 0.35, Hover = 0.6, Focus = 1 },
    Icon = { Color = "Gold", Idle = 0.8, Active = 1, FocusColor = "White" },
  },

  Sections = {
    Title = { X = 2, Y = -2 },
    Line = { Texture = "Dash", HorizTile = true, Color = "Lavender", Alpha = 0.6, Size = 2 },
    Highlight = { Color = "Gold", From = 0.12, To = 0 },
  },

  Tabs = {
    -- HUD boxes: a solid fill, an edge round each, the selected one lit with dark text.
    Fade = 1,
    Edge = { Color = "Lavender", Alpha = 0.75, Size = 1 },
    SelectedEdge = { Color = "Gold", Alpha = 1, Size = 1 },
    Glow = { Color = "Gold", BlendMode = "ADD", Drop = 0.3, Pulse = 0.8 },
    Indicator = false,
  },

  Footer = {
    Line = { Color = "Lavender", Inner = 0.15, Outer = 0.55, Size = 1 },
  },

  -- Square pixel sparks drifting out, flickering rather than twinkling.
  Sparkles = {
    Texture = "Pixel",
    BlendMode = "ADD",
    Upright = true,
    Colors = { "Phosphor", "Gold", "Cyan" },
    FadeIn = 0.05,
    FadeOut = 0.3,
    TwinkleSpeed = 23,
    TwinkleDepth = 0.6,
    Shrink = 0,
    WobbleSpeed = 9,
    Cloud = false,
    Ribbon = { Rate = 5, Max = 18, Life = { 0.8, 1.8 }, Size = { 2, 4 }, Speed = { 30, 80 }, Rise = { -2, 2 },
      Wobble = 1, Spin = 0, Alpha = 0.9, Spread = 70 },
    Edge = { Rate = 2, Max = 10, Life = { 1.2, 2.6 }, Size = { 2, 3 }, Speed = { 10, 30 }, Rise = { -2, 2 },
      Wobble = 1, Spin = 0, Alpha = 0.6, Reach = 24 },
    Knot = { Rate = 0, Max = 16, Life = { 0.3, 0.8 }, Size = { 2, 4 }, Speed = { 20, 60 }, Rise = { -20, 20 },
      Wobble = 1, Spin = 0, Alpha = 0.9, Burst = 14 },
  },

  Chain = {
    Thickness = 1, Amplitude = 5, Turn = 2.2,
  },

  Drag = {
    -- A lifted section glows.
    Shadow = { Color = "Phosphor", Alpha = 0.18, Spread = 10 },
  },

  Dock = {
    -- A card's title line as tall as its font (ConfirmTitle).
    TitleHeight = 26,
    Glow = { Color = "Gold", Width = 1, Low = 0.3, High = 1, Period = 0.7 },
    Halo = { Texture = "Glow", Color = "Gold", Spread = 24, Low = 0.08, High = 0.3, Period = 0.7, BlendMode = "ADD" },
  },

  Vendor = {
    Highlight = { 0.3, 1, 0.5, 0.15 },
    CardFill = { 0.3, 1, 0.5, 0.04 },
    CardHover = { 0.3, 1, 0.5, 0.1 },
  },

  Currency = {
    Tracker = { Edge = { Color = "Lavender", Alpha = 0.6, Size = 1 } },
  },

  -- Item buttons as terminal cells: the icon cropped in a dark cell, a thin phosphor edge, an item's quality on it.
  ItemButton = {
    Icon = { Inset = 1, TexCoords = { 0.08, 0.92, 0.08, 0.92 } },
    Backdrop = { Color = { 0, 0.04, 0.02, 0.9 }, BorderColor = { 0.22, 0.72, 0.4, 0.55 }, EdgeSize = 1 },
    QualityBorder = "Backdrop",
    Highlight = { Color = { 0.3, 1, 0.5, 0.2 } },
    Pushed = { Color = { 0.3, 1, 0.5, 0.3 } },
  },

  Settings = {
    Edge = { Color = "Lavender", Alpha = 0.55, Size = 1 },
  },

  Controls = {
    Toggle = {
      On = { Color = "Gold", Alpha = 0.9 },
      Edge = { Color = "Lavender", Alpha = 0.5, Size = 1 },
    },
    Button = {
      Primary = {
        Fill = { Color = "Gold", Alpha = 0.85 }, HoverFill = { Color = "White", Alpha = 0.9 },
        PressedFill = { Color = "Gold", Alpha = 0.6 },
        Edge = { Color = "Gold", Alpha = 1, Size = 1 }, HoverEdge = { Color = "White", Alpha = 1, Size = 1 },
      },
    },
    Dialog = {
      Edge = { Color = "Gold", Alpha = 0.7, Size = 1 },
    },
  },
})
