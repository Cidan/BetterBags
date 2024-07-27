local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SearchIndex
---@field property string
---@field ngrams table<string, table<string, boolean>>

---@class Search: AceModule
---@field private indicies table<string, SearchIndex>
---@field private defaultIndicies string[]
local search = addon:NewModule('Search')

function search:OnInitialize()
  self.indicies = {
    name = {property = 'name', ngrams = {}},
    itemLevel = {property = 'itemLevel', ngrams = {}},
    rarity = {property = 'rarity', ngrams = {}},
    type = {property = 'type', ngrams = {}},
    subtype = {property = 'subtype', ngrams = {}},
    category = {property = 'category', ngrams = {}},
  }

  self.defaultIndicies = {
    'name',
    'type',
    'category',
    'subtype'
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
end

---@param item ItemData
function search:Remove(item)
  search:removeStringFromIndex(self.indicies.name, item.itemInfo.itemName, item.slotkey)
  search:removeStringFromIndex(self.indicies.type, item.itemInfo.itemType, item.slotkey)
  search:removeStringFromIndex(self.indicies.subtype, item.itemInfo.itemSubType, item.slotkey)
end


---@param property string
---@return SearchIndex?
function search:GetIndex(property)
  if not self.indicies[property] then return end
  return self.indicies[property]
end

---@param index SearchIndex
---@param value string
---@return table<string, boolean>
function search:isStringInIndex(index, value)
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
    for _, property in ipairs(self.defaultIndicies) do
      local index = self:GetIndex(property)
      if index then
        return self:isStringInIndex(index, term)
      end
    end
    return {}
  end

  local index = self:GetIndex(prefix)
  if index then
    return self:isStringInIndex(index, value)
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
