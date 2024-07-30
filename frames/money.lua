---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class MoneyFrame: AceModule
local money = addon:NewModule('MoneyFrame')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Money
---@field frame Frame
---@field copperButton Button
---@field silverButton Button
---@field goldButton Button
---@field warbank? boolean
money.moneyProto = {}

function money.moneyProto:Update()
  local currentMoney = 0
  if self.warbank then
    currentMoney = C_Bank.FetchDepositedMoney(Enum.BankType.Account)
  else
    currentMoney = GetMoney()
  end
  local gold = floor(currentMoney / 1e4)
  local silver = floor(currentMoney / 100 % 100)
  local copper = currentMoney % 100
  self.goldButton:SetText(BreakUpLargeNumbers(gold))
  self.silverButton:SetText(tostring(silver))
  self.copperButton:SetText(tostring(copper))
  self.copperButton:SetWidth(self.copperButton:GetTextWidth() + 13)
  self.silverButton:SetWidth(self.silverButton:GetTextWidth() + 13)
end

---@param warbank? boolean
---@return Money
function money:Create(warbank)
  ---@type Money
  local m = setmetatable({}, { __index = money.moneyProto })
  m.warbank = warbank

  local f = CreateFrame("Frame", addonName .. "MoneyFrame", UIParent)
  m.frame = f
  m.frame:SetSize(128,18)
  m.copperButton = self:CreateButton("copper", m.frame, warbank)
  m.silverButton = self:CreateButton("silver", m.copperButton, warbank)
  m.goldButton = self:CreateButton("gold", m.silverButton, warbank)
  m.frame:Show()

  m:Update()
  events:RegisterEvent("PLAYER_MONEY", function()
    m:Update()
  end)
  return m
end


---@param kind string
---@param parent Frame
---@param warbank? boolean
---@return Button
function money:CreateButton(kind, parent, warbank)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(32, 13)
  if kind == "copper" then
    b:SetPoint("RIGHT", 0, 0)
  else
    b:SetPoint("RIGHT", parent, "LEFT", -4, 0)
  end
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetNormalAtlas("coin-" .. kind)
  b:GetNormalTexture():ClearAllPoints()
  b:GetNormalTexture():SetPoint("RIGHT", 0, 0)
  b:GetNormalTexture():SetSize(13, 13)
  local fs = b:CreateFontString(nil, "OVERLAY")
  b:SetFontString(fs)
  b:SetNormalFontObject("Number12Font")
  fs:SetPoint("RIGHT", -13, 0)
  b:SetScript("OnClick", function(_, button)
    if button == "LeftButton" then
      if warbank then
        StaticPopup_Show("BANK_MONEY_WITHDRAW", nil, nil, {bankType = Enum.BankType.Account})
      else
        StaticPopup_Show("PICKUP_MONEY")
      end
    elseif button == "RightButton" then
      if warbank then
        StaticPopup_Show("BANK_MONEY_DEPOSIT", nil, nil, {bankType = Enum.BankType.Account})
      end
    end
  end)
  b:Show()
  return b
end