local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

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
  local itemHash = item.itemHash
  local slotkey = item.slotkey
  if item.isItemEmpty then
    return
  end

  if not self.stacksByItemHash[itemHash] then
    self.stacksByItemHash[itemHash] = {count = 1, rootItem = slotkey, slotkeys = {}}
    return
  end

  -- JIT load here due to import loop.

  ---@class Items: AceModule
  local items = addon:GetModule('Items')

  local stackinfo = self.stacksByItemHash[itemHash]

  local rootItemData = items:GetItemDataFromSlotKey(stackinfo.rootItem)

  -- Always ensure the lead item in the stack is the one with the most count.
  if item.itemInfo.currentItemCount > rootItemData.itemInfo.currentItemCount then
    stackinfo.slotkeys[stackinfo.rootItem] = true
    stackinfo.slotkeys[slotkey] = nil
    stackinfo.rootItem = slotkey
    stackinfo.count = stackinfo.count + 1
  elseif not stackinfo.slotkeys[slotkey] then
    stackinfo.slotkeys[slotkey] = true
    stackinfo.count = stackinfo.count + 1
  end
end

--- Removes an item from a stack
---@param item ItemData
function stack:RemoveFromStack(item)
  local itemHash = item.itemHash
  local slotkey = item.slotkey
  local stackinfo = self.stacksByItemHash[itemHash]
  if not stackinfo then return end

  if stackinfo.rootItem == slotkey then
    if next(stackinfo.slotkeys) then
      stackinfo.rootItem = next(stackinfo.slotkeys)
      stackinfo.slotkeys[stackinfo.rootItem] = nil
      stackinfo.count = stackinfo.count - 1
    else
      self.stacksByItemHash[itemHash] = nil
    end
  elseif stackinfo.slotkeys[slotkey] then
    stackinfo.slotkeys[slotkey] = nil
    stackinfo.count = stackinfo.count - 1
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
