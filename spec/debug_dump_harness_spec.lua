-- debug_dump_harness_spec.lua -- Integration testing via live saved variables item dumps.

local dumpPath = "test.lua"
local f = io.open(dumpPath, "r")
if not f then
  describe("Debug Dump Harness [SKIPPED - test.lua not found]", function()
    it("should be skipped when test.lua is not present", function()
      pending("test.lua is not present in the repository root, skipping harness integration tests")
    end)
  end)
  return
end
f:close()

-- Load dependencies and setup BetterBags environment
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Required version flags
addon.isRetail = true
addon.isClassic = false
addon.isBCC = false
addon.isCata = false
addon.isMists = false
addon.isAnniversary = false
addon.isMidnight = false
addon.tocVersion = 110000

-- Define WoW quality descriptors and slot globals
_G.ITEM_QUALITY0_DESC = "Poor"
_G.ITEM_QUALITY1_DESC = "Common"
_G.ITEM_QUALITY2_DESC = "Uncommon"
_G.ITEM_QUALITY3_DESC = "Rare"
_G.ITEM_QUALITY4_DESC = "Epic"
_G.ITEM_QUALITY5_DESC = "Legendary"
_G.ITEM_QUALITY6_DESC = "Artifact"
_G.ITEM_QUALITY7_DESC = "Heirloom"
_G.ITEM_QUALITY8_DESC = "WoWToken"

_G.INVSLOT_HEAD = 1
_G.INVSLOT_NECK = 2
_G.INVSLOT_SHOULDER = 3
_G.INVSLOT_BODY = 4
_G.INVSLOT_CHEST = 5
_G.INVSLOT_WAIST = 6
_G.INVSLOT_LEGS = 7
_G.INVSLOT_FEET = 8
_G.INVSLOT_WRIST = 9
_G.INVSLOT_HAND = 10
_G.INVSLOT_FINGER1 = 11
_G.INVSLOT_FINGER2 = 12
_G.INVSLOT_TRINKET1 = 13
_G.INVSLOT_TRINKET2 = 14
_G.INVSLOT_BACK = 15
_G.INVSLOT_MAINHAND = 16
_G.INVSLOT_OFFHAND = 17
_G.INVSLOT_RANGED = 18
_G.INVSLOT_TABARD = 19

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

-- Define WoW Enums required by Constants and DB
_G.Enum = _G.Enum or {}
_G.Enum.BankType = { Character = 1, Account = 2 }
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

-- Load require modules in correct order
StubBetterBagsModule("Debug")
local dbg = addon:GetModule("Debug")
dbg.Log = function() end
dbg.Inspect = function() end

ResetModuleStub("Context", "core/context.lua")
LoadBetterBagsModule("core/context.lua")

ResetModuleStub("Events", "core/events.lua")
LoadBetterBagsModule("core/events.lua")
local events = addon:GetModule("Events")
events:OnInitialize()

ResetModuleStub("Localization", "core/localization.lua")
LoadBetterBagsModule("core/localization.lua")

ResetModuleStub("Constants", "core/constants.lua")
LoadBetterBagsModule("core/constants.lua")

ResetModuleStub("Database", "core/database.lua")
LoadBetterBagsModule("core/database.lua")
local DB = addon:GetModule("Database")

ResetModuleStub("EquipmentSets", "data/equipmentsets.lua")
LoadBetterBagsModule("data/equipmentsets.lua")
local equipmentSets = addon:GetModule("EquipmentSets")

ResetModuleStub("Categories", "data/categories.lua")
LoadBetterBagsModule("data/categories.lua")
local categories = addon:GetModule("Categories")

ResetModuleStub("Trees", "util/trees/trees.lua")
LoadBetterBagsModule("util/trees/trees.lua")
LoadBetterBagsModule("util/trees/intervaltree.lua")

ResetModuleStub("QueryParser", "util/query.lua")
LoadBetterBagsModule("util/query.lua")

ResetModuleStub("Search", "data/search.lua")
LoadBetterBagsModule("data/search.lua")
local search = addon:GetModule("Search")

ResetModuleStub("Stacks", "data/stacks.lua")
LoadBetterBagsModule("data/stacks.lua")

ResetModuleStub("Binding", "data/binding.lua")
LoadBetterBagsModule("data/binding.lua")

ResetModuleStub("TooltipScanner", "data/tooltip.lua")
LoadBetterBagsModule("data/tooltip.lua")
local tooltipScanner = addon:GetModule("TooltipScanner")

ResetModuleStub("Items", "data/items.lua")
LoadBetterBagsModule("data/items.lua")
LoadBetterBagsModule("data/slots.lua")
local items = addon:GetModule("Items")

-- Load setup helpers
local context = addon:GetModule("Context")
local const = addon:GetModule("Constants")

describe("Debug Dump Harness with test.lua", function()
  local oldBetterBagsDB

  before_each(function()
    -- Sandboxed database loading
    oldBetterBagsDB = _G.BetterBagsDB
    _G.BetterBagsDB = nil

    -- Load the user's high-fidelity SavedVariables dump
    dofile(dumpPath)

    -- Initialize database with loaded values
    DB:OnInitialize()
    tooltipScanner:OnInitialize()
    equipmentSets:OnInitialize()
    categories:OnInitialize()
    categories:OnEnable()
    search:OnInitialize()
    items:OnInitialize()
    items:OnEnable()
  end)

  after_each(function()
    -- Restore original database global
    _G.BetterBagsDB = oldBetterBagsDB
  end)

  it("should successfully initialize Database and read dump profiles", function()
    assert.is_not_nil(_G.BetterBagsDB)
    assert.is_not_nil(_G.BetterBagsDB.profiles)
    assert.is_not_nil(_G.BetterBagsDB.profiles.Default)
    assert.is_not_nil(_G.BetterBagsDB.profiles.Default.debugBackpackDump)

    -- Assert profile configuration loaded cleanly
    local currentProfile = DB:GetCurrentProfileName()
    assert.is_not_nil(currentProfile)
  end)

  it("should run the full items:ProcessRefresh pipeline using the dumped items", function()
    -- Set active profile to Default (where the dump resides)
    DB.data:SetProfile("Default")

    -- Retrieve the dumped items dictionary
    local dumpItems = _G.BetterBagsDB.profiles.Default.debugBackpackDump
    assert.is_not_nil(dumpItems)

    -- Mock items:Harvest to return the dumped items
    local originalHarvest = items.Harvest
    items.Harvest = function()
      return dumpItems, {}
    end

    local ctx = context:New("TestDumpRefresh")
    items:ProcessRefresh(ctx, const.BAG_KIND.BACKPACK)

    -- Restore harvest
    items.Harvest = originalHarvest

    -- Assert slotInfo structure was built successfully
    local slotInfo = items.slotInfo[const.BAG_KIND.BACKPACK]
    assert.is_not_nil(slotInfo)
    assert.is_not_nil(slotInfo.itemsBySlotKey)

    -- Verify specific item details from the dump are intact
    -- Item: Ruia's Musings, Part 2 (itemID: 265819)
    local item1 = slotInfo.itemsBySlotKey["1_25"]
    assert.is_not_nil(item1)
    assert.are.equal("Ruia's Musings, Part 2", item1.itemInfo.itemName)
    assert.are.equal(265819, item1.itemInfo.itemID)
    assert.are.equal("Midnight - Other", item1.itemInfo.category)

    -- Item: Light's Preservation (itemID: 241287)
    local item2 = slotInfo.itemsBySlotKey["1_3"]
    assert.is_not_nil(item2)
    assert.are.equal("Light's Preservation", item2.itemInfo.itemName)
    assert.are.equal(241287, item2.itemInfo.itemID)
    assert.are.equal("Midnight - Potions", item2.itemInfo.category)

    -- Item: Lucky Horseshoe (itemID: 198400)
    local item3 = slotInfo.itemsBySlotKey["2_3"]
    assert.is_not_nil(item3)
    assert.are.equal("Lucky Horseshoe", item3.itemInfo.itemName)
    assert.are.equal(198400, item3.itemInfo.itemID)
    assert.are.equal("Miscellaneous", item3.itemInfo.category)

    -- Ensure empty slots are also handled cleanly
    local emptySlot = slotInfo.itemsBySlotKey["5_25"]
    assert.is_not_nil(emptySlot)
    assert.is_true(emptySlot.isItemEmpty)
  end)

  it("should run the full physical harvesting (Phase 2), stacking (Phase 3), and search indexing (Phase 4) by mocking low-level C-level APIs with test.lua dump data", function()
    -- Set active profile to Default (where the dump resides)
    DB.data:SetProfile("Default")

    -- Retrieve the dumped items dictionary
    local dumpItems = _G.BetterBagsDB.profiles.Default.debugBackpackDump
    assert.is_not_nil(dumpItems)

    -- Save original API references
    local origGetContainerNumSlots = _G.C_Container.GetContainerNumSlots
    local origGetContainerItemID = _G.C_Container.GetContainerItemID
    local origGetContainerItemLink = _G.C_Container.GetContainerItemLink
    local origGetContainerItemInfo = _G.C_Container.GetContainerItemInfo
    local origGetContainerItemQuestInfo = _G.C_Container.GetContainerItemQuestInfo
    local origGetItemInfo = _G.C_Item.GetItemInfo
    local origGetDetailedItemLevelInfo = _G.C_Item.GetDetailedItemLevelInfo
    local origGetItemGUID = _G.C_Item.GetItemGUID

    -- Mock low-level APIs to pull data dynamically from test.lua dump
    _G.C_Container.GetContainerNumSlots = function(bagid)
      local maxSlot = 0
      for _, item in pairs(dumpItems) do
        if item.bagid == bagid then
          if item.slotid > maxSlot then
            maxSlot = item.slotid
          end
        end
      end
      return maxSlot > 0 and maxSlot or 0
    end

    _G.C_Container.GetContainerItemID = function(bagid, slotid)
      local slotkey = bagid .. "_" .. slotid
      local item = dumpItems[slotkey]
      if item and not item.isItemEmpty then
        return item.containerInfo.itemID
      end
      return nil
    end

    _G.C_Container.GetContainerItemLink = function(bagid, slotid)
      local slotkey = bagid .. "_" .. slotid
      local item = dumpItems[slotkey]
      if item and not item.isItemEmpty then
        return item.containerInfo.hyperlink
      end
      return nil
    end

    _G.C_Container.GetContainerItemInfo = function(bagid, slotid)
      local slotkey = bagid .. "_" .. slotid
      local item = dumpItems[slotkey]
      if item and not item.isItemEmpty then
        return item.containerInfo
      end
      return nil
    end

    _G.C_Container.GetContainerItemQuestInfo = function(bagid, slotid)
      local slotkey = bagid .. "_" .. slotid
      local item = dumpItems[slotkey]
      if item and not item.isItemEmpty then
        return item.questInfo
      end
      return nil
    end

    _G.C_Item.GetItemInfo = function(itemID)
      for _, item in pairs(dumpItems) do
        if item.containerInfo and item.containerInfo.itemID == itemID then
          local info = item.itemInfo
          return info.itemName, info.itemLink, info.itemQuality, info.itemLevel, info.itemMinLevel, info.itemType, info.itemSubType, info.itemStackCount, info.itemEquipLoc, info.itemIcon, info.sellPrice, info.classID, info.subclassID, info.bindType, info.expacID, info.setID, info.isCraftingReagent
        end
      end
      return nil
    end

    _G.C_Item.GetDetailedItemLevelInfo = function(itemID)
      for _, item in pairs(dumpItems) do
        if item.containerInfo and item.containerInfo.itemID == itemID then
          local info = item.itemInfo
          return info.effectiveIlvl or info.itemLevel, info.isPreview or false, info.baseIlvl or info.itemLevel
        end
      end
      return nil
    end

    _G.C_Item.GetItemGUID = function(_)
      return "MockGUID"
    end

    -- Run the full items:ProcessRefresh pipeline.
    -- This executes:
    --   - Phase 2 (Data Farming): Calls items:Harvest() which invokes our mocked C-level container APIs to scan and build physical ItemData.
    --   - Phase 3 (Virtual Stacks): Clears and resolves parent-child stacks.
    --   - Phase 4 (Search Indexing): Decoupled rebuild and ngram/fulltext indexing of items.
    --   - Phase 4.5 (Category & Data Enrichment): Assigns and priorities categories.
    local ctx = context:New("TestDumpEndToEndRefresh")
    items:ProcessRefresh(ctx, const.BAG_KIND.BACKPACK)

    -- Restore low-level APIs
    _G.C_Container.GetContainerNumSlots = origGetContainerNumSlots
    _G.C_Container.GetContainerItemID = origGetContainerItemID
    _G.C_Container.GetContainerItemLink = origGetContainerItemLink
    _G.C_Container.GetContainerItemInfo = origGetContainerItemInfo
    _G.C_Container.GetContainerItemQuestInfo = origGetContainerItemQuestInfo
    _G.C_Item.GetItemInfo = origGetItemInfo
    _G.C_Item.GetDetailedItemLevelInfo = origGetDetailedItemLevelInfo
    _G.C_Item.GetItemGUID = origGetItemGUID

    -- Assert results of the end-to-end refresh pass
    local slotInfo = items.slotInfo[const.BAG_KIND.BACKPACK]
    assert.is_not_nil(slotInfo)
    assert.is_not_nil(slotInfo.itemsBySlotKey)

    -- Verify specific item details from the dump are intact
    -- Item: Ruia's Musings, Part 2 (itemID: 265819)
    local item1 = slotInfo.itemsBySlotKey["1_25"]
    assert.is_not_nil(item1)
    assert.are.equal("Ruia's Musings, Part 2", item1.itemInfo.itemName)
    assert.are.equal(265819, item1.itemInfo.itemID)
    assert.are.equal("Midnight - Other", item1.itemInfo.category)

    -- Item: Light's Preservation (itemID: 241287)
    local item2 = slotInfo.itemsBySlotKey["1_3"]
    assert.is_not_nil(item2)
    assert.are.equal("Light's Preservation", item2.itemInfo.itemName)
    assert.are.equal(241287, item2.itemInfo.itemID)
    assert.are.equal("Midnight - Potions", item2.itemInfo.category)

    -- Ensure empty slots are also handled cleanly
    local emptySlot = slotInfo.itemsBySlotKey["5_25"]
    assert.is_not_nil(emptySlot)
    assert.is_true(emptySlot.isItemEmpty)
  end)
end)
