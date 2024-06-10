local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@type Theme
local simpleDark = {
  Name = 'Simple Dark',
  Description = 'A simple dark theme.',
  Portrait = function(frame)
    frame.NineSlice:Hide()
    frame.Bg:Hide()
    frame.Backdrop:SetBackdrop({
      bgFile = 'Interface\\ChatFrame\\ChatFrameBackground',
      edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
      edgeSize = 16,
      insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    frame.Backdrop:SetBackdropColor(0, 0, 0, 0.8)
    frame.Backdrop:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    frame.Backdrop:Show()
  end,
  Simple = function(frame)
    frame.NineSlice:Hide()
  end
}

themes:RegisterTheme('SimpleDark', simpleDark)