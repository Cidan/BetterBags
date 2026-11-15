-- serialization_spec.lua -- Unit tests for util/serialization.lua: text that can be shared (C_EncodingUtil's CBOR,
-- Deflate and Base64), the "!BB" strings exported before it (parsed, never run: #1317), and DeepCopy.

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
LoadBetterBagsModule("util/serialization.lua")
local Serialization = addon:GetModule("Serialization")
local legacyExport = dofile("spec/helpers/legacy_export.lua")
local fixture = dofile("spec/fixtures/legacy_export_v3.lua")

local E = C_EncodingUtil

-- Every byte, so a string that holds them all survives.
local function everyByte()
  local bytes = {}
  for i = 0, 255 do
    bytes[#bytes + 1] = string.char(i)
  end
  return table.concat(bytes)
end

describe("Serialization", function()

  -- ─── Encode / Decode ───────────────────────────────────────────────────────

  describe("Encode and Decode", function()

    it("round-trip what a category export holds: item IDs, bag kinds from 0, negative numbers, fractions, any bytes", function()
      local value = Serialization:DeepCopy(fixture.data)
      value.customCategoryFilters['Mats "&" Herbs'].note = everyByte()
      assert.are.same(value, Serialization:Decode(Serialization:Encode(value)))
    end)

    it("write Base64 only, so the text survives a chat box", function()
      assert.is_truthy(Serialization:Encode(fixture.data):match("^[A-Za-z0-9+/]+=*$"))
    end)

    it("write CBOR, compressed with Deflate, in Base64", function()
      local text = Serialization:Encode({ version = 3 })
      local cbor = E.DecompressString(E.DecodeBase64(text), Enum.CompressionMethod.Deflate)
      assert.are.same({ version = 3 }, E.DeserializeCBOR(cbor))
    end)

    -- C_EncodingUtil raises on some bad data and returns nothing on other (MayReturnNothing); each step handles both.
    it("refuse text when any step raises an error or returns nothing, naming the step", function()
      local text = Serialization:Encode({ version = 3 })
      local reasons = {
        DecodeBase64 = "it is not Base64",
        DecompressString = "it is not compressed data",
        DeserializeCBOR = "it does not hold a table",
      }
      for name, reason in pairs(reasons) do
        local real = E[name]
        for _, broken in ipairs({ function() error("bad data") end, function() end }) do
          E[name] = broken
          local ok, value, err = pcall(Serialization.Decode, Serialization, text)
          E[name] = real
          assert.is_true(ok, name)
          assert.is_nil(value, name)
          assert.are.equal(reason, err, name)
        end
      end
      local realDecode = E.DecodeBase64
      for _, broken in ipairs({ function() error("bad data") end, function() end }) do
        E.DecodeBase64 = broken
        local ok, value, err = pcall(Serialization.DecodeLegacy, Serialization, "e30=")
        E.DecodeBase64 = realDecode
        assert.is_true(ok)
        assert.is_nil(value)
        assert.are.equal("it is not Base64", err)
      end
    end)

    it("refuse text that is not Base64, not compressed, not CBOR or not a table, saying so", function()
      local cases = {
        "!!!not base64!!!",
        E.EncodeBase64("not compressed"),
        E.EncodeBase64(E.CompressString("\255")),
        E.EncodeBase64(E.CompressString(E.SerializeCBOR(42))),
        E.EncodeBase64(E.CompressString(E.SerializeCBOR("a string"))),
      }
      for _, text in ipairs(cases) do
        local value, err = Serialization:Decode(text)
        assert.is_nil(value, text)
        assert.is_string(err, text)
      end
    end)
  end)

  -- ─── DecodeLegacy ──────────────────────────────────────────────────────────

  describe("DecodeLegacy", function()

    it("reads a string the old exporter wrote", function()
      local value, err = Serialization:DecodeLegacy(fixture.text:sub(4))
      assert.is_nil(err)
      assert.are.same(fixture.data, value)
    end)

    it("reads every value the old writer wrote: strings of any bytes, numbers of any form, booleans, keys of each kind", function()
      local value = {
        everything = everyByte(),
        quoted = 'a "quoted" \\ back\\slash\nnew line\r\0',
        numbers = { -2, 0, 0.25, -0.5, 1.5e-07, 1e+20, 123456789012 },
        [0] = true, [-1] = false, [2447] = { [1] = {}, [2] = { deep = { deeper = "yes" } } },
        [true] = "a boolean key", [false] = 0,
        empty = {},
      }
      assert.are.same(value, Serialization:DecodeLegacy(legacyExport(value):sub(4)))
    end)

    it("reads the nil the old writer wrote for a value it could not write", function()
      assert.are.same({ kept = 1 }, Serialization:DecodeLegacy(legacyExport({ kept = 1, dropped = print }):sub(4)))
    end)

    it("never runs what the string holds: calls, globals, operators and functions are refused", function()
      _G.BB1317_RAN = nil
      local payloads = {
        '(function() _G.BB1317_RAN = true return { ["version"] = 3, } end)()',
        '{\n  ["version"] = (function() _G.BB1317_RAN = true return 3 end)(),\n}',
        '{\n  ["version"] = print("x"),\n}',
        '{\n  ["version"] = ("x"):rep(3),\n}',
        '{\n  ["version"] = BB1317_GLOBAL,\n}',
        '{\n  ["version"] = 1 + 2,\n}',
        '{\n  ["version"] = "a" .. "b",\n}',
        '{\n  ["version"] = function() end,\n}',
        '{\n  ["version"] = -x,\n}',
        'setmetatable({}, {})',
        '{\n  [f()] = 1,\n}',
      }
      for _, payload in ipairs(payloads) do
        local value, err = Serialization:DecodeLegacy(E.EncodeBase64(payload))
        assert.is_nil(value, payload)
        assert.is_string(err, payload)
      end
      assert.is_nil(_G.BB1317_RAN)
    end)

    it("refuses what the old writer never wrote", function()
      local bad = {
        '"a string"', '42', 'true', 'nil', '',
        '{\n  ["a"] = "unfinished,\n}',
        '{\n  ["a"] = "\\q",\n}',
        '{\n  ["a"] = "\\256",\n}',
        '{\n  ["a"] = 1,\n}\n}',
        '{\n  ["a"] = 1,\n} trailing',
        '{\n  ["a"] = 1\n  ["b"] = 2,\n}',
        '{ 1, 2, }',
        '{ a = 1, }',
        '{\n  ["a"] = 0x10,\n}',
        '{\n  ["a"] = [[long string]],\n}',
        '{\n  ["a"] = 1, -- comment\n}',
        '{\n  [{}] = 1,\n}',
        '{\n  [nil] = 1,\n}',
        '{\n  ["a"] = 1,',
        '{\n  ("a"] = 1,\n}',
        '{\n  ["a") = 1,\n}',
        '{\n  ["a"] : 1,\n}',
        'x["a"] = 1, }',
      }
      for _, text in ipairs(bad) do
        local value, err = Serialization:DecodeLegacy(E.EncodeBase64(text))
        assert.is_nil(value, text)
        assert.is_string(err, text)
      end
    end)

    it("reads a last field with no comma after it", function()
      assert.are.same({ a = 1, b = { 2 } },
        Serialization:DecodeLegacy(E.EncodeBase64('{ ["a"] = 1, ["b"] = { [1] = 2 } }')))
    end)

    it("refuses text that is not Base64", function()
      local value, err = Serialization:DecodeLegacy("!!!")
      assert.is_nil(value)
      assert.is_string(err)
    end)

    it("refuses nesting too deep to read, without raising", function()
      local text = string.rep('{ ["a"] = ', 30000) .. "1" .. string.rep(" }", 30000)
      local value, err = Serialization:DecodeLegacy(E.EncodeBase64(text))
      assert.is_nil(value)
      assert.is_string(err)
    end)
  end)

  -- ─── DeepCopy ───────────────────────────────────────────────────────────────

  describe("DeepCopy", function()

    it("creates an independent copy of a flat table", function()
      local orig = {a = 1, b = 2}
      local copy = Serialization:DeepCopy(orig)
      assert.same(orig, copy)
      -- Mutating the copy should not affect the original
      copy.a = 99
      assert.are.equal(1, orig.a)
    end)

    it("creates an independent copy of nested tables", function()
      local orig = {outer = {inner = "value"}}
      local copy = Serialization:DeepCopy(orig)
      assert.same(orig, copy)
      copy.outer.inner = "changed"
      assert.are.equal("value", orig.outer.inner)
    end)

    it("copies non-table values directly", function()
      assert.are.equal(42, Serialization:DeepCopy(42))
      assert.are.equal("hello", Serialization:DeepCopy("hello"))
      assert.are.equal(true, Serialization:DeepCopy(true))
      assert.is_nil(Serialization:DeepCopy(nil))
    end)

    it("preserves metatables", function()
      local mt = {__index = function() return "meta" end}
      local orig = setmetatable({}, mt)
      local copy = Serialization:DeepCopy(orig)
      assert.are.equal("meta", copy.anything)
    end)

    it("handles an empty table", function()
      local orig = {}
      local copy = Serialization:DeepCopy(orig)
      assert.same({}, copy)
      assert.are_not.equal(orig, copy) -- different table references
    end)
  end)
end)
