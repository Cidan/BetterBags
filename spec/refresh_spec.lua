-- refresh_spec.lua -- Unit tests for data/refresh.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Ensure dependencies exist
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
local events = addon:GetModule("Events")
events:Init()

-- Default the flavor flags to retail-with-warbank; individual tests override.
addon.isRetail = true
addon.hasWarbank = true

local const = StubBetterBagsModule("Constants")
const.BAG_KIND = { UNDEFINED = -1, BACKPACK = 0, BANK = 1 }
const.BANK_BAGS = { [6] = 6, [7] = 7 }
const.BACKPACK_BAGS = { [0] = 0, [1] = 1 }
const.BANK_TAB = { BANK = 1, REAGENT = 2, ACCOUNT_BANK_1 = 3 }

local db = StubBetterBagsModule("Database")
db.GetShowBankTabs = function() return false end

local debug = StubBetterBagsModule("Debug")
debug.Log = function() end

local match = require("luassert.match")

local items = StubBetterBagsModule("Items")
items.ClearItemCache = function() end
items.RefreshBackpack = function() end
items.RefreshBank = function() end
-- The serialized refresh scheduler (data/refresh.lua) drives sweeps through the inline
-- items:RunRefresh core, not the async ProcessRefresh wrappers, so tests assert against it.
items.RunRefresh = function() end
items.ClearNewItems = function() end
-- Mirror the real Items sort-sweep flag (data/items.lua): set by a sort, cleared by the
-- next committed sweep of that kind.
local sortSweepPending = {}
items.MarkSortSweepPending = function(_, kind) sortSweepPending[kind] = true end
items.IsSortSweepPending = function(_, kind) return sortSweepPending[kind] == true end

-- Mock ItemLoader
local loader = StubBetterBagsModule("ItemLoader")
local registeredCallback = nil
loader.TellMeWhenABagIsUpdated = function(_, cb)
  registeredCallback = cb
end
-- The startup read holds the loader and primes every item in one load (refresh-scheduler.md
-- §8); spec/refresh_pipeline_spec.lua drives that path, these tests only need no-ops.
loader.Hold = function() end
loader.Release = function() end
loader.PrimeAll = function() end

ResetModuleStub("Refresh", "data/refresh.lua")
LoadBetterBagsModule("data/refresh.lua")
local refresh = addon:GetModule("Refresh")

describe("Refresh Module", function()
  local savedAfter
  local delayed
  before_each(function()
    refresh:Init()
    registeredCallback = nil
    addon.atBank = false
    addon.Bags = {}
    for k in pairs(sortSweepPending) do sortSweepPending[k] = nil end
    -- Drive the scheduler's frame clock synchronously so a RequestUpdate drains its unit
    -- within the call, preserving these tests' "processed synchronously" expectations.
    -- Timers with a real delay (the sort fallback) are held for the test to fire.
    delayed = {}
    savedAfter = _G.C_Timer.After
    _G.C_Timer.After = function(delay, fn)
      if delay == 0 then
        fn()
      else
        table.insert(delayed, { delay = delay, fn = fn })
      end
    end
  end)

  after_each(function()
    _G.C_Timer.After = savedAfter
  end)

  it("should initialize with default states", function()
    assert.is_nil(refresh.pendingBackpack)
    assert.is_nil(refresh.pendingBank)
    assert.is_nil(refresh.pendingWipe)
    assert.is_nil(refresh.debounceTimer)
  end)

  it("should process RequestUpdate instantly and synchronously for backpack", function()
    spy.on(items, "RunRefresh")

    refresh:RequestUpdate({ backpack = true })

    assert.spy(items.RunRefresh).was.called_with(items, match._, const.BAG_KIND.BACKPACK)
    assert.spy(items.RunRefresh).was_not.called_with(items, match._, const.BAG_KIND.BANK)
  end)

  it("should process RequestUpdate instantly and synchronously for bank if at bank", function()
    addon.atBank = true
    addon.Bags = { Bank = { bankTab = 1 } }
    spy.on(items, "RunRefresh")

    refresh:RequestUpdate({ bank = true })

    assert.spy(items.RunRefresh).was.called_with(items, match._, const.BAG_KIND.BANK)
    assert.spy(items.RunRefresh).was_not.called_with(items, match._, const.BAG_KIND.BACKPACK)
  end)

  it("should process RequestUpdate instantly and synchronously for wipe", function()
    addon.atBank = true
    addon.Bags = { Bank = { bankTab = 1 } }
    spy.on(items, "ClearItemCache")
    spy.on(items, "RunRefresh")

    refresh:RequestUpdate({ wipe = true })

    assert.spy(items.ClearItemCache).was.called(1)
    assert.spy(items.RunRefresh).was.called_with(items, match._, const.BAG_KIND.BACKPACK)
    assert.spy(items.RunRefresh).was.called_with(items, match._, const.BAG_KIND.BANK)
  end)

  it("should register callback with ItemLoader on OnEnable", function()
    refresh:OnEnable()
    assert.is_not_nil(registeredCallback)

    -- Simulate loader notifying that backpack bag 0 updated
    local s = spy.on(refresh, "RequestUpdate")
    registeredCallback({ [0] = true })

    assert.spy(refresh.RequestUpdate).was.called(1)
    local calledArgs = s.calls[1].vals
    assert.is_not_nil(calledArgs)
    assert.is_true(calledArgs[2].backpack)
    assert.is_false(calledArgs[2].bank)
  end)

  -- At PLAYER_LOGIN the client has not delivered the bags yet (a captured login read 20
  -- empty slots here), so OnEnable reads nothing: it holds the queue and the loader until
  -- the startup read (refresh-scheduler.md §8).
  it("reads nothing in OnEnable and holds every request for the startup read", function()
    spy.on(loader, "Hold")
    spy.on(items, "RunRefresh")
    refresh:OnEnable()
    assert.spy(loader.Hold).was.called(1)
    refresh:RequestUpdate({ backpack = true })
    refresh:RequestUpdate({ wipe = true, backpack = true, bank = true })
    assert.spy(items.RunRefresh).was_not.called()
  end)

  it("should register bags/FullRefreshAll message and trigger full update", function()
    refresh:OnEnable()
    spy.on(refresh, "RequestUpdate")
    events:SendMessage("bags/FullRefreshAll")
    assert.spy(refresh.RequestUpdate).was.called_with(match._, { wipe = true, backpack = true, bank = true })
  end)

  it("should process item updates synchronously during combat", function()
    _G.InCombatLockdown = function() return true end
    addon.atBank = true
    addon.Bags = { Bank = { bankTab = 1 } }
    spy.on(items, "RunRefresh")

    refresh:RequestUpdate({ backpack = true })
    assert.spy(items.RunRefresh).was.called_with(items, match._, const.BAG_KIND.BACKPACK)

    refresh:RequestUpdate({ bank = true })
    assert.spy(items.RunRefresh).was.called_with(items, match._, const.BAG_KIND.BANK)

    _G.InCombatLockdown = function() return false end
  end)

  it("should not invoke sorting APIs when in combat lockdown", function()
    _G.C_Container = _G.C_Container or {}
    _G.C_Container.SortBags = function() end
    _G.SortBags = function() end

    spy.on(_G.C_Container, "SortBags")
    spy.on(_G, "SortBags")
    spy.on(items, "RunRefresh")

    _G.InCombatLockdown = function() return true end
    addon.isRetail = true

    refresh:RequestUpdate({ backpack = true, sort = true })

    assert.spy(items.RunRefresh).was.called_with(items, match._, const.BAG_KIND.BACKPACK)
    assert.spy(_G.C_Container.SortBags).was_not.called()
    assert.spy(_G.SortBags).was_not.called()

    _G.InCombatLockdown = function() return false end
    refresh:RequestUpdate({ sort = true })
    assert.spy(_G.C_Container.SortBags).was.called(1)
  end)

  it("sweeps a sort request immediately, with no fallback, when it cannot sort in combat", function()
    _G.C_Container = _G.C_Container or {}
    _G.C_Container.SortBags = function() end
    spy.on(_G.C_Container, "SortBags")
    spy.on(items, "RunRefresh")
    _G.InCombatLockdown = function() return true end

    refresh:RequestUpdate({ sort = true })

    _G.InCombatLockdown = function() return false end
    assert.spy(_G.C_Container.SortBags).was_not.called()
    assert.spy(items.RunRefresh).was.called_with(items, match._, const.BAG_KIND.BACKPACK)
    assert.is_true(items:IsSortSweepPending(const.BAG_KIND.BACKPACK), "the sweep (stubbed here) is what clears it")
    assert.are.equal(0, #delayed)
  end)

  it("sweeps a sort request immediately when the client has no sort function", function()
    _G.C_Container = _G.C_Container or {}
    local savedSortBags, savedGlobalSortBags = _G.C_Container.SortBags, _G.SortBags
    _G.C_Container.SortBags = nil
    _G.SortBags = nil
    spy.on(items, "RunRefresh")

    refresh:RequestUpdate({ sort = true })

    _G.C_Container.SortBags, _G.SortBags = savedSortBags, savedGlobalSortBags
    assert.spy(items.RunRefresh).was.called_with(items, match._, const.BAG_KIND.BACKPACK)
    assert.are.equal(0, #delayed)
  end)

  it("should trigger a full update on BAG_CONTAINER_UPDATE", function()
    refresh:OnEnable()
    spy.on(refresh, "RequestUpdate")
    local eventMap = events._eventMap
    assert.is_not_nil(eventMap["BAG_CONTAINER_UPDATE"])
    eventMap["BAG_CONTAINER_UPDATE"].fn("BAG_CONTAINER_UPDATE")
    assert.spy(refresh.RequestUpdate).was.called_with(match._, { wipe = true, backpack = true, bank = true })
  end)

  it("should trigger a full update on EQUIPMENT_SETS_CHANGED", function()
    refresh:OnEnable()
    spy.on(refresh, "RequestUpdate")
    local eventMap = events._eventMap
    assert.is_not_nil(eventMap["EQUIPMENT_SETS_CHANGED"])
    eventMap["EQUIPMENT_SETS_CHANGED"].fn("EQUIPMENT_SETS_CHANGED")
    assert.spy(refresh.RequestUpdate).was.called_with(match._, { wipe = true, backpack = true, bank = true })
  end)

  it("should trigger a bank update on PLAYERBANKSLOTS_CHANGED for non-retail", function()
    addon.isRetail = false
    refresh:OnEnable()
    spy.on(refresh, "RequestUpdate")
    local eventMap = events._eventMap
    assert.is_not_nil(eventMap["PLAYERBANKSLOTS_CHANGED"])
    eventMap["PLAYERBANKSLOTS_CHANGED"].fn("PLAYERBANKSLOTS_CHANGED")
    assert.spy(refresh.RequestUpdate).was.called_with(match._, { bank = true, bags = { [-1] = true } })
    addon.isRetail = true -- reset
  end)

  -- On WoW: Forever, placing a bag in (or removing it from) a bank tab's bag socket fires
  -- PLAYERBANKSLOTS_CHANGED and resizes that tab's container, so every bank bag is swept.
  -- Bag -1 is the keyring there, never the bank, so the Classic targeted request is wrong.
  it("should sweep every bank bag on PLAYERBANKSLOTS_CHANGED on Forever", function()
    events:Init()
    addon.isRetail = true
    addon.isForever = true
    refresh:OnEnable()
    spy.on(refresh, "RequestUpdate")
    local eventMap = events._eventMap
    assert.is_not_nil(eventMap["PLAYERBANKSLOTS_CHANGED"])
    eventMap["PLAYERBANKSLOTS_CHANGED"].fn("PLAYERBANKSLOTS_CHANGED")
    assert.spy(refresh.RequestUpdate).was.called_with(match._, { bank = true })
    assert.spy(refresh.RequestUpdate).was_not.called_with(match._, { bank = true, bags = { [-1] = true } })
    addon.isForever = nil -- reset
  end)

  it("should not listen for PLAYERBANKSLOTS_CHANGED on live retail", function()
    events:Init()
    addon.isRetail = true
    addon.isForever = false
    refresh:OnEnable()
    assert.is_nil(events._eventMap["PLAYERBANKSLOTS_CHANGED"])
    addon.isForever = nil -- reset
  end)

  it("should register bags/SortBackpack message and trigger sorting", function()
    refresh:OnEnable()
    addon.atBank = false
    spy.on(refresh, "RequestUpdate")
    events:SendMessage("bags/SortBackpack")
    assert.spy(refresh.RequestUpdate).was.called_with(match._, { sort = true })
  end)

  it("should also sort the bank and warbank when sorting the backpack with the bank open (retail)", function()
    refresh:OnEnable()
    addon.atBank = true
    addon.isRetail = true
    addon.hasWarbank = true
    spy.on(refresh, "RequestUpdate")
    events:SendMessage("bags/SortBackpack")
    assert.spy(refresh.RequestUpdate).was.called_with(match._, { sort = true, sortBank = true, sortWarbank = true })
  end)

  it("should sort the bank but NOT the warbank on a client without one (Forever)", function()
    refresh:OnEnable()
    addon.atBank = true
    addon.isRetail = true
    addon.hasWarbank = false
    spy.on(refresh, "RequestUpdate")
    events:SendMessage("bags/SortBackpack")
    assert.spy(refresh.RequestUpdate).was.called_with(match._, { sort = true, sortBank = true })
    addon.hasWarbank = true -- reset
  end)

  it("should also sort the bank (not warbank) when sorting the backpack with the bank open (classic)", function()
    refresh:OnEnable()
    addon.atBank = true
    addon.isRetail = false
    addon.hasWarbank = false
    spy.on(refresh, "RequestUpdate")
    events:SendMessage("bags/SortBackpack")
    assert.spy(refresh.RequestUpdate).was.called_with(match._, { sort = true, sortBank = true })
    addon.isRetail = true -- reset
    addon.hasWarbank = true -- reset
  end)

  it("should invoke C_Container.SortBags on Retail or SortBags on Classic when sorting", function()
    _G.C_Container = _G.C_Container or {}
    _G.C_Container.SortBags = function() end
    _G.SortBags = function() end

    spy.on(_G.C_Container, "SortBags")
    spy.on(_G, "SortBags")

    addon.isRetail = true
    refresh:RequestUpdate({ sort = true })
    assert.spy(_G.C_Container.SortBags).was.called(1)
    assert.spy(_G.SortBags).was_not.called()

    addon.isRetail = false
    refresh:RequestUpdate({ sort = true })
    assert.spy(_G.SortBags).was.called(1)
    addon.isRetail = true -- reset
  end)

  describe("Sort Handling and Recent Items Clearing", function()
    -- A sort that the client can run is issued at once and does NOT sweep in its own unit:
    -- the sweep that shows its result is the next refresh of that kind (the item moves'
    -- BAG_UPDATE), and a fallback timer refreshes the kind if no such sweep has happened,
    -- e.g. because the bags were already sorted and nothing moved.
    it("issues the backpack sort at once, clears recent items, and defers the sweep", function()
      _G.C_Container = _G.C_Container or {}
      _G.C_Container.SortBags = function() end
      spy.on(items, "ClearNewItems")
      spy.on(items, "RunRefresh")
      spy.on(_G.C_Container, "SortBags")

      refresh:RequestUpdate({ sort = true })

      assert.spy(items.ClearNewItems).was.called_with(items, const.BAG_KIND.BACKPACK)
      assert.spy(_G.C_Container.SortBags).was.called(1)
      assert.spy(items.RunRefresh).was_not.called()
      assert.is_true(items:IsSortSweepPending(const.BAG_KIND.BACKPACK))
      assert.are.equal(1, #delayed)
      assert.are.equal(refresh.SORT_FALLBACK_SECONDS, delayed[1].delay)
    end)

    it("refreshes from the fallback when the sort's sweep never happened", function()
      _G.C_Container = _G.C_Container or {}
      _G.C_Container.SortBags = function() end
      spy.on(items, "RunRefresh")

      refresh:RequestUpdate({ sort = true })
      assert.spy(items.RunRefresh).was_not.called()
      delayed[1].fn()

      assert.spy(items.RunRefresh).was.called(1)
      assert.spy(items.RunRefresh).was.called_with(items, match._, const.BAG_KIND.BACKPACK)
    end)

    it("does nothing from the fallback when the sort's sweep already happened", function()
      _G.C_Container = _G.C_Container or {}
      _G.C_Container.SortBags = function() end
      spy.on(items, "RunRefresh")
      spy.on(refresh, "RequestUpdate")

      refresh:RequestUpdate({ sort = true })
      sortSweepPending[const.BAG_KIND.BACKPACK] = nil -- a BAG_UPDATE sweep committed
      delayed[1].fn()

      assert.spy(refresh.RequestUpdate).was.called(1)
      assert.spy(items.RunRefresh).was_not.called()
    end)

    it("re-checks a fallback request when its unit runs, and skips a kind already swept", function()
      spy.on(items, "RunRefresh")
      refresh:RequestUpdate({ backpack = true, onlyIfSortPending = true })
      assert.spy(items.RunRefresh).was_not.called()

      sortSweepPending[const.BAG_KIND.BACKPACK] = true
      refresh:RequestUpdate({ backpack = true, onlyIfSortPending = true })
      assert.spy(items.RunRefresh).was.called_with(items, match._, const.BAG_KIND.BACKPACK)
    end)

    it("marks the sweep pending and arms the fallback before calling the sort API", function()
      _G.C_Container = _G.C_Container or {}
      local seen = {}
      _G.C_Container.SortBags = function()
        seen.pending = items:IsSortSweepPending(const.BAG_KIND.BACKPACK)
        seen.fallbacks = #delayed
        error("sort failed")
      end
      local savedHandler = _G.geterrorhandler
      _G.geterrorhandler = function() return function() end end

      refresh:RequestUpdate({ sort = true })

      _G.geterrorhandler = savedHandler
      assert.is_true(seen.pending)
      assert.are.equal(1, seen.fallbacks)
    end)

    it("issues the bank sort at once and defers the bank sweep", function()
      addon.atBank = true
      addon.Bags = { Bank = { bankTab = 1 } }
      _G.C_Container = _G.C_Container or {}
      _G.C_Container.SortBankBags = function() end
      spy.on(items, "ClearNewItems")
      spy.on(items, "RunRefresh")
      spy.on(_G.C_Container, "SortBankBags")

      refresh:RequestUpdate({ sortBank = true })

      assert.spy(items.ClearNewItems).was.called_with(items, const.BAG_KIND.BANK)
      assert.spy(_G.C_Container.SortBankBags).was.called(1)
      assert.spy(items.RunRefresh).was_not.called()
      assert.is_true(items:IsSortSweepPending(const.BAG_KIND.BANK))
      delayed[1].fn()
      assert.spy(items.RunRefresh).was.called_with(items, match._, const.BAG_KIND.BANK)
    end)

    it("issues the warbank sort at once and defers the bank sweep", function()
      addon.atBank = true
      addon.Bags = { Bank = { bankTab = 1 } }
      _G.C_Container = _G.C_Container or {}
      _G.C_Container.SortAccountBankBags = function() end
      spy.on(items, "ClearNewItems")
      spy.on(items, "RunRefresh")
      spy.on(_G.C_Container, "SortAccountBankBags")

      refresh:RequestUpdate({ sortWarbank = true })

      assert.spy(items.ClearNewItems).was.called_with(items, const.BAG_KIND.BANK)
      assert.spy(_G.C_Container.SortAccountBankBags).was.called(1)
      assert.spy(items.RunRefresh).was_not.called()
      assert.is_true(items:IsSortSweepPending(const.BAG_KIND.BANK))
    end)

    it("sorts the backpack, bank and warbank together with one fallback covering both kinds", function()
      addon.atBank = true
      addon.Bags = { Bank = { bankTab = 1 } }
      _G.C_Container = _G.C_Container or {}
      _G.C_Container.SortBags = function() end
      _G.C_Container.SortBankBags = function() end
      _G.C_Container.SortAccountBankBags = function() end
      spy.on(items, "RunRefresh")
      spy.on(_G.C_Container, "SortBags")
      spy.on(_G.C_Container, "SortBankBags")
      spy.on(_G.C_Container, "SortAccountBankBags")

      refresh:RequestUpdate({ sort = true, sortBank = true, sortWarbank = true })

      assert.spy(_G.C_Container.SortBags).was.called(1)
      assert.spy(_G.C_Container.SortBankBags).was.called(1)
      assert.spy(_G.C_Container.SortAccountBankBags).was.called(1)
      assert.spy(items.RunRefresh).was_not.called()
      assert.are.equal(1, #delayed)
      delayed[1].fn()
      assert.spy(items.RunRefresh).was.called_with(items, match._, const.BAG_KIND.BACKPACK)
      assert.spy(items.RunRefresh).was.called_with(items, match._, const.BAG_KIND.BANK)
    end)

    it("sweeps the bank at once when only an unavailable warbank sort was asked for", function()
      addon.atBank = true
      addon.Bags = { Bank = { bankTab = 1 } }
      _G.C_Container = _G.C_Container or {}
      local savedWarbank = _G.C_Container.SortAccountBankBags
      _G.C_Container.SortAccountBankBags = nil
      spy.on(items, "RunRefresh")

      refresh:RequestUpdate({ sortWarbank = true })

      _G.C_Container.SortAccountBankBags = savedWarbank
      assert.spy(items.RunRefresh).was.called_with(items, match._, const.BAG_KIND.BANK)
      assert.are.equal(0, #delayed)
    end)

    it("should route bags/SortBank and bags/SortWarbank messages", function()
      refresh:OnEnable()
      spy.on(refresh, "RequestUpdate")

      events:SendMessage("bags/SortBank")
      assert.spy(refresh.RequestUpdate).was.called_with(match._, { sortBank = true })

      events:SendMessage("bags/SortWarbank")
      assert.spy(refresh.RequestUpdate).was.called_with(match._, { sortWarbank = true })
    end)
  end)
end)