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

  search:addNumberToIndex(self.indicies.itemLevel, item.itemInfo.itemLevel, item.slotkey)
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

  search:removeNumberFromIndex(self.indicies.itemLevel, item.itemInfo.itemLevel, item.slotkey)
end


---@param property string
---@return SearchIndex?
function search:GetIndex(property)
  if not self.indicies[property] and not self.indexLookup[property] then return end
  return self.indicies[property] or self.indexLookup[property]
end

---@param index SearchIndex
---@param value any
---@return table<string, boolean>
function search:isInIndex(index, value)
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
    local index = self:GetIndex(property)
    if index then
      for slotkey in pairs(self:isInIndex(index, value)) do
        slots[slotkey] = true
      end
    end
  end
  return slots
end

---@param query string
---@param item ItemData
---@return boolean
function search:Find(query, item)
  local ast = QueryParser:Query(query)
  local p, n = self:evaluate_query(ast)
  return p[item.slotkey] and not n[item.slotkey]
end

---@param query string
---@return string[]
function search:Search(query)
  return {}
--  local ast = QueryParser:Query(query)
--  debug:Inspect("ast", ast)
--  local slots = {}
--  local terms = self:ParseQuery(query)
--  for _, term in ipairs(terms) do
--    for slotkey in pairs(self:Match(term)) do
--      table.insert(slots, slotkey)
--    end
--  end
--  return slots
end

--[[




]]

function search:evaluate_ast(node)
  local function evaluate_condition(field, operator, value)
      if operator == "=" then
          return self:isInIndex(field, value)
      elseif operator == ">=" then
          return isGreaterOrEqual(field, value)
      elseif operator == "<=" then
          return isLessOrEqual(field, value)
      elseif operator == ">" then
          return isGreater(field, value)
      elseif operator == "<" then
          return isLess(field, value)
      else
          error("Unknown operator: " .. operator)
      end
  end

  local function combine_results(op, left, right)
      local result = {}
      if op == "AND" then
          for k, v in pairs(left) do
              if right[k] then
                  result[k] = true
              end
          end
      elseif op == "OR" then
          for k, v in pairs(left) do result[k] = true end
          for k, v in pairs(right) do result[k] = true end
      end
      return result
  end

  if node.type == "logical" then
      if node.operator == "AND" or node.operator == "OR" then
          local left = self:evaluate_ast(node.left)
          local right = self:evaluate_ast(node.right)
          return combine_results(node.operator, left, right)
      elseif node.operator == "NOT" then
          -- For NOT, we evaluate the right node (not expression)
          local result = self:evaluate_ast(node.right)
          -- We can't know the full set of possible results here,
          -- so we'll return the negated results we do have
          local negated = {}
          for k, v in pairs(result) do
              negated[k] = false
          end
          return negated
      end
  elseif node.type == "comparison" then
      return evaluate_condition(node.field, node.operator, node.value)
  elseif node.type == "term" then
      return self:DefaultSearch(node.value)
  else
      error("Unknown node type: " .. node.type)
  end
end

function search:evaluate_query(ast)
  if ast == nil then return {}, {} end
  local result = self:evaluate_ast(ast)
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