local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Pawn: AceModule
local pawn = addon:NewModule('Pawn')

function pawn:OnEnable()
  if not PawnIsContainerItemAnUpgrade and not PawnGetItemData then
    return
  end

  items:RegisterUpgradeProvider("Pawn", function(data)
    if not data or data.isItemEmpty or not data.itemInfo or not data.itemInfo.itemLink then
      return false
    end
    local isUpgrade = PawnShouldItemLinkHaveUpgradeArrowUnbudgeted(data.itemInfo.itemLink, true)
    return isUpgrade or false
  end)

  print("BetterBags: Pawn integration enabled.")
end
