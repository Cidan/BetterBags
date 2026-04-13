-- intervaltree_spec.lua -- Unit tests for util/trees/ (Trees + IntervalTree)

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
-- trees.lua must load first (creates the Trees module), then intervaltree.lua (adds methods)
LoadBetterBagsModule("util/trees/trees.lua")
LoadBetterBagsModule("util/trees/intervaltree.lua")
local Trees = addon:GetModule("Trees")

-- Helper: extract values from a list of IntervalTreeNodes
local function nodeValues(nodes)
  local values = {}
  for _, node in ipairs(nodes) do
    table.insert(values, node.value)
  end
  table.sort(values)
  return values
end

describe("IntervalTree", function()

  local tree

  before_each(function()
    tree = Trees.NewIntervalTree()
  end)

  -- ─── Insert ─────────────────────────────────────────────────────────────────

  describe("Insert", function()

    it("inserts a single value", function()
      tree:Insert(10, {a = true})
      local node = tree:ExactMatch(10)
      assert.is_not_nil(node)
      assert.are.equal(10, node.value)
      assert.same({a = true}, node.data)
    end)

    it("inserts multiple values into a BST structure", function()
      tree:Insert(10, {a = true})
      tree:Insert(5, {b = true})
      tree:Insert(15, {c = true})
      assert.is_not_nil(tree:ExactMatch(10))
      assert.is_not_nil(tree:ExactMatch(5))
      assert.is_not_nil(tree:ExactMatch(15))
    end)

    it("merges data when inserting a duplicate value", function()
      tree:Insert(10, {a = true})
      tree:Insert(10, {b = true})
      local node = tree:ExactMatch(10)
      assert.same({a = true, b = true}, node.data)
    end)

    it("overwrites a data key on duplicate insert", function()
      tree:Insert(10, {a = "first"})
      tree:Insert(10, {a = "second"})
      local node = tree:ExactMatch(10)
      assert.are.equal("second", node.data.a)
    end)
  end)

  -- ─── ExactMatch ─────────────────────────────────────────────────────────────

  describe("ExactMatch", function()

    it("finds an existing value", function()
      tree:Insert(42, {x = true})
      local node = tree:ExactMatch(42)
      assert.is_not_nil(node)
      assert.are.equal(42, node.value)
    end)

    it("returns nil for a missing value", function()
      tree:Insert(10, {a = true})
      assert.is_nil(tree:ExactMatch(99))
    end)

    it("returns nil on an empty tree", function()
      assert.is_nil(tree:ExactMatch(1))
    end)

    it("finds values in the left subtree", function()
      tree:Insert(10, {a = true})
      tree:Insert(5, {b = true})
      tree:Insert(3, {c = true})
      local node = tree:ExactMatch(3)
      assert.is_not_nil(node)
      assert.are.equal(3, node.value)
    end)

    it("finds values in the right subtree", function()
      tree:Insert(10, {a = true})
      tree:Insert(15, {b = true})
      tree:Insert(20, {c = true})
      local node = tree:ExactMatch(20)
      assert.is_not_nil(node)
      assert.are.equal(20, node.value)
    end)
  end)

  -- ─── LessThan ───────────────────────────────────────────────────────────────

  describe("LessThan", function()

    it("returns nodes with values strictly less than the search value", function()
      tree:Insert(5, {a = true})
      tree:Insert(10, {b = true})
      tree:Insert(15, {c = true})
      local result = nodeValues(tree:LessThan(10))
      assert.same({5}, result)
    end)

    it("returns empty when no values are less", function()
      tree:Insert(10, {a = true})
      tree:Insert(20, {b = true})
      local result = tree:LessThan(5)
      assert.same({}, result)
    end)

    it("returns all nodes when search value is larger than all", function()
      tree:Insert(1, {a = true})
      tree:Insert(2, {b = true})
      tree:Insert(3, {c = true})
      local result = nodeValues(tree:LessThan(100))
      assert.same({1, 2, 3}, result)
    end)

    it("returns empty on an empty tree", function()
      assert.same({}, tree:LessThan(10))
    end)
  end)

  -- ─── LessThanEqual ──────────────────────────────────────────────────────────

  describe("LessThanEqual", function()

    it("includes the exact match value", function()
      tree:Insert(5, {a = true})
      tree:Insert(10, {b = true})
      tree:Insert(15, {c = true})
      local result = nodeValues(tree:LessThanEqual(10))
      assert.same({5, 10}, result)
    end)

    it("returns empty when no values are less or equal", function()
      tree:Insert(10, {a = true})
      local result = tree:LessThanEqual(5)
      assert.same({}, result)
    end)
  end)

  -- ─── GreaterThan ────────────────────────────────────────────────────────────

  describe("GreaterThan", function()

    it("returns nodes with values strictly greater than the search value", function()
      tree:Insert(5, {a = true})
      tree:Insert(10, {b = true})
      tree:Insert(15, {c = true})
      local result = nodeValues(tree:GreaterThan(10))
      assert.same({15}, result)
    end)

    it("returns empty when no values are greater", function()
      tree:Insert(10, {a = true})
      local result = tree:GreaterThan(20)
      assert.same({}, result)
    end)

    it("returns all nodes when search value is smaller than all", function()
      tree:Insert(10, {a = true})
      tree:Insert(20, {b = true})
      tree:Insert(30, {c = true})
      local result = nodeValues(tree:GreaterThan(1))
      assert.same({10, 20, 30}, result)
    end)

    it("returns empty on an empty tree", function()
      assert.same({}, tree:GreaterThan(10))
    end)
  end)

  -- ─── GreaterThanEqual ───────────────────────────────────────────────────────

  describe("GreaterThanEqual", function()

    it("includes the exact match value", function()
      tree:Insert(5, {a = true})
      tree:Insert(10, {b = true})
      tree:Insert(15, {c = true})
      local result = nodeValues(tree:GreaterThanEqual(10))
      assert.same({10, 15}, result)
    end)

    it("returns empty when no values are greater or equal", function()
      tree:Insert(10, {a = true})
      local result = tree:GreaterThanEqual(20)
      assert.same({}, result)
    end)
  end)

  -- ─── RemoveData ─────────────────────────────────────────────────────────────

  describe("RemoveData", function()

    it("removes a specific data key from a node", function()
      tree:Insert(10, {a = true, b = true})
      tree:RemoveData(10, "a")
      local node = tree:ExactMatch(10)
      assert.is_not_nil(node)
      assert.is_nil(node.data.a)
      assert.is_true(node.data.b)
    end)

    it("removes the node entirely when data becomes empty", function()
      tree:Insert(10, {a = true})
      tree:RemoveData(10, "a")
      assert.is_nil(tree:ExactMatch(10))
    end)

    it("does nothing for a non-existent value", function()
      tree:Insert(10, {a = true})
      tree:RemoveData(99, "a") -- should not error
      assert.is_not_nil(tree:ExactMatch(10))
    end)

    it("removes a leaf node and preserves the rest of the tree", function()
      tree:Insert(10, {a = true})
      tree:Insert(5, {b = true})
      tree:Insert(15, {c = true})
      tree:RemoveData(5, "b")
      assert.is_nil(tree:ExactMatch(5))
      assert.is_not_nil(tree:ExactMatch(10))
      assert.is_not_nil(tree:ExactMatch(15))
    end)

    it("removes the root node when it is the only node", function()
      tree:Insert(10, {a = true})
      tree:RemoveData(10, "a")
      assert.is_nil(tree:ExactMatch(10))
      -- Tree should be usable again after removal
      tree:Insert(20, {b = true})
      assert.is_not_nil(tree:ExactMatch(20))
    end)
  end)

  -- ─── NewIntervalTree factory ────────────────────────────────────────────────

  describe("NewIntervalTree", function()

    it("creates independent tree instances", function()
      local tree2 = Trees.NewIntervalTree()
      tree:Insert(10, {a = true})
      tree2:Insert(20, {b = true})
      assert.is_nil(tree:ExactMatch(20))
      assert.is_nil(tree2:ExactMatch(10))
    end)
  end)
end)
