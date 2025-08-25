local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- Context is a simple container for passing context between function
-- calls. It works similarly to Go's context package.
---@class (exact) Context: AceModule
---@field private keys table<string, any>
---@field private done boolean
---@field private timeout FunctionContainer
local context = addon:NewModule('Context')

-- New creates a new context object.
---@param event string
---@return Context
function context:New(event)
  local obj = setmetatable({}, {__index = self})
  obj.keys = {}
  obj.done = false
  obj:Set('event', event)
  obj:Set('events', {})
  return obj
end

-- Set sets a value in the context.
---@param key string
---@param value any
function context:Set(key, value)
  if self.done then
    error("context has been cancelled")
  end
  if self.keys['event'] ~= nil and key == 'event' then
    error("the event key for a context can not be overridden")
  end
  self.keys[key] = value
end

-- Get gets a value from the context.
---@param key string
---@return any
function context:Get(key)
  if self.done then
    error("context has been cancelled")
  end
  return self.keys[key]
end

-- Event gets the event from the context.
---@return string
function context:Event()
  return self.keys['event']
end

-- AppendEvent appends an event to the context.
---@param event string
function context:AppendEvent(event)
  self.keys['events'] = self.keys['events'] or {}
  table.insert(self.keys['events'], event)
end

-- Check checks if a key exists in the context.
---@param key string
---@return boolean
function context:IsTrue(key)
  if self.done then
    error("context has been cancelled")
  end
  return self.keys[key] == true
end

-- IsCancelled checks if the context has been cancelled.
function context:IsCancelled()
  return self.done
end

-- GetBool gets a boolean value from the context.
---@param key string
---@return boolean
function context:GetBool(key)
  if self.done then
    error("context has been cancelled")
  end
  return self.keys[key]
end

-- Delete deletes a key from the context.
---@param key string
function context:Delete(key)
  if self.done then
    error("context has been cancelled")
  end
  self.keys[key] = nil
end

-- Cancel cancels the context.
function context:Cancel()
  if self.done then
    error("context has been cancelled")
  end
  self.done = true
  if self.timeout then
    self.timeout:Cancel()
    self.timeout = nil
  end
end

-- Timeout will cancel the context after a certain number of seconds.
---@param seconds number
---@param callback function
function context:Timeout(seconds, callback)
  if self.done then
    error("context has been cancelled")
  end
  if self.timeout then
    error("context already has a timeout")
  end
  self.timeout = C_Timer.NewTimer(seconds, function()
    if self.done then
      return
    end
    self.done = true
    self.timeout = nil
    callback()
  end)
end

function context:HasTimeout()
  return self.timeout ~= nil
end

-- Copy creates a copy of the context and returns it.
-- It does not copy any Timeouts.
---@return Context
function context:Copy()
  if self.done then
    error("context has been cancelled")
  end
  local newContext = context:New(self.keys['event'])
  for key, value in pairs(self.keys) do
    if key ~= 'event' then
      newContext:Set(key, value)
    end
  end
  return newContext
end

---@param obj any
---@param script string
---@param func fun(ctx: Context, ...)
function addon.HookScript(obj, script, func)
  obj:HookScript(script, function(...)
    local ctx = context:New(script)
    func(ctx, unpack({...}))
  end)
end

---@param obj any
---@param script string
---@param func fun(ctx: Context, ...)
function addon.SetScript(obj, script, func)
  obj:SetScript(script, function(...)
    local ctx = context:New(script)
    func(ctx, unpack({...}))
  end)
end