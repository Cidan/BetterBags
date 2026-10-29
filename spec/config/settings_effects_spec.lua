-- settings_effects_spec.lua -- What each setting asks the bags for when it changes, read from the
-- settings catalog (config/catalog.lua) the settings window is built on (next-settings.md §1). A setting
-- that only changes how the bags look redraws them (bags/Redraw, refresh-scheduler.md §9); a setting the
-- data phase reads recalculates them from the items already read (bags/Rederive, §10); only a setting a
-- bag read itself depends on reads the bags again (bags/FullRefreshAll). These were checked through the
-- classic settings window until it was removed.

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
const.SECTION_SORT_TYPE = const.SECTION_SORT_TYPE or { ALPHABETICALLY = 1, SIZE_DESCENDING = 2, SIZE_ASCENDING = 3 }
const.ITEM_SORT_TYPE = const.ITEM_SORT_TYPE
  or { ALPHABETICALLY_THEN_QUALITY = 1, QUALITY_THEN_ALPHABETICALLY = 2, ITEM_LEVEL = 3, EXPANSION = 4 }

local context = LoadFreshBetterBagsModule("Context", "core/context.lua")
local events = stubModule("Events")
local db = stubModule("Database")
local bucket = stubModule("Bucket")
local sonata = stubModule("Sonata")
local bagSystem = stubModule("BagSystem")
stubModule("Items")
LoadFreshBetterBagsModule("SettingsCatalog", "config/catalog.lua")
local catalog = addon:GetModule("SettingsCatalog")

describe("What each setting asks the bags for", function()
  local saved, sent

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  local function ctx()
    return context:New("Test")
  end

  -- settings returns a setting titled so, once per bag that has it (or once for a general one).
  local function settings(title)
    local found = {}
    for _, id in ipairs(catalog:Ids()) do
      for _, bag in ipairs({ false, unpack(catalog:Bags()) }) do
        local ok, option = pcall(catalog.Get, catalog, id, bag or nil)
        if ok and option.title == title then
          table.insert(found, option)
        end
      end
    end
    assert.is_true(#found > 0, "no setting titled " .. title)
    return found
  end

  local function messages()
    local out = {}
    for _, s in ipairs(sent) do out[#out + 1] = s.message end
    return out
  end

  before_each(function()
    sent, saved = {}, {}
    override(events, "SendMessage", function(_, _, message, ...)
      table.insert(sent, { message = message, args = { ... } })
    end)
    override(bucket, "Later", function(_, _, _, fn) fn() end)
    local bagSize = { itemsPerRow = 7, columnCount = 2 }
    local ilvl = { enabled = true, color = true }
    for key, fn in pairs({
      SetGlowIntensity = function() end,
      SetBagViewSizeItems = function() end,
      SetBagViewSizeColumn = function() end,
      SetShowFullSectionNames = function() end,
      GetBagView = function() return 1 end,
      GetBagSizeInfo = function() return bagSize end,
      GetItemLevelOptions = function() return ilvl end,
      GetStackingOptions = function() return { mergeStacks = false } end,
      SetUpgradeIconProvider = function() end,
      SetSectionSortType = function() end,
      SetItemSortType = function() end,
      GetSectionSortType = function() return 1 end,
      GetItemSortType = function() return 1 end,
      SetGroupsEnabled = function() end,
      GetCategoryFilters = function() return {} end,
      SetShowAllFreeSpace = function() end,
      SetPreserveItemGaps = function() end,
    }) do
      override(db, key, fn)
    end
    -- The backpack and the bank, whatever an earlier spec left ("the guild bank" sets it).
    override(addon, "hasGuildBank", false)
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
      for _, option in ipairs(settings(case[1])) do
        sent = {}
        option.set(ctx(), case[2])
        assert.same({ "bags/Redraw" }, messages())
        local options = sent[1].args[1]
        assert.equal(case[3], options ~= nil and options.buttons == true,
          case[1] .. (case[3] and " restyles the item buttons" or " leaves the item buttons alone"))
      end
    end)
  end

  -- The data phase reads these; their old full refresh (a wipe) also rebuilt the layout and redrew
  -- every button, which the recalculation still does.
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
      for _, option in ipairs(settings(case[1])) do
        sent = {}
        option.set(ctx(), case[2])
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

  -- The guild bank (BetterBags Next's, guild-bank.md §5) has the bags' settings of its own.
  it("writes the guild bank's own settings on a client with a guild bank", function()
    addon.hasGuildBank = true
    local kinds = {}
    override(db, "SetGlowIntensity", function(_, kind) table.insert(kinds, kind) end)
    for _, option in ipairs(settings("Quality Glow Intensity")) do
      option.set(ctx(), 50)
    end
    assert.are.same({ 0, 1, 2 }, kinds)
  end)

  -- The size mode: sized to its items (content) or a window the player sizes (window).
  it("makes each bag a window the player sizes, or one sized to its items, and redraws it", function()
    local modes = {}
    override(db, "GetBagSizeMode", function(_, kind) return modes[kind] or "content" end)
    override(db, "SetBagSizeMode", function(_, kind, mode) modes[kind] = mode end)
    local found = settings("Resizable Window")
    assert.are.equal(2, #found)
    for _, option in ipairs(found) do
      sent, modes = {}, {}
      assert.is_false(option.get(ctx()))
      option.set(ctx(), true)
      local kind = next(modes)
      assert.are.equal("window", modes[kind])
      assert.is_true(option.get(ctx()))
      option.set(ctx(), false)
      assert.are.equal("content", modes[kind])
      assert.are.same({ "bags/Redraw", "bags/Redraw" }, messages())
    end
  end)

  -- Snap to Content is read when the player lets go of the resize grip (window.md, snapping).
  it("turns Snap to Content on and off for each bag, with no refresh", function()
    local snaps = {}
    override(db, "GetBagSnapToContent", function(_, kind) return snaps[kind] ~= false end)
    override(db, "SetBagSnapToContent", function(_, kind, value) snaps[kind] = value end)
    local found = settings("Snap to Content")
    assert.are.equal(2, #found)
    for _, option in ipairs(found) do
      sent, snaps = {}, {}
      assert.is_true(option.get(ctx()))
      option.set(ctx(), false)
      local kind = next(snaps)
      assert.is_false(snaps[kind])
      assert.is_false(option.get(ctx()))
      assert.are.same({}, messages())
    end
  end)

  -- One setting for every bag (window.md §3a): the bags put themselves on the screen when it is turned
  -- on, and may be moved off it when it is off.
  it("turns Clamp Bags to Screen on and off, and tells the bags", function()
    local on = false
    override(db, "GetClampBagsToScreen", function() return on end)
    override(db, "SetClampBagsToScreen", function(_, value) on = value end)
    local found = settings("Clamp Bags to Screen")
    assert.are.equal(1, #found)
    assert.is_false(found[1].get(ctx()))
    found[1].set(ctx(), true)
    assert.is_true(on)
    assert.are.same({ "bags/ClampChanged" }, messages())
    found[1].set(ctx(), false)
    assert.is_false(on)
    assert.are.same({ "bags/ClampChanged", "bags/ClampChanged" }, messages())
  end)

  -- The bag's canvas reads it on every render (render-pipeline.md §4c). One setting for both bags.
  it("turns Animate Item Movement on and off, with no refresh", function()
    local on = false
    override(db, "GetAnimateItemMovement", function() return on end)
    override(db, "SetAnimateItemMovement", function(_, value) on = value end)
    local found = settings("Animate Item Movement")
    assert.are.equal(1, #found)
    assert.is_false(found[1].get(ctx()))
    found[1].set(ctx(), true)
    assert.is_true(on)
    assert.are.same({}, messages())
  end)

  -- BetterBags Next's Size tab (docs/next-appearance-size.md): each saves its percentage and tells the
  -- panels, which size themselves; the bags' items are neither read nor recalculated.
  for _, case in ipairs({ { "Icon Scale", "GetNextIconScale", "SetNextIconScale" },
    { "Bag Scale", "GetNextBagScale", "SetNextBagScale" } }) do
    it("saves " .. case[1] .. " and tells BetterBags Next's panels, reading nothing", function()
      local value = 100
      override(db, case[2], function() return value end)
      override(db, case[3], function(_, v) value = v end)
      local found = settings(case[1])
      assert.are.equal(1, #found)
      assert.are.equal("slider", found[1].kind)
      assert.are.same({ 50, 150, 5 }, { found[1].min, found[1].max, found[1].step })
      assert.are.equal(100, found[1].get(ctx()))
      found[1].set(ctx(), 125)
      assert.are.equal(125, value)
      assert.are.same({ "next/ScalesChanged" }, messages())
    end)
  end

  -- BetterBags Next's Animation tab (next-themes.md §20): each switch saves its effect on or off and tells BetterBags
  -- Next, which lays the switches over the theme in use again; the bags' items are neither read nor recalculated.
  for _, case in ipairs({ { "Sparkles", "sparkles" }, { "Title Shimmer", "shimmer" }, { "Title Cloud", "titleCloud" },
    { "Title Ribbon", "ribbon" }, { "Braid", "braid" }, { "Moving Ornaments", "ornaments" },
    { "Glitch Effects", "glitch" }, { "Data Rain", "rain" }, { "Ice Shatter", "shatter" }, { "Snow, Leaves and Stars", "snow" },
    { "Smoke Puff", "smoke" }, { "Bats", "bats" }, { "Transporter", "beam" } }) do
    it("saves " .. case[1] .. " on or off and tells BetterBags Next, reading nothing", function()
      local on = { [case[2]] = true }
      override(db, "GetNextAnimation", function(_, name) return on[name] end)
      override(db, "SetNextAnimation", function(_, name, value) on[name] = value end)
      local found = settings(case[1])
      assert.are.equal(1, #found)
      assert.are.equal("toggle", found[1].kind)
      assert.is_true(found[1].get(ctx()))
      found[1].set(ctx(), false)
      assert.is_false(on[case[2]])
      assert.are.same({ "next/AnimationChanged" }, messages())
      found[1].set(ctx(), true)
      assert.is_true(on[case[2]])
    end)
  end

  -- BetterBags Next's currencies (currency.md §6, the Currencies page's Display tab): each saves its choice and tells
  -- the strip and the tracker (currencies/OptionsChanged); the bags' items are neither read nor recalculated.
  describe("BetterBags Next's currencies", function()
    local options, tracker

    before_each(function()
      options = { capBars = false, gains = true, hideEmpty = true, itemsEverywhere = true, layout = "row", scale = 100,
        background = true, hideInCombat = false, growX = "left", growY = "down" }
      tracker = { out = false }
      override(db, "GetNextCurrencyOption", function(_, name) return options[name] end)
      override(db, "SetNextCurrencyOption", function(_, name, value) options[name] = value end)
      override(db, "GetNextCurrencyTracker", function() return tracker.out, tracker.x, tracker.y end)
      override(db, "SetNextCurrencyTracker", function(_, out, x, y)
        tracker.out = out
        if x ~= nil then tracker.x, tracker.y = x, y end
      end)
    end)

    for _, case in ipairs({ { "Cap Bars", "capBars" }, { "Show Gains", "gains" },
      { "Hide What You Have None Of", "hideEmpty" }, { "Count Items Everywhere", "itemsEverywhere" },
      { "Tracker Background", "background" }, { "Hide Tracker in Combat", "hideInCombat" } }) do
      it("saves " .. case[1] .. " on or off and tells the currencies, reading nothing", function()
        local found = settings(case[1])
        assert.are.equal(1, #found)
        assert.are.equal("toggle", found[1].kind)
        local was = options[case[2]]
        assert.are.equal(was, found[1].get(ctx()))
        found[1].set(ctx(), not was)
        assert.are.equal(not was, options[case[2]])
        assert.are.same({ "currencies/OptionsChanged" }, messages())
      end)
    end

    it("saves the tracker's layout by its name", function()
      local found = settings("Tracker Layout")
      assert.are.equal(1, #found)
      assert.are.same({ "Row", "Column", "List" }, found[1].items)
      assert.are.equal("Row", found[1].get(ctx()))
      found[1].set(ctx(), "List")
      assert.are.equal("list", options.layout)
      assert.are.equal("List", found[1].get(ctx()))
      assert.are.same({ "currencies/OptionsChanged" }, messages())
    end)

    -- Asked: a grow direction for the tracker, left by default; up and down for a list.
    it("saves which way the tracker grows: left or right in a row, up or down in a column or a list", function()
      local found = settings("Tracker Grows")
      assert.are.equal(1, #found)
      local grow = found[1]
      assert.are.equal("dropdown", grow.kind)
      assert.are.same({ "Left", "Right" }, grow.itemsFunction())
      assert.are.equal("Left", grow.get(ctx()))
      grow.set(ctx(), "Right")
      assert.are.equal("right", options.growX)
      assert.are.equal("Right", grow.get(ctx()))
      assert.are.same({ "currencies/OptionsChanged" }, messages())
      for _, layout in ipairs({ "column", "list" }) do
        options.layout = layout
        assert.are.same({ "Up", "Down" }, grow.itemsFunction())
        assert.are.equal(options.growY == "up" and "Up" or "Down", grow.get(ctx()))
      end
      grow.set(ctx(), "Up")
      assert.are.equal("up", options.growY)
      assert.are.equal("Up", grow.get(ctx()))
      assert.are.equal("right", options.growX, "the other way kept")
    end)

    it("saves the tracker's scale, 50% to 200% in steps of 5", function()
      local found = settings("Tracker Scale")
      assert.are.equal(1, #found)
      assert.are.same({ 50, 200, 5 }, { found[1].min, found[1].max, found[1].step })
      assert.are.equal(100, found[1].get(ctx()))
      found[1].set(ctx(), 135)
      assert.are.equal(135, options.scale)
      assert.are.same({ "currencies/OptionsChanged" }, messages())
    end)

    it("takes the tracker out or puts it away, keeping where it was left", function()
      tracker.x, tracker.y = 300, 200
      local found = settings("Show Tracker")
      assert.are.equal(1, #found)
      assert.is_false(found[1].get(ctx()))
      found[1].set(ctx(), true)
      assert.are.same({ true, 300, 200 }, { tracker.out, tracker.x, tracker.y })
      assert.is_true(found[1].get(ctx()))
      assert.are.same({ "currencies/OptionsChanged" }, messages())
      found[1].set(ctx(), false)
      assert.is_false(tracker.out)
    end)
  end)

  -- BetterBagsNext (next.md §11): turning it on or off switches the bags at once, no reload; a switch
  -- refused (combat, the bank, a vendor) says so, and the window shows the setting again.
  it("switches the bags without a reload, and says when the switch is refused", function()
    local on = false
    override(db, "GetNextEnabled", function() return on end)
    local switched, allow = {}, true
    override(bagSystem, "Switch", function(_, c, design)
      assert.is_not_nil(c)
      table.insert(switched, design)
      if allow then on = design == "next" end
      return allow
    end)
    local found = settings("BetterBags Next (experimental)")
    assert.are.equal(1, #found)
    assert.is_false(found[1].get(ctx()))
    assert.are_not.equal(false, found[1].set(ctx(), true))
    assert.is_true(on)
    allow = false
    assert.is_false(found[1].set(ctx(), false))
    assert.are.same({ "next", "classic" }, switched)
    assert.is_true(on)
    assert.is_nil(found[1].reload, "no reload")
    assert.are.same({}, messages())
  end)

  describe("opacity and scale", function()
    local windows, savedValues, opacityUpdates

    before_each(function()
      windows, savedValues, opacityUpdates = {}, {}, 0
      override(db, "SetBagViewSizeOpacity", function(_, kind, _, value) savedValues[#savedValues + 1] = { "opacity", kind, value } end)
      override(db, "SetBagViewSizeScale", function(_, kind, _, value) savedValues[#savedValues + 1] = { "scale", kind, value } end)
      override(sonata, "UpdateOpacity", function() opacityUpdates = opacityUpdates + 1 end)
      override(addon, "GetBagFromKind", function(_, kind)
        windows[kind] = windows[kind] or { opacity = 0, scale = 0, quiet = {} }
        local w = windows[kind]
        return { window = {
          UpdateOpacity = function() w.opacity = w.opacity + 1 end,
          UpdateScale = function(_, quiet) w.scale = w.scale + 1 table.insert(w.quiet, quiet == true) end,
        } }
      end)
    end)

    -- Every window follows an opacity: the bags their own, the other windows the backpack's.
    it("saves the opacity and fades every window with Sonata, sending nothing to the bags", function()
      for _, option in ipairs(settings("Opacity")) do
        sent, savedValues, opacityUpdates = {}, {}, 0
        option.set(ctx(), 55)
        assert.are.same({}, messages())
        assert.are.equal("opacity", savedValues[1][1])
        assert.are.equal(55, savedValues[1][3])
        assert.are.equal(1, opacityUpdates)
      end
    end)

    it("saves the scale and rescales the bag's window, which lays itself out again", function()
      for _, option in ipairs(settings("Scale")) do
        sent, savedValues = {}, {}
        option.set(ctx(), 120)
        assert.are.same({}, messages())
        assert.are.equal(120, savedValues[1][3])
        local w = windows[savedValues[1][2]]
        assert.are.equal(1, w.scale)
        assert.are.same({ false }, w.quiet)
      end
    end)

    -- A BetterBagsNext backpack has no window to rescale (next.md §1).
    it("saves the scale of a bag without a window", function()
      override(addon, "GetBagFromKind", function() return {} end)
      for _, option in ipairs(settings("Scale")) do
        savedValues = {}
        option.set(ctx(), 90)
        assert.are.equal(90, savedValues[1][3])
      end
    end)
  end)

  -- The item hash, which decides what stacks, includes the transmog appearance only with this
  -- setting; the hash is computed when a slot is read.
  it("reads the bags again for Split Transmogged Items", function()
    for _, option in ipairs(settings("Split Transmogged Items")) do
      sent = {}
      option.set(ctx(), true)
      assert.same({ "bags/FullRefreshAll" }, messages())
    end
  end)
end)
