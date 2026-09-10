local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
local aceAddon = LibStub("AceAddon-3.0")

-- Regression coverage for the "warbank grey-out sticks after switching to the
-- Bank tab" bug.
--
-- Repro (retail): open bags, open bank on the Warbank group tab. Backpack items
-- that cannot go into the Warbank are correctly greyed. Click the Bank (Character)
-- group tab: the grey stays. Sorting the bags clears it.
--
-- Root cause: an item's dim/grey state is driven by the pre-computed
-- `data.itemContextMatchResult` (data/items.lua:ResolveItemContextMatchResult),
-- which is only re-resolved during a backpack data sweep (Phase6_EnrichData).
-- Switching bank group tabs (SwitchToGroup) or Blizzard bank tabs
-- (SwitchToBlizzardTab) updates the bank's active bankType and redraws ONLY the
-- bank, so the backpack keeps stale itemContextMatchResult values and its grey
-- never updates. Sorting works only because it forces a backpack refresh.
--
-- Fix: switching the active bank tab must request a backpack refresh so the
-- backpack context match is recomputed against the newly active bank type.
describe("Bank tab switch refreshes backpack item context grey-out", function()
  local oldModules = {}
  local oldAddons = {}
  local moduleNames = {
    "Localization", "Constants", "Events", "Items", "Database",
    "MoneyFrame", "Tabs", "Groups", "Context", "ContextMenu", "BankBehavior", "BankSlots"
  }

  local sentMessages
  local behavior

  before_each(function()
    -- Back up and clear the modules so we can load bank.lua fresh with our stubs.
    for _, name in ipairs(moduleNames) do
      oldModules[name] = addon.modules[name]
      oldAddons[name] = aceAddon.addons["BetterBags_" .. name]
      addon.modules[name] = nil
      aceAddon.addons["BetterBags_" .. name] = nil
    end

    -- WoW globals used by the retail bank tab switch paths.
    _G.Enum = _G.Enum or {}
    _G.Enum.BankType = { Character = 1, Account = 2 }
    _G.Enum.BagIndex = _G.Enum.BagIndex or {}
    _G.Enum.BagIndex.AccountBankTab_1 = 13
    _G.Enum.BagIndex.Characterbanktab = 6
    _G.BankPanel = { SetBankType = function() end }
    _G.ItemButtonUtil = _G.ItemButtonUtil or { Event = { ItemContextChanged = 1 }, TriggerEvent = function() end }

    addon.isRetail = true
    addon.atBank = true

    -- Localization stub.
    local L = StubBetterBagsModule("Localization")
    function L:G(key) return key end

    -- Constants stub.
    local const = StubBetterBagsModule("Constants")
    const.BAG_KIND = { BACKPACK = 0, BANK = 1, UNDEFINED = -1 }
    const.BANK_TAB = { BANK = -1, ACCOUNT_BANK_1 = 13 }
    const.OFFSETS = { BAG_LEFT_INSET = 0, BAG_RIGHT_INSET = 0 }

    -- Events stub records every SendMessage so tests can assert the refresh.
    sentMessages = {}
    local events = StubBetterBagsModule("Events")
    function events:SendMessage(_, message, ...)
      table.insert(sentMessages, message)
    end
    function events:RegisterEvent() end
    function events:RegisterMessage() end

    -- Items stub: provides slot info and a no-op refresh chokepoint.
    local items = StubBetterBagsModule("Items")
    function items:GetAllSlotInfo() return { [1] = {} } end

    -- Database stub with active group tracking.
    local database = StubBetterBagsModule("Database")
    database._activeGroup = {}
    function database:SetActiveGroup(kind, groupID) self._activeGroup[kind] = groupID end
    function database:GetActiveGroup(kind) return self._activeGroup[kind] end
    function database:GetShowBankTabs() return false end

    StubBetterBagsModule("MoneyFrame")
    StubBetterBagsModule("Tabs")
    StubBetterBagsModule("Context")
    StubBetterBagsModule("ContextMenu")

    -- Groups stub returns the two default retail bank groups.
    local groups = StubBetterBagsModule("Groups")
    groups._groups = {
      [2] = { id = 2, name = "Bank", bankType = _G.Enum.BankType.Character, isDefault = true },
      [3] = { id = 3, name = "Warbank", bankType = _G.Enum.BankType.Account, isDefault = true },
    }
    function groups:GetGroup(_, groupID) return self._groups[groupID] end

    -- Load the real BankBehavior module.
    ResetModuleStub("BankBehavior", "bags/bank.lua")
    LoadBetterBagsModule("bags/bank.lua")
    local bankBehavior = addon:GetModule("BankBehavior")

    -- Minimal fake bag with just the surface SwitchToGroup / SwitchToBlizzardTab use.
    local fakeBag = {
      currentItemCount = 0,
      bankTab = nil,
      blizzardBankTab = nil,
      Hide = function() end,
      SetTitle = function() end,
      Draw = function() end,
      tabs = { SetTabByID = function() end },
    }
    behavior = bankBehavior:Create(fakeBag)
  end)

  after_each(function()
    for _, name in ipairs(moduleNames) do
      addon.modules[name] = oldModules[name]
      aceAddon.addons["BetterBags_" .. name] = oldAddons[name]
    end
  end)

  local function refreshedBackpack()
    for _, message in ipairs(sentMessages) do
      if message == "bags/RefreshBackpack" then return true end
    end
    return false
  end

  it("SwitchToGroup requests a backpack refresh so stale grey is recomputed", function()
    local ctx = { Copy = function(self) return self end }
    behavior:SwitchToGroup(ctx, 2) -- switch to Character "Bank" group
    assert.is_true(refreshedBackpack(),
      "switching bank group tabs must send bags/RefreshBackpack so the backpack context grey-out recomputes")
  end)

  it("SwitchToBlizzardTab requests a backpack refresh and updates bankTab", function()
    local ctx = { Copy = function(self) return self end }
    behavior:SwitchToBlizzardTab(ctx, _G.Enum.BagIndex.Characterbanktab)
    assert.is_true(refreshedBackpack(),
      "switching Blizzard bank tabs must send bags/RefreshBackpack so the backpack context grey-out recomputes")
    assert.equal(_G.Enum.BagIndex.Characterbanktab, behavior.bag.bankTab,
      "SwitchToBlizzardTab must update bag.bankTab so ResolveItemContextMatchResult reads the active tab")
  end)

  it("does not request a backpack refresh when the bank is not open", function()
    addon.atBank = false
    local ctx = { Copy = function(self) return self end }
    behavior:SwitchToGroup(ctx, 2)
    assert.is_false(refreshedBackpack(),
      "no backpack refresh should be requested when the bank is closed")
  end)
end)
