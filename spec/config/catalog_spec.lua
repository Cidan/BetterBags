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
const.SECTION_SORT_TYPE = const.SECTION_SORT_TYPE or { ALPHABETICALLY = 1, SIZE_DESCENDING = 2, SIZE_ASCENDING = 3 }
const.ITEM_SORT_TYPE = const.ITEM_SORT_TYPE
  or { ALPHABETICALLY_THEN_QUALITY = 1, QUALITY_THEN_ALPHABETICALLY = 2, ITEM_LEVEL = 3, EXPANSION = 4 }

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

  it("lists the bags with settings of their own, the guild bank only where the client has one", function()
    assert.are.same({ { name = "Backpack", kind = 0 }, { name = "Bank", kind = 1 } }, catalog:Bags())
    addon.hasGuildBank = true
    assert.are.same({ { name = "Backpack", kind = 0 }, { name = "Bank", kind = 1 }, { name = "Guild Bank", kind = 2 } },
      catalog:Bags())
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
    assert.is_true(catalog:Has("inBagSearch"))
    assert.is_false(catalog:Has("noSuchSetting"))
    assert.has_error(function() catalog:Get("enableGroups", bank) end, "the bank has no setting enableGroups")
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

  it("reads a number within its range, and writes a number", function()
    local perRow = catalog:Get("itemsPerRow", backpack)
    assert.are.equal("slider", perRow.kind)
    assert.are.same({ 3, 20, 1 }, { perRow.min, perRow.max, perRow.step })
    assert.are.equal(20, perRow.get(ctx()), "the saved 25 shows as the most the slider has")
    perRow.set(ctx(), 9)
    assert.are.same({ 0, 1, 9 }, db._items)
    assert.are.same({ { message = "bags/Redraw", args = {} } }, sent)
  end)

  it("says which settings take effect after a reload", function()
    assert.is_true(catalog:Get("enableBankBags").reload)
    assert.is_nil(catalog:Get("inBagSearch").reload)
    catalog:Get("enableBankBags").set(ctx(), false)
    assert.is_false(db._bankBag)
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

  it("defines every setting the classic window had, once each", function()
    local ids = catalog:Ids()
    local seen = {}
    for _, id in ipairs(ids) do
      assert.is_nil(seen[id], id .. " twice")
      seen[id] = true
    end
    for _, id in ipairs({ "inBagSearch", "enterToMakeCategory", "categorySell", "showBagButton", "enableBankBags",
      "bagFading", "animateItemMovement", "nextEnabled", "upgradeProvider", "newItemDuration", "sectionOrder",
      "itemOrder", "enableGroups", "filterEquipmentLocation", "filterExpansion", "filterGearSet", "filterRecentItems",
      "filterTradeSkill", "filterType", "filterSubtype", "markRecentItems", "newItemFlash", "mergeStacks",
      "mergeUnstackable", "dontMergePartial", "dontMergeTransmog", "unmergeAtShop", "itemLevel", "itemLevelColor",
      "fullSectionNames", "showAllFreeSpace", "preserveGaps", "glowIntensity", "resizableWindow", "snapToContent",
      "itemsPerRow", "columns", "opacity", "scale" }) do
      assert.is_true(seen[id], id)
    end
  end)

  -- Category automation sells at most what buyback keeps unless this is off (automation.md).
  it("turns the automatic selling limit on and off, sending nothing", function()
    local on = true
    override(db, "GetAutoSellLimit", function() return on end)
    override(db, "SetAutoSellLimit", function(_, value) on = value end)
    local setting = catalog:Get("autoSellLimit")
    assert.are.equal("toggle", setting.kind)
    assert.is_true(setting.get(ctx()))
    setting.set(ctx(), false)
    assert.is_false(on)
    assert.truthy(setting.title:find("12", 1, true))
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
