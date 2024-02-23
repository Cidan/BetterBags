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

---@param view view
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

---@param view view
---@param bag Bag
---@param dirtyItems ItemData[]
local function GridView(view, bag, dirtyItems)
  local sizeInfo = database:GetBagSizeInfo(bag.kind, database:GetBagView(bag.kind))
  local categoryChanged = false
  local extraSlotInfo = items:GetExtraSlotInfo(bag.kind)
  view.content.compactStyle = database:GetBagCompaction(bag.kind)
  debug:Log("Draw", "Rendering grid view for bag", bag.kind, "with", #dirtyItems, "dirty items")
  debug:StartProfile('Dirty Item Stage')
  for _, data in pairs(dirtyItems) do
    local bagid, slotid = data.bagid, data.slotid
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
  debug:EndProfile('Dirty Item Stage')
  -- Add the empty slots to the view if bag slots are visible.
  if bag.slots:IsShown() then
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
  end

  if (extraSlotInfo.totalItems < view.itemCount and not bag.slots:IsShown() and not categoryChanged) then
    view.defer = true
  else
    view.defer = false
  end

  debug:StartProfile('Reconcile Stage')
  -- Loop through all sections and reconcile the items.
  for sectionName, section in pairs(view:GetAllSections()) do
    for slotkey, _ in pairs(section:GetAllCells()) do
      if slotkey ~= 'freeSlot' and slotkey ~= 'freeReagentSlot' then
        -- Get the bag and slot id from the slotkey.
        local data = view.itemsByBagAndSlot[slotkey].data
        -- Remove item buttons that are empty or don't match the category.
        if data.isItemEmpty and not bag.slots:IsShown() then
          if view.defer then
            view.itemsByBagAndSlot[slotkey]:SetFreeSlots(data.bagid, data.slotid, -1, const.BACKPACK_ONLY_REAGENT_BAGS[data.bagid] ~= nil)
            bag.drawOnClose = true
          else
            debug:Log("RemoveCell", "Removed because empty", slotkey, data.itemInfo.itemLink)
            section:RemoveCell(slotkey)
            view.itemsByBagAndSlot[slotkey]:Release()
            view.itemsByBagAndSlot[slotkey] = nil
            bag.drawOnClose = false
          end
        elseif data.itemInfo.category ~= sectionName then
          if view.defer then
            view.itemsByBagAndSlot[slotkey]:SetFreeSlots(data.bagid, data.slotid, -1, const.BACKPACK_ONLY_REAGENT_BAGS[data.bagid] ~= nil)
            bag.drawOnClose = true
          else
            debug:Log("RemoveCell", "Removed because category mismatch", slotkey)
            section:RemoveCell(slotkey)
            bag.drawOnClose = false
          end
        end
      end
    end

    if not view.defer then
      -- Remove the section if it's empty, otherwise draw it.
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
  end
  debug:EndProfile('Reconcile Stage')

  if not bag.slots:IsShown() then
    -- Get the free slots section and add the free slots to it.
    local freeSlotsSection = view:GetOrCreateSection(L:G("Free Space"))
    view.freeSlot = view.freeSlot or itemFrame:Create()
    if extraSlotInfo.emptySlots > 0 then
      local freeSlotBag, freeSlotID = view:ParseSlotKey(extraSlotInfo.freeSlotKey)
      view.freeSlot:SetFreeSlots(freeSlotBag, freeSlotID, extraSlotInfo.emptySlots, false)
    else
      view.freeSlot:SetFreeSlots(0, 0, 0, false)
    end
    freeSlotsSection:AddCell('freeSlot', view.freeSlot)

    -- Only add the reagent free slot to the backbag view.
    if bag.kind == const.BAG_KIND.BACKPACK and addon.isRetail then
      view.freeReagentSlot = view.freeReagentSlot or itemFrame:Create()
      if extraSlotInfo.emptyReagentSlots > 0 then
        local freeReagentSlotBag, freeReagentSlotID = view:ParseSlotKey(extraSlotInfo.freeReagentSlotKey)
        view.freeReagentSlot:SetFreeSlots(freeReagentSlotBag, freeReagentSlotID, extraSlotInfo.emptyReagentSlots, true)
      else
        view.freeReagentSlot:SetFreeSlots(0, 0, 0, true)
      end

      freeSlotsSection:AddCell('freeReagentSlot', view.freeReagentSlot)
    end

    -- Draw the free slots section.
    freeSlotsSection:SetMaxCellWidth(2)
    freeSlotsSection:Draw(bag.kind, database:GetBagView(bag.kind), false)
  end

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
  view.itemCount = extraSlotInfo.totalItems
end

---@param parent Frame
---@return view
function views:NewGrid(parent)
  local view = setmetatable({}, {__index = views.viewProto})
  view.sections = {}
  view.itemsByBagAndSlot = {}
  view.itemCount = 0
  view.kind = const.BAG_VIEW.SECTION_GRID
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
