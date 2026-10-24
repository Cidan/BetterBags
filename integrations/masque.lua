local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

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
  self.groups["Vendor"] = Masque:Group('BetterBags', 'Vendor')
  self.groups["Vendor"]:RegisterCallback(self.OnSkinChange, self)
  self.groups["Guild Bank"] = Masque:Group('BetterBags', 'Guild Bank')
  self.groups["Guild Bank"]:RegisterCallback(self.OnSkinChange, self)

  -- The group each item decoration was last added to. Item buttons are redrawn without
  -- being released (and so removed) in between, and Masque's AddButton does nothing for a
  -- button already in the group, so a redrawn button is re-skinned instead: the draw
  -- re-applied BetterBags' quality border (texture coordinates and blend) over the skin.
  self.added = setmetatable({}, { __mode = 'k' })

  ---@param item Item
  ---@param decoration ItemButton
  local function skin(item, decoration)
    if not item.kind then return end
    if not sonata:UsesMasque() then return end
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

  -- BetterBags Next's vendor buttons (next/vendorbutton.lua) are made once and reused, each
  -- announced once. Their square button is skinned as an item button with its parts named;
  -- nothing a draw does to them (icon, border color, count) needs a skin again. Adding a button
  -- already in the group does nothing (Masque's AddButton returns for it).
  self.vendorButtons = setmetatable({}, { __mode = 'k' })

  ---@param b NextVendorButtonFrame
  local function skinVendor(b)
    if not sonata:UsesMasque() then return end
    local group = self.groups["Vendor"]
    group:AddButton(b.button, b:MasqueRegions(), "Item")
    self.added[b.button] = group
  end

  events:RegisterMessage('vendor/NewButton', function(_, b)
    self.vendorButtons[b] = true
    skinVendor(b)
  end)

  -- A card restyles itself on a grid it was not styled for (NextVendorButton:Fit), drawing its icon,
  -- count and highlight over the skin: skinned again, so Masque's skin goes last, as after a theme.
  events:RegisterMessage('vendor/Updated', function(_, b)
    if not sonata:UsesMasque() then return end
    local group = self.groups["Vendor"]
    if self.added[b.button] == group then
      group:ReSkin(b.button)
    else
      skinVendor(b)
    end
  end)

  -- A BetterBags Next theme can resize them (its icons and price row, next-themes.md §6), and Masque
  -- sizes a skin to the button when it skins it (Masque 12.1.0 Core.lua UpdateScale), so each Next
  -- theme applied skins them again. (Bag item buttons re-skin on item/Updated: a resized one draws in
  -- full, itemProto:SetSize.)
  events:RegisterMessage('sonata/NextThemeChanged', function()
    if not sonata:UsesMasque() then return end
    local group = self.groups["Vendor"]
    for b in pairs(self.vendorButtons) do
      if self.added[b.button] == group then
        group:ReSkin(b.button)
      else
        skinVendor(b)
      end
    end
  end)

  -- BetterBags Next's guild bank buttons (next/guildbutton.lua) are Blizzard's own item buttons, made
  -- once and reused, each announced once; Masque finds an item button's parts itself, as for the
  -- item decorations. Every draw rewrites their quality border as an item draw does (Blizzard's
  -- SetItemButtonQuality sets its atlas, past Masque's SetTexture hook, and BetterBags' glow its
  -- coordinates and blend), so each draw (guild/Updated) skins them again, as item/Updated does. Like
  -- vendor buttons they are not drawn again on a theme change.
  self.guildButtons = setmetatable({}, { __mode = 'k' })

  ---@param b NextGuildButtonFrame
  local function skinGuild(b)
    if not sonata:UsesMasque() then return end
    local group = self.groups["Guild Bank"]
    if self.added[b.button] == group then
      group:ReSkin(b.button)
    else
      group:AddButton(b.button)
      self.added[b.button] = group
    end
    self:ReapplyBlend(b.button)
  end

  events:RegisterMessage('guild/NewButton', function(_, b)
    self.guildButtons[b] = true
    skinGuild(b)
  end)

  events:RegisterMessage('guild/Updated', function(_, b)
    self.guildButtons[b] = true
    skinGuild(b)
  end)

  -- Item buttons keep one decoration across themes, which the theme restyles. A theme that
  -- does not use Masque takes the buttons Masque skinned out of their groups (RemoveButton
  -- gives a button its own look back), so Masque's skin does not stay under the theme's;
  -- the next draw under a theme that uses Masque adds them again.
  -- Vendor buttons are not drawn again on a theme change, so a theme that uses Masque adds them back
  -- itself.
  events:RegisterMessage('sonata/ThemeChanged', function()
    if sonata:UsesMasque() then
      for b in pairs(self.vendorButtons) do
        skinVendor(b)
      end
      for b in pairs(self.guildButtons) do
        skinGuild(b)
      end
      return
    end
    for decoration, group in pairs(self.added) do
      group:RemoveButton(decoration)
      self.added[decoration] = nil
    end
  end)

  -- A released item button stays in its group. Item buttons exist for the whole session
  -- (created at boot), and Masque's RemoveButton is a full skin pass restoring the default
  -- look, which the button's next draw undoes with another (leaving Show Bags spent 9.5 ms
  -- un-skinning 145 empty-slot buttons). A released button is hidden; its next draw
  -- re-skins it, or moves it to the other group when it is reused for the other bag.

  events:RegisterMessage('bagbutton/Updated', function(_, bag)
    if not sonata:UsesMasque() then return end
    ---@cast bag BagButton
    local group = bag.kind == const.BAG_KIND.BANK and self.groups["Bank"] or self.groups["Backpack"]
    group:AddButton(bag.frame)
    bag.frame.IconBorder:SetBlendMode("BLEND")
  end)

  events:RegisterMessage('bagbutton/Clearing', function(_, bag)
    if not sonata:UsesMasque() then return end
    ---@cast bag BagButton
    local group = bag.kind == const.BAG_KIND.BANK and self.groups["Bank"] or self.groups["Backpack"]
    group:RemoveButton(bag.frame)
  end)

  print("BetterBags: Masque integration enabled.")
end

-- IsSkinned says whether Masque places a button's parts: the button is in one of BetterBags' Masque groups.
-- A group turned off in Masque's options places them too, with Masque's base skin (Masque 12.1.0
-- Core/Group.lua, __Disable). BetterBags Next's item fitter leaves those parts to Masque (next/itemfit.lua).
---@param button Frame
---@return boolean
function masque:IsSkinned(button)
  return self.added ~= nil and self.added[button] ~= nil
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
