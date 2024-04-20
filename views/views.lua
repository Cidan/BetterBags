local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SectionFrame: AceModule
local sectionFrame = addon:GetModule('SectionFrame')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class ItemFrame: AceModule
local itemFrame = addon:GetModule('ItemFrame')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Views: AceModule
local views = addon:NewModule('Views')

---@class (exact) Stack
---@field item string
---@field subItems table<string, boolean>
local stackProto = {}

---@class (exact) View
---@field sections table<string, Section>
---@field content Grid
---@field bagview BagView
---@field kind BagKind
---@field itemsByBagAndSlot table<string, Item>
---@field freeSlot Item
---@field freeReagentSlot Item
---@field defer boolean
---@field itemCount number
---@field itemFrames Item[]
---@field fullRefresh boolean
---@field deferredItems string[]
---@field private stacks table<string, Stack>
---@field private slotToStackHash table<string, string>
---@field WipeHandler fun(view: View)
views.viewProto = {}

---@param bag Bag
---@param slotInfo SlotInfo
function views.viewProto:Render(bag, slotInfo)
  _ = bag
  _ = slotInfo
  error('Render method not implemented')
end

function views.viewProto:Wipe()
  assert(self.WipeHandler, 'WipeHandler not set')
  self.WipeHandler(self)
  self:ClearDeferredItems()
  wipe(self.stacks)
  wipe(self.slotToStackHash)
end

function views.viewProto:WipeStacks()
  wipe(self.stacks)
end

---@return BagView
function views.viewProto:GetBagView()
  return self.bagview
end

---@return Grid
function views.viewProto:GetContent()
  return self.content
end

-- GetOrCreateItemButton will get an existing item button by slotkey,
-- creating it if it doesn't exist.
---@param slotkey string
---@return Item
function views.viewProto:GetOrCreateItemButton(slotkey)
  local item = self.itemsByBagAndSlot[slotkey]
  if item == nil then
    item = self:GetItemFrame()
    self.itemsByBagAndSlot[slotkey] = item
  end
  return item
end

-- GetOrCreateSection will get an existing section by category,
-- creating it if it doesn't exist.
---@param category string
---@return Section
function views.viewProto:GetOrCreateSection(category)
  local section = self.sections[category]
  if section == nil then
    section = sectionFrame:Create()
    section.frame:SetParent(self.content:GetScrollView())
    section:SetTitle(category)
    self.content:AddCell(category, section)
    self.sections[category] = section
  elseif self.content:GetCell(category) == nil then
    self.content:AddCell(category, section)
  end
  return section
end

function views.viewProto:GetSection(category)
  return self.sections[category]
end

---@param category string
function views.viewProto:RemoveSection(category)
  self.content:RemoveCell(category)
  self.sections[category] = nil
end

---@return table<string, Section>
function views.viewProto:GetAllSections()
  return self.sections
end

---@return table<string, Item>
function views.viewProto:GetItemsByBagAndSlot()
  return self.itemsByBagAndSlot
end

---@param data ItemData
---@return string
function views.viewProto:GetSlotKey(data)
  return data.bagid .. '_' .. data.slotid
end

---@param slotkey string
---@return number, number
function views.viewProto:ParseSlotKey(slotkey)
  ---@type string, string
  local bagid, slotid = strsplit('_', slotkey)
  return tonumber(bagid) --[[@as number]], tonumber(slotid) --[[@as number]]
end

---@return Item
function views.viewProto:GetItemFrame()
  self.itemFrames = self.itemFrames or {}
  local i = itemFrame:Create()
  tinsert(self.itemFrames, i)
  return i
end

function views.viewProto:ReleaseItemFrames()
  for _, item in pairs(self.itemFrames) do
    item:Release()
  end
  wipe(self.itemFrames)
end

function views.viewProto:SetPoints()
  local parent = self:GetContent():GetContainer():GetParent()
  self.content:GetContainer():ClearAllPoints()
  self.content:GetContainer():SetPoint("TOPLEFT", parent, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET, const.OFFSETS.BAG_TOP_INSET)
  self.content:GetContainer():SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", const.OFFSETS.BAG_RIGHT_INSET, const.OFFSETS.BAG_BOTTOM_INSET + const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET + 20)
end

---@param slotkey string
function views.viewProto:AddDeferredItem(slotkey)
  tinsert(self.deferredItems, slotkey)
end

---@return string[]
function views.viewProto:GetDeferredItems()
  return self.deferredItems
end

function views.viewProto:ClearDeferredItems()
  wipe(self.deferredItems)
end

---@param bag Bag
function views.viewProto:UpdateListSize(bag)
  _ = bag
end

function views.viewProto:StackRemove(slotkey)
  return false
end

---@param item ItemData
---@return Item?
function views.viewProto:NewButton(item)
  local opts = database:GetStackingOptions(self.kind)
  -- If we're not merging stacks, return nil.
  if not opts.mergeStacks or
  opts.unmergeAtShop and addon.atInteracting or
  opts.dontMergePartial and item.itemInfo.currentItemCount < item.itemInfo.itemStackCount then
    local itemButton = self:GetOrCreateItemButton(item.slotkey)
    itemButton:SetItem(item.slotkey)
    return itemButton
  end

  local stack = self.stacks[item.itemHash]

  -- If a stack was found, update it and return the stack button.
  if stack then
    local itemButton = self:GetOrCreateItemButton(stack.item)
    stack:AddItem(item.slotkey)
    stack:UpdateCount()
    itemButton:UpdateCount()
    debug:Log("Stacked", "Stacking", item.itemInfo.itemLink, item.slotkey, "->", stack.item)
    return nil
  end

  -- No stack was found, create a new stack.
  local itemButton = self:GetOrCreateItemButton(item.slotkey)
  self.stacks[item.itemHash] = setmetatable({
    item = item.slotkey,
    subItems = {}
  }, {__index = stackProto})
  self.slotToStackHash[item.slotkey] = item.itemHash
  itemButton:SetItem(item.slotkey)

  return itemButton
end

---@param item ItemData
---@return boolean
function views.viewProto:ChangeButton(item)
  --[[
    if the item is part of the stack but not the stack item itself, update the count.
    if the item is the stack item, update the count and the item.
    if the item is not part of the stack, return false.
  ]]--
  --local stack = self.stacks[item.itemHash]
  local stack = self.stacks[item.itemHash]

  -- If there's no stack, just update the item.
  if stack == nil then
    local itemButton = self:GetOrCreateItemButton(item.slotkey)
    itemButton:SetItem(item.slotkey)
    return true
  end

  if stack and stack.item == item.slotkey then
    stack:UpdateCount()
    local itemButton = self:GetOrCreateItemButton(stack.item)
    itemButton:SetItem(stack.item)
  end
  -- This item no longer belongs to the stack it was in.
  --if self.slotToStackHash[item.slotkey] ~= item.itemHash then
  --  local stack = self.stacks[self.slotToStackHash[item.slotkey]]
  --  if stack.item.slotkey == item.slotkey then
  --    stack:Promote()
  --  else
  --    stack:RemoveItem(item)
  --  end
  --  stack:UpdateCount()
  --  itemButton:UpdateCount()
  --end
--
  --local stack = self.stacks[item.itemHash]
  --[[
  if stack and stack.subItems[item.slotkey] then
    debug:Log("Stacked", "Stack Count Change", item.itemInfo.itemLink, item.slotkey)
    stack:UpdateCount()
    return false
  end
  if stack and stack.item.slotkey == item.slotkey then
    debug:Log("Stacked", "Stack Count Change", item.itemInfo.itemLink, item.slotkey)
    stack:UpdateCount()
    return true
  end
  --]]
  --[[
  -- If the item is part of a stack, update the count.
  if stack and stack.subItems[item.slotkey] then
    stack.item.data.stackedCount = stack.item.data.itemInfo.currentItemCount
    for _, subItem in pairs(stack.subItems) do
      stack.item.data.stackedCount = stack.item.data.stackedCount + subItem.itemInfo.currentItemCount
    end
    return true
  elseif stack and stack.item.data.slotkey == item.slotkey then
    stack.item.data.stackedCount = item.itemInfo.currentItemCount
    stack.item:SetItem(item)
    return false
  end
  --]]
  return false
end

---@return View
function views:NewBlankView()
  local view = setmetatable({
    sections = {},
    itemsByBagAndSlot = {},
    deferredItems = {},
    stacks = {},
    slotToStackHash = {}
  }, {__index = views.viewProto}) --[[@as View]]
  return view
end

---@param slotkey string
function stackProto:AddItem(slotkey)
  self.subItems[slotkey] = true
end

---@param item ItemData
function stackProto:RemoveItem(item)
  self.subItems[item.slotkey] = nil
end

---@param slotkey string
function stackProto:RemoveItemBySlotKey(slotkey)
  self.subItems[slotkey] = nil
end

function stackProto:Promote()
  local slotkey = next(self.subItems)
  if slotkey then
    self.item = slotkey
    self.subItems[slotkey] = nil
  else
    self.item = nil
  end
end

function stackProto:UpdateCount()
  if not self.item then return end
  local itemData = items:GetItemDataFromSlotKey(self.item)
  itemData.stackedCount = itemData.itemInfo.currentItemCount
  for subItemSlotKey in pairs(self.subItems) do
    local subItemData = items:GetItemDataFromSlotKey(subItemSlotKey)
    itemData.stackedCount = itemData.stackedCount + subItemData.itemInfo.currentItemCount
  end
end

---@return ItemData
function stackProto:GetBackingItemData()
  return items:GetItemDataFromSlotKey(self.item)
end
