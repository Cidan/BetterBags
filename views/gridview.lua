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
    section:RemoveCell(slotkey)
    view.itemsByBagAndSlot[slotkey]:Wipe(ctx)
    view.itemsByBagAndSlot[slotkey] = nil
    view:RemoveSlotSection(slotkey)
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
local function GridView(view, ctx, bag, slotInfo, callback)
  if ctx:GetBool('wipe') then
    view:Wipe(ctx)
  end
  ---@type Cell[]
  local hiddenCells = {}

  local sizeInfo = database:GetBagSizeInfo(bag.kind, database:GetBagView(bag.kind))

  local added, removed, changed = slotInfo:GetChangeset()

  local opts = database:GetStackingOptions(bag.kind)

  for _, item in pairs(removed) do
    local stackInfo = slotInfo.stacks:GetStackInfo(item.itemHash)
    if not stackInfo then
      ClearButton(ctx, view, item.slotkey)
    elseif view.itemsByBagAndSlot[item.slotkey] then
      ClearButton(ctx, view, item.slotkey)
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
    (opts.dontMergePartial and item.itemInfo.currentItemCount < item.itemInfo.itemStackCount) or
    (not opts.mergeUnstackable and item.itemInfo.itemStackCount == 1) or
    not stackInfo then
      -- If stacking is not allowed, create a new button
      CreateButton(ctx, view, item.slotkey)
    elseif stackInfo.rootItem ~= item.slotkey and view.itemsByBagAndSlot[stackInfo.rootItem] ~= nil then
      UpdateButton(ctx, view, stackInfo.rootItem)
    elseif stackInfo.rootItem ~= item.slotkey and view.itemsByBagAndSlot[stackInfo.rootItem] == nil then
      CreateButton(ctx, view, stackInfo.rootItem)
    else
      CreateButton(ctx, view, item.slotkey)
    end
  end

  for _, item in pairs(changed) do
    local stackInfo = slotInfo.stacks:GetStackInfo(item.itemHash)
    if not stackInfo then
      UpdateButton(ctx, view, item.slotkey)
    elseif view.itemsByBagAndSlot[item.slotkey] then
      UpdateButton(ctx, view, item.slotkey)
    elseif view.itemsByBagAndSlot[stackInfo.rootItem] then
      UpdateButton(ctx, view, stackInfo.rootItem)
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
  view.content.maxCellWidth = sizeInfo.columnCount
  view.content:Sort(sort:GetSectionSortFunction(bag.kind, const.BAG_VIEW.SECTION_GRID))

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

