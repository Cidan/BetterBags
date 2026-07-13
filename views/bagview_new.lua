---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class GridFrame: AceModule
local grid = addon:GetModule('Grid')

---@class Views: AceModule
local views = addon:GetModule('Views')

---@class Localization: AceModule
local L =  addon:GetModule('Localization')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class Groups: AceModule
local groups = addon:GetModule('Groups')

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
  view:Wipe(ctx)
  view.isNew = false

  local sizeInfo = database:GetBagSizeInfo(bag.kind, database:GetBagView(bag.kind))

  -- Draw empty slots depending on the bag view
  local tabData = slotInfo.tabs and slotInfo.tabs[view.tabID]
  if not tabData then
    tabData = {
      items = {},
      categories = {},
    }

    local function CompatItemBelongsToTab(item)
      if not item then return false end
      if view.bagview == const.BAG_VIEW.SECTION_ALL_BAGS then
        if bag.kind == const.BAG_KIND.BANK and addon.isRetail then
          if view.tabID == const.BANK_TAB.BANK then
            return const.ACCOUNT_BANK_BAGS == nil or const.ACCOUNT_BANK_BAGS[item.bagid] == nil
          else
            return item.bagid == view.tabID
          end
        end
        return true
      end
      local category = item.itemInfo and item.itemInfo.category or L:G("Everything")
      if category == L:G("Free Space") or category == L:G("Recent Items") then
        return false
      end
      if bag.kind == const.BAG_KIND.BANK then
        if database:GetShowBankTabs() then
          return item.bagid == view.tabID
        end
        local activeGroup = groups:GetGroup(const.BAG_KIND.BANK, view.tabID)
        if activeGroup and addon.isRetail then
          local itemIsAccountBank = (const.ACCOUNT_BANK_BAGS[item.bagid] ~= nil)
          local tabIsAccountBank = (Enum.BankType and activeGroup.bankType == Enum.BankType.Account)
          if itemIsAccountBank ~= tabIsAccountBank then
            return false
          end
        end
      end
      if database:GetGroupsEnabled(bag.kind) then
        return groups:CategoryBelongsToGroup(bag.kind, category, view.tabID)
      end
      return true
    end

    -- Determine which categories actually have visible items in this tab/view
    local sortedItems = slotInfo.sortedItems
    if not sortedItems then
      sortedItems = {}
      local itemsGetter = slotInfo.GetVisibleItems or slotInfo.GetCurrentItems
      if itemsGetter then
        for _, item in pairs(itemsGetter(slotInfo)) do
          if not item.isItemEmpty then
            table.insert(sortedItems, item)
          end
        end
      end
    end

    local activeCategories = {}
    for _, item in ipairs(sortedItems) do
      if CompatItemBelongsToTab(item) then
        table.insert(tabData.items, item)
        local category = item.itemInfo and item.itemInfo.category or L:G("Everything")
        activeCategories[category] = true
      end
    end

    -- Pre-create only the active sections in their precise pre-sorted order
    if slotInfo.sortedCategories then
      for _, catData in ipairs(slotInfo.sortedCategories) do
        if activeCategories[catData.name] then
          local shownVal = true
          if categories and categories.IsCategoryShown then
            shownVal = categories:IsCategoryShown(catData.name) ~= false
          end
          table.insert(tabData.categories, {
            name = catData.name,
            shown = shownVal,
          })
        end
      end
    else
      for catName in pairs(activeCategories) do
        local shownVal = true
        if categories and categories.IsCategoryShown then
          shownVal = categories:IsCategoryShown(catName) ~= false
        end
        table.insert(tabData.categories, {
          name = catName,
          shown = shownVal,
        })
      end
    end
  end

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
      local dbItem = items:GetItemDataFromSlotKey(slotkey)
      if dbItem then
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

  -- Hide filtered sections
  local hiddenCells = {}
  local shownCategories = {}
  for _, catData in ipairs(tabData.categories) do
    shownCategories[catData.name] = catData.shown
  end

  for sectionName, section in pairs(view:GetAllSections()) do
    if shownCategories[sectionName] == false then
      table.insert(hiddenCells, section)
    end
  end

  -- Handle empty group frame
  if view.emptyGroupFrame and view.tabID and view.tabID > 1 then
    local visibleSectionCount = 0
    for _, section in pairs(view:GetAllSections()) do
      local isHidden = false
      for _, hiddenSection in ipairs(hiddenCells) do
        if hiddenSection == section then
          isHidden = true
          break
        end
      end
      if not isHidden then
        visibleSectionCount = visibleSectionCount + 1
      end
    end

    if visibleSectionCount == 0 then
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
    mask = hiddenCells,
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
      mask = hiddenCells,
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
