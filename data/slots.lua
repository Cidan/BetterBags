local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Items: AceModule
local items = addon:GetModule('Items')

-- SlotInfo contains refresh data for an entire bag view, bag or bank.
---@class (exact) SlotInfo
---@field emptySlots table<string, number> The number of empty normal slots across all bags.
---@field freeSlotKeys table<string, string> The keys of the first empty slot per bag type.
---@field totalItems number The total number of valid items across all bags.
---@field previousTotalItems number The total number of valid items across all bags from the previous refresh.
---@field emptySlotByBagAndSlot table<number, table<number, ItemData>> A table of empty slots by bag and slot.
---@field deferDelete? boolean If true, delete's should be deferred until the next refresh.
---@field dirtyItems ItemData[] A list of dirty items that need to be refreshed.
---@field itemsBySlotKey table<string, ItemData> A table of items by slot key.
---@field previousItemsBySlotKey table<string, ItemData> A table of items by slot key from the previous refresh.
---@field addedItems table<string, ItemData> A list of items that were added since the last refresh.
---@field removedItems table<string, ItemData> A list of items that were removed since the last refresh.
---@field updatedItems table<string, ItemData> A list of items that were updated since the last refresh.
local SlotInfo = {}

function items:NewSlotInfo()
  return setmetatable({
      emptySlots = {},
      freeSlotKeys = {},
      totalItems = 0,
      emptySlotByBagAndSlot = {},
      dirtyItems = {},
      itemsBySlotKey = {},
      previousItemsBySlotKey = {},
      addedItems = {},
      removedItems = {},
      updatedItems = {},
      deferDelete = false
    }, {__index = SlotInfo})
end

---@param bagid number
---@param slotid number
---@return ItemData
function SlotInfo:GetCurrentItemByBagAndSlot(bagid, slotid)
  return self.itemsBySlotKey[items:GetSlotKeyFromBagAndSlot(bagid, slotid)]
end

---@param bagid number
---@param slotid number
---@return ItemData
function SlotInfo:GetPreviousItemByBagAndSlot(bagid, slotid)
  return self.previousItemsBySlotKey[items:GetSlotKeyFromBagAndSlot(bagid, slotid)]
end

---@return table<string, ItemData>
function SlotInfo:GetCurrentItems()
  return self.itemsBySlotKey
end

---@return table<string, ItemData>
function SlotInfo:GetPreviousItems()
  return self.previousItemsBySlotKey
end

---@return ItemData[], ItemData[], ItemData[]
function SlotInfo:GetChangeset()
  return self.addedItems, self.removedItems, self.updatedItems
end

---@param newItems table<string, ItemData>
function SlotInfo:Update(newItems)
  self.previousItemsBySlotKey = self.itemsBySlotKey
  self.itemsBySlotKey = newItems
  self.previousTotalItems = self.totalItems
  self.totalItems = 0
  self.emptySlots = {}
  self.freeSlotKeys = {}
  self.addedItems = {}
  self.removedItems = {}
  self.updatedItems = {}
  self.emptySlotByBagAndSlot = {}
  self.dirtyItems = {}
  self.deferDelete = false
end

function SlotInfo:Wipe()
  self.emptySlots = {}
  self.freeSlotKeys = {}
  self.totalItems = 0
  self.previousTotalItems = 0
  self.emptySlotByBagAndSlot = {}
  self.dirtyItems = {}
  self.itemsBySlotKey = {}
  self.previousItemsBySlotKey = {}
  self.addedItems = {}
  self.removedItems = {}
  self.updatedItems = {}
  self.deferDelete = false
end
