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
  self.button.frame:SetParent(self.frame)
  self.button.frame:SetPoint("LEFT", self.frame)

  local bagid, slotid = i:GetItemLocation():GetBagAndSlot()
  self.rowButton:SetID(slotid)
  self.rowButton:SetHasItem(i:GetItemIcon())

  local quality = i:GetItemQuality()
  self.text:SetVertexColor(unpack(const.ITEM_QUALITY_COLOR[quality]))
  self.rowButton.HighlightTexture:SetGradient("HORIZONTAL", CreateColor(unpack(const.ITEM_QUALITY_COLOR_HIGH[quality])), CreateColor(unpack(const.ITEM_QUALITY_COLOR_LOW[quality])))

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
  self.rowButton:SetScript("OnMouseWheel", nil)
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
  --TODO(lobato): Style the individual row frame, maybe?
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
  i.frame = p
  --TODO(lobato): Create our own template for row buttons.
  ---@class ItemButton
  local rowButton = CreateFrame("ItemButton", name, p, "ContainerFrameItemButtonTemplate")
  rowButton:SetAllPoints(i.frame)
  i.rowButton = rowButton

  -- Button properties are set when setting the item,
  -- and setting them here will have no effect.
  local button = itemFrame:Create()
  i.button = button

  local text = i.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  text:SetParent(i.frame)
  text:SetPoint("LEFT", i.button.frame, "RIGHT", 5, 0)
  text:SetHeight(30)
  text:SetWidth(310)
  text:SetTextHeight(28)
  text:SetWordWrap(true)
  text:SetJustifyH("LEFT")
  text:SetFont("Fonts\\FRIZQT__.TTF", 14, "THICK")
  text:SetShadowColor(0, 0, 0, 1)
  i.text = text

  local border = i.frame:CreateTexture(nil, "BORDER")
  border:SetColorTexture(0.1, 0.1, 0.1, 1)
  border:SetPoint("BOTTOMLEFT", i.frame)
  border:SetPoint("BOTTOMRIGHT", i.frame)
  border:SetHeight(2)
  border:Hide()
  self.border = border

  rowButton.NormalTexture:Hide()
  rowButton.NormalTexture:SetParent(nil)
  rowButton.NormalTexture = nil
  rowButton.PushedTexture:Hide()
  rowButton.PushedTexture:SetParent(nil)
  rowButton.PushedTexture = nil
  rowButton.NewItemTexture:Hide()
  rowButton.BattlepayItemTexture:Hide()
  rowButton:GetHighlightTexture():Hide()
  rowButton:GetHighlightTexture():SetParent(nil)
  rowButton.HighlightTexture = nil

  local highlight = rowButton:CreateTexture()
  highlight:SetDrawLayer("BACKGROUND")
  highlight:SetBlendMode("ADD")
  highlight:SetAllPoints()
  highlight:SetTexture("Interface/Buttons/WHITE8x8")
  highlight:Hide()
  rowButton.HighlightTexture = highlight
  rowButton:SetScript("OnEnter", function(s)
    s.HighlightTexture:Show()
  end)
  rowButton:SetScript("OnLeave", function(s)
    s.HighlightTexture:Hide()
  end)
  i.frame:SetSize(350, 35)

  return i
end

---@return ItemRow
function item:Create()
  return self._pool:Acquire()
end

item:Enable()