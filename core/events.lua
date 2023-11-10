local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
---@field _eventHandler AceEvent-3.0
local events = addon:NewModule('Events')

function events:OnInitialize()
  self._eventHandler = {}
  self._messageMap = {}
  LibStub:GetLibrary('AceEvent-3.0'):Embed(self._eventHandler)
end

---@param event string
---@param callback fun()
---@param arg? any
function events:RegisterMessage(event, callback, arg)
  if self._messageMap[event] == nil then
    self._messageMap[event] = {
      fn = function(...)
        for _, cb in ipairs(self._messageMap[event].cbs) do
          cb(...)
        end
      end,
      cbs = {},
    }
    self._eventHandler:RegisterMessage(event, self._messageMap[event].fn)
  end
  table.insert(self._messageMap[event].cbs, callback)
end

function events:RegisterEvent(event, callback, arg)
end

function events:SendMessage(event, ...)
  self._eventHandler:SendMessage(event, ...)
end

events:Enable()