local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

describe("Bank Module Loading and Classic Compatibility Tests", function()
  local oldModules = {}
  local oldAddons = {}
  local aceAddon = LibStub("AceAddon-3.0")
  local moduleNames = {
    "Localization", "Constants", "Events", "Items", "Database",
    "MoneyFrame", "Tabs", "Groups", "Context", "ContextMenu", "BankBehavior", "BankSlots"
  }

  before_each(function()
    -- Back up existing modules if any are registered, and then clear them
    for _, name in ipairs(moduleNames) do
      oldModules[name] = addon.modules[name]
      oldAddons[name] = aceAddon.addons["BetterBags_" .. name]
      addon.modules[name] = nil
      aceAddon.addons["BetterBags_" .. name] = nil
    end

    -- Ensure other dependent modules are stubbed so their GetModule calls succeed
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
    -- We do NOT stub BankSlots here to simulate a non-retail environment!
  end)

  after_each(function()
    -- Restore original modules to not affect other tests
    for _, name in ipairs(moduleNames) do
      addon.modules[name] = oldModules[name]
      aceAddon.addons["BetterBags_" .. name] = oldAddons[name]
    end
  end)

  it("should successfully load bags/bank.lua in Classic/TBC environments when BankSlots is not registered", function()
    -- Attempt to load bags/bank.lua directly
    local fn, err = loadfile("bags/bank.lua")
    assert.is_not_nil(fn, "Failed to loadfile bags/bank.lua: " .. tostring(err))

    -- Execute the chunk. In Classic/TBC where BankSlots is unregistered,
    -- this should NOT throw an error.
    assert.has_no.errors(function()
      fn("BetterBags")
    end)

    -- Verify that BankBehavior was registered successfully
    local bankBehavior = addon:GetModule("BankBehavior")
    assert.is_not_nil(bankBehavior)
  end)
end)
