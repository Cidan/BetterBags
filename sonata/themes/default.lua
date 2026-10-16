local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

-- Default is Blizzard's look: the bag is a DefaultPanelTemplate window (its rock background
-- fading with the bag's opacity, its NineSlice border and title bar above the bag's content)
-- with Blizzard's red close button, and section titles in BetterBags' yellow unit-frame font.
sonata:RegisterTheme({
  Name = "Default",
  DisplayName = "Default",
  Description = "The default theme.",
  Windows = {
    Bag = {
      Template = {
        Name = "DefaultPanelTemplate",
        Level = -1,
        Levels = { NineSlice = 500, TitleContainer = 501 },
        TitleFont = { Object = "UnitFrame12Yellow" },
        Opacity = "Bg",
      },
      CloseButton = { Template = "UIPanelCloseButtonDefaultAnchors" },
    },
  },
  Elements = {
    SectionHeader = { Font = { Object = "UnitFrame12Yellow" } },
  },
})
