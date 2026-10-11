local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class MasqueTheme: AceModule
---@field groups table<string, MasqueGroup>
local masque = addon:NewModule('Masque')

---@class Masque: AceAddon
local Masque = LibStub('Masque', true)

---@private
function masque:AddButtonToGroup(group, button)
  if not Masque then
    return
  end
  self.groups[group]:AddButton(button)
end

---@private
function masque:RemoveButtonFromGroup(group, button)
  if not Masque then
    return
  end
  if group == nil then
    return
  end
  self.groups[group]:RemoveButton(button)
end

---@param group string
---@return boolean
function masque:IsGroupEnabled(group)
  local _ = group
  if not Masque then
    return false
  end
  -- TODO(lobato): implement this
  return false
  --return not self.groups[group].db.Disabled
end

function masque:OnEnable()
  if not Masque then return end
  debug:Log("Masque", "Masque enabled.")
  self.groups = {}
  self.groups["Backpack"] = Masque:Group('BetterBags', 'Backpack')
  self.groups["Backpack"]:RegisterCallback(self.OnSkinChange, self)
  self.groups["Bank"] = Masque:Group('BetterBags', 'Bank')
  self.groups["Bank"]:RegisterCallback(self.OnSkinChange, self)

  -- The group each item decoration was last added to. Item buttons are redrawn without
  -- being released (and so removed) in between, and Masque's AddButton does nothing for a
  -- button already in the group, so a redrawn button is re-skinned instead: the draw
  -- re-applied BetterBags' quality border (texture coordinates and blend) over the skin.
  self.added = setmetatable({}, { __mode = 'k' })

  ---@param item Item
  ---@param decoration ItemButton
  local function skin(item, decoration)
    if not item.kind then return end
    if themes:GetCurrentTheme().DisableMasque then return end
    local group = item.kind == const.BAG_KIND.BANK and self.groups["Bank"] or self.groups["Backpack"]
    if self.added[decoration] == group then
      group:ReSkin(decoration)
    else
      group:AddButton(decoration)
      self.added[decoration] = group
    end
    self:ReapplyBlend(decoration)
  end

  events:RegisterMessage('item/NewButton', function(_, item, decoration)
    skin(item, decoration)
  end)

  events:RegisterMessage('item/Updated', function(_, item, decoration)
    skin(item, decoration)
  end)

  events:RegisterMessage('item/Clearing', function(_, item, decoration)
    ---@cast item Item
    if not item.kind then return end
    if themes:GetCurrentTheme().DisableMasque then return end
    local group = item.kind == const.BAG_KIND.BANK and self.groups["Bank"] or self.groups["Backpack"]
    group:RemoveButton(decoration)
    self.added[decoration] = nil
  end)

  events:RegisterMessage('bagbutton/Updated', function(_, bag)
    if themes:GetCurrentTheme().DisableMasque then return end
    ---@cast bag BagButton
    local group = bag.kind == const.BAG_KIND.BANK and self.groups["Bank"] or self.groups["Backpack"]
    group:AddButton(bag.frame)
    bag.frame.IconBorder:SetBlendMode("BLEND")
  end)

  events:RegisterMessage('bagbutton/Clearing', function(_, bag)
    if themes:GetCurrentTheme().DisableMasque then return end
    ---@cast bag BagButton
    local group = bag.kind == const.BAG_KIND.BANK and self.groups["Bank"] or self.groups["Backpack"]
    group:RemoveButton(bag.frame)
  end)

  print("BetterBags: Masque integration enabled.")
end

---@param button Button|ItemButton
function masque:ReapplyBlend(button)
  local blend = button.IconBorder:GetBlendMode()
  if blend == nil or blend == "DISABLE" then
    button.IconBorder:SetBlendMode("BLEND")
  else
    button.IconBorder:SetBlendMode(button.IconBorder:GetBlendMode())
  end
end

---@param group MasqueGroup
function masque:OnSkinChange(group)
  for _, button in pairs(group.Buttons) do
    self:ReapplyBlend(button)
  end
end
