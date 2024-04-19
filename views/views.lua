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

---@class Views: AceModule
local views = addon:NewModule('Views')

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
---@field private stacks table<string, Item>
views.viewProto = {}

---@param bag Bag
---@param slotInfo SlotInfo
function views.viewProto:Render(bag, slotInfo)
  _ = bag
  _ = slotInfo
  error('Render method not implemented')
end

function views.viewProto:Wipe()
  error('Wipe method not implemented')
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
function views.viewProto:StackAdd(item)
  local opts = database:GetStackingOptions(self.kind)
  -- If we're not merging stacks, return nil.
  if not opts.mergeStacks then return nil end

  -- If we're not merging at the shop and we're at the shop, return nil.
  if opts.unmergeAtShop and addon.atInteracting then return nil end

  -- If we're not merging partial stacks and this is a partial stack, return nil.
  if opts.dontMergePartial and item.itemInfo.currentItemCount < item.itemInfo.itemStackCount then return nil end

  local itemButton = self.stacks[item.itemHash]

  -- If a stack was found, update it and return the stack button.
  if itemButton then
    itemButton.data.stackedCount = itemButton.data.stackedCount + item.itemInfo.currentItemCount
    -- TODO: Track the stack in the item button.
    return itemButton
  end

  -- No stack was found, create a new stack.
  itemButton = self:GetOrCreateItemButton(item.slotkey)
  itemButton:SetItem(item)
  itemButton:UpdateCount()
  self.stacks[item.itemHash] = itemButton
  return itemButton
end

function views.viewProto:StackChange(slotkey)
  return false
end

---@return View
function views:NewBlankView()
  local view = setmetatable({
    sections = {},
    itemsByBagAndSlot = {},
    deferredItems = {},
    stacks = {}
  }, {__index = views.viewProto}) --[[@as View]]
  return view
end