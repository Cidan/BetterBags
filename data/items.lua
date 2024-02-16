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

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class (exact) ItemData
---@field itemInfo ExpandedItemInfo
---@field containerInfo ContainerItemInfo
---@field questInfo ItemQuestInfo
---@field bagid number
---@field slotid number
---@field isItemEmpty boolean
local itemDataProto = {}

---@class (exact) Items: AceModule
---@field itemsByBagAndSlot table<number, table<number, ItemData>>
---@field dirtyItems ItemData[]
---@field dirtyBankItems ItemData[]
---@field previousItemGUID table<number, table<number, string>>
---@field _container ContinuableContainer
---@field _bankContainer ContinuableContainer
---@field _doingRefreshAll boolean
local items = addon:NewModule('Items')

function items:OnInitialize()
  self.dirtyItems = {}
  self.dirtyBankItems = {}
  self.itemsByBagAndSlot = {}
  self.previousItemGUID = {}
end

function items:OnEnable()

  events:RegisterEvent('EQUIPMENT_SETS_CHANGED', function() self:RefreshAll() end)
  local eventList = {
    'BAG_UPDATE_DELAYED',
    'PLAYERBANKSLOTS_CHANGED',
  }

  if addon.isRetail then
    table.insert(eventList, 'PLAYERREAGENTBANKSLOTS_CHANGED')
  end

  events:GroupBucketEvent(eventList, function() self:RefreshAll() end)

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
end

function items:RefreshAll()
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
  -- Loop through all the bags and schedule each item for a refresh.
  for i in pairs(const.REAGENTBANK_BAGS) do
    self.itemsByBagAndSlot[i] = self.itemsByBagAndSlot[i] or {}
    self.previousItemGUID[i] = self.previousItemGUID[i] or {}
    self:RefreshBag(i, true)
  end

  --- Process the item container.
  self:ProcessBankContainer()
end

function items:RefreshBank()
  equipmentSets:Update()
  self._bankContainer = ContinuableContainer:Create()

  -- This is a small hack to force the bank bag quality data to be cached
  -- before the bank bag frame is drawn.
  for _, bag in pairs(const.BANK_ONLY_BAGS) do
    local id = C_Container.ContainerIDToInventoryID(bag)
    GetInventoryItemQuality("player", id)
  end

  -- Loop through all the bags and schedule each item for a refresh.
  for i in pairs(const.BANK_BAGS) do
    self.itemsByBagAndSlot[i] = {}
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

  -- Load item data in the background, and fire a message when
  -- all bags are done loading.
function items:ProcessContainer()
  self._container:ContinueOnLoad(function()
    for _, data in pairs(items.dirtyItems) do
      items:AttachItemInfo(data)
    end

    -- All items in all bags have finished loading, fire the all done event.
    events:SendMessage('items/RefreshBackpack/Done', items.dirtyItems)
    wipe(items.dirtyItems)
    items._container = nil
    items._doingRefreshAll = false
  end)
end

-- Load item data in the background, and fire a message when
-- all bags are done loading.
function items:ProcessBankContainer()
  self._bankContainer:ContinueOnLoad(function()
    for _, data in pairs(items.dirtyBankItems) do
      items:AttachItemInfo(data)
    end
    -- All items in all bags have finished loading, fire the all done event.
    events:SendMessage('items/RefreshBank/Done', items.dirtyBankItems)
    wipe(items.dirtyBankItems)
    items._bankContainer = nil
    items._doingRefreshAll = false
  end)
end

---@param data ItemData
function items:AttachItemInfo(data)
  local itemMixin = Item:CreateFromBagAndSlot(data.bagid, data.slotid) --[[@as ItemMixin]]
  local itemLocation = itemMixin:GetItemLocation() --[[@as ItemLocationMixin]]
  local bagid, slotid = data.bagid, data.slotid
  local itemID = C_Container.GetContainerItemID(bagid, slotid)
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

--TODO(lobato): Completely eliminate the use of ItemMixin.
-- RefreshBag will refresh a bag's contents entirely and update the
-- item database.
---@private
---@param bagid number
---@param bankBag boolean
function items:RefreshBag(bagid, bankBag)
  local size = C_Container.GetContainerNumSlots(bagid)
  local dirty = bankBag and self.dirtyBankItems or self.dirtyItems
  -- Loop through every container slot and create an item for it.
  for slotid = 1, size do
    local itemMixin = Item:CreateFromBagAndSlot(bagid, slotid)
    local data = setmetatable({}, {__index = itemDataProto})
    data.bagid = bagid
    data.slotid = slotid

    table.insert(dirty, data)

    -- If this is an actual item, add it to the callback container
    -- so data is fetched from the server.
    if not itemMixin:IsItemEmpty() and not itemMixin:IsItemDataCached() then
      if bankBag then
        self._bankContainer:AddContinuable(itemMixin)
      else
        self._container:AddContinuable(itemMixin)
      end
    else
      data.isItemEmpty = true
    end

    -- All items are added to the bag/slot lookup table, including
    -- empty items
    self.itemsByBagAndSlot[bagid][slotid] = data
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