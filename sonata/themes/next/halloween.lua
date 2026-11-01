local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- Halloween: BetterBags Next in pumpkin orange with black accents (next-themes.md §23). Asked: "think: black cats,
-- pumpkins/jack-o-lanterns, bats, orange and black. the bags should appear in a puff of smoke from bottom to top ...
-- for the bag closing, make the bag 'turn into' several bats ... main color should be orange with black accents (so
-- orange backdrop), with whimsy and fun animations. slightly cartoony almost and flat shaded ... a nice good color of
-- orange, like that of a pumpkin, not over the top bright".
--   Opening: smoke rises up the bag from the bottom, soft and uneven, swelling, curling and thinning away as real smoke
--     does, embers rising through it, and the bag shows under it (NextSmoke); a bat or two flutters out of its header.
--     Closing: the bag trembles, breaks up into a dozen or so pieces of itself that drift apart and turn into bats,
--     flapping off the screen every which way (NextBats).
--   At rest: the body a deep pumpkin orange, goo dripping along its top; at the bottom of the feather a
--     jack-o'-lantern, its candle flickering, with a black cat sitting on it, blinking now and then and swishing its
--     tail (on a small bag, the cat and a little jack-o'-lantern sit on its top edge); a cobweb in the feather's top
--     corner, a spider swinging from it; a pumpkin vine curling along the footer; autumn leaves falling down the
--     feather and behind the items (NextSnow); bats fluttering out of the header now and then; a candlelit glow round
--     the title, a bat gliding in along the black ribbon into it; little stars for sparkles.
--   Display text in Creepster (fonts/halloween, Font Diner, SIL Open Font License; its Latin alphabets only, so other
--     locales draw the client's font), the rest in the client's own; dark ink on the orange, light on the black.
-- The palette redefines Default's names (Gold, Lavender, Text, Muted...) in candlelight, a witch's purple and dark ink,
-- so everything this theme leaves to Default follows. Its art is tools/textures/next_halloween.py's. Data only.
local FONTS = "Interface\\AddOns\\BetterBags\\fonts\\halloween\\"
local TEXTURES = "Interface\\AddOns\\BetterBags\\textures\\next\\halloween\\"
-- The locales whose alphabets Creepster covers (Latin: basic, Latin-1; checked against its character map).
local LATIN = { "enUS", "enGB", "deDE", "frFR", "esES", "esMX", "itIT", "ptBR" }

-- A role in Creepster: its size and colour, no shadow.
local function creepster(size, color)
  return { File = FONTS .. "Creepster-Regular.ttf", Locales = LATIN, Size = size, Color = color, Shadow = false }
end

-- Light text on the black parts (tabs, the search box, menus) carries a shadow of its own.
local DARK_SHADOW = { Color = "Black", X = 1, Y = -1 }

-- The smoke's look: greys with a little of a witch's purple in them, a few darker.
local SMOKE_COLORS = { "Smoke", "Smoke", "SmokeShade", "SmokeDeep" }

sonataNext:RegisterTheme({
  Name = "Halloween",
  DisplayName = "Halloween",
  Description = "Pumpkin orange and black: it appears out of rising smoke, breaks up into bats when it closes, and a "
    .. "black cat keeps watch on a jack-o'-lantern while the leaves fall.",

  Palette = {
    -- A pumpkin's orange, not over bright and a little deep (body.png's average).
    Body = { 0.8, 0.4, 0.11, 0.97 },
    Wash = { 1, 0.78, 0.35, 0.12 },
    -- Candlelight where Default is gold; a witch's purple where it is lavender.
    Gold = { 1, 0.78, 0.24, 1 },
    Lavender = { 0.27, 0.13, 0.33, 1 },
    -- Dark ink on the orange; light bone and pumpkin on the black.
    Ink = { 0.09, 0.055, 0.04, 1 },
    InkSoft = { 0.24, 0.12, 0.05, 1 },
    InkMuted = { 0.38, 0.19, 0.06, 1 },
    Text = { 0.09, 0.055, 0.04, 1 },
    Muted = { 0.38, 0.19, 0.06, 1 },
    Bone = { 0.96, 0.9, 0.77, 1 },
    PumpkinLight = { 1, 0.64, 0.28, 1 },
    PumpkinDim = { 0.78, 0.47, 0.22, 1 },
    Night = { 0.27, 0.13, 0.33, 1 },
    Blood = { 0.55, 0.04, 0.04, 1 },
    Lime = { 0.66, 0.9, 0.24, 1 },
    -- The smoke: greys, a little purple.
    Smoke = { 0.88, 0.86, 0.9, 1 },
    SmokeShade = { 0.7, 0.67, 0.75, 1 },
    SmokeDeep = { 0.52, 0.48, 0.57, 1 },
    -- Autumn leaves and the vine.
    Rust = { 0.66, 0.2, 0.07, 1 },
    Ochre = { 0.9, 0.64, 0.14, 1 },
    Brown = { 0.42, 0.23, 0.09, 1 },
    Maroon = { 0.46, 0.08, 0.1, 1 },
    Vine = { 0.18, 0.29, 0.09, 1 },
    Warbank = { 0.3, 0.75, 0.85, 1 },
    WarbankWash = { 0.3, 0.75, 0.85, 0.12 },
    Guild = { 0.45, 0.85, 0.35, 1 },
    GuildWash = { 0.45, 0.85, 0.35, 0.12 },
    -- The black accents: tabs (the chosen one in the witch's purple), the search box, menus.
    Tab = { 0.08, 0.05, 0.04, 0.94 },
    TabSelected = { 0.25, 0.12, 0.31, 0.97 },
    Card = { 0.09, 0.055, 0.045, 0.97 },
    Scrim = { 0, 0, 0, 0.5 },
    SearchFill = { 0.08, 0.05, 0.04, 0.92 },
    SearchFillFocus = { 0.15, 0.08, 0.11, 0.96 },
    -- No shadow under the ink; light text on the black carries its own.
    Shadow = { 0, 0, 0, 0 },
    ButtonIcon = { 0.09, 0.055, 0.04, 1 },
    Art = { 0.95, 0.92, 0.88, 1 },
    Bead = { 1, 0.92, 0.7, 1 },
    -- The settings window's controls (next-settings.md §6): fields a deeper orange than the page, edged in ink, a
    -- darker one pressed and for a switch's or slider's empty track; a deep red for what deletes.
    ControlFill = { 0.72, 0.36, 0.1, 1 },
    ControlHover = { 0.77, 0.39, 0.12, 1 },
    ControlPressed = { 0.64, 0.31, 0.08, 1 },
    Track = { 0.53, 0.25, 0.07, 1 },
    Danger = { 0.55, 0.04, 0.04, 1 },
    Crimson = { 0.7, 0.06, 0.06, 1 },
    Emerald = { 0.22, 0.62, 0.18, 1 },
    Sidebar = { 0.09, 0.055, 0.04, 0.1 },
    Gain = { 0.12, 0.4, 0.05, 1 },
    Capped = { 0.55, 0.04, 0.04, 1 },
  },

  Textures = {
    HalloweenBody = TEXTURES .. "body.png",
    Puff = TEXTURES .. "puff.png",
    Star = TEXTURES .. "star.png",
    Bats = TEXTURES .. "bats.png",
    Bat = TEXTURES .. "bat.png",
    Cat = TEXTURES .. "cat.png",
    CatEyes = TEXTURES .. "cat_eyes.png",
    CatTail = TEXTURES .. "cat_tail.png",
    Pumpkin = TEXTURES .. "pumpkin.png",
    PumpkinFace = TEXTURES .. "pumpkin_face.png",
    Web = TEXTURES .. "web.png",
    Spider = TEXTURES .. "spider.png",
    Leaf = TEXTURES .. "leaf.png",
    Vine = TEXTURES .. "vine.png",
    Drips = TEXTURES .. "drips.png",
  },

  FontShadow = { Color = "Shadow", X = 0, Y = 0 },
  Fonts = {
    Title = creepster(30, "Ink"),
    Section = creepster(17, "Ink"),
    SectionRecent = creepster(17, "Night"),
    SectionFree = creepster(16, "InkMuted"),
    Count = { Color = "InkMuted" },
    Tab = { Color = "PumpkinLight", Shadow = DARK_SHADOW },
    TabSelected = { Color = "Gold", Shadow = DARK_SHADOW },
    Footer = { Color = "InkSoft" },
    Empty = creepster(22, "InkMuted"),
    ConfirmTitle = creepster(20, "Ink"),
    ConfirmWarning = { Color = "Blood" },
    ConfirmHint = { Color = "InkSoft" },
    Search = { Color = "PumpkinDim" },
    SearchText = { Color = "Bone", Shadow = DARK_SHADOW },
    Price = { Color = "Ink" },
    PriceUnaffordable = { Color = "Blood" },
    VendorName = { Color = "Ink", Shadow = false },
    CurrencyCapped = { Color = "Blood" },
    CurrencyNone = { Color = "InkMuted" },
    CurrencyName = { Color = "Ink" },
    CurrencyGain = { Color = "Gain" },
    CurrencyLoss = { Color = "InkMuted" },
    CurrencyMore = { Color = "InkSoft" },
    -- The numbers over item icons, on their dark cells, keep a shadow.
    Stack = { Shadow = DARK_SHADOW },
    DragHint = { Color = "Bone", Shadow = DARK_SHADOW },
    -- The settings window and its controls, in ink on the orange; candlelight on the black (a primary button, a menu's
    -- choice), the witch's purple for what leads (a heading in the sidebar, a link under the pointer).
    ControlText = { Color = "Ink" },
    ControlMuted = { Color = "InkMuted" },
    ControlHelp = { Color = "InkMuted" },
    Button = { Color = "Ink", Shadow = false },
    ButtonPrimary = { Color = "Gold", Shadow = DARK_SHADOW },
    ButtonDanger = { Color = "Danger" },
    Link = { Color = "InkSoft" },
    LinkHover = { Color = "Night" },
    MenuItem = { Color = "Bone" },
    MenuItemSelected = { Color = "Gold" },
    DialogTitle = creepster(22, "Ink"),
    DialogText = { Color = "InkSoft" },
    TopTab = { Color = "InkMuted" },
    TopTabHover = { Color = "InkSoft" },
    TopTabSelected = { Color = "Ink" },
    SettingsBrand = creepster(26, "Ink"),
    SettingsNavGroup = { Color = "Night" },
    SettingsNav = { Color = "InkSoft" },
    SettingsNavHover = { Color = "Ink" },
    SettingsNavSelected = { Color = "Ink" },
    SettingsVersion = { Color = "InkMuted" },
    SettingsTitle = creepster(30, "Ink"),
    SettingsDescription = { Color = "InkSoft" },
    SettingsSection = { Color = "InkMuted" },
    SettingsSectionNote = { Color = "InkMuted" },
    SettingsLabel = { Color = "Ink" },
    SettingsText = { Color = "InkSoft" },
    SettingsLink = { Color = "Night" },
  },

  Motion = {
    -- Sections pop into place, a touch past and back, as the smoke clears.
    Time = { Cascade = 0.36, Stagger = 0.045, ShimmerEvery = 6 },
    Ease = { Cascade = "outBackSoft" },
    Rise = 10,
  },

  Panel = {
    Fill = { Texture = "HalloweenBody", Color = "White" },
    Feather = { Color = "Body" },
    Edge = { Color = "Ink", Alpha = 0.85, Size = 2 },
    Wash = { Height = 200, BlendMode = "ADD" },
    DropGlow = { Color = "Gold", Alpha = 0.18, BlendMode = "ADD" },
    -- Each piece drawn for the backpack (its inner side on the left) and mirrored on the panels across the screen.
    Ornaments = {
      -- Goo dripping along the top, above the title and the header buttons.
      { Texture = "Drips", Point = "TOP", Height = 16, Tile = 128, Color = "Ink", Alpha = 0.92, Layer = "BORDER",
        SubLevel = 6 },
      -- A cobweb across the feather's top corner, a spider swinging from it.
      { Texture = "Web", Point = "TOPINNER", Width = 92, Height = 92, X = -92, Color = "Bone", Alpha = 0.5,
        Sizes = "Full" },
      { Texture = "Spider", Point = "TOPINNER", Width = 16, Height = 64, X = -44, Y = 18, Sizes = "Full",
        Motion = { Sway = 8, Period = 3.6, Origin = "TOP" } },
      -- A jack-o'-lantern at the bottom of the feather, its candle flickering in its face and round it.
      { Texture = "Glow", Point = "BOTTOMINNER", Width = 140, Height = 110, X = -118, Y = 16, Color = "Gold",
        Alpha = 0.4, BlendMode = "ADD", Layer = "BACKGROUND", SubLevel = 7, Sizes = "Full",
        Motion = { Flicker = { Low = 0.5, Speed = 7 } } },
      { Texture = "Pumpkin", Point = "BOTTOMINNER", Width = 84, Height = 84, X = -90, Layer = "ARTWORK", SubLevel = 1,
        Sizes = "Full" },
      { Texture = "PumpkinFace", Point = "BOTTOMINNER", Width = 84, Height = 84, X = -90, Layer = "ARTWORK",
        SubLevel = 2, Sizes = "Full", Motion = { Flicker = { Low = 0.45, Speed = 9 } } },
      -- A black cat sitting on it, swishing its tail, blinking now and then.
      { Texture = "CatTail", Point = "BOTTOMINNER", Width = 32, Height = 64, X = -86, Y = -58, Layer = "ARTWORK",
        SubLevel = 3, Sizes = "Full", Motion = { Sway = 12, Period = 2.8, Origin = "BOTTOMOUTER" } },
      { Texture = "Cat", Point = "BOTTOMINNER", Width = 64, Height = 64, X = -76, Y = -52, Layer = "ARTWORK",
        SubLevel = 4, Sizes = "Full" },
      { Texture = "CatEyes", Point = "BOTTOMINNER", Width = 64, Height = 64, X = -76, Y = -52, Layer = "ARTWORK",
        SubLevel = 5, Sizes = "Full", Motion = { Blink = { Every = { 3, 7 }, Time = 0.13, Twice = 0.3 } } },
      -- On a small bag, the cat and a little jack-o'-lantern sit on its top edge.
      { Texture = "Cat", Point = "TOPOUTER", Anchor = "BOTTOMOUTER", Width = 52, Height = 52, X = 34, Y = 4,
        Layer = "ARTWORK", SubLevel = 4, Sizes = "Small" },
      { Texture = "CatEyes", Point = "TOPOUTER", Anchor = "BOTTOMOUTER", Width = 52, Height = 52, X = 34, Y = 4,
        Layer = "ARTWORK", SubLevel = 5, Sizes = "Small",
        Motion = { Blink = { Every = { 3, 7 }, Time = 0.13, Twice = 0.3 } } },
      { Texture = "Pumpkin", Point = "TOPOUTER", Anchor = "BOTTOMOUTER", Width = 44, Height = 44, X = 84, Y = 4,
        Layer = "ARTWORK", SubLevel = 1, Sizes = "Small" },
      { Texture = "PumpkinFace", Point = "TOPOUTER", Anchor = "BOTTOMOUTER", Width = 44, Height = 44, X = 84, Y = 4,
        Layer = "ARTWORK", SubLevel = 2, Sizes = "Small", Motion = { Flicker = { Low = 0.45, Speed = 9 } } },
    },
    -- Out of smoke (NextSmoke; asked: "make it more real-ish"): a front rising up the body leaves rows of soft, uneven
    -- puffs, each at a strength and an angle of its own, swelling, rising faster and faster, curling and thinning away
    -- from the bottom up; embers rising through it. The bag shows under it by 0.4 seconds (a bank waits for its panel
    -- to have shown before it loads, 1 second at most), and the smoke clears about a second later.
    -- Appearance > Animation > Smoke Puff turns it off.
    Smoke = {
      Puffs = { Texture = "Puff", Colors = SMOKE_COLORS, Size = { 110, 160 }, Alpha = { 0.35, 0.65 }, BlendMode = "BLEND",
        Spin = 25 },
      Sparks = { Texture = "Glow", Count = 12, Size = { 10, 16 }, Life = { 0.3, 0.55 }, Rise = { 40, 90 },
        Colors = { "Gold", "PumpkinLight" }, Alpha = 1, BlendMode = "ADD" },
      Open = { Rise = 0.36, Spacing = 52, Jitter = 0.35, Life = { 0.75, 1.25 }, Start = 0.55, Growth = 1.8,
        FadeIn = 0.12, Lift = { 25, 55 }, Buoyancy = 80, Spread = { 10, 35 }, Burst = 3, Swirl = { 12, 0.7 },
        Reveal = { 0.1, 0.4 } },
    },
    -- Turning into bats (NextBats; asked: "no puff of smokes: how the frost theme shatters, we want the bag break up
    -- *and morph* into bats and fly away. almost a surreal effect"): it trembles a moment, breaks into a dozen or so
    -- pieces of its own body that drift apart, and each turns into a bat that flaps off the screen every which way
    -- (asked: "like 10-15 bats, and fly away in random directions off screen"); and now and then one to three fluttering
    -- out of the header, as it opens too. Appearance > Animation > Bats turns them off.
    Bats = {
      Texture = "Bats", Frames = 4, FrameRate = 14, Color = "White", BlendMode = "BLEND",
      Close = { Count = { 11, 15 }, Pieces = { Texture = "HalloweenBody", Color = "White" }, Jitter = 0.3,
        Shudder = 0.18, Tremble = 3, Break = 0.12, Gap = 16, Morph = 0.32, Dark = "Ink", Delay = { 0, 0.16 },
        Size = { 44, 70 }, Speed = { 170, 260 }, Accel = 1.6, Wobble = { 14, 2.2 }, Tilt = 22, Life = 3.5, Spread = 50 },
      Flutter = { Every = { 9, 18 }, Count = { 1, 3 }, Size = { 22, 32 }, Speed = { 90, 140 }, Wobble = { 7, 2.6 },
        Stagger = 0.35, Travel = 420, Band = { 28, 62 }, Rise = { -30, 10 }, Alpha = 1, OnOpen = true,
        Layer = "BORDER", SubLevel = 6 },
    },
    -- Autumn leaves (NextSnow): down the feather, out into the world, and a few behind the items, tumbling as they
    -- fall, a gust now and then. Appearance > Animation > Snow, Leaves and Stars turns them off.
    Snow = {
      Flakes = {
        { Where = "Feather", Texture = "Leaf", Count = 10, Size = { 12, 20 }, Fall = { 18, 34 }, Drift = 10,
          Wobble = { 14, 0.35 }, Spin = 120, Alpha = { 0.85, 1 }, Colors = { "Rust", "Ochre", "Brown", "Maroon", "Rust" },
          BlendMode = "BLEND" },
        { Where = "Body", Texture = "Leaf", Count = 5, Size = { 10, 16 }, Fall = { 10, 20 }, Drift = 6,
          Wobble = { 10, 0.3 }, Spin = 90, Alpha = { 0.35, 0.55 }, Colors = { "Rust", "Brown", "Maroon" },
          BlendMode = "BLEND" },
      },
      Gusts = { Every = 14, Time = 2.4, Strength = 90 },
    },
    -- A pumpkin vine curling along the footer out to the jack-o'-lantern, swaying a little (NextThreads).
    Threads = {
      { Anchor = "BOTTOM", Points = { { 1.02, 10 }, { 0.78, 4 }, { 0.52, 12 }, { 0.26, 3 }, { 0.02, 11 }, { -0.1, 6 } },
        Segments = 24, Width = 4, Texture = "Vine", Color = "Vine", Alpha = 0.85, BlendMode = "BLEND",
        Sway = { Amplitude = 2, Period = 8 }, Draw = 0.8 },
    },
  },

  Header = {
    TitleGlow = { Texture = "Glow", Color = "Gold", Alpha = 0.3, X = 24, Y = 14, BlendMode = "ADD" },
    -- A black ribbon out of the window, and a bat gliding in along it into the candlelight round the title.
    Ribbon = { Length = 300, Thickness = 2, Color = "Ink", BlendMode = "BLEND",
      Glow = { { 0, 0.9 }, { 1, 0.35 }, { -1, 0.35 } } },
    Spark = { Texture = "Bat", Size = 30, Growth = 10, Color = "White", BlendMode = "BLEND" },
    Cloud = {
      Join = { Size = 34, Color = "Gold", A = 0.3 },
      Puffs = {
        { F = 0.45, Y = 0, W = false, Wide = 1.15, H = 60, Color = "Gold", A = 0.1 },
        { F = 0.10, Y = 5, W = 54, H = 50, Color = "Gold", A = 0.22 },
        { F = 0.21, Y = -8, W = 50, H = 46, Color = "Gold", A = 0.2 },
        { F = 0.34, Y = 9, W = 60, H = 54, Color = "Gold", A = 0.18 },
        { F = 0.48, Y = -7, W = 66, H = 56, Color = "Gold", A = 0.18 },
        { F = 0.62, Y = 8, W = 58, H = 52, Color = "Gold", A = 0.16 },
        { F = 0.77, Y = -6, W = 52, H = 46, Color = "Gold", A = 0.14 },
        { F = 0.91, Y = 3, W = 42, H = 40, Color = "Gold", A = 0.12 },
        { F = 0.16, Y = 17, W = 30, H = 26, Color = "Gold", A = 0.1 },
        { F = 0.28, Y = -19, W = 34, H = 30, Color = "Gold", A = 0.1 },
        { F = 0.55, Y = 19, W = 38, H = 32, Color = "Gold", A = 0.1 },
        { F = 0.70, Y = -18, W = 32, H = 28, Color = "Gold", A = 0.09 },
      },
    },
    -- The glyphs (settings, close) in ink, the witch's purple under the pointer; colored icons in their own colors.
    Buttons = { Color = "Ink", HoverColor = "Night", ArtColor = "Art", ArtHoverColor = "White" },
  },

  Search = {
    Edge = { Color = "Ink", Size = 1, Idle = 0.6, Hover = 0.85, Focus = 1 },
    Icon = { Color = "PumpkinLight", Idle = 0.8, Active = 1, FocusColor = "Gold" },
  },

  Sections = {
    Line = { Color = "Ink", From = 0.55, To = 0, Size = 2 },
    Highlight = { Color = "Night", From = 0.14, To = 0 },
  },

  Tabs = {
    Fade = 0.85,
    Glow = { Color = "Gold", BlendMode = "ADD", Drop = 0.3, Pulse = 0.8 },
    Indicator = { Color = "Gold" },
  },

  Footer = {
    Line = { Color = "Ink", Inner = 0.1, Outer = 0.6, Size = 1 },
  },

  -- Little stars for sparkles, in candlelight, lime and bone, drawn flat.
  Sparkles = {
    Texture = "Star",
    BlendMode = "BLEND",
    Colors = { "Gold", "Lime", "Bone" },
    TwinkleSpeed = 5,
    TwinkleDepth = 0.35,
  },

  Chain = { Color = "Gold", BeadColor = "Bone", KnotColor = "Gold" },

  Drag = { Shadow = { Color = "Black", Alpha = 0.3 } },

  -- A docked section's card on the pumpkin's orange, its text in ink.
  Dock = {
    Card = { Texture = "HalloweenBody", Color = "White" },
    Glow = { Color = "Ink" },
  },

  -- Tracked currencies in ink on the orange, their caps in red; the tracker a slip of the orange (currency.md).
  Currency = {
    Bar = { Track = { Color = "Ink", Alpha = 0.15 }, Fill = { Color = "Ink", Alpha = 0.75 }, Capped = { Color = "Blood" } },
    Hover = { Color = "Ink", Alpha = 0.06 },
    Drop = { Color = "Gold", Alpha = 0.4 },
    Slot = { Color = "Ink" },
    Tracker = {
      Fill = { Texture = "HalloweenBody", Color = "White" },
      Edge = { Color = "Ink", Alpha = 0.6 },
    },
  },

  -- The settings window on the pumpkin's orange, its lines and lights in ink, its marks in the witch's purple.
  Settings = {
    Fill = { Texture = "HalloweenBody", Color = "White" },
    Wash = false,
    Edge = { Color = "Ink", Alpha = 0.7 },
    Sidebar = { Fill = { Color = "Ink", Alpha = 0.08 }, Line = { Color = "Ink", Alpha = 0.3 } },
    Brand = { IconColor = "Night", Line = { Color = "Ink" } },
    Search = { IconColor = "Ink" },
    Back = { IconColor = "Ink" },
    Nav = {
      Indicator = { Color = "Night" },
      SelectedFill = { Color = "Ink", Alpha = 0.1 },
      HoverFill = { Color = "Ink", Alpha = 0.05 },
    },
    Header = { Close = { Color = "Ink", HoverColor = "Night" } },
    Content = {
      Card = { Color = "Ink", Alpha = 0.05 },
      Divider = { Color = "Ink", Alpha = 0.18 },
      Hover = { Color = "Ink", Alpha = 0.06 },
    },
    Footer = { Line = { Color = "Ink", Alpha = 0.3 } },
    Cards = {
      Fill = { Color = "Ink", Alpha = 0.05 }, HoverFill = { Color = "Ink", Alpha = 0.1 },
      Edge = { Color = "Ink", Alpha = 0.3 }, SelectedEdge = { Color = "Night", Alpha = 0.9 },
    },
    Categories = {
      Indicator = { Color = "Night" },
      SelectedFill = { Color = "Ink", Alpha = 0.1 },
      HoverFill = { Color = "Ink", Alpha = 0.05 },
    },
    BagCategories = {
      Fill = { Color = "Ink", Alpha = 0.04 },
      HoverFill = { Color = "Ink", Alpha = 0.05 },
    },
  },

  -- Its controls: fields a deeper orange edged in ink; black where Default is gold (a switch on, a slider's fill, a
  -- primary button), the black menus' choices in bone; a dialog is a slip of the orange.
  Controls = {
    ScrollBar = {
      Track = { Color = "Ink", Alpha = 0.08 }, Thumb = { Color = "Ink", Alpha = 0.35 },
      ThumbHover = { Color = "Ink", Alpha = 0.6 }, ThumbDrag = { Color = "Night", Alpha = 0.9 },
    },
    Toggle = {
      On = { Color = "Ink", Alpha = 0.92 }, Edge = { Color = "Ink", Alpha = 0.45 },
      Knob = { Color = "Ink" }, KnobOn = { Color = "PumpkinLight" }, Hover = { Color = "Ink", Alpha = 0.06 },
    },
    Button = {
      Plain = { Edge = { Color = "Ink", Alpha = 0.45 }, HoverEdge = { Color = "Ink", Alpha = 0.75 } },
      Primary = {
        Fill = { Color = "Ink", Alpha = 0.88 }, HoverFill = { Color = "Night", Alpha = 1 },
        PressedFill = { Color = "Ink", Alpha = 0.7 },
        Edge = { Color = "Ink", Alpha = 1 }, HoverEdge = { Color = "Gold", Alpha = 0.8 },
      },
    },
    Input = { Edge = { Color = "Ink" } },
    Slider = { Fill = { Color = "Ink" }, Thumb = { Color = "Ink" }, ThumbHover = { Color = "Night" } },
    Dropdown = { Edge = { Color = "Ink" }, Chevron = { Color = "Ink" } },
    Menu = {
      Edge = { Color = "Gold", Alpha = 0.5 },
      HoverFill = { Color = "Gold", Alpha = 0.15 },
      Check = { Color = "Gold" },
    },
    Swatch = { Edge = { Color = "Ink", Alpha = 0.5 }, HoverEdge = { Color = "Ink", Alpha = 0.9 } },
    TopTabs = { Indicator = { Color = "Ink" }, Line = { Color = "Ink", Alpha = 0.25 } },
    ItemGrid = {
      CommonEdge = { Color = "Ink", Alpha = 0.3 },
      Hover = { Color = "Ink", Alpha = 0.12 },
    },
    Dialog = {
      Card = { Texture = "HalloweenBody", Color = "White" },
      Edge = { Color = "Ink", Alpha = 0.7 },
    },
  },

  Vendor = {
    Highlight = { 0, 0, 0, 0.12 },
    -- Cards inked faintly on the orange.
    CardFill = { 0.09, 0.055, 0.04, 0.08 },
    CardHover = { 0.09, 0.055, 0.04, 0.12 },
  },

  -- Item buttons as dark cells on the orange: the icon cropped, a thin ink edge, an item's quality on its icon's border.
  ItemButton = {
    Icon = { Inset = 1, TexCoords = { 0.08, 0.92, 0.08, 0.92 } },
    Backdrop = { Color = { 0.12, 0.07, 0.09, 0.92 }, BorderColor = { 0.09, 0.055, 0.04, 1 }, EdgeSize = 1 },
    Highlight = { Color = { 1, 0.8, 0.3, 0.18 } },
    Pushed = { Color = { 1, 0.8, 0.3, 0.28 } },
  },
})
