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

  it("should trigger a full update on OnEnable (Startup Refresh Gap)", function()
    spy.on(refresh, "RequestUpdate")
    refresh:OnEnable()
    assert.spy(refresh.RequestUpdate).was.called_with(refresh, { wipe = true, backpack = true, bank = true })
  end)

  it("should register bags/FullRefreshAll message and trigger full update", function()
    refresh:OnEnable()
    spy.on(refresh, "RequestUpdate")
    events:SendMessage("bags/FullRefreshAll")
    assert.spy(refresh.RequestUpdate).was.called_with(refresh, { wipe = true, backpack = true, bank = true })
  end)

  it("should handle combat gating and queue requests", function()
    -- Set to combat
    _G.InCombatLockdown = function() return true end
    addon.atBank = true
    addon.Bags = { Bank = { bankTab = 1 } }
    spy.on(items, "RefreshBackpack")
    spy.on(items, "RefreshBank")

    refresh:RequestUpdate({ backpack = true })
    assert.spy(items.RefreshBackpack).was_not.called()
    assert.is_not_nil(refresh.pendingRequest)
    assert.is_true(refresh.pendingRequest.backpack)

    refresh:RequestUpdate({ bank = true })
    assert.spy(items.RefreshBank).was_not.called()
    assert.is_true(refresh.pendingRequest.bank)

    refresh:OnEnable() -- registers PLAYER_REGEN_ENABLED

    -- Exit combat
    _G.InCombatLockdown = function() return false end

    local eventMap = events._eventMap
    assert.is_not_nil(eventMap["PLAYER_REGEN_ENABLED"])

    eventMap["PLAYER_REGEN_ENABLED"].fn("PLAYER_REGEN_ENABLED")

    assert.spy(items.RefreshBackpack).was.called(1)
    assert.spy(items.RefreshBank).was.called(1)
    assert.is_nil(refresh.pendingRequest)
  end)

  it("should trigger a full update on BAG_CONTAINER_UPDATE", function()
    refresh:OnEnable()
    spy.on(refresh, "RequestUpdate")
    local eventMap = events._eventMap
    assert.is_not_nil(eventMap["BAG_CONTAINER_UPDATE"])
    eventMap["BAG_CONTAINER_UPDATE"].fn("BAG_CONTAINER_UPDATE")
    assert.spy(refresh.RequestUpdate).was.called_with(refresh, { wipe = true, backpack = true, bank = true })
  end)

  it("should trigger a full update on EQUIPMENT_SETS_CHANGED", function()
    refresh:OnEnable()
    spy.on(refresh, "RequestUpdate")
    local eventMap = events._eventMap
    assert.is_not_nil(eventMap["EQUIPMENT_SETS_CHANGED"])
    eventMap["EQUIPMENT_SETS_CHANGED"].fn("EQUIPMENT_SETS_CHANGED")
    assert.spy(refresh.RequestUpdate).was.called_with(refresh, { wipe = true, backpack = true, bank = true })
  end)

  it("should trigger a bank update on PLAYERBANKSLOTS_CHANGED for non-retail", function()
    addon.isRetail = false
    refresh:OnEnable()
    spy.on(refresh, "RequestUpdate")
    local eventMap = events._eventMap
    assert.is_not_nil(eventMap["PLAYERBANKSLOTS_CHANGED"])
    eventMap["PLAYERBANKSLOTS_CHANGED"].fn("PLAYERBANKSLOTS_CHANGED")
    assert.spy(refresh.RequestUpdate).was.called_with(refresh, { wipe = true, bank = true })
    addon.isRetail = true -- reset
  end)

  it("should register bags/SortBackpack message and trigger sorting", function()
    refresh:OnEnable()
    spy.on(refresh, "RequestUpdate")
    events:SendMessage("bags/SortBackpack")
    assert.spy(refresh.RequestUpdate).was.called_with(refresh, { sort = true })
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
end)