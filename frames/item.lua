local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class ItemFrame: AceModule
local item = addon:NewModule('Item')

---@class Item
---@field frame ItemButton
---@field IconTexture Texture
local itemProto = {}

local buttonCount = 0
-- TODO(lobato): Add field annotations for the children in itemProto.
local children = {
  "Cooldown",
  "IconBorder",
  "IconTexture",
  "IconQuestTexture",
  "Count",
  "Stock",
  "NormalTexture",
  "NewItemTexture",
  "IconOverlay2",
  "ItemContextOverlay"
}

---@param i ItemMixin
function itemProto:SetItem(i)
  assert(i, 'item must be provided')
end

---@return Item
function item:Create()
  local i = setmetatable({}, { __index = itemProto })
  -- Generate the item button name. This is needed because item
  -- button textures are named after the button itself.
  local name = format("BetterBagsItemButton%d", buttonCount)
  buttonCount = buttonCount + 1

  ---@class ItemButton: Frame
  local f = CreateFrame("ItemButton", name, nil, "ContainerFrameItemButtonTemplate")

  -- Assign the global item button textures to the item button.
  for _, child in pairs(children) do
    i[child] = _G[name..child]
  end

  f:SetSize(37, 37)
  i.frame = f

  return i
end

item:Enable()
item:Create()
