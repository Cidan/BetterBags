local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class ItemFrame: AceModule
local itemFrame = addon:GetModule('ItemFrame')

---@class Views: AceModule
local views = addon:GetModule('Views')

---@param a Item
---@param b Item
---@return boolean
local function SortView (a, b)
  if a == nil or b == nil or a.data == nil or b.data == nil then return false end
  if a.data.itemInfo.itemQuality == nil or b.data.itemInfo.itemQuality == nil then return false end
  if a.data.itemInfo.itemQuality == b.data.itemInfo.itemQuality then
    if a.data.itemInfo.itemName == nil or b.data.itemInfo.itemName == nil then return false end
    return a.data.itemInfo.itemName < b.data.itemInfo.itemName
  end
  return a.data.itemInfo.itemQuality > b.data.itemInfo.itemQuality
end

---@param bag Bag
---@param dirtyItems ItemData[]
function views:OneBagView(bag, dirtyItems)
  bag:WipeFreeSlots()
  local freeSlotsData = {count = 0, bagid = 0, slotid = 0}
  local freeReagentSlotsData = {count = 0, bagid = 0, slotid = 0}
  bag.content.compactStyle = const.GRID_COMPACT_STYLE.NONE
  for _, data in pairs(dirtyItems) do
    local bagid, slotid = data.bagid, data.slotid
    bag.itemsByBagAndSlot[bagid] = bag.itemsByBagAndSlot[bagid] or {}
    if data.isItemEmpty then
      if bagid == Enum.BagIndex.ReagentBag then
        freeReagentSlotsData.count = freeReagentSlotsData.count + 1
        freeReagentSlotsData.bagid = bagid
        freeReagentSlotsData.slotid = slotid
      else
        freeSlotsData.count = freeSlotsData.count + 1
        freeSlotsData.bagid = bagid
        freeSlotsData.slotid = slotid
      end
    end

    local oldFrame = bag.itemsByBagAndSlot[bagid][slotid] --[[@as Item]]

    -- The old frame does not exist, so we need to create a new one.
    if oldFrame == nil and not data.isItemEmpty then
      local newFrame = itemFrame:Create()
      newFrame:SetItem(data)
      newFrame:AddToMasqueGroup(bag.kind)
      bag.content:AddCell(data.itemInfo.itemGUID, newFrame)
      bag.itemsByBagAndSlot[bagid][slotid] = newFrame
    elseif oldFrame ~= nil and not data.isItemEmpty then
      -- The old frame exists, so we need to update it.
      oldFrame:SetItem(data)
    elseif data.isItemEmpty and oldFrame ~= nil then
      -- The old frame exists, but the item is empty, so we need to delete it.
      bag.itemsByBagAndSlot[bagid][slotid] = nil
      bag.content:RemoveCell(oldFrame.data.itemInfo.itemGUID, oldFrame)
      oldFrame:Release()
    end
  end

  bag.content:Sort(SortView)

  bag.content:AddCell("freeBagSlots", bag.freeBagSlotsButton)
  bag.content:AddCell("freeReagentBagSlots", bag.freeReagentBagSlotsButton)
  bag.freeBagSlotsButton:SetFreeSlots(freeSlotsData.bagid, freeSlotsData.slotid, freeSlotsData.count, false)
  bag.freeReagentBagSlotsButton:SetFreeSlots(freeReagentSlotsData.bagid, freeReagentSlotsData.slotid, freeReagentSlotsData.count, true)
  -- Redraw the world.
  local w, h = bag.content:Draw()
  bag.content:HideScrollBar()
  bag.frame:SetWidth(w + 12)
  local bagHeight = h +
  const.OFFSETS.BAG_BOTTOM_INSET + -const.OFFSETS.BAG_TOP_INSET +
  const.OFFSETS.BOTTOM_BAR_HEIGHT + const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET
  bag.frame:SetHeight(bagHeight)
end