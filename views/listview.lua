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

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Views: AceModule
local views = addon:GetModule('Views')

--TODO(lobato): Move the -35 below to constants.

---@param bag Bag
function views:UpdateListSize(bag)
  local w, _ = bag.frame:GetSize()
  for _, section in pairs(bag:GetAllSections()) do
    section.frame:SetWidth(w - 35)
    for _, cell in pairs(section:GetAllCells()) do
      cell.frame:SetWidth(w - 35)
    end
  end
  bag.recentItems.frame:SetWidth(w - 35)
  for _, cell in pairs(bag.recentItems:GetAllCells()) do
    cell.frame:SetWidth(w - 35)
  end
end

---@param bag Bag
---@param dirtyItems ItemData[]
function views:ListView(bag, dirtyItems)
  local sizeInfo = database:GetBagSizeInfo(bag.kind, database:GetBagView(bag.kind))
  bag:WipeFreeSlots()
  local freeSlotsData = {count = 0, bagid = 0, slotid = 0}
  local freeReagentSlotsData = {count = 0, bagid = 0, slotid = 0}
  bag.content.compactStyle = database:GetBagCompaction(bag.kind)
  for _, data in pairs(dirtyItems) do
    local bagid, slotid = data.bagid, data.slotid
    bag.itemsByBagAndSlot[bagid] = bag.itemsByBagAndSlot[bagid] or {}

    -- Capture information about free slots.
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

    local oldFrame = bag.itemsByBagAndSlot[bagid][slotid] --[[@as ItemRow]]
    -- The old frame does not exist, so we need to create a new one.
    if oldFrame == nil and not data.isItemEmpty then
      local newFrame = itemRowFrame:Create()
      newFrame.rowButton:SetScript("OnMouseWheel", function(_, delta)
        bag.content:GetContainer():OnMouseWheel(delta)
      end)
      newFrame:SetItem(data)
      local category = newFrame:GetCategory()
      local section ---@type Section|nil
      section = bag:GetOrCreateSection(category)

      section:GetContent():GetContainer():SetScript("OnMouseWheel", function(_, delta)
        bag.content:GetContainer():OnMouseWheel(delta)
      end)
      section:AddCell(data.itemInfo.itemGUID, newFrame)
      newFrame:AddToMasqueGroup(bag.kind)
      bag.itemsByBagAndSlot[bagid][slotid] = newFrame
    elseif oldFrame ~= nil and not data.isItemEmpty and oldFrame.data.itemInfo.itemGUID ~= data.itemInfo.itemGUID then
      -- This case handles the situation where the item in this slot no longer matches the item displayed.
      -- The old frame exists, so we need to update it.
      local oldCategory = oldFrame.data.itemInfo.category
      local oldSection = bag:GetSection(oldCategory)
      local oldGuid = oldFrame:GetGUID()
      oldFrame:SetItem(data)
      local newCategory = oldFrame:GetCategory()
      local newSection = bag:GetOrCreateSection(newCategory)

      if oldCategory ~= newCategory then
        oldSection:RemoveCell(oldGuid, oldFrame)
        newSection:AddCell(oldFrame:GetGUID(), oldFrame)
      end
      if oldSection == bag.recentItems then
      elseif oldSection:GetCellCount() == 0 then
        bag:RemoveSection(oldCategory)
        bag.content:RemoveCell(oldCategory, oldSection)
        oldSection:Release()
      end
    elseif oldFrame ~= nil and not data.isItemEmpty and oldFrame:GetGUID() == data.itemInfo.itemGUID then
      -- This case handles when the item in this slot is the same as the item displayed.
      local oldCategory = oldFrame.data.itemInfo.category
      local oldSection = bag:GetOrCreateSection(oldCategory)
      local oldGuid = oldFrame.data.itemInfo.itemGUID
      oldFrame:SetItem(data)
      local newCategory = oldFrame:GetCategory()
      local newSection = bag:GetOrCreateSection(newCategory)
      if oldCategory ~= newCategory then
        oldSection:RemoveCell(oldGuid, oldFrame)
        newSection:AddCell(oldFrame.data.itemInfo.itemGUID, oldFrame)
      end
      if oldSection == bag.recentItems then
      elseif oldSection:GetCellCount() == 0 then
        bag:RemoveSection(oldCategory)
        bag.content:RemoveCell(oldCategory, oldSection)
        oldSection:Release()
      end
    elseif data.isItemEmpty and oldFrame ~= nil then
      -- The old frame exists, but the item is empty, so we need to delete it.
      bag.itemsByBagAndSlot[bagid][slotid] = nil
      local section = bag:GetOrCreateSection(oldFrame:GetCategory())
      section:RemoveCell(oldFrame:GetGUID(), oldFrame)
      -- Delete the section if it's empty as well.
      if section == bag.recentItems then
      elseif section:GetCellCount() == 0 then
        bag:RemoveSection(oldFrame:GetCategory())
        bag.content:RemoveCell(oldFrame:GetCategory(), section)
        section:Release()
      end
      oldFrame:Release()
    end
  end

  bag.freeSlots:AddCell("freeBagSlots", bag.freeBagSlotsButton)
  if bag.freeReagentBagSlotsButton then
    bag.freeSlots:AddCell("freeReagentBagSlots", bag.freeReagentBagSlotsButton)
  end
  bag.freeBagSlotsButton:SetFreeSlots(freeSlotsData.bagid, freeSlotsData.slotid, freeSlotsData.count, false)
  if bag.freeReagentBagSlotsButton then
    bag.freeReagentBagSlotsButton:SetFreeSlots(freeReagentSlotsData.bagid, freeReagentSlotsData.slotid, freeReagentSlotsData.count, true)
  end
  bag.recentItems:SetMaxCellWidth(1)
  -- Loop through each section and draw it's size.
  for _, section in pairs(bag:GetAllSections()) do
    section:SetMaxCellWidth(1)
    section:Draw(bag.kind, database:GetBagView(bag.kind))
  end
  bag.recentItems:Draw(bag.kind, database:GetBagView(bag.kind))
  bag.freeSlots:SetMaxCellWidth(sizeInfo.itemsPerRow)
  bag.freeSlots:Draw(bag.kind, database:GetBagView(bag.kind))

  -- Remove the freeSlots section.
  bag.content:RemoveCell(bag.freeSlots.title:GetText(), bag.freeSlots)

  -- Sort all sections by title.
  bag.content:Sort(sort:GetSectionSortFunction(bag.kind, const.BAG_VIEW.LIST))
  bag.content.maxCellWidth = 1
  -- Add the freeSlots section back to the end of all sections
  --bag.content:AddCellToLastColumn(bag.freeSlots.title:GetText(), bag.freeSlots)
  bag.freeSlots.frame:Hide()
  -- Position all sections and draw the main bag.
  local w, h = bag.content:Draw()
  -- Reposition the content frame if the recent items section is empty.

  if w < 160 then
    w = 160
  end
  if h == 0 then
    h = 40
  end
  bag.content:ShowScrollBar()

  bag.frame:SetSize(database:GetBagViewFrameSize(bag.kind, database:GetBagView(bag.kind)))
  bag.content:GetContainer():FullUpdate()
end
