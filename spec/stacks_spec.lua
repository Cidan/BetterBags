-- stacks_spec.lua -- Unit tests for data/stacks.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Stacks JIT-loads Items via addon:GetModule('Items') inside AddToStack/RemoveFromStack.
-- Create a stub with a controllable lookup table.
local items = StubBetterBagsModule("Items")
local itemDataStore = {}

items.GetItemDataFromSlotKey = function(_, slotkey)
  return itemDataStore[slotkey]
end

LoadBetterBagsModule("data/stacks.lua")
local stacksMod = addon:GetModule("Stacks")

--- Helper: create mock ItemData
---@param opts table {slotkey, itemHash, count, isItemEmpty}
local function MockItemData(opts)
  local data = {
    slotkey = opts.slotkey or "bag:0:slot:0",
    itemHash = opts.itemHash or "hash-default",
    isItemEmpty = opts.isItemEmpty or false,
    itemInfo = {
      currentItemCount = opts.count or 1,
    },
  }
  -- Register in the store so Items:GetItemDataFromSlotKey can find it
  itemDataStore[data.slotkey] = data
  return data
end

describe("Stacks", function()

  local stack

  before_each(function()
    stack = stacksMod:Create()
    -- Clear the item data store
    for k in pairs(itemDataStore) do
      itemDataStore[k] = nil
    end
  end)

  -- ─── Create ─────────────────────────────────────────────────────────────────

  describe("Create", function()

    it("creates a new empty stack", function()
      assert.is_not_nil(stack)
      assert.same({}, stack.stacksByItemHash)
    end)

    it("creates independent instances", function()
      local stack2 = stacksMod:Create()
      local item = MockItemData({slotkey = "s1", itemHash = "h1"})
      stack:AddToStack(item)
      assert.are.equal(1, stack:GetTotalCount("h1"))
      assert.are.equal(0, stack2:GetTotalCount("h1"))
    end)
  end)

  -- ─── AddToStack ─────────────────────────────────────────────────────────────

  describe("AddToStack", function()

    it("adds a single item as root", function()
      local item = MockItemData({slotkey = "s1", itemHash = "h1", count = 5})
      stack:AddToStack(item)
      assert.are.equal(1, stack:GetTotalCount("h1"))
      assert.is_true(stack:IsRootItem("h1", "s1"))
    end)

    it("ignores empty items", function()
      local item = MockItemData({slotkey = "s1", itemHash = "h1", isItemEmpty = true})
      stack:AddToStack(item)
      assert.are.equal(0, stack:GetTotalCount("h1"))
    end)

    it("stacks items with the same hash", function()
      local item1 = MockItemData({slotkey = "s1", itemHash = "h1", count = 5})
      local item2 = MockItemData({slotkey = "s2", itemHash = "h1", count = 10})
      stack:AddToStack(item1)
      stack:AddToStack(item2)
      assert.are.equal(2, stack:GetTotalCount("h1"))
    end)

    it("promotes the item with the highest count to root", function()
      local small = MockItemData({slotkey = "s1", itemHash = "h1", count = 5})
      local large = MockItemData({slotkey = "s2", itemHash = "h1", count = 20})
      stack:AddToStack(small)
      stack:AddToStack(large)
      assert.is_true(stack:IsRootItem("h1", "s2"))
    end)

    it("keeps different item hashes separate", function()
      local item1 = MockItemData({slotkey = "s1", itemHash = "h1", count = 1})
      local item2 = MockItemData({slotkey = "s2", itemHash = "h2", count = 1})
      stack:AddToStack(item1)
      stack:AddToStack(item2)
      assert.are.equal(1, stack:GetTotalCount("h1"))
      assert.are.equal(1, stack:GetTotalCount("h2"))
    end)
  end)

  -- ─── RemoveFromStack ────────────────────────────────────────────────────────

  describe("RemoveFromStack", function()

    it("removes a non-root item from the stack", function()
      local item1 = MockItemData({slotkey = "s1", itemHash = "h1", count = 20})
      local item2 = MockItemData({slotkey = "s2", itemHash = "h1", count = 5})
      stack:AddToStack(item1)
      stack:AddToStack(item2)
      stack:RemoveFromStack(item2)
      assert.are.equal(1, stack:GetTotalCount("h1"))
      assert.is_false(stack:HasItem("h1", "s2"))
    end)

    it("promotes a child to root when root is removed", function()
      local item1 = MockItemData({slotkey = "s1", itemHash = "h1", count = 10})
      local item2 = MockItemData({slotkey = "s2", itemHash = "h1", count = 5})
      stack:AddToStack(item1)
      stack:AddToStack(item2)
      stack:RemoveFromStack(item1)
      assert.is_true(stack:IsRootItem("h1", "s2"))
    end)

    it("removes the entire stack when the last item is removed", function()
      local item = MockItemData({slotkey = "s1", itemHash = "h1", count = 1})
      stack:AddToStack(item)
      stack:RemoveFromStack(item)
      assert.is_nil(stack:GetStackInfo("h1"))
    end)

    it("does nothing for a non-existent item hash", function()
      local item = MockItemData({slotkey = "s1", itemHash = "missing"})
      stack:RemoveFromStack(item) -- should not error
    end)
  end)

  -- ─── GetTotalCount ──────────────────────────────────────────────────────────

  describe("GetTotalCount", function()

    it("returns 0 for unknown hashes", function()
      assert.are.equal(0, stack:GetTotalCount("unknown"))
    end)

    it("returns the correct count after multiple adds", function()
      for i = 1, 5 do
        stack:AddToStack(MockItemData({
          slotkey = "s" .. i,
          itemHash = "h1",
          count = i
        }))
      end
      assert.are.equal(5, stack:GetTotalCount("h1"))
    end)
  end)

  -- ─── GetStackInfo ───────────────────────────────────────────────────────────

  describe("GetStackInfo", function()

    it("returns nil for unknown hashes", function()
      assert.is_nil(stack:GetStackInfo("unknown"))
    end)

    it("returns stack info with count and rootItem", function()
      local item = MockItemData({slotkey = "s1", itemHash = "h1", count = 10})
      stack:AddToStack(item)
      local info = stack:GetStackInfo("h1")
      assert.is_not_nil(info)
      assert.are.equal(1, info.count)
      assert.are.equal("s1", info.rootItem)
    end)
  end)

  -- ─── HasItem ────────────────────────────────────────────────────────────────

  describe("HasItem", function()

    it("returns false for unknown hashes", function()
      assert.is_false(stack:HasItem("unknown", "s1"))
    end)

    it("returns true for root items", function()
      local item = MockItemData({slotkey = "s1", itemHash = "h1"})
      stack:AddToStack(item)
      assert.is_true(stack:HasItem("h1", "s1"))
    end)

    it("returns true for non-root items in the stack", function()
      local item1 = MockItemData({slotkey = "s1", itemHash = "h1", count = 20})
      local item2 = MockItemData({slotkey = "s2", itemHash = "h1", count = 5})
      stack:AddToStack(item1)
      stack:AddToStack(item2)
      assert.is_true(stack:HasItem("h1", "s2"))
    end)

    it("returns false for items not in the stack", function()
      local item = MockItemData({slotkey = "s1", itemHash = "h1"})
      stack:AddToStack(item)
      assert.is_false(stack:HasItem("h1", "s99"))
    end)
  end)

  -- ─── IsRootItem ─────────────────────────────────────────────────────────────

  describe("IsRootItem", function()

    it("returns false for unknown hashes", function()
      assert.is_false(stack:IsRootItem("unknown", "s1"))
    end)

    it("returns true for the root item", function()
      local item = MockItemData({slotkey = "s1", itemHash = "h1"})
      stack:AddToStack(item)
      assert.is_true(stack:IsRootItem("h1", "s1"))
    end)

    it("returns false for non-root items", function()
      local item1 = MockItemData({slotkey = "s1", itemHash = "h1", count = 20})
      local item2 = MockItemData({slotkey = "s2", itemHash = "h1", count = 5})
      stack:AddToStack(item1)
      stack:AddToStack(item2)
      assert.is_false(stack:IsRootItem("h1", "s2"))
    end)
  end)

  -- ─── Clear ──────────────────────────────────────────────────────────────────

  describe("Clear", function()

    it("removes all stack data", function()
      local item1 = MockItemData({slotkey = "s1", itemHash = "h1"})
      local item2 = MockItemData({slotkey = "s2", itemHash = "h2"})
      stack:AddToStack(item1)
      stack:AddToStack(item2)
      stack:Clear()
      assert.are.equal(0, stack:GetTotalCount("h1"))
      assert.are.equal(0, stack:GetTotalCount("h2"))
    end)
  end)
end)
