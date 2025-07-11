

---@type BetterBags
local addon = GetBetterBags()

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Search: AceModule
local search = addon:GetModule('Search')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Localization: AceModule
local L =  addon:GetModule('Localization')

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
---@field allowBlizzardItems? boolean If true, this category will allow Blizzard items to be added to it.
---@field sortOrder? number The sort order of the category. No value means it will be sorted via the section sort option.

---@class (exact) Categories: AceModule
---@field private itemsWithNoCategory table<number, boolean>
---@field private categoryFunctions table<string, fun(data: ItemData): string>
---@field private categoryCount number
---@field private categories table<string, CustomCategoryFilter>
---@field private itemIDToCategories table<number, string[]>
---@field private slotsToCategories table<string, string[]>
local categories = addon:NewModule('Categories')

function categories:OnInitialize()
  self.categories = {}
  self.itemIDToCategories = {}
  self.slotsToCategories = {}
  self.categoryFunctions = {}
  self.itemsWithNoCategory = {}
  self.categoryCount = 0
end

function categories:OnEnable()
  for name, filter in pairs(database:GetAllItemCategories()) do
    self.categoryCount = self.categoryCount + 1
    self.categories[name] = CopyTable(filter, false)
    -- Delete the temporary item list.
    self.categories[name].itemList = {}
    -- In-line migration for allowBlizzardItems.
    if self.categories[name].allowBlizzardItems == nil then
      self.categories[name].allowBlizzardItems = true
    end
    if self.categories[name].sortOrder == nil then
      self.categories[name].sortOrder = -1
    end
    if self.categories[name].shown == nil then
      self.categories[name].shown = true
    end
    if filter.permanentItemList then
      for id in pairs(filter.permanentItemList) do
        if not self.itemIDToCategories[id] then
          self.itemIDToCategories[id] = {}
        end
        table.insert(self.itemIDToCategories[id], name)
      end
    end
    if self.categories[name].priority == nil then
      self.categories[name].priority = 10
    end
    self:SaveCategoryToDisk(context:New('OnEnable'), name)
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
    priority = 10,
    dynamic = false,
    shown = true,
    allowBlizzardItems = true,
    sortOrder = -1,
  }
  return category
end

---@param ctx Context
---@param category CustomCategoryFilter
---@param update? boolean If true, update the existing category.
function categories:CreateCategory(ctx, category, update)
  -- HACKFIX: This is a backwards compatibility shim for the old way of adding items to categories.
  -- To be removed eventually.
  if type(ctx) == "table" and not ctx.Event then
    category = ctx --[[@as CustomCategoryFilter]]
    ctx = context:New('CreateCategory')
  end

  if self.categories[category.name] then
    if update then
      category.sortOrder = self.categories[category.name].sortOrder
    else
      return
    end
  end

  category.enabled = category.enabled or {
    [const.BAG_KIND.BACKPACK] = true,
    [const.BAG_KIND.BANK] = true,
  }

  if category.permanentItemList then
    for id, add in pairs(category.permanentItemList) do
      if not self.itemIDToCategories[id] then
        self.itemIDToCategories[id] = {}
      end
      if add then
        table.insert(self.itemIDToCategories[id], category.name)
      else
        self.itemIDToCategories[id] = nil
        category.permanentItemList[id] = nil
      end
    end
  end
  if category.itemList then
    for id in pairs(category.itemList) do
      if not self.itemIDToCategories[id] then
        self.itemIDToCategories[id] = {}
      end
      table.insert(self.itemIDToCategories[id], category.name)
    end
  end
  category.sortOrder = category.sortOrder or -1
  category.priority = category.priority or 10
  category.shown = category.shown or true
  -- On a fresh install, categories are created on the fly. Without this,
  -- `allowBlizzardItems` is nil, and items are not assigned to their correct
  -- categories.
  if category.allowBlizzardItems == nil then
    category.allowBlizzardItems = true
  end
  self.categories[category.name] = category
  self:SaveCategoryToDisk(ctx, category.name)
  events:SendMessage(ctx, 'categories/Changed')
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

---@return CustomCategoryFilter[]
function categories:GetCategoryBySortThenAlphaOrder()
  ---@type CustomCategoryFilter[]
  local list = {}
  for _, category in pairs(self.categories) do
    table.insert(list, category)
  end
  table.sort(list, function(a, b)
    if a.sortOrder == b.sortOrder then
      return string.lower(a.name) < string.lower(b.name)
    end
    if a.sortOrder > 0 and b.sortOrder > 0 then
      return a.sortOrder < b.sortOrder
    end
    return a.sortOrder > b.sortOrder
  end)
  return list
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

-- SaveCategoryToDisk saves a custom category to disk.
---@param ctx Context
---@param name string
function categories:SaveCategoryToDisk(ctx, name)
  _ = ctx
  local category = self.categories[name]
  if category then
    database:CreateOrUpdateCategory(category)
  end
end

---@param ctx Context
function categories:UpdateSearchCache(ctx)
  _ = ctx
  wipe(self.slotsToCategories)
  for _, filter in pairs(self:GetAllCategoriesWithSearch()) do
    local results = search:Search(filter.searchCategory.query)
    for slotkey, match in pairs(results) do
      if match then
        self.slotsToCategories[slotkey] = self.slotsToCategories[slotkey] or {}
        table.insert(self.slotsToCategories[slotkey], filter.name)
      end
    end
  end
  for slotkey, _ in pairs(self.slotsToCategories) do
    table.sort(self.slotsToCategories[slotkey], function(a, b)
      return self.categories[a].priority < self.categories[b].priority
    end)
  end
end

---@return table<string, string[]>
function categories:GetSearchCache()
  return self.slotsToCategories
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
  self.itemIDToCategories[id] = self.itemIDToCategories[id] or {}
  table.insert(self.itemIDToCategories[id], name)
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
  self.itemIDToCategories[id] = self.itemIDToCategories[id] or {}
  table.insert(self.itemIDToCategories[id], name)
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

---@param ctx Context
---@param data ItemData
function categories:CalculateAndUpdateBlizzardCategory(ctx, data)
  if database:GetCategoryFilter(data.kind, "RecentItems") then
    if data.internalNewItem then
      data.categories.blizzard = {name = L:G('Recent Items'), priority = 10}
      return
    end
  end

  -- Check for equipment sets first, as it doesn't make sense to put them anywhere else.
  if data.itemInfo.equipmentSets and database:GetCategoryFilter(data.kind, "GearSet") then
    data.categories.blizzard = {name = "Gear: " .. data.itemInfo.equipmentSets[1], priority = 10}
    return
  end

  if data.containerInfo.quality == Enum.ItemQuality.Poor then
    data.categories.blizzard = {name = L:G('Junk'), priority = 10}
  end

  local category = ""

  if database:GetCategoryFilter(data.kind, "EquipmentLocation") and
  data.itemInfo.itemEquipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" and
  _G[data.itemInfo.itemEquipLoc] ~= nil and
  _G[data.itemInfo.itemEquipLoc] ~= "" then
    categories:CreateCategory(ctx, {
      name = _G[data.itemInfo.itemEquipLoc],
    })
    local filter = categories:GetCategoryByName(_G[data.itemInfo.itemEquipLoc])
    if filter.allowBlizzardItems and filter.enabled[data.kind] then
      data.categories.blizzard = {name = filter.name, priority = filter.priority}
    end
  end
  -- Add the type filter to the category if enabled, but not to trade goods
  -- when the tradeskill filter is enabled. This makes it so trade goods are
  -- labeled as "Tailoring" and not "Tradeskill - Tailoring", which is redundent.
  if database:GetCategoryFilter(data.kind, "Type") and not
  (data.itemInfo.classID == Enum.ItemClass.Tradegoods and database:GetCategoryFilter(data.kind, "TradeSkill")) and
  data.itemInfo.itemType then
    category = category .. data.itemInfo.itemType --[[@as string]]
  end

  -- Add the subtype filter to the category if enabled, but same as with
  -- the type filter we don't add it to trade goods when the tradeskill
  -- filter is enabled.
  if database:GetCategoryFilter(data.kind, "Subtype") and not
  (data.itemInfo.classID == Enum.ItemClass.Tradegoods and database:GetCategoryFilter(data.kind, "TradeSkill")) and
  data.itemInfo.itemSubType then
    if category ~= "" then
      category = category .. " - "
    end
    category = category .. data.itemInfo.itemSubType
  end

  -- Add the tradeskill filter to the category if enabled.
  if data.itemInfo.classID == Enum.ItemClass.Tradegoods and database:GetCategoryFilter(data.kind, "TradeSkill") then
    if category ~= "" then
      category = category .. " - "
    end
    category = category .. const.TRADESKILL_MAP[data.itemInfo.subclassID]
  end

  -- Add the expansion filter to the category if enabled.
  if database:GetCategoryFilter(data.kind, "Expansion") and data.itemInfo.expacID ~= nil then
    if category ~= "" then
      category = category .. " - "
    end
    category = category .. const.EXPANSION_MAP[data.itemInfo.expacID] --[[@as string]]
  end

  if category == "" then
    category = L:G('Everything')
  end

  categories:CreateCategory(ctx, {
    name = category,
  })

  local filter = categories:GetCategoryByName(category)
  if filter.allowBlizzardItems and filter.enabled[data.kind] then
    data.categories.blizzard = {name = filter.name, priority = filter.priority}
    return
  end

  local everythingCategoryName = L:G('Everything')
  local everythingFilter = categories:GetCategoryByName(everythingCategoryName)
  if not everythingFilter then
    categories:CreateCategory(ctx, {
      name = everythingCategoryName,
    })
    everythingFilter = categories:GetCategoryByName(everythingCategoryName)
  end
  data.categories.blizzard = {name = everythingFilter.name, priority = everythingFilter.priority}
end

---@param ctx Context
---@param data ItemData
function categories:CalculateAndUpdateManualCategory(ctx, data)
  local category = self:GetCustomCategory(ctx, data.kind, data)
  if category then
    local filter = self.categories[category]
    if category then
      data.categories.manual = {name = category, priority = filter.priority}
    end
  end
end

---@param ctx Context
---@param data ItemData
function categories:CalculateAndUpdateSearchCategory(ctx, data)
  _ = ctx
  local slotkey = data.slotkey
  if self.slotsToCategories[slotkey] and #self.slotsToCategories[slotkey] > 0 then
    local filter = self.categories[self.slotsToCategories[slotkey][1]]
    data.categories.search = {name = filter.name, priority = filter.priority}
  end
end

---@param ctx Context
---@param data ItemData
function categories:CalculateAndUpdateCategoriesForItem(ctx, data)
  data.categories = {}
  if data.isItemEmpty then
    data.categories.blizzard = {name = L:G('Empty Slot'), priority = 10}
    return
  end
  self:CalculateAndUpdateBlizzardCategory(ctx, data)
  self:CalculateAndUpdateManualCategory(ctx, data)
  self:CalculateAndUpdateSearchCategory(ctx, data)
end

---@param ctx Context
---@param data ItemData
---@return string
function categories:GetBestCategoryForItem(ctx, data)
  _ = ctx
  ---@type {name: string, priority: number}[]
  local allCategories = {}
  if data.categories.blizzard then
    table.insert(allCategories, data.categories.blizzard)
  end
  if data.categories.manual then
    table.insert(allCategories, data.categories.manual)
  end
  if data.categories.search then
    table.insert(allCategories, data.categories.search)
  end
  table.sort(allCategories, function(a, b)
    return a.priority < b.priority
  end)
  return allCategories[1].name
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
  local filterNames = self.itemIDToCategories[itemID]
  if filterNames then
    table.sort(filterNames, function(a, b)
      return self.categories[a].priority < self.categories[b].priority
    end)
    for _, name in ipairs(filterNames) do
      local filter = self.categories[name]
      if filter.enabled[kind] then
        return filter.name
      end
    end
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
function categories:RemoveItemFromAllCategories(ctx, id)
  for _, filterName in ipairs(self.itemIDToCategories[id]) do
    self.categories[filterName].itemList[id] = nil
    self.categories[filterName].permanentItemList[id] = nil
    self:SaveCategoryToDisk(ctx, filterName)
  end
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
