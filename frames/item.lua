local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class MasqueTheme: AceModule
local masque = addon:GetModule('Masque')

---@class ItemFrame: AceModule
local item = addon:NewModule('ItemFrame')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Item
---@field name string
---@field mixin ItemMixin
---@field guid string
---@field frame Frame
---@field button ItemButton
---@field itemType string
---@field itemSubType string
---@field masqueGroup string
---@field info ContainerItemInfo
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

-- OnEvent is the event handler for the item button.
---@param i Item
---@param event string
local function OnEvent(i, event, ...)
  if event == 'BAG_UPDATE_COOLDOWN' or event == 'SPELL_UPDATE_COOLDOWN' then
    i.button:UpdateCooldown(i.mixin:GetItemIcon())
  end
end

---@param i ItemMixin
function itemProto:SetItem(i)
  assert(i, 'item must be provided')
  self.mixin = i
  self.name = i:GetItemName() or ""
  self.guid = i:GetItemGUID() or ""
  local tooltipOwner = GameTooltip:GetOwner();
  local bagid, slotid = i:GetItemLocation():GetBagAndSlot()
  self.button:SetID(slotid)
  self.frame:SetID(bagid)

  -- TODO(lobato): Move all this to the items.lua database.
  local info = C_Container.GetContainerItemInfo(bagid, slotid)
  self.info = info
  local readable = info and info.isReadable;
  local isFiltered = info and info.isFiltered;
  local noValue = info and info.hasNoValue;
  local questInfo = C_Container.GetContainerItemQuestInfo(bagid, slotid)
  local isQuestItem = questInfo.isQuestItem;
  local questID = questInfo.questID;
  local isActive = questInfo.isActive
  local _, _, _, _, _, itemType, itemSubType = GetItemInfo(i:GetItemID() or 0)
  self.itemType = itemType or "unknown"
  self.itemSubType = itemSubType or "unknown"
  local l = i:GetItemLocation()
  local bound = false
  if l ~= nil then
    bound = C_Item.IsBound(l)
  end


  ClearItemButtonOverlay(self.button)
  self.button:SetHasItem(i:GetItemIcon())
  self.button:SetItemButtonTexture(i:GetItemIcon())
  SetItemButtonQuality(self.button, i:GetItemQuality(), i:GetItemLink(), false, bound);
  SetItemButtonCount(self.button, i:GetStackCount())
  SetItemButtonDesaturated(self.button, i:IsItemLocked())
  self.button:UpdateExtended()
  self.button:UpdateQuestItem(isQuestItem, questID, isActive)
  self.button:UpdateNewItem(i:GetItemQuality())
  self.button:UpdateJunkItem(i:GetItemQuality(), noValue)
  self.button:UpdateItemContextMatching()
  self.button:UpdateCooldown(i:GetItemIcon())
  self.button:SetReadable(readable)
  self.button:CheckUpdateTooltip(tooltipOwner)
  self.button:SetMatchesSearch(not isFiltered)
  self.button:RegisterEvent('BAG_UPDATE_COOLDOWN')
  self.button:RegisterEvent('SPELL_UPDATE_COOLDOWN')
  self.button:SetScript('OnEvent', function(_, event, ...) OnEvent(self, event, ...) end)
  self.frame:Show()
  self.button:Show()
end

-- SetFreeSlots will set the item button to a free slot.
function itemProto:SetFreeSlots(bagid, slotid, count)
  self.button:SetID(slotid)
  self.frame:SetID(bagid)

  ClearItemButtonOverlay(self.button)
  self.button:SetHasItem(false)
  SetItemButtonCount(self.button, count)
  self.button.ItemSlotBackground:Show()
  self.frame:Show()
  self.button:Show()
end

function itemProto:GetCategory()
  -- TODO(lobato): Handle cases such as new items here instead of in the layout engine.
  if self.info.quality == Enum.ItemQuality.Poor then
    return L:G('Junk')
  end
  return self.itemType
end

---@return boolean
function itemProto:IsNewItem()
  if self.button.NewItemTexture:IsShown() then
    return true
  end
  return C_NewItems.IsNewItem(self.mixin:GetItemLocation():GetBagAndSlot())
end

function itemProto:Release()
  item._pool:Release(self)
end

function itemProto:ClearItem()
  masque:RemoveButtonFromGroup(self.masqueGroup, self.button)
  self.masqueGroup = nil
  self.button:UnregisterEvent('BAG_UPDATE_COOLDOWN')
  self.button:UnregisterEvent('SPELL_UPDATE_COOLDOWN')
  self.button:SetScript('OnEvent', nil)
  self.mixin = nil
  self.guid = nil
  self.name = nil
  self.frame:ClearAllPoints()
  self.frame:SetParent(nil)
  self.frame:Hide()
  self.button:SetHasItem(false)
  self.button:SetItemButtonTexture(0)
  self.button:UpdateQuestItem(false, nil, nil)
  self.button:UpdateNewItem(false)
  self.button:UpdateJunkItem(false, false)
  self.button:UpdateItemContextMatching()
  SetItemButtonQuality(self.button, false);
  SetItemButtonCount(self.button, 0)
  SetItemButtonDesaturated(self.button, false)
  ClearItemButtonOverlay(self.button)
  self.button.ItemSlotBackground:Hide()
  self.frame:SetID(0)
  self.button:SetID(0)
  self.itemType = nil
  self.itemSubType = nil
end

---@param kind BagKind
function itemProto:AddToMasqueGroup(kind)
  if kind == const.BAG_KIND.BANK then
    self.masqueGroup = "Bank"
    masque:AddButtonToGroup(self.masqueGroup, self.button)
  else
    self.masqueGroup = "Backpack"
    masque:AddButtonToGroup(self.masqueGroup, self.button)
  end
end

function item:OnInitialize()
  self._pool = CreateObjectPool(self._DoCreate, self._DoReset)
  self._pool:SetResetDisallowedIfNew()
end

---@param i Item
function item:_DoReset(i)
  i:ClearItem()
end

function item:_DoCreate()
  local i = setmetatable({}, { __index = itemProto })
  -- Generate the item button name. This is needed because item
  -- button textures are named after the button itself.
  local name = format("BetterBagsItemButton%d", buttonCount)
  buttonCount = buttonCount + 1

  -- Create a hidden parent to the ItemButton frame to work around
  -- item taint introduced in 10.x
  local p = CreateFrame("Frame")

  ---@class ItemButton
  local button = CreateFrame("ItemButton", name, p, "ContainerFrameItemButtonTemplate")

  -- Assign the global item button textures to the item button.
  for _, child in pairs(children) do
    i[child] = _G[name..child]
  end

  p:SetSize(37, 37)
  button:SetSize(37, 37)
  button:RegisterForDrag("LeftButton")
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  i.button = button
  button:SetAllPoints(p)
  i.frame = p

  button.ItemSlotBackground = button:CreateTexture(nil, "BACKGROUND", "ItemSlotBackgroundCombinedBagsTemplate", -6);
  button.ItemSlotBackground:SetAllPoints(button);
  button.ItemSlotBackground:Hide()
  return i
end

---@return Item
function item:Create()
  ---@return Item
  return self._pool:Acquire()
end

item:Enable()
