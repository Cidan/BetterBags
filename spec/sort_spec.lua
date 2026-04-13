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
  ONE_BAG = 1,
  SECTION_GRID = 2,
  LIST = 3,
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
}

-- Localization: L:G(key) returns the key as-is (no translations loaded)
function L:G(key) return key end

-- Now load the Sort module
LoadBetterBagsModule("util/sort.lua")
local sort = addon:GetModule("Sort")

-- ─── Mock Factories ───────────────────────────────────────────────────────────

--- Create a mock Item for item sort tests.
---@param opts table {name, quality, count, guid, isFreeSlot, itemLevel, expacID}
local function MockItem(opts)
  local data = nil
  if not opts.isFreeSlot then
    data = {
      itemInfo = {
        itemName = opts.name or "Unknown",
        itemQuality = opts.quality or 1,
        currentItemCount = opts.count or 1,
        itemGUID = opts.guid or "guid-0",
        currentItemLevel = opts.itemLevel or 1,
        expacID = opts.expacID,
      },
      slotid = opts.slotid or 0,
      bagid = opts.bagid or 0,
    }
  end
  return {
    isFreeSlot = opts.isFreeSlot or false,
    GetItemData = function() return data end,
  }
end

--- Create a mock Section for section sort tests.
---@param opts table {title, fillWidth, cellCount}
local function MockSection(opts)
  return {
    title = { GetText = function() return opts.title or "" end },
    GetFillWidth = function() return opts.fillWidth or false end,
    GetCellCount = function() return opts.cellCount or 0 end,
  }
end

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
end)
