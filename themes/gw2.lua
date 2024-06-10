local addonName = ... ---@type string
local gw = GW2_ADDON

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@type Theme
local gw2Theme = {
  Name = "Guild Wars 2",
  Description = "A theme using the GW2_UI style.",
  Available = gw ~= nil,
  Portrait = function(frame)
    frame.Backdrop:ClearBackdrop()
    gw.CreateFrameHeaderWithBody(frame.Backdrop, frame.TitleContainer.TitleText, "Interface/AddOns/GW2_UI/textures/bag/bagicon", {})
    frame.NineSlice:Hide()
    frame.Backdrop:Show()
    frame.Bg:Hide()
    frame.TopTileStreaks:Hide()
    --frame.PortraitContainer:Hide()
  end,
  Simple = function(frame)
  end,
  Flat = function(frame)
  end,
  Opacity = function(frame, alpha)
  end,
  SectionFont = function(font)
  end
}

themes:RegisterTheme('GW2', gw2Theme)