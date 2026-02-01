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
---@field groupBy? number The groupBy type (0=None, 1=Type, 2=Subtype, 3=Expansion). Default is 0 (None).

---@class (exact) CustomCategoryFilter
---@field name string The name of this category as it appears for the user.
---@field itemList table<number, boolean> The list of item IDs in this category.
---@field enabled? table<BagKind, boolean> The enabled state of the category for each bag.
---@field readOnly? boolean Currently unused.
---@field save? boolean If true, this category is saved to disk.
---@field searchCategory? SearchCategory If defined, this category is a search category.
---@field note? string A note about the category.
---@field color? number[] The RGB color of the category name.
---@field priority? number The priority of the category. A higher number has a higher priority.
---@field dynamic? boolean If true, this category is dynamic and added to the database at runtime.

---@class (exact) Categories: AceModule
---@field private itemsWithNoCategory table<number, boolean>
---@field private categoryFunctions table<string, fun(data: ItemData): string>
---@field private categoryCount number
---@field private ephemeralCategories table<string, CustomCategoryFilter>
---@field private ephemeralCategoryByItemID table<number, CustomCategoryFilter>
local categories = addon:NewModule('Categories')

function categories:OnInitialize()
  self.categoryFunctions = {}
  self.itemsWithNoCategory = {}
  self.ephemeralCategories = {}
  self.ephemeralCategoryByItemID = {}
  self.categoryCount = 0
end

function categories:OnEnable()
  for _ in pairs(database:GetAllItemCategories()) do
    self.categoryCount = self.categoryCount + 1
  end
  for _, category in pairs(database:GetAllEphemeralItemCategories()) do
    if category.dynamic then
      self.ephemeralCategories[category.name] = category
    end
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
  ---@type table<string, CustomCategoryFilter>
  local catList = {}
  for name, filter in pairs(database:GetAllItemCategories()) do
    catList[name] = filter
  end
  for name, filter in pairs(self.ephemeralCategories) do
    if catList[name] == nil then
      catList[name] = filter
    end
  end
  return catList
end

-- GetMergedCategory returns a custom category by its name, merging ephemeral and persistent categories.
---@param name string
---@return CustomCategoryFilter?
function categories:GetMergedCategory(name)
  ---@type CustomCategoryFilter
  local results = {
    name = name,
    itemList = {},
  }

  local filter = database:GetItemCategory(name)

  if filter then
    for id, _ in pairs(filter.itemList) do
      results.itemList[id] = true
    end
  end

  if self.ephemeralCategories[name] then
    for id, _ in pairs(self.ephemeralCategories[name].itemList) do
      results.itemList[id] = true
    end
  end

  return results
end

---@param ctx Context
---@param id number The ItemID of the item to add to the category.
---@param category string The name of the custom category to add the item to.
function categories:AddPermanentItemToCategory(ctx, id, category)
  -- HACKFIX: This is a backwards compatibility shim for the old way of adding items to categories.
  -- To be removed eventually.
  if type(ctx) == "number" then
    category = id --[[@as string]]
    id = ctx
    ctx = context:New('AddPermanentItemToCategory')
  end
  assert(id, format("Attempted to add item to category %s, but the item ID is nil.", category))
  assert(category ~= nil, format("Attempted to add item %d to a nil category.", id))
  assert(C_Item.GetItemInfoInstant(id), format("Attempted to add item %d to category %s, but the item does not exist.", id, category))

  if not database:ItemCategoryExists(category) then
    self:CreateCategory(ctx, {
      name = category,
      itemList = {},
      save = true,
    })
  end

  if not self.ephemeralCategories[category] then
    self.ephemeralCategories[category] = {
      name = category,
      itemList = {},
    }
  end
  database:SaveItemToCategory(id, category)
end

-- AddItemToCategory adds an item to a custom category.
---@param ctx Context
---@param id number The ItemID of the item to add to the category.
---@param category string The name of the custom category to add the item to.
function categories:AddItemToCategory(ctx, id, category)
  -- HACKFIX: This is a backwards compatibility shim for the old way of adding items to categories.
  -- To be removed eventually.
  if type(ctx) == "number" then
    category = id --[[@as string]]
    id = ctx
    ctx = context:New('AddItemToCategory')
  end
  assert(id, format("Attempted to add item to category %s, but the item ID is nil.", category))
  assert(category ~= nil, format("Attempted to add item %d to a nil category.", id))
  assert(C_Item.GetItemInfoInstant(id), format("Attempted to add item %d to category %s, but the item does not exist.", id, category))

  -- Backwards compatability for the old way of adding items to categories.
  if not self.ephemeralCategories[category] then
    self:CreateCategory(ctx, {
      name = category,
      itemList = {},
    })
  end

  if self.ephemeralCategories[category] then
    if self.ephemeralCategories[category].searchCategory then
      return
    end
    self.ephemeralCategories[category].itemList[id] = true
    self.ephemeralCategoryByItemID[id] = self.ephemeralCategories[category]
    return
  end

  assert(database:ItemCategoryExists(category), format("Attempted to add item %d to category %s, but the category does not exist.", id, category))
  if database:GetItemCategory(category).searchCategory then
    return
  end
  database:SaveItemToCategory(id, category)
end

-- WipeCategory removes all items from a custom category, but does not delete the category.
---@param ctx Context
---@param category string The name of the custom category to wipe.
function categories:WipeCategory(ctx, category)
  -- HACKFIX: This is a backwards compatibility shim for the old way of adding items to categories.
  -- To be removed eventually.
  if type(ctx) == "string" then
    category = ctx
    ctx = context:New('WipeCategory')
  end
  database:WipeItemCategory(category)
  if self.ephemeralCategories[category] then
    for id, _ in pairs(self.ephemeralCategories[category].itemList) do
      self.ephemeralCategoryByItemID[id] = nil
    end
    wipe(self.ephemeralCategories[category].itemList)
  end
  events:SendMessage(ctx, 'categories/Changed')
end

-- IsCategoryEnabled returns whether or not a custom category is enabled.
---@param kind BagKind
---@param category string The name of the custom category to check.
---@return boolean
function categories:IsCategoryEnabled(kind, category)
  if self.ephemeralCategories[category] then
    return database:GetEphemeralItemCategory(category).enabled[kind]
  end
  if database:GetItemCategory(category) then
    if database:GetItemCategory(category).itemList then
      return database:GetItemCategory(category).enabled[kind]
    end
  end
  return false
end

-- ToggleCategory toggles the enabled state of a custom category.
---@param kind BagKind
---@param category string The name of the custom category to toggle.
function categories:ToggleCategory(kind, category)
  ---@type boolean
  local enabled
  if self.ephemeralCategories[category] then
    enabled = not self.ephemeralCategories[category].enabled[kind]
    self.ephemeralCategories[category].enabled[kind] = enabled
    database:SetEphemeralItemCategoryEnabled(kind, category, enabled)
    return
  end
  local filter = database:GetItemCategory(category)
  if filter then
    database:SetItemCategoryEnabled(kind, category, enabled)
  end
end

---@param kind BagKind
---@param category string The name of the custom category to toggle.
function categories:EnableCategory(kind, category)
  if self.ephemeralCategories[category] then
    self.ephemeralCategories[category].enabled[kind] = true
    database:SetEphemeralItemCategoryEnabled(kind, category, true)
    return
  end
  local filter = database:GetItemCategory(category)
  if filter then
    database:SetItemCategoryEnabled(kind, category, true)
  end
end

---@param kind BagKind
---@param category string The name of the custom category to toggle.
function categories:DisableCategory(kind, category)
  if self.ephemeralCategories[category] then
    self.ephemeralCategories[category].enabled[kind] = false
    database:SetEphemeralItemCategoryEnabled(kind, category, false)
    return
  end
  local filter = database:GetItemCategory(category)
  if filter then
    database:SetItemCategoryEnabled(kind, category, false)
  end
end

-- DoesCategoryExist returns true if a custom category exists.
---@param category string
---@return boolean
function categories:DoesCategoryExist(category)
  if self.ephemeralCategories[category] == nil and not database:ItemCategoryExists(category) then
    return false
  end
  return true
end

---@param kind BagKind
---@param category string The name of the custom category to toggle.
---@param enabled boolean
function categories:SetCategoryState(kind, category, enabled)
  if self.ephemeralCategories[category] then
    self.ephemeralCategories[category].enabled[kind] = enabled
    database:SetEphemeralItemCategoryEnabled(kind, category, enabled)
  end
  if database:GetItemCategory(category).itemList then
    database:SetItemCategoryEnabled(kind, category, enabled)
  end
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
  category.enabled = category.enabled or {
    [const.BAG_KIND.BACKPACK] = true,
    [const.BAG_KIND.BANK] = true,
  }

  if category.save then
    database:CreateOrUpdateCategory(category)
  elseif self.ephemeralCategories[category.name] == nil then
    local savedState = database:GetEphemeralItemCategory(category.name)
    if savedState and savedState.enabled then
      category.enabled = savedState.enabled
      category.dynamic = savedState.dynamic
    end
    self.ephemeralCategories[category.name] = category
    for id in pairs(category.itemList) do
      self.ephemeralCategoryByItemID[id] = category
    end
    database:CreateOrUpdateCategory(category)
  end
  events:SendMessage(ctx, 'categories/Changed')
end

---@param name string
---@return CustomCategoryFilter
function categories:GetCategoryByName(name)
  return database:GetItemCategory(name) or self.ephemeralCategories[name]
end

---@return table<string, CustomCategoryFilter>
function categories:GetAllSearchCategories()
  ---@type table<string, CustomCategoryFilter>
  local results = {}
  local savedCategories = database:GetAllItemCategories()
  for name, searchCategory in pairs(savedCategories) do
    if searchCategory.searchCategory then
      results[name] = searchCategory
    end
  end
  for name, searchCategory in pairs(self.ephemeralCategories) do
    if searchCategory.searchCategory then
      results[name] = searchCategory
    end
  end
  return results
end

-- Returns a reverse sorted list of search categories, by priority.
---@return CustomCategoryFilter[]
function categories:GetSortedSearchCategories()
  ---@type CustomCategoryFilter[]
  local results = {}
  local savedCategories = categories:GetAllSearchCategories()
  for _, searchCategory in pairs(savedCategories) do
    table.insert(results, searchCategory)
  end
  table.sort(results, function(a, b)
    return a.priority > b.priority
  end)
  return results
end

---@param ctx Context
---@param category string
function categories:DeleteCategory(ctx, category)
  -- HACKFIX: This is a backwards compatibility shim for the old way of adding items to categories.
  -- To be removed eventually.
  if type(ctx) == "string" then
    category = ctx
    ctx = context:New('DeleteCategory')
  end

  if self.ephemeralCategories[category] then
    for id, _ in pairs(self.ephemeralCategories[category].itemList) do
      self.ephemeralCategoryByItemID[id] = nil
    end
    self.ephemeralCategories[category] = nil
  end

  database:DeleteItemCategory(category)
  events:SendMessage(ctx, 'categories/Changed')
  events:SendMessage(ctx, 'bags/FullRefreshAll')
end

---@param ctx Context
---@param category string
function categories:HideCategory(ctx, category)
  -- HACKFIX: This is a backwards compatibility shim for the old way of adding items to categories.
  -- To be removed eventually.
  if type(ctx) == "string" then
    category = ctx
    ctx = context:New('HideCategory')
  end
  database:GetCategoryOptions(category).shown = false
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
  database:GetCategoryOptions(category).shown = true
  events:SendMessage(ctx, 'bags/FullRefreshAll')
end

---@param category string
---@return boolean
function categories:IsCategoryShown(category)
  return database:GetCategoryOptions(category).shown
end

---@param category string
---@return boolean
function categories:IsDynamicCategory(category)
  return self.ephemeralCategories[category] and self.ephemeralCategories[category].dynamic or false
end

---@param ctx Context
---@param category string
function categories:ToggleCategoryShown(ctx, category)
  -- HACKFIX: This is a backwards compatibility shim for the old way of adding items to categories.
  -- To be removed eventually.
  if type(ctx) == "string" then
    category = ctx
    ctx = context:New('ToggleCategoryShown')
  end
  local options = database:GetCategoryOptions(category)
  options.shown = not options.shown
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
  local filter = database:GetItemCategoryByItemID(itemID)
  if filter.enabled and filter.enabled[kind] then
    return filter.name
  end

  filter = self.ephemeralCategoryByItemID[itemID]

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
      local category = select(1, args) --[[@as string]]
      local found = self.ephemeralCategories[category] and true or false
      self:AddItemToCategory(ctx, itemID, category)
      if not found then
        self.categoryCount = self.categoryCount + 1
        events:SendMessage(ctx, 'categories/Changed')
      end
      if self:IsCategoryEnabled(kind, category) then
        return category
      end
    end
  end
  self.itemsWithNoCategory[itemID] = true
  return nil
end

---@param id number The ItemID of the item to remove from a custom category.
function categories:RemoveItemFromCategory(id)
  local filter = self.ephemeralCategoryByItemID[id]
  if filter then
    filter.itemList[id] = nil
    self.ephemeralCategoryByItemID[id] = nil
  end
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
---@param ctx Context
function categories:ReprocessAllItems(ctx)
  wipe(self.itemsWithNoCategory)
  events:SendMessage(ctx, 'bags/FullRefreshAll')
end
