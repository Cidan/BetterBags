local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class EquipmentSets: AceModule
local equipmentSets = addon:GetModule('EquipmentSets')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class (exact) ExtraSlotInfo
---@field emptySlots number The number of empty normal slots across all bags.
---@field emptyReagentSlots number The number of empty reagent slots across all bags.
---@field totalItems number The total number of valid items across all bags.
---@field freeSlotKey string The key of the first empty normal slot.
---@field freeReagentSlotKey string The key of the first empty reagent slot.
---@field emptySlotByBagAndSlot table<number, table<number, ItemData>> A table of empty slots by bag and slot.

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
---@field stacks table<string, string>
---@field stackedOn string
---@field stackedCount number
local itemDataProto = {}

---@class (exact) Items: AceModule
---@field itemsByBagAndSlot table<number, table<number, ItemData>>
---@field bankItemsByBagAndSlot table<number, table<number, ItemData>>
---@field slotInfo ExtraSlotInfo
---@field bankSlotInfo ExtraSlotInfo
---@field dirtyItems ItemData[]
---@field dirtyBankItems ItemData[]
---@field previousItemGUID table<number, table<number, string>>
---@field _container ContinuableContainer
---@field _bankContainer ContinuableContainer
---@field _doingRefreshAll boolean
---@field _newItemTimers table<string, number>
---@field _firstLoad boolean
---@field _bankFirstLoad boolean
local items = addon:NewModule('Items')

function items:OnInitialize()
  self.dirtyItems = {}
  self.dirtyBankItems = {}
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
  }
  self.bankSlotInfo = {
    emptySlots = 0,
    emptyReagentSlots = 0,
    totalItems = 0,
    freeSlotKey = "",
    freeReagentSlotKey = "",
    emptySlotByBagAndSlot = {},
  }
  self._newItemTimers = {}
  self._firstLoad = true
  self._bankFirstLoad = true
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
  }
  self.bankSlotInfo = {
    emptySlots = 0,
    emptyReagentSlots = 0,
    totalItems = 0,
    freeSlotKey = "",
    freeReagentSlotKey = "",
    emptySlotByBagAndSlot = {},
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
  wipe(self.dirtyItems)

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
  local itemID = C_Container.GetContainerItemID(bagid, slotid)
  local itemLink = nil
  if itemID ~= nil then
    _, itemLink = GetItemInfo(itemID)
  end
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
---@return ExtraSlotInfo
function items:GetExtraSlotInfo(kind)
  return kind == const.BAG_KIND.BACKPACK and self.slotInfo or self.bankSlotInfo
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
  }

  ---@type table<number, ItemData>
  local stacks = {}

  local dirty = {}
  for bagid, bag in pairs(items.itemsByBagAndSlot) do
    extraSlotInfo.emptySlotByBagAndSlot[bagid] = extraSlotInfo.emptySlotByBagAndSlot[bagid] or {}
    for slotid, data in pairs(bag) do
      -- Check if the item as changed, and if so, add it to the dirty list.
      if items:HasItemChanged(bagid, slotid, data) then
        debug:Log("Dirty Item", data.itemInfo and data.itemInfo.itemLink)
        wipe(data)
        data.bagid = bagid
        data.slotid = slotid
        items:AttachItemInfo(data, const.BAG_KIND.BACKPACK)
        table.insert(items.dirtyItems, data)
        dirty[self:GetSlotKey(data)] = data
      end

      -- Compute stacking data.
      if not data.isItemEmpty then
        local stackItem = stacks[data.itemInfo.itemID]
        if stackItem ~= nil then
          stackItem.stacks[data.itemInfo.itemGUID] = items:GetSlotKey(data)
          data.stackedOn = items:GetSlotKey(stackItem)
          data.stackedCount = data.itemInfo.currentItemCount
          data.stacks = {}
          stackItem.stackedCount = stackItem.stackedCount + data.itemInfo.currentItemCount
          local key = items:GetSlotKey(data)
          if dirty[key] == nil then
            table.insert(items.dirtyItems, data)
            dirty[key] = data
          end

          key = items:GetSlotKey(stackItem)
          if dirty[key] == nil then
            table.insert(items.dirtyItems, stackItem)
            dirty[key] = stackItem
          end
        else
          data.stacks = {}
          data.stackedOn = nil
          data.stackedCount = data.itemInfo.currentItemCount
          stacks[data.itemInfo.itemID] = data
        end
      end

      if data.isItemEmpty then
        data.stacks = {}
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

  self.slotInfo = extraSlotInfo
  -- All items in all bags have finished loading, fire the all done event.
  if not self._firstLoad then
    debug:EndProfile('Backpack Data Pipeline')
    events:SendMessageLater('items/RefreshBackpack/Done', function()
      wipe(items.dirtyItems)
      items._container = nil
      items._doingRefreshAll = false
    end,
    items.dirtyItems)
  end
end

  -- Load item data in the background, and fire a message when
  -- all bags are done loading.
function items:ProcessContainer()
  self._container:ContinueOnLoad(function() self:BackpackLoadFunction() end)
  -- Call the data load function twice on first load, because the first load
  -- sometimes does not complete, even though the container is marked as done.
  -- This is a Blizzard bug.
  if self._firstLoad then
    self._firstLoad = false
    self._container:ContinueOnLoad(function() self:BackpackLoadFunction() end)
  end
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
  }
  for bagid, bag in pairs(items.bankItemsByBagAndSlot) do
    extraSlotInfo.emptySlotByBagAndSlot[bagid] = extraSlotInfo.emptySlotByBagAndSlot[bagid] or {}
    for slotid, data in pairs(bag) do
      items:AttachItemInfo(data, const.BAG_KIND.BACKPACK)
      table.insert(items.dirtyBankItems, data)

      if data.isItemEmpty then
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
  self.bankSlotInfo = extraSlotInfo
  -- All items in all bags have finished loading, fire the all done event.
  if not self._bankFirstLoad then
    events:SendMessage('items/RefreshBank/Done', items.dirtyBankItems)
    wipe(items.dirtyBankItems)
    items._bankContainer = nil
    items._doingRefreshAll = false
  end
end

-- Load item data in the background, and fire a message when
-- all bags are done loading.
function items:ProcessBankContainer()
  self._bankContainer:ContinueOnLoad(function() self:BankLoadFunction() end)
  -- Call the data load function twice on first load, because the first load
  -- sometimes does not complete, even though the container is marked as done.
  -- This is a Blizzard bug.
  if self._bankFirstLoad then
    self._bankFirstLoad = false
    self._bankContainer:ContinueOnLoad(function() self:BankLoadFunction() end)
  end
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

function items:ClearNewItems()
  wipe(self._newItemTimers)
end

---@param data ItemData
---@param kind BagKind
function items:AttachItemInfo(data, kind)
  local itemMixin = Item:CreateFromBagAndSlot(data.bagid, data.slotid) --[[@as ItemMixin]]
  local itemLocation = itemMixin:GetItemLocation() --[[@as ItemLocationMixin]]
  local bagid, slotid = data.bagid, data.slotid
  local itemID = C_Container.GetContainerItemID(bagid, slotid)
  data.kind = kind
  data.basic = false
  if itemID == nil then
    data.isItemEmpty = true
    data.itemInfo = {} --[[@as table]]
    return
  end
  data.isItemEmpty = false
  local itemName, itemLink, itemQuality,
  itemLevel, itemMinLevel, itemType, itemSubType,
  itemStackCount, itemEquipLoc, itemTexture,
  sellPrice, classID, subclassID, bindType, expacID,
  setID, isCraftingReagent = GetItemInfo(itemID)
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
end
