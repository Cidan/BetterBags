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

---@class Sort: AceModule
local sort = addon:GetModule('Sort')

---@class GridFrame: AceModule
local grid = addon:GetModule('Grid')

---@class Debug : AceModule
local debug = addon:GetModule('Debug')

---@class Views: AceModule
local views = addon:GetModule('Views')

---@param view view
local function Wipe(view)
  view.content:Wipe()
  if view.freeSlot ~= nil then
    view.freeSlot:Release()
    view.freeSlot = nil
  end
  if view.freeReagentSlot ~= nil then
    view.freeReagentSlot:Release()
    view.freeReagentSlot = nil
  end
  for _, item in pairs(view.itemsByBagAndSlot) do
    item:Release()
  end
  wipe(view.itemsByBagAndSlot)
end

---@param view view
---@param bag Bag
---@param slotInfo ExtraSlotInfo
local function OneBagView(view, bag, slotInfo)
  if view.fullRefresh then
    view:Wipe()
    view.fullRefresh = false
  end
  local sizeInfo = database:GetBagSizeInfo(bag.kind, database:GetBagView(bag.kind))
  local dirtyItems = slotInfo.dirtyItems

  view.content.compactStyle = const.GRID_COMPACT_STYLE.NONE

  for _, data in pairs(dirtyItems) do
      if data.stackedOn == nil or data.isItemEmpty then
      local slotkey = view:GetSlotKey(data)

      -- Create or get the item frame for this slot.
      local itemButton = view.itemsByBagAndSlot[slotkey] --[[@as Item]]
      if itemButton == nil then
        itemButton = itemFrame:Create()
        --debug:DrawBorder(itemButton.frame, 1, 1, 0)
        view.itemsByBagAndSlot[slotkey] = itemButton
      end

      -- Set the item data on the item frame.
      itemButton:SetItem(data)
      view.content:AddCell(slotkey, itemButton)
    end
  end

  for slotkey, _ in pairs(view.content:GetAllCells()) do
    local data = view.itemsByBagAndSlot[slotkey].data
    if data.isItemEmpty or data.stackedOn ~= nil then
      view.content:RemoveCell(slotkey)
      view.itemsByBagAndSlot[slotkey]:Wipe()
    end
  end

  for _, item in pairs(view.itemsByBagAndSlot) do
    item:UpdateCount()
  end

  -- Get the free slots section and add the free slots to it.
  for name, freeSlotCount in pairs(slotInfo.emptySlots) do
    local itemButton = view.itemsByBagAndSlot[name]
    if itemButton == nil then
      itemButton = itemFrame:Create()
      view.itemsByBagAndSlot[name] = itemButton
    end
    local freeSlotBag, freeSlotID = view:ParseSlotKey(slotInfo.freeSlotKeys[name])
    itemButton:SetFreeSlots(freeSlotBag, freeSlotID, freeSlotCount, name)
    view.content:AddCell(name, itemButton)
  end

  view.content.maxCellWidth = sizeInfo.columnCount
  -- Sort the items.
  view.content:Sort(sort:GetItemSortFunction(bag.kind, const.BAG_VIEW.ONE_BAG))
  local w, h = view.content:Draw()
  view.content:HideScrollBar()
  bag.frame:SetWidth(w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET)
  local bagHeight = h +
  const.OFFSETS.BAG_BOTTOM_INSET + -const.OFFSETS.BAG_TOP_INSET +
  const.OFFSETS.BOTTOM_BAR_HEIGHT + const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET
  bag.frame:SetHeight(bagHeight)
end

---@param parent Frame
---@return view
function views:NewOneBag(parent)
  local view = setmetatable({}, {__index = views.viewProto})
  view.itemsByBagAndSlot = {}
  view.kind = const.BAG_VIEW.ONE_BAG
  view.content = grid:Create(parent)
  view.content:GetContainer():ClearAllPoints()
  view.content:GetContainer():SetPoint("TOPLEFT", parent, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET, const.OFFSETS.BAG_TOP_INSET)
  view.content:GetContainer():SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", const.OFFSETS.BAG_RIGHT_INSET, const.OFFSETS.BAG_BOTTOM_INSET + const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET + 20)
  view.content.compactStyle = const.GRID_COMPACT_STYLE.NONE
  view.content:Hide()
  view.Render = OneBagView
  view.Wipe = Wipe
  return view
end