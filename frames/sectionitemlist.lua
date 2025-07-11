


local addon = GetBetterBags()

---@class List: AceModule
local list = addon:GetModule('List')

local animations = addon:GetAnimations()

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

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

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

---@param ctx Context
function sectionItemListFrame:OnReceiveDrag(ctx)
  local kind, id = GetCursorInfo()
  if kind ~= "item" or not tonumber(id) then return end
  ClearCursor()
  local itemid = tonumber(id) --[[@as number]]
  categories:AddPermanentItemToCategory(ctx, itemid, self.currentCategory)
  events:SendMessage(ctx, 'bags/FullRefreshAll')
end

---@param ctx Context
---@param b string
---@param elementData table
function sectionItemListFrame:OnItemClick(ctx, b, elementData)
  if b == "LeftButton" then
    self:OnReceiveDrag(ctx)
    return
  end
  ClearCursor()
  contextMenu:Show(ctx, {{
    text = L:G("Remove"),
    notCheckable = true,
    hasArrow = false,
    func = function()
      database:DeleteItemFromCategory(elementData.id, elementData.category)
      events:SendMessage(ctx, 'bags/FullRefreshAll')
    end
  }})
end

---@param frame BetterBagsSectionConfigItemFrame
---@param elementData table
function sectionItemListFrame:initSectionItem(frame, elementData)
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
---@param elementData table
function sectionItemListFrame:resetSectionItem(frame, elementData)
  _ = elementData
  local ctx = context:New("SectionItemList_Reset")
  if frame.item then
    frame.item:ClearItem(ctx)
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

  themes:SetTitle(self.frame, category)
  self.currentCategory = category

  local itemDataList = categories:GetMergedCategory(category)

  -- This is a dynamic category, do nothing for now.
  if itemDataList == nil then
    self.content:Wipe()
    self:Show()
    return
  end

  self.content:Wipe()

  for id in pairs(itemDataList.itemList) do
    self.content:AddToStart({id = id, category = category})
  end
  if not self:IsShown() then
    self:Show()
  end
end

---@param parent Frame
---@return SectionItemListFrame
function sectionItemList:Create(parent)
  local sc = setmetatable({}, {__index = sectionItemListFrame})
  sc.frame = CreateFrame("Frame", parent:GetName().."SectionList", parent) --[[@as Frame]]
  sc.frame:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMLEFT', -10, 0)
  sc.frame:SetPoint('TOPRIGHT', parent, 'TOPLEFT', -10, 0)
  sc.frame:SetWidth(300)
  sc.frame:EnableMouse(true)

  addon.SetScript(sc.frame, "OnReceiveDrag", function(ctx)
    sc:OnReceiveDrag(ctx)
  end)
  addon.SetScript(sc.frame, "OnMouseDown", function(ctx)
    sc:OnReceiveDrag(ctx)
  end)

  themes:RegisterSimpleWindow(sc.frame, L:G("Items"))

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