local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- Context is a simple container for passing context between function
-- calls. It works similarly to Go's context package.
---@class (exact) Context: AceModule
---@field private keys table<string, any>
---@field private done boolean
local context = addon:NewModule('Context')

-- New creates a new context object.
---@return Context
function context:New()
  local obj = setmetatable({}, {__index = self})
  obj.keys = {}
  obj.done = false
  return obj
end

-- Set sets a value in the context.
---@param key string
---@param value any
function context:Set(key, value)
  if self.done then
    error("context has been cancelled")
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

-- Check checks if a key exists in the context.
---@param key string
---@return boolean
function context:IsTrue(key)
  if self.done then
    error("context has been cancelled")
  end
  return self.keys[key] == true
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
end

-- Timeout will cancel the context after a certain number of seconds.
---@param seconds number
---@param callback function
function context:Timeout(seconds, callback)
  if self.done then
    error("context has been cancelled")
  end
  C_Timer.After(seconds, function()
    if self.done then
      return
    end
    self.done = true
    callback()
  end)
end

-- Copy creates a copy of the context and returns it.
-- It does not copy any Timeouts.
---@return Context
function context:Copy()
  if self.done then
    error("context has been cancelled")
  end
  local newContext = context:New()
  for key, value in pairs(self.keys) do
    newContext:Set(key, value)
  end
  return newContext
end