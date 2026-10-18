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
    events:Init()
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

  -- Init replaces the AceEvent handler. The old one stayed registered and kept dispatching
  -- every later message to the new handlers again (a spec that re-initialized Events made
  -- one message reach a refresh handler seven times).
  describe("Init", function()
    it("unregisters the previous handler, so a message reaches each listener once", function()
      local ctx = addon:GetModule("Context"):New("test")
      events:RegisterMessage("test/ReInit", function() end)
      events:Init()
      local calls = 0
      events:RegisterMessage("test/ReInit", function() calls = calls + 1 end)
      events:SendMessage(ctx, "test/ReInit")
      assert.equal(1, calls)
    end)

    it("unregisters the previous handler's events, so an event reaches each listener once", function()
      events:RegisterEvent("TEST_REINIT_EVENT", function() end)
      events:Init()
      local fired = 0
      events:RegisterEvent("TEST_REINIT_EVENT", function() fired = fired + 1 end)
      LibStub("AceEvent-3.0").events:Fire("TEST_REINIT_EVENT")
      assert.equal(1, fired)
    end)
  end)

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

    it("keeps a single pending timer while events keep firing", function()
      events:BucketEvent("test/BucketCancel", function() end)
      local fn = events._eventMap["test/BucketCancel"].fn
      fn("test/BucketCancel", "test/BucketCancel")
      fn("test/BucketCancel", "test/BucketCancel")
      fn("test/BucketCancel", "test/BucketCancel")
      -- Later fires join the pending window instead of cancelling and
      -- re-creating the timer.
      assert.are.equal(1, #timerCallbacks)
      assert.is_false(timerCallbacks[1].cancelled)
    end)

    it("opens a new window with the next fire after a window flushed", function()
      events:BucketEvent("test/BucketClear", function() end)
      local fn = events._eventMap["test/BucketClear"].fn
      fn("test/BucketClear", "test/BucketClear")
      fireTimers()
      fn("test/BucketClear", "test/BucketClear")
      assert.are.equal(1, #timerCallbacks)
    end)

    it("runs the callback for every window, not only the first", function()
      local calls = 0
      events:BucketEvent("test/BucketRepeat", function() calls = calls + 1 end)
      local fn = events._eventMap["test/BucketRepeat"].fn
      for _ = 1, 3 do
        fn("test/BucketRepeat")
        fn("test/BucketRepeat")
        fireTimers()
      end
      assert.are.equal(3, calls)
    end)

    it("is not starved by a continuous stream of fires", function()
      local batches = {}
      events:BucketEvent("test/BucketStream", function(_, evts) table.insert(batches, #evts) end)
      local fn = events._eventMap["test/BucketStream"].fn
      -- Fires keep arriving inside every window; each window still flushes.
      fn("test/BucketStream", 1)
      fn("test/BucketStream", 2)
      fireTimers()
      fn("test/BucketStream", 3)
      fn("test/BucketStream", 4)
      fn("test/BucketStream", 5)
      fireTimers()
      assert.same({2, 3}, batches)
    end)

    it("drops fires rejected by the filter without scheduling or recording", function()
      local received
      events:BucketEvent("test/BucketFilter", function(_, evts) received = evts end, function(_, id)
        return id == 7
      end)
      local fn = events._eventMap["test/BucketFilter"].fn
      fn("test/BucketFilter", 1)
      fn("test/BucketFilter", 2)
      assert.are.equal(0, #timerCallbacks)
      fn("test/BucketFilter", 7)
      assert.are.equal(1, #timerCallbacks)
      fireTimers()
      assert.are.equal(1, #received)
      assert.are.equal(7, received[1].args[1])
    end)

    it("builds no context or argument record for payload-less fires", function()
      local received
      events:BucketEvent("test/BucketNoAlloc", function(_, evts) received = evts end)
      local fn = events._eventMap["test/BucketNoAlloc"].fn
      local originalNew = context.New
      local created = 0
      context.New = function(...)
        created = created + 1
        return originalNew(...)
      end
      for _ = 1, 5 do fn("test/BucketNoAlloc") end
      local createdDuringFires = created
      fireTimers()
      context.New = originalNew
      assert.are.equal(0, createdDuringFires)
      assert.are.same({}, received)
      assert.are.equal(1, created)
    end)

    it("registers the underlying event once, however many buckets listen to it", function()
      events:BucketEvent("test/BucketOnce", function() end)
      local fn = events._eventMap["test/BucketOnce"].fn
      events:BucketEvent("test/BucketOnce", function() end)
      assert.are.equal(fn, events._eventMap["test/BucketOnce"].fn)
    end)

    it("opens a fresh window for fires raised during the flush", function()
      local fn
      local batches = {}
      events:BucketEvent("test/BucketReentrant", function(_, evts)
        table.insert(batches, evts[1].args[1])
        if #batches == 1 then fn("test/BucketReentrant", "second") end
      end)
      fn = events._eventMap["test/BucketReentrant"].fn
      fn("test/BucketReentrant", "first")
      local firstWindow = timerCallbacks[1]
      timerCallbacks = {}
      firstWindow.callback()
      assert.are.equal(1, #timerCallbacks)
      fireTimers()
      assert.same({"first", "second"}, batches)
    end)

    -- Both bag designs bucket BAG_UPDATE_COOLDOWN (next.md §11): one registration must not take
    -- another's place.
    it("gives each registration its own bucket: its own window, filter and callback", function()
      local first, second = {}, {}
      events:BucketEvent("test/BucketMulti", function(_, evts) table.insert(first, #evts) end)
      events:BucketEvent("test/BucketMulti", function(_, evts) table.insert(second, #evts) end, function(_, id)
        return id == 2
      end)
      local fn = events._eventMap["test/BucketMulti"].fn
      fn("test/BucketMulti", 1)
      assert.are.equal(1, #timerCallbacks, "only the first took it")
      fn("test/BucketMulti", 2)
      assert.are.equal(2, #timerCallbacks)
      fireTimers()
      assert.are.same({ 2 }, first)
      assert.are.same({ 1 }, second)
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

    it("passes the collected per-fire event arguments to the callback", function()
      local received
      events:BucketEvent("test/BucketArgs", function(_, evts) received = evts end)
      local fn = events._eventMap["test/BucketArgs"].fn
      -- Simulate AceEvent firing the event twice in one window with
      -- distinct payloads (e.g. two different TOOLTIP_DATA_UPDATE dataInstanceIDs).
      fn("test/BucketArgs", 111)
      fn("test/BucketArgs", 222)
      fireTimers()
      assert.is_table(received)
      assert.are.equal(2, #received)
      assert.are.equal(111, received[1].args[1])
      assert.are.equal(222, received[2].args[1])
    end)
  end)

  -- ─── Scopes ─────────────────────────────────────────────────────────────────

  -- A bag design's registrations are made in its scope, so switching the design off unhooks every
  -- one of them and switching it on hooks them again (next.md §11).
  describe("scopes", function()
    local timers, originalNewTimer, aceFrame

    before_each(function()
      timers = {}
      originalNewTimer = _G.C_Timer.NewTimer
      _G.C_Timer.NewTimer = function(_, callback)
        local entry = { callback = callback, cancelled = false }
        table.insert(timers, entry)
        return { Cancel = function() entry.cancelled = true end }
      end
      aceFrame = LibStub("AceEvent-3.0").frame
    end)

    after_each(function()
      _G.C_Timer.NewTimer = originalNewTimer
    end)

    local function fire(event, ...)
      local entry = events._eventMap[event]
      if entry then entry.fn(event, ...) end
    end

    local function fireTimers()
      local pending = timers
      timers = {}
      for _, t in ipairs(pending) do
        if not t.cancelled then t.callback() end
      end
    end

    it("switches off a scope's events, messages and buckets, and back on", function()
      local scope = events:NewScope("design")
      local got = {}
      events:InScope(scope, function()
        events:RegisterEvent("TEST_SCOPE_EVENT", function(_, _, n) table.insert(got, "event " .. n) end)
        events:RegisterMessage("test/ScopeMessage", function(_, n) table.insert(got, "message " .. n) end)
        events:BucketEvent("TEST_SCOPE_BUCKET", function(_, evts) table.insert(got, "bucket " .. #evts) end)
      end)
      fire("TEST_SCOPE_EVENT", 1)
      events:SendMessage(context:New("t"), "test/ScopeMessage", 1)
      fire("TEST_SCOPE_BUCKET", 1)
      fireTimers()
      assert.are.same({ "event 1", "message 1", "bucket 1" }, got)
      scope:Disable()
      assert.is_false(scope:IsEnabled())
      got = {}
      fire("TEST_SCOPE_EVENT", 2)
      events:SendMessage(context:New("t"), "test/ScopeMessage", 2)
      fire("TEST_SCOPE_BUCKET", 2)
      fireTimers()
      assert.are.same({}, got)
      scope:Enable()
      fire("TEST_SCOPE_EVENT", 3)
      events:SendMessage(context:New("t"), "test/ScopeMessage", 3)
      fire("TEST_SCOPE_BUCKET", 3)
      fireTimers()
      assert.are.same({ "event 3", "message 3", "bucket 1" }, got)
    end)

    it("leaves what was registered outside it alone", function()
      local scope = events:NewScope("design")
      local got = {}
      events:RegisterEvent("TEST_SCOPE_SHARED", function() table.insert(got, "outside") end)
      events:InScope(scope, function()
        events:RegisterEvent("TEST_SCOPE_SHARED", function() table.insert(got, "inside") end)
      end)
      events:RegisterEvent("TEST_SCOPE_SHARED", function() table.insert(got, "after") end)
      scope:Disable()
      fire("TEST_SCOPE_SHARED")
      assert.are.same({ "outside", "after" }, got)
    end)

    it("unregisters a WoW event no callback is left for, and registers it again", function()
      local scope = events:NewScope("design")
      events:InScope(scope, function()
        events:RegisterEvent("TEST_SCOPE_ALONE", function() end)
        events:BucketEvent("TEST_SCOPE_ALONE_BUCKET", function() end)
      end)
      assert.is_true(aceFrame._events["TEST_SCOPE_ALONE"])
      scope:Disable()
      assert.is_nil(aceFrame._events["TEST_SCOPE_ALONE"])
      assert.is_nil(aceFrame._events["TEST_SCOPE_ALONE_BUCKET"])
      assert.is_nil(events._eventMap["TEST_SCOPE_ALONE"])
      scope:Enable()
      assert.is_true(aceFrame._events["TEST_SCOPE_ALONE"])
      assert.is_true(aceFrame._events["TEST_SCOPE_ALONE_BUCKET"])
    end)

    it("cancels a bucket's open window when switched off", function()
      local scope = events:NewScope("design")
      local ran = false
      events:InScope(scope, function()
        events:BucketEvent("TEST_SCOPE_WINDOW", function() ran = true end)
      end)
      fire("TEST_SCOPE_WINDOW", 1)
      assert.are.equal(1, #timers)
      scope:Disable()
      assert.is_true(timers[1].cancelled)
      fireTimers()
      assert.is_false(ran)
      scope:Enable()
      fire("TEST_SCOPE_WINDOW", 2)
      fireTimers()
      assert.is_true(ran)
    end)

    it("switches on and off once, however often it is asked", function()
      local scope = events:NewScope("design")
      local calls = 0
      events:InScope(scope, function()
        events:RegisterEvent("TEST_SCOPE_TWICE", function() calls = calls + 1 end)
      end)
      scope:Enable()
      fire("TEST_SCOPE_TWICE")
      assert.are.equal(1, calls)
      scope:Disable()
      scope:Disable()
      scope:Enable()
      fire("TEST_SCOPE_TWICE")
      assert.are.equal(2, calls)
    end)

    it("hooks nothing registered in it while it is off, until it is switched on", function()
      local scope = events:NewScope("design")
      local calls = 0
      scope:Disable()
      events:InScope(scope, function()
        events:RegisterEvent("TEST_SCOPE_LATE", function() calls = calls + 1 end)
      end)
      fire("TEST_SCOPE_LATE")
      assert.are.equal(0, calls)
      scope:Enable()
      fire("TEST_SCOPE_LATE")
      assert.are.equal(1, calls)
    end)

    it("keeps a dispatch going when a callback switches a scope off", function()
      local scope = events:NewScope("design")
      local got = {}
      events:RegisterEvent("TEST_SCOPE_DURING", function()
        table.insert(got, "first")
        scope:Disable()
      end)
      events:InScope(scope, function()
        events:RegisterEvent("TEST_SCOPE_DURING", function() table.insert(got, "second") end)
      end)
      events:RegisterEvent("TEST_SCOPE_DURING", function() table.insert(got, "third") end)
      fire("TEST_SCOPE_DURING")
      fire("TEST_SCOPE_DURING")
      assert.are.same({ "first", "second", "third", "first", "third" }, got)
    end)

    it("puts back the scope it was in, nested or after an error", function()
      local outer, inner = events:NewScope("outer"), events:NewScope("inner")
      local got = {}
      events:InScope(outer, function()
        events:InScope(inner, function()
          events:RegisterEvent("TEST_SCOPE_NESTED", function() table.insert(got, "inner") end)
        end)
        events:RegisterEvent("TEST_SCOPE_NESTED", function() table.insert(got, "outer") end)
      end)
      assert.has_error(function()
        events:InScope(inner, function() error("boom") end)
      end)
      events:RegisterEvent("TEST_SCOPE_NESTED", function() table.insert(got, "none") end)
      inner:Disable()
      fire("TEST_SCOPE_NESTED")
      assert.are.same({ "outer", "none" }, got)
      outer:Disable()
      got = {}
      fire("TEST_SCOPE_NESTED")
      assert.are.same({ "none" }, got)
    end)
  end)

  -- ─── GroupBucketEvent ───────────────────────────────────────────────────────

  describe("GroupBucketEvent", function()

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

    it("buckets events from multiple sources into one callback", function()
      local received
      events:GroupBucketEvent({"g/E1", "g/E2"}, {}, function(arg)
        received = arg
      end)
      local eventMap = events._eventMap
      if eventMap["g/E1"] then eventMap["g/E1"].fn("g/E1", "g/E1") end
      if eventMap["g/E2"] then eventMap["g/E2"].fn("g/E2", "g/E2") end
      fireTimers()
      assert.is_not_nil(received)
      assert.are.equal(2, #received)
    end)

    it("also buckets messages alongside events", function()
      local received
      events:GroupBucketEvent({"g/E3"}, {"g/M1"}, function(arg)
        received = arg
      end)
      local eventMap = events._eventMap
      if eventMap["g/E3"] then eventMap["g/E3"].fn("g/E3", "g/E3") end
      local ctx = context:New("TestGroupBucket")
      events:SendMessage(ctx, "g/M1", "msgarg")
      fireTimers()
      assert.is_not_nil(received)
      assert.are.equal(2, #received)
    end)

    it("resets the arguments list after firing", function()
      local batchSizes = {}
      events:GroupBucketEvent({"g/E4"}, {}, function(arg)
        table.insert(batchSizes, #arg)
      end)
      local eventMap = events._eventMap
      if eventMap["g/E4"] then eventMap["g/E4"].fn("g/E4", "g/E4") end
      fireTimers()
      if eventMap["g/E4"] then eventMap["g/E4"].fn("g/E4", "g/E4") end
      if eventMap["g/E4"] then eventMap["g/E4"].fn("g/E4", "g/E4") end
      fireTimers()
      assert.are.equal(1, batchSizes[1])
      assert.are.equal(2, batchSizes[2])
    end)
  end)

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

  -- ─── Profiler dispatch labels ───────────────────────────────────────────────

  describe("profiler dispatch labels", function()
    LoadBetterBagsModule("debug/perf/format.lua")
    local perf = addon:GetModule("Perf")
    local perfFormat = addon:GetModule("PerfFormat")

    local now
    local timerCallbacks
    local originalNewTimer

    before_each(function()
      now = 0
      perf:Init()
      perf:SetClock(function() return now end)
      timerCallbacks = {}
      originalNewTimer = _G.C_Timer.NewTimer
      _G.C_Timer.NewTimer = function(_, callback)
        table.insert(timerCallbacks, callback)
        return { Cancel = function() end }
      end
      perf:Start({ modules = {}, prototypes = {}, includeRoot = false, calibrate = false })
    end)

    after_each(function()
      if perf:IsActive() then perf:Stop() end
      _G.C_Timer.NewTimer = originalNewTimer
    end)

    local function stopAndFind(path)
      return perfFormat:Find(perfFormat:Decode(perf:Stop()), path)
    end

    it("roots WoW event dispatch under the event's name", function()
      events:RegisterEvent("TEST_PERF_EVENT", function() now = now + 3 end)
      local fn = events._eventMap["TEST_PERF_EVENT"].fn
      fn("TEST_PERF_EVENT")
      fn("TEST_PERF_EVENT")
      local node = stopAndFind({ "[event] TEST_PERF_EVENT" })
      assert.are.equal(2, node.calls)
      assert.are.equal(6, node.self)
    end)

    it("counts every fire of a bucketed event, including filtered ones", function()
      events:BucketEvent("TEST_PERF_BUCKET", function() now = now + 4 end, function(_, id)
        return id == 1
      end)
      local fn = events._eventMap["TEST_PERF_BUCKET"].fn
      fn("TEST_PERF_BUCKET", 1)
      fn("TEST_PERF_BUCKET", 2)
      fn("TEST_PERF_BUCKET", 3)
      timerCallbacks[1]()
      local tree = perfFormat:Decode(perf:Stop())
      assert.are.equal(3, perfFormat:Find(tree, { "[event] TEST_PERF_BUCKET" }).calls)
      local flush = perfFormat:Find(tree, { "[bucket] TEST_PERF_BUCKET" })
      assert.are.equal(1, flush.calls)
      assert.are.equal(4, flush.self)
    end)

    it("roots message dispatch under the message name", function()
      events:RegisterMessage("test/PerfMessage", function() now = now + 2 end)
      events:SendMessage(context:New("TestPerf"), "test/PerfMessage")
      local node = stopAndFind({ "[msg] test/PerfMessage" })
      assert.are.equal(1, node.calls)
      assert.are.equal(2, node.self)
    end)

    it("labels a group bucket flush", function()
      events:GroupBucketEvent({ "TEST_PERF_GROUP" }, {}, function() now = now + 5 end)
      events._eventMap["TEST_PERF_GROUP"].fn("TEST_PERF_GROUP")
      timerCallbacks[#timerCallbacks]()
      local node = stopAndFind({ "[bucket] TEST_PERF_GROUP" })
      assert.are.equal(5, node.self)
    end)

    describe("with a call trace that records arguments", function()
      local function restartTracing()
        perf:Stop()
        perf:Start({ modules = {}, prototypes = {}, includeRoot = false, calibrate = false, trace = true, traceArgs = true })
      end

      local function onlyCall()
        local trace = perfFormat:OpenTrace(perf:Stop())
        return trace, trace:Get(1)
      end

      it("records an event's payload, without the event name", function()
        restartTracing()
        events:RegisterEvent("TEST_PERF_PAYLOAD", function() end)
        events._eventMap["TEST_PERF_PAYLOAD"].fn("TEST_PERF_PAYLOAD", 7, "x")
        local trace, call = onlyCall()
        assert.are.equal("[event] TEST_PERF_PAYLOAD", call.name)
        assert.are.equal('7, "x"', trace:Text(call.args))
      end)

      it("records a message's payload", function()
        restartTracing()
        events:RegisterMessage("test/PerfPayload", function() end)
        events:SendMessage(context:New("TestPerf"), "test/PerfPayload", 5)
        local trace, call = onlyCall()
        assert.are.equal("[msg] test/PerfPayload", call.name)
        assert.are.equal("ctx TestPerf {}, 5", trace:Text(call.args))
      end)

      it("records the events a bucket flush delivers", function()
        events:BucketEvent("TEST_PERF_BUCKET_ARGS", function() end)
        restartTracing()
        local fn = events._eventMap["TEST_PERF_BUCKET_ARGS"].fn
        fn("TEST_PERF_BUCKET_ARGS", 42)
        timerCallbacks[#timerCallbacks]()
        local trace = perfFormat:OpenTrace(perf:Stop())
        local flush
        for i = 1, trace:Count() do
          if trace:Get(i).name == "[bucket] TEST_PERF_BUCKET_ARGS" then flush = trace:Get(i) end
        end
        assert.is_not_nil(flush)
        local text = trace:Text(flush.args)
        assert.is_truthy(text:find('eventName="TEST_PERF_BUCKET_ARGS"', 1, true), text)
      end)
    end)
  end)
end)
