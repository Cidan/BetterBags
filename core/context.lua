local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- Context is a simple container for passing context between function
-- calls. It works similarly to Go's context package.
---@class (exact) Context: AceModule
---@field private keys table<string, any>
local context = addon:NewModule('Context')

-- New creates a new context object.
---@return Context
function context:New()
  local obj = setmetatable({}, {__index = self})
  obj.keys = {}
  return obj
end

-- Set sets a value in the context.
---@param key string
---@param value any
function context:Set(key, value)
  self.keys[key] = value
end

-- Get gets a value from the context.
---@param key string
---@return any
function context:Get(key)
  return self.keys[key]
end

-- Check checks if a key exists in the context.
---@param key string
---@return boolean
function context:IsTrue(key)
  return self.keys[key] == true
end

-- GetBool gets a boolean value from the context.
---@param key string
---@return boolean
function context:GetBool(key)
  return self.keys[key]
end

-- Delete deletes a key from the context.
---@param key string
function context:Delete(key)
  self.keys[key] = nil
end