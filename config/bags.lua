local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Config: AceModule
local config = addon:GetModule('Config')

---@return AceConfig.OptionsTable
function config:GetBagOptions()
  ---@type AceConfig.OptionsTable
  local options = {
    type = "group",
    name = L["Bags"],
    args = {}
  }
  return options
end