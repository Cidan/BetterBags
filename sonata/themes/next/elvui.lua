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
--   Text in ElvUI's font and style; sizes fixed per role (a theme drawn again at other sizes makes new font objects,
--     which can never be freed).
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
local FAINT = { 0, 0, 0, 0.6 }
local SHADOW_COLORS = {
  NONE = FAINT, OUTLINE = FAINT, THICKOUTLINE = FAINT, MONOCHROME = FAINT, MONOCHROMEOUTLINE = FAINT,
  MONOCHROMETHICKOUTLINE = FAINT, SHADOW = { 0, 0, 0, 1 }, SHADOWOUTLINE = FAINT, SHADOWTHICKOUTLINE = FAINT,
}

-- A text role in ElvUI's font and style, size and color its own.
---@param size number
---@param color string
---@return table
local function text(size, color)
  return { File = "$Font", Flags = "$FontFlags", Shadow = "$Shadowed", Size = size, Color = color }
end

-- ElvUI's one-pixel edge (SetTemplate: E.twoPixelsPlease is always false, General/Initialize.lua:103), and lit.
local EDGE = { Color = "Border", Alpha = 1, Size = 1 }
local LIT = { Color = "Accent", Alpha = 1, Size = 1 }
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
-- StyleButton's under the pointer and pressed, inside the border.
local INSIDE = { Left = 1, Right = 1, Top = 1, Bottom = 1 }

sonataNext:RegisterTheme({
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
  },
  -- ElvUI's options call E:UpdateMedia after every change (ElvUI_Options/Game/Shared/General.lua), and its start calls
  -- E:UpdateTexCoords after E:UpdateMedia (General/Core.lua:2047-2055).
  Watch = {
    { Global = "ElvUI", Path = { 1 }, Method = "UpdateMedia" },
    { Global = "ElvUI", Path = { 1 }, Method = "UpdateTexCoords" },
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
    -- Its quest colors (Defaults/Profile.lua:534-535): an item that starts a quest, and a quest's item.
    QuestStarter = { 1, 0.96, 0.41, 1 },
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
    Price = text(11, "White"),
    PriceUnaffordable = text(11, "Unaffordable"),
    VendorName = text(11, "Text"),
    -- The bags' counts in ElvUI's: Homespun 10, MONOCHROMEOUTLINE (Defaults/Profile.lua:487-489).
    Stack = { Object = "NumberFontNormal", File = MEDIA .. "Fonts\\Homespun.ttf", Size = 10, Flags = "MONOCHROMEOUTLINE" },
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
    TitleTop = 18,
    TitleInset = 2,
    SearchTop = 46,
    SearchHeight = 20,
    ContentTop = 76,
    Footer = 30,
    FooterText = 10,
    FooterMoney = 9,
    SectionHeader = 20,
    SectionSpacing = 10,
    TabHeight = 24,
    TabSpacing = 2,
    TabPadding = 10,
    -- Its bag buttons are 20 across (Modules/Bags/Bags.lua:2512-2543), 5 apart.
    HeaderButton = 20,
    HeaderButtonGap = 5,
    HeaderButtonTop = 16,
  },

  -- ElvUI's frames appear where they go: no bounce.
  Motion = { Ease = { Open = "outCubic", Enter = "outCubic" } },

  Panel = {
    Fill = { Color = "Body" },
    Feather = false,
    Wash = false,
    Edge = { Color = "Border", Alpha = 1, Size = 1, Full = true },
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
    Edge = { Color = "Border", Size = 1, Idle = 1, Hover = 1, Focus = 1 },
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
    Tracker = { Fill = { Color = "Body" }, Edge = EDGE },
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
    Icon = { Inset = 1, TexCoords = "$TexCoords" },
    Backdrop = { Texture = "$Gloss", VertexColor = "$Backdrop", BorderColor = "$Border", EdgeSize = 1 },
    QualityBorder = { Texture = "Interface\\Common\\WhiteIconFrame", Alpha = 1 },
    QualityColors = { [0] = "$Border", [1] = "$Border" },
    QuestBorderColor = { 1, 0.96, 0.41, 1 },
    -- Its "!" only on an item that starts a quest not yet taken, nothing over other quest items, on every client
    -- (Modules/Bags/Bags.lua:793; on Era its tooltip scan marks quest items active, :663-683).
    QuestStarterIcon = { Texture = TEX .. "BagQuestIcon.tga" },
    QuestIcon = { Texture = TEX .. "Invisible.tga" },
    UpgradeIcon = { Texture = TEX .. "BagUpgradeIcon.tga", Scale = 1.2 },
    Highlight = { Color = { 1, 1, 1, 0.3 }, BlendMode = "ADD", Inset = INSIDE },
    Pushed = { Color = { 0.9, 0.8, 0.1, 0.3 }, BlendMode = "ADD", Inset = INSIDE },
    Count = { Font = { Path = MEDIA .. "Fonts\\Homespun.ttf", Size = 10, Flags = "MONOCHROMEOUTLINE" } },
  },

  Settings = {
    Fill = { Color = "Body" },
    Wash = false,
    Edge = EDGE,
    Sidebar = { Fill = { Color = "Card", Alpha = 0.5 }, Line = EDGE },
    Brand = { IconColor = "Accent", Line = { Color = "Accent", From = 1, To = 0, Size = 1 } },
    Search = { IconColor = "Text" },
    Back = { IconColor = "Text" },
    Nav = { Indicator = { Color = "Accent", Width = 2 }, SelectedFill = ROW_CHOSEN, HoverFill = ROW_HOVER },
    Header = { Close = { Icon = "Close", Color = "Text", HoverColor = "Accent", Size = 12 } },
    Content = {
      Card = { Color = "Card", Alpha = 0.5 },
      Divider = { Color = "White", Alpha = 0.06, Size = 1 },
      Hover = { Color = "White", Alpha = 0.05 },
    },
    Footer = { Line = EDGE },
    Cards = {
      Fill = { Color = "Card" },
      HoverFill = { Texture = "Highlight", Color = "White", Alpha = 0.15 },
      Edge = EDGE,
      SelectedEdge = LIT,
    },
    Categories = { Indicator = { Color = "Accent", Width = 2 }, SelectedFill = ROW_CHOSEN, HoverFill = ROW_HOVER },
    BagCategories = { Fill = { Color = "Card", Alpha = 0.5 }, HoverFill = ROW_HOVER },
    Currency = { Hover = { Color = "White", Alpha = 0.05 } },
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
      Width = 16, Height = 16, KnobSize = 14, KnobInset = 1,
      Off = { Color = "ControlFill" },
      On = { Color = "ControlFill", Alpha = 1 },
      Edge = EDGE,
      Knob = false,
      KnobOn = { Texture = "Melli", Color = "Gold", Alpha = 0.8 },
      Hover = { Color = "White", Alpha = 0 },
    },
    Button = {
      Plain = button("Button", "ButtonHover"),
      Primary = button("ButtonPrimary", "ButtonHover"),
      Danger = button("ButtonDanger", "ButtonDanger"),
    },
    -- HandleEditBox: the default template; its edge does not change.
    Input = {
      Fill = { Color = "ControlFill" },
      FocusFill = { Color = "ControlFill" },
      Edge = { Color = "Border", Size = 1, Idle = 1, Hover = 1, Focus = 1 },
    },
    -- HandleSliderFrame: a 12-tall box on the default template, a gold square thumb 10 across; no fill.
    Slider = {
      Height = 12, TrackSize = 12, ThumbSize = 10,
      Track = { Color = "ControlFill" },
      Fill = false,
      Edge = EDGE,
      Thumb = { Texture = "Melli", Color = "Gold", Alpha = 0.8 },
      ThumbHover = { Texture = "Melli", Color = "Gold", Alpha = 1 },
    },
    -- HandleDropDownBox: the default template, ElvUI's up arrow turned down, 14 across.
    Dropdown = {
      Fill = { Color = "ControlFill" },
      HoverFill = { Color = "ControlFill" },
      OpenFill = { Color = "ControlFill" },
      Edge = { Color = "Border", Size = 1, Idle = 1, Hover = 1, Open = 1 },
      Chevron = { Texture = "Arrow", TexCoords = { 0, 1, 1, 0 }, Color = "Text", Size = 14 },
    },
    -- ElvUI's menus (Skins/Menu.lua): the transparent template; the chosen row's mark a square of the bar texture in the
    -- value color.
    Menu = {
      Fill = { Color = "Body" },
      Edge = EDGE,
      HoverFill = ROW_HOVER,
      Check = { Texture = "$Norm", Color = "Accent", Size = 10 },
      Picker = { NewIcon = { Color = "Accent" }, BackIcon = { Color = "Text" } },
    },
    Swatch = { Edge = EDGE, HoverEdge = LIT },
    TopTabs = { Indicator = { Color = "Accent", Height = 2 }, Line = EDGE },
    -- ElvUI's popups: the transparent template.
    Dialog = { Card = { Color = "Body" }, Edge = EDGE },
    ItemGrid = { CommonEdge = EDGE, Hover = { Color = "White", Alpha = 0.3 } },
  },
})
