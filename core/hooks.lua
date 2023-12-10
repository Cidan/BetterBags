local addonName = ... ---@type string

---@class BetterBags: AceAddon
---@field backpackShouldOpen boolean
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)
---@cast addon +AceHook-3.0

addon.backpackShouldOpen = false
addon.backpackShouldClose = false

function addon.ForceHideBlizzardBags()
  for i = 1, NUM_TOTAL_BAG_FRAMES, 1 do
    CloseBag(i)
  end
end

function addon.ForceShowBlizzardBags()
  for i = 1, NUM_TOTAL_BAG_FRAMES, 1 do
    OpenBag(i)
  end
end

function addon.OnUpdate()
  if addon.backpackShouldOpen then
    addon.backpackShouldOpen = false
    addon.ForceShowBlizzardBags()
    addon.Bags.Backpack:Show()
  elseif addon.backpackShouldClose then
    addon.backpackShouldClose = false
    addon.ForceHideBlizzardBags()
    addon.Bags.Backpack:Hide()
  end
end

function addon:OpenAllBags()
  addon.backpackShouldOpen = true
end

---@param interactingFrame Frame
function addon:CloseAllBags(interactingFrame)
  if interactingFrame ~= nil then return end
  addon.backpackShouldClose = true
end

function addon:CloseBackpack()
  addon.backpackShouldClose = true
end

function addon:OpenBackpack()
  addon.backpackShouldOpen = true
end

function addon:ToggleBag()
  if addon.Bags.Backpack:IsShown() then
    addon.backpackShouldClose = true
  else
    addon.backpackShouldOpen = true
  end
end

function addon:CloseBag()
  addon.backpackShouldClose = true
end

function addon:ToggleAllBags()
  if addon.Bags.Backpack:IsShown() then
    addon.backpackShouldClose = true
  else
    addon.backpackShouldOpen = true
  end
end

function addon:ToggleBackpack()
  if addon.Bags.Backpack:IsShown() then
    addon.backpackShouldClose = true
  else
    addon.backpackShouldOpen = true
  end
end

function addon:CloseSpecialWindows()
  addon.backpackShouldClose = true
  addon.Bags.Bank:Hide()
  addon.Bags.Bank:SwitchToBank()
  CloseBankFrame()
end

function addon:OpenBank()
  addon.Bags.Bank:Show()
  addon.Bags.Backpack:Show()
end

---@param interactingFrame Frame
function addon:CloseBank(interactingFrame)
  if interactingFrame ~= nil then return end
  addon.Bags.Bank:Hide()
  addon.Bags.Bank:SwitchToBank()
end
