local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

-- Default is Blizzard's look. Bags and panels are DefaultPanelTemplate windows (the rock
-- background fading with the opacity, the NineSlice border and title bar above the content)
-- with Blizzard's red close button; flat windows and dialogs are DefaultPanelFlatTemplate.
-- The slots panels are headerless flat panels, except where that template cannot be used:
-- Classic draws a title band on it that cannot be hidden (classic-bag-slots-panel.md), and
-- WoW: Forever redraws its header art too tall (camelot-forever.md section 5), so those use a
-- dark tooltip frame with even padding.
local PANEL = {
  Template = {
    Name = "DefaultPanelTemplate",
    Level = -1,
    Levels = { NineSlice = 500, TitleContainer = 501 },
    TitleFont = { Object = "UnitFrame12Yellow" },
    Opacity = "Bg",
  },
  CloseButton = { Template = "UIPanelCloseButtonDefaultAnchors" },
}

local FLAT_TEMPLATE = {
  Name = "DefaultPanelFlatTemplate",
  TitleFont = { Object = "UnitFrame12Yellow" },
  HideTitleWhenEmpty = true,
}

local TOOLTIP_PADDING = { Left = 8, Right = 8, Top = 8, Bottom = 8 }

sonata:RegisterTheme({
  Name = "Default",
  DisplayName = "Default",
  Description = "The default theme.",
  Windows = {
    Bag = PANEL,
    Panel = PANEL,
    Flat = {
      Template = FLAT_TEMPLATE,
      CloseButton = { Template = "UIPanelCloseButton", Points = { { Point = "TOPRIGHT", X = 2, Y = 2 } } },
    },
    Dialog = { Template = FLAT_TEMPLATE },
    -- BetterBagsSearchPanelTemplate is SimplePanelTemplate on retail and BetterBags' own panel
    -- art on Classic; both carry an Inset frame the overlay does not use.
    Search = { Template = { Name = "BetterBagsSearchPanelTemplate", Title = false, Hide = { "Inset" } } },
    Slots = {
      Template = { Name = "DefaultPanelFlatTemplate", HideTitleWhenEmpty = true },
      Insets = { Left = 10, Right = 6, Top = 30, Bottom = 12 },
    },
  },
  Elements = {
    SectionHeader = { Font = { Object = "UnitFrame12Yellow" } },
  },
  Clients = {
    Classic = {
      Windows = {
        Slots = {
          Template = false,
          Insets = TOOLTIP_PADDING,
          Backdrop = {
            BgFile = "Interface/Tooltips/UI-Tooltip-Background",
            EdgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            Tile = true,
            TileSize = 16,
            EdgeSize = 16,
            Insets = { Left = 4, Right = 4, Top = 4, Bottom = 4 },
            Color = { 0, 0, 0, 0.9 },
            BorderColor = { 1, 1, 1, 1 },
            Opacity = false,
          },
        },
      },
    },
    Forever = {
      Windows = {
        Slots = {
          Template = {
            Name = "TooltipBorderedFrameTemplate",
            BackdropColor = { 0, 0, 0, 0.9 },
            BackdropBorderColor = { 1, 1, 1, 1 },
          },
          Insets = TOOLTIP_PADDING,
          -- The tooltip border is thicker than the bag window's.
          Layout = { Offset = { X = 4, Y = -2 } },
        },
      },
    },
  },
})
