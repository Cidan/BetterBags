local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- ElvUI: BetterBags Next in ElvUI's look, offered while ElvUI is loaded (docs/next-elvui-theme.md). Data only, nothing
-- of ElvUI's called: its art drawn from its own files, read from its source (.libraries/ElvUI); the player's ElvUI
-- colors, bar and gloss textures, font and its style, and icon crop read out of ElvUI's tables (Variables, references,
-- next-themes-references.md §2a), ElvUI's defaults while one is not there. E:UpdateMedia and E:UpdateTexCoords are
-- watched (Watch, §2b): after either runs, the theme is read again and drawn again if anything it reads changed (asked:
-- "i do think we should hook UpdateMedia").
--   Every window flat on ElvUI's templates (General/Toolkit.lua, SetTemplate): the panels, menus and dialogs on its
--     transparent one (the fade color), cards, fields, tabs, buttons and the search box on its default one (the
--     backdrop color), each with its one-pixel edge in the border color. Its value color where ElvUI lights things.
--   Its controls as its skins draw them (Modules/Skins/Skins.lua); its bags' buttons and slots (Modules/Bags/Bags.lua).
--   Text in ElvUI's font, style and size: every role but the vendor card's keeps its difference from ElvUI's 12, and the
--     rows, offsets and widths round it grow with it (grow, widen); the bags' counts and item levels in ElvUI's bag
--     fonts. Font objects are reused by look, so a size passed once makes its set once (next-themes.md §4).
-- Paths below are under ElvUI/Game/Shared/.
local MEDIA = "Interface\\AddOns\\ElvUI\\Game\\Shared\\Media\\"
local TEX = MEDIA .. "Textures\\"

-- elvui names a value under ElvUI's engine (E, unpack(ElvUI)'s first), with ElvUI's default when it is not there.
---@param path (string|number)[]
---@param fallback any
---@param extra? table
---@return table
local function elvui(path, fallback, extra)
  local ref = { Global = "ElvUI", Path = { 1 }, Fallback = fallback }
  for _, key in ipairs(path) do
    table.insert(ref.Path, key)
  end
  for k, v in pairs(extra or {}) do
    ref[k] = v
  end
  return ref
end

-- ElvUI's font styles (LibAceConfigHelper's values): NONE draws no flags, and a SHADOW style is the rest and a shadow
-- (FontTemplate, General/Toolkit.lua:513-519); the others are flags as they are.
local FLAGS = { NONE = "", SHADOW = "", SHADOWOUTLINE = "OUTLINE", SHADOWTHICKOUTLINE = "THICKOUTLINE" }
local SHADOWED = {
  NONE = false, OUTLINE = false, THICKOUTLINE = false, MONOCHROME = false, MONOCHROMEOUTLINE = false,
  MONOCHROMETHICKOUTLINE = false, SHADOW = true, SHADOWOUTLINE = true, SHADOWTHICKOUTLINE = true,
}
-- The same as a shadow to draw (E:SetFontShadow, General/Initialize.lua:460-463): black 1 down and right, at 1 for SHADOW
-- alone and 0.6 with an outline; none for the rest. For the bags' own fonts (their outline settings).
local NO_SHADOW = { Color = { 0, 0, 0, 0 }, X = 0, Y = 0 }
local SOFT_SHADOW = { Color = { 0, 0, 0, 0.6 }, X = 1, Y = -1 }
local BAG_SHADOWS = {
  NONE = NO_SHADOW, OUTLINE = NO_SHADOW, THICKOUTLINE = NO_SHADOW, MONOCHROME = NO_SHADOW, MONOCHROMEOUTLINE = NO_SHADOW,
  MONOCHROMETHICKOUTLINE = NO_SHADOW, SHADOW = { Color = { 0, 0, 0, 1 }, X = 1, Y = -1 }, SHADOWOUTLINE = SOFT_SHADOW,
  SHADOWTHICKOUTLINE = SOFT_SHADOW,
}
local FAINT = { 0, 0, 0, 0.6 }
local SHADOW_COLORS = {
  NONE = FAINT, OUTLINE = FAINT, THICKOUTLINE = FAINT, MONOCHROME = FAINT, MONOCHROMEOUTLINE = FAINT,
  MONOCHROMETHICKOUTLINE = FAINT, SHADOW = { 0, 0, 0, 1 }, SHADOWOUTLINE = FAINT, SHADOWTHICKOUTLINE = FAINT,
}

-- The sizes that follow ElvUI's font size (E.db.general.fontSize, 12 by default, Defaults/Profile.lua:76; its options
-- call E:UpdateMedia): variables gathered as the theme is written, added to its Variables below.
local sizes = {}

-- grow names a size that follows ElvUI's font size: base at its 12, n times the change past it (n lines of text in a
-- row; 0.5 for an offset that keeps something centered on a line).
---@param base number
---@param n? number
---@return string
local function grow(base, n)
  n = n or 1
  local name = ("Grow%s_%s"):format((tostring(base):gsub("%.", "_")), (tostring(n):gsub("%.", "_")))
  sizes[name] = elvui({ "db", "general", "fontSize" }, 12, { Scale = n, Add = base - 12 * n })
  return "$" .. name
end

-- widen names a width that holds text, widening as the text does: base at ElvUI's 12, in proportion past it.
---@param base number
---@return string
local function widen(base)
  local name = ("Wide%s"):format((tostring(base):gsub("%.", "_")))
  sizes[name] = elvui({ "db", "general", "fontSize" }, 12, { Scale = base / 12 })
  return "$" .. name
end

-- A text role in ElvUI's font and style, size and color its own; its size following ElvUI's font size, keeping its
-- difference from ElvUI's 12, unless it is fixed (the vendor's card text, sized to sit beside its icon).
---@param size number
---@param color string
---@param fixed? boolean
---@return table
local function text(size, color, fixed)
  return { File = "$Font", Flags = "$FontFlags", Shadow = "$Shadowed", Size = fixed and size or grow(size), Color = color }
end

-- ElvUI's one-pixel edge (SetTemplate: E.twoPixelsPlease is always false, General/Initialize.lua:103), and lit; with
-- its black lines inside and outside it outside pixel mode ($Outlines). A line (a divider, a tab rail's) has none.
local EDGE = { Color = "Border", Alpha = 1, Size = 1, Outlines = "$Outlines" }
local LIT = { Color = "Accent", Alpha = 1, Size = 1, Outlines = "$Outlines" }
local LINE = { Color = "Border", Alpha = 1, Size = 1 }
-- Outside pixel mode SetTemplate puts a black one-pixel line just inside its edge and one just outside it
-- (General/Toolkit.lua:331-359): rings in NextControls' terms, and in Sonata's for item buttons.
local RINGS = { { Offset = 1, Color = "Black", Size = 1 }, { Offset = -1, Color = "Black", Size = 1 } }
local ITEM_RINGS = {
  { Offset = 1, EdgeSize = 1, Color = { 0, 0, 0, 1 } },
  { Offset = -1, EdgeSize = 1, Color = { 0, 0, 0, 1 } },
}
-- A button on the gloss template (HandleButton: SetTemplate(template, true)), its edge lit under the pointer
-- (S.SetModifiedBackdrop); no pushed look (its pushed texture cleared).
local GLOSS = { Texture = "$Gloss", Color = "Card", Alpha = 1 }
---@param font string
---@param hover string
---@return table
local function button(font, hover)
  return {
    Fill = GLOSS, HoverFill = GLOSS, PressedFill = GLOSS, DisabledFill = GLOSS,
    Edge = EDGE, HoverEdge = LIT, Font = font, HoverFont = hover, DisabledFont = "ButtonDisabled",
  }
end
-- A list row under the pointer (HandleButtonHighlight: Highlight.tga, white at 0.3) and chosen (the value color at 0.5,
-- HandleCategoriesButtons' highlight).
local ROW_HOVER = { Texture = "Highlight", Color = "White", Alpha = 0.3 }
local ROW_CHOSEN = { Texture = "Highlight", Color = "Accent", Alpha = 0.5 }

local theme = {
  Name = "ElvUI",
  DisplayName = "ElvUI",
  Description = "ElvUI's look, in your ElvUI colors, textures and font: flat frames, one-pixel borders, its art.",
  Requires = { "ElvUI" },

  -- ElvUI's values, read when the theme resolves.
  Variables = {
    -- The player's colors (Defaults/Profile.lua:138-141), written into E.media by E:UpdateMedia (General/Core.lua:351-372):
    -- the border, the default template's fill, the transparent template's (its alpha the player's), the value color.
    Border = elvui({ "media", "bordercolor" }, { 0, 0, 0, 1 }, { Alpha = 1 }),
    Backdrop = elvui({ "media", "backdropcolor" }, { 0.1, 0.1, 0.1, 1 }, { Alpha = 1 }),
    Fade = elvui({ "media", "backdropfadecolor" }, { 0.06, 0.06, 0.06, 0.8 }),
    Value = elvui({ "media", "rgbvaluecolor" }, { 0.09, 0.52, 0.82, 1 }, { Alpha = 1 }),
    -- The bar textures the player picked ("ElvUI Norm" for both, Defaults/Private.lua:9-10), and the font (unset: the
    -- client's own, for the locale).
    Norm = elvui({ "media", "normTex" }, TEX .. "NormTex2.tga"),
    Gloss = elvui({ "media", "glossTex" }, TEX .. "NormTex2.tga"),
    Font = elvui({ "media", "normFont" }, false),
    -- The font's style (Defaults/Profile.lua:78), as flags and a shadow.
    FontFlags = elvui({ "db", "general", "fontStyle" }, "OUTLINE", { Map = FLAGS }),
    Shadowed = elvui({ "db", "general", "fontStyle" }, false, { Map = SHADOWED }),
    -- The shadow: black at 0.6, and at 1 for SHADOW alone (E:SetFontShadow, General/Initialize.lua:460-463).
    ShadowColor = elvui({ "db", "general", "fontStyle" }, { 0, 0, 0, 0.6 }, { Map = SHADOW_COLORS }),
    -- The icon crop: 0.04 times cropIcon (2) in from each side once ElvUI has started (E:UpdateTexCoords,
    -- General/Toolkit.lua:69-81); 0 to 1 until then.
    TexCoords = elvui({ "TexCoords" }, { 0.08, 0.92, 0.08, 0.92 }),
    -- Pixel mode (Thin Borders, on by default, Defaults/Private.lua:24; E.PixelMode, General/Initialize.lua:727): off,
    -- the black lines inside and outside every edge, what is inside an edge inset past them (E.Border 2, :728; drawn
    -- here as an Inset of "Edge", from the lines themselves). Changing it needs a reload (ElvUI_Options General.lua:192):
    -- read, not watched.
    Outlines = elvui({ "PixelMode" }, false, { Map = { [true] = false, [false] = RINGS } }),
    ItemOutlines = elvui({ "PixelMode" }, false, { Map = { [true] = false, [false] = ITEM_RINGS } }),
    -- The bags' quest colors (Defaults/Profile.lua:534-535): an item while its quest is not active, and once it is
    -- (Modules/Bags/Bags.lua:615-617, B.QuestColors).
    QuestStarter = elvui({ "db", "bags", "colors", "items", "questStarter" }, { 1, 0.96, 0.41, 1 }, { Alpha = 1 }),
    QuestItem = elvui({ "db", "bags", "colors", "items", "questItem" }, { 0.9, 0.3, 0.3, 1 }, { Alpha = 1 }),
    -- The bags' count and item level fonts (Defaults/Profile.lua, P.bags: Homespun 10 MONOCHROMEOUTLINE), by the name the
    -- player picked, as B:UpdateItemDisplay draws them (FontTemplate: LSM:Fetch, General/Toolkit.lua): the file from
    -- LibSharedMedia's table (E.Libs.LSM, General/Initialize.lua:198), ElvUI's Homespun for a name it does not have (a
    -- font not registered for this client's locale). Not their color: a color dragged would make a font object a step.
    CountName = elvui({ "db", "bags", "countFont" }, "Homespun"),
    CountFile = elvui({ "Libs", "LSM", "MediaTable", "font", "$CountName" }, MEDIA .. "Fonts\\Homespun.ttf"),
    CountSize = elvui({ "db", "bags", "countFontSize" }, 10),
    CountFlags = elvui({ "db", "bags", "countFontOutline" }, "MONOCHROMEOUTLINE", { Map = FLAGS }),
    CountShadow = elvui({ "db", "bags", "countFontOutline" }, NO_SHADOW, { Map = BAG_SHADOWS }),
    LevelName = elvui({ "db", "bags", "itemLevelFont" }, "Homespun"),
    LevelFile = elvui({ "Libs", "LSM", "MediaTable", "font", "$LevelName" }, MEDIA .. "Fonts\\Homespun.ttf"),
    LevelSize = elvui({ "db", "bags", "itemLevelFontSize" }, 10),
    LevelFlags = elvui({ "db", "bags", "itemLevelFontOutline" }, "MONOCHROMEOUTLINE", { Map = FLAGS }),
    LevelShadow = elvui({ "db", "bags", "itemLevelFontOutline" }, NO_SHADOW, { Map = BAG_SHADOWS }),
  },
  -- ElvUI's options call E:UpdateMedia after every change (ElvUI_Options/Game/Shared/General.lua), and its start calls
  -- E:UpdateTexCoords after E:UpdateMedia (General/Core.lua:2047-2055); its bags' color options call UpdateBagColors on
  -- its bags module (E.Bags, General/Initialize.lua:79; ElvUI_Options/Game/Shared/Bags.lua:196), its text options
  -- UpdateItemDisplay.
  Watch = {
    { Global = "ElvUI", Path = { 1 }, Method = "UpdateMedia" },
    { Global = "ElvUI", Path = { 1 }, Method = "UpdateTexCoords" },
    { Global = "ElvUI", Path = { 1, "Bags" }, Method = "UpdateBagColors" },
    -- Its bags' count, item level and item info options call UpdateItemDisplay (ElvUI_Options/Game/Shared/Bags.lua:145-167).
    { Global = "ElvUI", Path = { 1, "Bags" }, Method = "UpdateItemDisplay" },
  },

  Textures = {
    Close = TEX .. "Close.tga",
    Arrow = TEX .. "ArrowUp.tga",
    Melli = TEX .. "Melli.tga",
    Highlight = TEX .. "Highlight.tga",
  },

  Palette = {
    Border = "$Border",
    Accent = "$Value",
    -- The transparent template's fill: the panels, menus, dialogs.
    Body = "$Fade",
    -- The default template's: cards, fields, tabs, buttons, the search box.
    Card = "$Backdrop",
    ControlFill = "$Backdrop",
    ControlHover = "$Backdrop",
    ControlPressed = "$Backdrop",
    Track = "$Backdrop",
    SearchFill = "$Backdrop",
    SearchFillFocus = "$Backdrop",
    Tab = "$Backdrop",
    TabSelected = "$Backdrop",
    -- Text white; ElvUI's gold (its check marks and slider thumbs, 1, 0.82, 0, HandleCheckBox and HandleSliderFrame) for
    -- what Blizzard's templates draw gold, which ElvUI keeps; gray (its disabled check marks, 0.6) for what is off.
    Text = { 1, 1, 1, 1 },
    Gold = { 1, 0.82, 0, 1 },
    Muted = { 0.6, 0.6, 0.6, 1 },
    ButtonIcon = { 1, 1, 1, 1 },
    Bead = { 1, 1, 1, 1 },
    Shadow = "$ShadowColor",
    Scrim = { 0, 0, 0, 0.5 },
  },

  FontShadow = { Color = "Shadow", X = 1, Y = -1 },
  -- No role is drawn in a color read from ElvUI: its options call E:UpdateMedia on every step of a dragged color, and a
  -- role drawn otherwise needs new font objects, which can never be freed (next-themes-references.md §2b). Gold, as
  -- Blizzard's templates draw what ElvUI keeps, where the value color would go.
  Fonts = {
    Title = text(16, "Text"),
    Section = text(13, "Text"),
    SectionRecent = text(13, "Gold"),
    SectionFree = text(12, "Muted"),
    Count = text(11, "Muted"),
    -- Blizzard's tabs, which ElvUI keeps: gold, white when chosen.
    Tab = text(12, "Gold"),
    TabSelected = text(12, "White"),
    Footer = text(12, "Text"),
    Empty = text(12, "Muted"),
    DragHint = text(12, "White"),
    ConfirmTitle = text(15, "Text"),
    ConfirmWarning = text(12, "Gold"),
    ConfirmHint = text(12, "Muted"),
    Search = text(12, "Muted"),
    SearchText = text(12, "Text"),
    -- Two lines of a name and a price beside a vendor's 36-pixel icon.
    Price = text(11, "White", true),
    PriceUnaffordable = text(11, "Unaffordable", true),
    VendorName = text(11, "Text", true),
    -- The vendor's stack counts in the bags' count font, size and outline (CountFile: the player's, Homespun 10
    -- MONOCHROMEOUTLINE by default).
    Stack = { Object = "NumberFontNormal", File = "$CountFile", Size = "$CountSize", Flags = "$CountFlags",
      Shadow = "$CountShadow" },
    ControlText = text(12, "Text"),
    ControlMuted = text(12, "Muted"),
    ControlHelp = text(12, "Muted"),
    -- Blizzard's buttons, which ElvUI keeps: gold, white under the pointer, gray while off.
    Button = text(12, "Gold"),
    ButtonPrimary = text(12, "Gold"),
    ButtonDanger = text(12, "Danger"),
    ButtonHover = text(12, "White"),
    ButtonDisabled = text(12, "Muted"),
    Link = text(12, "Gold"),
    LinkHover = text(12, "White"),
    MenuItem = text(12, "Text"),
    MenuItemSelected = text(12, "Gold"),
    DialogTitle = text(14, "Text"),
    DialogText = text(12, "Text"),
    TopTab = text(12, "Gold"),
    TopTabHover = text(12, "White"),
    TopTabSelected = text(12, "White"),
    SettingsBrand = text(16, "Text"),
    SettingsNavGroup = text(11, "Gold"),
    SettingsNav = text(12, "Gold"),
    SettingsNavHover = text(12, "White"),
    SettingsNavSelected = text(12, "White"),
    SettingsVersion = text(10, "Muted"),
    SettingsTitle = text(20, "Text"),
    SettingsDescription = text(12, "Muted"),
    SettingsSection = text(12, "Gold"),
    SettingsSectionNote = text(11, "Muted"),
    SettingsLabel = text(12, "Text"),
    SettingsText = text(12, "Muted"),
    SettingsLink = text(12, "Gold"),
    SettingsLead = text(14, "Text"),
    CurrencyCapped = text(12, "Capped"),
    CurrencyNone = text(12, "Muted"),
    CurrencyName = text(12, "Text"),
    CurrencyGain = text(12, "Gain"),
    CurrencyLoss = text(12, "Muted"),
    CurrencyMore = text(11, "Muted"),
  },

  Layout = {
    -- ElvUI's bags: slots 34 across (Defaults/Profile.lua:454), close together, ten to a row.
    Icon = 36,
    Gap = 4,
    PerRow = 10,
    VendorPriceRaise = 3,
    Pad = 12,
    -- The rows round the text grow with ElvUI's font size: the search box under the title, the content under both, the
    -- footer, the section headers and the tabs a line each; the header buttons stay centered on the title. The footer's
    -- text and money stay where they are: anchored by their bottoms in a footer that grows as its text does, they stay
    -- centered (found in review: moved by half a line, the free-slot text left its footer for the items from 28).
    TitleTop = 18,
    TitleInset = 2,
    SearchTop = grow(46),
    SearchHeight = grow(20),
    ContentTop = grow(76, 2),
    Footer = grow(30),
    FooterText = 10,
    FooterMoney = 9,
    -- The gold, a box of its own size (next/coins.lua), moves by half a line to stay centered in the footer.
    FooterCoins = grow(9, 0.5),
    SectionHeader = grow(20),
    SectionSpacing = 10,
    TabHeight = grow(24),
    TabMaxWidth = widen(150),
    TabSpacing = 2,
    TabPadding = 10,
    -- Its bag buttons are 20 across (Modules/Bags/Bags.lua:2512-2543), 5 apart.
    HeaderButton = 20,
    HeaderButtonGap = 5,
    HeaderButtonTop = grow(16, 0.5),
  },

  -- ElvUI's frames appear where they go: no bounce.
  Motion = { Ease = { Open = "outCubic", Enter = "outCubic" } },

  Panel = {
    Fill = { Color = "Body" },
    Feather = false,
    Wash = false,
    Edge = { Color = "Border", Alpha = 1, Size = 1, Full = true, Outlines = "$Outlines" },
    DropGlow = { Color = "Accent", Alpha = 0.15, BlendMode = "ADD" },
  },

  Header = {
    Title = { Font = "Title" },
    TitleGlow = false,
    ItemDrop = { Highlight = { Texture = "Highlight", Color = "Accent", Alpha = 0.5, X = 12, Y = 4, BlendMode = "ADD" } },
    Ribbon = false,
    Spark = false,
    Cloud = false,
    -- Its bag buttons (Modules/Bags/Bags.lua:2512-2543): squares on the default template, the art inside its border,
    -- the edge in the value color under the pointer; BetterBags' glyphs in white inside. Its close button bare: its art
    -- 12 across, the value color under the pointer (HandleCloseButton, Modules/Skins/Skins.lua:1784-1818).
    Buttons = {
      Color = "Text", HoverColor = "Accent", ArtColor = "White", ArtHoverColor = "White", Scale = 0.75,
      Backdrop = { Fill = { Color = "Card" }, Edge = EDGE, HoverEdge = LIT },
      Icons = {
        closeButton = { Texture = "Close", Backdrop = false, Scale = 0.8 },
      },
    },
  },

  -- The bags' search box on the default template, 19 tall (Modules/Bags/Bags.lua:2546-2549); its edge does not change.
  Search = {
    Fill = "SearchFill",
    FocusFill = "SearchFillFocus",
    Edge = { Color = "Border", Size = 1, Idle = 1, Hover = 1, Focus = 1, Outlines = "$Outlines" },
    Icon = { Color = "Text", Idle = 0.6, Active = 1, FocusColor = "White" },
  },

  Sections = {
    Title = { X = 2, Y = -3 },
    Line = { Color = "Accent", From = 0.5, To = 0, Size = 1 },
    Highlight = { Color = "White", From = 0.08, To = 0 },
  },

  -- HandleTab: the default template; the chosen one's edge in the value color.
  Tabs = {
    Fill = "Tab",
    SelectedFill = "TabSelected",
    Fade = 1,
    Edge = EDGE,
    SelectedEdge = LIT,
    Glow = { Color = "Accent", BlendMode = "ADD", Drop = 0.3, Pulse = 0.6 },
    Indicator = false,
  },

  Footer = { Line = false },

  Sparkles = false,

  Chain = { Braid = false, Color = "Accent", BeadColor = "Accent", KnotColor = "Accent" },

  Drag = { Shadow = { Color = "Black", Alpha = 0.6, Spread = 4 } },

  -- A waiting section's card on the default template, its edge pulsing in the value color.
  Dock = {
    Card = { Color = "Card" },
    Glow = { Color = "Accent", Width = 1, Low = 0.5, High = 1, Period = 1.2 },
    Halo = false,
    -- Its title and its two lines, each a line of text.
    TitleHeight = grow(22),
    LineHeight = grow(16),
  },

  -- The currencies' cap bars in the player's bar texture (HandleStatusBar: E.media.normTex), the tracker on the
  -- transparent template.
  Currency = {
    Bar = {
      Track = { Color = "Card", Alpha = 1 },
      Fill = { Texture = "$Norm", Color = "Accent", Alpha = 1 },
    },
    Flash = { Color = "Accent" },
    Drop = { Color = "Accent" },
    Slot = { Color = "Accent" },
    Tracker = { Fill = { Color = "Body" }, Edge = EDGE, ListWidth = widen(200) },
    -- An entry's row is its icon's: it holds its count and name.
    Icon = grow(16),
  },

  Vendor = {
    -- No taller than the price.
    CoinSize = 11,
    Highlight = { 1, 1, 1, 0.3 },
    CardFill = "$Backdrop",
    CardHover = { 1, 1, 1, 0.1 },
  },

  -- ElvUI's bag slots (Modules/Bags/Bags.lua:2783-2911, 630-660): on the gloss template, the icon inset by its border
  -- and cropped as ElvUI crops, the border color's edge; quality on the icon's border (Blizzard's frame), Poor and Common
  -- in the border color as ElvUI draws them; StyleButton's under the pointer and pressed; its quest and upgrade icons;
  -- its count font.
  ItemButton = {
    -- Inside the border and the black line inside it outside pixel mode (SetInside), from the lines themselves.
    Icon = { Inset = "Edge", TexCoords = "$TexCoords" },
    Backdrop = { Texture = "$Gloss", VertexColor = "$Backdrop", BorderColor = "$Border", EdgeSize = 1,
      Outlines = "$ItemOutlines" },
    QualityBorder = { Texture = "Interface\\Common\\WhiteIconFrame", Alpha = 1 },
    QualityColors = { [0] = "$Border", [1] = "$Border" },
    QuestBorderColor = "$QuestStarter",
    QuestActiveBorderColor = "$QuestItem",
    -- Its "!" only on an item that starts a quest not yet taken, nothing over other quest items, on every client
    -- (Modules/Bags/Bags.lua:793; on Era its tooltip scan marks quest items active, :663-683).
    QuestStarterIcon = { Texture = TEX .. "BagQuestIcon.tga" },
    QuestIcon = { Texture = TEX .. "Invisible.tga" },
    UpgradeIcon = { Texture = TEX .. "BagUpgradeIcon.tga", Scale = 1.2 },
    Highlight = { Color = { 1, 1, 1, 0.3 }, BlendMode = "ADD", Inset = "Edge" },
    Pushed = { Color = { 0.9, 0.8, 0.1, 0.3 }, BlendMode = "ADD", Inset = "Edge" },
    Count = { Font = { Path = "$CountFile", Size = "$CountSize", Flags = "$CountFlags", Shadow = "$CountShadow" } },
    ItemLevel = { Font = { Path = "$LevelFile", Size = "$LevelSize", Flags = "$LevelFlags", Shadow = "$LevelShadow" } },
  },

  Settings = {
    -- The window grows as its text does (it shrinks itself to fit the screen, settings:fitScale): its sidebar and
    -- controls widen with the text, and in a window of a fixed width they spilled off the page from 30 (found in review).
    Width = widen(1000),
    Height = widen(720),
    Fill = { Color = "Body" },
    Wash = false,
    Edge = EDGE,
    -- Every row round text grows with ElvUI's font size by the lines it holds (the header its title and description, a
    -- category its name and note, a theme's card its name, status and description), and the sidebar widens with it.
    Sidebar = { Fill = { Color = "Card", Alpha = 0.5 }, Line = LINE, Width = widen(232) },
    Brand = { IconColor = "Accent", Line = { Color = "Accent", From = 1, To = 0, Size = 1 }, Height = grow(72) },
    Search = { IconColor = "Text" },
    Back = { IconColor = "Text" },
    Nav = { Indicator = { Color = "Accent", Width = 2 }, SelectedFill = ROW_CHOSEN, HoverFill = ROW_HOVER,
      ItemHeight = grow(28), GroupHeight = grow(24) },
    Version = { Bottom = grow(14) },
    Header = { Close = { Icon = "Close", Color = "Text", HoverColor = "Accent", Size = 12 }, Height = grow(100, 2) },
    Content = {
      Card = { Color = "Card", Alpha = 0.5 },
      Divider = { Color = "White", Alpha = 0.06, Size = 1 },
      Hover = { Color = "White", Alpha = 0.05 },
      TitleHeight = grow(24),
      RowHeight = grow(44),
    },
    Footer = { Line = LINE, Height = grow(56) },
    Cards = {
      Fill = { Color = "Card" },
      HoverFill = { Texture = "Highlight", Color = "White", Alpha = 0.15 },
      Edge = EDGE,
      SelectedEdge = LIT,
      Height = grow(78, 3),
    },
    Categories = { Indicator = { Color = "Accent", Width = 2 }, SelectedFill = ROW_CHOSEN, HoverFill = ROW_HOVER,
      RowHeight = grow(38, 2), GroupHeight = grow(24), LabelWidth = widen(110), FilterWidth = widen(200) },
    BagCategories = { Fill = { Color = "Card", Alpha = 0.5 }, HoverFill = ROW_HOVER, RowHeight = grow(30),
      GroupHeight = grow(24) },
    Currency = { Hover = { Color = "White", Alpha = 0.05 }, HeaderHeight = grow(26), RowHeight = grow(30) },
  },

  Controls = {
    -- HandleTrimScrollBar: the track on the transparent template, the thumb in the value color at 0.25, 0.75 under the
    -- pointer and held.
    ScrollBar = {
      Size = 6, HoverSize = 8,
      Track = { Color = "Body" },
      Thumb = { Color = "Accent", Alpha = 0.25 },
      ThumbHover = { Color = "Accent", Alpha = 0.75 },
      ThumbDrag = { Color = "Accent", Alpha = 0.75 },
    },
    -- HandleCheckBox: a 16-pixel box on the default template, ElvUI's gold square (Melli) inside its border while on;
    -- no highlight (cleared).
    Toggle = {
      Style = "Square",
      Width = 16, Height = 16, KnobSize = "Fill", KnobInset = "Edge",
      Off = { Color = "ControlFill" },
      On = { Color = "ControlFill", Alpha = 1 },
      Edge = EDGE,
      Knob = false,
      KnobOn = { Texture = "Melli", Color = "Gold", Alpha = 0.8 },
      Hover = { Color = "White", Alpha = 0 },
    },
    -- Every control's height grows with ElvUI's font size, a line of text each; a dropdown's and a number box's widths
    -- widen with it.
    Button = {
      Height = grow(26),
      Plain = button("Button", "ButtonHover"),
      Primary = button("ButtonPrimary", "ButtonHover"),
      Danger = button("ButtonDanger", "ButtonDanger"),
    },
    -- HandleEditBox: the default template; its edge does not change.
    Input = {
      Height = grow(26),
      Fill = { Color = "ControlFill" },
      FocusFill = { Color = "ControlFill" },
      Edge = { Color = "Border", Size = 1, Idle = 1, Hover = 1, Focus = 1, Outlines = "$Outlines" },
    },
    -- HandleSliderFrame: a 12-tall box on the default template, a gold square thumb 10 across; no fill.
    Slider = {
      Height = 12, TrackSize = 12, ThumbSize = 10, ValueWidth = widen(46),
      Track = { Color = "ControlFill" },
      Fill = false,
      Edge = EDGE,
      Thumb = { Texture = "Melli", Color = "Gold", Alpha = 0.8 },
      ThumbHover = { Texture = "Melli", Color = "Gold", Alpha = 1 },
    },
    -- HandleDropDownBox: the default template, ElvUI's up arrow turned down, 14 across.
    Dropdown = {
      Height = grow(26), Width = widen(170),
      Fill = { Color = "ControlFill" },
      HoverFill = { Color = "ControlFill" },
      OpenFill = { Color = "ControlFill" },
      Edge = { Color = "Border", Size = 1, Idle = 1, Hover = 1, Open = 1, Outlines = "$Outlines" },
      Chevron = { Texture = "Arrow", TexCoords = { 0, 1, 1, 0 }, Color = "Text", Size = 14 },
    },
    -- ElvUI's menus (Skins/Menu.lua): the transparent template; the chosen row's mark a square of the bar texture in the
    -- value color.
    Menu = {
      Fill = { Color = "Body" },
      Edge = EDGE,
      HoverFill = ROW_HOVER,
      Check = { Texture = "$Norm", Color = "Accent", Size = 10 },
      ItemHeight = grow(24),
      -- Its head: two lines of text beside the icon, which grows with them.
      Picker = { NewIcon = { Color = "Accent" }, BackIcon = { Color = "Text" }, IconSize = grow(32, 2) },
    },
    Swatch = { Edge = EDGE, HoverEdge = LIT },
    TopTabs = { Indicator = { Color = "Accent", Height = 2 }, Line = LINE, Height = grow(34) },
    -- ElvUI's popups: the transparent template.
    Dialog = { Card = { Color = "Body" }, Edge = EDGE },
    ItemGrid = { CommonEdge = EDGE, Hover = { Color = "White", Alpha = 0.3 } },
  },

  -- On Era ElvUI marks every quest item active but a quest starter (its tooltip scan, Modules/Bags/Bags.lua:661-685):
  -- its quest item color for every one but a starter.
  Clients = {
    Era = { ItemButton = { QuestBorderColor = "$QuestItem", QuestStarterBorderColor = "$QuestStarter" } },
  },
}

for name, ref in pairs(sizes) do
  theme.Variables[name] = ref
end
sonataNext:RegisterTheme(theme)
