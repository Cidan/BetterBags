-- targeted_sweep_spec.lua -- Integration/Unit tests for targeted bag sweeps

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Ensure dependencies exist
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
local events = addon:GetModule("Events")
events:Init()

local debug = StubBetterBagsModule("Debug")
debug.Log = function() end
debug.Inspect = function() end

local database = StubBetterBagsModule("Database")
local const = StubBetterBagsModule("Constants")
local L = StubBetterBagsModule("Localization")
function L:G(key) return key end

local equipmentSets = StubBetterBagsModule("EquipmentSets")
equipmentSets.GetItemSets = function() return nil end

local tooltipScanner = StubBetterBagsModule("TooltipScanner")
tooltipScanner.GetTooltipText = function() return "" end

LoadBetterBagsModule("util/query.lua")
LoadBetterBagsModule("util/trees/trees.lua")
LoadBetterBagsModule("util/trees/intervaltree.lua")
LoadBetterBagsModule("data/search.lua")
LoadBetterBagsModule("core/async.lua")
local async = addon:GetModule("Async")
async.Yield = function() end
LoadBetterBagsModule("data/stacks.lua")
ResetModuleStub("Binding", "data/binding.lua")
LoadBetterBagsModule("data/binding.lua")

local categories
local ok = pcall(function() return addon:GetModule("Categories") end)
if not ok then
  categories = StubBetterBagsModule("Categories")
else
  categories = addon:GetModule("Categories")
end
categories.GetSortedSearchCategories = categories.GetSortedSearchCategories or function() return {} end
categories.GetCustomCategory = categories.GetCustomCategory or function() return nil, nil end
categories.DoesCategoryExist = categories.DoesCategoryExist or function() return false end

-- Set up constants
const.BAG_KIND = { UNDEFINED = -1, BACKPACK = 0, BANK = 1 }
const.BAG_VIEW = { UNDEFINED = 0, SECTION_GRID = 2, SECTION_ALL_BAGS = 4 }
const.BANK_BAGS = { [6] = 6, [7] = 7 }
const.ACCOUNT_BANK_BAGS = { [13] = 13, [14] = 14 }
const.BACKPACK_BAGS = { [0] = 0, [1] = 1 }
const.BANK_TAB = { BANK = 1, REAGENT = 2, ACCOUNT_BANK_1 = 3 }

const.BINDING_SCOPE = {
  UNKNOWN = 0,
  NONBINDING = 1,
  BOUND = 2,
  BOE = 3,
  BOU = 4,
  QUEST = 5,
  SOULBOUND = 6,
  REFUNDABLE = 7,
  ACCOUNT = 8,
  BNET = 9,
  WUE = 10,
}
const.BINDING_MAP = {
  [0] = "",
  [1] = "boe",
  [2] = "soulbound",
}
const.ITEM_QUALITY = { Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
const.BAG_SUBTYPE_TO_QUALITY = { [0] = 1, [1] = 2, [2] = 2, [3] = 2, [4] = 2, [99] = 2 }
const.SEARCH_CATEGORY_GROUP_BY = { NONE = 0, TYPE = 1, SUBTYPE = 2, EXPANSION = 3 }
const.EXPANSION_MAP = { [0] = "Classic" }
const.BRIEF_EXPANSION_MAP = { [0] = "classic" }
const.TRADESKILL_MAP = {}
const.INVENTORY_TYPE_TO_INVENTORY_SLOTS = { [1] = {1} }

_G.Enum = _G.Enum or {}
_G.Enum.ItemClass = _G.Enum.ItemClass or { Tradegoods = 7, Container = 1 }

database.GetNewItemTime = function() return 30 end
database.GetStackingOptions = function() return { dontMergeTransmog = false } end
database.GetCategoryFilter = function() return false end
database.GetEnableBankBag = function() return false end
database.GetMarkRecentItems = function() return false end
database.GetShowAllFreeSpace = function() return true end
database.GetBagView = function() return const.BAG_VIEW.SECTION_GRID end

addon.isRetail = true
addon.isClassic = false

-- Stub Stacks
local stacksMod = StubBetterBagsModule("Stacks")
stacksMod.Create = function()
  return {
    RemoveFromStack = function() end,
    AddToStack = function() end,
    Clear = function() end,
    GetStackInfo = function() return nil end,
  }
end

-- Mock ItemLoader
local loader = StubBetterBagsModule("ItemLoader")
local registeredCallback = nil
loader.TellMeWhenABagIsUpdated = function(_, cb)
  registeredCallback = cb
end
loader.GetItemMixinFromSlotKey = function() return nil end

ResetModuleStub("Items", "data/items.lua")
LoadBetterBagsModule("data/items.lua")
LoadBetterBagsModule("data/slots.lua")
local items = addon:GetModule("Items")

ResetModuleStub("Refresh", "data/refresh.lua")
LoadBetterBagsModule("data/refresh.lua")
local refresh = addon:GetModule("Refresh")

describe("Targeted Data Sweep System", function()
  before_each(function()
    local search = addon:GetModule("Search")
    search:Init()
    items:Init()
    refresh:Init()
    registeredCallback = nil
    addon.atBank = false
    addon.Bags = {}
  end)

  describe("Refresh Module Targeted Requests", function()
    it("should pass targeted bags into context on RequestUpdate", function()
      local capturedCtx
      local origRefreshBackpack = items.RefreshBackpack
      items.RefreshBackpack = function(self, ctx)
        capturedCtx = ctx
      end

      refresh:RequestUpdate({ backpack = true, bags = { [0] = true } })

      assert.is_not_nil(capturedCtx)
      local targetedBags = capturedCtx:Get("targetedBags")
      assert.is_not_nil(targetedBags)
      assert.is_true(targetedBags[0])

      items.RefreshBackpack = origRefreshBackpack
    end)

    it("should pass updatedBags from ItemLoader callback to RequestUpdate", function()
      refresh:OnEnable()
      assert.is_not_nil(registeredCallback)

      local capturedRequest
      local origRequestUpdate = refresh.RequestUpdate
      refresh.RequestUpdate = function(self, req)
        capturedRequest = req
      end

      registeredCallback({ [0] = true, [1] = true })

      assert.is_not_nil(capturedRequest)
      assert.is_true(capturedRequest.backpack)
      assert.is_not_nil(capturedRequest.bags)
      assert.is_true(capturedRequest.bags[0])
      assert.is_true(capturedRequest.bags[1])

      refresh.RequestUpdate = origRequestUpdate
    end)

    it("should target bag -1 on PLAYERBANKSLOTS_CHANGED for non-retail", function()
      addon.isRetail = false
      refresh:OnEnable()

      local capturedRequest
      local origRequestUpdate = refresh.RequestUpdate
      refresh.RequestUpdate = function(self, req)
        capturedRequest = req
      end

      local eventMap = events._eventMap
      assert.is_not_nil(eventMap["PLAYERBANKSLOTS_CHANGED"])
      eventMap["PLAYERBANKSLOTS_CHANGED"].fn("PLAYERBANKSLOTS_CHANGED")

      assert.is_not_nil(capturedRequest)
      assert.is_true(capturedRequest.bank)
      assert.is_not_nil(capturedRequest.bags)
      assert.is_true(capturedRequest.bags[-1])

      addon.isRetail = true
      refresh.RequestUpdate = origRequestUpdate
    end)
  end)

  describe("Items Module Targeted Harvesting & Merging", function()
    local mockContainer = {}

    before_each(function()
      mockContainer = {}
      _G.C_Container = _G.C_Container or {}
      _G.C_Container.GetContainerNumSlots = function(bagid)
        if mockContainer[bagid] then
          return #mockContainer[bagid]
        end
        return 0
      end
      _G.C_Container.GetContainerItemID = function(bagid, slotid)
        local slot = mockContainer[bagid] and mockContainer[bagid][slotid]
        return slot and slot.itemID or nil
      end
      _G.C_Container.GetContainerItemLink = function(bagid, slotid)
        local slot = mockContainer[bagid] and mockContainer[bagid][slotid]
        return slot and slot.itemLink or nil
      end
      _G.C_Container.GetContainerItemInfo = function(bagid, slotid)
        local slot = mockContainer[bagid] and mockContainer[bagid][slotid]
        if not slot or not slot.itemID then return nil end
        return {
          iconFileID = 134400,
          stackCount = slot.count or 1,
          isLocked = false,
          quality = 1,
          isReadable = false,
          hasLoot = false,
          hyperlink = slot.itemLink or "",
          isFiltered = false,
          hasNoValue = false,
          itemID = slot.itemID,
          isBound = false,
        }
      end
      _G.C_Item = _G.C_Item or {}
      _G.C_Item.GetItemInfo = function(itemID)
        return "TestItem " .. itemID, "|cff0070dd|Hitem:" .. itemID .. "|h[TestItem " .. itemID .. "]|h|r", 1, 100, 1, "Misc", "Junk", 20, "INVTYPE_NON_EQUIP", 134400, 10, 1, 0, 1, 0, 0, false
      end
      _G.C_Item.GetItemSubClassInfo = function() return "Bag" end
      _G.C_Container.ContainerIDToInventoryID = function() return nil end
      _G.GetInventoryItemLink = function() return nil end
    end)

    it("Phase1_DetermineBags should filter bags when targetedBags is in context", function()
      local ctx = addon:GetModule("Context"):New("TestTargetedBags")
      ctx:Set("targetedBags", { [0] = true })

      local bags = items:Phase1_DetermineBags(ctx, const.BAG_KIND.BACKPACK)
      assert.is_not_nil(bags[0])
      assert.is_nil(bags[1])
    end)

    it("Phase1_DetermineBags should return all bags when targetedBags is nil", function()
      local ctx = addon:GetModule("Context"):New("TestAllBags")
      local bags = items:Phase1_DetermineBags(ctx, const.BAG_KIND.BACKPACK)
      assert.is_not_nil(bags[0])
      assert.is_not_nil(bags[1])
    end)

    it("ProcessRefresh should merge targeted bag changes with previous state", function()
      -- Initial state: Bag 0 has Item 101 (count 5) in slot 1, empty slot 2.
      --                Bag 1 has Item 201 (count 10) in slot 1, empty slot 2.
      mockContainer[0] = {
        { itemID = 101, itemLink = "|Hitem:101|h", count = 5 },
        { itemID = nil }
      }
      mockContainer[1] = {
        { itemID = 201, itemLink = "|Hitem:201|h", count = 10 },
        { itemID = nil }
      }

      -- Run initial full refresh (first load)
      local ctx1 = addon:GetModule("Context"):New("InitialLoad")
      items:RefreshBackpack(ctx1)

      local slotInfo = items.slotInfo[const.BAG_KIND.BACKPACK]
      assert.is_not_nil(slotInfo)
      assert.is_not_nil(slotInfo.itemsBySlotKey["0_1"])
      assert.is_not_nil(slotInfo.itemsBySlotKey["1_1"])
      assert.equal(5, slotInfo.itemsBySlotKey["0_1"].itemInfo.currentItemCount)
      assert.equal(10, slotInfo.itemsBySlotKey["1_1"].itemInfo.currentItemCount)

      -- Scenario A: Item count changes in Bag 0 (count becomes 8)
      mockContainer[0][1].count = 8

      local ctx2 = addon:GetModule("Context"):New("TargetedUpdate")
      ctx2:Set("targetedBags", { [0] = true })
      items:RefreshBackpack(ctx2)

      local updatedSlotInfo = items.slotInfo[const.BAG_KIND.BACKPACK]
      -- Bag 0 slot 1 updated to 8
      assert.equal(8, updatedSlotInfo.itemsBySlotKey["0_1"].itemInfo.currentItemCount)
      -- Bag 1 slot 1 preserved from previous state (count 10)
      assert.is_not_nil(updatedSlotInfo.itemsBySlotKey["1_1"])
      assert.equal(10, updatedSlotInfo.itemsBySlotKey["1_1"].itemInfo.currentItemCount)

      -- Scenario B: Item removed from Bag 0 (slot 1 becomes empty)
      mockContainer[0][1] = { itemID = nil }

      local ctx3 = addon:GetModule("Context"):New("TargetedRemove")
      ctx3:Set("targetedBags", { [0] = true })
      items:RefreshBackpack(ctx3)

      local removedSlotInfo = items.slotInfo[const.BAG_KIND.BACKPACK]
      assert.is_true(removedSlotInfo.itemsBySlotKey["0_1"].isItemEmpty)
      -- Bag 1 slot 1 still preserved
      assert.is_not_nil(removedSlotInfo.itemsBySlotKey["1_1"])
      assert.is_false(removedSlotInfo.itemsBySlotKey["1_1"].isItemEmpty)
      assert.equal(10, removedSlotInfo.itemsBySlotKey["1_1"].itemInfo.currentItemCount)

      -- Scenario C: Swap positions between Bag 0 and Bag 1
      -- Move Item 201 from Bag 1 slot 1 to Bag 0 slot 1, and place Item 301 in Bag 1 slot 1
      mockContainer[0][1] = { itemID = 201, itemLink = "|Hitem:201|h", count = 10 }
      mockContainer[1][1] = { itemID = 301, itemLink = "|Hitem:301|h", count = 1 }

      local ctx4 = addon:GetModule("Context"):New("TargetedSwap")
      ctx4:Set("targetedBags", { [0] = true, [1] = true })
      items:RefreshBackpack(ctx4)

      local swapSlotInfo = items.slotInfo[const.BAG_KIND.BACKPACK]
      assert.equal(201, swapSlotInfo.itemsBySlotKey["0_1"].itemInfo.itemID)
      assert.equal(301, swapSlotInfo.itemsBySlotKey["1_1"].itemInfo.itemID)
    end)

    it("ProcessRefresh should fall back to full sweep when wipe=true or targetedBags is nil", function()
      mockContainer[0] = { { itemID = 101, itemLink = "|Hitem:101|h", count = 1 } }
      mockContainer[1] = { { itemID = 201, itemLink = "|Hitem:201|h", count = 1 } }

      -- Initial load
      local ctx1 = addon:GetModule("Context"):New("Init")
      items:RefreshBackpack(ctx1)

      -- Modify container
      mockContainer[0][1] = { itemID = 102, itemLink = "|Hitem:102|h", count = 2 }
      mockContainer[1][1] = { itemID = 202, itemLink = "|Hitem:202|h", count = 2 }

      -- Full sweep with wipe = true
      local ctx2 = addon:GetModule("Context"):New("Wipe")
      ctx2:Set("wipe", true)
      items:RefreshBackpack(ctx2)

      local slotInfo = items.slotInfo[const.BAG_KIND.BACKPACK]
      assert.equal(102, slotInfo.itemsBySlotKey["0_1"].itemInfo.itemID)
      assert.equal(202, slotInfo.itemsBySlotKey["1_1"].itemInfo.itemID)
    end)
  end)
end)
