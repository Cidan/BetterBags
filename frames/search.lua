local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Search: AceModule
local search = addon:NewModule('Search')

function BetterBags_ToggleSearch()
  print("TODO: Search")
end