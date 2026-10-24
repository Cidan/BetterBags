-- BetterBags-Themes' Next themes: each loads through the TOC, resolves and checks clean on every client, describes
-- itself, and ships every file its Textures name under the addon, as a PNG with an alpha channel, sides powers of two.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
if addon:GetModule("NextTween", true) == nil then
  ResetModuleStub("NextTween", "next/tween.lua")
  LoadBetterBagsModule("next/tween.lua")
end
LoadBetterBagsModule("core/context.lua")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextOrnaments", "next/ornaments.lua" } }) do
  if addon:GetModule(m[1], true) == nil then
    ResetModuleStub(m[1], m[2])
    LoadBetterBagsModule(m[2])
  end
end
local H = dofile("tools/next_theme_check/themes.lua")

local FLAGS = { "isRetail", "isForever", "isClassic", "isBCC", "isMists", "isAnniversary", "isCata" }
local CLIENTS = {
  Retail = { isRetail = true }, Forever = { isRetail = true, isForever = true }, Era = { isClassic = true },
  TBC = { isBCC = true }, Anniversary = { isAnniversary = true, isBCC = true }, Mists = { isMists = true },
  Cata = { isCata = true },
}

local function png(path)
  local f = io.open(path, "rb")
  if f == nil then return nil end
  local data = f:read("*a")
  f:close()
  if data:sub(1, 8) ~= "\137PNG\r\n\26\n" then return false end
  local function u32(i)
    local a, b, c, d = data:byte(i, i + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
  end
  return u32(17), u32(21), data:byte(25), data:byte(26)
end

local function pow2(n)
  while n > 1 and n % 2 == 0 do n = n / 2 end
  return n == 1
end

describe("BetterBags-Themes' Next themes", function()
  local sonataNext, keys, saved

  before_each(function()
    sonataNext = FreshNextThemes()
    keys = H.Load()
    saved = {}
    for _, flag in ipairs(FLAGS) do saved[flag] = addon[flag] end
  end)

  after_each(function()
    for _, flag in ipairs(FLAGS) do addon[flag] = saved[flag] end
    FreshNextThemes()
  end)

  it("registers through the TOC", function()
    print("themes: " .. table.concat(keys, ", "))
    assert.is_true(#keys >= 1)
  end)

  it("resolves every one on every client and finds nothing it does not define", function()
    for client, flags in pairs(CLIENTS) do
      for _, flag in ipairs(FLAGS) do addon[flag] = flags[flag] == true end
      for _, key in ipairs(keys) do
        local theme = sonataNext:Resolve(key)
        assert.is_true(theme.DisplayName ~= "Default" and theme.Description ~= "", key)
        assert.are.same({}, sonataNext:Check(key), key .. " on " .. client)
      end
    end
  end)

  it("ships every file its Textures name under the addon: RGBA PNGs, sides powers of two", function()
    for _, key in ipairs(keys) do
      local theme = sonataNext:Resolve(key)
      for name, path in pairs(theme.Textures) do
        if type(path) == "string" and path:sub(1, #H.ART_PREFIX) == H.ART_PREFIX then
          local file = H.REPO .. path:sub(#H.ART_PREFIX + 1):gsub("\\", "/")
          local w, h, depth, kind = png(file)
          assert.is_not_nil(w, key .. "." .. name .. ": " .. file .. " is shipped")
          assert.are.same({ 8, 6 }, { depth, kind }, file .. ": RGBA")
          assert.is_true(pow2(w) and pow2(h), file .. ": " .. tostring(w) .. " x " .. tostring(h))
        end
      end
      for i, o in ipairs(theme.Panel.Ornaments or {}) do
        local path = theme.Textures[o.Texture] or o.Texture
        assert.are.equal(H.ART_PREFIX, path:sub(1, #H.ART_PREFIX), key .. " ornament " .. i .. " is the addon's art")
      end
    end
  end)
end)
