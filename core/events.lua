local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Perf: AceModule
local perf = addon:GetModule('Perf')

---@alias eventData any[][]

---@class Callback
---@field cb fun(...)
---@field a any
---@field raw? boolean Receives the AceEvent arguments directly; no Context is built per fire.

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
---@field _scope? EventScope The scope registrations are made in now (InScope).
local events = addon:NewModule('Events')

-- An EventScope holds registrations made while it was current (events:InScope): WoW events,
-- messages and event buckets. Switching it off unhooks every one of them, unregistering a WoW
-- event or message no other callback listens to, and closes its buckets' open windows; switching
-- it on hooks them again. BetterBags makes each bag design in a scope of its own, so the design not
-- shown costs nothing (next.md §11).
---@class EventScope
---@field name string
---@field enabled boolean
---@field entries {kind: "event"|"message", name: string, entry: Callback}[]
---@field buckets {close: fun()}[]
---@field owner Events
local scopeProto = {}

function events:Init()
  -- Re-initializing (specs do) must not leave the old handler registered: its dispatchers
  -- read the module's current maps, so it would deliver every later event and message again.
  if self._eventHandler and self._eventHandler.UnregisterAllEvents then
    self._eventHandler:UnregisterAllEvents()
    self._eventHandler:UnregisterAllMessages()
  end
  self._eventHandler = {}
  self._messageMap = {}
  self._eventMap = {}
  self._bucketTimers = {}
  self._eventQueue = {}
  self._bucketCallbacks = {}
  self._eventArguments = {}
  self._scope = nil
  LibStub:GetLibrary('AceEvent-3.0'):Embed(self._eventHandler)
end

-- NewScope makes a scope, switched on, with nothing in it.
---@param name string
---@return EventScope
function events:NewScope(name)
  return setmetatable({ name = name, enabled = true, entries = {}, buckets = {}, owner = self },
    { __index = scopeProto })
end

-- InScope runs fn with scope current: every event, message and bucket it registers belongs to the
-- scope. The scope that was current before is current again afterwards, even when fn errors.
---@param scope EventScope
---@param fn fun()
function events:InScope(scope, fn)
  local previous = self._scope
  self._scope = scope
  local ok, err = xpcall(fn, function(e)
    return debugstack and (tostring(e) .. "\n" .. debugstack(2)) or e
  end)
  self._scope = previous
  if not ok then
    error(err, 0)
  end
end

---@return boolean
function scopeProto:IsEnabled()
  return self.enabled
end

-- Disable unhooks every registration in the scope and closes its buckets' open windows.
function scopeProto:Disable()
  self.enabled = false
  for _, rec in ipairs(self.entries) do
    self.owner:detach(rec.kind, rec.name, rec.entry)
  end
  for _, bucket in ipairs(self.buckets) do
    bucket.close()
  end
end

-- Enable hooks every registration in the scope again.
function scopeProto:Enable()
  if self.enabled then return end
  self.enabled = true
  for _, rec in ipairs(self.entries) do
    self.owner:attach(rec.kind, rec.name, rec.entry)
  end
end

-- dispatcher returns the function AceEvent calls for an event or a message: it runs every callback
-- listening to it now (a callback added or removed during a dispatch counts from the next one).
---@param kind "event"|"message"
---@param name string
---@return fun(...)
function events:dispatcher(kind, name)
  if kind == "message" then
    local label = '[msg] ' .. name
    return function(...)
      local token = perf.active and perf:Enter(label, select(2, ...))
      for _, cb in pairs(self._messageMap[name].cbs) do
        cb.cb(select(2, ...))
      end
      if token then perf:Exit(token) end
    end
  end
  local label = '[event] ' .. name
  return function(...)
    local token = perf.active and perf:Enter(label, select(2, ...))
    for _, cb in pairs(self._eventMap[name].cbs) do
      if cb.raw then
        cb.cb(...)
      else
        local ctx = context:New(name)
        cb.cb(ctx, ...)
      end
    end
    if token then perf:Exit(token) end
  end
end

-- attach hooks a callback to an event or a message. AceEvent keeps one handler per event for our
-- embedded object, so every callback for an event is multiplexed through one registered function,
-- registered with the first callback.
---@private
---@param kind "event"|"message"
---@param name string
---@param entry Callback
function events:attach(kind, name, entry)
  local map = kind == "message" and self._messageMap or self._eventMap
  if map[name] == nil then
    map[name] = { fn = self:dispatcher(kind, name), cbs = {} }
    if kind == "message" then
      self._eventHandler:RegisterMessage(name, map[name].fn)
    else
      self._eventHandler:RegisterEvent(name, map[name].fn)
    end
  end
  table.insert(map[name].cbs, entry)
end

-- detach unhooks a callback, unregistering the event or message when no callback is left. The list
-- is replaced, not changed, so a dispatch going over it finishes as it started.
---@private
---@param kind "event"|"message"
---@param name string
---@param entry Callback
function events:detach(kind, name, entry)
  local map = kind == "message" and self._messageMap or self._eventMap
  local found = map[name]
  if found == nil then return end
  local left = {}
  for _, cb in ipairs(found.cbs) do
    if cb ~= entry then
      table.insert(left, cb)
    end
  end
  found.cbs = left
  if #left == 0 then
    map[name] = nil
    if kind == "message" then
      self._eventHandler:UnregisterMessage(name)
    else
      self._eventHandler:UnregisterEvent(name)
    end
  end
end

-- register records a callback in the current scope, if any, and hooks it unless that scope is
-- switched off.
---@private
---@param kind "event"|"message"
---@param name string
---@param entry Callback
function events:register(kind, name, entry)
  local scope = self._scope
  if scope then
    table.insert(scope.entries, { kind = kind, name = name, entry = entry })
    if not scope.enabled then return end
  end
  self:attach(kind, name, entry)
end

---@param event string
---@param callback fun(ctx: Context, ...)
function events:RegisterMessage(event, callback)
  self:register("message", event, {cb = callback})
end

---@param event string
---@param callback fun(ctx: Context, ...)
function events:RegisterEvent(event, callback)
  self:addEventCallback(event, {cb = callback})
end

---@private
---@param event string
---@param entry Callback
function events:addEventCallback(event, entry)
  self:register("event", event, entry)
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

-- BucketEvent batches an event into 0.2s windows: the first fire opens a window, later
-- fires join it, and the callback runs once when the window closes. A continuous stream
-- of fires therefore still flushes every 0.2s instead of being held off until it goes
-- quiet. The callback receives the payloads of the window's fires as an EventArg[] (each
-- entry `{ eventName = <event>, args = { <payload...> } }`); fires with no payload are not
-- recorded. The optional filter runs first on every fire and drops it when it returns
-- false, before anything is recorded or scheduled. Each call makes a bucket of its own,
-- with its own window, filter and callback (both bag designs bucket BAG_UPDATE_COOLDOWN).
---@param event string
---@param callback fun(ctx: Context, events: EventArg[])
---@param filter? fun(eventName: string, ...): boolean
function events:BucketEvent(event, callback, filter)
  local bucket = { args = {}, timer = nil }
  local label = '[bucket] ' .. event
  local flush = function()
    local collected = bucket.args
    local token = perf.active and perf:Enter(label, collected)
    bucket.args = {}
    bucket.timer = nil
    -- Wrap in a closure: xpcall in Lua 5.1 (WoW's runtime) does not forward
    -- extra args to the protected function, so pass `collected` via upvalue.
    xpcall(function()
      callback(context:New(event), collected)
    end, geterrorhandler())
    if token then perf:Exit(token) end
  end
  -- close drops an open window: its timer is cancelled and what it collected forgotten.
  bucket.close = function()
    if bucket.timer then
      bucket.timer:Cancel()
      bucket.timer = nil
    end
    bucket.args = {}
  end
  if self._scope then
    table.insert(self._scope.buckets, bucket)
  end

  self:addEventCallback(event, { raw = true, cb = function(eventName, ...)
    if filter and not filter(eventName, ...) then return end
    if select('#', ...) > 0 then
      tinsert(bucket.args, { eventName = eventName, args = {...} })
    end
    if not bucket.timer then
      bucket.timer = C_Timer.NewTimer(0.2, flush)
    end
  end })
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

  local names = {}
  for _, name in ipairs(groupEvents) do names[#names + 1] = name end
  for _, name in ipairs(groupMessages) do names[#names + 1] = name end
  local label = '[bucket] ' .. table.concat(names, ', ')
  local bucketFunction = function()
    local token = perf.active and perf:Enter(label, self._eventArguments[joinedEvents])
    for _, cb in pairs(self._bucketCallbacks[joinedEvents]) do
      -- Note: use a wrapper function because xpcall in Lua 5.1 (the WoW
      -- runtime) does NOT pass extra args to f, unlike Lua 5.4. Calling
      -- cb directly via xpcall would silently drop the arg on WoW.
      xpcall(function()
        cb(self._eventArguments[joinedEvents])
      end, geterrorhandler())
    end
    self._eventArguments[joinedEvents] = {}
    if token then perf:Exit(token) end
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
