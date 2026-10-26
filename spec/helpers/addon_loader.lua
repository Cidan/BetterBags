-- addon_loader.lua -- Creates the BetterBags addon and provides helpers for loading modules in tests.
-- This file must be loaded AFTER Ace3 libraries are available (LibStub, AceAddon, etc.).

-- Create the BetterBags addon, mimicking core/boot.lua
local addon = LibStub("AceAddon-3.0"):NewAddon("BetterBags", 'AceHook-3.0')
addon:SetDefaultModuleState(false)

-- Keybinding globals that boot.lua sets
_G.BINDING_NAME_BETTERBAGS_TOGGLESEARCH = "Search Bags"
_G.BINDING_NAME_BETTERBAGS_TOGGLEBAGS = "Toggle Bags"
_G.BINDING_NAME_BETTERBAGS_DESTROYNEXT = "Destroy Next Item"

-- Track which module files have been loaded to prevent double-registration
local loadedModules = {}

--- Load a BetterBags module file, passing "BetterBags" as the vararg (addon name).
--- Uses loadfile() so the module's `local addonName = ...` receives the correct value.
--- Each path is loaded at most once to prevent AceAddon duplicate module errors.
---@param path string File path relative to the repository root (e.g. "util/query.lua")
_G.LoadBetterBagsModule = function(path)
  if loadedModules[path] then return end
  local fn, err = loadfile(path)
  if not fn then
    error("Failed to load module: " .. path .. "\n" .. tostring(err))
  end
  fn("BetterBags")
  loadedModules[path] = true
end

--- Create a stub module on the BetterBags addon. Useful for satisfying GetModule()
--- dependencies without loading the real module file.
--- Returns the existing module if it was already created, plus a flag telling the
--- caller whether a brand new stub was registered (so it can ResetModuleStub it during
--- teardown without clobbering a real module registered by another spec).
---@param name string Module name (e.g. "Database", "Constants")
---@return table module The stub module table
---@return boolean created True when this call registered a new stub module
_G.StubBetterBagsModule = function(name)
  local ok, mod = pcall(function() return addon:GetModule(name) end)
  if ok and mod then return mod, false end
  local stub = addon:NewModule(name)
  if name == "Database" then
    stub.GetUpgradeIconProvider = stub.GetUpgradeIconProvider or function() return "None" end
  end
  return stub, true
end

--- Clear a previously-stubbed module so the real module file can be loaded safely.
--- Only clears if the module exists and the real file hasn't been loaded yet.
---@param name string Module name (e.g. "Database")
---@param filePath string File path that would load the real module (e.g. "core/database.lua")
_G.ResetModuleStub = function(name, filePath)
  if addon.modules[name] then
    addon.modules[name] = nil
  end
  -- AceAddon registers modules as sub-addons via NewAddon with name "ParentName_ModuleName"
  local subAddonName = "BetterBags_" .. name
  local aceAddon = LibStub("AceAddon-3.0")
  if aceAddon.addons[subAddonName] then
    aceAddon.addons[subAddonName] = nil
  end
  if filePath ~= nil then
    loadedModules[filePath] = nil
  end
  if name == "Items" then
    loadedModules["data/slots.lua"] = nil
  end
  if name == "Trees" then
    loadedModules["util/trees/intervaltree.lua"] = nil
  end
end

--- Load a brand new copy of a real module, replacing whatever is registered under that
--- name. Use it when a spec needs the real behavior of a shared module (Events, Context)
--- that earlier spec files may have stubbed or patched without restoring.
---@param name string Module name (e.g. "Events")
---@param filePath string File that defines it (e.g. "core/events.lua")
---@return table module
_G.LoadFreshBetterBagsModule = function(name, filePath)
  _G.ResetModuleStub(name, filePath)
  _G.LoadBetterBagsModule(filePath)
  return addon:GetModule(name)
end

--- FreshNextThemes loads a new SonataNext (sonata/next.lua) with BetterBags Next's own themes
-- registered (sonata/themes/next/*.lua, Default first), replacing one another spec file changed or
-- removed, and returns it. spec/setup.lua loads one for every spec: next/style.lua reads the Default
-- theme when it loads. A spec that changes SonataNext's themes calls it again in its teardown.
---@return table sonataNext
_G.FreshNextThemes = function()
  _G.ResetModuleStub("SonataNext", "sonata/next.lua")
  _G.LoadBetterBagsModule("sonata/next.lua")
  local files = {}
  local list = io.popen("ls sonata/themes/next/*.lua")
  for file in list:lines() do
    table.insert(files, file)
  end
  list:close()
  table.sort(files, function(a, b)
    local da, db = a:match("/default%.lua$") ~= nil, b:match("/default%.lua$") ~= nil
    if da ~= db then
      return da
    end
    return a < b
  end)
  for _, file in ipairs(files) do
    loadedModules[file] = nil
    _G.LoadBetterBagsModule(file)
  end
  return addon:GetModule("SonataNext")
end

-- UseNextTheme makes BetterBags Next draw with a theme for a spec: theme (a Next theme table, named
-- "Spec" here, inheriting from Default) registered in SonataNext, replacing the last one, and handed
-- to NextStyle; nil goes back to Default. Returns the resolved theme. Widgets restyle with their own
-- ApplyStyle.
---@param theme? table
---@return table
_G.UseNextTheme = function(theme)
  local sonataNext = addon:GetModule("SonataNext")
  sonataNext.themes.Spec = nil
  local key = "Default"
  if theme ~= nil then
    theme.Name = "Spec"
    sonataNext:RegisterTheme(theme)
    key = "Spec"
  end
  local style = addon:GetModule("NextStyle")
  style:Use(sonataNext:Resolve(key))
  return style.Theme
end

-- UseNextCurrencies readies BetterBags Next's currencies (.claude/rules/currency.md) for a spec that builds the
-- backpack, whose footer holds them: the spec's Database answers the currency settings (nothing tracked, every option
-- its default, the tracker put away), installed with the spec's own override so they are put back after each test,
-- and the Currencies module starts fresh. Call it where the spec sets up each test (before_each), after it loaded
-- data/currencies.lua.
---@param database table
---@param override fun(tbl: table, key: string, value: any)
_G.UseNextCurrencies = function(database, override)
  local tracked, tracker = {}, { out = false }
  local options = { capBars = false, gains = true, hideEmpty = true, itemsEverywhere = true, layout = "row",
    scale = 100, background = true, hideInCombat = false, growX = "left", growY = "down" }
  override(database, "GetNextCurrencies", function()
    local out = {}
    for _, e in ipairs(tracked) do table.insert(out, { kind = e.kind, id = e.id }) end
    return out
  end)
  override(database, "SetNextCurrencies", function(_, list)
    tracked = {}
    for _, e in ipairs(list) do table.insert(tracked, { kind = e.kind, id = e.id }) end
  end)
  override(database, "GetNextCurrencyOption", function(_, name) return options[name] end)
  override(database, "SetNextCurrencyOption", function(_, name, value) options[name] = value end)
  override(database, "GetNextCurrencyTracker", function() return tracker.out, tracker.x, tracker.y end)
  override(database, "SetNextCurrencyTracker", function(_, out, x, y)
    tracker.out = out
    if x ~= nil then tracker.x, tracker.y = x, y end
  end)
  addon:GetModule("Currencies"):Init()
end

-- NextIconName names what a BetterBags Next header button draws: its icon's file name without its
-- folder or extension ("sort" for ...\\icons\\sort.png), or its atlas.
---@param button table
---@return string?
_G.NextIconName = function(button)
  local icon = button.icon
  local atlas = icon:GetAtlas()
  if atlas ~= nil then
    return atlas
  end
  local path = icon:GetTexture()
  return type(path) == "string" and (path:match("([^\\/]+)%.png$") or path) or path
end

-- Make Sonata's text roles usable in a spec whose code draws text with them
--- (Sonata:CreateText, SetTextRole, GetTextFont): loads the engine and SonataApply when they
--- are not loaded, registers the real Base theme (replacing a stand-in Base without text
--- roles, which other specs register) and Default when Sonata has none, forgets its resolved
--- theme and role font objects (and the applied theme when it is no longer registered), and
--- returns Sonata. Roles are styled from the applied theme, else the saved one
--- (Database:GetTheme): the spec's Database must answer GetTheme. Call it where the spec sets
--- up each test (before_each) as well, since other spec files change Sonata's themes.
---@return table sonata
_G.UseSonataTextRoles = function()
  _G.LoadBetterBagsModule("sonata/engine.lua")
  _G.LoadBetterBagsModule("sonata/apply.lua")
  local sonata = addon:GetModule("Sonata")
  sonata.textFonts = sonata.textFonts or {}
  local base = sonata.themes.Base
  if base ~= nil and base.Text == nil then
    sonata.themes.Base = nil
  end
  for key, file in pairs({ Base = "sonata/themes/base.lua", Default = "sonata/themes/default.lua" }) do
    if sonata.themes[key] == nil then
      assert(loadfile(file))("BetterBags")
    end
  end
  if sonata.current ~= nil and sonata.themes[sonata.current] == nil then
    sonata.current = nil
  end
  sonata.resolved, sonata.resolvedKey = nil, nil
  sonata.textFonts = {}
  sonata.texts = sonata.texts or setmetatable({}, { __mode = "k" })
  sonata.buttonTexts = sonata.buttonTexts or setmetatable({}, { __mode = "k" })
  sonata.textWatchers = sonata.textWatchers or setmetatable({}, { __mode = "k" })
  return sonata
end
