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

---@param view view
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

---@param view view
---@param data ItemData
---@return boolean
local function drawDirtyItemUnstacked(view, data)
  local categoryChanged = false
  local bagid = data.bagid

  -- Don't draw keys at all.
  if bagid == Enum.BagIndex.Keyring then
    return false
  end

  local slotkey = view:GetSlotKey(data)
  -- Create or get the item frame for this slot.
  local itemButton = view.itemsByBagAndSlot[slotkey] --[[@as Item]]
  if itemButton == nil then
    itemButton = itemFrame:Create()
    view.itemsByBagAndSlot[slotkey] = itemButton
  end

  -- Set the item data on the item frame.
  itemButton:SetItem(data)

  -- Add the item to the correct category section, skipping the keyring unless we're showing bag slots.
  if (not data.isItemEmpty) then
    local section = view:GetOrCreateSection(data.itemInfo.category)
    section:AddCell(slotkey, itemButton)
  end
  return categoryChanged
end

--local stacks = {}

---@param view view
---@param bag Bag
---@param slotInfo SlotInfo
local function GridView(view, bag, slotInfo)
  if view.fullRefresh then
    view:Wipe()
    view.fullRefresh = false
  end
  local dirtyItems = slotInfo.dirtyItems
  local sizeInfo = database:GetBagSizeInfo(bag.kind, database:GetBagView(bag.kind))
  local categoryChanged = false
  view.content.compactStyle = database:GetBagCompaction(bag.kind)

  debug:Log("Draw", "Rendering grid view for bag", bag.kind, "with", #dirtyItems, "dirty items")
  debug:StartProfile('Dirty Item Stage')
  for _, data in pairs(dirtyItems) do
    if data.stackedOn == nil or data.isItemEmpty then
      debug:Log("Draw", "Drawing dirty item", data.itemInfo and data.itemInfo.itemLink or nil, "in bag", data.bagid, "slot", data.slotid)
      local change = drawDirtyItemUnstacked(view, data)
      if categoryChanged == false and change == true then
        categoryChanged = true
      end
    end
  end
  debug:EndProfile('Dirty Item Stage')

  view.defer = slotInfo.deferDelete

  debug:StartProfile('Reconcile Stage')
  -- Loop through all sections and reconcile the items.
  for sectionName, section in pairs(view:GetAllSections()) do
    local allCells = section:GetKeys()
    for _, slotkey in pairs(allCells) do
      local button = view.itemsByBagAndSlot[slotkey]
      local data = button and button.data or nil
      if button == nil then
        debug:Log("RemoveCell", "Removed because not in itemsByBagAndSlot", slotkey)
        section:RemoveCell(slotkey)
      else
        -- Remove item buttons that are empty or don't match the category.
        if data.isItemEmpty or data.stackedOn ~= nil then
          if view.defer and not data.forceClear then
            debug:Log("RemoveCell", "Removed because empty (defer)", slotkey, data.itemInfo.itemLink)
            view.itemsByBagAndSlot[slotkey]:SetFreeSlots(data.bagid, data.slotid, -1, "Recently Deleted")
            bag.drawOnClose = true
          elseif view.defer and data.forceClear then
            local nextStack = slotInfo.itemsBySlotKey[data.nextStack]
            if nextStack ~= nil then
              debug:Log("SwapCell", "Swapped because empty (defer)", slotkey, data.itemInfo.itemLink, data.nextStack, nextStack.itemInfo.itemLink)
              view.itemsByBagAndSlot[slotkey] = nil
              section:RemoveCell(data.nextStack)
              section:RemoveCell(slotkey)
              view.itemsByBagAndSlot[data.nextStack]:Release()
              view.itemsByBagAndSlot[data.nextStack] = button
              button:SetItem(nextStack)
              section:AddCell(data.nextStack, button)
            end
            bag.drawOnClose = true
          else
            debug:Log("RemoveCell", "Removed because empty", slotkey, data.forceClear, data.itemInfo.itemLink)
            section:RemoveCell(slotkey)
            view.itemsByBagAndSlot[slotkey]:Release()
            view.itemsByBagAndSlot[slotkey] = nil
            bag.drawOnClose = false
          end
        elseif data.itemInfo.category ~= sectionName then
          if view.defer then
            if sectionName ~= L:G("Recent Items") then
              debug:Log("RemoveCell", "Removed mismatch (defer)", slotkey, data.itemInfo.itemLink, data.itemInfo.category, "->", sectionName)
              view.itemsByBagAndSlot[slotkey]:SetFreeSlots(data.bagid, data.slotid, -1, "Recently Deleted")
            end
            bag.drawOnClose = true
          else
            debug:Log("RemoveCell", "Removed mismatch", slotkey, data.itemInfo.itemLink, data.itemInfo.category, "->", sectionName)
            section:RemoveCell(slotkey)
            bag.drawOnClose = false
          end
        end
      end
    end
  end
  debug:EndProfile('Reconcile Stage')

  debug:StartProfile("Stacking Stage")
  for _, item in pairs(view.itemsByBagAndSlot) do
    item:UpdateCount()
  end
  debug:EndProfile("Stacking Stage")

  debug:StartProfile('Section Draw Stage')
  for sectionName, section in pairs(view:GetAllSections()) do
      -- Remove the section if it's empty, otherwise draw it.
    if not view.defer then
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

  if not view.defer then
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
---@return view
function views:NewGrid(parent)
  local view = setmetatable({}, {__index = views.viewProto})
  view.sections = {}
  view.itemsByBagAndSlot = {}
  view.itemCount = 0
  view.kind = const.BAG_VIEW.SECTION_GRID
  view.content = grid:Create(parent)
  view.content:GetContainer():ClearAllPoints()
  view.content:GetContainer():SetPoint("TOPLEFT", parent, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET, const.OFFSETS.BAG_TOP_INSET)
  view.content:GetContainer():SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", const.OFFSETS.BAG_RIGHT_INSET, const.OFFSETS.BAG_BOTTOM_INSET + const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET + 20)
  view.content.compactStyle = const.GRID_COMPACT_STYLE.NONE
  view.content:Hide()
  view.Render = GridView
  view.Wipe = Wipe
  return view
end
