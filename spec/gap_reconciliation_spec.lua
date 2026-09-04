-- gap_reconciliation_spec.lua -- Unit tests for items:BuildOrderedItems, the data-side
-- diff that holds a persistent empty gap wherever a displayed icon has left the bag.
--
-- These tests drive the real Items module with stubbed dependencies and call
-- items:BuildOrderedItems directly with hand-built previous-layout / current-sweep
-- inputs, asserting on the returned ordered list (items + isItemGap placeholders).
--
-- Module/global state is saved and restored per-test (mirroring refresh_pipeline_spec.lua)
-- so this file never leaks stubs or field mutations into other spec files.

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local BACKPACK, BANK = 0, 1
local SECTION_GRID, SECTION_ALL_BAGS = 2, 4

local currentBagView = SECTION_GRID
local preserveGaps = true

local overrides = {}
local function override(tbl, key, value)
  table.insert(overrides, { tbl = tbl, key = key, original = tbl[key] })
  tbl[key] = value
end
local function restoreOverrides()
  for i = #overrides, 1, -1 do
    local o = overrides[i]
    o.tbl[o.key] = o.original
  end
  overrides = {}
end

local createdStubs = {}
local function stubModule(name)
  local mod, created = _G.StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end
local function resetCreatedStubs()
  for i = #createdStubs, 1, -1 do
    ResetModuleStub(createdStubs[i])
  end
  createdStubs = {}
end

-- Deterministic comparator over ItemData for the "append new items" path and the
-- fresh-sort fallback: order by slotkey ascending.
local function bySlotkey(a, b)
  if a.isItemGap or a.isFreeSlot then return false end
  if b.isItemGap or b.isFreeSlot then return true end
  return tostring(a.slotkey) < tostring(b.slotkey)
end

local function fakeCtx(vals)
  vals = vals or {}
  return {
    Get = function(_, key) return vals[key] end,
    Set = function(_, key, value) vals[key] = value end,
  }
end

--- Build an ItemData-like node.
local function mkItem(slotkey, hash, category, opts)
  opts = opts or {}
  local bagid = tonumber(tostring(slotkey):match("^(%-?%d+)_")) or 0
  return {
    slotkey = slotkey,
    itemHash = hash,
    bagid = bagid,
    kind = opts.kind or BACKPACK,
    itemInfo = {
      category = category,
      itemName = opts.name or slotkey,
      itemGUID = opts.guid or ("guid-" .. slotkey),
      currentItemCount = opts.count or 1,
      itemQuality = opts.quality or 1,
      currentItemLevel = opts.ilvl or 1,
      expacID = 0,
    },
  }
end

--- Turn an array of items into the visibleItemsBySlotKey map keyed by slotkey.
local function toVisible(list)
  local map = {}
  for _, item in ipairs(list) do
    map[item.slotkey] = item
  end
  return map
end

local function countGaps(result)
  local n = 0
  for _, e in ipairs(result) do
    if e.isItemGap then n = n + 1 end
  end
  return n
end

describe("items:BuildOrderedItems (persistent gap reconciliation)", function()
  local items
  local markCalls

  before_each(function()
    currentBagView = SECTION_GRID
    preserveGaps = true
    markCalls = {}

    stubModule("Events")
    local const = stubModule("Constants")
    override(const, "BAG_KIND", { UNDEFINED = -1, BACKPACK = BACKPACK, BANK = BANK })
    override(const, "BAG_VIEW", { UNDEFINED = 0, SECTION_GRID = SECTION_GRID, SECTION_ALL_BAGS = SECTION_ALL_BAGS })
    override(const, "BACKPACK_BAGS", { [0] = 0, [1] = 1 })
    override(const, "BANK_BAGS", { [6] = 6, [7] = 7 })
    override(const, "ACCOUNT_BANK_BAGS", { [13] = 13 })
    stubModule("EquipmentSets")
    stubModule("Categories")
    local database = stubModule("Database")
    override(database, "GetBagView", function(_, _) return currentBagView end)
    override(database, "GetPreserveItemGaps", function(_, _) return preserveGaps end)
    stubModule("Context")
    stubModule("Search")
    local L = stubModule("Localization")
    override(L, "G", function(_, key) return key end)
    stubModule("Binding")
    stubModule("Async")
    local sort = stubModule("Sort")
    override(sort, "GetItemDataSortFunction", function() return bySlotkey end)
    override(sort, "SortItemDataBySlot", function(a, b)
      if not a then return false end
      if not b then return true end
      if a.bagid ~= b.bagid then return a.bagid < b.bagid end
      return (a.slotid or 0) < (b.slotid or 0)
    end)

    _G.C_Container = _G.C_Container or {}
    override(_G.C_Container, "GetBagName", function() return nil end)

    ResetModuleStub("Items", "data/items.lua")
    LoadBetterBagsModule("data/items.lua")
    items = addon:GetModule("Items")

    -- The diff only produces gaps while the bag is open; force that in unit tests,
    -- and capture MarkDrawOnClose calls.
    override(items, "IsBagOpen", function() return true end)
    override(items, "MarkDrawOnClose", function(_, kind) table.insert(markCalls, kind) end)
  end)

  after_each(function()
    ResetModuleStub("Items", "data/items.lua")
    restoreOverrides()
    resetCreatedStubs()
  end)

  it("holds a gap in place when a single item is removed", function()
    local A = mkItem("0_0", "H_A", "Cat")
    local B = mkItem("0_1", "H_B", "Cat")
    local C = mkItem("0_2", "H_C", "Cat")
    local prev = { A, B, C }
    local cur = toVisible({ A, C })

    local result = items:BuildOrderedItems(fakeCtx(), BACKPACK, cur, {}, prev)

    assert.equal(3, #result)
    assert.equal(A, result[1])
    assert.is_true(result[2].isItemGap == true)
    assert.equal("gap:0_1", result[2].slotkey)
    assert.equal("Cat", result[2].itemInfo.category)
    assert.equal(C, result[3])
  end)

  it("turns an entire consumed category into gaps, preserving order", function()
    local A = mkItem("0_0", "H_A", "Cat")
    local B = mkItem("0_1", "H_B", "Cat")
    local prev = { A, B }
    local result = items:BuildOrderedItems(fakeCtx(), BACKPACK, toVisible({}), {}, prev)

    assert.equal(2, #result)
    assert.is_true(result[1].isItemGap == true)
    assert.equal("gap:0_0", result[1].slotkey)
    assert.is_true(result[2].isItemGap == true)
    assert.equal("gap:0_1", result[2].slotkey)
  end)

  it("rekeys a moved same-hash item in place with no gap", function()
    local A = mkItem("0_0", "H_A", "Cat", { guid = "g" })
    local prev = { A }
    local Amoved = mkItem("0_5", "H_A", "Cat", { guid = "g" })
    local result = items:BuildOrderedItems(fakeCtx(), BACKPACK, toVisible({ Amoved }), {}, prev)

    assert.equal(1, #result)
    assert.equal(Amoved, result[1])
    assert.equal(0, countGaps(result))
  end)

  it("does not gap on a virtual-stack re-root (root slot vanishes, sibling survives)", function()
    local root = mkItem("0_5", "H", "Cat", { guid = "g1", count = 40 })
    local prev = { root }
    local newRoot = mkItem("0_8", "H", "Cat", { guid = "g2", count = 20 })
    local result = items:BuildOrderedItems(fakeCtx(), BACKPACK, toVisible({ newRoot }), {}, prev)

    assert.equal(1, #result)
    assert.equal(newRoot, result[1])
    assert.equal(0, countGaps(result))
  end)

  it("does not gap on a partial consume that keeps the same root", function()
    local before = mkItem("0_5", "H", "Cat", { count = 20 })
    local prev = { before }
    local after = mkItem("0_5", "H", "Cat", { count = 12 })
    local result = items:BuildOrderedItems(fakeCtx(), BACKPACK, toVisible({ after }), {}, prev)

    assert.equal(1, #result)
    assert.equal(after, result[1])
    assert.equal(0, countGaps(result))
  end)

  it("gaps exactly one of N unmerged stacks of the same hash", function()
    local S1 = mkItem("0_5", "H", "Cat", { guid = "s1" })
    local S2 = mkItem("0_6", "H", "Cat", { guid = "s2" })
    local S3 = mkItem("0_7", "H", "Cat", { guid = "s3" })
    local prev = { S1, S2, S3 }
    local result = items:BuildOrderedItems(fakeCtx(), BACKPACK, toVisible({ S1, S3 }), {}, prev)

    assert.equal(3, #result)
    assert.equal(1, countGaps(result))
    assert.equal(S1, result[1])
    assert.is_true(result[2].isItemGap == true)
    assert.equal("gap:0_6", result[2].slotkey)
    assert.equal(S3, result[3])
  end)

  it("appends genuinely new items after held gaps", function()
    local A = mkItem("0_0", "H_A", "Cat")
    local C = mkItem("0_2", "H_C", "Cat")
    local prevGap = { isItemGap = true, slotkey = "gap:0_1", bagid = 0, itemHash = "H_B",
      itemInfo = { category = "Cat" } }
    local prev = { A, prevGap, C }
    local NEW = mkItem("0_9", "H_N", "Cat")
    local result = items:BuildOrderedItems(fakeCtx(), BACKPACK, toVisible({ A, C, NEW }), {}, prev)

    assert.equal(4, #result)
    assert.equal(A, result[1])
    assert.is_true(result[2].isItemGap == true)
    assert.equal("gap:0_1", result[2].slotkey)
    assert.equal(C, result[3])
    assert.equal(NEW, result[4])
  end)

  it("keeps the gap and appends a new item that lands in the vacated physical slot", function()
    local A = mkItem("0_5", "H_A", "Cat", { guid = "gA" })
    local prev = { A }
    local X = mkItem("0_5", "H_X", "Cat", { guid = "gX" })
    local result = items:BuildOrderedItems(fakeCtx(), BACKPACK, toVisible({ X }), {}, prev)

    assert.equal(2, #result)
    assert.is_true(result[1].isItemGap == true)
    assert.equal("gap:0_5", result[1].slotkey)
    assert.equal(X, result[2])
  end)

  it("re-emits existing gaps unchanged across refreshes", function()
    local A = mkItem("0_0", "H_A", "Cat")
    local C = mkItem("0_2", "H_C", "Cat")
    local first = items:BuildOrderedItems(fakeCtx(), BACKPACK, toVisible({ A, C }),
      {}, { A, mkItem("0_1", "H_B", "Cat"), C })
    local second = items:BuildOrderedItems(fakeCtx(), BACKPACK, toVisible({ A, C }), {}, first)
    assert.equal(3, #second)
    assert.is_true(second[2].isItemGap == true)
    assert.equal("gap:0_1", second[2].slotkey)
  end)

  it("marks drawOnClose only when a gap is emitted", function()
    local A = mkItem("0_0", "H_A", "Cat")
    local B = mkItem("0_1", "H_B", "Cat")
    items:BuildOrderedItems(fakeCtx(), BACKPACK, toVisible({ A, B }), {}, { A, B })
    assert.equal(0, #markCalls)

    items:BuildOrderedItems(fakeCtx(), BACKPACK, toVisible({ A }), {}, { A, B })
    assert.equal(1, #markCalls)
    assert.equal(BACKPACK, markCalls[1])
  end)

  it("does a fresh gapless sort when resetLayout is set", function()
    local A = mkItem("0_0", "H_A", "Cat")
    local B = mkItem("0_1", "H_B", "Cat")
    local result = items:BuildOrderedItems(fakeCtx({ resetLayout = true }), BACKPACK,
      toVisible({ A }), {}, { A, B })
    assert.equal(1, #result)
    assert.equal(0, countGaps(result))
    assert.equal(A, result[1])
  end)

  it("does a fresh gapless sort when the option is off", function()
    preserveGaps = false
    local A = mkItem("0_0", "H_A", "Cat")
    local B = mkItem("0_1", "H_B", "Cat")
    local result = items:BuildOrderedItems(fakeCtx(), BACKPACK, toVisible({ A }), {}, { A, B })
    assert.equal(1, #result)
    assert.equal(0, countGaps(result))
  end)

  it("does a fresh gapless sort when the bag is closed", function()
    override(items, "IsBagOpen", function() return false end)
    local A = mkItem("0_0", "H_A", "Cat")
    local B = mkItem("0_1", "H_B", "Cat")
    local result = items:BuildOrderedItems(fakeCtx(), BACKPACK, toVisible({ A }), {}, { A, B })
    assert.equal(1, #result)
    assert.equal(0, countGaps(result))
  end)

  it("does a fresh gapless sort when there is no previous layout", function()
    local A = mkItem("0_1", "H_A", "Cat")
    local B = mkItem("0_0", "H_B", "Cat")
    local result = items:BuildOrderedItems(fakeCtx(), BACKPACK, toVisible({ A, B }), {}, {})
    assert.equal(2, #result)
    assert.equal(0, countGaps(result))
    assert.equal(B, result[1])
    assert.equal(A, result[2])
  end)

  it("delegates to a fresh sort (no gaps) in the physical bag view", function()
    currentBagView = SECTION_ALL_BAGS
    local A = mkItem("0_0", "H_A", "Cat")
    local prev = { A, mkItem("0_1", "H_B", "Cat") }
    local result = items:BuildOrderedItems(fakeCtx(), BACKPACK, toVisible({ A }), {}, prev)
    assert.equal(0, countGaps(result))
  end)
end)
