


local addon = GetBetterBags()

---@class SectionFrame: AceModule
local sectionFrame = addon:GetModule('SectionFrame')

local const = addon:GetConstants()
---@class Database: AceModule
local database = addon:GetModule('Database')

---@class ItemFrame: AceModule
local itemFrame = addon:GetModule('ItemFrame')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

local debug = addon:GetDebug()

---@class Views: AceModule
local views = addon:NewModule('Views')

---@class (exact) Stack
---@field item string The slotkey of the item that is rendered.
---@field swap string The slotkey of the item to swap with when marked dirty.
---@field subItems table<string, boolean> All the sub items in this stack that are not rendered.
---@field hash string The item hash for this stack.
---@field dirty boolean If the stack needs to be updated.
local stackProto = {}

---@class (exact) View
---@field sections table<string, Section>
---@field slotToSection table<string, Section>
---@field content Grid
---@field bagview BagView
---@field kind BagKind
---@field itemsByBagAndSlot table<string, Item>
---@field freeSlot Item
---@field freeReagentSlot Item
---@field defer boolean
---@field itemCount number
---@field itemFrames Item[]
---@field deferredItems table<string, boolean>
---@field dirtySections table<string, boolean>
---@field private stacks table<string, Stack>
---@field WipeHandler fun(view: View, ctx: Context)
views.viewProto = {}

function views:OnEnable()
end

---@param ctx Context
---@param bag Bag
---@param slotInfo SlotInfo
---@param callback fun()
function views.viewProto:Render(ctx, bag, slotInfo, callback)
  _ = ctx
  _ = bag
  _ = slotInfo
  _ = callback
  error('Render method not implemented')
end

---@param oldSlotKey string
---@param newSlotKey? string
function views.viewProto:ReindexSlot(oldSlotKey, newSlotKey)
  _ = oldSlotKey
  _ = newSlotKey
  error('ReindexSlot method not implemented')
end

---@param newSlotKey string
function views.viewProto:AddSlot(newSlotKey)
  _ = newSlotKey
  error('AddSlot method not implemented')
end

---@param ctx Context
function views.viewProto:Wipe(ctx)
  assert(self.WipeHandler, 'WipeHandler not set')
  self.WipeHandler(self, ctx)
  self:ClearDeferredItems()
  self:ClearDirtySections()
  wipe(self.stacks)
  wipe(self.slotToSection)
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
---@param ctx Context
---@param slotkey string
---@param createFunc? fun(): Item|ItemRow
---@return Item
function views.viewProto:GetOrCreateItemButton(ctx, slotkey, createFunc)
  local item = self.itemsByBagAndSlot[slotkey]
  if item == nil then
    item = self:GetItemFrame(ctx, createFunc)
    self.itemsByBagAndSlot[slotkey] = item
  end
  return item
end

-- GetOrCreateSection will get an existing section by category,
-- creating it if it doesn't exist.
---@param ctx Context
---@param category string
---@param onlyCreate? boolean If true, only create the section, but don't add it to the view.
---@return Section
function views.viewProto:GetOrCreateSection(ctx, category, onlyCreate)
  local section = self.sections[category]
  if section == nil then
    section = sectionFrame:Create(ctx)
    section.frame:SetParent(self.content:GetScrollView())
    section:SetTitle(category)
    if not onlyCreate then
      self.content:AddCell(category, section)
    end
    self.sections[category] = section
    if self.bagview == const.BAG_VIEW.SECTION_GRID then
      categories:CreateCategory(ctx, {
        name = category,
        itemList = {},
        dynamic = true,
      })
    end
  elseif self.content:GetCell(category) == nil and not onlyCreate then
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

---@param section string
---@return Cell?
function views.viewProto:RemoveSectionFromGrid(section)
  local cell = self.content:RemoveCell(section)
  if cell then
    return cell
  end
  cell = self.sections[section] --[[@as Cell?]]
  return cell
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

---@param ctx Context
---@param createFunc? fun(): Item
---@return Item
function views.viewProto:GetItemFrame(ctx, createFunc)
  self.itemFrames = self.itemFrames or {}
  local i = createFunc and createFunc() or itemFrame:Create(ctx)
  tinsert(self.itemFrames, i)
  return i
end

---@param ctx Context
function views.viewProto:ReleaseItemFrames(ctx)
  for _, item in pairs(self.itemFrames) do
    item:Release(ctx)
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
---@param section Section
function views.viewProto:SetSlotSection(slotkey, section)
  self.slotToSection[slotkey] = section
end

---@param slotkey string
---@return Section
function views.viewProto:GetSlotSection(slotkey)
  return self.slotToSection[slotkey]
end

---@param slotkey string
function views.viewProto:RemoveSlotSection(slotkey)
  self.slotToSection[slotkey] = nil
end

---@param title string
function views.viewProto:AddDirtySection(title)
  if not title then return end
  self.dirtySections[title] = true
end

function views.viewProto:ClearDirtySections()
  wipe(self.dirtySections)
end

---@return table<string, boolean>
function views.viewProto:GetDirtySections()
  return self.dirtySections
end

---@param slotkey string
function views.viewProto:AddDeferredItem(slotkey)
  self.deferredItems[slotkey] = true
end

---@return table<string, boolean>
function views.viewProto:GetDeferredItems()
  return self.deferredItems
end

function views.viewProto:ClearDeferredItems()
  wipe(self.deferredItems)
end

function views.viewProto:RemoveDeferredItem(slotkey)
  self.deferredItems[slotkey] = nil
end

---@param bag Bag
function views.viewProto:UpdateListSize(bag)
  _ = bag
end

---@param ctx Context
---@param slotkey string
function views.viewProto:FlashStack(ctx, slotkey)
  -- HACKFIX: Disable this for non retail clients due to
  -- a lack of stable sort API.
  if not addon.isRetail then return end

  local item = items:GetItemDataFromSlotKey(slotkey)
  local stack = self.stacks[item.itemHash]
  if not stack then return end
  items:ClearNewItem(ctx, slotkey)
  items:ClearNewItem(ctx, stack.item)
  for subItemSlotKey in pairs(stack.subItems) do
    items:ClearNewItem(ctx, subItemSlotKey)
    if self.itemsByBagAndSlot[subItemSlotKey] then
      self.itemsByBagAndSlot[subItemSlotKey]:ClearFlashItem(ctx)
    end
  end
  local itemButton = self:GetOrCreateItemButton(ctx, slotkey)
  itemButton:FlashItem(ctx)
end


---@return View
function views:NewBlankView()
  local view = setmetatable({
    sections = {},
    itemsByBagAndSlot = {},
    deferredItems = {},
    stacks = {},
    slotToSection = {},
    dirtySections = {},
  }, {__index = views.viewProto}) --[[@as View]]
  return view
end

---@param slotkey string
---@return Stack
function views:NewStack(slotkey)
  local data = items:GetItemDataFromSlotKey(slotkey)
  return setmetatable({
    item = slotkey,
    subItems = {},
    hash = data.itemHash,
    dirty = false
  }, {__index = stackProto})
end

-- AddItem adds an item to the stack. If the stack has no main item, the item is added as the main item.
-- If the stack already has a main item, the item is added as a sub item.
-- Returns true if the item was added as the main item, false if it was added as a sub item.
---@param slotkey string
---@return boolean
function stackProto:AddItem(slotkey)
  if self.item == nil then
    self.item = slotkey
    return true
  end
  self.subItems[slotkey] = true
  return false
end

-- RemoveItem removes an item from the stack. If the item was the main item,
-- the first sub item is promoted to the main item. If the item was a sub item,
-- it is removed from the stack. Returns the slotkey of the main item, or nil if the
-- stack is now empty.
---@param slotkey string
---@return string?
function stackProto:RemoveItem(slotkey)
  if self.item == slotkey then
    self.item = nil
    local nextkey = next(self.subItems)
    if nextkey then
      self.item = nextkey
      self.subItems[nextkey] = nil
      self:UpdateCount()
      return nextkey
    end
    return nil
  end

  assert(self.subItems[slotkey], "Slotkey not found in stack" .. slotkey)

  self.subItems[slotkey] = nil
  self:UpdateCount()
  return self.item
end

function stackProto:UpdateCount()
  if not self.item then return end
  local itemData = items:GetItemDataFromSlotKey(self.item)
  if itemData.isItemEmpty then return end
  itemData.stackedCount = itemData.itemInfo.currentItemCount
  for subItemSlotKey in pairs(self.subItems) do
    local subItemData = items:GetItemDataFromSlotKey(subItemSlotKey)
    if not subItemData.isItemEmpty then
      itemData.stackedCount = itemData.stackedCount + subItemData.itemInfo.currentItemCount
    end
  end
end

---@return number
function stackProto:GetStackCount()
  if not self.item then return 0 end
  local itemData = items:GetItemDataFromSlotKey(self.item)
  return itemData.stackedCount
end

function stackProto:HasSubItem(slotkey)
  return self.subItems[slotkey] ~= nil
end

function stackProto:HasAnySubItems()
  return next(self.subItems) ~= nil
end

function stackProto:IsInStack(slotkey)
  return self.item == slotkey or self.subItems[slotkey] ~= nil
end

---@return ItemData
function stackProto:GetBackingItemData()
  return items:GetItemDataFromSlotKey(self.item)
end

function stackProto:IsStackEmpty()
  return self.item == nil and next(self.subItems) == nil
end
