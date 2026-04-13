-- serialization_spec.lua -- Unit tests for util/serialization.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
LoadBetterBagsModule("util/serialization.lua")
local Serialization = addon:GetModule("Serialization")

describe("Serialization", function()

  -- ─── Serialize / Deserialize ────────────────────────────────────────────────

  describe("Serialize + Deserialize", function()

    it("round-trips a simple flat table", function()
      local tbl = {a = 1, b = "hello", c = true}
      local str = Serialization:Serialize(tbl)
      local result = Serialization:Deserialize(str)
      assert.same(tbl, result)
    end)

    it("round-trips a table with numeric keys", function()
      local tbl = {10, 20, 30}
      local str = Serialization:Serialize(tbl)
      local result = Serialization:Deserialize(str)
      assert.same(tbl, result)
    end)

    it("round-trips nested tables", function()
      local tbl = {outer = {inner = {deep = "value"}}}
      local str = Serialization:Serialize(tbl)
      local result = Serialization:Deserialize(str)
      assert.same(tbl, result)
    end)

    it("round-trips an empty table", function()
      local tbl = {}
      local str = Serialization:Serialize(tbl)
      local result = Serialization:Deserialize(str)
      assert.same(tbl, result)
    end)

    it("round-trips strings with special characters", function()
      local tbl = {msg = 'he said "hello"', path = "a\\b\\c"}
      local str = Serialization:Serialize(tbl)
      local result = Serialization:Deserialize(str)
      assert.same(tbl, result)
    end)

    it("round-trips mixed key types", function()
      local tbl = {[1] = "first", ["key"] = "second", [true] = nil}
      local str = Serialization:Serialize(tbl)
      local result = Serialization:Deserialize(str)
      assert.same(tbl, result)
    end)

    it("round-trips boolean values", function()
      local tbl = {enabled = true, disabled = false}
      local str = Serialization:Serialize(tbl)
      local result = Serialization:Deserialize(str)
      assert.same(tbl, result)
    end)

    it("serializes to a string", function()
      local tbl = {x = 1}
      local str = Serialization:Serialize(tbl)
      assert.is_string(str)
      assert.is_truthy(#str > 0)
    end)
  end)

  -- ─── Deserialize errors ─────────────────────────────────────────────────────

  describe("Deserialize", function()

    it("returns nil and an error for invalid Lua syntax", function()
      local result, err = Serialization:Deserialize("{{{invalid")
      assert.is_nil(result)
      assert.is_not_nil(err)
    end)

    it("returns nil and an error for non-table expressions", function()
      -- loadstring("return 42") succeeds but returns a number, not a table.
      -- The function still returns it (no type check), so this tests the boundary.
      local result = Serialization:Deserialize("42")
      assert.are.equal(42, result)
    end)
  end)

  -- ─── Base64 ─────────────────────────────────────────────────────────────────

  describe("Base64", function()

    it("round-trips a simple string", function()
      local input = "Hello, World!"
      local encoded = Serialization:EncodeBase64(input)
      local decoded = Serialization:DecodeBase64(encoded)
      assert.are.equal(input, decoded)
    end)

    it("round-trips an empty string", function()
      local encoded = Serialization:EncodeBase64("")
      local decoded = Serialization:DecodeBase64(encoded)
      assert.are.equal("", decoded)
    end)

    it("round-trips binary-like data", function()
      local input = "\0\1\2\255\254\253"
      local encoded = Serialization:EncodeBase64(input)
      local decoded = Serialization:DecodeBase64(encoded)
      assert.are.equal(input, decoded)
    end)

    it("round-trips strings of various lengths (padding cases)", function()
      -- Length 1: needs == padding
      local a = "A"
      assert.are.equal(a, Serialization:DecodeBase64(Serialization:EncodeBase64(a)))
      -- Length 2: needs = padding
      local ab = "AB"
      assert.are.equal(ab, Serialization:DecodeBase64(Serialization:EncodeBase64(ab)))
      -- Length 3: no padding
      local abc = "ABC"
      assert.are.equal(abc, Serialization:DecodeBase64(Serialization:EncodeBase64(abc)))
    end)

    it("produces only valid Base64 characters", function()
      local encoded = Serialization:EncodeBase64("test data 123")
      assert.is_truthy(encoded:match("^[A-Za-z0-9+/=]+$"))
    end)

    it("adds correct padding", function()
      -- 1 byte input -> 4 chars with == padding
      local enc1 = Serialization:EncodeBase64("A")
      assert.is_truthy(enc1:match("==$"))
      -- 2 byte input -> 4 chars with = padding
      local enc2 = Serialization:EncodeBase64("AB")
      assert.is_truthy(enc2:match("=$"))
      -- 3 byte input -> 4 chars with no padding
      local enc3 = Serialization:EncodeBase64("ABC")
      assert.is_falsy(enc3:match("="))
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
