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

---@class Refresh: AceModule
---@field UpdateQueue table<number, EventArg>
---@field private isUpdateRunning boolean
local refresh = addon:NewModule('Refresh')

function refresh:OnInitialize()
  self.UpdateQueue = {}
  self.isUpdateRunning = false
end

-- StartUpdate will start the bag update process if it's not already running.
function refresh:StartUpdate()
  if self.isUpdateRunning then
    -- This is a safety check to ensure that the update process is
    -- never missed in the event of the update queue being interrupted.
    C_Timer.After(0, function()
      self:StartUpdate()
    end)
    return
  end

  local ctx = context:New()
  self.isUpdateRunning = true
  local updateBackpack = false
  local updateBank = false
  local sortBackpack = false
  local sortBackpackClassic = false
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
    elseif event.eventName == 'PLAYERBANKSLOTS_CHANGED' then
      updateBank = true
    elseif event.eventName == 'PLAYERREAGENTBANKSLOTS_CHANGED' then
      updateBank = true
    elseif event.eventName == 'BAG_SORT' then
      if not InCombatLockdown() then
        sortBackpack = true
      end
    elseif event.eventName == 'BAG_SORT_CLASSIC' then
      if not InCombatLockdown() then
        sortBackpackClassic = true
      end
    elseif const.BANK_BAGS[event.args[1]] then
      updateBank = true
    elseif const.REAGENTBANK_BAGS[event.args[1]] then
      updateBank = true
    elseif const.BACKPACK_BAGS[event.args[1]] then
      updateBackpack = true
    end
  end
  wipe(self.UpdateQueue)

  if sortBackpack then
    self.isUpdateRunning = false
    items:RemoveNewItemFromAllItems()
    items:ClearItemCache()
    items._firstLoad[const.BAG_KIND.BACKPACK] = true
    items._firstLoad[const.BAG_KIND.BANK] = true
    items._firstLoad[const.BAG_KIND.REAGENT_BANK] = true
    items:PreSort()
    C_Container:SortBags()
    return
  end

  if sortBackpackClassic then
    self.isUpdateRunning = false
    items:RemoveNewItemFromAllItems()
    _G.SortBags()
    return
  end

  if updateBank and addon.atBank then
    local bankCtx = ctx:Copy()
    if addon.Bags.Bank.isReagentBank then
      items:RefreshReagentBank(bankCtx)
    else
      items:RefreshBank(bankCtx)
    end
  end

  if updateBackpack then
    -- This timer runs during loading screens, which can cause the context
    -- to be cancelled before the draw even happens.
    ctx:Timeout(60, function()
      self.isUpdateRunning = false
      items._preSort = false
    end)
    items:RefreshBackpack(ctx)
  else
    self.isUpdateRunning = false
    ctx:Cancel()
  end

end

function refresh:OnEnable()

  -- Register for main bag update events from the WoW client.
  events:CatchUntil('BAG_UPDATE', 'BAG_UPDATE_DELAYED', function(eventList)
    -- If the event list is empty, we never got the BAG_UPDATE event, and need to insert
    -- a BAG_UPDATE_DELAYED event to trigger the update.
    if #eventList == 0 then
      table.insert(refresh.UpdateQueue, {eventName = 'BAG_UPDATE_DELAYED', args = {}, ctx = context:New()})
    else
      for _, event in pairs(eventList) do
        event.ctx = context:New()
        table.insert(refresh.UpdateQueue, event)
      end
    end

    self:StartUpdate()
  end)

  -- Register when bank slots change for any reason.
  events:RegisterEvent('PLAYERBANKSLOTS_CHANGED', function()
    local ctx = context:New()
    ctx:Set("wipe", false)
    table.insert(refresh.UpdateQueue, {eventName = 'PLAYERBANKSLOTS_CHANGED', args = {}, ctx = ctx})
    self:StartUpdate()
  end)

  -- Register when equipment sets change.
  events:RegisterEvent('EQUIPMENT_SETS_CHANGED', function()
    local ctx = context:New()
    ctx:Set("wipe", true)
    table.insert(refresh.UpdateQueue, {eventName = 'EQUIPMENT_SETS_CHANGED', args = {}, ctx = ctx})
    self:StartUpdate()
  end)

  -- Register when reagent bank slots change, only in retail.
  if addon.isRetail then
    events:RegisterEvent('PLAYERREAGENTBANKSLOTS_CHANGED', function()
      local ctx = context:New()
      ctx:Set("wipe", false)
      table.insert(refresh.UpdateQueue, {eventName = 'PLAYERREAGENTBANKSLOTS_CHANGED', args = {}, ctx = ctx})
      self:StartUpdate()
    end)
  end

  -- Register when combat ends and start updates to catch any
  -- required updates.
  events:RegisterEvent('PLAYER_REGEN_ENABLED', function()
    self:StartUpdate()
  end)

  -- Register when the backpack is manually refreshed.
  events:RegisterMessage('bags/RefreshBackpack', function(_, shouldWipe)
    local ctx = context:New()
    ctx:Set("wipe", shouldWipe)
    table.insert(refresh.UpdateQueue, {eventName = 'BAG_UPDATE_DELAYED', args = {}, ctx = ctx})
    self:StartUpdate()
  end)

  -- Register when the bank is manually refreshed.
  events:RegisterMessage('bags/RefreshBank', function (_, shouldWipe)
    local ctx = context:New()
    ctx:Set("wipe", shouldWipe)
    table.insert(refresh.UpdateQueue, {eventName = 'BAG_UPDATE_DELAYED', args = {}, ctx = ctx})
    self:StartUpdate()
  end)

  -- Register when everything should be refreshed, manually.
  events:RegisterMessage('bags/RefreshAll', function(_, shouldWipe)
    local ctx = context:New()
    ctx:Set("wipe", shouldWipe)
    table.insert(refresh.UpdateQueue, {eventName = 'BAG_UPDATE_DELAYED', args = {}, ctx = ctx})
    self:StartUpdate()
  end)

  -- Register when then backpack should be sorted.
  events:RegisterMessage('bags/SortBackpack', function()
    table.insert(refresh.UpdateQueue, {eventName = 'BAG_SORT', args = {const.BAG_KIND.BACKPACK}, ctx = context:New()})
    self:StartUpdate()
  end)

  -- Register when the classic backpack should be sorted.
  events:RegisterMessage('bags/SortBackpackClassic', function()
    table.insert(refresh.UpdateQueue, {eventName = 'BAG_SORT_CLASSIC', args = {const.BAG_KIND.BACKPACK}, ctx = context:New()})
    self:StartUpdate()
  end)

  -- Register when all bags should be wiped and reloaded.
  events:RegisterMessage('bags/FullRefreshAll', function()
    items:WipeAndRefreshAll()
  end)

  -- Register for when bags are done drawing.
  events:RegisterMessage('bags/Draw/Backpack/Done', function(_, ctx)
    -- Cancel the context as the bag has been drawn.
    ---@cast ctx Context
    ctx:Cancel()

    -- If there are more updates in the queue, start the next one with a new context.
    self.isUpdateRunning = false
    items._preSort = false
    if next(self.UpdateQueue) ~= nil then
      self:StartUpdate()
    end
  end)

end
