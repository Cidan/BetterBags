local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Currency: AceModule
local currency = addon:NewModule('Currency')

---@class GridFrame: AceModule
local grid = addon:GetModule('Grid')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class CurrencyItem
---@field frame Frame
---@field icon Texture
---@field name FontString
local CurrencyItem = {}

---@class CurrencyFrame
---@field frame Frame
---@field content Grid
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
    print(info.name)
    index = index + 1
  until index > C_CurrencyInfo.GetCurrencyListSize()
  self.content:Draw()
end

function CurrencyFrame:Setup()
  local index = 1
  repeat
    local info = C_CurrencyInfo.GetCurrencyListInfo(index)
    local item = self:CreateCurrencyItem()
    item.frame:SetSize(20, 20)
    item.icon:SetTexture(info.iconFileID)
    item.name:SetText(info.name)
    item.frame:Show()
    self.content:AddCell(info.name, item)
    index = index + 1
  until index > C_CurrencyInfo.GetCurrencyListSize()
end

function CurrencyFrame:CreateCurrencyItem()
  local item = setmetatable({}, {__index = CurrencyItem})
  item.frame = CreateFrame("Frame")
  item.icon = item.frame:CreateTexture(nil, "ARTWORK")
  item.icon:SetSize(16, 16)
  item.icon:SetPoint("LEFT", item.frame, "LEFT", 0, 0)
  item.name = item.frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  item.name:SetPoint("LEFT", item.icon, "RIGHT", 5, 0)
  return item
end

---@param parent Frame
---@return CurrencyFrame
function currency:Create(parent)
  ---@class CurrencyFrame
  local b = {}
  setmetatable(b, {__index = CurrencyFrame})

  ---CURRENCY_DISPLAY_UPDATE
  local frame = CreateFrame('Frame', 'BetterBagsCurrencyFrame', UIParent, "DefaultPanelTemplate") --[[@as Frame]]
  frame:Hide()
  frame:SetParent(parent)
  frame:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMLEFT', -10, 0)
  frame:SetPoint('TOPRIGHT', parent, 'TOPLEFT', -10, 0)
  frame:SetWidth(200)
  frame:SetScript('OnShow', function()
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
  end)
  frame:SetScript('OnHide', function()
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
  end)
  b.frame = frame

  local g = grid:Create(b.frame)
  g:GetContainer():SetPoint("TOPLEFT", b.frame, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET, const.OFFSETS.BAG_TOP_INSET)
  g:GetContainer():SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMRIGHT", const.OFFSETS.BAG_RIGHT_INSET, const.OFFSETS.BAG_BOTTOM_INSET)
  g.maxCellWidth = 1
  b.content = g
  b:Setup()

  return b
end