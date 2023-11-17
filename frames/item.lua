local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class ItemFrame: AceModule
local item = addon:NewModule('ItemFrame')

---@class Item
---@field mixin ItemMixin
---@field guid string
---@field frame Frame
---@field button ItemButton
---@field itemType string
---@field itemSubType string
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
  self.guid = i:GetItemGUID() or ""
  local tooltipOwner = GameTooltip:GetOwner();
  local bagid, slotid = i:GetItemLocation():GetBagAndSlot()
  self.button:SetID(slotid)
  self.frame:SetID(bagid)

  -- TODO(lobato): Move all this to the items.lua database.
  local info = C_Container.GetContainerItemInfo(bagid, slotid)
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

function itemProto:GetCategory()
  return self.itemType
end

function itemProto:ClearItem()
  self.button:UnregisterEvent('BAG_UPDATE_COOLDOWN')
  self.button:UnregisterEvent('SPELL_UPDATE_COOLDOWN')
  self.button:SetScript('OnEvent', nil)
  self.mixin = nil
  self.guid = nil
  self.frame:ClearAllPoints()
  self.frame:SetParent(nil)
  self.frame:Hide()
  self.button:Hide()
  self.button:SetID(0)
  self.button:SetHasItem(false)
  self.frame:SetID(0)
end

function item:OnInitialize()
  self._pool = CreateObjectPool(self._DoCreate, self._DoReset)
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
  return i
end

---@return Item
function item:Create()
  ---@return Item
  return self._pool:Acquire()
end

---@param i Item
function item:Release(i)
  self._pool:Release(i)
end

item:Enable()
