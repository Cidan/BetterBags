local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Reads a TOC file and returns true if it lists the given file entry (matching on
-- a trailing path segment, tolerant of forward/back slashes and surrounding space).
local function tocListsFile(tocPath, entry)
  local fh = assert(io.open(tocPath, "r"))
  local wanted = entry:gsub("\\", "/"):lower()
  for line in fh:lines() do
    local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
    -- Skip comments (## metadata and # comments) and blank lines.
    if trimmed ~= "" and trimmed:sub(1, 1) ~= "#" then
      if trimmed:gsub("\\", "/"):lower() == wanted then
        fh:close()
        return true
      end
    end
  end
  fh:close()
  return false
end

describe("WoW: Forever (Camelot) detection", function()
  local savedIsForever

  before_each(function()
    savedIsForever = addon.isForever
    addon.isForever = nil
  end)

  after_each(function()
    addon.isForever = savedIsForever
  end)

  it("core/forever.lua sets addon.isForever to true", function()
    loadfile("core/forever.lua")("BetterBags")
    assert.is_true(addon.isForever)
  end)

  it("is listed in the Camelot TOC so it loads only on that client", function()
    assert.is_true(tocListsFile("BetterBags_Camelot.toc", "core/forever.lua"))
  end)

  it("is NOT listed in the base TOC (retail/classic must never be flagged Forever)", function()
    assert.is_false(tocListsFile("BetterBags.toc", "core/forever.lua"))
  end)

  it("loads before constants.lua in the Camelot TOC", function()
    local fh = assert(io.open("BetterBags_Camelot.toc", "r"))
    local foreverLine, constantsLine, n
    n = 0
    for line in fh:lines() do
      n = n + 1
      local t = line:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\\", "/"):lower()
      if t == "core/forever.lua" then foreverLine = n end
      if t == "core/constants.lua" then constantsLine = n end
    end
    fh:close()
    assert.is_not_nil(foreverLine)
    assert.is_not_nil(constantsLine)
    assert.is_true(foreverLine < constantsLine)
  end)
end)
