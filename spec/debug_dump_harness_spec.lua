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
events:Init()

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

ResetModuleStub("Async", "core/async.lua")
LoadBetterBagsModule("core/async.lua")
local async = addon:GetModule("Async")
async.Yield = function() end

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
    DB:Init()
    tooltipScanner:Init()
    equipmentSets:Init()
    categories:Init()
    categories:OnEnable()
    search:Init()
    items:Init()
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

  -- Issue #1107: Migrate runs on every load and used to drop every pin of a built-in
  -- category ("Armor", "Junk"), keeping only custom ones like the dump's "Midnight".
  it("keeps every pinned category of a real profile across a load, built-in ones included", function()
    DB.data:SetProfile("Default")
    local sort = DB.data.profile.customSectionSort[0]
    assert.is_not_nil(sort, "dump should carry a backpack customSectionSort table")
    assert.is_not_nil(DB.data.profile.customCategoryFilters["Midnight"],
      "'Midnight' must be a real category in the dump")
    assert.are.equal(1, sort["Midnight"])
    assert.is_nil(DB.data.profile.customCategoryFilters["Armor"])

    sort["Armor"] = 2

    DB:Migrate()

    assert.are.equal(1, DB.data.profile.customSectionSort[0]["Midnight"])
    assert.are.equal(2, DB.data.profile.customSectionSort[0]["Armor"])
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

    -- C_Item.GetItemInfo takes an item ID or an item link (warcraft.wiki.gg).
    _G.C_Item.GetItemInfo = function(itemInfo)
      local itemID = tonumber(itemInfo) or tonumber(tostring(itemInfo):match("item:(%d+)"))
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

    -- Every dumped item's data is there (its link included), so each is read complete, with the
    -- traits the search indexes (items:ReadItemTraits).
    local read = 0
    for slotkey, item in pairs(slotInfo.itemsBySlotKey) do
      if not item.isItemEmpty then
        read = read + 1
        assert.is_false(item.harvestIncomplete, slotkey)
        assert.is_not_nil(item.itemInfo.traits, slotkey)
      end
    end
    assert.is_true(read > 0)
    assert.are.equal(dumpItems["1_3"].itemInfo.sellPrice, item2.itemInfo.traits.sellPrice)

    -- Ensure empty slots are also handled cleanly
    local emptySlot = slotInfo.itemsBySlotKey["5_25"]
    assert.is_not_nil(emptySlot)
    assert.is_true(emptySlot.isItemEmpty)
  end)

  it("should generate distinct tabs for character bank bags when GetShowBankTabs is true and view is SECTION_ALL_BAGS, and should generate dummy empty slots for Warbank bags", function()
    -- Enable Show Bank Tabs and SECTION_ALL_BAGS view
    local old_isRetail = addon.isRetail
    addon.isRetail = true
    local old_GetShowBankTabs = DB.GetShowBankTabs
    DB.GetShowBankTabs = function() return true end
    local old_GetBagView = DB.GetBagView
    DB.GetBagView = function(self, kind)
      if kind == const.BAG_KIND.BANK then
        return const.BAG_VIEW.SECTION_ALL_BAGS
      end
      return const.BAG_VIEW.SECTION_GRID
    end

    -- Overwrite constants for tests
    local old_BANK_BAGS = const.BANK_BAGS
    local old_ACCOUNT_BANK_BAGS = const.ACCOUNT_BANK_BAGS
    const.BANK_BAGS = { [100] = 100, [5] = 5 }
    const.ACCOUNT_BANK_BAGS = { [13] = 13 }

    -- Create simulated bank items dump
    local dumpBankItems = {
      ["100_1"] = {
        bagid = 100,
        slotid = 1,
        isItemEmpty = false,
        containerInfo = { itemID = 1001, hyperlink = "|Hitem:1001:1001::::::::|h[Bank Item 1]|h", stackCount = 1 },
        itemInfo = { itemName = "Bank Item 1", itemLink = "|Hitem:1001:1001::::::::|h[Bank Item 1]|h", itemQuality = 2, itemLevel = 100, itemMinLevel = 1, itemType = "Weapon", itemSubType = "One-Handed Swords", itemStackCount = 1, itemIcon = 135328, sellPrice = 100, classID = 2, subclassID = 7 }
      },
      ["5_1"] = {
        bagid = 5,
        slotid = 1,
        isItemEmpty = false,
        containerInfo = { itemID = 1002, hyperlink = "|Hitem:1002:1002::::::::|h[Bank Tab Item 2]|h", stackCount = 1 },
        itemInfo = { itemName = "Bank Tab Item 2", itemLink = "|Hitem:1002:1002::::::::|h[Bank Tab Item 2]|h", itemQuality = 3, itemLevel = 200, itemMinLevel = 1, itemType = "Armor", itemSubType = "Cloth", itemStackCount = 1, itemIcon = 135329, sellPrice = 200, classID = 4, subclassID = 1 }
      },
      ["13_1"] = {
        bagid = 13,
        slotid = 1,
        isItemEmpty = false,
        containerInfo = { itemID = 1003, hyperlink = "|Hitem:1003:1003::::::::|h[Warbank Item 3]|h", stackCount = 1 },
        itemInfo = { itemName = "Warbank Item 3", itemLink = "|Hitem:1003:1003::::::::|h[Warbank Item 3]|h", itemQuality = 4, itemLevel = 300, itemMinLevel = 1, itemType = "Gem", itemSubType = "Red", itemStackCount = 1, itemIcon = 135330, sellPrice = 300, classID = 3, subclassID = 0 }
      }
    }

    -- Save original API references
    local origGetContainerNumSlots = _G.C_Container.GetContainerNumSlots
    local origGetContainerItemID = _G.C_Container.GetContainerItemID
    local origGetContainerItemLink = _G.C_Container.GetContainerItemLink
    local origGetContainerItemInfo = _G.C_Container.GetContainerItemInfo
    local origGetContainerItemQuestInfo = _G.C_Container.GetContainerItemQuestInfo
    local origGetItemInfo = _G.C_Item.GetItemInfo
    local origGetDetailedItemLevelInfo = _G.C_Item.GetDetailedItemLevelInfo
    local origGetItemGUID = _G.C_Item.GetItemGUID
    local origGetBagName = _G.C_Container.GetBagName

    -- Mock low-level APIs
    _G.C_Container.GetContainerNumSlots = function(bagid)
      -- Let's say each bag has 2 slots
      return 2
    end

    _G.C_Container.GetContainerItemID = function(bagid, slotid)
      local slotkey = bagid .. "_" .. slotid
      local item = dumpBankItems[slotkey]
      if item and not item.isItemEmpty then
        return item.containerInfo.itemID
      end
      return nil
    end

    _G.C_Container.GetContainerItemLink = function(bagid, slotid)
      local slotkey = bagid .. "_" .. slotid
      local item = dumpBankItems[slotkey]
      if item and not item.isItemEmpty then
        return item.containerInfo.hyperlink
      end
      return nil
    end

    _G.C_Container.GetContainerItemInfo = function(bagid, slotid)
      local slotkey = bagid .. "_" .. slotid
      local item = dumpBankItems[slotkey]
      if item and not item.isItemEmpty then
        return item.containerInfo
      end
      return nil
    end

    _G.C_Container.GetContainerItemQuestInfo = function(bagid, slotid)
      return nil
    end

    _G.C_Item.GetItemInfo = function(itemID)
      for _, item in pairs(dumpBankItems) do
        if item.containerInfo and item.containerInfo.itemID == itemID then
          local info = item.itemInfo
          return info.itemName, info.itemLink, info.itemQuality, info.itemLevel, info.itemMinLevel, info.itemType, info.itemSubType, info.itemStackCount, info.itemEquipLoc, info.itemIcon, info.sellPrice, info.classID, info.subclassID, info.bindType, info.expacID, info.setID, info.isCraftingReagent
        end
      end
      return nil
    end

    _G.C_Item.GetDetailedItemLevelInfo = function(itemID)
      for _, item in pairs(dumpBankItems) do
        if item.containerInfo and item.containerInfo.itemID == itemID then
          local info = item.itemInfo
          return info.itemLevel, false, info.itemLevel
        end
      end
      return nil
    end

    _G.C_Item.GetItemGUID = function(_)
      return "MockGUID"
    end

    _G.C_Container.GetBagName = function(bagid)
      if bagid == 100 then return "Bank" end
      if bagid == 5 then return "Bank Bag 1" end
      -- Warbank returns nil for GetBagName natively
      if bagid == 13 then return nil end
      return nil
    end

    -- Run the bank refresh pass
    local ctx = context:New("TestBankEndToEndRefresh")
    items:ProcessRefresh(ctx, const.BAG_KIND.BANK)

    -- Restore low-level APIs
    _G.C_Container.GetContainerNumSlots = origGetContainerNumSlots
    _G.C_Container.GetContainerItemID = origGetContainerItemID
    _G.C_Container.GetContainerItemLink = origGetContainerItemLink
    _G.C_Container.GetContainerItemInfo = origGetContainerItemInfo
    _G.C_Container.GetContainerItemQuestInfo = origGetContainerItemQuestInfo
    _G.C_Item.GetItemInfo = origGetItemInfo
    _G.C_Item.GetDetailedItemLevelInfo = origGetDetailedItemLevelInfo
    _G.C_Item.GetItemGUID = origGetItemGUID
    _G.C_Container.GetBagName = origGetBagName

    -- Restore constants
    const.BANK_BAGS = old_BANK_BAGS
    const.ACCOUNT_BANK_BAGS = old_ACCOUNT_BANK_BAGS
    addon.isRetail = old_isRetail
    DB.GetShowBankTabs = old_GetShowBankTabs
    DB.GetBagView = old_GetBagView

    -- Assert results of the end-to-end bank refresh pass
    local slotInfo = items.slotInfo[const.BAG_KIND.BANK]
    assert.is_not_nil(slotInfo)

    -- Tab 100, 5, and 13 should all be created
    assert.is_not_nil(slotInfo.tabs[100], "Tab 100 (main bank) should exist")
    assert.is_not_nil(slotInfo.tabs[5], "Tab 5 (character bank bag 1) should exist")
    assert.is_not_nil(slotInfo.tabs[13], "Tab 13 (warbank bag 1) should exist")

    -- Items must belong to their respective tabs and include dummy free slots (size is 2)
    assert.are.equal(2, #slotInfo.tabs[100].items, "Tab 100 should contain 2 items")
    local tab100Real, tab100Free = nil, nil
    for _, item in ipairs(slotInfo.tabs[100].items) do
      if item.isFreeSlot then tab100Free = item else tab100Real = item end
    end
    assert.is_not_nil(tab100Real, "Tab 100 should contain real item")
    assert.is_not_nil(tab100Free, "Tab 100 should contain dummy empty slot")
    assert.are.equal("Bank Item 1", tab100Real.itemInfo.itemName)

    assert.are.equal(2, #slotInfo.tabs[5].items, "Tab 5 should contain 2 items")
    local tab5Real, tab5Free = nil, nil
    for _, item in ipairs(slotInfo.tabs[5].items) do
      if item.isFreeSlot then tab5Free = item else tab5Real = item end
    end
    assert.is_not_nil(tab5Real, "Tab 5 should contain real item")
    assert.is_not_nil(tab5Free, "Tab 5 should contain dummy empty slot")
    assert.are.equal("Bank Tab Item 2", tab5Real.itemInfo.itemName)

    assert.are.equal(2, #slotInfo.tabs[13].items, "Tab 13 should contain 2 items")
    local tab13Real, tab13Free = nil, nil
    for _, item in ipairs(slotInfo.tabs[13].items) do
      if item.isFreeSlot then tab13Free = item else tab13Real = item end
    end
    assert.is_not_nil(tab13Real, "Tab 13 should contain real item")
    assert.is_not_nil(tab13Free, "Tab 13 should contain dummy empty slot")
    assert.are.equal("Warbank Item 3", tab13Real.itemInfo.itemName)
  end)

  it("profiles the real refresh pipeline without changing its results, and exports the session", function()
    LoadBetterBagsModule("debug/perf/format.lua")
    local perf = addon:GetModule("Perf")
    local perfFormat = addon:GetModule("PerfFormat")
    DB.data:SetProfile("Default")
    local dumpItems = _G.BetterBagsDB.profiles.Default.debugBackpackDump
    local originalHarvest = items.Harvest
    items.Harvest = function()
      return dumpItems, {}
    end
    -- The sweep is under test, not message delivery: handlers that earlier spec files left
    -- registered on AceEvent would otherwise run (and may throw) on the commit message.
    local originalSendMessage = events.SendMessage
    events.SendMessage = function() end

    local function categoriesBySlot()
      local out = {}
      for slotkey, item in pairs(items.slotInfo[const.BAG_KIND.BACKPACK].itemsBySlotKey) do
        out[slotkey] = item.itemInfo.category or false
      end
      return out
    end

    items:ProcessRefresh(context:New("Unprofiled"), const.BAG_KIND.BACKPACK)
    local expected = categoriesBySlot()

    local runRefresh = items.RunRefresh
    perf:Init()
    perf:SetClock(nil)
    assert.is_true(perf:Start({
      modules = { "Items", "Search", "Categories", "Stacks", "Database", "EquipmentSets", "TooltipScanner",
        "QueryParser", "Binding", "Async", "Localization" },
      prototypes = { "SlotInfo", "Stack", "IntervalTree" },
      includeRoot = false,
      calibrate = true,
    }))
    items:ProcessRefresh(context:New("Profiled"), const.BAG_KIND.BACKPACK)
    perf:_OnFrame()
    local session = perf:Stop()
    items.Harvest = originalHarvest
    events.SendMessage = originalSendMessage

    assert.are.equal(runRefresh, items.RunRefresh)
    assert.are.same(expected, categoriesBySlot())

    local tree = perfFormat:Decode(session)
    local sweep = perfFormat:Find(tree, { "Items.ProcessRefresh", "Async.Do", "Async.DoWithDelay", "Items.RunRefresh" })
    assert.is_not_nil(sweep, "the sweep runs inside async:Do's coroutine")
    for _, phase in ipairs({ "Items.Phase1_DetermineBags", "Items.Phase2_Harvest", "Items.Phase6_EnrichData",
      "Items.Phase8_EnrichCategories", "Items.Phase10_PartitionIntoTabs", "Items.Phase11_CommitAndDispatch" }) do
      assert.is_not_nil(sweep.childByName[phase], phase)
    end
    assert.is_true(session.stats.calls > 100)
    assert.is_true(session.stats.wrappedFunctions > 100)
    assert.are.equal(0, session.stats.aborted)

    -- Round-trip the session through a SavedVariables file and the offline exporter.
    local function serialize(value, indent)
      if type(value) == "string" then return string.format("%q", value) end
      if type(value) ~= "table" then return tostring(value) end
      local parts = {}
      for k, v in pairs(value) do
        local key = type(k) == "number" and ("[" .. k .. "]") or ("[" .. string.format("%q", k) .. "]")
        parts[#parts + 1] = indent .. "  " .. key .. " = " .. serialize(v, indent .. "  ")
      end
      return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
    end
    session.id = 1
    session.meta = { character = "Harness", realm = "Local", startedAt = 1700000000, reason = "manual" }
    local dir = os.tmpname()
    os.remove(dir)
    os.execute("mkdir -p '" .. dir .. "'")
    local svPath = dir .. "/BetterBags.lua"
    local svFile = assert(io.open(svPath, "w"))
    svFile:write("BetterBagsPerfDB = " .. serialize({ version = 1, sessions = { session } }, "") .. "\n")
    svFile:close()
    local tool = assert(loadfile("tools/flamegraph/flamegraph.lua"))("flamegraph-module")
    assert.are.equal(0, tool.Main({ svPath, "--out", dir }, function() end))
    local folded = assert(io.open(dir .. "/betterbags-1.folded", "r")):read("*a")
    assert.is_truthy(folded:find("Items.ProcessRefresh;Async.Do;Async.DoWithDelay;Items.RunRefresh;Items.Phase2_Harvest", 1, true))
    os.execute("rm -rf '" .. dir .. "'")
  end)

  it("traces every call of the real refresh pipeline with its arguments, without changing its results", function()
    LoadBetterBagsModule("debug/perf/format.lua")
    local perf = addon:GetModule("Perf")
    local perfFormat = addon:GetModule("PerfFormat")
    DB.data:SetProfile("Default")
    local dumpItems = _G.BetterBagsDB.profiles.Default.debugBackpackDump
    local originalHarvest = items.Harvest
    items.Harvest = function()
      return dumpItems, {}
    end
    local originalSendMessage = events.SendMessage
    events.SendMessage = function() end

    local function categoriesBySlot()
      local out = {}
      for slotkey, item in pairs(items.slotInfo[const.BAG_KIND.BACKPACK].itemsBySlotKey) do
        out[slotkey] = item.itemInfo.category or false
      end
      return out
    end

    items:ProcessRefresh(context:New("Unprofiled"), const.BAG_KIND.BACKPACK)
    local expected = categoriesBySlot()

    perf:Init()
    perf:SetClock(nil)
    assert.is_true(perf:Start({
      modules = { "Items", "Search", "Categories", "Stacks", "Database", "EquipmentSets", "TooltipScanner",
        "QueryParser", "Binding", "Async", "Localization" },
      prototypes = { "SlotInfo", "Stack", "IntervalTree" },
      includeRoot = false,
      calibrate = true,
      trace = true,
      traceArgs = true,
    }))
    items:ProcessRefresh(context:New("Traced"), const.BAG_KIND.BACKPACK)
    perf:_OnFrame()
    local session = perf:Stop()
    items.Harvest = originalHarvest
    events.SendMessage = originalSendMessage

    assert.are.same(expected, categoriesBySlot())
    assert.are.equal(0, session.stats.aborted)
    assert.are.equal(session.stats.calls, session.stats.traceCalls)

    local trace = perfFormat:OpenTrace(session)
    assert.are.equal(session.stats.calls, trace:Count())
    local tree = perfFormat:Decode(session)
    local callsByName, refresh = {}, nil
    for index = 1, trace:Count() do
      local call = trace:Get(index)
      assert.are.equal(index, call.index)
      assert.is_true(call.wall >= 0, "call " .. index)
      assert.are.equal(0, call.flags, "call " .. index)
      callsByName[call.name] = (callsByName[call.name] or 0) + 1
      if call.name == "Items.RunRefresh" then refresh = call end
    end
    -- Every call in the tree is in the trace, and nothing else.
    for _, fn in ipairs(perfFormat:DecodeFunctions(session, tree)) do
      assert.are.equal(fn.calls, callsByName[fn.name], fn.name)
    end
    assert.is_not_nil(refresh)
    local args = trace:Text(refresh.args)
    assert.is_truthy(args:find("ctx Traced", 1, true), args)
    assert.is_truthy(args:find(", 0$"), args)

    -- Each distinct argument list is stored once.
    local seen = {}
    for _, spec in ipairs(session.trace.sets) do
      assert.is_nil(seen[spec], spec)
      seen[spec] = true
    end
    assert.is_true(#session.trace.sets < trace:Count())

    local out = {}
    local tool = assert(loadfile("tools/flamegraph/flamegraph.lua"))("flamegraph-module")
    assert.is_true(tool.WriteChromeTrace(session, function(s) out[#out + 1] = s end))
    local json = table.concat(out)
    local exported = 0
    for _ in string.gmatch(json, '"ph":"X"') do exported = exported + 1 end
    assert.are.equal(trace:Count(), exported)
  end)
end)

-- The client's own answers: Dump tab captures whose items carry apiProbe, what every Blizzard API
-- returned about them in game (debug/itemprobe.lua, test-harness.md §5). Every API the harvest
-- calls is answered from one, so the real pipeline runs on what the game said. The expected values
-- below were read from the raw answers (docs/vendor-compat.md, "What a capture settled").

-- clientAnswers runs the tests of a block on a capture: before each, every API the harvest calls
-- answers from the fixture's apiProbe (by location, item ID or link, as each API takes them).
---@param fixturePath string
local function clientAnswers(fixturePath)
  local fixture = dofile(fixturePath)
  local oldBetterBagsDB
  local saved
  local slots, byLink, byID, bySpecies, maxSlot

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  -- The values a recorded call returned (unpacked with their count), or nothing.
  local function answer(rec)
    if type(rec) ~= "table" or rec.error then return end
    return unpack(rec, 1, rec.n or 0)
  end

  -- The probe of the item at a bag location; nothing for an equipment slot (the gear is not dumped).
  local function probeAt(location)
    local bag, slot = location:GetBagAndSlot()
    local item = bag and slot and slots[bag .. "_" .. slot]
    return item and item.apiProbe
  end

  local function probeOf(info)
    if type(info) == "number" then return byID[info] end
    return byLink[info]
  end

  -- What Blizzard's enUS global strings hold (Ketho/BlizzardInterfaceResources, live,
  -- Resources/GlobalStrings/enUS.lua at 36dd01db): the stat keys the dump's items have, and the
  -- tooltip lines toys and known items carry.
  local strings = {
    ITEM_MOD_HASTE_RATING_SHORT = "Haste", ITEM_MOD_VERSATILITY = "Versatility",
    ITEM_MOD_STAMINA_SHORT = "Stamina", ITEM_MOD_STRENGTH_SHORT = "Strength", RESISTANCE0_NAME = "Armor",
    TOY = "Toy", ITEM_SPELL_KNOWN = "Already known",
  }

  before_each(function()
    saved = {}
    oldBetterBagsDB = _G.BetterBagsDB
    _G.BetterBagsDB = nil
    dofile(dumpPath)
    DB:Init()
    tooltipScanner:Init()
    equipmentSets:Init()
    categories:Init()
    categories:OnEnable()
    search:Init()
    items:Init()
    items:OnEnable()
    DB.data:SetProfile("Default")

    slots, byLink, byID, bySpecies, maxSlot = {}, {}, {}, {}, {}
    for slotkey, item in pairs(fixture.items) do
      slots[slotkey] = item
      maxSlot[item.bagid] = math.max(maxSlot[item.bagid] or 0, item.slotid)
      local p = item.apiProbe
      if p then
        byLink[p.link] = p
        byID[p.itemID] = p
        local species = p.petInfo and p.petInfo[13]
        if species then bySpecies[species] = p end
      end
    end
    for key, text in pairs(strings) do override(_G, key, text) end

    local function at(bag, slot)
      local item = bag and slot and slots[bag .. "_" .. slot]
      if item and not item.isItemEmpty then return item end
    end
    override(C_Container, "GetContainerNumSlots", function(bag) return maxSlot[bag] or 0 end)
    override(C_Container, "GetContainerItemID", function(bag, slot) local i = at(bag, slot) return i and i.apiProbe.itemID end)
    override(C_Container, "GetContainerItemLink", function(bag, slot) local i = at(bag, slot) return i and i.apiProbe.link end)
    override(C_Container, "GetContainerItemInfo", function(bag, slot) local i = at(bag, slot) return i and i.containerInfo end)
    override(C_Container, "GetContainerItemQuestInfo", function(bag, slot) local i = at(bag, slot) return i and i.questInfo end)
    override(C_Container, "GetBagName", function(bag)
      for _, item in pairs(slots) do
        if item.bagid == bag and item.apiProbe then return answer(item.apiProbe.bagName) end
      end
    end)
    override(C_Item, "GetItemGUID", function(location)
      local bag, slot = location:GetBagAndSlot()
      local i = at(bag, slot)
      return i and i.itemInfo.itemGUID
    end)
    -- Not probed: the slot's own quality, which its container info also reports.
    override(C_Item, "GetItemQuality", function(location)
      local bag, slot = location:GetBagAndSlot()
      local i = at(bag, slot)
      return i and i.containerInfo.quality
    end)
    override(C_Item, "IsItemDataCached", function(location) local p = probeAt(location) return answer(p and p.dataCached) end)
    override(C_Item, "GetItemInfo", function(info)
      local p = probeOf(info)
      if not p then return nil end
      return answer(type(info) == "number" and p.itemInfoByID or p.itemInfoByLink)
    end)
    override(C_Item, "GetItemInfoInstant", function(info)
      local p = probeOf(info)
      return answer(p and p.itemInfoInstant)
    end)
    override(C_Item, "GetDetailedItemLevelInfo", function(info)
      local p = probeOf(info)
      if not p then return nil end
      return answer(type(info) == "number" and p.detailedItemLevelByID or p.detailedItemLevelByLink)
    end)
    override(C_Item, "GetCurrentItemLevel", function(location) local p = probeAt(location) return answer(p and p.currentItemLevel) end)
    override(C_Item, "IsEquippableItem", function(link) local p = probeOf(link) return answer(p and p.equippable) end)
    override(C_Item, "GetItemSpell", function(link) local p = probeOf(link) return answer(p and p.itemSpell) end)
    override(C_Item, "IsCosmeticItem", function(link) local p = probeOf(link) return answer(p and p.cosmetic) end)
    override(C_Item, "GetItemUpgradeInfo", function(link) local p = probeOf(link) return answer(p and p.upgradeInfo) end)
    override(C_Item, "GetItemStats", function(link) local p = probeOf(link) return answer(p and p.stats) end)
    override(C_Item, "CanScrapItem", function(location) local p = probeAt(location) return answer(p and p.scrappable) end)
    override(_G, "C_TradeSkillUI", {
      GetItemReagentQualityByItemInfo = function(link) local p = probeOf(link) return answer(p and p.reagentQuality) end,
      GetItemCraftedQualityByItemInfo = function(link) local p = probeOf(link) return answer(p and p.craftedQuality) end,
    })
    override(_G, "C_PetJournal", {
      GetPetInfoByItemID = function(id) local p = byID[id] return answer(p and p.petInfo) end,
      GetNumCollectedInfo = function(species) local p = bySpecies[species] return answer(p and p.petCollected) end,
    })
    override(_G, "C_PlayerInfo", { CanUseItem = function(id) local p = byID[id] return answer(p and p.canUse) end })
    override(_G, "C_TransmogCollection", {
      GetItemInfo = function(link) local p = probeOf(link) return answer(p and p.transmog) end,
      PlayerHasTransmog = function() return false end,
    })
    override(C_TooltipInfo, "GetBagItem", function(bag, slot)
      local i = at(bag, slot)
      if not i or not i.apiProbe.tooltip then return nil end
      local lines = {}
      for _, line in ipairs(i.apiProbe.tooltip) do
        table.insert(lines, { type = line.type, leftText = line.left, rightText = line.right })
      end
      return { lines = lines }
    end)
  end)

  after_each(function()
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
    _G.BetterBagsDB = oldBetterBagsDB
  end)

  local h = {}

  function h.read()
    local ctx = context:New("ClientAnswers")
    ctx:Set("wipe", true)
    items:ProcessRefresh(ctx, const.BAG_KIND.BACKPACK)
    return items.slotInfo[const.BAG_KIND.BACKPACK].itemsBySlotKey
  end

  function h.keys(...)
    local set = {}
    for _, k in ipairs({...}) do set[k] = true end
    return set
  end

  function h.count(set)
    local n = 0
    for _ in pairs(set) do n = n + 1 end
    return n
  end

  return h
end

-- Retail 12.1.5 (build 70448, enUS), 88 items.
describe("Dump harness: the client's own answers (spec/fixtures/dump_retail_12_1_5.lua)", function()
  local h = clientAnswers("spec/fixtures/dump_retail_12_1_5.lua")
  local read, keys, count = h.read, h.keys, h.count

  it("reads every item with its data, and its traits", function()
    local n = 0
    for slotkey, item in pairs(read()) do
      if not item.isItemEmpty then
        n = n + 1
        assert.is_false(item.harvestIncomplete, slotkey)
        assert.is_not_nil(item.itemInfo.traits, slotkey)
      end
    end
    assert.are.equal(88, n)
  end)

  -- The one item whose link and item ID answered differently: an upgraded cloak. Its link has the
  -- item in the bag; its item ID the base item (item level 80, required level 80, 225552 copper).
  it("reads the cloak's required level and price from its link, not its base item", function()
    local cloak = read()["1_6"]
    assert.are.equal("Voidfused Wing Cloak", cloak.itemInfo.itemName)
    assert.are.equal(90, cloak.itemInfo.traits.minLevel)
    assert.are.equal(325268, cloak.itemInfo.traits.sellPrice)
    assert.are.equal(230, cloak.itemInfo.currentItemLevel)
    -- Three foods need level 90 too, by link and by item ID alike.
    assert.are.same(keys("0_3", "0_5", "0_6", "1_6"), search:Search("minlevel = 90"))
    assert.is_nil(search:Search("minlevel = 80")["1_6"], "not its base item's required level")
    assert.are.same(keys("1_6"), search:Search("price = 325268"))
    assert.are.same({}, search:Search("price = 225552"), "not its base item's price")
    assert.are.same(keys("1_6"), search:Search("maxlevel = 230"))
  end)

  -- The cloak's upgrade info names a track (Adventurer) with no levels (0/0, max item level 0), and
  -- its tooltip has no upgrade level line: it is not on a track the game shows.
  it("does not take a track with no levels as an upgrade track", function()
    local cloak = read()["1_6"]
    assert.is_nil(cloak.itemInfo.traits.upgradeTrack)
    assert.are.same({}, search:Search("upgradeable = true"))
    assert.are.same({}, search:Search("track = adventurer"))
  end)

  it("finds the cloak as the only equipment, by its stats", function()
    read()
    assert.are.same(keys("1_6"), search:Search("equipment = true"))
    assert.are.same(keys("1_6"), search:Search("stat = haste AND stat = vers"))
    assert.are.same(keys("1_6"), search:Search("stat = armor"))
  end)

  it("finds the two pets, the three tiered reagents, and the Use: items", function()
    read()
    assert.are.same(keys("2_16", "2_9"), search:Search("pet = true"))
    assert.are.same(keys("1_16", "1_17", "1_4"), search:Search("quality = 1"))
    -- 43 Use: lines and 8 recipes and pets whose "Use: Teaches you" lines GetItemSpell answers too.
    assert.are.equal(51, count(search:Search("hasuse = true")))
    assert.are.equal(37, count(search:Search("hasuse = false")))
  end)

  -- Both toys: the tooltip has a line "Toy" (TOY) and, learned, "Already known" (ITEM_SPELL_KNOWN,
  -- a UsageRequirement line); C_ToyBox.GetToyInfo also answered for these two and no other item.
  it("finds the toys, and the items already known, by their tooltip lines", function()
    read()
    assert.are.same(keys("0_2", "2_29"), search:Search("toy = true"))
    assert.are.same(keys("0_2", "2_29"), search:Search("known = true"))
    assert.are.equal(86, count(search:Search("toy = false")))
  end)

  -- CanUseItem said no to the 9 recipes of professions the character does not have.
  it("finds what the character can use, wear, and transmog", function()
    read()
    assert.are.same(keys("1_10", "1_11", "1_12", "1_13", "1_14", "1_15", "1_7", "1_8", "1_9"),
      search:Search("usable = false"))
    assert.are.same(keys("1_6"), search:Search("equippable = true"))
    assert.are.same(keys("1_6"), search:Search("transmoggable = true"))
  end)

  it("finds items by the plain name of their bag", function()
    read()
    assert.are.equal(20, count(search:Search("bag = backpack")))
    assert.are.equal(68, count(search:Search("bag = shrouded")))
  end)
end)

-- A second capture, the same day, with a bag in the backpack (33 items): IsEquippableItem says a bag
-- is equipment. Vendor's IsEquipment calls the same API (itemproperties.lua:176, interop.lua:46).
describe("Dump harness: a capture with a bag (spec/fixtures/dump_retail_12_1_5_bag.lua)", function()
  local h = clientAnswers("spec/fixtures/dump_retail_12_1_5_bag.lua")
  local read, keys = h.read, h.keys

  it("takes a bag as equipment the character can equip, worth nothing to a vendor", function()
    local bag = read()["3_17"]
    assert.are.equal("Horadric Haversack", bag.itemInfo.itemName)
    assert.are.same(keys("1_6", "3_17"), search:Search("equipment = true"))
    assert.are.same(keys("1_6", "3_17"), search:Search("equippable = true"))
    assert.is_true(search:Search("price = 0")["3_17"])
    assert.is_nil(search:Search("upgradeable = true")["3_17"])
  end)
end)
