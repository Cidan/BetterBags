-- search_spec.lua -- Unit tests for data/search.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Dependencies: QueryParser and Trees are already loaded by other specs.
-- Load them explicitly for safety (idempotent).
LoadBetterBagsModule("util/query.lua")
LoadBetterBagsModule("util/trees/trees.lua")
LoadBetterBagsModule("util/trees/intervaltree.lua")

-- Stub Debug (search uses debug:Log and debug:Inspect)
local debug = StubBetterBagsModule("Debug")
debug.Log = function() end
debug.Inspect = function() end

-- Set up Constants that search.lua references
local const = StubBetterBagsModule("Constants")
const.BRIEF_EXPANSION_MAP = {
  [0] = "classic",
  [1] = "bc",
  [2] = "wotlk",
  [3] = "cata",
  [9] = "tww",
}
const.BINDING_MAP = {
  [0] = "",
  [1] = "boe",
  [2] = "soulbound",
}
const.ITEM_QUALITY_TO_ENUM = {
  poor = 0,
  common = 1,
  uncommon = 2,
  rare = 3,
  epic = 4,
  legendary = 5,
}

-- Stub Items (search.EvaluateQuery JIT-loads Items for standalone != queries)
local items = StubBetterBagsModule("Items")
items.GetAllSlotInfo = function() return {} end

LoadBetterBagsModule("data/search.lua")
local search = addon:GetModule("Search")

-- Use shared mock factory
local MockSearchItem = MockData.ItemData

describe("Search", function()

  before_each(function()
    search:OnInitialize()
  end)

  -- ─── Index Basics ───────────────────────────────────────────────────────────

  describe("Index operations", function()

    it("adds an item to string indexes (ngram prefix matching)", function()
      local item = MockSearchItem({slotkey = "s1", name = "Thunderfury"})
      search:Add(item)
      local results = search:isInIndex("name", "thunder")
      assert.is_true(results["s1"] or false)
    end)

    it("is case-insensitive for string matching", function()
      local item = MockSearchItem({slotkey = "s1", name = "Thunderfury"})
      search:Add(item)
      assert.is_true(search:isInIndex("name", "THUNDER")["s1"] or false)
      assert.is_true(search:isInIndex("name", "thunderfury")["s1"] or false)
    end)

    it("adds an item to number indexes", function()
      local item = MockSearchItem({slotkey = "s1", itemLevel = 300})
      search:Add(item)
      local results = search:isInIndex("level", 300)
      assert.is_true(results["s1"] or false)
    end)

    it("adds an item to boolean indexes", function()
      local item = MockSearchItem({slotkey = "s1", isReagent = true})
      search:Add(item)
      local results = search:isInIndex("reagent", "true")
      assert.is_true(results["s1"] or false)
    end)

    it("removes an item from all indexes", function()
      local item = MockSearchItem({slotkey = "s1", name = "Sword", itemLevel = 100})
      search:Add(item)
      search:Remove(item)
      assert.is_nil(search:isInIndex("name", "sword")["s1"])
    end)

    it("ignores empty items on Add", function()
      local item = MockSearchItem({slotkey = "s1", name = "Ghost"})
      item.isItemEmpty = true
      search:Add(item)
      assert.same({}, search:isInIndex("name", "ghost"))
    end)
  end)

  -- ─── String Search ──────────────────────────────────────────────────────────

  describe("String search", function()

    it("matches prefix substrings via ngrams", function()
      search:Add(MockSearchItem({slotkey = "s1", name = "Thunderfury"}))
      search:Add(MockSearchItem({slotkey = "s2", name = "Thunder Strike"}))
      search:Add(MockSearchItem({slotkey = "s3", name = "Sword"}))
      local results = search:isInIndex("name", "thunder")
      assert.is_true(results["s1"] or false)
      assert.is_true(results["s2"] or false)
      assert.is_nil(results["s3"])
    end)

    it("returns empty for no match", function()
      search:Add(MockSearchItem({slotkey = "s1", name = "Sword"}))
      assert.same({}, search:isInIndex("name", "axe"))
    end)
  end)

  -- ─── Full Text Search ──────────────────────────────────────────────────────

  describe("Full text search", function()

    it("matches substrings within full text", function()
      search:Add(MockSearchItem({slotkey = "s1", name = "Thunderfury"}))
      search:Add(MockSearchItem({slotkey = "s2", name = "Sulfuras"}))
      local results = search:isFullTextMatch("name", "fury")
      assert.is_true(results["s1"] or false)
      assert.is_nil(results["s2"])
    end)
  end)

  -- ─── Number Comparisons ─────────────────────────────────────────────────────

  describe("Number comparisons", function()

    before_each(function()
      search:Add(MockSearchItem({slotkey = "low", name = "Low", itemLevel = 50}))
      search:Add(MockSearchItem({slotkey = "mid", name = "Mid", itemLevel = 200}))
      search:Add(MockSearchItem({slotkey = "high", name = "High", itemLevel = 450}))
    end)

    it("isGreater returns items above threshold", function()
      local results = search:isGreater("level", 200)
      assert.is_true(results["high"] or false)
      assert.is_nil(results["mid"])
      assert.is_nil(results["low"])
    end)

    it("isGreaterOrEqual includes the threshold", function()
      local results = search:isGreaterOrEqual("level", 200)
      assert.is_true(results["high"] or false)
      assert.is_true(results["mid"] or false)
      assert.is_nil(results["low"])
    end)

    it("isLess returns items below threshold", function()
      local results = search:isLess("level", 200)
      assert.is_true(results["low"] or false)
      assert.is_nil(results["mid"])
      assert.is_nil(results["high"])
    end)

    it("isLessOrEqual includes the threshold", function()
      local results = search:isLessOrEqual("level", 200)
      assert.is_true(results["low"] or false)
      assert.is_true(results["mid"] or false)
      assert.is_nil(results["high"])
    end)
  end)

  -- ─── Negation ───────────────────────────────────────────────────────────────

  describe("Negation (isNotInIndex)", function()

    it("returns negated results with ___NEGATED___ marker", function()
      search:Add(MockSearchItem({slotkey = "s1", name = "Sword", quality = 4}))
      search:Add(MockSearchItem({slotkey = "s2", name = "Shield", quality = 1}))
      local results = search:isNotInIndex("rarity", 4)
      assert.is_true(results["___NEGATED___"] or false)
      assert.are.equal(false, results["s1"])
    end)
  end)

  -- ─── Index Aliases ──────────────────────────────────────────────────────────

  describe("Index aliases", function()

    it("resolves 'ilvl' to the level index", function()
      search:Add(MockSearchItem({slotkey = "s1", itemLevel = 300}))
      local index = search:GetIndex("ilvl")
      assert.is_not_nil(index)
      assert.are.equal("level", index.property)
    end)

    it("resolves 'exp' to the expansion index", function()
      local index = search:GetIndex("exp")
      assert.is_not_nil(index)
      assert.are.equal("expansion", index.property)
    end)

    it("resolves 'count' to the stackcount index", function()
      local index = search:GetIndex("count")
      assert.is_not_nil(index)
      assert.are.equal("stackcount", index.property)
    end)

    it("returns nil for unknown indexes", function()
      assert.is_nil(search:GetIndex("nonexistent"))
    end)
  end)

  -- ─── Wipe ───────────────────────────────────────────────────────────────────

  describe("Wipe", function()

    it("clears all indexed data", function()
      search:Add(MockSearchItem({slotkey = "s1", name = "Sword", itemLevel = 100}))
      search:Wipe()
      assert.same({}, search:isInIndex("name", "sword"))
      assert.same({}, search:isInIndex("level", 100))
    end)
  end)

  -- ─── DefaultSearch ──────────────────────────────────────────────────────────

  describe("DefaultSearch", function()

    it("searches across all default indexes", function()
      search:Add(MockSearchItem({slotkey = "s1", name = "Sword", category = "Weapons"}))
      search:Add(MockSearchItem({slotkey = "s2", name = "Potion", category = "Consumables"}))
      -- "sword" should match via name
      local results = search:DefaultSearch("sword")
      assert.is_true(results["s1"] or false)
      assert.is_nil(results["s2"])
    end)

    it("matches across different default index fields", function()
      search:Add(MockSearchItem({slotkey = "s1", name = "Sword", category = "Weapons"}))
      -- "weapons" should match via category
      local results = search:DefaultSearch("weapons")
      assert.is_true(results["s1"] or false)
    end)
  end)

  -- ─── Query Evaluation (full pipeline) ───────────────────────────────────────

  describe("Search (query pipeline)", function()

    before_each(function()
      search:Add(MockSearchItem({
        slotkey = "sword", name = "Thunderfury", quality = 4, itemLevel = 300,
        itemType = "Weapon", category = "Weapons",
      }))
      search:Add(MockSearchItem({
        slotkey = "shield", name = "Bulwark", quality = 3, itemLevel = 200,
        itemType = "Armor", category = "Armor",
      }))
      search:Add(MockSearchItem({
        slotkey = "potion", name = "Healing Potion", quality = 1, itemLevel = 50,
        itemType = "Consumable", category = "Consumables", isReagent = true,
      }))
    end)

    it("finds items by simple term (default search)", function()
      local results = search:Search("thunderfury")
      assert.is_true(results["sword"] or false)
      assert.is_nil(results["shield"])
    end)

    it("finds items by field comparison", function()
      local results = search:Search("rarity = 4")
      assert.is_true(results["sword"] or false)
      assert.is_nil(results["shield"])
      assert.is_nil(results["potion"])
    end)

    it("supports >= comparison", function()
      local results = search:Search("level >= 200")
      assert.is_true(results["sword"] or false)
      assert.is_true(results["shield"] or false)
      assert.is_nil(results["potion"])
    end)

    it("supports AND queries", function()
      local results = search:Search("rarity >= 3 AND level >= 250")
      assert.is_true(results["sword"] or false)
      assert.is_nil(results["shield"])
      assert.is_nil(results["potion"])
    end)

    it("supports OR queries", function()
      local results = search:Search("name = thunderfury OR name = bulwark")
      assert.is_true(results["sword"] or false)
      assert.is_true(results["shield"] or false)
      assert.is_nil(results["potion"])
    end)

    it("supports != (not equal) queries", function()
      local results = search:Search("rarity != 1")
      -- != returns negated results: items with rarity=1 are excluded
      assert.is_nil(results["potion"])
    end)

    it("supports NOT combined with AND", function()
      -- Standalone NOT only marks exclusions; combine with AND to filter
      local results = search:Search("type %= weapon AND NOT rarity = 1")
      assert.is_true(results["sword"] or false)
      assert.is_nil(results["potion"])
    end)

    it("supports %= (full text match) queries", function()
      local results = search:Search("name %= fury")
      assert.is_true(results["sword"] or false)
      assert.is_nil(results["shield"])
    end)

    it("returns empty results for no matches", function()
      local results = search:Search("name = nonexistent")
      assert.same({}, results)
    end)

    it("returns empty results for invalid query (nil AST)", function()
      local results = search:Search(")")
      assert.same({}, results)
    end)
  end)

  -- ─── Find (single item check) ──────────────────────────────────────────────

  describe("Find", function()

    it("returns true when item matches query", function()
      local item = MockSearchItem({slotkey = "s1", name = "Sword", quality = 4})
      search:Add(item)
      assert.is_true(search:Find("rarity = 4", item))
    end)

    it("returns falsy when item does not match query", function()
      local item = MockSearchItem({slotkey = "s1", name = "Sword", quality = 1})
      search:Add(item)
      -- Find returns nil (not false) when item isn't in positive results
      -- because p[slotkey] is nil and `nil and x` evaluates to nil in Lua
      assert.is_falsy(search:Find("rarity = 4", item))
    end)
  end)

  -- ─── UpdateCategoryIndex ────────────────────────────────────────────────────

  describe("UpdateCategoryIndex", function()

    it("updates the category index for an item", function()
      local item = MockSearchItem({slotkey = "s1", name = "Sword", category = "OldCategory"})
      search:Add(item)
      assert.is_true(search:isInIndex("category", "oldcategory")["s1"] or false)

      item.itemInfo.category = "NewCategory"
      search:UpdateCategoryIndex(item, "OldCategory")
      assert.is_nil(search:isInIndex("category", "oldcategory")["s1"])
      assert.is_true(search:isInIndex("category", "newcategory")["s1"] or false)
    end)

    it("ignores empty items", function()
      local item = MockSearchItem({slotkey = "s1", category = "Test"})
      item.isItemEmpty = true
      search:UpdateCategoryIndex(item, "Old") -- should not error
    end)
  end)

  -- ─── StringToBoolean ───────────────────────────────────────────────────────

  describe("StringToBoolean", function()

    it("converts 'true' to true", function()
      assert.is_true(search:StringToBoolean("true"))
    end)

    it("converts 'false' to false", function()
      assert.is_false(search:StringToBoolean("false"))
    end)

    it("returns nil for other strings", function()
      assert.is_nil(search:StringToBoolean("yes"))
      assert.is_nil(search:StringToBoolean("1"))
    end)
  end)
end)
