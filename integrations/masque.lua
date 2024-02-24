local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class MasqueTheme: AceModule
---@field groups table<string, MasqueGroup>
local masque = addon:NewModule('Masque')

---@class Masque: AceAddon
local Masque = LibStub('Masque', true)

function masque:AddButtonToGroup(group, button)
  if not Masque then
    return
  end
  self.groups[group]:AddButton(button)
end

function masque:RemoveButtonFromGroup(group, button)
  if not Masque then
    return
  end
  if group == nil then
    return
  end
  self.groups[group]:RemoveButton(button)
end

function masque:OnEnable()
  if not Masque then return end
  self.groups = {}
  self.groups["Backpack"] = Masque:Group('BetterBags', 'Backpack')
  self.groups["Bank"] = Masque:Group('BetterBags', 'Bank')

  events:RegisterMessage('item/Updated', function(_, item)
    ---@cast item Item
    local group = item.kind == 'Bank' and self.groups["Bank"] or self.groups["Backpack"]
    group:AddButton(item.button)
    item.button.IconBorder:SetBlendMode("BLEND")
  end)

  events:RegisterMessage('item/Clearing', function(_, item)
    ---@cast item Item
    local group = item.kind == 'Bank' and self.groups["Bank"] or self.groups["Backpack"]
    group:RemoveButton(item.button)
  end)

  events:RegisterMessage('bagslot/Updated', function(_, bag)
    ---@cast bag BagButton
    local group = bag.kind == 'Bank' and self.groups["Bank"] or self.groups["Backpack"]
    group:AddButton(bag.frame)
    bag.frame.IconBorder:SetBlendMode("BLEND")
  end)

  events:RegisterMessage('bagslot/Clearing', function(_, bag)
    ---@cast bag BagButton
    local group = bag.kind == 'Bank' and self.groups["Bank"] or self.groups["Backpack"]
    group:RemoveButton(bag.frame)
  end)

  print("BetterBags: Masque integration enabled.")
end