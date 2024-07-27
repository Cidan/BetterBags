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

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Fonts: AceModule
local fonts = addon:GetModule('Fonts')

---@class Animations: AceModule
local animations = addon:GetModule('Animations')

---@class CurrencyGrid
---@field frame Frame
local CurrencyGrid = {}

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

---@class CurrencyFrame
---@field frame Frame
---@field content Grid
---@field iconGrid Grid
---@field loaded boolean
---@field private fadeIn AnimationGroup
---@field private fadeOut AnimationGroup
---@field private iconIndex CurrencyItem[]
---@field private currencyItems CurrencyItem[]
local CurrencyFrame = {}

---@param callback? fun()
function CurrencyFrame:Show(callback)
  PlaySound(SOUNDKIT.GUILD_BANK_OPEN_BAG)
  if callback then
    self.fadeIn.callback = function()
      self.fadeIn.callback = nil
      callback()
    end
  end
  self.fadeIn:Play()
end

---@param callback? fun()
function CurrencyFrame:Hide(callback)
  PlaySound(SOUNDKIT.GUILD_BANK_OPEN_BAG)
  if callback then
    self.fadeOut.callback = function()
      self.fadeOut.callback = nil
      callback()
    end
  end
  self.fadeOut:Play()
end

function CurrencyFrame:IsShown()
  return self.frame:IsShown()
end

---@param index number
---@param info CurrencyInfo
---@return CurrencyItem|nil
function CurrencyFrame:GetCurrencyItem(index, info)
  if not info then return nil end
  local item = self.currencyItems[info.name]
  if not item then
    item = self:CreateCurrencyItem(index, info.isHeader)
    item.frame:SetSize(232, 30)
    if not info.isHeader then
      item.frame:SetScript('OnEnter', function()
        GameTooltip:SetOwner(item.frame, "ANCHOR_RIGHT")
        GameTooltip:SetCurrencyToken(item.index)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to add or remove this currency to and from your backpack.", 1, 1, 1, true)
        GameTooltip:Show()
      end)
      item.frame:SetScript('OnLeave', function()
        GameTooltip:Hide()
      end)
      item.frame:SetScript('OnMouseDown', function()
        local refinfo = C_CurrencyInfo.GetCurrencyListInfo(item.index)
        if refinfo.isShowInBackpack then
          C_CurrencyInfo.SetCurrencyBackpack(item.index, false)
        else
          C_CurrencyInfo.SetCurrencyBackpack(item.index, true)
        end
        self:Update()
      end)
    end
    item.frame:Show()
    self.currencyItems[info.name] = item
    self.content:AddCell(info.name, item)
  end
  item.index = index
  return item
end

function CurrencyFrame:Update()
  for _, cell in pairs(self.iconGrid.cells) do
    ---@cast cell CurrencyItem
    cell:Release()
  end
  self.iconGrid:Wipe()
  local index = 1
  local showCount = 0
  repeat
    local ref = index
    local info = C_CurrencyInfo.GetCurrencyListInfo(ref)
    if info and info.isHeader then
      C_CurrencyInfo.ExpandCurrencyList(ref, true)
    end
    local item = self:GetCurrencyItem(ref, info)
    if item then
      item.icon:SetTexture(info.iconFileID)
      item.name:SetText(info.name)
      if item.count and not info.isHeader then
        item.count:SetText(BreakUpLargeNumbers(info.quantity))
      end
      if info.isShowInBackpack then
        item.frame:SetBackdropColor(1, 1, 0, .2)
        if showCount < 7 then
          local icon = self.iconIndex[index]
          if not icon then
            icon = self:CreateCurrencyItem(index, false, true)
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
      elseif index % 2 == 0 then
        item.frame:SetBackdropColor(0, 0, 0, .2)
      else
        item.frame:SetBackdropColor(0, 0, 0, .1)
      end
      item.frame:Show()
    else
    end
    index = index + 1
  until index > C_CurrencyInfo.GetCurrencyListSize()
  self.content:Sort(function(a, b)
    ---@cast a CurrencyItem
    ---@cast b CurrencyItem
    return a.index < b.index
  end)
  self.content:Draw({
    cells = self.content.cells,
    maxWidthPerRow = 1,
  })
  local w, h = self.iconGrid:Draw({
    cells = self.iconGrid.cells,
    maxWidthPerRow = 1024,
  })
  self.iconGrid:GetContainer():SetSize(w, h)
end

---@param index number
---@param header boolean
---@param nobackdrop? boolean
---@return CurrencyItem
function CurrencyFrame:CreateCurrencyItem(index, header, nobackdrop)
  local item = setmetatable({}, {__index = CurrencyItem})
  item.frame = CreateFrame("Frame", nil, nil, "BackdropTemplate") --[[@as Frame]]
  item.frame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  if not nobackdrop then
    if index % 2 == 0 then
      item.frame:SetBackdropColor(0, 0, 0, .2)
    else
      item.frame:SetBackdropColor(0, 0, 0, .1)
    end
  else
    item.frame:SetBackdropColor(1, 1, 0, 0)
  end
  item.icon = item.frame:CreateTexture(nil, "ARTWORK")
  item.icon:SetSize(24, 24)
  item.icon:SetPoint("LEFT", item.frame, "LEFT", 0, 0)

  if header then
    item.name = item.frame:CreateFontString(nil, "ARTWORK")
    item.name:SetFontObject(fonts.UnitFrame12Yellow)
  else
    item.name = item.frame:CreateFontString(nil, "ARTWORK")
    item.name:SetFontObject(fonts.UnitFrame12White)
  end
  item.name:SetPoint("LEFT", item.icon, "RIGHT", 5, 0)

  item.count = item.frame:CreateFontString(nil, "ARTWORK", "Number12Font")
  item.count:SetPoint("RIGHT", item.frame, "RIGHT", -5, 0)

  return item
end

---@param parent Frame
---@param iconParent Frame
---@return CurrencyFrame
function currency:Create(parent, iconParent)
  ---@class CurrencyFrame
  local b = {}
  setmetatable(b, {__index = CurrencyFrame})

  b.currencyItems = {}
  b.iconIndex = {}
  b.loaded = false

  ---CURRENCY_DISPLAY_UPDATE
  local frame = CreateFrame('Frame', 'BetterBagsCurrencyFrame', UIParent) --[[@as Frame]]
  frame:Hide()
  frame:SetParent(parent)
  frame:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMLEFT', -10, 0)
  frame:SetPoint('TOPRIGHT', parent, 'TOPLEFT', -10, 0)
  frame:SetWidth(260)

  themes:RegisterSimpleWindow(frame, L:G("Currencies"))

  b.fadeIn, b.fadeOut = animations:AttachFadeAndSlideLeft(frame)
  b.frame = frame

  local g = grid:Create(b.frame)
  g:GetContainer():SetPoint("TOPLEFT", b.frame, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET+4, const.OFFSETS.BAG_TOP_INSET)
  g:GetContainer():SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMRIGHT", const.OFFSETS.BAG_RIGHT_INSET, const.OFFSETS.BAG_BOTTOM_INSET)
  g.maxCellWidth = 1
  g.spacing = 0
  b.content = g

  b.iconGrid = self:CreateIconGrid(iconParent)
  b:Update()
  events:RegisterEvent('CURRENCY_DISPLAY_UPDATE', function()
    b:Update()
  end)
  return b
end

function currency:CreateIconGrid(parent)
  -- Setup the currency grid
  local g = grid:Create(parent)
  g:GetContainer():ClearAllPoints()
  g:GetContainer():SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", const.OFFSETS.BAG_LEFT_INSET+4, const.OFFSETS.BAG_BOTTOM_INSET+3)
  g:GetContainer():SetWidth(200)
  g:HideScrollBar()
  g.maxCellWidth = 7
  return g
end
