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

---@param frame BetterBagsSectionConfigItemFrame
---@param elementData table
function sectionItemListFrame:initSectionItem(frame, elementData)
  if frame.item == nil then
    frame.item = itemRowFrame:Create()
    frame.item.frame:SetParent(frame)
    frame.item.frame:SetPoint("LEFT", frame, "LEFT", 4, 0)
  end
  frame.item:SetStaticItemFromData(elementData.data)
end

---@param frame BetterBagsSectionConfigItemFrame
---@param elementData table
function sectionItemListFrame:resetSectionItem(frame, elementData)
  _ = elementData
  if frame.item then
    frame.item:ClearItem()
  end
end

---@param category string
function sectionItemListFrame:ShowCategory(category)
  if self:IsShown() then
    self:Hide(function()
      self:ShowCategory(category)
    end)
    return
  end

  self.content:Wipe()
  self.frame:SetTitle(category)

  local itemDataList = categories:GetMergedCategory(category)

  -- This is a dynamic category, do nothing for now.
  if itemDataList == nil then
    self:Show()
    return
  end

  local itemIDs = {}
  for id in pairs(itemDataList.itemList) do
    table.insert(itemIDs, id)
  end

  items:GetItemData(itemIDs, function(itemData)
    ---@cast itemData +ItemData[]
    for _, data in pairs(itemData) do
      self.content:AddToEnd({data = data})
    end
    self:Show()
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