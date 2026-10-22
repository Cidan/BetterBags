-- search_spec.lua -- Unit tests for data/search.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Dependencies: QueryParser and Trees are already loaded by other specs.
-- Load them explicitly for safety (idempotent).
LoadBetterBagsModule("util/query.lua")
LoadBetterBagsModule("util/trees/trees.lua")
LoadBetterBagsModule("util/trees/intervaltree.lua")

-- Ensure clean stubs and reload Search to prevent test pollution
ResetModuleStub("Constants")
ResetModuleStub("Items")
ResetModuleStub("Search", "data/search.lua")

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

-- Stub Items: a negation covers the indexed items (search:Universe), never the bags' committed
-- items, so this stub has none.
local items = StubBetterBagsModule("Items")
items.GetAllSlotInfo = function() return {} end

LoadBetterBagsModule("data/search.lua")
local search = addon:GetModule("Search")

-- Use shared mock factory
local MockSearchItem = MockData.ItemData

describe("Search", function()

  before_each(function()
    search:Init()
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

  -- A NOT or a != matches every indexed item the negated part does not: on its own, inside an OR,
  -- around a group. Before, a negation only marked what it excluded, and only an AND (or a bare
  -- `field != value`) used that, so `NOT rarity = poor` on its own matched nothing
  -- (docs/vendor-compat.md, "The query engine today").
  describe("Negation", function()
    local items4

    before_each(function()
      items4 = {
        sword = MockSearchItem({slotkey = "sword", name = "Thunderfury", quality = 4, itemLevel = 300}),
        shield = MockSearchItem({slotkey = "shield", name = "Bulwark", quality = 3, itemLevel = 200}),
        potion = MockSearchItem({slotkey = "potion", name = "Healing Potion", quality = 1, itemLevel = 50}),
        junk = MockSearchItem({slotkey = "junk", name = "Broken Tooth", quality = 0, itemLevel = 1}),
      }
      for _, item in pairs(items4) do search:Add(item) end
    end)

    local function keys(...)
      local set = {}
      for _, k in ipairs({...}) do set[k] = true end
      return set
    end

    it("matches every item a NOT excludes, on its own", function()
      assert.are.same(keys("sword", "shield", "junk"), search:Search("NOT rarity = 1"))
      assert.are.same(keys("sword", "shield", "potion"), search:Search("not rarity = poor"))
    end)

    it("matches every other item for !=, with nothing else in the results", function()
      assert.are.same(keys("sword", "shield", "junk"), search:Search("rarity != 1"))
      assert.are.same(keys("sword", "shield", "potion"), search:Search("rarity != poor"))
    end)

    it("keeps a negation's matches through an OR", function()
      assert.are.same(keys("sword", "shield", "junk"), search:Search("NOT rarity = 1 OR level > 250"))
      assert.are.same(keys("potion", "junk"), search:Search("rarity = 1 OR NOT level > 100"))
      assert.are.same(keys("sword", "shield", "potion", "junk"), search:Search("rarity != 4 OR name = thunderfury"))
    end)

    it("negates a group, and cancels a double NOT", function()
      assert.are.same(keys("potion", "junk"), search:Search("NOT (rarity = 4 OR rarity = 3)"))
      assert.are.same(keys("sword"), search:Search("NOT NOT rarity = 4"))
    end)

    it("combines negations with AND", function()
      assert.are.same(keys("shield", "potion"), search:Search("NOT rarity = 4 AND NOT rarity = 0"))
      assert.are.same(keys("shield"), search:Search("level > 100 AND rarity != 4"))
      assert.are.same(keys("shield"), search:Search("NOT rarity = 4 AND level > 100"))
      assert.are.same(keys("shield"), search:Search("level > 100 AND NOT rarity = 4"))
      assert.are.same(keys("junk"), search:Search("NOT (rarity = 4 OR rarity = 3) AND NOT potion"))
    end)

    -- Measured offline: `A AND NOT B` over 1,500 items took 0.18 ms through the complement and
    -- 0.06 ms as A minus B (docs/vendor-compat.md).
    it("takes an AND with a NOT as one side minus the other, never every indexed item", function()
      local original = search.Complement
      local calls = 0
      search.Complement = function(self, set)
        calls = calls + 1
        return original(self, set)
      end
      local ok, err = pcall(function()
        assert.are.same(keys("shield"), search:Search("level > 100 AND NOT rarity = 4"))
        assert.are.same(keys("shield"), search:Search("NOT rarity = 4 AND level > 100"))
      end)
      search.Complement = original
      assert(ok, err)
      assert.are.equal(0, calls)
    end)

    it("negates a word searched in every field", function()
      assert.are.same(keys("sword", "shield", "junk"), search:Search("NOT potion"))
    end)

    -- The items a negation covers are the ones indexed now. Before, a bare != read the bags'
    -- committed items, which, while a sweep runs, are the previous sweep's: an item that arrived in
    -- the sweep did not match until the next one.
    it("covers every indexed item, and only those, whatever the bags have committed", function()
      local looted = MockSearchItem({slotkey = "looted", name = "Fresh Loot", quality = 2, itemLevel = 10})
      search:Add(looted)
      assert.are.same(keys("sword", "shield", "looted", "junk"), search:Search("rarity != 1"))
      search:Remove(items4.junk)
      assert.are.same(keys("sword", "shield", "looted"), search:Search("NOT rarity = 1"))
    end)

    it("answers a negation for one item (Find)", function()
      assert.is_true(search:Find("NOT rarity = 4", items4.potion))
      assert.is_false(search:Find("NOT rarity = 4", items4.sword))
      assert.is_true(search:Find("rarity != 4", items4.junk))
    end)

    it("returns the other items from isNotInIndex, as a plain set", function()
      assert.are.same(keys("shield", "potion", "junk"), search:isNotInIndex("rarity", 4))
    end)

    it("matches nothing, without failing, for a NOT right after a word", function()
      assert.are.same({}, search:Search("thunderfury NOT bulwark"))
      assert.are.same({}, search:Search("level > 1 AND thunderfury NOT bulwark"))
    end)

    it("matches nothing for != on a field that does not exist, as for =", function()
      assert.are.same({}, search:Search("nosuchfield != 1"))
      assert.are.same({}, search:Search("nosuchfield = 1"))
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
      assert.are.same({ sword = true, shield = true }, results)
    end)

    it("supports NOT combined with AND", function()
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

  -- ─── Clean-Sweep Rebuilding ────────────────────────────────────────────────

  describe("Clean-Sweep Rebuilding (IndexItems)", function()
    it("wipes previous index and builds a completely fresh index from a flat items collection", function()
      -- Initial load
      local item1 = MockSearchItem({slotkey = "s1", name = "Thunderfury", itemLevel = 300})
      local item2 = MockSearchItem({slotkey = "s2", name = "Bulwark of Azzinoth", itemLevel = 200})

      search:IndexItems({s1 = item1, s2 = item2})

      -- Verify they are indexed
      assert.is_true(search:isInIndex("name", "thunder")["s1"] or false)
      assert.is_true(search:isInIndex("name", "bulwark")["s2"] or false)
      assert.is_true(search:isInIndex("level", 300)["s1"] or false)
      assert.is_true(search:isInIndex("level", 200)["s2"] or false)

      -- Now do a clean sweep with a new list of items that does not have thunderfury, but has a potion
      local item3 = MockSearchItem({slotkey = "s3", name = "Healing Potion", itemLevel = 50})

      search:IndexItems({s3 = item3})

      -- Verify s1 and s2 are completely gone, and s3 is the only one left
      assert.is_nil(search:isInIndex("name", "thunder")["s1"])
      assert.is_nil(search:isInIndex("name", "bulwark")["s2"])
      assert.is_nil(search:isInIndex("level", 300)["s1"])
      assert.is_nil(search:isInIndex("level", 200)["s2"])

      assert.is_true(search:isInIndex("name", "healing")["s3"] or false)
      assert.is_true(search:isInIndex("level", 50)["s3"] or false)
    end)
  end)

  describe("Basic Index Matching (isInIndex & isFullTextMatch)", function()
    it("matches basic string and boolean conditions", function()
      local item = MockSearchItem({slotkey = "s1", name = "Lesser Healing Potion", isReagent = true})
      search:IndexItems({s1 = item})

      assert.is_true(search:isInIndex("name", "lesser")["s1"] or false)
      assert.is_true(search:isInIndex("reagent", "true")["s1"] or false)
      assert.is_true(search:isFullTextMatch("name", "healing")["s1"] or false)
    end)
  end)

  -- ─── Tooltip index: full text only, substring semantics ────────────────────
  -- Tooltip text is hundreds of characters long; storing every prefix of it is
  -- quadratic per item and was the dominant cost of every sweep. The tooltip index
  -- keeps only the full text, and `tooltip =` / `tooltip !=` match substrings.

  describe("Tooltip index (full text only)", function()

    local function potion()
      return MockSearchItem({
        slotkey = "potion", name = "Healing Potion",
        tooltipText = "Healing Potion Use: Restores 70 to 90 health. Sell Price: 1",
      })
    end

    local function sword()
      return MockSearchItem({
        slotkey = "sword", name = "Thunderfury",
        tooltipText = "Thunderfury, Blessed Blade of the Windseeker Chance on hit",
      })
    end

    it("stores no prefix ngrams for tooltip text", function()
      search:IndexItems({potion = potion(), sword = sword()})
      local index = search:GetIndex("tooltip")
      assert.is_nil(next(index.ngrams))
      assert.is_true(index.fullText["healing potion use: restores 70 to 90 health. sell price: 1"]["potion"])
    end)

    it("still stores prefix ngrams for short string fields", function()
      search:IndexItems({potion = potion()})
      assert.is_true(search:isInIndex("name", "heal")["potion"] or false)
    end)

    it("matches `tooltip = x` as a substring anywhere in the tooltip", function()
      search:IndexItems({potion = potion(), sword = sword()})
      local results = search:Search("tooltip = health")
      assert.is_true(results["potion"] or false)
      assert.is_nil(results["sword"])
    end)

    it("treats a numeric `tooltip = x` value as text, not a number lookup", function()
      search:IndexItems({potion = potion(), sword = sword()})
      local results = search:isInIndex("tooltip", 70)
      assert.is_true(results["potion"] or false)
      assert.is_nil(results["sword"])
    end)

    it("excludes items whose tooltip contains x for `tooltip != x`", function()
      search:IndexItems({potion = potion(), sword = sword()})
      local results = search:isNotInIndex("tooltip", "health")
      assert.are.same({ sword = true }, results)
      assert.are.same({ sword = true }, search:Search("tooltip != health"))

      local combined = search:Search("name %= u AND tooltip != health")
      assert.is_true(combined["sword"] or false)
      assert.is_nil(combined["potion"])
    end)

    it("keeps plain searches matching words inside the tooltip", function()
      search:IndexItems({potion = potion(), sword = sword()})
      local results = search:Search("health")
      assert.is_true(results["potion"] or false)
      assert.is_nil(results["sword"])
    end)
  end)
end)

-- The index is kept up to date incrementally: each sweep re-indexes only the items whose
-- indexed values changed, removing an item with the values it was indexed with. The result
-- must always equal a clean rebuild (search:IndexItems) over the same items
-- (docs/roadmap.md, "Incremental search indexing").
describe("Search incremental indexing (SyncKind)", function()
  local BACKPACK, BANK = 0, 1

  local function item(opts)
    return MockSearchItem(opts)
  end

  local function sortedKeys(set)
    local keys = {}
    for k in pairs(set) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    return table.concat(keys, ",")
  end

  local function normalizeSets(sets)
    local out = {}
    for value, slots in pairs(sets) do
      out[tostring(value)] = sortedKeys(slots)
    end
    return out
  end

  -- checkTree asserts every node's min/max covers exactly its subtree (range queries prune
  -- on them) and collects value -> slotkeys.
  local function checkTree(node, out)
    if not node then return nil, nil end
    local lo, hi = node.value, node.value
    local lmin, lmax = checkTree(node.left, out)
    local rmin, rmax = checkTree(node.right, out)
    if lmin and lmin < lo then lo = lmin end
    if rmin and rmin < lo then lo = rmin end
    if lmax and lmax > hi then hi = lmax end
    if rmax and rmax > hi then hi = rmax end
    assert.are.equal(lo, node.min, "interval tree min")
    assert.are.equal(hi, node.max, "interval tree max")
    assert.is_not_nil(next(node.data), "interval tree node with no slots")
    out[tostring(node.value)] = sortedKeys(node.data)
    return lo, hi
  end

  local function indexState()
    local out = {}
    for name, index in pairs(search.indicies) do
      local numbers = {}
      checkTree(index.numbers.root, numbers)
      out[name] = {
        ngrams = normalizeSets(index.ngrams),
        fullText = normalizeSets(index.fullText),
        bools = normalizeSets(index.bools),
        numbers = numbers,
      }
    end
    return out
  end

  -- cleanState is the index a clean rebuild over the given items produces. The live
  -- (incremental) index is set aside and restored, so drift can accumulate across steps.
  local function cleanState(itemsByKind)
    local saved = { search.indicies, search.indexLookup, search.indexed, search.indexedItems }
    search:Init()
    local all = {}
    for _, kindItems in pairs(itemsByKind) do
      for slotkey, it in pairs(kindItems) do all[slotkey] = it end
    end
    search:IndexItems(all)
    local state = indexState()
    search.indicies, search.indexLookup, search.indexed, search.indexedItems = saved[1], saved[2], saved[3], saved[4]
    return state
  end

  before_each(function()
    search:Init()
  end)

  it("indexes new items and leaves unchanged ones alone", function()
    local bag = {
      a = item({ slotkey = "a", name = "Sword", kind = BACKPACK }),
      b = item({ slotkey = "b", name = "Shield", kind = BACKPACK }),
    }
    search:SyncKind(BACKPACK, bag)
    local added = {}
    local add = search.Add
    search.Add = function(self, it)
      table.insert(added, it.slotkey)
      return add(self, it)
    end
    bag.c = item({ slotkey = "c", name = "Potion", kind = BACKPACK })
    search:SyncKind(BACKPACK, bag)
    search.Add = add
    assert.are.same({ "c" }, added)
    assert.is_true(search:isInIndex("name", "potion")["c"])
    assert.is_true(search:isInIndex("name", "sword")["a"])
  end)

  it("re-indexes an item changed in place, removing the values it was indexed with", function()
    local sword = item({ slotkey = "a", name = "Sword", category = "Weapons", count = 1, kind = BACKPACK })
    local bag = { a = sword }
    search:SyncKind(BACKPACK, bag)
    sword.itemInfo.category = "Junk"
    sword.itemInfo.currentItemCount = 4
    search:SyncKind(BACKPACK, bag)
    assert.is_nil(search:isInIndex("category", "weapons")["a"])
    assert.is_true(search:isInIndex("category", "junk")["a"])
    assert.is_nil(search:isInIndex("count", 1)["a"])
    assert.is_true(search:isInIndex("count", 4)["a"])
  end)

  -- With changed (data-loader.md §18), only the items named in it and the items that are other
  -- objects than their slot was indexed from are compared: the pipeline names every item whose
  -- indexed values it set again, so an unchanged object is not looked at.
  describe("with the items that changed", function()
    it("does not compare an item that is the object its slot was indexed from", function()
      local sword = item({ slotkey = "a", name = "Sword", count = 1, kind = BACKPACK })
      local bag = { a = sword }
      search:SyncKind(BACKPACK, bag)
      sword.itemInfo.currentItemCount = 4
      search:SyncKind(BACKPACK, bag, false, {})
      assert.is_true(search:isInIndex("count", 1)["a"], "not compared")
      search:SyncKind(BACKPACK, bag, false, { a = true })
      assert.is_true(search:isInIndex("count", 4)["a"], "named as changed")
    end)

    it("compares an item that is another object than its slot was indexed from", function()
      local bag = { a = item({ slotkey = "a", name = "Sword", count = 1, kind = BACKPACK }) }
      search:SyncKind(BACKPACK, bag)
      bag.a = item({ slotkey = "a", name = "Sword", count = 4, kind = BACKPACK })
      search:SyncKind(BACKPACK, bag, false, {})
      assert.is_true(search:isInIndex("count", 4)["a"])
    end)

    it("takes a new object with the values it was indexed with as indexed from then on", function()
      local bag = { a = item({ slotkey = "a", name = "Sword", count = 1, kind = BACKPACK }) }
      search:SyncKind(BACKPACK, bag)
      local same = item({ slotkey = "a", name = "Sword", count = 1, kind = BACKPACK })
      bag.a = same
      search:SyncKind(BACKPACK, bag, false, {})
      assert.are.equal(same, search.indexedItems.a)
    end)

    it("forgets the item of a slot it removes, and every item on a wipe", function()
      local bag = { a = item({ slotkey = "a", name = "Sword", kind = BACKPACK }), b = item({ slotkey = "b", name = "Shield", kind = BACKPACK }) }
      search:SyncKind(BACKPACK, bag)
      bag.a = nil
      search:SyncKind(BACKPACK, bag, false, {})
      assert.is_nil(search.indexedItems.a)
      assert.are.equal(bag.b, search.indexedItems.b)
      search:Wipe()
      assert.is_nil(next(search.indexedItems))
    end)
  end)

  it("removes an item that left the bag or whose slot is now empty", function()
    local bag = {
      a = item({ slotkey = "a", name = "Sword", kind = BACKPACK }),
      b = item({ slotkey = "b", name = "Shield", kind = BACKPACK }),
    }
    search:SyncKind(BACKPACK, bag)
    bag.a = nil
    bag.b = item({ slotkey = "b", isItemEmpty = true, kind = BACKPACK })
    search:SyncKind(BACKPACK, bag)
    assert.is_nil(next(search.indexed))
    assert.are.same(cleanState({}), indexState())
  end)

  it("never touches the other bag's items", function()
    search:SyncKind(BANK, { z = item({ slotkey = "z", name = "Banked", kind = BANK }) })
    search:SyncKind(BACKPACK, { a = item({ slotkey = "a", name = "Sword", kind = BACKPACK }) })
    search:SyncKind(BACKPACK, {})
    assert.is_true(search:isInIndex("name", "banked")["z"])
    assert.is_nil(search:isInIndex("name", "sword")["a"])
  end)

  it("re-adds every item of the bag on a rebuild", function()
    local bag = { a = item({ slotkey = "a", name = "Sword", kind = BACKPACK }) }
    search:SyncKind(BACKPACK, bag)
    local added = 0
    local add = search.Add
    search.Add = function(self, it)
      added = added + 1
      return add(self, it)
    end
    search:SyncKind(BACKPACK, bag, true)
    search.Add = add
    assert.are.equal(1, added)
    assert.are.same(cleanState({ bag }), indexState())
  end)

  it("keeps a category updated after indexing, so the next sync does not re-index it", function()
    local sword = item({ slotkey = "a", name = "Sword", category = "Weapons", kind = BACKPACK })
    local bag = { a = sword }
    search:SyncKind(BACKPACK, bag)
    sword.itemInfo.category = "Search Hits"
    search:UpdateCategoryIndex(sword, "Weapons")
    local added = 0
    local add = search.Add
    search.Add = function(self, it)
      added = added + 1
      return add(self, it)
    end
    search:SyncKind(BACKPACK, bag)
    search.Add = add
    assert.are.equal(0, added)
    assert.are.same(cleanState({ bag }), indexState())
  end)

  it("deletes a value's entry when its last slot is removed", function()
    local it = item({ slotkey = "a", name = "Sword", tooltipText = "Use: Restores health.", kind = BACKPACK })
    search:Add(it)
    search:Remove(it)
    for name, index in pairs(search.indicies) do
      assert.is_nil(next(index.ngrams), name .. " ngrams")
      assert.is_nil(next(index.fullText), name .. " fullText")
      assert.is_nil(next(index.bools), name .. " bools")
      assert.is_nil(index.numbers.root, name .. " numbers")
    end
  end)

  it("replaces, rather than adds to, an item added twice under the same slot", function()
    search:Add(item({ slotkey = "a", name = "Sword", kind = BACKPACK }))
    search:Add(item({ slotkey = "a", name = "Shield", kind = BACKPACK }))
    assert.is_nil(search:isInIndex("name", "sword")["a"])
    assert.is_true(search:isInIndex("name", "shield")["a"])
  end)

  -- Every value an item puts in the index, changed in place on the same ItemData object
  -- (as targeted sweeps and the harvest cache do), must re-index the item.
  describe("re-indexes an item when one indexed value changes in place", function()
    local changes = {
      { "name", function(it) it.itemInfo.itemName = "Shield" end },
      { "type", function(it) it.itemInfo.itemType = "Weapon" end },
      { "subtype", function(it) it.itemInfo.itemSubType = "Swords" end },
      { "category", function(it) it.itemInfo.category = "Junk" end },
      { "GUID", function(it) it.itemInfo.itemGUID = "guid-other" end },
      { "expansion", function(it) it.itemInfo.expacID = 9 end },
      { "equipment location", function(it) it.itemInfo.itemEquipLoc = "INVTYPE_HEAD" end },
      { "binding", function(it) it.bindingInfo.binding = 2 end },
      { "tooltip", function(it) it.itemInfo.tooltipText = "Use: Restores mana." end },
      { "item level", function(it) it.itemInfo.currentItemLevel = 500 end },
      { "quality", function(it) it.itemInfo.itemQuality = 4 end },
      { "item ID", function(it) it.itemInfo.itemID = 4242 end },
      { "count", function(it) it.itemInfo.currentItemCount = 9 end },
      { "class", function(it) it.itemInfo.classID = 2 end },
      { "subclass", function(it) it.itemInfo.subclassID = 7 end },
      { "bind type", function(it) it.itemInfo.bindType = 2 end },
      { "reagent flag", function(it) it.itemInfo.isCraftingReagent = true end },
      { "bound flag", function(it) it.itemInfo.isBound = true end },
      { "binding's bound flag", function(it) it.bindingInfo.bound = true end },
      { "quest item flag", function(it) it.questInfo.isQuestItem = true end },
      { "active quest flag", function(it) it.questInfo.isActive = true end },
      { "equipment sets", function(it) it.itemInfo.equipmentSets = { "Tank" } end },
      { "bonus IDs", function(it) it.itemLinkInfo.bonusIDs = { "6652" } end },
    }
    for _, change in ipairs(changes) do
      it(change[1], function()
        local savedHead = _G.INVTYPE_HEAD
        _G.INVTYPE_HEAD = "Head"
        local sword = item({ slotkey = "a", name = "Sword", kind = BACKPACK, tooltipText = "Use: Restores health." })
        local bag = { a = sword }
        search:SyncKind(BACKPACK, bag)
        change[2](sword)
        search:SyncKind(BACKPACK, bag)
        local expected = cleanState({ bag })
        local actual = indexState()
        _G.INVTYPE_HEAD = savedHead
        assert.are.same(expected, actual)
      end)
    end
  end)

  -- Acceptance gate (docs/roadmap.md): randomized adds, removes, moves, in-place changes,
  -- category updates after indexing and rebuilds across both bags, compared after every
  -- step with a clean rebuild over the same items.
  describe("matches a clean rebuild", function()
    local seed
    local function random(n)
      seed = (seed * 16807) % 2147483647
      return seed % n + 1
    end
    local function pick(list)
      return list[random(#list)]
    end

    local NAMES = { "Sword", "Swordfish", "Shield", "Potion", "Potion of Speed", "Tank Plate" }
    local CATEGORIES = { "Weapons", "Armor", "Consumables", "Recent Items", "Junk" }
    local TOOLTIPS = { "", "Use: Restores health.", "Equip: +5 Stamina", "Use: Restores mana." }
    local SETS = { "Tank", "Tanky", "Heal" }
    local EQUIP = { "INVTYPE_NON_EQUIP_IGNORE", "INVTYPE_HEAD", "INVTYPE_CHEST", "" }
    local guid = 0

    local function randomItem(kind, slot)
      guid = guid + 1
      local sets
      if random(3) == 1 then
        sets = {}
        for _ = 1, random(2) do sets[#sets + 1] = pick(SETS) end
      end
      local bonus = {}
      for _ = 1, random(3) - 1 do bonus[#bonus + 1] = tostring(pick({ 6652, 13440, 13578 })) end
      return item({
        slotkey = slot, bagid = kind * 10 + 1, slotid = tonumber(slot:match("_(%d+)$")), kind = kind,
        name = pick(NAMES), category = pick(CATEGORIES), count = random(20), itemLevel = random(5) * 100,
        quality = random(5) - 1, itemID = 1000 + random(6), expacID = pick({ 0, 1, 9, 5 }),
        equipLoc = pick(EQUIP), tooltipText = pick(TOOLTIPS), equipmentSets = sets, bonusIDs = bonus,
        isBound = random(2) == 1, isReagent = random(2) == 1, bound = random(2) == 1,
        bindingScope = random(3) - 1, isQuest = random(2) == 1, isActiveQuest = random(2) == 1,
        guid = "guid-" .. guid,
      })
    end

    local function mutate(it)
      local info = it.itemInfo
      local which = random(18)
      if which == 1 then info.category = pick(CATEGORIES)
      elseif which == 2 then info.currentItemCount = random(20)
      elseif which == 3 then info.tooltipText = pick(TOOLTIPS)
      elseif which == 4 then info.equipmentSets = random(2) == 1 and { pick(SETS), pick(SETS) } or nil
      elseif which == 5 then it.itemLinkInfo.bonusIDs = { tostring(pick({ 6652, 13440 })) }
      elseif which == 6 then it.questInfo.isActive = not it.questInfo.isActive
      elseif which == 7 then info.itemName = pick(NAMES)
      elseif which == 8 then it.bindingInfo.bound = not it.bindingInfo.bound
      elseif which == 9 then info.currentItemLevel = random(5) * 100
      elseif which == 10 then info.itemQuality = random(5) - 1
      elseif which == 11 then info.itemID = 1000 + random(6)
      elseif which == 12 then info.classID = random(4)
      elseif which == 13 then info.subclassID = random(4)
      elseif which == 14 then info.bindType = random(4) - 1
      elseif which == 15 then info.isBound = not info.isBound
      elseif which == 16 then info.isCraftingReagent = not info.isCraftingReagent
      elseif which == 17 then it.questInfo.isQuestItem = not it.questInfo.isQuestItem
      else it.bindingInfo.binding = random(3) - 1 end
    end

    local function step(bags, kind)
      local bag = bags[kind]
      local slots = {}
      for i = 1, 8 do slots[i] = kind .. "_" .. i end
      local op = random(6)
      local slot = pick(slots)
      if op == 1 then
        bag[slot] = randomItem(kind, slot)
      elseif op == 2 then
        bag[slot] = nil
      elseif op == 3 and bag[slot] and not bag[slot].isItemEmpty then
        mutate(bag[slot])
      elseif op == 4 then
        bag[slot] = item({ slotkey = slot, isItemEmpty = true, kind = kind })
      elseif op == 5 and bag[slot] and not bag[slot].isItemEmpty then
        -- A move: the same item (GUID) shows up in another slot as a new object.
        local dest = pick(slots)
        if dest ~= slot then
          local moved = randomItem(kind, dest)
          moved.itemInfo.itemGUID = bag[slot].itemInfo.itemGUID
          moved.itemInfo.itemName = bag[slot].itemInfo.itemName
          bag[dest] = moved
          bag[slot] = nil
        end
      end

      local otherKind = kind == BACKPACK and BANK or BACKPACK
      search:SyncKind(kind, bag, random(10) == 1)
      search:SyncKind(otherKind, bags[otherKind])

      -- Phase8 re-resolves categories after indexing and updates the category index.
      for _, it in pairs(bag) do
        if not it.isItemEmpty and random(5) == 1 then
          local old = it.itemInfo.category
          it.itemInfo.category = pick(CATEGORIES)
          if it.itemInfo.category ~= old then
            search:UpdateCategoryIndex(it, old)
          end
        end
      end
    end

    for _, startSeed in ipairs({ 1, 42, 1999, 31337, 271828 }) do
      it("over 150 random steps (seed " .. startSeed .. ")", function()
        seed = startSeed
        local bags = { [BACKPACK] = {}, [BANK] = {} }
        for n = 1, 150 do
          step(bags, random(2) == 1 and BACKPACK or BANK)
          assert.are.same(cleanState(bags), indexState(), "step " .. n)
        end
      end)
    end
  end)
end)
