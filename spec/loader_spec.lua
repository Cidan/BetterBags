-- loader_spec.lua -- Unit tests for data/loader.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Stub dependencies
local const = StubBetterBagsModule("Constants")
const.BACKPACK_BAGS = { [0] = 0, [1] = 1 }
const.BANK_BAGS = { [5] = 5 }
const.ACCOUNT_BANK_BAGS = { [10] = 10 }

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")

-- Stub C_Container.GetContainerNumSlots
_G.C_Container = _G.C_Container or {}
_G.C_Container.GetContainerNumSlots = function(bagID)
  return 2 -- Let's return 2 slots for each bag in tests
end

describe("ItemLoader", function()
  before_each(function()
    -- Reset stub/event registry
    local events = addon:GetModule("Events")
    events:Init()
  end)

  it("should initialize with static structures", function()
    -- Load the module
    LoadBetterBagsModule("data/loader.lua")
    local loader = addon:GetModule("ItemLoader")
    assert.is_not_nil(loader)

    loader:Init()
    assert.is_not_nil(loader.itemMixinsBySlotKey)
    assert.is_not_nil(loader.itemMixinsByBag)
    assert.is_not_nil(loader.bagUpdateCallbacks)
  end)

  it("should populate the static itemMixins cache on enable", function()
    local loader = addon:GetModule("ItemLoader")
    loader:Init()
    loader:OnEnable()

    -- Check that mixins were created for the mock bags (0, 1, 5, 10)
    -- Slots are 1 and 2 (as returned by GetContainerNumSlots)
    local mixin1 = loader:GetItemMixinFromSlotKey("0_1")
    assert.is_not_nil(mixin1)
    assert.are.equal(0, mixin1._bagID)
    assert.are.equal(1, mixin1._slotID)

    local mixin2 = loader:GetItemMixinFromSlotKey("5_2")
    assert.is_not_nil(mixin2)
    assert.are.equal(5, mixin2._bagID)
    assert.are.equal(2, mixin2._slotID)
  end)

  -- At startup the refresh scheduler holds the loader until the client has delivered the
  -- bags (refresh-scheduler.md §8): bag batches are only marked dirty, then dropped when the
  -- startup read covers them.
  it("holds bag batches while held and drops them on release", function()
    local loader = addon:GetModule("ItemLoader")
    loader:Init()
    loader:OnEnable()
    local calls = 0
    loader:TellMeWhenABagIsUpdated(function() calls = calls + 1 end)

    loader:Hold()
    local eventMap = addon:GetModule("Events")._eventMap
    eventMap["BAG_UPDATE"].fn("BAG_UPDATE", 0)
    eventMap["BAG_UPDATE_DELAYED"].fn("BAG_UPDATE_DELAYED")
    assert.equal(0, calls, "nothing is loaded while held")

    loader:Release()
    eventMap["BAG_UPDATE_DELAYED"].fn("BAG_UPDATE_DELAYED")
    assert.equal(0, calls, "the held batch was dropped")

    eventMap["BAG_UPDATE"].fn("BAG_UPDATE", 1)
    eventMap["BAG_UPDATE_DELAYED"].fn("BAG_UPDATE_DELAYED")
    assert.equal(1, calls, "batches after the release load as before")
  end)

  it("primes every managed bag and every equipped slot in one load, then calls back once", function()
    local loader = addon:GetModule("ItemLoader")
    loader:Init()
    loader:OnEnable()
    local bagCallbacks = 0
    loader:TellMeWhenABagIsUpdated(function() bagCallbacks = bagCallbacks + 1 end)

    local containers, added = 0, {}
    local originalCreate = _G.ContinuableContainer.Create
    _G.ContinuableContainer.Create = function()
      containers = containers + 1
      return {
        AddContinuable = function(_, mixin) table.insert(added, mixin) end,
        ContinueOnLoad = function(_, cb) cb() end,
      }
    end
    local primed = 0
    loader:PrimeAll(function() primed = primed + 1 end)
    _G.ContinuableContainer.Create = originalCreate

    assert.equal(1, containers)
    assert.equal(1, primed)
    assert.equal(0, bagCallbacks, "priming does not fan out to the bag-update callbacks")
    local bagSlots, equipped = 0, 0
    for _, mixin in ipairs(added) do
      if mixin._bagID then bagSlots = bagSlots + 1 else equipped = equipped + 1 end
    end
    -- Bags 0, 1, 5 and 10 have two slots each in this spec.
    assert.equal(8, bagSlots)
    assert.equal(INVSLOT_LAST_EQUIPPED - INVSLOT_FIRST_EQUIPPED + 1, equipped)
  end)

  -- Bank containers hold no slots until the bank opens, so PrimeAll at login cannot cover
  -- them; the bank primes on its own when it opens. A capture of opening the bank read 478 of
  -- 491 bank items before their data had loaded.
  it("primes every bank bag, and only bank bags, in one load, then calls back once", function()
    local loader = addon:GetModule("ItemLoader")
    loader:Init()
    loader:OnEnable()
    local bagCallbacks = 0
    loader:TellMeWhenABagIsUpdated(function() bagCallbacks = bagCallbacks + 1 end)

    local containers, added = 0, {}
    local originalCreate = _G.ContinuableContainer.Create
    _G.ContinuableContainer.Create = function()
      containers = containers + 1
      return {
        AddContinuable = function(_, mixin) table.insert(added, mixin) end,
        ContinueOnLoad = function(_, cb) cb() end,
      }
    end
    local primed = 0
    loader:PrimeBank(function() primed = primed + 1 end)
    _G.ContinuableContainer.Create = originalCreate

    assert.equal(1, containers)
    assert.equal(1, primed)
    assert.equal(0, bagCallbacks, "priming does not fan out to the bag-update callbacks")
    local bags = {}
    for _, mixin in ipairs(added) do
      bags[mixin._bagID] = (bags[mixin._bagID] or 0) + 1
    end
    -- Bank bag 5 and account bank bag 10 have two slots each in this spec.
    assert.same({ [5] = 2, [10] = 2 }, bags)
  end)

  it("should support registering callbacks for bag updates", function()
    local loader = addon:GetModule("ItemLoader")
    loader:Init()
    loader:OnEnable()

    local called = false
    loader:TellMeWhenABagIsUpdated(function(updatedBags)
      called = true
      assert.is_true(updatedBags[0])
    end)

    -- Let's simulate a BAG_UPDATE
    local events = addon:GetModule("Events")
    local eventMap = events._eventMap
    if eventMap["BAG_UPDATE"] then
      eventMap["BAG_UPDATE"].fn("BAG_UPDATE", 0)
    end

    -- Let's simulate BAG_UPDATE_DELAYED which should execute pending updates and callback
    if eventMap["BAG_UPDATE_DELAYED"] then
      eventMap["BAG_UPDATE_DELAYED"].fn("BAG_UPDATE_DELAYED")
    end

    assert.is_true(called)
  end)

  it("roots the work done when item data finishes loading under a span that records the bags", function()
    LoadBetterBagsModule("debug/perf/format.lua")
    local perf = addon:GetModule("Perf")
    local perfFormat = addon:GetModule("PerfFormat")
    local loader = addon:GetModule("ItemLoader")
    loader:Init()
    loader:OnEnable()
    local listener = addon:GetModule("PerfLoaderListener", true) or addon:NewModule("PerfLoaderListener")
    function listener:TOnLoaded() end
    loader:TellMeWhenABagIsUpdated(function(updatedBags) listener:TOnLoaded(updatedBags) end)

    -- Item data usually arrives later, from Blizzard's own item-load listener, outside any
    -- call of ours.
    local pending
    local originalCreate = _G.ContinuableContainer.Create
    _G.ContinuableContainer.Create = function()
      return { AddContinuable = function() end, ContinueOnLoad = function(_, cb) pending = cb end }
    end
    local now = 0
    perf:Init()
    perf:SetClock(function() return now end)
    perf:Start({ modules = { "PerfLoaderListener" }, prototypes = {}, includeRoot = false, calibrate = false,
      trace = true, traceArgs = true })
    loader.pendingBags = { [1] = true }
    loader:ProcessPendingBagUpdates()
    pending()
    local trace = perfFormat:OpenTrace(perf:Stop())
    _G.ContinuableContainer.Create = originalCreate

    local loaded, inner = trace:Get(1), trace:Get(2)
    assert.are.equal("[loaded] item data", loaded.name)
    assert.are.equal(1, loaded.depth)
    assert.are.equal("{[1]=true}", trace:Text(loaded.args))
    assert.are.equal("PerfLoaderListener.TOnLoaded", inner.name)
    assert.are.equal(2, inner.depth)
  end)
end)
