-- close_bank_spec.lua -- addon.CloseBank hides Blizzard's BankPanel and its Camelot
-- MoneyDisplay in a taint-safe event context.
--
-- Regression (WoW: Forever / Camelot): BankPanel.MoneyDisplay (BankBagCostMoneyDisplayMixin,
-- the "cost of next bank tab" money frame) registers PLAYER_MONEY at login and stays
-- registered because BetterBags reparents BankFrame under a permanently-hidden frame, so the
-- normal close cascade never fires MoneyDisplay:OnHide to unregister it. Once a bank has been
-- visited (BankPanel.bankType set) a gold change while away from the bank ran Blizzard's
-- OnShowOrHideBagCost with a nil BankFrame bank type and crashed on FetchNumPurchasedBankTabs.
-- CloseBank runs on BANKFRAME_CLOSED (taint-safe), where BankPanel is already hidden; hiding
-- MoneyDisplay there fires its OnHide -> UnregisterFrameForEvents(PLAYER_MONEY).

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

describe("addon.CloseBank BankPanel/MoneyDisplay suppression", function()
  local aceAddon = LibStub("AceAddon-3.0")
  local moduleNames = { "Debug", "Events", "Context" }
  local oldModules, oldAddons = {}, {}
  local savedBankPanel, savedBags, savedEnum, savedCloseBank

  before_each(function()
    for _, name in ipairs(moduleNames) do
      oldModules[name] = addon.modules[name]
      oldAddons[name] = aceAddon.addons["BetterBags_" .. name]
      addon.modules[name] = nil
      aceAddon.addons["BetterBags_" .. name] = nil
    end
    local debug = StubBetterBagsModule("Debug")
    debug.Log = function() end
    local events = StubBetterBagsModule("Events")
    events.SendMessage = function() end
    StubBetterBagsModule("Context")

    savedEnum = _G.Enum
    _G.Enum = _G.Enum or {}
    _G.Enum.PlayerInteractionType = _G.Enum.PlayerInteractionType or {
      TradePartner = 1, Banker = 2, Merchant = 3, MailInfo = 4, Auctioneer = 5,
      GuildBanker = 6, VoidStorageBanker = 7, ScrappingMachine = 8, ItemUpgrade = 9,
      AccountBanker = 10,
    }

    savedCloseBank = addon.CloseBank
    loadfile("core/hooks.lua")("BetterBags")

    savedBankPanel = _G.BankPanel
    savedBags = addon.Bags
  end)

  after_each(function()
    _G.BankPanel = savedBankPanel
    addon.Bags = savedBags
    addon.CloseBank = savedCloseBank
    _G.Enum = savedEnum
    for _, name in ipairs(moduleNames) do
      addon.modules[name] = oldModules[name]
      aceAddon.addons["BetterBags_" .. name] = oldAddons[name]
    end
  end)

  local function frame()
    local f = { hidden = false, unregistered = {} }
    function f:Hide() self.hidden = true end
    function f:UnregisterEvent(event) self.unregistered[event] = true end
    return f
  end

  it("hides BankPanel and directly unregisters MoneyDisplay's PLAYER_MONEY on close", function()
    addon.Bags = { Bank = { Hide = function() end, SwitchToBankAndWipe = function() end } }
    local panel = frame()
    panel.MoneyDisplay = frame()
    _G.BankPanel = panel

    addon.CloseBank(nil, nil, nil)

    assert.is_true(panel.hidden)
    -- Registration is independent of shown state, so Hide() cannot unregister it; the
    -- event must be removed directly.
    assert.is_true(panel.MoneyDisplay.unregistered["PLAYER_MONEY"])
  end)

  it("no-ops on live retail where BankPanel has no MoneyDisplay", function()
    addon.Bags = { Bank = { Hide = function() end, SwitchToBankAndWipe = function() end } }
    local panel = frame()
    _G.BankPanel = panel

    assert.has_no.errors(function() addon.CloseBank(nil, nil, nil) end)
    assert.is_true(panel.hidden)
    assert.is_nil(panel.MoneyDisplay)
  end)

  it("does nothing when the close is for an interacting frame", function()
    addon.Bags = { Bank = { Hide = function() end, SwitchToBankAndWipe = function() end } }
    local panel = frame()
    panel.MoneyDisplay = frame()
    _G.BankPanel = panel

    addon.CloseBank(nil, nil, {}) -- interactingFrame ~= nil => early return

    assert.is_false(panel.hidden)
    assert.is_nil(panel.MoneyDisplay.unregistered["PLAYER_MONEY"])
  end)
end)
