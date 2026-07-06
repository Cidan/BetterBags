-- items_new_spec.lua -- Unit tests for data/items_new.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Ensure all dependencies exist before loading items_new.lua
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
local events = addon:GetModule("Events")
events:OnInitialize()

-- Stubs for modules items_new.lua depends on
local debug = StubBetterBagsModule("Debug")
debug.Log = function() end
debug.Inspect = function() end

local database = StubBetterBagsModule("Database")
local const = StubBetterBagsModule("Constants")
local L = StubBetterBagsModule("Localization")
function L:G(key) return key end

local equipmentSets = StubBetterBagsModule("EquipmentSets")
equipmentSets.GetItemSets = function() return nil end

local tooltipScanner = StubBetterBagsModule("TooltipScanner")
tooltipScanner.GetTooltipText = function() return "" end

LoadBetterBagsModule("util/query.lua")
LoadBetterBagsModule("util/trees/trees.lua")
LoadBetterBagsModule("util/trees/intervaltree.lua")
LoadBetterBagsModule("data/search_new.lua")
LoadBetterBagsModule("core/async.lua")
LoadBetterBagsModule("data/stacks_new.lua")
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

database.GetNewItemTime = function() return 30 end
database.GetStackingOptions = function()
  return { dontMergeTransmog = false }
end
database.GetCategoryFilter = function() return false end
database.GetEnableBankBag = function() return false end
database.GetMarkRecentItems = function() return false end

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
ResetModuleStub("Items", "data/items_new.lua")
LoadBetterBagsModule("data/items_new.lua")
LoadBetterBagsModule("data/slots.lua")
local items = addon:GetModule("Items")

describe("Items (New Data Farming Engine)", function()
  before_each(function()
    items:OnInitialize()
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
      search:OnInitialize()
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
      items:UpdateFreeSlots(ctx, const.BAG_KIND.BANK)

      local slotInfo = items.slotInfo[const.BAG_KIND.BANK]
      assert.is_not_nil(slotInfo.emptySlotsByBag)
      assert.are.equal(5, slotInfo.emptySlotsByBag[6].count)
      assert.are.equal("Bag", slotInfo.emptySlotsByBag[6].name)
      assert.are.equal(3, slotInfo.emptySlotsByBag[7].count)
      assert.are.equal(10, slotInfo.emptySlotsByBag[13].count)
      assert.are.equal(12, slotInfo.emptySlotsByBag[14].count)

      -- Restore mocks
      _G.C_Container.GetContainerNumFreeSlots = originalGetContainerNumFreeSlots
      _G.C_Item.GetItemSubClassInfo = originalGetItemSubClassInfo
      _G.GetInventoryItemLink = originalGetInventoryItemLink
    end)
  end)
end)
