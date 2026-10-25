local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- Plain is the default UI of the game played (asked: "the Plain theme looks like the default UI for the version of WoW
-- we're playing on"; docs/next-plain-theme.md), at Default's scale and in Default's layout (asked, round three: "scale for
-- Plain should be the same as our Default", and of the settings window, "keep it like we do in default, just, pass over
-- with skin a bit"). Every piece is Blizzard's own, named as Blizzard's UI source names it (.libraries/wow-ui-source,
-- one branch per client), drawn by BetterBags Next from data:
--   The bags, every client: the original BetterBags bag window (DefaultPanelTemplate: ButtonFrameTemplateNoPortrait in
--     the client's art over the content, the rock, the streaks; Classic's title band), its menu button's bag in the
--     corner holding the header's actions in the original bags' menu (the vendor's portrait on the vendor's), the
--     close button, the search box where the original bags put it.
--   The settings window, every client: Default's, in the same frame and rock, its sidebar Blizzard's inset
--     (InsetFrameTemplate over its marble), the settings list's art for its pages, the page tabs on a line across their
--     column.
--   The controls: the panel button (UIPanelButtonNoTooltipTemplate), the input border (InputBoxVisualTemplate), the
--     multi-line edit box's frame (InputScrollFrameTemplate) round text areas and item boxes, the settings check box,
--     slider and dropdown art, MinimalTab tabs, Blizzard_Menu's menus, today's popup; Retail and WoW: Forever
--     (Clients.Retail) and every Classic client (Clients.Classic) each their own close button, menus and popup border.
--   The client's own fonts, copied (their file, flags, color and shadow) at Default's sizes.
-- The bags' side tabs are Blizzard's list rows: Blizzard has no sideways text tabs. No sparkles, feather, wash, ribbon,
-- cloud, glow or braid. Data only.

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

-- The original bags' menu button (frames/menubutton.lua), Next's bag button holding the header's actions (asked, round
-- three: "remove all top bar buttons ... bring back the drop down menu with these options, just like the original
-- bags"): Bagslots2x's first fifth (the bag in its gold ring), 48 x 60, its ring in a 40-square button 12 out from the
-- corner and 15 above it (the art 2 left of and above the button, 14 out and 17 above the corner as before); its gold
-- glow (the file's second fifth, 2 to the right, as the original's) over it under the pointer. On the vendor, the
-- vendor's portrait (asked: "vendors should have their portrait for the bag button, not the bag texture"), round
-- (TempPortraitAlphaMask, as Blizzard rounds its portraits) over a dark disc for while there is none, in the file's
-- empty gold ring (x 296 to 352, y 3 to 59 of its 512 x 128), drawn as large across as the bag's ring.
local BAGSLOTS = "Interface\\Containerframe\\Bagslots2x"
local PORTRAIT_MASK = { Texture = "Interface\\CharacterFrame\\TempPortraitAlphaMask" }
local PORTRAIT = { Left = 4, Top = 4, Right = 4, Bottom = 4 }
local BAG_BUTTON = {
  Point = "TOPINNER", X = -12, Y = -15, Width = 40, Height = 40,
  Layers = { { Texture = BAGSLOTS, TexCoords = { 0, 0.2, 0, 1 }, Inset = { Left = -2, Top = -2, Right = -6, Bottom = -18 } } },
  Highlight = { Texture = BAGSLOTS, TexCoords = { 0.2, 0.3992, 0, 1 }, Inset = { Left = 0, Top = -2, Right = -8, Bottom = -18 } },
  Panels = { Vendor = { Layers = {
    { Color = { 0, 0, 0, 1 }, Inset = PORTRAIT, Mask = PORTRAIT_MASK },
    { Unit = "npc", Inset = PORTRAIT, Mask = PORTRAIT_MASK },
    { Texture = BAGSLOTS, TexCoords = { 0.578125, 0.689453125, 0.0234375, 0.46875 },
      Inset = { Left = 0, Top = 1, Right = -3, Bottom = -4 } },
  } } },
}

-- InsetFrameTemplate's Bg (Blizzard_SharedXML/<Family>/SharedUIPanelTemplates.xml): Interface\FrameGeneral\
-- UI-Background-Marble tiled both ways, under its nine-slice.
local MARBLE = { Texture = "Interface\\FrameGeneral\\UI-Background-Marble", HorizTile = true, VertTile = true, Color = "White",
  Alpha = 1 }

-- InputScrollFrameTemplate's frame (every client: Interface\Common\Common-Input-Border-TL to -BR and -M, its 8 x 8
-- corners 5 outside the box, its edges between them, its middle filling them): Blizzard's multi-line edit box, round text
-- areas and item boxes.
local EDIT_BOX = { Pieces = {
  TopLeftCorner = { Texture = "Interface\\Common\\Common-Input-Border-TL", Width = 8, Height = 8, X = -5, Y = 5 },
  TopRightCorner = { Texture = "Interface\\Common\\Common-Input-Border-TR", Width = 8, Height = 8, X = 5, Y = 5 },
  BottomLeftCorner = { Texture = "Interface\\Common\\Common-Input-Border-BL", Width = 8, Height = 8, X = -5, Y = -5 },
  BottomRightCorner = { Texture = "Interface\\Common\\Common-Input-Border-BR", Width = 8, Height = 8, X = 5, Y = -5 },
  TopEdge = { Texture = "Interface\\Common\\Common-Input-Border-T", Height = 8 },
  BottomEdge = { Texture = "Interface\\Common\\Common-Input-Border-B", Height = 8 },
  LeftEdge = { Texture = "Interface\\Common\\Common-Input-Border-L", Width = 8 },
  RightEdge = { Texture = "Interface\\Common\\Common-Input-Border-R", Width = 8 },
  Center = { Texture = "Interface\\Common\\Common-Input-Border-M" },
} }

-- The settings page tabs' line (asked: "a line across the bottom of them edge to edge probably, so it looks like a tab
-- sitting on top of a pane"): the tabs' outline (the Options_Tab art's top, two rows of #dbdbdb at about a quarter
-- strength, measured), across the content column (32 past the tabs, the header's padding, either side: from the sidebar's edge to
-- the frame's), open under the chosen tab.
local TAB_LINE = { Color = { 0.86, 0.86, 0.86, 1 }, Alpha = 0.25, Size = 2, Open = true, Outset = { Left = 32, Right = 32 } }

-- WowStyle2DropdownTemplate's Background: its atlas 7 past the dropdown on every side (sliced 12 either side, so it
-- stretches across).
local function cButton(atlas)
  return { Atlas = atlas, Color = "White", Alpha = 1, Inset = { Left = -7, Top = -7, Right = -7, Bottom = -7 } }
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

  -- The client's own font objects, copied outright (Copy, next-themes.md §4): their file, flags, color and shadow in every
  -- locale, at Default's size for each role (asked: "scale for Plain should be the same as our Default"). Size = false
  -- keeps the client's own: the title in Blizzard's title bar (20 tall), and the two Blizzard fonts larger than Default's
  -- (the settings list's headers, the settings sections).
  Fonts = {
    Title = { Copy = "GameFontNormal", Size = false },
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
    DialogTitle = { Copy = "GameFontNormal" },
    DialogText = { Copy = "GameFontHighlight" },
    TopTab = { Copy = "GameFontNormalSmall" },
    TopTabHover = { Copy = "GameFontHighlightSmall" },
    TopTabSelected = { Copy = "GameFontHighlightSmall" },
    SettingsBrand = { Copy = "GameFontNormalLarge" },
    -- The settings list's headers (SettingsCategoryListHeaderTemplate: GameFontHighlightMedium) and rows
    -- (GameFontNormal, GameFontHighlight chosen).
    SettingsNavGroup = { Copy = "GameFontHighlightMedium", Size = false },
    SettingsNav = { Copy = "GameFontNormal" },
    -- Under the pointer a row keeps its font, its art lights (SettingsCategoryListButtonMixin:UpdateStateInternal).
    SettingsNavHover = { Copy = "GameFontNormal" },
    SettingsNavSelected = { Copy = "GameFontHighlight" },
    SettingsVersion = { Copy = "GameFontDisableSmall" },
    SettingsTitle = { Copy = "GameFontHighlightHuge" },
    SettingsDescription = { Copy = "GameFontHighlightSmall" },
    SettingsSection = { Copy = "GameFontHighlightLarge", Size = false },
    SettingsSectionNote = { Copy = "GameFontDisableSmall" },
    SettingsLabel = { Copy = "GameFontNormal" },
    SettingsText = { Copy = "GameFontHighlightSmall" },
    SettingsLink = { Copy = "GameFontNormal" },
  },

  -- Default's sizes (asked: "scale for Plain should be the same as our Default"), but what the frame's art fixes.
  Layout = {
    -- The title's top 6 below the frame's (TitleContainer at -1, its text at -5 in it), in the title bar, centered between
    -- the bag button and the close button.
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
    -- UIPanelCloseButton's 24, in the title bar's corner.
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
      -- The header's actions in the bag button's menu; only the close button (pinned, in Clients) stays in the header.
      Menu = BAG_BUTTON,
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
  },

  -- Default's settings window, skinned (asked, round three: "don't change the proportions or layout of settings here --
  -- keep it like we do in default, just, pass over with skin a bit"): its size, sidebar, header, rows and footer
  -- Default's; in the original bags' frame and stone, as the What's New window; its name in the title bar.
  Settings = {
    Fill = ROCK,
    Frame = { Layout = "ButtonFrameTemplateNoPortrait", Bands = { STREAKS } },
    Wash = false,
    Edge = false,
    -- DefaultPanelBaseTemplate's TitleContainer, 30 in to 24 from the right, its text 5 below its top 1 down; the bar
    -- moves the window.
    Title = { Font = "Title", Top = 6, Left = 30, Right = 24, Height = 22 },
    -- Default's sidebar as Blizzard's inset (ButtonFrameTemplate's Inset: InsetFrameTemplate's nine-slice over its marble),
    -- PANEL_INSET_LEFT_OFFSET 4 in, PANEL_INSET_TOP_OFFSET 24 down (below the title bar), PANEL_INSET_BOTTOM_OFFSET 4 above
    -- the bottom (SharedUIPanelTemplates.lua, every client).
    Sidebar = { Left = 4, Top = 24, Bottom = 4, Fill = MARBLE, Line = false, Frame = { Layout = "InsetFrameTemplate" } },
    -- The window names itself in its title bar.
    Brand = false,
    -- SearchBoxTemplate's magnifier, gray.
    Search = { Atlas = "common-search-magnifyingglass", IconSize = 10, IconColor = "SearchIcon" },
    Back = { IconColor = "Gold", Height = 30 },
    -- The pages as Blizzard's settings list draws them (Blizzard_CategoryList.lua) at Default's row height: a heading on
    -- Options_CategoryHeader_1 to 3, cycled, at its own size (199 wide, its bar 28 tall), 16 in (the sidebar's padding,
    -- in line with the search box), its label 20 in from the art and 1 down, as written; a row's label 16 deeper (Blizzard
    -- puts rows at 36 against headings at 20), 1 above its middle; Options_List_Active and _Hover across the row.
    Nav = {
      GroupHeight = 30, Indent = 36, TextRaise = 1, GroupUpper = false,
      Indicator = false,
      SelectedFill = LIST_ACTIVE,
      HoverFill = LIST_HOVER,
      GroupFills = {
        { Atlas = "Options_CategoryHeader_1", Color = "White", Alpha = 1, AtlasSize = true, Point = "TOPLEFT", X = 16 },
        { Atlas = "Options_CategoryHeader_2", Color = "White", Alpha = 1, AtlasSize = true, Point = "TOPLEFT", X = 16 },
        { Atlas = "Options_CategoryHeader_3", Color = "White", Alpha = 1, AtlasSize = true, Point = "TOPLEFT", X = 16 },
      },
      GroupLabel = { Point = "LEFT", X = 36, Y = -1 },
    },
    -- Default's header, its content column clear of the frame's right edge (6 in, PANEL_INSET_RIGHT_OFFSET).
    Header = { Right = 6 },
    -- Default's rows on a soft shade, lit white at 0.1 under the pointer (HoverBackgroundTemplate); section titles as
    -- written, as Blizzard's (SettingsListSectionHeaderTemplate).
    Content = { TitleUpper = false, Card = { Color = "Shade" }, Divider = { Color = "White", Alpha = 0.08, Size = 1 },
      Hover = { Color = "White", Alpha = 0.1 } },
    Footer = { Line = false },
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
    -- UIPanelButtonNoTooltipTemplate, 20 either side of its label (fitTextWidthPadding 40), at Default's height.
    Button = {
      Padding = 20, DisabledAlpha = 1,
      Plain = BUTTON, Primary = BUTTON, Danger = BUTTON,
      Link = { Font = "Link", HoverFont = "LinkHover" },
    },
    -- InputBoxVisualTemplate: common-search-border, its left cap 8 wide and 5 past the field, at Default's height (the
    -- art drawn over all of what takes the field's clicks).
    Input = {
      Fill = { Pieces = "Horizontal", Inset = { Left = -5 }, Color = "White", Alpha = 1,
        Begin = { Atlas = "common-search-border-left", Size = 8 }, Middle = { Atlas = "common-search-border-middle" },
        End = { Atlas = "common-search-border-right", Size = 8 } },
      FocusFill = { Pieces = "Horizontal", Inset = { Left = -5 }, Color = "White", Alpha = 1,
        Begin = { Atlas = "common-search-border-left", Size = 8 }, Middle = { Atlas = "common-search-border-middle" },
        End = { Atlas = "common-search-border-right", Size = 8 } },
      Edge = false,
    },
    -- A text area (the Search Rule) and an item box in Blizzard's multi-line edit box's frame, round the whole box.
    TextArea = { Fill = false, FocusFill = false, Edge = false, Frame = EDIT_BOX },
    ItemGrid = {
      Fill = false, Edge = false, Frame = EDIT_BOX,
      CommonEdge = { Color = "White", Alpha = 0.25 },
      Hover = { Color = "White", Alpha = 0.15 },
    },
    -- The settings slider's bar (MinimalSliderTemplate, 19 tall, in three pieces at their atlas sizes centered on it, its
    -- thumb Minimal_SliderBar_Button at its atlas size), at 0.7 while disabled (MinimalSlider.lua), at Default's width with
    -- Default's number box.
    Slider = {
      Height = 19, TrackSize = 19, ThumbSize = "Atlas",
      Track = { Pieces = "Horizontal", Thickness = "Atlas", Color = "White", Alpha = 1, Begin = { Atlas = "Minimal_SliderBar_Left" },
        Middle = { Atlas = "_Minimal_SliderBar_Middle" }, End = { Atlas = "Minimal_SliderBar_Right" } },
      Fill = false,
      Thumb = { Atlas = "Minimal_SliderBar_Button", Color = "White", Alpha = 1 },
      ThumbHover = { Atlas = "Minimal_SliderBar_Button", Color = "White", Alpha = 1 },
      DisabledAlpha = 0.7,
    },
    -- The settings dropdown's art (WowStyle2DropdownTemplate, every client), at Default's size: common-dropdown-c-button 7
    -- past it in its art for each state (WowStyle2DropdownMixin:GetBackgroundAtlas), the choice centered 13 in from each
    -- side in gold (gray disabled), the arrow (common-dropdown-c-button-hover-arrow) 5 below its bottom under the pointer.
    Dropdown = {
      Padding = 13, Justify = "CENTER",
      Fill = cButton("common-dropdown-c-button"), HoverFill = cButton("common-dropdown-c-button-hover-1"),
      PressedFill = cButton("common-dropdown-c-button-pressedhover-1"), OpenFill = cButton("common-dropdown-c-button-open"),
      DisabledFill = cButton("common-dropdown-c-button-disabled"),
      Edge = false,
      Font = "DropdownText", DisabledFont = "DropdownDisabled", DisabledAlpha = 1,
      Chevron = { Atlas = "common-dropdown-c-button-hover-arrow", Color = "White", Size = "Atlas", Anchor = "BOTTOM",
        Point = { X = 0, Y = -5 }, HoverOnly = true },
    },
    -- Blizzard_Menu's menu rows: Interface\QuestFrame\UI-QuestTitleHighlight added under the pointer (MenuVariants.lua).
    Menu = {
      Edge = false,
      HoverFill = { Texture = "Interface\\QuestFrame\\UI-QuestTitleHighlight", BlendMode = "ADD", Color = "White", Alpha = 1 },
    },
    Swatch = { Edge = { Color = "White", Alpha = 0.45 }, HoverEdge = { Color = "White", Alpha = 0.9 } },
    -- MinimalTabTemplate (the settings window's tabs): 5 apart, as wide as their text and 40, each in three pieces at their
    -- atlas sizes by their bottoms (Options_Tab_*, Options_Tab_Active_* chosen), the text 4 above the bottom (6 chosen);
    -- no marker; on a line across their column, open under the chosen tab.
    TopTabs = {
      Gap = 5, Padding = 20, TextBottom = 4, SelectedTextBottom = 6,
      Indicator = false, Line = TAB_LINE,
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
            closeButton = { Atlas = "RedButton-Exit", Glyph = false,
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
          Pinned = { closeButton = { Point = "TOPOUTER", X = 0, Y = 0 } },
          Icons = {
            closeButton = { Texture = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up", Glyph = false, Scale = 32 / 24,
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
