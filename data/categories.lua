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
---@field groupBy? number Where group by was before it was the category's own (GroupByOf still reads it).

-- A category (category-lifecycle.md §6) is one kind: a rule (searchCategory, a search), items placed
-- by hand (itemList), or both, defined once and used in each bag it is enabled for.
---@class (exact) CustomCategoryFilter
---@field name string The name of this category as it appears for the user.
---@field itemList table<number, boolean> The items placed in this category by hand.
---@field enabled? table<BagKind, boolean> The bags this category is used in.
---@field readOnly? boolean Currently unused.
---@field save? boolean If true, this category is saved to disk.
---@field searchCategory? SearchCategory Its rule: the items its search matches belong to it.
---@field groupBy? number Its members grouped into sub-categories (0=None, 1=Type, 2=Subtype, 3=Expansion).
---@field note? string A note about the category.
---@field color? number[] The RGB color of the category name.
---@field priority? number Where it is in the order of the Categories list, which is the categories' priority: lower comes first and wins (category-lifecycle.md §7). Default is 10; ties go by name. Never shown.
---@field dynamic? boolean If true, this category is dynamic and added to the database at runtime.
---@field isGroupBySubcategory? boolean If true, this category is a groupBy subcategory and should not be manually deleted.
---@field groupByParent? string If this is a groupBy subcategory, this is the name of the parent search category.
---@field automation? string What it does with its items on its own: "sell" or "destroy" (automation.md).
---@field confirmSale? boolean false when Auto Sell sells at once; confirmed in the vendor's dock otherwise (automation.md §3).
---@field skipRecent? boolean Its items skip Recent Items (Skip Recent Items, docs/next-batch-2.md §1).

---@class (exact) Categories: AceModule
---@field private itemsWithNoCategory table<number, boolean>
---@field private categoryFunctions table<string, fun(data: ItemData): string>
---@field private categoryCount number
---@field private ephemeralCategories table<string, CustomCategoryFilter>
---@field private ephemeralCategoryByItemID table<number, CustomCategoryFilter>
local categories = addon:NewModule('Categories')

-- The generation of everything a custom category lookup (GetCustomCategory) reads. It changes with
-- every change made through this module, so the bags work every item's category out again on their
-- next refresh even when the caller (another addon filing items) asks for no refresh
-- (data-loader.md §18). It is never reset.
categories.generation = 0

-- GetGeneration says which generation the custom categories are at.
---@return number
function categories:GetGeneration()
  return self.generation
end

-- changed starts a new generation.
---@private
function categories:changed()
  self.generation = self.generation + 1
end

function categories:Init()
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
    filter.itemList = filter.itemList or {}
    for id, _ in pairs(filter.itemList) do
      results.itemList[id] = true
    end
  end

  if self.ephemeralCategories[name] then
    self.ephemeralCategories[name].itemList = self.ephemeralCategories[name].itemList or {}
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

  self:changed()
  self.itemsWithNoCategory[id] = nil

  if not database:ItemCategoryExists(category) then
    self:CreateCategory(ctx, {
      name = category,
      itemList = {},
      save = true,
    })
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
  self:changed()
  self:addItemToCategory(ctx, id, category)
end

-- addItemToCategory files an item, without starting a new generation: GetCustomCategory files the
-- items a category function names while it works an item's category out.
---@private
---@param ctx Context
---@param id number
---@param category string
function categories:addItemToCategory(ctx, id, category)
  assert(id, format("Attempted to add item to category %s, but the item ID is nil.", category))
  assert(category ~= nil, format("Attempted to add item %d to a nil category.", id))
  assert(C_Item.GetItemInfoInstant(id), format("Attempted to add item %d to category %s, but the item does not exist.", id, category))

  self.itemsWithNoCategory[id] = nil

  -- Backwards compatability for the old way of adding items to categories.
  if not self.ephemeralCategories[category] then
    self:CreateCategory(ctx, {
      name = category,
      itemList = {},
    })
  end

  if self.ephemeralCategories[category] then
    self.ephemeralCategories[category].itemList[id] = true
    self.ephemeralCategoryByItemID[id] = self.ephemeralCategories[category]
    return
  end

  assert(database:ItemCategoryExists(category), format("Attempted to add item %d to category %s, but the category does not exist.", id, category))
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
  self:changed()
  database:WipeItemCategory(category)
  if self.ephemeralCategories[category] then
    self.ephemeralCategories[category].itemList = self.ephemeralCategories[category].itemList or {}
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
    local filter = database:GetEphemeralItemCategory(category)
    if filter and filter.enabled then
      return filter.enabled[kind]
    end
    return false
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
  self:changed()
  if self.ephemeralCategories[category] then
    local enabled = not self.ephemeralCategories[category].enabled[kind]
    self.ephemeralCategories[category].enabled[kind] = enabled
    database:SetEphemeralItemCategoryEnabled(kind, category, enabled)
    return
  end
  local filter = database:GetItemCategory(category)
  if filter then
    local enabled = not (filter.enabled and filter.enabled[kind])
    database:SetItemCategoryEnabled(kind, category, enabled)
  end
end

---@param kind BagKind
---@param category string The name of the custom category to toggle.
function categories:EnableCategory(kind, category)
  self:changed()
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
  self:changed()
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
  self:changed()
  if self.ephemeralCategories[category] then
    self.ephemeralCategories[category].enabled[kind] = enabled
    database:SetEphemeralItemCategoryEnabled(kind, category, enabled)
  end
  local filter = database:GetItemCategory(category)
  if filter and filter.itemList then
    database:SetItemCategoryEnabled(kind, category, enabled)
  end
end

-- before orders categories by priority (10 when unset), then by name ignoring case: the order of the
-- Categories list, which is their priority (category-lifecycle.md §7). A tie between priorities saved
-- before the list was ordered is alphabetical.
---@param a CustomCategoryFilter
---@param b CustomCategoryFilter
---@return boolean
local function before(a, b)
  local pa, pb = a.priority or 10, b.priority or 10
  if pa ~= pb then
    return pa < pb
  end
  local la, lb = a.name:lower(), b.name:lower()
  if la ~= lb then
    return la < lb
  end
  return a.name < b.name
end

-- everyBag returns a category's bags with every bag on.
---@return table<BagKind, boolean>
local function everyBag()
  local enabled = {}
  for name, kind in pairs(const.BAG_KIND) do
    if name ~= "UNDEFINED" then
      enabled[kind] = true
    end
  end
  return enabled
end

-- RuleOf returns a category's rule (its search), or nil when it has none.
---@param filter? CustomCategoryFilter
---@return string?
function categories:RuleOf(filter)
  local query = filter and filter.searchCategory and filter.searchCategory.query
  if type(query) ~= "string" then
    return nil
  end
  query = strtrim(query)
  return query ~= "" and query or nil
end

-- CreateCategory makes (or makes again) a category. A new one is used in every bag; one made again
-- without saying which bags keeps the bags it had, so a plugin creating its categories at every load
-- never undoes a player's choice. Group by given in the rule (where it was) becomes the category's own.
---@param ctx Context
---@param category CustomCategoryFilter
function categories:CreateCategory(ctx, category)
  -- HACKFIX: This is a backwards compatibility shim for the old way of adding items to categories.
  -- To be removed eventually.
  if type(ctx) == "table" and not ctx.Event then
    category = ctx --[[@as CustomCategoryFilter]]
    ctx = context:New('CreateCategory')
  end
  self:changed()
  local existing = database:GetItemCategory(category.name) or self.ephemeralCategories[category.name]
  category.enabled = category.enabled or (existing and existing.enabled) or everyBag()
  -- A new category goes on top of the order (asked: "newest on top"); a group by's section follows
  -- its category.
  local new = existing == nil and not category.isGroupBySubcategory
    and (category.save or database:GetEphemeralItemCategory(category.name) == nil)
  if new then
    category.priority = self:topPriority()
  end
  if category.groupBy == nil and type(category.searchCategory) == "table" then
    category.groupBy = category.searchCategory.groupBy
  end

  if category.save then
    database:CreateOrUpdateCategory(category)
  elseif self.ephemeralCategories[category.name] == nil then
    local savedState = database:GetEphemeralItemCategory(category.name)
    if savedState and savedState.enabled then
      category.enabled = savedState.enabled
      category.dynamic = savedState.dynamic
      category.isGroupBySubcategory = savedState.isGroupBySubcategory
      category.groupByParent = savedState.groupByParent
    end
    -- The color, priority and automation a player set for a plugin's category win over the plugin's.
    if savedState then
      if savedState.color ~= nil then
        category.color = savedState.color
      end
      if savedState.priority ~= nil then
        category.priority = savedState.priority
      end
      if savedState.automation ~= nil then
        category.automation = savedState.automation
      end
      if savedState.confirmSale ~= nil then
        category.confirmSale = savedState.confirmSale
      end
      if savedState.skipRecent ~= nil then
        category.skipRecent = savedState.skipRecent
      end
    end
    self.ephemeralCategories[category.name] = category
    category.itemList = category.itemList or {}
    for id in pairs(category.itemList) do
      self.ephemeralCategoryByItemID[id] = category
    end
    database:CreateOrUpdateCategory(category)
    if new then
      -- Its place is the player's from now on: saved, so it stays there in the next session.
      database:UpdateEphemeralItemCategory(category.name, { enabled = category.enabled, priority = category.priority })
    end
  end
  events:SendMessage(ctx, 'categories/Changed')
end

-- topPriority returns the priority that puts a category on top of the order.
---@private
---@return number
function categories:topPriority()
  local top
  for _, filter in pairs(self:GetAllCategories()) do
    local priority = filter.priority or 10
    if top == nil or priority < top then
      top = priority
    end
  end
  return top and top - 1 or 1
end

-- GetOrder returns every category's name but a group by's sections, in the order of the Categories
-- list: their priority, the first winning an item that fits more than one (category-lifecycle.md §7).
---@return string[]
function categories:GetOrder()
  local list = {}
  for _, filter in pairs(self:GetAllCategories()) do
    if not filter.isGroupBySubcategory then
      table.insert(list, filter)
    end
  end
  table.sort(list, before)
  local names = {}
  for i, filter in ipairs(list) do
    names[i] = filter.name
  end
  return names
end

-- saveState saves what a player set for a plugin's category (its saved state, category-lifecycle.md §1).
---@param filter CustomCategoryFilter
local function saveState(filter)
  database:UpdateEphemeralItemCategory(filter.name, { enabled = filter.enabled, color = filter.color,
    priority = filter.priority, automation = filter.automation, confirmSale = filter.confirmSale,
    skipRecent = filter.skipRecent })
end

-- setPriority sets a category's place, saving a plugin's in its saved state as UpdateCategory does.
---@private
---@param name string
---@param priority number
function categories:setPriority(name, priority)
  local filter = self:GetCategoryByName(name)
  filter.priority = priority
  if database:GetItemCategory(name) == nil then
    saveState(filter)
  end
end

-- MoveCategory moves a category in the order right after another (after), or to the top without one,
-- then numbers every category in the order from 1, so none ties; a group by's sections take their
-- category's place. It returns false, changing nothing, for a name no category has, an anchor that is
-- none, or a category that lands where it was.
---@param ctx Context
---@param name string
---@param after? string
---@return boolean
function categories:MoveCategory(ctx, name, after)
  local order = self:GetOrder()
  local from
  for i, n in ipairs(order) do
    if n == name then
      from = i
    end
  end
  if from == nil then
    return false
  end
  table.remove(order, from)
  local to = 1
  if after ~= nil then
    to = nil
    for i, n in ipairs(order) do
      if n == after then
        to = i + 1
      end
    end
    if to == nil then
      return false
    end
  end
  if to == from then
    return false
  end
  table.insert(order, to, name)
  self:changed()
  for i, n in ipairs(order) do
    self:setPriority(n, i)
  end
  for _, filter in pairs(self:GetAllCategories()) do
    if filter.isGroupBySubcategory and filter.groupByParent then
      local parent = self:GetCategoryByName(filter.groupByParent)
      if parent then
        self:setPriority(filter.name, parent.priority)
      end
    end
  end
  events:SendMessage(ctx, 'categories/Changed')
  events:SendMessage(ctx, 'bags/Rederive', { resetLayout = true, buttons = true })
  return true
end

---@param name string
---@return CustomCategoryFilter
function categories:GetCategoryByName(name)
  return database:GetItemCategory(name) or self.ephemeralCategories[name]
end

-- GetAllSearchCategories returns every category with a rule.
---@return table<string, CustomCategoryFilter>
function categories:GetAllSearchCategories()
  ---@type table<string, CustomCategoryFilter>
  local results = {}
  local savedCategories = database:GetAllItemCategories()
  for name, filter in pairs(savedCategories) do
    if self:RuleOf(filter) then
      results[name] = filter
    end
  end
  for name, filter in pairs(self.ephemeralCategories) do
    if results[name] == nil and savedCategories[name] == nil and self:RuleOf(filter) then
      results[name] = filter
    end
  end
  return results
end

-- UpdateCategory changes a category in place, keeping its items: fields may hold color (a color, or
-- false for none), priority, enabled (the bags named are set, the others kept), rule (its search;
-- empty for none), groupBy, automation ("sell", "destroy", or false for none), confirmSale (false:
-- Auto Sell sells at once; true, the default, is not stored) and skipRecent (true: its items skip Recent
-- Items; false, the default, is not stored). A plugin's category keeps its own rule and
-- group by; the bags, color, priority and automation set for it are saved, and win when the plugin makes
-- it again. The bags are recalculated unless only the automation changed, which changes no item's
-- category. It returns false for a name no category has.
---@param ctx Context
---@param name string
---@param fields {color?: number[]|false, priority?: number, enabled?: table<BagKind, boolean>, rule?: string, groupBy?: number, automation?: string|false, confirmSale?: boolean, skipRecent?: boolean}
---@return boolean
function categories:UpdateCategory(ctx, name, fields)
  local saved = database:GetItemCategory(name)
  local filter = saved or self.ephemeralCategories[name]
  if filter == nil then
    return false
  end
  self:changed()
  if fields.color ~= nil then
    filter.color = fields.color or nil
  end
  if fields.priority ~= nil then
    filter.priority = fields.priority
  end
  if fields.automation ~= nil then
    filter.automation = fields.automation or nil
  end
  if fields.confirmSale == false then
    filter.confirmSale = false
  elseif fields.confirmSale ~= nil then
    filter.confirmSale = nil
  end
  if fields.skipRecent ~= nil then
    filter.skipRecent = fields.skipRecent == true or nil
  end
  if fields.enabled ~= nil then
    filter.enabled = filter.enabled or everyBag()
    for kind, on in pairs(fields.enabled) do
      filter.enabled[kind] = on
    end
  end
  if saved then
    if fields.rule ~= nil then
      local rule = strtrim(fields.rule)
      saved.searchCategory = rule ~= "" and { query = rule } or nil
    end
    if fields.groupBy ~= nil then
      saved.groupBy = fields.groupBy
    end
  else
    saveState(filter)
  end
  events:SendMessage(ctx, 'categories/Changed')
  local onlyAutomation = fields.automation ~= nil or fields.confirmSale ~= nil
  for key in pairs(fields) do
    if key ~= 'automation' and key ~= 'confirmSale' then
      onlyAutomation = false
    end
  end
  if not onlyAutomation then
    events:SendMessage(ctx, 'bags/Rederive', { resetLayout = true, buttons = true })
  end
  return true
end

-- AutomationOf returns what a category does with its items on its own ("sell", "destroy" or nil;
-- automation.md): a group by's sections do what their category does. A built-in category has none.
---@param name string
---@return string?
function categories:AutomationOf(name)
  local filter = self:GetCategoryByName(name)
  if filter and filter.isGroupBySubcategory and filter.groupByParent then
    filter = self:GetCategoryByName(filter.groupByParent)
  end
  return filter and filter.automation or nil
end

-- SkipsRecentOf says whether a category's items skip Recent Items (Skip Recent Items; a group by's
-- sections as their category). A built-in category does not.
---@param name string
---@return boolean
function categories:SkipsRecentOf(name)
  local filter = self:GetCategoryByName(name)
  if filter and filter.isGroupBySubcategory and filter.groupByParent then
    filter = self:GetCategoryByName(filter.groupByParent)
  end
  return filter ~= nil and filter.skipRecent == true
end

-- ConfirmsSaleOf says whether Auto Sell waits for the player to confirm a category's sale in the
-- vendor's dock (true unless turned off; automation.md §3): a group by's sections as their category does.
---@param name string
---@return boolean
function categories:ConfirmsSaleOf(name)
  local filter = self:GetCategoryByName(name)
  if filter and filter.isGroupBySubcategory and filter.groupByParent then
    filter = self:GetCategoryByName(filter.groupByParent)
  end
  return not (filter and filter.confirmSale == false)
end

-- GetSortedSearchCategories returns the categories with a rule in the order (category-lifecycle.md §7):
-- by priority, ties by name, the first winning an item more than one matches.
---@return CustomCategoryFilter[]
function categories:GetSortedSearchCategories()
  ---@type CustomCategoryFilter[]
  local results = {}
  local savedCategories = categories:GetAllSearchCategories()
  for _, searchCategory in pairs(savedCategories) do
    table.insert(results, searchCategory)
  end
  table.sort(results, before)
  return results
end

---@param ctx Context
---@param category string
function categories:DeleteCategory(ctx, category)
  self:changed()
  -- HACKFIX: This is a backwards compatibility shim for the old way of adding items to categories.
  -- To be removed eventually.
  if type(ctx) == "string" then
    category = ctx
    ctx = context:New('DeleteCategory')
  end

  if self.ephemeralCategories[category] then
    self.ephemeralCategories[category].itemList = self.ephemeralCategories[category].itemList or {}
    for id, _ in pairs(self.ephemeralCategories[category].itemList) do
      self.ephemeralCategoryByItemID[id] = nil
    end
    self.ephemeralCategories[category] = nil
  end

  database:DeleteItemCategory(category)
  events:SendMessage(ctx, 'categories/Changed')
  events:SendMessage(ctx, 'bags/Rederive', { resetLayout = true, buttons = true })
end

-- RenameCategory renames a category.
---@param ctx Context
---@param oldName string
---@param newName string
---@return boolean success
function categories:RenameCategory(ctx, oldName, newName)
  self:changed()
  -- Trim whitespace and validate new name
  newName = strtrim(newName)
  if newName == "" then
    debug:Log("categories", "Cannot rename category to empty name")
    return false
  end

  -- Validate category exists
  if not self:DoesCategoryExist(oldName) then
    debug:Log("categories", "Category not found: %s", oldName)
    return false
  end

  -- Validate new name doesn't conflict
  if self:DoesCategoryExist(newName) then
    debug:Log("categories", "Category already exists: %s", newName)
    return false
  end

  -- Update module-level ephemeral caches
  if self.ephemeralCategories[oldName] then
    self.ephemeralCategories[newName] = self.ephemeralCategories[oldName]
    self.ephemeralCategories[newName].name = newName
    self.ephemeralCategories[oldName] = nil

    -- Update item lookup cache
    self.ephemeralCategories[newName].itemList = self.ephemeralCategories[newName].itemList or {}
    for itemID, _ in pairs(self.ephemeralCategories[newName].itemList) do
      self.ephemeralCategoryByItemID[itemID].name = newName
    end
  end

  -- Delete grouped sub-categories (e.g., "OldName - Consumable", "OldName - Quest")
  -- These will be recreated with the new name on next refresh
  local groupedPrefix = oldName .. " - "
  local categoriesToDelete = {}
  for categoryName, _ in pairs(self.ephemeralCategories) do
    if categoryName:sub(1, #groupedPrefix) == groupedPrefix then
      table.insert(categoriesToDelete, categoryName)
    end
  end
  for _, categoryName in ipairs(categoriesToDelete) do
    if self.ephemeralCategories[categoryName] then
      self.ephemeralCategories[categoryName].itemList = self.ephemeralCategories[categoryName].itemList or {}
      for itemID, _ in pairs(self.ephemeralCategories[categoryName].itemList) do
        self.ephemeralCategoryByItemID[itemID] = nil
      end
      self.ephemeralCategories[categoryName] = nil
    end
  end

  -- Call database layer to update all data structures
  local success = database:RenameCategory(oldName, newName)
  if not success then
    debug:Log("categories", "Failed to rename category in database: %s -> %s", oldName, newName)
    return false
  end

  debug:Log("categories", "Renamed category: %s -> %s", oldName, newName)
  events:SendMessage(ctx, 'categories/Changed', newName, oldName)
  events:SendMessage(ctx, 'bags/Rederive', { resetLayout = true, buttons = true })
  return true
end

-- Hiding a section was retired (category-lifecycle.md §6; tabs do it better): every section shows.
-- HideCategory, ShowCategory and ToggleCategoryShown stay for plugins that call them, and do nothing.
---@param ctx? Context
---@param category? string
function categories:HideCategory(ctx, category)
  local _, _ = ctx, category
end

---@param ctx? Context
---@param category? string
function categories:ShowCategory(ctx, category)
  local _, _ = ctx, category
end

---@param category? string
---@return boolean
function categories:IsCategoryShown(category)
  local _ = category
  return true
end

---@param category string
---@return boolean
function categories:IsDynamicCategory(category)
  -- If there's a saved category with this name, it's not dynamic (user created it)
  if database:GetItemCategory(category) then
    return false
  end
  return self.ephemeralCategories[category] and self.ephemeralCategories[category].dynamic or false
end

-- IsGroupBySubcategory returns true if a category is a grouped sub-category
-- (created by a search category with groupBy enabled).
---@param category string
---@return boolean
function categories:IsGroupBySubcategory(category)
  local filter = self:GetCategoryByName(category)
  return filter and filter.isGroupBySubcategory or false
end

---@param ctx? Context
---@param category? string
function categories:ToggleCategoryShown(ctx, category)
  local _, _ = ctx, category
end

-- GetCustomCategory returns the custom category for an item, or nil if it doesn't have one.
-- This will JIT call all registered functions the first time an item is seen, returning
-- the custom category if one is found. If no custom category is found, nil is returned.
---@param ctx Context
---@param kind BagKind
---@param data ItemData The item data to get the custom category for.
---@return string|nil categoryName
---@return number|nil priority
---@return CustomCategoryFilter|nil filter The category, for the bags to group its items (its groupBy).
function categories:GetCustomCategory(ctx, kind, data)
  -- HACKFIX: This is a backwards compatibility shim for the old way of adding items to categories.
  -- To be removed eventually.
  if type(ctx) == "number" then
    data = kind --[[@as ItemData]]
    kind = ctx
    ctx = context:New('GetCustomCategory')
  end
  local itemID = data.itemInfo.itemID
  if not itemID then return nil, nil end
  local filter = database:GetItemCategoryByItemID(itemID)
  if filter.enabled and filter.enabled[kind] then
    return filter.name, filter.priority or 10, filter
  end

  filter = self.ephemeralCategoryByItemID[itemID]

  if filter and filter.enabled[kind] then
    return filter.name, filter.priority or 10, filter
  end

  -- Check for items that had no category previously. This
  -- is a performance optimization to avoid calling all
  -- registered functions for every item.
  if self.itemsWithNoCategory[itemID] then return nil, nil end

  local errorHandler = (_G.geterrorhandler and _G.geterrorhandler()) or error
  for _, func in pairs(self.categoryFunctions) do
    local success, args = xpcall(func, errorHandler, data)
    if success and args ~= nil then
      local category = select(1, args) --[[@as string]]
      local found = self.ephemeralCategories[category] and true or false
      self:addItemToCategory(ctx, itemID, category)
      if not found then
        self.categoryCount = self.categoryCount + 1
        events:SendMessage(ctx, 'categories/Changed')
      end
      if self:IsCategoryEnabled(kind, category) then
        -- Get priority from the category if it exists
        local categoryFilter = self.ephemeralCategories[category]
        local priority = categoryFilter and categoryFilter.priority or 10
        return category, priority, categoryFilter
      end
    end
  end
  self.itemsWithNoCategory[itemID] = true
  return nil, nil
end

---@param id number The ItemID of the item to remove from a custom category.
---@param category? string When provided, remove the item only from this specific
--- category (whether it is the item's ephemeral assignment or the user's saved,
--- persisted assignment). When omitted, remove only the item's ephemeral
--- assignment and leave any saved (persisted) assignment untouched.
---
--- An unscoped call must never silently destroy a category the user themselves
--- filed the item into: plugins routinely add items to their own ephemeral
--- category and later remove them, and the old unscoped behaviour also deleted
--- the user's hand-filed persisted assignment with no signal to the caller
--- (issue #1079). Pass `category` explicitly to remove a persisted assignment.
function categories:RemoveItemFromCategory(id, category)
  self:changed()
  self.itemsWithNoCategory[id] = nil

  if category ~= nil then
    -- Scoped removal: only touch the named category, wherever it lives.
    local ephemeral = self.ephemeralCategories[category]
    if ephemeral and ephemeral.itemList then
      ephemeral.itemList[id] = nil
    end
    local filter = self.ephemeralCategoryByItemID[id]
    if filter and filter.name == category then
      self.ephemeralCategoryByItemID[id] = nil
    end
    local persistedCategory = database:GetItemCategoryByItemID(id)
    if persistedCategory.name == category then
      database:DeleteItemFromCategory(id, category)
    end
    return
  end

  -- Unscoped removal: only the ephemeral assignment. The user's saved
  -- (persisted) assignment is intentionally preserved (issue #1079).
  local filter = self.ephemeralCategoryByItemID[id]
  if filter then
    if filter.itemList then
      filter.itemList[id] = nil
    end
    self.ephemeralCategoryByItemID[id] = nil
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
  self:changed()
  self.categoryFunctions[id] = func
  wipe(self.itemsWithNoCategory)
end

-- ReprocessAllItems will wipe the category cache and cause all items to be fully reprocessed, recategoried,
-- and rerendered. This is a very expensive operation to call and should only be called once all,
-- category functions have been registered or if some configuration changes and all items should be
-- reprocessed and re-categorized.
---@param ctx Context
function categories:ReprocessAllItems(ctx)
  self:changed()
  wipe(self.itemsWithNoCategory)
  events:SendMessage(ctx, 'bags/Rederive', { resetLayout = true, buttons = true })
end
