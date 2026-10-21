local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Config: AceModule
local config = addon:GetModule('Config')

-- AddPluginConfig gives a plugin its page of the settings window (next/settings/content.lua,
-- next-settings.md §4), made from its AceConfig options: a group, or the args of one.
---@param title string
---@param c AceConfig.OptionsTable
function config:AddPluginConfig(title, c)
  addon:GetModule('NextSettingsContent'):AddPlugin(title, c)
end
