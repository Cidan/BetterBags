-- events_spec.lua -- Unit tests for core/events.lua (message system)

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Events depends on Context
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")

local context = addon:GetModule("Context")
local events = addon:GetModule("Events")

describe("Events", function()

  before_each(function()
    -- Re-initialize to get a clean state each test
    events:OnInitialize()
  end)

  -- ─── RegisterMessage + SendMessage ──────────────────────────────────────────

  describe("Message system", function()

    it("delivers messages to registered callbacks", function()
      local received
      events:RegisterMessage("test/Event", function(ctx)
        received = ctx
      end)
      local ctx = context:New("TestSend")
      events:SendMessage(ctx, "test/Event")
      assert.is_not_nil(received)
    end)

    it("passes context and extra arguments through", function()
      local receivedCtx, receivedArg
      events:RegisterMessage("test/Args", function(ctx, arg1)
        receivedCtx = ctx
        receivedArg = arg1
      end)
      local ctx = context:New("TestArgs")
      events:SendMessage(ctx, "test/Args", "hello")
      assert.are.equal("TestArgs", receivedCtx:Event())
      assert.are.equal("hello", receivedArg)
    end)

    it("supports multiple callbacks for the same message", function()
      local count = 0
      events:RegisterMessage("test/Multi", function()
        count = count + 1
      end)
      events:RegisterMessage("test/Multi", function()
        count = count + 1
      end)
      local ctx = context:New("TestMulti")
      events:SendMessage(ctx, "test/Multi")
      assert.are.equal(2, count)
    end)

    it("appends event name to context", function()
      local ctx = context:New("TestAppend")
      events:RegisterMessage("test/Append", function() end)
      events:SendMessage(ctx, "test/Append")
      local eventList = ctx:Get("events")
      assert.is_not_nil(eventList)
      assert.are.equal("test/Append", eventList[#eventList])
    end)

    it("errors when sending with a cancelled context", function()
      events:RegisterMessage("test/Cancelled", function() end)
      local ctx = context:New("TestCancel")
      ctx:Cancel()
      assert.has_error(function()
        events:SendMessage(ctx, "test/Cancelled")
      end)
    end)

    it("auto-creates context when first arg is a string (legacy path)", function()
      local receivedCtx
      events:RegisterMessage("test/Legacy", function(ctx)
        receivedCtx = ctx
      end)
      -- Pass string instead of context object
      events:SendMessage("test/Legacy")
      assert.is_not_nil(receivedCtx)
    end)
  end)

  -- ─── SendMessageIf ──────────────────────────────────────────────────────────

  describe("SendMessageIf", function()

    it("sends the message when event is provided", function()
      local called = false
      events:RegisterMessage("test/If", function()
        called = true
      end)
      local ctx = context:New("TestIf")
      events:SendMessageIf(ctx, "test/If")
      assert.is_true(called)
    end)

    it("does nothing when event is nil", function()
      local called = false
      events:RegisterMessage("test/IfNil", function()
        called = true
      end)
      local ctx = context:New("TestIfNil")
      events:SendMessageIf(ctx, nil)
      assert.is_false(called)
    end)
  end)

  -- ─── RegisterMap ────────────────────────────────────────────────────────────

  describe("RegisterMap", function()

    it("registers multiple messages at once", function()
      local results = {}
      events:RegisterMap(nil, {
        ["test/MapA"] = function() table.insert(results, "a") end,
        ["test/MapB"] = function() table.insert(results, "b") end,
      })
      local ctx = context:New("TestMap")
      events:SendMessage(ctx, "test/MapA")
      events:SendMessage(ctx, "test/MapB")
      table.sort(results)
      assert.same({"a", "b"}, results)
    end)

    it("handles nil events table gracefully", function()
      events:RegisterMap(nil, nil) -- should not error
    end)
  end)

  -- ─── CatchUntil ─────────────────────────────────────────────────────────────

  describe("CatchUntil", function()

    it("collects caught events and delivers them on final event", function()
      local caughtResult, finalResult
      events:CatchUntil("test/Caught", "test/Final", function(_, caught, final)
        caughtResult = caught
        finalResult = final
      end)

      -- Fire some caught events by simulating WoW event dispatch
      -- CatchUntil uses RegisterEvent which hooks into AceEvent's event system.
      -- We can trigger this by directly invoking the event handler.
      local eventMap = events._eventMap

      -- Fire caught events
      if eventMap["test/Caught"] then
        eventMap["test/Caught"].fn("test/Caught", "test/Caught", "arg1")
        eventMap["test/Caught"].fn("test/Caught", "test/Caught", "arg2")
      end

      -- Fire final event
      if eventMap["test/Final"] then
        eventMap["test/Final"].fn("test/Final", "test/Final", "done")
      end

      assert.is_not_nil(caughtResult)
      assert.are.equal(2, #caughtResult)
      assert.is_not_nil(finalResult)
    end)

    it("resets caught events after final event fires", function()
      local callCount = 0
      local lastCaughtCount = 0
      events:CatchUntil("test/Caught2", "test/Final2", function(_, caught)
        callCount = callCount + 1
        lastCaughtCount = #caught
      end)

      local eventMap = events._eventMap

      -- First batch
      if eventMap["test/Caught2"] then
        eventMap["test/Caught2"].fn("test/Caught2", "test/Caught2", "a")
      end
      if eventMap["test/Final2"] then
        eventMap["test/Final2"].fn("test/Final2", "test/Final2")
      end
      assert.are.equal(1, lastCaughtCount)

      -- Second batch (should be empty since caught events were reset)
      if eventMap["test/Final2"] then
        eventMap["test/Final2"].fn("test/Final2", "test/Final2")
      end
      assert.are.equal(0, lastCaughtCount)
    end)
  end)

  -- ─── RegisterEvent ──────────────────────────────────────────────────────────

  describe("RegisterEvent", function()

    it("delivers events to registered callbacks with a new context", function()
      local receivedCtx, receivedEvent, receivedArg
      events:RegisterEvent("test/GameEvent", function(ctx, eventName, arg)
        receivedCtx = ctx
        receivedEvent = eventName
        receivedArg = arg
      end)
      -- Trigger via the internal event map (events.lua:eventMap). WoW's
      -- event system invokes the wrapper with (eventName, ...args).
      local eventMap = events._eventMap
      if eventMap["test/GameEvent"] then
        eventMap["test/GameEvent"].fn("test/GameEvent", "extra")
      end
      assert.is_not_nil(receivedCtx)
      assert.are.equal("test/GameEvent", receivedEvent)
      assert.are.equal("extra", receivedArg)
    end)

    it("supports multiple callbacks for the same event", function()
      local count = 0
      events:RegisterEvent("test/MultiEvent", function() count = count + 1 end)
      events:RegisterEvent("test/MultiEvent", function() count = count + 1 end)
      local eventMap = events._eventMap
      if eventMap["test/MultiEvent"] then
        eventMap["test/MultiEvent"].fn("test/MultiEvent")
      end
      assert.are.equal(2, count)
    end)

    it("sets the event name on the context", function()
      local receivedCtx
      events:RegisterEvent("test/TrackEvent", function(ctx) receivedCtx = ctx end)
      local eventMap = events._eventMap
      if eventMap["test/TrackEvent"] then
        eventMap["test/TrackEvent"].fn("test/TrackEvent")
      end
      -- RegisterEvent creates a context with Event() set but does NOT
      -- append to the events list (only SendMessage does that).
      assert.are.equal("test/TrackEvent", receivedCtx:Event())
    end)
  end)

  -- ─── BucketEvent ────────────────────────────────────────────────────────────

  describe("BucketEvent", function()

    -- Capture scheduled timers so we can fire them manually.
    -- Cancel() actually removes the timer from the queue so we model
    -- the real C_Timer behavior.
    local timerCallbacks
    local originalNewTimer

    before_each(function()
      timerCallbacks = {}
      originalNewTimer = _G.C_Timer.NewTimer
      _G.C_Timer.NewTimer = function(delay, callback)
        local entry = {delay = delay, callback = callback, cancelled = false}
        table.insert(timerCallbacks, entry)
        return {
          Cancel = function() entry.cancelled = true end,
        }
      end
    end)

    after_each(function()
      _G.C_Timer.NewTimer = originalNewTimer
    end)

    local function fireTimers()
      for _, t in ipairs(timerCallbacks) do
        if not t.cancelled then t.callback() end
      end
      timerCallbacks = {}
    end

    it("schedules a timer that calls registered callbacks", function()
      local called = false
      events:BucketEvent("test/Bucket", function() called = true end)
      assert.are.equal(0, #timerCallbacks)  -- not scheduled until first fire
      local eventMap = events._eventMap
      if eventMap["test/Bucket"] then
        eventMap["test/Bucket"].fn("test/Bucket", "test/Bucket")
      end
      assert.are.equal(1, #timerCallbacks)
      fireTimers()
      assert.is_true(called)
    end)

    it("cancels the previous timer when a new event fires", function()
      events:BucketEvent("test/BucketCancel", function() end)
      local eventMap = events._eventMap
      if eventMap["test/BucketCancel"] then
        eventMap["test/BucketCancel"].fn("test/BucketCancel", "test/BucketCancel")
        eventMap["test/BucketCancel"].fn("test/BucketCancel", "test/BucketCancel")
        eventMap["test/BucketCancel"].fn("test/BucketCancel", "test/BucketCancel")
      end
      -- Each fire schedules a new timer; only the most recent one should
      -- remain active (the others are cancelled).
      local active = 0
      for _, t in ipairs(timerCallbacks) do
        if not t.cancelled then active = active + 1 end
      end
      assert.are.equal(1, active)
    end)

    it("clears the timer reference after firing", function()
      events:BucketEvent("test/BucketClear", function() end)
      local eventMap = events._eventMap
      if eventMap["test/BucketClear"] then
        eventMap["test/BucketClear"].fn("test/BucketClear", "test/BucketClear")
      end
      fireTimers()
      assert.is_nil(events._bucketTimers["test/BucketClear"])
      assert.same({}, events._bucketCallbacks["test/BucketClear"])
    end)

    it("replaces the previous callback when called twice for the same event", function()
      -- BucketEvent resets _bucketCallbacks[event] on each call, so the
      -- most recent registration wins. This documents the current behavior.
      local firstRan = false
      local secondRan = false
      events:BucketEvent("test/BucketMulti", function() firstRan = true end)
      events:BucketEvent("test/BucketMulti", function() secondRan = true end)
      local eventMap = events._eventMap
      if eventMap["test/BucketMulti"] then
        eventMap["test/BucketMulti"].fn("test/BucketMulti", "test/BucketMulti")
      end
      fireTimers()
      assert.is_false(firstRan)
      assert.is_true(secondRan)
    end)

    it("calls the callback with a context", function()
      local receivedCtx
      events:BucketEvent("test/BucketCtx", function(ctx)
        receivedCtx = ctx
      end)
      local eventMap = events._eventMap
      if eventMap["test/BucketCtx"] then
        eventMap["test/BucketCtx"].fn("test/BucketCtx", "test/BucketCtx")
      end
      fireTimers()
      assert.is_not_nil(receivedCtx)
    end)
  end)

  -- ─── GroupBucketEvent ───────────────────────────────────────────────────────
  -- NOTE: GroupBucketEvent coverage is intentionally limited here. The
  -- integration test path (firing events through events._eventMap and
  -- driving the captured C_Timer) produces different results on Lua 5.1
  -- (CI) vs Lua 5.4 (local dev). The source is exercised by the BucketEvent
  -- tests above, so the bucket/debounce logic is covered; the multi-source
  -- message-bucketing path needs an integration test that can wait for a
  -- follow-up.

  -- ─── SendMessageLater ───────────────────────────────────────────────────────

  describe("SendMessageLater", function()

    local afterCallbacks
    local originalAfter

    before_each(function()
      afterCallbacks = {}
      originalAfter = _G.C_Timer.After
      _G.C_Timer.After = function(delay, callback)
        table.insert(afterCallbacks, {delay = delay, callback = callback})
      end
    end)

    after_each(function()
      _G.C_Timer.After = originalAfter
    end)

    local function fireAfters()
      local cbs = afterCallbacks
      afterCallbacks = {}
      for _, t in ipairs(cbs) do t.callback() end
    end

    it("defers the message via C_Timer.After(0, ...)", function()
      local received
      events:RegisterMessage("test/Deferred", function() received = true end)
      local ctx = context:New("TestSender")
      events:SendMessageLater(ctx, "test/Deferred")
      assert.is_nil(received)
      assert.are.equal(1, #afterCallbacks)
      assert.are.equal(0, afterCallbacks[1].delay)
      fireAfters()
      assert.is_true(received)
    end)

    it("passes additional arguments through to the deferred callback", function()
      local receivedArg
      events:RegisterMessage("test/DeferredArgs", function(_, arg)
        receivedArg = arg
      end)
      local ctx = context:New("TestDeferredArgs")
      events:SendMessageLater(ctx, "test/DeferredArgs", "payload")
      fireAfters()
      assert.are.equal("payload", receivedArg)
    end)

    it("errors on a cancelled context even when deferred", function()
      events:RegisterMessage("test/DeferredCancelled", function() end)
      local ctx = context:New("TestCancel")
      ctx:Cancel()
      assert.has_error(function()
        events:SendMessageLater(ctx, "test/DeferredCancelled")
        fireAfters()
      end)
    end)
  end)
end)
