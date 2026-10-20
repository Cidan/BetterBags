local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- Default is BetterBags Next's own look (asked: "the current design should be the default"): deep
-- indigo panels, moonlit lavender and starlight gold. It is complete: every other Next theme
-- inherits what it does not set from it. The schema is in .claude/rules/next-themes.md. Data only.
sonataNext:RegisterTheme({
  Name = "Default",
  DisplayName = "Default",
  Description = "BetterBags Next's own look: deep indigo, moonlit lavender and starlight gold, with sparkles.",

  -- Colors as { r, g, b, a }. Everything else names them.
  Palette = {
    Body = { 0.045, 0.04, 0.085, 0.94 },
    Wash = { 0.55, 0.45, 1.0, 0.16 },
    Gold = { 1.0, 0.84, 0.5, 1 },
    -- The Warbank's accent, and the wash the panel takes while it shows a Warbank tab.
    Warbank = { 0.35, 0.85, 0.95, 1 },
    WarbankWash = { 0.3, 0.75, 1.0, 0.16 },
    -- The guild bank's accent and wash: the guild's green (guild chat's color).
    Guild = { 0.4, 1.0, 0.5, 1 },
    GuildWash = { 0.3, 1.0, 0.45, 0.16 },
    White = { 1, 1, 1, 1 },
    Black = { 0, 0, 0, 1 },
    Lavender = { 0.78, 0.72, 1.0, 1 },
    Text = { 0.96, 0.95, 1.0, 1 },
    Muted = { 0.62, 0.58, 0.78, 1 },
    Tab = { 0.09, 0.08, 0.16, 0.92 },
    TabSelected = { 0.18, 0.15, 0.32, 0.96 },
    -- A move waiting to be confirmed (the dock): its card, and the scrim dimming the panel behind it.
    Card = { 0.1, 0.085, 0.19, 0.98 },
    Scrim = { 0, 0, 0, 0.6 },
    -- The search box's fill, idle and focused: lighter than the body, so it reads as a field.
    SearchFill = { 0.133, 0.114, 0.239, 1 },
    SearchFillFocus = { 0.165, 0.141, 0.314, 1 },
    -- Text shadows.
    Shadow = { 0, 0, 0, 0.85 },
    -- The header buttons' icons, and the lights running along the braid.
    ButtonIcon = { 0.85, 0.82, 1, 1 },
    Bead = { 1, 0.95, 0.8, 1 },
    -- The vendor's tints, as Blizzard's merchant frame tints (MerchantFrame_UpdateMerchantInfo).
    Unusable = { 0.9, 0, 0, 1 },
    SoldOutUnusable = { 0.5, 0, 0, 1 },
    SoldOut = { 0.5, 0.5, 0.5, 1 },
    Unaffordable = { 1, 0.25, 0.25, 1 },
  },

  -- Files the theme draws with, named.
  Textures = {
    -- White, the shape in the alpha: a soft round glow (tools/textures/next_glow.py).
    Glow = "Interface\\AddOns\\BetterBags\\textures\\next\\glow.png",
    -- The cooldown "bling" star, on every client.
    Sparkle = "Interface\\Cooldown\\star4",
    -- The header buttons' glyphs (tools/textures/next_icons.py): white line art, the shape in the
    -- alpha, in the style of Blizzard's settings gear.
    IconSettings = "Interface\\AddOns\\BetterBags\\textures\\next\\icons\\settings.png",
    IconClose = "Interface\\AddOns\\BetterBags\\textures\\next\\icons\\close.png",
    IconSort = "Interface\\AddOns\\BetterBags\\textures\\next\\icons\\sort.png",
    IconBags = "Interface\\AddOns\\BetterBags\\textures\\next\\icons\\bags.png",
    IconSmall = "Interface\\AddOns\\BetterBags\\textures\\next\\icons\\small.png",
    IconFull = "Interface\\AddOns\\BetterBags\\textures\\next\\icons\\full.png",
    IconBankTabs = "Interface\\AddOns\\BetterBags\\textures\\next\\icons\\banktabs.png",
    IconDeposit = "Interface\\AddOns\\BetterBags\\textures\\next\\icons\\deposit.png",
    IconDepositGold = "Interface\\AddOns\\BetterBags\\textures\\next\\icons\\depositgold.png",
    IconWithdrawGold = "Interface\\AddOns\\BetterBags\\textures\\next\\icons\\withdrawgold.png",
    IconFilter = "Interface\\AddOns\\BetterBags\\textures\\next\\icons\\filter.png",
    IconSellJunk = "Interface\\AddOns\\BetterBags\\textures\\next\\icons\\selljunk.png",
    IconRepair = "Interface\\AddOns\\BetterBags\\textures\\next\\icons\\repair.png",
    IconGuildRepair = "Interface\\AddOns\\BetterBags\\textures\\next\\icons\\guildrepair.png",
  },

  -- Text roles: Size, Color, Shadow (true: FontShadow; a table: its own; unset: none), Flags, File (a
  -- font file; unset: the client's own, for the locale), Justify. Every theme application makes new
  -- font objects (next-themes.md, text).
  FontShadow = { Color = "Shadow", X = 0, Y = -2 },
  Fonts = {
    Title = { Size = 26, Color = "White", Shadow = true },
    Section = { Size = 14, Color = "Text", Shadow = true },
    SectionRecent = { Size = 14, Color = "Gold", Shadow = true },
    SectionFree = { Size = 13, Color = "Muted" },
    Count = { Size = 11, Color = "Muted" },
    Tab = { Size = 12, Color = "Muted" },
    TabSelected = { Size = 12, Color = "White", Shadow = true },
    Footer = { Size = 12, Color = "Muted" },
    -- "Nothing here yet" over an empty tab.
    Empty = { Size = 12, Color = "Muted" },
    -- What dropping a dragged section does ("Move to the Bank").
    DragHint = { Size = 12, Color = "White", Shadow = true },
    -- A move waiting to be confirmed (the dock): what it does, its warning, and how to answer.
    ConfirmTitle = { Size = 18, Color = "White", Shadow = true },
    ConfirmWarning = { Size = 12, Color = "Gold" },
    ConfirmHint = { Size = 12, Color = "Lavender" },
    -- The search box's help text ("Search Backpack"), and what is typed in it.
    Search = { Size = 12, Color = "Muted" },
    SearchText = { Size = 13, Color = "Text" },
    -- The vendor's buttons: the price under the icon (and one the player cannot afford), the stack
    -- size and stock on it.
    Price = { Size = 10, Color = "White", Shadow = true },
    PriceUnaffordable = { Size = 10, Color = "Unaffordable", Shadow = true },
    Stack = { Size = 11, Color = "White", Shadow = true },
  },

  -- Sizes, in UI units.
  Layout = {
    -- Item icons, the room under a vendor button's icon for its price, between icons, per row.
    Icon = 44,
    VendorPrice = 14,
    Gap = 6,
    PerRow = 8,
    -- The scroll box keeps its bar's room on both sides (render/scrollbox.lua, Symmetric).
    Gutter = 28,
    -- Between the body's edges and the scroll box.
    Pad = 18,
    -- The feathered edge beside the body, transparent to opaque.
    Feather = 96,
    -- The header, from the body's top: the title, then the search box; the content starts below.
    TitleTop = 24,
    -- Text in from the body's edge past Pad: the title, and the footer's free slots.
    TitleInset = 4,
    SearchTop = 70,
    SearchHeight = 26,
    -- The search box's magnifier, the room left of it and between it and the text, and the room
    -- right of the text (its clear button).
    SearchIcon = 14,
    SearchGap = 8,
    SearchRight = 24,
    ContentTop = 110,
    -- "Nothing here yet", below the content's top.
    EmptyTop = 40,
    Footer = 40,
    -- The footer's free slots and money, up from the body's bottom.
    FooterText = 14,
    FooterMoney = 12,
    -- Sections: a header row above the icons, and the room between sections.
    SectionHeader = 24,
    SectionSpacing = 16,
    -- Tabs down the body's inner edge.
    TabHeight = 30,
    TabSpacing = 6,
    TabMinWidth = 76,
    TabMaxWidth = 150,
    TabPadding = 14,
    TabHover = 6,
    TabIcon = 16,
    TabIconGap = 6,
    -- Between the bank's character tabs and its Warbank tabs.
    TabGroupGap = 10,
    -- The header buttons: their size, the room between them, how far down from the body's top.
    HeaderButton = 22,
    HeaderButtonGap = 8,
    HeaderButtonTop = 27,
  },

  -- Animations: how long (seconds) and how (an ease of next/tween.lua: linear, outCubic, inCubic,
  -- inOutSine, inOutCubic, outBack, outBackSoft).
  Motion = {
    Time = {
      -- Everything that moves in answer to the player: items and sections gliding to new places, a
      -- dropped section landing or flying away, the tab bar gliding.
      Interaction = 0.24,
      Open = 0.45,
      Close = 0.24,
      Cascade = 0.32,
      Stagger = 0.045,
      OpenCascadeDelay = 0.12,
      Glide = 0.24,
      -- The wash at the top of the panel fading to another color.
      Wash = 0.44,
      Hover = 0.15,
      Shimmer = 1.4,
      ShimmerEvery = 3.4,
      -- How long the shimmer takes to settle into the title's cloud once it arrives.
      Absorb = 0.7,
      -- Moving sections.
      Lift = 0.12,
      Land = 0.24,
      FlyAway = 0.24,
      Pulse = 0.6,
      -- Chaining: a bag flying to its partner, or home; a chained bag coming in beside its partner;
      -- the ribbons twisting together, and coming apart.
      Fly = 0.45,
      Enter = 0.5,
      Couple = 0.35,
      Uncouple = 0.25,
      -- Switching between full and small: the glide, then the fade.
      Morph = 0.4,
      MorphFade = 0.2,
      -- A small panel gliding back to its default size (Shift-click on a grip).
      Resize = 0.4,
    },
    Ease = {
      -- Opening's overshoot sets how far the body reaches past the screen edge, so the bounce never
      -- shows what is behind the panel (NextStyle: OVERREACH).
      Open = "outBack",
      Close = "inCubic",
      SmallOpen = "outCubic",
      SmallClose = "inCubic",
      Enter = "outBackSoft",
      Fly = "inOutCubic",
      Glide = "outCubic",
      Hover = "outCubic",
      Wash = "inOutSine",
      Cascade = "outCubic",
      Lift = "outCubic",
      Land = "outCubic",
      FlyAway = "inCubic",
      Pulse = "outCubic",
      Couple = "outCubic",
      Uncouple = "inOutSine",
      Morph = "inOutCubic",
      MorphFade = "inOutSine",
      Resize = "inOutCubic",
    },
    -- How far sections rise as they cascade in.
    Rise = 12,
  },

  -- The panel itself.
  Panel = {
    -- The body (a texture spec: Color, Texture, Atlas, TexCoords, HorizTile, VertTile, BlendMode,
    -- Alpha, VertexColor, Gradient).
    Fill = { Color = "Body" },
    -- The feathered edge beside the body: from Color's alpha at the body to nothing (Layout.Feather
    -- wide).
    Feather = { Color = "Body" },
    -- The faint color at the top of the body, from nothing below to its color at the top; a Warbank
    -- tab and the guild bank tint it.
    Wash = { Height = 260, BlendMode = "ADD" },
    Washes = { Default = "Wash", Warbank = "WarbankWash", Guild = "GuildWash" },
    -- A small panel's border round its body (Full: a full panel's too).
    Edge = { Color = "Lavender", Alpha = 0.35, Size = 1, Full = false },
    -- Lit while a section from the other bag would drop on it.
    DropGlow = { Color = "Lavender", Alpha = 0.12, BlendMode = "ADD" },
  },

  Header = {
    Title = { Font = "Title" },
    -- Behind the title while the pointer is over it.
    TitleGlow = { Texture = "Glow", Color = "Gold", Alpha = 0.3, X = 24, Y = 14, BlendMode = "ADD" },
    -- The ribbon running from the title out of the window: a line and its glow, lines above and below
    -- it at an offset, fainter the further out ({ offset, alpha }).
    Ribbon = {
      Length = 300,
      Thickness = 2,
      Color = "Gold",
      BlendMode = "ADD",
      Glow = { { 0, 0.9 }, { 2, 0.35 }, { -2, 0.35 }, { 4, 0.15 }, { -4, 0.15 }, { 6, 0.06 }, { -6, 0.06 } },
    },
    -- What glides in along the ribbon every Motion.Time.ShimmerEvery seconds and settles into the
    -- title's cloud.
    Spark = { Texture = "Sparkle", Size = 26, Growth = 18, Color = "Gold", BlendMode = "ADD" },
    -- The cloud round the title the ribbon flows into: puffs of glow, no line anywhere. A puff sits a
    -- share F of the way across it from the ribbon's end, Y above the title's middle, W x H (W false:
    -- as wide as the cloud times Wide), in a palette color at alpha A. Each breathes, out of step:
    -- its alpha by Depth and its height by Drift. The shimmer swells the cloud by Swell and the Join
    -- puff (on the ribbon's end) by JoinSwell. SecretTitleWidth stands in for the title's width when
    -- the client will not say it (a vendor's name in an instance is secret).
    Cloud = {
      Texture = "Glow",
      BlendMode = "ADD",
      SecretTitleWidth = 160,
      Pad = 16, Swell = 0.6, JoinSwell = 0.45, Depth = 0.15, Drift = 1.5,
      Join = { Size = 34, Color = "Gold", A = 0.35 },
      Puffs = {
        { F = 0.45, Y = 0, W = false, Wide = 1.15, H = 60, Color = "Lavender", A = 0.09 },
        { F = 0.10, Y = 5, W = 54, H = 50, Color = "Gold", A = 0.24 },
        { F = 0.21, Y = -8, W = 50, H = 46, Color = "Gold", A = 0.2 },
        { F = 0.34, Y = 9, W = 60, H = 54, Color = "Lavender", A = 0.17 },
        { F = 0.48, Y = -7, W = 66, H = 56, Color = "Lavender", A = 0.16 },
        { F = 0.62, Y = 8, W = 58, H = 52, Color = "Lavender", A = 0.15 },
        { F = 0.77, Y = -6, W = 52, H = 46, Color = "Lavender", A = 0.12 },
        { F = 0.91, Y = 3, W = 42, H = 40, Color = "Lavender", A = 0.1 },
        { F = 0.16, Y = 17, W = 30, H = 26, Color = "Gold", A = 0.12 },
        { F = 0.28, Y = -19, W = 34, H = 30, Color = "Lavender", A = 0.11 },
        { F = 0.55, Y = 19, W = 38, H = 32, Color = "Lavender", A = 0.11 },
        { F = 0.70, Y = -18, W = 32, H = 28, Color = "Lavender", A = 0.09 },
      },
    },
    -- The header buttons' icons (next-themes.md §3). Icons gives each button its icon by its key (the
    -- size button by its state: sizeButtonFull, sizeButtonSmall): a Texture (one of Textures, or a
    -- file) with its TexCoords, or an Atlas (it wins over an inherited Texture). An icon is a glyph,
    -- white and one color, drawn in Color and brighter in HoverColor; Glyph = false makes it full-color
    -- art, drawn in ArtColor and ArtHoverColor (a tint multiplies the art: a dark one blackens it). An
    -- icon may have its own Color and HoverColor. A disabled button is drawn at DisabledAlpha of its
    -- color (a white glyph looks the same desaturated), art desaturated too.
    Buttons = { Color = "ButtonIcon", HoverColor = "White", ArtColor = "ButtonIcon", ArtHoverColor = "White",
      DisabledAlpha = 0.3,
      Icons = {
        settingsButton = { Texture = "IconSettings" },
        closeButton = { Texture = "IconClose" },
        sortButton = { Texture = "IconSort" },
        classicButton = { Texture = "IconBags" },
        sizeButtonFull = { Texture = "IconSmall" },
        sizeButtonSmall = { Texture = "IconFull" },
        bankTabsButton = { Texture = "IconBankTabs" },
        depositButton = { Texture = "IconDeposit" },
        depositGoldButton = { Texture = "IconDepositGold" },
        withdrawGoldButton = { Texture = "IconWithdrawGold" },
        filterButton = { Texture = "IconFilter" },
        sellJunkButton = { Texture = "IconSellJunk" },
        repairAllButton = { Texture = "IconRepair" },
        guildRepairButton = { Texture = "IconGuildRepair" },
      } },
  },

  Search = {
    Fill = "SearchFill",
    FocusFill = "SearchFillFocus",
    -- Its border, and how strong: idle, under the pointer or holding a search, focused.
    Edge = { Color = "Lavender", Size = 1, Idle = 0.3, Hover = 0.55, Focus = 1 },
    -- Its magnifier: idle, and under the pointer or holding a search; while focused, FocusColor.
    Icon = { Color = "Lavender", Idle = 0.85, Active = 1, FocusColor = "White" },
    HelpFont = "Search",
    TextFont = "SearchText",
  },

  Sections = {
    -- The title, from the section's top left; the count after it, and the line after the count.
    Title = { X = 2, Y = -4 },
    CountGap = 8,
    LineGap = 10,
    TitleFont = "Section",
    RecentFont = "SectionRecent",
    FreeFont = "SectionFree",
    CountFont = "Count",
    -- The line after a section's title and count, fading out (From and To are alphas of Color).
    Line = { Color = "Lavender", From = 0.35, To = 0, Size = 1 },
    -- Lit under a section's title row while the pointer is over it.
    Highlight = { Color = "Lavender", From = 0.12, To = 0 },
  },

  Tabs = {
    Fill = "Tab",
    SelectedFill = "TabSelected",
    -- A tab fades out toward its far end, to this share of its alpha.
    Fade = 0.35,
    Font = "Tab",
    SelectedFont = "TabSelected",
    -- Lit on a tab a dragged section would drop on (Drop), and flashing on one that received one
    -- (Pulse, fading from).
    Glow = { Color = "Lavender", BlendMode = "ADD", Drop = 0.3, Pulse = 0.8 },
    -- The bar beside the selected tab, in its accent (a Warbank or guild tab's), else Color.
    Indicator = { Color = "Gold", Width = 3 },
    Accents = { Warbank = "Warbank", Guild = "Guild" },
  },

  Footer = {
    -- Fading from Inner at the inner side to Outer at the screen-edge side.
    Line = { Color = "Lavender", Inner = 0.05, Outer = 0.35, Size = 1 },
    Font = "Footer",
    EmptyFont = "Empty",
    -- Gold written as text (the guild bank's; the bags' money frame is Blizzard's).
    MoneyFont = "Footer",
  },

  -- Sparkles: Texture and Colors (palette names) for every emitter; how a sparkle fades in and out
  -- (shares of its life), twinkles (speed, depth), shrinks and wobbles. Each emitter (false: none) is
  -- Rate a second, Max alive, Life, Size, Speed, Rise ({ least, most }), Wobble, Spin, Alpha. Ribbon
  -- sparkles are born up to Spread out along the ribbon; edge sparkles up to Reach out of the inner
  -- side; the knot bursts Burst of them as two bags couple.
  Sparkles = {
    Texture = "Sparkle",
    BlendMode = "ADD",
    Colors = { "Gold", "White", "Lavender" },
    FadeIn = 0.15,
    FadeOut = 0.4,
    TwinkleSpeed = 7,
    TwinkleDepth = 0.3,
    Shrink = 0.35,
    WobbleSpeed = 2.3,
    Cloud = { Rate = 3, Max = 10, Life = { 1.4, 2.6 }, Size = { 4, 9 }, Speed = { 3, 12 }, Rise = { -3, 5 },
      Wobble = 2, Spin = 1.2, Alpha = 0.7 },
    Ribbon = { Rate = 8, Max = 28, Life = { 2.0, 3.6 }, Size = { 6, 15 }, Speed = { 22, 64 }, Rise = { -8, 10 },
      Wobble = 4, Spin = 1.5, Alpha = 0.9, Spread = 70 },
    Edge = { Rate = 2.5, Max = 12, Life = { 2.4, 4.2 }, Size = { 4, 9 }, Speed = { 14, 36 }, Rise = { -6, 6 },
      Wobble = 3, Spin = 1, Alpha = 0.6, Reach = 24 },
    Knot = { Rate = 0, Max = 16, Life = { 0.5, 1.1 }, Size = { 4, 10 }, Speed = { 12, 40 }, Rise = { -16, 16 },
      Wobble = 2, Spin = 2, Alpha = 0.9, Burst = 12 },
  },

  -- Chaining the backpack and its companion (next.md §12): a chained bag comes in Stagger after an
  -- anchor still coming in; a companion waits up to AnchorWait for its anchor; TabMargin between the
  -- two tab rails; OuterFeather wide on a bag's far side away from its screen edge; CoupledFeather of
  -- the gap the inner feathers reach into. The braid: Segments lines per strand on each bag's half,
  -- Amplitude either side of the ribbon at the middle, Wavelength per turn, Turn radians a second,
  -- Thickness, Alpha in front (Depth less behind), in Color; Beads lights (BeadColor) running along it
  -- in BeadTime, BeadSize; the knot KnotSize, KnotAlpha, swelling by KnotSwell, in KnotColor.
  Chain = {
    -- The braid the two ribbons twist into as two bags couple (false: none).
    Braid = true,
    Stagger = 0.08,
    AnchorWait = 0.25,
    TabMargin = 24,
    OuterFeather = 48,
    CoupledFeather = 0.65,
    Segments = 16, Amplitude = 7, Wavelength = 64, Turn = 0.9, Thickness = 2, Alpha = 0.85, Depth = 0.5,
    Beads = 3, BeadTime = 1.6, BeadSize = 12,
    KnotSize = 30, KnotAlpha = 0.5, KnotSwell = 0.5,
    Color = "Gold",
    BeadColor = "Bead",
    KnotColor = "Gold",
  },

  -- Small mode (docs/next-small-mode.md): the panel's height (a share of the screen's), its beam and
  -- how far out along it its sparkles are born, its slide in and out, its margin from the screen edge
  -- until first moved; chaining by dropping a bag beside its partner: how close, how far apart their
  -- tops may be, and the least room between them.
  Small = {
    -- The grips on a small panel's bottom corners (next.md §14g): Blizzard's chat size grabber
    -- (FloatingChatFrame.xml's resize button), Size square, Inset in from the corner, mirrored on the
    -- left, seen only while the pointer is over one (ShowOnHover; false: at all times); and the least
    -- room a narrowed panel keeps for its title, cut short past that.
    Grip = {
      Size = 16,
      Inset = 2,
      ShowOnHover = true,
      Normal = { Texture = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up" },
      Highlight = { Texture = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight", BlendMode = "ADD" },
      Pushed = { Texture = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down" },
    },
    MinTitle = 60,
    Height = 0.66,
    Ribbon = 120,
    SparkSpread = 48,
    Slide = 24,
    Margin = 40,
    SnapReach = 80,
    SnapRise = 160,
    MinGap = 64,
  },

  -- Dragging a section: lifted to LiftScale, flying away down to FlyScale; its shadow, and the line
  -- naming what dropping does, Gap below it.
  Drag = {
    LiftScale = 0.94,
    FlyScale = 0.15,
    Shadow = { Color = "Black", Alpha = 0.35, Spread = 10 },
    HintFont = "DragHint",
    HintGap = 6,
  },

  -- A move waiting to be confirmed, docked in its target (next.md §7): the scrim over the target, the
  -- card (Pad inside, Top below the target's top), its glow edge pulsing from Low to High every
  -- Period seconds and its halo, and its lines.
  Dock = {
    -- Texture specs (Color, Texture, Atlas, ...), so a card can be art.
    Scrim = { Color = "Scrim" },
    Card = { Color = "Card" },
    Pad = 12,
    Top = 12,
    TitleHeight = 22,
    LineHeight = 16,
    Glow = { Color = "Gold", Width = 2, Low = 0.35, High = 1, Period = 1.2 },
    Halo = { Texture = "Glow", Color = "Gold", Spread = 28, Low = 0.15, High = 0.5, Period = 1.2, BlendMode = "ADD" },
    TitleFont = "ConfirmTitle",
    WarningFont = "ConfirmWarning",
    HintFont = "ConfirmHint",
  },

  -- The vendor's buttons: dimmed when a search leaves them out; lit under the pointer; tinted when
  -- unusable or sold out; the durability bar.
  Vendor = {
    -- The border round an item from Uncommon up, in its quality's color (false: none), and the mark
    -- on an item that starts a quest.
    QualityBorder = "Interface\\Common\\WhiteIconFrame",
    QuestMark = "Interface\\ContainerFrame\\UI-Icon-QuestBang",
    SearchDim = 0.25,
    Highlight = { 1, 1, 1, 0.15 },
    Unusable = "Unusable",
    SoldOutUnusable = "SoldOutUnusable",
    SoldOut = "SoldOut",
    PriceFont = "Price",
    UnaffordableFont = "PriceUnaffordable",
    StackFont = "Stack",
    DurabilityHeight = 3,
  },
})
