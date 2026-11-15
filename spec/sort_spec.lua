-- sort_spec.lua -- Unit tests for util/sort.lua (Sort module)

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Stub dependent modules BEFORE loading sort.lua (it calls GetModule at load time)
local database = StubBetterBagsModule("Database")
local const = StubBetterBagsModule("Constants")
local L = StubBetterBagsModule("Localization")

-- Set up constants that sort.lua references
const.BAG_KIND = {
  UNDEFINED = -1,
  BACKPACK = 0,
  BANK = 1,
}

const.BAG_VIEW = {
  UNDEFINED = 0,
  SECTION_GRID = 2,
  SECTION_ALL_BAGS = 4,
}

const.SECTION_SORT_TYPE = {
  ALPHABETICALLY = 1,
  SIZE_DESCENDING = 2,
  SIZE_ASCENDING = 3,
}

-- The keys an item order is made of (core/constants.lua).
const.ITEM_ORDER_KEY = {
  QUALITY = "quality", NAME = "name", ITEM_LEVEL = "itemLevel", UPGRADE_TRACK = "upgradeTrack",
  EQUIPMENT_SLOT = "equipmentSlot", ITEM_TYPE = "itemType", EXPANSION = "expansion", COUNT = "count",
  SELL_PRICE_STACK = "sellPriceStack", SELL_PRICE_EACH = "sellPriceEach",
}

-- Localization: L:G(key) returns the key as-is (no translations loaded)
function L:G(key) return key end

-- The vendor price of one item is the Items module's (items:SellPriceOf, spec/items_spec.lua); the sell
-- price tests give it the price each item is made with.
local itemsModule = StubBetterBagsModule("Items")

-- A category's own item order (Categories:ItemOrderOf); none unless a test gives one.
local categories = StubBetterBagsModule("Categories")
categories.ItemOrderOf = function() return nil end
categories.HasItemOrders = function() return false end

-- Now load the Sort module
ResetModuleStub("Sort", "util/sort.lua")
LoadBetterBagsModule("util/sort.lua")
local sort = addon:GetModule("Sort")

-- Use shared mock factories
local MockSection = MockData.Section
local MockItemData = MockData.ItemData

local KEY = const.ITEM_ORDER_KEY

-- by returns the comparison of an order made of the keys given.
local function by(...)
  return sort:ItemDataComparator({ ... })
end

-- guidsOf returns a sorted list's GUIDs, gaps and free slots left out.
local function guidsOf(list)
  local guids = {}
  for _, data in ipairs(list) do
    if not data.isFreeSlot and not data.isItemGap then table.insert(guids, data.itemInfo.itemGUID) end
  end
  return guids
end

-- ─── Tests ────────────────────────────────────────────────────────────────────

describe("Sort", function()
  local savedPriceOf

  before_each(function()
    savedPriceOf = rawget(itemsModule, "SellPriceOf")
    itemsModule.SellPriceOf = function(_, data) return data.itemInfo.sellPrice end
  end)

  after_each(function()
    itemsModule.SellPriceOf = savedPriceOf
  end)

  -- ─── Item orders: each key ────────────────────────────────────────────────
  -- Issue #108: an order is the keys the player chose (Item Order, Then By, And Then By), each breaking the
  -- ties of the one before; then the name, the bigger pile and the GUID, which make it total.

  describe("by quality", function()
    it("sorts higher quality before lower quality", function()
      local epic = MockItemData({name = "Sword", quality = 4, guid = "a"})
      local common = MockItemData({name = "Sword", quality = 1, guid = "b"})
      assert.is_true(by(KEY.QUALITY)(epic, common))
      assert.is_false(by(KEY.QUALITY)(common, epic))
    end)

    it("sorts by name when quality is equal", function()
      local axe = MockItemData({name = "Axe", quality = 3, guid = "a"})
      local sword = MockItemData({name = "Sword", quality = 3, guid = "b"})
      assert.is_true(by(KEY.QUALITY)(axe, sword))
      assert.is_false(by(KEY.QUALITY)(sword, axe))
    end)

    it("sorts the bigger pile first when name and quality match", function()
      local stack20 = MockItemData({name = "Potion", quality = 1, count = 20, guid = "a"})
      local stack5 = MockItemData({name = "Potion", quality = 1, count = 5, guid = "b"})
      assert.is_true(by(KEY.QUALITY)(stack20, stack5))
      assert.is_false(by(KEY.QUALITY)(stack5, stack20))
    end)

    it("falls back to the GUID for a stable sort", function()
      local a = MockItemData({name = "Potion", quality = 1, count = 1, guid = "aaa"})
      local b = MockItemData({name = "Potion", quality = 1, count = 1, guid = "zzz"})
      assert.is_true(by(KEY.QUALITY)(a, b))
      assert.is_false(by(KEY.QUALITY)(b, a))
    end)
  end)

  describe("by name", function()
    it("sorts by name first", function()
      local axe = MockItemData({name = "Axe", quality = 1, guid = "a"})
      local sword = MockItemData({name = "Sword", quality = 4, guid = "b"})
      assert.is_true(by(KEY.NAME, KEY.QUALITY)(axe, sword))
      assert.is_false(by(KEY.NAME, KEY.QUALITY)(sword, axe))
    end)

    it("sorts by the next key when names match", function()
      local epic = MockItemData({name = "Sword", quality = 4, guid = "b"})
      local common = MockItemData({name = "Sword", quality = 1, guid = "a"})
      assert.is_true(by(KEY.NAME, KEY.QUALITY)(epic, common))
      assert.is_false(by(KEY.NAME, KEY.QUALITY)(common, epic))
    end)
  end)

  describe("by item level", function()
    it("sorts higher item level first", function()
      local high = MockItemData({name = "B", quality = 1, itemLevel = 300, guid = "a"})
      local low = MockItemData({name = "A", quality = 1, itemLevel = 100, guid = "b"})
      assert.is_true(by(KEY.ITEM_LEVEL)(high, low))
      assert.is_false(by(KEY.ITEM_LEVEL)(low, high))
    end)

    it("falls back to the name when item level matches", function()
      local axe = MockItemData({name = "Axe", quality = 1, itemLevel = 200, guid = "a"})
      local sword = MockItemData({name = "Sword", quality = 1, itemLevel = 200, guid = "b"})
      assert.is_true(by(KEY.ITEM_LEVEL)(axe, sword))
      assert.is_false(by(KEY.ITEM_LEVEL)(sword, axe))
    end)
  end)

  describe("by expansion", function()
    it("sorts the older expansion first", function()
      local classic = MockItemData({name = "B", quality = 1, expacID = 0, guid = "a"})
      local wrath = MockItemData({name = "A", quality = 1, expacID = 2, guid = "b"})
      assert.is_true(by(KEY.EXPANSION)(classic, wrath))
      assert.is_false(by(KEY.EXPANSION)(wrath, classic))
    end)

    it("falls back to the name within an expansion", function()
      local axe = MockItemData({name = "Axe", quality = 1, expacID = 3, guid = "a"})
      local sword = MockItemData({name = "Sword", quality = 1, expacID = 3, guid = "b"})
      assert.is_true(by(KEY.EXPANSION)(axe, sword))
      assert.is_false(by(KEY.EXPANSION)(sword, axe))
    end)

    it("reads a missing expansion as Classic (0)", function()
      local noExpac = MockItemData({name = "B", quality = 1, guid = "a"})
      local wrath = MockItemData({name = "A", quality = 1, expacID = 2, guid = "b"})
      assert.is_true(by(KEY.EXPANSION)(noExpac, wrath))
      assert.is_false(by(KEY.EXPANSION)(wrath, noExpac))
    end)
  end)

  -- The character sheet's order, top to bottom, then the weapons, then what is equipped elsewhere; the comment
  -- on issue #108 had three Stormwind cloaks of three names apart in a section, which Equipment Slot puts together.
  describe("by equipment slot", function()
    local slots = { "INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_BODY", "INVTYPE_CHEST", "INVTYPE_WAIST",
      "INVTYPE_LEGS", "INVTYPE_FEET", "INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_FINGER", "INVTYPE_TRINKET", "INVTYPE_CLOAK",
      "INVTYPE_2HWEAPON", "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPON", "INVTYPE_WEAPONOFFHAND", "INVTYPE_SHIELD",
      "INVTYPE_HOLDABLE", "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN", "INVTYPE_RELIC", "INVTYPE_AMMO",
      "INVTYPE_QUIVER", "INVTYPE_TABARD", "INVTYPE_PROFESSION_TOOL", "INVTYPE_PROFESSION_GEAR",
      "INVTYPE_EQUIPABLESPELL_OFFENSIVE", "INVTYPE_EQUIPABLESPELL_UTILITY", "INVTYPE_EQUIPABLESPELL_DEFENSIVE",
      "INVTYPE_EQUIPABLESPELL_WEAPON", "INVTYPE_BAG" }

    it("follows the character sheet, whatever the names, what is not equipment last", function()
      local list = {}
      -- Names the other way round, so only the slot can give this order.
      for i, slot in ipairs(slots) do
        table.insert(list, MockItemData({ name = string.format("%02d", 99 - i), equipLoc = slot, guid = slot }))
      end
      table.insert(list, MockItemData({ name = "A Potion", equipLoc = "INVTYPE_NON_EQUIP_IGNORE", guid = "potion" }))
      table.insert(list, MockItemData({ name = "B Ore", equipLoc = "", guid = "ore" }))
      math.randomseed(108)
      for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
      end
      table.sort(list, by(KEY.EQUIPMENT_SLOT))
      local want = {}
      for _, slot in ipairs(slots) do table.insert(want, slot) end
      table.insert(want, "potion")
      table.insert(want, "ore")
      assert.are.same(want, guidsOf(list))
    end)

    it("holds a robe and a chest piece in one slot, the next key between them", function()
      local robe = MockItemData({ name = "A Robe", equipLoc = "INVTYPE_ROBE", guid = "robe" })
      local chest = MockItemData({ name = "B Chest", equipLoc = "INVTYPE_CHEST", guid = "chest" })
      assert.is_true(by(KEY.EQUIPMENT_SLOT)(robe, chest))
      assert.is_false(by(KEY.EQUIPMENT_SLOT)(chest, robe))
    end)

    -- Asked in #203 (a duplicate of #108): "group armor slots together ... and secondarily sorted by item level".
    it("puts each slot's gear together, the highest item level first, with Then By Item Level", function()
      local list = {
        MockItemData({ name = "Wrist A", equipLoc = "INVTYPE_WRIST", itemLevel = 300, guid = "wrist300" }),
        MockItemData({ name = "Helm", equipLoc = "INVTYPE_HEAD", itemLevel = 250, guid = "head250" }),
        MockItemData({ name = "Wrist B", equipLoc = "INVTYPE_WRIST", itemLevel = 320, guid = "wrist320" }),
        MockItemData({ name = "Cloak", equipLoc = "INVTYPE_CLOAK", itemLevel = 400, guid = "cloak400" }),
        MockItemData({ name = "Wrist C", equipLoc = "INVTYPE_WRIST", itemLevel = 310, guid = "wrist310" }),
      }
      table.sort(list, by(KEY.EQUIPMENT_SLOT, KEY.ITEM_LEVEL))
      assert.are.same({ "head250", "wrist320", "wrist310", "wrist300", "cloak400" }, guidsOf(list))
    end)
  end)

  -- Blizzard's item class, then its subclass, by their IDs (Enum.ItemClass): the same in every language, and
  -- under Armor, Cloth, Leather, Mail, then Plate.
  describe("by item type", function()
    it("orders by class, then subclass", function()
      local list = {
        MockItemData({ name = "A", classID = 4, subclassID = 4, guid = "plate" }),
        MockItemData({ name = "B", classID = 4, subclassID = 1, guid = "cloth" }),
        MockItemData({ name = "C", classID = 2, subclassID = 7, guid = "sword" }),
        MockItemData({ name = "D", classID = 0, subclassID = 1, guid = "potion" }),
        MockItemData({ name = "E", classID = 4, subclassID = 2, guid = "leather" }),
      }
      table.sort(list, by(KEY.ITEM_TYPE))
      assert.are.same({ "potion", "sword", "cloth", "leather", "plate" }, guidsOf(list))
    end)
  end)

  describe("by count", function()
    it("puts the bigger count the button shows first: a merged stack's total", function()
      local merged = MockItemData({ name = "C", count = 5, stackedCount = 30, guid = "merged" })
      local twenty = MockItemData({ name = "B", count = 20, guid = "twenty" })
      local one = MockItemData({ name = "A", count = 1, guid = "one" })
      local list = { one, merged, twenty }
      table.sort(list, by(KEY.COUNT))
      assert.are.same({ "merged", "twenty", "one" }, guidsOf(list))
    end)
  end)

  -- ─── Item orders: sell price ──────────────────────────────────────────────
  -- Issue #1303: Sell Price (Stack) orders by what the stack the button shows sells for, Sell Price (Each)
  -- by what one sells for, highest first. The price is the one Auto Sell uses (items:SellPriceOf).

  describe("by sell price", function()
    it("Sell Price (Stack) puts the stack worth more first: its price times its count", function()
      local cloth = MockItemData({ name = "Cloth", sellPrice = 10, count = 20, guid = "a" })
      local ring = MockItemData({ name = "Ring", sellPrice = 150, count = 1, guid = "b" })
      assert.is_true(by(KEY.SELL_PRICE_STACK)(cloth, ring))
      assert.is_false(by(KEY.SELL_PRICE_STACK)(ring, cloth))
    end)

    it("Sell Price (Stack) counts what the button shows: a merged stack's total", function()
      local cloth = MockItemData({ name = "Cloth", sellPrice = 10, count = 5, stackedCount = 30, guid = "a" })
      local ring = MockItemData({ name = "Ring", sellPrice = 200, count = 1, guid = "b" })
      assert.is_true(by(KEY.SELL_PRICE_STACK)(cloth, ring))
      assert.is_false(by(KEY.SELL_PRICE_STACK)(ring, cloth))
    end)

    it("Sell Price (Each) puts the item worth more each first, whatever the count", function()
      local cloth = MockItemData({ name = "Cloth", sellPrice = 10, count = 20, stackedCount = 40, guid = "a" })
      local ring = MockItemData({ name = "Ring", sellPrice = 150, count = 1, guid = "b" })
      assert.is_true(by(KEY.SELL_PRICE_EACH)(ring, cloth))
      assert.is_false(by(KEY.SELL_PRICE_EACH)(cloth, ring))
    end)

    for _, case in ipairs({ { "Sell Price (Stack)", KEY.SELL_PRICE_STACK }, { "Sell Price (Each)", KEY.SELL_PRICE_EACH } }) do
      local name, key = case[1], case[2]

      it(name .. " puts what no vendor buys (0) after everything worth a copper", function()
        local unsellable = MockItemData({ name = "A Quest Item", sellPrice = 0, count = 1, guid = "a" })
        local junk = MockItemData({ name = "Z Junk", sellPrice = 1, count = 1, guid = "b" })
        assert.is_true(by(key)(junk, unsellable))
        assert.is_false(by(key)(unsellable, junk))
      end)

      it(name .. " falls back to the name, and last to the GUID", function()
        local apple = MockItemData({ name = "Apple", sellPrice = 5, count = 1, guid = "z" })
        local bread = MockItemData({ name = "Bread", sellPrice = 5, count = 1, guid = "a" })
        assert.is_true(by(key)(apple, bread))
        assert.is_false(by(key)(bread, apple))
        local first = MockItemData({ name = "Potion", sellPrice = 5, count = 1, guid = "aaa" })
        local second = MockItemData({ name = "Potion", sellPrice = 5, count = 1, guid = "zzz" })
        assert.is_true(by(key)(first, second))
        assert.is_false(by(key)(second, first))
      end)
    end

    it("Sell Price (Stack) breaks a tie of worth by the bigger pile", function()
      local few = MockItemData({ name = "Potion", sellPrice = 10, count = 2, guid = "a" })
      local many = MockItemData({ name = "Potion", sellPrice = 5, count = 4, guid = "b" })
      assert.is_true(by(KEY.SELL_PRICE_STACK)(many, few))
      assert.is_false(by(KEY.SELL_PRICE_STACK)(few, many))
    end)

    it("Sell Price (Each) breaks a tie of price by the bigger pile", function()
      local few = MockItemData({ name = "Potion", sellPrice = 5, count = 2, guid = "a" })
      local many = MockItemData({ name = "Potion", sellPrice = 5, count = 3, guid = "b" })
      assert.is_true(by(KEY.SELL_PRICE_EACH)(many, few))
      assert.is_false(by(KEY.SELL_PRICE_EACH)(few, many))
    end)

    it("takes each item's price from items:SellPriceOf", function()
      itemsModule.SellPriceOf = function(_, data) return data.itemInfo.itemName == "Cheap" and 1 or 100 end
      local cheap = MockItemData({ name = "Cheap", sellPrice = 900, guid = "a" })
      local dear = MockItemData({ name = "Dear", sellPrice = 1, guid = "b" })
      assert.is_true(by(KEY.SELL_PRICE_EACH)(dear, cheap))
      assert.is_true(by(KEY.SELL_PRICE_STACK)(dear, cheap))
    end)

    it("sorts a whole list by the stack's worth with table.sort", function()
      local list = {
        MockItemData({ name = "Ring", sellPrice = 150, count = 1, guid = "r" }),
        { isFreeSlot = true, bagid = 0, slotid = 9 },
        MockItemData({ name = "Quest Item", sellPrice = 0, count = 1, guid = "q" }),
        MockItemData({ name = "Cloth", sellPrice = 10, count = 20, guid = "c" }),
        MockItemData({ name = "Herb", sellPrice = 15, count = 10, guid = "h" }),
        MockItemData({ name = "Potion", sellPrice = 75, count = 2, guid = "p" }),
      }
      table.sort(list, by(KEY.SELL_PRICE_STACK))
      -- Cloth 200; Herb, Potion and Ring 150 each, by name; Quest Item 0.
      assert.are.same({ "c", "h", "p", "r", "q" }, guidsOf(list))
      assert.is_true(list[6].isFreeSlot)
    end)
  end)

  -- ─── Item orders: upgrade track ───────────────────────────────────────────
  -- Issue #769: gear by its upgrade track (Myth, Hero, Champion...) rather than its item level, which mixes
  -- the tracks (a Veteran 6/6 is above a Champion 1/6). A track is ranked by the item level it upgrades to
  -- (items:ReadItemTraits' upgradeMaxItemLevel): the track's name is in the game's language. The order it was
  -- (Upgrade Track) is the keys Upgrade Track, then Item Level.

  describe("by upgrade track", function()
    local byTrack = by(KEY.UPGRADE_TRACK, KEY.ITEM_LEVEL)

    -- Gear on a track of 6 ranks, the item level it is at and the one its track upgrades to.
    local function gear(name, level, track, rank, top, opts)
      opts = opts or {}
      return MockItemData({ name = name, currentItemLevel = level, count = opts.count, guid = opts.guid or name,
        traits = { isEquipment = true, upgradeTrack = track, upgradeLevel = rank, upgradeMax = 6,
          upgradeMaxItemLevel = top, stats = {} } })
    end

    -- An item read with its data that is on no track (old gear, a consumable).
    local function untracked(name, level, opts)
      opts = opts or {}
      return MockItemData({ name = name, currentItemLevel = level, count = opts.count, guid = opts.guid or name,
        traits = { isEquipment = opts.equipment, stats = {} } })
    end

    it("puts gear on a higher track first, above gear of a lower track at a higher item level", function()
      local champion = gear("Champion Boots", 308, "Champion", 6, 308)
      local hero = gear("Hero Boots", 305, "Hero", 1, 321)
      assert.is_true(byTrack(hero, champion))
      assert.is_false(byTrack(champion, hero))
    end)

    it("puts the higher item level first within a track", function()
      local low = gear("A Hero Ring", 305, "Hero", 1, 321)
      local high = gear("B Hero Ring", 311, "Hero", 3, 321)
      assert.is_true(byTrack(high, low))
      assert.is_false(byTrack(low, high))
    end)

    it("ranks the tracks by the item level they upgrade to, never by their names", function()
      local list = {
        gear("Adventurer Cloak", 282, "Adventurer", 6, 282),
        { isFreeSlot = true, bagid = 0, slotid = 9 },
        gear("Veteran Belt", 279, "Veteran", 1, 295),
        untracked("Potion", 1),
        gear("Champion Belt", 292, "Champion", 1, 308),
        gear("Veteran Helm", 295, "Veteran", 6, 295),
        untracked("Old Helm", 250, { equipment = true }),
        gear("Hero Helm", 305, "Hero", 1, 321),
        gear("Champion Helm", 308, "Champion", 6, 308),
        gear("Myth Ring", 318, "Myth", 1, 334),
      }
      table.sort(list, byTrack)
      assert.are.same({ "Myth Ring", "Hero Helm", "Champion Helm", "Champion Belt", "Veteran Helm", "Veteran Belt",
        "Adventurer Cloak", "Old Helm", "Potion" }, guidsOf(list))
      assert.is_true(list[10].isFreeSlot)
    end)

    it("puts an item on no track after every item on one, whatever its item level", function()
      local adventurer = gear("Adventurer Cloak", 266, "Adventurer", 1, 282)
      local old = untracked("Old Helm", 400, { equipment = true })
      assert.is_true(byTrack(adventurer, old))
      assert.is_false(byTrack(old, adventurer))
      -- Read cold: no traits yet, so no track either.
      local cold = MockItemData({ name = "Cold Helm", currentItemLevel = 500, guid = "cold" })
      assert.is_true(byTrack(adventurer, cold))
      assert.is_false(byTrack(cold, adventurer))
    end)

    it("orders the items on no track by item level, as Item Level does", function()
      local high = untracked("Old Helm", 400, { equipment = true })
      local low = untracked("Older Helm", 300, { equipment = true })
      assert.is_true(byTrack(high, low))
      assert.is_false(byTrack(low, high))
    end)

    it("falls back to the name, then the bigger pile, and last the GUID", function()
      local axe = gear("Axe", 305, "Hero", 1, 321)
      local sword = gear("Sword", 305, "Hero", 1, 321)
      assert.is_true(byTrack(axe, sword))
      assert.is_false(byTrack(sword, axe))
      local many = untracked("Potion", 1, { count = 20, guid = "z" })
      local few = untracked("Potion", 1, { count = 5, guid = "a" })
      assert.is_true(byTrack(many, few))
      assert.is_false(byTrack(few, many))
      local first = untracked("Potion", 1, { guid = "aaa" })
      local second = untracked("Potion", 1, { guid = "zzz" })
      assert.is_true(byTrack(first, second))
      assert.is_false(byTrack(second, first))
    end)
  end)

  -- ─── Item orders: tiers ───────────────────────────────────────────────────

  describe("an order of several keys", function()
    it("breaks the first key's ties by the second, and its ties by the third, before the name", function()
      local list = {
        MockItemData({ name = "A", classID = 4, subclassID = 4, equipLoc = "INVTYPE_WRIST", itemLevel = 300, guid = "plateWrist300" }),
        MockItemData({ name = "B", classID = 4, subclassID = 4, equipLoc = "INVTYPE_HEAD", itemLevel = 280, guid = "plateHead280" }),
        MockItemData({ name = "C", classID = 4, subclassID = 1, equipLoc = "INVTYPE_WRIST", itemLevel = 290, guid = "clothWrist290" }),
        MockItemData({ name = "D", classID = 4, subclassID = 4, equipLoc = "INVTYPE_WRIST", itemLevel = 310, guid = "plateWrist310" }),
        MockItemData({ name = "E", classID = 4, subclassID = 4, equipLoc = "INVTYPE_HEAD", itemLevel = 300, guid = "plateHead300" }),
      }
      table.sort(list, by(KEY.ITEM_TYPE, KEY.EQUIPMENT_SLOT, KEY.ITEM_LEVEL))
      assert.are.same({ "clothWrist290", "plateHead300", "plateHead280", "plateWrist310", "plateWrist300" }, guidsOf(list))
    end)

    it("breaks the ties of every key chosen by the name, once", function()
      -- Quality then Item Level: equal on both, so the name decides.
      local b = MockItemData({ name = "B", quality = 3, itemLevel = 200, guid = "a" })
      local a = MockItemData({ name = "A", quality = 3, itemLevel = 200, guid = "b" })
      assert.is_true(by(KEY.QUALITY, KEY.ITEM_LEVEL)(a, b))
      assert.is_false(by(KEY.QUALITY, KEY.ITEM_LEVEL)(b, a))
      -- Name chosen second: the third key decides before the GUID.
      local low = MockItemData({ name = "Ring", quality = 3, itemLevel = 200, guid = "a" })
      local high = MockItemData({ name = "Ring", quality = 3, itemLevel = 250, guid = "b" })
      assert.is_true(by(KEY.QUALITY, KEY.NAME, KEY.ITEM_LEVEL)(high, low))
      assert.is_false(by(KEY.QUALITY, KEY.NAME, KEY.ITEM_LEVEL)(low, high))
    end)

    -- What the orders a profile saved before (const.ITEM_SORT_TYPE) became, each giving the order it gave
    -- (DB:MigrateItemOrders, item-sort.md §1).
    it("gives each order a profile saved before the order it gave", function()
      local function items()
        return {
          MockItemData({ name = "Sword", quality = 4, itemLevel = 300, expacID = 9, sellPrice = 500, count = 1, guid = "sword" }),
          MockItemData({ name = "Axe", quality = 2, itemLevel = 310, expacID = 2, sellPrice = 100, count = 1, guid = "axe" }),
          MockItemData({ name = "Potion", quality = 1, itemLevel = 1, expacID = 9, sellPrice = 10, count = 20, guid = "potion20" }),
          MockItemData({ name = "Potion", quality = 1, itemLevel = 1, expacID = 9, sellPrice = 10, count = 5, guid = "potion5" }),
          MockItemData({ name = "Cloth", quality = 1, itemLevel = 1, expacID = 0, sellPrice = 30, count = 10, guid = "cloth" }),
        }
      end
      local cases = {
        { "Alphabetically", { KEY.NAME, KEY.QUALITY }, { "axe", "cloth", "potion20", "potion5", "sword" } },
        { "Quality", { KEY.QUALITY }, { "sword", "axe", "cloth", "potion20", "potion5" } },
        { "Item Level", { KEY.ITEM_LEVEL }, { "axe", "sword", "cloth", "potion20", "potion5" } },
        { "Expansion", { KEY.EXPANSION }, { "cloth", "axe", "potion20", "potion5", "sword" } },
        { "Sell Price (Stack)", { KEY.SELL_PRICE_STACK }, { "sword", "cloth", "potion20", "axe", "potion5" } },
        { "Sell Price (Each)", { KEY.SELL_PRICE_EACH }, { "sword", "axe", "cloth", "potion20", "potion5" } },
        { "Upgrade Track", { KEY.UPGRADE_TRACK, KEY.ITEM_LEVEL }, { "axe", "sword", "cloth", "potion20", "potion5" } },
      }
      for _, case in ipairs(cases) do
        local list = items()
        table.sort(list, sort:ItemDataComparator(case[2]))
        assert.are.same(case[3], guidsOf(list), case[1])
      end
    end)

    it("puts free slots and gaps last, whatever the order", function()
      for _, key in pairs(KEY) do
        local item = MockItemData({ name = "Sword", quality = 4, guid = "a" })
        local freeSlot = { isFreeSlot = true, bagid = 0, slotid = 1 }
        local gapSlot = MockItemData({ name = "A", quality = 5, itemLevel = 999, guid = "gap" })
        gapSlot.isItemGap = true
        assert.is_false(by(key)(freeSlot, item), key)
        assert.is_true(by(key)(item, freeSlot), key)
        assert.is_false(by(key)(gapSlot, item), key)
        assert.is_true(by(key)(item, gapSlot), key)
      end
    end)

    it("leaves an item without its data unordered", function()
      for _, key in pairs(KEY) do
        local good = MockItemData({ name = "Sword", quality = 4, sellPrice = 50, guid = "a" })
        local bad = MockItemData({ name = "Shield", quality = 1, sellPrice = 10, guid = "b" })
        bad.itemInfo.itemGUID = nil
        assert.is_false(by(key)(good, bad), key)
        assert.is_false(by(key)(bad, good), key)
      end
    end)

    it("refuses a key it does not know", function()
      assert.has_error(function() sort:ItemDataComparator({ "nope" }) end)
    end)
  end)

  -- ─── The bags' item order ─────────────────────────────────────────────────

  describe("GetItemDataSortFunction", function()
    local savedGetOrder, savedOrderOf, savedHas

    before_each(function()
      savedGetOrder, savedOrderOf, savedHas = rawget(database, "GetItemOrder"), categories.ItemOrderOf,
        categories.HasItemOrders
    end)

    after_each(function()
      database.GetItemOrder, categories.ItemOrderOf, categories.HasItemOrders = savedGetOrder, savedOrderOf, savedHas
    end)

    -- What most bags are: the bag's order alone, with nothing to read per category (the profiler's cost, item-sort.md §5).
    it("sorts by the bag's order alone, reading no category's, when no category the bag uses has its own", function()
      local asked = {}
      database.GetItemOrder = function() return { KEY.ITEM_LEVEL } end
      categories.HasItemOrders = function(_, kind)
        table.insert(asked, kind)
        return false
      end
      categories.ItemOrderOf = function() error("no category's order is read") end
      local fn = sort:GetItemDataSortFunction(const.BAG_KIND.BANK, const.BAG_VIEW.SECTION_GRID)
      assert.are.same({ const.BAG_KIND.BANK }, asked)
      local high = MockItemData({ name = "B", itemLevel = 300, category = "Gear", guid = "a" })
      local low = MockItemData({ name = "A", itemLevel = 100, category = "Mats", guid = "b" })
      assert.is_true(fn(high, low))
      assert.is_false(fn(low, high))
    end)

    it("returns a no-op for UNDEFINED bag kind", function()
      local fn = sort:GetItemDataSortFunction(const.BAG_KIND.UNDEFINED, const.BAG_VIEW.SECTION_GRID)
      local a = MockItemData({name = "A", quality = 1, guid = "a"})
      local b = MockItemData({name = "B", quality = 1, guid = "b"})
      assert.is_false(fn(a, b))
      assert.is_false(fn(b, a))
    end)

    it("sorts by the bag's order in its view", function()
      local asked = {}
      database.GetItemOrder = function(_, kind, view)
        table.insert(asked, { kind, view })
        return { KEY.ITEM_LEVEL }
      end
      local fn = sort:GetItemDataSortFunction(const.BAG_KIND.BANK, const.BAG_VIEW.SECTION_GRID)
      assert.are.same({ { const.BAG_KIND.BANK, const.BAG_VIEW.SECTION_GRID } }, asked)
      local high = MockItemData({ name = "B", itemLevel = 300, guid = "a" })
      local low = MockItemData({ name = "A", itemLevel = 100, guid = "b" })
      assert.is_true(fn(high, low))
      assert.is_false(fn(low, high))
    end)

    -- Asked: "each category can have its own sort order". A section shows its category's items in the list's
    -- order (Phase10_PartitionIntoTabs), so a category with its own order has its items in it, the others in the
    -- bag's; the categories' items are kept apart in the list so the whole of it is one order table.sort can use.
    describe("with a category's own order", function()
      local asked

      local function list()
        return {
          MockItemData({ name = "Z Helm", itemLevel = 300, category = "Gear", guid = "gear300" }),
          MockItemData({ name = "B Ore", itemLevel = 50, category = "Mats", guid = "ore" }),
          MockItemData({ name = "A Helm", itemLevel = 250, category = "Gear", guid = "gear250" }),
          { isFreeSlot = true, bagid = 0, slotid = 9 },
          MockItemData({ name = "A Herb", itemLevel = 60, category = "Mats", guid = "herb" }),
          MockItemData({ name = "M Ring", itemLevel = 400, category = "Gear", guid = "gear400" }),
          MockItemData({ name = "C Potion", itemLevel = 10, category = "Recent Items", guid = "potion" }),
          MockItemData({ name = "B Flask", itemLevel = 20, category = "Recent Items", guid = "flask" }),
        }
      end

      local function byCategory(sorted)
        local out = {}
        for _, data in ipairs(sorted) do
          if not data.isFreeSlot then
            local category = data.itemInfo.category
            out[category] = out[category] or {}
            table.insert(out[category], data.itemInfo.itemGUID)
          end
        end
        return out
      end

      before_each(function()
        asked = {}
        database.GetItemOrder = function() return { KEY.NAME } end
        categories.HasItemOrders = function() return true end
        categories.ItemOrderOf = function(_, name, kind)
          table.insert(asked, { name, kind })
          return name == "Gear" and { KEY.ITEM_LEVEL } or nil
        end
      end)

      it("sorts that category's items by it, every other by the bag's", function()
        local sorted = list()
        table.sort(sorted, sort:GetItemDataSortFunction(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID))
        assert.are.same({
          Gear = { "gear400", "gear300", "gear250" },
          Mats = { "herb", "ore" },
          ["Recent Items"] = { "flask", "potion" },
        }, byCategory(sorted))
        assert.is_true(sorted[#sorted].isFreeSlot, "free slots last")
      end)

      it("asks for each category's order once in a sort, in the bag sorted", function()
        local sorted = list()
        table.sort(sorted, sort:GetItemDataSortFunction(const.BAG_KIND.BANK, const.BAG_VIEW.SECTION_GRID))
        local seen = {}
        for _, ask in ipairs(asked) do
          assert.are.equal(const.BAG_KIND.BANK, ask[2])
          assert.is_nil(seen[ask[1]], "asked again for " .. ask[1])
          seen[ask[1]] = true
        end
        assert.are.same({ Gear = true, Mats = true, ["Recent Items"] = true }, seen)
      end)

      it("gives every category its items in order however the list starts out", function()
        math.randomseed(1108)
        for _ = 1, 200 do
          local sorted = list()
          for i = #sorted, 2, -1 do
            local j = math.random(i)
            sorted[i], sorted[j] = sorted[j], sorted[i]
          end
          table.sort(sorted, sort:GetItemDataSortFunction(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID))
          assert.are.same({
            Gear = { "gear400", "gear300", "gear250" },
            Mats = { "herb", "ore" },
            ["Recent Items"] = { "flask", "potion" },
          }, byCategory(sorted))
          assert.is_true(sorted[#sorted].isFreeSlot)
        end
      end)

      it("leaves an item without its data unordered, its category's order or not", function()
        local fn = sort:GetItemDataSortFunction(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID)
        for _, category in ipairs({ "Gear", "Mats" }) do
          local good = MockItemData({ name = "A", itemLevel = 300, category = category, guid = "a" })
          local bad = MockItemData({ name = "B", itemLevel = 100, category = category, guid = "b" })
          bad.itemInfo.itemName = nil
          assert.is_false(fn(good, bad), category)
          assert.is_false(fn(bad, good), category)
        end
      end)

      -- The bag's order's items are told from a category's by whether it has its own, never by a name: a category
      -- may be named anything.
      it("keeps a category with its own order apart from the bag's, whatever its name", function()
        categories.ItemOrderOf = function(_, name) return name == "" and { KEY.ITEM_LEVEL } or nil end
        local fn = sort:GetItemDataSortFunction(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID)
        local low = MockItemData({ name = "A", itemLevel = 100, category = "", guid = "low" })
        local high = MockItemData({ name = "B", itemLevel = 300, category = "", guid = "high" })
        local other = MockItemData({ name = "C", itemLevel = 500, category = "Other", guid = "other" })
        local sorted = { low, other, high }
        table.sort(sorted, fn)
        assert.are.same({ "other", "high", "low" }, guidsOf(sorted))
        assert.is_true(fn(other, low))
        assert.is_false(fn(low, other))
      end)

      it("holds the order a strict weak order across categories", function()
        local fn = sort:GetItemDataSortFunction(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID)
        local items = list()
        for _, a in ipairs(items) do
          assert.is_false(fn(a, a), "irreflexive")
          for _, b in ipairs(items) do
            assert.is_false(fn(a, b) and fn(b, a), "asymmetric")
            for _, c in ipairs(items) do
              if fn(a, b) and fn(b, c) then
                assert.is_true(fn(a, c), "transitive")
              end
            end
          end
        end
      end)
    end)
  end)

  -- ─── The keys a client offers ─────────────────────────────────────────────

  describe("the keys an order is chosen from", function()
    it("lists every key in the dropdown's order, Upgrade Track after Item Level where the client has tracks", function()
      assert.are.same({ KEY.NAME, KEY.QUALITY, KEY.ITEM_LEVEL, KEY.UPGRADE_TRACK, KEY.EQUIPMENT_SLOT, KEY.ITEM_TYPE,
        KEY.EXPANSION, KEY.COUNT, KEY.SELL_PRICE_STACK, KEY.SELL_PRICE_EACH }, sort:ItemOrderKeys())
      local names = {}
      for i, key in ipairs(sort:ItemOrderKeys()) do names[i] = sort:ItemOrderKeyName(key) end
      assert.are.same({ "Name", "Quality", "Item Level", "Upgrade Track", "Equipment Slot", "Item Type", "Expansion",
        "Count", "Sell Price (Stack)", "Sell Price (Each)" }, names)
    end)

    -- The client's APIs are what they are from the start, so the Sort module decides when it loads: where the
    -- client reads no tracks (items:ReadItemTraits), no item has one, and Upgrade Track would do nothing.
    it("leaves Upgrade Track out where the client has no upgrade tracks", function()
      local getUpgradeInfo = _G.C_Item.GetItemUpgradeInfo
      finally(function()
        _G.C_Item.GetItemUpgradeInfo = getUpgradeInfo
        LoadFreshBetterBagsModule("Sort", "util/sort.lua")
      end)
      _G.C_Item.GetItemUpgradeInfo = nil
      local fresh = LoadFreshBetterBagsModule("Sort", "util/sort.lua")
      assert.are.same({ KEY.NAME, KEY.QUALITY, KEY.ITEM_LEVEL, KEY.EQUIPMENT_SLOT, KEY.ITEM_TYPE, KEY.EXPANSION, KEY.COUNT,
        KEY.SELL_PRICE_STACK, KEY.SELL_PRICE_EACH }, fresh:ItemOrderKeys())
      assert.is_false(fresh:OffersItemOrderKey(KEY.UPGRADE_TRACK))
      assert.is_true(fresh:OffersItemOrderKey(KEY.ITEM_LEVEL))
    end)
  end)

  -- ─── Choosing an order's tiers ────────────────────────────────────────────
  -- What the three dropdowns (Item Order, Then By, And Then By) list and save, the bag's and a category's alike.

  describe("choosing an order's tiers", function()
    local all = { "Name", "Quality", "Item Level", "Upgrade Track", "Equipment Slot", "Item Type", "Expansion", "Count",
      "Sell Price (Stack)", "Sell Price (Each)" }

    local function without(...)
      local drop, out = {}, { "None" }
      for _, name in ipairs({ ... }) do drop[name] = true end
      for _, name in ipairs(all) do
        if not drop[name] then table.insert(out, name) end
      end
      return out
    end

    it("lists every key for the first tier, and None then the keys not taken above for a later one", function()
      local order = { KEY.EQUIPMENT_SLOT, KEY.ITEM_LEVEL }
      assert.are.same(all, sort:ItemOrderChoices(order, 1))
      assert.are.same(without("Equipment Slot"), sort:ItemOrderChoices(order, 2))
      assert.are.same(without("Equipment Slot", "Item Level"), sort:ItemOrderChoices(order, 3))
    end)

    it("shows each tier's key by name, None for a tier the order has not got", function()
      local order = { KEY.EQUIPMENT_SLOT, KEY.ITEM_LEVEL }
      assert.are.equal("Equipment Slot", sort:ItemOrderChoice(order, 1))
      assert.are.equal("Item Level", sort:ItemOrderChoice(order, 2))
      assert.are.equal("None", sort:ItemOrderChoice(order, 3))
    end)

    it("sets a tier to a key, never changing the order it was given", function()
      local order = { KEY.QUALITY }
      local chosen = sort:WithItemOrderChoice(order, 2, "Item Level")
      assert.are.same({ KEY.QUALITY, KEY.ITEM_LEVEL }, chosen)
      assert.are.same({ KEY.QUALITY }, order)
      assert.are.same({ KEY.NAME, KEY.ITEM_LEVEL }, sort:WithItemOrderChoice(chosen, 1, "Name"))
      assert.are.same({ KEY.QUALITY, KEY.ITEM_LEVEL, KEY.COUNT }, sort:WithItemOrderChoice(chosen, 3, "Count"))
    end)

    it("moves a key chosen above from the tier below it: a key is in an order once", function()
      local order = { KEY.QUALITY, KEY.ITEM_LEVEL, KEY.COUNT }
      assert.are.same({ KEY.COUNT, KEY.ITEM_LEVEL }, sort:WithItemOrderChoice(order, 1, "Count"))
      assert.are.same({ KEY.QUALITY, KEY.COUNT }, sort:WithItemOrderChoice(order, 2, "Count"))
    end)

    it("takes a later tier out with None, the tiers below moving up", function()
      local order = { KEY.QUALITY, KEY.ITEM_LEVEL, KEY.COUNT }
      assert.are.same({ KEY.QUALITY, KEY.COUNT }, sort:WithItemOrderChoice(order, 2, "None"))
      assert.are.same({ KEY.QUALITY, KEY.ITEM_LEVEL }, sort:WithItemOrderChoice(order, 3, "None"))
      assert.are.same({ KEY.QUALITY }, sort:WithItemOrderChoice({ KEY.QUALITY }, 2, "None"))
    end)

    -- An order is never empty and never has a hole: the first tier has no None, and a tier below one the order has not
    -- got is its next.
    it("keeps the first tier, and fills the next tier the order has not got", function()
      assert.are.same({ KEY.QUALITY, KEY.ITEM_LEVEL }, sort:WithItemOrderChoice({ KEY.QUALITY, KEY.ITEM_LEVEL }, 1, "None"))
      assert.are.same({ KEY.QUALITY, KEY.COUNT }, sort:WithItemOrderChoice({ KEY.QUALITY }, 3, "Count"))
    end)
  end)

  -- ─── Section Sort: Alphabetically ─────────────────────────────────────────

  describe("SortSectionsAlphabetically", function()

    before_each(function()
      -- Default: no pinned sections
      database.GetCustomSectionSort = function(_, _) return {} end
    end)

    it("sorts sections alphabetically by title", function()
      local armor = MockSection({title = "Armor"})
      local weapons = MockSection({title = "Weapons"})
      assert.is_true(sort.SortSectionsAlphabetically(const.BAG_KIND.BACKPACK, armor, weapons))
      assert.is_false(sort.SortSectionsAlphabetically(const.BAG_KIND.BACKPACK, weapons, armor))
    end)

    it("always sorts 'Recent Items' first", function()
      local recent = MockSection({title = "Recent Items"})
      local armor = MockSection({title = "Armor"})
      assert.is_true(sort.SortSectionsAlphabetically(const.BAG_KIND.BACKPACK, recent, armor))
      assert.is_false(sort.SortSectionsAlphabetically(const.BAG_KIND.BACKPACK, armor, recent))
    end)

    it("always sorts 'Free Space' last (before fill-width)", function()
      local freeSpace = MockSection({title = "Free Space"})
      local weapons = MockSection({title = "Weapons"})
      assert.is_false(sort.SortSectionsAlphabetically(const.BAG_KIND.BACKPACK, freeSpace, weapons))
      assert.is_true(sort.SortSectionsAlphabetically(const.BAG_KIND.BACKPACK, weapons, freeSpace))
    end)

    it("sorts fill-width sections to the very end", function()
      local fillWidth = MockSection({title = "ZZZ", fillWidth = true})
      local normal = MockSection({title = "Weapons"})
      assert.is_false(sort.SortSectionsAlphabetically(const.BAG_KIND.BACKPACK, fillWidth, normal))
      assert.is_true(sort.SortSectionsAlphabetically(const.BAG_KIND.BACKPACK, normal, fillWidth))
    end)

    it("handles 'Recent Items' before 'Free Space'", function()
      local recent = MockSection({title = "Recent Items"})
      local freeSpace = MockSection({title = "Free Space"})
      assert.is_true(sort.SortSectionsAlphabetically(const.BAG_KIND.BACKPACK, recent, freeSpace))
    end)

    it("returns false for nil sections instead of crashing", function()
      local section = MockSection({title = "Armor"})
      assert.is_false(sort.SortSectionsAlphabetically(const.BAG_KIND.BACKPACK, nil, section))
      assert.is_false(sort.SortSectionsAlphabetically(const.BAG_KIND.BACKPACK, section, nil))
      assert.is_false(sort.SortSectionsAlphabetically(const.BAG_KIND.BACKPACK, nil, nil))
    end)
  end)

  -- ─── Section Sort: Size Descending ────────────────────────────────────────

  describe("SortSectionsBySizeDescending", function()

    before_each(function()
      database.GetCustomSectionSort = function(_, _) return {} end
    end)

    it("sorts larger sections first", function()
      local big = MockSection({title = "A", cellCount = 20})
      local small = MockSection({title = "B", cellCount = 5})
      assert.is_true(sort.SortSectionsBySizeDescending(const.BAG_KIND.BACKPACK, big, small))
      assert.is_false(sort.SortSectionsBySizeDescending(const.BAG_KIND.BACKPACK, small, big))
    end)

    it("falls back to alphabetical when size is equal", function()
      local armor = MockSection({title = "Armor", cellCount = 10})
      local weapons = MockSection({title = "Weapons", cellCount = 10})
      assert.is_true(sort.SortSectionsBySizeDescending(const.BAG_KIND.BACKPACK, armor, weapons))
    end)

    it("respects 'Recent Items' priority", function()
      local recent = MockSection({title = "Recent Items", cellCount = 1})
      local big = MockSection({title = "Big", cellCount = 100})
      assert.is_true(sort.SortSectionsBySizeDescending(const.BAG_KIND.BACKPACK, recent, big))
    end)

    it("returns false for nil sections instead of crashing", function()
      local section = MockSection({title = "Armor", cellCount = 5})
      assert.is_false(sort.SortSectionsBySizeDescending(const.BAG_KIND.BACKPACK, nil, section))
      assert.is_false(sort.SortSectionsBySizeDescending(const.BAG_KIND.BACKPACK, section, nil))
    end)
  end)

  -- ─── Section Sort: Size Ascending ─────────────────────────────────────────

  describe("SortSectionsBySizeAscending", function()

    before_each(function()
      database.GetCustomSectionSort = function(_, _) return {} end
    end)

    it("sorts smaller sections first", function()
      local big = MockSection({title = "A", cellCount = 20})
      local small = MockSection({title = "B", cellCount = 5})
      assert.is_true(sort.SortSectionsBySizeAscending(const.BAG_KIND.BACKPACK, small, big))
      assert.is_false(sort.SortSectionsBySizeAscending(const.BAG_KIND.BACKPACK, big, small))
    end)

    it("falls back to alphabetical when size is equal", function()
      local armor = MockSection({title = "Armor", cellCount = 10})
      local weapons = MockSection({title = "Weapons", cellCount = 10})
      assert.is_true(sort.SortSectionsBySizeAscending(const.BAG_KIND.BACKPACK, armor, weapons))
    end)

    it("returns false for nil sections instead of crashing", function()
      local section = MockSection({title = "Armor", cellCount = 5})
      assert.is_false(sort.SortSectionsBySizeAscending(const.BAG_KIND.BACKPACK, nil, section))
      assert.is_false(sort.SortSectionsBySizeAscending(const.BAG_KIND.BACKPACK, section, nil))
    end)
  end)

  -- ─── Section Sort: Priority (Pinned) ──────────────────────────────────────

  describe("SortSectionsByPriority", function()

    it("sorts pinned sections before unpinned", function()
      database.GetCustomSectionSort = function(_, _)
        return { ["Favorites"] = 1 }
      end
      local pinned = MockSection({title = "Favorites"})
      local unpinned = MockSection({title = "Weapons"})
      local shouldSort, result = sort.SortSectionsByPriority(const.BAG_KIND.BACKPACK, pinned, unpinned)
      assert.is_true(shouldSort)
      assert.is_true(result)
    end)

    it("sorts among pinned sections by priority value", function()
      database.GetCustomSectionSort = function(_, _)
        return { ["First"] = 1, ["Second"] = 2 }
      end
      local first = MockSection({title = "First"})
      local second = MockSection({title = "Second"})
      local shouldSort, result = sort.SortSectionsByPriority(const.BAG_KIND.BACKPACK, first, second)
      assert.is_true(shouldSort)
      assert.is_true(result)
    end)

    it("returns false, false when neither section is pinned", function()
      database.GetCustomSectionSort = function(_, _) return {} end
      local a = MockSection({title = "A"})
      local b = MockSection({title = "B"})
      local shouldSort, result = sort.SortSectionsByPriority(const.BAG_KIND.BACKPACK, a, b)
      assert.is_false(shouldSort)
      assert.is_false(result)
    end)
  end)

  -- ─── GetSectionSortFunction ───────────────────────────────────────────────

  describe("GetSectionSortFunction", function()

    before_each(function()
      database.GetCustomSectionSort = function(_, _) return {} end
    end)

    it("returns alphabetical sort when configured", function()
      database.GetSectionSortType = function(_, _, _)
        return const.SECTION_SORT_TYPE.ALPHABETICALLY
      end
      local fn = sort:GetSectionSortFunction(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID)
      local armor = MockSection({title = "Armor"})
      local weapons = MockSection({title = "Weapons"})
      assert.is_true(fn(armor, weapons))
    end)

    it("returns size-descending sort when configured", function()
      database.GetSectionSortType = function(_, _, _)
        return const.SECTION_SORT_TYPE.SIZE_DESCENDING
      end
      local fn = sort:GetSectionSortFunction(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID)
      local big = MockSection({title = "A", cellCount = 20})
      local small = MockSection({title = "B", cellCount = 5})
      assert.is_true(fn(big, small))
    end)

    it("returns size-ascending sort when configured", function()
      database.GetSectionSortType = function(_, _, _)
        return const.SECTION_SORT_TYPE.SIZE_ASCENDING
      end
      local fn = sort:GetSectionSortFunction(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID)
      local big = MockSection({title = "A", cellCount = 20})
      local small = MockSection({title = "B", cellCount = 5})
      assert.is_true(fn(small, big))
    end)

    it("defaults to alphabetical for unknown sort type", function()
      database.GetSectionSortType = function(_, _, _) return 999 end
      local fn = sort:GetSectionSortFunction(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID)
      local armor = MockSection({title = "Armor"})
      local weapons = MockSection({title = "Weapons"})
      assert.is_true(fn(armor, weapons))
    end)
  end)

  -- ─── Slot order (Show Bags) ───────────────────────────────────────────────

  describe("slot order", function()

    it("SortItemDataBySlot sorts by bagid and then slotid", function()
      local slot1_1 = MockItemData({bagid = 1, slotid = 1})
      local slot1_5 = MockItemData({bagid = 1, slotid = 5})
      local slot2_1 = MockItemData({bagid = 2, slotid = 1})

      assert.is_true(sort.SortItemDataBySlot(slot1_1, slot1_5))
      assert.is_false(sort.SortItemDataBySlot(slot1_5, slot1_1))
      assert.is_true(sort.SortItemDataBySlot(slot1_5, slot2_1))
      assert.is_false(sort.SortItemDataBySlot(slot2_1, slot1_5))
    end)

    -- The keyring's bag ID is below the backpack's (-2 on Classic Era, -1 on WoW: Forever), which put it
    -- first in Show Bags; it is numbered after the last bag (items:GetBagName). Asked: "keyring should go
    -- last here in terms of sort".
    describe("the backpack's keyring", function()
      local savedBags, savedKeyring

      before_each(function()
        savedBags, savedKeyring = const.BACKPACK_BAGS, Enum.BagIndex.Keyring
      end)

      after_each(function()
        const.BACKPACK_BAGS, Enum.BagIndex.Keyring = savedBags, savedKeyring
      end)

      for _, client in ipairs({ { name = "Classic Era", keyring = -2, last = 4 }, { name = "WoW: Forever", keyring = -1, last = 5 } }) do
        it("comes after every bag on " .. client.name, function()
          Enum.BagIndex.Keyring = client.keyring
          const.BACKPACK_BAGS = { [client.keyring] = client.keyring }
          for bag = 0, client.last do const.BACKPACK_BAGS[bag] = bag end
          local key = MockItemData({bagid = client.keyring, slotid = 1})
          for bag = 0, client.last do
            local other = MockItemData({bagid = bag, slotid = 30})
            assert.is_true(sort.SortItemDataBySlot(other, key), "bag " .. bag)
            assert.is_false(sort.SortItemDataBySlot(key, other), "bag " .. bag)
          end
          local nextKey = MockItemData({bagid = client.keyring, slotid = 2})
          assert.is_true(sort.SortItemDataBySlot(key, nextKey), "its own slots in order")
          assert.is_false(sort.SortItemDataBySlot(nextKey, key))
        end)
      end

      -- Classic Era's bank is -1, its keyring -2: the bank keeps its place before its bank bags.
      it("leaves the Classic Era bank first", function()
        Enum.BagIndex.Keyring = -2
        const.BACKPACK_BAGS = { [-2] = -2, [0] = 0, [1] = 1, [2] = 2, [3] = 3, [4] = 4 }
        local bank = MockItemData({bagid = -1, slotid = 1})
        local bankBag = MockItemData({bagid = 5, slotid = 1})
        assert.is_true(sort.SortItemDataBySlot(bank, bankBag))
        assert.is_false(sort.SortItemDataBySlot(bankBag, bank))
      end)

      -- Live retail's enum has a Keyring member (-1) and no keyring: the backpack does not read it.
      it("leaves the enum's keyring ID alone where the backpack reads no keyring", function()
        Enum.BagIndex.Keyring = -1
        const.BACKPACK_BAGS = { [0] = 0, [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5 }
        local other = MockItemData({bagid = -1, slotid = 1})
        local bag = MockItemData({bagid = 0, slotid = 1})
        assert.is_true(sort.SortItemDataBySlot(other, bag))
        assert.is_false(sort.SortItemDataBySlot(bag, other))
      end)
    end)

    it("SortItemDataBySlot handles equal slots", function()
      local slot1 = MockItemData({bagid = 1, slotid = 1})
      local slot2 = MockItemData({bagid = 1, slotid = 1})
      assert.is_false(sort.SortItemDataBySlot(slot1, slot2))
    end)
  end)

  -- ─── Category Data Sort Functions ─────────────────────────────────────────

  describe("Category Data Sort Functions", function()
    before_each(function()
      database.GetCustomSectionSort = function(_, _) return {} end
    end)

    it("SortCategoryDataAlphabetically sorts alphabetically", function()
      local armor = { name = "Armor", count = 5, fillWidth = false }
      local weapons = { name = "Weapons", count = 10, fillWidth = false }
      assert.is_true(sort.SortCategoryDataAlphabetically(const.BAG_KIND.BACKPACK, armor, weapons))
      assert.is_false(sort.SortCategoryDataAlphabetically(const.BAG_KIND.BACKPACK, weapons, armor))
    end)

    it("SortCategoryDataAlphabetically respects priority pins", function()
      database.GetCustomSectionSort = function(_, _) return { ["Weapons"] = 1 } end
      local armor = { name = "Armor", count = 5, fillWidth = false }
      local weapons = { name = "Weapons", count = 10, fillWidth = false }
      assert.is_true(sort.SortCategoryDataAlphabetically(const.BAG_KIND.BACKPACK, weapons, armor))
    end)

    it("SortCategoryDataAlphabetically puts Recent Items first and Free Space last", function()
      local recent = { name = L:G("Recent Items"), count = 1, fillWidth = false }
      local free = { name = L:G("Free Space"), count = 1, fillWidth = false }
      local armor = { name = "Armor", count = 5, fillWidth = false }

      assert.is_true(sort.SortCategoryDataAlphabetically(const.BAG_KIND.BACKPACK, recent, armor))
      assert.is_true(sort.SortCategoryDataAlphabetically(const.BAG_KIND.BACKPACK, armor, free))
    end)

    it("SortCategoryDataBySizeDescending sorts by size descending", function()
      local big = { name = "Armor", count = 20, fillWidth = false }
      local small = { name = "Weapons", count = 5, fillWidth = false }
      assert.is_true(sort.SortCategoryDataBySizeDescending(const.BAG_KIND.BACKPACK, big, small))
      assert.is_false(sort.SortCategoryDataBySizeDescending(const.BAG_KIND.BACKPACK, small, big))
    end)

    it("SortCategoryDataBySizeAscending sorts by size ascending", function()
      local big = { name = "Armor", count = 20, fillWidth = false }
      local small = { name = "Weapons", count = 5, fillWidth = false }
      assert.is_true(sort.SortCategoryDataBySizeAscending(const.BAG_KIND.BACKPACK, small, big))
      assert.is_false(sort.SortCategoryDataBySizeAscending(const.BAG_KIND.BACKPACK, big, small))
    end)

    it("GetCategoryDataSortFunction returns correct functions", function()
      database.GetSectionSortType = function(_, _, _)
        return const.SECTION_SORT_TYPE.SIZE_DESCENDING
      end
      local fn = sort:GetCategoryDataSortFunction(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID)
      local big = { name = "A", count = 20, fillWidth = false }
      local small = { name = "B", count = 5, fillWidth = false }
      assert.is_true(fn(big, small))
    end)
  end)
end)
