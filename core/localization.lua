local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
---@field data table<string, string>
local L = addon:NewModule('Localization')

-- Data is set outside of the initialization function so that
-- it loads when the file is read.
L.data = {}

-- G returns the localized string for the given key.
-- If no localized string is found, the key is returned.
---@param key string
---@return string
function L:G(key)
  return self.data[key] or key
end

-- S sets the localized string for the given key.
---@param key string
---@param value string
---@return nil
function L:S(key, value)
  self.data[key] = value
end

L:Enable()