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
---@param dirtyItems ItemData[]
function views:GridView(bag, dirtyItems)
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

    local oldFrame = bag.itemsByBagAndSlot[bagid][slotid] --[[@as Item]]
    -- The old frame does not exist, so we need to create a new one.
    if oldFrame == nil and not data.isItemEmpty then
      local newFrame = itemFrame:Create()
      newFrame:SetItem(data)
      local category = newFrame:GetCategory()
      local section ---@type Section|nil
      if newFrame:IsNewItem() then
        section = bag.recentItems
      else
        section = bag:GetOrCreateSection(category)
      end

      section:AddCell(data.itemInfo.itemGUID, newFrame)
      newFrame:AddToMasqueGroup(bag.kind)
      bag.itemsByBagAndSlot[bagid][slotid] = newFrame
    elseif oldFrame ~= nil and not data.isItemEmpty and oldFrame.data.itemInfo.itemGUID ~= data.itemInfo.itemGUID then
      -- This case handles the situation where the item in this slot no longer matches the item displayed.
      -- The old frame exists, so we need to update it.
      local oldCategory = oldFrame.data.itemInfo.category
      local oldSection = bag.sections[oldCategory]
      if bag.recentItems:HasItem(oldFrame) then
        oldSection = bag.recentItems
        oldCategory = bag.recentItems.title:GetText()
      end
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
        bag.sections[oldCategory] = nil
        bag.content:RemoveCell(oldCategory, oldSection)
        oldSection:Release()
      end
    elseif oldFrame ~= nil and not data.isItemEmpty and oldFrame.data.itemInfo.itemGUID == data.itemInfo.itemGUID then
      -- This case handles when the item in this slot is the same as the item displayed.
      local oldCategory = oldFrame.data.itemInfo.category
      local oldSection = bag.sections[oldCategory]
      local oldGuid = oldFrame.data.itemInfo.itemGUID
      oldFrame:SetItem(data)
      local newCategory = oldFrame:GetCategory()
      local newSection = bag:GetOrCreateSection(newCategory)
      if oldCategory ~= newCategory then
        oldSection:RemoveCell(oldGuid, oldFrame)
        newSection:AddCell(oldFrame.data.itemInfo.itemGUID, oldFrame)
      end
      if oldSection:GetCellCount() == 0 then
        bag.sections[oldCategory] = nil
        bag.content:RemoveCell(oldCategory, oldSection)
        oldSection:Release()
      end

      -- The item in this same slot may no longer be a new item, i.e. it was moused over. If so, we
      -- need to resection it.
      if not oldFrame:IsNewItem() and bag.recentItems:HasItem(oldFrame) then
        bag.recentItems:RemoveCell(oldFrame.data.itemInfo.itemGUID, oldFrame)
        local category = oldFrame:GetCategory()
        local section = bag:GetOrCreateSection(category)
        section:AddCell(oldFrame.data.itemInfo.itemGUID, oldFrame)
      end
    elseif data.isItemEmpty and oldFrame ~= nil then
      -- The old frame exists, but the item is empty, so we need to delete it.
      bag.itemsByBagAndSlot[bagid][slotid] = nil
      -- Special handling for the recent items section.
      if bag.recentItems:HasItem(oldFrame) then
        bag.recentItems:RemoveCell(oldFrame.data.itemInfo.itemGUID, oldFrame)
      else
        local section = bag.sections[oldFrame:GetCategory()]
        section:RemoveCell(oldFrame.data.itemInfo.itemGUID, oldFrame)
        -- Delete the section if it's empty as well.
        if section:GetCellCount() == 0 then
          bag.sections[oldFrame:GetCategory()] = nil
          bag.content:RemoveCell(oldFrame:GetCategory(), section)
          section:Release()
        end
      end
      oldFrame:Release()
    end
  end

  bag.freeSlots:AddCell("freeBagSlots", bag.freeBagSlotsButton)
  bag.freeSlots:AddCell("freeReagentBagSlots", bag.freeReagentBagSlotsButton)

  bag.freeBagSlotsButton:SetFreeSlots(freeSlotsData.bagid, freeSlotsData.slotid, freeSlotsData.count, false)
  bag.freeReagentBagSlotsButton:SetFreeSlots(freeReagentSlotsData.bagid, freeReagentSlotsData.slotid, freeReagentSlotsData.count, true)

  bag.recentItems:SetMaxCellWidth(sizeInfo.itemsPerRow)
  -- Loop through each section and draw it's size.
  for _, section in pairs(bag.sections) do
    section:SetMaxCellWidth(sizeInfo.itemsPerRow)
    section:Draw()
  end
  bag.freeSlots:SetMaxCellWidth(sizeInfo.itemsPerRow)
  bag.freeSlots:Draw()

  -- Remove the freeSlots section.
  bag.content:RemoveCell(bag.freeSlots.title:GetText(), bag.freeSlots)

  -- Sort all sections by title.
  bag.content:Sort(function(a, b)
    ---@cast a +Section
    ---@cast b +Section
    if not a.title or not b.title then return false end
    return a.title:GetText() < b.title:GetText()
  end)

  -- Add the freeSlots section back to the end of all sections
  bag.content:AddCellToLastColumn(bag.freeSlots.title:GetText(), bag.freeSlots)

  -- Position all sections and draw the main bag.
  local w, h = bag.content:Draw()
  -- Reposition the content frame if the recent items section is empty.

  --debug:DrawDebugBorder(self.content.frame, 1, 1, 1)
  if w < 160 then
    w = 160
  end
  if h == 0 then
    h = 40
  end
  bag.content:HideScrollBar()
  --TODO(lobato): Implement SafeSetSize that prevents the window from being larger
  -- than the screen space.
  bag.frame:SetWidth(w + 12)
  local bagHeight = h +
  const.OFFSETS.BAG_BOTTOM_INSET + -const.OFFSETS.BAG_TOP_INSET +
  const.OFFSETS.BOTTOM_BAR_HEIGHT + const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET
  bag.frame:SetHeight(bagHeight)
end