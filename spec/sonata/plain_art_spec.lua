-- plain_art_spec.lua -- the Plain theme (sonata/themes/next/plain.lua, docs/next-plain-theme.md) draws only Blizzard
-- art each client has: every atlas, Blizzard file, nine-slice layout, font and named color Plain resolves to on a
-- client is used by code that client loads from its branch of Blizzard's UI source (spec/helpers/ui_source.lua: the
-- files its TOCs load). An atlas the client lacks draws nothing; a font or color it lacks is an error.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
local uiSource = dofile("spec/helpers/ui_source.lua")

local FLAGS = { "isRetail", "isForever", "isClassic", "isBCC", "isMists", "isAnniversary", "isCata" }
-- The flags each client BetterBags ships a TOC for sets (core/constants.lua).
local FLAGS_OF = {
  Retail = { isRetail = true },
  Forever = { isRetail = true, isForever = true },
  Era = { isClassic = true },
  Anniversary = { isAnniversary = true, isBCC = true },
  Mists = { isMists = true },
}

-- names walks a resolved theme for what it names of Blizzard's: atlases, files (paths of the game's own, not
-- BetterBags'), nine-slice layouts (a Frame's Layout), fonts copied (Copy, Object) and named colors (Global).
local function names(theme)
  local found = { atlas = {}, file = {}, layout = {}, font = {}, color = {} }
  local function walk(t, key)
    for k, v in pairs(t) do
      if type(v) == "table" then
        walk(v, k)
      elseif type(v) == "string" then
        if k == "Atlas" then
          found.atlas[v] = true
        elseif (k == "Texture" or k == "Icon" or k == "QualityBorder" or k == "QuestMark") and v:find("\\", 1, true)
          and not v:lower():find("^interface\\addons\\") then
          found.file[v] = true
        elseif key == "Frame" and k == "Layout" then
          found.layout[v] = true
        elseif k == "Copy" or k == "Object" then
          found.font[v] = true
        elseif k == "Global" then
          found.color[v] = true
        end
      end
    end
  end
  walk(theme)
  -- The theme's own textures by name (Textures), the game's ones among them.
  for _, path in pairs(theme.Textures or {}) do
    if type(path) == "string" and path:find("\\", 1, true) and not path:lower():find("^interface\\addons\\") then
      found.file[path] = true
    end
  end
  return found
end

local function sorted(set)
  local list = {}
  for name in pairs(set) do table.insert(list, name) end
  table.sort(list)
  return list
end

describe("the Plain theme's art", function()
  local sonataNext = addon:GetModule("SonataNext")
  local available, why = uiSource.Available()

  it("can be checked: the UI source has every client's branch", function()
    assert.is_true(available, why)
  end)

  local clients = sorted(FLAGS_OF)
  for _, name in ipairs(clients) do
    it("is all used by the code " .. name .. " loads", function()
      if not available then
        error(why)
      end
      local saved = {}
      for _, flag in ipairs(FLAGS) do saved[flag] = addon[flag] end
      for _, flag in ipairs(FLAGS) do addon[flag] = FLAGS_OF[name][flag] == true end
      local ok, theme = pcall(sonataNext.Resolve, sonataNext, "Plain")
      for _, flag in ipairs(FLAGS) do addon[flag] = saved[flag] end
      assert.is_true(ok, tostring(theme))
      local client = uiSource.CLIENTS[name]
      local found = names(theme)
      local files = uiSource.Loaded(client)
      assert.is_true(#files > 1000, name .. " loads " .. #files .. " files")

      -- Each name as Blizzard writes it: an atlas and a font quoted; a file with either slash, its backslashes single
      -- (XML) or doubled (Lua); a layout as a table key; a color as a name.
      local needles, wanted = {}, {}
      local function want(kind, value, forms)
        wanted[#wanted + 1] = { kind = kind, value = value, forms = forms }
        for _, form in ipairs(forms) do table.insert(needles, form) end
      end
      for _, atlas in ipairs(sorted(found.atlas)) do
        -- Blizzard_CategoryList.lua builds these: string.format("Options_CategoryHeader_%d", headerIndex).
        local quoted = atlas:match("^Options_CategoryHeader_%d$") and '"Options_CategoryHeader_%d"' or ('"' .. atlas .. '"')
        want("atlas", atlas, { quoted })
      end
      for _, file in ipairs(sorted(found.file)) do
        want("file", file, { file, (file:gsub("\\", "\\\\")), (file:gsub("\\", "/")) })
      end
      for _, layout in ipairs(sorted(found.layout)) do
        want("layout", layout, { layout .. " =", layout .. "=" })
      end
      for _, font in ipairs(sorted(found.font)) do
        want("font", font, { 'name="' .. font .. '"' })
      end
      for _, color in ipairs(sorted(found.color)) do
        want("color", color, { color })
      end
      local uses = uiSource.Uses(client, files, needles)
      local missing = {}
      for _, w in ipairs(wanted) do
        local used = false
        for _, form in ipairs(w.forms) do
          used = used or uses[form]
        end
        if not used then
          table.insert(missing, w.kind .. " " .. w.value)
        end
      end
      assert.are.same({}, missing, name)
      assert.is_true(#wanted >= 40, name .. " checks " .. #wanted .. " names")
    end)
  end
end)
