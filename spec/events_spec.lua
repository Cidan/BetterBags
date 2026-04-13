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
end)
