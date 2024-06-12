local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@type Theme
local defaultTheme = {
  Name = 'Default',
  Description = 'The default theme.',
  Available = true,
  Portrait = function(frame)
    themes.ShowDefaultDecoration(frame)
  end,
  Simple = function(frame)
    frame.Backdrop:Hide()
    NineSliceUtil.ApplyLayoutByName(frame.NineSlice, "ButtonFrameTemplateNoPortrait")
    frame.Bg:SetTexture([[Interface\FrameGeneral\UI-Background-Rock]])
    frame.Bg:SetHorizTile(true)
    frame.Bg:SetVertTile(true)
    frame.NineSlice:Show()
    frame.Bg:Show()
    frame.TopTileStreaks:Show()
    frame.TitleContainer.TitleText:SetFont(UNIT_NAME_FONT, 12, "")
    frame.TitleContainer.TitleText:SetTextColor(1, 0.82, 0)
    frame.TitleContainer:Show()
    themes:resetCloseButton(frame.CloseButton)
    frame.CloseButton:Show()
  end,
  Flat = function(frame)
    frame.Backdrop:Hide()
    NineSliceUtil.ApplyLayoutByName(frame.NineSlice, "ButtonFrameTemplateNoPortrait")
    frame.NineSlice:Show()
    frame.Bg:Show()
    frame.TitleContainer.TitleText:SetFont(UNIT_NAME_FONT, 12, "")
    frame.TitleContainer.TitleText:SetTextColor(1, 0.82, 0)
    frame.TitleContainer:Show()
  end,
  Opacity = function(frame, alpha)
    frame.Bg:SetAlpha(alpha / 100)
  end,
  SectionFont = function(font)
    font:SetFont(UNIT_NAME_FONT, 12, "")
    font:SetTextColor(1, 0.82, 0)
  end,
  Reset = function(_, _)
  end
}

themes:RegisterTheme('Default', defaultTheme)