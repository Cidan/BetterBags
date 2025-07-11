


local addon = GetBetterBags()

---@class Localization: AceModule
---@field data table<string, table<string, string>>
local L = addon:NewModule('Localization')

-- Data is set outside of the initialization function so that
-- it loads when the file is read.
L.data = {}
L.locale = GetLocale()

-- G returns the localized string for the given key.
-- If no localized string is found, the key is returned.
---@param key string
---@return string
function L:G(key)
  if not self.data[key] then return key end
  return self.data[key][L.locale] or key
end

L:Enable()