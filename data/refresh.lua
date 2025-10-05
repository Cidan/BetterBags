local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class (exact) Refresh: AceModule
---@field private pendingBackpack boolean
---@field private pendingBank boolean
---@field private pendingWipe boolean
---@field private debounceTimer table?
---@field private isSorting boolean
local refresh = addon:NewModule('Refresh')

function refresh:OnInitialize()
  self.pendingBackpack = false
  self.pendingBank = false
  self.pendingWipe = false
  self.debounceTimer = nil
  self.isSorting = false
end

---@param ctx Context
function refresh:RedrawBackpack(ctx)
  debug:Log('RedrawBackpack', 'Redrawing backpack')
  ctx:Set('redraw', true)
  addon.Bags.Backpack:Draw(ctx, items:GetAllSlotInfo()[const.BAG_KIND.BACKPACK], function()
    events:SendMessage(ctx, 'bags/Draw/Backpack/Done')
  end)
end

function refresh:AfterSort(ctx)
  -- TODO(lobato): Detect if only new items were moved,
  -- and only refresh the backpack if that's the case.
  -- After moving an item, the client state does not update right
  -- away, and there is a delay. This delay will prevent issues
  -- with drawing.
  C_Timer.After(0.5, function()
    self.isSorting = false
    events:SendMessage(ctx, 'bags/FullRefreshAll')
  end)

  --if ctx:GetBool('moved') then
  --  events:SendMessage(ctx, 'bags/FullRefreshAll')
  --else
  --  events:SendMessage(ctx, 'bags/FullRefreshAll')
  --end
end

-- RequestUpdate queues an update and debounces it
---@class RefreshRequest
---@field wipe? boolean Clear cache before refresh
---@field backpack? boolean Update backpack items
---@field bank? boolean Update bank items
---@field sort? boolean Sort backpack items

---@param request RefreshRequest
function refresh:RequestUpdate(request)
  -- Don't queue updates during sorting
  if self.isSorting then
    return
  end

  -- Set pending flags
  if request.wipe then
    self.pendingWipe = true
  end
  if request.backpack then
    self.pendingBackpack = true
  end
  if request.bank then
    self.pendingBank = true
  end

  -- Handle sorting immediately
  if request.sort and not InCombatLockdown() then
    self.isSorting = true
    items:RemoveNewItemFromAllItems()
    local ctx = context:New('BagSort')
    items:Restack(ctx, const.BAG_KIND.BACKPACK, function()
      self:AfterSort(ctx)
    end)
    return
  end

  -- Cancel existing debounce timer
  if self.debounceTimer then
    self.debounceTimer:Cancel()
  end

  -- Debounce: wait 0.05s before executing
  self.debounceTimer = C_Timer.NewTimer(0.05, function()
    self:ExecutePendingUpdates()
  end)
end

-- ExecutePendingUpdates processes all pending update flags
function refresh:ExecutePendingUpdates()
  local ctx = context:New('BagUpdate')

  -- Prevent wipes during combat
  if self.pendingWipe and InCombatLockdown() then
    self.pendingBackpack = false
    self.pendingBank = false
    self.pendingWipe = false
    return
  end

  -- Handle wipe
  if self.pendingWipe then
    items:ClearItemCache(ctx)
    ctx:Set('wipe', true)
    self.pendingBackpack = true
    self.pendingBank = true
  end

  -- Update bank if needed and at bank
  if self.pendingBank and addon.atBank and addon.Bags.Bank then
    local accountBankStart = addon.isRetail and Enum.BagIndex.AccountBankTab_1 or const.BANK_TAB.ACCOUNT_BANK_1
    if addon.atWarbank and addon.Bags.Bank.bankTab and accountBankStart and addon.Bags.Bank.bankTab < accountBankStart then
      addon.Bags.Bank.bankTab = accountBankStart
    end

    local database = addon:GetModule('Database')
    local refreshCtx = ctx:Copy()

    -- Check if the context already has a filterBagID set (from tab switching)
    local existingFilter = ctx:Get('filterBagID')
    if existingFilter ~= nil then
      refreshCtx:Set('filterBagID', existingFilter)
    elseif addon.atWarbank then
      refreshCtx:Set('filterBagID', addon.Bags.Bank.bankTab)
    else
      local currentTab = addon.Bags.Bank.bankTab
      accountBankStart = addon.isRetail and Enum.BagIndex.AccountBankTab_1 or 13

      if currentTab >= accountBankStart then
        refreshCtx:Set('filterBagID', nil)
      elseif database:GetCharacterBankTabsEnabled() then
        if currentTab >= Enum.BagIndex.CharacterBankTab_1 and currentTab <= Enum.BagIndex.CharacterBankTab_6 then
          refreshCtx:Set('filterBagID', currentTab)
        else
          refreshCtx:Set('filterBagID', Enum.BagIndex.CharacterBankTab_1)
        end
      else
        refreshCtx:Set('filterBagID', nil)
      end
    end

    items:RefreshBank(refreshCtx)
  end

  -- Update backpack if needed
  if self.pendingBackpack then
    items:RefreshBackpack(ctx)
  end

  -- Reset pending flags
  self.pendingBackpack = false
  self.pendingBank = false
  self.pendingWipe = false
end

function refresh:OnEnable()

  -- Register for main bag update events from the WoW client.
  events:CatchUntil('BAG_UPDATE', 'BAG_UPDATE_DELAYED', function(_, eventList)
    local updateBackpack = false
    local updateBank = false

    -- Process all bag update events
    for _, event in pairs(eventList) do
      if const.BANK_BAGS[event.args[1]] or const.ACCOUNT_BANK_BAGS[event.args[1]] then
        updateBank = true
      elseif const.BACKPACK_BAGS[event.args[1]] then
        updateBackpack = true
      end
    end

    -- If no specific bags, update both
    if #eventList == 0 or (not updateBackpack and not updateBank) then
      updateBackpack = true
      updateBank = true
    end

    self:RequestUpdate({ backpack = updateBackpack, bank = updateBank })
  end)

  if not addon.isRetail then
    -- Register when bank slots change for any reason.
    events:RegisterEvent('PLAYERBANKSLOTS_CHANGED', function(_, _, slot)
      self:RequestUpdate({
        wipe = slot > NUM_BANKGENERIC_SLOTS,
        bank = true
      })
    end)
  end

  -- Register when the bag slots change for any reason.
  events:RegisterEvent('BAG_CONTAINER_UPDATE', function()
    self:RequestUpdate({ wipe = true, backpack = true })
  end)

  -- Register when equipment sets change.
  events:RegisterEvent('EQUIPMENT_SETS_CHANGED', function()
    self:RequestUpdate({ wipe = true, backpack = true, bank = true })
  end)

  -- Register when combat ends and execute any pending updates
  events:RegisterEvent('PLAYER_REGEN_ENABLED', function()
    if self.pendingBackpack or self.pendingBank or self.pendingWipe then
      self:ExecutePendingUpdates()
    end
  end)

  events:RegisterMessage('bags/Backpack/Redraw', function(ctx)
    self:RedrawBackpack(ctx)
  end)

  -- Register when the backpack is manually refreshed.
  events:RegisterMessage('bags/RefreshBackpack', function(_, _, shouldWipe)
    self:RequestUpdate({ wipe = shouldWipe, backpack = true })
  end)

  -- Register when the bank is manually refreshed.
  events:RegisterMessage('bags/RefreshBank', function (_, _, shouldWipe)
    self:RequestUpdate({ wipe = shouldWipe, bank = true })
  end)

  -- Register when everything should be refreshed, manually.
  events:RegisterMessage('bags/RefreshAll', function()
    self:RequestUpdate({ backpack = true, bank = true })
  end)

  -- Register when then backpack should be sorted.
  events:RegisterMessage('bags/SortBackpack', function()
    self:RequestUpdate({ sort = true })
  end)

  -- Register when all bags should be wiped and reloaded.
  events:RegisterMessage('bags/FullRefreshAll', function()
    self:RequestUpdate({ wipe = true, backpack = true, bank = true })
  end)

end
