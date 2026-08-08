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
    extraGlowyButtons = { [0] = false, [1] = false },
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
    collapsedSections = { [0] = {}, [1] = {} },
    size = {
      [1] = {
        [0] = { columnCount = 15, itemsPerRow = 15, scale = 100, width = 700, height = 500, opacity = 89 },
        [1] = { columnCount = 1, itemsPerRow = 15, scale = 100, width = 700, height = 500, opacity = 89 },
      },
      [2] = {
        [0] = { columnCount = 2, itemsPerRow = 7, scale = 100, width = 700, height = 500, opacity = 89 },
        [1] = { columnCount = 2, itemsPerRow = 7, scale = 100, width = 700, height = 500, opacity = 89 },
      },
      [3] = {
        [0] = { columnCount = 1, itemsPerRow = 15, scale = 100, width = 700, height = 500, opacity = 89 },
        [1] = { columnCount = 5, itemsPerRow = 5, scale = 100, width = 700, height = 500, opacity = 89 },
      },
      [4] = {
        [0] = { columnCount = 1, itemsPerRow = 15, scale = 100, width = 700, height = 500, opacity = 89 },
        [1] = { columnCount = 1, itemsPerRow = 15, scale = 100, width = 700, height = 500, opacity = 89 },
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

  describe("kind-scoped group migration", function()
    local BACKPACK = 0
    local BANK = 1

    -- The namespace AceDB copies in from the current defaults before Migrate
    -- runs. Its presence must not be read as "this profile is already scoped".
    local function injectedBackpackNamespace()
      return { [1] = { id = 1, name = "Backpack", order = 1, kind = BACKPACK, isDefault = true } }
    end

    local function scopedBankNamespace()
      return {
        [1] = { id = 1, name = "Bank", order = 1, kind = BANK,
                bankType = _G.Enum.BankType.Character, isDefault = true },
        [2] = { id = 2, name = "Warbank", order = 2, kind = BANK,
                bankType = _G.Enum.BankType.Account, isDefault = true },
      }
    end

    it("re-homes flat groups even though the backpack namespace already exists", function()
      DB.data.profile.groups = {
        [BACKPACK] = injectedBackpackNamespace(),
        [BANK] = {},
        [2] = { id = 2, name = "Legacy Group", order = 2 },
      }
      DB.data.profile.groupCounter = 2
      DB.data.profile.categoryToGroup = { [BACKPACK] = {}, [BANK] = {}, ["CatA"] = 2, ["CatB"] = 2 }

      DB:Migrate()

      local moved = DB.data.profile.groups[BACKPACK][2]
      assert.is_table(moved)
      assert.are.equal("Legacy Group", moved.name)
      assert.are.equal(BACKPACK, moved.kind)
      assert.are.equal(2, moved.id)
      assert.is_nil(DB.data.profile.groups[2])

      assert.are.equal(2, DB.data.profile.categoryToGroup[BACKPACK]["CatA"])
      assert.are.equal(2, DB.data.profile.categoryToGroup[BACKPACK]["CatB"])
      assert.is_nil(DB.data.profile.categoryToGroup["CatA"])
      assert.is_nil(DB.data.profile.categoryToGroup["CatB"])

      assert.are.equal(2, DB.data.profile.groupCounter[BACKPACK])
    end)

    it("repairs profiles the old migration flagged without converting", function()
      -- Exactly what a live profile looks like after the broken conversion: the
      -- markers are set, the bank namespace was filled in afterwards, and the
      -- user's group plus its category assignments were left at the top level.
      DB.data.profile.__groupsScopedByKind = true
      DB.data.profile.__bankDefaultTabsFixed = true
      DB.data.profile.groups = {
        [BACKPACK] = injectedBackpackNamespace(),
        [BANK] = scopedBankNamespace(),
        [2] = { id = 2, name = "Legacy Group", order = 2 },
      }
      DB.data.profile.groupCounter = { [BACKPACK] = 2, [BANK] = 2 }
      DB.data.profile.categoryToGroup = { [BACKPACK] = {}, [BANK] = {}, ["CatA"] = 2 }

      DB:Migrate()

      assert.are.equal("Legacy Group", DB.data.profile.groups[BACKPACK][2].name)
      assert.is_nil(DB.data.profile.groups[2])
      assert.are.equal(2, DB.data.profile.categoryToGroup[BACKPACK]["CatA"])
      assert.is_nil(DB.data.profile.categoryToGroup["CatA"])

      -- The bank namespace is untouched, so no duplicate default tabs appear.
      assert.are.equal("Bank", DB.data.profile.groups[BANK][1].name)
      assert.are.equal("Warbank", DB.data.profile.groups[BANK][2].name)
      assert.is_nil(DB.data.profile.groups[BANK][3])

      -- The obsolete markers are cleared out of the profile.
      assert.is_nil(DB.data.profile.__groupsScopedByKind)
      assert.is_nil(DB.data.profile.__bankDefaultTabsFixed)
    end)

    it("keeps a scoped category assignment over the orphaned flat one", function()
      DB.data.profile.groups = {
        [BACKPACK] = {
          [1] = { id = 1, name = "Backpack", order = 1, kind = BACKPACK, isDefault = true },
          [5] = { id = 5, name = "Newer Group", order = 5, kind = BACKPACK },
        },
        [BANK] = scopedBankNamespace(),
        [2] = { id = 2, name = "Legacy Group", order = 2 },
      }
      DB.data.profile.groupCounter = { [BACKPACK] = 5, [BANK] = 2 }
      -- CatA was re-assigned to group 5 after the flat entry was orphaned.
      DB.data.profile.categoryToGroup = {
        [BACKPACK] = { ["CatA"] = 5 },
        [BANK] = {},
        ["CatA"] = 2,
        ["CatB"] = 2,
      }

      DB:Migrate()

      assert.are.equal(5, DB.data.profile.categoryToGroup[BACKPACK]["CatA"])
      assert.are.equal(2, DB.data.profile.categoryToGroup[BACKPACK]["CatB"])
      assert.is_nil(DB.data.profile.categoryToGroup["CatA"])
    end)

    it("moves a flat group sitting on the bank kind key to the backpack", function()
      DB.data.profile.groups = {
        [BACKPACK] = injectedBackpackNamespace(),
        -- Legacy group ID 1 collides with BAG_KIND.BANK.
        [1] = { id = 1, name = "Backpack", order = 1 },
      }
      DB.data.profile.groupCounter = 1
      DB.data.profile.categoryToGroup = { ["CatA"] = 1 }

      DB:Migrate()

      assert.are.equal("Backpack", DB.data.profile.groups[BACKPACK][1].name)
      assert.is_true(DB.data.profile.groups[BACKPACK][1].isDefault)
      assert.are.equal(BACKPACK, DB.data.profile.groups[BACKPACK][1].kind)
      assert.are.equal(1, DB.data.profile.categoryToGroup[BACKPACK]["CatA"])

      -- The bank namespace was rebuilt and refilled with its default tabs.
      assert.are.equal("Bank", DB.data.profile.groups[BANK][1].name)
      assert.are.equal("Warbank", DB.data.profile.groups[BANK][2].name)
    end)

    it("leaves already scoped data alone and is safe to run repeatedly", function()
      DB.data.profile.groups = {
        [BACKPACK] = {
          [1] = { id = 1, name = "Backpack", order = 1, kind = BACKPACK, isDefault = true },
          [3] = { id = 3, name = "User Group", order = 3, kind = BACKPACK },
        },
        [BANK] = scopedBankNamespace(),
      }
      DB.data.profile.groupCounter = { [BACKPACK] = 3, [BANK] = 2 }
      DB.data.profile.categoryToGroup = { [BACKPACK] = { ["CatA"] = 3 }, [BANK] = {} }

      DB:Migrate()
      DB:Migrate()

      local backpackGroups = DB.data.profile.groups[BACKPACK]
      local count = 0
      for _ in pairs(backpackGroups) do count = count + 1 end
      assert.are.equal(2, count)
      assert.are.equal("User Group", backpackGroups[3].name)
      assert.are.equal(3, DB.data.profile.categoryToGroup[BACKPACK]["CatA"])
      assert.are.equal(3, DB.data.profile.groupCounter[BACKPACK])
    end)

    it("allocates a fresh ID when a flat group's slot is already taken", function()
      DB.data.profile.groups = {
        [BACKPACK] = {
          [1] = { id = 1, name = "Backpack", order = 1, kind = BACKPACK, isDefault = true },
          [2] = { id = 2, name = "Existing Group", order = 2, kind = BACKPACK },
        },
        [BANK] = scopedBankNamespace(),
        [2] = { id = 2, name = "Legacy Group", order = 2 },
      }
      DB.data.profile.groupCounter = { [BACKPACK] = 2, [BANK] = 2 }
      DB.data.profile.categoryToGroup = { [BACKPACK] = {}, [BANK] = {}, ["CatA"] = 2 }

      DB:Migrate()

      assert.are.equal("Existing Group", DB.data.profile.groups[BACKPACK][2].name)
      assert.are.equal("Legacy Group", DB.data.profile.groups[BACKPACK][3].name)
      assert.are.equal(3, DB.data.profile.groups[BACKPACK][3].id)
      -- The assignment follows the group to its new ID.
      assert.are.equal(3, DB.data.profile.categoryToGroup[BACKPACK]["CatA"])
      assert.are.equal(3, DB.data.profile.groupCounter[BACKPACK])
    end)
  end)
end)
