-- luacheck: ignore 212 211, globals SLASH_BETTERBAGS_DEBUGITEMS1 SlashCmdList
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule("Events")

---@class Constants: AceModule
local const = addon:GetModule("Constants")

---@class EquipmentSets: AceModule
local equipmentSets = addon:GetModule("EquipmentSets")

---@class Categories: AceModule
local categories = addon:GetModule("Categories")

---@class Database: AceModule
local database = addon:GetModule("Database")

---@class Context: AceModule
local context = addon:GetModule("Context")

---@class Search: AceModule
local search = addon:GetModule("Search")

---@class Localization: AceModule
local L = addon:GetModule("Localization")

---@class Binding: AceModule
local binding = addon:GetModule("Binding")

---@class Async: AceModule
local async = addon:GetModule("Async")

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

---@param name string
---@param func fun(data: ItemData): boolean
function items:RegisterUpgradeProvider(name, func)
  self.upgradeProviders = self.upgradeProviders or {}
  self.upgradeProviders[name] = func
end

---@param data ItemData
---@return boolean
function items:ResolveUpgrade(data)
  if not data or data.isItemEmpty then
    return false
  end
  local provider = database:GetUpgradeIconProvider()
  if provider == "None" then
    return false
  end
  self.upgradeProviders = self.upgradeProviders or {}
  local func = self.upgradeProviders[provider]
  if func then
    return func(data) or false
  end
  return false
end

---@param data ItemData
---@return integer
function items:ResolveItemContextMatchResult(data)
  local match = _G.ItemButtonUtil and _G.ItemButtonUtil.ItemContextMatchResult and _G.ItemButtonUtil.ItemContextMatchResult.Match or 1
  local mismatch = _G.ItemButtonUtil and _G.ItemButtonUtil.ItemContextMatchResult and _G.ItemButtonUtil.ItemContextMatchResult.Mismatch or 2
  local doesNotApply = _G.ItemButtonUtil and _G.ItemButtonUtil.ItemContextMatchResult and _G.ItemButtonUtil.ItemContextMatchResult.DoesNotApply or 0

  if not data or data.isItemEmpty or not data.bagid or not data.slotid then
    return doesNotApply
  end
  if not _G.ItemLocation or not _G.ItemButtonUtil or not _G.ItemButtonUtil.GetItemContextMatchResultForItem then
    return match
  end
  local itemLocation = _G.ItemLocation:CreateFromBagAndSlot(data.bagid, data.slotid)
  if itemLocation and type(itemLocation) == "table" and itemLocation.HasAnyLocation and itemLocation:HasAnyLocation() and itemLocation.IsBagAndSlot and itemLocation:IsBagAndSlot() and itemLocation.IsValid and itemLocation:IsValid() then
    local result = _G.ItemButtonUtil.GetItemContextMatchResultForItem(itemLocation)
    if not const.BACKPACK_BAGS[data.bagid] then
      return match
    end
    if result == match then
      return match
    end

    local accountBankStart = addon.isRetail and Enum and Enum.BagIndex and Enum.BagIndex.AccountBankTab_1 or const.BANK_TAB.ACCOUNT_BANK_1
    if
      addon.atBank
      and addon.Bags
      and addon.Bags.Bank
      and addon.Bags.Bank.bankTab
      and accountBankStart
      and addon.Bags.Bank.bankTab >= accountBankStart
    then
      if C_Bank and C_Bank.IsItemAllowedInBankType and not C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, itemLocation) then
        return mismatch
      else
        return match
      end
    end
    return result or match
  end
  return doesNotApply
end

-- BOOT STUBS & LEGACY PROTOTYPES
function items:Init()
  self.slotInfo = {}
  self.searchCache = {
    [const.BAG_KIND.BACKPACK] = {},
    [const.BAG_KIND.BANK] = {},
  }
  self.categoryPriorityCache = {
    [const.BAG_KIND.BACKPACK] = {},
    [const.BAG_KIND.BANK] = {},
  }
  self._newItemTimers = {
    [const.BAG_KIND.BACKPACK] = {},
    [const.BAG_KIND.BANK] = {},
  }
  self._preSort = false
  self._doingRefresh = false
  self._firstLoad = {
    [const.BAG_KIND.BACKPACK] = true,
    [const.BAG_KIND.BANK] = true,
  }
  self.equipmentCache = {}
  self.previousItemGUID = {}

  self.upgradeProviders = {}
  self:RegisterUpgradeProvider("BetterBags", function(data)
    if not data.inventorySlots or not C_Item.IsEquippableItem(data.itemInfo.itemLink) then
      return false
    end

    for _, slot in pairs(data.inventorySlots) do
      local equippedItem = self:GetItemDataFromInventorySlot(slot)
      -- If the item is an offhand and the mainhand is a 2H weapon, don't show upgrade.
      if slot == INVSLOT_OFFHAND then
        local mainhand = self:GetItemDataFromInventorySlot(INVSLOT_MAINHAND)
        if mainhand and (mainhand.itemInfo.itemEquipLoc == "INVTYPE_2HWEAPON" or mainhand.itemInfo.itemEquipLoc == "INVTYPE_RANGED") then
          return false
        end
      end

      if equippedItem and data.itemInfo.currentItemLevel > equippedItem.itemInfo.currentItemLevel then
        return true
      elseif equippedItem and equippedItem.isItemEmpty and slot >= INVSLOT_FIRST_EQUIPPED and slot <= INVSLOT_LAST_EQUIPPED then
        return true
      end
    end
    return false
  end)
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
  self:WipeSearchCache(const.BAG_KIND.BACKPACK)
  self:WipeSearchCache(const.BAG_KIND.BANK)
  self:ResetSlotInfo()
end

function items:ClearBankCache(ctx)
  self:WipeSearchCache(const.BAG_KIND.BANK)
  self:WipeSlotInfo(const.BAG_KIND.BANK)
end

function items:WipeAndRefreshAll(ctx)
  self:ClearItemCache(ctx)
end

function items:Restack(ctx, kind, callback)
  if callback then callback() end
end

-- Phase5_UpdateFreeSlots updates the current free slot count for a given bag kind.
---@param ctx Context
---@param kind BagKind
---@return table emptySlots, table emptySlotsByBag
function items:Phase5_UpdateFreeSlots(ctx, kind)
  local baglist
  local tab = ctx:Get("bagid")
  if kind == const.BAG_KIND.BANK then
    if addon.isRetail then
      baglist = {}
      for _, bag in pairs(const.BANK_BAGS) do
        baglist[bag] = bag
      end
      if const.ACCOUNT_BANK_BAGS then
        for _, bag in pairs(const.ACCOUNT_BANK_BAGS) do
          baglist[bag] = bag
        end
      end
    else
      local blizzardTab = addon.Bags and addon.Bags.Bank and addon.Bags.Bank.blizzardBankTab
      if tab == const.BANK_TAB.BANK then
        baglist = const.BANK_BAGS
      elseif const.ACCOUNT_BANK_BAGS and tab == const.BANK_TAB.ACCOUNT_BANK_1 then
        baglist = const.ACCOUNT_BANK_BAGS
      else
        baglist = { [tab] = tab }
      end
    end
  else
    baglist = const.BACKPACK_BAGS
  end

  local emptySlots = {}
  local emptySlotsByBag = {}

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
      emptySlots[name] = emptySlots[name] or 0
      emptySlots[name] = emptySlots[name] + freeSlots
      emptySlotsByBag[bagid] = { name = name, count = freeSlots }
    end
  end

  return emptySlots, emptySlotsByBag
end

---@param bagid number
---@return string
function items:GetBagName(bagid)
  local isBackpack = const.BACKPACK_BAGS[bagid] ~= nil
  if isBackpack then
    local isKeyring = Enum and Enum.BagIndex and Enum.BagIndex.Keyring and bagid == Enum.BagIndex.Keyring
    local bagname = isKeyring and L:G('Keyring') or C_Container.GetBagName(bagid)
    local displayid = isKeyring and 6 or bagid+1
    return string.format("#%d: %s", displayid, bagname or "Unknown")
  end

  local id = bagid
  if id == -1 then
    return string.format("#%d: %s", 1, L:G('Bank'))
  elseif id == -3 then
    return string.format("#%d: %s", 1, L:G('Reagent Bank'))
  else
    local bagname = C_Container.GetBagName(id)
    return string.format("#%d: %s", id - 4, bagname or L:G("Bank Bag"))
  end
end

-- CloneAsGap produces a frameless gap placeholder from a previous layout entry,
-- preserving the fields (bagid, itemInfo.category, itemHash) that downstream tab
-- partitioning and category tallying rely on, so the hole stays in the same
-- section/tab the departed item occupied.
---@param entry ItemData
---@return ItemData
local function CloneAsGap(entry)
  local gap = {}
  for k, v in pairs(entry) do
    gap[k] = v
  end
  gap.isItemGap = true
  gap.isFreeSlot = nil
  if not entry.isItemGap then
    gap.slotkey = "gap:" .. tostring(entry.slotkey)
  end
  return gap
end

local function ItemBelongsToTab(kind, item, tabID, viewBagView)
  if not item then return false end
  if viewBagView == const.BAG_VIEW.SECTION_ALL_BAGS then
    if kind == const.BAG_KIND.BANK then
      return item.bagid == tabID
    end
    return true
  end
  local category = item.itemInfo and item.itemInfo.category or L:G("Everything")
  if category == L:G("Free Space") or category == L:G("Recent Items") then
    return false
  end
  local groupsMod = addon:GetModule("Groups", true)
  if kind == const.BAG_KIND.BANK then
    if database.GetShowBankTabs and database:GetShowBankTabs() then
      if tabID == const.BANK_TAB.BANK then
        return const.ACCOUNT_BANK_BAGS == nil or const.ACCOUNT_BANK_BAGS[item.bagid] == nil
      else
        return item.bagid == tabID
      end
    end
    if groupsMod then
      local activeGroup = groupsMod:GetGroup(const.BAG_KIND.BANK, tabID)
      if activeGroup and addon.isRetail then
        local itemIsAccountBank = (const.ACCOUNT_BANK_BAGS and const.ACCOUNT_BANK_BAGS[item.bagid] ~= nil) or false
        local tabIsAccountBank = (Enum.BankType and activeGroup.bankType == Enum.BankType.Account) or false
        if itemIsAccountBank ~= tabIsAccountBank then
          return false
        end
      end
    end
  end
  if database.GetGroupsEnabled and database:GetGroupsEnabled(kind) and groupsMod then
    return groupsMod:CategoryBelongsToGroup(kind, category, tabID)
  end
  return true
end

local function IncludeBagInFreeSpace(kind, bagid, tabID)
  if kind == const.BAG_KIND.BACKPACK then
    return const.BACKPACK_BAGS[bagid] ~= nil
  end
  if database.GetShowBankTabs and database:GetShowBankTabs() then
    local viewBagView = database.GetBagView and database:GetBagView(kind) or const.BAG_VIEW.SECTION_GRID
    if viewBagView == const.BAG_VIEW.SECTION_ALL_BAGS then
      return bagid == tabID
    end
    if addon.isRetail then
      if tabID == const.BANK_TAB.BANK then
        return const.ACCOUNT_BANK_BAGS == nil or const.ACCOUNT_BANK_BAGS[bagid] == nil
      else
        return bagid == tabID
      end
    else
      return const.BANK_BAGS[bagid] ~= nil or bagid == -1
    end
  end
  if database.GetGroupsEnabled and database:GetGroupsEnabled(const.BAG_KIND.BANK) and addon.isRetail then
    local groupsMod = addon:GetModule("Groups", true)
    if groupsMod then
      local activeGroup = groupsMod:GetGroup(const.BAG_KIND.BANK, tabID)
      if activeGroup then
        local itemIsAccountBank = (const.ACCOUNT_BANK_BAGS and const.ACCOUNT_BANK_BAGS[bagid] ~= nil) or false
        local tabIsAccountBank = (Enum.BankType and activeGroup.bankType == Enum.BankType.Account) or false
        return itemIsAccountBank == tabIsAccountBank
      end
    end
  end
  return const.ACCOUNT_BANK_BAGS == nil or const.ACCOUNT_BANK_BAGS[bagid] == nil
end

local function GetPossibleTabIDs(kind)
  local tabs = {}
  local groupsMod = addon:GetModule("Groups", true)
  if kind == const.BAG_KIND.BACKPACK then
    if database.GetGroupsEnabled and database:GetGroupsEnabled(kind) and groupsMod and groupsMod.GetAllGroups then
      for _, group in pairs(groupsMod:GetAllGroups(kind)) do
        tabs[group.id] = true
      end
    else
      tabs[1] = true
    end
  elseif kind == const.BAG_KIND.BANK then
    if database.GetShowBankTabs and database:GetShowBankTabs() then
      tabs[const.BANK_TAB.BANK] = true
      if const.BANK_BAGS then
        for _, bag in pairs(const.BANK_BAGS) do
          tabs[bag] = true
        end
      end
      if addon.isRetail and const.ACCOUNT_BANK_BAGS then
        for _, bag in pairs(const.ACCOUNT_BANK_BAGS) do
          tabs[bag] = true
        end
      end
    elseif database.GetGroupsEnabled and database:GetGroupsEnabled(kind) and groupsMod and groupsMod.GetAllGroups then
      for _, group in pairs(groupsMod:GetAllGroups(kind)) do
        tabs[group.id] = true
      end
    else
      local activeGroup = database.GetActiveGroup and database:GetActiveGroup(kind) or 1
      tabs[activeGroup] = true
      tabs[1] = true
    end
  end
  return tabs
end

--- CENTRALIZED PIPELINE REFRESH ORCHESTRATOR (PHASES 1-5)
---@param ctx Context
---@param kind BagKind
function items:Phase1_DetermineBags(ctx, kind)
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

  local targetedBags = ctx:Get("targetedBags")
  if targetedBags and not ctx:Get("wipe") then
    local filteredBagList = {}
    for bagID in pairs(bagList) do
      if targetedBags[bagID] then
        filteredBagList[bagID] = bagList[bagID]
      end
    end
    return filteredBagList
  end

  return bagList
end

function items:Phase2_Harvest(kind, bagList)
  return self:Harvest(kind, bagList, kind == const.BAG_KIND.BACKPACK)
end

function items:Phase6_EnrichData(ctx, kind, itemData)
  local emptySlotByBagAndSlot = {}
  local freeSlotKeys = {}
  local freeSlotKeysByBag = {}
  local emptySlotsSorted = {}
  local totalItems = 0

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

    if currentItem.isItemEmpty then
      currentItem.itemInfo = currentItem.itemInfo or {}
      currentItem.itemInfo.emptySlotName = name
      local quality
      if baglink ~= nil and invid ~= nil then
        local class, subclass = select(6, C_Item.GetItemInfoInstant(baglink))
        if class == Enum.ItemClass.Quiver then
          quality = const.BAG_SUBTYPE_TO_QUALITY[99]
        else
          quality = const.BAG_SUBTYPE_TO_QUALITY[subclass]
        end
      else
        quality = const.BAG_SUBTYPE_TO_QUALITY[0]
      end
      currentItem.itemInfo.itemQuality = quality or const.ITEM_QUALITY.Common
    end

    if currentItem.isItemEmpty then
      emptySlotByBagAndSlot[currentItem.bagid] = emptySlotByBagAndSlot[currentItem.bagid] or {}
      emptySlotByBagAndSlot[currentItem.bagid][currentItem.slotid] = currentItem
      freeSlotKeys[name] = currentItem.slotkey
      freeSlotKeysByBag[currentItem.bagid] = currentItem.slotkey
      table.insert(emptySlotsSorted, currentItem)
    else
      totalItems = totalItems + 1
    end

    currentItem.itemInfo.category = self:GetCategory(ctx, currentItem)
    currentItem.isUpgrade = self:ResolveUpgrade(currentItem)
    currentItem.itemContextMatchResult = self:ResolveItemContextMatchResult(currentItem)
  end

  table.sort(emptySlotsSorted, function(a, b)
    if a.bagid == b.bagid then
      return a.slotid < b.slotid
    end
    return a.bagid < b.bagid
  end)

  return emptySlotByBagAndSlot, freeSlotKeys, freeSlotKeysByBag, emptySlotsSorted, totalItems
end

function items:Phase4_ClearMovedItemGlows(ctx, previousItems, itemData)
  local added = {}
  local removed = {}

  for slotkey, newItem in pairs(itemData) do
    local oldItem = previousItems[slotkey]
    if not newItem.isItemEmpty then
      if not oldItem or oldItem.isItemEmpty then
        added[slotkey] = newItem
      end
    end
  end

  for slotkey, oldItem in pairs(previousItems) do
    local newItem = itemData[slotkey]
    if not oldItem.isItemEmpty then
      if not newItem or newItem.isItemEmpty then
        removed[slotkey] = oldItem
      end
    end
  end

  for _, addedItem in pairs(added) do
    for _, removedItem in pairs(removed) do
      if addedItem.itemInfo and removedItem.itemInfo and addedItem.itemInfo.itemGUID == removedItem.itemInfo.itemGUID then
        self:ClearNewItemFromData(ctx, addedItem)
      end
    end
  end
end

function items:Phase7_ApplyVirtualStacks(kind, itemData)
  local stacks = addon:GetModule("Stacks")
  local stackData = stacks:Create()
  for _, item in pairs(itemData) do
    if not item.isItemEmpty then
      stackData:AddToStack(item, itemData)
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

  local visibleItemsBySlotKey = {}
  for slotkey, item in pairs(itemData) do
    if not item.isItemEmpty then
      local stackInfo = stackData:GetStackInfo(item.itemHash)
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
        visibleItemsBySlotKey[slotkey] = item
      end
    end
  end

  return visibleItemsBySlotKey, stackData
end

function items:Phase8_EnrichCategories(ctx, kind, itemData, emptySlotByBagAndSlot)
  if search and search.IndexItems then
    -- The search index is a single, global structure shared by the backpack and the
    -- bank, and IndexItems is a clean sweep (search:Wipe then re-add). Indexing only
    -- this kind's items would therefore evict the other bag from the index. A full
    -- refresh processes the bank first and the backpack second (data/refresh.lua), so
    -- the backpack would overwrite the bank's entries and the live bank search box
    -- (frames/search.lua -> search:Search) would match nothing, filtering out every
    -- bank item. Rebuild from the complete cross-kind model instead: this kind's fresh
    -- items unioned with the other kind's last-committed items.
    local otherKind = (kind == const.BAG_KIND.BANK) and const.BAG_KIND.BACKPACK or const.BAG_KIND.BANK
    local combinedItems = {}
    local otherSlotInfo = self.slotInfo and self.slotInfo[otherKind]
    if otherSlotInfo and otherSlotInfo.itemsBySlotKey then
      for slotkey, item in pairs(otherSlotInfo.itemsBySlotKey) do
        combinedItems[slotkey] = item
      end
    end
    for slotkey, item in pairs(itemData) do
      combinedItems[slotkey] = item
    end
    search:IndexItems(combinedItems)
  end

  self:RefreshSearchCache(kind, itemData)

  -- Phase 6 resolved categories against the previous sweep's search cache. Resolve
  -- again now that the cache reflects this sweep, so search categories compete with
  -- custom categories, gear sets and recent items by the priority rules in GetCategory.
  for _, currentItem in pairs(itemData) do
    if not currentItem.isItemEmpty then
      local oldCategory = currentItem.itemInfo.category
      local newCategory = self:GetCategory(ctx, currentItem)
      if newCategory ~= oldCategory then
        currentItem.itemInfo.category = newCategory
        if search.UpdateCategoryIndex then
          search:UpdateCategoryIndex(currentItem, oldCategory)
        end
      end
    end
  end

  local searchBox = addon:GetModule("SearchBox", true)
  local searchQuery = searchBox and searchBox.GetText and searchBox:GetText()
  local searchResults = nil
  if searchQuery and searchQuery ~= "" and search and search.Search then
    searchResults = search:Search(searchQuery)
  end
  for _, currentItem in pairs(itemData) do
    if searchResults then
      currentItem.isSearchResult = searchResults[currentItem.slotkey] or false
    else
      currentItem.isSearchResult = nil
    end
  end

  local sectionLayouts = {}
  if database.GetBagView and database:GetBagView(kind) == const.BAG_VIEW.SECTION_ALL_BAGS then
    local shouldHideHeader = (kind == const.BAG_KIND.BANK)
    for _, currentItem in pairs(itemData) do
      if not currentItem.isItemEmpty then
        local category = self:GetBagName(currentItem.bagid)
        currentItem.itemInfo.category = category
        sectionLayouts[category] = { hideHeader = shouldHideHeader, sortMode = "physical" }
      end
    end
    for bagid, _ in pairs(emptySlotByBagAndSlot) do
      local category = self:GetBagName(bagid)
      sectionLayouts[category] = { hideHeader = shouldHideHeader, sortMode = "physical" }
    end
  end

  return sectionLayouts
end

-- IsBagOpen reports whether the bag window for `kind` is currently visible.
-- Gaps only accrue while the user is looking at the bag; a sweep that runs while
-- the bag is hidden (the on-close redraw, or consuming items with bags closed)
-- rebuilds a fresh, gapless layout instead.
---@param kind BagKind
---@return boolean
function items:IsBagOpen(kind)
  local bag = addon.Bags and (kind == const.BAG_KIND.BANK and addon.Bags.Bank or addon.Bags.Backpack)
  if not bag or not bag.frame or not bag.frame.IsShown then
    return false
  end
  return bag.frame:IsShown() and true or false
end

-- MarkDrawOnClose flags the bag so that closing it triggers a refresh which,
-- because the frame is then hidden, rebuilds a gapless layout.
---@param kind BagKind
function items:MarkDrawOnClose(kind)
  local bag = addon.Bags and (kind == const.BAG_KIND.BANK and addon.Bags.Bank or addon.Bags.Backpack)
  if bag then
    bag.drawOnClose = true
  end
end

-- BuildOrderedItems computes the ordered item list for a sweep, holding a
-- persistent empty gap wherever a displayed icon has left the bag, by diffing the
-- previously committed layout (previousSortedItems) against this sweep's displayed
-- items (visibleItemsBySlotKey). Falls back to a fresh attribute sort (Phase9_Sort)
-- for the physical bag view, when the feature is off, on an explicit reset, when the
-- bag is closed, or when there is no previous layout to diff against.
---@param ctx Context
---@param kind BagKind
---@param visibleItemsBySlotKey table<string, ItemData>
---@param emptySlotByBagAndSlot table
---@param previousSortedItems ItemData[]
---@return ItemData[]
function items:BuildOrderedItems(ctx, kind, visibleItemsBySlotKey, emptySlotByBagAndSlot, previousSortedItems)
  local view = database.GetBagView and database:GetBagView(kind) or const.BAG_VIEW.SECTION_GRID
  if view == const.BAG_VIEW.SECTION_ALL_BAGS then
    return self:Phase9_Sort(kind, visibleItemsBySlotKey, emptySlotByBagAndSlot)
  end

  local enabled = database.GetPreserveItemGaps and database:GetPreserveItemGaps(kind) or false
  local reset = ctx and ctx:Get("resetLayout") == true
  local havePrevious = previousSortedItems ~= nil and next(previousSortedItems) ~= nil

  if (not enabled) or reset or (not self:IsBagOpen(kind)) or (not havePrevious) then
    return self:Phase9_Sort(kind, visibleItemsBySlotKey, emptySlotByBagAndSlot)
  end

  -- Bucket previous real entries and current displayed items by stack identity.
  local prevByHash = {}
  for _, entry in ipairs(previousSortedItems) do
    if not entry.isItemGap and not entry.isFreeSlot and entry.itemHash then
      prevByHash[entry.itemHash] = prevByHash[entry.itemHash] or {}
      table.insert(prevByHash[entry.itemHash], entry)
    end
  end

  local curByHash = {}
  for slotkey, item in pairs(visibleItemsBySlotKey) do
    if item.itemHash then
      curByHash[item.itemHash] = curByHash[item.itemHash] or {}
      curByHash[item.itemHash][slotkey] = item
    end
  end

  local action = {}   -- prevEntry table -> { keep = ItemData } or { gap = true }
  local usedCur = {}  -- current slotkey -> true

  for h, prevs in pairs(prevByHash) do
    local cur = curByHash[h] or {}
    -- Pass 1: same slotkey survives in place.
    for _, p in ipairs(prevs) do
      if cur[p.slotkey] and not usedCur[p.slotkey] then
        action[p] = { keep = cur[p.slotkey] }
        usedCur[p.slotkey] = true
      end
    end
    -- Pass 2: remaining current items of this hash fill remaining prev slots
    -- (a move or virtual-stack re-root keeps its position; no gap).
    local remaining = {}
    for slotkey in pairs(cur) do
      if not usedCur[slotkey] then
        table.insert(remaining, slotkey)
      end
    end
    table.sort(remaining)
    local ri = 1
    for _, p in ipairs(prevs) do
      if not action[p] then
        if ri <= #remaining then
          local sk = remaining[ri]
          action[p] = { keep = cur[sk] }
          usedCur[sk] = true
          ri = ri + 1
        else
          action[p] = { gap = true }
        end
      end
    end
  end

  -- Emit in the previous layout's order, holding gaps in place.
  local result = {}
  local emittedGap = false
  for _, entry in ipairs(previousSortedItems) do
    if entry.isItemGap then
      table.insert(result, CloneAsGap(entry))
      emittedGap = true
    elseif not entry.isFreeSlot then
      local a = action[entry]
      if a and a.keep then
        table.insert(result, a.keep)
      else
        table.insert(result, CloneAsGap(entry))
        emittedGap = true
      end
    end
  end

  -- Append genuinely new displayed items in fresh sort order.
  local newItems = {}
  for slotkey, item in pairs(visibleItemsBySlotKey) do
    if not usedCur[slotkey] then
      table.insert(newItems, item)
    end
  end
  local sortModule = addon:GetModule("Sort", true)
  if sortModule and sortModule.GetItemDataSortFunction then
    local sortFunc = sortModule:GetItemDataSortFunction(kind, view)
    if sortFunc then
      table.sort(newItems, sortFunc)
    end
  end
  for _, item in ipairs(newItems) do
    table.insert(result, item)
  end

  if emittedGap then
    self:MarkDrawOnClose(kind)
  end

  return result
end

function items:Phase9_Sort(kind, visibleItemsBySlotKey, emptySlotByBagAndSlot)
  local sortedItems = {}
  for _, item in pairs(visibleItemsBySlotKey) do
    table.insert(sortedItems, item)
  end

  if database.GetBagView and database:GetBagView(kind) == const.BAG_VIEW.SECTION_ALL_BAGS then
    for bagid, emptyBagData in pairs(emptySlotByBagAndSlot) do
      for slotid, data in pairs(emptyBagData) do
        if C_Container.GetBagName(bagid) ~= nil or (addon.isRetail and const.ACCOUNT_BANK_BAGS and const.ACCOUNT_BANK_BAGS[bagid]) then
          local category = self:GetBagName(bagid)
          local dummy = {
            isFreeSlot = true,
            bagid = bagid,
            slotid = slotid,
            slotkey = data.slotkey or (bagid .. "_" .. slotid),
            itemInfo = {
              category = category,
              itemName = "",
              itemQuality = -1,
              currentItemCount = 0,
              itemGUID = "",
              currentItemLevel = 0,
              expacID = 0
            }
          }
          table.insert(sortedItems, dummy)
        end
      end
    end
  end

  local sortModule = addon:GetModule("Sort", true)
  if sortModule then
    local sortFunc
    if database.GetBagView and database:GetBagView(kind) == const.BAG_VIEW.SECTION_ALL_BAGS then
      sortFunc = sortModule.SortItemDataBySlot
    elseif sortModule.GetItemDataSortFunction then
      sortFunc = sortModule:GetItemDataSortFunction(kind, database:GetBagView(kind))
    end

    if sortFunc then
      table.sort(sortedItems, sortFunc)
    end
  end

  return sortedItems
end

function items:Phase10_PartitionIntoTabs(ctx, kind, sortedItems, emptySlotsSorted, emptySlotsByBag, freeSlotKeysByBag, itemData)
  local tabs = {}
  local viewBagView = database.GetBagView and database:GetBagView(kind) or const.BAG_VIEW.SECTION_GRID
  local possibleTabs = GetPossibleTabIDs(kind)

  -- Get active tab ID
  local activeTabID = 1
  if kind == const.BAG_KIND.BACKPACK then
    if database.GetGroupsEnabled and database:GetGroupsEnabled(kind) then
      activeTabID = database.GetActiveGroup and database:GetActiveGroup(kind) or 1
    end
  elseif kind == const.BAG_KIND.BANK then
    if database.GetShowBankTabs and database:GetShowBankTabs() then
      activeTabID = const.BANK_TAB.BANK
    elseif database.GetGroupsEnabled and database:GetGroupsEnabled(kind) then
      activeTabID = database.GetActiveGroup and database:GetActiveGroup(kind) or 1
    end
  end

  possibleTabs[activeTabID] = true
  possibleTabs[1] = true -- fallback

  local showAll = database:GetShowAllFreeSpace(kind)

  for tabID in pairs(possibleTabs) do
    tabs[tabID] = {
      items = {},
      categories = {},
      emptySlotsSorted = {},
      emptySlotsByBag = {},
      emptySlots = {},
      totalItems = 0,
      freeSpace = {
        showAll = showAll,
        buttons = {},
      },
    }

    -- Filter emptySlotsSorted and emptySlotsByBag for this tab
    for _, item in ipairs(emptySlotsSorted or {}) do
      if IncludeBagInFreeSpace(kind, item.bagid, tabID) then
        table.insert(tabs[tabID].emptySlotsSorted, item)
      end
    end

    if emptySlotsByBag then
      for bagid, info in pairs(emptySlotsByBag) do
        if IncludeBagInFreeSpace(kind, bagid, tabID) then
          tabs[tabID].emptySlotsByBag[bagid] = { name = info.name, count = info.count }
          tabs[tabID].emptySlots[info.name] = (tabs[tabID].emptySlots[info.name] or 0) + info.count
        end
      end
    end

    -- Populate tabData.freeSpace.buttons
    if showAll then
      for _, item in ipairs(tabs[tabID].emptySlotsSorted) do
        table.insert(tabs[tabID].freeSpace.buttons, {
          slotkey = item.slotkey,
          bagid = item.bagid,
          slotid = item.slotid,
          count = 1,
          isIndividual = true,
          key = item.slotkey,
          itemInfo = item.itemInfo,
        })
      end
    else
      local aggregatedCounts = {}
      local firstSlotKeyForSubclass = {}
      for bagid, info in pairs(tabs[tabID].emptySlotsByBag) do
        aggregatedCounts[info.name] = (aggregatedCounts[info.name] or 0) + info.count
        if not firstSlotKeyForSubclass[info.name] and freeSlotKeysByBag and freeSlotKeysByBag[bagid] then
          firstSlotKeyForSubclass[info.name] = freeSlotKeysByBag[bagid]
        end
      end

      local sortedSubclasses = {}
      for name in pairs(aggregatedCounts) do
        table.insert(sortedSubclasses, name)
      end
      table.sort(sortedSubclasses)

      for _, name in ipairs(sortedSubclasses) do
        local freeSlotCount = aggregatedCounts[name]
        local slotKey = firstSlotKeyForSubclass[name]
        if freeSlotCount > 0 and slotKey ~= nil then
          local freeSlotBag, freeSlotID = slotKey:match("^(%-?%d+)_(%d+)$")
          if freeSlotBag and freeSlotID then
            local originalItem = itemData[slotKey]
            table.insert(tabs[tabID].freeSpace.buttons, {
              slotkey = slotKey,
              bagid = tonumber(freeSlotBag),
              slotid = tonumber(freeSlotID),
              count = freeSlotCount,
              isIndividual = false,
              key = name,
              itemInfo = originalItem and originalItem.itemInfo or {
                emptySlotName = name,
                itemQuality = const.ITEM_QUALITY.Common,
              },
            })
          end
        end
      end
    end
  end

  -- Filter and assign items to their respective tabs
  for _, item in ipairs(sortedItems) do
    local category = item.itemInfo and item.itemInfo.category or L:G("Everything")
    local isShown = true
    if viewBagView ~= const.BAG_VIEW.SECTION_ALL_BAGS and categories.IsCategoryShown then
      isShown = categories:IsCategoryShown(category) ~= false
    end
    if isShown then
      for tabID, tabData in pairs(tabs) do
        if ItemBelongsToTab(kind, item, tabID, viewBagView) then
          table.insert(tabData.items, item)
          if not item.isFreeSlot and not item.isItemGap then
            tabData.totalItems = tabData.totalItems + 1
          end
        end
      end
    end
  end

  local sortModule = addon:GetModule("Sort", true)

  -- Sort categories for each tab
  for _, tabData in pairs(tabs) do
    local categoryTally = {}
    local categoryOrder = {}
    for _, item in ipairs(tabData.items) do
      local category = item.itemInfo and item.itemInfo.category or L:G("Everything")
      if not categoryTally[category] then
        categoryTally[category] = {
          name = category,
          count = 0,
          isFreeSpace = (category == L:G("Free Space")),
          isRecent = (category == L:G("Recent Items")),
          fillWidth = false,
          shown = (not categories.IsCategoryShown) or (categories:IsCategoryShown(category) ~= false),
        }
        table.insert(categoryOrder, categoryTally[category])
      end
      categoryTally[category].count = categoryTally[category].count + 1
    end

    local isAllBags = database.GetBagView and database:GetBagView(kind) == const.BAG_VIEW.SECTION_ALL_BAGS
    if not isAllBags and sortModule and sortModule.GetCategoryDataSortFunction then
      local sortFunc = sortModule:GetCategoryDataSortFunction(kind, database:GetBagView(kind))
      if sortFunc then
        table.sort(categoryOrder, sortFunc)
      end
    end
    tabData.categories = categoryOrder
  end

  return tabs
end

function items:Phase11_CommitAndDispatch(ctx, kind, itemData, equipmentData, previousItems, previousTotalItems, emptySlots, emptySlotsByBag, emptySlotByBagAndSlot, totalItems, emptySlotsSorted, freeSlotKeys, freeSlotKeysByBag, visibleItemsBySlotKey, stackData, sectionLayouts, sortedItems, tabData)
  local realSlotInfo = self.slotInfo[kind]
  if not realSlotInfo then
    self:WipeSlotInfo(kind)
    realSlotInfo = self.slotInfo[kind]
  end

  if kind == const.BAG_KIND.BACKPACK then
    self.equipmentCache = equipmentData
  end

  -- Atomic state commitment
  realSlotInfo.emptySlots = emptySlots
  realSlotInfo.freeSlotKeys = freeSlotKeys
  realSlotInfo.freeSlotKeysByBag = freeSlotKeysByBag
  realSlotInfo.emptySlotsByBag = emptySlotsByBag
  realSlotInfo.totalItems = totalItems
  realSlotInfo.previousTotalItems = previousTotalItems
  realSlotInfo.emptySlotByBagAndSlot = emptySlotByBagAndSlot
  realSlotInfo.deferDelete = false
  realSlotInfo.dirtyItems = {}
  realSlotInfo.itemsBySlotKey = itemData
  realSlotInfo.previousItemsBySlotKey = previousItems
  realSlotInfo.addedItems = {}
  realSlotInfo.removedItems = {}
  realSlotInfo.updatedItems = {}
  realSlotInfo.emptySlotsSorted = emptySlotsSorted
  realSlotInfo.stacks = stackData

  -- Set final computed fields on realSlotInfo
  realSlotInfo.visibleItemsBySlotKey = visibleItemsBySlotKey
  realSlotInfo.sectionLayouts = sectionLayouts
  realSlotInfo.sortedItems = sortedItems
  realSlotInfo.tabs = tabData

  -- Synthesize Category Data
  local categoryTally = {}
  local categoryOrder = {}
  for _, item in ipairs(realSlotInfo.sortedItems) do
    local category = item.itemInfo and item.itemInfo.category or L:G("Everything")
    if not categoryTally[category] then
      categoryTally[category] = {
        name = category,
        count = 0,
        isFreeSpace = (category == L:G("Free Space")),
        isRecent = (category == L:G("Recent Items")),
        fillWidth = false
      }
      table.insert(categoryOrder, categoryTally[category])
    end
    categoryTally[category].count = categoryTally[category].count + 1
  end

  local isAllBags = database.GetBagView and database:GetBagView(kind) == const.BAG_VIEW.SECTION_ALL_BAGS
  local sortModule = addon:GetModule("Sort", true)
  if not isAllBags and sortModule and sortModule.GetCategoryDataSortFunction then
    local sortFunc = sortModule:GetCategoryDataSortFunction(kind, database:GetBagView(kind))
    if sortFunc then
      table.sort(categoryOrder, sortFunc)
    end
  end
  realSlotInfo.sortedCategories = categoryOrder

  local ev = kind == const.BAG_KIND.BANK and "items/RefreshBank/Done" or "items/RefreshBackpack/Done"
  events:SendMessage(ctx, ev, realSlotInfo)
end

function items:Phase3_ExtractPreviousState(kind)
  local realSlotInfo = self.slotInfo[kind]
  local previousItems = realSlotInfo and realSlotInfo.itemsBySlotKey or {}
  local previousTotalItems = realSlotInfo and realSlotInfo.totalItems or 0
  local previousSortedItems = realSlotInfo and realSlotInfo.sortedItems or {}
  return previousItems, previousTotalItems, previousSortedItems
end

function items:ProcessRefresh(ctx, kind)
  async:Do(ctx, function(ectx)
    local bagList = self:Phase1_DetermineBags(ectx, kind)
    local itemData, equipmentData = self:Phase2_Harvest(kind, bagList)

    -- The harvest captured this frame's client state. Everything below runs on the
    -- next frame against the state committed by then, so refreshes started in the
    -- same frame merge in order instead of overwriting each other's bags.
    async:Yield()

    if self._firstLoad[kind] == true then
      self._firstLoad[kind] = false
      ectx:Set("wipe", true)
    end

    local previousItems, previousTotalItems, previousSortedItems = self:Phase3_ExtractPreviousState(kind)

    local targetedBags = ectx:Get("targetedBags")
    local isWipe = ectx:Get("wipe") == true

    if targetedBags and not isWipe then
      local harvestedData = itemData
      itemData = {}
      for slotkey, item in pairs(previousItems) do
        local bagid = item.bagid or tonumber((strsplit("_", slotkey)))
        if not targetedBags[bagid] then
          itemData[slotkey] = item
        end
      end
      for slotkey, item in pairs(harvestedData) do
        itemData[slotkey] = item
      end
    end

    self:Phase4_ClearMovedItemGlows(ectx, previousItems, itemData)

    local emptySlots, emptySlotsByBag = self:Phase5_UpdateFreeSlots(ectx, kind)

    local emptySlotByBagAndSlot, freeSlotKeys, freeSlotKeysByBag, emptySlotsSorted, totalItems = self:Phase6_EnrichData(ectx, kind, itemData)

    local visibleItemsBySlotKey, stackData = self:Phase7_ApplyVirtualStacks(kind, itemData)
    local sectionLayouts = self:Phase8_EnrichCategories(ectx, kind, itemData, emptySlotByBagAndSlot)
    local sortedItems = self:BuildOrderedItems(ectx, kind, visibleItemsBySlotKey, emptySlotByBagAndSlot, previousSortedItems)
    local tabData = self:Phase10_PartitionIntoTabs(ectx, kind, sortedItems, emptySlotsSorted, emptySlotsByBag, freeSlotKeysByBag, itemData)

    self:Phase11_CommitAndDispatch(ectx, kind, itemData, equipmentData, previousItems, previousTotalItems, emptySlots, emptySlotsByBag, emptySlotByBagAndSlot, totalItems, emptySlotsSorted, freeSlotKeys, freeSlotKeysByBag, visibleItemsBySlotKey, stackData, sectionLayouts, sortedItems, tabData)
  end)
end

function items:RefreshBackpack(ctx)
  self:ProcessRefresh(ctx, const.BAG_KIND.BACKPACK)
end

function items:RefreshBank(ctx)
  self:ProcessRefresh(ctx, const.BAG_KIND.BANK)
end

function items:GetSearchCategory(kind, slotkey)
  return self.searchCache[kind] and self.searchCache[kind][slotkey]
end

function items:WipeSearchCache(kind)
  if not self.searchCache or not self.categoryPriorityCache then return end
  if self.searchCache[kind] then wipe(self.searchCache[kind]) end
  if self.categoryPriorityCache[kind] then wipe(self.categoryPriorityCache[kind]) end
end

function items:RefreshSearchCache(kind, itemData)
  itemData = itemData or (self.slotInfo[kind] and self.slotInfo[kind].itemsBySlotKey) or {}
  self:WipeSearchCache(kind)
  if not categories or not categories.GetSortedSearchCategories then return end
  local ctx = context:New('RefreshSearchCache')
  local categoryTable = categories:GetSortedSearchCategories()
  local createdGroupByCategories = {} -- Track created groupBy categories to avoid duplicates

  for _, categoryFilter in ipairs(categoryTable) do
    if categoryFilter.enabled[kind] then
      local results = search:Search(categoryFilter.searchCategory.query)
      local groupBy = categoryFilter.searchCategory.groupBy or const.SEARCH_CATEGORY_GROUP_BY.NONE
      local priority = categoryFilter.priority or 10

      for slotkey, match in pairs(results) do
        if match then
          local categoryName = categoryFilter.name

          -- Apply groupBy logic to generate dynamic category name
          if groupBy ~= const.SEARCH_CATEGORY_GROUP_BY.NONE then
            local currentItem = itemData[slotkey]
            if currentItem and not currentItem.isItemEmpty then
              local suffix = self:GetGroupBySuffix(currentItem, groupBy)
              if suffix and suffix ~= "" then
                categoryName = categoryFilter.name .. " - " .. suffix

                -- Create the groupBy subcategory object if it doesn't exist yet
                if not createdGroupByCategories[categoryName] and not categories:DoesCategoryExist(categoryName) then
                  categories:CreateCategory(ctx, {
                    name = categoryName,
                    itemList = {},
                    enabled = categoryFilter.enabled,
                    dynamic = true,
                    isGroupBySubcategory = true,
                    groupByParent = categoryFilter.name,
                    priority = priority,
                    color = categoryFilter.color,
                  })
                  createdGroupByCategories[categoryName] = true
                end
              end
            end
          end

          -- Only set if this is higher priority than existing entry
          -- Lower priority numbers have higher priority (1 > 10)
          local existingPriority = self.categoryPriorityCache[kind][slotkey]
          if not existingPriority or priority < existingPriority then
            self.searchCache[kind][slotkey] = categoryName
            self.categoryPriorityCache[kind][slotkey] = priority
          end
        end
      end
    end
  end
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
  local container = ContinuableContainer:Create()
  for _, itemID in pairs(itemList) do
    local itemMixin = Item:CreateFromItemID(itemID)
    container:AddContinuable(itemMixin)
  end
  container:ContinueOnLoad(function()
    ---@type ItemData[]
    local dataList = {}
    for _, itemID in pairs(itemList) do
      local data = {} ---@type ItemData
      self:AttachBasicItemInfo(itemID, data)
      table.insert(dataList, data)
    end
    if callback then callback(ctx, dataList) end
  end)
end

local function resolveKind(self, data)
  if data and data.kind then
    return data.kind
  end
  if data and data.bagid then
    return self:GetBagKindFromBagID(data.bagid)
  end
  return const.BAG_KIND.BACKPACK
end

function items:IsNewItem(data)
  if not data or data.isItemEmpty then return false end
  if _G.C_NewItems and _G.C_NewItems.IsNewItem then
    if _G.C_NewItems.IsNewItem(data.bagid, data.slotid) then
      return true
    end
  end
  local guid = data.itemInfo and data.itemInfo.itemGUID
  if guid then
    local kind = resolveKind(self, data)
    local timerTable = self._newItemTimers and self._newItemTimers[kind]
    if timerTable and timerTable[guid] then
      local diff = time() - timerTable[guid]
      local limit = database:GetNewItemTime() or 30
      return diff < limit
    end
  end
  return false
end

function items:ClearNewItem(ctx, slotkey)
  if not slotkey then
    return
  end
  self:ClearNewItemFromData(ctx, self:GetItemDataFromSlotKey(slotkey))
end

---@param ctx Context
---@param data ItemData?
function items:ClearNewItemFromData(ctx, data)
  if not data or data.isItemEmpty then
    return
  end
  if _G.C_NewItems and _G.C_NewItems.RemoveNewItem then
    _G.C_NewItems.RemoveNewItem(data.bagid, data.slotid)
  end
  data.itemInfo.isNewItem = false
  local kind = resolveKind(self, data)
  if self._newItemTimers and self._newItemTimers[kind] and data.itemInfo and data.itemInfo.itemGUID then
    self._newItemTimers[kind][data.itemInfo.itemGUID] = nil
  end
  data.itemInfo.category = self:GetCategory(ctx, data)
end

function items:ClearNewItems(kind)
  if kind == const.BAG_KIND.BACKPACK then
    if self._newItemTimers and self._newItemTimers[const.BAG_KIND.BACKPACK] then
      wipe(self._newItemTimers[const.BAG_KIND.BACKPACK])
    end
    if _G.C_NewItems and _G.C_NewItems.RemoveNewItem then
      for bagID in pairs(const.BACKPACK_BAGS) do
        local numSlots = _G.C_Container and _G.C_Container.GetContainerNumSlots and _G.C_Container.GetContainerNumSlots(bagID) or 0
        for slotID = 1, numSlots do
          if _G.C_NewItems.IsNewItem and _G.C_NewItems.IsNewItem(bagID, slotID) then
            _G.C_NewItems.RemoveNewItem(bagID, slotID)
          end
        end
      end
    end
  elseif kind == const.BAG_KIND.BANK then
    if self._newItemTimers and self._newItemTimers[const.BAG_KIND.BANK] then
      wipe(self._newItemTimers[const.BAG_KIND.BANK])
    end
    if _G.C_NewItems and _G.C_NewItems.RemoveNewItem then
      local function clearBags(bags)
        if not bags then return end
        for bagID in pairs(bags) do
          local numSlots = _G.C_Container and _G.C_Container.GetContainerNumSlots and _G.C_Container.GetContainerNumSlots(bagID) or 0
          for slotID = 1, numSlots do
            if _G.C_NewItems.IsNewItem and _G.C_NewItems.IsNewItem(bagID, slotID) then
              _G.C_NewItems.RemoveNewItem(bagID, slotID)
            end
          end
        end
      end
      clearBags(const.BANK_BAGS)
      clearBags(const.ACCOUNT_BANK_BAGS)
    end
  else
    if _G.C_NewItems and _G.C_NewItems.ClearAll then
      _G.C_NewItems.ClearAll()
    end
    if self._newItemTimers then
      if self._newItemTimers[const.BAG_KIND.BACKPACK] then
        wipe(self._newItemTimers[const.BAG_KIND.BACKPACK])
      end
      if self._newItemTimers[const.BAG_KIND.BANK] then
        wipe(self._newItemTimers[const.BAG_KIND.BANK])
      end
    end
  end
end

function items:MarkItemAsNew(ctx, data)
  if data and data.itemInfo and data.itemInfo.itemGUID then
    local kind = resolveKind(self, data)
    local timerTable = self._newItemTimers and self._newItemTimers[kind]
    if timerTable and timerTable[data.itemInfo.itemGUID] == nil then
      timerTable[data.itemInfo.itemGUID] = time()
      data.itemInfo.isNewItem = true
      data.itemInfo.category = self:GetCategory(ctx, data)
    end
  end
end

function items:MarkItemSlotAsNew(ctx, slotkey)
  local data = self:GetItemDataFromSlotKey(slotkey)
  self:MarkItemAsNew(ctx, data)
end

function items:GetItemDataFromSlotKey(slotkey)
  local kind = self:GetBagKindFromSlotKey(slotkey)
  if not kind then return nil end
  local slotInfo = self.slotInfo[kind]
  return slotInfo and slotInfo.itemsBySlotKey[slotkey]
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
    isBattlePayItem = (_G.C_Container and _G.C_Container.IsBattlePayItem and _G.C_Container.IsBattlePayItem(bagid, slotid)) and true or false,
    currentItemCount = data.containerInfo.stackCount or 1,
    category = "",
    currentItemLevel = C_Item.GetCurrentItemLevel and C_Item.GetCurrentItemLevel(itemLocation) or effectiveIlvl or 0,
    equipmentSets = equipmentSets:GetItemSets(bagid, slotid),
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

  if data.itemInfo.isNewItem and self._newItemTimers and self._newItemTimers[kind] and self._newItemTimers[kind][data.itemInfo.itemGUID] == nil then
    self._newItemTimers[kind][data.itemInfo.itemGUID] = time()
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
  if not data or data.isItemEmpty then
    return L:G("Empty Slot")
  end

  if not data.itemInfo then
    data.itemInfo = {}
  end

  if database:GetCategoryFilter(data.kind, "RecentItems") then
    if items:IsNewItem(data) then
      return L:G("Recent Items")
    end
  end

  -- Check for equipment sets first, as it doesn't make sense to put them anywhere else.
  if data.itemInfo.equipmentSets and database:GetCategoryFilter(data.kind, "GearSet") then
    return "Gear: " .. data.itemInfo.equipmentSets[1] -- Always use the first set, for now.
  end

  if not data.kind then
    return L:G("Everything")
  end

  -- Unified priority-based category selection
  -- Check both search cache (from search categories) and item list categories,
  -- returning the one with higher priority
  local searchCategory = self.searchCache[data.kind] and self.searchCache[data.kind][data.slotkey]
  local searchPriority = self.categoryPriorityCache[data.kind] and self.categoryPriorityCache[data.kind][data.slotkey]
  local customCategory, customPriority = categories:GetCustomCategory(ctx, data.kind, data)

  -- If both exist, compare priorities
  if searchCategory and customCategory then
    local sPriority = searchPriority or 10
    local cPriority = customPriority or 10
    -- Lower priority number wins (1 > 10); if equal, search category wins (tie-breaker)
    if cPriority < sPriority then
      return customCategory
    else
      return searchCategory
    end
  end

  -- If only one exists, return it
  if searchCategory then
    return searchCategory
  end

  if customCategory then
    return customCategory
  end

  local quality = data.containerInfo and data.containerInfo.quality
  if quality == const.ITEM_QUALITY.Poor then
    return L:G("Junk")
  end

  -- Item Equipment location takes precedence filters below and does not bisect.
  if
    database:GetCategoryFilter(data.kind, "EquipmentLocation")
    and data.itemInfo.itemEquipLoc ~= "INVTYPE_NON_EQUIP_IGNORE"
    and data.itemInfo.itemEquipLoc ~= nil
    and _G[data.itemInfo.itemEquipLoc] ~= nil
    and _G[data.itemInfo.itemEquipLoc] ~= ""
  then
    return _G[data.itemInfo.itemEquipLoc]
  end

  local category = ""

  -- Add the type filter to the category if enabled, but not to trade goods
  -- when the tradeskill filter is enabled. This makes it so trade goods are
  -- labeled as "Tailoring" and not "Tradeskill - Tailoring", which is redundent.
  if
    database:GetCategoryFilter(data.kind, "Type")
    and not (data.itemInfo.classID == Enum.ItemClass.Tradegoods and database:GetCategoryFilter(
      data.kind,
      "TradeSkill"
    ))
    and data.itemInfo.itemType
  then
    category = category .. data.itemInfo.itemType --[[@as string]]
  end

  -- Add the subtype filter to the category if enabled, but same as with
  -- the type filter we don't add it to trade goods when the tradeskill
  -- filter is enabled.
  if
    database:GetCategoryFilter(data.kind, "Subtype")
    and not (data.itemInfo.classID == Enum.ItemClass.Tradegoods and database:GetCategoryFilter(
      data.kind,
      "TradeSkill"
    ))
    and data.itemInfo.itemSubType
  then
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
    if not data.itemInfo.expacID then
      return L:G("Unknown")
    end
    -- Guard against unmapped expansion IDs (e.g., future Anniversary editions).
    -- This defensive check prevents nil concatenation crashes when Blizzard introduces
    -- new expansion IDs that aren't yet in EXPANSION_MAP.
    if not const.EXPANSION_MAP[data.itemInfo.expacID] then
      return L:G("Unknown")
    end
    if category ~= "" then
      category = category .. " - "
    end
    category = category .. const.EXPANSION_MAP[data.itemInfo.expacID] --[[@as string]]
  end

  if category == "" then
    category = L:G("Everything")
  end

  return category
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
