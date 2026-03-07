local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Zygor: AceModule
local zygor = addon:NewModule('Zygor')

---@param item Item
local function onItemUpdate(item)
  if not item.button.UpgradeIcon then return end
  local data = item:GetItemData()
  if not data then return end
  if data.isItemEmpty or not data.bagid or not data.slotid then
    item.button.UpgradeIcon:SetShown(false)
    return
  end
  local isUpgrade, _, _, _, comment = ZGV.ItemScore.Upgrades:IsUpgrade(data.itemInfo.itemLink)
  if comment == "not scored" or comment == "no link" then return end
  item.button.UpgradeIcon:SetShown(isUpgrade or false)
end

---@param bag Bag
local function onBagRendered(_, bag, _)
  if InCombatLockdown() then
    addon.Bags.Backpack.drawAfterCombat = true
    return
  end
  if database:GetUpgradeIconProvider() ~= 'Zygor' then return end
  if not ZGV.ItemScore.ActiveRuleSet then return end
  items:PreLoadAllEquipmentSlots(function()
    for _, item in pairs(bag.currentView:GetItemsByBagAndSlot()) do
      onItemUpdate(item)
    end
  end)
end

function zygor:OnEnable()
  if not ZGV or not ZGV.ItemScore or not ZGV.ItemScore.Upgrades then
    return
  end
  events:RegisterMessage('bag/Rendered', onBagRendered)
end
