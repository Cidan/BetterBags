-- addon_loader.lua -- Creates the BetterBags addon and provides helpers for loading modules in tests.
-- This file must be loaded AFTER Ace3 libraries are available (LibStub, AceAddon, etc.).

-- Create the BetterBags addon, mimicking core/boot.lua
local addon = LibStub("AceAddon-3.0"):NewAddon("BetterBags", 'AceHook-3.0')
addon:SetDefaultModuleState(false)

-- Keybinding globals that boot.lua sets
_G.BINDING_NAME_BETTERBAGS_TOGGLESEARCH = "Search Bags"
_G.BINDING_NAME_BETTERBAGS_TOGGLEBAGS = "Toggle Bags"

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
--- Returns the existing module if it was already created.
---@param name string Module name (e.g. "Database", "Constants")
---@return table module The stub module table
_G.StubBetterBagsModule = function(name)
  local ok, mod = pcall(function() return addon:GetModule(name) end)
  if ok and mod then return mod end
  return addon:NewModule(name)
end
