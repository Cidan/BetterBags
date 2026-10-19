-- guildbank_spec.lua (next) -- NextGuildBank (next/guildbank.lua): BetterBags Next's guild bank
-- (guild-bank.md §5). A panel on the left, as the bank's, that stands in for Blizzard's guild bank
-- frame while BetterBags Next is on: every tab's items in categories (All Tabs) or a tab by itself,
-- its own buttons for guild bank slots, gold in and out, buying and renaming tabs, and every way of
-- closing it ending the visit.
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
const.BAG_VIEW = const.BAG_VIEW or { UNDEFINED = 0, SECTION_GRID = 2, SECTION_ALL_BAGS = 4 }

local stubs = {
  L = trackStub("Localization"),
  items = trackStub("Items"),
  database = trackStub("Database"),
  events = trackStub("Events"),
  searchBox = trackStub("SearchBox"),
  sonata = trackStub("Sonata"),
  elements = trackStub("SonataElements"),
  cursorPlacement = trackStub("CursorPlacement"),
  sectionFrame = trackStub("SectionFrame"),
  groups = trackStub("Groups"),
  itemFrame = trackStub("ItemFrame"),
  question = trackStub("Question"),
  guildBank = trackStub("GuildBank"),
  color = trackStub("Color"),
}

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
local modules = { { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextSparkles", "next/sparkles.lua" }, { "NextTabs", "next/tabs.lua" }, { "NextContent", "next/content.lua" },
  { "NextDrag", "next/drag.lua" }, { "NextChain", "next/chain.lua" }, { "NextPanel", "next/panel.lua" },
  { "NextGuildButton", "next/guildbutton.lua" }, { "NextGuildBank", "next/guildbank.lua" } }
for _, m in ipairs(modules) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local nextGuildBank = addon:GetModule("NextGuildBank")
local nextDrag = addon:GetModule("NextDrag")
local guildButton = addon:GetModule("NextGuildButton")
local style = addon:GetModule("NextStyle")
local tween = addon:GetModule("NextTween")
local render = addon:GetModule("Render")
local motion = addon:GetModule("Motion")
local context = addon:GetModule("Context")

local GUILD = 2
local ALL = 1
local SECTION_GRID, SECTION_ALL_BAGS = 2, 4

describe("NextGuildBank", function()
  local messages, handlers, timers, calls, data, asked

  local function ctx() return context:New("spec") end

  local function finishTweens()
    for _ = 1, 400 do
      local update = tween.driver and tween.driver:GetScript("OnUpdate")
      if update == nil then return end
      update(tween.driver, 0.05)
    end
  end

  local function runTimers()
    local pending = timers
    timers = {}
    for _, fn in ipairs(pending) do fn() end
  end

  local function tabIDs(g)
    local ids = {}
    for _, t in ipairs(g.tabs.tabs) do table.insert(ids, t.id) end
    return ids
  end

  local function tabNamed(g, name)
    for _, t in ipairs(g.tabs.tabs) do
      if t.text:GetText() == name then return t end
    end
  end

  local function click(button, mouse)
    button:GetScript("OnClick")(button, mouse or "LeftButton")
  end

  local function sent(name)
    local out = {}
    for _, m in ipairs(messages) do
      if m.name == name then table.insert(out, m.args) end
    end
    return out
  end

  local function tab(n, name, opts)
    opts = opts or {}
    return { tab = n, container = 1000 + n, name = name, icon = 100 + n, viewable = opts.viewable ~= false,
      canDeposit = opts.canDeposit ~= false, numWithdrawals = opts.numWithdrawals or 5,
      remainingWithdrawals = opts.remainingWithdrawals or 3 }
  end

  -- open makes the guild bank and opens it the way the refresh does (refresh-scheduler.md §11): the
  -- visit starts (guildbank/Opened), the panel shows, and its tabs load once it has shown.
  local function open(g)
    g = g or nextGuildBank:Create(ctx())
    addon.atGuildBank = true
    local shown = 0
    g:Show(ctx(), nil, function() shown = shown + 1 end)
    finishTweens()
    return g, shown
  end

  before_each(function()
    render:Init()
    tween:Init()
    motion:Init()
    nextDrag:Init()
    guildButton:Init()
    ResetMockGuildBank()
    messages, handlers, timers = {}, {}, {}
    calls = { load = {}, close = 0, buy = 0, deposit = 0, withdraw = 0, place = {}, cleared = 0, created = {},
      deposited = {}, withdrawn = {} }
    asked = nil
    data = {
      tabs = { tab(1, "Gear"), tab(2, "Mats", { remainingWithdrawals = -1 }), tab(3, "Officers", { viewable = false }),
        tab(4, "Donations", { numWithdrawals = 0 }) },
      current = 2, canBuy = false, canWithdraw = true, money = 1234567, withdrawMoney = 50000,
      showTabs = false, views = { [GUILD] = SECTION_GRID }, slotInfo = {}, guildName = "Moonguard Traders",
      canEdit = false,
    }
    override(addon, "isRetail", true)
    override(addon, "TriggerItemContextChanged", function() end)
    override(addon, "ForceHideBlizzardBags", function() end)
    override(addon, "atGuildBank", nil)
    override(const, "BAG_KIND", { BACKPACK = 0, BANK = 1, GUILD = GUILD, UNDEFINED = -1 })
    override(const, "BAG_VIEW", { UNDEFINED = 0, SECTION_GRID = SECTION_GRID, SECTION_ALL_BAGS = SECTION_ALL_BAGS })
    override(const, "GUILD_BANK_ALL_TAB", ALL)
    override(const, "GUILD_BANK_BAGS", { [1001] = 1, [1002] = 2, [1003] = 3, [1004] = 4 })
    override(const, "ITEM_QUALITY_COLOR", { [1] = { 1, 1, 1, 1 } })
    override(const, "ITEM_QUALITY", { Poor = 0, Common = 1, Uncommon = 2 })
    override(stubs.L, "G", function(_, key) return key end)
    override(stubs.items, "ExpireRecentItems", function() return false end)
    override(stubs.items, "GetAllSlotInfo", function() return { [GUILD] = data.slotInfo } end)
    override(stubs.database, "GetNextChain", function() return "apart" end)
    override(stubs.database, "GetNextSize", function() return "full" end)
    override(stubs.database, "GetInBagSearch", function() return true end)
    override(stubs.database, "GetGroupsEnabled", function() return false end)
    override(stubs.database, "GetShowGuildBankTabs", function() return data.showTabs end)
    override(stubs.database, "SetShowGuildBankTabs", function(_, shown) data.showTabs = shown end)
    override(stubs.database, "GetBagView", function(_, kind) return data.views[kind] end)
    override(stubs.database, "SetBagView", function(_, kind, view) data.views[kind] = view end)
    override(stubs.database, "GetItemLevelOptions", function() return { enabled = false } end)
    override(stubs.events, "SendMessage", function(_, _, name, ...)
      table.insert(messages, { name = name, args = { ... } })
    end)
    override(stubs.events, "RegisterMessage", function(_, name, fn) handlers[name] = fn end)
    override(stubs.events, "RegisterEvent", function(_, name, fn) handlers[name] = fn end)
    override(stubs.events, "BucketEvent", function() end)
    override(stubs.searchBox, "CreateBox", function(_, kind, parent)
      table.insert(calls.created, kind)
      local frame = CreateFrame("Frame", nil, parent)
      -- As searchBox:CreateBox makes it (frames/search.lua): a BagSearchBoxTemplate edit box.
      local textBox = CreateFrame("EditBox", nil, frame, "BagSearchBoxTemplate")
      return { frame = frame, textBox = textBox, helpText = textBox.Instructions, kind = kind }
    end)
    override(stubs.sonata, "UnregisterElement", function() end)
    override(stubs.sonata, "RegisterElement", function() end)
    override(stubs.elements, "DrawItemQuality", function() return false end)
    override(stubs.itemFrame, "DrawQualityGlowFor", function() end)
    override(stubs.guildBank, "Tabs", function() return data.tabs end)
    override(stubs.guildBank, "TabInfo", function(_, n) return data.tabs[n] end)
    override(stubs.guildBank, "TabOf", function(_, container) return const.GUILD_BANK_BAGS[container] end)
    override(stubs.guildBank, "ContainerOf", function(_, n) return 1000 + n end)
    override(stubs.guildBank, "CurrentTab", function() return data.current end)
    override(stubs.guildBank, "LoadTab", function(_, n)
      table.insert(calls.load, n)
      data.current = n
      return true
    end)
    override(stubs.guildBank, "CanBuyTab", function() return data.canBuy end)
    override(stubs.guildBank, "BuyTab", function() calls.buy = calls.buy + 1 end)
    override(stubs.guildBank, "DepositMoney", function() calls.deposit = calls.deposit + 1 end)
    override(stubs.guildBank, "WithdrawMoney", function() calls.withdraw = calls.withdraw + 1 end)
    override(stubs.guildBank, "Close", function() calls.close = calls.close + 1 end)
    override(stubs.guildBank, "PlaceCursorItem", function(_, n)
      table.insert(calls.place, n or "current")
      return "placed"
    end)
    override(stubs.question, "AskForInput", function(_, title, text, onInput)
      asked = { title = title, text = text, onInput = onInput }
    end)
    override(stubs.question, "YesNo", function(_, title, text, yes, no)
      asked = { title = title, text = text, yes = yes, no = no }
    end)
    override(stubs.guildBank, "DepositSlots", function(_, slots, n)
      table.insert(calls.deposited, { slots = slots, tab = n })
      return #slots
    end)
    override(stubs.guildBank, "WithdrawItems", function(_, list)
      table.insert(calls.withdrawn, list)
      return #list
    end)
    -- Every pile a section's virtual stacks hide comes with it (SectionFrame:WithStacks).
    override(stubs.sectionFrame, "WithStacks", function(_, list)
      local all = {}
      for _, d in ipairs(list) do
        table.insert(all, d)
        for _, pile in ipairs(d.piles or {}) do table.insert(all, pile) end
      end
      return all
    end)
    override(const, "BACKPACK_BAGS", { [0] = 0, [1] = 1 })
    override(C_Timer, "After", function(_, fn) table.insert(timers, fn) end)
    override(_G, "PlaySound", function() end)
    override(_G, "GetGuildInfo", function() return data.guildName, "Member", 3 end)
    override(_G, "GetGuildBankMoney", function() return data.money end)
    override(_G, "GetGuildBankWithdrawMoney", function() return data.withdrawMoney end)
    override(_G, "CanWithdrawGuildBankMoney", function() return data.canWithdraw end)
    override(_G, "CanEditGuildBankTabInfo", function() return data.canEdit end)
    -- Blizzard's item button helpers (Blizzard_ItemButton ItemButtonTemplate.lua), for guild buttons.
    override(_G, "SetItemButtonTexture", function(button, texture) button.icon:SetTexture(texture) end)
    override(_G, "SetItemButtonCount", function(button, count)
      if count and count > 1 then
        button.Count:SetText(count)
        button.Count:Show()
      else
        button.Count:Hide()
      end
    end)
    override(_G, "SetItemButtonDesaturated", function(button, desaturated) button.icon:SetDesaturated(desaturated) end)
    override(_G, "SetItemButtonQuality", function() end)
    _G._cursorHasItem = false
    _G._hiddenPopups = {}
  end)

  after_each(function()
    restore()
    ResetMockGuildBank()
    _G._cursorHasItem = false
  end)

  teardown(function()
    for i = #modules, 1, -1 do ResetModuleStub(modules[i][1]) end
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  describe("the panel", function()
    it("is a hidden, named panel on the left, the backpack's companion", function()
      local g = nextGuildBank:Create(ctx())
      assert.are.equal("BetterBagsNextGuildBank", g:GetName())
      assert.are.equal("LEFT", g.side)
      assert.are.equal(GUILD, g.kind)
      assert.are.equal("companion", g.chainRole)
      assert.is_false(g:IsShown())
      assert.are.equal("HIGH", g.frame:GetFrameStrata())
    end)

    it("draws the guild bank's own buttons, not the bags' item buttons", function()
      local g = nextGuildBank:Create(ctx())
      assert.are.equal(guildButton, g.content.buttonSource)
    end)

    it("is a panel its sections are dragged in", function()
      local g = nextGuildBank:Create(ctx())
      local registered = false
      for _, panel in ipairs(nextDrag.panels) do
        if panel == g then registered = true end
      end
      assert.is_true(registered)
    end)

    it("takes the guild bank's in-bag search box", function()
      local g = nextGuildBank:Create(ctx())
      assert.are.same({ GUILD }, calls.created)
      assert.are.equal(GUILD, g.searchBox.kind)
    end)

    it("is washed in the guild's green", function()
      local g = nextGuildBank:Create(ctx())
      assert.are.same(style.Color.GuildWash, g.washColor)
    end)

    it("shows the guild's gold at its screen edge", function()
      local g = open()
      assert.are.equal(C_CurrencyInfo.GetCoinTextureString(1234567), g.moneyFrame.text:GetText())
    end)

    it("has close, settings, deposit gold and withdraw gold in its header", function()
      local g = open()
      assert.are.same({ g.closeButton, g.settingsButton, g.depositButton, g.withdrawButton }, g.headerButtons)
      click(g.depositButton)
      click(g.withdrawButton)
      assert.are.equal(1, calls.deposit)
      assert.are.equal(1, calls.withdraw)
      click(g.settingsButton)
      assert.are.equal(1, #sent("config/Open"))
    end)

    it("enables withdrawing gold only for a member who may", function()
      data.canWithdraw = false
      local g = open()
      assert.is_false(g.withdrawButton:IsEnabled())
      data.canWithdraw = true
      handlers["guildbank/MoneyChanged"](ctx())
      assert.is_true(g.withdrawButton:IsEnabled())
    end)

    it("updates the gold when the guild bank's money changes", function()
      local g = open()
      data.money = 99
      handlers["guildbank/MoneyChanged"](ctx())
      assert.are.equal(C_CurrencyInfo.GetCoinTextureString(99), g.moneyFrame.text:GetText())
    end)
  end)

  describe("opening", function()
    it("shows every tab's items in categories, titled with the guild's name", function()
      local g = open()
      assert.are.equal("Moonguard Traders", g.title:GetText())
      assert.are.equal(ALL, g:GetCurrentTabID())
      assert.are.equal(SECTION_GRID, data.views[GUILD])
      assert.are.equal(ALL, g.tabs.selected)
    end)

    it("says Guild Bank when the guild has no name for the player", function()
      data.guildName = nil
      local g = open()
      assert.are.equal("Guild Bank", g.title:GetText())
    end)

    it("lists All Tabs, then every tab the player can view, and buying one only for the guild leader", function()
      local g = open()
      assert.are.same({ ALL, 1001, 1002, 1004 }, tabIDs(g))
      assert.are.equal(101, tabNamed(g, "Gear").icon:GetTexture())
      data.canBuy = true
      g:RefreshTabs()
      assert.are.same({ ALL, 1001, 1002, 1004, 0 }, tabIDs(g))
    end)

    it("says Loading... until the guild bank has been read", function()
      local g = open()
      assert.is_true(g.emptyText:IsShown())
      assert.are.equal("Loading...", g.emptyText:GetText())
    end)

    it("tells the refresh it has finished showing once it has slid in", function()
      local _, shown = open()
      assert.are.equal(1, shown)
    end)

    it("shows the tab last shown by itself, the guild bank's current one", function()
      data.showTabs = true
      local g = open()
      assert.are.equal(1002, g:GetCurrentTabID())
      assert.are.equal("Mats", g.title:GetText())
      assert.are.equal(SECTION_ALL_BAGS, data.views[GUILD])
      assert.are.equal(1002, g.tabs.selected)
    end)

    it("shows the first tab it can view when the current one is closed to the player", function()
      data.showTabs = true
      data.current = 3
      local g = open()
      assert.are.equal(1001, g:GetCurrentTabID())
    end)
  end)

  describe("tabs", function()
    it("shows a tab by itself, made current (deposits go to it) and queried, as Blizzard's tab click does", function()
      local g = open()
      messages = {}
      click(tabNamed(g, "Gear").button)
      assert.are.same({ 1 }, calls.load)
      assert.is_true(data.showTabs)
      assert.are.equal(SECTION_ALL_BAGS, data.views[GUILD])
      assert.are.equal(1001, g:GetCurrentTabID())
      assert.are.equal("Gear", g.title:GetText())
      assert.are.equal(1001, g.tabs.selected)
      assert.are.same({ { { guild = true, resetLayout = true } } }, sent("bags/Rederive"))
    end)

    it("goes back to every tab's items with All Tabs", function()
      data.showTabs = true
      local g = open()
      messages = {}
      click(tabNamed(g, "All Tabs").button)
      assert.is_false(data.showTabs)
      assert.are.equal(SECTION_GRID, data.views[GUILD])
      assert.are.equal(ALL, g:GetCurrentTabID())
      assert.are.equal("Moonguard Traders", g.title:GetText())
      assert.are.same({ { { guild = true, resetLayout = true } } }, sent("bags/Rederive"))
      assert.are.same({}, calls.load)
    end)

    it("does nothing for a click on the tab already shown", function()
      local g = open()
      messages = {}
      click(tabNamed(g, "All Tabs").button)
      assert.are.same({}, sent("bags/Rederive"))
    end)

    it("buys the next tab with Blizzard's own dialog", function()
      data.canBuy = true
      local g = open()
      click(g.tabs:Tab(0).button)
      assert.are.equal(1, calls.buy)
      assert.are.equal(ALL, g:GetCurrentTabID())
    end)

    it("renames a tab, keeping its icon, for a member who may edit tabs", function()
      data.canEdit = true
      local g = open()
      click(tabNamed(g, "Mats").button, "RightButton")
      assert.is_not_nil(asked)
      asked.onInput("Reagents")
      assert.are.same({ { tab = 2, name = "Reagents", icon = 102 } }, _G._guildBankCalls.tabInfo)
      asked.onInput("")
      assert.are.equal(1, #_G._guildBankCalls.tabInfo, "no empty name")
    end)

    it("renames nothing for a member who may not, nor All Tabs", function()
      local g = open()
      click(tabNamed(g, "Mats").button, "RightButton")
      assert.is_nil(asked)
      data.canEdit = true
      click(tabNamed(g, "All Tabs").button, "RightButton")
      assert.is_nil(asked)
    end)

    it("says what the player may do in a tab, and how many stacks are left to take today", function()
      local g = open()
      local lines = {}
      local saved = { GameTooltip.SetText, GameTooltip.AddLine }
      GameTooltip.SetText = function(_, text) table.insert(lines, text) end
      GameTooltip.AddLine = function(_, text) table.insert(lines, text) end
      local t = tabNamed(g, "Gear")
      t.tooltip(t.button)
      local donations = tabNamed(g, "Donations")
      donations.tooltip(donations.button)
      local mats = tabNamed(g, "Mats")
      mats.tooltip(mats.button)
      GameTooltip.SetText, GameTooltip.AddLine = saved[1], saved[2]
      assert.are.same({
        "Gear", GUILDBANK_TAB_FULL_ACCESS, "Withdrawals left today: 3 stacks", "Left-click to view this tab",
        "Donations", GUILDBANK_TAB_DEPOSIT_ONLY, "Left-click to view this tab",
        "Mats", GUILDBANK_TAB_FULL_ACCESS, "Withdrawals left today: Unlimited", "Left-click to view this tab",
      }, lines)
    end)

    it("lists its tabs again when the guild bank's tabs change, back to All Tabs when the one shown is gone", function()
      data.showTabs = true
      data.current = 4
      local g = open()
      table.remove(data.tabs, 4)
      handlers["guildbank/TabsChanged"](ctx())
      assert.are.same({ ALL, 1001, 1002 }, tabIDs(g))
      assert.are.equal(ALL, g:GetCurrentTabID())
      assert.is_false(data.showTabs)
    end)
  end)

  describe("drawing", function()
    it("draws the tab shown with guild buttons, and counts the free slots", function()
      local g = open()
      g:Draw(ctx(), {
        sortedItems = {},
        tabs = { [ALL] = { categories = { { name = "Ore" } }, items = {
          { slotkey = "1002_4", bagid = 1002, slotid = 4, guildTab = 2, itemInfo = { category = "Ore", itemIcon = 5,
            currentItemCount = 20, itemQuality = 1, classID = 7 } },
        }, freeSpace = { showAll = false, buttons = { { slotkey = "1001_2", bagid = 1001, slotid = 2, count = 96,
          key = "Gear", itemInfo = { emptySlotName = "Gear" } } } } } },
      })
      local ore = g.content.buttons["1002_4"]
      assert.are.equal(guildButton:GetButton(ctx(), "1002_4"), ore)
      assert.are.equal(2, ore.tab)
      assert.are.equal("96 free slots", g.freeText:GetText())
      assert.is_false(g.emptyText:IsShown())
    end)
  end)

  describe("closing", function()
    it("slides out and ends the visit once when its close button is clicked", function()
      local g = open()
      click(g.closeButton)
      g:Hide(ctx())
      assert.are.equal(1, calls.close)
      finishTweens()
      assert.is_false(g:IsShown())
    end)

    it("ends the visit a frame later when Escape hides it", function()
      local g = open()
      g.frame:Hide()
      g.frame:GetScript("OnHide")(g.frame)
      assert.are.equal(0, calls.close)
      runTimers()
      assert.are.equal(1, calls.close)
    end)

    it("ends nothing when the visit ended before the frame passed", function()
      local g = open()
      g.frame:Hide()
      g.frame:GetScript("OnHide")(g.frame)
      addon.atGuildBank = false
      handlers["guildbank/Closed"](ctx())
      runTimers()
      assert.are.equal(0, calls.close)
    end)

    it("slides out when the visit ends, closing Blizzard's guild bank dialogs, and lets go of its buttons once out", function()
      local g = open()
      g:Draw(ctx(), { sortedItems = {}, tabs = { [ALL] = { categories = { { name = "Ore" } }, items = {
        { slotkey = "1002_4", bagid = 1002, slotid = 4, guildTab = 2, itemInfo = { category = "Ore", itemIcon = 5,
          currentItemCount = 1, itemQuality = 1, classID = 7 } } } } } })
      local ore = g.content.buttons["1002_4"]
      addon.atGuildBank = false
      handlers["guildbank/Closed"](ctx())
      assert.are.same({ "GUILDBANK_DEPOSIT", "GUILDBANK_WITHDRAW", "CONFIRM_BUY_GUILDBANK_TAB" }, _G._hiddenPopups)
      assert.is_true(ore.frame:IsShown(), "it slides out full")
      finishTweens()
      g.frame:GetScript("OnHide")(g.frame)
      assert.is_false(g:IsShown())
      assert.is_false(ore.frame:IsShown())
      assert.are.equal(0, calls.close, "the visit had ended")
    end)
  end)

  describe("drops", function()
    it("puts the item held into the guild bank's current tab while every tab shows", function()
      local g = open()
      assert.are.equal("placed", g:PlaceCursorItem())
      assert.are.same({ "current" }, calls.place)
    end)

    it("puts the item held into the tab shown by itself", function()
      data.showTabs = true
      local g = open()
      g:PlaceCursorItem()
      assert.are.same({ 2 }, calls.place)
    end)
  end)

  -- Sections dragged in and out (next.md §7, guild-bank.md §5): the guild bank says what it takes and
  -- moves it, as the vendor sells what is dragged onto it.
  describe("sections moved in and out", function()
    local function bagItem(bag, slot, opts)
      opts = opts or {}
      return { bagid = bag, slotid = slot, slotkey = bag .. "_" .. slot, piles = opts.piles,
        itemInfo = { isBound = opts.bound or false } }
    end

    it("deposits into the tab shown by itself, else the guild bank's current tab, only where the player may", function()
      local g = open()
      assert.are.equal(2, g:DepositTab())
      data.tabs[2].canDeposit = false
      assert.is_nil(g:DepositTab())
      data.showTabs = true
      data.current = 1
      g = open(g)
      assert.are.equal(1, g:DepositTab())
    end)

    it("deposits a backpack section's items and their piles, leaving out bound items and other bags'", function()
      local g = open()
      local result = g:Deposit(ctx(), {
        bagItem(0, 1, { piles = { bagItem(1, 4) } }),
        bagItem(0, 2, { bound = true }),
        bagItem(6, 3),
      })
      assert.are.equal("deposited", result)
      assert.are.same({ { slots = { { bag = 0, slot = 1 }, { bag = 1, slot = 4 } }, tab = 2 } }, calls.deposited)
    end)

    it("deposits into the tab it was dropped on", function()
      local g = open()
      g:Deposit(ctx(), { bagItem(0, 1) }, 1001)
      assert.are.equal(1, calls.deposited[1].tab)
    end)

    -- Confirmed in the guild bank itself, as a big sale is in the vendor (NextDrag docks the section).
    it("deposits into a tab the player cannot take items back out of only once confirmed, with no dialog", function()
      local g = open()
      local items = { bagItem(0, 1), bagItem(0, 2) }
      local result, confirmation = g:Deposit(ctx(), items, 1004)
      assert.are.equal("confirm", result)
      assert.are.same({ title = "Deposit 2 items?", warning = "You cannot take them back out of Donations.",
        hint = "Double-click to deposit · Right-click to cancel" }, confirmation)
      assert.are.same({}, calls.deposited)
      assert.is_nil(asked)
      assert.are.equal("deposited", g:Deposit(ctx(), items, 1004, true))
      assert.are.equal(4, calls.deposited[1].tab)
    end)

    it("deposits nothing when nothing in the section can go in, or no tab takes deposits", function()
      local g = open()
      assert.are.equal("nothing", g:Deposit(ctx(), { bagItem(0, 2, { bound = true }) }))
      data.tabs[2].canDeposit = false
      assert.are.equal("nothing", g:Deposit(ctx(), { bagItem(0, 1) }))
      assert.are.same({}, calls.deposited)
      assert.is_nil(asked)
    end)

    it("withdraws a section on a right click on its header, and says so", function()
      local g = open()
      g:Draw(ctx(), { sortedItems = {}, tabs = { [ALL] = { categories = { { name = "Ore" } }, items = {
        { slotkey = "1002_4", bagid = 1002, slotid = 4, guildTab = 2, itemInfo = { category = "Ore", itemIcon = 5,
          currentItemCount = 20, itemQuality = 1, classID = 7 } } } } } })
      local section = g.content.byName.Ore
      g:OnHeaderClick(ctx(), section, "RightButton")
      assert.are.equal(1, #calls.withdrawn)
      assert.are.equal("1002_4", calls.withdrawn[1][1].slotkey)
      local lines = {}
      local saved = { GameTooltip.SetText, GameTooltip.AddLine }
      GameTooltip.SetText = function(_, text) table.insert(lines, text) end
      GameTooltip.AddLine = function(_, text) table.insert(lines, text) end
      g:OnHeaderEnter(section)
      GameTooltip.SetText, GameTooltip.AddLine = saved[1], saved[2]
      assert.are.same({ "Ore", "Drag to reorder, or onto the backpack to take it out.", "Right-click to take it out to your bags." }, lines)
    end)

    it("withdraws a guild section's items and their piles", function()
      local g = open()
      local a = { bagid = 1002, slotid = 4, guildTab = 2 }
      local pile = { bagid = 1001, slotid = 9, guildTab = 1 }
      a.piles = { pile }
      g:Withdraw({ a })
      assert.are.same({ { a, pile } }, calls.withdrawn)
    end)
  end)

  describe("switching designs", function()
    it("hides at once and lets go of its buttons when BetterBags Next is switched off", function()
      local g = open()
      g:Deactivate(ctx())
      assert.is_false(g:IsShown())
    end)
  end)

  -- Blizzard's ShowGuildBankFrame shows its frame (ShowUIPanel), then ends the visit at once when the
  -- frame is not visible (Blizzard_GuildBankUI_Bootstrap.lua; the TBC, Wrath, Cata and Mists UIParent
  -- do the same), and the frame's OnHide ends it too (GuildBankFrameMixin:OnHide). So the frame is put
  -- under a tiny shown frame first (visible to Blizzard's check, never seen), its OnHide taken off,
  -- and a frame later under the hidden frame (Bagnon's takeover, core/features/uiOverrides.lua).
  describe("Blizzard's guild bank frame", function()
    local sneaky, savedFrame, savedShowUIPanel

    -- showGuildBankFrame is Blizzard's ShowGuildBankFrame.
    local function showGuildBankFrame()
      ShowUIPanel(GuildBankFrame)
      if not GuildBankFrame:IsVisible() then
        CloseGuildBankFrame()
      end
    end

    before_each(function()
      savedFrame, savedShowUIPanel = _G.GuildBankFrame, _G.ShowUIPanel
      -- As the module starts: nothing hooked or taken (each test puts the global back).
      nextGuildBank.hookedShow, nextGuildBank.hookedFrame, nextGuildBank.taken = false, nil, nil
      sneaky = CreateFrame("Frame")
      sneaky:Hide()
      _G.GuildBankFrame = CreateFrame("Frame", "GuildBankFrame", UIParent)
      _G.GuildBankFrame:Hide()
      _G.GuildBankFrame:SetScript("OnHide", function() CloseGuildBankFrame() end)
    end)

    after_each(function()
      nextGuildBank:GiveBack()
      _G.GuildBankFrame, _G.ShowUIPanel = savedFrame, savedShowUIPanel
    end)

    it("stays shown and visible to Blizzard's check, never seen, and is hidden a frame later", function()
      local g = nextGuildBank:Create(ctx())
      nextGuildBank:TakeOver(sneaky)
      addon.atGuildBank = true
      showGuildBankFrame()
      assert.are.equal(0, _G._guildBankCalls.closed, "Blizzard's visibility check passed")
      assert.is_true(GuildBankFrame:IsShown())
      assert.is_nil(GuildBankFrame:GetScript("OnHide"), "its OnHide no longer ends the visit")
      local tiny = GuildBankFrame:GetParent()
      assert.are_not.equal(UIParent, tiny)
      assert.is_true(tiny:GetScale() < 0.01)
      runTimers()
      assert.are.equal(sneaky, GuildBankFrame:GetParent())
      assert.is_true(GuildBankFrame:IsShown())
      assert.is_false(GuildBankFrame:IsVisible())
      assert.are.equal(0, _G._guildBankCalls.closed)
      local _ = g
    end)

    it("ends the visit a frame later when something hides the frame during a visit (another panel)", function()
      nextGuildBank:Create(ctx())
      nextGuildBank:TakeOver(sneaky)
      addon.atGuildBank = true
      showGuildBankFrame()
      runTimers()
      GuildBankFrame:Hide()
      assert.are.equal(0, calls.close)
      runTimers()
      assert.are.equal(1, calls.close)
    end)

    it("hooks the frame's Hide once, and ShowUIPanel once, however often it is taken", function()
      nextGuildBank:Create(ctx())
      nextGuildBank:TakeOver(sneaky)
      local hooked = ShowUIPanel
      nextGuildBank:GiveBack()
      nextGuildBank:TakeOver(sneaky)
      assert.are.equal(hooked, ShowUIPanel)
      addon.atGuildBank = true
      showGuildBankFrame()
      runTimers()
      showGuildBankFrame()
      runTimers()
      GuildBankFrame:Hide()
      runTimers()
      assert.are.equal(1, calls.close)
    end)

    it("is given back to UIParent with its OnHide when BetterBags Next is switched off", function()
      nextGuildBank:Create(ctx())
      nextGuildBank:TakeOver(sneaky)
      addon.atGuildBank = true
      showGuildBankFrame()
      runTimers()
      addon.atGuildBank = false
      GuildBankFrame:Hide()
      nextGuildBank:GiveBack()
      assert.are.equal(UIParent, GuildBankFrame:GetParent())
      assert.is_function(GuildBankFrame:GetScript("OnHide"))
      showGuildBankFrame()
      assert.are.equal(UIParent, GuildBankFrame:GetParent(), "not taken while given back")
    end)

    it("leaves any other panel alone", function()
      nextGuildBank:Create(ctx())
      nextGuildBank:TakeOver(sneaky)
      local other = CreateFrame("Frame", nil, UIParent)
      other:Hide()
      ShowUIPanel(other)
      assert.are.equal(UIParent, other:GetParent())
    end)
  end)
end)
