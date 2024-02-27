local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Header: AceModule
local header = addon:NewModule('Header')

---@class (exact) HeaderFrame
---@field frame Frame
header.headerProto = {}

function header.headerProto:Add()

end

---@return HeaderFrame
function header:Create()
  local h = setmetatable({}, {__index = self.headerProto})
  h.frame = CreateFrame('Frame')
  return h
end