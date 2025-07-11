---@diagnostic disable: duplicate-set-field,duplicate-doc-field



local addon = GetBetterBags()

local const = addon:GetConstants()
local database = addon:GetDatabase()

local itemFrame = addon:GetItemFrame()

local items = addon:GetItems()

local grid = addon:GetGrid()

local views = addon:GetViews()

local sort = addon:GetSort()

---@class Localization: AceModule
local L =  addon:GetModule('Localization')

local categories = addon:GetCategories()

local async = addon:GetAsync()

local debug = addon:GetDebug()

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
end

-- ClearButton clears a button and makes it empty while preserving the slot,
-- but does not release it, while also adding it to the deferred items list.
---@param ctx Context
---@param view View
---@param slotkey string
local function ClearButton(ctx, view, slotkey)
  if not view.itemsByBagAndSlot[slotkey] then
    return
  end
  local item = items:GetItemDataFromSlotKey(slotkey)
  debug:Log("ClearButton", "Clearing button for item", slotkey)
  local cell = view.itemsByBagAndSlot[slotkey]
  if cell then
    local section = view:GetSlotSection(slotkey)
    if section then
      section:DislocateAllCellsWithID(slotkey)
      section:RemoveCell(slotkey)
    end
    view.itemsByBagAndSlot[slotkey]:Wipe(ctx)
    view.itemsByBagAndSlot[slotkey] = nil
    view:RemoveSlotSection(slotkey)
  end
  addon:GetBagFromBagID(item.bagid).drawOnClose = true
end

-- CreateButton creates a button for an item and adds it to the view.
-- Returns true if the button was created, false if it already existed.
---@param ctx Context
---@param view View
---@param slotkey string
---@return boolean
local function CreateButton(ctx, view, slotkey)
  if view.itemsByBagAndSlot[slotkey] then
    if not view.itemsByBagAndSlot[slotkey].isFreeSlot then
      debug:Log("CreateButton", "Button already exists for slotkey", slotkey)
      return false
    else
      ClearButton(ctx, view, slotkey)
    end
  end
  local item = items:GetItemDataFromSlotKey(slotkey)
  debug:Log("CreateButton", "Creating button for item", slotkey)
  local oldSection = view:GetSlotSection(slotkey)
  if oldSection then
    oldSection:RemoveCell(slotkey)
  end
  local category = categories:GetBestCategoryForItem(ctx, item)
  local itemButton = view:GetOrCreateItemButton(ctx, slotkey)
  itemButton:SetItem(ctx, slotkey)
  local section = view:GetOrCreateSection(ctx, category)
  section:AddCell(itemButton:GetItemData().slotkey, itemButton)
  view:AddDirtySection(category)
  view:SetSlotSection(itemButton:GetItemData().slotkey, section)
  return true
end

---@param ctx Context
---@param view View
---@param slotkey string
local function UpdateButton(ctx, view, slotkey)
  debug:Log("UpdateButton", "Updating button for item", slotkey)
  local itemButton = view:GetOrCreateItemButton(ctx, slotkey)
  itemButton:SetItem(ctx, slotkey)
  if ctx:GetBool('wipe') == false and database:GetShowNewItemFlash(view.kind) then
    view:FlashStack(ctx, slotkey)
  end
end

-- UpdateDeletedSlot updates the slot key of a deleted slot, while maintaining the
-- button position and section to prevent a sort from happening.
---@param ctx Context
---@param view View
---@param oldSlotKey string
---@param newSlotKey string
local function UpdateDeletedSlot(ctx, view, oldSlotKey, newSlotKey)
  debug:Log("UpdateDeletedSlot", "Updating button for item", oldSlotKey, newSlotKey)
  local oldSlotCell = view.itemsByBagAndSlot[oldSlotKey]
  local oldSlotSection = view:GetSlotSection(oldSlotKey)
  if not oldSlotSection then
    UpdateButton(ctx, view, newSlotKey)
    return
  end
  oldSlotSection:RekeyCell(oldSlotKey, newSlotKey)
  oldSlotCell:SetItem(ctx, newSlotKey)
  view.itemsByBagAndSlot[newSlotKey] = oldSlotCell
  view.itemsByBagAndSlot[oldSlotKey] = nil
  view:SetSlotSection(newSlotKey, oldSlotSection)
  view:RemoveSlotSection(oldSlotKey)
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

---@param ctx Context
---@param view View
---@param stackInfo StackInfo
local function ReconcileWithPartial(ctx, view, stackInfo)
  local opts = database:GetStackingOptions(view.kind)
  if not opts.dontMergePartial then return end
  local rootItem = items:GetItemDataFromSlotKey(stackInfo.rootItem)

  -- If the root item is not full, all items in the stack will be partial,
  -- so let's make sure they all are drawn.
  if rootItem.itemInfo.currentItemCount ~= rootItem.itemInfo.itemStackCount then
    CreateButton(ctx, view, rootItem.slotkey)
    for slotkey in pairs(stackInfo.slotkeys) do
      CreateButton(ctx, view, slotkey)
    end
    return
  end

  -- The root item is full, so first, let's draw it.
  if not CreateButton(ctx, view, stackInfo.rootItem) then
    -- And update it just in case
    UpdateButton(ctx, view, stackInfo.rootItem)
  end

  -- Now we need to check each item in the stack to see if it's partial. If it is, draw it
  -- if it's not, clear it.
  for slotkey in pairs(stackInfo.slotkeys) do
    local childData = items:GetItemDataFromSlotKey(slotkey)
    if childData.itemInfo.currentItemCount ~= childData.itemInfo.itemStackCount then
      CreateButton(ctx, view, slotkey)
    else
      ClearButton(ctx, view, slotkey)
    end
  end
end

---@param ctx Context
---@param view View
---@param stackInfo StackInfo
local function ReconcileStack(ctx, view, stackInfo)
  local opts = database:GetStackingOptions(view.kind)
  if opts.dontMergePartial then
    ReconcileWithPartial(ctx, view, stackInfo)
    return
   end

  -- If any child item has a button, clear it, as it's no longer the root item.
  for childKey in pairs(stackInfo.slotkeys) do
    if view.itemsByBagAndSlot[childKey] then
      ClearButton(ctx, view, childKey)
    end
  end

  -- The root item is always drawn, so first, let's draw it.
  if not CreateButton(ctx, view, stackInfo.rootItem) then
   -- And update it just in case it aleady exists.
   UpdateButton(ctx, view, stackInfo.rootItem)
  end
end

---@param view View
---@param ctx Context
---@param bag Bag
---@param slotInfo SlotInfo
---@param callback fun()
local function GridView(view, ctx, bag, slotInfo, callback)
  ---@type Cell[]
  local hiddenCells = {}

  local sizeInfo = database:GetBagSizeInfo(bag.kind, database:GetBagView(bag.kind))

  local added, removed, changed = slotInfo:GetChangeset()

  if ctx:GetBool('redraw') then
    view:Wipe(ctx)
    ---@type ItemData[]
    local currentItems = {}
    for _, item in pairs(slotInfo:GetCurrentItems()) do
      if not item.isItemEmpty then
        table.insert(currentItems, item)
      end
    end
    added = currentItems
  elseif ctx:GetBool('wipe') then
    view:Wipe(ctx)
  end

  local opts = database:GetStackingOptions(bag.kind)

  for _, item in pairs(removed) do
    local stackInfo = slotInfo.stacks:GetStackInfo(item.itemHash)
    if not stackInfo then
      ClearButton(ctx, view, item.slotkey)
    elseif view.itemsByBagAndSlot[item.slotkey] then
      if stackInfo.rootItem ~= nil and view.itemsByBagAndSlot[stackInfo.rootItem] == nil then
        UpdateDeletedSlot(ctx, view, item.slotkey, stackInfo.rootItem)
      else
        ClearButton(ctx, view, item.slotkey)
      end
    elseif view.itemsByBagAndSlot[stackInfo.rootItem] then
      UpdateButton(ctx, view, stackInfo.rootItem)
    end
  end

  -- Let's just add items for now.
  for _, item in pairs(added) do
    local stackInfo = slotInfo.stacks:GetStackInfo(item.itemHash)
    ---- Check stacking options
    if (not opts.mergeStacks) or
    (opts.unmergeAtShop and addon.atInteracting) or
    (opts.dontMergePartial and item.itemInfo.itemStackCount ~= item.itemInfo.currentItemCount) or
    (not opts.mergeUnstackable and item.itemInfo.itemStackCount == 1) or
    not stackInfo then
      -- If stacking is not allowed, create a new button
      CreateButton(ctx, view, item.slotkey)
    else
      -- If the item is part of a stack, reconcile the stack
      ReconcileStack(ctx, view, stackInfo)
    end
  end

  for _, item in pairs(changed) do
    local stackInfo = slotInfo.stacks:GetStackInfo(item.itemHash)
    if not stackInfo then
      UpdateButton(ctx, view, item.slotkey)
    elseif view.itemsByBagAndSlot[item.slotkey] then
      if (not opts.mergeStacks) or
      (opts.unmergeAtShop and addon.atInteracting) or
      (not opts.mergeUnstackable and item.itemInfo.itemStackCount == 1) then
        UpdateButton(ctx, view, item.slotkey)
      else
        UpdateButton(ctx, view, item.slotkey)
        ReconcileStack(ctx, view, stackInfo)
      end
    elseif view.itemsByBagAndSlot[stackInfo.rootItem] then
      if (not opts.mergeStacks) or
      (opts.unmergeAtShop and addon.atInteracting) or
      (not opts.mergeUnstackable and item.itemInfo.itemStackCount == 1) then
        UpdateButton(ctx, view, stackInfo.rootItem)
      else
        UpdateButton(ctx, view, stackInfo.rootItem)
        ReconcileStack(ctx, view, stackInfo)
      end
    end
  end

  -- Special handling for Recent Items -- add it to the dirty sections if
  -- it has no items visible.
  local recentItemsSection = view:GetSection(L:G("Recent Items"))
  if recentItemsSection then
    local hasItem = false
    for _, cell in pairs(recentItemsSection:GetAllCells()) do
      if cell.frame:IsShown() then
        hasItem = true
        break
      end
    end
    if not hasItem then
      view:AddDirtySection(L:G("Recent Items"))
    end
  end

  -- Update any sections that are dirty and need to be drawn.
  local dirtySections = view:GetDirtySections()
  for sectionName in pairs(dirtySections) do
    local section = view:GetSection(sectionName)
    -- We need to check for the section here, as a section
    -- may have been added to dirty items when it doesn't
    -- exist yet. This happens when a new item's "new item"
    -- status expires, it's category is no longer a new item
    -- but the actual category hasn't been drawn yet.
    if section ~= nil then
      -- If a cell is hidden, remove it as it was dislocated and hidden.
      for slotkey, cell in pairs(section:GetAllCells()) do
        if not cell.frame:IsShown() then
          section:RemoveCell(slotkey)
          cell:Wipe(ctx)
          view:RemoveSlotSection(slotkey)
        end
      end
      -- Remove the section if it's empty, otherwise draw it.
      if section:GetCellCount() == 0 then
        debug:Log("Section", "Removing section", sectionName)
        view:RemoveSection(sectionName)
        section:ReleaseAllCells(ctx)
        section:Release(ctx)
      else
        debug:Log("Section", "Drawing section", sectionName)
        if sectionName == L:G("Recent Items") then
          section:SetMaxCellWidth(sizeInfo.itemsPerRow * sizeInfo.columnCount)
        else
          section:SetMaxCellWidth(sizeInfo.itemsPerRow)
        end
        section:Draw(bag.kind, database:GetBagView(bag.kind), false)
      end
    end
  end
  view:ClearDirtySections()

  -- Hide sections that are not shown.
  for sectionName, section in pairs(view:GetAllSections()) do
    if categories:IsCategoryShown(sectionName) == false then
      table.insert(hiddenCells, section)
    end
  end

  -- Sort the sections.
  if ctx:GetBool('wipe') then
    view.content.maxCellWidth = sizeInfo.columnCount
    view.content:Sort(sort:GetSectionSortFunction(bag.kind, const.BAG_VIEW.SECTION_GRID))
  end

  -- Get the free slots section and add the free slots to it.
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
      if slotInfo.freeSlotKeys[name] ~= nil then
        local itemButton = view:GetOrCreateItemButton(ctx, name)
        local freeSlotBag, freeSlotID = view:ParseSlotKey(slotInfo.freeSlotKeys[name])
        itemButton:SetFreeSlots(ctx, freeSlotBag, freeSlotID, freeSlotCount)
        freeSlotsSection:AddCell(name, itemButton)
      else
        local itemButton = view:GetOrCreateItemButton(ctx, name)
        itemButton:SetFreeSlots(ctx, 1, 1, freeSlotCount)
        freeSlotsSection:AddCell(name, itemButton)
      end
    end
    freeSlotsSection:Draw(bag.kind, database:GetBagView(bag.kind), false)
  end

  debug:StartProfile('Content Draw Stage %d', bag.kind)
  local w, h = view.content:Draw({
    cells = view.content.cells,
    maxWidthPerRow = ((37 + 4) * sizeInfo.itemsPerRow) + 16,
    columns = sizeInfo.columnCount,
    header = view:RemoveSectionFromGrid(L:G("Recent Items")),
    footer = database:GetShowAllFreeSpace(bag.kind) and view:RemoveSectionFromGrid(L:G("Free Space")) or nil,
    mask = hiddenCells,
  })
  for _, section in pairs(view.sections) do
    debug:WalkAndFixAnchorGraph(section.frame)
  end
  debug:EndProfile('Content Draw Stage %d', bag.kind)
  -- Reposition the content frame if the recent items section is empty.
  if w < 160 then
    w = 220
  end
  if bag.tabs and w < bag.tabs.width then
    w = bag.tabs.width
  end
  if h == 0 then
    h = 40
  end
  if database:GetInBagSearch() then
    h = h + 20
  end
  view.content:HideScrollBar()
  --TODO(lobato): Implement SafeSetSize that prevents the window from being larger
  -- than the screen space.
  bag.frame:SetWidth(w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET)
  local bagHeight = h +
  const.OFFSETS.BAG_BOTTOM_INSET + -const.OFFSETS.BAG_TOP_INSET +
  const.OFFSETS.BOTTOM_BAR_HEIGHT + const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET
  bag.frame:SetHeight(bagHeight)
  UpdateViewSize(view)
  view.itemCount = slotInfo.totalItems
  callback()
end

---@param parent Frame
---@param kind BagKind
---@return View
function views:NewGrid(parent, kind)
  local view = views:NewBlankView()
  view.itemCount = 0
  view.bagview = const.BAG_VIEW.SECTION_GRID
  view.kind = kind
  view.content = grid:Create(parent)
  view.content:SortVertical()
  view.content:GetContainer():ClearAllPoints()
  view.content:GetContainer():SetPoint("TOPLEFT", parent, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET, const.OFFSETS.BAG_TOP_INSET)
  view.content:GetContainer():SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", const.OFFSETS.BAG_RIGHT_INSET, const.OFFSETS.BAG_BOTTOM_INSET + const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET + 20)
  view.content.compactStyle = const.GRID_COMPACT_STYLE.NONE
  view.content:Hide()
  view.Render = GridView
  view.WipeHandler = Wipe
  return view
end

