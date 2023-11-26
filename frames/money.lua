local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class MoneyFrame: AceModule
local money = addon:NewModule('MoneyFrame')

---@class Money
---@field frame Button
local moneyProto = {}

---@return Money
function money:Create()
  ---@type Money
  local m = setmetatable({}, { __index = moneyProto })

  local f = CreateFrame("Button",  addonName .. "MoneyFrame", UIParent, "SmallMoneyFrameTemplate") --[[@as Button]]
  m.frame = f
  m.frame:SetHeight(13)
  return m
end