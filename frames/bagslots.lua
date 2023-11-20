local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- Create the bagslot module.
---@class BagSlots: AceModule
local BagSlots = addon:NewModule('BagSlots')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class bagSlot
---@field frame Frame
local bagSlotProto = {}

local bagButtonProto = {}

---@return bagSlot
function BagSlots:CreatePanel(kind)
  ---@class bagSlot
  local b = {}
  setmetatable(b, {__index = bagSlotProto})
  local name = kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"
  local f = CreateFrame("Frame", name .. "BagSlots", "BackdropTemplate")
  b.frame = f
  return b
end