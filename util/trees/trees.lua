local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Trees: AceModule
local trees = addon:NewModule('Trees')

---@return IntervalTree
function trees.NewIntervalTree()
  ---@class IntervalTree
  local tree = setmetatable({}, {__index = trees.IntervalTree})
  return tree
end