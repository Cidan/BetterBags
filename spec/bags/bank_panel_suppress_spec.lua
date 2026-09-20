-- bank_panel_suppress_spec.lua -- Blizzard BankPanel suppression when BetterBags takes over
-- the bank (bank open path). On WoW: Forever (Camelot) BankPanel.MoneyDisplay
-- (BankBagCostMoneyDisplayMixin) registers PLAYER_MONEY at login and stays registered because
-- BetterBags reparents BankFrame under a permanently-hidden frame -- registration is
-- independent of shown state, so hiding it cannot unregister it. It must be UnregisterEvent'd
-- directly, or a gold change while away from the bank crashes Blizzard's OnShowOrHideBagCost.

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

describe("BankPanel suppression (Camelot PLAYER_MONEY crash)", function()
  local bank
  local savedBankPanel
  local aceAddon = LibStub("AceAddon-3.0")
  local moduleNames = {
    "Localization", "Constants", "Events", "Items", "Database",
    "MoneyFrame", "Tabs", "Groups", "Context", "ContextMenu", "BankBehavior", "BankSlots"
  }
  local oldModules, oldAddons = {}, {}

  before_each(function()
    for _, name in ipairs(moduleNames) do
      oldModules[name] = addon.modules[name]
      oldAddons[name] = aceAddon.addons["BetterBags_" .. name]
      addon.modules[name] = nil
      aceAddon.addons["BetterBags_" .. name] = nil
    end

    StubBetterBagsModule("Localization")
    StubBetterBagsModule("Constants")
    StubBetterBagsModule("Events")
    StubBetterBagsModule("Items")
    StubBetterBagsModule("Database")
    StubBetterBagsModule("MoneyFrame")
    StubBetterBagsModule("Tabs")
    StubBetterBagsModule("Groups")
    StubBetterBagsModule("Context")
    StubBetterBagsModule("ContextMenu")

    loadfile("bags/bank.lua")("BetterBags")
    bank = addon:GetModule("BankBehavior")

    savedBankPanel = _G.BankPanel
  end)

  after_each(function()
    _G.BankPanel = savedBankPanel
    for _, name in ipairs(moduleNames) do
      addon.modules[name] = oldModules[name]
      aceAddon.addons["BetterBags_" .. name] = oldAddons[name]
    end
  end)

  local function makeFrame()
    local f = { shown = true, unregistered = {} }
    function f:Hide() self.shown = false end
    function f:Show() self.shown = true end
    function f:SetAlpha() end
    function f:EnableMouse() end
    function f:EnableKeyboard() end
    function f:UnregisterEvent(event) self.unregistered[event] = true end
    return f
  end

  it("unregisters Camelot BankPanel.MoneyDisplay's PLAYER_MONEY and hides the chrome", function()
    local panel = makeFrame()
    panel.MoneyDisplay = makeFrame()
    panel.MoneyFrame = makeFrame()
    panel.AutoDepositFrame = makeFrame()
    panel.Header = makeFrame()
    _G.BankPanel = panel

    bank:SuppressBlizzardBankPanel()

    assert.is_true(panel.MoneyDisplay.unregistered["PLAYER_MONEY"])
    assert.is_false(panel.MoneyFrame.shown)
    assert.is_false(panel.AutoDepositFrame.shown)
    assert.is_false(panel.Header.shown)
    -- The panel itself stays shown (invisibly) so GetActiveBankType works.
    assert.is_true(panel.shown)
  end)

  it("no-ops safely when BankPanel is absent", function()
    _G.BankPanel = nil
    assert.has_no.errors(function() bank:SuppressBlizzardBankPanel() end)
  end)

  it("no-ops safely on live retail where MoneyDisplay does not exist", function()
    local panel = makeFrame()
    panel.MoneyFrame = makeFrame()
    _G.BankPanel = panel
    assert.has_no.errors(function() bank:SuppressBlizzardBankPanel() end)
    assert.is_false(panel.MoneyFrame.shown)
    assert.is_nil(panel.MoneyDisplay)
  end)
end)
