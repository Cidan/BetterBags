-- search_new_spec.lua -- Unit tests for data/search_new.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Dependencies
LoadBetterBagsModule("util/query.lua")
LoadBetterBagsModule("util/trees/trees.lua")
LoadBetterBagsModule("util/trees/intervaltree.lua")

-- Stub Debug (search uses debug:Log and debug:Inspect)
local debug = StubBetterBagsModule("Debug")
debug.Log = function() end
debug.Inspect = function() end

-- Set up Constants that search_new.lua references
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

-- Load the new search module
LoadBetterBagsModule("data/search_new.lua")
local search = addon:GetModule("Search")

local MockSearchItem = MockData.ItemData

describe("Search (New Clean-Sweep Engine)", function()
  before_each(function()
    search:OnInitialize()
  end)

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
end)
