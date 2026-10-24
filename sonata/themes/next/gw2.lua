local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- Guild Wars 2: BetterBags Next in GW2_UI's look, offered while GW2_UI is loaded (docs/next-gw2-theme.md). Data
-- only, nothing of GW2_UI's called: its art drawn from its own files, read from its source (.libraries/GW2_UI):
--   The panels: GW2_UI's bag painting (bag\bagbg.png) for the body; its window header across the top and its footer
--     band along the bottom; its side panel (bag\bagleftpanel.png) down the inner side with the header's buttons on
--     it (asked: "side buttons can be left on backpack, and right on other bags"); its bag emblem at the top of it on
--     the bag, bank and guild bank and its merchant's on the vendor (Inventory/bag.xml, bank.xml, guildBank.lua,
--     Immersive/Skins/merchant.lua); its brush edge in the bottom outer corner; its close button art.
--   Text: GW2_UI's own fonts, copied from the client fonts it rewrites at login (Core/fonts.lua: GameFontHighlight in
--     its normal family, SystemFont_Shadow_Large in its header family), so the player's locale and GW2 font settings
--     are followed; its colors (Core/color.lua): LightHeader titles, its wine accent, its skin colors.
--   Item buttons: GW2_UI's skin (Inventory/inventory.lua, reskinItemButton).
--   The settings window, menus and dialogs: GW2_UI's character window painting, its list rows, its cream buttons.
-- No sparkles, shimmer, cloud or ribbon: GW2_UI's look is painted, not starry.
local GW = "Interface\\AddOns\\GW2_UI\\Textures\\"

-- character\windowbg.png is painted in its top 754 rows of 1024 (measured from the file).
local WINDOW = { 0, 1, 0, 754 / 1024 }
-- The roles' client fonts, as GW2_UI rewrites them: its normal family, and its header family for titles.
local NORMAL, HEADER = "GameFontHighlight", "SystemFont_Shadow_Large"
-- GW2_UI's side panel is 40 wide (GwWindowLeftPanel, Core/shared.xml).
local RAIL = 40

sonataNext:RegisterTheme({
  Name = "GW2",
  DisplayName = "Guild Wars 2",
  Description = "GW2_UI's look: its painted bag, header and side panel, its fonts, colors and item buttons.",
  Requires = { "GW2_UI" },

  Textures = {
    BagBody = GW .. "bag\\bagbg.png",
    Window = GW .. "character\\windowbg.png",
    Header = GW .. "bag\\bagheader.png",
    HeaderEnd = GW .. "bag\\bagheader-right.png",
    Footer = GW .. "bag\\bagfooter.png",
    SidePanel = GW .. "bag\\bagleftpanel.png",
    Corner = GW .. "bag\\bottom-right.png",
    BagEmblem = GW .. "bag\\bagicon.png",
    VendorEmblem = GW .. "character\\macro-window-icon.png",
    ItemBorder = GW .. "bag\\bagitemborder.png",
    RowHover = GW .. "character\\menu-hover.png",
    Button = GW .. "uistuff\\button.png",
    Close = GW .. "uistuff\\window-close-button-normal.png",
    Resize = GW .. "uistuff\\resize.png",
  },

  Palette = {
    -- GW2_UI's text colors and accent (GW.Colors.TextColors.LightHeader, GW.Colors.Accent).
    LightHeader = { 1, 0.9450, 0.8196, 1 },
    Accent = { 150 / 255, 50 / 255, 50 / 255, 1 },
    -- Its skin colors: light frames (CreamBorder), the second line under a name (SubText), an empty field's hint
    -- (Placeholder), money (MoneyColors.Gold), negative and positive.
    Lavender = { 1, 0.99, 0.85, 1 },
    Muted = { 0.75, 0.75, 0.75, 1 },
    Placeholder = { 0.7, 0.7, 0.7, 1 },
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
    -- The bag painting's average (0.189, 0.118, 0.098), for the feather beside it; its tabs' (units\unittab_down.png).
    Body = { 0.19, 0.12, 0.10, 0.92 },
    Tab = { 0.13, 0.17, 0.19, 0.9 },
    TabSelected = { 0.2, 0.25, 0.27, 0.96 },
    Card = { 0.1, 0.09, 0.08, 0.98 },
    SearchFill = { 0.06, 0.05, 0.05, 0.85 },
    SearchFillFocus = { 0.1, 0.08, 0.07, 0.95 },
    Shadow = { 0, 0, 0, 0.9 },
    ButtonIcon = { 1, 0.9450, 0.8196, 1 },
    Bead = { 1, 0.9450, 0.8196, 1 },
    ControlFill = { 0.1, 0.085, 0.075, 0.9 },
    ControlHover = { 0.15, 0.125, 0.11, 0.95 },
    ControlPressed = { 0.07, 0.06, 0.05, 0.95 },
    Track = { 0.25, 0.21, 0.18, 1 },
    Sidebar = { 0, 0, 0, 0.35 },
    -- Dark text on GW2_UI's cream button.
    Ink = { 0.05, 0.04, 0.03, 1 },
  },

  -- GW2_UI's shadows are a pixel down and right.
  FontShadow = { Color = "Shadow", X = 1, Y = -1 },
  Fonts = {
    Title = { Object = HEADER, Size = 24, Color = "LightHeader", Shadow = true },
    Section = { Object = NORMAL, Size = 14, Color = "LightHeader", Shadow = true },
    SectionRecent = { Object = NORMAL, Size = 14, Color = "Gold", Shadow = true },
    SectionFree = { Object = NORMAL, Size = 13, Color = "Muted" },
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
    Button = { Object = NORMAL, Size = 12, Color = "LightHeader", Shadow = true },
    ButtonPrimary = { Object = NORMAL, Size = 12, Color = "Ink", Shadow = false },
    ButtonDanger = { Object = NORMAL, Size = 12, Color = "Danger", Shadow = true },
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

  -- The side panel's buttons are GW2_UI's 26 across, 8 apart.
  Layout = {
    HeaderButton = 26,
    HeaderButtonGap = 8,
  },

  Panel = {
    Fill = { Texture = "BagBody", Color = "White" },
    Feather = { Color = "Body" },
    Wash = false,
    Edge = { Color = "Black", Alpha = 0.6, Size = 1 },
    DropGlow = { Color = "LightHeader", Alpha = 0.1, BlendMode = "ADD" },
    -- Drawn for the backpack (its inner side on the left), mirrored on the other panels.
    Ornaments = {
      -- The header band from the side panel out; its dark end (the right piece's last quarter) at the outer corner.
      { Texture = "Header", Point = "TOP", Height = 64, Start = RAIL },
      { Texture = "HeaderEnd", Point = "TOPOUTER", Width = 128, Height = 64, TexCoords = { 0.75, 1, 0, 1 }, SubLevel = 1 },
      -- The emblem at the top of the side panel, over the header's start, out past the body's edge as GW2_UI's is.
      { Texture = "BagEmblem", Point = "TOPINNER", Width = 64, Height = 64, X = -12, SubLevel = 2,
        Panels = { "Backpack", "Bank", "GuildBank" } },
      { Texture = "VendorEmblem", Point = "TOPINNER", Width = 64, Height = 64, X = -12, SubLevel = 2, Panels = { "Vendor" } },
      -- The footer band: the file's top 34 rows (measured).
      { Texture = "Footer", Point = "BOTTOM", Height = 34, Start = RAIL, TexCoords = { 0, 1, 0, 34 / 64 } },
      { Texture = "Corner", Point = "BOTTOMOUTER", Width = 128, Height = 128, SubLevel = 1 },
    },
  },

  Header = {
    Title = { Font = "Title" },
    TitleGlow = { Color = "LightHeader", Alpha = 0.15 },
    Ribbon = false,
    Spark = false,
    Cloud = false,
    -- Down GW2_UI's side panel (its art's top 481 rows of 512, measured), below the emblem.
    Buttons = {
      Color = "LightHeader", HoverColor = "White", ArtColor = "White", ArtHoverColor = "LightHeader",
      Rail = { Width = RAIL, Top = 66, Gap = 8, Fill = { Texture = "SidePanel", TexCoords = { 0, 1, 0, 481 / 512 }, Color = "White" } },
      -- GW2_UI's close button (its X is 16 of its 26 pixels, a little larger to match the glyphs).
      Icons = { closeButton = { Texture = "Close", Glyph = false, Scale = 1.2 } },
    },
  },

  Search = {
    Edge = { Color = "Lavender", Idle = 0.2, Hover = 0.4, Focus = 0.7 },
    Icon = { Color = "LightHeader", FocusColor = "White" },
  },

  Sections = {
    Line = { Color = "Lavender", From = 0.25, To = 0 },
    Highlight = { Color = "LightHeader", From = 0.08 },
  },

  Tabs = {
    Fade = 0.5,
    Glow = { Color = "LightHeader", Drop = 0.25, Pulse = 0.6 },
    Indicator = { Color = "Accent" },
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

  -- A waiting section's card on GW2_UI's window painting, its edge pulsing in LightHeader.
  Dock = {
    Card = { Texture = "Window", TexCoords = WINDOW, Color = "White" },
    Glow = { Color = "LightHeader" },
    Halo = false,
  },

  Vendor = {
    QualityBorder = "ItemBorder",
    Highlight = { 1, 1, 1, 0.12 },
    CardFill = { 0, 0, 0, 0.25 },
    CardHover = { 1, 0.99, 0.85, 0.08 },
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

  Settings = {
    Fill = { Texture = "Window", TexCoords = WINDOW, Color = "White" },
    Wash = false,
    Edge = { Color = "Black", Alpha = 0.6 },
    Sidebar = { Fill = { Color = "Sidebar" }, Line = { Color = "Lavender", Alpha = 0.12 } },
    Brand = { IconColor = "LightHeader", Line = { Color = "Accent", From = 0.9 } },
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
      Fill = { Color = "Black", Alpha = 0.25 },
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
    ScrollBar = {
      Track = { Color = "Black", Alpha = 0.3 },
      Thumb = { Color = "Lavender", Alpha = 0.3 },
      ThumbHover = { Color = "Lavender", Alpha = 0.55 },
      ThumbDrag = { Color = "Gold", Alpha = 0.85 },
    },
    Toggle = {
      On = { Color = "Accent", Alpha = 1 },
      Edge = { Color = "Lavender", Alpha = 0.25 },
      Knob = { Color = "LightHeader" },
      KnobOn = { Color = "White" },
    },
    Button = {
      Plain = { Edge = { Color = "Lavender", Alpha = 0.3 }, HoverEdge = { Color = "Lavender", Alpha = 0.6 } },
      -- GW2_UI's cream button, brighter under the pointer, darker pressed, with dark text.
      Primary = {
        Fill = { Texture = "Button", Color = { 0.9, 0.9, 0.9, 1 }, Alpha = 1 },
        HoverFill = { Texture = "Button", Color = "White", Alpha = 1 },
        PressedFill = { Texture = "Button", Color = { 0.72, 0.72, 0.72, 1 }, Alpha = 1 },
        Edge = { Color = "Black", Alpha = 0.7 },
        HoverEdge = { Color = "Black", Alpha = 0.9 },
      },
    },
    Input = { Edge = { Color = "Lavender" } },
    Slider = { Fill = { Color = "Accent", Alpha = 1 }, Thumb = { Color = "LightHeader" }, ThumbHover = { Color = "White" } },
    Dropdown = { Edge = { Color = "Lavender" }, Chevron = { Color = "LightHeader" } },
    Menu = {
      Fill = { Texture = "Window", TexCoords = WINDOW, Color = "White" },
      Edge = { Color = "Lavender", Alpha = 0.3 },
      HoverFill = { Texture = "RowHover", Color = { 0.8, 0.8, 0.8, 1 }, Alpha = 0.8 },
      Check = { Color = "Gold" },
    },
    TopTabs = { Indicator = { Color = "Accent" }, Line = { Color = "Lavender", Alpha = 0.12 } },
    Dialog = {
      Card = { Texture = "Window", TexCoords = WINDOW, Color = "White" },
      Edge = { Color = "Lavender", Alpha = 0.35 },
    },
    ItemGrid = { Hover = { Color = "LightHeader", Alpha = 0.18 } },
  },
})
