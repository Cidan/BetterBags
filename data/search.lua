local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SearchIndex
---@field property string
---@field ngrams table<string, table<string, boolean>>

---@class Search: AceModule
---@field private indicies table<string, SearchIndex>
local search = addon:NewModule('Search')

function search:OnInitialize()
    self.indicies = {
      name = {property = 'name', ngrams = {}},
      itemLevel = {property = 'itemLevel', ngrams = {}},
      rarity = {property = 'rarity', ngrams = {}},
      type = {property = 'type', ngrams = {}},
      subtype = {property = 'subtype', ngrams = {}},
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

-----@param property string
-----@param value any
-----@return SearchIndex
--function search:CreateIndex(property, value)
--  self.indicies[property][value] = self.indicies[property][value] or { property = property, slots = {} }
--  return self.indicies[property][value]
--end

---@private
---@param index SearchIndex
---@param value string
---@param slotkey string
function search:addStringToIndex(index, value, slotkey)
  local prefix = ""
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
  for i = 1, #value do
    prefix = prefix .. value:sub(i, i)
    index.ngrams[prefix] = index.ngrams[prefix] or {}
    index.ngrams[prefix][slotkey] = nil
  end
end

---@param item ItemData
function search:Add(item)
  search:addStringToIndex(self.indicies.name, item.itemInfo.itemName, item.slotkey)
end

---@param item ItemData
function search:Remove(item)
  search:removeStringFromIndex(self.indicies.name, item.itemInfo.itemName, item.slotkey)
end

--[[
---@param property string
---@param value any
---@return SearchIndex?
function search:GetIndex(property, value)
  if not self.indicies[property] then return end
  return self.indicies[property][value]
end

---@param property string
---@param value any
---@return SearchIndex?
function search:MatchIndex(property, value)
  if not self.indicies[property] then return end
  local index = self.indicies[property][value]
  if not index then return end
  if string.find(index.)
end
]]--

--[[
--- Match will return a list of slot keys that match the given term.
---@param term string
---@return string[]
function search:Match(term)
    ---@type string, string
    local prefix, value = strsplit(":", term, 2)
    -- If no prefix is provided, assume the filter is a name or type filter.
    if value == nil then
    end
    local index = self:GetIndex(prefix, value)
    if prefix == "name" then

    end
end

---@param query string
function search:Search(query)
  local terms = self:ParseQuery(query)
end
--]]