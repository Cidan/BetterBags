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

addon:GetModule("Context")
local events = addon:GetModule("Events")
events:OnInitialize()

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
    showBagButton = true,
    enableBankBag = true,
    showBankTabs = false,
    debug = false,
    inBagSearch = true,
    categorySell = false,
    showKeybindWarning = true,
    enterToMakeCategory = true,
    upgradeIconProvider = 'None',
    theme = 'Default',
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
    categoryOptions = {},
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
  char = {},
}

-- Un-stub Database if it was previously stubbed by another spec (e.g. categories_spec)
ResetModuleStub("Database", "core/database.lua")

LoadBetterBagsModule("core/database.lua")
local DB = addon:GetModule("Database")

-- Stub Migrate to simplify test setup (we test migration behavior separately)
DB.Migrate = function() end

-- Initialize the database with our controlled defaults
DB:OnInitialize()

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

    it("GetShowBankTabs / SetShowBankTabs", function()
      DB:SetShowBankTabs(true)
      assert.is_true(DB:GetShowBankTabs())
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

  describe("extra glowy buttons", function()

    it("GetExtraGlowyButtons / SetExtraGlowyButtons", function()
      DB:SetExtraGlowyButtons(const.BAG_KIND.BACKPACK, true)
      assert.is_true(DB:GetExtraGlowyButtons(const.BAG_KIND.BACKPACK))
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

  describe("category options", function()

    it("GetCategoryOptions returns defaults for unknown category", function()
      local opts = DB:GetCategoryOptions("NewCategory")
      assert.is_true(opts.shown)
    end)

    it("GetCategoryOptions returns stored options", function()
      DB.data.profile.categoryOptions["TestCat"] = { shown = false }
      local opts = DB:GetCategoryOptions("TestCat")
      assert.is_false(opts.shown)
    end)
  end)

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
      DB.data.profile.categoryOptions["OldName"] = { shown = false }
      DB.data.profile.collapsedSections[const.BAG_KIND.BACKPACK]["OldName"] = true
      DB.data.profile.collapsedSections[const.BAG_KIND.BANK]["OldName"] = false
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

    it("updates categoryOptions", function()
      DB:RenameCategory("OldName", "NewName")
      assert.is_nil(DB.data.profile.categoryOptions["OldName"])
      assert.is_false(DB.data.profile.categoryOptions["NewName"].shown)
    end)

    it("updates collapsedSections for all kinds", function()
      DB:RenameCategory("OldName", "NewName")
      assert.is_true(DB.data.profile.collapsedSections[const.BAG_KIND.BACKPACK]["NewName"])
      assert.is_false(DB.data.profile.collapsedSections[const.BAG_KIND.BANK]["NewName"])
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
      DB.data.profile.categoryOptions["OldName - Consumable"] = { shown = true }
      DB.data.profile.collapsedSections[const.BAG_KIND.BACKPACK]["OldName - Consumable"] = true
      DB.data.profile.customSectionSort[const.BAG_KIND.BANK]["OldName - Consumable"] = 2

      DB:RenameCategory("OldName", "NewName")

      assert.is_nil(DB.data.profile.ephemeralCategoryFilters["OldName - Consumable"])
      assert.is_nil(DB.data.profile.categoryOptions["OldName - Consumable"])
      assert.is_nil(DB.data.profile.collapsedSections[const.BAG_KIND.BACKPACK]["OldName - Consumable"])
      assert.is_nil(DB.data.profile.customSectionSort[const.BAG_KIND.BANK]["OldName - Consumable"])
    end)
  end)

  -- ─── Section collapse ──────────────────────────────────────────────────────────

  describe("section collapse", function()

    it("GetSectionCollapsed returns false by default", function()
      assert.is_false(DB:GetSectionCollapsed(const.BAG_KIND.BACKPACK, "SomeSection"))
    end)

    it("SetSectionCollapsed sets collapse state", function()
      DB:SetSectionCollapsed(const.BAG_KIND.BANK, "MySection", true)
      assert.is_true(DB:GetSectionCollapsed(const.BAG_KIND.BANK, "MySection"))
    end)

    it("ToggleSectionCollapsed flips the state", function()
      DB:ToggleSectionCollapsed(const.BAG_KIND.BACKPACK, "ToggleMe")
      assert.is_true(DB:GetSectionCollapsed(const.BAG_KIND.BACKPACK, "ToggleMe"))
      DB:ToggleSectionCollapsed(const.BAG_KIND.BACKPACK, "ToggleMe")
      assert.is_false(DB:GetSectionCollapsed(const.BAG_KIND.BACKPACK, "ToggleMe"))
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
end)
