local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- Make It So: BetterBags Next as a starship's computer (next-themes.md §24). Asked, to honor Patrick Stewart: "star trek
-- TNG themed, the bags obviously need the star trek beam down, and beam up animation for appearing and closing. star
-- trek comm badge is a part of the theme as well ... LCARS is an option, but maybe also holodeck too -- up to you, go
-- nuts", with "same amazing, incredible glam that we gave holloween, glitch, and frost themes".
--   Opening: it beams down (NextBeam): a column of pale blue light over where it rests, the transporter's shimmer
--     twinkling and rippling up and down through it, the bag glowing as it materializes under them; the shimmer goes
--     out after. The comm badge chirps, a glint across it, once it is there.
--   Closing: it beams up where it stands: lit, shimmering, fading out of the light, which goes out after it.
--   At rest: an LCARS frame: the side bar (lilac) curving into the top bar (orange) at an elbow, a segment of the bar
--     flickering as the computer works, a rounded end; another elbow (peach) into the bottom bar; the header's buttons
--     are the side bar's blocks, each in its own LCARS colour, its glyph at its end. The comm badge is its close button
--     (tap it to beam up), at the top outer corner. Behind the items, the holodeck's golden grid; in the feathered edge,
--     stars streaking past at warp, and now and then a jump to warp. Tabs and section headers are LCARS bars, their
--     names in black; sparkles are the transporter's flecks.
--   Display text in Antonio (fonts/makeitso, Vernon Adams, SIL Open Font License; a free face in the spirit of LCARS'
--     lettering; its Latin alphabets only, so other locales draw the client's font), the rest in the client's own.
-- Then, asked after the first look: "softer colors, maybe a bit more translucent in the title of each section, more..
-- modern a bit. i'll let you decide what this means". A pane of glass: LCARS' colours softened to pastels, the body a
-- translucent navy, the side bar glass with its blocks floating on it as rounded keys, a slimmer top and bottom bar, the
-- body's corners rounded (the inner ones as the elbows curve), sections and tabs on glass with their names in peach, the
-- chosen tab solid.
-- The palette redefines Default's names (Gold, Lavender, Text, Muted...) in LCARS orange, lilac and peach, so everything
-- this theme leaves to Default follows. Its art is tools/textures/next_makeitso.py's. Data only.
local FONTS = "Interface\\AddOns\\BetterBags\\fonts\\makeitso\\"
local TEXTURES = "Interface\\AddOns\\BetterBags\\textures\\next\\makeitso\\"
-- The locales whose alphabets Antonio covers (Latin: basic, Latin-1; checked against its character map).
local LATIN = { "enUS", "enGB", "deDE", "frFR", "esES", "esMX", "itIT", "ptBR" }

-- A role in Antonio, bold or semibold: its size and colour; black text on an LCARS bar has no shadow.
local function antonio(size, color, semibold)
  local role = { File = FONTS .. (semibold and "Antonio-SemiBold.ttf" or "Antonio-Bold.ttf"), Locales = LATIN,
    Size = size, Color = color }
  if color == "Black" then
    role.Shadow = false
  end
  return role
end

-- The side bar is 52 wide and its buttons 36 (Layout.HeaderButton): each button's block is drawn the bar's width
-- across (tools/textures/next_makeitso.py: the block 36 tall in the middle of its 52, a black band above and below).
local RAIL, BUTTON = 52, 36

-- The comm badge: larger than the close button it stands over (Layout.HeaderButton), centered on it.
local BADGE = 44
local OVER = (BADGE - BUTTON) / 2

-- A side bar button: its block, the light over it under the pointer.
local function block(name)
  return { Texture = "Block" .. name, Glyph = false, Scale = RAIL / BUTTON,
    Highlight = { Texture = "BlockLight", BlendMode = "ADD", Alpha = 0.35 } }
end

sonataNext:RegisterTheme({
  Name = "MakeItSo",
  DisplayName = "Make It So",
  Description = "A starship's computer: it beams in and out in a shimmer of light, LCARS panels frame it, a comm "
    .. "badge closes it, the holodeck's grid lies behind your items and stars streak past at warp.",

  Palette = {
    -- The holodeck's navy (holodeck.png's), as glass.
    Body = { 0.02, 0.025, 0.05, 0.9 },
    -- LCARS orange where Default is gold; lilac where it is lavender; peach for text.
    Gold = { 0.98, 0.7, 0.42, 1 },
    Lavender = { 0.78, 0.68, 0.9, 1 },
    Text = { 1, 0.9, 0.8, 1 },
    Muted = { 0.7, 0.66, 0.76, 1 },
    -- LCARS' colours, softened (tools/textures/next_makeitso.py draws its blocks in the same).
    LcarsOrange = { 0.98, 0.7, 0.42, 1 },
    LcarsPeach = { 1, 0.86, 0.72, 1 },
    LcarsLilac = { 0.78, 0.68, 0.9, 1 },
    LcarsBlue = { 0.62, 0.7, 1, 1 },
    LcarsSalmon = { 0.96, 0.66, 0.56, 1 },
    LcarsRed = { 0.88, 0.5, 0.52, 1 },
    Sky = { 0.66, 0.84, 1, 1 },
    -- Glass: the holodeck, the side bar behind its blocks, the tabs not chosen.
    HolodeckGlass = { 1, 1, 1, 0.9 },
    LilacGlass = { 0.78, 0.68, 0.9, 0.16 },
    TabGlass = { 0.78, 0.68, 0.9, 0.42 },
    -- The transporter's light.
    Transporter = { 0.62, 0.82, 1, 1 },
    Warbank = { 0.6, 0.8, 1, 1 },
    WarbankWash = { 0.6, 0.8, 1, 0.12 },
    Card = { 0.03, 0.035, 0.065, 0.95 },
    Scrim = { 0, 0, 0, 0.55 },
    SearchFill = { 0.06, 0.065, 0.1, 0.85 },
    SearchFillFocus = { 0.09, 0.09, 0.14, 0.95 },
    Shadow = { 0, 0, 0, 0.75 },
    ButtonIcon = { 1, 0.86, 0.72, 1 },
    Bead = { 1, 0.86, 0.72, 1 },
    -- The settings window's controls (next-settings.md §6): navy fields, a lavender track; soft red for what deletes.
    ControlFill = { 0.07, 0.075, 0.12, 1 },
    ControlHover = { 0.1, 0.105, 0.16, 1 },
    ControlPressed = { 0.05, 0.055, 0.09, 1 },
    Track = { 0.22, 0.2, 0.3, 1 },
    Danger = { 0.88, 0.5, 0.52, 1 },
    Crimson = { 0.86, 0.38, 0.4, 1 },
    Sidebar = { 0, 0, 0.02, 0.3 },
  },

  Textures = {
    Holodeck = TEXTURES .. "holodeck.png",
    ElbowTop = TEXTURES .. "elbow_top.png",
    ElbowBottom = TEXTURES .. "elbow_bottom.png",
    Cap = TEXTURES .. "cap.png",
    Solid = TEXTURES .. "solid.png",
    Blank = TEXTURES .. "blank.png",
    LcarsTab = TEXTURES .. "tab.png",
    SectionBar = TEXTURES .. "section_bar.png",
    BlockSettings = TEXTURES .. "block_settings.png",
    BlockSort = TEXTURES .. "block_sort.png",
    BlockBags = TEXTURES .. "block_bags.png",
    BlockSmall = TEXTURES .. "block_small.png",
    BlockFull = TEXTURES .. "block_full.png",
    BlockBankTabs = TEXTURES .. "block_banktabs.png",
    BlockDeposit = TEXTURES .. "block_deposit.png",
    BlockDepositGold = TEXTURES .. "block_depositgold.png",
    BlockWithdrawGold = TEXTURES .. "block_withdrawgold.png",
    BlockFilter = TEXTURES .. "block_filter.png",
    BlockSellJunk = TEXTURES .. "block_selljunk.png",
    BlockRepair = TEXTURES .. "block_repair.png",
    BlockGuildRepair = TEXTURES .. "block_guildrepair.png",
    BlockLight = TEXTURES .. "block_light.png",
    CommBadge = TEXTURES .. "comm_badge.png",
    BadgeLight = TEXTURES .. "badge_light.png",
    Glint = TEXTURES .. "glint.png",
    Column = TEXTURES .. "column.png",
    BodyGlow = TEXTURES .. "body_glow.png",
    Streak = TEXTURES .. "streak.png",
  },

  Fonts = {
    Title = antonio(32, "LcarsOrange"),
    -- Section names in peach on their bars' glass, counts in lavender; tabs' names in peach on glass, the chosen one's in
    -- black on its solid bar.
    Section = antonio(15, "LcarsPeach"),
    SectionRecent = antonio(15, "LcarsPeach"),
    SectionFree = antonio(15, "LcarsPeach"),
    Count = antonio(13, "LcarsLilac", true),
    Tab = antonio(15, "LcarsPeach", true),
    TabSelected = antonio(15, "Black", true),
    Footer = { Color = "LcarsPeach" },
    Empty = antonio(22, "LcarsPeach"),
    ConfirmTitle = antonio(20, "LcarsOrange"),
    Search = { Color = "Muted" },
    SearchText = { Color = "Text" },
    DialogTitle = antonio(22, "LcarsOrange"),
    SettingsBrand = antonio(28, "LcarsOrange"),
    SettingsTitle = antonio(30, "LcarsOrange"),
    SettingsNavGroup = antonio(13, "LcarsLilac", true),
    SettingsSection = antonio(14, "LcarsLilac", true),
  },

  Layout = {
    -- The side bar's buttons (its blocks), and the footer's text clear of the bottom bar; a section's header taller than
    -- its bar (Sections.Header.Height), room under it before the first row of icons.
    HeaderButton = BUTTON,
    TitleTop = 26,
    FooterText = 20,
    FooterMoney = 18,
    SectionHeader = 28,
  },

  Panel = {
    -- The holodeck's grid behind the items, repeating, as glass.
    Fill = { Texture = "Holodeck", Color = "HolodeckGlass", HorizTile = true, VertTile = true },
    Feather = { Color = "Body" },
    Wash = false,
    -- No border: its corners are rounded (Corners), where straight lines would stop short; the frame and the glass mark
    -- its edges.
    Edge = false,
    DropGlow = { Color = "LcarsOrange", Alpha = 0.16, BlendMode = "ADD" },
    -- A small bag's inner corners rounded (asked: "corner at the top left and bottom left peak out around the LCARS, i
    -- think we need a way to shape the window itself"), as round as the elbows' outer corners
    -- (tools/textures/next_makeitso.py: TOP_ROUND, BOTTOM_ROUND), so nothing of the body shows past them. Its outer ones
    -- square: the client masks the body's fill at most three times.
    Corners = { TOPINNER = 30, BOTTOMINNER = 24 },
    -- The LCARS frame, drawn for the backpack (its inner side on the left) and mirrored on the panels across the screen:
    -- the side bar (Header.Buttons.Rail, 52 wide) curving into the slim top bar (10 tall) at the top elbow, then a
    -- segment flickering, the bar on to its rounded end short of the comm badge; the bottom elbow into the bottom bar (8
    -- tall). A small bag can be as narrow as 216, where the top bar beyond its elbow would run into the elbow and the
    -- badge: it keeps its elbows, its bottom bar and the badge.
    Ornaments = {
      { Texture = "ElbowTop", Point = "TOPINNER", Width = 150, Height = 66, Color = "LcarsOrange", Layer = "ARTWORK",
        SubLevel = 2 },
      { Texture = "Solid", Point = "TOPINNER", Width = 40, Height = 10, X = 154, Color = "LcarsLilac",
        Layer = "ARTWORK", SubLevel = 2, Sizes = "Full", Motion = { Flicker = { Low = 0.55, Speed = 2.5 } } },
      { Texture = "Solid", Point = "TOP", Height = 10, Start = 198, End = 70, Color = "LcarsOrange", Layer = "ARTWORK",
        SubLevel = 2, Sizes = "Full" },
      { Texture = "Cap", Point = "TOPOUTER", Width = 10, Height = 10, X = 60, Color = "LcarsOrange", Layer = "ARTWORK",
        SubLevel = 2, Sizes = "Full" },
      { Texture = "ElbowBottom", Point = "BOTTOMINNER", Width = 150, Height = 40, Color = "LcarsPeach",
        Layer = "ARTWORK", SubLevel = 2 },
      { Texture = "Solid", Point = "BOTTOM", Height = 8, Start = 154, End = 36, Color = "LcarsSalmon",
        Layer = "ARTWORK", SubLevel = 2 },
      { Texture = "Cap", Point = "BOTTOMOUTER", Width = 8, Height = 8, X = 28, Color = "LcarsSalmon",
        Layer = "ARTWORK", SubLevel = 2 },
      -- The comm badge, larger than the close button pinned under it and centered on it (its own icon blank, its light
      -- the badge's): over the content, a glint flashing across it once the bag has beamed in, and now and then after.
      { Texture = "CommBadge", Point = "TOPOUTER", Width = BADGE, Height = BADGE, X = 12 - OVER, Y = 6 - OVER,
        Above = true, Layer = "OVERLAY", SubLevel = 2 },
      { Texture = "Glint", Point = "TOPOUTER", Width = 36, Height = 36, X = 12 - OVER + (BADGE - 36) / 2,
        Y = 6 - OVER + (BADGE - 36) / 2, Above = true, Layer = "OVERLAY", SubLevel = 3, BlendMode = "ADD", Alpha = 0.95,
        Motion = { Flash = { Every = { 7, 13 }, Time = 0.5, First = 0.85 } } },
    },
    -- Beaming in and out (NextBeam; asked: "the bags obviously need the star trek beam down, and beam up animation for
    -- appearing and closing ... most important part is beam down/beam up"). Down: the column and the shimmer come up
    -- over where it rests, the bag glowing as it materializes under them, there by 0.72 seconds (a bank waits for its
    -- panel to have shown before it loads, 1 second at most); the light goes out after. Up: lit and shimmering, it
    -- fades out of the light by 0.65 seconds, which goes out after it. Appearance > Animation > Transporter turns it
    -- off. It covers the window and Margin past it all round, and runs Ends past that above and below, fading out there
    -- (asked: "make sure it covers the window + it's decoration fully", "leave tabs out", and "the top and bottom beam are
    -- cut off extremely clean on the horizontal plane, almost like it's clipped at the top and bottom").
    Beam = {
      Margin = 24,
      Ends = 64,
      Sparkles = { Texture = "Glint", Colors = { "White", "Transporter", "Transporter", "LcarsPeach" }, Density = 2.6,
        Size = { 6, 13 }, Stretch = 1.8, Alpha = { 0.55, 1 }, BlendMode = "ADD", Twinkle = { 3, 9 }, Sharpness = 3,
        Drift = { 20, 70 }, Spread = 8 },
      Column = { Texture = "Column", Color = "Transporter", Alpha = 0.55, BlendMode = "ADD", Spread = 24,
        Shimmer = { 0.25, 5 }, Scroll = 0.8 },
      Glow = { Texture = "BodyGlow", Color = "Transporter", Alpha = 0.7, BlendMode = "ADD" },
      Open = { Reveal = { 0.32, 0.72 }, Sparkles = { 0, 0.18, 0.6, 1.15 }, Column = { 0, 0.2, 0.55, 1.05 },
        Glow = { 0.15, 0.45, 0.6, 0.95 } },
      Close = { Fade = { 0.3, 0.65 }, Sparkles = { 0, 0.15, 0.6, 1.05 }, Column = { 0.05, 0.25, 0.6, 1 },
        Glow = { 0, 0.3, 0.5, 0.8 } },
    },
    -- Stars at warp (NextSnow): streaks and specks drifting out of the feathered edge into the world, at three speeds,
    -- and now and then a jump to warp, the stars blown past and streaks sweeping across. Appearance > Animation > Snow,
    -- Leaves and Stars turns them off.
    Snow = {
      Flakes = {
        { Where = "Feather", Texture = "Streak", Count = 8, Size = { 24, 48 }, Fall = { 0, 0 }, Drift = 160,
          Wobble = { 0, 0 }, Spin = 0, Alpha = { 0.4, 0.85 }, Colors = { "White", "Sky" }, BlendMode = "ADD" },
        { Where = "Feather", Texture = "Streak", Count = 8, Size = { 12, 24 }, Fall = { 0, 0 }, Drift = 70,
          Wobble = { 0, 0 }, Spin = 0, Alpha = { 0.3, 0.7 }, Colors = { "White", "LcarsPeach" }, BlendMode = "ADD" },
        { Where = "Feather", Texture = "Glint", Count = 10, Size = { 4, 8 }, Fall = { 0, 0 }, Drift = 18,
          Wobble = { 0, 0 }, Spin = 0, Alpha = { 0.35, 0.9 }, Colors = { "White", "Sky" }, BlendMode = "ADD" },
      },
      Gusts = { Every = 30, Time = 2.2, Strength = 600,
        Streaks = { Texture = "Streak", Count = 7, Length = { 140, 280 }, Thickness = { 3, 6 }, Alpha = 0.3,
          Color = "Sky", BlendMode = "ADD", Tilt = 0 } },
    },
  },

  Header = {
    TitleGlow = { Texture = "Glow", Color = "LcarsOrange", Alpha = 0.16, X = 24, Y = 14, BlendMode = "ADD" },
    -- An orange line out of the window, a fleck of the transporter's light gliding in along it; no cloud: LCARS' text
    -- stands on black.
    Ribbon = { Length = 300, Thickness = 2, Color = "LcarsOrange", BlendMode = "ADD",
      Glow = { { 0, 0.9 }, { 2, 0.3 }, { -2, 0.3 }, { 4, 0.1 }, { -4, 0.1 } } },
    Spark = { Texture = "Glint", Size = 22, Growth = 8, Color = "Transporter", BlendMode = "ADD" },
    Cloud = false,
    -- The header's buttons down the side bar, each its LCARS block floating on the bar's glass; the close button pinned
    -- at the top outer corner, under the comm badge (Panel.Ornaments).
    Buttons = {
      ArtColor = "White", ArtHoverColor = "White", DisabledAlpha = 0.35,
      Rail = { Width = RAIL, Top = 70, Gap = 4, Start = 66, Fill = { Color = "LilacGlass" } },
      Pinned = { closeButton = { Point = "TOPOUTER", X = -12, Y = -6 } },
      Icons = {
        settingsButton = block("Settings"),
        closeButton = { Texture = "Blank", Glyph = false,
          Highlight = { Texture = "BadgeLight", BlendMode = "ADD", Alpha = 0.6 } },
        sortButton = block("Sort"),
        bagsButton = block("Bags"),
        sizeButtonFull = block("Small"),
        sizeButtonSmall = block("Full"),
        bankTabsButton = block("BankTabs"),
        depositButton = block("Deposit"),
        depositGoldButton = block("DepositGold"),
        withdrawGoldButton = block("WithdrawGold"),
        filterButton = block("Filter"),
        sellJunkButton = block("SellJunk"),
        repairAllButton = block("Repair"),
        guildRepairButton = block("GuildRepair"),
      },
    },
  },

  Search = {
    Edge = { Color = "LcarsLilac", Size = 1, Idle = 0.35, Hover = 0.6, Focus = 0.9 },
    Icon = { Color = "LcarsPeach", Idle = 0.8, Active = 1, FocusColor = "LcarsOrange" },
  },

  -- Each section's header an LCARS bar of glass (tools/textures/next_makeitso.py: a solid rounded tip, then glass fading
  -- along the section), its name in peach over the glass; 20 tall, in a header 28 tall (Layout.SectionHeader), room
  -- between it and the first row of icons (reported: the title "is overlaping with the first icon row").
  Sections = {
    Title = { X = 24, Y = -3 },
    Header = { Texture = "SectionBar", Color = "LcarsLilac", Height = 20 },
    Line = false,
    Highlight = { Color = "LcarsPeach", From = 0.12, To = 0 },
  },

  -- Tabs as LCARS bars of glass, rounded where they stick out; the chosen one solid apricot.
  Tabs = {
    Fill = { Texture = "LcarsTab", Color = "TabGlass" },
    SelectedFill = { Texture = "LcarsTab", Color = "LcarsOrange" },
    Indicator = false,
    Glow = { Color = "LcarsPeach", BlendMode = "ADD", Drop = 0.35, Pulse = 0.8 },
  },

  Footer = {
    Line = false,
  },

  -- The transporter's flecks for sparkles; none in a cloud the title has not got.
  Sparkles = {
    Texture = "Glint",
    BlendMode = "ADD",
    Colors = { "Transporter", "White", "LcarsPeach" },
    Cloud = false,
  },

  Chain = { Color = "LcarsOrange", BeadColor = "LcarsPeach", KnotColor = "Transporter" },

  Dock = {
    Glow = { Color = "LcarsOrange" },
  },

  Currency = {
    Bar = { Fill = { Color = "LcarsOrange", Alpha = 0.85 } },
    Drop = { Color = "LcarsOrange", Alpha = 0.4 },
    Slot = { Color = "LcarsPeach" },
  },

  -- The settings window on the holodeck's black, its marks in LCARS orange.
  Settings = {
    Wash = false,
    Edge = { Color = "LcarsLilac", Alpha = 0.35 },
    Brand = { IconColor = "LcarsOrange", Line = { Color = "LcarsOrange" } },
    Nav = { Indicator = { Color = "LcarsOrange" } },
  },

  Vendor = {
    Highlight = { 1, 0.86, 0.72, 0.12 },
  },

  -- Item buttons as navy cells on the grid, a soft lavender edge, an item's quality on its icon's border.
  ItemButton = {
    Icon = { Inset = 1, TexCoords = { 0.08, 0.92, 0.08, 0.92 } },
    Backdrop = { Color = { 0.04, 0.045, 0.08, 0.9 }, BorderColor = { 0.78, 0.68, 0.9, 0.3 }, EdgeSize = 1 },
    Highlight = { Color = { 1, 0.86, 0.72, 0.16 } },
    Pushed = { Color = { 0.98, 0.7, 0.42, 0.22 } },
  },
})
