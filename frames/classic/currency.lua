---@diagnostic disable: duplicate-set-field,duplicate-doc-field
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

---@class Animations: AceModule
local animations = addon:GetModule('Animations')

---@class CurrencyItem: Item
---@field frame Frame
---@field icon Texture
---@field name FontString
---@field count FontString
---@field index number
local CurrencyItem = {}

function CurrencyItem:Release()
  self.frame:ClearAllPoints()
  self.frame:Hide()
end

---@param ref number
---@return CurrencyInfo
local function getCurrencyInfo(ref)
  local name, isHeader, isExpanded,
  isUnused, isWatched, count, icon,
  maximum, hasWeeklyLimit,
  currentWeeklyAmount, unknown, itemID = GetCurrencyListInfo(ref)
  return {
    name = name,
    isHeader = isHeader,
    isHeaderExpanded = isExpanded,
    isTypeUnused = isUnused,
    isShowInBackpack = isWatched,
    quantity = count,
    iconFileID = icon,
    maxQuantity = maximum,
    canEarnPerWeek = hasWeeklyLimit,
    quantityEarnedThisWeek = currentWeeklyAmount,
    unknown = unknown,
    itemID = itemID
  }
end

---@class CurrencyIconGrid
---@field iconGrid Grid
---@field private iconIndex CurrencyItem[]
---@field fadeIn AnimationGroup
---@field fadeOut AnimationGroup
local CurrencyIconGrid = {}

function CurrencyIconGrid:Show()
  self.iconGrid.frame:Show()
end

function CurrencyIconGrid:Hide(callback)
  -- Support optional callback parameter used by windowGrouping
  if callback then
    self.fadeOut.callback = callback
    self.fadeOut:Play()
  else
    self.iconGrid.frame:Hide()
  end
end

function CurrencyIconGrid:IsShown()
  return self.iconGrid.frame:IsShown()
end

function CurrencyIconGrid:Update()
  for _, cell in pairs(self.iconGrid.cells) do
    ---@cast cell CurrencyItem
    cell:Release()
  end
  self.iconGrid:Wipe()
  local index = 1
  local showCount = 0
  repeat
    local ref = index
    local info = getCurrencyInfo(ref)
    if info and info.isShowInBackpack and showCount < 7 then
      local icon = self.iconIndex[index]
      if not icon then
        icon = self:CreateCurrencyItem(index)
        icon.frame:SetSize(70, 18)
        icon.frame:SetScript('OnEnter', function()
          GameTooltip:SetOwner(icon.frame, "ANCHOR_RIGHT")
          GameTooltip:SetCurrencyToken(ref)
          GameTooltip:Show()
        end)
        icon.frame:SetScript('OnLeave', function()
          GameTooltip:Hide()
        end)
        icon.icon:SetSize(18, 18)
        icon.count:ClearAllPoints()
        icon.count:SetPoint("LEFT", icon.icon, "RIGHT", 5, 0)
        icon.frame:Show()
        self.iconIndex[index] = icon
      end
      self.iconGrid:AddCell(info.name, icon)
      icon.icon:SetTexture(info.iconFileID)
      icon.count:SetText(BreakUpLargeNumbers(info.quantity))
      icon.frame:SetWidth(icon.count:GetStringWidth() + icon.icon:GetWidth() + 7)
      showCount = showCount + 1
    end
    index = index + 1
  until index > GetCurrencyListSize()
  local w, h = self.iconGrid:Draw({
    cells = self.iconGrid.cells,
    maxWidthPerRow = 1024,
  })
  self.iconGrid:GetContainer():SetSize(w, h)
end

---@param index number
---@return CurrencyItem
function CurrencyIconGrid:CreateCurrencyItem(index)
  local item = setmetatable({}, {__index = CurrencyItem})
  item.frame = CreateFrame("Frame", nil, nil, "BackdropTemplate") --[[@as Frame]]
  item.frame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  item.frame:SetBackdropColor(1, 1, 0, 0)
  item.icon = item.frame:CreateTexture(nil, "ARTWORK")
  item.icon:SetSize(24, 24)
  item.icon:SetPoint("LEFT", item.frame, "LEFT", 0, 0)

  item.count = item.frame:CreateFontString(nil, "ARTWORK", "Number12Font")
  item.count:SetPoint("RIGHT", item.frame, "RIGHT", -5, 0)
  _ = index

  return item
end

---@param parent Frame
---@return CurrencyIconGrid
function currency:CreateIconGrid(parent)
  ---@class CurrencyIconGrid
  local b = {}
  setmetatable(b, {__index = CurrencyIconGrid})

  b.iconIndex = {}

  -- Setup the currency grid
  local g = grid:Create(parent)
  g:GetContainer():ClearAllPoints()
  g:GetContainer():SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", const.OFFSETS.BAG_LEFT_INSET+4, const.OFFSETS.BAG_BOTTOM_INSET+3)
  g:GetContainer():SetWidth(200)
  g:HideScrollBar()
  g.maxCellWidth = 7
  b.iconGrid = g

  -- Attach fade animations for windowGrouping compatibility
  b.fadeIn, b.fadeOut = animations:AttachFadeGroup(g:GetContainer())

  b:Update()
  events:RegisterEvent('CURRENCY_DISPLAY_UPDATE', function()
    b:Update()
  end)
  -- Listen for manual updates from the currency options pane
  events:RegisterMessage('currency/Updated', function()
    b:Update()
  end)
  return b
end
