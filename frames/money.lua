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
money.moneyProto = {}

function money.moneyProto:Update()
  local currentMoney = GetMoney()
  local gold = floor(currentMoney / 1e4)
  local silver = floor(currentMoney / 100 % 100)
  local copper = currentMoney % 100
  self.goldButton:SetText(tostring(gold))
  self.silverButton:SetText(tostring(silver))
  self.copperButton:SetText(tostring(copper))
  self.copperButton:SetWidth(self.copperButton:GetTextWidth() + 13)
  self.silverButton:SetWidth(self.silverButton:GetTextWidth() + 13)
end

---@return Money
function money:Create()
  ---@type Money
  local m = setmetatable({}, { __index = money.moneyProto })

  local f = CreateFrame("Frame", addonName .. "MoneyFrame", UIParent)
  m.frame = f
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

function money:CreateButton(kind, parent)
  local b = CreateFrame("Button", nil, parent)
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
  b:SetScript("OnClick", function()
    StaticPopup_Show("PICKUP_MONEY")
  end)
  b:Show()
  return b
end