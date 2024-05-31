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

function refresh:RefreshBackpack()
end

---@param bagid number
function refresh:UpdateBag(_, bagid)
  print("update bag called", bagid)
end

-- StartUpdate will start the bag update process if it's not already running.
---@param ctx Context
function refresh:StartUpdate(ctx)
  if self.isUpdateRunning then
    return
  end
  self.isUpdateRunning = true
  local updateBackpack = false
  local updateBank = false
  for _, event in pairs(self.UpdateQueue) do
    if event.eventName == 'BAG_UPDATE_DELAYED' then
      updateBackpack = true
      updateBank = true
    elseif const.BACKPACK_BAGS[event.args[1]] then
      updateBackpack = true
    elseif const.BANK_BAGS[event.args[1]] then
      updateBank = true
    elseif const.REAGENTBANK_BAGS[event.args[1]] then
      updateBank = true
    end
  end
  wipe(self.UpdateQueue)

  if updateBackpack then
    items:RefreshBackpack(ctx)
  end

  if updateBank then
    local bankCtx = ctx:Copy()
    items:RefreshBank(bankCtx)
  end

  print("would have updated backpack", updateBackpack)
  print("would have updated bank", updateBank)
end

function refresh:OnEnable()

  -- Register for main bag update events from the WoW client.
  events:CatchUntil('BAG_UPDATE', 'BAG_UPDATE_DELAYED', function(eventList)
    -- If the event list is empty, we never got the BAG_UPDATE event, and need to insert
    -- a BAG_UPDATE_DELAYED event to trigger the update.
    if #eventList == 0 then
      table.insert(refresh.UpdateQueue, {eventName = 'BAG_UPDATE_DELAYED', args = {}})
    else
      for _, event in pairs(eventList) do
        table.insert(refresh.UpdateQueue, event)
      end
    end
    -- Create the update context and start the update process.
    local ctx = context:New()
    ctx:Set("wipe", false)

    self:StartUpdate(ctx)
  end)

  -- Register for when bags are done drawing.
  events:RegisterMessage('bags/Draw/Backpack/Done', function(_, ctx)
    -- Cancel the context as the bag has been drawn.
    -- TODO(lobato): Uncomment this when context cancel is removed from Items codepath.
    -----@cast ctx Context
    --ctx:Cancel()

    -- If there are more updates in the queue, start the next one with a new context.
    self.isUpdateRunning = false
    if next(self.UpdateQueue) ~= nil then
      local newCtx = context:New()
      ctx:Set("wipe", false)
      self:StartUpdate(newCtx)
    end
  end)

  events:RegisterMessage('bags/RefreshBackpack', function(_, shouldWipe)
    print("got refresh backpack message with wipe of", shouldWipe)
  end)

  events:RegisterMessage('bags/RefreshBank', function (_, shouldWipe)
    print("got refresh bank message with wipe of", shouldWipe)
  end)

  events:RegisterMessage('bags/RefreshAll', function(_, shouldWipe)
    print("got refresh all message with wipe of", shouldWipe)
  end)

end
