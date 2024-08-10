local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Anchor: AceModule
local anchor = addon:NewModule('Anchor')

---@class AnchorFrame
---@field frame Frame
local anchorFrame = {}

---@return AnchorFrame
function anchor:New()
  local af = setmetatable({}, { __index = anchorFrame })
  af.frame = CreateFrame('Frame', nil, UIParent)
  return af
end