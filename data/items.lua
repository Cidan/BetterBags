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

-- ExtraSlotInfo contains refresh data for an entire bag view, bag or bank.
---@class (exact) ExtraSlotInfo
---@field emptySlots number The number of empty normal slots across all bags.
---@field emptyReagentSlots number The number of empty reagent slots across all bags.
---@field totalItems number The total number of valid items across all bags.
---@field freeSlotKey string The key of the first empty normal slot.
---@field freeReagentSlotKey string The key of the first empty reagent slot.
---@field emptySlotByBagAndSlot table<number, table<number, ItemData>> A table of empty slots by bag and slot.
---@field deferDelete? boolean If true, delete's should be deferred until the next refresh.
---@field dirtyItems ItemData[] A list of dirty items that need to be refreshed.

-- ItemData contains all the information about an item in a bag or bank.
---@class (exact) ItemData
---@field basic boolean
---@field itemInfo ExpandedItemInfo
---@field containerInfo ContainerItemInfo
---@field questInfo ItemQuestInfo
---@field bagid number
---@field slotid number
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
local itemDataProto = {}

---@class (exact) Items: AceModule
---@field itemsByBagAndSlot table<number, table<number, ItemData>>
---@field bankItemsByBagAndSlot table<number, table<number, ItemData>>
---@field slotInfo ExtraSlotInfo
---@field bankSlotInfo ExtraSlotInfo
---@field previousItemGUID table<number, table<number, string>>
---@field _container ContinuableContainer
---@field _bankContainer ContinuableContainer
---@field _doingRefreshAll boolean
---@field _newItemTimers table<string, number>
---@field _firstLoad boolean
---@field _bankFirstLoad boolean
local items = addon:NewModule('Items')

function items:OnInitialize()
  self.itemsByBagAndSlot = {}
  self.bankItemsByBagAndSlot = {}
  self.previousItemGUID = {}
  self.slotInfo = {
    emptySlots = 0,
    emptyReagentSlots = 0,
    totalItems = 0,
    freeSlotKey = "",
    freeReagentSlotKey = "",
    emptySlotByBagAndSlot = {},
    dirtyItems = {},
  }
  self.bankSlotInfo = {
    emptySlots = 0,
    emptyReagentSlots = 0,
    totalItems = 0,
    freeSlotKey = "",
    freeReagentSlotKey = "",
    emptySlotByBagAndSlot = {},
    dirtyItems = {},
  }
  self._newItemTimers = {}
  self._firstLoad = false
  self._bankFirstLoad = false
end

function items:OnEnable()

  events:RegisterEvent('EQUIPMENT_SETS_CHANGED', function()
    self:DoRefreshAll()
  end)
  local eventList = {
    'BAG_UPDATE_DELAYED',
    'PLAYERBANKSLOTS_CHANGED',
  }

  if addon.isRetail then
    table.insert(eventList, 'PLAYERREAGENTBANKSLOTS_CHANGED')
  end

  events:RegisterMessage('bags/FullRefreshAll', function()
    if InCombatLockdown() then
      addon.Bags.Backpack.drawAfterCombat = true
    else
      self:FullRefreshAll()
    end
  end)

  events:GroupBucketEvent(eventList, {'bags/RefreshAll', 'bags/RefreshBackpack', 'bags/RefreshBank'}, function()
    self:DoRefreshAll()
  end)

  events:RegisterEvent('BANKFRAME_OPENED', function()
    if GameMenuFrame:IsShown() then
      return
    end
    addon.atBank = true
    self:RefreshBank()
  end)
  events:RegisterEvent('BANKFRAME_CLOSED', function()
    addon.atBank = false
  end)
end

function items:Disable()
  --events:UnregisterEvent('BAG_UPDATE')
end

function items:RemoveNewItemFromAllItems()
  for _, bagid in pairs(self.itemsByBagAndSlot) do
    for _, item in pairs(bagid) do
      if C_NewItems.IsNewItem(item.bagid, item.slotid) then
        C_NewItems.RemoveNewItem(item.bagid, item.slotid)
      end
    end
  end
  wipe(self._newItemTimers)
end

function items:RefreshAll()
  events:SendMessage('bags/RefreshAll')
end

---@private
-- FullRefreshAll will wipe the item cache and refresh all items in all bags.
function items:FullRefreshAll()
  debug:Log('FullRefreshAll', "Full Refresh All triggered")
  self.itemsByBagAndSlot = {}
  self.bankItemsByBagAndSlot = {}
  self.previousItemGUID = {}
  self.slotInfo = {
    emptySlots = 0,
    emptyReagentSlots = 0,
    totalItems = 0,
    freeSlotKey = "",
    freeReagentSlotKey = "",
    emptySlotByBagAndSlot = {},
    dirtyItems = {},
  }
  self.bankSlotInfo = {
    emptySlots = 0,
    emptyReagentSlots = 0,
    totalItems = 0,
    freeSlotKey = "",
    freeReagentSlotKey = "",
    emptySlotByBagAndSlot = {},
    dirtyItems = {},
  }
  events:SendMessage('bags/RefreshAll')
end

---@private
function items:DoRefreshAll()
  if not addon.Bags.Bank or not addon.Bags.Backpack then return end
  if addon.Bags.Bank.frame:IsShown() then
    if addon.Bags.Bank.isReagentBank then
      self:RefreshReagentBank()
    else
      self:RefreshBank()
    end
  end
  self:RefreshBackpack()
end

function items:RefreshReagentBank()
  self._bankContainer = ContinuableContainer:Create()
  self.bankItemsByBagAndSlot = {}
  -- Loop through all the bags and schedule each item for a refresh.
  for i in pairs(const.REAGENTBANK_BAGS) do
    self.bankItemsByBagAndSlot[i] = {}
    self.previousItemGUID[i] = self.previousItemGUID[i] or {}
    self:RefreshBag(i, true)
  end

  --- Process the item container.
  self:ProcessBankContainer()
end

function items:RefreshBank()
  equipmentSets:Update()
  self._bankContainer = ContinuableContainer:Create()
  self.bankItemsByBagAndSlot = {}
  -- This is a small hack to force the bank bag quality data to be cached
  -- before the bank bag frame is drawn.
  for _, bag in pairs(const.BANK_ONLY_BAGS) do
    local id = C_Container.ContainerIDToInventoryID(bag)
    GetInventoryItemQuality("player", id)
  end

  -- Loop through all the bags and schedule each item for a refresh.
  for i in pairs(const.BANK_BAGS) do
    self.bankItemsByBagAndSlot[i] = {}
    self.previousItemGUID[i] = self.previousItemGUID[i] or {}
    self:RefreshBag(i, true)
  end

  --- Process the item container.
  self:ProcessBankContainer()

  -- Show the bank frame if it's not already shown.
  if not addon.Bags.Bank:IsShown() and addon.atBank then
    addon.Bags.Bank:Show()
  end
end

-- RefreshBackback will refresh all bags' contents entirely and update
-- the item database.
function items:RefreshBackpack()
  if self._doingRefreshAll then
    return
  end

  debug:StartProfile('Backpack Data Pipeline')

  equipmentSets:Update()
  self._doingRefreshAll = true
  self._container = ContinuableContainer:Create()

  -- Loop through all the bags and schedule each item for a refresh.
  for i in pairs(const.BACKPACK_BAGS) do
    self.itemsByBagAndSlot[i] = self.itemsByBagAndSlot[i] or {}
    self.previousItemGUID[i] = self.previousItemGUID[i] or {}
    self:RefreshBag(i, false)
  end
  --- Process the item container.
  self:ProcessContainer()
end

---@param bagid number
---@param slotid number
---@param data ItemData
---@return boolean
function items:HasItemChanged(bagid, slotid, data)
  local itemMixin = Item:CreateFromBagAndSlot(bagid, slotid)
  local itemLocation = itemMixin:GetItemLocation()
  local itemLink = C_Container.GetContainerItemLink(bagid, slotid)

  local oldItemLink = data.itemInfo and data.itemInfo.itemLink or nil
  local oldStackCount = data.itemInfo and data.itemInfo.currentItemCount or 1
  if itemLink ~= oldItemLink then
    debug:Log("ItemChange", oldItemLink, "->", itemLink)
    return true
  end

  if itemLocation and C_Item.DoesItemExist(itemLocation) and oldStackCount ~= C_Item.GetStackCount(itemLocation) then
    debug:Log("ItemChange", itemLink, "count", oldStackCount, "->", C_Item.GetStackCount(itemLocation))
    return true
  end

  if data.itemInfo and data.itemInfo.category == L:G("Recent Items") and not self:IsNewItem(data) then
    debug:Log("ItemChange", itemLink, "Not Recent Item")
    return true
  end

  return false
end

---@param kind BagKind
---@param data ItemData
---@return boolean
function items:ShouldItemStack(kind, data)
  if data.isItemEmpty then return false end
  local stackOptions = database:GetStackingOptions(kind)
  if stackOptions.unmergeAtShop and addon.atInteracting and kind ~= const.BAG_KIND.BANK then
    return false
  end

  if database:GetBagView(kind) == const.BAG_VIEW.SECTION_ALL_BAGS then
    return false
  end

  if stackOptions.mergeStacks and data.itemInfo.itemStackCount and data.itemInfo.itemStackCount > 1 then
    return true
  end
  if stackOptions.mergeUnstackable and data.itemInfo.itemStackCount == 1 then
    return true
  end
  return false
end

---@param data ItemData
---@return string
function items:GetSlotKey(data)
  return data.bagid .. '_' .. data.slotid
end


---@private
function items:BackpackLoadFunction()
  ---@type ExtraSlotInfo
  local extraSlotInfo = {
    emptySlots = 0,
    emptyReagentSlots = 0,
    totalItems = 0,
    freeSlotKey = "",
    freeReagentSlotKey = "",
    emptySlotByBagAndSlot = {},
    dirtyItems = {},
  }

  ---@type table<string, ItemData>
  local stacks = {}

  ---@type table<string, ItemData>
  local dirty = {}

  for bagid, bag in pairs(items.itemsByBagAndSlot) do
    extraSlotInfo.emptySlotByBagAndSlot[bagid] = extraSlotInfo.emptySlotByBagAndSlot[bagid] or {}
    for slotid, data in pairs(bag) do
      -- Check if the item as changed, and if so, add it to the dirty list.
      if items:HasItemChanged(bagid, slotid, data) then
        local wasStacked = data.stacks and data.stacks > 0
        wipe(data)
        data.bagid = bagid
        data.slotid = slotid
        items:AttachItemInfo(data, const.BAG_KIND.BACKPACK)
        if wasStacked then
          debug:Log("Stacks", "Was Stacked", data.itemInfo.itemLink)
          data.forceClear = true
        end
        table.insert(extraSlotInfo.dirtyItems, data)
        dirty[self:GetSlotKey(data)] = data
      end

      -- Compute stacking data.
      if items:ShouldItemStack(const.BAG_KIND.BACKPACK, data) then
        local stackItem = stacks[data.itemHash]
        if stackItem ~= nil then
          stackItem.stacks = stackItem.stacks + 1
          data.stackedOn = items:GetSlotKey(stackItem)
          data.stackedCount = data.itemInfo.currentItemCount
          data.stacks = 0
          stackItem.stackedCount = stackItem.stackedCount + data.itemInfo.currentItemCount
          stackItem.stacks = stackItem.stacks + 1
          if not self:IsNewItem(stackItem) or not self:IsNewItem(data) then
            self:ClearNewItem(data)
            self:ClearNewItem(stackItem)
            data.itemInfo.category = self:GetCategory(data)
            stackItem.itemInfo.category = self:GetCategory(stackItem)
          end
          --TODO(lobato): I don't know why dirty as a set doesn't just work here when
          -- passing it into the event, and I'm too tired to figure it out right now.
          local key = items:GetSlotKey(data)
          if dirty[key] == nil then
            table.insert(extraSlotInfo.dirtyItems, data)
            dirty[key] = data
          end

          key = items:GetSlotKey(stackItem)
          if dirty[key] == nil then
            table.insert(extraSlotInfo.dirtyItems, stackItem)
            dirty[key] = stackItem
          end
        else
          local key = items:GetSlotKey(data)
          if data.stackedOn ~= nil and dirty[key] == nil then
            table.insert(extraSlotInfo.dirtyItems, data)
            dirty[key] = data
          end
          data.stacks = 0
          data.stackedOn = nil
          data.stackedCount = data.itemInfo.currentItemCount
          stacks[data.itemHash] = data
        end
      elseif data.stackedOn ~= nil or (data.stacks ~= nil and data.stacks > 0) then
        data.stackedOn = nil
        data.stacks = 0
        data.stackedCount = data.itemInfo.currentItemCount
        local key = items:GetSlotKey(data)
        if dirty[key] == nil then
          table.insert(extraSlotInfo.dirtyItems, data)
          dirty[key] = data
        end
      end

      if data.isItemEmpty then
        data.stacks = 0
        data.stackedOn = nil
        data.stackedCount = nil
        if const.BACKPACK_ONLY_REAGENT_BAGS[bagid] then
          extraSlotInfo.emptyReagentSlots = (extraSlotInfo.emptyReagentSlots or 0) + 1
          extraSlotInfo.freeReagentSlotKey = bagid .. '_' .. slotid
        elseif bagid ~= Enum.BagIndex.Keyring then
          extraSlotInfo.emptySlots = (extraSlotInfo.emptySlots or 0) + 1
          extraSlotInfo.freeSlotKey = bagid .. '_' .. slotid
        end
        extraSlotInfo.emptySlotByBagAndSlot[bagid][slotid] = data
      else
        extraSlotInfo.totalItems = (extraSlotInfo.totalItems or 0) + 1
      end
    end
  end

  if extraSlotInfo.totalItems < self.slotInfo.totalItems then
    extraSlotInfo.deferDelete = true
  end

  self.slotInfo = CopyTable(extraSlotInfo)
  -- All items in all bags have finished loading, fire the all done event.
  debug:EndProfile('Backpack Data Pipeline')
  events:SendMessageLater('items/RefreshBackpack/Done', function()
    items._container = nil
    items._doingRefreshAll = false
  end,
  extraSlotInfo)
end

  -- Load item data in the background, and fire a message when
  -- all bags are done loading.
function items:ProcessContainer()
  self._container:ContinueOnLoad(function() self:BackpackLoadFunction() end)
end

function items:BankLoadFunction()
  ---@type ExtraSlotInfo
  local extraSlotInfo = {
    emptySlots = 0,
    emptyReagentSlots = 0,
    totalItems = 0,
    freeSlotKey = "",
    freeReagentSlotKey = "",
    emptySlotByBagAndSlot = {},
    dirtyItems = {},
  }

  ---@type table<string, ItemData>
  local stacks = {}
  for bagid, bag in pairs(items.bankItemsByBagAndSlot) do
    extraSlotInfo.emptySlotByBagAndSlot[bagid] = extraSlotInfo.emptySlotByBagAndSlot[bagid] or {}
    for slotid, data in pairs(bag) do
      items:AttachItemInfo(data, const.BAG_KIND.BANK)
      data.stackedCount = 0
      data.stackedOn = nil
      data.stacks = 0
      table.insert(extraSlotInfo.dirtyItems, data)
      -- Compute stacking data.
      if items:ShouldItemStack(const.BAG_KIND.BANK, data) then
        local stackItem = stacks[data.itemHash]
        if stackItem ~= nil then
          stackItem.stacks = stackItem.stacks + 1
          data.stackedOn = items:GetSlotKey(stackItem)
          data.stackedCount = data.itemInfo.currentItemCount
          data.stacks = 0
          stackItem.stackedCount = stackItem.stackedCount + data.itemInfo.currentItemCount
          stackItem.stacks = stackItem.stacks + 1
          if not self:IsNewItem(stackItem) or not self:IsNewItem(data) then
            self:ClearNewItem(data)
            self:ClearNewItem(stackItem)
            data.itemInfo.category = self:GetCategory(data)
            stackItem.itemInfo.category = self:GetCategory(stackItem)
          end
        else
          data.stacks = 0
          data.stackedOn = nil
          data.stackedCount = data.itemInfo.currentItemCount
          stacks[data.itemHash] = data
        end
      else
        data.stackedOn = nil
        data.stacks = 0
        data.stackedCount = data.itemInfo.currentItemCount
      end

      if data.isItemEmpty then
        data.stacks = 0
        data.stackedOn = nil
        data.stackedCount = nil
        if const.BACKPACK_ONLY_REAGENT_BAGS[bagid] then
          extraSlotInfo.emptyReagentSlots = (extraSlotInfo.emptyReagentSlots or 0) + 1
          extraSlotInfo.freeReagentSlotKey = bagid .. '_' .. slotid
        else
          extraSlotInfo.emptySlots = (extraSlotInfo.emptySlots or 0) + 1
          extraSlotInfo.freeSlotKey = bagid .. '_' .. slotid
        end
        extraSlotInfo.emptySlotByBagAndSlot[bagid][slotid] = data
      else
        extraSlotInfo.totalItems = (extraSlotInfo.totalItems or 0) + 1
      end
    end
  end
  self.bankSlotInfo = CopyTable(extraSlotInfo)
  -- All items in all bags have finished loading, fire the all done event.
  events:SendMessage('items/RefreshBank/Done', extraSlotInfo)
  items._bankContainer = nil
  items._doingRefreshAll = false
end

-- Load item data in the background, and fire a message when
-- all bags are done loading.
function items:ProcessBankContainer()
  self._bankContainer:ContinueOnLoad(function() self:BankLoadFunction() end)
end

--TODO(lobato): Completely eliminate the use of ItemMixin.
-- RefreshBag will refresh a bag's contents entirely and update the
-- item database.
---@private
---@param bagid number
---@param bankBag boolean
function items:RefreshBag(bagid, bankBag)
  local size = C_Container.GetContainerNumSlots(bagid)
  local index = bankBag and self.bankItemsByBagAndSlot or self.itemsByBagAndSlot
  --local dirty = bankBag and self.dirtyBankItems or self.dirtyItems
  -- Loop through every container slot and create an item for it.
  for slotid = 1, size do
    local itemMixin = Item:CreateFromBagAndSlot(bagid, slotid)
    local data = setmetatable({}, {__index = itemDataProto})
    data.bagid = bagid
    data.slotid = slotid
    data.stacks = 0

    --table.insert(dirty, data)

    -- If this is an actual item, add it to the callback container
    -- so data is fetched from the server.
    if not itemMixin:IsItemEmpty() and not itemMixin:IsItemDataCached() then
      if bankBag then
        self._bankContainer:AddContinuable(itemMixin)
      else
        self._container:AddContinuable(itemMixin)
      end
    elseif itemMixin:IsItemEmpty() then
      data.isItemEmpty = true
    end

    if index[bagid][slotid] then
      index[bagid][slotid].isItemEmpty = data.isItemEmpty
    else
      index[bagid][slotid] = data
    end
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

---@param data ItemData
---@return boolean
function items:IsNewItem(data)
  if not data then return false end
  if data.isItemEmpty then return false end
  if (self._newItemTimers[data.itemInfo.itemGUID] ~= nil and time() - self._newItemTimers[data.itemInfo.itemGUID] < database:GetNewItemTime()) or
    C_NewItems.IsNewItem(data.bagid, data.slotid) then
    return true
  end
  self._newItemTimers[data.itemInfo.itemGUID] = nil
  return false
end

---@param data ItemData
function items:ClearNewItem(data)
  if not data then return end
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
    if items:IsNewItem(data) then
      return L:G("Recent Items")
    end
  end

  -- Check for equipment sets first, as it doesn't make sense to put them anywhere else..
  if data.itemInfo.equipmentSet and database:GetCategoryFilter(data.kind, "GearSet") then
    return "Gear: " .. data.itemInfo.equipmentSet
  end

  -- Return the custom category if it exists next.
  local customCategory = categories:GetCustomCategory(data.kind, data)
  if customCategory then
    return customCategory
  end

  if not data.kind then return L:G('Everything') end
  -- TODO(lobato): Handle cases such as new items here instead of in the layout engine.
  if data.containerInfo.quality == Enum.ItemQuality.Poor then
    return L:G('Junk')
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
function items:AttachItemInfo(data, kind)
  local itemMixin = Item:CreateFromBagAndSlot(data.bagid, data.slotid) --[[@as ItemMixin]]
  local itemLocation = itemMixin:GetItemLocation() --[[@as ItemLocationMixin]]
  local bagid, slotid = data.bagid, data.slotid
  local itemID = C_Container.GetContainerItemID(bagid, slotid)
  local itemLink = C_Container.GetContainerItemLink(bagid, slotid)
  data.kind = kind
  data.basic = false
  if itemID == nil then
    data.isItemEmpty = true
    data.itemInfo = {} --[[@as table]]
    return
  end
  data.isItemEmpty = false
  local itemName, _, itemQuality,
  itemLevel, itemMinLevel, itemType, itemSubType,
  itemStackCount, itemEquipLoc, itemTexture,
  sellPrice, classID, subclassID, bindType, expacID,
  setID, isCraftingReagent = GetItemInfo(itemLink)
  itemQuality = C_Item.GetItemQuality(itemLocation) --[[@as Enum.ItemQuality]]
  local effectiveIlvl, isPreview, baseIlvl = GetDetailedItemLevelInfo(itemID)
  data.containerInfo = C_Container.GetContainerItemInfo(bagid, slotid)
  data.questInfo = C_Container.GetContainerItemQuestInfo(bagid, slotid)
  data.itemInfo = {
    itemID = itemID,
    itemGUID = C_Item.GetItemGUID(itemLocation),
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
    isBound = C_Item.IsBound(itemLocation),
    isLocked = false,
    isNewItem = C_NewItems.IsNewItem(bagid, slotid),
    currentItemCount = C_Item.GetStackCount(itemLocation),
    category = "",
    currentItemLevel = C_Item.GetCurrentItemLevel(itemLocation) --[[@as number]],
    equipmentSet = equipmentSets:GetItemSet(bagid, slotid),
  }

  if database:GetItemLock(data.itemInfo.itemGUID) then
    data.itemInfo.isLocked = true
  end

  if data.itemInfo.isNewItem and self._newItemTimers[data.itemInfo.itemGUID] == nil then
    self._newItemTimers[data.itemInfo.itemGUID] = time()
  end

  data.itemLinkInfo = self:ParseItemLink(itemLink)
  data.itemHash = self:GenerateItemHash(data)
  data.itemInfo.category = self:GetCategory(data)
  data.forceClear = false
  data.stacks = 0
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
