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

---@class Sort: AceModule
local sort = addon:GetModule('Sort')

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

---@param bagid number
---@return string
local function GetBagName(bagid)
  local isBackpack = const.BACKPACK_BAGS[bagid] ~= nil
  if isBackpack then
    local isKeyring = Enum and Enum.BagIndex and Enum.BagIndex.Keyring and bagid == Enum.BagIndex.Keyring
    local bagname = isKeyring and L:G('Keyring') or C_Container.GetBagName(bagid)
    local displayid = isKeyring and 6 or bagid+1
    return format("#%d: %s", displayid, bagname or "Unknown")
  end

  local id = bagid
  if id == -1 then
    return format("#%d: %s", 1, L:G('Bank'))
  elseif id == -3 then
    return format("#%d: %s", 1, L:G('Reagent Bank'))
  else
    local bagname = C_Container.GetBagName(id)
    return format("#%d: %s", id - 4, bagname or L:G("Bank Bag"))
  end
end

local function ItemBelongsToTab(view, bagKind, item)
  if not item then return false end
  if view.bagview == const.BAG_VIEW.SECTION_ALL_BAGS then
    if bagKind == const.BAG_KIND.BANK and addon.isRetail then
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
  if bagKind == const.BAG_KIND.BANK then
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
  if database:GetGroupsEnabled(bagKind) then
    return groups:CategoryBelongsToGroup(bagKind, category, view.tabID)
  end
  return true
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
  local activeGroup = nil
  if database:GetGroupsEnabled(bag.kind) and not (bag.kind == const.BAG_KIND.BANK and database:GetShowBankTabs()) then
    activeGroup = view.tabID
  end

  -- Populate the sections from pre-sorted items (both real items and free/empty slots)
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
    if view.bagview == const.BAG_VIEW.SECTION_ALL_BAGS and slotInfo.emptySlotByBagAndSlot then
      for bagid, emptyBagData in pairs(slotInfo.emptySlotByBagAndSlot) do
        for slotid, data in pairs(emptyBagData) do
          if C_Container.GetBagName(bagid) ~= nil then
            local category = GetBagName(bagid)
            local dummy = {
              isFreeSlot = true,
              bagid = bagid,
              slotid = slotid,
              slotkey = data.slotkey or (bagid .. "_" .. slotid),
              itemInfo = {
                category = category,
                itemName = "",
                itemQuality = -1,
                currentItemCount = 0,
                itemGUID = "",
                currentItemLevel = 0,
                expacID = 0
              }
            }
            table.insert(sortedItems, dummy)
          end
        end
      end
    end
  end

  -- Determine which categories actually have visible items in this tab/view
  local activeCategories = {}
  for _, item in ipairs(sortedItems) do
    if ItemBelongsToTab(view, bag.kind, item) then
      local category = item.itemInfo and item.itemInfo.category or L:G("Everything")
      activeCategories[category] = true
    end
  end

  -- Pre-create only the active sections in their precise pre-sorted order
  local fallbackSort = false
  if slotInfo.sortedCategories then
    for _, catData in ipairs(slotInfo.sortedCategories) do
      if activeCategories[catData.name] then
        view:GetOrCreateSection(ctx, catData.name)
      end
    end
  else
    fallbackSort = true
  end

  for _, item in ipairs(sortedItems) do
    if ItemBelongsToTab(view, bag.kind, item) then
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
  for sectionName, section in pairs(view:GetAllSections()) do
    local shouldHide = false
    if categories:IsCategoryShown(sectionName) == false then
      shouldHide = true
    end
    if not shouldHide and activeGroup and view.bagview ~= const.BAG_VIEW.SECTION_ALL_BAGS then
      if not groups:CategoryBelongsToGroup(bag.kind, sectionName, activeGroup) then
        shouldHide = true
      end
    end
    if shouldHide then
      table.insert(hiddenCells, section)
    end
  end

  -- Handle empty group frame
  if view.emptyGroupFrame and activeGroup and activeGroup > 1 then
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
  if fallbackSort and (ctx:GetBool('wipe') or view.sortRequired) then
    view.sortRequired = false
    view.content:Sort(sort:GetSectionSortFunction(bag.kind, database:GetBagView(bag.kind)))
  end

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
