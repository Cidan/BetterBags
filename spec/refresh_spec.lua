-- refresh_spec.lua -- Unit tests for data/refresh.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Ensure dependencies exist
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
local events = addon:GetModule("Events")
events:Init()

-- Default the flavor flags to retail-with-warbank; individual tests override.
local savedIsRetail, savedHasWarbank = addon.isRetail, addon.hasWarbank
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
items.SortSweepShown = function(_, kind) sortSweepPending[kind] = nil end
-- What a sort no read has shown still needs (the real Items works it out from what it read).
local sortLeaves = "read"
items.SortLeaves = function() return sortLeaves end
-- The bags marked changed since their read (the real Items records them, data/items.lua).
local unreadBags = {}
items.MarkBagUnread = function(_, bagID) unreadBags[bagID] = true end

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
  local savedSortBank, savedSortAccount = _G.C_Container.SortBankBags, _G.C_Container.SortAccountBankBags

  -- These outlive the file: a spec file after it would read the bags as if it had a Warbank and could sort the bank.
  teardown(function()
    addon.isRetail, addon.hasWarbank = savedIsRetail, savedHasWarbank
    _G.C_Container.SortBankBags, _G.C_Container.SortAccountBankBags = savedSortBank, savedSortAccount
  end)

  local savedAfter
  local delayed
  before_each(function()
    refresh:Init()
    registeredCallback = nil
    addon.atBank = false
    addon.Bags = {}
    for k in pairs(sortSweepPending) do sortSweepPending[k] = nil end
    sortLeaves = "read"
    for k in pairs(unreadBags) do unreadBags[k] = nil end
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

  -- A bag's read follows BAG_UPDATE only once the loader has the bag's item data, and then waits
  -- its turn; a recalculation that runs in between must know the bag changed.
  it("marks a bag changed when the client reports it (BAG_UPDATE)", function()
    events:Init()
    refresh:OnEnable()
    events._eventMap["BAG_UPDATE"].fn("BAG_UPDATE", 1)
    assert.same({ [1] = true }, unreadBags)
  end)

  it("marks every bag changed on BAG_CONTAINER_UPDATE", function()
    events:Init()
    local savedAccount = const.ACCOUNT_BANK_BAGS
    const.ACCOUNT_BANK_BAGS = { [13] = 13 }
    refresh:OnEnable()
    events._eventMap["BAG_CONTAINER_UPDATE"].fn("BAG_CONTAINER_UPDATE")
    const.ACCOUNT_BANK_BAGS = savedAccount
    assert.same({ [0] = true, [1] = true, [6] = true, [7] = true, [13] = true }, unreadBags)
  end)

  it("should trigger a full update on BAG_CONTAINER_UPDATE", function()
    refresh:OnEnable()
    spy.on(refresh, "RequestUpdate")
    local eventMap = events._eventMap
    assert.is_not_nil(eventMap["BAG_CONTAINER_UPDATE"])
    eventMap["BAG_CONTAINER_UPDATE"].fn("BAG_CONTAINER_UPDATE")
    assert.spy(refresh.RequestUpdate).was.called_with(match._, { wipe = true, backpack = true, bank = true })
  end)

  -- Gear sets are read from the set map on every sweep, never from a bag slot, so a set
  -- change recalculates the bags (refresh-scheduler.md §10).
  it("should recalculate both bags, with a fresh layout, on EQUIPMENT_SETS_CHANGED", function()
    refresh:OnEnable()
    spy.on(refresh, "RequestUpdate")
    local eventMap = events._eventMap
    assert.is_not_nil(eventMap["EQUIPMENT_SETS_CHANGED"])
    eventMap["EQUIPMENT_SETS_CHANGED"].fn("EQUIPMENT_SETS_CHANGED")
    assert.spy(refresh.RequestUpdate).was.called_with(match._, { derive = true, backpack = true, bank = true, resetLayout = true })
  end)

  it("routes bags/Rederive, recalculating every kind of bag unless told which", function()
    refresh:OnEnable()
    spy.on(refresh, "RequestUpdate")
    events:SendMessage("bags/Rederive")
    assert.spy(refresh.RequestUpdate).was.called_with(match._, { derive = true, backpack = true, bank = true, guild = true })
    local ctx = addon:GetModule("Context"):New("Test")
    events:SendMessage(ctx, "bags/Rederive", { backpack = true, resetLayout = true, buttons = true })
    assert.spy(refresh.RequestUpdate).was.called_with(match._, { derive = true, backpack = true, resetLayout = true, restyle = true })
    events:SendMessage(ctx, "bags/Rederive", { backpack = false, bank = true })
    assert.spy(refresh.RequestUpdate).was.called_with(match._, { derive = true, bank = true })
    events:SendMessage(ctx, "bags/Rederive", { backpack = true, categoriesUnchanged = true })
    assert.spy(refresh.RequestUpdate).was.called_with(match._, { derive = true, backpack = true, categoriesUnchanged = true })
  end)

  -- A capture of opening the bank read 478 of 491 bank items before the client had their
  -- data; it arrived 1.2 s later and set off another refresh. The bank shows at once and is read
  -- once its item data has loaded (refresh-scheduler.md §11). It is read tab by tab, as the guild
  -- bank is (asked: "pop in data for each physical tab (non-virtual tab) one by one ... mimic the
  -- guild bank behavior as close as possible"): a capture of a bank open (500 items) spent 520 ms
  -- in one frame reading and drawing them all at once.
  describe("opening the bank", function()
    local primes, shown, onShown, loaded, slotsOf, requests, warm
    local savedPrimeBank, savedGetShowBankTabs, savedGameMenu, savedNumSlots, savedAccount
    local savedBankBags, savedSetLoaded, savedLoaded, savedRequest

    before_each(function()
      events:Init()
      addon.isRetail = true
      primes, shown, onShown, loaded, requests, warm = {}, 0, nil, "unset", {}, false
      -- Character tabs 6 and 7, Warbank tab 13, each with slots.
      slotsOf = { [6] = 4, [7] = 4, [13] = 4 }
      savedAccount = const.ACCOUNT_BANK_BAGS
      const.ACCOUNT_BANK_BAGS = { [13] = 13 }
      savedNumSlots = _G.C_Container.GetContainerNumSlots
      _G.C_Container.GetContainerNumSlots = function(bag) return slotsOf[bag] or 0 end
      savedBankBags, savedSetLoaded, savedLoaded = items.BankBags, items.SetLoadedBankBags, items.LoadedBankBags
      items.BankBags = function() return { [6] = 6, [7] = 7, [13] = 13 } end
      items.SetLoadedBankBags = function(_, bags) loaded = bags end
      items.LoadedBankBags = function() return loaded end
      savedPrimeBank = loader.PrimeBank
      -- PrimeBank(bags, callback): one load per tab.
      loader.PrimeBank = function(_, bags, cb)
        table.insert(primes, { bags = bags, cb = cb })
        if warm then cb() end
      end
      savedGetShowBankTabs = db.GetShowBankTabs
      db.GetShowBankTabs = function() return false end
      savedGameMenu = _G.GameMenuFrame
      _G.GameMenuFrame = { IsShown = function() return false end }
      -- Show(ctx, slotInfo, onShown): onShown runs once the window has finished showing. The
      -- character bank is shown (bankTab: the bank's tab, as both bag designs keep it).
      addon.Bags = { Bank = { bankTab = 6, Show = function(_, _, _, cb)
        shown = shown + 1
        onShown = cb
      end } }
      refresh:OnEnable()
      -- The startup read OnEnable holds every sweep for (refresh-scheduler.md §8): a bank open
      -- reads one tab per read, the next once the read before it has run, so reads must run.
      refresh:_WorldRead(refresh._world, "primed")
      savedRequest = refresh.RequestUpdate
      -- Each request as it was made: merging folds later requests into a waiting one.
      refresh.RequestUpdate = function(self, r)
        local copy = {}
        for k, v in pairs(r) do copy[k] = v end
        table.insert(requests, copy)
        return savedRequest(self, r)
      end
    end)

    after_each(function()
      loader.PrimeBank = savedPrimeBank
      db.GetShowBankTabs = savedGetShowBankTabs
      _G.GameMenuFrame = savedGameMenu
      _G.C_Container.GetContainerNumSlots = savedNumSlots
      const.ACCOUNT_BANK_BAGS = savedAccount
      items.BankBags, items.SetLoadedBankBags, items.LoadedBankBags = savedBankBags, savedSetLoaded, savedLoaded
      refresh.RequestUpdate = savedRequest
      addon.atBank = false
    end)

    local function fire(event)
      events._eventMap[event].fn(event)
    end

    local function timers(delay)
      local out = {}
      for _, t in ipairs(delayed) do
        if t.delay == delay then out[#out + 1] = t end
      end
      return out
    end

    local function timeouts()
      return timers(refresh.BANK_PRIME_TIMEOUT)
    end

    -- prime calls back the load of a tab.
    local function prime(bag)
      for _, p in ipairs(primes) do
        if p.bags[1] == bag then
          p.cb()
          return
        end
      end
      error("no load of tab " .. tostring(bag))
    end

    -- waves lists the tab each read of the open read, in order.
    local function waves()
      local out = {}
      for _, r in ipairs(requests) do
        if r.bankWaveTab then out[#out + 1] = r.bankWaveTab end
      end
      return out
    end

    -- Asked: "finish our bank window show animation, before we start loading in bank info, just
    -- to prevent hitching" (refresh-scheduler.md §11).
    it("shows the bank at once, and loads it only once it has finished showing", function()
      fire("BANKFRAME_OPENED")
      assert.equal(1, shown)
      assert.is_true(addon.atBank)
      assert.is_function(onShown, "asks to hear when the window has finished showing")
      assert.equal(0, #primes, "loads nothing while the window shows")
      assert.equal(0, #timeouts())
      assert.equal(0, #requests)
      onShown()
      assert.equal(0, #requests)
      assert.are.same({}, loaded, "no tab loaded yet: a read of the bank reads nothing")
    end)

    -- The guild bank's tabs come from the server one at a time (GuildBank:Load); the bank's are all
    -- on the client, so their item data loads at once, each tab in a load of its own.
    it("loads every tab's item data at once, each in a load of its own, only tabs with slots", function()
      slotsOf[7] = 0
      fire("BANKFRAME_OPENED")
      onShown()
      local bags = {}
      for _, p in ipairs(primes) do
        assert.equal(1, #p.bags)
        bags[#bags + 1] = p.bags[1]
      end
      table.sort(bags)
      assert.are.same({ 6, 13 }, bags)
      assert.equal(1, #timeouts())
    end)

    -- window.md §3c: the classic bank goes by its saved position while its tabs read in.
    describe("telling the bags when an open starts and when its reads are done", function()
      local said, savedSend

      before_each(function()
        said = {}
        savedSend = events.SendMessage
        events.SendMessage = function(self, ctx, message, ...)
          if message == "bags/BankOpening" or message == "bags/BankLoaded" then
            table.insert(said, { message = message, shown = shown, waves = #waves() })
          end
          return savedSend(self, ctx, message, ...)
        end
      end)

      after_each(function()
        events.SendMessage = savedSend
      end)

      it("says it is opening before the window shows, and loaded once, after the last tab's read", function()
        fire("BANKFRAME_OPENED")
        assert.are.same({ { message = "bags/BankOpening", shown = 0, waves = 0 } }, said)
        onShown()
        prime(6)
        prime(7)
        assert.equal(1, #said, "tabs still to read")
        prime(13)
        assert.are.same({ 6, 7, 13 }, waves())
        assert.are.same({ message = "bags/BankLoaded", shown = 1, waves = 3 }, said[2])
        assert.equal(2, #said, "once")
      end)

      it("says it is loaded after the one read of a bank with no tab with slots", function()
        slotsOf = {}
        fire("BANKFRAME_OPENED")
        onShown()
        assert.equal("bags/BankLoaded", said[2].message)
        assert.equal(2, #said)
      end)

      it("says nothing more for an open that ended", function()
        fire("BANKFRAME_OPENED")
        onShown()
        prime(6)
        fire("BANKFRAME_CLOSED")
        prime(7)
        prime(13)
        assert.equal(1, #said)
      end)
    end)

    it("reads each tab once its item data has loaded, the shown one first, every read afresh", function()
      fire("BANKFRAME_OPENED")
      onShown()
      prime(7)
      assert.equal(0, #requests, "waits for the tab shown")
      prime(6)
      assert.are.same({ 6, 7 }, waves(), "then the next, as soon as the read before it has run")
      assert.is_true(requests[1].resetLayout)
      assert.equal("primed", requests[1].bankOpen)
      assert.is_true(requests[1].bank)
      assert.is_true(requests[2].resetLayout, "a layout kept from the tabs read so far would be wrong for the whole bank")
      assert.is_true(requests[1].tabArrived and requests[2].tabArrived, "and nothing travels: each read re-sorts everything")
      assert.are.same({ [6] = true, [7] = true }, loaded)
      prime(13)
      assert.are.same({ 6, 7, 13 }, waves())
      assert.is_nil(loaded, "every tab read: reads read every bank bag again")
      timeouts()[1].fn()
      timers(refresh.BANK_SHOW_TIMEOUT)[1].fn()
      assert.equal(3, #requests, "the timeouts do nothing once read")
      assert.equal(3, #primes)
    end)

    it("reads the shown tab's bank type first: the Warbank's tabs while it shows", function()
      warm = true
      addon.Bags.Bank.bankTab = 13
      fire("BANKFRAME_OPENED")
      onShown()
      assert.are.same({ 13, 6, 7 }, waves())
    end)

    it("reads the Blizzard tab shown first (tab mode), then the rest of its bank type", function()
      warm = true
      addon.Bags.Bank.blizzardBankTab = 7
      addon.Bags.Bank.bankTab = 7
      fire("BANKFRAME_OPENED")
      onShown()
      assert.are.same({ 7, 6, 13 }, waves())
    end)

    -- Choosing a guild bank tab while it loads moves that tab to the front (GuildBank:LoadTab).
    it("reads a tab chosen while it loads next", function()
      fire("BANKFRAME_OPENED")
      onShown()
      prime(6)
      addon.Bags.Bank.blizzardBankTab = 13
      addon.Bags.Bank.bankTab = 13
      prime(7)
      assert.are.same({ 6 }, waves(), "waits for the tab chosen")
      prime(13)
      assert.are.same({ 6, 13, 7 }, waves())
    end)

    it("reads one tab per read even when every tab's data is already loaded", function()
      warm = true
      local seen = {}
      local runRefresh = items.RunRefresh
      items.RunRefresh = function(_, _, kind)
        if kind == const.BAG_KIND.BANK then
          local copy = {}
          for bag in pairs(loaded or {}) do copy[#copy + 1] = bag end
          table.sort(copy)
          seen[#seen + 1] = table.concat(copy, ",")
        end
      end
      fire("BANKFRAME_OPENED")
      onShown()
      items.RunRefresh = runRefresh
      assert.are.same({ "6", "6,7", "6,7,13" }, seen)
    end)

    it("reads every tab when the data has not loaded in time, and a tab again when its data arrives", function()
      fire("BANKFRAME_OPENED")
      onShown()
      assert.equal(1, #timeouts())
      timeouts()[1].fn()
      assert.are.same({ 6, 7, 13 }, waves())
      assert.equal("timeout", requests[1].bankOpen)
      assert.is_true(requests[1].resetLayout)
      prime(7)
      assert.equal(4, #requests)
      assert.are.same({ bank = true, resetLayout = true, tabArrived = true }, requests[4],
        "read again, warm, afresh: its first read was cold")
      prime(6)
      assert.equal(5, #requests)
    end)

    it("reads a tab whose data arrives after the timeout but before its turn once, warm", function()
      fire("BANKFRAME_OPENED")
      onShown()
      -- The shown tab's read waits in the queue, so the other tabs wait their turn.
      refresh._held = true
      timeouts()[1].fn()
      assert.are.same({ 6 }, waves())
      prime(7)
      refresh._held = false
      refresh:RequestUpdate({ backpack = true })
      assert.are.same({ 6, 7, 13 }, waves())
      for _, r in ipairs(requests) do
        if r.bankWaveTab == 7 then
          assert.equal("primed", r.bankOpen, "tab 7 says its data had loaded")
        end
      end
      for _, r in ipairs(requests) do
        assert.is_false(r.bank == true and r.bankWaveTab == nil, "no read again for a tab read warm in its turn")
      end
    end)

    -- On Classic the bank, its bags, then the reagent bank (Enum.BagIndex.Reagentbank is -3).
    it("reads the bank, then its bags, then the reagent bank on Classic", function()
      warm = true
      local savedBankBagsConst = const.BANK_BAGS
      const.BANK_BAGS = { [-1] = -1, [6] = 6, [7] = 7 }
      const.ACCOUNT_BANK_BAGS = nil
      items.BankBags = function() return { [-1] = -1, [6] = 6, [7] = 7, [-3] = -3 } end
      slotsOf = { [-1] = 28, [6] = 4, [7] = 4, [-3] = 98 }
      addon.Bags.Bank.bankTab = -1
      fire("BANKFRAME_OPENED")
      onShown()
      const.BANK_BAGS = savedBankBagsConst
      assert.are.same({ -1, 6, 7, -3 }, waves())
    end)

    it("reads the bank once when it has no tab with slots (WoW: Forever before its first tab)", function()
      slotsOf = {}
      fire("BANKFRAME_OPENED")
      onShown()
      assert.equal(0, #primes)
      assert.equal(1, #requests)
      assert.is_number(requests[1].bankWave)
      requests[1].bankWave = nil
      assert.are.same({ bank = true, resetLayout = true, bankOpen = "empty" }, requests[1])
      assert.is_nil(loaded)
    end)

    it("lets the next tab load after a read that failed", function()
      warm = true
      local errors = 0
      local savedHandler = _G.geterrorhandler
      _G.geterrorhandler = function() return function() errors = errors + 1 end end
      local runRefresh = items.RunRefresh
      local failed = false
      items.RunRefresh = function(_, _, kind)
        if kind == const.BAG_KIND.BANK and not failed then
          failed = true
          error("a read that fails")
        end
      end
      fire("BANKFRAME_OPENED")
      onShown()
      items.RunRefresh = runRefresh
      _G.geterrorhandler = savedHandler
      assert.equal(1, errors)
      assert.are.same({ 6, 7, 13 }, waves())
    end)

    it("does not load or read for an open that has ended", function()
      fire("BANKFRAME_OPENED")
      local firstShown = onShown
      fire("BANKFRAME_CLOSED")
      firstShown()
      timers(refresh.BANK_SHOW_TIMEOUT)[1].fn()
      assert.equal(0, #primes, "closed while it showed")

      fire("BANKFRAME_OPENED")
      onShown()
      local first = primes
      primes = {}
      fire("BANKFRAME_CLOSED")
      assert.is_nil(loaded, "closing stops limiting reads to the tabs loaded")
      first[1].cb()
      assert.equal(0, #requests)

      fire("BANKFRAME_OPENED")
      onShown()
      for _, p in ipairs(first) do p.cb() end
      timeouts()[1].fn()
      assert.equal(0, #requests, "the old open's loads and timeout do nothing")
      prime(6)
      assert.are.same({ 6 }, waves())

      -- An open whose tabs were read before their data arrived, then closed: the data arriving
      -- later reads nothing, for this open or the next.
      fire("BANKFRAME_CLOSED")
      primes, requests = {}, {}
      fire("BANKFRAME_OPENED")
      onShown()
      timeouts()[#timeouts()].fn()
      local timedOut = primes
      primes = {}
      fire("BANKFRAME_CLOSED")
      fire("BANKFRAME_OPENED")
      onShown()
      local before = #requests
      for _, p in ipairs(timedOut) do p.cb() end
      assert.equal(before, #requests)
    end)

    -- The first read of an open that ended can still wait in the queue when the next open's first
    -- read arrives; the two merge. The merged read is the newer open's, or that open never loads
    -- its next tab.
    it("carries on loading when its first read merges into the last open's", function()
      fire("BANKFRAME_OPENED")
      onShown()
      refresh._held = true
      prime(6)
      fire("BANKFRAME_CLOSED")
      primes = {}
      fire("BANKFRAME_OPENED")
      onShown()
      warm = true
      prime(6)
      prime(7)
      prime(13)
      assert.equal(1, #refresh._queue, "merged")
      refresh._held = false
      refresh:RequestUpdate({ backpack = true })
      assert.are.same({ 6, 6, 7, 13 }, waves())
      assert.is_nil(loaded, "every tab read")
    end)

    it("stops loading tabs when the bank closes", function()
      fire("BANKFRAME_OPENED")
      onShown()
      prime(6)
      fire("BANKFRAME_CLOSED")
      prime(7)
      prime(13)
      assert.are.same({ 6 }, waves())
      assert.is_nil(loaded)
    end)

    -- Escape can hide the window mid-animation (its callback is dropped) while the bank stays
    -- open, and a theme's animation might never finish.
    it("loads anyway when the window never says it finished showing", function()
      fire("BANKFRAME_OPENED")
      assert.equal(1, #timers(refresh.BANK_SHOW_TIMEOUT))
      assert.is_true(refresh.BANK_SHOW_TIMEOUT >= 0.45 and refresh.BANK_SHOW_TIMEOUT < refresh.BANK_PRIME_TIMEOUT)
      timers(refresh.BANK_SHOW_TIMEOUT)[1].fn()
      assert.equal(3, #primes)
      onShown()
      assert.equal(3, #primes, "loads once")
    end)

    it("says why each open stopped waiting for its window, for profiler traces", function()
      spy.on(refresh, "_BankShown")
      fire("BANKFRAME_OPENED")
      onShown()
      timers(refresh.BANK_SHOW_TIMEOUT)[1].fn()
      assert.spy(refresh._BankShown).was.returned_with("loading")
      assert.spy(refresh._BankShown).was.called_with(match.is_ref(refresh), match._, "finished")
      assert.spy(refresh._BankShown).was.returned_with("already")
      fire("BANKFRAME_CLOSED")
      fire("BANKFRAME_OPENED")
      local stale = timers(refresh.BANK_SHOW_TIMEOUT)[1]
      fire("BANKFRAME_CLOSED")
      stale.fn()
      assert.spy(refresh._BankShown).was.returned_with("ended")
      refresh._BankShown:revert()
    end)

    it("loads at once without a bank window (Enable Bank Bags off)", function()
      addon.Bags = {}
      fire("BANKFRAME_OPENED")
      assert.equal(3, #primes)
    end)

    -- Nothing reads the bank while its window shows: the open's reads, which follow, read every
    -- bank tab after, so a bank sweep asked for meanwhile is covered. The backpack is not held.
    it("sweeps no bank while its window shows, and the backpack as usual", function()
      warm = true
      spy.on(items, "RunRefresh")
      fire("BANKFRAME_OPENED")
      refresh:RequestUpdate({ backpack = true, bank = true, bags = { [6] = true } })
      refresh:RequestUpdate({ wipe = true })
      assert.spy(items.RunRefresh).was.called_with(items, match._, const.BAG_KIND.BACKPACK)
      assert.spy(items.RunRefresh).was_not.called_with(items, match._, const.BAG_KIND.BANK)
      onShown()
      assert.spy(items.RunRefresh).was.called_with(items, match._, const.BAG_KIND.BANK)
      refresh:RequestUpdate({ bank = true, bags = { [6] = true } })
      local bankSweeps = 0
      for _, call in ipairs(items.RunRefresh.calls) do
        if call.vals[3] == const.BAG_KIND.BANK then bankSweeps = bankSweeps + 1 end
      end
      assert.equal(4, bankSweeps, "a read per tab, then sweeps as usual")
      items.RunRefresh:revert()
    end)

    it("sweeps the bank again once the bank closes during the animation and reopens", function()
      warm = true
      spy.on(items, "RunRefresh")
      fire("BANKFRAME_OPENED")
      fire("BANKFRAME_CLOSED")
      fire("BANKFRAME_OPENED")
      onShown()
      assert.spy(items.RunRefresh).was.called_with(items, match._, const.BAG_KIND.BANK)
      items.RunRefresh:revert()
    end)
  end)

  it("should trigger a bank update on PLAYERBANKSLOTS_CHANGED for non-retail", function()
    addon.isRetail = false
    refresh:OnEnable()
    spy.on(refresh, "RequestUpdate")
    local eventMap = events._eventMap
    assert.is_not_nil(eventMap["PLAYERBANKSLOTS_CHANGED"])
    eventMap["PLAYERBANKSLOTS_CHANGED"].fn("PLAYERBANKSLOTS_CHANGED")
    assert.spy(refresh.RequestUpdate).was.called_with(match._, { bank = true, bags = { [-1] = true } })
    assert.same({ [-1] = true }, unreadBags)
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
    assert.same({ [6] = true, [7] = true }, unreadBags)
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

  -- The guild bank opens as the bank does (guild-bank.md §3): its window shows at once, its tabs
  -- load once the window has finished showing, and each tab is read once its items' data has loaded.
  describe("the guild bank", function()
    local GUILD = 2
    local guildBank, shown, onShown, primes, savedBagKind, savedPrimeGuildBank, loads, loadedTabs

    local function send(message, ...)
      events:SendMessage(addon:GetModule("Context"):New("test"), message, ...)
    end

    local function timers(delay)
      local out = {}
      for _, t in ipairs(delayed) do
        if t.delay == delay then out[#out + 1] = t end
      end
      return out
    end

    before_each(function()
      events:Init()
      savedBagKind = const.BAG_KIND
      const.BAG_KIND = { UNDEFINED = -1, BACKPACK = 0, BANK = 1, GUILD = GUILD }
      guildBank = StubBetterBagsModule("GuildBank")
      loads, loadedTabs = 0, {}
      guildBank.Load = function() loads = loads + 1 return true end
      guildBank.LoadedContainers = function()
        local out = {}
        for _, tab in ipairs(loadedTabs) do out[1000 + tab] = 1000 + tab end
        return out
      end
      guildBank.TabOf = function(_, container) return container - 1000 end
      shown, onShown, primes = 0, nil, {}
      savedPrimeGuildBank = loader.PrimeGuildBank
      loader.PrimeGuildBank = function(_, tabs, cb)
        table.insert(primes, { tabs = tabs, cb = cb })
      end
      addon.Bags = { GuildBank = { Show = function(_, _, _, cb)
        shown = shown + 1
        onShown = cb
      end } }
      refresh:OnEnable()
      refresh:_WorldRead(refresh._world, "primed")
      spy.on(refresh, "RequestUpdate")
    end)

    after_each(function()
      refresh.RequestUpdate:revert()
      loader.PrimeGuildBank = savedPrimeGuildBank
      const.BAG_KIND = savedBagKind
      addon.atGuildBank = nil
    end)

    -- What the nth read asked for, and how many it has asked for.
    local function asked(n)
      return refresh.RequestUpdate.calls[n].vals[2]
    end

    local function reads()
      return #refresh.RequestUpdate.calls
    end

    local function open()
      addon.atGuildBank = true
      send("guildbank/Opened")
    end

    it("shows the guild bank at once, and loads its tabs only once it has finished showing", function()
      open()
      assert.equal(1, shown)
      assert.equal(0, loads, "loads nothing while the window shows")
      onShown()
      assert.equal(1, loads)
      timers(refresh.GUILD_SHOW_TIMEOUT)[1].fn()
      assert.equal(1, loads, "the timeout does nothing once loading")
    end)

    it("loads anyway when the window never says it finished showing", function()
      open()
      timers(refresh.GUILD_SHOW_TIMEOUT)[1].fn()
      assert.equal(1, loads)
      onShown()
      assert.equal(1, loads)
    end)

    it("does nothing without a guild bank window (the classic bags: Blizzard's frame shows it)", function()
      addon.Bags = {}
      open()
      assert.equal(0, loads)
      send("guildbank/TabLoaded", 1)
      assert.equal(0, #primes)
    end)

    -- Whether a read starts the layout afresh is the read's to find: it does when a tab's items first appear in it.
    it("reads each tab once its items' data has loaded", function()
      open()
      onShown()
      send("guildbank/TabLoaded", 2)
      assert.are.same({ 2 }, primes[1].tabs)
      assert.spy(refresh.RequestUpdate).was_not.called()
      primes[1].cb()
      assert.are.same({ guild = true, guildLoad = "primed" }, asked(1))
      send("guildbank/TabLoaded", 1)
      primes[2].cb()
      assert.are.same({ guild = true, guildLoad = "primed" }, asked(2))
      assert.equal(2, reads())
    end)

    it("reads a tab whose data has not loaded in time, and again when it arrives", function()
      open()
      onShown()
      send("guildbank/TabLoaded", 2)
      timers(refresh.GUILD_PRIME_TIMEOUT)[1].fn()
      assert.are.same({ guild = true, guildLoad = "timeout" }, asked(1))
      primes[1].cb()
      assert.are.same({ guild = true }, asked(2), "the read that warms it finds that for itself")
      assert.equal(2, reads())
    end)

    -- A change is another player moving an item: it keeps the layout, gaps and all, once the visit has read something.
    it("keeps the layout for a change after a tab has loaded, and for its read again", function()
      open()
      onShown()
      send("guildbank/TabLoaded", 2)
      primes[1].cb()
      loadedTabs = { 2 }
      send("guildbank/Changed")
      timers(refresh.GUILD_PRIME_TIMEOUT)[2].fn()
      assert.are.same({ guild = true, guildLoad = "timeout" }, asked(2))
      primes[2].cb()
      assert.are.same({ guild = true }, asked(3))
      assert.equal(3, reads())
    end)

    it("reads the loaded tabs when the guild bank changes, not while its window shows", function()
      open()
      send("guildbank/Changed")
      assert.equal(0, #primes)
      onShown()
      loadedTabs = { 3, 1 }
      send("guildbank/Changed")
      assert.are.same({ 1, 3 }, primes[1].tabs)
      primes[1].cb()
      assert.are.same({ guild = true, guildLoad = "primed" }, asked(1))
      send("guildbank/Changed")
      primes[2].cb()
      assert.are.same({ guild = true, guildLoad = "primed" }, asked(2))
    end)

    it("reads when its tabs change (names, permissions)", function()
      open()
      onShown()
      send("guildbank/TabsChanged")
      assert.spy(refresh.RequestUpdate).was.called_with(match._, { guild = true })
    end)

    it("does nothing for a visit that has ended", function()
      open()
      local stale = onShown
      send("guildbank/Closed")
      stale()
      assert.equal(0, loads)
      open()
      onShown()
      send("guildbank/TabLoaded", 1)
      local first = primes[1].cb
      send("guildbank/Closed")
      first()
      timers(refresh.GUILD_PRIME_TIMEOUT)[1].fn()
      assert.spy(refresh.RequestUpdate).was_not.called()
    end)

    it("forgets the guild bank's items when it closes", function()
      spy.on(items, "ClearGuildBankCache")
      open()
      send("guildbank/Closed")
      assert.spy(items.ClearGuildBankCache).was.called(1)
      items.ClearGuildBankCache:revert()
    end)

    it("sweeps the guild bank only while it is open and its window has shown, after the bank", function()
      spy.on(items, "RunRefresh")
      refresh:RequestUpdate({ guild = true })
      assert.spy(items.RunRefresh).was_not.called_with(items, match._, GUILD)
      open()
      refresh:RequestUpdate({ guild = true })
      assert.spy(items.RunRefresh).was_not.called_with(items, match._, GUILD)
      onShown()
      refresh:RequestUpdate({ guild = true, backpack = true })
      assert.spy(items.RunRefresh).was.called_with(items, match._, GUILD)
      local calls = items.RunRefresh.calls
      assert.are.equal(GUILD, calls[#calls - 1].vals[3], "before the backpack")
      items.RunRefresh:revert()
    end)

    it("reads the open guild bank on a wipe", function()
      spy.on(items, "RunRefresh")
      open()
      onShown()
      refresh:RequestUpdate({ wipe = true })
      assert.spy(items.RunRefresh).was.called_with(items, match._, GUILD)
      items.RunRefresh:revert()
    end)

    it("recalculates the guild bank when asked, and with every kind when none is named", function()
      send("bags/Rederive", { guild = true })
      assert.spy(refresh.RequestUpdate).was.called_with(match._, { derive = true, guild = true })
      send("bags/Rederive")
      assert.spy(refresh.RequestUpdate).was.called_with(match._, { derive = true, backpack = true, bank = true, guild = true })
    end)
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

    it("sweeps nothing from the fallback when the sort left nothing to show", function()
      _G.C_Container = _G.C_Container or {}
      _G.C_Container.SortBags = function() end
      spy.on(items, "RunRefresh")

      refresh:RequestUpdate({ sort = true })
      sortLeaves = "nothing"
      delayed[1].fn()

      assert.spy(items.RunRefresh).was_not.called()
      assert.is_false(items:IsSortSweepPending(const.BAG_KIND.BACKPACK))
    end)

    it("recalculates from the fallback, showing the sort, when that is all it left", function()
      _G.C_Container = _G.C_Container or {}
      _G.C_Container.SortBags = function() end
      local seen
      items.RunRefresh = function(_, ectx, kind)
        seen = { kind = kind, derive = ectx:Get("derive"), showsSort = ectx:Get("showsSort"),
          categoriesUnchanged = ectx:Get("categoriesUnchanged") }
      end

      refresh:RequestUpdate({ sort = true })
      sortLeaves = "recalculate"
      delayed[1].fn()
      items.RunRefresh = function() end

      assert.are.same({ kind = const.BAG_KIND.BACKPACK, derive = true, showsSort = true, categoriesUnchanged = true }, seen)
      assert.is_true(items:IsSortSweepPending(const.BAG_KIND.BACKPACK), "the sweep (stubbed here) is what clears it")
    end)

    it("reads from the fallback when that is what the sort left", function()
      _G.C_Container = _G.C_Container or {}
      _G.C_Container.SortBags = function() end
      local seen
      items.RunRefresh = function(_, ectx) seen = ectx:Get("derive") == true end

      refresh:RequestUpdate({ sort = true })
      delayed[1].fn()
      items.RunRefresh = function() end

      assert.is_false(seen)
    end)

    it("calls each sort through a function the profiler measures, by name", function()
      _G.C_Container = _G.C_Container or {}
      _G.C_Container.SortBags = function() end
      local original, seen = refresh._CallSorter, {}
      refresh._CallSorter = function(self, name, sorter)
        table.insert(seen, { name, sorter })
        return original(self, name, sorter)
      end

      refresh:RequestUpdate({ sort = true })
      refresh._CallSorter = original

      assert.are.same({ { "backpack", _G.C_Container.SortBags } }, seen)
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

  -- Settings that only change how the bags look redraw the committed data: no bag is read
  -- and nothing is derived (refresh-scheduler.md §9).
  describe("redraw-only settings", function()
    local draws

    local function bag(name, shown)
      return {
        IsShown = function() return shown end,
        Draw = function(_, _, slotInfo, callback)
          table.insert(draws, { name = name, slotInfo = slotInfo })
          if callback then callback() end
        end,
      }
    end

    local function newContext()
      return addon:GetModule("Context"):New("Test")
    end

    before_each(function()
      draws = {}
      items.slotInfo = { [const.BAG_KIND.BACKPACK] = { kind = "backpack" }, [const.BAG_KIND.BANK] = { kind = "bank" } }
      items.GetAllSlotInfo = function(self) return self.slotInfo end
      addon.Bags = { Backpack = bag("backpack", false), Bank = bag("bank", false) }
    end)

    it("draws the backpack from its committed data and reads no bag", function()
      spy.on(items, "RunRefresh")
      refresh:Redraw(newContext())
      assert.spy(items.RunRefresh).was_not.called()
      assert.equal(1, #draws)
      assert.equal("backpack", draws[1].name)
      assert.equal(items.slotInfo[const.BAG_KIND.BACKPACK], draws[1].slotInfo)
    end)

    it("draws the bank too while it is shown", function()
      addon.Bags.Bank = bag("bank", true)
      refresh:Redraw(newContext())
      assert.equal(2, #draws)
      assert.equal("bank", draws[2].name)
      assert.equal(items.slotInfo[const.BAG_KIND.BANK], draws[2].slotInfo)
    end)

    it("restyles the item buttons when asked, so they draw in full", function()
      local itemFrame, created = StubBetterBagsModule("ItemFrame")
      local restyled = 0
      local original = itemFrame.RestyleButtons
      itemFrame.RestyleButtons = function() restyled = restyled + 1 end
      refresh:Redraw(newContext(), true)
      refresh:Redraw(newContext())
      itemFrame.RestyleButtons = original
      if created then ResetModuleStub("ItemFrame") end
      assert.equal(1, restyled)
    end)

    it("routes bags/Redraw to Redraw, passing whether buttons restyle", function()
      refresh:OnEnable()
      stub(refresh, "Redraw")
      finally(function() refresh.Redraw:revert() end)
      events:SendMessage(newContext(), "bags/Redraw", { buttons = true })
      assert.spy(refresh.Redraw).was.called_with(match._, match._, true)
    end)

    -- Dragging a slider asks for a redraw on every value it passes, many per frame (a
    -- captured glow-intensity drag asked for 22 in one frame, each restyling every button).
    it("draws once on the next frame for every redraw asked for in a frame", function()
      local frame = {}
      -- Next-frame timers only: OnEnable's wait for the world keeps a timer of its own.
      _G.C_Timer.After = function(delay, fn) if delay == 0 then table.insert(frame, fn) end end
      refresh:OnEnable()
      -- Only the scheduling is checked here; drawing and restyling are covered above.
      stub(refresh, "Redraw")
      finally(function() refresh.Redraw:revert() end)
      events:SendMessage(newContext(), "bags/Redraw")
      events:SendMessage(newContext(), "bags/Redraw", { buttons = true })
      events:SendMessage(newContext(), "bags/Redraw")
      assert.spy(refresh.Redraw).was_not.called()
      assert.equal(1, #frame)
      frame[1]()
      assert.spy(refresh.Redraw).was.called(1)
      assert.spy(refresh.Redraw).was.called_with(match._, match._, true)

      -- The next frame's requests get their own draw, without the restyle.
      frame = {}
      events:SendMessage(newContext(), "bags/Redraw")
      assert.equal(1, #frame)
      frame[1]()
      assert.spy(refresh.Redraw).was.called(2)
      assert.spy(refresh.Redraw).was.called_with(match._, match._, false)
    end)
  end)
end)
