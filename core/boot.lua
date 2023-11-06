-- boot.lua handles the initialisation of the addon and the creation of the root module.
local addonName, root = ...

-- BetterBags is the root module of the addon.
---@class BetterBags: AceModule
local addon = LibStub("AceAddon-3.0"):NewAddon(root, addonName, 'AceHook-3.0')

addon:SetDefaultModuleState(false)
