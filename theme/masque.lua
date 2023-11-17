local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class MasqueTheme: AceModule
---@field groups table<string, MasqueGroup>
local masque = addon:NewModule('Masque')

function masque:OnEnable()
  ---@class Masque: AceAddon
  local Masque = LibStub('Masque', true)
  if not Masque then
    return
  end
  print("yay")
  self.groups = {}
  self.groups["Backpack"] = Masque:Group('BetterBags', 'Backpack')
  self.groups["Bank"] = Masque:Group('BetterBags', 'Bank')
end

function masque:AddButtonToGroup(group, button)
  self.groups[group]:AddButton(button)
end
