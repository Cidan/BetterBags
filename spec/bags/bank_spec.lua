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

describe("Classic/Era Bank OnCreate Bag Slots Panel", function()
  local oldModules = {}
  local oldAddons = {}
  local aceAddon = LibStub("AceAddon-3.0")
  local moduleNames = {
    "Localization", "Constants", "Events", "Items", "Database",
    "MoneyFrame", "Tabs", "Groups", "Context", "ContextMenu", "BankBehavior", "BankSlots", "BagSlots"
  }
  local const
  local createPanelCalls

  before_each(function()
    for _, name in ipairs(moduleNames) do
      oldModules[name] = addon.modules[name]
      oldAddons[name] = aceAddon.addons["BetterBags_" .. name]
      addon.modules[name] = nil
      aceAddon.addons["BetterBags_" .. name] = nil
    end

    StubBetterBagsModule("Localization")
    StubBetterBagsModule("Events")
    StubBetterBagsModule("Items")
    StubBetterBagsModule("Database")
    StubBetterBagsModule("MoneyFrame")
    StubBetterBagsModule("Tabs")
    StubBetterBagsModule("Groups")
    StubBetterBagsModule("Context")
    StubBetterBagsModule("ContextMenu")

    const = StubBetterBagsModule("Constants")
    const.BAG_KIND = { BACKPACK = 0, BANK = 1, UNDEFINED = -1 }
    const.BANK_TAB = { BANK = -1 }

    createPanelCalls = {}
    local bagSlots = StubBetterBagsModule("BagSlots")
    bagSlots.CreatePanel = function(_, ctx, kind, bagFrame)
      local panel = { frame = CreateFrame("Frame") }
      function panel:IsShown() return self.frame:IsShown() end
      function panel:Show() self.frame:Show() end
      function panel:Hide() self.frame:Hide() end
      function panel:Draw() end
      table.insert(createPanelCalls, { ctx = ctx, kind = kind, bagFrame = bagFrame, panel = panel })
      return panel
    end
  end)

  after_each(function()
    for _, name in ipairs(moduleNames) do
      addon.modules[name] = oldModules[name]
      aceAddon.addons["BetterBags_" .. name] = oldAddons[name]
    end
  end)

  -- Loads the base bank behavior plus a client override fresh, creates a
  -- behavior for a mock bag, and runs its OnCreate.
  local function runBankOnCreate(overridePath)
    local loadBase = assert(loadfile("bags/bank.lua"))
    loadBase("BetterBags")
    local bank = addon:GetModule("BankBehavior")

    local fn, err = loadfile(overridePath)
    assert.is_not_nil(fn, "Failed to loadfile " .. overridePath .. ": " .. tostring(err))
    fn("BetterBags")

    local mockBag = {
      frame = CreateFrame("Frame"),
      Hide = function() end,
    }
    local behavior = bank:Create(mockBag)
    local ctx = {}

    assert.has_no.errors(function()
      behavior:OnCreate(ctx)
    end)

    return mockBag, ctx
  end

  -- The context menu's "Show Bags" entry is gated on bag.slots
  -- (frames/contextmenu.lua), so the bank must own a bag slots panel.
  local function assertBankSlotsPanel(mockBag, ctx, flavor)
    assert.are.equal(const.BANK_TAB.BANK, mockBag.bankTab)

    assert.is_not_nil(mockBag.slots, flavor .. " bank OnCreate must create the bag slots panel")
    assert.are.equal(1, #createPanelCalls, flavor .. " bank OnCreate must call BagSlots:CreatePanel exactly once")

    local call = createPanelCalls[1]
    assert.are.equal(ctx, call.ctx)
    assert.are.equal(const.BAG_KIND.BANK, call.kind)
    assert.are.equal(mockBag.frame, call.bagFrame)
    assert.are.equal(call.panel, mockBag.slots)
    assert.is_false(mockBag.slots.frame:IsShown(), flavor .. " bank slots panel must start hidden")
  end

  it("classic bank OnCreate creates a hidden BANK bag slots panel for 'Show Bags'", function()
    local mockBag, ctx = runBankOnCreate("bags/classic/bank.lua")
    assertBankSlotsPanel(mockBag, ctx, "classic")
  end)

  it("era bank OnCreate creates a hidden BANK bag slots panel for 'Show Bags'", function()
    local mockBag, ctx = runBankOnCreate("bags/era/bank.lua")
    assertBankSlotsPanel(mockBag, ctx, "era")
  end)
end)
