-- async_spec.lua -- Unit tests for core/async.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")

local context = addon:GetModule("Context")
local events = addon:GetModule("Events")
events:OnInitialize()

LoadBetterBagsModule("core/async.lua")
local async = addon:GetModule("Async")

describe("Async", function()

  -- Capture C_Timer.After callbacks for manual firing
  local timerCallbacks

  before_each(function()
    timerCallbacks = {}
    _G.C_Timer.After = function(_, callback)
      table.insert(timerCallbacks, callback)
    end
    async:OnInitialize()
  end)

  after_each(function()
    _G.C_Timer.After = function() end
  end)

  local function fireAllTimers()
    -- Fire timers iteratively (timers can schedule more timers)
    local maxIterations = 100
    local iteration = 0
    while #timerCallbacks > 0 and iteration < maxIterations do
      local batch = timerCallbacks
      timerCallbacks = {}
      for _, cb in ipairs(batch) do
        cb()
      end
      iteration = iteration + 1
    end
  end

  -- ─── Do ─────────────────────────────────────────────────────────────────────

  describe("Do", function()

    it("runs a simple function immediately", function()
      local ran = false
      local ctx = context:New("Test")
      async:Do(ctx, function() ran = true end)
      assert.is_true(ran)
    end)

    it("fires a string event on completion", function()
      local received = false
      events:RegisterMessage("test/AsyncDone", function() received = true end)
      local ctx = context:New("Test")
      async:Do(ctx, function() end, "test/AsyncDone")
      assert.is_true(received)
    end)

    it("calls a callback function on completion", function()
      local callbackRan = false
      local ctx = context:New("Test")
      async:Do(ctx, function() end, function() callbackRan = true end)
      assert.is_true(callbackRan)
    end)

    it("resumes coroutine after yield via C_Timer", function()
      local steps = {}
      local ctx = context:New("Test")
      async:Do(ctx, function()
        table.insert(steps, "before")
        async:Yield()
        table.insert(steps, "after")
      end)
      assert.same({"before"}, steps)
      fireAllTimers()
      assert.same({"before", "after"}, steps)
    end)
  end)

  -- ─── Each ───────────────────────────────────────────────────────────────────

  describe("Each", function()

    it("processes each item in the list", function()
      local results = {}
      local ctx = context:New("Test")
      async:Each(ctx, {"a", "b", "c"}, function(_, item)
        table.insert(results, item)
      end, "test/EachDone")
      -- First item is processed immediately, rest need timer ticks
      fireAllTimers()
      assert.same({"a", "b", "c"}, results)
    end)

    it("passes index to the callback", function()
      local indices = {}
      local ctx = context:New("Test")
      async:Each(ctx, {"x", "y"}, function(_, _, index)
        table.insert(indices, index)
      end, "test/EachIdx")
      fireAllTimers()
      assert.same({1, 2}, indices)
    end)
  end)

  -- ─── Batch ──────────────────────────────────────────────────────────────────

  describe("Batch", function()

    it("processes items in batches", function()
      local results = {}
      local ctx = context:New("Test")
      async:Batch(ctx, 2, {"a", "b", "c", "d", "e"}, function(_, item)
        table.insert(results, item)
      end, "test/BatchDone")
      fireAllTimers()
      assert.same({"a", "b", "c", "d", "e"}, results)
    end)

    it("handles batch size larger than list", function()
      local results = {}
      local ctx = context:New("Test")
      async:Batch(ctx, 100, {"a", "b"}, function(_, item)
        table.insert(results, item)
      end, "test/BatchBig")
      fireAllTimers()
      assert.same({"a", "b"}, results)
    end)

    it("handles empty list", function()
      local called = false
      local ctx = context:New("Test")
      async:Batch(ctx, 2, {}, function()
        called = true
      end, "test/BatchEmpty")
      fireAllTimers()
      assert.is_false(called)
    end)
  end)

  -- ─── Until ──────────────────────────────────────────────────────────────────

  describe("Until", function()

    it("loops until condition is true", function()
      local count = 0
      local ctx = context:New("Test")
      async:Until(ctx, function()
        count = count + 1
        return count >= 3
      end, "test/UntilDone")
      fireAllTimers()
      assert.are.equal(3, count)
    end)
  end)

  -- ─── AfterCombat ────────────────────────────────────────────────────────────

  describe("AfterCombat", function()

    it("runs immediately when not in combat", function()
      _G.InCombatLockdown = function() return false end
      local ran = false
      local ctx = context:New("Test")
      async:AfterCombat(ctx, function() ran = true end)
      assert.is_true(ran)
    end)

    it("defers when in combat", function()
      _G.InCombatLockdown = function() return true end
      local ran = false
      local ctx = context:New("Test")
      async:AfterCombat(ctx, function() ran = true end)
      assert.is_false(ran)
      assert.are.equal(1, #async.AfterCombatCallbacks)
    end)
  end)

  -- ─── Chain ──────────────────────────────────────────────────────────────────

  describe("Chain", function()

    it("executes functions in sequence", function()
      local order = {}
      local ctx = context:New("Test")
      async:Chain(ctx, "test/ChainDone",
        function() table.insert(order, 1) end,
        function() table.insert(order, 2) end,
        function() table.insert(order, 3) end
      )
      fireAllTimers()
      assert.same({1, 2, 3}, order)
    end)
  end)

  -- ─── Yield ──────────────────────────────────────────────────────────────────

  describe("Yield", function()

    it("yields the current coroutine", function()
      local co = coroutine.create(function()
        async:Yield()
      end)
      coroutine.resume(co)
      assert.are.equal("suspended", coroutine.status(co))
    end)
  end)
end)
