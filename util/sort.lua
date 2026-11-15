local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Sort: AceModule
local sort = addon:NewModule('Sort')

---@class Localization: AceModule
local L =  addon:GetModule('Localization')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

local KEY = const.ITEM_ORDER_KEY

---@param aData ItemData
---@param bData ItemData
---@return boolean
local function invalidData(aData, bData)
  if not aData or not bData
  or not aData.itemInfo or not bData.itemInfo
  or not aData.itemInfo.itemQuality or not bData.itemInfo.itemQuality
  or not aData.itemInfo.currentItemCount or not bData.itemInfo.currentItemCount
  or not aData.itemInfo.itemGUID or not bData.itemInfo.itemGUID
  or not aData.itemInfo.itemName or not bData.itemInfo.itemName then
    return true
  end
  return false
end

-- shownCount is the count an item's button shows: a virtual stack's total, else the item's own count.
---@param data ItemData
---@return number
local function shownCount(data)
  return data.stackedCount or data.itemInfo.currentItemCount
end

-- stackWorth is what a vendor pays for the stack an item's button shows.
---@param data ItemData
---@return number
local function stackWorth(data)
  return items:SellPriceOf(data) * shownCount(data)
end

---@param data ItemData
---@return number
local function eachWorth(data)
  return items:SellPriceOf(data)
end

-- trackTop is the item level an item's upgrade track takes it to (items:ReadItemTraits), which ranks the tracks
-- whatever language their names are in; 0 for an item on no track, or read cold.
---@param data ItemData
---@return number
local function trackTop(data)
  local traits = data.itemInfo.traits
  return traits and traits.upgradeTrack and traits.upgradeMaxItemLevel or 0
end

-- The equipment slots in the character sheet's order, top to bottom, then the weapons, then what is equipped elsewhere;
-- a robe goes where a chest piece does (Enum.InventoryType's ItemEquipLoc, warcraft.wiki.gg).
local SLOTS = {
  { "INVTYPE_HEAD" }, { "INVTYPE_NECK" }, { "INVTYPE_SHOULDER" }, { "INVTYPE_BODY" }, { "INVTYPE_CHEST", "INVTYPE_ROBE" },
  { "INVTYPE_WAIST" }, { "INVTYPE_LEGS" }, { "INVTYPE_FEET" }, { "INVTYPE_WRIST" }, { "INVTYPE_HAND" },
  { "INVTYPE_FINGER" }, { "INVTYPE_TRINKET" }, { "INVTYPE_CLOAK" }, { "INVTYPE_2HWEAPON" }, { "INVTYPE_WEAPONMAINHAND" },
  { "INVTYPE_WEAPON" }, { "INVTYPE_WEAPONOFFHAND" }, { "INVTYPE_SHIELD" }, { "INVTYPE_HOLDABLE" }, { "INVTYPE_RANGED" },
  { "INVTYPE_RANGEDRIGHT" }, { "INVTYPE_THROWN" }, { "INVTYPE_RELIC" }, { "INVTYPE_AMMO" }, { "INVTYPE_QUIVER" },
  { "INVTYPE_TABARD" }, { "INVTYPE_PROFESSION_TOOL" }, { "INVTYPE_PROFESSION_GEAR" },
  { "INVTYPE_EQUIPABLESPELL_OFFENSIVE" }, { "INVTYPE_EQUIPABLESPELL_UTILITY" }, { "INVTYPE_EQUIPABLESPELL_DEFENSIVE" },
  { "INVTYPE_EQUIPABLESPELL_WEAPON" }, { "INVTYPE_BAG" },
}

---@type table<string, number>
local SLOT_RANK = {}
for rank, locs in ipairs(SLOTS) do
  for _, loc in ipairs(locs) do
    SLOT_RANK[loc] = rank
  end
end

-- slotRank is where an item's slot is in SLOTS; after every slot for what is not equipment.
---@param data ItemData
---@return number
local function slotRank(data)
  return SLOT_RANK[data.itemInfo.itemEquipLoc] or #SLOTS + 1
end

-- Each key's comparison of two items with their data: below 0 when the first goes first, above 0 when the second does,
-- 0 when the key holds them equal. Each compares its values itself: a sort calls them thousands of times.
---@type table<ItemOrderKey, fun(aData: ItemData, bData: ItemData): number>
local compare = {
  [KEY.QUALITY] = function(a, b)
    local x, y = a.itemInfo.itemQuality, b.itemInfo.itemQuality
    if x == y then return 0 end
    return x > y and -1 or 1
  end,
  [KEY.NAME] = function(a, b)
    local x, y = a.itemInfo.itemName, b.itemInfo.itemName
    if x == y then return 0 end
    return x < y and -1 or 1
  end,
  [KEY.ITEM_LEVEL] = function(a, b)
    local x, y = a.itemInfo.currentItemLevel, b.itemInfo.currentItemLevel
    if x == y then return 0 end
    return x > y and -1 or 1
  end,
  [KEY.UPGRADE_TRACK] = function(a, b)
    local x, y = trackTop(a), trackTop(b)
    if x == y then return 0 end
    return x > y and -1 or 1
  end,
  [KEY.EQUIPMENT_SLOT] = function(a, b)
    local x, y = slotRank(a), slotRank(b)
    if x == y then return 0 end
    return x < y and -1 or 1
  end,
  -- Blizzard's item class, then its subclass, by their IDs (Enum.ItemClass): the same in every language.
  [KEY.ITEM_TYPE] = function(a, b)
    local x, y = a.itemInfo.classID, b.itemInfo.classID
    if x == y then
      x, y = a.itemInfo.subclassID, b.itemInfo.subclassID
      if x == y then return 0 end
    end
    return x < y and -1 or 1
  end,
  -- A missing expansion is Classic's.
  [KEY.EXPANSION] = function(a, b)
    local x, y = a.itemInfo.expacID or 0, b.itemInfo.expacID or 0
    if x == y then return 0 end
    return x < y and -1 or 1
  end,
  [KEY.COUNT] = function(a, b)
    local x, y = shownCount(a), shownCount(b)
    if x == y then return 0 end
    return x > y and -1 or 1
  end,
  [KEY.SELL_PRICE_STACK] = function(a, b)
    local x, y = stackWorth(a), stackWorth(b)
    if x == y then return 0 end
    return x > y and -1 or 1
  end,
  [KEY.SELL_PRICE_EACH] = function(a, b)
    local x, y = eachWorth(a), eachWorth(b)
    if x == y then return 0 end
    return x > y and -1 or 1
  end,
}

-- Each key's name in the dropdowns that choose an order. Not translated, as the settings catalog's choices are not.
---@type table<ItemOrderKey, string>
local KEY_NAMES = {
  [KEY.NAME] = 'Name',
  [KEY.QUALITY] = 'Quality',
  [KEY.ITEM_LEVEL] = 'Item Level',
  [KEY.UPGRADE_TRACK] = 'Upgrade Track',
  [KEY.EQUIPMENT_SLOT] = 'Equipment Slot',
  [KEY.ITEM_TYPE] = 'Item Type',
  [KEY.EXPANSION] = 'Expansion',
  [KEY.COUNT] = 'Count',
  [KEY.SELL_PRICE_STACK] = 'Sell Price (Stack)',
  [KEY.SELL_PRICE_EACH] = 'Sell Price (Each)',
}

---@type table<string, ItemOrderKey>
local KEY_OF_NAME = {}
for key, name in pairs(KEY_NAMES) do
  KEY_OF_NAME[name] = key
end

-- A later tier's choice of no key.
local NONE = 'None'

-- The keys an order is chosen from, in the dropdowns' order. Upgrade Track only where the client reads upgrade tracks
-- (items:ReadItemTraits): elsewhere no item has one, and it would order nothing. A client's APIs do not change while
-- it runs, so this is decided once.
---@type ItemOrderKey[]
local OFFERED = { KEY.NAME, KEY.QUALITY, KEY.ITEM_LEVEL, KEY.EQUIPMENT_SLOT, KEY.ITEM_TYPE, KEY.EXPANSION, KEY.COUNT,
  KEY.SELL_PRICE_STACK, KEY.SELL_PRICE_EACH }
if C_Item.GetItemUpgradeInfo then
  table.insert(OFFERED, 4, KEY.UPGRADE_TRACK)
end

---@type table<ItemOrderKey, boolean>
local OFFERS = {}
for _, key in ipairs(OFFERED) do
  OFFERS[key] = true
end

-- inOrder returns the comparison an order makes of two items with their data: its keys first to last, the name after
-- them when it is not one of them, then the bigger pile and the GUID, which make the order total.
---@param order ItemOrderKey[]
---@return fun(aData: ItemData, bData: ItemData): boolean
local function inOrder(order)
  local compares, named = {}, false
  for _, key in ipairs(order) do
    assert(compare[key] ~= nil, "Unknown item order key: " .. tostring(key))
    table.insert(compares, compare[key])
    named = named or key == KEY.NAME
  end
  if not named then
    table.insert(compares, compare[KEY.NAME])
  end
  local count = #compares
  return function(aData, bData)
    for i = 1, count do
      local c = compares[i](aData, bData)
      if c ~= 0 then
        return c < 0
      end
    end
    if aData.itemInfo.currentItemCount ~= bData.itemInfo.currentItemCount then
      return aData.itemInfo.currentItemCount > bData.itemInfo.currentItemCount
    end
    return aData.itemInfo.itemGUID < bData.itemInfo.itemGUID
  end
end

-- ItemDataComparator returns the comparison of two items' data an order makes (item-sort.md §1): free slots and gaps
-- last, two items either of which lacks its data unordered, the rest by the order's keys.
---@param order ItemOrderKey[]
---@return fun(aData: ItemData, bData: ItemData): boolean
function sort:ItemDataComparator(order)
  local ordered = inOrder(order)
  return function(aData, bData)
    if aData.isFreeSlot or aData.isItemGap then return false end
    if bData.isFreeSlot or bData.isItemGap then return true end
    if invalidData(aData, bData) then return false end
    return ordered(aData, bData)
  end
end

-- GetItemDataSortFunction returns how the data pipeline sorts a bag's items (items:Phase9_Sort, BuildOrderedItems): a
-- category's items by its own order where it has one (Categories:ItemOrderOf), the others by the bag's in the view
-- (DB:GetItemOrder). A section shows its category's items in the list's order (Phase10_PartitionIntoTabs), so the
-- items of a category with its own order are kept apart in the list, after the bag's order's, by the category's name:
-- one order over the whole list, as table.sort needs. Each category's order is read once, the first time the sort meets it. With no category the
-- bag uses having its own order (Categories:HasItemOrders), the bag's order is the whole sort, read per item no further.
---@param kind BagKind
---@param view BagView
---@return fun(aData: ItemData, bData: ItemData): boolean
function sort:GetItemDataSortFunction(kind, view)
  if kind == const.BAG_KIND.UNDEFINED then
    return function() return false end
  end
  local order = database:GetItemOrder(kind, view)
  if not categories:HasItemOrders(kind) then
    return self:ItemDataComparator(order)
  end
  local bagOrder = inOrder(order)
  -- Each category's own order's comparison, or false for the bag's.
  ---@type table<string, fun(aData: ItemData, bData: ItemData): boolean|false>
  local own = {}
  local function read(category)
    local ownOrder = categories:ItemOrderOf(category, kind)
    local ordered = ownOrder and inOrder(ownOrder) or false
    own[category] = ordered
    return ordered
  end
  return function(aData, bData)
    if aData.isFreeSlot or aData.isItemGap then return false end
    if bData.isFreeSlot or bData.isItemGap then return true end
    if invalidData(aData, bData) then return false end
    local aCategory, bCategory = aData.itemInfo.category or "", bData.itemInfo.category or ""
    local aOwn, bOwn = own[aCategory], own[bCategory]
    if aOwn == nil then
      aOwn = read(aCategory)
    end
    if bOwn == nil then
      bOwn = read(bCategory)
    end
    if not aOwn then
      if bOwn then
        return true
      end
      return bagOrder(aData, bData)
    end
    if not bOwn then
      return false
    end
    if aCategory ~= bCategory then
      return aCategory < bCategory
    end
    return aOwn(aData, bData)
  end
end

-- ItemOrderKeys returns the keys an order is chosen from on this client, in the dropdowns' order.
---@return ItemOrderKey[]
function sort:ItemOrderKeys()
  return { unpack(OFFERED) }
end

-- OffersItemOrderKey says whether an order is chosen from a key on this client.
---@param key ItemOrderKey
---@return boolean
function sort:OffersItemOrderKey(key)
  return OFFERS[key] == true
end

-- ItemOrderKeyName returns a key's name, as the dropdowns show it.
---@param key ItemOrderKey
---@return string
function sort:ItemOrderKeyName(key)
  return KEY_NAMES[key]
end

-- ItemOrderChoices returns what a tier of an order (1 for Item Order, 2 for Then By, 3 for And Then By) can be, as its
-- dropdown lists them: for the first, every key offered; for a later one, None, then the keys the tiers above it have
-- not taken.
---@param order ItemOrderKey[]
---@param tier number
---@return string[]
function sort:ItemOrderChoices(order, tier)
  local taken = {}
  for i = 1, tier - 1 do
    if order[i] ~= nil then
      taken[order[i]] = true
    end
  end
  local choices = tier > 1 and { NONE } or {}
  for _, key in ipairs(OFFERED) do
    if not taken[key] then
      table.insert(choices, KEY_NAMES[key])
    end
  end
  return choices
end

-- ItemOrderChoice returns what a tier of an order is, as its dropdown shows it: its key's name, or None.
---@param order ItemOrderKey[]
---@param tier number
---@return string
function sort:ItemOrderChoice(order, tier)
  local key = order[tier]
  return key ~= nil and KEY_NAMES[key] or NONE
end

-- WithItemOrderChoice returns a new order: order with a tier set to a choice of its dropdown. A key is in an order once,
-- so a key chosen leaves the tier below that had it; None takes a later tier out, the tiers below it moving up.
---@param order ItemOrderKey[]
---@param tier number
---@param choice string
---@return ItemOrderKey[]
function sort:WithItemOrderChoice(order, tier, choice)
  local chosen = { unpack(order) }
  if choice == NONE then
    if tier > 1 and tier <= #chosen then
      table.remove(chosen, tier)
    end
    return chosen
  end
  local key = KEY_OF_NAME[choice]
  tier = math.min(tier, #chosen + 1)
  chosen[tier] = key
  for i = #chosen, 1, -1 do
    if i ~= tier and chosen[i] == key then
      table.remove(chosen, i)
    end
  end
  return chosen
end

---@param kind BagKind
---@param view BagView
---@return function
function sort:GetSectionSortFunction(kind, view)
  local sortType = database:GetSectionSortType(kind, view)
  if sortType == const.SECTION_SORT_TYPE.ALPHABETICALLY then
    return function(a, b)
      return self.SortSectionsAlphabetically(kind, a, b)
    end
  elseif sortType == const.SECTION_SORT_TYPE.SIZE_ASCENDING then
    return function(a, b)
      return self.SortSectionsBySizeAscending(kind, a, b)
    end
  elseif sortType == const.SECTION_SORT_TYPE.SIZE_DESCENDING then
    return function(a, b)
      return self.SortSectionsBySizeDescending(kind, a, b)
    end
  end
  -- Return the default alphabetical sort in case of an unknown sort type.
  -- This can happen if external addons modify the saved variables.
  return function(a, b)
    return self.SortSectionsAlphabetically(kind, a, b)
  end
end

---@param kind BagKind
---@param a Section
---@param b Section
---@return boolean, boolean
function sort.SortSectionsByPriority(kind, a, b)
  if not a or not b then return false, false end
  local aTitle, bTitle = a.title:GetText(), b.title:GetText()
  local pinnedItems = database:GetCustomSectionSort(kind)
  if not pinnedItems[aTitle] and not pinnedItems[bTitle] then return false, false end
  if pinnedItems[aTitle] and not pinnedItems[bTitle] then return true, true end
  if not pinnedItems[aTitle] and pinnedItems[bTitle] then return true, false end

  return true, pinnedItems[aTitle] < pinnedItems[bTitle]
end

---@param kind BagKind
---@param a Section
---@param b Section
---@return boolean
function sort.SortSectionsAlphabetically(kind, a, b)
  if not a or not b then return false end
  local shouldSort, sortResult = sort.SortSectionsByPriority(kind, a, b)
  if shouldSort then return sortResult end

  if a.title:GetText() == L:G("Recent Items") then return true end
  if b.title:GetText() == L:G("Recent Items") then return false end

  if a:GetFillWidth() then return false end
  if b:GetFillWidth() then return true end

  if a.title:GetText() == L:G("Free Space") then return false end
  if b.title:GetText() == L:G("Free Space") then return true end
  return a.title:GetText() < b.title:GetText()
end

---@param kind BagKind
---@param a Section
---@param b Section
---@return boolean
function sort.SortSectionsBySizeDescending(kind, a, b)
  if not a or not b then return false end
  local shouldSort, sortResult = sort.SortSectionsByPriority(kind, a, b)
  if shouldSort then return sortResult end

  if a.title:GetText() == L:G("Recent Items") then return true end
  if b.title:GetText() == L:G("Recent Items") then return false end

  if a:GetFillWidth() then return false end
  if b:GetFillWidth() then return true end

  if a.title:GetText() == L:G("Free Space") then return false end
  if b.title:GetText() == L:G("Free Space") then return true end
  local aSize, bSize = a:GetCellCount(), b:GetCellCount()
  if aSize ~= bSize then
    return aSize > bSize
  end
  return a.title:GetText() < b.title:GetText()
end

---@param kind BagKind
---@param a Section
---@param b Section
---@return boolean
function sort.SortSectionsBySizeAscending(kind, a, b)
  if not a or not b then return false end
  local shouldSort, sortResult = sort.SortSectionsByPriority(kind, a, b)
  if shouldSort then return sortResult end

  if a.title:GetText() == L:G("Recent Items") then return true end
  if b.title:GetText() == L:G("Recent Items") then return false end

  if a:GetFillWidth() then return false end
  if b:GetFillWidth() then return true end

  if a.title:GetText() == L:G("Free Space") then return false end
  if b.title:GetText() == L:G("Free Space") then return true end
  local aSize, bSize = a:GetCellCount(), b:GetCellCount()
  if aSize ~= bSize then
    return aSize < bSize
  end
  return a.title:GetText() < b.title:GetText()
end

-- slotOrder is where a bag's slots go in slot order: the backpack's keyring (Classic Era, WoW: Forever), whose bag
-- ID is below the backpack's, after every bag, as its number says (items:GetBagName).
---@param bagid number
---@return number
local function slotOrder(bagid)
  if bagid == Enum.BagIndex.Keyring and const.BACKPACK_BAGS[bagid] ~= nil then
    return math.huge
  end
  return bagid
end

---@param aData ItemData
---@param bData ItemData
---@return boolean
function sort.SortItemDataBySlot(aData, bData)
  if not aData then return false end
  if not bData then return true end
  if aData.bagid ~= bData.bagid then
    return slotOrder(aData.bagid) < slotOrder(bData.bagid)
  end
  return aData.slotid < bData.slotid
end

---@param kind BagKind
---@param a table
---@param b table
---@return boolean, boolean
function sort.SortCategoryDataByPriority(kind, a, b)
  if not a or not b then return false, false end
  local aTitle, bTitle = a.name, b.name
  local pinnedItems = database:GetCustomSectionSort(kind)
  if not pinnedItems[aTitle] and not pinnedItems[bTitle] then return false, false end
  if pinnedItems[aTitle] and not pinnedItems[bTitle] then return true, true end
  if not pinnedItems[aTitle] and pinnedItems[bTitle] then return true, false end

  return true, pinnedItems[aTitle] < pinnedItems[bTitle]
end

---@param kind BagKind
---@param a table
---@param b table
---@return boolean
function sort.SortCategoryDataAlphabetically(kind, a, b)
  if not a or not b then return false end
  local shouldSort, sortResult = sort.SortCategoryDataByPriority(kind, a, b)
  if shouldSort then return sortResult end

  if a.name == L:G("Recent Items") then return true end
  if b.name == L:G("Recent Items") then return false end

  if a.fillWidth then return false end
  if b.fillWidth then return true end

  if a.name == L:G("Free Space") then return false end
  if b.name == L:G("Free Space") then return true end
  return a.name < b.name
end

---@param kind BagKind
---@param a table
---@param b table
---@return boolean
function sort.SortCategoryDataBySizeDescending(kind, a, b)
  if not a or not b then return false end
  local shouldSort, sortResult = sort.SortCategoryDataByPriority(kind, a, b)
  if shouldSort then return sortResult end

  if a.name == L:G("Recent Items") then return true end
  if b.name == L:G("Recent Items") then return false end

  if a.fillWidth then return false end
  if b.fillWidth then return true end

  if a.name == L:G("Free Space") then return false end
  if b.name == L:G("Free Space") then return true end
  local aSize, bSize = a.count, b.count
  if aSize ~= bSize then
    return aSize > bSize
  end
  return a.name < b.name
end

---@param kind BagKind
---@param a table
---@param b table
---@return boolean
function sort.SortCategoryDataBySizeAscending(kind, a, b)
  if not a or not b then return false end
  local shouldSort, sortResult = sort.SortCategoryDataByPriority(kind, a, b)
  if shouldSort then return sortResult end

  if a.name == L:G("Recent Items") then return true end
  if b.name == L:G("Recent Items") then return false end

  if a.fillWidth then return false end
  if b.fillWidth then return true end

  if a.name == L:G("Free Space") then return false end
  if b.name == L:G("Free Space") then return true end
  local aSize, bSize = a.count, b.count
  if aSize ~= bSize then
    return aSize < bSize
  end
  return a.name < b.name
end

---@param kind BagKind
---@param view BagView
---@return function
function sort:GetCategoryDataSortFunction(kind, view)
  local sortType = database:GetSectionSortType(kind, view)
  if sortType == const.SECTION_SORT_TYPE.ALPHABETICALLY then
    return function(a, b)
      return self.SortCategoryDataAlphabetically(kind, a, b)
    end
  elseif sortType == const.SECTION_SORT_TYPE.SIZE_ASCENDING then
    return function(a, b)
      return self.SortCategoryDataBySizeAscending(kind, a, b)
    end
  elseif sortType == const.SECTION_SORT_TYPE.SIZE_DESCENDING then
    return function(a, b)
      return self.SortCategoryDataBySizeDescending(kind, a, b)
    end
  end
  return function(a, b)
    return self.SortCategoryDataAlphabetically(kind, a, b)
  end
end
