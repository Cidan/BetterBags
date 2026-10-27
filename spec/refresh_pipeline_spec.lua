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
  override(categories, "SkipsRecentOf", function() return false end)
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

  -- The bank's partition asks Groups for a tab's group. Another spec file can leave a Groups
  -- stub without it, or the real module, which asks the database (busted --shuffle-files); no
  -- group then, as with no Groups module.
  local groups = stubModule("Groups")
  if not groups.GetGroup then
    override(groups, "GetGroup", function() return nil end)
  end
  if not database.GetGroup then
    override(database, "GetGroup", function() return nil end)
  end
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
  -- C_Item.GetItemGUID(itemLocation) takes an ItemLocation that holds an item, not an
  -- EmptiableItemLocation (ItemDocumentation.lua): the client raises an error for an empty slot, as
  -- seen in game ("bad argument #1 to 'GetItemGUID' (Usage: local itemGUID =
  -- C_Item.GetItemGUID(itemLocation))"). Equipped items are not modeled here.
  _G.C_Item.GetItemGUID = function(location)
    local bagid, slotid = location:GetBagAndSlot()
    if bagid == nil then
      return ""
    end
    local slot = mockContainer[bagid] and mockContainer[bagid][slotid]
    if not (slot and slot.itemID) then
      error("bad argument #1 to 'GetItemGUID' (Usage: local itemGUID = C_Item.GetItemGUID(itemLocation))", 2)
    end
    return slot.guid or ""
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
    if opts and opts.derive then
      ctx:Set("derive", true)
    end
    if opts and opts.categoriesUnchanged then
      ctx:Set("categoriesUnchanged", true)
    end
    if opts and opts.restyle then
      ctx:Set("restyle", true)
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

  -- Issue #1121: on WoW: Forever the keyring (bag -1) is read with the backpack, as on
  -- Classic Era, and its empty slots are not free space.
  it("shows the items in the Forever keyring, without counting its slots as free space", function()
    override(_G.Enum.BagIndex, "Keyring", -1)
    override(const, "BACKPACK_BAGS", { [-1] = -1, [0] = 0, [1] = 1 })
    override(_G.C_Container, "GetContainerNumFreeSlots", function(bagid)
      local free = 0
      for _, slot in ipairs(mockContainer[bagid] or {}) do
        if not slot.itemID then free = free + 1 end
      end
      return free, 0
    end)
    mockContainer[-1] = { { itemID = 900, guid = "guid-key" }, {}, {} }
    mockContainer[0] = { { itemID = 101, guid = "guid-101" }, {} }

    local slotInfo = refreshBackpack({ wipe = true })

    local key = slotInfo.itemsBySlotKey["-1_1"]
    assert.is_not_nil(key)
    assert.are.equal(900, key.itemInfo.itemID)
    assert.is_not_nil(slotInfo:GetVisibleItems()["-1_1"])
    local free = 0
    for _, count in pairs(slotInfo.emptySlots) do free = free + count end
    assert.are.equal(1, free)
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

    -- Vendor's CurrentEquippedLevel and WatermarkLevel, per item (search-indexing.md §16).
    describe("slot values", function()
      local bagGear

      before_each(function()
        -- Bag items 101 (a ring), 102 (a one-hander), 103 (a two-hander), 104 (not equipment).
        -- Enum.InventoryType's finger (11), weapon (13) and two-hand (17) types, and their slots as
        -- core/constants.lua maps them (this spec stubs the constants).
        bagGear = {
          [101] = { "INVTYPE_FINGER", 11 },
          [102] = { "INVTYPE_WEAPON", 13 },
          [103] = { "INVTYPE_2HWEAPON", 17 },
        }
        override(const, "INVENTORY_TYPE_TO_INVENTORY_SLOTS", { [1] = { 1 }, [11] = { 11, 12 }, [13] = { 16, 17 },
          [17] = { 16 } })
        -- An item ID or an item link, as GetItemInfoInstant and IsEquippableItem take them.
        local function idOf(l) return tonumber(l) or tonumber(tostring(l):match("item:(%d+)")) end
        local instant = _G.C_Item.GetItemInfoInstant
        override(_G.C_Item, "GetItemInfoInstant", function(info)
          local gear = bagGear[idOf(info)]
          if gear then return idOf(info), "Armor", "Misc", gear[1], 134400, 4, 0 end
          return instant(info)
        end)
        override(_G.C_Item, "IsEquippableItem", function(l) return bagGear[idOf(l)] ~= nil end)
        local bagItem = _G.Item.CreateFromBagAndSlot
        override(_G.Item, "CreateFromBagAndSlot", function(item, bag, slot)
          local mixin = bagItem(item, bag, slot)
          local held = mockContainer[bag] and mockContainer[bag][slot]
          local gear = held and bagGear[held.itemID]
          if gear then
            function mixin:GetInventoryType() return gear[2] end
          end
          return mixin
        end)
        override(_G, "C_ItemUpgrade", { GetHighWatermarkForItem = function(l)
          if bagGear[idOf(l)] then return 246, 250 end
          return 0, 0
        end })
        override(_G, "CanDualWield", function() return true end)
        override(_G, "UnitClass", function() return "Paladin", "PALADIN", 2 end)
        mockContainer[0] = { { itemID = 101, guid = "ring", count = 1 }, { itemID = 102, guid = "sword", count = 1 },
          { itemID = 103, guid = "axe", count = 1 }, { itemID = 104, guid = "cheese", count = 1 } }
        equip(11, 511, 230)
        equip(12, 512, 210)
        equip(16, 516, 200)
        equip(17, 517, 150)
      end)

      it("gives equipment the lowest item level worn in its slots, and its slot's best", function()
        local slotInfo = refreshBackpack({ wipe = true })
        local ring = slotInfo.itemsBySlotKey["0_1"]
        assert.are.equal(210, ring.slotEquipped)
        assert.are.equal(246, ring.slotBest)
        assert.are.same({ ["0_1"] = true }, search:Search("slotequipped = 210"))
        assert.is_true(search:Search("slotbest = 246")["0_1"])
        assert.is_nil(slotInfo.itemsBySlotKey["0_4"].slotEquipped, "not equipment")
        assert.is_nil(slotInfo.itemsBySlotKey["0_4"].slotBest)
      end)

      it("counts the off hand for a one-hander only with dual wield", function()
        local slotInfo = refreshBackpack({ wipe = true })
        assert.are.equal(150, slotInfo.itemsBySlotKey["0_2"].slotEquipped)
        _G.CanDualWield = function() return false end
        slotInfo = refreshBackpack({ wipe = true })
        assert.are.equal(200, slotInfo.itemsBySlotKey["0_2"].slotEquipped)
      end)

      it("counts both hands for a warrior's two-hander", function()
        local slotInfo = refreshBackpack({ wipe = true })
        assert.are.equal(200, slotInfo.itemsBySlotKey["0_3"].slotEquipped)
        _G.UnitClass = function() return "Warrior", "WARRIOR", 1 end
        slotInfo = refreshBackpack({ wipe = true })
        assert.are.equal(150, slotInfo.itemsBySlotKey["0_3"].slotEquipped)
      end)

      it("is 0 when nothing is worn in the slots", function()
        equipped[11], equipped[12] = nil, nil
        local slotInfo = refreshBackpack({ wipe = true })
        assert.are.equal(0, slotInfo.itemsBySlotKey["0_1"].slotEquipped)
      end)

      -- The worn gear changes without the item changing: a recalculation keeps the search current.
      it("keeps a kept item's slot values current when the worn gear changes", function()
        refreshBackpack({ wipe = true })
        local kept = items.slotInfo[const.BAG_KIND.BACKPACK].itemsBySlotKey["0_1"]
        equip(12, 612, 260)
        refreshBackpack({ derive = true, categoriesUnchanged = true })
        assert.are.equal(kept, items.slotInfo[const.BAG_KIND.BACKPACK].itemsBySlotKey["0_1"])
        assert.are.equal(230, kept.slotEquipped)
        assert.are.same({ ["0_1"] = true }, search:Search("slotequipped = 230"))
        assert.are.same({}, search:Search("slotequipped = 210"))
        assert.is_true(search:Search("ilvl < slotequipped")["0_1"], "a field compared with a slot value")
      end)

      it("has no slot values for an item read before its data loaded", function()
        local info = _G.C_Item.GetItemInfo
        override(_G.C_Item, "GetItemInfo", function(x)
          if tostring(x):find("101", 1, true) then return nil end
          return info(x)
        end)
        local slotInfo = refreshBackpack({ wipe = true })
        assert.is_nil(slotInfo.itemsBySlotKey["0_1"].slotEquipped)
        assert.is_nil(slotInfo.itemsBySlotKey["0_1"].slotBest)
      end)
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
    local asked, verdicts, registered, timers, sent, sentOptions, provider

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
      asked, verdicts, registered, timers, sent, sentOptions = {}, {}, {}, {}, {}, {}
      override(database, "GetUpgradeIconProvider", function() return provider end)
      override(database, "GetUpgradeIconProviderUserSet", function() return true end)
      override(events, "RegisterEvent", function(_, name, cb) registered[name] = cb end)
      override(_G.C_Timer, "After", function(delay, fn) table.insert(timers, { delay = delay, fn = fn }) end)
      local send = events.SendMessage
      override(events, "SendMessage", function(self, ctx, event, ...)
        table.insert(sent, event)
        sentOptions[#sent] = (...)
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

    -- The upgrade field follows the arrow on an item the sweep kept (data-loader.md §18: a value
    -- set again in place is re-indexed only when the item is marked).
    it("keeps the upgrade field current when a kept item's arrow changes", function()
      assert.are.same({ ["0_1"] = true }, search:Search("upgrade = true"))
      local kept = items.slotInfo[const.BAG_KIND.BACKPACK].itemsBySlotKey["0_1"]
      verdicts[101] = false
      items:InvalidateUpgrades()
      local slotInfo = refreshBackpack({ derive = true })
      assert.are.equal(kept, slotInfo.itemsBySlotKey["0_1"], "the same item, kept")
      assert.is_false(slotInfo.itemsBySlotKey["0_1"].isUpgrade)
      assert.are.same({}, search:Search("upgrade = true"))
      assert.is_true(search:Search("upgrade = false")["0_1"])
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

    -- Level and scaling change the bag items' own current item levels, which only a read
    -- sees (the kept-slot check compares them). Every other input of a verdict lives outside
    -- the bags, so the bags are recalculated from the items already read, not read again.
    local invalidating = {
      { "PLAYER_EQUIPMENT_CHANGED", { 5, true }, "bags/Rederive" },
      { "PLAYER_LEVEL_UP", { 70 }, "bags/RefreshBackpack" },
      { "PLAYER_LEVEL_CHANGED", { 70, 60 }, "bags/RefreshBackpack" },
      { "PLAYER_AVG_ITEM_LEVEL_UPDATE", {}, "bags/RefreshBackpack" },
      { "SKILL_LINES_CHANGED", {}, "bags/Rederive" },
      { "LEARNED_SPELL_IN_SKILL_LINE", { 12345, 1, false }, "bags/Rederive" },
      { "PLAYER_SPECIALIZATION_CHANGED", { "player" }, "bags/Rederive" },
    }
    for _, case in ipairs(invalidating) do
      local derive = case[3] == "bags/Rederive"
      it("asks again after " .. case[1] .. ", and requests a backpack " .. (derive and "recalculation" or "read"), function()
        fire(case[1], unpack(case[2]))
        runTimers()
        assert.are.same({ case[3] }, sent, "the bank is closed")
        if derive then
          assert.are.same({ backpack = true, bank = false, categoriesUnchanged = true }, sentOptions[1])
        end
        refreshBackpack(derive and { derive = true } or nil)
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
      assert.are.same({ "bags/Rederive" }, sent)
    end)

    it("reads instead of recalculating when a level change is among the frame's invalidations", function()
      fire("SKILL_LINES_CHANGED")
      fire("PLAYER_LEVEL_UP", 70)
      fire("PLAYER_EQUIPMENT_CHANGED", 5, true)
      assert.equal(1, #timers)
      runTimers()
      assert.are.same({ "bags/RefreshBackpack" }, sent)
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
      runTimers()
      sent = {}
      current = link:gsub("505:0", "505:6")
      refreshBackpack()
      assert.are.same({ "0_1", "0_2" }, askedKeys())
      -- The sweep that read the new gear resolved every verdict with it, so it asks for no
      -- second backpack refresh.
      runTimers()
      for _, event in ipairs(sent) do
        assert.is_nil(event:match("^bags/"), "no refresh is requested")
      end
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
      assert.are.same({ "bags/Rederive" }, sent)
      assert.are.same({ backpack = true, bank = true, categoriesUnchanged = true }, sentOptions[1])
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
      local requested = {}
      for i, event in ipairs(sent) do
        if event:match("^bags/") then table.insert(requested, { event, sentOptions[i] }) end
      end
      assert.are.same({ { "bags/Rederive", { backpack = false, bank = true, categoriesUnchanged = true } } }, requested,
        "the open bank is recalculated")
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
      assert.are.same({ "0_1", "0_2" }, askedKeys(), "the sweep that reads the gear warm asks again itself")
      runTimers()
      for _, event in ipairs(sent) do
        assert.is_nil(event:match("^bags/"), "so it needs no second refresh")
      end
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

    -- Before the first backpack sweep the equipped gear is unknown (equipmentCache is nil):
    -- a verdict computed then would compare with nothing, and a naked character's gear read
    -- would detect no change to invalidate it, so nothing is kept until the gear is read.
    it("does not keep a verdict computed before the equipped gear was read", function()
      mockContainer[6] = { { itemID = 301, guid = "bank1", count = 1 } }
      items.equipmentCache = nil
      items:RefreshBank(context:New("bank1"))
      items:RefreshBank(context:New("bank2"))
      assert.are.same({ "6_1", "6_1" }, askedKeys(), "asked on every sweep while the gear is unknown")
      refreshBackpack()
      askedKeys()
      items:RefreshBank(context:New("bank3"))
      items:RefreshBank(context:New("bank4"))
      assert.are.same({ "6_1" }, askedKeys(), "kept once the gear has been read")
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

    -- At equal priority an item placed by hand stays where it was placed (category-lifecycle.md §6).
    override(categories, "GetSortedSearchCategories", searchCategoryWithPriority(1))
    slotInfo = refreshBackpack()
    assert.equal("Custom", slotInfo.itemsBySlotKey["0_1"].itemInfo.category, "a tie")

    -- ... and the search category wins once it carries the higher priority.
    override(categories, "GetSortedSearchCategories", searchCategoryWithPriority(0))
    slotInfo = refreshBackpack()
    assert.equal("Searchy", slotInfo.itemsBySlotKey["0_1"].itemInfo.category)
  end)

  -- Asked: an item you add to a category by hand stays in it, whatever the order of the categories
  -- (category-lifecycle.md §7). A plugin's item lists still compete with rules by the order.
  it("keeps an item added by hand to a category of yours there, even with a rule's category above it", function()
    local tools = { name = "Tools", save = true, priority = 5, enabled = { [const.BAG_KIND.BACKPACK] = true } }
    local custom = tools
    override(categories, "GetCustomCategory", function(_, _, _, data)
      if data.itemInfo.itemID == 101 then return custom.name, custom.priority, custom end
      return nil, nil
    end)
    override(categories, "GetSortedSearchCategories", function()
      return { { name = "Sell", enabled = { [const.BAG_KIND.BACKPACK] = true }, priority = 1,
        searchCategory = { query = "alpha", groupBy = const.SEARCH_CATEGORY_GROUP_BY.NONE } } }
    end)
    mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 } }
    local slotInfo = refreshBackpack()
    assert.equal("Sell", items:GetSearchCategory(const.BAG_KIND.BACKPACK, "0_1"), "the rule matches it")
    assert.equal("Tools", slotInfo.itemsBySlotKey["0_1"].itemInfo.category)
    custom = { name = "Openable", priority = 5, enabled = { [const.BAG_KIND.BACKPACK] = true } }
    slotInfo = refreshBackpack({ wipe = true })
    assert.equal("Sell", slotInfo.itemsBySlotKey["0_1"].itemInfo.category, "a plugin's list loses to a rule above it")
  end)

  -- Group by is the category's own: the items placed in it by hand are grouped as its rule's matches
  -- are, into sub-categories made for them (category-lifecycle.md §6).
  it("groups the items placed in a category by hand, making the sub-category", function()
    local mats = { name = "Mats", groupBy = const.SEARCH_CATEGORY_GROUP_BY.TYPE, priority = 4, color = { 1, 0, 0 },
      enabled = { [const.BAG_KIND.BACKPACK] = true } }
    override(categories, "GetCustomCategory", function(_, _, _, data)
      if data.itemInfo.itemID == 101 then return "Mats", 4, mats end
      return nil, nil
    end)
    local made = {}
    override(categories, "DoesCategoryExist", function(_, name) return made[name] ~= nil end)
    override(categories, "CreateCategory", function(_, _, category) made[category.name] = category end)
    mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 } }
    local slotInfo = refreshBackpack()
    local item = slotInfo.itemsBySlotKey["0_1"]
    local grouped = "Mats - " .. item.itemInfo.itemType
    assert.equal(grouped, item.itemInfo.category)
    local sub = made[grouped]
    assert.is_not_nil(sub, "the sub-category is made")
    assert.is_true(sub.isGroupBySubcategory)
    assert.equal("Mats", sub.groupByParent)
    assert.equal(mats.enabled, sub.enabled)
    assert.same({ 1, 0, 0 }, sub.color)
    assert.equal(4, sub.priority)
  end)

  -- Search categories are matched against each item's own category (the one it has without any
  -- search category), never against a search category it was given (data-loader.md §8).
  -- Reported: a search category "Lucky Items" with the query "lucky" held Arcanoweave, which says
  -- "lucky" nowhere: categories were first given from the previous sweep's search results, kept by
  -- bag slot, and a bare word matches the category field, so an item that landed in a lucky item's
  -- slot (a sort) took "Lucky Items" and then matched "lucky" through that name for good.
  describe("search categories match each item's own category", function()
    local function searchCategories(list)
      override(categories, "GetCustomCategory", function() return nil, nil end)
      override(categories, "GetSortedSearchCategories", function()
        local out = {}
        for _, c in ipairs(list) do
          table.insert(out, { name = c[1], priority = c[3] or 10,
            enabled = { [const.BAG_KIND.BACKPACK] = true, [const.BAG_KIND.BANK] = true },
            searchCategory = { query = c[2], groupBy = const.SEARCH_CATEGORY_GROUP_BY.NONE } })
        end
        return out
      end)
    end

    local function categoryOf(slotInfo, slotkey)
      return slotInfo.itemsBySlotKey[slotkey].itemInfo.category
    end

    it("never gives an item the search category of the item that was in its slot before", function()
      searchCategories({ { "Alpha Items", "alpha" } })
      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 }, { itemID = 202, guid = "guid-202", count = 1 } }
      local slotInfo = refreshBackpack()
      local own = categoryOf(slotInfo, "0_2")
      assert.equal("Alpha Items", categoryOf(slotInfo, "0_1"))
      assert.are_not.equal("Alpha Items", own)
      -- A sort swaps them: each keeps its GUID, in the other slot.
      mockContainer[0] = { { itemID = 202, guid = "guid-202", count = 1 }, { itemID = 101, guid = "guid-101", count = 1 } }
      slotInfo = refreshBackpack()
      assert.equal(own, categoryOf(slotInfo, "0_1"), "Beta Shield took its slot's old search category")
      assert.equal("Alpha Items", categoryOf(slotInfo, "0_2"))
      slotInfo = refreshBackpack()
      assert.equal(own, categoryOf(slotInfo, "0_1"), "and on the next read")
    end)

    it("lets an item go once it no longer matches, even when the category's name holds the query", function()
      searchCategories({ { "Alpha Items", "alpha" } })
      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 } }
      assert.equal("Alpha Items", categoryOf(refreshBackpack(), "0_1"))
      -- Its own name, type, subtype and tooltip hold no "items"; the category's name does.
      searchCategories({ { "Alpha Items", "items" } })
      local slotInfo = refreshBackpack({ derive = true })
      assert.are_not.equal("Alpha Items", categoryOf(slotInfo, "0_1"))
    end)

    it("matches the category field against the item's own category, never a search category's name", function()
      searchCategories({ { "Alpha Items", "alpha" }, { "Meta", 'category = "alpha items"', 1 } })
      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 } }
      refreshBackpack()
      local slotInfo = refreshBackpack()
      assert.equal("Alpha Items", categoryOf(slotInfo, "0_1"))
      -- The item's own category still works (README: `and not category = "gear:"`).
      override(categories, "GetCustomCategory", function(_, _, _, data)
        if data.itemInfo.itemID == 101 then return "Custom", 10 end
        return nil, nil
      end)
      local list = { { "By Custom", "category = custom" } }
      -- Ahead of Custom: at equal priority the item would stay in the category it was placed in.
      override(categories, "GetSortedSearchCategories", function()
        return { { name = list[1][1], priority = 9, enabled = { [const.BAG_KIND.BACKPACK] = true },
          searchCategory = { query = list[1][2], groupBy = const.SEARCH_CATEGORY_GROUP_BY.NONE } } }
      end)
      slotInfo = refreshBackpack({ derive = true })
      assert.equal("By Custom", categoryOf(slotInfo, "0_1"))
    end)

    it("reads each item's crafting tier from its link, for the quality field", function()
      override(_G.C_TradeSkillUI, "GetItemReagentQualityByItemInfo", function(info)
        return tostring(info):find("item:202", 1, true) and 2 or nil
      end)
      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 }, { itemID = 202, guid = "guid-202", count = 1 } }
      local slotInfo = refreshBackpack()
      assert.is_nil(slotInfo.itemsBySlotKey["0_1"].itemInfo.traits.craftingQuality)
      assert.are.equal(2, slotInfo.itemsBySlotKey["0_2"].itemInfo.traits.craftingQuality)
      searchCategories({ { "Tier 2", "quality = 2" } })
      slotInfo = refreshBackpack({ derive = true })
      assert.equal("Tier 2", categoryOf(slotInfo, "0_2"))
      assert.are_not.equal("Tier 2", categoryOf(slotInfo, "0_1"))
    end)

    it("reads no crafting tier while an item's data has not loaded, and reads it once it has", function()
      local asked = 0
      override(_G.C_TradeSkillUI, "GetItemReagentQualityByItemInfo", function()
        asked = asked + 1
        return 2
      end)
      local getItemInfo = _G.C_Item.GetItemInfo
      local cold = true
      override(_G.C_Item, "GetItemInfo", function(id)
        if cold then return nil end
        return getItemInfo(id)
      end)
      mockContainer[0] = { { itemID = 202, guid = "guid-202", count = 1 } }
      local slotInfo = refreshBackpack({ wipe = true })
      assert.is_true(slotInfo.itemsBySlotKey["0_1"].harvestIncomplete)
      assert.is_nil(slotInfo.itemsBySlotKey["0_1"].itemInfo.traits)
      assert.are.equal(0, asked)
      cold = false
      slotInfo = refreshBackpack({ derive = true })
      assert.are.equal(2, slotInfo.itemsBySlotKey["0_1"].itemInfo.traits.craftingQuality, "read again once loaded")
    end)

    -- Category automation leaves a purchase that can still be refunded alone, deciding from the bags'
    -- last read (automation.md §2): so the read records it, from the slot that holds the item, and a
    -- kept slot reads it again (the refund window ends without the slot changing).
    it("reads whether each item can still be refunded, and again while it stays in its slot", function()
      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 }, { itemID = 202, guid = "guid-202", count = 1 } }
      override(_G, "_refundableLocations", { ["0:1"] = true })
      local slotInfo = refreshBackpack()
      assert.is_true(slotInfo.itemsBySlotKey["0_1"].itemInfo.refundable)
      assert.is_false(slotInfo.itemsBySlotKey["0_2"].itemInfo.refundable)
      _G._refundableLocations["0:1"] = nil
      local before = slotInfo.itemsBySlotKey["0_1"]
      slotInfo = refreshBackpack({ bags = { [0] = true } })
      assert.are.equal(before, slotInfo.itemsBySlotKey["0_1"], "kept")
      assert.is_false(slotInfo.itemsBySlotKey["0_1"].itemInfo.refundable, "its window ended")
      _G._refundableLocations["0:2"] = true
      slotInfo = refreshBackpack({ derive = true })
      assert.is_true(slotInfo.itemsBySlotKey["0_2"].itemInfo.refundable, "a recalculation reads it too")
    end)

    -- One search category per new field group, end to end: the harvest reads the traits from the
    -- slot's link, the index holds them, and a kept slot keeps them.
    it("reads each item's traits from its link, and searches them", function()
      override(_G.C_Item, "IsEquippableItem", function(l) return tostring(l):find("item:101", 1, true) ~= nil end)
      override(_G.C_Item, "GetItemSpell", function(l)
        if tostring(l):find("item:202", 1, true) then return "Shield Wall", 871 end
      end)
      override(_G.C_Item, "CanScrapItem", function(location)
        local bag, slot = location:GetBagAndSlot()
        return bag == 0 and slot == 1
      end)
      local asked = 0
      local getItemSpell = _G.C_Item.GetItemSpell
      override(_G.C_Item, "GetItemSpell", function(l)
        asked = asked + 1
        return getItemSpell(l)
      end)
      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 }, { itemID = 202, guid = "guid-202", count = 1 } }
      local slotInfo = refreshBackpack()
      local sword = slotInfo.itemsBySlotKey["0_1"].itemInfo.traits
      assert.is_true(sword.isEquipment)
      assert.is_true(sword.isScrappable)
      assert.are.equal(10, sword.sellPrice)
      assert.are.same({ ["0_1"] = true }, search:Search("equipment = true AND scrappable = true"))
      assert.are.same({ ["0_2"] = true }, search:Search("hasuse = true"))
      searchCategories({ { "Usable", "hasuse = true AND price = 10" } })
      slotInfo = refreshBackpack({ derive = true })
      assert.equal("Usable", categoryOf(slotInfo, "0_2"))
      asked = 0
      refreshBackpack({ bags = { [0] = true } })
      assert.are.equal(0, asked, "a kept slot keeps its traits")
    end)

    -- How many of the item the kind's bags hold, by item ID (Vendor's TotalItemCount). A slot that
    -- changes changes the total of the kept items of the same item, which are re-indexed.
    it("counts each item across the bags, and keeps a kept item's total current", function()
      mockContainer[0] = { { itemID = 101, guid = "a", count = 5 }, { itemID = 101, guid = "b", count = 7 },
        { itemID = 202, guid = "c", count = 1 } }
      local slotInfo = refreshBackpack()
      assert.are.equal(12, slotInfo.itemsBySlotKey["0_1"].itemTotal)
      assert.are.equal(1, slotInfo.itemsBySlotKey["0_3"].itemTotal)
      assert.are.same({ ["0_1"] = true, ["0_2"] = true }, search:Search("total = 12"))
      mockContainer[1] = { { itemID = 101, guid = "d", count = 3 } }
      local kept = slotInfo.itemsBySlotKey["0_1"]
      slotInfo = refreshBackpack({ bags = { [1] = true } })
      assert.are.equal(kept, slotInfo.itemsBySlotKey["0_1"], "bag 0 was not read")
      assert.are.same({ ["0_1"] = true, ["0_2"] = true, ["1_1"] = true }, search:Search("total = 15"))
      assert.are.same({}, search:Search("total = 12"))
    end)

    -- usable follows the character (skills, level, spec): a kept item is asked again each sweep.
    it("asks whether the character can use each item, again on a kept item, never cold", function()
      local can = { [101] = true, [202] = false }
      local asked = 0
      override(_G, "C_PlayerInfo", { CanUseItem = function(id)
        asked = asked + 1
        return can[id]
      end })
      override(_G.C_Item, "IsEquippableItem", function(l) return tostring(l):find("item:101", 1, true) ~= nil end)
      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 }, { itemID = 202, guid = "guid-202", count = 1 } }
      local slotInfo = refreshBackpack()
      assert.is_true(slotInfo.itemsBySlotKey["0_1"].isUsable)
      assert.are.same({ ["0_1"] = true }, search:Search("usable = true"))
      assert.are.same({ ["0_1"] = true }, search:Search("equippable = true"))
      can[202] = true
      local kept = slotInfo.itemsBySlotKey["0_2"]
      -- A recalculation that changes no category: only the answer re-indexes the item.
      slotInfo = refreshBackpack({ derive = true, categoriesUnchanged = true })
      assert.are.equal(kept, slotInfo.itemsBySlotKey["0_2"])
      assert.are.same({ ["0_1"] = true, ["0_2"] = true }, search:Search("usable = true"))
      local getItemInfo = _G.C_Item.GetItemInfo
      override(_G.C_Item, "GetItemInfo", function() return nil end)
      mockContainer[0][3] = { itemID = 303, guid = "guid-303", count = 1 }
      asked = 0
      slotInfo = refreshBackpack({ bags = { [0] = true } })
      assert.is_nil(slotInfo.itemsBySlotKey["0_3"].isUsable, "not asked before the item's data loaded")
      override(_G.C_Item, "GetItemInfo", getItemInfo)
    end)

    -- Pet counts follow the account. Nothing is asked before the pet journal has loaded (a login
    -- capture: 0 owned until PET_JOURNAL_LIST_UPDATE); the journal's events recalculate the bags
    -- holding a pet item whose counts changed, and nothing else.
    describe("pet counts", function()
      local registered, sent, owned, journal

      before_each(function()
        registered, sent, owned = {}, {}, { [635] = 1 }
        -- Before the journal has loaded, a login capture had GetNumPets answer 0 owned.
        journal = { total = 2014, owned = 0 }
        override(events, "RegisterEvent", function(_, name, cb) registered[name] = cb end)
        override(events, "BucketEvent", function() end)
        local send = events.SendMessage
        override(events, "SendMessage", function(self, ctx, event, ...)
          if event == "bags/Rederive" then table.insert(sent, (...)) end
          return send(self, ctx, event, ...)
        end)
        override(_G, "C_PetJournal", {
          GetPetInfoByItemID = function(id)
            if id == 101 then return "Adder", 1, 1, 1, "", "", false, true, true, false, true, 1, 635 end
          end,
          GetNumCollectedInfo = function(species) return owned[species] or 0, 3 end,
          GetNumPets = function() return journal.total, journal.owned end,
        })
        items._petJournalLoaded = false
        items:RegisterCacheEvents()
        mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 }, { itemID = 202, guid = "guid-202", count = 1 } }
      end)

      after_each(function()
        items._petJournalLoaded = false
      end)

      it("listens to the pet journal's events", function()
        for _, name in ipairs({ "PET_JOURNAL_LIST_UPDATE", "NEW_PET_ADDED", "PET_JOURNAL_PET_DELETED",
          "PET_JOURNAL_PET_RESTORED" }) do
          assert.is_function(registered[name], name)
        end
      end)

      it("has no counts before the journal has loaded, then recalculates the bag with the pet", function()
        local slotInfo = refreshBackpack()
        assert.is_nil(slotInfo.itemsBySlotKey["0_1"].petOwned)
        assert.are.same({}, search:Search("collectable = true"))
        registered.PET_JOURNAL_LIST_UPDATE(context:New("evt"), "PET_JOURNAL_LIST_UPDATE")
        assert.are.same({ { backpack = true, bank = false, guild = false } }, sent)
        slotInfo = refreshBackpack({ derive = true })
        assert.are.equal(1, slotInfo.itemsBySlotKey["0_1"].petOwned)
        assert.are.same({ ["0_1"] = true }, search:Search("collectable = true"))
        assert.are.same({ ["0_1"] = true }, search:Search("petcount = 1"))
      end)

      it("recalculates when a pet is learned, and not when nothing changed", function()
        registered.PET_JOURNAL_LIST_UPDATE(context:New("evt"), "PET_JOURNAL_LIST_UPDATE")
        refreshBackpack()
        sent = {}
        registered.PET_JOURNAL_LIST_UPDATE(context:New("evt"), "PET_JOURNAL_LIST_UPDATE")
        sent = {}
        registered.PET_JOURNAL_LIST_UPDATE(context:New("evt"), "PET_JOURNAL_LIST_UPDATE")
        assert.are.same({}, sent, "the counts did not change")
        owned[635] = 3
        registered.NEW_PET_ADDED(context:New("evt"), "NEW_PET_ADDED", "BattlePet-0-1")
        assert.are.equal(1, #sent)
        refreshBackpack({ derive = true, categoriesUnchanged = true })
        assert.are.same({}, search:Search("collectable = true"))
        assert.are.same({ ["0_1"] = true }, search:Search("petcount = 3"))
      end)

      -- A /reload capture: the journal answered 234 owned from the first sample, and its event came
      -- 59 ms after the first bag read had started.
      it("knows the counts at once when the account already owns pets (a /reload)", function()
        journal.owned = 234
        local slotInfo = refreshBackpack()
        assert.are.equal(1, slotInfo.itemsBySlotKey["0_1"].petOwned)
      end)

      -- The journal's first event can come while a read is under way, before anything is committed:
      -- the bags are recalculated anyway (the request waits for the read).
      it("recalculates the bags when the journal first loads, even with nothing committed yet", function()
        registered.PET_JOURNAL_LIST_UPDATE(context:New("evt"), "PET_JOURNAL_LIST_UPDATE")
        assert.are.same({ { backpack = true, bank = false, guild = false } }, sent)
      end)

      it("recalculates when only the limit changed", function()
        registered.PET_JOURNAL_LIST_UPDATE(context:New("evt"), "PET_JOURNAL_LIST_UPDATE")
        refreshBackpack()
        registered.PET_JOURNAL_LIST_UPDATE(context:New("evt"), "PET_JOURNAL_LIST_UPDATE")
        sent = {}
        override(_G.C_PetJournal, "GetNumCollectedInfo", function(species) return owned[species] or 0, 5 end)
        registered.PET_JOURNAL_LIST_UPDATE(context:New("evt"), "PET_JOURNAL_LIST_UPDATE")
        assert.are.equal(1, #sent)
      end)

      -- Opening the bank reads it, so a closed bank's pets are not recalculated.
      it("recalculates the bank only while it is open", function()
        local bank = const.BAG_KIND.BANK
        local saved = { items.slotInfo[bank], addon.atBank }
        local pet = { bagid = 6, slotid = 1, isItemEmpty = false, petOwned = 0, petLimit = 3,
          itemInfo = { itemID = 101, traits = { isPet = true, petSpeciesID = 635, stats = {} } } }
        items.slotInfo[bank] = { itemsBySlotKey = { ["6_1"] = pet } }
        addon.atBank = false
        items._petJournalLoaded = true
        registered.PET_JOURNAL_LIST_UPDATE(context:New("evt"), "PET_JOURNAL_LIST_UPDATE")
        local closed = sent
        sent = {}
        addon.atBank = true
        registered.PET_JOURNAL_LIST_UPDATE(context:New("evt"), "PET_JOURNAL_LIST_UPDATE")
        items.slotInfo[bank], addon.atBank = saved[1], saved[2]
        assert.are.same({}, closed)
        assert.are.same({ { backpack = false, bank = true, guild = false } }, sent)
      end)

      it("reads the counts of a pet item read after the journal loaded", function()
        registered.PET_JOURNAL_LIST_UPDATE(context:New("evt"), "PET_JOURNAL_LIST_UPDATE")
        local slotInfo = refreshBackpack()
        assert.are.same({ 1, 3 }, { slotInfo.itemsBySlotKey["0_1"].petOwned, slotInfo.itemsBySlotKey["0_1"].petLimit })
        assert.is_nil(slotInfo.itemsBySlotKey["0_2"].petOwned, "not a pet")
      end)
    end)

    -- A login capture (retail 12.1.5): C_PlayerInfo.CanUseItem answered false for all 30 backpack
    -- items at the end of the loading screen, false for 6 after the first SPELLS_CHANGED, and true
    -- for all after the second, about 2.2 s later; the first bag read came 0.23 to 0.3 s after it in
    -- every login captured. Spells and reputations change the answers, so committed items are asked
    -- again when they change, and the bags where an answer changed are recalculated.
    describe("usability that changes with spells and reputations", function()
      local buckets, sent, can

      before_each(function()
        buckets, sent, can = {}, {}, { [101] = false, [202] = false }
        override(events, "RegisterEvent", function() end)
        override(events, "BucketEvent", function(_, name, cb) buckets[name] = cb end)
        local send = events.SendMessage
        override(events, "SendMessage", function(self, ctx, event, ...)
          if event == "bags/Rederive" then table.insert(sent, (...)) end
          return send(self, ctx, event, ...)
        end)
        override(_G, "C_PlayerInfo", { CanUseItem = function(id) return can[id] == true end })
        items:RegisterCacheEvents()
        mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 }, { itemID = 202, guid = "guid-202", count = 1 } }
      end)

      it("listens to spells, reputations and the appearance collection, bucketed", function()
        for _, name in ipairs({ "SPELLS_CHANGED", "UPDATE_FACTION", "TRANSMOG_COLLECTION_UPDATED",
          "TRANSMOG_COLLECTION_SOURCE_ADDED", "TRANSMOG_COLLECTION_SOURCE_REMOVED" }) do
          assert.is_function(buckets[name], name)
        end
      end)

      it("recalculates the bags when an appearance is collected, and keeps the search current", function()
        local collected = false
        override(_G, "C_TransmogCollection", {
          GetItemInfo = function(l) if tostring(l):find("item:101", 1, true) then return 1001, 2002 end end,
          GetCategoryCollectedCount = function(category) return category == 1 and 100 or 0 end,
          PlayerHasTransmogItemModifiedAppearance = function() return collected end,
          GetAppearanceSources = function() return {} end,
          PlayerHasTransmogByItemInfo = function() return false end,
          PlayerHasTransmog = function() return false end,
        })
        items._appearancesLoaded = false
        refreshBackpack()
        assert.are.same({ ["0_1"] = true }, search:Search("appearance = unknown"))
        assert.are.same({ ["0_1"] = true }, search:Search("source = unknown"))
        collected = true
        buckets.TRANSMOG_COLLECTION_SOURCE_ADDED(context:New("evt"), {})
        assert.are.equal(1, #sent)
        refreshBackpack({ derive = true, categoriesUnchanged = true })
        assert.are.same({ ["0_1"] = true }, search:Search("appearance = known"))
        assert.are.same({ ["0_1"] = true }, search:Search("source = known"))
        items._appearancesLoaded = false
      end)

      it("recalculates the bags when an answer changed, and keeps the search current", function()
        refreshBackpack()
        assert.are.same({}, search:Search("usable = true"))
        can[101], can[202] = true, true
        buckets.SPELLS_CHANGED(context:New("evt"), {})
        assert.are.same({ { backpack = true, bank = false, guild = false } }, sent)
        refreshBackpack({ derive = true, categoriesUnchanged = true })
        assert.are.same({ ["0_1"] = true, ["0_2"] = true }, search:Search("usable = true"))
      end)

      it("does nothing when no answer changed", function()
        refreshBackpack()
        buckets.UPDATE_FACTION(context:New("evt"), {})
        assert.are.same({}, sent)
      end)
    end)

    it("gives every item the plain name of its bag, for the bagname field", function()
      override(_G.C_Container, "GetBagName", function(bagid)
        return ({ [0] = "Backpack", [1] = "Herb Satchel" })[bagid]
      end)
      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 } }
      mockContainer[1] = { { itemID = 202, guid = "guid-202", count = 1 } }
      local slotInfo = refreshBackpack()
      assert.are.equal("Backpack", slotInfo.itemsBySlotKey["0_1"].bagName)
      assert.are.equal("Herb Satchel", slotInfo.itemsBySlotKey["1_1"].bagName)
      assert.are.same({ ["1_1"] = true }, search:Search("bag = herb"))
      searchCategories({ { "Herbs", "bagname = herb satchel" } })
      slotInfo = refreshBackpack({ derive = true })
      assert.equal("Herbs", categoryOf(slotInfo, "1_1"))
    end)

    -- A rule that is only a negation (docs/vendor-compat.md): it matched nothing before.
    it("puts every item a NOT rule does not exclude in its category", function()
      searchCategories({ { "Not Alpha", "NOT alpha" } })
      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 }, { itemID = 202, guid = "guid-202", count = 1 } }
      local slotInfo = refreshBackpack()
      assert.are_not.equal("Not Alpha", categoryOf(slotInfo, "0_1"))
      assert.equal("Not Alpha", categoryOf(slotInfo, "0_2"))
    end)

    -- A != covers the items indexed in this sweep. It used to read the bags' committed items,
    -- the previous sweep's while a sweep runs, so a looted item missed it for one sweep.
    it("matches an item arriving in a sweep against a != rule in that sweep", function()
      searchCategories({ { "Not Alpha", "name != alpha" } })
      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 } }
      refreshBackpack()
      mockContainer[0][2] = { itemID = 303, guid = "guid-303", count = 1 }
      local slotInfo = refreshBackpack()
      assert.equal("Not Alpha", categoryOf(slotInfo, "0_2"))
      assert.are_not.equal("Not Alpha", categoryOf(slotInfo, "0_1"))
    end)

    it("still lets the search box find items by the search category they are in", function()
      searchCategories({ { "Alpha Items", "alpha" } })
      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 }, { itemID = 202, guid = "guid-202", count = 1 } }
      searchText = "alpha items"
      local slotInfo = refreshBackpack()
      assert.is_true(slotInfo.itemsBySlotKey["0_1"].isSearchResult, "found by the category it is in")
      assert.is_false(slotInfo.itemsBySlotKey["0_2"].isSearchResult)
      assert.is_true(search:Search("alpha items")["0_1"], "between sweeps too")
    end)
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
      local saved = { search.indicies, search.indexLookup, search.indexed, search.indexedItems }
      search:Init()
      local all = {}
      for _, kind in ipairs({ const.BAG_KIND.BACKPACK, const.BAG_KIND.BANK }) do
        for slotkey, it in pairs(items.slotInfo[kind].itemsBySlotKey or {}) do all[slotkey] = it end
      end
      search:IndexItems(all)
      local state = indexState()
      search.indicies, search.indexLookup, search.indexed, search.indexedItems = saved[1], saved[2], saved[3], saved[4]
      return state
    end
    local function refreshBank(wipe)
      local ctx = context:New("refresh-bank")
      if wipe then ctx:Set("wipe", true) end
      items:RefreshBank(ctx)
    end

    it("equals a clean rebuild after sweeps with a search category in play", function()
      override(categories, "GetCustomCategory", function() return nil, nil end)
      override(categories, "GetSortedSearchCategories", function()
        return { { name = "Alpha Items", priority = 10, enabled = { [const.BAG_KIND.BACKPACK] = true, [const.BAG_KIND.BANK] = true },
          searchCategory = { query = "alpha", groupBy = const.SEARCH_CATEGORY_GROUP_BY.NONE } } }
      end)
      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 }, { itemID = 202, guid = "guid-202", count = 1 } }
      mockContainer[6] = { { itemID = 303, guid = "guid-303", count = 1 } }
      refreshBank()
      refreshBackpack({ wipe = true })
      assert.are.same(cleanState(), indexState(), "after a wipe")
      mockContainer[0] = { { itemID = 202, guid = "guid-202", count = 1 }, { itemID = 101, guid = "guid-101", count = 1 } }
      refreshBackpack()
      assert.are.same(cleanState(), indexState(), "after a swap")
      refreshBackpack({ derive = true })
      assert.are.same(cleanState(), indexState(), "after a recalculation")
    end)

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

  -- A virtual stack shows one icon for every pile of an item, and that icon sits in one section.
  -- Reported: a stack being looted into "gets drawn up to Recent Items, then back to its category,
  -- ping pong, if you keep looting the item". The stack's section came from its root pile alone,
  -- the pile holding the most, so it moved whenever looting made a different pile the largest. A
  -- stack is in Recent Items while any pile it merges is recent.
  describe("virtual stacks and Recent Items", function()
    local ORE = 2771
    local BACKPACK = 0

    local function stacking(opts)
      override(database, "GetStackingOptions", function()
        local o = { mergeStacks = true, mergeUnstackable = true, unmergeAtShop = false,
          dontMergePartial = false, dontMergeTransmog = false }
        for k, v in pairs(opts or {}) do o[k] = v end
        return o
      end)
    end

    before_each(function()
      override(database, "GetCategoryFilter", function(_, _, filter) return filter == "RecentItems" end)
      stacking()
    end)

    -- shown lists, for every icon of the item, its section and the count it shows.
    local function shown(itemID)
      local out = {}
      for _, item in pairs(items.slotInfo[BACKPACK]:GetVisibleItems()) do
        if not item.isItemEmpty and item.itemInfo.itemID == itemID then
          table.insert(out, item.itemInfo.category .. ":" .. tostring(item.stackedCount or item.itemInfo.currentItemCount))
        end
      end
      table.sort(out)
      return table.concat(out, ",")
    end

    local function bag(slots)
      mockContainer[0] = {}
      for i = 1, 8 do mockContainer[0][i] = slots[i] or {} end
    end

    -- loot adds count of the item to a pile, as the client does, then reads the bag.
    local function loot(slot, count, guid)
      local pile = mockContainer[0][slot]
      if pile.itemID then
        pile.count = pile.count + count
      else
        mockContainer[0][slot] = { itemID = ORE, guid = guid, count = count }
        newSlots["0_" .. slot] = true
      end
      refreshBackpack({ bags = { [0] = true } })
      return shown(ORE)
    end

    -- The item stacks to 20 (the GetItemInfo mock).
    it("stays in Recent Items while a pile it merges is recent, whichever pile is largest", function()
      bag({ [3] = { itemID = ORE, guid = "ore-old", count = 12 } })
      refreshBackpack({ wipe = true })
      assert.equal("Everything:12", shown(ORE))
      assert.equal("Recent Items:27", loot(5, 15, "ore-new"), "a new pile, larger than the old one")
      assert.equal("Recent Items:33", loot(3, 6), "the old pile tops up and is largest again")
      assert.equal("Recent Items:35", loot(5, 2), "the two tie")
      assert.equal("Recent Items:40", loot(3, 2) and loot(5, 3), "both full")
      assert.equal("Recent Items:45", loot(6, 5, "ore-third"), "a third pile")
    end)

    it("stays in Recent Items when a recent partial pile fills and merges (Merge Partial off)", function()
      stacking({ dontMergePartial = true })
      bag({ [3] = { itemID = ORE, guid = "ore-old", count = 20 } })
      refreshBackpack({ wipe = true })
      assert.equal("Everything:20", shown(ORE))
      assert.equal("Everything:20,Recent Items:15", loot(5, 15, "ore-new"), "the partial pile apart")
      assert.equal("Recent Items:40", loot(5, 5), "full: it merges, and the stack is recent")
      assert.equal("Recent Items:3,Recent Items:40", loot(6, 3, "ore-third"))
    end)

    -- The same with the new pile in an earlier slot: two full piles tie, and the root was the old
    -- pile, whose slot key is greater.
    it("stays in Recent Items when a recent pile in an earlier slot fills and merges", function()
      stacking({ dontMergePartial = true })
      bag({ [6] = { itemID = ORE, guid = "ore-old", count = 20 } })
      refreshBackpack({ wipe = true })
      assert.equal("Everything:20,Recent Items:15", loot(2, 15, "ore-new"))
      assert.equal("Recent Items:40", loot(2, 5), "full: it merges, and the stack is recent")
    end)

    it("goes back to its category once no pile it merges is recent", function()
      bag({ [3] = { itemID = ORE, guid = "ore-old", count = 18 }, [5] = { itemID = ORE, guid = "ore-new", count = 2 } })
      newSlots["0_5"] = true
      refreshBackpack({ wipe = true })
      refreshBackpack({ bags = { [0] = true } })
      assert.equal("Recent Items:20", shown(ORE))
      mockContainer[0][5] = {}
      refreshBackpack({ bags = { [0] = true } })
      assert.equal("Everything:18", shown(ORE), "the recent pile was used up")
    end)

    it("shows the same section and count however the piles are read", function()
      bag({ [3] = { itemID = ORE, guid = "ore-old", count = 12 } })
      refreshBackpack({ wipe = true })
      loot(5, 15, "ore-new")
      loot(3, 6)
      local targeted = shown(ORE)
      refreshBackpack()
      assert.equal(targeted, shown(ORE), "a read of every bag")
      refreshBackpack({ derive = true })
      assert.equal(targeted, shown(ORE), "a recalculation")
    end)
  end)

  -- A refresh recalculates only what changed (data-loader.md §18). An item's category, upgrade
  -- arrow and grey-out are kept with it, and computed again only when the item is read anew, when an
  -- input of its own changes (recency, tooltip text, gear sets, quest state), or when an input every
  -- item shares changes: category settings and definitions (a recalculation that does not say
  -- categoriesUnchanged, or the categories module's generation), the item context, the upgrade
  -- generation. A captured bank open spent 1.35 s asking Pawn about items it had already asked about.
  describe("deriving only what changed", function()
    local BACKPACK, BANK = 0, 1
    local asked, contextAsked, customAsked, categoryAsked, added
    local itemContext, gear, catGen, customOf, tooltipOf, setsOf, searchCats, stackOpts, questOf, allowedInWarbank

    -- A pile of an item, with a link in the client's format (ParseItemLink reads the item ID from
    -- it, so different items hash apart).
    local function pile(id, guid, count)
      return { itemID = id, guid = guid, count = count,
        link = "|cnIQ1:|Hitem:" .. id .. ":0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:::|h[TestItem " .. id .. "]|h|r" }
    end

    local function distinct(list)
      local seen, out = {}, {}
      for _, v in ipairs(list) do
        if not seen[v] then
          seen[v] = true
          out[#out + 1] = v
        end
      end
      table.sort(out)
      return out
    end

    local function reset()
      asked, contextAsked, customAsked, categoryAsked, added = {}, {}, {}, {}, {}
    end

    local function refreshBank(opts)
      local ctx = context:New("refresh-bank")
      if opts and opts.wipe then ctx:Set("wipe", true) end
      if opts and opts.derive then ctx:Set("derive", true) end
      if opts and opts.categoriesUnchanged then ctx:Set("categoriesUnchanged", true) end
      items:RefreshBank(ctx)
    end

    before_each(function()
      override(database, "GetCategoryFilter", function(_, _, filter) return filter == "RecentItems" end)
      reset()
      gear, catGen, itemContext = 1, 1, nil
      customOf, tooltipOf, setsOf, searchCats, questOf = {}, {}, {}, {}, {}
      saveGlobal(_G.C_Container, "GetContainerItemQuestInfo")
      _G.C_Container.GetContainerItemQuestInfo = function(bagid, slotid)
        return questOf[bagid .. "_" .. slotid] or { isQuestItem = false, isActive = false }
      end
      -- The Warbank (bag 13 here) and whether it takes an item (C_Bank.IsItemAllowedInBankType): a
      -- property of the item, so every pile of an item answers alike (binding reads it too).
      override(_G.Enum.BagIndex, "AccountBankTab_1", 13)
      allowedInWarbank = function(itemID) return itemID % 2 == 0 end
      saveGlobal(_G, "C_Bank")
      _G.C_Bank = { IsItemAllowedInBankType = function(_, location)
        local bagid, slotid = location:GetBagAndSlot()
        local itemID = _G.C_Container.GetContainerItemID(bagid, slotid)
        return itemID ~= nil and allowedInWarbank(itemID)
      end }
      stackOpts = { mergeStacks = true, mergeUnstackable = true, unmergeAtShop = false,
        dontMergePartial = false, dontMergeTransmog = false }
      override(database, "GetStackingOptions", function() return stackOpts end)
      items:RegisterUpgradeProvider("Counted", function(data)
        asked[#asked + 1] = data.slotkey
        return (data.itemInfo.itemID + gear) % 2 == 0
      end, { cacheable = true })
      override(database, "GetUpgradeIconProvider", function() return "Counted" end)
      override(database, "GetUpgradeIconProviderUserSet", function() return true end)
      saveGlobal(_G, "ItemButtonUtil")
      _G.ItemButtonUtil = {
        ItemContextMatchResult = { Match = 1, Mismatch = 2, DoesNotApply = 0 },
        GetItemContext = function() return itemContext end,
        GetItemContextMatchResultForItem = function(location)
          local bagid, slotid = location:GetBagAndSlot()
          contextAsked[#contextAsked + 1] = bagid .. "_" .. slotid
          if itemContext == nil then return 0 end
          return (slotid + #itemContext) % 2 == 0 and 1 or 2
        end,
      }
      override(categories, "GetGeneration", function() return catGen end)
      override(categories, "GetCustomCategory", function(_, _, _, data)
        customAsked[#customAsked + 1] = data.slotkey
        local name = customOf[data.itemInfo.itemID]
        if name then return name, 10 end
        return nil, nil
      end)
      override(categories, "GetSortedSearchCategories", function()
        local out = {}
        for _, c in ipairs(searchCats) do
          table.insert(out, { name = c[1], priority = c[3] or 10,
            enabled = { [BACKPACK] = true, [BANK] = true },
            searchCategory = { query = c[2], groupBy = const.SEARCH_CATEGORY_GROUP_BY.NONE } })
        end
        return out
      end)
      local tooltipScanner = addon:GetModule("TooltipScanner")
      override(tooltipScanner, "GetTooltipText", function(_, bagid, slotid)
        return tooltipOf[bagid .. "_" .. slotid] or ""
      end)
      local equipmentSets = addon:GetModule("EquipmentSets")
      override(equipmentSets, "GetItemSets", function(_, bagid, slotid)
        return setsOf[bagid .. "_" .. slotid]
      end)
      local add = search.Add
      override(search, "Add", function(self, it)
        added[#added + 1] = it.slotkey
        return add(self, it)
      end)
      local getCategory = items.GetCategory
      override(items, "GetCategory", function(self, ctx, data, ...)
        if data and not data.isItemEmpty then categoryAsked[#categoryAsked + 1] = data.slotkey end
        return getCategory(self, ctx, data, ...)
      end)
    end)

    local function threeItems()
      mockContainer[0] = {
        pile(101, "g101", 1),
        pile(202, "g202", 5),
        pile(303, "g303", 1),
        {},
      }
      refreshBackpack({ wipe = true })
      reset()
    end

    it("asks the upgrade provider only about items a read finds changed", function()
      threeItems()
      mockContainer[0][4] = pile(404, "g404", 1)
      refreshBackpack({ bags = { [0] = true } })
      assert.are.same({ "0_4" }, distinct(asked), "the new item")
      reset()
      mockContainer[0][2].count = 6
      refreshBackpack({ bags = { [0] = true } })
      assert.are.same({ "0_2" }, distinct(asked), "the stack that grew")
      reset()
      refreshBackpack({ derive = true, categoriesUnchanged = true })
      assert.are.same({}, asked, "a recalculation of something else")
      items:InvalidateUpgrades(false)
      refreshBackpack({ bags = { [0] = true } })
      assert.are.same({ "0_1", "0_2", "0_3", "0_4" }, distinct(asked), "every item after the gear changed")
    end)

    it("recalculates an item's category only when the item or one of its inputs changes", function()
      threeItems()
      mockContainer[0][4] = pile(404, "g404", 1)
      refreshBackpack({ bags = { [0] = true } })
      assert.are.same({ "0_4" }, distinct(customAsked), "the new item")
      reset()
      refreshBackpack({ derive = true, categoriesUnchanged = true })
      assert.are.same({}, customAsked, "nothing changed")
      newSlots["0_1"] = true
      refreshBackpack({ bags = { [0] = true } })
      -- Its category without Recent Items is unchanged (data-loader.md §18, base): only recency picks.
      assert.are.same({}, distinct(categoryAsked), "nothing asked for the item that became recent")
      assert.equal("Recent Items", items.slotInfo[BACKPACK].itemsBySlotKey["0_1"].itemInfo.category)
      reset()
      tooltipOf["0_3"] = "shiny"
      refreshBackpack({ derive = true, categoriesUnchanged = true })
      assert.are.same({ "0_3" }, distinct(customAsked), "the item whose tooltip changed")
      reset()
      catGen = catGen + 1
      customOf[202] = "Gems"
      refreshBackpack({ bags = { [0] = true } })
      assert.are.same({ "0_1", "0_2", "0_3", "0_4" }, distinct(categoryAsked), "every item once a category changed")
      assert.equal("Gems", items.slotInfo[BACKPACK].itemsBySlotKey["0_2"].itemInfo.category)
      reset()
      refreshBackpack({ derive = true })
      assert.are.same({ "0_1", "0_2", "0_3", "0_4" }, distinct(categoryAsked), "a recalculation that may change them")
    end)

    it("works grey-out out again only when the item context changes", function()
      threeItems()
      mockContainer[0][4] = pile(404, "g404", 1)
      refreshBackpack({ bags = { [0] = true } })
      assert.are.same({ "0_4" }, distinct(contextAsked))
      reset()
      refreshBackpack({ derive = true, categoriesUnchanged = true })
      assert.are.same({}, contextAsked)
      itemContext = "Scrapping"
      refreshBackpack({ derive = true, categoriesUnchanged = true })
      assert.are.same({ "0_1", "0_2", "0_3", "0_4" }, distinct(contextAsked), "a vendor or scrapper opened")
      -- The mock matches slots whose number plus the context's length is even.
      assert.equal(1, items.slotInfo[BACKPACK].itemsBySlotKey["0_1"].itemContextMatchResult)
      assert.equal(2, items.slotInfo[BACKPACK].itemsBySlotKey["0_2"].itemContextMatchResult)
      -- While a context is active Blizzard's answer can depend on more than the context: the spell
      -- being cast for Enchanting, CheckItemCondition, ReplaceBonusTree, JumpUpgradeTrack
      -- (ItemButtonUtil.GetItemContextMatchResultForItem). So every refresh works it out.
      reset()
      refreshBackpack({ derive = true, categoriesUnchanged = true })
      assert.are.same({ "0_1", "0_2", "0_3", "0_4" }, distinct(contextAsked), "while a context is active")
      itemContext = nil
      refreshBackpack({ derive = true, categoriesUnchanged = true })
      reset()
      refreshBackpack({ derive = true, categoriesUnchanged = true })
      assert.are.same({}, contextAsked, "no context")
      addon.atBank = true
      refreshBackpack({ bags = { [0] = true } })
      assert.are.same({ "0_1", "0_2", "0_3", "0_4" }, distinct(contextAsked), "the bank opened")
    end)

    -- At the bank, the backpack is greyed out by what the shown bank takes: the Warbank takes fewer
    -- items than the character bank (ResolveItemContextMatchResult).
    it("works grey-out out again when the bank shows the Warbank instead of the character bank", function()
      threeItems()
      addon.atBank = true
      addon.Bags = { Bank = { bankTab = 6 } }
      refreshBackpack({ derive = true, categoriesUnchanged = true })
      local slot1 = function() return items.slotInfo[BACKPACK].itemsBySlotKey["0_1"].itemContextMatchResult end
      assert.equal(0, slot1(), "the character bank takes everything")
      addon.Bags.Bank.bankTab = 13
      refreshBackpack({ derive = true, categoriesUnchanged = true })
      assert.equal(2, slot1(), "the Warbank does not take it")
      addon.Bags.Bank.bankTab = 6
      refreshBackpack({ derive = true, categoriesUnchanged = true })
      assert.equal(0, slot1())
    end)

    -- Search categories match an item's own category, which leaves Recent Items out (data-loader.md
    -- §8): a rule on "recent items" never takes an item, and an item shows in Recent Items while it is
    -- recent and in its category once it is not, its own recency and its stack's.
    describe("an own category that follows recency", function()
      before_each(function()
        searchCats = { { "Was Recent", 'category = "recent items"', 1 } }
      end)

      local function categoryOf(slotkey)
        return items.slotInfo[BACKPACK].itemsBySlotKey[slotkey].itemInfo.category
      end

      it("lets an item go once it is no longer recent", function()
        threeItems()
        newSlots["0_1"] = true
        refreshBackpack({ bags = { [0] = true } })
        assert.equal("Recent Items", categoryOf("0_1"))
        for guid in pairs(items._newItemTimers[BACKPACK]) do items._newItemTimers[BACKPACK][guid] = 0 end
        newSlots["0_1"] = nil
        items:ExpireRecentItems(BACKPACK)
        refreshBackpack({ derive = true, categoriesUnchanged = true })
        assert.equal("Everything", categoryOf("0_1"))
      end)

      it("lets a stack go once no pile it merges is recent", function()
        mockContainer[0] = { pile(101, "old", 15), {}, {} }
        refreshBackpack({ wipe = true })
        mockContainer[0][2] = pile(101, "new", 3)
        newSlots["0_2"] = true
        refreshBackpack({ bags = { [0] = true } })
        assert.equal("Recent Items", categoryOf("0_1"), "the stack shows the recent pile")
        catGen = catGen + 1
        refreshBackpack({ derive = true })
        mockContainer[0][2] = {}
        refreshBackpack({ bags = { [0] = true } })
        assert.equal("Everything", categoryOf("0_1"))
      end)
    end)

    -- A stack is recent while a pile it merges is (stackRecent); the largest pile shows it. Once
    -- stacking is off every pile shows its own.
    it("shows a pile's own category once stacking stops merging it", function()
      mockContainer[0] = { pile(101, "old", 15), pile(101, "new", 3), {} }
      refreshBackpack({ wipe = true })
      newSlots["0_2"] = true
      refreshBackpack({ bags = { [0] = true } })
      assert.equal("Recent Items", items.slotInfo[BACKPACK].itemsBySlotKey["0_1"].itemInfo.category)
      stackOpts.mergeStacks = false
      refreshBackpack({ derive = true, resetLayout = true })
      assert.equal("Everything", items.slotInfo[BACKPACK].itemsBySlotKey["0_1"].itemInfo.category)
      assert.equal("Recent Items", items.slotInfo[BACKPACK].itemsBySlotKey["0_2"].itemInfo.category)
    end)

    -- Every input of the category an item is shown in is recorded, the search category included:
    -- in the game a change of search categories also starts a new categories generation, which
    -- works everything out again; the record does not rely on it.
    it("works an item's shown category out again when its search category changes", function()
      searchCats = { { "Shiny", "alpha", 10 } }
      threeItems()
      assert.equal("Shiny", items.slotInfo[BACKPACK].itemsBySlotKey["0_1"].itemInfo.category)
      searchCats = { { "Swords", "alpha", 10 } }
      refreshBackpack({ derive = true, categoriesUnchanged = true })
      assert.equal("Swords", items.slotInfo[BACKPACK].itemsBySlotKey["0_1"].itemInfo.category)
    end)

    -- A sweep can fail after it indexed its items and before it committed them: the index then
    -- holds items the bag never got. The other bag's next sweep brings the index back to the
    -- committed items (search:SyncKind compares an item that is not the object its slot was
    -- indexed from).
    it("brings the index back to the committed items after a sweep failed before committing", function()
      threeItems()
      mockContainer[6] = { pile(505, "g505", 1) }
      refreshBank()
      local partition = items.Phase10_PartitionIntoTabs
      override(items, "Phase10_PartitionIntoTabs", function() error("spec: fails after indexing") end)
      mockContainer[0][2] = pile(606, "g606", 1)
      pcall(refreshBackpack, { bags = { [0] = true } })
      override(items, "Phase10_PartitionIntoTabs", partition)
      assert.is_true(search:isInIndex("id", 606)["0_2"], "the failed sweep indexed its item")
      refreshBank()
      assert.is_nil(search:isInIndex("id", 606)["0_2"])
      assert.is_true(search:isInIndex("id", 202)["0_2"], "the item the bag still has")
    end)

    -- A sweep can also fail after it worked an item out again (Phase 6) and before it indexed it
    -- (Phase 8). The item is the committed object, so nothing in the next sweep looks changed; it
    -- must still be indexed with what it holds now.
    it("indexes an item worked out by a sweep that failed before indexing it", function()
      threeItems()
      local stacks = items.Phase7_ApplyVirtualStacks
      override(items, "Phase7_ApplyVirtualStacks", function() error("spec: fails before indexing") end)
      tooltipOf["0_3"] = "Use: sharpens a blade"
      pcall(refreshBackpack, { derive = true, categoriesUnchanged = true })
      override(items, "Phase7_ApplyVirtualStacks", stacks)
      assert.is_nil(search:Search("sharpens")["0_3"])
      refreshBackpack({ derive = true, categoriesUnchanged = true })
      assert.is_true(search:Search("sharpens")["0_3"])
      for slotkey, it in pairs(items.slotInfo[BACKPACK].itemsBySlotKey) do
        assert.is_nil(it.derived and it.derived.indexPending, slotkey .. " is indexed: no mark left")
      end
    end)

    it("re-indexes only the items that changed, and nothing on a recalculation of something else", function()
      threeItems()
      mockContainer[0][4] = pile(404, "g404", 1)
      refreshBackpack({ bags = { [0] = true } })
      assert.are.same({ "0_4" }, added)
      added = {}
      refreshBackpack({ derive = true, categoriesUnchanged = true })
      mockContainer[6] = { pile(505, "g505", 1) }
      refreshBank()
      added = {}
      refreshBackpack({ bags = { [0] = true } })
      assert.are.same({}, added, "the bank's items are left alone")
    end)

    -- The safety net: whatever happens, what a refresh keeps equals what a full recalculation of
    -- every item would give, as search-indexing.md §1 checks the search index against a rebuild.
    describe("equals a full recalculation", function()
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
        local saved = { search.indicies, search.indexLookup, search.indexed, search.indexedItems }
        search:Init()
        local all = {}
        for _, kind in ipairs({ BACKPACK, BANK }) do
          for slotkey, it in pairs(items.slotInfo[kind].itemsBySlotKey or {}) do all[slotkey] = it end
        end
        search:IndexItems(all)
        local state = indexState()
        search.indicies, search.indexLookup, search.indexed, search.indexedItems = saved[1], saved[2], saved[3], saved[4]
        return state
      end

      local function capture()
        local out = {}
        for _, kind in ipairs({ BACKPACK, BANK }) do
          local si = items.slotInfo[kind]
          local visible = si:GetVisibleItems()
          for slotkey, it in pairs(si.itemsBySlotKey or {}) do
            if not it.isItemEmpty then
              out[slotkey] = table.concat({ tostring(it.itemInfo.category), tostring(it.isUpgrade),
                tostring(it.itemContextMatchResult), tostring(visible[slotkey] ~= nil and it.stackedCount or "-"),
                tostring(it.isSearchResult) }, "|")
            end
          end
        end
        return out
      end

      -- A full recalculation: nothing kept about any item (derived), no kept verdict, every
      -- category worked out again (a recalculation that does not say categoriesUnchanged).
      local function compare(step, what)
        local kept, keptIndex = capture(), indexState()
        assert.are.same(cleanState(), keptIndex, "search index, step " .. step .. " (" .. what .. ")")
        for _, kind in ipairs({ BACKPACK, BANK }) do
          for _, it in pairs(items.slotInfo[kind].itemsBySlotKey or {}) do
            it.derived = nil
            it.stackRecent = nil
          end
        end
        items:InvalidateUpgrades(false)
        refreshBackpack({ derive = true })
        refreshBank({ derive = true })
        assert.are.same(capture(), kept, "step " .. step .. " (" .. what .. ")")
      end

      local function run(seed, steps)
        local state = seed
        local function rand(n)
          state = (state * 1103515245 + 12345) % 2147483648
          return (math.floor(state / 65536) % n) + 1
        end
        local guid = 0
        local function newGuid()
          guid = guid + 1
          return "r" .. guid
        end
        local ids = { 101, 202, 303 }
        mockContainer[0], mockContainer[1], mockContainer[6] = {}, {}, {}
        for i = 1, 8 do mockContainer[0][i] = {} end
        for i = 1, 5 do mockContainer[1][i] = {} end
        for i = 1, 4 do mockContainer[6][i] = {} end
        mockContainer[0][1] = pile(101, newGuid(), 5)
        mockContainer[0][2] = pile(202, newGuid(), 20)
        mockContainer[6][1] = pile(303, newGuid(), 2)
        refreshBank({ wipe = true })
        refreshBackpack({ wipe = true })

        local function slots(occupied, bags)
          local out = {}
          for _, bagid in ipairs(bags or { 0, 1 }) do
            for slotid, slot in ipairs(mockContainer[bagid]) do
              if (slot.itemID ~= nil) == occupied then out[#out + 1] = { bagid, slotid } end
            end
          end
          return out
        end
        local function pick(list) return list[rand(#list)] end
        local function key(bs) return bs[1] .. "_" .. bs[2] end

        local actions = {
          { "loot a new pile", 4, function()
            local at = pick(slots(false))
            if not at then return end
            mockContainer[at[1]][at[2]] = pile(pick(ids), newGuid(), rand(20))
            newSlots[key(at)] = rand(2) == 1
            refreshBackpack({ bags = { [at[1]] = true } })
          end },
          { "top up a pile", 3, function()
            local at = pick(slots(true))
            if not at then return end
            local slot = mockContainer[at[1]][at[2]]
            slot.count = math.min(20, slot.count + rand(4))
            refreshBackpack({ bags = { [at[1]] = true } })
          end },
          { "use up a pile", 2, function()
            local at = pick(slots(true))
            if not at then return end
            mockContainer[at[1]][at[2]] = {}
            refreshBackpack({ bags = { [at[1]] = true } })
          end },
          { "move a pile", 2, function()
            local from, to = pick(slots(true)), pick(slots(false))
            if not from or not to then return end
            mockContainer[to[1]][to[2]] = mockContainer[from[1]][from[2]]
            mockContainer[from[1]][from[2]] = {}
            refreshBackpack({ bags = { [from[1]] = true, [to[1]] = true } })
          end },
          { "the client flags a pile new", 1, function()
            local at = pick(slots(true))
            if not at then return end
            newSlots[key(at)] = true
            refreshBackpack({ bags = { [at[1]] = true } })
          end },
          { "a plugin files an item (no refresh asked)", 1, function()
            local names = { false, "Mats", "Gems" }
            customOf[pick(ids)] = names[rand(3)] or nil
            catGen = catGen + 1
            local at = pick(slots(true)) or { 0, 1 }
            refreshBackpack({ bags = { [at[1]] = true } })
            refreshBank()
          end },
          { "search categories change", 1, function()
            local lists = { {}, { { "Shiny", "shiny" } }, { { "Alpha", "alpha" }, { "Meta", 'category = "alpha"', 1 } },
              { { "Recent Mats", 'category = "recent items"', 1 } } }
            searchCats = lists[rand(#lists)]
            refreshBackpack({ derive = true })
            refreshBank({ derive = true })
          end },
          -- An input both bags share: both are recalculated, as the game does.
          { "the item context changes", 1, function()
            local contexts = { false, "Scrapping", "Enchanting" }
            itemContext = contexts[rand(3)] or nil
            refreshBackpack({ derive = true, categoriesUnchanged = true })
            refreshBank({ derive = true, categoriesUnchanged = true })
          end },
          { "the bank opens or closes", 1, function()
            addon.atBank = not addon.atBank
            refreshBackpack({ derive = true, categoriesUnchanged = true })
            refreshBank({ derive = true, categoriesUnchanged = true })
          end },
          { "the gear changes", 1, function()
            gear = gear + 1
            items:InvalidateUpgrades(false)
            refreshBackpack({ derive = true, categoriesUnchanged = true })
            refreshBank({ derive = true, categoriesUnchanged = true })
          end },
          { "a tooltip finishes loading", 1, function()
            local at = pick(slots(true))
            if not at then return end
            local texts = { "", "shiny", "alpha dust" }
            tooltipOf[key(at)] = texts[rand(3)]
            refreshBackpack({ derive = true, categoriesUnchanged = true })
            refreshBank({ derive = true, categoriesUnchanged = true })
          end },
          -- The set map is rebuilt by every sweep, so a read can see a set change before
          -- EQUIPMENT_SETS_CHANGED's recalculation runs.
          { "gear sets change", 1, function()
            local at = pick(slots(true))
            if not at then return end
            setsOf[key(at)] = rand(2) == 1 and { "Tank" } or nil
            override(database, "GetCategoryFilter", function(_, _, filter)
              return filter == "RecentItems" or filter == "GearSet"
            end)
            if rand(2) == 1 then
              refreshBackpack()
            else
              refreshBackpack({ derive = true })
              refreshBank({ derive = true })
            end
          end },
          { "a quest starts or ends", 1, function()
            local at = pick(slots(true))
            if not at then return end
            questOf[key(at)] = rand(2) == 1 and { isQuestItem = true, questID = 77, isActive = rand(2) == 1 } or nil
            refreshBackpack()
          end },
          { "the bank shows another tab", 1, function()
            addon.Bags.Bank.bankTab = rand(2) == 1 and 13 or 6
            refreshBackpack({ derive = true, categoriesUnchanged = true })
          end },
          { "Recent Items are cleared (a sort)", 1, function()
            items:ClearNewItems(BACKPACK)
            refreshBackpack()
          end },
          { "stacking options change", 1, function()
            stackOpts.dontMergePartial = rand(2) == 1
            stackOpts.mergeStacks = rand(4) ~= 1
            refreshBackpack({ derive = true })
            refreshBank({ derive = true })
          end },
          { "the search box", 1, function()
            local texts = { "", "test", "shiny", "recent" }
            searchText = texts[rand(#texts)]
            refreshBackpack({ derive = true, categoriesUnchanged = true })
            refreshBank({ derive = true, categoriesUnchanged = true })
          end },
          { "the bank changes", 1, function()
            local at = pick(slots(false, { 6 }))
            if at then
              mockContainer[6][at[2]] = pile(pick(ids), newGuid(), rand(20))
            end
            refreshBank()
          end },
          -- The bag closing: Recent Items that are old enough expire, then a recalculation that
          -- changes nothing categories read (OnClosed, recent-items.md §3).
          { "the bag closes and Recent Items expire", 1, function()
            local timers = items._newItemTimers[BACKPACK]
            for timerGuid in pairs(timers) do
              if rand(2) == 1 then timers[timerGuid] = 0 end
            end
            items:ExpireRecentItems(BACKPACK)
            refreshBackpack({ derive = true, categoriesUnchanged = true })
          end },
          { "Show Bags is toggled", 0.5, function()
            local showBags = rand(2) == 1
            override(database, "GetBagView", function()
              return showBags and const.BAG_VIEW.SECTION_ALL_BAGS or const.BAG_VIEW.SECTION_GRID
            end)
            refreshBackpack({ derive = true })
            refreshBank({ derive = true })
          end },
          { "a full read", 1, function()
            refreshBackpack()
          end },
          { "a wipe", 0.25, function()
            refreshBank({ wipe = true })
            refreshBackpack({ wipe = true })
          end },
        }
        local total = 0
        for _, a in ipairs(actions) do total = total + a[2] end
        for step = 1, steps do
          local roll = rand(1000) / 1000 * total
          local chosen
          for _, a in ipairs(actions) do
            roll = roll - a[2]
            if roll <= 0 then chosen = a break end
          end
          chosen = chosen or actions[1]
          chosen[3]()
          compare(step, chosen[1])
        end
      end

      for _, seed in ipairs({ 7, 1234, 98765, 424242, 31337, 2026 }) do
        it("over random changes (seed " .. seed .. ")", function()
          addon.atBank = false
          addon.Bags = { Bank = { bankTab = 6 } }
          run(seed, 200)
        end)
      end
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

  -- The client does not flag a stack that grows as new. A capture of buying at a vendor
  -- (session #4, 2026-10-13) showed C_NewItems.IsNewItem false for Dalaran Sharp's slot after
  -- its stack went from 5 to 10, and true for Darnassian Bleu, bought into an empty slot.
  -- "All Items Recent" (on by default) marks a grown stack recent when the item's total in the
  -- backpack grew, so stacks merged or split by hand do not count.
  describe("All Items Recent: a stack that grows", function()
    local function enableAllItemsRecent()
      override(database, "GetMarkRecentItems", function(_, kind) return kind == const.BAG_KIND.BACKPACK end)
      override(database, "GetCategoryFilter", function(_, _, filter) return filter == "RecentItems" end)
      override(items, "IsBagOpen", function() return true end)
    end

    local function bag(size, filled)
      local slots = {}
      for i = 1, size do slots[i] = filled[i] or {} end
      return slots
    end

    -- The reads of the captured purchase, in order, with the captured items and slots. Every
    -- baseline is a full refresh, as the login read is: it marks nothing new, so the stack is
    -- not recent before the purchase (the capture: IsNewItem false for it).
    it("marks the stack a vendor purchase grew, in the captured order", function()
      enableAllItemsRecent()
      mockContainer[0] = bag(13, { [13] = { itemID = 414, guid = "g-sharp", count = 5 } })
      mockContainer[1] = bag(24, {})
      local before = refreshBackpack({ wipe = true })
      assert.are_not.equal("Recent Items", before.itemsBySlotKey["0_13"].itemInfo.category)

      -- 3.51 s: bag 0 read; Dalaran Sharp 5 -> 10, same GUID, the client does not flag it.
      mockContainer[0][13].count = 10
      local slotInfo = refreshBackpack({ bags = { [0] = true } })
      assert.equal("Recent Items", slotInfo.itemsBySlotKey["0_13"].itemInfo.category)

      -- 5.46 s: bag 1 read with nothing changed.
      slotInfo = refreshBackpack({ bags = { [1] = true } })
      assert.equal("Recent Items", slotInfo.itemsBySlotKey["0_13"].itemInfo.category)

      -- 6.12 s: Darnassian Bleu bought into the empty slot 1_23; the client flags it.
      mockContainer[1][23] = { itemID = 2070, guid = "g-bleu", count = 5 }
      newSlots["1_23"] = true
      slotInfo = refreshBackpack({ bags = { [1] = true } })
      assert.equal("Recent Items", slotInfo.itemsBySlotKey["1_23"].itemInfo.category)

      -- 7.09 s: slot 1_23 read again after it grew; still flagged, its timer already running.
      mockContainer[1][23].count = 10
      slotInfo = refreshBackpack({ bags = { [1] = true } })
      assert.equal("Recent Items", slotInfo.itemsBySlotKey["1_23"].itemInfo.category)
      assert.equal("Recent Items", slotInfo.itemsBySlotKey["0_13"].itemInfo.category)
    end)

    it("does not mark a stack merged into by hand", function()
      enableAllItemsRecent()
      mockContainer[0] = {
        { itemID = 414, guid = "g-a", count = 5 },
        { itemID = 414, guid = "g-b", count = 3 },
      }
      refreshBackpack({ wipe = true })
      mockContainer[0] = { { itemID = 414, guid = "g-a", count = 8 }, {} }
      local slotInfo = refreshBackpack({ bags = { [0] = true } })
      assert.are_not.equal("Recent Items", slotInfo.itemsBySlotKey["0_1"].itemInfo.category)
    end)

    it("does not mark a stack part of another stack was moved onto", function()
      enableAllItemsRecent()
      mockContainer[0] = {
        { itemID = 414, guid = "g-a", count = 5 },
        { itemID = 414, guid = "g-b", count = 3 },
      }
      refreshBackpack({ wipe = true })
      mockContainer[0][1].count = 7
      mockContainer[0][2].count = 1
      local slotInfo = refreshBackpack({ bags = { [0] = true } })
      assert.are_not.equal("Recent Items", slotInfo.itemsBySlotKey["0_1"].itemInfo.category)
    end)

    it("does not mark a grown stack with the option off", function()
      override(database, "GetMarkRecentItems", function() return false end)
      override(database, "GetCategoryFilter", function(_, _, filter) return filter == "RecentItems" end)
      mockContainer[0] = { { itemID = 414, guid = "g-sharp", count = 5 } }
      refreshBackpack({ wipe = true })
      mockContainer[0][1].count = 10
      local slotInfo = refreshBackpack({ bags = { [0] = true } })
      assert.are_not.equal("Recent Items", slotInfo.itemsBySlotKey["0_1"].itemInfo.category)
    end)

    it("keeps a running timer when a recent stack grows again", function()
      enableAllItemsRecent()
      local now = 1000
      override(_G, "time", function() return now end)
      mockContainer[0] = { { itemID = 414, guid = "g-sharp", count = 5 } }
      refreshBackpack({ wipe = true })
      mockContainer[0][1].count = 10
      refreshBackpack({ bags = { [0] = true } })
      now = 1100
      mockContainer[0][1].count = 15
      refreshBackpack({ bags = { [0] = true } })
      assert.equal(1000, items._newItemTimers[const.BAG_KIND.BACKPACK]["g-sharp"])
    end)
  end)

  -- Where an item dropped on a header lands without the category it was added to by hand (FileItem,
  -- docs/next-batch-2.md §8): its rules, a plugin's, the built-in categories; never Recent Items.
  describe("an item's natural category (NaturalCategory)", function()
    it("leaves out the category it was added to by hand and Recent Items, a rule still counting", function()
      override(database, "GetCategoryFilter", function(_, _, filter) return filter == "RecentItems" end)
      override(categories, "GetCustomCategory", function(_, _, _, data, withoutAdded)
        if data.itemInfo.itemID == 101 and not withoutAdded then return "Mats", 10, { save = true } end
        return nil, nil
      end)
      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 }, { itemID = 202, guid = "guid-202", count = 1 } }
      newSlots["0_1"] = true
      local slotInfo = refreshBackpack({ wipe = true })
      local ore = slotInfo.itemsBySlotKey["0_1"]
      assert.equal("Recent Items", ore.itemInfo.category)
      local natural = items:NaturalCategory(context:New("spec"), ore)
      assert.are_not.equal("Mats", natural)
      assert.are_not.equal("Recent Items", natural)
      assert.equal(items:GetCategory(context:New("spec"), slotInfo.itemsBySlotKey["0_2"], false, true), natural,
        "the built-in category, as an item never added")
      override(categories, "GetSortedSearchCategories", function()
        return { { name = "Alpha Items", priority = 10, enabled = { [const.BAG_KIND.BACKPACK] = true },
          searchCategory = { query = "alpha", groupBy = const.SEARCH_CATEGORY_GROUP_BY.NONE } } }
      end)
      slotInfo = refreshBackpack({ derive = true })
      assert.equal("Alpha Items", items:NaturalCategory(context:New("spec"), slotInfo.itemsBySlotKey["0_1"]))
    end)
  end)

  -- Asked: Ignored Items, "never land in there under any circumstance, no matter if it's added in Added
  -- Items, or in a Search Filter" (docs/next-batch-2.md §2): a rule that ignores an item passes it on.
  describe("Ignored Items (search rules)", function()
    local function rules(list)
      override(categories, "GetCustomCategory", function() return nil, nil end)
      override(categories, "GetSortedSearchCategories", function()
        local out = {}
        for _, c in ipairs(list) do
          table.insert(out, { name = c[1], priority = c[3] or 10, ignoredItems = c[4],
            enabled = { [const.BAG_KIND.BACKPACK] = true, [const.BAG_KIND.BANK] = true },
            searchCategory = { query = c[2], groupBy = c[5] or const.SEARCH_CATEGORY_GROUP_BY.NONE } })
        end
        return out
      end)
    end

    local function categoryOf(slotInfo, slotkey)
      return slotInfo.itemsBySlotKey[slotkey].itemInfo.category
    end

    it("gives an item a rule ignores to the next rule that matches it, else its own category", function()
      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 }, { itemID = 202, guid = "guid-202", count = 1 } }
      rules({ { "Alpha Items", "alpha", 1, { [101] = true } } })
      local slotInfo = refreshBackpack({ wipe = true })
      local own = categoryOf(slotInfo, "0_1")
      assert.are_not.equal("Alpha Items", own)
      rules({ { "Alpha Items", "alpha", 1, { [101] = true } }, { "Also Alpha", "alpha", 5 } })
      slotInfo = refreshBackpack({ derive = true })
      assert.equal("Also Alpha", categoryOf(slotInfo, "0_1"))
      rules({ { "Alpha Items", "alpha", 1, { [202] = true } }, { "Also Alpha", "alpha", 5 } })
      slotInfo = refreshBackpack({ derive = true })
      assert.equal("Alpha Items", categoryOf(slotInfo, "0_1"), "another item ignored: it matches again")
    end)

    it("keeps an ignored item out of a group by's sections", function()
      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 } }
      rules({ { "Alpha Items", "alpha", 1, { [101] = true }, const.SEARCH_CATEGORY_GROUP_BY.TYPE } })
      local slotInfo = refreshBackpack({ wipe = true })
      assert.is_nil(categoryOf(slotInfo, "0_1"):find("Alpha Items", 1, true))
    end)
  end)

  -- Asked: "'Skip Recent Items', which makes items that get assigned that category skip the recent
  -- items list (it gets unmarked as a new item, goes right to the category) -- this is 100% independent
  -- of autosell". docs/next-batch-2.md §1.
  describe("Skip Recent Items (a category setting)", function()
    local skips

    before_each(function()
      override(database, "GetCategoryFilter", function(_, _, filter) return filter == "RecentItems" end)
      override(database, "GetNewItemTime", function() return 300 end)
      override(categories, "GetCustomCategory", function(_, _, _, data)
        local name = ({ [101] = "Ore", [202] = "Mats" })[data.itemInfo.itemID]
        if name then return name, 10 end
        return nil, nil
      end)
      skips = { Ore = true }
      override(categories, "SkipsRecentOf", function(_, name) return skips[name] == true end)
    end)

    local function categoryOf(slotInfo, slotkey)
      return slotInfo.itemsBySlotKey[slotkey].itemInfo.category
    end

    it("shows a new item whose category skips Recent Items in that category at once, no longer new", function()
      mockContainer[0] = { { itemID = 101, guid = "g101", count = 1 }, { itemID = 202, guid = "g202", count = 1 } }
      newSlots["0_1"], newSlots["0_2"] = true, true
      local slotInfo = refreshBackpack({ wipe = true })
      assert.equal("Ore", categoryOf(slotInfo, "0_1"))
      assert.is_false(slotInfo.itemsBySlotKey["0_1"].itemInfo.isNewItem, "no glow")
      assert.is_nil(newSlots["0_1"], "the client's mark removed")
      assert.is_nil(items._newItemTimers[const.BAG_KIND.BACKPACK]["g101"])
      assert.equal("Recent Items", categoryOf(slotInfo, "0_2"), "another category's item stays recent")
      slotInfo = refreshBackpack()
      assert.equal("Ore", categoryOf(slotInfo, "0_1"), "and on the next read")
    end)

    it("unmarks an item looted later, and follows the setting", function()
      mockContainer[0] = { { itemID = 202, guid = "g202", count = 1 }, {}, {} }
      refreshBackpack({ wipe = true })
      mockContainer[0][2] = { itemID = 101, guid = "g101", count = 1 }
      newSlots["0_2"] = true
      local slotInfo = refreshBackpack({ bags = { [0] = true } })
      assert.equal("Ore", categoryOf(slotInfo, "0_2"))
      skips = {}
      mockContainer[0][3] = { itemID = 101, guid = "g101b", count = 1 }
      newSlots["0_3"] = true
      slotInfo = refreshBackpack({ bags = { [0] = true } })
      assert.equal("Recent Items", categoryOf(slotInfo, "0_3"), "turned off: recent again")
    end)

    it("skips by this read's search category, from an item's first read", function()
      override(categories, "GetCustomCategory", function() return nil, nil end)
      override(categories, "GetSortedSearchCategories", function()
        return { { name = "Alpha Items", priority = 10, enabled = { [const.BAG_KIND.BACKPACK] = true },
          searchCategory = { query = "alpha", groupBy = const.SEARCH_CATEGORY_GROUP_BY.NONE } } }
      end)
      skips = { ["Alpha Items"] = true }
      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 } }
      newSlots["0_1"] = true
      local slotInfo = refreshBackpack({ wipe = true })
      assert.equal("Alpha Items", categoryOf(slotInfo, "0_1"))
      assert.is_nil(newSlots["0_1"])
    end)

    -- Reported on WoW: Forever: gray items stayed in Recent Items until a sort, then went to Sell. The
    -- player's Sell (their saved rule) takes junk by its category; a new item's own category, which rules
    -- are matched against, was "Recent Items", so `category = "junk"` never took a new item.
    it("skips an item its category's rule takes by the item's category, while the item is new", function()
      override(categories, "GetCustomCategory", function() return nil, nil end)
      override(categories, "GetSortedSearchCategories", function()
        return { { name = "Sell", priority = 1, enabled = { [const.BAG_KIND.BACKPACK] = true },
          searchCategory = { query = 'usable = false or "Trade Goods" OR "Consumable" or category = "junk"',
            groupBy = const.SEARCH_CATEGORY_GROUP_BY.NONE } } }
      end)
      skips = { Sell = true }
      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1, info = { quality = 0 } }, {} }
      refreshBackpack({ wipe = true })
      mockContainer[0][2] = { itemID = 7073, guid = "guid-fang", count = 1, info = { quality = 0 } }
      newSlots["0_2"] = true
      local slotInfo = refreshBackpack({ bags = { [0] = true } })
      assert.equal("Sell", categoryOf(slotInfo, "0_1"), "an old junk item: Sell")
      assert.equal("Sell", categoryOf(slotInfo, "0_2"), "a new one too, not Recent Items")
      assert.is_nil(newSlots["0_2"])
    end)

    it("takes a virtual stack out of Recent Items when its category skips them", function()
      override(database, "GetStackingOptions", function()
        return { mergeStacks = true, mergeUnstackable = true, unmergeAtShop = false, dontMergePartial = false,
          dontMergeTransmog = false }
      end)
      mockContainer[0] = { { itemID = 101, guid = "old", count = 15 }, {}, {} }
      refreshBackpack({ wipe = true })
      mockContainer[0][2] = { itemID = 101, guid = "new", count = 3 }
      newSlots["0_2"] = true
      local slotInfo = refreshBackpack({ bags = { [0] = true } })
      assert.equal("Ore", categoryOf(slotInfo, "0_1"), "the stack shows in its category")
      assert.is_nil(slotInfo.itemsBySlotKey["0_1"].stackRecent)
    end)
  end)

  describe("Recent Items (timer only, expires when the bag closes)", function()
    local now

    local function setupRecent()
      override(database, "GetCategoryFilter", function(_, _, filter) return filter == "RecentItems" end)
      override(database, "GetNewItemTime", function() return 300 end)
      saveGlobal(_G, "time")
      now = 1000000
      _G.time = function() return now end
    end

    it("shows a new item in its category while the Recent Items category is turned off", function()
      setupRecent()
      override(database, "GetCategoryFilter", function() return false end)
      mockContainer[0] = { { itemID = 101, guid = "g101", count = 1 } }
      newSlots["0_1"] = true
      local slotInfo = refreshBackpack({ wipe = true })
      assert.equal("Everything", slotInfo.itemsBySlotKey["0_1"].itemInfo.category)
      assert.is_true(items:IsNewItem(slotInfo.itemsBySlotKey["0_1"]), "still new: only not shown there")
    end)

    it("keeps an item in Recent Items while the bag is open, after it was hovered and its duration passed", function()
      setupRecent()
      mockContainer[0] = {
        { itemID = 101, guid = "g101", count = 1 },
        { itemID = 201, guid = "g201", count = 1 },
      }
      newSlots["0_1"] = true
      local slotInfo = refreshBackpack({ wipe = true })
      assert.equal("Recent Items", slotInfo.itemsBySlotKey["0_1"].itemInfo.category)

      now = now + 600
      -- Hovering the item: Blizzard's ContainerFrameItemButtonMixin:OnUpdate drops its flag.
      _G.C_NewItems.RemoveNewItem(0, 1)
      -- Selling another item: its bag is swept.
      mockContainer[0][2] = {}
      slotInfo = refreshBackpack({ bags = { [0] = true } })

      assert.equal("Recent Items", slotInfo.itemsBySlotKey["0_1"].itemInfo.category)
    end)

    it("moves an expired item out of Recent Items on the sweep after the bag closes, for good", function()
      setupRecent()
      mockContainer[0] = {
        { itemID = 101, guid = "g101", count = 1 },
      }
      -- Never hovered: the client keeps flagging the item new.
      newSlots["0_1"] = true
      refreshBackpack({ wipe = true })

      now = now + 300
      assert.is_true(items:ExpireRecentItems(const.BAG_KIND.BACKPACK))
      local slotInfo = refreshBackpack()
      local item = slotInfo.itemsBySlotKey["0_1"]
      assert.are_not.equal("Recent Items", item.itemInfo.category)
      assert.is_false(item.itemInfo.isNewItem, "the expired item stops glowing")

      now = now + 10
      slotInfo = refreshBackpack()
      assert.are_not.equal("Recent Items", slotInfo.itemsBySlotKey["0_1"].itemInfo.category)
    end)

    it("never starts a timer for a flagged item the client reports no GUID for", function()
      setupRecent()
      mockContainer[0] = {
        { itemID = 101, count = 1 },
      }
      newSlots["0_1"] = true
      local slotInfo = refreshBackpack({ wipe = true })

      assert.is_nil(items._newItemTimers[const.BAG_KIND.BACKPACK][""])
      assert.are_not.equal("Recent Items", slotInfo.itemsBySlotKey["0_1"].itemInfo.category)
    end)

    it("keeps an item that has not expired when the bag closes", function()
      setupRecent()
      mockContainer[0] = {
        { itemID = 101, guid = "g101", count = 1 },
      }
      newSlots["0_1"] = true
      refreshBackpack({ wipe = true })

      now = now + 100
      assert.is_false(items:ExpireRecentItems(const.BAG_KIND.BACKPACK))
      local slotInfo = refreshBackpack()
      assert.equal("Recent Items", slotInfo.itemsBySlotKey["0_1"].itemInfo.category)
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

    describe("items whose hash changes without leaving their slot", function()
      -- A link with every field present, so the item ID parses into the item hash.
      local function link(itemID)
        local name = itemNames[itemID] or ("TestItem " .. itemID)
        return "|cffffffff|Hitem:" .. itemID .. "::::::::80::::::::::|h[" .. name .. "]|h|r"
      end

      it("keeps items read cold at login in place when the item cache warms", function()
        enableGaps()
        override(database, "GetCategoryFilter", function(_, _, filter)
          return filter == "Type" or filter == "Expansion"
        end)
        override(const, "EXPANSION_MAP", { [0] = "Classic", [11] = "Midnight" })
        local function idOf(x) return tonumber(x) or tonumber(tostring(x):match("item:(%d+)")) end
        local warm = { [101] = false, [201] = true, [202] = false }
        _G.C_Item.GetItemInfo = function(x)
          local id = idOf(x)
          if not warm[id] then return nil end
          return itemNames[id], nil, 1, 100, 1, "Consumable", "Potion", 20, "INVTYPE_NON_EQUIP_IGNORE",
            134400, 10, 0, 1, 0, 11, 0, false
        end
        saveGlobal(_G.C_Item, "GetItemInfoInstant")
        _G.C_Item.GetItemInfoInstant = function(x)
          return idOf(x), "Consumable", "Potion", "INVTYPE_NON_EQUIP_IGNORE", 134400, 0, 1
        end
        saveGlobal(_G.C_Item, "GetCurrentItemLevel")
        _G.C_Item.GetCurrentItemLevel = function(location)
          local bagid, slotid = location:GetBagAndSlot()
          local slot = mockContainer[bagid] and mockContainer[bagid][slotid]
          return (slot and warm[slot.itemID]) and 100 or nil
        end
        mockContainer[0] = {
          { itemID = 101, guid = "g101", count = 1, link = link(101) },
          { itemID = 201, guid = "g201", count = 1, link = link(201) },
          { itemID = 202, guid = "g202", count = 1, link = link(202) },
        }
        local cold = refreshBackpack({ wipe = true })
        assert.equal("Consumable - Classic", cold.itemsBySlotKey["0_1"].itemInfo.category)
        assert.equal("Consumable - Midnight", cold.itemsBySlotKey["0_2"].itemInfo.category)
        assert.equal("Consumable - Classic", cold.itemsBySlotKey["0_3"].itemInfo.category)

        warm[101], warm[202] = true, true
        local after = refreshBackpack()

        assert.equal(0, gapCount(after.sortedItems))
        assert.equal(3, #after.sortedItems)
        for _, entry in ipairs(after.sortedItems) do
          assert.equal("Consumable - Midnight", entry.itemInfo.category)
        end
      end)

      it("keeps a virtual stack in place when every pile's hash changes", function()
        enableGaps()
        override(database, "GetStackingOptions", function()
          return { mergeStacks = true, mergeUnstackable = true, unmergeAtShop = false,
            dontMergePartial = false, dontMergeTransmog = false }
        end)
        local level = nil
        saveGlobal(_G.C_Item, "GetCurrentItemLevel")
        _G.C_Item.GetCurrentItemLevel = function() return level end
        mockContainer[0] = {
          { itemID = 101, guid = "g101a", count = 20, link = link(101) },
          { itemID = 101, guid = "g101b", count = 10, link = link(101) },
          { itemID = 201, guid = "g201", count = 1, link = link(201) },
        }
        local before = refreshBackpack()
        assert.equal(2, #before.sortedItems)

        -- The current item level resolving changes the hash of every pile.
        level = 100
        local after = refreshBackpack()

        assert.equal(0, gapCount(after.sortedItems))
        assert.equal(2, #after.sortedItems)
        for i, entry in ipairs(before.sortedItems) do
          assert.equal(entry.slotkey, after.sortedItems[i].slotkey)
        end
        assert.equal(30, after.itemsBySlotKey["0_1"].stackedCount)
      end)

      it("still treats a move from the Character Bank to the Warbank as a remove + add", function()
        enableGaps()
        override(addon, "atBank", true)
        mockContainer[6] = {
          { itemID = 201, guid = "gbank1", count = 1, link = link(201) },
          { itemID = 202, guid = "gbank2", count = 1, link = link(202) },
        }
        mockContainer[13] = { {} }
        refreshBank()

        mockContainer[6][1] = {}
        mockContainer[13][1] = { itemID = 201, guid = "gbank1", count = 1, link = link(201) }
        local after = refreshBank()

        assert.equal(1, gapCount(after.sortedItems))
        assert.equal("gap:6_1", after.sortedItems[1].slotkey)
        assert.equal("13_1", after.sortedItems[#after.sortedItems].slotkey)
      end)
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

    it("keeps inset current when a kept item leaves its set", function()
      pendingSets[0] = { [1] = { "Demo" } }
      mockContainer[0] = { { itemID = 101, guid = "gear-demo", count = 1 } }
      refreshBackpack()
      assert.are.same({ ["0_1"] = true }, search:Search("inset = true"))
      pendingSets[0] = {}
      refreshBackpack({ derive = true })
      assert.are.same({}, search:Search("inset = true"))
      assert.is_true(search:Search("inset = false")["0_1"])
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

    -- toy and known come from whole tooltip lines (TooltipScanner); a kept item takes the marks of
    -- its tooltip as it is now, as it takes its text.
    it("finds toys and items already known, and follows a kept item's tooltip", function()
      local tooltipScanner = addon:GetModule("TooltipScanner")
      local learned = false
      -- The marks come from the lines the text joins: a learned toy's text has its "Already known".
      override(tooltipScanner, "GetTooltipText", function(_, bagid, slotid)
        if bagid == 0 and slotid == 1 then
          if learned then
            return "Flight Master's Whistle Toy Already known", { toy = true, known = true }
          end
          return "Flight Master's Whistle Toy", { toy = true }
        end
        return "", nil
      end)
      mockContainer[0] = { { itemID = 101, guid = "guid-101", count = 1 }, { itemID = 202, guid = "guid-202", count = 1 } }
      refreshBackpack()
      assert.are.same({ ["0_1"] = true }, search:Search("toy = true"))
      assert.are.same({}, search:Search("known = true"))
      learned = true
      refreshBackpack({ derive = true })
      assert.are.same({ ["0_1"] = true }, search:Search("known = true"))
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

  -- A derive recalculates everything the data phase derives from the items the last read
  -- committed, without reading a bag slot (.claude/rules/refresh-scheduler.md §10).
  describe("recalculating without reading (derive)", function()
    local reads, commits

    before_each(function()
      reads, commits = 0, 0
      for _, name in ipairs({ "GetContainerNumSlots", "GetContainerItemInfo", "GetContainerItemID", "GetContainerItemLink" }) do
        local original = _G.C_Container[name]
        override(_G.C_Container, name, function(...)
          reads = reads + 1
          return original(...)
        end)
      end
      local commit = items.Phase11_CommitAndDispatch
      override(items, "Phase11_CommitAndDispatch", function(...)
        commits = commits + 1
        return commit(...)
      end)
      -- The CanBeRefunded mock looks the slot up to know whether it holds an item; the client's reads no
      -- bag slot, so that lookup is not counted.
      local canBeRefunded = _G.C_Item.CanBeRefunded
      override(_G.C_Item, "CanBeRefunded", function(...)
        local before = reads
        local refundable = canBeRefunded(...)
        reads = before
        return refundable
      end)
    end)

    it("reads no bag slot and keeps the committed items", function()
      mockContainer[0] = { { itemID = 101, guid = "g101", count = 1 }, {} }
      local item = refreshBackpack().itemsBySlotKey["0_1"]
      reads = 0
      local slotInfo = refreshBackpack({ derive = true })
      assert.equal(0, reads)
      assert.equal(item, slotInfo.itemsBySlotKey["0_1"])
      assert.is_true(slotInfo.itemsBySlotKey["0_2"].isItemEmpty)
    end)

    it("ends in the same state as a read when the bags did not change", function()
      override(database, "GetStackingOptions", function() return { mergeStacks = true, mergeUnstackable = true } end)
      mockContainer[0] = {
        { itemID = 101, guid = "g101", count = 1 },
        { itemID = 202, guid = "g202a", count = 3 },
        {},
        { itemID = 202, guid = "g202b", count = 4 },
      }
      mockContainer[1] = { { itemID = 303, guid = "g303", count = 1 }, {} }
      local function state(slotInfo)
        local out = { total = slotInfo.totalItems, order = {} }
        for _, item in ipairs(slotInfo.sortedItems) do
          table.insert(out.order, item.slotkey .. "|" .. tostring(item.itemInfo and item.itemInfo.category))
        end
        for slotkey, item in pairs(slotInfo.itemsBySlotKey) do
          out[slotkey] = tostring(item.itemInfo and item.itemInfo.category) .. "|" .. tostring(item.stackedCount)
            .. "|" .. tostring(item.isUpgrade) .. "|" .. tostring(item.itemContextMatchResult)
        end
        for slotkey in pairs(slotInfo.visibleItemsBySlotKey) do
          out["visible " .. slotkey] = true
        end
        return out
      end
      refreshBackpack()
      local read = state(refreshBackpack())
      local derived = state(refreshBackpack({ derive = true }))
      assert.are.same(read, derived)
    end)

    it("applies a category change", function()
      mockContainer[0] = { { itemID = 101, guid = "g101", count = 1 } }
      refreshBackpack()
      override(categories, "GetCustomCategory", function(_, _, _, data)
        if data.itemInfo.itemID == 101 then return "Swords", 1 end
        return nil, nil
      end)
      local slotInfo = refreshBackpack({ derive = true })
      assert.equal("Swords", slotInfo.itemsBySlotKey["0_1"].itemInfo.category)
    end)

    it("re-scans a tooltip whose text was dropped, and indexes the new text", function()
      local texts = { g101 = "Alpha Sword" }
      local tooltipScanner = addon:GetModule("TooltipScanner")
      override(tooltipScanner, "GetTooltipText", function(_, _, _, guid) return texts[guid] end)
      mockContainer[0] = { { itemID = 101, guid = "g101", count = 1 } }
      refreshBackpack()
      assert.is_nil(search:Search("zephyrium")["0_1"])
      texts.g101 = "Use: channel zephyrium essence"
      local slotInfo = refreshBackpack({ derive = true })
      assert.equal("Use: channel zephyrium essence", slotInfo.itemsBySlotKey["0_1"].itemInfo.tooltipText)
      assert.is_true(search:Search("zephyrium")["0_1"] == true)
    end)

    it("applies a gear set change", function()
      override(database, "GetCategoryFilter", function(_, _, filter) return filter == "GearSet" end)
      local sets
      local equipmentSets = addon:GetModule("EquipmentSets")
      override(equipmentSets, "GetItemSets", function(_, bagid, slotid)
        if bagid == 0 and slotid == 1 then return sets end
        return nil
      end)
      mockContainer[0] = { { itemID = 101, guid = "g101", count = 1 } }
      refreshBackpack()
      sets = { "Tank" }
      local slotInfo = refreshBackpack({ derive = true })
      assert.equal("Gear: Tank", slotInfo.itemsBySlotKey["0_1"].itemInfo.category)
    end)

    it("refreshes the new-item flag of an item still in its slot", function()
      mockContainer[0] = { { itemID = 101, guid = "g101", count = 1 } }
      refreshBackpack()
      newSlots["0_1"] = true
      local slotInfo = refreshBackpack({ derive = true })
      assert.is_true(slotInfo.itemsBySlotKey["0_1"].itemInfo.isNewItem)
    end)

    -- The slot changed and its read has not run yet, with no change reported for its bag
    -- (MarkBagUnread): the item's GUID still tells it. What the client reports for the slot
    -- belongs to another item, so none of it is written to the committed one.
    it("leaves an item whose slot now holds something else as it was", function()
      override(database, "GetCategoryFilter", function(_, _, filter) return filter == "RecentItems" end)
      mockContainer[0] = { { itemID = 101, guid = "g101", count = 1 } }
      refreshBackpack()
      mockContainer[0] = { { itemID = 202, guid = "g202", count = 1 } }
      newSlots["0_1"] = true
      local slotInfo = refreshBackpack({ derive = true })
      local item = slotInfo.itemsBySlotKey["0_1"]
      assert.equal("g101", item.itemInfo.itemGUID)
      assert.is_false(item.itemInfo.isNewItem)
      assert.is_nil(items._newItemTimers[const.BAG_KIND.BACKPACK]["g101"])
      assert.are_not.equal("Recent Items", item.itemInfo.category)
    end)

    -- A capture of opening the bank read 478 of 491 items before the client had their data
    -- ("Retrieving item information" tooltips). Reads re-read such slots every time; the
    -- recalculations after the open skipped them, so their names and tooltip text stayed
    -- cold until the next open.
    it("re-reads an item read without its data, once its slot still holds it", function()
      local cold = true
      local getItemInfo = _G.C_Item.GetItemInfo
      override(_G.C_Item, "GetItemInfo", function(itemID)
        if cold then return nil end
        return getItemInfo(itemID)
      end)
      local tooltipScanner = addon:GetModule("TooltipScanner")
      override(tooltipScanner, "GetTooltipText", function()
        return cold and "Retrieving item information" or "Use: channel zephyrium essence"
      end)
      itemNames[909] = "Warm Name"
      mockContainer[0] = { { itemID = 909, guid = "guid-909", count = 1 } }
      local first = refreshBackpack().itemsBySlotKey["0_1"]
      assert.is_true(first.harvestIncomplete)
      cold = false
      local item = refreshBackpack({ derive = true }).itemsBySlotKey["0_1"]
      itemNames[909] = nil
      assert.is_false(item.harvestIncomplete)
      assert.equal("Warm Name", item.itemInfo.itemName)
      assert.is_true(search:Search("zephyrium")["0_1"] == true)
    end)

    describe("a bag the client changed after its read (MarkBagUnread)", function()
      local asked

      before_each(function()
        asked = {}
        local getItemGUID = _G.C_Item.GetItemGUID
        override(_G.C_Item, "GetItemGUID", function(location)
          local bagid, slotid = location:GetBagAndSlot()
          table.insert(asked, bagid .. "_" .. slotid)
          return getItemGUID(location)
        end)
        mockContainer[0] = { { itemID = 101, guid = "g101", count = 1 }, { itemID = 202, guid = "g202", count = 1 } }
        mockContainer[1] = { { itemID = 303, guid = "g303", count = 1 } }
        refreshBackpack()
        asked = {}
      end)

      it("is left as the last read committed it, and the client is asked nothing about it", function()
        local before = items.slotInfo[const.BAG_KIND.BACKPACK].itemsBySlotKey
        mockContainer[0][1] = {}
        newSlots["0_2"] = true
        items:MarkBagUnread(0)
        newSlots["1_1"] = true
        local committed = refreshBackpack({ derive = true }).itemsBySlotKey
        assert.same({ "1_1" }, asked)
        assert.equal(before["0_1"], committed["0_1"])
        assert.is_false(committed["0_1"].isItemEmpty)
        assert.is_false(committed["0_2"].itemInfo.isNewItem, "nothing the client says of the bag is taken")
        assert.is_true(committed["1_1"].itemInfo.isNewItem, "an unchanged bag is refreshed")
      end)

      it("is read again by the read the change leads to, which ends it", function()
        mockContainer[0][1] = {}
        items:MarkBagUnread(0)
        local committed = refreshBackpack({ bags = { [0] = true } }).itemsBySlotKey
        assert.is_true(committed["0_1"].isItemEmpty)
        assert.is_nil(items._unreadBags[0])
        asked = {}
        refreshBackpack({ derive = true })
        table.sort(asked)
        assert.same({ "0_2", "1_1" }, asked)
      end)

      it("stays unread through a recalculation and a read of another bag", function()
        items:MarkBagUnread(0)
        refreshBackpack({ derive = true })
        assert.is_not_nil(items._unreadBags[0])
        refreshBackpack({ bags = { [1] = true } })
        assert.is_not_nil(items._unreadBags[0])
        assert.is_nil(items._unreadBags[1])
      end)

      it("is ended for every bag by a read of every bag", function()
        items:MarkBagUnread(0)
        items:MarkBagUnread(1)
        refreshBackpack({ wipe = true })
        assert.is_nil(items._unreadBags[0])
        assert.is_nil(items._unreadBags[1])
      end)

      -- The read harvests in one frame and commits in a later one; a change in between is not in
      -- what it committed.
      it("stays unread when it changes again while a read of it is under way", function()
        async.Yield = function() coroutine.yield() end
        items:MarkBagUnread(0)
        local ctx = context:New("refresh")
        ctx:Set("targetedBags", { [0] = true })
        local sweep = coroutine.create(function() items:RunRefresh(ctx, const.BAG_KIND.BACKPACK) end)
        assert.is_true(coroutine.resume(sweep))
        mockContainer[0][2] = {}
        items:MarkBagUnread(0)
        assert.is_true(coroutine.resume(sweep))
        assert.equal("dead", coroutine.status(sweep))
        assert.is_not_nil(items._unreadBags[0])
      end)

      it("stays unread when the read of it fails before committing", function()
        items:MarkBagUnread(0)
        override(items, "Phase11_CommitAndDispatch", function() error("commit failed") end)
        local ctx = context:New("refresh")
        ctx:Set("targetedBags", { [0] = true })
        assert.is_false(pcall(items.RunRefresh, items, ctx, const.BAG_KIND.BACKPACK))
        assert.is_not_nil(items._unreadBags[0])
      end)
    end)

    -- Reported in game, twice: data/items.lua:1190: bad argument #1 to 'GetItemGUID' (Usage: local
    -- itemGUID = C_Item.GetItemGUID(itemLocation)), from a recalculation the queue ran (refresh.lua:250,
    -- its frame step). A slot the player emptied (a sale, the last of a stack used) is read only once the
    -- loader has the bag's item data, then waits its turn behind the units already queued, which never
    -- carry it (a read never rides on a recalculation). A recalculation that ran first worked from the
    -- items the last read committed and asked the client about the emptied slot.
    describe("while a changed bag's read waits", function()
      local advance, loaderCallback, errors

      local function resetEvents()
        if events._eventHandler then
          events._eventHandler:UnregisterAllEvents()
          events._eventHandler:UnregisterAllMessages()
        end
        events:Init()
      end

      local function fire(name, ...)
        local entry = events._eventMap[name]
        if entry then entry.fn(name, ...) end
      end

      local function drain()
        for _ = 1, 100 do
          if advance() == 0 then return end
        end
        error("the refresh queue never went idle")
      end

      before_each(function()
        resetEvents()
        async.Yield = function() coroutine.yield() end
        local frames = {}
        saveGlobal(_G.C_Timer, "After")
        _G.C_Timer.After = function(_, fn) table.insert(frames, fn) end
        advance = function()
          local due = frames
          frames = {}
          for _, fn in ipairs(due) do fn() end
          return #due
        end
        errors = {}
        saveGlobal(_G, "geterrorhandler")
        _G.geterrorhandler = function() return function(err) table.insert(errors, err) end end
        local loader = addon:GetModule("ItemLoader")
        override(loader, "TellMeWhenABagIsUpdated", function(_, cb) loaderCallback = cb end)
        override(loader, "Hold", function() end)
        override(loader, "Release", function() end)
        mockContainer[0] = { { itemID = 101, guid = "g101", count = 1 }, { itemID = 202, guid = "g202", count = 1 } }
        refresh:OnEnable()
        refresh:_WorldRead(refresh._world, "primed")
        drain()
      end)

      after_each(function()
        resetEvents()
      end)

      it("recalculates from the last read without asking the client about the emptied slot", function()
        -- A read is under way when a tooltip finishes loading; the recalculation it asks for waits.
        refresh:RequestUpdate({ backpack = true })
        events:SendMessage(context:New("TooltipDataResolved"), "bags/Rederive",
          { backpack = true, bank = false, categoriesUnchanged = true })
        -- The player sells the first slot's item: the client empties the slot and says so; the bag's
        -- read comes once the loader has its item data, behind the recalculation.
        mockContainer[0][1] = {}
        fire("BAG_UPDATE", 0)
        loaderCallback({ [0] = true })
        drain()
        assert.same({}, errors)
        local committed = items.slotInfo[const.BAG_KIND.BACKPACK].itemsBySlotKey
        assert.is_true(committed["0_1"].isItemEmpty)
        assert.equal("g202", committed["0_2"].itemInfo.itemGUID)
      end)
    end)

    -- A simulated client: the real events, queue and pipeline, a client whose bags change at random, and
    -- what BetterBags is asked for in game (tooltips finishing, windows opening and closing, the bank,
    -- settings, gear sets, sorts, loading screens). The client reports each change to a bag (BAG_UPDATE)
    -- as it makes it, and a loading screen behaves as a capture of a trip into an instance and back out
    -- showed: the items there at LOADING_SCREEN_ENABLED, taken away with no BAG_UPDATE while frames run,
    -- gone at PLAYER_LEAVING_WORLD, and given back with BAG_UPDATE once the loading screen ends. Reported
    -- in game, from a tooltip finishing, a window closing and the queue's step: items.lua: bad argument #1
    -- to 'GetItemGUID' (Usage: local itemGUID = C_Item.GetItemGUID(itemLocation)), a recalculation asking
    -- the client about a slot it had emptied. BetterBags must never ask about one, and once the client is
    -- quiet what it committed must be what the client holds.
    describe("a simulated client", function()
      local now, timers, errors, loaderCallback, loaderPending, frameChanged, bankStore, clientBankOpen
      local seed, log, guidCounter, sweeps

      local BACKPACK, BANK_BAGS = { 0, 1 }, { 6, 7, 13 }
      local SLOTS = 6

      local function random(n)
        seed = (seed * 1103515245 + 12345) % 2147483648
        return (math.floor(seed / 65536) % n) + 1
      end

      local function after(delay, fn)
        table.insert(timers, { at = now + math.max(delay or 0, 0.001), fn = fn })
      end

      -- A WoW event reaches every listener: the events module's handlers and the world frame
      -- (refresh-scheduler.md §8).
      local function fire(name, ...)
        table.insert(log, string.format("%.3f %s %s", now, name, tostring((...))))
        local entry = events._eventMap[name]
        if entry then entry.fn(name, ...) end
        local f = refresh._worldFrame
        if f and f._events and f._events[name] and f:GetScript("OnEvent") then
          f:GetScript("OnEvent")(f, name, ...)
        end
      end

      local function send(message, options)
        table.insert(log, string.format("%.3f [msg] %s", now, message))
        events:SendMessage(context:New(message), message, options)
      end

      -- The client's BAG_UPDATE: BetterBags' handlers, and the loader's (its pending bags, read once the
      -- frame's batch ends and their item data has loaded, at once or a few frames later).
      local function bagUpdate(bag)
        fire("BAG_UPDATE", bag)
        loaderPending[bag] = true
        frameChanged = true
      end

      local function loaderBatch()
        if next(loaderPending) == nil then return end
        local bags = loaderPending
        loaderPending = {}
        local delay = random(4) - 1
        if delay == 0 then
          loaderCallback(bags)
        else
          after(delay / 60, function() loaderCallback(bags) end)
        end
      end

      local function frame()
        now = now + 1 / 60
        local f = refresh._worldFrame
        local onUpdate = f and f:GetScript("OnUpdate")
        if onUpdate then onUpdate(f, 1 / 60) end
        local due, rest = {}, {}
        for _, t in ipairs(timers) do
          if t.at <= now + 1e-9 then table.insert(due, t) else table.insert(rest, t) end
        end
        timers = rest
        for _, t in ipairs(due) do t.fn() end
        if frameChanged then
          frameChanged = false
          fire("BAG_UPDATE_DELAYED")
          loaderBatch()
        end
      end

      local function frames(n)
        for _ = 1, n do frame() end
      end

      local function newItem()
        guidCounter = guidCounter + 1
        return { itemID = 100 + random(5), guid = "g" .. guidCounter, count = random(5) }
      end

      local function slotsOf(bags, filled)
        local found = {}
        for _, bag in ipairs(bags) do
          local slots = mockContainer[bag]
          if slots then
            for slot = 1, #slots do
              if (slots[slot].itemID ~= nil) == filled then
                table.insert(found, { bag, slot })
              end
            end
          end
        end
        return found
      end

      local function pick(list)
        if #list == 0 then return nil end
        return list[random(#list)]
      end

      -- What hooks.lua asks for when an interaction window opens (a frame later, from OnUpdate) or closes.
      local function interactionRecalculation()
        return {
          resetLayout = true,
          backpack = true,
          bank = items:NeedsInteractionRecalculation(const.BAG_KIND.BANK),
          categoriesUnchanged = true,
        }
      end

      local function closeWindow(interactionType)
        addon.atInteracting = false
        fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", interactionType)
        send("bags/Rederive", interactionRecalculation())
      end

      -- What a tooltip finishing asks for, from its bucket's timer (TooltipScanner:OnTooltipDataResolved).
      local function tooltipLoaded()
        after(0.2, function()
          send("bags/Rederive", { backpack = true, bank = addon.atBank, categoriesUnchanged = true })
        end)
      end

      local OPS = {
        loot = function()
          local at = pick(slotsOf(BACKPACK, false))
          if not at then return end
          mockContainer[at[1]][at[2]] = newItem()
          bagUpdate(at[1])
          tooltipLoaded()
        end,
        use = function()
          local at = pick(slotsOf(BACKPACK, true))
          if not at then return end
          mockContainer[at[1]][at[2]] = {}
          bagUpdate(at[1])
        end,
        move = function()
          local from, to = pick(slotsOf(BACKPACK, true)), pick(slotsOf(BACKPACK, false))
          if not (from and to) then return end
          mockContainer[to[1]][to[2]] = mockContainer[from[1]][from[2]]
          mockContainer[from[1]][from[2]] = {}
          bagUpdate(from[1])
          if to[1] ~= from[1] then bagUpdate(to[1]) end
        end,
        count = function()
          local at = pick(slotsOf(BACKPACK, true))
          if not at then return end
          local item = mockContainer[at[1]][at[2]]
          mockContainer[at[1]][at[2]] = { itemID = item.itemID, guid = item.guid, count = random(20) }
          bagUpdate(at[1])
        end,
        tooltip = tooltipLoaded,
        settings = function()
          send("bags/Rederive", { resetLayout = true, buttons = true })
        end,
        gearSets = function()
          fire("EQUIPMENT_SETS_CHANGED")
        end,
        openWindow = function()
          if addon.atInteracting then return end
          addon.atInteracting = true
          fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 5)
          after(0, function() send("bags/Rederive", interactionRecalculation()) end)
        end,
        closeWindow = function()
          if not addon.atInteracting or clientBankOpen then return end
          closeWindow(5)
        end,
        openBank = function()
          if clientBankOpen or addon.atInteracting then return end
          clientBankOpen = true
          for _, bag in ipairs(BANK_BAGS) do mockContainer[bag] = bankStore[bag] end
          addon.atInteracting = true
          fire("BANKFRAME_OPENED")
          after(0, function() send("bags/Rederive", interactionRecalculation()) end)
        end,
        -- BANKFRAME_CLOSED fires twice; the bank's data is there only at the first (warcraft.wiki.gg
        -- BANKFRAME_CLOSED). addon.CloseBank forgets the bank's items at each.
        closeBank = function()
          if not clientBankOpen then return end
          fire("BANKFRAME_CLOSED")
          items:ClearBankCache(context:New("BANKFRAME_CLOSED"))
          clientBankOpen = false
          for _, bag in ipairs(BANK_BAGS) do mockContainer[bag] = nil end
          fire("BANKFRAME_CLOSED")
          items:ClearBankCache(context:New("BANKFRAME_CLOSED"))
          closeWindow(8)
        end,
        deposit = function()
          if not clientBankOpen then return end
          local from, to = pick(slotsOf(BACKPACK, true)), pick(slotsOf(BANK_BAGS, false))
          if not (from and to) then return end
          mockContainer[to[1]][to[2]] = mockContainer[from[1]][from[2]]
          mockContainer[from[1]][from[2]] = {}
          bagUpdate(from[1])
          bagUpdate(to[1])
        end,
        withdraw = function()
          if not clientBankOpen then return end
          local from, to = pick(slotsOf(BANK_BAGS, true)), pick(slotsOf(BACKPACK, false))
          if not (from and to) then return end
          mockContainer[to[1]][to[2]] = mockContainer[from[1]][from[2]]
          mockContainer[from[1]][from[2]] = {}
          bagUpdate(from[1])
          bagUpdate(to[1])
        end,
        sort = function()
          send("bags/SortBackpack")
        end,
        -- A loading screen, as captured: the items there at LOADING_SCREEN_ENABLED, frames run, the items
        -- taken with no BAG_UPDATE, more frames (timers firing, a window closing, a tooltip finishing),
        -- PLAYER_LEAVING_WORLD, the bags' containers and the player back, the loading screen gone, then
        -- the items given back with BAG_UPDATE.
        transfer = function()
          if clientBankOpen then return end
          fire("LOADING_SCREEN_ENABLED")
          frames(random(10))
          local held = {}
          for _, bag in ipairs(BACKPACK) do
            held[bag] = mockContainer[bag]
            mockContainer[bag] = nil
          end
          tooltipLoaded()
          frames(random(10))
          if addon.atInteracting then closeWindow(5) end
          frames(random(30))
          fire("PLAYER_LEAVING_WORLD")
          frames(random(5))
          fire("BAG_CONTAINER_UPDATE")
          fire("PLAYER_ENTERING_WORLD", false, false)
          fire("LOADING_SCREEN_DISABLED")
          frames(random(3))
          for _, bag in ipairs(BACKPACK) do
            mockContainer[bag] = held[bag]
            bagUpdate(bag)
          end
        end,
        wait = function()
          frames(random(12))
        end,
      }
      local OP_NAMES = {}
      for name in pairs(OPS) do table.insert(OP_NAMES, name) end
      table.sort(OP_NAMES)

      -- What does not change from one seed to the next: the client's clock, its error handler, the loader,
      -- the bank's window, the stacking options BetterBags ships with, and a count of the sweeps run.
      before_each(function()
        saveGlobal(_G.C_Timer, "After")
        saveGlobal(_G.C_Timer, "NewTimer")
        _G.C_Timer.After = function(delay, fn) after(delay, fn) end
        _G.C_Timer.NewTimer = function(delay, fn)
          local t = { cancelled = false }
          function t:Cancel() self.cancelled = true end
          after(delay, function() if not t.cancelled then fn(t) end end)
          return t
        end
        saveGlobal(_G, "geterrorhandler")
        _G.geterrorhandler = function()
          return function(err)
            table.insert(errors, { err = tostring(err), log = { unpack(log, math.max(1, #log - 30)) } })
          end
        end
        saveGlobal(_G, "GameMenuFrame")
        _G.GameMenuFrame = { IsShown = function() return false end }
        saveGlobal(_G.C_Container, "SortBags")
        _G.C_Container.SortBags = function()
          -- The server moves the items a few frames later; each bag it changed says so.
          after(random(3) / 60, function()
            for _, bag in ipairs(BACKPACK) do
              local slots = mockContainer[bag]
              if slots then
                for i = #slots, 2, -1 do
                  local j = random(i)
                  slots[i], slots[j] = slots[j], slots[i]
                end
                bagUpdate(bag)
              end
            end
          end)
        end
        override(database, "GetStackingOptions", function()
          return { mergeStacks = true, unmergeAtShop = true, mergeUnstackable = true }
        end)
        local loader = addon:GetModule("ItemLoader")
        override(loader, "TellMeWhenABagIsUpdated", function(_, cb) loaderCallback = cb end)
        override(loader, "Hold", function() end)
        override(loader, "Release", function() end)
        for _, name in ipairs({ "PrimeBank", "PrimeAll" }) do
          override(loader, name, function(...)
            local cb = select(select("#", ...), ...)
            local delay = random(3) - 1
            if delay == 0 then cb() else after(delay / 60, cb) end
          end)
        end
        local runRefresh = items.RunRefresh
        override(items, "RunRefresh", function(self, ctx, kind)
          local key = ctx:Get("derive") and "derive" or "read"
          sweeps[key] = sweeps[key] + 1
          if kind == const.BAG_KIND.BANK then sweeps.bank = sweeps.bank + 1 end
          return runRefresh(self, ctx, kind)
        end)
      end)

      after_each(function()
        if events._eventHandler then
          events._eventHandler:UnregisterAllEvents()
          events._eventHandler:UnregisterAllMessages()
        end
        events:Init()
      end)

      local function setup(s)
        seed = s
        now, timers, errors, loaderPending, frameChanged, log, guidCounter = 0, {}, {}, {}, false, {}, 0
        clientBankOpen = false
        sweeps = { read = 0, derive = 0, bank = 0, transfer = 0 }
        if events._eventHandler then
          events._eventHandler:UnregisterAllEvents()
          events._eventHandler:UnregisterAllMessages()
        end
        events:Init()
        async.Yield = function() coroutine.yield() end
        search:Init()
        items:Init()
        items._firstLoad[const.BAG_KIND.BACKPACK] = false
        items._firstLoad[const.BAG_KIND.BANK] = false
        refresh:Init()
        addon.atBank = false
        addon.atInteracting = false
        addon.Bags = { Bank = { bankTab = 6, Show = function(_, _, _, onShown)
          after(random(30) / 60, onShown)
        end } }
        mockContainer, newSlots = {}, {}
        bankStore = {}
        for _, bag in ipairs(BANK_BAGS) do
          bankStore[bag] = {}
          for slot = 1, SLOTS do bankStore[bag][slot] = random(2) == 1 and newItem() or {} end
        end
        for _, bag in ipairs(BACKPACK) do
          mockContainer[bag] = {}
          for slot = 1, SLOTS do mockContainer[bag][slot] = random(2) == 1 and newItem() or {} end
        end
        refresh:OnEnable()
        refresh:_WorldRead(refresh._world, "primed")
        frames(10)
      end

      -- Runs a seed: its operations, then frames until the client has been quiet long enough for every
      -- read, wait and timeout to have run. It returns the first error, with the events before it.
      local function run(steps)
        for _ = 1, steps do
          local name = OP_NAMES[random(#OP_NAMES)]
          table.insert(log, string.format("%.3f op %s", now, name))
          if name == "transfer" then sweeps.transfer = sweeps.transfer + 1 end
          local ok, err = pcall(OPS[name])
          if not ok then
            table.insert(errors, { err = tostring(err), log = { unpack(log, math.max(1, #log - 30)) } })
          end
          if #errors > 0 then
            return errors[1].err .. "\n--- before it ---\n" .. table.concat(errors[1].log, "\n")
          end
        end
        frames(60 * 70)
        return nil
      end

      -- What the client holds in the backpack, and what BetterBags committed of it, by slot and GUID.
      local function holdings()
        local client, committed = {}, {}
        for _, bag in ipairs(BACKPACK) do
          for slot, contents in ipairs(mockContainer[bag]) do
            if contents.itemID then client[bag .. "_" .. slot] = contents.guid end
          end
        end
        for slotkey, item in pairs(items.slotInfo[const.BAG_KIND.BACKPACK].itemsBySlotKey) do
          if not item.isItemEmpty then committed[slotkey] = item.itemInfo.itemGUID end
        end
        return client, committed
      end

      it("never asks about a slot the client emptied, and commits what the client holds once it is quiet", function()
        local total = { read = 0, derive = 0, bank = 0, transfer = 0 }
        for s = 1, 60 do
          setup(s)
          local failure = run(300)
          if failure then
            error("seed " .. s .. ": " .. failure)
          end
          local client, committed = holdings()
          assert.same(client, committed, "seed " .. s)
          for k, v in pairs(sweeps) do total[k] = total[k] + v end
        end
        assert.is_true(total.read > 1000 and total.derive > 1000 and total.bank > 100 and total.transfer > 500,
          string.format("reads %d, recalculations %d, bank sweeps %d, loading screens %d",
            total.read, total.derive, total.bank, total.transfer))
      end)
    end)

    it("leaves an item read without its data whose slot now holds something else", function()
      local getItemInfo = _G.C_Item.GetItemInfo
      override(_G.C_Item, "GetItemInfo", function(itemID)
        if itemID == 909 then return nil end
        return getItemInfo(itemID)
      end)
      mockContainer[0] = { { itemID = 909, guid = "guid-909", count = 1 } }
      refreshBackpack()
      mockContainer[0] = { { itemID = 202, guid = "g202", count = 1 } }
      local item = refreshBackpack({ derive = true }).itemsBySlotKey["0_1"]
      assert.equal("guid-909", item.itemInfo.itemGUID)
    end)

    -- Opening or closing an interaction window recalculates the bags; the bank's only input
    -- that depends on it is stack unmerging (ShouldMergeItem). A capture of opening the bank
    -- showed the banker interaction recalculating the bank (149 ms) into the same layout its
    -- own read had just committed, already stacked for the open interaction.
    describe("NeedsInteractionRecalculation", function()
      local savedInteracting
      before_each(function()
        savedInteracting = addon.atInteracting
        override(database, "GetStackingOptions", function()
          return { mergeStacks = true, unmergeAtShop = true, mergeUnstackable = true }
        end)
        mockContainer[0] = { { itemID = 101, guid = "g101", count = 1 } }
      end)
      after_each(function() addon.atInteracting = savedInteracting end)

      it("is false when the committed stacks were built for the current interaction state", function()
        addon.atInteracting = true
        refreshBackpack()
        assert.is_false(items:NeedsInteractionRecalculation(const.BAG_KIND.BACKPACK))
      end)

      it("is true when the interaction state changed since, and false again once recalculated", function()
        addon.atInteracting = false
        refreshBackpack()
        addon.atInteracting = true
        assert.is_true(items:NeedsInteractionRecalculation(const.BAG_KIND.BACKPACK))
        refreshBackpack({ derive = true })
        assert.is_false(items:NeedsInteractionRecalculation(const.BAG_KIND.BACKPACK))
      end)

      it("is false when the kind does not unmerge at interactions", function()
        override(database, "GetStackingOptions", function()
          return { mergeStacks = true, unmergeAtShop = false, mergeUnstackable = true }
        end)
        addon.atInteracting = false
        refreshBackpack()
        addon.atInteracting = true
        assert.is_false(items:NeedsInteractionRecalculation(const.BAG_KIND.BACKPACK))
      end)

      it("is false when the kind has no committed items (its next read stacks them)", function()
        addon.atInteracting = false
        refreshBackpack()
        items:WipeSlotInfo(const.BAG_KIND.BACKPACK)
        addon.atInteracting = true
        assert.is_false(items:NeedsInteractionRecalculation(const.BAG_KIND.BACKPACK))
      end)
    end)

    -- A kind's first read is a wipe, which never marks the items it finds as new. A derive
    -- before it must leave it so, or the first read would put the whole bag in Recent Items.
    it("does nothing for a kind that has never been read, and the first read still marks nothing new", function()
      override(database, "GetMarkRecentItems", function() return true end)
      override(database, "GetCategoryFilter", function(_, _, filter) return filter == "RecentItems" end)
      items._firstLoad[const.BAG_KIND.BACKPACK] = true
      mockContainer[0] = { { itemID = 101, guid = "g101", count = 1 } }
      refreshBackpack({ derive = true })
      assert.equal(0, commits)
      assert.is_true(items._firstLoad[const.BAG_KIND.BACKPACK])
      local slotInfo = refreshBackpack()
      assert.are_not.equal("Recent Items", slotInfo.itemsBySlotKey["0_1"].itemInfo.category)
    end)

    -- Closing the bank empties its committed items; drawing a derive of them would show an
    -- empty bank.
    it("does nothing for a kind whose items were cleared", function()
      mockContainer[0] = { { itemID = 101, guid = "g101", count = 1 } }
      refreshBackpack()
      items:WipeSlotInfo(const.BAG_KIND.BACKPACK)
      commits = 0
      refreshBackpack({ derive = true })
      assert.equal(0, commits)
    end)

    it("leaves a sort's sweep pending: only a read shows a sort", function()
      mockContainer[0] = { { itemID = 101, guid = "g101", count = 1 } }
      refreshBackpack()
      items:MarkSortSweepPending(const.BAG_KIND.BACKPACK)
      refreshBackpack({ derive = true })
      assert.is_true(items:IsSortSweepPending(const.BAG_KIND.BACKPACK))
    end)

    it("starts a new draw generation only when the buttons are restyled", function()
      mockContainer[0] = { { itemID = 101, guid = "g101", count = 1 } }
      refreshBackpack()
      local generation = items._drawGeneration[const.BAG_KIND.BACKPACK]
      refreshBackpack({ derive = true })
      assert.equal(generation, items._drawGeneration[const.BAG_KIND.BACKPACK])
      local slotInfo = refreshBackpack({ derive = true, restyle = true })
      assert.equal(generation + 1, items._drawGeneration[const.BAG_KIND.BACKPACK])
      assert.equal(generation + 1, slotInfo.itemsBySlotKey["0_1"].drawGeneration)
    end)

    -- Upgrade arrows compare with the equipped gear, which a backpack read reads; a derive
    -- after a gear change must see the new gear.
    it("reads the equipped gear on a backpack derive", function()
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
      mockContainer[0] = { { itemID = 101, guid = "g101", count = 1 } }
      refreshBackpack()
      current = link:gsub("505:0", "505:6")
      refreshBackpack({ derive = true })
      assert.equal(current, items._equipped[5].link)
    end)
  end)

  -- One bag read on login (.claude/rules/refresh-scheduler.md §7 and §8). The queue merges
  -- requests that are still waiting, and holds every sweep at startup until the client has
  -- delivered the bags and their item data.
  describe("one bag read on login", function()
    local advance, timers, sweeps, harvests

    -- The hand-cranked clock of the scheduler tests, keeping timers with a real delay for
    -- the test to fire.
    local function installClock()
      async.Yield = function() coroutine.yield() end
      timers = {}
      saveGlobal(_G.C_Timer, "After")
      _G.C_Timer.After = function(delay, fn) table.insert(timers, { delay = delay, fn = fn }) end
      return function()
        local due, later = {}, {}
        for _, t in ipairs(timers) do
          if t.delay == 0 then due[#due + 1] = t.fn else later[#later + 1] = t end
        end
        timers = later
        for _, fn in ipairs(due) do fn() end
        return #due
      end
    end

    local function drain()
      for _ = 1, 100 do
        if advance() == 0 then return end
      end
      error("the refresh queue never went idle")
    end

    local function fireDelayed(delay)
      for i, t in ipairs(timers) do
        if t.delay == delay then
          table.remove(timers, i)
          t.fn()
          return true
        end
      end
      return false
    end

    local function resetEvents()
      if events._eventHandler then
        events._eventHandler:UnregisterAllEvents()
        events._eventHandler:UnregisterAllMessages()
      end
      events:Init()
    end

    before_each(function()
      resetEvents()
      advance = installClock()
      sweeps, harvests = {}, 0
      local run = items.RunRefresh
      override(items, "RunRefresh", function(self, ectx, kind)
        table.insert(sweeps, {
          kind = kind,
          wipe = ectx:Get("wipe") == true,
          bags = ectx:Get("targetedBags"),
          reset = ectx:Get("resetLayout") == true,
          derive = ectx:Get("derive") == true,
          restyle = ectx:Get("restyle") == true,
          categoriesUnchanged = ectx:Get("categoriesUnchanged") == true,
          recategorize = ectx:Get("recategorize") == true,
        })
        return run(self, ectx, kind)
      end)
      local harvest = items.Phase2_Harvest
      override(items, "Phase2_Harvest", function(...)
        harvests = harvests + 1
        return harvest(...)
      end)
      mockContainer[0] = { { itemID = 101, guid = "g101", count = 1 }, {} }
      mockContainer[1] = { { itemID = 201, guid = "g201", count = 1 } }
    end)

    after_each(function()
      resetEvents()
    end)

    describe("merging waiting requests", function()
      it("lets a waiting wipe absorb the requests that arrive after it", function()
        refresh:RequestUpdate({ backpack = true }) -- runs now and parks at its yield
        refresh:RequestUpdate({ wipe = true, backpack = true, bank = true })
        refresh:RequestUpdate({ backpack = true, bags = { [0] = true } })
        refresh:RequestUpdate({ wipe = true, backpack = true, bank = true })
        refresh:RequestUpdate({ backpack = true })
        drain()
        assert.equal(2, #sweeps)
        assert.is_false(sweeps[1].wipe)
        assert.is_true(sweeps[2].wipe)
      end)

      it("merges waiting plain requests and reads every bag any of them named", function()
        refresh:RequestUpdate({ backpack = true })
        refresh:RequestUpdate({ backpack = true, bags = { [0] = true } })
        refresh:RequestUpdate({ backpack = true, bags = { [1] = true } })
        drain()
        assert.equal(2, #sweeps)
        assert.same({ [0] = true, [1] = true }, sweeps[2].bags)
      end)

      it("reads every bag when one of the merged requests named none", function()
        refresh:RequestUpdate({ backpack = true })
        refresh:RequestUpdate({ backpack = true, bags = { [0] = true } })
        refresh:RequestUpdate({ backpack = true })
        drain()
        assert.equal(2, #sweeps)
        assert.is_nil(sweeps[2].bags)
      end)

      it("does not change the bag set a caller passed in", function()
        local named = { [0] = true }
        refresh:RequestUpdate({ backpack = true })
        refresh:RequestUpdate({ backpack = true, bags = named })
        refresh:RequestUpdate({ backpack = true, bags = { [1] = true } })
        drain()
        assert.same({ [0] = true }, named)
      end)

      it("keeps a wipe that arrives behind a waiting plain request separate", function()
        refresh:RequestUpdate({ backpack = true })
        refresh:RequestUpdate({ backpack = true, bags = { [0] = true } })
        refresh:RequestUpdate({ wipe = true, backpack = true, bank = true })
        drain()
        assert.equal(3, #sweeps)
        assert.is_false(sweeps[2].wipe)
        assert.is_true(sweeps[3].wipe)
      end)

      it("never merges a sort", function()
        local sorted = 0
        saveGlobal(_G.C_Container, "SortBags")
        _G.C_Container.SortBags = function() sorted = sorted + 1 end
        refresh:RequestUpdate({ backpack = true })
        refresh:RequestUpdate({ backpack = true })
        refresh:RequestUpdate({ sort = true })
        refresh:RequestUpdate({ backpack = true })
        refresh:RequestUpdate({ sort = true })
        drain()
        assert.equal(2, sorted)
        assert.equal(3, #sweeps)
      end)

      it("never merges the sort fallback", function()
        items:MarkSortSweepPending(const.BAG_KIND.BACKPACK)
        refresh:RequestUpdate({ backpack = true, bags = { [0] = true } })
        refresh:RequestUpdate({ backpack = true, onlyIfSortPending = true })
        refresh:RequestUpdate({ backpack = true, bags = { [1] = true } })
        drain()
        -- The first request shows the sort, so the fallback finds nothing to do and the
        -- last request is not folded into it.
        assert.equal(2, #sweeps)
        assert.same({ [1] = true }, sweeps[2].bags)
      end)

      it("merges a layout reset only into a waiting wipe", function()
        refresh:RequestUpdate({ backpack = true })
        refresh:RequestUpdate({ backpack = true })
        refresh:RequestUpdate({ backpack = true, resetLayout = true })
        drain()
        assert.equal(3, #sweeps)
        assert.is_false(sweeps[2].reset)
        assert.is_true(sweeps[3].reset)

        sweeps = {}
        refresh:RequestUpdate({ backpack = true })
        refresh:RequestUpdate({ wipe = true, backpack = true, bank = true })
        refresh:RequestUpdate({ backpack = true, resetLayout = true })
        drain()
        assert.equal(2, #sweeps)
        assert.is_true(sweeps[2].wipe)
      end)

      -- Merging must leave the bags exactly as running the requests one at a time would,
      -- including which items count as newly acquired.
      for _, order in ipairs({ { "plain", "wipe" }, { "wipe", "plain" } }) do
        it("ends in the same state as running the requests one at a time (" .. order[1] .. ", then " .. order[2] .. ")", function()
          override(database, "GetMarkRecentItems", function() return true end)
          override(database, "GetCategoryFilter", function(_, _, filter) return filter == "RecentItems" end)
          local function request(name)
            if name == "wipe" then return { wipe = true, backpack = true, bank = true } end
            return { backpack = true, bags = { [0] = true } }
          end
          local function scenario(together)
            search:Init()
            items:Init()
            items._firstLoad[const.BAG_KIND.BACKPACK] = false
            items._firstLoad[const.BAG_KIND.BANK] = false
            refresh:Init()
            mockContainer[0] = { { itemID = 101, guid = "g101", count = 1 }, {} }
            refresh:RequestUpdate({ backpack = true })
            drain()
            -- This unit harvests now; the loot lands while it is parked.
            refresh:RequestUpdate({ backpack = true })
            mockContainer[0][2] = { itemID = 202, guid = "g202", count = 1 }
            if together then
              refresh:RequestUpdate(request(order[1]))
              refresh:RequestUpdate(request(order[2]))
              drain()
            else
              drain()
              refresh:RequestUpdate(request(order[1]))
              drain()
              refresh:RequestUpdate(request(order[2]))
              drain()
            end
            local out = {}
            for slotkey, item in pairs(items.slotInfo[const.BAG_KIND.BACKPACK].itemsBySlotKey) do
              out[slotkey] = (item.isItemEmpty and "empty" or item.itemInfo.itemGUID) .. "|" .. tostring(item.itemInfo and item.itemInfo.category)
            end
            for guid in pairs(items._newItemTimers[const.BAG_KIND.BACKPACK]) do
              out["timer " .. guid] = true
            end
            return out
          end
          assert.same(scenario(false), scenario(true))
        end)
      end
    end)

    -- A derive reads no bag. It rides on a waiting read that reads every bag of its kinds,
    -- since that read recalculates everything too; a read can never ride on a derive.
    describe("merging derives", function()
      before_each(function()
        addon.atBank = true
        addon.Bags = { Bank = {} }
        mockContainer[6] = { { itemID = 201, guid = "g201b", count = 1 } }
        refresh:RequestUpdate({ backpack = true, bank = true })
        drain()
        sweeps = {}
      end)

      it("merges waiting derives, with the kinds and restyles of both", function()
        refresh:RequestUpdate({ backpack = true }) -- runs now
        refresh:RequestUpdate({ derive = true, backpack = true })
        refresh:RequestUpdate({ derive = true, bank = true, restyle = true })
        drain()
        assert.equal(3, #sweeps)
        assert.same({ const.BAG_KIND.BANK, true, true }, { sweeps[2].kind, sweeps[2].derive, sweeps[2].restyle })
        assert.same({ const.BAG_KIND.BACKPACK, true, true }, { sweeps[3].kind, sweeps[3].derive, sweeps[3].restyle })
      end)

      it("rides on a waiting read of every bag of its kinds", function()
        refresh:RequestUpdate({ backpack = true })
        refresh:RequestUpdate({ backpack = true })
        refresh:RequestUpdate({ derive = true, backpack = true, restyle = true })
        drain()
        assert.equal(2, #sweeps)
        assert.is_false(sweeps[2].derive)
        assert.is_true(sweeps[2].restyle)
      end)

      -- data-loader.md §18: kept categories stand only when every merged request says nothing they
      -- read changed. A read keeps them, so one that absorbs a recalculation that changed them must
      -- work them out again.
      it("keeps categories only when every merged derive says they are unchanged", function()
        refresh:RequestUpdate({ backpack = true }) -- runs now
        refresh:RequestUpdate({ derive = true, backpack = true, categoriesUnchanged = true })
        refresh:RequestUpdate({ derive = true, backpack = true, categoriesUnchanged = true })
        drain()
        assert.equal(2, #sweeps)
        assert.is_true(sweeps[2].categoriesUnchanged)
        sweeps = {}
        refresh:RequestUpdate({ backpack = true })
        refresh:RequestUpdate({ derive = true, backpack = true, categoriesUnchanged = true })
        refresh:RequestUpdate({ derive = true, backpack = true })
        drain()
        assert.equal(2, #sweeps)
        assert.is_false(sweeps[2].categoriesUnchanged, "one changed them")
      end)

      it("makes a read that absorbs a recalculation of categories work them out again", function()
        refresh:RequestUpdate({ backpack = true }) -- runs now
        refresh:RequestUpdate({ backpack = true })
        refresh:RequestUpdate({ derive = true, backpack = true, categoriesUnchanged = true })
        drain()
        assert.is_false(sweeps[2].recategorize, "nothing changed them")
        sweeps = {}
        refresh:RequestUpdate({ backpack = true })
        refresh:RequestUpdate({ backpack = true })
        refresh:RequestUpdate({ derive = true, backpack = true })
        drain()
        assert.equal(2, #sweeps)
        assert.is_false(sweeps[2].derive)
        assert.is_true(sweeps[2].recategorize)
      end)

      it("works categories out again after a merged read that absorbed their change", function()
        local custom
        override(categories, "GetCustomCategory", function(_, _, _, data)
          if custom and data.itemInfo.itemID == 101 then return custom, 10 end
          return nil, nil
        end)
        mockContainer[0] = { { itemID = 101, guid = "g101b", count = 1 } }
        refresh:RequestUpdate({ backpack = true, wipe = true })
        drain()
        custom = "Swords"
        refresh:RequestUpdate({ backpack = true }) -- runs now
        refresh:RequestUpdate({ backpack = true })
        refresh:RequestUpdate({ derive = true, backpack = true })
        drain()
        assert.equal("Swords", items.slotInfo[const.BAG_KIND.BACKPACK].itemsBySlotKey["0_1"].itemInfo.category)
      end)

      -- A targeted read carries the other bags' items over without refreshing them, so it
      -- would not do what the derive asked for (a re-scanned tooltip in another bag).
      it("does not ride on a waiting read of some bags", function()
        refresh:RequestUpdate({ backpack = true })
        refresh:RequestUpdate({ backpack = true, bags = { [0] = true } })
        refresh:RequestUpdate({ derive = true, backpack = true })
        drain()
        assert.equal(3, #sweeps)
        assert.is_true(sweeps[3].derive)
      end)

      it("does not ride on a waiting read of fewer kinds", function()
        refresh:RequestUpdate({ backpack = true })
        refresh:RequestUpdate({ backpack = true })
        refresh:RequestUpdate({ derive = true, backpack = true, bank = true })
        drain()
        assert.equal(4, #sweeps)
        assert.is_true(sweeps[3].derive)
        assert.is_true(sweeps[4].derive)
      end)

      it("never lets a read ride on a waiting derive", function()
        refresh:RequestUpdate({ backpack = true })
        refresh:RequestUpdate({ derive = true, backpack = true })
        refresh:RequestUpdate({ backpack = true })
        drain()
        assert.equal(3, #sweeps)
        assert.is_true(sweeps[2].derive)
        assert.is_false(sweeps[3].derive)
      end)

      it("rides on a waiting wipe", function()
        refresh:RequestUpdate({ backpack = true })
        refresh:RequestUpdate({ wipe = true, backpack = true, bank = true })
        refresh:RequestUpdate({ derive = true, backpack = true })
        drain()
        assert.equal(3, #sweeps)
        assert.is_true(sweeps[2].wipe and sweeps[3].wipe)
      end)

      it("merges a layout reset only with another reset", function()
        refresh:RequestUpdate({ backpack = true })
        refresh:RequestUpdate({ derive = true, backpack = true })
        refresh:RequestUpdate({ derive = true, backpack = true, resetLayout = true })
        drain()
        assert.equal(3, #sweeps)
        assert.is_false(sweeps[2].reset)
        assert.is_true(sweeps[3].reset)
      end)
    end)

    describe("the startup read", function()
      local primed, held, released, loaderCallback

      local function gateEvent(name, ...)
        local frame = refresh._worldFrame
        if frame and frame._events[name] then
          frame:GetScript("OnEvent")(frame, name, ...)
        end
      end

      -- A WoW event reaches every listener: the events module's handlers and the startup
      -- frame.
      local function fire(name, ...)
        local entry = events._eventMap[name]
        if entry then entry.fn(name, ...) end
        gateEvent(name, ...)
      end

      local function frame()
        local f = refresh._worldFrame
        local onUpdate = f and f:GetScript("OnUpdate")
        if onUpdate then onUpdate(f, 0.016) end
        advance()
      end

      before_each(function()
        primed, held, released, loaderCallback = nil, 0, 0, nil
        local loader = addon:GetModule("ItemLoader")
        override(loader, "TellMeWhenABagIsUpdated", function(_, cb) loaderCallback = cb end)
        override(loader, "Hold", function() held = held + 1 end)
        override(loader, "Release", function() released = released + 1 end)
        override(loader, "PrimeAll", function(_, cb) primed = cb end)
      end)

      it("holds every sweep until the client has delivered the bags", function()
        refresh:OnEnable()
        assert.equal(1, held)
        refresh:RequestUpdate({ wipe = true, backpack = true, bank = true })
        refresh:RequestUpdate({ backpack = true })
        fire("PLAYER_ENTERING_WORLD", true, false)
        fire("BAG_CONTAINER_UPDATE")
        drain()
        assert.equal(0, harvests)
      end)

      it("reads every bag once, after the first quiet frame past the loading screen and the item data", function()
        refresh:OnEnable()
        events:SendMessage(context:New("Themes_OnEnable"), "bags/FullRefreshAll")
        fire("BAG_CONTAINER_UPDATE")
        loaderCallback({ [0] = true, [1] = true })
        refresh:RequestUpdate({ backpack = true })

        fire("LOADING_SCREEN_DISABLED")
        fire("BAG_UPDATE", 0)
        frame() -- bags still changing this frame
        assert.is_nil(primed)
        frame() -- quiet
        assert.is_function(primed)
        assert.equal(0, harvests, "nothing is read while the item data loads")

        primed()
        drain()
        assert.equal(1, harvests)
        assert.equal(1, #sweeps)
        assert.is_true(sweeps[1].wipe)
        assert.equal(1, released)
        assert.is_not_nil(items.slotInfo[const.BAG_KIND.BACKPACK].itemsBySlotKey["1_1"])
      end)

      it("runs a sort asked for before the read after it", function()
        local sorted = 0
        saveGlobal(_G.C_Container, "SortBags")
        _G.C_Container.SortBags = function() sorted = sorted + 1 end
        refresh:OnEnable()
        refresh:RequestUpdate({ sort = true })
        refresh:RequestUpdate({ backpack = true })
        fire("LOADING_SCREEN_DISABLED")
        frame()
        primed()
        assert.equal(0, sorted, "the read comes first")
        drain()
        assert.equal(1, sorted)
        assert.equal(1, harvests)
      end)

      it("reads at the timeout when the item data is slow, and once more when it arrives", function()
        refresh:OnEnable()
        fire("LOADING_SCREEN_DISABLED")
        frame()
        assert.is_function(primed)
        assert.is_true(fireDelayed(refresh.WORLD_PRIME_TIMEOUT))
        drain()
        assert.equal(1, harvests)
        assert.is_true(sweeps[1].wipe)

        primed()
        drain()
        assert.equal(2, harvests)
        assert.is_false(sweeps[2].wipe)
        assert.is_nil(sweeps[2].bags)
      end)

      it("does not read again when the timeout fires after the item data arrived", function()
        refresh:OnEnable()
        fire("LOADING_SCREEN_DISABLED")
        frame()
        primed()
        drain()
        fireDelayed(refresh.WORLD_PRIME_TIMEOUT)
        drain()
        assert.equal(1, harvests)
      end)

      it("stops waiting for a quiet frame after the settle timeout", function()
        local now = 100
        saveGlobal(_G, "GetTime")
        _G.GetTime = function() return now end
        refresh:OnEnable()
        fire("LOADING_SCREEN_DISABLED")
        for _ = 1, 5 do
          fire("BAG_UPDATE", 0)
          frame()
        end
        assert.is_nil(primed)
        now = 100 + refresh.WORLD_SETTLE_TIMEOUT
        fire("BAG_UPDATE", 0)
        frame()
        assert.is_function(primed)
      end)

      it("reads at once when the backpack opens before the read, and again for the item data", function()
        addon.Bags = { Backpack = { frame = CreateFrame("Frame") } }
        refresh:OnEnable()
        fire("PLAYER_ENTERING_WORLD", true, false)
        local bagFrame = addon.Bags.Backpack.frame
        bagFrame:GetScript("OnShow")(bagFrame)
        drain()
        assert.equal(1, harvests)
        assert.is_true(sweeps[1].wipe)
        -- The item data it did not wait for is still loaded, and read when it arrives.
        assert.is_function(primed)
        primed()
        drain()
        assert.equal(2, harvests)
        fire("LOADING_SCREEN_DISABLED")
        frame()
        drain()
        assert.equal(2, harvests, "the startup wait is over")
      end)

      it("loads the item data once when the backpack opens while it loads", function()
        override(addon, "Bags", { Backpack = { frame = CreateFrame("Frame") } })
        local primes = 0
        local loader = addon:GetModule("ItemLoader")
        override(loader, "PrimeAll", function(_, cb) primes = primes + 1 primed = cb end)
        refresh:OnEnable()
        fire("LOADING_SCREEN_DISABLED")
        frame()
        assert.equal(1, primes)
        local bagFrame = addon.Bags.Backpack.frame
        bagFrame:GetScript("OnShow")(bagFrame)
        drain()
        assert.equal(1, harvests, "read at once")
        assert.equal(1, primes, "the item data already loading is not loaded again")
      end)

      it("reads once when the backpack opens and the item data is already loaded", function()
        addon.Bags = { Backpack = { frame = CreateFrame("Frame") } }
        local loader = addon:GetModule("ItemLoader")
        override(loader, "PrimeAll", function(_, cb) cb() end)
        refresh:OnEnable()
        local bagFrame = addon.Bags.Backpack.frame
        bagFrame:GetScript("OnShow")(bagFrame)
        drain()
        assert.equal(1, harvests)
      end)

      it("starts on PLAYER_ENTERING_WORLD on a client without LOADING_SCREEN_DISABLED", function()
        saveGlobal(_G, "C_EventUtils")
        _G.C_EventUtils = { IsEventValid = function(name) return name ~= "LOADING_SCREEN_DISABLED" end }
        refresh:OnEnable()
        fire("PLAYER_ENTERING_WORLD", true, false)
        frame()
        assert.is_function(primed)
      end)

      it("starts anyway when the loading screen never reports its end", function()
        refresh:OnEnable()
        fire("PLAYER_ENTERING_WORLD", true, false)
        frame()
        assert.is_nil(primed)
        assert.is_true(fireDelayed(refresh.WORLD_LOADING_TIMEOUT))
        frame()
        assert.is_function(primed)
      end)

      -- After the one read at login, tooltip text resolving, gear sets and upgrade inputs
      -- changing are recalculated from the items already read (refresh-scheduler.md §10).
      -- Replays the bank open of a capture (session #1, 21:49) in its order: BANKFRAME_OPENED
      -- at 1.25 s with the bank's item data not loaded (478 of 491 items read cold), the banker
      -- interaction's recalculation at 2.08 s, then at 2.51 s the item data arriving with the
      -- tooltip resolution it sets off. The bank must be read once, warm, and not move after.
      -- The window's show animation (0.1 s classic, 0.45 s Next) ends before the interaction;
      -- nothing loads until it has (refresh-scheduler.md §11).
      it("reads the bank once, warm, through a bank open in the captured order", function()
        items:OnEnable()
        refresh:OnEnable()
        mockContainer[0] = { { itemID = 101, guid = "g101", count = 1 } }
        fire("LOADING_SCREEN_DISABLED")
        frame()
        primed()
        drain()

        local bankCold = true
        local getItemInfo = _G.C_Item.GetItemInfo
        override(_G.C_Item, "GetItemInfo", function(item)
          local id = tonumber(tostring(item):match("item:(%d+)") or item)
          if bankCold and id and id >= 601 and id <= 603 then return nil end
          return getItemInfo(item)
        end)
        mockContainer[6] = {
          { itemID = 601, guid = "g601", count = 1 },
          { itemID = 602, guid = "g602", count = 1 },
          { itemID = 603, guid = "g603", count = 1 },
        }
        local loader = addon:GetModule("ItemLoader")
        local bankPrimed
        override(loader, "PrimeBank", function(_, _, cb) bankPrimed = cb end)
        override(database, "GetShowBankTabs", function() return false end)
        override(_G, "GameMenuFrame", { IsShown = function() return false end })
        local shown, bankShown = 0, nil
        override(addon, "Bags", { Bank = { bankTab = 6, Show = function(_, _, _, onShown)
          shown = shown + 1
          bankShown = onShown
        end } })
        override(addon, "atBank", false)
        override(addon, "atInteracting", false)

        local bankReads, coldReads = 0, 0
        local harvest = items.Phase2_Harvest
        override(items, "Phase2_Harvest", function(self, kind, ...)
          if kind == const.BAG_KIND.BANK then
            bankReads = bankReads + 1
            if bankCold then coldReads = coldReads + 1 end
          end
          return harvest(self, kind, ...)
        end)
        local layouts = {}
        local commit = items.Phase11_CommitAndDispatch
        override(items, "Phase11_CommitAndDispatch", function(self, ectx, kind, ...)
          local result = commit(self, ectx, kind, ...)
          if kind == const.BAG_KIND.BANK then
            local order, cold = {}, false
            for _, item in ipairs(self.slotInfo[kind].sortedItems) do
              order[#order + 1] = item.slotkey .. "|" .. tostring(item.itemInfo and item.itemInfo.category)
              if item.harvestIncomplete then cold = true end
            end
            table.insert(layouts, { order = table.concat(order, ","), cold = cold })
          end
          return result
        end)

        fire("BANKFRAME_OPENED")
        drain()
        assert.equal(1, shown, "the bank shows at once")
        assert.is_nil(bankPrimed, "nothing loads while its window shows")
        bankShown()
        drain()
        assert.is_function(bankPrimed, "loading once it has shown")
        assert.equal(0, bankReads, "and is not read while its item data loads")

        -- What core/hooks.lua sends when the banker interaction opens the backpack
        -- (spec/core/interaction_refresh_spec.lua).
        addon.atInteracting = true
        events:SendMessage(context:New("PLAYER_INTERACTION_MANAGER_FRAME_SHOW"), "bags/Rederive", {
          resetLayout = true, backpack = true,
          bank = items:NeedsInteractionRecalculation(const.BAG_KIND.BANK),
        })
        drain()
        assert.equal(0, #layouts, "the interaction does not recalculate a bank that has not been read")

        bankCold = false
        bankPrimed()
        drain()
        events:SendMessage(context:New("TooltipDataResolved"), "bags/Rederive", { backpack = true, bank = true })
        drain()

        assert.equal(1, bankReads, "read once")
        assert.equal(0, coldReads, "after its item data loaded")
        assert.equal(2, #layouts)
        assert.is_false(layouts[1].cold or layouts[2].cold, "nothing committed cold")
        assert.equal(layouts[1].order, layouts[2].order, "nothing moves after the open")
      end)

      -- The bank is read tab by tab as it opens, as the guild bank is (refresh-scheduler.md §11):
      -- each read shows one more tab, frames apart, the tab shown first. Asked: "pop in data for each
      -- physical tab (non-virtual tab) one by one ... mimic the guild bank behavior as close as
      -- possible". A captured open (500 items) read and drew them all in one 520 ms frame.
      describe("opening the bank, tab by tab", function()
        local bankShown, commits, frameNo, loads

        -- run steps the queue frame by frame until it is idle, numbering the frames.
        local function run()
          for _ = 1, 100 do
            frameNo = frameNo + 1
            if advance() == 0 then return end
          end
          error("the refresh queue never went idle")
        end

        local function shownTabs(i)
          return commits[i] and commits[i].bags
        end

        before_each(function()
          items:OnEnable()
          refresh:OnEnable()
          mockContainer[0] = { { itemID = 101, guid = "g101", count = 1 } }
          fire("LOADING_SCREEN_DISABLED")
          frame()
          primed()
          drain()
          mockContainer[6] = { { itemID = 601, guid = "g601", count = 1 }, {} }
          mockContainer[7] = { { itemID = 701, guid = "g701", count = 1 } }
          mockContainer[13] = { { itemID = 1301, guid = "g1301", count = 1 } }
          loads = {}
          local loader = addon:GetModule("ItemLoader")
          override(loader, "PrimeBank", function(_, bags, cb)
            assert.equal(1, #bags, "a load per tab")
            loads[bags[1]] = cb
          end)
          override(database, "GetShowBankTabs", function() return false end)
          override(_G, "GameMenuFrame", { IsShown = function() return false end })
          override(addon, "Bags", { Bank = { bankTab = 6, Show = function(_, _, _, onShown)
            bankShown = onShown
          end } })
          override(addon, "atBank", false)
          frameNo = 0
          commits = {}
          local commit = items.Phase11_CommitAndDispatch
          override(items, "Phase11_CommitAndDispatch", function(self, ectx, kind, ...)
            local result = commit(self, ectx, kind, ...)
            if kind == const.BAG_KIND.BANK then
              local bags, seen = {}, {}
              for _, item in pairs(self.slotInfo[kind].itemsBySlotKey) do
                if not item.isItemEmpty and not seen[item.bagid] then
                  seen[item.bagid] = true
                  bags[#bags + 1] = item.bagid
                end
              end
              table.sort(bags)
              table.insert(commits, { bags = table.concat(bags, ","), frame = frameNo })
            end
            return result
          end)
        end)

        local function open()
          fire("BANKFRAME_OPENED")
          drain()
          bankShown()
        end

        local function loadAll()
          for _, bag in ipairs({ 6, 7, 13 }) do
            if loads[bag] then loads[bag]() end
          end
        end

        it("shows one more tab with each read, frames apart, the shown bank type first", function()
          open()
          loadAll()
          run()
          assert.equal(3, #commits)
          assert.are.same({ "6", "6,7", "6,7,13" }, { shownTabs(1), shownTabs(2), shownTabs(3) })
          assert.is_true(commits[2].frame - commits[1].frame >= 2, "a read per unit: commit, idle, read")
          assert.is_true(commits[3].frame - commits[2].frame >= 2)
          local bankSweeps = {}
          for _, sweep in ipairs(sweeps) do
            if sweep.kind == const.BAG_KIND.BANK then bankSweeps[#bankSweeps + 1] = sweep end
          end
          assert.equal(3, #bankSweeps)
          assert.is_true(bankSweeps[1].reset, "the first read afresh")
          assert.is_false(bankSweeps[2].reset)
          assert.is_false(bankSweeps[3].reset)
          assert.is_nil(items:LoadedBankBags(), "every tab read")
        end)

        it("reads the Warbank first while it shows", function()
          addon.Bags.Bank.bankTab = 13
          open()
          loadAll()
          run()
          assert.are.same({ "13", "6,13", "6,7,13" }, { shownTabs(1), shownTabs(2), shownTabs(3) })
        end)

        it("shows only the tabs loaded to a bank read asked for while it loads", function()
          open()
          loads[6]()
          run()
          refresh:RequestUpdate({ bank = true, bags = { [13] = true } })
          refresh:RequestUpdate({ wipe = true })
          run()
          for _, c in ipairs(commits) do
            assert.equal("6", c.bags, "the Warbank's tab is not read before its turn")
          end
          loads[7]()
          loads[13]()
          run()
          assert.equal("6,7,13", commits[#commits].bags)
        end)

        it("reads a tab that gains slots after the open, like any change", function()
          mockContainer[7] = {}
          open()
          loadAll()
          run()
          assert.equal("6,13", commits[#commits].bags)
          mockContainer[7] = { { itemID = 701, guid = "g701", count = 1 } }
          refresh:RequestUpdate({ bank = true })
          run()
          assert.equal("6,7,13", commits[#commits].bags)
        end)

        -- A read of an open that ended finishing while the next open loads must not load the next
        -- open's next tab before that open's own read has run.
        it("lets only an open's own read load its next tab", function()
          fire("BANKFRAME_OPENED")
          drain()
          bankShown()
          loads[6]() -- the first open's read: harvested now, parked until the next frame
          fire("BANKFRAME_CLOSED")
          loads = {}
          fire("BANKFRAME_OPENED")
          bankShown()
          loadAll() -- the second open's first read waits behind the first open's
          assert.equal(1, #refresh._queue)
          advance() -- the first open's read finishes
          assert.equal(1, #refresh._queue, "the second open still waits for its own read")
          run()
          assert.are.same({ "6", "6", "6,7", "6,7,13" }, { shownTabs(1), shownTabs(2), shownTabs(3), shownTabs(4) })
        end)

        it("starts over, afresh, when the bank closes while it loads and opens again", function()
          open()
          loads[6]()
          run()
          fire("BANKFRAME_CLOSED")
          items:ClearBankCache(context:New("Close"))
          addon.atBank = false
          loads[7]()
          run()
          assert.equal(1, #commits, "the closed open reads nothing more")
          loads = {}
          addon.Bags.Bank.bankTab = 13
          open()
          loadAll()
          run()
          assert.are.same({ "13", "6,13", "6,7,13" }, { shownTabs(2), shownTabs(3), shownTabs(4) })
        end)
      end)

      it("recalculates, without reading the bags again, what changes after the read", function()
        items:OnEnable()
        refresh:OnEnable()
        mockContainer[0] = { { itemID = 101, guid = "g101", count = 1 }, {} }
        fire("LOADING_SCREEN_DISABLED")
        frame()
        primed()
        drain()
        assert.equal(1, harvests)
        local units = #sweeps

        events:SendMessage(context:New("TooltipDataResolved"), "bags/Rederive", { backpack = true, bank = false })
        fire("EQUIPMENT_SETS_CHANGED")
        fire("PLAYER_EQUIPMENT_CHANGED", 5, true)
        fire("SKILL_LINES_CHANGED")
        drain()
        assert.equal(1, harvests, "nothing read the bags again")
        assert.is_true(#sweeps > units, "the bags were recalculated")
        for i = units + 1, #sweeps do
          assert.is_true(sweeps[i].derive)
        end
      end)

      it("lets go of every startup event once the read has run", function()
        refresh:OnEnable()
        local startupFrame = refresh._worldFrame
        fire("LOADING_SCREEN_DISABLED")
        frame()
        primed()
        drain()
        assert.is_nil(startupFrame:GetScript("OnUpdate"))
        assert.same({}, startupFrame._events)
      end)

      -- The captured login (BetterBags 12.1.0, a full relaunch with a cold cache): the first
      -- sweep ran inside OnEnable and saw a backpack of 20 empty slots; the bags attached
      -- (BAG_CONTAINER_UPDATE x14) and the items arrived over the next five seconds, and 25
      -- refresh units followed, 17 of them full wipes.
      it("reads the bags once on a login like the captured one, and marks nothing as new", function()
        override(database, "GetMarkRecentItems", function() return true end)
        override(database, "GetCategoryFilter", function(_, _, filter) return filter == "RecentItems" end)
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
        items._firstLoad[const.BAG_KIND.BACKPACK] = true
        items._firstLoad[const.BAG_KIND.BANK] = true

        -- PLAYER_LOGIN: the backpack has slots but nothing in them, the other bags are absent.
        local empty = {}
        for i = 1, 20 do empty[i] = {} end
        mockContainer = { [0] = empty }
        items:OnEnable()
        refresh:OnEnable()
        events:SendMessage(context:New("Themes_OnEnable"), "bags/FullRefreshAll")

        fire("PLAYER_ENTERING_WORLD", false, false)
        fire("SKILL_LINES_CHANGED")
        fire("LEARNED_SPELL_IN_SKILL_LINE", 12345, 1, false)
        advance()
        -- The bags attach and the items arrive, in bursts.
        mockContainer[1] = { { itemID = 201, guid = "g201", count = 1 }, {} }
        for _ = 1, 14 do fire("BAG_CONTAINER_UPDATE") end
        for slot = 1, 10 do
          mockContainer[0][slot] = { itemID = 100 + slot, guid = "g" .. (100 + slot), count = 1 }
          fire("BAG_UPDATE", 0)
        end
        fire("BAG_UPDATE_DELAYED")
        loaderCallback({ [0] = true, [1] = true })
        -- The config sliders' delayed refreshes.
        events:SendMessage(context:New("OnValueChanged"), "bags/FullRefreshAll")
        events:SendMessage(context:New("OnValueChanged"), "bags/FullRefreshAll")

        fire("LOADING_SCREEN_DISABLED")
        fire("BAG_UPDATE", 1)
        frame()
        frame()
        primed()
        drain()
        for _ = 1, 3 do frame() end
        drain()

        assert.equal(1, harvests, "one read of the bags")
        local slotInfo = items.slotInfo[const.BAG_KIND.BACKPACK]
        assert.is_not_nil(slotInfo.itemsBySlotKey["0_10"])
        assert.is_not_nil(slotInfo.itemsBySlotKey["1_1"])
        for slotkey, item in pairs(slotInfo.itemsBySlotKey) do
          if not item.isItemEmpty then
            assert.are_not.equal("Recent Items", item.itemInfo.category, slotkey .. " was in the bags at login")
          end
        end
      end)
    end)

    -- Entering a dungeon is a world transfer: the client takes the player's items away for the
    -- loading screen and gives them back after, with no BAG_UPDATE on the way out (BAG_UPDATE fires
    -- the moment a bag's contents change: SynchronousEvent, ContainerDocumentation.lua). Reported:
    -- "4x data/items.lua:1197: bad argument #1 to 'GetItemGUID' (Usage: local itemGUID =
    -- C_Item.GetItemGUID(itemLocation))" as a player went into a dungeon, from a window closing
    -- (CloseInteractionWindow, core/hooks.lua): its recalculation ran in the event and asked the client
    -- about slots the transfer had emptied. Every loading screen is now held as the login is
    -- (refresh-scheduler.md §8).
    describe("leaving the world (every loading screen)", function()
      local primed, held, released, errors, asked

      local function worldEvent(name, ...)
        local f = refresh._worldFrame
        if f and f._events[name] then
          f:GetScript("OnEvent")(f, name, ...)
        end
      end

      -- A WoW event reaches every listener: the events module's handlers and the world frame.
      local function fire(name, ...)
        local entry = events._eventMap[name]
        if entry then entry.fn(name, ...) end
        worldEvent(name, ...)
      end

      local function frame()
        local f = refresh._worldFrame
        local onUpdate = f and f:GetScript("OnUpdate")
        if onUpdate then onUpdate(f, 0.016) end
        advance()
      end

      -- The player's items, as the client holds them in the world.
      local function giveBack()
        mockContainer[0] = { { itemID = 101, guid = "g101", count = 1 }, {} }
        mockContainer[1] = { { itemID = 201, guid = "g201", count = 1 } }
      end
      -- The transfer takes them away, with no BAG_UPDATE.
      local function takeAway()
        mockContainer[0] = { {}, {} }
        mockContainer[1] = { {} }
      end

      -- A window closing asks for this recalculation (CloseInteractionWindow, interactionRecalculation).
      local function closeWindow()
        events:SendMessage(context:New("PLAYER_INTERACTION_MANAGER_FRAME_HIDE"), "bags/Rederive",
          { resetLayout = true, backpack = true, bank = false, categoriesUnchanged = true })
      end

      -- Logged in: the login's read has run.
      local function login()
        refresh:OnEnable()
        fire("LOADING_SCREEN_DISABLED")
        frame()
        primed()
        drain()
        primed = nil
      end

      local function committed()
        return items.slotInfo[const.BAG_KIND.BACKPACK].itemsBySlotKey
      end

      before_each(function()
        primed, held, released = nil, 0, 0
        local loader = addon:GetModule("ItemLoader")
        override(loader, "TellMeWhenABagIsUpdated", function() end)
        override(loader, "Hold", function() held = held + 1 end)
        override(loader, "Release", function() released = released + 1 end)
        override(loader, "PrimeAll", function(_, cb) primed = cb end)
        errors = {}
        saveGlobal(_G, "geterrorhandler")
        _G.geterrorhandler = function() return function(err) table.insert(errors, tostring(err)) end end
        -- Every slot the client is asked an item's GUID about.
        asked = {}
        local guid = _G.C_Item.GetItemGUID
        override(_G.C_Item, "GetItemGUID", function(location)
          local bagid, slotid = location:GetBagAndSlot()
          if bagid ~= nil then table.insert(asked, bagid .. "_" .. slotid) end
          return guid(location)
        end)
        giveBack()
      end)

      it("recalculates nothing while out of the world, then reads the bags once: the reported dungeon entry", function()
        login()
        local before = #sweeps
        fire("PLAYER_LEAVING_WORLD")
        takeAway()
        -- Windows close as the transfer starts (the report's 4x: as many as closed).
        closeWindow()
        closeWindow()
        drain()
        assert.same({}, errors)
        assert.equal(before, #sweeps, "nothing swept while out of the world")

        fire("PLAYER_ENTERING_WORLD", false, false)
        fire("LOADING_SCREEN_DISABLED")
        giveBack()
        fire("BAG_UPDATE", 0)
        fire("BAG_UPDATE", 1)
        frame() -- the items arriving
        assert.is_nil(primed)
        frame() -- quiet
        assert.is_function(primed)
        primed()
        drain()

        assert.same({}, errors)
        assert.equal(before + 1, #sweeps, "one read takes in both windows' recalculations")
        assert.is_true(sweeps[#sweeps].wipe)
        assert.equal("g101", committed()["0_1"].itemInfo.itemGUID)
        assert.equal("g201", committed()["1_1"].itemInfo.itemGUID)
        assert.is_nil(next(items._newItemTimers[const.BAG_KIND.BACKPACK] or {}), "nothing came in as new")
        assert.equal(2, held)
        assert.equal(2, released)
      end)

      -- Captured in game, a trip into an instance and back out (BetterBags' profiler, both bag counts
      -- recorded at each event): the client takes the player's items away after LOADING_SCREEN_ENABLED and
      -- before PLAYER_LEAVING_WORLD, which came 1.9 s (in) and 0.9 s (out) later, with 464 frames run in
      -- between on the way in. At LOADING_SCREEN_ENABLED the backpack held its 26 items, all existing; at
      -- PLAYER_LEAVING_WORLD, none, and no slot. Reported three times after the world was held from
      -- PLAYER_LEAVING_WORLD on: the GetItemGUID error with the queue not held (_held=false), from a tooltip
      -- that finished loading (its bucket's timer), from a window closing, and from the queue's step.
      local function tooltipLoaded()
        events:SendMessage(context:New("TooltipDataResolved"), "bags/Rederive",
          { backpack = true, bank = false, categoriesUnchanged = true })
      end

      it("holds from the loading screen's start, before the client takes the items away (captured)", function()
        login()
        local before = #sweeps
        asked = {}
        fire("LOADING_SCREEN_ENABLED")
        frame()
        takeAway()
        frame()
        -- Before PLAYER_LEAVING_WORLD: a window closes as the player zones, a tooltip finishes loading.
        closeWindow()
        tooltipLoaded()
        frame()
        drain()
        assert.same({}, errors)
        assert.same({}, asked, "the client is asked about no slot during the loading screen")
        assert.equal(before, #sweeps, "nothing swept during the loading screen")

        fire("PLAYER_LEAVING_WORLD")
        fire("PLAYER_ENTERING_WORLD", false, false)
        fire("LOADING_SCREEN_DISABLED")
        giveBack()
        fire("BAG_UPDATE", 0)
        fire("BAG_UPDATE", 1)
        frame() -- the items arriving
        frame() -- quiet
        primed()
        drain()
        assert.same({}, errors)
        assert.equal(before + 1, #sweeps, "one read takes in the window's and the tooltip's recalculations")
        assert.is_true(sweeps[#sweeps].wipe)
        assert.equal("g101", committed()["0_1"].itemInfo.itemGUID)
        assert.equal(2, held, "the login's wait and the loading screen's: leaving the world joins it")
        assert.equal(2, released)
      end)

      -- The first report's stack: the queue's step (refresh.lua _Step) ran the recalculation.
      it("goes on with no unit during the loading screen: a recalculation waiting behind a read (captured)", function()
        login()
        refresh:RequestUpdate({ backpack = true }) -- a read under way, its harvest done
        refresh:RequestUpdate({ derive = true, backpack = true }) -- a recalculation waits behind it
        asked = {}
        fire("LOADING_SCREEN_ENABLED")
        frame()
        takeAway()
        drain()
        assert.same({}, errors)
        assert.same({}, asked)

        fire("PLAYER_LEAVING_WORLD")
        fire("PLAYER_ENTERING_WORLD", false, false)
        fire("LOADING_SCREEN_DISABLED")
        giveBack()
        frame()
        primed()
        drain()
        assert.same({}, errors)
        assert.equal("g101", committed()["0_1"].itemInfo.itemGUID)
      end)

      it("waits once per loading screen, whichever of its two signals comes first", function()
        login()
        fire("PLAYER_LEAVING_WORLD")
        fire("LOADING_SCREEN_ENABLED")
        assert.equal(2, held, "the loading screen joins the wait leaving the world started")
        fire("PLAYER_ENTERING_WORLD", false, false)
        fire("LOADING_SCREEN_DISABLED")
        giveBack()
        frame()
        primed()
        drain()
        assert.same({}, errors)
        -- The next loading screen is a wait of its own.
        fire("LOADING_SCREEN_ENABLED")
        assert.equal(3, held)
      end)

      it("starts a new wait for a loading screen that begins before the world's read", function()
        login()
        fire("PLAYER_LEAVING_WORLD")
        fire("PLAYER_ENTERING_WORLD", false, false)
        fire("LOADING_SCREEN_DISABLED") -- the first wait settles
        fire("LOADING_SCREEN_ENABLED") -- another loading screen, before the first wait read
        frame()
        frame()
        assert.is_nil(primed, "waiting for the second loading screen to end")
        assert.equal(3, held)
      end)

      it("starts a new wait when the player leaves a second time during a loading screen's wait", function()
        login()
        fire("LOADING_SCREEN_ENABLED")
        fire("PLAYER_LEAVING_WORLD") -- the same loading screen: joins its wait
        fire("PLAYER_ENTERING_WORLD", false, false) -- arms that wait's loading timeout
        fire("PLAYER_LEAVING_WORLD") -- another transfer, before the loading screen ended
        assert.equal(3, held)
        assert.is_true(fireDelayed(refresh.WORLD_LOADING_TIMEOUT))
        frame()
        assert.is_nil(primed, "the second wait still waits for its loading screen")
      end)

      it("asks the client about no bag while out of the world", function()
        login()
        asked = {}
        fire("PLAYER_LEAVING_WORLD")
        takeAway()
        closeWindow()
        refresh:RequestUpdate({ backpack = true })
        refresh:RequestUpdate({ wipe = true, backpack = true, bank = true })
        drain()
        assert.same({}, asked)
        assert.same({}, errors)
      end)

      it("goes on with a unit parked when the player left only once the world is back", function()
        login()
        override(addon, "atBank", true)
        override(addon, "Bags", { Bank = {} })
        mockContainer[6] = { { itemID = 301, guid = "bank1", count = 1 } }
        -- The bank is read and the unit parks; the backpack's read is its next step.
        refresh:RequestUpdate({ bank = true, backpack = true })
        local harvested = harvests
        fire("PLAYER_LEAVING_WORLD")
        takeAway()
        drain()
        assert.equal(harvested, harvests, "the backpack is not read while out of the world")
        assert.equal("g101", committed()["0_1"].itemInfo.itemGUID)

        fire("PLAYER_ENTERING_WORLD", false, false)
        fire("LOADING_SCREEN_DISABLED")
        giveBack()
        frame()
        primed()
        drain()
        assert.same({}, errors)
        assert.equal("g101", committed()["0_1"].itemInfo.itemGUID)
        assert.equal("bank1", items.slotInfo[const.BAG_KIND.BANK].itemsBySlotKey["6_1"].itemInfo.itemGUID)
      end)

      -- Leaving the world marks every bag unread: until a read of them, a recalculation asks the client
      -- nothing about them, even one that runs before the world's read (a unit parked when the player
      -- left) and even when the items are not back yet.
      it("asks nothing about the bags in a recalculation that runs before the world's read", function()
        login()
        override(addon, "atBank", true)
        override(addon, "Bags", { Bank = {} })
        mockContainer[6] = { { itemID = 301, guid = "bank1", count = 1 } }
        refresh:RequestUpdate({ bank = true, backpack = true })
        drain()
        -- The bank is recalculated and the unit parks; the backpack's recalculation is its next step.
        refresh:RequestUpdate({ derive = true, bank = true, backpack = true })
        asked = {}
        fire("PLAYER_LEAVING_WORLD")
        takeAway()
        fire("PLAYER_ENTERING_WORLD", false, false)
        fire("LOADING_SCREEN_DISABLED")
        frame()
        primed()
        drain()
        assert.same({}, errors)
        for _, key in ipairs(asked) do
          assert.is_nil(key:match("^[01]_"), "asked about " .. key)
        end
      end)

      it("ends each loading screen's wait on its own: an earlier wait's timers and item data end nothing", function()
        refresh:OnEnable()
        fire("PLAYER_ENTERING_WORLD", true, false) -- arms the login's loading timeout
        fire("LOADING_SCREEN_DISABLED")
        frame()
        local loginPrimed = primed
        assert.is_true(fireDelayed(refresh.WORLD_PRIME_TIMEOUT)) -- the login's read runs without the item data
        drain()
        local before = #sweeps
        primed = nil
        fire("PLAYER_LEAVING_WORLD")
        takeAway()
        loginPrimed() -- the login's item data arrives during the loading screen
        assert.is_true(fireDelayed(refresh.WORLD_LOADING_TIMEOUT)) -- the login's loading timeout
        frame()
        drain()
        assert.equal(before, #sweeps, "nothing read while out of the world")
        assert.is_nil(primed, "still waiting for the loading screen")
        assert.same({}, errors)

        fire("PLAYER_ENTERING_WORLD", false, false)
        fire("LOADING_SCREEN_DISABLED")
        giveBack()
        frame()
        primed()
        drain()
        assert.equal(before + 1, #sweeps, "the login's late item data asked for a read, taken in by the world's")
      end)

      it("ends nothing with the timeout or item data of a wait the player left before it read", function()
        refresh:OnEnable()
        fire("LOADING_SCREEN_DISABLED")
        frame() -- the login's wait loads the item data
        local loginPrimed = primed
        primed = nil
        fire("PLAYER_LEAVING_WORLD")
        takeAway()
        assert.is_true(fireDelayed(refresh.WORLD_PRIME_TIMEOUT)) -- the login's
        loginPrimed() -- the login's item data
        drain()
        assert.equal(0, #sweeps, "nothing read while out of the world")
        assert.is_nil(primed)

        fire("PLAYER_ENTERING_WORLD", false, false)
        fire("LOADING_SCREEN_DISABLED")
        giveBack()
        frame()
        primed()
        drain()
        assert.equal(1, #sweeps)
        loginPrimed() -- the login's item data, late
        drain()
        assert.equal(1, #sweeps, "the login's wait never read, so its item data asks for nothing")
      end)

      it("ends nothing with the timers of a wait the player left while it was still loading", function()
        login()
        fire("PLAYER_LEAVING_WORLD")
        fire("PLAYER_ENTERING_WORLD", false, false) -- arms the first wait's loading timeout
        fire("PLAYER_LEAVING_WORLD") -- before its loading screen ended
        assert.is_true(fireDelayed(refresh.WORLD_LOADING_TIMEOUT))
        frame()
        assert.is_nil(primed, "the second wait still waits for its loading screen")
      end)

      it("counts the settle timeout from the loading screen's end, whatever fires after", function()
        local now = 100
        saveGlobal(_G, "GetTime")
        _G.GetTime = function() return now end
        login()
        fire("PLAYER_LEAVING_WORLD")
        fire("PLAYER_ENTERING_WORLD", false, false)
        fire("LOADING_SCREEN_DISABLED")
        fire("BAG_UPDATE", 0)
        frame() -- the items arriving
        now = 101
        assert.is_true(fireDelayed(refresh.WORLD_LOADING_TIMEOUT)) -- the loading timeout, after the end
        fire("BAG_UPDATE", 0)
        frame()
        assert.is_nil(primed)
        now = 100 + refresh.WORLD_SETTLE_TIMEOUT
        fire("BAG_UPDATE", 0)
        frame()
        assert.is_function(primed, "two seconds after the loading screen ended")
      end)

      it("stops waiting for the world after a while when the client never says it is back", function()
        login()
        fire("PLAYER_LEAVING_WORLD")
        frame()
        assert.is_nil(primed)
        -- The login's wait set one too: it ends nothing now.
        assert.is_true(fireDelayed(refresh.WORLD_RETURN_TIMEOUT))
        frame()
        assert.is_nil(primed)
        assert.is_true(fireDelayed(refresh.WORLD_RETURN_TIMEOUT))
        frame()
        assert.is_function(primed)
      end)

      it("reads nothing early when the backpack shows while out of the world: only the login does", function()
        override(addon, "Bags", { Backpack = { frame = CreateFrame("Frame") } })
        login()
        local before = #sweeps
        local hooks = 0
        local hookScript = addon.HookScript
        override(addon, "HookScript", function(...) hooks = hooks + 1 return hookScript(...) end)
        fire("PLAYER_LEAVING_WORLD")
        assert.equal(0, hooks, "the backpack is hooked once, at login")
        local bagFrame = addon.Bags.Backpack.frame
        bagFrame:GetScript("OnShow")(bagFrame)
        drain()
        assert.equal(before, #sweeps)
        assert.is_nil(primed)
      end)

      it("starts a new wait when the player leaves again before the world's read", function()
        login()
        fire("PLAYER_LEAVING_WORLD")
        fire("PLAYER_ENTERING_WORLD", false, false)
        fire("LOADING_SCREEN_DISABLED")
        fire("PLAYER_LEAVING_WORLD")
        local before = #sweeps
        frame()
        drain()
        assert.equal(before, #sweeps)
        assert.is_nil(primed, "waiting for the second loading screen")
        fire("PLAYER_ENTERING_WORLD", false, false)
        fire("LOADING_SCREEN_DISABLED")
        frame()
        primed()
        drain()
        assert.equal(before + 1, #sweeps)
      end)
    end)
  end)
end)
