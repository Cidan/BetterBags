local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Items: AceModule
local items = addon:NewModule('Items')

---@class Item A single item a player can interact with.
local itemProto = {}

-- Create will create a new item and return it.
---@return Item
function items:Create()
  ---@class Item
  local item = setmetatable({}, { __index = itemProto })
  return item
end

function items:OnEnable()
  --TODO(lobato): Load all items from the inventory. 
end