local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Debug: AceModule
local debug = addon:NewModule('Debug')

function debug:OnEnable()
  print("BetterBags: debug mode enabled")
end

debug:Enable()
