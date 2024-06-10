local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@type Theme
local defaultTheme = {
  Name = 'Default',
  Description = 'The default theme.',
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
  end,
  Flat = function(frame)
    frame.Backdrop:Hide()
    NineSliceUtil.ApplyLayoutByName(frame.NineSlice, "ButtonFrameTemplateNoPortrait")
    frame.NineSlice:Show()
    frame.Bg:Show()
  end,
  Opacity = function(frame, alpha)
    frame.Bg:SetAlpha(alpha / 100)
  end,
  MenuButton = function (button)
    local parent = button:GetParent() --[[@as PortraitContainer]]
    button:SetWidth(40)
    button:SetHeight(40)
    button:SetPoint("TOPLEFT", parent.portrait, "TOPLEFT", -1, 2)
  end
}

themes:RegisterTheme('Default', defaultTheme)