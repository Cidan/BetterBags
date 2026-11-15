-- groups_spec.lua -- Unit tests for data/groups.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

ResetModuleStub("Database", "core/database.lua")
ResetModuleStub("Groups", "data/groups.lua")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")

local context = addon:GetModule("Context")
local events = addon:GetModule("Events")
events:Init()

local debug = StubBetterBagsModule("Debug")
debug.Log = function() end

local const = StubBetterBagsModule("Constants")
const.BAG_KIND = { BACKPACK = 0, BANK = 1 }

-- In-memory database mock for groups
local database = StubBetterBagsModule("Database")
local dbGroups = {}       -- [kind][groupID] = Group
local dbCategoryGroups = {} -- [kind][categoryName] = groupID
local dbActiveGroups = {}   -- [kind] = groupID
local nextGroupID = 100

database.CreateGroup = function(_, kind, name, bankType)
  nextGroupID = nextGroupID + 1
  dbGroups[kind] = dbGroups[kind] or {}
  dbGroups[kind][nextGroupID] = {id = nextGroupID, name = name, bankType = bankType}
  return nextGroupID
end
database.GetGroup = function(_, kind, groupID)
  return dbGroups[kind] and dbGroups[kind][groupID]
end
-- As core/database.lua's DB:DeleteGroup: the active group moves to the default (Backpack, or the
-- character bank's default group) before Groups says the group went.
database.DeleteGroup = function(_, kind, groupID)
  if dbGroups[kind] then dbGroups[kind][groupID] = nil end
  if dbActiveGroups[kind] == groupID then
    dbActiveGroups[kind] = 1
    if kind == const.BAG_KIND.BANK then
      for id, g in pairs(dbGroups[kind] or {}) do
        if g.isDefault and g.bankType == Enum.BankType.Character then
          dbActiveGroups[kind] = id
        end
      end
    end
  end
end
database.RenameGroup = function(_, kind, groupID, name)
  if dbGroups[kind] and dbGroups[kind][groupID] then
    dbGroups[kind][groupID].name = name
  end
end
database.GetAllGroups = function(_, kind)
  return dbGroups[kind] or {}
end
database.SetCategoryGroup = function(_, kind, categoryName, groupID)
  dbCategoryGroups[kind] = dbCategoryGroups[kind] or {}
  dbCategoryGroups[kind][categoryName] = groupID
end
database.GetCategoryGroup = function(_, kind, categoryName)
  return dbCategoryGroups[kind] and dbCategoryGroups[kind][categoryName]
end
database.RemoveCategoryFromGroup = function(_, kind, categoryName)
  if dbCategoryGroups[kind] then dbCategoryGroups[kind][categoryName] = nil end
end
database.GetGroupCategories = function(_, kind, groupID)
  local result = {}
  if dbCategoryGroups[kind] then
    for cat, gid in pairs(dbCategoryGroups[kind]) do
      if gid == groupID then result[cat] = true end
    end
  end
  return result
end
database.GetActiveGroup = function(_, kind) return dbActiveGroups[kind] or 1 end
database.SetActiveGroup = function(_, kind, groupID) dbActiveGroups[kind] = groupID end
database.GetCustomSectionSort = function() return {} end
local dbHideEmpty = {}      -- [kind] = Hide Empty Groups
database.GetHideEmptyGroups = function(_, kind) return dbHideEmpty[kind] == true end

-- The bags' data as Items holds it (items:GetAllSlotInfo), read when a category is assigned to a group.
local itemsModule, itemsCreated = StubBetterBagsModule("Items")

-- Stub Enum for GetDefaultBankGroup
_G.Enum = _G.Enum or {}
_G.Enum.BankType = _G.Enum.BankType or {Character = 1, Account = 2}

LoadBetterBagsModule("data/groups.lua")
local groups = addon:GetModule("Groups")

describe("Groups", function()
  local savedSlotInfo, slotInfo

  before_each(function()
    for k in pairs(dbGroups) do dbGroups[k] = nil end
    for k in pairs(dbCategoryGroups) do dbCategoryGroups[k] = nil end
    for k in pairs(dbActiveGroups) do dbActiveGroups[k] = nil end
    nextGroupID = 100
    savedSlotInfo = rawget(itemsModule, "GetAllSlotInfo")
    slotInfo = {}
    itemsModule.GetAllSlotInfo = function() return slotInfo end
  end)

  after_each(function()
    itemsModule.GetAllSlotInfo = savedSlotInfo
  end)

  teardown(function()
    if itemsCreated then ResetModuleStub("Items") end
  end)

  -- ─── CRUD ───────────────────────────────────────────────────────────────────

  describe("CreateGroup", function()

    it("creates a group and returns it", function()
      local ctx = context:New("Test")
      local group = groups:CreateGroup(ctx, const.BAG_KIND.BACKPACK, "My Group")
      assert.is_not_nil(group)
      assert.are.equal("My Group", group.name)
    end)

    it("assigns unique IDs to groups", function()
      local ctx = context:New("Test")
      groups:CreateGroup(ctx, const.BAG_KIND.BACKPACK, "A")
      groups:CreateGroup(ctx, const.BAG_KIND.BACKPACK, "B")
      local all = groups:GetAllGroups(const.BAG_KIND.BACKPACK)
      local ids = {}
      for id in pairs(all) do table.insert(ids, id) end
      assert.are.equal(2, #ids)
      assert.are_not.equal(ids[1], ids[2])
    end)
  end)

  describe("DeleteGroup", function()

    it("deletes a non-default group", function()
      local ctx = context:New("Test")
      local group = groups:CreateGroup(ctx, const.BAG_KIND.BACKPACK, "Temp")
      local groupID = group.id
      groups:DeleteGroup(ctx, const.BAG_KIND.BACKPACK, groupID)
      assert.is_nil(groups:GetGroup(const.BAG_KIND.BACKPACK, groupID))
    end)

    it("refuses to delete default backpack group (ID 1)", function()
      local ctx = context:New("Test")
      -- Manually create group with ID 1 as default
      dbGroups[const.BAG_KIND.BACKPACK] = {[1] = {id = 1, name = "Backpack", isDefault = true}}
      nextGroupID = 1
      groups:DeleteGroup(ctx, const.BAG_KIND.BACKPACK, 1)
      -- Should still exist
      assert.is_not_nil(groups:GetGroup(const.BAG_KIND.BACKPACK, 1))
    end)

    it("does nothing for non-existent groups", function()
      local ctx = context:New("Test")
      groups:DeleteGroup(ctx, const.BAG_KIND.BACKPACK, 999) -- should not error
    end)

    -- The bags read whether to show the default group from the message (#1265): by the time it
    -- is sent, the active group is already the default.
    it("says the deleted group was the one shown, though the active group is already the default", function()
      local ctx = context:New("Test")
      local group = groups:CreateGroup(ctx, const.BAG_KIND.BACKPACK, "Shown")
      database:SetActiveGroup(const.BAG_KIND.BACKPACK, group.id)
      local heard
      events:RegisterMessage("groups/Deleted", function(_, ...)
        heard = { args = { ... }, active = database:GetActiveGroup(const.BAG_KIND.BACKPACK) }
      end)
      groups:DeleteGroup(ctx, const.BAG_KIND.BACKPACK, group.id)
      assert.are.same({ group.id, "Shown", const.BAG_KIND.BACKPACK, true }, heard.args)
      assert.are.equal(1, heard.active)
    end)

    it("says a deleted group that was not shown was not", function()
      local ctx = context:New("Test")
      local shown = groups:CreateGroup(ctx, const.BAG_KIND.BACKPACK, "Shown")
      local other = groups:CreateGroup(ctx, const.BAG_KIND.BACKPACK, "Other")
      database:SetActiveGroup(const.BAG_KIND.BACKPACK, shown.id)
      local heard
      events:RegisterMessage("groups/Deleted", function(_, ...) heard = { ... } end)
      groups:DeleteGroup(ctx, const.BAG_KIND.BACKPACK, other.id)
      assert.are.same({ other.id, "Other", const.BAG_KIND.BACKPACK, false }, heard)
      assert.are.equal(shown.id, database:GetActiveGroup(const.BAG_KIND.BACKPACK))
    end)
  end)

  describe("RenameGroup", function()

    it("renames a group", function()
      local ctx = context:New("Test")
      local group = groups:CreateGroup(ctx, const.BAG_KIND.BACKPACK, "Old")
      groups:RenameGroup(ctx, const.BAG_KIND.BACKPACK, group.id, "New")
      local updated = groups:GetGroup(const.BAG_KIND.BACKPACK, group.id)
      assert.are.equal("New", updated.name)
    end)

    it("does nothing for non-existent groups", function()
      local ctx = context:New("Test")
      groups:RenameGroup(ctx, const.BAG_KIND.BACKPACK, 999, "X") -- should not error
    end)
  end)

  -- ─── IsDefaultGroup ─────────────────────────────────────────────────────────

  describe("IsDefaultGroup", function()

    it("returns true for backpack group ID 1", function()
      assert.is_true(groups:IsDefaultGroup(const.BAG_KIND.BACKPACK, 1))
    end)

    it("returns true for groups with isDefault flag", function()
      dbGroups[const.BAG_KIND.BANK] = {[5] = {id = 5, name = "Bank", isDefault = true}}
      assert.is_true(groups:IsDefaultGroup(const.BAG_KIND.BANK, 5))
    end)

    it("returns false for non-default groups", function()
      local ctx = context:New("Test")
      local group = groups:CreateGroup(ctx, const.BAG_KIND.BACKPACK, "Custom")
      assert.is_false(groups:IsDefaultGroup(const.BAG_KIND.BACKPACK, group.id))
    end)
  end)

  -- ─── Category Assignment ────────────────────────────────────────────────────

  describe("Category assignment", function()

    it("assigns a category to a group", function()
      local ctx = context:New("Test")
      local group = groups:CreateGroup(ctx, const.BAG_KIND.BACKPACK, "Weapons")
      groups:AssignCategoryToGroup(ctx, const.BAG_KIND.BACKPACK, "Swords", group.id)
      assert.are.equal(group.id, groups:GetGroupForCategory(const.BAG_KIND.BACKPACK, "Swords"))
    end)

    it("removes category assignment when assigned to default group", function()
      local ctx = context:New("Test")
      local group = groups:CreateGroup(ctx, const.BAG_KIND.BACKPACK, "Custom")
      groups:AssignCategoryToGroup(ctx, const.BAG_KIND.BACKPACK, "Cat", group.id)
      -- Assign to default group (ID 1) should remove the explicit assignment
      groups:AssignCategoryToGroup(ctx, const.BAG_KIND.BACKPACK, "Cat", 1)
      assert.is_nil(groups:GetGroupForCategory(const.BAG_KIND.BACKPACK, "Cat"))
    end)

    it("removes a category from its group", function()
      local ctx = context:New("Test")
      local group = groups:CreateGroup(ctx, const.BAG_KIND.BACKPACK, "G")
      groups:AssignCategoryToGroup(ctx, const.BAG_KIND.BACKPACK, "Cat", group.id)
      groups:RemoveCategoryFromGroup(ctx, const.BAG_KIND.BACKPACK, "Cat")
      assert.is_nil(groups:GetGroupForCategory(const.BAG_KIND.BACKPACK, "Cat"))
    end)

    it("does nothing when removing unassigned category", function()
      local ctx = context:New("Test")
      groups:RemoveCategoryFromGroup(ctx, const.BAG_KIND.BACKPACK, "Nobody") -- should not error
    end)
  end)

  -- ─── CategoryBelongsToGroup ─────────────────────────────────────────────────

  describe("CategoryBelongsToGroup", function()

    it("unassigned categories belong to default group", function()
      assert.is_true(groups:CategoryBelongsToGroup(const.BAG_KIND.BACKPACK, "Unassigned", 1))
    end)

    it("explicitly assigned categories belong to their group", function()
      local ctx = context:New("Test")
      local group = groups:CreateGroup(ctx, const.BAG_KIND.BACKPACK, "Custom")
      groups:AssignCategoryToGroup(ctx, const.BAG_KIND.BACKPACK, "Cat", group.id)
      assert.is_true(groups:CategoryBelongsToGroup(const.BAG_KIND.BACKPACK, "Cat", group.id))
    end)

    it("explicitly assigned categories do NOT belong to default", function()
      local ctx = context:New("Test")
      local group = groups:CreateGroup(ctx, const.BAG_KIND.BACKPACK, "Custom")
      groups:AssignCategoryToGroup(ctx, const.BAG_KIND.BACKPACK, "Cat", group.id)
      assert.is_false(groups:CategoryBelongsToGroup(const.BAG_KIND.BACKPACK, "Cat", 1))
    end)

    it("categories don't belong to groups they aren't assigned to", function()
      local ctx = context:New("Test")
      local g1 = groups:CreateGroup(ctx, const.BAG_KIND.BACKPACK, "G1")
      local g2 = groups:CreateGroup(ctx, const.BAG_KIND.BACKPACK, "G2")
      groups:AssignCategoryToGroup(ctx, const.BAG_KIND.BACKPACK, "Cat", g1.id)
      assert.is_false(groups:CategoryBelongsToGroup(const.BAG_KIND.BACKPACK, "Cat", g2.id))
    end)
  end)

  -- ─── Active Group ───────────────────────────────────────────────────────────

  describe("Active group", function()

    it("defaults to group 1", function()
      assert.are.equal(1, groups:GetActiveGroup(const.BAG_KIND.BACKPACK))
    end)

    it("sets and gets active group", function()
      local ctx = context:New("Test")
      local group = groups:CreateGroup(ctx, const.BAG_KIND.BACKPACK, "Custom")
      groups:SetActiveGroup(ctx, const.BAG_KIND.BACKPACK, group.id)
      assert.are.equal(group.id, groups:GetActiveGroup(const.BAG_KIND.BACKPACK))
    end)

    it("does nothing when setting to non-existent group", function()
      local ctx = context:New("Test")
      groups:SetActiveGroup(ctx, const.BAG_KIND.BACKPACK, 999) -- should not error
      -- Active group should remain default
      assert.are.equal(1, groups:GetActiveGroup(const.BAG_KIND.BACKPACK))
    end)
  end)

  -- ─── GetGroup ───────────────────────────────────────────────────────────────

  describe("GetGroup", function()

    it("returns nil for an unknown group ID", function()
      assert.is_nil(groups:GetGroup(const.BAG_KIND.BACKPACK, 9999))
    end)

    it("returns the default backpack group (ID 1)", function()
      dbGroups[const.BAG_KIND.BACKPACK] = dbGroups[const.BAG_KIND.BACKPACK] or {}
      dbGroups[const.BAG_KIND.BACKPACK][1] = {id = 1, name = "Backpack", isDefault = true}
      local g = groups:GetGroup(const.BAG_KIND.BACKPACK, 1)
      assert.is_not_nil(g)
      assert.are.equal("Backpack", g.name)
    end)
  end)

  -- ─── GetAllGroups ───────────────────────────────────────────────────────────

  describe("GetAllGroups", function()

    it("returns an empty table when no groups exist", function()
      assert.same({}, groups:GetAllGroups(const.BAG_KIND.BACKPACK))
    end)

    it("returns every group of a given kind", function()
      local ctx = context:New("Test")
      groups:CreateGroup(ctx, const.BAG_KIND.BACKPACK, "A")
      groups:CreateGroup(ctx, const.BAG_KIND.BACKPACK, "B")
      local all = groups:GetAllGroups(const.BAG_KIND.BACKPACK)
      local count = 0
      for _ in pairs(all) do count = count + 1 end
      assert.are.equal(2, count)
    end)
  end)

  -- ─── GetGroupForCategory ────────────────────────────────────────────────────

  describe("GetGroupForCategory", function()

    it("returns nil for an unassigned category", function()
      assert.is_nil(groups:GetGroupForCategory(const.BAG_KIND.BACKPACK, "Unassigned"))
    end)

    it("returns the assigned group ID", function()
      local ctx = context:New("Test")
      local group = groups:CreateGroup(ctx, const.BAG_KIND.BACKPACK, "G")
      groups:AssignCategoryToGroup(ctx, const.BAG_KIND.BACKPACK, "Cat", group.id)
      assert.are.equal(group.id, groups:GetGroupForCategory(const.BAG_KIND.BACKPACK, "Cat"))
    end)
  end)

  -- ─── GetCategoriesInGroup ───────────────────────────────────────────────────

  describe("GetCategoriesInGroup", function()

    it("returns the explicit list of categories in a group", function()
      local ctx = context:New("Test")
      local group = groups:CreateGroup(ctx, const.BAG_KIND.BACKPACK, "G")
      groups:AssignCategoryToGroup(ctx, const.BAG_KIND.BACKPACK, "A", group.id)
      groups:AssignCategoryToGroup(ctx, const.BAG_KIND.BACKPACK, "B", group.id)
      local cats = groups:GetCategoriesInGroup(const.BAG_KIND.BACKPACK, group.id)
      assert.is_true(cats["A"])
      assert.is_true(cats["B"])
    end)

    it("returns an empty table for a group with no categories", function()
      local ctx = context:New("Test")
      local group = groups:CreateGroup(ctx, const.BAG_KIND.BACKPACK, "Empty")
      assert.same({}, groups:GetCategoriesInGroup(const.BAG_KIND.BACKPACK, group.id))
    end)
  end)

  -- ─── GetDefaultBankGroup ────────────────────────────────────────────────────

  describe("GetDefaultBankGroup", function()

    it("returns nil when no default bank group exists", function()
      assert.is_nil(groups:GetDefaultBankGroup())
    end)

    it("returns the default character bank group", function()
      dbGroups[const.BAG_KIND.BANK] = {
        [10] = {id = 10, name = "Bank", isDefault = true, bankType = 1},
        [11] = {id = 11, name = "Warbank", isDefault = true, bankType = 2},
      }
      local g = groups:GetDefaultBankGroup()
      assert.is_not_nil(g)
      assert.are.equal("Bank", g.name)
    end)

    it("skips the warbank when looking for the character bank", function()
      dbGroups[const.BAG_KIND.BANK] = {
        [11] = {id = 11, name = "Warbank", isDefault = true, bankType = 2},
      }
      assert.is_nil(groups:GetDefaultBankGroup())
    end)
  end)

  -- ─── OnCategoryDeleted ──────────────────────────────────────────────────────

  describe("OnCategoryDeleted", function()

    it("removes the category from any group assignment across all bag kinds", function()
      local ctx = context:New("Test")
      local bg = groups:CreateGroup(ctx, const.BAG_KIND.BACKPACK, "BPGroup")
      local bng = groups:CreateGroup(ctx, const.BAG_KIND.BANK, "BankGroup")
      groups:AssignCategoryToGroup(ctx, const.BAG_KIND.BACKPACK, "Doomed", bg.id)
      groups:AssignCategoryToGroup(ctx, const.BAG_KIND.BANK, "Doomed", bng.id)
      assert.are.equal(bg.id, groups:GetGroupForCategory(const.BAG_KIND.BACKPACK, "Doomed"))
      assert.are.equal(bng.id, groups:GetGroupForCategory(const.BAG_KIND.BANK, "Doomed"))
      groups:OnCategoryDeleted(ctx, "Doomed")
      assert.is_nil(groups:GetGroupForCategory(const.BAG_KIND.BACKPACK, "Doomed"))
      assert.is_nil(groups:GetGroupForCategory(const.BAG_KIND.BANK, "Doomed"))
    end)

    it("is a no-op for categories that were never assigned", function()
      local ctx = context:New("Test")
      groups:OnCategoryDeleted(ctx, "NeverExisted") -- should not error
    end)
  end)

  -- ─── HiddenGroups (Hide Empty Groups, groups.md §3) ─────────────────────────

  -- Asked (#1321): "There should be an option in the settings to allow for hiding of empty layout groups."
  describe("HiddenGroups", function()
    local BACKPACK, BANK = const.BAG_KIND.BACKPACK, const.BAG_KIND.BANK

    before_each(function()
      dbHideEmpty[BACKPACK], dbHideEmpty[BANK] = true, true
    end)

    after_each(function()
      dbHideEmpty[BACKPACK], dbHideEmpty[BANK] = nil, nil
    end)

    -- tabsOf is a bag's data by tab, as items:Phase10_PartitionIntoTabs works it out: each tab's items counted.
    local function tabsOf(counts)
      local out = {}
      for id, n in pairs(counts) do out[id] = { items = {}, categories = {}, totalItems = n, hiddenItems = 0 } end
      return out
    end

    it("leaves out no group while it is off", function()
      dbHideEmpty[BACKPACK] = false
      local herbs = groups:CreateGroup(context:New("Test"), BACKPACK, "Herbs")
      assert.are.same({}, groups:HiddenGroups(BACKPACK, tabsOf({ [1] = 0, [herbs.id] = 0 }), 1))
    end)

    it("leaves out each group with nothing in it, never the default group nor the one shown", function()
      local ctx = context:New("Test")
      local herbs = groups:CreateGroup(ctx, BACKPACK, "Herbs")
      local ore = groups:CreateGroup(ctx, BACKPACK, "Ore")
      local made = groups:CreateGroup(ctx, BACKPACK, "Made Since")
      dbGroups[BACKPACK][1] = { id = 1, name = "Backpack" }
      -- Made since the data was worked out: no tab of its own in it yet, so nothing in it.
      local tabs = tabsOf({ [1] = 0, [herbs.id] = 0, [ore.id] = 3 })
      assert.are.same({ [herbs.id] = true, [made.id] = true }, groups:HiddenGroups(BACKPACK, tabs, 1))
      assert.are.same({ [made.id] = true }, groups:HiddenGroups(BACKPACK, tabs, herbs.id), "the group shown stays")
    end)

    -- A tab's count leaves out what a category hides in the bag (items:Phase10_PartitionIntoTabs): such a group shows
    -- nothing, and counts as empty (asked: "count hidden groups as empty").
    it("counts a group whose only items a category hides as empty", function()
      local herbs = groups:CreateGroup(context:New("Test"), BACKPACK, "Herbs")
      local tabs = tabsOf({ [1] = 2, [herbs.id] = 0 })
      tabs[herbs.id].hiddenItems = 4
      assert.are.same({ [herbs.id] = true }, groups:HiddenGroups(BACKPACK, tabs, 1))
    end)

    it("never leaves out the bank's default groups", function()
      local ctx = context:New("Test")
      local bank = groups:CreateGroup(ctx, BANK, "Bank", Enum.BankType.Character)
      dbGroups[BANK][bank.id].isDefault = true
      local warbank = groups:CreateGroup(ctx, BANK, "Warbank", Enum.BankType.Account)
      dbGroups[BANK][warbank.id].isDefault = true
      local vault = groups:CreateGroup(ctx, BANK, "Vault", Enum.BankType.Character)
      local tabs = tabsOf({ [bank.id] = 0, [warbank.id] = 0, [vault.id] = 0 })
      assert.are.same({ [vault.id] = true }, groups:HiddenGroups(BANK, tabs, bank.id))
    end)

    -- The bank's data before its first read after it opens has no tabs (items:ClearBankCache).
    it("leaves out none before the bag's data was first worked out", function()
      groups:CreateGroup(context:New("Test"), BACKPACK, "Herbs")
      assert.are.same({}, groups:HiddenGroups(BACKPACK, nil, 1))
    end)

    -- A section dropped on an empty group's tab: the next recalculation puts its items there, and its tab stays until
    -- then rather than going and coming back.
    it("keeps a group a category was assigned to until the bag's data is worked out again", function()
      local ctx = context:New("Test")
      local herbs = groups:CreateGroup(ctx, BACKPACK, "Herbs")
      local tabs = tabsOf({ [1] = 5, [herbs.id] = 0 })
      slotInfo = { [BACKPACK] = { tabs = tabs } }
      groups:AssignCategoryToGroup(ctx, BACKPACK, "Herbalism", herbs.id)
      assert.are.same({}, groups:HiddenGroups(BACKPACK, tabs, 1))
      local again = tabsOf({ [1] = 5, [herbs.id] = 0 })
      slotInfo = { [BACKPACK] = { tabs = again } }
      assert.are.same({ [herbs.id] = true }, groups:HiddenGroups(BACKPACK, again, 1), "nothing came")
    end)

    it("keeps no group for a category assigned to another bag's group", function()
      local ctx = context:New("Test")
      local herbs = groups:CreateGroup(ctx, BACKPACK, "Herbs")
      local vault = groups:CreateGroup(ctx, BANK, "Vault")
      local tabs = tabsOf({ [1] = 5, [herbs.id] = 0 })
      slotInfo = { [BACKPACK] = { tabs = tabs }, [BANK] = { tabs = tabsOf({ [vault.id] = 0 }) } }
      groups:AssignCategoryToGroup(ctx, BANK, "Herbalism", vault.id)
      assert.are.same({ [herbs.id] = true }, groups:HiddenGroups(BACKPACK, tabs, 1))
    end)

    it("says whether two sets of groups name the same groups", function()
      assert.is_true(groups:SameGroups({}, {}))
      assert.is_true(groups:SameGroups({ [2] = true, [3] = true }, { [3] = true, [2] = true }))
      assert.is_false(groups:SameGroups({ [2] = true }, { [3] = true }))
      assert.is_false(groups:SameGroups({ [2] = true }, { [2] = true, [3] = true }))
      assert.is_false(groups:SameGroups({ [2] = true, [3] = true }, { [2] = true }))
    end)
  end)
end)
