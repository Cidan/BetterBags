-- refresh_spec.lua -- Unit tests for data/refresh.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

addon.isRetail = true
addon.isClassic = false
addon.isAnniversary = false
addon.atBank = false
addon.atWarbank = false

-- Mock Bags structure (simplified)
addon.Bags = {
  Backpack = { Draw = function() end },
  Bank = nil,
}

-- Dependencies
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")

local context = addon:GetModule("Context")
local events = addon:GetModule("Events")
events:OnInitialize()

-- Constants stub
local const = StubBetterBagsModule("Constants")
const.BAG_KIND = { BACKPACK = 0, BANK = 1 }
const.BANK_TAB = { ACCOUNT_BANK_1 = 200 }

-- Debug stub
local debug = StubBetterBagsModule("Debug")
debug.Log = function() end
debug.Inspect = function() end

-- Required globals for refresh module
_G.Enum = _G.Enum or {}
_G.Enum.BagIndex = _G.Enum.BagIndex or {}
_G.Enum.BagIndex.AccountBankTab_1 = 200
_G.Enum.BankType = _G.Enum.BankType or { Character = 1, Account = 2 }

-- Items stub
local items = StubBetterBagsModule("Items")
local itemsCalls = {}
items.GetAllSlotInfo = function() return {} end
items.RefreshBackpack = function() end
items.RefreshBank = function() end
items.ClearItemCache = function() table.insert(itemsCalls, "ClearItemCache") end
items.RemoveNewItemFromAllItems = function() table.insert(itemsCalls, "RemoveNewItemFromAllItems") end
items.Restack = function(_, _, _, cb)
  table.insert(itemsCalls, "Restack")
  if cb then cb() end
end

-- Override C_Timer.NewTimer so we can control debounce timing
local timerCallbacks = {}
_G.C_Timer.NewTimer = function(seconds, callback)
  local timer = { _seconds = seconds, _callback = callback }
  table.insert(timerCallbacks, timer)
  return {
    Cancel = function(self)
      timer._cancelled = true
    end,
  }
end

-- Helper to flush debounce timers
local function flushTimers()
  for _, timer in ipairs(timerCallbacks) do
    if not timer._cancelled then
      timer._callback()
    end
  end
  for i = #timerCallbacks, 1, -1 do
    timerCallbacks[i] = nil
  end
end

-- Override C_Timer.After for AfterSort
local afterCallbacks = {}
_G.C_Timer.After = function(seconds, callback)
  table.insert(afterCallbacks, {seconds = seconds, callback = callback})
end

local function flushAfters()
  for _, ac in ipairs(afterCallbacks) do
    ac.callback()
  end
  for i = #afterCallbacks, 1, -1 do
    afterCallbacks[i] = nil
  end
end

-- Reset InCombatLockdown

LoadBetterBagsModule("data/refresh.lua")
local refresh = addon:GetModule("Refresh")

describe("Refresh", function()

  before_each(function()
    -- Reset items calls
    for i = #itemsCalls, 1, -1 do itemsCalls[i] = nil end
    -- Reset timers
    for i = #timerCallbacks, 1, -1 do timerCallbacks[i] = nil end
    for i = #afterCallbacks, 1, -1 do afterCallbacks[i] = nil end
    -- Reset addon state
    addon.atBank = false
    addon.atWarbank = false
    addon.Bags.Bank = nil
    -- Reset combat state
    _G.InCombatLockdown = function() return false end
    -- Re-initialize module
    refresh:OnInitialize()
    events:OnInitialize()
  end)

  -- ─── OnInitialize ──────────────────────────────────────────────────────────────

  describe("OnInitialize", function()

    it("sets initial state", function()
      refresh:OnInitialize()
      assert.is_false(refresh.pendingBackpack)
      assert.is_false(refresh.pendingBank)
      assert.is_false(refresh.pendingWipe)
      assert.is_nil(refresh.debounceTimer)
      assert.is_false(refresh.isSorting)
    end)
  end)

  -- ─── OnEnable ────────────────────────────────────────────────────────────────

  describe("OnEnable", function()

    it("registers BAG_UPDATE_DELAYED to refresh backpack+bank", function()
      refresh:OnEnable()
      -- Trigger the WoW event via the internal event map.
      local eventMap = events._eventMap
      if eventMap["BAG_UPDATE_DELAYED"] then
        eventMap["BAG_UPDATE_DELAYED"].fn("BAG_UPDATE_DELAYED", "BAG_UPDATE_DELAYED")
      end
      assert.is_true(refresh.pendingBackpack)
      assert.is_true(refresh.pendingBank)
    end)

    it("registers bags/RefreshBackpack to request a wipe+backpack update", function()
      refresh:OnEnable()
      local ctx = context:New("TestRefresh")
      events:SendMessage(ctx, "bags/RefreshBackpack", true)
      assert.is_true(refresh.pendingWipe)
      assert.is_true(refresh.pendingBackpack)
    end)

    it("registers bags/RefreshBank to request a wipe+bank update", function()
      refresh:OnEnable()
      local ctx = context:New("TestRefresh")
      events:SendMessage(ctx, "bags/RefreshBank", true)
      assert.is_true(refresh.pendingWipe)
      assert.is_true(refresh.pendingBank)
    end)

    it("registers bags/RefreshAll to refresh both backpack and bank", function()
      refresh:OnEnable()
      local ctx = context:New("TestRefresh")
      events:SendMessage(ctx, "bags/RefreshAll")
      assert.is_true(refresh.pendingBackpack)
      assert.is_true(refresh.pendingBank)
    end)

    it("registers bags/SortBackpack to trigger a sort", function()
      refresh:OnEnable()
      _G.InCombatLockdown = function() return false end
      local ctx = context:New("TestSort")
      events:SendMessage(ctx, "bags/SortBackpack")
      assert.is_true(refresh.isSorting)
    end)

    it("registers bags/FullRefreshAll to request a wipe+all update", function()
      refresh:OnEnable()
      local ctx = context:New("TestFull")
      events:SendMessage(ctx, "bags/FullRefreshAll")
      assert.is_true(refresh.pendingWipe)
      assert.is_true(refresh.pendingBackpack)
      assert.is_true(refresh.pendingBank)
    end)

    it("registers BAG_CONTAINER_UPDATE to request a wipe+backpack update", function()
      refresh:OnEnable()
      local eventMap = events._eventMap
      if eventMap["BAG_CONTAINER_UPDATE"] then
        eventMap["BAG_CONTAINER_UPDATE"].fn("BAG_CONTAINER_UPDATE", "BAG_CONTAINER_UPDATE")
      end
      assert.is_true(refresh.pendingWipe)
      assert.is_true(refresh.pendingBackpack)
    end)

    it("registers EQUIPMENT_SETS_CHANGED to request a wipe+all update", function()
      refresh:OnEnable()
      local eventMap = events._eventMap
      if eventMap["EQUIPMENT_SETS_CHANGED"] then
        eventMap["EQUIPMENT_SETS_CHANGED"].fn("EQUIPMENT_SETS_CHANGED", "EQUIPMENT_SETS_CHANGED")
      end
      assert.is_true(refresh.pendingWipe)
      assert.is_true(refresh.pendingBackpack)
      assert.is_true(refresh.pendingBank)
    end)

    it("registers PLAYER_REGEN_ENABLED to flush pending updates", function()
      refresh.pendingBackpack = true
      refresh:OnEnable()
      local eventMap = events._eventMap
      if eventMap["PLAYER_REGEN_ENABLED"] then
        eventMap["PLAYER_REGEN_ENABLED"].fn("PLAYER_REGEN_ENABLED", "PLAYER_REGEN_ENABLED")
      end
      -- After execute, pending flags should be reset.
      assert.is_false(refresh.pendingBackpack)
    end)
  end)

  -- ─── RequestUpdate ─────────────────────────────────────────────────────────────

  describe("RequestUpdate", function()

    it("sets pendingBackpack when request.backpack is true", function()
      refresh:RequestUpdate({ backpack = true })
      assert.is_true(refresh.pendingBackpack)
    end)

    it("sets pendingBank when request.bank is true", function()
      refresh:RequestUpdate({ bank = true })
      assert.is_true(refresh.pendingBank)
    end)

    it("sets pendingWipe when request.wipe is true", function()
      refresh:RequestUpdate({ wipe = true })
      assert.is_true(refresh.pendingWipe)
    end)

    it("sets multiple flags at once", function()
      refresh:RequestUpdate({ wipe = true, backpack = true, bank = true })
      assert.is_true(refresh.pendingWipe)
      assert.is_true(refresh.pendingBackpack)
      assert.is_true(refresh.pendingBank)
    end)

    it("does not set flags when sorting", function()
      refresh.isSorting = true
      refresh:RequestUpdate({ backpack = true })
      assert.is_false(refresh.pendingBackpack)
    end)

    it("creates a debounce timer", function()
      refresh:RequestUpdate({ backpack = true })
      assert.is_not_nil(refresh.debounceTimer)
      assert.are.equal(1, #timerCallbacks)
    end)

    it("cancels previous debounce timer on new request", function()
      refresh:RequestUpdate({ backpack = true })
      local firstTimer = timerCallbacks[1]
      refresh:RequestUpdate({ bank = true })
      assert.is_true(firstTimer._cancelled)
    end)

    it("cancels debounce timer when sort request arrives", function()
      _G.InCombatLockdown = function() return false end
      refresh:RequestUpdate({ backpack = true })
      local updateTimer = timerCallbacks[1]
      -- Sort should cancel the pending update timer before starting
      refresh:RequestUpdate({ sort = true })
      -- BUG: sort returns at line 97 before reaching the timer cancel at line 101,
      -- so the update timer is still alive and will fire during sort
      assert.is_true(updateTimer._cancelled, "debounce timer should be cancelled when sort starts")
    end)

    it("handles sort request when not in combat", function()
      _G.InCombatLockdown = function() return false end
      refresh:RequestUpdate({ sort = true })
      assert.is_true(refresh.isSorting)
      -- Should have called RemoveNewItemFromAllItems
      local foundRemove = false
      for _, call in ipairs(itemsCalls) do
        if call == "RemoveNewItemFromAllItems" then foundRemove = true end
      end
      assert.is_true(foundRemove)
      -- Should have called Restack
      local foundRestack = false
      for _, call in ipairs(itemsCalls) do
        if call == "Restack" then foundRestack = true end
      end
      assert.is_true(foundRestack)
    end)

    it("ignores sort request in combat", function()
      _G.InCombatLockdown = function() return true end
      refresh:RequestUpdate({ sort = true })
      assert.is_false(refresh.isSorting)
    end)

    it("does not queue update during sort", function()
      refresh.isSorting = true
      refresh:RequestUpdate({ wipe = true, backpack = true })
      assert.is_false(refresh.pendingWipe)
      assert.is_false(refresh.pendingBackpack)
    end)
  end)

  -- ─── AfterSort ─────────────────────────────────────────────────────────────────

  describe("AfterSort", function()

    it("sets isSorting to false", function()
      refresh.isSorting = true
      refresh:AfterSort(context:New("Test"))
      -- AfterSort schedules via C_Timer.After, flush the callback
      flushAfters()
      assert.is_false(refresh.isSorting)
    end)

    it("sends FullRefreshAll after delay", function()
      local fullRefreshSent = false
      events:RegisterMessage("bags/FullRefreshAll", function()
        fullRefreshSent = true
      end)

      refresh:AfterSort(context:New("Test"))
      -- Flush the C_Timer.After callback
      flushAfters()

      assert.is_true(fullRefreshSent)
    end)
  end)

  -- ─── ExecutePendingUpdates ─────────────────────────────────────────────────────

  describe("ExecutePendingUpdates", function()

    it("clears pending flags on combat with pendingWipe", function()
      _G.InCombatLockdown = function() return true end
      refresh.pendingWipe = true
      refresh.pendingBackpack = true
      refresh.pendingBank = true
      refresh:ExecutePendingUpdates()
      assert.is_false(refresh.pendingWipe)
      assert.is_false(refresh.pendingBackpack)
      assert.is_false(refresh.pendingBank)
    end)

    it("clears item cache when pendingWipe", function()
      _G.InCombatLockdown = function() return false end
      refresh.pendingWipe = true
      refresh:ExecutePendingUpdates()
      flushTimers()
      local found = false
      for _, call in ipairs(itemsCalls) do
        if call == "ClearItemCache" then found = true end
      end
      assert.is_true(found)
    end)

    it("triggers backpack refresh after wipe via ClearItemCache", function()
      _G.InCombatLockdown = function() return false end
      refresh.pendingWipe = true
      refresh:ExecutePendingUpdates()
      -- ExecutePendingUpdates resets flags at the end, but ClearItemCache should have been called
      local foundClearCache = false
      for _, call in ipairs(itemsCalls) do
        if call == "ClearItemCache" then foundClearCache = true end
      end
      assert.is_true(foundClearCache)
      -- All flags reset after execution
      assert.is_false(refresh.pendingWipe)
      assert.is_false(refresh.pendingBackpack)
      assert.is_false(refresh.pendingBank)
    end)

    it("updates bank when at bank", function()
      _G.InCombatLockdown = function() return false end
      addon.atBank = true
      addon.Bags.Bank = { bankTab = 100 }
      refresh.pendingBank = true
      refresh:ExecutePendingUpdates()
      flushTimers()
      -- Bank refresh should have been called (via debounce)
      assert.is_false(refresh.pendingBank)
    end)

    it("updates backpack when pendingBackpack", function()
      _G.InCombatLockdown = function() return false end
      refresh.pendingBackpack = true
      refresh:ExecutePendingUpdates()
      flushTimers()
      assert.is_false(refresh.pendingBackpack)
    end)

    it("resets all pending flags after execution", function()
      _G.InCombatLockdown = function() return false end
      refresh.pendingBackpack = true
      refresh.pendingBank = true
      refresh.pendingWipe = true
      refresh:ExecutePendingUpdates()
      flushTimers()
      assert.is_false(refresh.pendingBackpack)
      assert.is_false(refresh.pendingBank)
      assert.is_false(refresh.pendingWipe)
    end)

    it("shifts bank tab to account bank start when at warbank", function()
      _G.InCombatLockdown = function() return false end
      addon.atBank = true
      addon.atWarbank = true
      addon.isRetail = true
      addon.Bags.Bank = { bankTab = 50 } -- Below account bank start

      refresh.pendingBank = true
      refresh:ExecutePendingUpdates()
      flushTimers()

      -- Bank tab should have been shifted to account bank start (200)
      assert.are.equal(200, addon.Bags.Bank.bankTab)
    end)

    it("does not update bank when not at bank", function()
      _G.InCombatLockdown = function() return false end
      addon.atBank = false
      refresh.pendingBank = true
      refresh:ExecutePendingUpdates()
      flushTimers()
      assert.is_false(refresh.pendingBank)
    end)

    it("does nothing when no flags are set", function()
      _G.InCombatLockdown = function() return false end
      refresh:ExecutePendingUpdates()
      -- Should complete without error
    end)
  end)

  -- ─── RedrawBackpack ────────────────────────────────────────────────────────────

  describe("RedrawBackpack", function()

    it("calls Bags.Backpack:Draw with slot info", function()
      local drawn = false
      addon.Bags.Backpack.Draw = function(_, _, _, callback)
        drawn = true
        if callback then callback() end
      end

      refresh:RedrawBackpack(context:New("Test"))
      assert.is_true(drawn)
    end)

    it("sends bags/Draw/Backpack/Done message on complete", function()
      local doneReceived = false
      events:RegisterMessage("bags/Draw/Backpack/Done", function()
        doneReceived = true
      end)

      addon.Bags.Backpack.Draw = function(_, _, _, callback)
        if callback then callback() end
      end

      refresh:RedrawBackpack(context:New("Test"))
      assert.is_true(doneReceived)
    end)
  end)
end)
