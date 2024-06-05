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

---@class Debug : AceModule
local debug = addon:GetModule('Debug')

---@param view View
local function Wipe(view)
  debug:Log("Wipe", "Grid View Wipe")
  view.content:Wipe()
  if view.freeSlot ~= nil then
    view.freeSlot:Release()
    view.freeSlot = nil
  end
  if view.freeReagentSlot ~= nil then
    view.freeReagentSlot:Release()
    view.freeReagentSlot = nil
  end
  view.itemCount = 0
  for _, section in pairs(view.sections) do
    section:ReleaseAllCells()
    section:Release()
  end
  for _, item in pairs(view.itemsByBagAndSlot) do
    --item:Release()
  end
  wipe(view.sections)
  wipe(view.itemsByBagAndSlot)
end

-- ClearButton clears a button and makes it empty while preserving the slot,
-- but does not release it, while also adding it to the deferred items list.
---@param view View
---@param item ItemData
local function ClearButton(view, item)
  local cell = view.itemsByBagAndSlot[item.slotkey]
  local bagid, slotid = view:ParseSlotKey(item.slotkey)
  cell:SetFreeSlots(bagid, slotid, -1, "Recently Deleted")
  view:AddDeferredItem(item.slotkey)
  local section = view:GetSlotSection(item.slotkey)
  if section then
    view:AddDirtySection(section.title:GetText())
  end
  view:AddDirtySection(item.itemInfo.category)
  addon:GetBagFromBagID(bagid).drawOnClose = true
end

-- CreateButton creates a button for an item and adds it to the view.
---@param view View
---@param item ItemData
local function CreateButton(view, item)
  debug:Log("CreateButton", "Creating button for item", item.slotkey)
  view:RemoveDeferredItem(item.slotkey)
  local oldSection = view:GetSlotSection(item.slotkey)
  if oldSection then
    oldSection:RemoveCell(item.slotkey)
  end
  local itemButton = view:GetOrCreateItemButton(item.slotkey)
  itemButton:SetItem(item.slotkey)
  local section = view:GetOrCreateSection(item.itemInfo.category)
  section:AddCell(itemButton:GetItemData().slotkey, itemButton)
  view:AddDirtySection(item.itemInfo.category)
  view:SetSlotSection(itemButton:GetItemData().slotkey, section)
end

---@param ctx Context
---@param view View
---@param slotkey string
local function UpdateButton(ctx, view, slotkey)
  debug:Log("UpdateButton", "Updating button for item", slotkey)
  view:RemoveDeferredItem(slotkey)
  local itemButton = view:GetOrCreateItemButton(slotkey)
  itemButton:SetItem(slotkey)
  if ctx:GetBool('wipe') == false and database:GetShowNewItemFlash(view.kind) then
    view:FlashStack(slotkey)
  end
  local data = itemButton:GetItemData()
  view:AddDirtySection(data.itemInfo.category)
end

-- UpdateDeletedSlot updates the slot key of a deleted slot, while maintaining the
-- button position and section to prevent a sort from happening.
---@param ctx Context
---@param view View
---@param oldSlotKey string
---@param newSlotKey string
local function UpdateDeletedSlot(ctx, view, oldSlotKey, newSlotKey)
  local oldSlotCell = view.itemsByBagAndSlot[oldSlotKey]
  local oldSlotSection = view:GetSlotSection(oldSlotKey)
  if not oldSlotSection then
    UpdateButton(ctx, view, newSlotKey)
    return
  end
  oldSlotSection:RekeyCell(oldSlotKey, newSlotKey)
  oldSlotCell:SetItem(newSlotKey)
  view.itemsByBagAndSlot[newSlotKey] = oldSlotCell
  view.itemsByBagAndSlot[oldSlotKey] = nil
  view:SetSlotSection(newSlotKey, oldSlotSection)
  view:RemoveSlotSection(oldSlotKey)
  view:AddDirtySection(oldSlotCell:GetItemData().itemInfo.category)
  local newData = items:GetItemDataFromSlotKey(newSlotKey)
  view:AddDirtySection(newData.itemInfo.category)
end

---@param view View
---@param ctx Context
---@param bag Bag
---@param slotInfo SlotInfo
local function GridView(view, ctx, bag, slotInfo)
  if view.fullRefresh then
    view:Wipe()
    view.fullRefresh = false
  end
  local sizeInfo = database:GetBagSizeInfo(bag.kind, database:GetBagView(bag.kind))
  view.content.compactStyle = database:GetBagCompaction(bag.kind)

  local added, removed, changed = slotInfo:GetChangeset()

  for _, item in pairs(removed) do
    if item.bagid ~= Enum.BagIndex.Keyring then
      local newSlotKey = view:RemoveButton(item)

      -- Clear if the item is empty, otherwise reindex it as a new item has taken it's
      -- place due to the deleted being the head of a stack.
      if not newSlotKey then
        ClearButton(view, item)
      else
        UpdateDeletedSlot(ctx, view, item.slotkey, newSlotKey)
      end
    end
  end

  for _, item in pairs(added) do
    if item.bagid ~= Enum.BagIndex.Keyring then
      local updateKey = view:AddButton(item)
      if not updateKey then
        CreateButton(view, item)
      else
        UpdateButton(ctx, view, updateKey)
      end
    end
  end

  for _, item in pairs(changed) do
    if item.bagid ~= Enum.BagIndex.Keyring then
      local updateKey, removeKey = view:ChangeButton(item)
      UpdateButton(ctx, view, updateKey)
      if updateKey ~= item.slotkey then
        UpdateButton(ctx, view, item.slotkey)
      end
      if removeKey then
        ClearButton(view, items:GetItemDataFromSlotKey(removeKey))
      end
    end
  end

  if not slotInfo.deferDelete then
    for slotkey, _ in pairs(view:GetDeferredItems()) do
      local section = view:GetSlotSection(slotkey)
      section:RemoveCell(slotkey)
      view.itemsByBagAndSlot[slotkey]:Wipe()
      view:RemoveSlotSection(slotkey)
    end
    view:ClearDeferredItems()
  end

  debug:StartProfile('Section Draw Stage')
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
          section:ReleaseAllCells()
          section:Release()
        else
          debug:Log("Section", "Drawing section", sectionName)
          section:SetMaxCellWidth(sizeInfo.itemsPerRow)
          section:Draw(bag.kind, database:GetBagView(bag.kind), false)
        end
      end
    end
    view:ClearDirtySections()
  end
  debug:EndProfile('Section Draw Stage')

  -- Get the free slots section and add the free slots to it.
  local freeSlotsSection = view:GetOrCreateSection(L:G("Free Space"))
  for name, freeSlotCount in pairs(slotInfo.emptySlots) do
    if slotInfo.freeSlotKeys[name] ~= nil then
      local itemButton = view:GetOrCreateItemButton(name)
      local freeSlotBag, freeSlotID = view:ParseSlotKey(slotInfo.freeSlotKeys[name])
      itemButton:SetFreeSlots(freeSlotBag, freeSlotID, freeSlotCount, name)
      freeSlotsSection:AddCell(name, itemButton)
    else
      local itemButton = view:GetOrCreateItemButton(name)
      itemButton:SetFreeSlots(1, 1, freeSlotCount, name)
      freeSlotsSection:AddCell(name, itemButton)
    end
  end

  freeSlotsSection:Draw(bag.kind, database:GetBagView(bag.kind), false)
  view.content.maxCellWidth = sizeInfo.columnCount
  -- Sort the sections.
  view.content:Sort(sort:GetSectionSortFunction(bag.kind, const.BAG_VIEW.SECTION_GRID))

  if not slotInfo.deferDelete then
    debug:StartProfile('Content Draw Stage')
    local w, h = view.content:Draw()
    for _, section in pairs(view.sections) do
      debug:WalkAndFixAnchorGraph(section.frame)
    end
    debug:EndProfile('Content Draw Stage')
    -- Reposition the content frame if the recent items section is empty.
    if w < 160 then
      w = 160
    end
    if h == 0 then
      h = 40
    end
    view.content:HideScrollBar()
    --TODO(lobato): Implement SafeSetSize that prevents the window from being larger
    -- than the screen space.
    bag.frame:SetWidth(w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET)
    local bagHeight = h +
    const.OFFSETS.BAG_BOTTOM_INSET + -const.OFFSETS.BAG_TOP_INSET +
    const.OFFSETS.BOTTOM_BAR_HEIGHT + const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET
    bag.frame:SetHeight(bagHeight)
  end
  view.itemCount = slotInfo.totalItems
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

