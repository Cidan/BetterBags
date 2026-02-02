---@diagnostic disable: duplicate-set-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class CurrencyPane: AceModule
local currencyPane = addon:GetModule('CurrencyPane')

-------
--- Era Currency Pane Override
--- Classic Era doesn't have the currency system.
-------

---@param parent Frame
---@return Frame
function currencyPane:Create(parent)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetAllPoints()

  local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  text:SetPoint("CENTER", 0, 0)
  text:SetText(L:G("Currency is not available in this version of World of Warcraft."))
  text:SetTextColor(0.5, 0.5, 0.5)

  return frame
end
