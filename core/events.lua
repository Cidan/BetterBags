local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Context: AceModule
local context = addon:GetModule('Context')

---@alias eventData any[][]

---@class Callback
---@field cb fun(...)
---@field a any

---@class EventArg
---@field eventName string
---@field ctx? Context
---@field args any[]

---@class Events: AceModule
---@field _eventHandler AceEvent-3.0
---@field _messageMap table<string, {fn: fun(...), cbs: Callback[]}>
---@field _eventMap table<string, {fn: fun(...), cbs: Callback[]}>
---@field _bucketTimers table<string, FunctionContainer>
---@field _eventQueue table<string, boolean>
---@field _eventArguments table<string, EventArg[]>
---@field _bucketCallbacks table<string, fun(...)[]>
local events = addon:NewModule('Events')

function events:OnInitialize()
  self._eventHandler = {}
  self._messageMap = {}
  self._eventMap = {}
  self._bucketTimers = {}
  self._eventQueue = {}
  self._bucketCallbacks = {}
  self._eventArguments = {}
  LibStub:GetLibrary('AceEvent-3.0'):Embed(self._eventHandler)
end

---@param event string
---@param callback fun(ctx: Context, ...)
function events:RegisterMessage(event, callback)
  if self._messageMap[event] == nil then
    self._messageMap[event] = {
      fn = function(...)
        for _, cb in pairs(self._messageMap[event].cbs) do
          cb.cb(select(2, ...))
        end
      end,
      cbs = {},
    }
    self._eventHandler:RegisterMessage(event, self._messageMap[event].fn)
  end
  table.insert(self._messageMap[event].cbs, {cb = callback})
end

---@param event string
---@param callback fun(ctx: Context, ...)
function events:RegisterEvent(event, callback)
  if self._eventMap[event] == nil then
    self._eventMap[event] = {
      fn = function(...)
        for _, cb in pairs(self._eventMap[event].cbs) do
          local ctx = context:New(event)
          cb.cb(ctx, ...)
        end
      end,
      cbs = {},
    }
    self._eventHandler:RegisterEvent(event, self._eventMap[event].fn)
  end
  table.insert(self._eventMap[event].cbs, {cb = callback})
end

---@param evts? table<string, fun()>
---@param messages? table<string, fun()>
function events:RegisterMap(evts, messages)
  if evts then
    for event, callback in pairs(evts) do
      self:RegisterEvent(event, callback)
    end
  end
  if messages then
    for message, callback in pairs(messages) do
      self:RegisterMessage(message, callback)
    end
  end
end

-- CatchUntil will group all events that fire as caughtEvent,
-- until finalEvent is fired. Once finalEvent is fired, the callback
-- will be called with all the caughtEvent arguments that were fired,
-- and the finalEvent arguments. If finalEvent is fired without any
-- caughtEvents being fired, the callback will be called with the
-- finalEvent arguments.
---@param caughtEvent string
---@param finalEvent string
---@param callback fun(ctx: Context, caughtEvents: EventArg[], finalArgs: EventArg)
function events:CatchUntil(caughtEvent, finalEvent, callback)
  local caughtEvents = {}
  local finalArgs = nil
  self:RegisterEvent(caughtEvent, function(ctx, eventName, ...)
    table.insert(caughtEvents, {
      eventName = eventName, args = CopyTable({...}), ctx = ctx
    })
  end)

  self:RegisterEvent(finalEvent, function(ctx, eventName, ...)
    finalArgs = {
      eventName = eventName, args = CopyTable({...}), ctx = ctx
    }
    callback(ctx, caughtEvents, finalArgs)
    caughtEvents = {}
    finalArgs = nil
  end)
end

---@param event string
---@param callback fun(ctx: Context, ...)
function events:BucketEvent(event, callback)
 --TODO(lobato): Refine this so that timers only run when an event is in the queue.
  local bucketFunction = function()
    for _, cb in pairs(self._bucketCallbacks[event]) do
      xpcall(function(...)
        local ctx = context:New(event)
        cb(ctx, ...)
      end, geterrorhandler())
    end
    self._bucketTimers[event] = nil
    self._bucketCallbacks[event] = {}
  end

  self._bucketCallbacks[event] = {}
  self:RegisterEvent(event, function()
    if self._bucketTimers[event] then
      self._bucketTimers[event]:Cancel()
    end
    self._bucketTimers[event] = C_Timer.NewTimer(0.2, bucketFunction)
  end)

  table.insert(self._bucketCallbacks[event], callback)
end

-- GroupBucketEvent registers a callback for a group of events that will be
-- called when any of the events in the group are fired. The callback will be
-- called at most once every 0.5 seconds.
---@param groupEvents string[]
---@param groupMessages string[]
---@param callback fun(eventData: EventArg[])
function events:GroupBucketEvent(groupEvents, groupMessages, callback)
  local joinedEvents = table.concat(groupEvents, '')
  joinedEvents = joinedEvents .. table.concat(groupMessages, '')

  local bucketFunction = function()
    for _, cb in pairs(self._bucketCallbacks[joinedEvents]) do
      xpcall(cb, geterrorhandler(), self._eventArguments[joinedEvents])
    end
    self._eventArguments[joinedEvents] = {}
  end

  self._bucketCallbacks[joinedEvents] = {}
  self._eventArguments[joinedEvents] = {}
  for _, event in pairs(groupEvents) do
    self:RegisterEvent(event, function(eventName, ...)
      if self._bucketTimers[joinedEvents] then
        self._bucketTimers[joinedEvents]:Cancel()
      end
      tinsert(self._eventArguments[joinedEvents], {
        eventName = eventName, args = {...}}
      )
      self._bucketTimers[joinedEvents] = C_Timer.NewTimer(0.2, bucketFunction)
    end)
  end

  for _, event in pairs(groupMessages) do
    self:RegisterMessage(event, function(eventName, ...)
      if self._bucketTimers[joinedEvents] then
        self._bucketTimers[joinedEvents]:Cancel()
      end
      tinsert(self._eventArguments[joinedEvents], {
        eventName = eventName, args = {...}}
      )
      self._bucketTimers[joinedEvents] = C_Timer.NewTimer(0.2, bucketFunction)
    end)
  end
  table.insert(self._bucketCallbacks[joinedEvents], callback)
end

---@param ctx Context
---@param event string
---@param ... any
function events:SendMessage(ctx, event, ...)
  if type(ctx) ~= 'table' or not ctx.Event then
    event = ctx --[[@as string]]
    ctx = context:New("SendMessage" .. event)
    --error('ctx must be passed into SendMessage and must be a Context object: ' .. event)
  end
  if ctx:IsCancelled() then
    error('ctx has been cancelled: ' .. event)
  end
  ctx:AppendEvent(event)
  local args = {...}
  table.insert(args, 1, ctx)
  self._eventHandler:SendMessage(event, unpack(args))
end

---@param ctx Context
---@param event? string
---@param ... any
function events:SendMessageIf(ctx, event,...)
  if event then
    self:SendMessage(ctx, event, ...)
  end
end

---@param ctx Context
---@param event string
---@param ... any
function events:SendMessageLater(ctx, event, ...)
  local args = {...}
  C_Timer.After(0, function()
    self:SendMessage(ctx, event, unpack(args))
  end)
end

events:Enable()
