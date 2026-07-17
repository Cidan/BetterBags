local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SectionFrame: AceModule
local sectionFrame = addon:GetModule('SectionFrame')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class ItemFrame: AceModule
local itemFrame = addon:GetModule('ItemFrame')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class Views: AceModule
local views = addon:NewModule('Views')

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
---@field WipeHandler fun(view: View, ctx: Context)
---@field isNew boolean
views.viewProto = {}

function views:OnEnable()
end

---@param ctx Context
---@param bag Bag
---@param slotInfo SlotInfo
---@param callback fun()
function views.viewProto:Render(ctx, bag, slotInfo, callback)
  local _ = ctx
  _ = bag
  _ = slotInfo
  _ = callback
  error('Render method not implemented')
end

---@param oldSlotKey string
---@param newSlotKey? string
function views.viewProto:ReindexSlot(oldSlotKey, newSlotKey)
  local _ = oldSlotKey
  _ = newSlotKey
  error('ReindexSlot method not implemented')
end

---@param newSlotKey string
function views.viewProto:AddSlot(newSlotKey)
  local _ = newSlotKey
  error('AddSlot method not implemented')
end

---@param ctx Context
function views.viewProto:Wipe(ctx)
  assert(self.WipeHandler, 'WipeHandler not set')
  self.WipeHandler(self, ctx)
  self:ClearDeferredItems()
  self:ClearDirtySections()
  wipe(self.slotToSection)
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
    if createFunc then
      item = self:GetItemFrame(ctx, createFunc)
    else
      item = itemFrame:GetButton(ctx, slotkey)
      self.itemFrames = self.itemFrames or {}
      tinsert(self.itemFrames, item)
    end
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
  -- Look up category color
  local filter = categories:GetCategoryByName(category)
  local color = filter and filter.color or nil

  if section == nil then
    section = sectionFrame:Create(ctx)
    section.frame:SetParent(self.content:GetScrollView())
    section:SetTitle(category, color)
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
  else
    -- Section already exists - update the color in case it changed
    section:SetTitle(category, color)
    if self.content:GetCell(category) == nil and not onlyCreate then
      self.content:AddCell(category, section)
    end
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


---@return View
function views:NewBlankView()
  local view = setmetatable({
    sections = {},
    itemsByBagAndSlot = {},
    deferredItems = {},
    slotToSection = {},
    dirtySections = {},
  }, {__index = views.viewProto}) --[[@as View]]
  return view
end
