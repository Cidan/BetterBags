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

  -- ─── Bag name ───────────────────────────────────────────────────────────────

  -- The bag holding an item, by its plain name (asked: docs/vendor-compat.md, "Decisions"). The field
  -- existed as `bagName` and was never filled, and could not have been found: field names are
  -- lower-cased before the lookup.
  describe("bag name", function()
    before_each(function()
      search:Add(MockSearchItem({ slotkey = "s1", name = "Sword", bagName = "Backpack" }))
      search:Add(MockSearchItem({ slotkey = "s2", name = "Peacebloom", bagName = "Herb Satchel" }))
    end)

    it("finds items by the plain name of their bag, as bagname or bag", function()
      assert.are.same({ s1 = true }, search:Search("bagname = backpack"))
      assert.are.same({ s1 = true }, search:Search("bagName = Back"), "as the field was always written")
      assert.are.same({ s2 = true }, search:Search("bag = herb"))
      assert.are.same({ s2 = true }, search:Search("bag %= satchel"))
      assert.are.same({ s2 = true }, search:Search("bag != backpack"))
    end)

    it("is not searched by a bare word", function()
      assert.are.same({}, search:Search("satchel"))
    end)
  end)

  -- ─── Crafting quality ───────────────────────────────────────────────────────

  -- quality is the crafting quality tier of reagents and crafted items; an item's quality in the
  -- Poor-to-Legendary sense is rarity (the player, docs/vendor-compat.md). The index existed and
  -- was never filled.
  describe("crafting quality", function()
    local function keys(...)
      local set = {}
      for _, k in ipairs({...}) do set[k] = true end
      return set
    end

    before_each(function()
      search:Add(MockSearchItem({ slotkey = "ore1", quality = 1, traits = { craftingQuality = 1 } }))
      search:Add(MockSearchItem({ slotkey = "ore2", quality = 1, traits = { craftingQuality = 2 } }))
      search:Add(MockSearchItem({ slotkey = "ring5", quality = 4, traits = { craftingQuality = 5 } }))
      search:Add(MockSearchItem({ slotkey = "sword", quality = 1 }))
    end)

    it("finds items by their crafting tier, never by their rarity", function()
      assert.are.same(keys("ore1"), search:Search("quality = 1"))
      assert.are.same(keys("ore2", "ring5"), search:Search("quality >= 2"))
      assert.are.same(keys("ring5"), search:Search("quality > 2 AND rarity = epic"))
      assert.are.same(keys("ore2", "ring5", "sword"), search:Search("quality != 1"))
      assert.are.same({}, search:Search("quality = epic"), "rarity names are rarity's")
    end)
  end)

  -- ─── Item traits ────────────────────────────────────────────────────────────

  -- The fields read from an item's link once its data has loaded (items:ReadItemTraits,
  -- docs/vendor-compat.md "Proposed: new fields"). An item read cold has none.
  describe("item traits", function()
    local function keys(...)
      local set = {}
      for _, k in ipairs({...}) do set[k] = true end
      return set
    end

    before_each(function()
      search:Add(MockSearchItem({ slotkey = "blade", currentItemLevel = 600, traits = {
        minLevel = 70, stackSize = 1, sellPrice = 52000, isEquipment = true, hasUse = true, isCosmetic = false,
        isPet = false, isScrappable = true, upgradeTrack = "Hero", upgradeLevel = 3, upgradeMax = 6,
        upgradeMaxItemLevel = 619, stats = { "Critical Strike", "Haste" } } }))
      search:Add(MockSearchItem({ slotkey = "ore", currentItemLevel = 1, traits = {
        minLevel = 0, stackSize = 200, sellPrice = 0, isEquipment = false, hasUse = false, isCosmetic = false,
        isPet = false, isScrappable = false, stats = {} } }))
      search:Add(MockSearchItem({ slotkey = "snake", currentItemLevel = 25, traits = {
        minLevel = 0, stackSize = 1, sellPrice = 100, isEquipment = false, hasUse = true, isPet = true,
        stats = {} } }))
      local cold = MockSearchItem({ slotkey = "cold", currentItemLevel = 1 })
      cold.itemInfo.tooltipMarks = { toy = true, known = true }
      search:Add(cold)
    end)

    it("finds items by required level, max stack and sell price", function()
      assert.are.same(keys("blade"), search:Search("minlevel > 60"))
      assert.are.same(keys("ore", "snake"), search:Search("minlevel = 0"))
      assert.are.same(keys("ore"), search:Search("stacksize >= 200"))
      assert.are.same(keys("ore"), search:Search("price = 0"))
      assert.are.same(keys("blade"), search:Search("price > 10000"))
    end)

    it("finds items by what they are", function()
      assert.are.same(keys("blade"), search:Search("equipment = true"))
      assert.are.same(keys("ore", "snake"), search:Search("equipment = false"))
      assert.are.same(keys("blade", "snake"), search:Search("hasuse = true"))
      assert.are.same(keys("blade", "ore"), search:Search("cosmetic = false"), "a client without the answer has none")
      assert.are.same(keys("snake"), search:Search("pet = true"))
      assert.are.same(keys("blade"), search:Search("scrappable = true"))
    end)

    it("finds equipment by its upgrade track", function()
      assert.are.same(keys("blade"), search:Search("upgradeable = true"))
      assert.are.same(keys("ore", "snake"), search:Search("upgradeable = false"))
      assert.are.same(keys("blade"), search:Search("track = hero"))
      assert.are.same(keys("blade"), search:Search("upgradelevel = 3 AND upgrademax = 6"))
    end)

    -- Vendor's MaxLevel: the fully upgraded item level, never below the current one; the current one
    -- for an item without a track.
    it("finds items by their fully upgraded item level", function()
      assert.are.same(keys("blade"), search:Search("maxlevel = 619"))
      assert.are.same(keys("snake"), search:Search("maxlevel = 25"))
      assert.are.same({}, search:Search("maxlevel = 600"))
    end)

    it("takes the current item level as the max when an upgrade would lower it", function()
      search:Add(MockSearchItem({ slotkey = "squished", currentItemLevel = 640, traits = {
        isEquipment = true, upgradeTrack = "Myth", upgradeLevel = 1, upgradeMax = 6, upgradeMaxItemLevel = 619,
        stats = {} } }))
      assert.are.same(keys("squished"), search:Search("maxlevel = 640"))
    end)

    it("finds items by their stats, by the start of a stat's name or anywhere in it", function()
      assert.are.same(keys("blade"), search:Search("stat = haste"))
      assert.are.same(keys("blade"), search:Search("stat = crit"))
      assert.are.same(keys("blade"), search:Search("stat %= strike"))
      assert.are.same({}, search:Search("stat = mastery"))
    end)

    -- Rule #1: an item read before its data loaded matches no trait until it is read again.
    it("matches no trait of an item read cold", function()
      for _, q in ipairs({ "minlevel >= 0", "price >= 0", "equipment = false", "hasuse = false", "pet = false",
        "upgradeable = false", "maxlevel >= 0", "stacksize >= 0", "quality >= 0", "toy = true", "toy = false",
        "known = true", "known = false" }) do
        assert.is_nil(search:Search(q).cold, q)
      end
    end)
  end)

  -- ─── Fields the pipeline works out ──────────────────────────────────────────

  describe("gear sets, upgrade arrows and totals", function()
    local function keys(...)
      local set = {}
      for _, k in ipairs({...}) do set[k] = true end
      return set
    end

    before_each(function()
      local helm = MockSearchItem({ slotkey = "helm", equipmentSets = { "Tank" } })
      helm.isUpgrade = true
      helm.itemTotal = 1
      local potion = MockSearchItem({ slotkey = "potion" })
      potion.isUpgrade = false
      potion.itemTotal = 45
      local cold = MockSearchItem({ slotkey = "cold" })
      cold.isUpgrade = true
      cold.harvestIncomplete = true
      cold.itemTotal = 2
      search:Add(helm)
      search:Add(potion)
      search:Add(cold)
    end)

    it("finds items in any gear set", function()
      assert.are.same(keys("helm"), search:Search("inset = true"))
      assert.are.same(keys("potion", "cold"), search:Search("inset = false"))
    end)

    -- The arrow BetterBags draws, from the active provider (data-loader.md §15).
    it("finds items the upgrade arrow marks, but not one read before its data loaded", function()
      assert.are.same(keys("helm"), search:Search("upgrade = true"))
      assert.are.same(keys("potion"), search:Search("upgrade = false"))
    end)

    it("finds items by how many of them the bags hold", function()
      assert.are.same(keys("potion"), search:Search("total >= 40"))
      assert.are.same(keys("helm", "cold"), search:Search("total < 10"))
    end)
  end)

  -- ─── Usability and appearances ──────────────────────────────────────────────

  describe("usability and appearances", function()
    local function keys(...)
      local set = {}
      for _, k in ipairs({...}) do set[k] = true end
      return set
    end

    before_each(function()
      local cloak = MockSearchItem({ slotkey = "cloak", traits = { isEquipment = true, transmoggable = true, stats = {} } })
      cloak.isUsable = true
      local plate = MockSearchItem({ slotkey = "plate", traits = { isEquipment = true, transmoggable = true, stats = {} } })
      plate.isUsable = false
      local recipe = MockSearchItem({ slotkey = "recipe", traits = { isEquipment = false, transmoggable = false, stats = {} } })
      recipe.isUsable = false
      local classic = MockSearchItem({ slotkey = "classic", traits = { isEquipment = true, stats = {} } })
      local cold = MockSearchItem({ slotkey = "cold" })
      cold.isUsable = true
      for _, item in ipairs({ cloak, plate, recipe, classic, cold }) do search:Add(item) end
    end)

    it("finds items the character can use, and gear the character can wear", function()
      assert.are.same(keys("cloak"), search:Search("usable = true"))
      assert.are.same(keys("plate", "recipe"), search:Search("usable = false"))
      assert.are.same(keys("cloak"), search:Search("equippable = true"))
      assert.are.same(keys("plate", "recipe"), search:Search("equippable = false"),
        "a client that cannot say whether it is usable says nothing")
    end)

    -- Vendor's PetCount, PetLimit and IsPetCollectable (itemproperties.lua): the account's count of
    -- the species, its limit, and whether one more can be learned.
    it("finds pets by how many the account has, and whether one more can be learned", function()
      local snake = MockSearchItem({ slotkey = "snake", traits = { isPet = true, petSpeciesID = 635, stats = {} } })
      snake.petOwned, snake.petLimit = 1, 3
      local full = MockSearchItem({ slotkey = "full", traits = { isPet = true, petSpeciesID = 243, stats = {} } })
      full.petOwned, full.petLimit = 1, 1
      local unloaded = MockSearchItem({ slotkey = "unloaded", traits = { isPet = true, petSpeciesID = 9, stats = {} } })
      local ore = MockSearchItem({ slotkey = "ore", traits = { isPet = false, stats = {} } })
      for _, item in ipairs({ snake, full, unloaded, ore }) do search:Add(item) end
      assert.are.same(keys("snake"), search:Search("collectable = true"))
      assert.are.same(keys("full", "ore"), search:Search("collectable = false"),
        "not a pet is not collectable; a pet whose counts are not known yet is neither, nor an item with no "
          .. "answer about pets (the recipe, as on a client without a pet journal)")
      assert.are.same(keys("snake", "full"), search:Search("petcount = 1"))
      assert.are.same(keys("snake"), search:Search("petlimit = 3"))
      assert.are.same({}, search:Search("petcount = 0"), "no count before the journal loaded")
    end)

    it("finds items with an appearance", function()
      assert.are.same(keys("cloak", "plate"), search:Search("transmoggable = true"))
      assert.are.same(keys("recipe"), search:Search("transmoggable = false"))
    end)
  end)

  -- ─── Expressions (docs/vendor-compat.md, "Proposed: the math") ─────────────

  describe("expressions", function()
    local saved
    local function keys(...)
      local set = {}
      for _, k in ipairs({...}) do set[k] = true end
      return set
    end
    local function override(tbl, key, value)
      table.insert(saved, { tbl, key, rawget(tbl, key) })
      tbl[key] = value
    end

    before_each(function()
      saved = {}
      -- Player values as a retail capture recorded them (12.1.5): a level 90 Protection Paladin,
      -- average item level 233.6875, Tailoring, Enchanting and three secondary professions.
      override(_G, "UnitLevel", function(unit) return unit == "player" and 90 or 0 end)
      override(_G, "GetAverageItemLevel", function() return 233.6875, 229.25, 230 end)
      override(_G, "UnitClass", function() return "Paladin", "PALADIN", 2 end)
      override(_G, "UnitFullName", function() return "Someone", "Somewhere" end)
      override(_G, "C_SpecializationInfo", { GetSpecialization = function() return 2 end,
        GetSpecializationInfo = function(index) if index == 2 then return 66, "Protection" end end })
      override(_G, "GetProfessions", function() return 7, 8, 10, 9, 6 end)
      local professions = { [7] = { "Tailoring", 197 }, [8] = { "Enchanting", 333 }, [10] = { "Archaeology", 794 },
        [9] = { "Fishing", 356 }, [6] = { "Cooking", 185 } }
      override(_G, "GetProfessionInfo", function(index)
        local p = professions[index]
        return p[1], 1, 50, 100, 2, 0, p[2]
      end)
      -- traits = false: an item read before its data loaded, which has none.
      local function item(key, opts)
        opts.slotkey = key
        if opts.traits == false then
          opts.traits = nil
        elseif opts.traits == nil then
          opts.traits = { stats = {} }
        end
        search:Add(MockSearchItem(opts))
      end
      item("sword", { name = "Sword", currentItemLevel = 220, quality = 4, count = 1,
        traits = { sellPrice = 52000, upgradeMaxItemLevel = 240, stats = {} } })
      item("swordlong", { name = "Sword of the Ages", currentItemLevel = 70, quality = 3, count = 1,
        traits = { sellPrice = 9000, stats = {} } })
      item("potion", { name = "Potion", currentItemLevel = 80, quality = 1, count = 20,
        traits = { sellPrice = 600, stats = {} } })
      item("cheese", { name = "Cheese", currentItemLevel = 12, quality = 1, count = 5,
        traits = { sellPrice = 0, stats = {} } })
      item("cold", { name = "Cold", currentItemLevel = 10, quality = 0, count = 1, traits = false })
    end)

    after_each(function()
      for i = #saved, 1, -1 do saved[i][1][saved[i][2]] = saved[i][3] end
    end)

    it("compares a whole text with ==, and its negation with ~=", function()
      assert.are.same(keys("sword"), search:Search("name == sword"))
      assert.are.same(keys("sword", "swordlong"), search:Search("name = sword"), "= still starts the text")
      assert.are.same(keys("swordlong", "potion", "cheese", "cold"), search:Search("name ~= sword"))
      assert.are.same(keys("potion"), search:Search("count == 20"))
    end)

    it("reads money as copper", function()
      assert.are.same(keys("sword"), search:Search("price > 5g"))
      assert.are.same(keys("swordlong"), search:Search("price = 90s"))
      assert.are.same(keys("sword", "swordlong"), search:Search("price >= 1g50s - 60s"))
      assert.are.same(keys("potion", "cheese"), search:Search("price < 6s1c"))
      assert.are.same({}, search:Search("price > 5gx"), "not money: matches nothing, as before")
    end)

    it("folds player values into an index lookup", function()
      assert.are.same(keys("potion", "swordlong", "cheese", "cold"), search:Search("ilvl <= player.level - 10"))
      assert.are.same(keys("sword"), search:Search("ilvl > player.ilvl - 20"))
      assert.are.same(keys("swordlong", "potion", "cheese", "cold"), search:Search("80 >= ilvl"), "flipped")
      assert.are.same(keys("sword", "swordlong", "potion"), search:Search("60 < ilvl"))
      assert.are.same(keys("sword", "potion"), search:Search("70 < ilvl"))
      assert.are.same(keys("sword", "swordlong", "potion"), search:Search("70 <= ilvl"))
      assert.are.same(keys("swordlong", "potion", "cheese", "cold"), search:Search("ilvl < player.level"),
        "a player value written as a plain word")
    end)

    it("works out the parts that do not depend on the item once", function()
      local asked = 0
      local playerValue = search.PlayerValue
      search.PlayerValue = function(self, name)
        asked = asked + 1
        return playerValue(self, name)
      end
      local result = search:Search("price * count > player.level")
      search.PlayerValue = playerValue
      assert.are.same(keys("sword", "swordlong", "potion"), result)
      assert.are.equal(1, asked)
    end)

    it("negates within the items the rest of an AND matched", function()
      local universe = search.Universe
      local whole = 0
      search.Universe = function(self)
        whole = whole + 1
        return universe(self)
      end
      local result = search:Search("rarity = epic AND (NOT name = sword OR name = sword)")
      search.Universe = universe
      assert.are.same(keys("sword"), result)
      assert.are.equal(0, whole, "the NOT went over the AND's matches, not every item")
    end)

    it("answers a comparison of player values alone for every item, or none", function()
      assert.are.same(keys("sword", "swordlong", "potion", "cheese", "cold"), search:Search("player.level >= 80"))
      assert.are.same({}, search:Search("player.level < 80"))
      assert.are.same(keys("potion"), search:Search("player.class = paladin AND name = potion"))
      assert.are.same({}, search:Search("player.class = mage"))
    end)

    it("reads every player value", function()
      local all = keys("sword", "swordlong", "potion", "cheese", "cold")
      for _, query in ipairs({ "player.level == 90", "player.ilvl == 233", "player.equippedilvl == 229",
        "player.class == paladin", "player.class == PALADIN", "player.classid == 2", "player.spec == protection",
        "player.spec = prot", "player.specid == 66", "player.profession = tailoring", "player.profession = 197",
        "player.profession = cook", "player.name == someone", "player.realm == somewhere" }) do
        assert.are.same(all, search:Search(query), query)
      end
      assert.are.same({}, search:Search("player.profession = mining"))
      assert.are.same({}, search:Search("player.unknown = 1"), "an unknown player value matches nothing")
    end)

    it("has no specialization before one is known", function()
      _G.C_SpecializationInfo.GetSpecialization = function() return 0 end
      local asked = 0
      _G.C_SpecializationInfo.GetSpecializationInfo = function() asked = asked + 1 end
      assert.are.same({}, search:Search("player.specid > 0"))
      assert.are.equal(0, asked, "index 0 is no specialization")
    end)

    it("reads the class by its token or its name", function()
      _G.UnitClass = function() return "Death Knight", "DEATHKNIGHT", 6 end
      local all = keys("sword", "swordlong", "potion", "cheese", "cold")
      assert.are.same(all, search:Search('player.class == "death knight"'))
      assert.are.same(all, search:Search("player.class == deathknight"))
    end)

    it("compares a field with another field, item by item", function()
      assert.are.same(keys("sword"), search:Search("maxlevel > ilvl"))
      assert.are.same(keys("swordlong", "potion", "cheese"), search:Search("maxlevel == ilvl"))
    end)

    it("does arithmetic on fields, item by item", function()
      assert.are.same(keys("sword", "potion"), search:Search("price * count >= 1g"))
      assert.are.same(keys("sword", "swordlong", "potion"), search:Search("price * count > 0"))
      assert.are.same(keys("potion"), search:Search("count % 2 == 0 AND count > 10"))
    end)

    -- Vendor's Potential Upgrades rule.
    it("calls functions", function()
      assert.are.same(keys("sword"), search:Search("maxlevel >= min(player.ilvl * 0.95, player.ilvl - 5)"))
      assert.are.same(keys("sword"), search:Search("maxlevel >= math.max(floor(221.9), ceil(220.1), abs(-1))"))
    end)

    it("negates an expression against every item", function()
      assert.are.same(keys("swordlong", "cheese", "cold"), search:Search("NOT price * count >= 1g"))
    end)

    it("matches nothing where a value is missing, and never fails", function()
      assert.are.same({}, search:Search("price * count > 0 AND name = cold"))
      assert.are.same({}, search:Search("name + 1 > 2"))
      assert.are.same({}, search:Search("price / 0 < 0"))
    end)

    -- Within an AND, the side the index answers is found first, and the other side checks only its
    -- matches.
    it("checks item by item only the items the rest of an AND matched", function()
      local checked = {}
      local matchEach = search.MatchEach
      search.MatchEach = function(self, node, candidates)
        local n = 0
        for _ in pairs(candidates) do n = n + 1 end
        table.insert(checked, n)
        return matchEach(self, node, candidates)
      end
      local result = search:Search("price * count > 0 AND rarity = epic")
      local reversed = search:Search("rarity = epic AND price * count > 0")
      search.MatchEach = matchEach
      assert.are.same(keys("sword"), result)
      assert.are.same(keys("sword"), reversed)
      assert.are.same({ 1, 1 }, checked)
    end)

    -- The index and the check made item by item must agree: "field op N" is answered from the index,
    -- "field + 0 op N" item by item.
    it("answers a comparison the same from the index and item by item, over random items", function()
      math.randomseed(7)
      search:Init()
      local fields = { "level", "ilvl", "rarity", "count", "price", "maxlevel", "minlevel" }
      local ops = { "=", "==", "!=", "~=", "<", "<=", ">", ">=" }
      for i = 1, 60 do
        local traits = math.random(5) > 1 and { sellPrice = math.random(0, 5) * 100, minLevel = math.random(0, 3) * 10,
          upgradeMaxItemLevel = math.random(3) == 1 and math.random(10, 40) or nil, stats = {} } or nil
        search:Add(MockSearchItem({ slotkey = "r" .. i, currentItemLevel = math.random(10, 30), quality = math.random(0, 5),
          count = math.random(1, 4), traits = traits }))
      end
      for _ = 1, 300 do
        local field, op, n = fields[math.random(#fields)], ops[math.random(#ops)], math.random(0, 40) * 10 / 10
        if field == "price" then n = math.random(0, 5) * 100 end
        local indexed = search:Search(field .. " " .. op .. " " .. n)
        local each = search:Search(field .. " + 0 " .. op .. " " .. n)
        assert.are.same(indexed, each, field .. " " .. op .. " " .. n)
        local other = fields[math.random(#fields)] .. " > " .. math.random(0, 30)
        for _, join in ipairs({ " AND ", " OR ", " AND NOT " }) do
          local q1 = field .. " " .. op .. " " .. n .. join .. other
          local q2 = field .. " + 0 " .. op .. " " .. n .. join .. other
          assert.are.same(search:Search(q1), search:Search(q2), q1)
        end
      end
    end)

    it("reads an equipment slot token as the slot's name", function()
      local head = _G.INVTYPE_HEAD
      _G.INVTYPE_HEAD = "Head"
      search:Add(MockSearchItem({ slotkey = "helm", name = "Helm", equipLoc = "INVTYPE_HEAD", traits = { stats = {} } }))
      local result = search:Search("slot = INVTYPE_HEAD")
      _G.INVTYPE_HEAD = head
      assert.are.same(keys("helm"), result)
    end)

    it("keeps reading a word compared with a text field as text", function()
      search:Add(MockSearchItem({ slotkey = "lvl", name = "Level Up", traits = { stats = {} } }))
      assert.are.same(keys("lvl"), search:Search("name = level"))
      assert.are.same(keys("lvl"), search:Search('name == "level up"'))
    end)
  end)

  -- ─── Expansion order ────────────────────────────────────────────────────────

  -- Asked (docs/vendor-compat.md, "Decisions"): < and > compare expansions in release order. The
  -- field holds a short name, and comparing it matched nothing.
  describe("expansion order", function()
    local function keys(...)
      local set = {}
      for _, k in ipairs({...}) do set[k] = true end
      return set
    end

    before_each(function()
      search:Add(MockSearchItem({ slotkey = "classic", expacID = 0 }))
      search:Add(MockSearchItem({ slotkey = "bc", expacID = 1 }))
      search:Add(MockSearchItem({ slotkey = "cata", expacID = 3 }))
      search:Add(MockSearchItem({ slotkey = "tww", expacID = 9 }))
      search:Add(MockSearchItem({ slotkey = "none" }))
    end)

    it("orders expansions named in a comparison by their release", function()
      assert.are.same(keys("classic", "bc"), search:Search("exp < cata"))
      assert.are.same(keys("cata", "tww"), search:Search("exp >= cata"))
      assert.are.same(keys("cata", "tww"), search:Search("expansion > bc"))
      assert.are.same(keys("classic", "bc", "cata"), search:Search("exp <= CATA"))
    end)

    it("takes an expansion's number", function()
      assert.are.same(keys("classic", "bc"), search:Search("exp <= 1"))
      assert.are.same(keys("cata"), search:Search("exp = 3"))
      assert.are.same(keys("classic", "bc", "tww", "none"), search:Search("exp != 3"))
    end)

    it("takes the start of a name when only one expansion has it, and matches nothing otherwise", function()
      assert.are.same(keys("classic", "bc", "cata"), search:Search("exp < tw"))
      assert.are.same({}, search:Search("exp < c"), "classic or cata")
      assert.are.same({}, search:Search("exp < nosuchexpansion"))
    end)

    it("still matches names as text for = and !=", function()
      assert.are.same(keys("cata"), search:Search("exp = cata"))
      assert.are.same(keys("classic", "cata"), search:Search("exp = c"))
    end)

    -- TBC Anniversary tags its items 254, which BetterBags names bc (const.BRIEF_EXPANSION_MAP, set
    -- when the addon loads, before the search module is initialized).
    it("orders an expansion by its name, whatever number the client tags it with", function()
      const.BRIEF_EXPANSION_MAP[254] = "bc"
      local ok, err = pcall(function()
        search:Init()
        search:Add(MockSearchItem({ slotkey = "bc", expacID = 1 }))
        search:Add(MockSearchItem({ slotkey = "anniversary", expacID = 254 }))
        search:Add(MockSearchItem({ slotkey = "cata", expacID = 3 }))
        assert.are.same(keys("bc", "anniversary"), search:Search("exp < cata"))
        assert.are.same(keys("bc", "anniversary"), search:Search("exp = 1"))
      end)
      const.BRIEF_EXPANSION_MAP[254] = nil
      assert(ok, err)
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
      { "bag name", function(it) it.bagName = "Large Sack" end },
      { "crafting quality", function(it) it.itemInfo.traits.craftingQuality = 2 end },
      { "required level", function(it) it.itemInfo.traits.minLevel = 30 end },
      { "max stack", function(it) it.itemInfo.traits.stackSize = 20 end },
      { "sell price", function(it) it.itemInfo.traits.sellPrice = 999 end },
      { "equipment flag", function(it) it.itemInfo.traits.isEquipment = true end },
      { "use flag", function(it) it.itemInfo.traits.hasUse = true end },
      { "cosmetic flag", function(it) it.itemInfo.traits.isCosmetic = true end },
      { "pet flag", function(it) it.itemInfo.traits.isPet = true end },
      { "scrappable flag", function(it) it.itemInfo.traits.isScrappable = true end },
      { "upgrade track", function(it) it.itemInfo.traits.upgradeTrack = "Veteran" end },
      { "upgrade level", function(it) it.itemInfo.traits.upgradeLevel = 2 end },
      { "upgrade max", function(it) it.itemInfo.traits.upgradeMax = 8 end },
      { "upgraded item level", function(it) it.itemInfo.traits.upgradeMaxItemLevel = 700 end },
      { "stats", function(it) it.itemInfo.traits.stats = { "Versatility" } end },
      { "traits read once loaded", function(it) it.itemInfo.traits = nil end },
      { "upgrade arrow", function(it) it.isUpgrade = true end },
      { "total held", function(it) it.itemTotal = 99 end },
      { "read cold", function(it) it.harvestIncomplete = true; it.isUpgrade = true end },
      { "toy mark", function(it) it.itemInfo.tooltipMarks = { toy = true } end },
      { "known mark", function(it) it.itemInfo.tooltipMarks = { known = true } end },
      { "usable", function(it) it.isUsable = true end },
      { "appearance", function(it) it.itemInfo.traits.transmoggable = true end },
      { "slot equipped", function(it) it.slotEquipped = 200 end },
      { "slot best", function(it) it.slotBest = 250 end },
      { "pet count", function(it) it.petOwned = 2 end, pet = true },
      { "pet limit", function(it) it.petLimit = 5 end, pet = true },
      { "pet counts known", function(it) it.petOwned, it.petLimit = nil, nil end, pet = true },
    }
    for _, change in ipairs(changes) do
      it(change[1], function()
        local savedHead = _G.INVTYPE_HEAD
        _G.INVTYPE_HEAD = "Head"
        local sword = item({ slotkey = "a", name = "Sword", kind = BACKPACK, tooltipText = "Use: Restores health." })
        sword.itemInfo.traits = { minLevel = 10, stackSize = 1, sellPrice = 5, isEquipment = false, hasUse = false,
          isCosmetic = false, isPet = false, isScrappable = false, upgradeTrack = "Hero", upgradeLevel = 1,
          upgradeMax = 6, upgradeMaxItemLevel = 619, stats = { "Haste" } }
        -- A pet whose counts are known, for the changes that only a pet has.
        if change.pet then
          sword.itemInfo.traits.isPet = true
          sword.petOwned, sword.petLimit = 1, 3
        end
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
      local which = random(25)
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
      elseif which == 18 then it.bagName = pick({ "Backpack", "Herb Satchel", "Large Sack" })
      elseif which == 19 then
        if random(4) == 1 then
          info.traits = nil
        else
          info.traits = info.traits or {}
          local t = info.traits
          local f = random(8)
          if f == 1 then t.craftingQuality = random(3) == 1 and nil or random(5)
          elseif f == 2 then t.minLevel = random(4) * 10
          elseif f == 3 then t.sellPrice = random(3) - 1
          elseif f == 4 then t.isEquipment = random(2) == 1
          elseif f == 5 then t.upgradeTrack = pick({ "Hero", "Myth", nil })
          elseif f == 6 then t.upgradeMaxItemLevel = random(3) * 100
          elseif f == 7 then t.stats = random(2) == 1 and { pick({ "Haste", "Mastery" }) } or nil
          else t.isPet = random(2) == 1 end
        end
      elseif which == 20 then it.isUpgrade = random(2) == 1
      elseif which == 21 then it.itemTotal = random(3) * 10
      elseif which == 22 then it.itemInfo.tooltipMarks = pick({ { toy = true }, { known = true }, { toy = true, known = true }, false }) or nil
      elseif which == 23 then it.isUsable = pick({ true, false, "none" })
        if it.isUsable == "none" then it.isUsable = nil end
      elseif which == 24 then
        if it.itemInfo.traits then it.itemInfo.traits.isPet = random(2) == 1 end
        it.petOwned = random(3) == 1 and nil or random(3) - 1
        it.petLimit = it.petOwned and 3 or nil
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
