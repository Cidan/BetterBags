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
  for _, section in pairs(view.sections) do
    section:ReleaseAllCells(ctx)
    section:Release(ctx)
  end
  wipe(view.sections)
  wipe(view.itemsByBagAndSlot)
  view.sortRequired = true
end

---@param view View
local function UpdateViewSize(view)
  local parent = view.content:GetContainer():GetParent()
  if database:GetInBagSearch() then
    view.content:GetContainer():SetPoint("TOPLEFT", parent, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET, const.OFFSETS.BAG_TOP_INSET - 20)
  else
    view.content:GetContainer():SetPoint("TOPLEFT", parent, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET, const.OFFSETS.BAG_TOP_INSET)
  end
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
    local category = items:GetCategory(nil, item)
    local isSpecialSection = category == L:G("Free Space") or category == L:G("Recent Items")
    if isSpecialSection then
      return true -- Special sections are shown on all tabs
    end
    return groups:CategoryBelongsToGroup(bagKind, category, view.tabID)
  end
  return true
end

local function FilterChangesetForTab(view, bagKind, added, removed, changed)
  local tabAdded, tabRemoved, tabChanged = {}, {}, {}

  for _, item in pairs(added) do
    if ItemBelongsToTab(view, bagKind, item) then
      table.insert(tabAdded, item)
    end
  end

  for _, item in pairs(removed) do
    if view.itemsByBagAndSlot[item.slotkey] then
      table.insert(tabRemoved, item)
    end
  end

  for _, item in pairs(changed) do
    local belongsNow = ItemBelongsToTab(view, bagKind, item)
    local hadButton = (view.itemsByBagAndSlot[item.slotkey] ~= nil)

    if belongsNow and not hadButton then
      table.insert(tabAdded, item)
    elseif not belongsNow and hadButton then
      table.insert(tabRemoved, item)
    elseif belongsNow and hadButton then
      table.insert(tabChanged, item)
    end
  end

  return tabAdded, tabRemoved, tabChanged
end

local function ShouldMergeItem(bagKind, item, stackInfo)
  if not stackInfo then return false end
  local opts = database:GetStackingOptions(bagKind)
  if not opts.mergeStacks then return false end
  if opts.unmergeAtShop and addon.atInteracting then return false end
  if opts.dontMergePartial and item.itemInfo.itemStackCount ~= item.itemInfo.currentItemCount then return false end
  if not opts.mergeUnstackable and item.itemInfo.itemStackCount == 1 then return false end
  return true
end

---@param view View
---@param ctx Context
---@param bag Bag
---@param slotInfo SlotInfo
---@param callback fun()
local function GridView(view, ctx, bag, slotInfo, callback)
  local sizeInfo = database:GetBagSizeInfo(bag.kind, database:GetBagView(bag.kind))

  -- Tab switch or background rendering changeset-gating optimization
  local added, removed, changed = slotInfo:GetChangeset()
  if bag.GetCurrentTabID and view.tabID ~= bag:GetCurrentTabID() and not ctx:GetBool('redraw') and not view.isNew and not ctx:GetBool('wipe') then
    local tabAdded, tabRemoved, tabChanged = FilterChangesetForTab(view, bag.kind, added, removed, changed)
    if #tabAdded == 0 and #tabRemoved == 0 and #tabChanged == 0 then
      if callback then callback() end
      return
    end
  end

  -- Wipe view for clean sweep
  view:Wipe(ctx)
  view.isNew = false

  -- Extract all items that belong to the active tab ID
  local currentItems = {}
  for _, item in pairs(slotInfo:GetCurrentItems()) do
    if not item.isItemEmpty and ItemBelongsToTab(view, bag.kind, item) then
      table.insert(currentItems, item)
    end
  end

  -- Populate the sections
  for _, item in ipairs(currentItems) do
    local stackInfo = slotInfo.stacks and slotInfo.stacks:GetStackInfo(item.itemHash) or nil
    local isRoot = true

    if ShouldMergeItem(bag.kind, item, stackInfo) then
      if item.slotkey == stackInfo.rootItem then
        -- Root item. Compute total count.
        local totalCount = item.itemInfo.currentItemCount
        for childSlotkey in pairs(stackInfo.slotkeys) do
          local childItem = (slotInfo.itemsBySlotKey and slotInfo.itemsBySlotKey[childSlotkey]) or items:GetItemDataFromSlotKey(childSlotkey)
          if childItem and not childItem.isItemEmpty then
            totalCount = totalCount + childItem.itemInfo.currentItemCount
          end
        end
        item.stackedCount = totalCount
      else
        isRoot = false
      end
    else
      item.stackedCount = nil
    end

    if isRoot then
      local dbItem = items:GetItemDataFromSlotKey(item.slotkey)
      if dbItem then
        -- Get or create visual item button
        local itemButton = view:GetOrCreateItemButton(ctx, item.slotkey)
        if itemButton.SetItemFromData then
          itemButton:SetItemFromData(ctx, item)
        else
          itemButton.staticData = item
          itemButton:SetItem(ctx, item.slotkey)
        end

        -- Resolve polymorphic section name
        local category = L:G("Items")
        if view.bagview == const.BAG_VIEW.SECTION_GRID then
          category = items:GetCategory(ctx, item)
        elseif view.bagview == const.BAG_VIEW.SECTION_ALL_BAGS then
          category = GetBagName(item.bagid)
        end

        local section = view:GetOrCreateSection(ctx, category)
        section:AddCell(item.slotkey, itemButton)
        view:SetSlotSection(item.slotkey, section)
      end
    end
  end

  -- Draw empty slots depending on the bag view
  local activeGroup = nil
  if database:GetGroupsEnabled(bag.kind) and not (bag.kind == const.BAG_KIND.BANK and database:GetShowBankTabs()) then
    activeGroup = view.tabID
  end

  if view.bagview == const.BAG_VIEW.SECTION_ALL_BAGS then
    for bagid, emptyBagData in pairs(slotInfo.emptySlotByBagAndSlot) do
      for slotid, data in pairs(emptyBagData) do
        local slotkey = view:GetSlotKey(data)
        if C_Container.GetBagName(bagid) ~= nil then
          local itemButton = view:GetOrCreateItemButton(ctx, slotkey)
          itemButton:SetFreeSlots(ctx, bagid, slotid, -1)
          local section = view:GetOrCreateSection(ctx, GetBagName(bagid))
          section:AddCell(slotkey, itemButton)
        end
      end
    end
  else
    -- Draw Free Space for SECTION_GRID or ONE_BAG
    local freeSlotsSection = view:GetOrCreateSection(ctx, L:G("Free Space"))
    if database:GetShowAllFreeSpace(bag.kind) then
      freeSlotsSection:SetMaxCellWidth(sizeInfo.itemsPerRow * sizeInfo.columnCount)
      freeSlotsSection:WipeOnlyContents()
      for _, item in ipairs(slotInfo.emptySlotsSorted) do
        local itemButton = view:GetOrCreateItemButton(ctx, item.slotkey)
        itemButton:SetFreeSlots(ctx, item.bagid, item.slotid, 1, true)
        freeSlotsSection:AddCell(item.slotkey, itemButton)
      end
      freeSlotsSection:Draw(bag.kind, database:GetBagView(bag.kind), true, true)
    else
      freeSlotsSection:SetMaxCellWidth(sizeInfo.itemsPerRow)
      for name, freeSlotCount in pairs(slotInfo.emptySlots) do
        if freeSlotCount > 0 and slotInfo.freeSlotKeys[name] ~= nil then
          local itemButton = view:GetOrCreateItemButton(ctx, slotInfo.freeSlotKeys[name])
          local freeSlotBag, freeSlotID = view:ParseSlotKey(slotInfo.freeSlotKeys[name])
          itemButton:SetFreeSlots(ctx, freeSlotBag, freeSlotID, freeSlotCount)
          freeSlotsSection:AddCell(name, itemButton)
        end
      end
      freeSlotsSection:Draw(bag.kind, database:GetBagView(bag.kind), false)
    end
  end

  -- Draw active sections and release empty ones
  for sectionName, section in pairs(view:GetAllSections()) do
    if sectionName ~= L:G("Free Space") then
      if section:GetCellCount() == 0 then
        view:RemoveSection(sectionName)
        section:ReleaseAllCells(ctx)
        section:Release(ctx)
      else
        if sectionName == L:G("Recent Items") then
          section:SetMaxCellWidth(sizeInfo.itemsPerRow * sizeInfo.columnCount)
        else
          section:SetMaxCellWidth(sizeInfo.itemsPerRow)
        end
        section:Draw(bag.kind, database:GetBagView(bag.kind), false)
      end
    end
  end

  -- Hide filtered sections
  local hiddenCells = {}
  for sectionName, section in pairs(view:GetAllSections()) do
    local shouldHide = false
    if categories:IsCategoryShown(sectionName) == false then
      shouldHide = true
    end
    if not shouldHide and activeGroup then
      local isSpecialSection = sectionName == L:G("Free Space") or sectionName == L:G("Recent Items")
      if not isSpecialSection and not groups:CategoryBelongsToGroup(bag.kind, sectionName, activeGroup) then
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
    for sectionName, section in pairs(view:GetAllSections()) do
      local isSpecialSection = sectionName == L:G("Free Space") or sectionName == L:G("Recent Items")
      if not isSpecialSection then
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
    end

    if visibleSectionCount == 0 then
      view.emptyGroupFrame:Show()
      for sectionName, section in pairs(view:GetAllSections()) do
        local isSpecialSection = sectionName == L:G("Free Space") or sectionName == L:G("Recent Items")
        if isSpecialSection then
          local alreadyHidden = false
          for _, hiddenSection in ipairs(hiddenCells) do
            if hiddenSection == section then
              alreadyHidden = true
              break
            end
          end
          if not alreadyHidden then
            table.insert(hiddenCells, section)
          end
        end
      end
    else
      view.emptyGroupFrame:Hide()
    end
  elseif view.emptyGroupFrame then
    view.emptyGroupFrame:Hide()
  end

  -- Sort sections if required
  if ctx:GetBool('wipe') or view.sortRequired then
    view.sortRequired = false
    view.content.maxCellWidth = sizeInfo.columnCount
    view.content:Sort(sort:GetSectionSortFunction(bag.kind, database:GetBagView(bag.kind)))
  end

  -- Pass 1: Draw layout
  for _, section in ipairs(view.content.cells) do
    section.shouldShrinkWhenCollapsed = false
  end

  local w, h = view.content:Draw({
    cells = view.content.cells,
    maxWidthPerRow = ((37 + 4) * sizeInfo.itemsPerRow) + 16,
    columns = sizeInfo.columnCount,
    header = view:RemoveSectionFromGrid(L:G("Recent Items")),
    footer = database:GetShowAllFreeSpace(bag.kind) and view:RemoveSectionFromGrid(L:G("Free Space")) or nil,
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
    w, h = view.content:Draw({
      cells = view.content.cells,
      maxWidthPerRow = ((37 + 4) * sizeInfo.itemsPerRow) + 16,
      columns = sizeInfo.columnCount,
      header = view:RemoveSectionFromGrid(L:G("Recent Items")),
      footer = database:GetShowAllFreeSpace(bag.kind) and view:RemoveSectionFromGrid(L:G("Free Space")) or nil,
      mask = hiddenCells,
    })
  end

  for _, section in pairs(view.sections) do
    debug:WalkAndFixAnchorGraph(section.frame)
  end

  -- Set size and scrollbars
  if w < 260 then w = 260 end
  if bag.tabs and w < bag.tabs.width then
    w = bag.tabs.width
  end
  if bag.slots and bag.slots:IsShown() then
    local minW = bag.slots.frame:GetWidth()
      - const.OFFSETS.BAG_LEFT_INSET
      + const.OFFSETS.BAG_RIGHT_INSET
      - const.OFFSETS.SCROLLBAR_WIDTH
    if w < minW then
      w = minW
    end
  end
  if h < 100 then h = 100 end
  if database:GetInBagSearch() then
    h = h + 20
  end

  local bagHeight = h +
    const.OFFSETS.BAG_BOTTOM_INSET + -const.OFFSETS.BAG_TOP_INSET +
    const.OFFSETS.BOTTOM_BAR_HEIGHT + const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET

  local maxHeight = UIParent:GetHeight() * 0.90
  local bagWidth = w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET + const.OFFSETS.SCROLLBAR_WIDTH
  if bagHeight > maxHeight then
    bagHeight = maxHeight
    view.content:ShowScrollBar()
  else
    view.content:HideScrollBar()
  end

  bag.frame:SetWidth(bagWidth)
  bag.frame:SetHeight(bagHeight)
  UpdateViewSize(view)
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
  view.content = grid:Create(parent)
  view.content:SortVertical()
  view.content:GetContainer():ClearAllPoints()
  view.content:GetContainer():SetPoint("TOPLEFT", parent, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET, const.OFFSETS.BAG_TOP_INSET)
  view.content:GetContainer():SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", const.OFFSETS.BAG_RIGHT_INSET, const.OFFSETS.BAG_BOTTOM_INSET + const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET + 20)
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
