local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Debug
local debug = addon:GetModule('Debug')

---@param data ItemData
---@param id number
---@return boolean
function debug:IsItem(data, id)
  if data and data.itemInfo and data.itemInfo.itemID == id then
    return true
  end
  return false
end