local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Pawn: AceModule
local pawn = addon:NewModule('Pawn')

---@param event string
---@param item Item
local function onItemUpdate(event, item)
  local bagid, slotid = item.data.bagid, item.data.slotid
  if item.data.isItemEmpty or event == 'item/Clearing' then
    item.button.UpgradeIcon:SetShown(false)
  else
    item.button.UpgradeIcon:SetShown(PawnIsContainerItemAnUpgrade(bagid, slotid) or false)
  end
end

function pawn:OnEnable()
  if not PawnVersion then return end
  print("BetterBags: Pawn integration enabled.")
  events:RegisterMessage('item/Updated', onItemUpdate)
end