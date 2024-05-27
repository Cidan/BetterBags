local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Async: AceModule
local async = addon:GetModule('Async')

---@class Pawn: AceModule
local pawn = addon:NewModule('Pawn')

local slots = {
  INVSLOT_AMMO,
  INVSLOT_BACK,
  INVSLOT_BODY,
  INVSLOT_CHEST,
  INVSLOT_FEET,
  INVSLOT_FINGER1,
  INVSLOT_FINGER2,
  INVSLOT_HAND,
  INVSLOT_HEAD,
  INVSLOT_LEGS,
  INVSLOT_MAINHAND,
  INVSLOT_NECK,
  INVSLOT_OFFHAND,
  INVSLOT_RANGED,
  INVSLOT_SHOULDER,
  INVSLOT_TABARD,
  INVSLOT_TRINKET1,
  INVSLOT_TRINKET2,
  INVSLOT_WAIST,
  INVSLOT_WRIST,
}

local function PreLoadAllEquipmentSlots(cb)
  local continuableContainer = ContinuableContainer:Create()
  for _, slot in pairs(slots) do
    local location = ItemLocation:CreateFromEquipmentSlot(slot)
    local item = Item:CreateFromItemLocation(location)
    if not item:IsItemEmpty() then
      continuableContainer:AddContinuable(item)
    end
  end
  continuableContainer:ContinueOnLoad(cb)
end

---@param item Item
local function onItemUpdateRetail(item)
  if not item.button.UpgradeIcon then return end
  local data = item:GetItemData()
  if not data then return end
  local bagid, slotid = data.bagid, data.slotid
  if data.isItemEmpty or not bagid or not slotid then
    item.button.UpgradeIcon:SetShown(false)
  else
    local isUpgrade = PawnShouldItemLinkHaveUpgradeArrowUnbudgeted(data.itemInfo.itemLink, true)
    item.button.UpgradeIcon:SetShown(isUpgrade or false)
  end
end

---@param item Item
local function onItemUpdateClassic(item)
  if not item.button.UpgradeIcon then return end
  local data = item:GetItemData()
  if not data then return end
  if data.isItemEmpty or not data.slotid or not data.bagid then
    item.button.UpgradeIcon:SetShown(false)
  else
    local isUpgrade = PawnShouldItemLinkHaveUpgradeArrowUnbudgeted(data.itemInfo.itemLink, true)
    item.button.UpgradeIcon:SetShown(isUpgrade or false)
  end
end

---@param bag Bag
local function onBagRendered(_, bag, _)
  PreLoadAllEquipmentSlots(function()
    for _, item in pairs(bag.currentView:GetItemsByBagAndSlot()) do
      if addon.isRetail then
        onItemUpdateRetail(item)
      else
        onItemUpdateClassic(item)
      end
    end
  end)
end

function pawn:OnEnable()
  if not PawnIsContainerItemAnUpgrade and not PawnGetItemData then
    return
  end
  events:RegisterMessage('bag/Rendered', onBagRendered)
  print("BetterBags: Pawn integration enabled.")
end
