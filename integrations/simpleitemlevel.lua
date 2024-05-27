local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class SimpleItemLevel: AceModule
local simpleItemLevel = addon:NewModule('SimpleItemLevel')

---@param item Item
local function onItemUpdate(item)
  if not item.button.UpgradeIcon then return end
  local data = item:GetItemData()
  if not data then return end
  if data.isItemEmpty or not data.slotid or not data.bagid then
    item.button.UpgradeIcon:SetShown(false)
  else
    local isUpgrade = SimpleItemLevel.API.ItemIsUpgrade(data.itemInfo.itemLink)
    item.button.UpgradeIcon:SetShown(isUpgrade or false)
  end
end

---@param bag Bag
local function onBagRendered(_, bag, _)
  items:PreLoadAllEquipmentSlots(function()
    for _, item in pairs(bag.currentView:GetItemsByBagAndSlot()) do
      onItemUpdate(item)
    end
  end)
end

function simpleItemLevel:OnEnable()
  if not SimpleItemLevel then return end
  events:RegisterMessage('bag/Rendered', onBagRendered)
  print("BetterBags: SimpleItemLevel integration enabled.")
end