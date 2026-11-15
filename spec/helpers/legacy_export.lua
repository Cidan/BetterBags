-- legacy_export.lua -- The "!BB" strings BetterBags exported before #1317: a Lua table constructor (serializeTable),
-- in Base64, as util/serialization.lua wrote them. Kept here, unchanged, so specs can make the strings players still
-- hold and check that they import. Returns function(tbl) -> "!BB" .. Base64.

local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

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

return function(tbl)
  return "!BB" .. encodeBase64(serializeTable(tbl))
end
