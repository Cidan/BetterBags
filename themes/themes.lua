local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Database: AceModule
local db = addon:GetModule('Database')

---@class Theme
---@field key? string The key used to identify this theme.
---@field Name string The display name used by this theme in the theme selection window.
---@field Description string A description of the theme used by this theme in the theme selection window.
---@field Portrait fun(frame: BetterBagsBagPortraitTemplate) A function that applies the theme to a portrait frame.
---@field Simple fun(frame: Frame) A function that applies the theme to a simple frame.

---@class Themes: AceModule
---@field themes table<string, Theme>
---@field windows table<WindowKind, Frame[]>
local themes = addon:NewModule('Themes')

-- Initialize this bare as we will be adding themes from bare files.
themes.themes = {}

function themes:OnInitialize()
  self.windows = {
    [const.WINDOW_KIND.PORTRAIT] = {},
    [const.WINDOW_KIND.SIMPLE] = {}
  }
end

function themes:OnEnable()
  local theme = db:GetTheme()
  if self.themes[theme] then
    self:ApplyTheme(theme)
  else
    self:ApplyTheme('Default')
  end
end

---@param key string
---@param themeTemplate Theme
function themes:RegisterTheme(key, themeTemplate)
  themeTemplate.key = key
  self.themes[key] = themeTemplate
end

-- ApplyTheme is used to apply a theme to every window registered with RegisterWindow.
---@param key string
function themes:ApplyTheme(key)
  assert(self.themes[key], 'Theme does not exist.')
  local theme = self.themes[key]
  for _, frame in pairs(self.windows[const.WINDOW_KIND.PORTRAIT]) do
    theme.Portrait(frame)
  end
  db:SetTheme(key)
end

-- RegisterWindow is used to register a window frame to be themed by themes.
---@param kind WindowKind
---@param frame Frame
function themes:RegisterWindow(kind, frame)
  table.insert(self.windows[kind], frame)
end

---@return table<string, Theme>
function themes:GetAllThemes()
  return self.themes
end