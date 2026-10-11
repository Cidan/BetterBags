-- refresh_pipeline_spec.lua -- Data-phase correctness of items:ProcessRefresh.
--
-- These tests drive the real Items/Search/Stacks/Binding/Async/Refresh modules on top
-- of mocked C_Container / C_Item / C_NewItems client APIs, and assert on the committed
-- SlotInfo state that the views receive.

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
local events = addon:GetModule("Events")
events:Init()
local context = addon:GetModule("Context")

local overrides = {}
local function override(tbl, key, value)
  table.insert(overrides, { tbl = tbl, key = key, original = tbl[key] })
  tbl[key] = value
end
local function restoreOverrides()
  for i = #overrides, 1, -1 do
    local o = overrides[i]
    o.tbl[o.key] = o.original
  end
  overrides = {}
end

-- Stub modules registered by this spec are torn down again so later spec files can
-- load the real module (AceAddon refuses to NewModule a name that already exists).
local createdStubs = {}
local function stubModule(name)
  local mod, created = _G.StubBetterBagsModule(name)
  if created then
    table.insert(createdStubs, name)
  end
  return mod
end
local function resetCreatedStubs()
  for i = #createdStubs, 1, -1 do
    ResetModuleStub(createdStubs[i])
  end
  createdStubs = {}
end

local itemNames = {
  [101] = "Alpha Sword",
  [201] = "Delta Axe",
  [202] = "Beta Shield",
  [303] = "Gamma Ring",
}

local const, database, categories, searchText
local mockContainer, newSlots, removedNewItems, mockStats

local function stubModules()
  local debug = stubModule("Debug")
  override(debug, "Log", function() end)
  override(debug, "Inspect", function() end)

  local L = stubModule("Localization")
  override(L, "G", function(_, key) return key end)

  const = stubModule("Constants")
  override(const, "BAG_KIND", { UNDEFINED = -1, BACKPACK = 0, BANK = 1 })
  override(const, "BAG_VIEW", { UNDEFINED = 0, SECTION_GRID = 2, SECTION_ALL_BAGS = 4 })
  override(const, "BANK_BAGS", { [6] = 6, [7] = 7 })
  override(const, "ACCOUNT_BANK_BAGS", { [13] = 13 })
  override(const, "BACKPACK_BAGS", { [0] = 0, [1] = 1 })
  override(const, "BANK_TAB", { BANK = 6, REAGENT = 2, ACCOUNT_BANK_1 = 13 })
  override(const, "BANK_ONLY_BAGS", {})
  override(const, "BINDING_SCOPE", {
    UNKNOWN = 0, NONBINDING = 1, BOUND = 2, BOE = 3, BOU = 4, QUEST = 5,
    SOULBOUND = 6, REFUNDABLE = 7, ACCOUNT = 8, BNET = 9, WUE = 10,
  })
  override(const, "BINDING_MAP", { [0] = "", [1] = "boe", [2] = "soulbound" })
  override(const, "ITEM_QUALITY", { Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 })
  override(const, "BAG_SUBTYPE_TO_QUALITY", { [0] = 1, [1] = 2, [2] = 2, [3] = 2, [4] = 2, [99] = 2 })
  override(const, "SEARCH_CATEGORY_GROUP_BY", { NONE = 0, TYPE = 1, SUBTYPE = 2, EXPANSION = 3 })
  override(const, "EXPANSION_MAP", { [0] = "Classic" })
  override(const, "BRIEF_EXPANSION_MAP", { [0] = "classic" })
  override(const, "TRADESKILL_MAP", {})
  override(const, "INVENTORY_TYPE_TO_INVENTORY_SLOTS", { [1] = { 1 } })

  database = stubModule("Database")
  override(database, "GetNewItemTime", function() return 30 end)
  override(database, "GetStackingOptions", function() return { mergeStacks = false, dontMergeTransmog = false } end)
  override(database, "GetCategoryFilter", function() return false end)
  override(database, "GetEnableBankBag", function() return false end)
  override(database, "GetMarkRecentItems", function() return false end)
  override(database, "GetShowAllFreeSpace", function() return false end)
  override(database, "GetBagView", function() return const.BAG_VIEW.SECTION_GRID end)
  override(database, "GetUpgradeIconProvider", function() return "None" end)
  override(database, "GetUpgradeIconProviderUserSet", function() return false end)
  override(database, "GetGroupsEnabled", function() return false end)
  override(database, "GetActiveGroup", function() return 1 end)
  override(database, "GetShowBankTabs", function() return false end)

  local equipmentSets = stubModule("EquipmentSets")
  override(equipmentSets, "GetItemSets", function() return nil end)
  override(equipmentSets, "Update", function() end)

  local tooltipScanner = stubModule("TooltipScanner")
  override(tooltipScanner, "GetTooltipText", function() return "" end)

  categories = stubModule("Categories")
  override(categories, "GetSortedSearchCategories", function() return {} end)
  override(categories, "GetCustomCategory", function() return nil, nil end)
  override(categories, "DoesCategoryExist", function() return false end)
  override(categories, "IsCategoryShown", function() return true end)
  override(categories, "CreateCategory", function() end)

  local sort = stubModule("Sort")
  override(sort, "GetItemDataSortFunction", function() return nil end)
  override(sort, "GetCategoryDataSortFunction", function() return nil end)
  override(sort, "SortItemDataBySlot", function() return false end)

  local searchBox = stubModule("SearchBox")
  override(searchBox, "GetSearchText", function() return searchText end)

  local loader = stubModule("ItemLoader")
  override(loader, "TellMeWhenABagIsUpdated", function() end)
  override(loader, "GetItemMixinFromSlotKey", function() return nil end)
end

local savedGlobals = {}
local function saveGlobal(tbl, key)
  table.insert(savedGlobals, { tbl = tbl, key = key, original = tbl[key] })
end
local function restoreGlobals()
  for i = #savedGlobals, 1, -1 do
    local g = savedGlobals[i]
    g.tbl[g.key] = g.original
  end
  savedGlobals = {}
end

local function stubClientAPIs()
  _G.C_Container = _G.C_Container or {}
  _G.C_Item = _G.C_Item or {}
  _G.C_NewItems = _G.C_NewItems or {}
  _G.Enum = _G.Enum or {}
  _G.Enum.ItemClass = _G.Enum.ItemClass or { Tradegoods = 7, Container = 1 }

  local keys = {
    { _G.C_Container, "GetContainerNumSlots" },
    { _G.C_Container, "GetContainerItemID" },
    { _G.C_Container, "GetContainerItemLink" },
    { _G.C_Container, "GetContainerItemInfo" },
    { _G.C_Container, "ContainerIDToInventoryID" },
    { _G.C_Item, "GetItemInfo" },
    { _G.C_Item, "GetItemGUID" },
    { _G.C_Item, "GetItemStats" },
    { _G.C_Item, "GetItemSubClassInfo" },
    { _G.C_NewItems, "IsNewItem" },
    { _G.C_NewItems, "RemoveNewItem" },
    { _G, "GetInventoryItemLink" },
    { _G.Item, "CreateFromEquipmentSlot" },
  }
  for _, k in ipairs(keys) do
    saveGlobal(k[1], k[2])
  end

  _G.C_Container.GetContainerNumSlots = function(bagid)
    return mockContainer[bagid] and #mockContainer[bagid] or 0
  end
  _G.C_Container.GetContainerItemID = function(bagid, slotid)
    local slot = mockContainer[bagid] and mockContainer[bagid][slotid]
    return slot and slot.itemID or nil
  end
  _G.C_Container.GetContainerItemLink = function(bagid, slotid)
    local slot = mockContainer[bagid] and mockContainer[bagid][slotid]
    if not slot or not slot.itemID then return nil end
    if slot.link then return slot.link end
    local name = itemNames[slot.itemID] or ("TestItem " .. slot.itemID)
    return "|cffffffff|Hitem:" .. slot.itemID .. "|h[" .. name .. "]|h|r"
  end
  _G.C_Container.GetContainerItemInfo = function(bagid, slotid)
    local slot = mockContainer[bagid] and mockContainer[bagid][slotid]
    if not slot or not slot.itemID then return nil end
    local info = {
      iconFileID = 134400,
      stackCount = slot.count or 1,
      isLocked = false,
      quality = 1,
      isReadable = false,
      hasLoot = false,
      hyperlink = _G.C_Container.GetContainerItemLink(bagid, slotid),
      isFiltered = false,
      hasNoValue = false,
      itemID = slot.itemID,
      isBound = false,
      itemName = itemNames[slot.itemID] or ("TestItem " .. slot.itemID),
    }
    -- slot.info overrides individual ContainerItemInfo fields.
    for k, v in pairs(slot.info or {}) do info[k] = v end
    return info
  end
  _G.C_Container.ContainerIDToInventoryID = function() return nil end
  _G.C_Item.GetItemInfo = function(itemID)
    local id = tonumber(itemID) or tonumber(tostring(itemID):match("item:(%d+)")) or 0
    local name = itemNames[id] or ("TestItem " .. id)
    return name, "|cffffffff|Hitem:" .. id .. "|h[" .. name .. "]|h|r",
      1, 100, 1, "Misc", "Junk", 20, "INVTYPE_NON_EQUIP", 134400, 10, 1, 0, 1, 0, 0, false
  end
  _G.C_Item.GetItemGUID = function(location)
    local bagid, slotid = location:GetBagAndSlot()
    local slot = bagid and mockContainer[bagid] and mockContainer[bagid][slotid]
    return slot and slot.guid or ""
  end
  _G.C_Item.GetItemStats = function(link) return mockStats[link] end
  _G.C_Item.GetItemSubClassInfo = function() return "Bag" end
  _G.C_NewItems.IsNewItem = function(bagid, slotid)
    return newSlots[bagid .. "_" .. slotid] or false
  end
  _G.C_NewItems.RemoveNewItem = function(bagid, slotid)
    newSlots[bagid .. "_" .. slotid] = nil
    table.insert(removedNewItems, bagid .. "_" .. slotid)
  end
  _G.GetInventoryItemLink = function() return nil end
  -- Nothing is equipped unless a test equips something, consistent with GetInventoryItemLink.
  _G.Item.CreateFromEquipmentSlot = function(_, slot)
    local loc = _G.ItemLocation:CreateFromEquipmentSlot(slot)
    local mixin = {}
    function mixin:GetItemLocation() return loc end
    function mixin:IsItemEmpty() return true end
    return mixin
  end
end

local function loadRealModules()
  LoadBetterBagsModule("util/query.lua")
  LoadBetterBagsModule("util/trees/trees.lua")
  LoadBetterBagsModule("util/trees/intervaltree.lua")
  ResetModuleStub("Search", "data/search.lua")
  LoadBetterBagsModule("data/search.lua")
  LoadBetterBagsModule("core/async.lua")
  ResetModuleStub("Stacks", "data/stacks.lua")
  LoadBetterBagsModule("data/stacks.lua")
  ResetModuleStub("Binding", "data/binding.lua")
  LoadBetterBagsModule("data/binding.lua")
  ResetModuleStub("Items", "data/items.lua")
  LoadBetterBagsModule("data/items.lua")
  LoadBetterBagsModule("data/slots.lua")
  ResetModuleStub("Refresh", "data/refresh.lua")
  LoadBetterBagsModule("data/refresh.lua")
end

local function unloadRealModules()
  ResetModuleStub("Refresh", "data/refresh.lua")
  ResetModuleStub("Items", "data/items.lua")
  ResetModuleStub("Binding", "data/binding.lua")
  ResetModuleStub("Stacks", "data/stacks.lua")
  ResetModuleStub("Search", "data/search.lua")
end

describe("Refresh pipeline (ProcessRefresh) data-phase correctness", function()
  local items, refresh, search, async
  local savedYield, savedIsRetail, savedAtBank, savedBags

  local function refreshBackpack(opts)
    local ctx = context:New("refresh")
    if opts and opts.bags then
      ctx:Set("targetedBags", opts.bags)
    end
    if opts and opts.wipe then
      items:ClearItemCache(ctx)
      ctx:Set("wipe", true)
    end
    items:RefreshBackpack(ctx)
    return items.slotInfo[const.BAG_KIND.BACKPACK]
  end

  before_each(function()
    mockContainer = {}
    newSlots = {}
    removedNewItems = {}
    mockStats = {}
    searchText = ""

    stubModules()
    stubClientAPIs()
    loadRealModules()

    items = addon:GetModule("Items")
    refresh = addon:GetModule("Refresh")
    search = addon:GetModule("Search")
    async = addon:GetModule("Async")

    savedYield = async.Yield
    async.Yield = function() end
    savedIsRetail, savedAtBank, savedBags = addon.isRetail, addon.atBank, addon.Bags
    addon.isRetail = true
    addon.isClassic = false
    addon.atBank = false
    addon.Bags = {}

    search:Init()
    items:Init()
    items._firstLoad[const.BAG_KIND.BACKPACK] = false
    items._firstLoad[const.BAG_KIND.BANK] = false
    refresh:Init()
  end)

  after_each(function()
    async.Yield = savedYield
    addon.isRetail, addon.atBank, addon.Bags = savedIsRetail, savedAtBank, savedBags
    unloadRealModules()
    restoreGlobals()
    restoreOverrides()
    resetCreatedStubs()
  end)

  it("clears the Recent Items status of an item that was only moved between slots", function()
    override(database, "GetCategoryFilter", function(_, _, filter) return filter == "RecentItems" end)
    mockContainer[0] = {
      { itemID = 101, guid = "guid-101", count = 1 },
      {},
    }
    newSlots["0_1"] = true

    local slotInfo = refreshBackpack()
    assert.equal("Recent Items", slotInfo.itemsBySlotKey["0_1"].itemInfo.category)
    assert.is_not_nil(items._newItemTimers[const.BAG_KIND.BACKPACK]["guid-101"])

    -- The player drags the item into slot 2. The client drops its own new-item flag on
    -- pickup; the addon must drop its GUID timer for the moved item as well.
    newSlots["0_1"] = nil
    mockContainer[0] = {
      {},
      { itemID = 101, guid = "guid-101", count = 1 },
    }
    slotInfo = refreshBackpack({ bags = { [0] = true } })

    local moved = slotInfo.itemsBySlotKey["0_2"]
    assert.is_not_nil(moved)
    assert.equal("guid-101", moved.itemInfo.itemGUID)
    assert.is_nil(items._newItemTimers[const.BAG_KIND.BACKPACK]["guid-101"], "moved item's recent timer must be cleared")
    assert.is_false(moved.itemInfo.isNewItem)
    assert.are_not.equal("Recent Items", moved.itemInfo.category)
  end)

  -- A sweep re-reads only the slots whose contents changed: a slot whose client container
  -- info and item GUID match the committed item keeps that item (refreshing the fields that
  -- change without the slot changing), so a targeted sweep of a 36-slot bag after one potion
  -- re-reads one slot, not 36.
  describe("per-slot harvest cache", function()
    local harvested

    local function harvestedKeys()
      local keys = {}
      for _, key in ipairs(harvested) do keys[#keys + 1] = key end
      table.sort(keys)
      return keys
    end

    before_each(function()
      harvested = {}
      local attach = items.AttachItemInfo
      override(items, "AttachItemInfo", function(self, data, kind, ...)
        table.insert(harvested, data.bagid .. "_" .. data.slotid)
        return attach(self, data, kind, ...)
      end)
    end)

    it("keeps unchanged slots and re-reads the changed one on a targeted sweep", function()
      mockContainer[0] = {
        { itemID = 101, guid = "guid-101", count = 1 },
        { itemID = 102, guid = "guid-102", count = 5 },
      }
      local kept = refreshBackpack({ wipe = true }).itemsBySlotKey["0_1"]
      harvested = {}

      mockContainer[0][2].count = 4
      local slotInfo = refreshBackpack({ bags = { [0] = true } })
      assert.are.same({ "0_2" }, harvestedKeys())
      assert.equal(kept, slotInfo.itemsBySlotKey["0_1"])
      assert.equal(4, slotInfo.itemsBySlotKey["0_2"].itemInfo.currentItemCount)
    end)

    it("reads a changed slot's container info once", function()
      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 } }
      refreshBackpack({ wipe = true })
      local reads = 0
      local read = _G.C_Container.GetContainerItemInfo
      override(_G.C_Container, "GetContainerItemInfo", function(bagid, slotid)
        reads = reads + 1
        return read(bagid, slotid)
      end)
      mockContainer[0][1].count = 2
      refreshBackpack({ bags = { [0] = true } })
      assert.equal(1, reads)
    end)

    it("re-reads a slot whose item changed identity even though its container info matches", function()
      mockContainer[0] = { { itemID = 101, guid = "guid-a", count = 20 } }
      refreshBackpack({ wipe = true })
      harvested = {}
      mockContainer[0][1].guid = "guid-b"
      local slotInfo = refreshBackpack({ bags = { [0] = true } })
      assert.are.same({ "0_1" }, harvestedKeys())
      assert.equal("guid-b", slotInfo.itemsBySlotKey["0_1"].itemInfo.itemGUID)
    end)

    -- Scaling (level, timewalking-style events) can change an item's current item level
    -- without changing its link, its container info or its GUID.
    it("re-reads a slot whose current item level changed", function()
      local level = 100
      local currentLevel = _G.C_Item.GetCurrentItemLevel
      override(_G.C_Item, "GetCurrentItemLevel", function(location)
        local bagid, slotid = location:GetBagAndSlot()
        if bagid == 0 and slotid == 1 then return level end
        return currentLevel(location)
      end)
      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 } }
      refreshBackpack({ wipe = true })
      harvested = {}
      refreshBackpack({ bags = { [0] = true } })
      assert.are.same({}, harvestedKeys())
      level = 60
      local slotInfo = refreshBackpack({ bags = { [0] = true } })
      assert.are.same({ "0_1" }, harvestedKeys())
      assert.equal(60, slotInfo.itemsBySlotKey["0_1"].itemInfo.currentItemLevel)
    end)

    it("re-reads every slot on a wipe sweep", function()
      mockContainer[0] = {
        { itemID = 101, guid = "guid-101", count = 1 },
        { itemID = 102, guid = "guid-102", count = 1 },
      }
      refreshBackpack({ wipe = true })
      harvested = {}
      refreshBackpack({ wipe = true })
      assert.are.same({ "0_1", "0_2" }, harvestedKeys())
    end)

    it("re-reads a slot first read while the client had no item info for it", function()
      local cold = true
      local getItemInfo = _G.C_Item.GetItemInfo
      override(_G.C_Item, "GetItemInfo", function(itemID)
        if cold then return nil end
        return getItemInfo(itemID)
      end)
      itemNames[909] = "Warm Name"
      mockContainer[0] = { { itemID = 909, guid = "guid-909", count = 1 } }
      refreshBackpack({ wipe = true })
      cold = false
      harvested = {}
      local slotInfo = refreshBackpack({ bags = { [0] = true } })
      assert.are.same({ "0_1" }, harvestedKeys())
      assert.equal("Warm Name", slotInfo.itemsBySlotKey["0_1"].itemInfo.itemName)

      harvested = {}
      refreshBackpack({ bags = { [0] = true } })
      assert.are.same({}, harvestedKeys(), "once read warm, the slot is kept")
      itemNames[909] = nil
    end)

    -- A fresh read takes the new-item flag (the glow) from the client alone; the Recent
    -- Items timer decides the category. A kept slot must agree, or an item the player
    -- hovered (which drops the client flag) keeps glowing until its timer runs out.
    it("computes a kept slot's new-item flag exactly as a fresh read does", function()
      mockContainer[0] = {
        { itemID = 101, guid = "guid-101", count = 1 },
        { itemID = 102, guid = "guid-102", count = 1 },
      }
      newSlots["0_1"] = true
      local first = refreshBackpack({ wipe = true })
      assert.is_true(first.itemsBySlotKey["0_1"].itemInfo.isNewItem)
      assert.is_not_nil(items._newItemTimers[const.BAG_KIND.BACKPACK]["guid-101"])

      newSlots["0_1"] = nil
      harvested = {}
      mockContainer[0][2].count = 2
      local kept = refreshBackpack({ bags = { [0] = true } }).itemsBySlotKey["0_1"]
      assert.are.same({ "0_2" }, harvestedKeys())

      local fresh = { bagid = 0, slotid = 1 }
      items:AttachItemInfo(fresh, const.BAG_KIND.BACKPACK)
      assert.is_false(fresh.itemInfo.isNewItem)
      assert.is_false(kept.itemInfo.isNewItem)
    end)

    -- Each ContainerItemInfo field the check compares; any change re-reads the slot. An
    -- enchant or an upgrade changes the link but keeps the GUID.
    local SWORD = "|cnIQ1:|Hitem:101:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:::|h[Alpha Sword]|h|r"
    local fieldChanges = {
      { "link", function(slot) slot.link = "|cnIQ1:|Hitem:101:6:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:::|h[Alpha Sword]|h|r" end },
      { "item ID", function(slot) slot.info = { itemID = 999 } end },
      { "name", function(slot) slot.info = { itemName = "Renamed" } end },
      { "icon", function(slot) slot.info = { iconFileID = 1 } end },
      { "quality", function(slot) slot.info = { quality = 4 } end },
      { "lock", function(slot) slot.info = { isLocked = true } end },
      { "bound state", function(slot) slot.info = { isBound = true } end },
      { "readable", function(slot) slot.info = { isReadable = true } end },
      { "loot", function(slot) slot.info = { hasLoot = true } end },
      { "filter", function(slot) slot.info = { isFiltered = true } end },
      { "no-value", function(slot) slot.info = { hasNoValue = true } end },
    }
    for _, change in ipairs(fieldChanges) do
      it("re-reads a slot whose " .. change[1] .. " changed", function()
        mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1, link = SWORD } }
        refreshBackpack({ wipe = true })
        harvested = {}
        change[2](mockContainer[0][1])
        refreshBackpack({ bags = { [0] = true } })
        assert.are.same({ "0_1" }, harvestedKeys())
      end)
    end

    it("does not change the committed items it keeps until the sweep commits", function()
      override(database, "GetStackingOptions", function()
        return { mergeStacks = true, mergeUnstackable = true, unmergeAtShop = false,
          dontMergePartial = false, dontMergeTransmog = false }
      end)
      local shield = "|cnIQ1:|Hitem:102:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:::|h[Beta Shield]|h|r"
      mockContainer[0] = {
        { itemID = 101, guid = "guid-a", count = 5, link = SWORD },
        { itemID = 101, guid = "guid-b", count = 3, link = SWORD },
        { itemID = 102, guid = "guid-c", count = 1, link = shield },
      }
      local root = refreshBackpack({ wipe = true }).itemsBySlotKey["0_1"]
      assert.equal(8, root.stackedCount)
      -- Between the harvest and the commit (one frame apart) the bag may draw from the
      -- committed state; it must still show the stack total.
      local stackedDuringSweep
      local harvest = items.Phase2_Harvest
      override(items, "Phase2_Harvest", function(self, ...)
        local a, b = harvest(self, ...)
        stackedDuringSweep = root.stackedCount
        return a, b
      end)
      mockContainer[0][3].count = 2
      refreshBackpack({ bags = { [0] = true } })
      assert.equal(8, stackedDuringSweep)
    end)

    it("refreshes a kept slot's new-item flag, gear sets, quest state and tooltip text", function()
      mockContainer[0] = {
        { itemID = 101, guid = "guid-101", count = 1 },
        { itemID = 102, guid = "guid-102", count = 1 },
      }
      refreshBackpack({ wipe = true })

      newSlots["0_1"] = true
      local equipmentSets = addon:GetModule("EquipmentSets")
      override(equipmentSets, "GetItemSets", function(_, bagid, slotid)
        if bagid == 0 and slotid == 1 then return { "Tank" } end
        return nil
      end)
      local tooltipScanner = addon:GetModule("TooltipScanner")
      override(tooltipScanner, "GetTooltipText", function(_, bagid, slotid)
        if bagid == 0 and slotid == 1 then return "Use: Restores health." end
        return ""
      end)
      local questInfo = _G.C_Container.GetContainerItemQuestInfo
      override(_G.C_Container, "GetContainerItemQuestInfo", function(bagid, slotid)
        if bagid == 0 and slotid == 1 then return { isQuestItem = true, questID = 9, isActive = true } end
        return questInfo(bagid, slotid)
      end)
      harvested = {}
      mockContainer[0][2].count = 2
      local item = refreshBackpack({ bags = { [0] = true } }).itemsBySlotKey["0_1"]

      assert.are.same({ "0_2" }, harvestedKeys())
      assert.is_true(item.itemInfo.isNewItem)
      assert.are.same({ "Tank" }, item.itemInfo.equipmentSets)
      assert.equal("Use: Restores health.", item.itemInfo.tooltipText)
      assert.is_true(item.questInfo.isActive)
    end)

    describe("virtual stacks", function()
      before_each(function()
        override(database, "GetStackingOptions", function()
          return { mergeStacks = true, mergeUnstackable = true, unmergeAtShop = false,
            dontMergePartial = false, dontMergeTransmog = false }
        end)
      end)

      it("totals a stack from current counts when its piles were kept", function()
        -- Full retail links: the short mock link parses to item ID 0, so two different items
        -- without one would share a hash.
        local swordLink = "|cnIQ1:|Hitem:101:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:::|h[Alpha Sword]|h|r"
        local shieldLink = "|cnIQ1:|Hitem:102:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:::|h[Beta Shield]|h|r"
        mockContainer[0] = {
          { itemID = 101, guid = "guid-a", count = 5, link = swordLink },
          { itemID = 101, guid = "guid-b", count = 3, link = swordLink },
          { itemID = 102, guid = "guid-c", count = 1, link = shieldLink },
        }
        local first = refreshBackpack({ wipe = true })
        assert.are_not.equal(first.itemsBySlotKey["0_1"].itemHash, first.itemsBySlotKey["0_3"].itemHash)
        harvested = {}
        mockContainer[0][3].count = 2
        local slotInfo = refreshBackpack({ bags = { [0] = true } })
        assert.are.same({ "0_3" }, harvestedKeys())
        assert.equal(8, slotInfo.visibleItemsBySlotKey["0_1"].stackedCount)
        assert.is_nil(slotInfo.visibleItemsBySlotKey["0_2"])
      end)

      it("re-roots a stack onto a kept pile when the root pile shrinks", function()
        mockContainer[0] = {
          { itemID = 101, guid = "guid-a", count = 5 },
          { itemID = 101, guid = "guid-b", count = 3 },
        }
        refreshBackpack({ wipe = true })
        harvested = {}
        mockContainer[0][1].count = 2
        local slotInfo = refreshBackpack({ bags = { [0] = true } })
        assert.are.same({ "0_1" }, harvestedKeys())
        assert.is_nil(slotInfo.visibleItemsBySlotKey["0_1"])
        assert.equal(5, slotInfo.visibleItemsBySlotKey["0_2"].stackedCount)
      end)

      it("unmerges kept piles when the stacking rule stops applying", function()
        mockContainer[0] = {
          { itemID = 101, guid = "guid-a", count = 5 },
          { itemID = 101, guid = "guid-b", count = 3 },
        }
        refreshBackpack({ wipe = true })
        addon.atInteracting = true
        override(database, "GetStackingOptions", function()
          return { mergeStacks = true, mergeUnstackable = true, unmergeAtShop = true,
            dontMergePartial = false, dontMergeTransmog = false }
        end)
        local slotInfo = refreshBackpack()
        addon.atInteracting = nil
        assert.is_nil(slotInfo.visibleItemsBySlotKey["0_1"].stackedCount)
        assert.is_nil(slotInfo.visibleItemsBySlotKey["0_2"].stackedCount)
        assert.equal(5, slotInfo.visibleItemsBySlotKey["0_1"].itemInfo.currentItemCount)
      end)
    end)
  end)

  it("looks a bag's name up again on the next sweep (bags can be swapped)", function()
    mockContainer[0] = { {} }
    local name = "Bag"
    override(_G.C_Item, "GetItemSubClassInfo", function() return name end)
    refreshBackpack({ wipe = true })
    name = "Herb Bag"
    local slotInfo = refreshBackpack()
    assert.equal("Herb Bag", slotInfo.itemsBySlotKey["0_1"].itemInfo.emptySlotName)
  end)

  -- Phase 6 names each empty slot after its bag. The name is the same for every slot of a
  -- bag and only empty slots use it, so it is looked up once per bag per sweep.
  it("looks up a bag's name once per sweep, not once per slot", function()
    mockContainer[0] = { { itemID = 101, guid = "g1", count = 1 }, {}, {}, {} }
    mockContainer[1] = { {}, {}, { itemID = 102, guid = "g2", count = 1 } }
    local lookups = {}
    local inPhase6 = false
    local phase6 = items.Phase6_EnrichData
    override(items, "Phase6_EnrichData", function(self, ...)
      inPhase6 = true
      local a1, a2, a3, a4, a5 = phase6(self, ...)
      inPhase6 = false
      return a1, a2, a3, a4, a5
    end)
    local toInventory = _G.C_Container.ContainerIDToInventoryID
    override(_G.C_Container, "ContainerIDToInventoryID", function(bagid)
      if inPhase6 then lookups[bagid] = (lookups[bagid] or 0) + 1 end
      return toInventory(bagid)
    end)
    local slotInfo = refreshBackpack({ wipe = true })
    assert.are.same({ [0] = 1, [1] = 1 }, lookups)
    assert.equal("Bag", slotInfo.itemsBySlotKey["0_2"].itemInfo.emptySlotName)
    assert.equal("Bag", slotInfo.itemsBySlotKey["1_1"].itemInfo.emptySlotName)
  end)

  -- Equipped gear is read on backpack sweeps. A slot is read again only when its link or
  -- current item level changed, when PLAYER_EQUIPMENT_CHANGED named it, on a wipe, or when
  -- its last read was cold; otherwise the previous read is kept.
  describe("equipped gear cache", function()
    local equipped, reads, registered

    local function equip(slot, id, ilvl)
      equipped[slot] = { id = id, ilvl = ilvl,
        link = "|cnIQ4:|Hitem:" .. id .. ":0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:::|h[Gear " .. id .. "]|h|r" }
    end

    local function readSlots()
      local slots = {}
      for _, slot in ipairs(reads) do slots[#slots + 1] = slot end
      table.sort(slots)
      reads = {}
      return slots
    end

    before_each(function()
      equipped, reads, registered = {}, {}, {}
      override(_G, "GetInventoryItemLink", function(_, slot)
        local e = equipped[slot]
        return e and e.link or nil
      end)
      override(_G.Item, "CreateFromEquipmentSlot", function(_, slot)
        local loc = _G.ItemLocation:CreateFromEquipmentSlot(slot)
        local mixin = {}
        function mixin:GetItemLocation() return loc end
        function mixin:IsItemEmpty() return equipped[slot] == nil end
        function mixin:GetItemLink() return equipped[slot] and equipped[slot].link end
        function mixin:GetItemID() return equipped[slot] and equipped[slot].id end
        function mixin:GetInventoryType() return 5 end
        return mixin
      end)
      local currentLevel = _G.C_Item.GetCurrentItemLevel
      override(_G.C_Item, "GetCurrentItemLevel", function(location)
        local slot = location.GetEquipmentSlot and location:GetEquipmentSlot()
        if slot then return equipped[slot] and equipped[slot].ilvl end
        return currentLevel(location)
      end)
      local getEquipmentInfo = items.GetEquipmentInfo
      override(items, "GetEquipmentInfo", function(self, mixin)
        table.insert(reads, mixin:GetItemLocation():GetEquipmentSlot())
        return getEquipmentInfo(self, mixin)
      end)
      override(events, "RegisterEvent", function(_, name, cb) registered[name] = cb end)
      override(_G.C_Timer, "After", function() end)
      items:RegisterCacheEvents()
      mockContainer[0] = { { itemID = 101, guid = "g1", count = 1 } }
      equip(1, 501, 100)
      equip(5, 505, 100)
      refreshBackpack({ wipe = true })
      reads = {}
    end)

    it("keeps every slot whose link and item level are unchanged", function()
      refreshBackpack()
      assert.are.same({}, readSlots())
      assert.equal(100, items:GetItemDataFromInventorySlot(5).itemInfo.currentItemLevel)
    end)

    it("re-reads a slot whose item changed", function()
      equip(5, 605, 200)
      refreshBackpack()
      assert.are.same({ 5 }, readSlots())
      assert.equal(200, items:GetItemDataFromInventorySlot(5).itemInfo.currentItemLevel)
    end)

    it("re-reads a slot whose item level changed without its link changing", function()
      equipped[5].ilvl = 150
      refreshBackpack()
      assert.are.same({ 5 }, readSlots())
      assert.equal(150, items:GetItemDataFromInventorySlot(5).itemInfo.currentItemLevel)
    end)

    it("re-reads a slot PLAYER_EQUIPMENT_CHANGED named, even with the same link", function()
      registered["PLAYER_EQUIPMENT_CHANGED"](context:New("evt"), "PLAYER_EQUIPMENT_CHANGED", 1, true)
      refreshBackpack()
      assert.are.same({ 1 }, readSlots())
    end)

    it("drops a slot that was emptied", function()
      equipped[5] = nil
      refreshBackpack()
      assert.is_nil(items:GetItemDataFromInventorySlot(5))
      assert.is_not_nil(items:GetItemDataFromInventorySlot(1))
    end)

    it("re-reads every equipped slot on a wipe", function()
      refreshBackpack({ wipe = true })
      assert.are.same({ 1, 5 }, readSlots())
    end)

    it("re-reads a slot whose last read was cold until it reads warm", function()
      local cold = true
      local getItemInfo = _G.C_Item.GetItemInfo
      override(_G.C_Item, "GetItemInfo", function(id)
        if cold and tostring(id):find("item:705", 1, true) then return nil end
        return getItemInfo(id)
      end)
      equip(5, 705, 300)
      refreshBackpack()
      assert.are.same({ 5 }, readSlots())
      refreshBackpack()
      assert.are.same({ 5 }, readSlots(), "a cold read is not kept")
      cold = false
      refreshBackpack()
      assert.are.same({ 5 }, readSlots())
      refreshBackpack()
      assert.are.same({}, readSlots(), "once read warm, the slot is kept")
    end)

    it("does not read gear on bank sweeps", function()
      local ctx = context:New("bank")
      items:RefreshBank(ctx)
      assert.are.same({}, readSlots())
    end)
  end)

  -- Upgrade verdicts of the cacheable providers (Pawn, the built-in BetterBags) are kept on
  -- each item and reused while the provider and the upgrade generation are unchanged. Every
  -- input of a verdict must invalidate it: these tests pin each one.
  describe("upgrade verdict cache", function()
    local asked, verdicts, registered, timers, sent, provider

    local function askedKeys()
      local keys = {}
      for _, key in ipairs(asked) do keys[#keys + 1] = key end
      table.sort(keys)
      asked = {}
      return keys
    end

    local function useProvider(name, cacheable)
      provider = name
      items:RegisterUpgradeProvider(name, function(data)
        table.insert(asked, data.slotkey)
        return verdicts[data.itemInfo.itemID] or false
      end, { cacheable = cacheable })
    end

    local function fire(name, ...)
      registered[name](context:New("evt"), name, ...)
    end

    local function runTimers()
      local pending = timers
      timers = {}
      for _, t in ipairs(pending) do t.fn() end
    end

    before_each(function()
      asked, verdicts, registered, timers, sent = {}, {}, {}, {}, {}
      override(database, "GetUpgradeIconProvider", function() return provider end)
      override(database, "GetUpgradeIconProviderUserSet", function() return true end)
      override(events, "RegisterEvent", function(_, name, cb) registered[name] = cb end)
      override(_G.C_Timer, "After", function(delay, fn) table.insert(timers, { delay = delay, fn = fn }) end)
      local send = events.SendMessage
      override(events, "SendMessage", function(self, ctx, event, ...)
        table.insert(sent, event)
        return send(self, ctx, event, ...)
      end)
      items:RegisterCacheEvents()
      useProvider("Test", true)
      mockContainer[0] = {
        { itemID = 101, guid = "g1", count = 1 },
        { itemID = 102, guid = "g2", count = 5 },
        {},
      }
      verdicts[101] = true
      refreshBackpack({ wipe = true })
      assert.are.same({ "0_1", "0_2" }, askedKeys())
      sent = {}
    end)

    it("asks again only for the slot that changed", function()
      mockContainer[0][2].count = 4
      local slotInfo = refreshBackpack({ bags = { [0] = true } })
      assert.are.same({ "0_2" }, askedKeys())
      assert.is_true(slotInfo.itemsBySlotKey["0_1"].isUpgrade)
      refreshBackpack()
      assert.are.same({}, askedKeys())
    end)

    it("asks every sweep for a provider that is not cacheable", function()
      useProvider("Uncached", false)
      refreshBackpack()
      refreshBackpack()
      assert.are.same({ "0_1", "0_1", "0_2", "0_2" }, askedKeys())
    end)

    it("asks again when the active provider changes, even without a wipe", function()
      useProvider("Other", true)
      refreshBackpack()
      assert.are.same({ "0_1", "0_2" }, askedKeys())
    end)

    it("never returns one provider's verdict for another, even at the same generation", function()
      items:RegisterUpgradeProvider("Other", function(data)
        table.insert(asked, data.slotkey)
        return false
      end, { cacheable = true })
      provider = "Other"
      local slotInfo = refreshBackpack()
      assert.are.same({ "0_1", "0_2" }, askedKeys())
      assert.is_false(slotInfo.itemsBySlotKey["0_1"].isUpgrade)
    end)

    it("asks again after a wipe sweep", function()
      refreshBackpack({ wipe = true })
      assert.are.same({ "0_1", "0_2" }, askedKeys())
    end)

    local invalidating = {
      { "PLAYER_EQUIPMENT_CHANGED", { 5, true } },
      { "PLAYER_LEVEL_UP", { 70 } },
      { "PLAYER_LEVEL_CHANGED", { 70, 60 } },
      { "PLAYER_AVG_ITEM_LEVEL_UPDATE", {} },
      { "SKILL_LINES_CHANGED", {} },
      { "LEARNED_SPELL_IN_SKILL_LINE", { 12345, 1, false } },
      { "PLAYER_SPECIALIZATION_CHANGED", { "player" } },
    }
    for _, case in ipairs(invalidating) do
      it("asks again after " .. case[1] .. ", and requests a backpack refresh", function()
        fire(case[1], unpack(case[2]))
        runTimers()
        local refreshed = false
        for _, event in ipairs(sent) do
          if event == "bags/RefreshBackpack" then refreshed = true end
          assert.are_not.equal("bags/RefreshBank", event, "the bank is closed")
        end
        assert.is_true(refreshed)
        refreshBackpack()
        assert.are.same({ "0_1", "0_2" }, askedKeys())
      end)
    end

    it("ignores another unit's specialization change", function()
      fire("PLAYER_SPECIALIZATION_CHANGED", "party1")
      runTimers()
      refreshBackpack()
      assert.are.same({}, askedKeys())
    end)

    it("refreshes the bank too when it is open", function()
      addon.atBank = true
      fire("PLAYER_LEVEL_UP", 70)
      runTimers()
      local bank = false
      for _, event in ipairs(sent) do
        if event == "bags/RefreshBank" then bank = true end
      end
      assert.is_true(bank)
    end)

    it("coalesces invalidations in one frame into one refresh request", function()
      fire("PLAYER_EQUIPMENT_CHANGED", 1, true)
      fire("PLAYER_EQUIPMENT_CHANGED", 5, true)
      fire("SKILL_LINES_CHANGED")
      assert.equal(1, #timers)
      runTimers()
      local count = 0
      for _, event in ipairs(sent) do
        if event == "bags/RefreshBackpack" then count = count + 1 end
      end
      assert.equal(1, count)
    end)

    it("asks again when the harvest finds that equipped gear changed, with no event", function()
      local link = "|cnIQ4:|Hitem:505:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:::|h[Gear]|h|r"
      local current = link
      override(_G, "GetInventoryItemLink", function(_, slot)
        if slot == 5 then return current end
        return nil
      end)
      override(_G.Item, "CreateFromEquipmentSlot", function(_, slot)
        local loc = _G.ItemLocation:CreateFromEquipmentSlot(slot)
        local mixin = {}
        function mixin:GetItemLocation() return loc end
        function mixin:IsItemEmpty() return slot ~= 5 end
        function mixin:GetItemLink() return current end
        function mixin:GetItemID() return 505 end
        function mixin:GetInventoryType() return 5 end
        return mixin
      end)
      refreshBackpack()
      askedKeys()
      current = link:gsub("505:0", "505:6")
      refreshBackpack()
      assert.are.same({ "0_1", "0_2" }, askedKeys())
    end)

    -- Built-in usability (C_PlayerInfo.CanUseItem) also changes with reputation and spells
    -- (Blizzard's own usability refresh, Blizzard_Wardrobe.lua, listens for these). They fire
    -- often, so they invalidate only the built-in provider's verdicts and request no refresh:
    -- the next refresh recomputes them.
    for _, name in ipairs({ "UPDATE_FACTION", "SPELLS_CHANGED" }) do
      it("drops kept verdicts without requesting a refresh after " .. name, function()
        fire(name)
        assert.equal(0, #timers, "no refresh is requested")

        local builtin = items.upgradeProviders["BetterBags"]
        local builtinAsked = 0
        items.upgradeProviders["BetterBags"] = function(data)
          builtinAsked = builtinAsked + 1
          return builtin(data)
        end
        provider = "BetterBags"
        refreshBackpack()
        builtinAsked = 0
        refreshBackpack()
        assert.equal(0, builtinAsked, "kept")
        fire(name)
        refreshBackpack()
        assert.equal(2, builtinAsked, "asked again")
      end)
    end

    it("does not lose a bank refresh requested after a backpack-only one was scheduled", function()
      fire("PLAYER_LEVEL_UP", 70)
      assert.equal(1, #timers)
      addon.atBank = true
      items:RequestUpgradeRefresh(false, true)
      assert.equal(1, #timers)
      sent = {}
      runTimers()
      table.sort(sent)
      assert.are.same({ "bags/RefreshBackpack", "bags/RefreshBank" }, sent)
    end)

    it("does not lose a backpack refresh requested after a bank-only one was scheduled", function()
      addon.atBank = true
      items:RequestUpgradeRefresh(false, true)
      items:RequestUpgradeRefresh(true, false)
      assert.equal(1, #timers)
      sent = {}
      runTimers()
      table.sort(sent)
      assert.are.same({ "bags/RefreshBackpack", "bags/RefreshBank" }, sent)
    end)

    it("registers its cache events when the module is enabled", function()
      registered = {}
      items:OnEnable()
      for _, name in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_LEVEL_CHANGED",
        "PLAYER_AVG_ITEM_LEVEL_UPDATE", "SKILL_LINES_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE",
        "PLAYER_SPECIALIZATION_CHANGED", "UPDATE_FACTION", "SPELLS_CHANGED" }) do
        assert.is_function(registered[name], name)
      end
    end)

    -- Equipped gear that was read while the client had no item info for it: verdicts that
    -- compare with it are not kept, the bag is retried, and once the gear reads warm every
    -- verdict is asked again.
    it("drops every kept verdict and refreshes the open bank when equipped gear stops reading cold", function()
      addon.atBank = true
      local cold = true
      local link = "|cnIQ4:|Hitem:505:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:::|h[Gear]|h|r"
      override(_G, "GetInventoryItemLink", function(_, slot)
        if slot == 5 then return link end
        return nil
      end)
      override(_G.Item, "CreateFromEquipmentSlot", function(_, slot)
        local loc = _G.ItemLocation:CreateFromEquipmentSlot(slot)
        local mixin = {}
        function mixin:GetItemLocation() return loc end
        function mixin:IsItemEmpty() return slot ~= 5 end
        function mixin:GetItemLink() return link end
        function mixin:GetItemID() return 505 end
        function mixin:GetInventoryType() return 5 end
        return mixin
      end)
      local getItemInfo = _G.C_Item.GetItemInfo
      override(_G.C_Item, "GetItemInfo", function(id)
        if cold and tostring(id):find("item:505", 1, true) then return nil end
        return getItemInfo(id)
      end)
      -- As in the client: the item level and the instant info do not depend on the item
      -- cache, so the cold and warm reads differ only in being cold.
      local currentLevel = _G.C_Item.GetCurrentItemLevel
      override(_G.C_Item, "GetCurrentItemLevel", function(location)
        if location.GetEquipmentSlot and location:GetEquipmentSlot() == 5 then return 100 end
        return currentLevel(location)
      end)
      local instant = _G.C_Item.GetItemInfoInstant
      override(_G.C_Item, "GetItemInfoInstant", function(item)
        if tostring(item):find("item:505", 1, true) then
          return 505, "Armor", "Plate", "INVTYPE_CHEST", 134400, 4, 4
        end
        return instant(item)
      end)
      refreshBackpack({ wipe = true })
      runTimers()
      local generation = items._upgradeGeneration
      cold = false
      sent = {}
      refreshBackpack()
      assert.is_true(items._upgradeGeneration > generation, "a new generation")
      runTimers()
      local bank = false
      for _, event in ipairs(sent) do
        if event == "bags/RefreshBank" then bank = true end
      end
      assert.is_true(bank, "the open bank is refreshed")
    end)

    -- A sweep that fails partway through reading the gear must not lose the change it read
    -- before failing: nothing is recorded until every slot was read.
    it("does not lose a gear change when reading a later slot fails", function()
      provider = "BetterBags"
      local links = {
        [1] = "|cnIQ4:|Hitem:501:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:::|h[Head]|h|r",
        [5] = "|cnIQ4:|Hitem:505:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:::|h[Chest]|h|r",
      }
      override(_G, "GetInventoryItemLink", function(_, slot) return links[slot] end)
      override(_G.Item, "CreateFromEquipmentSlot", function(_, slot)
        local loc = _G.ItemLocation:CreateFromEquipmentSlot(slot)
        local mixin = {}
        function mixin:GetItemLocation() return loc end
        function mixin:IsItemEmpty() return links[slot] == nil end
        function mixin:GetItemLink() return links[slot] end
        function mixin:GetItemID() return 500 + slot end
        function mixin:GetInventoryType() return slot end
        return mixin
      end)
      refreshBackpack({ wipe = true })
      runTimers()

      -- The head changes; the chest is unchanged but due for a re-read, which fails.
      links[1] = links[1]:gsub("501:0", "501:6")
      fire("PLAYER_EQUIPMENT_CHANGED", 5, true)
      runTimers()
      local generation = items._upgradeGeneration
      local getEquipmentInfo = items.GetEquipmentInfo
      override(items, "GetEquipmentInfo", function(self, mixin)
        if mixin:GetItemLocation():GetEquipmentSlot() == 5 then error("simulated read failure") end
        return getEquipmentInfo(self, mixin)
      end)
      assert.has_error(function() refreshBackpack() end)
      items.GetEquipmentInfo = getEquipmentInfo

      refreshBackpack()
      assert.is_true(items._upgradeGeneration > generation, "the head change is still seen")
    end)

    -- The equip location comes from GetItemInfoInstant (all seven values, never a server
    -- query), so a cold GetItemInfo does not blank it.
    it("reads an equipped item's equip location from GetItemInfoInstant", function()
      local link = "|cnIQ4:|Hitem:505:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:::|h[Gear]|h|r"
      override(_G, "GetInventoryItemLink", function(_, slot)
        if slot == 16 then return link end
        return nil
      end)
      override(_G.Item, "CreateFromEquipmentSlot", function(_, slot)
        local loc = _G.ItemLocation:CreateFromEquipmentSlot(slot)
        local mixin = {}
        function mixin:GetItemLocation() return loc end
        function mixin:IsItemEmpty() return slot ~= 16 end
        function mixin:GetItemLink() return link end
        function mixin:GetItemID() return 505 end
        function mixin:GetInventoryType() return 17 end
        return mixin
      end)
      local instant = _G.C_Item.GetItemInfoInstant
      override(_G.C_Item, "GetItemInfoInstant", function(item)
        if tostring(item):find("item:505", 1, true) then
          return 505, "Weapon", "Two-Handed Swords", "INVTYPE_2HWEAPON", 135000, 2, 8
        end
        return instant(item)
      end)
      override(_G.C_Item, "GetItemInfo", function() return nil end)
      refreshBackpack({ wipe = true })
      assert.equal("INVTYPE_2HWEAPON", items:GetItemDataFromInventorySlot(16).itemInfo.itemEquipLoc)
    end)

    it("keeps no verdict while equipped gear reads cold, and asks again once it reads warm", function()
      local cold = true
      local link = "|cnIQ4:|Hitem:505:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:::|h[Gear]|h|r"
      override(_G, "GetInventoryItemLink", function(_, slot)
        if slot == 5 then return link end
        return nil
      end)
      override(_G.Item, "CreateFromEquipmentSlot", function(_, slot)
        local loc = _G.ItemLocation:CreateFromEquipmentSlot(slot)
        local mixin = {}
        function mixin:GetItemLocation() return loc end
        function mixin:IsItemEmpty() return slot ~= 5 end
        function mixin:GetItemLink() return link end
        function mixin:GetItemID() return 505 end
        function mixin:GetInventoryType() return 5 end
        return mixin
      end)
      local getItemInfo = _G.C_Item.GetItemInfo
      override(_G.C_Item, "GetItemInfo", function(id)
        if cold and tostring(id):find("item:505", 1, true) then return nil end
        return getItemInfo(id)
      end)
      refreshBackpack({ wipe = true })
      askedKeys()
      runTimers()
      refreshBackpack()
      assert.are.same({ "0_1", "0_2" }, askedKeys(), "not kept while the gear is cold")

      cold = false
      runTimers()
      sent = {}
      refreshBackpack()
      askedKeys()
      runTimers()
      local refreshed = false
      for _, event in ipairs(sent) do
        if event == "bags/RefreshBackpack" then refreshed = true end
      end
      assert.is_true(refreshed, "warming gear refreshes the bags")
      refreshBackpack()
      assert.are.same({}, askedKeys(), "kept once the gear is warm")
    end)

    it("asks again when an equipped item's level changes without its link changing", function()
      local link = "|cnIQ4:|Hitem:505:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:::|h[Gear]|h|r"
      local level = 100
      override(_G, "GetInventoryItemLink", function(_, slot)
        if slot == 5 then return link end
        return nil
      end)
      override(_G.Item, "CreateFromEquipmentSlot", function(_, slot)
        local loc = _G.ItemLocation:CreateFromEquipmentSlot(slot)
        local mixin = {}
        function mixin:GetItemLocation() return loc end
        function mixin:IsItemEmpty() return slot ~= 5 end
        function mixin:GetItemLink() return link end
        function mixin:GetItemID() return 505 end
        function mixin:GetInventoryType() return 5 end
        return mixin
      end)
      local currentLevel = _G.C_Item.GetCurrentItemLevel
      override(_G.C_Item, "GetCurrentItemLevel", function(location)
        if location.GetEquipmentSlot and location:GetEquipmentSlot() == 5 then return level end
        return currentLevel(location)
      end)
      refreshBackpack()
      askedKeys()
      level = 40
      refreshBackpack()
      assert.are.same({ "0_1", "0_2" }, askedKeys())
    end)

    -- A backpack sweep that fails after its harvest must not leave the bank judged against
    -- the gear before the change: the gear read is published with the harvest.
    it("judges the bank against the newly read gear even when the backpack sweep failed", function()
      provider = "BetterBags"
      override(const, "INVENTORY_TYPE_TO_INVENTORY_SLOTS", { [1] = { 5 } })
      local gear = { link = "|cnIQ4:|Hitem:505:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:::|h[Gear]|h|r", ilvl = 100 }
      override(_G, "GetInventoryItemLink", function(_, slot)
        if slot == 5 then return gear.link end
        return nil
      end)
      override(_G.Item, "CreateFromEquipmentSlot", function(_, slot)
        local loc = _G.ItemLocation:CreateFromEquipmentSlot(slot)
        local mixin = {}
        function mixin:GetItemLocation() return loc end
        function mixin:IsItemEmpty() return slot ~= 5 end
        function mixin:GetItemLink() return gear.link end
        function mixin:GetItemID() return 505 end
        function mixin:GetInventoryType() return 5 end
        return mixin
      end)
      override(_G.C_Item, "GetCurrentItemLevel", function(location)
        if location.GetEquipmentSlot and location:GetEquipmentSlot() == 5 then return gear.ilvl end
        return 200
      end)
      mockContainer[6] = { { itemID = 301, guid = "bank1", count = 1 } }
      refreshBackpack({ wipe = true })
      local bankCtx = context:New("bank")
      items:RefreshBank(bankCtx)
      assert.is_true(items.slotInfo[const.BAG_KIND.BANK].itemsBySlotKey["6_1"].isUpgrade)

      gear.link = gear.link:gsub("505:0", "505:6")
      gear.ilvl = 300
      local phase6 = items.Phase6_EnrichData
      override(items, "Phase6_EnrichData", function() error("simulated sweep failure") end)
      assert.has_error(function() refreshBackpack() end)
      items.Phase6_EnrichData = phase6

      items:RefreshBank(context:New("bank2"))
      assert.is_false(items.slotInfo[const.BAG_KIND.BANK].itemsBySlotKey["6_1"].isUpgrade)
    end)

    it("does not keep a verdict for an item read while the client had no item info", function()
      local getItemInfo = _G.C_Item.GetItemInfo
      override(_G.C_Item, "GetItemInfo", function(id)
        if tostring(id) == "103" then return nil end
        return getItemInfo(id)
      end)
      mockContainer[0][3] = { itemID = 103, guid = "g3", count = 1 }
      local slotInfo = refreshBackpack({ bags = { [0] = true } })
      assert.is_nil(slotInfo.itemsBySlotKey["0_3"].upgradeGeneration)
    end)

    -- The built-in provider compares a bag item with the gear equipped in its slot. It must
    -- compare with the gear read in the same sweep, or a verdict computed against the
    -- previous gear would be kept.
    it("judges the built-in provider against the gear read in the same sweep", function()
      provider = "BetterBags"
      override(const, "INVENTORY_TYPE_TO_INVENTORY_SLOTS", { [1] = { 5 } })
      local gear = { link = "|cnIQ4:|Hitem:505:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:::|h[Gear]|h|r", ilvl = 100 }
      override(_G, "GetInventoryItemLink", function(_, slot)
        if slot == 5 then return gear.link end
        return nil
      end)
      override(_G.Item, "CreateFromEquipmentSlot", function(_, slot)
        local loc = _G.ItemLocation:CreateFromEquipmentSlot(slot)
        local mixin = {}
        function mixin:GetItemLocation() return loc end
        function mixin:IsItemEmpty() return slot ~= 5 end
        function mixin:GetItemLink() return gear.link end
        function mixin:GetItemID() return 505 end
        function mixin:GetInventoryType() return 5 end
        return mixin
      end)
      override(_G.C_Item, "GetCurrentItemLevel", function(location)
        if location.GetEquipmentSlot and location:GetEquipmentSlot() == 5 then return gear.ilvl end
        return 200
      end)
      local slotInfo = refreshBackpack({ wipe = true })
      assert.is_true(slotInfo.itemsBySlotKey["0_1"].isUpgrade, "200 beats the equipped 100")

      gear.link = gear.link:gsub("505:0", "505:6")
      gear.ilvl = 300
      slotInfo = refreshBackpack()
      assert.is_false(slotInfo.itemsBySlotKey["0_1"].isUpgrade, "the same sweep sees the new 300")
    end)
  end)

  -- Item buttons skip a redraw whose inputs are unchanged (frames/item.lua). Settings that
  -- change how a button looks without changing its data (glow intensity, item level
  -- display, theme) all send bags/FullRefreshAll, a wipe sweep; the draw generation every
  -- item carries changes on exactly those sweeps, so their buttons redraw in full.
  describe("draw generation", function()
    it("stamps every item, including those a targeted sweep carried over", function()
      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 } }
      mockContainer[1] = { { itemID = 102, guid = "guid-102", count = 1 } }
      local slotInfo = refreshBackpack({ wipe = true })
      local generation = slotInfo.itemsBySlotKey["0_1"].drawGeneration
      assert.is_not_nil(generation)
      assert.equal(generation, slotInfo.itemsBySlotKey["1_1"].drawGeneration)

      mockContainer[0][1].count = 2
      slotInfo = refreshBackpack({ bags = { [0] = true } })
      assert.equal(generation, slotInfo.itemsBySlotKey["0_1"].drawGeneration, "a targeted sweep keeps the generation")
      assert.equal(generation, slotInfo.itemsBySlotKey["1_1"].drawGeneration)
    end)

    it("changes on a wipe sweep only", function()
      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 } }
      local first = refreshBackpack({ wipe = true }).itemsBySlotKey["0_1"].drawGeneration
      local plain = refreshBackpack().itemsBySlotKey["0_1"].drawGeneration
      assert.equal(first, plain)
      local wiped = refreshBackpack({ wipe = true }).itemsBySlotKey["0_1"].drawGeneration
      assert.are_not.equal(first, wiped)
    end)

    it("is counted per bag kind, so a bank wipe does not redraw the backpack", function()
      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 } }
      local before = refreshBackpack({ wipe = true }).itemsBySlotKey["0_1"].drawGeneration
      local ctx = context:New("bank-wipe")
      ctx:Set("wipe", true)
      items:RefreshBank(ctx)
      local after = refreshBackpack().itemsBySlotKey["0_1"].drawGeneration
      assert.equal(before, after)
    end)
  end)

  -- Two 12.1 Catalyst pieces: identical itemID, item level and bonus IDs, differing
  -- only in the secondary stats reported by GetItemStats. Without a stat component in
  -- the item hash they collide and one is hidden behind a virtual stack.
  -- Modern (|cnIQ4:) colour-prefixed links that ParseItemLink handles cleanly. Both
  -- carry identical bonus IDs (6652,13440); they differ only in the value of modifier
  -- type 64 (251124 vs 193758) — the field the real Catalyst uses and the one the item
  -- hash does not hash. GetItemStats is mocked per exact link string below.
  local FIST_HASTE = "|cnIQ4:|Hitem:271520:0:0:0:0:0:0:0:0:0:0:0:2:6652:13440:1:64:251124:0:0:0:::|h[Monkey King's Fighting Fists]|h|r"
  local FIST_VERS  = "|cnIQ4:|Hitem:271520:0:0:0:0:0:0:0:0:0:0:0:2:6652:13440:1:64:193758:0:0:0:::|h[Monkey King's Fighting Fists]|h|r"

  it("does not virtually stack two catalyst items that differ only in secondary stats", function()
    override(database, "GetStackingOptions", function()
      return { mergeStacks = true, mergeUnstackable = true, unmergeAtShop = false,
        dontMergePartial = false, dontMergeTransmog = false }
    end)
    mockContainer[0] = {
      { itemID = 271520, guid = "guid-fist-1", count = 1, link = FIST_HASTE },
      { itemID = 271520, guid = "guid-fist-2", count = 1, link = FIST_VERS },
    }
    mockStats[FIST_HASTE] = {
      ITEM_MOD_CRIT_RATING_SHORT = 93, ITEM_MOD_HASTE_RATING_SHORT = 50,
      ITEM_MOD_STAMINA_SHORT = 2527, RESISTANCE0_NAME = 101, ITEM_MOD_AGILITY_SHORT = 125,
    }
    mockStats[FIST_VERS] = {
      ITEM_MOD_CRIT_RATING_SHORT = 84, ITEM_MOD_VERSATILITY = 59,
      ITEM_MOD_STAMINA_SHORT = 2527, RESISTANCE0_NAME = 101, ITEM_MOD_AGILITY_SHORT = 125,
    }

    local slotInfo = refreshBackpack()

    -- Both physical slots survive as their own visible (root) items rather than
    -- one being merged away.
    assert.is_not_nil(slotInfo.visibleItemsBySlotKey["0_1"], "first fist must remain visible")
    assert.is_not_nil(slotInfo.visibleItemsBySlotKey["0_2"], "second fist must remain visible")
    assert.are_not.equal(
      slotInfo.itemsBySlotKey["0_1"].itemHash,
      slotInfo.itemsBySlotKey["0_2"].itemHash,
      "differing secondary stats must yield different item hashes"
    )
  end)

  describe("Show Bags (SECTION_ALL_BAGS) view", function()
    local function twoIdenticalItems()
      return {
        ["0_1"] = { slotkey = "0_1", isItemEmpty = false, itemHash = "H",
          itemInfo = { currentItemCount = 1, itemStackCount = 1 } },
        ["0_2"] = { slotkey = "0_2", isItemEmpty = false, itemHash = "H",
          itemInfo = { currentItemCount = 1, itemStackCount = 1 } },
      }
    end

    it("never virtually stacks items, so every physical slot stays visible", function()
      override(database, "GetStackingOptions", function()
        return { mergeStacks = true, mergeUnstackable = true, unmergeAtShop = false,
          dontMergePartial = false, dontMergeTransmog = false }
      end)
      override(database, "GetBagView", function() return const.BAG_VIEW.SECTION_ALL_BAGS end)

      local visible = items:Phase7_ApplyVirtualStacks(const.BAG_KIND.BACKPACK, twoIdenticalItems())
      assert.is_not_nil(visible["0_1"], "Show Bags must render every physical slot")
      assert.is_not_nil(visible["0_2"], "Show Bags must render every physical slot")
    end)

    it("still merges identical items in the grid view", function()
      override(database, "GetStackingOptions", function()
        return { mergeStacks = true, mergeUnstackable = true, unmergeAtShop = false,
          dontMergePartial = false, dontMergeTransmog = false }
      end)
      override(database, "GetBagView", function() return const.BAG_VIEW.SECTION_GRID end)

      local visible = items:Phase7_ApplyVirtualStacks(const.BAG_KIND.BACKPACK, twoIdenticalItems())
      local count = 0
      for _ in pairs(visible) do count = count + 1 end
      assert.are.equal(1, count, "grid view merges identical items into a single visible root")
    end)
  end)

  describe("bank/warbank virtual stacking isolation", function()
    local function refreshBank()
      local ctx = context:New("refresh")
      items:RefreshBank(ctx)
      return items.slotInfo[const.BAG_KIND.BANK]
    end

    -- The retail bank data sweep loads the Character Bank (BANK_BAGS) and the Warbank
    -- (ACCOUNT_BANK_BAGS) into one unified cache, then partitions into tabs downstream.
    -- Virtual stacking runs before that partition, so two identical items -- one in each
    -- bank type -- must NOT merge into a single visible root, or one physical pile is
    -- hidden and the item appears to jump between bank types / tabs.
    it("does not merge an identical item across the Character Bank and the Warbank", function()
      override(database, "GetStackingOptions", function()
        return { mergeStacks = true, mergeUnstackable = true, unmergeAtShop = false,
          dontMergePartial = false, dontMergeTransmog = false }
      end)
      -- Same itemID (and thus same generated link/stats) in a Character Bank bag (6) and
      -- an Account Bank / Warbank bag (13).
      mockContainer[6] = { { itemID = 101, guid = "guid-char", count = 5 } }
      mockContainer[13] = { { itemID = 101, guid = "guid-warbank", count = 5 } }

      local slotInfo = refreshBank()

      assert.is_not_nil(slotInfo.visibleItemsBySlotKey["6_1"], "character-bank copy must stay visible")
      assert.is_not_nil(slotInfo.visibleItemsBySlotKey["13_1"], "warbank copy must stay visible")
      assert.are_not.equal(
        slotInfo.itemsBySlotKey["6_1"].itemHash,
        slotInfo.itemsBySlotKey["13_1"].itemHash,
        "character-bank and warbank copies must hash differently so they never stack"
      )
    end)

    it("still merges two identical items within the same Character Bank", function()
      override(database, "GetStackingOptions", function()
        return { mergeStacks = true, mergeUnstackable = true, unmergeAtShop = false,
          dontMergePartial = false, dontMergeTransmog = false }
      end)
      mockContainer[6] = { { itemID = 101, guid = "guid-a", count = 5 } }
      mockContainer[7] = { { itemID = 101, guid = "guid-b", count = 5 } }

      local slotInfo = refreshBank()

      local visibleInBankBags = 0
      for slotkey in pairs(slotInfo.visibleItemsBySlotKey) do
        if slotkey == "6_1" or slotkey == "7_1" then visibleInBankBags = visibleInBankBags + 1 end
      end
      assert.are.equal(1, visibleInBankBags, "identical items in the same bank type still merge")
    end)
  end)

  it("resolves search categories against custom categories by priority after re-indexing", function()
    override(categories, "GetCustomCategory", function(_, _, _, data)
      if data.itemInfo.itemID == 101 then
        return "Custom", 1
      end
      return nil, nil
    end)
    local function searchCategoryWithPriority(priority)
      return function()
        return {
          {
            name = "Searchy",
            enabled = { [const.BAG_KIND.BACKPACK] = true, [const.BAG_KIND.BANK] = true },
            searchCategory = { query = "alpha", groupBy = const.SEARCH_CATEGORY_GROUP_BY.NONE },
            priority = priority,
          },
        }
      end
    end
    mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 } }

    -- Lower priority number wins: the custom category (1) beats the search category (10).
    override(categories, "GetSortedSearchCategories", searchCategoryWithPriority(10))
    local slotInfo = refreshBackpack()
    assert.equal("Searchy", items:GetSearchCategory(const.BAG_KIND.BACKPACK, "0_1"), "search category must match the item")
    assert.equal("Custom", slotInfo.itemsBySlotKey["0_1"].itemInfo.category)

    -- ... and the search category wins once it carries the higher priority.
    override(categories, "GetSortedSearchCategories", searchCategoryWithPriority(1))
    slotInfo = refreshBackpack()
    assert.equal("Searchy", slotInfo.itemsBySlotKey["0_1"].itemInfo.category)
  end)

  it("evaluates the active search box text against the freshly indexed items", function()
    mockContainer[0] = {
      { itemID = 101, guid = "guid-101", count = 1 },
      { itemID = 202, guid = "guid-202", count = 1 },
    }
    searchText = "alpha"

    local slotInfo = refreshBackpack()
    assert.is_true(slotInfo.itemsBySlotKey["0_1"].isSearchResult, "Alpha Sword must match the live search on the very refresh it was indexed")
    assert.is_false(slotInfo.itemsBySlotKey["0_2"].isSearchResult)

    -- A newly looted item must match on the refresh that first indexes it.
    mockContainer[0][3] = { itemID = 303, guid = "guid-303", count = 1 }
    searchText = "gamma"
    slotInfo = refreshBackpack({ bags = { [0] = true } })
    assert.is_true(slotInfo.itemsBySlotKey["0_3"].isSearchResult)
    assert.is_false(slotInfo.itemsBySlotKey["0_1"].isSearchResult)

    -- Clearing the search text resets the flag so buttons draw at full alpha.
    searchText = ""
    slotInfo = refreshBackpack({ bags = { [0] = true } })
    assert.is_nil(slotInfo.itemsBySlotKey["0_3"].isSearchResult)
  end)

  it("keeps both bags searchable in the shared global index after a full refresh (bank indexed first, backpack last)", function()
    -- A full refresh (data/refresh.lua RequestUpdate) always processes the bank first
    -- and the backpack second. The search index is a single global structure shared by
    -- both bags, so indexing only the last-processed kind evicts the other bag from the
    -- index. That is exactly what broke the live bank search: the backpack overwrote the
    -- bank's entries, so typing anything in the bank filtered out every bank item.
    mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 } } -- Alpha Sword (backpack)
    mockContainer[6] = { { itemID = 202, guid = "guid-202", count = 1 } } -- Beta Shield (bank)

    local bankCtx = context:New("refresh-bank")
    items:RefreshBank(bankCtx)
    refreshBackpack()

    -- These are the exact calls frames/search.lua makes when the user types into the
    -- backpack or bank search box against the shared global index.
    local backpackResults = search:Search("alpha")
    assert.is_true(backpackResults["0_1"], "backpack item must match the live search box")

    local bankResults = search:Search("beta")
    assert.is_true(bankResults["6_1"], "bank item must remain searchable after the backpack is indexed last")
  end)

  -- The index is updated incrementally (search:SyncKind). It must always equal a clean
  -- rebuild over both bags' committed items (docs/roadmap.md, "Incremental search indexing").
  describe("incremental search index", function()
    local function sets(t)
      local out = {}
      for value, slots in pairs(t) do
        local keys = {}
        for k in pairs(slots) do keys[#keys + 1] = k end
        table.sort(keys)
        out[tostring(value)] = table.concat(keys, ",")
      end
      return out
    end
    local function numbers(node, out)
      if node then
        numbers(node.left, out)
        local keys = {}
        for k in pairs(node.data) do keys[#keys + 1] = k end
        table.sort(keys)
        out[tostring(node.value)] = table.concat(keys, ",")
        numbers(node.right, out)
      end
      return out
    end
    local function indexState()
      local out = {}
      for name, index in pairs(search.indicies) do
        out[name] = { sets(index.ngrams), sets(index.fullText), sets(index.bools), numbers(index.numbers.root, {}) }
      end
      return out
    end
    local function cleanState()
      local saved = { search.indicies, search.indexLookup, search.indexed }
      search:Init()
      local all = {}
      for _, kind in ipairs({ const.BAG_KIND.BACKPACK, const.BAG_KIND.BANK }) do
        for slotkey, it in pairs(items.slotInfo[kind].itemsBySlotKey or {}) do all[slotkey] = it end
      end
      search:IndexItems(all)
      local state = indexState()
      search.indicies, search.indexLookup, search.indexed = saved[1], saved[2], saved[3]
      return state
    end
    local function refreshBank(wipe)
      local ctx = context:New("refresh-bank")
      if wipe then ctx:Set("wipe", true) end
      items:RefreshBank(ctx)
    end

    it("re-indexes only the slot that changed on a targeted sweep", function()
      mockContainer[0] = {
        { itemID = 101, guid = "guid-101", count = 1 },
        { itemID = 202, guid = "guid-202", count = 5 },
      }
      mockContainer[6] = { { itemID = 303, guid = "guid-303", count = 1 } }
      refreshBank()
      refreshBackpack({ wipe = true })

      local added = {}
      local add = search.Add
      override(search, "Add", function(self, it)
        table.insert(added, it.slotkey)
        return add(self, it)
      end)
      mockContainer[0][2].count = 4
      refreshBackpack({ bags = { [0] = true } })
      assert.are.same({ "0_2" }, added)
      assert.is_true(search:isInIndex("count", 4)["0_2"])
      assert.is_nil(search:isInIndex("count", 5)["0_2"])
    end)

    it("equals a clean rebuild over both bags after targeted, plain and wipe sweeps", function()
      mockContainer[0] = {
        { itemID = 101, guid = "guid-101", count = 1 },
        { itemID = 202, guid = "guid-202", count = 5 },
        {},
      }
      mockContainer[1] = { { itemID = 303, guid = "guid-303", count = 2 } }
      mockContainer[6] = { { itemID = 201, guid = "guid-201", count = 1 }, {} }
      refreshBank(true)
      refreshBackpack({ wipe = true })
      assert.are.same(cleanState(), indexState(), "after wipe sweeps")

      -- Use one potion, loot an item, move one, sell one.
      mockContainer[0][2].count = 4
      mockContainer[0][3] = { itemID = 303, guid = "guid-new", count = 1 }
      refreshBackpack({ bags = { [0] = true } })
      assert.are.same(cleanState(), indexState(), "after a targeted sweep")

      mockContainer[1][1], mockContainer[0][1] = mockContainer[0][1], {}
      refreshBackpack()
      assert.are.same(cleanState(), indexState(), "after a move")

      mockContainer[6][2] = { itemID = 202, guid = "guid-bank2", count = 3 }
      refreshBank()
      assert.are.same(cleanState(), indexState(), "after a bank sweep")

      mockContainer[1] = { {} }
      refreshBackpack({ bags = { [1] = true } })
      assert.are.same(cleanState(), indexState(), "after a sale")
      assert.is_nil(search.indexed["1_1"])
      assert.is_not_nil(search.indexed["6_2"], "the bank stays indexed")
    end)
  end)

  describe("All Items Recent (container auto-loot, same-frame remove + add)", function()
    -- The "All Items Recent" option (database:GetMarkRecentItems) marks every BetterBags-detected
    -- ADDED item as recent, independent of the client's C_NewItems flag. This matters because WoW
    -- does NOT flag items that pop out of an opened container (e.g. a loot bag) as new via
    -- C_NewItems -- so C_NewItems.IsNewItem stays false for them (newSlots left empty below).
    -- Opening the container removes it from its slot and auto-loots its contents in the SAME
    -- BAG_UPDATE sweep; those added items must still land in "Recent Items".

    local function enableAllItemsRecent()
      override(database, "GetMarkRecentItems", function(_, kind) return kind == const.BAG_KIND.BACKPACK end)
      override(database, "GetCategoryFilter", function(_, _, filter) return filter == "RecentItems" end)
      override(items, "IsBagOpen", function() return true end)
    end

    it("marks items auto-looted from an opened container as Recent Items in the sweep the container is removed", function()
      enableAllItemsRecent()

      -- Baseline: a loot-bag container sits in slot 0_1, with two empty slots after it.
      mockContainer[0] = {
        { itemID = 303, guid = "guid-bag", count = 1 }, -- the container item
        {},
        {},
      }
      local baseline = refreshBackpack()
      assert.equal(303, baseline.itemsBySlotKey["0_1"].itemInfo.itemID)

      -- Open it: the container is consumed (removed) and its three items are auto-looted into
      -- slot 0_1 (its own freed slot -> hash change) plus the two freed slots 0_2 and 0_3, all in
      -- the SAME targeted sweep. The client does not flag any of them as new (newSlots stays empty).
      mockContainer[0] = {
        { itemID = 101, guid = "guid-101", count = 1 },
        { itemID = 201, guid = "guid-201", count = 1 },
        { itemID = 202, guid = "guid-202", count = 1 },
      }
      local after = refreshBackpack({ bags = { [0] = true } })

      assert.equal("Recent Items", after.itemsBySlotKey["0_1"].itemInfo.category,
        "item that replaced the container in its own slot must be Recent")
      assert.equal("Recent Items", after.itemsBySlotKey["0_2"].itemInfo.category,
        "item auto-looted into a freed slot must be Recent")
      assert.equal("Recent Items", after.itemsBySlotKey["0_3"].itemInfo.category,
        "item auto-looted into a freed slot must be Recent")
    end)

    it("does not mark a purely moved item as Recent via All Items Recent", function()
      enableAllItemsRecent()

      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 }, {} }
      refreshBackpack()

      -- Drag the item from slot 1 to slot 2: same GUID, no C_NewItems flag. A move is not an
      -- acquisition, so it must not be (re-)marked recent.
      mockContainer[0] = { {}, { itemID = 101, guid = "guid-101", count = 1 } }
      local after = refreshBackpack({ bags = { [0] = true } })

      assert.are_not.equal("Recent Items", after.itemsBySlotKey["0_2"].itemInfo.category,
        "a pure move must not be marked recent by All Items Recent")
    end)
  end)

  describe("persistent item gaps", function()
    local function gapCount(sortedItems)
      local n = 0
      for _, e in ipairs(sortedItems or {}) do
        if e.isItemGap then n = n + 1 end
      end
      return n
    end

    local function enableGaps()
      override(database, "GetPreserveItemGaps", function() return true end)
      override(items, "IsBagOpen", function() return true end)
      override(addon:GetModule("Sort"), "GetItemDataSortFunction", function()
        return function(a, b)
          if a.isItemGap or a.isFreeSlot then return false end
          if b.isItemGap or b.isFreeSlot then return true end
          return tostring(a.slotkey) < tostring(b.slotkey)
        end
      end)
    end

    local function refreshBackpackReset()
      local ctx = context:New("refresh")
      ctx:Set("resetLayout", true)
      items:RefreshBackpack(ctx)
      return items.slotInfo[const.BAG_KIND.BACKPACK]
    end

    local function refreshBank()
      local ctx = context:New("refresh")
      items:RefreshBank(ctx)
      return items.slotInfo[const.BAG_KIND.BANK]
    end

    it("holds a gap in place when an item is consumed while the bag is open", function()
      enableGaps()
      mockContainer[0] = {
        { itemID = 101, guid = "g101", count = 1 },
        { itemID = 201, guid = "g201", count = 1 },
        { itemID = 202, guid = "g202", count = 1 },
      }
      local baseline = refreshBackpack()
      assert.equal(3, baseline.totalItems)
      assert.equal(0, gapCount(baseline.sortedItems))

      -- Consume the middle item (slot 2 -> "0_2").
      mockContainer[0][2] = {}
      local after = refreshBackpack()

      assert.equal(2, after.totalItems)
      assert.equal(1, gapCount(after.sortedItems))
      assert.equal("0_1", after.sortedItems[1].slotkey)
      assert.is_true(after.sortedItems[2].isItemGap == true)
      assert.equal("gap:0_2", after.sortedItems[2].slotkey)
      assert.equal("0_3", after.sortedItems[3].slotkey)
    end)

    it("appends a newly looted item after the held gap", function()
      enableGaps()
      mockContainer[0] = {
        { itemID = 101, guid = "g101", count = 1 },
        { itemID = 201, guid = "g201", count = 1 },
        { itemID = 202, guid = "g202", count = 1 },
      }
      refreshBackpack()
      mockContainer[0][2] = {}
      refreshBackpack()
      -- Loot a new item into slot 4.
      mockContainer[0][4] = { itemID = 303, guid = "g303", count = 1 }
      local after = refreshBackpack()

      assert.equal(3, after.totalItems)
      assert.equal(1, gapCount(after.sortedItems))
      assert.equal(4, #after.sortedItems)
      assert.equal("0_1", after.sortedItems[1].slotkey)
      assert.is_true(after.sortedItems[2].isItemGap == true)
      assert.equal("0_3", after.sortedItems[3].slotkey)
      assert.equal("0_4", after.sortedItems[4].slotkey)
    end)

    it("collapses gaps on a reset (sort) refresh", function()
      enableGaps()
      mockContainer[0] = {
        { itemID = 101, guid = "g101", count = 1 },
        { itemID = 201, guid = "g201", count = 1 },
      }
      refreshBackpack()
      mockContainer[0][1] = {}
      local gapped = refreshBackpack()
      assert.equal(1, gapCount(gapped.sortedItems))

      local collapsed = refreshBackpackReset()
      assert.equal(0, gapCount(collapsed.sortedItems))
      assert.equal(1, collapsed.totalItems)
    end)

    it("produces no gaps when the bag is closed", function()
      enableGaps()
      override(items, "IsBagOpen", function() return false end)
      mockContainer[0] = {
        { itemID = 101, guid = "g101", count = 1 },
        { itemID = 201, guid = "g201", count = 1 },
      }
      refreshBackpack()
      mockContainer[0][1] = {}
      local after = refreshBackpack()
      assert.equal(0, gapCount(after.sortedItems))
    end)

    it("does not gap on a partial stack consume (virtual stacks)", function()
      enableGaps()
      override(database, "GetStackingOptions", function()
        return { mergeStacks = true, mergeUnstackable = true, unmergeAtShop = false,
          dontMergePartial = false, dontMergeTransmog = false }
      end)
      -- Two slots of the same item merge into a single displayed stack.
      mockContainer[0] = {
        { itemID = 101, guid = "g101a", count = 10 },
        { itemID = 101, guid = "g101b", count = 10 },
      }
      local baseline = refreshBackpack()
      assert.equal(1, #baseline.sortedItems) -- one displayed icon
      assert.equal(0, gapCount(baseline.sortedItems))

      -- Consume one slot entirely; the merged icon remains -> no gap.
      mockContainer[0][1] = {}
      local after = refreshBackpack()
      assert.equal(0, gapCount(after.sortedItems))
      assert.equal(1, #after.sortedItems)
    end)

    it("gaps when an entire displayed stack is consumed (virtual stacks)", function()
      enableGaps()
      override(database, "GetStackingOptions", function()
        return { mergeStacks = true, mergeUnstackable = true, unmergeAtShop = false,
          dontMergePartial = false, dontMergeTransmog = false }
      end)
      mockContainer[0] = {
        { itemID = 101, guid = "g101a", count = 10 },
        { itemID = 101, guid = "g101b", count = 10 },
      }
      refreshBackpack()
      -- Consume both slots -> the whole displayed stack disappears -> one gap.
      mockContainer[0][1] = {}
      mockContainer[0][2] = {}
      local after = refreshBackpack()
      assert.equal(1, gapCount(after.sortedItems))
      assert.equal(0, after.totalItems)
    end)

    it("scopes gaps per bag kind (bank gap does not touch the backpack)", function()
      enableGaps()
      override(addon, "atBank", true)
      mockContainer[0] = {
        { itemID = 101, guid = "gbp1", count = 1 },
      }
      mockContainer[6] = {
        { itemID = 201, guid = "gbank1", count = 1 },
        { itemID = 202, guid = "gbank2", count = 1 },
      }
      local bp = refreshBackpack()
      local bank = refreshBank()
      assert.equal(0, gapCount(bp.sortedItems))
      assert.equal(0, gapCount(bank.sortedItems))

      -- Consume a bank item; refresh only the bank.
      mockContainer[6][1] = {}
      local bankAfter = refreshBank()
      assert.equal(1, gapCount(bankAfter.sortedItems))

      -- The backpack's committed layout is a different kind and is untouched.
      assert.equal(0, gapCount(items.slotInfo[const.BAG_KIND.BACKPACK].sortedItems))
    end)
  end)

  describe("refresh scheduler (serialized queue)", function()
    -- data/refresh.lua serializes every refresh request through a single frame-stepped
    -- queue: RequestUpdate only enqueues, and a pump runs exactly one unit at a time,
    -- with a deliberate idle frame between units, so no two data sweeps are ever in
    -- flight and no request-time side effect (ClearItemCache/ClearNewItems/Sort) can
    -- mutate state a parked sweep still depends on. installClock() swaps in the real
    -- coroutine yield and a captured, hand-cranked frame clock so the cadence is
    -- deterministic; advance() runs exactly the tick(s) pending for one frame.
    local function installClock()
      async.Yield = function() coroutine.yield() end
      local frames = {}
      saveGlobal(_G.C_Timer, "After")
      _G.C_Timer.After = function(_, fn) table.insert(frames, fn) end
      return function()
        local pending = frames
        frames = {}
        for _, fn in ipairs(pending) do fn() end
        return #pending
      end
    end

    it("processes queued refreshes one at a time with an idle frame between units", function()
      local advance = installClock()
      local origRun = items.RunRefresh
      local starts, ends = {}, {}
      override(items, "RunRefresh", function(self, ectx, kind)
        table.insert(starts, kind)
        origRun(self, ectx, kind)
        table.insert(ends, kind)
      end)

      mockContainer[0] = { { itemID = 101, guid = "g1", count = 1 } }

      -- Frame 1 (synchronous, scheduler idle): U1 harvests and parks at its yield.
      refresh:RequestUpdate({ backpack = true })
      assert.same({ const.BAG_KIND.BACKPACK }, starts)
      assert.same({}, ends, "the first unit is parked at its yield, not yet committed")

      -- A second request only enqueues; it must NOT start while U1 is in flight.
      refresh:RequestUpdate({ backpack = true })
      assert.equal(1, #starts, "the second unit must not start while the first is in flight")

      advance() -- U1 resumes -> commits -> unit done
      assert.same({ const.BAG_KIND.BACKPACK }, ends)
      assert.equal(1, #starts, "no new unit starts on the commit frame")

      advance() -- idle hand-off frame: nothing runs
      assert.equal(1, #starts, "an idle frame must separate the two units")
      assert.equal(1, #ends)

      advance() -- U2 starts, parks
      assert.equal(2, #starts)
      assert.equal(1, #ends)

      advance() -- U2 commits
      assert.equal(2, #ends)
    end)

    it("defers a queued unit's side effects until it runs (no sync mutation of an in-flight sweep)", function()
      local advance = installClock()
      local clears = 0
      local origClear = items.ClearItemCache
      override(items, "ClearItemCache", function(self, ctx)
        clears = clears + 1
        return origClear(self, ctx)
      end)

      mockContainer[0] = { { itemID = 101, guid = "g1", count = 1 } }

      refresh:RequestUpdate({ backpack = true })                    -- U1 parked
      refresh:RequestUpdate({ wipe = true, backpack = true, bank = true }) -- U2 enqueued
      assert.equal(0, clears, "a wipe must not clear the cache while a prior sweep is parked")

      for _ = 1, 12 do advance() end
      assert.equal(1, clears, "the wipe clears the cache exactly once, when its own unit runs")
    end)

    it("runs the first queued unit's harvest synchronously when the scheduler is idle", function()
      installClock()
      local origRun = items.RunRefresh
      local started = false
      override(items, "RunRefresh", function(self, ectx, kind)
        started = true
        origRun(self, ectx, kind)
      end)

      mockContainer[0] = { { itemID = 101, guid = "g1", count = 1 } }
      refresh:RequestUpdate({ backpack = true })
      assert.is_true(started, "an idle scheduler executes the first step within the enqueue call")
    end)

    it("does not flood Recent Items when a bank-open burst enqueues a switch refresh and a full wipe", function()
      -- The reported bug: bags opened, closed, then bank opened dumped the whole backpack
      -- into Recent Items. Opening the bank enqueues a non-wipe backpack refresh (bank tab
      -- switch) and, in the same frame, a bags/FullRefreshAll wipe. Under the old direct
      -- model the wipe's ClearItemCache ran synchronously and emptied the parked switch
      -- refresh's previousItems, so MarkAddedItemsRecent marked every item acquired. The
      -- serialized queue runs the switch refresh to completion before the wipe touches the
      -- cache, so nothing is falsely marked recent.
      override(database, "GetMarkRecentItems", function(_, kind) return kind == const.BAG_KIND.BACKPACK end)
      override(database, "GetCategoryFilter", function(_, _, filter) return filter == "RecentItems" end)
      override(items, "IsBagOpen", function() return true end)

      mockContainer[0] = {
        { itemID = 101, guid = "guid-101", count = 1 },
        { itemID = 201, guid = "guid-201", count = 1 },
        { itemID = 202, guid = "guid-202", count = 1 },
      }
      -- Baseline (bags already open) committed synchronously before the clock is installed.
      refreshBackpack({ wipe = true })
      assert.are_not.equal("Recent Items",
        items.slotInfo[const.BAG_KIND.BACKPACK].itemsBySlotKey["0_1"].itemInfo.category)

      local advance = installClock()
      refresh:RequestUpdate({ backpack = true })                            -- bank tab switch
      refresh:RequestUpdate({ wipe = true, backpack = true, bank = true })  -- interaction FullRefreshAll
      for _ = 1, 16 do advance() end

      local after = items.slotInfo[const.BAG_KIND.BACKPACK]
      assert.are_not.equal("Recent Items", after.itemsBySlotKey["0_1"].itemInfo.category,
        "pre-existing backpack items must not be flooded into Recent Items on bank open")
      assert.are_not.equal("Recent Items", after.itemsBySlotKey["0_2"].itemInfo.category)
      assert.are_not.equal("Recent Items", after.itemsBySlotKey["0_3"].itemInfo.category)
      assert.is_nil(items._newItemTimers[const.BAG_KIND.BACKPACK]["guid-101"],
        "the burst must not seed recent-item timers for pre-existing items")
    end)

    it("preserves untouched bags when a wipe and a targeted refresh are enqueued in the same frame", function()
      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 } }
      mockContainer[1] = { { itemID = 201, guid = "guid-201", count = 1 } }
      refreshBackpack() -- baseline, committed synchronously (before the clock)
      assert.is_not_nil(items.slotInfo[const.BAG_KIND.BACKPACK].itemsBySlotKey["1_1"])

      local advance = installClock()
      -- Serialized: the wipe unit commits both bags in full, THEN the targeted bag-0 sweep
      -- merges against that committed state, so bag 1 survives.
      refresh:RequestUpdate({ wipe = true, backpack = true, bank = true })
      refresh:RequestUpdate({ backpack = true, bags = { [0] = true } })
      for _ = 1, 16 do advance() end

      local slotInfo = items.slotInfo[const.BAG_KIND.BACKPACK]
      assert.is_not_nil(slotInfo.itemsBySlotKey["0_1"])
      assert.is_not_nil(slotInfo.itemsBySlotKey["1_1"], "bag 1 must survive a same-frame wipe + targeted refresh")
      assert.equal(201, slotInfo.itemsBySlotKey["1_1"].itemInfo.itemID)
      assert.equal(2, slotInfo.totalItems)
    end)
  end)

  -- Sorting. A sort the client can run is issued straight away and its own unit does not
  -- sweep: the one sweep that shows the result is the next refresh of that kind (normally
  -- the item moves' BAG_UPDATE), forced to re-read every bag and rebuild the layout, and a
  -- fallback timer guarantees that sweep when nothing moves. The disaster to rule out is a
  -- sort after which no sweep ever shows the cleared Recent Items / collapsed gaps.
  describe("sorting (one sweep per sort)", function()
    local frames, timers, sweeps, sortCalls

    local function installClocks()
      async.Yield = function() coroutine.yield() end
      frames, timers = {}, {}
      saveGlobal(_G.C_Timer, "After")
      _G.C_Timer.After = function(delay, fn)
        if delay == 0 then
          table.insert(frames, fn)
        else
          table.insert(timers, fn)
        end
      end
    end

    local function drain()
      for _ = 1, 50 do
        local pending = frames
        frames = {}
        for _, fn in ipairs(pending) do fn() end
        if #frames == 0 then return end
      end
      error("the refresh queue never drained")
    end

    local function fireFallbacks()
      local pending = timers
      timers = {}
      for _, fn in ipairs(pending) do fn() end
    end

    local function gapCount(sortedItems)
      local n = 0
      for _, e in ipairs(sortedItems or {}) do
        if e.isItemGap then n = n + 1 end
      end
      return n
    end

    before_each(function()
      sweeps = { [const.BAG_KIND.BACKPACK] = 0, [const.BAG_KIND.BANK] = 0 }
      sortCalls = { backpack = 0, bank = 0 }
      override(database, "GetCategoryFilter", function(_, _, filter) return filter == "RecentItems" end)
      override(database, "GetPreserveItemGaps", function() return true end)
      override(items, "IsBagOpen", function() return true end)
      override(addon:GetModule("Sort"), "GetItemDataSortFunction", function()
        return function(a, b) return tostring(a.slotkey) < tostring(b.slotkey) end
      end)
      local origRun = items.RunRefresh
      override(items, "RunRefresh", function(self, ectx, kind)
        sweeps[kind] = sweeps[kind] + 1
        return origRun(self, ectx, kind)
      end)
      saveGlobal(_G.C_Container, "SortBags")
      saveGlobal(_G.C_Container, "SortBankBags")
      _G.C_Container.SortBags = function() sortCalls.backpack = sortCalls.backpack + 1 end
      _G.C_Container.SortBankBags = function() sortCalls.bank = sortCalls.bank + 1 end

      -- Bag 0: three items; bag 1: one item flagged new by the client.
      mockContainer[0] = {
        { itemID = 101, guid = "g101", count = 1 },
        { itemID = 201, guid = "g201", count = 1 },
        { itemID = 202, guid = "g202", count = 1 },
      }
      mockContainer[1] = { { itemID = 303, guid = "g303", count = 1 } }
      newSlots["1_1"] = true
      refreshBackpack()
      -- Consume 0_2 with the bag open, leaving a held gap.
      mockContainer[0][2] = {}
      local before = refreshBackpack()
      assert.equal(1, gapCount(before.sortedItems))
      assert.equal("Recent Items", before.itemsBySlotKey["1_1"].itemInfo.category)
      assert.is_true(before.itemsBySlotKey["1_1"].itemInfo.isNewItem)
      sweeps[const.BAG_KIND.BACKPACK] = 0
      sweeps[const.BAG_KIND.BANK] = 0
    end)

    local function assertSortShown()
      local si = items.slotInfo[const.BAG_KIND.BACKPACK]
      assert.equal(0, gapCount(si.sortedItems), "the sort's sweep collapses held gaps")
      assert.are_not.equal("Recent Items", si.itemsBySlotKey["1_1"].itemInfo.category)
      assert.is_false(si.itemsBySlotKey["1_1"].itemInfo.isNewItem,
        "every bag is re-read, so the new-item glow clears even on a bag the sort did not touch")
      assert.is_false(items:IsSortSweepPending(const.BAG_KIND.BACKPACK))
    end

    it("shows a sort that moves items with the one sweep from the moves' BAG_UPDATE", function()
      installClocks()
      refresh:RequestUpdate({ sort = true })
      drain()
      assert.equal(1, sortCalls.backpack)
      assert.equal(0, sweeps[const.BAG_KIND.BACKPACK], "the sort unit itself must not sweep")

      -- The server moves 0_3 into the free 0_2; the loader reports bag 0 only.
      mockContainer[0][2] = mockContainer[0][3]
      mockContainer[0][3] = {}
      refresh:RequestUpdate({ backpack = true, bags = { [0] = true } })
      drain()

      assert.equal(1, sweeps[const.BAG_KIND.BACKPACK])
      assertSortShown()
      local si = items.slotInfo[const.BAG_KIND.BACKPACK]
      assert.equal(202, si.itemsBySlotKey["0_2"].itemInfo.itemID)

      fireFallbacks()
      drain()
      assert.equal(1, sweeps[const.BAG_KIND.BACKPACK], "the fallback does nothing once the sort was shown")
    end)

    it("shows a sort that moves nothing with the one sweep from the fallback", function()
      installClocks()
      refresh:RequestUpdate({ sort = true })
      drain()
      assert.equal(0, sweeps[const.BAG_KIND.BACKPACK])
      assert.equal(1, #timers)

      fireFallbacks()
      drain()

      assert.equal(1, sweeps[const.BAG_KIND.BACKPACK])
      assertSortShown()
    end)

    it("does not sweep twice when the fallback fires while the moves' refresh is still queued", function()
      installClocks()
      refresh:RequestUpdate({ sort = true })
      mockContainer[0][2] = mockContainer[0][3]
      mockContainer[0][3] = {}
      refresh:RequestUpdate({ backpack = true, bags = { [0] = true } })
      fireFallbacks() -- the moves' unit has not run yet, so the sweep is still pending
      drain()

      assert.equal(1, sweeps[const.BAG_KIND.BACKPACK])
      assertSortShown()
    end)

    it("still shows the sort from the fallback when the moves' sweep fails", function()
      installClocks()
      local failures = 1
      local origPartition = items.Phase10_PartitionIntoTabs
      override(items, "Phase10_PartitionIntoTabs", function(...)
        if failures > 0 then
          failures = failures - 1
          error("simulated sweep failure")
        end
        return origPartition(...)
      end)

      refresh:RequestUpdate({ sort = true })
      refresh:RequestUpdate({ backpack = true, bags = { [0] = true } })
      drain()
      assert.equal(1, sweeps[const.BAG_KIND.BACKPACK])
      assert.is_true(items:IsSortSweepPending(const.BAG_KIND.BACKPACK), "a failed sweep must not count as shown")

      fireFallbacks()
      drain()
      assert.equal(2, sweeps[const.BAG_KIND.BACKPACK])
      assertSortShown()
    end)

    it("sweeps at once, as before, when it cannot sort in combat", function()
      installClocks()
      saveGlobal(_G, "InCombatLockdown")
      _G.InCombatLockdown = function() return true end
      refresh:RequestUpdate({ sort = true })
      drain()

      assert.equal(0, sortCalls.backpack)
      assert.equal(1, sweeps[const.BAG_KIND.BACKPACK])
      assert.equal(0, #timers)
      assertSortShown()
    end)

    it("shows a bank sort that moves nothing with the one bank sweep from the fallback", function()
      installClocks()
      override(addon, "atBank", true)
      override(addon, "Bags", { Bank = { bankTab = 6 } })
      mockContainer[6] = { { itemID = 201, guid = "gb1", count = 1 } }
      refresh:RequestUpdate({ sortBank = true })
      drain()
      assert.equal(1, sortCalls.bank)
      assert.equal(0, sweeps[const.BAG_KIND.BANK])

      fireFallbacks()
      drain()
      assert.equal(1, sweeps[const.BAG_KIND.BANK])
      assert.equal(0, sweeps[const.BAG_KIND.BACKPACK])
      assert.is_false(items:IsSortSweepPending(const.BAG_KIND.BANK))
    end)
  end)

  -- Gear set (WoW C_EquipmentSet) labeling. The equipment-set location map is
  -- keyed by physical (bag, slot) and is only correct if it is rebuilt on every
  -- data sweep. Commit ce09592 dropped the per-sweep equipmentSets:Update() call
  -- that the pre-refactor pipeline made at the top of RefreshBags, so the map
  -- went stale after login: newly looted items in slots a set item had vacated
  -- inherited the set label, and set items that moved lost theirs (issue: gear
  -- items mislabeled / disappearing after looting).
  describe("gear set labeling (C_EquipmentSet)", function()
    -- A stateful EquipmentSets stub: GetItemSets reads a live (bag,slot)->names
    -- map, and Update() rebuilds that live map from a "pending" source of truth
    -- (the current C_EquipmentSet item locations). The sweep must call Update()
    -- for the live map to reflect the pending source.
    local liveSets, pendingSets, eq

    local function syncFromPending()
      liveSets = {}
      for bag, slots in pairs(pendingSets) do
        liveSets[bag] = {}
        for slot, names in pairs(slots) do
          liveSets[bag][slot] = names
        end
      end
    end

    before_each(function()
      liveSets = {}
      pendingSets = {}
      eq = addon:GetModule("EquipmentSets")
      override(eq, "GetItemSets", function(_, bag, slot)
        return liveSets[bag] and liveSets[bag][slot]
      end)
      override(eq, "Update", function()
        syncFromPending()
      end)
      -- Only the GearSet category filter is on for these tests.
      override(database, "GetCategoryFilter", function(_, _, filter)
        return filter == "GearSet"
      end)
    end)

    it("rebuilds the set map each sweep so a set item is labeled", function()
      pendingSets[0] = { [1] = { "Demo" } }
      mockContainer[0] = {
        { itemID = 101, guid = "gear-demo", count = 1 },
      }

      local slotInfo = refreshBackpack()

      local item = slotInfo.itemsBySlotKey["0_1"]
      assert.is_not_nil(item)
      assert.are.same({ "Demo" }, item.itemInfo.equipmentSets)
      assert.equal("Gear: Demo", item.itemInfo.category)
    end)

    it("does not label a newly looted item that took over a vacated set slot", function()
      -- Simulate login: the set map was built once while a Demo gear piece sat in
      -- slot 0_1.
      pendingSets[0] = { [1] = { "Demo" } }
      eq:Update()
      assert.are.same({ "Demo" }, eq:GetItemSets(0, 1))

      -- The Demo piece is equipped (leaves the bags) and a brand-new looted item
      -- lands in the now-free slot 0_1. The set no longer occupies any bag slot.
      pendingSets[0] = {}
      mockContainer[0] = {
        { itemID = 303, guid = "loot-new", count = 1 },
      }

      local slotInfo = refreshBackpack({ bags = { [0] = true } })

      local item = slotInfo.itemsBySlotKey["0_1"]
      assert.is_not_nil(item)
      assert.equal(303, item.itemInfo.itemID)
      assert.is_nil(item.itemInfo.equipmentSets)
      assert.are_not.equal("Gear: Demo", item.itemInfo.category)
    end)

    it("follows a set item that moved to a new slot instead of dropping its label", function()
      -- Login-time map: Demo piece in slot 0_1.
      pendingSets[0] = { [1] = { "Demo" } }
      eq:Update()

      -- The piece is dragged to slot 0_2; the C_EquipmentSet locations now point
      -- at 0_2. Without a per-sweep Update() the stale map still points at 0_1, so
      -- the moved piece loses its "Gear: Demo" label (the "gear sets disappeared"
      -- symptom).
      pendingSets[0] = { [2] = { "Demo" } }
      mockContainer[0] = {
        {},
        { itemID = 101, guid = "gear-demo", count = 1 },
      }

      local slotInfo = refreshBackpack({ bags = { [0] = true } })

      local moved = slotInfo.itemsBySlotKey["0_2"]
      assert.is_not_nil(moved)
      assert.are.same({ "Demo" }, moved.itemInfo.equipmentSets)
      assert.equal("Gear: Demo", moved.itemInfo.category)
    end)

    it("relabels set items when the set is renamed (e.g. after a spec switch)", function()
      -- Two gear pieces, initially in the "Demo" set.
      pendingSets[0] = { [1] = { "Demo" }, [2] = { "Demo" } }
      mockContainer[0] = {
        { itemID = 101, guid = "gear-a", count = 1 },
        { itemID = 202, guid = "gear-b", count = 1 },
      }
      local slotInfo = refreshBackpack()
      assert.equal("Gear: Demo", slotInfo.itemsBySlotKey["0_1"].itemInfo.category)
      assert.equal("Gear: Demo", slotInfo.itemsBySlotKey["0_2"].itemInfo.category)

      -- The set the pieces belong to now resolves to a different name. A stale map
      -- would keep labeling them "Gear: Demo"; a fresh sweep must pick up "Aff".
      pendingSets[0] = { [1] = { "Aff" }, [2] = { "Aff" } }
      slotInfo = refreshBackpack({ wipe = true })

      assert.equal("Gear: Aff", slotInfo.itemsBySlotKey["0_1"].itemInfo.category)
      assert.equal("Gear: Aff", slotInfo.itemsBySlotKey["0_2"].itemInfo.category)
    end)
  end)

  -- Tooltip-body free-text search. The harvest scans each item's tooltip via
  -- tooltipScanner:GetTooltipText and must store it on itemInfo.tooltipText so
  -- search:Add indexes it into the 'tooltip' index (one of the default free-text
  -- indices). Commit ce09592 (#1037) dropped the assignment from the itemInfo
  -- constructor, so the tooltip index stayed empty and free-text queries that
  -- only match an item's tooltip body found nothing (issue #1078).
  describe("tooltip-body search indexing", function()
    it("indexes an item's tooltip text so free-text search matches it", function()
      local tooltipScanner = addon:GetModule("TooltipScanner")
      -- "zephyrium" appears only in the tooltip body, not in the name/type/subtype.
      override(tooltipScanner, "GetTooltipText", function(_, bagid, slotid)
        if bagid == 0 and slotid == 1 then
          return "Use: channel zephyrium essence"
        end
        return ""
      end)
      mockContainer[0] = {
        { itemID = 101, guid = "guid-101", count = 1 },
      }

      local slotInfo = refreshBackpack()

      -- The scanned text must be carried on the item so the search engine can index it.
      assert.equal("Use: channel zephyrium essence",
        slotInfo.itemsBySlotKey["0_1"].itemInfo.tooltipText)

      -- A free-text query for a word that lives only in the tooltip body must match.
      local results = search:Search("zephyrium")
      assert.is_true(results["0_1"] == true,
        "free-text search should match text found only in the tooltip body")
    end)

    it("leaves the tooltip index empty for items with no tooltip text", function()
      local tooltipScanner = addon:GetModule("TooltipScanner")
      override(tooltipScanner, "GetTooltipText", function() return "" end)
      mockContainer[0] = {
        { itemID = 101, guid = "guid-101", count = 1 },
      }

      local slotInfo = refreshBackpack()
      assert.equal("", slotInfo.itemsBySlotKey["0_1"].itemInfo.tooltipText)
      assert.is_nil(search:Search("zephyrium")["0_1"])
    end)
  end)
end)
