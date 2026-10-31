local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- Papercraft: BetterBags Next as a sheet of paper taped to the screen (next-themes.md §25). Asked: "the open animation
-- should be the bags 'unfolding' in two parts (1/4th square, unfold into half, unfold into full), and the close animation
-- should it being crumbled up like a paper ball and being tossed up slightly, then falling off the screen. the text
-- should all look like it's hand drawn, and the paper should be a soft color. elements should look like they are 'taped
-- on' and held together ... it's okay to have little doodles too in the paper at the margins. here's the trick for this
-- one: the animations? should be stop-motion esque. meaning they are not just staggered in that stop motion FPS, but
-- imperfect in their placement from frame to frame."
--   Opening: a folded note with a backpack drawn on it drops into place, unfolds across one fold and then the other, a
--     pose at a time, and the bag's things appear on the sheet (NextPaper). Closing: it is grabbed, crumpled up with its
--     items printed on it into a ball, tossed up a little, and falls off the screen, tumbling (NextPaper).
--   Every animation runs at twelve poses a second, each landing a little off where it should be (Motion.StopMotion,
--     NextStopMotion), and the doodles' lines boil, drawn again a little differently each pose (an ornament's Boil).
--   At rest: soft cream paper with the creases its folds left, torn edges with a pale fibrous lip, washi tape holding it
--     and its tabs on, section names over a highlighter's streak and followed by a pencil line, items mounted on squares
--     of lighter paper with their quality in coloured pencil, a cat, a sprig, a sun and a note in the margins.
--   Text in Caveat (titles, sections) and Patrick Hand (the rest; fonts/papercraft, SIL Open Font License); their alphabets
--     are Latin (Caveat's Cyrillic too), so other locales draw the client's font.
-- The palette redefines Default's names (Gold a red pencil, Lavender a blue one, Text and Muted dark ink), so everything
-- this theme leaves to Default follows. Its art is tools/textures/next_papercraft.py's. Data only.
local FONTS = "Interface\\AddOns\\BetterBags\\fonts\\papercraft\\"
local TEXTURES = "Interface\\AddOns\\BetterBags\\textures\\next\\papercraft\\"
local CAVEAT = FONTS .. "Caveat-Bold.ttf"
local PATRICK = FONTS .. "PatrickHand-Regular.ttf"
-- The locales whose alphabets each covers (checked against their character maps).
local LATIN = { "enUS", "enGB", "deDE", "frFR", "esES", "esMX", "itIT", "ptBR" }
local LATIN_CYRILLIC = { "enUS", "enGB", "deDE", "frFR", "esES", "esMX", "itIT", "ptBR", "ruRU" }
-- Notes written in English in the margins.
local ENGLISH = { "enUS", "enGB" }

-- A role in Caveat: the display hand, for titles and section names.
local function script(size, color)
  return { File = CAVEAT, Locales = LATIN_CYRILLIC, Size = size, Color = color, Shadow = false }
end

-- A role in Patrick Hand: everything else.
local function hand(size, color)
  return { File = PATRICK, Locales = LATIN, Size = size, Color = color, Shadow = false }
end

-- A piece of washi tape, in its colour, over what it holds (Above: over the panel's content and frame).
local function tape(art, color, point, x, y, width, height, sizes)
  return { Texture = art, Color = color, Point = point, X = x, Y = y, Width = width, Height = height, Sizes = sizes,
    Above = true, Layer = "OVERLAY", SubLevel = 1 }
end

-- A doodle in the margin: a strip of Frames drawings of it, boiling (next-themes.md §12), under everything else.
local function doodle(art, color, alpha, point, x, y, size, sizes, locales)
  return { Texture = art, Frames = 3, Color = color, Alpha = alpha, Point = point, X = x, Y = y, Width = size,
    Height = size, Sizes = sizes, Locales = locales, Layer = "ARTWORK", SubLevel = 1,
    Motion = { Boil = { FPS = 6, Jiggle = 0.6 } } }
end

-- The torn edge a sheet of it has, for the frame round each one (next-themes.md §15): the art reaches 26 outside what it
-- frames and 6 into it, where it fades into the sheet. Tiled along each side, flipped for the far sides.
local function tornFrame()
  local SIDE, TOP, CORNER = "PaperEdgeSide", "PaperEdgeTop", "PaperCorner"
  return {
    SubLevel = 3,
    Pieces = {
      TopLeftCorner = { Texture = CORNER, Width = 32, Height = 32, X = -26, Y = 26 },
      TopRightCorner = { Texture = CORNER, Width = 32, Height = 32, X = 26, Y = 26, TexCoords = { 1, 0, 0, 1 } },
      BottomLeftCorner = { Texture = CORNER, Width = 32, Height = 32, X = -26, Y = -26, TexCoords = { 0, 1, 1, 0 } },
      BottomRightCorner = { Texture = CORNER, Width = 32, Height = 32, X = 26, Y = -26, TexCoords = { 1, 0, 1, 0 } },
      TopEdge = { Texture = TOP, Height = 32, HorizTile = true },
      BottomEdge = { Texture = TOP, Height = 32, HorizTile = true, TexCoords = { 0, 1, 1, 0 } },
      LeftEdge = { Texture = SIDE, Width = 32, VertTile = true },
      RightEdge = { Texture = SIDE, Width = 32, VertTile = true, TexCoords = { 1, 0, 0, 1 } },
    },
  }
end

-- A control in its art: its pencil outline in three pieces, whatever its width.
local function outlined(file, color, alpha)
  return { Pieces = "Horizontal", Color = color, Alpha = alpha,
    Begin = { Texture = file, TexCoords = { 0, 12 / 128, 0, 1 }, Size = 12 },
    Middle = { Texture = file, TexCoords = { 12 / 128, 116 / 128, 0, 1 } },
    End = { Texture = file, TexCoords = { 116 / 128, 1, 0, 1 }, Size = 12 } }
end

sonataNext:RegisterTheme({
  Name = "Papercraft",
  DisplayName = "Papercraft",
  Description = "A sheet of soft paper taped to your screen: it unfolds a fold at a time, crumples into a ball and falls "
    .. "off the screen, all in stop motion, with hand-drawn lettering and doodles in the margins.",

  Palette = {
    -- The paper (body.png's own colour), and a sheet a little lighter for what sits on it.
    Body = { 0.925, 0.885, 0.805, 1 },
    Paper = { 0.925, 0.885, 0.805, 1 },
    PaperLight = { 0.975, 0.955, 0.895, 1 },
    PaperShade = { 0.862, 0.815, 0.725, 1 },
    Wash = { 0, 0, 0, 0 },
    -- Ink for lines and text; a red pencil where Default is gold; a blue one where it is lavender.
    Ink = { 0.18, 0.16, 0.14, 1 },
    InkSoft = { 0.33, 0.29, 0.25, 1 },
    InkMuted = { 0.48, 0.43, 0.36, 1 },
    Text = { 0.18, 0.16, 0.14, 1 },
    Muted = { 0.48, 0.43, 0.36, 1 },
    Gold = { 0.77, 0.27, 0.23, 1 },
    Lavender = { 0.3, 0.48, 0.71, 1 },
    PencilRed = { 0.77, 0.27, 0.23, 1 },
    PencilBlue = { 0.3, 0.48, 0.71, 1 },
    Leaf = { 0.25, 0.38, 0.25, 1 },
    Sun = { 0.86, 0.63, 0.22, 1 },
    Heart = { 0.85, 0.42, 0.47, 1 },
    Highlighter = { 0.96, 0.86, 0.47, 1 },
    -- Washi tape.
    TapeTan = { 0.8, 0.7, 0.52, 1 },
    TapeBlue = { 0.56, 0.71, 0.86, 1 },
    TapePink = { 0.9, 0.63, 0.6, 1 },
    Twine = { 0.55, 0.42, 0.27, 1 },
    Warbank = { 0.3, 0.55, 0.7, 1 },
    WarbankWash = { 0, 0, 0, 0 },
    Guild = { 0.25, 0.52, 0.28, 1 },
    GuildWash = { 0, 0, 0, 0 },
    Tab = { 0.925, 0.885, 0.805, 1 },
    TabSelected = { 0.975, 0.955, 0.895, 1 },
    Card = { 0.925, 0.885, 0.805, 1 },
    Scrim = { 0.1, 0.08, 0.06, 0.35 },
    SearchFill = { 0.975, 0.955, 0.895, 0.5 },
    SearchFillFocus = { 0.975, 0.955, 0.895, 0.9 },
    Shadow = { 0, 0, 0, 0 },
    ButtonIcon = { 0.18, 0.16, 0.14, 1 },
    Art = { 1, 1, 1, 1 },
    Bead = { 0.55, 0.42, 0.27, 1 },
    -- The settings window's controls (next-settings.md §6): fields a lighter paper, a darker one pressed.
    ControlFill = { 0.975, 0.955, 0.895, 1 },
    ControlHover = { 1, 0.985, 0.94, 1 },
    ControlPressed = { 0.9, 0.86, 0.78, 1 },
    Track = { 0.48, 0.43, 0.36, 1 },
    Danger = { 0.72, 0.2, 0.18, 1 },
    Crimson = { 0.77, 0.27, 0.23, 1 },
    Emerald = { 0.25, 0.52, 0.28, 1 },
    Sidebar = { 0.18, 0.16, 0.14, 0.04 },
    Gain = { 0.2, 0.5, 0.22, 1 },
    Capped = { 0.72, 0.2, 0.18, 1 },
    Unaffordable = { 0.72, 0.2, 0.18, 1 },
  },

  Textures = {
    PaperBody = TEXTURES .. "body.png",
    PaperBack = TEXTURES .. "back.png",
    PaperEdgeSide = TEXTURES .. "edge_side.png",
    PaperEdgeTop = TEXTURES .. "edge_top.png",
    PaperCorner = TEXTURES .. "corner.png",
    PaperEdgeRun = TEXTURES .. "edge_run.png",
    Creases = TEXTURES .. "creases.png",
    PaperShadow = TEXTURES .. "shadow.png",
    TabScrap = TEXTURES .. "tab.png",
    TabScrapChosen = TEXTURES .. "tab_selected.png",
    TapeFlat = TEXTURES .. "tape_flat.png",
    TapeLeft = TEXTURES .. "tape_left.png",
    TapeRight = TEXTURES .. "tape_right.png",
    TapeCorner = TEXTURES .. "tape_corner.png",
    PencilLine = TEXTURES .. "pencil_line.png",
    Underline = TEXTURES .. "underline.png",
    Swash = TEXTURES .. "swash.png",
    Marker = TEXTURES .. "marker.png",
    Field = TEXTURES .. "field.png",
    OutlineButton = TEXTURES .. "button.png",
    OutlineFill = TEXTURES .. "button_fill.png",
    CheckBox = TEXTURES .. "check_box.png",
    CheckMark = TEXTURES .. "check_mark.png",
    Thumb = TEXTURES .. "thumb.png",
    ScrollThumb = TEXTURES .. "scroll_thumb.png",
    ScrollTrack = TEXTURES .. "scroll_track.png",
    GripArt = TEXTURES .. "grip.png",
    ItemMount = TEXTURES .. "item_mount.png",
    Confetti = TEXTURES .. "confetti.png",
    DoodleCat = TEXTURES .. "doodle_cat.png",
    DoodleHeart = TEXTURES .. "doodle_heart.png",
    DoodleSprig = TEXTURES .. "doodle_sprig.png",
    DoodleSmile = TEXTURES .. "doodle_smile.png",
    DoodleSun = TEXTURES .. "doodle_sun.png",
    DoodleStar = TEXTURES .. "doodle_star.png",
    DoodlePlane = TEXTURES .. "doodle_plane.png",
    DoodleMug = TEXTURES .. "doodle_mug.png",
    DoodleBag = TEXTURES .. "doodle_bag.png",
    NoteNeed = TEXTURES .. "note_need.png",
    NoteLight = TEXTURES .. "note_light.png",
    NoteTime = TEXTURES .. "note_time.png",
    NoteName = TEXTURES .. "note_name.png",
    -- The glyphs, drawn by hand: what every button and control draws them with.
    IconSettings = TEXTURES .. "icon_settings.png",
    IconClose = TEXTURES .. "icon_close.png",
    IconSort = TEXTURES .. "icon_sort.png",
    IconBags = TEXTURES .. "icon_bags.png",
    IconSmall = TEXTURES .. "icon_small.png",
    IconFull = TEXTURES .. "icon_full.png",
    IconBankTabs = TEXTURES .. "icon_banktabs.png",
    IconDeposit = TEXTURES .. "icon_deposit.png",
    IconDepositGold = TEXTURES .. "icon_depositgold.png",
    IconWithdrawGold = TEXTURES .. "icon_withdrawgold.png",
    IconFilter = TEXTURES .. "icon_filter.png",
    IconSellJunk = TEXTURES .. "icon_selljunk.png",
    IconRepair = TEXTURES .. "icon_repair.png",
    IconGuildRepair = TEXTURES .. "icon_guildrepair.png",
    IconChevron = TEXTURES .. "icon_chevron.png",
    IconBack = TEXTURES .. "icon_back.png",
    IconCheck = TEXTURES .. "icon_check.png",
    IconSearch = TEXTURES .. "icon_search.png",
    IconPlus = TEXTURES .. "icon_plus.png",
  },

  FontShadow = { Color = "Shadow", X = 0, Y = 0 },
  Fonts = {
    Title = script(40, "Ink"),
    Section = script(24, "Ink"),
    SectionRecent = script(24, "PencilRed"),
    SectionFree = script(22, "InkMuted"),
    Count = hand(14, "InkMuted"),
    Tab = hand(15, "InkSoft"),
    TabSelected = hand(15, "Ink"),
    Footer = hand(15, "InkSoft"),
    Empty = script(26, "InkMuted"),
    DragHint = script(22, "Ink"),
    ConfirmTitle = script(26, "Ink"),
    ConfirmWarning = hand(15, "PencilRed"),
    ConfirmHint = hand(15, "InkSoft"),
    Search = hand(15, "InkMuted"),
    SearchText = hand(15, "Ink"),
    Price = hand(14, "Ink"),
    PriceUnaffordable = hand(14, "Danger"),
    VendorName = hand(14, "Ink"),
    -- The numbers over item icons, on their icons: white, outlined.
    Stack = { File = PATRICK, Locales = LATIN, Size = 15, Color = "White", Flags = "OUTLINE" },
    ControlText = hand(15, "Ink"),
    ControlMuted = hand(15, "InkMuted"),
    ControlHelp = hand(15, "InkMuted"),
    Button = hand(15, "Ink"),
    ButtonPrimary = hand(15, "Ink"),
    ButtonDanger = hand(15, "Danger"),
    Link = hand(15, "PencilBlue"),
    LinkHover = hand(15, "Ink"),
    MenuItem = hand(15, "Ink"),
    MenuItemSelected = hand(15, "PencilBlue"),
    DialogTitle = script(28, "Ink"),
    DialogText = hand(15, "InkSoft"),
    TopTab = hand(16, "InkMuted"),
    TopTabHover = hand(16, "InkSoft"),
    TopTabSelected = hand(16, "Ink"),
    SettingsBrand = script(30, "Ink"),
    SettingsNavGroup = script(21, "PencilRed"),
    SettingsNav = hand(15, "InkSoft"),
    SettingsNavHover = hand(15, "Ink"),
    SettingsNavSelected = hand(15, "Ink"),
    SettingsVersion = hand(13, "InkMuted"),
    SettingsTitle = script(38, "Ink"),
    SettingsDescription = hand(15, "InkSoft"),
    SettingsSection = script(22, "PencilBlue"),
    SettingsSectionNote = hand(14, "InkMuted"),
    SettingsLabel = hand(15, "Ink"),
    SettingsText = hand(15, "InkSoft"),
    SettingsLink = hand(15, "PencilBlue"),
    CurrencyCount = hand(14, "Ink"),
    CurrencyCapped = hand(14, "Capped"),
    CurrencyNone = hand(14, "InkMuted"),
    CurrencyName = hand(14, "Ink"),
    CurrencyGain = hand(15, "Gain"),
    CurrencyLoss = hand(14, "InkMuted"),
    CurrencyMore = hand(14, "InkSoft"),
  },

  Layout = {
    -- A taller header for the larger hand; section names in their row, above the first row of icons.
    TitleTop = 14,
    TitleInset = 6,
    SearchTop = 72,
    SearchHeight = 28,
    SearchIcon = 15,
    ContentTop = 110,
    Footer = 40,
    FooterText = 13,
    FooterMoney = 12,
    SectionHeader = 30,
    SectionSpacing = 16,
    TabHeight = 32,
    TabSpacing = 4,
    TabMinWidth = 80,
    TabMaxWidth = 170,
    TabPadding = 18,
    TabHover = 7,
    HeaderButton = 24,
    HeaderButtonGap = 8,
    HeaderButtonTop = 24,
    VendorTextGap = 8,
    VendorPriceRaise = 2,
  },

  Motion = {
    -- Twelve poses a second, each a little off where it should be (asked: "not just staggered in that stop motion FPS,
    -- but imperfect in their placement from frame to frame"). Appearance > Animation > Stop Motion turns it off.
    StopMotion = { FPS = 12, Spacing = 0.35, Wobble = 1.2 },
    -- Sections are placed on the sheet one after the other, a pose or two each.
    Time = { Cascade = 0.25, Stagger = 0.05, Hover = 0.17, Toggle = 0.17, TabMarker = 0.25, Interaction = 0.33,
      Land = 0.33, FlyAway = 0.33 },
    Ease = { Cascade = "outBackSoft", Open = "outBackSoft" },
    Rise = 8,
  },

  Panel = {
    Fill = { Texture = "PaperBody", Color = "White" },
    Feather = false,
    Wash = false,
    Edge = false,
    Frame = tornFrame(),
    DropGlow = { Texture = "Swash", Color = "PencilBlue", Alpha = 0.15, BlendMode = "BLEND" },
    -- Each piece drawn for the backpack (its inner side on the left) and mirrored on the panels across the screen.
    Ornaments = {
      -- The creases a sheet folded in four keeps, across its middle both ways, where it unfolded.
      { Texture = "Creases", Point = "BODY", Color = "White", Alpha = 0.7, Layer = "BORDER", SubLevel = 1 },
      -- A red pencil under the title.
      { Texture = "Underline", Point = "TOPINNER", X = 22, Y = 62, Width = 158, Height = 10, Color = "PencilRed",
        Alpha = 0.9, Layer = "ARTWORK", SubLevel = 2 },
      -- Doodles in the margins, behind the items. Y is down from whichever corner it hangs from: up from a bottom one.
      doodle("DoodleCat", "Ink", 0.7, "BOTTOMOUTER", 14, -40, 112),
      doodle("DoodleHeart", "Heart", 0.9, "BOTTOMOUTER", 10, -140, 26),
      doodle("DoodleSprig", "Leaf", 0.7, "BOTTOMINNER", -4, -36, 104),
      -- Not at the vendor, whose header buttons run this far along.
      { Texture = "DoodleSun", Frames = 3, Color = "Sun", Alpha = 0.9, Point = "TOPOUTER", X = 178, Y = 10, Width = 46,
        Height = 46, Sizes = "Full", Panels = { "Backpack", "Bank", "GuildBank" }, Layer = "ARTWORK", SubLevel = 1,
        Motion = { Boil = { FPS = 6, Jiggle = 0.6 } } },
      doodle("DoodleStar", "Ink", 0.45, "BOTTOMINNER", 90, -46, 24),
      doodle("DoodleStar", "PencilRed", 0.5, "BOTTOMOUTER", 148, -152, 18, "Full"),
      doodle("DoodlePlane", "InkSoft", 0.5, "BOTTOMINNER", 40, -236, 96, "Full"),
      doodle("DoodleMug", "InkSoft", 0.55, "BOTTOMOUTER", 134, -44, 46, "Full"),
      -- A note to self, in English.
      { Texture = "NoteNeed", Point = "BOTTOMINNER", X = 104, Y = -52, Width = 200, Height = 100, Color = "InkSoft",
        Alpha = 0.7, Locales = ENGLISH, Sizes = "Full", Layer = "ARTWORK", SubLevel = 1 },
      -- Tape holding it to the screen, over its inner edge, and across its corners on a small bag.
      tape("TapeLeft", "TapeTan", "TOPINNER", -58, 16, 96, 48),
      tape("TapeRight", "TapeBlue", "BOTTOMINNER", -48, -110, 96, 48),
      tape("TapeRight", "TapePink", "TOPOUTER", -30, -16, 96, 48, "Small"),
      tape("TapeLeft", "TapeBlue", "BOTTOMOUTER", -36, 18, 96, 48, "Small"),
    },
    -- A sheet folded in four, opening and closing (NextPaper). Twelve poses a second: it drops in over two, unfolds
    -- across one fold over four and the other over five, there in 0.92 seconds (a bank waits for its panel to have shown
    -- before it loads, 1 second at most). Closing, it is grabbed for two poses, crumples over six, and is tossed up a
    -- little, tumbling, until it has fallen off the screen. Appearance > Animation > Paper Folding turns it off.
    Paper = {
      Front = { Texture = "PaperBody", Color = "White" },
      Back = { Texture = "PaperBack", Color = "White" },
      Edge = { Texture = "PaperEdgeRun", Width = 13, Inside = 3, Tile = 128 },
      Shadow = { Texture = "PaperShadow", Color = "Black", Alpha = 0.34, Spread = 16, X = 3, Y = -5 },
      Rate = 12,
      Wobble = { Move = 1.6, Turn = 0.55, Vertex = 0.9, Pose = 6 },
      Open = {
        From = "TOPOUTER", Cells = 5, Curl = 0.5, Depth = 2.4, Lit = 0.68, Reveal = 2,
        Quarter = { { Scale = 1.09, Turn = -2.5 }, {} },
        Half = { 138, 84, 26, 0 },
        Full = { 142, 96, 44, -4, 0 },
        Note = {
          { Texture = "DoodleBag", Frames = 3, Color = "Ink", Alpha = 0.8, Width = 104, Height = 104, X = 0, Y = -30 },
          { Texture = "NoteName", Color = "Ink", Alpha = 0.85, Width = 136, Height = 34, X = 0, Y = 36 },
        },
      },
      Close = {
        Grab = 2, Tremble = 2.5, Cell = 56, Jitter = 0.34, Ball = 56, Lump = 0.2, Wrinkle = 24, Jag = 13, Wrap = 0.94,
        Lag = 0.35, Lit = 0.42, Twist = 0.9, Facet = 0.34, Crop = 0.08, Mount = { Texture = "ItemMount", Color = "White" },
        Poses = { 0.1, 0.27, 0.48, 0.7, 0.88, 1 },
        Toss = { Up = 470, Gravity = 1500, Drift = { 60, 130 }, Tumble = { 5, 6.5 }, Life = 3.5 },
      },
    },
  },

  Header = {
    TitleGlow = { Texture = "Swash", Color = "Highlighter", Alpha = 0.7, X = 16, Y = 2, BlendMode = "BLEND" },
    Ribbon = false,
    Spark = false,
    Cloud = false,
    Buttons = { Color = "Ink", HoverColor = "PencilRed", ArtColor = "White", ArtHoverColor = "White", DisabledAlpha = 0.3 },
  },

  -- A field drawn round in pencil, on the paper itself.
  Search = {
    Fill = { Texture = "Field", Color = "Ink", Alpha = 0.7 },
    FocusFill = { Texture = "Field", Color = "PencilBlue", Alpha = 1 },
    Edge = false,
    Icon = { Color = "InkSoft", Idle = 0.85, Active = 1, FocusColor = "PencilBlue", ActiveColor = "Ink" },
  },

  -- A section's name in Caveat over a highlighter's streak, its count, and a pencil line on across the section.
  Sections = {
    Title = { X = 4, Y = -1 },
    CountGap = 8,
    LineGap = 10,
    Header = { Texture = "Swash", Color = "Highlighter", Alpha = 0.55, Height = 26 },
    Line = { Texture = "PencilLine", Color = "Ink", Alpha = 0.42, Size = 8 },
    Highlight = { Texture = "Swash", Color = "PencilBlue", Alpha = 0.22 },
  },

  -- Scraps of paper taped to the bag's side, torn where they stick out; the chosen one lighter, its tape blue.
  Tabs = {
    Fill = { Texture = "TabScrap", Color = "White" },
    SelectedFill = { Texture = "TabScrapChosen", Color = "White" },
    Indicator = false,
    Glow = { Color = "PencilBlue", BlendMode = "BLEND", Drop = 0.3, Pulse = 0.5 },
  },

  Footer = {
    Line = { Texture = "PencilLine", Color = "Ink", Alpha = 0.35, Size = 8 },
    -- The bags' money, written on the paper.
    CoinFont = "Price",
  },

  -- Flecks of paper for sparkles, in tape's colours; none drifting about, only bursts.
  Sparkles = {
    Texture = "Confetti",
    BlendMode = "BLEND",
    Colors = { "TapeTan", "TapeBlue", "TapePink", "PencilRed" },
    TwinkleDepth = 0,
    Cloud = false,
    Ribbon = false,
    Edge = false,
  },

  -- A twine tying two bags together.
  Chain = { Color = "Twine", BeadColor = "Twine", KnotColor = "Twine", Beads = 0, Thickness = 2, Amplitude = 5, Turn = 0.6,
    Segments = 12, KnotAlpha = 0 },

  Small = {
    Grip = {
      Size = 18,
      ShowOnHover = false,
      Normal = { Texture = "GripArt", Color = "InkSoft", Alpha = 0.75 },
      Highlight = { Texture = "GripArt", Color = "PencilBlue", BlendMode = "BLEND" },
      Pushed = { Texture = "GripArt", Color = "Ink" },
    },
  },

  Drag = { Shadow = { Color = "Black", Alpha = 0.28 } },

  -- A section waiting to be answered, on a slip of paper edged in pencil, a highlighter's streak behind it.
  Dock = {
    TitleHeight = 30,
    Card = { Texture = "PaperBody", Color = "White" },
    Glow = { Color = "PencilBlue", Width = 2, Low = 0.35, High = 0.9 },
    Halo = { Texture = "Glow", Color = "Highlighter", BlendMode = "BLEND", Low = 0.25, High = 0.6 },
  },

  Currency = {
    Icon = 18,
    Bar = { Track = { Color = "Ink", Alpha = 0.15 }, Fill = { Color = "PencilBlue", Alpha = 0.85 },
      Capped = { Color = "PencilRed" } },
    Flash = { Texture = "Glow", Color = "Highlighter", BlendMode = "BLEND", Alpha = 0.7 },
    Drop = { Texture = "Swash", Color = "PencilBlue", BlendMode = "BLEND", Alpha = 0.35 },
    Slot = { Color = "InkSoft" },
    Tracker = {
      Fill = { Texture = "PaperBody", Color = "White" },
      Edge = false,
      Frame = tornFrame(),
    },
  },

  Vendor = {
    -- Cards as faint pencil boxes on the sheet.
    QualityBorder = TEXTURES .. "item_quality.png",
    CoinSize = 14,
    Highlight = { 0.3, 0.48, 0.71, 0.14 },
    CardFill = { 0.18, 0.16, 0.14, 0.045 },
    CardHover = { 0.18, 0.16, 0.14, 0.09 },
  },

  -- The settings window as a larger sheet: the pages down its side on a shade of it, marked in a highlighter's blue.
  Settings = {
    Fill = { Texture = "PaperBody", Color = "White" },
    Frame = tornFrame(),
    Wash = false,
    Edge = false,
    Sidebar = { Fill = { Color = "Sidebar" }, Line = { Color = "Ink", Alpha = 0.22, Size = 1 } },
    Brand = { IconColor = "Ink", IconSize = 30,
      Line = { Texture = "PencilLine", Color = "Ink", Alpha = 0.5, Size = 8 } },
    Search = { IconColor = "InkSoft" },
    Back = { IconColor = "Ink" },
    Nav = {
      Indicator = false,
      SelectedFill = { Texture = "Marker", Color = "TapeBlue", Alpha = 0.8 },
      HoverFill = { Texture = "Marker", Color = "Highlighter", Alpha = 0.45 },
    },
    Header = { Close = { Color = "Ink", HoverColor = "PencilRed" } },
    Content = {
      Card = { Color = "White", Alpha = 0.22 },
      Divider = { Color = "Ink", Alpha = 0.1, Size = 1 },
      Hover = { Texture = "Marker", Color = "Highlighter", Alpha = 0.28 },
      TitleUpper = false,
      TitleHeight = 30,
    },
    Footer = { Line = { Color = "Ink", Alpha = 0.2, Size = 1 } },
    Cards = {
      Fill = { Color = "White", Alpha = 0.22 }, HoverFill = { Color = "White", Alpha = 0.42 },
      Edge = { Color = "Ink", Alpha = 0.3, Size = 1 }, SelectedEdge = { Color = "PencilBlue", Alpha = 1, Size = 2 },
    },
    Categories = {
      Indicator = false,
      SelectedFill = { Texture = "Marker", Color = "TapeBlue", Alpha = 0.8 },
      HoverFill = { Texture = "Marker", Color = "Highlighter", Alpha = 0.45 },
    },
    BagCategories = {
      Fill = { Color = "White", Alpha = 0.2 },
      HoverFill = { Texture = "Marker", Color = "Highlighter", Alpha = 0.3 },
    },
    Currency = { Hover = { Texture = "Marker", Color = "Highlighter", Alpha = 0.3 } },
  },

  Controls = {
    -- Pencil: a line to run along, a thumb shaded by hand.
    ScrollBar = {
      Size = 8, HoverSize = 10,
      Track = { Texture = "ScrollTrack", Color = "Ink", Alpha = 0.3 },
      Thumb = { Texture = "ScrollThumb", Color = "InkSoft", Alpha = 0.8 },
      ThumbHover = { Texture = "ScrollThumb", Color = "Ink", Alpha = 1 },
      ThumbDrag = { Texture = "ScrollThumb", Color = "PencilBlue", Alpha = 1 },
    },
    -- Check boxes drawn by hand, a blue pencil's tick for on.
    Toggle = {
      Style = "Check",
      Width = 22, Height = 22,
      Off = { Texture = "CheckBox", Color = "Ink", Alpha = 0.85 },
      On = { Texture = "CheckMark", Color = "PencilBlue", Alpha = 1 },
      Disabled = { Texture = "CheckBox", Color = "InkMuted", Alpha = 0.5 },
      DisabledOn = { Texture = "CheckMark", Color = "InkMuted", Alpha = 0.6 },
      Hover = { Texture = "Marker", Color = "Highlighter", Alpha = 0.5 },
    },
    -- Buttons as a pencilled outline, in three pieces whatever their width. Every art spec here sets its Alpha: themes
    -- merge with Default key by key, and Default's Primary and Danger fills are faint colors.
    Button = {
      Height = 28, DisabledAlpha = 0.45,
      Plain = {
        Fill = outlined("OutlineButton", "Ink", 0.8), HoverFill = outlined("OutlineButton", "PencilBlue", 1),
        PressedFill = outlined("OutlineButton", "Ink", 1), Edge = false, HoverEdge = false,
      },
      Primary = {
        Fill = outlined("OutlineFill", "TapeBlue", 0.75), HoverFill = outlined("OutlineFill", "TapeBlue", 1),
        PressedFill = outlined("OutlineFill", "PencilBlue", 0.6), Edge = false, HoverEdge = false,
      },
      Danger = {
        Fill = outlined("OutlineButton", "Danger", 0.85), HoverFill = outlined("OutlineFill", "TapePink", 0.8),
        PressedFill = outlined("OutlineFill", "TapePink", 1), Edge = false, HoverEdge = false,
      },
    },
    -- Fields: the pencilled outline on the paper.
    Input = {
      Height = 28,
      Fill = outlined("OutlineButton", "Ink", 0.65), FocusFill = outlined("OutlineButton", "PencilBlue", 1),
      Edge = false,
    },
    TextArea = {
      Fill = { Color = "White", Alpha = 0.3 }, FocusFill = { Color = "White", Alpha = 0.5 },
      Edge = { Color = "Ink", Size = 1, Idle = 0.3, Hover = 0.45, Focus = 0.8 },
    },
    ItemGrid = {
      Fill = { Color = "White", Alpha = 0.22 },
      Edge = { Color = "Ink", Size = 1, Idle = 0.25, Hover = 0.35, Focus = 0.5 },
      CommonEdge = { Color = "Ink", Alpha = 0.3 },
      Hover = { Color = "PencilBlue", Alpha = 0.18 },
    },
    Slider = {
      ThumbSize = 16,
      Track = { Texture = "PencilLine", Color = "Ink", Alpha = 0.55 },
      Fill = { Texture = "PencilLine", Color = "PencilBlue", Alpha = 1 },
      Thumb = { Texture = "Thumb", Color = "Ink" },
      ThumbHover = { Texture = "Thumb", Color = "PencilBlue" },
    },
    Dropdown = {
      Height = 28,
      Fill = outlined("OutlineButton", "Ink", 0.65), HoverFill = outlined("OutlineButton", "PencilBlue", 0.9),
      OpenFill = outlined("OutlineButton", "PencilBlue", 1),
      Edge = false,
      Chevron = { Texture = "IconChevron", Color = "InkSoft", Size = 13 },
    },
    -- A menu: a slip of paper, edged in pencil.
    Menu = {
      ItemHeight = 26,
      Fill = { Texture = "PaperBody", Color = "White" },
      Edge = { Color = "Ink", Alpha = 0.55, Size = 1 },
      HoverFill = { Texture = "Marker", Color = "Highlighter", Alpha = 0.65 },
      Check = { Texture = "IconCheck", Color = "PencilBlue", Size = 13 },
    },
    Swatch = { Edge = { Color = "Ink", Alpha = 0.6, Size = 1 }, HoverEdge = { Color = "Ink", Alpha = 1, Size = 1 } },
    TopTabs = {
      Height = 36,
      Indicator = { Texture = "Underline", Color = "PencilRed", Height = 6 },
      Line = { Color = "Ink", Alpha = 0.15, Size = 1 },
    },
    -- A dialog: a note, torn round its edge.
    Dialog = {
      Card = { Texture = "PaperBody", Color = "White" },
      Edge = false,
      Frame = tornFrame(),
    },
  },

  -- Item buttons: each icon mounted on a square of lighter paper, pencilled round, its quality in coloured pencil.
  ItemButton = {
    Icon = { Inset = 3, TexCoords = { 0.08, 0.92, 0.08, 0.92 } },
    Backdrop = { Texture = TEXTURES .. "item_mount.png" },
    QualityBorder = { Texture = TEXTURES .. "item_quality.png", Alpha = 0.92 },
    QuestBorderColor = { 0.86, 0.63, 0.22, 1 },
    Highlight = { Texture = TEXTURES .. "item_light.png", VertexColor = { 0.3, 0.48, 0.71, 0.26 }, BlendMode = "BLEND" },
    Pushed = { Texture = TEXTURES .. "item_light.png", VertexColor = { 0.18, 0.16, 0.14, 0.26 }, BlendMode = "BLEND" },
    EmptySlot = { Texture = TEXTURES .. "item_empty.png" },
    Count = { Font = { Object = "NumberFontNormal", Path = PATRICK, Size = 15, Flags = "OUTLINE" },
      Points = { { Point = "BOTTOMRIGHT", X = -4, Y = 4 } } },
    ItemLevel = { Font = { Object = "NumberFontNormal", Path = PATRICK, Size = 15, Flags = "OUTLINE" } },
    Countdown = { Locales = LATIN, Font = { Path = PATRICK, Size = 18, Flags = "OUTLINE" } },
  },
})
