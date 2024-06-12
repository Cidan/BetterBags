local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@type Theme
local simpleDark = {
  Name = 'Simple Dark',
  Description = 'A simple dark theme.',
  Available = true,
  Portrait = function(frame)
    frame.NineSlice:Hide()
    frame.Bg:Hide()
    frame.TopTileStreaks:Hide()
    frame.PortraitContainer.CircleMask:SetTexture([[Interface\Common\Common-IconMask]])
    frame.PortraitContainer.CircleMask:SetPoint("TOPLEFT", frame.PortraitContainer.portrait, "TOPLEFT", 2, -2)
    frame.PortraitContainer.CircleMask:SetPoint("BOTTOMRIGHT", frame.PortraitContainer.portrait, "BOTTOMRIGHT", -2, 1)
    frame:SetPortraitTextureSizeAndOffset(30, 4, -7)
    frame.Backdrop:SetBackdrop({
      bgFile = 'Interface\\ChatFrame\\ChatFrameBackground',
      edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
      edgeSize = 16,
      insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    frame.Backdrop:SetBackdropColor(0, 0, 0, 1)
    frame.Backdrop:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    frame.Backdrop:Show()
    frame.TitleContainer.TitleText:SetFont(UNIT_NAME_FONT, 12, "")
    frame.TitleContainer.TitleText:SetTextColor(1, 1, 1)
    frame.TitleContainer:Show()
    frame.PortraitContainer:Show()
    frame.Owner.sideAnchor:ClearAllPoints()
    frame.Owner.sideAnchor:SetPoint("TOPRIGHT", frame, "TOPLEFT")
    frame.Owner.sideAnchor:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT")
    themes:resetCloseButton(frame.CloseButton)
    frame.CloseButton:Show()
  end,
  Simple = function(frame)
    frame.NineSlice:Hide()
    frame.Bg:Hide()
    frame.TopTileStreaks:Hide()
    frame.Backdrop:SetBackdrop({
      bgFile = 'Interface\\ChatFrame\\ChatFrameBackground',
      edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
      edgeSize = 16,
      insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    frame.Backdrop:SetBackdropColor(0, 0, 0, 1)
    frame.Backdrop:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    frame.Backdrop:Show()
    frame.TitleContainer.TitleText:SetFont(UNIT_NAME_FONT, 12, "")
    frame.TitleContainer.TitleText:SetTextColor(1, 1, 1)
    frame.TitleContainer:Show()
    themes:resetCloseButton(frame.CloseButton)
    frame.CloseButton:Show()
  end,
  Flat = function (frame)
    frame.NineSlice:Hide()
    frame.Bg:Hide()
    frame.Backdrop:SetBackdrop({
      bgFile = 'Interface\\ChatFrame\\ChatFrameBackground',
      edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
      edgeSize = 16,
      insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    frame.Backdrop:SetBackdropColor(0, 0, 0, 1)
    frame.Backdrop:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    frame.Backdrop:Show()
    frame.TitleContainer.TitleText:SetFont(UNIT_NAME_FONT, 12, "")
    frame.TitleContainer.TitleText:SetTextColor(1, 1, 1)
    frame.TitleContainer:Show()
  end,
  Opacity = function(frame, alpha)
    frame.Backdrop:SetBackdropColor(0, 0, 0, alpha / 100)
  end,
  SectionFont = function(font)
    font:SetFont(UNIT_NAME_FONT, 12, "")
    font:SetTextColor(1, 1, 1)
  end,
  Reset = function()
  end
}

themes:RegisterTheme('SimpleDark', simpleDark)