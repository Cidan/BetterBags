-- wow_mocks.lua -- Mock basic World of Warcraft globals required by Ace3 and addon modules.
-- This file is loaded by spec/setup.lua before any libraries or addon code.

-- Core game functions
_G.GetTime = function() return os.clock() end
_G.CreateFrame = function(_, name, _, _)
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
  After = function(_, _) end,
  NewTimer = function(_, _)
    return { Cancel = function() end }
  end,
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

-- Error handling and secure call wrappers
_G.geterrorhandler = function()
  return function(err) return err end
end
_G.securecallfunction = function(fn, ...)
  return pcall(fn, ...)
end
_G.securecall = _G.securecallfunction

-- Table utilities
_G.CopyTable = function(t)
  if type(t) ~= "table" then return t end
  local copy = {}
  for k, v in pairs(t) do
    if type(v) == "table" then
      copy[k] = _G.CopyTable(v)
    else
      copy[k] = v
    end
  end
  return copy
end

-- Combat and gameplay state
_G.InCombatLockdown = function() return false end
_G.GetFramerate = function() return 60 end

-- String utilities (WoW-specific)
_G.format = string.format
_G.strtrim = function(str)
  if not str then return "" end
  return str:match("^%s*(.-)%s*$")
end

-- Item info stubs
_G.C_Item = _G.C_Item or {}
if not _G.C_Item.GetItemInfoInstant then
  _G.C_Item.GetItemInfoInstant = function(id) return id end
end
_G.C_Item.IsBound = _G.C_Item.IsBound or function() return false end

-- New item tracking
_G.C_NewItems = _G.C_NewItems or {
  IsNewItem = function() return false end,
  RemoveNewItem = function() end,
  ClearAll = function() end,
}

-- Time function
_G.time = _G.time or os.time

-- string.split (WoW alias for strsplit, available as string method)
string.split = string.split or function(sep, str)
  return strsplit(sep, str)
end

-- strsplittable: like strsplit but returns a table
_G.strsplittable = function(sep, str, max)
  return {strsplit(sep, str, max)}
end

-- Lua 5.1/5.3 compatibility shims
if not _G.unpack and _G.table and _G.table.unpack then
  _G.unpack = _G.table.unpack
end

if not _G.loadstring and _G.load then
  _G.loadstring = _G.load
end

-- String functions (WoW global aliases for string library)
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

_G.strsplit = function(sep, str, max)
  if str == nil then return end
  local t = {}
  local start = 1
  local splitStart, splitEnd = string.find(str, sep, start, true)
  while splitStart do
    if max and #t >= max - 1 then break end
    table.insert(t, string.sub(str, start, splitStart - 1))
    start = splitEnd + 1
    splitStart, splitEnd = string.find(str, sep, start, true)
  end
  table.insert(t, string.sub(str, start))
  return unpack(t)
end

-- Table functions (WoW global aliases for table library)
_G.tinsert = table.insert
_G.tremove = table.remove
_G.tconcat = table.concat
_G.wipe = function(t)
  for k in pairs(t) do
    t[k] = nil
  end
  return t
end
