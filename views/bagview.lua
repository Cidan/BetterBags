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

---@class ItemFrame: AceModule
local itemFrame = addon:GetModule('ItemFrame')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Sort: AceModule
local sort = addon:GetModule('Sort')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@param view View
---@param ctx Context
local function Wipe(view, ctx)
  view.content:Wipe()
  view.itemCount = 0
  for _, section in pairs(view.sections) do
    section:ReleaseAllCells(ctx)
    section:Release(ctx)
  end
  wipe(view.sections)
  wipe(view.itemsByBagAndSlot)
end

---@param bagid number
---@return string
local function GetBagName(bagid)
  local isBackpack = const.BACKPACK_BAGS[bagid] ~= nil
  if isBackpack then
    local bagname = bagid == Enum.BagIndex.Keyring and L:G('Keyring') or C_Container.GetBagName(bagid)
    local displayid = bagid == Enum.BagIndex.Keyring and 6 or bagid+1
    return format("#%d: %s", displayid, bagname or "Unknown")
  end

    local id = bagid
    if id == -1 then
      return format("#%d: %s", 1, L:G('Bank'))
    elseif id == -3 then
      return format("#%d: %s", 1, L:G('Reagent Bank'))
    else
      return format("#%d: %s", id - 4, C_Container.GetBagName(id))
    end

end

-- ClearButton clears a button and makes it empty while preserving the slot,
-- but does not release it, while also adding it to the deferred items list.
---@param ctx Context
---@param view View
---@param item ItemData
local function ClearButton(ctx, view, item)
  local cell = view.itemsByBagAndSlot[item.slotkey]
  local bagid, slotid = view:ParseSlotKey(item.slotkey)
  cell:SetFreeSlots(ctx, bagid, slotid, -1)
  view:AddDeferredItem(item.slotkey)
  addon:GetBagFromBagID(bagid).drawOnClose = true
end

-- CreateButton creates a button for an item and adds it to the view.
---@param ctx Context
---@param view View
---@param item ItemData
local function CreateButton(ctx, view, item)
  debug:Log("CreateButton", "Creating button for item", item.slotkey)
  view:RemoveDeferredItem(item.slotkey)
  local oldSection = view:GetSlotSection(item.slotkey)
  if oldSection then
    oldSection:RemoveCell(item.slotkey)
  end
  local itemButton = view:GetOrCreateItemButton(ctx, item.slotkey)
  itemButton:SetItem(ctx, item.slotkey)
  local section = view:GetOrCreateSection(ctx, GetBagName(item.bagid))
  section:AddCell(itemButton:GetItemData().slotkey, itemButton)
  view:SetSlotSection(itemButton:GetItemData().slotkey, section)
end

---@param ctx Context
---@param view View
---@param slotkey string
local function UpdateButton(ctx, view, slotkey)
  view:RemoveDeferredItem(slotkey)
  local itemButton = view:GetOrCreateItemButton(ctx, slotkey)
  itemButton:SetItem(ctx, slotkey)
end

---@param ctx Context
---@param view View
---@param newSlotKey string
local function AddSlot(ctx, view, newSlotKey)
  local itemButton = view:GetOrCreateItemButton(ctx, newSlotKey)
  local newBagid = view:ParseSlotKey(newSlotKey)
  local newSection = view:GetOrCreateSection(ctx, GetBagName(newBagid))
  newSection:AddCell(newSlotKey, itemButton)
  itemButton:SetItem(ctx, newSlotKey)
end

---@param view View
local function UpdateViewSize(view)
  local parent = view.content:GetContainer():GetParent()
  if database:GetInBagSearch() then
    view.content:GetContainer():SetPoint("TOPLEFT", parent, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET, const.OFFSETS.BAG_TOP_INSET - 20)
  else
    view.content:GetContainer():SetPoint("TOPLEFT", parent, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET, const.OFFSETS.BAG_TOP_INSET)
  end
end

---@param view View
---@param ctx Context
---@param bag Bag
---@param slotInfo SlotInfo
---@param callback fun()
local function BagView(view, ctx, bag, slotInfo, callback)
  if ctx:GetBool('wipe') then
    view:Wipe(ctx)
  end
  -- Use the section grid sizing for this view type.
  local sizeInfo = database:GetBagSizeInfo(bag.kind, const.BAG_VIEW.SECTION_ALL_BAGS)

  local added, removed, changed = slotInfo:GetChangeset()

  for _, item in pairs(removed) do
    ClearButton(ctx, view, item)
  end

  for _, item in pairs(added) do
    CreateButton(ctx, view, item)
  end

  for _, item in pairs(changed) do
    UpdateButton(ctx, view, item.slotkey)
  end

  for bagid, emptyBagData in pairs(slotInfo.emptySlotByBagAndSlot) do
    for slotid, data in pairs(emptyBagData) do
      local slotkey = view:GetSlotKey(data)
      if C_Container.GetBagName(bagid) ~= nil then
        local itemButton = view.itemsByBagAndSlot[slotkey] --[[@as Item]]
        if itemButton == nil then
          itemButton = itemFrame:Create(ctx)
          view.itemsByBagAndSlot[slotkey] = itemButton
        end
        itemButton:SetFreeSlots(ctx, bagid, slotid, -1)
        local section = view:GetOrCreateSection(ctx, GetBagName(bagid))
        section:AddCell(slotkey, itemButton)
      end
    end
  end

  for _, item in pairs(view.itemsByBagAndSlot) do
    item:UpdateCount(ctx)
  end

  for sectionName, section in pairs(view:GetAllSections()) do
    if section:GetCellCount() == 0 then
      debug:Log("RemoveSection", "Removed because empty", sectionName)
      view:RemoveSection(sectionName)
      section:ReleaseAllCells(ctx)
      section:Release(ctx)
    else
      debug:Log("KeepSection", "Section kept because not empty", sectionName)
      section:SetMaxCellWidth(sizeInfo.itemsPerRow)
      section:Draw(bag.kind, database:GetBagView(bag.kind), true)
    end
  end
  view.content.maxCellWidth = sizeInfo.columnCount
  -- Sort the sections.
  view.content:Sort(function(a, b)
    return sort.SortSectionsAlphabetically(view.kind, a, b)
  end)
  debug:StartProfile('Content Draw Stage')
  local w, h = view.content:Draw({
    cells = view.content.cells,
    maxWidthPerRow = ((37 + 4) * sizeInfo.itemsPerRow) + 16,
    columns = sizeInfo.columnCount,
  })
  debug:EndProfile('Content Draw Stage')
  -- Reposition the content frame if the recent items section is empty.
  if w < 160 then
    w = 160
  end
  if bag.tabs and w < bag.tabs.width then
    w = bag.tabs.width
  end
  if h == 0 then
    h = 40
  end
  if database:GetInBagSearch() then
    h = h + 20
  end
  view.content:HideScrollBar()
  --TODO(lobato): Implement SafeSetSize that prevents the window from being larger
  -- than the screen space.
  bag.frame:SetWidth(w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET)
  local bagHeight = h +
  const.OFFSETS.BAG_BOTTOM_INSET + -const.OFFSETS.BAG_TOP_INSET +
  const.OFFSETS.BOTTOM_BAR_HEIGHT + const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET
  bag.frame:SetHeight(bagHeight)
  UpdateViewSize(view)
  callback()
end

---@param parent Frame
---@param kind BagKind
---@return View
function views:NewBagView(parent, kind)
  local view = views:NewBlankView()
  view.itemFrames = {}
  view.itemCount = 0
  view.bagview = const.BAG_VIEW.SECTION_ALL_BAGS
  view.kind = kind
  view.content = grid:Create(parent)
  view.content:GetContainer():ClearAllPoints()
  view.content:GetContainer():SetPoint("TOPLEFT", parent, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET, const.OFFSETS.BAG_TOP_INSET)
  view.content:GetContainer():SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", const.OFFSETS.BAG_RIGHT_INSET, const.OFFSETS.BAG_BOTTOM_INSET + const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET + 20)
  view.content.compactStyle = const.GRID_COMPACT_STYLE.NONE
  view.content:Hide()
  view.Render = BagView
  view.WipeHandler = Wipe
  view.AddSlot = AddSlot

  return view
end
