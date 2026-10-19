-- guildbank_pipeline_spec.lua -- the guild bank through the data engine: a third kind of bag read
-- from the guild bank's tabs, then every phase as for the bank (guild-bank.md §3).

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local createdStubs = {}
local function stubModule(name)
  local mod, created = StubBetterBagsModule(name)
  if created then
    createdStubs[name] = true
  end
  return mod
end

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

local GUILD = 2
local BASE = 1000
local SECTION_GRID, SECTION_ALL_BAGS = 2, 4

-- Items by ID: name, type (GetItemInfoInstant's itemType / itemSubType / equip location / class).
local itemDefs = {
  [100] = { name = "Iron Sword", type = "Weapon", subType = "Swords", equip = "INVTYPE_WEAPON", class = 2, sub = 7 },
  [200] = { name = "Copper Ore", type = "Tradeskill", subType = "Metal & Stone", equip = "", class = 7, sub = 7 },
  [300] = { name = "Healing Potion", type = "Consumable", subType = "Potion", equip = "", class = 0, sub = 1 },
}
local coldItems

-- A retail item link: the quality color code (with its colon), then every field of an item string
-- (item ID, seven empty fields, the link level, ten more), no bonus IDs or modifiers.
local function linkOf(id)
  return "|cnIQ2:|Hitem:" .. id .. "::::::::80::::::::::|h[" .. itemDefs[id].name .. "]|h|r"
end

local function idOf(x)
  return tonumber(x) or tonumber(tostring(x):match("item:(%d+)"))
end

local const, database, categories, guildBank, items, search, async, refresh
local viewMode

local function stubModules()
  local debug = stubModule("Debug")
  override(debug, "Log", function() end)
  override(debug, "Inspect", function() end)

  local L = stubModule("Localization")
  override(L, "G", function(_, key) return key end)

  const = stubModule("Constants")
  override(const, "BAG_KIND", { UNDEFINED = -1, BACKPACK = 0, BANK = 1, GUILD = GUILD })
  override(const, "BAG_VIEW", { UNDEFINED = 0, SECTION_GRID = SECTION_GRID, SECTION_ALL_BAGS = SECTION_ALL_BAGS })
  override(const, "BANK_BAGS", { [6] = 6 })
  override(const, "ACCOUNT_BANK_BAGS", {})
  override(const, "BACKPACK_BAGS", { [0] = 0 })
  override(const, "BANK_TAB", { BANK = 6, ACCOUNT_BANK_1 = 13 })
  override(const, "BANK_ONLY_BAGS", {})
  local bags, containers, list = {}, {}, {}
  for tab = 1, 8 do
    bags[BASE + tab] = tab
    containers[tab] = BASE + tab
    list[tab] = BASE + tab
  end
  override(const, "GUILD_BANK_BAGS", bags)
  override(const, "GUILD_BANK_TAB_CONTAINER", containers)
  override(const, "GUILD_BANK_BAGS_LIST", list)
  override(const, "GUILD_BANK_SLOTS", 98)
  override(const, "GUILD_BANK_ALL_TAB", 1)
  override(const, "BINDING_SCOPE", {
    UNKNOWN = 0, NONBINDING = 1, BOUND = 2, BOE = 3, BOU = 4, QUEST = 5,
    SOULBOUND = 6, REFUNDABLE = 7, ACCOUNT = 8, BNET = 9, WUE = 10,
  })
  override(const, "BINDING_MAP", { [0] = "", [1] = "boe", [2] = "soulbound" })
  override(const, "ITEM_QUALITY", { Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 })
  override(const, "BAG_SUBTYPE_TO_QUALITY", { [0] = 1 })
  override(const, "SEARCH_CATEGORY_GROUP_BY", { NONE = 0, TYPE = 1, SUBTYPE = 2, EXPANSION = 3 })
  override(const, "EXPANSION_MAP", { [0] = "Classic" })
  override(const, "BRIEF_EXPANSION_MAP", { [0] = "classic" })
  override(const, "TRADESKILL_MAP", {})
  override(const, "INVENTORY_TYPE_TO_INVENTORY_SLOTS", { [13] = { 16, 17 } })

  database = stubModule("Database")
  override(database, "GetNewItemTime", function() return 30 end)
  override(database, "GetStackingOptions", function() return { mergeStacks = true, mergeUnstackable = false } end)
  override(database, "GetCategoryFilter", function(_, _, filter) return filter == "Type" end)
  override(database, "GetEnableBankBag", function() return false end)
  override(database, "GetMarkRecentItems", function() return false end)
  override(database, "GetShowAllFreeSpace", function() return false end)
  override(database, "GetBagView", function(_, kind) return kind == GUILD and viewMode or SECTION_GRID end)
  override(database, "GetUpgradeIconProvider", function() return "None" end)
  override(database, "GetUpgradeIconProviderUserSet", function() return false end)
  override(database, "GetGroupsEnabled", function() return false end)
  override(database, "GetActiveGroup", function() return 1 end)
  override(database, "GetShowBankTabs", function() return false end)
  override(database, "GetShowGuildBankTabs", function() return viewMode == SECTION_ALL_BAGS end)
  override(database, "GetPreserveItemGaps", function() return false end)

  local equipmentSets = stubModule("EquipmentSets")
  override(equipmentSets, "GetItemSets", function() return nil end)
  override(equipmentSets, "Update", function() end)

  local tooltipScanner = stubModule("TooltipScanner")
  override(tooltipScanner, "GetTooltipText", function() return "" end)
  override(tooltipScanner, "GetGuildBankItemText", function(_, tab, slot)
    return "guild tooltip " .. tab .. ":" .. slot
  end)

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
  override(searchBox, "GetSearchText", function() return "" end)

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

local reads
local function stubClientAPIs()
  for _, k in ipairs({
    { _G.C_Item, "GetItemInfo" }, { _G.C_Item, "GetItemInfoInstant" }, { _G.C_Item, "GetItemStats" },
    { _G.C_Item, "GetDetailedItemLevelInfo" }, { _G.C_Item, "GetItemInventoryTypeByID" },
    { _G.C_Container, "GetContainerNumSlots" }, { _G.C_Container, "GetContainerNumFreeSlots" },
    { _G.C_Container, "ContainerIDToInventoryID" }, { _G, "GetGuildBankItemInfo" }, { _G, "GetGuildBankItemLink" },
    { _G, "GetInventoryItemLink" },
  }) do
    saveGlobal(k[1], k[2])
  end
  -- GetItemInfo(item) -> itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType,
  -- itemSubType, itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID,
  -- bindType, expacID, setID, isCraftingReagent; nothing while the item's data is not loaded.
  _G.C_Item.GetItemInfo = function(item)
    local id = idOf(item)
    local def = itemDefs[id]
    if def == nil or coldItems[id] then return nil end
    return def.name, linkOf(id), 2, 80, 1, def.type, def.subType, 20, def.equip, 134400 + id, 10, def.class,
      def.sub, 2, 0, 0, false
  end
  -- GetItemInfoInstant(item) -> itemID, itemType, itemSubType, itemEquipLoc, icon, classID,
  -- subClassID: from the client's static data, never cold.
  _G.C_Item.GetItemInfoInstant = function(item)
    local id = idOf(item)
    local def = itemDefs[id]
    if def == nil then return nil end
    return id, def.type, def.subType, def.equip, 134400 + id, def.class, def.sub
  end
  _G.C_Item.GetItemStats = function() return nil end
  _G.C_Item.GetDetailedItemLevelInfo = function() return 80, false, 80 end
  _G.C_Item.GetItemInventoryTypeByID = function(item)
    local def = itemDefs[idOf(item)]
    return def and def.equip == "INVTYPE_WEAPON" and 13 or 0
  end
  _G.C_Container.GetContainerNumSlots = function() return 0 end
  _G.C_Container.GetContainerNumFreeSlots = function() return 0, 0 end
  _G.C_Container.ContainerIDToInventoryID = function() return nil end
  _G.GetInventoryItemLink = function() return nil end
  local itemInfo, itemLink = _G.GetGuildBankItemInfo, _G.GetGuildBankItemLink
  _G.GetGuildBankItemInfo = function(tab, slot)
    reads = reads + 1
    return itemInfo(tab, slot)
  end
  _G.GetGuildBankItemLink = function(tab, slot)
    reads = reads + 1
    return itemLink(tab, slot)
  end
end

local function loadRealModules()
  LoadBetterBagsModule("util/query.lua")
  LoadBetterBagsModule("util/trees/trees.lua")
  LoadBetterBagsModule("util/trees/intervaltree.lua")
  LoadFreshBetterBagsModule("Context", "core/context.lua")
  LoadFreshBetterBagsModule("Events", "core/events.lua")
  ResetModuleStub("Search", "data/search.lua")
  LoadBetterBagsModule("data/search.lua")
  LoadBetterBagsModule("core/async.lua")
  ResetModuleStub("Stacks", "data/stacks.lua")
  LoadBetterBagsModule("data/stacks.lua")
  ResetModuleStub("Binding", "data/binding.lua")
  LoadBetterBagsModule("data/binding.lua")
  ResetModuleStub("GuildBank", "data/guildbank.lua")
  LoadBetterBagsModule("data/guildbank.lua")
  ResetModuleStub("Items", "data/items.lua")
  LoadBetterBagsModule("data/items.lua")
  LoadBetterBagsModule("data/slots.lua")
  ResetModuleStub("Refresh", "data/refresh.lua")
  LoadBetterBagsModule("data/refresh.lua")
end

local function unloadRealModules()
  ResetModuleStub("Refresh", "data/refresh.lua")
  ResetModuleStub("Items", "data/items.lua")
  ResetModuleStub("GuildBank", "data/guildbank.lua")
  ResetModuleStub("Binding", "data/binding.lua")
  ResetModuleStub("Stacks", "data/stacks.lua")
  ResetModuleStub("Search", "data/search.lua")
end

local function slot(id, opts)
  opts = opts or {}
  return { link = linkOf(id), texture = 134400 + id, count = opts.count or 1, locked = opts.locked,
    quality = opts.quality or 2 }
end

describe("the guild bank through the data engine", function()
  local savedYield, savedBags, savedHasGuildBank, events, context, done

  local function fire(event, ...)
    events._eventMap[event].fn(event, ...)
  end

  -- loadTabs opens the guild bank and has the server answer every viewable tab.
  local function loadTabs()
    fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Enum.PlayerInteractionType.GuildBanker)
    for t in pairs(_G._guildBank.tabs) do _G._guildBank.delivered[t] = true end
    guildBank:Load()
    while guildBank:IsLoading() do fire("GUILDBANKBAGSLOTS_CHANGED") end
  end

  local function read(opts)
    local ctx = context:New("guild read")
    if opts and opts.wipe then ctx:Set("wipe", true) end
    if opts and opts.derive then ctx:Set("derive", true) end
    items:ProcessRefresh(ctx, GUILD)
    return items.slotInfo[GUILD]
  end

  local function keyOf(tab, slotID)
    return (BASE + tab) .. "_" .. slotID
  end

  before_each(function()
    ResetMockGuildBank()
    coldItems = {}
    reads = 0
    viewMode = SECTION_GRID
    stubModules()
    stubClientAPIs()
    loadRealModules()
    context = addon:GetModule("Context")
    events = addon:GetModule("Events")
    events:Init()
    guildBank = addon:GetModule("GuildBank")
    items = addon:GetModule("Items")
    search = addon:GetModule("Search")
    async = addon:GetModule("Async")
    refresh = addon:GetModule("Refresh")
    savedYield = async.Yield
    async.Yield = function() end
    savedBags, savedHasGuildBank = addon.Bags, addon.hasGuildBank
    addon.Bags = {}
    addon.hasGuildBank = true
    guildBank:Init()
    guildBank:OnEnable()
    search:Init()
    items:Init()
    for _, kind in ipairs({ 0, 1, GUILD }) do items._firstLoad[kind] = false end
    refresh:Init()
    done = {}
    events:RegisterMessage("items/RefreshGuildBank/Done", function(_, slotInfo) table.insert(done, slotInfo) end)

    _G._guildBank.tabs = {
      { name = "Gear", icon = 1, isViewable = true, canDeposit = true, slots = {
        [1] = slot(100), [3] = slot(300, { count = 5 }) } },
      { name = "Mats", icon = 2, isViewable = true, canDeposit = true, slots = {
        [2] = slot(200, { count = 20, quality = 1 }), [4] = slot(300, { count = 3 }) } },
      { name = "Officers", icon = 3, isViewable = false, slots = { [1] = slot(100) } },
    }
  end)

  after_each(function()
    async.Yield = savedYield
    addon.Bags, addon.hasGuildBank = savedBags, savedHasGuildBank
    addon.atGuildBank = nil
    unloadRealModules()
    restoreGlobals()
    restoreOverrides()
    for name in pairs(createdStubs) do
      ResetModuleStub(name)
    end
    createdStubs = {}
  end)

  describe("reading", function()
    it("reads every slot of the tabs it has loaded, each a guild item keyed by its tab's container", function()
      loadTabs()
      local slotInfo = read()
      local sword = slotInfo.itemsBySlotKey[keyOf(1, 1)]
      assert.are.equal(GUILD, sword.kind)
      assert.are.equal(1, sword.guildTab)
      assert.are.equal(BASE + 1, sword.bagid)
      assert.are.equal(1, sword.slotid)
      assert.are.equal(100, sword.itemInfo.itemID)
      assert.are.equal("Iron Sword", sword.itemInfo.itemName)
      assert.are.equal(linkOf(100), sword.itemInfo.itemLink)
      assert.are.equal(2, sword.itemInfo.itemQuality)
      assert.are.equal("guild tooltip 1:1", sword.itemInfo.tooltipText)
      assert.are.equal(20, slotInfo.itemsBySlotKey[keyOf(2, 2)].itemInfo.currentItemCount)
      assert.is_true(slotInfo.itemsBySlotKey[keyOf(1, 2)].isItemEmpty)
      local count = 0
      for _ in pairs(slotInfo.itemsBySlotKey) do count = count + 1 end
      assert.are.equal(2 * 98, count, "every slot of the two tabs it can view, none of the third")
      assert.are.equal(1, #done, "and says it has read the guild bank")
    end)

    it("reads nothing of a tab not loaded yet", function()
      fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Enum.PlayerInteractionType.GuildBanker)
      _G._guildBank.delivered[1] = true
      guildBank:LoadTab(1)
      fire("GUILDBANKBAGSLOTS_CHANGED")
      local slotInfo = read()
      assert.is_not_nil(slotInfo.itemsBySlotKey[keyOf(1, 1)])
      assert.is_nil(slotInfo.itemsBySlotKey[keyOf(2, 2)])
    end)

    it("names guild items by their type, as the bank's", function()
      loadTabs()
      local slotInfo = read()
      assert.are.equal("Weapon", slotInfo.itemsBySlotKey[keyOf(1, 1)].itemInfo.category)
      assert.are.equal("Tradeskill", slotInfo.itemsBySlotKey[keyOf(2, 2)].itemInfo.category)
    end)

    it("categorizes an item whose data is not loaded by its type, and reads it again later", function()
      coldItems[100] = true
      loadTabs()
      local slotInfo = read()
      local sword = slotInfo.itemsBySlotKey[keyOf(1, 1)]
      assert.is_true(sword.harvestIncomplete)
      assert.are.equal("Weapon", sword.itemInfo.category)
      coldItems[100] = nil
      slotInfo = read()
      assert.are_not.equal(sword, slotInfo.itemsBySlotKey[keyOf(1, 1)])
      assert.are.equal("Iron Sword", slotInfo.itemsBySlotKey[keyOf(1, 1)].itemInfo.itemName)
    end)

    it("is never bound, its binding from its bind type", function()
      loadTabs()
      local sword = read().itemsBySlotKey[keyOf(1, 1)]
      assert.are.same({ binding = const.BINDING_SCOPE.BOE, bound = false }, sword.bindingInfo)
      assert.is_false(sword.itemInfo.isBound)
    end)
  end)

  describe("kept slots", function()
    it("keeps the item of every slot whose contents are unchanged", function()
      loadTabs()
      local first = read()
      local sword = first.itemsBySlotKey[keyOf(1, 1)]
      local potions = first.itemsBySlotKey[keyOf(1, 3)]
      _G._guildBank.tabs[1].slots[3].count = 4
      local second = read()
      assert.are.equal(sword, second.itemsBySlotKey[keyOf(1, 1)])
      assert.are_not.equal(potions, second.itemsBySlotKey[keyOf(1, 3)])
      assert.are.equal(4, second.itemsBySlotKey[keyOf(1, 3)].itemInfo.currentItemCount)
    end)

    it("reads a slot again when its lock changes (another player moving it)", function()
      loadTabs()
      local sword = read().itemsBySlotKey[keyOf(1, 1)]
      _G._guildBank.tabs[1].slots[1].locked = true
      local after = read().itemsBySlotKey[keyOf(1, 1)]
      assert.are_not.equal(sword, after)
      assert.is_true(after.itemInfo.isLocked)
    end)

    it("reads every slot again on a wipe", function()
      loadTabs()
      local sword = read().itemsBySlotKey[keyOf(1, 1)]
      assert.are_not.equal(sword, read({ wipe = true }).itemsBySlotKey[keyOf(1, 1)])
    end)
  end)

  describe("recalculating (derive)", function()
    it("reads no slot, keeping the items and their tooltip text", function()
      loadTabs()
      local sword = read().itemsBySlotKey[keyOf(1, 1)]
      reads = 0
      local slotInfo = read({ derive = true })
      assert.are.equal(sword, slotInfo.itemsBySlotKey[keyOf(1, 1)])
      assert.are.equal(0, reads)
    end)
  end)

  -- The combined view is every tab's items in categories; a tab shown by itself is its slots in
  -- order, as the bank's own tabs are (guild-bank.md §4).
  describe("tabs of the view", function()
    it("puts every tab's items in the combined view, and frees per tab it may deposit in", function()
      loadTabs()
      local slotInfo = read()
      local all = slotInfo.tabs[const.GUILD_BANK_ALL_TAB]

      assert.is_not_nil(all)
      local keys = {}
      for _, item in ipairs(all.items) do keys[item.slotkey] = true end
      assert.is_true(keys[keyOf(1, 1)] and keys[keyOf(2, 2)] and true)
      local free = {}
      for _, button in ipairs(all.freeSpace.buttons) do free[button.key] = button.count end
      assert.are.same({ Gear = 96, Mats = 96 }, free)
    end)

    it("stacks the same item across tabs in the combined view", function()
      loadTabs()
      local slotInfo = read()
      local potionsShown = 0
      for _, item in ipairs(slotInfo.tabs[const.GUILD_BANK_ALL_TAB].items) do
        if item.itemInfo.itemID == 300 then
          potionsShown = potionsShown + 1
          assert.are.equal(8, item.stackedCount)
        end
      end
      assert.are.equal(1, potionsShown)
    end)

    it("shows a tab by itself in slot order, without stacking, named after the tab", function()
      viewMode = SECTION_ALL_BAGS
      loadTabs()
      local slotInfo = read()
      local mats = slotInfo.tabs[BASE + 2]
      assert.is_not_nil(mats)
      local shown = {}
      for _, item in ipairs(mats.items) do
        assert.are.equal(BASE + 2, item.bagid)
        if not item.isItemEmpty and not item.isFreeSlot then table.insert(shown, item.slotkey) end
      end
      assert.are.same({ keyOf(2, 2), keyOf(2, 4) }, shown)
      assert.are.equal("#2: Mats", slotInfo.itemsBySlotKey[keyOf(2, 2)].itemInfo.category)
      assert.is_true(slotInfo.sectionLayouts["#2: Mats"].hideHeader)
    end)
  end)

  -- A guild tab is not a bag: the client has no bag name for its container
  -- (C_Container.GetBagName), yet its empty slots show in place, as Blizzard's guild bank grid does.
  it("shows a tab's empty slots in place when the tab is shown by itself", function()
    saveGlobal(_G.C_Container, "GetBagName")
    _G.C_Container.GetBagName = function(bagid) return bagid < BASE and "Bag" or nil end
    viewMode = SECTION_ALL_BAGS
    loadTabs()
    local slotInfo = read()
    local free = 0
    for _, item in ipairs(slotInfo.tabs[BASE + 2].items) do
      if item.isFreeSlot then
        free = free + 1
        assert.are.equal("#2: Mats", item.itemInfo.category)
      end
    end
    assert.are.equal(96, free)
  end)

  describe("the shared search index", function()
    it("holds the guild bank's items beside the bags', and drops them when the guild bank closes", function()
      loadTabs()
      read()
      assert.is_true(search:Search("Copper")[keyOf(2, 2)])
      items:ProcessRefresh(context:New("backpack"), 0)
      assert.is_true(search:Search("Copper")[keyOf(2, 2)], "a backpack read keeps them")
      items:ClearGuildBankCache(context:New("closed"))
      items:ProcessRefresh(context:New("backpack"), 0)
      assert.is_nil(search:Search("Copper")[keyOf(2, 2)])
    end)
  end)

  it("knows a guild container's kind", function()
    assert.are.equal(GUILD, items:GetBagKindFromBagID(BASE + 3))
    assert.are.equal(GUILD, items:GetBagKindFromSlotKey(keyOf(3, 7)))
  end)
end)
