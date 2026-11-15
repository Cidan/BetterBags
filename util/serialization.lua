local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Serialization: AceModule
local serialization = addon:NewModule('Serialization')

-- parseLegacy reads the Lua table constructor the "!BB" exporter wrote (serializeTable, before #1317), and nothing else:
-- tables of `[key] = value,` fields, keys and values that are strings as string.format("%q") writes them, numbers as
-- tostring writes them, true, false, and nil. It is read as data and never run. Raises an error for anything else.
---@param text string
---@return table
local function parseLegacy(text)
  local pos = 1

  local function fail(what)
    error(string.format("%s at byte %d", what, pos), 0)
  end

  local function skipSpace()
    pos = text:find("[^%s]", pos) or #text + 1
  end

  local function readString()
    local parts = {}
    pos = pos + 1
    while true do
      local at = text:find('["\\]', pos)
      if not at then
        fail("unfinished string")
      end
      table.insert(parts, text:sub(pos, at - 1))
      if text:sub(at, at) == '"' then
        pos = at + 1
        return table.concat(parts)
      end
      local escaped = text:sub(at + 1, at + 1)
      if escaped == '"' or escaped == "\\" or escaped == "\n" then
        table.insert(parts, escaped)
        pos = at + 2
      elseif escaped == "r" then
        table.insert(parts, "\r")
        pos = at + 2
      else
        local digits = text:match("^%d%d?%d?", at + 1)
        if not digits then
          pos = at
          fail("unknown escape")
        end
        table.insert(parts, string.char(tonumber(digits)))
        pos = at + 1 + #digits
      end
    end
  end

  local function readNumber()
    local token = text:match("^%-?%d+%.?%d*[eE][%+%-]?%d+", pos) or text:match("^%-?%d+%.?%d*", pos)
    if not token then
      fail("unexpected text")
    end
    pos = pos + #token
    return tonumber(token)
  end

  -- A literal: a string, a number, true, false or nil.
  local function readLiteral()
    local c = text:sub(pos, pos)
    if c == '"' then
      return readString()
    elseif text:find("^true", pos) then
      pos = pos + 4
      return true
    elseif text:find("^false", pos) then
      pos = pos + 5
      return false
    elseif text:find("^nil", pos) then
      pos = pos + 3
      return nil
    end
    return readNumber()
  end

  local readTable

  local function readValue()
    if text:sub(pos, pos) == "{" then
      return readTable()
    end
    return readLiteral()
  end

  readTable = function()
    local result = {}
    pos = pos + 1
    while true do
      skipSpace()
      if text:sub(pos, pos) == "}" then
        pos = pos + 1
        return result
      end
      if text:sub(pos, pos) ~= "[" then
        fail("expected a [key]")
      end
      pos = pos + 1
      skipSpace()
      local key = readLiteral()
      skipSpace()
      if text:sub(pos, pos) ~= "]" then
        fail("expected ]")
      end
      pos = pos + 1
      skipSpace()
      if text:sub(pos, pos) ~= "=" then
        fail("expected =")
      end
      pos = pos + 1
      skipSpace()
      result[key] = readValue()
      skipSpace()
      local c = text:sub(pos, pos)
      if c == "," then
        pos = pos + 1
      elseif c ~= "}" then
        fail("expected , or }")
      end
    end
  end

  skipSpace()
  if text:sub(pos, pos) ~= "{" then
    fail("expected a table")
  end
  local result = readTable()
  skipSpace()
  if pos <= #text then
    fail("text after the table")
  end
  return result
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

-- base64Only keeps the characters Base64 is written with. The "!BB" reader skipped every other one, so a string saved
-- with a period after it, or pasted with a no-break or zero-width space, read; both formats still do.
---@param text string
---@return string
local function base64Only(text)
  return (text:gsub("[^A-Za-z0-9%+/=]", ""))
end

-- Encode writes a table as text a player can share: CBOR, compressed with Deflate, in Base64 (C_EncodingUtil, on every
-- client BetterBags ships for).
---@param value table
---@return string
function serialization:Encode(value)
  local cbor = C_EncodingUtil.SerializeCBOR(value)
  local compressed = C_EncodingUtil.CompressString(cbor, Enum.CompressionMethod.Deflate,
    Enum.CompressionLevel.OptimizeForSize)
  return C_EncodingUtil.EncodeBase64(compressed)
end

-- Decode reads what Encode wrote. The text is pasted by a player, so anything may be in it: CBOR only ever reads as
-- data, and text that is not Base64, not compressed, not CBOR or not a table is refused (C_EncodingUtil raises an error
-- on some bad data and returns nothing on other).
---@param text string
---@return table|nil, string?
function serialization:Decode(text)
  local decodedOK, decoded = pcall(C_EncodingUtil.DecodeBase64, base64Only(text))
  if not decodedOK or not decoded then
    return nil, "it is not Base64"
  end
  local inflatedOK, inflated = pcall(C_EncodingUtil.DecompressString, decoded, Enum.CompressionMethod.Deflate)
  if not inflatedOK or not inflated then
    return nil, "it is not compressed data"
  end
  local valueOK, value = pcall(C_EncodingUtil.DeserializeCBOR, inflated)
  if not valueOK or type(value) ~= "table" then
    return nil, "it does not hold a table"
  end
  return value
end

-- DecodeLegacy reads a string exported before #1317: the Base64 after "!BB", of a Lua table constructor. It is parsed,
-- never run (it used to be handed to loadstring, so a pasted string could run any code). What the parser cannot read
-- comes back as the reason, tables nested too deep for Lua's stack included.
---@param text string
---@return table|nil, string?
function serialization:DecodeLegacy(text)
  local decodedOK, decoded = pcall(C_EncodingUtil.DecodeBase64, base64Only(text))
  if not decodedOK or not decoded then
    return nil, "it is not Base64"
  end
  local parsedOK, value = pcall(parseLegacy, decoded)
  if not parsedOK then
    return nil, value
  end
  return value
end

---@param orig table
---@return table
function serialization:DeepCopy(orig)
  return deepCopy(orig)
end
