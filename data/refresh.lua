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

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class (exact) Refresh: AceModule
local refresh = addon:NewModule('Refresh')

-- How long a sort waits for its item moves before refreshing anyway. WoW has no "sort
-- finished" event, and a sort that moves nothing fires no BAG_UPDATE at all.
refresh.SORT_FALLBACK_SECONDS = 0.5

function refresh:Init()
  -- Serialized refresh queue. RequestUpdate only enqueues; the pump (_Step) runs exactly
  -- ONE unit at a time in a single coroutine, with a deliberate idle hand-off frame
  -- between units. Because no two sweeps are ever in flight, no request-time side effect
  -- (ClearItemCache / ClearNewItems / Sort) can mutate state a parked sweep still depends
  -- on, and a unit's commit+draw can never share a frame with the next unit's harvest.
  self._queue = {}
  self._active = nil
  self._idlePending = false
  self._running = false
end

---@param ctx Context
function refresh:RedrawBackpack(ctx)
  debug:Log('RedrawBackpack', 'Redrawing backpack')
  ctx:Set('redraw', true)
  addon.Bags.Backpack:Draw(ctx, items:GetAllSlotInfo()[const.BAG_KIND.BACKPACK], function()
    events:SendMessage(ctx, 'bags/Draw/Backpack/Done')
  end)
end

---@class RefreshRequest
---@field wipe? boolean Clear cache before refresh
---@field backpack? boolean Update backpack items
---@field bank? boolean Update bank items
---@field sort? boolean Sort backpack items
---@field sortBank? boolean Sort character bank items
---@field sortWarbank? boolean Sort account/warbank items
---@field bags? table<number, boolean> Table of specific bagIDs that changed
---@field resetLayout? boolean Ignore the previous gap layout and rebuild a fresh, gapless sort
---@field onlyIfSortPending? boolean Sweep each requested kind only if its sort has not been shown yet (the sort fallback)

-- RequestUpdate enqueues an update request onto the serialized refresh queue. It performs
-- NO side effects itself: the request's mutations (cache wipe, recent-item clearing,
-- Blizzard sort calls) and data sweeps all run inside the request's own unit when the
-- pump reaches it, so a request queued while another is in flight can never corrupt the
-- in-flight sweep. If the scheduler is idle, the first step runs synchronously in this
-- call (harvesting this frame's client state); every subsequent step is handed off to the
-- next frame via _Arm.
---@param request RefreshRequest
function refresh:RequestUpdate(request)
  table.insert(self._queue, request)
  if not self._running then
    self._running = true
    self:_Step()
  end
end

-- _Arm schedules the next pump step for the next frame. This is the ONLY clock that steps
-- the pump: a single chain, never one-per-refresh, so step ordering is deterministic. (The
-- sort fallback timer only calls RequestUpdate.)
function refresh:_Arm()
  C_Timer.After(0, function()
    self:_Step()
  end)
end

-- _Resume advances the active unit's coroutine by one step. When the unit finishes it
-- flags an idle hand-off frame; a failed unit is dropped (reported, not swallowed) so a
-- single bad sweep cannot wedge the whole queue.
function refresh:_Resume()
  local co = self._active
  local ok, err = coroutine.resume(co)
  if not ok then
    self._active = nil
    self._idlePending = true
    if geterrorhandler then
      geterrorhandler()(err)
    end
    return
  end
  if coroutine.status(co) == 'dead' then
    self._active = nil
    self._idlePending = true
  end
end

-- _Step is one frame of the pump: advance the active unit, else burn the idle hand-off
-- frame, else start the next queued unit. When the queue drains it stops the clock.
function refresh:_Step()
  if self._active then
    self:_Resume()
    self:_Arm()
    return
  end

  if self._idlePending then
    self._idlePending = false
    self:_Arm()
    return
  end

  local request = table.remove(self._queue, 1)
  if not request then
    self._running = false
    return
  end

  self._active = coroutine.create(function()
    self:_RunUnit(request)
  end)
  self:_Resume()
  self:_Arm()
end

local function backpackSorter()
  if addon.isRetail and C_Container and C_Container.SortBags then
    return C_Container.SortBags
  end
  return _G.SortBags
end

local function bankSorter()
  if addon.isRetail and C_Container and C_Container.SortBankBags then
    return C_Container.SortBankBags
  end
  return _G.SortBankBags
end

local function warbankSorter()
  if addon.isRetail and C_Container and C_Container.SortAccountBankBags then
    return C_Container.SortAccountBankBags
  end
  return nil
end

-- _ArmSortFallback guarantees that a sort is shown even if none of its item moves ever
-- produce a refresh (the bags were already sorted, or the client refused the sort). When
-- the timer fires it requests a sweep of each kind whose sort is still unshown; that unit
-- checks again when it runs, so a moves refresh queued ahead of it is never repeated.
---@param backpack boolean
---@param bank boolean
function refresh:_ArmSortFallback(backpack, bank)
  C_Timer.After(self.SORT_FALLBACK_SECONDS, function()
    local request = { onlyIfSortPending = true }
    request.backpack = backpack and items:IsSortSweepPending(const.BAG_KIND.BACKPACK) or nil
    request.bank = bank and items:IsSortSweepPending(const.BAG_KIND.BANK) or nil
    if request.backpack or request.bank then
      self:RequestUpdate(request)
    end
  end)
end

-- _RunUnit executes a single request end-to-end inside the pump's coroutine: request-time
-- mutations and sort calls first, then the bank sweep, then the backpack sweep (each an
-- inline items:RunRefresh that yields once). Because this is the only sweep in flight,
-- ClearItemCache/ClearNewItems run with nothing parked to corrupt.
---@param request RefreshRequest
function refresh:_RunUnit(request)
  local ctx = context:New('BagUpdate')

  if request.onlyIfSortPending then
    if request.backpack and not items:IsSortSweepPending(const.BAG_KIND.BACKPACK) then
      request.backpack = nil
    end
    if request.bank and not items:IsSortSweepPending(const.BAG_KIND.BANK) then
      request.bank = nil
    end
  end

  if request.bags then
    ctx:Set('targetedBags', request.bags)
  end

  -- resetLayout collapses any persistent item gaps: the sweep rebuilds a fresh,
  -- gapless sort instead of diffing against the previous layout. Set before the
  -- bank ctx:Copy() below so both kinds inherit it.
  if request.resetLayout then
    ctx:Set('resetLayout', true)
  end

  if request.wipe then
    items:ClearItemCache(ctx)
    ctx:Set('wipe', true)
    request.backpack = true
    request.bank = true
  end

  -- Sorting. Every sorted kind is marked "sort sweep pending": the next committed sweep of
  -- that kind re-reads all of its bags with a fresh layout and clears the mark. When the
  -- client can sort now, the sort is issued here and this unit does not sweep that kind,
  -- since the sweep would only redraw the pre-sort contents the moves replace a moment
  -- later; the moves' BAG_UPDATE refresh shows the result, and the fallback timer covers a
  -- sort that moves nothing. When it cannot sort (combat, no sort API), the kind is swept
  -- here, now. The mark and the fallback are set before any call that could fail.
  local sorters = {}
  local deferBackpack, deferBank = false, false
  local canSort = not InCombatLockdown()
  local sortsBank = request.sortBank or request.sortWarbank

  if request.sort then
    items:MarkSortSweepPending(const.BAG_KIND.BACKPACK)
    local sorter = canSort and backpackSorter() or nil
    if sorter then
      table.insert(sorters, sorter)
      deferBackpack = true
    else
      request.backpack = true
    end
  end

  if sortsBank then
    items:MarkSortSweepPending(const.BAG_KIND.BANK)
    local bank = request.sortBank and canSort and bankSorter() or nil
    local warbank = request.sortWarbank and canSort and warbankSorter() or nil
    if bank then table.insert(sorters, bank) end
    if warbank then table.insert(sorters, warbank) end
    if bank or warbank then
      deferBank = true
    else
      request.bank = true
    end
  end

  if deferBackpack or deferBank then
    self:_ArmSortFallback(deferBackpack, deferBank)
  end

  if request.sort then
    items:ClearNewItems(const.BAG_KIND.BACKPACK)
  end
  if sortsBank then
    items:ClearNewItems(const.BAG_KIND.BANK)
  end

  for _, sorter in ipairs(sorters) do
    sorter()
  end

  if request.bank and addon.atBank and addon.Bags.Bank then
    local accountBankStart = addon.isRetail and Enum.BagIndex.AccountBankTab_1 or const.BANK_TAB.ACCOUNT_BANK_1
    if addon.atWarbank and addon.Bags.Bank.bankTab and accountBankStart and addon.Bags.Bank.bankTab < accountBankStart then
      addon.Bags.Bank.bankTab = accountBankStart
    end

    items:RunRefresh(ctx:Copy(), const.BAG_KIND.BANK)
  end

  if request.backpack then
    items:RunRefresh(ctx, const.BAG_KIND.BACKPACK)
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
        bank = bankChanged,
        bags = updatedBags
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
  events:RegisterMessage('bags/SortBackpack', function()
    -- Sorting the backpack while the bank is open also sorts the open bank, so a
    -- single right-click cleans up everything on screen (restores the classic
    -- "sort inventory also sorts the bank" behavior). Both bank sorts ride the
    -- same serialized refresh unit as the backpack sort.
    local request = { sort = true }
    if addon.atBank then
      request.sortBank = true
      if addon.hasWarbank then
        request.sortWarbank = true
      end
    end
    self:RequestUpdate(request)
  end)
  events:RegisterMessage('bags/SortBank', function()
    self:RequestUpdate({ sortBank = true })
  end)
  events:RegisterMessage('bags/SortWarbank', function()
    self:RequestUpdate({ sortWarbank = true })
  end)

  events:RegisterEvent('BAG_CONTAINER_UPDATE', function()
    self:RequestUpdate({ wipe = true, backpack = true, bank = true })
  end)

  events:RegisterEvent('EQUIPMENT_SETS_CHANGED', function()
    self:RequestUpdate({ wipe = true, backpack = true, bank = true })
  end)

  events:RegisterEvent('BANKFRAME_OPENED', function()
    if GameMenuFrame:IsShown() then
      return
    end
    addon.atBank = true
    if addon.isRetail and database:GetShowBankTabs()
      and addon.Bags and addon.Bags.Bank then
      local slots = addon.Bags.Bank.slots
      local firstButton = slots and slots.buttons and slots.buttons[1]
      if firstButton then
        addon.Bags.Bank.blizzardBankTab = firstButton.bagIndex
      end
    end
    -- Opening the bank starts from a clean, gapless layout; any gaps held from a
    -- previous session are collapsed here.
    self:RequestUpdate({ bank = true, resetLayout = true })
  end)

  events:RegisterEvent('BANKFRAME_CLOSED', function()
    addon.atBank = false
  end)

  if not addon.isRetail then
    events:RegisterEvent('PLAYERBANKSLOTS_CHANGED', function()
      self:RequestUpdate({ bank = true, bags = { [-1] = true } })
    end)
  elseif addon.isForever then
    -- A bag placed in or removed from a bank tab's bag socket resizes that tab's
    -- container, so sweep every bank bag. Bag -1 is the keyring on Forever.
    events:RegisterEvent('PLAYERBANKSLOTS_CHANGED', function()
      self:RequestUpdate({ bank = true })
    end)
  end

  -- Route the initial login sweep through the ItemLoader's ContinuableContainer, exactly
  -- like a BAG_UPDATE, so the first harvest only runs once the item cache is primed.
  -- Harvesting a cold cache here reads nil type/subtype from C_Item.GetItemInfo and dumps
  -- items into "Everything" until a /reload. The loader's callback (registered above) fans
  -- this out to RequestUpdate, and RunRefresh forces a wipe on each kind's first sweep, so
  -- no explicit wipe is needed here.
  itemLoader:LoadAllBagsAndUpdate()
end
