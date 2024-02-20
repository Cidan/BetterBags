local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@alias eventData any[][]

---@class Callback
---@field cb fun(...)
---@field a any
local callbackProto = {}

---@class Events: AceModule
---@field _eventHandler AceEvent-3.0
---@field _messageMap table<string, {fn: fun(...), cbs: Callback[]}>
---@field _eventMap table<string, {fn: fun(...), cbs: Callback[]}>
---@field _bucketTimers table<string, cbObject>
---@field _eventQueue table<string, boolean>
---@field _eventArguments any[]
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
---@param callback fun(...)
---@param arg? any
function events:RegisterMessage(event, callback, arg)
  if self._messageMap[event] == nil then
    self._messageMap[event] = {
      fn = function(...)
        for _, cb in pairs(self._messageMap[event].cbs) do
          if cb.a ~= nil then
            cb.cb(cb.a, ...)
          else
            cb.cb(...)
          end
        end
      end,
      cbs = {},
    }
    self._eventHandler:RegisterMessage(event, self._messageMap[event].fn)
  end
  table.insert(self._messageMap[event].cbs, {cb = callback, a = arg})
end

function events:RegisterEvent(event, callback, arg)
  if self._eventMap[event] == nil then
    self._eventMap[event] = {
      fn = function(...)
        for _, cb in pairs(self._eventMap[event].cbs) do
          if cb.a ~= nil then
            cb.cb(cb.a, ...)
          else
            cb.cb(...)
          end
        end
      end,
      cbs = {},
    }
    self._eventHandler:RegisterEvent(event, self._eventMap[event].fn)
  end
  table.insert(self._eventMap[event].cbs, {cb = callback, a = arg})
end

function events:BucketEvent(event, callback)
 --TODO(lobato): Refine this so that timers only run when an event is in the queue. 
  if not self._bucketTimers[event] then
    self._bucketCallbacks[event] = {}
    self._bucketTimers[event] = C_Timer.NewTicker(0.5,
      function()
        if not self._eventQueue[event] then
          return
        end
        for _, cb in pairs(self._bucketCallbacks[event]) do
          cb()
        end
        self._eventQueue[event] = false
      end)
    self:RegisterEvent(event, function()
      self._eventQueue[event] = true
    end)
  end

  table.insert(self._bucketCallbacks[event], callback)
end

-- GroupBucketEvent registers a callback for a group of events that will be
-- called when any of the events in the group are fired. The callback will be
-- called at most once every 0.5 seconds.
---@param groupEvents string[]
---@param groupMessages string[]
---@param callback fun(eventData: eventData)
function events:GroupBucketEvent(groupEvents, groupMessages, callback)
  local joinedEvents = table.concat(groupEvents, '')
  joinedEvents = joinedEvents .. table.concat(groupMessages, '')
  if not self._bucketTimers[joinedEvents] then
    self._bucketCallbacks[joinedEvents] = {}
    self._eventArguments[joinedEvents] = {}
    self._bucketTimers[joinedEvents] = C_Timer.NewTicker(0.5,
      function()
        if not self._eventQueue[joinedEvents] then
          return
        end
        for _, cb in pairs(self._bucketCallbacks[joinedEvents]) do
          xpcall(cb, geterrorhandler(), self._eventArguments[joinedEvents])
        end
        self._eventQueue[joinedEvents] = false
        self._eventArguments[joinedEvents] = {}
      end)
    for _, event in pairs(groupEvents) do
      self:RegisterEvent(event, function(eventName, ...)
        tinsert(self._eventArguments[joinedEvents], {eventName, ...})
        self._eventQueue[joinedEvents] = true
      end)
    end

    for _, event in pairs(groupMessages) do
      self:RegisterMessage(event, function(eventName, ...)
        tinsert(self._eventArguments[joinedEvents], {eventName, ...})
        self._eventQueue[joinedEvents] = true
      end)
    end
  end
  table.insert(self._bucketCallbacks[joinedEvents], callback)
end

function events:SendMessage(event, ...)
  self._eventHandler:SendMessage(event, ...)
end

---@param event string
---@param callback? function
---@param ... any
function events:SendMessageLater(event, callback, ...)
  ---@type any[]
  local vararg = {...}
  C_Timer.After(0, function()
    self._eventHandler:SendMessage(event, vararg)
    if callback then
      callback()
    end
  end)
end

events:Enable()