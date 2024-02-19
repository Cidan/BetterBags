---@diagnostic disable: duplicate-set-field,duplicate-doc-field
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
local item = addon:GetModule('ItemRowFrame')

---@param data ItemData
function item.itemRowProto:SetItem(data)
  self.data = data
  self.button:SetItem(data)
  self.button.frame:SetParent(self.frame)
  self.button.frame:SetPoint("LEFT", self.frame, "LEFT", 4, 0)

  local bagid, slotid = data.bagid, data.slotid
  if slotid then
    self.rowButton:SetID(slotid)
  end

  if data.isItemEmpty then
    return
  end

  local quality = data.itemInfo.itemQuality
  self.text:SetVertexColor(unpack(const.ITEM_QUALITY_COLOR[quality]))
  self.rowButton.HighlightTexture:SetGradient("HORIZONTAL", CreateColor(unpack(const.ITEM_QUALITY_COLOR_HIGH[quality])), CreateColor(unpack(const.ITEM_QUALITY_COLOR_LOW[quality])))

  self.button:SetSize(20, 20)
  self.button.Count:Hide()
  self.button.ilvlText:Hide()
  self.button.LockTexture:Hide()
  self.button.button.IconBorder:SetSize(20, 20)

  if bagid then
    self.frame:SetID(bagid)
  end
  self.text:SetText(data.itemInfo.itemName)
  self.rowButton:SetScript("OnEnter", function(s)
    s.HighlightTexture:Show()
    GameTooltip:SetOwner(self.button.frame, "ANCHOR_LEFT")
    if bagid and slotid then
      GameTooltip:SetBagItem(bagid, slotid)
    else
      GameTooltip:SetItemByID(data.itemInfo.itemID)
    end
    GameTooltip:Show()
  end)

  self:AddToMasqueGroup(data.kind)
  self.frame:Show()
  self.rowButton:Show()
end

local buttonCount = 0

---@return ItemRow
function item:_DoCreate()
  local i = setmetatable({}, { __index = item.itemRowProto })
  -- Generate the item button name. This is needed because item
  -- button textures are named after the button itself.
  local name = format("BetterBagsRowItemButton%d", buttonCount)
  buttonCount = buttonCount + 1

  -- Create a hidden parent to the ItemButton frame to work around
  -- item taint introduced in 10.x
  local p = CreateFrame("Frame")
  i.frame = p
  --TODO(lobato): Create our own template for row buttons.
  ---@class Button
  ---@field BattlepayItemTexture Texture
  local rowButton = CreateFrame("Button", name, p, "ContainerFrameItemButtonTemplate")
  rowButton:SetAllPoints(i.frame)
  i.rowButton = rowButton

  -- Button properties are set when setting the item,
  -- and setting them here will have no effect.
  local button = itemFrame:Create()
  i.button = button
  i.button.NormalTexture:Hide()
  i.button.NormalTexture:SetTexture(nil)

  local text = i.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  text:SetParent(i.frame)
  text:SetPoint("LEFT", i.button.frame, "RIGHT", 5, 0)
  text:SetHeight(16)
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

  --TODO(lobato): Recycle these textures instead of creating new ones.
  rowButton:GetNormalTexture():Hide()
  rowButton:GetPushedTexture():Hide()
  rowButton:GetHighlightTexture():Hide()
  rowButton:GetNormalTexture():SetTexture(nil)
  rowButton:GetPushedTexture():SetTexture(nil)
  rowButton:GetHighlightTexture():SetTexture(nil)
  rowButton.BattlepayItemTexture:SetShown(false)
  --rowButton.NormalTexture:Hide()
  --rowButton.NormalTexture:SetParent(nil)
  --rowButton.NormalTexture = nil
  --rowButton.PushedTexture:Hide()
  --rowButton.PushedTexture:SetParent(nil)
  --rowButton.PushedTexture = nil
  --rowButton.NewItemTexture:Hide()
  --rowButton.BattlepayItemTexture:Hide()
  --rowButton:GetHighlightTexture():Hide()
  --rowButton:GetHighlightTexture():SetParent(nil)
  --rowButton.HighlightTexture = nil

  local highlight = rowButton:CreateTexture()
  highlight:SetDrawLayer("BACKGROUND")
  highlight:SetBlendMode("ADD")
  highlight:SetAllPoints()
  highlight:SetTexture("Interface/Buttons/WHITE8x8")
  highlight:Hide()
  rowButton.HighlightTexture = highlight
  rowButton:SetScript("OnLeave", function(s)
    s.HighlightTexture:Hide()
    GameTooltip:Hide()
  end)
  i.frame:SetSize(350, 24)

  return i
end
