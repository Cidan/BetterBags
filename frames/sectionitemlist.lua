local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class List: AceModule
local list = addon:GetModule('List')

---@class Animations: AceModule
local animations = addon:GetModule('Animations')

---@class ItemRowFrame: AceModule
local itemRowFrame = addon:GetModule('ItemRowFrame')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class ContextMenu: AceModule
local contextMenu = addon:GetModule('ContextMenu')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Localization: AceModule
local L =  addon:GetModule('Localization')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class SectionItemList: AceModule
local sectionItemList = addon:NewModule('SectionItemList')

---@class BetterBagsSectionConfigItemFrame: Frame
---@field item ItemRow

---@class SectionItemListElement
---@field name string

---@class SectionItemListFrame
---@field frame Frame
---@field content ListFrame
---@field package fadeIn AnimationGroup
---@field package fadeOut AnimationGroup
---@field private currentCategory string
local sectionItemListFrame = {}

---@param callback? fun()
function sectionItemListFrame:Show(callback)
  PlaySound(SOUNDKIT.GUILD_BANK_OPEN_BAG)
  if callback then
    self.fadeIn.callback = function()
      self.fadeIn.callback = nil
      callback()
    end
  end
  self.fadeIn:Play()
end

---@param callback? fun()
function sectionItemListFrame:Hide(callback)
  PlaySound(SOUNDKIT.GUILD_BANK_OPEN_BAG)
  if callback then
    self.fadeOut.callback = function()
      self.fadeOut.callback = nil
      callback()
    end
  end
  self.fadeOut:Play()
end

function sectionItemListFrame:IsShown()
  return self.frame:IsShown()
end

function sectionItemListFrame:OnReceiveDrag()
  local kind, id = GetCursorInfo()
  if kind ~= "item" or not tonumber(id) then return end
  ClearCursor()
  local itemid = tonumber(id) --[[@as number]]
  database:SaveItemToCategory(itemid, self.currentCategory)
  events:SendMessage('bags/FullRefreshAll')
end

function sectionItemListFrame:OnItemClick(b, elementData)
  if b == "LeftButton" then
    self:OnReceiveDrag()
    return
  end
  ClearCursor()
  contextMenu:Show({{
    text = L:G("Remove"),
    notCheckable = true,
    hasArrow = false,
    func = function()
      database:DeleteItemFromCategory(elementData.data.itemInfo.itemID, elementData.category)
      events:SendMessage('bags/FullRefreshAll')
    end
  }})
end

---@param frame BetterBagsSectionConfigItemFrame
---@param elementData table
function sectionItemListFrame:initSectionItem(frame, elementData)
  if frame.item == nil then
    frame.item = itemRowFrame:Create()
    frame.item.frame:SetParent(frame)
    frame.item.frame:SetPoint("LEFT", frame, "LEFT", 4, 0)
    frame.item.frame:SetPoint("RIGHT", frame, "RIGHT", -9, 0)
  end

  local click = function(_, b)
    self:OnItemClick(b, elementData)
  end

  local drag = function()
    self:OnReceiveDrag()
  end

  frame.item.rowButton:SetScript("OnReceiveDrag", drag)
  frame.item.button.button:SetScript("OnReceiveDrag", drag)

  frame.item.rowButton:SetScript("OnMouseDown", click)
  frame.item.button.button:SetScript("OnMouseDown", click)
  frame.item:SetStaticItemFromData(elementData.data)
end

---@param frame BetterBagsSectionConfigItemFrame
---@param elementData table
function sectionItemListFrame:resetSectionItem(frame, elementData)
  _ = elementData
  if frame.item then
    frame.item:ClearItem()
    frame.item.rowButton:SetScript("OnMouseDown", nil)
  end
end

---@param category string
---@return boolean
function sectionItemListFrame:IsCategory(category)
  return self.currentCategory == category
end

function sectionItemListFrame:Redraw()
  self:ShowCategory(self.currentCategory, true)
end

---@param category string
---@param redraw? boolean
function sectionItemListFrame:ShowCategory(category, redraw)
  if self:IsShown() and self.currentCategory ~= category then
    self:Hide(function()
      self:ShowCategory(category)
    end)
    return
  elseif self:IsShown() and self.currentCategory == category and not redraw then
    self:Hide()
    return
  end

  self.frame:SetTitle(category)
  self.currentCategory = category

  local itemDataList = categories:GetMergedCategory(category)

  -- This is a dynamic category, do nothing for now.
  if itemDataList == nil then
    self.content:Wipe()
    self:Show()
    return
  end

  local itemIDs = {}
  for id in pairs(itemDataList.itemList) do
    table.insert(itemIDs, id)
  end

  items:GetItemData(itemIDs, function(itemData)
    self.content:Wipe()
    ---@cast itemData +ItemData[]
    for _, data in pairs(itemData) do
      self.content:AddToStart({data = data, category = category})
    end
    if not self:IsShown() then
      self:Show()
    end
  end)
end

---@param parent Frame
---@return SectionItemListFrame
function sectionItemList:Create(parent)
  local sc = setmetatable({}, {__index = sectionItemListFrame})
  sc.frame = CreateFrame("Frame", nil, parent, "DefaultPanelTemplate") --[[@as Frame]]
  sc.frame:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMLEFT', -10, 0)
  sc.frame:SetPoint('TOPRIGHT', parent, 'TOPLEFT', -10, 0)
  sc.frame:SetWidth(300)
  sc.frame:EnableMouse(true)
  sc.frame:SetScript("OnReceiveDrag", function()
    sc:OnReceiveDrag()
  end)
  sc.frame:SetScript("OnMouseDown", function()
    sc:OnReceiveDrag()
  end)
  sc.fadeIn, sc.fadeOut = animations:AttachFadeAndSlideLeft(sc.frame)
  sc.content = list:Create(sc.frame)
  sc.content.frame:SetAllPoints()
  -- Setup the create and destroy functions for items on the list.
  sc.content:SetupDataSource("BetterBagsSectionConfigItemFrame", function(f, data)
    ---@cast f BetterBagsSectionConfigItemFrame
    sc:initSectionItem(f, data)
  end,
  function(f, data)
    ---@cast f BetterBagsSectionConfigItemFrame
    sc:resetSectionItem(f, data)
  end)

  sc.frame:Hide()
  return sc
end