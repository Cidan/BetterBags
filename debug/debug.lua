


local addon = GetBetterBags()

local context = addon:GetContext()

---@class Debug: AceModule
---@field window DebugWindow
---@field enabled boolean
---@field profiles table<string, number>
---@field tooltip GameTooltip
---@field StartProfile fun(self: Debug, name: string, ...)
---@field EndProfile fun(self: Debug, name: string, ...)
---@field Switch fun(self: Debug, label: string, enabled: boolean)
---@field IncrementCounter fun(self: Debug, counter: string, amount: number)
---@field DecrementCounter fun(self: Debug, counter: string, amount: number)
---@field SetCounter fun(self: Debug, counter: string, amount: number)
local debug = addon:NewModule('Debug')

function debug:OnInitialize()
  self.profiles = {}
  self.enabled = false
  self.tooltip = CreateFrame('GameTooltip', 'BetterBagsTooltip', UIParent, 'GameTooltipTemplate') --[[@as GameTooltip]]
end

function debug:OnEnable()
  ---@class DebugWindow: AceModule
  self.window = addon:GetModule('DebugWindow')
  local ctx = context:New('DebugWindowEnable')
  self.window:Create(ctx)

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
  local ctx = context:New('DebugLog')
  self.window:AddLogLine(ctx, category, debug:Format(...))
end

---@param category string
---@param ctx Context
function debug:LogContext(category, ctx)
  if not self.enabled then return end
  if ctx == nil then
    error("context is nil")
  end
  self:Log(category, ctx:Get('event'))
  local eventList = ctx:Get('events') --[[@as table<number, string>]]
  for k, v in ipairs(eventList) do
    self:Log(category, k, v)
  end
end

---@param tag string
---@param value any
---@param nocopy? boolean
function debug:Inspect(tag, value, nocopy)
  if self.enabled and _G.DevTool then
    -- DevTool does a JIT expansion of values when inspecting
    -- a value in the UI. This is a problem because the state
    -- of the value may change between the time it is inspected
    -- and the time it is viewed. To avoid this, we make a deep copy
    -- of the value if it is a table.
    if type(value) == "table"  and not nocopy then
      _G.DevTool:AddData(CopyTable(value), tag)
    else
      _G.DevTool:AddData(value, tag)
    end
  end
end
