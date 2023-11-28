local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class ItemFrame: AceModule
local itemFrame = addon:GetModule('ItemFrame')

---@class Views: AceModule
local views = addon:GetModule('Views')

---@param bag Bag
---@param dirtyItems table<number, table<number, ItemMixin>>
function views:ListView(bag, dirtyItems)
  bag:WipeFreeSlots()
  for bid, bagData in pairs(dirtyItems) do
    bag.itemsByBagAndSlot[bid] = bag.itemsByBagAndSlot[bid] or {}
    for sid, itemData in pairs(bagData) do
      local bagid, slotid = itemData:GetItemLocation():GetBagAndSlot()
    end
  end
end