local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class SimpleItemLevel: AceModule
local simpleItemLevel = addon:NewModule('SimpleItemLevel')

function simpleItemLevel:OnEnable()
  if not SimpleItemLevel then return end

  items:RegisterUpgradeProvider("SimpleItemLevel", function(data)
    if not data or data.isItemEmpty or not data.itemInfo or not data.itemInfo.itemLink then
      return false
    end
    local isUpgrade = SimpleItemLevel.API.ItemIsUpgrade(data.itemInfo.itemLink)
    return isUpgrade or false
  end)

  print("BetterBags: SimpleItemLevel integration enabled.")
end
