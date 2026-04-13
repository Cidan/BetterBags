-- bucket_spec.lua -- Unit tests for util/bucket.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
LoadBetterBagsModule("util/bucket.lua")
local bucket = addon:GetModule("Bucket")

describe("Bucket", function()

  -- Capture C_Timer.After callbacks so we can fire them manually
  local timerCallbacks

  before_each(function()
    timerCallbacks = {}
    _G.C_Timer.After = function(delay, callback)
      table.insert(timerCallbacks, {delay = delay, callback = callback})
    end
    -- Simulate OnInitialize (Ace modules call this on enable)
    bucket.bucketsFunctions = {}
  end)

  after_each(function()
    -- Restore the no-op mock
    _G.C_Timer.After = function() end
  end)

  local function fireAllTimers()
    for _, timer in ipairs(timerCallbacks) do
      timer.callback()
    end
    timerCallbacks = {}
  end

  -- ─── Later ──────────────────────────────────────────────────────────────────

  describe("Later", function()

    it("schedules a function for later execution", function()
      local called = false
      bucket:Later("test", 0.5, function() called = true end)
      assert.is_false(called)
      fireAllTimers()
      assert.is_true(called)
    end)

    it("passes the correct delay to C_Timer.After", function()
      bucket:Later("test", 1.5, function() end)
      assert.are.equal(1, #timerCallbacks)
      assert.are.equal(1.5, timerCallbacks[1].delay)
    end)

    it("debounces: ignores duplicate calls with the same name", function()
      local callCount = 0
      bucket:Later("test", 0.5, function() callCount = callCount + 1 end)
      bucket:Later("test", 0.5, function() callCount = callCount + 10 end)
      -- Only the first should be scheduled
      assert.are.equal(1, #timerCallbacks)
      fireAllTimers()
      assert.are.equal(1, callCount)
    end)

    it("allows different names to coexist", function()
      local results = {}
      bucket:Later("a", 0.5, function() table.insert(results, "a") end)
      bucket:Later("b", 0.5, function() table.insert(results, "b") end)
      assert.are.equal(2, #timerCallbacks)
      fireAllTimers()
      table.sort(results)
      assert.same({"a", "b"}, results)
    end)

    it("clears the bucket entry after the timer fires", function()
      bucket:Later("test", 0.5, function() end)
      assert.is_not_nil(bucket.bucketsFunctions["test"])
      fireAllTimers()
      assert.is_nil(bucket.bucketsFunctions["test"])
    end)

    it("allows re-scheduling after the timer fires", function()
      local callCount = 0
      bucket:Later("test", 0.5, function() callCount = callCount + 1 end)
      fireAllTimers()
      assert.are.equal(1, callCount)
      -- Now schedule again with the same name
      bucket:Later("test", 0.5, function() callCount = callCount + 1 end)
      fireAllTimers()
      assert.are.equal(2, callCount)
    end)

    it("stores the function metadata while pending", function()
      local fn = function() end
      bucket:Later("myFunc", 2.0, fn)
      local entry = bucket.bucketsFunctions["myFunc"]
      assert.is_not_nil(entry)
      assert.are.equal("myFunc", entry.name)
      assert.are.equal(2.0, entry.delay)
      assert.are.equal(fn, entry.func)
    end)
  end)
end)
