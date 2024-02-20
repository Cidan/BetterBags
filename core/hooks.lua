local addonName = ... ---@type string

---@class BetterBags: AceAddon
---@field backpackShouldOpen boolean
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)
---@cast addon +AceHook-3.0

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Events: AceModule
local events = addon:GetModule('Events')

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
    debug:Log('Hooks', 'OnUpdate', addon.backpackShouldOpen, addon.backpackShouldClose)
    addon.backpackShouldOpen = false
    addon.backpackShouldClose = false
    addon.Bags.Backpack:Show()
  elseif addon.backpackShouldClose then
    debug:Log('Hooks', 'OnUpdate', addon.backpackShouldOpen, addon.backpackShouldClose)
    addon.backpackShouldClose = false
    addon.Bags.Backpack:Hide()
  end
end

function addon:OpenAllBags(interactingFrame)
  if interactingFrame ~= nil then return end
  debug:Log('Hooks', 'OpenAllBags')
  addon.backpackShouldOpen = true
  events:SendMessageLater('bags/OpenClose')
end

---@param interactingFrame Frame
function addon:CloseAllBags(interactingFrame)
  if interactingFrame ~= nil then return end
  debug:Log('Hooks', 'CloseAllBags')
  addon.backpackShouldClose = true
  events:SendMessageLater('bags/OpenClose')
end

function addon:CloseBackpack(interactingFrame)
  if interactingFrame ~= nil then return end
  debug:Log('Hooks', 'CloseBackpack')
  addon.backpackShouldClose = true
  events:SendMessageLater('bags/OpenClose')
end

function addon:OpenBackpack(interactingFrame)
  if interactingFrame ~= nil then return end
  debug:Log('Hooks', 'OpenBackpack')
  addon.backpackShouldOpen = true
  events:SendMessageLater('bags/OpenClose')
end

function addon:ToggleBag(interactingFrame)
  if interactingFrame ~= nil then return end
  debug:Log('Hooks', 'ToggleBag')
  if addon.Bags.Backpack:IsShown() then
    addon.backpackShouldClose = true
  else
    addon.backpackShouldOpen = true
  end
  events:SendMessageLater('bags/OpenClose')
end

function addon:CloseBag(interactingFrame)
  if interactingFrame ~= nil then return end
  debug:Log('Hooks', 'CloseBag')
  addon.backpackShouldClose = true
  events:SendMessageLater('bags/OpenClose')
end

function addon:ToggleAllBags(interactingFrame)
  if interactingFrame ~= nil then return end
  debug:Log('Hooks', 'ToggleAllBags')
  if addon.Bags.Backpack:IsShown() then
    addon.backpackShouldClose = true
  else
    addon.backpackShouldOpen = true
  end
  events:SendMessageLater('bags/OpenClose')
end

function addon:ToggleBackpack(interactingFrame)
  if interactingFrame ~= nil then return end
  debug:Log('Hooks', 'ToggleBackpack')
  if addon.Bags.Backpack:IsShown() then
    addon.backpackShouldClose = true
  else
    addon.backpackShouldOpen = true
  end
  events:SendMessageLater('bags/OpenClose')
end

function addon:CloseSpecialWindows(interactingFrame)
  if interactingFrame ~= nil then return end
  debug:Log('Hooks', 'CloseSpecialWindows')
  addon.backpackShouldClose = true
  addon.Bags.Bank:Hide()
  addon.Bags.Bank:SwitchToBank()
  events:SendMessage('addon/CloseSpecialWindows')
  CloseBankFrame()
  events:SendMessageLater('bags/OpenClose')
end

function addon:OpenBank(interactingFrame)
  if interactingFrame ~= nil then return end
  debug:Log('Hooks', 'OpenBank')
  addon.Bags.Bank:Show()
  addon.Bags.Backpack:Show()
end

---@param interactingFrame Frame
function addon:CloseBank(interactingFrame)
  debug:Log('Hooks', 'CloseBank')
  if interactingFrame ~= nil then return end
  addon.Bags.Bank:Hide()
  addon.Bags.Bank:SwitchToBank()
end
