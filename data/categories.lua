local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class SearchCategory
---@field query string The search query for the category.

---@class (exact) CustomCategoryFilter
---@field name string The name of this category as it appears for the user.
---@field itemList? table<number, boolean> The list of item IDs in this category.
---@field permanentItemList? table<number, boolean> The list of item IDs in this category.
---@field enabled? table<BagKind, boolean> The enabled state of the category for each bag.
---@field readOnly? boolean Currently unused.
---@field save? boolean If true, this category is saved to disk.
---@field searchCategory? SearchCategory If defined, this category is a search category.
---@field note? string A note about the category.
---@field color? number[] The RGB color of the category name.
---@field priority? number The priority of the category. A higher number has a higher priority.
---@field dynamic? boolean If true, this category is dynamic and added to the database at runtime.
---@field shown? boolean If true, this category is shown in the UI.

---@class (exact) Categories: AceModule
---@field private itemsWithNoCategory table<number, boolean>
---@field private categoryFunctions table<string, fun(data: ItemData): string>
---@field private categoryCount number
---@field private categories table<string, CustomCategoryFilter>
---@field private itemIDToCategory table<number, CustomCategoryFilter>
local categories = addon:NewModule('Categories')

function categories:OnInitialize()
  self.categories = {}
  self.itemIDToCategory = {}
  self.categoryFunctions = {}
  self.itemsWithNoCategory = {}
  self.categoryCount = 0
end

function categories:OnEnable()
  for name, filter in pairs(database:GetAllItemCategories()) do
    self.categoryCount = self.categoryCount + 1
    self.categories[name] = CopyTable(filter, false)
  end
end

---@param name string
---@return CustomCategoryFilter
function categories:NewBlankCategory(name)
  ---@type CustomCategoryFilter
  local category = {
    name = name,
    itemList = {},
    permanentItemList = {},
    enabled = {
      [const.BAG_KIND.BACKPACK] = true,
      [const.BAG_KIND.BANK] = true,
    },
    readOnly = false,
    save = true,
    searchCategory = nil,
    note = nil,
    color = nil,
    priority = 0,
    dynamic = false,
    shown = true,
  }
  return category
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
  return self.categories
end

-- GetMergedCategory returns a custom category by its name, merging ephemeral and persistent categories.
---@param name string
---@return CustomCategoryFilter?
function categories:GetMergedCategory(name)
  return self.categories[name]
end

-- SaveCategoryToDisk saves a custom category to disk.
---@param ctx Context
---@param name string
function categories:SaveCategoryToDisk(ctx, name)
  _ = ctx
  local category = self.categories[name]
  if category and category.save then
    database:CreateOrUpdateCategory(category)
  end
end

---@param ctx Context
---@param id number The ItemID of the item to add to the category.
---@param name string The name of the custom category to add the item to.
function categories:AddPermanentItemToCategory(ctx, id, name)
  -- HACKFIX: This is a backwards compatibility shim for the old way of adding items to categories.
  -- To be removed eventually.
  if type(ctx) == "number" then
    name = id --[[@as string]]
    id = ctx
    ctx = context:New('AddPermanentItemToCategory')
  end
  assert(id, format("Attempted to add item to category %s, but the item ID is nil.", name))
  assert(name ~= nil, format("Attempted to add item %d to a nil category.", id))
  assert(C_Item.GetItemInfoInstant(id), format("Attempted to add item %d to category %s, but the item does not exist.", id, name))
  self.categories[name].permanentItemList[id] = true
  self.categories[name].save = true
  self:SaveCategoryToDisk(ctx, name)
end

-- AddItemToCategory adds an item to a custom category.
---@param ctx Context
---@param id number The ItemID of the item to add to the category.
---@param name string The name of the custom category to add the item to.
function categories:AddItemToCategory(ctx, id, name)
  -- HACKFIX: This is a backwards compatibility shim for the old way of adding items to categories.
  -- To be removed eventually.
  if type(ctx) == "number" then
    name = id --[[@as string]]
    id = ctx
    ctx = context:New('AddItemToCategory')
  end
  assert(id, format("Attempted to add item to category %s, but the item ID is nil.", name))
  assert(name ~= nil, format("Attempted to add item %d to a nil category.", id))
  assert(C_Item.GetItemInfoInstant(id), format("Attempted to add item %d to category %s, but the item does not exist.", id, name))
  self.categories[name].itemList[id] = true
  self:SaveCategoryToDisk(ctx, name)
end

-- WipeCategory removes all items from a custom category, but does not delete the category.
---@param ctx Context
---@param name string The name of the custom category to wipe.
function categories:WipeCategory(ctx, name)
  -- HACKFIX: This is a backwards compatibility shim for the old way of adding items to categories.
  -- To be removed eventually.
  if type(ctx) == "string" then
    name = ctx
    ctx = context:New('WipeCategory')
  end
  self.categories[name] = self:NewBlankCategory(name)
  self:SaveCategoryToDisk(ctx, name)
  events:SendMessage(ctx, 'categories/Changed')
end

-- IsCategoryEnabled returns whether or not a custom category is enabled.
---@param kind BagKind
---@param name string The name of the custom category to check.
---@return boolean
function categories:IsCategoryEnabled(kind, name)
  if self.categories[name] then
    return self.categories[name].enabled[kind]
  end
  return false
end

-- ToggleCategory toggles the enabled state of a custom category.
---@param ctx Context
---@param kind BagKind
---@param name string The name of the custom category to toggle.
function categories:ToggleCategory(ctx, kind, name)
  if self.categories[name] then
    self.categories[name].enabled[kind] = not self.categories[name].enabled[kind]
    self:SaveCategoryToDisk(ctx, name)
  end
end

-- EnableCategory enables a custom category.
---@param ctx Context
---@param kind BagKind
---@param name string The name of the custom category to toggle.
function categories:EnableCategory(ctx, kind, name)
  if self.categories[name] then
    self.categories[name].enabled[kind] = true
    self:SaveCategoryToDisk(ctx, name)
  end
end

---@param ctx Context
---@param kind BagKind
---@param category string The name of the custom category to toggle.
function categories:DisableCategory(ctx, kind, category)
  if self.categories[category] then
    self.categories[category].enabled[kind] = false
    self:SaveCategoryToDisk(ctx, category)
  end
end

-- SetCategoryState sets the enabled state of a custom category.
---@param ctx Context
---@param kind BagKind
---@param name string The name of the custom category to toggle.
---@param enabled boolean
function categories:SetCategoryState(ctx, kind, name, enabled)
  if self.categories[name] then
    self.categories[name].enabled[kind] = enabled
    self:SaveCategoryToDisk(ctx, name)
  end
end

-- DoesCategoryExist returns true if a custom category exists.
---@param name string
---@return boolean
function categories:DoesCategoryExist(name)
  return self.categories[name] ~= nil
end


---@param ctx Context
---@param category CustomCategoryFilter
function categories:CreateCategory(ctx, category)
  -- HACKFIX: This is a backwards compatibility shim for the old way of adding items to categories.
  -- To be removed eventually.
  if type(ctx) == "table" and not ctx.Event then
    category = ctx --[[@as CustomCategoryFilter]]
    ctx = context:New('CreateCategory')
  end

  if self.categories[category.name] then
    return
  end

  category.enabled = category.enabled or {
    [const.BAG_KIND.BACKPACK] = true,
    [const.BAG_KIND.BANK] = true,
  }

  self.categories[category.name] = category
  self:SaveCategoryToDisk(ctx, category.name)
  events:SendMessage(ctx, 'categories/Changed')
end

---@param name string
---@return CustomCategoryFilter
function categories:GetCategoryByName(name)
  return self.categories[name]
end

---@return table<string, CustomCategoryFilter>
function categories:GetAllCategoriesWithSearch()
  ---@type table<string, CustomCategoryFilter>
  local results = {}
  for name, category in pairs(self.categories) do
    if category.searchCategory then
      results[name] = category
    end
  end
  return results
end

-- Returns a reverse sorted list of search categories, by priority.
---@return CustomCategoryFilter[]
function categories:GetSortedSearchCategories()
  ---@type CustomCategoryFilter[]
  local results = {}
  for _, searchCategory in pairs(self:GetAllCategoriesWithSearch()) do
    table.insert(results, searchCategory)
  end
  table.sort(results, function(a, b)
    return a.priority > b.priority
  end)
  return results
end

---@param ctx Context
---@param name string
function categories:DeleteCategory(ctx, name)
  -- HACKFIX: This is a backwards compatibility shim for the old way of adding items to categories.
  -- To be removed eventually.
  if type(ctx) == "string" then
    name = ctx
    ctx = context:New('DeleteCategory')
  end

  self.categories[name] = nil
  database:DeleteItemCategory(name)

  events:SendMessage(ctx, 'categories/Changed')
  events:SendMessage(ctx, 'bags/FullRefreshAll')
end

---@param ctx Context
---@param name string
function categories:HideCategory(ctx, name)
  -- HACKFIX: This is a backwards compatibility shim for the old way of adding items to categories.
  -- To be removed eventually.
  if type(ctx) == "string" then
    name = ctx
    ctx = context:New('HideCategory')
  end

  self.categories[name].shown = false
  self:SaveCategoryToDisk(ctx, name)
  events:SendMessage(ctx, 'bags/FullRefreshAll')
end

---@param ctx Context
---@param category string
function categories:ShowCategory(ctx, category)
  -- HACKFIX: This is a backwards compatibility shim for the old way of adding items to categories.
  -- To be removed eventually.
  if type(ctx) == "string" then
    category = ctx
    ctx = context:New('ShowCategory')
  end
  self.categories[category].shown = true
  self:SaveCategoryToDisk(ctx, category)
  events:SendMessage(ctx, 'bags/FullRefreshAll')
end

---@param category string
---@return boolean
function categories:IsCategoryShown(category)
  if self.categories[category] then
    return self.categories[category].shown
  end
  return false
end

---@param ctx Context
---@param name string
function categories:ToggleCategoryShown(ctx, name)
  -- HACKFIX: This is a backwards compatibility shim for the old way of adding items to categories.
  -- To be removed eventually.
  if type(ctx) == "string" then
    name = ctx
    ctx = context:New('ToggleCategoryShown')
  end
  self.categories[name].shown = not self.categories[name].shown
  self:SaveCategoryToDisk(ctx, name)
  events:SendMessage(ctx, 'bags/FullRefreshAll')
end

-- GetCustomCategory returns the custom category for an item, or nil if it doesn't have one.
-- This will JIT call all registered functions the first time an item is seen, returning
-- the custom category if one is found. If no custom category is found, nil is returned.
---@param ctx Context
---@param kind BagKind
---@param data ItemData The item data to get the custom category for.
---@return string|nil
function categories:GetCustomCategory(ctx, kind, data)
  -- HACKFIX: This is a backwards compatibility shim for the old way of adding items to categories.
  -- To be removed eventually.
  if type(ctx) == "number" then
    data = kind --[[@as ItemData]]
    kind = ctx
    ctx = context:New('GetCustomCategory')
  end
  local itemID = data.itemInfo.itemID
  if not itemID then return nil end
  local filter = self.itemIDToCategory[itemID]
  if filter and filter.enabled[kind] then
    return filter.name
  end

  -- Check for items that had no category previously. This
  -- is a performance optimization to avoid calling all
  -- registered functions for every item.
  if self.itemsWithNoCategory[itemID] then return nil end

  for _, func in pairs(self.categoryFunctions) do
    local success, args = xpcall(func, geterrorhandler(), data)
    if success and args ~= nil then
      local name = select(1, args) --[[@as string]]
      local found = self.categories[name] and true or false
      self:AddItemToCategory(ctx, itemID, name)
      if not found then
        self.categoryCount = self.categoryCount + 1
        events:SendMessage(ctx, 'categories/Changed')
      end
      if self:IsCategoryEnabled(kind, name) then
        return name
      end
    end
  end
  self.itemsWithNoCategory[itemID] = true
  return nil
end

---@param ctx Context
---@param id number The ItemID of the item to remove from a custom category.
function categories:RemoveItemFromCategory(ctx, id)
  local category = self.itemIDToCategory[id]
  if not category then return end
  category.itemList[id] = nil
  category.permanentItemList[id] = nil
  self:SaveCategoryToDisk(ctx, category.name)
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
---@param ctx Context
function categories:ReprocessAllItems(ctx)
  wipe(self.itemsWithNoCategory)
  events:SendMessage(ctx, 'bags/FullRefreshAll')
end
