local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:NewModule('Events', 'AceEvent-3.0')
---@cast events +AceEvent-3.0

events:Enable()