local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class GridFrame: AceModule
local grid = addon:GetModule('Grid')

---@class Views: AceModule
local views = addon:GetModule('Views')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Debug : AceModule
local debug = addon:GetModule('Debug')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class ItemFrame: AceModule
local itemFrame = addon:GetModule('ItemFrame')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Sort: AceModule
local sort = addon:GetModule('Sort')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@param view View
local function Wipe(view)
  view.content:Wipe()
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

---@param bagid number
---@return string
local function GetBagName(bagid)
  local isBackpack = const.BACKPACK_BAGS[bagid] ~= nil
  if isBackpack then
    local bagname = bagid == Enum.BagIndex.Keyring and L:G('Keyring') or C_Container.GetBagName(bagid)
    local displayid = bagid == Enum.BagIndex.Keyring and 6 or bagid+1
    return format("#%d: %s", displayid, bagname)
  end

    local id = bagid
    if id == -1 then
      return format("#%d: %s", 1, L:G('Bank'))
    elseif id == -3 then
      return format("#%d: %s", 1, L:G('Reagent Bank'))
    else
      return format("#%d: %s", id - 4, C_Container.GetBagName(id))
    end

end

---@param view View
---@param bag Bag
---@param slotInfo SlotInfo
local function BagView(view, bag, slotInfo)
  if view.fullRefresh then
    view:Wipe()
    view.fullRefresh = false
  end
  -- Use the section grid sizing for this view type.
  local sizeInfo = database:GetBagSizeInfo(bag.kind, const.BAG_VIEW.SECTION_GRID)

  local added, removed, changed = slotInfo:GetChangeset()

  for _, item in pairs(removed) do
    view:RemoveButton(item)
  end

  view:ProcessStacks()

  for _, item in pairs(added) do
    local itemButton = view:AddButton(item)
    if itemButton then
      local section = view:GetOrCreateSection(GetBagName(item.bagid))
      section:AddCell(itemButton:GetItemData().slotkey, itemButton)
    end
  end

  for _, item in pairs(changed) do
    view:ChangeButton(item)
  end

  view:ProcessStacks()
--  local dirtyItems = slotInfo.dirtyItems
--
--  for _, data in pairs(dirtyItems) do
--    local bagid = data.bagid
--    local slotkey = view:GetSlotKey(data)
--
--    -- Create or get the item frame for this slot.
--    local itemButton = view.itemsByBagAndSlot[slotkey] --[[@as Item]]
--    if itemButton == nil then
--      itemButton = itemFrame:Create()
--      view.itemsByBagAndSlot[slotkey] = itemButton
--    end
--
--    -- Set the item data on the item frame.
--    itemButton:SetItem(data)
--
--    -- Add the item to the correct category section, skipping the keyring unless we're showing bag slots.
--    if (not data.isItemEmpty) then
--      local section = view:GetOrCreateSection(GetBagName(bagid))
--      section:AddCell(slotkey, itemButton)
--    end
--  end

  for bagid, emptyBagData in pairs(slotInfo.emptySlotByBagAndSlot) do
    for slotid, data in pairs(emptyBagData) do
      local slotkey = view:GetSlotKey(data)
      if C_Container.GetBagName(bagid) ~= nil then
        local itemButton = view.itemsByBagAndSlot[slotkey] --[[@as Item]]
        if itemButton == nil then
          itemButton = itemFrame:Create()
          view.itemsByBagAndSlot[slotkey] = itemButton
        end
        itemButton:SetFreeSlots(bagid, slotid, -1, C_Container.GetBagName(bagid))
        local section = view:GetOrCreateSection(GetBagName(bagid))
        section:AddCell(slotkey, itemButton)
      end
    end
  end

  for _, item in pairs(view.itemsByBagAndSlot) do
    item:UpdateCount()
  end

  for sectionName, section in pairs(view:GetAllSections()) do
    if section:GetCellCount() == 0 then
      debug:Log("RemoveSection", "Removed because empty", sectionName)
      view:RemoveSection(sectionName)
      section:ReleaseAllCells()
      section:Release()
    else
      debug:Log("KeepSection", "Section kept because not empty", sectionName)
      section:SetMaxCellWidth(sizeInfo.itemsPerRow)
      section:Draw(bag.kind, database:GetBagView(bag.kind), true)
    end
  end
  view.content.maxCellWidth = sizeInfo.columnCount
  -- Sort the sections.
  view.content:Sort(sort:GetSectionSortFunction(bag.kind, const.BAG_VIEW.SECTION_GRID))
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

---@param parent Frame
---@param kind BagKind
---@return View
function views:NewBagView(parent, kind)
  local view = views:NewBlankView()
  view.itemFrames = {}
  view.itemCount = 0
  view.bagview = const.BAG_VIEW.SECTION_ALL_BAGS
  view.kind = kind
  view.content = grid:Create(parent)
  view.content:GetContainer():ClearAllPoints()
  view.content:GetContainer():SetPoint("TOPLEFT", parent, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET, const.OFFSETS.BAG_TOP_INSET)
  view.content:GetContainer():SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", const.OFFSETS.BAG_RIGHT_INSET, const.OFFSETS.BAG_BOTTOM_INSET + const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET + 20)
  view.content.compactStyle = const.GRID_COMPACT_STYLE.NONE
  view.content:Hide()
  view.Render = BagView
  view.Wipe = Wipe
  return view
end