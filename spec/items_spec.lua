-- items_spec.lua -- Unit tests for data/items.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Ensure all dependencies exist before loading items.lua
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
local events = addon:GetModule("Events")
events:Init()

-- Stubs for modules items.lua depends on
local debug = StubBetterBagsModule("Debug")
debug.Log = function() end
debug.Inspect = function() end

local database = StubBetterBagsModule("Database")
local const = StubBetterBagsModule("Constants")
local L = StubBetterBagsModule("Localization")
function L:G(key) return key end

local equipmentSets = StubBetterBagsModule("EquipmentSets")
equipmentSets.GetItemSets = function() return nil end
-- RunRefresh rebuilds the equipment-set location map each sweep.
equipmentSets.Update = equipmentSets.Update or function() end

local tooltipScanner = StubBetterBagsModule("TooltipScanner")
tooltipScanner.GetTooltipText = function() return "" end

LoadBetterBagsModule("util/query.lua")
LoadBetterBagsModule("util/trees/trees.lua")
LoadBetterBagsModule("util/trees/intervaltree.lua")
LoadBetterBagsModule("data/search.lua")
LoadBetterBagsModule("core/async.lua")
local async = addon:GetModule("Async")
async.Yield = function() end
LoadBetterBagsModule("data/stacks.lua")
ResetModuleStub("Binding", "data/binding.lua")
LoadBetterBagsModule("data/binding.lua")

local categories
local ok = pcall(function() return addon:GetModule("Categories") end)
if not ok then
  categories = StubBetterBagsModule("Categories")
else
  categories = addon:GetModule("Categories")
end
categories.GetSortedSearchCategories = categories.GetSortedSearchCategories or function() return {} end
categories.GetCustomCategory = categories.GetCustomCategory or function() return nil, nil end
categories.DoesCategoryExist = categories.DoesCategoryExist or function() return false end

-- Set up constants
const.BAG_KIND = { UNDEFINED = -1, BACKPACK = 0, BANK = 1 }
const.BAG_VIEW = { UNDEFINED = 0, SECTION_GRID = 2, SECTION_ALL_BAGS = 4 }
const.BANK_BAGS = { [6] = 6, [7] = 7, [8] = 8, [9] = 9, [10] = 10, [11] = 11 }
const.ACCOUNT_BANK_BAGS = { [13] = 13, [14] = 14, [15] = 15, [16] = 16, [17] = 17 }
const.BACKPACK_BAGS = { [0] = 0, [1] = 1, [2] = 2, [3] = 3, [4] = 4 }
const.BINDING_SCOPE = {
  UNKNOWN = 0,
  NONBINDING = 1,
  BOUND = 2,
  BOE = 3,
  BOU = 4,
  QUEST = 5,
  SOULBOUND = 6,
  REFUNDABLE = 7,
  ACCOUNT = 8,
  BNET = 9,
  WUE = 10,
}
const.ITEM_QUALITY = { Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
const.BAG_SUBTYPE_TO_QUALITY = { [0] = 1, [1] = 2, [2] = 2, [3] = 2, [4] = 2, [99] = 2 }
const.SEARCH_CATEGORY_GROUP_BY = { NONE = 0, TYPE = 1, SUBTYPE = 2, EXPANSION = 3 }
const.EXPANSION_MAP = { [0] = "Classic", [1] = "Burning Crusade", [2] = "Wrath", [9] = "The War Within" }
const.TRADESKILL_MAP = { [0] = "Tailoring", [1] = "Leatherworking", [2] = "Blacksmithing" }
const.BINDING_MAP = {
  [0] = "",
  [1] = "boe",
  [2] = "soulbound",
}
const.BRIEF_EXPANSION_MAP = {
  [0] = "classic",
  [1] = "bc",
  [2] = "wotlk",
  [3] = "cata",
  [9] = "tww",
}
const.INVENTORY_TYPE_TO_INVENTORY_SLOTS = {
  [1] = {1},
}

_G.Enum = _G.Enum or {}
_G.Enum.ItemClass = _G.Enum.ItemClass or { Tradegoods = 7, Container = 1 }

database.GetUpgradeIconProvider = database.GetUpgradeIconProvider or function() return "None" end
database.GetUpgradeIconProviderUserSet = function() return true end
database.GetNewItemTime = function() return 30 end
database.GetStackingOptions = function()
  return { dontMergeTransmog = false }
end
database.GetCategoryFilter = function() return false end
database.GetEnableBankBag = function() return false end
database.GetMarkRecentItems = function() return false end
database.GetShowAllFreeSpace = function() return true end

addon.isRetail = true
addon.isClassic = false

-- Stub Stacks inside setups, as we're JIT-loading Stacks
local stacksMod = StubBetterBagsModule("Stacks")
stacksMod.Create = function()
  return {
    RemoveFromStack = function() end,
    AddToStack = function() end,
    Clear = function() end,
    GetStackInfo = function() return nil end,
  }
end

-- Load the new items module
ResetModuleStub("Items", "data/items.lua")
LoadBetterBagsModule("data/items.lua")
LoadBetterBagsModule("data/slots.lua")
local items = addon:GetModule("Items")

describe("Items (New Data Farming Engine)", function()
  before_each(function()
    items:Init()
  end)

  describe("Initialization & Stubs", function()
    it("initializes empty slots, caches and lists safely", function()
      assert.is_not_nil(items.searchCache)
      assert.is_not_nil(items.categoryPriorityCache)
      assert.is_not_nil(items._newItemTimers)
      assert.is_not_nil(items.slotInfo)
    end)

    it("has stubs for all legacy methods to prevent crash on boot", function()
      -- Assert stubs exist and can be called safely
      assert.is_nil(items:GetSearchCategory(0, "0_1"))
      assert.is_nil(items:GetStackData({}))

      local called = false
      items:Restack({}, 0, function() called = true end)
      assert.is_true(called)
    end)
  end)

  describe("Utility Methods", function()
    it("GetSlotKey formats bag and slot", function()
      local data = { bagid = 3, slotid = 5 }
      assert.are.equal("3_5", items:GetSlotKey(data))
    end)

    it("GetBagKindFromBagID matches backpack and bank bags", function()
      assert.are.equal(const.BAG_KIND.BACKPACK, items:GetBagKindFromBagID(1))
      assert.are.equal(const.BAG_KIND.BANK, items:GetBagKindFromBagID(6))
    end)
  end)

  describe("Harvesting Engine", function()
    local savedContainerIDToInventoryID
    local savedGetItemSubClassInfo
    local savedGetInventoryItemLink
    local savedGetContainerNumSlots
    local savedGetContainerItemID
    local savedGetContainerItemLink
    local savedGetContainerItemInfo

    before_each(function()
      savedContainerIDToInventoryID = _G.C_Container.ContainerIDToInventoryID
      savedGetItemSubClassInfo = _G.C_Item.GetItemSubClassInfo
      savedGetInventoryItemLink = _G.GetInventoryItemLink
      savedGetContainerNumSlots = _G.C_Container.GetContainerNumSlots
      savedGetContainerItemID = _G.C_Container.GetContainerItemID
      savedGetContainerItemLink = _G.C_Container.GetContainerItemLink
      savedGetContainerItemInfo = _G.C_Container.GetContainerItemInfo

      _G.C_Container.ContainerIDToInventoryID = function() return nil end
      _G.C_Item.GetItemSubClassInfo = function() return "MockSubClass" end
      _G.GetInventoryItemLink = function() return nil end

      -- Default mock container state (empty bag)
      _G.C_Container.GetContainerNumSlots = function(bagid) return 2 end
      _G.C_Container.GetContainerItemID = function(bagid, slotid) return nil end
      _G.C_Container.GetContainerItemLink = function(bagid, slotid) return nil end
      _G.C_Container.GetContainerItemInfo = function(bagid, slotid) return nil end
    end)

    after_each(function()
      _G.C_Container.ContainerIDToInventoryID = savedContainerIDToInventoryID
      _G.C_Item.GetItemSubClassInfo = savedGetItemSubClassInfo
      _G.GetInventoryItemLink = savedGetInventoryItemLink
      _G.C_Container.GetContainerNumSlots = savedGetContainerNumSlots
      _G.C_Container.GetContainerItemID = savedGetContainerItemID
      _G.C_Container.GetContainerItemLink = savedGetContainerItemLink
      _G.C_Container.GetContainerItemInfo = savedGetContainerItemInfo
    end)

    it("harvests correct physical data from a mocked bag configuration", function()
      -- Stub C_Container calls to return a valid item in bag 0 slot 1
      _G.C_Container.GetContainerItemID = function(bagid, slotid)
        if bagid == 0 and slotid == 1 then return 12345 end
        return nil
      end
      _G.C_Container.GetContainerItemLink = function(bagid, slotid)
        if bagid == 0 and slotid == 1 then return "|cff0070dd|Hitem:12345|h[Test Sword]|h|r" end
        return nil
      end

      -- Mock C_Item.GetItemInfo
      local savedGetItemInfo = _G.C_Item.GetItemInfo
      _G.C_Item.GetItemInfo = function(itemID)
        return "Test Sword", "|cff0070dd|Hitem:12345|h[Test Sword]|h|r", 3, 100, 1, "Weapon", "One-Handed Swords", 1, "INVTYPE_WEAPON", 134400, 100, 2, 0, 1, 0, 0, false
      end

      local itemsMap = items:Harvest(const.BAG_KIND.BACKPACK, { [0] = 0 })

      _G.C_Item.GetItemInfo = savedGetItemInfo

      -- Check harvested items map
      assert.is_not_nil(itemsMap)
      assert.is_not_nil(itemsMap["0_1"])
      assert.is_false(itemsMap["0_1"].isItemEmpty)
      assert.are.equal(12345, itemsMap["0_1"].itemInfo.itemID)
      assert.are.equal("Test Sword", itemsMap["0_1"].itemInfo.itemName)

      -- Check slot 2 which was mocked empty
      assert.is_not_nil(itemsMap["0_2"])
      assert.is_true(itemsMap["0_2"].isItemEmpty)
    end)
  end)

  -- Regression for issue #1090: on login with very full bags the item cache is cold,
  -- so C_Item.GetItemInfo(itemID) returns nil type/subtype and every affected item was
  -- dumped into "Everything". The categorization-relevant fields (itemType, itemSubType,
  -- itemEquipLoc, classID, subclassID) are ALL available from C_Item.GetItemInfoInstant,
  -- which never queries the server and always returns for a valid item, so categorization
  -- must be sourced from it and stay correct even when GetItemInfo is cold.
  describe("Cold item cache categorization (login, issue #1090)", function()
    local savedGetItemInfo
    local savedGetItemInfoInstant
    local savedGetContainerNumSlots
    local savedGetContainerItemID
    local savedGetContainerItemLink
    local savedGetContainerItemInfo
    local savedGetCategoryFilter

    before_each(function()
      savedGetItemInfo = _G.C_Item.GetItemInfo
      savedGetItemInfoInstant = _G.C_Item.GetItemInfoInstant
      savedGetContainerNumSlots = _G.C_Container.GetContainerNumSlots
      savedGetContainerItemID = _G.C_Container.GetContainerItemID
      savedGetContainerItemLink = _G.C_Container.GetContainerItemLink
      savedGetContainerItemInfo = _G.C_Container.GetContainerItemInfo
      savedGetCategoryFilter = database.GetCategoryFilter

      -- A single valid item in bag 0 slot 1.
      _G.C_Container.GetContainerNumSlots = function(bagid) return bagid == 0 and 1 or 0 end
      _G.C_Container.GetContainerItemID = function(bagid, slotid)
        if bagid == 0 and slotid == 1 then return 12345 end
        return nil
      end
      _G.C_Container.GetContainerItemLink = function(bagid, slotid)
        if bagid == 0 and slotid == 1 then return "|cff0070dd|Hitem:12345|h[Cold Sword]|h|r" end
        return nil
      end
      _G.C_Container.GetContainerItemInfo = function() return nil end

      -- COLD CACHE: GetItemInfo returns nothing (exactly what an uncached item returns
      -- during the login sweep).
      _G.C_Item.GetItemInfo = function() return nil end

      -- GetItemInfoInstant is cold-proof and returns the instant fields:
      -- itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID.
      _G.C_Item.GetItemInfoInstant = function()
        return 12345, "Weapon", "One-Handed Swords", "INVTYPE_WEAPON", 134400, 2, 7
      end

      -- Only the Type filter is on, so a warm categorization yields exactly "Weapon".
      database.GetCategoryFilter = function(_, _, filter)
        return filter == "Type"
      end
    end)

    after_each(function()
      _G.C_Item.GetItemInfo = savedGetItemInfo
      _G.C_Item.GetItemInfoInstant = savedGetItemInfoInstant
      _G.C_Container.GetContainerNumSlots = savedGetContainerNumSlots
      _G.C_Container.GetContainerItemID = savedGetContainerItemID
      _G.C_Container.GetContainerItemLink = savedGetContainerItemLink
      _G.C_Container.GetContainerItemInfo = savedGetContainerItemInfo
      database.GetCategoryFilter = savedGetCategoryFilter
    end)

    it("categorizes a cold-cache item by its instant type, not into Everything", function()
      local ctx = { Get = function() return nil end, Set = function() end }
      local itemsMap = items:Harvest(const.BAG_KIND.BACKPACK, { [0] = 0 })
      local data = itemsMap["0_1"]

      assert.is_not_nil(data)
      assert.is_false(data.isItemEmpty)
      -- The instant type/subtype must have been captured despite the cold GetItemInfo.
      assert.are.equal("Weapon", data.itemInfo.itemType)
      assert.are.equal("One-Handed Swords", data.itemInfo.itemSubType)
      assert.are.equal("INVTYPE_WEAPON", data.itemInfo.itemEquipLoc)
      assert.are.equal(2, data.itemInfo.classID)
      assert.are.equal(7, data.itemInfo.subclassID)

      -- The bug: this resolved to "Everything". It must be the real type.
      assert.are.equal("Weapon", items:GetCategory(ctx, data))
    end)
  end)

  describe("Category Enrichment & Search Cache", function()
    local savedContainerIDToInventoryID
    local savedGetItemSubClassInfo
    local savedGetInventoryItemLink
    local savedGetContainerNumSlots
    local savedGetContainerItemID
    local savedGetContainerItemLink
    local savedGetContainerItemInfo

    before_each(function()
      savedContainerIDToInventoryID = _G.C_Container.ContainerIDToInventoryID
      savedGetItemSubClassInfo = _G.C_Item.GetItemSubClassInfo
      savedGetInventoryItemLink = _G.GetInventoryItemLink
      savedGetContainerNumSlots = _G.C_Container.GetContainerNumSlots
      savedGetContainerItemID = _G.C_Container.GetContainerItemID
      savedGetContainerItemLink = _G.C_Container.GetContainerItemLink
      savedGetContainerItemInfo = _G.C_Container.GetContainerItemInfo

      _G.C_Container.ContainerIDToInventoryID = function() return nil end
      _G.C_Item.GetItemSubClassInfo = function() return "MockSubClass" end
      _G.GetInventoryItemLink = function() return nil end

      _G.C_Container.GetContainerNumSlots = function(bagid) return 2 end
      _G.C_Container.GetContainerItemID = function(bagid, slotid) return nil end
      _G.C_Container.GetContainerItemLink = function(bagid, slotid) return nil end
      _G.C_Container.GetContainerItemInfo = function(bagid, slotid) return nil end

      local search = addon:GetModule("Search")
      search:Init()
    end)

    after_each(function()
      _G.C_Container.ContainerIDToInventoryID = savedContainerIDToInventoryID
      _G.C_Item.GetItemSubClassInfo = savedGetItemSubClassInfo
      _G.GetInventoryItemLink = savedGetInventoryItemLink
      _G.C_Container.GetContainerNumSlots = savedGetContainerNumSlots
      _G.C_Container.GetContainerItemID = savedGetContainerItemID
      _G.C_Container.GetContainerItemLink = savedGetContainerItemLink
      _G.C_Container.GetContainerItemInfo = savedGetContainerItemInfo
    end)

    it("updates and cleans search cache, resolving search categories priority-wise", function()
      local search = addon:GetModule("Search")
      local originalSearch = search.Search
      search.Search = function(self, query)
        if query == "potion" then
          return { ["0_1"] = true }
        end
        return {}
      end

      local originalGetSortedSearchCategories = categories.GetSortedSearchCategories
      categories.GetSortedSearchCategories = function()
        return {
          {
            name = "CustomSearchCat",
            enabled = { [const.BAG_KIND.BACKPACK] = true, [const.BAG_KIND.BANK] = true },
            searchCategory = { query = "potion", groupBy = const.SEARCH_CATEGORY_GROUP_BY.NONE },
            priority = 5,
          }
        }
      end

      items:RefreshSearchCache(const.BAG_KIND.BACKPACK)
      assert.are.equal("CustomSearchCat", items:GetSearchCategory(const.BAG_KIND.BACKPACK, "0_1"))

      items:WipeSearchCache(const.BAG_KIND.BACKPACK)
      assert.is_nil(items:GetSearchCategory(const.BAG_KIND.BACKPACK, "0_1"))

      search.Search = originalSearch
      categories.GetSortedSearchCategories = originalGetSortedSearchCategories
    end)

    it("assigns categories dynamically during ProcessRefresh after search indexing", function()
      _G.C_Container.GetContainerNumSlots = function(bagid) return 1 end
      _G.C_Container.GetContainerItemID = function(bagid, slotid) return 12345 end
      _G.C_Container.GetContainerItemLink = function(bagid, slotid) return "|cff0070dd|Hitem:12345|h[Test Sword]|h|r" end

      local savedGetItemInfo = _G.C_Item.GetItemInfo
      _G.C_Item.GetItemInfo = function(itemID)
        return "Test Sword", "|cff0070dd|Hitem:12345|h[Test Sword]|h|r", 3, 100, 1, "Weapon", "One-Handed Swords", 1, "INVTYPE_WEAPON", 134400, 100, 2, 0, 1, 0, 0, false
      end

      local search = addon:GetModule("Search")
      local originalSearch = search.Search
      search.Search = function(self, query)
        if query == "sword" then
          return { ["0_1"] = true }
        end
        return {}
      end

      local originalGetSortedSearchCategories = categories.GetSortedSearchCategories
      categories.GetSortedSearchCategories = function()
        return {
          {
            name = "MySwordCategory",
            enabled = { [const.BAG_KIND.BACKPACK] = true },
            searchCategory = { query = "sword", groupBy = const.SEARCH_CATEGORY_GROUP_BY.NONE },
            priority = 1,
          }
        }
      end

      local ctx = addon:GetModule("Context"):New("TestRefresh")
      items:ProcessRefresh(ctx, const.BAG_KIND.BACKPACK)

      local slotInfo = items.slotInfo[const.BAG_KIND.BACKPACK]
      local item = slotInfo.itemsBySlotKey["0_1"]
      assert.is_not_nil(item)
      assert.are.equal("MySwordCategory", item.itemInfo.category)

      _G.C_Item.GetItemInfo = savedGetItemInfo
      search.Search = originalSearch
      categories.GetSortedSearchCategories = originalGetSortedSearchCategories
    end)

    it("pre-computes currentItem.isUpgrade correctly during ProcessRefresh", function()
      _G.C_Container.GetContainerNumSlots = function(bagid) return 1 end
      _G.C_Container.GetContainerItemID = function(bagid, slotid) return 12345 end
      _G.C_Container.GetContainerItemLink = function(bagid, slotid) return "|cff0070dd|Hitem:12345|h[Test Sword]|h|r" end

      local savedGetItemInfo = _G.C_Item.GetItemInfo
      _G.C_Item.GetItemInfo = function(itemID)
        return "Test Sword", "|cff0070dd|Hitem:12345|h[Test Sword]|h|r", 3, 100, 1, "Weapon", "One-Handed Swords", 1, "INVTYPE_WEAPON", 134400, 100, 2, 0, 1, 0, 0, false
      end

      local DB = addon:GetModule("Database")
      local originalGetUpgradeIconProvider = DB.GetUpgradeIconProvider
      DB.GetUpgradeIconProvider = function() return "BetterBags" end

      local originalGetCurrentItemLevel = _G.C_Item.GetCurrentItemLevel
      _G.C_Item.GetCurrentItemLevel = function() return 100 end

      -- Let's mock GetItemDataFromInventorySlot
      local originalGetItemDataFromInventorySlot = items.GetItemDataFromInventorySlot
      items.GetItemDataFromInventorySlot = function(self, slot)
        return {
          isItemEmpty = false,
          itemInfo = {
            currentItemLevel = 90
          }
        }
      end

      local ctx = addon:GetModule("Context"):New("TestRefresh")
      items:ProcessRefresh(ctx, const.BAG_KIND.BACKPACK)

      local slotInfo = items.slotInfo[const.BAG_KIND.BACKPACK]
      local item = slotInfo.itemsBySlotKey["0_1"]
      assert.is_not_nil(item)
      assert.is_true(item.isUpgrade)

      -- Clean up
      _G.C_Item.GetItemInfo = savedGetItemInfo
      _G.C_Item.GetCurrentItemLevel = originalGetCurrentItemLevel
      DB.GetUpgradeIconProvider = originalGetUpgradeIconProvider
      items.GetItemDataFromInventorySlot = originalGetItemDataFromInventorySlot
    end)
  end)

  describe("Bug 2: Warbank free space counts by splitting empty slots", function()
    it("should split emptySlots by bag id and populate emptySlotsByBag", function()
      addon.isRetail = true
      const.BANK_BAGS = { [6] = 6, [7] = 7 }
      const.ACCOUNT_BANK_BAGS = { [13] = 13, [14] = 14 }
      const.BANK_TAB = { BANK = -1, ACCOUNT_BANK_1 = -3 }

      local originalGetContainerNumFreeSlots = _G.C_Container.GetContainerNumFreeSlots
      _G.C_Container.GetContainerNumFreeSlots = function(bagid)
        if bagid == 6 then return 5 end
        if bagid == 7 then return 3 end
        if bagid == 13 then return 10 end
        if bagid == 14 then return 12 end
        return 0
      end

      local originalGetItemSubClassInfo = _G.C_Item.GetItemSubClassInfo
      _G.C_Item.GetItemSubClassInfo = function(class, subclass)
        return "Bag"
      end

      local originalGetInventoryItemLink = _G.GetInventoryItemLink
      _G.GetInventoryItemLink = function(player, invid)
        return nil -- Fallback to general subclass container 0
      end

      local ctx = addon:GetModule("Context"):New("TestFreeSlots")
      items:WipeSlotInfo(const.BAG_KIND.BANK)
      local _, emptySlotsByBag = items:Phase5_UpdateFreeSlots(ctx, const.BAG_KIND.BANK)

      assert.is_not_nil(emptySlotsByBag)
      assert.are.equal(5, emptySlotsByBag[6].count)
      assert.are.equal("Bag", emptySlotsByBag[6].name)
      assert.are.equal(3, emptySlotsByBag[7].count)
      assert.are.equal(10, emptySlotsByBag[13].count)
      assert.are.equal(12, emptySlotsByBag[14].count)

      -- Restore mocks
      _G.C_Container.GetContainerNumFreeSlots = originalGetContainerNumFreeSlots
      _G.C_Item.GetItemSubClassInfo = originalGetItemSubClassInfo
      _G.GetInventoryItemLink = originalGetInventoryItemLink
    end)
  end)

  describe("Synthesis of sortedCategories", function()
    it("should synthesize and sort categories after ProcessRefresh", function()
      _G.C_Container.GetContainerNumSlots = function(bagid) return 2 end
      _G.C_Container.GetContainerItemID = function(bagid, slotid) return 1000 + slotid end
      _G.C_Container.GetContainerItemLink = function(bagid, slotid) return "|cff0070dd|Hitem:"..(1000+slotid).."|h[Item "..slotid.."]|h|r" end

      local savedGetItemInfo = _G.C_Item.GetItemInfo
      _G.C_Item.GetItemInfo = function(itemID)
        local id = tonumber(itemID)
        if not id and type(itemID) == "string" then
          id = tonumber(string.match(itemID, "item:(%d+)"))
        end
        id = id or 1001
        local name = "Item " .. (id - 1000)
        local quality = 1
        local class = "Weapon"
        local subclass = "One-Handed Swords"
        if id == 1001 then
          class = "Armor"
          subclass = "Shields"
        end
        return name, "|cff0070dd|Hitem:"..id.."|h["..name.."]|h|r", quality, 100, 1, class, subclass, 1, "INVTYPE_WEAPON", 134400, 100, 2, 0, 1, 0, 0, false
      end

      -- Stub Database to return simple alphabetical sort for sections
      local DB = addon:GetModule("Database")
      DB.GetSectionSortType = function() return const.SECTION_SORT_TYPE.ALPHABETICALLY end
      DB.GetCustomSectionSort = function() return {} end
      local originalGetCategoryFilter = DB.GetCategoryFilter
      function DB:GetCategoryFilter(kind, filter)
        return filter == "Type"
      end

      local ctx = addon:GetModule("Context"):New("TestCategorySynthesis")
      items:ProcessRefresh(ctx, const.BAG_KIND.BACKPACK)

      local slotInfo = items.slotInfo[const.BAG_KIND.BACKPACK]
      assert.is_not_nil(slotInfo.sortedCategories)
      assert.is_true(#slotInfo.sortedCategories > 0)

      -- Verify we have categories and they are sorted alphabetically by default
      local hasWeapon = false
      local hasArmor = false
      for _, cat in ipairs(slotInfo.sortedCategories) do
        if cat.name == "Weapon" then hasWeapon = true end
        if cat.name == "Armor" then hasArmor = true end
      end
      -- Weapons and Armor categories should have been synthesized from class names
      assert.is_true(hasWeapon or hasArmor)

      -- Restore mocks
      _G.C_Item.GetItemInfo = savedGetItemInfo
      DB.GetCategoryFilter = originalGetCategoryFilter
    end)

    it("should retain physical order of categories in SECTION_ALL_BAGS mode and not sort them alphabetically", function()
      -- Set up SECTION_ALL_BAGS view
      local DB = addon:GetModule("Database")
      local originalGetBagView = DB.GetBagView
      DB.GetBagView = function() return const.BAG_VIEW.SECTION_ALL_BAGS end

      -- Mock bags and their names
      local savedGetBagName = _G.C_Container.GetBagName
      _G.C_Container.GetBagName = function(bagid)
        if bagid == 1 then return "#1: Bag 1" end
        if bagid == 2 then return "#2: Bag 2" end
        if bagid == 10 then return "#10: Bag 10" end
        return nil
      end

      -- Mock items across those bag IDs
      -- We return 1 slot for bags 1, 2, and 10
      local savedGetContainerNumSlots = _G.C_Container.GetContainerNumSlots
      _G.C_Container.GetContainerNumSlots = function(bagid)
        if bagid == 1 or bagid == 2 or bagid == 10 then return 1 end
        return 0
      end

      local savedGetContainerItemID = _G.C_Container.GetContainerItemID
      _G.C_Container.GetContainerItemID = function(bagid, slotid)
        if bagid == 1 or bagid == 2 or bagid == 10 then return 1000 + bagid end
        return nil
      end

      local savedGetContainerItemLink = _G.C_Container.GetContainerItemLink
      _G.C_Container.GetContainerItemLink = function(bagid, slotid)
        if bagid == 1 or bagid == 2 or bagid == 10 then
          return "|cff0070dd|Hitem:"..(1000+bagid).."|h[Item "..bagid.."]|h|r"
        end
        return nil
      end

      local savedGetItemInfo = _G.C_Item.GetItemInfo
      _G.C_Item.GetItemInfo = function(itemID)
        local id = tonumber(itemID)
        if not id and type(itemID) == "string" then
          id = tonumber(string.match(itemID, "item:(%d+)"))
        end
        id = id or 1001
        return "Item " .. id, "|cff0070dd|Hitem:"..id.."|h[Item "..id.."]|h|r", 1, 100, 1, "Misc", "Junk", 1, "INVTYPE_WEAPON", 134400, 100, 2, 0, 1, 0, 0, false
      end

      -- Force Sort module to be active with standard alphabetical category sort
      local sortModule = StubBetterBagsModule("Sort")
      sortModule.SortItemDataBySlot = function(a, b)
        if not a then return false end
        if not b then return true end
        if a.bagid ~= b.bagid then
          return a.bagid < b.bagid
        end
        return a.slotid < b.slotid
      end
      local originalGetCategoryDataSortFunction = sortModule.GetCategoryDataSortFunction
      sortModule.GetCategoryDataSortFunction = function()
        -- Return standard alphabetical sort logic for categories
        return function(a, b)
          return a.name < b.name
        end
      end

      local ctx = addon:GetModule("Context"):New("TestPhysicalCategoryOrder")
      items:WipeSlotInfo(const.BAG_KIND.BACKPACK)

      -- Let's construct a list of active bags including 1, 2, 10
      local activeBags = { [1] = 1, [2] = 2, [10] = 10 }

      -- We override BACKPACK_BAGS temporarily so that ProcessRefresh knows these bags are active
      local originalBackpackBags = const.BACKPACK_BAGS
      const.BACKPACK_BAGS = activeBags

      -- Let's use ProcessRefresh which internally calls Harvest and assigns categories
      items:ProcessRefresh(ctx, const.BAG_KIND.BACKPACK)

      local slotInfo = items.slotInfo[const.BAG_KIND.BACKPACK]
      assert.is_not_nil(slotInfo.sortedCategories)

      -- If physical ordering is preserved, the order should be: Bag 1, Bag 2, Bag 10
      -- If alphabetical sort was applied, Bag 10 would sort before Bag 2
      local order = {}
      for _, cat in ipairs(slotInfo.sortedCategories) do
        table.insert(order, cat.name)
      end

      assert.are.equal("#2: #1: Bag 1", order[1])
      assert.are.equal("#3: #2: Bag 2", order[2])
      assert.are.equal("#11: #10: Bag 10", order[3])

      -- Restore all mocks
      DB.GetBagView = originalGetBagView
      _G.C_Container.GetBagName = savedGetBagName
      _G.C_Container.GetContainerNumSlots = savedGetContainerNumSlots
      _G.C_Container.GetContainerItemID = savedGetContainerItemID
      _G.C_Container.GetContainerItemLink = savedGetContainerItemLink
      _G.C_Item.GetItemInfo = savedGetItemInfo
      sortModule.GetCategoryDataSortFunction = originalGetCategoryDataSortFunction
      const.BACKPACK_BAGS = originalBackpackBags
    end)
  end)

  describe("Tab Partitioning (Phase 4.5)", function()
    it("pre-partitions slotInfo.tabs based on active groups and configurations", function()
      -- Enable groups in Database
      local DB = addon:GetModule("Database")
      local originalGetGroupsEnabled = DB.GetGroupsEnabled
      DB.GetGroupsEnabled = function() return true end

      local originalGetCategoryFilter = DB.GetCategoryFilter
      DB.GetCategoryFilter = function(self, kind, filter)
        return filter == "Type"
      end

      -- Mock a group
      local groups = addon:GetModule("Groups", true)
      if not groups then
        ResetModuleStub("Groups", "data/groups.lua")
        LoadBetterBagsModule("data/groups.lua")
        groups = addon:GetModule("Groups")
      end
      local originalGetAllGroups = groups.GetAllGroups
      groups.GetAllGroups = function(self, kind)
        return {
          [1] = { id = 1, name = "Default Group", isDefault = true },
          [100] = { id = 100, name = "Custom Group" }
        }
      end

      local originalCategoryBelongsToGroup = groups.CategoryBelongsToGroup
      groups.CategoryBelongsToGroup = function(self, kind, category, tabID)
        if tabID == 100 and category == "Quest" then
          return true
        elseif tabID == 1 and category ~= "Quest" then
          return true
        end
        return false
      end

      -- Mock some items in container
      _G.C_Container.GetContainerNumSlots = function(bagid) return 2 end
      _G.C_Container.GetContainerItemID = function(bagid, slotid) return 1000 + slotid end
      _G.C_Container.GetContainerItemLink = function(bagid, slotid) return "|cff0070dd|Hitem:"..(1000+slotid).."|h[Item "..slotid.."]|h|r" end

      local savedGetItemInfo = _G.C_Item.GetItemInfo
      _G.C_Item.GetItemInfo = function(itemID)
        local id = tonumber(itemID)
        if not id and type(itemID) == "string" then
          id = tonumber(string.match(itemID, "item:(%d+)"))
        end
        id = id or 1001
        local name = "Item " .. id
        local class = "Quest"
        if id == 1001 then
          class = "Armor"
        end
        return name, "|cff0070dd|Hitem:"..id.."|h["..name.."]|h|r", 1, 100, 1, class, class, 1, "INVTYPE_WEAPON", 134400, 100, 2, 0, 1, 0, 0, false
      end

      local ctx = addon:GetModule("Context"):New("TestTabPartitioning")
      items:WipeSlotInfo(const.BAG_KIND.BACKPACK)
      items:ProcessRefresh(ctx, const.BAG_KIND.BACKPACK)

      local slotInfo = items.slotInfo[const.BAG_KIND.BACKPACK]

      -- Assertions for partitioning
      assert.is_not_nil(slotInfo.tabs)
      assert.is_not_nil(slotInfo.tabs[1])
      assert.is_not_nil(slotInfo.tabs[100])

      -- Item 1001 (Armor) belongs to default group (tab 1)
      -- Item 1002 (Quest) belongs to Custom Group (tab 100)
      local hasArmorInTab1 = false
      for _, item in ipairs(slotInfo.tabs[1].items) do
        if item.itemInfo and item.itemInfo.category == "Armor" then
          hasArmorInTab1 = true
        end
      end
      assert.is_true(hasArmorInTab1)

      local hasQuestInTab100 = false
      for _, item in ipairs(slotInfo.tabs[100].items) do
        if item.itemInfo and item.itemInfo.category == "Quest" then
          hasQuestInTab100 = true
        end
      end
      assert.is_true(hasQuestInTab100)

      -- Clean up mocks
      DB.GetGroupsEnabled = originalGetGroupsEnabled
      DB.GetCategoryFilter = originalGetCategoryFilter
      groups.GetAllGroups = originalGetAllGroups
      groups.CategoryBelongsToGroup = originalCategoryBelongsToGroup
      _G.C_Item.GetItemInfo = savedGetItemInfo
    end)

    it("filters out hidden categories and their items upstream from slotInfo.tabs", function()
      -- Enable groups in Database
      local DB = addon:GetModule("Database")
      local originalGetGroupsEnabled = DB.GetGroupsEnabled
      DB.GetGroupsEnabled = function() return true end

      local originalGetCategoryFilter = DB.GetCategoryFilter
      DB.GetCategoryFilter = function(self, kind, filter)
        return filter == "Type"
      end

      -- Mock a group
      local groups = addon:GetModule("Groups", true) or StubBetterBagsModule("Groups")
      local originalGetAllGroups = groups.GetAllGroups
      groups.GetAllGroups = function(self, kind)
        return {
          [1] = { id = 1, name = "Default Group", isDefault = true },
          [100] = { id = 100, name = "Custom Group" }
        }
      end

      local originalCategoryBelongsToGroup = groups.CategoryBelongsToGroup
      groups.CategoryBelongsToGroup = function(self, kind, category, tabID)
        if tabID == 100 and category == "Quest" then
          return true
        elseif tabID == 1 and category ~= "Quest" then
          return true
        end
        return false
      end

      -- Mock category shown state (Quest is hidden)
      local originalIsCategoryShown = categories.IsCategoryShown
      categories.IsCategoryShown = function(self, category)
        if category == "Quest" then return false end
        return true
      end

      -- Mock some items in container
      _G.C_Container.GetContainerNumSlots = function(bagid) return 2 end
      _G.C_Container.GetContainerItemID = function(bagid, slotid) return 1000 + slotid end
      _G.C_Container.GetContainerItemLink = function(bagid, slotid) return "|cff0070dd|Hitem:"..(1000+slotid).."|h[Item "..slotid.."]|h|r" end

      local savedGetItemInfo = _G.C_Item.GetItemInfo
      _G.C_Item.GetItemInfo = function(itemID)
        local id = tonumber(itemID)
        if not id and type(itemID) == "string" then
          id = tonumber(string.match(itemID, "item:(%d+)"))
        end
        id = id or 1001
        local name = "Item " .. id
        local class = "Quest"
        if id == 1001 then
          class = "Armor"
        end
        return name, "|cff0070dd|Hitem:"..id.."|h["..name.."]|h|r", 1, 100, 1, class, class, 1, "INVTYPE_WEAPON", 134400, 100, 2, 0, 1, 0, 0, false
      end

      local ctx = addon:GetModule("Context"):New("TestHiddenTabPartitioning")
      items:WipeSlotInfo(const.BAG_KIND.BACKPACK)
      items:ProcessRefresh(ctx, const.BAG_KIND.BACKPACK)

      local slotInfo = items.slotInfo[const.BAG_KIND.BACKPACK]

      -- Assertions for partitioning
      assert.is_not_nil(slotInfo.tabs)
      assert.is_not_nil(slotInfo.tabs[1])
      assert.is_not_nil(slotInfo.tabs[100])

      -- Item 1001 (Armor) belongs to default group (tab 1) and is shown
      local hasArmorInTab1 = false
      for _, item in ipairs(slotInfo.tabs[1].items) do
        if item.itemInfo and item.itemInfo.category == "Armor" then
          hasArmorInTab1 = true
        end
      end
      assert.is_true(hasArmorInTab1)

      -- Item 1002 (Quest) belongs to Custom Group (tab 100) but is hidden,
      -- so it should NOT be in tab 100.
      local hasQuestInTab100 = false
      for _, item in ipairs(slotInfo.tabs[100].items) do
        if item.itemInfo and item.itemInfo.category == "Quest" then
          hasQuestInTab100 = true
        end
      end
      assert.is_false(hasQuestInTab100)
      assert.are.equal(0, #slotInfo.tabs[100].categories)

      -- Clean up mocks
      DB.GetGroupsEnabled = originalGetGroupsEnabled
      DB.GetCategoryFilter = originalGetCategoryFilter
      groups.GetAllGroups = originalGetAllGroups
      groups.CategoryBelongsToGroup = originalCategoryBelongsToGroup
      categories.IsCategoryShown = originalIsCategoryShown
      _G.C_Item.GetItemInfo = savedGetItemInfo
    end)

    it("pre-evaluates Free Space settings and populates tabData.freeSpace", function()
      -- Enable groups in Database
      local DB = addon:GetModule("Database")
      local originalGetGroupsEnabled = DB.GetGroupsEnabled
      DB.GetGroupsEnabled = function() return true end

      local originalGetShowAllFreeSpace = DB.GetShowAllFreeSpace
      DB.GetShowAllFreeSpace = function(self, kind) return true end -- Test with showAll = true

      -- Mock a group
      local groups = addon:GetModule("Groups", true) or StubBetterBagsModule("Groups")
      local originalGetAllGroups = groups.GetAllGroups
      groups.GetAllGroups = function(self, kind)
        return {
          [1] = { id = 1, name = "Default Group", isDefault = true }
        }
      end

      local originalCategoryBelongsToGroup = groups.CategoryBelongsToGroup
      groups.CategoryBelongsToGroup = function(self, kind, category, tabID)
        return true
      end

      -- Isolate BACKPACK_BAGS to only contain bag 0
      local originalBackpackBags = const.BACKPACK_BAGS
      const.BACKPACK_BAGS = { [0] = 0 }

      -- Mock bags and free slots
      local originalGetContainerNumFreeSlots = _G.C_Container.GetContainerNumFreeSlots
      _G.C_Container.GetContainerNumFreeSlots = function(bagid)
        if bagid == 0 then return 2 end
        return 0
      end

      -- Mock item data
      _G.C_Container.GetContainerNumSlots = function(bagid) return 2 end
      _G.C_Container.GetContainerItemID = function(bagid, slotid) return nil end -- empty slots
      _G.C_Container.GetContainerItemLink = function(bagid, slotid) return nil end

      local ctx = addon:GetModule("Context"):New("TestFreeSpacePartitioning")
      items:WipeSlotInfo(const.BAG_KIND.BACKPACK)
      items:ProcessRefresh(ctx, const.BAG_KIND.BACKPACK)

      local slotInfo = items.slotInfo[const.BAG_KIND.BACKPACK]

      -- Assertions for freeSpace payload
      assert.is_not_nil(slotInfo.tabs)
      assert.is_not_nil(slotInfo.tabs[1])
      assert.is_not_nil(slotInfo.tabs[1].freeSpace)
      assert.is_true(slotInfo.tabs[1].freeSpace.showAll)
      assert.are.equal(2, #slotInfo.tabs[1].freeSpace.buttons)
      assert.are.equal("0_1", slotInfo.tabs[1].freeSpace.buttons[1].slotkey)
      assert.is_true(slotInfo.tabs[1].freeSpace.buttons[1].isIndividual)

      -- Now test with showAll = false
      DB.GetShowAllFreeSpace = function(self, kind) return false end
      items:WipeSlotInfo(const.BAG_KIND.BACKPACK)
      items:ProcessRefresh(ctx, const.BAG_KIND.BACKPACK)

      slotInfo = items.slotInfo[const.BAG_KIND.BACKPACK]
      assert.is_not_nil(slotInfo.tabs[1].freeSpace)
      assert.is_false(slotInfo.tabs[1].freeSpace.showAll)
      assert.are.equal(1, #slotInfo.tabs[1].freeSpace.buttons) -- only 1 aggregated button for subclass
      assert.is_false(slotInfo.tabs[1].freeSpace.buttons[1].isIndividual)
      assert.are.equal(2, slotInfo.tabs[1].freeSpace.buttons[1].count)

      -- Clean up mocks
      DB.GetGroupsEnabled = originalGetGroupsEnabled
      DB.GetShowAllFreeSpace = originalGetShowAllFreeSpace
      _G.C_Container.GetContainerNumFreeSlots = originalGetContainerNumFreeSlots
      groups.GetAllGroups = originalGetAllGroups
      groups.CategoryBelongsToGroup = originalCategoryBelongsToGroup
      const.BACKPACK_BAGS = originalBackpackBags
    end)
  end)

  describe("GetItemData API", function()
    it("should retrieve formatted item data asynchronously using ContinuableContainer", function()
      local savedGetItemInfo = _G.C_Item.GetItemInfo
      _G.C_Item.GetItemInfo = function(itemID)
        return "Test Item " .. itemID, "|cff0070dd|Hitem:"..itemID.."|h[Test Item "..itemID.."]|h|r", 3, 100, 1, "Weapon", "One-Handed Swords", 1, "INVTYPE_WEAPON", 134400, 100, 2, 0, 1, 0, 0, false
      end

      local ctx = addon:GetModule("Context"):New("TestGetItemData")
      local callbackCtx, callbackData
      items:GetItemData(ctx, { 12345, 67890 }, function(ectx, dataList)
        callbackCtx = ectx
        callbackData = dataList
      end)

      assert.is_not_nil(callbackCtx)
      assert.are.equal(ctx, callbackCtx)
      assert.is_not_nil(callbackData)
      assert.are.equal(2, #callbackData)
      assert.are.equal(12345, callbackData[1].itemInfo.itemID)
      assert.are.equal("Test Item 12345", callbackData[1].itemInfo.itemName)
      assert.are.equal(67890, callbackData[2].itemInfo.itemID)
      assert.are.equal("Test Item 67890", callbackData[2].itemInfo.itemName)

      _G.C_Item.GetItemInfo = savedGetItemInfo
    end)
  end)

  describe("ProcessRefresh Functional Phase Isolation", function()
    it("Phase1_DetermineBags returns the expected bag list", function()
      local ctx = addon:GetModule("Context"):New("TestPhase1")
      local backpackBags = items:Phase1_DetermineBags(ctx, const.BAG_KIND.BACKPACK)
      assert.are.equal(const.BACKPACK_BAGS, backpackBags)
    end)

    it("Phase4_ClearMovedItemGlows clears new item status on the moved item's harvested data", function()
      local ctx = addon:GetModule("Context"):New("TestPhase3")
      local clearedData = nil
      local originalClearNewItemFromData = items.ClearNewItemFromData
      items.ClearNewItemFromData = function(self, ectx, data)
        clearedData = data
      end

      local previous = {
        ["0_1"] = {
          isItemEmpty = false,
          slotkey = "0_1",
          itemInfo = { itemGUID = "GUID_123" }
        }
      }
      local current = {
        ["0_2"] = {
          isItemEmpty = false,
          slotkey = "0_2",
          itemInfo = { itemGUID = "GUID_123" }
        }
      }

      items:Phase4_ClearMovedItemGlows(ctx, previous, current)
      -- The harvested data for the new slot is cleared directly; the committed
      -- SlotInfo still holds the previous occupant of that slot (or nothing at all).
      assert.are.equal(current["0_2"], clearedData)

      items.ClearNewItemFromData = originalClearNewItemFromData
    end)

    it("Phase7_ApplyVirtualStacks calculates stack data correctly", function()
      local stacks = addon:GetModule("Stacks")
      local originalCreate = stacks.Create
      stacks.Create = function()
        local s = {
          stacksByItemHash = {},
          AddToStack = function(self, item)
            self.stacksByItemHash[item.itemHash] = {count = 1, rootItem = item.slotkey, slotkeys = {}}
          end,
          GetStackInfo = function(self, hash)
            return self.stacksByItemHash[hash]
          end
        }
        return s
      end

      items:WipeSlotInfo(const.BAG_KIND.BACKPACK)
      local itemData = {
        ["0_1"] = {
          isItemEmpty = false,
          slotkey = "0_1",
          itemHash = "hash123",
          itemInfo = { currentItemCount = 5, itemStackCount = 20 }
        }
      }

      local visibleMap, stackData = items:Phase7_ApplyVirtualStacks(const.BAG_KIND.BACKPACK, itemData)
      assert.is_not_nil(visibleMap["0_1"])
      assert.is_not_nil(stackData)
      local stackInfo = stackData:GetStackInfo("hash123")
      assert.is_not_nil(stackInfo)
      assert.are.equal("0_1", stackInfo.rootItem)

      stacks.Create = originalCreate
    end)

    it("GetItemDataFromSlotKey does not read from _tempSlotInfo", function()
      items:WipeSlotInfo(const.BAG_KIND.BACKPACK)
      items._tempSlotInfo = {
        [const.BAG_KIND.BACKPACK] = {
          itemsBySlotKey = {
            ["0_1"] = { slotkey = "0_1", isItemEmpty = false }
          }
        }
      }
      assert.is_nil(items:GetItemDataFromSlotKey("0_1"))
      items._tempSlotInfo = nil
    end)

    it("Phase6_EnrichData pre-computes itemContextMatchResult on itemData", function()
      _G.ItemLocation = {
        CreateFromBagAndSlot = function(bagid, slotid)
          return {
            HasAnyLocation = function() return true end,
            IsBagAndSlot = function() return true end,
            IsValid = function() return true end,
          }
        end
      }
      _G.ItemButtonUtil = {
        ItemContextMatchResult = { Match = 1, Mismatch = 2, DoesNotApply = 0 },
        GetItemContextMatchResultForItem = function() return 1 end,
      }

      local itemData = {
        ["0_1"] = {
          slotkey = "0_1",
          bagid = 0,
          slotid = 1,
          isItemEmpty = false,
          itemInfo = {},
        }
      }

      local ctx = addon:GetModule("Context"):New("test_enrich_context")
      items:Phase6_EnrichData(ctx, const.BAG_KIND.BACKPACK, itemData)

      assert.is_not_nil(itemData["0_1"].itemContextMatchResult)
      assert.equal(1, itemData["0_1"].itemContextMatchResult)
    end)

    it("should pre-compute isSearchResult during Phase8_EnrichCategories once the fresh index exists", function()
      local search = addon:GetModule("Search")
      local origSearch = search.Search
      search.Search = function(_, text)
        if text == "potion" then
          return { ["0_1"] = true, ["0_2"] = false }
        end
        return {}
      end

      local searchBox = StubBetterBagsModule("SearchBox")
      searchBox.GetText = function() return "potion" end

      local itemData = {
        ["0_1"] = MockData.ItemData({ slotkey = "0_1", bagid = 0, slotid = 1 }),
        ["0_2"] = MockData.ItemData({ slotkey = "0_2", bagid = 0, slotid = 2 }),
      }

      local ctx = addon:GetModule("Context"):New("test_search_enrich")
      items:Phase8_EnrichCategories(ctx, const.BAG_KIND.BACKPACK, itemData, {})

      assert.is_true(itemData["0_1"].isSearchResult)
      assert.is_false(itemData["0_2"].isSearchResult)

      search.Search = origSearch
    end)

    it("should leave isSearchResult unset in Phase6_EnrichData so buttons never draw against a stale index", function()
      local searchBox = StubBetterBagsModule("SearchBox")
      local origGetText = searchBox.GetText
      searchBox.GetText = function() return "potion" end

      local itemData = {
        ["0_1"] = MockData.ItemData({ slotkey = "0_1", bagid = 0, slotid = 1 }),
      }

      local ctx = addon:GetModule("Context"):New("test_search_phase6")
      items:Phase6_EnrichData(ctx, const.BAG_KIND.BACKPACK, itemData)

      assert.is_nil(itemData["0_1"].isSearchResult)

      searchBox.GetText = origGetText
    end)
  end)

  describe("Scoped Recent Items Tracking", function()
    before_each(function()
      items:Init()
    end)

    it("initializes _newItemTimers scoped by BAG_KIND", function()
      assert.is_table(items._newItemTimers)
      assert.is_table(items._newItemTimers[const.BAG_KIND.BACKPACK])
      assert.is_table(items._newItemTimers[const.BAG_KIND.BANK])
    end)

    it("correctly tracks new items separately per BAG_KIND", function()
      local ctx = addon:GetModule("Context"):New("TestScopedNewItems")
      local backpackData = {
        kind = const.BAG_KIND.BACKPACK,
        bagid = 0,
        slotid = 1,
        isItemEmpty = false,
        itemInfo = { itemGUID = "GUID_BACKPACK_1" }
      }
      local bankData = {
        kind = const.BAG_KIND.BANK,
        bagid = 6,
        slotid = 1,
        isItemEmpty = false,
        itemInfo = { itemGUID = "GUID_BANK_1" }
      }

      items:MarkItemAsNew(ctx, backpackData)
      items:MarkItemAsNew(ctx, bankData)

      assert.is_true(items:IsNewItem(backpackData))
      assert.is_true(items:IsNewItem(bankData))

      local fakeBackpackWithBankGUID = {
        kind = const.BAG_KIND.BACKPACK,
        bagid = 0,
        slotid = 2,
        isItemEmpty = false,
        itemInfo = { itemGUID = "GUID_BANK_1" }
      }
      assert.is_false(items:IsNewItem(fakeBackpackWithBankGUID))
    end)

    it("ClearNewItems(BACKPACK) only clears backpack recent items", function()
      local ctx = addon:GetModule("Context"):New("TestClearBackpackNewItems")
      local backpackData = {
        kind = const.BAG_KIND.BACKPACK,
        bagid = 0,
        slotid = 1,
        isItemEmpty = false,
        itemInfo = { itemGUID = "GUID_BP" }
      }
      local bankData = {
        kind = const.BAG_KIND.BANK,
        bagid = 6,
        slotid = 1,
        isItemEmpty = false,
        itemInfo = { itemGUID = "GUID_BANK" }
      }

      items:MarkItemAsNew(ctx, backpackData)
      items:MarkItemAsNew(ctx, bankData)

      items:ClearNewItems(const.BAG_KIND.BACKPACK)

      assert.is_false(items:IsNewItem(backpackData))
      assert.is_true(items:IsNewItem(bankData))
    end)

    it("ClearNewItems(BANK) only clears bank recent items", function()
      local ctx = addon:GetModule("Context"):New("TestClearBankNewItems")
      local backpackData = {
        kind = const.BAG_KIND.BACKPACK,
        bagid = 0,
        slotid = 1,
        isItemEmpty = false,
        itemInfo = { itemGUID = "GUID_BP" }
      }
      local bankData = {
        kind = const.BAG_KIND.BANK,
        bagid = 6,
        slotid = 1,
        isItemEmpty = false,
        itemInfo = { itemGUID = "GUID_BANK" }
      }

      items:MarkItemAsNew(ctx, backpackData)
      items:MarkItemAsNew(ctx, bankData)

      items:ClearNewItems(const.BAG_KIND.BANK)

      assert.is_true(items:IsNewItem(backpackData))
      assert.is_false(items:IsNewItem(bankData))
    end)

    it("ClearNewItems() with no arguments clears both backpack and bank recent items", function()
      local ctx = addon:GetModule("Context"):New("TestClearAllNewItems")
      local backpackData = {
        kind = const.BAG_KIND.BACKPACK,
        bagid = 0,
        slotid = 1,
        isItemEmpty = false,
        itemInfo = { itemGUID = "GUID_BP" }
      }
      local bankData = {
        kind = const.BAG_KIND.BANK,
        bagid = 6,
        slotid = 1,
        isItemEmpty = false,
        itemInfo = { itemGUID = "GUID_BANK" }
      }

      items:MarkItemAsNew(ctx, backpackData)
      items:MarkItemAsNew(ctx, bankData)

      items:ClearNewItems()

      assert.is_false(items:IsNewItem(backpackData))
      assert.is_false(items:IsNewItem(bankData))
    end)
  end)
end)

-- ─── Item stat hashing (Catalyst) ─────────────────────────────────────────────
-- The 12.1 Catalyst retains a source item's secondary stats, so two pieces can
-- share the same itemID, item level and bonus IDs yet differ only in their stat
-- allocation. That difference is invisible to the item link's hashed fields but
-- is reported by C_Item.GetItemStats, so the hash must fold in a stat digest or
-- the two pieces collide and get virtually stacked into one slot.
describe("GenerateItemHash (Catalyst item stats)", function()
  local savedGetItemStats
  before_each(function()
    _G.C_Item = _G.C_Item or {}
    savedGetItemStats = _G.C_Item.GetItemStats
  end)
  after_each(function()
    _G.C_Item.GetItemStats = savedGetItemStats
  end)

  -- Both fists share itemID, item level and bonus IDs; only the itemLink (used to
  -- look up live stats) and the reported stats differ.
  local function makeData(link)
    return {
      kind = const.BAG_KIND.BACKPACK,
      itemLinkInfo = {
        itemID = 271520,
        bonusIDs = { "6652", "13440", "13691", "13697", "12846" },
        relic1BonusIDs = {}, relic2BonusIDs = {}, relic3BonusIDs = {},
      },
      bindingInfo = { binding = const.BINDING_SCOPE.SOULBOUND },
      itemInfo = { currentItemLevel = 321, itemLink = link },
      transmogInfo = {},
    }
  end

  it("GenerateItemStatHash returns a deterministic, sorted digest", function()
    _G.C_Item.GetItemStats = function()
      return { ITEM_MOD_HASTE_RATING_SHORT = 50, ITEM_MOD_CRIT_RATING_SHORT = 93 }
    end
    assert.are.equal(
      "ITEM_MOD_CRIT_RATING_SHORT=93,ITEM_MOD_HASTE_RATING_SHORT=50",
      items:GenerateItemStatHash("anylink")
    )
  end)

  it("GenerateItemStatHash returns empty string when stats are unavailable", function()
    _G.C_Item.GetItemStats = function() return nil end
    assert.are.equal("", items:GenerateItemStatHash("anylink"))
    _G.C_Item.GetItemStats = function() return {} end
    assert.are.equal("", items:GenerateItemStatHash("anylink"))
  end)

  it("produces different hashes for two catalyst items that differ only in secondary stats", function()
    _G.C_Item.GetItemStats = function(link)
      if link == "linkHaste" then
        return {
          ITEM_MOD_CRIT_RATING_SHORT = 93, ITEM_MOD_HASTE_RATING_SHORT = 50,
          ITEM_MOD_STAMINA_SHORT = 2527, RESISTANCE0_NAME = 101, ITEM_MOD_AGILITY_SHORT = 125,
        }
      elseif link == "linkVers" then
        return {
          ITEM_MOD_CRIT_RATING_SHORT = 84, ITEM_MOD_VERSATILITY = 59,
          ITEM_MOD_STAMINA_SHORT = 2527, RESISTANCE0_NAME = 101, ITEM_MOD_AGILITY_SHORT = 125,
        }
      end
      return nil
    end

    local hashHaste = items:GenerateItemHash(makeData("linkHaste"))
    local hashVers = items:GenerateItemHash(makeData("linkVers"))
    assert.are_not.equal(hashHaste, hashVers)
  end)

  it("produces identical hashes for two items with identical stats (still stackable)", function()
    -- The item link itself is not hashed, only the parsed link fields plus the
    -- stat digest; two items with identical stats must remain mergeable.
    _G.C_Item.GetItemStats = function()
      return { ITEM_MOD_CRIT_RATING_SHORT = 93, ITEM_MOD_HASTE_RATING_SHORT = 50 }
    end
    assert.are.equal(items:GenerateItemHash(makeData("linkA")), items:GenerateItemHash(makeData("linkB")))
  end)
end)

-- Load the Pawn and SimpleItemLevel integration modules so their OnEnable
-- provider registration can be exercised directly.
LoadBetterBagsModule("integrations/pawn.lua")
LoadBetterBagsModule("integrations/simpleitemlevel.lua")
local pawn = addon:GetModule("Pawn")
local simpleItemLevel = addon:GetModule("SimpleItemLevel")

describe("Upgrade Icon Providers", function()
  -- INVSLOT globals the built-in BetterBags provider references. wow_mocks only
  -- defines FIRST/LAST_EQUIPPED, not MAINHAND/OFFHAND.
  local savedMainhand, savedOffhand, savedIsEquippable
  local savedPawnUnbudgeted, savedPawnIsUpgrade, savedPawnGetItemData
  local savedSimpleItemLevel

  local savedUserSet, savedGetProvider

  before_each(function()
    items:Init()
    -- Reset the integration modules' one-shot registration guard so each test
    -- exercises a clean OnEnable.
    pawn._registered = nil
    simpleItemLevel._registered = nil

    savedMainhand = _G.INVSLOT_MAINHAND
    savedOffhand = _G.INVSLOT_OFFHAND
    savedIsEquippable = _G.C_Item.IsEquippableItem
    savedPawnUnbudgeted = _G.PawnShouldItemLinkHaveUpgradeArrowUnbudgeted
    savedPawnIsUpgrade = _G.PawnIsContainerItemAnUpgrade
    savedPawnGetItemData = _G.PawnGetItemData
    savedSimpleItemLevel = _G.SimpleItemLevel
    savedUserSet = database.GetUpgradeIconProviderUserSet
    savedGetProvider = database.GetUpgradeIconProvider

    _G.INVSLOT_MAINHAND = 16
    _G.INVSLOT_OFFHAND = 17
    _G.C_Item.IsEquippableItem = function() return true end
    -- Default: the user made an explicit provider choice, so precedence does
    -- not kick in. Precedence tests override this to false.
    database.GetUpgradeIconProviderUserSet = function() return true end
  end)

  after_each(function()
    _G.INVSLOT_MAINHAND = savedMainhand
    _G.INVSLOT_OFFHAND = savedOffhand
    _G.C_Item.IsEquippableItem = savedIsEquippable
    _G.PawnShouldItemLinkHaveUpgradeArrowUnbudgeted = savedPawnUnbudgeted
    _G.PawnIsContainerItemAnUpgrade = savedPawnIsUpgrade
    _G.PawnGetItemData = savedPawnGetItemData
    _G.SimpleItemLevel = savedSimpleItemLevel
    database.GetUpgradeIconProviderUserSet = savedUserSet
    database.GetUpgradeIconProvider = savedGetProvider
  end)

  -- Register the Pawn provider with a controllable verdict.
  local function enablePawn(verdict)
    _G.PawnGetItemData = function() return {} end
    _G.PawnShouldItemLinkHaveUpgradeArrowUnbudgeted = function() return verdict end
    pawn._registered = nil
    pawn:OnEnable()
  end

  -- Build a minimal equippable item that the providers can consume.
  ---@param opts table
  local function equippableItem(opts)
    return {
      isItemEmpty = false,
      inventorySlots = opts.inventorySlots or { 5 },
      itemInfo = {
        itemLink = opts.itemLink or "|cff0070dd|Hitem:1000|h[Test]|h|r",
        currentItemLevel = opts.currentItemLevel or 100,
        itemEquipLoc = opts.itemEquipLoc or "INVTYPE_CHEST",
      },
    }
  end

  -- An equipped item as stored in items.equipmentCache (keyed by inventory slot).
  local function equippedItem(ilvl, equipLoc)
    return {
      isItemEmpty = false,
      itemInfo = { currentItemLevel = ilvl, itemEquipLoc = equipLoc or "INVTYPE_CHEST" },
    }
  end

  describe("BetterBags (built-in) provider", function()
    before_each(function()
      database.GetUpgradeIconProvider = function() return "BetterBags" end
    end)

    it("is registered by items:Init()", function()
      assert.is_function(items.upgradeProviders["BetterBags"])
    end)

    it("returns false for non-equippable items", function()
      _G.C_Item.IsEquippableItem = function() return false end
      items.equipmentCache = { [5] = equippedItem(90) }
      local data = equippableItem({ inventorySlots = { 5 }, currentItemLevel = 200 })
      assert.is_false(items:ResolveUpgrade(data))
    end)

    it("returns true when the bag item out-levels the equipped item in its slot", function()
      items.equipmentCache = { [5] = equippedItem(90) }
      local data = equippableItem({ inventorySlots = { 5 }, currentItemLevel = 100 })
      assert.is_true(items:ResolveUpgrade(data))
    end)

    it("returns false when the bag item ilvl equals the equipped item", function()
      items.equipmentCache = { [5] = equippedItem(100) }
      local data = equippableItem({ inventorySlots = { 5 }, currentItemLevel = 100 })
      assert.is_false(items:ResolveUpgrade(data))
    end)

    it("returns false when the bag item ilvl is below the equipped item", function()
      items.equipmentCache = { [5] = equippedItem(120) }
      local data = equippableItem({ inventorySlots = { 5 }, currentItemLevel = 100 })
      assert.is_false(items:ResolveUpgrade(data))
    end)

    it("does not arrow an offhand when a 2H weapon is equipped in the mainhand", function()
      items.equipmentCache = {
        [16] = equippedItem(90, "INVTYPE_2HWEAPON"),
        [17] = equippedItem(90, "INVTYPE_WEAPONOFFHAND"),
      }
      local data = equippableItem({
        inventorySlots = { 17 }, currentItemLevel = 200, itemEquipLoc = "INVTYPE_WEAPONOFFHAND",
      })
      assert.is_false(items:ResolveUpgrade(data))
    end)

    -- When the usability APIs are unavailable (e.g. Classic, where the tooltip
    -- flags are not exposed), the built-in provider falls back to a pure
    -- item-level comparison and will arrow a higher-ilvl piece regardless of
    -- armor type. This documents that graceful-degradation path.
    it("falls back to naive ilvl comparison when usability APIs are unavailable", function()
      assert.is_nil(_G.IsItemPreferredArmorType)
      assert.is_nil(_G.C_PlayerInfo and _G.C_PlayerInfo.CanUseItem)
      items.equipmentCache = { [5] = equippedItem(100, "INVTYPE_CHEST") }
      local clothChest = equippableItem({ inventorySlots = { 5 }, currentItemLevel = 110 })
      assert.is_true(items:ResolveUpgrade(clothChest))
    end)
  end)

  describe("BetterBags provider — usability gating (retail APIs)", function()
    local savedCanUse, savedPreferred, savedArmorSub, savedClassArmor, savedClassWeapon

    before_each(function()
      database.GetUpgradeIconProvider = function() return "BetterBags" end
      savedCanUse = _G.C_PlayerInfo
      savedPreferred = _G.IsItemPreferredArmorType
      savedArmorSub = _G.Enum.ItemArmorSubclass
      savedClassArmor = _G.Enum.ItemClass.Armor
      savedClassWeapon = _G.Enum.ItemClass.Weapon

      _G.C_PlayerInfo = { CanUseItem = function() return true end }
      _G.IsItemPreferredArmorType = function() return true end
      _G.Enum.ItemClass.Armor = 4
      _G.Enum.ItemClass.Weapon = 2
      _G.Enum.ItemArmorSubclass = {
        Generic = 0, Cloth = 1, Leather = 2, Mail = 3, Plate = 4, Cosmetic = 5, Shield = 6,
      }
    end)

    after_each(function()
      _G.C_PlayerInfo = savedCanUse
      _G.IsItemPreferredArmorType = savedPreferred
      _G.Enum.ItemArmorSubclass = savedArmorSub
      _G.Enum.ItemClass.Armor = savedClassArmor
      _G.Enum.ItemClass.Weapon = savedClassWeapon
    end)

    -- A wearable-armor bag item: plate wearer's slot with a higher-ilvl piece.
    local function armorItem(subclassID, equipLoc)
      items.equipmentCache = { [5] = equippedItem(100, equipLoc or "INVTYPE_CHEST") }
      return {
        isItemEmpty = false,
        bagid = 0, slotid = 3,
        inventorySlots = { 5 },
        itemInfo = {
          itemID = 55555,
          itemLink = "|cff0070dd|Hitem:55555|h[Chest]|h|r",
          currentItemLevel = 200,
          itemEquipLoc = equipLoc or "INVTYPE_CHEST",
          classID = 4,
          subclassID = subclassID,
        },
      }
    end

    it("arrows a higher-ilvl item the character can use and prefers", function()
      assert.is_true(items:ResolveUpgrade(armorItem(4))) -- Plate, preferred
    end)

    it("does NOT arrow an item the character cannot use (proficiency)", function()
      _G.C_PlayerInfo.CanUseItem = function() return false end
      assert.is_false(items:ResolveUpgrade(armorItem(4)))
    end)

    it("does NOT arrow wearable armor of a non-preferred type (cloth on a plate wearer)", function()
      _G.IsItemPreferredArmorType = function() return false end
      assert.is_false(items:ResolveUpgrade(armorItem(1))) -- Cloth, not preferred
    end)

    it("still arrows a cloak even though cloaks are subclass Cloth", function()
      -- Cloaks are armor subclass Cloth but wearable by every class, so the
      -- preferred-armor gate must never suppress them.
      _G.IsItemPreferredArmorType = function() return false end
      assert.is_true(items:ResolveUpgrade(armorItem(1, "INVTYPE_CLOAK")))
    end)

    it("does not apply the preferred-armor gate to shields", function()
      -- Shield is subclass 6, not one of the four wearable armor types.
      _G.IsItemPreferredArmorType = function() return false end
      assert.is_true(items:ResolveUpgrade(armorItem(6, "INVTYPE_SHIELD")))
    end)

    it("does not apply the preferred-armor gate to non-armor (weapons)", function()
      _G.IsItemPreferredArmorType = function() return false end
      local weapon = armorItem(7, "INVTYPE_WEAPONMAINHAND")
      weapon.itemInfo.classID = 2 -- Weapon
      assert.is_true(items:ResolveUpgrade(weapon))
    end)
  end)

  describe("Pawn provider", function()
    it("registers a 'Pawn' provider when Pawn is loaded at OnEnable time", function()
      _G.PawnGetItemData = function() return {} end
      _G.PawnShouldItemLinkHaveUpgradeArrowUnbudgeted = function() return true end
      pawn:OnEnable()
      assert.is_function(items.upgradeProviders["Pawn"])
    end)

    it("delegates to Pawn's verdict when selected as the provider", function()
      _G.PawnGetItemData = function() return {} end
      local pawnVerdict = true
      _G.PawnShouldItemLinkHaveUpgradeArrowUnbudgeted = function() return pawnVerdict end
      pawn:OnEnable()
      database.GetUpgradeIconProvider = function() return "Pawn" end

      local data = equippableItem({ currentItemLevel = 1 })
      assert.is_true(items:ResolveUpgrade(data))

      pawnVerdict = false
      assert.is_false(items:ResolveUpgrade(data))
    end)

    it("returns false for empty items without calling Pawn", function()
      _G.PawnGetItemData = function() return {} end
      local called = false
      _G.PawnShouldItemLinkHaveUpgradeArrowUnbudgeted = function() called = true; return true end
      pawn:OnEnable()
      database.GetUpgradeIconProvider = function() return "Pawn" end

      -- ResolveUpgrade short-circuits empty items before hitting the provider.
      assert.is_false(items:ResolveUpgrade({ isItemEmpty = true }))
      assert.is_false(called)
    end)

    -- Robustness against the reported "Pawn is not in the dropdown" symptom: if
    -- the Pawn addon has not populated its globals by the time BetterBags enables
    -- its modules (load-order race), OnEnable must not give up permanently. It
    -- registers an ADDON_LOADED retry so the provider appears once Pawn loads.
    it("registers late via ADDON_LOADED when Pawn loads after BetterBags enables", function()
      _G.PawnGetItemData = nil
      _G.PawnIsContainerItemAnUpgrade = nil
      _G.PawnShouldItemLinkHaveUpgradeArrowUnbudgeted = nil
      pawn:OnEnable()
      -- Not registered yet: Pawn's globals do not exist.
      assert.is_nil(items.upgradeProviders["Pawn"])

      -- Pawn finishes loading; its globals appear and ADDON_LOADED fires. The
      -- retry registers the provider and requests one refresh so drawn arrows
      -- re-resolve against Pawn.
      _G.PawnGetItemData = function() return {} end
      _G.PawnShouldItemLinkHaveUpgradeArrowUnbudgeted = function() return true end
      local refreshed = 0
      events:RegisterMessage('bags/FullRefreshAll', function() refreshed = refreshed + 1 end)
      local handler = events._eventMap["ADDON_LOADED"]
      assert.is_not_nil(handler)
      handler.fn("ADDON_LOADED", "Pawn")

      assert.is_function(items.upgradeProviders["Pawn"])
      assert.are.equal(1, refreshed)

      -- A subsequent ADDON_LOADED must not re-register or re-refresh.
      handler.fn("ADDON_LOADED", "SomethingElse")
      assert.are.equal(1, refreshed)
    end)
  end)

  describe("provider precedence (restores automatic Pawn/SimpleItemLevel)", function()
    -- The user never explicitly picked a provider (legacy default), so an
    -- available external provider should win automatically — restoring the
    -- pre-#1036 behavior where Pawn drew arrows without any dropdown selection.
    before_each(function()
      database.GetUpgradeIconProviderUserSet = function() return false end
    end)

    it("prefers a registered Pawn provider over the saved 'None' value", function()
      database.GetUpgradeIconProvider = function() return "None" end
      enablePawn(true)
      assert.are.equal("Pawn", items:GetActiveUpgradeProvider())
      assert.is_true(items:ResolveUpgrade(equippableItem({ currentItemLevel = 1 })))
    end)

    it("prefers a registered Pawn provider over the saved 'BetterBags' value", function()
      database.GetUpgradeIconProvider = function() return "BetterBags" end
      enablePawn(false)
      assert.are.equal("Pawn", items:GetActiveUpgradeProvider())
      -- Pawn says not-an-upgrade, so no arrow even though BetterBags (naive)
      -- would have arrowed this higher-ilvl item.
      items.equipmentCache = { [5] = equippedItem(90) }
      assert.is_false(items:ResolveUpgrade(equippableItem({ inventorySlots = { 5 }, currentItemLevel = 200 })))
    end)

    it("prefers Pawn over SimpleItemLevel when both are registered", function()
      database.GetUpgradeIconProvider = function() return "None" end
      enablePawn(true)
      _G.SimpleItemLevel = { API = { ItemIsUpgrade = function() return true end } }
      simpleItemLevel._registered = nil
      simpleItemLevel:OnEnable()
      assert.are.equal("Pawn", items:GetActiveUpgradeProvider())
    end)

    it("uses SimpleItemLevel when it is the only external provider", function()
      database.GetUpgradeIconProvider = function() return "None" end
      _G.SimpleItemLevel = { API = { ItemIsUpgrade = function() return true end } }
      simpleItemLevel._registered = nil
      simpleItemLevel:OnEnable()
      assert.are.equal("SimpleItemLevel", items:GetActiveUpgradeProvider())
    end)

    it("falls back to the saved value when no external provider is registered", function()
      database.GetUpgradeIconProvider = function() return "BetterBags" end
      assert.are.equal("BetterBags", items:GetActiveUpgradeProvider())
    end)

    it("honors an explicit user choice over external-provider precedence", function()
      database.GetUpgradeIconProviderUserSet = function() return true end
      database.GetUpgradeIconProvider = function() return "None" end
      enablePawn(true)
      -- The user explicitly chose 'None'; Pawn must NOT override it.
      assert.are.equal("None", items:GetActiveUpgradeProvider())
      assert.is_false(items:ResolveUpgrade(equippableItem({ currentItemLevel = 1 })))
    end)
  end)

  describe("SimpleItemLevel provider", function()
    it("registers a 'SimpleItemLevel' provider when the addon is loaded", function()
      _G.SimpleItemLevel = { API = { ItemIsUpgrade = function() return true end } }
      simpleItemLevel:OnEnable()
      assert.is_function(items.upgradeProviders["SimpleItemLevel"])
    end)

    it("does not register when the SimpleItemLevel addon is absent", function()
      _G.SimpleItemLevel = nil
      simpleItemLevel:OnEnable()
      assert.is_nil(items.upgradeProviders["SimpleItemLevel"])
    end)
  end)

  describe("ResolveUpgrade selection", function()
    it("returns false when the provider is 'None'", function()
      database.GetUpgradeIconProvider = function() return "None" end
      items.equipmentCache = { [5] = equippedItem(1) }
      local data = equippableItem({ currentItemLevel = 999 })
      assert.is_false(items:ResolveUpgrade(data))
    end)

    it("returns false when the selected provider is not registered (no fallback)", function()
      -- e.g. a saved 'Pawn' value while the Pawn provider failed to register.
      database.GetUpgradeIconProvider = function() return "Pawn" end
      items.upgradeProviders["Pawn"] = nil
      items.equipmentCache = { [5] = equippedItem(1) }
      local data = equippableItem({ currentItemLevel = 999 })
      assert.is_false(items:ResolveUpgrade(data))
    end)

    it("returns false for empty item data", function()
      database.GetUpgradeIconProvider = function() return "BetterBags" end
      assert.is_false(items:ResolveUpgrade({ isItemEmpty = true }))
      assert.is_false(items:ResolveUpgrade(nil))
    end)
  end)
end)

describe("Empty slot family icons (specialized bags)", function()
  before_each(function()
    addon.isRetail = true
  end)

  it("GetEmptySlotFamilyIcon returns nil for generic bags and a texture for specialized bags", function()
    const.EMPTY_SLOT_FAMILY_ICON_DEFAULT = [[Interface\PaperDoll\UI-PaperDoll-Slot-Bag]]
    const.EMPTY_SLOT_FAMILY_ICON = {}

    assert.is_nil(items:GetEmptySlotFamilyIcon(nil))
    assert.is_nil(items:GetEmptySlotFamilyIcon(0))
    -- Any non-zero family with no explicit override falls back to the shared default.
    assert.are.equal([[Interface\PaperDoll\UI-PaperDoll-Slot-Bag]], items:GetEmptySlotFamilyIcon(4))

    -- A per-family override is honored (sets us up for distinct icons later).
    const.EMPTY_SLOT_FAMILY_ICON[32] = [[Interface\Icons\INV_Misc_Herb_01]]
    assert.are.equal([[Interface\Icons\INV_Misc_Herb_01]], items:GetEmptySlotFamilyIcon(32))
  end)

  it("Phase5_UpdateFreeSlots records the bag family per bag", function()
    const.BANK_BAGS = { [6] = 6, [7] = 7 }
    const.ACCOUNT_BANK_BAGS = {}
    const.BANK_TAB = { BANK = -1, ACCOUNT_BANK_1 = -3 }

    local origFree = _G.C_Container.GetContainerNumFreeSlots
    _G.C_Container.GetContainerNumFreeSlots = function(bagid)
      if bagid == 6 then return 5, 0 end    -- generic bag
      if bagid == 7 then return 3, 32 end   -- herb bag (family bit 32)
      return 0, 0
    end
    local origSub = _G.C_Item.GetItemSubClassInfo
    _G.C_Item.GetItemSubClassInfo = function() return "Bag" end
    local origLink = _G.GetInventoryItemLink
    _G.GetInventoryItemLink = function() return nil end

    local c = addon:GetModule("Context"):New("TestFamilyPhase5")
    items:WipeSlotInfo(const.BAG_KIND.BANK)
    local _, emptySlotsByBag = items:Phase5_UpdateFreeSlots(c, const.BAG_KIND.BANK)

    assert.are.equal(0, emptySlotsByBag[6].family)
    assert.are.equal(32, emptySlotsByBag[7].family)

    _G.C_Container.GetContainerNumFreeSlots = origFree
    _G.C_Item.GetItemSubClassInfo = origSub
    _G.GetInventoryItemLink = origLink
  end)

  it("Phase5_UpdateFreeSlots flags the retail reagent bag by id (family 0 from the API)", function()
    -- On retail the reagent bag (id 5) is identified purely by its id; GetContainerNumFreeSlots
    -- returns family 0 for it, so it must be flagged via BACKPACK_ONLY_REAGENT_BAGS instead.
    addon.isRetail = true
    const.BACKPACK_BAGS = { [0] = 0, [5] = 5 }
    const.BACKPACK_ONLY_REAGENT_BAGS = { [5] = 5 }
    const.REAGENT_BAG_FAMILY_KEY = "ReagentBag"

    local origFree = _G.C_Container.GetContainerNumFreeSlots
    _G.C_Container.GetContainerNumFreeSlots = function(bagid)
      if bagid == 0 then return 4, 0 end    -- generic backpack bag
      if bagid == 5 then return 6, 0 end    -- reagent bag: API reports family 0
      return 0, 0
    end
    local origSub = _G.C_Item.GetItemSubClassInfo
    _G.C_Item.GetItemSubClassInfo = function() return "Bag" end
    local origLink = _G.GetInventoryItemLink
    _G.GetInventoryItemLink = function() return nil end

    local c = addon:GetModule("Context"):New("TestReagentPhase5")
    items:WipeSlotInfo(const.BAG_KIND.BACKPACK)
    local _, emptySlotsByBag = items:Phase5_UpdateFreeSlots(c, const.BAG_KIND.BACKPACK)

    assert.are.equal(0, emptySlotsByBag[0].family)
    assert.are.equal("ReagentBag", emptySlotsByBag[5].family)
    -- The reagent-bag key resolves to a (default) glyph.
    const.EMPTY_SLOT_FAMILY_ICON_DEFAULT = [[Interface\PaperDoll\UI-PaperDoll-Slot-Bag]]
    const.EMPTY_SLOT_FAMILY_ICON = {}
    assert.are.equal([[Interface\PaperDoll\UI-PaperDoll-Slot-Bag]], items:GetEmptySlotFamilyIcon("ReagentBag"))

    _G.C_Container.GetContainerNumFreeSlots = origFree
    _G.C_Item.GetItemSubClassInfo = origSub
    _G.GetInventoryItemLink = origLink
  end)

  it("Phase6_EnrichData resolves the family icon onto empty-slot itemInfo", function()
    const.EMPTY_SLOT_FAMILY_ICON_DEFAULT = [[Interface\PaperDoll\UI-PaperDoll-Slot-Bag]]
    const.EMPTY_SLOT_FAMILY_ICON = {}
    const.BACKPACK_BAGS = { [0] = 0 }

    local origIID = _G.C_Container.ContainerIDToInventoryID
    _G.C_Container.ContainerIDToInventoryID = function() return nil end
    local origSub = _G.C_Item.GetItemSubClassInfo
    _G.C_Item.GetItemSubClassInfo = function() return "Herb Bag" end
    local origLink = _G.GetInventoryItemLink
    _G.GetInventoryItemLink = function() return nil end

    local itemData = {
      ["0_1"] = { bagid = 0, slotid = 1, slotkey = "0_1", isItemEmpty = true, itemInfo = {} },
      ["0_2"] = { bagid = 0, slotid = 2, slotkey = "0_2", isItemEmpty = true, itemInfo = {} },
    }
    -- Bag 0 is a specialized (herb, family 32) bag in this scenario.
    local emptySlotsByBag = { [0] = { name = "Herb Bag", count = 2, family = 32 } }

    local c = addon:GetModule("Context"):New("TestFamilyPhase6")
    items:Phase6_EnrichData(c, const.BAG_KIND.BACKPACK, itemData, emptySlotsByBag)

    assert.are.equal([[Interface\PaperDoll\UI-PaperDoll-Slot-Bag]], itemData["0_1"].itemInfo.emptySlotFamilyIcon)
    assert.are.equal([[Interface\PaperDoll\UI-PaperDoll-Slot-Bag]], itemData["0_2"].itemInfo.emptySlotFamilyIcon)

    _G.C_Container.ContainerIDToInventoryID = origIID
    _G.C_Item.GetItemSubClassInfo = origSub
    _G.GetInventoryItemLink = origLink
  end)

  it("Phase6_EnrichData leaves the family icon nil for a generic (family 0) bag", function()
    const.EMPTY_SLOT_FAMILY_ICON_DEFAULT = [[Interface\PaperDoll\UI-PaperDoll-Slot-Bag]]
    const.EMPTY_SLOT_FAMILY_ICON = {}
    const.BACKPACK_BAGS = { [0] = 0 }

    local origIID = _G.C_Container.ContainerIDToInventoryID
    _G.C_Container.ContainerIDToInventoryID = function() return nil end
    local origSub = _G.C_Item.GetItemSubClassInfo
    _G.C_Item.GetItemSubClassInfo = function() return "Bag" end
    local origLink = _G.GetInventoryItemLink
    _G.GetInventoryItemLink = function() return nil end

    local itemData = {
      ["0_1"] = { bagid = 0, slotid = 1, slotkey = "0_1", isItemEmpty = true, itemInfo = {} },
    }
    local emptySlotsByBag = { [0] = { name = "Bag", count = 1, family = 0 } }

    local c = addon:GetModule("Context"):New("TestFamilyPhase6Generic")
    items:Phase6_EnrichData(c, const.BAG_KIND.BACKPACK, itemData, emptySlotsByBag)

    assert.is_nil(itemData["0_1"].itemInfo.emptySlotFamilyIcon)

    _G.C_Container.ContainerIDToInventoryID = origIID
    _G.C_Item.GetItemSubClassInfo = origSub
    _G.GetInventoryItemLink = origLink
  end)
end)
