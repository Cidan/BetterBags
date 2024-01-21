local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Config: AceModule
local config = addon:GetModule('Config')

local GUI = LibStub('AceGUI-3.0')

function config:CreateItemListWidget()
  local widget = GUI:Create("InlineGroup")
  --widget.type = "ItemList"
end