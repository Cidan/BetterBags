---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class MoneyFrame: AceModule
local money = addon:GetModule('MoneyFrame')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Events: AceModule
local events = addon:GetModule('Events')


function money:CreateButton(kind, parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(32, 13)
  if kind == "copper" then
    b:SetPoint("RIGHT", 0, 0)
  else
    b:SetPoint("RIGHT", parent, "LEFT", -4, 0)
  end
 b:SetNormalTexture("Interface\\MONEYFRAME\\UI-MoneyIcons")
  b:GetNormalTexture():ClearAllPoints()
  b:GetNormalTexture():SetPoint("RIGHT", 0, 0)
  b:GetNormalTexture():SetSize(13, 13)
  if kind == "copper" then
    b:GetNormalTexture():SetTexCoord(0.5, 0.75, 0, 1)
  elseif kind == "silver" then
    b:GetNormalTexture():SetTexCoord(0.25, 0.5, 0, 1)
  else
    b:GetNormalTexture():SetTexCoord(0, 0.25, 0, 1)
  end
  local fs = b:CreateFontString(nil, "OVERLAY")
  b:SetFontString(fs)
  b:SetNormalFontObject("NumberFontNormalRight")
  fs:SetPoint("RIGHT", -13, 0)
  b:SetScript("OnClick", function()
    StaticPopup_Show("PICKUP_MONEY")
  end)
  b:Show()
  return b
end