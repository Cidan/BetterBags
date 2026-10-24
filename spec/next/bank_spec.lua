-- bank_spec.lua -- NextBank (next/bank.lua): BetterBagsNext's bank. The backpack's panel mirrored on
-- the left of the screen, doing everything the classic retail, WoW: Forever and Classic banks do:
-- groups and the Warbank, Blizzard's bank tabs, bag sockets, purchases, deposits, sorting, money,
-- and opening and closing the bank (next.md §6).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")

local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local const = trackStub("Constants")
const.BAG_KIND = const.BAG_KIND or { BACKPACK = 0, BANK = 1 }
local BANK = const.BAG_KIND.BANK

local stubs = {
  L = trackStub("Localization"),
  itemFrame = trackStub("ItemFrame"),
  items = trackStub("Items"),
  database = trackStub("Database"),
  groups = trackStub("Groups"),
  events = trackStub("Events"),
  searchBox = trackStub("SearchBox"),
  sonata = trackStub("Sonata"),
  money = trackStub("MoneyFrame"),
  cursorPlacement = trackStub("CursorPlacement"),
  bankBehavior = trackStub("BankBehavior"),
  bankSlots = trackStub("BankSlots"),
  menuButton = trackStub("BagMenuButton"),
  sectionFrame = trackStub("SectionFrame"),
  categories = trackStub("Categories"),
}

-- Every value this spec replaces, put back after each test.
local replaced = {}
local function override(tbl, key, value)
  table.insert(replaced, { tbl, key, rawget(tbl, key) })
  tbl[key] = value
end
local function restore()
  for i = #replaced, 1, -1 do
    replaced[i][1][replaced[i][2]] = replaced[i][3]
  end
  replaced = {}
end

LoadBetterBagsModule("render/render.lua")
LoadBetterBagsModule("render/drawable.lua")
LoadBetterBagsModule("render/scrollbox.lua")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" },
  { "NextSparkles", "next/sparkles.lua" }, { "NextLift", "next/lift.lua" }, { "NextTabs", "next/tabs.lua" }, { "NextContent", "next/content.lua" },
  { "NextDockCard", "next/dockcard.lua" }, { "NextDock", "next/dock.lua" }, { "NextDrag", "next/drag.lua" }, { "NextChain", "next/chain.lua" }, { "NextPanel", "next/panel.lua" }, { "NextBank", "next/bank.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local nextBank = addon:GetModule("NextBank")
local style = addon:GetModule("NextStyle")
local tween = addon:GetModule("NextTween")
local render = addon:GetModule("Render")
local motion = addon:GetModule("Motion")
local context = addon:GetModule("Context")

-- Live retail's numbers: character tabs are bags 6 to 11, Warbank tabs 12 to 16.
local CHAR, ACCOUNT = 1, 2
local SECTION_GRID, SECTION_ALL_BAGS = 2, 4
local EMPTY_BAG_SLOT = [[Interface\PaperDoll\UI-PaperDoll-Slot-Bag]]

describe("NextBank", function()
  local buttons, sent, messages, eventsRegistered, buckets, calls
  local db, allGroups, slotInfo, purchased, nextPurchasable, moneyMade

  local function fakeButton(slotkey)
    local b = { slotkey = slotkey, frame = CreateFrame("Frame"), released = 0 }
    b.frame:SetSize(37, 37)
    function b:SetItemFromData(_, data) self.data = data self.isFreeSlot = false end
    function b:SetFreeSlots(_, data) self.data = data self.isFreeSlot = true end
    function b:SetSize(_, w, h) self.frame:SetSize(w, h) end
    function b:GetItemData() return self.data end
    function b:UpdateSearch() end
    function b:UpdateCooldown() calls.cooldowns = calls.cooldowns + 1 return "start" end
    function b:Release() self.released = self.released + 1 end
    return b
  end

  local function item(slotkey, category)
    return { slotkey = slotkey, itemInfo = { category = category } }
  end

  local function tab(items, category)
    return { categories = { { name = category } }, items = items }
  end

  -- The bank's read data: a tab for each group, and one for each Blizzard tab (tab mode).
  local function data()
    return {
      sortedItems = {},
      tabs = {
        [2] = tab({ item("6_1", "Cloth") }, "Cloth"),
        [3] = tab({ item("12_1", "Ore") }, "Ore"),
        [4] = tab({ item("6_2", "Herbs") }, "Herbs"),
        [5] = tab({ item("13_1", "Gems") }, "Gems"),
        [6] = tab({ item("6_1", "#1: Bank") }, "#1: Bank"),
        [12] = tab({ item("12_1", "#1: Warbank") }, "#1: Warbank"),
      },
    }
  end

  -- client sets the flavor flags BetterBags reads.
  local function client(name)
    override(addon, "isRetail", name ~= "classic")
    override(addon, "isForever", name == "forever")
    override(addon, "hasWarbank", name == "retail")
    if name == "classic" then
      override(const, "ACCOUNT_BANK_BAGS", {})
      override(const, "BANK_TAB", { BANK = -1 })
      override(C_Container, "SortBankBags", nil)
      override(_G, "SortBankBags", nil)
    end
    if name == "forever" then
      override(const, "ACCOUNT_BANK_BAGS", {})
    end
  end

  before_each(function()
    render:Init()
    tween:Init()
    motion:Init()
    buttons, sent, messages, eventsRegistered, buckets = {}, {}, {}, {}, {}
    calls = { suppressed = 0, bankTypes = {}, cleared = 0, closed = 0, deposits = {}, sorts = {}, menus = {},
      created = 0, purchaseUpdates = 0, tabConfigs = {}, pickups = {}, context = 0, cooldowns = 0, placed = {} }
    db = { groupsEnabled = true, active = 2, showBankTabs = false, view = SECTION_GRID, previous = nil, inBagSearch = true }
    allGroups = {
      [2] = { id = 2, name = "Bank", bankType = CHAR, isDefault = true },
      [3] = { id = 3, name = "Warbank", bankType = ACCOUNT, isDefault = true },
      [4] = { id = 4, name = "Herbs", bankType = CHAR },
      [5] = { id = 5, name = "Gems", bankType = ACCOUNT },
    }
    slotInfo = data()
    purchased = {
      [CHAR] = { { ID = 7, name = "Mats", icon = 101 }, { ID = 6, name = "Base", icon = 100 } },
      [ACCOUNT] = { { ID = 12, name = "Shared", icon = 200 } },
    }
    nextPurchasable = { [CHAR] = { tabCost = 1 }, [ACCOUNT] = { tabCost = 2 } }
    moneyMade = {}

    override(addon, "isRetail", true)
    override(addon, "isForever", false)
    override(addon, "hasWarbank", true)
    override(addon, "atBank", true)
    override(const, "BANK_TAB", { BANK = -2, ACCOUNT_BANK_1 = 12 })
    override(const, "BAG_VIEW", { SECTION_GRID = SECTION_GRID, SECTION_ALL_BAGS = SECTION_ALL_BAGS })
    override(const, "ACCOUNT_BANK_BAGS", { [12] = 12, [13] = 13, [14] = 14, [15] = 15, [16] = 16 })
    override(Enum.BagIndex, "Characterbanktab", -2)
    override(Enum.BagIndex, "CharacterBankTab_1", 6)
    override(Enum.BagIndex, "AccountBankTab_1", 12)

    override(stubs.L, "G", function(_, key) return key end)
    override(stubs.itemFrame, "GetButton", function(_, _, slotkey)
      buttons[slotkey] = buttons[slotkey] or fakeButton(slotkey)
      return buttons[slotkey]
    end)
    override(stubs.items, "GetAllSlotInfo", function() return { [BANK] = slotInfo } end)
    override(stubs.items, "ExpireRecentItems", function() return calls.expire == true end)
    override(stubs.items, "ClearBankCache", function() calls.cleared = calls.cleared + 1 end)
    override(stubs.database, "GetGroupsEnabled", function() return db.groupsEnabled end)
    override(stubs.database, "GetActiveGroup", function() return db.active end)
    override(stubs.database, "SetActiveGroup", function(_, _, id) db.active = id end)
    override(stubs.database, "GetNextChain", function() return "apart" end)
    override(stubs.database, "GetNextSize", function() return "full" end)
    override(stubs.database, "GetInBagSearch", function() return db.inBagSearch end)
    db.tabOrder = {}
    override(stubs.database, "GetNextTabOrder", function(_, key) return db.tabOrder[key] or {} end)
    override(stubs.database, "SetNextTabOrder", function(_, key, ids) db.tabOrder[key] = ids end)
    override(stubs.database, "GetShowBankTabs", function() return db.showBankTabs end)
    override(stubs.database, "SetShowBankTabs", function(_, on) db.showBankTabs = on end)
    override(stubs.database, "GetBagView", function() return db.view end)
    override(stubs.database, "SetBagView", function(_, _, view) db.view = view end)
    override(stubs.database, "GetPreviousView", function() return db.previous end)
    override(stubs.database, "SetPreviousView", function(_, _, view) db.previous = view end)
    override(stubs.groups, "GetAllGroups", function() return allGroups end)
    override(stubs.groups, "GetGroup", function(_, _, id) return allGroups[id] end)
    override(stubs.groups, "IsDefaultGroup", function(_, _, id) return allGroups[id] and allGroups[id].isDefault == true end)
    override(stubs.groups, "GetDefaultBankGroup", function() return allGroups[2] end)
    override(stubs.events, "SendMessage", function(_, _, name, opts) table.insert(sent, { name, opts }) end)
    override(stubs.events, "RegisterMessage", function(_, name, fn) messages[name] = fn end)
    override(stubs.events, "RegisterEvent", function(_, name, fn) eventsRegistered[name] = fn end)
    override(stubs.events, "BucketEvent", function(_, name, fn, filter) buckets[name] = { fn, filter } end)
    override(stubs.searchBox, "CreateBox", function(_, kind, parent)
      local box = { kind = kind, frame = CreateFrame("Frame", nil, parent) }
      -- As searchBox:CreateBox makes it (frames/search.lua): a BagSearchBoxTemplate edit box.
      box.textBox = CreateFrame("EditBox", nil, box.frame, "BagSearchBoxTemplate")
      box.helpText = box.textBox.Instructions
      calls.box = box
      return box
    end)
    override(stubs.sonata, "UnregisterElement", function() end)
    override(stubs.money, "Create", function(_, warbank)
      local m = { frame = CreateFrame("Frame"), warbank = warbank, updates = 0 }
      function m:Update() self.updates = self.updates + 1 end
      table.insert(moneyMade, m)
      return m
    end)
    override(stubs.cursorPlacement, "PlaceCursorItem", function(_, kind, bankTab)
      table.insert(calls.placed, { kind, bankTab })
      return "placed"
    end)
    override(stubs.bankBehavior, "SuppressBlizzardBankPanel", function() calls.suppressed = calls.suppressed + 1 end)
    override(stubs.bankBehavior, "proto", {
      ShowCreateGroupDialog = function(self) calls.created = calls.created + 1 calls.dialogBag = self.bag end,
      ShowGroupContextMenu = function(_, _, id) table.insert(calls.menus, id) end,
      UpdatePurchaseBankButton = function(self)
        calls.purchaseUpdates = calls.purchaseUpdates + 1
        calls.purchaseBag = self.bag
      end,
    })
    override(stubs.bankSlots, "OpenTabConfig", function(_, id) table.insert(calls.tabConfigs, id) end)
    override(stubs.bankSlots, "PickupBag", function(_, bankType, id) table.insert(calls.pickups, { bankType, id }) end)
    override(stubs.bankSlots, "GetBagSocketIndex", function(_, bankType, id)
      if addon.isForever and bankType == CHAR and id > 6 then return id - 5 end
      return nil
    end)
    override(stubs.menuButton, "Sort", function(_, _, bag) table.insert(calls.sorts, { "menu", bag }) end)
    override(C_Bank, "FetchPurchasedBankTabData", function(bankType) return purchased[bankType] end)
    override(C_Bank, "FetchNextPurchasableBankTabData", function(bankType) return nextPurchasable[bankType] end)
    override(C_Bank, "CloseBankFrame", function() calls.closed = calls.closed + 1 end)
    override(C_Bank, "AutoDepositItemsIntoBank", function(bankType) table.insert(calls.deposits, bankType) end)
    override(_G, "CloseBankFrame", function() calls.closed = calls.closed + 1 end)
    override(C_Container, "SortBankBags", function() end)
    override(addon, "SetBlizzardBankType", function(bankType) table.insert(calls.bankTypes, bankType) end)
    override(addon, "TriggerItemContextChanged", function() calls.context = calls.context + 1 end)
    override(addon, "ForceHideBlizzardBags", function() end)
    override(_G, "PlaySound", function() end)
    override(_G, "InCombatLockdown", function() return false end)
    _G._cursorType = nil
    _G._isShiftKeyDown = false
  end)

  after_each(function()
    restore()
    _G._cursorType = nil
    _G._isShiftKeyDown = false
  end)

  teardown(function()
    for _, m in ipairs({ "NextBank", "NextPanel", "NextDrag", "NextContent", "NextTabs", "NextSparkles", "NextTween", "NextStyle" }) do
      ResetModuleStub(m)
    end
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  local function ctx() return context:New("spec") end

  local function finishTweens()
    for _ = 1, 400 do
      local update = tween.driver and tween.driver:GetScript("OnUpdate")
      if update == nil then return end
      update(tween.driver, 0.05)
    end
  end

  local function offset(bank)
    local _, _, _, x = bank.frame:GetPoint(1)
    return x
  end

  local function sentNamed(name)
    local out = {}
    for _, m in ipairs(sent) do
      if m[1] == name then table.insert(out, m) end
    end
    return out
  end

  local function opened()
    local bank = nextBank:Create(ctx())
    bank:Show(ctx())
    bank:Draw(ctx(), slotInfo, function() end)
    finishTweens()
    return bank
  end

  local function tabIDs(bank)
    local ids = {}
    for _, t in ipairs(bank.tabs.tabs) do table.insert(ids, t.id) end
    return ids
  end

  local function tabOf(bank, id)
    for _, t in ipairs(bank.tabs.tabs) do
      if t.id == id then return t end
    end
  end

  local function click(button, mouse)
    button:GetScript("OnClick")(button, mouse or "LeftButton")
  end

  -- Switching between the classic design and BetterBags Next without a reload (next.md §11).
  describe("switching designs (Activate)", function()
    it("catches up on its tabs, its money and its Purchase Bank button", function()
      local bank = nextBank:Create(ctx())
      local before = calls.purchaseUpdates
      local updates = moneyMade[#moneyMade].updates
      allGroups[13] = { id = 13, name = "Ore", bankType = CHAR }
      bank:Activate(ctx())
      assert.is_not_nil(bank.tabs:Tab(13))
      assert.are.equal(updates + 1, moneyMade[#moneyMade].updates)
      assert.are.equal(before + 1, calls.purchaseUpdates)
    end)
  end)

  describe("the panel", function()
    it("is a hidden, named, full-height panel on the left edge of the screen", function()
      local bank = nextBank:Create(ctx())
      assert.are.equal(BANK, bank.kind)
      assert.are.equal("BetterBagsNextBank", bank:GetName())
      assert.is_false(bank:IsShown())
      assert.are.same({ "TOPLEFT", UIParent, "TOPLEFT", 0, 0 }, { bank.frame:GetPoint(1) })
      assert.are.same({ "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0 }, { bank.frame:GetPoint(2) })
      assert.are.equal(style.WIDTH, bank.frame:GetWidth())
      assert.are.equal("HIGH", bank.frame:GetFrameStrata())
    end)

    it("feathers its right edge out to nothing and takes no clicks there", function()
      local bank = nextBank:Create(ctx())
      local g = bank.feather._gradient
      assert.are.equal(style.Color.Body[4], g.min.a)
      assert.are.equal(0, g.max.a)
      assert.are.same({ "TOPRIGHT", bank.frame, "TOPRIGHT", 0, 0 }, { bank.feather:GetPoint(1) })
      assert.are.same({ "TOPLEFT", bank.frame, "TOPLEFT", 0, 0 }, { bank.body:GetPoint(1) })
      assert.are.same({ 0, style.FEATHER, 0, 0 }, { bank.frame:GetHitRectInsets() })
    end)

    it("titles itself on its inner side, its ribbon running right out of the window", function()
      local bank = nextBank:Create(ctx())
      assert.are.equal("Bank", bank.title:GetText())
      assert.are.same({ "TOPRIGHT", bank.body, "TOPRIGHT", -(style.PAD + 4), -style.TITLE_TOP }, { bank.title:GetPoint(1) })
      local g = bank.ribbon._gradient
      assert.is_true(g.min.a > g.max.a, "bright at the title, gone at its far end")
    end)

    -- The cloud mirrored (next.md §3): the ribbon enters it from the right, where it is warm, the
    -- shimmer glides in from the right, and its sparkles are born near the join.
    it("runs its ribbon into the right of the title's cloud, warm where it enters", function()
      local C = style.Cloud
      local bank = nextBank:Create(ctx())
      local edge = style.PAD + 4
      local span = bank.title:GetStringWidth() + edge + C.Pad
      -- From the body's right edge, the window's hard edge, by whole pixels (docs/next-pixel-perfect.md).
      local point, to, relative, x = bank.ribbon:GetPoint(1)
      assert.are.same({ "TOPLEFT", bank.body, "TOPRIGHT", 0 }, { point, to, relative, x })
      assert.is_nil(bank.cloud.tail)
      local _, fontHeight = bank.title:GetFont()
      local join = bank.cloud.join
      local middle = style.TITLE_TOP + math.floor(fontHeight / 2)
      assert.are.same({ "TOPLEFT", bank.body, "TOPRIGHT", -math.floor(join:GetWidth() / 2),
        -(middle - math.floor(join:GetHeight() / 2)) }, { join:GetPoint(1) })
      for i, puff in ipairs(bank.cloud.puffs) do
        assert.are.equal(edge - C.Puffs[i].F * span, puff.base.x)
        local p, rel, relPoint, px = puff.texture:GetPoint(1)
        assert.are.same({ "CENTER", bank.title, "RIGHT", puff.base.x }, { p, rel, relPoint, px })
      end
    end)

    it("glides its shimmer in from the right, to rest at the window's edge", function()
      local bank = opened()
      tween:Stop(bank.spark)
      bank:playShimmer()
      local driver, xs = tween.driver, {}
      for _ = 1, math.ceil((style.Time.ShimmerEvery - style.Time.Absorb) / 0.02) do
        driver:GetScript("OnUpdate")(driver, 0.02)
        local _, to, point, x = bank.spark:GetPoint(1)
        if bank.spark:GetAlpha() > 0 then
          assert.are.same({ bank.ribbon, "LEFT" }, { to, point })
          table.insert(xs, x)
        end
      end
      assert.is_true(xs[1] > 0.9 * 300, "from the far end, on the right")
      for i = 2, #xs do assert.is_true(xs[i] <= xs[i - 1], "in, toward the cloud") end
      assert.are.equal(0, xs[#xs], "at rest at the window's edge")
    end)

    -- The fill mirrored (next.md §3): the bank bounces open from the left edge.
    it("keeps its fill over the left screen edge through the whole bounce", function()
      local bank = nextBank:Create(ctx())
      local point, to, relative, reach = bank.fill:GetPoint(1)
      assert.are.same({ "TOPLEFT", bank.frame, "TOPLEFT" }, { point, to, relative })
      bank:Show(ctx())
      local deepest = 0
      for _ = 1, 250 do
        tween:Step(0.002)
        deepest = math.max(deepest, offset(bank))
        assert.is_true(offset(bank) + reach <= 0, "the fill reaches the screen edge: " .. offset(bank) .. " " .. reach)
      end
      assert.is_true(deepest > 0.09 * (style.WIDTH + style.OVERREACH), "it still bounces: " .. deepest)
      assert.are.equal(0, offset(bank))
    end)

    it("hangs its tabs from its right side and drifts its sparkles right", function()
      local bank = nextBank:Create(ctx())
      assert.are.equal("LEFT", bank.tabs.side)
      assert.are.same({ "TOPLEFT", bank.body, "TOPRIGHT", 0, -style.CONTENT_TOP }, { bank.tabs.frame:GetPoint(1) })
      assert.are.equal(1, bank.sparkles.options.Direction)
      assert.are.equal(1, bank.edgeSparkles.options.Direction)
      local C = style.Cloud
      local join = style.BODY_WIDTH
      local x = bank.sparkles.options.Spawn()
      assert.is_true(x >= join, "born at the ribbon's start or past it")
      assert.are.equal(1, bank.cloudSparkles.options.Direction)
      local near = 0
      math.randomseed(7)
      for _ = 1, 200 do
        local cx = bank.cloudSparkles.options.Spawn()
        assert.is_true(cx <= join + 1e-9, "in the cloud, which ends at the join")
        if cx > join - (bank.title:GetStringWidth() + style.PAD + 4 + C.Pad) / 2 then near = near + 1 end
      end
      assert.is_true(near > 120, "most near the join: " .. near)
    end)

    it("uses the bank's own in-bag search box", function()
      local bank = nextBank:Create(ctx())
      assert.are.equal(BANK, calls.box.kind)
      assert.are.equal(calls.box, bank.searchBox)
    end)

    it("slides in from the left, past its place a little and back, and out to the left", function()
      local bank = nextBank:Create(ctx())
      bank:Show(ctx())
      assert.are.equal(-(style.WIDTH + style.OVERREACH), offset(bank))
      local past = false
      for _ = 1, 40 do
        tween:Step(0.0125)
        if offset(bank) > 0 then past = true end
      end
      assert.is_true(past, "overshoots")
      assert.are.equal(0, offset(bank))
      bank:Hide(ctx())
      finishTweens()
      assert.is_false(bank:IsShown())
      assert.are.equal(-(style.WIDTH + style.OVERREACH), offset(bank))
    end)

    it("refreshes no cooldowns: items in the bank cannot be used", function()
      local bank = opened()
      assert.is_nil(buckets["BAG_UPDATE_COOLDOWN"])
      assert.are.same({ 0, 0 }, { bank:OnCooldown(ctx()) })
      assert.are.equal(0, calls.cooldowns)
    end)

    it("drops an item into the bank type it shows", function()
      local bank = opened()
      bank.frame:GetScript("OnReceiveDrag")(bank.frame)
      bank:SwitchToGroup(ctx(), 3)
      bank.frame:GetScript("OnReceiveDrag")(bank.frame)
      assert.are.same({ { BANK, -2 }, { BANK, 12 } }, calls.placed)
    end)
  end)

  describe("its header", function()
    local function headerKinds(bank)
      local out = {}
      for _, b in ipairs(bank.headerButtons) do table.insert(out, NextIconName(b)) end
      return out
    end

    it("lines its buttons up from the left edge: close, settings, bank tabs, deposit, sort", function()
      local bank = nextBank:Create(ctx())
      assert.are.same({ "close", "settings", "banktabs", "deposit", "sort" }, headerKinds(bank))
      assert.are.same({ "TOPLEFT", bank.body, "TOPLEFT", style.PAD, -(style.TITLE_TOP + 3) }, { bank.closeButton:GetPoint(1) })
      assert.are.same({ "TOPLEFT", bank.closeButton, "TOPRIGHT", 8, 0 }, { bank.settingsButton:GetPoint(1) })
    end)

    it("has no deposit button without a Warbank, and no bank tabs or sort where the client lacks them", function()
      client("forever")
      local forever = nextBank:Create(ctx())
      assert.are.same({ "close", "settings", "banktabs", "sort" }, headerKinds(forever))
      client("classic")
      local classic = nextBank:Create(ctx())
      assert.are.same({ "close", "settings" }, headerKinds(classic))
      override(_G, "SortBankBags", function() end)
      local sorting = nextBank:Create(ctx())
      assert.are.same({ "close", "settings", "sort" }, headerKinds(sorting))
    end)

    it("closes the bank, opens the settings and deposits Warbound items", function()
      local bank = opened()
      click(bank.settingsButton)
      click(bank.depositButton)
      assert.are.equal(1, #sentNamed("config/Open"))
      assert.are.same({ ACCOUNT }, calls.deposits)
      click(bank.closeButton)
      finishTweens()
      assert.is_false(bank:IsShown())
    end)

    it("sorts as the menu button's right click does on retail, and the bank on Classic", function()
      local bank = opened()
      click(bank.sortButton)
      assert.are.same({ { "menu", bank } }, calls.sorts)
      client("classic")
      override(_G, "SortBankBags", function() end)
      override(stubs.events, "SendMessage", function(_, _, name) table.insert(sent, { name }) end)
      local classic = nextBank:Create(ctx())
      click(classic.sortButton)
      assert.are.equal(1, #sentNamed("bags/SortBank"))
    end)
  end)

  describe("its footer", function()
    it("shows the Warbank's gold on retail, the character's on WoW: Forever, and none on Classic", function()
      local bank = nextBank:Create(ctx())
      assert.are.equal(true, moneyMade[1].warbank)
      assert.are.equal(moneyMade[1], bank.moneyFrame)
      assert.are.same({ "BOTTOMLEFT", bank.body, "BOTTOMLEFT", style.PAD, 12 }, { bank.moneyFrame.frame:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", bank.body, "BOTTOMRIGHT", -(style.PAD + 4), 14 }, { bank.freeText:GetPoint(1) })
      client("forever")
      moneyMade = {}
      override(stubs.money, "Create", function(_, warbank)
        local m = { frame = CreateFrame("Frame"), warbank = warbank, Update = function() end }
        table.insert(moneyMade, m)
        return m
      end)
      nextBank:Create(ctx())
      assert.are.equal(false, moneyMade[1].warbank)
      client("classic")
      local classic = nextBank:Create(ctx())
      assert.is_nil(classic.moneyFrame)
    end)
  end)

  describe("opening", function()
    it("suppresses Blizzard's bank panel, shows the active group and updates the money", function()
      local bank = nextBank:Create(ctx())
      bank:Show(ctx())
      assert.are.equal(1, calls.suppressed)
      assert.are.equal("Bank", bank.title:GetText())
      assert.are.same({ CHAR }, calls.bankTypes)
      assert.are.equal(-2, bank.bankTab)
      assert.are.equal(1, bank.moneyFrame.updates)
      assert.are.equal(bank, calls.purchaseBag)
      assert.are.equal("Cloth", bank.content.order[1].name, "draws the active group from what was read")
    end)

    it("shows a Warbank group's bank type and wash", function()
      db.active = 3
      local bank = nextBank:Create(ctx())
      bank:Show(ctx())
      finishTweens()
      assert.are.same({ ACCOUNT }, calls.bankTypes)
      assert.are.equal(12, bank.bankTab)
      assert.are.equal("Warbank", bank.title:GetText())
      assert.are.same(style.Color.WarbankWash, bank.washColor)
    end)

    it("fades the wash to the Warbank's over its own time", function()
      local bank = opened()
      bank:SwitchToGroup(ctx(), 3)
      tween:Step(style.Time.Wash - 0.01)
      assert.are_not.same(style.Color.WarbankWash, bank.washColor)
      tween:Step(0.02)
      assert.are.same(style.Color.WarbankWash, bank.washColor)
    end)

    it("says it is loading until the bank has been read", function()
      slotInfo = { sortedItems = {} }
      local bank = nextBank:Create(ctx())
      bank:Show(ctx())
      assert.is_true(bank.emptyText:IsShown())
      assert.are.equal("Loading...", bank.emptyText:GetText())
      slotInfo = data()
      bank:Draw(ctx(), slotInfo, function() end)
      assert.is_false(bank.emptyText:IsShown())
      bank:SwitchToGroup(ctx(), 4)
      slotInfo.tabs[4] = tab({}, "Herbs")
      bank:Draw(ctx(), slotInfo, function() end)
      assert.are.equal("Nothing here yet", bank.emptyText:GetText())
    end)
  end)

  describe("groups", function()
    it("lists the character groups, then after a gap the Warbank groups in teal, then a tab to make one", function()
      local bank = opened()
      assert.are.same({ 2, 4, 3, 5, 0 }, tabIDs(bank))
      local step = style.TAB_HEIGHT + style.TAB_SPACING
      assert.are.equal(2 * step + style.TAB_GROUP_GAP, tabOf(bank, 3).y)
      assert.are.equal("Warbank", tabOf(bank, 3).accent)
      assert.are.equal("warbands-icon", tabOf(bank, 5).icon:GetAtlas())
      assert.is_false(tabOf(bank, 4).icon:IsShown())
      assert.are.equal(2, bank.tabs.selected)
    end)

    -- Asked: tabs reorderable, "make sure it saves" (docs/next-batch-2.md §5): the character groups and the
    -- Warbank groups each among themselves, the gap above whichever Warbank group is first.
    it("lists each block of groups in the order saved, and saves the order they are moved to", function()
      db.tabOrder.bank = { 5, 3, 4, 2 }
      local bank = opened()
      assert.are.same({ 4, 2, 5, 3, 0 }, tabIDs(bank))
      local step = style.TAB_HEIGHT + style.TAB_SPACING
      assert.are.equal(2 * step + style.TAB_GROUP_GAP, tabOf(bank, 5).y)
      assert.are.equal(3 * step + style.TAB_GROUP_GAP, tabOf(bank, 3).y)
      assert.are.equal("bank", tabOf(bank, 2).block)
      assert.are.equal("warbank", tabOf(bank, 3).block)
      assert.is_false(tabOf(bank, 0).movable)
      bank.tabs.onReorder(ctx(), { 2, 4, 3, 5, 0 })
      assert.are.same({ 2, 4, 3, 5, 0 }, db.tabOrder.bank)
      assert.are.same({ 2, 4, 3, 5, 0 }, tabIDs(bank))
    end)

    it("shows a group on a click: its bank type, title, items and the backpack's grey-out", function()
      local bank = opened()
      local before = calls.purchaseUpdates
      click(tabOf(bank, 5).button)
      assert.are.equal(5, db.active)
      assert.are.equal(5, bank.tabs.selected)
      assert.are.equal(ACCOUNT, calls.bankTypes[#calls.bankTypes])
      assert.are.equal(12, bank.bankTab)
      assert.are.equal("Gems", bank.title:GetText())
      assert.are.equal("Gems", bank.content.order[1].name)
      assert.are.equal(before + 1, calls.purchaseUpdates)
      assert.are.same({ { "bags/Rederive", { backpack = true, bank = false, categoriesUnchanged = true } } }, sentNamed("bags/Rederive"))
      assert.are.equal(0, bank.content.order[1].frame:GetAlpha(), "fades in")
    end)

    it("leaves the backpack alone when it switches group away from the bank", function()
      local bank = opened()
      override(addon, "atBank", false)
      bank:SwitchToGroup(ctx(), 4)
      assert.are.same({}, sentNamed("bags/Rederive"))
    end)

    it("opens a custom group's menu on a right click, never a default group's, and the group dialog from +", function()
      local bank = opened()
      click(tabOf(bank, 4).button, "RightButton")
      click(tabOf(bank, 3).button, "RightButton")
      click(tabOf(bank, 2).button, "RightButton")
      assert.are.same({ 4 }, calls.menus)
      click(tabOf(bank, 0).button)
      assert.are.equal(1, calls.created)
      assert.are.equal(bank, calls.dialogBag)
      assert.are.equal(2, db.active)
    end)

    it("lists the groups again when they change, and shows the default bank group when its group goes", function()
      local bank = opened()
      bank:SwitchToGroup(ctx(), 4)
      allGroups[4] = nil
      messages["groups/Deleted"](ctx(), 4, nil, BANK)
      assert.are.equal(2, db.active)
      assert.are.same({ 2, 3, 5, 0 }, tabIDs(bank))
      allGroups[6] = { id = 6, name = "Leather", bankType = CHAR }
      messages["groups/Created"](ctx(), { kind = BANK })
      assert.are.same({ 2, 6, 3, 5, 0 }, tabIDs(bank))
      messages["groups/Created"](ctx(), { kind = 0 })
      allGroups[6].name = "Hides"
      messages["groups/Changed"](ctx(), 6, nil, nil, BANK)
      assert.are.equal("Hides", tabOf(bank, 6).text:GetText())
    end)

    -- Classic has no Enum.BankType: no group is the Warbank's there.
    it("lists every group as a bank group on a client without a Warbank", function()
      client("classic")
      override(Enum, "BankType", nil)
      local bank = opened()
      assert.are.same({ 2, 3, 4, 5, 0 }, tabIDs(bank))
      assert.is_nil(tabOf(bank, 3).accent)
      assert.are.equal(-1, bank.bankTab)
    end)

    it("hides its tabs while the bank's groups are off", function()
      db.groupsEnabled = false
      local bank = opened()
      assert.is_false(bank.tabs.frame:IsShown())
      assert.are.equal(1, bank:GetCurrentTabID())
    end)

    it("switches group for Quick Find and the group dialogs through its behavior", function()
      local bank = opened()
      bank.behavior:SwitchToGroup(ctx(), 4)
      assert.are.equal(4, db.active)
    end)
  end)

  describe("bank tabs (retail)", function()
    local function inTabMode()
      db.showBankTabs = true
      db.view = SECTION_ALL_BAGS
      return opened()
    end

    it("lists the purchased character tabs, then the Warbank's in teal, then a + for each that can be bought", function()
      local bank = inTabMode()
      assert.are.same({ 6, 7, -1, 12, -2 }, tabIDs(bank))
      assert.are.equal(100, tabOf(bank, 6).icon:GetTexture())
      assert.are.equal("Mats", tabOf(bank, 7).text:GetText())
      assert.are.equal("Warbank", tabOf(bank, 12).accent)
      assert.is_true(tabOf(bank, -1).secure)
      assert.are.equal(CHAR, tabOf(bank, -1).button:GetAttribute("overrideBankType"))
      assert.are.equal(ACCOUNT, tabOf(bank, -2).button:GetAttribute("overrideBankType"))
      nextPurchasable[CHAR] = nil
      bank:RefreshTabs()
      assert.are.same({ 6, 7, 12, -2 }, tabIDs(bank))
    end)

    it("lists each bank type's tabs in the order saved apart from the groups', buying ones last", function()
      db.tabOrder.bankTabs = { 7, 6 }
      db.tabOrder.bank = { 6, 7 }
      local bank = inTabMode()
      assert.are.same({ 7, 6, -1, 12, -2 }, tabIDs(bank))
      assert.is_false(tabOf(bank, -1).movable)
      bank.tabs.onReorder(ctx(), { 6, 7, -1, 12, -2 })
      assert.are.same({ 6, 7, -1, 12, -2 }, db.tabOrder.bankTabs)
      assert.are.same({ 6, 7 }, db.tabOrder.bank, "the groups' order is their own")
    end)

    it("shows the first purchased tab when it opens without one", function()
      local bank = inTabMode()
      assert.are.equal(6, bank.blizzardBankTab)
      assert.are.equal(6, bank:GetCurrentTabID())
      assert.are.equal("Base", bank.title:GetText())
      assert.are.equal("#1: Bank", bank.content.order[1].name)
    end)

    it("shows a tab on a click: its bank type, title and items, and the backpack's grey-out", function()
      local bank = inTabMode()
      click(tabOf(bank, 12).button)
      assert.are.equal(12, bank.blizzardBankTab)
      assert.are.equal(12, bank.bankTab)
      assert.are.equal(ACCOUNT, calls.bankTypes[#calls.bankTypes])
      assert.are.equal("Shared", bank.title:GetText())
      assert.are.equal("#1: Warbank", bank.content.order[1].name)
      assert.are.same({ { "bags/Rederive", { backpack = true, bank = false, categoriesUnchanged = true } } }, sentNamed("bags/Rederive"))
      assert.are.same({ { "bags/Rederive", { backpack = true, bank = false, categoriesUnchanged = true } } }, sentNamed("bags/Rederive"))
      bank.behavior:SwitchToBlizzardTab(ctx(), 7)
      assert.are.equal(CHAR, calls.bankTypes[#calls.bankTypes])
    end)

    it("opens Blizzard's settings for a tab on a right click", function()
      local bank = inTabMode()
      click(tabOf(bank, 7).button, "RightButton")
      assert.are.same({ 7 }, calls.tabConfigs)
      assert.are.equal(6, bank.blizzardBankTab)
    end)

    it("explains a tab in its tooltip", function()
      local bank = inTabMode()
      local button = tabOf(bank, 12).button
      button:GetScript("OnEnter")(button)
      local lines = {}
      for _, line in ipairs(GameTooltip.lines) do lines[line.text] = true end
      assert.are.equal("Shared", GameTooltip._text)
      assert.is_true(lines["Warbank"])
      assert.is_true(lines["Left-click to view this tab"])
      assert.is_true(lines["Right-click to configure this tab"])
    end)

    describe("on WoW: Forever, where a character tab is its bag socket", function()
      before_each(function()
        client("forever")
        _G._itemsAtLocation = { ["-2:2"] = { icon = 555 } }
      end)

      after_each(function()
        _G._itemsAtLocation = {}
      end)

      it("moves bags through a tab dragged, dropped on, clicked holding one or Shift-clicked", function()
        local bank = inTabMode()
        local socket = tabOf(bank, 7).button
        assert.are.same({ "LeftButton" }, socket._registeredDrags)
        socket:GetScript("OnDragStart")(socket)
        socket:GetScript("OnReceiveDrag")(socket)
        _G._cursorType = "item"
        click(socket)
        _G._cursorType = nil
        _G._isShiftKeyDown = true
        click(socket)
        assert.are.same({ { CHAR, 7 }, { CHAR, 7 }, { CHAR, 7 }, { CHAR, 7 } }, calls.pickups)
        assert.are.equal(6, bank.blizzardBankTab, "none of them showed the tab")
        _G._isShiftKeyDown = false
        click(socket)
        assert.are.equal(7, bank.blizzardBankTab)
      end)

      it("never moves bags through the bagless base tab", function()
        local bank = inTabMode()
        local base = tabOf(bank, 6)
        assert.is_falsy(base.draggable, "its drag moves the tab (docs/next-batch-2.md §5), never a bag")
        assert.is_true(base.movable)
        _G._cursorType = "item"
        click(base.button)
        assert.are.same({}, calls.pickups)
      end)

      it("shows the bag in a tab's socket as its icon, or an empty bag slot", function()
        purchased[CHAR][3] = { ID = 8, name = "Spare", icon = 102 }
        local bank = inTabMode()
        assert.are.equal(555, tabOf(bank, 7).icon:GetTexture())
        assert.are.equal(EMPTY_BAG_SLOT, tabOf(bank, 8).icon:GetTexture())
        assert.are.equal(100, tabOf(bank, 6).icon:GetTexture())
      end)
    end)

    it("switches between groups and bank tabs as the classic bank's Show Bags does", function()
      local bank = opened()
      click(bank.bankTabsButton)
      assert.is_true(db.showBankTabs)
      assert.are.equal(SECTION_GRID, db.previous)
      assert.are.equal(SECTION_ALL_BAGS, db.view)
      assert.are.equal(6, bank.blizzardBankTab)
      assert.are.same({ 6, 7, -1, 12, -2 }, tabIDs(bank))
      assert.are.equal("Base", bank.title:GetText())
      assert.are.same({ { "bags/Rederive", { resetLayout = true } } }, sentNamed("bags/Rederive"))
      click(bank.bankTabsButton)
      assert.is_false(db.showBankTabs)
      assert.are.equal(SECTION_GRID, db.view)
      assert.is_nil(bank.blizzardBankTab)
      assert.are.same({ 2, 4, 3, 5, 0 }, tabIDs(bank))
      assert.are.equal("Bank", bank.title:GetText())
      assert.are.equal(-2, bank.bankTab)
      assert.are.equal(2, #sentNamed("bags/Rederive"))
    end)

    it("refuses to switch in combat", function()
      local bank = opened()
      override(_G, "InCombatLockdown", function() return true end)
      click(bank.bankTabsButton)
      assert.is_false(db.showBankTabs)
    end)

    it("lists the tabs again when they are bought or changed, and checks the purchase button", function()
      local bank = inTabMode()
      local before = calls.purchaseUpdates
      purchased[CHAR][3] = { ID = 8, name = "New", icon = 103 }
      eventsRegistered["BANK_TABS_CHANGED"](ctx())
      assert.are.same({ 6, 7, 8, -1, 12, -2 }, tabIDs(bank))
      assert.are.equal(before + 1, calls.purchaseUpdates)
      purchased[ACCOUNT][1].name = "Renamed"
      eventsRegistered["BANK_TAB_SETTINGS_UPDATED"](ctx())
      assert.are.equal("Renamed", tabOf(bank, 12).text:GetText())
      purchased[ACCOUNT][2] = { ID = 13, name = "Second", icon = 201 }
      eventsRegistered["PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED"](ctx())
      assert.are.same({ 6, 7, 8, -1, 12, 13, -2 }, tabIDs(bank))
    end)

    it("shows its groups on Classic, which has no bank tabs, even with the setting left on", function()
      client("classic")
      db.showBankTabs = true
      local bank = opened()
      assert.are.same({ 2, 3, 4, 5, 0 }, tabIDs(bank))
      assert.is_nil(bank.blizzardBankTab)
    end)

    it("opens on the first purchased tab when the tab it showed is gone", function()
      db.showBankTabs = true
      local bank = nextBank:Create(ctx())
      bank.blizzardBankTab = 9
      bank:Show(ctx())
      assert.are.equal(6, bank.blizzardBankTab)
    end)

    it("lists no Warbank tabs, and shows none first, on a client without a Warbank", function()
      client("forever")
      db.showBankTabs = true
      local bank = opened()
      assert.are.same({ 6, 7, -1 }, tabIDs(bank))
      purchased[CHAR] = {}
      local empty = nextBank:Create(ctx())
      empty:Show(ctx())
      assert.is_nil(empty.blizzardBankTab)
    end)

    it("registers no retail bank event on Classic", function()
      client("classic")
      nextBank:Create(ctx())
      assert.is_nil(eventsRegistered["BANK_TABS_CHANGED"])
      assert.is_nil(eventsRegistered["BANK_TAB_SETTINGS_UPDATED"])
      assert.is_nil(eventsRegistered["PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED"])
      assert.is_nil(eventsRegistered["PLAYERBANKSLOTS_CHANGED"])
    end)

    it("redraws its tabs when a bag socket changes, only on WoW: Forever", function()
      client("forever")
      db.showBankTabs = true
      local bank = opened()
      _G._itemsAtLocation = { ["-2:2"] = { icon = 777 } }
      eventsRegistered["PLAYERBANKSLOTS_CHANGED"](ctx())
      assert.are.equal(777, tabOf(bank, 7).icon:GetTexture())
      _G._itemsAtLocation = {}
      eventsRegistered["BAG_CONTAINER_UPDATE"](ctx())
      assert.are.equal(EMPTY_BAG_SLOT, tabOf(bank, 7).icon:GetTexture())
    end)
  end)

  describe("closing", function()
    it("ends the bank interaction at once on retail when closed while at the bank", function()
      local bank = opened()
      bank:Hide(ctx())
      assert.are.equal(1, calls.closed)
      assert.is_true(bank:IsShown(), "still sliding out")
      finishTweens()
      assert.are.equal(1, calls.closed)
      override(addon, "atBank", false)
      bank:Show(ctx())
      bank:Hide(ctx())
      assert.are.equal(1, calls.closed, "not at the bank: nothing to end")
    end)

    it("ends the bank interaction once even when ending it hides the bank again", function()
      local bank = opened()
      override(C_Bank, "CloseBankFrame", function()
        calls.closed = calls.closed + 1
        bank:Hide(ctx())
      end)
      bank:Hide(ctx())
      assert.are.equal(1, calls.closed)
    end)

    it("ends the bank interaction when the slide ends on Classic", function()
      client("classic")
      local bank = opened()
      bank:Hide(ctx())
      assert.are.equal(0, calls.closed)
      finishTweens()
      assert.are.equal(1, calls.closed)
    end)

    -- Escape hides the frame directly; CloseSpecialWindows ends the interaction. Touching
    -- Blizzard's bank panel from OnHide breaks UseContainerItem for every container.
    it("ends nothing and touches no Blizzard bank state when Escape hides it", function()
      local bank = opened()
      local types = #calls.bankTypes
      bank.frame:Hide()
      bank.frame:GetScript("OnHide")(bank.frame)
      assert.are.equal(0, calls.closed)
      assert.are.equal(types, #calls.bankTypes)
    end)

    it("resets and clears the bank when the bank closes, after the slide when it is sliding out", function()
      local bank = opened()
      bank:SwitchToGroup(ctx(), 3)
      local cloth = buttons["12_1"]
      local c = ctx()
      bank:Hide(c)
      bank:SwitchToBankAndWipe(c)
      assert.is_true(c:Get("wipe"))
      assert.are.equal(-2, bank.bankTab)
      assert.are.equal(CHAR, calls.bankTypes[#calls.bankTypes])
      assert.are.equal("Bank", bank.title:GetText())
      assert.are.equal(1, calls.cleared)
      assert.are.equal(0, cloth.released, "not while it slides out")
      finishTweens()
      -- The client fires the frame's OnHide as the slide ends and hides it; the mock does not.
      bank.frame:GetScript("OnHide")(bank.frame)
      assert.are.equal(1, cloth.released)
      bank:Show(ctx())
      bank:SwitchToGroup(ctx(), 2)
      bank.frame:Hide()
      bank.frame:GetScript("OnHide")(bank.frame)
      local herbs = buttons["6_1"]
      local released = herbs.released
      bank:SwitchToBankAndWipe(ctx())
      assert.are.equal(released + 1, herbs.released, "at once when hidden")
    end)

    it("resets Classic's selected Blizzard bank tab instead of a bank type", function()
      client("classic")
      override(_G, "BankFrame", { selectedTab = 3 })
      local bank = opened()
      bank:SwitchToBankAndWipe(ctx())
      assert.are.equal(1, BankFrame.selectedTab)
      assert.are.equal(-1, bank.bankTab)
      assert.are.same({}, calls.bankTypes)
    end)

    it("expires Recent Items when it closes, refreshing the bank only while it is open", function()
      local bank = opened()
      calls.expire = true
      bank.frame:Hide()
      bank.frame:GetScript("OnHide")(bank.frame)
      assert.are.same({ { "bags/Rederive", { backpack = false, bank = true, categoriesUnchanged = true } } }, sentNamed("bags/Rederive"))
    end)
  end)

  describe("buying the bank", function()
    it("has a Purchase Bank button on retail: Blizzard's template, the character bank, no click of ours", function()
      local bank = nextBank:Create(ctx())
      local b = bank.purchaseBankButton
      assert.are.equal("BankPanelPurchaseButtonScriptTemplate, UIPanelButtonTemplate", b._template)
      assert.are.equal(CHAR, b:GetAttribute("overrideBankType"))
      assert.is_nil(b:GetScript("OnClick"))
      assert.are.same({ "CENTER", bank.scroll.frame, "CENTER", 0, 0 }, { b:GetPoint(1) })
      assert.is_false(b:IsShown())
    end)

    it("has none on Classic", function()
      client("classic")
      local bank = nextBank:Create(ctx())
      assert.is_nil(bank.purchaseBankButton)
      bank:Show(ctx())
      assert.are.equal(0, calls.purchaseUpdates)
    end)
  end)
end)
