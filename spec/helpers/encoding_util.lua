-- encoding_util.lua -- C_EncodingUtil and its enums (EncodingUtilDocumentation.lua, the same on every client branch:
-- live, classic, classic_era, classic_anniversary, classic_titan, forever). spec/helpers/world.lua loads it after
-- wow_mocks.lua. What the documentation and warcraft.wiki.gg (API:C_EncodingUtil.*) say, the mock does:
--
-- SerializeCBOR(value, options) -> string: RFC 8949. Strings are byte strings (major type 2), never text strings. A
--   table is an array (major type 4) when it can be wholly one (keys 1..n, nothing else), else a map (major type 5), any
--   key type. No tags, no indefinite lengths. Integers in the fewest bytes; other numbers as doubles (the client may
--   write a shorter float that holds the same value: a reader cannot tell). A function, thread or userdata raises an
--   error, unless options.ignoreSerializationErrors, which writes 'undefined' in its place. A table inside itself raises
--   an error, and so does nesting deeper than 100 (Constants.EncodingLimits.EncodingStackSizeLimit).
-- DeserializeCBOR(source) -> value: reads text strings as byte strings; raises an error on tags, indefinite lengths,
--   nesting deeper than 100 and data it cannot read (the wiki does not say whether bad data raises or returns nil;
--   callers handle both).
-- CompressString(source, method, level) -> string, DecompressString(source, method) -> string: Deflate (RFC 1951),
--   the default method. The mock writes stored blocks (Deflate's uncompressed blocks, which every inflater reads) and
--   reads only those, so it reads what it wrote. Zlib and Gzip raise an error here: nothing in BetterBags uses them.
--   DecompressString raises an error on data that is not valid (the wiki: it "will raise an error if the data appears
--   to be invalid").
-- EncodeBase64(source, variant) -> string, DecodeBase64(source, variant) -> string: RFC 4648, Standard or
--   StandardUrlSafe, padded. DecodeBase64 returns nothing for text that is not Base64 (MayReturnNothing).

_G.Enum = _G.Enum or {}
_G.Enum.CompressionMethod = { Deflate = 0, Zlib = 1, Gzip = 2 }
_G.Enum.CompressionLevel = { Default = 0, OptimizeForSpeed = 1, OptimizeForSize = 2 }
_G.Enum.Base64Variant = { Standard = 0, StandardUrlSafe = 1 }

local floor, ldexp, frexp, huge = math.floor, math.ldexp, math.frexp, math.huge
local char, byte, concat = string.char, string.byte, table.concat

local STACK_LIMIT = 100

-- Big-endian bytes of a whole number below 2^(8 * count).
---@param n number
---@param count number
---@return string
local function bigEndian(n, count)
  local out = {}
  for i = count, 1, -1 do
    out[i] = char(n % 256)
    n = floor(n / 256)
  end
  return concat(out)
end

-- A CBOR item's head: its major type and its argument, in the fewest bytes.
---@param major number
---@param n number
---@return string
local function head(major, n)
  local base = major * 32
  if n < 24 then
    return char(base + n)
  elseif n < 256 then
    return char(base + 24) .. bigEndian(n, 1)
  elseif n < 65536 then
    return char(base + 25) .. bigEndian(n, 2)
  elseif n < 4294967296 then
    return char(base + 26) .. bigEndian(n, 4)
  end
  return char(base + 27) .. bigEndian(n, 8)
end

-- An IEEE 754 double, big-endian.
---@param x number
---@return string
local function double(x)
  if x ~= x then
    return char(0x7F, 0xF8, 0, 0, 0, 0, 0, 0)
  end
  local sign = 0
  if x < 0 or (x == 0 and 1 / x < 0) then
    sign = 1
    x = -x
  end
  local exponent, mantissa
  if x == huge then
    exponent, mantissa = 0x7FF, 0
  elseif x == 0 then
    exponent, mantissa = 0, 0
  else
    local m, e = frexp(x)
    exponent = e + 1022
    if exponent <= 0 then
      exponent, mantissa = 0, ldexp(x, 1074)
    else
      mantissa = (m * 2 - 1) * 2 ^ 52
    end
  end
  local high = sign * 2048 + exponent
  return char(floor(high / 16), (high % 16) * 16 + floor(mantissa / 2 ^ 48)) .. bigEndian(mantissa % 2 ^ 48, 6)
end

-- A table that is wholly an array: keys 1..n and nothing else.
---@param t table
---@return number|nil
local function arrayLength(t)
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  for i = 1, count do
    if rawget(t, i) == nil then
      return nil
    end
  end
  return count
end

local encode
---@param value any
---@param options? table
---@param out string[]
---@param seen table
---@param depth number
encode = function(value, options, out, seen, depth)
  local kind = type(value)
  if kind == "nil" then
    out[#out + 1] = char(0xF6)
  elseif kind == "boolean" then
    out[#out + 1] = char(value and 0xF5 or 0xF4)
  elseif kind == "number" then
    if value == floor(value) and value >= -2 ^ 53 and value <= 2 ^ 53 then
      if value >= 0 then
        out[#out + 1] = head(0, value)
      else
        out[#out + 1] = head(1, -1 - value)
      end
    else
      out[#out + 1] = char(0xFB) .. double(value)
    end
  elseif kind == "string" then
    out[#out + 1] = head(2, #value) .. value
  elseif kind == "table" then
    if depth > STACK_LIMIT then
      error("SerializeCBOR: nesting deeper than " .. STACK_LIMIT, 0)
    end
    if seen[value] then
      error("SerializeCBOR: a table holds itself", 0)
    end
    seen[value] = true
    local length = arrayLength(value)
    if length then
      out[#out + 1] = head(4, length)
      for i = 1, length do
        encode(value[i], options, out, seen, depth + 1)
      end
    else
      local count = 0
      for _ in pairs(value) do
        count = count + 1
      end
      out[#out + 1] = head(5, count)
      for k, v in pairs(value) do
        encode(k, options, out, seen, depth + 1)
        encode(v, options, out, seen, depth + 1)
      end
    end
    seen[value] = nil
  elseif options and options.ignoreSerializationErrors then
    out[#out + 1] = char(0xF7)
  else
    error("SerializeCBOR: cannot serialize a " .. kind, 0)
  end
end

-- A float of the given width: 1 sign bit, then the exponent and the mantissa.
---@param bytes string
---@param exponentBits number
---@param mantissaBits number
---@return number
local function float(bytes, exponentBits, mantissaBits)
  -- The sign and exponent from the first two bytes, the mantissa from the rest: a double's 64 bits do not fit in
  -- one Lua number, its 52-bit mantissa does.
  local top = byte(bytes, 1) * 256 + byte(bytes, 2)
  local sign = top >= 32768 and -1 or 1
  top = top % 32768
  local topMantissaBits = 15 - exponentBits
  local exponent = floor(top / 2 ^ topMantissaBits)
  local mantissa = top % 2 ^ topMantissaBits
  for i = 3, #bytes do
    mantissa = mantissa * 256 + byte(bytes, i)
  end
  local maxExponent = 2 ^ exponentBits - 1
  local bias = 2 ^ (exponentBits - 1) - 1
  if exponent == maxExponent then
    if mantissa == 0 then
      return sign * huge
    end
    return 0 / 0
  elseif exponent == 0 then
    return sign * ldexp(mantissa, 1 - bias - mantissaBits)
  end
  return sign * ldexp(mantissa + 2 ^ mantissaBits, exponent - bias - mantissaBits)
end

---@param source string
---@return any
local function decode(source)
  local pos = 1
  local function take(count)
    if pos + count - 1 > #source then
      error("DeserializeCBOR: the data ends early", 0)
    end
    local s = source:sub(pos, pos + count - 1)
    pos = pos + count
    return s
  end
  local function argument(info)
    if info < 24 then
      return info
    elseif info >= 24 and info <= 27 then
      local bytes = take(2 ^ (info - 24))
      local n = 0
      for i = 1, #bytes do
        n = n * 256 + byte(bytes, i)
      end
      return n
    end
    error("DeserializeCBOR: indefinite lengths are not supported", 0)
  end
  local item
  item = function(depth)
    if depth > STACK_LIMIT then
      error("DeserializeCBOR: nesting deeper than " .. STACK_LIMIT, 0)
    end
    local initial = byte(take(1))
    local major, info = floor(initial / 32), initial % 32
    if major == 0 then
      return argument(info)
    elseif major == 1 then
      return -1 - argument(info)
    elseif major == 2 or major == 3 then
      return take(argument(info))
    elseif major == 4 then
      local t = {}
      for i = 1, argument(info) do
        t[i] = item(depth + 1)
      end
      return t
    elseif major == 5 then
      local t = {}
      for _ = 1, argument(info) do
        local k = item(depth + 1)
        local v = item(depth + 1)
        if k == nil or k ~= k then
          error("DeserializeCBOR: a map key that is not a table key", 0)
        end
        t[k] = v
      end
      return t
    elseif major == 6 then
      error("DeserializeCBOR: tags are not supported", 0)
    elseif info == 20 then
      return false
    elseif info == 21 then
      return true
    elseif info == 22 or info == 23 then
      return nil
    elseif info == 25 then
      return float(take(2), 5, 10)
    elseif info == 26 then
      return float(take(4), 8, 23)
    elseif info == 27 then
      return float(take(8), 11, 52)
    end
    error("DeserializeCBOR: an unsupported simple value", 0)
  end
  local value = item(1)
  if pos <= #source then
    error("DeserializeCBOR: data after the value", 0)
  end
  return value
end

local ALPHABETS = {
  [0] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
  [1] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_",
}

---@param source any
---@param name string
local function checkString(source, name)
  if type(source) ~= "string" then
    error(name .. ": bad argument #1 (string expected, got " .. type(source) .. ")", 0)
  end
end

---@param method? number
---@param name string
local function checkDeflate(method, name)
  if method ~= nil and method ~= _G.Enum.CompressionMethod.Deflate then
    error(name .. ": the mock supports Deflate only", 0)
  end
end

_G.C_EncodingUtil = {
  SerializeCBOR = function(value, options)
    local out = {}
    encode(value, options, out, {}, 1)
    return concat(out)
  end,

  DeserializeCBOR = function(source)
    checkString(source, "DeserializeCBOR")
    return decode(source)
  end,

  CompressString = function(source, method)
    checkString(source, "CompressString")
    checkDeflate(method, "CompressString")
    local out = {}
    local pos = 1
    repeat
      local block = source:sub(pos, pos + 65534)
      pos = pos + #block
      local final = pos > #source
      local length = #block
      out[#out + 1] = char(final and 1 or 0) .. char(length % 256, floor(length / 256))
        .. char((65535 - length) % 256, floor((65535 - length) / 256)) .. block
    until final
    return concat(out)
  end,

  DecompressString = function(source, method)
    checkString(source, "DecompressString")
    checkDeflate(method, "DecompressString")
    local out = {}
    local pos = 1
    while true do
      local header = byte(source, pos)
      if not header then
        error("DecompressString: the data is not valid", 0)
      end
      if floor(header / 2) % 4 ~= 0 then
        error("DecompressString: the mock reads stored blocks only", 0)
      end
      local a, b, c, d = byte(source, pos + 1, pos + 4)
      if not d or a + b * 256 + c + d * 256 ~= 65535 then
        error("DecompressString: the data is not valid", 0)
      end
      local length = a + b * 256
      if pos + 4 + length > #source then
        error("DecompressString: the data is not valid", 0)
      end
      out[#out + 1] = source:sub(pos + 5, pos + 4 + length)
      pos = pos + 5 + length
      if header % 2 == 1 then
        return concat(out)
      end
    end
  end,

  EncodeBase64 = function(source, variant)
    checkString(source, "EncodeBase64")
    local alphabet = ALPHABETS[variant or 0]
    local out = {}
    for i = 1, #source, 3 do
      local a, b, c = byte(source, i, i + 2)
      local n = a * 65536 + (b or 0) * 256 + (c or 0)
      local quad = {}
      for j = 4, 1, -1 do
        local index = n % 64
        quad[j] = alphabet:sub(index + 1, index + 1)
        n = floor(n / 64)
      end
      if not b then
        quad[3], quad[4] = "=", "="
      elseif not c then
        quad[4] = "="
      end
      out[#out + 1] = concat(quad)
    end
    return concat(out)
  end,

  DecodeBase64 = function(source, variant)
    checkString(source, "DecodeBase64")
    local alphabet = ALPHABETS[variant or 0]
    local body, padding = source:match("^(.-)(=*)$")
    if #padding > 2 or (#padding > 0 and (#body + #padding) % 4 ~= 0) or #body % 4 == 1 then
      return
    end
    local values = {}
    for i = 1, #body do
      local index = alphabet:find(body:sub(i, i), 1, true)
      if not index then
        return
      end
      values[i] = index - 1
    end
    local out = {}
    for i = 1, #values, 4 do
      local count = math.min(4, #values - i + 1)
      local n = 0
      for j = 0, 3 do
        n = n * 64 + (values[i + j] or 0)
      end
      local bytes = bigEndian(n, 3)
      out[#out + 1] = bytes:sub(1, count - 1)
    end
    return concat(out)
  end,
}
