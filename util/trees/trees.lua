


local addon = GetBetterBags()

---@class Trees: AceModule
---@field IntervalTree IntervalTree 
local trees = addon:NewModule('Trees')

---@return IntervalTree
function trees.NewIntervalTree()
  ---@class IntervalTree
  local tree = setmetatable({}, {__index = trees.IntervalTree})
  return tree
end