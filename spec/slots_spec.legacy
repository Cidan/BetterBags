-- slots_spec.lua -- Unit tests for data/slots.lua (SlotInfo)

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Slots extends the Items module and depends on Stacks
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("data/stacks.lua")

-- Items module stub needs GetSlotKeyFromBagAndSlot
local items = StubBetterBagsModule("Items")
items.GetSlotKeyFromBagAndSlot = function(_, bagid, slotid)
  return "bag:" .. bagid .. ":slot:" .. slotid
end

LoadBetterBagsModule("data/slots.lua")

local context = addon:GetModule("Context")

describe("SlotInfo", function()

  local slotInfo, ctx

  before_each(function()
    slotInfo = items:NewSlotInfo()
    ctx = context:New("SlotTest")
  end)

  -- ─── NewSlotInfo ────────────────────────────────────────────────────────────

  describe("NewSlotInfo", function()

    it("creates a SlotInfo with empty defaults", function()
      assert.are.equal(0, slotInfo.totalItems)
      assert.same({}, slotInfo.emptySlots)
      assert.same({}, slotInfo.itemsBySlotKey)
      assert.same({}, slotInfo.addedItems)
      assert.same({}, slotInfo.removedItems)
      assert.same({}, slotInfo.updatedItems)
      assert.is_false(slotInfo.deferDelete)
    end)

    it("creates independent instances", function()
      local slotInfo2 = items:NewSlotInfo()
      slotInfo.totalItems = 5
      assert.are.equal(0, slotInfo2.totalItems)
    end)
  end)

  -- ─── Update ─────────────────────────────────────────────────────────────────

  describe("Update", function()

    it("stores new items and resets changeset", function()
      local item1 = MockData.ItemData({slotkey = "s1", name = "Sword"})
      local item2 = MockData.ItemData({slotkey = "s2", name = "Shield"})
      slotInfo:Update(ctx, {s1 = item1, s2 = item2})
      assert.are.equal(item1, slotInfo.itemsBySlotKey["s1"])
      assert.are.equal(item2, slotInfo.itemsBySlotKey["s2"])
      assert.same({}, slotInfo.addedItems)
      assert.same({}, slotInfo.removedItems)
    end)

    it("preserves previous items for changeset comparison", function()
      local item1 = MockData.ItemData({slotkey = "s1", name = "Sword"})
      slotInfo:Update(ctx, {s1 = item1})
      local item2 = MockData.ItemData({slotkey = "s1", name = "Axe"})
      slotInfo:Update(ctx, {s1 = item2})
      assert.are.equal(item2, slotInfo.itemsBySlotKey["s1"])
      assert.are.equal(item1, slotInfo.previousItemsBySlotKey["s1"])
    end)

    it("calls Wipe when context has wipe=true", function()
      local item = MockData.ItemData({slotkey = "s1"})
      slotInfo:Update(ctx, {s1 = item})
      slotInfo.totalItems = 10

      local wipeCtx = context:New("WipeTest")
      wipeCtx:Set("wipe", true)
      slotInfo:Update(wipeCtx, {})
      -- After wipe, previousItemsBySlotKey should be empty (wiped before being set)
      assert.same({}, slotInfo.previousItemsBySlotKey)
    end)

    it("resets tracking fields on each update", function()
      slotInfo.deferDelete = true
      slotInfo:Update(ctx, {})
      assert.is_false(slotInfo.deferDelete)
      assert.same({}, slotInfo.dirtyItems)
      assert.same({}, slotInfo.emptySlotsSorted)
    end)
  end)

  -- ─── Changeset tracking ─────────────────────────────────────────────────────

  describe("Changeset tracking", function()

    it("tracks added items", function()
      local item = MockData.ItemData({slotkey = "s1", name = "Sword", itemHash = "h1", count = 5})
      slotInfo:AddToAddedItems(item)
      assert.are.equal(item, slotInfo.addedItems["s1"])
    end)

    it("tracks removed items", function()
      local item = MockData.ItemData({slotkey = "s1", name = "Sword", itemHash = "h1"})
      slotInfo:AddToRemovedItems(item)
      assert.are.equal(item, slotInfo.removedItems["s1"])
    end)

    it("tracks updated items", function()
      local oldItem = MockData.ItemData({slotkey = "s1", name = "Sword", itemHash = "h1", count = 1})
      local newItem = MockData.ItemData({slotkey = "s1", name = "Sword", itemHash = "h1", count = 5})
      slotInfo:AddToUpdatedItems(oldItem, newItem)
      assert.are.equal(newItem, slotInfo.updatedItems["s1"])
    end)

    it("returns changeset via GetChangeset", function()
      local added = MockData.ItemData({slotkey = "a1", name = "Added", itemHash = "ha"})
      local removed = MockData.ItemData({slotkey = "r1", name = "Removed", itemHash = "hr"})
      slotInfo:AddToAddedItems(added)
      slotInfo:AddToRemovedItems(removed)
      local a, r, u = slotInfo:GetChangeset()
      assert.are.equal(added, a["a1"])
      assert.are.equal(removed, r["r1"])
      assert.same({}, u)
    end)

    it("ignores nil items in AddToAddedItems", function()
      slotInfo:AddToAddedItems(nil) -- should not error
      assert.same({}, slotInfo.addedItems)
    end)

    it("ignores items without slotkey in AddToRemovedItems", function()
      slotInfo:AddToRemovedItems({}) -- no slotkey
      assert.same({}, slotInfo.removedItems)
    end)
  end)

  -- ─── Empty slot management ──────────────────────────────────────────────────

  describe("Empty slot management", function()

    it("stores empty slots by bag and slot", function()
      local empty = MockData.EmptySlot({bagid = 1, slotid = 3, slotkey = "bag:1:slot:3"})
      slotInfo:StoreIfEmptySlot("Backpack", empty)
      assert.are.equal(empty, slotInfo.emptySlotByBagAndSlot[1][3])
    end)

    it("stores free slot key by bag name", function()
      local empty = MockData.EmptySlot({bagid = 0, slotid = 1, slotkey = "bag:0:slot:1"})
      slotInfo:StoreIfEmptySlot("Backpack", empty)
      assert.are.equal("bag:0:slot:1", slotInfo.freeSlotKeys["Backpack"])
    end)

    it("adds empty slots to the sorted list", function()
      local empty = MockData.EmptySlot({bagid = 0, slotid = 1, slotkey = "bag:0:slot:1"})
      slotInfo:StoreIfEmptySlot("Backpack", empty)
      assert.are.equal(1, #slotInfo.emptySlotsSorted)
    end)

    it("does NOT store non-empty items", function()
      local item = MockData.ItemData({bagid = 0, slotid = 1, slotkey = "bag:0:slot:1"})
      slotInfo:StoreIfEmptySlot("Backpack", item)
      assert.same({}, slotInfo.emptySlotByBagAndSlot)
    end)

    it("sorts empty slots by bag then slot", function()
      slotInfo:StoreIfEmptySlot("a", MockData.EmptySlot({bagid = 2, slotid = 1, slotkey = "b2s1"}))
      slotInfo:StoreIfEmptySlot("b", MockData.EmptySlot({bagid = 0, slotid = 3, slotkey = "b0s3"}))
      slotInfo:StoreIfEmptySlot("c", MockData.EmptySlot({bagid = 0, slotid = 1, slotkey = "b0s1"}))
      slotInfo:SortEmptySlots()
      assert.are.equal("b0s1", slotInfo.emptySlotsSorted[1].slotkey)
      assert.are.equal("b0s3", slotInfo.emptySlotsSorted[2].slotkey)
      assert.are.equal("b2s1", slotInfo.emptySlotsSorted[3].slotkey)
    end)
  end)

  -- ─── Lookup ─────────────────────────────────────────────────────────────────

  describe("Lookup", function()

    it("finds current item by bag and slot", function()
      local item = MockData.ItemData({slotkey = "bag:1:slot:5"})
      slotInfo.itemsBySlotKey["bag:1:slot:5"] = item
      local found = slotInfo:GetCurrentItemByBagAndSlot(1, 5)
      assert.are.equal(item, found)
    end)

    it("returns nil for missing current item", function()
      assert.is_nil(slotInfo:GetCurrentItemByBagAndSlot(99, 99))
    end)

    it("finds previous item by bag and slot", function()
      local item = MockData.ItemData({slotkey = "bag:2:slot:3"})
      slotInfo.previousItemsBySlotKey["bag:2:slot:3"] = item
      local found = slotInfo:GetPreviousItemByBagAndSlot(2, 3)
      assert.are.equal(item, found)
    end)

    it("GetCurrentItems returns the itemsBySlotKey table", function()
      local item = MockData.ItemData({slotkey = "s1"})
      slotInfo.itemsBySlotKey["s1"] = item
      assert.are.equal(item, slotInfo:GetCurrentItems()["s1"])
    end)
  end)

  -- ─── Wipe ───────────────────────────────────────────────────────────────────

  describe("Wipe", function()

    it("clears all data", function()
      slotInfo.totalItems = 10
      slotInfo.itemsBySlotKey["s1"] = MockData.ItemData({slotkey = "s1"})
      slotInfo.addedItems["s1"] = MockData.ItemData({slotkey = "s1"})
      slotInfo:Wipe()
      assert.are.equal(0, slotInfo.totalItems)
      assert.same({}, slotInfo.itemsBySlotKey)
      assert.same({}, slotInfo.addedItems)
      assert.same({}, slotInfo.removedItems)
      assert.is_false(slotInfo.deferDelete)
    end)
  end)
end)
