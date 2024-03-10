local addonName = ... ---@type string

---@class BetterBags: AceAddon
---@field backpackShouldOpen boolean
---@field backpackShouldClose boolean
---@field atInteracting boolean
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)
---@cast addon +AceHook-3.0

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Events: AceModule
local events = addon:GetModule('Events')

addon.backpackShouldOpen = false
addon.backpackShouldClose = false

local interactionEvents = {
  [Enum.PlayerInteractionType.Banker] = true,
  [Enum.PlayerInteractionType.Merchant] = true,
  [Enum.PlayerInteractionType.MailInfo] = true,
  [Enum.PlayerInteractionType.Auctioneer] = true,
  [Enum.PlayerInteractionType.GuildBanker] = true,
  [Enum.PlayerInteractionType.VoidStorageBanker] = true,
}

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
    if addon.atInteracting then
      events:SendMessage('bags/RefreshAll')
    end
  elseif addon.backpackShouldClose then
    debug:Log('Hooks', 'OnUpdate', addon.backpackShouldOpen, addon.backpackShouldClose)
    addon.backpackShouldClose = false
    addon.Bags.Backpack:Hide()
  end
end

---@param interactionType Enum.PlayerInteractionType
function addon:OpenInteractionWindow(interactionType)
  if interactionEvents[interactionType] == nil then return end
  if GameMenuFrame:IsShown() then
    return
  end
  debug:Log("Interaction", "OpenInteractionWindow", interactionType)
  addon.atInteracting = true
  addon.backpackShouldOpen = true
  events:SendMessageLater('bags/OpenClose')
end

---@param interactionType Enum.PlayerInteractionType
function addon:CloseInteractionWindow(interactionType)
  if interactionEvents[interactionType] == nil then return end
  debug:Log("Interaction", "CloseInteractionWindow", interactionType)
  addon.atInteracting = false
  addon.backpackShouldClose = true
  events:SendMessage('bags/RefreshAll')
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
  if GameMenuFrame:IsShown() then
    return
  end
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
