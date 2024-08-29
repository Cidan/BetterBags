---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class ItemFrame: AceModule
local itemFrame = addon:GetModule('ItemFrame')

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

---@class Async: AceModule
local async = addon:GetModule('Async')

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
end

-- ClearButton clears a button and makes it empty while preserving the slot,
-- but does not release it, while also adding it to the deferred items list.
---@param ctx Context
---@param view View
---@param slotkey string
local function ClearButton(ctx, view, slotkey)
  local item = items:GetItemDataFromSlotKey(slotkey)
  debug:Log("ClearButton", "Clearing button for item", slotkey)
  local cell = view.itemsByBagAndSlot[slotkey]
  if cell then
    local section = view:GetSlotSection(slotkey)
    section:DislocateAllCellsWithID(slotkey)
    view:AddDeferredItem(slotkey)
  end
  addon:GetBagFromBagID(item.bagid).drawOnClose = true
end

-- CreateButton creates a button for an item and adds it to the view.
---@param ctx Context
---@param view View
---@param slotkey string
local function CreateButton(ctx, view, slotkey)
  local item = items:GetItemDataFromSlotKey(slotkey)
  debug:Log("CreateButton", "Creating button for item", slotkey)
  view:RemoveDeferredItem(slotkey)
  local oldSection = view:GetSlotSection(slotkey)
  if oldSection then
    oldSection:RemoveCell(slotkey)
  end
  local category = item.itemInfo.category
  local itemButton = view:GetOrCreateItemButton(ctx, slotkey)
  itemButton:SetItem(ctx, slotkey)
  local section = view:GetOrCreateSection(ctx, category)
  section:AddCell(itemButton:GetItemData().slotkey, itemButton)
  view:AddDirtySection(category)
  view:SetSlotSection(itemButton:GetItemData().slotkey, section)
end

---@param ctx Context
---@param view View
---@param slotkey string
local function UpdateButton(ctx, view, slotkey)
  debug:Log("UpdateButton", "Updating button for item", slotkey)
  view:RemoveDeferredItem(slotkey)
  local itemButton = view:GetOrCreateItemButton(ctx, slotkey)
  itemButton:SetItem(ctx, slotkey)
  if ctx:GetBool('wipe') == false and database:GetShowNewItemFlash(view.kind) then
    view:FlashStack(ctx, slotkey)
  end
  --local data = itemButton:GetItemData()
  --local category = data.itemInfo.category
  --view:AddDirtySection(category)
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
  view:AddDirtySection(oldSlotCell:GetItemData().itemInfo.category)
  local newData = items:GetItemDataFromSlotKey(newSlotKey)
  view:AddDirtySection(newData.itemInfo.category)
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

---@param view View
---@param ctx Context
---@param bag Bag
---@param slotInfo SlotInfo
---@param callback fun()
local function AltGridView(view, ctx, bag, slotInfo, callback)
  if ctx:GetBool('wipe') then
    view:Wipe(ctx)
  end
  ---@type Cell[]
  local hiddenCells = {}

  local sizeInfo = database:GetBagSizeInfo(bag.kind, database:GetBagView(bag.kind))

  local added, removed, changed = slotInfo:GetChangeset()

  local opts = database:GetStackingOptions(bag.kind)

  for _, item in pairs(removed) do
--    local stackInfo = slotInfo.stacks:GetStackInfo(item.itemHash)
--    if stackInfo and stackInfo.rootItem ~= item.slotkey then
      --UpdateButton(ctx, view, stackInfo.rootItem)
--    else
      ClearButton(ctx, view, item.slotkey)
--    end
  end

  -- Let's just add items for now.
  for _, item in pairs(added) do
    ---- Check stacking options
    --if (not opts.mergeStacks) or
    --(opts.unmergeAtShop and addon.atInteracting) or
    --(opts.dontMergePartial and item.itemInfo.currentItemCount < item.itemInfo.itemStackCount) or
    --(not opts.mergeUnstackable and item.itemInfo.itemStackCount == 1) then
    --  -- If stacking is not allowed, create a new button
    --  CreateButton(ctx, view, item.slotkey)
    --else
    --  local stackInfo = slotInfo.stacks:GetStackInfo(item.itemHash)
    --  if not stackInfo then
    --    CreateButton(ctx, view, item.slotkey)
    --  elseif stackInfo.rootItem ~= item.slotkey then
    --    UpdateButton(ctx, view, stackInfo.rootItem)
    --  else
    --    CreateButton(ctx, view, item.slotkey)
    --    print("this case needs to be handled")
    --  end
    --end
    CreateButton(ctx, view, item.slotkey)
  end

  for _, item in pairs(changed) do
    ---- Check stacking options
    --if (not opts.mergeStacks) or
    --   (opts.unmergeAtShop and addon.atInteracting) or
    --   (opts.dontMergePartial and item.itemInfo.currentItemCount < item.itemInfo.itemStackCount) or
    --   (not opts.mergeUnstackable and item.itemInfo.itemStackCount == 1) then
    --  -- If stacking is not allowed, create a new button
    --  UpdateButton(ctx, view, item.slotkey)
    --else
    --  -- Handle stacking case if needed
    --end
    UpdateButton(ctx, view, item.slotkey)
  end

  local dirtySections = view:GetDirtySections()
  for sectionName in pairs(dirtySections) do
    local section = view:GetSection(sectionName)
    -- We need to check for the section here, as a section
    -- may have been added to dirty items when it doesn't
    -- exist yet. This happens when a new item's "new item"
    -- status expires, it's category is no longer a new item
    -- but the actual category hasn't been drawn yet.
    if section ~= nil then
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

  view.content.maxCellWidth = sizeInfo.columnCount
  -- Sort the sections.
  view.content:Sort(sort:GetSectionSortFunction(bag.kind, const.BAG_VIEW.SECTION_GRID))
  for sectionName, section in pairs(view:GetAllSections()) do
    if categories:IsCategoryShown(sectionName) == false then
      table.insert(hiddenCells, section)
    end
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

---@param view View
---@param ctx Context
---@param bag Bag
---@param slotInfo SlotInfo
---@param callback fun()
local function GridView(view, ctx, bag, slotInfo, callback)
  if ctx:GetBool('wipe') then
    view:Wipe(ctx)
  end
  local sizeInfo = database:GetBagSizeInfo(bag.kind, database:GetBagView(bag.kind))

  local added, removed, changed = slotInfo:GetChangeset()
  ---@type Cell[]
  local hiddenCells = {}

  for _, item in pairs(removed) do
    local stackInfo = slotInfo.stacks:GetStackInfo(item.itemHash)
    if stackInfo and items:GetItemDataFromSlotKey(item.slotkey).isItemEmpty then
      UpdateDeletedSlot(ctx, view, item.slotkey, stackInfo.rootItem)
    else
      ClearButton(ctx, view, item.slotkey)
    end
  end

  debug:StartProfile('Create Button Stage %d', bag.kind)

  for _, item in pairs(added) do
    local opts = database:GetStackingOptions(bag.kind)
    -- Check stacking options
    if (not opts.mergeStacks) or
    (opts.unmergeAtShop and addon.atInteracting) or
    (opts.dontMergePartial and item.itemInfo.currentItemCount < item.itemInfo.itemStackCount) or
    (not opts.mergeUnstackable and item.itemInfo.itemStackCount == 1) then
      -- If stacking is not allowed, create a new button
      CreateButton(ctx, view, item.slotkey)
    else
      local stackInfo = slotInfo.stacks:GetStackInfo(item.itemHash)
      if stackInfo and slotInfo.stacks:IsRootItem(item.itemHash, item.slotkey) then
        CreateButton(ctx, view, item.slotkey)
      elseif stackInfo and not slotInfo.stacks:IsRootItem(item.itemHash, item.slotkey) then
        if not view.sections[stackInfo.rootItem] or view.deferredItems[stackInfo.rootItem] then
          CreateButton(ctx, view, stackInfo.rootItem)
        else
          UpdateButton(ctx, view, stackInfo.rootItem)
        end
      end
    end
  end

  debug:EndProfile('Create Button Stage %d', bag.kind)

  for _, item in pairs(changed) do
    local opts = database:GetStackingOptions(bag.kind)
    if (not opts.mergeStacks) or
    (opts.unmergeAtShop and addon.atInteracting) or
    (opts.dontMergePartial and item.itemInfo.currentItemCount < item.itemInfo.itemStackCount) or
    (not opts.mergeUnstackable and item.itemInfo.itemStackCount == 1) then
      -- If stacking is not allowed, just update the existing button
      UpdateButton(ctx, view, item.slotkey)
    else
      local stackInfo = slotInfo.stacks:GetStackInfo(item.itemHash)
      if stackInfo and stackInfo.count > 0 then
        if stackInfo.rootItem == item.slotkey then
          UpdateButton(ctx, view, item.slotkey)
        elseif stackInfo.rootItem ~= nil then
          UpdateButton(ctx, view, stackInfo.rootItem)
        else
          -- If there are other items in the stack, update the existing slot
          local existingSlotKey = next(stackInfo.slotkeys)
          if existingSlotKey then
            UpdateButton(ctx, view, existingSlotKey)
            if existingSlotKey ~= item.slotkey then
              -- Clear the old button if it's different from the existing stack
              ClearButton(ctx, view, item.slotkey)
            end
          end
        end
      else
        -- If the stack is empty or doesn't exist, update the current button
        UpdateButton(ctx, view, item.slotkey)
      end
    end
  end

  if not slotInfo.deferDelete then
    for slotkey, _ in pairs(view:GetDeferredItems()) do
      local section = view:GetSlotSection(slotkey)
      if section then
        section:RemoveCell(slotkey)
      end
      if view.itemsByBagAndSlot[slotkey] then
        view.itemsByBagAndSlot[slotkey]:Wipe(ctx)
        view:RemoveSlotSection(slotkey)
      end
    end
    view:ClearDeferredItems()
  end
  debug:StartProfile('Section Draw Stage %d', bag.kind)
  if not slotInfo.deferDelete then
    local dirtySections = view:GetDirtySections()
    for sectionName in pairs(dirtySections) do
      local section = view:GetSection(sectionName)
      -- We need to check for the section here, as a section
      -- may have been added to dirty items when it doesn't
      -- exist yet. This happens when a new item's "new item"
      -- status expires, it's category is no longer a new item
      -- but the actual category hasn't been drawn yet.
      if section ~= nil then
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
  end
  for sectionName, section in pairs(view:GetAllSections()) do
    if categories:IsCategoryShown(sectionName) == false then
      table.insert(hiddenCells, section)
    end
  end
  debug:EndProfile('Section Draw Stage %d', bag.kind)
  -- Get the free slots section and add the free slots to it.
  local freeSlotsSection = view:GetOrCreateSection(ctx, L:G("Free Space"))
  if database:GetShowAllFreeSpace(bag.kind) then
    freeSlotsSection:SetMaxCellWidth(sizeInfo.itemsPerRow * sizeInfo.columnCount)
    freeSlotsSection:WipeOnlyContents()
    for bagid, data in pairs(slotInfo.emptySlotByBagAndSlot) do
      for slotid, item in pairs(data) do
        if not view:GetDeferredItems()[item.slotkey] then
          local itemButton = view:GetOrCreateItemButton(ctx, item.slotkey)
          itemButton:SetFreeSlots(ctx, bagid, slotid, 1, true)
          freeSlotsSection:AddCell(item.slotkey, itemButton)
        end
      end
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
  view.content.maxCellWidth = sizeInfo.columnCount
  -- Sort the sections.
  view.content:Sort(sort:GetSectionSortFunction(bag.kind, const.BAG_VIEW.SECTION_GRID))
  if not slotInfo.deferDelete then
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
  end
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
  view.Render = AltGridView
  view.WipeHandler = Wipe
  return view
end

