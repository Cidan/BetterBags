-- classic_settings_layout_spec.lua -- The classic settings window (config/config.lua) as players see
-- it: every entry it adds, in order, with its title, description, choices and ranges, compared
-- with spec/fixtures/classic_settings_layout.lua, recorded from the window before its settings moved
-- into the settings catalog (config/catalog.lua, docs/next-settings.md). Building the window on the
-- catalog must change nothing a player sees. What each setting does is covered by
-- config_redraw_spec.lua and catalog_spec.lua.

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local createdStubs = {}
local function stubModule(name)
  local mod, created = StubBetterBagsModule(name)
  if created then
    table.insert(createdStubs, name)
  end
  return mod
end

local const = stubModule("Constants")
const.BAG_KIND = const.BAG_KIND or { UNDEFINED = -1, BACKPACK = 0, BANK = 1 }
const.BAG_KIND.GUILD = const.BAG_KIND.GUILD or 2
const.FORM_LAYOUT = const.FORM_LAYOUT or { STACKED = 1 }
const.SECTION_SORT_TYPE = const.SECTION_SORT_TYPE or { ALPHABETICALLY = 1, SIZE_DESCENDING = 2, SIZE_ASCENDING = 3 }
const.ITEM_SORT_TYPE = const.ITEM_SORT_TYPE
  or { ALPHABETICALLY_THEN_QUALITY = 1, QUALITY_THEN_ALPHABETICALLY = 2, ITEM_LEVEL = 3, EXPANSION = 4 }

LoadFreshBetterBagsModule("Context", "core/context.lua")
stubModule("Events")
local db = stubModule("Database")
local bucket = stubModule("Bucket")
local form = stubModule("Form")
stubModule("Sonata")
stubModule("CategoryPane")
stubModule("ThemePane")
stubModule("CurrencyPane")
stubModule("ItemColorPane")

-- The settings catalog, when the window is built on it (it is not before).
if io.open("config/catalog.lua", "r") then
  LoadFreshBetterBagsModule("SettingsCatalog", "config/catalog.lua")
end
LoadFreshBetterBagsModule("Config", "config/config.lua")
local config = addon:GetModule("Config")

-- classicSettingsLayout builds the classic window with a form that records every entry, and returns
-- them as plain data: kind, title, description, static choices (or that they are computed), slider
-- range, a pane link's bag, a button group's titles.
---@param guildBank boolean
---@return table[]
local function classicSettingsLayout(guildBank)
  local saved = {}
  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end
  local entries
  override(form, "Create", function()
    local f = { frame = CreateFrame("Frame"), entries = {}, layout = { textAreas = {} } }
    setmetatable(f, { __index = function(_, key)
      if type(key) == "string" and key:match("^Add") then
        return function(self, opts) table.insert(self.entries, { kind = key, opts = opts or {} }) end
      end
    end })
    function f:GetFrame() return self.frame end
    entries = f.entries
    return f
  end)
  override(bucket, "Later", function() end)
  override(db, "GetProfileCharacterCounts", function() return {} end)
  override(addon, "hasGuildBank", guildBank)
  config.configFrame = nil
  config:CreateConfig()
  for i = #saved, 1, -1 do
    saved[i][1][saved[i][2]] = saved[i][3]
  end
  local layout = {}
  for _, entry in ipairs(entries) do
    local o = entry.opts
    local row = { kind = entry.kind, title = o.title, description = o.description }
    if o.items ~= nil then
      row.items = {}
      for i, item in ipairs(o.items) do row.items[i] = item end
    end
    if o.itemsFunction ~= nil then row.itemsFunction = true end
    row.min, row.max, row.step = o.min, o.max, o.step
    if entry.kind == "AddPaneLink" then
      row.bagKind = o.bagKind
    end
    if o.ButtonOptions ~= nil then
      row.buttons = {}
      for i, button in ipairs(o.ButtonOptions) do row.buttons[i] = button.title end
    end
    table.insert(layout, row)
  end
  return layout
end

describe("The classic settings window", function()
  teardown(function()
    for i = #createdStubs, 1, -1 do
      ResetModuleStub(createdStubs[i])
    end
  end)

  it("adds every entry players see, in order, as before the settings catalog", function()
    local recorded = dofile("spec/fixtures/classic_settings_layout.lua")
    local withGuild = classicSettingsLayout(true)
    local withoutGuild = classicSettingsLayout(false)
    assert.are.equal(#recorded.withGuildBank, #withGuild)
    for i, row in ipairs(recorded.withGuildBank) do
      assert.are.same(row, withGuild[i], "entry " .. i .. " (" .. tostring(row.title or row.description) .. ")")
    end
    assert.are.equal(#recorded.withoutGuildBank, #withoutGuild)
    for i, row in ipairs(recorded.withoutGuildBank) do
      assert.are.same(row, withoutGuild[i], "entry " .. i .. " (" .. tostring(row.title or row.description) .. ")")
    end
  end)
end)
