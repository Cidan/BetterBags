local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@param button Button
local function resetCloseButton(button)
  button:SetDisabledAtlas("RedButton-Exit-Disabled")
  button:SetNormalAtlas("RedButton-Exit")
  button:SetPushedAtlas("RedButton-exit-pressed")
  button:SetHighlightAtlas("RedButton-Highlight", "ADD")
end

---@type Theme
local defaultTheme = {
  Name = 'Default',
  Description = 'The default theme.',
  Available = true,
  Portrait = function (frame)
    NineSliceUtil.ApplyLayoutByName(frame.NineSlice, "HeldBagLayout")
    frame.Bg:SetTexture([[Interface\FrameGeneral\UI-Background-Rock]])
    frame.Bg:SetHorizTile(true)
    frame.Bg:SetVertTile(true)
    frame.NineSlice:Show()
    frame.Bg:Show()
    frame.TopTileStreaks:Show()
    frame.Backdrop:Hide()
    frame.PortraitContainer.CircleMask:SetTexture([[Interface\CharacterFrame\TempPortraitAlphaMask]])
    frame.PortraitContainer.CircleMask:SetPoint("TOPLEFT", frame.PortraitContainer.portrait, "TOPLEFT", 2, 0)
    frame.PortraitContainer.CircleMask:SetPoint("BOTTOMRIGHT", frame.PortraitContainer.portrait, "BOTTOMRIGHT", -2, 4)
    frame:SetPortraitToAsset([[Interface\Icons\INV_Misc_Bag_07]])
    frame:SetPortraitTextureSizeAndOffset(38, -5, 0)
    frame.TitleContainer.TitleText:SetFontObject("GameFontNormal")
    frame.TitleContainer:Show()
    resetCloseButton(frame.CloseButton)
    frame.CloseButton:Show()
    -- <Color r="1.0" g="0.82" b="0"/>
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
    frame.TitleContainer.TitleText:SetFontObject("GameFontNormal")
  end,
  Flat = function(frame)
    frame.Backdrop:Hide()
    NineSliceUtil.ApplyLayoutByName(frame.NineSlice, "ButtonFrameTemplateNoPortrait")
    frame.NineSlice:Show()
    frame.Bg:Show()
    frame.TitleContainer.TitleText:SetFontObject("GameFontNormal")
  end,
  Opacity = function(frame, alpha)
    frame.Bg:SetAlpha(alpha / 100)
  end,
  SectionFont = function(font)
    font:SetFontObject("GameFontNormal")
  end,
  Reset = function(windows, sectionFonts)
  end
}

themes:RegisterTheme('Default', defaultTheme)