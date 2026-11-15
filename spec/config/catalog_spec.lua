-- catalog_spec.lua -- The settings catalog (config/catalog.lua, docs/next-settings.md): every setting
-- defined once, read and written through it by both settings windows. These check what the catalog
-- itself promises: settings bound to a bag, the shapes the windows read, the rules (a setting that
-- needs a reload, a change that was refused) and what each kind of setting sends so the bags show
-- it. What each setting sends is checked by settings_effects_spec.lua; the window built on it by
-- spec/next/settings/.

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
const.NEXT_SECTION_COLUMNS_MAX = const.NEXT_SECTION_COLUMNS_MAX or 4
const.SECTION_SORT_TYPE = const.SECTION_SORT_TYPE or { ALPHABETICALLY = 1, SIZE_DESCENDING = 2, SIZE_ASCENDING = 3 }
const.ITEM_SORT_TYPE = const.ITEM_SORT_TYPE
  or { ALPHABETICALLY_THEN_QUALITY = 1, QUALITY_THEN_ALPHABETICALLY = 2, ITEM_LEVEL = 3, EXPANSION = 4,
    SELL_PRICE_STACK = 5, SELL_PRICE_EACH = 6 }

local context = LoadFreshBetterBagsModule("Context", "core/context.lua")
local events = stubModule("Events")
local db = stubModule("Database")
local bucket = stubModule("Bucket")
stubModule("Sonata")
local bagSystem = stubModule("BagSystem")
local itemsModule = stubModule("Items")

LoadFreshBetterBagsModule("SettingsCatalog", "config/catalog.lua")
local catalog = addon:GetModule("SettingsCatalog")

describe("The settings catalog", function()
  local saved, sent, stacking, ilvl, filters

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  local function ctx()
    return context:New("spec")
  end

  local backpack = { name = "Backpack", kind = 0 }
  local bank = { name = "Bank", kind = 1 }
  local guild = { name = "Guild Bank", kind = 2 }
  -- BetterBags Next's vendor: no bag the data engine reads, so its kind is UNDEFINED (next/vendor.lua).
  local vendor = { name = "Vendor", kind = -1 }

  before_each(function()
    saved, sent = {}, {}
    stacking = { [0] = { mergeStacks = false }, [1] = { mergeStacks = true } }
    ilvl = { [0] = { enabled = true, color = false }, [1] = { enabled = false, color = false } }
    filters = { [0] = { Type = true }, [1] = { Type = false } }
    override(events, "SendMessage", function(_, _, message, ...)
      table.insert(sent, { message = message, args = { ... } })
    end)
    override(bucket, "Later", function(_, _, _, fn) fn() end)
    override(db, "GetStackingOptions", function(_, kind) return stacking[kind] end)
    override(db, "GetItemLevelOptions", function(_, kind) return ilvl[kind] end)
    override(db, "GetCategoryFilters", function(_, kind) return filters[kind] end)
    override(db, "GetBagView", function() return 1 end)
    override(db, "GetSectionSortType", function() return const.SECTION_SORT_TYPE.SIZE_DESCENDING end)
    override(db, "SetSectionSortType", function(_, kind, view, value) db._sectionSort = { kind, view, value } end)
    override(db, "GetBagSizeInfo", function() return { itemsPerRow = 25, columnCount = 3, opacity = 80, scale = 100 } end)
    override(db, "SetBagViewSizeItems", function(_, kind, view, value) db._items = { kind, view, value } end)
    override(db, "GetEnableBankBag", function() return true end)
    override(db, "SetEnableBankBag", function(_, value) db._bankBag = value end)
    override(db, "GetNextEnabled", function() return false end)
    override(db, "GetGroupsEnabled", function() return true end)
    override(db, "SetGroupsEnabled", function() end)
    override(itemsModule, "GetActiveUpgradeProvider", function() return "Pawn" end)
    override(itemsModule, "upgradeProviders", { BetterBags = {}, Pawn = {} })
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

  -- Asked: "we need to add a bag menu for all our bag windows, so we have Backpack, Bank, and Guild Bank, we need to add
  -- Vendor as well".
  it("lists the bags with settings of their own, the guild bank only where the client has one, then the vendor", function()
    assert.are.same({ backpack, bank, vendor }, catalog:Bags())
    addon.hasGuildBank = true
    assert.are.same({ backpack, bank, guild, vendor }, catalog:Bags())
  end)

  it("refuses a setting it does not define, naming it", function()
    assert.has_error(function() catalog:Get("noSuchSetting") end, "the settings catalog has no setting named noSuchSetting")
  end)

  it("binds a bag's setting to that bag, its text naming the bag", function()
    local mine, theirs = catalog:Get("mergeStacks", backpack), catalog:Get("mergeStacks", bank)
    assert.are.equal("toggle", mine.kind)
    assert.are.equal("Merge Stacks", mine.title)
    assert.are.equal("Stackable items will merge into a single item button in your backpack.", mine.description)
    assert.are.equal("Stackable items will merge into a single item button in your bank.", theirs.description)
    assert.is_false(mine.get(ctx()))
    assert.is_true(theirs.get(ctx()))
    mine.set(ctx(), true)
    assert.is_true(stacking[0].mergeStacks)
    assert.is_true(stacking[1].mergeStacks)
    assert.are.same({ { message = "bags/Rederive", args = { { resetLayout = true, buttons = true } } } }, sent)
  end)

  it("needs a bag for a bag's setting, and none for the others", function()
    assert.has_error(function() catalog:Get("mergeStacks") end, "the setting mergeStacks belongs to a bag")
    assert.has_error(function() catalog:Get("inBagSearch", backpack) end, "the setting inBagSearch belongs to no bag")
  end)

  it("gives a setting only to the bags it has (groups: the backpack)", function()
    assert.is_true(catalog:Has("enableGroups", backpack))
    assert.is_false(catalog:Has("enableGroups", bank))
    assert.is_true(catalog:Has("mergeStacks", bank))
    assert.is_true(catalog:Has("mergeStacks", guild))
    assert.is_true(catalog:Has("inBagSearch"))
    assert.is_false(catalog:Has("noSuchSetting"))
    assert.has_error(function() catalog:Get("enableGroups", bank) end, "the bank has no setting enableGroups")
  end)

  -- Asked (#1321): "There should be an option in the settings to allow for hiding of empty layout groups", for the
  -- backpack and the bank (groups.md §3). Which tabs show needs no recalculation: the bags list their tabs again.
  it("hides a bag's empty group tabs, the backpack's and the bank's alone, listing the bag's tabs again", function()
    local hide = { [0] = false, [1] = true }
    override(db, "GetHideEmptyGroups", function(_, kind) return hide[kind] end)
    override(db, "SetHideEmptyGroups", function(_, kind, value) hide[kind] = value end)
    assert.is_true(catalog:Has("hideEmptyGroups", backpack))
    assert.is_true(catalog:Has("hideEmptyGroups", bank))
    assert.is_false(catalog:Has("hideEmptyGroups", guild))
    assert.is_false(catalog:Has("hideEmptyGroups", vendor))
    local setting = catalog:Get("hideEmptyGroups", backpack)
    assert.are.equal("toggle", setting.kind)
    assert.are.equal("Hide Empty Groups", setting.title)
    assert.are.equal("Hide the tab of a group with nothing in your backpack. The group shown stays, and every group's "
      .. "tab shows while you drag a section, to drop it on one.", setting.description)
    assert.are.equal("Hide the tab of a group with nothing in your bank. The group shown stays, and every group's "
      .. "tab shows while you drag a section, to drop it on one.", catalog:Get("hideEmptyGroups", bank).description)
    assert.is_false(setting.get(ctx()))
    assert.is_true(catalog:Get("hideEmptyGroups", bank).get(ctx()))
    setting.set(ctx(), true)
    assert.is_true(hide[0])
    assert.is_true(hide[1], "the bank keeps its own")
    assert.are.same({ { message = "groups/HideEmptyChanged", args = { 0, true } } }, sent)
  end)

  -- The vendor shows a merchant's items in cards: it has none of the bags' settings of how items are sorted, stacked
  -- and filed, only those that name it (its Size tab and Enable Vendor Window).
  it("gives the vendor only the settings that name it", function()
    for _, id in ipairs(catalog:Ids()) do
      local def = catalog.defs[id]
      if def.bag then
        local named = false
        for _, kind in ipairs(def.only or {}) do
          if kind == vendor.kind then named = true end
        end
        assert.are.equal(named, catalog:Has(id, vendor), id)
      end
    end
    for _, id in ipairs({ "nextIconScale", "nextBagScale", "nextAutosize", "nextFitNamesWhileOpen", "nextVendor" }) do
      assert.is_true(catalog:Has(id, vendor), id)
    end
    for _, id in ipairs({ "mergeStacks", "sectionOrder", "itemLevel", "filterType", "glowIntensity" }) do
      assert.is_false(catalog:Has(id, vendor), id)
    end
    assert.has_error(function() catalog:Get("mergeStacks", vendor) end, "the vendor has no setting mergeStacks")
  end)

  -- Issue #202: a keystone's level on its button, by a setting of its own beside the item level's. The guild bank
  -- takes no bound item, so never a keystone.
  it("shows a keystone's level by its own setting, in the backpack and the bank", function()
    ilvl[0].keystone, ilvl[1].keystone = true, false
    local mine, theirs = catalog:Get("keystoneLevel", backpack), catalog:Get("keystoneLevel", bank)
    assert.are.equal("toggle", mine.kind)
    assert.are.equal("Show Keystone Level", mine.title)
    assert.are.equal("Show a keystone's level on its button in the backpack.", mine.description)
    assert.is_true(mine.get(ctx()))
    assert.is_false(theirs.get(ctx()))
    mine.set(ctx(), false)
    assert.is_false(ilvl[0].keystone)
    assert.is_false(ilvl[1].keystone)
    assert.are.same({ { message = "bags/Redraw", args = { { buttons = true } } } }, sent)
    assert.is_false(catalog:Has("keystoneLevel", { name = "Guild Bank", kind = 2 }))
  end)

  -- Asked (#1239): the tooltip said the tabs are at the bottom of the backpack, where only the classic bags draw them;
  -- BetterBags Next's run down the panel's side, and both designs read this one description.
  it("describes Enable Groups without naming where the tabs are drawn", function()
    assert.are.equal("Show group tabs on the backpack. Groups allow you to organize categories into separate tabs. "
      .. "When disabled, all categories are shown in a single view.", catalog:Get("enableGroups", backpack).description)
  end)

  it("reads a choice as the item chosen, and writes the item picked", function()
    local order = catalog:Get("sectionOrder", backpack)
    assert.are.equal("dropdown", order.kind)
    assert.are.same({ "Alphabetically", "Size Descending", "Size Ascending" }, order.items)
    assert.are.equal("Size Descending", order.get(ctx()))
    order.set(ctx(), "Size Ascending")
    assert.are.same({ 0, 1, const.SECTION_SORT_TYPE.SIZE_ASCENDING }, db._sectionSort)
    local provider = catalog:Get("upgradeProvider")
    assert.are.equal("Pawn", provider.get(ctx()))
    local list = provider.itemsFunction(ctx())
    table.sort(list)
    assert.are.same({ "BetterBags", "None", "Pawn" }, list)
  end)

  -- Issue #1303: items in a section by what a vendor pays, for the stack or for one.
  it("offers the item orders, the two sell prices after the others", function()
    override(db, "GetItemSortType", function() return const.ITEM_SORT_TYPE.SELL_PRICE_EACH end)
    override(db, "SetItemSortType", function(_, kind, view, value) db._itemSort = { kind, view, value } end)
    local order = catalog:Get("itemOrder", backpack)
    assert.are.same({ "Alphabetically", "Quality", "Item Level", "Expansion", "Sell Price (Stack)", "Sell Price (Each)" },
      order.items)
    assert.are.equal("Sell Price (Each)", order.get(ctx()))
    order.set(ctx(), "Sell Price (Stack)")
    assert.are.same({ 0, 1, const.ITEM_SORT_TYPE.SELL_PRICE_STACK }, db._itemSort)
    order.set(ctx(), "Sell Price (Each)")
    assert.are.same({ 0, 1, const.ITEM_SORT_TYPE.SELL_PRICE_EACH }, db._itemSort)
    local words = {}
    for _, word in ipairs(order.keywords) do words[word] = true end
    assert.is_true(words["sell price"] and words["vendor"] and true or false)
  end)

  it("reads a number within its range, and writes a number", function()
    local perRow = catalog:Get("itemsPerRow", backpack)
    assert.are.equal("slider", perRow.kind)
    assert.are.same({ 3, 20, 1 }, { perRow.min, perRow.max, perRow.step })
    assert.are.equal(20, perRow.get(ctx()), "the saved 25 shows as the most the slider has")
    perRow.set(ctx(), 9)
    assert.are.same({ 0, 1, 9 }, db._items)
    assert.are.same({ { message = "bags/Redraw", args = {} } }, sent)
  end)

  -- Asked: "a 'compact' mode to columns, as a single toggle".
  it("turns a bag's compact sections on and off, off at one column, and the fill off with it", function()
    local columns, compact = { [backpack.kind] = 2 }, {}
    override(db, "GetNextSectionColumns", function(_, kind) return columns[kind] or 1 end)
    override(db, "GetNextSectionCompact", function(_, kind) return compact[kind] == true end)
    override(db, "SetNextSectionCompact", function(_, kind, on) compact[kind] = on end)
    local toggle = catalog:Get("sectionCompact", backpack)
    assert.are.equal("toggle", toggle.kind)
    assert.are.equal("Compact Sections", toggle.title)
    assert.is_false(toggle.get(ctx()))
    assert.is_false(toggle.disabled())
    local fill = catalog:Get("sectionFill", backpack)
    assert.is_false(fill.disabled())
    toggle.set(ctx(), true)
    assert.is_true(compact[backpack.kind])
    assert.is_true(toggle.get(ctx()))
    assert.is_true(fill.disabled(), "with no columns there is nothing to fill")
    columns[backpack.kind] = 1
    assert.is_true(toggle.disabled())
  end)

  -- Asked: "let's have an option for 'leave a gap between sections' which keeps things 1 icon grid apart. this should go in
  -- each bag's layout section, disabled by default".
  it("turns a bag's gap between sections on and off, that bag's alone, off at one column", function()
    local columns, gaps = { [backpack.kind] = 2, [bank.kind] = 2 }, {}
    override(db, "GetNextSectionColumns", function(_, kind) return columns[kind] or 1 end)
    override(db, "GetNextSectionGap", function(_, kind) return gaps[kind] == true end)
    override(db, "SetNextSectionGap", function(_, kind, on) gaps[kind] = on end)
    local toggle = catalog:Get("sectionGap", backpack)
    assert.are.equal("toggle", toggle.kind)
    assert.are.equal("Gap Between Sections", toggle.title)
    assert.is_truthy(toggle.description:find("backpack", 1, true), "names its bag")
    assert.is_truthy(toggle.description:find("grid", 1, true))
    local words = {}
    for _, word in ipairs(toggle.keywords) do words[word] = true end
    assert.is_true(words.gap and words.spacing and words.padding and words["side by side"] and true or false)
    assert.is_false(toggle.get(ctx()))
    assert.is_false(toggle.disabled())
    toggle.set(ctx(), true)
    assert.are.same({ [backpack.kind] = true }, gaps)
    assert.is_true(toggle.get(ctx()))
    assert.is_false(catalog:Get("sectionGap", bank).get(ctx()), "the bank's stays")
    assert.are.same({ { message = "next/SectionColumnsChanged", args = { backpack.kind } } }, sent)
    columns[backpack.kind] = 1
    assert.is_true(toggle.disabled(), "nothing stands side by side in one column")
  end)

  -- Asked of a small bag fitting its names: "with an option to enable/disable this behavior in settings, default disable";
  -- then: "every appearance -> size option needs to become per-bag".
  it("turns a bag's Fit Names While Open on and off, that bag's alone", function()
    local on = {}
    override(db, "GetNextFitNamesWhileOpen", function(_, kind) return on[kind] == true end)
    override(db, "SetNextFitNamesWhileOpen", function(_, kind, value) on[kind] = value end)
    local toggle = catalog:Get("nextFitNamesWhileOpen", bank)
    assert.are.equal("toggle", toggle.kind)
    assert.are.equal("Fit Names While Open", toggle.title)
    assert.is_truthy(toggle.description:find("cut short", 1, true))
    assert.is_truthy(toggle.description:find("bank", 1, true), "names its bag")
    local words = {}
    for _, word in ipairs(toggle.keywords) do words[word] = true end
    assert.is_true(words.width and words.names and words.title)
    assert.is_false(toggle.get(ctx()))
    toggle.set(ctx(), true)
    assert.are.same({ [1] = true }, on)
    assert.is_true(toggle.get(ctx()))
    assert.is_false(catalog:Get("nextFitNamesWhileOpen", backpack).get(ctx()), "the backpack's stays")
    assert.are.same({ { message = "next/FitNamesChanged", args = { 1 } } }, sent)
  end)

  -- Asked: "autosize bags ... it should make it so the bag grows on the vertical (Y axis) to hold all items + free space the
  -- user currently has, keeping the X size as is. it should be a toggle option"; then, per bag.
  it("turns a bag's Autosize on and off, that bag's alone", function()
    local on = { [0] = true, [-1] = false }
    override(db, "GetNextAutosize", function(_, kind) return on[kind] end)
    override(db, "SetNextAutosize", function(_, kind, value) on[kind] = value end)
    local toggle = catalog:Get("nextAutosize", backpack)
    assert.are.equal("toggle", toggle.kind)
    assert.are.equal("Autosize", toggle.title)
    assert.is_truthy(toggle.description:find("Free Space", 1, true))
    assert.is_truthy(toggle.description:find("backpack", 1, true), "names its bag")
    local words = {}
    for _, word in ipairs(toggle.keywords) do words[word] = true end
    assert.is_true(words.height and words.autosize and words.fit)
    assert.is_true(toggle.get(ctx()))
    toggle.set(ctx(), false)
    assert.is_false(on[0])
    assert.is_false(toggle.get(ctx()))
    catalog:Get("nextAutosize", vendor).set(ctx(), true)
    assert.is_true(on[-1])
    assert.is_false(on[0], "the backpack's stays")
    assert.are.same({ { message = "next/AutosizeChanged", args = { 0 } }, { message = "next/AutosizeChanged", args = { -1 } } },
      sent)
  end)

  for _, case in ipairs({ { "nextIconScale", "Icon Scale", "GetNextIconScale", "SetNextIconScale" },
    { "nextBagScale", "Bag Scale", "GetNextBagScale", "SetNextBagScale" } }) do
    it("saves a bag's " .. case[2] .. ", that bag's alone, and tells its panel", function()
      local scales = { [0] = 100, [1] = 100, [2] = 100, [-1] = 100 }
      override(db, case[3], function(_, kind) return scales[kind] end)
      override(db, case[4], function(_, kind, value) scales[kind] = value end)
      addon.hasGuildBank = true
      for _, bag in ipairs({ backpack, bank, guild, vendor }) do
        local slider = catalog:Get(case[1], bag)
        assert.are.equal("slider", slider.kind)
        assert.are.equal(case[2], slider.title)
        assert.is_truthy(slider.description:find(string.lower(bag.name), 1, true), bag.name)
        assert.are.same({ 50, 150, 5 }, { slider.min, slider.max, slider.step })
      end
      catalog:Get(case[1], vendor).set(ctx(), 125)
      assert.are.same({ [0] = 100, [1] = 100, [2] = 100, [-1] = 125 }, scales)
      assert.are.equal(125, catalog:Get(case[1], vendor).get(ctx()))
      assert.are.same({ { message = "next/ScalesChanged", args = { -1 } } }, sent)
    end)
  end

  it("saves a bag's section columns and fill order, the fill off at one column", function()
    local columns, fill = {}, {}
    override(db, "GetNextSectionColumns", function(_, kind) return columns[kind] or 1 end)
    override(db, "SetNextSectionColumns", function(_, kind, n) columns[kind] = n end)
    override(db, "GetNextSectionFill", function(_, kind) return fill[kind] or "across" end)
    override(db, "SetNextSectionFill", function(_, kind, f) fill[kind] = f end)
    local spans, limits = {}, {}
    override(db, "GetNextSectionWideRows", function(_, kind) return limits[kind] or 2 end)
    override(db, "SetNextSectionWideRows", function(_, kind, n) limits[kind] = n end)
    override(db, "GetNextSectionSpan", function(_, kind) return spans[kind] ~= false end)
    override(db, "SetNextSectionSpan", function(_, kind, on) spans[kind] = on end)
    override(db, "GetNextSectionCompact", function() return false end)
    local count = catalog:Get("sectionColumns", backpack)
    assert.are.equal("slider", count.kind)
    assert.are.same({ 1, 4, 1 }, { count.min, count.max, count.step })
    assert.are.equal(1, count.get(ctx()))
    local order = catalog:Get("sectionFill", backpack)
    assert.are.equal("dropdown", order.kind)
    assert.are.same({ "Side to Side", "Top to Bottom" }, order.items)
    assert.are.equal("Side to Side", order.get(ctx()))
    assert.is_true(order.disabled())
    local span = catalog:Get("sectionSpan", backpack)
    assert.are.equal("toggle", span.kind)
    assert.is_true(span.get(ctx()))
    assert.is_true(span.disabled())
    span.set(ctx(), false)
    assert.is_false(spans[backpack.kind])
    count.set(ctx(), 2)
    assert.is_false(span.disabled())
    local limit = catalog:Get("sectionWideRows", backpack)
    assert.are.equal("Wide Column Limit", limit.title)
    assert.are.equal("slider", limit.kind)
    assert.are.same({ 2, 10, 1 }, { limit.min, limit.max, limit.step })
    assert.are.equal(2, limit.get(ctx()))
    assert.is_true(limit.disabled(), "wide sections are off")
    span.set(ctx(), true)
    assert.is_false(limit.disabled())
    count.set(ctx(), 1)
    assert.is_true(limit.disabled(), "one column")
    count.set(ctx(), 2)
    limit.set(ctx(), 5)
    assert.are.equal(5, limits[backpack.kind])
    assert.are.equal(2, columns[backpack.kind])
    assert.is_false(order.disabled())
    order.set(ctx(), "Top to Bottom")
    assert.are.equal("down", fill[backpack.kind])
    assert.are.equal("Top to Bottom", order.get(ctx()))
  end)

  it("says which settings take effect after a reload", function()
    assert.is_true(catalog:Get("enableBankBags", bank).reload)
    assert.is_nil(catalog:Get("inBagSearch").reload)
    catalog:Get("enableBankBags", bank).set(ctx(), false)
    assert.is_false(db._bankBag)
  end)

  -- Asked: "all the enable/disable toggles in general need to move to a general tab in each respective bag menu": each is
  -- its bag's own setting.
  it("gives each bag's Enable switch to its bag alone", function()
    addon.hasGuildBank = true
    for id, owner in pairs({ enableBankBags = bank, nextVendor = vendor, nextGuildBank = guild }) do
      for _, bag in ipairs(catalog:Bags()) do
        assert.are.equal(bag.kind == owner.kind, catalog:Has(id, bag), id .. " for the " .. bag.name)
      end
      assert.has_error(function() catalog:Get(id) end, "the setting " .. id .. " belongs to a bag")
    end
  end)

  it("says a change was refused", function()
    local switched = true
    override(bagSystem, "Switch", function(_, _, design)
      db._design = design
      return switched
    end)
    local setting = catalog:Get("nextEnabled")
    assert.is_true(setting.set(ctx(), true) ~= false)
    assert.are.equal("next", db._design)
    switched = false
    assert.is_false(setting.set(ctx(), false))
    assert.are.equal("classic", db._design)
  end)

  -- Enable Vendor Window and Enable Guild Bank Window (#1262): the bag system switches each at once, and says when
  -- it refuses (at a vendor, at the guild bank).
  it("switches BetterBags Next's vendor and guild bank windows at once, saying when it was refused", function()
    local asked, allow = {}, true
    override(bagSystem, "SetVendorEnabled", function(_, c, on)
      table.insert(asked, { "vendor", on, c ~= nil })
      return allow
    end)
    override(bagSystem, "SetGuildBankEnabled", function(_, c, on)
      table.insert(asked, { "guild", on, c ~= nil })
      return allow
    end)
    override(db, "GetNextVendorEnabled", function() return true end)
    override(db, "GetNextGuildBankEnabled", function() return false end)
    local vendorWindow, guildWindow = catalog:Get("nextVendor", vendor), catalog:Get("nextGuildBank", guild)
    assert.are.equal("toggle", vendorWindow.kind)
    assert.are.equal("toggle", guildWindow.kind)
    assert.are.equal("Enable Vendor Window", vendorWindow.title)
    assert.are.equal("Enable Guild Bank Window", guildWindow.title)
    assert.is_true(vendorWindow.get(ctx()))
    assert.is_false(guildWindow.get(ctx()))
    assert.is_true(vendorWindow.set(ctx(), false) ~= false)
    assert.is_true(guildWindow.set(ctx(), true) ~= false)
    allow = false
    assert.is_false(vendorWindow.set(ctx(), true))
    assert.is_false(guildWindow.set(ctx(), false))
    assert.are.same({ { "vendor", false, true }, { "guild", true, true }, { "vendor", true, true }, { "guild", false, true } },
      asked)
    assert.is_nil(vendorWindow.reload, "no reload")
    assert.is_nil(guildWindow.reload, "no reload")
    assert.are.same({}, sent)
  end)

  -- The QuickFind integration (integrations/quickfind.lua): BetterBags' items stay a QuickFind source, empty while it
  -- is off, so it follows the switch at once.
  it("turns the QuickFind integration on and off, sending nothing", function()
    local on = true
    override(db, "GetQuickFindEnabled", function() return on end)
    override(db, "SetQuickFindEnabled", function(_, value) on = value end)
    local setting = catalog:Get("quickFind")
    assert.are.equal("toggle", setting.kind)
    assert.are.equal("Enable QuickFind Integration", setting.title)
    assert.is_true(setting.get(ctx()))
    setting.set(ctx(), false)
    assert.is_false(on)
    assert.is_false(setting.get(ctx()))
    assert.is_nil(setting.reload, "no reload")
    assert.are.same({}, sent)
  end)

  -- What the backpack does at each interaction (interaction-bags.md): a choice for each, saved by the interaction's
  -- name in Enum.PlayerInteractionType and read as its window opens and closes, so choosing sends nothing.
  it("offers what the backpack does at each interaction, saved by the interaction's name, sending nothing", function()
    local chosen = {}
    override(db, "GetInteractionBags", function(_, name) return chosen[name] end)
    override(db, "SetInteractionBags", function(_, name, value) chosen[name] = value end)
    local interactions = {
      interactionTrade = { "Trade", "TradePartner" }, interactionBank = { "Bank", "Banker" },
      interactionWarbank = { "Warband Bank", "AccountBanker" }, interactionVendor = { "Vendor", "Merchant" },
      interactionMail = { "Mailbox", "MailInfo" }, interactionAuctionHouse = { "Auction House", "Auctioneer" },
      interactionGuildBank = { "Guild Bank", "GuildBanker" },
      interactionVoidStorage = { "Void Storage", "VoidStorageBanker" },
      interactionScrapper = { "Scrapper", "ScrappingMachine" }, interactionItemUpgrade = { "Item Upgrade", "ItemUpgrade" },
    }
    for id, want in pairs(interactions) do
      local name = want[2]
      chosen[name] = "openClose"
      local setting = catalog:Get(id)
      assert.are.equal("dropdown", setting.kind, id)
      assert.are.equal(want[1], setting.title, id)
      assert.are.same({ "Open and Close", "Open Only", "Leave Alone" }, setting.items, id)
      assert.is_nil(setting.reload, id)
      assert.are.equal("Open and Close", setting.get(ctx()), id)
      setting.set(ctx(), "Open Only")
      assert.are.equal("open", chosen[name], id)
      assert.are.equal("Open Only", setting.get(ctx()), id)
      setting.set(ctx(), "Leave Alone")
      assert.are.equal("none", chosen[name], id)
      assert.are.equal("Leave Alone", setting.get(ctx()), id)
      setting.set(ctx(), "Open and Close")
      assert.are.equal("openClose", chosen[name], id)
    end
    assert.are.same({}, sent)
  end)

  it("defines every setting the classic window had, once each", function()
    local ids = catalog:Ids()
    local seen = {}
    for _, id in ipairs(ids) do
      assert.is_nil(seen[id], id .. " twice")
      seen[id] = true
    end
    for _, id in ipairs({ "inBagSearch", "enterToMakeCategory", "categorySell", "showBagButton", "enableBankBags",
      "bagFading", "animateItemMovement", "clampBagsToScreen", "nextEnabled", "upgradeProvider", "newItemDuration", "sectionOrder",
      "itemOrder", "enableGroups", "filterEquipmentLocation", "filterExpansion", "filterGearSet", "filterRecentItems",
      "filterTradeSkill", "filterType", "filterSubtype", "markRecentItems", "newItemFlash", "mergeStacks",
      "mergeUnstackable", "dontMergePartial", "dontMergeTransmog", "unmergeAtShop", "itemLevel", "itemLevelColor",
      "fullSectionNames", "showAllFreeSpace", "preserveGaps", "glowIntensity", "resizableWindow", "snapToContent",
      "itemsPerRow", "columns", "opacity", "scale" }) do
      assert.is_true(seen[id], id)
    end
  end)

  -- Before, only the changelog window's "Don't show me this again" checkbox set it (next-settings.md §7).
  it("turns What's New on login on and off, sending nothing", function()
    local auto = true
    override(db, "GetChangelogAutoOpen", function() return auto end)
    override(db, "SetChangelogAutoOpen", function(_, value) auto = value end)
    local setting = catalog:Get("changelogOnLogin")
    assert.are.equal("toggle", setting.kind)
    assert.is_true(setting.get(ctx()))
    setting.set(ctx(), false)
    assert.is_false(auto)
    assert.is_false(setting.get(ctx()))
    assert.are.same({}, sent)
  end)

  it("keeps searching words beside a setting's own text", function()
    local glow = catalog:Get("glowIntensity", backpack)
    assert.is_true(#glow.keywords > 0)
    for _, word in ipairs(glow.keywords) do
      assert.are.equal("string", type(word))
    end
  end)
end)
