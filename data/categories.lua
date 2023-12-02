local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Categories: AceModule
---@field private itemToCategory table<number, string>
local categories = addon:NewModule('Categories')

function categories:OnInitialize()
  self.itemToCategory = {}
end

---@param id number The ItemID of the item to add to a custom category.
---@param category string The name of the custom category to add the item to.
function categories:AddItemToCategory(id, category)
  self.itemToCategory[id] = category
end

---@param id number The ItemID of the item to lookup a custom category for.
---@return string
function categories:GetCustomCategory(id)
  return self.itemToCategory[id]
end

---@param id number The ItemID of the item to remove from a custom category.
function categories:RemoveItemFromCategory(id)
  self.itemToCategory[id] = nil
end

categories:Enable()