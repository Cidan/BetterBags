-- group_delete_spec.lua -- Deleting a group from a classic bag's tab menu (#1265), against the real
-- Database and Groups. DB:DeleteGroup moves the active group to the default before Groups sends
-- groups/Deleted, so the message says whether the deleted group was the one shown: the bag then shows
-- the default group, drawn, and the confirm recalculates the bag, so the deleted group's categories
-- are on the default group's tab (groups.md).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

-- Every function this spec replaces, put back after each test or when the file ends.
local replaced = {}
local function override(tbl, key, value)
  table.insert(replaced, { tbl, key, rawget(tbl, key) })
  tbl[key] = value
end
local function restore(upTo)
  for i = #replaced, (upTo or 0) + 1, -1 do
    replaced[i][1][replaced[i][2]] = replaced[i][3]
    replaced[i] = nil
  end
end

local L = trackStub("Localization")
local const = trackStub("Constants")
local events = trackStub("Events")
local debug = trackStub("Debug")
local items = trackStub("Items")
local question = trackStub("Question")
for _, name in ipairs({ "BagSlots", "SearchBox", "Currency", "MoneyFrame", "ContextMenu", "SectionFrame" }) do
  trackStub(name)
end

local BACKPACK, BANK = 0, 1

-- Messages go to the handlers registered since the test began, at once, as AceEvent sends them.
local handlers, sent = {}, {}
override(events, "RegisterMessage", function(_, name, fn)
  handlers[name] = handlers[name] or {}
  table.insert(handlers[name], fn)
end)
override(events, "SendMessage", function(_, ctx, name, ...)
  table.insert(sent, { name, ... })
  for _, fn in ipairs(handlers[name] or {}) do
    fn(ctx, ...)
  end
end)
override(events, "RegisterEvent", function() end)
override(events, "BucketEvent", function() end)
override(L, "G", function(_, key) return key end)
override(debug, "Log", function() end)
override(const, "BAG_KIND", { BACKPACK = BACKPACK, BANK = BANK, UNDEFINED = -1 })
override(const, "OFFSETS", { BAG_LEFT_INSET = 6, BAG_RIGHT_INSET = -6 })
override(const, "DATABASE_DEFAULTS", {
  profile = {
    groups = { [BACKPACK] = { [1] = { id = 1, name = "Backpack", order = 1, kind = BACKPACK, isDefault = true } }, [BANK] = {} },
    groupCounter = { [BACKPACK] = 1, [BANK] = 0 },
    categoryToGroup = { [BACKPACK] = {}, [BANK] = { [Enum.BankType.Character] = {}, [Enum.BankType.Account] = {} } },
    activeGroup = { [BACKPACK] = 1, [BANK] = 1 },
    groupsEnabled = { [BACKPACK] = true, [BANK] = true },
    showBankTabs = false,
  },
  char = {},
  global = {},
})
local fileOverrides = #replaced

LoadBetterBagsModule("core/context.lua")
ResetModuleStub("Database", "core/database.lua")
LoadBetterBagsModule("core/database.lua")
ResetModuleStub("Groups", "data/groups.lua")
LoadBetterBagsModule("data/groups.lua")
LoadBetterBagsModule("core/async.lua")
LoadBetterBagsModule("sonata/engine.lua")
LoadBetterBagsModule("sonata/apply.lua")
LoadBetterBagsModule("sonata/elements.lua")
addon:GetModule("Sonata"):Init()
ResetModuleStub("Tabs", "frames/tabs.lua")
LoadBetterBagsModule("frames/tabs.lua")
addon:GetModule("Tabs"):Init()
ResetModuleStub("BackpackBehavior", "bags/backpack.lua")
LoadBetterBagsModule("bags/backpack.lua")
ResetModuleStub("BankBehavior", "bags/bank.lua")
LoadBetterBagsModule("bags/bank.lua")

local context = addon:GetModule("Context")
local DB = addon:GetModule("Database")
local groups = addon:GetModule("Groups")
local tabs = addon:GetModule("Tabs")
local backpackBehavior = addon:GetModule("BackpackBehavior")
local bankBehavior = addon:GetModule("BankBehavior")

DB.Migrate = function() end
DB:Init()

local backpackSlots, bankSlots = { "backpack slot info" }, { "bank slot info" }

describe("Deleting a group from a classic bag", function()
  before_each(function()
    DB.data:ResetProfile(false, true)
    handlers, sent = {}, {}
    override(items, "GetAllSlotInfo", function() return { [BACKPACK] = backpackSlots, [BANK] = bankSlots } end)
    override(addon, "TriggerItemContextChanged", function() end)
    override(_G.StaticPopupDialogs, "BETTERBAGS_DELETE_GROUP", nil)
  end)

  after_each(function()
    restore(fileOverrides)
  end)

  local function ctx() return context:New("spec") end

  -- A bag as frames/bag.lua makes it, as far as the behaviors reach: it records what it draws (the group
  -- the active group says, as GetCurrentTabID reads it) and its title.
  local function makeBag(kind, name)
    local frame = CreateFrame("Frame", name)
    local bag = { kind = kind, frame = frame, currentItemCount = 0, draws = {}, titles = {} }
    function bag:Draw(_, slotInfo, callback)
      table.insert(self.draws, { group = DB:GetActiveGroup(kind), slotInfo = slotInfo })
      callback()
    end
    function bag:SetTitle(title) table.insert(self.titles, title) end
    bag.tabs = tabs:Create(frame, kind)
    return bag
  end

  local function drawnGroups(bag)
    local out = {}
    for _, draw in ipairs(bag.draws) do table.insert(out, draw.group) end
    return out
  end

  local function selectedTab(bag)
    local tab = bag.tabs.tabIndex[bag.tabs.selectedTab]
    return tab and tab.id
  end

  local function tabShown(bag, id)
    for _, tab in pairs(bag.tabs.tabIndex) do
      if tab.id == id then return tab:IsShown() end
    end
    return false
  end

  local function sentNamed(name)
    local out = {}
    for _, m in ipairs(sent) do
      if m[1] == name then table.insert(out, m) end
    end
    return out
  end

  describe("the backpack", function()
    local function backpack()
      local bag = makeBag(BACKPACK, "BetterBagsGroupDeleteBackpack")
      local behavior = backpackBehavior:Create(bag)
      bag.behavior = behavior
      behavior:RegisterEvents()
      behavior:GenerateGroupTabs(ctx())
      return bag, behavior
    end

    -- What the group's tab menu does: Delete Group, then Delete in its confirmation.
    local function confirmDelete(behavior, id)
      behavior:ShowDeleteGroupConfirm(id)
      local popup = _G._lastPopupShown
      assert.are.equal("BETTERBAGS_DELETE_GROUP", popup.name)
      StaticPopupDialogs[popup.name].OnAccept({ data = popup.args[3] })
    end

    it("shows Backpack, drawn, when the group it shows is deleted, and recalculates it", function()
      local bag, behavior = backpack()
      local herbs = groups:CreateGroup(ctx(), BACKPACK, "Herbs")
      groups:AssignCategoryToGroup(ctx(), BACKPACK, "Herbalism", herbs.id)
      behavior:SwitchToGroup(ctx(), herbs.id)
      bag.draws, sent = {}, {}
      confirmDelete(behavior, herbs.id)
      assert.are.equal(1, DB:GetActiveGroup(BACKPACK))
      assert.are.same({ 1 }, drawnGroups(bag), "the Backpack group, drawn once")
      assert.are.equal(backpackSlots, bag.draws[1].slotInfo)
      assert.are.equal(1, selectedTab(bag))
      assert.is_false(tabShown(bag, herbs.id))
      assert.is_true(groups:CategoryBelongsToGroup(BACKPACK, "Herbalism", 1))
      assert.are.same({ { "bags/Rederive", { backpack = true, bank = false, resetLayout = true } } }, sentNamed("bags/Rederive"))
    end)

    it("keeps the group it shows when another group is deleted, and recalculates it", function()
      local bag, behavior = backpack()
      local herbs = groups:CreateGroup(ctx(), BACKPACK, "Herbs")
      local ore = groups:CreateGroup(ctx(), BACKPACK, "Ore")
      behavior:SwitchToGroup(ctx(), ore.id)
      bag.draws, sent = {}, {}
      confirmDelete(behavior, herbs.id)
      assert.are.equal(ore.id, DB:GetActiveGroup(BACKPACK))
      assert.are.same({}, bag.draws, "drawn by the recalculation")
      assert.are.equal(ore.id, selectedTab(bag))
      assert.is_false(tabShown(bag, herbs.id))
      assert.is_true(tabShown(bag, ore.id))
      assert.are.same({ { "bags/Rederive", { backpack = true, bank = false, resetLayout = true } } }, sentNamed("bags/Rederive"))
    end)

    it("keeps the group it shows when a group is renamed", function()
      local bag, behavior = backpack()
      local herbs = groups:CreateGroup(ctx(), BACKPACK, "Herbs")
      behavior:SwitchToGroup(ctx(), herbs.id)
      groups:RenameGroup(ctx(), BACKPACK, herbs.id, "Reagents")
      assert.are.equal(herbs.id, DB:GetActiveGroup(BACKPACK))
      assert.are.equal(herbs.id, selectedTab(bag))
      assert.are.equal("Reagents", bag.tabs:GetTabNameByID(herbs.id))
    end)

    it("shows Backpack when the group it last showed is gone", function()
      local bag = backpack()
      DB:SetActiveGroup(BACKPACK, 99)
      bag.behavior:GenerateGroupTabs(ctx())
      assert.are.equal(1, DB:GetActiveGroup(BACKPACK))
      assert.are.equal(1, selectedTab(bag))
    end)

    it("shows the group it showed last when it is made", function()
      override(addon:GetModule("SearchBox"), "Create", function() return CreateFrame("Frame") end)
      override(addon:GetModule("BagSlots"), "CreatePanel", function() return nil end)
      override(addon:GetModule("Currency"), "CreateIconGrid", function() return CreateFrame("Frame") end)
      local herbs = groups:CreateGroup(ctx(), BACKPACK, "Herbs")
      DB:SetActiveGroup(BACKPACK, herbs.id)
      local bag = { kind = BACKPACK, frame = CreateFrame("Frame", "BetterBagsGroupDeleteMade") }
      backpackBehavior:Create(bag):OnCreate(ctx())
      assert.are.equal(herbs.id, DB:GetActiveGroup(BACKPACK))
      assert.are.equal(herbs.id, selectedTab(bag))
    end)
  end)

  describe("the bank", function()
    local bankID, warbankID

    before_each(function()
      override(addon, "isRetail", true)
      override(addon, "atBank", true)
      -- Live retail bag indices (Blizzard_APIDocumentationGenerated/BagIndexConstantsDocumentation.lua).
      override(Enum.BagIndex, "Characterbanktab", -2)
      override(Enum.BagIndex, "AccountBankTab_1", 12)
      -- The default bank groups Migrate seeds (core/database.lua).
      bankID = DB:CreateGroup(BANK, "Bank", Enum.BankType.Character)
      DB.data.profile.groups[BANK][bankID].isDefault = true
      warbankID = DB:CreateGroup(BANK, "Warbank", Enum.BankType.Account)
      DB.data.profile.groups[BANK][warbankID].isDefault = true
      DB:SetActiveGroup(BANK, bankID)
    end)

    local function bank()
      local bag = makeBag(BANK, "BetterBagsGroupDeleteBank")
      local behavior = bankBehavior:Create(bag)
      behavior.UpdatePurchaseBankButton = function() end
      bag.behavior = behavior
      behavior:RegisterEvents()
      behavior:GenerateGroupTabs(ctx())
      return bag, behavior
    end

    -- What the group's tab menu does: Delete Group, then Yes in its question.
    local function confirmDelete(behavior, id)
      local yes
      override(question, "YesNo", function(_, _, _, onYes) yes = onYes end)
      behavior:ShowDeleteGroupConfirm(id)
      yes()
    end

    it("shows the default bank group, drawn, when the group it shows is deleted, and recalculates it", function()
      local bag, behavior = bank()
      local mats = groups:CreateGroup(ctx(), BANK, "Mats", Enum.BankType.Character)
      groups:AssignCategoryToGroup(ctx(), BANK, "Cloth", mats.id)
      behavior:SwitchToGroup(ctx(), mats.id)
      bag.draws, bag.titles, sent = {}, {}, {}
      confirmDelete(behavior, mats.id)
      assert.are.equal(bankID, DB:GetActiveGroup(BANK))
      assert.are.same({ bankID }, drawnGroups(bag), "the default bank group, drawn once")
      assert.are.equal(bankSlots, bag.draws[1].slotInfo)
      assert.are.same({ "Bank" }, bag.titles)
      assert.are.equal(bankID, selectedTab(bag))
      assert.is_false(tabShown(bag, mats.id))
      assert.is_true(groups:CategoryBelongsToGroup(BANK, "Cloth", bankID))
      assert.are.same({
        { "bags/Rederive", { backpack = true, bank = false, categoriesUnchanged = true } },
        { "bags/Rederive", { backpack = false, bank = true, resetLayout = true } },
      }, sentNamed("bags/Rederive"), "the backpack's grey-out for the bank type, then the bank")
    end)

    it("shows the character bank when the Warbank group it shows is deleted", function()
      local bag, behavior = bank()
      local gems = groups:CreateGroup(ctx(), BANK, "Gems", Enum.BankType.Account)
      behavior:SwitchToGroup(ctx(), gems.id)
      assert.are.equal(12, bag.bankTab)
      bag.titles = {}
      confirmDelete(behavior, gems.id)
      assert.are.equal(bankID, DB:GetActiveGroup(BANK))
      assert.are.equal(-2, bag.bankTab)
      assert.are.same({ "Bank" }, bag.titles)
    end)

    it("keeps the group it shows when another group is deleted, and recalculates it", function()
      local bag, behavior = bank()
      local mats = groups:CreateGroup(ctx(), BANK, "Mats", Enum.BankType.Character)
      behavior:SwitchToGroup(ctx(), warbankID)
      bag.draws, bag.titles, sent = {}, {}, {}
      confirmDelete(behavior, mats.id)
      assert.are.equal(warbankID, DB:GetActiveGroup(BANK))
      assert.are.same({}, bag.draws, "drawn by the recalculation")
      assert.are.same({}, bag.titles)
      assert.are.equal(12, bag.bankTab)
      assert.are.equal(warbankID, selectedTab(bag))
      assert.are.same({ { "bags/Rederive", { backpack = false, bank = true, resetLayout = true } } }, sentNamed("bags/Rederive"))
    end)
  end)
end)

teardown(function()
  restore()
  for _, m in ipairs({ "BankBehavior", "BackpackBehavior", "Tabs", "Groups", "Database" }) do
    ResetModuleStub(m)
  end
  for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
end)
