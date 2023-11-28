local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class MasqueTheme: AceModule
local masque = addon:GetModule('Masque')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class ItemFrame: AceModule
local itemFrame = addon:GetModule('ItemFrame')

---@class ItemRowFrame: AceModule
local item = addon:NewModule('ItemRowFrame')


---@class ItemRow
---@field frame Frame
---@field button Item
---@field rowButton ItemButton
---@field text FontString
local itemRowProto = {}

---@param i ItemMixin
function itemRowProto:SetItem(i)
  self.button:SetItem(i)

  local bagid, slotid = i:GetItemLocation():GetBagAndSlot()
  self.rowButton:SetID(slotid)
  self.rowButton:SetHasItem(i:GetItemIcon())
  self.rowButton:UpdateNewItem(i:GetItemQuality())
  self.frame:SetID(bagid)
  self.text:SetText(i:GetItemName())
  self.frame:Show()
  self.rowButton:Show()
end

function itemRowProto:ClearItem()
  self.button:ClearItem()

  self.rowButton:SetID(0)
  self.frame:SetID(0)
  self.frame:Hide()
  self.rowButton:Hide()
end

---@return ItemMixin
function itemRowProto:GetMixin()
  return self.button:GetMixin()
end

---@return string
function itemRowProto:GetCategory()
  return self.button:GetCategory()
end

---@return boolean
function itemRowProto:IsNewItem()
  return self.button:IsNewItem()
end

---@param kind BagKind
function itemRowProto:AddToMasqueGroup(kind)
  self.button:AddToMasqueGroup(kind)
end

---@return string
function itemRowProto:GetGUID()
  return self.button:GetMixin():GetItemGUID() or ""
end

function itemRowProto:Release()
  item._pool:Release(self)
end

function itemRowProto:UpdateSearch(text)
  self.button:UpdateSearch(text)
end

local buttonCount = 0

function item:OnInitialize()
  self._pool = CreateObjectPool(self._DoCreate, self._DoReset)
  self._pool:SetResetDisallowedIfNew()
end

---@param i ItemRow
function item:_DoReset(i)
  i:ClearItem()
end

---@return ItemRow
function item:_DoCreate()
  local i = setmetatable({}, { __index = itemRowProto })
  -- Generate the item button name. This is needed because item
  -- button textures are named after the button itself.
  local name = format("BetterBagsRowItemButton%d", buttonCount)
  buttonCount = buttonCount + 1

  -- Create a hidden parent to the ItemButton frame to work around
  -- item taint introduced in 10.x
  local p = CreateFrame("Frame")
  ---@class ItemButton
  local rowButton = CreateFrame("ItemButton", name, p, "ContainerFrameItemButtonTemplate")
  rowButton:SetAllPoints(p)
  i.rowButton = rowButton
  i.frame = p

  local button = itemFrame:Create()
  button.frame:SetParent(i.rowButton)
  button.frame:SetPoint("LEFT", i.rowButton)
  i.frame:SetHeight(button.frame:GetHeight())
  i.button = button

  local text = i.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  text:SetParent(i.frame)
  text:SetPoint("RIGHT", i.frame)
  text:SetHeight(30)
  i.text = text
  i.frame:SetSize(300, 45)
  i.frame:Show()

  --[[
  ---@class ItemButton
  local button = CreateFrame("ItemButton", name, p, "ContainerFrameItemButtonTemplate")

  p:SetSize(37, 37)
  button:SetSize(37, 37)
  button:RegisterForDrag("LeftButton")
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  i.button = button
  button:SetAllPoints(p)
  i.frame = p

  button.ItemSlotBackground = button:CreateTexture(nil, "BACKGROUND", "ItemSlotBackgroundCombinedBagsTemplate", -6);
  button.ItemSlotBackground:SetAllPoints(button);
  button.ItemSlotBackground:Hide()
  events:RegisterEvent('BAG_UPDATE_COOLDOWN', function(_, ...) OnEvent(i) end)
  ]]--
  return i
end

---@return ItemRow
function item:Create()
  return self._pool:Acquire()
end

item:Enable()