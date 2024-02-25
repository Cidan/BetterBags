local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Pawn: AceModule
local pawn = addon:NewModule('Pawn')

---@param item Item
local function onItemUpdateRetail(item)
  local bagid, slotid = item.data.bagid, item.data.slotid
  if item.data.isItemEmpty or not bagid or not slotid then
    item.button.UpgradeIcon:SetShown(false)
  else
    item.button.UpgradeIcon:SetShown(PawnIsContainerItemAnUpgrade(bagid, slotid) or false)
  end
end

---@param item Item
local function onItemUpdateClassic(item)
  if item.data.isItemEmpty or not item.data.slotid or not item.data.bagid then
    item.button.UpgradeIcon:SetShown(false)
  else
    local isUpgrade = PawnShouldItemLinkHaveUpgradeArrow(item.data.itemInfo.itemLink)
    item.button.UpgradeIcon:SetShown(isUpgrade or false)
  end
end

---@param bag Bag
local function onBagRendered(_, bag)
  for _, item in pairs(bag.currentView.itemsByBagAndSlot) do
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