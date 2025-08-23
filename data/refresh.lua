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
---@field UpdateQueue table<number, EventArg>
---@field private isUpdateRunning boolean
---@field private backpackRedrawPending boolean
---@field private isSorting boolean
local refresh = addon:NewModule('Refresh')

function refresh:OnInitialize()
  self.UpdateQueue = {}
  self.isUpdateRunning = false
  self.backpackRedrawPending = false
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

-- StartUpdate will start the bag update process if it's not already running.
---@param ctx Context
function refresh:StartUpdate(ctx)
  if self.isSorting then
    wipe(self.UpdateQueue)
    return
  end
  if self.isUpdateRunning then
    -- This is a safety check to ensure that the update process is
    -- never missed in the event of the update queue being interrupted.
    C_Timer.After(0, function()
      if next(self.UpdateQueue) ~= nil then
        self:StartUpdate(context:New('MissedEvent'))
      end
    end)
    return
  end

  self.isUpdateRunning = true
  local updateBackpack = false
  local updateBank = false
  local sortBackpack = false
  local wipeAndRefreshAll = false
  for _, event in pairs(self.UpdateQueue) do
    if event.ctx:GetBool("wipe") then
      -- Prevent full wipes from happening in combat.
      -- This function will be called again when combat ends automatically.
      if InCombatLockdown() then
        self.isUpdateRunning = false
        return
      end
      ctx:Set("wipe", true)
    end
    if event.eventName == 'BAG_UPDATE_DELAYED' then
      updateBackpack = true
      updateBank = true
    elseif event.eventName == 'EQUIPMENT_SETS_CHANGED' then
      updateBackpack = true
      updateBank = true
    elseif event.eventName == 'BAG_SORT' then
      if not InCombatLockdown() then
        sortBackpack = true
      end
    elseif event.eventName == 'BAG_UPDATE_BANK' then
      updateBank = true
    elseif event.eventName == 'WIPE_AND_REFRESH_ALL' then
      wipeAndRefreshAll = true
    elseif const.BANK_BAGS[event.args[1]] then
      updateBank = true
    elseif const.REAGENTBANK_BAGS[event.args[1]] then
      updateBank = true
    elseif const.ACCOUNT_BANK_BAGS[event.args[1]] then
      updateBank = true
    elseif const.BACKPACK_BAGS[event.args[1]] then
      updateBackpack = true
    end
  end
  wipe(self.UpdateQueue)

  if wipeAndRefreshAll then
    items:ClearItemCache(ctx)
    ctx:Set('wipe', true)
    updateBackpack = true
    updateBank = true
  end

  if sortBackpack then
    self.isUpdateRunning = false
    self.isSorting = true
    items:RemoveNewItemFromAllItems()
    items:Restack(ctx, const.BAG_KIND.BACKPACK, function()
      self:AfterSort(ctx)
    end)
    return
  end

  if updateBank and addon.atBank then
    if addon.atWarbank and addon.Bags.Bank.bankTab < const.BANK_TAB.ACCOUNT_BANK_1 then
      addon.Bags.Bank.bankTab = const.BANK_TAB.ACCOUNT_BANK_1
    end
    items:RefreshBank(ctx:Copy())
  end

  if updateBackpack then
    if not ctx:HasTimeout() then
    -- This timer runs during loading screens, which can cause the context
    -- to be cancelled before the draw even happens.
      ctx:Timeout(60, function()
        self.isUpdateRunning = false
        items._preSort = false
      end)
    end
    items:RefreshBackpack(ctx)
  else
    self.isUpdateRunning = false
    -- ctx:Cancel()
  end

end

function refresh:OnEnable()

  -- Register for main bag update events from the WoW client.
  events:CatchUntil('BAG_UPDATE', 'BAG_UPDATE_DELAYED', function(ctx, eventList)
    -- If the event list is empty, we never got the BAG_UPDATE event, and need to insert
    -- a BAG_UPDATE_DELAYED event to trigger the update.
    if #eventList == 0 then
      table.insert(refresh.UpdateQueue, {eventName = 'BAG_UPDATE_DELAYED', args = {}, ctx = ctx})
    else
      for _, event in pairs(eventList) do
        table.insert(refresh.UpdateQueue, event)
      end
    end

    self:StartUpdate(ctx)
  end)

  if not addon.isRetail then
    -- Register when bank slots change for any reason.
    events:RegisterEvent('PLAYERBANKSLOTS_CHANGED', function(ctx, _, slot)
      if slot > NUM_BANKGENERIC_SLOTS then
        ctx:Set("wipe", true)
      else
        ctx:Set("wipe", false)
      end
      table.insert(refresh.UpdateQueue, {eventName = 'BAG_UPDATE_BANK', args = {}, ctx = ctx})
    end)
  end
  -- Register when the bag slots change for any reason.
  events:RegisterEvent('BAG_CONTAINER_UPDATE', function(ctx)
    ctx:Set("wipe", true)
    table.insert(refresh.UpdateQueue, {eventName = 'BAG_UPDATE', args = {}, ctx = ctx})
  end)

  -- Register when equipment sets change.
  events:RegisterEvent('EQUIPMENT_SETS_CHANGED', function(ctx)
    ctx:Set("wipe", true)
    table.insert(refresh.UpdateQueue, {eventName = 'EQUIPMENT_SETS_CHANGED', args = {}, ctx = ctx})
    self:StartUpdate(ctx)
  end)

  -- Register when combat ends and start updates to catch any
  -- required updates.
  events:RegisterEvent('PLAYER_REGEN_ENABLED', function(ctx)
    self:StartUpdate(ctx)
  end)

  events:RegisterMessage('bags/Backpack/Redraw', function(ctx)
    self:RedrawBackpack(ctx)
  end)

  -- Register when the backpack is manually refreshed.
  events:RegisterMessage('bags/RefreshBackpack', function(ctx, _, shouldWipe)
    ctx:Set("wipe", shouldWipe)
    table.insert(refresh.UpdateQueue, {eventName = 'BAG_UPDATE_DELAYED', args = {}, ctx = ctx})
    self:StartUpdate(ctx)
  end)

  -- Register when the bank is manually refreshed.
  events:RegisterMessage('bags/RefreshBank', function (ctx, _, shouldWipe)
    ctx:Set("wipe", shouldWipe)
    table.insert(refresh.UpdateQueue, {eventName = 'BAG_UPDATE_DELAYED', args = {}, ctx = ctx})
    self:StartUpdate(ctx)
  end)

  -- Register when everything should be refreshed, manually.
  events:RegisterMessage('bags/RefreshAll', function(ctx)
    table.insert(refresh.UpdateQueue, {eventName = 'BAG_UPDATE_DELAYED', args = {}, ctx = ctx})
    self:StartUpdate(ctx)
  end)

  -- Register when then backpack should be sorted.
  events:RegisterMessage('bags/SortBackpack', function(ctx)
    table.insert(refresh.UpdateQueue, {eventName = 'BAG_SORT', args = {const.BAG_KIND.BACKPACK}, ctx = ctx})
    self:StartUpdate(ctx)
  end)

  -- Register when all bags should be wiped and reloaded.
  events:RegisterMessage('bags/FullRefreshAll', function(ctx)
    table.insert(refresh.UpdateQueue, {eventName = 'WIPE_AND_REFRESH_ALL', args = {}, ctx = ctx})
    self:StartUpdate(ctx)
  end)

  -- Register for when bags are done drawing.
  events:RegisterMessage('bags/Draw/Backpack/Done', function(ctx)
    -- If there are more updates in the queue, start the next one with a new context.
    self.isUpdateRunning = false
    self.backpackRedrawPending = false
    if next(self.UpdateQueue) ~= nil then
      self:StartUpdate(ctx)
    else
      -- ctx:Cancel()
    end
  end)

end
