-- luacheck: ignore 212 211, globals SLASH_BETTERBAGS_DEBUGITEMS1 SlashCmdList
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)

---@class Events: AceModule
--local events = addon:GetModule("Events")

---@class Constants: AceModule
local const = addon:GetModule("Constants")

---@class EquipmentSets: AceModule
--local equipmentSets = addon:GetModule("EquipmentSets")

---@class Categories: AceModule
--local categories = addon:GetModule("Categories")

---@class Database: AceModule
local database = addon:GetModule("Database")

---@class Context: AceModule
--local context = addon:GetModule("Context")

---@class Search: AceModule
--local search = addon:GetModule("Search")

---@class Localization: AceModule
local L = addon:GetModule("Localization")

---@class Binding: AceModule
local binding = addon:GetModule("Binding")

---@class Async: AceModule
--local async = addon:GetModule("Async")

---@class Debug: AceModule
--local debug = addon:GetModule("Debug")

---@alias SlotKey string

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

---@class (exact) TransmogInfo
---@field transmogInfoMixin? ItemTransmogInfoMixin
---@field itemAppearanceID number
---@field itemModifiedAppearanceID number
---@field hasTransmog boolean

---@class (exact) ItemData
---@field basic boolean
---@field itemInfo ExpandedItemInfo
---@field containerInfo ContainerItemInfo
---@field questInfo ItemQuestInfo
---@field transmogInfo TransmogInfo
---@field bindingInfo BindingInfo
---@field bagid number
---@field slotid number
---@field inventoryType number
---@field inventorySlots number[]
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

local items = addon:NewModule("Items")

-- BOOT STUBS & LEGACY PROTOTYPES
function items:OnInitialize()
  self.slotInfo = {}
  self.searchCache = {
    [const.BAG_KIND.BACKPACK] = {},
    [const.BAG_KIND.BANK] = {},
  }
  self.categoryPriorityCache = {
    [const.BAG_KIND.BACKPACK] = {},
    [const.BAG_KIND.BANK] = {},
  }
  self._newItemTimers = {}
  self._preSort = false
  self._doingRefresh = false
  self._firstLoad = {
    [const.BAG_KIND.BACKPACK] = true,
    [const.BAG_KIND.BANK] = true,
  }
  self.equipmentCache = {}
  self.previousItemGUID = {}
end

function items:OnEnable()
  self:ResetSlotInfo()
end

function items:WipeSlotInfo(kind)
  self.slotInfo = self.slotInfo or {}
  self.slotInfo[kind] = self:NewSlotInfo()
end

function items:ResetSlotInfo()
  self:WipeSlotInfo(const.BAG_KIND.BACKPACK)
  self:WipeSlotInfo(const.BAG_KIND.BANK)
end

function items:RemoveNewItemFromAllItems()
  -- NOOP stub for boot
end

function items:RefreshAll(ctx)
  -- NOOP stub for boot
end

function items:ClearItemCache(ctx)
  self.previousItemGUID = {}
  self:ResetSlotInfo()
end

function items:ClearBankCache(ctx)
  self:WipeSlotInfo(const.BAG_KIND.BANK)
end

function items:WipeAndRefreshAll(ctx)
  self:ClearItemCache(ctx)
end

function items:Restack(ctx, kind, callback)
  if callback then callback() end
end

-- UpdateFreeSlots updates the current free slot count for a given bag kind.
---@param ctx Context
---@param kind BagKind
function items:UpdateFreeSlots(ctx, kind)
  local baglist
  local tab = ctx:Get("bagid")
  if kind == const.BAG_KIND.BANK then
    local blizzardTab = addon.Bags and addon.Bags.Bank and addon.Bags.Bank.blizzardBankTab
    if blizzardTab and addon.isRetail then
      baglist = { [blizzardTab] = blizzardTab }
    elseif tab == const.BANK_TAB.BANK then
      baglist = const.BANK_BAGS
    elseif const.ACCOUNT_BANK_BAGS and tab == const.BANK_TAB.ACCOUNT_BANK_1 then
      baglist = const.ACCOUNT_BANK_BAGS
    else
      baglist = { [tab] = tab }
    end
  else
    baglist = const.BACKPACK_BAGS
  end

  self.slotInfo[kind].emptySlots = {}

  for bagid in pairs(baglist) do
    local freeSlots = C_Container.GetContainerNumFreeSlots(bagid) or 0
    local name
    local invid = C_Container.ContainerIDToInventoryID(bagid)
    local baglink = GetInventoryItemLink("player", invid)
    if baglink ~= nil and invid ~= nil then
      local class, subclass = select(6, C_Item.GetItemInfoInstant(baglink)) --[[@as number]]
      name = C_Item.GetItemSubClassInfo(class, subclass)
    else
      name = C_Item.GetItemSubClassInfo(Enum.ItemClass.Container, 0)
    end
    if addon.isClassic and Enum.BagIndex and (bagid == Enum.BagIndex.Bank or (Enum.BagIndex.Reagentbank and bagid == Enum.BagIndex.Reagentbank)) then
      freeSlots = freeSlots - 4
    end
    if not (Enum.BagIndex and Enum.BagIndex.Keyring and bagid == Enum.BagIndex.Keyring) then
      self.slotInfo[kind].emptySlots[name] = self.slotInfo[kind].emptySlots[name] or 0
      self.slotInfo[kind].emptySlots[name] = self.slotInfo[kind].emptySlots[name] + freeSlots
    end
  end
end

--- CENTRALIZED PIPELINE REFRESH ORCHESTRATOR (PHASES 1-5)
---@param ctx Context
---@param kind BagKind
function items:ProcessRefresh(ctx, kind)
  local bagList = {}
  if kind == const.BAG_KIND.BACKPACK then
    bagList = const.BACKPACK_BAGS
  elseif kind == const.BAG_KIND.BANK then
    if const.BANK_ONLY_BAGS then
      for _, bag in pairs(const.BANK_ONLY_BAGS) do
        local id = C_Container.ContainerIDToInventoryID(bag)
        if id and GetInventoryItemQuality then
          GetInventoryItemQuality("player", id)
        end
      end
    end

    local blizzardTab = addon.Bags and addon.Bags.Bank and addon.Bags.Bank.blizzardBankTab
    if addon.isRetail then
      ctx:Set("bagid", const.BANK_TAB.BANK)
      for _, bag in pairs(const.BANK_BAGS) do
        bagList[bag] = bag
      end
      if const.ACCOUNT_BANK_BAGS then
        for _, bag in pairs(const.ACCOUNT_BANK_BAGS) do
          bagList[bag] = bag
        end
      end
      local reagentBank = not addon.isRetail and const.BANK_TAB.REAGENT or nil
      if reagentBank then
        bagList[reagentBank] = reagentBank
      end
    elseif blizzardTab and addon.isRetail then
      if Enum.BagIndex and Enum.BagIndex.AccountBankTab_1 and blizzardTab >= Enum.BagIndex.AccountBankTab_1 then
        ctx:Set("bagid", const.BANK_TAB.ACCOUNT_BANK_1)
      else
        ctx:Set("bagid", const.BANK_TAB.BANK)
      end
      bagList[blizzardTab] = blizzardTab
    else
      local activeGroupID = database:GetActiveGroup(const.BAG_KIND.BANK)
      local activeGroup = activeGroupID and database:GetGroup(const.BAG_KIND.BANK, activeGroupID)
      local reagentBank = not addon.isRetail and const.BANK_TAB.REAGENT or nil

      if activeGroup and addon.isRetail and activeGroup.bankType == (Enum and Enum.BankType and Enum.BankType.Account) then
        ctx:Set("bagid", const.BANK_TAB.ACCOUNT_BANK_1)
        if const.ACCOUNT_BANK_BAGS then
          for _, bag in pairs(const.ACCOUNT_BANK_BAGS) do
            bagList[bag] = bag
          end
        end
      else
        ctx:Set("bagid", const.BANK_TAB.BANK)
        for _, bag in pairs(const.BANK_BAGS) do
          bagList[bag] = bag
        end
        if reagentBank then
          bagList[reagentBank] = reagentBank
        end
      end
    end
  end

  local itemData, equipmentData = self:Harvest(kind, bagList, kind == const.BAG_KIND.BACKPACK)

  local slotInfo = self.slotInfo[kind]
  if not slotInfo then
    self:WipeSlotInfo(kind)
    slotInfo = self.slotInfo[kind]
  end

  local previousItems = slotInfo.itemsBySlotKey or {}
  local added = {}
  local removed = {}
  local updated = {}

  for slotkey, newItem in pairs(itemData) do
    local oldItem = previousItems[slotkey]
    if newItem.isItemEmpty then
      if oldItem and not oldItem.isItemEmpty then
        removed[slotkey] = oldItem
      end
    else
      if not oldItem or oldItem.isItemEmpty then
        added[slotkey] = newItem
      else
        if oldItem.itemHash ~= newItem.itemHash or
           oldItem.itemInfo.currentItemCount ~= newItem.itemInfo.currentItemCount or
           oldItem.itemInfo.isNewItem ~= newItem.itemInfo.isNewItem then
          updated[slotkey] = newItem
        end
      end
    end
  end

  for slotkey, oldItem in pairs(previousItems) do
    if not itemData[slotkey] and not oldItem.isItemEmpty then
      removed[slotkey] = oldItem
    end
  end

  if self._firstLoad[kind] == true then
    self._firstLoad[kind] = false
    ctx:Set("wipe", true)
  end

  slotInfo:Update(ctx, itemData)
  slotInfo.addedItems = added
  slotInfo.removedItems = removed
  slotInfo.updatedItems = updated

  if kind == const.BAG_KIND.BACKPACK then
    self.equipmentCache = equipmentData
  end

  self:UpdateFreeSlots(ctx, kind)

  for _, currentItem in pairs(itemData) do
    local bagid = currentItem.bagid
    local slotid = currentItem.slotid
    local name
    local invid = C_Container.ContainerIDToInventoryID(bagid)
    local baglink = GetInventoryItemLink("player", invid)

    if Enum.BagIndex and Enum.BagIndex.Keyring and bagid == Enum.BagIndex.Keyring then
      name = L:G("Keyring")
    elseif baglink ~= nil and invid ~= nil then
      local class, subclass = select(6, C_Item.GetItemInfoInstant(baglink)) --[[@as number]]
      name = C_Item.GetItemSubClassInfo(class, subclass)
    else
      name = C_Item.GetItemSubClassInfo(Enum.ItemClass.Container, 0)
    end

    slotInfo:StoreIfEmptySlot(name, currentItem)

    if not currentItem.isItemEmpty then
      slotInfo.totalItems = slotInfo.totalItems + 1
    end
    currentItem.itemInfo.category = self:GetCategory(ctx, currentItem)
  end

  slotInfo:SortEmptySlots()

  for _, addedItem in pairs(slotInfo.addedItems) do
    for _, removedItem in pairs(slotInfo.removedItems) do
      if addedItem.itemInfo and removedItem.itemInfo and addedItem.itemInfo.itemGUID == removedItem.itemInfo.itemGUID then
        self:ClearNewItem(ctx, addedItem.slotkey)
      end
    end
  end

  if slotInfo.totalItems < slotInfo.previousTotalItems then
    slotInfo.deferDelete = true
  end

  slotInfo.stacks:Clear()
  for _, item in pairs(itemData) do
    if not item.isItemEmpty then
      slotInfo.stacks:AddToStack(item)
    end
  end

  local function ShouldMergeItem(bagKind, item, stackInfo)
    if not stackInfo then return false end
    local opts = database:GetStackingOptions(bagKind)
    if not opts.mergeStacks then return false end
    if opts.unmergeAtShop and addon.atInteracting then return false end
    if opts.dontMergePartial and item.itemInfo.itemStackCount ~= item.itemInfo.currentItemCount then return false end
    if not opts.mergeUnstackable and item.itemInfo.itemStackCount == 1 then return false end
    return true
  end

  slotInfo.visibleItemsBySlotKey = {}
  for slotkey, item in pairs(itemData) do
    if not item.isItemEmpty then
      local stackInfo = slotInfo.stacks:GetStackInfo(item.itemHash)
      local isRoot = true

      if ShouldMergeItem(kind, item, stackInfo) then
        if item.slotkey == stackInfo.rootItem then
          -- Root item. Compute total count.
          local totalCount = item.itemInfo.currentItemCount
          for childSlotkey in pairs(stackInfo.slotkeys) do
            local childItem = itemData[childSlotkey]
            if childItem and not childItem.isItemEmpty then
              if ShouldMergeItem(kind, childItem, stackInfo) then
                totalCount = totalCount + childItem.itemInfo.currentItemCount
              end
            end
          end
          item.stackedCount = totalCount
        else
          isRoot = false
        end
      else
        item.stackedCount = nil
      end

      if isRoot then
        slotInfo.visibleItemsBySlotKey[slotkey] = item
      end
    end
  end

  local search = addon:GetModule("Search")
  if search and search.IndexItems then
    search:IndexItems(itemData)
  end

  local ev = kind == const.BAG_KIND.BANK and "items/RefreshBank/Done" or "items/RefreshBackpack/Done"
  local events = addon:GetModule("Events")
  events:SendMessage(ctx, ev, slotInfo)
end

function items:RefreshBackpack(ctx)
  self:ProcessRefresh(ctx, const.BAG_KIND.BACKPACK)
end

function items:RefreshBank(ctx)
  self:ProcessRefresh(ctx, const.BAG_KIND.BANK)
end

function items:GetSearchCategory(kind, slotkey)
  return nil
end

function items:WipeSearchCache(kind)
  -- NOOP stub
end

function items:RefreshSearchCache(kind)
  -- NOOP stub
end

function items:GetGroupBySuffix(data, groupBy)
  if not data or data.isItemEmpty then return nil end
  if groupBy == const.SEARCH_CATEGORY_GROUP_BY.TYPE then
    return data.itemInfo and data.itemInfo.itemType
  elseif groupBy == const.SEARCH_CATEGORY_GROUP_BY.SUBTYPE then
    return data.itemInfo and data.itemInfo.itemSubType
  elseif groupBy == const.SEARCH_CATEGORY_GROUP_BY.EXPANSION then
    local expacID = data.itemInfo and data.itemInfo.expacID
    return const.EXPANSION_MAP[expacID] or "Unknown"
  end
  return nil
end

function items:GetItemData(ctx, itemList, callback)
  if callback then callback() end
end

function items:IsNewItem(data)
  if not data or data.isItemEmpty then return false end
  if _G.C_NewItems and _G.C_NewItems.IsNewItem then
    if _G.C_NewItems.IsNewItem(data.bagid, data.slotid) then
      return true
    end
  end
  local guid = data.itemInfo and data.itemInfo.itemGUID
  if guid and self._newItemTimers[guid] then
    local diff = time() - self._newItemTimers[guid]
    local limit = database:GetNewItemTime() or 30
    return diff < limit
  end
  return false
end

function items:ClearNewItem(ctx, slotkey)
  -- NOOP stub
end

function items:ClearNewItems()
  -- NOOP stub
end

function items:MarkItemAsNew(ctx, data)
  if data and data.itemInfo and data.itemInfo.itemGUID then
    self._newItemTimers[data.itemInfo.itemGUID] = time()
  end
end

function items:MarkItemSlotAsNew(ctx, slotkey)
  -- NOOP stub
end

function items:GetItemDataFromSlotKey(slotkey)
  local kind = self:GetBagKindFromSlotKey(slotkey)
  if not kind then return nil end
  return self.slotInfo[kind] and self.slotInfo[kind].itemsBySlotKey[slotkey]
end

function items:GetItemDataFromInventorySlot(slot)
  return self.equipmentCache[slot]
end

function items:GetStackData(item)
  return nil
end

function items:PreLoadAllEquipmentSlots(cb)
  if cb then cb() end
end

function items:GetAllSlotInfo()
  return self.slotInfo
end

-- PURE DATA HARVESTING ENGINE (PHASE 2)

--- Harvest sweeps the specified bag list and builds a flat table of physical ItemData.
---@param kind BagKind
---@param bagList table<number, number> Bags to sweep (e.g., const.BACKPACK_BAGS)
---@param includeEquipment boolean Whether to include equipped items
---@return table<string, ItemData> itemData A flat table of physical item datas indexed by slotKey
---@return table<number, ItemData> equipmentData A flat table of equipped item datas indexed by inventory slot ID
function items:Harvest(kind, bagList, includeEquipment)
  local itemData = {}
  local equipmentData = {}

  -- 1. Sweep physical container bags
  for bagid in pairs(bagList) do
    local size = C_Container.GetContainerNumSlots(bagid)
    if size and size > 0 then
      for slotid = 1, size do
        local data = {}
        ---@cast data +ItemData
        data.bagid, data.slotid = bagid, slotid
        self:AttachItemInfo(data, kind)
        itemData[self:GetSlotKey(data)] = data
      end
    end
  end

  -- 2. Sweep equipment if requested
  if includeEquipment then
    for i = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
      local itemMixin = Item:CreateFromEquipmentSlot(i)
      if not itemMixin:IsItemEmpty() then
        local data = self:GetEquipmentInfo(itemMixin)
        equipmentData[data.inventorySlots[1]] = data
      end
    end
  end

  return itemData, equipmentData
end

-- IN-GAME DEBUG SLASH COMMAND
SLASH_BETTERBAGS_DEBUGITEMS1 = "/bb"
SlashCmdList["BETTERBAGS_DEBUGITEMS"] = function(msg)
  if msg == "debugitems" then
    print("|cff00ff00BetterBags Debug Physical Items Map:|r")
    -- Collect backpack bags
    local backpackItems = items:Harvest(const.BAG_KIND.BACKPACK, const.BACKPACK_BAGS, true)
    local count = 0
    for slotkey, data in pairs(backpackItems) do
      if not data.isItemEmpty then
        print(format("Slotkey: %s | ItemID: %d | Name: %s | Count: %d",
          slotkey, data.itemInfo.itemID, data.itemInfo.itemName, data.itemInfo.currentItemCount))
        count = count + 1
      end
    end
    print(format("|cff00ff00Total Non-Empty Backpack Items Harvested: %d|r", count))
  else
    print("BetterBags Debug Commands: use '/bb debugitems' to dump harvested physical items.")
  end
end

-- REUSED DETAILED METADATA UTILITIES FROM LEGACY IMPLEMENTATION

---@param data ItemData
---@return string
function items:GetSlotKey(data)
  return data.bagid .. "_" .. data.slotid
end

---@param bagid number
---@param slotid number
---@return string
function items:GetSlotKeyFromBagAndSlot(bagid, slotid)
  return bagid .. "_" .. slotid
end

---@param slotkey string
---@return BagKind|nil
function items:GetBagKindFromSlotKey(slotkey)
  local bagid = tonumber((strsplit("_", slotkey)))
  if not bagid then return nil end
  return self:GetBagKindFromBagID(bagid)
end

---@param bagid number|string
---@return BagKind
function items:GetBagKindFromBagID(bagid)
  local bid = tonumber(bagid)
  if not bid then return const.BAG_KIND.BACKPACK end
  if const.BACKPACK_BAGS[bid] then
    return const.BAG_KIND.BACKPACK
  elseif const.BANK_BAGS[bid] or (const.ACCOUNT_BANK_BAGS and const.ACCOUNT_BANK_BAGS[bid]) then
    return const.BAG_KIND.BANK
  end
  return const.BAG_KIND.BACKPACK
end

---@param bagid number
---@return number, number
function items:GetBagTypeFromBagID(bagid)
  local invid = C_Container.ContainerIDToInventoryID(bagid)
  local baglink = GetInventoryItemLink("player", invid)
  if baglink ~= nil and invid ~= nil then
    local class, subclass = select(6, C_Item.GetItemInfoInstant(baglink)) --[[@as number]]
    return class, subclass
  else
    return Enum.ItemClass.Container, 0
  end
end

-- HasReagentBag returns true if the player has a reagent bag slotted in their inventory.
---@return boolean
function items:HasReagentBag()
  local invid = C_Container.ContainerIDToInventoryID(Enum.BagIndex.ReagentBag)
  local baglink = GetInventoryItemLink("player", invid)
  if not baglink then
    return false
  end
  return true
end

---@param itemLink string
---@return Enum.ItemBind?
function items:GetBindTypeFromLink(itemLink)
  local bindType = nil
  if strfind(itemLink, "item:") then
    bindType = select(14, C_Item.GetItemInfo(itemLink))
  end
  return bindType
end

---@param itemMixin ItemMixin
---@return ItemData
function items:GetEquipmentInfo(itemMixin)
  local data = {}
  ---@cast data +ItemData
  local invType = itemMixin:GetInventoryType()
  local itemLocation = itemMixin:GetItemLocation() --[[@as ItemLocationMixin]]
  local itemLink = itemMixin:GetItemLink() --[[@as string]]
  local itemID = itemMixin:GetItemID() --[[@as number]]
  local itemName, _, _, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, expacID, setID =
    C_Item.GetItemInfo(itemLink)

  itemName = itemName or ""
  itemLevel = itemLevel or 0
  itemMinLevel = itemMinLevel or 0
  itemType = itemType or ""
  itemSubType = itemSubType or ""
  itemStackCount = itemStackCount or 1
  itemEquipLoc = itemEquipLoc or ""
  itemTexture = itemTexture or 134400
  sellPrice = sellPrice or 0
  classID = classID or 0
  subclassID = subclassID or 0
  bindType = bindType or 0
  expacID = expacID or 0
  setID = setID or 0

  local itemAppearanceID, itemModifiedAppearanceID = 0, 0
  if C_TransmogCollection and itemLink then
    local appID, modAppID = C_TransmogCollection.GetItemInfo(itemLink)
    itemAppearanceID = appID or 0
    itemModifiedAppearanceID = modAppID or 0
  end

  data.transmogInfo = {
    transmogInfoMixin = C_Item.GetCurrentItemTransmogInfo and C_Item.GetCurrentItemTransmogInfo(itemLocation) or {
      appearanceID = 0,
      secondaryAppearanceID = 0,
      appliedAppearanceID = 0,
      appliedSecondaryAppearanceID = 0,
    },
    itemAppearanceID = itemAppearanceID,
    itemModifiedAppearanceID = itemModifiedAppearanceID,
    hasTransmog = C_TransmogCollection and C_TransmogCollection.PlayerHasTransmog(itemID, itemModifiedAppearanceID) or false,
  }
  data.inventoryType = invType --[[@as number]]
  data.inventorySlots = { itemMixin:GetItemLocation():GetEquipmentSlot() }
  local itemQuality = C_Item.GetItemQuality(itemLocation) --[[@as ItemQuality]]
  itemQuality = itemQuality or const.ITEM_QUALITY.Common
  local effectiveIlvl, isPreview, baseIlvl = C_Item.GetDetailedItemLevelInfo(itemLink)
  effectiveIlvl = effectiveIlvl or itemLevel or 0
  isPreview = not not isPreview
  baseIlvl = baseIlvl or itemLevel or 0

  data.itemInfo = {
    itemID = itemID,
    itemGUID = C_Item.GetItemGUID(itemLocation) or "",
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
    isCraftingReagent = false,
    effectiveIlvl = effectiveIlvl --[[@as number]],
    isPreview = isPreview --[[@as boolean]],
    baseIlvl = baseIlvl --[[@as number]],
    itemIcon = itemTexture or 134400,
    isBound = C_Item.IsBound and C_Item.IsBound(itemLocation) or false,
    isLocked = false,
    isNewItem = false,
    currentItemCount = C_Item.GetStackCount and C_Item.GetStackCount(itemLocation) or 1,
    category = "",
    currentItemLevel = C_Item.GetCurrentItemLevel and C_Item.GetCurrentItemLevel(itemLocation) or effectiveIlvl or 0,
    equipmentSet = nil,
  }
  return data
end

---@param data ItemData
---@param kind BagKind
---@return ItemData
function items:AttachItemInfo(data, kind)
  local bagid, slotid = data.bagid, data.slotid
  local slotkey = self:GetSlotKeyFromBagAndSlot(bagid, slotid)
  local itemLoader = addon:GetModule("ItemLoader", true)
  local itemMixin = itemLoader and itemLoader:GetItemMixinFromSlotKey(slotkey) or Item:CreateFromBagAndSlot(bagid, slotid) --[[@as ItemMixin]]
  local itemLocation = itemMixin:GetItemLocation() --[[@as ItemLocationMixin]]
  local itemID = C_Container.GetContainerItemID(bagid, slotid)
  local itemLink = C_Container.GetContainerItemLink(bagid, slotid)
  data.kind = kind
  data.basic = false
  data.slotkey = slotkey
  if itemID == nil then
    data.isItemEmpty = true
    data.bindingInfo = {} --[[@as table]]
    data.itemInfo = {} --[[@as table]]
    return data
  end
  data.isItemEmpty = false
  local itemName, _, _, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, expacID, setID, isCraftingReagent =
    C_Item.GetItemInfo(itemID)

  itemName = itemName or ""
  itemLevel = itemLevel or 0
  itemMinLevel = itemMinLevel or 0
  itemType = itemType or ""
  itemSubType = itemSubType or ""
  itemStackCount = itemStackCount or 1
  itemEquipLoc = itemEquipLoc or ""
  itemTexture = itemTexture or 134400
  sellPrice = sellPrice or 0
  classID = classID or 0
  subclassID = subclassID or 0
  bindType = bindType or 0
  expacID = expacID or 0
  setID = setID or 0
  isCraftingReagent = not not isCraftingReagent

  bindType = self:GetBindTypeFromLink(itemLink) or bindType --link overrides itemID if set
  local itemQuality = C_Item.GetItemQuality(itemLocation) --[[@as ItemQuality]]
  itemQuality = itemQuality or const.ITEM_QUALITY.Common

  local effectiveIlvl, isPreview, baseIlvl = C_Item.GetDetailedItemLevelInfo(itemID)
  effectiveIlvl = effectiveIlvl or itemLevel or 0
  isPreview = not not isPreview
  baseIlvl = baseIlvl or itemLevel or 0

  local invType = itemMixin:GetInventoryType()
  data.containerInfo = C_Container.GetContainerItemInfo(bagid, slotid)
  if not data.containerInfo then
    data.containerInfo = {
      iconFileID = itemTexture or 134400,
      stackCount = 1,
      isLocked = false,
      quality = itemQuality,
      isReadable = false,
      hasLoot = false,
      hyperlink = itemLink or "",
      isFiltered = false,
      hasNoValue = false,
      itemID = itemID,
      isBound = false,
    }
  end
  data.containerInfo.itemName = data.containerInfo.itemName or itemName or ""
  data.containerInfo.iconFileID = data.containerInfo.iconFileID or itemTexture or 134400
  data.containerInfo.quality = data.containerInfo.quality or itemQuality

  data.questInfo = C_Container.GetContainerItemQuestInfo(bagid, slotid)
  if not data.questInfo then
    data.questInfo = {
      isQuestItem = false,
      isActive = false,
    }
  end

  local itemAppearanceID, itemModifiedAppearanceID = 0, 0
  if C_TransmogCollection and itemLink then
    local appID, modAppID = C_TransmogCollection.GetItemInfo(itemLink)
    itemAppearanceID = appID or 0
    itemModifiedAppearanceID = modAppID or 0
  end
  data.transmogInfo = {
    transmogInfoMixin = C_Item.GetCurrentItemTransmogInfo and C_Item.GetCurrentItemTransmogInfo(itemLocation) or {
      appearanceID = 0,
      secondaryAppearanceID = 0,
      appliedAppearanceID = 0,
      appliedSecondaryAppearanceID = 0,
    },
    itemAppearanceID = itemAppearanceID,
    itemModifiedAppearanceID = itemModifiedAppearanceID,
    hasTransmog = C_TransmogCollection and C_TransmogCollection.PlayerHasTransmog(itemID, itemModifiedAppearanceID) or false,
  }

  data.bindingInfo = binding.GetItemBinding(itemLocation, bindType) or { binding = 0, bound = false }

  -- Extract tooltip text for search indexing
  ---@class TooltipScanner: AceModule
  local tooltipScanner = addon:GetModule('TooltipScanner')
  local itemGUID = C_Item.GetItemGUID(itemLocation) or ""
  local tooltipText = tooltipScanner:GetTooltipText(bagid, slotid, itemGUID)

  data.inventoryType = invType --[[@as number]]
  data.inventorySlots = const.INVENTORY_TYPE_TO_INVENTORY_SLOTS[invType]
      and const.INVENTORY_TYPE_TO_INVENTORY_SLOTS[invType]
    or { 0 }
  data.itemInfo = {
    itemID = itemID,
    itemGUID = itemGUID,
    itemName = data.containerInfo.itemName or itemName or "",
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
    itemIcon = data.containerInfo.iconFileID or itemTexture or 134400,
    isBound = data.containerInfo.isBound or false,
    isLocked = data.containerInfo.isLocked or false,
    isNewItem = self:IsNewItem(data),
    currentItemCount = data.containerInfo.stackCount or 1,
    category = "",
    currentItemLevel = C_Item.GetCurrentItemLevel and C_Item.GetCurrentItemLevel(itemLocation) or effectiveIlvl or 0,
    equipmentSet = nil,
  }
  -- Track max item level for dynamic coloring
  if data.itemInfo.currentItemLevel and data.itemInfo.currentItemLevel > 0 then
    local cID = data.itemInfo.classID
    local isGear
    if Enum and Enum.ItemClass and Enum.ItemClass.Weapon and Enum.ItemClass.Armor then
      isGear = (cID == Enum.ItemClass.Weapon or cID == Enum.ItemClass.Armor)
    else
      isGear = (cID == 2 or cID == 4)
    end
    if isGear and database.UpdateMaxItemLevel then
      database:UpdateMaxItemLevel(data.itemInfo.currentItemLevel)
    end
  end

  if data.itemInfo.isNewItem and self._newItemTimers[data.itemInfo.itemGUID] == nil then
    self._newItemTimers[data.itemInfo.itemGUID] = time()
  end

  data.itemLinkInfo = self:ParseItemLink(itemLink)
  data.itemHash = self:GenerateItemHash(data)
  data.forceClear = false
  data.stacks = 0
  data.stackedCount = data.itemInfo.currentItemCount
  return data
end

---@param itemID number
---@param data ItemData
function items:AttachBasicItemInfo(itemID, data)
  local getDetailedItemLevelInfo = C_Item and C_Item.GetDetailedItemLevelInfo or _G.GetDetailedItemLevelInfo
  local getItemInfo = C_Item and C_Item.GetItemInfo or _G.GetItemInfo
  local getItemIconByID = C_Item and C_Item.GetItemIconByID or _G.GetItemIconByID

  local effectiveIlvl, isPreview, baseIlvl
  if getDetailedItemLevelInfo then
    effectiveIlvl, isPreview, baseIlvl = getDetailedItemLevelInfo(itemID)
  end

  local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, expacID, setID, isCraftingReagent
  if getItemInfo then
    itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, expacID, setID, isCraftingReagent =
      getItemInfo(itemID)
  end

  itemName = itemName or ""
  itemLink = itemLink or ""
  itemQuality = itemQuality or const.ITEM_QUALITY.Common
  itemLevel = itemLevel or 0
  itemMinLevel = itemMinLevel or 0
  itemType = itemType or ""
  itemSubType = itemSubType or ""
  itemStackCount = itemStackCount or 1
  itemEquipLoc = itemEquipLoc or ""
  itemTexture = itemTexture or 134400
  sellPrice = sellPrice or 0
  classID = classID or 0
  subclassID = subclassID or 0
  bindType = bindType or 0
  expacID = expacID or 0
  setID = setID or 0
  isCraftingReagent = not not isCraftingReagent

  effectiveIlvl = effectiveIlvl or itemLevel or 0
  isPreview = not not isPreview
  baseIlvl = baseIlvl or itemLevel or 0

  local itemIcon = 134400
  if getItemIconByID then
    itemIcon = getItemIconByID(itemID) or 134400
  end

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
    itemIcon = itemIcon,
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

function items:GetCategory(ctx, data)
  return "Everything"
end

function items:ParseItemLink(link)
  local _, _, itemID, enchantID, gemID1, gemID2, gemID3, gemID4, suffixID, uniqueID, linkLevel, specializationID, modifiersMask, itemContext, rest =
    strsplit(":", link, 15) --[[@as string]]

  if not addon.isRetail then
    local _
    _, itemID, enchantID, gemID1, gemID2, gemID3, gemID4, suffixID, uniqueID, linkLevel, specializationID, modifiersMask, itemContext, rest =
      strsplit(":", link, 14) --[[@as string]]
  end

  local crafterGUID, extraEnchantID
  local numBonusIDs, bonusIDs
  local numModifiers, modifierIDs
  local relic1NumBonusIDs, relic1BonusIDs
  local relic2NumBonusIDs, relic2BonusIDs
  local relic3NumBonusIDs, relic3BonusIDs

  if rest ~= nil then
    numBonusIDs, rest = strsplit(":", rest, 2) --[[@as string]]

    if numBonusIDs ~= "" then
      local splits = (tonumber(numBonusIDs)) + 1
      bonusIDs = strsplittable(":", rest, splits)
      rest = table.remove(bonusIDs, splits)
    end

    numModifiers, rest = strsplit(":", rest, 2) --[[@as string]]
    if numModifiers ~= "" then
      local splits = (tonumber(numModifiers) * 2) + 1
      modifierIDs = strsplittable(":", rest, splits)
      rest = table.remove(modifierIDs, splits)
    end

    relic1NumBonusIDs, rest = strsplit(":", rest, 2) --[[@as string]]
    if relic1NumBonusIDs ~= "" then
      local splits = (tonumber(relic1NumBonusIDs)) + 1
      relic1BonusIDs = strsplittable(":", rest, splits)
      rest = table.remove(relic1BonusIDs, splits)
    end

    relic2NumBonusIDs, rest = strsplit(":", rest, 2) --[[@as string]]
    if relic2NumBonusIDs ~= "" then
      local splits = (tonumber(relic2NumBonusIDs)) + 1
      relic2BonusIDs = strsplittable(":", rest, (tonumber(relic2NumBonusIDs)) + 1)
      rest = table.remove(relic2BonusIDs, splits)
    end

    relic3NumBonusIDs, rest = strsplit(":", rest, 2) --[[@as string]]
    if relic3NumBonusIDs ~= "" then
      local splits = (tonumber(relic3NumBonusIDs)) + 1
      relic3BonusIDs = strsplittable(":", rest, (tonumber(relic3NumBonusIDs)) + 1)
      rest = table.remove(relic3BonusIDs, splits)
    end

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
    extraEnchantID = extraEnchantID or "",
  }
end

function items:GenerateItemHash(data)
  local stackOpts = database:GetStackingOptions(data.kind)
  local itemLinkInfo = data.itemLinkInfo or {}
  local bindingInfo = data.bindingInfo or {}
  local itemInfo = data.itemInfo or {}
  local transmogInfo = data.transmogInfo or {}

  local itemID = itemLinkInfo.itemID or 0
  local enchantID = itemLinkInfo.enchantID or ""
  local gemID1 = itemLinkInfo.gemID1 or ""
  local gemID2 = itemLinkInfo.gemID2 or ""
  local gemID3 = itemLinkInfo.gemID3 or ""
  local suffixID = itemLinkInfo.suffixID or ""
  local bonusIDs = table.concat(itemLinkInfo.bonusIDs or {}, ",")
  local relic1BonusIDs = table.concat(itemLinkInfo.relic1BonusIDs or {}, ",")
  local relic2BonusIDs = table.concat(itemLinkInfo.relic2BonusIDs or {}, ",")
  local relic3BonusIDs = table.concat(itemLinkInfo.relic3BonusIDs or {}, ",")
  local crafterGUID = itemLinkInfo.crafterGUID or ""
  local extraEnchantID = itemLinkInfo.extraEnchantID or ""
  local bindingVal = bindingInfo.binding or 0
  local currentItemLevel = itemInfo.currentItemLevel or 0

  local appearanceID = 0
  if stackOpts.dontMergeTransmog
    and transmogInfo.transmogInfoMixin
    and transmogInfo.transmogInfoMixin.appearanceID then
    appearanceID = transmogInfo.transmogInfoMixin.appearanceID
  end

  local hash = format(
    "%d%s%s%s%s%s%s%s%s%s%s%s%d%d%d",
    itemID,
    enchantID,
    gemID1,
    gemID2,
    gemID3,
    suffixID,
    bonusIDs,
    relic1BonusIDs,
    relic2BonusIDs,
    relic3BonusIDs,
    crafterGUID,
    extraEnchantID,
    bindingVal,
    currentItemLevel,
    appearanceID
  )
  return hash
end
