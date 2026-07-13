-- orchestrator_spec.lua -- Unit tests for Phase 1-5 End-to-End Orchestrator

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Ensure dependencies exist
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
local events = addon:GetModule("Events")
events:OnInitialize()

local debug = StubBetterBagsModule("Debug")
debug.Log = function() end
debug.Inspect = function() end

local database = StubBetterBagsModule("Database")
database.GetNewItemTime = function() return 30 end
database.GetStackingOptions = function()
  return { dontMergeTransmog = false }
end
database.GetCategoryFilter = function() return false end
database.GetEnableBankBag = function() return false end
database.GetMarkRecentItems = function() return false end

local const = StubBetterBagsModule("Constants")
const.BAG_KIND = { UNDEFINED = -1, BACKPACK = 0, BANK = 1 }
const.BANK_BAGS = { [6] = 6, [7] = 7 }
const.BACKPACK_BAGS = { [0] = 0, [1] = 1 }
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
const.ITEM_QUALITY = { Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
const.SEARCH_CATEGORY_GROUP_BY = { NONE = 0, TYPE = 1, SUBTYPE = 2, EXPANSION = 3 }
const.EXPANSION_MAP = { [0] = "Classic" }
const.BRIEF_EXPANSION_MAP = {
  [0] = "classic",
  [1] = "bc",
  [2] = "wotlk",
  [3] = "cata",
  [9] = "tww",
}
const.BINDING_MAP = { [0] = "", [1] = "boe", [2] = "soulbound" }
const.INVENTORY_TYPE_TO_INVENTORY_SLOTS = { [1] = {1} }

_G.Enum = _G.Enum or {}
_G.Enum.ItemClass = _G.Enum.ItemClass or { Tradegoods = 7, Container = 1 }

local L = StubBetterBagsModule("Localization")
function L:G(key) return key end

local equipmentSets = StubBetterBagsModule("EquipmentSets")
equipmentSets.GetItemSets = function() return nil end
equipmentSets.Update = function() end

local tooltipScanner = StubBetterBagsModule("TooltipScanner")
tooltipScanner.GetTooltipText = function() return "" end

LoadBetterBagsModule("util/query.lua")
LoadBetterBagsModule("util/trees/trees.lua")
LoadBetterBagsModule("util/trees/intervaltree.lua")
LoadBetterBagsModule("data/search_new.lua")
LoadBetterBagsModule("core/async.lua")
ResetModuleStub("Stacks", "data/stacks_new.lua")
LoadBetterBagsModule("data/stacks_new.lua")
ResetModuleStub("Binding", "data/binding.lua")
LoadBetterBagsModule("data/binding.lua")

local categories = StubBetterBagsModule("Categories")
categories.GetSortedSearchCategories = function() return {} end

-- Load items, slots, and stacks
ResetModuleStub("Items", "data/items_new.lua")
LoadBetterBagsModule("data/items_new.lua")
loadfile("data/slots.lua")("BetterBags")
local items = addon:GetModule("Items")

-- Mock basic WOW API
_G.C_Container = _G.C_Container or {}
_G.C_Item = _G.C_Item or {}
_G.GetInventoryItemLink = function() return nil end

describe("Phase 1-5 Orchestrator (ProcessRefresh)", function()
  local savedGetContainerNumSlots
  local savedGetContainerItemID
  local savedGetContainerItemLink
  local savedGetContainerItemInfo
  local savedGetItemInfo

  before_each(function()
    savedGetContainerNumSlots = _G.C_Container.GetContainerNumSlots
    savedGetContainerItemID = _G.C_Container.GetContainerItemID
    savedGetContainerItemLink = _G.C_Container.GetContainerItemLink
    savedGetContainerItemInfo = _G.C_Container.GetContainerItemInfo
    savedGetItemInfo = _G.C_Item.GetItemInfo

    _G.C_Container.GetContainerNumSlots = function(bagid) return 2 end
    _G.C_Container.GetContainerItemID = function(bagid, slotid) return nil end
    _G.C_Container.GetContainerItemLink = function(bagid, slotid) return nil end
    _G.C_Container.GetContainerItemInfo = function(bagid, slotid) return nil end
    _G.C_Item.GetItemInfo = function() return nil end

    items:OnInitialize()
    items:OnEnable()

    local search = addon:GetModule("Search")
    search:OnInitialize()
  end)

  after_each(function()
    _G.C_Container.GetContainerNumSlots = savedGetContainerNumSlots
    _G.C_Container.GetContainerItemID = savedGetContainerItemID
    _G.C_Container.GetContainerItemLink = savedGetContainerItemLink
    _G.C_Container.GetContainerItemInfo = savedGetContainerItemInfo
    _G.C_Item.GetItemInfo = savedGetItemInfo
  end)

  it("should sequentially execute Phase 2 (Farming), Phase 3 (Stacking), and Phase 4 (Search Indexing)", function()
    -- Set up test mock data: 1 non-empty item in bag 0 slot 1
    _G.C_Container.GetContainerItemID = function(bagid, slotid)
      if bagid == 0 and slotid == 1 then return 54321 end
      return nil
    end
    _G.C_Container.GetContainerItemLink = function(bagid, slotid)
      if bagid == 0 and slotid == 1 then return "|Hitem:54321|h[Mock item]|h" end
      return nil
    end
    _G.C_Item.GetItemInfo = function(itemID)
      return "Mock item", "|Hitem:54321|h[Mock item]|h", 2, 100, 1, "Tradegoods", "Parts", 20, "INVTYPE_NON_EQUIP", 134400, 10, 7, 0, 1, 0, 0, false
    end

    local ctx = addon:GetModule("Context"):New("TestRefresh")
    local search = addon:GetModule("Search")

    -- Spy on search indexing and stacking
    spy.on(search, "IndexItems")

    -- Call ProcessRefresh for backpack
    items:ProcessRefresh(ctx, const.BAG_KIND.BACKPACK)

    -- Assert that ProcessRefresh created and filled SlotInfo
    local slotInfo = items.slotInfo[const.BAG_KIND.BACKPACK]
    assert.is_not_nil(slotInfo)

    -- Assert Phase 2 Harvesting: SlotInfo itemsBySlotKey has the item
    local item = slotInfo.itemsBySlotKey["0_1"]
    assert.is_not_nil(item)
    assert.is_false(item.isItemEmpty)
    assert.are.equal(54321, item.itemInfo.itemID)

    -- Assert Phase 3 Stacking: Item is added to stacks
    local stackInfo = slotInfo.stacks:GetStackInfo(item.itemHash)
    assert.is_not_nil(stackInfo)
    assert.are.equal("0_1", stackInfo.rootItem)

    -- Assert Phase 4 Search Indexing: search:IndexItems was called with slotInfo.itemsBySlotKey
    assert.spy(search.IndexItems).was.called(1)
  end)

  it("should dispatch completion messages on done", function()
    local ctx = addon:GetModule("Context"):New("TestRefresh")
    local messageDispatched = false

    events:RegisterMessage("items/RefreshBackpack/Done", function(_, dispatchedCtx, slotInfo)
      messageDispatched = true
      assert.are.equal(ctx, dispatchedCtx)
      assert.is_not_nil(slotInfo)
    end)

    items:ProcessRefresh(ctx, const.BAG_KIND.BACKPACK)
    assert.is_true(messageDispatched)
  end)

  describe("Stack Resolution with dontMergePartial option", function()
    local savedGetStackingOptions

    before_each(function()
      savedGetStackingOptions = database.GetStackingOptions
    end)

    after_each(function()
      database.GetStackingOptions = savedGetStackingOptions
    end)

    it("should keep partial stack separate when dontMergePartial is true", function()
      -- Stacking option: dontMergePartial = true, mergeStacks = true
      database.GetStackingOptions = function()
        return {
          mergeStacks = true,
          dontMergePartial = true,
          mergeUnstackable = true,
          unmergeAtShop = false,
        }
      end

      -- Mock items:
      -- 1. Slot 0_1: Silk Cloth (itemID 100, currentItemCount = 20, itemStackCount = 20) -> Full stack
      -- 2. Slot 0_2: Silk Cloth (itemID 100, currentItemCount = 20, itemStackCount = 20) -> Full stack (this will be root as 0_2 > 0_1)
      -- 3. Slot 1_1: Silk Cloth (itemID 100, currentItemCount = 5, itemStackCount = 20) -> Partial stack
      _G.C_Container.GetContainerNumSlots = function(bagid) return 2 end
      _G.C_Container.GetContainerItemID = function(bagid, slotid)
        if (bagid == 0 and slotid == 1) or (bagid == 0 and slotid == 2) or (bagid == 1 and slotid == 1) then
          return 100
        end
        return nil
      end
      _G.C_Container.GetContainerItemLink = function(bagid, slotid)
        if (bagid == 0 and slotid == 1) or (bagid == 0 and slotid == 2) or (bagid == 1 and slotid == 1) then
          return "|Hitem:100|h[Silk Cloth]|h"
        end
        return nil
      end
      _G.C_Item.GetItemInfo = function(itemID)
        return "Silk Cloth", "|Hitem:100|h[Silk Cloth]|h", 1, 1, 1, "Tradegoods", "Material", 20, "INVTYPE_NON_EQUIP", 134400, 10, 7, 0, 1, 0, 0, false
      end

      -- We also need C_Container.GetContainerItemInfo to return correct stackCount
      _G.C_Container.GetContainerItemInfo = function(bagid, slotid)
        if bagid == 1 and slotid == 1 then
          return { stackCount = 5, hyperlink = "|Hitem:100|h[Silk Cloth]|h", itemID = 100 }
        elseif (bagid == 0 and slotid == 1) or (bagid == 0 and slotid == 2) then
          return { stackCount = 20, hyperlink = "|Hitem:100|h[Silk Cloth]|h", itemID = 100 }
        end
        return nil
      end

      local ctx = addon:GetModule("Context"):New("TestPartialStack")
      items:ProcessRefresh(ctx, const.BAG_KIND.BACKPACK)

      local slotInfo = items.slotInfo[const.BAG_KIND.BACKPACK]
      assert.is_not_nil(slotInfo)

      -- With dontMergePartial = true, the visible slots should be:
      -- 1. "0_2" (root of the full stacks: 0_2 + 0_1 = 40 count)
      -- 2. "1_1" (partial stack, independent button with 5 count)
      local visible = slotInfo:GetVisibleItems()
      assert.is_not_nil(visible["0_2"])
      assert.is_not_nil(visible["1_1"])
      assert.is_nil(visible["0_1"]) -- Child merged under 0_2

      assert.are.equal(40, visible["0_2"].stackedCount)
      assert.is_nil(visible["1_1"].stackedCount) -- Not merged
    end)

    it("should merge partial stack when dontMergePartial is false", function()
      -- Stacking option: dontMergePartial = false, mergeStacks = true
      database.GetStackingOptions = function()
        return {
          mergeStacks = true,
          dontMergePartial = false,
          mergeUnstackable = true,
          unmergeAtShop = false,
        }
      end

      _G.C_Container.GetContainerNumSlots = function(bagid) return 2 end
      _G.C_Container.GetContainerItemID = function(bagid, slotid)
        if (bagid == 0 and slotid == 1) or (bagid == 0 and slotid == 2) or (bagid == 1 and slotid == 1) then
          return 100
        end
        return nil
      end
      _G.C_Container.GetContainerItemLink = function(bagid, slotid)
        if (bagid == 0 and slotid == 1) or (bagid == 0 and slotid == 2) or (bagid == 1 and slotid == 1) then
          return "|Hitem:100|h[Silk Cloth]|h"
        end
        return nil
      end
      _G.C_Item.GetItemInfo = function(itemID)
        return "Silk Cloth", "|Hitem:100|h[Silk Cloth]|h", 1, 1, 1, "Tradegoods", "Material", 20, "INVTYPE_NON_EQUIP", 134400, 10, 7, 0, 1, 0, 0, false
      end

      _G.C_Container.GetContainerItemInfo = function(bagid, slotid)
        if bagid == 1 and slotid == 1 then
          return { stackCount = 5, hyperlink = "|Hitem:100|h[Silk Cloth]|h", itemID = 100 }
        elseif (bagid == 0 and slotid == 1) or (bagid == 0 and slotid == 2) then
          return { stackCount = 20, hyperlink = "|Hitem:100|h[Silk Cloth]|h", itemID = 100 }
        end
        return nil
      end

      local ctx = addon:GetModule("Context"):New("TestPartialStackMerge")
      items:ProcessRefresh(ctx, const.BAG_KIND.BACKPACK)

      local slotInfo = items.slotInfo[const.BAG_KIND.BACKPACK]
      assert.is_not_nil(slotInfo)

      -- With dontMergePartial = false, the visible slots should be:
      -- Only "0_2" (root of all stacks: 0_2 + 0_1 + 1_1 = 45 count)
      local visible = slotInfo:GetVisibleItems()
      assert.is_not_nil(visible["0_2"])
      assert.is_nil(visible["0_1"])
      assert.is_nil(visible["1_1"]) -- All merged under 0_2

      assert.are.equal(45, visible["0_2"].stackedCount)
    end)
  end)
end)
