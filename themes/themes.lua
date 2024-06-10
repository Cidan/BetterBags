local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Database: AceModule
local db = addon:GetModule('Database')

---@class Theme
---@field key? string The key used to identify this theme. This will be set by the Themes module when registering the theme, you do not need to provide this.
---@field Name string The display name used by this theme in the theme selection window.
---@field Description string A description of the theme used by this theme in the theme selection window.
---@field Portrait fun(frame: BetterBagsBagPortraitTemplate) A function that applies the theme to a portrait frame.
---@field Simple fun(frame: Frame) A function that applies the theme to a simple frame.
---@field Flat fun(frame: Frame) A function that applies the theme to a flat frame.
---@field Opacity fun(frame: Frame, opacity: number) A callback that is called when the user changes the opacity of the frame. You should use this to change the alpha of your backdrops.
---@field SectionFont fun(font: FontString) A function that applies the theme to a section font.

---@class Themes: AceModule
---@field themes table<string, Theme>
---@field windows table<WindowKind, Frame[]>
---@field sectionFonts table<string, FontString>
local themes = addon:NewModule('Themes')

-- Initialize this bare as we will be adding themes from bare files.
themes.themes = {}

function themes:OnInitialize()
  self.windows = {
    [const.WINDOW_KIND.PORTRAIT] = {},
    [const.WINDOW_KIND.SIMPLE] = {},
    [const.WINDOW_KIND.FLAT] = {}
  }
  self.sectionFonts = {}
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

  -- Apply all portrait themes.
  for _, frame in pairs(self.windows[const.WINDOW_KIND.PORTRAIT]) do
    theme.Portrait(frame)
    local sizeInfo = db:GetBagSizeInfo(const.BAG_KIND.BACKPACK, db:GetBagView(const.BAG_KIND.BACKPACK))
    theme.Opacity(frame, sizeInfo.opacity)
  end

  -- Apply all simple frame themes.
  for _, frame in pairs(self.windows[const.WINDOW_KIND.SIMPLE]) do
    theme.Simple(frame)
    local sizeInfo = db:GetBagSizeInfo(const.BAG_KIND.BACKPACK, db:GetBagView(const.BAG_KIND.BACKPACK))
    theme.Opacity(frame, sizeInfo.opacity)
  end

  -- Apply all flat frame themes.
  for _, frame in pairs(self.windows[const.WINDOW_KIND.FLAT]) do
    theme.Flat(frame)
  end

  -- Apply all section fonts.
  for _, font in pairs(self.sectionFonts) do
    theme.SectionFont(font)
  end

  db:SetTheme(key)
end

-- RegisterPortraitWindow is used to register a protrait window frame to be themed by themes.
---@param frame Frame
function themes:RegisterPortraitWindow(frame)
  table.insert(self.windows[const.WINDOW_KIND.PORTRAIT], frame)
end

-- RegisterSimpleWindow is used to register a protrait window frame to be themed by themes.
---@param frame Frame
function themes:RegisterSimpleWindow(frame)
  table.insert(self.windows[const.WINDOW_KIND.SIMPLE], frame)
end

-- RegisterFlatWindow is used to register a protrait window frame to be themed by themes.
---@param frame Frame
function themes:RegisterFlatWindow(frame)
  table.insert(self.windows[const.WINDOW_KIND.FLAT], frame)
end

-- RegisterSectionFont is used to register a font to be used in the section headers.
---@param font FontString
function themes:RegisterSectionFont(font)
  table.insert(self.sectionFonts, font)
end

---@return table<string, Theme>
function themes:GetAllThemes()
  return self.themes
end

function themes:UpdateOpacity()
  local theme = self.themes[db:GetTheme()]
  for _, frame in pairs(self.windows[const.WINDOW_KIND.PORTRAIT]) do
    local sizeInfo = db:GetBagSizeInfo(const.BAG_KIND.BACKPACK, db:GetBagView(const.BAG_KIND.BACKPACK))
    theme.Opacity(frame, sizeInfo.opacity)
  end
  for _, frame in pairs(self.windows[const.WINDOW_KIND.SIMPLE]) do
    local sizeInfo = db:GetBagSizeInfo(const.BAG_KIND.BACKPACK, db:GetBagView(const.BAG_KIND.BACKPACK))
    theme.Opacity(frame, sizeInfo.opacity)
  end
end
