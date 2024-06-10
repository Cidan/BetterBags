local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Animations: AceModule
local animations = addon:GetModule('Animations')

---@class List: AceModule
local list = addon:GetModule('List')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

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
  f:SetText(data.name)
  f:SetScript("OnClick", function()
    themes:ApplyTheme(data.name)
    --[[
    data.Enabled = not data.Enabled
    if data.Enabled then
      f:SetNormalFontObject("GameFontHighlight")
    else
      f:SetNormalFontObject("GameFontDisable")
    end
    ]]--
  end)
end

---@param f BetterBagsPlainTextListButton
---@param data table
function themeConfigFrame:resetThemeItem(f, data)
  f:SetText('')
  f:SetScript("OnClick", nil)
end

---@param callback? fun()
function themeConfigFrame:Show(callback)
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
function themeConfigFrame:Hide(callback)
  PlaySound(SOUNDKIT.GUILD_BANK_OPEN_BAG)
  if callback then
    self.fadeOut.callback = function()
      self.fadeOut.callback = nil
      callback()
    end
  end
  self.fadeOut:Play()
end

function themeConfigFrame:IsShown()
  return self.frame:IsShown()
end


---@param parent Frame
---@return ThemeConfigFrame
function themeConfig:Create(parent)
  local tc = setmetatable({}, {__index = themeConfigFrame}) --[[@as ThemeConfigFrame]]
  tc.frame = CreateFrame("Frame", nil, parent, "DefaultPanelTemplate") --[[@as Frame]]
  tc.frame:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMLEFT', -10, 0)
  tc.frame:SetPoint('TOPRIGHT', parent, 'TOPLEFT', -10, 0)
  tc.frame:SetWidth(300)
  tc.frame:SetTitle("Theme Configuration")
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

  for _, themeName in ipairs(themes:GetAllThemes()) do
    tc.content:AddToStart({name = themeName})
  end
  return tc
end