local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

function addon:OpenAllBags(requesterFrame)
  addon.Bags.Backpack:Show()
end

function addon:ToggleAllBags(requesterFrame)
  addon.Bags.Backpack:Toggle()
end