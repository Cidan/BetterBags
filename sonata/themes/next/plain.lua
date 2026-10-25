local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- Plain is the default UI of the game played (asked: "the Plain theme looks like the default UI for the version of WoW
-- we're playing on"; docs/next-plain-theme.md). Every piece is Blizzard's own, named as Blizzard's UI source names it
-- (.libraries/wow-ui-source, one branch per client), and drawn by BetterBags Next from data:
--   Retail and WoW: Forever (Clients.Retail): the bag window (ContainerFrameCombinedBags: PortraitFrameFlatTemplate,
--     HeldBagLayout's metal with the portrait corner, the flat fill in PANEL_BACKGROUND_COLOR, the round portrait, the
--     title centered, the red close button), Blizzard's dropdowns and menus (Blizzard_Menu/Mainline).
--   Classic, Era, TBC, Anniversary, Mists and Cata (Clients.Classic): the settings window's frame (SettingsFrameTemplate:
--     ButtonFrameTemplateNoPortrait's Classic art, its title band, the flat fill), Classic's close button, the Classic
--     dropdowns and menus (Blizzard_Menu/Classic). Classic's own bag art comes in fixed sizes per bag and cannot stretch
--     to a window of any size.
--   Every client: the settings controls (SettingsCheckboxTemplate, MinimalSliderTemplate, MinimalScrollBar), the input
--     border (InputBoxVisualTemplate), the panel button (UIPanelButtonNoTooltipTemplate), the bag sort button, the
--     settings list's rows and headers (Blizzard_CategoryList.lua), the dialog (StaticPopup: the Dialog layout over
--     UI-DialogBox-Background), and the client's own fonts (FontStyles.xml), copied.
-- The tabs are Blizzard's list rows: Blizzard has no sideways text tabs. Header buttons Blizzard has no art for are
-- BetterBags' glyphs in Blizzard's gold, white under the pointer. No sparkles, feather, wash, ribbon, cloud, glow or
-- braid. Data only.

-- UIPanelButtonNoTooltipTemplate: one file in three pieces, its caps 12 wide (TexCoords measured by Blizzard's XML);
-- UIPanelButton_OnMouseDown and OnDisable draw the Down and Disabled files the same way.
local function panelButton(file)
  return { Pieces = "Horizontal", Texture = file, Color = "White", Alpha = 1,
    Begin = { TexCoords = { 0, 0.09375, 0, 0.6875 }, Size = 12 },
    Middle = { TexCoords = { 0.09375, 0.53125, 0, 0.6875 } },
    End = { TexCoords = { 0.53125, 0.625, 0, 0.6875 }, Size = 12 } }
end
local BUTTON = {
  Fill = panelButton("Interface\\Buttons\\UI-Panel-Button-Up"),
  HoverFill = panelButton("Interface\\Buttons\\UI-Panel-Button-Up"),
  PressedFill = panelButton("Interface\\Buttons\\UI-Panel-Button-Down"),
  DisabledFill = panelButton("Interface\\Buttons\\UI-Panel-Button-Disabled"),
  -- UIPanelButtonHighlightTexture, added over the button under the pointer.
  Highlight = { Texture = "Interface\\Buttons\\UI-Panel-Button-Highlight", TexCoords = { 0, 0.625, 0, 0.6875 },
    BlendMode = "ADD", Color = "White", Alpha = 1 },
  Edge = false, HoverEdge = false,
  Font = "Button", HoverFont = "ButtonHover", DisabledFont = "ButtonDisabled",
}

-- MinimalScrollBar's thumb: its top, middle and bottom, idle, under the pointer (-over) and dragged (-down).
local function thumb(suffix)
  return { Pieces = "Vertical", Color = "White", Alpha = 1,
    Begin = { Atlas = "minimal-scrollbar-small-thumb-top" .. suffix },
    Middle = { Atlas = "minimal-scrollbar-small-thumb-middle" .. suffix },
    End = { Atlas = "minimal-scrollbar-small-thumb-bottom" .. suffix } }
end

-- MinimalTabTemplate's art: Options_Tab_Left, _Middle and _Right (Options_Tab_Active_* chosen), each at its atlas size,
-- by their bottoms (MinimalTabMixin:UpdateAtlas).
local function tab(state)
  return { Pieces = "Horizontal", Thickness = "Atlas", Align = "BOTTOM", Color = "White", Alpha = 1,
    Begin = { Atlas = "Options_Tab_" .. state .. "Left" }, Middle = { Atlas = "Options_Tab_" .. state .. "Middle" },
    End = { Atlas = "Options_Tab_" .. state .. "Right" } }
end

-- DefaultPanelTemplate (Blizzard_SharedXML/<Family>/SharedUIPanelTemplates.xml), the original bags' and the What's New
-- window's: its Bg, Interface\FrameGeneral\UI-Background-Rock tiled both ways, 6 in from the left, 21 from the top, 2 from
-- the right and the bottom.
local ROCK = { Texture = "Interface\\FrameGeneral\\UI-Background-Rock", HorizTile = true, VertTile = true, Color = "White",
  Alpha = 1, Inset = { Left = 6, Right = 2, Top = 21, Bottom = 2 } }
-- Its TopTileStreaks over the rock, 21 down, 6 in to 2 from the right: retail's _UI-Frame-TopTileStreaks atlas (256 x 43,
-- tiled across); Classic's a strip of Interface\FrameGeneral\_UI-Frame (0.671875 to 0.9609375 down it, 37 tall).
local STREAKS = { Atlas = "_UI-Frame-TopTileStreaks", HorizTile = true, Color = "White", Alpha = 1, Height = 43, Left = 6,
  Right = 2, Top = 21 }
local CLASSIC_STREAKS = { Texture = "Interface\\FrameGeneral\\_UI-Frame", TexCoords = { 0, 1, 0.671875, 0.9609375 },
  HorizTile = true, Color = "White", Alpha = 1, Height = 37, Left = 6, Right = 2, Top = 21 }
-- Classic's TitleBg (DefaultPanelBaseTemplate's, retail's has none): _UI-Frame-TitleTileBg, a 17-pixel strip of _UI-Frame
-- tiled across, 23 left of the TitleContainer (30 in) and 3 below its top (1 down), to its right (24 from the right).
local TITLE_BAND = { Texture = "Interface\\FrameGeneral\\_UI-Frame", TexCoords = { 0, 1, 0.2890625, 0.421875 },
  HorizTile = true, Color = "White", Alpha = 1, Height = 17, Left = 7, Right = 24, Top = 4 }

-- The original bags' menu button (frames/menubutton.lua): Bagslots2x's first fifth, 48 x 60, centered on a 40-square
-- button at TOPLEFT -10, 7, so 14 out from the corner and 17 above it; over the border and the search box (the button is
-- strata HIGH); never flipped. On every bag, as the original's backpack and bank both had it.
local BAG_ICON = { Texture = "Interface\\Containerframe\\Bagslots2x", TexCoords = { 0, 0.2, 0, 1 }, Point = "TOPINNER",
  Width = 48, Height = 60, X = -14, Y = -17, Mirror = false, Above = true, Layer = "OVERLAY", SubLevel = 7 }

-- WowStyle2DropdownTemplate's Background: its atlas 7 past the dropdown on every side (sliced 12 either side, so it
-- stretches across); a stepper's (WowStyle2IconButtonTemplate) at the atlas's own size centered on the button.
local function cButton(atlas)
  return { Atlas = atlas, Color = "White", Alpha = 1, Inset = { Left = -7, Top = -7, Right = -7, Bottom = -7 } }
end
local function stepperArt(atlas)
  return { Atlas = atlas, Color = "White", Alpha = 1, AtlasSize = true }
end

-- The settings list's rows (Blizzard_CategoryList.lua): lit under the pointer, chosen.
local LIST_HOVER = { Atlas = "Options_List_Hover", Color = "White", Alpha = 1 }
local LIST_ACTIVE = { Atlas = "Options_List_Active", Color = "White", Alpha = 1 }

sonataNext:RegisterTheme({
  Name = "Plain",
  DisplayName = "Plain",
  Description = "The game's own look: Blizzard's frames, buttons and fonts, for the version of the game you play.",

  Palette = {
    -- The client's own colors (Color.lua makes every named UI color a global).
    Panel = { Global = "PANEL_BACKGROUND_COLOR" },
    Gold = { Global = "NORMAL_FONT_COLOR" },
    White = { Global = "HIGHLIGHT_FONT_COLOR" },
    Gray = { Global = "DISABLED_FONT_COLOR" },
    -- BetterBags' glyphs in Blizzard's gold.
    ButtonIcon = { Global = "NORMAL_FONT_COLOR" },
    -- SearchBoxTemplate's magnifier: gray, white while typed in (SearchBoxTemplate_OnEditFocusLost/Gained).
    SearchIcon = { 0.6, 0.6, 0.6, 1 },
    Scrim = { 0, 0, 0, 0.5 },
    Shade = { 0, 0, 0, 0.25 },
    Lit = { 1, 1, 1, 0.08 },
  },

  -- The client's own font objects, copied outright (Copy, next-themes.md §4): their file, size, color and shadow in every
  -- locale, nothing of Default's roles changing them.
  Fonts = {
    Title = { Copy = "GameFontNormal" },
    Section = { Copy = "GameFontNormal" },
    SectionRecent = { Copy = "GameFontHighlight" },
    SectionFree = { Copy = "GameFontDisable" },
    Count = { Copy = "GameFontDisableSmall" },
    Tab = { Copy = "GameFontNormal" },
    TabSelected = { Copy = "GameFontHighlight" },
    Footer = { Copy = "GameFontHighlightSmall" },
    Empty = { Copy = "GameFontDisable" },
    DragHint = { Copy = "GameFontHighlight" },
    ConfirmTitle = { Copy = "GameFontNormalLarge" },
    ConfirmWarning = { Copy = "GameFontRed" },
    ConfirmHint = { Copy = "GameFontHighlightSmall" },
    -- The bag search box's help text (InputBoxInstructionsTemplate: GameFontDisableSmall) and what is typed.
    Search = { Copy = "GameFontDisableSmall" },
    SearchText = { Copy = "GameFontHighlightSmall" },
    Price = { Copy = "GameFontHighlightSmall" },
    PriceUnaffordable = { Copy = "GameFontRedSmall" },
    VendorName = { Copy = "GameFontHighlightSmall" },
    ControlText = { Copy = "GameFontHighlightSmall" },
    ControlMuted = { Copy = "GameFontDisableSmall" },
    ControlHelp = { Copy = "GameFontDisableSmall" },
    -- UIPanelButtonNoTooltipTemplate's NormalFont, HighlightFont and DisabledFont.
    Button = { Copy = "GameFontNormal" },
    ButtonPrimary = { Copy = "GameFontNormal" },
    ButtonDanger = { Copy = "GameFontNormal" },
    ButtonHover = { Copy = "GameFontHighlight" },
    ButtonDisabled = { Copy = "GameFontDisable" },
    Link = { Copy = "GameFontNormal" },
    LinkHover = { Copy = "GameFontHighlight" },
    -- Blizzard_Menu's rows (Compositor.lua: GameFontHighlight), the chosen one too (its tick marks it).
    MenuItem = { Copy = "GameFontHighlight" },
    MenuItemSelected = { Copy = "GameFontHighlight" },
    -- WowStyle2DropdownTemplate's text (the settings dropdowns, every client), gray while disabled (DISABLED_FONT_COLOR).
    DropdownText = { Copy = "GameFontNormal" },
    DropdownDisabled = { Copy = "GameFontDisable" },
    -- MinimalSliderWithSteppersTemplate's RightText, gray while disabled (GRAY_FONT_COLOR).
    SliderValue = { Copy = "GameFontNormal" },
    SliderValueDisabled = { Copy = "GameFontDisable" },
    DialogTitle = { Copy = "GameFontNormal" },
    DialogText = { Copy = "GameFontHighlight" },
    TopTab = { Copy = "GameFontNormalSmall" },
    TopTabHover = { Copy = "GameFontHighlightSmall" },
    TopTabSelected = { Copy = "GameFontHighlightSmall" },
    SettingsBrand = { Copy = "GameFontNormalLarge" },
    -- The settings list's headers (SettingsCategoryListHeaderTemplate: GameFontHighlightMedium) and rows
    -- (GameFontNormal, GameFontHighlight chosen).
    SettingsNavGroup = { Copy = "GameFontHighlightMedium" },
    SettingsNav = { Copy = "GameFontNormal" },
    -- Under the pointer a row keeps its font, its art lights (SettingsCategoryListButtonMixin:UpdateStateInternal).
    SettingsNavHover = { Copy = "GameFontNormal" },
    SettingsNavSelected = { Copy = "GameFontHighlight" },
    SettingsVersion = { Copy = "GameFontDisableSmall" },
    SettingsTitle = { Copy = "GameFontHighlightHuge" },
    SettingsDescription = { Copy = "GameFontHighlightSmall" },
    SettingsSection = { Copy = "GameFontHighlightLarge" },
    SettingsSectionNote = { Copy = "GameFontDisableSmall" },
    SettingsLabel = { Copy = "GameFontNormal" },
    SettingsText = { Copy = "GameFontHighlightSmall" },
    SettingsLink = { Copy = "GameFontNormal" },
  },

  Layout = {
    -- ContainerFrameItemButtonTemplate's 37, ITEM_SPACING_X and Y 5 (ContainerFrame.lua).
    Icon = 37,
    Gap = 5,
    -- Clear of the frame's edges: Blizzard insets its fill 2 to 7 from the sides.
    Pad = 10,
    -- The title's top 6 below the frame's (TitleContainer at -1, its text at -5 in it), in the title bar, centered from 30
    -- in (the TitleContainer's left: Pad in plus TitleInset) to the buttons.
    TitleTop = 6,
    TitleInset = 20,
    -- The search box where the original bags put it (sonata/themes/base.lua: 30 down, 20 tall), and their content from
    -- 62 down (their insets' 42 and the search box's 20).
    SearchTop = 30,
    SearchHeight = 20,
    SearchIcon = 10,
    SearchGap = 6,
    SearchRight = 20,
    ContentTop = 62,
    Footer = 28,
    FooterText = 9,
    FooterMoney = 8,
    SectionHeader = 22,
    SectionSpacing = 12,
    TabHeight = 26,
    TabSpacing = 2,
    TabMinWidth = 70,
    TabPadding = 12,
    TabHover = 4,
    -- UIPanelCloseButton's 24, the header's buttons in the title bar beside it.
    HeaderButton = 24,
    HeaderButtonGap = 2,
    HeaderButtonTop = 0,
  },

  -- Blizzard's windows open without a bounce.
  Motion = { Ease = { Open = "outCubic", Enter = "outCubic" } },

  -- The original bags' window (DefaultPanelTemplate, asked: "the stone window background"): the rock, the frame over the
  -- content as the original raised it (Sonata's Default: NineSlice at +500), the streaks, the bag icon.
  Panel = {
    Fill = ROCK,
    Frame = { Layout = "ButtonFrameTemplateNoPortrait", Above = true, Bands = { STREAKS } },
    Ornaments = { BAG_ICON },
    Feather = false,
    Wash = false,
    Edge = false,
    DropGlow = { Color = "Gold", Alpha = 0.12, BlendMode = "ADD" },
  },

  Header = {
    Title = { Font = "Title", Justify = "CENTER" },
    TitleGlow = false,
    Ribbon = false,
    Spark = false,
    Cloud = false,
    Buttons = {
      Color = "ButtonIcon", HoverColor = "White", ArtColor = "White", ArtHoverColor = "White", DisabledAlpha = 0.4,
      Scale = 0.7,
      -- The row in the title bar, past the close button in the corner.
      RowStart = 26,
      Icons = {
        -- BagItemAutoSortButton: bags-button-autosort-up, -down pressed, ButtonHilight-Square added under the pointer.
        sortButton = { Atlas = "bags-button-autosort-up", Glyph = false, Scale = 1 / 0.7,
          Pushed = { Atlas = "bags-button-autosort-down" },
          Highlight = { Texture = "Interface\\Buttons\\ButtonHilight-Square", BlendMode = "ADD" } },
      },
    },
  },

  -- The bag search box as Blizzard draws it (BagSearchBoxTemplate's InputBoxVisualTemplate border), 20 in and 10 from the
  -- right as the original bags put it, its insides as SearchBoxTemplate lays them out (InputBoxTemplates.xml): the
  -- magnifier 10 x 10 at LEFT 1, -1, the text 16 in and 20 from the right, the clear button at RIGHT -3, the help in
  -- InputBoxInstructionsTemplate's 0.35 gray.
  Search = {
    Template = true,
    Inset = { Left = 20, Right = 10 },
    Inner = { IconX = 1, IconY = -1, IconSize = 10, TextLeft = 16, TextRight = 20, ClearRight = 3 },
    HelpColor = { 0.35, 0.35, 0.35, 1 },
    -- Gray while empty and not typed in, white while typed in or holding a search (SearchBoxTemplate_OnEditFocusLost).
    Icon = { Color = "SearchIcon", Idle = 1, Active = 1, FocusColor = "White", ActiveColor = "White" },
    HelpFont = "Search",
    TextFont = "SearchText",
  },

  Sections = {
    Line = false,
    Highlight = LIST_HOVER,
  },

  -- The settings list's rows: the panel's color, lit under the pointer, chosen.
  Tabs = {
    Fill = "Panel",
    SelectedFill = "Panel",
    Fade = 1,
    Font = "Tab",
    SelectedFont = "TabSelected",
    Glow = { Color = "Gold", BlendMode = "ADD", Drop = 0.3, Pulse = 0.8 },
    Indicator = false,
    Highlight = LIST_HOVER,
    SelectedHighlight = LIST_ACTIVE,
  },

  Footer = { Line = false },

  Sparkles = false,

  Chain = { Braid = false, Color = "Gold", KnotColor = "Gold" },

  Dock = {
    -- The popup's background (GameDialog.lua).
    Card = { Atlas = "UI-DialogBox-Background-Dark", Color = "White", Alpha = 1 },
    Glow = { Color = "Gold" },
    Halo = false,
  },

  Vendor = {
    CardFill = "Shade",
    CardHover = "Lit",
    -- No taller than the price (GameFontHighlightSmall).
    CoinSize = 11,
  },

  -- Blizzard's settings window (Blizzard_SettingsPanel.xml, the same on every client: 920 x 724), in the original bags'
  -- stone as the What's New window (asked); its frame at its own level, its content placed inside it
  -- (SettingsFrameTemplate: NineSlice useParentLevel).
  Settings = {
    Width = 920, Height = 724,
    Fill = ROCK,
    Frame = { Layout = "ButtonFrameTemplateNoPortrait", Bands = { STREAKS } },
    Wash = false,
    Edge = false,
    -- Its name in the title bar (DefaultPanelBaseTemplate's TitleContainer, 30 in to 24 from the right, its text 5 below
    -- its top 1 down), the bar moving the window.
    Title = { Font = "Title", Top = 6, Left = 30, Right = 24, Height = 22 },
    -- Options_InnerFrame at its size (886 x 618) at 17, -64: the list's column and the content inside a soft frame.
    InnerFrame = { Atlas = "Options_InnerFrame", AtlasSize = true, Point = "TOPLEFT", X = 17, Y = -64, Color = "White", Alpha = 1 },
    -- The category list (SettingsCategoryListTemplate) at 18, 76, 199 wide, down to 46 above the bottom.
    Sidebar = { Width = 199, Pad = 0, Left = 18, Top = 76, Bottom = 46, Fill = false, Line = false },
    Brand = false,
    -- Its search box (SearchBoxTemplate) 350 wide, its bottom right 4 right of and 20 above the content's top right: 18 from
    -- the window's right, 34 down; the template's magnifier.
    Search = { Place = "Top", Width = 350, Right = 18, Top = 34, Atlas = "common-search-magnifyingglass", IconSize = 10,
      IconColor = "SearchIcon" },
    Back = { IconColor = "Gold", Height = 30 },
    Version = { Window = true, Left = 18, Bottom = 22 },
    -- Blizzard's settings list (Blizzard_CategoryList.lua): rows 175 x 20, their label 36 in and 1 above the middle, their
    -- art at its own size, centered; headers 175 x 30 in Options_CategoryHeader_1 to 3, cycled, at their top left, their
    -- labels 20 in and 1 down, as written (SettingsCategoryListHeaderTemplate); 2 between every one (its view's spacing).
    Nav = {
      ItemWidth = 175, ItemHeight = 20, GroupHeight = 30, GroupGap = 0, Spacing = 2, TextRaise = 1, Indent = 36,
      GroupUpper = false,
      Indicator = false,
      SelectedFill = { Atlas = "Options_List_Active", Color = "White", Alpha = 1, AtlasSize = true },
      HoverFill = { Atlas = "Options_List_Hover", Color = "White", Alpha = 1, AtlasSize = true },
      GroupFills = {
        { Atlas = "Options_CategoryHeader_1", Color = "White", Alpha = 1, AtlasSize = true, Point = "TOPLEFT" },
        { Atlas = "Options_CategoryHeader_2", Color = "White", Alpha = 1, AtlasSize = true, Point = "TOPLEFT" },
        { Atlas = "Options_CategoryHeader_3", Color = "White", Alpha = 1, AtlasSize = true, Point = "TOPLEFT" },
      },
      GroupLabel = { Point = "LEFT", X = 20, Y = -1 },
    },
    -- The content (its Container) from 16 right of the list to 22 from the window's right; its header (SettingsListTemplate)
    -- 50 tall at its top, the page's name 7 in and 22 down, Options_HorizontalDivider centered 50 down, no description;
    -- a page's buttons where its Defaults button is (36 from the header's right, 16 down).
    Header = { Left = 16, Right = 22, Top = 76, Height = 50, Pad = 7, TitleTop = 22, DescriptionFont = false,
      Divider = { Atlas = "Options_HorizontalDivider", AtlasSize = true, Point = "TOP", Y = -50, Color = "White", Alpha = 1 },
      Actions = { Top = 16, Right = 36, Gap = 8 } },
    -- A page's tabs on the inner frame's top edge, 27 down (MinimalTabTemplate's place in Blizzard's window).
    Tabs = { Top = 27, Left = 0 },
    -- The list (SettingsListTemplate) from 15 left of the content and 2 below its header to 20 in from its right, 25 in
    -- and 10 from its top, 9 between every element; a section's title 45 tall, 7 in and 16 down, as written
    -- (SettingsListSectionHeaderTemplate); rows 26 tall, one column, the name 37 in up to 85 left of the middle, each
    -- control placed from the middle as SettingControls places it; a row lit white at 0.1 under the pointer, 10 past its
    -- left to 5 short of its right (HoverBackgroundTemplate); no cards or lines. The dropdown 46.5 left of the middle: 220
    -- wide, centered in Blizzard's 223-wide control placed 48 left of it (SettingsDropdownControlMixin).
    Content = { Layout = "List", ScrollLeft = -15, ScrollRight = 20, ScrollTop = 2, Pad = 25, PadRight = 0, Top = 10,
      Bottom = 10, RowGap = 9, SectionHeight = 45, TitleX = 7, TitleTop = 16, TitleUpper = false, RowHeight = 26,
      LabelX = 37, LabelRight = -85,
      Controls = { toggle = { X = -80 }, slider = { X = -80, Y = 3 }, dropdown = { X = -46.5, Y = 3 }, color = { X = -73 },
        input = { X = -80 }, buttons = { X = -40 } },
      HoverInset = { Left = -10, Right = 5 }, Card = false, Divider = false, Hover = { Color = "White", Alpha = 0.1 } },
    -- Done (its Close) 96 x 22 at 16, 16 from the bottom right, What's New in its Apply button's place, 2 left of it.
    Footer = { Height = 45, Left = 0, Line = false, Buttons = { Width = 96, Right = 16, Bottom = 16, Gap = 2 }, WhatsNew = "Plain" },
    Categories = { Indicator = false, SelectedFill = LIST_ACTIVE, HoverFill = LIST_HOVER },
    BagCategories = { Fill = { Color = "Shade" }, HoverFill = LIST_HOVER },
    Currency = { Hover = LIST_HOVER },
    Cards = {
      Fill = { Color = "Shade" }, HoverFill = { Color = "Lit" },
      Edge = { Color = "Gold", Alpha = 0.3 }, SelectedEdge = { Color = "Gold", Alpha = 1 },
    },
  },

  Controls = {
    ScrollBar = {
      Width = 10, Size = 8, HoverSize = 8,
      Track = { Pieces = "Vertical", Color = "White", Alpha = 1, Begin = { Atlas = "minimal-scrollbar-track-top" },
        Middle = { Atlas = "!minimal-scrollbar-track-middle" }, End = { Atlas = "minimal-scrollbar-track-bottom" } },
      Thumb = thumb(""),
      ThumbHover = thumb("-over"),
      ThumbDrag = thumb("-down"),
    },
    -- SettingsCheckboxTemplate: 30 x 29, checkbox-minimal, checkmark-minimal over it (-disabled while disabled).
    Toggle = {
      Style = "Check",
      Width = 30, Height = 29,
      Off = { Atlas = "checkbox-minimal", Color = "White", Alpha = 1 },
      On = { Atlas = "checkmark-minimal", Color = "White", Alpha = 1 },
      Disabled = { Atlas = "checkbox-minimal", Desaturated = true, Color = "White", Alpha = 1 },
      DisabledOn = { Atlas = "checkmark-minimal-disabled", Color = "White", Alpha = 1 },
      Hover = false,
    },
    -- UIPanelButtonNoTooltipTemplate: 22 tall, 20 either side of its label (fitTextWidthPadding 40), at least 40.
    Button = {
      Height = 22, Padding = 20, MinWidth = 40, DisabledAlpha = 1,
      Plain = BUTTON, Primary = BUTTON, Danger = BUTTON,
      Link = { Font = "Link", HoverFont = "LinkHover" },
    },
    -- InputBoxVisualTemplate: common-search-border, 20 tall, its left cap 8 wide and 5 past the field.
    Input = {
      Height = 20, Padding = 6,
      Fill = { Pieces = "Horizontal", Thickness = 20, Inset = { Left = -5 }, Color = "White", Alpha = 1,
        Begin = { Atlas = "common-search-border-left", Size = 8 }, Middle = { Atlas = "common-search-border-middle" },
        End = { Atlas = "common-search-border-right", Size = 8 } },
      FocusFill = { Pieces = "Horizontal", Thickness = 20, Inset = { Left = -5 }, Color = "White", Alpha = 1,
        Begin = { Atlas = "common-search-border-left", Size = 8 }, Middle = { Atlas = "common-search-border-middle" },
        End = { Atlas = "common-search-border-right", Size = 8 } },
      Edge = false,
    },
    ItemGrid = {
      CommonEdge = { Color = "White", Alpha = 0.25 },
      Hover = { Color = "White", Alpha = 0.15 },
    },
    -- The settings slider (MinimalSliderWithSteppersTemplate, 250 wide): its bar (MinimalSliderTemplate, 19 tall, in three
    -- pieces at their atlas sizes centered on it, its thumb Minimal_SliderBar_Button at its atlas size) 19 in from each
    -- side, the back and forward steppers (Minimal_SliderBar_Button_Left 11 x 19, _Right 9 x 18) 4 out from its ends, at
    -- 0.5 and desaturated where the value can go no further; the value in GameFontNormal 25 right of it, gray and the
    -- slider at 0.7 while disabled (MinimalSlider.lua).
    Slider = {
      Width = 212, Height = 19, TrackSize = 19, ThumbSize = "Atlas",
      Track = { Pieces = "Horizontal", Thickness = "Atlas", Color = "White", Alpha = 1, Begin = { Atlas = "Minimal_SliderBar_Left" },
        Middle = { Atlas = "_Minimal_SliderBar_Middle" }, End = { Atlas = "Minimal_SliderBar_Right" } },
      Fill = false,
      Thumb = { Atlas = "Minimal_SliderBar_Button", Color = "White", Alpha = 1 },
      ThumbHover = { Atlas = "Minimal_SliderBar_Button", Color = "White", Alpha = 1 },
      Steppers = { Back = { Atlas = "Minimal_SliderBar_Button_Left", Width = 11, Height = 19 },
        Forward = { Atlas = "Minimal_SliderBar_Button_Right", Width = 9, Height = 18 }, Gap = 4, Room = 19, DisabledAlpha = 0.5 },
      Value = "Text", ValueGap = 25, ValueFont = "SliderValue", ValueDisabledFont = "SliderValueDisabled", DisabledAlpha = 0.7,
    },
    -- The settings dropdown (WowStyle2DropdownTemplate, every client): 220 x 25, common-dropdown-c-button 7 past it in its
    -- art for each state (WowStyle2DropdownMixin:GetBackgroundAtlas), the choice centered 13 in from each side in gold
    -- (gray disabled), the arrow (common-dropdown-c-button-hover-arrow) 5 below its bottom under the pointer; the back and
    -- next steppers (WowStyle2IconButtonTemplate, 26 x 25: common-dropdown-c-button at its size and the arrow icons) 5
    -- left and 4 right of it (DropdownWithSteppersTemplate).
    Dropdown = {
      Width = 220, Height = 25, Padding = 13, Justify = "CENTER",
      Fill = cButton("common-dropdown-c-button"), HoverFill = cButton("common-dropdown-c-button-hover-1"),
      PressedFill = cButton("common-dropdown-c-button-pressedhover-1"), OpenFill = cButton("common-dropdown-c-button-open"),
      DisabledFill = cButton("common-dropdown-c-button-disabled"),
      Edge = false,
      Font = "DropdownText", DisabledFont = "DropdownDisabled", DisabledAlpha = 1,
      Chevron = { Atlas = "common-dropdown-c-button-hover-arrow", Color = "White", Size = "Atlas", Anchor = "BOTTOM",
        Point = { X = 0, Y = -5 }, HoverOnly = true },
      Steppers = { Width = 26, Height = 25, BackGap = 5, NextGap = 4,
        Back = { Atlas = "common-dropdown-icon-back", Disabled = { Atlas = "common-dropdown-icon-back-disabled" } },
        Next = { Atlas = "common-dropdown-icon-next", Disabled = { Atlas = "common-dropdown-icon-next-disabled" } },
        Fill = stepperArt("common-dropdown-c-button"), HoverFill = stepperArt("common-dropdown-c-button-hover-2"),
        PressedFill = stepperArt("common-dropdown-c-button-pressedhover-2"), DisabledFill = stepperArt("common-dropdown-c-button-disabled") },
    },
    -- Blizzard_Menu's menu rows: Interface\QuestFrame\UI-QuestTitleHighlight added under the pointer (MenuVariants.lua).
    Menu = {
      Gap = 2, Padding = 4, ItemHeight = 20,
      Edge = false,
      HoverFill = { Texture = "Interface\\QuestFrame\\UI-QuestTitleHighlight", BlendMode = "ADD", Color = "White", Alpha = 1 },
    },
    Swatch = { Edge = { Color = "White", Alpha = 0.45 }, HoverEdge = { Color = "White", Alpha = 0.9 } },
    -- MinimalTabTemplate (the settings window's tabs): 37 tall, 5 apart, as wide as their text and 40, each in three
    -- pieces at their atlas sizes by their bottoms (Options_Tab_*, Options_Tab_Active_* chosen), the text 4 above the
    -- bottom (6 chosen); no marker, no line.
    TopTabs = {
      Height = 37, Gap = 5, Padding = 20, TextBottom = 4, SelectedTextBottom = 6,
      Indicator = false, Line = false,
      Fill = tab(""), HoverFill = tab(""), SelectedFill = tab("Active_"),
    },
    -- Today's popup (GameDialogBaseMixin:OnLoad, GameDialog.lua): UI-DialogBox-Background-Dark 7 in, its diamond border
    -- over the whole popup (in Clients: each family's).
    Dialog = {
      Scrim = { Color = "Scrim" },
      Card = { Atlas = "UI-DialogBox-Background-Dark", Color = "White", Alpha = 1, Inset = { Left = 7, Right = 7, Top = 7, Bottom = 7 } },
      Edge = false,
    },
  },

  Clients = {
    -- Retail and WoW: Forever: the bag window.
    Retail = {
      Header = {
        Buttons = {
          -- UIPanelCloseButtonDefaultAnchors: TOPRIGHT 1, 0.
          Pinned = { closeButton = { Point = "TOPOUTER", X = 1, Y = 0 } },
          Icons = {
            -- UIPanelCloseButtonNoScripts: RedButton-Exit, -pressed, -Disabled, RedButton-Highlight added.
            closeButton = { Atlas = "RedButton-Exit", Glyph = false, Scale = 1 / 0.7,
              Pushed = { Atlas = "RedButton-exit-pressed" }, Disabled = { Atlas = "RedButton-Exit-Disabled" },
              Highlight = { Atlas = "RedButton-Highlight", BlendMode = "ADD" } },
          },
        },
      },
      Settings = {
        -- Its close (UIPanelCloseButtonDefaultAnchors: TOPRIGHT 1, 0).
        Header = { Close = { Atlas = "RedButton-Exit", Color = "White", HoverColor = "White", Size = 24, Offset = { X = 1, Y = 0 },
          Highlight = { Atlas = "RedButton-Highlight", BlendMode = "ADD", Color = "White", Alpha = 1 } } },
      },
      Controls = {
        -- The settings dropdowns' menus (MenuStyle2Mixin, Blizzard_Menu/MenuTemplates.lua): common-dropdown-c-bg 17 past
        -- its sides, 12 above and 22 below, the list 3, 6, 3 and 7 in.
        Dropdown = {
          Menu = { Inset = { Left = 3, Top = 6, Right = 3, Bottom = 7 }, Border = false,
            Fill = { Atlas = "common-dropdown-c-bg", Color = "White", Alpha = 1,
              Inset = { Left = -17, Top = -12, Right = -17, Bottom = -22 } } },
        },
        -- MenuStyle1Mixin: common-dropdown-bg 10 and 3 past the menu at 0.925, the list 8, 8, 8 and 15 in
        -- (GetInset); MenuVariants.CreateRadio: the ring on every row, the yellow tick over it on the chosen one.
        Menu = {
          Inset = { Left = 8, Top = 8, Right = 8, Bottom = 15 },
          Fill = { Atlas = "common-dropdown-bg", Color = "White", Alpha = 0.925,
            Inset = { Left = -10, Right = -10, Top = -3, Bottom = -3 } },
          Check = { Atlas = "common-dropdown-icon-radialtick-yellow", Color = "White", Size = "Atlas",
            Off = { Atlas = "common-dropdown-tickradial" }, Under = { Atlas = "common-dropdown-tickradial" } },
        },
        -- Its diamond border (Mainline/GameDialog.lua: GameDialogBackgroundTop).
        Dialog = { Border = { Atlas = "UI-DiamondDialogBox-Border", Color = "White", Alpha = 1 } },
      },
    },
    -- Every Classic client: the settings window's frame for the bags too.
    Classic = {
      -- Classic's streaks, and its title band.
      Panel = { Frame = { Bands = { CLASSIC_STREAKS, TITLE_BAND } } },
      Header = {
        Buttons = {
          -- UIPanelCloseButtonDefaultAnchors: a 32-square button at TOPRIGHT 4, 4; here its 32-square art centered on a
          -- button in the corner, drawn where Blizzard's is.
          RowStart = 30,
          Pinned = { closeButton = { Point = "TOPOUTER", X = 0, Y = 0 } },
          Icons = {
            closeButton = { Texture = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up", Glyph = false, Scale = 32 / 24 / 0.7,
              Pushed = { Texture = "Interface\\Buttons\\UI-Panel-MinimizeButton-Down" },
              Disabled = { Texture = "Interface\\Buttons\\UI-Panel-MinimizeButton-Disabled" },
              Highlight = { Texture = "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", BlendMode = "ADD" } },
          },
        },
      },
      Settings = {
        Frame = { Bands = { CLASSIC_STREAKS, TITLE_BAND } },
        Header = { Close = { Icon = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up", Color = "White", HoverColor = "White",
          Size = 32, Inset = -4,
          Highlight = { Texture = "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", BlendMode = "ADD", Color = "White",
            Alpha = 1 } } },
      },
      Controls = {
        -- The settings dropdowns' menus: Classic's MenuStyle2Mixin (Classic/MenuTemplates.lua, loaded after the shared one,
        -- Blizzard_Menu.toc): common-dropdown-classic-b-bg 3 past its sides, 1 above and 4 below, over black at 0.8 from
        -- 7, 4 to 8, 8 inside it; the list 14 in.
        Dropdown = {
          Menu = { Inset = { Left = 14, Top = 14, Right = 14, Bottom = 14 },
            Fill = { Color = { 0, 0, 0, 0.8 }, Inset = { Left = 4, Top = 3, Right = 5, Bottom = 4 } },
            Border = { Atlas = "common-dropdown-classic-b-bg", Color = "White", Alpha = 1,
              Inset = { Left = -3, Top = -1, Right = -3, Bottom = -4 } } },
        },
        -- MenuStyle1Mixin: common-dropdown-classic-bg 3, 3, 3 and 4 past the menu over black at 0.8 6 inside it, the list
        -- 16, 10, 16 and 10 in (GetInset); the Vanilla and Cata radios: the ring on the rows not chosen, the yellow tick
        -- in its place on the chosen one (one texture, its atlas swapped).
        Menu = {
          Inset = { Left = 16, Top = 10, Right = 16, Bottom = 10 },
          Fill = { Color = { 0, 0, 0, 0.8 }, Inset = { Left = 3, Right = 3, Top = 3, Bottom = 2 } },
          Border = { Atlas = "common-dropdown-classic-bg", Color = "White", Alpha = 1,
            Inset = { Left = -3, Right = -3, Top = -3, Bottom = -4 } },
          Check = { Atlas = "common-dropdown-icon-radialtick-yellow-classic", Color = "White", Size = "Atlas",
            Off = { Atlas = "common-dropdown-tickradial-classic" } },
        },
        -- Its diamond border (Classic/GameDialog.lua: GameDialogBackgroundTop).
        Dialog = { Border = { Atlas = "UI-DiamondDialogBox-ClassicBorder", Color = "White", Alpha = 1 } },
      },
    },
  },
})
