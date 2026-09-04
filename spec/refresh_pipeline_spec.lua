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
local mockContainer, newSlots, removedNewItems

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
  override(database, "GetGroupsEnabled", function() return false end)
  override(database, "GetActiveGroup", function() return 1 end)
  override(database, "GetShowBankTabs", function() return false end)

  local equipmentSets = stubModule("EquipmentSets")
  override(equipmentSets, "GetItemSets", function() return nil end)

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
  override(searchBox, "GetText", function() return searchText end)

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
    { _G.C_Item, "GetItemSubClassInfo" },
    { _G.C_NewItems, "IsNewItem" },
    { _G.C_NewItems, "RemoveNewItem" },
    { _G, "GetInventoryItemLink" },
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
    local name = itemNames[slot.itemID] or ("TestItem " .. slot.itemID)
    return "|cffffffff|Hitem:" .. slot.itemID .. "|h[" .. name .. "]|h|r"
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
      hyperlink = _G.C_Container.GetContainerItemLink(bagid, slotid),
      isFiltered = false,
      hasNoValue = false,
      itemID = slot.itemID,
      isBound = false,
    }
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
  _G.C_Item.GetItemSubClassInfo = function() return "Bag" end
  _G.C_NewItems.IsNewItem = function(bagid, slotid)
    return newSlots[bagid .. "_" .. slotid] or false
  end
  _G.C_NewItems.RemoveNewItem = function(bagid, slotid)
    newSlots[bagid .. "_" .. slotid] = nil
    table.insert(removedNewItems, bagid .. "_" .. slotid)
  end
  _G.GetInventoryItemLink = function() return nil end
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

  it("does not lose untouched bags when a wipe refresh and a targeted refresh start in the same frame", function()
    mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 } }
    mockContainer[1] = { { itemID = 201, guid = "guid-201", count = 1 } }
    refreshBackpack()
    assert.is_not_nil(items.slotInfo[const.BAG_KIND.BACKPACK].itemsBySlotKey["1_1"])

    -- Use the real frame boundary: async:Yield suspends the coroutine and it resumes
    -- through C_Timer.After on the next frame.
    async.Yield = function() coroutine.yield() end
    local queued = {}
    saveGlobal(_G.C_Timer, "After")
    _G.C_Timer.After = function(_, fn) table.insert(queued, fn) end

    -- Frame N: a full wipe refresh (bags/FullRefreshAll) ...
    refresh:RequestUpdate({ wipe = true, backpack = true, bank = true })
    -- ... followed in the same frame by a BAG_UPDATE_DELAYED sweep targeting bag 0 only.
    refresh:RequestUpdate({ backpack = true, bags = { [0] = true } })
    assert.equal(2, #queued, "both refreshes must be suspended at a frame boundary")

    -- Frame N+1: both coroutines resume in the order they were queued.
    local i = 1
    while queued[i] do
      queued[i]()
      i = i + 1
    end

    local slotInfo = items.slotInfo[const.BAG_KIND.BACKPACK]
    assert.is_not_nil(slotInfo.itemsBySlotKey["0_1"])
    assert.is_not_nil(slotInfo.itemsBySlotKey["1_1"], "bag 1 must survive a same-frame wipe + targeted refresh")
    assert.equal(201, slotInfo.itemsBySlotKey["1_1"].itemInfo.itemID)
    assert.equal(2, slotInfo.totalItems)
  end)
end)
