-- bank_tab_category_routing_spec.lua
-- Reproduction test suite for cross-tab category assignment bug between Character Bank and Warbank.

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
local mockData = require("spec.helpers.mock_data")

-- Required globals and enums for retail bank testing
addon.isRetail = true
addon.isClassic = false
addon.tocVersion = 110000

_G.ITEM_QUALITY0_DESC = "Poor"
_G.ITEM_QUALITY1_DESC = "Common"
_G.ITEM_QUALITY2_DESC = "Uncommon"
_G.ITEM_QUALITY3_DESC = "Rare"
_G.ITEM_QUALITY4_DESC = "Epic"
_G.ITEM_QUALITY5_DESC = "Legendary"
_G.ITEM_QUALITY6_DESC = "Artifact"
_G.ITEM_QUALITY7_DESC = "Heirloom"
_G.ITEM_QUALITY8_DESC = "WoWToken"

_G.EXPANSION_NAME0 = "Classic"
_G.EXPANSION_NAME1 = "Burning Crusade"
_G.EXPANSION_NAME2 = "Wrath of the Lich King"
_G.EXPANSION_NAME3 = "Cataclysm"
_G.EXPANSION_NAME4 = "Mists of Pandaria"
_G.EXPANSION_NAME5 = "Warlords of Draenor"
_G.EXPANSION_NAME6 = "Legion"
_G.EXPANSION_NAME7 = "Battle for Azeroth"
_G.EXPANSION_NAME8 = "Shadowlands"
_G.EXPANSION_NAME9 = "Dragonflight"
_G.EXPANSION_NAME10 = "The War Within"
_G.EXPANSION_NAME11 = "Midnight"

_G.LE_EXPANSION_CLASSIC = 0
_G.LE_EXPANSION_BURNING_CRUSADE = 1
_G.LE_EXPANSION_WRATH_OF_THE_LICH_KING = 2
_G.LE_EXPANSION_CATACLYSM = 3
_G.LE_EXPANSION_MISTS_OF_PANDARIA = 4
_G.LE_EXPANSION_WARLORDS_OF_DRAENOR = 5
_G.LE_EXPANSION_LEGION = 6
_G.LE_EXPANSION_BATTLE_FOR_AZEROTH = 7
_G.LE_EXPANSION_SHADOWLANDS = 8
_G.LE_EXPANSION_DRAGONFLIGHT = 9
_G.LE_EXPANSION_WAR_WITHIN = 10
_G.LE_EXPANSION_MIDNIGHT = 11

_G.Enum = _G.Enum or {}
_G.Enum.BankType = { Character = 0, Account = 2 }
_G.Enum.ItemClass = { Tradegoods = 7, Container = 1 }
_G.Enum.BagIndex = {
  Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4,
  ReagentBag = 5, Bank = -1, Reagentbank = -3,
  BankBag_1 = 6, BankBag_2 = 7, BankBag_3 = 8, BankBag_4 = 9,
  BankBag_5 = 10, BankBag_6 = 11, BankBag_7 = 12,
  Characterbanktab = 100, CharacterBankTab_1 = 101, CharacterBankTab_2 = 102,
  CharacterBankTab_3 = 103, CharacterBankTab_4 = 104, CharacterBankTab_5 = 105,
  CharacterBankTab_6 = 106,
  AccountBankTab_1 = 200, AccountBankTab_2 = 201, AccountBankTab_3 = 202,
  AccountBankTab_4 = 203, AccountBankTab_5 = 204,
}
_G.Enum.ItemQuality = {
  Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4,
  Legendary = 5, Artifact = 6, Heirloom = 7, WoWToken = 8,
  Good = 2, Standard = 1,
}
_G.Enum.InventoryType = {
  IndexHeadType = 1, IndexNeckType = 2, IndexShoulderType = 3,
  IndexBodyType = 4, IndexChestType = 5, IndexWaistType = 6,
  IndexLegsType = 7, IndexFeetType = 8, IndexWristType = 9,
  IndexHandType = 10, IndexFingerType = 11, IndexTrinketType = 12,
  IndexWeaponType = 13, IndexShieldType = 14, IndexRangedType = 15,
  IndexCloakType = 16, Index2HweaponType = 17, IndexTabardType = 18,
  IndexRobeType = 20, IndexWeaponmainhandType = 21,
  IndexWeaponoffhandType = 22, IndexHoldableType = 23,
  IndexThrownType = 25, IndexRangedrightType = 26,
}

_G.C_Item = _G.C_Item or {}
if not _G.C_Item.GetItemSubClassInfo then
  _G.C_Item.GetItemSubClassInfo = function() return "MockSubClass" end
end

_G.INVTYPE_HEAD = "Head"

-- Load required modules
StubBetterBagsModule("Debug")
local dbg = addon:GetModule("Debug")
dbg.Log = function() end
dbg.Inspect = function() end

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
local events = addon:GetModule("Events")
events:Init()

ResetModuleStub("Localization", "core/localization.lua")
LoadBetterBagsModule("core/localization.lua")

ResetModuleStub("Constants", "core/constants.lua")
LoadBetterBagsModule("core/constants.lua")

ResetModuleStub("Database", "core/database.lua")
LoadBetterBagsModule("core/database.lua")

ResetModuleStub("EquipmentSets", "data/equipmentsets.lua")
LoadBetterBagsModule("data/equipmentsets.lua")

ResetModuleStub("Categories", "data/categories.lua")
LoadBetterBagsModule("data/categories.lua")

ResetModuleStub("Groups", "data/groups.lua")
LoadBetterBagsModule("data/groups.lua")

LoadBetterBagsModule("util/trees/trees.lua")
LoadBetterBagsModule("util/trees/intervaltree.lua")
LoadBetterBagsModule("util/query.lua")

ResetModuleStub("Search", "data/search.lua")
LoadBetterBagsModule("data/search.lua")

ResetModuleStub("Stacks", "data/stacks.lua")
LoadBetterBagsModule("data/stacks.lua")

ResetModuleStub("Binding", "data/binding.lua")
LoadBetterBagsModule("data/binding.lua")

ResetModuleStub("TooltipScanner", "data/tooltip.lua")
LoadBetterBagsModule("data/tooltip.lua")

LoadBetterBagsModule("core/async.lua")

ResetModuleStub("Items", "data/items.lua")
LoadBetterBagsModule("data/items.lua")
LoadBetterBagsModule("data/slots.lua")

local context = addon:GetModule("Context")
local const = addon:GetModule("Constants")
local database = addon:GetModule("Database")
local groups = addon:GetModule("Groups")
local items = addon:GetModule("Items")
local categories = addon:GetModule("Categories")
local search = addon:GetModule("Search")
local async = addon:GetModule("Async")

-- Disable async yields in tests
async.Yield = function() end

describe("Bank tab category routing bug reproduction", function()
  local oldBetterBagsDB
  local oldBankBags, oldAccountBankBags

  before_each(function()
    oldBetterBagsDB = _G.BetterBagsDB
    oldBankBags = const.BANK_BAGS
    oldAccountBankBags = const.ACCOUNT_BANK_BAGS

    const.BANK_BAGS = { [-1] = -1, [6] = 6, [7] = 7 }
    const.ACCOUNT_BANK_BAGS = { [13] = 13, [14] = 14 }
  end)

  after_each(function()
    _G.BetterBagsDB = oldBetterBagsDB
    const.BANK_BAGS = oldBankBags
    const.ACCOUNT_BANK_BAGS = oldAccountBankBags
  end)

  it("reproduces the bug with isolated programmatic configuration", function()
    -- Initialize a clean database
    _G.BetterBagsDB = nil
    database:Init()
    groups:Init()
    categories:Init()
    items:Init()

    local ctx = context:New("IsolatedRepro")
    local BANK = const.BAG_KIND.BANK

    -- Setup groups as described by user:
    -- Group 1: Default Bank (Character, bankType = 0)
    -- Group 2: Default Warbank (Account, bankType = 2)
    -- Group 4: "ARMOR WEAPONS" on Warbank (bankType = 2)
    -- Group 6: "CRAFTING" on Warbank (bankType = 2)
    -- Group 9: "ARMOR WEAPONS" on Bank (bankType = 0)
    -- Group 10: "CRAFTING" on Bank (bankType = 0)
    database.data.profile.groups[BANK] = {
      [1] = { id = 1, name = "Bank", bankType = 0, isDefault = true, kind = BANK, order = 1 },
      [2] = { id = 2, name = "Warbank", bankType = 2, isDefault = true, kind = BANK, order = 2 },
      [4] = { id = 4, name = "ARMOR WEAPONS", bankType = 2, kind = BANK, order = 4 },
      [6] = { id = 6, name = "CRAFTING", bankType = 2, kind = BANK, order = 6 },
      [9] = { id = 9, name = "ARMOR WEAPONS", bankType = 0, kind = BANK, order = 9 },
      [10] = { id = 10, name = "CRAFTING", bankType = 0, kind = BANK, order = 10 },
    }
    database.data.profile.groupsEnabled[BANK] = true

    -- User drags "Head" section onto Warbank "ARMOR WEAPONS" tab (group 4)
    groups:AssignCategoryToGroup(ctx, BANK, "Head", 4)

    -- User drags "Mining - Midnight" onto Warbank "CRAFTING" tab (group 6)
    groups:AssignCategoryToGroup(ctx, BANK, "Mining - Midnight", 6)

    -- User drags "Mining - The War Within" onto Bank "CRAFTING" tab (group 10)
    groups:AssignCategoryToGroup(ctx, BANK, "Mining - The War Within", 10)

    -- Create fake items using mockData harness:
    -- 1. Character bank items (bagid 6):
    local charHelm = mockData.ItemData({
      bagid = 6,
      slotid = 1,
      slotkey = "6_1",
      kind = BANK,
      name = "Character Bank Helmet",
      category = "Head",
    })
    local charMidnightOre = mockData.ItemData({
      bagid = 6,
      slotid = 2,
      slotkey = "6_2",
      kind = BANK,
      name = "Character Bank Midnight Ore",
      category = "Mining - Midnight",
    })
    local charTWWOre = mockData.ItemData({
      bagid = 6,
      slotid = 3,
      slotkey = "6_3",
      kind = BANK,
      name = "Character Bank TWW Ore",
      category = "Mining - The War Within",
    })

    -- 2. Warbank items (bagid 13):
    local warHelm = mockData.ItemData({
      bagid = 13,
      slotid = 1,
      slotkey = "13_1",
      kind = BANK,
      name = "Warbank Helmet",
      category = "Head",
    })
    local warMidnightOre = mockData.ItemData({
      bagid = 13,
      slotid = 2,
      slotkey = "13_2",
      kind = BANK,
      name = "Warbank Midnight Ore",
      category = "Mining - Midnight",
    })
    local warTWWOre = mockData.ItemData({
      bagid = 13,
      slotid = 3,
      slotkey = "13_3",
      kind = BANK,
      name = "Warbank TWW Ore",
      category = "Mining - The War Within",
    })

    local sortedItems = { charHelm, charMidnightOre, charTWWOre, warHelm, warMidnightOre, warTWWOre }
    local itemData = {
      ["6_1"] = charHelm,
      ["6_2"] = charMidnightOre,
      ["6_3"] = charTWWOre,
      ["13_1"] = warHelm,
      ["13_2"] = warMidnightOre,
      ["13_3"] = warTWWOre,
    }

    -- Partition items into tabs via Phase 10
    local tabs = items:Phase10_PartitionIntoTabs(ctx, BANK, sortedItems, {}, {}, {}, itemData)

    -- Helper to find which tabs an item exists in
    local function findTabsForItem(slotkey)
      local tabList = {}
      for tabID, tab in pairs(tabs) do
        for _, item in ipairs(tab.items) do
          if item.slotkey == slotkey then
            table.insert(tabList, tabID)
          end
        end
      end
      return tabList
    end

    local charHelmTabs = findTabsForItem("6_1")
    local charMidnightOreTabs = findTabsForItem("6_2")
    local charTWWOreTabs = findTabsForItem("6_3")
    local warHelmTabs = findTabsForItem("13_1")
    local warMidnightOreTabs = findTabsForItem("13_2")
    local warTWWOreTabs = findTabsForItem("13_3")

    -- Warbank items assigned to Warbank groups (4 and 6) show up in their Warbank tabs:
    assert.are.same({ 4 }, warHelmTabs, "Warbank helm should be in Warbank Armor tab (4)")
    assert.are.same({ 6 }, warMidnightOreTabs, "Warbank Midnight ore should be in Warbank Crafting tab (6)")

    -- Character bank TWW ore assigned to Character bank group (10) shows up in Character bank tab:
    assert.are.same({ 10 }, charTWWOreTabs, "Character bank TWW ore should be in Bank Crafting tab (10)")

    -- With bankType-scoped routing:
    -- Character bank items whose category was assigned to a Warbank group (4 or 6)
    -- are safely preserved in the default Character Bank tab (1):
    assert.are.same({ 1 }, charHelmTabs, "Character bank helm should fall back to default Bank tab (1)")
    assert.are.same({ 1 }, charMidnightOreTabs, "Character bank Midnight ore should fall back to default Bank tab (1)")

    -- And conversely, Warbank items whose category was assigned to a Character bank group (10)
    -- are safely preserved in the default Warbank tab (2):
    assert.are.same({ 2 }, warTWWOreTabs, "Warbank TWW ore should fall back to default Warbank tab (2)")

    -- Now verify that assigning "Head" to Character Bank tab 9 works independently of Warbank tab 4:
    groups:AssignCategoryToGroup(ctx, BANK, "Head", 9)
    tabs = items:Phase10_PartitionIntoTabs(ctx, BANK, sortedItems, {}, {}, {}, itemData)
    charHelmTabs = findTabsForItem("6_1")
    warHelmTabs = findTabsForItem("13_1")

    assert.are.same({ 9 }, charHelmTabs, "Character bank helm should now be in Character Bank Armor tab (9)")
    assert.are.same({ 4 }, warHelmTabs, "Warbank helm should remain in Warbank Armor tab (4)")
  end)

  it("reproduces the bug using the user's actual SavedVariables file from ~/Downloads/BetterBags.lua", function()
    local dumpPath = "/home/antonio/Downloads/BetterBags.lua"
    local f = io.open(dumpPath, "r")
    if not f then
      pending("SavedVariables file not found at " .. dumpPath)
      return
    end
    f:close()

    _G.BetterBagsDB = nil
    dofile(dumpPath)

    database:Init()
    database.data:SetProfile("Default")
    groups:Init()
    categories:Init()
    items:Init()

    local ctx = context:New("UserDumpRepro")
    local BANK = const.BAG_KIND.BANK

    -- Create items matching the user's specific missing categories:
    -- 1. "Head" armor piece in Character Bank (user: "can't see any of the armor or weapon items in her bank")
    local charHelm = mockData.ItemData({
      bagid = 6,
      slotid = 1,
      slotkey = "6_1",
      kind = BANK,
      name = "User Character Bank Helm",
      category = "Head",
    })

    -- 2. "Mining - Midnight" in Character Bank (user: "can't see any of the Midnight crafting reagents in my bank")
    local charMidnightOre = mockData.ItemData({
      bagid = 6,
      slotid = 2,
      slotkey = "6_2",
      kind = BANK,
      name = "User Character Bank Midnight Ore",
      category = "Mining - Midnight",
    })

    -- 3. "Head" armor piece in Warbank
    local warHelm = mockData.ItemData({
      bagid = 13,
      slotid = 1,
      slotkey = "13_1",
      kind = BANK,
      name = "User Warbank Helm",
      category = "Head",
    })

    -- 4. "Mining - Midnight" in Warbank
    local warMidnightOre = mockData.ItemData({
      bagid = 13,
      slotid = 2,
      slotkey = "13_2",
      kind = BANK,
      name = "User Warbank Midnight Ore",
      category = "Mining - Midnight",
    })

    -- 5. "Mining - The War Within" in Warbank
    local warTWWOre = mockData.ItemData({
      bagid = 13,
      slotid = 3,
      slotkey = "13_3",
      kind = BANK,
      name = "User Warbank TWW Ore",
      category = "Mining - The War Within",
    })

    local sortedItems = { charHelm, charMidnightOre, warHelm, warMidnightOre, warTWWOre }
    local itemData = {
      ["6_1"] = charHelm,
      ["6_2"] = charMidnightOre,
      ["13_1"] = warHelm,
      ["13_2"] = warMidnightOre,
      ["13_3"] = warTWWOre,
    }

    local tabs = items:Phase10_PartitionIntoTabs(ctx, BANK, sortedItems, {}, {}, {}, itemData)

    local function findTabsForItem(slotkey)
      local tabList = {}
      for tabID, tab in pairs(tabs) do
        for _, item in ipairs(tab.items) do
          if item.slotkey == slotkey then
            table.insert(tabList, tabID)
          end
        end
      end
      return tabList
    end

    local charHelmTabs = findTabsForItem("6_1")
    local charMidnightOreTabs = findTabsForItem("6_2")
    local warHelmTabs = findTabsForItem("13_1")
    local warMidnightOreTabs = findTabsForItem("13_2")
    local warTWWOreTabs = findTabsForItem("13_3")

    -- Verify warbank items are in tab 4 (ARMOR WEAPONS) and tab 6 (CRAFTING)
    assert.are.same({ 4 }, warHelmTabs)
    assert.are.same({ 6 }, warMidnightOreTabs)

    -- Under the migrated configuration:
    -- 1. Character bank armor piece safely falls back to default Bank tab 1 instead of vanishing:
    assert.are.same({ 1 }, charHelmTabs, "User's Character Bank Helm is safely visible in Bank default tab (1)!")

    -- 2. Character bank Midnight reagent safely falls back to default Bank tab 1 instead of vanishing:
    assert.are.same({ 1 }, charMidnightOreTabs, "User's Character Bank Midnight Ore is safely visible in Bank default tab (1)!")

    -- 3. Warbank TWW reagent (which user assigned to Character Bank CRAFTING tab 10) safely falls back to Warbank default tab 2:
    assert.are.same({ 2 }, warTWWOreTabs, "User's Warbank TWW Ore is safely visible in Warbank default tab (2)!")
  end)

  it("fails the expected invariant: all physical bank items must belong to at least one bank tab", function()
    -- This test asserts what SHOULD happen (expected behavior):
    -- Every item in the character bank and warbank MUST appear in at least one tab of that container.
    -- This test FAILS under the current codebase, reproducing the bug as a TDD failure.
    local dumpPath = "/home/antonio/Downloads/BetterBags.lua"
    local f = io.open(dumpPath, "r")
    if not f then
      pending("SavedVariables file not found at " .. dumpPath)
      return
    end
    f:close()

    _G.BetterBagsDB = nil
    dofile(dumpPath)

    database:Init()
    database.data:SetProfile("Default")
    groups:Init()
    categories:Init()
    items:Init()

    local ctx = context:New("InvariantTest")
    local BANK = const.BAG_KIND.BANK

    local charHelm = mockData.ItemData({
      bagid = 6,
      slotid = 1,
      slotkey = "6_1",
      kind = BANK,
      name = "Character Bank Helm",
      category = "Head",
    })
    local charMidnightOre = mockData.ItemData({
      bagid = 6,
      slotid = 2,
      slotkey = "6_2",
      kind = BANK,
      name = "Character Bank Midnight Ore",
      category = "Mining - Midnight",
    })

    local sortedItems = { charHelm, charMidnightOre }
    local itemData = {
      ["6_1"] = charHelm,
      ["6_2"] = charMidnightOre,
    }

    local tabs = items:Phase10_PartitionIntoTabs(ctx, BANK, sortedItems, {}, {}, {}, itemData)

    local function isItemInAnyTab(slotkey)
      for _, tab in pairs(tabs) do
        for _, item in ipairs(tab.items) do
          if item.slotkey == slotkey then return true end
        end
      end
      return false
    end

    -- Expected invariant: Character bank items must NOT vanish into thin air
    -- Under the current codebase, both of these fail because the items are in 0 tabs!
    assert.is_true(isItemInAnyTab("6_1"), "Character bank helm should be visible in at least one bank tab")
    assert.is_true(isItemInAnyTab("6_2"), "Character bank Midnight ore should be visible in at least one bank tab")
  end)

  it("reproduces through the end-to-end items:ProcessRefresh pipeline", function()
    local dumpPath = "/home/antonio/Downloads/BetterBags.lua"
    local f = io.open(dumpPath, "r")
    if not f then
      pending("SavedVariables file not found at " .. dumpPath)
      return
    end
    f:close()

    _G.BetterBagsDB = nil
    dofile(dumpPath)

    database:Init()
    database.data:SetProfile("Default")
    groups:Init()
    categories:Init()
    search:Init()
    items:Init()

    local BANK = const.BAG_KIND.BANK
    items._firstLoad[BANK] = false

    local charHelm = mockData.ItemData({
      bagid = 6,
      slotid = 1,
      slotkey = "6_1",
      kind = BANK,
      name = "User Character Bank Helm",
      equipLoc = "INVTYPE_HEAD",
      category = "Head",
    })
    local charMidnightOre = mockData.ItemData({
      bagid = 6,
      slotid = 2,
      slotkey = "6_2",
      kind = BANK,
      name = "User Character Bank Midnight Ore",
      classID = 7,
      subclassID = 7,
      expacID = 11,
      category = "Mining - Midnight",
    })
    local warHelm = mockData.ItemData({
      bagid = 13,
      slotid = 1,
      slotkey = "13_1",
      kind = BANK,
      name = "User Warbank Helm",
      equipLoc = "INVTYPE_HEAD",
      category = "Head",
    })

    local fakeHarvest = {
      ["6_1"] = charHelm,
      ["6_2"] = charMidnightOre,
      ["13_1"] = warHelm,
    }

    local originalHarvest = items.Harvest
    items.Harvest = function()
      return fakeHarvest, {}
    end

    local ctx = context:New("ProcessRefreshRepro")
    ctx:Set("wipe", true)
    items:ProcessRefresh(ctx, BANK)
    items.Harvest = originalHarvest

    local slotInfo = items.slotInfo[BANK]
    assert.is_not_nil(slotInfo)
    assert.is_not_nil(slotInfo.tabs)

    -- In the committed slotInfo, the items were scanned and exist in itemsBySlotKey:
    assert.is_not_nil(slotInfo.itemsBySlotKey["6_1"], "Item 6_1 was harvested into itemsBySlotKey")
    assert.is_not_nil(slotInfo.itemsBySlotKey["6_2"], "Item 6_2 was harvested into itemsBySlotKey")
    assert.is_not_nil(slotInfo.itemsBySlotKey["13_1"], "Item 13_1 was harvested into itemsBySlotKey")

    local function inAnyTab(slotkey)
      for _, tab in pairs(slotInfo.tabs) do
        for _, item in ipairs(tab.items) do
          if item.slotkey == slotkey then return true end
        end
      end
      return false
    end

    -- Warbank helm is in tab 4 (Warbank Armor):
    assert.is_true(inAnyTab("13_1"), "Warbank helm is present in a bank tab")

    -- Character bank items are safely preserved in bank tabs (default tab 1):
    assert.is_true(inAnyTab("6_1"), "Character bank helm is visible in bank tabs!")
    assert.is_true(inAnyTab("6_2"), "Character bank Midnight ore is visible in bank tabs!")
  end)
end)
