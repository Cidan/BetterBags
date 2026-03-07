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

---@return Stack
function stacks:Create()
  local newState = setmetatable({}, {__index = stack})
  newState.stacksByItemHash = {}
  return newState
end

---@param item ItemData
function stack:AddToStack(item)
  if item.isItemEmpty then
    return
  end

  local hash = item.itemHash
  local stackinfo = self.stacksByItemHash[hash]

  if not stackinfo then
    self.stacksByItemHash[hash] = {count = 1, rootItem = item.slotkey, slotkeys = {}}
    return
  end

  ---@class Items: AceModule
  local items = addon:GetModule('Items')
  local rootItemData = items:GetItemDataFromSlotKey(stackinfo.rootItem)

  stackinfo.slotkeys[item.slotkey] = true
  stackinfo.count = stackinfo.count + 1

  if not rootItemData or rootItemData.isItemEmpty or
     ((item.itemInfo.currentItemCount > rootItemData.itemInfo.currentItemCount) or
      (item.itemInfo.currentItemCount == rootItemData.itemInfo.currentItemCount and item.slotkey > stackinfo.rootItem)) then
    stackinfo.slotkeys[stackinfo.rootItem] = true
    stackinfo.slotkeys[item.slotkey] = nil
    stackinfo.rootItem = item.slotkey
  end
end

---@param item ItemData
function stack:RemoveFromStack(item)
  local stackinfo = self.stacksByItemHash[item.itemHash]
  if not stackinfo then return end

  ---@class Items: AceModule
  local items = addon:GetModule('Items')

  if stackinfo.rootItem == item.slotkey then
    local bestChildSlotkey = nil
    local bestChildData = nil

    for slotkey in pairs(stackinfo.slotkeys) do
      local childData = items:GetItemDataFromSlotKey(slotkey)
      if childData and not childData.isItemEmpty then
        if not bestChildData then
          bestChildSlotkey = slotkey
          bestChildData = childData
        else
          if (childData.itemInfo.currentItemCount > bestChildData.itemInfo.currentItemCount) or
             (childData.itemInfo.currentItemCount == bestChildData.itemInfo.currentItemCount and slotkey > bestChildSlotkey) then
            bestChildSlotkey = slotkey
            bestChildData = childData
          end
        end
      end
    end

    if bestChildSlotkey then
      stackinfo.rootItem = bestChildSlotkey
      stackinfo.slotkeys[bestChildSlotkey] = nil
      stackinfo.count = stackinfo.count - 1
    else
      self.stacksByItemHash[item.itemHash] = nil
    end
  elseif stackinfo.slotkeys[item.slotkey] then
    stackinfo.slotkeys[item.slotkey] = nil
    stackinfo.count = stackinfo.count - 1
  end
end

---@param itemHash string
---@return number
function stack:GetTotalCount(itemHash)
  local stackinfo = self.stacksByItemHash[itemHash]
  return stackinfo and stackinfo.count or 0
end

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
  return stackinfo.slotkeys[slotkey] or false
end

---@param itemHash string
---@param slotkey string
---@return boolean
function stack:IsRootItem(itemHash, slotkey)
  local stackinfo = self.stacksByItemHash[itemHash]
  if not stackinfo then return false end
  return stackinfo.rootItem == slotkey
end

function stack:Clear()
  wipe(self.stacksByItemHash)
end
