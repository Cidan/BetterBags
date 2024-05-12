local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Pawn: AceModule
local pawn = addon:NewModule('Pawn')

---@param item Item
local function onItemUpdateRetail(item)
  if not item.button.UpgradeIcon then return end
  local data = item:GetItemData()
  if not data then return end
  local bagid, slotid = data.bagid, data.slotid
  if data.isItemEmpty or not bagid or not slotid then
    item.button.UpgradeIcon:SetShown(false)
  else
    item.button.UpgradeIcon:SetShown(PawnIsContainerItemAnUpgrade(bagid, slotid) or false)
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
    local isUpgrade = PawnShouldItemLinkHaveUpgradeArrowUnbudgeted(data.itemInfo.itemLink)
    item.button.UpgradeIcon:SetShown(isUpgrade or false)
  end
end

---@param bag Bag
local function onBagRendered(_, bag, _)
  for _, item in pairs(bag.currentView:GetItemsByBagAndSlot()) do
    if addon.isRetail then
      onItemUpdateRetail(item)
    else
      onItemUpdateClassic(item)
    end
  end
end

function pawn:OnEnable()
  if not PawnIsContainerItemAnUpgrade and not PawnGetItemData then
    return
  end
  events:RegisterMessage('bag/Rendered', onBagRendered)
  print("BetterBags: Pawn integration enabled.")
end