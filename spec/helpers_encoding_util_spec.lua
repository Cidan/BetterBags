-- helpers_encoding_util_spec.lua -- The C_EncodingUtil mock (spec/helpers/encoding_util.lua) against the RFCs it stands
-- in for: CBOR (RFC 8949, Appendix A's examples), Deflate's stored blocks (RFC 1951 §3.2.4) and Base64 (RFC 4648 §10's
-- test vectors), and what the client's documentation says it does with tables, bad data and options.

local E = C_EncodingUtil

local function hex(s)
  return (s:gsub(".", function(c) return string.format("%02x", c:byte()) end))
end

local function unhex(h)
  return (h:gsub("%x%x", function(pair) return string.char(tonumber(pair, 16)) end))
end

describe("the C_EncodingUtil mock", function()
  it("has the documented enums", function()
    assert.are.same({ Deflate = 0, Zlib = 1, Gzip = 2 }, Enum.CompressionMethod)
    assert.are.same({ Default = 0, OptimizeForSpeed = 1, OptimizeForSize = 2 }, Enum.CompressionLevel)
    assert.are.same({ Standard = 0, StandardUrlSafe = 1 }, Enum.Base64Variant)
  end)

  describe("SerializeCBOR", function()
    it("writes RFC 8949's examples, strings as byte strings", function()
      local cases = {
        { 0, "00" }, { 1, "01" }, { 23, "17" }, { 24, "1818" }, { 100, "1864" }, { 1000, "1903e8" },
        { 1000000, "1a000f4240" }, { 1000000000000, "1b000000e8d4a51000" }, { -1, "20" }, { -10, "29" },
        { -100, "3863" }, { -1000, "3903e7" }, { 1.1, "fb3ff199999999999a" }, { -4.1, "fbc010666666666666" },
        { 1.0e300, "fb7e37e43c8800759c" }, { false, "f4" }, { true, "f5" }, { "", "40" }, { "IETF", "4449455446" },
        { { 1, 2, 3 }, "83010203" }, { { 1, { 2, 3 }, { 4, 5 } }, "8301820203820405" }, { {}, "80" },
      }
      for _, case in ipairs(cases) do
        assert.are.equal(case[2], hex(E.SerializeCBOR(case[1])), tostring(case[1]))
      end
      assert.are.equal("fb7ff0000000000000", hex(E.SerializeCBOR(math.huge)))
      assert.are.equal("fbfff0000000000000", hex(E.SerializeCBOR(-math.huge)))
    end)

    it("writes a table that is not wholly an array as a map, whatever its keys", function()
      assert.are.equal("a1004474727565", hex(E.SerializeCBOR({ [0] = "true" })))
      assert.are.equal("a1190993f5", hex(E.SerializeCBOR({ [2451] = true })))
      assert.are.equal("a102f5", hex(E.SerializeCBOR({ [2] = true })))
      assert.are.equal("a1416101", hex(E.SerializeCBOR({ a = 1 })))
    end)

    it("refuses what it cannot write, unless told to write undefined in its place", function()
      assert.has_error(function() E.SerializeCBOR({ f = print }) end)
      local loop = {}
      loop.self = loop
      assert.has_error(function() E.SerializeCBOR(loop) end)
      local deep = {}
      for _ = 1, 101 do
        deep = { deep }
      end
      assert.has_error(function() E.SerializeCBOR(deep) end)
      assert.are.equal("a14166f7", hex(E.SerializeCBOR({ f = print }, { ignoreSerializationErrors = true })))
    end)
  end)

  describe("DeserializeCBOR", function()
    it("reads RFC 8949's examples, text strings as strings, every float width", function()
      assert.are.equal(1000000000000, E.DeserializeCBOR(unhex("1b000000e8d4a51000")))
      assert.are.equal(-1000, E.DeserializeCBOR(unhex("3903e7")))
      assert.are.equal(1.1, E.DeserializeCBOR(unhex("fb3ff199999999999a")))
      assert.are.equal(1.0, E.DeserializeCBOR(unhex("f93c00")))
      assert.are.equal(65504.0, E.DeserializeCBOR(unhex("f97bff")))
      assert.are.equal(2 ^ -24, E.DeserializeCBOR(unhex("f90001")))
      assert.are.equal(100000.0, E.DeserializeCBOR(unhex("fa47c35000")))
      assert.are.equal(-math.huge, E.DeserializeCBOR(unhex("f9fc00")))
      local nan = E.DeserializeCBOR(unhex("f97e00"))
      assert.is_true(nan ~= nan)
      assert.are.equal("IETF", E.DeserializeCBOR(unhex("6449455446")))
      assert.are.same({ 1, { 2, 3 }, { 4, 5 } }, E.DeserializeCBOR(unhex("8301820203820405")))
      assert.are.same({ [1] = 2, [3] = 4 }, E.DeserializeCBOR(unhex("a201020304")))
      assert.are.same({ a = 1, b = { 2, 3 } }, E.DeserializeCBOR(unhex("a26161016162820203")))
      assert.is_nil(E.DeserializeCBOR(unhex("f6")))
    end)

    it("reads back what SerializeCBOR wrote", function()
      local value = {
        [0] = true, [-1] = "minus", [2451] = { [1] = 0.25, [2] = 0.5, [3] = 1 }, name = 'q"\\\n\r\0\255',
        nested = { deep = { deeper = { false } } }, big = 2 ^ 53, small = -2 ^ 53, tiny = 2 ^ -1074,
      }
      assert.are.same(value, E.DeserializeCBOR(E.SerializeCBOR(value)))
    end)

    it("refuses tags, indefinite lengths, data that ends early or goes on, and nesting deeper than 100", function()
      for _, bad in ipairs({ "c074", "5f42010243030405ff", "9f01ff", "1903", "830102", "0000", "a1f601" }) do
        assert.has_error(function() E.DeserializeCBOR(unhex(bad)) end, nil, bad)
      end
      assert.has_error(function() E.DeserializeCBOR(string.rep("\129", 101) .. "\0") end)
      assert.has_error(function() E.DeserializeCBOR(nil) end)
    end)
  end)

  describe("CompressString and DecompressString", function()
    it("write and read Deflate's stored blocks", function()
      assert.are.equal("010300fcff616263", hex(E.CompressString("abc", Enum.CompressionMethod.Deflate,
        Enum.CompressionLevel.OptimizeForSize)))
      assert.are.equal("010000ffff", hex(E.CompressString("")))
      assert.are.equal("abc", E.DecompressString(unhex("010300fcff616263"), Enum.CompressionMethod.Deflate))
      local long = string.rep("0123456789", 7000)
      local compressed = E.CompressString(long)
      assert.are.equal(0, compressed:byte(1))
      assert.are.equal(long, E.DecompressString(compressed))
    end)

    it("raise an error on data that is not valid", function()
      for _, bad in ipairs({ "", "01", "010300fcff6162", "010300fdff616263", "000300fcff616263" }) do
        assert.has_error(function() E.DecompressString(unhex(bad)) end, nil, bad)
      end
    end)
  end)

  describe("EncodeBase64 and DecodeBase64", function()
    it("follow RFC 4648's test vectors, in both alphabets", function()
      local vectors = { { "", "" }, { "f", "Zg==" }, { "fo", "Zm8=" }, { "foo", "Zm9v" }, { "foob", "Zm9vYg==" },
        { "fooba", "Zm9vYmE=" }, { "foobar", "Zm9vYmFy" } }
      for _, v in ipairs(vectors) do
        assert.are.equal(v[2], E.EncodeBase64(v[1]))
        assert.are.equal(v[1], E.DecodeBase64(v[2]))
      end
      assert.are.equal("-_8=", E.EncodeBase64("\251\255", Enum.Base64Variant.StandardUrlSafe))
      assert.are.equal("+/8=", E.EncodeBase64("\251\255"))
      assert.are.equal("\251\255", E.DecodeBase64("-_8=", Enum.Base64Variant.StandardUrlSafe))
    end)

    it("return nothing for text that is not Base64", function()
      for _, bad in ipairs({ "Zm9v!", "Z", "Zg===", "Zg=", "-_8=", "Zm 9v" }) do
        assert.are.equal(0, select("#", E.DecodeBase64(bad)), bad)
      end
    end)
  end)
end)
