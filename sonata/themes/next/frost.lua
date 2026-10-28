local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- Frost: BetterBags Next in deep winter blue, threaded with gold (next-themes.md §22). Asked: "a cool blue and cold
-- theme, icy in nature ... the shades of blue and gold should be like the screenshot ... themes are ice, cool breeze,
-- etc. ... go crazy on the show and hide animations, and the overall feel".
--   Opening: the bag appears out of a frost storm growing from its bottom inner corner across it, flakes curling and mist
--     rolling in it, shards of its own body forming behind the storm's front; once it has crossed, the seams between the
--     shards flash, the frost on them thaws away and the bag shows under them as the storm blows away; a gust of wind
--     blows snow in, and its gold threads draw themselves in (NextShatter, NextSnow, NextThreads).
--     Closing: frost spreads over it, cracks run along its seams out from where it was clicked, and it shatters, the
--     shards tumbling away as they fall, catching the light as they turn.
--   At rest: the body's teal-blue depths, an aurora drifting across the top, a frosted rim, an interlace border down
--     its inner side and along its top and bottom, ice crystals growing out of its inner corners; snow drifting across
--     the body and down the feather on a breeze that gusts now and then, its streaks of wind sweeping across; now and
--     then a gold shooting star flying a short way across the body; threads of gold light swaying round the header,
--     the footer and the feather, a glint running along them; snowflakes for sparkles, a frosty mist round the title.
--   Display text in Cinzel (fonts/frost, SIL Open Font License; its Latin alphabets only, so other locales draw the
--     client's font), the rest in the client's own.
-- The palette redefines Default's names (Gold, Lavender, Text, Muted...) in its gold and ice blues, so everything this
-- theme leaves to Default follows. Its art is tools/textures/next_frost.py's. Data only.
local FONTS = "Interface\\AddOns\\BetterBags\\fonts\\frost\\"
local TEXTURES = "Interface\\AddOns\\BetterBags\\textures\\next\\frost\\"
-- The locales whose alphabets Cinzel covers (Latin: basic, Latin-1).
local LATIN = { "enUS", "enGB", "deDE", "frFR", "esES", "esMX", "itIT", "ptBR" }

-- A role in Cinzel: its size, colour and shadow (true: FontShadow), bold or not.
local function cinzel(size, color, shadow, bold)
  return { File = FONTS .. (bold and "Cinzel-Bold.ttf" or "Cinzel-Regular.ttf"), Locales = LATIN, Size = size,
    Color = color, Shadow = shadow }
end

sonataNext:RegisterTheme({
  Name = "Frost",
  DisplayName = "Frost",
  Description = "Deep winter blue threaded with gold: it freezes together from shards of ice, shatters when it closes, "
    .. "and snow drifts across it on a cold breeze.",

  Palette = {
    Body = { 0.035, 0.14, 0.225, 0.96 },
    Wash = { 0.5, 0.85, 1, 0.12 },
    -- Gold where Default is gold; ice blue where it is lavender.
    Gold = { 0.95, 0.8, 0.47, 1 },
    Lavender = { 0.55, 0.82, 0.95, 1 },
    Ice = { 0.5, 0.85, 1, 1 },
    Frost = { 0.85, 0.96, 1, 1 },
    -- The title's cold steel.
    Silver = { 0.84, 0.9, 0.94, 1 },
    Text = { 0.88, 0.96, 1, 1 },
    Muted = { 0.52, 0.71, 0.81, 1 },
    Warbank = { 0.55, 0.9, 1, 1 },
    WarbankWash = { 0.55, 0.9, 1, 0.12 },
    Guild = { 0.55, 1, 0.82, 1 },
    GuildWash = { 0.55, 1, 0.82, 0.12 },
    Tab = { 0.04, 0.16, 0.26, 0.92 },
    TabSelected = { 0.1, 0.32, 0.46, 0.96 },
    Card = { 0.05, 0.17, 0.27, 0.98 },
    Scrim = { 0, 0.03, 0.06, 0.6 },
    SearchFill = { 0.06, 0.2, 0.31, 1 },
    SearchFillFocus = { 0.08, 0.26, 0.39, 1 },
    Shadow = { 0, 0.02, 0.05, 0.9 },
    ButtonIcon = { 0.78, 0.92, 1, 1 },
    Bead = { 1, 0.95, 0.82, 1 },
    -- Derived from the search fill, as Default's are from its own (0.89, 1.15, 0.71 of it; the track 1.5).
    ControlFill = { 0.053, 0.178, 0.276, 1 },
    ControlHover = { 0.069, 0.23, 0.357, 1 },
    ControlPressed = { 0.043, 0.142, 0.22, 1 },
    Track = { 0.09, 0.3, 0.465, 1 },
    Danger = { 1, 0.5, 0.55, 1 },
    Crimson = { 0.95, 0.3, 0.42, 1 },
    Emerald = { 0.4, 0.95, 0.85, 1 },
    Sidebar = { 0, 0.03, 0.06, 0.3 },
  },

  Textures = {
    IceBody = TEXTURES .. "body.png",
    Frost = TEXTURES .. "frost.png",
    Crystal = TEXTURES .. "crystal.png",
    KnotEdge = TEXTURES .. "knot_edge.png",
    KnotSide = TEXTURES .. "knot_side.png",
    Aurora = TEXTURES .. "aurora.png",
    Rim = TEXTURES .. "rim.png",
    Flake = TEXTURES .. "flake.png",
    Streak = TEXTURES .. "streak.png",
    Thread = TEXTURES .. "thread.png",
  },

  FontShadow = { Color = "Shadow", X = 1, Y = -1 },
  Fonts = {
    Title = cinzel(26, "Silver", true, true),
    Section = cinzel(15, "Text", true),
    SectionRecent = cinzel(15, "Gold", true),
    SectionFree = cinzel(14, "Muted", true),
    Tab = cinzel(12, "Text", true),
    TabSelected = cinzel(12, "Gold", true, true),
    Empty = cinzel(20, "Muted", true),
    ConfirmTitle = cinzel(20, "Gold", true, true),
    DialogTitle = cinzel(20, "Gold", true, true),
    TopTab = cinzel(13, "Muted"),
    TopTabHover = cinzel(13, "Text"),
    TopTabSelected = cinzel(13, "Gold", false, true),
    SettingsBrand = cinzel(24, "Silver", true, true),
    SettingsNavGroup = cinzel(11, "Ice"),
    SettingsTitle = cinzel(28, "Silver", true, true),
    SettingsSection = cinzel(12, "Ice"),
  },

  Motion = {
    -- Sections settle into place like snow, a touch past and back.
    Time = { Cascade = 0.4, Stagger = 0.05, Hover = 0.2, ShimmerEvery = 5 },
    Ease = { Cascade = "outBackSoft" },
    Rise = 10,
  },

  Panel = {
    Fill = { Texture = "IceBody", Color = "White" },
    Edge = { Color = "Ice", Alpha = 0.45, Size = 1 },
    Wash = { Height = 220, BlendMode = "ADD" },
    DropGlow = { Color = "Ice", Alpha = 0.15, BlendMode = "ADD" },
    -- Each piece drawn for the backpack (its inner side on the left) and mirrored on the panels across the screen.
    Ornaments = {
      -- Frost along every edge.
      { Texture = "Rim", Point = "BODY", Color = "Frost", Alpha = 0.18, BlendMode = "ADD", Layer = "BACKGROUND",
        SubLevel = 4 },
      -- An aurora drifting across the top.
      { Texture = "Aurora", Point = "TOP", Height = 160, Tile = 512, Color = "Ice", Alpha = 0.16, BlendMode = "ADD",
        Layer = "BACKGROUND", SubLevel = 5, Motion = { Scroll = { X = 8 } } },
      -- An interlace border down the inner side and along the top and the bottom; down the outer side too on a small
      -- panel (a full one's is the screen's edge).
      { Texture = "KnotSide", Point = "INNER", Width = 12, Tile = 32, X = 4, Color = "Lavender", Alpha = 0.32 },
      { Texture = "KnotSide", Point = "OUTER", Width = 12, Tile = 32, X = 4, Color = "Lavender", Alpha = 0.32,
        Sizes = "Small" },
      { Texture = "KnotEdge", Point = "TOP", Height = 12, Tile = 32, Y = 4, Start = 16, End = 16, Color = "Lavender",
        Alpha = 0.32 },
      { Texture = "KnotEdge", Point = "BOTTOM", Height = 12, Tile = 32, Y = -4, Start = 16, End = 16,
        Color = "Lavender", Alpha = 0.32 },
      -- Ice crystals growing out of the inner corners into the feather, glinting.
      { Texture = "Crystal", Point = "TOPINNER", Width = 72, Height = 72, X = -72, TexCoords = { 1, 0, 0, 1 },
        Color = "Frost", Alpha = 0.5, BlendMode = "ADD", Motion = { Pulse = { 0.35, 0.65 }, Period = 4.5 } },
      { Texture = "Crystal", Point = "BOTTOMINNER", Width = 72, Height = 72, X = -72, TexCoords = { 1, 0, 1, 0 },
        Color = "Frost", Alpha = 0.5, BlendMode = "ADD", Motion = { Pulse = { 0.35, 0.65 }, Period = 5.5, Delay = 2 } },
    },
    -- Freezing together and shattering (NextShatter). Appearance > Animation > Ice Shatter turns it off.
    Shatter = {
      Shards = { Size = 96, Jitter = 0.32, Texture = "IceBody", Color = "White", Alpha = 1 },
      Frost = { Texture = "Frost", Color = "Frost", Alpha = 0.75, BlendMode = "ADD" },
      Seams = { Texture = "Thread", Color = "Frost", Alpha = 0.95, Thickness = 2, BlendMode = "ADD" },
      -- Out of a frost storm growing from the bottom inner corner (asked: "a sort of... frost storm that grows from the
      -- bottom left to the top right and the bag appears ... almost like the bag appearing out of the frost storm"): its
      -- flakes curling and turning, its mist rolling and growing; the shards form behind it. About 0.9 seconds in all: a
      -- bank waits for its panel to have shown before it loads, 1 second at most.
      Open = { Time = 0.5, Clear = 0.26, Spin = 160,
        Storm = { From = "BOTTOMINNER", Appear = 0.12,
          Flakes = { Texture = "Flake", Count = 140, Size = { 6, 18 }, Life = { 0.3, 0.7 }, Speed = { 140, 380 },
            Swirl = 5, Spin = 240, Colors = { "White", "Frost", "Ice" }, Alpha = { 0.55, 1 }, BlendMode = "ADD" },
          Mist = { Texture = "Glow", Count = 24, Size = { 140, 280 }, Growth = 1.8, Life = { 0.4, 0.8 },
            Speed = { 60, 160 }, Color = "Frost", Alpha = 0.3, BlendMode = "ADD" } } },
      Close = { Frost = 0.16, Crack = 0.14, Time = 0.75, Speed = { 160, 520 }, Spin = 420, Gravity = 1400, Lift = 160 },
    },
    -- Snow on a cold breeze (NextSnow): soft specks and a few flakes behind the items, more down the feather, out into
    -- the world; a gust now and then, and one as it opens. Appearance > Animation > Snowfall turns it off.
    Snow = {
      Flakes = {
        { Where = "Body", Texture = "Glow", Count = 34, Size = { 2, 5 }, Fall = { 8, 22 }, Drift = 6, Wobble = { 6, 0.35 },
          Alpha = { 0.15, 0.45 }, Colors = { "Frost", "White", "Ice" }, BlendMode = "ADD" },
        { Where = "Body", Texture = "Flake", Count = 7, Size = { 8, 14 }, Fall = { 10, 20 }, Drift = 8,
          Wobble = { 8, 0.25 }, Spin = 40, Alpha = { 0.12, 0.3 }, Colors = { "Frost", "Ice" }, BlendMode = "ADD" },
        { Where = "Feather", Texture = "Flake", Count = 14, Size = { 6, 13 }, Fall = { 14, 34 }, Drift = 14,
          Wobble = { 10, 0.3 }, Spin = 60, Alpha = { 0.3, 0.7 }, Colors = { "White", "Frost", "Ice" }, BlendMode = "ADD" },
        { Where = "Feather", Texture = "Glow", Count = 22, Size = { 2, 5 }, Fall = { 14, 30 }, Drift = 12,
          Wobble = { 6, 0.4 }, Alpha = { 0.3, 0.7 }, Colors = { "White", "Frost" }, BlendMode = "ADD" },
      },
      Gusts = { Every = 11, Time = 2.6, Strength = 110, OnOpen = true,
        Streaks = { Texture = "Streak", Count = 6, Length = { 140, 300 }, Thickness = { 3, 7 }, Alpha = 0.22,
          Color = "Frost", BlendMode = "ADD", Tilt = 8 } },
      -- Now and then a gold shooting star flies a short way across the body, its head twinkling (asked, of the streaks
      -- first blown across the whole body: "more golden, and A LOT less of them, more like... slower, shooting star,
      -- then don't even go the full length of the bag, more like... flyby twinkles").
      Flybys = { Every = { 4, 9 }, Max = 2, Travel = { 110, 170 }, Speed = { 55, 85 }, Length = { 50, 90 },
        Thickness = { 2, 3 }, Tilt = 12, Texture = "Streak", Color = "Gold", Alpha = 0.7, BlendMode = "ADD",
        Layer = "BORDER", SubLevel = 4,
        Head = { Texture = "Flake", Size = { 9, 13 }, Color = "Gold", Alpha = 0.95, BlendMode = "ADD", Twinkle = 3 } },
    },
    -- Threads of gold light (NextThreads): round the header behind the title, along the footer and out into the
    -- feather, and a long one down the feather; swaying, a glint running along each now and then.
    Threads = {
      { Anchor = "TOP", Points = { { 0, 46 }, { 0.22, 24 }, { 0.45, 52 }, { 0.72, 18 }, { 0.96, 40 }, { 1.06, 10 } },
        Segments = 28, Width = 7, Texture = "Thread", Color = "Gold", Alpha = 0.72, BlendMode = "ADD",
        Sway = { Amplitude = 5, Period = 9 },
        Glint = { Every = 7, Time = 1.6, Length = 0.12, Color = "White", Strength = 0.9 }, Draw = 0.9 },
      { Anchor = "BOTTOM", Points = { { 1.02, 36 }, { 0.72, 14 }, { 0.4, 30 }, { 0.08, 12 }, { -0.16, 34 } },
        Segments = 24, Width = 6, Texture = "Thread", Color = "Gold", Alpha = 0.6, BlendMode = "ADD",
        Sway = { Amplitude = 4, Period = 11 },
        Glint = { Every = 9, Time = 1.8, Length = 0.12, Color = "White", Strength = 0.85 }, Draw = 0.9 },
      { Anchor = "BODY", Points = { { -0.06, 0.04 }, { -0.15, 0.24 }, { -0.04, 0.45 }, { -0.17, 0.66 }, { -0.06, 0.86 },
        { -0.13, 1 } }, Segments = 36, Width = 5, Texture = "Thread", Color = "Gold", Alpha = 0.5, BlendMode = "ADD",
        Sizes = "Full", Sway = { Amplitude = 8, Period = 13 },
        Glint = { Every = 10, Time = 2.4, Length = 0.08, Color = "White", Strength = 0.8 }, Draw = 1.2 },
    },
  },

  Header = {
    TitleGlow = { Texture = "Glow", Color = "Ice", Alpha = 0.25, X = 24, Y = 14, BlendMode = "ADD" },
    Ribbon = { Length = 300, Thickness = 2, Color = "Gold", BlendMode = "ADD",
      Glow = { { 0, 0.9 }, { 2, 0.3 }, { -2, 0.3 }, { 4, 0.1 }, { -4, 0.1 } } },
    -- A snowflake gliding in along the gold ribbon into the frosty mist round the title.
    Spark = { Texture = "Flake", Size = 24, Growth = 16, Color = "White", BlendMode = "ADD" },
    Cloud = {
      Join = { Size = 34, Color = "Gold", A = 0.3 },
      Puffs = {
        { F = 0.45, Y = 0, W = false, Wide = 1.15, H = 60, Color = "Ice", A = 0.08 },
        { F = 0.10, Y = 5, W = 54, H = 50, Color = "Frost", A = 0.16 },
        { F = 0.21, Y = -8, W = 50, H = 46, Color = "Ice", A = 0.16 },
        { F = 0.34, Y = 9, W = 60, H = 54, Color = "Frost", A = 0.13 },
        { F = 0.48, Y = -7, W = 66, H = 56, Color = "Ice", A = 0.14 },
        { F = 0.62, Y = 8, W = 58, H = 52, Color = "Frost", A = 0.12 },
        { F = 0.77, Y = -6, W = 52, H = 46, Color = "Ice", A = 0.11 },
        { F = 0.91, Y = 3, W = 42, H = 40, Color = "Frost", A = 0.09 },
        { F = 0.16, Y = 17, W = 30, H = 26, Color = "Gold", A = 0.08 },
        { F = 0.28, Y = -19, W = 34, H = 30, Color = "Ice", A = 0.1 },
        { F = 0.55, Y = 19, W = 38, H = 32, Color = "Frost", A = 0.09 },
        { F = 0.70, Y = -18, W = 32, H = 28, Color = "Ice", A = 0.08 },
      },
    },
    Buttons = { HoverColor = "Gold" },
  },

  Search = {
    Edge = { Color = "Ice", Size = 1, Idle = 0.35, Hover = 0.6, Focus = 1 },
    Icon = { Color = "Ice", Idle = 0.8, Active = 1, FocusColor = "White" },
  },

  Sections = {
    Line = { Color = "Gold", From = 0.5, To = 0, Size = 1 },
    Highlight = { Color = "Ice", From = 0.12, To = 0 },
  },

  Tabs = {
    Edge = { Color = "Ice", Alpha = 0.35, Size = 1 },
    SelectedEdge = { Color = "Gold", Alpha = 0.8, Size = 1 },
    Glow = { Color = "Ice", BlendMode = "ADD", Drop = 0.3, Pulse = 0.8 },
  },

  Footer = {
    Line = { Color = "Gold", Inner = 0.1, Outer = 0.6, Size = 1 },
  },

  -- Snowflakes for sparkles, turning slowly, a few in gold.
  Sparkles = {
    Texture = "Flake",
    Colors = { "White", "Frost", "Ice", "Gold" },
    TwinkleSpeed = 4,
    TwinkleDepth = 0.4,
    Shrink = 0.2,
    WobbleSpeed = 1.6,
  },

  Chain = {
    Color = "Gold",
    BeadColor = "Frost",
    KnotColor = "Ice",
  },

  Drag = {
    Shadow = { Color = "Ice", Alpha = 0.15, Spread = 10 },
  },

  Vendor = {
    Highlight = { 0.5, 0.85, 1, 0.15 },
    CardFill = { 0.5, 0.85, 1, 0.05 },
    CardHover = { 0.5, 0.85, 1, 0.12 },
  },

  -- Item buttons as frosted cells: the icon cropped in a dark cell, a thin ice edge, an item's quality on it.
  ItemButton = {
    Icon = { Inset = 1, TexCoords = { 0.08, 0.92, 0.08, 0.92 } },
    Backdrop = { Color = { 0.02, 0.08, 0.13, 0.85 }, BorderColor = { 0.5, 0.85, 1, 0.45 }, EdgeSize = 1 },
    QualityBorder = "Backdrop",
    Highlight = { Color = { 0.6, 0.9, 1, 0.18 } },
    Pushed = { Color = { 0.6, 0.9, 1, 0.28 } },
  },

  Settings = {
    Fill = { Texture = "IceBody", Color = "White" },
    Edge = { Color = "Ice", Alpha = 0.4, Size = 1 },
  },
})
