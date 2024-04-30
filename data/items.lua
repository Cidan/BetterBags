local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class EquipmentSets: AceModule
local equipmentSets = addon:GetModule('EquipmentSets')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

-- A slot key is a string that represents a bag and slot id.
---@alias SlotKey string

-- ItemLinkInfo contains all the information parsed from an item link.
---@class (exact) ItemLinkInfo
---@field itemID number
---@field enchantID string
---@field gemID1 string
---@field gemID2 string
---@field gemID3 string
---@field gemID4 string
---@field suffixID string
---@field uniqueID string
---@field linkLevel string
---@field specializationID string
---@field modifiersMask string
---@field itemContext string
---@field bonusIDs string[]
---@field modifierIDs string[]
---@field relic1BonusIDs string[]
---@field relic2BonusIDs string[]
---@field relic3BonusIDs string[]
---@field crafterGUID string
---@field extraEnchantID string

-- ItemData contains all the information about an item in a bag or bank.
---@class (exact) ItemData
---@field basic boolean
---@field itemInfo ExpandedItemInfo
---@field containerInfo ContainerItemInfo
---@field questInfo ItemQuestInfo
---@field bagid number
---@field slotid number
---@field slotkey string
---@field isItemEmpty boolean
---@field kind BagKind
---@field newItemTime number
---@field stacks number
---@field stackedOn string
---@field stackedCount number
---@field itemLinkInfo ItemLinkInfo
---@field itemHash string
---@field bagName string
---@field forceClear boolean
---@field nextStack string
local itemDataProto = {}

---@class (exact) Items: AceModule
---@field private slotInfo table<BagKind, SlotInfo>
---@field previousItemGUID table<number, table<number, string>>
---@field _newItemTimers table<string, number>
---@field _preSort boolean
local items = addon:NewModule('Items')

function items:OnInitialize()
  self.previousItemGUID = {}
  self:ResetSlotInfo()

  self._newItemTimers = {}
  self._preSort = false
end

function items:OnEnable()

  events:RegisterEvent('EQUIPMENT_SETS_CHANGED', function()
    self:DoRefreshAll()
  end)
  local eventList = {
    'BAG_UPDATE_DELAYED',
    'BAG_UPDATE',
    'PLAYERBANKSLOTS_CHANGED',
  }

  if addon.isRetail then
    table.insert(eventList, 'PLAYERREAGENTBANKSLOTS_CHANGED')
  end

  events:RegisterMessage('bags/FullRefreshAll', function()
    self:WipeAndRefreshAll()
  end)

  events:RegisterMessage('bags/SortBackpackClassic', function()
    self:RemoveNewItemFromAllItems()
    self:ClearItemCache()
    self:PreSort()
    _G.SortBags()
  end)

  events:RegisterMessage('bags/SortBackpack', function()
    self:RemoveNewItemFromAllItems()
    self:ClearItemCache()
    self:PreSort()
    C_Container:SortBags()
  end)

  events:GroupBucketEvent(eventList, {'bags/RefreshAll', 'bags/RefreshBackpack', 'bags/RefreshBank'}, function()
    debug:Log("Items", "Group Bucket Event for Refresh* Fired")
    self._preSort = false
    -- No total items means we're doing a full refresh (or the player bags are totally empty, which is rare).
    if InCombatLockdown() and self.slotInfo[const.BAG_KIND.BACKPACK].totalItems == 0 then
      addon.Bags.Backpack.drawAfterCombat = true
      print(L:G("BetterBags: Bags will refresh after combat ends."))
    else
      self:DoRefreshAll()
    end
  end)

  events:RegisterEvent('BANKFRAME_OPENED', function()
    if GameMenuFrame:IsShown() then
      return
    end
    addon.atBank = true
  end)
  events:RegisterEvent('BANKFRAME_CLOSED', function()
    addon.atBank = false
    items:ClearBankCache()
  end)
end

---@param kind BagKind
function items:WipeSlotInfo(kind)
  debug:Inspect("wiping slot info", kind)
  self.slotInfo = self.slotInfo or {}
  self.slotInfo[kind] = self:NewSlotInfo()
end

function items:ResetSlotInfo()
  self:WipeSlotInfo(const.BAG_KIND.BACKPACK)
  self:WipeSlotInfo(const.BAG_KIND.BANK)
end

function items:RemoveNewItemFromAllItems()
  for _, item in pairs(self.slotInfo[const.BAG_KIND.BACKPACK].itemsBySlotKey) do
    if C_NewItems.IsNewItem(item.bagid, item.slotid) then
      C_NewItems.RemoveNewItem(item.bagid, item.slotid)
    end
  end
  wipe(self._newItemTimers)
end

function items:RefreshAll()
  events:SendMessage('bags/RefreshAll')
end

---@private
function items:PreSort()
  self._preSort = true
  C_Timer.After(0.6, function()
    if self._preSort then
      self:WipeAndRefreshAll()
    end
  end)
end

---@private
function items:ClearItemCache()
  self.previousItemGUID = {}
  self:ResetSlotInfo()
  if addon.Bags.Backpack.currentView then
    addon.Bags.Backpack.currentView.fullRefresh = true
  end
  if addon.Bags.Bank.currentView then
    addon.Bags.Bank.currentView.fullRefresh = true
  end
  debug:Log("Items", "Item Cache Cleared")
end

function items:ClearBankCache()
  self:WipeSlotInfo(const.BAG_KIND.BANK)
  if addon.Bags.Bank.currentView then
    addon.Bags.Bank.currentView.fullRefresh = true
  end
  debug:Log("Items", "Bank Cache Cleared")
end

---@private
-- FullRefreshAll will wipe the item cache and refresh all items in all bags.
function items:WipeAndRefreshAll()
  debug:Log('WipeAndRefreshAll', "Wipe And Refresh All triggered")
  if InCombatLockdown() then
    addon.Bags.Backpack.drawAfterCombat = true
    print(L:G("BetterBags: Bags will refresh after combat ends."))
  else
    self:ClearItemCache()
    events:SendMessage('bags/RefreshAll', true)
  end
end

---@private
function items:DoRefreshAll()
  if not addon.Bags.Bank or not addon.Bags.Backpack then return end
  if addon.Bags.Bank.frame:IsShown() or addon.atBank then
    if addon.Bags.Bank.isReagentBank then
      self:RefreshReagentBank()
    else
      self:RefreshBank()
    end
  end
  self:RefreshBackpack()
end

function items:RefreshReagentBank()
  local container = self:NewLoader(const.BAG_KIND.BANK)
  -- Loop through all the bags and schedule each item for a refresh.
  for i in pairs(const.REAGENTBANK_BAGS) do
    self:StageBagForUpdate(i, container)
  end

  --- Process the item container.
  self:ProcessContainer(const.BAG_KIND.BANK, container)
end

function items:RefreshBank()
  equipmentSets:Update()
  local container = self:NewLoader(const.BAG_KIND.BANK)
  -- This is a small hack to force the bank bag quality data to be cached
  -- before the bank bag frame is drawn.
  for _, bag in pairs(const.BANK_ONLY_BAGS) do
    local id = C_Container.ContainerIDToInventoryID(bag)
    GetInventoryItemQuality("player", id)
  end

  -- Loop through all the bags and schedule each item for a refresh.
  for i in pairs(const.BANK_BAGS) do
    self:StageBagForUpdate(i, container)
  end

  --- Process the item container.
  self:ProcessContainer(const.BAG_KIND.BANK, container)
end

-- RefreshBackback will refresh all bags' contents entirely and update
-- the item database.
function items:RefreshBackpack()
  debug:StartProfile('Backpack Data Pipeline')

  equipmentSets:Update()
  local container = self:NewLoader(const.BAG_KIND.BACKPACK)

  -- Loop through all the bags and schedule each item for a refresh.
  for i in pairs(const.BACKPACK_BAGS) do
    self:StageBagForUpdate(i, container)
  end
  --- Process the item container.
  self:ProcessContainer(const.BAG_KIND.BACKPACK, container)
end

---@param newData ItemData
---@param oldData ItemData
---@return boolean
function items:ItemAdded(newData, oldData)
  if newData.isItemEmpty then return false end
  if not oldData or (oldData and oldData.isItemEmpty) then return true end
  return false
end

---@param newData ItemData
---@param oldData ItemData
---@return boolean
function items:ItemRemoved(newData, oldData)
  if not oldData or (oldData and oldData.isItemEmpty) then return false end
  if newData.isItemEmpty then return true end
  return false
end

---@param newData ItemData
---@param oldData ItemData
---@return boolean
function items:ItemChanged(newData, oldData)
  -- Item was marked as new when it wasn't before.
  if C_NewItems.IsNewItem(newData.bagid, newData.slotid) and oldData and oldData.itemInfo and not oldData.itemInfo.isNewItem then
    return true
  end

  -- Item count changed.
  if oldData and oldData.itemInfo and oldData.itemInfo.currentItemCount ~= newData.itemInfo.currentItemCount then
    return true
  end

  -- Item is no longer in the recent items category.
  if oldData and oldData.itemInfo and oldData.itemInfo.category == L:G("Recent Items") and not self:IsNewItem(oldData.slotkey) then
    return true
  end

  return false
end

---@param newData ItemData
---@param oldData ItemData
---@return boolean
function items:ItemHashChanged(newData, oldData)
  if newData.isItemEmpty and not oldData then return false end
  return newData.itemHash ~= oldData.itemHash
end

---@param data ItemData
---@return string
function items:GetSlotKey(data)
  return data.bagid .. '_' .. data.slotid
end

---@param bagid number
---@param slotid number
---@return string
function items:GetSlotKeyFromBagAndSlot(bagid, slotid)
  return bagid .. '_' .. slotid
end

-- UpdateFreeSlots updates the current free slot count for a given bag kind.
---@param kind BagKind
function items:UpdateFreeSlots(kind)
  local baglist = kind == const.BAG_KIND.BANK and const.BANK_BAGS or const.BACKPACK_BAGS
  for bagid in pairs(baglist) do
    local freeSlots = C_Container.GetContainerNumFreeSlots(bagid)
    local name = ""
    local invid = C_Container.ContainerIDToInventoryID(bagid)
    local baglink = GetInventoryItemLink("player", invid)
    if baglink ~= nil and invid ~= nil then
      local class, subclass = select(6, C_Item.GetItemInfoInstant(baglink)) --[[@as number]]
      name = GetItemSubClassInfo(class, subclass)
    else
      name = GetItemSubClassInfo(Enum.ItemClass.Container, 0)
    end
    if bagid == Enum.BagIndex.Bank or bagid == Enum.BagIndex.Reagentbank then
      -- BugFix(https://github.com/Stanzilla/WoWUIBugs/issues/538):
      -- There are 4 extra slots in the bank bag in Classic that should not
      -- exist. This is a Blizzard bug.
      if addon.isClassic then
        freeSlots = freeSlots - 4
      end
    end

    if bagid ~= Enum.BagIndex.Keyring then
      self.slotInfo[kind].emptySlots[name] = self.slotInfo[kind].emptySlots[name] or 0
      self.slotInfo[kind].emptySlots[name] = self.slotInfo[kind].emptySlots[name] + freeSlots
    end
  end
end

--- LoadItems will load all items in a given bag kind and update the item database.
---@private
---@param kind BagKind
---@param dataCache table<string, ItemData>
function items:LoadItems(kind, dataCache)
  -- Push the new slot info into the slot info table, and the old slot info
  -- to the previous slot info table.
  debug:Inspect("LoadItems: "..kind, dataCache)
  self.slotInfo[kind]:Update(dataCache)
  self:UpdateFreeSlots(kind)
  local slotInfo = self.slotInfo[kind]

  -- Loop through all the items in the bag and update slot info properties.
  for _, currentItem in pairs(slotInfo:GetCurrentItems()) do
    local bagid = currentItem.bagid
    local slotid = currentItem.slotid
    local name = ""
    local previousItem = slotInfo:GetPreviousItemByBagAndSlot(bagid, slotid)
    local invid = C_Container.ContainerIDToInventoryID(bagid)
    local baglink = GetInventoryItemLink("player", invid)

    if baglink ~= nil and invid ~= nil then
      local class, subclass = select(6, C_Item.GetItemInfoInstant(baglink)) --[[@as number]]
      name = GetItemSubClassInfo(class, subclass)
    else
      name = GetItemSubClassInfo(Enum.ItemClass.Container, 0)
    end

    -- Process item changes.
    if items:ItemAdded(currentItem, previousItem) then
      debug:Log("ItemAdded", currentItem.itemInfo.itemLink)
     slotInfo.addedItems[currentItem.slotkey] = currentItem
    elseif items:ItemRemoved(currentItem, previousItem) then
      debug:Log("ItemRemoved", previousItem.itemInfo.itemLink)
      slotInfo.removedItems[previousItem.slotkey] = previousItem
    elseif items:ItemHashChanged(currentItem, previousItem) then
      debug:Log("ItemHashChanged", currentItem.itemInfo.itemLink)
      slotInfo.removedItems[previousItem.slotkey] = previousItem
      slotInfo.addedItems[currentItem.slotkey] = currentItem
    elseif items:ItemChanged(currentItem, previousItem) then
      debug:Log("ItemChanged", currentItem.itemInfo.itemLink)
      slotInfo.updatedItems[currentItem.slotkey] = currentItem
    end


    -- Store empty slot data
    if currentItem.isItemEmpty then
      slotInfo.freeSlotKeys[name] = bagid .. '_' .. slotid
      slotInfo.emptySlotByBagAndSlot[bagid] = slotInfo.emptySlotByBagAndSlot[bagid] or {}
      slotInfo.emptySlotByBagAndSlot[bagid][slotid] = currentItem
    end

    -- Increment the total items count.
    if not currentItem.isItemEmpty then
      slotInfo.totalItems = slotInfo.totalItems + 1
    end
  end

  -- Set the defer delete flag if the total items count has decreased.
  if slotInfo.totalItems < slotInfo.previousTotalItems then
    slotInfo.deferDelete = true
  end
end

-- ProcessContainer will load all items in the container and fire
-- a message when all items are done loading.
---@private
---@param kind BagKind
---@param container ItemLoader
function items:ProcessContainer(kind, container)
  container:Load(function()
    self:LoadItems(kind, container:GetDataCache())
    local ev = kind == const.BAG_KIND.BANK and 'items/RefreshBank/Done' or 'items/RefreshBackpack/Done'

    events:SendMessageLater(ev, nil, self.slotInfo[kind])
    if kind == const.BAG_KIND.BACKPACK then
      debug:EndProfile('Backpack Data Pipeline')
    end
  end)
end

-- StageBagForUpdate will scan a bag for items and add them
-- to the provided container for data fetching.
---@private
---@param bagid number
---@param container ItemLoader
function items:StageBagForUpdate(bagid, container)
  local size = C_Container.GetContainerNumSlots(bagid)
  -- Loop through every container slot and create an item for it.
  for slotid = 1, size do
    local itemMixin = Item:CreateFromBagAndSlot(bagid, slotid)
    container:Add(itemMixin)
  end
end

---@param itemList number[]
---@param callback function<ItemData[]>
function items:GetItemData(itemList, callback)
  local container = ContinuableContainer:Create()
  for _, itemID in pairs(itemList) do
    local itemMixin = Item:CreateFromItemID(itemID)
    container:AddContinuable(itemMixin)
  end
  container:ContinueOnLoad(function()
    ---@type ItemData[]
    local dataList = {}
    for _, itemID in pairs(itemList) do
      local data = setmetatable({}, {__index = itemDataProto}) ---@type ItemData
      self:AttachBasicItemInfo(itemID, data)
      table.insert(dataList, data)
    end
    callback(dataList)
  end)
end

---@param slotkey string
---@return boolean
function items:IsNewItem(slotkey)
  if not slotkey then return false end
  local data = self:GetItemDataFromSlotKey(slotkey)
  if not data or data.isItemEmpty then return false end
  if (self._newItemTimers[data.itemInfo.itemGUID] ~= nil and time() - self._newItemTimers[data.itemInfo.itemGUID] < database:GetNewItemTime()) or
    C_NewItems.IsNewItem(data.bagid, data.slotid) then
    return true
  end
  self._newItemTimers[data.itemInfo.itemGUID] = nil
  return false
end

---@param slotkey string
function items:ClearNewItem(slotkey)
  if not slotkey then return end
  local data = self:GetItemDataFromSlotKey(slotkey)
  if data.isItemEmpty then return end
  C_NewItems.RemoveNewItem(data.bagid, data.slotid)
  self._newItemTimers[data.itemInfo.itemGUID] = nil
end

function items:ClearNewItems()
  C_NewItems.ClearAll()
  wipe(self._newItemTimers)
end

---@param link string
---@return ItemLinkInfo
function items:ParseItemLink(link)
	-- Parse the first elements that have no variable length
	local _, itemID, enchantID, gemID1, gemID2, gemID3, gemID4,
	suffixID, uniqueID, linkLevel, specializationID, modifiersMask,
	itemContext, rest = strsplit(":", link, 14) --[[@as string]]

  ---@type string, string
	local crafterGUID, extraEnchantID
  ---@type string, string[]
	local numBonusIDs, bonusIDs
  ---@type string, string[]
  local numModifiers, modifierIDs
  ---@type string, string[]
	local relic1NumBonusIDs, relic1BonusIDs
  ---@type string, string[]
	local relic2NumBonusIDs, relic2BonusIDs
  ---@type string, string[]
	local relic3NumBonusIDs, relic3BonusIDs

  if rest ~= nil then
	  numBonusIDs, rest = strsplit(":", rest, 2) --[[@as string]]

	  if numBonusIDs ~= "" then
	  	local splits = (tonumber(numBonusIDs))+1
	  	bonusIDs = strsplittable(":", rest, splits)
	  	rest = table.remove(bonusIDs, splits)
	  end

	  numModifiers, rest = strsplit(":", rest, 2) --[[@as string]]
	  if numModifiers ~= "" then
	  	local splits = (tonumber(numModifiers)*2)+1
	  	modifierIDs = strsplittable(":", rest, splits)
	  	rest = table.remove(modifierIDs, splits)
	  end

	  relic1NumBonusIDs, rest = strsplit(":", rest, 2) --[[@as string]]
	  if relic1NumBonusIDs ~= "" then
	  	local splits = (tonumber(relic1NumBonusIDs))+1
	  	relic1BonusIDs = strsplittable(":", rest, splits)
	  	rest = table.remove(relic1BonusIDs, splits)
	  end

	  relic2NumBonusIDs, rest = strsplit(":", rest, 2) --[[@as string]]
	  if relic2NumBonusIDs ~= "" then
	  	local splits = (tonumber(relic2NumBonusIDs))+1
	  	relic2BonusIDs = strsplittable(":", rest, (tonumber(relic2NumBonusIDs))+1)
	  	rest = table.remove(relic2BonusIDs, splits)
	  end

	  relic3NumBonusIDs, rest = strsplit(":", rest, 2) --[[@as string]]
	  if relic3NumBonusIDs ~= "" then
	  	local splits = (tonumber(relic3NumBonusIDs))+1
	  	relic3BonusIDs = strsplittable(":", rest, (tonumber(relic3NumBonusIDs))+1)
	  	rest = table.remove(relic3BonusIDs, splits)
	  end

    ---@type string, string
	  crafterGUID, extraEnchantID = strsplit(":", rest, 3)
  end

	return {
		itemID = tonumber(itemID),
		enchantID = enchantID,
		gemID1 = gemID1,
		gemID2 = gemID2,
		gemID3 = gemID3,
		gemID4 = gemID4,
		suffixID = suffixID,
		uniqueID = uniqueID,
		linkLevel = linkLevel,
		specializationID = specializationID,
		modifiersMask = modifiersMask,
		itemContext = itemContext,
		bonusIDs = bonusIDs or {},
		modifierIDs = modifierIDs or {},
		relic1BonusIDs = relic1BonusIDs or {},
		relic2BonusIDs = relic2BonusIDs or {},
		relic3BonusIDs = relic3BonusIDs or {},
		crafterGUID = crafterGUID or "",
		extraEnchantID = extraEnchantID or ""
	}
end

---@param data ItemData
---@return string
function items:GenerateItemHash(data)
  local hash = format("%d%s%s%s%s%s%s%s%s%s%s%s%s%d",
    data.itemLinkInfo.itemID,
    data.itemLinkInfo.enchantID,
    data.itemLinkInfo.gemID1,
    data.itemLinkInfo.gemID2,
    data.itemLinkInfo.gemID3,
    data.itemLinkInfo.suffixID,
    table.concat(data.itemLinkInfo.bonusIDs, ","),
    table.concat(data.itemLinkInfo.modifierIDs, ","),
    table.concat(data.itemLinkInfo.relic1BonusIDs, ","),
    table.concat(data.itemLinkInfo.relic2BonusIDs, ","),
    table.concat(data.itemLinkInfo.relic3BonusIDs, ","),
    data.itemLinkInfo.crafterGUID or "",
    data.itemLinkInfo.extraEnchantID or "",
    data.itemInfo.currentItemLevel
  )
  return hash
end

---@param data ItemData
---@return string
function items:GetCategory(data)
  if data.isItemEmpty then return L:G('Empty Slot') end

  if database:GetCategoryFilter(data.kind, "RecentItems") then
    if items:IsNewItem(data.slotkey) then
      return L:G("Recent Items")
    end
  end

  -- Check for equipment sets first, as it doesn't make sense to put them anywhere else.
  if data.itemInfo.equipmentSet and database:GetCategoryFilter(data.kind, "GearSet") then
    return "Gear: " .. data.itemInfo.equipmentSet
  end

  -- Return the custom category if it exists next.
  local customCategory = categories:GetCustomCategory(data.kind, data)
  if customCategory then
    return customCategory
  end

  if not data.kind then return L:G('Everything') end

  if data.containerInfo.quality == Enum.ItemQuality.Poor then
    return L:G('Junk')
  end

  -- Item Equipment location takes precedence filters below and does not bisect.
  if database:GetCategoryFilter(data.kind, "EquipmentLocation") and
  data.itemInfo.itemEquipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" and
  _G[data.itemInfo.itemEquipLoc] ~= nil and
  _G[data.itemInfo.itemEquipLoc] ~= "" then
    return _G[data.itemInfo.itemEquipLoc]
  end

  local category = ""

  -- Add the type filter to the category if enabled, but not to trade goods
  -- when the tradeskill filter is enabled. This makes it so trade goods are
  -- labeled as "Tailoring" and not "Tradeskill - Tailoring", which is redundent.
  if database:GetCategoryFilter(data.kind, "Type") and not
  (data.itemInfo.classID == Enum.ItemClass.Tradegoods and database:GetCategoryFilter(data.kind, "TradeSkill")) and
  data.itemInfo.itemType then
    category = category .. data.itemInfo.itemType --[[@as string]]
  end

  -- Add the subtype filter to the category if enabled, but same as with
  -- the type filter we don't add it to trade goods when the tradeskill
  -- filter is enabled.
  if database:GetCategoryFilter(data.kind, "Subtype") and not
  (data.itemInfo.classID == Enum.ItemClass.Tradegoods and database:GetCategoryFilter(data.kind, "TradeSkill")) and
  data.itemInfo.itemSubType then
    if category ~= "" then
      category = category .. " - "
    end
    category = category .. data.itemInfo.itemSubType
  end

  -- Add the tradeskill filter to the category if enabled.
  if data.itemInfo.classID == Enum.ItemClass.Tradegoods and database:GetCategoryFilter(data.kind, "TradeSkill") then
    if category ~= "" then
      category = category .. " - "
    end
    category = category .. const.TRADESKILL_MAP[data.itemInfo.subclassID]
  end

  -- Add the expansion filter to the category if enabled.
  if database:GetCategoryFilter(data.kind, "Expansion") then
    if not data.itemInfo.expacID then return L:G('Unknown') end
    if category ~= "" then
      category = category .. " - "
    end
    category = category .. const.EXPANSION_MAP[data.itemInfo.expacID] --[[@as string]]
  end

  if category == "" then
    category = L:G('Everything')
  end

  return category
end

---@param data ItemData
---@param kind BagKind
---@return ItemData
function items:AttachItemInfo(data, kind)
  local itemMixin = Item:CreateFromBagAndSlot(data.bagid, data.slotid) --[[@as ItemMixin]]
  local itemLocation = itemMixin:GetItemLocation() --[[@as ItemLocationMixin]]
  local bagid, slotid = data.bagid, data.slotid
  local slotkey = self:GetSlotKeyFromBagAndSlot(bagid, slotid)
  local itemID = C_Container.GetContainerItemID(bagid, slotid)
  local itemLink = C_Container.GetContainerItemLink(bagid, slotid)
  data.kind = kind
  data.basic = false
  data.slotkey = slotkey
  if itemID == nil then
    data.isItemEmpty = true
    data.itemInfo = {} --[[@as table]]
    return data
  end
  data.isItemEmpty = false
  local _, _, _,
  itemLevel, itemMinLevel, itemType, itemSubType,
  itemStackCount, itemEquipLoc, itemTexture,
  sellPrice, classID, subclassID, bindType, expacID,
  setID, isCraftingReagent = GetItemInfo(itemID)
  local itemQuality = C_Item.GetItemQuality(itemLocation) --[[@as Enum.ItemQuality]]
  local effectiveIlvl, isPreview, baseIlvl = GetDetailedItemLevelInfo(itemID)
  data.containerInfo = C_Container.GetContainerItemInfo(bagid, slotid)
  data.questInfo = C_Container.GetContainerItemQuestInfo(bagid, slotid)
  data.itemInfo = {
    itemID = itemID,
    itemGUID = C_Item.GetItemGUID(itemLocation),
    itemName = data.containerInfo.itemName,
    itemLink = itemLink,
    itemQuality = itemQuality,
    itemLevel = itemLevel,
    itemMinLevel = itemMinLevel,
    itemType = itemType,
    itemSubType = itemSubType,
    itemStackCount = itemStackCount,
    itemEquipLoc = itemEquipLoc,
    itemTexture = itemTexture,
    sellPrice = sellPrice,
    classID = classID,
    subclassID = subclassID,
    bindType = bindType,
    expacID = expacID,
    setID = setID or 0,
    isCraftingReagent = isCraftingReagent,
    effectiveIlvl = effectiveIlvl --[[@as number]],
    isPreview = isPreview --[[@as boolean]],
    baseIlvl = baseIlvl --[[@as number]],
    itemIcon = data.containerInfo.iconFileID,
    isBound = C_Item.IsBound(itemLocation),
    isLocked = false,
    isNewItem = C_NewItems.IsNewItem(bagid, slotid),
    currentItemCount = C_Item.GetStackCount(itemLocation),
    category = "",
    currentItemLevel = C_Item.GetCurrentItemLevel(itemLocation) --[[@as number]],
    equipmentSet = equipmentSets:GetItemSet(bagid, slotid),
  }

  --if database:GetItemLock(data.itemInfo.itemGUID) then
  --  data.itemInfo.isLocked = true
  --end

  if data.itemInfo.isNewItem and self._newItemTimers[data.itemInfo.itemGUID] == nil then
    self._newItemTimers[data.itemInfo.itemGUID] = time()
  end

  data.itemLinkInfo = self:ParseItemLink(itemLink)
  data.itemHash = self:GenerateItemHash(data)
  data.itemInfo.category = self:GetCategory(data)
  data.forceClear = false
  data.stacks = 0
  data.stackedCount = data.itemInfo.currentItemCount
  return data
end

---@param itemID number
---@param data ItemData
function items:AttachBasicItemInfo(itemID, data)
  local effectiveIlvl, isPreview, baseIlvl = GetDetailedItemLevelInfo(itemID)
  local itemName, itemLink, itemQuality,
  itemLevel, itemMinLevel, itemType, itemSubType,
  itemStackCount, itemEquipLoc, itemTexture,
  sellPrice, classID, subclassID, bindType, expacID,
  setID, isCraftingReagent = GetItemInfo(itemID)
  data.questInfo = {
    isActive = false,
    isQuestItem = false,
  }
  data.basic = true
  data.itemInfo = {
    itemID = itemID,
    itemGUID = "",
    itemName = itemName,
    itemLink = itemLink,
    itemQuality = itemQuality,
    itemLevel = itemLevel,
    itemMinLevel = itemMinLevel,
    itemType = itemType,
    itemSubType = itemSubType,
    itemStackCount = itemStackCount,
    itemEquipLoc = itemEquipLoc,
    itemTexture = itemTexture,
    sellPrice = sellPrice,
    classID = classID,
    subclassID = subclassID,
    bindType = bindType,
    expacID = expacID,
    setID = setID or 0,
    isCraftingReagent = isCraftingReagent,
    effectiveIlvl = effectiveIlvl --[[@as number]],
    isPreview = isPreview --[[@as boolean]],
    baseIlvl = baseIlvl --[[@as number]],
    itemIcon = C_Item.GetItemIconByID(itemID),
    isBound = false,
    isLocked = false,
    isNewItem = false,
    currentItemCount = 1,
    category = "",
    currentItemLevel = 0 --[[@as number]],
    equipmentSet = nil,
  }
  data.forceClear = false
end

---@param slotkey string
---@return BagKind
function items:GetBagKindFromSlotKey(slotkey)
  local bagid = string.split('_', slotkey) --[[@as string]]
  if const.BANK_BAGS[tonumber(bagid)] or const.REAGENTBANK_BAGS[tonumber(bagid)] then
    return const.BAG_KIND.BANK
  end
  return const.BAG_KIND.BACKPACK
end

---@param slotkey string
---@return ItemData
function items:GetItemDataFromSlotKey(slotkey)
  return self.slotInfo[self:GetBagKindFromSlotKey(slotkey)].itemsBySlotKey[slotkey]
end
