local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

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

-- ParseQuery will parse a query string and return a set of boolean
-- filters that can be matched against an item.
---@private
---@param query string
---@return string[]
function search:ParseQuery(query)
  local filters = {}
  for filter in string.gmatch(query, "([^&]+)") do
      table.insert(filters, string.trim(filter))
  end
  return filters
end

---@private
---@param index SearchIndex
---@param value number
---@param slotkey string
function search:addNumberToIndex(index, value, slotkey)
  index.numbers:Insert(value, {[slotkey] = true})
  --index.numbers[value] = index.numbers[value] or {}
  --index.numbers[value][slotkey] = true
end

---@private
---@param index SearchIndex
---@param value number
---@param slotkey string
function search:removeNumberFromIndex(index, value, slotkey)
  --index.numbers[value] = index.numbers[value] or {}
  --index.numbers[value][slotkey] = nil
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

--- Match will return a list of slot keys that match the given term.
---@private
---@param term string
---@return table<string, boolean>
function search:Match(term)
  ---@type string, string
  local prefix, value = strsplit(":", term, 2)

  -- If no prefix is provided, assume the filter is a default filter.
  if value == nil then
    ---@type table<string, boolean>
    local slots = {}
    for _, property in ipairs(self.defaultIndicies) do
      local index = self:GetIndex(property)
      if index then
        for slotkey in pairs(self:isInIndex(index, term)) do
          slots[slotkey] = true
        end
      end
    end
    return slots
  end

  local index = self:GetIndex(prefix)
  if index then
    return self:isInIndex(index, value)
  end
  return {}
end

---@param query string
---@param item ItemData
---@return boolean
function search:Find(query, item)
  local terms = self:ParseQuery(query)
  for _, term in ipairs(terms) do
    local slots = self:Match(term)
    if slots[item.slotkey] then
      return true
    end
  end
  return false
end

---@param query string
---@return string[]
function search:Search(query)
  local slots = {}
  local terms = self:ParseQuery(query)
  for _, term in ipairs(terms) do
    for slotkey in pairs(self:Match(term)) do
      table.insert(slots, slotkey)
    end
  end
  return slots
end
