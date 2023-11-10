local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class ItemFrame: AceModule
local item = addon:NewModule('ItemFrame')

---@class Item
---@field mixin ItemMixin
---@field frame ItemButton
---@field IconTexture Texture
---@field Count FontString
---@field Stock FontString
---@field IconBorder Texture
---@field IconQuestTexture Texture
---@field NormalTexture Texture
---@field NewItemTexture Texture
---@field IconOverlay2 Texture
---@field ItemContextOverlay Texture
---@field Cooldown Cooldown
local itemProto = {}

local buttonCount = 0
local children = {
  "IconQuestTexture",
  "IconTexture",
  "Count",
  "Stock",
  "IconBorder",
  "Cooldown",
  "NormalTexture",
  "NewItemTexture",
  "IconOverlay2",
  "ItemContextOverlay"
}

---@param i ItemMixin
function itemProto:SetItem(i)
  assert(i, 'item must be provided')
  self.mixin = i
  local tooltipOwner = GameTooltip:GetOwner();
  local bagid, slotid = i:GetItemLocation():GetBagAndSlot()
  self.frame:SetBagID(bagid)
  self.frame:SetID(slotid)

  local info = C_Container.GetContainerItemInfo(bagid, self.frame:GetID());
  local texture = info and info.iconFileID;
  local itemCount = info and info.stackCount;
  local locked = info and info.isLocked;
  local quality = info and info.quality;
  local readable = info and info.isReadable;
  local itemLink = info and info.hyperlink;
  local isFiltered = info and info.isFiltered;
  local noValue = info and info.hasNoValue;
  local itemID = info and info.itemID;
  local isBound = info and info.isBound;
  local questInfo = C_Container.GetContainerItemQuestInfo(bagid, self.frame:GetID());
  local isQuestItem = questInfo.isQuestItem;
  local questID = questInfo.questID;
  local isActive = questInfo.isActive;

  local l = i:GetItemLocation()
  local bound = false
  if l ~= nil then
    bound = C_Item.IsBound(l)
  end

  self.IconTexture:SetTexture(i:GetItemIcon())
  self.IconTexture:SetTexCoord(0,1,0,1)
  --self.frame.GetBagID = function() return -1 end

  self.frame.GetItemContextMatchResult = nil
--[[
  ClearItemButtonOverlay(self.frame)
  self.frame:SetHasItem(i:GetItemIcon())
  --self.frame:SetItemButtonTexture(i:GetItemIcon())
  SetItemButtonQuality(self.frame, i:GetItemQuality(), i:GetItemLink(), false, bound);
  --SetItemButtonCount(self.frame, i:GetStackCount())
  SetItemButtonDesaturated(self.frame, i:IsItemLocked())
  --self.frame:UpdateExtended()
  self.frame:UpdateQuestItem(isQuestItem, questID, isActive)
  --self.frame:UpdateNewItem(i:GetItemQuality())
  --self.frame:UpdateJunkItem(i:GetItemQuality(), noValue)
  self.frame:UpdateItemContextMatching()
  --self.frame:UpdateCooldown(i:GetItemIcon())
  self.frame:SetReadable(readable)
  self.frame:CheckUpdateTooltip(tooltipOwner)
  self.frame:SetMatchesSearch(not isFiltered)
  --self.frame.PostOnShow = nil
  ]]--
  self.frame:Show()
end

function itemProto:OnEnter()
  self.mixin:GetItemID()
  GameTooltip:SetOwner(self.frame, "ANCHOR_RIGHT")
  GameTooltip:SetHyperlink(self.mixin:GetItemLink())
  GameTooltip:Show()
end

function itemProto:OnLeave()
  GameTooltip:Hide()
end

function itemProto:OnClick()
end

---@return Item
function item:Create()
  local i = setmetatable({}, { __index = itemProto })
  -- Generate the item button name. This is needed because item
  -- button textures are named after the button itself.
  local name = format("BetterBagsItemButton%d", buttonCount)
  buttonCount = buttonCount + 1

  ---@class ItemButton
  local f = CreateFrame("ItemButton", name, nil)

  -- Assign the global item button textures to the item button.
  for _, child in pairs(children) do
    i[child] = _G[name..child]
  end
  f:SetSize(37, 37)
  f:RegisterForDrag("LeftButton")
  f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  f:SetScript("OnEnter", function() i:OnEnter() end)
  f:SetScript("OnLeave", function() i:OnLeave() end)
  f:SetScript("OnClick", function() i:OnClick() end)
  i.frame = f

  return i
end

item:Enable()
