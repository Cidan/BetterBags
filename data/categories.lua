local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class (exact) Categories: AceModule
---@field private itemsWithNoCategory table<number, boolean>
---@field private categoryFunctions table<string, fun(data: ItemData): string>
---@field private categoryCount number
local categories = addon:NewModule('Categories')

function categories:OnInitialize()
  self.categoryFunctions = {}
  self.itemsWithNoCategory = {}
  self.categoryCount = 0
end

function categories:OnEnable()
  for _ in pairs(database:GetAllItemCategories()) do
    self.categoryCount = self.categoryCount + 1
  end
end

---@return number
function categories:GetCategoryCount()
  local count = 0
  for _ in pairs(database:GetAllItemCategories()) do
    count = count + 1
  end
  return count
end

-- GetAllCategories returns a list of all custom categories.
---@return table<string, CustomCategoryFilter>
function categories:GetAllCategories()
  return database:GetAllItemCategories()
end

-- AddItemToCategory adds an item to a custom category by its ItemID.
---@param id number The ItemID of the item to add to a custom category.
---@param category string The name of the custom category to add the item to.
function categories:AddItemToCategory(id, category)
  assert(id, format("Attempted to add item to category %s, but the item ID is nil.", category))
  assert(category ~= nil, format("Attempted to add item %d to a nil category.", id))
  assert(GetItemInfoInstant(id), format("Attempted to add item %d to category %s, but the item does not exist.", id, category))
  local found = database:ItemCategoryExists(category)
  database:SaveItemToCategory(id, category)
  if not found then
    self.categoryCount = self.categoryCount + 1
    events:SendMessage('categories/Changed')
  end
end

-- WipeCategory removes all items from a custom category, but does not delete the category.
---@param category string The name of the custom category to wipe.
function categories:WipeCategory(category)
  database:WipeItemCategory(category)
  events:SendMessage('categories/Changed')
end

-- IsCategoryEnabled returns whether or not a custom category is enabled.
---@param kind BagKind
---@param category string The name of the custom category to check.
---@return boolean
function categories:IsCategoryEnabled(kind, category)
  return database:GetItemCategory(category).enabled[kind]
end

-- ToggleCategory toggles the enabled state of a custom category.
---@param kind BagKind
---@param category string The name of the custom category to toggle.
function categories:ToggleCategory(kind, category)
  local enabled = not database:GetItemCategory(category).enabled[kind]
  database:SetItemCategoryEnabled(kind, category, enabled)
end

---@param kind BagKind
---@param category string The name of the custom category to toggle.
function categories:EnableCategory(kind, category)
  database:SetItemCategoryEnabled(kind, category, true)
end

---@param kind BagKind
---@param category string The name of the custom category to toggle.
function categories:DisableCategory(kind, category)
  database:SetItemCategoryEnabled(kind, category, false)
end

---@param kind BagKind
---@param category string The name of the custom category to toggle.
---@param enabled boolean
function categories:SetCategoryState(kind, category, enabled)
  database:SetItemCategoryEnabled(kind, category, enabled)
end

function categories:CreateCategory(category)
  database:CreateCategory(category)
  events:SendMessage('categories/Changed')
end

function categories:DeleteCategory(category)
  database:DeleteItemCategory(category)
  events:SendMessage('categories/Changed')
  events:SendMessage('bags/FullRefreshAll')
end

-- GetCustomCategory returns the custom category for an item, or nil if it doesn't have one.
-- This will JIT call all registered functions the first time an item is seen, returning
-- the custom category if one is found. If no custom category is found, nil is returned.
---@param kind BagKind
---@param data ItemData The item data to get the custom category for.
---@return string|nil
function categories:GetCustomCategory(kind, data)
  local itemID = data.itemInfo.itemID
  if not itemID then return nil end

  local filter = database:GetItemCategoryByItemID(itemID)
  if filter.enabled and filter.enabled[kind] then
    return filter.name
  end

  -- Check for items that had no category previously. This
  -- is a performance optimization to avoid calling all
  -- registered functions for every item.
  if self.itemsWithNoCategory[itemID] then return nil end

  for _, func in pairs(self.categoryFunctions) do
    local success, args = xpcall(func, geterrorhandler(), data)
    if success and args ~= nil then
      local category = select(1, args) --[[@as string]]
      local found = database:ItemCategoryExists(category)
      database:SaveItemToCategory(itemID, category)
      if not found then
        self.categoryCount = self.categoryCount + 1
        events:SendMessage('categories/Changed')
      end
      if self:IsCategoryEnabled(kind, category) then
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
  database:DeleteItemFromCategory(id, database:GetItemCategoryByItemID(id).name)
end

-- RegisterCategoryFunction registers a function that will be called to get the category name for all items.
-- Registered functions are only called once per item, and the result is cached. Registering a new
-- function will clear the cache. Do not abuse this API,
-- as it has the potential to cause a significant amount of CPU usage the first time an item is rendered,
-- which at game load time, is every item.
---@param id string A unique identifier for the category function. This is not used for the category name!
---@param func fun(data: ItemData): string|nil The function to call to get the category name for an item.
function categories:RegisterCategoryFunction(id, func)
  assert(not self.categoryFunctions[id], 'category function already registered: '.. id)
  self.categoryFunctions[id] = func
  wipe(self.itemsWithNoCategory)
end

-- ReprocessAllItems will wipe the category cache and cause all items to be fully reprocessed, recategoried,
-- and rerendered. This is a very expensive operation to call and should only be called once all,
-- category functions have been registered or if some configuration changes and all items should be
-- reprocessed and re-categorized.
function categories:ReprocessAllItems()
  wipe(self.itemsWithNoCategory)
  events:SendMessage('bags/FullRefreshAll')
end
