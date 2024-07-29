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

---@class Search: AceModule
---@field private indicies table<string, SearchIndex>
---@field private indexLookup table<string, SearchIndex>
---@field private defaultIndicies string[]
local search = addon:NewModule('Search')

function search:CreateIndex(name)
  self.indicies[name] = {
    property = name,
    ngrams = {},
    numbers = trees.NewIntervalTree()
  }
end

function search:OnInitialize()
  self.indicies = {}
  self:CreateIndex('name')
  self:CreateIndex('itemLevel')
  self:CreateIndex('rarity')
  self:CreateIndex('type')
  self:CreateIndex('subtype')
  self:CreateIndex('category')
  self:CreateIndex('equipmentLocation')
  self:CreateIndex('expansion')
  self:CreateIndex('equipmentSet')

  self.defaultIndicies = {
    'name',
    'type',
    'category',
    'subtype',
    'equipmentLocation'
  }

  self.indexLookup = {
    exp = self.indicies.expansion,
    gear = self.indicies.equipmentLocation,
    ilvl = self.indicies.itemLevel,
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
end

---@param item ItemData
function search:Add(item)
  search:addStringToIndex(self.indicies.name, item.itemInfo.itemName, item.slotkey)
  search:addStringToIndex(self.indicies.type, item.itemInfo.itemType, item.slotkey)
  search:addStringToIndex(self.indicies.subtype, item.itemInfo.itemSubType, item.slotkey)
  search:addStringToIndex(self.indicies.category, item.itemInfo.category, item.slotkey)

  if item.itemInfo.equipmentSet ~= nil then
    search:addStringToIndex(self.indicies.equipmentSet, item.itemInfo.equipmentSet, item.slotkey)
  end

  if item.itemInfo.expacID ~= nil and const.BRIEF_EXPANSION_MAP[item.itemInfo.expacID] ~= nil then
    search:addStringToIndex(self.indicies.expansion, const.BRIEF_EXPANSION_MAP[item.itemInfo.expacID], item.slotkey)
  end

  if item.itemInfo.itemEquipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" and
  _G[item.itemInfo.itemEquipLoc] ~= nil and
  _G[item.itemInfo.itemEquipLoc] ~= "" then
    search:addStringToIndex(self.indicies.equipmentLocation, _G[item.itemInfo.itemEquipLoc], item.slotkey)
  end

  search:addNumberToIndex(self.indicies.itemLevel, item.itemInfo.currentItemLevel, item.slotkey)
end

---@param item ItemData
function search:Remove(item)
  search:removeStringFromIndex(self.indicies.name, item.itemInfo.itemName, item.slotkey)
  search:removeStringFromIndex(self.indicies.type, item.itemInfo.itemType, item.slotkey)
  search:removeStringFromIndex(self.indicies.subtype, item.itemInfo.itemSubType, item.slotkey)
  search:removeStringFromIndex(self.indicies.category, item.itemInfo.category, item.slotkey)

  if item.itemInfo.equipmentSet ~= nil then
    search:removeStringFromIndex(self.indicies.equipmentSet, item.itemInfo.equipmentSet, item.slotkey)
  end

  if item.itemInfo.expacID ~= nil and const.BRIEF_EXPANSION_MAP[item.itemInfo.expacID] ~= nil then
    search:removeStringFromIndex(self.indicies.expansion, const.BRIEF_EXPANSION_MAP[item.itemInfo.expacID], item.slotkey)
  end

  if item.itemInfo.itemEquipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" and
  _G[item.itemInfo.itemEquipLoc] ~= nil and
  _G[item.itemInfo.itemEquipLoc] ~= "" then
    search:removeStringFromIndex(self.indicies.equipmentLocation, _G[item.itemInfo.itemEquipLoc], item.slotkey)
  end

  search:removeNumberFromIndex(self.indicies.itemLevel, item.itemInfo.currentItemLevel, item.slotkey)
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

---@param node QueryNode
---@return table<string, boolean>
function search:EvaluateAST(node)
  if node == nil then
      error("Encountered nil node in AST")
  end

  local function evaluate_condition(field, operator, value)
      if operator == "=" then
          return self:isInIndex(field, value)
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

  ---@param result table<string, boolean>
  ---@return boolean
  local function has_negative(result)
      for _, v in pairs(result) do
          if not v then
              return true
          end
      end
      return false
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
            elseif left[k] == true and right[k] == nil and has_negative(right) then
              result[k] = true
            elseif left[k] == true and right[k] == nil and not has_negative(right) then
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
            elseif right[k] == true and left[k] == nil and has_negative(left) then
              result[k] = true
            elseif right[k] == true and left[k] == nil and not has_negative(left) then
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
          local negated = {}
          for k, v in pairs(result) do
              negated[k] = false
          end
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