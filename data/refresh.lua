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
---@field private isSorting boolean
local refresh = addon:NewModule('Refresh')

function refresh:OnInitialize()
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

-- RequestUpdate processes an update request instantly and synchronously
---@class RefreshRequest
---@field wipe? boolean Clear cache before refresh
---@field backpack? boolean Update backpack items
---@field bank? boolean Update bank items
---@field sort? boolean Sort backpack items

---@param request RefreshRequest
function refresh:RequestUpdate(request)
  if InCombatLockdown() then
    if not self.pendingRequest then
      self.pendingRequest = {}
    end
    for k, v in pairs(request) do
      if v then
        self.pendingRequest[k] = true
      end
    end
    return
  end

  local ctx = context:New('BagUpdate')

  if request.wipe then
    items:ClearItemCache(ctx)
    ctx:Set('wipe', true)
    request.backpack = true
    request.bank = true
  end

  if request.bank and addon.atBank and addon.Bags.Bank then
    local accountBankStart = addon.isRetail and Enum.BagIndex.AccountBankTab_1 or const.BANK_TAB.ACCOUNT_BANK_1
    if addon.atWarbank and addon.Bags.Bank.bankTab and accountBankStart and addon.Bags.Bank.bankTab < accountBankStart then
      addon.Bags.Bank.bankTab = accountBankStart
    end

    local refreshCtx = ctx:Copy()
    items:RefreshBank(refreshCtx)
  end

  if request.backpack then
    items:RefreshBackpack(ctx)
  end
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
  events:RegisterMessage('bags/FullRefreshAll', function()
    self:RequestUpdate({ wipe = true, backpack = true, bank = true })
  end)
  events:RegisterMessage('bags/RefreshBackpack', function()
    self:RequestUpdate({ backpack = true })
  end)
  events:RegisterMessage('bags/RefreshBank', function()
    self:RequestUpdate({ bank = true })
  end)

  events:RegisterEvent('PLAYER_REGEN_ENABLED', function()
    if self.pendingRequest then
      local req = self.pendingRequest
      self.pendingRequest = nil
      self:RequestUpdate(req)
    end
  end)

  events:RegisterEvent('BAG_CONTAINER_UPDATE', function()
    self:RequestUpdate({ wipe = true, backpack = true, bank = true })
  end)

  events:RegisterEvent('EQUIPMENT_SETS_CHANGED', function()
    self:RequestUpdate({ wipe = true, backpack = true, bank = true })
  end)

  if not addon.isRetail then
    events:RegisterEvent('PLAYERBANKSLOTS_CHANGED', function()
      self:RequestUpdate({ wipe = true, bank = true })
    end)
  end

  self:RequestUpdate({ wipe = true, backpack = true, bank = true })
end
