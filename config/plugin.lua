local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Config: AceModule
local config = addon:GetModule('Config')

function config:AddPluginConfig()
end