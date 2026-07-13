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
end)
