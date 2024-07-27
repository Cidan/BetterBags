local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SearchIndex
---@field property string
---@field slots table<string, boolean>

---@class Search: AceModule
---@field private indicies table<string, table<any, SearchIndex>>
local search = addon:NewModule('Search')

function search:OnInitialize()
    self.indicies = {
      name = {},
      itemLevel = {},
      rarity = {},
      type = {},
      subtype = {},
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

---@param property string
---@param value any
---@return SearchIndex
function search:GetIndex(property, value)
  self.indicies[property][value] = self.indicies[property][value] or { property = property, slots = {} }
  return self.indicies[property][value]
end

---@param item ItemData
function search:Add(item)
  local index = self:GetIndex('name', item.itemInfo.itemName)
  index.slots[item.slotkey] = true
end

---@param query string
function search:Search(query)
  local terms = self:ParseQuery(query)
end