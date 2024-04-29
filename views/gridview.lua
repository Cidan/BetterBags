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
    item:Release()
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
  --view:RemoveSlotSection(item.slotkey)
  addon:GetBagFromBagID(bagid).drawOnClose = true
end

-- CreateButton creates a button for an item and adds it to the view.
---@param view View
---@param item ItemData
local function CreateButton(view, item)
  debug:Log("CreateButton", "Creating button for item", item.slotkey)
  local itemButton = view:GetOrCreateItemButton(item.slotkey)
  itemButton:SetItem(item.slotkey)
  local section = view:GetOrCreateSection(item.itemInfo.category)
  section:AddCell(itemButton:GetItemData().slotkey, itemButton)
  view:SetSlotSection(itemButton:GetItemData().slotkey, section)
end

---@param view View
---@param slotkey string
local function UpdateButton(view, slotkey)
  local itemButton = view:GetOrCreateItemButton(slotkey)
  itemButton:UpdateCount()
end

-- UpdateDeletedSlot updates the slot key of a deleted slot, while maintaining the
-- button position and section to prevent a sort from happening.
---@param view View
---@param oldSlotKey string
---@param newSlotKey string
local function UpdateDeletedSlot(view, oldSlotKey, newSlotKey)
  local oldSlotCell = view.itemsByBagAndSlot[oldSlotKey]
  local oldSlotSection = view:GetSlotSection(oldSlotKey)
  oldSlotSection:RekeyCell(oldSlotKey, newSlotKey)
  oldSlotCell:SetItem(newSlotKey)
  view.itemsByBagAndSlot[newSlotKey] = oldSlotCell
  view.itemsByBagAndSlot[oldSlotKey] = nil
  view:SetSlotSection(newSlotKey, oldSlotSection)
  view:RemoveSlotSection(oldSlotKey)
end

--local function ReindexSlot(view, oldSlotKey, newSlotKey)
--  local cell = view.itemsByBagAndSlot[oldSlotKey] --[[@as Item]]
--  local data = cell:GetItemData()
--  if newSlotKey then
--    local oldSection = view:GetSlotSection(oldSlotKey)
--    local newSection = view:GetSlotSection(newSlotKey)
--    if newSection == nil then
--      newSection = view:GetOrCreateSection(data.itemInfo.category)
--    end
--    if oldSection == newSection then
--      oldSection:RekeyCell(oldSlotKey, newSlotKey)
--    else
--      oldSection:RemoveCell(oldSlotKey)
--      newSection:AddCell(newSlotKey, cell)
--      view:RemoveSlotSection(oldSlotKey)
--    end
--    cell:SetItem(newSlotKey)
--  else
--    if data and not data.isItemEmpty then
--      local slotKeyCat = view:GetSlotSection(oldSlotKey).title:GetText()
--      local dataCat = data.itemInfo.category
--      if slotKeyCat ~= dataCat then
--        local oldSection = view:GetSlotSection(oldSlotKey)
--        local newSection = view:GetOrCreateSection(dataCat)
--        oldSection:RemoveCell(oldSlotKey)
--        newSection:AddCell(oldSlotKey, cell)
--        view:RemoveSlotSection(oldSlotKey)
--        view:SetSlotSection(oldSlotKey, newSection)
--      end
--    else
--      local bagid, slotid = view:ParseSlotKey(oldSlotKey)
--      cell:SetFreeSlots(bagid, slotid, -1, "Recently Deleted")
--      view:AddDeferredItem(oldSlotKey)
--      view:RemoveSlotSection(oldSlotKey)
--      addon:GetBagFromBagID(bagid).drawOnClose = true
--    end
--    -- TODO(lobato): Add deferred sections 
--  end
--end
--local stacks = {}

---@param view View
---@param bag Bag
---@param slotInfo SlotInfo
local function GridView(view, bag, slotInfo)
  if view.fullRefresh then
    view:Wipe()
    view.fullRefresh = false
  end
  local sizeInfo = database:GetBagSizeInfo(bag.kind, database:GetBagView(bag.kind))
  view.content.compactStyle = database:GetBagCompaction(bag.kind)

  local added, removed, changed, swapped = slotInfo:GetChangeset()

  for _, item in pairs(removed) do
    local newSlotKey = view:RemoveButton(item)

    -- Clear if the item is empty, otherwise reindex it as a new item has taken it's
    -- place due to the deleted being the head of a stack.
    if not newSlotKey then
      ClearButton(view, item)
    else
      UpdateDeletedSlot(view, item.slotkey, newSlotKey)
    end
  end

  for _, item in pairs(added) do
    local updateKey = view:AddButton(item)
    if not updateKey then
      CreateButton(view, item)
    else
      UpdateButton(view, updateKey)
    end
  end

  for _, swapset in pairs(swapped) do
    -- If swapset.a is set but not b, this means the item
    -- hash changed, i.e. it was enchanted or similar.
    if swapset.a and not swapset.b then
      local data = items:GetItemDataFromSlotKey(swapset.a)
      local stack = view:GetStack(data.itemHash)

    end
    print("swapped", swapset.a, swapset.b)
  end

  for _, item in pairs(changed) do
    UpdateButton(view, view:ChangeButton(item))
  end

  if not slotInfo.deferDelete then
    for slotkey, _ in pairs(view:GetDeferredItems()) do
      local section = view:GetSlotSection(slotkey)
      section:RemoveCell(slotkey)
      view.itemsByBagAndSlot[slotkey]:Wipe()
    end
    view:ClearDeferredItems()
  end

  debug:StartProfile('Section Draw Stage')
  for sectionName, section in pairs(view:GetAllSections()) do
      -- Remove the section if it's empty, otherwise draw it.
    if not slotInfo.deferDelete then
      if section:GetCellCount() == 0 then
        debug:Log("RemoveSection", "Removed because empty", sectionName)
        view:RemoveSection(sectionName)
        section:ReleaseAllCells()
        section:Release()
      else
        debug:Log("KeepSection", "Section kept because not empty", sectionName)
        section:SetMaxCellWidth(sizeInfo.itemsPerRow)
        section:Draw(bag.kind, database:GetBagView(bag.kind), false)
      end
    end
  end
  debug:EndProfile('Section Draw Stage')

  -- Get the free slots section and add the free slots to it.
  local freeSlotsSection = view:GetOrCreateSection(L:G("Free Space"))
  for name, freeSlotCount in pairs(slotInfo.emptySlots) do
    if slotInfo.freeSlotKeys[name] ~= nil then
      local itemButton = view.itemsByBagAndSlot[name]
      if itemButton == nil then
        itemButton = itemFrame:Create()
        view.itemsByBagAndSlot[name] = itemButton
      end
      local freeSlotBag, freeSlotID = view:ParseSlotKey(slotInfo.freeSlotKeys[name])
      itemButton:SetFreeSlots(freeSlotBag, freeSlotID, freeSlotCount, name)
      freeSlotsSection:AddCell(name, itemButton)
    end
  end

  freeSlotsSection:SetMaxCellWidth(2)
  freeSlotsSection:Draw(bag.kind, database:GetBagView(bag.kind), false)
  view.content.maxCellWidth = sizeInfo.columnCount
  -- Sort the sections.
  view.content:Sort(sort:GetSectionSortFunction(bag.kind, const.BAG_VIEW.SECTION_GRID))

  if not slotInfo.deferDelete then
    debug:StartProfile('Content Draw Stage')
    local w, h = view.content:Draw()
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
  view.content:GetContainer():ClearAllPoints()
  view.content:GetContainer():SetPoint("TOPLEFT", parent, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET, const.OFFSETS.BAG_TOP_INSET)
  view.content:GetContainer():SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", const.OFFSETS.BAG_RIGHT_INSET, const.OFFSETS.BAG_BOTTOM_INSET + const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET + 20)
  view.content.compactStyle = const.GRID_COMPACT_STYLE.NONE
  view.content:Hide()
  view.Render = GridView
  view.WipeHandler = Wipe
  return view
end
