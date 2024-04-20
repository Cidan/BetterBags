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
---@field dirty boolean
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
  self.stacks[item.itemHash] = views:NewStack(item.slotkey)
  self.slotToStackHash[item.slotkey] = item.itemHash
  itemButton:SetItem(item.slotkey)

  return itemButton
end

---@param item ItemData
---@return boolean
function views.viewProto:ChangeButton(item)
  local stack = self.stacks[item.itemHash]

  -- If there's no stack, just update the item.
  if stack == nil then
    local itemButton = self:GetOrCreateItemButton(item.slotkey)
    itemButton:SetItem(item.slotkey)
    return true
  end

  stack:MarkDirty()
  return false
end

function views.viewProto:ProcessStacks()
  for _, stack in pairs(self.stacks) do
    if stack.dirty then
      stack:Process(self)
    end
  end

end

---@param itemHash string
---@return Stack
function views.viewProto:GetStack(itemHash)
  return self.stacks[itemHash]
end

---@param slotkey string
---@param itemHash string
function views.viewProto:SetItemHashStack(slotkey, itemHash)
  self.slotToStackHash[slotkey] = itemHash
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
---@return Stack
function views:NewStack(slotkey)
  return setmetatable({
    item = slotkey,
    subItems = {},
    dirty = false
  }, {__index = stackProto})
end

---@param slotkey string
function stackProto:AddItem(slotkey)
  self.subItems[slotkey] = true
end

---@param slotkey string
function stackProto:RemoveItem(slotkey)
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

function stackProto:MarkDirty()
  self.dirty = true
end

---@param view View
function stackProto:Process(view)
  self.dirty = false

  local newStack = views:NewStack(self.item)
  ---@type Stack[]
  local stacksToUpdate = {}
  local myData = items:GetItemDataFromSlotKey(self.item)

  for subItemSlotKey in pairs(self.subItems) do
    local subitem = items:GetItemDataFromSlotKey(subItemSlotKey)
    local stack = view:GetStack(subitem.itemHash)
    if subitem.itemHash ~= myData.itemHash then
      debug:Log("StackUpdate", "Removing", subitem.itemInfo.itemLink, "from", myData.itemInfo.itemLink)
      --self:RemoveItem(subItemSlotKey)
      debug:Log("StackUpdate", "Adding", subitem.itemInfo.itemLink, "to", items:GetItemDataFromSlotKey(stack.item).itemInfo.itemLink)
      --stack:AddItem(subItemSlotKey)
      table.insert(stacksToUpdate, stack)
    end
  end

  for _, stack in ipairs(stacksToUpdate) do
    stack:UpdateCount()
    view:GetOrCreateItemButton(stack.item):SetItem(stack.item)
  end

  self:UpdateCount()
  view:GetOrCreateItemButton(self.item):SetItem(self.item)
  view:SetItemHashStack(self.item, myData.itemHash)
end