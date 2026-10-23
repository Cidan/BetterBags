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
    -- The controls (next-settings.md): a field's fill idle, under the pointer and pressed; a switch
    -- that is off and a slider's empty track; and a warning (a button that deletes).
    ControlFill = { 0.118, 0.101, 0.212, 1 },
    ControlHover = { 0.153, 0.131, 0.275, 1 },
    ControlPressed = { 0.094, 0.08, 0.17, 1 },
    Track = { 0.2, 0.18, 0.33, 1 },
    Danger = { 1, 0.45, 0.45, 1 },
    -- The vendor's destroy card's glow (Dock.DestroyColor, automation.md §4).
    Crimson = { 0.86, 0.08, 0.24, 1 },
    -- The settings window's sidebar, over its body: darker.
    Sidebar = { 0, 0, 0, 0.28 },
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
    -- The controls' glyphs: a dropdown's chevron, a menu's check, the search box's magnifier, a plus.
    IconChevron = "Interface\\AddOns\\BetterBags\\textures\\next\\icons\\chevron.png",
    IconBack = "Interface\\AddOns\\BetterBags\\textures\\next\\icons\\back.png",
    IconCheck = "Interface\\AddOns\\BetterBags\\textures\\next\\icons\\check.png",
    IconSearch = "Interface\\AddOns\\BetterBags\\textures\\next\\icons\\search.png",
    IconPlus = "Interface\\AddOns\\BetterBags\\textures\\next\\icons\\plus.png",
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
    Price = { Size = 13, Color = "White", Shadow = true },
    PriceUnaffordable = { Size = 13, Color = "Unaffordable", Shadow = true },
    -- A vendor item's name on its card (from Uncommon up, in its quality's color).
    VendorName = { Size = 13, Color = "Text", Shadow = true },
    -- A vendor item's stack count and stock: the bags' item count font (ItemButtonTemplate's Count,
    -- NumberFontNormal), copied (Object).
    Stack = { Object = "NumberFontNormal" },
    -- The controls: text in a field (and muted, for one that is off), a field's help while empty; a
    -- button's label, plain, primary and danger, and a link's; a menu's items (the chosen one); a
    -- dialog's title and text; a page's tabs (chosen, under the pointer).
    ControlText = { Size = 12, Color = "Text" },
    ControlMuted = { Size = 12, Color = "Muted" },
    ControlHelp = { Size = 12, Color = "Muted" },
    Button = { Size = 12, Color = "Text", Shadow = true },
    ButtonPrimary = { Size = 12, Color = "Gold", Shadow = true },
    ButtonDanger = { Size = 12, Color = "Danger", Shadow = true },
    Link = { Size = 12, Color = "Lavender" },
    LinkHover = { Size = 12, Color = "White" },
    MenuItem = { Size = 12, Color = "Text" },
    MenuItemSelected = { Size = 12, Color = "Gold" },
    DialogTitle = { Size = 16, Color = "White", Shadow = true },
    DialogText = { Size = 12, Color = "Text" },
    TopTab = { Size = 13, Color = "Muted" },
    TopTabHover = { Size = 13, Color = "Text" },
    TopTabSelected = { Size = 13, Color = "White", Shadow = true },
    -- The settings window (next-settings.md): the brand, the sidebar's headings and pages (under the
    -- pointer, chosen), the version; a page's title and description; a section's title and note; a
    -- setting's name; text on a page (a paragraph, "nothing found"); a search result's page.
    SettingsBrand = { Size = 20, Color = "White", Shadow = true },
    SettingsNavGroup = { Size = 11, Color = "Gold" },
    SettingsNav = { Size = 13, Color = "Muted" },
    SettingsNavHover = { Size = 13, Color = "Text" },
    SettingsNavSelected = { Size = 13, Color = "White", Shadow = true },
    SettingsVersion = { Size = 10, Color = "Muted" },
    SettingsTitle = { Size = 26, Color = "White", Shadow = true },
    SettingsDescription = { Size = 13, Color = "Muted" },
    SettingsSection = { Size = 11, Color = "Lavender" },
    SettingsSectionNote = { Size = 11, Color = "Muted" },
    SettingsLabel = { Size = 13, Color = "Text" },
    SettingsText = { Size = 12, Color = "Muted" },
    SettingsLink = { Size = 12, Color = "Gold" },
  },

  -- Sizes, in UI units.
  Layout = {
    -- Item icons; the vendor's cards across its full width (an item's name and price beside its
    -- icon, next.md §10b), and the room between an icon and its name and price; between icons; per row.
    Icon = 44,
    VendorColumns = 2,
    VendorTextGap = 8,
    -- How far a card's price sits up from its bottom edge.
    VendorPriceRaise = 3,
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
      -- A switch's knob sliding; a page's tab marker gliding to the tab chosen.
      Toggle = 0.18,
      TabMarker = 0.22,
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
      Toggle = "outCubic",
      TabMarker = "outCubic",
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
    -- color (a white glyph looks the same desaturated), art desaturated too. Scale is an icon's size
    -- as a share of its button (Layout.HeaderButton), centered in it; an icon's own Scale multiplies
    -- it (art that needs fitting). The buttons keep their size and places.
    Buttons = { Color = "ButtonIcon", HoverColor = "White", ArtColor = "ButtonIcon", ArtHoverColor = "White",
      DisabledAlpha = 0.3, Scale = 1,
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
    -- The vendor's destroy card (automation.md §4) is this card, its edge and halo in this color.
    DestroyColor = "Crimson",
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
    -- A card's name (two lines of it and a line of the price fit beside the icon), the coin icons in
    -- its price, its fill and the light over it under the pointer (false: none).
    NameFont = "VendorName",
    CoinSize = 13,
    CardFill = { 0.78, 0.72, 1, 0.05 },
    CardHover = { 1, 1, 1, 0.07 },
    StackFont = "Stack",
    DurabilityHeight = 3,
  },

  -- The settings window (next-settings.md): a page per entry down its sidebar, tabs across a page,
  -- sections of settings in two columns.
  Settings = {
    -- The window: Width x Height (scaled down to fit a small screen), its body, the wash at its top,
    -- its edge.
    Width = 1000, Height = 720,
    Fill = { Color = "Body" },
    Wash = { Color = "Wash", Height = 220, BlendMode = "ADD" },
    Edge = { Color = "Lavender", Alpha = 0.35, Size = 1 },
    -- Down its left: Width wide, Pad inside; its fill and the line along its inner side.
    Sidebar = { Width = 232, Pad = 16, Fill = { Color = "Sidebar" }, Line = { Color = "Lavender", Alpha = 0.15, Size = 1 } },
    -- At the sidebar's top: the bag glyph and "BetterBags", Height tall, the gold line fading out
    -- under them.
    Brand = {
      Height = 72, Icon = "IconBags", IconSize = 28, IconColor = "Gold", Gap = 10, Font = "SettingsBrand",
      Line = { Color = "Gold", From = 0.7, To = 0, Size = 1 },
    },
    -- The search box under the brand (Controls.Input), its magnifier IconSize, Gap below it.
    Search = { Icon = "IconSearch", IconSize = 14, IconColor = "Lavender", Gap = 14 },
    -- In place of the brand while a page's own list shows (a page's sidebar, next-settings.md §5): Back,
    -- its chevron IconSize, Gap before its text; the list slides in over Slide seconds.
    Back = {
      Icon = "IconBack", IconSize = 14, IconColor = "Lavender", Gap = 8, Font = "SettingsNav",
      HoverFont = "SettingsNavHover", Slide = 0.28,
    },
    -- The pages: their headings (GroupHeight tall, GroupGap above every one but the first), rows
    -- ItemHeight tall Indent in; the chosen page's bar and fill, the fill under the pointer; their fonts.
    Nav = {
      ItemHeight = 28, Indent = 14, GroupHeight = 24, GroupGap = 14,
      Indicator = { Color = "Gold", Width = 3 },
      SelectedFill = { Color = "Lavender", Alpha = 0.1 },
      HoverFill = { Color = "Lavender", Alpha = 0.05 },
      GroupFont = "SettingsNavGroup", Font = "SettingsNav", HoverFont = "SettingsNavHover",
      SelectedFont = "SettingsNavSelected",
    },
    -- At the sidebar's bottom: the version.
    Version = { Font = "SettingsVersion", Bottom = 14 },
    -- A page's header: Height tall, Pad in, the title TitleTop down and the description under it; the
    -- close button (a glyph, Size square, Inset from the window's top right corner).
    Header = {
      Height = 100, Pad = 32, TitleTop = 26, Gap = 6, TitleFont = "SettingsTitle", DescriptionFont = "SettingsDescription",
      Close = { Icon = "IconClose", Size = 22, Inset = 14, Color = "ButtonIcon", HoverColor = "White" },
      -- A page's actions (Rename, Delete): their top Top down, Gap left of the close button and right of
      -- the title.
      Actions = { Top = 22, Gap = 16 },
    },
    -- The page's tabs (Controls.TopTabs) under the header, Pad in.
    -- The page: Pad either side and Top above the first section; sections SectionGap apart, their
    -- titles TitleHeight above their card; a setting's row at least RowHeight tall, its name and its
    -- control RowPad in; two columns when the page is at least twice MinColumn wide. The card, the
    -- lines between rows and columns, the light under the pointer; the fonts.
    Content = {
      Pad = 32, Top = 18, Bottom = 24, SectionGap = 22, TitleHeight = 24, RowHeight = 44, RowPad = 14, MinColumn = 300,
      Card = { Color = "Lavender", Alpha = 0.035 },
      Divider = { Color = "Lavender", Alpha = 0.08, Size = 1 },
      Hover = { Color = "Lavender", Alpha = 0.05 },
      TitleFont = "SettingsSection", NoteFont = "SettingsSectionNote", LabelFont = "SettingsLabel",
      TextFont = "SettingsText", LinkFont = "SettingsLink",
    },
    -- The footer: Height tall, Pad in, the line along its top.
    Footer = { Height = 56, Pad = 24, Line = { Color = "Lavender", Alpha = 0.12, Size = 1 } },
    -- The Categories page (next-settings.md §5). Its list, in the sidebar: rows RowHeight tall (a name
    -- and a line of what is in it; headings GroupHeight), the name Indent in from the sidebar's Pad with
    -- its color's dot (Dot square) before it; the chosen one's bar and fill, the light under the
    -- pointer. Its tabs: Pad inside, rows FieldGap apart, names LabelWidth wide, the items' filter
    -- FilterWidth wide. The fonts.
    Categories = {
      RowHeight = 38, GroupHeight = 24, Indent = 12, Dot = 6,
      Indicator = { Color = "Gold", Width = 3 },
      SelectedFill = { Color = "Lavender", Alpha = 0.1 },
      HoverFill = { Color = "Lavender", Alpha = 0.05 },
      Pad = 18, FieldGap = 10, LabelWidth = 110, FilterWidth = 200,
      GroupFont = "SettingsSection", Font = "SettingsLabel", NoteFont = "SettingsSectionNote",
      LabelFont = "SettingsText", TextFont = "SettingsText", SectionFont = "SettingsSection",
      HintFont = "SettingsSectionNote",
    },
    -- A bag's categories, on its Categories tab: Height tall over its Fill, Pad inside; rows RowHeight
    -- tall (headings GroupHeight), Indent in; the light under the pointer; the fonts. A dragged row is
    -- lifted as a bag's section is (Drag).
    BagCategories = {
      Height = 420, Pad = 10, RowHeight = 30, GroupHeight = 24, Indent = 10,
      Fill = { Color = "Lavender", Alpha = 0.035 },
      HoverFill = { Color = "Lavender", Alpha = 0.05 },
      GroupFont = "SettingsSection", Font = "SettingsLabel", NoteFont = "SettingsSectionNote",
    },
    -- The classic bags' Currency page: headings HeaderHeight tall, currencies RowHeight tall with their
    -- icon IconSize square and Gap from their name; the fonts.
    Currency = {
      HeaderHeight = 26, RowHeight = 30, IconSize = 18, Gap = 8,
      GroupFont = "SettingsSection", NameFont = "SettingsLabel", TextFont = "SettingsText",
      Hover = { Color = "Lavender", Alpha = 0.05 },
    },
    -- Cards of a page's own (the themes): Height tall, at least MinWidth wide, Gap apart, Pad inside;
    -- their fill (under the pointer), edge (the one chosen), fonts, and each status's font.
    Cards = {
      Height = 78, MinWidth = 220, Gap = 10, Pad = 12,
      Fill = { Color = "Lavender", Alpha = 0.04 }, HoverFill = { Color = "Lavender", Alpha = 0.09 },
      Edge = { Color = "Lavender", Alpha = 0.18, Size = 1 }, SelectedEdge = { Color = "Gold", Alpha = 0.9, Size = 1 },
      NameFont = "SettingsLabel", TextFont = "SettingsText",
      ActiveFont = "SettingsLink", PreviewFont = "SettingsNavHover", UnavailableFont = "ControlMuted",
    },
  },

  -- BetterBags Next's controls (next-settings.md): every one is BetterBags' own, drawn from here. A
  -- fill is a texture spec (Color, Alpha; or a Texture or Atlas, tinted by Color), false for none; an
  -- edge is a Color, Alpha and Size (false: none).
  Controls = {
    -- The scroll bar of every Next scroll box (the bags' too): Width wide where it takes the mouse,
    -- Inset in from the box's right edge; the track and the thumb Size wide (HoverSize under the
    -- pointer or while dragged), the thumb at least MinThumb tall. An auto-hiding bar fades in over
    -- FadeIn while the pointer is over it or the box scrolls, stays Linger seconds, fades out over
    -- FadeOut.
    ScrollBar = {
      Width = 12, Inset = 1, Size = 4, HoverSize = 6, MinThumb = 24,
      Track = { Color = "Lavender", Alpha = 0.06 },
      Thumb = { Color = "Lavender", Alpha = 0.35 },
      ThumbHover = { Color = "Lavender", Alpha = 0.65 },
      ThumbDrag = { Color = "Gold", Alpha = 0.85 },
      FadeIn = 0.15, FadeOut = 0.3, Linger = 1,
    },
    -- A switch: its track off and on, its edge, its knob (KnobSize, KnobInset from the track's ends)
    -- off and on, and the light over it under the pointer.
    Toggle = {
      Width = 36, Height = 18, KnobSize = 12, KnobInset = 3,
      Off = { Color = "Track" },
      On = { Color = "Gold", Alpha = 0.9 },
      Edge = { Color = "Lavender", Alpha = 0.2, Size = 1 },
      Knob = { Color = "Lavender" },
      KnobOn = { Color = "White" },
      Hover = { Color = "White", Alpha = 0.08 },
    },
    -- Buttons: Height tall, Padding either side of the label, at least MinWidth; each style's fills
    -- idle, under the pointer and pressed, its edges idle and under the pointer, its font (HoverFont
    -- under the pointer, when set). A disabled button is drawn at DisabledAlpha.
    Button = {
      Height = 26, Padding = 16, MinWidth = 72, DisabledAlpha = 0.4,
      Plain = {
        Fill = { Color = "ControlFill" }, HoverFill = { Color = "ControlHover" }, PressedFill = { Color = "ControlPressed" },
        Edge = { Color = "Lavender", Alpha = 0.3, Size = 1 }, HoverEdge = { Color = "Lavender", Alpha = 0.6, Size = 1 },
        Font = "Button",
      },
      Primary = {
        Fill = { Color = "Gold", Alpha = 0.14 }, HoverFill = { Color = "Gold", Alpha = 0.24 },
        PressedFill = { Color = "Gold", Alpha = 0.08 },
        Edge = { Color = "Gold", Alpha = 0.6, Size = 1 }, HoverEdge = { Color = "Gold", Alpha = 1, Size = 1 },
        Font = "ButtonPrimary",
      },
      Danger = {
        Fill = { Color = "Danger", Alpha = 0.1 }, HoverFill = { Color = "Danger", Alpha = 0.2 },
        PressedFill = { Color = "Danger", Alpha = 0.06 },
        Edge = { Color = "Danger", Alpha = 0.5, Size = 1 }, HoverEdge = { Color = "Danger", Alpha = 0.9, Size = 1 },
        Font = "ButtonDanger",
      },
      Link = {
        Fill = false, HoverFill = false, PressedFill = false, Edge = false, HoverEdge = false,
        Font = "Link", HoverFont = "LinkHover",
      },
    },
    -- A text field and a text area: Height (a field's), Padding inside; their fill, focused; their
    -- edge, its strength idle, under the pointer and focused; their text and help fonts.
    Input = {
      Height = 26, Padding = 8,
      Fill = { Color = "ControlFill" }, FocusFill = { Color = "ControlHover" },
      Edge = { Color = "Lavender", Size = 1, Idle = 0.25, Hover = 0.5, Focus = 0.9 },
      Font = "ControlText", HelpFont = "ControlHelp",
    },
    -- A grid of item icons (next/controls/itemgrid.lua): cells Size square, Gap apart, Pad inside its
    -- fill and edge (an input's); an item's quality on its cell's edge, Common and Poor items the
    -- CommonEdge; an item showing in another category at DimAlpha; the light under the pointer; the
    -- count's font, and the text it shows when empty.
    ItemGrid = {
      Size = 36, Gap = 4, Pad = 6,
      CommonEdge = { Color = "Lavender", Alpha = 0.25, Size = 1 },
      DimAlpha = 0.35,
      Hover = { Color = "Lavender", Alpha = 0.18 },
      CountFont = "Stack", EmptyFont = "Empty",
    },
    -- A slider: its track Width wide and TrackSize thick, filled up to the thumb, the thumb (under
    -- the pointer or dragged: ThumbHover), and the number box ValueWidth wide, ValueGap after it.
    Slider = {
      Width = 120, Height = 18, TrackSize = 4, ThumbSize = 12, ValueWidth = 46, ValueGap = 10,
      Track = { Color = "Track" },
      Fill = { Color = "Gold", Alpha = 0.9 },
      Thumb = { Color = "Lavender" },
      ThumbHover = { Color = "White" },
    },
    -- A dropdown: its size, Padding inside, its fills (idle, under the pointer, open), its edge's
    -- strength the same way, its text, and its chevron.
    Dropdown = {
      Width = 170, Height = 26, Padding = 10,
      Fill = { Color = "ControlFill" }, HoverFill = { Color = "ControlHover" }, OpenFill = { Color = "ControlHover" },
      Edge = { Color = "Lavender", Size = 1, Idle = 0.25, Hover = 0.5, Open = 0.9 },
      Font = "ControlText",
      Chevron = { Texture = "IconChevron", Color = "Lavender", Size = 12 },
    },
    -- A menu of choices: its card and edge, Gap below what opened it, Padding inside, rows ItemHeight
    -- tall (MaxRows before it scrolls), the light under the pointer, its fonts, and the chosen row's
    -- check.
    Menu = {
      Gap = 2, Padding = 4, ItemHeight = 24, MaxRows = 12,
      Fill = { Color = "Card" },
      Edge = { Color = "Lavender", Alpha = 0.35, Size = 1 },
      HoverFill = { Color = "Lavender", Alpha = 0.14 },
      Font = "MenuItem", SelectedFont = "MenuItemSelected",
      Check = { Texture = "IconCheck", Color = "Gold", Size = 12 },
    },
    -- A color swatch: Size square, its edge idle and under the pointer.
    Swatch = {
      Size = 20,
      Edge = { Color = "White", Alpha = 0.45, Size = 1 },
      HoverEdge = { Color = "White", Alpha = 0.9, Size = 1 },
    },
    -- Tabs across a page: Height tall, Gap between labels, their fonts, the marker under the chosen
    -- one (Height thick), and the line under them all.
    TopTabs = {
      Height = 34, Gap = 28,
      Font = "TopTab", HoverFont = "TopTabHover", SelectedFont = "TopTabSelected",
      Indicator = { Color = "Gold", Height = 2 },
      Line = { Color = "Lavender", Alpha = 0.12, Size = 1 },
    },
    -- A dialog over a window: Width wide, Pad inside, Gap between its parts and ButtonGap between its
    -- buttons; the scrim behind it, its card and edge, its fonts.
    Dialog = {
      Width = 380, Pad = 20, Gap = 12, ButtonGap = 8,
      Scrim = { Color = "Scrim" },
      Card = { Color = "Card" },
      Edge = { Color = "Gold", Alpha = 0.45, Size = 1 },
      TitleFont = "DialogTitle", TextFont = "DialogText",
    },
  },
})
