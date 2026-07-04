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
  if request.wipe then
    self.pendingWipe = true
  end
  if request.backpack then
    self.pendingBackpack = true
  end
  if request.bank then
    self.pendingBank = true
  end

  if self.debounceTimer then
    self.debounceTimer:Cancel()
  end

  self.debounceTimer = C_Timer.NewTimer(0.01, function()
    self.debounceTimer = nil
    self:ExecutePendingUpdates()
  end)
end

-- ExecutePendingUpdates processes all pending update flags
function refresh:ExecutePendingUpdates()
  local ctx = context:New('BagUpdate')

  -- Prevent updates during combat
  if InCombatLockdown() then
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

    local refreshCtx = ctx:Copy()

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
  local itemLoader = addon:GetModule('ItemLoader')
  itemLoader:TellMeWhenABagIsUpdated(function(updatedBags)
    local backpackChanged = false
    local bankChanged = false

    for bagID in pairs(updatedBags) do
      if const.BACKPACK_BAGS[bagID] then
        backpackChanged = true
      elseif const.BANK_BAGS[bagID] or (const.ACCOUNT_BANK_BAGS and const.ACCOUNT_BANK_BAGS[bagID]) then
        bankChanged = true
      end
    end

    if backpackChanged or bankChanged then
      self:RequestUpdate({
        backpack = backpackChanged,
        bank = bankChanged
      })
    end
  end)

  events:RegisterMessage('bags/RefreshAll', function()
    self:RequestUpdate({ wipe = true, backpack = true, bank = true })
  end)
  events:RegisterMessage('bags/RefreshBackpack', function()
    self:RequestUpdate({ backpack = true })
  end)
  events:RegisterMessage('bags/RefreshBank', function()
    self:RequestUpdate({ bank = true })
  end)
end
