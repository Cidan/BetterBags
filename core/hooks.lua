local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

function addon:OpenAllBags()
  addon.Bags.Backpack:Show()
end

function addon:CloseAllBags()
  addon.Bags.Backpack:Hide()
end

function addon:ToggleAllBags()
  addon.Bags.Backpack:Toggle()
end

function addon:OpenBank()
  addon.Bags.Bank:Show()
  addon.Bags.Backpack:Show()
end

function addon:CloseBank()
  addon.Bags.Bank:Hide()
  addon.Bags.Backpack:Hide()
  addon.Bags.Bank:SwitchToBank()
end