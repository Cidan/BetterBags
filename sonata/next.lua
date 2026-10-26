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
-- The corners a pinned header button may name (Header.Buttons.Pinned): the body's, or by their side (mirrored
-- with the panel, as ornaments' are).
local CORNERS = { TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true, TOPINNER = true, TOPOUTER = true,
  BOTTOMINNER = true, BOTTOMOUTER = true }
-- The corners a bag button may name (Header.Buttons.Menu, next/menubutton.lua): by their side, as ornaments' corner
-- pieces.
local MENU_CORNERS = { TOPINNER = true, TOPOUTER = true, BOTTOMINNER = true, BOTTOMOUTER = true }
-- The styles a switch is drawn in (Controls.Toggle.Style, next/controls/toggle.lua).
local TOGGLE_STYLES = { Square = true, Round = true, Check = true }

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
  -- The player's Icon Scale (docs/next-appearance-size.md), kept across themes.
  nextStyle():SetIconScale(db():GetNextIconScale())
  self:use(self:GetSavedThemeKey())
end

-- itemSnap is BetterBags Next's rounding for Sonata's item button styler (SonataElements:SetItemButtonSnap):
-- whole screen pixels on a region's grid (NextPixel, docs/next-pixel-perfect.md).
local nextItemSnap
---@return SonataItemSnap
local function itemSnap()
  if nextItemSnap == nil then
    local pixel = addon:GetModule('NextPixel')
    nextItemSnap = {
      Offset = function(region, units) return pixel:Snap(region, units) end,
      Length = function(region, units) return pixel:Length(region, units) end,
      Unit = function(region) return pixel:Unit(region) end,
      Text = function(region) return pixel:TextOffset(region) end,
    }
  end
  return nextItemSnap
end

-- SetActive says whether BetterBags Next is the design in use (BagSystem:Use): only then does a Next
-- theme style the item buttons, and are their parts placed on whole screen pixels (Sonata's rounding,
-- NextItemFit). Before the classic bags take the buttons over, the parts Next placed go back.
---@param active boolean
function sonataNext:SetActive(active)
  self.active = active
  if not active then
    local fit = addon:GetModule('NextItemFit', true)
    if fit ~= nil then
      fit:RestoreAll()
    end
  end
  local elements = addon:GetModule('SonataElements', true)
  if elements ~= nil then
    elements:SetItemButtonSnap(active and itemSnap() or nil)
  end
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

-- The player's Animation switches (Appearance > Animation, next-themes.md §20): what each one turned off takes out of
-- the theme in use once it is resolved, as a theme without it leaves it out (resolution removes a table a theme sets to
-- false; Chain.Braid is a boolean). Asked: "we need a way to disable sparkles etc on any theme, not just switching to a
-- theme without them". An ornament stilled keeps its art.
local ANIMATION_OFF = {
  sparkles = function(theme) theme.Sparkles = nil end,
  shimmer = function(theme) theme.Header.Spark = nil end,
  titleCloud = function(theme) theme.Header.Cloud = nil end,
  ribbon = function(theme) theme.Header.Ribbon = nil end,
  braid = function(theme) theme.Chain.Braid = false end,
  ornaments = function(theme)
    for _, piece in ipairs(theme.Panel.Ornaments or {}) do
      piece.Motion = nil
    end
  end,
  -- The Glitch theme's (next-themes.md §21): its bags glitch in and out and now and then while they show; off, they
  -- slide in and out as any theme's. And its data rain.
  -- An ornament's glitch (a blinking twitch) is a glitch too: it goes, its other motion left to Moving Ornaments.
  glitch = function(theme)
    theme.Panel.Glitch = nil
    for _, piece in ipairs(theme.Panel.Ornaments or {}) do
      if piece.Motion then
        piece.Motion.Glitch = nil
      end
    end
  end,
  rain = function(theme) theme.Panel.Rain = nil end,
}

-- effective returns a theme as the player sees it: resolved (a new table), the Animation switches they turned off laid
-- over it. Resolve and Check keep a theme as it is written.
---@private
---@param key string
---@return NextTheme
function sonataNext:effective(key)
  local theme = self:Resolve(key)
  local saved = db()
  for name, off in pairs(ANIMATION_OFF) do
    if not saved:GetNextAnimation(name) then
      off(theme)
    end
  end
  return theme
end

-- use makes key the current theme and hands it to Next's style.
---@private
---@param key string
function sonataNext:use(key)
  self.resolved = self:effective(key)
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
  local resolved = self:effective(key)
  self.resolved = resolved
  self.current = key
  self.generation = self.generation + 1
  if save ~= false then
    db():SetNextTheme(key)
  end
  nextStyle():Use(resolved)
  self:syncItemButtons()
  self:RestyleWidgets(ctx)
  events():SendMessage(ctx, 'sonata/NextThemeChanged', key)
end

-- RestyleWidgets restyles every widget (its ApplyStyle) with the theme in effect, each in its own protected
-- call: a window drawn at a new scale lays everything out again for its pixel grid (the settings window,
-- docs/next-pixel-perfect.md). A widget gone before its turn (another one's restyle released it) is not
-- styled.
---@param ctx Context
function sonataNext:RestyleWidgets(ctx)
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

-- WatchClientFonts follows the client's fonts once the game has started (core/init.lua, after NextPixel):
-- every PLAYER_ENTERING_WORLD checks them (OnClientFontsChanged). Registered once however often it starts.
function sonataNext:WatchClientFonts()
  if self.watchingFonts then
    return
  end
  self.watchingFonts = true
  events():RegisterEvent("PLAYER_ENTERING_WORLD", function(ctx)
    self:OnClientFontsChanged(ctx)
  end)
end

-- OnClientFontsChanged applies the current theme again, unsaved, when a client font one of its roles copies is
-- no longer what it was copied from (NextStyle:CopiesStale): every role made again from the fonts as they are,
-- everything restyled, as a new pixel grid does (NextPixel). It returns whether it did, for profiler traces.
---@param ctx Context
---@return boolean
function sonataNext:OnClientFontsChanged(ctx)
  local key = self.started and self:GetCurrentThemeKey() or nil
  if key == nil or not nextStyle():CopiesStale() then
    return false
  end
  self:ApplyTheme(ctx, key, false)
  return true
end

-- ApplyAnimation lays the Animation switches over the current theme again (a switch changed: next/AnimationChanged)
-- and restyles every widget, as a theme applied does, keeping the font objects: the switches touch no font, and font
-- objects can never be freed (a theme applied on every click would leave a set behind each time). Nothing is saved
-- or announced. It returns whether it did, for profiler traces.
---@param ctx Context
---@return boolean
function sonataNext:ApplyAnimation(ctx)
  if not self.started then
    return false
  end
  self.resolved = self:effective(self.current)
  nextStyle():Use(self.resolved, true)
  self:RestyleWidgets(ctx)
  return true
end

-- WatchAnimation follows the player's Animation switches (core/init.lua, after WatchClientFonts): each one sends
-- next/AnimationChanged (config/catalog.lua). Registered once however often it starts.
function sonataNext:WatchAnimation()
  if self.watchingAnimation then
    return
  end
  self.watchingAnimation = true
  events():RegisterMessage('next/AnimationChanged', function(ctx)
    self:ApplyAnimation(ctx)
  end)
end

---@return string?
function sonataNext:GetCurrentThemeKey()
  return self.current
end

-- GetCurrentTheme returns the resolved current theme.
---@return NextTheme
function sonataNext:GetCurrentTheme()
  if self.resolved == nil then
    self.resolved = self:effective(self.current or self:GetSavedThemeKey())
  end
  return self.resolved
end

-- Keys whose value names a palette color (or gives one as { r, g, b, a }, or is a texture spec).
local COLOR_KEYS = {
  Color = true, Fill = true, SelectedFill = true, FocusFill = true, HoverColor = true, FocusColor = true,
  BeadColor = true, KnotColor = true, Unusable = true, SoldOut = true, SoldOutUnusable = true,
  ArtColor = true, ArtHoverColor = true, IconColor = true, DestroyColor = true, BuyColor = true,
}
-- The controls' fills and edges are texture specs whose Color is checked as any Color is.
-- Tables whose values name palette colors.
local COLOR_MAPS = { Washes = true, Accents = true, Colors = true }
-- Keys whose value names a text role (Fonts).
local FONT_KEYS = {
  Font = true, SelectedFont = true, TitleFont = true, RecentFont = true, FreeFont = true, CountFont = true,
  HelpFont = true, TextFont = true, EmptyFont = true, MoneyFont = true, HintFont = true, WarningFont = true,
  PriceFont = true, UnaffordableFont = true, StackFont = true, NameFont = true, HoverFont = true,
  DescriptionFont = true, NoteFont = true, LabelFont = true, LinkFont = true, GroupFont = true,
  ActiveFont = true, PreviewFont = true, UnavailableFont = true, DisabledFont = true,
  CappedFont = true, NoneFont = true, GainFont = true, LossFont = true, MoreFont = true, HeadFont = true,
}
-- Keys whose value names one of the theme's Textures, or is a file (a path or a file ID).
local TEXTURE_KEYS = { Texture = true, QualityBorder = true, QuestMark = true, Icon = true, HoverIcon = true }
-- The pieces of a nine-slice frame (Frame, next-themes.md §15): Blizzard's names (Blizzard_SharedXML/NineSlice.lua).
local FRAME_PIECES = {
  TopLeftCorner = true, TopRightCorner = true, BottomLeftCorner = true, BottomRightCorner = true, TopEdge = true,
  BottomEdge = true, LeftEdge = true, RightEdge = true, Center = true,
}
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
  -- A palette color naming one of the client's named colors (NextStyle: Color.lua makes each a global ColorMixin).
  for name, value in pairs(palette) do
    if type(value) == "table" and value.Global ~= nil then
      local color = _G[value.Global]
      if type(color) ~= "table" or color.GetRGBA == nil then
        table.insert(problems, "Palette." .. tostring(name) .. ".Global: no client color named " .. tostring(value.Global))
      end
    end
  end
  local function color(value, path)
    if type(value) == "string" and palette[value] == nil then
      table.insert(problems, path .. ": no color named " .. value)
    end
  end
  local walk
  -- A frame draws one of the client's layouts (NineSliceUtil, when the client has it) or its own pieces.
  local function frame(v, here)
    if v.Layout == nil and v.Pieces == nil then
      table.insert(problems, here .. ": a Layout or Pieces")
    end
    if v.Layout ~= nil and NineSliceUtil ~= nil and NineSliceUtil.GetLayout(v.Layout) == nil then
      table.insert(problems, here .. ".Layout: the client has no nine-slice layout named " .. tostring(v.Layout))
    end
    for name in pairs(type(v.Pieces) == "table" and v.Pieces or {}) do
      if not FRAME_PIECES[name] then
        table.insert(problems, here .. ".Pieces." .. tostring(name) .. ": no piece named " .. tostring(name))
      end
    end
  end
  local function check(k, v, here)
    if k == "Frame" and type(v) == "table" then
      frame(v, here)
      walk(v, here)
    elseif COLOR_MAPS[k] and type(v) == "table" then
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
  -- Ornaments (Panel.Ornaments, next-themes.md §12): their places, anchors, sizes and motions are NextOrnaments'.
  local ornaments = addon:GetModule('NextOrnaments', true)
  local list = theme.Panel and theme.Panel.Ornaments
  if ornaments ~= nil and type(list) == "table" then
    for i, o in ipairs(list) do
      local here = "Panel.Ornaments." .. i
      local function problem(field, text)
        table.insert(problems, here .. "." .. field .. ": " .. text)
      end
      if not ornaments.POINTS[o.Point] then
        problem("Point", "no place named " .. tostring(o.Point))
      elseif (o.Point == "INNER" or o.Point == "OUTER") and o.Width == nil then
        problem("Width", "a span along a side needs one")
      elseif (o.Point == "TOP" or o.Point == "BOTTOM") and o.Height == nil then
        problem("Height", "a span along an edge needs one")
      elseif ornaments.ANCHORS[o.Point] then
        if o.Width == nil then
          problem("Width", "a piece at a corner needs one")
        end
        if o.Height == nil then
          problem("Height", "a piece at a corner needs one")
        end
      end
      if o.Anchor ~= nil and not ornaments.ANCHORS[o.Anchor] then
        problem("Anchor", "no corner named " .. tostring(o.Anchor))
      end
      if o.Sizes ~= nil and not ornaments.SIZES[o.Sizes] then
        problem("Sizes", "no size named " .. tostring(o.Sizes))
      end
      if o.Texture == nil and o.Atlas == nil then
        problem("Texture", "a Texture or an Atlas")
      end
      if o.Atlas ~= nil and o.Tile ~= nil then
        problem("Atlas", "not with Tile")
      end
      if type(o.Mask) == "table" and o.Mask.Texture == nil then
        problem("Mask.Texture", "a mask needs one")
      end
      if o.TexCoords ~= nil then
        if type(o.TexCoords) ~= "table" or #o.TexCoords ~= 4 then
          problem("TexCoords", "four numbers, left, right, top and bottom")
        end
      end
      if o.Panels ~= nil then
        if type(o.Panels) ~= "table" then
          problem("Panels", "a list of panels")
        else
          for _, name in ipairs(o.Panels) do
            if ornaments.PANELS[name] == nil then
              problem("Panels", "no panel named " .. tostring(name))
            end
          end
        end
      end
      if type(o.Motion) == "table" then
        for k in pairs(o.Motion) do
          if not ornaments.MOTIONS[k] then
            problem("Motion." .. tostring(k), "no motion named " .. tostring(k))
          end
        end
        if o.Motion.Origin ~= nil and not ornaments.ORIGINS[o.Motion.Origin] then
          problem("Motion.Origin", "no point named " .. tostring(o.Motion.Origin))
        end
        for _, motion in ipairs({ "Glitch", "Scroll" }) do
          local spec = o.Motion[motion]
          if spec ~= nil and type(spec) ~= "table" then
            problem("Motion." .. motion, "a table")
          end
        end
        for k in pairs(type(o.Motion.Glitch) == "table" and o.Motion.Glitch or {}) do
          if not ornaments.GLITCH[k] then
            problem("Motion.Glitch." .. tostring(k), "no glitch part named " .. tostring(k))
          end
        end
        for k in pairs(type(o.Motion.Scroll) == "table" and o.Motion.Scroll or {}) do
          if k ~= "X" and k ~= "Y" then
            problem("Motion.Scroll." .. tostring(k), "X or Y")
          end
        end
      end
    end
  end
  -- A range: two numbers, none below 0, the least first.
  local function range(v)
    return type(v) == "table" and type(v[1]) == "number" and type(v[2]) == "number" and v[1] >= 0 and v[1] <= v[2]
  end
  -- A glitch (Panel.Glitch, next-themes.md §21): its parts are NextGlitch's; opening, closing and bursts need their time.
  local glitch = addon:GetModule('NextGlitch', true)
  local G = theme.Panel and theme.Panel.Glitch
  if glitch ~= nil and type(G) == "table" then
    local function problem(field, text)
      table.insert(problems, "Panel.Glitch." .. field .. ": " .. text)
    end
    for k in pairs(G) do
      if not glitch.KEYS[k] then
        problem(tostring(k), "no part named " .. tostring(k))
      end
    end
    local moments = false
    for _, part in ipairs({ { "Open", "a glitch opening needs one" }, { "Close", "a glitch closing needs one" },
      { "Bursts", "bursts need one" } }) do
      local spec = G[part[1]]
      if spec ~= nil then
        moments = true
        if type(spec) ~= "table" then
          problem(part[1], "a table")
        elseif type(spec.Time) ~= "number" then
          problem(part[1] .. ".Time", part[2])
        end
      end
    end
    if moments and not (type(G.Step) == "number" and G.Step > 0) then
      problem("Step", "a glitch needs one")
    end
    if type(G.Bursts) == "table" and not (type(G.Bursts.Every) == "number" and G.Bursts.Every > 0) then
      problem("Bursts.Every", "bursts need one")
    end
    if G.Flicker ~= nil and not range(G.Flicker) then
      problem("Flicker", "two numbers, dark and lit")
    end
    if type(G.Corrupt) == "table" and (type(G.Corrupt.Glyphs) ~= "string" or G.Corrupt.Glyphs == "") then
      problem("Corrupt.Glyphs", "some glyphs")
    end
  end
  -- A data rain (Panel.Rain, next-themes.md §21): each entry's parts are NextRain's, where it falls, its glyphs and its
  -- ranges.
  local rain = addon:GetModule('NextRain', true)
  local drops = theme.Panel and theme.Panel.Rain
  if rain ~= nil and type(drops) == "table" then
    for i, entry in ipairs(drops) do
      local function problem(field, text)
        table.insert(problems, "Panel.Rain." .. i .. "." .. field .. ": " .. text)
      end
      for k in pairs(entry) do
        if not rain.KEYS[k] then
          problem(tostring(k), "no part named " .. tostring(k))
        end
      end
      if not rain.WHERE[entry.Where] then
        problem("Where", "no place named " .. tostring(entry.Where))
      end
      if type(entry.Glyphs) ~= "string" or entry.Glyphs == "" then
        problem("Glyphs", "some glyphs")
      end
      for _, field in ipairs({ "Font", "HeadFont" }) do
        if entry[field] == nil then
          problem(field, "a text role")
        end
      end
      if entry.Spacing ~= nil and not (type(entry.Spacing) == "number" and entry.Spacing > 0) then
        problem("Spacing", "more than nothing")
      end
      if not range(entry.Speed) then
        problem("Speed", "two numbers, slowest and fastest")
      end
      if not range(entry.Trail) then
        problem("Trail", "two numbers, shortest and longest")
      end
    end
  end
  -- The side rail (Header.Buttons.Rail, next-themes.md §13): how wide, and where its buttons start.
  local toggle = theme.Controls and theme.Controls.Toggle
  if type(toggle) == "table" and not TOGGLE_STYLES[toggle.Style] then
    table.insert(problems, "Controls.Toggle.Style: no style named " .. tostring(toggle.Style))
  end
  local buttons = theme.Header and theme.Header.Buttons
  for name, pin in pairs(type(buttons) == "table" and type(buttons.Pinned) == "table" and buttons.Pinned or {}) do
    if not CORNERS[pin.Point] then
      table.insert(problems, "Header.Buttons.Pinned." .. tostring(name) .. ".Point: no corner named " .. tostring(pin.Point))
    end
  end
  local rail = buttons and buttons.Rail
  if type(rail) == "table" then
    for _, field in ipairs({ "Width", "Top" }) do
      if type(rail[field]) ~= "number" then
        table.insert(problems, "Header.Buttons.Rail." .. field .. ": a side rail needs one")
      end
    end
  end
  -- A bag button holding the header's row (Header.Buttons.Menu, next-themes.md §19): a corner of the body by its side,
  -- its size, art in each layer (a file, an atlas, a unit's portrait, a color), the panels it names.
  local menu = buttons and buttons.Menu
  if type(menu) == "table" then
    local where = "Header.Buttons.Menu."
    for _, field in ipairs({ "Point", "Anchor" }) do
      if (field == "Point" or menu[field] ~= nil) and not MENU_CORNERS[menu[field]] then
        table.insert(problems, where .. field .. ": no corner named " .. tostring(menu[field]))
      end
    end
    for _, field in ipairs({ "Width", "Height" }) do
      if type(menu[field]) ~= "number" then
        table.insert(problems, where .. field .. ": a bag button needs one")
      end
    end
    local function layers(path, given)
      for i, layer in ipairs(type(given) == "table" and given or {}) do
        if layer.Texture == nil and layer.Atlas == nil and layer.Unit == nil and layer.Color == nil then
          table.insert(problems, path .. "Layers[" .. i .. "]: draws nothing")
        end
      end
    end
    layers(where, menu.Layers)
    for name, own in pairs(type(menu.Panels) == "table" and menu.Panels or {}) do
      if ornaments ~= nil and ornaments.PANELS[name] == nil then
        table.insert(problems, where .. "Panels." .. tostring(name) .. ": no panel named " .. tostring(name))
      elseif type(own) == "table" then
        layers(where .. "Panels." .. tostring(name) .. ".", own.Layers)
      end
    end
  end
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
