-- categories_spec.lua -- Unit tests for data/categories.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Dependencies
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")

local context = addon:GetModule("Context")
local events = addon:GetModule("Events")
events:OnInitialize()

local debug = StubBetterBagsModule("Debug")
debug.Log = function() end
debug.Inspect = function() end

local const = StubBetterBagsModule("Constants")
const.BAG_KIND = { BACKPACK = 0, BANK = 1 }

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
database.CreateOrUpdateCategory = function(_, category)
  if category.save then
    dbCategories[category.name] = category
  else
    dbEphemeralCategories[category.name] = category
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
database.GetCategoryOptions = function(_, name)
  dbCategoryOptions[name] = dbCategoryOptions[name] or {shown = true}
  return dbCategoryOptions[name]
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
    categories:OnInitialize()
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

    it("sets default enabled state for both bag kinds", function()
      local ctx = context:New("Test")
      categories:CreateCategory(ctx, {
        name = "Test",
        itemList = {},
        save = true,
      })
      assert.is_true(dbCategories["Test"].enabled[const.BAG_KIND.BACKPACK])
      assert.is_true(dbCategories["Test"].enabled[const.BAG_KIND.BANK])
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

  describe("Category visibility", function()

    it("IsCategoryShown returns true by default", function()
      assert.is_true(categories:IsCategoryShown("AnyCategory"))
    end)

    it("HideCategory sets shown to false", function()
      local ctx = context:New("Test")
      categories:HideCategory(ctx, "Hidden")
      assert.is_false(categories:IsCategoryShown("Hidden"))
    end)

    it("ShowCategory sets shown to true", function()
      local ctx = context:New("Test")
      categories:HideCategory(ctx, "Toggle")
      categories:ShowCategory(ctx, "Toggle")
      assert.is_true(categories:IsCategoryShown("Toggle"))
    end)

    it("ToggleCategoryShown flips visibility", function()
      local ctx = context:New("Test")
      assert.is_true(categories:IsCategoryShown("Flip"))
      categories:ToggleCategoryShown(ctx, "Flip")
      assert.is_false(categories:IsCategoryShown("Flip"))
      categories:ToggleCategoryShown(ctx, "Flip")
      assert.is_true(categories:IsCategoryShown("Flip"))
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
end)
