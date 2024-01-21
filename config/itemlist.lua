local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Config: AceModule
local config = addon:GetModule('Config')

local GUI = LibStub('AceGUI-3.0')

local function SetMultiselect(self, flag)
end

local function SetLabel(self, name)
end

local function SetList(self, values)
end

local function SetDisabled(self, disabled)
end

local function SetItemValue(self, key, value)
end

function config:CreateItemListWidget()
  local widget = GUI:Create("InlineGroup")
  ---@cast widget +AceItemList
  widget.type = "ItemList"
  widget["SetMultiselect"] = SetMultiselect
  widget["SetLabel"] = SetLabel
  widget["SetList"] = SetList
  widget["SetDisabled"] = SetDisabled
  widget["SetItemValue"] = SetItemValue
  return widget
end
