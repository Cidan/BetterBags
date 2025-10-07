local bb = GetBetterBags()
local moonlight = GetMoonlight()

--- Describe in a comment what this module does. Note the lower case starting letter -- this denotes a module package accessor.
---@class stack
---@field pool Pool
---@field backpackHashToStack table<string, Stack>
---@field backpackSlotKeyToStack table<string, Stack>
---@field bankHashToStack table<string, Stack>
---@field bankSlotKeyToStack table<string, Stack>
local stack = bb:NewClass("stack")

--- This is the instance of a module, and where the module
--- functionality actually is. Note the upper case starting letter -- this denotes a module instance.
--- Make sure to define all instance variables here. Private variables start with a lower case, public variables start with an upper case. 
---@class Stack
---@field itemHash string
---@field sortedSlotKeys string[]
local Stack = {}

---@return Stack
local stackConstructor = function()
  local instance = {
    sortedSlotKeys = {}
    -- Define your instance variables here
  }
  return setmetatable(instance, {
    __index = Stack
  })
end

---@param w Stack
local stackDeconstructor = function(w)
  -- Remove from both table sets (only one will have it)
  if stack.backpackHashToStack ~= nil then
    stack.backpackHashToStack[w.itemHash] = nil
  end
  if stack.bankHashToStack ~= nil then
    stack.bankHashToStack[w.itemHash] = nil
  end
  wipe(w.sortedSlotKeys)
  w.itemHash = nil
end

--- Helper to determine if a bagID is a bank bag
---@param bagID number
---@return boolean
local function isBankBag(bagID)
  local const = moonlight:GetConst()
  return const.BANK_BAGS[bagID] ~= nil or const.ACCOUNT_BANK_BAGS[bagID] ~= nil
end

--- Helper to get the correct hash table based on slotKey
---@param slotKey string
---@return table<string, Stack>
local function getHashTableForSlotKey(slotKey)
  local util = moonlight:GetUtil()
  local bagID, _ = util:GetBagAndSlotFromSlotkey(slotKey)
  if isBankBag(bagID) then
    if stack.bankHashToStack == nil then
      stack.bankHashToStack = {}
    end
    return stack.bankHashToStack
  else
    if stack.backpackHashToStack == nil then
      stack.backpackHashToStack = {}
    end
    return stack.backpackHashToStack
  end
end

--- Helper to get the correct slotKey table based on slotKey
---@param slotKey string
---@return table<string, Stack>
local function getSlotKeyTableForSlotKey(slotKey)
  local util = moonlight:GetUtil()
  local bagID, _ = util:GetBagAndSlotFromSlotkey(slotKey)
  if isBankBag(bagID) then
    if stack.bankSlotKeyToStack == nil then
      stack.bankSlotKeyToStack = {}
    end
    return stack.bankSlotKeyToStack
  else
    if stack.backpackSlotKeyToStack == nil then
      stack.backpackSlotKeyToStack = {}
    end
    return stack.backpackSlotKeyToStack
  end
end

--- This creates a new instance of a module, and optionally, initializes the module.
---@return Stack
function stack:new()
  if self.pool == nil then
    self.pool = moonlight:GetPool():New(stackConstructor, stackDeconstructor)
  end

  return self.pool:TakeOne("Stack")
end

function Stack:Release()
  stack.pool:GiveBack("Stack", self)
end

---@param data ItemData?
---@return Stack?
function stack:GetStack(data)
  if data == nil or data.ItemHash == nil or data.SlotKey == nil then
    return nil
  end

  local hashTable = getHashTableForSlotKey(data.SlotKey)
  if hashTable == nil then
    return nil
  end

  local st = hashTable[data.ItemHash]
  if st == nil then
    return nil
  end

  return st
end

function stack:SortAllStacks()
  -- Sort backpack stacks
  if self.backpackSlotKeyToStack ~= nil then
    for _, st in pairs(self.backpackSlotKeyToStack) do
      st:Sort()
    end
  end

  -- Only sort bank stacks if bank is open
  if self.bankSlotKeyToStack ~= nil then
    local bank = bb:GetBank():GetBank()
    if bank.window:IsVisible() then
      for _, st in pairs(self.bankSlotKeyToStack) do
        st:Sort()
      end
    end
  end
end

---@param data ItemData?
function stack:UpdateStack(data)
  if data == nil then
    error("attempted to update nil item data")
  end

  local hashTable = getHashTableForSlotKey(data.SlotKey)
  local slotKeyTable = getSlotKeyTableForSlotKey(data.SlotKey)

  -- If the slot is now empty, find the previous stack and remove the item.
  if data.Empty == true then
    local previousStack = slotKeyTable[data.SlotKey]
    if previousStack ~= nil then
      previousStack:RemoveItem(data)
    end
    return
  end

  -- There is an item in the slot.
  local st = hashTable[data.ItemHash]
  local previousStack = slotKeyTable[data.SlotKey]

  -- If there was a different item here before, remove it from its old stack.
  if previousStack ~= nil and previousStack ~= st then
    previousStack:RemoveItem(data)
  end

  -- If this is the first time we've seen this item type, create a new stack for it.
  if st == nil then
    st = stack:new()
  end

  -- If the item isn't already in the correct stack, add it.
  if st:HasItem(data) == false then
    st:InsertItem(data)
  end
end

---@param data ItemData
---@return boolean
function Stack:HasItem(data)
  if data == nil then
    return false
  end
  local slotKeyTable = getSlotKeyTableForSlotKey(data.SlotKey)
  if slotKeyTable[data.SlotKey] == self then
    return true
  end
  return false
end

---@param data ItemData
function Stack:InsertItem(data)
  local hashTable = getHashTableForSlotKey(data.SlotKey)
  local slotKeyTable = getSlotKeyTableForSlotKey(data.SlotKey)

  if slotKeyTable[data.SlotKey] ~= nil then
    error("attempted to add an item to a stack when it's already in a stack")
  end

  if self.itemHash ~= nil and data.ItemHash ~= self.itemHash then
    error("attempted to add an item to a stack that does not have the same hash")
  end

  self.itemHash = data.ItemHash
  slotKeyTable[data.SlotKey] = self
  hashTable[data.ItemHash] = self
  table.insert(self.sortedSlotKeys, data.SlotKey)
end

function Stack:Sort()
  local loader = moonlight:GetLoader()

  table.sort(self.sortedSlotKeys, function(a, b)
    local aMix = loader:GetItemMixinFromSlotKey(a)
    local bMix = loader:GetItemMixinFromSlotKey(b)
    if aMix == nil or bMix == nil then
      error("slotkey has no item mixin, which should not be possible. huge bug :)")
    end

    local aStack = C_Item.GetStackCount(aMix:GetItemLocation())
    local bStack = C_Item.GetStackCount(bMix:GetItemLocation())
    return aStack < bStack
  end)
end

---@return number
function Stack:GetItemCount()
  return #self.sortedSlotKeys
end

---@param data ItemData
---@return boolean
function Stack:IsThisDataTheHeadItem(data)
  if self:GetItemCount() == 0 then
    error("empty stack when attemping to find stack head")
  end

  if self.sortedSlotKeys[1] == data.SlotKey then
    return true
  end

  return false
end

---@param data ItemData
function Stack:RemoveItem(data)
  local slotKeyTable = getSlotKeyTableForSlotKey(data.SlotKey)

  for idx, slotKey in ipairs(self.sortedSlotKeys) do
    if data.SlotKey == slotKey then
      slotKeyTable[slotKey] = nil
      table.remove(self.sortedSlotKeys, idx)
      if self:GetItemCount() == 0 then
        self:Release()
      end
      return
    end
  end
  error("attempted to remove an item from a stack, but the item was not found in the stack")
end

---@return number
function Stack:GetTotalStackCount()
  local loader = moonlight:GetLoader()
  ---@type number
  local totalCount = 0
  for _, slotKey in ipairs(self.sortedSlotKeys) do
    local mixin = loader:GetItemMixinFromSlotKey(slotKey)
    if mixin ~= nil then
      local stackCount = C_Item.GetStackCount(mixin:GetItemLocation())
      totalCount = totalCount + stackCount
    end
  end
  return totalCount
end

---@return string[]
function Stack:GetAllItems()
  return self.sortedSlotKeys
end