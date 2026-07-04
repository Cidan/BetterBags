-- refresh_spec.lua -- Unit tests for data/refresh.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Ensure dependencies exist
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
local events = addon:GetModule("Events")
events:OnInitialize()

local const = StubBetterBagsModule("Constants")
const.BAG_KIND = { UNDEFINED = -1, BACKPACK = 0, BANK = 1 }
const.BANK_BAGS = { [6] = 6, [7] = 7 }
const.BACKPACK_BAGS = { [0] = 0, [1] = 1 }
const.BANK_TAB = { BANK = 1, REAGENT = 2, ACCOUNT_BANK_1 = 3 }

local debug = StubBetterBagsModule("Debug")
debug.Log = function() end

local items = StubBetterBagsModule("Items")
items.ClearItemCache = function() end
items.RefreshBackpack = function() end
items.RefreshBank = function() end

-- Mock ItemLoader
local loader = StubBetterBagsModule("ItemLoader")
local registeredCallback = nil
loader.TellMeWhenABagIsUpdated = function(_, cb)
  registeredCallback = cb
end

ResetModuleStub("Refresh", "data/refresh.lua")
LoadBetterBagsModule("data/refresh.lua")
local refresh = addon:GetModule("Refresh")

describe("Refresh Module", function()
  before_each(function()
    refresh:OnInitialize()
    registeredCallback = nil
    addon.atBank = false
    addon.Bags = {}
  end)

  it("should initialize with default states", function()
    assert.is_false(refresh.isSorting)
    assert.is_nil(refresh.pendingBackpack)
    assert.is_nil(refresh.pendingBank)
    assert.is_nil(refresh.pendingWipe)
    assert.is_nil(refresh.debounceTimer)
  end)

  it("should process RequestUpdate instantly and synchronously for backpack", function()
    spy.on(items, "RefreshBackpack")
    spy.on(items, "RefreshBank")

    refresh:RequestUpdate({ backpack = true })

    assert.spy(items.RefreshBackpack).was.called(1)
    assert.spy(items.RefreshBank).was_not.called()
  end)

  it("should process RequestUpdate instantly and synchronously for bank if at bank", function()
    addon.atBank = true
    addon.Bags = { Bank = { bankTab = 1 } }
    spy.on(items, "RefreshBackpack")
    spy.on(items, "RefreshBank")

    refresh:RequestUpdate({ bank = true })

    assert.spy(items.RefreshBank).was.called(1)
    assert.spy(items.RefreshBackpack).was_not.called()
  end)

  it("should process RequestUpdate instantly and synchronously for wipe", function()
    addon.atBank = true
    addon.Bags = { Bank = { bankTab = 1 } }
    spy.on(items, "ClearItemCache")
    spy.on(items, "RefreshBackpack")
    spy.on(items, "RefreshBank")

    refresh:RequestUpdate({ wipe = true })

    assert.spy(items.ClearItemCache).was.called(1)
    assert.spy(items.RefreshBackpack).was.called(1)
    assert.spy(items.RefreshBank).was.called(1)
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
end)