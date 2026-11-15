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

const.ITEM_SORT_TYPE = {
  ALPHABETICALLY_THEN_QUALITY = 1,
  QUALITY_THEN_ALPHABETICALLY = 2,
  ITEM_LEVEL = 3,
  EXPANSION = 4,
  SELL_PRICE_STACK = 5,
  SELL_PRICE_EACH = 6,
  UPGRADE_TRACK = 7,
}

-- Localization: L:G(key) returns the key as-is (no translations loaded)
function L:G(key) return key end

-- The vendor price of one item is the Items module's (items:SellPriceOf, spec/items_spec.lua); the sell
-- price tests give it the price each item is made with.
local itemsModule = StubBetterBagsModule("Items")

-- Now load the Sort module
ResetModuleStub("Sort", "util/sort.lua")
LoadBetterBagsModule("util/sort.lua")
local sort = addon:GetModule("Sort")

-- Use shared mock factories
local MockItem = MockData.Item
local MockSection = MockData.Section

-- ─── Tests ────────────────────────────────────────────────────────────────────

describe("Sort", function()

  -- ─── Item Sort: Quality Then Alpha ────────────────────────────────────────

  describe("SortItemsByQualityThenAlpha", function()

    it("sorts higher quality before lower quality", function()
      local epic = MockItem({name = "Sword", quality = 4, guid = "a"})
      local common = MockItem({name = "Sword", quality = 1, guid = "b"})
      assert.is_true(sort.SortItemsByQualityThenAlpha(epic, common))
      assert.is_false(sort.SortItemsByQualityThenAlpha(common, epic))
    end)

    it("sorts alphabetically when quality is equal", function()
      local axe = MockItem({name = "Axe", quality = 3, guid = "a"})
      local sword = MockItem({name = "Sword", quality = 3, guid = "b"})
      assert.is_true(sort.SortItemsByQualityThenAlpha(axe, sword))
      assert.is_false(sort.SortItemsByQualityThenAlpha(sword, axe))
    end)

    it("sorts higher count first when name and quality match", function()
      local stack20 = MockItem({name = "Potion", quality = 1, count = 20, guid = "a"})
      local stack5 = MockItem({name = "Potion", quality = 1, count = 5, guid = "b"})
      assert.is_true(sort.SortItemsByQualityThenAlpha(stack20, stack5))
      assert.is_false(sort.SortItemsByQualityThenAlpha(stack5, stack20))
    end)

    it("falls back to GUID for stable sort", function()
      local a = MockItem({name = "Potion", quality = 1, count = 1, guid = "aaa"})
      local b = MockItem({name = "Potion", quality = 1, count = 1, guid = "zzz"})
      assert.is_true(sort.SortItemsByQualityThenAlpha(a, b))
      assert.is_false(sort.SortItemsByQualityThenAlpha(b, a))
    end)

    it("always sorts free slots to the end", function()
      local item = MockItem({name = "Sword", quality = 4, guid = "a"})
      local freeSlot = MockItem({isFreeSlot = true})
      assert.is_false(sort.SortItemsByQualityThenAlpha(freeSlot, item))
      assert.is_true(sort.SortItemsByQualityThenAlpha(item, freeSlot))
    end)

    it("returns false for two free slots", function()
      local a = MockItem({isFreeSlot = true})
      local b = MockItem({isFreeSlot = true})
      assert.is_false(sort.SortItemsByQualityThenAlpha(a, b))
    end)

    it("returns false when item data is invalid (nil data)", function()
      local good = MockItem({name = "Sword", quality = 4, guid = "a"})
      local bad = { isFreeSlot = false, GetItemData = function() return nil end }
      assert.is_false(sort.SortItemsByQualityThenAlpha(good, bad))
      assert.is_false(sort.SortItemsByQualityThenAlpha(bad, good))
    end)
  end)

  -- ─── Item Sort: Alpha Then Quality ────────────────────────────────────────

  describe("SortItemsByAlphaThenQuality", function()

    it("sorts alphabetically first", function()
      local axe = MockItem({name = "Axe", quality = 1, guid = "a"})
      local sword = MockItem({name = "Sword", quality = 4, guid = "b"})
      assert.is_true(sort.SortItemsByAlphaThenQuality(axe, sword))
      assert.is_false(sort.SortItemsByAlphaThenQuality(sword, axe))
    end)

    it("sorts by quality when names match", function()
      local epic = MockItem({name = "Sword", quality = 4, guid = "a"})
      local common = MockItem({name = "Sword", quality = 1, guid = "b"})
      assert.is_true(sort.SortItemsByAlphaThenQuality(epic, common))
      assert.is_false(sort.SortItemsByAlphaThenQuality(common, epic))
    end)

    it("always sorts free slots to the end", function()
      local item = MockItem({name = "Axe", quality = 1, guid = "a"})
      local freeSlot = MockItem({isFreeSlot = true})
      assert.is_true(sort.SortItemsByAlphaThenQuality(item, freeSlot))
      assert.is_false(sort.SortItemsByAlphaThenQuality(freeSlot, item))
    end)
  end)

  -- ─── Item Sort: Item Level ────────────────────────────────────────────────

  describe("SortItemsByItemLevel", function()

    it("sorts higher item level first", function()
      local high = MockItem({name = "A", quality = 1, itemLevel = 300, guid = "a"})
      local low = MockItem({name = "B", quality = 1, itemLevel = 100, guid = "b"})
      assert.is_true(sort.SortItemsByItemLevel(high, low))
      assert.is_false(sort.SortItemsByItemLevel(low, high))
    end)

    it("falls back to alphabetical when item level matches", function()
      local axe = MockItem({name = "Axe", quality = 1, itemLevel = 200, guid = "a"})
      local sword = MockItem({name = "Sword", quality = 1, itemLevel = 200, guid = "b"})
      assert.is_true(sort.SortItemsByItemLevel(axe, sword))
      assert.is_false(sort.SortItemsByItemLevel(sword, axe))
    end)

    it("always sorts free slots to the end", function()
      local item = MockItem({name = "Sword", quality = 1, itemLevel = 300, guid = "a"})
      local freeSlot = MockItem({isFreeSlot = true})
      assert.is_true(sort.SortItemsByItemLevel(item, freeSlot))
      assert.is_false(sort.SortItemsByItemLevel(freeSlot, item))
    end)
  end)

  -- ─── Item Sort: Expansion ─────────────────────────────────────────────────

  describe("SortItemsByExpansion", function()

    it("sorts by expansion chronologically (lower first)", function()
      local classic = MockItem({name = "A", quality = 1, expacID = 0, guid = "a"})
      local wrath = MockItem({name = "B", quality = 1, expacID = 2, guid = "b"})
      assert.is_true(sort.SortItemsByExpansion(classic, wrath))
      assert.is_false(sort.SortItemsByExpansion(wrath, classic))
    end)

    it("falls back to alphabetical within the same expansion", function()
      local axe = MockItem({name = "Axe", quality = 1, expacID = 3, guid = "a"})
      local sword = MockItem({name = "Sword", quality = 1, expacID = 3, guid = "b"})
      assert.is_true(sort.SortItemsByExpansion(axe, sword))
      assert.is_false(sort.SortItemsByExpansion(sword, axe))
    end)

    it("defaults missing expacID to 0 (Classic)", function()
      local noExpac = MockItem({name = "A", quality = 1, guid = "a"}) -- expacID = nil
      local wrath = MockItem({name = "B", quality = 1, expacID = 2, guid = "b"})
      assert.is_true(sort.SortItemsByExpansion(noExpac, wrath))
    end)

    it("always sorts free slots to the end", function()
      local item = MockItem({name = "A", quality = 1, expacID = 0, guid = "a"})
      local freeSlot = MockItem({isFreeSlot = true})
      assert.is_true(sort.SortItemsByExpansion(item, freeSlot))
      assert.is_false(sort.SortItemsByExpansion(freeSlot, item))
    end)
  end)

  -- ─── Item Sort: Slot ID ───────────────────────────────────────────────────

  describe("GetItemSortBySlot", function()

    it("sorts by slot ID ascending", function()
      local slot1 = MockItem({name = "A", quality = 1, guid = "a", slotid = 1})
      local slot5 = MockItem({name = "B", quality = 1, guid = "b", slotid = 5})
      assert.is_true(sort.GetItemSortBySlot(slot1, slot5))
      assert.is_false(sort.GetItemSortBySlot(slot5, slot1))
    end)

    it("handles nil item data gracefully", function()
      local good = MockItem({name = "A", quality = 1, guid = "a", slotid = 1})
      local bad = { isFreeSlot = false, GetItemData = function() return nil end }
      assert.is_false(sort.GetItemSortBySlot(bad, good))
      assert.is_true(sort.GetItemSortBySlot(good, bad))
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

  -- ─── GetItemSortFunction ──────────────────────────────────────────────────

  describe("GetItemSortFunction", function()

    it("returns a no-op for UNDEFINED bag kind", function()
      local fn = sort:GetItemSortFunction(const.BAG_KIND.UNDEFINED, const.BAG_VIEW.SECTION_GRID)
      -- no-op always returns false
      local a = MockItem({name = "A", quality = 1, guid = "a"})
      local b = MockItem({name = "B", quality = 1, guid = "b"})
      assert.is_false(fn(a, b))
      assert.is_false(fn(b, a))
    end)

    it("returns quality-then-alpha sort when configured", function()
      database.GetItemSortType = function(_, _, _)
        return const.ITEM_SORT_TYPE.QUALITY_THEN_ALPHABETICALLY
      end
      local fn = sort:GetItemSortFunction(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID)
      local epic = MockItem({name = "Sword", quality = 4, guid = "a"})
      local common = MockItem({name = "Sword", quality = 1, guid = "b"})
      assert.is_true(fn(epic, common))
    end)

    it("returns alpha-then-quality sort when configured", function()
      database.GetItemSortType = function(_, _, _)
        return const.ITEM_SORT_TYPE.ALPHABETICALLY_THEN_QUALITY
      end
      local fn = sort:GetItemSortFunction(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID)
      local axe = MockItem({name = "Axe", quality = 1, guid = "a"})
      local sword = MockItem({name = "Sword", quality = 4, guid = "b"})
      assert.is_true(fn(axe, sword))
    end)

    it("returns item-level sort when configured", function()
      database.GetItemSortType = function(_, _, _)
        return const.ITEM_SORT_TYPE.ITEM_LEVEL
      end
      local fn = sort:GetItemSortFunction(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID)
      local high = MockItem({name = "A", quality = 1, itemLevel = 300, guid = "a"})
      local low = MockItem({name = "B", quality = 1, itemLevel = 100, guid = "b"})
      assert.is_true(fn(high, low))
    end)

    it("returns expansion sort when configured", function()
      database.GetItemSortType = function(_, _, _)
        return const.ITEM_SORT_TYPE.EXPANSION
      end
      local fn = sort:GetItemSortFunction(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID)
      local classic = MockItem({name = "A", quality = 1, expacID = 0, guid = "a"})
      local wrath = MockItem({name = "B", quality = 1, expacID = 2, guid = "b"})
      assert.is_true(fn(classic, wrath))
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

  -- ─── table.sort integration ───────────────────────────────────────────────

  describe("table.sort integration", function()

    it("correctly sorts a list of items by quality then alpha", function()
      local items = {
        MockItem({name = "Sword", quality = 1, guid = "c"}),
        MockItem({name = "Axe", quality = 4, guid = "a"}),
        MockItem({name = "Shield", quality = 4, guid = "b"}),
        MockItem({isFreeSlot = true}),
        MockItem({name = "Potion", quality = 1, guid = "d"}),
      }
      table.sort(items, sort.SortItemsByQualityThenAlpha)
      -- Epic items first (alphabetical), then common (alphabetical), then free slots
      assert.are.equal("Axe", items[1]:GetItemData().itemInfo.itemName)
      assert.are.equal("Shield", items[2]:GetItemData().itemInfo.itemName)
      assert.are.equal("Potion", items[3]:GetItemData().itemInfo.itemName)
      assert.are.equal("Sword", items[4]:GetItemData().itemInfo.itemName)
      assert.is_true(items[5].isFreeSlot)
    end)
  end)

  -- ─── Data Sort Functions ───────────────────────────────────────────────

  describe("Data Sort Functions", function()
    local MockItemData = MockData.ItemData

    it("SortItemDataByQualityThenAlpha sorts higher quality first", function()
      local epic = MockItemData({name = "Sword", quality = 4, guid = "a"})
      local common = MockItemData({name = "Sword", quality = 1, guid = "b"})
      assert.is_true(sort.SortItemDataByQualityThenAlpha(epic, common))
      assert.is_false(sort.SortItemDataByQualityThenAlpha(common, epic))
    end)

    it("SortItemDataByAlphaThenQuality sorts alpha first", function()
      local axe = MockItemData({name = "Axe", quality = 1, guid = "a"})
      local sword = MockItemData({name = "Sword", quality = 4, guid = "b"})
      assert.is_true(sort.SortItemDataByAlphaThenQuality(axe, sword))
      assert.is_false(sort.SortItemDataByAlphaThenQuality(sword, axe))
    end)

    it("SortItemDataByItemLevel sorts higher level first", function()
      local high = MockItemData({name = "A", quality = 1, itemLevel = 300, guid = "a"})
      local low = MockItemData({name = "B", quality = 1, itemLevel = 100, guid = "b"})
      assert.is_true(sort.SortItemDataByItemLevel(high, low))
      assert.is_false(sort.SortItemDataByItemLevel(low, high))
    end)

    it("SortItemDataByExpansion sorts chronologically", function()
      local classic = MockItemData({name = "A", quality = 1, expacID = 0, guid = "a"})
      local wrath = MockItemData({name = "B", quality = 1, expacID = 2, guid = "b"})
      assert.is_true(sort.SortItemDataByExpansion(classic, wrath))
      assert.is_false(sort.SortItemDataByExpansion(wrath, classic))
    end)

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

    it("GetItemDataSortFunction returns correct functions", function()
      database.GetItemSortType = function(_, _, _)
        return const.ITEM_SORT_TYPE.QUALITY_THEN_ALPHABETICALLY
      end
      local fn = sort:GetItemDataSortFunction(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID)
      assert.are.equal(sort.SortItemDataByQualityThenAlpha, fn)
    end)

    it("SortItemData functions always sort free slots and gaps to the end", function()
      local item = MockItemData({name = "Sword", quality = 4, guid = "a"})
      local freeSlot = { isFreeSlot = true, bagid = 0, slotid = 1 }
      local gapSlot = { isItemGap = true, bagid = 0, slotid = 2 }
      assert.is_false(sort.SortItemDataByQualityThenAlpha(freeSlot, item))
      assert.is_true(sort.SortItemDataByQualityThenAlpha(item, freeSlot))
      assert.is_false(sort.SortItemDataByQualityThenAlpha(gapSlot, item))
      assert.is_true(sort.SortItemDataByQualityThenAlpha(item, gapSlot))
    end)
  end)

  -- ─── Item Sort: Sell Price ────────────────────────────────────────────────
  -- Issue #1303: Sell Price (Stack) orders by what the stack the button shows sells for, Sell Price (Each)
  -- by what one sells for, highest first. The price is the one Auto Sell uses (items:SellPriceOf).

  describe("by sell price", function()
    local MockItemData = MockData.ItemData
    local savedPriceOf

    before_each(function()
      savedPriceOf = rawget(itemsModule, "SellPriceOf")
      itemsModule.SellPriceOf = function(_, data) return data.itemInfo.sellPrice end
    end)

    after_each(function()
      itemsModule.SellPriceOf = savedPriceOf
    end)

    it("Sell Price (Stack) puts the stack worth more first: its price times its count", function()
      local cloth = MockItemData({ name = "Cloth", sellPrice = 10, count = 20, guid = "a" })
      local ring = MockItemData({ name = "Ring", sellPrice = 150, count = 1, guid = "b" })
      assert.is_true(sort.SortItemDataBySellPriceStack(cloth, ring))
      assert.is_false(sort.SortItemDataBySellPriceStack(ring, cloth))
    end)

    it("Sell Price (Stack) counts what the button shows: a merged stack's total", function()
      local cloth = MockItemData({ name = "Cloth", sellPrice = 10, count = 5, stackedCount = 30, guid = "a" })
      local ring = MockItemData({ name = "Ring", sellPrice = 200, count = 1, guid = "b" })
      assert.is_true(sort.SortItemDataBySellPriceStack(cloth, ring))
      assert.is_false(sort.SortItemDataBySellPriceStack(ring, cloth))
    end)

    it("Sell Price (Each) puts the item worth more each first, whatever the count", function()
      local cloth = MockItemData({ name = "Cloth", sellPrice = 10, count = 20, stackedCount = 40, guid = "a" })
      local ring = MockItemData({ name = "Ring", sellPrice = 150, count = 1, guid = "b" })
      assert.is_true(sort.SortItemDataBySellPriceEach(ring, cloth))
      assert.is_false(sort.SortItemDataBySellPriceEach(cloth, ring))
    end)

    for _, case in ipairs({ { "Sell Price (Stack)", "SortItemDataBySellPriceStack" },
      { "Sell Price (Each)", "SortItemDataBySellPriceEach" } }) do
      local name, fn = case[1], case[2]

      it(name .. " puts what no vendor buys (0) after everything worth a copper", function()
        local unsellable = MockItemData({ name = "A Quest Item", sellPrice = 0, count = 1, guid = "a" })
        local junk = MockItemData({ name = "Z Junk", sellPrice = 1, count = 1, guid = "b" })
        assert.is_true(sort[fn](junk, unsellable))
        assert.is_false(sort[fn](unsellable, junk))
      end)

      it(name .. " falls back to the name, and last to the GUID", function()
        local apple = MockItemData({ name = "Apple", sellPrice = 5, count = 1, guid = "z" })
        local bread = MockItemData({ name = "Bread", sellPrice = 5, count = 1, guid = "a" })
        assert.is_true(sort[fn](apple, bread))
        assert.is_false(sort[fn](bread, apple))
        local first = MockItemData({ name = "Potion", sellPrice = 5, count = 1, guid = "aaa" })
        local second = MockItemData({ name = "Potion", sellPrice = 5, count = 1, guid = "zzz" })
        assert.is_true(sort[fn](first, second))
        assert.is_false(sort[fn](second, first))
      end)

      it(name .. " puts free slots and gaps last", function()
        local item = MockItemData({ name = "Sword", sellPrice = 0, guid = "a" })
        local freeSlot = { isFreeSlot = true, bagid = 0, slotid = 1 }
        local gapSlot = { isItemGap = true, bagid = 0, slotid = 2 }
        assert.is_true(sort[fn](item, freeSlot))
        assert.is_false(sort[fn](freeSlot, item))
        assert.is_true(sort[fn](item, gapSlot))
        assert.is_false(sort[fn](gapSlot, item))
      end)

      it(name .. " leaves an item without its data unordered", function()
        local good = MockItemData({ name = "Sword", sellPrice = 50, guid = "a" })
        local bad = MockItemData({ name = "Shield", sellPrice = 10, guid = "b" })
        bad.itemInfo.itemGUID = nil
        assert.is_false(sort[fn](good, bad))
        assert.is_false(sort[fn](bad, good))
      end)
    end

    it("Sell Price (Stack) breaks a tie of worth by the bigger pile", function()
      local few = MockItemData({ name = "Potion", sellPrice = 10, count = 2, guid = "a" })
      local many = MockItemData({ name = "Potion", sellPrice = 5, count = 4, guid = "b" })
      assert.is_true(sort.SortItemDataBySellPriceStack(many, few))
      assert.is_false(sort.SortItemDataBySellPriceStack(few, many))
    end)

    it("Sell Price (Each) breaks a tie of price by the bigger pile", function()
      local few = MockItemData({ name = "Potion", sellPrice = 5, count = 2, guid = "a" })
      local many = MockItemData({ name = "Potion", sellPrice = 5, count = 3, guid = "b" })
      assert.is_true(sort.SortItemDataBySellPriceEach(many, few))
      assert.is_false(sort.SortItemDataBySellPriceEach(few, many))
    end)

    it("takes each item's price from items:SellPriceOf", function()
      itemsModule.SellPriceOf = function(_, data) return data.itemInfo.itemName == "Cheap" and 1 or 100 end
      local cheap = MockItemData({ name = "Cheap", sellPrice = 900, guid = "a" })
      local dear = MockItemData({ name = "Dear", sellPrice = 1, guid = "b" })
      assert.is_true(sort.SortItemDataBySellPriceEach(dear, cheap))
      assert.is_true(sort.SortItemDataBySellPriceStack(dear, cheap))
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
      table.sort(list, sort.SortItemDataBySellPriceStack)
      local names = {}
      for i = 1, 5 do table.insert(names, list[i].itemInfo.itemName) end
      -- Cloth 200; Herb, Potion and Ring 150 each, by name; Quest Item 0.
      assert.are.same({ "Cloth", "Herb", "Potion", "Ring", "Quest Item" }, names)
      assert.is_true(list[6].isFreeSlot)
    end)

    it("orders item buttons the same way (SortItemsBySellPriceStack, SortItemsBySellPriceEach)", function()
      local cloth = MockItem({ name = "Cloth", sellPrice = 10, count = 20, guid = "a" })
      local ring = MockItem({ name = "Ring", sellPrice = 150, count = 1, guid = "b" })
      local freeSlot = MockItem({ isFreeSlot = true })
      local bad = { isFreeSlot = false, GetItemData = function() return nil end }
      assert.is_true(sort.SortItemsBySellPriceStack(cloth, ring))
      assert.is_false(sort.SortItemsBySellPriceStack(ring, cloth))
      assert.is_true(sort.SortItemsBySellPriceEach(ring, cloth))
      assert.is_false(sort.SortItemsBySellPriceEach(cloth, ring))
      for _, fn in ipairs({ sort.SortItemsBySellPriceStack, sort.SortItemsBySellPriceEach }) do
        assert.is_true(fn(cloth, freeSlot))
        assert.is_false(fn(freeSlot, cloth))
        assert.is_false(fn(cloth, bad))
        assert.is_false(fn(bad, cloth))
      end
    end)

    it("is what GetItemDataSortFunction and GetItemSortFunction give when chosen", function()
      local chosen
      database.GetItemSortType = function() return chosen end
      chosen = const.ITEM_SORT_TYPE.SELL_PRICE_STACK
      assert.are.equal(sort.SortItemDataBySellPriceStack,
        sort:GetItemDataSortFunction(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID))
      assert.are.equal(sort.SortItemsBySellPriceStack,
        sort:GetItemSortFunction(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID))
      chosen = const.ITEM_SORT_TYPE.SELL_PRICE_EACH
      assert.are.equal(sort.SortItemDataBySellPriceEach,
        sort:GetItemDataSortFunction(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID))
      assert.are.equal(sort.SortItemsBySellPriceEach,
        sort:GetItemSortFunction(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID))
    end)
  end)

  -- ─── Item Sort: Upgrade Track ─────────────────────────────────────────────
  -- Issue #769: gear by its upgrade track (Myth, Hero, Champion...) rather than its item level, which mixes
  -- the tracks (a Veteran 6/6 is above a Champion 1/6). A track is ranked by the item level it upgrades to
  -- (items:ReadItemTraits' upgradeMaxItemLevel): the track's name is in the game's language.

  describe("by upgrade track", function()
    local MockItemData = MockData.ItemData

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
      assert.is_true(sort.SortItemDataByUpgradeTrack(hero, champion))
      assert.is_false(sort.SortItemDataByUpgradeTrack(champion, hero))
    end)

    it("puts the higher item level first within a track", function()
      local low = gear("A Hero Ring", 305, "Hero", 1, 321)
      local high = gear("B Hero Ring", 311, "Hero", 3, 321)
      assert.is_true(sort.SortItemDataByUpgradeTrack(high, low))
      assert.is_false(sort.SortItemDataByUpgradeTrack(low, high))
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
      table.sort(list, sort.SortItemDataByUpgradeTrack)
      local names = {}
      for i = 1, 9 do table.insert(names, list[i].itemInfo.itemName) end
      assert.are.same({ "Myth Ring", "Hero Helm", "Champion Helm", "Champion Belt", "Veteran Helm", "Veteran Belt",
        "Adventurer Cloak", "Old Helm", "Potion" }, names)
      assert.is_true(list[10].isFreeSlot)
    end)

    it("puts an item on no track after every item on one, whatever its item level", function()
      local adventurer = gear("Adventurer Cloak", 266, "Adventurer", 1, 282)
      local old = untracked("Old Helm", 400, { equipment = true })
      assert.is_true(sort.SortItemDataByUpgradeTrack(adventurer, old))
      assert.is_false(sort.SortItemDataByUpgradeTrack(old, adventurer))
      -- Read cold: no traits yet, so no track either.
      local cold = MockItemData({ name = "Cold Helm", currentItemLevel = 500, guid = "cold" })
      assert.is_true(sort.SortItemDataByUpgradeTrack(adventurer, cold))
      assert.is_false(sort.SortItemDataByUpgradeTrack(cold, adventurer))
    end)

    it("orders the items on no track by item level, as Item Level does", function()
      local high = untracked("Old Helm", 400, { equipment = true })
      local low = untracked("Older Helm", 300, { equipment = true })
      assert.is_true(sort.SortItemDataByUpgradeTrack(high, low))
      assert.is_false(sort.SortItemDataByUpgradeTrack(low, high))
    end)

    it("falls back to the name, then the bigger pile, and last the GUID", function()
      local axe = gear("Axe", 305, "Hero", 1, 321)
      local sword = gear("Sword", 305, "Hero", 1, 321)
      assert.is_true(sort.SortItemDataByUpgradeTrack(axe, sword))
      assert.is_false(sort.SortItemDataByUpgradeTrack(sword, axe))
      local many = untracked("Potion", 1, { count = 20, guid = "z" })
      local few = untracked("Potion", 1, { count = 5, guid = "a" })
      assert.is_true(sort.SortItemDataByUpgradeTrack(many, few))
      assert.is_false(sort.SortItemDataByUpgradeTrack(few, many))
      local first = untracked("Potion", 1, { guid = "aaa" })
      local second = untracked("Potion", 1, { guid = "zzz" })
      assert.is_true(sort.SortItemDataByUpgradeTrack(first, second))
      assert.is_false(sort.SortItemDataByUpgradeTrack(second, first))
    end)

    -- A free slot as the harvest reads one (an empty name sorts first by name), and a gap as CloneAsGap makes it: a
    -- copy of the item that left, here one that would sort first.
    it("puts free slots and gaps last", function()
      local item = untracked("Potion", 1)
      local freeSlot = MockData.EmptySlot()
      freeSlot.isFreeSlot = true
      local gapSlot = gear("Myth Ring", 318, "Myth", 1, 334)
      gapSlot.isItemGap = true
      assert.is_true(sort.SortItemDataByUpgradeTrack(item, freeSlot))
      assert.is_false(sort.SortItemDataByUpgradeTrack(freeSlot, item))
      assert.is_true(sort.SortItemDataByUpgradeTrack(item, gapSlot))
      assert.is_false(sort.SortItemDataByUpgradeTrack(gapSlot, item))
    end)

    it("leaves an item without its data unordered", function()
      local good = gear("Myth Ring", 318, "Myth", 1, 334)
      local bad = gear("Hero Ring", 305, "Hero", 1, 321)
      bad.itemInfo.itemGUID = nil
      assert.is_false(sort.SortItemDataByUpgradeTrack(good, bad))
      assert.is_false(sort.SortItemDataByUpgradeTrack(bad, good))
    end)

    it("orders item buttons the same way (SortItemsByUpgradeTrack)", function()
      local traits = function(track, top)
        return { isEquipment = true, upgradeTrack = track, upgradeLevel = 1, upgradeMax = 6,
          upgradeMaxItemLevel = top, stats = {} }
      end
      local champion = MockItem({ name = "Champion Boots", currentItemLevel = 308, guid = "a",
        traits = traits("Champion", 308) })
      local hero = MockItem({ name = "Hero Boots", currentItemLevel = 305, guid = "b", traits = traits("Hero", 321) })
      local freeSlot = MockItem({ isFreeSlot = true })
      local bad = { isFreeSlot = false, GetItemData = function() return nil end }
      assert.is_true(sort.SortItemsByUpgradeTrack(hero, champion))
      assert.is_false(sort.SortItemsByUpgradeTrack(champion, hero))
      assert.is_true(sort.SortItemsByUpgradeTrack(hero, freeSlot))
      assert.is_false(sort.SortItemsByUpgradeTrack(freeSlot, hero))
      assert.is_false(sort.SortItemsByUpgradeTrack(hero, bad))
      assert.is_false(sort.SortItemsByUpgradeTrack(bad, hero))
    end)

    it("is what GetItemDataSortFunction and GetItemSortFunction give when chosen", function()
      database.GetItemSortType = function() return const.ITEM_SORT_TYPE.UPGRADE_TRACK end
      assert.are.equal(sort.SortItemDataByUpgradeTrack,
        sort:GetItemDataSortFunction(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID))
      assert.are.equal(sort.SortItemsByUpgradeTrack,
        sort:GetItemSortFunction(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID))
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
