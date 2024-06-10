local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Animations: AceModule
local animations = addon:GetModule('Animations')

---@class List: AceModule
local list = addon:GetModule('List')

---@class ThemeConfig: AceModule
local themeConfig = addon:NewModule('ThemeConfig')

---@class BetterBagsPlainTextListButton: Button

---@class (exact) ThemeConfigFrame
---@field frame Frame
---@field content ListFrame
---@field package fadeIn AnimationGroup
---@field package fadeOut AnimationGroup
local themeConfigFrame = {}

---@param f BetterBagsPlainTextListButton
---@param data table
function themeConfigFrame:initThemeItem(f, data)
  f:SetHeight(20)
  f:SetNormalFontObject("GameFontHighlight")
  f:SetText(data.Name)
  f:SetScript("OnClick", function()
    data.Enabled = not data.Enabled
    if data.Enabled then
      f:SetNormalFontObject("GameFontHighlight")
    else
      f:SetNormalFontObject("GameFontDisable")
    end
  end)
end

---@param f BetterBagsPlainTextListButton
---@param data table
function themeConfigFrame:resetThemeItem(f, data)
  f:SetText('')
  f:SetScript("OnClick", nil)
end

---@param parent Frame
---@return ThemeConfigFrame
function themeConfig:Create(parent)
  local tc = setmetatable({}, {__index = themeConfigFrame}) --[[@as ThemeConfigFrame]]
  tc.frame = CreateFrame("Frame", nil, parent, "DefaultPanelTemplate") --[[@as Frame]]
  tc.frame:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMLEFT', -10, 0)
  tc.frame:SetPoint('TOPRIGHT', parent, 'TOPLEFT', -10, 0)
  tc.frame:SetWidth(300)
  tc.frame:SetTitle("Configure Categories")
  tc.frame:SetIgnoreParentScale(true)
  tc.frame:SetScale(UIParent:GetScale())
  tc.frame:Hide()

  tc.fadeIn, tc.fadeOut = animations:AttachFadeAndSlideLeft(tc.frame)
  tc.content = list:Create(tc.frame)
  tc.content.frame:SetAllPoints()

  tc.content:SetupDataSource("BetterBagsPlainTextListButton", function(f, data)
    ---@cast f BetterBagsPlainTextListButton
    tc:initThemeItem(f, data)
  end,
  function(f, data)
    ---@cast f BetterBagsPlainTextListButton
    tc:resetThemeItem(f, data)
  end)
  return tc
end