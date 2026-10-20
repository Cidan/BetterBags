local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- The saved theme lives in the Database module, read when a theme is applied or first looked
-- up (never per draw).
---@return Database
local function db()
  return addon:GetModule('Database')
end

-- Messages go out only when a theme is applied.
---@return Events
local function events()
  return addon:GetModule('Events')
end

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class SonataResolve: AceModule
local resolve = addon:GetModule('SonataResolve')

-- Sonata is BetterBags' theme engine (from Moonlight's Sonata). A theme is data: a table of
-- window styles and element styles, with no code. A theme inherits every value it does not
-- set from its Parent (Base when it names none), each level's per-client overrides apply
-- on top of that level, and "$Name" strings take the value of the theme's Variables. The
-- engine applies the resolved theme to every registered window (through the window
-- decorator) and every registered element (through the styler of its kind).
---@class Sonata: AceModule
---@field themes table<string, SonataTheme>
---@field private windows {window: table, kind: string}[]
---@field private windowIndex table<table, string> The kind of every registered window.
---@field private decorations table<table, any> What the decorator returned for each window.
---@field private elements table<string, table<table, boolean>>
---@field private elementStylers table<string, fun(element: table, style: table, theme: SonataTheme)>
---@field private windowDecorator? fun(window: table, style: table, theme: SonataTheme)
---@field private current? string
---@field private resolved? SonataTheme
---@field private resolvedKey? string
---@field private applied boolean
---@field private generation number
---@field private textFonts table<string, Font> This theme's font object of every text role asked for.
---@field private texts table<FontString|EditBox, string> The text role of every text drawn with one.
---@field private buttonTexts table<Button, string> The text role of every button's text drawn with one.
local sonata = addon:NewModule('Sonata')

-- Themes register as their files load, before Init runs.
sonata.themes = {}

---@class SonataTheme
---@field Name string The key the theme is saved and registered under.
---@field DisplayName? string The name shown in the theme pickers.
---@field Description? string
---@field Parent? string The theme this one inherits from (Base when unset).
---@field Hidden? boolean Not listed and never applied (Base).
---@field Available? boolean|fun(): boolean
---@field Masque? boolean false: item buttons are not handed to Masque.
---@field Variables? table<string, any|fun(): any>
---@field Windows? table<string, table> Window styles by window kind (Bag, Panel, Flat, Dialog, Slots, Search).
---@field Elements? table<string, table> Element styles by element kind.
---@field Text? table<string, SonataFont> Text roles: the fonts of BetterBags' own text in windows and on the bag.
---@field Clients? table<string, SonataTheme> Partial themes applied on a client (Retail, Forever, Classic, Era, TBC, Mists, Anniversary, Cata).

-- The style handed out for a window or element kind a theme does not style.
local EMPTY = setmetatable({}, { __newindex = function() error("Sonata styles are read-only") end })

function sonata:Init()
  self.windows = {}
  self.windowIndex = {}
  self.decorations = setmetatable({}, { __mode = "k" })
  self.elements = {}
  self.elementStylers = self.elementStylers or {}
  self.textFonts = {}
  self.texts = setmetatable({}, { __mode = "k" })
  self.buttonTexts = setmetatable({}, { __mode = "k" })
  self.textWatchers = setmetatable({}, { __mode = "k" })
  -- The client rescales its fonts (the Text Size setting) after VARIABLES_LOADED and whenever
  -- the setting changes; role fonts are copies of them, so new ones are made. One callback per
  -- owner and event: registering again replaces it.
  EventRegistry:RegisterCallback("TextSizeManager.OnTextScaleUpdated", function()
    self:newTextFonts()
  end, self)
  self.current = nil
  self.resolved = nil
  self.resolvedKey = nil
  self.applied = false
  self.generation = 0
end

---@param theme SonataTheme
function sonata:RegisterTheme(theme)
  if type(theme) ~= "table" or type(theme.Name) ~= "string" or theme.Name == "" then
    error("a theme needs a Name")
  end
  if self.themes[theme.Name] ~= nil then
    error("a theme named " .. theme.Name .. " has already been registered")
  end
  resolve:CheckClients(theme)
  self.themes[theme.Name] = theme
  -- A theme from another addon registers when that addon loads, after Sonata applied Default
  -- in place of the saved theme; the saved theme is applied as soon as it can be.
  if self.applied and self.current ~= theme.Name and db():GetTheme() == theme.Name and self:IsSelectable(theme.Name) then
    self:ApplyTheme(context:New('Sonata_LateTheme'), theme.Name, false)
  end
end

-- RegisterNextTheme registers a theme for BetterBags Next's panels, the other registration path
-- (SonataNext, sonata/next.lua): data only, inheriting from Next's Default.
---@param theme NextTheme
function sonata:RegisterNextTheme(theme)
  addon:GetModule('SonataNext'):RegisterTheme(theme)
end

---@param key string
---@return SonataTheme?
function sonata:GetTheme(key)
  return self.themes[key]
end

---@param key string
---@return boolean
function sonata:IsAvailable(key)
  local theme = self.themes[key]
  if theme == nil then
    return false
  end
  if type(theme.Available) == "function" then
    return theme.Available() == true
  end
  return theme.Available ~= false
end

---@param key string
---@return boolean
function sonata:IsSelectable(key)
  local theme = self.themes[key]
  return theme ~= nil and theme.Hidden ~= true and self:IsAvailable(key)
end

-- GetThemes returns every theme that is not hidden, whether its addon is loaded or not (the
-- theme picker lists unavailable themes as such).
---@return table<string, SonataTheme>
function sonata:GetThemes()
  local list = {}
  for key, theme in pairs(self.themes) do
    if theme.Hidden ~= true then
      list[key] = theme
    end
  end
  return list
end

-- GetAllThemes returns every theme a player can pick.
---@return table<string, SonataTheme>
function sonata:GetAllThemes()
  local list = {}
  for key, theme in pairs(self.themes) do
    if self:IsSelectable(key) then
      list[key] = theme
    end
  end
  return list
end

-- GetClientKeys returns the client override keys for this client, general first.
---@return string[]
function sonata:GetClientKeys()
  return resolve:ClientKeys()
end

---@param key string
---@return SonataTheme[] chain The theme first, Base last.
function sonata:chainOf(key)
  return resolve:Chain(self.themes, key, "Base")
end

-- Resolve returns the complete style of a theme: a new table, safe to keep.
---@param key string
---@return SonataTheme
function sonata:Resolve(key)
  local resolved = resolve:Resolve(self.themes, key, "Base")
  resolved.Windows = resolved.Windows or {}
  resolved.Elements = resolved.Elements or {}
  resolved.Text = resolved.Text or {}
  return resolved
end

-- SetWindowDecorator sets the function that applies a window style to a window.
---@param fn fun(window: table, style: table, theme: SonataTheme)
function sonata:SetWindowDecorator(fn)
  self.windowDecorator = fn
  if self.applied and fn ~= nil then
    self:Redecorate()
  end
end

-- SetElementStyler sets the function that applies an element style to elements of a kind.
---@param kind string
---@param fn fun(element: table, style: table, theme: SonataTheme)
function sonata:SetElementStyler(kind, fn)
  self.elementStylers = self.elementStylers or {}
  self.elementStylers[kind] = fn
  if self.applied and fn ~= nil then
    self:restyleKind(kind)
  end
end

---@private
---@param window table
---@param kind string
function sonata:decorate(window, kind)
  if self.windowDecorator == nil then
    return
  end
  local theme = self:GetCurrentTheme()
  local ok, result = pcall(self.windowDecorator, window, theme.Windows[kind] or EMPTY, theme)
  if ok then
    self.decorations[window] = result
  else
    geterrorhandler()(result)
  end
end

---@private
---@param kind string
function sonata:restyleKind(kind)
  local set = self.elements[kind]
  if set == nil then
    return
  end
  local list = {}
  for element in pairs(set) do
    table.insert(list, element)
  end
  for _, element in ipairs(list) do
    if set[element] then
      self:style(kind, element)
    end
  end
end

---@private
---@param kind string
---@param element table
function sonata:style(kind, element)
  local styler = self.elementStylers[kind]
  if styler == nil then
    return
  end
  local theme = self:GetCurrentTheme()
  local ok, err = pcall(styler, element, theme.Elements[kind] or EMPTY, theme)
  if not ok then
    geterrorhandler()(err)
  end
end

-- RegisterWindow adds a window to be decorated with the style of its kind. A window that
-- registers after a theme was applied is decorated at once.
---@param window table
---@param kind string Bag, Panel, Flat, Dialog, Slots or Search.
function sonata:RegisterWindow(window, kind)
  if self.windowIndex[window] ~= nil then
    error("a window was registered with Sonata twice")
  end
  table.insert(self.windows, { window = window, kind = kind })
  self.windowIndex[window] = kind
  if self.applied then
    self:decorate(window, kind)
  end
end

-- UpdateOpacity tells every registered window that has an opacity (UpdateOpacity) to apply
-- it again, after an opacity setting changed.
function sonata:UpdateOpacity()
  for _, entry in ipairs(self.windows) do
    if entry.window.UpdateOpacity ~= nil then
      entry.window:UpdateOpacity()
    end
  end
end

---@param window table
function sonata:UnregisterWindow(window)
  if self.windowIndex[window] == nil then
    return
  end
  for i, entry in ipairs(self.windows) do
    if entry.window == window then
      table.remove(self.windows, i)
      break
    end
  end
  self.windowIndex[window] = nil
  self.decorations[window] = nil
end

-- Redecorate decorates window again with the current theme, or every window when window is
-- nil, without saving the theme, changing the generation or redrawing the bags: for a
-- window whose own state the decoration reads changed (its opacity, its title).
---@param window? table
function sonata:Redecorate(window)
  if not self.applied then
    return
  end
  if window ~= nil then
    local kind = self.windowIndex[window]
    if kind ~= nil then
      self:decorate(window, kind)
    end
    return
  end
  local list = {}
  for i, entry in ipairs(self.windows) do
    list[i] = entry
  end
  for _, entry in ipairs(list) do
    if self.windowIndex[entry.window] ~= nil then
      self:decorate(entry.window, entry.kind)
    end
  end
end

-- GetDecoration returns what the window decorator returned for window.
---@param window table
---@return any
function sonata:GetDecoration(window)
  return self.decorations[window]
end

-- RegisterElement adds an element to be styled with the style of its kind. Elements are
-- held weakly: a discarded element needs no unregistering.
---@param kind string
---@param element table
function sonata:RegisterElement(kind, element)
  if self.elements[kind] == nil then
    self.elements[kind] = setmetatable({}, { __mode = "k" })
  end
  if self.elements[kind][element] then
    return
  end
  self.elements[kind][element] = true
  if self.applied then
    self:style(kind, element)
  end
end

---@param kind string
---@param element table
function sonata:UnregisterElement(kind, element)
  if self.elements[kind] ~= nil then
    self.elements[kind][element] = nil
  end
end

-- ApplyTheme makes a theme the active one, saves it (unless save is false), and applies it
-- to every registered window and element. The bags redraw (a theme changes how they look,
-- not what they hold). Windows and elements registered while it applies are styled once, as
-- they register.
---@param ctx Context
---@param key string
---@param save? boolean
function sonata:ApplyTheme(ctx, key, save)
  local theme = self.themes[key]
  if theme == nil then
    error("attempted to apply a theme that is not registered: " .. tostring(key))
  end
  if theme.Hidden == true then
    error("attempted to apply a hidden theme: " .. tostring(key))
  end
  if not self:IsAvailable(key) then
    error("attempted to apply a theme that is not available: " .. tostring(key))
  end
  self.resolved = self:Resolve(key)
  self.resolvedKey = key
  self.current = key
  self.applied = true
  self.generation = self.generation + 1
  if save ~= false then
    db():SetTheme(key)
  end

  self:newTextFonts()
  local snapshot = {}
  for kind, set in pairs(self.elements) do
    local list = {}
    for element in pairs(set) do
      table.insert(list, element)
    end
    snapshot[kind] = list
  end
  self:Redecorate()
  for kind, list in pairs(snapshot) do
    local set = self.elements[kind]
    for _, element in ipairs(list) do
      if set[element] then
        self:style(kind, element)
      end
    end
  end

  events():SendMessage(ctx, 'sonata/ThemeChanged', key)
  events():SendMessage(ctx, 'bags/Redraw')
end

-- OnEnable applies the saved theme. A saved theme that is missing or unavailable this
-- session (its addon is not loaded) is replaced by Default without changing the saved
-- choice, so it comes back once its addon does.
function sonata:OnEnable()
  local key = db():GetTheme()
  if self:IsSelectable(key) then
    self:ApplyTheme(context:New('Sonata_OnEnable'), key)
  else
    self:ApplyTheme(context:New('Sonata_OnEnable'), 'Default', false)
  end
end

---@return string?
function sonata:GetCurrentThemeKey()
  return self.current
end

-- GetSavedThemeKey returns the theme the saved setting puts in effect: the saved theme, or
-- Default while it is missing, hidden or unavailable.
---@return string
function sonata:GetSavedThemeKey()
  local key = db():GetTheme()
  if self:IsSelectable(key) then
    return key
  end
  return 'Default'
end

-- RestoreSavedTheme applies the theme the saved setting puts in effect, without saving, when
-- another one is applied (a preview from the theme pane).
---@param ctx Context
function sonata:RestoreSavedTheme(ctx)
  if not self.applied then
    return
  end
  local key = self:GetSavedThemeKey()
  if self.current ~= key then
    self:ApplyTheme(ctx, key, false)
  end
end

-- GetCurrentTheme returns the resolved active theme. Before a theme was applied it is the
-- saved one, or Default when that is missing or unavailable.
---@return SonataTheme
function sonata:GetCurrentTheme()
  local key = self.current
  if key == nil then
    key = db():GetTheme()
    if not self:IsSelectable(key) then
      key = 'Default'
    end
  end
  if self.resolved == nil or self.resolvedKey ~= key then
    self.resolved = self:Resolve(key)
    self.resolvedKey = key
  end
  return self.resolved
end

-- GetWindowStyle returns the current theme's style for a window kind. Styles are shared and
-- read-only.
---@param kind string
---@return table
function sonata:GetWindowStyle(kind)
  return self:GetCurrentTheme().Windows[kind] or EMPTY
end

-- GetElementStyle returns the current theme's style for an element kind. Styles are shared
-- and read-only.
---@param kind string
---@return table
function sonata:GetElementStyle(kind)
  return self:GetCurrentTheme().Elements[kind] or EMPTY
end

-- GetGeneration changes every time a theme is applied: anything that records what it drew
-- with a theme compares it to know it must draw again.
---@return number
function sonata:GetGeneration()
  return self.generation
end

---@return boolean
function sonata:UsesMasque()
  return self:GetCurrentTheme().Masque ~= false
end

-- Text roles. BetterBags' own text (settings, dialogs, editors, the debug window, the bag's
-- footer and hints) is drawn with one font object per role of the theme's Text table, made
-- when first asked for. A font object is styled once, when it is made, and never changed:
-- a font object changed while text used it left that text out of step once the text switched
-- to another font object (hovering a settings entry changed its size). So every theme
-- application, and every rescale of the client's fonts, makes a new font object per role, and
-- Sonata moves each text and button drawn with a role to it. Such text must not set its own
-- color or shadow, which would override its font object.

-- The number of role font objects made: their names must be unique.
local textFontCount = 0

-- styleTextFont makes font a copy of its role's client font, then applies what the role sets.
-- A copy, never a font that inherits from it (Font:SetFontObject): Blizzard makes its own
-- runtime font objects by copying (FontableFrameMixin).
---@param font Font
---@param spec SonataFont
local function styleTextFont(font, spec)
  local apply = addon:GetModule('SonataApply')
  local rest = {}
  for key, value in pairs(spec) do
    if key ~= "Object" then
      rest[key] = value
    end
  end
  if spec.Object ~= nil then
    font:CopyFontObject(apply:FontObject(spec.Object))
  end
  apply:Font(font, rest)
end

-- GetTextFont returns the current theme's font object for a role, made the first time it is
-- asked for.
---@param role string
---@return Font
function sonata:GetTextFont(role)
  local font = self.textFonts[role]
  if font == nil then
    local spec = self:GetCurrentTheme().Text[role]
    if spec == nil then
      error("unknown text role: " .. tostring(role))
    end
    textFontCount = textFontCount + 1
    font = CreateFont("BetterBagsText" .. role .. textFontCount)
    styleTextFont(font, spec)
    self.textFonts[role] = font
  end
  return font
end

-- CreateText makes a font string drawn with a text role.
---@param parent Frame
---@param role string
---@param layer? DrawLayer The default is OVERLAY.
---@return FontString
function sonata:CreateText(parent, role, layer)
  local text = parent:CreateFontString(nil, layer or "OVERLAY")
  self:SetTextRole(text, role)
  return text
end

-- SetTextRole draws a font string or edit box with a text role.
---@param text FontString|EditBox
---@param role string
function sonata:SetTextRole(text, role)
  text:SetFontObject(self:GetTextFont(role))
  self.texts[text] = role
  self:fontChanged(text)
end

-- WatchTextFont calls fn(text) after every change of text's font object: a role switch, a
-- theme's new font objects, the client rescaling its fonts. For text sized to its content: a
-- button's font string keeps the width it had when the button's text was set
-- (QuestLogTitleButton_Resize, Blizzard_UIPanels_Game QuestLogFrame.lua), so its owner refits it.
---@param text FontString
---@param fn fun(text: FontString)
function sonata:WatchTextFont(text, fn)
  self.textWatchers[text] = fn
end

-- fontChanged runs the text's watcher, telling a running render recorder about the change, the
-- refit, and the refit text a frame later: a SetWidth is applied on the next update tick
-- (render-recorder.md).
---@private
---@param text FontString|EditBox
function sonata:fontChanged(text)
  local recorder = addon:GetModule('RenderRecorder', true)
  local recording = recorder ~= nil and recorder.recording
  if recording then
    recorder:TextChanged(text, self.texts[text], "font")
  end
  local watcher = self.textWatchers[text]
  if watcher ~= nil then
    watcher(text)
    if recording then
      local role = self.texts[text]
      recorder:TextChanged(text, role, "refit")
      C_Timer.After(0, function()
        recorder:TextChanged(text, role, "next frame")
      end)
    end
  end
end

-- SetButtonTextRole draws a button's text with a text role (its normal font object).
---@param button Button
---@param role string
function sonata:SetButtonTextRole(button, role)
  button:SetNormalFontObject(self:GetTextFont(role))
  self.buttonTexts[button] = role
end

-- newTextFonts starts a new set of role font objects for the current theme and moves every
-- text and button drawn with a role to its role's new font object. Text whose role the theme
-- does not define keeps its font object.
---@private
function sonata:newTextFonts()
  self.textFonts = {}
  if next(self.texts) == nil and next(self.buttonTexts) == nil then
    return
  end
  local roles = self:GetCurrentTheme().Text
  for text, role in pairs(self.texts) do
    if roles[role] ~= nil then
      text:SetFontObject(self:GetTextFont(role))
      self:fontChanged(text)
    end
  end
  for button, role in pairs(self.buttonTexts) do
    if roles[role] ~= nil then
      button:SetNormalFontObject(self:GetTextFont(role))
    end
  end
end
