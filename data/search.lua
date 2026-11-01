local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class QueryParser: AceModule
local QueryParser = addon:GetModule('QueryParser')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Trees: AceModule
local trees = addon:GetModule('Trees')

---@class SearchIndex
---@field property string
---@field ngrams table<string, table<string, boolean>>
---@field numbers IntervalTree
---@field bools table<boolean, table<string, boolean>>
---@field fullText table<string, table<string, boolean>>
---@field fullTextOnly? boolean Stores no prefix ngrams; `=` / `!=` match substrings of the full text.

---@class Search: AceModule
---@field private indicies table<string, SearchIndex>
---@field private indexLookup table<string, SearchIndex>
---@field private defaultIndicies string[]
---@field private indexed table<string, table> slotkey -> the values that slot is indexed with (see fillSnapshot).
local search = addon:NewModule('Search')

-- An item's indexed values. fillSnapshot is the single definition of what an item puts in
-- the index: Add indexes a snapshot and Remove removes the slot's stored snapshot, so an
-- item is always removed with exactly the values it was indexed with, however its ItemData
-- changed since. SyncKind compares a fresh snapshot with the stored one to find the items
-- whose indexed values changed.
local SNAPSHOT_FIELDS = {
  'kind', 'name', 'type', 'subtype', 'category', 'guid', 'expansion', 'equipmentlocation',
  'binding', 'tooltip', 'bagname', 'level', 'rarity', 'quality', 'id', 'stackcount', 'class', 'subclass',
  'bagid', 'slotid', 'bindtype', 'reagent', 'isbound', 'bound', 'quest', 'activequest',
  'minlevel', 'stacksize', 'price', 'equipment', 'hasuse', 'cosmetic', 'pet', 'scrappable', 'upgradeable',
  'track', 'upgradelevel', 'upgrademax', 'maxlevel', 'upgrade', 'total', 'toy', 'known', 'transmoggable',
  'usable', 'petcount', 'petlimit', 'slotequipped', 'slotbest', 'appearance', 'source',
}
-- expansionid is not compared: it follows expansion, which is.

-- expansionNumbers maps each expansion's short name to the number it orders by: the lowest expansion
-- ID const.BRIEF_EXPANSION_MAP gives that name, so TBC Anniversary's 254 ("bc") orders as 1. Built
-- by search:Init.
---@type table<string, number>
local expansionNumbers = {}

---@param into table[]|nil
---@param list string[]|nil
---@return table
local function copyList(into, list)
  into = into or {}
  local n = 0
  for _, v in ipairs(list or {}) do
    n = n + 1
    into[n] = v
  end
  for i = n + 1, #into do
    into[i] = nil
  end
  return into
end

-- KNOWN names a collected state as the appearance and source fields hold it.
local KNOWN = { [true] = "known", [false] = "unknown" }

---@param s table The snapshot to fill (reused across items).
---@param item ItemData
---@return table
local function fillSnapshot(s, item)
  local info = item.itemInfo
  s.kind = item.kind
  s.name = info.itemName
  s.type = info.itemType
  s.subtype = info.itemSubType
  s.category = info.category
  s.guid = info.itemGUID
  s.sets = copyList(s.sets, info.equipmentSets)
  s.expansion = info.expacID ~= nil and const.BRIEF_EXPANSION_MAP[info.expacID] or nil
  s.expansionid = s.expansion and expansionNumbers[s.expansion] or nil
  local equipLoc = info.itemEquipLoc
  if equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" and _G[equipLoc] ~= nil and _G[equipLoc] ~= "" then
    s.equipmentlocation = _G[equipLoc]
  else
    s.equipmentlocation = nil
  end
  local bindingInfo = item.bindingInfo
  if bindingInfo and bindingInfo.binding ~= nil and const.BINDING_MAP[bindingInfo.binding] ~= "" then
    s.binding = const.BINDING_MAP[bindingInfo.binding]
  else
    s.binding = nil
  end
  if info.tooltipText and info.tooltipText ~= "" then
    s.tooltip = info.tooltipText
  else
    s.tooltip = nil
  end
  s.bagname = item.bagName
  s.level = info.currentItemLevel
  s.rarity = info.itemQuality
  s.id = info.itemID
  s.stackcount = info.currentItemCount
  s.class = info.classID
  s.subclass = info.subclassID
  s.bagid = item.bagid
  s.slotid = item.slotid
  s.bindtype = info.bindType
  s.bonusIDs = copyList(s.bonusIDs, item.itemLinkInfo and item.itemLinkInfo.bonusIDs)
  s.reagent = info.isCraftingReagent
  s.isbound = info.isBound
  s.bound = bindingInfo and bindingInfo.bound
  s.quest = item.questInfo and item.questInfo.isQuestItem
  s.activequest = item.questInfo and item.questInfo.isActive
  -- Read from the item's link once its data has loaded (items:ReadItemTraits); an item read cold
  -- has none (rule #1, data-loader.md §19).
  local t = info.traits
  s.quality = t and t.craftingQuality
  s.minlevel = t and t.minLevel
  s.stacksize = t and t.stackSize
  s.price = t and t.sellPrice
  s.equipment = t and t.isEquipment
  s.hasuse = t and t.hasUse
  s.cosmetic = t and t.isCosmetic
  s.pet = t and t.isPet
  s.scrappable = t and t.isScrappable
  s.upgradeable = t and t.upgradeTrack ~= nil
  s.track = t and t.upgradeTrack
  s.upgradelevel = t and t.upgradeLevel
  s.upgrademax = t and t.upgradeMax
  -- Vendor's MaxLevel: the fully upgraded item level, never below the current one.
  local level = info.currentItemLevel
  if t and t.upgradeMaxItemLevel and level then
    s.maxlevel = math.max(t.upgradeMaxItemLevel, level)
  elseif t then
    s.maxlevel = level
  else
    s.maxlevel = nil
  end
  s.stats = copyList(s.stats, t and t.stats)
  -- What the tooltip's whole lines mark (TooltipScanner), read with the item's data.
  local marks = info.tooltipMarks
  s.toy = t and (marks ~= nil and marks.toy == true)
  s.known = t and (marks ~= nil and marks.known == true)
  s.transmoggable = t and t.transmoggable
  -- Whether the character can use it (items:CanUseItem); equippable follows it and equipment.
  s.usable = t and item.isUsable
  s.equippable = t and item.isUsable and t.isEquipment == true
  -- How many of its pet the account has (items:PetCountsOf), known once the pet journal loaded; only
  -- a pet has counts. collectable follows them and pet, which are compared.
  local counted = t and item.petOwned ~= nil and item.petLimit ~= nil
  s.petcount = counted and item.petOwned or nil
  s.petlimit = counted and item.petLimit or nil
  if t and t.isPet == false then
    s.collectable = false
  elseif counted then
    s.collectable = item.petOwned < item.petLimit
  else
    s.collectable = nil
  end
  -- Follows the sets above, which are compared.
  s.inset = info.equipmentSets ~= nil and info.equipmentSets[1] ~= nil
  -- The arrow BetterBags draws, for an item read with its data (rule #1) that its provider can tell about.
  if item.harvestIncomplete or item.upgradeUnknown then
    s.upgrade = nil
  else
    s.upgrade = item.isUpgrade == true
  end
  s.total = item.itemTotal
  -- Follow the worn gear (items:SlotLevelsOf); Phase 6 marks an item whose values changed.
  s.slotequipped = item.slotEquipped
  s.slotbest = item.slotBest
  -- Collected or not (items:AppearanceStateOf), known once the collection loaded.
  s.appearance = KNOWN[item.appearanceKnown]
  s.source = KNOWN[item.sourceKnown]
  return s
end

---@param a table
---@param b table
---@return boolean
local function sameList(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do
    if a[i] ~= b[i] then return false end
  end
  return true
end

---@param a table
---@param b table
---@return boolean
local function sameSnapshot(a, b)
  for _, field in ipairs(SNAPSHOT_FIELDS) do
    if a[field] ~= b[field] then return false end
  end
  return sameList(a.sets, b.sets) and sameList(a.bonusIDs, b.bonusIDs) and sameList(a.stats, b.stats)
end

-- Number and boolean snapshot fields share their name with the index they go into.
local NUMBER_FIELDS = {
  'level', 'rarity', 'quality', 'id', 'stackcount', 'class', 'subclass', 'bagid', 'slotid', 'bindtype',
  'expansionid', 'minlevel', 'stacksize', 'price', 'upgradelevel', 'upgrademax', 'maxlevel', 'total',
  'petcount', 'petlimit', 'slotequipped', 'slotbest',
}
local BOOL_FIELDS = {
  'reagent', 'isbound', 'bound', 'quest', 'activequest', 'equipment', 'hasuse', 'cosmetic', 'pet', 'scrappable',
  'upgradeable', 'inset', 'upgrade', 'toy', 'known', 'transmoggable', 'usable', 'equippable', 'collectable',
}

-- scratch is reused to snapshot each item SyncKind compares, so an unchanged item costs no
-- allocation.
local scratch = {}

-- What a query's words name, for comparisons answered item by item (search:MatchEach) and for
-- deciding how a word compared with a field is read.
local ALIASES = { ilvl = 'level', count = 'stackcount', exp = 'expansion', slot = 'equipmentlocation', bag = 'bagname' }
local TEXT_FIELDS = {
  name = true, type = true, subtype = true, category = true, guid = true, expansion = true,
  equipmentlocation = true, binding = true, tooltip = true, bagname = true, track = true,
  appearance = true, source = true,
}
-- List fields: an item can hold several values; a comparison matches when any value does.
local LIST_KEYS = { equipmentset = 'sets', stat = 'stats', bonusid = 'bonusIDs' }
local NUMERIC = {}
for _, field in ipairs(NUMBER_FIELDS) do NUMERIC[field] = true end
local BOOLEAN = {}
for _, field in ipairs(BOOL_FIELDS) do BOOLEAN[field] = true end

-- fieldKey returns the snapshot key holding a field's value (aliases resolved), or nil for a word
-- that names no field.
---@param word string A lower-case word.
---@return string?
local function fieldKey(word)
  word = ALIASES[word] or word
  if NUMERIC[word] or TEXT_FIELDS[word] or BOOLEAN[word] then
    return word
  end
  return LIST_KEYS[word]
end

-- moneyOf reads gold, silver and copper (5g, 50s, 1g50s, 20c) as copper; nil for anything else.
---@param word string A lower-case word.
---@return number?
local function moneyOf(word)
  local gold = word:match("^(%d+)g")
  local rest = gold and word:sub(#gold + 2) or word
  local silver = rest:match("^(%d+)s")
  rest = silver and rest:sub(#silver + 2) or rest
  local copper = rest:match("^(%d+)c")
  rest = copper and rest:sub(#copper + 2) or rest
  if rest ~= "" or not (gold or silver or copper) then return nil end
  return (tonumber(gold) or 0) * 10000 + (tonumber(silver) or 0) * 100 + (tonumber(copper) or 0)
end

-- QUERY_FUNCTIONS are what a query's functions compute (QueryParser.FUNCTIONS names them); any
-- argument that is not a number makes nothing.
local QUERY_FUNCTIONS = {
  min = function(args)
    local best
    for _, v in ipairs(args) do
      if type(v) ~= 'number' then return nil end
      if best == nil or v < best then best = v end
    end
    return best
  end,
  max = function(args)
    local best
    for _, v in ipairs(args) do
      if type(v) ~= 'number' then return nil end
      if best == nil or v > best then best = v end
    end
    return best
  end,
  floor = function(args) return type(args[1]) == 'number' and math.floor(args[1]) or nil end,
  ceil = function(args) return type(args[1]) == 'number' and math.ceil(args[1]) or nil end,
  abs = function(args) return type(args[1]) == 'number' and math.abs(args[1]) or nil end,
}

---@param op string
---@param a any
---@param b any
---@return number?
local function arithmetic(op, a, b)
  if type(a) ~= 'number' or type(b) ~= 'number' then return nil end
  if op == '+' then return a + b
  elseif op == '-' then return a - b
  elseif op == '*' then return a * b
  elseif op == '/' then return a / b
  end
  return a % b
end

---@param v any
---@return any
local function asBoolean(v)
  if v == "true" then return true end
  if v == "false" then return false end
  return v
end

-- compareValues compares two values as a query does: numbers by value; text without case, = by its
-- start, == whole, %= anywhere; booleans by value. A list (a player's professions) matches when any
-- of its values does, and != or ~= when none does. A missing value matches only != and ~=, as the
-- index answers them (isNotInIndex: items without the field included).
---@param a any
---@param op string
---@param b any
---@return boolean
local function compareValues(a, op, b)
  if op == '!=' then return not compareValues(a, '=', b) end
  if op == '~=' then return not compareValues(a, '==', b) end
  if a == nil or b == nil then return false end
  if type(a) == 'table' then
    for _, v in ipairs(a) do
      if compareValues(v, op, b) then return true end
    end
    return false
  end
  if type(b) == 'table' then
    for _, v in ipairs(b) do
      if compareValues(a, op, v) then return true end
    end
    return false
  end
  if type(a) == 'boolean' or type(b) == 'boolean' then
    a, b = asBoolean(a), asBoolean(b)
    return (op == '=' or op == '==') and a == b
  end
  if type(a) ~= type(b) then
    a, b = tonumber(a), tonumber(b)
    if a == nil or b == nil then return false end
  end
  if type(a) == 'number' then
    if op == '=' or op == '==' then return a == b
    elseif op == '<' then return a < b
    elseif op == '<=' then return a <= b
    elseif op == '>' then return a > b
    elseif op == '>=' then return a >= b
    elseif op == '%=' then return string.find(tostring(a), tostring(b), 1, true) ~= nil
    end
    return false
  end
  a, b = string.lower(a), string.lower(b)
  if op == '=' then return a:sub(1, #b) == b
  elseif op == '==' then return a == b
  elseif op == '%=' then return string.find(a, b, 1, true) ~= nil
  elseif op == '<' then return a < b
  elseif op == '<=' then return a <= b
  elseif op == '>' then return a > b
  elseif op == '>=' then return a >= b
  end
  return false
end

-- FLIPPED is the operator that keeps a comparison's meaning with its sides swapped; %= has none.
local FLIPPED = { ['<'] = '>', ['<='] = '>=', ['>'] = '<', ['>='] = '<=', ['='] = '=', ['=='] = '==',
  ['!='] = '!=', ['~='] = '~=' }

---@param name string
---@param fullTextOnly? boolean
function search:CreateIndex(name, fullTextOnly)
  self.indicies[name] = {
    property = name,
    ngrams = {},
    numbers = trees.NewIntervalTree(),
    bools = {},
    fullText = {},
    fullTextOnly = fullTextOnly,
  }
end

function search:Init()
  expansionNumbers = {}
  for id, name in pairs(const.BRIEF_EXPANSION_MAP) do
    if expansionNumbers[name] == nil or id < expansionNumbers[name] then
      expansionNumbers[name] = id
    end
  end
  self.indicies = {}
  self.indexed = {}
  -- The item object each slot was indexed from (SyncKind skips one still indexed from it).
  self.indexedItems = {}
  -- String indexes
  self:CreateIndex('name')
  self:CreateIndex('type')
  self:CreateIndex('subtype')
  self:CreateIndex('category')
  self:CreateIndex('equipmentlocation')
  self:CreateIndex('expansion')
  self:CreateIndex('equipmentset')
  self:CreateIndex('bagname')
  self:CreateIndex('guid')
  self:CreateIndex('binding')
  self:CreateIndex('track')
  self:CreateIndex('stat')
  self:CreateIndex('appearance')
  self:CreateIndex('source')
  -- Tooltip text runs to hundreds of characters; indexing every prefix of it is
  -- quadratic per item and dominated the cost of each sweep.
  self:CreateIndex('tooltip', true)

  -- Number indexes
  self:CreateIndex('level')
  self:CreateIndex('rarity')
  self:CreateIndex('id')
  self:CreateIndex('quality')
  self:CreateIndex('stackcount')
  self:CreateIndex('class')
  self:CreateIndex('subclass')
  self:CreateIndex('bagid')
  self:CreateIndex('slotid')
  self:CreateIndex('bindtype')
  self:CreateIndex('expansionid')
  self:CreateIndex('minlevel')
  self:CreateIndex('stacksize')
  self:CreateIndex('price')
  self:CreateIndex('upgradelevel')
  self:CreateIndex('upgrademax')
  self:CreateIndex('maxlevel')
  self:CreateIndex('total')
  self:CreateIndex('bonusid')

  -- Boolean indexes
  self:CreateIndex('reagent')
  self:CreateIndex('isbound') -- from C_Item
  self:CreateIndex('bound') -- from Binding
  self:CreateIndex('quest')
  self:CreateIndex('activequest')
  self:CreateIndex('equipment')
  self:CreateIndex('hasuse')
  self:CreateIndex('cosmetic')
  self:CreateIndex('pet')
  self:CreateIndex('scrappable')
  self:CreateIndex('upgradeable')
  self:CreateIndex('inset')
  self:CreateIndex('upgrade')
  self:CreateIndex('toy')
  self:CreateIndex('known')
  self:CreateIndex('transmoggable')
  self:CreateIndex('usable')
  self:CreateIndex('equippable')
  self:CreateIndex('collectable')
  self:CreateIndex('petcount')
  self:CreateIndex('petlimit')
  self:CreateIndex('slotequipped')
  self:CreateIndex('slotbest')

  self.defaultIndicies = {
    'name',
    'type',
    'category',
    'subtype',
    'equipmentlocation',
    'binding',
    'tooltip',
  }

  self.indexLookup = {
    exp = self.indicies.expansion,
    slot = self.indicies.equipmentlocation,
    ilvl = self.indicies.level,
    count = self.indicies.stackcount,
    bag = self.indicies.bagname,
  }
end

-- Wipe will clear all data from the search index.
function search:Wipe()
  for _, index in pairs(self.indicies) do
    index.ngrams = {}
    index.fullText = {}
    index.bools = {}
    index.numbers = trees.NewIntervalTree()
  end
  self.indexed = {}
  self.indexedItems = {}
end

-- IndexItems replaces the previous indexes and indexes a completely fresh collection of flat items
---@param currentItems table<string, ItemData>
function search:IndexItems(currentItems)
  self:Wipe()
  if not currentItems then return end
  for _, item in pairs(currentItems) do
    self:Add(item)
  end
end

-- SyncKind makes the index hold exactly the given items of one bag kind, leaving the other
-- kind's entries alone. Only the items whose indexed values changed since they were indexed
-- are re-indexed; a slot that is gone or now empty is removed with the values it was indexed
-- with. With rebuild set, every item of the kind is removed and re-added. The result is the
-- index search:IndexItems would build over the same items (spec/search_spec.lua checks this
-- over randomized sequences).
--
-- With changed (a set of slot keys), an item that is the very object its slot was indexed from
-- and is not in changed is taken as indexed already, without comparing its values: the pipeline
-- passes the items whose values it set again (data-loader.md §18), and every other in-place change
-- of an indexed value goes through UpdateCategoryIndex. Without changed every item is compared.
---@param kind BagKind
---@param items table<string, ItemData>|nil
---@param rebuild? boolean
---@param changed? table<string, any>
function search:SyncKind(kind, items, rebuild, changed)
  for slotkey, snap in pairs(self.indexed) do
    if snap.kind == kind then
      local item = items and items[slotkey]
      if rebuild or not item or item.isItemEmpty then
        self:removeSnapshot(slotkey, snap)
      end
    end
  end
  for slotkey, item in pairs(items or {}) do
    if not item.isItemEmpty then
      local snap = self.indexed[slotkey]
      if not snap then
        self:Add(item)
      elseif changed == nil or changed[slotkey] or self.indexedItems[slotkey] ~= item then
        if sameSnapshot(fillSnapshot(scratch, item), snap) then
          self.indexedItems[slotkey] = item
        else
          self:Add(item)
        end
      end
    end
  end
end

---@private
---@param index SearchIndex
---@param value boolean
---@param slotkey string
function search:addBoolToIndex(index, value, slotkey)
  index.bools[value] = index.bools[value] or {}
  index.bools[value][slotkey] = true
end

---@private
---@param index SearchIndex
---@param value boolean
---@param slotkey string
function search:removeBoolFromIndex(index, value, slotkey)
  local set = index.bools[value]
  if set then
    set[slotkey] = nil
    if next(set) == nil then index.bools[value] = nil end
  end
end

---@private
---@param index SearchIndex
---@param value number
---@param slotkey string
function search:addNumberToIndex(index, value, slotkey)
  index.numbers:Insert(value, {[slotkey] = true})
end

---@private
---@param index SearchIndex
---@param value number
---@param slotkey string
function search:removeNumberFromIndex(index, value, slotkey)
  index.numbers:RemoveData(value, slotkey)
end

---@private
---@param index SearchIndex
---@param value string
---@param slotkey string
function search:addStringToIndex(index, value, slotkey)
  if value == nil or value == "" then return end
  value = string.lower(value)
  if not index.fullTextOnly then
    local prefix = ""
    for i = 1, #value do
      prefix = prefix .. value:sub(i, i)
      index.ngrams[prefix] = index.ngrams[prefix] or {}
      index.ngrams[prefix][slotkey] = true
    end
  end
  index.fullText[value] = index.fullText[value] or {}
  index.fullText[value][slotkey] = true
end

---@private
---@param index SearchIndex
---@param value string
---@param slotkey string
function search:removeStringFromIndex(index, value, slotkey)
  if value == nil or value == "" then return end
  value = string.lower(value)
  if not index.fullTextOnly then
    local prefix = ""
    for i = 1, #value do
      prefix = prefix .. value:sub(i, i)
      local set = index.ngrams[prefix]
      if set then
        set[slotkey] = nil
        if next(set) == nil then index.ngrams[prefix] = nil end
      end
    end
  end
  -- A value with no slots left is deleted, so the index stays equal to a clean rebuild and
  -- full-text searches (which walk every value) do not slow down as items come and go.
  local set = index.fullText[value]
  if set then
    set[slotkey] = nil
    if next(set) == nil then index.fullText[value] = nil end
  end
end

-- UpdateCategoryIndex moves an indexed item to its new category. The category it is
-- removed from is the one it was indexed with, when it was indexed.
---@param item ItemData
---@param oldCategory string
function search:UpdateCategoryIndex(item, oldCategory)
  if item == nil or item.isItemEmpty or item.itemInfo.category == nil then return end
  local snap = self.indexed[item.slotkey]
  if snap then
    if snap.category == item.itemInfo.category then return end
    oldCategory = snap.category
    snap.category = item.itemInfo.category
  end
  self:removeStringFromIndex(self.indicies.category, oldCategory, item.slotkey)
  self:addStringToIndex(self.indicies.category, item.itemInfo.category, item.slotkey)
end

---@private
---@param slotkey string
---@param s table
function search:indexSnapshot(slotkey, s)
  local idx = self.indicies
  self:addStringToIndex(idx.name, s.name, slotkey)
  self:addStringToIndex(idx.type, s.type, slotkey)
  self:addStringToIndex(idx.subtype, s.subtype, slotkey)
  self:addStringToIndex(idx.category, s.category, slotkey)
  self:addStringToIndex(idx.guid, s.guid, slotkey)
  for _, set in ipairs(s.sets) do
    self:addStringToIndex(idx.equipmentset, set, slotkey)
  end
  self:addStringToIndex(idx.expansion, s.expansion, slotkey)
  self:addStringToIndex(idx.equipmentlocation, s.equipmentlocation, slotkey)
  self:addStringToIndex(idx.binding, s.binding, slotkey)
  self:addStringToIndex(idx.tooltip, s.tooltip, slotkey)
  self:addStringToIndex(idx.bagname, s.bagname, slotkey)
  self:addStringToIndex(idx.track, s.track, slotkey)
  self:addStringToIndex(idx.appearance, s.appearance, slotkey)
  self:addStringToIndex(idx.source, s.source, slotkey)
  for _, stat in ipairs(s.stats) do
    self:addStringToIndex(idx.stat, stat, slotkey)
  end
  for _, field in ipairs(NUMBER_FIELDS) do
    if s[field] ~= nil then
      self:addNumberToIndex(idx[field], s[field], slotkey)
    end
  end
  for _, bonusID in ipairs(s.bonusIDs) do
    local bonusNum = tonumber(bonusID)
    if bonusNum then self:addNumberToIndex(idx.bonusid, bonusNum, slotkey) end
  end
  for _, field in ipairs(BOOL_FIELDS) do
    if s[field] ~= nil then
      self:addBoolToIndex(idx[field], s[field], slotkey)
    end
  end
end

---@private
---@param slotkey string
---@param s table
function search:removeSnapshot(slotkey, s)
  local idx = self.indicies
  self:removeStringFromIndex(idx.name, s.name, slotkey)
  self:removeStringFromIndex(idx.type, s.type, slotkey)
  self:removeStringFromIndex(idx.subtype, s.subtype, slotkey)
  self:removeStringFromIndex(idx.category, s.category, slotkey)
  self:removeStringFromIndex(idx.guid, s.guid, slotkey)
  for _, set in ipairs(s.sets) do
    self:removeStringFromIndex(idx.equipmentset, set, slotkey)
  end
  self:removeStringFromIndex(idx.expansion, s.expansion, slotkey)
  self:removeStringFromIndex(idx.equipmentlocation, s.equipmentlocation, slotkey)
  self:removeStringFromIndex(idx.binding, s.binding, slotkey)
  self:removeStringFromIndex(idx.tooltip, s.tooltip, slotkey)
  self:removeStringFromIndex(idx.bagname, s.bagname, slotkey)
  self:removeStringFromIndex(idx.track, s.track, slotkey)
  self:removeStringFromIndex(idx.appearance, s.appearance, slotkey)
  self:removeStringFromIndex(idx.source, s.source, slotkey)
  for _, stat in ipairs(s.stats) do
    self:removeStringFromIndex(idx.stat, stat, slotkey)
  end
  for _, field in ipairs(NUMBER_FIELDS) do
    if s[field] ~= nil then
      self:removeNumberFromIndex(idx[field], s[field], slotkey)
    end
  end
  for _, bonusID in ipairs(s.bonusIDs) do
    local bonusNum = tonumber(bonusID)
    if bonusNum then self:removeNumberFromIndex(idx.bonusid, bonusNum, slotkey) end
  end
  for _, field in ipairs(BOOL_FIELDS) do
    if s[field] ~= nil then
      self:removeBoolFromIndex(idx[field], s[field], slotkey)
    end
  end
  self.indexed[slotkey] = nil
  self.indexedItems[slotkey] = nil
end

-- Add indexes an item, replacing whatever its slot was indexed with.
---@param item ItemData
function search:Add(item)
  if item == nil or item.isItemEmpty then return end
  local old = self.indexed[item.slotkey]
  if old then
    self:removeSnapshot(item.slotkey, old)
  end
  local snap = fillSnapshot({}, item)
  self:indexSnapshot(item.slotkey, snap)
  self.indexed[item.slotkey] = snap
  self.indexedItems[item.slotkey] = item
end

-- Remove removes an item's slot from the index, with the values it was indexed with.
---@param item ItemData
function search:Remove(item)
  if item == nil then return end
  local snap = self.indexed[item.slotkey]
  if snap then
    self:removeSnapshot(item.slotkey, snap)
  end
end

function search:StringToBoolean(value)
  if value == "true" then
    return true
  elseif value == "false" then
    return false
  end
end

---@param property string
---@return SearchIndex?
function search:GetIndex(property)
  if not self.indicies[property] and not self.indexLookup[property] then return end
  return self.indicies[property] or self.indexLookup[property]
end

---@param name string The name of the search index to lookup
---@param value any
---@return table<string, boolean>
function search:isInIndex(name, value)
  local index = self:GetIndex(name)
  if not index then return {} end
  if index.fullTextOnly then
    return self:isFullTextMatch(name, tostring(value))
  end
  if type(tonumber(value)) == 'number' then
    local node = index.numbers:ExactMatch(tonumber(value)--[[@as number]])
    return node and node.data or {}
  end

  local b = self:StringToBoolean(string.lower(value))
  if b ~= nil then
    return index.bools[b] or {}
  end

  return index.ngrams[string.lower(value)] or {}
end

-- isNotInIndex returns every indexed item whose value is not the one isInIndex looks for, items
-- without the field included: the other items, as a plain set. An unknown field matches nothing.
---@param name string The name of the search index to lookup
---@param value any
---@return table<string, boolean>
function search:isNotInIndex(name, value)
  if not self:GetIndex(name) then return {} end
  return self:Complement(self:isInIndex(name, value))
end

-- Complement returns every item a query can match (Universe), or of within, that is not in set.
---@param set table<string, boolean>
---@param within? table<string, any>
---@return table<string, boolean>
function search:Complement(set, within)
  ---@type table<string, boolean>
  local results = {}
  for slotkey in pairs(within or self:Universe()) do
    if not set[slotkey] then
      results[slotkey] = true
    end
  end
  return results
end

-- isExactly returns the items whose value is exactly value (==): a whole text, without case; a
-- number or a boolean as = finds it.
---@param name string
---@param value any
---@return table<string, boolean>
function search:isExactly(name, value)
  local index = self:GetIndex(name)
  if not index then return {} end
  if not index.fullTextOnly and (tonumber(value) ~= nil or self:StringToBoolean(string.lower(value)) ~= nil) then
    return self:isInIndex(name, value)
  end
  return index.fullText[string.lower(value)] or {}
end

---@param value any
---@return table<string, boolean>
function search:DefaultSearch(value)
  ---@type table<string, boolean>
  local slots = {}
  for _, property in ipairs(self.defaultIndicies) do
    for slotkey in pairs(self:isFullTextMatch(property, value)) do
      slots[slotkey] = true
    end
  end
  return slots
end

---@param query string
---@param item ItemData
---@return boolean
function search:Find(query, item)
  return self:EvaluateQuery(QueryParser:Query(query))[item.slotkey] == true
end

---@param query string
---@return table<string, boolean>
function search:Search(query)
  ---@type table<string, boolean>
  local results = {}
  for k, v in pairs(self:EvaluateQuery(QueryParser:Query(query))) do
    if v then
      results[k] = true
    end
  end
  return results
end


---@param name string The name of the search index to lookup
---@param value any
---@return table<string, boolean>
function search:isLess(name, value)
  local index = self:GetIndex(name)
  if not index then return {} end
  if type(tonumber(value)) == 'number' then
    ---@type table<string, boolean>
    local results = {}
    local nodes = index.numbers:LessThan(tonumber(value)--[[@as number]])
    for _, node in pairs(nodes) do
      for k, v in pairs(node.data) do
        results[k] = v
      end
    end
    return results
  end
  return {}
end

---@param name string The name of the search index to lookup
---@param value any
---@return table<string, boolean>
function search:isLessOrEqual(name, value)
  local index = self:GetIndex(name)
  if not index then return {} end
  if type(tonumber(value)) == 'number' then
    ---@type table<string, boolean>
    local results = {}
    local nodes = index.numbers:LessThanEqual(tonumber(value)--[[@as number]])
    for _, node in pairs(nodes) do
      for k, v in pairs(node.data) do
        results[k] = v
      end
    end
    return results
  end
  return {}
end

---@param name string The name of the search index to lookup
---@param value any
---@return table<string, boolean>
function search:isGreater(name, value)
  local index = self:GetIndex(name)
  if not index then return {} end
  if type(tonumber(value)) == 'number' then
    ---@type table<string, boolean>
    local results = {}
    local nodes = index.numbers:GreaterThan(tonumber(value)--[[@as number]])
    for _, node in pairs(nodes) do
      for k, v in pairs(node.data) do
        results[k] = v
      end
    end
    return results
  end
  return {}
end

---@param name string The name of the search index to lookup
---@param value any
---@return table<string, boolean>
function search:isGreaterOrEqual(name, value)
  local index = self:GetIndex(name)
  if not index then return {} end
  if type(tonumber(value)) == 'number' then
    ---@type table<string, boolean>
    local results = {}
    local nodes = index.numbers:GreaterThanEqual(tonumber(value)--[[@as number]])
    for _, node in pairs(nodes) do
      for k, v in pairs(node.data) do
        results[k] = v
      end
    end
    return results
  end
  return {}
end

---@param name string The name of the search index to lookup
---@param value any
---@return table<string, boolean>
function search:isFullTextMatch(name, value)
  local index = self:GetIndex(name)
  if not index then return {} end
  local lower = string.lower(value)
  ---@type table<string, boolean>
  local results = {}
  for text, slots in pairs(index.fullText or {}) do
    if string.find(text, lower, 1, true) then
      for k, v in pairs(slots) do
        results[k] = v
      end
    end
  end
  return results
end

---@private
---@param operator string
---@param value string|number
---@return table<string, boolean>
function search:isRarity(operator, value)
  if type(tonumber(value)) == 'number' then
    if operator == "=" then
      return self:isInIndex('rarity', value)
    elseif operator == "!=" then
      return self:isNotInIndex('rarity', value)
    elseif operator == ">=" then
      return self:isGreaterOrEqual('rarity', value)
    elseif operator == "<=" then
      return self:isLessOrEqual('rarity', value)
    elseif operator == ">" then
      return self:isGreater('rarity', value)
    elseif operator == "<" then
      return self:isLess('rarity', value)
    else
      error("Unknown operator: " .. operator)
    end
  end
  local rarity = const.ITEM_QUALITY_TO_ENUM[value] --[[@as ItemQuality]]
  if not rarity then return {} end
  if operator == "=" then
    return self:isInIndex('rarity', rarity)
  elseif operator == "!=" then
    return self:isNotInIndex('rarity', rarity)
  elseif operator == ">=" then
    return self:isGreaterOrEqual('rarity', rarity)
  elseif operator == "<=" then
    return self:isLessOrEqual('rarity', rarity)
  elseif operator == ">" then
    return self:isGreater('rarity', rarity)
  elseif operator == "<" then
    return self:isLess('rarity', rarity)
  else
    error("Unknown operator: " .. operator)
  end
end

---@param node QueryNode
---@return table<string, boolean>
-- ExpansionNumberOf returns the number an expansion orders by (expansionNumber), from its short
-- name, or the start of exactly one expansion's name; nil for none or several.
---@param text string A lower-case name.
---@return number?
function search:ExpansionNumberOf(text)
  if expansionNumbers[text] then
    return expansionNumbers[text]
  end
  local found
  for name, number in pairs(expansionNumbers) do
    if name:sub(1, #text) == text then
      if found then
        return nil
      end
      found = number
    end
  end
  return found
end

-- Expansions compare by release for these operators, and for = and != with a number.
local ORDERED = { ["<"] = true, ["<="] = true, [">"] = true, [">="] = true }

---@return number? specID, string? name
local function playerSpecialization()
  local api = _G.C_SpecializationInfo
  local get = api and api.GetSpecialization or _G.GetSpecialization
  local info = api and api.GetSpecializationInfo or _G.GetSpecializationInfo
  if get == nil or info == nil then return nil end
  local index = get()
  if index == nil or index == 0 then return nil end
  local id, name = info(index)
  return id, name
end

-- PlayerValue reads a player value (player.level, ...) as Vendor's player functions do, when the
-- query is evaluated; nil for one the client cannot say or a name that is none. Text values that
-- have several names are lists (the class's token and its name; every profession's name and skill
-- line), matching when any does.
---@param name string The lower-case name after "player.".
---@return any
function search:PlayerValue(name)
  if name == 'level' then
    return _G.UnitLevel and UnitLevel("player")
  elseif name == 'ilvl' or name == 'equippedilvl' then
    if not _G.GetAverageItemLevel then return nil end
    local overall, equipped = GetAverageItemLevel()
    local value = name == 'ilvl' and overall or equipped
    return value and math.floor(value)
  elseif name == 'class' or name == 'classid' then
    if not _G.UnitClass then return nil end
    local className, token, classID = UnitClass("player")
    if name == 'classid' then return classID end
    return { token, className }
  elseif name == 'spec' or name == 'specid' then
    local id, specName = playerSpecialization()
    if name == 'specid' then return id end
    return specName
  elseif name == 'profession' then
    if not _G.GetProfessions or not _G.GetProfessionInfo then return nil end
    local values = {}
    for _, index in pairs({ GetProfessions() }) do
      local professionName, _, _, _, _, _, skillLine = GetProfessionInfo(index)
      table.insert(values, professionName)
      table.insert(values, skillLine)
    end
    return values
  elseif name == 'name' or name == 'realm' then
    if not _G.UnitFullName then return nil end
    local playerName, realm = UnitFullName("player")
    return name == 'name' and playerName or realm
  end
  return nil
end

-- dependsOnItem says whether an expression reads an item's field, so it has a value only for an item.
---@param node QueryNode
---@return boolean
local function dependsOnItem(node)
  if node.type == 'word' then
    if node.quoted then return false end
    local word = string.lower(node.value)
    return word:sub(1, 7) ~= 'player.' and tonumber(word) == nil and moneyOf(word) == nil
      and fieldKey(word) ~= nil
  elseif node.type == 'arith' then
    return dependsOnItem(node.left) or dependsOnItem(node.right)
  elseif node.type == 'neg' then
    return dependsOnItem(node.expression)
  elseif node.type == 'call' then
    for _, arg in ipairs(node.args) do
      if dependsOnItem(arg) then return true end
    end
  end
  return false
end

-- ValueOf works out an expression's value: for an item's snapshot (search.indexed), or, without
-- one, for what does not depend on an item (a field then has no value).
---@param node QueryNode
---@param snapshot? table
---@return any
function search:ValueOf(node, snapshot)
  if node.type == 'value' then
    return node.value
  elseif node.type == 'word' then
    if node.quoted then return node.value end
    local word = string.lower(node.value)
    if word:sub(1, 7) == 'player.' then
      return self:PlayerValue(word:sub(8))
    end
    local number = tonumber(word) or moneyOf(word)
    if number then return number end
    local key = fieldKey(word)
    if key then
      return snapshot and snapshot[key]
    end
    return node.value
  elseif node.type == 'arith' then
    return arithmetic(node.operator, self:ValueOf(node.left, snapshot), self:ValueOf(node.right, snapshot))
  elseif node.type == 'neg' then
    local v = self:ValueOf(node.expression, snapshot)
    return type(v) == 'number' and -v or nil
  elseif node.type == 'call' then
    local args = {}
    for i, arg in ipairs(node.args) do
      args[i] = self:ValueOf(arg, snapshot)
    end
    return QUERY_FUNCTIONS[node.name](args)
  end
  return nil
end

-- Fold replaces each part of an expression that does not depend on an item with its value, so a
-- check made item by item works it out once.
---@param node QueryNode
---@return QueryNode
function search:Fold(node)
  if not dependsOnItem(node) then
    return { type = 'value', value = self:ValueOf(node) }
  elseif node.type == 'arith' then
    return { type = 'arith', operator = node.operator, left = self:Fold(node.left), right = self:Fold(node.right) }
  elseif node.type == 'neg' then
    return { type = 'neg', expression = self:Fold(node.expression) }
  elseif node.type == 'call' then
    local args = {}
    for i, arg in ipairs(node.args) do args[i] = self:Fold(arg) end
    return { type = 'call', name = node.name, args = args }
  end
  return node
end

-- MatchEach checks a comparison (its constant parts folded) item by item, over candidates: the items
-- the rest of an AND matched, or every item.
---@param node QueryNode A compare node.
---@param candidates table<string, any>
---@return table<string, boolean>
function search:MatchEach(node, candidates)
  ---@type table<string, boolean>
  local results = {}
  for slotkey in pairs(candidates) do
    local snapshot = self.indexed[slotkey]
    if snapshot and compareValues(self:ValueOf(node.left, snapshot), node.operator,
      self:ValueOf(node.right, snapshot)) then
      results[slotkey] = true
    end
  end
  return results
end

-- everything returns every item a query can match within candidates (or the universe), for a
-- comparison that holds whatever the item.
---@param within? table<string, any>
---@return table<string, boolean>
function search:everything(within)
  ---@type table<string, boolean>
  local results = {}
  for slotkey in pairs(within or self:Universe()) do
    results[slotkey] = true
  end
  return results
end

---@param value any
---@return string?
local function indexValue(value)
  if type(value) == 'number' then return tostring(value) end
  if type(value) == 'boolean' then return value and "true" or "false" end
  if type(value) == 'string' then return value end
  return nil
end

-- needsItems says whether a condition is checked item by item somewhere (search:MatchEach), so an
-- AND evaluates its other side first and checks only that side's matches.
---@param node QueryNode
---@return boolean
local function needsItems(node)
  if node.type == 'logical' then
    if node.operator == 'NOT' then return needsItems(node.expression) end
    return needsItems(node.left) or needsItems(node.right)
  elseif node.type == 'compare' then
    return dependsOnItem(node.left) and dependsOnItem(node.right)
      or not ((node.left.type == 'word' and dependsOnItem(node.left)) or (node.right.type == 'word' and dependsOnItem(node.right)))
  elseif node.type == 'comparison' then
    local value = string.lower(node.value)
    return not node.quoted and NUMERIC[fieldKey(string.lower(node.field)) or ''] == true
      and fieldKey(value) ~= nil and tonumber(value) == nil
  end
  return false
end

---@param node QueryNode
---@param within? table<string, any> The only items whose answer matters (an AND's other side).
---@return table<string, boolean>
function search:EvaluateAST(node, within)
  if node == nil then
      error("Encountered nil node in AST")
  end

  ---@param field string
  ---@param operator string
  ---@param value any
  ---@return table<string, boolean>
  local function evaluate_condition(field, operator, value)
      value = string.lower(value)
      field = string.lower(field)
      -- Rarity is a special case, as it is an enum.
      if field == "rarity" then
        return self:isRarity(operator == "==" and "=" or operator == "~=" and "!=" or operator, value)
      end
      -- Expansions order by release (expansionid): a comparison, or a number, never a name as text.
      if (field == "expansion" or field == "exp")
        and (ORDERED[operator] or (tonumber(value) and (operator == "=" or operator == "!="
          or operator == "==" or operator == "~="))) then
        local number = tonumber(value) or self:ExpansionNumberOf(value)
        if number == nil then
          return {}
        end
        field, value = "expansionid", tostring(number)
      end
      if operator == "=" then
        return self:isInIndex(field, value)
      elseif operator == "==" then
        return self:isExactly(field, value)
      elseif operator == "!=" then
        return self:isNotInIndex(field, value)
      elseif operator == "~=" then
        if not self:GetIndex(field) then return {} end
        return self:Complement(self:isExactly(field, value))
      elseif operator == "%=" then
        return self:isFullTextMatch(field, value)
      elseif operator == ">=" then
        return self:isGreaterOrEqual(field, value)
      elseif operator == "<=" then
        return self:isLessOrEqual(field, value)
      elseif operator == ">" then
        return self:isGreater(field, value)
      elseif operator == "<" then
        return self:isLess(field, value)
      else
        return {}
      end
  end

  -- compare answers a comparison of two expressions: with no field, the same for every item; a field
  -- against a constant, from the index (sides swapped if needed); else item by item.
  ---@param cmp QueryNode
  ---@return table<string, boolean>
  local function compare(cmp)
    local leftItem, rightItem = dependsOnItem(cmp.left), dependsOnItem(cmp.right)
    if not leftItem and not rightItem then
      if compareValues(self:ValueOf(cmp.left), cmp.operator, self:ValueOf(cmp.right)) then
        return self:everything(within)
      end
      return {}
    end
    local field, constant, operator
    if cmp.left.type == 'word' and leftItem and not rightItem then
      field, constant, operator = cmp.left.value, cmp.right, cmp.operator
    elseif cmp.right.type == 'word' and rightItem and not leftItem and FLIPPED[cmp.operator] then
      field, constant, operator = cmp.right.value, cmp.left, FLIPPED[cmp.operator]
    end
    -- A value with several names (a player's class: its token and its name) is checked item by item.
    if field and LIST_KEYS[ALIASES[string.lower(field)] or string.lower(field)] == nil
      and type(self:ValueOf(constant)) ~= 'table' then
      local value = indexValue(self:ValueOf(constant))
      if value == nil then return {} end
      return evaluate_condition(field, operator, value)
    end
    local folded = { type = 'compare', left = self:Fold(cmp.left), operator = cmp.operator, right = self:Fold(cmp.right) }
    return self:MatchEach(folded, within or self:Universe())
  end

  -- comparison answers field op word as queries always have, reading the word by the field's type:
  -- a player value is the player's with any field; money or another numeric field compared with a
  -- numeric field takes the new meaning (a number, item by item); for anything else the word is what
  -- it always was.
  ---@param cmp QueryNode
  ---@return table<string, boolean>
  local function comparison(cmp)
    local field = string.lower(cmp.field)
    local key = fieldKey(field)
    local asExpression = function()
      return compare({ type = 'compare', left = { type = 'word', value = cmp.field }, operator = cmp.operator,
        right = { type = 'word', value = cmp.value, quoted = cmp.quoted } })
    end
    -- A word that names no field: a player value or a number compares as an expression; anything
    -- else matches nothing, as an unknown field always has.
    if not self:GetIndex(field) then
      if field:sub(1, 7) == 'player.' or tonumber(field) or moneyOf(field) then
        return asExpression()
      end
      return {}
    end
    if cmp.quoted then
      return evaluate_condition(cmp.field, cmp.operator, cmp.value)
    end
    local value = string.lower(cmp.value)
    if value:sub(1, 7) == 'player.' then
      return asExpression()
    end
    if NUMERIC[key or ''] then
      if fieldKey(value) ~= nil and tonumber(value) == nil then
        return asExpression()
      end
      local money = moneyOf(value)
      if money then
        return evaluate_condition(cmp.field, cmp.operator, tostring(money))
      end
    end
    if key == 'equipmentlocation' and value:match("^invtype_") then
      local slotName = _G[string.upper(value)]
      if type(slotName) == 'string' and slotName ~= "" then
        return evaluate_condition(cmp.field, cmp.operator, slotName)
      end
    end
    return evaluate_condition(cmp.field, cmp.operator, cmp.value)
  end

  if node.type == "logical" then
      if node.operator == "AND" then
          -- A side that is a NOT removes its expression's items from the other side, which costs
          -- what that side holds, not every indexed item (Complement). Otherwise the side the index
          -- answers goes first, and the other is checked only on its matches.
          local keep, drop = node.left, nil
          if node.right.type == "logical" and node.right.operator == "NOT" then
            drop = node.right.expression
          elseif node.left.type == "logical" and node.left.operator == "NOT" then
            keep, drop = node.right, node.left.expression
          end
          ---@type table<string, boolean>
          local result = {}
          if drop then
            local kept = self:EvaluateAST(keep, within)
            local removed = self:EvaluateAST(drop, kept)
            for k, v in pairs(kept) do
              if v and not removed[k] then
                result[k] = true
              end
            end
            return result
          end
          local first, second = node.left, node.right
          if needsItems(first) and not needsItems(second) then
            first, second = second, first
          end
          local firstResult = self:EvaluateAST(first, within)
          for k, v in pairs(self:EvaluateAST(second, firstResult)) do
            if v and firstResult[k] then
              result[k] = true
            end
          end
          return result
      elseif node.operator == "OR" then
          ---@type table<string, boolean>
          local result = {}
          for k, v in pairs(self:EvaluateAST(node.left, within)) do
            if v then result[k] = true end
          end
          for k, v in pairs(self:EvaluateAST(node.right, within)) do
            if v then result[k] = true end
          end
          return result
      elseif node.operator == "NOT" then
          return self:Complement(self:EvaluateAST(node.expression, within), within)
      else
          error("Unknown logical operator: " .. node.operator)
      end
  elseif node.type == "comparison" then
      return comparison(node)
  elseif node.type == "compare" then
      return compare(node)
  elseif node.type == "term" then
      local found = self:DefaultSearch(node.value)
      -- A word naming a true or false field also finds the items where it is true: "NOT collectable".
      local field = not node.quoted and fieldKey(string.lower(node.value))
      if field and BOOLEAN[field] then
        for slotkey in pairs(self:isInIndex(field, "true")) do
          found[slotkey] = true
        end
      end
      return found
  else
      error("Unknown node type: " .. node.type)
  end
end

-- EvaluateQuery returns the items a parsed query matches, by slot key. Every part of a query is a
-- set of the items it matches: AND keeps the items in both, OR the items in either, and NOT (and !=)
-- every item a query can match (Universe) outside its part's set.
---@param ast? QueryNode
---@return table<string, boolean>
function search:EvaluateQuery(ast)
  if ast == nil then return {} end
  debug:Inspect("ast", ast)
  local result = self:EvaluateAST(ast)
  debug:Inspect("ast result", result)
  return result
end

-- Universe returns every item a query can match, by slot key: every item indexed now. During a
-- sweep that is this sweep's items of the kind being read and the committed items of the others
-- (Phase 8 syncs both before searching, search-indexing.md §4); a search instance of other items
-- (BetterBags Next's vendor, next/merchant.lua) has its own.
---@return table<string, any>
function search:Universe()
  return self.indexed
end
