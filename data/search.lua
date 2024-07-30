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

---@class Search: AceModule
---@field private indicies table<string, SearchIndex>
---@field private indexLookup table<string, SearchIndex>
---@field private defaultIndicies string[]
local search = addon:NewModule('Search')

function search:CreateIndex(name)
  self.indicies[name] = {
    property = name,
    ngrams = {},
    numbers = trees.NewIntervalTree(),
    bools = {},
    fullText = {}
  }
end

function search:OnInitialize()
  self.indicies = {}
  -- String indexes
  self:CreateIndex('name')
  self:CreateIndex('type')
  self:CreateIndex('subtype')
  self:CreateIndex('category')
  self:CreateIndex('equipmentlocation')
  self:CreateIndex('expansion')
  self:CreateIndex('equipmentset')
  self:CreateIndex('bagName')

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

  -- Boolean indexes
  self:CreateIndex('reagent')
  self:CreateIndex('bound')
  self:CreateIndex('quest')
  self:CreateIndex('activequest')

  self.defaultIndicies = {
    'name',
    'type',
    'category',
    'subtype',
    'equipmentLocation'
  }

  self.indexLookup = {
    exp = self.indicies.expansion,
    slot = self.indicies.equipmentlocation,
    ilvl = self.indicies.level,
    count = self.indicies.stackCount,
  }
end

-- Wipe will clear all data from the search index.
function search:Wipe()
  for _, index in pairs(self.indicies) do
    index.ngrams = {}
    index.numbers = trees.NewIntervalTree()
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
  index.bools[value] = index.bools[value] or {}
  index.bools[value][slotkey] = nil
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
  local prefix = ""
  value = string.lower(value)
  for i = 1, #value do
    prefix = prefix .. value:sub(i, i)
    index.ngrams[prefix] = index.ngrams[prefix] or {}
    index.ngrams[prefix][slotkey] = true
  end
  index.fullText[value] = index.fullText[value] or {}
  index.fullText[value][slotkey] = true
end

---@private
---@param index SearchIndex
---@param value string
---@param slotkey string
function search:removeStringFromIndex(index, value, slotkey)
  local prefix = ""
  value = string.lower(value)
  for i = 1, #value do
    prefix = prefix .. value:sub(i, i)
    index.ngrams[prefix] = index.ngrams[prefix] or {}
    index.ngrams[prefix][slotkey] = nil
  end
  index.fullText[value] = index.fullText[value] or {}
  index.fullText[value][slotkey] = nil
end

---@param item ItemData
function search:Add(item)
  search:addStringToIndex(self.indicies.name, item.itemInfo.itemName, item.slotkey)
  search:addStringToIndex(self.indicies.type, item.itemInfo.itemType, item.slotkey)
  search:addStringToIndex(self.indicies.subtype, item.itemInfo.itemSubType, item.slotkey)
  search:addStringToIndex(self.indicies.category, item.itemInfo.category, item.slotkey)
  --search:addStringToIndex(self.indicies.bagName, item.bagName, item.slotkey)

  if item.itemInfo.equipmentSet ~= nil then
    search:addStringToIndex(self.indicies.equipmentset, item.itemInfo.equipmentSet, item.slotkey)
  end

  if item.itemInfo.expacID ~= nil and const.BRIEF_EXPANSION_MAP[item.itemInfo.expacID] ~= nil then
    search:addStringToIndex(self.indicies.expansion, const.BRIEF_EXPANSION_MAP[item.itemInfo.expacID], item.slotkey)
  end

  if item.itemInfo.itemEquipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" and
  _G[item.itemInfo.itemEquipLoc] ~= nil and
  _G[item.itemInfo.itemEquipLoc] ~= "" then
    search:addStringToIndex(self.indicies.equipmentlocation, _G[item.itemInfo.itemEquipLoc], item.slotkey)
  end

  search:addNumberToIndex(self.indicies.level, item.itemInfo.currentItemLevel, item.slotkey)
  search:addNumberToIndex(self.indicies.rarity, item.itemInfo.itemQuality, item.slotkey)
  search:addNumberToIndex(self.indicies.id, item.itemInfo.itemID, item.slotkey)
  search:addNumberToIndex(self.indicies.stackcount, item.itemInfo.currentItemCount, item.slotkey)
  search:addNumberToIndex(self.indicies.class, item.itemInfo.classID, item.slotkey)
  search:addNumberToIndex(self.indicies.subclass, item.itemInfo.subclassID, item.slotkey)
  search:addNumberToIndex(self.indicies.bagid, item.bagid, item.slotkey)
  search:addNumberToIndex(self.indicies.slotid, item.slotid, item.slotkey)

  search:addBoolToIndex(self.indicies.reagent, item.itemInfo.isCraftingReagent, item.slotkey)
  search:addBoolToIndex(self.indicies.bound, item.itemInfo.isBound, item.slotkey)
  search:addBoolToIndex(self.indicies.quest, item.questInfo.isQuestItem, item.slotkey)
  search:addBoolToIndex(self.indicies.activequest, item.questInfo.isActive, item.slotkey)
end

---@param item ItemData
function search:Remove(item)
  search:removeStringFromIndex(self.indicies.name, item.itemInfo.itemName, item.slotkey)
  search:removeStringFromIndex(self.indicies.type, item.itemInfo.itemType, item.slotkey)
  search:removeStringFromIndex(self.indicies.subtype, item.itemInfo.itemSubType, item.slotkey)
  search:removeStringFromIndex(self.indicies.category, item.itemInfo.category, item.slotkey)
  --search:removeStringFromIndex(self.indicies.bagName, item.bagName, item.slotkey)

  if item.itemInfo.equipmentSet ~= nil then
    search:removeStringFromIndex(self.indicies.equipmentset, item.itemInfo.equipmentSet, item.slotkey)
  end

  if item.itemInfo.expacID ~= nil and const.BRIEF_EXPANSION_MAP[item.itemInfo.expacID] ~= nil then
    search:removeStringFromIndex(self.indicies.expansion, const.BRIEF_EXPANSION_MAP[item.itemInfo.expacID], item.slotkey)
  end

  if item.itemInfo.itemEquipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" and
  _G[item.itemInfo.itemEquipLoc] ~= nil and
  _G[item.itemInfo.itemEquipLoc] ~= "" then
    search:removeStringFromIndex(self.indicies.equipmentlocation, _G[item.itemInfo.itemEquipLoc], item.slotkey)
  end

  search:removeNumberFromIndex(self.indicies.level, item.itemInfo.currentItemLevel, item.slotkey)
  search:removeNumberFromIndex(self.indicies.rarity, item.itemInfo.itemQuality, item.slotkey)
  search:removeNumberFromIndex(self.indicies.id, item.itemInfo.itemID, item.slotkey)
  search:removeNumberFromIndex(self.indicies.stackcount, item.itemInfo.currentItemCount, item.slotkey)
  search:removeNumberFromIndex(self.indicies.class, item.itemInfo.classID, item.slotkey)
  search:removeNumberFromIndex(self.indicies.subclass, item.itemInfo.subclassID, item.slotkey)
  search:removeNumberFromIndex(self.indicies.bagid, item.bagid, item.slotkey)
  search:removeNumberFromIndex(self.indicies.slotid, item.slotid, item.slotkey)

  search:removeBoolFromIndex(self.indicies.reagent, item.itemInfo.isCraftingReagent, item.slotkey)
  search:removeBoolFromIndex(self.indicies.bound, item.itemInfo.isBound, item.slotkey)
  search:removeBoolFromIndex(self.indicies.quest, item.questInfo.isQuestItem, item.slotkey)
  search:removeBoolFromIndex(self.indicies.activequest, item.questInfo.isActive, item.slotkey)
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
  if type(tonumber(value)) == 'number' then
    local node = index.numbers:ExactMatch(tonumber(value)--[[@as number]])
    return node and node.data or {}
  end

  local b = self:StringToBoolean(value)
  if b ~= nil then
    return index.bools[b] or {}
  end

  return index.ngrams[value] or {}
end

---@param value any
---@return table<string, boolean>
function search:DefaultSearch(value)
  ---@type table<string, boolean>
  local slots = {}
  for _, property in ipairs(self.defaultIndicies) do
    for slotkey in pairs(self:isInIndex(property, value)) do
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
  ---@type table<string, boolean>
  local results = {}
  for text, slots in pairs(index.fullText or {}) do
    if string.match(text, value) then
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
  local rarity = const.ITEM_QUALITY_TO_ENUM[value] --[[@as Enum.ItemQuality]]
  if not rarity then return {} end
  if operator == "=" then
    return self:isInIndex('rarity', rarity)
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

  local function evaluate_condition(field, operator, value)
      value = string.lower(value)
      field = string.lower(field)
      -- Rarity is a special case, as it is an enum.
      if field == "rarity" then
        return self:isRarity(operator, value)
      end
      if operator == "=" then
          return self:isInIndex(field, value)
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
          error("Unknown operator: " .. operator)
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
            if left[k] and right[k] then
              result[k] = true
            elseif left[k] == false or right[k] == false then
              result[k] = false
            elseif left[k] == true and right[k] == nil and right["___NEGATED___"] == true then
              result[k] = true
            elseif left[k] == true and right[k] == nil and not right["___NEGATED___"] then
              result[k] = false
            else
              result[k] = true
            end
          end
          for k in pairs(right) do
            if right[k] and left[k] then
              result[k] = true
            elseif right[k] == false or left[k] == false then
              result[k] = false
            elseif right[k] == true and left[k] == nil and left["___NEGATED___"] == true then
              result[k] = true
            elseif right[k] == true and left[k] == nil and not left["___NEGATED___"] then
              result[k] = false
            else
              result[k] = true
            end
          end
      elseif op == "OR" then
          for k, v in pairs(left) do result[k] = v end
          for k, v in pairs(right) do result[k] = v end
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
              error("NOT node has no expression")
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
  local result = self:EvaluateAST(ast)
  ---@type table<string, boolean>, table<string, boolean>
  local positive, negative = {}, {}
  for k, v in pairs(result) do
      if v then
          positive[k] = true
      else
          negative[k] = true
      end
  end
  return positive, negative
end