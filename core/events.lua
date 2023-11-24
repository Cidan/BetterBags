local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Callback
---@field cb fun(...)
---@field a any
local callbackProto = {}

---@class Events: AceModule
---@field _eventHandler AceEvent-3.0
---@field _messageMap table<string, {fn: fun(...), cbs: Callback[]}>
---@field _eventMap table<string, {fn: fun(...), cbs: Callback[]}>
local events = addon:NewModule('Events')

function events:OnInitialize()
  self._eventHandler = {}
  self._messageMap = {}
  self._eventMap = {}
  LibStub:GetLibrary('AceEvent-3.0'):Embed(self._eventHandler)
end

---@param event string
---@param callback fun(...)
---@param arg? any
function events:RegisterMessage(event, callback, arg)
  if self._messageMap[event] == nil then
    self._messageMap[event] = {
      fn = function(...)
        for _, cb in ipairs(self._messageMap[event].cbs) do
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
        for _, cb in ipairs(self._eventMap[event].cbs) do
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

function events:SendMessage(event, ...)
  self._eventHandler:SendMessage(event, ...)
end

events:Enable()