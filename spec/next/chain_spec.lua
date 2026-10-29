-- chain_spec.lua -- NextChain (next/chain.lua): BetterBags Next's backpack and its companion (the
-- bank or the vendor) apart on opposite edges of the screen, or chained together on one (next.md
-- §12). Asked: an anchor bag on the left or the right; clicking a bag's name flies it to the other
-- and their ribbons merge, intertwined and coupled; clicking a chained bag's name puts it back;
-- clicking the anchor's name moves both to the other side; kept across sessions; vendors, banks and
-- the backpack alike. Each bag keeps its orientation (asked: "fixed"), and the backpack alone opens
-- at its own edge, joining its companion when it opens (asked: "option a").
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
local BACKPACK, BANK = const.BAG_KIND.BACKPACK, const.BAG_KIND.BANK

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
  backpackBehavior = trackStub("BackpackBehavior"),
  bankBehavior = trackStub("BankBehavior"),
  bankSlots = trackStub("BankSlots"),
  menuButton = trackStub("BagMenuButton"),
  sectionFrame = trackStub("SectionFrame"),
  categories = trackStub("Categories"),
  bagButton = trackStub("BagButton"),
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
  { "NextFrameArt", "next/frameart.lua" }, { "NextFill", "next/fill.lua" }, { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" },
  { "NextSparkles", "next/sparkles.lua" }, { "NextLift", "next/lift.lua" }, { "NextTabs", "next/tabs.lua" }, { "NextContent", "next/content.lua" },
  { "NextDockCard", "next/dockcard.lua" }, { "NextDock", "next/dock.lua" }, { "NextDrag", "next/drag.lua" }, { "NextChain", "next/chain.lua" }, { "NextOrnaments", "next/ornaments.lua" }, { "NextMenuButton", "next/menubutton.lua" }, { "NextGlitch", "next/glitch.lua" }, { "NextRain", "next/rain.lua" }, { "NextShatter", "next/shatter.lua" }, { "NextSnow", "next/snow.lua" }, { "NextThreads", "next/threads.lua" }, { "NextSmoke", "next/smoke.lua" }, { "NextBats", "next/bats.lua" }, { "NextBeam", "next/beam.lua" }, { "NextPanel", "next/panel.lua" },
  { "Currencies", "data/currencies.lua" }, { "NextCurrencyEntry", "next/currencyentry.lua" },
  { "NextCurrencyDrag", "next/currencydrag.lua" },
  { "NextCurrencyTracker", "next/currencytracker.lua" }, { "NextCurrencyStrip", "next/currencystrip.lua" }, { "NextBag", "next/bag.lua" }, { "NextBank", "next/bank.lua" } }
for _, m in ipairs(modules) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local nextBag = addon:GetModule("NextBag")
local nextBank = addon:GetModule("NextBank")
local chain = addon:GetModule("NextChain")
local style = addon:GetModule("NextStyle")
local tween = addon:GetModule("NextTween")
local render = addon:GetModule("Render")
local motion = addon:GetModule("Motion")
local context = addon:GetModule("Context")

local CHAR, ACCOUNT = 1, 2
local SECTION_GRID = 2
local SCREEN = 1920

describe("NextChain", function()
  local buttons, sent, db, backpackGroups, bankGroups, slots, layout, backpack, bank
  local eventHandlers = {}

  local function fakeButton(slotkey)
    local b = { slotkey = slotkey, frame = CreateFrame("Frame") }
    b.frame:SetSize(37, 37)
    function b:SetItemFromData(_, data) self.data = data end
    function b:SetFreeSlots(_, data) self.data = data end
    function b:SetSize(_, w, h) self.frame:SetSize(w, h) end
    function b:GetItemData() return self.data end
    function b:UpdateSearch() end
    function b:UpdateCooldown() return "unchanged" end
    function b:Release() end
    return b
  end

  local function item(slotkey, category)
    return { slotkey = slotkey, itemInfo = { category = category } }
  end

  local function tab(names, items)
    local categories = {}
    for _, n in ipairs(names) do table.insert(categories, { name = n }) end
    return { categories = categories, items = items }
  end

  local function ctx() return context:New("spec") end

  -- step runs the tweens and the panels' own frame drivers seconds along, in 1/60 s frames.
  local function step(seconds)
    local frames = math.max(1, math.floor(seconds * 60 + 0.5))
    for _ = 1, frames do
      local update = tween.driver and tween.driver:GetScript("OnUpdate")
      if update then update(tween.driver, 1 / 60) end
      for _, panel in ipairs({ backpack, bank }) do
        local driver = panel.cloud.driver
        local drive = driver:GetScript("OnUpdate")
        if panel.frame:IsShown() and drive then drive(driver, 1 / 60) end
      end
      local turn = chain.driver:GetScript("OnUpdate")
      if turn then turn(chain.driver, 1 / 60) end
    end
  end

  local function settle() step(3) end

  local function offset(panel)
    local _, _, _, x = panel.frame:GetPoint(1)
    return x
  end

  local function open(panel, onShown)
    panel:Show(ctx(), nil, onShown)
    panel:Draw(ctx(), slots[panel.kind], function() end)
  end

  local function close(panel)
    panel:Hide(ctx())
  end

  local function escape(panel)
    panel.frame:Hide()
    panel.frame:GetScript("OnHide")(panel.frame)
  end

  local function click(panel)
    panel.titleButton:GetScript("OnClick")(panel.titleButton, "LeftButton")
  end

  -- The gap between the two bodies: both tab rails hang into it (each up to its widest tab, plus
  -- the hover slide), with a margin between them, and never less than the two feathers.
  local function gap()
    local tabs = backpack.tabs:Width() + bank.tabs:Width() + 2 * style.TAB_HOVER + style.Chain.TabMargin
    return math.max(2 * style.FEATHER, tabs)
  end

  -- How far the chained bag sits from its own edge: the screen less both bodies and the gap.
  local function distance()
    return SCREEN - 2 * (style.WIDTH - style.FEATHER) - gap()
  end

  -- Whether any of a panel's frame is on the screen.
  local function onScreen(panel)
    local left = panel.side == "LEFT" and offset(panel) or (SCREEN + offset(panel) - style.WIDTH)
    return left + style.WIDTH > 0 and left < SCREEN
  end

  -- Where each body's inner edge is on screen.
  local function bankBodyEdge() return offset(bank) + style.WIDTH - style.FEATHER end
  local function backpackBodyEdge() return SCREEN + offset(backpack) - style.WIDTH + style.FEATHER end

  before_each(function()
    UseNextCurrencies(stubs.database, override)
    render:Init()
    tween:Init()
    motion:Init()
    chain:Init()
    eventHandlers = {}
    buttons, sent = {}, {}
    layout = "apart"
    db = { view = { [BACKPACK] = SECTION_GRID, [BANK] = SECTION_GRID }, active = { [BACKPACK] = 1, [BANK] = 10 } }
    backpackGroups = { [1] = { id = 1, name = "Backpack" } }
    bankGroups = {
      [10] = { id = 10, name = "Bank", bankType = CHAR, isDefault = true },
      [11] = { id = 11, name = "Warbank", bankType = ACCOUNT, isDefault = true },
    }
    slots = {
      [BACKPACK] = { sortedItems = {}, tabs = { [1] = tab({ "Armor" }, { item("0_1", "Armor") }) } },
      [BANK] = { sortedItems = {}, tabs = { [10] = tab({ "Cloth" }, { item("6_1", "Cloth") }),
        [11] = tab({ "Ore" }, { item("12_1", "Ore") }) } },
    }

    override(addon, "isRetail", true)
    override(addon, "isForever", false)
    override(addon, "hasWarbank", true)
    override(addon, "atBank", true)
    override(const, "BANK_TAB", { BANK = -2, ACCOUNT_BANK_1 = 12 })
    override(const, "BAG_VIEW", { SECTION_GRID = SECTION_GRID, SECTION_ALL_BAGS = 4 })
    override(const, "ACCOUNT_BANK_BAGS", { [12] = 12 })
    override(Enum.BagIndex, "Characterbanktab", -2)
    override(Enum.BagIndex, "CharacterBankTab_1", 6)
    override(Enum.BagIndex, "AccountBankTab_1", 12)
    UIParent:_SetRect(0, 0, SCREEN, 1200)

    override(stubs.L, "G", function(_, key) return key end)
    override(stubs.itemFrame, "GetButton", function(_, _, slotkey)
      buttons[slotkey] = buttons[slotkey] or fakeButton(slotkey)
      return buttons[slotkey]
    end)
    override(stubs.items, "GetAllSlotInfo", function() return slots end)
    override(stubs.items, "ExpireRecentItems", function() return false end)
    override(stubs.items, "ClearBankCache", function() end)
    override(stubs.database, "GetGroupsEnabled", function() return true end)
    override(stubs.database, "GetActiveGroup", function(_, kind) return db.active[kind] end)
    override(stubs.database, "SetActiveGroup", function(_, kind, id) db.active[kind] = id end)
    override(stubs.database, "GetInBagSearch", function() return true end)
    override(stubs.database, "GetShowBankTabs", function() return false end)
    override(stubs.database, "GetBagView", function(_, kind) return db.view[kind] end)
    override(stubs.database, "GetCustomSectionSort", function() return {} end)
    override(stubs.database, "GetNextChain", function() return layout end)
    -- No tab order saved (docs/next-batch-2.md §5).
    override(stubs.database, "GetNextTabOrder", function() return {} end)
    override(stubs.database, "GetNextSize", function() return "full" end)
    override(stubs.database, "SetNextChain", function(_, value) layout = value end)
    override(stubs.groups, "GetAllGroups", function(_, kind) return kind == BANK and bankGroups or backpackGroups end)
    override(stubs.groups, "GetGroup", function(_, kind, id) return (kind == BANK and bankGroups or backpackGroups)[id] end)
    override(stubs.groups, "IsDefaultGroup", function() return true end)
    override(stubs.groups, "GetDefaultBankGroup", function() return bankGroups[10] end)
    override(stubs.events, "SendMessage", function(_, _, name, opts) table.insert(sent, { name, opts }) end)
    override(stubs.events, "RegisterMessage", function() end)
    override(stubs.events, "RegisterEvent", function(_, name, fn) eventHandlers[name] = fn end)
    override(stubs.events, "BucketEvent", function() end)
    override(stubs.searchBox, "CreateBox", function(_, kind, parent)
      local box = { kind = kind, frame = CreateFrame("Frame", nil, parent) }
      -- As searchBox:CreateBox makes it (frames/search.lua): a BagSearchBoxTemplate edit box.
      box.textBox = CreateFrame("EditBox", nil, box.frame, "BagSearchBoxTemplate")
      box.helpText = box.textBox.Instructions
      return box
    end)
    override(stubs.sonata, "UnregisterElement", function() end)
    override(stubs.money, "Create", function()
      return { frame = CreateFrame("Frame"), Update = function() end }
    end)
    override(stubs.cursorPlacement, "PlaceCursorItem", function() return "placed" end)
    override(stubs.backpackBehavior, "Create", function() return {} end)
    override(stubs.bankBehavior, "SuppressBlizzardBankPanel", function() end)
    override(stubs.bankBehavior, "proto", { UpdatePurchaseBankButton = function() end })
    override(stubs.bankSlots, "GetBagSocketIndex", function() return nil end)
    override(C_Bank, "FetchPurchasedBankTabData", function(bankType)
      if bankType == CHAR then return { { ID = 6, name = "Base", icon = 1 } } end
      return { { ID = 12, name = "Shared", icon = 2 } }
    end)
    override(C_Bank, "FetchNextPurchasableBankTabData", function() return nil end)
    override(addon, "SetBlizzardBankType", function() end)
    override(addon, "TriggerItemContextChanged", function() end)
    override(addon, "ForceHideBlizzardBags", function() end)
    override(_G, "PlaySound", function() end)
    override(_G, "InCombatLockdown", function() return false end)
    UIErrorsFrame._messages = {}

    backpack = nextBag:Create(ctx())
    bank = nextBank:Create(ctx())
  end)

  after_each(function()
    restore()
  end)

  teardown(function()
    for i = #modules, 1, -1 do ResetModuleStub(modules[i][1]) end
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  describe("the layouts", function()
    it("knows both bags, the backpack and its companion", function()
      assert.are.equal("backpack", backpack.chainRole)
      assert.are.equal("companion", bank.chainRole)
    end)

    it("keeps the bags on opposite edges while apart", function()
      open(bank)
      open(backpack)
      settle()
      assert.are.equal(0, offset(bank))
      assert.are.equal(0, offset(backpack))
      assert.is_true(bank.docked and backpack.docked)
      assert.is_nil(chain.coupling)
    end)

    it("leaves room between the bodies for both tab rails, never less than the two feathers", function()
      local width = bank.tabs.Width
      bank.tabs.Width = function() return 10 end
      assert.are.equal(2 * style.FEATHER, chain:Gap(bank, backpack), "narrow tabs")
      bank.tabs.Width = width
      bankGroups[10].name = string.rep("W", 20)
      bank:RefreshTabs()
      local wide = bank.tabs:Width() + backpack.tabs:Width() + 2 * style.TAB_HOVER + style.Chain.TabMargin
      assert.is_true(wide > 2 * style.FEATHER)
      assert.are.equal(wide, chain:Gap(bank, backpack))
      assert.are.equal(chain:Gap(bank, backpack), chain:Gap(backpack, bank))
    end)
  end)

  describe("clicking a bag's name", function()
    before_each(function()
      open(bank)
      open(backpack)
      settle()
    end)

    -- "if we link from left to right, it flies right, and vice versa"
    it("flies the right bag left to the left bag, which becomes the anchor, and keeps the choice", function()
      click(backpack)
      assert.are.equal("left", layout)
      step(style.Time.Fly / 2)
      local mid = offset(backpack)
      assert.is_true(mid < 0 and mid > -distance(), "on its way left")
      settle()
      assert.are.equal(-distance(), offset(backpack))
      assert.are.equal(0, offset(bank), "the anchor stays")
      assert.are.equal(gap(), backpackBodyEdge() - bankBodyEdge())
    end)

    it("flies the left bag right to the right bag, which becomes the anchor", function()
      click(bank)
      assert.are.equal("right", layout)
      settle()
      assert.are.equal(distance(), offset(bank))
      assert.are.equal(0, offset(backpack))
      assert.are.equal(gap(), backpackBodyEdge() - bankBodyEdge())
    end)

    -- Asked: the flight "feels too slow and... linear almost": quick, slow off the mark and into
    -- place, fast in the middle (in-out cubic).
    it("flies quickly, slow off the mark and into place, fast in the middle", function()
      assert.is_true(style.Time.Fly <= 0.45, "quick: " .. style.Time.Fly)
      click(backpack)
      local progress = {}
      for _ = 1, 3 do
        step(style.Time.Fly * 0.25)
        table.insert(progress, -offset(backpack) / distance())
      end
      local cubic = tween.Ease.inOutCubic
      for i, share in ipairs({ 0.25, 0.5, 0.75 }) do
        assert.is_true(math.abs(progress[i] - cubic(share)) < 0.06, share .. ": " .. progress[i])
      end
      step(style.Time.Fly * 0.25 + 2 / 60)
      assert.are.equal(-distance(), offset(backpack), "there on time")
    end)

    -- "if a bag is chained, clicking on it's name puts it back"
    it("puts a chained bag back on its own edge", function()
      click(backpack)
      settle()
      click(backpack)
      assert.are.equal("apart", layout)
      settle()
      assert.are.equal(0, offset(backpack))
      click(bank)
      settle()
      click(bank)
      assert.are.equal("apart", layout)
      settle()
      assert.are.equal(0, offset(bank))
    end)

    -- "if a bag is chained, clicking on the anchor's name, moves both bags to the other side"
    it("moves both bags across together when the anchor's name is clicked, the other bag now at the edge", function()
      click(backpack)
      settle()
      click(bank)
      assert.are.equal("right", layout)
      local spans = {}
      for _ = 1, 20 do
        step(style.Time.Fly / 20)
        table.insert(spans, backpackBodyEdge() - bankBodyEdge())
      end
      for _, span in ipairs(spans) do
        assert.is_true(math.abs(span - gap()) < 1e-6, "together all the way: " .. span)
      end
      settle()
      assert.are.equal(distance(), offset(bank))
      assert.are.equal(0, offset(backpack))
      click(backpack)
      assert.are.equal("left", layout)
      settle()
      assert.are.equal(0, offset(bank))
      assert.are.equal(-distance(), offset(backpack))
    end)

    it("does nothing while its bag is alone, and says why", function()
      escape(bank)
      settle()
      assert.are.equal("alone", chain:Click(ctx(), backpack))
      assert.are.equal("apart", layout)
      assert.are.equal(0, offset(backpack))
    end)

    it("refuses when the screen is too narrow for both bags side by side", function()
      UIParent:_SetRect(0, 0, 2 * (style.WIDTH - style.FEATHER) + gap() - 1, 1200)
      assert.are.equal("no room", chain:Click(ctx(), backpack))
      assert.are.equal("apart", layout)
      assert.are.equal(1, #UIErrorsFrame._messages)
    end)

    it("keeps the chained bag beside its anchor when the gap changes (a tab renamed)", function()
      click(backpack)
      settle()
      bankGroups[10].name = string.rep("W", 20)
      bank:RefreshTabs()
      settle()
      assert.are.equal(-distance(), offset(backpack))
      assert.are.equal(gap(), backpackBodyEdge() - bankBodyEdge())
    end)

    -- UI_SCALE_CHANGED and DISPLAY_SIZE_CHANGED change the screen's width under the bags.
    it("places the bags at once for the new screen when its size or the UI scale changes", function()
      click(backpack)
      settle()
      for _, event in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
        assert.is_function(eventHandlers[event], event)
      end
      UIParent:_SetRect(0, 0, 2400, 1200)
      eventHandlers["UI_SCALE_CHANGED"](ctx())
      assert.are.equal(-(2400 - 2 * (style.WIDTH - style.FEATHER) - gap()), offset(backpack), "at once")
      assert.is_false(tween:IsPlaying(backpack))
    end)

    it("goes apart while the screen is too narrow, keeping the choice", function()
      click(backpack)
      settle()
      UIParent:_SetRect(0, 0, 1000, 1200)
      chain:Update(ctx())
      settle()
      assert.are.equal(0, offset(backpack))
      assert.are.equal("left", layout)
    end)
  end)

  describe("opening and closing", function()
    -- "option a": alone, the backpack sits at its own edge, and joins its companion when it opens.
    it("opens the backpack alone at its own edge even when chained left", function()
      layout = "left"
      open(backpack)
      settle()
      assert.are.equal(0, offset(backpack))
      assert.is_true(backpack.docked)
    end)

    it("flies the open backpack to its companion when the companion opens", function()
      layout = "left"
      open(backpack)
      settle()
      open(bank)
      settle()
      assert.are.equal(0, offset(bank))
      assert.are.equal(-distance(), offset(backpack))
      assert.is_false(backpack.docked)
    end)

    it("brings the backpack in beside its open companion from behind it", function()
      layout = "left"
      open(bank)
      settle()
      open(backpack)
      assert.is_true(offset(backpack) <= -SCREEN, "starts past the companion's edge: " .. offset(backpack))
      assert.is_true(backpack.frame:GetFrameLevel() < bank.frame:GetFrameLevel(), "beneath the companion")
      assert.are.equal(-distance(), backpack.target, "headed beside it")
      step(style.Time.Enter + 2 / 60)
      assert.are.equal(-distance(), offset(backpack), "in its place once the entrance ends")
    end)

    -- Asked: restoring a chain as the pair opens, "stagger them appearing from the border they are
    -- chained to? the window closest to the border first, then the chained one a few ms after, and
    -- have them fall in place". At a bank or vendor the companion opens first and the backpack a
    -- frame later (the interaction sends bags/OpenClose later).
    it("brings a chained pair in from the anchor's edge, the anchor first, the chained bag a moment after", function()
      layout = "left"
      open(bank)
      step(1 / 60)
      open(backpack)
      local held = offset(backpack)
      assert.is_true(held <= -SCREEN, "waiting beyond the anchor's edge: " .. held)
      assert.is_false(onScreen(backpack))
      assert.is_true(backpack.frame:GetFrameLevel() < bank.frame:GetFrameLevel(), "beneath the anchor")
      step(style.Chain.Stagger * 0.8)
      assert.are.equal(held, offset(backpack), "a moment after the anchor")
      assert.is_true(onScreen(bank), "the anchor is coming in")
      step(style.Chain.Stagger * 0.4)
      assert.is_true(offset(backpack) > held, "then it comes")
      settle()
      assert.are.equal(-distance(), offset(backpack))
      assert.are.equal(0, offset(bank))
      assert.are.equal(500, backpack.frame:GetFrameLevel(), "back at its own level once in place")
    end)

    -- As in game: what the backpack shows was drawn while it was hidden, and is drawn as it opens.
    it("cascades its sections in only as it starts coming in", function()
      layout = "left"
      open(bank)
      step(1 / 60)
      backpack:Draw(ctx(), slots[BACKPACK], function() end)
      backpack:Show(ctx())
      step(style.Chain.Stagger + style.Time.OpenCascadeDelay - 0.03)
      assert.are.equal(0, backpack.content.order[1].frame:GetAlpha(), "not yet")
      settle()
      assert.are.equal(1, backpack.content.order[1].frame:GetAlpha())
    end)

    it("does not hold a companion for a backpack that is already open", function()
      layout = "right"
      open(backpack)
      settle()
      assert.is_false(chain:WaitsForAnchor(bank))
      escape(backpack)
      assert.is_true(chain:WaitsForAnchor(bank))
    end)

    it("falls into place: fast out from behind the anchor, settling just past its place and back", function()
      layout = "left"
      open(bank)
      settle()
      open(backpack)
      local from, to = offset(backpack), -distance()
      local furthest, first = to, nil
      for _ = 1, math.ceil(style.Time.Enter * 60) + 2 do
        step(1 / 60)
        first = first or offset(backpack)
        furthest = math.max(furthest, offset(backpack))
      end
      assert.is_true((first - from) / (to - from) > 0.05, "quick off the mark")
      local past = furthest - to
      assert.is_true(past > 0, "it settles past its place")
      assert.is_true(past < 0.04 * (to - from), "only just: " .. past)
      assert.are.equal(to, offset(backpack))
    end)

    -- Chained right, the backpack is the anchor, but the bank or vendor opens first: it waits out
    -- of sight beyond the backpack's edge, and comes in after the backpack.
    it("holds a companion chained to the backpack out of sight until the backpack opens, then brings it in after", function()
      layout = "right"
      open(bank)
      assert.is_false(onScreen(bank), "out of sight")
      assert.is_true(offset(bank) >= SCREEN, "beyond the backpack's edge: " .. offset(bank))
      step(1 / 60)
      assert.is_false(onScreen(bank), "waiting")
      open(backpack)
      local held = offset(bank)
      step(style.Chain.Stagger * 0.8)
      assert.are.equal(held, offset(bank), "after the backpack")
      assert.is_true(onScreen(backpack), "the backpack is coming in")
      settle()
      assert.are.equal(distance(), offset(bank))
      assert.are.equal(0, offset(backpack))
      assert.is_not_nil(chain.coupling)
    end)

    it("says the waiting companion has finished showing only once it is in place", function()
      layout = "right"
      local shown = 0
      open(bank, function() shown = shown + 1 end)
      step(1 / 60)
      open(backpack)
      step(style.Chain.Stagger + style.Time.Enter * 0.5)
      assert.are.equal(0, shown, "still coming in")
      settle()
      assert.are.equal(1, shown)
    end)

    it("brings a waiting companion in from its own edge when the backpack does not open", function()
      layout = "right"
      local shown = 0
      open(bank, function() shown = shown + 1 end)
      step(style.Chain.AnchorWait * 0.9)
      assert.is_false(onScreen(bank), "still waiting")
      step(style.Chain.AnchorWait * 0.1 + 2 / 60)
      assert.is_true(offset(bank) <= 0 and onScreen(bank), "from its own edge: " .. offset(bank))
      settle()
      assert.are.equal(0, offset(bank))
      assert.is_true(bank.docked)
      assert.are.equal(1, shown)
    end)

    it("closes a waiting companion without crossing the screen", function()
      layout = "right"
      open(bank)
      step(1 / 60)
      close(bank)
      for _ = 1, 60 do
        step(1 / 60)
        assert.is_false(onScreen(bank), "never on the screen: " .. offset(bank))
      end
      assert.is_false(bank:IsShown())
    end)

    -- Held out of sight beyond the bank's edge while the bank leaves, then home from its own edge.
    it("sends a chained bag home from its own edge when its anchor closes before it came in", function()
      layout = "left"
      open(bank)
      step(1 / 60)
      open(backpack)
      close(bank)
      for _ = 1, 60 do
        step(1 / 60)
        assert.is_true(offset(backpack) >= -0.5 or not onScreen(backpack), "never crossing the screen: " .. offset(backpack))
      end
      assert.are.equal(0, offset(backpack))
      assert.is_true(backpack.docked)
    end)

    it("brings the bank in beside the backpack when chained right", function()
      layout = "right"
      open(backpack)
      settle()
      open(bank)
      assert.is_true(offset(bank) >= SCREEN, "starts past the backpack's edge: " .. offset(bank))
      settle()
      assert.are.equal(distance(), offset(bank))
      assert.are.equal(0, offset(backpack))
    end)

    it("flies the chained bag home when its anchor closes, or is hidden with Escape", function()
      layout = "left"
      open(bank)
      open(backpack)
      settle()
      close(bank)
      settle()
      assert.are.equal(0, offset(backpack))
      assert.is_true(backpack.docked)
      layout = "right"
      open(bank)
      settle()
      assert.are.equal(distance(), offset(bank))
      escape(backpack)
      settle()
      assert.are.equal(0, offset(bank))
    end)

    -- Asked: "when closing a vendor or bank, if the bag is chained, it should also exit in the
    -- direction of the anchor (right now it flies across the screen to it's original side when we
    -- leave the vendor/bank/whatever)". Leaving, the companion closes a frame before the backpack
    -- (addon.CloseInteractionWindow sends bags/OpenClose later).
    it("leaves through its anchor's edge, beneath the anchor, when it closes beside it", function()
      layout = "right"
      open(backpack)
      open(bank)
      settle()
      close(bank)
      assert.is_true(bank.frame:GetFrameLevel() < backpack.frame:GetFrameLevel(), "beneath the anchor")
      local last = offset(bank)
      for _ = 1, 40 do
        step(1 / 60)
        assert.is_true(offset(bank) >= last - 1e-6, "toward the anchor's edge: " .. offset(bank))
        last = offset(bank)
      end
      assert.is_false(bank:IsShown())
      assert.is_true(last >= SCREEN, "out beyond it")
      assert.are.equal(500, bank.frame:GetFrameLevel(), "back at its own level once hidden")
      close(backpack)
      settle()
      assert.are.equal(backpack:HiddenOffset(), offset(backpack), "the anchor through its own edge")
    end)

    it("holds a chained backpack while its anchor leaves, then lets it leave after it through the anchor's edge", function()
      layout = "left"
      open(bank)
      open(backpack)
      settle()
      close(bank)
      step(1 / 60)
      assert.are.equal(-distance(), offset(backpack), "held where it is")
      close(backpack)
      local last = offset(backpack)
      for _ = 1, 40 do
        step(1 / 60)
        assert.is_true(offset(backpack) <= last + 1e-6, "never toward its own edge: " .. offset(backpack))
        last = offset(backpack)
      end
      assert.is_false(backpack:IsShown())
      assert.is_true(last <= -SCREEN, "out beyond the anchor's edge")
    end)

    it("goes home once its anchor has gone when it stays open", function()
      layout = "left"
      open(bank)
      open(backpack)
      settle()
      close(bank)
      step(style.Time.Close * 0.6)
      assert.are.equal(-distance(), offset(backpack), "until the anchor has gone")
      settle()
      assert.are.equal(0, offset(backpack))
      assert.is_true(backpack.docked)
    end)

    -- leavesOwnEdge closes panel and checks it goes out through its own edge, never the other way.
    local function leavesOwnEdge(panel)
      close(panel)
      local out, last = -panel:Outward(), offset(panel)
      for _ = 1, 40 do
        step(1 / 60)
        assert.is_true((offset(panel) - last) * out >= -1e-6, "through its own edge: " .. offset(panel))
        last = offset(panel)
      end
      assert.are.equal(panel:HiddenOffset(), last)
    end

    it("lets a bag slide in at its own edge while the anchor of its chain is still leaving", function()
      layout = "left"
      open(bank)
      settle()
      close(bank)
      open(backpack)
      step(style.Time.Open + 2 / 60)
      assert.are.equal(0, offset(backpack), "slid all the way in, never held")
      assert.is_true(backpack.docked)
    end)

    it("closes through its own edge when a screen too narrow to chain keeps it there", function()
      UIParent:_SetRect(0, 0, 2 * (style.WIDTH - style.FEATHER) + gap() - 1, 1200)
      layout = "left"
      open(bank)
      open(backpack)
      settle()
      leavesOwnEdge(backpack)
    end)

    it("closes through its own edge on its way home after its anchor was hidden", function()
      layout = "left"
      open(bank)
      open(backpack)
      settle()
      escape(bank)
      step(style.Time.Fly * 0.3)
      leavesOwnEdge(backpack)
      layout = "right"
      open(backpack)
      open(bank)
      settle()
      escape(backpack)
      step(style.Time.Fly * 0.3)
      leavesOwnEdge(bank)
    end)

    it("closes the anchor of a pair moving across through its own edge", function()
      layout = "left"
      open(bank)
      open(backpack)
      settle()
      click(bank)
      assert.are.equal("right", layout, "the backpack is the anchor now")
      step(style.Time.Fly * 0.3)
      leavesOwnEdge(backpack)
    end)

    it("still leaves through its own edge when it is alone at it", function()
      layout = "left"
      open(backpack)
      settle()
      close(backpack)
      local last = offset(backpack)
      for _ = 1, 30 do
        step(1 / 60)
        assert.is_true(offset(backpack) >= last - 1e-6)
        last = offset(backpack)
      end
      assert.are.equal(backpack:HiddenOffset(), last)
    end)

    -- The bank loads once it has finished showing (refresh-scheduler.md §11): a flight that
    -- replaces a panel's opening slide still says when it is done.
    it("says a panel has finished showing when a flight took over its opening slide", function()
      layout = "left"
      local shown = 0
      open(backpack, function() shown = shown + 1 end)
      step(style.Time.Open / 3)
      open(bank)
      step(style.Time.Open)
      assert.are.equal(0, shown, "still flying")
      settle()
      assert.are.equal(1, shown)
    end)
  end)

  describe("the far edge of a chained bag", function()
    it("reaches past the screen edge at its edge, and feathers out toward the middle of the screen when not", function()
      local point, _, _, reach = backpack.fill:GetPoint(2)
      assert.are.equal("BOTTOMRIGHT", point)
      assert.are.equal(style.OVERREACH, reach)
      assert.is_false(backpack.outerFeather:IsShown())
      open(bank)
      open(backpack)
      settle()
      click(backpack)
      step(1 / 60)
      assert.is_false(backpack.docked, "detached as it leaves")
      local _, _, _, detached = backpack.fill:GetPoint(2)
      assert.are.equal(0, detached)
      local feather = backpack.outerFeather
      assert.is_true(feather:IsShown())
      assert.are.same({ "TOPLEFT", backpack.frame, "TOPRIGHT", 0, 0 }, { feather:GetPoint(1) })
      -- Asked: the far edge's feathering "is too heavy. tone it down a bit".
      assert.are.equal(style.Chain.OuterFeather, feather:GetWidth())
      assert.is_true(style.Chain.OuterFeather < style.FEATHER, "lighter than the inner feather")
      local g = feather._gradient
      assert.are.equal(style.Color.Body[4], g.min.a, "the body's color at its edge")
      assert.are.equal(0, g.max.a, "nothing at the far end")
      local _, _, _, wash = backpack.wash:GetPoint(2)
      assert.are.equal(0, wash, "the wash stops at the edge too")
      settle()
      click(backpack)
      settle()
      assert.is_true(backpack.docked)
      assert.is_false(feather:IsShown())
      assert.are.equal(style.OVERREACH, select(4, backpack.fill:GetPoint(2)))
    end)

    it("mirrors on the bank", function()
      open(bank)
      open(backpack)
      settle()
      click(bank)
      step(1 / 60)
      assert.are.same({ "TOPRIGHT", bank.frame, "TOPLEFT", 0, 0 }, { bank.outerFeather:GetPoint(1) })
      assert.are.equal(0, bank.outerFeather._gradient.min.a)
      assert.are.equal(0, select(4, bank.fill:GetPoint(1)))
    end)
  end)

  describe("coupling", function()
    before_each(function()
      open(bank)
      open(backpack)
      settle()
    end)

    local function half() return gap() / 2 end

    -- A strand's points, from the panel's body edge out to the middle of the gap, as (d, y): how
    -- far from the body edge and how far above the ribbon.
    local function points(panel, s)
      local _, joinX, _ = panel:TitleJoin()
      local out = panel:Outward()
      local pts = {}
      for i, line in ipairs(panel.braid.strands[s]) do
        local _, _, sx, sy = line:GetStartPoint()
        local _, _, ex, ey = line:GetEndPoint()
        if i == 1 then table.insert(pts, { (sx - joinX) * out, sy }) end
        table.insert(pts, { (ex - joinX) * out, ey })
      end
      return pts
    end

    it("twists the two ribbons together once the bag has flown in", function()
      click(backpack)
      step(style.Time.Fly * 0.5)
      assert.is_true((chain.coupling == nil) or chain.coupling.amount == 0, "not while flying")
      settle()
      assert.is_not_nil(chain.coupling)
      assert.are.equal(bank, chain.coupling.anchor)
      assert.are.equal(backpack, chain.coupling.chained)
      assert.are.equal(1, chain.coupling.amount)
      for _, panel in ipairs({ bank, backpack }) do
        assert.are.equal(1, panel.braid.amount)
        assert.are.equal(half(), panel.braid.half)
        assert.are.equal(half(), panel.ribbonLength, "its ribbon reaches the middle of the gap")
        assert.are.equal(half(), panel.ribbon:GetWidth())
        for _, strand in ipairs(panel.braid.strands) do
          assert.are.equal(style.Chain.Segments, #strand)
          for _, line in ipairs(strand) do
            assert.is_true(line:IsShown())
            assert.are.equal("ADD", line:GetBlendMode())
            assert.are.equal(style.Chain.Thickness, line:GetThickness())
          end
        end
      end
      assert.is_true(backpack.braid.knot:IsShown(), "the knot in the middle, drawn by the chained bag")
      assert.is_false(bank.braid.knot:IsShown())
    end)

    -- The client reads a frame's size back with float error at a UI scale (window.md §3b,
    -- layout-rendering.md §4). Reported: the tangle "only appears sometimes", never at the bank,
    -- and at a vendor only after clicking the vendor again (which lists its tabs again).
    it("couples when the client reads the tabs' widths back with float error", function()
      open(bank)
      open(backpack)
      settle()
      local reads = 0
      for _, panel in ipairs({ bank, backpack }) do
        for _, t in ipairs(panel.tabs.tabs) do
          local get = t.button.GetWidth
          t.button.GetWidth = function(b)
            reads = reads + 1
            return get(b) + (reads % 2 == 0 and 1e-4 or -1e-4)
          end
        end
      end
      click(backpack)
      settle()
      assert.is_not_nil(chain.coupling)
      assert.are.equal(1, chain.coupling.amount)
    end)

    it("couples a bag resting within half a pixel of its place", function()
      click(backpack)
      settle()
      escape(bank)
      settle()
      open(bank)
      backpack:PlaceAt(-distance() + 0.3)
      settle()
      assert.is_not_nil(chain.coupling)
      assert.are.equal(1, chain.coupling.amount)
    end)

    it("takes a place within half a pixel for its place: no flight, still coupled", function()
      click(backpack)
      settle()
      backpack:PlaceAt(-distance() + 0.3)
      chain:Update(ctx())
      assert.is_false(tween:IsPlaying(backpack), "no flight for under half a pixel")
      assert.are.equal(1, chain.coupling.amount)
      assert.are.equal(1, chain.coupling.target, "not letting go")
    end)

    -- One companion closes and another opens in the same moment (a bank closed by Escape as a
    -- vendor opens): the backpack stays where it is, and the new pair couples once the old one
    -- has let go.
    it("couples a new pair once the coupling of the pair before has let go", function()
      -- Letting go outlasting the new anchor's slide: nothing else is left to couple them after.
      override(style.Time, "Uncouple", style.Time.Open * 2)
      local other = nextBank:Create(ctx())
      click(backpack)
      settle()
      escape(bank)
      open(other)
      settle()
      assert.is_not_nil(chain.coupling)
      assert.are.equal(other, chain.coupling.anchor)
      assert.are.equal(1, chain.coupling.amount)
    end)

    it("braids from each body edge to the middle of the gap, the halves meeting, the strands crossing", function()
      click(backpack)
      settle()
      local a1, a2 = points(bank, 1), points(bank, 2)
      local b1, b2 = points(backpack, 1), points(backpack, 2)
      -- One curve across the gap: the right half goes on from the knot, it does not mirror the left.
      local mirrored = true
      for i = 1, #a1 do
        if math.abs(a1[i][2] - b1[i][2]) > 1e-6 then mirrored = false end
      end
      assert.is_false(mirrored, "the curve runs on through the knot")
      assert.are.equal(0, a1[1][1])
      assert.are.equal(0, a1[1][2], "from the ribbon at the body edge")
      assert.is_true(math.abs(a1[#a1][1] - half()) < 1e-6, "to the middle")
      assert.is_true(math.abs(b1[#b1][1] - half()) < 1e-6)
      assert.is_true(math.abs(a1[#a1][2] - b1[#b1][2]) < 1e-6, "the halves meet")
      assert.is_true(math.abs(a2[#a2][2] - b2[#b2][2]) < 1e-6)
      local crossed, apart = false, 0
      for i = 1, #a1 do
        assert.is_true(math.abs(a1[i][2] + a2[i][2]) < 1e-6, "one strand mirrors the other")
        apart = math.max(apart, math.abs(a1[i][2]))
        if i > 1 and (a1[i][2] > 0) ~= (a1[i - 1][2] > 0) then crossed = true end
      end
      assert.is_true(apart > style.Chain.Amplitude * 0.5, "they wind apart")
      assert.is_true(crossed, "and cross")
    end)

    it("turns the braid slowly and runs lights along it to the knot", function()
      click(backpack)
      settle()
      local before = points(backpack, 1)[3][2]
      local bead = backpack.braid.beads[1]
      local _, _, _, bx1 = bead:GetPoint(1)
      step(0.25)
      assert.are_not.equal(before, points(backpack, 1)[3][2], "it turns")
      local _, _, _, bx2 = bead:GetPoint(1)
      assert.are_not.equal(bx1, bx2, "the lights move")
      assert.is_true(bead:GetAlpha() >= 0)
    end)

    it("stays coupled while the pair moves across together", function()
      click(backpack)
      settle()
      click(bank)
      for _ = 1, 10 do
        step(style.Time.Fly / 10)
        assert.are.equal(1, chain.coupling.amount)
      end
      settle()
      assert.are.equal(bank, chain.coupling.chained, "the bank is the chained bag now")
      assert.are.equal(backpack, chain.coupling.anchor)
    end)

    it("untwists and lets go as the chained bag flies home, its ribbon back to full length", function()
      click(backpack)
      settle()
      click(backpack)
      step(style.Time.Uncouple / 2)
      assert.is_true(backpack.braid.amount < 1 and backpack.braid.amount > 0, "untwisting")
      assert.is_true(backpack.braid.half > half(), "stretching")
      settle()
      assert.is_nil(chain.coupling)
      for _, panel in ipairs({ bank, backpack }) do
        assert.are.equal(0, panel.braid.amount)
        assert.are.equal(style.RIBBON_LENGTH, panel.ribbonLength)
        for _, strand in ipairs(panel.braid.strands) do
          for _, line in ipairs(strand) do
            assert.is_false(line:IsShown())
          end
        end
      end
      assert.is_false(backpack.braid.knot:IsShown())
    end)

    it("lets go when either bag closes", function()
      click(backpack)
      settle()
      close(bank)
      settle()
      assert.is_nil(chain.coupling)
      assert.are.equal(0, backpack.braid.amount)
    end)

    it("bursts with sparkles at the knot as they couple", function()
      click(backpack)
      local burst = backpack.knotSparkles
      step(style.Time.Fly + 2 / 60)
      assert.are.equal(0, #burst.alive, "not before")
      step(style.Time.Couple + 0.1)
      assert.is_true(#burst.alive > 0, "as they couple")
    end)

    -- Asked: "the small sparkles along the bags stop when they are coupled, let's not do that".
    -- They keep drifting off both inner edges into the gap, dying before the other bag; ribbon
    -- sparkles die before the middle of the gap.
    it("keeps both bags' edge sparkles going along their inner edges while coupled", function()
      click(backpack)
      settle()
      for _, panel in ipairs({ bank, backpack }) do
        local o = panel.edgeSparkles.options
        assert.is_true(o.Rate > 0, panel:GetName())
        assert.is_not_nil(panel.edgeSparkles.frame:GetScript("OnUpdate"), "running")
        assert.are.equal(panel:Outward(), o.Direction, "into the gap")
        local inner = panel.side == "LEFT" and style.BODY_WIDTH or style.FEATHER
        for _ = 1, 20 do
          local x = o.Spawn()
          assert.is_true(math.abs(x - inner) <= 24, "born on its inner edge: " .. x)
        end
        assert.is_true(o.Speed[2] * o.Life[2] + 24 < gap(), "dies before the other bag")
        local r = panel.sparkles.options
        assert.is_true(r.Speed[2] * r.Life[2] <= half(), "ribbon sparkles die before the middle")
      end
    end)

    -- Asked: "let's grow the feathering between two coupled bags a bit when things are coupled, so
    -- they appear a bit more closely together (still a gap, just not as drastic)".
    it("grows both inner feathers into the gap while coupled, still leaving a gap, and back as they part", function()
      click(backpack)
      settle()
      local grown = math.max(style.FEATHER, style.Chain.CoupledFeather * gap())
      assert.is_true(grown > gap() / 2, "they overlap in the middle")
      assert.is_true(grown < gap(), "neither reaches the other bag")
      -- In whole pixels (docs/next-pixel-perfect.md): the growth rounded.
      local growth = math.floor(grown - style.FEATHER + 0.5)
      for _, panel in ipairs({ bank, backpack }) do
        assert.are.equal(style.FEATHER + growth, panel.feather:GetWidth(), panel:GetName() .. " grown")
      end
      -- Each still starts at its body edge: the grown part reaches past its frame into the gap.
      assert.are.equal(growth, select(4, bank.feather:GetPoint(1)))
      assert.are.equal(-growth, select(4, backpack.feather:GetPoint(1)))
      click(backpack)
      step(style.Time.Uncouple / 2)
      local partway = bank.feather:GetWidth()
      assert.is_true(partway > style.FEATHER and partway < grown, "shrinking as they part: " .. partway)
      settle()
      for _, panel in ipairs({ bank, backpack }) do
        assert.are.equal(style.FEATHER, panel.feather:GetWidth())
        assert.are.equal(0, select(4, panel.feather:GetPoint(1)))
      end
    end)

    -- Grown, a bag's feather reaches into the other bag's half of the gap: the braid is drawn on a
    -- layer above both bags, so neither feather covers it.
    it("draws the braid above both bags' feathers", function()
      click(backpack)
      settle()
      for _, panel in ipairs({ bank, backpack }) do
        local layer = panel.braid.layer
        assert.are.equal(layer, panel.braid.strands[1][1]:GetParent())
        assert.are.equal(layer, panel.braid.beads[1]:GetParent())
        assert.are.equal(layer, panel.braid.knot:GetParent())
        assert.is_true(layer:GetFrameLevel() > bank.frame:GetFrameLevel())
        assert.is_true(layer:GetFrameLevel() > backpack.frame:GetFrameLevel())
      end
    end)
  end)

  describe("the title", function()
    it("takes clicks over the title and says what a click does", function()
      -- Over the title, 8 past it across and 6 above and below, hung from the body (never from the title, whose
      -- anchoring is secret while it shows a secret: next-themes.md).
      local b = backpack.titleButton
      local inset = backpack:InnerPad() + style.TITLE_INSET
      assert.are.same({ "TOPLEFT", backpack.body, "TOPLEFT", inset - 8, -(style.TITLE_TOP - 6) }, { b:GetPoint(1) })
      assert.are.equal(math.ceil(backpack.title:GetStringWidth()) + 16, b:GetWidth())
      local function tip(panel)
        panel.titleButton:GetScript("OnEnter")(panel.titleButton)
        return GameTooltip.lines[1] and GameTooltip.lines[1].text
      end
      assert.are.equal("Open the bank or a vendor to chain your backpack to it.", tip(backpack))
      open(bank)
      open(backpack)
      settle()
      assert.are.equal("Click to chain to the Bank.", tip(backpack))
      assert.are.equal("Click to chain to the Backpack.", tip(bank))
      click(backpack)
      settle()
      assert.are.equal("Click to put it back.", tip(backpack))
      assert.are.equal("Click to move both bags to the other side.", tip(bank))
      backpack.titleButton:GetScript("OnLeave")(backpack.titleButton)
    end)

    -- A vendor's title is the vendor's name, secret in an instance (UnitName is
    -- SecretWhenUnitNameIdentityRestricted), and GameTooltip's methods are not marked up to take
    -- secrets: tooltips name a bag by its label, never by its title.
    it("names bags by their labels in tooltips, never by a title that can be secret", function()
      override(_G, "issecretvalue", IsMockSecret)
      open(bank)
      open(backpack)
      settle()
      bank.title:SetText(MockSecret("A Secret Name"))
      local function tip(panel)
        panel.titleButton:GetScript("OnEnter")(panel.titleButton)
        return GameTooltip._header, GameTooltip.lines[1] and GameTooltip.lines[1].text
      end
      local header, line = tip(backpack)
      assert.are.equal("Backpack", header)
      assert.are.equal("Click to chain to the Bank.", line)
      header = tip(bank)
      assert.are.equal("Bank", header)
      backpack.titleButton:GetScript("OnLeave")(backpack.titleButton)
    end)

    it("lights up while the pointer is over it", function()
      local b, glow = backpack.titleButton, backpack.titleGlow
      assert.are.equal(0, glow:GetAlpha())
      b:GetScript("OnEnter")(b)
      step(style.Time.Hover * 2)
      assert.is_true(glow:GetAlpha() > 0)
      b:GetScript("OnLeave")(b)
      step(style.Time.Hover * 2)
      assert.are.equal(0, glow:GetAlpha())
    end)
  end)
end)
