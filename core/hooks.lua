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

---@class Context: AceModule
local context = addon:GetModule('Context')

addon.backpackShouldOpen = false
addon.backpackShouldClose = false

local interactionEvents = {
  [Enum.PlayerInteractionType.TradePartner] = true,
  [Enum.PlayerInteractionType.Banker] = true,
  [Enum.PlayerInteractionType.Merchant] = true,
  [Enum.PlayerInteractionType.MailInfo] = true,
  [Enum.PlayerInteractionType.Auctioneer] = true,
  [Enum.PlayerInteractionType.GuildBanker] = true,
  [Enum.PlayerInteractionType.VoidStorageBanker] = true,
  [Enum.PlayerInteractionType.ScrappingMachine] = true,
  [Enum.PlayerInteractionType.ItemUpgrade] = true,
}

if addon.isRetail then
  interactionEvents[Enum.PlayerInteractionType.AccountBanker] = true
end

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

---@param ctx Context
function addon.OnUpdate(ctx)
  if addon.backpackShouldOpen then
    debug:Log('Hooks', 'OnUpdate', addon.backpackShouldOpen, addon.backpackShouldClose)
    addon.backpackShouldOpen = false
    addon.backpackShouldClose = false
    addon.Bags.Backpack:Show()
    addon:UpdateButtonHighlight()
    if addon.atInteracting then
      events:SendMessage('bags/FullRefreshAll', ctx)
    end
  elseif addon.backpackShouldClose then
    debug:Log('Hooks', 'OnUpdate', addon.backpackShouldOpen, addon.backpackShouldClose)
    addon.backpackShouldClose = false
    addon.Bags.Backpack:Hide(ctx)
    addon:UpdateButtonHighlight()
  end
end

---@param ctx Context
---@param interactionType Enum.PlayerInteractionType
function addon:OpenInteractionWindow(ctx, interactionType)
  if interactionEvents[interactionType] == nil then return end
  if GameMenuFrame:IsShown() then
    return
  end
  debug:Log("Interaction", "OpenInteractionWindow", interactionType)
  if interactionType == Enum.PlayerInteractionType.AccountBanker then
    addon.atWarbank = true
  end
  addon.atInteracting = true
  addon.backpackShouldOpen = true
  events:SendMessageLater('bags/OpenClose', ctx)
end

---@param ctx Context
---@param interactionType Enum.PlayerInteractionType
function addon:CloseInteractionWindow(ctx, interactionType)
  if interactionEvents[interactionType] == nil then return end
  debug:Log("Interaction", "CloseInteractionWindow", interactionType)
  addon.atInteracting = false
  addon.atWarbank = false
  addon.backpackShouldClose = true
  events:SendMessage('bags/FullRefreshAll', ctx)
  events:SendMessageLater('bags/OpenClose', ctx)
end

---@param ctx Context
---@param interactingFrame? Frame
function addon:ToggleAllBags(ctx, interactingFrame)
  if interactingFrame ~= nil then return end
  ctx = ctx or context:New('ToggleAllBags')
  debug:Log('Hooks', 'ToggleAllBags')
  if addon.Bags.Backpack:IsShown() then
    addon.backpackShouldClose = true
  else
    addon.backpackShouldOpen = true
  end
  events:SendMessage('bags/OpenClose', ctx)
end

---@param interactingFrame Frame
function addon:CloseSpecialWindows(interactingFrame)
  if interactingFrame ~= nil then return end

  local ctx = context:New('CloseSpecialWindows')
  ---@class Async: AceModule
  local async = addon:GetModule('Async')

  debug:Log('Hooks', 'CloseSpecialWindows')
  addon.backpackShouldClose = true
  async:AfterCombat(function()
    addon.Bags.Bank:Hide(ctx)
    addon.Bags.Bank:SwitchToBankAndWipe(ctx)
  end)
  events:SendMessage('addon/CloseSpecialWindows', ctx)
  if C_Bank then
    C_Bank.CloseBankFrame()
  else
    CloseBankFrame()
  end
  events:SendMessageLater('bags/OpenClose', ctx)
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

---@param ctx Context
---@param interactingFrame Frame
function addon:CloseBank(ctx, interactingFrame)
  debug:Log('Hooks', 'CloseBank')
  if interactingFrame ~= nil then return end
  addon.Bags.Bank:Hide(ctx)
  addon.Bags.Bank:SwitchToBankAndWipe(ctx)
  events:SendMessage('bags/BankClosed', ctx)
end
