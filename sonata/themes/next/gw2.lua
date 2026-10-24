local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- Guild Wars 2: BetterBags Next in GW2_UI's look, offered while GW2_UI is loaded (docs/next-gw2-theme.md). Data
-- only, nothing of GW2_UI's called: its art drawn from its own files, read from its source (.libraries/GW2_UI).
--   The frame is the original BetterBags GW2 theme's (sonata/themes/gw2.lua; asked: "we need to use those icons,
--     that bag frame style, that icon"): the world map painting for the body, GW2's header band across the top with
--     the title on it, GW2's bag emblem (84) at the top inner corner (its merchant's on the vendor, as GW2_UI does),
--     GW2's side panel standing outside the window along its inner side with the actions down it in the original's
--     micro icons (32, 5 apart), the footer band, the close button at the top outer corner (top right on the
--     backpack), no feather (asked: none while docked).
--   Every control in GW2_UI's art (asked: "tabs, i mean everything ... art of buttons, art of toggles"): its side
--     tabs, its bag search bar, its bag section rows (GwBagHeaderTemplate), its cream buttons with dark text and
--     their disabled art, its check boxes, sliders, scroll bars, fields, dropdowns and menus (Core/API/toolkit.lua,
--     editBox.lua, Immersive/Skins/menu.lua), its settings window (Settings/settingsWindow.xml).
--   Text: GW2_UI's own fonts, copied from the client fonts it rewrites at login (Core/fonts.lua: GameFontHighlight in
--     its normal family, SystemFont_Shadow_Large in its header family), so the player's locale and GW2 font settings
--     are followed; its colors (Core/color.lua): LightHeader titles, its wine accent, its skin colors.
--   Item buttons: GW2_UI's skin (Inventory/inventory.lua, reskinItemButton).
-- No sparkles, shimmer, cloud or ribbon: GW2_UI's look is painted, not starry. Painted rows and columns below were
-- measured from the files.
local GW = "Interface\\AddOns\\GW2_UI\\Textures\\"

-- The roles' client fonts, as GW2_UI rewrites them: its normal family, and its header family for titles.
local NORMAL, HEADER = "GameFontHighlight", "SystemFont_Shadow_Large"
-- GW2_UI's side tab art for tabs sticking out to the left (Immersive/Skins/utils.lua, direction "left"); drawn for
-- the backpack's tabs and mirrored on the other panels.
local TAB = { 1, 0, 0, 1 }

sonataNext:RegisterTheme({
  Name = "GW2",
  DisplayName = "Guild Wars 2",
  Description = "GW2_UI's look: the original BetterBags GW2 frame, side panel and icons, and every control in its art.",
  Requires = { "GW2_UI" },

  Textures = {
    Map = GW .. "character\\worldmap-background.png",
    Header = GW .. "bag\\bagheader.png",
    HeaderEnd = GW .. "bag\\bagheader-right.png",
    Footer = GW .. "bag\\bagfooter.png",
    SidePanel = GW .. "bag\\bagleftpanel.png",
    BagEmblem = GW .. "bag\\bagicon.png",
    VendorEmblem = GW .. "character\\macro-window-icon.png",
    ItemBorder = GW .. "bag\\bagitemborder.png",
    SectionRow = GW .. "bag\\bag-sep.png",
    SearchBar = GW .. "bag\\bagsearchbg.png",
    Tab = GW .. "uistuff\\tab-tex-right-left.png",
    RowHover = GW .. "character\\menu-hover.png",
    Button = GW .. "uistuff\\button.png",
    ButtonHover = GW .. "uistuff\\button_hover.png",
    ButtonOff = GW .. "uistuff\\button_disable.png",
    Close = GW .. "uistuff\\window-close-button-normal.png",
    CloseHover = GW .. "uistuff\\window-close-button-hover.png",
    Resize = GW .. "uistuff\\resize.png",
    Check = GW .. "uistuff\\checkbox.png",
    Checked = GW .. "uistuff\\checkboxchecked.png",
    CheckOff = GW .. "uistuff\\checkbox-disabled.png",
    SliderTrack = GW .. "uistuff\\sliderbg.png",
    SliderThumb = GW .. "uistuff\\sliderhandle.png",
    ScrollTrack = GW .. "uistuff\\scrollbg.png",
    ScrollThumb = GW .. "uistuff\\scrollbarmiddle.png",
    Arrow = GW .. "uistuff\\arrowdown_down.png",
    Backdrop = GW .. "uistuff\\ui-tooltip-background.png",
    Field = GW .. "uistuff\\statusbar.png",
    SettingsPanel = GW .. "uistuff\\settingspanelbg.png",
    SettingsMenu = GW .. "uistuff\\236menubg.png",
    SettingsDivider = GW .. "uistuff\\settingspanelsep.png",
    BrandLine = GW .. "hud\\levelreward-sep.png",
    -- The original's actions (micro buttons) and GW2_UI's own buttons.
    MicroBag = GW .. "icons\\bagmicrobutton-up.png",
    MicroBagDown = GW .. "icons\\bagmicrobutton-down.png",
    MicroCollections = GW .. "icons\\microicons\\collectionsmicrobutton-up.png",
    MicroQuestLog = GW .. "icons\\microicons\\questlogmicrobutton-up.png",
    Minimize = GW .. "uistuff\\minimize_button.png",
    Maximize = GW .. "uistuff\\maximize_button.png",
    BankIcons = GW .. "bag\\bankicons.png",
    Repair = GW .. "icons\\repair.png",
  },

  Palette = {
    -- GW2_UI's text colors and accent (GW.Colors.TextColors.LightHeader, GW.Colors.Accent).
    LightHeader = { 1, 0.9450, 0.8196, 1 },
    Accent = { 150 / 255, 50 / 255, 50 / 255, 1 },
    -- Its skin colors: light frames (CreamBorder), the second line under a name (SubText), an empty field's hint
    -- (Placeholder), greyed out (Disabled), money (MoneyColors.Gold), negative and positive.
    Lavender = { 1, 0.99, 0.85, 1 },
    Muted = { 0.75, 0.75, 0.75, 1 },
    Placeholder = { 0.7, 0.7, 0.7, 1 },
    Disabled = { 0.6, 0.6, 0.6, 1 },
    Gold = { 221 / 255, 187 / 255, 68 / 255, 1 },
    Text = { 1, 1, 1, 1 },
    Unaffordable = { 1, 0.3, 0.3, 1 },
    Danger = { 1, 0.3, 0.3, 1 },
    -- The Warbank's and the guild's accents (IndicatorColors.Teal, SkinColors.Positive).
    Warbank = { 0.3, 0.75, 0.75, 1 },
    Guild = { 0.3, 1, 0.3, 1 },
    -- A destroy card's and a buy card's glow (DebuffColors None, IndicatorColors.Green).
    Crimson = { 220 / 255, 0, 0, 1 },
    Emerald = { 0.2, 0.8, 0.2, 1 },
    -- The world map painting's average (0.151, 0.131, 0.100), for what is drawn beside it.
    Body = { 0.15, 0.13, 0.10, 0.92 },
    Card = { 0.1, 0.09, 0.08, 0.98 },
    Shadow = { 0, 0, 0, 0.9 },
    ButtonIcon = { 1, 0.9450, 0.8196, 1 },
    Bead = { 1, 0.9450, 0.8196, 1 },
    ControlFill = { 0.1, 0.085, 0.075, 0.9 },
    ControlHover = { 0.15, 0.125, 0.11, 0.95 },
    ControlPressed = { 0.07, 0.06, 0.05, 0.95 },
    Track = { 0.25, 0.21, 0.18, 1 },
    -- Dark text on GW2_UI's cream buttons (GwSkinButton: black), and a danger button's.
    Ink = { 0.05, 0.04, 0.03, 1 },
    InkDanger = { 0.55, 0.05, 0.05, 1 },
    -- GW2's tabs, dimmed until selected.
    TabIdle = { 0.72, 0.72, 0.72, 1 },
    -- GW2_UI's cream buttons under the pointer (button_hover.png, darkened) and pressed.
    ButtonHover = { 0.86, 0.86, 0.86, 1 },
    ButtonPressed = { 0.72, 0.72, 0.72, 1 },
  },

  -- GW2_UI's shadows are a pixel down and right.
  FontShadow = { Color = "Shadow", X = 1, Y = -1 },
  Fonts = {
    -- The original's title: GW2's BigHeader size and two more.
    Title = { Object = HEADER, Size = 20, Color = "LightHeader", Shadow = true },
    Section = { Object = NORMAL, Size = 13, Color = "LightHeader", Shadow = true },
    SectionRecent = { Object = NORMAL, Size = 13, Color = "Gold", Shadow = true },
    SectionFree = { Object = NORMAL, Size = 12, Color = "Muted" },
    Count = { Object = NORMAL, Size = 11, Color = "Muted" },
    Tab = { Object = NORMAL, Size = 12, Color = "Muted" },
    TabSelected = { Object = NORMAL, Size = 12, Color = "LightHeader", Shadow = true },
    Footer = { Object = NORMAL, Size = 12, Color = "Muted" },
    Empty = { Object = NORMAL, Size = 12, Color = "Muted" },
    DragHint = { Object = NORMAL, Size = 12, Color = "White", Shadow = true },
    ConfirmTitle = { Object = HEADER, Size = 18, Color = "LightHeader", Shadow = true },
    ConfirmWarning = { Object = NORMAL, Size = 12, Color = "Gold" },
    ConfirmHint = { Object = NORMAL, Size = 12, Color = "Muted" },
    Search = { Object = NORMAL, Size = 12, Color = "Placeholder" },
    SearchText = { Object = NORMAL, Size = 13, Color = "Text" },
    Price = { Object = NORMAL, Size = 13, Color = "White", Shadow = true },
    PriceUnaffordable = { Object = NORMAL, Size = 13, Color = "Unaffordable", Shadow = true },
    VendorName = { Object = NORMAL, Size = 13, Color = "Text", Shadow = true },
    ControlText = { Object = NORMAL, Size = 12, Color = "Text" },
    ControlMuted = { Object = NORMAL, Size = 12, Color = "Muted" },
    ControlHelp = { Object = NORMAL, Size = 12, Color = "Placeholder" },
    Button = { Object = NORMAL, Size = 12, Color = "Ink", Shadow = false },
    ButtonPrimary = { Object = NORMAL, Size = 12, Color = "Ink", Shadow = false },
    ButtonDanger = { Object = NORMAL, Size = 12, Color = "InkDanger", Shadow = false },
    Link = { Object = NORMAL, Size = 12, Color = "Gold" },
    LinkHover = { Object = NORMAL, Size = 12, Color = "LightHeader" },
    MenuItem = { Object = NORMAL, Size = 12, Color = "Text" },
    MenuItemSelected = { Object = NORMAL, Size = 12, Color = "Gold" },
    DialogTitle = { Object = HEADER, Size = 16, Color = "LightHeader", Shadow = true },
    DialogText = { Object = NORMAL, Size = 12, Color = "Text" },
    TopTab = { Object = NORMAL, Size = 13, Color = "Muted" },
    TopTabHover = { Object = NORMAL, Size = 13, Color = "Text" },
    TopTabSelected = { Object = NORMAL, Size = 13, Color = "LightHeader", Shadow = true },
    SettingsBrand = { Object = HEADER, Size = 20, Color = "LightHeader", Shadow = true },
    SettingsNavGroup = { Object = NORMAL, Size = 11, Color = "Gold" },
    SettingsNav = { Object = NORMAL, Size = 13, Color = "Muted" },
    SettingsNavHover = { Object = NORMAL, Size = 13, Color = "Text" },
    SettingsNavSelected = { Object = NORMAL, Size = 13, Color = "LightHeader", Shadow = true },
    SettingsVersion = { Object = NORMAL, Size = 10, Color = "Muted" },
    SettingsTitle = { Object = HEADER, Size = 26, Color = "LightHeader", Shadow = true },
    SettingsDescription = { Object = NORMAL, Size = 13, Color = "Muted" },
    SettingsSection = { Object = NORMAL, Size = 11, Color = "LightHeader" },
    SettingsSectionNote = { Object = NORMAL, Size = 11, Color = "Muted" },
    SettingsLabel = { Object = NORMAL, Size = 13, Color = "Text" },
    SettingsText = { Object = NORMAL, Size = 12, Color = "Muted" },
    SettingsLink = { Object = NORMAL, Size = 12, Color = "Gold" },
  },

  Layout = {
    -- The header band is its file's painted rows (19 to 64 of 64) from the body's top, 45 tall: the title on it, as
    -- the original's (35 in, 10 up from its bottom), the search bar 13 below it, as the original's.
    TitleTop = 13,
    TitleInset = 17,
    SearchTop = 58,
    SearchHeight = 24,
    ContentTop = 92,
    -- The footer band, 30 tall (its painted rows), the free slots and the money on it.
    Footer = 34,
    FooterText = 9,
    FooterMoney = 8,
    -- GW2_UI's bag section rows: a name on a row of bag-sep.png (GwBagHeaderTemplate, 32 tall).
    SectionHeader = 30,
    -- The original's actions: 32 square, 5 apart down the side panel.
    HeaderButton = 32,
    HeaderButtonGap = 5,
  },

  Panel = {
    Fill = { Texture = "Map", Color = "White" },
    -- Asked: no feather while docked (a small panel has none).
    Feather = false,
    Wash = false,
    Edge = { Color = "Black", Alpha = 0.6, Size = 1 },
    DropGlow = { Color = "LightHeader", Alpha = 0.1, BlendMode = "ADD" },
    -- Drawn for the backpack (its inner side on the left), mirrored on the other panels.
    Ornaments = {
      -- The header band across the top, its right piece's painted columns (196 on) at the outer corner.
      { Texture = "Header", Point = "TOP", Height = 45, TexCoords = { 0, 1, 19 / 64, 1 } },
      { Texture = "HeaderEnd", Point = "TOPOUTER", Width = 316, Height = 45, TexCoords = { 196 / 512, 1, 19 / 64, 1 },
        SubLevel = 1 },
      -- The original's emblem, 84, at the top inner corner over the side panel; GW2_UI's merchant's on the vendor.
      { Texture = "BagEmblem", Point = "TOPINNER", Width = 84, Height = 84, X = -66, SubLevel = 2,
        Panels = { "Backpack", "Bank", "GuildBank" } },
      { Texture = "VendorEmblem", Point = "TOPINNER", Width = 84, Height = 84, X = -66, SubLevel = 2, Panels = { "Vendor" } },
      -- The footer band: the file's painted rows (0 to 34 of 64).
      { Texture = "Footer", Point = "BOTTOM", Height = 30, TexCoords = { 0, 1, 0, 34 / 64 } },
    },
  },

  Header = {
    Title = { Font = "Title" },
    TitleGlow = { Color = "LightHeader", Alpha = 0.15 },
    Ribbon = false,
    Spark = false,
    Cloud = false,
    -- Down GW2_UI's side panel, standing outside the window along its inner side (its art's painted rows 0 to 481 of
    -- 512), below the emblem; the close button at the top outer corner. Glyphs where GW2_UI has no icon, in its
    -- LightHeader; GW2's art at 32 (Scale over Buttons.Scale), its own art under the pointer where it has some.
    Buttons = {
      Color = "LightHeader", HoverColor = "White", ArtColor = "White", ArtHoverColor = "LightHeader", Scale = 0.75,
      -- The first button 4 below the emblem's square (84).
      Rail = { Width = 40, Top = 88, Gap = 5, Outside = true,
        Fill = { Texture = "SidePanel", TexCoords = { 0, 1, 0, 481 / 512 }, Color = "White" } },
      Pinned = { closeButton = { Point = "TOPOUTER", X = -6, Y = -6 } },
      Icons = {
        -- Its X is 16 of its 26 pixels: drawn at 26.
        closeButton = { Texture = "Close", Glyph = false, Scale = 1.1, Hover = { Texture = "CloseHover" } },
        bagsButton = { Texture = "MicroBag", Glyph = false, Scale = 4 / 3, Hover = { Texture = "MicroBagDown" } },
        sortButton = { Texture = "MicroCollections", Glyph = false, Scale = 4 / 3 },
        settingsButton = { Texture = "MicroQuestLog", Glyph = false, Scale = 4 / 3 },
        sizeButtonFull = { Texture = "Minimize", Glyph = false, Scale = 4 / 3 },
        sizeButtonSmall = { Texture = "Maximize", Glyph = false, Scale = 4 / 3 },
        -- GW2_UI's bank tab icons (Inventory/bank.xml): the character bank's and the Warbank's.
        bankTabsButton = { Texture = "BankIcons", TexCoords = { 0, 0.5, 0.5, 1 }, Glyph = false, Scale = 4 / 3 },
        depositButton = { Texture = "BankIcons", TexCoords = { 0.5, 1, 0, 0.5 }, Glyph = false, Scale = 4 / 3 },
        repairAllButton = { Texture = "Repair", Glyph = false, Scale = 4 / 3 },
      },
    },
  },

  -- GW2_UI's bag search bar (SkinBagSearchBox): its art, no border.
  Search = {
    Fill = { Texture = "SearchBar", Color = "White", Alpha = 0.85 },
    FocusFill = { Texture = "SearchBar", Color = "White", Alpha = 1 },
    Edge = false,
    Icon = { Color = "LightHeader", FocusColor = "White" },
  },

  -- GW2_UI's bag section rows (GwBagHeaderTemplate): the name on bag-sep.png across the section, menu-hover.png under
  -- the pointer; the row is the separator, so no line.
  Sections = {
    Title = { X = 8, Y = -8 },
    Header = { Texture = "SectionRow", Color = "White" },
    Line = false,
    Highlight = { Texture = "RowHover", Color = "White", Alpha = 0.6 },
  },

  -- GW2_UI's side tabs, dimmed until selected, its wine accent beside the selected one.
  Tabs = {
    Fill = { Texture = "Tab", TexCoords = TAB, Color = "TabIdle" },
    SelectedFill = { Texture = "Tab", TexCoords = TAB, Color = "White" },
    Glow = { Color = "LightHeader", Drop = 0.25, Pulse = 0.6 },
    Indicator = { Color = "Accent", Width = 3 },
  },

  -- The footer band is its line.
  Footer = { Line = false },

  Sparkles = false,

  Chain = { Braid = false, Color = "LightHeader", BeadColor = "Bead", KnotColor = "LightHeader" },

  Small = {
    Grip = {
      Normal = { Texture = "Resize" },
      Highlight = { Texture = "Resize", BlendMode = "ADD" },
      Pushed = { Texture = "Resize" },
    },
  },

  Drag = { Shadow = { Color = "Black", Alpha = 0.45 } },

  -- A waiting section's card on GW2_UI's backdrop (GW.BackdropTemplates.Default), its edge pulsing in LightHeader.
  Dock = {
    Card = { Texture = "Backdrop", Color = "White" },
    Glow = { Color = "LightHeader" },
    Halo = false,
  },

  Vendor = {
    QualityBorder = "ItemBorder",
    Highlight = { 1, 1, 1, 0.12 },
    CardFill = { Texture = "Backdrop", Color = "White", Alpha = 0.6 },
    CardHover = { Texture = "RowHover", Color = "White", Alpha = 0.6 },
  },

  -- GW2_UI's item buttons (Sonata's ItemButton element: files by path).
  ItemButton = {
    Icon = { Inset = 0, TexCoords = { 0.07, 0.93, 0.07, 0.93 } },
    Backdrop = { Texture = GW .. "bag\\bagitembackdrop.png" },
    QualityBorder = { Texture = GW .. "bag\\bagitemborder.png", Alpha = 0.9 },
    -- A common item framed in GW2_UI's frame for an icon without quality (SkinColors.IconBorder).
    QualityColors = { [1] = { 0.45, 0.45, 0.45, 1 } },
    QuestBorderColor = { 1, 0.8, 0.1, 1 },
    Highlight = { Texture = GW .. "bag\\bagitemborder.png", BlendMode = "ADD", Alpha = 0.33 },
    Pushed = { Texture = GW .. "uistuff\\ui-quickslot-depress.png" },
    Count = { Font = { Object = "NumberFontNormal" }, Points = { { Point = "TOPRIGHT", X = 0, Y = -3 } } },
  },

  -- GW2_UI's settings window (Settings/settingsWindow.xml): its panel painting (its painted rows, 0 to 754 of 1024),
  -- its menu backing (236menubg.png, painted 226 x 484), its brand separator (levelreward-sep.png, painted columns 63
  -- to 416) and its divider (settingspanelsep.png, 4 columns, 434 rows); its list rows (menu-hover.png).
  Settings = {
    Fill = { Texture = "SettingsPanel", TexCoords = { 0, 1, 0, 754 / 1024 }, Color = "White" },
    Wash = false,
    Edge = { Color = "Black", Alpha = 0.6 },
    Sidebar = {
      Fill = { Texture = "SettingsMenu", TexCoords = { 0, 226 / 256, 0, 484 / 512 }, Color = "White" },
      Line = { Texture = "SettingsDivider", TexCoords = { 0, 0.5, 0, 434 / 512 }, Color = "White", Size = 4 },
    },
    Brand = {
      IconColor = "LightHeader",
      Line = { Texture = "BrandLine", TexCoords = { 63 / 512, 417 / 512, 0, 1 }, Color = "White", Alpha = 0.8, Size = 2 },
    },
    Search = { IconColor = "LightHeader" },
    Back = { IconColor = "LightHeader" },
    -- GW2_UI's list rows: menu-hover.png at ListSelected and ListHover (SkinColors).
    Nav = {
      Indicator = { Color = "Accent" },
      SelectedFill = { Texture = "RowHover", Color = { 0.8, 0.8, 0.8, 1 }, Alpha = 1 },
      HoverFill = { Texture = "RowHover", Color = { 0.8, 0.8, 0.8, 1 }, Alpha = 0.8 },
    },
    Header = { Close = { Color = "LightHeader", HoverColor = "White" } },
    Content = {
      Card = { Color = "Black", Alpha = 0.22 },
      Divider = { Color = "Lavender", Alpha = 0.08 },
      Hover = { Texture = "RowHover", Color = "White", Alpha = 0.5 },
    },
    Footer = { Line = { Color = "Lavender", Alpha = 0.12 } },
    Cards = {
      Fill = { Texture = "Backdrop", Color = "White", Alpha = 0.6 },
      HoverFill = { Texture = "RowHover", Color = { 0.8, 0.8, 0.8, 1 }, Alpha = 0.35 },
      Edge = { Color = "Lavender", Alpha = 0.15 },
      SelectedEdge = { Color = "Gold", Alpha = 0.9 },
    },
    Categories = {
      Indicator = { Color = "Accent" },
      SelectedFill = { Texture = "RowHover", Color = { 0.8, 0.8, 0.8, 1 }, Alpha = 1 },
      HoverFill = { Texture = "RowHover", Color = { 0.8, 0.8, 0.8, 1 }, Alpha = 0.8 },
    },
    BagCategories = {
      Fill = { Color = "Black", Alpha = 0.22 },
      HoverFill = { Texture = "RowHover", Color = { 0.8, 0.8, 0.8, 1 }, Alpha = 0.8 },
    },
    Currency = { Hover = { Texture = "RowHover", Color = "White", Alpha = 0.5 } },
  },

  Controls = {
    -- GW2_UI's scroll bars: scrollbg.png under scrollbarmiddle.png.
    ScrollBar = {
      Size = 6, HoverSize = 8,
      Track = { Texture = "ScrollTrack", Color = "White", Alpha = 0.6 },
      Thumb = { Texture = "ScrollThumb", Color = "White" },
      ThumbHover = { Texture = "ScrollThumb", Color = "LightHeader" },
      ThumbDrag = { Texture = "ScrollThumb", Color = "Gold" },
    },
    -- GW2_UI's check boxes (GwSkinCheckButton): the box, the mark over it while checked, the disabled box, the mark
    -- greyed while disabled.
    Toggle = {
      Style = "Check",
      Width = 22, Height = 22,
      Off = { Texture = "Check", Color = "White" },
      On = { Texture = "Checked", Color = "White", Alpha = 1 },
      Disabled = { Texture = "CheckOff", Color = "White" },
      DisabledOn = { Texture = "Checked", Color = "Disabled" },
      Hover = { Color = "White", Alpha = 0.08 },
    },
    -- GW2_UI's cream buttons (GwSkinButton): button.png, darker under the pointer and pressed, button_disable.png
    -- disabled, dark text, no edge.
    Button = {
      Plain = {
        Fill = { Texture = "Button", Color = "White" },
        HoverFill = { Texture = "Button", Color = "ButtonHover" },
        PressedFill = { Texture = "Button", Color = "ButtonPressed" },
        DisabledFill = { Texture = "ButtonOff", Color = "White" },
        Edge = false, HoverEdge = false,
      },
      Primary = {
        Fill = { Texture = "Button", Color = "White" },
        HoverFill = { Texture = "Button", Color = "ButtonHover" },
        PressedFill = { Texture = "Button", Color = "ButtonPressed" },
        DisabledFill = { Texture = "ButtonOff", Color = "White" },
        Edge = false, HoverEdge = false,
      },
      Danger = {
        Fill = { Texture = "Button", Color = "White" },
        HoverFill = { Texture = "Button", Color = "ButtonHover" },
        PressedFill = { Texture = "Button", Color = "ButtonPressed" },
        DisabledFill = { Texture = "ButtonOff", Color = "White" },
        Edge = false, HoverEdge = false,
      },
    },
    -- GW2_UI's fields (editBox.lua): statusbar.png at half, edged in black.
    Input = {
      Fill = { Texture = "Field", Color = "White", Alpha = 0.5 },
      FocusFill = { Texture = "Field", Color = "White", Alpha = 0.75 },
      Edge = { Color = "Black", Size = 1, Idle = 0.8, Hover = 0.9, Focus = 1 },
    },
    -- GW2_UI's sliders: sliderbg.png and sliderhandle.png.
    Slider = {
      ThumbSize = 14,
      Track = { Texture = "SliderTrack", Color = "White", Alpha = 0.6 },
      Fill = { Color = "Accent", Alpha = 0.9 },
      Thumb = { Texture = "SliderThumb", Color = "White" },
      ThumbHover = { Texture = "SliderThumb", Color = "LightHeader" },
    },
    -- GW2_UI's dropdowns (GwHandleDropDownBox): its backdrop, edged, its down arrow.
    Dropdown = {
      Fill = { Texture = "Backdrop", Color = "White" },
      HoverFill = { Texture = "Backdrop", Color = "White" },
      OpenFill = { Texture = "Backdrop", Color = "White" },
      Edge = { Color = "Lavender" },
      Chevron = { Texture = "Arrow", Color = "White", Size = 16 },
    },
    -- GW2_UI's menus (Immersive/Skins/menu.lua): its backdrop, button_hover.png under the pointer, its check mark for
    -- the chosen row.
    Menu = {
      Fill = { Texture = "Backdrop", Color = "White" },
      Edge = { Color = "Lavender", Alpha = 0.3 },
      HoverFill = { Texture = "ButtonHover", Color = "LightHeader", Alpha = 0.25 },
      Check = { Texture = "Checked", Color = "White", Size = 14 },
    },
    TopTabs = { Indicator = { Color = "Accent" }, Line = { Color = "Lavender", Alpha = 0.12 } },
    -- GW2_UI's dialogs (GW.BackdropTemplates.DefaultWithSmallBorder): its backdrop, edged dark.
    Dialog = {
      Card = { Texture = "Backdrop", Color = "White" },
      Edge = { Color = "Black", Alpha = 0.8 },
    },
    ItemGrid = { Hover = { Color = "LightHeader", Alpha = 0.18 } },
  },
})
