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
  debug:Log("Wipe", "Grid View Wipe")
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
local function GridView(view, ctx, bag, slotInfo, callback)
  view:Wipe(ctx)
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
    if item.isFreeSlot then
      local itemButton = view:GetOrCreateItemButton(ctx, slotkey)
      itemButton:SetFreeSlots(ctx, item.bagid, item.slotid, -1)
      local category = item.itemInfo and item.itemInfo.category or L:G("Everything")
      local section = view:GetOrCreateSection(ctx, category)
      section:AddCell(slotkey, itemButton)
      view:SetSlotSection(slotkey, section)
    else
      local itemButton = view:GetOrCreateItemButton(ctx, slotkey)
      if itemButton.SetItemFromData then
        itemButton:SetItemFromData(ctx, item)
      else
        itemButton.staticData = item
        itemButton:SetItem(ctx, slotkey)
      end
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

  -- Pass 1: Draw layout
  for _, section in ipairs(view.content.cells) do
    section.shouldShrinkWhenCollapsed = false
  end

  view.content:Draw({
    cells = view.content.cells,
    maxWidthPerRow = ((37 + 4) * sizeInfo.itemsPerRow) + 16,
    columns = sizeInfo.columnCount,
  })

  -- Pass 2: Row collapse shrink optimization
  local maxRowWidth = ((37 + 4) * sizeInfo.itemsPerRow) + 16
  local spacing = 4
  local rowSections = {}
  local currentRowWidth = 0
  local currentRow = 1
  local needsRedraw = false

  for _, section in ipairs(view.content.cells) do
    if section.frame and section.frame:IsShown() then
      local sectionWidth = section.frame:GetWidth()
      if currentRowWidth > 0 and currentRowWidth + sectionWidth > maxRowWidth then
        currentRow = currentRow + 1
        currentRowWidth = sectionWidth
      else
        if currentRowWidth > 0 then
          currentRowWidth = currentRowWidth + sectionWidth + spacing
        else
          currentRowWidth = sectionWidth
        end
      end

      if not rowSections[currentRow] then
        rowSections[currentRow] = {}
      end
      table.insert(rowSections[currentRow], section)
    end
  end

  for _, sectionsInRow in pairs(rowSections) do
    local allCollapsed = true
    for _, section in ipairs(sectionsInRow) do
      if not section:IsCollapsed() then
        allCollapsed = false
        break
      end
    end
    for _, section in ipairs(sectionsInRow) do
      if section.shouldShrinkWhenCollapsed ~= allCollapsed then
        section.shouldShrinkWhenCollapsed = allCollapsed
        needsRedraw = true
      end
    end
  end

  if needsRedraw then
    for _, section in ipairs(view.content.cells) do
      section:Draw(bag.kind, database:GetBagView(bag.kind), false)
    end
    view.content:Draw({
      cells = view.content.cells,
      maxWidthPerRow = ((37 + 4) * sizeInfo.itemsPerRow) + 16,
      columns = sizeInfo.columnCount,
    })
  end

  for _, section in pairs(view.sections) do
    debug:WalkAndFixAnchorGraph(section.frame)
  end

  view.itemCount = slotInfo.totalItems
  callback()
end

---@param parent Frame
---@param kind BagKind
---@param tabID? number
---@return View
function views:NewGrid(parent, kind, tabID)
  local view = views:NewBlankView()
  view.itemCount = 0
  view.bagview = const.BAG_VIEW.SECTION_GRID
  view.kind = kind
  view.tabID = tabID or 1
  view.content = grid:Create(parent, false)
  view.content:SortVertical()
  view.content:GetContainer():ClearAllPoints()
  view.content:GetContainer():SetAllPoints(parent)
  view.content.compactStyle = const.GRID_COMPACT_STYLE.NONE
  view.content:Hide()
  view.Render = GridView
  view.WipeHandler = Wipe
  view.sortRequired = false
  view.isNew = true

  -- Create empty group state frame (only for backpack)
  if kind == const.BAG_KIND.BACKPACK then
    local emptyGroupFrame = CreateFrame("Frame", nil, view.content:GetContainer())
    emptyGroupFrame:SetAllPoints()
    emptyGroupFrame:SetFrameLevel(view.content:GetContainer():GetFrameLevel() + 10)
    emptyGroupFrame:Hide()

    local helpText = emptyGroupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    helpText:SetPoint("CENTER", emptyGroupFrame, "CENTER", 0, 0)
    helpText:SetText(L:G("Drag a section header to this tab at the bottom of the window to add a section to this group!"))
    helpText:SetTextColor(0.6, 0.6, 0.6, 1)
    helpText:SetWidth(220)
    helpText:SetJustifyH("CENTER")

    view.emptyGroupFrame = emptyGroupFrame
  end

  return view
end
