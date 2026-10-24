-- Loads another addon's Next themes (BetterBags - Themes by default) into the SonataNext a spec uses, the way that
-- addon's TOC loads them, and makes FreshNextThemes (spec/helpers/addon_loader.lua) register them along with
-- BetterBags' own: a check of a theme addon against BetterBags' engine (README.md). The addon's folder is
-- BETTERBAGS_THEMES, else ../BetterBags-Themes beside this repository.
local THEMES_REPO = os.getenv("BETTERBAGS_THEMES") or "../BetterBags-Themes"
if THEMES_REPO:sub(-1) ~= "/" then
  THEMES_REPO = THEMES_REPO .. "/"
end
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local M = { REPO = THEMES_REPO, ART_PREFIX = "Interface\\AddOns\\BetterBags-Themes\\" }

-- The theme files in TOC order: themes/Shared.lua, then every themes/next/ file.
function M.Files()
  local files = {}
  local toc = io.open(THEMES_REPO .. "BetterBags-Themes.toc")
  assert(toc ~= nil, "no BetterBags-Themes.toc in " .. THEMES_REPO .. " (set BETTERBAGS_THEMES to the addon's folder)")
  toc:close()
  for line in io.lines(THEMES_REPO .. "BetterBags-Themes.toc") do
    if line == "themes/Shared.lua" or line:match("^themes/next/.+%.lua$") then
      table.insert(files, line)
    end
  end
  return files
end

function M.Load()
  local sonata = addon:GetModule("Sonata", true) or addon:NewModule("Sonata")
  -- A spec's stand-in Sonata forwards Next themes as BetterBags' does (sonata/engine.lua).
  if sonata.RegisterNextTheme == nil then
    function sonata:RegisterNextTheme(theme) addon:GetModule("SonataNext"):RegisterTheme(theme) end
  end
  local ns = {}
  local keys = {}
  local before = {}
  for key in pairs(addon:GetModule("SonataNext").themes) do before[key] = true end
  for _, file in ipairs(M.Files()) do
    local chunk = assert(loadfile(THEMES_REPO .. file))
    chunk("BetterBags-Themes", ns)
  end
  for key in pairs(addon:GetModule("SonataNext").themes) do
    if not before[key] then table.insert(keys, key) end
  end
  table.sort(keys)
  return keys
end

function M.Install()
  local fresh = _G.FreshNextThemes
  _G.FreshNextThemes = function()
    local s = fresh()
    M.Load()
    return s
  end
  return _G.FreshNextThemes()
end

-- RunSpec runs one of BetterBags' spec files in this file's environment, with the themes registered.
function M.RunSpec(path, env)
  M.Install()
  local chunk = assert(loadfile(path))
  setfenv(chunk, env)
  chunk()
end

return M
