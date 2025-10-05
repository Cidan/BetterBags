local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Serialization: AceModule
local serialization = addon:NewModule('Serialization')

-- Base64 encoding/decoding characters
local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- Serialize a Lua table to a string
---@param tbl table
---@param indent? number
---@return string
local function serializeTable(tbl, indent)
  indent = indent or 0
  local result = {}
  local indentStr = string.rep("  ", indent)

  table.insert(result, "{\n")

  for k, v in pairs(tbl) do
    local key
    if type(k) == "number" then
      key = string.format("[%d]", k)
    elseif type(k) == "string" then
      key = string.format("[%q]", k)
    else
      key = "[" .. tostring(k) .. "]"
    end

    table.insert(result, indentStr .. "  " .. key .. " = ")

    if type(v) == "table" then
      table.insert(result, serializeTable(v, indent + 1))
    elseif type(v) == "string" then
      table.insert(result, string.format("%q", v))
    elseif type(v) == "number" or type(v) == "boolean" then
      table.insert(result, tostring(v))
    else
      table.insert(result, "nil")
    end

    table.insert(result, ",\n")
  end

  table.insert(result, indentStr .. "}")
  return table.concat(result)
end

-- Deserialize a string back to a Lua table
---@param str string
---@return table|nil, string?
local function deserializeTable(str)
  local func, err = loadstring("return " .. str)
  if not func then
    return nil, err
  end

  local success, result = pcall(func)
  if not success then
    return nil, result
  end

  return result
end

-- Encode a string to Base64
---@param data string
---@return string
local function encodeBase64(data)
  return ((data:gsub('.', function(x)
    local r, b = '', x:byte()
    for i = 8, 1, -1 do
      r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0')
    end
    return r
  end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
    if (#x < 6) then return '' end
    local c = 0
    for i = 1, 6 do
      c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0)
    end
    return b64chars:sub(c + 1, c + 1)
  end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

-- Decode a Base64 string
---@param data string
---@return string|nil
local function decodeBase64(data)
  data = string.gsub(data, '[^'..b64chars..'=]', '')
  return (data:gsub('.', function(x)
    if (x == '=') then return '' end
    local r, f = '', (b64chars:find(x) - 1)
    for i = 6, 1, -1 do
      r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0')
    end
    return r
  end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
    if (#x ~= 8) then return '' end
    local c = 0
    for i = 1, 8 do
      c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0)
    end
    return string.char(c)
  end))
end

-- Deep copy a table
---@param orig table
---@return table
local function deepCopy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[deepCopy(orig_key)] = deepCopy(orig_value)
    end
    setmetatable(copy, deepCopy(getmetatable(orig)))
  else
    copy = orig
  end
  return copy
end

-- Export public functions
---@param tbl table
---@return string
function serialization:Serialize(tbl)
  return serializeTable(tbl)
end

---@param str string
---@return table|nil, string?
function serialization:Deserialize(str)
  return deserializeTable(str)
end

---@param data string
---@return string
function serialization:EncodeBase64(data)
  return encodeBase64(data)
end

---@param data string
---@return string|nil
function serialization:DecodeBase64(data)
  return decodeBase64(data)
end

---@param orig table
---@return table
function serialization:DeepCopy(orig)
  return deepCopy(orig)
end
