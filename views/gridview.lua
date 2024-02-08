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

---@class Sort: AceModule
local sort = addon:GetModule('Sort')

---@param bag Bag
---@param dirtyItems ItemData[]
function views:GridView(bag, dirtyItems)
  local sizeInfo = database:GetBagSizeInfo(bag.kind, database:GetBagView(bag.kind))
  bag:WipeFreeSlots()
  local freeSlotsData = {count = 0, bagid = 0, slotid = 0}
  local freeReagentSlotsData = {count = 0, bagid = 0, slotid = 0}
  local itemCount = 0
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
    else
      itemCount = itemCount + 1
    end

    local oldFrame = bag.itemsByBagAndSlot[bagid][slotid] --[[@as Item]]
    -- The old frame does not exist, so we need to create a new one.
    if oldFrame == nil and not data.isItemEmpty then
      local newFrame = itemFrame:Create()
      newFrame:SetItem(data)
      local category = newFrame:GetCategory()
      local section ---@type Section|nil
      section = bag:GetOrCreateSection(category)

      section:AddCell(data.itemInfo.itemGUID, newFrame)
      newFrame:AddToMasqueGroup(bag.kind)
      bag.itemsByBagAndSlot[bagid][slotid] = newFrame
    elseif oldFrame ~= nil and not data.isItemEmpty and oldFrame.data.itemInfo.itemGUID ~= data.itemInfo.itemGUID then
      -- This case handles the situation where the item in this slot no longer matches the item displayed.
      -- The old frame exists, so we need to update it.
      local oldCategory = oldFrame.data.itemInfo.category
      local oldSection = bag:GetSection(oldCategory)
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
        table.insert(bag.toReleaseSections, oldSection)
      end
    elseif oldFrame ~= nil and not data.isItemEmpty and oldFrame.data.itemInfo.itemGUID == data.itemInfo.itemGUID then
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
        table.insert(bag.toReleaseSections, oldSection)
      end
    elseif data.isItemEmpty and oldFrame ~= nil then
      -- The old frame exists, but the item is empty, so we need to delete it.
      bag.itemsByBagAndSlot[bagid][slotid] = nil
      local section = bag:GetOrCreateSection(oldFrame:GetCategory())
      section:RemoveCell(oldFrame.data.itemInfo.itemGUID, oldFrame)
      -- Delete the section if it's empty as well.
      if section == bag.recentItems then
      elseif section:GetCellCount() == 0 then
        bag:RemoveSection(oldFrame:GetCategory())
        bag.content:RemoveCell(oldFrame:GetCategory(), section)
        table.insert(bag.toReleaseSections, section)
      end
      table.insert(bag.toRelease, oldFrame)
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
  bag.recentItems:SetMaxCellWidth(sizeInfo.itemsPerRow)
  -- Loop through each section and draw it's size.
  if bag.currentItemCount <= itemCount or bag.currentItemCount == -1 or bag.slots:IsShown() then
    for _, oldFrame in pairs(bag.toRelease) do
      oldFrame:Release()
    end
    for _, section in pairs(bag.toReleaseSections) do
      section:Release()
    end
    wipe(bag.toRelease)
    wipe(bag.toReleaseSections)
    for _, section in pairs(bag:GetAllSections()) do
      section:SetMaxCellWidth(sizeInfo.itemsPerRow)
      section:Draw(bag.kind, database:GetBagView(bag.kind))
    end
    bag.recentItems:Draw(bag.kind, database:GetBagView(bag.kind))
  else
    for _, oldFrame in pairs(bag.toRelease) do
      oldFrame:SetAlpha(0)
    end
    for _, section in pairs(bag.toReleaseSections) do
      section:SetAlpha(0)
    end
    bag.drawOnClose = true
  end
  bag.freeSlots:SetMaxCellWidth(sizeInfo.itemsPerRow)
  bag.freeSlots:Draw(bag.kind, database:GetBagView(bag.kind))

  -- Remove the freeSlots section.
  bag.content:RemoveCell(bag.freeSlots.title:GetText(), bag.freeSlots)

  bag.content:Sort(sort:GetSectionSortFunction(bag.kind, const.BAG_VIEW.SECTION_GRID))
  -- Add the freeSlots section back to the end of all sections
  bag.content:AddCellToLastColumn(bag.freeSlots.title:GetText(), bag.freeSlots)

  if bag.currentItemCount <= itemCount or bag.currentItemCount == -1 or bag.slots:IsShown() then
  -- Position all sections and draw the main bag.
    local w, h = bag.content:Draw()
    -- Reposition the content frame if the recent items section is empty.
    if w < 160 then
      w = 160
    end
    if h == 0 then
      h = 40
    end
    bag.content:HideScrollBar()
    --TODO(lobato): Implement SafeSetSize that prevents the window from being larger
    -- than the screen space.
    bag.frame:SetWidth(w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET)
    local bagHeight = h +
    const.OFFSETS.BAG_BOTTOM_INSET + -const.OFFSETS.BAG_TOP_INSET +
    const.OFFSETS.BOTTOM_BAR_HEIGHT + const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET
    bag.frame:SetHeight(bagHeight)
  end
  bag.currentItemCount = itemCount
end