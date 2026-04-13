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
end)
