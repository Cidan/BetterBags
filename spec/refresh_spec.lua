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
  local savedNewTimer

  before_each(function()
    refresh:OnInitialize()
    registeredCallback = nil

    savedNewTimer = _G.C_Timer.NewTimer
    _G.C_Timer.NewTimer = function(seconds, callback)
      _G.C_Timer._lastTimerCallback = callback
      return {
        Cancel = function()
          _G.C_Timer._lastTimerCallback = nil
        end
      }
    end
  end)

  after_each(function()
    _G.C_Timer.NewTimer = savedNewTimer
  end)

  it("should initialize with default states", function()
    assert.is_false(refresh.pendingBackpack)
    assert.is_false(refresh.pendingBank)
    assert.is_false(refresh.pendingWipe)
  end)

  it("should queue updates and debounce them via timer", function()
    spy.on(refresh, "ExecutePendingUpdates")

    refresh:RequestUpdate({ backpack = true, wipe = true })

    assert.is_true(refresh.pendingBackpack)
    assert.is_true(refresh.pendingWipe)
    assert.is_not_nil(refresh.debounceTimer)

    -- Force the timer to fire synchronously by calling its callback
    local callback = _G.C_Timer._lastTimerCallback
    assert.is_not_nil(callback)
    callback()

    assert.spy(refresh.ExecutePendingUpdates).was.called(1)
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
