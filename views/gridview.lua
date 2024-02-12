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
  view.content:Wipe()
  wipe(view.sections)
  wipe(view.itemsByBagAndSlot)
end

---@param view view
---@param bag Bag
---@param dirtyItems ItemData[]
local function GridView(view, bag, dirtyItems)
  local sizeInfo = database:GetBagSizeInfo(bag.kind, database:GetBagView(bag.kind))
  local freeSlotsData = {count = 0, bagid = 0, slotid = 0}
  local freeReagentSlotsData = {count = 0, bagid = 0, slotid = 0}
  local itemCount = 0
  view.content.compactStyle = database:GetBagCompaction(bag.kind)
  --view.content:Clear()
  for _, data in pairs(dirtyItems) do
    local bagid, slotid = data.bagid, data.slotid
    local slotkey = view:GetSlotKey(data)

    -- Capture information about free slots.
    if data.isItemEmpty then
      if bagid == Enum.BagIndex.ReagentBag then
        freeReagentSlotsData.count = freeReagentSlotsData.count + 1
        freeReagentSlotsData.bagid = bagid
        freeReagentSlotsData.slotid = slotid
      elseif bagid ~= Enum.BagIndex.Keyring then
        freeSlotsData.count = freeSlotsData.count + 1
        freeSlotsData.bagid = bagid
        freeSlotsData.slotid = slotid
      end
    else
      itemCount = itemCount + 1
    end

    -- Create or get the item frame for this slot.
    local itemButton = view.itemsByBagAndSlot[slotkey] --[[@as Item]]
    if itemButton == nil then
      itemButton = itemFrame:Create()
      itemButton:AddToMasqueGroup(bag.kind)
      view.itemsByBagAndSlot[slotkey] = itemButton
    end

    -- Set the item data on the item frame.
    itemButton:SetItem(data)

    -- Add the item to the correct category section.
    if not data.isItemEmpty then
      local category = itemButton:GetCategory()
      local section = view:GetOrCreateSection(category)
      section:AddCell(slotkey, itemButton)
    end
  end

  -- Loop through all sections and reconcile the items.
  for sectionName, section in pairs(view:GetAllSections()) do
    for slotkey, itemButton in pairs(section:GetAllCells()) do
      if slotkey ~= 'freeSlot' and slotkey ~= 'freeReagentSlot' then
        -- Get the bag and slot id from the slotkey.
        local data = view.itemsByBagAndSlot[slotkey].data
        -- Remove item buttons that are empty or don't match the category.
        if data.isItemEmpty  then
          section:RemoveCell(slotkey)
          itemButton:Wipe()
        elseif data.itemInfo.category ~= sectionName then
          section:RemoveCell(slotkey)
        end
      end
    end
    -- Remove the section if it's empty, otherwise draw it.
    if section:GetCellCount() == 0 then
      view:RemoveSection(sectionName)
      section:Release()
    else
      section:SetMaxCellWidth(sizeInfo.itemsPerRow)
      section:Draw(bag.kind, database:GetBagView(bag.kind))
    end
  end

  local freeSlotsSection = view:GetOrCreateSection(L:G("Free Space"))
  view.freeSlot:SetFreeSlots(freeSlotsData.bagid, freeSlotsData.slotid, freeSlotsData.count, false)
  freeSlotsSection:AddCell('freeSlot', view.freeSlot)

  if bag.kind == const.BAG_KIND.BACKPACK then
    view.freeReagentSlot:SetFreeSlots(freeReagentSlotsData.bagid, freeReagentSlotsData.slotid, freeReagentSlotsData.count, true)
    freeSlotsSection:AddCell('freeReagentSlot', view.freeReagentSlot)
  end

  freeSlotsSection:SetMaxCellWidth(2)
  freeSlotsSection:Draw(bag.kind, database:GetBagView(bag.kind))

  view.content.maxCellWidth = sizeInfo.columnCount
  -- Sort the sections.
  view.content:Sort(sort:GetSectionSortFunction(bag.kind, const.BAG_VIEW.SECTION_GRID))

  -- Position all sections and draw the main bag.
  local w, h = view.content:Draw()
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
  view.content:Show()
end

---@param parent Frame
---@return view
function views:NewGrid(parent)
  local view = setmetatable({}, {__index = views.viewProto})
  view.sections = {}
  view.itemsByBagAndSlot = {}
  view.freeSlot = itemFrame:Create()
  view.freeReagentSlot = itemFrame:Create()
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
