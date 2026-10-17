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

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

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
---@field rendering boolean True between BeginRender and FinishRender.
---@field claims table<Item, boolean>|nil The current pass's claimed buttons (see frames/bag.lua Draw).
---@field staleSections table<string, Section>|nil Last pass's sections not drawn again yet.
---@field tabID number
---@field sortRequired boolean
---@field emptyGroupFrame? Frame The hint shown in an empty group tab.
views.viewProto = {}
addon:GetModule('Perf'):RegisterPrototype(views.viewProto, 'View')

function views:OnEnable()
end

---@class (exact) ViewLayout
---@field itemsPerRow number How many items a section puts in a row.
---@field columns number How many columns of sections the view lays out.

---@class (exact) ViewMeasure
---@field itemsPerRow number
---@field columns number
---@field sections table<Section, SectionMeasure>
---@field content GridMeasure Where the sections go.
---@field width number
---@field height number

---@alias SectionMeasurer fun(section: Section, itemsPerRow: number): SectionMeasure

-- Bind puts the tab's data into the view: a section per category in the data's order, and a
-- cell per item, gap and free slot, each item button drawn from its data. It ends the render
-- pass (releasing the sections it did not draw again). Bind lays nothing out: Layout does,
-- and can run again with other limits (a window being resized) without binding again.
---@param ctx Context
---@param bag Bag
---@param slotInfo SlotInfo
function views.viewProto:Bind(ctx, bag, slotInfo)
  local _ = bag
  self:BeginRender(ctx)
  self.isNew = false

  local tabData = slotInfo.tabs and slotInfo.tabs[self.tabID] or {
    items = {},
    categories = {},
  }

  for _, catData in ipairs(tabData.categories) do
    self:GetOrCreateSection(ctx, catData.name)
  end

  for _, item in ipairs(tabData.items) do
    local slotkey = item.slotkey
    local category = item.itemInfo and item.itemInfo.category or L:G("Everything")
    local section = self:GetOrCreateSection(ctx, category)
    if item.isItemGap then
      section:AddCell(slotkey, { isGap = true, width = 37, height = 37 })
    else
      local itemButton = self:GetOrCreateItemButton(ctx, slotkey)
      if item.isFreeSlot then
        itemButton:SetFreeSlots(ctx, item, -1)
      else
        itemButton:SetItemFromData(ctx, item)
      end
      section:AddCell(slotkey, itemButton)
    end
    self:SetSlotSection(slotkey, section)
  end

  for sectionName, section in pairs(self.sections) do
    local layout = slotInfo.sectionLayouts and slotInfo.sectionLayouts[sectionName]
    if layout and layout.hideHeader then
      section:RemoveHeader()
    end
  end

  if self.emptyGroupFrame then
    self.emptyGroupFrame:SetShown(self.tabID ~= nil and self.tabID > 1 and #tabData.categories == 0)
  end

  self.sortRequired = false
  self.itemCount = slotInfo.totalItems
  self:FinishRender(ctx)
end

-- Measure works out the layout of the bound sections, moving nothing (render-pipeline.md, the
-- layout engine): each section measured with itemsPerRow items in a row (by measureSection when
-- given: the canvas caches measures across the layouts it tries), and the sections packed in rows
-- of 41 * itemsPerRow + 16 within columns at their measured sizes.
---@param itemsPerRow number
---@param columns number
---@param measureSection? SectionMeasurer
---@return ViewMeasure
function views.viewProto:Measure(itemsPerRow, columns, measureSection)
  local sections = {}
  for _, section in pairs(self.sections) do
    if measureSection ~= nil then
      sections[section] = measureSection(section, itemsPerRow)
    else
      sections[section] = section:Measure(self.kind, itemsPerRow)
    end
  end
  local content = self.content:Measure({
    cells = self.content.cells,
    maxWidthPerRow = ((37 + 4) * itemsPerRow) + 16,
    columns = columns,
    sizeOf = function(cell)
      local measured = sections[cell]
      if measured ~= nil then
        return measured.width, measured.height
      end
    end,
  })
  return {
    itemsPerRow = itemsPerRow,
    columns = columns,
    sections = sections,
    content = content,
    width = content.width,
    height = content.height,
  }
end

-- Arrange applies a measure: every section's cells and size, then the sections where it put them.
-- It returns the size it took.
---@param measured ViewMeasure
---@return number width, number height
function views.viewProto:Arrange(measured)
  for section, sectionMeasure in pairs(measured.sections) do
    section:Arrange(self.kind, sectionMeasure)
  end
  self.content.maxCellWidth = measured.columns
  self.content:Arrange(measured.content)
  for _, section in pairs(self.sections) do
    debug:WalkAndFixAnchorGraph(section.frame)
  end
  return measured.width, measured.height
end

-- Layout measures the bound sections with layout's items per row and columns and arranges them.
---@param ctx Context
---@param layout ViewLayout
---@return number width, number height
function views.viewProto:Layout(ctx, layout)
  local _ = ctx
  return self:Arrange(self:Measure(layout.itemsPerRow, layout.columns))
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

-- BeginRender starts a render pass without releasing or hiding anything. Last pass's
-- sections are set aside so GetOrCreateSection can draw the same category into the same
-- section, and every button the pass draws is recorded in claims; the bag releases the
-- buttons no renderer claimed once every renderer has run. A second call before
-- FinishRender is a no-op.
---@param ctx Context
---@param claims table<Item, boolean>|nil
function views.viewProto:BeginRender(ctx, claims)
  local _ = ctx
  if self.rendering then return end
  self.rendering = true
  self.claims = claims
  self.staleSections = self.sections
  self.sections = {}
  self.content:Wipe()
  self.itemCount = 0
  wipe(self.itemsByBagAndSlot)
  self:ClearDeferredItems()
  self:ClearDirtySections()
  wipe(self.slotToSection)
  self.sortRequired = true
  self.isNew = true
end

-- FinishRender ends the pass and releases the sections it did not draw again. Their item
-- buttons are left alone: a button may already be drawn somewhere else in this pass.
---@param ctx Context
function views.viewProto:FinishRender(ctx)
  if not self.rendering then return end
  self.rendering = false
  self.claims = nil
  local stale = self.staleSections
  self.staleSections = nil
  for _, section in pairs(stale or {}) do
    section:Release(ctx)
  end
end

-- Wipe tears the view down: every section and every item button it drew is released,
-- including the sections a failed render pass set aside.
---@param ctx Context
function views.viewProto:Wipe(ctx)
  assert(self.WipeHandler, 'WipeHandler not set')
  for _, section in pairs(self.staleSections or {}) do
    section:ReleaseAllCells(ctx)
  end
  self:FinishRender(ctx)
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
      -- Static per-slot buttons belong to ItemFrame, not to the view.
      item = itemFrame:GetButton(ctx, slotkey)
    end
    self.itemsByBagAndSlot[slotkey] = item
  end
  if self.claims then
    self.claims[item] = true
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
    section = self.staleSections and self.staleSections[category]
    if section then
      self.staleSections[category] = nil
      section:PrepareForReuse()
    else
      section = sectionFrame:Create(ctx)
      section.frame:SetParent(self.content:GetScrollView())
    end
    section:SetTitle(category, color)
    if not onlyCreate then
      self.content:AddCell(category, section)
    end
    self.sections[category] = section
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
