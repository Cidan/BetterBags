local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@type Theme
local defaultTheme = {
  Portrait = function (frame)
    NineSliceUtil.ApplyLayoutByName(frame.NineSlice, "HeldBagLayout")
    frame.NineSlice:Show()
    frame.Bg:Show()
    frame:SetPortraitToAsset([[Interface\Icons\INV_Misc_Bag_07]])
    frame:SetPortraitTextureSizeAndOffset(38, -5, 0)
  end,
  Simple = function (frame)

  end
}

themes:RegisterTheme('Default', defaultTheme)