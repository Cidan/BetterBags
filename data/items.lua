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
---@field bagName? string The plain name of the item's bag (GetPlainBagName), set in Phase 6.
---@field itemTotal? number How many of its item the kind's bags hold (CountItemTotals).
---@field isUsable? boolean Whether the character can use it (CanUseItem); nil read cold or without the API.
---@field petOwned? number How many of its pet the account has (PetCountsOf); nil until the pet journal loaded.
---@field petLimit? number How many of its pet the account may have.
---@field appearanceKnown? boolean Its appearance is collected (AppearanceStateOf); nil without one or before the collection loaded.
---@field sourceKnown? boolean Its own source is collected.
---@field slotEquipped? number The lowest item level worn in its slots (SlotLevelsOf).
---@field slotBest? number The character's best item level in its slot (SlotLevelsOf).
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
---@field drawGeneration number The kind's draw generation when this sweep ran (see items:Init).
---@field harvestIncomplete boolean True when the client had no item info at harvest; never reused.
---@field rawItemName string|nil The client's ContainerItemInfo.itemName, before fallbacks (see ReuseHarvestedSlot).
---@field rawIconFileID number|nil The client's ContainerItemInfo.iconFileID, before fallbacks.
---@field rawQuality number|nil The client's ContainerItemInfo.quality, before fallbacks.
---@field bagName string
---@field forceClear boolean
---@field nextStack string

local items = addon:NewModule("Items")

-- eachKind calls fn with every kind of bag the data engine reads.
---@param fn fun(kind: BagKind)
local function eachKind(fn)
  for _, kind in pairs(const.BAG_KIND) do
    if kind ~= const.BAG_KIND.UNDEFINED then
      fn(kind)
    end
  end
end

-- guildTabOf is the guild bank tab a container is (const.GUILD_BANK_BAGS), nil for every container
-- that is a bag.
---@param bagid number
---@return number?
local function guildTabOf(bagid)
  return const.GUILD_BANK_BAGS and const.GUILD_BANK_BAGS[bagid]
end

-- drawsEmptySlotsInPlace says whether the slot-order view (Show Bags, a bank or guild tab by itself)
-- draws a bag's empty slots in place (Phase9_Sort): a bag with a name, a Warbank tab (retail reports
-- no name for them) and a guild bank tab (not a bag).
---@param bagid number
---@return boolean
local function drawsEmptySlotsInPlace(bagid)
  return C_Container.GetBagName(bagid) ~= nil
    or (addon.isRetail and const.ACCOUNT_BANK_BAGS ~= nil and const.ACCOUNT_BANK_BAGS[bagid] ~= nil)
    or guildTabOf(bagid) ~= nil
end

---@return GuildBank
local function guildBankSource()
  return addon:GetModule("GuildBank")
end

-- A cacheable provider's verdicts are kept on each item until one of their inputs changes
-- (see ResolveUpgrade); register a provider as cacheable only when every input of its
-- verdict is covered by an invalidation in RegisterCacheEvents.
---@param name string
---@param func fun(data: ItemData): boolean
---@param options? {cacheable: boolean}
function items:RegisterUpgradeProvider(name, func, options)
  self.upgradeProviders = self.upgradeProviders or {}
  self.upgradeProviderOptions = self.upgradeProviderOptions or {}
  self.upgradeProviders[name] = func
  self.upgradeProviderOptions[name] = options or {}
end

-- GetActiveUpgradeProvider resolves which registered provider actually drives
-- upgrade arrows. When the user has explicitly chosen a provider we honor that
-- choice exactly. Otherwise (the legacy default, where the setting was never
-- touched) an available external provider takes precedence over the built-in
-- 'None'/'BetterBags' values, restoring the pre-#1036 behavior where Pawn (or
-- SimpleItemLevel) drew arrows automatically without any dropdown selection.
-- Pawn wins over SimpleItemLevel when both are present.
---@return string
function items:GetActiveUpgradeProvider()
  local selected = database:GetUpgradeIconProvider()
  if database:GetUpgradeIconProviderUserSet() then
    return selected
  end
  self.upgradeProviders = self.upgradeProviders or {}
  if self.upgradeProviders["Pawn"] then
    return "Pawn"
  end
  if self.upgradeProviders["SimpleItemLevel"] then
    return "SimpleItemLevel"
  end
  return selected
end

-- IsNonPreferredArmorType returns true when the item is one of the four
-- wearable armor types (Cloth/Leather/Mail/Plate) but not the armor type the
-- current character prefers, per Blizzard's IsItemPreferredArmorType (the same
-- check that drives the "not your best armor type" bind warning). Shields,
-- cloaks (armor subclass Cloth but universally wearable), cosmetic and generic
-- armor, and all non-armor items are never gated. Returns false when the API
-- is unavailable (non-retail), so those clients keep the naive comparison.
---@param data ItemData
---@return boolean
function items:IsNonPreferredArmorType(data)
  if not _G.IsItemPreferredArmorType or not _G.ItemLocation then
    return false
  end
  local info = data and data.itemInfo
  if not info or not Enum or not Enum.ItemClass or not Enum.ItemArmorSubclass then
    return false
  end
  if info.classID ~= Enum.ItemClass.Armor then
    return false
  end
  local sub = info.subclassID
  local armor = Enum.ItemArmorSubclass
  if sub ~= armor.Cloth and sub ~= armor.Leather and sub ~= armor.Mail and sub ~= armor.Plate then
    return false
  end
  -- Cloaks are armor subclass Cloth but wearable by every class; never gate.
  if info.itemEquipLoc == "INVTYPE_CLOAK" then
    return false
  end
  local loc = _G.ItemLocation:CreateFromBagAndSlot(data.bagid, data.slotid)
  if not (loc and loc.IsValid and loc:IsValid()) then
    return false
  end
  return not _G.IsItemPreferredArmorType(loc)
end

-- Main-hand items that leave no off hand (a ranged weapon only sits in the main hand on
-- clients without a ranged slot), and items that need a one-handed main hand or go in the
-- off hand. A character holding one kind is not shown upgrades of the other (Pawn's rule): a
-- one-hander's item level says nothing about replacing a two-hander, and a two-hander's
-- ignores the off hand that would be lost.
local NO_OFF_HAND_EQUIP_LOCS = { INVTYPE_2HWEAPON = true, INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true }
local ONE_HAND_EQUIP_LOCS = {
  INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true,
  INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true,
}
-- Shirts and tabards are cosmetic, never upgrades.
local COSMETIC_EQUIP_LOCS = { INVTYPE_BODY = true, INVTYPE_TABARD = true }
-- Rings and trinkets fill two slots and are nearly always unique-equipped, so a copy of one
-- already worn cannot fill the other slot.
local PAIRED_UNIQUE_EQUIP_LOCS = { INVTYPE_FINGER = true, INVTYPE_TRINKET = true }
-- Primary stats as GetItemStats names them, and the LE_UNIT_STAT_* constant for each.
local PRIMARY_STAT_CONSTANTS = {
  STRENGTH = "LE_UNIT_STAT_STRENGTH",
  AGILITY = "LE_UNIT_STAT_AGILITY",
  INTELLECT = "LE_UNIT_STAT_INTELLECT",
}

-- specPrimaryStat returns the current spec's primary stat (an LE_UNIT_STAT_* value), read
-- the way Blizzard's paper doll does (PaperDollFrame.lua), or nil when the client reports
-- none (no spec, or a client without spec primary stats).
---@return number|nil
local function specPrimaryStat()
  local specInfo = _G.C_SpecializationInfo
  if not specInfo or not specInfo.GetSpecialization or not specInfo.GetSpecializationInfo then
    return nil
  end
  local spec = specInfo.GetSpecialization()
  if not spec then
    return nil
  end
  local primaryStat = select(6, specInfo.GetSpecializationInfo(spec, false, false, nil, UnitSex("player")))
  if primaryStat == nil or primaryStat == 0 then
    return nil
  end
  return primaryStat
end

-- itemSuitsPrimaryStat reports whether an item carries the given primary stat, or no
-- primary stat at all. GetItemStats keys are global strings: ITEM_MOD_STRENGTH_SHORT and
-- friends, with a multi-primary item listing each of its primaries (or, as the global
-- strings allow, a combined key such as ITEM_MOD_AGILITY_OR_INTELLECT_SHORT).
---@param itemLink string
---@param primaryStat number
---@return boolean
local function itemSuitsPrimaryStat(itemLink, primaryStat)
  local getItemStats = (C_Item and C_Item.GetItemStats) or _G.GetItemStats
  local stats = getItemStats and itemLink and getItemStats(itemLink)
  if not stats then
    return true
  end
  local hasPrimary = false
  for key in pairs(stats) do
    local body = key:match("^ITEM_MOD_(.+)_SHORT$")
    if body then
      for name in (body .. "_OR_"):gmatch("(.-)_OR_") do
        local constant = PRIMARY_STAT_CONSTANTS[name]
        if constant then
          hasPrimary = true
          if _G[constant] == primaryStat then
            return true
          end
        end
      end
    end
  end
  return not hasPrimary
end

-- ResolveUpgrade returns whether an item shows the upgrade arrow. A cacheable provider's
-- verdict is kept on the item (upgradeVerdict) with the provider and the upgrade generation,
-- and reused while both still match. The item itself never changes under a kept verdict: a
-- slot whose contents change is read into a new ItemData (ReuseHarvestedSlot). Everything
-- else a verdict depends on starts a new generation (InvalidateUpgrades; see
-- .claude/rules/caches.md §2). Nothing is kept for an item read while the client had no item
-- info for it, before the equipped gear has been read, or while any equipped item reads cold.
-- A provider that cannot tell yet leaves the item marked upgradeUnknown: it shows no arrow, but it
-- is no "not an upgrade", which a rule could take and Auto Sell could sell.
---@param data ItemData
---@return boolean
function items:ResolveUpgrade(data)
  if not data or data.isItemEmpty then
    return false
  end
  data.upgradeUnknown = nil
  local provider = self:GetActiveUpgradeProvider()
  if provider == "None" then
    return false
  end
  self.upgradeProviders = self.upgradeProviders or {}
  local func = self.upgradeProviders[provider]
  if not func then
    return false
  end
  local options = self.upgradeProviderOptions and self.upgradeProviderOptions[provider]
  local cacheable = options ~= nil and options.cacheable == true and self.equipmentCache ~= nil
    and not data.harvestIncomplete and not self._equipmentIncomplete
  if cacheable and data.upgradeProvider == provider and data.upgradeGeneration == self._upgradeGeneration then
    return data.upgradeVerdict
  end
  -- A provider answers nil when it cannot tell yet (Pawn: "we're not sure yet"): no arrow, and it is
  -- asked again next time.
  local answer = func(data)
  local verdict = answer and true or false
  data.upgradeUnknown = answer == nil or nil
  if cacheable and answer ~= nil then
    data.upgradeVerdict = verdict
    data.upgradeProvider = provider
    data.upgradeGeneration = self._upgradeGeneration
  else
    data.upgradeGeneration = nil
  end
  return verdict
end

-- contextSignature is what grey-out (ResolveItemContextMatchResult) reads besides the item, or nil
-- when kept grey-out cannot stand. With no item context (ItemButtonUtil.GetItemContext, every
-- client) it reads whether the bank is open and whether it shows a Warbank tab. While a context is
-- active, Blizzard's answer can depend on more than the context (the spell being cast for Enchanting,
-- CheckItemCondition, ReplaceBonusTree or JumpUpgradeTrack; the recipe while recrafting:
-- ItemButtonUtil.GetItemContextMatchResultForItem), so it is worked out on every refresh, as before.
---@return string|nil
function items:contextSignature()
  local util = _G.ItemButtonUtil
  if util and util.GetItemContext and util.GetItemContext() ~= nil then
    return nil
  end
  -- The Warbank as ResolveItemContextMatchResult tells it, which reads it only at the bank.
  local warbank = false
  local bank = addon.Bags and addon.Bags.Bank
  if addon.atBank and bank and bank.bankTab then
    local accountBankStart = addon.isRetail and Enum and Enum.BagIndex and Enum.BagIndex.AccountBankTab_1
      or (const.BANK_TAB and const.BANK_TAB.ACCOUNT_BANK_1)
    warbank = accountBankStart ~= nil and bank.bankTab >= accountBankStart
  end
  return tostring(addon.atBank == true) .. "|" .. tostring(warbank)
end

-- categoryStamp is what an item's own category was worked out under, besides the item and its
-- recency: the kind's category generation and the Categories module's.
---@param kind BagKind
---@return string
function items:categoryStamp(kind)
  local generation = categories and categories.GetGeneration and categories:GetGeneration() or 0
  return self._categoryGeneration[kind] .. ":" .. generation
end

-- InvalidateUpgrades starts a new upgrade generation, so kept verdicts are computed again.
-- With refresh, the backpack and (while open) the bank are refreshed on the next frame so
-- arrows update right away; without it, the next refresh recomputes them (used for frequent
-- events). The refresh recalculates the bags from the items already read, unless reread:
-- level and scaling change the bag items' own current item levels, which only a read sees.
---@param refresh boolean
---@param reread? boolean
function items:InvalidateUpgrades(refresh, reread)
  self._upgradeGeneration = self._upgradeGeneration + 1
  if refresh then
    self:RequestUpgradeRefresh(true, addon.atBank == true, reread)
  end
end

-- GetUpgradeGeneration is the current upgrade generation, for a provider keeping answers of its own (Pawn).
---@return number
function items:GetUpgradeGeneration()
  return self._upgradeGeneration
end

-- RequestUpgradeRefresh asks, on the next frame, for refreshes of the given bag kinds:
-- recalculations (bags/Rederive), or reads when any request of the frame asked to reread.
-- Requests made in the same frame share one timer and one refresh.
---@param backpack boolean
---@param bank boolean
---@param reread? boolean
function items:RequestUpgradeRefresh(backpack, bank, reread)
  local pending = self._upgradeRefreshPending
  local scheduled = pending.backpack or pending.bank
  pending.backpack = pending.backpack or backpack
  pending.bank = pending.bank or bank
  pending.reread = pending.reread or reread == true
  if scheduled or not (pending.backpack or pending.bank) then
    return
  end
  C_Timer.After(0, function()
    local doBackpack, doBank, doReread = pending.backpack, pending.bank and addon.atBank == true, pending.reread
    pending.backpack, pending.bank, pending.reread = false, false, false
    local ctx = context:New('InvalidateUpgrades')
    if not doReread then
      if doBackpack or doBank then
        events:SendMessage(ctx, 'bags/Rederive', { backpack = doBackpack, bank = doBank, categoriesUnchanged = true })
      end
      return
    end
    if doBackpack then
      events:SendMessage(ctx, 'bags/RefreshBackpack')
    end
    if doBank then
      events:SendMessage(ctx, 'bags/RefreshBank')
    end
  end)
end

---@param name string
---@return boolean
local function isEventValid(name)
  if _G.C_EventUtils and _G.C_EventUtils.IsEventValid then
    return _G.C_EventUtils.IsEventValid(name)
  end
  return true
end

-- RegisterCacheEvents wires the client events that change an input of a kept upgrade
-- verdict or of the equipped gear cache (.claude/rules/caches.md §2, §3):
--   * gear: PLAYER_EQUIPMENT_CHANGED (also marks the slot for a re-read);
--   * level and scaling: PLAYER_LEVEL_UP, PLAYER_LEVEL_CHANGED (level sync and other
--     effective-level changes), PLAYER_AVG_ITEM_LEVEL_UPDATE (also re-read all gear);
--   * proficiencies and skills: SKILL_LINES_CHANGED, LEARNED_SPELL_IN_SKILL_LINE;
--   * specialization: PLAYER_SPECIALIZATION_CHANGED for the player.
-- Each invalidates every kept verdict and refreshes the bags: level and scaling events read
-- them (the bag items' own current item levels change), the others recalculate them from the
-- items already read (refresh-scheduler.md §10). The built-in provider's
-- usability check (C_PlayerInfo.CanUseItem) also changes with reputation and spells, the
-- events Blizzard's own usability refresh listens for (Blizzard_Wardrobe.lua):
-- UPDATE_FACTION and SPELLS_CHANGED fire often, so they invalidate without a refresh (the
-- next refresh recomputes the verdicts).
function items:RegisterCacheEvents()
  local function register(name, callback)
    if isEventValid(name) then
      events:RegisterEvent(name, callback)
    end
  end
  register('PLAYER_EQUIPMENT_CHANGED', function(_, _, slot)
    if slot then
      self._equipmentDirty[slot] = true
    else
      self._equipmentDirtyAll = true
    end
    self:InvalidateUpgrades(true)
  end)
  for _, name in ipairs({ 'PLAYER_LEVEL_UP', 'PLAYER_LEVEL_CHANGED', 'PLAYER_AVG_ITEM_LEVEL_UPDATE' }) do
    register(name, function()
      self._equipmentDirtyAll = true
      self:InvalidateUpgrades(true, true)
    end)
  end
  for _, name in ipairs({ 'SKILL_LINES_CHANGED', 'LEARNED_SPELL_IN_SKILL_LINE' }) do
    register(name, function()
      self:InvalidateUpgrades(true)
    end)
  end
  register('PLAYER_SPECIALIZATION_CHANGED', function(_, _, unit)
    if unit == nil or unit == "player" then
      self:InvalidateUpgrades(true)
    end
  end)
  for _, name in ipairs({ 'UPDATE_FACTION', 'SPELLS_CHANGED' }) do
    register(name, function()
      self:InvalidateUpgrades(false)
    end)
  end
  for _, name in ipairs({ 'PET_JOURNAL_LIST_UPDATE', 'NEW_PET_ADDED', 'PET_JOURNAL_PET_DELETED',
    'PET_JOURNAL_PET_RESTORED' }) do
    register(name, function()
      self:OnCharacterStateChanged(true)
    end)
  end
  -- What the character can use follows its spells and reputations, which change often; what is
  -- collected follows the appearance collection: bucketed.
  for _, name in ipairs({ 'UPDATE_FACTION', 'SPELLS_CHANGED', 'TRANSMOG_COLLECTION_UPDATED',
    'TRANSMOG_COLLECTION_SOURCE_ADDED', 'TRANSMOG_COLLECTION_SOURCE_REMOVED' }) do
    if isEventValid(name) then
      events:BucketEvent(name, function()
        self:OnCharacterStateChanged(false)
      end)
    end
  end
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
  self.searchCache = {}
  self.categoryPriorityCache = {}
  self._newItemTimers = {}
  self._preSort = false
  self._doingRefresh = false
  self._firstLoad = {}
  -- A sort clears recent items and asks for a fresh layout, but the sweep that shows the
  -- result comes later (the item moves' refresh, or Refresh's fallback when nothing moved).
  -- The flag stays set until a sweep of that kind has committed.
  self._sortSweepPending = {}
  -- The bags the client changed after BetterBags last read them, each with the number of its last
  -- change (MarkBagUnread), and the count of changes reported so far.
  self._unreadBags = {}
  self._bagChanges = 0
  -- The interaction state (addon.atInteracting) each kind's committed stacks were built
  -- under (see NeedsInteractionRecalculation).
  self._stackedInteracting = {}
  -- Stamped on every item each sweep (Phase6_EnrichData) and bumped by every wipe sweep and
  -- every restyling recalculation (settings, bags/Rederive with buttons). Item buttons skip a
  -- redraw whose inputs are unchanged, so a new generation makes every button of the kind
  -- redraw.
  self._drawGeneration = {}
  -- What an item's kept category was worked out under (data-loader.md §18): bumped by every wipe and
  -- every recalculation that does not say its categories are unchanged (settings, categories, gear
  -- sets). With the Categories module's own generation it is each item's category stamp.
  self._categoryGeneration = {}
  eachKind(function(kind)
    self.searchCache[kind] = {}
    self.categoryPriorityCache[kind] = {}
    self._newItemTimers[kind] = {}
    self._firstLoad[kind] = true
    self._sortSweepPending[kind] = false
    self._drawGeneration[kind] = 0
    self._categoryGeneration[kind] = 0
  end)
  -- Equipped gear by inventory slot, set by every backpack sweep (HarvestEquipment); nil
  -- until the first one, so an unread slot is never taken for an empty one.
  self.equipmentCache = nil
  self.previousItemGUID = {}
  -- Upgrade verdict cache (ResolveUpgrade) and equipped gear cache (HarvestEquipment).
  self._upgradeGeneration = 0
  self._upgradeRefreshPending = { backpack = false, bank = false, reread = false }
  self._equipmentIncomplete = false
  self._equipped = {}
  self._equipmentDirty = {}
  self._equipmentDirtyAll = false
  self._equipmentLocations = {}

  self.upgradeProviders = {}
  self.upgradeProviderOptions = {}
  self:RegisterUpgradeProvider("BetterBags", function(data)
    local info = data.itemInfo
    if not data.inventorySlots or COSMETIC_EQUIP_LOCS[info.itemEquipLoc] or not C_Item.IsEquippableItem(info.itemLink) then
      return false
    end
    -- Before the first backpack sweep has read the equipped gear, every slot would look empty.
    if not self.equipmentCache then
      return false
    end

    -- Suppress arrows for items this character cannot use at all (class /
    -- proficiency), e.g. a staff for a warrior. C_PlayerInfo.CanUseItem is
    -- available on retail (10.0.5+) and Classic; when absent the provider
    -- degrades to the naive item-level comparison below.
    if _G.C_PlayerInfo and _G.C_PlayerInfo.CanUseItem and info.itemID then
      if not _G.C_PlayerInfo.CanUseItem(info.itemID) then
        return false
      end
    end

    -- Gear the character is not high enough level to wear yet.
    if (info.itemMinLevel or 0) > UnitLevel("player") then
      return false
    end

    -- Suppress arrows for wearable armor that is not the character's preferred
    -- armor type (e.g. cloth on a plate wearer), mirroring Blizzard's own
    -- "not your best armor type" bind-on-equip warning.
    if self:IsNonPreferredArmorType(data) then
      return false
    end

    -- Gear with primary stats, none of them the current spec's (an Intellect cloak for a
    -- Strength spec). Rings, necks and many trinkets carry no primary stat and pass.
    local primaryStat = specPrimaryStat()
    if primaryStat and not itemSuitsPrimaryStat(info.itemLink, primaryStat) then
      return false
    end

    local mainhand = self:GetItemDataFromInventorySlot(INVSLOT_MAINHAND)
    local mainhandEquipLoc = mainhand and mainhand.itemInfo.itemEquipLoc
    if ONE_HAND_EQUIP_LOCS[info.itemEquipLoc] and NO_OFF_HAND_EQUIP_LOCS[mainhandEquipLoc] then
      return false
    end
    -- Only melee two-handers: on Classic a ranged weapon goes in its own slot.
    if info.itemEquipLoc == "INVTYPE_2HWEAPON" and ONE_HAND_EQUIP_LOCS[mainhandEquipLoc] then
      return false
    end
    -- A one-hander goes in the off hand only for a character that can dual wield.
    local offhandAllowed = info.itemEquipLoc ~= "INVTYPE_WEAPON" or not _G.CanDualWield or _G.CanDualWield()

    for _, slot in pairs(data.inventorySlots) do
      if slot ~= INVSLOT_OFFHAND or offhandAllowed then
        local equippedItem = self:GetItemDataFromInventorySlot(slot)
        if equippedItem == nil then
          -- An empty slot: anything that fits is an upgrade, unless a copy of this ring or
          -- trinket is already worn in its other slot.
          local wornElsewhere = false
          if PAIRED_UNIQUE_EQUIP_LOCS[info.itemEquipLoc] and info.itemID then
            for _, other in pairs(data.inventorySlots) do
              local worn = self:GetItemDataFromInventorySlot(other)
              if worn and worn.itemInfo.itemID == info.itemID then
                wornElsewhere = true
              end
            end
          end
          if not wornElsewhere then
            return true
          end
        elseif info.currentItemLevel > equippedItem.itemInfo.currentItemLevel then
          return true
        end
      end
    end
    return false
  end, { cacheable = true })
end

function items:OnEnable()
  self:ResetSlotInfo()
  self:RegisterCacheEvents()
end

function items:WipeSlotInfo(kind)
  self.slotInfo = self.slotInfo or {}
  self.slotInfo[kind] = self:NewSlotInfo()
end

function items:ResetSlotInfo()
  eachKind(function(kind)
    self:WipeSlotInfo(kind)
  end)
end

function items:RemoveNewItemFromAllItems()
  -- NOOP stub for boot
end

function items:RefreshAll(ctx)
  -- NOOP stub for boot
end

function items:ClearItemCache(ctx)
  self.previousItemGUID = {}
  eachKind(function(kind)
    self:WipeSearchCache(kind)
  end)
  self:ResetSlotInfo()
end

function items:ClearBankCache(ctx)
  self:WipeSearchCache(const.BAG_KIND.BANK)
  self:WipeSlotInfo(const.BAG_KIND.BANK)
end

-- ClearGuildBankCache forgets the guild bank's items when the guild bank closes: the next sweep of
-- any kind drops them from the shared search index (Phase8_EnrichCategories), and the next visit
-- reads the guild bank afresh.
function items:ClearGuildBankCache(ctx)
  self:WipeSearchCache(const.BAG_KIND.GUILD)
  self:WipeSlotInfo(const.BAG_KIND.GUILD)
  self._firstLoad[const.BAG_KIND.GUILD] = true
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
function items:Phase5_UpdateFreeSlots(ctx, kind, itemData)
  if kind == const.BAG_KIND.GUILD then
    return self:guildFreeSlots(itemData)
  end
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
    local freeSlots, bagFamily = C_Container.GetContainerNumFreeSlots(bagid)
    freeSlots = freeSlots or 0
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
      -- The retail reagent bag reports family 0 (it is identified by bag id, not a family
      -- bit), so key it by the symbolic reagent key; classic profession bags keep their bits.
      local family = bagFamily or 0
      if family == 0 and const.BACKPACK_ONLY_REAGENT_BAGS and const.BACKPACK_ONLY_REAGENT_BAGS[bagid] then
        family = const.REAGENT_BAG_FAMILY_KEY
      end
      emptySlots[name] = emptySlots[name] or 0
      emptySlots[name] = emptySlots[name] + freeSlots
      emptySlotsByBag[bagid] = { name = name, count = freeSlots, family = family }
    end
  end

  return emptySlots, emptySlotsByBag
end

-- guildFreeSlots counts a guild bank read's empty slots per tab, from the slots it read (a tab is
-- not a container, so the client has no free slot count for it). Each tab is its own kind of free
-- space, named after the tab; only tabs this player may deposit in count.
---@private
---@param itemData table<string, ItemData>
---@return table<string, number> emptySlots, table<number, {name: string, count: number, family: number}> emptySlotsByBag
function items:guildFreeSlots(itemData)
  local emptySlots, emptySlotsByBag = {}, {}
  local free = {}
  for _, item in pairs(itemData or {}) do
    if item.isItemEmpty then
      free[item.bagid] = (free[item.bagid] or 0) + 1
    end
  end
  for container in pairs(guildBankSource():LoadedContainers()) do
    local info = guildBankSource():TabInfo(guildBankSource():TabOf(container))
    if info and info.canDeposit then
      local count = free[container] or 0
      emptySlots[info.name] = (emptySlots[info.name] or 0) + count
      emptySlotsByBag[container] = { name = info.name, count = count, family = 0 }
    end
  end
  return emptySlots, emptySlotsByBag
end

-- GetPlainBagName returns a bag's name: a guild tab's name, the keyring, the bank, or the client's
-- name for the container (C_Container.GetBagName). Show Bags labels it with a number
-- (GetBagName); the bagname search field holds it as it is.
---@param bagid number
---@return string
function items:GetPlainBagName(bagid)
  local guildTab = guildTabOf(bagid)
  if guildTab then
    local info = guildBankSource():TabInfo(guildTab)
    return info and info.name or format(GUILDBANK_TAB_NUMBER, guildTab)
  end
  if const.BACKPACK_BAGS[bagid] ~= nil then
    if Enum and Enum.BagIndex and Enum.BagIndex.Keyring and bagid == Enum.BagIndex.Keyring then
      return L:G('Keyring')
    end
    return C_Container.GetBagName(bagid) or "Unknown"
  end
  if bagid == -1 then
    return L:G('Bank')
  elseif bagid == -3 then
    return L:G('Reagent Bank')
  end
  return C_Container.GetBagName(bagid) or L:G("Bank Bag")
end

-- GetBagName returns a bag's Show Bags label: "#<n>: <name>" (GetPlainBagName).
---@param bagid number
---@return string
function items:GetBagName(bagid)
  local name = self:GetPlainBagName(bagid)
  local guildTab = guildTabOf(bagid)
  if guildTab then
    return string.format("#%d: %s", guildTab, name)
  end
  if const.BACKPACK_BAGS[bagid] ~= nil then
    local displayid = bagid + 1
    if Enum and Enum.BagIndex and Enum.BagIndex.Keyring and bagid == Enum.BagIndex.Keyring then
      -- After the last bag: #6 on Classic Era (bags 0-4), #7 on Forever (with the reagent bag).
      local lastBag = 0
      for id in pairs(const.BACKPACK_BAGS) do
        if id ~= bagid and id > lastBag then
          lastBag = id
        end
      end
      displayid = lastBag + 2
    end
    return string.format("#%d: %s", displayid, name)
  end
  if bagid == -1 or bagid == -3 then
    return string.format("#%d: %s", 1, name)
  end
  return string.format("#%d: %s", bagid - 4, name)
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
  -- The guild bank shows every tab's items in categories (one view), or a tab by itself, its
  -- slots in order (guild-bank.md §4).
  if kind == const.BAG_KIND.GUILD then
    if viewBagView == const.BAG_VIEW.SECTION_ALL_BAGS then
      return item.bagid == tabID
    end
    local category = item.itemInfo and item.itemInfo.category or L:G("Everything")
    return tabID == const.GUILD_BANK_ALL_TAB and category ~= L:G("Free Space") and category ~= L:G("Recent Items")
  end
  if viewBagView == const.BAG_VIEW.SECTION_ALL_BAGS then
    -- Retail's bank Show Bags view is one Blizzard bank tab at a time (tab ID == bag ID).
    -- Classic/Era has no bank tabs, so every bank container renders, like the backpack.
    if kind == const.BAG_KIND.BANK and addon.isRetail then
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
    local bankType = nil
    if addon.isRetail and kind == const.BAG_KIND.BANK then
      local itemIsAccountBank = (const.ACCOUNT_BANK_BAGS and const.ACCOUNT_BANK_BAGS[item.bagid] ~= nil) or false
      bankType = itemIsAccountBank and (Enum.BankType and Enum.BankType.Account or 2) or (Enum.BankType and Enum.BankType.Character or 0)
    end
    return groupsMod:CategoryBelongsToGroup(kind, category, tabID, bankType)
  end
  return true
end

local function IncludeBagInFreeSpace(kind, bagid, tabID)
  if kind == const.BAG_KIND.GUILD then
    if database:GetBagView(kind) == const.BAG_VIEW.SECTION_ALL_BAGS then
      return bagid == tabID
    end
    return tabID == const.GUILD_BANK_ALL_TAB and guildTabOf(bagid) ~= nil
  end
  if kind == const.BAG_KIND.BACKPACK then
    -- The keyring (WoW: Forever) holds only keys: its slots are not free space.
    local isKeyring = Enum.BagIndex and Enum.BagIndex.Keyring and bagid == Enum.BagIndex.Keyring
    return const.BACKPACK_BAGS[bagid] ~= nil and not isKeyring
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
  if kind == const.BAG_KIND.GUILD then
    if database:GetBagView(kind) == const.BAG_VIEW.SECTION_ALL_BAGS then
      for container in pairs(guildBankSource():LoadedContainers()) do
        tabs[container] = true
      end
    else
      tabs[const.GUILD_BANK_ALL_TAB] = true
    end
    return tabs
  end
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
  elseif kind == const.BAG_KIND.GUILD then
    -- The guild bank's tabs the client has received this visit (GuildBank:Load).
    bagList = guildBankSource():LoadedContainers()
  elseif kind == const.BAG_KIND.BANK then
    if const.BANK_ONLY_BAGS then
      for _, bag in pairs(const.BANK_ONLY_BAGS) do
        local id = C_Container.ContainerIDToInventoryID(bag)
        if id and GetInventoryItemQuality then
          GetInventoryItemQuality("player", id)
        end
      end
    end
    bagList = self:BankBags(ctx)
    -- While a bank open loads the bank tab by tab, only the tabs loaded so far, as a guild bank
    -- read reads only the tabs received (refresh-scheduler.md §11).
    local loaded = self._loadedBankBags
    if loaded ~= nil then
      local onlyLoaded = {}
      for bagID in pairs(bagList) do
        if loaded[bagID] then
          onlyLoaded[bagID] = bagList[bagID]
        end
      end
      bagList = onlyLoaded
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

-- BankBags returns the bags a read of the bank reads: on retail every character and Warbank tab; on
-- Classic the bank, its bags and the reagent bank. With a ctx it marks which bank the read is of
-- (bagid), for the free slot count.
---@param ctx? Context
---@return table<number, number>
function items:BankBags(ctx)
  local bagList = {}
  local function mark(bagid)
    if ctx ~= nil then
      ctx:Set("bagid", bagid)
    end
  end
  local blizzardTab = addon.Bags and addon.Bags.Bank and addon.Bags.Bank.blizzardBankTab
  if addon.isRetail then
    mark(const.BANK_TAB.BANK)
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
      mark(const.BANK_TAB.ACCOUNT_BANK_1)
    else
      mark(const.BANK_TAB.BANK)
    end
    bagList[blizzardTab] = blizzardTab
  else
    local activeGroupID = database:GetActiveGroup(const.BAG_KIND.BANK)
    local activeGroup = activeGroupID and database:GetGroup(const.BAG_KIND.BANK, activeGroupID)
    local reagentBank = not addon.isRetail and const.BANK_TAB.REAGENT or nil

    if activeGroup and addon.isRetail and activeGroup.bankType == (Enum and Enum.BankType and Enum.BankType.Account) then
      mark(const.BANK_TAB.ACCOUNT_BANK_1)
      if const.ACCOUNT_BANK_BAGS then
        for _, bag in pairs(const.ACCOUNT_BANK_BAGS) do
          bagList[bag] = bag
        end
      end
    else
      mark(const.BANK_TAB.BANK)
      for _, bag in pairs(const.BANK_BAGS) do
        bagList[bag] = bag
      end
      if reagentBank then
        bagList[reagentBank] = reagentBank
      end
    end
  end
  return bagList
end

-- SetLoadedBankBags limits reads of the bank to the tabs a bank open has loaded so far (a set of bag
-- IDs), or, with nil, lets them read every bank bag again (refresh-scheduler.md §11).
---@param bags? table<number, boolean>
function items:SetLoadedBankBags(bags)
  self._loadedBankBags = bags
end

-- LoadedBankBags is the set of bank tabs reads of the bank are limited to, or nil for every bank bag.
---@return table<number, boolean>?
function items:LoadedBankBags()
  return self._loadedBankBags
end

-- NeedsInteractionRecalculation says whether an interaction window opening or closing
-- changes the kind's committed data: stacks unmerge while interacting when the kind's
-- "Unmerge on Interactions" option is on (ShouldMergeItem), so the answer is yes only when
-- the committed stacks were built under the other interaction state. A kind with no committed
-- items has nothing to recalculate (its next read stacks them).
---@param kind BagKind
---@return boolean
function items:NeedsInteractionRecalculation(kind)
  local committed = self.slotInfo and self.slotInfo[kind] and self.slotInfo[kind].itemsBySlotKey
  if not committed or next(committed) == nil then
    return false
  end
  local opts = database:GetStackingOptions(kind)
  if not (opts.mergeStacks and opts.unmergeAtShop) then
    return false
  end
  return self._stackedInteracting[kind] ~= (addon.atInteracting == true)
end

---@param kind BagKind
---@param bagList table<number, number>
---@param previousItems? table<string, ItemData> The committed items, whose unchanged slots are kept.
---@param rereadEquipment? boolean Read every equipped slot again (wipe sweeps).
function items:Phase2_Harvest(kind, bagList, previousItems, rereadEquipment)
  if kind == const.BAG_KIND.GUILD then
    return self:HarvestGuildBank(bagList, previousItems), {}
  end
  return self:Harvest(kind, bagList, kind == const.BAG_KIND.BACKPACK, previousItems, rereadEquipment)
end

-- Phase2_Rederive gives a derive (refresh-scheduler.md §10) the items the last read
-- committed, reading no bag slot. A bag the client changed after that read (MarkBagUnread) keeps
-- its committed items as they were, and the client is asked nothing about them: what it reports
-- for their slots belongs to the change (an emptied slot has no item to ask about), and the read the
-- change led to is on its way. In every other bag, an item still in its slot (same GUID) gets the
-- fields a read refreshes on a kept slot (refreshKeptItem): quest state, tooltip text, gear sets and
-- the new-item flag; one read while the client had no data for it (harvestIncomplete) is
-- read again, as every read does with such a slot. An item whose slot now holds something else keeps its values: what the
-- client reports for the slot belongs to the other item, and the slot's read is on its way.
-- A backpack derive reads the equipped gear, as a backpack read does, so upgrade arrows
-- compare with the gear worn now.
---@param kind BagKind
---@param committedItems table<string, ItemData>
---@return table<string, ItemData> itemData
---@return table<number, ItemData> equipmentData
function items:Phase2_Rederive(kind, committedItems)
  if kind == const.BAG_KIND.GUILD then
    return self:RederiveGuildBank(committedItems), {}
  end
  local itemData = {}
  local itemLoader = addon:GetModule("ItemLoader", true)
  for slotkey, item in pairs(committedItems) do
    if not item.isItemEmpty and self._unreadBags[item.bagid] == nil then
      local itemMixin = itemLoader and itemLoader:GetItemMixinFromSlotKey(slotkey) or Item:CreateFromBagAndSlot(item.bagid, item.slotid) --[[@as ItemMixin]]
      local itemGUID = C_Item.GetItemGUID(itemMixin:GetItemLocation()) or ""
      if itemGUID == item.itemInfo.itemGUID then
        if item.harvestIncomplete then
          local data = {}
          ---@cast data +ItemData
          data.bagid, data.slotid = item.bagid, item.slotid
          self:AttachItemInfo(data, kind)
          item = data
        else
          self:RefreshKeptItem(kind, item, item.bagid, item.slotid, itemGUID)
        end
      end
    end
    itemData[slotkey] = item
  end
  local equipmentData = {}
  if kind == const.BAG_KIND.BACKPACK then
    equipmentData = self:HarvestEquipment()
  end
  return itemData, equipmentData
end

-- Phase6_EnrichData works out each item's own category, grey-out and upgrade arrow, and names the
-- empty slots. An item whose own category it works out again is marked for the search index
-- (derived.indexPending, which Phase 8 clears once it is indexed, data-loader.md §18).
function items:Phase6_EnrichData(ctx, kind, itemData, emptySlotsByBag)
  local emptySlotByBagAndSlot = {}
  local freeSlotKeys = {}
  local freeSlotKeysByBag = {}
  local emptySlotsSorted = {}
  local totalItems = 0
  local stamp = self:categoryStamp(kind)
  local contextSig = self:contextSignature()

  -- An empty slot is named after its bag and colored by the bag's type. Both are the same
  -- for every slot of a bag, so each bag is looked up once per sweep (never kept across
  -- sweeps: bags can be swapped). Slots holding an item use neither.
  local bagDetails = {}
  local function bagDetailsOf(bagid)
    local details = bagDetails[bagid]
    if details then
      return details
    end
    local name, quality
    local guildTab = guildTabOf(bagid)
    if guildTab then
      local info = guildBankSource():TabInfo(guildTab)
      details = { name = info and info.name or format(GUILDBANK_TAB_NUMBER, guildTab), quality = const.BAG_SUBTYPE_TO_QUALITY[0] }
      bagDetails[bagid] = details
      return details
    end
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
    details = { name = name, quality = quality }
    bagDetails[bagid] = details
    return details
  end

  -- Each item's bag by name, for the bagname search field (Phase 8 indexes it), also looked up once
  -- per bag per sweep.
  local bagNames = {}

  for _, currentItem in pairs(itemData) do
    local bagid = currentItem.bagid
    local name

    bagNames[bagid] = bagNames[bagid] or self:GetPlainBagName(bagid)
    currentItem.bagName = bagNames[bagid]

    if currentItem.isItemEmpty then
      local details = bagDetailsOf(bagid)
      name = details.name
      currentItem.itemInfo = currentItem.itemInfo or {}
      currentItem.itemInfo.emptySlotName = name
      local bagFamily = emptySlotsByBag and emptySlotsByBag[bagid] and emptySlotsByBag[bagid].family
      currentItem.itemInfo.emptySlotFamilyIcon = self:GetEmptySlotFamilyIcon(bagFamily)
      currentItem.itemInfo.itemQuality = details.quality or const.ITEM_QUALITY.Common
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

    if currentItem.isItemEmpty then
      currentItem.itemInfo.category = self:GetCategory(ctx, currentItem, true)
    else
      -- What the item was worked out with is kept on it (derived), and each part is worked out
      -- again only when one of its inputs changed (data-loader.md §18): a re-read slot is a new
      -- item with nothing kept, and an in-place change of one of its own inputs drops what was
      -- kept (RefreshKeptItem).
      local d = currentItem.derived
      if d == nil then
        d = {}
        currentItem.derived = d
      end
      -- The item's own category, without search categories or Recent Items: the search index holds it
      -- while Phase 8 matches search categories (data-loader.md §8), so a rule's category field matches
      -- what the item is, new or not (a rule taking junk by `category = "junk"` takes a new junk item,
      -- and Skip Recent Items sees it).
      if d.category ~= stamp then
        d.ownCategory = self:GetCategory(ctx, currentItem, true, true)
        d.category, d.base, d.final = stamp, nil, nil
        currentItem.itemInfo.category = d.ownCategory
        d.indexPending = true
      end
      if contextSig == nil or d.context ~= contextSig then
        currentItem.itemContextMatchResult = self:ResolveItemContextMatchResult(currentItem)
        d.context = contextSig
      end
    end
    -- Kept verdicts are reused inside (caches.md §2). The search indexes the arrow: a kept item
    -- whose arrow changed is compared with its search entry again (search-indexing.md §11).
    local wasUnknown = currentItem.upgradeUnknown
    local upgrade = self:ResolveUpgrade(currentItem)
    -- The slot values follow the worn gear, as the arrow does (search-indexing.md §16).
    local slotEquipped, slotBest = self:SlotLevelsOf(currentItem)
    if currentItem.derived and (currentItem.isUpgrade ~= upgrade or currentItem.upgradeUnknown ~= wasUnknown
      or currentItem.slotEquipped ~= slotEquipped or currentItem.slotBest ~= slotBest) then
      currentItem.derived.indexPending = true
    end
    currentItem.isUpgrade = upgrade
    currentItem.slotEquipped, currentItem.slotBest = slotEquipped, slotBest
    currentItem.drawGeneration = self._drawGeneration[kind]
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

-- MarkAddedItemsRecent implements the "All Items Recent" option
-- (database:GetMarkRecentItems). It marks every genuinely-acquired item as recent
-- independent of the client's C_NewItems flag, which is required because WoW does not flag
-- items auto-looted from an opened container (e.g. a loot bag) as new, nor a stack that grows
-- (a vendor purchase onto a partial stack). An item is treated as acquired when its GUID is
-- not present anywhere in the previously committed state; this covers a brand-new slot, a
-- slot whose contents changed in place (the container's own slot being filled by its
-- contents), and excludes a pure move (the same GUID reappearing in a different slot), which
-- Phase4_ClearMovedItemGlows handles instead. A stack that kept its GUID is acquired when its
-- count grew and so did its item's total count in the kind, which excludes stacks merged by
-- hand (the total is unchanged).
---@param ctx Context
---@param kind BagKind
---@param previousItems table<string, ItemData>
---@param itemData table<string, ItemData>
function items:MarkAddedItemsRecent(ctx, kind, previousItems, itemData)
  if ctx:Get("wipe") == true then return end
  if not addon.isRetail then return end
  -- Bank items are only being viewed, not actively acquired, so they are never marked recent.
  if kind ~= const.BAG_KIND.BACKPACK then return end
  if not (database.GetMarkRecentItems and database:GetMarkRecentItems(kind)) then return end

  -- previousCounts[guid] is the GUID's count in the previous state; totals are per item ID.
  local previousCounts, previousTotals, totals = {}, {}, {}
  for _, oldItem in pairs(previousItems) do
    if not oldItem.isItemEmpty and oldItem.itemInfo then
      local info = oldItem.itemInfo
      if info.itemGUID then
        previousCounts[info.itemGUID] = info.currentItemCount or 0
      end
      if info.itemID then
        previousTotals[info.itemID] = (previousTotals[info.itemID] or 0) + (info.currentItemCount or 0)
      end
    end
  end
  for _, item in pairs(itemData) do
    local info = item.itemInfo
    if not item.isItemEmpty and info and info.itemID then
      totals[info.itemID] = (totals[info.itemID] or 0) + (info.currentItemCount or 0)
    end
  end

  for _, newItem in pairs(itemData) do
    local info = newItem.itemInfo
    if not newItem.isItemEmpty and info and info.itemGUID then
      local previousCount = previousCounts[info.itemGUID]
      if previousCount == nil then
        self:MarkItemAsNew(ctx, newItem)
      elseif (info.currentItemCount or 0) > previousCount and info.itemID
        and (totals[info.itemID] or 0) > (previousTotals[info.itemID] or 0) then
        self:MarkItemAsNew(ctx, newItem)
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

  -- Show Bags (SECTION_ALL_BAGS) mirrors the physical container layout: every bag slot
  -- must render on its own, so virtual stacking is disabled entirely for that view.
  local isAllBags = database.GetBagView and database:GetBagView(kind) == const.BAG_VIEW.SECTION_ALL_BAGS

  local function ShouldMergeItem(bagKind, item, stackInfo)
    if isAllBags then return false end
    if not stackInfo then return false end
    local opts = database:GetStackingOptions(bagKind)
    if not opts.mergeStacks then return false end
    if opts.unmergeAtShop and addon.atInteracting then return false end
    if opts.dontMergePartial and item.itemInfo.itemStackCount ~= item.itemInfo.currentItemCount then return false end
    if not opts.mergeUnstackable and item.itemInfo.itemStackCount == 1 then return false end
    return true
  end

  -- A stack is shown in Recent Items while any pile it merges is recent (stackRecent, read by
  -- GetCategory). Its root is the largest pile, which looting changes: taking recency from the root
  -- alone moved a stack between Recent Items and its category as it was looted into
  -- (virtual-stacks.md §9).
  local visibleItemsBySlotKey = {}
  for slotkey, item in pairs(itemData) do
    if not item.isItemEmpty then
      local stackInfo = stackData:GetStackInfo(item.itemHash)
      local isRoot = true
      item.stackRecent = nil

      if ShouldMergeItem(kind, item, stackInfo) then
        if item.slotkey == stackInfo.rootItem then
          -- Root item. Compute total count.
          local totalCount = item.itemInfo.currentItemCount
          local anyRecent = false
          for childSlotkey in pairs(stackInfo.slotkeys) do
            local childItem = itemData[childSlotkey]
            if childItem and not childItem.isItemEmpty then
              if ShouldMergeItem(kind, childItem, stackInfo) then
                totalCount = totalCount + childItem.itemInfo.currentItemCount
                anyRecent = anyRecent or self:IsNewItem(childItem)
              end
            end
          end
          item.stackedCount = totalCount
          item.stackRecent = anyRecent or nil
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

-- syncIndex brings a kind's entries of the search index in line with its items, comparing only the
-- items marked for it (derived.indexPending, set when Phase 6 works an item out again) and the items
-- that are other objects than the index was built from (search:SyncKind), then clears the marks. A
-- mark outlives a sweep that fails before indexing, so the next sweep indexes the item.
---@param kind BagKind
---@param kindItems table<string, ItemData>
---@param rebuild boolean
function items:syncIndex(kind, kindItems, rebuild)
  local pending = {}
  for slotkey, item in pairs(kindItems) do
    if item.derived and item.derived.indexPending then
      pending[slotkey] = item
    end
  end
  search:SyncKind(kind, kindItems, rebuild, pending)
  for _, item in pairs(pending) do
    item.derived.indexPending = nil
  end
end

-- CountItemTotals gives each item how many of its item the kind's bags hold, by item ID
-- (itemTotal, the search's total field), and marks for re-indexing a kept item whose total changed:
-- a slot that changes changes the total of every other slot of its item.
---@param itemData table<string, ItemData>
function items:CountItemTotals(itemData)
  local totals = {}
  for _, item in pairs(itemData) do
    if not item.isItemEmpty then
      local id = item.itemInfo.itemID
      totals[id] = (totals[id] or 0) + (item.itemInfo.currentItemCount or 0)
    end
  end
  for _, item in pairs(itemData) do
    if not item.isItemEmpty then
      local total = totals[item.itemInfo.itemID]
      if item.derived and item.itemTotal ~= total then
        item.derived.indexPending = true
      end
      item.itemTotal = total
    end
  end
end

-- Phase8_EnrichCategories brings the search index up to date, matches search categories, and works out
-- the category each item is shown in, again only for an item whose inputs changed (data-loader.md
-- §18): it was re-read, its own category was worked out again (Phase 6), its search category or
-- recency changed. The index holds the category each item is shown in.
---@param ctx Context
---@param kind BagKind
---@param itemData table<string, ItemData>
---@param emptySlotByBagAndSlot table
---@return table sectionLayouts
-- SkipRecent unmarks a new item whose category (category: the item's own with its search categories,
-- Recent Items left out) skips Recent Items (Skip Recent Items, a category setting, categories:SkipsRecentOf;
-- docs/next-batch-2.md §1): its timer ends and the client's new-item mark goes, so it shows in its
-- category at once, and a virtual stack it roots is no longer recent (every pile of a stack is the same
-- item, in the same category). It returns whether it unmarked the item, for profiler traces.
---@param ctx Context
---@param item ItemData
---@param category string
---@return boolean
function items:SkipRecent(ctx, item, category)
  -- Not on a guess: a rule can take an item with no upgrade state yet (NOT upgrade = true), and what this
  -- ends cannot be given back when the answer says otherwise.
  if item.upgradeUnknown or not (item.stackRecent or self:IsNewItem(item)) or not categories:SkipsRecentOf(category) then
    return false
  end
  item.stackRecent = nil
  if self:IsNewItem(item) then
    self:ClearNewItemFromData(ctx, item)
    return true
  end
  return false
end

function items:Phase8_EnrichCategories(ctx, kind, itemData, emptySlotByBagAndSlot)
  if search and search.SyncKind then
    -- The search index is a single, global structure shared by the backpack and the bank
    -- (the live bank search box queries it too). Bring this kind's entries in line with
    -- this sweep's items -- re-indexing only the items whose indexed values changed, or
    -- every item on a wipe -- and the other kind's with its last-committed items, so the
    -- index always equals a clean rebuild over both bags.
    self:syncIndex(kind, itemData, ctx:Get("wipe") == true)
    eachKind(function(otherKind)
      if otherKind ~= kind then
        local otherSlotInfo = self.slotInfo and self.slotInfo[otherKind]
        self:syncIndex(otherKind, otherSlotInfo and otherSlotInfo.itemsBySlotKey or {}, false)
      end
    end)
  end

  -- Search categories match each item's own category (data-loader.md §8). The index holds the
  -- category each item is shown in, so while they are matched an item shown in another category is
  -- indexed with its own; the loop below indexes the category it is shown in again.
  local inPlay = false
  if categories and categories.GetSortedSearchCategories then
    for _, categoryFilter in ipairs(categories:GetSortedSearchCategories()) do
      if categoryFilter.enabled and categoryFilter.enabled[kind] then
        inPlay = true
        break
      end
    end
  end
  if inPlay and search.UpdateCategoryIndex then
    for _, currentItem in pairs(itemData) do
      local own = not currentItem.isItemEmpty and currentItem.derived and currentItem.derived.ownCategory
      if own and currentItem.itemInfo.category ~= own then
        currentItem.itemInfo.category = own
        search:UpdateCategoryIndex(currentItem)
      end
    end
  end
  self:RefreshSearchCache(kind, itemData)

  -- Search categories compete with custom categories, gear sets and recent items by the priority
  -- rules in GetCategory. An item's shown category is worked out again when its own category was
  -- (final dropped by Phase 6), or its search category or recency (a stack's too) changed. In the
  -- Show Bags view every item is shown in its bag's section.
  local showBags = database.GetBagView and database:GetBagView(kind) == const.BAG_VIEW.SECTION_ALL_BAGS
  local searchCache = self.searchCache[kind] or {}
  local priorities = self.categoryPriorityCache[kind] or {}
  for slotkey, currentItem in pairs(itemData) do
    if not currentItem.isItemEmpty then
      local d = currentItem.derived
      if d == nil then
        d = {}
        currentItem.derived = d
      end
      local searchCategory, searchPriority = searchCache[slotkey], priorities[slotkey]
      -- Its category without Recent Items (base), worked out again only when its own category (Phase 6
      -- drops it) or its search categories changed; then whether it is recent, which only picks between
      -- base and Recent Items, as GetCategory does (its Recent Items check comes first).
      if d.base == nil or d.searchCategory ~= searchCategory or d.searchPriority ~= searchPriority then
        d.base = self:GetCategory(ctx, currentItem, false, true)
        d.searchCategory, d.searchPriority, d.final = searchCategory, searchPriority, nil
      end
      self:SkipRecent(ctx, currentItem, d.base)
      local recent = self:IsNewItem(currentItem) or currentItem.stackRecent == true
      if d.final == nil or d.finalRecent ~= recent then
        local shownRecent = recent and database:GetCategoryFilter(currentItem.kind, "RecentItems")
        d.final = shownRecent and L:G("Recent Items") or d.base
        d.finalRecent = recent
      end
      local shown = showBags and self:GetBagName(currentItem.bagid) or d.final
      if currentItem.itemInfo.category ~= shown then
        local oldCategory = currentItem.itemInfo.category
        currentItem.itemInfo.category = shown
        if search.UpdateCategoryIndex then
          search:UpdateCategoryIndex(currentItem, oldCategory)
        end
      end
    end
  end

  local searchBox = addon:GetModule("SearchBox", true)
  -- Resolve the active query for THIS kind: with in-bag search on (default) the
  -- live filter is driven by the per-kind in-bag box, not the overlay box that
  -- GetText() reads. Reading the wrong box reset isSearchResult to nil on every
  -- redraw, clearing the visible filter (e.g. right-clicking an item to bank it).
  local searchQuery = searchBox and searchBox.GetSearchText and searchBox:GetSearchText(kind)
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
  if showBags then
    -- A bank tab or a guild bank tab shown by itself is one section: its tab names it.
    local shouldHideHeader = (kind == const.BAG_KIND.BANK or kind == const.BAG_KIND.GUILD)
    for _, currentItem in pairs(itemData) do
      if not currentItem.isItemEmpty then
        sectionLayouts[currentItem.itemInfo.category] = { hideHeader = shouldHideHeader, sortMode = "physical" }
      end
    end
    for bagid, _ in pairs(emptySlotByBagAndSlot) do
      local category = self:GetBagName(bagid)
      sectionLayouts[category] = { hideHeader = shouldHideHeader, sortMode = "physical" }
    end
  end

  return sectionLayouts
end

-- bagOfKind is the bag that shows a kind: the backpack, the bank, or the guild bank.
---@private
---@param kind BagKind
---@return table?
function items:bagOfKind(kind)
  local bags = addon.Bags
  if not bags then
    return nil
  end
  if kind == const.BAG_KIND.BANK then
    return bags.Bank
  elseif kind == const.BAG_KIND.GUILD then
    return bags.GuildBank
  end
  return bags.Backpack
end

-- IsBagOpen reports whether the bag window for `kind` is currently visible.
-- Gaps only accrue while the user is looking at the bag; a sweep that runs while
-- the bag is hidden (the on-close redraw, or consuming items with bags closed)
-- rebuilds a fresh, gapless layout instead.
---@param kind BagKind
---@return boolean
function items:IsBagOpen(kind)
  local bag = self:bagOfKind(kind)
  if not bag or not bag.frame or not bag.frame.IsShown then
    return false
  end
  return bag.frame:IsShown() and true or false
end

-- MarkDrawOnClose flags the bag so that closing it triggers a refresh which,
-- because the frame is then hidden, rebuilds a gapless layout.
---@param kind BagKind
function items:MarkDrawOnClose(kind)
  local bag = self:bagOfKind(kind)
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

  -- Pass 3: an item whose hash changed without leaving its slot (same item GUID) keeps
  -- its position: a cold read at login warming up, an enchant or an item level change
  -- rehashes an item that never left. It runs after the hash passes, so it only pairs
  -- what they left over. The slot must match: a move between the Character Bank and the
  -- Warbank changes the hash on purpose and stays a remove + add.
  local keptRehashed = false
  for _, p in ipairs(previousSortedItems) do
    if not p.isItemGap and not p.isFreeSlot and not (action[p] and action[p].keep) then
      local cur = visibleItemsBySlotKey[p.slotkey]
      local guid = p.itemInfo and p.itemInfo.itemGUID
      if cur and not usedCur[p.slotkey] and guid and guid ~= ""
        and cur.itemInfo and cur.itemInfo.itemGUID == guid then
        action[p] = { keep = cur }
        usedCur[p.slotkey] = true
        keptRehashed = true
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

  -- A kept rehashed item holds its old position, which can be out of sort order (its
  -- category or sort keys may have changed), so closing the bag re-sorts it too.
  if emittedGap or keptRehashed then
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
        if drawsEmptySlotsInPlace(bagid) then
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
              expacID = 0,
              emptySlotFamilyIcon = data.itemInfo and data.itemInfo.emptySlotFamilyIcon,
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
  if kind == const.BAG_KIND.GUILD then
    activeTabID = const.GUILD_BANK_ALL_TAB
  elseif kind == const.BAG_KIND.BACKPACK then
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

  if kind ~= const.BAG_KIND.GUILD or viewBagView ~= const.BAG_VIEW.SECTION_ALL_BAGS then
    possibleTabs[activeTabID] = true
    possibleTabs[1] = true -- fallback
  end

  local showAll = database:GetShowAllFreeSpace(kind)
  -- The slot-order view draws a bag's empty slots in place, so Free Space leaves those bags out: an
  -- entry's button is one of those slots, and a slot has one button, so the section took it out of
  -- its place and left a gap.
  local slotOrder = viewBagView == const.BAG_VIEW.SECTION_ALL_BAGS
  local function inFreeSpace(bagid, tabID)
    return IncludeBagInFreeSpace(kind, bagid, tabID) and not (slotOrder and drawsEmptySlotsInPlace(bagid))
  end

  for tabID in pairs(possibleTabs) do
    tabs[tabID] = {
      items = {},
      categories = {},
      emptySlotsSorted = {},
      emptySlotsByBag = {},
      emptySlots = {},
      totalItems = 0,
      hiddenItems = 0,
    }
    local freeSpaceButtons = {}

    -- Filter emptySlotsSorted and emptySlotsByBag for this tab
    for _, item in ipairs(emptySlotsSorted or {}) do
      if inFreeSpace(item.bagid, tabID) then
        table.insert(tabs[tabID].emptySlotsSorted, item)
      end
    end

    if emptySlotsByBag then
      for bagid, info in pairs(emptySlotsByBag) do
        if inFreeSpace(bagid, tabID) then
          tabs[tabID].emptySlotsByBag[bagid] = { name = info.name, count = info.count, family = info.family }
          tabs[tabID].emptySlots[info.name] = (tabs[tabID].emptySlots[info.name] or 0) + info.count
        end
      end
    end

    if showAll then
      for _, item in ipairs(tabs[tabID].emptySlotsSorted) do
        local info = item.itemInfo or {}
        table.insert(freeSpaceButtons, {
          slotkey = item.slotkey,
          bagid = item.bagid,
          slotid = item.slotid,
          count = 1,
          isIndividual = true,
          key = item.slotkey,
          -- Like the aggregated button below: the bag's name and glyph, and no itemQuality (the
          -- empty slot's itemInfo carries its bag's quality, which drew a colored border).
          itemInfo = {
            emptySlotName = info.emptySlotName,
            emptySlotFamilyIcon = info.emptySlotFamilyIcon,
          },
        })
      end
    else
      local aggregatedCounts = {}
      local firstSlotKeyForSubclass = {}
      local familyForSubclass = {}
      for bagid, info in pairs(tabs[tabID].emptySlotsByBag) do
        aggregatedCounts[info.name] = (aggregatedCounts[info.name] or 0) + info.count
        if familyForSubclass[info.name] == nil then
          familyForSubclass[info.name] = info.family
        end
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
            table.insert(freeSpaceButtons, {
              slotkey = slotKey,
              bagid = tonumber(freeSlotBag),
              slotid = tonumber(freeSlotID),
              count = freeSlotCount,
              isIndividual = false,
              key = name,
              -- The aggregated "stack" button is a counter, not a real item slot, so it carries
              -- no itemQuality (nil => no quality border). Reusing the harvested slot's itemInfo
              -- would leak the bag's quality (e.g. the reagent bag's) and paint a colored border.
              itemInfo = {
                emptySlotName = name,
                emptySlotFamilyIcon = self:GetEmptySlotFamilyIcon(familyForSubclass[name]),
              },
            })
          end
        end
      end
    end

    -- The bag draws a Free Space section only for a tab whose data carries freeSpace.
    if #freeSpaceButtons > 0 then
      tabs[tabID].freeSpace = { showAll = showAll, buttons = freeSpaceButtons }
    end
  end

  -- Assign items to their respective tabs, leaving out what a category hides in this bag (a gap it left too)
  -- and counting it for the bag's footer.
  local hiddenCategories = {}
  for _, item in ipairs(sortedItems) do
    local category = item.itemInfo and item.itemInfo.category or ""
    if hiddenCategories[category] == nil then
      hiddenCategories[category] = categories:HiddenIn(category, kind)
    end
    local hides = hiddenCategories[category]
    for tabID, tabData in pairs(tabs) do
      if ItemBelongsToTab(kind, item, tabID, viewBagView) then
        local counts = not item.isFreeSlot and not item.isItemGap
        if not hides then
          table.insert(tabData.items, item)
          if counts then
            tabData.totalItems = tabData.totalItems + 1
          end
        elseif counts then
          tabData.hiddenItems = tabData.hiddenItems + 1
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
  realSlotInfo.builtForView = database.GetBagView and database:GetBagView(kind) or nil
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

  local ev = "items/RefreshBackpack/Done"
  if kind == const.BAG_KIND.BANK then
    ev = "items/RefreshBank/Done"
  elseif kind == const.BAG_KIND.GUILD then
    ev = "items/RefreshGuildBank/Done"
  end
  events:SendMessage(ctx, ev, realSlotInfo)
end

function items:Phase3_ExtractPreviousState(kind)
  local realSlotInfo = self.slotInfo[kind]
  local previousItems = realSlotInfo and realSlotInfo.itemsBySlotKey or {}
  local previousTotalItems = realSlotInfo and realSlotInfo.totalItems or 0
  local previousSortedItems = realSlotInfo and realSlotInfo.sortedItems or {}
  return previousItems, previousTotalItems, previousSortedItems
end

-- RunRefresh executes the full data sweep for one bag kind inline in the CURRENT
-- coroutine (it calls async:Yield() once, after the harvest). It must be driven from
-- within a coroutine -- either ProcessRefresh's async:Do wrapper (direct/test callers)
-- or the Refresh scheduler's serialized unit coroutine (production). Keeping the core
-- driveable is what lets the scheduler run bank-then-backpack sequentially in a single
-- coroutine, so no two sweeps are ever in flight at once.
---@param ectx Context
---@param kind BagKind
function items:RunRefresh(ectx, kind)
  -- A derive recalculates from the items the last read committed, reading no bag slot
  -- (refresh-scheduler.md §10). A kind with no committed items has nothing to recalculate:
  -- never read (deriving it would take the kind's first sweep, which must be a read that
  -- marks nothing as new) or the bank cleared on close (it would draw an empty bank).
  local wipeRequested = ectx:Get("wipe") == true
  local derive = ectx:Get("derive") == true and not wipeRequested
  local committedItems
  if not wipeRequested and self.slotInfo and self.slotInfo[kind] then
    committedItems = self.slotInfo[kind].itemsBySlotKey
  end
  if derive and (committedItems == nil or next(committedItems) == nil) then
    return
  end

  -- The first sweep after a sort shows the sort. It re-reads every bag of the kind, even
  -- when a BAG_UPDATE named only some: the sort may have moved items anywhere, and the
  -- new-item flags it cleared live on every bag (an untouched bag would keep its stale
  -- glow). It also rebuilds the layout from scratch, collapsing held gaps. A derive leaves it
  -- pending, unless it is what the sort's fallback found a sort that moved nothing needs
  -- (showsSort, SortLeaves).
  local sortSweep = (not derive or ectx:Get("showsSort") == true) and self._sortSweepPending[kind] == true
  if sortSweep then
    ectx:Delete("targetedBags")
    ectx:Set("resetLayout", true)
  end

  -- Rebuild the equipment-set location map before harvesting. The map is keyed by
  -- physical (bag, slot), and the harvest reads it per slot via
  -- equipmentSets:GetItemSets. Rebuilding it here (same frame as the harvest)
  -- keeps gear-set labels correct as items are looted, moved, equipped, or the
  -- active set changes; without it the map only reflects login state, so looted
  -- items inherit stale set labels and moved set items lose theirs.
  equipmentSets:Update()

  local bagList = self:Phase1_DetermineBags(ectx, kind)
  -- A wipe re-reads every slot; any other read keeps the committed item of each slot whose
  -- contents have not changed (ReuseHarvestedSlot); a derive reads no slot.
  local itemData, equipmentData
  -- The changes the client had reported when this read harvested: those its commit shows.
  local readAt = self._bagChanges
  if derive then
    itemData, equipmentData = self:Phase2_Rederive(kind, committedItems)
  else
    itemData, equipmentData = self:Phase2_Harvest(kind, bagList, committedItems, wipeRequested)
  end

  -- The harvest captured this frame's client state. Everything below runs on the
  -- next frame against the state committed by then.
  async:Yield()

  -- A guild bank read whose visit ended while it waited commits nothing: the guild bank's items
  -- were forgotten when it closed (ClearGuildBankCache).
  if kind == const.BAG_KIND.GUILD and not addon.atGuildBank then
    return
  end

  if self._firstLoad[kind] == true then
    self._firstLoad[kind] = false
    ectx:Set("wipe", true)
  end

  local previousItems, previousTotalItems, previousSortedItems = self:Phase3_ExtractPreviousState(kind)

  local targetedBags = ectx:Get("targetedBags")
  local isWipe = ectx:Get("wipe") == true
  -- A recalculation works every item's category out again unless it says nothing categories read
  -- changed (categoriesUnchanged), and so does a read that absorbed such a recalculation
  -- (recategorize); a wipe re-reads every item anyway (data-loader.md §18).
  if isWipe or ectx:Get("recategorize") == true or (derive and ectx:Get("categoriesUnchanged") ~= true) then
    self._categoryGeneration[kind] = self._categoryGeneration[kind] + 1
  end
  if isWipe then
    self._drawGeneration[kind] = self._drawGeneration[kind] + 1
    self:InvalidateUpgrades(false)
  elseif ectx:Get("restyle") == true then
    -- A setting the buttons draw from changed: every button of the kind draws in full.
    self._drawGeneration[kind] = self._drawGeneration[kind] + 1
  end

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
  self:MarkAddedItemsRecent(ectx, kind, previousItems, itemData)

  local emptySlots, emptySlotsByBag = self:Phase5_UpdateFreeSlots(ectx, kind, itemData)

  local emptySlotByBagAndSlot, freeSlotKeys, freeSlotKeysByBag, emptySlotsSorted, totalItems = self:Phase6_EnrichData(ectx, kind, itemData, emptySlotsByBag)

  local stackedInteracting = addon.atInteracting == true
  local visibleItemsBySlotKey, stackData = self:Phase7_ApplyVirtualStacks(kind, itemData)
  self:CountItemTotals(itemData)
  local sectionLayouts = self:Phase8_EnrichCategories(ectx, kind, itemData, emptySlotByBagAndSlot)
  local sortedItems = self:BuildOrderedItems(ectx, kind, visibleItemsBySlotKey, emptySlotByBagAndSlot, previousSortedItems)
  local tabData = self:Phase10_PartitionIntoTabs(ectx, kind, sortedItems, emptySlotsSorted, emptySlotsByBag, freeSlotKeysByBag, itemData)

  self:Phase11_CommitAndDispatch(ectx, kind, itemData, equipmentData, previousItems, previousTotalItems, emptySlots, emptySlotsByBag, emptySlotByBagAndSlot, totalItems, emptySlotsSorted, freeSlotKeys, freeSlotKeysByBag, visibleItemsBySlotKey, stackData, sectionLayouts, sortedItems, tabData)
  self._stackedInteracting[kind] = stackedInteracting

  -- Only a committed sweep counts as having shown the sort; one that failed above leaves
  -- the flag set for the next sweep or the fallback.
  if sortSweep then
    self._sortSweepPending[kind] = false
  end
  -- Likewise only a committed read shows the changes its harvest read.
  if not derive then
    self:MarkBagsRead(bagList, readAt)
  end
end

-- MarkBagUnread records that the client reported a change to a bag's contents (BAG_UPDATE, and the
-- other events a read of the bag follows: refresh:OnEnable). From then until a read that harvested
-- the bag after the change has committed, the bag's committed items are not what it holds: a
-- recalculation leaves them as they were and asks the client nothing about them
-- (Phase2_Rederive). That read waits for the bag's item data (the loader) and then for its turn
-- in the queue, and a recalculation can run in between. Changes are numbered, so one made while a
-- read was under way (after its harvest) still marks the bag when that read commits.
---@param bagID number
function items:MarkBagUnread(bagID)
  self._bagChanges = self._bagChanges + 1
  self._unreadBags[bagID] = self._bagChanges
end

-- MarkBagsRead clears, for each bag a committed read harvested, the changes made before its
-- harvest (readAt: the number of changes reported by then).
---@param bagList table<number, number>
---@param readAt number
function items:MarkBagsRead(bagList, readAt)
  for bagID in pairs(bagList) do
    local changedAt = self._unreadBags[bagID]
    if changedAt ~= nil and changedAt <= readAt then
      self._unreadBags[bagID] = nil
    end
  end
end

-- MarkSortSweepPending records that a sort of this kind was requested and its result has
-- not been shown yet. Refresh calls it before issuing the sort.
---@param kind BagKind
function items:MarkSortSweepPending(kind)
  self._sortSweepPending[kind] = true
end

---@param kind BagKind
---@return boolean
function items:IsSortSweepPending(kind)
  return self._sortSweepPending[kind] == true
end

-- SortSweepShown says a sort has nothing left to show.
---@param kind BagKind
function items:SortSweepShown(kind)
  self._sortSweepPending[kind] = false
end

-- SortLeaves says what a sort no sweep has shown yet still needs, once its fallback fires. "read": a
-- bag of the kind changed since it was read, or a slot holds other than it was read holding (the client
-- does not always say, refresh-scheduler.md §10), so the sort may have moved something; or nothing has
-- been read yet. Otherwise the sort moved nothing, and what it did do is clear Recent Items and the
-- new-item flags, and ask for a fresh layout: "recalculate" when anything on screen shows otherwise, or
-- an item was read before its data had loaded, which needs no other slot read; "nothing" when what the
-- bags committed already looks like that.
---@param kind BagKind
---@return "read"|"recalculate"|"nothing"
function items:SortLeaves(kind)
  local slotInfo = self.slotInfo[kind]
  local committed = slotInfo and slotInfo.itemsBySlotKey
  if committed == nil or next(committed) == nil or slotInfo.sortedItems == nil then
    return "read"
  end
  local tables = kind == const.BAG_KIND.BACKPACK and { const.BACKPACK_BAGS } or { const.BANK_BAGS, const.ACCOUNT_BANK_BAGS }
  for _, bags in pairs(tables) do
    for bagID in pairs(bags) do
      if self._unreadBags[bagID] ~= nil then
        return "read"
      end
    end
  end
  local recentName = L:G("Recent Items")
  local recalculate = false
  for _, item in pairs(committed) do
    local info = item.itemInfo
    if C_Container.GetContainerItemID(item.bagid, item.slotid) ~= info.itemID then
      return "read"
    end
    if item.harvestIncomplete or info.isNewItem or info.category == recentName then
      recalculate = true
    end
  end
  if recalculate then
    return "recalculate"
  end
  local fresh = self:Phase9_Sort(kind, slotInfo.visibleItemsBySlotKey, slotInfo.emptySlotByBagAndSlot)
  local shown = slotInfo.sortedItems
  if #fresh ~= #shown then
    return "recalculate"
  end
  for i = 1, #fresh do
    if fresh[i].slotkey ~= shown[i].slotkey then
      return "recalculate"
    end
  end
  return "nothing"
end

function items:ProcessRefresh(ctx, kind)
  async:Do(ctx, function(ectx)
    self:RunRefresh(ectx, kind)
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

-- GroupedCategory returns the category an item placed in a category by hand shows in: the category, or
-- its sub-category for the item when it groups its members (its groupBy), made when missing.
---@param ctx Context
---@param name string
---@param filter? CustomCategoryFilter
---@param data ItemData
---@return string
function items:GroupedCategory(ctx, name, filter, data)
  local groupBy = filter and filter.groupBy or const.SEARCH_CATEGORY_GROUP_BY.NONE
  if groupBy == const.SEARCH_CATEGORY_GROUP_BY.NONE then
    return name
  end
  local suffix = self:GetGroupBySuffix(data, groupBy)
  if not suffix or suffix == "" then
    return name
  end
  local grouped = name .. " - " .. suffix
  self:ensureSubcategory(ctx, filter, grouped)
  return grouped
end

-- ensureSubcategory makes a grouped category's sub-category for one group, unless it exists: used in
-- the same bags, with the same color and priority.
---@private
---@param ctx Context
---@param filter CustomCategoryFilter
---@param name string
function items:ensureSubcategory(ctx, filter, name)
  if categories:DoesCategoryExist(name) then
    return
  end
  categories:CreateCategory(ctx, {
    name = name,
    itemList = {},
    enabled = filter.enabled,
    dynamic = true,
    isGroupBySubcategory = true,
    groupByParent = filter.name,
    priority = filter.priority or 10,
    color = filter.color,
  })
end

function items:RefreshSearchCache(kind, itemData)
  itemData = itemData or (self.slotInfo[kind] and self.slotInfo[kind].itemsBySlotKey) or {}
  self:WipeSearchCache(kind)
  if not categories or not categories.GetSortedSearchCategories then return end
  local ctx = context:New('RefreshSearchCache')
  local categoryTable = categories:GetSortedSearchCategories()

  for _, categoryFilter in ipairs(categoryTable) do
    if categoryFilter.enabled[kind] then
      local results = search:Search(categoryFilter.searchCategory.query)
      local groupBy = categoryFilter.groupBy or const.SEARCH_CATEGORY_GROUP_BY.NONE
      local priority = categoryFilter.priority or 10

      for slotkey, match in pairs(results) do
        -- A rule never takes an item its category ignores (Ignored Items): the next one does.
        local matched = itemData[slotkey]
        local ignored = categoryFilter.ignoredItems ~= nil and matched ~= nil and not matched.isItemEmpty
          and categoryFilter.ignoredItems[matched.itemInfo.itemID] == true
        if match and not ignored then
          local categoryName = categoryFilter.name

          -- A grouping category's match shows in its sub-category for the item.
          if groupBy ~= const.SEARCH_CATEGORY_GROUP_BY.NONE then
            local currentItem = itemData[slotkey]
            if currentItem and not currentItem.isItemEmpty then
              local suffix = self:GetGroupBySuffix(currentItem, groupBy)
              if suffix and suffix ~= "" then
                categoryName = categoryFilter.name .. " - " .. suffix
                self:ensureSubcategory(ctx, categoryFilter, categoryName)
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

-- IsNewItem decides Recent Items membership: an item is recent while it has a timer. The
-- client's new-item flag only starts the timer (SeedNewItemTimer) and drives the glow; the
-- client clears it on hover and when Blizzard's own bag frames close, at moments unrelated
-- to the timer. Timers end only when the bag closes (ExpireRecentItems), so nothing leaves
-- Recent Items while the bag is open.
function items:IsNewItem(data)
  if not data or data.isItemEmpty then return false end
  local guid = data.itemInfo and data.itemInfo.itemGUID
  local timerTable = self._newItemTimers and self._newItemTimers[resolveKind(self, data)]
  return guid ~= nil and timerTable ~= nil and timerTable[guid] ~= nil
end

-- ExpireRecentItems ends the Recent Items timer of every item of this kind that is at least
-- the configured duration old, and returns true when any did. It runs only when the bag
-- closes. Each expired item's client new-item flag is cleared as well: the harvest starts a
-- timer for any item still flagged, which would make it recent again.
---@param kind BagKind
---@return boolean
function items:ExpireRecentItems(kind)
  local timers = self._newItemTimers and self._newItemTimers[kind]
  if not timers then return false end
  local limit = database:GetNewItemTime() or 30
  local now = time()
  local expired = {}
  local anyExpired = false
  for guid, startedAt in pairs(timers) do
    if now - startedAt >= limit then
      expired[guid] = true
      anyExpired = true
    end
  end
  if not anyExpired then return false end

  for guid in pairs(expired) do
    timers[guid] = nil
  end
  local slotInfo = self.slotInfo and self.slotInfo[kind]
  if slotInfo and slotInfo.itemsBySlotKey and _G.C_NewItems and _G.C_NewItems.RemoveNewItem then
    for _, item in pairs(slotInfo.itemsBySlotKey) do
      if not item.isItemEmpty and item.itemInfo and expired[item.itemInfo.itemGUID] then
        _G.C_NewItems.RemoveNewItem(item.bagid, item.slotid)
      end
    end
  end
  return true
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
  if data and data.itemInfo and data.itemInfo.itemGUID and data.itemInfo.itemGUID ~= "" then
    local kind = resolveKind(self, data)
    local timerTable = self._newItemTimers and self._newItemTimers[kind]
    if timerTable and timerTable[data.itemInfo.itemGUID] == nil then
      timerTable[data.itemInfo.itemGUID] = time()
      data.itemInfo.isNewItem = true
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
  return self.equipmentCache and self.equipmentCache[slot]
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
---@param previousItems? table<string, ItemData> Committed items; a slot whose contents are unchanged keeps its item.
---@param rereadEquipment? boolean Read every equipped slot again.
---@return table<string, ItemData> itemData A flat table of physical item datas indexed by slotKey
---@return table<number, ItemData> equipmentData A flat table of equipped item datas indexed by inventory slot ID
function items:Harvest(kind, bagList, includeEquipment, previousItems, rereadEquipment)
  local itemData = {}
  local equipmentData = {}

  -- 1. Sweep physical container bags
  for bagid in pairs(bagList) do
    local size = C_Container.GetContainerNumSlots(bagid)
    if size and size > 0 then
      for slotid = 1, size do
        local slotkey = self:GetSlotKeyFromBagAndSlot(bagid, slotid)
        local data, containerInfo
        if previousItems then
          data, containerInfo = self:ReuseHarvestedSlot(kind, previousItems[slotkey], bagid, slotid)
        end
        if not data then
          data = {}
          ---@cast data +ItemData
          data.bagid, data.slotid = bagid, slotid
          self:AttachItemInfo(data, kind, containerInfo)
        end
        itemData[slotkey] = data
      end
    end
  end

  -- 2. Sweep equipment if requested
  if includeEquipment then
    equipmentData = self:HarvestEquipment(rereadEquipment)
  end

  return itemData, equipmentData
end

---@param data ItemData|nil
---@return string
local function equipmentSignature(data)
  if not data then
    return ""
  end
  local info = data.itemInfo
  return tostring(info.itemLink) .. "|" .. tostring(info.currentItemLevel) .. "|" .. tostring(info.itemEquipLoc)
end

-- HarvestEquipment returns the equipped gear (inventory slot -> ItemData) and publishes it
-- as equipmentCache at once, so upgrade verdicts always compare with the gear last read,
-- even if the rest of the sweep fails. A slot keeps its previous read when its link and
-- current item level (two cheap client calls) are unchanged, PLAYER_EQUIPMENT_CHANGED has
-- not named it, and its previous read was not cold; otherwise it is read again with
-- GetEquipmentInfo. rereadAll (a wipe) and level or scaling events read every slot again.
-- When a slot's item, item level or equip location changed, or the gear stopped reading
-- cold, every kept upgrade verdict is invalidated. The gear is read by backpack sweeps, which
-- resolve every backpack verdict after the harvest, so only the open bank is refreshed: a
-- backpack refresh would re-read the bags to find what this sweep already shows (it made the
-- first gear read of every login cost a second read of the bags).
---@param rereadAll? boolean
---@return table<number, ItemData>
function items:HarvestEquipment(rereadAll)
  if self._equipmentDirtyAll then
    self._equipmentDirtyAll = false
    rereadAll = true
  end
  local equipmentData = {}
  local read = {}
  local changed = false
  local currentItemLevel = C_Item.GetCurrentItemLevel
  for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
    local link = GetInventoryItemLink("player", slot)
    local level
    if link and currentItemLevel then
      local location = self._equipmentLocations[slot]
      if not location then
        location = ItemLocation:CreateFromEquipmentSlot(slot)
        self._equipmentLocations[slot] = location
      end
      level = currentItemLevel(location)
    end
    local entry = self._equipped[slot]
    local keep = entry ~= nil and not rereadAll and not self._equipmentDirty[slot]
      and not entry.incomplete and entry.link == link and entry.level == level
    if not keep then
      local itemMixin = Item:CreateFromEquipmentSlot(slot)
      local data
      if not itemMixin:IsItemEmpty() then
        data = self:GetEquipmentInfo(itemMixin)
      end
      if equipmentSignature(entry and entry.data) ~= equipmentSignature(data) then
        changed = true
      end
      entry = {
        link = link,
        level = level,
        data = data,
        incomplete = data ~= nil and (data.harvestIncomplete == true or link == nil),
      }
    end
    read[slot] = entry
  end
  -- Nothing is recorded until every slot was read: if a read fails, the next sweep reads
  -- the changed slots again and still sees the change.
  local incomplete = false
  for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
    local entry = read[slot]
    self._equipped[slot] = entry
    self._equipmentDirty[slot] = nil
    if entry and entry.data then
      equipmentData[entry.data.inventorySlots[1]] = entry.data
    end
    if entry and entry.incomplete then
      incomplete = true
    end
  end
  if self._equipmentIncomplete and not incomplete then
    changed = true
  end
  self._equipmentIncomplete = incomplete
  self.equipmentCache = equipmentData
  if changed then
    self:InvalidateUpgrades(false)
    if addon.atBank then
      self:RequestUpgradeRefresh(false, true)
    end
  end
  return equipmentData
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

-- ClientNewItemFlag is an item's new-item flag (the glow): the client's own flag alone. The
-- Recent Items timer (IsNewItem with a GUID) decides the category, not the glow, so an item
-- the player hovered (which drops the client flag) stops glowing but stays in Recent Items.
-- A method so captures record what the client reported for each slot read.
---@param bagid number
---@param slotid number
---@return boolean
function items:ClientNewItemFlag(bagid, slotid)
  return _G.C_NewItems ~= nil and _G.C_NewItems.IsNewItem ~= nil
    and _G.C_NewItems.IsNewItem(bagid, slotid) and true or false
end

-- sameList says two lists (or nils) hold the same values in the same order.
---@param a? table
---@param b? table
---@return boolean
local function sameList(a, b)
  if a == b then return true end
  if a == nil or b == nil or #a ~= #b then return false end
  for i = 1, #a do
    if a[i] ~= b[i] then return false end
  end
  return true
end

-- sameQuest says two quest infos (C_Container.GetContainerItemQuestInfo) are alike.
---@param a? table
---@param b? table
---@return boolean
local function sameQuest(a, b)
  if a == nil or b == nil then return a == b end
  return a.isQuestItem == b.isQuestItem and a.questID == b.questID and a.isActive == b.isActive
end

-- SeedNewItemTimer starts the Recent Items timer of a new item the first time a sweep sees
-- it, so it stays recent after the client drops its own new-item flag. It returns what it
-- decided, which captures record: "started", "running" (the GUID already has a timer, which
-- is not restarted), "not new" (the client does not flag the item) or "no guid".
---@param kind BagKind
---@param data ItemData
---@return string
function items:SeedNewItemTimer(kind, data)
  local guid = data.itemInfo.itemGUID
  if not data.itemInfo.isNewItem then return "not new" end
  if not guid or guid == "" then return "no guid" end
  local timers = self._newItemTimers and self._newItemTimers[kind]
  if not timers then return "no timers" end
  if timers[guid] ~= nil then return "running" end
  timers[guid] = time()
  return "started"
end

-- ReuseHarvestedSlot returns a slot's committed item when the slot still holds the same
-- item in the same state, so a sweep only re-reads the slots that changed. The item is the
-- same when the client's container info (item, link, count, name, icon, quality, lock,
-- bound, readable, loot, filtered, no-value), the item's GUID and its current item level
-- (which scaling changes without changing the link) all match what the item was read from. The fields that change without the slot changing are refreshed on the kept
-- item: the new-item flag, gear sets, quest state and tooltip text. Everything the later
-- phases derive (category, virtual stack, search match, upgrade, context match) is
-- recomputed by them every sweep. Nothing else on the kept item is written here: it is the
-- committed item until this sweep commits a frame later, and the bag may draw from it in
-- between (a virtual stack root must still show its total).
--
-- A slot is read again when it was empty, when it was read while the client had no item
-- info for it (cold cache at login, which AttachItemInfo heals on a later read), or when
-- the check fails. In the last case the container info it read is returned so the harvest
-- does not read it twice.
--
-- Like an item in a bag the sweep did not visit, a kept item does not refresh state the
-- client changes without changing the slot: a refundable purchase's binding expiring, or
-- an appearance being collected. A wipe sweep re-reads everything.
---@param kind BagKind
---@param previous ItemData|nil
---@param bagid number
---@param slotid number
---@return ItemData|nil kept
---@return ContainerItemInfo|nil containerInfo
function items:ReuseHarvestedSlot(kind, previous, bagid, slotid)
  if not previous or previous.isItemEmpty or previous.harvestIncomplete or previous.kind ~= kind then
    return nil, nil
  end
  local info = C_Container.GetContainerItemInfo(bagid, slotid)
  if not info then
    return nil, nil
  end
  local old = previous.containerInfo
  if info.itemID ~= old.itemID
    or info.hyperlink ~= old.hyperlink
    or info.stackCount ~= old.stackCount
    or info.itemName ~= previous.rawItemName
    or info.iconFileID ~= previous.rawIconFileID
    or info.quality ~= previous.rawQuality
    or info.isLocked ~= old.isLocked
    or info.isBound ~= old.isBound
    or info.isReadable ~= old.isReadable
    or info.hasLoot ~= old.hasLoot
    or info.isFiltered ~= old.isFiltered
    or info.hasNoValue ~= old.hasNoValue then
    return nil, info
  end
  local itemLoader = addon:GetModule("ItemLoader", true)
  local itemMixin = itemLoader and itemLoader:GetItemMixinFromSlotKey(previous.slotkey) or Item:CreateFromBagAndSlot(bagid, slotid) --[[@as ItemMixin]]
  local itemLocation = itemMixin:GetItemLocation()
  local itemGUID = C_Item.GetItemGUID(itemLocation) or ""
  local itemInfo = previous.itemInfo
  if itemGUID ~= itemInfo.itemGUID then
    return nil, info
  end
  -- Scaling can change an item's current item level without changing its link.
  if C_Item.GetCurrentItemLevel then
    local level = C_Item.GetCurrentItemLevel(itemLocation)
    if level ~= nil and level ~= itemInfo.currentItemLevel then
      return nil, info
    end
  end

  self:RefreshKeptItem(kind, previous, bagid, slotid, itemGUID)
  return previous, info
end

-- refundableAt says whether the item at a location can still be refunded. It is read with the slot,
-- as every location property: CanBeRefunded takes an ItemLocation that holds an item (not an
-- EmptiableItemLocation, ItemDocumentation.lua) and raises an error for an empty one, so it is asked
-- only by reads that know the slot holds the item.
---@param itemLocation ItemLocationMixin
---@return boolean
local function refundableAt(itemLocation)
  return C_Item.CanBeRefunded ~= nil and C_Item.CanBeRefunded(itemLocation) == true
end

-- RefreshKeptItem refreshes the fields of a kept item that change without its slot
-- changing, each computed exactly as AttachItemInfo computes it: quest state, tooltip text
-- (a cache hit, or a re-scan after TOOLTIP_DATA_UPDATE dropped it), gear sets (the set map
-- is rebuilt every sweep), the new-item flag and whether it can still be refunded (its refund
-- window ends). The caller has checked that the slot still holds the item (its GUID).
---@param kind BagKind
---@param item ItemData
---@param bagid number
---@param slotid number
---@param itemGUID string
function items:RefreshKeptItem(kind, item, bagid, slotid, itemGUID)
  local itemInfo = item.itemInfo
  local oldQuest, oldTooltip, oldSets = item.questInfo, itemInfo.tooltipText, itemInfo.equipmentSets
  item.questInfo = C_Container.GetContainerItemQuestInfo(bagid, slotid)
  if not item.questInfo then
    item.questInfo = {
      isQuestItem = false,
      isActive = false,
    }
  end
  ---@class TooltipScanner: AceModule
  local tooltipScanner = addon:GetModule('TooltipScanner')
  local tooltipText, tooltipMarks = tooltipScanner:GetTooltipText(bagid, slotid, itemGUID)
  itemInfo.tooltipText = tooltipText or ""
  -- Marks come from the same scan as the text, so they change only with it.
  itemInfo.tooltipMarks = tooltipMarks
  itemInfo.equipmentSets = equipmentSets:GetItemSets(bagid, slotid)
  itemInfo.isNewItem = self:ClientNewItemFlag(bagid, slotid)
  itemInfo.refundable = refundableAt(ItemLocation:CreateFromBagAndSlot(bagid, slotid))
  self:SeedNewItemTimer(kind, item)
  -- Quest state, tooltip text and gear sets are inputs of the item's category and search entry:
  -- when one changed, nothing kept about the item stands (data-loader.md §18).
  if itemInfo.tooltipText ~= oldTooltip or not sameList(itemInfo.equipmentSets, oldSets)
    or not sameQuest(item.questInfo, oldQuest) then
    item.derived = nil
  end
  self:RefreshCharacterState(item)
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
  elseif guildTabOf(bid) then
    return const.BAG_KIND.GUILD
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

-- GetEmptySlotFamilyIcon returns the small centered overlay icon for an empty slot that
-- belongs to a specialized bag, keyed by the bag's family bit value (see
-- const.ITEM_BAG_FAMILY). Generic bags (family 0 or nil) return nil, meaning no overlay.
-- A specialized family with no per-family override falls back to the shared default glyph.
---@param family number|nil
---@return string|nil
function items:GetEmptySlotFamilyIcon(family)
  if not family or family == 0 then
    return nil
  end
  local overrides = const.EMPTY_SLOT_FAMILY_ICON
  return (overrides and overrides[family]) or const.EMPTY_SLOT_FAMILY_ICON_DEFAULT
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

-- ReadLinkInfo reads C_Item.GetItemInfo for the slot's link (the item in the slot), where the item
-- ID describes its base item: its required level, max stack, sell price and bind type. Only an item
-- link ("item:"; a caged pet's is battlepet:) is read; loaded is false when its data has not loaded.
---@param itemLink? string
---@return number? minLevel, number? stackSize, number? sellPrice, Enum.ItemBind? bindType, boolean loaded
function items:ReadLinkInfo(itemLink)
  if itemLink == nil or not strfind(itemLink, "item:") then
    return nil, nil, nil, nil, true
  end
  local name, _, _, _, minLevel, _, _, stackSize, _, _, sellPrice, _, _, bindType = C_Item.GetItemInfo(itemLink)
  return minLevel, stackSize, sellPrice, bindType, name ~= nil
end

-- SlotLevelsOf works out an equipment item's slot values (search-indexing.md §16): the lowest item
-- level worn in its slots, 0 when nothing is worn there (slotequipped, Vendor's CurrentEquippedLevel:
-- a one-hander counts the off hand only with dual wield, a Warrior's two-hander both hands), and the
-- character's best item level in its slot (slotbest, Vendor's WatermarkLevel,
-- C_ItemUpgrade.GetHighWatermarkForItem). Nil for an item that is not equipment or was read before
-- its data loaded; slotequipped also before the worn gear has been read.
---@param item ItemData
---@return number? slotEquipped, number? slotBest
function items:SlotLevelsOf(item)
  local traits = not item.isItemEmpty and item.itemInfo.traits
  if not traits or not traits.isEquipment then
    return nil, nil
  end
  local best
  local upgrade = _G.C_ItemUpgrade
  if upgrade and upgrade.GetHighWatermarkForItem and item.itemInfo.itemLink then
    best = upgrade.GetHighWatermarkForItem(item.itemInfo.itemLink)
  end
  if self.equipmentCache == nil then
    return nil, best
  end
  local slots = item.inventorySlots or {}
  local equipLoc = item.itemInfo.itemEquipLoc
  if equipLoc == "INVTYPE_WEAPON" and not (_G.CanDualWield and _G.CanDualWield()) then
    slots = { INVSLOT_MAINHAND }
  elseif equipLoc == "INVTYPE_2HWEAPON" and _G.UnitClass and select(3, UnitClass("player")) == 1 then
    slots = { INVSLOT_MAINHAND, INVSLOT_OFFHAND }
  end
  local lowest = 0
  for _, slot in ipairs(slots) do
    local worn = self.equipmentCache[slot]
    local level = worn and worn.itemInfo.currentItemLevel
    if level and (lowest == 0 or level < lowest) then
      lowest = level
    end
  end
  return lowest, best
end

-- CanUseItem says whether the character can use an item (C_PlayerInfo.CanUseItem: proficiency,
-- level, profession, reputation), or nil on a client without the API. It follows the character,
-- so a kept item is asked again (RefreshKeptItem).
---@param itemID number
---@return boolean?
function items:CanUseItem(itemID)
  local api = _G.C_PlayerInfo
  if api and api.CanUseItem then
    return api.CanUseItem(itemID) == true
  end
  return nil
end

-- PetCountsOf says how many of a battle pet species the account has and may have
-- (C_PetJournal.GetNumCollectedInfo: numOwned, maxAllowed, as Blizzard_PetBattleUI.lua reads it), or
-- nil until the pet journal has loaded. Login captures had C_PetJournal.GetNumPets report 0 owned
-- until it loaded, just before PET_JOURNAL_LIST_UPDATE; a /reload capture had it report the
-- account's pets from the start, with the event 59 ms after the first bag read began. So the journal
-- has loaded once the event fired (OnCharacterStateChanged) or the account owns a pet.
---@param speciesID? number
---@return number? owned, number? limit
function items:PetCountsOf(speciesID)
  local api = _G.C_PetJournal
  if speciesID == nil or not (api and api.GetNumCollectedInfo) then
    return nil
  end
  if not self._petJournalLoaded and api.GetNumPets then
    local _, owned = api.GetNumPets()
    self._petJournalLoaded = owned ~= nil and owned > 0
  end
  if not self._petJournalLoaded then
    return nil
  end
  return api.GetNumCollectedInfo(speciesID)
end

-- AppearanceCollectionLoaded says whether the account's appearance collection has loaded: some
-- appearance collected (C_TransmogCollection.GetCategoryCollectedCount over every category but
-- None). Captures had 0 until the player entered the world, then 3,083, on a login and on a reload;
-- TRANSMOG_COLLECTION_UPDATED fired at login with 0 collected, so it is no sign. Asked at most once a
-- frame until it has loaded, then never again; an account with no appearance never loads.
---@return boolean
function items:AppearanceCollectionLoaded()
  if self._appearancesLoaded then
    return true
  end
  local now = GetTime()
  if self._appearancesCheckedAt == now then
    return false
  end
  self._appearancesCheckedAt = now
  local api, collectionTypes = _G.C_TransmogCollection, Enum and Enum.TransmogCollectionType
  if not (api and api.GetCategoryCollectedCount and collectionTypes) then
    return false
  end
  for _, category in pairs(collectionTypes) do
    if category ~= collectionTypes.None and (api.GetCategoryCollectedCount(category) or 0) > 0 then
      self._appearancesLoaded = true
      return true
    end
  end
  return false
end

-- AppearanceStateOf says whether an item's appearance is collected, every way Vendor asks
-- (itemproperties.lua; its soulbound shortcut aside): through its own source, any source of the
-- appearance, or the item itself (PlayerHasTransmogByItemInfo); and whether its own source is. A
-- retail dump had all three agree on 141 items, but for 3 artifacts PlayerHasTransmogByItemInfo said
-- no where the others said yes. Nil for an item without an appearance or before the collection has
-- loaded.
---@param traits? ItemTraits
---@param itemLink? string
---@return boolean? appearanceKnown, boolean? sourceKnown
function items:AppearanceStateOf(traits, itemLink)
  if not traits or traits.sourceID == nil or not self:AppearanceCollectionLoaded() then
    return nil
  end
  local api = _G.C_TransmogCollection
  local source = api.PlayerHasTransmogItemModifiedAppearance
    and api.PlayerHasTransmogItemModifiedAppearance(traits.sourceID) == true
  if source then
    return true, true
  end
  if api.GetAppearanceSources then
    for _, other in ipairs(api.GetAppearanceSources(traits.appearanceID) or {}) do
      if other.isCollected then
        return true, false
      end
    end
  end
  local known = api.PlayerHasTransmogByItemInfo and itemLink ~= nil
    and api.PlayerHasTransmogByItemInfo(itemLink) == true
  return known == true, false
end

-- ReadCharacterState reads what follows the character and the account rather than the item:
-- whether the character can use it, how many of its pet the account has, and whether its appearance
-- is collected. Only for an item read with its data (rule #1).
---@param item ItemData
function items:ReadCharacterState(item)
  local traits = item.itemInfo.traits
  item.isUsable = self:CanUseItem(item.itemInfo.itemID)
  item.petOwned, item.petLimit = self:PetCountsOf(traits.petSpeciesID)
  item.appearanceKnown, item.sourceKnown = self:AppearanceStateOf(traits, item.itemInfo.itemLink)
end

-- RefreshCharacterState reads a kept item's character state again (a kept item was read with its
-- data: a cold read is never kept), and marks it for re-indexing when it changed (data-loader.md
-- §18).
---@param item ItemData
function items:RefreshCharacterState(item)
  local usable, owned, limit = item.isUsable, item.petOwned, item.petLimit
  local appearance, source = item.appearanceKnown, item.sourceKnown
  self:ReadCharacterState(item)
  if (usable ~= item.isUsable or owned ~= item.petOwned or limit ~= item.petLimit
    or appearance ~= item.appearanceKnown or source ~= item.sourceKnown) and item.derived then
    item.derived.indexPending = true
  end
end

-- characterStateChanged says whether a committed item's character state (ReadCharacterState) no
-- longer matches what the client answers.
---@param item ItemData
---@return boolean
function items:CharacterStateChanged(item)
  if self:CanUseItem(item.itemInfo.itemID) ~= item.isUsable then
    return true
  end
  local traits = item.itemInfo.traits
  local appearance, source = self:AppearanceStateOf(traits, item.itemInfo.itemLink)
  if appearance ~= item.appearanceKnown or source ~= item.sourceKnown then
    return true
  end
  if traits.petSpeciesID ~= nil then
    local owned, limit = self:PetCountsOf(traits.petSpeciesID)
    return owned ~= item.petOwned or limit ~= item.petLimit
  end
  return false
end

-- OnCharacterStateChanged: something the items' character state follows may have changed: the pet
-- journal loaded, or a pet was learned, caged, released or restored (petJournal); spells or
-- reputations, which C_PlayerInfo.CanUseItem follows. The committed items are asked again and the
-- kinds where an answer changed are recalculated (refresh-scheduler.md §10); nothing else. When the
-- journal first loads every kind is recalculated: its event can come while a read is under way,
-- before anything is committed (the request waits for the read). The bank and the guild bank only
-- while open: opening them reads them.
---@param petJournal boolean
function items:OnCharacterStateChanged(petJournal)
  local firstLoad = petJournal and not self._petJournalLoaded
  if petJournal then
    self._petJournalLoaded = true
  end
  local kinds = {
    { const.BAG_KIND.BACKPACK, 'backpack', true },
    { const.BAG_KIND.BANK, 'bank', addon.atBank == true },
    { const.BAG_KIND.GUILD, 'guild', addon.atGuildBank == true },
  }
  local options, changed = {}, false
  for _, entry in ipairs(kinds) do
    local kind, name, open = entry[1], entry[2], entry[3]
    options[name] = open and firstLoad
    changed = changed or options[name]
    local slotInfo = self.slotInfo[kind]
    if open and not firstLoad and slotInfo then
      for _, item in pairs(slotInfo.itemsBySlotKey) do
        if not item.isItemEmpty and item.itemInfo.traits and self:CharacterStateChanged(item) then
          options[name], changed = true, true
          break
        end
      end
    end
  end
  if changed then
    events:SendMessage(context:New('CharacterStateChanged'), 'bags/Rederive', options)
  end
end

-- ReadItemTraits reads what the search knows of an item beyond its name and type
-- (search-indexing.md §10), from the slot's link: what it is, its upgrade track, its stats, its
-- crafting tier. minLevel, stackSize and sellPrice are its link's (ReadLinkInfo). Call it only once
-- the item's data has loaded (rule #1, data-loader.md §19).
---@param itemID number
---@param itemLink string
---@param minLevel? number
---@param stackSize? number
---@param sellPrice? number
---@return ItemTraits
function items:ReadItemTraits(itemID, itemLink, minLevel, stackSize, sellPrice)
  ---@type ItemTraits
  local traits = {
    minLevel = minLevel,
    stackSize = stackSize,
    sellPrice = sellPrice,
    craftingQuality = self:CraftingQualityOf(itemLink),
    stats = {},
  }
  if C_Item.IsEquippableItem then
    traits.isEquipment = C_Item.IsEquippableItem(itemLink) == true
  end
  if C_Item.GetItemSpell then
    traits.hasUse = C_Item.GetItemSpell(itemLink) ~= nil
  end
  if C_Item.IsCosmeticItem then
    traits.isCosmetic = C_Item.IsCosmeticItem(itemLink) == true
  end
  -- Nothing for an item without an appearance (a retail capture: 87 of 88 items).
  local transmog = _G.C_TransmogCollection
  if transmog and transmog.GetItemInfo then
    local appearanceID, sourceID = transmog.GetItemInfo(itemLink)
    traits.transmoggable = appearanceID ~= nil and appearanceID ~= 0
    if traits.transmoggable then
      traits.appearanceID, traits.sourceID = appearanceID, sourceID
    end
  end
  -- Every caged pet's item is the same Pet Cage: its species is the first value of its link
  -- (BattlePetToolTip_UnpackBattlePetLink). GetPetInfoByItemID takes an item ID only: a link raises an error
  -- (warcraft.wiki.gg).
  local caged = itemLink and string.match(itemLink, "battlepet:(%d+)")
  if caged then
    traits.isPet = true
    traits.petSpeciesID = tonumber(caged)
  elseif C_PetJournal and C_PetJournal.GetPetInfoByItemID then
    local name, _, _, _, _, _, _, _, _, _, _, _, speciesID = C_PetJournal.GetPetInfoByItemID(itemID)
    traits.isPet = name ~= nil
    traits.petSpeciesID = speciesID
  end
  -- Only equipment has a track (Vendor asks only equipment): one without a track string has none.
  if traits.isEquipment and C_Item.GetItemUpgradeInfo then
    local upgrade = C_Item.GetItemUpgradeInfo(itemLink)
    -- A track with no levels is not one the game shows: a retail dump's Adventurer cloak had
    -- trackString with 0/0 and maxItemLevel 0, and no upgrade line in its tooltip.
    if upgrade and upgrade.trackString and (upgrade.maxLevel or 0) > 0 then
      traits.upgradeTrack = upgrade.trackString
      traits.upgradeLevel = upgrade.currentLevel
      traits.upgradeMax = upgrade.maxLevel
      traits.upgradeMaxItemLevel = upgrade.maxItemLevel
    end
  end
  -- The stats' names (GetItemStats keys are global strings: ITEM_MOD_HASTE_RATING_SHORT is "Haste").
  local getItemStats = C_Item.GetItemStats or _G.GetItemStats
  local stats = getItemStats and getItemStats(itemLink)
  if stats then
    for key in pairs(stats) do
      local name = _G[key]
      if type(name) == "string" and name ~= "" then
        table.insert(traits.stats, name)
      end
    end
    table.sort(traits.stats)
  end
  return traits
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
  -- A read while the client had no item info for the gear is not kept (HarvestEquipment).
  data.harvestIncomplete = itemName == nil
  -- The equip location (the built-in provider's two-hand check) never needs a server query.
  local instEquipLoc = select(4, C_Item.GetItemInfoInstant(itemLink))
  itemEquipLoc = instEquipLoc or itemEquipLoc

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
---@param containerInfo? ContainerItemInfo The slot's container info, when the caller already read it.
---@return ItemData
function items:AttachItemInfo(data, kind, containerInfo)
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
  local props = self:ReadItemProperties(itemID, itemLink)
  local harvestIncomplete = props.incomplete

  local itemQuality = C_Item.GetItemQuality(itemLocation) --[[@as ItemQuality]]
  itemQuality = itemQuality or const.ITEM_QUALITY.Common

  local invType = itemMixin:GetInventoryType()
  data.containerInfo = containerInfo or C_Container.GetContainerItemInfo(bagid, slotid)
  if not data.containerInfo then
    harvestIncomplete = true
    data.containerInfo = {
      iconFileID = props.itemTexture or 134400,
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
  data.rawItemName = data.containerInfo.itemName
  data.rawIconFileID = data.containerInfo.iconFileID
  data.rawQuality = data.containerInfo.quality
  data.containerInfo.itemName = data.containerInfo.itemName or props.itemName or ""
  data.containerInfo.iconFileID = data.containerInfo.iconFileID or props.itemTexture or 134400
  data.containerInfo.quality = data.containerInfo.quality or itemQuality

  data.questInfo = C_Container.GetContainerItemQuestInfo(bagid, slotid)
  if not data.questInfo then
    data.questInfo = {
      isQuestItem = false,
      isActive = false,
    }
  end

  data.transmogInfo = self:TransmogInfoOf(itemID, itemLink,
    C_Item.GetCurrentItemTransmogInfo and C_Item.GetCurrentItemTransmogInfo(itemLocation) or nil)

  data.bindingInfo = binding.GetItemBinding(itemLocation, props.bindType) or { binding = 0, bound = false }

  -- Extract tooltip text for search indexing
  ---@class TooltipScanner: AceModule
  local tooltipScanner = addon:GetModule('TooltipScanner')
  local itemGUID = C_Item.GetItemGUID(itemLocation) or ""
  local tooltipText, tooltipMarks = tooltipScanner:GetTooltipText(bagid, slotid, itemGUID)

  data.inventoryType = invType --[[@as number]]
  data.inventorySlots = const.INVENTORY_TYPE_TO_INVENTORY_SLOTS[invType]
      and const.INVENTORY_TYPE_TO_INVENTORY_SLOTS[invType]
    or { 0 }
  data.itemInfo = self:ItemInfoOf(props, {
    itemGUID = itemGUID,
    itemName = data.containerInfo.itemName or props.itemName or "",
    itemQuality = itemQuality,
    itemIcon = data.containerInfo.iconFileID or props.itemTexture or 134400,
    isBound = data.containerInfo.isBound or false,
    isLocked = data.containerInfo.isLocked or false,
    isNewItem = self:ClientNewItemFlag(bagid, slotid),
    isBattlePayItem = (_G.C_Container and _G.C_Container.IsBattlePayItem and _G.C_Container.IsBattlePayItem(bagid, slotid)) and true or false,
    currentItemCount = data.containerInfo.stackCount or 1,
    currentItemLevel = C_Item.GetCurrentItemLevel and C_Item.GetCurrentItemLevel(itemLocation) or props.effectiveIlvl or 0,
    equipmentSets = equipmentSets:GetItemSets(bagid, slotid),
    tooltipText = tooltipText,
    tooltipMarks = tooltipMarks,
  })
  -- A purchase that can still be refunded: category automation leaves it alone (automation.md §2).
  data.itemInfo.refundable = refundableAt(itemLocation)
  -- Scrapping asks about the item where it is; only a bag slot has a location.
  if data.itemInfo.traits and C_Item.CanScrapItem then
    data.itemInfo.traits.isScrappable = C_Item.CanScrapItem(itemLocation) == true
  end
  if data.itemInfo.traits then
    self:ReadCharacterState(data)
  end
  return self:FinishItemData(data, kind, harvestIncomplete, true)
end

-- CraftingQualityOf returns an item's crafting quality tier: a reagent's, else a crafted item's, in
-- the order Blizzard's item buttons read them (SetItemCraftingQualityOverlay,
-- Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua); nil for an item without one, or on a client
-- without them. itemInfo is a link or an item ID: a crafted item's tier is its own, so a slot's link.
---@param itemInfo string|number
---@return number?
function items:CraftingQualityOf(itemInfo)
  local api = C_TradeSkillUI
  if api == nil then
    return nil
  end
  local tier = api.GetItemReagentQualityByItemInfo and api.GetItemReagentQualityByItemInfo(itemInfo)
  if tier == nil and api.GetItemCraftedQualityByItemInfo then
    tier = api.GetItemCraftedQualityByItemInfo(itemInfo)
  end
  return tier
end

-- ReadItemProperties reads what an item is, whatever slot holds it: C_Item.GetItemInfo, with every
-- field it has no data for yet filled with a fallback (incomplete is then true), and the fields
-- categories depend on from C_Item.GetItemInfoInstant, which never needs a server query.
---@param itemID number
---@param itemLink? string
---@return table
function items:ReadItemProperties(itemID, itemLink)
  local itemName, _, quality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, expacID, setID, isCraftingReagent =
    C_Item.GetItemInfo(itemID)
  local props = {
    itemID = itemID,
    itemLink = itemLink,
    incomplete = itemName == nil,
    itemName = itemName or "",
    itemQuality = quality,
    itemLevel = itemLevel or 0,
    itemMinLevel = itemMinLevel or 0,
    itemType = itemType or "",
    itemSubType = itemSubType or "",
    itemStackCount = itemStackCount or 1,
    itemEquipLoc = itemEquipLoc or "",
    itemTexture = itemTexture or 134400,
    sellPrice = sellPrice or 0,
    classID = classID or 0,
    subclassID = subclassID or 0,
    expacID = expacID or 0,
    setID = setID or 0,
    isCraftingReagent = not not isCraftingReagent,
  }

  -- The categorization-relevant fields (type, subtype, equip location, class, subclass)
  -- are sourced from C_Item.GetItemInfoInstant, which never issues a server query and
  -- always returns for a valid item -- unlike C_Item.GetItemInfo above, which returns nil
  -- for these while the item cache is cold. On login with very full bags that cold read
  -- coerced itemType/itemSubType to "" and dumped every affected item into "Everything"
  -- until a /reload warmed the cache (issue #1090). Instant info keeps categorization
  -- correct regardless of cache warmth; GetItemInfo still supplies name/level/price/bind/
  -- expac, which have no instant equivalent and heal on the next warm sweep.
  local _, instType, instSubType, instEquipLoc, _, instClassID, instSubclassID =
    C_Item.GetItemInfoInstant(itemID)
  props.itemType = instType or props.itemType
  props.itemSubType = instSubType or props.itemSubType
  props.itemEquipLoc = instEquipLoc or props.itemEquipLoc
  props.classID = instClassID or props.classID
  props.subclassID = instSubclassID or props.subclassID

  local linkMinLevel, linkStackSize, linkSellPrice, linkBindType, linkLoaded = self:ReadLinkInfo(itemLink)
  props.bindType = linkBindType or bindType or 0 --link overrides itemID if set
  -- Item data is read only once it has loaded (C_Item.GetItemInfoInstant aside; rule #1,
  -- data-loader.md §19): the item in the slot (its link) as well as its base item. A read without it
  -- is incomplete, and the item is read again (harvestIncomplete); until then it has no traits.
  props.incomplete = props.incomplete or not linkLoaded
  if not props.incomplete then
    props.traits = self:ReadItemTraits(itemID, itemLink, linkMinLevel or props.itemMinLevel,
      linkStackSize or props.itemStackCount, linkSellPrice or props.sellPrice)
  end

  local effectiveIlvl, isPreview, baseIlvl = C_Item.GetDetailedItemLevelInfo(itemID)
  props.effectiveIlvl = effectiveIlvl or props.itemLevel or 0
  props.isPreview = not not isPreview
  props.baseIlvl = baseIlvl or props.itemLevel or 0
  return props
end

-- TransmogInfoOf is an item's appearance and whether the account has collected it. current is the
-- slot's own transmog (C_Item.GetCurrentItemTransmogInfo), which only a slot with an item location
-- has.
---@param itemID number
---@param itemLink? string
---@param current? table
---@return table
function items:TransmogInfoOf(itemID, itemLink, current)
  local itemAppearanceID, itemModifiedAppearanceID = 0, 0
  if C_TransmogCollection and itemLink then
    local appID, modAppID = C_TransmogCollection.GetItemInfo(itemLink)
    itemAppearanceID = appID or 0
    itemModifiedAppearanceID = modAppID or 0
  end
  return {
    transmogInfoMixin = current or {
      appearanceID = 0,
      secondaryAppearanceID = 0,
      appliedAppearanceID = 0,
      appliedSecondaryAppearanceID = 0,
    },
    itemAppearanceID = itemAppearanceID,
    itemModifiedAppearanceID = itemModifiedAppearanceID,
    hasTransmog = C_TransmogCollection and C_TransmogCollection.PlayerHasTransmog(itemID, itemModifiedAppearanceID) or false,
  }
end

-- ItemInfoOf builds an item's itemInfo from what the item is (props, ReadItemProperties) and what
-- its slot says of it (slot): the one place every kind of slot (a bag slot, a guild bank slot) fills
-- it, so they never differ in what they hold.
---@param props table
---@param slot table
---@return ItemInfo
function items:ItemInfoOf(props, slot)
  return {
    itemID = props.itemID,
    itemGUID = slot.itemGUID,
    itemName = slot.itemName,
    itemLink = props.itemLink,
    itemQuality = slot.itemQuality,
    itemLevel = props.itemLevel,
    itemMinLevel = props.itemMinLevel,
    itemType = props.itemType,
    itemSubType = props.itemSubType,
    itemStackCount = props.itemStackCount,
    itemEquipLoc = props.itemEquipLoc,
    itemTexture = props.itemTexture,
    sellPrice = props.sellPrice,
    classID = props.classID,
    subclassID = props.subclassID,
    bindType = props.bindType,
    expacID = props.expacID,
    setID = props.setID or 0,
    isCraftingReagent = props.isCraftingReagent,
    traits = props.traits,
    effectiveIlvl = props.effectiveIlvl --[[@as number]],
    isPreview = props.isPreview --[[@as boolean]],
    baseIlvl = props.baseIlvl --[[@as number]],
    itemIcon = slot.itemIcon,
    isBound = slot.isBound,
    isLocked = slot.isLocked,
    isNewItem = slot.isNewItem,
    isBattlePayItem = slot.isBattlePayItem,
    currentItemCount = slot.currentItemCount,
    category = "",
    currentItemLevel = slot.currentItemLevel,
    equipmentSets = slot.equipmentSets,
    tooltipText = slot.tooltipText or "",
    tooltipMarks = slot.tooltipMarks,
  } --[[@as ItemInfo]]
end

-- FinishItemData ends a read of an item, for every kind of slot: the highest item level seen (item
-- level colors), the Recent Items timer for an item the client flags new (bag slots only: seed),
-- the parsed link, the item hash, the stack fields and whether the read was cold.
---@param data ItemData
---@param kind BagKind
---@param harvestIncomplete boolean
---@param seed boolean
---@return ItemData
function items:FinishItemData(data, kind, harvestIncomplete, seed)
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

  if seed then
    self:SeedNewItemTimer(kind, data)
  end

  data.itemLinkInfo = self:ParseItemLink(data.itemInfo.itemLink)
  data.itemHash = self:GenerateItemHash(data)
  data.forceClear = false
  data.stacks = 0
  data.stackedCount = data.itemInfo.currentItemCount
  data.harvestIncomplete = harvestIncomplete
  return data
end

-- AttachGuildBankItemInfo fills a guild bank slot's ItemData, as AttachItemInfo fills a bag slot's:
-- from what the guild bank says of the slot (read, GuildBank:ReadSlot; nil for an empty slot) and
-- what the item is. A guild bank slot has no item location, so it has no GUID, quest data, new-item
-- flag, current transmog or equipment set; its item is never bound (the guild bank takes no bound
-- item), its binding comes from its bind type, and its current item level is its link's.
---@param data ItemData With bagid (the tab's container) and slotid.
---@param read? GuildBankSlotRead
---@return ItemData
function items:AttachGuildBankItemInfo(data, read)
  local tab = guildBankSource():TabOf(data.bagid)
  data.kind = const.BAG_KIND.GUILD
  data.basic = false
  data.guildTab = tab
  data.slotkey = self:GetSlotKeyFromBagAndSlot(data.bagid, data.slotid)
  data.guildRead = read
  if read == nil then
    data.isItemEmpty = true
    data.bindingInfo = {} --[[@as table]]
    data.itemInfo = {} --[[@as table]]
    return data
  end
  data.isItemEmpty = false
  local itemID = C_Item.GetItemInfoInstant(read.link)
  local props = self:ReadItemProperties(itemID, read.link)
  local itemQuality = read.quality or props.itemQuality or const.ITEM_QUALITY.Common
  local icon = read.texture or props.itemTexture or 134400

  data.containerInfo = {
    iconFileID = icon,
    stackCount = read.count,
    isLocked = read.locked,
    quality = itemQuality,
    isReadable = false,
    hasLoot = false,
    hyperlink = read.link,
    isFiltered = read.isFiltered,
    hasNoValue = props.sellPrice == 0,
    itemID = itemID,
    isBound = false,
    itemName = props.itemName,
  }
  data.questInfo = { isQuestItem = false, isActive = false }
  data.transmogInfo = self:TransmogInfoOf(itemID, read.link, nil)
  data.bindingInfo = binding.FromBindType(props.bindType)

  ---@class TooltipScanner: AceModule
  local tooltipScanner = addon:GetModule('TooltipScanner')
  local invType = C_Item.GetItemInventoryTypeByID(read.link) or 0
  data.inventoryType = invType
  data.inventorySlots = const.INVENTORY_TYPE_TO_INVENTORY_SLOTS[invType] or { 0 }
  local level = C_Item.GetDetailedItemLevelInfo(read.link)
  local tooltipText, tooltipMarks = tooltipScanner:GetGuildBankItemText(tab, data.slotid, read.link)
  data.itemInfo = self:ItemInfoOf(props, {
    itemGUID = "",
    itemName = props.itemName,
    itemQuality = itemQuality,
    itemIcon = icon,
    isBound = false,
    isLocked = read.locked,
    isNewItem = false,
    isBattlePayItem = false,
    currentItemCount = read.count,
    currentItemLevel = level or props.effectiveIlvl or 0,
    tooltipText = tooltipText,
    tooltipMarks = tooltipMarks,
  })
  if data.itemInfo.traits then
    self:ReadCharacterState(data)
  end
  return self:FinishItemData(data, const.BAG_KIND.GUILD, props.incomplete, false)
end

-- sameGuildRead says whether a guild bank slot still holds what an item was read from: every field
-- the guild bank reports of the slot. The lock is one: another player moving the item locks it.
---@param a GuildBankSlotRead
---@param b GuildBankSlotRead
---@return boolean
local function sameGuildRead(a, b)
  return a.link == b.link and a.count == b.count and a.locked == b.locked and a.texture == b.texture
    and a.isFiltered == b.isFiltered and a.quality == b.quality
end

-- HarvestGuildBank reads every slot of the guild bank tabs in bagList (their containers), as Harvest
-- reads bags: a slot whose contents are unchanged keeps its committed item (previousItems), unless
-- that item was read cold.
---@param bagList table<number, number>
---@param previousItems? table<string, ItemData>
---@return table<string, ItemData>
function items:HarvestGuildBank(bagList, previousItems)
  local itemData = {}
  for container in pairs(bagList) do
    local tab = guildBankSource():TabOf(container)
    if tab then
      for slotid = 1, const.GUILD_BANK_SLOTS do
        local slotkey = self:GetSlotKeyFromBagAndSlot(container, slotid)
        local read = guildBankSource():ReadSlot(tab, slotid)
        local previous = previousItems and previousItems[slotkey]
        if read and previous and not previous.isItemEmpty and not previous.harvestIncomplete
          and previous.guildRead and sameGuildRead(previous.guildRead, read) then
          itemData[slotkey] = previous
        else
          local data = {}
          ---@cast data +ItemData
          data.bagid, data.slotid = container, slotid
          itemData[slotkey] = self:AttachGuildBankItemInfo(data, read)
        end
      end
    end
  end
  return itemData
end

-- RederiveGuildBank gives a recalculation of the guild bank (refresh-scheduler.md §10) the items it
-- last read, reading no slot, the tooltip text refreshed (a cache hit, or a re-scan after a tooltip
-- resolved). An item read cold is read again, as every read does with one.
---@param committedItems table<string, ItemData>
---@return table<string, ItemData>
function items:RederiveGuildBank(committedItems)
  local itemData = {}
  ---@class TooltipScanner: AceModule
  local tooltipScanner = addon:GetModule('TooltipScanner')
  for slotkey, item in pairs(committedItems) do
    if not item.isItemEmpty then
      if item.harvestIncomplete then
        local data = {}
        ---@cast data +ItemData
        data.bagid, data.slotid = item.bagid, item.slotid
        item = self:AttachGuildBankItemInfo(data, guildBankSource():ReadSlot(item.guildTab, item.slotid))
      else
        local text, marks = tooltipScanner:GetGuildBankItemText(item.guildTab, item.slotid, item.itemInfo.itemLink)
        text = text or ""
        -- Tooltip text is an input of the item's category and search entry (data-loader.md §18).
        if text ~= item.itemInfo.tooltipText then
          item.itemInfo.tooltipText = text
          item.itemInfo.tooltipMarks = marks
          item.derived = nil
        end
        self:RefreshCharacterState(item)
      end
    end
    itemData[slotkey] = item
  end
  return itemData
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

-- GetCategory returns the category data is shown in. With own, it leaves search categories out:
-- the item's own category, which search categories are matched against (Phase6_EnrichData). With
-- ignoreRecent, a recent item gets the category it has once it is no longer recent (category
-- automation acts by it, automation.md). With withoutAdded, the category it was added to by hand is
-- left out (NaturalCategory).
---@param ctx Context
---@param data ItemData
---@param own? boolean
---@param ignoreRecent? boolean
---@param withoutAdded? boolean
---@return string
function items:GetCategory(ctx, data, own, ignoreRecent, withoutAdded)
  if not data or data.isItemEmpty then
    return L:G("Empty Slot")
  end

  if not data.itemInfo then
    data.itemInfo = {}
  end

  if not ignoreRecent and database:GetCategoryFilter(data.kind, "RecentItems") then
    -- A virtual stack root is recent while any pile it merges is (stackRecent, Phase 7). Its own
    -- category (own) goes by the item alone: the search index holds it.
    if items:IsNewItem(data) or (not own and data.stackRecent) then
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
  local searchCategory, searchPriority
  if not own then
    searchCategory = self.searchCache[data.kind] and self.searchCache[data.kind][data.slotkey]
    searchPriority = self.categoryPriorityCache[data.kind] and self.categoryPriorityCache[data.kind][data.slotkey]
  end
  local customCategory, customPriority, customFilter = categories:GetCustomCategory(ctx, data.kind, data, withoutAdded)

  -- An item added by hand to a category of yours stays there, whatever the order (category-lifecycle.md
  -- §7). A plugin's item lists compete with rules by priority, the list winning a tie.
  if searchCategory and customCategory then
    if (customFilter and customFilter.save) or (customPriority or 10) <= (searchPriority or 10) then
      return self:GroupedCategory(ctx, customCategory, customFilter, data)
    end
    return searchCategory
  end

  if searchCategory then
    return searchCategory
  end

  if customCategory then
    return self:GroupedCategory(ctx, customCategory, customFilter, data)
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
  local typeName

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
    typeName = data.itemInfo.itemType
    category = category .. typeName --[[@as string]]
  end

  -- Add the subtype filter to the category if enabled, but same as with
  -- the type filter we don't add it to trade goods when the tradeskill
  -- filter is enabled. A subtype named like its type (quest items are
  -- "Quest" / "Quest") is not repeated.
  if
    database:GetCategoryFilter(data.kind, "Subtype")
    and not (data.itemInfo.classID == Enum.ItemClass.Tradegoods and database:GetCategoryFilter(
      data.kind,
      "TradeSkill"
    ))
    and data.itemInfo.itemSubType
    and data.itemInfo.itemSubType ~= typeName
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

-- NaturalCategory returns where an item lands without the category it was added to by hand, out of
-- Recent Items: its rules (this sweep's), a plugin's categories, the built-in ones. An item dropped on
-- the header of that category needs no Added Items there (Categories:FileItem, docs/next-batch-2.md §8).
---@param ctx Context
---@param data ItemData
---@return string
function items:NaturalCategory(ctx, data)
  return self:GetCategory(ctx, data, false, true, true)
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

-- The 12.1 Catalyst retains a source item's secondary stats, so two pieces can share
-- the same itemID, item level and bonus IDs (the stat difference lives in an item-link
-- modifier we do not hash) yet display different stats. C_Item.GetItemStats reports the
-- resolved per-item stats, so a sorted digest of it is folded into the item hash to keep
-- such pieces from collapsing into a single virtual stack. The digest is intentionally
-- key/value only (locale-independent constant names) and sorted for determinism.
---@param itemLink? string
---@return string
function items:GenerateItemStatHash(itemLink)
  if not itemLink or itemLink == "" then return "" end
  -- C_Item.GetItemStats on Retail (10.2.5+); the global GetItemStats on Classic/Era.
  local getItemStats = (C_Item and C_Item.GetItemStats) or _G.GetItemStats
  if not getItemStats then return "" end
  local stats = getItemStats(itemLink)
  if not stats then return "" end
  local keys = {}
  for k in pairs(stats) do
    keys[#keys + 1] = k
  end
  if #keys == 0 then return "" end
  table.sort(keys)
  local parts = {}
  for i = 1, #keys do
    parts[i] = keys[i] .. "=" .. tostring(stats[keys[i]])
  end
  return table.concat(parts, ",")
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
  local statHash = self:GenerateItemStatHash(itemInfo.itemLink)

  local appearanceID = 0
  if stackOpts.dontMergeTransmog
    and transmogInfo.transmogInfoMixin
    and transmogInfo.transmogInfoMixin.appearanceID then
    appearanceID = transmogInfo.transmogInfoMixin.appearanceID
  end

  -- Scope the hash by bank type so the Character Bank and the Warbank never virtually
  -- stack together. On retail the bank data sweep loads both bank types into one unified
  -- cache (they only partition into tabs downstream, after stacking), so two identical
  -- items -- one in each bank type -- would otherwise collide on this hash and one would
  -- be hidden behind the other's virtual stack, making items appear to merge across bank
  -- types. Items within the same bank type (all Character Bank bags, or all Warbank tabs)
  -- keep the same scope and still stack. Backpack and non-retail clients are unaffected.
  local bankScope = ""
  if const.ACCOUNT_BANK_BAGS and const.ACCOUNT_BANK_BAGS[data.bagid] then
    bankScope = "W"
  end

  local hash = format(
    "%d%s%s%s%s%s%s%s%s%s%s%s%d%d%d%s%s",
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
    appearanceID,
    statHash,
    bankScope
  )
  return hash
end
