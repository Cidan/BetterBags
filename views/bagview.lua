---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class GridFrame: AceModule
local grid = addon:GetModule('Grid')

---@class Views: AceModule
local views = addon:GetModule('Views')

---@class Localization: AceModule
local L =  addon:GetModule('Localization')

---@class Debug : AceModule
local debug = addon:GetModule('Debug')

---@param view View
---@param ctx Context
local function Wipe(view, ctx)
  debug:Log("Wipe", "Bag View Wipe")
  view.content:Wipe()
  if view.freeSlot ~= nil then
    view.freeSlot:Release(ctx)
    view.freeSlot = nil
  end
  if view.freeReagentSlot ~= nil then
    view.freeReagentSlot:Release(ctx)
    view.freeReagentSlot = nil
  end
  view.itemCount = 0
  local k, section = next(view.sections)
  while k do
    view.sections[k] = nil
    section:ReleaseAllCells(ctx)
    section:Release(ctx)
    k, section = next(view.sections)
  end
  wipe(view.itemsByBagAndSlot)
  view.sortRequired = true
  view.isNew = true
end



---@param view View
---@param ctx Context
---@param bag Bag
---@param slotInfo SlotInfo
---@param callback fun()
local function BagView(view, ctx, bag, slotInfo, callback)
  view:BeginRender(ctx)
  view.isNew = false

  local sizeInfo = database:GetBagSizeInfo(bag.kind, database:GetBagView(bag.kind))

  -- Draw empty slots depending on the bag view
  local tabData = slotInfo.tabs and slotInfo.tabs[view.tabID] or {
    items = {},
    categories = {},
  }

  -- Pre-create only the active sections in their precise pre-sorted order
  for _, catData in ipairs(tabData.categories) do
    view:GetOrCreateSection(ctx, catData.name)
  end

  for _, item in ipairs(tabData.items) do
    local slotkey = item.slotkey
    if item.isItemGap then
      local category = item.itemInfo and item.itemInfo.category or L:G("Everything")
      local section = view:GetOrCreateSection(ctx, category)
      local gapCell = { isGap = true, width = 37, height = 37 }
      section:AddCell(slotkey, gapCell)
      view:SetSlotSection(slotkey, section)
    elseif item.isFreeSlot then
      local itemButton = view:GetOrCreateItemButton(ctx, slotkey)
      itemButton:SetFreeSlots(ctx, item, -1)
      local category = item.itemInfo and item.itemInfo.category or L:G("Everything")
      local section = view:GetOrCreateSection(ctx, category)
      section:AddCell(slotkey, itemButton)
      view:SetSlotSection(slotkey, section)
    else
      local itemButton = view:GetOrCreateItemButton(ctx, slotkey)
      itemButton:SetItemFromData(ctx, item)
      local category = item.itemInfo and item.itemInfo.category or L:G("Everything")
      local section = view:GetOrCreateSection(ctx, category)
      section:AddCell(slotkey, itemButton)
      view:SetSlotSection(slotkey, section)
    end
  end

  -- Draw active sections (with sorting bypassed, since they are pre-sorted)
  for sectionName, section in pairs(view:GetAllSections()) do
    section:SetMaxCellWidth(sizeInfo.itemsPerRow)
    local layout = slotInfo.sectionLayouts and slotInfo.sectionLayouts[sectionName]
    if layout then
      if layout.hideHeader then
        section:RemoveHeader()
      end
    end
    section:Draw(bag.kind, database:GetBagView(bag.kind), false, true)
  end

  -- Handle empty group frame
  if view.emptyGroupFrame and view.tabID and view.tabID > 1 then
    if #tabData.categories == 0 then
      view.emptyGroupFrame:Show()
    else
      view.emptyGroupFrame:Hide()
    end
  elseif view.emptyGroupFrame then
    view.emptyGroupFrame:Hide()
  end

  -- Sort sections if required
  view.content.maxCellWidth = sizeInfo.columnCount
  view.sortRequired = false

  view.content:Draw({
    cells = view.content.cells,
    maxWidthPerRow = ((37 + 4) * sizeInfo.itemsPerRow) + 16,
    columns = sizeInfo.columnCount,
  })

  for _, section in pairs(view.sections) do
    debug:WalkAndFixAnchorGraph(section.frame)
  end

  view.itemCount = slotInfo.totalItems
  view:FinishRender(ctx)
  callback()
end

---@param parent Frame
---@param kind BagKind
---@param tabID? number
---@return View
function views:NewBagView(parent, kind, tabID)
  local view = views:NewBlankView()
  view.itemFrames = {}
  view.itemCount = 0
  view.bagview = const.BAG_VIEW.SECTION_ALL_BAGS
  view.kind = kind
  view.tabID = tabID or 1
  view.content = grid:Create(parent, false)
  view.content:GetContainer():ClearAllPoints()
  view.content:GetContainer():SetAllPoints(parent)
  view.content.compactStyle = const.GRID_COMPACT_STYLE.NONE
  view.content:Hide()
  view.Render = BagView
  view.WipeHandler = Wipe
  view.isNew = true

  return view
end
