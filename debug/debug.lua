local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Debug: AceModule
---@field window DebugWindow
---@field enabled boolean
---@field profiles table<string, number>
---@field tooltip GameTooltip
local debug = addon:NewModule('Debug')

function debug:OnInitialize()
  self.profiles = {}
  self.enabled = false
  self.tooltip = CreateFrame('GameTooltip', 'BetterBagsTooltip', UIParent, 'GameTooltipTemplate') --[[@as GameTooltip]]
end

function debug:OnEnable()
  ---@class DebugWindow: AceModule
  self.window = addon:GetModule('DebugWindow')
  self.window:Create()

  ---@class Events: AceModule
  local events = addon:GetModule('Events')
  events:RegisterMessage('config/DebugMode', function(_, enabled)
    self.enabled = enabled
  end)

  ---@class Database: AceModule
  local database = addon:GetModule('Database')
  self.enabled = database:GetDebugMode()
  if self.enabled then
    print("BetterBags: debug mode enabled")
  end
end

debug.colors = {
	["nil"]      = "aaaaaa",
	["boolean"]  = "77aaff",
	["number"]   = "ff77ff",
	["table"]    = "44ffaa",
	["UIObject"] = "ffaa44",
	["function"] = "77ffff",
}

function debug:GetType(value)
  local t = type(value)
  if t == "table" and type(value[0]) == "userdata" then
    return "UIObject"
  end
  return t
end

function debug:UnsafeGetTableName(value)
	return
		(type(value.GetName) == "function" and value:GetName())
		or (type(value.ToString) == "function" and value:ToString())
		or value.name
end

function debug:GetRawTableName(t)
	local mt = getmetatable(t)
	setmetatable(t, nil)
	local name = tostring(t)
	setmetatable(t, mt)
	return name
end

function debug:GetTableName(value)
  if type(value) ~= "table" then
    return tostring(value)
  end
  local ok, name = pcall(debug.UnsafeGetTableName, debug, value) ---@type boolean, string
  if ok then
    return name
  end
  return debug:GetRawTableName(value)
end

function debug:GetTableLink(value)
  if type(value) ~= "table" then
    return tostring(value)
  end
  local name, valueType = tostring(debug:GetTableName(value)), debug:GetType(value)
  return format("|cff%s|HBetterBags%s:%s|h[%s]|h|r", debug.colors[valueType], valueType, name, name)
end

function debug:Clean(value)
  local valueType = debug:GetType(value)
  local str ---@type string
  if valueType == "table" or valueType == "UIObject" then
    return debug:GetTableLink(value)
  else
    str = tostring(value)
  end
  local color = debug.colors[valueType]
  return color and strjoin('', '|cff', color, str, '|r') or str
end

function debug:Format(...)
  local n = select('#', ...)
  if n == 0 then
    return
  elseif n == 1 then
    return debug:Clean(...)
  end
  ---@type table<number, string>
  local tempFormat = {}
  for i = 1, n do
    local v = select(i, ...)
    tempFormat[i] = type(v) == "string" and v or debug:Clean(v)
  end
  return table.concat(tempFormat, " ", 1, n)
end

function debug:Log(category, ...)
  if not self.enabled then return end
  self.window:AddLogLine(category, debug:Format(...))
end
debug:Enable()
