-- merchant_spec.lua -- NextMerchant (next/merchant.lua): what BetterBags Next's vendor shows and does
-- (next.md §10). It reads the open merchant's items (retail's C_MerchantFrame, Classic's
-- GetMerchantItemInfo), gives them the backpack's categories in the backpack's order, searches them in
-- an index of their own, reads buyback and what needs repair, and buys through Blizzard's own
-- confirmations, as Blizzard's item button does.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("util/query.lua")
LoadBetterBagsModule("util/trees/trees.lua")
LoadBetterBagsModule("util/trees/intervaltree.lua")

local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local const = trackStub("Constants")
const.BAG_KIND = const.BAG_KIND or { BACKPACK = 0, BANK = 1 }
-- core/constants.lua defines it before next/merchant.lua loads, whose Init runs the search
-- module's (search:Init reads it).
const.BRIEF_EXPANSION_MAP = const.BRIEF_EXPANSION_MAP or {}
local BACKPACK = const.BAG_KIND.BACKPACK

local stubs = {
  items = trackStub("Items"),
  categories = trackStub("Categories"),
  sort = trackStub("Sort"),
  database = trackStub("Database"),
  debug = trackStub("Debug"),
  tooltip = trackStub("TooltipScanner"),
}

local replaced = {}
local function override(tbl, key, value)
  table.insert(replaced, { tbl, key, rawget(tbl, key) })
  tbl[key] = value
end
local function restore()
  for i = #replaced, 1, -1 do
    replaced[i][1][replaced[i][2]] = replaced[i][3]
  end
  replaced = {}
end

-- The bags' own search module, for the vendor's index of its own.
ResetModuleStub("Search", "data/search.lua")
LoadBetterBagsModule("data/search.lua")
ResetModuleStub("NextMerchant", "next/merchant.lua")
LoadBetterBagsModule("next/merchant.lua")

local merchant = addon:GetModule("NextMerchant")
local search = addon:GetModule("Search")
local context = addon:GetModule("Context")

local SECTION_GRID = 2
local GROUP_BY_TYPE = 1

describe("NextMerchant", function()
  local itemInfo, searchCategories, customByID

  -- link builds an item link the mocks below read the item's info from.
  local function link(id) return "|cffffffff|Hitem:" .. id .. "::::::::80:::::|h[Item " .. id .. "]|h|r" end
  local function idOf(l) return tonumber(tostring(l):match("item:(%d+)")) end

  local function ctx() return context:New("spec") end

  local function vendorItem(id, opts)
    opts = opts or {}
    local item = { link = link(id), itemID = id, name = "Item " .. id, texture = 1000 + id, price = opts.price or 100,
      stackCount = opts.stackCount or 1, numAvailable = opts.numAvailable or -1, maxStack = opts.maxStack or 20 }
    for k, v in pairs(opts) do item[k] = v end
    return item
  end

  before_each(function()
    ResetMockMerchant()
    _G._modifiedClickHandled = false
    itemInfo = {
      [10] = { "Item 10", 2, 0, "Consumable", "Potion", "", 0, 3 },
      [11] = { "Item 11", 3, 4, "Armor", "Plate", "INVTYPE_CHEST", 4, 4 },
      [12] = { "Item 12", 1, 0, "Consumable", "Food & Drink", "", 0, 5 },
      [13] = { "Item 13", 4, 2, "Weapon", "Swords", "INVTYPE_WEAPON", 2, 7 },
    }
    searchCategories = {}
    customByID = {}
    override(addon, "isRetail", true)
    override(const, "BACKPACK_BAGS", { [0] = 0, [1] = 1 })
    override(const, "SEARCH_CATEGORY_GROUP_BY", { NONE = 0, TYPE = GROUP_BY_TYPE })
    override(const, "BRIEF_EXPANSION_MAP", {})
    override(const, "BINDING_MAP", { [0] = "" })
    override(const, "ITEM_QUALITY_TO_ENUM", { poor = 0, common = 1, uncommon = 2, rare = 3, epic = 4 })
    override(const, "ITEM_QUALITY", { Poor = 0, Common = 1 })
    -- C_Item.GetItemInfo(link): name, link, quality, level, minLevel, type, subType, stackCount,
    -- equipLoc, icon, sellPrice, classID, subclassID, bindType, expacID; nothing while cold.
    override(C_Item, "GetItemInfo", function(l)
      local info = itemInfo[idOf(l)]
      if info == nil then return nil end
      return info[1], l, info[2], 10, 1, info[4], info[5], 20, info[6], 1000 + idOf(l), 5, info[7], 0, 0, info[8]
    end)
    -- C_Item.GetItemInfoInstant(link): itemID, type, subType, equipLoc, icon, classID, subclassID.
    override(C_Item, "GetItemInfoInstant", function(l)
      local id = idOf(l)
      local info = itemInfo[id] or { nil, nil, nil, "Miscellaneous", "Junk", "", 15 }
      return id, info[4], info[5], info[6], 1000 + id, info[7], 0
    end)
    override(C_Item, "GetDetailedItemLevelInfo", function() return 10 end)
    override(stubs.debug, "Log", function() end)
    override(stubs.debug, "Inspect", function() end)
    override(stubs.database, "GetBagView", function() return SECTION_GRID end)
    -- The backpack's categories, by type here.
    override(stubs.items, "GetCategory", function(_, _, data)
      assert.are.equal(BACKPACK, data.kind)
      if data.containerInfo.quality == 0 then return "Junk" end
      return customByID[data.itemInfo.itemID] and customByID[data.itemInfo.itemID][1] or data.itemInfo.itemType
    end)
    override(stubs.items, "GetGroupBySuffix", function(_, data, groupBy)
      if groupBy == GROUP_BY_TYPE then return data.itemInfo.itemType end
    end)
    override(stubs.items, "GetAllSlotInfo", function() return {} end)
    override(stubs.items, "CraftingQualityOf", function(_, l) return idOf(l) == 12 and 2 or nil end)
    override(stubs.categories, "GetCustomCategory", function(_, _, kind, data)
      assert.are.equal(BACKPACK, kind)
      local c = customByID[data.itemInfo.itemID]
      if c then return c[1], c[2] end
      return nil, nil
    end)
    override(stubs.categories, "GetSortedSearchCategories", function() return searchCategories end)
    override(stubs.sort, "GetCategoryDataSortFunction", function(_, kind, view)
      assert.are.equal(BACKPACK, kind)
      assert.are.equal(SECTION_GRID, view)
      return function(a, b) return a.name < b.name end
    end)
    override(stubs.tooltip, "GetMerchantItemText", function(_, index) return "vendor tooltip " .. index end)
    override(stubs.tooltip, "GetInventoryRepairCost", function(_, slot) return _G._repairCosts["inv:" .. slot] end)
    override(stubs.tooltip, "GetBagRepairCost", function(_, bag, slot) return _G._repairCosts["bag:" .. bag .. ":" .. slot] end)
    search:Init()
    merchant:Init()
  end)

  after_each(function()
    restore()
    ResetMockMerchant()
    _G._modifiedClickHandled = false
  end)

  -- The real Search module stays loaded, as spec/search_spec.lua leaves it: later specs load
  -- modules that look it up.
  teardown(function()
    ResetModuleStub("NextMerchant")
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  describe("reading the merchant's items", function()
    it("reads every item with its price, stack, stock, use, costs and quality (retail)", function()
      _G._merchant.items = {
        vendorItem(10, { price = 250, stackCount = 5, numAvailable = 3, maxStack = 100, canAfford = false }),
        vendorItem(11, { price = 0, hasExtendedCost = true, isUsable = false, isQuestStartItem = true,
          costs = { { texture = 77, value = 30, currencyName = "Valor" }, { texture = 78, value = 2, link = link(12) } },
          refundable = false }),
      }
      local list = merchant:ReadItems(ctx())
      assert.are.equal(2, #list)
      local a, b = list[1], list[2]
      assert.are.same({ 1, link(10), 10, "Item 10", 1010, 250, 5, 3, 100, false, true, true, false, 2 },
        { a.index, a.link, a.itemID, a.name, a.texture, a.price, a.stackCount, a.numAvailable, a.maxStack, a.canAfford,
          a.isPurchasable, a.isUsable, a.hasExtendedCost, a.quality })
      assert.are.same({ true, false, true, 3 }, { b.hasExtendedCost, b.isUsable, b.isQuestStartItem, b.quality })
      assert.are.same({ { texture = 77, value = 30, currencyName = "Valor" }, { texture = 78, value = 2, link = link(12) } },
        b.costs)
      assert.is_true(a.refundable)
      assert.is_false(b.refundable)
    end)

    it("reads Classic's GetMerchantItemInfo, where nothing is ever non-refundable", function()
      override(addon, "isRetail", false)
      override(C_MerchantFrame, "GetItemInfo", nil)
      _G._merchant.items = { vendorItem(10, { price = 40, stackCount = 2, refundable = false }) }
      local a = merchant:ReadItems(ctx())[1]
      assert.are.same({ 1, "Item 10", 40, 2, true }, { a.index, a.name, a.price, a.stackCount, a.refundable })
    end)

    it("names a currency for sale as its container does", function()
      local saved = _G.CurrencyContainerUtil
      _G.CurrencyContainerUtil = { GetCurrencyContainerInfo = function(id, n, name, texture)
        return name .. " x" .. n, texture + 1, n * 2
      end }
      _G._merchant.items = { vendorItem(10, { currencyID = 42, numAvailable = 3 }) }
      local a = merchant:ReadItems(ctx())[1]
      _G.CurrencyContainerUtil = saved
      assert.are.same({ "Item 10 x3", 1011, 6 }, { a.name, a.texture, a.numAvailable })
    end)

    it("says when an item's info is not loaded yet, and reads its type from the instant info", function()
      itemInfo[14] = nil
      _G._merchant.items = { vendorItem(14) }
      local list, cold = merchant:ReadItems(ctx())
      assert.is_true(cold)
      assert.are.equal("Miscellaneous", list[1].record.itemInfo.itemType)
      _G._merchant.items = { vendorItem(10) }
      local _, warm = merchant:ReadItems(ctx())
      assert.is_false(warm)
    end)

    it("gives each item a record the backpack's categories and search read", function()
      _G._merchant.items = { vendorItem(11, { stackCount = 3 }) }
      local r = merchant:ReadItems(ctx())[1].record
      assert.are.same({ BACKPACK, "vendor:1" }, { r.kind, r.slotkey })
      local i = r.itemInfo
      assert.are.same({ 11, "Item 11", link(11), 3, "Armor", "Plate", "INVTYPE_CHEST", 4, 0, 4, 3, 10, "vendor tooltip 1" },
        { i.itemID, i.itemName, i.itemLink, i.itemQuality, i.itemType, i.itemSubType, i.itemEquipLoc, i.classID,
          i.subclassID, i.expacID, i.currentItemCount, i.currentItemLevel, i.tooltipText })
      assert.are.equal(3, r.containerInfo.quality)
    end)
  end)

  describe("categories", function()
    it("gives items the backpack's categories, a matching search category beating a lower one", function()
      _G._merchant.items = { vendorItem(10), vendorItem(11), vendorItem(12), vendorItem(13) }
      customByID[12] = { "Snacks", 5 }
      customByID[13] = { "Blades", 1 }
      searchCategories = {
        { name = "Shiny", priority = 3, enabled = { [BACKPACK] = true }, searchCategory = { query = "rarity >= 3" } },
        { name = "Off", priority = 1, enabled = {}, searchCategory = { query = "name = item" } },
      }
      local list = merchant:ReadItems(ctx())
      local got = {}
      for _, item in ipairs(list) do got[item.itemID] = item.category end
      -- 11 (rare) goes to Shiny; 13 (epic) stays in Blades, priority 1 beating 3; 12 in Snacks.
      assert.are.same({ [10] = "Consumable", [11] = "Shiny", [12] = "Snacks", [13] = "Blades" }, got)
      assert.are.same({ "vendor:2" }, (function()
        local out = {}
        for k in pairs(merchant.search:Search("category = shiny")) do table.insert(out, k) end
        return out
      end)())
    end)

    it("gives an item matching two search categories the one with the lower priority number", function()
      _G._merchant.items = { vendorItem(13) }
      searchCategories = {
        { name = "Late", priority = 8, enabled = { [BACKPACK] = true }, searchCategory = { query = "rarity >= 3" } },
        { name = "Early", priority = 2, enabled = { [BACKPACK] = true }, searchCategory = { query = "rarity >= 4" } },
        { name = "Later", priority = 9, enabled = { [BACKPACK] = true }, searchCategory = { query = "type = weapon" } },
      }
      assert.are.equal("Early", merchant:ReadItems(ctx())[1].category)
    end)

    -- category-lifecycle.md §6: at equal priority an item placed in a category by hand stays there.
    it("gives a tie between an item placed by hand and a rule to where it was placed, as the bags do", function()
      _G._merchant.items = { vendorItem(13) }
      customByID[13] = { "Blades", 3 }
      searchCategories = { { name = "Shiny", priority = 3, enabled = { [BACKPACK] = true },
        searchCategory = { query = "rarity >= 3" } } }
      assert.are.equal("Blades", merchant:ReadItems(ctx())[1].category)
      searchCategories[1].priority = 2
      assert.are.equal("Shiny", merchant:ReadItems(ctx())[1].category, "a rule with a lower number wins")
    end)

    it("names a grouped search category after the item, creating nothing", function()
      _G._merchant.items = { vendorItem(11), vendorItem(13) }
      searchCategories = { { name = "Gear", priority = 10, enabled = { [BACKPACK] = true }, groupBy = GROUP_BY_TYPE,
        searchCategory = { query = "rarity >= 3" } } }
      local list = merchant:ReadItems(ctx())
      assert.are.same({ "Gear - Armor", "Gear - Weapon" }, { list[1].category, list[2].category })
    end)

    it("orders sections as the backpack does, items in the vendor's order", function()
      _G._merchant.items = { vendorItem(12), vendorItem(11), vendorItem(10) }
      local sections = merchant:BuildSections(merchant:ReadItems(ctx()))
      assert.are.same({ "Armor", "Consumable" }, { sections[1].name, sections[2].name })
      assert.are.same({ 12, 10 }, { sections[2].items[1].itemID, sections[2].items[2].itemID })
    end)
  end)

  describe("searching", function()
    it("searches the vendor's items in their own index, leaving the bags' alone", function()
      _G._merchant.items = { vendorItem(10), vendorItem(11) }
      merchant:ReadItems(ctx())
      assert.is_nil(merchant:Search(""))
      assert.are.same({ ["vendor:2"] = true }, merchant:Search("plate"))
      assert.are.same({ ["vendor:1"] = true }, merchant:Search("type != armor"))
      assert.are.same({ ["vendor:1"] = true }, merchant:Search("NOT type = armor"), "a NOT covers the vendor's items")
      assert.are.same({}, search:Search("plate"), "nothing in the bags' index")
      assert.are.same({}, search:Search("NOT plate"), "nor in a NOT over the bags' index")
    end)

    it("searches a vendor item's crafting tier, read from its link", function()
      _G._merchant.items = { vendorItem(10), vendorItem(12) }
      merchant:ReadItems(ctx())
      assert.are.same({ ["vendor:2"] = true }, merchant:Search("quality = 2"))
    end)

    -- Rule #1: read once the item's data has loaded; the vendor reads again on GET_ITEM_INFO_RECEIVED.
    it("reads no crafting tier for a vendor item whose data has not loaded", function()
      local asked = 0
      override(stubs.items, "CraftingQualityOf", function() asked = asked + 1; return 2 end)
      _G._merchant.items = { vendorItem(14) }
      local _, cold = merchant:ReadItems(ctx())
      assert.is_true(cold)
      assert.are.equal(0, asked)
      assert.are.same({}, merchant:Search("quality = 2"))
    end)

    it("forgets the last vendor's items", function()
      _G._merchant.items = { vendorItem(10), vendorItem(11) }
      merchant:ReadItems(ctx())
      _G._merchant.items = { vendorItem(10) }
      merchant:ReadItems(ctx())
      assert.are.same({}, merchant:Search("plate"))
    end)
  end)

  describe("buyback", function()
    it("lists what was sold, newest first", function()
      _G._merchant.buyback = {
        { name = "Old", texture = 1, price = 5, quantity = 2, isUsable = true, link = link(10) },
        { name = "New", texture = 2, price = 9, quantity = 1, isUsable = false, link = link(11) },
      }
      local list = merchant:ReadBuyback()
      assert.are.same({ 2, "New", 9, 1, false, 3 },
        { list[1].index, list[1].name, list[1].price, list[1].quantity, list[1].isUsable, list[1].quality })
      assert.are.equal(1, list[2].index)
    end)

    it("buys back by index", function()
      merchant:Buyback(2)
      assert.are.same({ 2 }, _G._merchantCalls.buyback)
    end)
  end)

  describe("repair", function()
    before_each(function()
      override(_G, "GetInventoryItemLink", function(_, slot) return slot <= 3 and link(10 + slot) or nil end)
      override(_G, "GetInventoryItemTexture", function(_, slot) return 500 + slot end)
      override(C_Container, "GetContainerNumSlots", function(bag) return bag == 0 and 2 or 0 end)
      override(C_Container, "GetContainerItemLink", function(bag, slot) return link(20 + slot) end)
      override(C_Container, "GetContainerItemInfo", function(bag, slot) return { iconFileID = 600 + slot } end)
    end)

    it("lists damaged equipped and bag items with their durability and cost, nothing else", function()
      _G._durability = { [1] = { 30, 100 }, [2] = { 100, 100 }, [3] = { 0, 60 } }
      _G._bagDurability = { ["0:1"] = { 50, 50 }, ["0:2"] = { 5, 50 } }
      _G._repairCosts = { ["inv:1"] = 700, ["inv:3"] = 900, ["bag:0:2"] = 40 }
      local repair = merchant:ReadRepair()
      assert.are.same({ { 1, 30, 100, 700, 501 }, { 3, 0, 60, 900, 503 } }, {
        { repair.equipped[1].slot, repair.equipped[1].durability, repair.equipped[1].maxDurability,
          repair.equipped[1].cost, repair.equipped[1].texture },
        { repair.equipped[2].slot, repair.equipped[2].durability, repair.equipped[2].maxDurability,
          repair.equipped[2].cost, repair.equipped[2].texture },
      })
      assert.are.same({ 0, 2, 5, 50, 40, 602, link(22) }, { repair.bags[1].bag, repair.bags[1].slot,
        repair.bags[1].durability, repair.bags[1].maxDurability, repair.bags[1].cost, repair.bags[1].texture,
        repair.bags[1].link })
      assert.are.equal(1, #repair.bags)
    end)

    it("repairs one item in repair mode, putting the cursor back as it was", function()
      merchant:RepairOne({ slot = 3 })
      merchant:RepairOne({ bag = 0, slot = 2 })
      assert.are.same({ { slot = 3, repairing = true } }, _G._merchantCalls.inventoryPickups)
      assert.are.same({ bag = 0, slot = 2 }, C_Container._pickups[#C_Container._pickups])
      assert.is_false(InRepairMode())
      ShowRepairCursor()
      merchant:RepairOne({ slot = 1 })
      assert.is_true(InRepairMode(), "the player's own repair cursor stays")
    end)

    it("repairs everything, from the guild bank when asked", function()
      merchant:RepairAll(false)
      merchant:RepairAll(true)
      assert.are.same({ false, true }, _G._merchantCalls.repair)
    end)
  end)

  -- The right click of Blizzard's item button (MerchantItemButton_OnClick): Blizzard's own
  -- confirmations for items with extended costs, non-refundable items and expensive ones.
  describe("buying", function()
    local function standIn()
      local b = CreateFrame("Button")
      return b
    end

    local function read(...)
      _G._merchant.items = { ... }
      return merchant:ReadItems(ctx())
    end

    it("buys a plain item at once", function()
      local item = read(vendorItem(10, { price = 500 }))[1]
      merchant:Purchase(standIn(), item)
      assert.are.same({ { 1, nil } }, _G._merchantCalls.buy)
    end)

    it("asks Blizzard to confirm an expensive item, with the button Blizzard reads", function()
      local item = read(vendorItem(11, { price = 2000000, stackCount = 2 }))[1]
      merchant:Purchase(standIn(), item)
      assert.are.same({}, _G._merchantCalls.buy)
      assert.are.same({ id = 1, price = 2000000, link = link(11) }, _G._merchantCalls.confirmHighCost[1])
    end)

    it("hands an item with an extended cost or no refund to Blizzard's confirmation", function()
      local list = read(vendorItem(11, { price = 0, hasExtendedCost = true, stackCount = 5 }),
        vendorItem(12, { price = 300, refundable = false }))
      merchant:Purchase(standIn(), list[1])
      merchant:Purchase(standIn(), list[2])
      assert.are.same({ id = 1, price = nil, link = link(11), count = 5, name = "Item 11", texture = 1011,
        nonrefundable = false }, _G._merchantCalls.confirmExtended[1])
      assert.are.same({ id = 2, price = 300, link = link(12), count = 1, name = "Item 12", texture = 1012,
        nonrefundable = true }, _G._merchantCalls.confirmExtended[2])
      assert.are.same({}, _G._merchantCalls.buy)
    end)

    it("buys a quantity as Blizzard's stack split does: confirmed for extended costs, at once otherwise", function()
      local list = read(vendorItem(10, { price = 2000000, maxStack = 20 }),
        vendorItem(11, { price = 0, hasExtendedCost = true }))
      merchant:Purchase(standIn(), list[1], 7)
      merchant:Purchase(standIn(), list[2], 3)
      assert.are.same({ { 1, 7 } }, _G._merchantCalls.buy)
      assert.are.equal(3, _G._merchantCalls.confirmExtended[1].quantity)
    end)

    it("says how many can be bought at once: the stack limit, what the money and the cost items allow", function()
      override(_G, "GetMoney", function() return 1000 end)
      override(C_Item, "GetItemCount", function() return 9 end)
      local list = read(vendorItem(10, { price = 100, stackCount = 1, maxStack = 20 }),
        vendorItem(11, { price = 0, hasExtendedCost = true, stackCount = 1, maxStack = 50,
          costs = { { texture = 1, value = 3, link = link(12) } } }),
        vendorItem(12, { price = 0, maxStack = 30 }))
      assert.are.equal(10, merchant:MaxPurchasable(list[1]))
      assert.are.equal(3, merchant:MaxPurchasable(list[2]))
      assert.are.equal(30, merchant:MaxPurchasable(list[3]))
    end)
  end)

  -- As dropping an item on Blizzard's merchant frame, or on one of its item buttons, sells it.
  describe("selling what is on the cursor", function()
    it("sells it, and nothing without one", function()
      _G._cursorHasItem = true
      assert.are.equal("sold", merchant:SellCursorItem())
      assert.are.same({ 0 }, _G._merchantCalls.pickup)
      _G._cursorHasItem = false
      assert.are.equal("nothing", merchant:SellCursorItem())
      assert.are.same({ 0 }, _G._merchantCalls.pickup)
    end)

    it("lets Blizzard ask first about selling a refundable item, as its merchant frame does", function()
      _G._cursorHasItem = true
      override(_G, "MerchantFrame", { refundItem = "bag button", refundItemEquipped = false })
      _G._extendedPriceShown = true
      assert.are.equal("asked", merchant:SellCursorItem())
      assert.are.same({}, _G._merchantCalls.pickup)
      assert.are.equal("bag button", _G._extendedPriceAsked.button)
      _G._extendedPriceShown = false
      assert.are.equal("sold", merchant:SellCursorItem(), "not refundable: sold")
      _G._cursorHasItem = false
    end)
  end)

  describe("junk", function()
    it("sells all junk through Blizzard's own confirmation where the client has it", function()
      _G._merchant.junk = 3
      assert.is_true(merchant:HasSellAllJunk())
      assert.are.equal(3, merchant:NumJunk())
      merchant:SellAllJunk()
      assert.are.equal(1, _G._merchantCalls.sellJunkClicked)
      _G._merchant.sellJunkEnabled = false
      assert.is_false(merchant:HasSellAllJunk())
    end)

    it("finds Classic's junk itself: poor items worth something, in the backpack's bags", function()
      override(C_MerchantFrame, "IsSellAllJunkEnabled", nil)
      override(C_MerchantFrame, "GetNumJunkItems", nil)
      override(C_Container, "GetContainerNumSlots", function(bag) return bag == 0 and 3 or 1 end)
      override(C_Container, "GetContainerItemInfo", function(bag, slot)
        if bag == 0 and slot == 1 then return { quality = 0, hasNoValue = false } end
        if bag == 0 and slot == 2 then return { quality = 0, hasNoValue = true } end
        if bag == 1 then return { quality = 0, hasNoValue = false } end
        return { quality = 1 }
      end)
      assert.is_false(merchant:HasSellAllJunk())
      assert.are.same({ { bag = 0, slot = 1 }, { bag = 1, slot = 1 } }, merchant:JunkSlots())
      assert.are.equal(2, merchant:NumJunk())
    end)

    it("sells junk slots one by one while the merchant is open", function()
      local used = {}
      override(C_Container, "UseContainerItem", function(bag, slot) table.insert(used, { bag, slot }) end)
      merchant:SellSlots({ { bag = 0, slot = 1 }, { bag = 1, slot = 4 } })
      assert.are.same({ { 0, 1 }, { 1, 4 } }, used)
      merchant:SellSlots({ { bag = 0, slot = 1 } }, function() return false end)
      assert.are.equal(2, #used, "not once the merchant has closed")
    end)
  end)
end)
