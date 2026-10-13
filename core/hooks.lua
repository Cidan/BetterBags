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

---@class Constants: AceModule
local const = addon:GetModule('Constants')

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

-- The Account (warband) banker only exists on clients with a warbank. WoW:
-- Forever (Camelot) has none, so don't register its interaction (Enum.
-- PlayerInteractionType.AccountBanker may not even exist there).
if addon.hasWarbank then
  interactionEvents[Enum.PlayerInteractionType.AccountBanker] = true
end

-- SetBlizzardBankType sets the bank type of Blizzard's hidden BankPanel, which decides where
-- right-click deposits go. Its own function so the profiler measures it: inline Blizzard calls
-- are not measured (perf-profiler.md §2). Do not inline it.
---@param bankType Enum.BankType
function addon.SetBlizzardBankType(bankType)
  if BankPanel and BankPanel.SetBankType then
    BankPanel:SetBankType(bankType)
  end
end

-- TriggerItemContextChanged makes every shown item button re-check whether it matches the open
-- window. Its own function so the profiler measures it, like SetBlizzardBankType.
function addon.TriggerItemContextChanged()
  ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
end

-- interactionRecalculation is what an interaction window opening or closing recalculates:
-- always the backpack (its grey-out depends on the open window), and the bank only when its
-- committed stacks were built under the other interaction state, its only input that depends
-- on it (items:NeedsInteractionRecalculation).
---@return table options for bags/Rederive
local function interactionRecalculation()
  local items = addon:GetModule('Items')
  return {
    resetLayout = true,
    backpack = true,
    bank = items:NeedsInteractionRecalculation(const.BAG_KIND.BANK),
  }
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
    addon.Bags.Backpack:Show(ctx)
    addon:UpdateButtonHighlight()
    if addon.atInteracting then
      events:SendMessage(ctx, 'bags/Rederive', interactionRecalculation())
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
function addon.OpenInteractionWindow(ctx, _, interactionType)
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
  events:SendMessageLater(ctx, 'bags/OpenClose')
end

---@param ctx Context
---@param interactionType Enum.PlayerInteractionType
function addon.CloseInteractionWindow(ctx, _, interactionType)
  if interactionEvents[interactionType] == nil then return end
  debug:Log("Interaction", "CloseInteractionWindow", interactionType)
  addon.atInteracting = false
  addon.atWarbank = false
  addon.backpackShouldClose = true
  events:SendMessage(ctx, 'bags/Rederive', interactionRecalculation())
  events:SendMessageLater(ctx, 'bags/OpenClose')
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
  events:SendMessage(ctx, 'bags/OpenClose')
end

---@param interactingFrame Frame
function addon:CloseSpecialWindows(interactingFrame)
  if interactingFrame ~= nil then return end

  local ctx = context:New('CloseSpecialWindows')
  ---@class Async: AceModule
  local async = addon:GetModule('Async')

  debug:Log('Hooks', 'CloseSpecialWindows')
  addon.backpackShouldClose = true
  if not addon.isRetail and addon.Bags.Bank then
    async:AfterCombat(ctx, function(ectx)
      addon.Bags.Bank:Hide(ectx)
      addon.Bags.Bank:SwitchToBankAndWipe(ectx)
    end)
  end
  events:SendMessage(ctx, 'addon/CloseSpecialWindows')

  -- Call CloseBankFrame() to exit banking mode and trigger BANKFRAME_CLOSED event.
  -- This is safe here (SecureHook runs after Blizzard's function completes).
  -- CRITICAL: Do NOT call this from OnHide - that runs in protected context and causes taint.
  if C_Bank then
    C_Bank.CloseBankFrame()
  else
    CloseBankFrame()
  end

  events:SendMessageLater(ctx, 'bags/OpenClose')
end

---@param ctx Context
---@param interactingFrame Frame
function addon.CloseBank(ctx, _, interactingFrame)
  debug:Log('Hooks', 'CloseBank')
  if interactingFrame ~= nil then return end
  if addon.Bags.Bank then
    addon.Bags.Bank:Hide(ctx)
    addon.Bags.Bank:SwitchToBankAndWipe(ctx)
  end

  -- Hide BankPanel in event handler context (safe from taint)
  -- This must happen AFTER the bank frame is hidden to prevent taint
  if BankPanel then
    BankPanel:Hide()
    -- Camelot: BankPanel.MoneyDisplay (BankBagCostMoneyDisplayMixin -- the "cost of the next
    -- bank tab" money frame) registers PLAYER_MONEY at login and stays registered, because
    -- BetterBags reparents BankFrame under a permanently-hidden frame (HideBlizzardBags), so
    -- MoneyDisplay is never effectively visible and its OnHide never fires. Event registration
    -- is independent of shown state, so Hide() does NOT unregister it (verified live:
    -- registered=true, shown=false). Left live, a gold change while away from the bank (e.g.
    -- looting) runs Blizzard's OnShowOrHideBagCost with a nil BankFrame:GetActiveBankType()
    -- (gated on BankPanel:IsShown(), which we just set false) and crashes on
    -- C_Bank.FetchNumPurchasedBankTabs(nil). We therefore UnregisterEvent it directly, in this
    -- taint-safe event context. Nil-guarded, so live retail (no MoneyDisplay) is unaffected.
    -- See camelot-forever.md.
    if BankPanel.MoneyDisplay then
      BankPanel.MoneyDisplay:UnregisterEvent("PLAYER_MONEY")
    end
  end

  events:SendMessage(ctx, 'bags/BankClosed')
end
