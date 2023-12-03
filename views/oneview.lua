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

---@param bag Bag
---@param dirtyItems table<number, table<number, ItemData>>
function views:OneBagView(bag, dirtyItems)
  bag:WipeFreeSlots()
  local freeSlotsData = {count = 0, bagid = 0, slotid = 0}
  local freeReagentSlotsData = {count = 0, bagid = 0, slotid = 0}
  bag.content.compactStyle = const.GRID_COMPACT_STYLE.NONE
  for bid, bagData in pairs(dirtyItems) do
    bag.itemsByBagAndSlot[bid] = bag.itemsByBagAndSlot[bid] or {}
    for sid, itemData in pairs(bagData) do
      local bagid, slotid = itemData:GetItemLocation():GetBagAndSlot()

      if itemData:IsItemEmpty() then
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
      if oldFrame == nil and not itemData:IsItemEmpty() then
        local newFrame = itemFrame:Create()
        newFrame:SetItem(itemData)
        newFrame:AddToMasqueGroup(bag.kind)
        bag.content:AddCell(itemData:GetItemGUID(), newFrame)
        bag.itemsByBagAndSlot[bagid][slotid] = newFrame
      elseif oldFrame ~= nil and not itemData:IsItemEmpty() then
        -- The old frame exists, so we need to update it.
        oldFrame:SetItem(itemData)
      elseif itemData:IsItemEmpty() and oldFrame ~= nil then
        -- The old frame exists, but the item is empty, so we need to delete it.
        bag.itemsByBagAndSlot[bid][sid] = nil
        bag.content:RemoveCell(oldFrame.guid, oldFrame)
        oldFrame:Release()
      end
    end
  end

  bag.content:Sort(function (a, b)
    ---@cast a +Item
    ---@cast b +Item
    if not a:GetMixin() or not b:GetMixin() then return false end
    if a:GetMixin():GetItemQuality() == nil or b:GetMixin():GetItemQuality() == nil then return false end
    if a:GetMixin():GetItemQuality() == b:GetMixin():GetItemQuality() then
      if a:GetMixin():GetItemName() == nil or b:GetMixin():GetItemName() == nil then return false end
      return a:GetMixin():GetItemName() < b:GetMixin():GetItemName()
    end
    return a:GetMixin():GetItemQuality() > b:GetMixin():GetItemQuality()
  end)

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