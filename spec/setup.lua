-- Mock basic World of Warcraft globals required by Ace3 and other libraries
_G.GetTime = function() return os.clock() end
_G.CreateFrame = function(frameType, name, parent, template)
  local frame = {
    SetScript = function() end,
    Show = function() end,
    Hide = function() end,
    RegisterEvent = function() end,
    UnregisterEvent = function() end,
  }
  if name then
    _G[name] = frame
  end
  return frame
end
_G.hooksecurefunc = function() end
_G.UIParent = {}
_G.C_Timer = {
  After = function(delay, callback) end
}
_G.IsLoggedIn = function() return true end
_G.SlashCmdList = {}
_G.hash_SlashCmdList = {}
_G.GetLocale = function() return "enUS" end
_G.GetBuildInfo = function() return "10.0.0", "12345", "Jan 1 2024", 100000 end
_G.GetRealmName = function() return "TestRealm" end
_G.UnitName = function() return "TestChar", "TestRealm" end
_G.UnitClass = function() return "Warrior", "WARRIOR" end
_G.UnitFactionGroup = function() return "Alliance", "Alliance" end
_G.UnitRace = function() return "Human", "Human" end
_G.GetCurrentRegion = function() return 1 end
_G.GetCurrentRegionName = function() return "US" end

if not _G.unpack and _G.table and _G.table.unpack then
  _G.unpack = _G.table.unpack
end

if not _G.loadstring and _G.load then
  _G.loadstring = _G.load
end

-- String functions
_G.strmatch = string.match
_G.strsub = string.sub
_G.strlen = string.len
_G.strfind = string.find
_G.strlower = string.lower
_G.strupper = string.upper
_G.strbyte = string.byte
_G.strchar = string.char
_G.strrep = string.rep
_G.strjoin = function(sep, ...) return table.concat({...}, sep) end

_G.strsplit = function(sep, str)
  if str == nil then return end
  local t = {}
  local start = 1
  local splitStart, splitEnd = string.find(str, sep, start, true)
  while splitStart do
    table.insert(t, string.sub(str, start, splitStart - 1))
    start = splitEnd + 1
    splitStart, splitEnd = string.find(str, sep, start, true)
  end
  table.insert(t, string.sub(str, start))
  return unpack(t)
end

-- Table functions
_G.tinsert = table.insert
_G.tremove = table.remove
_G.tconcat = table.concat
_G.wipe = function(t)
  for k in pairs(t) do
    t[k] = nil
  end
  return t
end

-- Load LibStub
dofile("libs/LibStub/LibStub.lua")

-- Load CallbackHandler
-- Note: It requires Ace3 environment to load, but CallbackHandler itself doesn't need much.
dofile("libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")

-- Load AceAddon-3.0
dofile("libs/AceAddon-3.0/AceAddon-3.0.lua")

-- Load AceEvent-3.0
dofile("libs/AceEvent-3.0/AceEvent-3.0.lua")

-- Load AceDB-3.0
dofile("libs/AceDB-3.0/AceDB-3.0.lua")

-- Load AceHook-3.0
dofile("libs/AceHook-3.0/AceHook-3.0.lua")

-- Load AceConsole-3.0
dofile("libs/AceConsole-3.0/AceConsole-3.0.lua")

-- Load AceDBOptions-3.0
dofile("libs/AceDBOptions-3.0/AceDBOptions-3.0.lua")

-- Load AceConfig-3.0 (Skip AceConfigDialog as it requires AceGUI)
dofile("libs/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua")
dofile("libs/AceConfig-3.0/AceConfigCmd-3.0/AceConfigCmd-3.0.lua")
dofile("libs/AceConfig-3.0/AceConfig-3.0.lua")
