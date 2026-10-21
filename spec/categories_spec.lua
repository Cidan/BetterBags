-- categories_spec.lua -- Unit tests for data/categories.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Dependencies
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")

local context = addon:GetModule("Context")
local events = addon:GetModule("Events")
events:Init()

local debug = StubBetterBagsModule("Debug")
debug.Log = function() end
debug.Inspect = function() end

local const = StubBetterBagsModule("Constants")
const.BAG_KIND = { BACKPACK = 0, BANK = 1, GUILD = 2, UNDEFINED = -1 }
const.SEARCH_CATEGORY_GROUP_BY = const.SEARCH_CATEGORY_GROUP_BY or { NONE = 0, TYPE = 1, SUBTYPE = 2, EXPANSION = 3 }

-- In-memory database mock for categories
local database = StubBetterBagsModule("Database")
local dbCategories = {}
local dbEphemeralCategories = {}
local dbCategoryOptions = {}

database.GetAllItemCategories = function() return dbCategories end
database.GetAllEphemeralItemCategories = function() return dbEphemeralCategories end
database.GetItemCategory = function(_, name) return dbCategories[name] end
database.GetEphemeralItemCategory = function(_, name) return dbEphemeralCategories[name] end
database.ItemCategoryExists = function(_, name) return dbCategories[name] ~= nil end
database.SaveItemToCategory = function(_, id, name)
  dbCategories[name] = dbCategories[name] or {name = name, itemList = {}}
  dbCategories[name].itemList[id] = true
end
-- As the real database: a saved category is kept as given; a plugin's keeps only its saved state (its
-- bags, flags, and the color and priority a player set), a copy.
database.CreateOrUpdateCategory = function(_, category)
  if category.save then
    dbCategories[category.name] = category
  else
    local saved = dbEphemeralCategories[category.name]
    dbEphemeralCategories[category.name] = {
      name = category.name, enabled = category.enabled, dynamic = category.dynamic,
      isGroupBySubcategory = category.isGroupBySubcategory, groupByParent = category.groupByParent, itemList = {},
      color = saved and saved.color, priority = saved and saved.priority,
    }
  end
end
database.DeleteItemCategory = function(_, name)
  dbCategories[name] = nil
  dbEphemeralCategories[name] = nil
end
database.WipeItemCategory = function(_, name)
  if dbCategories[name] then
    dbCategories[name].itemList = {}
  end
end
database.SetItemCategoryEnabled = function(_, kind, name, enabled)
  if dbCategories[name] then
    dbCategories[name].enabled = dbCategories[name].enabled or {}
    dbCategories[name].enabled[kind] = enabled
  end
end
database.SetEphemeralItemCategoryEnabled = function(_, kind, name, enabled)
  if dbEphemeralCategories[name] then
    dbEphemeralCategories[name].enabled = dbEphemeralCategories[name].enabled or {}
    dbEphemeralCategories[name].enabled[kind] = enabled
  end
end
database.GetItemCategoryByItemID = function(_, id)
  for _, cat in pairs(dbCategories) do
    if cat.itemList and cat.itemList[id] then return cat end
  end
  return {}
end
database.DeleteItemFromCategory = function(_, id, name)
  if dbCategories[name] and dbCategories[name].itemList then
    dbCategories[name].itemList[id] = nil
  end
end
-- The saved state of a plugin's category: the bags, color and priority a player set for it.
database.UpdateEphemeralItemCategory = function(_, name, fields)
  dbEphemeralCategories[name] = dbEphemeralCategories[name] or { name = name, itemList = {} }
  for k, v in pairs(fields) do dbEphemeralCategories[name][k] = v end
end
database.RenameCategory = function(_, oldName, newName)
  if dbCategories[oldName] then
    dbCategories[newName] = dbCategories[oldName]
    dbCategories[newName].name = newName
    dbCategories[oldName] = nil
    return true
  end
  if dbEphemeralCategories[oldName] then
    dbEphemeralCategories[newName] = dbEphemeralCategories[oldName]
    dbEphemeralCategories[newName].name = newName
    dbEphemeralCategories[oldName] = nil
    return true
  end
  return false
end

LoadBetterBagsModule("data/categories.lua")
local categories = addon:GetModule("Categories")

describe("Categories", function()

  before_each(function()
    -- Reset database state
    for k in pairs(dbCategories) do dbCategories[k] = nil end
    for k in pairs(dbEphemeralCategories) do dbEphemeralCategories[k] = nil end
    for k in pairs(dbCategoryOptions) do dbCategoryOptions[k] = nil end
    -- Re-initialize module
    categories:Init()
  end)

  -- The bags keep each item's category until something it reads changes (data-loader.md §18), so
  -- every change made through this module starts a new generation, including other addons filing
  -- items without asking for a refresh.
  describe("generation", function()
    local function bumps(fn)
      local before = categories:GetGeneration()
      fn()
      return categories:GetGeneration() > before
    end

    it("changes with every change of what a category lookup reads", function()
      local ctx = context:New("test")
      categories:CreateCategory(ctx, { name = "Mats", itemList = {}, save = true })
      local changes = {
        CreateCategory = function() categories:CreateCategory(ctx, { name = "Gems", itemList = {} }) end,
        AddItemToCategory = function() categories:AddItemToCategory(ctx, 101, "Gems") end,
        AddPermanentItemToCategory = function() categories:AddPermanentItemToCategory(ctx, 102, "Mats") end,
        RemoveItemFromCategory = function() categories:RemoveItemFromCategory(101, "Gems") end,
        WipeCategory = function() categories:WipeCategory(ctx, "Mats") end,
        ToggleCategory = function() categories:ToggleCategory(0, "Gems") end,
        EnableCategory = function() categories:EnableCategory(0, "Gems") end,
        DisableCategory = function() categories:DisableCategory(0, "Gems") end,
        SetCategoryState = function() categories:SetCategoryState(0, "Gems", true) end,
        RegisterCategoryFunction = function() categories:RegisterCategoryFunction("spec", function() return nil end) end,
        UpdateCategory = function() categories:UpdateCategory(ctx, "Mats", { priority = 4 }) end,
        RenameCategory = function() categories:RenameCategory(ctx, "Mats", "Metals") end,
        DeleteCategory = function() categories:DeleteCategory(ctx, "Metals") end,
        ReprocessAllItems = function() categories:ReprocessAllItems(ctx) end,
      }
      for _, name in ipairs({ "CreateCategory", "AddItemToCategory", "AddPermanentItemToCategory",
        "RemoveItemFromCategory", "WipeCategory", "ToggleCategory", "EnableCategory", "DisableCategory",
        "SetCategoryState", "RegisterCategoryFunction", "UpdateCategory", "RenameCategory", "DeleteCategory",
        "ReprocessAllItems" }) do
        assert.is_true(bumps(changes[name]), name)
      end
    end)

    it("does not change while a lookup files an item a category function names", function()
      local ctx = context:New("test")
      categories:CreateCategory(ctx, { name = "Fish", itemList = {} })
      categories:RegisterCategoryFunction("fish", function() return "Fish" end)
      local data = { itemInfo = { itemID = 555 } }
      assert.is_false(bumps(function()
        assert.equal("Fish", (categories:GetCustomCategory(ctx, 0, data)))
      end))
    end)
  end)

  -- ─── CreateCategory ─────────────────────────────────────────────────────────

  describe("CreateCategory", function()

    it("creates a persistent category when save=true", function()
      local ctx = context:New("Test")
      categories:CreateCategory(ctx, {
        name = "Weapons",
        itemList = {},
        save = true,
      })
      assert.is_not_nil(dbCategories["Weapons"])
    end)

    it("creates an ephemeral category when save is not set", function()
      local ctx = context:New("Test")
      categories:CreateCategory(ctx, {
        name = "Dynamic",
        itemList = {},
      })
      assert.is_true(categories:DoesCategoryExist("Dynamic"))
    end)

    -- Every bag the same way, the guild bank included (category-lifecycle.md §6).
    it("uses a new category in every bag", function()
      local ctx = context:New("Test")
      categories:CreateCategory(ctx, {
        name = "Test",
        itemList = {},
        save = true,
      })
      assert.are.same({ [0] = true, [1] = true, [2] = true }, dbCategories["Test"].enabled)
    end)

    -- Plugins create their categories again at every load; that must not undo the bags a player chose.
    it("keeps the bags a category is used in when it is made again without saying", function()
      local ctx = context:New("Test")
      dbCategories["Mats"] = { name = "Mats", itemList = {}, save = true, enabled = { [0] = true, [1] = false, [2] = true } }
      categories:CreateCategory(ctx, { name = "Mats", itemList = {}, save = true })
      assert.is_false(dbCategories["Mats"].enabled[const.BAG_KIND.BANK])
      categories:CreateCategory(ctx, { name = "Mats", itemList = {}, save = true, enabled = { [0] = true, [1] = true, [2] = true } })
      assert.is_true(dbCategories["Mats"].enabled[const.BAG_KIND.BANK], "unless it says")
    end)

    it("handles legacy call without context (backwards compat)", function()
      -- When first arg is a table without Event, it's treated as the category
      categories:CreateCategory({
        name = "Legacy",
        itemList = {},
        save = true,
      })
      assert.is_not_nil(dbCategories["Legacy"])
    end)
  end)

  -- ─── DoesCategoryExist ──────────────────────────────────────────────────────

  describe("DoesCategoryExist", function()

    it("returns true for persistent categories", function()
      dbCategories["Saved"] = {name = "Saved", itemList = {}}
      assert.is_true(categories:DoesCategoryExist("Saved"))
    end)

    it("returns true for ephemeral categories", function()
      local ctx = context:New("Test")
      categories:CreateCategory(ctx, {name = "Ephemeral", itemList = {}})
      assert.is_true(categories:DoesCategoryExist("Ephemeral"))
    end)

    it("returns false for non-existent categories", function()
      assert.is_false(categories:DoesCategoryExist("Ghost"))
    end)
  end)

  -- ─── GetAllCategories ───────────────────────────────────────────────────────

  describe("GetAllCategories", function()

    it("merges persistent and ephemeral categories", function()
      dbCategories["Saved"] = {name = "Saved", itemList = {}}
      local ctx = context:New("Test")
      categories:CreateCategory(ctx, {name = "Ephemeral", itemList = {}})

      local all = categories:GetAllCategories()
      assert.is_not_nil(all["Saved"])
      assert.is_not_nil(all["Ephemeral"])
    end)

    it("persistent takes priority over ephemeral with same name", function()
      dbCategories["Weapons"] = {name = "Weapons", itemList = {}, save = true}
      local ctx = context:New("Test")
      categories:CreateCategory(ctx, {name = "Weapons", itemList = {[123] = true}})

      local all = categories:GetAllCategories()
      -- Persistent version should win
      assert.is_true(all["Weapons"].save or false)
    end)
  end)

  -- ─── GetMergedCategory ──────────────────────────────────────────────────────

  describe("GetMergedCategory", function()

    it("merges item lists from persistent and ephemeral sources", function()
      dbCategories["Mix"] = {name = "Mix", itemList = {[100] = true, [200] = true}}
      local ctx = context:New("Test")
      categories:CreateCategory(ctx, {name = "Mix", itemList = {[300] = true}})
      -- Force the ephemeral category to have an itemList
      categories.ephemeralCategories["Mix"].itemList[300] = true

      local merged = categories:GetMergedCategory("Mix")
      assert.is_true(merged.itemList[100] or false)
      assert.is_true(merged.itemList[200] or false)
      assert.is_true(merged.itemList[300] or false)
    end)

    it("returns empty itemList for non-existent category", function()
      local merged = categories:GetMergedCategory("Ghost")
      assert.same({}, merged.itemList)
      assert.are.equal("Ghost", merged.name)
    end)
  end)

  -- ─── DeleteCategory ─────────────────────────────────────────────────────────

  describe("DeleteCategory", function()

    it("removes a persistent category", function()
      dbCategories["ToDelete"] = {name = "ToDelete", itemList = {}}
      local ctx = context:New("Test")
      categories:DeleteCategory(ctx, "ToDelete")
      assert.is_nil(dbCategories["ToDelete"])
    end)

    it("removes an ephemeral category and cleans up item ID references", function()
      local ctx = context:New("Test")
      categories:CreateCategory(ctx, {name = "Temp", itemList = {[42] = true}})
      categories.ephemeralCategories["Temp"].itemList[42] = true
      categories.ephemeralCategoryByItemID[42] = categories.ephemeralCategories["Temp"]

      categories:DeleteCategory(ctx, "Temp")
      assert.is_nil(categories.ephemeralCategories["Temp"])
      assert.is_nil(categories.ephemeralCategoryByItemID[42])
    end)

    it("handles legacy call without context", function()
      dbCategories["Legacy"] = {name = "Legacy", itemList = {}}
      categories:DeleteCategory("Legacy")
      assert.is_nil(dbCategories["Legacy"])
    end)
  end)

  -- ─── RenameCategory ─────────────────────────────────────────────────────────

  describe("RenameCategory", function()

    it("renames a persistent category", function()
      dbCategories["OldName"] = {name = "OldName", itemList = {}, save = true}
      local ctx = context:New("Test")
      local ok = categories:RenameCategory(ctx, "OldName", "NewName")
      assert.is_true(ok)
      assert.is_nil(dbCategories["OldName"])
      assert.is_not_nil(dbCategories["NewName"])
    end)

    it("renames an ephemeral category", function()
      local ctx = context:New("Test")
      categories:CreateCategory(ctx, {name = "OldEph", itemList = {}})
      local ok = categories:RenameCategory(ctx, "OldEph", "NewEph")
      assert.is_true(ok)
      assert.is_nil(categories.ephemeralCategories["OldEph"])
      assert.is_not_nil(categories.ephemeralCategories["NewEph"])
    end)

    it("fails when renaming to an empty name", function()
      dbCategories["Cat"] = {name = "Cat", itemList = {}}
      local ctx = context:New("Test")
      local ok = categories:RenameCategory(ctx, "Cat", "  ")
      assert.is_false(ok)
    end)

    it("fails when target name already exists", function()
      dbCategories["A"] = {name = "A", itemList = {}}
      dbCategories["B"] = {name = "B", itemList = {}}
      local ctx = context:New("Test")
      local ok = categories:RenameCategory(ctx, "A", "B")
      assert.is_false(ok)
    end)

    it("fails when source category doesn't exist", function()
      local ctx = context:New("Test")
      local ok = categories:RenameCategory(ctx, "Ghost", "NewName")
      assert.is_false(ok)
    end)

    it("cleans up grouped sub-categories on rename", function()
      local ctx = context:New("Test")
      categories:CreateCategory(ctx, {name = "Parent", itemList = {}})
      categories:CreateCategory(ctx, {
        name = "Parent - Consumable",
        itemList = {[10] = true},
        isGroupBySubcategory = true,
        groupByParent = "Parent",
      })
      categories.ephemeralCategories["Parent - Consumable"].itemList[10] = true
      categories.ephemeralCategoryByItemID[10] = categories.ephemeralCategories["Parent - Consumable"]

      categories:RenameCategory(ctx, "Parent", "NewParent")
      -- Old sub-category should be cleaned up
      assert.is_nil(categories.ephemeralCategories["Parent - Consumable"])
      assert.is_nil(categories.ephemeralCategoryByItemID[10])
    end)
  end)

  -- ─── Category visibility ───────────────────────────────────────────────────

  -- Hiding a section was retired (category-lifecycle.md §6): every section shows. Plugins may still
  -- call the old functions; they do nothing.
  describe("Category visibility (retired)", function()
    it("shows every section, whatever hides it", function()
      local ctx = context:New("Test")
      categories:HideCategory(ctx, "Hidden")
      categories:ToggleCategoryShown(ctx, "Hidden")
      categories:ToggleCategoryShown(ctx, "Hidden")
      assert.is_true(categories:IsCategoryShown("Hidden"))
      categories:ShowCategory(ctx, "Hidden")
      assert.is_true(categories:IsCategoryShown("Hidden"))
    end)
  end)

  -- ─── One kind of category ──────────────────────────────────────────────────

  describe("rules and group by", function()
    it("reads a category's rule: its search, none when empty", function()
      assert.are.equal("type = armor", categories:RuleOf({ searchCategory = { query = "  type = armor " } }))
      assert.is_nil(categories:RuleOf({ searchCategory = { query = "  " } }))
      assert.is_nil(categories:RuleOf({}))
      assert.is_nil(categories:RuleOf(nil))
    end)

    -- Group by is the category's own (its hand-placed items are grouped too); plugins may still pass it
    -- in the rule, where it was.
    it("makes a rule's group by the category's own when a category is made", function()
      local ctx = context:New("Test")
      categories:CreateCategory(ctx, { name = "Gear", itemList = {}, save = true, searchCategory = { query = "x", groupBy = 1 } })
      assert.are.equal(1, dbCategories["Gear"].groupBy)
      categories:CreateCategory(ctx, { name = "Own", itemList = {}, save = true, groupBy = 2,
        searchCategory = { query = "x", groupBy = 1 } })
      assert.are.equal(2, dbCategories["Own"].groupBy, "its own wins")
    end)

    it("names the category it found for an item, for the bags to group its items", function()
      local ctx = context:New("Test")
      dbCategories["Mats"] = { name = "Mats", itemList = { [9] = true }, save = true, priority = 4, groupBy = 1,
        enabled = { [0] = true } }
      local name, priority, filter = categories:GetCustomCategory(ctx, const.BAG_KIND.BACKPACK, { itemInfo = { itemID = 9 } })
      assert.are.equal("Mats", name)
      assert.are.equal(4, priority)
      assert.are.equal(dbCategories["Mats"], filter)
    end)

    it("lists as search categories only those with a rule", function()
      dbCategories["Empty"] = { name = "Empty", itemList = {}, searchCategory = { query = "" } }
      dbCategories["Rule"] = { name = "Rule", itemList = {}, searchCategory = { query = "a" } }
      local found = categories:GetAllSearchCategories()
      assert.is_nil(found.Empty)
      assert.is_not_nil(found.Rule)
    end)
  end)

  describe("UpdateCategory", function()
    local sent, savedSend

    before_each(function()
      sent = {}
      savedSend = events.SendMessage
      events.SendMessage = function(_, _, message, ...) table.insert(sent, { message, ... }) end
    end)

    after_each(function()
      events.SendMessage = savedSend
    end)

    it("changes what it is given, keeps the items, and recalculates the bags", function()
      dbCategories["Mats"] = { name = "Mats", itemList = { [5] = true }, save = true, priority = 10,
        enabled = { [0] = true, [1] = true, [2] = true }, color = { 1, 0, 0 } }
      local before = categories:GetGeneration()
      assert.is_true(categories:UpdateCategory(context:New("Test"), "Mats", {
        priority = 3, enabled = { [1] = false }, rule = " type = trade goods ", groupBy = 1, color = false,
      }))
      local f = dbCategories["Mats"]
      assert.are.equal(3, f.priority)
      assert.are.same({ [0] = true, [1] = false, [2] = true }, f.enabled)
      assert.are.same({ query = "type = trade goods" }, f.searchCategory)
      assert.are.equal(1, f.groupBy)
      assert.is_nil(f.color)
      assert.are.same({ [5] = true }, f.itemList)
      assert.is_true(categories:GetGeneration() > before)
      assert.are.same({ "categories/Changed" }, sent[1])
      assert.are.same({ "bags/Rederive", { resetLayout = true, buttons = true } }, sent[2])
    end)

    it("drops a rule set to nothing", function()
      dbCategories["Mats"] = { name = "Mats", itemList = {}, save = true, searchCategory = { query = "x" } }
      categories:UpdateCategory(context:New("Test"), "Mats", { rule = "  " })
      assert.is_nil(dbCategories["Mats"].searchCategory)
    end)

    it("keeps the bags, color and priority set for a plugin's category across its next creation", function()
      local ctx = context:New("Test")
      categories:CreateCategory(ctx, { name = "Openable", itemList = {}, priority = 1, color = { 0, 1, 0 } })
      categories:UpdateCategory(ctx, "Openable", { enabled = { [0] = false }, priority = 7, color = { 0, 0, 1 },
        rule = "ignored", groupBy = 2 })
      local live = categories:GetCategoryByName("Openable")
      assert.are.equal(7, live.priority)
      assert.is_false(live.enabled[const.BAG_KIND.BACKPACK])
      assert.is_nil(live.searchCategory, "a plugin's category keeps its own rule")
      -- The next session: the plugin makes it again with its own values.
      categories:Init()
      categories:CreateCategory(ctx, { name = "Openable", itemList = {}, priority = 1, color = { 0, 1, 0 } })
      live = categories:GetCategoryByName("Openable")
      assert.are.equal(7, live.priority)
      assert.are.same({ 0, 0, 1 }, live.color)
      assert.is_false(live.enabled[const.BAG_KIND.BACKPACK])
    end)

    it("says when there is no such category", function()
      assert.is_false(categories:UpdateCategory(context:New("Test"), "Nope", { priority = 1 }))
      assert.are.same({}, sent)
    end)
  end)

  describe("AddPermanentItemToCategory", function()
    it("files the item in the saved category, which still reports its bags", function()
      local ctx = context:New("Test")
      _G.C_Item = _G.C_Item or {}
      local savedInstant = C_Item.GetItemInfoInstant
      C_Item.GetItemInfoInstant = function() return 5 end
      dbCategories["Mats"] = { name = "Mats", itemList = {}, save = true, enabled = { [0] = true, [1] = false, [2] = true } }
      categories:AddPermanentItemToCategory(ctx, 5, "Mats")
      C_Item.GetItemInfoInstant = savedInstant
      assert.is_true(dbCategories["Mats"].itemList[5])
      assert.is_true(categories:IsCategoryEnabled(const.BAG_KIND.BACKPACK, "Mats"))
      assert.is_false(categories:IsCategoryEnabled(const.BAG_KIND.BANK, "Mats"))
    end)
  end)

  -- ─── Search categories ─────────────────────────────────────────────────────

  describe("Search categories", function()

    it("GetAllSearchCategories filters to search categories only", function()
      dbCategories["Regular"] = {name = "Regular", itemList = {}}
      dbCategories["Search"] = {name = "Search", itemList = {}, searchCategory = {query = "rarity >= 4"}}

      local results = categories:GetAllSearchCategories()
      assert.is_nil(results["Regular"])
      assert.is_not_nil(results["Search"])
    end)

    it("GetSortedSearchCategories sorts by priority ascending", function()
      dbCategories["Low"] = {name = "Low", itemList = {}, searchCategory = {query = "a"}, priority = 1}
      dbCategories["High"] = {name = "High", itemList = {}, searchCategory = {query = "b"}, priority = 10}
      dbCategories["Default"] = {name = "Default", itemList = {}, searchCategory = {query = "c"}}

      local sorted = categories:GetSortedSearchCategories()
      assert.are.equal("Low", sorted[1].name)
      -- Default priority is 10, same as "High"
      assert.are.equal(3, #sorted)
    end)
  end)

  -- ─── RegisterCategoryFunction ───────────────────────────────────────────────

  describe("RegisterCategoryFunction", function()

    it("registers a category function", function()
      categories:RegisterCategoryFunction("test-func", function() return nil end)
      assert.is_not_nil(categories.categoryFunctions["test-func"])
    end)

    it("errors on duplicate registration", function()
      categories:RegisterCategoryFunction("unique", function() return nil end)
      assert.has_error(function()
        categories:RegisterCategoryFunction("unique", function() return nil end)
      end)
    end)

    it("clears itemsWithNoCategory cache on registration", function()
      categories.itemsWithNoCategory[1234] = true
      categories:RegisterCategoryFunction("clearer", function() return nil end)
      assert.is_nil(categories.itemsWithNoCategory[1234])
    end)
  end)

  -- ─── IsDynamicCategory ──────────────────────────────────────────────────────

  describe("IsDynamicCategory", function()

    it("returns false for persistent categories", function()
      dbCategories["Saved"] = {name = "Saved", itemList = {}}
      assert.is_false(categories:IsDynamicCategory("Saved"))
    end)

    it("returns true for dynamic ephemeral categories", function()
      local ctx = context:New("Test")
      categories:CreateCategory(ctx, {name = "Dyn", itemList = {}, dynamic = true})
      categories.ephemeralCategories["Dyn"].dynamic = true
      assert.is_true(categories:IsDynamicCategory("Dyn"))
    end)

    it("returns false for non-dynamic ephemeral categories", function()
      local ctx = context:New("Test")
      categories:CreateCategory(ctx, {name = "Static", itemList = {}})
      assert.is_false(categories:IsDynamicCategory("Static"))
    end)
  end)

  -- ─── WipeCategory ──────────────────────────────────────────────────────────

  describe("WipeCategory", function()

    it("clears item list from persistent category", function()
      dbCategories["Wipeable"] = {name = "Wipeable", itemList = {[1] = true, [2] = true}}
      local ctx = context:New("Test")
      categories:WipeCategory(ctx, "Wipeable")
      assert.same({}, dbCategories["Wipeable"].itemList)
    end)

    it("clears item list and ID references from ephemeral category", function()
      local ctx = context:New("Test")
      categories:CreateCategory(ctx, {name = "EphWipe", itemList = {[42] = true}})
      categories.ephemeralCategories["EphWipe"].itemList[42] = true
      categories.ephemeralCategoryByItemID[42] = categories.ephemeralCategories["EphWipe"]

      categories:WipeCategory(ctx, "EphWipe")
      assert.same({}, categories.ephemeralCategories["EphWipe"].itemList)
      assert.is_nil(categories.ephemeralCategoryByItemID[42])
    end)
  end)

  -- ─── GetCustomCategory ──────────────────────────────────────────────────────

  describe("GetCustomCategory", function()

    it("correctly clears itemsWithNoCategory cache after manual addition and removal", function()
      local ctx = context:New("Test")
      local itemID = 12345
      local mockItem = { itemInfo = { itemID = itemID } }
      local _

      -- Ensure it starts with no custom category (returns nil)
      -- This will populate the cache `self.itemsWithNoCategory[itemID] = true`
      local categoryName, priority = categories:GetCustomCategory(ctx, const.BAG_KIND.BACKPACK, mockItem)
      assert.is_nil(categoryName)
      assert.is_nil(priority)
      assert.is_true(categories.itemsWithNoCategory[itemID])

      -- Add it to a custom category
      categories:AddItemToCategory(ctx, itemID, "MyManualCategory")

      -- Assert that itemsWithNoCategory cache is cleared for this item
      assert.is_nil(categories.itemsWithNoCategory[itemID])

      -- Query it again. It should now return the category name "MyManualCategory"
      categoryName, _ = categories:GetCustomCategory(ctx, const.BAG_KIND.BACKPACK, mockItem)
      assert.are.equal("MyManualCategory", categoryName)

      -- Remove it from the custom category
      categories:RemoveItemFromCategory(itemID)

      -- Assert that itemsWithNoCategory cache is also cleared upon removal
      assert.is_nil(categories.itemsWithNoCategory[itemID])
    end)
  end)

  -- ─── RemoveItemFromCategory ──────────────────────────────────────────────────
  -- Issue #1079: an unscoped RemoveItemFromCategory(id) must not destroy the
  -- user's saved (persisted) category assignment as a side effect. A category
  -- name may be passed to scope the removal.
  describe("RemoveItemFromCategory", function()
    local ctx
    before_each(function()
      ctx = context:New("Test")
    end)

    it("unscoped removal leaves the user's persisted assignment intact", function()
      local itemID = 12345
      -- User hand-files the item into their own saved category.
      categories:AddPermanentItemToCategory(ctx, itemID, "UserCat")
      -- A plugin also files it into its own ephemeral category.
      categories:AddItemToCategory(ctx, itemID, "PluginCat")

      categories:RemoveItemFromCategory(itemID)

      -- Ephemeral (plugin) assignment is gone...
      assert.is_nil(categories.ephemeralCategoryByItemID[itemID])
      -- ...but the user's saved assignment survives.
      assert.are.equal("UserCat", database:GetItemCategoryByItemID(itemID).name)
    end)

    it("scoped removal of the ephemeral category leaves the persisted one intact", function()
      local itemID = 23456
      categories:AddPermanentItemToCategory(ctx, itemID, "UserCat")
      categories:AddItemToCategory(ctx, itemID, "PluginCat")

      categories:RemoveItemFromCategory(itemID, "PluginCat")

      assert.is_nil(categories.ephemeralCategoryByItemID[itemID])
      assert.are.equal("UserCat", database:GetItemCategoryByItemID(itemID).name)
    end)

    it("scoped removal of the persisted category deletes only that assignment", function()
      local itemID = 34567
      categories:AddPermanentItemToCategory(ctx, itemID, "UserCat")
      categories:AddItemToCategory(ctx, itemID, "PluginCat")

      categories:RemoveItemFromCategory(itemID, "UserCat")

      -- The persisted assignment is gone...
      assert.are.equal(nil, database:GetItemCategoryByItemID(itemID).name)
      -- ...but the plugin's ephemeral assignment is untouched.
      assert.is_not_nil(categories.ephemeralCategoryByItemID[itemID])
      assert.are.equal("PluginCat", categories.ephemeralCategoryByItemID[itemID].name)
    end)

    it("scoped removal of a non-matching category touches nothing", function()
      local itemID = 45678
      categories:AddPermanentItemToCategory(ctx, itemID, "UserCat")
      categories:AddItemToCategory(ctx, itemID, "PluginCat")

      categories:RemoveItemFromCategory(itemID, "SomeOtherCategory")

      assert.are.equal("UserCat", database:GetItemCategoryByItemID(itemID).name)
      assert.is_not_nil(categories.ephemeralCategoryByItemID[itemID])
      assert.are.equal("PluginCat", categories.ephemeralCategoryByItemID[itemID].name)
    end)

    it("unscoped removal still clears the itemsWithNoCategory marker", function()
      local itemID = 56789
      local mockItem = { itemInfo = { itemID = itemID } }
      -- Populate the no-category cache.
      categories:GetCustomCategory(ctx, const.BAG_KIND.BACKPACK, mockItem)
      assert.is_true(categories.itemsWithNoCategory[itemID])

      categories:RemoveItemFromCategory(itemID)
      assert.is_nil(categories.itemsWithNoCategory[itemID])
    end)
  end)

  -- Categories are applied by the data phase, so a category change recalculates the bags
  -- from the items already read (refresh-scheduler.md §10), with a fresh layout and redrawn
  -- buttons as the old full refresh had.
  describe("refreshes", function()
    local sent, savedSend

    -- Earlier spec files patch the shared Events module's SendMessage without restoring it,
    -- so the messages are captured at SendMessage itself.
    before_each(function()
      sent = {}
      savedSend = events.SendMessage
      events.SendMessage = function(_, _, message, options)
        if message:match("^bags/") then
          table.insert(sent, { message = message, options = options })
        end
      end
    end)

    after_each(function()
      events.SendMessage = savedSend
    end)

    local function assertRecalculated()
      assert.is_true(#sent > 0, "a refresh was requested")
      for _, s in ipairs(sent) do
        assert.equal("bags/Rederive", s.message)
        assert.same({ resetLayout = true, buttons = true }, s.options)
      end
    end

    it("recalculates after a category is deleted", function()
      dbCategories["Gone"] = {name = "Gone", itemList = {}}
      categories:DeleteCategory(context:New("Test"), "Gone")
      assertRecalculated()
    end)

    it("recalculates after a category is renamed", function()
      dbCategories["Before"] = {name = "Before", itemList = {}, save = true}
      categories:RenameCategory(context:New("Test"), "Before", "After")
      assertRecalculated()
    end)

    it("asks for nothing when a plugin hides, shows or toggles a section (retired)", function()
      local ctx = context:New("Test")
      categories:HideCategory(ctx, "Shy")
      categories:ShowCategory(ctx, "Shy")
      categories:ToggleCategoryShown(ctx, "Shy")
      assert.are.same({}, sent)
    end)

    it("recalculates when every item is reprocessed", function()
      categories:ReprocessAllItems(context:New("Test"))
      assertRecalculated()
    end)
  end)
end)
