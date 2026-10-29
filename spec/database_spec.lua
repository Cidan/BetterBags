-- database_spec.lua -- Unit tests for core/database.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Set up version flags
addon.isRetail = true
addon.isClassic = false
addon.isBCC = false
addon.isCata = false
addon.isMists = false
addon.isAnniversary = false
addon.isMidnight = false
addon.tocVersion = 110000

-- Required globals for database defaults and migration
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

-- C_Item mock for TRADESKILL_MAP
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

StubBetterBagsModule("Debug")
local debug = addon:GetModule("Debug")
debug.Log = function() end
debug.Inspect = function() end

local L = StubBetterBagsModule("Localization")
L.data = {}
L.locale = "enUS"
function L:G(key) return key end

-- Set up Constants module
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

-- Minimal DATABASE_DEFAULTS
const.DATABASE_DEFAULTS = {
  profile = {
    firstTimeMenu = true,
    enabled = true,
    enableBagFading = false,
    animateItemMovement = false,
    clampBagsToScreen = false,
    nextEnabled = false,
    nextChain = "apart",
    nextTabOrder = {},
    nextIconScale = 100,
    nextBagScale = 100,
    nextSize = "full",
    nextSmallPlaces = {},
    nextSmallSizes = {},
    nextSmallChain = "apart",
    nextTheme = "Default",
    nextAnimation = { sparkles = true, shimmer = true, titleCloud = true, ribbon = true, braid = true, ornaments = true,
      glitch = true, rain = true, shatter = true, snow = true, smoke = true, bats = true, beam = true },
    nextCurrencies = {},
    nextCurrency = { capBars = false, gains = true, hideEmpty = true, itemsEverywhere = true, layout = "row",
      scale = 100, background = true, hideInCombat = false, growX = "left", growY = "down" },
    nextCurrencyTracker = { out = false },
    showBagButton = true,
    enableBankBag = true,
    showBankTabs = false,
    showGuildBankTabs = false,
    debug = false,
    inBagSearch = true,
    categorySell = false,
    showKeybindWarning = true,
    enterToMakeCategory = true,
    upgradeIconProvider = 'None',
    theme = 'Default',
    showFullSectionNames = { [0] = false, [1] = false },
    showAllFreeSpace = { [0] = false, [1] = false },
    preserveItemGaps = { [0] = true, [1] = true },
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
    anchorState = {
      [0] = { enabled = false, shown = false },
      [1] = { enabled = false, shown = false },
    },
    sectionSort = {
      [0] = { [1] = 1, [2] = 1, [3] = 1, [4] = 1 },
      [1] = { [1] = 1, [2] = 1, [3] = 1, [4] = 1 },
    },
    itemSort = {
      [0] = { [1] = 2, [2] = 2, [3] = 2, [4] = 2 },
      [1] = { [1] = 2, [2] = 2, [3] = 2, [4] = 2 },
    },
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
    customCategoryFilters = {},
    ephemeralCategoryFilters = {},
    customCategoryIndex = {},
    categoryFilters = {
      [0] = { Type = true, Subtype = false, Expansion = false, TradeSkill = false, RecentItems = true, GearSet = true, EquipmentLocation = true },
      [1] = { Type = true, Subtype = false, Expansion = false, TradeSkill = false, RecentItems = true, GearSet = true, EquipmentLocation = true },
    },
    lockedItems = {},
    newItemTime = 300,
    groups = {
      [0] = { [1] = { id = 1, name = "Backpack", order = 1, kind = 0, isDefault = true } },
      [1] = {},
    },
    groupCounter = { [0] = 1, [1] = 0 },
    categoryToGroup = { [0] = {}, [1] = {} },
    activeGroup = { [0] = 1, [1] = 1 },
    groupsEnabled = { [0] = true, [1] = true },
    __profileSystemMigrated = false,
  },
  global = {
    changelog = { lastSeen = 0, autoOpen = true },
  },
  char = {},
}

-- Un-stub Database if it was previously stubbed by another spec (e.g. categories_spec)
ResetModuleStub("Database", "core/database.lua")

LoadBetterBagsModule("core/database.lua")
local DB = addon:GetModule("Database")

-- Stub Migrate to simplify test setup (we test migration behavior separately)
DB.Migrate = function() end

-- Initialize the database with our controlled defaults
DB:Init()

describe("Database", function()

  before_each(function()
    -- Get a fresh profile by resetting
    DB.data:ResetProfile(false, true)
    -- Set up known state for tests
    DB.data.profile.firstTimeMenu = false
  end)

  -- ─── Basic getters/setters ─────────────────────────────────────────────────────

  describe("basic booleans", function()

    it("GetShowBagButton / SetShowBagButton", function()
      DB:SetShowBagButton(false)
      assert.is_false(DB:GetShowBagButton())
      DB:SetShowBagButton(true)
      assert.is_true(DB:GetShowBagButton())
    end)

    it("GetEnableBankBag / SetEnableBankBag", function()
      DB:SetEnableBankBag(false)
      assert.is_false(DB:GetEnableBankBag())
    end)

    it("GetShowGuildBankTabs / SetShowGuildBankTabs, off until turned on", function()
      assert.is_false(DB:GetShowGuildBankTabs())
      DB:SetShowGuildBankTabs(true)
      assert.is_true(DB:GetShowGuildBankTabs())
      DB:SetShowGuildBankTabs(false)
      assert.is_false(DB:GetShowGuildBankTabs())
    end)

    it("GetShowBankTabs / SetShowBankTabs", function()
      DB:SetShowBankTabs(true)
      assert.is_true(DB:GetShowBankTabs())
    end)

    it("GetNextEnabled / SetNextEnabled, off until turned on", function()
      assert.is_false(DB:GetNextEnabled())
      DB:SetNextEnabled(true)
      assert.is_true(DB:GetNextEnabled())
      DB:SetNextEnabled(false)
      assert.is_false(DB:GetNextEnabled())
    end)

    -- Asked: "if this is a net new install of the addon, i now want to default to the next
    -- experience". A new install has no saved variables yet: AceDB creates BetterBagsDB only when it
    -- is nil (AceDB-3.0 New), and nothing reads it before DB:Init. The setting's default stays off,
    -- so a profile that never turned Next on (AceDB saves only what differs from the defaults) keeps
    -- the classic bags (next.md §1).
    describe("new installs", function()
      local savedData, savedVariables
      before_each(function()
        savedData, savedVariables = DB.data, _G.BetterBagsDB
      end)
      after_each(function()
        DB.data, _G.BetterBagsDB = savedData, savedVariables
      end)

      it("starts a new install with BetterBags Next, and saves it", function()
        _G.BetterBagsDB = nil
        DB:Init()
        assert.is_true(DB:GetNextEnabled())
        -- AceDB copies each default into the profile when it is made (copyDefaults) and removes the
        -- values equal to their default at logout (removeDefaults): true differs, so it is saved.
        assert.is_true(rawget(_G.BetterBagsDB.profiles.Default, "nextEnabled"), "saved, so the next load keeps it")
      end)

      it("is not new on its second load", function()
        _G.BetterBagsDB = nil
        DB:Init()
        DB:Init()
        assert.is_true(DB:GetNextEnabled())
        DB:SetNextEnabled(false)
        DB:Init()
        assert.is_false(DB:GetNextEnabled(), "the player's choice from then on")
      end)

      it("keeps the classic bags on an install from before that never turned Next on", function()
        _G.BetterBagsDB = { profileKeys = {}, profiles = { Default = { firstTimeMenu = false } } }
        DB:Init()
        assert.is_false(DB:GetNextEnabled())
        assert.is_false(rawget(_G.BetterBagsDB.profiles.Default, "nextEnabled"), "only the default, removed at logout")
      end)

      it("keeps what an existing install chose", function()
        _G.BetterBagsDB = { profiles = { Default = { nextEnabled = true } } }
        DB:Init()
        assert.is_true(DB:GetNextEnabled())
        _G.BetterBagsDB = { profiles = { Default = { nextEnabled = false } } }
        DB:Init()
        assert.is_false(DB:GetNextEnabled())
      end)

      -- Every character shares the Default profile (AceDB:New with true), so a character new to an
      -- existing install is no new install: it has the account's bags.
      it("gives a character new to an existing install the account's bags", function()
        _G.BetterBagsDB = { profileKeys = { ["Someone Else - Elsewhere"] = "Default" }, profiles = { Default = {} } }
        DB:Init()
        assert.is_false(DB:GetNextEnabled())
        _G.BetterBagsDB = { profileKeys = { ["Someone Else - Elsewhere"] = "Default" },
          profiles = { Default = { nextEnabled = true } } }
        DB:Init()
        assert.is_true(DB:GetNextEnabled())
      end)
    end)

    -- How BetterBags Next's bags sit (next.md §12): apart on opposite edges, or chained on one.
    it("GetNextChain / SetNextChain, apart until chained, and nothing but a layout", function()
      assert.are.equal("apart", DB:GetNextChain())
      for _, layout in ipairs({ "left", "right", "apart" }) do
        DB:SetNextChain(layout)
        assert.are.equal(layout, DB:GetNextChain())
      end
      assert.has_error(function() DB:SetNextChain("middle") end)
      assert.are.equal("apart", DB:GetNextChain())
    end)

    -- BetterBags Next's size (docs/next-small-mode.md): full-height panels until switched to small,
    -- movable ones.
    -- The order the player moved each Next tab rail's tabs to (docs/next-batch-2.md §5).
    it("GetNextTabOrder / SetNextTabOrder, per rail, none until moved, kept as a copy", function()
      assert.are.same({}, DB:GetNextTabOrder("backpack"))
      local ids = { 2, 1, 0 }
      DB:SetNextTabOrder("backpack", ids)
      ids[1] = 9
      assert.are.same({ 2, 1, 0 }, DB:GetNextTabOrder("backpack"))
      assert.are.same({}, DB:GetNextTabOrder("bank"))
      assert.are.same({ backpack = { 2, 1, 0 } }, DB.data.profile.nextTabOrder)
    end)

    -- BetterBags Next's Size tab (docs/next-appearance-size.md): percentages, whole, kept in 50 to 150.
    for _, case in ipairs({ { "GetNextIconScale", "SetNextIconScale", "nextIconScale" },
      { "GetNextBagScale", "SetNextBagScale", "nextBagScale" } }) do
      it(case[1] .. " / " .. case[2] .. ", 100 until set, whole and kept in 50 to 150", function()
        assert.are.equal(100, DB[case[1]](DB))
        DB[case[2]](DB, 120)
        assert.are.equal(120, DB[case[1]](DB))
        assert.are.equal(120, DB.data.profile[case[3]])
        DB[case[2]](DB, 87.6)
        assert.are.equal(88, DB[case[1]](DB))
        DB[case[2]](DB, 10)
        assert.are.equal(50, DB[case[1]](DB))
        DB[case[2]](DB, 400)
        assert.are.equal(150, DB[case[1]](DB))
        DB[case[2]](DB, "nonsense")
        assert.are.equal(100, DB[case[1]](DB))
      end)
    end

    it("GetNextSize / SetNextSize, full until switched, and nothing but a size", function()
      assert.are.equal("full", DB:GetNextSize())
      DB:SetNextSize("small")
      assert.are.equal("small", DB:GetNextSize())
      assert.has_error(function() DB:SetNextSize("tiny") end)
      assert.are.equal("small", DB:GetNextSize())
      DB:SetNextSize("full")
      assert.are.equal("full", DB:GetNextSize())
    end)

    -- Each kind of bag keeps where its small panel was left: its top left, in UIParent's units.
    it("GetNextSmallPlace / SetNextSmallPlace, per kind, nothing until moved", function()
      assert.is_nil(DB:GetNextSmallPlace(0))
      DB:SetNextSmallPlace(0, 1200.5, 900)
      DB:SetNextSmallPlace(1, 40, 800)
      assert.are.same({ 1200.5, 900 }, { DB:GetNextSmallPlace(0) })
      assert.are.same({ 40, 800 }, { DB:GetNextSmallPlace(1) })
      assert.is_nil(DB:GetNextSmallPlace(2))
    end)

    -- And the size the player gave it (next.md §14g): nothing until resized, cleared by a reset.
    it("GetNextSmallSize / SetNextSmallSize, per kind, nothing until resized, cleared with nothing", function()
      assert.is_nil(DB:GetNextSmallSize(0))
      DB:SetNextSmallSize(0, 640.5, 500)
      DB:SetNextSmallSize(1, 380, 720)
      assert.are.same({ 640.5, 500 }, { DB:GetNextSmallSize(0) })
      assert.are.same({ 380, 720 }, { DB:GetNextSmallSize(1) })
      DB:SetNextSmallSize(0, nil, nil)
      assert.is_nil(DB:GetNextSmallSize(0))
      assert.is_nil(DB.data.profile.nextSmallSizes[0], "nothing left behind")
      assert.are.same({ 380, 720 }, { DB:GetNextSmallSize(1) })
    end)

    -- Which small bag is the anchor of a chained pair (docs/next-small-mode.md): the one the other
    -- was dropped beside.
    it("GetNextSmallChain / SetNextSmallChain, apart until chained, and nothing but a layout", function()
      assert.are.equal("apart", DB:GetNextSmallChain())
      for _, layout in ipairs({ "backpack", "companion", "apart" }) do
        DB:SetNextSmallChain(layout)
        assert.are.equal(layout, DB:GetNextSmallChain())
      end
      assert.has_error(function() DB:SetNextSmallChain("left") end)
      assert.are.equal("apart", DB:GetNextSmallChain())
    end)

    -- BetterBags Next's theme (next-themes.md): the Default theme until another is picked.
    it("GetNextTheme / SetNextTheme, Default until another is picked", function()
      assert.are.equal("Default", DB:GetNextTheme())
      DB:SetNextTheme("Ember")
      assert.are.equal("Ember", DB:GetNextTheme())
    end)

    -- BetterBags Next's Animation switches (Appearance > Animation, next-themes.md §20): every effect on until the
    -- player turns it off, on any theme; nothing but an effect.
    it("GetNextAnimation / SetNextAnimation, every effect on until turned off, and nothing but an effect", function()
      for _, name in ipairs({ "sparkles", "shimmer", "titleCloud", "ribbon", "braid", "ornaments", "glitch", "rain",
        "shatter", "snow", "smoke", "bats", "beam" }) do
        assert.is_true(DB:GetNextAnimation(name), name)
        DB:SetNextAnimation(name, false)
        assert.is_false(DB:GetNextAnimation(name), name)
        DB:SetNextAnimation(name, true)
        assert.is_true(DB:GetNextAnimation(name), name)
      end
      assert.has_error(function() DB:GetNextAnimation("cascade") end)
      assert.has_error(function() DB:SetNextAnimation("cascade", false) end)
    end)

    -- BetterBags Next's currencies (currency.md): what is tracked, in order, per profile; how they show;
    -- where the tracker dragged out of the backpack was left.
    describe("currencies", function()
      it("tracks nothing until something is tracked, and keeps a copy of the list it is given", function()
        assert.are.same({}, DB:GetNextCurrencies())
        local list = { { kind = "currency", id = 3008 }, { kind = "item", id = 210796 } }
        DB:SetNextCurrencies(list)
        table.insert(list, { kind = "item", id = 1 })
        list[1].id = 9
        assert.are.same({ { kind = "currency", id = 3008 }, { kind = "item", id = 210796 } }, DB:GetNextCurrencies())
      end)

      it("hands out a copy, so a caller cannot change what is saved", function()
        DB:SetNextCurrencies({ { kind = "currency", id = 3008 } })
        local got = DB:GetNextCurrencies()
        got[1].id = 1
        table.insert(got, { kind = "item", id = 2 })
        assert.are.same({ { kind = "currency", id = 3008 } }, DB:GetNextCurrencies())
      end)

      it("refuses an entry that is no currency or item", function()
        assert.has_error(function() DB:SetNextCurrencies({ { kind = "spell", id = 1 } }) end)
        assert.has_error(function() DB:SetNextCurrencies({ { kind = "item" } }) end)
      end)

      it("shows gains, hides what you have none of, and counts items everywhere until told; no cap bars", function()
          for _, name in ipairs({ "gains", "hideEmpty", "itemsEverywhere", "background" }) do
            assert.is_true(DB:GetNextCurrencyOption(name), name)
            DB:SetNextCurrencyOption(name, false)
            assert.is_false(DB:GetNextCurrencyOption(name), name)
          end
          assert.is_false(DB:GetNextCurrencyOption("capBars"))
          DB:SetNextCurrencyOption("capBars", true)
          assert.is_true(DB:GetNextCurrencyOption("capBars"))
          assert.is_false(DB:GetNextCurrencyOption("hideInCombat"))
          assert.are.equal("row", DB:GetNextCurrencyOption("layout"))
          assert.are.equal(100, DB:GetNextCurrencyOption("scale"))
          DB:SetNextCurrencyOption("layout", "list")
          assert.are.equal("list", DB:GetNextCurrencyOption("layout"))
          assert.has_error(function() DB:GetNextCurrencyOption("sparkles") end)
          assert.has_error(function() DB:SetNextCurrencyOption("sparkles", true) end)
          assert.has_error(function() DB:SetNextCurrencyOption("layout", "grid") end)
          assert.are.equal("left", DB:GetNextCurrencyOption("growX"))
          assert.are.equal("down", DB:GetNextCurrencyOption("growY"))
          DB:SetNextCurrencyOption("growX", "right")
          DB:SetNextCurrencyOption("growY", "up")
          assert.are.equal("right", DB:GetNextCurrencyOption("growX"))
          assert.are.equal("up", DB:GetNextCurrencyOption("growY"))
          assert.has_error(function() DB:SetNextCurrencyOption("growX", "up") end)
          assert.has_error(function() DB:SetNextCurrencyOption("growY", "left") end)
        end)

      it("keeps whether the tracker is out and where it was left", function()
        local out, x, y = DB:GetNextCurrencyTracker()
        assert.is_false(out)
        assert.is_nil(x)
        assert.is_nil(y)
        DB:SetNextCurrencyTracker(true, 120, 340)
        out, x, y = DB:GetNextCurrencyTracker()
        assert.is_true(out)
        assert.are.equal(120, x)
        assert.are.equal(340, y)
        DB:SetNextCurrencyTracker(false)
        out, x, y = DB:GetNextCurrencyTracker()
        assert.is_false(out)
        assert.are.equal(120, x, "put away, it remembers where it was")
        assert.are.equal(340, y)
      end)
    end)

    it("GetClampBagsToScreen / SetClampBagsToScreen, off until turned on", function()
      assert.is_false(DB:GetClampBagsToScreen())
      DB:SetClampBagsToScreen(true)
      assert.is_true(DB:GetClampBagsToScreen())
      DB:SetClampBagsToScreen(false)
      assert.is_false(DB:GetClampBagsToScreen())
    end)

    it("GetAnimateItemMovement / SetAnimateItemMovement, off until turned on", function()
      assert.is_false(DB:GetAnimateItemMovement())
      DB:SetAnimateItemMovement(true)
      assert.is_true(DB:GetAnimateItemMovement())
      DB:SetAnimateItemMovement(false)
      assert.is_false(DB:GetAnimateItemMovement())
    end)

    it("GetEnableBagFading / SetEnableBagFading", function()
      DB:SetEnableBagFading(true)
      assert.is_true(DB:GetEnableBagFading())
    end)

    it("GetDebugMode / SetDebugMode", function()
      DB:SetDebugMode(true)
      assert.is_true(DB:GetDebugMode())
    end)

    it("GetInBagSearch / SetInBagSearch", function()
      DB:SetInBagSearch(false)
      assert.is_false(DB:GetInBagSearch())
    end)

    it("GetCategorySell / SetCategorySell", function()
      DB:SetCategorySell(true)
      assert.is_true(DB:GetCategorySell())
    end)

    it("GetShowKeybindWarning / SetShowKeybindWarning", function()
      DB:SetShowKeybindWarning(false)
      assert.is_false(DB:GetShowKeybindWarning())
    end)

    it("GetEnterToMakeCategory / SetEnterToMakeCategory", function()
      DB:SetEnterToMakeCategory(false)
      assert.is_false(DB:GetEnterToMakeCategory())
    end)
  end)

  -- At PLAYER_LOGOUT AceDB strips every setting still at its default from the profile, right after
  -- it fires OnDatabaseShutdown (initialization.md §7).
  describe("logging out", function()
    local savedData, savedVariables
    before_each(function()
      savedData, savedVariables = DB.data, _G.BetterBagsDB
    end)
    after_each(function()
      DB.data, _G.BetterBagsDB = savedData, savedVariables
      addon.loggingOut = false
    end)

    -- AceDB's handler of PLAYER_LOGOUT, for this database alone.
    local function logout()
      local aceDB = LibStub("AceDB-3.0")
      local registry = aceDB.db_registry
      aceDB.db_registry = { [DB.data] = true }
      local ok, err = pcall(aceDB.frame:GetScript("OnEvent"), aceDB.frame, "PLAYER_LOGOUT")
      aceDB.db_registry = registry
      if not ok then error(err, 0) end
    end

    it("says the player is logging out when AceDB shuts the database down, and not before", function()
      _G.BetterBagsDB = nil
      DB:Init()
      assert.is_false(addon.loggingOut)
      logout()
      assert.is_true(addon.loggingOut)
      assert.is_nil(rawget(DB.data.profile, "views"), "the views at their default, stripped")
    end)

    it("starts a new session not logging out", function()
      _G.BetterBagsDB = nil
      DB:Init()
      logout()
      DB:Init()
      assert.is_false(addon.loggingOut)
    end)
  end)

  -- ─── Bag view ──────────────────────────────────────────────────────────────────

  describe("bag views", function()

    it("GetBagView returns the configured view", function()
      assert.are.equal(const.BAG_VIEW.SECTION_GRID, DB:GetBagView(const.BAG_KIND.BACKPACK))
    end)

    it("SetBagView changes the view", function()
      DB:SetBagView(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_ALL_BAGS)
      assert.are.equal(const.BAG_VIEW.SECTION_ALL_BAGS, DB:GetBagView(const.BAG_KIND.BACKPACK))
    end)

    it("GetPreviousView / SetPreviousView", function()
      DB:SetPreviousView(const.BAG_KIND.BANK, const.BAG_VIEW.SECTION_GRID)
      assert.are.equal(const.BAG_VIEW.SECTION_GRID, DB:GetPreviousView(const.BAG_KIND.BANK))
    end)
  end)

  -- ─── New items ─────────────────────────────────────────────────────────────────

  describe("new items", function()

    it("GetMarkRecentItems / SetMarkRecentItems", function()
      DB:SetMarkRecentItems(const.BAG_KIND.BACKPACK, false)
      assert.is_false(DB:GetMarkRecentItems(const.BAG_KIND.BACKPACK))
    end)

    it("GetShowNewItemFlash / SetShowNewItemFlash", function()
      DB:SetShowNewItemFlash(const.BAG_KIND.BANK, true)
      assert.is_true(DB:GetShowNewItemFlash(const.BAG_KIND.BANK))
    end)

    it("GetNewItemTime / SetNewItemTime", function()
      DB:SetNewItemTime(600)
      assert.are.equal(600, DB:GetNewItemTime())
    end)
  end)

  -- ─── Groups enabled ────────────────────────────────────────────────────────────

  describe("groups enabled", function()

    it("GetGroupsEnabled returns true by default", function()
      assert.is_true(DB:GetGroupsEnabled(const.BAG_KIND.BACKPACK))
    end)

    it("SetGroupsEnabled changes the value", function()
      DB:SetGroupsEnabled(const.BAG_KIND.BANK, false)
      assert.is_false(DB:GetGroupsEnabled(const.BAG_KIND.BANK))
    end)

    it("GetGroupsEnabled returns true when groupsEnabled is nil", function()
      DB.data.profile.groupsEnabled = nil
      assert.is_true(DB:GetGroupsEnabled(const.BAG_KIND.BANK))
    end)

    it("GetGroupsEnabled returns true when kind entry is nil", function()
      DB.data.profile.groupsEnabled = {}
      assert.is_true(DB:GetGroupsEnabled(const.BAG_KIND.BACKPACK))
    end)
  end)

  -- ─── Bag size ──────────────────────────────────────────────────────────────────

  describe("bag size", function()

    it("GetBagSizeInfo returns size for view/kind", function()
      local size = DB:GetBagSizeInfo(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID)
      assert.is_not_nil(size)
      assert.are.equal(2, size.columnCount)
      assert.are.equal(7, size.itemsPerRow)
    end)

    it("SetBagViewSizeColumn changes column count", function()
      DB:SetBagViewSizeColumn(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID, 3)
      local size = DB:GetBagSizeInfo(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID)
      assert.are.equal(3, size.columnCount)
    end)

    it("SetBagViewSizeItems changes items per row", function()
      DB:SetBagViewSizeItems(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID, 10)
      local size = DB:GetBagSizeInfo(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID)
      assert.are.equal(10, size.itemsPerRow)
    end)

    it("SetBagViewSizeScale changes scale", function()
      DB:SetBagViewSizeScale(const.BAG_KIND.BANK, const.BAG_VIEW.SECTION_ALL_BAGS, 150)
      local size = DB:GetBagSizeInfo(const.BAG_KIND.BANK, const.BAG_VIEW.SECTION_ALL_BAGS)
      assert.are.equal(150, size.scale)
    end)

    it("SetBagViewSizeOpacity changes opacity", function()
      DB:SetBagViewSizeOpacity(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID, 50)
      local size = DB:GetBagSizeInfo(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID)
      assert.are.equal(50, size.opacity)
    end)

    it("GetBagViewFrameSize / SetBagViewFrameSize", function()
      DB:SetBagViewFrameSize(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID, 800, 600)
      local w, h = DB:GetBagViewFrameSize(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID)
      assert.are.equal(800, w)
      assert.are.equal(600, h)
    end)

    it("sizes every bag window to its contents by default", function()
      for _, kind in pairs({ const.BAG_KIND.BACKPACK, const.BAG_KIND.BANK }) do
        for _, view in pairs({ const.BAG_VIEW.SECTION_GRID, const.BAG_VIEW.SECTION_ALL_BAGS }) do
          assert.are.equal("content", DB:GetBagSizeInfo(kind, view).sizeMode)
        end
        assert.are.equal("content", DB:GetBagSizeMode(kind))
      end
    end)

    it("keeps the size mode of the view the bag shows", function()
      DB:SetBagView(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID)
      DB:SetBagSizeMode(const.BAG_KIND.BACKPACK, "window")
      assert.are.equal("window", DB:GetBagSizeMode(const.BAG_KIND.BACKPACK))
      assert.are.equal("content", DB:GetBagSizeMode(const.BAG_KIND.BANK))
      DB:SetBagView(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_ALL_BAGS)
      assert.are.equal("content", DB:GetBagSizeMode(const.BAG_KIND.BACKPACK))
      DB:SetBagView(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID)
      assert.are.equal("window", DB:GetBagSizeMode(const.BAG_KIND.BACKPACK))
    end)

    it("snaps every bag window to its content unless turned off, per view", function()
      DB:SetBagView(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID)
      assert.is_true(DB:GetBagSnapToContent(const.BAG_KIND.BACKPACK))
      assert.is_true(DB:GetBagSnapToContent(const.BAG_KIND.BANK))
      DB:SetBagSnapToContent(const.BAG_KIND.BACKPACK, false)
      assert.is_false(DB:GetBagSnapToContent(const.BAG_KIND.BACKPACK))
      assert.is_true(DB:GetBagSnapToContent(const.BAG_KIND.BANK))
      DB:SetBagView(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_ALL_BAGS)
      assert.is_true(DB:GetBagSnapToContent(const.BAG_KIND.BACKPACK))
      DB:SetBagView(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID)
      assert.is_false(DB:GetBagSnapToContent(const.BAG_KIND.BACKPACK))
      DB:SetBagSnapToContent(const.BAG_KIND.BACKPACK, true)
      assert.is_true(DB:GetBagSnapToContent(const.BAG_KIND.BACKPACK))
    end)

    it("rejects a size mode it does not know", function()
      assert.has_error(function() DB:SetBagSizeMode(const.BAG_KIND.BACKPACK, "huge") end)
    end)
  end)

  -- ─── Item level ────────────────────────────────────────────────────────────────

  describe("item level", function()

    it("GetItemLevelOptions returns kind-specific options", function()
      local opts = DB:GetItemLevelOptions(const.BAG_KIND.BACKPACK)
      assert.is_true(opts.enabled)
      assert.is_true(opts.color)
    end)

    it("SetItemLevelEnabled / SetItemLevelColorEnabled", function()
      DB:SetItemLevelEnabled(const.BAG_KIND.BANK, false)
      DB:SetItemLevelColorEnabled(const.BAG_KIND.BANK, false)
      local opts = DB:GetItemLevelOptions(const.BAG_KIND.BANK)
      assert.is_false(opts.enabled)
      assert.is_false(opts.color)
    end)

    it("GetItemLevelColors returns color table", function()
      local colors = DB:GetItemLevelColors()
      assert.is_not_nil(colors.low)
      assert.is_not_nil(colors.mid)
      assert.is_not_nil(colors.high)
      assert.is_not_nil(colors.max)
    end)

    it("SetItemLevelColor updates a specific color", function()
      local newColor = { red = 0.1, green = 0.2, blue = 0.3, alpha = 0.5 }
      DB:SetItemLevelColor("low", newColor)
      local colors = DB:GetItemLevelColors()
      assert.are.same(newColor, colors.low)
    end)

    it("GetMaxItemLevel returns per-character max", function()
      -- Initially 1 (default)
      local max = DB:GetMaxItemLevel()
      assert.are.equal(1, max)
    end)

    it("UpdateMaxItemLevel updates when higher", function()
      DB:UpdateMaxItemLevel(100)
      assert.are.equal(100, DB:GetMaxItemLevel())
    end)

    it("UpdateMaxItemLevel does not decrease", function()
      DB:UpdateMaxItemLevel(100)
      DB:UpdateMaxItemLevel(50)
      assert.are.equal(100, DB:GetMaxItemLevel())
    end)

    -- The maximum is learned while items are read, and a sweep keeps the items of unchanged
    -- slots without reading them again, so a reset must ask for a full re-read.
    it("ResetMaxItemLevel requests a full refresh so the maximum is learned again", function()
      DB:UpdateMaxItemLevel(100)
      local sent = {}
      local send = events.SendMessage
      events.SendMessage = function(_, _, event)
        table.insert(sent, event)
      end
      DB:ResetMaxItemLevel()
      events.SendMessage = send
      assert.are.equal(1, DB:GetMaxItemLevel())
      local full = false
      for _, event in ipairs(sent) do
        if event == "bags/FullRefreshAll" then full = true end
      end
      assert.is_true(full)
    end)
  end)

  -- ─── Sort types ────────────────────────────────────────────────────────────────

  describe("sort types", function()

    it("GetSectionSortType / SetSectionSortType", function()
      DB:SetSectionSortType(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID, const.SECTION_SORT_TYPE.SIZE_DESCENDING)
      assert.are.equal(const.SECTION_SORT_TYPE.SIZE_DESCENDING, DB:GetSectionSortType(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID))
    end)

    it("GetItemSortType / SetItemSortType", function()
      DB:SetItemSortType(const.BAG_KIND.BANK, const.BAG_VIEW.SECTION_ALL_BAGS, const.ITEM_SORT_TYPE.ITEM_LEVEL)
      assert.are.equal(const.ITEM_SORT_TYPE.ITEM_LEVEL, DB:GetItemSortType(const.BAG_KIND.BANK, const.BAG_VIEW.SECTION_ALL_BAGS))
    end)
  end)

  -- ─── Extra glowy buttons ───────────────────────────────────────────────────────

  describe("glow intensity", function()

    it("GetGlowIntensity / SetGlowIntensity", function()
      DB:SetGlowIntensity(const.BAG_KIND.BACKPACK, 85)
      assert.equal(85, DB:GetGlowIntensity(const.BAG_KIND.BACKPACK))
    end)

    it("clamps and rounds the stored intensity to an integer in [0, 100]", function()
      DB:SetGlowIntensity(const.BAG_KIND.BACKPACK, 61.6)
      assert.equal(62, DB:GetGlowIntensity(const.BAG_KIND.BACKPACK))
      DB:SetGlowIntensity(const.BAG_KIND.BACKPACK, -20)
      assert.equal(0, DB:GetGlowIntensity(const.BAG_KIND.BACKPACK))
      DB:SetGlowIntensity(const.BAG_KIND.BACKPACK, 250)
      assert.equal(100, DB:GetGlowIntensity(const.BAG_KIND.BACKPACK))
    end)
  end)

  -- ─── Show full section names / free space ──────────────────────────────────────

  describe("display toggles", function()

    it("GetShowFullSectionNames / SetShowFullSectionNames", function()
      DB:SetShowFullSectionNames(const.BAG_KIND.BANK, true)
      assert.is_true(DB:GetShowFullSectionNames(const.BAG_KIND.BANK))
    end)

    it("GetShowAllFreeSpace / SetShowAllFreeSpace", function()
      DB:SetShowAllFreeSpace(const.BAG_KIND.BACKPACK, true)
      assert.is_true(DB:GetShowAllFreeSpace(const.BAG_KIND.BACKPACK))
    end)

    it("GetPreserveItemGaps / SetPreserveItemGaps", function()
      -- Default is on for both kinds.
      assert.is_true(DB:GetPreserveItemGaps(const.BAG_KIND.BACKPACK))
      assert.is_true(DB:GetPreserveItemGaps(const.BAG_KIND.BANK))
      DB:SetPreserveItemGaps(const.BAG_KIND.BACKPACK, false)
      assert.is_false(DB:GetPreserveItemGaps(const.BAG_KIND.BACKPACK))
      assert.is_true(DB:GetPreserveItemGaps(const.BAG_KIND.BANK))
    end)
  end)

  -- ─── Theme ─────────────────────────────────────────────────────────────────────

  describe("theme", function()

    it("GetTheme / SetTheme", function()
      DB:SetTheme("DarkMode")
      assert.are.equal("DarkMode", DB:GetTheme())
    end)

    it("GetUpgradeIconProvider / SetUpgradeIconProvider", function()
      DB:SetUpgradeIconProvider("Pawn")
      assert.are.equal("Pawn", DB:GetUpgradeIconProvider())
    end)

    it("tracks whether the user explicitly set a provider", function()
      -- Defaults to false so external-provider precedence can kick in for
      -- legacy users who never touched the setting.
      assert.is_false(DB:GetUpgradeIconProviderUserSet())
      DB:SetUpgradeIconProvider("Pawn")
      assert.is_true(DB:GetUpgradeIconProviderUserSet())
    end)
  end)

  -- ─── Stacking ──────────────────────────────────────────────────────────────────

  describe("stacking", function()

    it("GetStackingOptions returns kind-specific stacking config", function()
      local opts = DB:GetStackingOptions(const.BAG_KIND.BACKPACK)
      assert.is_not_nil(opts)
      assert.is_true(opts.mergeStacks)
    end)

    it("SetMergeItems toggles mergeStacks", function()
      DB:SetMergeItems(const.BAG_KIND.BANK, false)
      local opts = DB:GetStackingOptions(const.BAG_KIND.BANK)
      assert.is_false(opts.mergeStacks)
    end)

    it("SetMergeUnstackable toggles mergeUnstackable", function()
      DB:SetMergeUnstackable(const.BAG_KIND.BACKPACK, false)
      local opts = DB:GetStackingOptions(const.BAG_KIND.BACKPACK)
      assert.is_false(opts.mergeUnstackable)
    end)

    it("SetUnmergeAtShop toggles unmergeAtShop", function()
      DB:SetUnmergeAtShop(const.BAG_KIND.BANK, false)
      local opts = DB:GetStackingOptions(const.BAG_KIND.BANK)
      assert.is_false(opts.unmergeAtShop)
    end)

    it("SetDontMergePartial toggles dontMergePartial", function()
      DB:SetDontMergePartial(const.BAG_KIND.BACKPACK, true)
      local opts = DB:GetStackingOptions(const.BAG_KIND.BACKPACK)
      assert.is_true(opts.dontMergePartial)
    end)

    it("SetDontMergeTransmog toggles dontMergeTransmog", function()
      DB:SetDontMergeTransmog(const.BAG_KIND.BANK, true)
      local opts = DB:GetStackingOptions(const.BAG_KIND.BANK)
      assert.is_true(opts.dontMergeTransmog)
    end)
  end)

  -- ─── Category filters ──────────────────────────────────────────────────────────

  describe("category filters", function()

    it("GetCategoryFilter / SetCategoryFilter", function()
      DB:SetCategoryFilter(const.BAG_KIND.BACKPACK, "Type", false)
      assert.is_false(DB:GetCategoryFilter(const.BAG_KIND.BACKPACK, "Type"))
    end)

    it("GetCategoryFilters returns filter table for a kind", function()
      local filters = DB:GetCategoryFilters(const.BAG_KIND.BANK)
      assert.is_true(filters.Type)
      assert.is_false(filters.Subtype)
    end)
  end)

  -- ─── Item locking ──────────────────────────────────────────────────────────────

  describe("item locking", function()

    it("SetItemLock / GetItemLock", function()
      DB:SetItemLock("guid-123", true)
      assert.is_true(DB:GetItemLock("guid-123"))
    end)

    it("GetItemLock returns nil for unknown guid", function()
      assert.is_nil(DB:GetItemLock("guid-nonexistent"))
    end)
  end)

  -- ─── First time menu ───────────────────────────────────────────────────────────

  describe("first time menu", function()

    it("GetFirstTimeMenu / SetFirstTimeMenu", function()
      DB:SetFirstTimeMenu(true)
      assert.is_true(DB:GetFirstTimeMenu())
    end)
  end)

  -- ─── Category options ──────────────────────────────────────────────────────────

  -- ─── SaveItemToCategory / DeleteItemFromCategory ───────────────────────────────

  describe("item category assignment", function()

    it("SaveItemToCategory adds an item to a category", function()
      DB.data.profile.customCategoryFilters["Weapons"] = {
        name = "Weapons", itemList = {}, enabled = { [0] = true, [1] = true }
      }
      DB:SaveItemToCategory(1234, "Weapons")
      assert.is_true(DB.data.profile.customCategoryFilters["Weapons"].itemList[1234])
      assert.are.equal("Weapons", DB.data.profile.customCategoryIndex[1234])
    end)

    it("SaveItemToCategory moves item from old category to new", function()
      DB.data.profile.customCategoryFilters["Old"] = {
        name = "Old", itemList = { [1234] = true }, enabled = { [0] = true, [1] = true }
      }
      DB.data.profile.customCategoryFilters["New"] = {
        name = "New", itemList = {}, enabled = { [0] = true, [1] = true }
      }
      DB.data.profile.customCategoryIndex[1234] = "Old"

      DB:SaveItemToCategory(1234, "New")
      assert.is_nil(DB.data.profile.customCategoryFilters["Old"].itemList[1234])
      assert.is_true(DB.data.profile.customCategoryFilters["New"].itemList[1234])
      assert.are.equal("New", DB.data.profile.customCategoryIndex[1234])
    end)

    it("DeleteItemFromCategory removes item", function()
      DB.data.profile.customCategoryFilters["Weapons"] = {
        name = "Weapons", itemList = { [1234] = true }, enabled = { [0] = true, [1] = true }
      }
      DB.data.profile.customCategoryIndex[1234] = "Weapons"
      DB:DeleteItemFromCategory(1234, "Weapons")
      assert.is_nil(DB.data.profile.customCategoryFilters["Weapons"].itemList[1234])
      assert.is_nil(DB.data.profile.customCategoryIndex[1234])
    end)

    -- The index entry is the item's home; removing it from a category it is not filed in must not
    -- unfile it from its home (one of the ways real profiles' indexes drifted).
    it("DeleteItemFromCategory leaves the item filed where it is when it names another category", function()
      DB.data.profile.customCategoryFilters["Weapons"] = { name = "Weapons", itemList = { [1234] = true } }
      DB.data.profile.customCategoryFilters["Junk"] = { name = "Junk", itemList = {} }
      DB.data.profile.customCategoryIndex[1234] = "Weapons"
      DB:DeleteItemFromCategory(1234, "Junk")
      assert.are.equal("Weapons", DB.data.profile.customCategoryIndex[1234])
      assert.is_true(DB.data.profile.customCategoryFilters["Weapons"].itemList[1234])
    end)

    it("GetItemCategoryByItemID returns category for an item", function()
      DB.data.profile.customCategoryFilters["Armor"] = {
        name = "Armor", itemList = { [5678] = true }, enabled = { [0] = true, [1] = true }
      }
      DB.data.profile.customCategoryIndex[5678] = "Armor"
      local cat = DB:GetItemCategoryByItemID(5678)
      assert.are.equal("Armor", cat.name)
    end)

    it("GetItemCategoryByItemID returns empty table for unknown item", function()
      local cat = DB:GetItemCategoryByItemID(9999)
      assert.same({}, cat)
    end)
  end)

  -- ─── Category enabled ──────────────────────────────────────────────────────────

  describe("category enabled", function()

    it("SetItemCategoryEnabled sets enabled per kind", function()
      DB.data.profile.customCategoryFilters["Weapons"] = {
        name = "Weapons", itemList = {}, enabled = { [0] = true, [1] = true }
      }
      DB:SetItemCategoryEnabled(const.BAG_KIND.BANK, "Weapons", false)
      assert.is_false(DB.data.profile.customCategoryFilters["Weapons"].enabled[const.BAG_KIND.BANK])
      assert.is_true(DB.data.profile.customCategoryFilters["Weapons"].enabled[const.BAG_KIND.BACKPACK])
    end)

    it("SetEphemeralItemCategoryEnabled sets enabled for ephemeral", function()
      DB.data.profile.ephemeralCategoryFilters["Temp"] = {
        name = "Temp", enabled = { [0] = true, [1] = true }
      }
      DB:SetEphemeralItemCategoryEnabled(const.BAG_KIND.BACKPACK, "Temp", false)
      assert.is_false(DB.data.profile.ephemeralCategoryFilters["Temp"].enabled[const.BAG_KIND.BACKPACK])
    end)
  end)

  -- ─── Category CRUD ─────────────────────────────────────────────────────────────

  describe("category CRUD", function()

    -- A plugin makes its category again at every load; what the player set for it stays.
    it("keeps the bags, color and priority set for a plugin's category when the plugin makes it again", function()
      DB:UpdateEphemeralItemCategory("Openable", { enabled = { [0] = false }, color = { 0, 0, 1 }, priority = 7 })
      DB:CreateOrUpdateCategory({ name = "Openable", enabled = { [0] = false }, color = { 0, 1, 0 }, priority = 1 })
      local saved = DB.data.profile.ephemeralCategoryFilters["Openable"]
      assert.are.same({ 0, 0, 1 }, saved.color)
      assert.are.equal(7, saved.priority)
      assert.are.same({ [0] = false }, saved.enabled)
    end)

    it("keeps the automation set for a plugin's category when the plugin makes it again", function()
      DB:UpdateEphemeralItemCategory("Openable", { enabled = { [0] = true }, automation = "sell" })
      assert.are.equal("sell", DB.data.profile.ephemeralCategoryFilters["Openable"].automation)
      DB:CreateOrUpdateCategory({ name = "Openable", enabled = { [0] = true }, priority = 1 })
      assert.are.equal("sell", DB.data.profile.ephemeralCategoryFilters["Openable"].automation)
      DB:UpdateEphemeralItemCategory("Openable", { enabled = { [0] = true } })
      assert.is_nil(DB.data.profile.ephemeralCategoryFilters["Openable"].automation, "turned off")
    end)

    it("keeps a plugin's Ignored Items when the plugin makes it again", function()
      DB:UpdateEphemeralItemCategory("Openable", { enabled = { [0] = true }, ignoredItems = { [202] = true } })
      DB:CreateOrUpdateCategory({ name = "Openable", enabled = { [0] = true }, priority = 1 })
      assert.are.same({ [202] = true }, DB.data.profile.ephemeralCategoryFilters["Openable"].ignoredItems)
    end)

    it("keeps Skip Recent Items for a plugin's category when the plugin makes it again", function()
      DB:UpdateEphemeralItemCategory("Openable", { enabled = { [0] = true }, skipRecent = true })
      DB:CreateOrUpdateCategory({ name = "Openable", enabled = { [0] = true }, priority = 1 })
      assert.is_true(DB.data.profile.ephemeralCategoryFilters["Openable"].skipRecent)
    end)

    it("keeps confirming set off for a plugin's category when the plugin makes it again", function()
      DB:UpdateEphemeralItemCategory("Openable", { enabled = { [0] = true }, automation = "sell", confirmSale = false })
      DB:CreateOrUpdateCategory({ name = "Openable", enabled = { [0] = true }, priority = 1 })
      assert.is_false(DB.data.profile.ephemeralCategoryFilters["Openable"].confirmSale)
    end)

    it("CreateOrUpdateCategory creates a persistent category", function()
      DB:CreateOrUpdateCategory({
        name = "Persistent", save = true, enabled = { [0] = true, [1] = true }
      })
      assert.is_not_nil(DB.data.profile.customCategoryFilters["Persistent"])
    end)

    it("CreateOrUpdateCategory creates an ephemeral category", function()
      DB:CreateOrUpdateCategory({
        name = "Ephemeral", save = false, enabled = { [0] = true, [1] = true }
      })
      assert.is_nil(DB.data.profile.customCategoryFilters["Ephemeral"])
      assert.is_not_nil(DB.data.profile.ephemeralCategoryFilters["Ephemeral"])
    end)

    it("CreateOrUpdateCategory updates customCategoryIndex for persistent categories", function()
      DB:CreateOrUpdateCategory({
        name = "Indexed", save = true, itemList = { [42] = true, [99] = true }, enabled = { [0] = true, [1] = true }
      })
      assert.are.equal("Indexed", DB.data.profile.customCategoryIndex[42])
      assert.are.equal("Indexed", DB.data.profile.customCategoryIndex[99])
    end)

    it("DeleteItemCategory removes persistent category", function()
      DB.data.profile.customCategoryFilters["Gone"] = {
        name = "Gone", itemList = {}, enabled = { [0] = true, [1] = true }
      }
      DB:DeleteItemCategory("Gone")
      assert.is_nil(DB.data.profile.customCategoryFilters["Gone"])
    end)

    it("DeleteItemCategory removes ephemeral category", function()
      DB.data.profile.ephemeralCategoryFilters["TempGone"] = {
        name = "TempGone", enabled = { [0] = true, [1] = true }
      }
      DB:DeleteItemCategory("TempGone")
      assert.is_nil(DB.data.profile.ephemeralCategoryFilters["TempGone"])
    end)

    it("DeleteItemCategory cleans up items from index", function()
      DB.data.profile.customCategoryFilters["CleanMe"] = {
        name = "CleanMe", itemList = { [1] = true, [2] = true }, enabled = { [0] = true, [1] = true }
      }
      DB.data.profile.customCategoryIndex[1] = "CleanMe"
      DB.data.profile.customCategoryIndex[2] = "CleanMe"
      DB:DeleteItemCategory("CleanMe")
      assert.is_nil(DB.data.profile.customCategoryIndex[1])
      assert.is_nil(DB.data.profile.customCategoryIndex[2])
    end)

    it("DeleteItemCategory scrubs pinned sort and group for all kinds", function()
      -- Reproduces the orphaned-category bug: deleting a category must remove
      -- every reference to it, otherwise a leftover customSectionSort ("Pinned")
      -- entry resurfaces it forever as an undeletable "dynamic" category.
      DB.data.profile.customCategoryFilters["Orphan"] = {
        name = "Orphan", itemList = { [50] = true }, enabled = { [0] = true, [1] = true }
      }
      DB.data.profile.customCategoryIndex[50] = "Orphan"
      DB.data.profile.categoryToGroup[const.BAG_KIND.BACKPACK]["Orphan"] = 3
      DB.data.profile.categoryToGroup[const.BAG_KIND.BANK]["Orphan"] = 4
      DB.data.profile.customSectionSort[const.BAG_KIND.BACKPACK]["Orphan"] = 5
      DB.data.profile.customSectionSort[const.BAG_KIND.BANK]["Orphan"] = 7

      DB:DeleteItemCategory("Orphan")

      assert.is_nil(DB.data.profile.customSectionSort[const.BAG_KIND.BACKPACK]["Orphan"])
      assert.is_nil(DB.data.profile.customSectionSort[const.BAG_KIND.BANK]["Orphan"])
      assert.is_nil(DB.data.profile.categoryToGroup[const.BAG_KIND.BACKPACK]["Orphan"])
      assert.is_nil(DB.data.profile.categoryToGroup[const.BAG_KIND.BANK]["Orphan"])
    end)

    it("DeleteItemCategory scrubs grouped sub-categories from side tables", function()
      DB.data.profile.customCategoryFilters["Parent"] = {
        name = "Parent", itemList = {}, enabled = { [0] = true, [1] = true }
      }
      DB.data.profile.ephemeralCategoryFilters["Parent - Consumable"] = { name = "Parent - Consumable" }
      DB.data.profile.customSectionSort[const.BAG_KIND.BACKPACK]["Parent - Consumable"] = 2

      DB:DeleteItemCategory("Parent")

      assert.is_nil(DB.data.profile.ephemeralCategoryFilters["Parent - Consumable"])
      assert.is_nil(DB.data.profile.customSectionSort[const.BAG_KIND.BACKPACK]["Parent - Consumable"])
    end)

    it("WipeItemCategory clears items from persistent category", function()
      DB.data.profile.customCategoryFilters["WipeMe"] = {
        name = "WipeMe", itemList = { [5] = true, [10] = true }, enabled = { [0] = true, [1] = true }
      }
      DB.data.profile.customCategoryIndex[5] = "WipeMe"
      DB.data.profile.customCategoryIndex[10] = "WipeMe"
      DB:WipeItemCategory("WipeMe")
      assert.same({}, DB.data.profile.customCategoryFilters["WipeMe"].itemList)
      assert.is_nil(DB.data.profile.customCategoryIndex[5])
    end)

    it("ItemCategoryExists checks persistent categories", function()
      DB.data.profile.customCategoryFilters["Exists"] = { name = "Exists", itemList = {} }
      assert.is_true(DB:ItemCategoryExists("Exists"))
    end)

    it("ItemCategoryExists returns false for unknown", function()
      assert.is_false(DB:ItemCategoryExists("Nope"))
    end)

    it("GetAllItemCategories sets name on each category", function()
      DB.data.profile.customCategoryFilters["A"] = { name = "OldA", itemList = {} }
      local all = DB:GetAllItemCategories()
      assert.are.equal("A", all["A"].name)
    end)

    it("GetItemCategory returns persistent category", function()
      DB.data.profile.customCategoryFilters["Cat"] = { name = "Cat", itemList = {} }
      assert.is_not_nil(DB:GetItemCategory("Cat"))
    end)

    it("GetEphemeralItemCategory returns ephemeral category", function()
      DB.data.profile.ephemeralCategoryFilters["Eph"] = { name = "Eph" }
      assert.is_not_nil(DB:GetEphemeralItemCategory("Eph"))
    end)

    it("GetAllEphemeralItemCategories returns all ephemeral", function()
      DB.data.profile.ephemeralCategoryFilters["E1"] = { name = "E1" }
      DB.data.profile.ephemeralCategoryFilters["E2"] = { name = "E2" }
      local all = DB:GetAllEphemeralItemCategories()
      assert.is_not_nil(all["E1"])
      assert.is_not_nil(all["E2"])
    end)
  end)

  -- ─── RenameCategory ────────────────────────────────────────────────────────────

  describe("RenameCategory", function()

    before_each(function()
      DB.data.profile.customCategoryFilters["OldName"] = {
        name = "OldName", itemList = { [100] = true }, enabled = { [0] = true, [1] = true }
      }
      DB.data.profile.customCategoryIndex[100] = "OldName"
      DB.data.profile.categoryToGroup[const.BAG_KIND.BACKPACK]["OldName"] = 1
      DB.data.profile.categoryToGroup[const.BAG_KIND.BANK]["OldName"] = 2
      DB.data.profile.ephemeralCategoryFilters["OldName"] = { name = "OldName", enabled = { [0] = true, [1] = true } }
      DB.data.profile.customSectionSort[const.BAG_KIND.BACKPACK]["OldName"] = 5
      DB.data.profile.customSectionSort[const.BAG_KIND.BANK]["OldName"] = 3
    end)

    it("renames successfully", function()
      local ok = DB:RenameCategory("OldName", "NewName")
      assert.is_true(ok)
    end)

    it("moves main category data", function()
      DB:RenameCategory("OldName", "NewName")
      assert.is_nil(DB.data.profile.customCategoryFilters["OldName"])
      assert.is_not_nil(DB.data.profile.customCategoryFilters["NewName"])
      assert.are.equal("NewName", DB.data.profile.customCategoryFilters["NewName"].name)
    end)

    it("updates customCategoryIndex", function()
      DB:RenameCategory("OldName", "NewName")
      assert.are.equal("NewName", DB.data.profile.customCategoryIndex[100])
    end)

    it("updates categoryToGroup for all kinds", function()
      DB:RenameCategory("OldName", "NewName")
      assert.are.equal(1, DB.data.profile.categoryToGroup[const.BAG_KIND.BACKPACK]["NewName"])
      assert.are.equal(2, DB.data.profile.categoryToGroup[const.BAG_KIND.BANK]["NewName"])
      assert.is_nil(DB.data.profile.categoryToGroup[const.BAG_KIND.BACKPACK]["OldName"])
    end)

    it("updates ephemeral filters", function()
      DB:RenameCategory("OldName", "NewName")
      assert.is_nil(DB.data.profile.ephemeralCategoryFilters["OldName"])
      assert.is_not_nil(DB.data.profile.ephemeralCategoryFilters["NewName"])
    end)

    it("updates customSectionSort for all kinds", function()
      DB:RenameCategory("OldName", "NewName")
      assert.are.equal(5, DB.data.profile.customSectionSort[const.BAG_KIND.BACKPACK]["NewName"])
      assert.are.equal(3, DB.data.profile.customSectionSort[const.BAG_KIND.BANK]["NewName"])
    end)

    it("fails when old category doesn't exist", function()
      local ok = DB:RenameCategory("GhostCategory", "NewName")
      assert.is_false(ok)
    end)

    it("fails when new name already exists", function()
      DB.data.profile.customCategoryFilters["NewName"] = { name = "NewName", itemList = {} }
      local ok = DB:RenameCategory("OldName", "NewName")
      assert.is_false(ok)
    end)

    it("fails when new name is empty", function()
      local ok = DB:RenameCategory("OldName", "   ")
      assert.is_false(ok)
    end)

    it("cleans up grouped sub-categories", function()
      DB.data.profile.ephemeralCategoryFilters["OldName - Consumable"] = { name = "OldName - Consumable" }
      DB.data.profile.customSectionSort[const.BAG_KIND.BANK]["OldName - Consumable"] = 2

      DB:RenameCategory("OldName", "NewName")

      assert.is_nil(DB.data.profile.ephemeralCategoryFilters["OldName - Consumable"])
      assert.is_nil(DB.data.profile.customSectionSort[const.BAG_KIND.BANK]["OldName - Consumable"])
    end)
  end)

  -- ─── Custom section sort ───────────────────────────────────────────────────────

  describe("custom section sort", function()

    it("ClearCustomSectionSort wipes the kind", function()
      DB.data.profile.customSectionSort[const.BAG_KIND.BACKPACK]["Pinned"] = 10
      DB:ClearCustomSectionSort(const.BAG_KIND.BACKPACK)
      assert.same({}, DB.data.profile.customSectionSort[const.BAG_KIND.BACKPACK])
    end)

    it("SetCustomSectionSort / GetCustomSectionSort", function()
      DB:SetCustomSectionSort(const.BAG_KIND.BANK, "Important", 1)
      local sort = DB:GetCustomSectionSort(const.BAG_KIND.BANK)
      assert.are.equal(1, sort["Important"])
    end)
  end)

  -- ─── Groups ────────────────────────────────────────────────────────────────────

  describe("groups", function()

    it("GetAllGroups returns groups for a kind", function()
      local groups = DB:GetAllGroups(const.BAG_KIND.BACKPACK)
      assert.is_not_nil(groups[1])
      assert.are.equal("Backpack", groups[1].name)
    end)

    it("GetGroup returns specific group", function()
      local group = DB:GetGroup(const.BAG_KIND.BACKPACK, 1)
      assert.are.equal("Backpack", group.name)
    end)

    it("GetGroup returns nil for non-existent group", function()
      assert.is_nil(DB:GetGroup(const.BAG_KIND.BANK, 999))
    end)

    it("GetAllGroups handles nil kind gracefully", function()
      local groups = DB:GetAllGroups(nil)
      assert.same({}, groups)
    end)

    it("GetGroup handles nil kind gracefully", function()
      local group = DB:GetGroup(nil, 1)
      assert.is_nil(group)
    end)

    it("CreateGroup creates a new group and returns its ID", function()
      local id = DB:CreateGroup(const.BAG_KIND.BACKPACK, "Test Group")
      assert.are.equal(2, id)
      local group = DB:GetGroup(const.BAG_KIND.BACKPACK, id)
      assert.are.equal("Test Group", group.name)
      assert.are.equal(const.BAG_KIND.BACKPACK, group.kind)
    end)

    it("CreateGroup increments groupCounter", function()
      DB:CreateGroup(const.BAG_KIND.BACKPACK, "Group A")
      DB:CreateGroup(const.BAG_KIND.BACKPACK, "Group B")
      assert.are.equal(3, DB.data.profile.groupCounter[const.BAG_KIND.BACKPACK])
    end)

    it("DeleteGroup removes a non-default group", function()
      DB.data.profile.groups[const.BAG_KIND.BACKPACK][10] = {
        id = 10, name = "DeleteMe", order = 10, kind = const.BAG_KIND.BACKPACK
      }
      DB.data.profile.categoryToGroup[const.BAG_KIND.BACKPACK]["CatA"] = 10
      DB.data.profile.categoryToGroup[const.BAG_KIND.BACKPACK]["CatB"] = 10
      DB:DeleteGroup(const.BAG_KIND.BACKPACK, 10)
      assert.is_nil(DB:GetGroup(const.BAG_KIND.BACKPACK, 10))
      assert.is_nil(DB.data.profile.categoryToGroup[const.BAG_KIND.BACKPACK]["CatA"])
      assert.is_nil(DB.data.profile.categoryToGroup[const.BAG_KIND.BACKPACK]["CatB"])
    end)

    it("DeleteGroup does not delete default groups", function()
      DB:DeleteGroup(const.BAG_KIND.BACKPACK, 1)
      assert.is_not_nil(DB:GetGroup(const.BAG_KIND.BACKPACK, 1))
    end)

    it("DeleteGroup switches active group to default for backpack", function()
      DB.data.profile.activeGroup[const.BAG_KIND.BACKPACK] = 10
      DB.data.profile.groups[const.BAG_KIND.BACKPACK][10] = {
        id = 10, name = "Active", order = 10, kind = const.BAG_KIND.BACKPACK
      }
      DB:DeleteGroup(const.BAG_KIND.BACKPACK, 10)
      assert.are.equal(1, DB.data.profile.activeGroup[const.BAG_KIND.BACKPACK])
    end)

    it("DeleteGroup switches active group to default bank", function()
      -- Need a bank group first
      local bankId = DB:CreateGroup(const.BAG_KIND.BANK, "Bank Default", _G.Enum.BankType.Character)
      DB.data.profile.groups[const.BAG_KIND.BANK][bankId].isDefault = true

      DB.data.profile.activeGroup[const.BAG_KIND.BANK] = 50
      DB.data.profile.groups[const.BAG_KIND.BANK][50] = {
        id = 50, name = "Active Bank", order = 50, kind = const.BAG_KIND.BANK
      }
      DB:DeleteGroup(const.BAG_KIND.BANK, 50)
      assert.are.equal(bankId, DB.data.profile.activeGroup[const.BAG_KIND.BANK])
    end)

    it("RenameGroup updates group name", function()
      DB.data.profile.groups[const.BAG_KIND.BACKPACK][5] = {
        id = 5, name = "OldName", order = 5, kind = const.BAG_KIND.BACKPACK
      }
      DB:RenameGroup(const.BAG_KIND.BACKPACK, 5, "NewName")
      assert.are.equal("NewName", DB.data.profile.groups[const.BAG_KIND.BACKPACK][5].name)
    end)

    it("RenameGroup does nothing for non-existent group", function()
      DB:RenameGroup(const.BAG_KIND.BACKPACK, 999, "Whatever")
      assert.is_nil(DB:GetGroup(const.BAG_KIND.BACKPACK, 999))
    end)

    it("GetNextGroupID returns the next available ID", function()
      assert.are.equal(2, DB:GetNextGroupID(const.BAG_KIND.BACKPACK))
      assert.are.equal(1, DB:GetNextGroupID(const.BAG_KIND.BANK))
    end)
  end)

  -- ─── Category-to-group mapping ─────────────────────────────────────────────────

  describe("category-to-group mapping", function()

    it("SetCategoryGroup / GetCategoryGroup", function()
      DB:SetCategoryGroup(const.BAG_KIND.BACKPACK, "Weapons", 5)
      assert.are.equal(5, DB:GetCategoryGroup(const.BAG_KIND.BACKPACK, "Weapons"))
    end)

    it("GetCategoryGroup returns nil for unmapped category", function()
      assert.is_nil(DB:GetCategoryGroup(const.BAG_KIND.BANK, "Unmapped"))
    end)

    it("RemoveCategoryFromGroup clears mapping", function()
      DB:SetCategoryGroup(const.BAG_KIND.BACKPACK, "RemoveMe", 3)
      DB:RemoveCategoryFromGroup(const.BAG_KIND.BACKPACK, "RemoveMe")
      assert.is_nil(DB:GetCategoryGroup(const.BAG_KIND.BACKPACK, "RemoveMe"))
    end)

    it("GetGroupCategories returns categories in a group", function()
      DB.data.profile.categoryToGroup[const.BAG_KIND.BACKPACK]["Cat1"] = 10
      DB.data.profile.categoryToGroup[const.BAG_KIND.BACKPACK]["Cat2"] = 10
      DB.data.profile.categoryToGroup[const.BAG_KIND.BACKPACK]["Cat3"] = 20

      local cats = DB:GetGroupCategories(const.BAG_KIND.BACKPACK, 10)
      assert.is_true(cats["Cat1"])
      assert.is_true(cats["Cat2"])
      assert.is_nil(cats["Cat3"])
    end)
  end)

  -- ─── Active group ──────────────────────────────────────────────────────────────

  describe("active group", function()

    it("GetActiveGroup returns stored active group", function()
      DB:SetActiveGroup(const.BAG_KIND.BANK, 5)
      assert.are.equal(5, DB:GetActiveGroup(const.BAG_KIND.BANK))
    end)

    it("GetActiveGroup defaults to 1", function()
      DB.data.profile.activeGroup = {}
      assert.are.equal(1, DB:GetActiveGroup(const.BAG_KIND.BACKPACK))
    end)
  end)

  -- ─── Group order ───────────────────────────────────────────────────────────────

  describe("group order", function()

    it("SetGroupOrder / GetGroupOrder", function()
      DB:SetGroupOrder(const.BAG_KIND.BACKPACK, 1, 42)
      assert.are.equal(42, DB:GetGroupOrder(const.BAG_KIND.BACKPACK, 1))
    end)

    it("GetGroupOrder defaults to group ID", function()
      assert.are.equal(1, DB:GetGroupOrder(const.BAG_KIND.BACKPACK, 1))
    end)
  end)

  -- ─── Position / anchor ─────────────────────────────────────────────────────────

  describe("positions and anchors", function()

    it("GetBagPosition returns position data", function()
      local pos = DB:GetBagPosition(const.BAG_KIND.BACKPACK)
      assert.is_not_nil(pos)
    end)

    it("GetAnchorPosition returns anchor position data", function()
      local pos = DB:GetAnchorPosition(const.BAG_KIND.BANK)
      assert.is_not_nil(pos)
    end)

    it("GetAnchorState returns anchor state", function()
      local state = DB:GetAnchorState(const.BAG_KIND.BACKPACK)
      assert.is_false(state.enabled)
      assert.is_false(state.shown)
    end)
  end)

  -- ─── Search categories ─────────────────────────────────────────────────────────

  describe("search categories", function()

    it("IsSearchCategory returns true for registered search categories", function()
      DB.data.profile.searchCategories = { ["Smart Search"] = true }
      assert.is_true(DB:IsSearchCategory("Smart Search"))
    end)

    it("IsSearchCategory returns false for non-search categories", function()
      DB.data.profile.searchCategories = {}
      assert.is_false(DB:IsSearchCategory("NotHere"))
    end)
  end)

  -- ─── Export / Import ───────────────────────────────────────────────────────────

  describe("import/export", function()

    it("ExportSettings returns a base64 string with !BB prefix", function()
      local exported = DB:ExportSettings()
      assert.is_not_nil(exported)
      assert.is_not_nil(exported:match("^!BB"))
    end)

    it("ImportSettings returns false for nil data", function()
      local ok, err = DB:ImportSettings(nil)
      assert.is_false(ok)
      assert.is_not_nil(err)
    end)

    it("ImportSettings returns false for empty string", function()
      local ok = DB:ImportSettings("")
      assert.is_false(ok)
    end)

    it("ImportSettings returns false for missing !BB prefix", function()
      local ok, err = DB:ImportSettings("garbage")
      assert.is_false(ok)
      assert.is_not_nil(string.find(err, "prefix"))
    end)

    it("ImportSettings returns false for invalid base64", function()
      local ok = DB:ImportSettings("!BB!!!not-valid-base64!!!")
      assert.is_false(ok)
    end)

    -- Version 3: rules written with AND binding tighter than OR.
    it("exports version 3, without the hidden sections", function()
      DB.data.profile.categoryOptions = { Junk = { shown = false } }
      local serialization = addon:GetModule("Serialization")
      local data = serialization:Deserialize(serialization:DecodeBase64(DB:ExportSettings():sub(4)))
      assert.are.equal(3, data.version)
      assert.is_nil(data.categoryOptions)
      DB.data.profile.categoryOptions = nil
    end)

    -- An old export carries the old shapes; importing it brings them to the current one, as a load does.
    it("imports a version 1 export into the current shape", function()
      local serialization = addon:GetModule("Serialization")
      local old = "!BB" .. serialization:EncodeBase64(serialization:Serialize({
        version = 1,
        customCategoryFilters = {
          Mats = { name = "Mats", itemList = { [42] = true }, enabled = { [0] = true, [1] = false } },
          Gear = { name = "Gear", itemList = {}, searchCategory = { query = "type = armor group by type" } },
        },
        customCategoryIndex = {},
        categoryOptions = { Mats = { shown = false } },
      }))
      local ok, msg = DB:ImportSettings(old)
      assert.is_true(ok, msg)
      local f = DB.data.profile.customCategoryFilters
      assert.is_false(f.Mats.enabled[const.BAG_KIND.BANK])
      assert.is_true(f.Mats.enabled[const.BAG_KIND.BACKPACK])
      assert.are.equal("Mats", DB.data.profile.customCategoryIndex[42])
      assert.are.same({ query = "type = armor" }, f.Gear.searchCategory)
      assert.are.equal(1, f.Gear.groupBy)
      assert.is_nil(DB.data.profile.categoryOptions)
    end)

    -- An export from before AND bound tighter than OR has rules grouped left to right.
    it("keeps the meaning of an older export's rules, and leaves a version 3 export's as they are", function()
      local serialization = addon:GetModule("Serialization")
      local function export(version)
        return "!BB" .. serialization:EncodeBase64(serialization:Serialize({
          version = version,
          customCategoryFilters = {
            Gear = { name = "Gear", itemList = {}, searchCategory = { query = "type = armor OR type = weapon AND ilvl > 200" } },
          },
          customCategoryIndex = {},
        }))
      end
      assert.is_true((DB:ImportSettings(export(2))))
      assert.are.equal("(type = armor OR type = weapon) AND ilvl > 200",
        DB.data.profile.customCategoryFilters.Gear.searchCategory.query)
      assert.is_true((DB:ImportSettings(export(3))))
      assert.are.equal("type = armor OR type = weapon AND ilvl > 200",
        DB.data.profile.customCategoryFilters.Gear.searchCategory.query)
    end)

    it("round-trip export/import preserves category data", function()
      DB.data.profile.customCategoryFilters["ExportTest"] = {
        name = "ExportTest", itemList = { [42] = true }, enabled = { [0] = true, [1] = true }
      }
      DB.data.profile.customCategoryIndex[42] = "ExportTest"

      local exported = DB:ExportSettings()
      -- Reset
      DB.data.profile.customCategoryFilters = {}
      DB.data.profile.customCategoryIndex = {}

      local ok, msg = DB:ImportSettings(exported)
      assert.is_true(ok, msg)
      assert.is_not_nil(DB.data.profile.customCategoryFilters["ExportTest"])
      assert.is_true(DB.data.profile.customCategoryFilters["ExportTest"].itemList[42])
      assert.are.equal("ExportTest", DB.data.profile.customCategoryIndex[42])
    end)
  end)

  -- ─── Profile management ─────────────────────────────────────────────────────────

  describe("profile management", function()

    it("GetCurrentProfileName returns current profile name", function()
      local name = DB:GetCurrentProfileName()
      assert.is_not_nil(name)
      assert.is_true(type(name) == "string")
    end)

    it("GetAvailableProfiles returns a list", function()
      local profiles = DB:GetAvailableProfiles()
      assert.is_not_nil(profiles)
      assert.is_true(#profiles >= 1)
    end)

    it("SwitchToProfile returns true", function()
      local ok = DB:SwitchToProfile("Default")
      assert.is_true(ok)
    end)

    it("SwitchToProfile returns false for empty name", function()
      local ok = DB:SwitchToProfile("")
      assert.is_false(ok)
    end)

    it("CreateProfile creates a new profile", function()
      local ok, msg = DB:CreateProfile("TestProfile")
      assert.is_true(ok, msg)
    end)

    it("CreateProfile fails for duplicate name", function()
      DB:CreateProfile("DupProfile")
      local ok, _ = DB:CreateProfile("DupProfile")
      assert.is_false(ok)
    end)

    it("CreateProfile fails for empty name", function()
      local ok, _ = DB:CreateProfile("")
      assert.is_false(ok)
    end)

    it("CopyFromProfile returns false for non-existent source", function()
      local ok, _ = DB:CopyFromProfile("NonexistentProfile")
      assert.is_false(ok)
    end)

    it("CopyFromProfile returns false for empty name", function()
      local ok, _ = DB:CopyFromProfile("")
      assert.is_false(ok)
    end)

    it("RenameProfile cannot rename Default", function()
      local ok, _ = DB:RenameProfile("Default", "NewDefault")
      assert.is_false(ok)
    end)

    it("RenameProfile returns false for empty new name", function()
      DB:CreateProfile("RenameMe")
      local ok, _ = DB:RenameProfile("RenameMe", "")
      assert.is_false(ok)
    end)

    it("DeleteProfile cannot delete Default", function()
      local ok, _ = DB:DeleteProfile("Default")
      assert.is_false(ok)
    end)

    it("DeleteProfile cannot delete active profile", function()
      local currentName = DB:GetCurrentProfileName()
      local ok, _ = DB:DeleteProfile(currentName)
      assert.is_false(ok)
    end)

    it("ResetCurrentProfile returns true", function()
      local ok, _ = DB:ResetCurrentProfile()
      assert.is_true(ok)
    end)

    it("GetProfileCharacterCounts returns table", function()
      local counts = DB:GetProfileCharacterCounts()
      assert.is_not_nil(counts)
    end)
  end)

  -- ─── Debug backpack dump ───────────────────────────────────────────────────────

  -- The changelog's state is account wide (AceDB global): the newest release the player has
  -- seen, and whether the changelog opens by itself on login.
  describe("changelog", function()
    it("starts with nothing seen and opening on login", function()
      DB.data.global.changelog = nil
      DB.data:ResetDB()
      assert.are.equal(0, DB:GetChangelogLastSeen())
      assert.is_true(DB:GetChangelogAutoOpen())
    end)

    it("keeps what was set", function()
      DB:SetChangelogLastSeen(1792195200)
      DB:SetChangelogAutoOpen(false)
      assert.are.equal(1792195200, DB:GetChangelogLastSeen())
      assert.is_false(DB:GetChangelogAutoOpen())
      DB:SetChangelogAutoOpen(true)
      assert.is_true(DB:GetChangelogAutoOpen())
    end)

    it("is shared by every profile, and a profile reset leaves it", function()
      DB:SetChangelogLastSeen(42)
      DB:SetChangelogAutoOpen(false)
      DB.data:SetProfile("ChangelogSpecOther")
      assert.are.equal(42, DB:GetChangelogLastSeen())
      assert.is_false(DB:GetChangelogAutoOpen())
      DB.data:ResetProfile(false, true)
      assert.are.equal(42, DB:GetChangelogLastSeen())
      DB.data:SetProfile("Default")
      DB:SetChangelogAutoOpen(true)
    end)
  end)

  describe("debug backpack dump", function()
    it("GetDebugBackpackDump returns empty table by default", function()
      local dump = DB:GetDebugBackpackDump()
      assert.is_not_nil(dump)
      assert.same({}, dump)
    end)

    it("SetDebugBackpackDump stores the given dump", function()
      local myDump = { { slotKey = "0_1", itemID = 12345 } }
      DB:SetDebugBackpackDump(myDump)
      local dump = DB:GetDebugBackpackDump()
      assert.are.same(myDump, dump)
    end)
  end)
end)
