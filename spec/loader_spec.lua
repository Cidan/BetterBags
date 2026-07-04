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
    events:OnInitialize()
  end)

  it("should initialize with static structures", function()
    -- Load the module
    LoadBetterBagsModule("data/loader.lua")
    local loader = addon:GetModule("ItemLoader")
    assert.is_not_nil(loader)

    loader:OnInitialize()
    assert.is_not_nil(loader.itemMixinsBySlotKey)
    assert.is_not_nil(loader.itemMixinsByBag)
    assert.is_not_nil(loader.bagUpdateCallbacks)
  end)

  it("should populate the static itemMixins cache on enable", function()
    local loader = addon:GetModule("ItemLoader")
    loader:OnInitialize()
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

  it("should support registering callbacks for bag updates", function()
    local loader = addon:GetModule("ItemLoader")
    loader:OnInitialize()
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
end)
