local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class ListFrame: AceModule
---@field frame Frame
---@field ScrollBox WowScrollBox
---@field ScrollBar MinimalScrollBar
---@field provider DataProviderMixin
---@field package canReorder boolean
---@field private dragBehavior ScrollBoxDragBehavior
local listFrame = {}

-- SetupDataSource readies the list frame to accept items.
-- You must call this method before you can add items to the list.
-- The itemTemplate is the name of the template to use for each item in the list.
-- The elementFactory is a function that initializes each item in the list.
-- The elementFactory function will be called with two arguments: the button frame and the element data.
-- The element data is the data that you pass to any of the Add methods on the list.
---@param itemTemplate string The name of the template to use for each item in the list.
---@param elementFactory fun(button: Frame, elementData: table) A function that initializes each item in the list.
---@param elementResetter fun(button: Frame, elementData: table) A function that resets elements in the list.
function listFrame:SetupDataSource(itemTemplate, elementFactory, elementResetter)
  local view = CreateScrollBoxListLinearView()

  view:SetElementInitializer(itemTemplate, elementFactory)
  view:SetElementResetter(elementResetter)
  view:SetPadding(4, 4, 8, 4, 0)
  view:SetExtent(20)
  ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox, self.ScrollBar, view)
  self.dragBehavior = ScrollUtil.InitDefaultLinearDragBehavior(self.ScrollBox)
  self.ScrollBox:SetDataProvider(self.provider)
end

-- AddToEnd will add an item to the end of the list.
---@param data table
function listFrame:AddToEnd(data)
  self.provider:InsertAtIndex(data, 1)
end

-- AddToStart will add an item to the start of the list.
---@param data table
function listFrame:AddToStart(data)
  self.provider:InsertAtIndex(data, self.provider:GetSize()+1)
end

---@param data table
---@return boolean
function listFrame:HasItem(data)
  return self.provider:ContainsByPredicate(function(elementData)
    for k, v in pairs(elementData) do
      if data[k] ~= v then
        return false
      end
    end
    return true
  end)
end

---@return table[]
function listFrame:GetAllItems()
  return self.provider:GetCollection()
end

---@return number
function listFrame:GetSize()
  return self.provider:GetSize()
end

---@param index number
---@return table
function listFrame:GetIndex(index)
  return self.provider:Find(index)
end

function listFrame:Wipe()
  self.provider:Flush()
end

-- CanReorder will set whether or not the list can be reordered by clicking on an item.
---@param canReorder boolean
---@param cb fun(event: number, elementData: table, currentIndex: number, newIndex: number)
function listFrame:SetCanReorder(canReorder, cb)
  self.canReorder = canReorder
  self.dragBehavior:SetReorderable(canReorder)
  self.provider:RegisterCallback(DataProviderMixin.Event.OnMove, cb)
end

---@class List: AceModule
local list = addon:NewModule('List')

-- Create will create a new list frame that can be used to display a list of items.
-- You must call SetupDataSource before you can add items to the list.
---@param parent Frame
---@return ListFrame
function list:Create(parent)
  local l = setmetatable({}, {__index = listFrame})
  l.frame = CreateFrame("Frame", nil, parent)

  l.ScrollBox = CreateFrame("Frame", nil, l.frame, "WowScrollBoxList") --[[@as WowScrollBox]]
  l.ScrollBox:SetPoint("TOPLEFT", l.frame, "TOPLEFT", 4, -22)
  l.ScrollBox:SetPoint("BOTTOM", 0, 4)

  l.ScrollBar = CreateFrame("EventFrame", nil, l.ScrollBox, "MinimalScrollBar") --[[@as MinimalScrollBar]]
  l.ScrollBar:SetPoint("TOPLEFT", l.frame, "TOPRIGHT", -16, -28)
  l.ScrollBar:SetPoint("BOTTOMLEFT", l.frame, "BOTTOMRIGHT", -16, 6)

  l.ScrollBox:SetInterpolateScroll(true)
  l.ScrollBar:SetInterpolateScroll(true)

  l.provider = CreateDataProvider() --[[@as DataProviderMixin]]

  l.canReorder = false
  return l
end