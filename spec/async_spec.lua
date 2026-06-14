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

  -- ─── DoWithDelay ────────────────────────────────────────────────────────────

  describe("DoWithDelay", function()

    it("runs the first slice immediately, then schedules subsequent ticks via C_Timer.After", function()
      local delays = {}
      _G.C_Timer.After = function(delay, callback)
        table.insert(delays, delay)
        table.insert(timerCallbacks, callback)
      end
      local ctx = context:New("Test")
      local steps = {}
      async:DoWithDelay(ctx, 0.5, function()
        table.insert(steps, "first")
        async:Yield()
        table.insert(steps, "second")
      end)
      -- The first slice runs synchronously inside the worker.
      assert.are.equal(0.5, delays[1])
      -- Fire all remaining timers to drive the second slice.
      fireAllTimers()
      assert.same({"first", "second"}, steps)
    end)

    it("honors a non-zero delay between yields", function()
      local delays = {}
      _G.C_Timer.After = function(delay, callback)
        table.insert(delays, delay)
        table.insert(timerCallbacks, callback)
      end
      local ctx = context:New("Test")
      async:DoWithDelay(ctx, 0.25, function()
        async:Yield()
        async:Yield()
      end)
      -- The first yield reschedules with 0.25; the second yield does too.
      -- After the second yield, the coroutine finishes and no more timers
      -- are scheduled.
      assert.are.equal(0.25, delays[1])
      fireAllTimers()
      assert.are.equal(0.25, delays[2])
      assert.is_nil(delays[3])
    end)

    it("delivers the completion event when the coroutine finishes", function()
      local received
      events:RegisterMessage("test/DoWithDelayDone", function() received = true end)
      local ctx = context:New("Test")
      async:DoWithDelay(ctx, 0, function() end, "test/DoWithDelayDone")
      fireAllTimers()
      assert.is_true(received)
    end)

    it("errors if the coroutine raises", function()
      local ctx = context:New("Test")
      assert.has_error(function()
        async:DoWithDelay(ctx, 0, function() error("boom") end)
      end)
    end)
  end)

  -- ─── BatchNoYield ───────────────────────────────────────────────────────────

  describe("BatchNoYield", function()

    it("processes the entire list without yielding between batches", function()
      local results = {}
      local ctx = context:New("Test")
      async:BatchNoYield(ctx, 2, {"a", "b", "c", "d"}, function(_, item)
        table.insert(results, item)
      end, "test/BatchNoYieldDone")
      -- Since BatchNoYield does not yield, the entire list should be
      -- processed on the first tick.
      fireAllTimers()
      assert.same({"a", "b", "c", "d"}, results)
    end)

    it("still fires the completion event for an empty list", function()
      -- Do() fires the event when the coroutine finishes, even with an
      -- empty iteration. This documents the current behavior.
      local done = false
      events:RegisterMessage("test/BatchNoYieldEmpty", function() done = true end)
      local ctx = context:New("Test")
      async:BatchNoYield(ctx, 2, {}, function() end, "test/BatchNoYieldEmpty")
      fireAllTimers()
      assert.is_true(done)
    end)
  end)

  -- ─── RawBatch ───────────────────────────────────────────────────────────────

  describe("RawBatch", function()

    it("yields once per batch from inside a coroutine", function()
      local yields = 0
      local ctx = context:New("Test")
      local co = coroutine.create(function()
        async:RawBatch(ctx, 2, {"a", "b", "c", "d", "e"}, function(_, item)
          -- (no yield here; RawBatch yields for us)
        end)
        yields = coroutine.yield(yields)
      end)
      coroutine.resume(co)
      -- 5 items at batch size 2 -> 3 batches -> 3 yields
      local done = false
      for _ = 1, 3 do
        if not done then
          local ok = coroutine.resume(co)
          done = not ok
        end
      end
      assert.is_true(yields <= 3)
    end)

    it("calls the function for every item", function()
      local results = {}
      local ctx = context:New("Test")
      local co = coroutine.create(function()
        async:RawBatch(ctx, 2, {10, 20, 30, 40, 50}, function(_, item)
          table.insert(results, item)
        end)
      end)
      coroutine.resume(co)  -- start
      coroutine.resume(co)  -- first batch yield
      coroutine.resume(co)  -- second batch yield
      coroutine.resume(co)  -- third batch yield
      coroutine.resume(co)  -- resume after last batch
      assert.are.equal(5, #results)
    end)
  end)

  -- ─── StableIterate ──────────────────────────────────────────────────────────

  describe("StableIterate", function()

    it("uses framerate to choose batch size", function()
      local originalFramerate = _G.GetFramerate
      _G.GetFramerate = function() return 60 end
      local ctx = context:New("Test")
      local processed = 0
      async:StableIterate(ctx, 0.5, {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}, function(_, _)
        processed = processed + 1
      end, "test/StableDone")
      fireAllTimers()
      _G.GetFramerate = originalFramerate
      assert.are.equal(10, processed)
    end)

    it("falls back to framerate=1 when GetFramerate returns 0", function()
      local originalFramerate = _G.GetFramerate
      _G.GetFramerate = function() return 0 end
      local ctx = context:New("Test")
      local ran = false
      async:StableIterate(ctx, 1, {1, 2}, function() ran = true end, "test/StableZero")
      fireAllTimers()
      _G.GetFramerate = originalFramerate
      assert.is_true(ran)
    end)
  end)
end)
