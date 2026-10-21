local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SonataResolve: AceModule
local resolve = addon:GetModule('SonataResolve')

-- The saved choice lives in the Database module, read when a theme is applied or Next starts.
---@return Database
local function db()
  return addon:GetModule('Database')
end

---@return Events
local function events()
  return addon:GetModule('Events')
end

---@return Context
local function context()
  return addon:GetModule('Context')
end

-- Next's style reads the resolved theme (next/style.lua); it loads after this file.
---@return NextStyle
local function nextStyle()
  return addon:GetModule('NextStyle')
end

-- SonataNext is Sonata for BetterBags Next (.claude/rules/next-themes.md): the same engine as the
-- classic bags' themes (inheritance, per-client overrides, variables: SonataResolve) with its own
-- registry and saved choice. Asked: "same mechanism (apply with a declarative spec, no functions!)".
-- A Next theme is data only: a function, an object or userdata anywhere in it is refused when it
-- registers, and a theme that needs another addon says so by name (Requires) instead of with a
-- function. Every theme inherits what it does not set from Default, the current design, which is
-- complete. Applying a theme hands it to Next's style (NextStyle:Use: values, and new font objects)
-- and restyles every registered widget (its ApplyStyle).
---@class SonataNext: AceModule
---@field themes table<string, NextTheme>
---@field private current? string
---@field private resolved? NextTheme
---@field private started boolean Init has run: the saved choice can be read.
---@field private active boolean BetterBags Next is the design in use (SetActive).
---@field private itemButtonStyle? table The item button style it gave Sonata (syncItemButtons).
---@field private generation number
---@field private widgets table<table, boolean>
local sonataNext = addon:NewModule('SonataNext')

-- Themes register as their files load, before Init runs. Widgets register as Next's panels are made.
sonataNext.themes = {}
sonataNext.widgets = setmetatable({}, { __mode = "k" })
sonataNext.generation = 0

-- The theme every Next theme inherits from, and the one used while the saved one cannot be.
local BASE = "Default"

---@class NextTheme
---@field Name string The key the theme is saved and registered under.
---@field DisplayName? string
---@field Description? string
---@field Parent? string The theme this one inherits from (Default when unset).
---@field Hidden? boolean
---@field Requires? string[] Addons that must be loaded for the theme to be picked.
---@field Variables? table<string, any>
---@field ItemButton? table Item buttons while Next is in use: a Sonata ItemButton element style (sonata.md 3a).
---@field Clients? table<string, table> Partial themes applied on a client (Retail, Forever, Classic, ...).

-- Init starts Next with the saved theme (Default while it cannot be used), before Next's panels are
-- made (core/init.lua).
function sonataNext:Init()
  self.widgets = setmetatable({}, { __mode = "k" })
  self.current = nil
  self.resolved = nil
  self.generation = 0
  self.started = true
  self.active = false
  self.itemButtonStyle = nil
  self:use(self:GetSavedThemeKey())
end

-- SetActive says whether BetterBags Next is the design in use (BagSystem:Use): only then does a Next
-- theme style the item buttons.
---@param active boolean
function sonataNext:SetActive(active)
  self.active = active
  self:syncItemButtons()
end

-- syncItemButtons gives Sonata the current theme's item button style (ItemButton) while Next is in
-- use, in place of the bags' theme's, or takes it away; the buttons then draw in full again. Item
-- buttons are shared by both designs and styled by Sonata's ItemButton element (sonata.md 3a).
---@private
function sonataNext:syncItemButtons()
  local style = self.active and self.resolved and self.resolved.ItemButton or nil
  if style == nil and self.itemButtonStyle == nil then
    return
  end
  self.itemButtonStyle = style
  addon:GetModule('Sonata'):SetElementStyleOverride("ItemButton", style)
  local itemFrame = addon:GetModule('ItemFrame', true)
  if itemFrame ~= nil then
    itemFrame:RestyleButtons()
  end
end

-- checkData errors when value holds anything but data: a function, an object (a table with a
-- metatable, a frame) or userdata, naming where.
---@param value any
---@param path string
local function checkData(value, path)
  local kind = type(value)
  if kind == "function" or kind == "userdata" or kind == "thread" then
    error("Next themes are data: " .. path .. " is a " .. kind, 0)
  end
  if kind == "table" then
    if resolve.IsObject(value) then
      error("Next themes are data: " .. path .. " is an object", 0)
    end
    for k, v in pairs(value) do
      checkData(v, path .. "." .. tostring(k))
    end
  end
end

---@param theme NextTheme
function sonataNext:RegisterTheme(theme)
  if type(theme) ~= "table" or type(theme.Name) ~= "string" or theme.Name == "" then
    error("a Next theme needs a Name")
  end
  if self.themes[theme.Name] ~= nil then
    error("a Next theme named " .. theme.Name .. " has already been registered")
  end
  checkData(theme, theme.Name)
  if theme.Requires ~= nil then
    if type(theme.Requires) ~= "table" then
      error("Next theme " .. theme.Name .. ": Requires is a list of addon names")
    end
    for _, name in pairs(theme.Requires) do
      if type(name) ~= "string" then
        error("Next theme " .. theme.Name .. ": Requires is a list of addon names")
      end
    end
  end
  resolve:CheckClients(theme)
  self.themes[theme.Name] = theme
  -- A theme from another addon registers when that addon loads, after Next started with Default in
  -- place of the saved theme; the saved theme is applied as soon as it can be.
  if self.started and self.current ~= theme.Name and db():GetNextTheme() == theme.Name
    and self:IsSelectable(theme.Name) then
    self:ApplyTheme(context():New('SonataNext_LateTheme'), theme.Name, false)
  end
end

---@param key string
---@return NextTheme?
function sonataNext:GetTheme(key)
  return self.themes[key]
end

-- IsAvailable says a theme is registered and every addon it requires is loaded.
---@param key string
---@return boolean
function sonataNext:IsAvailable(key)
  local theme = self.themes[key]
  if theme == nil then
    return false
  end
  for _, name in ipairs(theme.Requires or {}) do
    local _, loaded = C_AddOns.IsAddOnLoaded(name)
    if not loaded then
      return false
    end
  end
  return true
end

---@param key string
---@return boolean
function sonataNext:IsSelectable(key)
  local theme = self.themes[key]
  return theme ~= nil and theme.Hidden ~= true and self:IsAvailable(key)
end

-- GetThemes returns every theme that is not hidden, available or not.
---@return table<string, NextTheme>
function sonataNext:GetThemes()
  local list = {}
  for key, theme in pairs(self.themes) do
    if theme.Hidden ~= true then
      list[key] = theme
    end
  end
  return list
end

-- GetAllThemes returns every theme a player can pick now.
---@return table<string, NextTheme>
function sonataNext:GetAllThemes()
  local list = {}
  for key, theme in pairs(self.themes) do
    if self:IsSelectable(key) then
      list[key] = theme
    end
  end
  return list
end

-- Resolve returns the complete theme: a new table, safe to keep.
---@param key string
---@return NextTheme
function sonataNext:Resolve(key)
  return resolve:Resolve(self.themes, key, BASE)
end

-- GetSavedThemeKey returns the theme the saved setting puts in effect: the saved theme, or Default
-- while it is missing, hidden or unavailable (the saved choice is kept, so a theme whose addon is
-- off for one session comes back with it).
---@return string
function sonataNext:GetSavedThemeKey()
  local key = db():GetNextTheme()
  if self:IsSelectable(key) then
    return key
  end
  return BASE
end

-- use makes key the current theme and hands it to Next's style.
---@private
---@param key string
function sonataNext:use(key)
  self.resolved = self:Resolve(key)
  self.current = key
  nextStyle():Use(self.resolved)
end

-- RegisterWidget adds a widget restyled (its ApplyStyle(ctx)) whenever a theme is applied. Widgets
-- are held weakly.
---@param widget {ApplyStyle: fun(self, ctx: Context)}
function sonataNext:RegisterWidget(widget)
  self.widgets[widget] = true
end

---@param widget table
function sonataNext:UnregisterWidget(widget)
  self.widgets[widget] = nil
end

-- ApplyTheme makes a theme the current one, saves it (unless save is false: a preview), hands it to
-- Next's style, restyles every registered widget (one failing does not stop the others), and sends
-- sonata/NextThemeChanged.
---@param ctx Context
---@param key string
---@param save? boolean
function sonataNext:ApplyTheme(ctx, key, save)
  local theme = self.themes[key]
  if theme == nil then
    error("attempted to apply a Next theme that is not registered: " .. tostring(key))
  end
  if theme.Hidden == true then
    error("attempted to apply a hidden Next theme: " .. tostring(key))
  end
  if not self:IsAvailable(key) then
    error("attempted to apply a Next theme that is not available: " .. tostring(key))
  end
  local resolved = self:Resolve(key)
  self.resolved = resolved
  self.current = key
  self.generation = self.generation + 1
  if save ~= false then
    db():SetNextTheme(key)
  end
  nextStyle():Use(resolved)
  self:syncItemButtons()
  local list = {}
  for widget in pairs(self.widgets) do
    table.insert(list, widget)
  end
  for _, widget in ipairs(list) do
    if self.widgets[widget] then
      local ok, err = pcall(widget.ApplyStyle, widget, ctx)
      if not ok then
        geterrorhandler()(err)
      end
    end
  end
  events():SendMessage(ctx, 'sonata/NextThemeChanged', key)
end

-- RestoreSavedTheme applies the theme the saved setting puts in effect, without saving, when
-- another one is applied (a preview from the theme pane).
---@param ctx Context
function sonataNext:RestoreSavedTheme(ctx)
  local key = self:GetSavedThemeKey()
  if self.current ~= key then
    self:ApplyTheme(ctx, key, false)
  end
end

---@return string?
function sonataNext:GetCurrentThemeKey()
  return self.current
end

-- GetCurrentTheme returns the resolved current theme.
---@return NextTheme
function sonataNext:GetCurrentTheme()
  if self.resolved == nil then
    self.resolved = self:Resolve(self.current or self:GetSavedThemeKey())
  end
  return self.resolved
end

-- Keys whose value names a palette color (or gives one as { r, g, b, a }, or is a texture spec).
local COLOR_KEYS = {
  Color = true, Fill = true, SelectedFill = true, FocusFill = true, HoverColor = true, FocusColor = true,
  BeadColor = true, KnotColor = true, Unusable = true, SoldOut = true, SoldOutUnusable = true,
  ArtColor = true, ArtHoverColor = true,
}
-- The controls' fills and edges are texture specs whose Color is checked as any Color is.
-- Tables whose values name palette colors.
local COLOR_MAPS = { Washes = true, Accents = true, Colors = true }
-- Keys whose value names a text role (Fonts).
local FONT_KEYS = {
  Font = true, SelectedFont = true, TitleFont = true, RecentFont = true, FreeFont = true, CountFont = true,
  HelpFont = true, TextFont = true, EmptyFont = true, MoneyFont = true, HintFont = true, WarningFont = true,
  PriceFont = true, UnaffordableFont = true, StackFont = true, NameFont = true, HoverFont = true,
}
-- Keys whose value names one of the theme's Textures, or is a file (a path or a file ID).
local TEXTURE_KEYS = { Texture = true, QualityBorder = true, QuestMark = true }
-- Parts that are not Next's widgets' specs: checked elsewhere or not at all.
local UNCHECKED = { Palette = true, Variables = true, Textures = true, ItemButton = true }

-- Check returns what a theme names but does not define, each as "path: problem": a palette color, a
-- text role, a texture, an ease. Empty for a theme with nothing wrong. For theme authors and specs.
---@param key string
---@return string[]
function sonataNext:Check(key)
  local theme = self:Resolve(key)
  local problems = {}
  local palette, fonts, textures = theme.Palette or {}, theme.Fonts or {}, theme.Textures or {}
  local function color(value, path)
    if type(value) == "string" and palette[value] == nil then
      table.insert(problems, path .. ": no color named " .. value)
    end
  end
  local walk
  local function check(k, v, here)
    if COLOR_MAPS[k] and type(v) == "table" then
      for name, value in pairs(v) do
        color(value, here .. "." .. tostring(name))
      end
    elseif COLOR_KEYS[k] and type(v) ~= "table" then
      color(v, here)
    elseif FONT_KEYS[k] and type(v) == "string" and fonts[v] == nil then
      table.insert(problems, here .. ": no font named " .. v)
    elseif TEXTURE_KEYS[k] and type(v) == "string" and textures[v] == nil and not v:find("[\\/]") then
      table.insert(problems, here .. ": no texture named " .. v)
    elseif type(v) == "table" then
      walk(v, here)
    end
  end
  walk = function(node, path)
    for k, v in pairs(node) do
      if not (path == "" and UNCHECKED[k]) then
        check(k, v, path == "" and tostring(k) or (path .. "." .. tostring(k)))
      end
    end
  end
  walk(theme, "")
  local tween = addon:GetModule('NextTween', true)
  local motion = theme.Motion
  if tween ~= nil and motion ~= nil and motion.Ease ~= nil then
    for name, ease in pairs(motion.Ease) do
      if tween.Ease[ease] == nil then
        table.insert(problems, "Motion.Ease." .. name .. ": no ease named " .. tostring(ease))
      end
    end
  end
  return problems
end

-- GetGeneration changes every time a theme is applied.
---@return number
function sonataNext:GetGeneration()
  return self.generation
end
