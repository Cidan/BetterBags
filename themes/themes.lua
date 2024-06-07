local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Theme
---@field Portrait fun(frame: BetterBagsBagPortraitTemplate)
---@field Simple fun(frame: Frame)

---@class Themes: AceModule
---@field themes table<string, Theme>
---@field windows table<WindowKind, Frame[]>
local themes = addon:NewModule('Themes')

-- Initialize this bare as we will be adding themes from bare files.
themes.themes = {}

---@param name string
---@param themeTemplate Theme
function themes:RegisterTheme(name, themeTemplate)
  self.themes[name] = themeTemplate
end

-- ApplyTheme is used to apply a theme to every window registered with RegisterWindow.
---@param name string
function themes:ApplyTheme(name)
end

-- RegisterWindow is used to register a window frame to be themed by themes.
---@param kind WindowKind
---@param frame Frame
function themes:RegisterWindow(kind, frame)
end
