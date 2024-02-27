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

---@param view view
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

---@param view view
---@param bag Bag
---@param dirtyItems ItemData[]
local function BagView(view, bag, dirtyItems)
  if view.fullRefresh then
    view:Wipe()
    view.fullRefresh = false
  end
  -- Use the section grid sizing for this view type.
  local sizeInfo = database:GetBagSizeInfo(bag.kind, const.BAG_VIEW.SECTION_GRID)
  local extraSlotInfo = items:GetExtraSlotInfo(bag.kind)
  local categoryChanged = false

  for _, data in pairs(dirtyItems) do
    local bagid = data.bagid
    local slotkey = view:GetSlotKey(data)

    -- Create or get the item frame for this slot.
    local itemButton = view.itemsByBagAndSlot[slotkey] --[[@as Item]]
    if itemButton == nil then
      itemButton = itemFrame:Create()
      view.itemsByBagAndSlot[slotkey] = itemButton
    end

    -- Get the previous category for this slotkey.
    local previousCategory = itemButton.data and itemButton.data.itemInfo and itemButton.data.itemInfo.category

    -- Set the item data on the item frame.
    itemButton:SetItem(data)

    -- Add the item to the correct category section, skipping the keyring unless we're showing bag slots.
    if (not data.isItemEmpty and bagid ~= Enum.BagIndex.Keyring) then
      local category = itemButton:GetCategory()
      local section = view:GetOrCreateSection(category)
      section:AddCell(slotkey, itemButton)
      if previousCategory ~= category then
        categoryChanged = true
      end
    end
  end

  for slotkey, itemButton in pairs(view.itemsByBagAndSlot) do
    local data = itemButton.data
    local name = C_Container.GetBagName(data.bagid)
    local previousCategory = data.itemInfo and data.itemInfo.category
    if name ~= nil then
      local newCategory = itemButton:GetCategory()
      if not data.isItemEmpty and previousCategory ~= newCategory then
        debug:Log("BagSlotShow", "Category difference", previousCategory, "->", newCategory)
        local section = view:GetOrCreateSection(newCategory)
        section:AddCell(slotkey, itemButton)
        categoryChanged = true
      end
    else
      debug:Log("MissingBag", "Removing slotkey from missing bag", slotkey, "bagid ->", data.bagid)
      local section = view:GetOrCreateSection(previousCategory)
      section:RemoveCell(slotkey)
      view.itemsByBagAndSlot[slotkey]:Release()
      view.itemsByBagAndSlot[slotkey] = nil
    end
  end
  for bagid, emptyBagData in pairs(extraSlotInfo.emptySlotByBagAndSlot) do
    for slotid, data in pairs(emptyBagData) do
      local slotkey = view:GetSlotKey(data)
      if C_Container.GetBagName(bagid) ~= nil then
        local itemButton = view.itemsByBagAndSlot[slotkey] --[[@as Item]]
        if itemButton == nil then
          itemButton = itemFrame:Create()
          view.itemsByBagAndSlot[slotkey] = itemButton
        end
        itemButton:SetFreeSlots(bagid, slotid, -1, const.BACKPACK_ONLY_REAGENT_BAGS[bagid] ~= nil)
        local category = itemButton:GetCategory()
        local section = view:GetOrCreateSection(category)
        section:AddCell(slotkey, itemButton)
      end
    end
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
      section:Draw(bag.kind, database:GetBagView(bag.kind), bag.slots:IsShown())
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

function views:NewBagView(parent)
  local view = setmetatable({}, {__index = views.viewProto})
  view.sections = {}
  view.itemsByBagAndSlot = {}
  view.itemFrames = {}
  view.itemCount = 0
  view.kind = const.BAG_VIEW.SECTION_ALL_BAGS
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