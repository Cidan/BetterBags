---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class ItemRowFrame: AceModule
local itemRowFrame = addon:GetModule('ItemRowFrame')

---@class Sort: AceModule
local sort = addon:GetModule('Sort')

---@class GridFrame: AceModule
local grid = addon:GetModule('Grid')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Views: AceModule
local views = addon:GetModule('Views')

---@param view View
local function Wipe(view)
  view.content:Wipe()
  view.freeSlot = nil
  view.freeReagentSlot = nil
  for _, section in pairs(view.sections) do
    section:ReleaseAllCells()
    section:Release()
  end
  wipe(view.sections)
  wipe(view.itemsByBagAndSlot)
end

-- DeleteButton deletes a button entirely from the frame and releases it.
---@param view View
---@param item ItemData
local function DeleteButton(view, item)
  local section = view:GetSlotSection(item.slotkey)
  section:RemoveCell(item.slotkey)
  view.itemsByBagAndSlot[item.slotkey]:Wipe()
  view:RemoveDeferredItem(item.slotkey)
  view:RemoveSlotSection(item.slotkey)
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
  local itemButton = view:GetOrCreateItemButton(item.slotkey, function() return itemRowFrame:Create() end)
  itemButton:SetItem(item.slotkey)
  local section = view:GetOrCreateSection(item.itemInfo.category)
  section:AddCell(itemButton:GetItemData().slotkey, itemButton)
  view:SetSlotSection(itemButton:GetItemData().slotkey, section)
end

---@param ctx Context
---@param view View
---@param slotkey string
local function UpdateButton(ctx, view, slotkey)
  view:RemoveDeferredItem(slotkey)
  local itemButton = view:GetOrCreateItemButton(slotkey, function() return itemRowFrame:Create() end)
  itemButton:SetItem(slotkey)
  if ctx:GetBool('wipe') == false and database:GetShowNewItemFlash(view.kind) then
    view:FlashStack(slotkey)
  end
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

--TODO(lobato): Move the -35 below to constants.

---@param view View
---@param bag Bag
local function UpdateListSize(view, bag)
  local w, _ = bag.frame:GetSize()
  for _, section in pairs(view:GetAllSections()) do
    section.frame:SetWidth(w - 18)
    for _, cell in pairs(section:GetAllCells()) do
      cell.frame:SetWidth(w - 18)
    end
  end
end

---@param view View
---@param ctx Context
---@param bag Bag
---@param slotInfo SlotInfo
local function ListView(view, ctx, bag, slotInfo)
  if ctx:GetBool('wipe') then
    view:Wipe()
  end
  view.content.compactStyle = const.GRID_COMPACT_STYLE.NONE

  local added, removed, changed = slotInfo:GetChangeset()

  for _, item in pairs(removed) do
    local newSlotKey = view:RemoveButton(item)

    -- Clear if the item is empty, otherwise reindex it as a new item has taken it's
    -- place due to the deleted being the head of a stack.
    if not newSlotKey then
      DeleteButton(view, item)
    else
      UpdateDeletedSlot(view, item.slotkey, newSlotKey)
    end
  end

  for _, item in pairs(added) do
    local updateKey = view:AddButton(item)
    if not updateKey then
      CreateButton(view, item)
    else
      UpdateButton(ctx, view, updateKey)
    end
  end

  for _, item in pairs(changed) do
    UpdateButton(ctx, view, view:ChangeButton(item))
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

  for sectionName, section in pairs(view:GetAllSections()) do
    for slotkey, _ in pairs(section:GetAllCells()) do
      local data = view.itemsByBagAndSlot[slotkey]:GetItemData()
      if data.isItemEmpty or data.stackedOn ~= nil then
        section:RemoveCell(slotkey)
        view.itemsByBagAndSlot[slotkey]:Wipe()
      elseif data.itemInfo.category ~= sectionName then
        section:RemoveCell(slotkey)
      end
    end
    if section:GetCellCount() == 0 then
      view:RemoveSection(sectionName)
      section:ReleaseAllCells()
      section:Release()
    else
      section:SetMaxCellWidth(1)
      section:Draw(bag.kind, database:GetBagView(bag.kind), bag.slots:IsShown())
    end
  end

  view.content.maxCellWidth = 1
  view.content:Sort(sort:GetSectionSortFunction(bag.kind, const.BAG_VIEW.LIST))
  local w, h = view.content:Draw({
    cells = view.content.cells,
    maxWidthPerRow = 1,
  })

  if w < 160 then
  w = 160
  end
  if bag.tabs and w < bag.tabs.width then
    w = bag.tabs.width
  end
  if h == 0 then
  h = 40
  end
  view.content:ShowScrollBar()

  bag.frame:SetSize(database:GetBagViewFrameSize(bag.kind, database:GetBagView(bag.kind)))
  view.content:GetContainer():FullUpdate()
end

---@param parent Frame
---@param kind BagKind
---@return View
function views:NewList(parent, kind)
  local view = views:NewBlankView()
  view.itemCount = 0
  view.bagview = const.BAG_VIEW.LIST
  view.kind = kind
  view.content = grid:Create(parent)
  view.content:GetContainer():ClearAllPoints()
  view.content:GetContainer():SetPoint("TOPLEFT", parent, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET, const.OFFSETS.BAG_TOP_INSET)
  view.content:GetContainer():SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", const.OFFSETS.BAG_RIGHT_INSET, const.OFFSETS.BAG_BOTTOM_INSET + const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET + 20)
  view.content.compactStyle = const.GRID_COMPACT_STYLE.NONE
  view.content:Hide()
  view.Render = ListView
  view.WipeHandler = Wipe
  view.UpdateListSize = UpdateListSize
  return view
end