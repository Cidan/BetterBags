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
-- As the real one (DB:SaveItemToCategory): an item has one home, so it leaves the category it was in.
database.SaveItemToCategory = function(_, id, name)
  for other, cat in pairs(dbCategories) do
    if other ~= name and cat.itemList then cat.itemList[id] = nil end
  end
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
      color = saved and saved.color, priority = saved and saved.priority, automation = saved and saved.automation,
      confirmSale = saved and saved.confirmSale, skipRecent = saved and saved.skipRecent,
      ignoredItems = saved and saved.ignoredItems, hidden = saved and saved.hidden,
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
        IgnoreItem = function() categories:IgnoreItem(ctx, 101, "Gems") end,
        UnignoreItem = function() categories:UnignoreItem(ctx, 101, "Gems") end,
        ClearIgnoredItems = function() categories:ClearIgnoredItems(ctx, "Gems") end,
      }
      for _, name in ipairs({ "CreateCategory", "AddItemToCategory", "AddPermanentItemToCategory",
        "RemoveItemFromCategory", "WipeCategory", "ToggleCategory", "EnableCategory", "DisableCategory",
        "SetCategoryState", "RegisterCategoryFunction", "IgnoreItem", "UnignoreItem", "ClearIgnoredItems",
        "UpdateCategory", "RenameCategory", "DeleteCategory", "ReprocessAllItems" }) do
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

    -- What a category does on its own (automation.md) changes no item's category: the bags are not
    -- recalculated for it.
    it("sets a category's automation without recalculating the bags", function()
      dbCategories["Mats"] = { name = "Mats", itemList = {}, save = true }
      assert.is_true(categories:UpdateCategory(context:New("Test"), "Mats", { automation = "sell" }))
      assert.are.equal("sell", dbCategories["Mats"].automation)
      assert.are.same({ { "categories/Changed" } }, sent)
      categories:UpdateCategory(context:New("Test"), "Mats", { automation = false })
      assert.is_nil(dbCategories["Mats"].automation)
      sent = {}
      categories:UpdateCategory(context:New("Test"), "Mats", { automation = "destroy", priority = 4 })
      assert.are.same({ "bags/Rederive", { resetLayout = true, buttons = true } }, sent[2], "with another change")
    end)

    it("keeps the automation set for a plugin's category across its next creation", function()
      local ctx = context:New("Test")
      categories:CreateCategory(ctx, { name = "Openable", itemList = {}, priority = 1 })
      categories:UpdateCategory(ctx, "Openable", { automation = "destroy" })
      assert.are.equal("destroy", categories:GetCategoryByName("Openable").automation)
      categories:Init()
      categories:CreateCategory(ctx, { name = "Openable", itemList = {}, priority = 1, automation = "sell" })
      assert.are.equal("destroy", categories:GetCategoryByName("Openable").automation, "the player's choice wins")
    end)

    -- Asked: "Confirm autosell", a toggle that defaults to on (automation.md §3).
    it("turns confirming a category's sale off and on, keeping only off, without recalculating the bags", function()
      dbCategories["Mats"] = { name = "Mats", itemList = {}, save = true, automation = "sell" }
      categories:UpdateCategory(context:New("Test"), "Mats", { confirmSale = false })
      assert.is_false(dbCategories["Mats"].confirmSale)
      assert.are.same({ { "categories/Changed" } }, sent)
      categories:UpdateCategory(context:New("Test"), "Mats", { confirmSale = true })
      assert.is_nil(dbCategories["Mats"].confirmSale, "on is the default")
      assert.are.same({ { "categories/Changed" }, { "categories/Changed" } }, sent)
    end)

    it("keeps a plugin's confirming across its next creation and a move in the order", function()
      local ctx = context:New("Test")
      categories:CreateCategory(ctx, { name = "Openable", itemList = {}, priority = 1 })
      categories:UpdateCategory(ctx, "Openable", { automation = "sell", confirmSale = false })
      assert.is_false(dbEphemeralCategories["Openable"].confirmSale)
      dbCategories["Mats"] = { name = "Mats", itemList = {}, save = true, priority = 5 }
      categories:MoveCategory(ctx, "Openable", "Mats")
      assert.is_false(dbEphemeralCategories["Openable"].confirmSale, "a move keeps it")
      categories:Init()
      categories:CreateCategory(ctx, { name = "Openable", itemList = {}, priority = 1 })
      assert.is_false(categories:GetCategoryByName("Openable").confirmSale, "the player's choice wins")
    end)

    -- Asked: "Skip Recent Items" (docs/next-batch-2.md §1). It changes which items show in Recent
    -- Items, so the bags are recalculated.
    it("turns skipping Recent Items on and off, keeping only on, and recalculates the bags", function()
      dbCategories["Mats"] = { name = "Mats", itemList = {}, save = true }
      categories:UpdateCategory(context:New("Test"), "Mats", { skipRecent = true })
      assert.is_true(dbCategories["Mats"].skipRecent)
      assert.are.same({ "bags/Rederive", { resetLayout = true, buttons = true } }, sent[2])
      sent = {}
      categories:UpdateCategory(context:New("Test"), "Mats", { skipRecent = false })
      assert.is_nil(dbCategories["Mats"].skipRecent, "off is the default")
      assert.are.equal(2, #sent)
    end)

    -- Asked (issue #1222): hiding a category is back, per bag, for players without tabs.
    it("hides it in the bags named, keeping only what is on, and recalculates the bags", function()
      dbCategories["Mats"] = { name = "Mats", itemList = {}, save = true }
      categories:UpdateCategory(context:New("Test"), "Mats", { hidden = { [const.BAG_KIND.BANK] = true } })
      assert.are.same({ [const.BAG_KIND.BANK] = true }, dbCategories["Mats"].hidden)
      assert.are.same({ "bags/Rederive", { resetLayout = true, buttons = true } }, sent[2])
      categories:UpdateCategory(context:New("Test"), "Mats", { hidden = { [const.BAG_KIND.BACKPACK] = true } })
      assert.are.same({ [const.BAG_KIND.BANK] = true, [const.BAG_KIND.BACKPACK] = true }, dbCategories["Mats"].hidden)
      categories:UpdateCategory(context:New("Test"), "Mats", { hidden = { [const.BAG_KIND.BANK] = false } })
      assert.are.same({ [const.BAG_KIND.BACKPACK] = true }, dbCategories["Mats"].hidden)
      categories:UpdateCategory(context:New("Test"), "Mats", { hidden = { [const.BAG_KIND.BACKPACK] = false } })
      assert.is_nil(dbCategories["Mats"].hidden, "shown everywhere is the default")
    end)

    it("says whether a category is hidden in a bag, a group by's sections as their category is", function()
      local ctx = context:New("Test")
      dbCategories["Ore"] = { name = "Ore", itemList = {}, save = true, hidden = { [const.BAG_KIND.BANK] = true } }
      dbCategories["Mats"] = { name = "Mats", itemList = {}, save = true }
      categories:CreateCategory(ctx, { name = "Ore - Copper", itemList = {}, dynamic = true,
        isGroupBySubcategory = true, groupByParent = "Ore" })
      assert.is_true(categories:HiddenIn("Ore", const.BAG_KIND.BANK))
      assert.is_false(categories:HiddenIn("Ore", const.BAG_KIND.BACKPACK))
      assert.is_true(categories:HiddenIn("Ore - Copper", const.BAG_KIND.BANK))
      assert.is_false(categories:HiddenIn("Mats", const.BAG_KIND.BANK))
      assert.is_false(categories:HiddenIn("Armor", const.BAG_KIND.BANK), "a built-in category has none")
    end)

    it("keeps a plugin's hidden bags across its next creation", function()
      local ctx = context:New("Test")
      categories:CreateCategory(ctx, { name = "Openable", itemList = {}, priority = 1 })
      categories:UpdateCategory(ctx, "Openable", { hidden = { [const.BAG_KIND.BANK] = true } })
      assert.are.same({ [const.BAG_KIND.BANK] = true }, dbEphemeralCategories["Openable"].hidden)
      categories:Init()
      categories:CreateCategory(ctx, { name = "Openable", itemList = {}, priority = 1 })
      assert.are.same({ [const.BAG_KIND.BANK] = true }, categories:GetCategoryByName("Openable").hidden)
    end)

    it("keeps a plugin's Skip Recent Items across its next creation", function()
      local ctx = context:New("Test")
      categories:CreateCategory(ctx, { name = "Openable", itemList = {}, priority = 1 })
      categories:UpdateCategory(ctx, "Openable", { skipRecent = true })
      assert.is_true(dbEphemeralCategories["Openable"].skipRecent)
      categories:Init()
      categories:CreateCategory(ctx, { name = "Openable", itemList = {}, priority = 1 })
      assert.is_true(categories:GetCategoryByName("Openable").skipRecent)
    end)

    it("says when there is no such category", function()
      assert.is_false(categories:UpdateCategory(context:New("Test"), "Nope", { priority = 1 }))
      assert.are.same({}, sent)
    end)
  end)

  describe("AutomationOf", function()
    it("gives a category's automation, a group by's sections their category's", function()
      local ctx = context:New("Test")
      dbCategories["Mats"] = { name = "Mats", itemList = {}, save = true, automation = "sell" }
      dbCategories["Plain"] = { name = "Plain", itemList = {}, save = true }
      categories:CreateCategory(ctx, { name = "Mats - Cloth", itemList = {}, dynamic = true,
        isGroupBySubcategory = true, groupByParent = "Mats" })
      assert.are.equal("sell", categories:AutomationOf("Mats"))
      assert.are.equal("sell", categories:AutomationOf("Mats - Cloth"))
      assert.is_nil(categories:AutomationOf("Plain"))
      assert.is_nil(categories:AutomationOf("Armor"), "a built-in category has none")
    end)

    it("skips Recent Items when turned on, a group by's sections as their category does", function()
      local ctx = context:New("Test")
      dbCategories["Ore"] = { name = "Ore", itemList = {}, save = true, skipRecent = true }
      dbCategories["Mats"] = { name = "Mats", itemList = {}, save = true }
      categories:CreateCategory(ctx, { name = "Ore - Copper", itemList = {}, dynamic = true,
        isGroupBySubcategory = true, groupByParent = "Ore" })
      assert.is_true(categories:SkipsRecentOf("Ore"))
      assert.is_true(categories:SkipsRecentOf("Ore - Copper"))
      assert.is_false(categories:SkipsRecentOf("Mats"))
      assert.is_false(categories:SkipsRecentOf("Armor"), "a built-in category has none")
      assert.is_false(categories:SkipsRecentOf("Recent Items"))
    end)

    it("confirms a sale unless turned off, a group by's sections as their category does", function()
      local ctx = context:New("Test")
      dbCategories["Mats"] = { name = "Mats", itemList = {}, save = true, automation = "sell" }
      dbCategories["Ore"] = { name = "Ore", itemList = {}, save = true, automation = "sell", confirmSale = false }
      categories:CreateCategory(ctx, { name = "Ore - Copper", itemList = {}, dynamic = true,
        isGroupBySubcategory = true, groupByParent = "Ore" })
      assert.is_true(categories:ConfirmsSaleOf("Mats"))
      assert.is_false(categories:ConfirmsSaleOf("Ore"))
      assert.is_false(categories:ConfirmsSaleOf("Ore - Copper"))
      assert.is_true(categories:ConfirmsSaleOf("Armor"))
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

    -- Ties are alphabetical, as the Categories list shows them (asked), not left to the sort.
    it("GetSortedSearchCategories breaks ties by name, ignoring case", function()
      for _, spec in ipairs({ { "beta", 10 }, { "Alpha", 10 }, { "Gamma", 5 }, { "alpha2", 10 } }) do
        dbCategories[spec[1]] = { name = spec[1], itemList = {}, searchCategory = { query = "x" }, priority = spec[2] }
      end
      local names = {}
      for i, filter in ipairs(categories:GetSortedSearchCategories()) do names[i] = filter.name end
      assert.are.same({ "Gamma", "Alpha", "alpha2", "beta" }, names)
    end)
  end)

  -- The order of the Categories list is the categories' priority (category-lifecycle.md §7): a
  -- category higher up wins an item that fits more than one. The number is kept underneath, never shown.
  describe("the order", function()
    local sent, savedSend

    before_each(function()
      sent = {}
      savedSend = events.SendMessage
      events.SendMessage = function(_, _, message, ...) table.insert(sent, { message, ... }) end
    end)

    after_each(function()
      events.SendMessage = savedSend
    end)

    local function saved(name, priority, extra)
      dbCategories[name] = { name = name, itemList = {}, save = true, priority = priority,
        enabled = { [0] = true, [1] = true, [2] = true } }
      for k, v in pairs(extra or {}) do dbCategories[name][k] = v end
    end

    -- A plugin's category seen in an earlier session (its saved state exists).
    local function known(name, priority, savedPriority)
      dbEphemeralCategories[name] = { name = name, enabled = { [0] = true, [1] = true, [2] = true },
        itemList = {}, priority = savedPriority }
      categories:CreateCategory(context:New("Test"), { name = name, itemList = {}, priority = priority })
    end

    local function messages()
      local list = {}
      for _, m in ipairs(sent) do table.insert(list, m[1]) end
      return list
    end

    it("lists every category but a group by's sections, by priority, then by name ignoring case", function()
      saved("Mats", 5)
      saved("Potions", 10)
      saved("apples", 10)
      saved("Zinc")
      known("Openable", 1, 3)
      known("Mats - Cloth", 5)
      categories:GetCategoryByName("Mats - Cloth").isGroupBySubcategory = true
      assert.are.same({ "Openable", "Mats", "apples", "Potions", "Zinc" }, categories:GetOrder())
    end)

    -- Asked: "newest on top".
    it("puts a new category of yours on top", function()
      saved("Mats", 5)
      saved("Gems", 2)
      categories:CreateCategory(context:New("Test"), { name = "New", itemList = {}, save = true })
      assert.are.equal("New", categories:GetOrder()[1])
      assert.is_true(dbCategories["New"].priority < 2)
      categories:CreateCategory(context:New("Test"), { name = "Newer", itemList = {}, save = true })
      assert.are.same({ "Newer", "New", "Gems", "Mats" }, categories:GetOrder())
    end)

    it("leaves a category of yours made again where it was", function()
      saved("Mats", 5)
      saved("Gems", 2)
      categories:CreateCategory(context:New("Test"), dbCategories["Mats"])
      assert.are.same({ "Gems", "Mats" }, categories:GetOrder())
    end)

    it("puts a plugin's category seen for the first time on top, and keeps it there next session", function()
      saved("Mats", 5)
      categories:CreateCategory(context:New("Test"), { name = "Plug", itemList = {}, priority = 50 })
      assert.are.same({ "Plug", "Mats" }, categories:GetOrder())
      assert.are.equal(categories:GetCategoryByName("Plug").priority, dbEphemeralCategories["Plug"].priority,
        "its place is saved")
      categories:Init()
      categories:CreateCategory(context:New("Test"), { name = "Plug", itemList = {}, priority = 50 })
      assert.are.same({ "Plug", "Mats" }, categories:GetOrder())
    end)

    it("keeps a plugin's category it saw before where its own priority puts it, until the player moves it", function()
      saved("Mats", 5)
      saved("Gems", 9)
      known("Known", 7)
      assert.are.same({ "Mats", "Known", "Gems" }, categories:GetOrder())
    end)

    it("never puts a group by's section on top", function()
      saved("Mats", 5)
      saved("Gems", 2)
      categories:CreateCategory(context:New("Test"), { name = "Mats - Cloth", itemList = {}, dynamic = true,
        isGroupBySubcategory = true, groupByParent = "Mats", priority = 5 })
      assert.are.equal(5, categories:GetCategoryByName("Mats - Cloth").priority)
    end)

    it("moves a category after another, numbering every category from 1, once", function()
      saved("Mats", 5)
      saved("Potions", 10)
      saved("Zinc", 10)
      known("Openable", 1, 3)
      sent = {}
      assert.is_true(categories:MoveCategory(context:New("Test"), "Zinc", "Openable"))
      assert.are.same({ "Openable", "Zinc", "Mats", "Potions" }, categories:GetOrder())
      assert.are.same({ 1, 2, 3, 4 }, { categories:GetCategoryByName("Openable").priority, dbCategories["Zinc"].priority,
        dbCategories["Mats"].priority, dbCategories["Potions"].priority })
      assert.are.equal(1, dbEphemeralCategories["Openable"].priority, "a plugin's place is saved")
      assert.are.same({ "categories/Changed", "bags/Rederive" }, messages())
      assert.are.same({ resetLayout = true, buttons = true }, sent[2][2])
    end)

    it("moves a category to the top without one to follow", function()
      saved("Mats", 5)
      saved("Potions", 10)
      assert.is_true(categories:MoveCategory(context:New("Test"), "Potions", nil))
      assert.are.same({ "Potions", "Mats" }, categories:GetOrder())
    end)

    it("takes a group by's sections along with their category", function()
      saved("Mats", 5)
      saved("Potions", 10)
      known("Mats - Cloth", 5)
      local section = categories:GetCategoryByName("Mats - Cloth")
      section.isGroupBySubcategory, section.groupByParent = true, "Mats"
      categories:MoveCategory(context:New("Test"), "Mats", "Potions")
      assert.are.equal(dbCategories["Mats"].priority, section.priority)
      assert.are.equal(section.priority, dbEphemeralCategories["Mats - Cloth"].priority)
    end)

    it("changes nothing when the category lands where it was, or there is none", function()
      saved("Mats", 5)
      saved("Potions", 10)
      sent = {}
      assert.is_false(categories:MoveCategory(context:New("Test"), "Potions", "Mats"))
      assert.is_false(categories:MoveCategory(context:New("Test"), "Mats", nil))
      assert.is_false(categories:MoveCategory(context:New("Test"), "Nope", nil))
      assert.is_false(categories:MoveCategory(context:New("Test"), "Potions", "Nope"), "an anchor that is none")
      assert.are.same({ 5, 10 }, { dbCategories["Mats"].priority, dbCategories["Potions"].priority })
      assert.are.same({}, sent)
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

  -- Asked: "items in this are *ignored* from the category and never land in there under any
  -- circumstance, no matter if it's added in Added Items, or in a Search Filter" (docs/next-batch-2.md §2).
  describe("Ignored Items", function()
    local ctx
    before_each(function()
      ctx = context:New("Test")
    end)

    it("keeps an item added by hand out of the category, until no longer ignored", function()
      categories:CreateCategory(ctx, { name = "Mats", itemList = {}, save = true })
      categories:AddPermanentItemToCategory(ctx, 101, "Mats")
      local item = { itemInfo = { itemID = 101 } }
      assert.is_true(categories:IgnoreItem(ctx, 101, "Mats"))
      assert.is_true(categories:IgnoresItem("Mats", 101))
      assert.is_nil((categories:GetCustomCategory(ctx, 0, item)))
      assert.is_true(dbCategories["Mats"].itemList[101], "still added: ignoring wins")
      assert.is_true(dbCategories["Mats"].ignoredItems[101], "saved with the category")
      categories:UnignoreItem(ctx, 101, "Mats")
      assert.is_false(categories:IgnoresItem("Mats", 101))
      assert.is_nil(dbCategories["Mats"].ignoredItems, "none left: nothing stored")
      assert.are.equal("Mats", (categories:GetCustomCategory(ctx, 0, item)))
    end)

    it("keeps an item out of a plugin's list", function()
      categories:CreateCategory(ctx, { name = "Openable", itemList = { [202] = true } })
      local item = { itemInfo = { itemID = 202 } }
      assert.are.equal("Openable", (categories:GetCustomCategory(ctx, 0, item)))
      categories:IgnoreItem(ctx, 202, "Openable")
      assert.is_nil((categories:GetCustomCategory(ctx, 0, item)))
    end)

    it("keeps an item out of what a category function names, asking it once", function()
      categories:CreateCategory(ctx, { name = "Fish", itemList = {} })
      local asked = 0
      categories:RegisterCategoryFunction("fish", function()
        asked = asked + 1
        return "Fish"
      end)
      categories:IgnoreItem(ctx, 303, "Fish")
      local item = { itemInfo = { itemID = 303 } }
      assert.is_nil((categories:GetCustomCategory(ctx, 0, item)))
      assert.is_nil(categories:GetMergedCategory("Fish").itemList[303], "not filed there")
      assert.is_nil((categories:GetCustomCategory(ctx, 0, item)))
      assert.are.equal(1, asked, "remembered as having none")
      categories:UnignoreItem(ctx, 303, "Fish")
      assert.are.equal("Fish", (categories:GetCustomCategory(ctx, 0, item)))
    end)

    it("lets a category function name the items again once they are all no longer ignored", function()
      categories:CreateCategory(ctx, { name = "Fish", itemList = {} })
      categories:RegisterCategoryFunction("fish", function() return "Fish" end)
      categories:IgnoreItem(ctx, 303, "Fish")
      local item = { itemInfo = { itemID = 303 } }
      assert.is_nil((categories:GetCustomCategory(ctx, 0, item)))
      categories:ClearIgnoredItems(ctx, "Fish")
      assert.are.equal("Fish", (categories:GetCustomCategory(ctx, 0, item)))
    end)

    it("keeps a plugin's Ignored Items across its next creation", function()
      categories:CreateCategory(ctx, { name = "Openable", itemList = {}, priority = 1 })
      categories:IgnoreItem(ctx, 202, "Openable")
      assert.is_true(dbEphemeralCategories["Openable"].ignoredItems[202])
      categories:Init()
      categories:CreateCategory(ctx, { name = "Openable", itemList = {}, priority = 1 })
      assert.is_true(categories:IgnoresItem("Openable", 202))
    end)

    it("ignores for a group by's sections what their category ignores", function()
      dbCategories["Ore"] = { name = "Ore", itemList = {}, save = true, ignoredItems = { [101] = true } }
      categories:CreateCategory(ctx, { name = "Ore - Copper", itemList = {}, dynamic = true,
        isGroupBySubcategory = true, groupByParent = "Ore" })
      assert.is_true(categories:IgnoresItem("Ore - Copper", 101))
      assert.is_false(categories:IgnoresItem("Ore - Copper", 102))
      assert.is_false(categories:IgnoresItem("Armor", 101), "a built-in category ignores nothing")
    end)

    it("lists a copy of what a category ignores, and stops ignoring them all", function()
      categories:CreateCategory(ctx, { name = "Mats", itemList = {}, save = true })
      categories:IgnoreItem(ctx, 101, "Mats")
      categories:IgnoreItem(ctx, 102, "Mats")
      local list = categories:GetIgnoredItems("Mats")
      assert.are.same({ [101] = true, [102] = true }, list)
      list[103] = true
      assert.is_false(categories:IgnoresItem("Mats", 103))
      categories:ClearIgnoredItems(ctx, "Mats")
      assert.are.same({}, categories:GetIgnoredItems("Mats"))
      assert.are.same({}, categories:GetIgnoredItems("Nope"))
    end)

    it("says when there is no such category", function()
      assert.is_false(categories:IgnoreItem(ctx, 101, "Nope"))
      assert.is_false(categories:UnignoreItem(ctx, 101, "Nope"))
    end)
  end)

  -- Asked: "if you drag and drop an item onto a category header, it becomes an Added Item in that
  -- category ... if it would naturally fit there already ... don't add it to Added Items for that
  -- category, just strip it's manual assignment and let it land where it should" (docs/next-batch-2.md §8).
  describe("filing an item dropped on a category's header (FileItem)", function()
    local ctx
    before_each(function()
      ctx = context:New("Test")
      categories:CreateCategory(ctx, { name = "Mats", itemList = {}, save = true })
      categories:CreateCategory(ctx, { name = "Gems", itemList = {}, save = true })
      categories:CreateCategory(ctx, { name = "Ore", itemList = {}, save = true })
      categories:CreateCategory(ctx, { name = "Ore - Copper", itemList = {}, dynamic = true,
        isGroupBySubcategory = true, groupByParent = "Ore" })
      categories:CreateCategory(ctx, { name = "Openable", itemList = {} })
    end)

    local function homeOf(itemID)
      return database:GetItemCategoryByItemID(itemID).name
    end

    it("strips an item's manual assignment where it lands anyway, adding nothing", function()
      categories:AddPermanentItemToCategory(ctx, 101, "Mats")
      assert.are.equal("natural", categories:FileItem(ctx, 101, "Junk", "Junk"))
      assert.is_nil(homeOf(101))
      assert.is_nil(dbCategories["Junk"], "no category made")
      categories:AddPermanentItemToCategory(ctx, 102, "Gems")
      assert.are.equal("natural", categories:FileItem(ctx, 102, "Openable", "Openable"), "a plugin's too")
      assert.is_nil(homeOf(102))
      assert.are.equal("natural", categories:FileItem(ctx, 103, "Mats", "Mats"), "nothing to strip")
      assert.is_nil(dbCategories["Mats"].itemList[103])
    end)

    it("takes a group by's sections as their category, either side", function()
      categories:AddPermanentItemToCategory(ctx, 101, "Mats")
      assert.are.equal("natural", categories:FileItem(ctx, 101, "Ore - Copper", "Ore"))
      categories:AddPermanentItemToCategory(ctx, 101, "Mats")
      assert.are.equal("natural", categories:FileItem(ctx, 101, "Ore", "Ore - Copper"))
      assert.are.equal("added", categories:FileItem(ctx, 104, "Ore - Copper", "Junk"))
      assert.is_true(dbCategories["Ore"].itemList[104], "added to the category, not its section")
    end)

    it("adds an item that lands elsewhere to the category's Added Items, moving it from its last one", function()
      categories:AddPermanentItemToCategory(ctx, 101, "Gems")
      assert.are.equal("added", categories:FileItem(ctx, 101, "Mats", "Armor"))
      assert.are.equal("Mats", homeOf(101))
      assert.is_nil(dbCategories["Gems"].itemList[101])
      assert.are.equal("added", categories:FileItem(ctx, 105, "Mats", nil), "where it lands not known")
      assert.is_true(dbCategories["Mats"].itemList[105])
    end)

    it("stops the category ignoring an item dropped on it", function()
      categories:IgnoreItem(ctx, 106, "Mats")
      assert.are.equal("added", categories:FileItem(ctx, 106, "Mats", "Junk"))
      assert.is_false(categories:IgnoresItem("Mats", 106))
    end)

    -- The classic title's Shift drop did the same: a category of that name, which shows in its section.
    it("makes a category of a built-in category's name for an item that does not land there", function()
      assert.are.equal("added", categories:FileItem(ctx, 107, "Armor", "Junk"))
      assert.is_true(dbCategories["Armor"].save)
      assert.is_true(dbCategories["Armor"].itemList[107])
    end)

    it("adds nothing to a plugin's category the item does not land in", function()
      categories:AddPermanentItemToCategory(ctx, 108, "Mats")
      local before = categories:GetGeneration()
      assert.are.equal("plugin", categories:FileItem(ctx, 108, "Openable", "Junk"))
      assert.are.equal("Mats", homeOf(108), "left where it was")
      assert.is_nil(dbCategories["Openable"])
      assert.are.equal(before, categories:GetGeneration())
    end)
  end)

  describe("GetCustomCategory without the item's Added Items", function()
    it("passes over the category the item was added to by hand, a plugin's still counting", function()
      local ctx = context:New("Test")
      categories:CreateCategory(ctx, { name = "Mats", itemList = {}, save = true })
      categories:AddPermanentItemToCategory(ctx, 101, "Mats")
      local item = { itemInfo = { itemID = 101 } }
      assert.are.equal("Mats", (categories:GetCustomCategory(ctx, 0, item)))
      assert.is_nil((categories:GetCustomCategory(ctx, 0, item, true)))
      categories:CreateCategory(ctx, { name = "Openable", itemList = { [101] = true } })
      assert.are.equal("Openable", (categories:GetCustomCategory(ctx, 0, item, true)))
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
