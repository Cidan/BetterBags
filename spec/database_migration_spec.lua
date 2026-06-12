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
events:OnInitialize()

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
const.BAG_VIEW = { UNDEFINED = 0, ONE_BAG = 1, SECTION_GRID = 2, LIST = 3, SECTION_ALL_BAGS = 4 }
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

-- Initialize — Migrate() runs inside OnInitialize with valid defaults
DB:OnInitialize()

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
      local original = DB.data.profile.size[const.BAG_VIEW.LIST][const.BAG_KIND.BACKPACK].itemsPerRow
      DB:Migrate()
      assert.are.equal(original, DB.data.profile.size[const.BAG_VIEW.LIST][const.BAG_KIND.BACKPACK].itemsPerRow)
    end)
  end)
end)
