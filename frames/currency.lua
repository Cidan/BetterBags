local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Currency: AceModule
local currency = addon:NewModule('Currency')

---@class GridFrame: AceModule
local grid = addon:GetModule('Grid')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class CurrencyItem
---@field frame Frame
---@field icon Texture
---@field name FontString
---@field count FontString
local CurrencyItem = {}

---@class CurrencyFrame
---@field frame Frame
---@field content Grid
---@field private currencyItems CurrencyItem[]
local CurrencyFrame = {}

function CurrencyFrame:Show()
  self.frame:Show()
end

function CurrencyFrame:Hide()
  self.frame:Hide()
end

function CurrencyFrame:Update()
  local index = 1
  repeat
    local info = C_CurrencyInfo.GetCurrencyListInfo(index)
    local item = self.currencyItems[index]
    item.icon:SetTexture(info.iconFileID)
    item.name:SetText(info.name)
    if item.count and not info.isHeader then
      item.count:SetText(tostring(info.quantity))
    end
    index = index + 1
  until index > C_CurrencyInfo.GetCurrencyListSize()
  self.content:Draw()
end

function CurrencyFrame:Setup()
  local index = 1
  repeat
    local info = C_CurrencyInfo.GetCurrencyListInfo(index)
    local item = self:CreateCurrencyItem(index, info.isHeader)
    local ref = index
    item.frame:SetSize(238, 30)
    item.frame:SetScript('OnEnter', function()
      GameTooltip:SetOwner(item.frame, "ANCHOR_RIGHT")
      GameTooltip:SetCurrencyToken(ref)
      GameTooltip:Show()
    end)
    item.frame:SetScript('OnLeave', function()
      GameTooltip:Hide()
    end)
    self.currencyItems[index] = item
    item.frame:Show()
    self.content:AddCell(info.name, item)
    index = index + 1
  until index > C_CurrencyInfo.GetCurrencyListSize()
  self:Update()
  events:RegisterEvent('CURRENCY_DISPLAY_UPDATE', function()
    self:Update()
  end)
end

function CurrencyFrame:CreateCurrencyItem(index, header)
  local item = setmetatable({}, {__index = CurrencyItem})
  item.frame = CreateFrame("Frame", nil, nil, "BackdropTemplate")
  item.frame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  if index % 2 == 0 then
    item.frame:SetBackdropColor(0, 0, 0, .2)
  else
    item.frame:SetBackdropColor(0, 0, 0, .1)
  end

  item.icon = item.frame:CreateTexture(nil, "ARTWORK")
  item.icon:SetSize(24, 24)
  item.icon:SetPoint("LEFT", item.frame, "LEFT", 0, 0)

  if header then
    item.name = item.frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  else
    item.name = item.frame:CreateFontString(nil, "ARTWORK", "Game12Font")
  end
  item.name:SetPoint("LEFT", item.icon, "RIGHT", 5, 0)

  item.count = item.frame:CreateFontString(nil, "ARTWORK", "Number12Font")
  item.count:SetPoint("RIGHT", item.frame, "RIGHT", -5, 0)

  return item
end

---@param parent Frame
---@return CurrencyFrame
function currency:Create(parent)
  ---@class CurrencyFrame
  local b = {}
  setmetatable(b, {__index = CurrencyFrame})

  b.currencyItems = {}

  ---CURRENCY_DISPLAY_UPDATE
  local frame = CreateFrame('Frame', 'BetterBagsCurrencyFrame', UIParent, "DefaultPanelTemplate") --[[@as Frame]]
  frame:Hide()
  frame:SetParent(parent)
  frame:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMLEFT', -10, 0)
  frame:SetPoint('TOPRIGHT', parent, 'TOPLEFT', -10, 0)
  frame:SetWidth(260)
  frame:SetScript('OnShow', function()
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
  end)
  frame:SetScript('OnHide', function()
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
  end)
  b.frame = frame

  local g = grid:Create(b.frame)
  g:GetContainer():SetPoint("TOPLEFT", b.frame, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET+4, const.OFFSETS.BAG_TOP_INSET)
  g:GetContainer():SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMRIGHT", const.OFFSETS.BAG_RIGHT_INSET, const.OFFSETS.BAG_BOTTOM_INSET)
  g.maxCellWidth = 1
  g.spacing = 0
  b.content = g
  b:Setup()

  return b
end