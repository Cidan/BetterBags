local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class Sort: AceModule
local sort = addon:GetModule('Sort')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Search: AceModule
local search = addon:GetModule('Search')

---@class TooltipScanner: AceModule
local tooltipScanner = addon:GetModule('TooltipScanner')

-- NextMerchant is what BetterBags Next's vendor shows and does (next.md §10), with nothing drawn:
-- the open merchant's items with the backpack's categories in the backpack's order, searched in an
-- index of their own; what was sold (buyback); what needs repair and what that costs. Buying goes
-- the way Blizzard's item button's right click does (MerchantItemButton_OnClick): Blizzard's own
-- confirmations decide and ask, so BetterBags never buys what Blizzard would have asked about.
---@class NextMerchant: AceModule
---@field search Search The vendor's own search index (a search instance of its own).
local merchant = addon:NewModule('NextMerchant')

-- The most Blizzard's item costs show (MerchantFrame.lua MAX_ITEM_COST).
local MAX_ITEM_COST = 3

---@class (exact) NextVendorCost
---@field texture number|string
---@field value number
---@field link? string An item that is paid.
---@field currencyName? string A currency that is paid.

---@class NextVendorItem
---@field index number The merchant's index of it.
---@field link? string
---@field itemID? number
---@field name? string
---@field texture number|string
---@field price number Copper, per purchase (0 for none).
---@field stackCount number How many one purchase gives.
---@field numAvailable number How many are left (-1: no limit).
---@field maxStack number The most one purchase of a quantity can buy.
---@field isPurchasable boolean
---@field isUsable boolean
---@field hasExtendedCost boolean It costs items or currencies.
---@field currencyID? number It is a currency.
---@field isQuestStartItem boolean
---@field canAfford boolean
---@field refundable boolean Blizzard asks before buying what is not.
---@field isKnownHeirloom boolean
---@field quality? number
---@field costs NextVendorCost[]
---@field record ItemData What the backpack's categories and the vendor's search read.
---@field category string

---@class (exact) NextVendorSection
---@field name string
---@field items NextVendorItem[]

---@class (exact) NextBuybackItem
---@field index number
---@field name? string
---@field texture number|string
---@field price number
---@field quantity number
---@field isUsable boolean
---@field isBound boolean
---@field link? string
---@field quality? number

---@class (exact) NextRepairEntry
---@field slot number An equipment slot, or the slot in bag.
---@field bag? number
---@field link? string
---@field texture? number|string
---@field durability number
---@field maxDurability number
---@field cost number Copper.

function merchant:Init()
  -- A search instance of its own: the search module keeps everything it indexes on itself.
  local index = setmetatable({}, { __index = search })
  index:Init()
  -- A negated query covers the vendor's items, not the bags'.
  index.Universe = function(own)
    return own.indexed
  end
  self.search = index
end

-- costsOf reads what an item costs besides gold.
---@param index number
---@return NextVendorCost[]
local function costsOf(index)
  local costs = {}
  local count = GetMerchantItemCostInfo(index) or 0
  for i = 1, math.min(count, MAX_ITEM_COST) do
    local texture, value, link, currencyName = GetMerchantItemCostItem(index, i)
    if texture then
      table.insert(costs, { texture = texture, value = value, link = link, currencyName = currencyName })
    end
  end
  return costs
end

-- infoOf reads a merchant item as Blizzard's merchant frame does: C_MerchantFrame.GetItemInfo
-- where the client has it, GetMerchantItemInfo on Classic.
---@param index number
---@return table?
local function infoOf(index)
  if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
    return C_MerchantFrame.GetItemInfo(index)
  end
  local name, texture, price, stackCount, numAvailable, isPurchasable, isUsable, extendedCost, currencyID =
    GetMerchantItemInfo(index)
  if name == nil and texture == nil then
    return nil
  end
  return { name = name, texture = texture, price = price, stackCount = stackCount, numAvailable = numAvailable,
    isPurchasable = isPurchasable, isUsable = isUsable, hasExtendedCost = extendedCost, currencyID = currencyID }
end

-- recordOf builds the item record the backpack's categories (items:GetCategory) and the search
-- index read, from the item's link: the instant info first, which never needs the server
-- (data-loader.md §3), then the full info. It says whether the full info was there.
---@param item NextVendorItem
---@return ItemData record, boolean warm
local function recordOf(item)
  local link = item.link
  local info = {
    itemID = item.itemID,
    itemName = item.name,
    itemLink = link,
    itemIcon = item.texture,
    currentItemCount = item.stackCount,
  }
  local warm = false
  if link then
    local instID, instType, instSubType, instEquipLoc, _, instClassID, instSubclassID = C_Item.GetItemInfoInstant(link)
    info.itemID = info.itemID or instID
    info.itemType, info.itemSubType, info.itemEquipLoc = instType, instSubType, instEquipLoc
    info.classID, info.subclassID = instClassID, instSubclassID
    local name, _, quality, level, minLevel, itemType, itemSubType, _, equipLoc, _, sellPrice, classID, subclassID,
      bindType, expacID, _, isCraftingReagent = C_Item.GetItemInfo(link)
    if name ~= nil then
      warm = true
      info.itemName = name
      info.itemQuality = quality
      info.itemLevel = level
      info.itemMinLevel = minLevel
      info.itemType = info.itemType or itemType
      info.itemSubType = info.itemSubType or itemSubType
      info.itemEquipLoc = info.itemEquipLoc or equipLoc
      info.classID = info.classID or classID
      info.subclassID = info.subclassID or subclassID
      info.sellPrice = sellPrice
      info.bindType = bindType
      info.expacID = expacID
      info.isCraftingReagent = isCraftingReagent
      info.currentItemLevel = C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link) or level
    end
  end
  info.tooltipText = tooltipScanner:GetMerchantItemText(item.index)
  ---@type ItemData
  local record = {
    kind = const.BAG_KIND.BACKPACK,
    slotkey = "vendor:" .. item.index,
    itemInfo = info,
    containerInfo = { quality = info.itemQuality },
  }
  return record, warm
end

-- searchCategoriesOf evaluates the backpack's search categories over the vendor's index: each
-- item's best (the lowest priority number), named after the item for a grouped category; no
-- category is created for it.
---@private
---@param records table<string, ItemData>
---@return table<string, {name: string, priority: number}>
function merchant:searchCategoriesOf(records)
  local found = {}
  local kind = const.BAG_KIND.BACKPACK
  for _, filter in ipairs(categories:GetSortedSearchCategories() or {}) do
    if filter.enabled and filter.enabled[kind] and filter.searchCategory then
      local priority = filter.priority or 10
      local groupBy = filter.groupBy or const.SEARCH_CATEGORY_GROUP_BY.NONE
      for slotkey in pairs(self.search:Search(filter.searchCategory.query)) do
        local record = records[slotkey]
        if record ~= nil and (found[slotkey] == nil or priority < found[slotkey].priority) then
          local name = filter.name
          if groupBy ~= const.SEARCH_CATEGORY_GROUP_BY.NONE then
            local suffix = items:GetGroupBySuffix(record, groupBy)
            if suffix and suffix ~= "" then
              name = name .. " - " .. suffix
            end
          end
          found[slotkey] = { name = name, priority = priority }
        end
      end
    end
  end
  return found
end

-- ReadItems reads every item the open merchant sells, with its category, and indexes them in the
-- vendor's search (the last merchant's items are forgotten). It says whether any item's info was
-- not loaded yet (GET_ITEM_INFO_RECEIVED brings it).
---@param ctx Context
---@return NextVendorItem[] items, boolean cold
function merchant:ReadItems(ctx)
  local list = {}
  local cold = false
  local records = {}
  self.search:Wipe()
  for index = 1, GetMerchantNumItems() do
    local info = infoOf(index)
    if info then
      local name, texture, numAvailable = info.name, info.texture, info.numAvailable
      if info.currencyID and CurrencyContainerUtil and CurrencyContainerUtil.GetCurrencyContainerInfo then
        name, texture, numAvailable = CurrencyContainerUtil.GetCurrencyContainerInfo(info.currencyID, numAvailable, name,
          texture, nil)
      end
      local itemID = GetMerchantItemID and GetMerchantItemID(index) or nil
      local isHeirloom = addon.isRetail and itemID ~= nil and C_Heirloom ~= nil and C_Heirloom.IsItemHeirloom(itemID)
      -- Classic asks about no purchase's refund: its heirloom check is commented out (Vanilla
      -- MerchantFrame.lua); retail asks about what C_MerchantFrame says is not refundable.
      local refundable = true
      if addon.isRetail and C_MerchantFrame and C_MerchantFrame.IsMerchantItemRefundable then
        refundable = C_MerchantFrame.IsMerchantItemRefundable(index)
      end
      ---@type NextVendorItem
      local item = {
        index = index,
        link = GetMerchantItemLink(index),
        itemID = itemID,
        name = name,
        texture = texture,
        price = info.price or 0,
        stackCount = info.stackCount or 1,
        numAvailable = numAvailable or -1,
        maxStack = GetMerchantItemMaxStack(index) or 1,
        isPurchasable = info.isPurchasable ~= false,
        isUsable = info.isUsable ~= false,
        hasExtendedCost = info.hasExtendedCost == true,
        currencyID = info.currencyID,
        isQuestStartItem = info.isQuestStartItem == true,
        canAfford = CanAffordMerchantItem(index) ~= false,
        refundable = refundable,
        isKnownHeirloom = isHeirloom and C_Heirloom.PlayerHasHeirloom(itemID) or false,
        costs = costsOf(index),
      }
      local record, warm = recordOf(item)
      if item.link and not warm then
        cold = true
      end
      item.record = record
      item.quality = record.itemInfo.itemQuality
      item.category = items:GetCategory(ctx, record)
      record.itemInfo.category = item.category
      records[record.slotkey] = record
      self.search:Add(record)
      table.insert(list, item)
    end
  end
  local found = self:searchCategoriesOf(records)
  for _, item in ipairs(list) do
    local hit = found[item.record.slotkey]
    if hit then
      -- As items:GetCategory weighs them: a rule beats an item placed by hand only with a lower
      -- priority number; at a tie the item stays where it was placed.
      local custom, customPriority = categories:GetCustomCategory(ctx, const.BAG_KIND.BACKPACK, item.record)
      if not custom or (customPriority or 10) > hit.priority then
        local old = item.category
        item.category = hit.name
        item.record.itemInfo.category = hit.name
        self.search:UpdateCategoryIndex(item.record, old)
      end
    end
  end
  return list, cold
end

-- BuildSections groups items by category, the categories in the backpack's section order (its
-- sort setting and pinned order), the items of each in the merchant's order.
---@param list NextVendorItem[]
---@return NextVendorSection[]
function merchant:BuildSections(list)
  local byName, order = {}, {}
  for _, item in ipairs(list) do
    local section = byName[item.category]
    if section == nil then
      section = { name = item.category, items = {} }
      byName[item.category] = section
      table.insert(order, section)
    end
    table.insert(section.items, item)
  end
  local kind = const.BAG_KIND.BACKPACK
  local sortFunc = sort:GetCategoryDataSortFunction(kind, database:GetBagView(kind))
  local data = {}
  for _, section in ipairs(order) do
    table.insert(data, { name = section.name, count = #section.items, section = section })
  end
  table.sort(data, sortFunc)
  local sections = {}
  for _, d in ipairs(data) do
    table.insert(sections, d.section)
  end
  return sections
end

-- Search returns the vendor items matching a query (the bags' query language), by slot key, or
-- nil for an empty query.
---@param text string
---@return table<string, boolean>?
function merchant:Search(text)
  if text == nil or text == "" then
    return nil
  end
  -- Only the vendor's slots: the search's results can carry markers of its own (___NEGATED___).
  local results = {}
  for slotkey in pairs(self.search:Search(text)) do
    if self.search.indexed[slotkey] ~= nil then
      results[slotkey] = true
    end
  end
  return results
end

---@param link? string
---@return number?
local function qualityOf(link)
  if link == nil then
    return nil
  end
  local _, _, quality = C_Item.GetItemInfo(link)
  return quality
end

-- ReadBuyback lists what was sold to the merchant, newest first (Blizzard shows the newest,
-- GetBuybackItemInfo(GetNumBuybackItems()), on its merchant tab).
---@return NextBuybackItem[]
function merchant:ReadBuyback()
  local list = {}
  for index = GetNumBuybackItems(), 1, -1 do
    local name, texture, price, quantity, _, isUsable, isBound = GetBuybackItemInfo(index)
    if name or texture then
      local link = GetBuybackItemLink(index)
      table.insert(list, { index = index, name = name, texture = texture, price = price or 0, quantity = quantity or 1,
        isUsable = isUsable ~= false, isBound = isBound == true, link = link, quality = qualityOf(link) })
    end
  end
  return list
end

---@param index number
function merchant:Buyback(index)
  BuybackItem(index)
end

-- bagIDs returns the backpack's bags, in order.
---@return number[]
local function bagIDs()
  local ids = {}
  for bag in pairs(const.BACKPACK_BAGS) do
    table.insert(ids, bag)
  end
  table.sort(ids)
  return ids
end

-- ReadRepair lists what is worn and what is in the bags that is damaged, with its durability and
-- what repairing it costs.
---@return {equipped: NextRepairEntry[], bags: NextRepairEntry[]}
function merchant:ReadRepair()
  local equipped, bags = {}, {}
  for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
    local link = GetInventoryItemLink("player", slot)
    local durability, maxDurability = GetInventoryItemDurability(slot)
    if link and durability and maxDurability and durability < maxDurability then
      table.insert(equipped, { slot = slot, link = link, texture = GetInventoryItemTexture("player", slot),
        durability = durability, maxDurability = maxDurability, cost = tooltipScanner:GetInventoryRepairCost(slot) })
    end
  end
  for _, bag in ipairs(bagIDs()) do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      local durability, maxDurability = C_Container.GetContainerItemDurability(bag, slot)
      if durability and maxDurability and durability < maxDurability then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        table.insert(bags, { bag = bag, slot = slot, link = C_Container.GetContainerItemLink(bag, slot),
          texture = info and info.iconFileID, durability = durability, maxDurability = maxDurability,
          cost = tooltipScanner:GetBagRepairCost(bag, slot) })
      end
    end
  end
  return { equipped = equipped, bags = bags }
end

-- RepairOne repairs one item: in repair mode a pickup repairs it, as a click on it does after
-- Blizzard's Repair An Item button (MerchantRepairItemButton). The cursor goes back to the mode it
-- was in.
---@param entry NextRepairEntry
function merchant:RepairOne(entry)
  local wasRepairing = InRepairMode()
  if not wasRepairing then
    ShowRepairCursor()
  end
  if entry.bag ~= nil then
    C_Container.PickupContainerItem(entry.bag, entry.slot)
  else
    PickupInventoryItem(entry.slot)
  end
  if not wasRepairing then
    HideRepairCursor()
  end
end

-- RepairAll repairs everything, from the guild bank with guild (Blizzard's two repair buttons).
---@param guild boolean
function merchant:RepairAll(guild)
  RepairAllItems(guild)
end

-- standIn makes button carry what Blizzard's confirmations read of a merchant item button
-- (MerchantFrame_UpdateMerchantInfo sets them): its ID, price (none for a price paid only in
-- other costs), extended cost, name, link, texture, count and whether to warn it is not refundable.
---@param button Button
---@param item NextVendorItem
local function standIn(button, item)
  button:SetID(item.index)
  if item.hasExtendedCost and item.price <= 0 then
    button.price = nil
  else
    button.price = item.price
  end
  button.extendedCost = item.hasExtendedCost or nil
  button.name = item.name
  button.link = item.link
  button.texture = item.texture
  button.count = item.stackCount
  button.showNonrefundablePrompt = not item.refundable
end

-- Purchase buys an item as Blizzard's merchant item button does: a right click
-- (MerchantItemButton_OnClick) without quantity, its stack split (SplitStack) with one. Items with
-- extended costs and items that are not refundable go to Blizzard's MerchantFrame_ConfirmExtendedItemCost,
-- expensive ones (MERCHANT_HIGH_PRICE_COST) to MerchantFrame_ConfirmHighCostItem; those buy, asking
-- first when Blizzard would. button is the vendor button, made to carry what they read.
---@param button Button
---@param item NextVendorItem
---@param quantity? number
function merchant:Purchase(button, item, quantity)
  standIn(button, item)
  if quantity ~= nil then
    if button.extendedCost or button.showNonrefundablePrompt then
      MerchantFrame_ConfirmExtendedItemCost(button, quantity)
    elseif quantity > 0 then
      BuyMerchantItem(item.index, quantity)
    end
    return
  end
  if button.extendedCost or button.showNonrefundablePrompt then
    MerchantFrame_ConfirmExtendedItemCost(button)
  elseif button.price and button.price >= MERCHANT_HIGH_PRICE_COST then
    MerchantFrame_ConfirmHighCostItem(button)
  else
    BuyMerchantItem(item.index)
  end
end

-- MaxPurchasable is the most one quantity purchase can buy, as Blizzard's stack split works it out
-- (MerchantItemButton_OnModifiedClick): the stack limit, what the money pays for, and what the
-- items it costs pay for.
---@param item NextVendorItem
---@return number
function merchant:MaxPurchasable(item)
  local maxStack = item.maxStack
  local canAfford = maxStack
  if item.price and item.price > 0 then
    canAfford = math.floor(GetMoney() / (item.price / item.stackCount))
  end
  if item.hasExtendedCost then
    for _, cost in ipairs(item.costs) do
      if cost.link and not cost.currencyName then
        local have = C_Item.GetItemCount(cost.link, false, false, true)
        canAfford = math.min(canAfford, math.floor(have / (cost.value / item.stackCount)))
      end
    end
  end
  return math.min(maxStack, canAfford)
end

-- HasSellAllJunk says whether the client sells all junk itself, with Blizzard's own confirmation
-- (retail's Sell All Junk button).
---@return boolean
function merchant:HasSellAllJunk()
  return C_MerchantFrame ~= nil and C_MerchantFrame.IsSellAllJunkEnabled ~= nil
    and MerchantFrame_OnSellAllJunkButtonClicked ~= nil and C_MerchantFrame.IsSellAllJunkEnabled() == true
end

-- JunkSlots lists the junk in the backpack's bags, as Blizzard marks it: poor items that sell for
-- something (ContainerFrameItemButtonMixin:UpdateJunkItem).
---@return {bag: number, slot: number}[]
function merchant:JunkSlots()
  local slots = {}
  for _, bag in ipairs(bagIDs()) do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.quality == const.ITEM_QUALITY.Poor and not info.hasNoValue then
        table.insert(slots, { bag = bag, slot = slot })
      end
    end
  end
  return slots
end

-- SellCursorItem sells the item on the cursor, as dropping it on Blizzard's merchant frame does (its
-- OnMouseUp), or on one of its item buttons (a left click picks the merchant item up while holding
-- the player's: a sale): Blizzard asks first about a refundable item. It returns what it did, for
-- profiler traces: "sold", "asked" (Blizzard's refund question) or "nothing" (no item on the cursor).
---@return string
function merchant:SellCursorItem()
  if not CursorHasItem() then
    return "nothing"
  end
  if MerchantFrame and MerchantFrame.refundItem
    and ContainerFrame_GetExtendedPriceString(MerchantFrame.refundItem, MerchantFrame.refundItemEquipped) then
    return "asked"
  end
  PickupMerchantItem(0)
  return "sold"
end

---@return number
function merchant:NumJunk()
  if C_MerchantFrame and C_MerchantFrame.GetNumJunkItems then
    return C_MerchantFrame.GetNumJunkItems()
  end
  return #self:JunkSlots()
end

-- SellAllJunk is Blizzard's Sell All Junk button: its confirmation, then C_MerchantFrame.SellAllJunkItems.
function merchant:SellAllJunk()
  MerchantFrame_OnSellAllJunkButtonClicked()
end

-- SellSlots sells items to the merchant one by one, as a right click at a merchant does, while
-- stillOpen (when given) says the merchant is open.
---@param slots {bag: number, slot: number}[]
---@param stillOpen? fun(): boolean
function merchant:SellSlots(slots, stillOpen)
  for _, s in ipairs(slots) do
    if stillOpen and not stillOpen() then
      return
    end
    C_Container.UseContainerItem(s.bag, s.slot)
  end
end

merchant:Init()
