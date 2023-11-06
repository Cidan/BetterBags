local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)
---@cast addon +AceHook-3.0

function addon:OpenAllBags(requesterFrame)
  print("open")
end

function addon:ToggleAllBags(requesterFrame)
  print("open")
end