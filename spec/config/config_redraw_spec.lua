-- config_redraw_spec.lua -- Which refresh each setting in the config window asks for
-- (config/config.lua). A setting that only changes how the bags look redraws the bags
-- (bags/Redraw, refresh-scheduler.md §9); a setting the data phase reads recalculates
-- them from the items already read (bags/Rederive, §10); only a setting a bag read itself
-- depends on reads the bags again (bags/FullRefreshAll).

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
const.FORM_LAYOUT = const.FORM_LAYOUT or { STACKED = 1 }
const.SECTION_SORT_TYPE = const.SECTION_SORT_TYPE or { ALPHABETICALLY = 1, SIZE_DESCENDING = 2, SIZE_ASCENDING = 3 }
const.ITEM_SORT_TYPE = const.ITEM_SORT_TYPE
  or { ALPHABETICALLY_THEN_QUALITY = 1, QUALITY_THEN_ALPHABETICALLY = 2, ITEM_LEVEL = 3, EXPANSION = 4 }

local context = LoadFreshBetterBagsModule("Context", "core/context.lua")
local events = stubModule("Events")
local db = stubModule("Database")
local bucket = stubModule("Bucket")
local form = stubModule("Form")
stubModule("Themes")
local sonata = stubModule("Sonata")
stubModule("CategoryPane")
stubModule("ThemePane")
stubModule("CurrencyPane")
stubModule("ItemColorPane")

LoadFreshBetterBagsModule("Config", "config/config.lua")
local config = addon:GetModule("Config")

describe("Config settings refreshes", function()
  local saved, sent, entries

  -- A form that records every control it is given.
  local function fakeForm()
    local f = { frame = CreateFrame("Frame"), entries = {}, layout = { textAreas = {} } }
    setmetatable(f, { __index = function(_, key)
      if type(key) == "string" and key:match("^Add") then
        return function(self, opts) table.insert(self.entries, { kind = key, opts = opts or {} }) end
      end
    end })
    function f:GetFrame() return self.frame end
    return f
  end

  -- Each setting appears once per bag kind; return them all.
  local function settings(title)
    local found = {}
    for _, entry in ipairs(entries) do
      if entry.opts.title == title and entry.opts.setValue then
        table.insert(found, entry.opts)
      end
    end
    assert.is_true(#found > 0, "no setting titled " .. title)
    return found
  end

  before_each(function()
    sent = {}
    saved = {}
    for _, key in ipairs({ "SendMessage" }) do
      saved[#saved + 1] = { events, key, events[key] }
    end
    events.SendMessage = function(_, _, message, ...)
      table.insert(sent, { message = message, args = { ... } })
    end
    saved[#saved + 1] = { bucket, "Later", bucket.Later }
    bucket.Later = function(_, _, _, fn) fn() end
    saved[#saved + 1] = { form, "Create", form.Create }
    local created
    form.Create = function()
      created = fakeForm()
      return created
    end
    -- Database: every setter and getter the setting callbacks use.
    local bagSize = { itemsPerRow = 7, columnCount = 2 }
    local ilvl = { enabled = true, color = true }
    local dbStubs = {
      SetGlowIntensity = function() end,
      SetBagViewSizeItems = function() end,
      SetBagViewSizeColumn = function() end,
      SetShowFullSectionNames = function() end,
      SetStackingOptions = function() end,
      GetBagView = function() return 1 end,
      GetBagSizeInfo = function() return bagSize end,
      GetItemLevelOptions = function() return ilvl end,
      GetStackingOptions = function() return { mergeStacks = false } end,
      -- Read while the window is built (the profiles section).
      GetProfileCharacterCounts = function() return {} end,
      SetUpgradeIconProvider = function() end,
      SetSectionSortType = function() end,
      SetItemSortType = function() end,
      GetSectionSortType = function() return 1 end,
      GetItemSortType = function() return 1 end,
      SetGroupsEnabled = function() end,
      GetCategoryFilters = function() return {} end,
      SetShowAllFreeSpace = function() end,
      SetPreserveItemGaps = function() end,
    }
    for key, fn in pairs(dbStubs) do
      saved[#saved + 1] = { db, key, db[key] }
      db[key] = fn
    end
    config.configFrame = nil
    config:CreateConfig()
    entries = created.entries
  end)

  after_each(function()
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
  end)

  teardown(function()
    for i = #createdStubs, 1, -1 do
      ResetModuleStub(createdStubs[i])
    end
  end)

  local function messages()
    local out = {}
    for _, s in ipairs(sent) do out[#out + 1] = s.message end
    return out
  end

  local redrawOnly = {
    { "Items Per Row", 9, false },
    { "Columns", 3, false },
    { "Show Full Section Names", true, false },
    { "Quality Glow Intensity", 80, true },
    { "Show Item Level", false, true },
    { "Show Item Level Color", false, true },
  }
  for _, case in ipairs(redrawOnly) do
    it("redraws the bags for " .. case[1] .. " and reads nothing", function()
      for _, opts in ipairs(settings(case[1])) do
        sent = {}
        opts.setValue(context:New("Test"), case[2])
        assert.same({ "bags/Redraw" }, messages())
        local options = sent[1].args[1]
        assert.equal(case[3], options ~= nil and options.buttons == true,
          case[1] .. (case[3] and " restyles the item buttons" or " leaves the item buttons alone"))
      end
    end)
  end

  -- The data phase reads these; their old full refresh (a wipe) also rebuilt the layout and
  -- redrew every button, which the recalculation still does.
  local derived = {
    { "Upgrade Icon Provider", "Pawn" },
    { "Section Order", "Alphabetically" },
    { "Item Order", "Alphabetically" },
    { "Enable Groups", true },
    { "Equipment Location", true },
    { "Expansion", true },
    { "Equipment Set", true },
    { "Recent Items", true },
    { "Trade Skill", true },
    { "Type", true },
    { "Sub Type", true },
    { "Merge Stacks", true },
    { "Merge Unstackable", true },
    { "Don't Merge Partial Stacks", true },
    { "Unmerge on Interactions", true },
    { "Show All Free Space Slots", true },
    { "Preserve Empty Slots as Gaps", true },
  }
  for _, case in ipairs(derived) do
    it("recalculates the bags for " .. case[1] .. ", with a fresh layout and redrawn buttons", function()
      for _, opts in ipairs(settings(case[1])) do
        sent = {}
        opts.setValue(context:New("Test"), case[2])
        local refreshes = {}
        for _, s in ipairs(sent) do
          if s.message:match("^bags/") then refreshes[#refreshes + 1] = s end
        end
        assert.equal(1, #refreshes)
        assert.equal("bags/Rederive", refreshes[1].message)
        assert.same({ resetLayout = true, buttons = true }, refreshes[1].args[1])
      end
    end)
  end

  -- Opacity and scale belong to the bag's window: it fades its background or rescales and
  -- lays itself out again, with no message to the bags at all.
  describe("opacity and scale", function()
    local windows, savedValues, opacityUpdates

    before_each(function()
      windows, savedValues, opacityUpdates = {}, {}, 0
      for _, entry in ipairs({
        { db, "SetBagViewSizeOpacity", function(_, kind, _, value) savedValues[#savedValues + 1] = { "opacity", kind, value } end },
        { db, "SetBagViewSizeScale", function(_, kind, _, value) savedValues[#savedValues + 1] = { "scale", kind, value } end },
        { sonata, "UpdateOpacity", function() opacityUpdates = opacityUpdates + 1 end },
        { addon, "GetBagFromKind", function(_, kind)
          windows[kind] = windows[kind] or { opacity = 0, scale = 0, quiet = {} }
          local w = windows[kind]
          return { window = {
            UpdateOpacity = function() w.opacity = w.opacity + 1 end,
            UpdateScale = function(_, quiet) w.scale = w.scale + 1 table.insert(w.quiet, quiet == true) end,
          } }
        end },
      }) do
        saved[#saved + 1] = { entry[1], entry[2], entry[1][entry[2]] }
        entry[1][entry[2]] = entry[3]
      end
    end)

    -- Every window follows an opacity: the bags their own, the other windows the backpack's.
    it("saves the opacity and fades every window with Sonata, sending nothing to the bags", function()
      for _, opts in ipairs(settings("Opacity")) do
        sent, savedValues, opacityUpdates = {}, {}, 0
        opts.setValue(context:New("Test"), 55)
        assert.are.same({}, messages())
        assert.are.equal("opacity", savedValues[1][1])
        assert.are.equal(55, savedValues[1][3])
        assert.are.equal(1, opacityUpdates)
      end
    end)

    it("saves the scale and rescales the bag's window, which lays itself out again", function()
      for _, opts in ipairs(settings("Scale")) do
        sent, savedValues = {}, {}
        opts.setValue(context:New("Test"), 120)
        assert.are.same({}, messages())
        assert.are.equal(120, savedValues[1][3])
        local w = windows[savedValues[1][2]]
        assert.are.equal(1, w.scale)
        assert.are.same({ false }, w.quiet)
      end
    end)
  end)

  -- The item hash, which decides what stacks, includes the transmog appearance only with
  -- this setting; the hash is computed when a slot is read.
  it("reads the bags again for Split Transmogged Items", function()
    for _, opts in ipairs(settings("Split Transmogged Items")) do
      sent = {}
      opts.setValue(context:New("Test"), true)
      assert.same({ "bags/FullRefreshAll" }, messages())
    end
  end)
end)
