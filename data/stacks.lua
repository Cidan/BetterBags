local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Stacks: AceModule
local stacks = addon:NewModule('Stacks')

---@class StackInfo
---@field count number
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

    if not self.stacksByItemHash[itemHash] then
        self.stacksByItemHash[itemHash] = {count = 0, slotkeys = {}}
    end

    local stackinfo = self.stacksByItemHash[itemHash]

    if not stackinfo.slotkeys[slotkey] then
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
    if stackinfo and stackinfo.slotkeys[slotkey] then
        stackinfo.slotkeys[slotkey] = nil
        stackinfo.count = stackinfo.count - 1

        if next(stackinfo.slotkeys) == nil then
            self.stacksByItemHash[itemHash] = nil
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

--- Gets all slotkeys for an item
---@param itemHash string
---@return table<string, boolean>
function stack:GetSlotKeys(itemHash)
    local stackinfo = self.stacksByItemHash[itemHash]
    return stackinfo and stackinfo.slotkeys or {}
end

--- Clears all stack information
function stack:Clear()
    wipe(self.stacksByItemHash)
end
