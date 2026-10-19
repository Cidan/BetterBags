-- guildbank_spec.lua -- the guild bank as a data source (data/guildbank.lua, guild-bank.md §2).

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local L = StubBetterBagsModule("Localization")
L.G = L.G or function(_, key) return key end

-- The guild bank's constants (core/constants.lua; spec/core/constants_spec.lua "guild bank" checks
-- them), on whichever Constants module earlier specs left.
local const = StubBetterBagsModule("Constants")
if const.GUILD_BANK_TAB_CONTAINER == nil then
  const.GUILD_BANK_BAGS, const.GUILD_BANK_TAB_CONTAINER, const.GUILD_BANK_BAGS_LIST = {}, {}, {}
  for tab = 1, MAX_GUILDBANK_TABS do
    const.GUILD_BANK_BAGS[1000 + tab] = tab
    const.GUILD_BANK_TAB_CONTAINER[tab] = 1000 + tab
    const.GUILD_BANK_BAGS_LIST[tab] = 1000 + tab
  end
  const.GUILD_BANK_SLOTS = 98
end
LoadFreshBetterBagsModule("Context", "core/context.lua")
local events = LoadFreshBetterBagsModule("Events", "core/events.lua")
local guildBank = LoadFreshBetterBagsModule("GuildBank", "data/guildbank.lua")

local GUILD_BANKER = Enum.PlayerInteractionType.GuildBanker

describe("GuildBank (the guild bank as a data source)", function()
  local timers, messages, savedAfter, savedHasGuildBank

  local function fire(event, ...)
    events._eventMap[event].fn(event, ...)
  end

  local function runTimers()
    local due = timers
    timers = {}
    for _, t in ipairs(due) do t.fn() end
  end

  local function tab(name, opts)
    opts = opts or {}
    return { name = name, icon = opts.icon or 134400, isViewable = opts.isViewable ~= false,
      canDeposit = opts.canDeposit ~= false, numWithdrawals = opts.numWithdrawals or 5,
      remainingWithdrawals = opts.remainingWithdrawals or 5, slots = opts.slots or {} }
  end

  local function openBank()
    fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", GUILD_BANKER)
  end

  before_each(function()
    ResetMockGuildBank()
    savedHasGuildBank = addon.hasGuildBank
    addon.hasGuildBank = true
    events:Init()
    timers, messages = {}, {}
    savedAfter = C_Timer.After
    C_Timer.After = function(delay, fn) table.insert(timers, { delay = delay, fn = fn }) end
    for _, name in ipairs({ "guildbank/Opened", "guildbank/Closed", "guildbank/TabLoaded", "guildbank/Changed",
      "guildbank/TabsChanged", "guildbank/MoneyChanged" }) do
      events:RegisterMessage(name, function(_, ...)
        table.insert(messages, { name = name, args = { ... } })
      end)
    end
    guildBank:Init()
    guildBank:OnEnable()
    _G._guildBank.tabs = {
      tab("Gear", { slots = { [1] = { link = "|Hitem:100|h[Sword]|h", texture = 1, count = 1, quality = 3 } } }),
      tab("Mats", { slots = { [4] = { link = "|Hitem:200|h[Ore]|h", texture = 2, count = 20, quality = 1, locked = true } } }),
      tab("Officers", { isViewable = false }),
      tab("", { canDeposit = false }),
    }
    _G._guildBank.current = 2
  end)

  after_each(function()
    C_Timer.After = savedAfter
    addon.atGuildBank = nil
    addon.hasGuildBank = savedHasGuildBank
  end)

  it("listens to nothing on a client without a guild bank (Classic Era)", function()
    events:Init()
    addon.hasGuildBank = false
    guildBank:OnEnable()
    assert.is_nil(events._eventMap["GUILDBANKBAGSLOTS_CHANGED"])
    assert.is_nil(events._eventMap["PLAYER_INTERACTION_MANAGER_FRAME_SHOW"])
  end)

  local function names(list)
    local out = {}
    for _, m in ipairs(list) do table.insert(out, m.name) end
    return out
  end

  describe("opening and closing", function()
    it("opens with the guild banker interaction, and says so", function()
      fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Enum.PlayerInteractionType.Banker)
      assert.is_false(guildBank:IsOpen())
      openBank()
      assert.is_true(guildBank:IsOpen())
      assert.is_true(addon.atGuildBank)
      assert.are.same({ "guildbank/Opened" }, names(messages))
    end)

    it("closes with the interaction, forgetting what it loaded", function()
      openBank()
      guildBank:Load()
      fire("GUILDBANKBAGSLOTS_CHANGED")
      assert.is_true(guildBank:IsLoaded(2))
      fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", GUILD_BANKER)
      assert.is_false(guildBank:IsOpen())
      assert.is_false(addon.atGuildBank)
      assert.is_false(guildBank:IsLoaded(2))
      assert.are.equal("guildbank/Closed", messages[#messages].name)
    end)
  end)

  describe("tabs", function()
    it("lists the purchased tabs as Blizzard's frame shows them, named Tab N when unnamed", function()
      local tabs = guildBank:Tabs()
      assert.are.equal(4, #tabs)
      assert.are.same({ "Gear", "Mats", "Officers", "Tab 4" },
        { tabs[1].name, tabs[2].name, tabs[3].name, tabs[4].name })
      assert.are.equal(const.GUILD_BANK_TAB_CONTAINER[2], tabs[2].container)
      assert.is_false(tabs[3].viewable)
      assert.is_false(tabs[4].canDeposit)
      assert.are.equal(5, tabs[1].remainingWithdrawals)
    end)

    it("maps a tab to its container and back", function()
      local container = guildBank:ContainerOf(3)
      assert.are.equal(const.GUILD_BANK_TAB_CONTAINER[3], container)
      assert.are.equal(3, guildBank:TabOf(container))
      assert.is_nil(guildBank:TabOf(0))
    end)
  end)

  -- Blizzard's frame loads a tab by making it current and querying it (GuildBankTabMixin:OnClick:
  -- SetCurrentGuildBankTab, then QueryGuildBankTab); the server answers with GUILDBANKBAGSLOTS_CHANGED.
  describe("loading the tabs", function()
    it("queries the viewable tabs one at a time, the current one first, the way Blizzard's tab click does", function()
      openBank()
      assert.is_true(guildBank:Load())
      assert.are.same({ 2 }, _G._guildBankCalls.queries)
      fire("GUILDBANKBAGSLOTS_CHANGED")
      assert.are.same({ 2, 1 }, _G._guildBankCalls.queries)
      assert.are.equal(1, _G._guildBank.current, "made current before it is queried")
      fire("GUILDBANKBAGSLOTS_CHANGED")
      assert.are.same({ 2, 1, 4 }, _G._guildBankCalls.queries, "the tab it cannot view is never queried")
      fire("GUILDBANKBAGSLOTS_CHANGED")
      assert.are.same({ 2, 1, 4 }, _G._guildBankCalls.queries)
      assert.are.equal(2, _G._guildBank.current, "the player's current tab is current again")
      assert.is_true(guildBank:IsLoaded(1) and guildBank:IsLoaded(2) and guildBank:IsLoaded(4))
      assert.is_false(guildBank:IsLoaded(3))
      assert.is_false(guildBank:IsLoading())
    end)

    it("says when each tab has loaded", function()
      openBank()
      guildBank:Load()
      fire("GUILDBANKBAGSLOTS_CHANGED")
      fire("GUILDBANKBAGSLOTS_CHANGED")
      local loaded = {}
      for _, m in ipairs(messages) do
        if m.name == "guildbank/TabLoaded" then table.insert(loaded, m.args[1]) end
      end
      assert.are.same({ 2, 1 }, loaded)
    end)

    it("lists the loaded tabs' containers for the read", function()
      openBank()
      guildBank:Load()
      fire("GUILDBANKBAGSLOTS_CHANGED")
      local containers = guildBank:LoadedContainers()
      assert.are.same({ [guildBank:ContainerOf(2)] = guildBank:ContainerOf(2) }, containers)
    end)

    it("counts a tab loaded when no answer comes in time, and goes on", function()
      openBank()
      guildBank:Load()
      assert.are.equal(guildBank.QUERY_TIMEOUT, timers[1].delay)
      runTimers()
      assert.is_true(guildBank:IsLoaded(2))
      assert.are.same({ 2, 1 }, _G._guildBankCalls.queries)
    end)

    it("ignores a timeout whose answer came", function()
      openBank()
      guildBank:Load()
      local first = timers[1]
      fire("GUILDBANKBAGSLOTS_CHANGED")
      first.fn()
      assert.are.same({ 2, 1 }, _G._guildBankCalls.queries, "tab 1 was not skipped")
      assert.is_false(guildBank:IsLoaded(1))
    end)

    it("stops when the guild bank closes", function()
      openBank()
      guildBank:Load()
      fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", GUILD_BANKER)
      runTimers()
      assert.are.same({ 2 }, _G._guildBankCalls.queries)
      assert.is_false(guildBank:IsLoaded(2))
    end)

    it("loads one tab on its own (a tab shown by itself), making it current", function()
      openBank()
      guildBank:LoadTab(4)
      assert.are.same({ 4 }, _G._guildBankCalls.queries)
      assert.are.equal(4, _G._guildBank.current)
      fire("GUILDBANKBAGSLOTS_CHANGED")
      assert.is_true(guildBank:IsLoaded(4))
    end)

    it("does nothing while the guild bank is closed", function()
      assert.is_false(guildBank:Load())
      assert.are.same({}, _G._guildBankCalls.queries)
    end)
  end)

  describe("reading slots", function()
    it("reads a slot of a tab the server sent, and nothing for an empty one", function()
      _G._guildBank.delivered[2] = true
      local slot = guildBank:ReadSlot(2, 4)
      assert.are.same({ link = "|Hitem:200|h[Ore]|h", texture = 2, count = 20, locked = true, isFiltered = false,
        quality = 1 }, slot)
      assert.is_nil(guildBank:ReadSlot(2, 1))
    end)
  end)

  describe("changes", function()
    it("says the slots changed when the server sends a tab outside loading, and when locks change", function()
      openBank()
      messages = {}
      fire("GUILDBANKBAGSLOTS_CHANGED")
      fire("GUILDBANK_ITEM_LOCK_CHANGED")
      assert.are.same({ "guildbank/Changed", "guildbank/Changed" }, names(messages))
    end)

    it("says the tabs or the money changed", function()
      openBank()
      messages = {}
      fire("GUILDBANK_UPDATE_TABS")
      fire("GUILDBANK_UPDATE_MONEY")
      fire("GUILDBANK_UPDATE_WITHDRAWMONEY")
      assert.are.same({ "guildbank/TabsChanged", "guildbank/MoneyChanged", "guildbank/MoneyChanged" }, names(messages))
    end)

    it("says nothing while closed", function()
      fire("GUILDBANKBAGSLOTS_CHANGED")
      fire("GUILDBANK_UPDATE_TABS")
      assert.are.same({}, messages)
    end)
  end)

  -- Blizzard's item buttons act on GetCurrentGuildBankTab() (GuildBankItemButtonMixin:OnClick), so
  -- an item of another tab is acted on once its tab is current.
  describe("acting on items", function()
    before_each(function()
      openBank()
      _G._guildBank.current = 1
    end)

    it("picks an item up from its own tab, made current first", function()
      guildBank:Pickup(2, 4)
      assert.are.same({ { tab = 2, slot = 4, current = 2 } }, _G._guildBankCalls.pickup)
    end)

    it("withdraws to the bags (AutoStoreGuildBankItem) and splits from the item's tab", function()
      guildBank:Withdraw(2, 4)
      guildBank:Split(2, 4, 5)
      assert.are.same({ { tab = 2, slot = 4, current = 2 } }, _G._guildBankCalls.autoStore)
      assert.are.same({ { tab = 2, slot = 4, amount = 5, current = 2 } }, _G._guildBankCalls.split)
    end)

    it("does not make a tab current again when it already is", function()
      guildBank:Pickup(1, 3)
      assert.are.same({}, _G._guildBankCalls.setCurrent)
    end)
  end)

  -- Only into tabs it has loaded: a tab the client never received reads as empty, and a pickup on a
  -- slot that is not empty swaps the cursor's item with what is there.
  describe("placing the cursor's item", function()
    before_each(function()
      openBank()
      for t = 1, 4 do _G._guildBank.delivered[t] = true end
      guildBank:Load()
      while guildBank:IsLoading() do fire("GUILDBANKBAGSLOTS_CHANGED") end
      _G._guildBankCalls.setCurrent = {}
      _G._cursorType = "item"
      _G._guildBank.current = 1
    end)

    it("never into a tab it has not loaded, saying the guild bank is still loading", function()
      fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", GUILD_BANKER)
      openBank()
      UIErrorsFrame._messages = {}
      assert.are.equal("loading", guildBank:PlaceCursorItem(2))
      assert.are.same({}, _G._guildBankCalls.pickup)
      assert.are.equal("The guild bank is still loading.", UIErrorsFrame._messages[1].text)
    end)

    after_each(function()
      ClearCursor()
    end)

    it("puts it in the first free slot of the tab asked for, made current", function()
      assert.are.equal("placed", guildBank:PlaceCursorItem(2))
      assert.are.same({ { tab = 2, slot = 1, current = 2 } }, _G._guildBankCalls.pickup)
    end)

    it("puts it in the current tab when no tab is asked for", function()
      assert.are.equal("placed", guildBank:PlaceCursorItem())
      assert.are.same({ { tab = 1, slot = 2, current = 1 } }, _G._guildBankCalls.pickup)
    end)

    it("goes to the next tab it may deposit in when that one is full or closed to it", function()
      local full = {}
      for slot = 1, const.GUILD_BANK_SLOTS do full[slot] = { link = "|Hitem:1|h[x]|h", texture = 1, count = 1 } end
      _G._guildBank.tabs[1].slots = full
      assert.are.equal("placed", guildBank:PlaceCursorItem())
      assert.are.equal(2, _G._guildBankCalls.pickup[1].tab)
      _G._guildBankCalls.pickup = {}
      assert.are.equal("placed", guildBank:PlaceCursorItem(4))
      assert.are.equal(2, _G._guildBankCalls.pickup[1].tab, "tab 4 takes no deposits from this player")
    end)

    it("says the guild bank is full when no tab it may deposit in has room", function()
      local full = {}
      for slot = 1, const.GUILD_BANK_SLOTS do full[slot] = { link = "|Hitem:1|h[x]|h", texture = 1, count = 1 } end
      _G._guildBank.tabs[1].slots = full
      _G._guildBank.tabs[2].slots = full
      UIErrorsFrame._messages = {}
      assert.are.equal("full", guildBank:PlaceCursorItem())
      assert.are.same({}, _G._guildBankCalls.pickup)
      assert.are.equal(1, #UIErrorsFrame._messages)
    end)

    it("ignores anything but an item", function()
      _G._cursorType = "money"
      assert.are.equal("ignored", guildBank:PlaceCursorItem())
      assert.are.same({}, _G._guildBankCalls.pickup)
    end)
  end)

  describe("money and tabs", function()
    before_each(function()
      openBank()
      _G._lastPopupShown = nil
    end)

    it("deposits and withdraws gold through Blizzard's own dialogs", function()
      guildBank:DepositMoney()
      assert.are.equal("GUILDBANK_DEPOSIT", _G._lastPopupShown.name)
      _G._lastPopupShown = nil
      guildBank:WithdrawMoney()
      assert.is_nil(_G._lastPopupShown, "only a player who may withdraw")
      _G._guildBank.canWithdrawMoney = true
      guildBank:WithdrawMoney()
      assert.are.equal("GUILDBANK_WITHDRAW", _G._lastPopupShown.name)
    end)

    it("buys a tab only for the guild leader with a tab left to buy, through Blizzard's dialog", function()
      _G._guildBank.tabCost = 1000
      assert.is_false(guildBank:CanBuyTab())
      _G._guildBank.isLeader = true
      assert.is_true(guildBank:CanBuyTab())
      guildBank:BuyTab()
      assert.are.equal("CONFIRM_BUY_GUILDBANK_TAB", _G._lastPopupShown.name)
      for t = 5, MAX_BUY_GUILDBANK_TABS do _G._guildBank.tabs[t] = tab("T" .. t) end
      assert.is_false(guildBank:CanBuyTab())
    end)

    it("ends the visit", function()
      guildBank:Close()
      assert.are.equal(1, _G._guildBankCalls.closed)
    end)
  end)
end)
