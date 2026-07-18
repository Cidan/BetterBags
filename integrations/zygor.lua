local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Zygor: AceModule
local zygor = addon:NewModule('Zygor')

function zygor:OnEnable()
  if not ZGV or not ZGV.ItemScore or not ZGV.ItemScore.Upgrades then
    return
  end

  items:RegisterUpgradeProvider("Zygor", function(data)
    if not data or data.isItemEmpty or not data.itemInfo or not data.itemInfo.itemLink then
      return false
    end
    if not ZGV.ItemScore.ActiveRuleSet then
      return false
    end
    local isUpgrade, _, _, _, comment = ZGV.ItemScore.Upgrades:IsUpgrade(data.itemInfo.itemLink)
    if comment == "not scored" or comment == "no link" then
      -- Zygor does not score trinkets; fall back to an ilvl-based comparison.
      -- A trinket is an upgrade if its ilvl exceeds at least one equipped
      -- trinket, or if a trinket slot is empty. This does not imply full
      -- stat/effect evaluation.
      local ilvl = data.itemInfo.currentItemLevel
      if data.itemInfo.itemEquipLoc == "INVTYPE_TRINKET" and ilvl and ilvl > 0 then
        for _, slot in pairs({INVSLOT_TRINKET1, INVSLOT_TRINKET2}) do
          local equippedItem = items:GetItemDataFromInventorySlot(slot)
          if equippedItem and not equippedItem.isItemEmpty then
            if ilvl > equippedItem.itemInfo.currentItemLevel then
              return true
            end
          else
            return true
          end
        end
      end
      return false
    end
    return isUpgrade or false
  end)

  print("BetterBags: Zygor ItemScore integration enabled.")
end
