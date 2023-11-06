local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Hooks: AceModule
local hooks = addon:NewModule('Hooks', 'AceHook-3.0')
---@cast hooks +AceHook-3.0

hooks:Enable()

function hooks:On()
  self:RawHook("OpenAllBags")
end