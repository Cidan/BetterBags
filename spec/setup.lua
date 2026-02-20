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
