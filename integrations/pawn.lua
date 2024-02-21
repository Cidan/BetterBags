local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Pawn: AceModule
local pawn = addon:NewModule('Pawn')

---@param event string
---@param item Item
local function onItemUpdateRetail(event, item)
  local bagid, slotid = item.data.bagid, item.data.slotid
  if item.data.isItemEmpty or event == 'item/Clearing' then
    item.button.UpgradeIcon:SetShown(false)
  else
    item.button.UpgradeIcon:SetShown(PawnIsContainerItemAnUpgrade(bagid, slotid) or false)
  end
end

---@param event string
---@param item Item
local function onItemUpdateClassic(event, item)
  if item.data.isItemEmpty or event == 'item/Clearing' then
    item.button.UpgradeIcon:SetShown(false)
  else
    local pawnData = PawnGetItemData(item.data.itemInfo.itemLink)
    if not pawnData then
      item.button.UpgradeIcon:SetShown(false)
      return
    end
    local isUpgrade = PawnIsItemAnUpgrade(pawnData)
    item.button.UpgradeIcon:SetShown(isUpgrade or false)
  end
end

function pawn:OnEnable()
  if not PawnIsContainerItemAnUpgrade and not PawnGetItemData then
    return
  end
  print("BetterBags: Pawn integration enabled.")
  if addon.isRetail then
    events:RegisterMessage('item/Updated', onItemUpdateRetail)
  else
    events:RegisterMessage('item/Updated', onItemUpdateClassic)
  end
end