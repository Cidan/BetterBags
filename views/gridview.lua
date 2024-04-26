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

---@param view View
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

--local stacks = {}

---@param view View
---@param bag Bag
---@param slotInfo SlotInfo
local function GridView(view, bag, slotInfo)
  if view.fullRefresh then
    view:Wipe()
    view.fullRefresh = false
  end
  local sizeInfo = database:GetBagSizeInfo(bag.kind, database:GetBagView(bag.kind))
  view.content.compactStyle = database:GetBagCompaction(bag.kind)

  local added, removed, changed = slotInfo:GetChangeset()

  for _, item in pairs(removed) do
    view:RemoveButton(item)
  end
  view:ProcessStacks()

  for _, item in pairs(added) do
    local itemButton = view:AddButton(item)
    if itemButton then
      local section = view:GetOrCreateSection(item.itemInfo.category)
      section:AddCell(itemButton:GetItemData().slotkey, itemButton)
    end
  end

  for _, item in pairs(changed) do
    view:ChangeButton(item)
  end

  view:ProcessStacks()

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
---@param kind BagKind
---@return View
function views:NewGrid(parent, kind)
  local view = views:NewBlankView()
  view.itemCount = 0
  view.bagview = const.BAG_VIEW.SECTION_GRID
  view.kind = kind
  view.content = grid:Create(parent)
  view.content:GetContainer():ClearAllPoints()
  view.content:GetContainer():SetPoint("TOPLEFT", parent, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET, const.OFFSETS.BAG_TOP_INSET)
  view.content:GetContainer():SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", const.OFFSETS.BAG_RIGHT_INSET, const.OFFSETS.BAG_BOTTOM_INSET + const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET + 20)
  view.content.compactStyle = const.GRID_COMPACT_STYLE.NONE
  view.content:Hide()
  view.Render = GridView
  view.WipeHandler = Wipe
  return view
end
