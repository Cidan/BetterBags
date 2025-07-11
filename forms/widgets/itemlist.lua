


local addon = GetBetterBags()

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class ItemList: AceModule
local itemList = addon:NewModule('ItemList')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class ItemListFrame: Frame
---@field frame Frame
---@field content ListFrame
---@field onDragFunction fun(ctx: Context, self: ItemListFrame)
---@field onItemClickFunction fun(ctx: Context, b: string, elementData: FormItemListItem, self: ItemListFrame)
local itemListFrame = {}

function itemListFrame:OnReceiveDrag(ctx)
  if self.onDragFunction then
    self.onDragFunction(ctx, self)
  end
end

function itemListFrame:OnMouseDown(ctx)
  _ = ctx
end

function itemListFrame:OnItemClick(ctx, b, elementData)
  if b == "LeftButton" then
    self:OnReceiveDrag(ctx)
    return
  end
  if self.onItemClickFunction then
    self.onItemClickFunction(ctx, b, elementData, self)
  end
end

---@param frame BetterBagsSectionConfigItemFrame
---@param elementData FormItemListItem
function itemListFrame:initSectionItem(frame, elementData)
  ---@class ItemRowFrame: AceModule
  local itemRowFrame = addon:GetModule('ItemRowFrame')

  local ctx = context:New("SectionItemList_Init")
  if frame.item == nil then
    frame.item = itemRowFrame:Create(ctx)
    frame.item.frame:SetParent(frame)
    frame.item.frame:SetPoint("LEFT", frame, "LEFT", 4, 0)
    frame.item.frame:SetPoint("RIGHT", frame, "RIGHT", -9, 0)
  end

  addon.SetScript(frame.item.rowButton, "OnReceiveDrag", function(ectx)
    self:OnReceiveDrag(ectx)
  end)
  addon.SetScript(frame.item.button.button, "OnReceiveDrag", function(ectx)
    self:OnReceiveDrag(ectx)
  end)

  addon.SetScript(frame.item.rowButton, "OnMouseDown", function(ectx, _, b)
    self:OnItemClick(ectx, b, elementData)
  end)

  addon.SetScript(frame.item.button.button, "OnMouseDown", function(ectx, _, b)
    self:OnItemClick(ectx, b, elementData)
  end)

  items:GetItemData(ctx, {elementData.id}, function(ectx, itemData)
    frame.item:SetStaticItemFromData(ectx, itemData[1])
  end)

  frame.item:SetStaticItemFromData(ctx, elementData.data)
end

---@param frame BetterBagsSectionConfigItemFrame
---@param elementData FormItemListItem
function itemListFrame:resetSectionItem(frame, elementData)
  _ = elementData
  local ctx = context:New("SectionItemList_Reset")
  if frame.item then
    frame.item:ClearItem(ctx)
    frame.item.rowButton:SetScript("OnMouseDown", nil)
  end
end

---@param itemDataList FormItemListItem[]
function itemListFrame:AddItems(itemDataList)
  self.content:Wipe()

  for _, idata in pairs(itemDataList) do
    self.content:AddToStart(idata)
  end
end

---@param itemDataList FormItemListItem[]
function itemListFrame:UpdateItems(itemDataList)
  for _, idata in pairs(itemDataList) do
    self.content:AddToStart(idata)
  end
end

function itemListFrame:SetOnDragFunction(func)
  self.onDragFunction = func
end

function itemListFrame:SetOnItemClickFunction(func)
  self.onItemClickFunction = func
end

---@param parent Frame
---@return ItemListFrame
function itemList:Create(parent)
  local il = setmetatable({}, {__index = itemListFrame})
  local frame = CreateFrame('Frame', nil, parent)
  frame:EnableMouse(true)
  addon.SetScript(frame, "OnReceiveDrag", function(ctx)
    il:OnReceiveDrag(ctx)
  end)
  addon.SetScript(frame, "OnMouseDown", function(ctx)
    il:OnMouseDown(ctx)
  end)

  ---@class List: AceModule
  local list = addon:GetModule('List')

  il.content = list:Create(frame)
  il.content.frame:SetAllPoints()
  il.content:SetupDataSource("BetterBagsSectionConfigItemFrame", function(f, data)
    ---@cast f BetterBagsSectionConfigItemFrame
    il:initSectionItem(f, data)
  end,
  function(f, data)
    ---@cast f BetterBagsSectionConfigItemFrame
    il:resetSectionItem(f, data)
  end)

  il.frame = frame
  return il
end
