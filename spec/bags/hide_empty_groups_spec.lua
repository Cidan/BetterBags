-- hide_empty_groups_spec.lua -- Hide Empty Groups on the classic bags (#1321, groups.md §3), against the real Database,
-- Groups and tab bar: a group with nothing in the data last drawn has no tab, unless it is a default group or the one
-- shown; every group's tab shows while a section is dragged; and the tab a section was dropped on stays until the bag is
-- worked out again.
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
trackStub("Question")
for _, name in ipairs({ "BagSlots", "SearchBox", "Currency", "MoneyFrame", "ContextMenu", "SectionFrame" }) do
  trackStub(name)
end

local BACKPACK, BANK = 0, 1

-- Messages go to the handlers registered since the test began, at once, as AceEvent sends them.
local handlers = {}
override(events, "RegisterMessage", function(_, name, fn)
  handlers[name] = handlers[name] or {}
  table.insert(handlers[name], fn)
end)
override(events, "SendMessage", function(_, ctx, name, ...)
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
local SECTION_GRID, SECTION_ALL_BAGS = 2, 4
override(const, "BAG_VIEW", { SECTION_GRID = SECTION_GRID, SECTION_ALL_BAGS = SECTION_ALL_BAGS })
override(const, "DATABASE_DEFAULTS", {
  profile = {
    views = { [BACKPACK] = SECTION_GRID, [BANK] = SECTION_GRID },
    groups = { [BACKPACK] = { [1] = { id = 1, name = "Backpack", order = 1, kind = BACKPACK, isDefault = true } }, [BANK] = {} },
    groupCounter = { [BACKPACK] = 1, [BANK] = 0 },
    categoryToGroup = { [BACKPACK] = {}, [BANK] = { [Enum.BankType.Character] = {}, [Enum.BankType.Account] = {} } },
    activeGroup = { [BACKPACK] = 1, [BANK] = 1 },
    groupsEnabled = { [BACKPACK] = true, [BANK] = true },
    hideEmptyGroups = { [BACKPACK] = false, [BANK] = false },
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

describe("Hiding empty groups' tabs on a classic bag", function()
  local data

  before_each(function()
    DB.data:ResetProfile(false, true)
    handlers = {}
    data = {}
    override(items, "GetAllSlotInfo", function() return data end)
    override(addon, "TriggerItemContextChanged", function() end)
  end)

  after_each(function()
    restore(fileOverrides)
  end)

  teardown(function()
    restore()
    for _, name in ipairs({ "BankBehavior", "BackpackBehavior", "Tabs", "Groups", "Database" }) do
      ResetModuleStub(name)
    end
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  local function ctx() return context:New("spec") end

  -- tabsOf is a bag's data by tab, as items:Phase10_PartitionIntoTabs works it out: each tab's items counted.
  local function tabsOf(counts)
    local out = {}
    for id, n in pairs(counts) do out[id] = { items = {}, categories = {}, totalItems = n, hiddenItems = 0 } end
    return out
  end

  -- A bag as frames/bag.lua makes it, as far as the behaviors reach: its Draw says it rendered, as the real one does
  -- once it has laid its window out (bag/Rendered).
  local function makeBag(kind, name)
    local frame = CreateFrame("Frame", name)
    local bag = { kind = kind, frame = frame, currentItemCount = 0 }
    function bag:Draw(drawCtx, slotInfo, callback)
      events:SendMessage(drawCtx, "bag/Rendered", self, slotInfo)
      callback()
    end
    function bag:SetTitle() end
    bag.tabs = tabs:Create(frame, kind)
    return bag
  end

  local function drawn(bag, slotInfo)
    data[bag.kind] = slotInfo
    bag:Draw(ctx(), slotInfo, function() end)
  end

  local function tabShown(bag, id)
    for _, tab in pairs(bag.tabs.tabIndex) do
      if tab.id == id then return tab:IsShown() end
    end
    return false
  end

  local function selectedTab(bag)
    local tab = bag.tabs.tabIndex[bag.tabs.selectedTab]
    return tab and tab.id
  end

  describe("the backpack", function()
    local herbs, ore

    local function backpack()
      local bag = makeBag(BACKPACK, "BetterBagsHideEmptyBackpack")
      local behavior = backpackBehavior:Create(bag)
      bag.behavior = behavior
      behavior:RegisterEvents()
      herbs = groups:CreateGroup(ctx(), BACKPACK, "Herbs")
      ore = groups:CreateGroup(ctx(), BACKPACK, "Ore")
      behavior:GenerateGroupTabs(ctx())
      return bag, behavior
    end

    it("hides the tab of a group with nothing in it once drawn, never Backpack, the group shown nor +", function()
      DB:SetHideEmptyGroups(BACKPACK, true)
      local bag = backpack()
      assert.is_true(tabShown(bag, herbs.id), "nothing drawn yet")
      drawn(bag, { tabs = tabsOf({ [1] = 0, [herbs.id] = 0, [ore.id] = 2 }) })
      assert.is_false(tabShown(bag, herbs.id))
      assert.is_true(tabShown(bag, ore.id))
      assert.is_true(tabShown(bag, 1))
      assert.is_true(tabShown(bag, 0))
      assert.are.equal(1, selectedTab(bag))
    end)

    it("shows every group's tab while it is off, and hides the empty ones once it is turned on", function()
      local bag = backpack()
      drawn(bag, { tabs = tabsOf({ [1] = 0, [herbs.id] = 0, [ore.id] = 2 }) })
      assert.is_true(tabShown(bag, herbs.id))
      DB:SetHideEmptyGroups(BACKPACK, true)
      events:SendMessage(ctx(), "groups/HideEmptyChanged", BANK, true)
      assert.is_true(tabShown(bag, herbs.id), "the bank's")
      events:SendMessage(ctx(), "groups/HideEmptyChanged", BACKPACK, true)
      assert.is_false(tabShown(bag, herbs.id))
    end)

    it("hides the group it showed once it shows another", function()
      DB:SetHideEmptyGroups(BACKPACK, true)
      local bag, behavior = backpack()
      data[BACKPACK] = { tabs = tabsOf({ [1] = 3, [herbs.id] = 0, [ore.id] = 2 }) }
      behavior:SwitchToGroup(ctx(), herbs.id)
      assert.is_true(tabShown(bag, herbs.id), "the group shown stays")
      assert.are.equal(herbs.id, selectedTab(bag))
      behavior:SwitchToGroup(ctx(), 1)
      assert.is_false(tabShown(bag, herbs.id))
      assert.are.equal(1, selectedTab(bag))
    end)

    it("shows every group's tab while a section is dragged, and hides the empty ones after", function()
      DB:SetHideEmptyGroups(BACKPACK, true)
      local bag, behavior = backpack()
      drawn(bag, { tabs = tabsOf({ [1] = 3, [herbs.id] = 0, [ore.id] = 0 }) })
      behavior:RevealGroups(ctx(), true)
      assert.is_true(tabShown(bag, herbs.id))
      assert.is_true(tabShown(bag, ore.id))
      drawn(bag, data[BACKPACK])
      assert.is_true(tabShown(bag, herbs.id), "a draw meanwhile keeps them")
      behavior:RevealGroups(ctx(), false)
      assert.is_false(tabShown(bag, herbs.id))
      assert.is_false(tabShown(bag, ore.id))
    end)

    it("keeps the tab a section was dropped on until the bag is drawn again", function()
      DB:SetHideEmptyGroups(BACKPACK, true)
      local bag, behavior = backpack()
      drawn(bag, { tabs = tabsOf({ [1] = 3, [herbs.id] = 0, [ore.id] = 0 }) })
      behavior:RevealGroups(ctx(), true)
      groups:AssignCategoryToGroup(ctx(), BACKPACK, "Herbalism", herbs.id)
      behavior:RevealGroups(ctx(), false)
      assert.is_true(tabShown(bag, herbs.id))
      assert.is_false(tabShown(bag, ore.id))
      drawn(bag, { tabs = tabsOf({ [1] = 3, [herbs.id] = 2, [ore.id] = 0 }) })
      assert.is_true(tabShown(bag, herbs.id), "its items came")
      drawn(bag, { tabs = tabsOf({ [1] = 5, [herbs.id] = 0, [ore.id] = 0 }) })
      assert.is_false(tabShown(bag, herbs.id))
    end)

    -- Data never read has no tabs: the tabs follow the last data that had them.
    it("keeps the tabs it hid while it draws data with no tabs", function()
      DB:SetHideEmptyGroups(BACKPACK, true)
      local bag = backpack()
      drawn(bag, { tabs = tabsOf({ [1] = 3, [herbs.id] = 0, [ore.id] = 2 }) })
      drawn(bag, {})
      assert.is_false(tabShown(bag, herbs.id))
      assert.is_true(tabShown(bag, ore.id))
    end)

    it("shows a group's tab again once something is in it", function()
      DB:SetHideEmptyGroups(BACKPACK, true)
      local bag = backpack()
      drawn(bag, { tabs = tabsOf({ [1] = 3, [herbs.id] = 0, [ore.id] = 2 }) })
      drawn(bag, { tabs = tabsOf({ [1] = 3, [herbs.id] = 1, [ore.id] = 2 }) })
      assert.is_true(tabShown(bag, herbs.id))
    end)

    -- Found by the bug review: Show Bags (its slots panel shown, the tab bar hidden) counts every item in every tab
    -- (data/items.lua, ItemBelongsToTab), and the tabs it listed there were never shown or hidden, so a group that filled
    -- meanwhile kept its tab hidden once Show Bags was off.
    it("shows the tab of a group that filled while Show Bags was on, once it is off", function()
      DB:SetHideEmptyGroups(BACKPACK, true)
      local bag, behavior = backpack()
      local slotsShown = false
      bag.slots = { IsShown = function() return slotsShown end }
      drawn(bag, { tabs = tabsOf({ [1] = 3, [herbs.id] = 0, [ore.id] = 2 }) })
      assert.is_false(tabShown(bag, herbs.id))
      DB:SetBagView(BACKPACK, SECTION_ALL_BAGS)
      slotsShown = true
      behavior:GenerateGroupTabs(ctx())
      drawn(bag, { tabs = tabsOf({ [1] = 6, [herbs.id] = 6, [ore.id] = 6 }) })
      DB:SetBagView(BACKPACK, SECTION_GRID)
      slotsShown = false
      drawn(bag, { tabs = tabsOf({ [1] = 3, [herbs.id] = 1, [ore.id] = 2 }) })
      assert.is_true(tabShown(bag, herbs.id))
    end)

    -- Found by the second bug review: turning Show Bags off (ContextMenu:ToggleBagSlots) hides its slots panel, which
    -- fades out (0.1 s) still shown, and recalculates the bag, which draws within that fade; the panel shows the tab bar
    -- again once it has hidden (BagSlots:OnClose).
    it("shows the tab of a group that filled while Show Bags was on, drawn as its slots panel fades out", function()
      DB:SetHideEmptyGroups(BACKPACK, true)
      local bag = backpack()
      local slotsShown = false
      bag.slots = { IsShown = function() return slotsShown end }
      drawn(bag, { tabs = tabsOf({ [1] = 3, [herbs.id] = 0, [ore.id] = 2 }) })
      assert.is_false(tabShown(bag, herbs.id))
      DB:SetBagView(BACKPACK, SECTION_ALL_BAGS)
      slotsShown = true
      bag.tabs.frame:Hide()
      drawn(bag, { tabs = tabsOf({ [1] = 6, [herbs.id] = 6, [ore.id] = 6 }) })
      DB:SetBagView(BACKPACK, SECTION_GRID)
      drawn(bag, { tabs = tabsOf({ [1] = 3, [herbs.id] = 1, [ore.id] = 2 }) })
      assert.is_false(bag.tabs.frame:IsShown(), "not while its slots panel shows")
      slotsShown = false
      bag.tabs.frame:Show()
      assert.is_true(tabShown(bag, herbs.id))
    end)
  end)

  describe("the bank", function()
    local bankID, warbankID, vault

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
      vault = groups:CreateGroup(ctx(), BANK, "Vault", Enum.BankType.Character)
    end)

    local function bank()
      local bag = makeBag(BANK, "BetterBagsHideEmptyBank")
      local behavior = bankBehavior:Create(bag)
      behavior.UpdatePurchaseBankButton = function() end
      bag.behavior = behavior
      behavior:RegisterEvents()
      behavior:GenerateGroupTabs(ctx())
      return bag, behavior
    end

    it("hides an empty bank group's tab, never the Bank's nor the Warbank's", function()
      DB:SetHideEmptyGroups(BANK, true)
      local bag = bank()
      drawn(bag, { tabs = tabsOf({ [bankID] = 0, [warbankID] = 0, [vault.id] = 0 }) })
      assert.is_false(tabShown(bag, vault.id))
      assert.is_true(tabShown(bag, bankID))
      assert.is_true(tabShown(bag, warbankID))
    end)

    it("shows every group's tab while a section is dragged", function()
      DB:SetHideEmptyGroups(BANK, true)
      local bag, behavior = bank()
      drawn(bag, { tabs = tabsOf({ [bankID] = 4, [warbankID] = 0, [vault.id] = 0 }) })
      behavior:RevealGroups(ctx(), true)
      assert.is_true(tabShown(bag, vault.id))
      behavior:RevealGroups(ctx(), false)
      assert.is_false(tabShown(bag, vault.id))
    end)

    -- Blizzard's bank tabs split the data by bag (data/items.lua, GetPossibleTabIDs), never by group.
    it("hides no group's tab while it shows Blizzard's bank tabs", function()
      DB:SetHideEmptyGroups(BANK, true)
      local bag, behavior = bank()
      drawn(bag, { tabs = tabsOf({ [bankID] = 4, [warbankID] = 0, [vault.id] = 0 }) })
      assert.is_false(tabShown(bag, vault.id))
      DB:SetShowBankTabs(true)
      behavior:GenerateGroupTabs(ctx())
      assert.is_true(tabShown(bag, vault.id))
    end)

    -- Found by the third bug review: turning Blizzard's bank tabs off (ContextMenu:ToggleBagSlots) sets the setting and
    -- the view, then hides their panel, which fades out still shown; the recalculation draws within the fade, and the
    -- panel shows the tab bar once it has hidden (BankSlots:OnClose).
    -- The fourth bug review: by its fade (Window:IsClosing), never by its being shown, which a panel the bank's Escape
    -- left shown still is (frames/bag.lua Hide returns early for a window already hidden).
    it("keeps its tab bar hidden while Blizzard's bank tabs fade out, drawn then", function()
      DB:SetHideEmptyGroups(BANK, true)
      local bag, behavior = bank()
      local closing = false
      bag.slots = { window = { IsClosing = function() return closing end } }
      DB:SetShowBankTabs(true)
      DB:SetBagView(BANK, SECTION_ALL_BAGS)
      behavior:GenerateGroupTabs(ctx())
      assert.is_false(bag.tabs.frame:IsShown())
      DB:SetShowBankTabs(false)
      DB:SetBagView(BANK, SECTION_GRID)
      closing = true
      drawn(bag, { tabs = tabsOf({ [bankID] = 4, [warbankID] = 0, [vault.id] = 0 }) })
      assert.is_false(bag.tabs.frame:IsShown(), "not while the panel fades out")
      assert.is_false(tabShown(bag, vault.id))
      closing = false
      behavior:GenerateGroupTabs(ctx())
      assert.is_true(bag.tabs.frame:IsShown(), "a panel not fading leaves it shown")
    end)

    -- The bank's data is cleared when it closes, and has no tabs until it is read again (items:ClearBankCache).
    it("keeps the tabs it hid while it draws data with no tabs", function()
      DB:SetHideEmptyGroups(BANK, true)
      local bag = bank()
      drawn(bag, { tabs = tabsOf({ [bankID] = 4, [warbankID] = 0, [vault.id] = 0 }) })
      drawn(bag, {})
      assert.is_false(tabShown(bag, vault.id))
    end)
  end)
end)
