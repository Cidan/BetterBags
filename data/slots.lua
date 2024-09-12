local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Stacks: AceModule
local stacks = addon:GetModule('Stacks')

---@class (exact) SwapSet
---@field a string
---@field b? string

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
---@field emptySlotsSorted ItemData[] A sorted list of empty slots by bag and then slot.
---@field stacks Stack A stack object to manage item stacks.
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
      emptySlotsSorted = {},
      deferDelete = false,
      stacks = stacks:Create()
    }, {__index = SlotInfo})
end

---@param bagid number
---@param slotid number
---@return ItemData
function SlotInfo:GetCurrentItemByBagAndSlot(bagid, slotid)
  return self.itemsBySlotKey[items:GetSlotKeyFromBagAndSlot(bagid, slotid)]
end

---@param item ItemData
function SlotInfo:AddToRemovedItems(item)
  if item and item.slotkey then
    self.removedItems[item.slotkey] = item
    self.stacks:RemoveFromStack(item)
  end
end

---@param item ItemData
function SlotInfo:AddToAddedItems(item)
  if item and item.slotkey then
    self.addedItems[item.slotkey] = item
    self.stacks:AddToStack(item)
  end
end

---@param oldItem ItemData
---@param newItem ItemData
function SlotInfo:AddToUpdatedItems(oldItem, newItem)
	if newItem and newItem.slotkey then
		self.updatedItems[newItem.slotkey] = newItem
		self.stacks:RemoveFromStack(oldItem)
		self.stacks:AddToStack(newItem)
	end
end

---@param name string
---@param item ItemData
function SlotInfo:StoreIfEmptySlot(name, item)
  if item.isItemEmpty then
    self.emptySlotByBagAndSlot[item.bagid] = self.emptySlotByBagAndSlot[item.bagid] or {}
    self.emptySlotByBagAndSlot[item.bagid][item.slotid] = item
    self.freeSlotKeys[name] = item.slotkey
    table.insert(self.emptySlotsSorted, item)
  end
end

function SlotInfo:SortEmptySlots()
  table.sort(self.emptySlotsSorted, function(a, b)
    if a.bagid == b.bagid then
      return a.slotid < b.slotid
    end
    return a.bagid < b.bagid
  end)
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
  local added = {}
  local removed = {}
  local updated = {}
  for _, item in pairs(self.addedItems) do
    table.insert(added, item)
  end
  for _, item in pairs(self.removedItems) do
    table.insert(removed, item)
  end
  for _, item in pairs(self.updatedItems) do
    table.insert(updated, item)
  end
  return added, removed, updated
end

---@param ctx Context
---@param newItems table<string, ItemData>
function SlotInfo:Update(ctx, newItems)
  if ctx:GetBool('wipe') then
    self:Wipe()
  end
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
  self.emptySlotsSorted = {}
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
  self.emptySlotsSorted = {}
  self.deferDelete = false
  self.stacks:Clear()
end
