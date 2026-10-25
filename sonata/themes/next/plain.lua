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

-- Classic's settings window's title band (Classic/Blizzard_SettingsPanelTemplates.xml: _UI-Frame-TitleTileBg, a
-- 17-pixel strip of Interface\FrameGeneral\_UI-Frame tiled across, 8 in and 3 down, to the right edge).
local TITLE_BAND = { Texture = "Interface\\FrameGeneral\\_UI-Frame", TexCoords = { 0, 1, 0.2890625, 0.421875 }, HorizTile = true,
  Color = "White", Alpha = 1, Height = 17, Left = 8, Right = 0, Top = 3 }

-- The settings list's rows (Blizzard_CategoryList.lua): lit under the pointer, chosen.
local LIST_HOVER = { Atlas = "Options_List_Hover", Color = "White", Alpha = 1 }
local LIST_ACTIVE = { Atlas = "Options_List_Active", Color = "White", Alpha = 1 }

-- The round portrait of PortraitFrameBaseTemplate, as the bags draw it (ContainerFrame_OnLoad:
-- SetPortraitTextureSizeAndOffset(36, -4, 1)): 4 outside the frame's top left corner and 1 above it, cut round by
-- TempPortraitAlphaMask 2, 0, 2 and 4 in; never flipped on the bank.
local function portrait(panels, unit)
  return { Texture = "Interface\\Icons\\Inv_misc_bag_08", Point = "TOPINNER", Width = 36, Height = 36, X = -4, Y = -1,
    Mirror = false, Unit = unit, Panels = panels,
    Mask = { Texture = "Interface\\CharacterFrame\\TempPortraitAlphaMask", Inset = { Left = 2, Right = 2, Top = 0, Bottom = 4 } } }
end

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
    -- WowStyle1DropdownTemplate's text (retail; Classic's in Clients.Classic), gray while disabled (DISABLED_FONT_COLOR).
    DropdownText = { Copy = "GameFontHighlight" },
    DropdownDisabled = { Copy = "GameFontDisable" },
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
    -- The title's top 6 below the frame's (TitleContainer at -1, its text at -5 in it), in the title bar.
    TitleTop = 6,
    SearchTop = 28,
    SearchHeight = 20,
    SearchIcon = 14,
    SearchGap = 6,
    SearchRight = 20,
    ContentTop = 56,
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

  Panel = {
    Fill = { Color = "Panel" },
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

  -- The bag search box as Blizzard draws it (BagSearchBoxTemplate's InputBoxVisualTemplate border).
  Search = {
    Template = true,
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

  Settings = {
    Wash = false,
    Edge = false,
    Sidebar = { Fill = { Color = "Shade" }, Line = false },
    Brand = { IconColor = "Gold", Line = false },
    Search = { IconColor = "SearchIcon" },
    Back = { IconColor = "Gold" },
    -- Blizzard's settings list (Blizzard_CategoryList.lua): rows 20 tall, their text 1 above the middle, their art at its
    -- own size, centered; headers 30 tall in Options_CategoryHeader_1 to 3, cycled, at their top left, their labels 20
    -- in and 1 down (SettingsCategoryListHeaderTemplate); 2 between every one (its view's spacing).
    Nav = {
      ItemHeight = 20, GroupHeight = 30, GroupGap = 0, Spacing = 2, TextRaise = 1,
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
    -- A setting's row lit white at 0.1 under the pointer (HoverBackgroundTemplate), no cards or lines.
    Content = { Card = false, Divider = false, Hover = { Color = "White", Alpha = 0.1 } },
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
    -- MinimalSliderTemplate: 19 tall, its bar in three pieces at their atlas sizes centered on it, its thumb
    -- Minimal_SliderBar_Button at its atlas size.
    Slider = {
      Width = 140, Height = 19, TrackSize = 19, ThumbSize = "Atlas",
      Track = { Pieces = "Horizontal", Thickness = "Atlas", Color = "White", Alpha = 1, Begin = { Atlas = "Minimal_SliderBar_Left" },
        Middle = { Atlas = "_Minimal_SliderBar_Middle" }, End = { Atlas = "Minimal_SliderBar_Right" } },
      Fill = false,
      Thumb = { Atlas = "Minimal_SliderBar_Button", Color = "White", Alpha = 1 },
      ThumbHover = { Atlas = "Minimal_SliderBar_Button", Color = "White", Alpha = 1 },
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
      Layout = {
        -- The title centered from 35 (SetTitleOffsets(35)) to the buttons, Pad in plus this.
        TitleInset = 25,
      },
      Panel = {
        -- PortraitFrameFlatBaseTemplate's Bg, 2, 20, 2 and 3 in.
        Fill = { Inset = { Left = 2, Right = 2, Top = 20, Bottom = 3 } },
        Frame = { Layout = "HeldBagLayout" },
        Ornaments = {
          portrait({ "Backpack", "GuildBank" }),
          -- The bank and the vendor show their NPC (SetPortraitToUnit("npc")).
          portrait({ "Bank", "Vendor" }, "npc"),
        },
      },
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
        -- SettingsFrameTemplate: its Bg 7, 18, 3 and 3 in.
        Fill = { Color = "Panel", Inset = { Left = 7, Right = 3, Top = 18, Bottom = 3 } },
        Frame = { Layout = "ButtonFrameTemplateNoPortrait" },
        -- Its close (UIPanelCloseButtonDefaultAnchors: TOPRIGHT 1, 0).
        Header = { Close = { Atlas = "RedButton-Exit", Color = "White", HoverColor = "White", Size = 24, Offset = { X = 1, Y = 0 },
          Highlight = { Atlas = "RedButton-Highlight", BlendMode = "ADD", Color = "White", Alpha = 1 } } },
      },
      Controls = {
        -- Blizzard_Menu/Mainline: WowStyle1DropdownTemplate, 25 tall, its text 8 in, common-dropdown-textholder 8, 7, 8
        -- and 9 past it, its arrow by its right at RIGHT 1, -3 in its art for each state (GetWowStyle1ArrowButtonState).
        Dropdown = {
          Height = 25, Padding = 8,
          Fill = { Atlas = "common-dropdown-textholder", Color = "White", Alpha = 1,
            Inset = { Left = -8, Top = -7, Right = -8, Bottom = -9 } },
          HoverFill = { Atlas = "common-dropdown-textholder", Color = "White", Alpha = 1,
            Inset = { Left = -8, Top = -7, Right = -8, Bottom = -9 } },
          OpenFill = { Atlas = "common-dropdown-textholder", Color = "White", Alpha = 1,
            Inset = { Left = -8, Top = -7, Right = -8, Bottom = -9 } },
          Edge = false,
          Font = "DropdownText", DisabledFont = "DropdownDisabled", DisabledAlpha = 1,
          Chevron = { Atlas = "common-dropdown-a-button", Color = "White", Size = "Atlas", Point = { X = 1, Y = -3 },
            Hover = { Atlas = "common-dropdown-a-button-hover" }, Pressed = { Atlas = "common-dropdown-a-button-pressedhover" },
            Open = { Atlas = "common-dropdown-a-button-open" }, Disabled = { Atlas = "common-dropdown-a-button-disabled" } },
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
      Layout = {
        -- DefaultPanelBaseTemplate's TitleContainer, 30 in.
        TitleInset = 20,
      },
      Panel = {
        -- SettingsFrameTemplate's Bg, 7, 18, 3 and 3 in.
        Fill = { Inset = { Left = 7, Right = 3, Top = 18, Bottom = 3 } },
        Frame = { Layout = "ButtonFrameTemplateNoPortrait", TitleBg = TITLE_BAND },
      },
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
        Fill = { Color = "Panel", Inset = { Left = 7, Right = 3, Top = 18, Bottom = 3 } },
        Frame = { Layout = "ButtonFrameTemplateNoPortrait", TitleBg = TITLE_BAND },
        Header = { Close = { Icon = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up", Color = "White", HoverColor = "White",
          Size = 32, Inset = -4,
          Highlight = { Texture = "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", BlendMode = "ADD", Color = "White",
            Alpha = 1 } } },
      },
      -- Classic's dropdowns write in the small fonts (Classic/MenuTemplates.xml: GameFontHighlightSmall).
      Fonts = {
        DropdownText = { Copy = "GameFontHighlightSmall" },
        DropdownDisabled = { Copy = "GameFontDisableSmall" },
      },
      Controls = {
        -- Blizzard_Menu/Classic: WowStyle1DropdownTemplate, 24 tall, its text 9 in and written right against the arrow,
        -- common-dropdown-classic-textholder 9, 8, 8 and 9 past it (-small at 100 wide or less, OnSizeChanged), its
        -- arrow by its right at RIGHT -1, 0 in its art for each state (GetWowStyle1ArrowButtonState).
        Dropdown = {
          Height = 24, Padding = 9, Justify = "RIGHT",
          Fill = { Atlas = "common-dropdown-classic-textholder", Color = "White", Alpha = 1,
            Inset = { Left = -9, Top = -8, Right = -8, Bottom = -9 } },
          HoverFill = { Atlas = "common-dropdown-classic-textholder", Color = "White", Alpha = 1,
            Inset = { Left = -9, Top = -8, Right = -8, Bottom = -9 } },
          OpenFill = { Atlas = "common-dropdown-classic-textholder", Color = "White", Alpha = 1,
            Inset = { Left = -9, Top = -8, Right = -8, Bottom = -9 } },
          NarrowWidth = 100,
          NarrowFill = { Atlas = "common-dropdown-classic-textholder-small", Color = "White", Alpha = 1,
            Inset = { Left = -9, Top = -8, Right = -8, Bottom = -9 } },
          Edge = false,
          Font = "DropdownText", DisabledFont = "DropdownDisabled", DisabledAlpha = 1,
          Chevron = { Atlas = "common-dropdown-classic-a-buttonDown", Color = "White", Size = "Atlas", Point = { X = -1, Y = 0 },
            Hover = { Atlas = "common-dropdown-classic-a-buttonDown-hover" },
            Pressed = { Atlas = "common-dropdown-classic-a-buttonDown-pressedhover" },
            Disabled = { Atlas = "common-dropdown-classic-a-buttonDown-disabled" } },
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
