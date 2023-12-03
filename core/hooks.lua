local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)
---@cast addon +AceHook-3.0

function addon:OpenAllBags()
  addon.Bags.Backpack:Show()
end

function addon:CloseAllBags()
  addon.Bags.Backpack:Hide()
end

function addon:CloseBackpack()
  addon.Bags.Backpack:Hide()
end

function addon:OpenBackpack()
  addon.Bags.Backpack:Show()
end

function addon:ToggleBag()
  print("toggle")
end

function addon:CloseBag()
  print("Close Bag")
end

function addon:ToggleAllBags()
  addon.Bags.Backpack:Toggle()
end

function addon:ToggleBackpack()
  addon.Bags.Backpack:Show()
end

function addon:CloseSpecialWindows()
  addon.Bags.Backpack:Hide()
  addon.Bags.Bank:Hide()
  addon.Bags.Bank:SwitchToBank()
  CloseBankFrame()
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
