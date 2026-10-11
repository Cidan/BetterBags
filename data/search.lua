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
  'binding', 'tooltip', 'level', 'rarity', 'id', 'stackcount', 'class', 'subclass', 'bagid',
  'slotid', 'bindtype', 'reagent', 'isbound', 'bound', 'quest', 'activequest',
}

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
  return sameList(a.sets, b.sets) and sameList(a.bonusIDs, b.bonusIDs)
end

-- Number and boolean snapshot fields share their name with the index they go into.
local NUMBER_FIELDS = {
  'level', 'rarity', 'id', 'stackcount', 'class', 'subclass', 'bagid', 'slotid', 'bindtype',
}
local BOOL_FIELDS = { 'reagent', 'isbound', 'bound', 'quest', 'activequest' }

-- scratch is reused to snapshot each item SyncKind compares, so an unchanged item costs no
-- allocation.
local scratch = {}

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
  self.indicies = {}
  self.indexed = {}
  -- String indexes
  self:CreateIndex('name')
  self:CreateIndex('type')
  self:CreateIndex('subtype')
  self:CreateIndex('category')
  self:CreateIndex('equipmentlocation')
  self:CreateIndex('expansion')
  self:CreateIndex('equipmentset')
  self:CreateIndex('bagName')
  self:CreateIndex('guid')
  self:CreateIndex('binding')
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
  self:CreateIndex('bonusid')

  -- Boolean indexes
  self:CreateIndex('reagent')
  self:CreateIndex('isbound') -- from C_Item
  self:CreateIndex('bound') -- from Binding
  self:CreateIndex('quest')
  self:CreateIndex('activequest')

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
---@param kind BagKind
---@param items table<string, ItemData>|nil
---@param rebuild? boolean
function search:SyncKind(kind, items, rebuild)
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
      elseif not sameSnapshot(fillSnapshot(scratch, item), snap) then
        self:Add(item)
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
    oldCategory = snap.category
    snap.category = item.itemInfo.category
  end
  search:removeStringFromIndex(self.indicies.category, oldCategory, item.slotkey)
  search:addStringToIndex(self.indicies.category, item.itemInfo.category, item.slotkey)
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

---@param name string The name of the search index to lookup
---@param value any
---@return table<string, boolean>
function search:isNotInIndex(name, value)
  local index = self:GetIndex(name)
  if not index then return {} end
  ---@type table<string, boolean>
  local results = {
    ["___NEGATED___"] = true
  }
  if index.fullTextOnly then
    for k in pairs(self:isFullTextMatch(name, tostring(value))) do
      results[k] = false
    end
    return results
  end
  if type(tonumber(value)) == 'number' then
    local node = index.numbers:ExactMatch(tonumber(value)--[[@as number]])
    if node then
      for k in pairs(node.data) do
        results[k] = false
      end
      return results
    else
      return results
    end
  end

  local b = self:StringToBoolean(string.lower(value))
  if b ~= nil then
    if index.bools[b] then
      for k in pairs(index.bools[b]) do
        results[k] = false
      end
    end
    return results
  end

  if index.ngrams[string.lower(value)] ~= nil then
    for k in pairs(index.ngrams[string.lower(value)]) do
      results[k] = false
    end
  end
  return results
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
  local ast = QueryParser:Query(query)
  local p, n = self:EvaluateQuery(ast)
  return p[item.slotkey] and not n[item.slotkey]
end

---@param query string
---@return table<string, boolean>
function search:Search(query)
  ---@type table<string, boolean>
  local results = {}
  local ast = QueryParser:Query(query)
  local p, n = self:EvaluateQuery(ast)
  for k, v in pairs(p) do
    if v and not n[k] then
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
function search:EvaluateAST(node)
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
        return self:isRarity(operator, value)
      end
      if operator == "=" then
        return self:isInIndex(field, value)
      elseif operator == "!=" then
        return self:isNotInIndex(field, value)
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

  ---@param op string
  ---@param left table<string, boolean>
  ---@param right table<string, boolean>
  ---@return table<string, boolean>
  local function combine_results(op, left, right)
    ---@type table<string, boolean>
    local result = {}
    if op == "AND" then
      for k in pairs(left) do
        if left[k] == true then
          if right[k] == true or (right[k] == nil and right["___NEGATED___"] == true) then
            result[k] = true
          else
            result[k] = false
          end
        elseif left[k] == false then
          result[k] = false
        elseif left[k] == nil and left["___NEGATED___"] == true then
          if right[k] == false then
            result[k] = true
          else
            result[k] = false
          end
        end
      end
      for k in pairs(right) do
        if not result[k] then
          if right[k] == true then
            if left[k] == true or (left[k] == nil and left["___NEGATED___"] == true) then
              result[k] = true
            else
              result[k] = false
            end
          elseif right[k] == false then
              result[k] = false
          elseif right[k] == nil and right["___NEGATED___"] == true then
            if left[k] == false then
              result[k] = true
            else
              result[k] = false
            end
          end
        end
      end
    elseif op == "OR" then
      for k, v in pairs(left) do result[k] = v end
      for k, v in pairs(right) do
        if result[k] == nil or (result[k] == false and v == true) then
          result[k] = v
        end
      end
    end
    return result
  end

  if node.type == "logical" then
      if node.operator == "AND" or node.operator == "OR" then
          local left = self:EvaluateAST(node.left)
          local right = self:EvaluateAST(node.right)
          return combine_results(node.operator, left, right)
      elseif node.operator == "NOT" then
          if node.expression == nil then
              return {}
          end
          local result = self:EvaluateAST(node.expression)
         ---@type table<string, boolean>
          local negated = {}
          for k in pairs(result) do
              negated[k] = false
          end
          negated["___NEGATED___"] = true
          return negated
      else
          error("Unknown logical operator: " .. node.operator)
      end
  elseif node.type == "comparison" then
      return evaluate_condition(node.field, node.operator, node.value)
  elseif node.type == "term" then
      return self:DefaultSearch(node.value)
  else
      error("Unknown node type: " .. node.type)
  end
end

---@param ast? QueryNode
---@return table<string, boolean>, table<string, boolean>
function search:EvaluateQuery(ast)
  if ast == nil then return {}, {} end
  debug:Inspect("ast", ast)
  local result = self:EvaluateAST(ast)
  debug:Inspect("ast result", result)

  ---@type table<string, boolean>, table<string, boolean>
  local positive, negative = {}, {}
  for k, v in pairs(result) do
      if v then
          positive[k] = true
      else
          negative[k] = true
      end
  end

  -- This is a special case where we want to return all items in the index that are not
  -- in the result set, as this is a negation of the entire index.
  if not ast.left and not ast.right and ast.operator == "!=" then
    -- JIT load this module, as there is a circular dependency.
    ---@class Items: AceModule
    local items = addon:GetModule('Items')

    for _, slotInfo in pairs(items:GetAllSlotInfo()) do
      for k in pairs(slotInfo.itemsBySlotKey) do
        if not negative[k] then
          positive[k] = true
        end
      end
    end
  end
  return positive, negative
end
