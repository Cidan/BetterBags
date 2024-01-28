local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Categories: AceModule
---@field private itemToCategory table<number, string>
---@field private functionCategories table<number, string>
---@field private itemsWithNoCategory table<number, boolean>
---@field private categoryFunctions table<string, fun(data: ItemData): string>
---@field private categoryList table<string, number[]>
---@field private categoryCount number
local categories = addon:NewModule('Categories')

function categories:OnInitialize()
  self.itemToCategory = {}
  self.functionCategories = {}
  self.categoryFunctions = {}
  self.itemsWithNoCategory = {}
  self.categoryList = {}
  self.categoryCount = 0
end

function categories:OnEnable()
  for _ in pairs(database:GetAllItemCategories()) do
    self.categoryCount = self.categoryCount + 1
  end
end

---@return number
function categories:GetCategoryCount()
  return self.categoryCount
end

-- GetAllCategories returns a list of all custom categories.
---@return table<string, number[]>
function categories:GetAllCategories()
  return self.categoryList
end

-- AddItemToCategory adds an item to a custom category by its ItemID.
---@param id number The ItemID of the item to add to a custom category.
---@param category string The name of the custom category to add the item to.
function categories:AddItemToCategory(id, category)
  self.itemToCategory[id] = category
  local found = self.categoryList[category] and true or false
  self.categoryList[category] = self.categoryList[category] or {}
  table.insert(self.categoryList[category], id)
  database:SaveItemToCategory(id, category)
  if not found then
    self.categoryCount = self.categoryCount + 1
    events:SendMessage('categories/Changed')
  end
end

-- WipeCategory removes all items from a custom category, but does not delete the category.
---@param category string The name of the custom category to wipe.
function categories:WipeCategory(category)
  if not self.categoryList[category] then return end
  for _, id in pairs(self.categoryList[category]) do
    self.itemToCategory[id] = nil
  end
  database:WipeItemCategory(category)
  self.categoryList[category] = nil
  events:SendMessage('categories/Changed')
end

-- IsCategoryEnabled returns whether or not a custom category is enabled.
---@param category string The name of the custom category to check.
---@return boolean
function categories:IsCategoryEnabled(category)
  return database:GetItemCategory(category).enabled
end

-- ToggleCategory toggles the enabled state of a custom category.
---@param category string The name of the custom category to toggle.
function categories:ToggleCategory(category)
  local enabled = not database:GetItemCategory(category).enabled
  database:SetItemCategoryEnabled(category, enabled)
end

function categories:EnableCategory(category)
  database:SetItemCategoryEnabled(category, true)
end

function categories:DisableCategory(category)
  database:SetItemCategoryEnabled(category, false)
end

function categories:SetCategoryState(category, enabled)
  database:SetItemCategoryEnabled(category, enabled)
end

-- GetCustomCategory returns the custom category for an item, or nil if it doesn't have one.
-- This will JIT call all registered functions the first time an item is seen, returning
-- the custom category if one is found. If no custom category is found, nil is returned.
---@param data ItemData The item data to get the custom category for.
---@return string|nil
function categories:GetCustomCategory(data)
  local itemID = data.itemInfo.itemID
  if not itemID then return nil end

  local filter = database:GetItemCategoryByItemID(itemID)
  if filter.enabled then
    return filter.name
  end
  -- Check for categories manually set by item.
  local category = self.itemToCategory[itemID]

  -- Check for categories set by registered functions.
  category = self.functionCategories[itemID]
  if category then
    if self:IsCategoryEnabled(category) then
      return category
    else
      return nil
    end
  end

  -- Check for items that had no category previously. This
  -- is a performance optimization to avoid calling all
  -- registered functions for every item.
  if self.itemsWithNoCategory[itemID] then return nil end

  for _, func in pairs(self.categoryFunctions) do
    category = func(data)
    if category then
      self.functionCategories[itemID] = category
      local found = self.categoryList[category] and true or false
      self.categoryList[category] = self.categoryList[category] or {}
      table.insert(self.categoryList[category], itemID)
      if not found then
        self.categoryCount = self.categoryCount + 1
        events:SendMessage('categories/Changed')
      end
      if self:IsCategoryEnabled(category) then
        return category
      else
        return nil
      end
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
-- function will clear the cache. Do not abuse this API,
-- as it has the potential to cause a significant amount of CPU usage the first time an item is rendered,
-- which at game load time, is every item.
-- Categories functions are not saved to the database, and must be registered every time the addon is loaded.
---@param id string A unique identifier for the category function. This is not used for the category name!
---@param func fun(data: ItemData): string|nil The function to call to get the category name for an item.
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
