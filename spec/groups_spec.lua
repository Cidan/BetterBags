-- groups_spec.lua -- Unit tests for data/groups.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")

local context = addon:GetModule("Context")
local events = addon:GetModule("Events")
events:OnInitialize()

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
database.DeleteGroup = function(_, kind, groupID)
  if dbGroups[kind] then dbGroups[kind][groupID] = nil end
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

-- Stub Enum for GetDefaultBankGroup
_G.Enum = _G.Enum or {}
_G.Enum.BankType = _G.Enum.BankType or {Character = 1, Account = 2}

LoadBetterBagsModule("data/groups.lua")
local groups = addon:GetModule("Groups")

describe("Groups", function()

  before_each(function()
    for k in pairs(dbGroups) do dbGroups[k] = nil end
    for k in pairs(dbCategoryGroups) do dbCategoryGroups[k] = nil end
    for k in pairs(dbActiveGroups) do dbActiveGroups[k] = nil end
    nextGroupID = 100
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
end)
