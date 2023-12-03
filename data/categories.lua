local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Categories: AceModule
---@field private itemToCategory table<number, string>
---@field private functionCategories table<number, string>
---@field private itemsWithNoCategory table<number, boolean>
---@field private categoryFunctions table<string, fun(mixin: ItemMixin): string>
local categories = addon:NewModule('Categories')

function categories:OnInitialize()
  self.itemToCategory = {}
  self.functionCategories = {}
  self.categoryFunctions = {}
  self.itemsWithNoCategory = {}
end

-- AddItemToCategory adds an item to a custom category by its ItemID.
---@param id number The ItemID of the item to add to a custom category.
---@param category string The name of the custom category to add the item to.
function categories:AddItemToCategory(id, category)
  self.itemToCategory[id] = category
end

-- GetCustomCategory returns the custom category for an item, or nil if it doesn't have one.
-- This will JIT call all registered functions the first time an item is seen, returning
-- the custom category if one is found. If no custom category is found, nil is returned.
---@param mixin ItemMixin The item mixin to get the custom category for.
---@return string|nil
function categories:GetCustomCategory(mixin)
  local itemID = mixin:GetItemID()
  if not itemID then return nil end

  -- Check for categories manually set by item.
  local category = self.itemToCategory[itemID]
  if category then return category end

  -- Check for categories set by registered functions.
  category = self.functionCategories[itemID]
  if category then return category end

  -- Check for items that had no category previously. This
  -- is a performance optimization to avoid calling all
  -- registered functions for every item.
  if self.itemsWithNoCategory[itemID] then return nil end

  for _, func in pairs(self.categoryFunctions) do
    category = func(mixin)
    if category then
      self.functionCategories[itemID] = category
      return category
    end
  end
  self.itemsWithNoCategory[itemID] = true
  return nil
end

---@param id number The ItemID of the item to remove from a custom category.
function categories:RemoveItemFromCategory(id)
  self.itemToCategory[id] = nil
end

-- RegisterCategoryFunction registers a function that will be called to get the category name for all items.
-- Registered functions are only called once per item, and the result is cached. Registering a new
-- function will clear the cache and caused all items to be processed once. Do not abuse this API,
-- as it has the potential to cause a significant amount of CPU usage the first time an item is rendered,
-- which at game load time, is every item.
---@param id string A unique identifier for the category function. This is not used for the category name!
---@param func fun(mixin: ItemMixin): string The function to call to get the category name for an item.
function categories:RegisterCategoryFunction(id, func)
  assert(not self.categoryFunctions[id], 'category function already registered: '.. id)
  self.categoryFunctions[id] = func
  wipe(self.itemsWithNoCategory)
  wipe(self.functionCategories)
end

-- ReprocessAllItems will wipe the category cache and cause all items to be fully reprocessed, recategoried,
-- and rerendered. This is a very expensive operation to call and should only be called once all,
-- category functions have been registered or if some configuration changes and all items should be
-- reprocessed and re-categorized.
function categories:ReprocessAllItems()
  wipe(self.itemsWithNoCategory)
  wipe(self.functionCategories)
  items:RefreshAll()
end

categories:Enable()