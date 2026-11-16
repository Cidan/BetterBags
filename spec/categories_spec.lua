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
      confirmSale = saved and saved.confirmSale, deposit = saved and saved.deposit, skipRecent = saved and saved.skipRecent,
      ignoredItems = saved and saved.ignoredItems, hidden = saved and saved.hidden, itemOrder = saved and saved.itemOrder,
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

-- The Blizzard categories the bags' items have (Items:KnowsBlizzardCategory): none unless a test says so.
local itemsModule = StubBetterBagsModule("Items")
local knownBlizzard, savedKnows

describe("Categories", function()

  before_each(function()
    -- Reset database state
    for k in pairs(dbCategories) do dbCategories[k] = nil end
    for k in pairs(dbEphemeralCategories) do dbEphemeralCategories[k] = nil end
    for k in pairs(dbCategoryOptions) do dbCategoryOptions[k] = nil end
    knownBlizzard = {}
    savedKnows = rawget(itemsModule, "KnowsBlizzardCategory")
    itemsModule.KnowsBlizzardCategory = function(_, name) return knownBlizzard[name] == true end
    -- Re-initialize module
    categories:Init()
  end)

  after_each(function()
    itemsModule.KnowsBlizzardCategory = savedKnows
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

    -- Asked (#1280): Auto Deposit, where a category's items go when the bank opens. It changes no item's
    -- category, so the bags are not recalculated for it.
    it("sets where a category deposits its items without recalculating the bags", function()
      dbCategories["Mats"] = { name = "Mats", itemList = {}, save = true }
      assert.is_true(categories:UpdateCategory(context:New("Test"), "Mats", { deposit = "warbank" }))
      assert.are.equal("warbank", dbCategories["Mats"].deposit)
      assert.are.same({ { "categories/Changed" } }, sent)
      categories:UpdateCategory(context:New("Test"), "Mats", { deposit = false })
      assert.is_nil(dbCategories["Mats"].deposit)
      assert.are.same({ { "categories/Changed" }, { "categories/Changed" } }, sent)
      sent = {}
      categories:UpdateCategory(context:New("Test"), "Mats", { deposit = "bank", priority = 4 })
      assert.are.same({ "bags/Rederive", { resetLayout = true, buttons = true } }, sent[2], "with another change")
    end)

    it("keeps a plugin's Auto Deposit across its next creation and a move in the order", function()
      local ctx = context:New("Test")
      categories:CreateCategory(ctx, { name = "Openable", itemList = {}, priority = 1 })
      categories:UpdateCategory(ctx, "Openable", { deposit = "bank" })
      assert.are.equal("bank", dbEphemeralCategories["Openable"].deposit)
      dbCategories["Mats"] = { name = "Mats", itemList = {}, save = true, priority = 5 }
      -- The real database writes every field it is given, so what a move saves must hold the deposit too.
      local real, given = database.UpdateEphemeralItemCategory, nil
      database.UpdateEphemeralItemCategory = function(self, name, fields)
        given = fields
        return real(self, name, fields)
      end
      finally(function() database.UpdateEphemeralItemCategory = real end)
      categories:MoveCategory(ctx, "Openable", "Mats")
      assert.are.equal("bank", given.deposit, "a move keeps it")
      categories:Init()
      categories:CreateCategory(ctx, { name = "Openable", itemList = {}, priority = 1, deposit = "warbank" })
      assert.are.equal("bank", categories:GetCategoryByName("Openable").deposit, "the player's choice wins")
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
      dbCategories["Ore"] = { name = "Ore", itemList = {}, save = true, hidden = { [const.BAG_KIND.BANK] = true },
        enabled = { [0] = true, [1] = true, [2] = true } }
      dbCategories["Mats"] = { name = "Mats", itemList = {}, save = true, enabled = { [0] = true, [1] = true, [2] = true } }
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

    -- Asked (issue #108): "each category can have it's own sort order". It changes the order of its items, so
    -- the bags are recalculated, with a fresh layout.
    it("gives a category its own item order, a copy, and takes it away, recalculating the bags", function()
      dbCategories["Gear"] = { name = "Gear", itemList = {}, save = true }
      local order = { "equipmentSlot", "itemLevel" }
      categories:UpdateCategory(context:New("Test"), "Gear", { itemOrder = order })
      assert.are.same({ "equipmentSlot", "itemLevel" }, dbCategories["Gear"].itemOrder)
      order[1] = "name"
      assert.are.same({ "equipmentSlot", "itemLevel" }, dbCategories["Gear"].itemOrder, "a copy")
      assert.are.same({ "bags/Rederive", { resetLayout = true, buttons = true } }, sent[2])
      sent = {}
      categories:UpdateCategory(context:New("Test"), "Gear", { itemOrder = false })
      assert.is_nil(dbCategories["Gear"].itemOrder, "the bag's order is the default")
      assert.are.same({ "bags/Rederive", { resetLayout = true, buttons = true } }, sent[2])
    end)

    it("keeps a plugin's own item order across its next creation and a move in the order", function()
      local ctx = context:New("Test")
      categories:CreateCategory(ctx, { name = "Openable", itemList = {}, priority = 1 })
      categories:UpdateCategory(ctx, "Openable", { itemOrder = { "count" } })
      assert.are.same({ "count" }, dbEphemeralCategories["Openable"].itemOrder)
      dbCategories["Mats"] = { name = "Mats", itemList = {}, save = true, priority = 5 }
      local real, given = database.UpdateEphemeralItemCategory, nil
      database.UpdateEphemeralItemCategory = function(self, name, fields)
        given = fields
        return real(self, name, fields)
      end
      finally(function() database.UpdateEphemeralItemCategory = real end)
      categories:MoveCategory(ctx, "Openable", "Mats")
      assert.are.same({ "count" }, given.itemOrder, "a move keeps it")
      categories:Init()
      categories:CreateCategory(ctx, { name = "Openable", itemList = {}, priority = 1 })
      assert.are.same({ "count" }, categories:GetCategoryByName("Openable").itemOrder)
    end)

    it("says when there is no such category", function()
      assert.is_false(categories:UpdateCategory(context:New("Test"), "Nope", { priority = 1 }))
      assert.are.same({}, sent)
    end)
  end)

  describe("AutomationOf", function()
    local BACKPACK = const.BAG_KIND.BACKPACK
    local function everywhere()
      return { [0] = true, [1] = true, [2] = true }
    end

    it("gives a category's automation, a group by's sections their category's", function()
      local ctx = context:New("Test")
      dbCategories["Mats"] = { name = "Mats", itemList = {}, save = true, automation = "sell", enabled = everywhere() }
      dbCategories["Plain"] = { name = "Plain", itemList = {}, save = true, enabled = everywhere() }
      categories:CreateCategory(ctx, { name = "Mats - Cloth", itemList = {}, dynamic = true,
        isGroupBySubcategory = true, groupByParent = "Mats" })
      assert.are.equal("sell", categories:AutomationOf("Mats", BACKPACK))
      assert.are.equal("sell", categories:AutomationOf("Mats - Cloth", BACKPACK))
      assert.is_nil(categories:AutomationOf("Plain", BACKPACK))
      assert.is_nil(categories:AutomationOf("Armor", BACKPACK), "a built-in category has none")
    end)

    it("skips Recent Items when turned on, a group by's sections as their category does", function()
      local ctx = context:New("Test")
      dbCategories["Ore"] = { name = "Ore", itemList = {}, save = true, skipRecent = true, enabled = everywhere() }
      dbCategories["Mats"] = { name = "Mats", itemList = {}, save = true, enabled = everywhere() }
      categories:CreateCategory(ctx, { name = "Ore - Copper", itemList = {}, dynamic = true,
        isGroupBySubcategory = true, groupByParent = "Ore" })
      assert.is_true(categories:SkipsRecentOf("Ore", BACKPACK))
      assert.is_true(categories:SkipsRecentOf("Ore - Copper", BACKPACK))
      assert.is_false(categories:SkipsRecentOf("Mats", BACKPACK))
      assert.is_false(categories:SkipsRecentOf("Armor", BACKPACK), "a built-in category has none")
      assert.is_false(categories:SkipsRecentOf("Recent Items", BACKPACK))
    end)

    it("gives a category's own item order, a group by's sections their category's, none for the others", function()
      local ctx = context:New("Test")
      dbCategories["Gear"] = { name = "Gear", itemList = {}, save = true, itemOrder = { "itemLevel" }, enabled = everywhere() }
      dbCategories["Mats"] = { name = "Mats", itemList = {}, save = true, enabled = everywhere() }
      categories:CreateCategory(ctx, { name = "Gear - Plate", itemList = {}, dynamic = true,
        isGroupBySubcategory = true, groupByParent = "Gear" })
      assert.are.same({ "itemLevel" }, categories:ItemOrderOf("Gear", BACKPACK))
      assert.are.same({ "itemLevel" }, categories:ItemOrderOf("Gear - Plate", BACKPACK))
      assert.is_nil(categories:ItemOrderOf("Mats", BACKPACK))
      assert.is_nil(categories:ItemOrderOf("Armor", BACKPACK), "a built-in category has none")
      assert.is_nil(categories:ItemOrderOf("Recent Items", BACKPACK))
    end)

    it("says whether a category a bag uses has its own item order", function()
      dbCategories["Mats"] = { name = "Mats", itemList = {}, save = true, enabled = everywhere() }
      assert.is_false(categories:HasItemOrders(BACKPACK))
      dbCategories["Gear"] = { name = "Gear", itemList = {}, save = true, itemOrder = { "itemLevel" },
        enabled = { [0] = false, [1] = true, [2] = true } }
      assert.is_false(categories:HasItemOrders(BACKPACK), "not one the backpack uses")
      assert.is_true(categories:HasItemOrders(1))
      categories:CreateCategory(context:New("Test"), { name = "Openable", itemList = {}, priority = 1 })
      categories:UpdateCategory(context:New("Test"), "Openable", { itemOrder = { "count" } })
      assert.is_true(categories:HasItemOrders(BACKPACK), "a plugin's too")
    end)

    it("confirms a sale unless turned off, a group by's sections as their category does", function()
      local ctx = context:New("Test")
      dbCategories["Mats"] = { name = "Mats", itemList = {}, save = true, automation = "sell", enabled = everywhere() }
      dbCategories["Ore"] = { name = "Ore", itemList = {}, save = true, automation = "sell", confirmSale = false,
        enabled = everywhere() }
      categories:CreateCategory(ctx, { name = "Ore - Copper", itemList = {}, dynamic = true,
        isGroupBySubcategory = true, groupByParent = "Ore" })
      assert.is_true(categories:ConfirmsSaleOf("Mats", BACKPACK))
      assert.is_false(categories:ConfirmsSaleOf("Ore", BACKPACK))
      assert.is_false(categories:ConfirmsSaleOf("Ore - Copper", BACKPACK))
      assert.is_true(categories:ConfirmsSaleOf("Armor", BACKPACK))
    end)

    it("deposits where its category does, a group by's sections as their category does", function()
      local ctx = context:New("Test")
      dbCategories["Ore"] = { name = "Ore", itemList = {}, save = true, deposit = "warbank", enabled = everywhere() }
      dbCategories["Mats"] = { name = "Mats", itemList = {}, save = true, enabled = everywhere() }
      categories:CreateCategory(ctx, { name = "Ore - Copper", itemList = {}, dynamic = true,
        isGroupBySubcategory = true, groupByParent = "Ore" })
      assert.are.equal("warbank", categories:DepositOf("Ore", BACKPACK))
      assert.are.equal("warbank", categories:DepositOf("Ore - Copper", BACKPACK))
      assert.is_nil(categories:DepositOf("Mats", BACKPACK))
      assert.is_nil(categories:DepositOf("Armor", BACKPACK), "a built-in category has none")
    end)

    -- Asked (issue #1278): "we don't want dual behavior for options". A category of yours named like a Blizzard
    -- category, turned off in a bag, leaves that bag's section of its name to Blizzard: none of its settings apply there.
    it("does nothing in a bag that does not use the category", function()
      dbCategories["Junk"] = { name = "Junk", itemList = {}, save = true, blizzard = true, automation = "sell",
        confirmSale = false, deposit = "bank", skipRecent = true, hidden = { [0] = true, [1] = true },
        itemOrder = { "sellPriceStack" }, enabled = { [0] = false, [1] = true, [2] = true } }
      assert.is_nil(categories:AutomationOf("Junk", 0))
      assert.is_true(categories:ConfirmsSaleOf("Junk", 0))
      assert.is_nil(categories:DepositOf("Junk", 0))
      assert.is_false(categories:SkipsRecentOf("Junk", 0))
      assert.is_false(categories:HiddenIn("Junk", 0))
      assert.is_nil(categories:ItemOrderOf("Junk", 0))
      assert.are.equal("sell", categories:AutomationOf("Junk", 1))
      assert.is_false(categories:ConfirmsSaleOf("Junk", 1))
      assert.are.equal("bank", categories:DepositOf("Junk", 1))
      assert.is_true(categories:SkipsRecentOf("Junk", 1))
      assert.is_true(categories:HiddenIn("Junk", 1))
      assert.are.same({ "sellPriceStack" }, categories:ItemOrderOf("Junk", 1))
    end)
  end)

  -- CategoryIn is the one place a section's name finds the category whose settings it takes in a bag (its color, Hide
  -- In, what it does on its own, the items it ignores).
  describe("CategoryIn", function()
    it("is the category of that name where a bag uses it, a group by's section its category's, none elsewhere", function()
      local ctx = context:New("Test")
      dbCategories["Ore"] = { name = "Ore", itemList = {}, save = true, enabled = { [0] = true, [1] = false, [2] = true } }
      categories:CreateCategory(ctx, { name = "Ore - Copper", itemList = {}, dynamic = true, isGroupBySubcategory = true,
        groupByParent = "Ore", enabled = { [0] = true, [1] = true, [2] = true } })
      categories:CreateCategory(ctx, { name = "Openable", itemList = {}, enabled = { [0] = false, [1] = true, [2] = true } })
      assert.are.equal(dbCategories["Ore"], categories:CategoryIn("Ore", 0))
      assert.is_nil(categories:CategoryIn("Ore", 1), "a bag that does not use it")
      assert.are.equal(dbCategories["Ore"], categories:CategoryIn("Ore - Copper", 0))
      assert.is_nil(categories:CategoryIn("Ore - Copper", 1), "its category's bags, not its own")
      assert.is_nil(categories:CategoryIn("Openable", 0))
      assert.are.equal("Openable", categories:CategoryIn("Openable", 1).name)
      assert.is_nil(categories:CategoryIn("Armor", 0), "a Blizzard category has none")
    end)
  end)

  -- Asked (issue #1278): Blizzard's categories can be made yours: "convert them to managed categories ... blizzard items
  -- will still appear in the category, but custom changes can also be made to them". One made yours never groups ("i
  -- don't think it makes sense to group by on blizzard categories"), and renaming it makes a new category.
  describe("Blizzard categories made yours (Convert)", function()
    local ctx
    before_each(function()
      ctx = context:New("Test")
    end)

    it("makes a category of yours of a Blizzard category's name, made from it, on top, used in every bag", function()
      categories:CreateCategory(ctx, { name = "Mats", itemList = {}, save = true, priority = 3 })
      assert.is_true(categories:Convert(ctx, "Armor - Cloth"))
      local made = dbCategories["Armor - Cloth"]
      assert.is_true(made.save)
      assert.is_true(made.blizzard)
      assert.are.same({}, made.itemList)
      assert.is_nil(made.searchCategory)
      assert.is_nil(made.groupBy)
      assert.are.same({ [0] = true, [1] = true, [2] = true }, made.enabled)
      assert.are.equal("Armor - Cloth", categories:GetOrder()[1])
    end)

    it("makes nothing of a name a category has", function()
      categories:CreateCategory(ctx, { name = "Mats", itemList = {}, save = true })
      categories:CreateCategory(ctx, { name = "Openable", itemList = {} })
      assert.is_false(categories:Convert(ctx, "Mats"))
      assert.is_nil(dbCategories["Mats"].blizzard)
      assert.is_false(categories:Convert(ctx, "Openable"))
      assert.is_nil(dbCategories["Openable"], "a plugin's stays the plugin's")
    end)

    -- Asked: "accept with a warning that it's making a new category technically": Blizzard's items stay in their own.
    it("makes it a category like any other when it is renamed", function()
      categories:Convert(ctx, "Junk")
      assert.is_true(categories:RenameCategory(ctx, "Junk", "Trash"))
      assert.is_nil(dbCategories["Junk"])
      assert.is_nil(dbCategories["Trash"].blizzard)
    end)

    -- Asked: "naming something onto a blizzard name should work as a converted one": a Blizzard category's name is one
    -- Blizzard's data gives an item in your bags (Items:KnowsBlizzardCategory), whatever shows it now.
    it("makes a category of yours made with a Blizzard category's name one made from it, never grouping", function()
      knownBlizzard = { Junk = true }
      categories:CreateCategory(ctx, { name = "Junk", itemList = {}, save = true,
        searchCategory = { query = "x", groupBy = 1 } })
      assert.is_true(dbCategories.Junk.blizzard)
      assert.is_nil(dbCategories.Junk.groupBy)
      categories:CreateCategory(ctx, { name = "Mats", itemList = {}, save = true })
      assert.is_nil(dbCategories.Mats.blizzard, "a name Blizzard does not give")
    end)

    it("leaves a plugin's category of a Blizzard category's name alone", function()
      knownBlizzard = { Junk = true }
      categories:CreateCategory(ctx, { name = "Junk", itemList = {} })
      assert.is_nil(categories:GetCategoryByName("Junk").blizzard)
    end)

    -- Asked, of a category of yours whose name Blizzard's data starts giving items: "i would prefer hidden changes to
    -- non-uniform behavior": it becomes one made from it, as if named so, its group by and its sections gone.
    describe("named as a Blizzard category the bags' items have now (ConvertNamed)", function()
      local sent, savedSend

      before_each(function()
        sent = {}
        savedSend = events.SendMessage
        events.SendMessage = function(_, _, message, ...) table.insert(sent, { message, ... }) end
      end)

      after_each(function()
        events.SendMessage = savedSend
      end)

      it("makes it one made from it, its group by and its sections gone, the bags recalculated once", function()
        categories:CreateCategory(ctx, { name = "Cloth", itemList = {}, save = true, groupBy = 3,
          enabled = { [0] = true, [1] = true, [2] = true } })
        categories:CreateCategory(ctx, { name = "Junk", itemList = {}, save = true })
        categories:CreateCategory(ctx, { name = "Cloth - Classic", itemList = { [5] = true }, dynamic = true,
          isGroupBySubcategory = true, groupByParent = "Cloth" })
        categories.ephemeralCategoryByItemID[5] = categories.ephemeralCategories["Cloth - Classic"]
        categories:CreateCategory(ctx, { name = "Cloth - Pets", itemList = {} })
        sent = {}
        local before = categories:GetGeneration()
        assert.is_true(categories:ConvertNamed(ctx, { Cloth = true, Junk = true, Leather = true }))
        assert.is_true(dbCategories.Cloth.blizzard)
        assert.is_nil(dbCategories.Cloth.groupBy)
        assert.is_true(dbCategories.Junk.blizzard)
        assert.is_nil(categories:GetCategoryByName("Cloth - Classic"), "its group by's section goes")
        assert.is_nil(dbEphemeralCategories["Cloth - Classic"], "saved too, with what bags saved for it")
        assert.is_nil(categories.ephemeralCategoryByItemID[5])
        assert.is_not_nil(categories:GetCategoryByName("Cloth - Pets"), "a plugin's category of a longer name stays")
        assert.is_nil(dbCategories.Leather, "no category is made")
        assert.is_true(categories:GetGeneration() > before)
        assert.are.same({ { "categories/Changed" }, { "bags/Rederive", { resetLayout = true, buttons = true } } }, sent)
      end)

      it("changes nothing for one made from it already, a plugin's, or a name no category has", function()
        categories:Convert(ctx, "Junk")
        categories:CreateCategory(ctx, { name = "Openable", itemList = {} })
        sent = {}
        assert.is_false(categories:ConvertNamed(ctx, { Junk = true, Openable = true, Trash = true }))
        assert.is_nil(categories:GetCategoryByName("Openable").blizzard)
        assert.are.same({}, sent)
      end)
    end)

    it("makes a category renamed to a Blizzard category's name one made from it, its group by gone", function()
      knownBlizzard = { ["Armor - Cloth"] = true }
      categories:CreateCategory(ctx, { name = "Mats", itemList = {}, save = true, groupBy = 1 })
      assert.is_true(categories:RenameCategory(ctx, "Mats", "Armor - Cloth"))
      assert.is_true(dbCategories["Armor - Cloth"].blizzard)
      assert.is_nil(dbCategories["Armor - Cloth"].groupBy)
      assert.is_true(categories:RenameCategory(ctx, "Armor - Cloth", "Cloth"))
      assert.is_nil(dbCategories.Cloth.blizzard, "renamed away from it: a category like any other")
    end)
  end)

  -- #1250: one category shared as text (DB:ReadImport's category: what it is, never what it does on its own).
  describe("a category shared as text (ImportCategory)", function()
    local ctx, sent, savedSend

    local function shared(extra)
      local s = { name = "Herbs", itemList = { [765] = true, [2447] = true }, searchCategory = { query = "type = herb" },
        groupBy = 2, color = { 0.1, 0.8, 0.2 }, enabled = { [0] = true, [1] = false, [2] = true }, hidden = { [2] = true },
        ignoredItems = { [99] = true }, note = "from a friend", skipRecent = true, itemOrder = { "count", "name" } }
      for k, v in pairs(extra or {}) do s[k] = v end
      return s
    end

    before_each(function()
      ctx = context:New("Test")
      sent = {}
      savedSend = events.SendMessage
      events.SendMessage = function(_, _, message, ...) table.insert(sent, { message, ... }) end
    end)

    after_each(function()
      events.SendMessage = savedSend
    end)

    it("adds it as a new category of yours, on top, its items moved to it from where they were, the bags recalculated", function()
      categories:CreateCategory(ctx, { name = "Mats", itemList = { [765] = true, [5] = true }, save = true })
      sent = {}
      local before = categories:GetGeneration()
      assert.is_true(categories:ImportCategory(ctx, shared(), "Herbs"))
      local made = dbCategories.Herbs
      assert.is_true(made.save)
      assert.are.same({ [765] = true, [2447] = true }, made.itemList)
      assert.is_nil(dbCategories.Mats.itemList[765], "an item has one home")
      assert.is_true(dbCategories.Mats.itemList[5])
      assert.are.same({ query = "type = herb" }, made.searchCategory)
      assert.are.equal(2, made.groupBy)
      assert.are.same({ 0.1, 0.8, 0.2 }, made.color)
      assert.are.same({ [0] = true, [1] = false, [2] = true }, made.enabled)
      assert.are.same({ [2] = true }, made.hidden)
      assert.are.same({ [99] = true }, made.ignoredItems)
      assert.are.equal("from a friend", made.note)
      assert.is_true(made.skipRecent)
      assert.are.same({ "count", "name" }, made.itemOrder)
      assert.is_nil(made.automation)
      assert.are.equal("Herbs", categories:GetOrder()[1])
      assert.is_true(categories:GetGeneration() > before)
      assert.are.same({ { "categories/Changed" }, { "bags/Rederive", { resetLayout = true, buttons = true } } }, sent)
    end)

    it("adds it under another name, beside the category that has its name", function()
      categories:CreateCategory(ctx, { name = "Herbs", itemList = { [765] = true }, save = true })
      assert.is_true(categories:ImportCategory(ctx, shared(), "Herbs (2)"))
      assert.are.equal("Herbs (2)", dbCategories["Herbs (2)"].name)
      assert.is_true(dbCategories["Herbs (2)"].itemList[765])
      assert.is_nil(dbCategories.Herbs.itemList[765])
    end)

    -- A string from another client holds that client's item IDs.
    it("files items this client does not know", function()
      local known = C_Item.GetItemInfoInstant
      C_Item.GetItemInfoInstant = function() return nil end
      finally(function() C_Item.GetItemInfoInstant = known end)
      assert.is_true(categories:ImportCategory(ctx, shared({ itemList = { [999999] = true } }), "Herbs"))
      assert.is_true(dbCategories.Herbs.itemList[999999])
    end)

    it("replaces a category of yours: what it is becomes the shared one's; its place and what it does on its own stay", function()
      categories:CreateCategory(ctx, { name = "Herbs", save = true, automation = "sell", confirmSale = false,
        deposit = "bank", itemList = { [1] = true, [765] = true }, searchCategory = { query = "old" }, groupBy = 1,
        color = { 1, 0, 0 }, enabled = { [0] = false, [1] = true, [2] = true }, hidden = { [0] = true }, note = "mine",
        ignoredItems = { [3] = true }, itemOrder = { "quality" } })
      dbCategories.Herbs.priority = 4
      categories:CreateCategory(ctx, { name = "Mats", itemList = { [2447] = true }, save = true })
      sent = {}
      local before = categories:GetGeneration()
      local plain = shared()
      plain.note, plain.skipRecent, plain.itemOrder = nil, nil, nil
      assert.is_true(categories:ImportCategory(ctx, plain, "Herbs", true))
      local f = dbCategories.Herbs
      assert.are.same({ [765] = true, [2447] = true }, f.itemList)
      assert.is_nil(dbCategories.Mats.itemList[2447])
      assert.are.same({ query = "type = herb" }, f.searchCategory)
      assert.are.equal(2, f.groupBy)
      assert.are.same({ 0.1, 0.8, 0.2 }, f.color)
      assert.are.same({ [0] = true, [1] = false, [2] = true }, f.enabled)
      assert.are.same({ [2] = true }, f.hidden)
      assert.are.same({ [99] = true }, f.ignoredItems)
      assert.is_nil(f.note, "the shared one has none")
      assert.is_nil(f.skipRecent)
      assert.is_nil(f.itemOrder, "the shared one has none: the bag's order")
      assert.are.equal(4, f.priority)
      assert.are.equal("sell", f.automation)
      assert.is_false(f.confirmSale)
      assert.are.equal("bank", f.deposit)
      assert.is_true(categories:GetGeneration() > before)
      assert.are.same({ { "categories/Changed" }, { "bags/Rederive", { resetLayout = true, buttons = true } } }, sent)
    end)

    it("replaces one made from a Blizzard category without its group by: it never groups", function()
      categories:Convert(ctx, "Junk")
      assert.is_true(categories:ImportCategory(ctx, shared({ name = "Junk" }), "Junk", true))
      assert.is_true(dbCategories.Junk.blizzard)
      assert.is_nil(dbCategories.Junk.groupBy)
      assert.are.same({ query = "type = herb" }, dbCategories.Junk.searchCategory)
    end)

    it("refuses a name a category has, or to replace one that is not yours, changing nothing", function()
      categories:CreateCategory(ctx, { name = "Herbs", itemList = {}, save = true })
      categories:CreateCategory(ctx, { name = "Openable", itemList = {} })
      sent = {}
      assert.is_false(categories:ImportCategory(ctx, shared(), "Herbs"))
      assert.is_false(categories:ImportCategory(ctx, shared(), "Openable"))
      assert.is_false(categories:ImportCategory(ctx, shared(), "Openable", true))
      assert.is_false(categories:ImportCategory(ctx, shared(), "Nothing", true))
      assert.are.same({}, dbCategories.Herbs.itemList)
      assert.is_nil(dbCategories.Openable)
      assert.is_nil(dbCategories.Nothing)
      assert.are.same({}, sent)
    end)

    it("counts the items an import moves from your other categories", function()
      categories:CreateCategory(ctx, { name = "Mats", itemList = { [765] = true }, save = true })
      categories:CreateCategory(ctx, { name = "Herbs", itemList = { [2447] = true }, save = true })
      assert.are.equal(2, categories:MovesOnImport(shared(), nil), "to a new one, both move")
      assert.are.equal(1, categories:MovesOnImport(shared(), "Herbs"), "replacing Herbs, its own stays")
      assert.are.equal(0, categories:MovesOnImport(shared({ itemList = { [5] = true } }), nil))
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

    -- A Blizzard category's header makes it yours as Convert does (issue #1278: one kind of category from a Blizzard
    -- one, whatever made it), the item added to it.
    it("makes a Blizzard category yours for an item that does not land there", function()
      assert.are.equal("added", categories:FileItem(ctx, 107, "Armor", "Junk"))
      assert.is_true(dbCategories["Armor"].save)
      assert.is_true(dbCategories["Armor"].blizzard)
      assert.is_true(dbCategories["Armor"].itemList[107])
      assert.is_nil(dbCategories["Mats"].blizzard, "a category that was one already stays as it was")
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

  -- Issue #1333: gear sets were hard coded ahead of every category, so nothing added by hand or matched by a rule could
  -- take an item in one (asked: "it's time we undo the hard coding and make them function like other categories
  -- correctly"). Each equipment set is a category BetterBags makes, in the order of the Categories list, and what the
  -- player sets for it is saved in the profile by the set's ID (asked: "everything goes in the global profile. it's
  -- keyed by the id of the gear set"; category-lifecycle.md §12).
  describe("gear sets", function()
    local ctx, gearSetFilter, sent, dbGearSets, renamed, deleted, batches, deletedBags
    local saved = {}
    local FIELDS = { "enabled", "color", "priority", "automation", "confirmSale", "deposit", "skipRecent",
      "ignoredItems", "hidden", "itemOrder" }

    local function setItem(itemID, ...)
      return { itemInfo = { itemID = itemID, equipmentSets = { ... } } }
    end

    before_each(function()
      ctx = context:New("Test")
      gearSetFilter, sent, dbGearSets, renamed, deleted, batches, deletedBags = true, {}, {}, {}, {}, {}, {}
      for _, key in ipairs({ "GetCategoryFilter", "GetGearSet", "GetGearSets", "SetGearSet", "UpdateGearSet",
        "RenameGearSets", "DeleteGearSet", "SetEphemeralItemCategoryEnabled" }) do
        saved[key] = rawget(database, key)
      end
      saved.SendMessage = events.SendMessage
      database.GetCategoryFilter = function(_, _, filter) return filter == "GearSet" and gearSetFilter end
      -- As the real ones (core/database.lua): the profile's gearSets, by set ID. Which bag settings move or go is
      -- recorded (`bags`); spec/database_spec.lua moves them.
      database.GetGearSet = function(_, id) return dbGearSets[id] end
      database.GetGearSets = function() return dbGearSets end
      database.SetGearSet = function(_, id, record) dbGearSets[id] = record end
      database.UpdateGearSet = function(_, id, fields)
        local record = dbGearSets[id]
        if record == nil then return end
        for _, key in ipairs(FIELDS) do record[key] = fields[key] end
      end
      database.RenameGearSets = function(_, renames)
        local batch = {}
        for _, rename in ipairs(renames) do
          table.insert(renamed, { dbGearSets[rename.id].name, rename.name })
          table.insert(batch, { dbGearSets[rename.id].name, rename.name, rename.bags })
        end
        table.insert(batches, batch)
        for _, rename in ipairs(renames) do dbGearSets[rename.id].name = rename.name end
      end
      database.DeleteGearSet = function(_, id, bags, older)
        table.insert(deleted, dbGearSets[id] and dbGearSets[id].name or id)
        table.insert(deletedBags, bags)
        if older then
          dbEphemeralCategories[older] = nil
        end
        dbGearSets[id] = nil
      end
      database.SetEphemeralItemCategoryEnabled = function(_, kind, name, enabled)
        if dbEphemeralCategories[name] then
          dbEphemeralCategories[name].enabled = dbEphemeralCategories[name].enabled or {}
          dbEphemeralCategories[name].enabled[kind] = enabled
        end
      end
      events.SendMessage = function(_, _, message, ...) table.insert(sent, { message, ... }) end
    end)

    after_each(function()
      for key, fn in pairs(saved) do
        if key == "SendMessage" then events.SendMessage = fn else database[key] = fn end
      end
    end)

    it("makes a category for each set, named after it, on top of the order, used in every bag, saved by its ID", function()
      categories:CreateCategory(ctx, { name = "Mats", itemList = {}, save = true, priority = 1 })
      sent = {}
      local before = categories:GetGeneration()
      assert.is_true(categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } }))
      local tank = categories:GetCategoryByName("Gear: Tank")
      assert.are.equal(3, tank.gearSet)
      assert.are.same({ "Gear: Tank", "Mats" }, categories:GetOrder())
      assert.are.same({ [0] = true, [1] = true, [2] = true }, tank.enabled)
      assert.are.equal("Gear: Tank", dbGearSets[3].name)
      assert.are.equal(tank.priority, dbGearSets[3].priority, "its place saved")
      assert.is_nil(dbEphemeralCategories["Gear: Tank"], "not saved as a plugin's")
      assert.is_nil(dbCategories["Gear: Tank"], "not one of yours")
      assert.is_true(categories:IsGearSet("Gear: Tank"))
      assert.is_false(categories:IsGearSet("Mats"))
      assert.is_false(categories:IsGearSet("Gear: Heal"))
      assert.is_true(categories:GetGeneration() > before)
      assert.are.same({ "categories/Changed" }, sent[#sent])
    end)

    it("changes nothing when the sets are the same", function()
      categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } })
      local before = categories:GetGeneration()
      sent = {}
      assert.is_false(categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } }))
      assert.are.equal(before, categories:GetGeneration())
      assert.are.same({}, sent)
    end)

    it("gives an item in a set its set's category, with its place in the order", function()
      categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } })
      local name, priority, filter = categories:GetCustomCategory(ctx, 0, setItem(101, "Tank"))
      assert.are.equal("Gear: Tank", name)
      assert.are.equal(categories:GetCategoryByName("Gear: Tank").priority, priority)
      assert.are.equal(3, filter.gearSet)
      assert.is_nil((categories:GetCustomCategory(ctx, 0, { itemInfo = { itemID = 102 } })), "an item in no set")
    end)

    it("keeps an item added by hand to a category of yours there, whatever the order", function()
      categories:CreateCategory(ctx, { name = "Trinket", itemList = {}, save = true })
      categories:AddPermanentItemToCategory(ctx, 101, "Trinket")
      categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } })
      assert.are.equal("Gear: Tank", categories:GetOrder()[1], "the set is on top")
      assert.are.equal("Trinket", (categories:GetCustomCategory(ctx, 0, setItem(101, "Tank"))))
      assert.are.equal("Gear: Tank", (categories:GetCustomCategory(ctx, 0, setItem(101, "Tank"), true)),
        "where it lands without it")
    end)

    it("competes with a plugin's list by the order", function()
      categories:CreateCategory(ctx, { name = "Openable", itemList = { [101] = true } })
      categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } })
      assert.are.equal("Gear: Tank", (categories:GetCustomCategory(ctx, 0, setItem(101, "Tank"))))
      categories:MoveCategory(ctx, "Openable")
      assert.are.equal("Openable", (categories:GetCustomCategory(ctx, 0, setItem(101, "Tank"))))
      assert.are.equal("Openable", (categories:GetCustomCategory(ctx, 0, { itemInfo = { itemID = 101 } })), "out of a set")
    end)

    it("competes with what a category function names by the order", function()
      categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } })
      categories:RegisterCategoryFunction("fish", function() return "Fish" end)
      assert.are.equal("Fish", (categories:GetCustomCategory(ctx, 0, setItem(101, "Tank"))), "a new category, on top")
      categories:MoveCategory(ctx, "Gear: Tank")
      assert.are.equal("Gear: Tank", (categories:GetCustomCategory(ctx, 0, setItem(101, "Tank"))))
    end)

    -- Found by the first bug review: each new set was made on top in turn, so the client's last set came first, where an
    -- item in two sets used to show in the first.
    it("puts an item in two sets in the one higher in the order, the client's first set at first", function()
      categories:SyncGearSets(ctx, { { id = 1, name = "Tank" }, { id = 2, name = "Heal" } })
      assert.are.same({ "Gear: Tank", "Gear: Heal" }, categories:GetOrder())
      assert.are.equal("Gear: Tank", (categories:GetCustomCategory(ctx, 0, setItem(101, "Heal", "Tank"))))
      categories:MoveCategory(ctx, "Gear: Heal")
      assert.are.equal("Gear: Heal", (categories:GetCustomCategory(ctx, 0, setItem(101, "Heal", "Tank"))))
    end)

    it("passes over a set's category that ignores the item, is not used in the bag, or with the bag's switch off", function()
      categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } })
      local item = setItem(101, "Tank")
      categories:IgnoreItem(ctx, 101, "Gear: Tank")
      assert.is_nil((categories:GetCustomCategory(ctx, 0, item)))
      assert.is_true(dbGearSets[3].ignoredItems[101], "saved by the set's ID")
      categories:UnignoreItem(ctx, 101, "Gear: Tank")
      categories:UpdateCategory(ctx, "Gear: Tank", { enabled = { [1] = false } })
      assert.is_false(dbGearSets[3].enabled[1])
      assert.is_nil((categories:GetCustomCategory(ctx, 1, item)), "not used in the bank")
      assert.are.equal("Gear: Tank", (categories:GetCustomCategory(ctx, 0, item)))
      gearSetFilter = false
      assert.is_nil((categories:GetCustomCategory(ctx, 0, item)), "the bag's Equipment Set off")
      assert.is_nil(dbEphemeralCategories["Gear: Tank"], "nothing saved as a plugin's")
    end)

    it("keeps what the player set for a set's category in the next session", function()
      categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } })
      categories:CreateCategory(ctx, { name = "Mats", itemList = {}, save = true })
      categories:MoveCategory(ctx, "Mats")
      categories:UpdateCategory(ctx, "Gear: Tank", { color = { 1, 0, 0 } })
      categories:Init()
      categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } })
      assert.are.same({ "Mats", "Gear: Tank" }, categories:GetOrder(), "where it was, not on top")
      assert.are.same({ 1, 0, 0 }, categories:GetCategoryByName("Gear: Tank").color)
    end)

    it("follows a set renamed in the Equipment Manager: its settings by ID, its pins and tabs by name", function()
      categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } })
      categories:UpdateCategory(ctx, "Gear: Tank", { color = { 1, 0, 0 } })
      sent = {}
      local before = categories:GetGeneration()
      assert.is_true(categories:SyncGearSets(ctx, { { id = 3, name = "Prot" } }))
      assert.is_true(categories:GetGeneration() > before, "the bags work its items' categories out again")
      assert.is_nil(categories:GetCategoryByName("Gear: Tank"))
      local prot = categories:GetCategoryByName("Gear: Prot")
      assert.are.equal(3, prot.gearSet)
      assert.are.same({ 1, 0, 0 }, prot.color)
      assert.are.same({ { "Gear: Tank", "Gear: Prot" } }, renamed, "its pins and tabs move with it")
      assert.are.equal("Gear: Prot", dbGearSets[3].name)
      -- As RenameCategory says it, so the Categories page keeps it chosen.
      assert.are.same({ "categories/Changed", "Gear: Prot", "Gear: Tank" }, sent[1])
    end)

    -- Asked: a set's ID is the set on every character of the profile ("if the user renames or moves something on one
    -- character, it affects the other -- the user should make individual profiles"); a rename made while BetterBags was
    -- not loaded is found the same way.
    it("takes the settings saved for its ID, whatever the set was called when they were saved", function()
      categories:SyncGearSets(ctx, { { id = 0, name = "Tank" } })
      categories:UpdateCategory(ctx, "Gear: Tank", { color = { 1, 0, 0 } })
      categories:Init()
      categories:SyncGearSets(ctx, { { id = 0, name = "Healer" } })
      assert.are.same({ 1, 0, 0 }, categories:GetCategoryByName("Gear: Healer").color)
      assert.are.same({ { "Gear: Tank", "Gear: Healer" } }, renamed)
    end)

    -- Asked: "deleted should mean deleted". A set deleted and made again under its name starts fresh, not from the older
    -- entry of its name again.
    it("starts a set deleted and made again under its name fresh, its older entry gone with it", function()
      dbEphemeralCategories["Gear: Tank"] = { name = "Gear: Tank", enabled = { [0] = true }, itemList = {}, dynamic = true,
        color = { 0, 1, 0 }, priority = 30 }
      categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } })
      assert.are.same({ 0, 1, 0 }, categories:GetCategoryByName("Gear: Tank").color, "copied the first time")
      categories:ForgetGearSets(ctx, { 3 })
      assert.is_nil(dbEphemeralCategories["Gear: Tank"])
      categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } })
      local tank = categories:GetCategoryByName("Gear: Tank")
      assert.is_nil(tank.color)
      assert.are.same({ [0] = true, [1] = true, [2] = true }, tank.enabled)
      assert.are.equal("Gear: Tank", categories:GetOrder()[1], "on top")
    end)

    -- Found by the bug review: a set that copied the older entry of its first name, renamed and then deleted, left that
    -- entry behind, so a set made again under the first name took its settings back.
    it("deletes the older entry a set copied, even under the name it had before a rename", function()
      dbEphemeralCategories["Gear: Tank"] = { name = "Gear: Tank", enabled = { [0] = true }, itemList = {}, dynamic = true,
        color = { 0, 1, 0 } }
      categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } })
      assert.are.equal("Gear: Tank", dbGearSets[3].older, "the entry it copied")
      categories:SyncGearSets(ctx, { { id = 3, name = "Ret" } })
      assert.are.equal("Gear: Tank", dbGearSets[3].older, "kept through a rename")
      categories:ForgetGearSets(ctx, { 3 })
      assert.is_nil(dbEphemeralCategories["Gear: Tank"])
      categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } })
      assert.is_nil(categories:GetCategoryByName("Gear: Tank").color)
      assert.is_nil(dbGearSets[3].older, "nothing to copy")
    end)

    it("keeps the older entry a set copied when another category now has its name", function()
      dbEphemeralCategories["Gear: Tank"] = { name = "Gear: Tank", enabled = { [0] = true }, itemList = {}, dynamic = true }
      categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } })
      categories:SyncGearSets(ctx, { { id = 3, name = "Ret" } })
      categories:CreateCategory(ctx, { name = "Gear: Tank", itemList = {} })
      categories:ForgetGearSets(ctx, { 3 })
      assert.is_not_nil(dbEphemeralCategories["Gear: Tank"], "the plugin's now")
    end)

    -- Found by the bug review: another gear set holding the name of the entry a set copied kept that entry when the set
    -- was deleted (and only in one order of deletion), though a gear set's category never reads the entry of its name.
    it("deletes the older entry a set copied when another gear set has taken its name", function()
      dbEphemeralCategories["Gear: Tank"] = { name = "Gear: Tank", enabled = { [0] = true }, itemList = {}, dynamic = true,
        color = { 0, 1, 0 } }
      categories:SyncGearSets(ctx, { { id = 3, name = "Tank" }, { id = 5, name = "Heal" } })
      categories:SyncGearSets(ctx, { { id = 3, name = "Ret" }, { id = 5, name = "Tank" } })
      assert.are.equal(5, categories:GetCategoryByName("Gear: Tank").gearSet)
      categories:ForgetGearSets(ctx, { 3, 5 })
      assert.is_nil(dbEphemeralCategories["Gear: Tank"])
      categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } })
      assert.is_nil(categories:GetCategoryByName("Gear: Tank").color, "made again, fresh")
    end)

    -- Asked (option 2, "we just watch the event"): a set this character deletes is forgotten, so a set the client later
    -- gives its ID (Forever reuses a freed ID) starts fresh.
    it("forgets what was saved for a set this character deleted, its pins and tabs too", function()
      categories:SyncGearSets(ctx, { { id = 0, name = "first" }, { id = 1, name = "second" } })
      categories:UpdateCategory(ctx, "Gear: first", { color = { 1, 0, 0 } })
      sent = {}
      local before = categories:GetGeneration()
      categories:ForgetGearSets(ctx, { 0 })
      assert.is_true(categories:GetGeneration() > before)
      assert.are.same({ { "categories/Changed" } }, sent)
      assert.are.same({ "Gear: first" }, deleted, "the record and its pins and tabs")
      assert.is_nil(dbGearSets[0])
      assert.is_nil(categories:GetCategoryByName("Gear: first"))
      assert.is_false(categories:IsGearSet("Gear: first"))
      assert.is_not_nil(categories:GetCategoryByName("Gear: second"))
      categories:SyncGearSets(ctx, { { id = 1, name = "second" }, { id = 0, name = "new fourth after" } })
      local fresh = categories:GetCategoryByName("Gear: new fourth after")
      assert.is_nil(fresh.color)
      assert.are.equal("Gear: new fourth after", categories:GetOrder()[1], "on top, as a new one")
      assert.are.same({}, renamed, "not taken for a rename")
    end)

    -- Asked: a set another character has, or one gone without the event, is skipped, never deleted.
    it("keeps, untouched, what was saved for a set this character does not have", function()
      dbGearSets[7] = { name = "Gear: Alt", color = { 0, 0, 1 }, priority = 4, enabled = { [0] = true } }
      categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } })
      assert.is_nil(categories:GetCategoryByName("Gear: Alt"))
      assert.are.same({ name = "Gear: Alt", color = { 0, 0, 1 }, priority = 4, enabled = { [0] = true } }, dbGearSets[7])
      categories:SyncGearSets(ctx, {})
      assert.is_nil(categories:GetCategoryByName("Gear: Tank"), "a set no longer listed leaves the list")
      assert.is_not_nil(dbGearSets[3], "without the event it is kept")
      assert.are.same({}, deleted)
    end)

    -- Profiles saved by older versions (test.lua: "Gear: Tank", "Gear: Ret", dynamic, no place), and by the build before
    -- this one, hold gear sets' saved state by name (asked: copy it "the first time the set has no record ... After that
    -- leave those entries alone: not loaded, not deleted").
    it("copies what an older version saved by name into a set's record once, leaving it alone", function()
      dbCategories["Armor"] = { name = "Armor", save = true, priority = 3, itemList = {},
        enabled = { [0] = true, [1] = true, [2] = true }, searchCategory = { query = "type = armor" } }
      dbEphemeralCategories["Gear: Tank"] = { name = "Gear: Tank", enabled = { [0] = true, [1] = false }, itemList = {},
        dynamic = true, color = { 0, 1, 0 }, ignoredItems = { [5] = true } }
      dbEphemeralCategories["Gear: Pvp"] = { name = "Gear: Pvp", enabled = { [0] = true }, itemList = {}, priority = 20 }
      dbEphemeralCategories["Gear: Ret"] = { name = "Gear: Ret", enabled = { [0] = true }, itemList = {}, dynamic = true }
      categories:OnEnable()
      assert.is_nil(categories:GetCategoryByName("Gear: Tank"), "not loaded at login")
      assert.is_nil(categories:GetCategoryByName("Gear: Ret"))
      categories:SyncGearSets(ctx, { { id = 1, name = "Tank" }, { id = 4, name = "Pvp" } })
      local tank = categories:GetCategoryByName("Gear: Tank")
      assert.are.same({ 0, 1, 0 }, tank.color)
      assert.are.same({ [0] = true, [1] = false }, tank.enabled)
      assert.are.same({ [5] = true }, tank.ignoredItems)
      assert.are.same({ "Gear: Tank", "Armor", "Gear: Pvp" }, categories:GetOrder(), "on top unless it had a place")
      assert.are.same({ 0, 1, 0 }, dbGearSets[1].color, "copied into the record")
      categories:UpdateCategory(ctx, "Gear: Tank", { color = { 1, 1, 1 }, enabled = { [1] = true } })
      local old = dbEphemeralCategories["Gear: Tank"]
      assert.are.same({ 0, 1, 0 }, old.color, "left alone")
      assert.are.same({ [0] = true, [1] = false }, old.enabled)
      assert.is_true(old.dynamic)
      assert.is_not_nil(dbEphemeralCategories["Gear: Ret"], "not deleted")
      categories:Init()
      dbEphemeralCategories["Gear: Tank"].color = { 0, 0, 1 }
      categories:SyncGearSets(ctx, { { id = 1, name = "Tank" } })
      assert.are.same({ 1, 1, 1 }, categories:GetCategoryByName("Gear: Tank").color, "copied once")
    end)

    it("still loads a category's group by sections named like a gear set", function()
      dbEphemeralCategories["Gear: BoE - Plate"] = { name = "Gear: BoE - Plate", enabled = { [0] = true }, itemList = {},
        dynamic = true, isGroupBySubcategory = true, groupByParent = "Gear: BoE" }
      categories:OnEnable()
      assert.is_false(categories:SyncGearSets(ctx, {}))
      assert.is_not_nil(categories:GetCategoryByName("Gear: BoE - Plate"))
    end)

    it("makes none for a set another category is named after", function()
      categories:CreateCategory(ctx, { name = "Gear: Tank", itemList = {}, save = true })
      assert.is_false(categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } }))
      assert.is_false(categories:IsGearSet("Gear: Tank"))
      assert.is_true(categories:GetCategoryByName("Gear: Tank").save)
      assert.is_nil(dbGearSets[3])
    end)

    it("leaves a set renamed onto another category's name without one, its record as it was", function()
      categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } })
      categories:CreateCategory(ctx, { name = "Gear: Mine", itemList = {}, save = true })
      categories:SyncGearSets(ctx, { { id = 3, name = "Mine" } })
      assert.is_nil(categories:GetCategoryByName("Gear: Tank"))
      assert.is_true(categories:GetCategoryByName("Gear: Mine").save, "yours")
      assert.are.same({}, renamed)
      assert.are.equal("Gear: Tank", dbGearSets[3].name)
    end)

    -- Two characters of the profile whose sets have each other's names under their IDs: each name is another set's too,
    -- so its pins and tabs stay with the name (asked: a rename moves them only when no other set's saved settings use
    -- either name; "messy, but do it").
    it("renames sets that take each other's names together, their pins and tabs staying with the names", function()
      dbGearSets[0] = { name = "Gear: Tank", enabled = { [0] = true }, priority = 1 }
      dbGearSets[1] = { name = "Gear: Heal", enabled = { [0] = true }, priority = 2 }
      categories:SyncGearSets(ctx, { { id = 0, name = "Heal" }, { id = 1, name = "Tank" } })
      assert.are.equal(1, #batches, "in one go")
      table.sort(batches[1], function(a, b) return a[1] < b[1] end)
      assert.are.same({ { "Gear: Heal", "Gear: Tank", false }, { "Gear: Tank", "Gear: Heal", false } }, batches[1])
      assert.are.equal(0, categories:GetCategoryByName("Gear: Heal").gearSet)
      assert.are.equal(1, categories:GetCategoryByName("Gear: Tank").gearSet)
    end)

    it("swaps two sets' names in memory in one sweep", function()
      categories:SyncGearSets(ctx, { { id = 0, name = "Tank" }, { id = 1, name = "Heal" } })
      categories:UpdateCategory(ctx, "Gear: Tank", { color = { 1, 0, 0 } })
      sent = {}
      categories:SyncGearSets(ctx, { { id = 0, name = "Heal" }, { id = 1, name = "Tank" } })
      assert.are.same({ 1, 0, 0 }, categories:GetCategoryByName("Gear: Heal").color, "set 0's settings")
      assert.are.equal(1, categories:GetCategoryByName("Gear: Tank").gearSet)
      assert.are.equal(1, #batches)
      table.sort(batches[1], function(a, b) return a[1] < b[1] end)
      assert.are.same({ { "Gear: Heal", "Gear: Tank", false }, { "Gear: Tank", "Gear: Heal", false } }, batches[1],
        "each name a set leaves free for the other, its pins and tabs staying with the name")
      assert.are.equal("Gear: Heal", categories:GetCategoryByName("Gear: Heal").name)
      assert.are.equal("Gear: Tank", categories:GetCategoryByName("Gear: Tank").name)
    end)

    -- Asked: a rename moves pins and tabs only when no other set's saved settings use either name ("messy, but do it").
    -- A: set 0 "DPS", set 1 "Tank"; B, on the same profile: set 0 "Tank". Moving them on each login, B's rename wrote
    -- set 0's pin over A's Tank's, and A's took it away again.
    it("leaves pins and tabs with the name when another set's saved settings use the old or the new one", function()
      dbGearSets[0] = { name = "Gear: DPS", enabled = { [0] = true }, priority = 1 }
      dbGearSets[1] = { name = "Gear: Tank", enabled = { [0] = true }, priority = 2 }
      categories:SyncGearSets(ctx, { { id = 0, name = "Tank" } })
      assert.are.same({ { { "Gear: DPS", "Gear: Tank", false } } }, batches, "B: the new name is set 1's")
      categories:Init()
      batches = {}
      categories:SyncGearSets(ctx, { { id = 0, name = "DPS" }, { id = 1, name = "Tank" } })
      assert.are.same({ { { "Gear: Tank", "Gear: DPS", false } } }, batches, "A: the old name is set 1's")
      categories:Init()
      batches = {}
      dbGearSets[2] = { name = "Gear: Solo", enabled = { [0] = true }, priority = 3 }
      categories:SyncGearSets(ctx, { { id = 2, name = "Duo" } })
      assert.are.same({ { { "Gear: Solo", "Gear: Duo", true } } }, batches, "no other set's: they move")
    end)

    -- A chain across two characters (A: "A", "B"; B: "B", "C"): one set takes the name another leaves. Checked only as
    -- the records were, a pin was stranded under a name no set has.
    it("leaves pins and tabs with the names in a chain, checking the names the sets will have", function()
      dbGearSets[0] = { name = "Gear: A", enabled = { [0] = true }, priority = 1 }
      dbGearSets[1] = { name = "Gear: B", enabled = { [0] = true }, priority = 2 }
      categories:SyncGearSets(ctx, { { id = 0, name = "B" }, { id = 1, name = "C" } })
      table.sort(batches[1], function(a, b) return a[1] < b[1] end)
      assert.are.same({ { "Gear: A", "Gear: B", false }, { "Gear: B", "Gear: C", false } }, batches[1])
    end)

    it("leaves a deleted set's pins and tabs with its name when another set's saved settings use it", function()
      dbGearSets[1] = { name = "Gear: Tank", enabled = { [0] = true }, priority = 2 }
      dbGearSets[0] = { name = "Gear: Tank", enabled = { [0] = true }, priority = 1 }
      categories:SyncGearSets(ctx, { { id = 0, name = "Tank" } })
      categories:ForgetGearSets(ctx, { 0 })
      assert.are.same({ false }, deletedBags, "set 1's name too")
      dbGearSets[4] = { name = "Gear: Solo", enabled = { [0] = true }, priority = 3 }
      categories:SyncGearSets(ctx, { { id = 4, name = "Solo" } })
      categories:ForgetGearSets(ctx, { 4 })
      assert.are.same({ false, true }, deletedBags)
    end)

    -- Found by the second bug review: no test had another category in memory holding a record's old name.
    it("leaves the pins and tabs of a plugin's category of the record's name alone", function()
      dbGearSets[3] = { name = "Gear: Old", enabled = { [0] = true }, priority = 1 }
      categories:CreateCategory(ctx, { name = "Gear: Old", itemList = {} })
      categories:SyncGearSets(ctx, { { id = 3, name = "New" } })
      assert.are.same({ { { "Gear: Old", "Gear: New", false } } }, batches)
    end)

    -- Found by the bug review: what each bag saved under a record's name is the set's only while no other category has
    -- the name (a category of yours made since, on another character of the profile).
    it("leaves the pins and tabs of another category of the record's name alone, deleted or renamed", function()
      dbGearSets[3] = { name = "Gear: Tank", enabled = { [0] = true }, priority = 1 }
      categories:CreateCategory(ctx, { name = "Gear: Tank", itemList = {}, save = true })
      categories:SyncGearSets(ctx, { { id = 3, name = "Prot" } })
      assert.are.same({ { { "Gear: Tank", "Gear: Prot", false } } }, batches, "renamed, the bags' settings yours")
      dbGearSets[4] = { name = "Gear: Mine", enabled = { [0] = true }, priority = 2 }
      categories:CreateCategory(ctx, { name = "Gear: Mine", itemList = {}, save = true })
      categories:ForgetGearSets(ctx, { 4 })
      assert.are.same({ false }, deletedBags, "deleted, the bags' settings yours")
      categories:SyncGearSets(ctx, { { id = 3, name = "Prot" } })
      categories:ForgetGearSets(ctx, { 3 })
      assert.are.same({ false, true }, deletedBags, "the set's own")
    end)

    -- Found by the bug review: no test covered a gear set's category taken out of memory another way.
    it("makes a set's category again when it was deleted another way", function()
      categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } })
      categories:UpdateCategory(ctx, "Gear: Tank", { color = { 1, 0, 0 } })
      categories:DeleteCategory(ctx, "Gear: Tank")
      assert.is_nil(categories:GetCategoryByName("Gear: Tank"))
      assert.is_true(categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } }))
      assert.are.same({ 1, 0, 0 }, categories:GetCategoryByName("Gear: Tank").color, "from its record")
    end)

    -- Found by the bug review: plugins' older calls read and saved a category's bags as a plugin's.
    it("answers and saves a gear set's bags through the older plugin calls, the older entry left alone", function()
      dbEphemeralCategories["Gear: Tank"] = { name = "Gear: Tank", enabled = { [0] = true, [1] = true }, itemList = {} }
      categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } })
      assert.is_true(categories:IsCategoryEnabled(1, "Gear: Tank"))
      categories:DisableCategory(1, "Gear: Tank")
      assert.is_false(categories:IsCategoryEnabled(1, "Gear: Tank"))
      assert.is_false(dbGearSets[3].enabled[1])
      categories:ToggleCategory(1, "Gear: Tank")
      categories:EnableCategory(0, "Gear: Tank")
      categories:SetCategoryState(2, "Gear: Tank", false)
      assert.are.same({ [0] = true, [1] = true, [2] = false }, dbGearSets[3].enabled)
      assert.are.same({ [0] = true, [1] = true }, dbEphemeralCategories["Gear: Tank"].enabled, "left alone")
    end)

    -- Asked: "so long as we can't rename the category in BetterBags".
    it("cannot be renamed in BetterBags", function()
      categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } })
      assert.is_false(categories:RenameCategory(ctx, "Gear: Tank", "Tanky"))
      assert.is_not_nil(categories:GetCategoryByName("Gear: Tank"))
      assert.is_nil(categories:GetCategoryByName("Tanky"))
    end)

    it("takes nothing dropped on its header, unless the item lands there anyway", function()
      categories:CreateCategory(ctx, { name = "Mats", itemList = {}, save = true })
      categories:AddPermanentItemToCategory(ctx, 101, "Mats")
      categories:SyncGearSets(ctx, { { id = 3, name = "Tank" } })
      assert.are.equal("gear set", categories:FileItem(ctx, 102, "Gear: Tank", "Junk"))
      assert.is_nil(dbCategories["Gear: Tank"], "no category of yours made in its name")
      assert.are.equal("Mats", database:GetItemCategoryByItemID(101).name)
      assert.are.equal("natural", categories:FileItem(ctx, 101, "Gear: Tank", "Gear: Tank"))
      assert.is_nil(database:GetItemCategoryByItemID(101).name, "back to its set")
    end)
  end)
end)
