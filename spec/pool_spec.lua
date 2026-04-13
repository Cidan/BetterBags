-- pool_spec.lua -- Unit tests for core/pool.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
-- Context is needed by Pool's create/reset functions
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/pool.lua")
local context = addon:GetModule("Context")
local pool = addon:GetModule("Pool")

describe("Pool", function()

  local ctx

  before_each(function()
    ctx = context:New("PoolTest")
  end)

  -- ─── Create ─────────────────────────────────────────────────────────────────

  describe("Create", function()

    it("creates a pool with create and reset functions", function()
      local p = pool:Create(
        function() return {value = 0} end,
        function(_, item) item.value = 0 end
      )
      assert.is_not_nil(p)
    end)
  end)

  -- ─── Acquire ────────────────────────────────────────────────────────────────

  describe("Acquire", function()

    it("creates a new item when pool is empty", function()
      local created = 0
      local p = pool:Create(
        function()
          created = created + 1
          return {id = created}
        end,
        function(_, item) item.id = 0 end
      )
      local item = p:Acquire(ctx)
      assert.are.equal(1, item.id)
      assert.are.equal(1, created)
    end)

    it("creates multiple items when pool stays empty", function()
      local created = 0
      local p = pool:Create(
        function()
          created = created + 1
          return {id = created}
        end,
        function() end
      )
      local item1 = p:Acquire(ctx)
      local item2 = p:Acquire(ctx)
      assert.are.equal(1, item1.id)
      assert.are.equal(2, item2.id)
      assert.are.equal(2, created)
    end)

    it("reuses released items instead of creating new ones", function()
      local created = 0
      local p = pool:Create(
        function()
          created = created + 1
          return {id = created}
        end,
        function(_, item) item.reset = true end
      )
      local item1 = p:Acquire(ctx)
      p:Release(ctx, item1)
      local item2 = p:Acquire(ctx)
      -- Should reuse item1, not create a new one
      assert.are.equal(1, created)
      assert.is_true(item2.reset)
    end)

    it("passes context to the create function", function()
      local receivedCtx
      local p = pool:Create(
        function(c)
          receivedCtx = c
          return {}
        end,
        function() end
      )
      p:Acquire(ctx)
      assert.are.equal(ctx, receivedCtx)
    end)
  end)

  -- ─── Release ────────────────────────────────────────────────────────────────

  describe("Release", function()

    it("calls the reset function on release", function()
      local resetCalled = false
      local p = pool:Create(
        function() return {active = true} end,
        function(_, item)
          item.active = false
          resetCalled = true
        end
      )
      local item = p:Acquire(ctx)
      assert.is_true(item.active)
      p:Release(ctx, item)
      assert.is_false(item.active)
      assert.is_true(resetCalled)
    end)

    it("passes context to the reset function", function()
      local receivedCtx
      local p = pool:Create(
        function() return {} end,
        function(c) receivedCtx = c end
      )
      local item = p:Acquire(ctx)
      p:Release(ctx, item)
      assert.are.equal(ctx, receivedCtx)
    end)

    it("returns released items to the pool for reuse", function()
      local created = 0
      local p = pool:Create(
        function()
          created = created + 1
          return {id = created}
        end,
        function() end
      )
      -- Acquire and release 3 items
      local items = {}
      for i = 1, 3 do
        items[i] = p:Acquire(ctx)
      end
      for i = 1, 3 do
        p:Release(ctx, items[i])
      end
      -- Acquiring 3 more should reuse, not create
      for _ = 1, 3 do
        p:Acquire(ctx)
      end
      assert.are.equal(3, created)
    end)
  end)
end)
