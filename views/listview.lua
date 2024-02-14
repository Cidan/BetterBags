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

---@class GridFrame: AceModule
local grid = addon:GetModule('Grid')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Views: AceModule
local views = addon:GetModule('Views')

---@param view view
local function Wipe(view)
  view.content:Wipe()
  view.freeSlot = nil
  view.freeReagentSlot = nil
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

--TODO(lobato): Move the -35 below to constants.

---@param view view
---@param bag Bag
local function UpdateListSize(view, bag)
  local w, _ = bag.frame:GetSize()
  for _, section in pairs(view:GetAllSections()) do
    section.frame:SetWidth(w - 35)
    for _, cell in pairs(section:GetAllCells()) do
      cell.frame:SetWidth(w - 35)
    end
  end
end

---@param view view
---@param bag Bag
---@param dirtyItems ItemData[]
local function ListView(view, bag, dirtyItems)
  local freeSlotsData = {count = 0, bagid = 0, slotid = 0}
  local freeReagentSlotsData = {count = 0, bagid = 0, slotid = 0}
  view.content.compactStyle = const.GRID_COMPACT_STYLE.NONE
  for _, data in pairs(dirtyItems) do
    local bagid, slotid = data.bagid, data.slotid
    local slotkey = view:GetSlotKey(data)

    -- Capture information about free slots.
    if data.isItemEmpty then
      if bagid == Enum.BagIndex.ReagentBag then
        freeReagentSlotsData.count = freeReagentSlotsData.count + 1
        freeReagentSlotsData.bagid = bagid
        freeReagentSlotsData.slotid = slotid
      elseif bagid ~= Enum.BagIndex.Keyring then
        freeSlotsData.count = freeSlotsData.count + 1
        freeSlotsData.bagid = bagid
        freeSlotsData.slotid = slotid
      end
    end

    local itemButton = view.itemsByBagAndSlot[slotkey] --[[@as ItemRow]]
    if itemButton == nil then
      itemButton = itemRowFrame:Create()
      itemButton.rowButton:SetScript("OnMouseWheel", function(_, delta)
        view.content:GetContainer():OnMouseWheel(delta)
      end)
      itemButton:AddToMasqueGroup(bag.kind)
      view.itemsByBagAndSlot[slotkey] = itemButton --[[@as Item]]
    end

    itemButton:SetItem(data)

    if not data.isItemEmpty then
      local category = itemButton:GetCategory()
      local section = view:GetOrCreateSection(category)
      section:GetContent():GetContainer():SetScript("OnMouseWheel", function(_, delta)
        view.content:GetContainer():OnMouseWheel(delta)
      end)
      section:AddCell(slotkey, itemButton)
    end
  end

  for sectionName, section in pairs(view:GetAllSections()) do
    for slotkey, _ in pairs(section:GetAllCells()) do
      local data = view.itemsByBagAndSlot[slotkey].data
      if data.isItemEmpty then
        section:RemoveCell(slotkey)
        view.itemsByBagAndSlot[slotkey]:Wipe()
      elseif data.itemInfo.category ~= sectionName then
        section:RemoveCell(slotkey)
      end
    end
    if section:GetCellCount() == 0 then
      view:RemoveSection(sectionName)
      section:ReleaseAllCells()
      section:Release()
    else
      section:SetMaxCellWidth(1)
      section:Draw(bag.kind, database:GetBagView(bag.kind))
    end
  end

  view.content.maxCellWidth = 1
  view.content:Sort(sort:GetSectionSortFunction(bag.kind, const.BAG_VIEW.LIST))
  local w, h = view.content:Draw()

  if w < 160 then
  w = 160
  end
  if h == 0 then
  h = 40
  end
  view.content:ShowScrollBar()

  bag.frame:SetSize(database:GetBagViewFrameSize(bag.kind, database:GetBagView(bag.kind)))
  view.content:GetContainer():FullUpdate()
end

---@param parent Frame
---@return view
function views:NewList(parent)
  local view = setmetatable({}, {__index = views.viewProto})
  view.sections = {}
  view.itemsByBagAndSlot = {}
  view.itemCount = 0
  view.kind = const.BAG_VIEW.LIST
  view.content = grid:Create(parent)
  view.content:GetContainer():ClearAllPoints()
  view.content:GetContainer():SetPoint("TOPLEFT", parent, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET, const.OFFSETS.BAG_TOP_INSET)
  view.content:GetContainer():SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", const.OFFSETS.BAG_RIGHT_INSET, const.OFFSETS.BAG_BOTTOM_INSET + const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET + 20)
  view.content.compactStyle = const.GRID_COMPACT_STYLE.NONE
  view.content:Hide()
  view.Render = ListView
  view.Wipe = Wipe
  view.UpdateListSize = UpdateListSize
  return view
end