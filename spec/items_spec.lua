-- items_spec.lua -- Unit tests for data/items.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Ensure all dependencies exist before loading items.lua
-- (it calls GetModule for all of these at file scope)
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
local events = addon:GetModule("Events")
events:OnInitialize()

LoadBetterBagsModule("util/query.lua")
LoadBetterBagsModule("util/trees/trees.lua")
LoadBetterBagsModule("util/trees/intervaltree.lua")
LoadBetterBagsModule("data/search.lua")
LoadBetterBagsModule("core/async.lua")
LoadBetterBagsModule("data/stacks.lua")
LoadBetterBagsModule("data/binding.lua")

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

-- Categories stub (items.lua calls GetModule('Categories'))
-- Already created by categories_spec if it ran first, otherwise stub it
local ok = pcall(function() return addon:GetModule("Categories") end)
if not ok then
  StubBetterBagsModule("Categories")
end

-- Set up constants
const.BAG_KIND = { UNDEFINED = -1, BACKPACK = 0, BANK = 1 }
const.BANK_BAGS = { [6] = 6, [7] = 7, [8] = 8, [9] = 9, [10] = 10, [11] = 11 }
const.ACCOUNT_BANK_BAGS = { [13] = 13, [14] = 14, [15] = 15, [16] = 16, [17] = 17 }
const.BACKPACK_BAGS = { [0] = 0, [1] = 1, [2] = 2, [3] = 3, [4] = 4 }
const.BINDING_SCOPE = const.BINDING_SCOPE or { UNKNOWN = 0 }
const.ITEM_QUALITY = { Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
const.SEARCH_CATEGORY_GROUP_BY = { NONE = 0, TYPE = 1, SUBTYPE = 2, EXPANSION = 3 }
const.EXPANSION_MAP = { [0] = "Classic", [1] = "Burning Crusade", [2] = "Wrath", [9] = "The War Within" }
const.TRADESKILL_MAP = { [0] = "Tailoring", [1] = "Leatherworking", [2] = "Blacksmithing" }

_G.Enum = _G.Enum or {}
_G.Enum.ItemClass = _G.Enum.ItemClass or { Tradegoods = 7, Container = 1 }

-- Database stubs
database.GetNewItemTime = function() return 30 end
database.GetStackingOptions = function()
  return { dontMergeTransmog = false }
end
database.GetCategoryFilter = function() return false end
database.GetEnableBankBag = function() return false end

-- Addon state
addon.isRetail = true
addon.isClassic = false

-- Load items.lua and its SlotInfo extension
LoadBetterBagsModule("data/items.lua")
LoadBetterBagsModule("data/slots.lua")
local items = addon:GetModule("Items")
local search = addon:GetModule("Search")

describe("Items", function()

  before_each(function()
    items:OnInitialize()
    search:OnInitialize()
  end)

  -- ─── GetSlotKey / GetSlotKeyFromBagAndSlot ──────────────────────────────────

  describe("GetSlotKey", function()

    it("generates slot key from item data", function()
      local data = MockData.ItemData({bagid = 3, slotid = 7})
      assert.are.equal("3_7", items:GetSlotKey(data))
    end)

    it("generates slot key from bag and slot IDs", function()
      assert.are.equal("0_0", items:GetSlotKeyFromBagAndSlot(0, 0))
      assert.are.equal("5_12", items:GetSlotKeyFromBagAndSlot(5, 12))
    end)

    it("handles large bag/slot numbers", function()
      assert.are.equal("100_255", items:GetSlotKeyFromBagAndSlot(100, 255))
    end)
  end)

  -- ─── GetBagKindFromBagID ────────────────────────────────────────────────────

  describe("GetBagKindFromBagID", function()

    it("returns BACKPACK for backpack bags (0-4)", function()
      assert.are.equal(const.BAG_KIND.BACKPACK, items:GetBagKindFromBagID(0))
      assert.are.equal(const.BAG_KIND.BACKPACK, items:GetBagKindFromBagID(1))
      assert.are.equal(const.BAG_KIND.BACKPACK, items:GetBagKindFromBagID(4))
    end)

    it("returns BANK for bank bags (6-11)", function()
      assert.are.equal(const.BAG_KIND.BANK, items:GetBagKindFromBagID(6))
      assert.are.equal(const.BAG_KIND.BANK, items:GetBagKindFromBagID(11))
    end)

    it("returns BANK for account bank bags (13-17)", function()
      assert.are.equal(const.BAG_KIND.BANK, items:GetBagKindFromBagID(13))
      assert.are.equal(const.BAG_KIND.BANK, items:GetBagKindFromBagID(17))
    end)

    it("returns BACKPACK for unknown bag IDs", function()
      assert.are.equal(const.BAG_KIND.BACKPACK, items:GetBagKindFromBagID(5))
      assert.are.equal(const.BAG_KIND.BACKPACK, items:GetBagKindFromBagID(12))
    end)

    it("handles string bag IDs (from slot key parsing)", function()
      assert.are.equal(const.BAG_KIND.BANK, items:GetBagKindFromBagID("6"))
      assert.are.equal(const.BAG_KIND.BACKPACK, items:GetBagKindFromBagID("0"))
    end)
  end)

  -- ─── ParseItemLink ──────────────────────────────────────────────────────────

  describe("ParseItemLink", function()

    -- NOTE: Retail item links have an extra field between "Hitem:" and
    -- the itemID. The retail parser discards TWO prefix fields, classic
    -- discards ONE. Use exactly 13 colons (14 fields) so rest=nil and
    -- the variable-length parser is skipped for simple tests.
    -- Retail: |cff...|Hitem:EXTRA:itemID:enchant:gem1:gem2:gem3:gem4:suffix:unique:level:spec:modMask:context

    it("parses a basic retail item link", function()
      local link = "|cff0070dd|Hitem:0:19019:0:0:0:0:0:0:0:80:0:0:0"
      local info = items:ParseItemLink(link)
      assert.are.equal(19019, info.itemID)
      assert.are.equal("0", info.enchantID)
      assert.same({}, info.bonusIDs)
    end)

    it("parses item link with bonus IDs", function()
      -- 14 colons → rest is the 15th field containing bonus data + trailing empties
      local link = "|cff0070dd|Hitem:0:158075:0:0:0:0:0:0:0:120:0:0:0:2:1234:5678:::::::"
      local info = items:ParseItemLink(link)
      assert.are.equal(158075, info.itemID)
      assert.are.equal(2, #info.bonusIDs)
      assert.are.equal("1234", info.bonusIDs[1])
      assert.are.equal("5678", info.bonusIDs[2])
    end)

    it("parses item link with no bonus IDs (rest=nil)", function()
      local link = "|cff0070dd|Hitem:0:6948:0:0:0:0:0:0:0:1:0:0:0"
      local info = items:ParseItemLink(link)
      assert.are.equal(6948, info.itemID)
      assert.same({}, info.bonusIDs)
    end)

    it("returns empty tables when rest is nil", function()
      local link = "|cff0070dd|Hitem:0:6948:0:0:0:0:0:0:0:1:0:0:0"
      local info = items:ParseItemLink(link)
      assert.same({}, info.modifierIDs)
      assert.same({}, info.relic1BonusIDs)
      assert.same({}, info.relic2BonusIDs)
      assert.same({}, info.relic3BonusIDs)
      assert.are.equal("", info.crafterGUID)
      assert.are.equal("", info.extraEnchantID)
    end)

    it("parses enchant and gem IDs", function()
      local link = "|cff0070dd|Hitem:0:50000:6000:100:200:300:400:0:0:80:0:0:0"
      local info = items:ParseItemLink(link)
      assert.are.equal("6000", info.enchantID)
      assert.are.equal("100", info.gemID1)
      assert.are.equal("200", info.gemID2)
      assert.are.equal("300", info.gemID3)
      assert.are.equal("400", info.gemID4)
    end)

    it("parses classic item links (one fewer prefix field)", function()
      addon.isRetail = false
      local link = "|cff0070dd|Hitem:19019:0:0:0:0:0:0:0:80:0:0:0"
      local info = items:ParseItemLink(link)
      assert.are.equal(19019, info.itemID)
      assert.are.equal("0", info.enchantID)
      addon.isRetail = true
    end)
  end)

  -- ─── Change Detection ──────────────────────────────────────────────────────

  describe("ItemAdded", function()

    it("returns true when new item replaces empty slot", function()
      local newData = MockData.ItemData({name = "Sword"})
      local oldData = MockData.EmptySlot()
      assert.is_true(items:ItemAdded(newData, oldData))
    end)

    it("returns true when new item and no old data", function()
      local newData = MockData.ItemData({name = "Sword"})
      assert.is_true(items:ItemAdded(newData, nil))
    end)

    it("returns false when new slot is empty", function()
      local newData = MockData.EmptySlot()
      assert.is_false(items:ItemAdded(newData, nil))
    end)

    it("returns false when both slots have items (not an add)", function()
      local newData = MockData.ItemData({name = "Sword"})
      local oldData = MockData.ItemData({name = "Axe"})
      assert.is_false(items:ItemAdded(newData, oldData))
    end)
  end)

  describe("ItemRemoved", function()

    it("returns true when item replaced by empty slot", function()
      local newData = MockData.EmptySlot()
      local oldData = MockData.ItemData({name = "Sword"})
      assert.is_true(items:ItemRemoved(newData, oldData))
    end)

    it("returns false when new item replaces old item", function()
      local newData = MockData.ItemData({name = "Axe"})
      local oldData = MockData.ItemData({name = "Sword"})
      assert.is_false(items:ItemRemoved(newData, oldData))
    end)

    it("returns false when both empty", function()
      local newData = MockData.EmptySlot()
      local oldData = MockData.EmptySlot()
      assert.is_false(items:ItemRemoved(newData, oldData))
    end)

    it("returns false when no old data", function()
      local newData = MockData.EmptySlot()
      assert.is_false(items:ItemRemoved(newData, nil))
    end)
  end)

  describe("ItemGUIDChanged", function()

    it("returns true when GUID changes", function()
      local newData = MockData.ItemData({guid = "new-guid"})
      local oldData = MockData.ItemData({guid = "old-guid"})
      assert.is_true(items:ItemGUIDChanged(newData, oldData))
    end)

    it("returns false when GUID is the same", function()
      local newData = MockData.ItemData({guid = "same"})
      local oldData = MockData.ItemData({guid = "same"})
      assert.is_false(items:ItemGUIDChanged(newData, oldData))
    end)

    it("returns false for empty new data", function()
      local newData = MockData.EmptySlot()
      local oldData = MockData.ItemData({guid = "old"})
      assert.is_false(items:ItemGUIDChanged(newData, oldData))
    end)

    it("returns false when no old data", function()
      local newData = MockData.ItemData({guid = "new"})
      assert.is_false(items:ItemGUIDChanged(newData, nil))
    end)
  end)

  describe("ItemHashChanged", function()

    it("returns true when hash changes", function()
      local newData = MockData.ItemData({})
      newData.itemHash = "hash-new"
      local oldData = MockData.ItemData({})
      oldData.itemHash = "hash-old"
      assert.is_true(items:ItemHashChanged(newData, oldData))
    end)

    it("returns false when hash is the same", function()
      local newData = MockData.ItemData({})
      newData.itemHash = "same-hash"
      local oldData = MockData.ItemData({})
      oldData.itemHash = "same-hash"
      assert.is_false(items:ItemHashChanged(newData, oldData))
    end)

    it("returns false for empty new data with no old data", function()
      local newData = MockData.EmptySlot()
      assert.is_false(items:ItemHashChanged(newData, nil))
    end)
  end)

  -- ─── GenerateItemHash ──────────────────────────────────────────────────────

  describe("GenerateItemHash", function()

    it("generates a deterministic hash from item data", function()
      local data = MockData.ItemData({name = "Sword", itemLevel = 200})
      data.kind = const.BAG_KIND.BACKPACK
      local hash1 = items:GenerateItemHash(data)
      local hash2 = items:GenerateItemHash(data)
      assert.are.equal(hash1, hash2)
    end)

    it("produces different hashes for different item IDs", function()
      local data1 = MockData.ItemData({itemID = 100})
      data1.kind = const.BAG_KIND.BACKPACK
      local data2 = MockData.ItemData({itemID = 200})
      data2.kind = const.BAG_KIND.BACKPACK
      assert.are_not.equal(items:GenerateItemHash(data1), items:GenerateItemHash(data2))
    end)

    it("produces different hashes for different item levels", function()
      local data1 = MockData.ItemData({itemID = 100, currentItemLevel = 200})
      data1.kind = const.BAG_KIND.BACKPACK
      local data2 = MockData.ItemData({itemID = 100, currentItemLevel = 300})
      data2.kind = const.BAG_KIND.BACKPACK
      assert.are_not.equal(items:GenerateItemHash(data1), items:GenerateItemHash(data2))
    end)

    it("includes binding scope in hash", function()
      local data1 = MockData.ItemData({itemID = 100, bindingScope = 0})
      data1.kind = const.BAG_KIND.BACKPACK
      local data2 = MockData.ItemData({itemID = 100, bindingScope = 5})
      data2.kind = const.BAG_KIND.BACKPACK
      assert.are_not.equal(items:GenerateItemHash(data1), items:GenerateItemHash(data2))
    end)
  end)

  -- ─── IsNewItem ──────────────────────────────────────────────────────────────

  describe("IsNewItem", function()

    it("returns false for empty items", function()
      assert.is_false(items:IsNewItem(MockData.EmptySlot()))
    end)

    it("returns false for nil", function()
      assert.is_false(items:IsNewItem(nil))
    end)

    it("returns true when C_NewItems says it's new", function()
      _G.C_NewItems.IsNewItem = function() return true end
      local data = MockData.ItemData({name = "New Sword"})
      assert.is_true(items:IsNewItem(data))
      _G.C_NewItems.IsNewItem = function() return false end
    end)

    it("returns true when item has an active new-item timer", function()
      local data = MockData.ItemData({name = "Timed", guid = "new-guid-123"})
      items._newItemTimers["new-guid-123"] = time()
      assert.is_true(items:IsNewItem(data))
      items._newItemTimers["new-guid-123"] = nil
    end)

    it("returns false when new-item timer has expired", function()
      local data = MockData.ItemData({name = "Old", guid = "expired-guid"})
      items._newItemTimers["expired-guid"] = time() - 100 -- 100 seconds ago, > 30s threshold
      assert.is_false(items:IsNewItem(data))
    end)
  end)

  -- ─── WipeSlotInfo / ResetSlotInfo ───────────────────────────────────────────

  describe("SlotInfo management", function()

    it("creates slot info for both bag kinds on init", function()
      assert.is_not_nil(items:GetAllSlotInfo()[const.BAG_KIND.BACKPACK])
      assert.is_not_nil(items:GetAllSlotInfo()[const.BAG_KIND.BANK])
    end)

    it("WipeSlotInfo replaces slot info with a fresh instance", function()
      local original = items:GetAllSlotInfo()[const.BAG_KIND.BACKPACK]
      items:WipeSlotInfo(const.BAG_KIND.BACKPACK)
      local fresh = items:GetAllSlotInfo()[const.BAG_KIND.BACKPACK]
      assert.are_not.equal(original, fresh)
      assert.same({}, fresh.itemsBySlotKey)
    end)

    it("ResetSlotInfo wipes both bag kinds", function()
      items:GetAllSlotInfo()[const.BAG_KIND.BACKPACK].totalItems = 10
      items:GetAllSlotInfo()[const.BAG_KIND.BANK].totalItems = 5
      items:ResetSlotInfo()
      assert.are.equal(0, items:GetAllSlotInfo()[const.BAG_KIND.BACKPACK].totalItems)
      assert.are.equal(0, items:GetAllSlotInfo()[const.BAG_KIND.BANK].totalItems)
    end)
  end)

  -- ─── GetItemDataFromSlotKey ─────────────────────────────────────────────────

  describe("GetItemDataFromSlotKey", function()

    it("retrieves item data by slot key", function()
      local data = MockData.ItemData({bagid = 0, slotid = 1, slotkey = "0_1"})
      items:GetAllSlotInfo()[const.BAG_KIND.BACKPACK].itemsBySlotKey["0_1"] = data
      local found = items:GetItemDataFromSlotKey("0_1")
      assert.are.equal(data, found)
    end)

    it("routes to correct bag kind based on slot key", function()
      local bankData = MockData.ItemData({bagid = 6, slotid = 1, slotkey = "6_1"})
      items:GetAllSlotInfo()[const.BAG_KIND.BANK].itemsBySlotKey["6_1"] = bankData
      local found = items:GetItemDataFromSlotKey("6_1")
      assert.are.equal(bankData, found)
    end)
  end)

  -- ─── ItemChanged ────────────────────────────────────────────────────────────

  describe("ItemChanged", function()

    it("returns true when item count changed", function()
      local newData = MockData.ItemData({name = "Potion", count = 10, bagid = 0, slotid = 1})
      local oldData = MockData.ItemData({name = "Potion", count = 5, bagid = 0, slotid = 1})
      assert.is_true(items:ItemChanged(newData, oldData))
    end)

    it("returns false when item count is the same", function()
      local newData = MockData.ItemData({name = "Potion", count = 5, bagid = 0, slotid = 1})
      local oldData = MockData.ItemData({name = "Potion", count = 5, bagid = 0, slotid = 1})
      assert.is_false(items:ItemChanged(newData, oldData))
    end)

    it("returns true when C_NewItems marks item as new but old data wasn't new", function()
      local savedIsNewItem = _G.C_NewItems.IsNewItem
      _G.C_NewItems.IsNewItem = function() return true end
      local newData = MockData.ItemData({name = "Sword", bagid = 0, slotid = 1})
      local oldData = MockData.ItemData({name = "Sword", bagid = 0, slotid = 1})
      oldData.itemInfo.isNewItem = false
      assert.is_true(items:ItemChanged(newData, oldData))
      _G.C_NewItems.IsNewItem = savedIsNewItem
    end)

    it("returns true when old item was in Recent Items but is no longer new", function()
      local newData = MockData.ItemData({name = "Sword", bagid = 0, slotid = 1})
      local oldData = MockData.ItemData({name = "Sword", bagid = 0, slotid = 1})
      oldData.itemInfo.category = "Recent Items"
      oldData.itemInfo.isNewItem = false
      -- IsNewItem checks _newItemTimers and C_NewItems - both return false by default
      assert.is_true(items:ItemChanged(newData, oldData))
    end)

    it("returns false when no old data exists", function()
      local newData = MockData.ItemData({name = "Sword", bagid = 0, slotid = 1})
      assert.is_false(items:ItemChanged(newData, nil))
    end)
  end)

  -- ─── GetGroupBySuffix ──────────────────────────────────────────────────────

  describe("GetGroupBySuffix", function()

    it("returns itemType for TYPE grouping", function()
      local data = MockData.ItemData({itemType = "Weapon"})
      local suffix = items:GetGroupBySuffix(data, const.SEARCH_CATEGORY_GROUP_BY.TYPE)
      assert.are.equal("Weapon", suffix)
    end)

    it("returns itemSubType for SUBTYPE grouping", function()
      local data = MockData.ItemData({subType = "Swords"})
      local suffix = items:GetGroupBySuffix(data, const.SEARCH_CATEGORY_GROUP_BY.SUBTYPE)
      assert.are.equal("Swords", suffix)
    end)

    it("returns expansion name for EXPANSION grouping", function()
      local data = MockData.ItemData({expacID = 0})
      local suffix = items:GetGroupBySuffix(data, const.SEARCH_CATEGORY_GROUP_BY.EXPANSION)
      assert.are.equal("Classic", suffix)
    end)

    it("returns 'Unknown' for unmapped expansion IDs", function()
      local data = MockData.ItemData({expacID = 99})
      local suffix = items:GetGroupBySuffix(data, const.SEARCH_CATEGORY_GROUP_BY.EXPANSION)
      assert.are.equal("Unknown", suffix)
    end)

    it("returns nil for NONE grouping", function()
      local data = MockData.ItemData({})
      local suffix = items:GetGroupBySuffix(data, const.SEARCH_CATEGORY_GROUP_BY.NONE)
      assert.is_nil(suffix)
    end)

    it("returns nil for empty items", function()
      local data = MockData.EmptySlot()
      assert.is_nil(items:GetGroupBySuffix(data, const.SEARCH_CATEGORY_GROUP_BY.TYPE))
    end)

    it("returns nil for nil data", function()
      assert.is_nil(items:GetGroupBySuffix(nil, const.SEARCH_CATEGORY_GROUP_BY.TYPE))
    end)
  end)

  -- ─── GetCategory ────────────────────────────────────────────────────────────

  describe("GetCategory", function()

    local ctx
    local categoryFilters
    local cats

    before_each(function()
      ctx = addon:GetModule("Context"):New("GetCategoryTest")
      categoryFilters = {}
      database.GetCategoryFilter = function(_, _, filterName)
        return categoryFilters[filterName] or false
      end
      -- Reset search cache
      items.searchCache[const.BAG_KIND.BACKPACK] = {}
      items.categoryPriorityCache[const.BAG_KIND.BACKPACK] = {}
      -- Get the categories module and stub GetCustomCategory
      cats = addon:GetModule("Categories")
      cats.GetCustomCategory = function() return nil, nil end
    end)

    it("returns 'Empty Slot' for nil data", function()
      assert.are.equal("Empty Slot", items:GetCategory(ctx, nil))
    end)

    it("returns 'Empty Slot' for empty items", function()
      assert.are.equal("Empty Slot", items:GetCategory(ctx, MockData.EmptySlot()))
    end)

    it("returns 'Recent Items' when RecentItems filter is on and item is new", function()
      categoryFilters["RecentItems"] = true
      local data = MockData.ItemData({name = "New Sword", guid = "new-guid-cat"})
      data.kind = const.BAG_KIND.BACKPACK
      items._newItemTimers["new-guid-cat"] = time()
      local result = items:GetCategory(ctx, data)
      items._newItemTimers["new-guid-cat"] = nil
      assert.are.equal("Recent Items", result)
    end)

    it("returns equipment set name when GearSet filter is on", function()
      categoryFilters["GearSet"] = true
      local data = MockData.ItemData({name = "Sword", equipmentSets = {"PvP", "Raid"}})
      data.kind = const.BAG_KIND.BACKPACK
      assert.are.equal("Gear: PvP", items:GetCategory(ctx, data))
    end)

    it("returns search category when one exists in cache", function()
      local data = MockData.ItemData({name = "Sword", slotkey = "0_1"})
      data.kind = const.BAG_KIND.BACKPACK
      items.searchCache[const.BAG_KIND.BACKPACK]["0_1"] = "Epic Weapons"
      items.categoryPriorityCache[const.BAG_KIND.BACKPACK]["0_1"] = 5
      assert.are.equal("Epic Weapons", items:GetCategory(ctx, data))
    end)

    it("returns custom category when one exists", function()
      local data = MockData.ItemData({name = "Sword"})
      data.kind = const.BAG_KIND.BACKPACK
      cats.GetCustomCategory = function() return "My Custom Cat", 10 end
      assert.are.equal("My Custom Cat", items:GetCategory(ctx, data))
    end)

    it("prefers higher priority (lower number) between search and custom", function()
      local data = MockData.ItemData({name = "Sword", slotkey = "0_2"})
      data.kind = const.BAG_KIND.BACKPACK
      items.searchCache[const.BAG_KIND.BACKPACK]["0_2"] = "Search Cat"
      items.categoryPriorityCache[const.BAG_KIND.BACKPACK]["0_2"] = 10
      cats.GetCustomCategory = function() return "Custom Cat", 1 end
      -- Custom priority 1 < search priority 10, so custom wins
      assert.are.equal("Custom Cat", items:GetCategory(ctx, data))
    end)

    it("search wins ties (same priority)", function()
      local data = MockData.ItemData({name = "Sword", slotkey = "0_3"})
      data.kind = const.BAG_KIND.BACKPACK
      items.searchCache[const.BAG_KIND.BACKPACK]["0_3"] = "Search Cat"
      items.categoryPriorityCache[const.BAG_KIND.BACKPACK]["0_3"] = 10
      cats.GetCustomCategory = function() return "Custom Cat", 10 end
      assert.are.equal("Search Cat", items:GetCategory(ctx, data))
    end)

    it("returns 'Junk' for poor quality items", function()
      local data = MockData.ItemData({name = "Broken Sword", quality = 0})
      data.kind = const.BAG_KIND.BACKPACK
      data.containerInfo.quality = const.ITEM_QUALITY.Poor
      assert.are.equal("Junk", items:GetCategory(ctx, data))
    end)

    it("returns 'Everything' when no filters match", function()
      local data = MockData.ItemData({name = "Generic Item", quality = 1})
      data.kind = const.BAG_KIND.BACKPACK
      data.containerInfo.quality = const.ITEM_QUALITY.Common
      assert.are.equal("Everything", items:GetCategory(ctx, data))
    end)

    it("returns item type when Type filter is enabled", function()
      categoryFilters["Type"] = true
      local data = MockData.ItemData({name = "Sword", itemType = "Weapon"})
      data.kind = const.BAG_KIND.BACKPACK
      data.containerInfo.quality = const.ITEM_QUALITY.Common
      assert.are.equal("Weapon", items:GetCategory(ctx, data))
    end)

    it("returns type + subtype when both filters are enabled", function()
      categoryFilters["Type"] = true
      categoryFilters["Subtype"] = true
      local data = MockData.ItemData({name = "Sword", itemType = "Weapon", subType = "Swords"})
      data.kind = const.BAG_KIND.BACKPACK
      data.containerInfo.quality = const.ITEM_QUALITY.Common
      assert.are.equal("Weapon - Swords", items:GetCategory(ctx, data))
    end)

    it("returns 'Everything' when data.kind is nil", function()
      local data = MockData.ItemData({name = "Mystery"})
      data.kind = nil
      assert.are.equal("Everything", items:GetCategory(ctx, data))
    end)

    it("returns expansion when Expansion filter is enabled", function()
      categoryFilters["Expansion"] = true
      local data = MockData.ItemData({name = "Sword", expacID = 0})
      data.kind = const.BAG_KIND.BACKPACK
      data.containerInfo.quality = const.ITEM_QUALITY.Common
      assert.are.equal("Classic", items:GetCategory(ctx, data))
    end)

    it("returns 'Unknown' for unmapped expansion with Expansion filter", function()
      categoryFilters["Expansion"] = true
      local data = MockData.ItemData({name = "Sword", expacID = 99})
      data.kind = const.BAG_KIND.BACKPACK
      data.containerInfo.quality = const.ITEM_QUALITY.Common
      assert.are.equal("Unknown", items:GetCategory(ctx, data))
    end)

    it("returns 'Unknown' when expacID is nil with Expansion filter", function()
      categoryFilters["Expansion"] = true
      local data = MockData.ItemData({name = "Sword"})
      data.kind = const.BAG_KIND.BACKPACK
      data.containerInfo.quality = const.ITEM_QUALITY.Common
      data.itemInfo.expacID = nil
      assert.are.equal("Unknown", items:GetCategory(ctx, data))
    end)
  end)

  -- ─── findBestFit (stack merging) ────────────────────────────────────────────

  describe("findBestFit", function()

    local ctx

    before_each(function()
      ctx = addon:GetModule("Context"):New("FindBestFit")
    end)

    -- Helper: place items in the backpack slotInfo so GetItemDataFromSlotKey works
    local function placeItem(data)
      data.slotkey = data.bagid .. "_" .. data.slotid
      items:GetAllSlotInfo()[const.BAG_KIND.BACKPACK].itemsBySlotKey[data.slotkey] = data
      return data
    end

    it("moves a smaller stack onto a larger one when they fit", function()
      placeItem(MockData.ItemData({
        name = "Potion", bagid = 0, slotid = 1, count = 15, maxStack = 20,
        itemHash = "potion", slotkey = "0_1",
      }))
      local child = placeItem(MockData.ItemData({
        name = "Potion", bagid = 0, slotid = 2, count = 3, maxStack = 20,
        itemHash = "potion", slotkey = "0_2",
      }))

      local stackInfo = {rootItem = "0_1", slotkeys = {["0_2"] = true}, count = 2}
      local targets = {}
      local movePairs = {}

      items:findBestFit(ctx, child, stackInfo, targets, movePairs)

      assert.are.equal(1, #movePairs)
      assert.are.equal(0, movePairs[1].fromBag)
      assert.are.equal(2, movePairs[1].fromSlot)
      assert.are.equal(0, movePairs[1].toBag)
      assert.are.equal(1, movePairs[1].toSlot)
    end)

    it("does not move the root item", function()
      local root = placeItem(MockData.ItemData({
        name = "Potion", bagid = 0, slotid = 1, count = 5, maxStack = 20,
        itemHash = "potion", slotkey = "0_1",
      }))

      local stackInfo = {rootItem = "0_1", slotkeys = {}, count = 1}
      local targets = {}
      local movePairs = {}

      items:findBestFit(ctx, root, stackInfo, targets, movePairs)
      assert.are.equal(0, #movePairs)
    end)

    it("does not move items that are already full", function()
      placeItem(MockData.ItemData({
        name = "Potion", bagid = 0, slotid = 1, count = 20, maxStack = 20,
        itemHash = "potion", slotkey = "0_1",
      }))
      local full = placeItem(MockData.ItemData({
        name = "Potion", bagid = 0, slotid = 2, count = 20, maxStack = 20,
        itemHash = "potion", slotkey = "0_2",
      }))

      local stackInfo = {rootItem = "0_1", slotkeys = {["0_2"] = true}, count = 2}
      local targets = {}
      local movePairs = {}

      items:findBestFit(ctx, full, stackInfo, targets, movePairs)
      assert.are.equal(0, #movePairs)
    end)

    it("handles partial moves when target doesn't have enough room", function()
      placeItem(MockData.ItemData({
        name = "Potion", bagid = 0, slotid = 1, count = 18, maxStack = 20,
        itemHash = "potion", slotkey = "0_1",
      }))
      local child = placeItem(MockData.ItemData({
        name = "Potion", bagid = 0, slotid = 2, count = 5, maxStack = 20,
        itemHash = "potion", slotkey = "0_2",
      }))

      local stackInfo = {rootItem = "0_1", slotkeys = {["0_2"] = true}, count = 2}
      local targets = {}
      local movePairs = {}

      items:findBestFit(ctx, child, stackInfo, targets, movePairs)

      assert.are.equal(1, #movePairs)
      -- Partial move: root has 18, max 20, so only 2 can move
      assert.are.equal(2, movePairs[1].partial)
    end)
  end)

  -- ─── Search cache ───────────────────────────────────────────────────────────

  describe("Search cache", function()

    it("GetSearchCategory returns cached value", function()
      items.searchCache[const.BAG_KIND.BACKPACK]["0_1"] = "Cached Category"
      assert.are.equal("Cached Category", items:GetSearchCategory(const.BAG_KIND.BACKPACK, "0_1"))
    end)

    it("GetSearchCategory returns nil for uncached slotkey", function()
      assert.is_nil(items:GetSearchCategory(const.BAG_KIND.BACKPACK, "99_99"))
    end)

    it("WipeSearchCache clears both caches", function()
      items.searchCache[const.BAG_KIND.BACKPACK]["0_1"] = "Test"
      items.categoryPriorityCache[const.BAG_KIND.BACKPACK]["0_1"] = 5
      items:WipeSearchCache(const.BAG_KIND.BACKPACK)
      assert.is_nil(items.searchCache[const.BAG_KIND.BACKPACK]["0_1"])
      assert.is_nil(items.categoryPriorityCache[const.BAG_KIND.BACKPACK]["0_1"])
    end)
  end)
end)
