-- context_spec.lua -- Unit tests for core/context.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
LoadBetterBagsModule("core/context.lua")
local context = addon:GetModule("Context")

describe("Context", function()

  local ctx

  before_each(function()
    ctx = context:New("TestEvent")
  end)

  -- ─── New ────────────────────────────────────────────────────────────────────

  describe("New", function()

    it("creates a context with the given event", function()
      assert.are.equal("TestEvent", ctx:Event())
    end)

    it("initializes with an empty events list", function()
      local events = ctx:Get("events")
      assert.same({}, events)
    end)

    it("is not cancelled by default", function()
      assert.is_false(ctx:IsCancelled())
    end)
  end)

  -- ─── Set / Get ──────────────────────────────────────────────────────────────

  describe("Set and Get", function()

    it("stores and retrieves a string value", function()
      ctx:Set("key", "value")
      assert.are.equal("value", ctx:Get("key"))
    end)

    it("stores and retrieves a number value", function()
      ctx:Set("count", 42)
      assert.are.equal(42, ctx:Get("count"))
    end)

    it("stores and retrieves a boolean value", function()
      ctx:Set("enabled", true)
      assert.is_true(ctx:Get("enabled"))
    end)

    it("stores and retrieves a table value", function()
      local tbl = {a = 1}
      ctx:Set("data", tbl)
      assert.same({a = 1}, ctx:Get("data"))
    end)

    it("returns nil for unset keys", function()
      assert.is_nil(ctx:Get("nonexistent"))
    end)

    it("overwrites existing values", function()
      ctx:Set("key", "first")
      ctx:Set("key", "second")
      assert.are.equal("second", ctx:Get("key"))
    end)

    it("errors when setting the event key (immutable)", function()
      assert.has_error(function()
        ctx:Set("event", "OtherEvent")
      end)
    end)

    it("errors on Set after Cancel", function()
      ctx:Cancel()
      assert.has_error(function()
        ctx:Set("key", "value")
      end)
    end)

    it("errors on Get after Cancel", function()
      ctx:Cancel()
      assert.has_error(function()
        ctx:Get("key")
      end)
    end)
  end)

  -- ─── Event ──────────────────────────────────────────────────────────────────

  describe("Event", function()

    it("returns the event name", function()
      assert.are.equal("TestEvent", ctx:Event())
    end)
  end)

  -- ─── AppendEvent ────────────────────────────────────────────────────────────

  describe("AppendEvent", function()

    it("appends events to the events list", function()
      ctx:AppendEvent("EventA")
      ctx:AppendEvent("EventB")
      assert.same({"EventA", "EventB"}, ctx:Get("events"))
    end)
  end)

  -- ─── IsTrue ─────────────────────────────────────────────────────────────────

  describe("IsTrue", function()

    it("returns true for keys set to true", function()
      ctx:Set("flag", true)
      assert.is_true(ctx:IsTrue("flag"))
    end)

    it("returns false for keys set to false", function()
      ctx:Set("flag", false)
      assert.is_false(ctx:IsTrue("flag"))
    end)

    it("returns false for unset keys (nil ~= true)", function()
      assert.is_false(ctx:IsTrue("missing"))
    end)

    it("returns false for non-boolean truthy values", function()
      ctx:Set("flag", "yes")
      assert.is_false(ctx:IsTrue("flag"))
    end)

    it("errors after Cancel", function()
      ctx:Cancel()
      assert.has_error(function()
        ctx:IsTrue("flag")
      end)
    end)
  end)

  -- ─── GetBool ────────────────────────────────────────────────────────────────

  describe("GetBool", function()

    it("returns the boolean value directly", function()
      ctx:Set("flag", true)
      assert.is_true(ctx:GetBool("flag"))
      ctx:Set("other", false)
      assert.is_false(ctx:GetBool("other"))
    end)

    it("returns nil for unset keys", function()
      assert.is_nil(ctx:GetBool("missing"))
    end)

    it("errors after Cancel", function()
      ctx:Cancel()
      assert.has_error(function()
        ctx:GetBool("flag")
      end)
    end)
  end)

  -- ─── Delete ─────────────────────────────────────────────────────────────────

  describe("Delete", function()

    it("removes a key from the context", function()
      ctx:Set("key", "value")
      ctx:Delete("key")
      assert.is_nil(ctx:Get("key"))
    end)

    it("does nothing for non-existent keys", function()
      ctx:Delete("nonexistent") -- should not error
    end)

    it("errors after Cancel", function()
      ctx:Cancel()
      assert.has_error(function()
        ctx:Delete("key")
      end)
    end)
  end)

  -- ─── Cancel ─────────────────────────────────────────────────────────────────

  describe("Cancel", function()

    it("marks the context as cancelled", function()
      ctx:Cancel()
      assert.is_true(ctx:IsCancelled())
    end)

    it("errors on double cancel", function()
      ctx:Cancel()
      assert.has_error(function()
        ctx:Cancel()
      end)
    end)
  end)

  -- ─── Timeout ────────────────────────────────────────────────────────────────

  describe("Timeout", function()

    it("sets a timeout on the context", function()
      ctx:Timeout(5, function() end)
      assert.is_true(ctx:HasTimeout())
    end)

    it("errors when setting a second timeout", function()
      ctx:Timeout(5, function() end)
      assert.has_error(function()
        ctx:Timeout(10, function() end)
      end)
    end)

    it("errors after Cancel", function()
      ctx:Cancel()
      assert.has_error(function()
        ctx:Timeout(5, function() end)
      end)
    end)
  end)

  -- ─── HasTimeout ─────────────────────────────────────────────────────────────

  describe("HasTimeout", function()

    it("returns false when no timeout is set", function()
      assert.is_false(ctx:HasTimeout())
    end)

    it("returns true after timeout is set", function()
      ctx:Timeout(5, function() end)
      assert.is_true(ctx:HasTimeout())
    end)
  end)

  -- ─── Copy ───────────────────────────────────────────────────────────────────

  describe("Copy", function()

    it("creates a new context with the same event", function()
      local copy = ctx:Copy()
      assert.are.equal("TestEvent", copy:Event())
    end)

    it("copies all key-value pairs", function()
      ctx:Set("key1", "value1")
      ctx:Set("key2", 42)
      local copy = ctx:Copy()
      assert.are.equal("value1", copy:Get("key1"))
      assert.are.equal(42, copy:Get("key2"))
    end)

    it("creates an independent copy (mutations don't propagate)", function()
      ctx:Set("key", "original")
      local copy = ctx:Copy()
      copy:Set("key", "modified")
      assert.are.equal("original", ctx:Get("key"))
    end)

    it("does not copy timeouts", function()
      ctx:Timeout(5, function() end)
      local copy = ctx:Copy()
      assert.is_false(copy:HasTimeout())
    end)

    it("errors on Copy after Cancel", function()
      ctx:Cancel()
      assert.has_error(function()
        ctx:Copy()
      end)
    end)
  end)

  -- ─── Script helpers ─────────────────────────────────────────────────────────

  describe("SetScript and HookScript profiler labels", function()
    LoadBetterBagsModule("debug/perf/format.lua")
    local perf = addon:GetModule("Perf")
    local perfFormat = addon:GetModule("PerfFormat")
    local now

    before_each(function()
      now = 0
      perf:Init()
      perf:SetClock(function() return now end)
      perf:Start({ modules = {}, prototypes = {}, includeRoot = false, calibrate = false })
    end)

    after_each(function()
      if perf:IsActive() then perf:Stop() end
    end)

    it("roots a SetScript handler under the script name and passes its arguments", function()
      local frame = CreateFrame("Button")
      local received
      addon.SetScript(frame, "OnClick", function(c, _, button)
        received = { c:Event(), button }
        now = now + 4
      end)
      frame:GetScript("OnClick")(frame, "LeftButton")
      local tree = perfFormat:Decode(perf:Stop())
      assert.are.same({ "OnClick", "LeftButton" }, received)
      assert.are.equal(4, perfFormat:Find(tree, { "[script] OnClick" }).self)
    end)

    it("roots a HookScript handler under the script name", function()
      local frame = CreateFrame("Frame")
      addon.HookScript(frame, "OnShow", function() now = now + 6 end)
      frame:GetScript("OnShow")(frame)
      local tree = perfFormat:Decode(perf:Stop())
      assert.are.equal(6, perfFormat:Find(tree, { "[script] OnShow" }).self)
    end)

    it("records a script's arguments when the call trace records arguments", function()
      perf:Stop()
      perf:Start({ modules = {}, prototypes = {}, includeRoot = false, calibrate = false, trace = true, traceArgs = true })
      local frame = CreateFrame("Button")
      addon.SetScript(frame, "OnClick", function() end)
      frame:GetScript("OnClick")(frame, "RightButton")
      local trace = perfFormat:OpenTrace(perf:Stop())
      local call = trace:Get(1)
      assert.are.equal("[script] OnClick", call.name)
      local text = trace:Text(call.args)
      assert.is_truthy(text:find('"RightButton"$'), text)
    end)
  end)

  -- Once the player is logging out, AceDB strips the settings of their defaults, so no handler may
  -- run (initialization.md §7).
  describe("SetScript and HookScript while logging out", function()
    after_each(function()
      addon.loggingOut = false
    end)

    it("runs neither handler while the player is logging out", function()
      local frame = CreateFrame("Frame")
      local ran = {}
      addon.SetScript(frame, "OnSizeChanged", function() table.insert(ran, "set") end)
      addon.HookScript(frame, "OnSizeChanged", function() table.insert(ran, "hooked") end)

      addon.loggingOut = true
      frame:GetScript("OnSizeChanged")(frame)
      assert.are.same({}, ran)

      addon.loggingOut = false
      frame:GetScript("OnSizeChanged")(frame)
      assert.are.same({ "set", "hooked" }, ran)
    end)
  end)
end)
