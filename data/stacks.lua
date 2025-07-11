

---@type BetterBags
local addon = GetBetterBags()

---@class Stacks: AceModule
local stacks = addon:NewModule('Stacks')

---@class StackInfo
---@field count number
---@field rootItem string
---@field slotkeys table<string, boolean>

---@class Stack
---@field stacksByItemHash table<string, StackInfo>
local stack = {}

--- Creates a new stack
---@return Stack
function stacks:Create()
  local newState = setmetatable({}, {__index = stack})
  newState.stacksByItemHash = {}
  return newState
end

--- Initializes or updates stack information for an item
---@param item ItemData
function stack:AddToStack(item)
  if item.isItemEmpty then
    return
  end

  if not self.stacksByItemHash[item.itemHash] then
    self.stacksByItemHash[item.itemHash] = {count = 1, rootItem = item.slotkey, slotkeys = {}}
    return
  end

  -- JIT load here due to import loop.

  ---@class Items: AceModule
  local items = addon:GetModule('Items')

  local stackinfo = self.stacksByItemHash[item.itemHash]

  local rootItemData = items:GetItemDataFromSlotKey(stackinfo.rootItem)

  stackinfo.slotkeys[item.slotkey] = true
  stackinfo.count = stackinfo.count + 1

  -- Always ensure the lead item in the stack is the one with the most count.
  for slotkey in pairs(stackinfo.slotkeys) do
    local childData = items:GetItemDataFromSlotKey(slotkey)
    if rootItemData.isItemEmpty or
    (not childData.isItemEmpty and ((childData.itemInfo.currentItemCount > rootItemData.itemInfo.currentItemCount) or
    (childData.itemInfo.currentItemCount == rootItemData.itemInfo.currentItemCount and childData.slotkey > stackinfo.rootItem))) then
      stackinfo.slotkeys[stackinfo.rootItem] = true
      stackinfo.slotkeys[slotkey] = nil
      stackinfo.rootItem = slotkey
    end
  end
end

--- Removes an item from a stack
---@param item ItemData
function stack:RemoveFromStack(item)
  ---@class Items: AceModule
  local items = addon:GetModule('Items')

  local stackinfo = self.stacksByItemHash[item.itemHash]
  if not stackinfo then return end

  if stackinfo.rootItem == item.slotkey then
    if next(stackinfo.slotkeys) then
      stackinfo.rootItem = next(stackinfo.slotkeys)
      stackinfo.slotkeys[stackinfo.rootItem] = nil
      stackinfo.count = stackinfo.count - 1
    else
      self.stacksByItemHash[item.itemHash] = nil
    end
  elseif stackinfo.slotkeys[item.slotkey] then
    stackinfo.slotkeys[item.slotkey] = nil
    stackinfo.count = stackinfo.count - 1
  end
  local rootItemData = items:GetItemDataFromSlotKey(stackinfo.rootItem)
  -- Always ensure the lead item in the stack is the one with the most count.
  for slotkey in pairs(stackinfo.slotkeys) do
    local childData = items:GetItemDataFromSlotKey(slotkey)
    if rootItemData.isItemEmpty or
    (not childData.isItemEmpty and ((childData.itemInfo.currentItemCount > rootItemData.itemInfo.currentItemCount) or
    (childData.itemInfo.currentItemCount == rootItemData.itemInfo.currentItemCount and childData.slotkey > stackinfo.rootItem))) then
      stackinfo.slotkeys[stackinfo.rootItem] = true
      stackinfo.slotkeys[slotkey] = nil
      stackinfo.rootItem = slotkey
    end
  end
end

--- Gets the total count of an item across all stacks
---@param itemHash string
---@return number
function stack:GetTotalCount(itemHash)
  local stackinfo = self.stacksByItemHash[itemHash]
  return stackinfo and stackinfo.count or 0
end

--- Gets stack information for an item
---@param itemHash string
---@return StackInfo?
function stack:GetStackInfo(itemHash)
  return self.stacksByItemHash[itemHash]
end

---@param itemHash string
---@param slotkey string
---@return boolean
function stack:HasItem(itemHash, slotkey)
  local stackinfo = self.stacksByItemHash[itemHash]
  if not stackinfo then return false end
  if stackinfo.rootItem == slotkey then
    return true
  end
  return stackinfo.slotkeys[slotkey]
end

--- Checks if a slotkey is the root item of a stack
---@param itemHash string
---@param slotkey string
---@return boolean
function stack:IsRootItem(itemHash, slotkey)
  local stackinfo = self.stacksByItemHash[itemHash]
  if not stackinfo then return false end
  return stackinfo.rootItem == slotkey
end

--- Clears all stack information
function stack:Clear()
  wipe(self.stacksByItemHash)
end
