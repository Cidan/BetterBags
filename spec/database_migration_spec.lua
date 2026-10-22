-- database_migration_spec.lua -- Tests targeting the Migrate() function directly.
-- This file does NOT stub Migrate() so we can test real migration logic.

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

addon.isRetail = true
addon.isClassic = false
addon.isBCC = false
addon.isCata = false
addon.isMists = false
addon.isAnniversary = false
addon.isMidnight = false
addon.tocVersion = 110000

-- Required globals
_G.Enum = _G.Enum or {}
_G.Enum.BankType = { Character = 1, Account = 2 }
_G.Enum.BagIndex = {
  Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4,
  ReagentBag = 5, Bank = -1, Reagentbank = -3,
  BankBag_1 = 6, BankBag_2 = 7, BankBag_3 = 8, BankBag_4 = 9,
  BankBag_5 = 10, BankBag_6 = 11, BankBag_7 = 12,
  Characterbanktab = 100, CharacterBankTab_1 = 101, CharacterBankTab_2 = 102,
  CharacterBankTab_3 = 103, CharacterBankTab_4 = 104, CharacterBankTab_5 = 105,
  CharacterBankTab_6 = 106,
  AccountBankTab_1 = 200, AccountBankTab_2 = 201, AccountBankTab_3 = 202,
  AccountBankTab_4 = 203, AccountBankTab_5 = 204,
}
_G.Enum.ItemQuality = {
  Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4,
  Legendary = 5, Artifact = 6, Heirloom = 7, WoWToken = 8,
  Good = 2, Standard = 1,
}
_G.Enum.ItemClass = { Tradegoods = 7 }
_G.Enum.InventoryType = {
  IndexHeadType = 1, IndexNeckType = 2, IndexShoulderType = 3,
  IndexBodyType = 4, IndexChestType = 5, IndexWaistType = 6,
  IndexLegsType = 7, IndexFeetType = 8, IndexWristType = 9,
  IndexHandType = 10, IndexFingerType = 11, IndexTrinketType = 12,
  IndexWeaponType = 13, IndexShieldType = 14, IndexRangedType = 15,
  IndexCloakType = 16, Index2HweaponType = 17, IndexTabardType = 18,
  IndexRobeType = 20, IndexWeaponmainhandType = 21,
  IndexWeaponoffhandType = 22, IndexHoldableType = 23,
  IndexThrownType = 25, IndexRangedrightType = 26,
}

_G.C_Item = _G.C_Item or {}
if not _G.C_Item.GetItemSubClassInfo then
  _G.C_Item.GetItemSubClassInfo = function() return "MockSubClass" end
end

-- Dependencies
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
LoadBetterBagsModule("util/serialization.lua")
LoadBetterBagsModule("util/query.lua")

addon:GetModule("Context")
local events = addon:GetModule("Events")
events:Init()

local debug = StubBetterBagsModule("Debug")
debug.Log = function() end
debug.Inspect = function() end

local L = StubBetterBagsModule("Localization")
L.data = {}
L.locale = "enUS"
function L:G(key) return key end

-- Set up Constants
local const = StubBetterBagsModule("Constants")
const.BAG_KIND = { BACKPACK = 0, BANK = 1, UNDEFINED = -1 }
const.GLOW_INTENSITY_HALO_THRESHOLD = 60
const.GLOW_INTENSITY_MAX = 100
const.GLOW_INTENSITY_DEFAULT = 60
const.BAG_VIEW = { UNDEFINED = 0, SECTION_GRID = 2, SECTION_ALL_BAGS = 4 }
const.SECTION_SORT_TYPE = { ALPHABETICALLY = 1, SIZE_DESCENDING = 2, SIZE_ASCENDING = 3 }
const.ITEM_SORT_TYPE = { ALPHABETICALLY_THEN_QUALITY = 1, QUALITY_THEN_ALPHABETICALLY = 2, ITEM_LEVEL = 3, EXPANSION = 4 }
const.GRID_COMPACT_STYLE = { NONE = 0, SIMPLE = 1, COMPACT = 2 }
const.SEARCH_CATEGORY_GROUP_BY = { NONE = 0, TYPE = 1, SUBTYPE = 2, EXPANSION = 3 }
const.FORM_LAYOUT = { TWO_COLUMN = 1, STACKED = 2 }
const.BINDING_SCOPE = {}
const.BINDING_MAP = {}

-- Minimal defaults (same as database_spec.lua)
const.DATABASE_DEFAULTS = {
  profile = {
    firstTimeMenu = true, enabled = true, enableBagFading = false,
    showBagButton = true, enableBankBag = true, showBankTabs = false,
    debug = false, inBagSearch = true, categorySell = false,
    showKeybindWarning = true, enterToMakeCategory = true,
    upgradeIconProvider = 'None', theme = 'Default',
    showFullSectionNames = { [0] = false, [1] = false },
    showAllFreeSpace = { [0] = false, [1] = false },
    glowIntensity = { [0] = 60, [1] = 60 },
    newItems = {
      [0] = { markRecentItems = true, showNewItemFlash = false },
      [1] = { markRecentItems = true, showNewItemFlash = false },
    },
    stacking = {
      [0] = { mergeStacks = true, mergeUnstackable = true, unmergeAtShop = true, dontMergePartial = false, dontMergeTransmog = false },
      [1] = { mergeStacks = true, mergeUnstackable = true, unmergeAtShop = true, dontMergePartial = false, dontMergeTransmog = false },
    },
    itemLevel = {
      [0] = { enabled = true, color = true },
      [1] = { enabled = true, color = true },
    },
    itemLevelColor = {
      maxItemLevelByCharacter = {},
      colors = {
        low = { red = 0.62, green = 0.62, blue = 0.62, alpha = 1 },
        mid = { red = 1, green = 1, blue = 1, alpha = 1 },
        high = { red = 0, green = 0.55, blue = 0.87, alpha = 1 },
        max = { red = 1, green = 0.5, blue = 0, alpha = 1 },
      }
    },
    positions = { [0] = {}, [1] = {} },
    anchorPositions = { [0] = {}, [1] = {} },
    anchorState = { [0] = { enabled = false, shown = false }, [1] = { enabled = false, shown = false } },
    sectionSort = { [0] = { [1] = 1, [2] = 1, [3] = 1, [4] = 1 }, [1] = { [1] = 1, [2] = 1, [3] = 1, [4] = 1 } },
    itemSort = { [0] = { [1] = 2, [2] = 2, [3] = 2, [4] = 2 }, [1] = { [1] = 2, [2] = 2, [3] = 2, [4] = 2 } },
    customSectionSort = { [0] = {}, [1] = {} },
    size = {
      [1] = {
        [0] = { columnCount = 15, itemsPerRow = 15, scale = 100, width = 700, height = 500, opacity = 89, sizeMode = "content" },
        [1] = { columnCount = 1, itemsPerRow = 15, scale = 100, width = 700, height = 500, opacity = 89, sizeMode = "content" },
      },
      [2] = {
        [0] = { columnCount = 2, itemsPerRow = 7, scale = 100, width = 700, height = 500, opacity = 89, sizeMode = "content" },
        [1] = { columnCount = 2, itemsPerRow = 7, scale = 100, width = 700, height = 500, opacity = 89, sizeMode = "content" },
      },
      [3] = {
        [0] = { columnCount = 1, itemsPerRow = 15, scale = 100, width = 700, height = 500, opacity = 89, sizeMode = "content" },
        [1] = { columnCount = 5, itemsPerRow = 5, scale = 100, width = 700, height = 500, opacity = 89, sizeMode = "content" },
      },
      [4] = {
        [0] = { columnCount = 1, itemsPerRow = 15, scale = 100, width = 700, height = 500, opacity = 89, sizeMode = "content" },
        [1] = { columnCount = 1, itemsPerRow = 15, scale = 100, width = 700, height = 500, opacity = 89, sizeMode = "content" },
      },
    },
    views = { [0] = 2, [1] = 2 },
    previousViews = { [0] = 2, [1] = 2 },
    categoryOptions = {}, customCategoryFilters = {}, ephemeralCategoryFilters = {}, customCategoryIndex = {},
    categoryFilters = {
      [0] = { Type = true, Subtype = false, Expansion = false, TradeSkill = false, RecentItems = true, GearSet = true, EquipmentLocation = true },
      [1] = { Type = true, Subtype = false, Expansion = false, TradeSkill = false, RecentItems = true, GearSet = true, EquipmentLocation = true },
    },
    lockedItems = {},
    newItemTime = 300,
    groups = { [0] = { [1] = { id = 1, name = "Backpack", order = 1, kind = 0, isDefault = true } }, [1] = {} },
    groupCounter = { [0] = 1, [1] = 0 },
    categoryToGroup = { [0] = {}, [1] = {} },
    activeGroup = { [0] = 1, [1] = 1 },
    groupsEnabled = { [0] = true, [1] = true },
    __profileSystemMigrated = false,
  },
  char = {},
}

-- IMPORTANT: do NOT stub Migrate — we're testing it
ResetModuleStub("Database", "core/database.lua")
LoadBetterBagsModule("core/database.lua")
local DB = addon:GetModule("Database")

-- Initialize — Migrate() runs inside Init with valid defaults
DB:Init()

describe("Database Migration", function()

  -- ─── Bug: nil itemsPerRow crashes Migrate() ────────────────────────────────────

  describe("size fix migration (line 1021)", function()

    it("handles nil itemsPerRow gracefully (no crash)", function()
      DB.data.profile.size[const.BAG_VIEW.SECTION_GRID][const.BAG_KIND.BACKPACK].itemsPerRow = nil

      -- With the fix: (nil and ...) → short-circuits to nil (falsy), no crash
      DB:Migrate()
      -- nil itemsPerRow is left alone; AceDB defaults will fill it from DATABASE_DEFAULTS
      assert.is_nil(DB.data.profile.size[const.BAG_VIEW.SECTION_GRID][const.BAG_KIND.BACKPACK].itemsPerRow)
    end)

    it("handles itemsPerRow = 0 correctly (not affected by the bug)", function()
      DB.data.profile.size[const.BAG_VIEW.SECTION_GRID][const.BAG_KIND.BACKPACK].itemsPerRow = 0
      -- 0 < 1 is true, so it should be fixed to 7 without error
      DB:Migrate()
      assert.are.equal(7, DB.data.profile.size[const.BAG_VIEW.SECTION_GRID][const.BAG_KIND.BACKPACK].itemsPerRow)
    end)

    it("handles itemsPerRow = 35 correctly", function()
      DB.data.profile.size[const.BAG_VIEW.SECTION_GRID][const.BAG_KIND.BANK].itemsPerRow = 35
      DB:Migrate()
      assert.are.equal(7, DB.data.profile.size[const.BAG_VIEW.SECTION_GRID][const.BAG_KIND.BANK].itemsPerRow)
    end)

    it("leaves valid itemsPerRow alone", function()
      local original = DB.data.profile.size[const.BAG_VIEW.SECTION_ALL_BAGS][const.BAG_KIND.BACKPACK].itemsPerRow
      DB:Migrate()
      assert.are.equal(original, DB.data.profile.size[const.BAG_VIEW.SECTION_ALL_BAGS][const.BAG_KIND.BACKPACK].itemsPerRow)
    end)
  end)

  describe("retail bank view persistence", function()
    it("preserves SECTION_ALL_BAGS view state across migration in retail", function()
      addon.isRetail = true
      DB.data.profile.views[const.BAG_KIND.BANK] = const.BAG_VIEW.SECTION_ALL_BAGS
      DB:Migrate()
      assert.are.equal(const.BAG_VIEW.SECTION_ALL_BAGS, DB.data.profile.views[const.BAG_KIND.BANK])
    end)
  end)

  describe("extra glowy boolean -> glow intensity migration", function()
    it("maps the old per-kind boolean to an intensity (true->100, false->60) and drops the old field", function()
      DB.data.profile.extraGlowyButtons = { [const.BAG_KIND.BACKPACK] = true, [const.BAG_KIND.BANK] = false }
      DB:Migrate()
      assert.equal(100, DB.data.profile.glowIntensity[const.BAG_KIND.BACKPACK])
      assert.equal(60, DB.data.profile.glowIntensity[const.BAG_KIND.BANK])
      assert.is_nil(DB.data.profile.extraGlowyButtons)
    end)

    it("leaves glowIntensity at its default when there is no legacy field", function()
      DB.data.profile.extraGlowyButtons = nil
      DB.data.profile.glowIntensity = { [const.BAG_KIND.BACKPACK] = 85, [const.BAG_KIND.BANK] = 60 }
      DB:Migrate()
      assert.equal(85, DB.data.profile.glowIntensity[const.BAG_KIND.BACKPACK])
      assert.equal(60, DB.data.profile.glowIntensity[const.BAG_KIND.BANK])
    end)
  end)

  -- The Moonlight themes were first released as MoonlightDark and MoonlightParchment; a
  -- profile that chose one keeps it under its new key.
  describe("renamed Moonlight theme keys", function()
    it("moves a saved Moonlight theme to its new key", function()
      for old, new in pairs({ MoonlightDark = "Dark", MoonlightParchment = "Parchment" }) do
        DB.data.profile.theme = old
        DB:Migrate()
        assert.are.equal(new, DB.data.profile.theme, old)
      end
    end)

    it("leaves every other saved theme alone", function()
      for _, key in ipairs({ "Default", "SimpleDark", "Dark", "elvui", "SomeoneElsesTheme" }) do
        DB.data.profile.theme = key
        DB:Migrate()
        assert.are.equal(key, DB.data.profile.theme)
      end
    end)
  end)

  -- Section collapsing was removed; its saved state is dropped from every profile.
  describe("removed section collapse state", function()
    it("drops the saved collapsedSections table", function()
      DB.data.profile.collapsedSections = { [const.BAG_KIND.BACKPACK] = { Junk = true }, [const.BAG_KIND.BANK] = {} }
      DB:Migrate()
      assert.is_nil(DB.data.profile.collapsedSections)
    end)
  end)

  describe("default Warbank group gating (no warbank on Forever)", function()
    local savedHasWarbank

    before_each(function()
      savedHasWarbank = addon.hasWarbank
      -- Reset the bank groups so Migrate() re-seeds the defaults from scratch.
      DB.data.profile.groups[const.BAG_KIND.BANK] = {}
      DB.data.profile.groupCounter[const.BAG_KIND.BANK] = 0
      DB.data.profile.activeGroup[const.BAG_KIND.BANK] = nil
    end)

    after_each(function()
      addon.hasWarbank = savedHasWarbank
    end)

    local function defaultGroupOfType(bankType)
      for _, g in pairs(DB.data.profile.groups[const.BAG_KIND.BANK]) do
        if g.isDefault and g.bankType == bankType then return true end
      end
      return false
    end

    it("creates a default Warbank group when the client has a warbank", function()
      addon.hasWarbank = true
      DB:Migrate()
      assert.is_true(defaultGroupOfType(Enum.BankType.Account))
      assert.is_true(defaultGroupOfType(Enum.BankType.Character))
    end)

    it("creates only the Character bank group when the client has no warbank (Forever)", function()
      addon.hasWarbank = false
      DB:Migrate()
      assert.is_false(defaultGroupOfType(Enum.BankType.Account))
      assert.is_true(defaultGroupOfType(Enum.BankType.Character))
    end)
  end)

  -- Issue #1107: Migrate runs on every load, and used to drop every pin whose category is
  -- neither custom nor persisted-ephemeral: every built-in category ("Armor", "Junk").
  describe("pinned categories across a load", function()
    it("keeps the pinned order of built-in and custom categories", function()
      local profile = DB.data.profile
      profile.customCategoryFilters = { Midnight = { name = "Midnight", itemList = {} } }
      profile.ephemeralCategoryFilters = {}
      profile.customSectionSort = {
        [const.BAG_KIND.BACKPACK] = { Armor = 1, Junk = 2, Midnight = 3 },
        [const.BAG_KIND.BANK] = { Reagent = 1 },
      }
      DB:Migrate()
      assert.are.same({ Armor = 1, Junk = 2, Midnight = 3 }, profile.customSectionSort[const.BAG_KIND.BACKPACK])
      assert.are.same({ Reagent = 1 }, profile.customSectionSort[const.BAG_KIND.BANK])
    end)
  end)

  -- Issue #183: GetCategory no longer repeats a subtype equal to its type, so "Quest - Quest"
  -- is now "Quest". Settings saved under the old name follow the category to its new name.
  describe("category names that repeated their item type", function()
    local profile

    before_each(function()
      profile = DB.data.profile
      profile.categoryOptions = {}
      profile.customCategoryFilters = {}
      profile.ephemeralCategoryFilters = {}
      profile.categoryToGroup = { [const.BAG_KIND.BACKPACK] = {}, [const.BAG_KIND.BANK] = {} }
      profile.customSectionSort = { [const.BAG_KIND.BACKPACK] = {}, [const.BAG_KIND.BANK] = {} }
    end)

    it("moves the pinned order to the new name", function()
      profile.customSectionSort[const.BAG_KIND.BACKPACK] = { ["Quest - Quest"] = 4, Armor = 1 }
      profile.customSectionSort[const.BAG_KIND.BANK] = { ["Key - Key"] = 2 }
      DB:Migrate()
      assert.are.same({ Quest = 4, Armor = 1 }, profile.customSectionSort[const.BAG_KIND.BACKPACK])
      assert.are.same({ Key = 2 }, profile.customSectionSort[const.BAG_KIND.BANK])
    end)

    it("moves group assignments, including the per-bank-type ones", function()
      profile.categoryToGroup[const.BAG_KIND.BACKPACK]["Quest - Quest"] = 2
      profile.categoryToGroup[const.BAG_KIND.BANK][Enum.BankType.Character] = { ["Key - Key - Classic"] = 3 }
      DB:Migrate()
      assert.are.equal(2, profile.categoryToGroup[const.BAG_KIND.BACKPACK]["Quest"])
      assert.is_nil(profile.categoryToGroup[const.BAG_KIND.BACKPACK]["Quest - Quest"])
      local character = profile.categoryToGroup[const.BAG_KIND.BANK][Enum.BankType.Character]
      assert.are.equal(3, character["Key - Classic"])
      assert.is_nil(character["Key - Key - Classic"])
    end)

    it("skips legacy group assignments saved outside the bag kinds", function()
      -- Profiles from before groups were split by bag kind keep name = group entries at the
      -- top level, next to the per-kind tables; nothing reads them.
      profile.categoryToGroup["Quest - Quest"] = 3
      assert.has_no.errors(function() DB:Migrate() end)
      assert.are.equal(3, profile.categoryToGroup["Quest - Quest"])
    end)

    it("keeps a setting already saved under the new name", function()
      profile.customSectionSort[const.BAG_KIND.BACKPACK] = { Quest = 1, ["Quest - Quest"] = 2 }
      DB:Migrate()
      assert.are.same({ Quest = 1 }, profile.customSectionSort[const.BAG_KIND.BACKPACK])
    end)

    it("leaves other names and custom categories alone", function()
      profile.customSectionSort[const.BAG_KIND.BACKPACK] = { ["Weapon - One-Handed Swords"] = 1, ["Loot - Loot"] = 2 }
      profile.customCategoryFilters["Loot - Loot"] = { name = "Loot - Loot", itemList = {} }
      profile.ephemeralCategoryFilters["Gear - Gear"] = { name = "Gear - Gear", dynamic = true }
      profile.categoryToGroup[const.BAG_KIND.BACKPACK]["Gear - Gear"] = 2
      DB:Migrate()
      assert.are.same({ ["Weapon - One-Handed Swords"] = 1, ["Loot - Loot"] = 2 },
        profile.customSectionSort[const.BAG_KIND.BACKPACK])
      assert.are.equal(2, profile.categoryToGroup[const.BAG_KIND.BACKPACK]["Gear - Gear"])
      assert.is_nil(profile.categoryToGroup[const.BAG_KIND.BACKPACK]["Gear"])
    end)
  end)

  -- Categories are one kind (a rule, items placed by hand, or both), defined once and applied to each
  -- bag (category-lifecycle.md §6). Every load (and every import) brings saved categories to that
  -- shape; the cases come from real profiles (test.lua).
  -- AND binds tighter than OR (docs/vendor-compat.md, "Decisions"). Saved rules were written when
  -- they had one precedence and grouped left to right; each profile's are rewritten once to keep
  -- their meaning, and the profile records it (searchRuleVersion).
  describe("search rules written before AND bound tighter than OR", function()
    local profile, QueryParser

    local function rule(name)
      local f = profile.customCategoryFilters[name]
      return f.searchCategory and f.searchCategory.query
    end

    before_each(function()
      QueryParser = addon:GetModule("QueryParser")
      profile = DB.data.profile
      profile.searchRuleVersion = nil
      profile.customCategoryFilters = {
        Mixed = { name = "Mixed", itemList = {}, searchCategory = { query = "type = armor OR type = weapon AND ilvl > 200" } },
        Plain = { name = "Plain", itemList = {}, searchCategory = { query = "tradeskill AND (exp = tww)" } },
        Listed = { name = "Listed", itemList = { [5] = true } },
      }
      profile.customCategoryIndex = { [5] = "Listed" }
    end)

    it("rewrites a rule that mixes them, keeping its meaning, and leaves the others alone", function()
      DB:Migrate()
      assert.are.equal("(type = armor OR type = weapon) AND ilvl > 200", rule("Mixed"))
      assert.are.equal("tradeskill AND (exp = tww)", rule("Plain"))
      assert.is_nil(rule("Listed"))
      assert.are.equal(QueryParser.VERSION, profile.searchRuleVersion)
    end)

    it("does it once: a rule written afterwards keeps the precedence it was written for", function()
      DB:Migrate()
      profile.customCategoryFilters.Mixed.searchCategory.query = "a OR b AND c"
      DB:Migrate()
      assert.are.equal("a OR b AND c", rule("Mixed"))
    end)

    it("leaves a profile already on the current version alone", function()
      profile.searchRuleVersion = QueryParser.VERSION
      DB:Migrate()
      assert.are.equal("type = armor OR type = weapon AND ilvl > 200", rule("Mixed"))
    end)

    -- A new or reset profile has no old rules; the player may write some before the next load.
    it("marks a new profile and a reset one as current", function()
      local start = DB:GetCurrentProfileName()
      DB:CreateProfile("Fresh Rules")
      assert.are.equal(QueryParser.VERSION, DB.data.profile.searchRuleVersion)
      DB.data.profile.searchRuleVersion = nil
      DB:ResetCurrentProfile()
      assert.are.equal(QueryParser.VERSION, DB.data.profile.searchRuleVersion)
      DB:SwitchToProfile(start)
      DB.data:DeleteProfile("Fresh Rules", true)
    end)

    it("rewrites the rules of an old profile copied into this one", function()
      DB.data.sv.profiles["Old Rules"] = {
        customCategoryFilters = { Old = { name = "Old", itemList = {}, searchCategory = { query = "a OR b AND c" } } },
      }
      profile.searchRuleVersion = QueryParser.VERSION
      DB:CopyFromProfile("Old Rules")
      profile = DB.data.profile
      assert.are.equal("(a OR b) AND c", rule("Old"))
      assert.are.equal(QueryParser.VERSION, profile.searchRuleVersion)
      DB.data.sv.profiles["Old Rules"] = nil
    end)
  end)

  describe("unified categories", function()
    local profile

    before_each(function()
      const.BAG_KIND.GUILD = 2
      profile = DB.data.profile
      profile.customCategoryFilters = {}
      profile.ephemeralCategoryFilters = {}
      profile.customCategoryIndex = {}
    end)

    after_each(function()
      const.BAG_KIND.GUILD = nil
    end)

    it("applies every category to every bag the same way: a bag it does not name, it is used in", function()
      profile.customCategoryFilters = {
        Mats = { name = "Mats", itemList = {}, enabled = { [0] = true, [1] = false } },
        Gems = { name = "Gems", itemList = {} },
        Old = { name = "Old", itemList = {}, enabled = false },
      }
      profile.ephemeralCategoryFilters = { Openable = { name = "Openable", dynamic = true, enabled = { [0] = false } } }
      DB:Migrate()
      assert.are.same({ [0] = true, [1] = false, [2] = true }, profile.customCategoryFilters.Mats.enabled)
      assert.are.same({ [0] = true, [1] = true, [2] = true }, profile.customCategoryFilters.Gems.enabled)
      assert.are.same({ [0] = false, [1] = false, [2] = false }, profile.customCategoryFilters.Old.enabled,
        "a category saved off everywhere stays off everywhere")
      assert.are.same({ [0] = false, [1] = true, [2] = true }, profile.ephemeralCategoryFilters.Openable.enabled)
    end)

    it("gives every category an item list, and no rule for an empty search", function()
      profile.customCategoryFilters = {
        Test1 = { name = "Test1" },
        Blank = { name = "Blank", itemList = {}, searchCategory = { query = "   " } },
        Kept = { name = "Kept", itemList = {}, searchCategory = { query = "type = armor" } },
      }
      DB:Migrate()
      assert.are.same({}, profile.customCategoryFilters.Test1.itemList)
      assert.is_true(profile.customCategoryFilters.Test1.save, "a saved category says so")
      assert.is_nil(profile.customCategoryFilters.Blank.searchCategory)
      assert.are.same({ query = "type = armor" }, profile.customCategoryFilters.Kept.searchCategory)
    end)

    it("makes group by the category's own, from the rule or a clause left in its search", function()
      profile.customCategoryFilters = {
        Midnight = { name = "Midnight", itemList = {}, searchCategory = { query = "exp = mid", groupBy = 1 } },
        Clause = { name = "Clause", itemList = {}, searchCategory = { query = "type = armor group by Subtype" } },
        Only = { name = "Only", itemList = { [5] = true }, searchCategory = { query = "group by expansion" } },
        Word = { name = "Word", itemList = {}, searchCategory = { query = "name = regroup by type" } },
      }
      DB:Migrate()
      local f = profile.customCategoryFilters
      assert.are.equal(1, f.Midnight.groupBy)
      assert.are.same({ query = "exp = mid" }, f.Midnight.searchCategory)
      assert.are.equal(2, f.Clause.groupBy)
      assert.are.same({ query = "type = armor" }, f.Clause.searchCategory)
      assert.are.equal(3, f.Only.groupBy, "grouping items placed by hand, with no search")
      assert.is_nil(f.Only.searchCategory)
      assert.is_nil(f.Word.groupBy, "a word ending in group is not a clause")
      assert.are.same({ query = "name = regroup by type" }, f.Word.searchCategory)
    end)

    it("files every listed item where its list says, as the real profiles needed", function()
      profile.customCategoryFilters = {
        Midnight = { name = "Midnight", itemList = { [202395] = true }, priority = 2 },
        Test = { name = "Test", itemList = { [58259] = true } },
      }
      -- Default: Midnight listed 202395 with no index entry; Not Max Level: 58259 indexed to "ddd", gone.
      profile.customCategoryIndex = { [58259] = "ddd", [777] = "Test" }
      DB:Migrate()
      assert.are.same({ [202395] = "Midnight", [58259] = "Test" }, profile.customCategoryIndex)
    end)

    it("keeps an item listed twice in one category: the one its index names, else the lowest priority", function()
      profile.customCategoryFilters = {
        A = { name = "A", itemList = { [1] = true, [2] = true, [3] = true }, priority = 5 },
        B = { name = "B", itemList = { [1] = true, [2] = true, [3] = true }, priority = 2 },
        C = { name = "C", itemList = { [3] = true }, priority = 2 },
      }
      profile.customCategoryIndex = { [1] = "A" }
      DB:Migrate()
      local f = profile.customCategoryFilters
      assert.are.same({ [1] = "A", [2] = "B", [3] = "B" }, profile.customCategoryIndex,
        "the index's, else the lowest priority, else the first name")
      assert.are.same({ [1] = true }, f.A.itemList)
      assert.are.same({ [2] = true, [3] = true }, f.B.itemList)
      assert.are.same({}, f.C.itemList)
    end)

    it("drops what hiding sections saved: no section is hidden any more", function()
      profile.categoryOptions = { Junk = { shown = false } }
      DB:Migrate()
      assert.is_nil(profile.categoryOptions)
    end)

    it("changes nothing a second time", function()
      profile.customCategoryFilters = {
        Midnight = { name = "Midnight", itemList = { [202395] = true }, searchCategory = { query = "x group by type" } },
      }
      DB:Migrate()
      local first = DB:GetAllItemCategories().Midnight
      local copy = { enabled = {}, itemList = {} }
      for k, v in pairs(first.enabled) do copy.enabled[k] = v end
      DB:Migrate()
      assert.are.same(copy.enabled, first.enabled)
      assert.are.same({ query = "x" }, first.searchCategory)
      assert.are.equal(1, first.groupBy)
    end)
  end)
end)
