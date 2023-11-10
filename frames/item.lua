local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class ItemFrame: AceModule
local item = addon:NewModule('ItemFrame')

---@class Item
---@field frame ItemButton
---@field IconTexture Texture
---@field Count FontString
---@field Stock FontString
---@field IconBorder Texture
---@field IconQuestTexture Texture
---@field NormalTexture Texture
---@field NewItemTexture Texture
---@field IconOverlay2 Texture
---@field ItemContextOverlay Texture
---@field Cooldown Cooldown
local itemProto = {}

local buttonCount = 0
local children = {
  "IconQuestTexture",
  "IconTexture",
  "Count",
  "Stock",
  "IconBorder",
  "Cooldown",
  "NormalTexture",
  "NewItemTexture",
  "IconOverlay2",
  "ItemContextOverlay"
}

---@param i ItemMixin
function itemProto:SetItem(i)
  assert(i, 'item must be provided')
  self.IconTexture:SetTexture(i:GetItemIcon())
  self.IconTexture:SetTexCoord(0,1,0,1)
  local bagid, slotid = i:GetItemLocation():GetBagAndSlot()
  self.frame:SetBagID(bagid)
  self.frame:Show()
end

---@return Item
function item:Create()
  local i = setmetatable({}, { __index = itemProto })
  -- Generate the item button name. This is needed because item
  -- button textures are named after the button itself.
  local name = format("BetterBagsItemButton%d", buttonCount)
  buttonCount = buttonCount + 1

  ---@class ItemButton: Button
  local f = CreateFrame("ItemButton", name, nil, "ContainerFrameItemButtonTemplate")

  -- Assign the global item button textures to the item button.
  for _, child in pairs(children) do
    i[child] = _G[name..child]
  end
  f:SetSize(37, 37)
  f:RegisterForDrag("LeftButton")
  f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  i.frame = f

  return i
end

item:Enable()
