-- warbound_deposit_spec.lua -- Depositing every warbound item into the Warbank (bags/bank.lua, BankBehavior), as
-- Blizzard's Deposit All Warbound Items button does (BankPanelItemDepositButtonMixin, BankFrame.lua): at once, unless
-- an item it would put in the Warbank can still be refunded, whose refund the deposit would end; then it asks first
-- (issue #750, .claude/rules/warbank-deposit.md).

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

describe("Warbound deposit (BankBehavior)", function()
  local bank
  local aceAddon = LibStub("AceAddon-3.0")
  local moduleNames = {
    "Localization", "Constants", "Events", "Items", "Database",
    "MoneyFrame", "Tabs", "Groups", "Context", "ContextMenu", "BankBehavior", "BankSlots"
  }
  local oldModules, oldAddons = {}, {}
  local saved = {}
  local ACCOUNT

  before_each(function()
    for _, name in ipairs(moduleNames) do
      oldModules[name] = addon.modules[name]
      oldAddons[name] = aceAddon.addons["BetterBags_" .. name]
      addon.modules[name] = nil
      aceAddon.addons["BetterBags_" .. name] = nil
    end
    for _, name in ipairs({ "Localization", "Constants", "Events", "Items", "Database", "MoneyFrame", "Tabs", "Groups",
      "Context", "ContextMenu" }) do
      StubBetterBagsModule(name)
    end
    loadfile("bags/bank.lua")("BetterBags")
    bank = addon:GetModule("BankBehavior")

    saved = {
      bagIndex = _G.Enum.BagIndex, numTotalBagFrames = _G.NUM_TOTAL_BAG_FRAMES, containerItems = _G._containerItems,
      refundable = _G._refundableLocations, allowed = _G._itemsAllowedInBankType, deposits = _G._autoDeposits,
      popup = _G._lastPopupShown,
    }
    -- Live retail: the backpack, 4 bag slots and the reagent bag, then the character and the Warbank's tabs.
    _G.Enum.BagIndex = { Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4, ReagentBag = 5,
      CharacterBankTab_1 = 6, AccountBankTab_1 = 12 }
    _G.NUM_TOTAL_BAG_FRAMES = 5
    _G._containerItems = {}
    _G._refundableLocations = {}
    _G._itemsAllowedInBankType = {}
    _G._autoDeposits = {}
    _G._lastPopupShown = nil
    ACCOUNT = Enum.BankType.Account
    _G._itemsAllowedInBankType[ACCOUNT] = {}
  end)

  after_each(function()
    _G.Enum.BagIndex = saved.bagIndex
    _G.NUM_TOTAL_BAG_FRAMES = saved.numTotalBagFrames
    _G._containerItems = saved.containerItems
    _G._refundableLocations = saved.refundable
    _G._itemsAllowedInBankType = saved.allowed
    _G._autoDeposits = saved.deposits
    _G._lastPopupShown = saved.popup
    for _, name in ipairs(moduleNames) do
      addon.modules[name] = oldModules[name]
      aceAddon.addons["BetterBags_" .. name] = oldAddons[name]
    end
  end)

  -- put places an item at bag, slot: one the Warbank takes (warbound), one that can still be refunded, or both.
  local function put(bag, slot, opts)
    _G._containerItems[bag] = _G._containerItems[bag] or {}
    _G._containerItems[bag][slot] = 1000 + slot
    local key = bag .. ":" .. slot
    _G._itemsAllowedInBankType[ACCOUNT][key] = opts.warbound == true
    _G._refundableLocations[key] = opts.refundable == true
  end

  it("deposits at once when nothing it would put in the Warbank can be refunded", function()
    put(0, 1, { warbound = true })
    put(1, 3, { refundable = true })
    local asked = 0
    assert.is_false(bank:WarboundDepositEndsRefunds())
    bank:DepositWarbound(function() asked = asked + 1 end)
    assert.are.same({ ACCOUNT }, _G._autoDeposits)
    assert.are.equal(0, asked)
  end)

  it("asks first when an item it would put in the Warbank can be refunded, and deposits only once accepted", function()
    put(0, 1, { warbound = true })
    put(5, 2, { warbound = true, refundable = true })
    local accept
    assert.is_true(bank:WarboundDepositEndsRefunds(), "the reagent bag is one of the bags")
    bank:DepositWarbound(function(deposit) accept = deposit end)
    assert.are.same({}, _G._autoDeposits)
    assert.is_function(accept)
    accept()
    assert.are.same({ ACCOUNT }, _G._autoDeposits)
  end)

  it("looks in the bags only, as Blizzard's button does, never in the bank", function()
    put(6, 1, { warbound = true, refundable = true })
    put(12, 1, { warbound = true, refundable = true })
    assert.is_false(bank:WarboundDepositEndsRefunds())
    bank:DepositWarbound(function() error("nothing in the bags ends a refund") end)
    assert.are.same({ ACCOUNT }, _G._autoDeposits)
  end)

  -- The classic bank asks with the question Blizzard's own button asks (StaticPopupDialogs in BankFrame.lua), which
  -- deposits once accepted.
  describe("at the classic bank", function()
    local behavior

    before_each(function()
      behavior = setmetatable({ bag = {} }, { __index = bank.proto })
    end)

    it("deposits at once when no refund would end", function()
      put(2, 4, { warbound = true })
      behavior:DepositWarboundItems()
      assert.are.same({ ACCOUNT }, _G._autoDeposits)
      assert.is_nil(_G._lastPopupShown)
    end)

    it("shows Blizzard's question first when a refund would end", function()
      put(2, 4, { warbound = true, refundable = true })
      behavior:DepositWarboundItems()
      assert.are.same({}, _G._autoDeposits)
      assert.are.equal("ACCOUNT_BANK_DEPOSIT_ALL_NO_REFUND_CONFIRM", _G._lastPopupShown.name)
      assert.are.same({ nil, nil, { bankType = ACCOUNT } }, _G._lastPopupShown.args)
    end)
  end)
end)
