local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Theme
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
  self:ApplyTheme('Default')
end

---@param name string
---@param themeTemplate Theme
function themes:RegisterTheme(name, themeTemplate)
  self.themes[name] = themeTemplate
end

-- ApplyTheme is used to apply a theme to every window registered with RegisterWindow.
---@param name string
function themes:ApplyTheme(name)
  assert(self.themes[name], 'Theme does not exist.')
  local theme = self.themes[name]
  for _, frame in pairs(self.windows[const.WINDOW_KIND.PORTRAIT]) do
    theme.Portrait(frame)
  end
end

-- RegisterWindow is used to register a window frame to be themed by themes.
---@param kind WindowKind
---@param frame Frame
function themes:RegisterWindow(kind, frame)
  table.insert(self.windows[kind], frame)
end

---@return string[]
function themes:GetAllThemes()
  local result = {}
  for name, _ in pairs(self.themes) do
    table.insert(result, name)
  end
  return result
end