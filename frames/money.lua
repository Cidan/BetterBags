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
---@field overlay Frame
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
  local name = addonName .. "MoneyFrame" .. (warbank and "Warbank" or "")
  local f = CreateFrame("Frame", name, UIParent)
  local overlay = CreateFrame("Frame", name.."overlay", f)
  m.frame = f
  m.overlay = overlay
  overlay:SetAllPoints()
  overlay:SetAlpha(0.5)
  overlay:EnableMouse(true)
  overlay:SetScript("OnMouseDown", function(_, button)
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

  overlay:SetScript("OnEnter", function()
    GameTooltip:SetOwner(overlay, "ANCHOR_TOP", 0, 5)
    if warbank then
      GameTooltip:AddDoubleLine("Left Click", "Withdraw money", 1, 0.81, 0, 1, 1, 1)
      GameTooltip:AddDoubleLine("Right Click", "Deposit money", 1, 0.81, 0, 1, 1, 1)
    else
      GameTooltip:AddDoubleLine("Left Click", "Pick up money", 1, 0.81, 0, 1, 1, 1)
    end
    GameTooltip:Show()
  end)

  overlay:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  local t = overlay:CreateTexture(nil, "HIGHLIGHT")
  t:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  t:SetBlendMode("ADD")
  t:SetAllPoints()

  m.frame:SetSize(128,18)
  m.copperButton = self:CreateButton("copper", m.frame)
  m.silverButton = self:CreateButton("silver", m.copperButton)
  m.goldButton = self:CreateButton("gold", m.silverButton)
  m.frame:Show()

  m:Update()
  events:RegisterEvent("PLAYER_MONEY", function()
    m:Update()
  end)
  return m
end


---@param kind string
---@param parent Frame
---@return Button
function money:CreateButton(kind, parent)
  local b = CreateFrame("Button", nil, parent)
  b:EnableMouse(false)
  b:SetSize(32, 13)
  if kind == "copper" then
    b:SetPoint("RIGHT", 0, 0)
  else
    b:SetPoint("RIGHT", parent, "LEFT", -4, 0)
  end
  b:SetNormalAtlas("coin-" .. kind)
  b:GetNormalTexture():ClearAllPoints()
  b:GetNormalTexture():SetPoint("RIGHT", 0, 0)
  b:GetNormalTexture():SetSize(13, 13)
  local fs = b:CreateFontString(nil, "OVERLAY")
  b:SetFontString(fs)
  b:SetNormalFontObject("Number12Font")
  fs:SetPoint("RIGHT", -13, 0)
  b:Show()
  return b
end