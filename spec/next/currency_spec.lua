-- currency_spec.lua -- BetterBags Next's currencies (currency.md): the strip at the bottom of the backpack
-- (next/currencystrip.lua), its entries (next/currencyentry.lua) and the tracker dragged out of it
-- (next/currencytracker.lua), on a real backpack panel, on a real screen (spec/helpers/layout.lua).
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
local BACKPACK = const.BAG_KIND.BACKPACK

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
  sectionFrame = trackStub("SectionFrame"),
  categories = trackStub("Categories"),
  bagSystem = trackStub("BagSystem"),
  bagButton = trackStub("BagButton"),
  settings = trackStub("NextSettings"),
  menu = trackStub("NextMenu"),
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
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextFrameArt", "next/frameart.lua" }, { "NextFill", "next/fill.lua" }, { "NextControls", "next/controls/base.lua" },
  { "NextScrollBar", "next/controls/scrollbar.lua" }, { "NextSparkles", "next/sparkles.lua" }, { "NextLift", "next/lift.lua" },
  { "NextTabs", "next/tabs.lua" }, { "NextContent", "next/content.lua" }, { "NextDockCard", "next/dockcard.lua" },
  { "NextDock", "next/dock.lua" }, { "NextDrag", "next/drag.lua" }, { "NextChain", "next/chain.lua" },
  { "NextOrnaments", "next/ornaments.lua" }, { "NextMenuButton", "next/menubutton.lua" }, { "NextGlitch", "next/glitch.lua" }, { "NextRain", "next/rain.lua" }, { "NextShatter", "next/shatter.lua" }, { "NextSnow", "next/snow.lua" }, { "NextThreads", "next/threads.lua" }, { "NextSmoke", "next/smoke.lua" }, { "NextBats", "next/bats.lua" }, { "NextPanel", "next/panel.lua" },
  { "Currencies", "data/currencies.lua" }, { "NextCurrencyEntry", "next/currencyentry.lua" },
  { "NextCurrencyDrag", "next/currencydrag.lua" },
  { "NextCurrencyTracker", "next/currencytracker.lua" }, { "NextCurrencyStrip", "next/currencystrip.lua" },
  { "NextBag", "next/bag.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local layout = dofile("spec/helpers/layout.lua")
local nextBag = addon:GetModule("NextBag")
local style = addon:GetModule("NextStyle")
local tween = addon:GetModule("NextTween")
local render = addon:GetModule("Render")
local motion = addon:GetModule("Motion")
local context = addon:GetModule("Context")
local lift = addon:GetModule("NextLift")
local currencies = addon:GetModule("Currencies")
local tracker = addon:GetModule("NextCurrencyTracker")
local entryModule = addon:GetModule("NextCurrencyEntry")
local currencyDrag = addon:GetModule("NextCurrencyDrag")
local pixel = addon:GetModule("NextPixel")

describe("BetterBags Next's currencies", function()
  local messages, events, sent, slotInfo, opened, picked, placed, timers, unscreen, cleared

  local function ctx() return context:New("spec") end

  -- fire sends a message (or an event) to every handler registered for it.
  local function fire(name, ...)
    for _, fn in ipairs(messages[name] or {}) do fn(ctx(), ...) end
    for _, fn in ipairs(events[name] or {}) do fn(ctx(), name, ...) end
  end

  local function finishTweens()
    for _ = 1, 600 do
      local update = tween.driver and tween.driver:GetScript("OnUpdate")
      local moving = motion.driver and motion.driver:GetScript("OnUpdate")
      if update == nil and moving == nil then return end
      if update then update(tween.driver, 0.05) end
      if moving then moving(motion.driver, 0.05) end
    end
  end

  local function step(seconds)
    local update = tween.driver and tween.driver:GetScript("OnUpdate")
    if update then update(tween.driver, seconds) end
  end

  -- A currency as GetCurrencyInfo returns it (CurrencyInfoDocumentation.lua).
  local function currency(id, fields)
    local info = { name = "Currency " .. id, currencyID = id, quantity = 0, iconFileID = 1000 + id, maxQuantity = 0,
      canEarnPerWeek = false, quantityEarnedThisWeek = 0, maxWeeklyQuantity = 0, totalEarned = 0, discovered = true,
      useTotalEarnedForMaxQty = false, isAccountWide = false, isAccountTransferable = false, quality = 1 }
    for k, v in pairs(fields or {}) do info[k] = v end
    _G._currencies[id] = info
    return info
  end

  local function backpack()
    local bag = nextBag:Create(ctx())
    bag:Draw(ctx(), slotInfo, function() end)
    bag:Show(ctx())
    -- The client runs a frame's OnShow as it shows; the mock does not.
    bag.frame:GetScript("OnShow")(bag.frame)
    finishTweens()
    -- The bags were read once: counts from here on are gains (currency.md §2).
    fire("items/RefreshBackpack/Done")
    return bag
  end

  local function strip(bag) return bag.currencyStrip end

  local function shownKeys(s)
    local out = {}
    for _, key in ipairs(s.order) do table.insert(out, key) end
    return out
  end

  -- lit returns what an entry draws besides its icon and its cap bar: textures shown and not faded out (their alpha
  -- with their parents', as the client draws them). Nothing but those may show behind an entry (asked: no light
  -- behind them, before or after the pointer passes).
  local function lit(e)
    local out = {}
    for _, r in ipairs({ e.frame:GetRegions() }) do
      if r:IsObjectType("Texture") and r:IsShown() and r:GetAlpha() > 0 and r ~= e.icon and r ~= e.track
        and r ~= e.fill then
        table.insert(out, r)
      end
    end
    return out
  end

  -- hover runs the pointer over an entry and away, its fades to their end.
  local function hover(e)
    e.frame:GetScript("OnEnter")(e.frame)
    finishTweens()
    assert.are.same({}, lit(e), "nothing lit behind it under the pointer")
    e.frame:GetScript("OnLeave")(e.frame)
    finishTweens()
  end

  -- x of an entry from the strip's left (Motion places each by its top left).
  local function xOf(e)
    local _, _, _, x = e.frame:GetPoint(1)
    return x
  end

  before_each(function()
    UseNextCurrencies(stubs.database, override)
    unscreen = layout.UseScreen(1920, 1080, 1)
    render:Init()
    tween:Init()
    motion:Init()
    ResetMockCurrencies()
    messages, events, sent, opened, picked, placed, timers, cleared = {}, {}, {}, {}, {}, {}, {}, 0
    slotInfo = { sortedItems = {}, tabs = { [1] = { categories = {}, items = {} } } }
    tracker.instance = nil
    -- The entries' tooltips follow the Warband's amounts once a session (each test has its own messages).
    entryModule.watching = nil
    -- Each test makes its own backpack and tracker, which register with the entry drag as they are made.
    currencyDrag.held, currencyDrag.containers = nil, {}
    override(stubs.L, "G", function(_, key) return key end)
    override(stubs.items, "GetAllSlotInfo", function() return { [BACKPACK] = slotInfo } end)
    override(stubs.items, "ExpireRecentItems", function() return false end)
    for name, value in pairs({ GetGroupsEnabled = false, GetActiveGroup = 1, GetNextChain = "apart",
      GetNextSize = "full", GetInBagSearch = true, GetBagView = 2 }) do
      override(stubs.database, name, function() return value end)
    end
    override(stubs.database, "GetNextTabOrder", function() return {} end)
    override(stubs.groups, "GetAllGroups", function() return {} end)
    override(const, "BAG_VIEW", { SECTION_GRID = 2, SECTION_ALL_BAGS = 4 })
    override(stubs.events, "SendMessage", function(_, ectx, name, ...)
      table.insert(sent, { name = name, args = { ... } })
      for _, fn in ipairs(messages[name] or {}) do fn(ectx, ...) end
    end)
    override(stubs.events, "RegisterMessage", function(_, name, fn)
      messages[name] = messages[name] or {}
      table.insert(messages[name], fn)
    end)
    override(stubs.events, "RegisterEvent", function(_, name, fn)
      events[name] = events[name] or {}
      table.insert(events[name], fn)
    end)
    override(stubs.events, "BucketEvent", function() end)
    override(stubs.searchBox, "CreateBox", function(_, kind, parent)
      local box = { kind = kind, frame = CreateFrame("Frame", nil, parent) }
      box.textBox = CreateFrame("EditBox", nil, box.frame, "BagSearchBoxTemplate")
      box.textBox:SetAllPoints()
      box.helpText = box.textBox.Instructions
      return box
    end)
    override(stubs.sonata, "UnregisterElement", function() end)
    override(stubs.money, "Create", function()
      local f = CreateFrame("Frame")
      f:SetSize(120, 14)
      return { frame = f, Update = function() end }
    end)
    override(stubs.cursorPlacement, "PlaceCursorItem", function(_, kind) table.insert(placed, kind) return "placed" end)
    override(stubs.backpackBehavior, "Create", function() return {} end)
    override(stubs.settings, "Open", function(_, page, tab) table.insert(opened, page .. " > " .. tostring(tab)) end)
    override(stubs.menu, "Toggle", function(_, anchor, opts) picked = { anchor = anchor, opts = opts } end)
    override(_G, "PlaySound", function() end)
    override(_G, "InCombatLockdown", function() return false end)
    override(_G, "ClearCursor", function()
      cleared = cleared + 1
      _G._cursorType, _G._cursorItemID, _G._cursorHasItem = nil, nil, false
    end)
    override(C_Timer, "After", function(_, fn) table.insert(timers, fn) end)
    override(addon, "TriggerItemContextChanged", function() end)
    override(addon, "ForceHideBlizzardBags", function() end)
    override(C_Item, "GetItemNameByID", function(id) return id == 5 and "Mycobloom" or nil end)
    override(C_Item, "GetItemInfoInstant", function(id) return id, "Tradeskill", "Herb", "", 2000 + id end)
    _G._cursorX, _G._cursorY = 600, 400
    _G._mouseButtonsDown = { LeftButton = true }
    currencies:OnEnable()
  end)

  after_each(function()
    restore()
    unscreen()
    if tracker.instance then
      tracker.instance.frame:Hide()
      lift.held = nil
    end
    tracker.instance = nil
    _G._cursorType, _G._cursorItemID, _G._cursorHasItem = nil, nil, false
    _G._mouseButtonsDown = nil
  end)

  teardown(function()
    for _, m in ipairs({ "NextBag", "NextPanel", "NextDrag", "NextContent", "NextTabs", "NextSparkles", "NextTween",
      "NextStyle", "NextCurrencyStrip", "NextCurrencyTracker", "NextCurrencyEntry", "Currencies" }) do
      ResetModuleStub(m)
    end
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  describe("the strip", function()
    it("takes the free slots' place: no free slots text, the strip at the bottom of the inner side", function()
      local bag = backpack()
      assert.is_false(bag.freeText:IsShown())
      local s = strip(bag)
      local point, rel, relPoint, x = s.frame:GetPoint(1)
      assert.are.equal("BOTTOMLEFT", point)
      assert.are.equal(bag.body, rel)
      assert.are.equal("BOTTOMLEFT", relPoint)
      assert.are.equal(pixel:Snap(s.frame, bag:InnerPad() + style.TITLE_INSET), x)
    end)

    it("says Track Currencies while nothing is tracked, and opens where currencies are picked when clicked", function()
      override(addon, "isRetail", true)
      local s = strip(backpack())
      assert.is_true(s.hint:IsShown())
      assert.are.equal("Track Currencies", s.hintText:GetText())
      s.hint:GetScript("OnClick")(s.hint, "LeftButton")
      assert.are.same({ "currencies > currencies" }, opened)
      -- A client without currencies (TBC, Era): items are tracked, on their own tab.
      override(addon, "isRetail", false)
      override(addon, "isMists", false)
      s.hint:GetScript("OnClick")(s.hint, "LeftButton")
      assert.are.same({ "currencies > currencies", "currencies > items" }, opened)
    end)

    it("shows what is tracked in its order: each its icon and count, left to right", function()
      currency(1, { quantity = 1350, iconFileID = 77 })
      _G._itemCounts[5] = { bags = 40 }
      currencies:Track(ctx(), "currency", 1)
      currencies:Track(ctx(), "item", 5)
      local s = strip(backpack())
      assert.are.same({ "currency:1", "item:5" }, shownKeys(s))
      local c, i = s.entries["currency:1"], s.entries["item:5"]
      assert.are.equal("1,350", c.count:GetText())
      assert.are.equal("40", i.count:GetText())
      assert.are.equal(77, c.icon:GetTexture())
      assert.are.equal(2005, i.icon:GetTexture())
      assert.are.equal(0, xOf(c))
      assert.is_true(xOf(i) >= c.width + pixel:Length(s.frame, style.Theme.Currency.Gap))
      assert.is_false(s.hint:IsShown())
    end)

    -- Reported: a light behind each entry once tracked, gone only after the pointer passed over it.
    it("draws nothing behind its entries, as they are tracked and after the pointer passes over them", function()
      currency(1, { quantity = 5 })
      local s = strip(backpack())
      currencies:Track(ctx(), "currency", 1)
      currency(2, { quantity = 6216 })
      currencies:Track(ctx(), "currency", 2)
      finishTweens()
      for _, key in ipairs({ "currency:1", "currency:2" }) do
        local e = s.entries[key]
        assert.are.same({}, lit(e), key .. " as it is tracked")
        hover(e)
        assert.are.same({}, lit(e), key .. " after the pointer passed")
      end
    end)

    it("draws a cap bar for a currency with a cap, its fill its progress, and none for one without", function()
      currency(1, { quantity = 300, maxQuantity = 1200 })
      currency(2, { quantity = 5 })
      currencies:Track(ctx(), "currency", 1)
      currencies:Track(ctx(), "currency", 2)
      stubs.database:SetNextCurrencyOption("capBars", true)
      local s = strip(backpack())
      local capped, plain = s.entries["currency:1"], s.entries["currency:2"]
      assert.is_true(capped.track:IsShown())
      assert.is_true(capped.fill:IsShown())
      assert.are.equal(pixel:Length(capped.frame, capped.width * 0.25), capped.fill:GetWidth())
      assert.is_false(plain.track:IsShown())
    end)

    -- Asked: cap bars off by default.
    it("draws no bars until told, and every entry no taller than its icon then", function()
      currency(1, { quantity = 300, maxQuantity = 1200 })
      currencies:Track(ctx(), "currency", 1)
      local s = strip(backpack())
      local e = s.entries["currency:1"]
      assert.is_false(e.track:IsShown())
      assert.is_false(e.fill:IsShown())
      assert.are.equal(pixel:Length(e.frame, style.Theme.Currency.Icon), e.height)
    end)

    it("writes a count at a cap in the capped role, and one you have none of faded", function()
      currency(1, { quantity = 1200, maxQuantity = 1200 })
      currency(2, { quantity = 0 })
      currencies:Track(ctx(), "currency", 1)
      currencies:Track(ctx(), "currency", 2)
      stubs.database:SetNextCurrencyOption("hideEmpty", false)
      local s = strip(backpack())
      assert.are.equal(style:Font("CurrencyCapped"), s.entries["currency:1"].count:GetFontObject())
      local none = s.entries["currency:2"]
      assert.are.equal(style:Font("CurrencyNone"), none.count:GetFontObject())
      assert.is_true(none.icon:IsDesaturated())
    end)

    it("puts what you have none of behind +N, and what does not fit", function()
      for id = 1, 12 do
        currency(id, { quantity = 100000 + id })
        currencies:Track(ctx(), "currency", id)
      end
      currency(13, { quantity = 0 })
      currencies:Track(ctx(), "currency", 13)
      local bag = backpack()
      local s = strip(bag)
      assert.is_true(#s.order < 12, "not every one fits beside the gold")
      assert.is_true(s.more:IsShown())
      assert.are.equal("+" .. #s.hidden, s.moreText:GetText())
      assert.are.equal(13 - #s.order, #s.hidden)
      -- Nothing runs past the gold.
      local last = s.entries[s.order[#s.order]]
      local right = xOf(last) + last.width
      local room = bag:LayoutWidth() - (bag:InnerPad() + style.TITLE_INSET) - style.PAD - 120
        - style.Theme.Currency.MoneyGap
      assert.is_true(right <= room)
    end)

    it("lists what is behind +N in a menu, and brings what is picked to the front", function()
      for id = 1, 12 do
        currency(id, { quantity = 100000 + id })
        currencies:Track(ctx(), "currency", id)
      end
      local s = strip(backpack())
      s.more:GetScript("OnClick")(s.more, "LeftButton")
      assert.are.equal(s.more, picked.anchor)
      assert.are.equal(#s.hidden, #picked.opts.items)
      local last = picked.opts.items[#picked.opts.items]
      assert.is_truthy(last.text:find("Currency 12", 1, true))
      picked.opts.onPick(ctx(), last)
      assert.are.equal(12, currencies:Tracked()[1].id)
      assert.are.equal("currency:12", s.order[1])
    end)

    it("shows what you have none of when told", function()
      currency(1, { quantity = 0 })
      currencies:Track(ctx(), "currency", 1)
      stubs.database:SetNextCurrencyOption("hideEmpty", false)
      local s = strip(backpack())
      assert.are.same({ "currency:1" }, shownKeys(s))
      assert.is_false(s.more:IsShown())
    end)

    it("waits for the backpack to open before it draws", function()
      currency(1, { quantity = 1 })
      local bag = nextBag:Create(ctx())
      currencies:Track(ctx(), "currency", 1)
      assert.is_true(strip(bag).dirty)
      assert.is_nil(strip(bag).entries["currency:1"])
      bag:Draw(ctx(), slotInfo, function() end)
      bag:Show(ctx())
      bag.frame:GetScript("OnShow")(bag.frame)
      assert.are.same({ "currency:1" }, shownKeys(strip(bag)))
    end)

    it("is laid out again when the gold's width changes", function()
      for id = 1, 12 do
        currency(id, { quantity = 100000 + id })
        currencies:Track(ctx(), "currency", id)
      end
      local bag = backpack()
      local s = strip(bag)
      local before = #s.order
      bag.moneyFrame.frame:SetWidth(10)
      fire("PLAYER_MONEY")
      for _, fn in ipairs(timers) do fn() end
      assert.is_true(#s.order > before)
    end)

    it("opens the Currencies page on a right click", function()
      currency(1, { quantity = 1 })
      currencies:Track(ctx(), "currency", 1)
      local s = strip(backpack())
      local e = s.entries["currency:1"]
      e.frame:GetScript("OnClick")(e.frame, "RightButton")
      s.frame:GetScript("OnMouseUp")(s.frame, "RightButton")
      assert.are.same({ "currencies > tracked", "currencies > tracked" }, opened, "what is tracked")
    end)

    it("searches the backpack for an item on a Shift-click, and clears it on another", function()
      _G._itemCounts[5] = { bags = 3 }
      currencies:Track(ctx(), "item", 5)
      local bag = backpack()
      local e = strip(bag).entries["item:5"]
      override(_G, "IsShiftKeyDown", function() return true end)
      e.frame:GetScript("OnClick")(e.frame, "LeftButton")
      assert.are.equal('name == "Mycobloom"', bag.searchBox.textBox:GetText())
      e.frame:GetScript("OnClick")(e.frame, "LeftButton")
      assert.are.equal("", bag.searchBox.textBox:GetText())
    end)
  end)

  describe("gains", function()
    local function gained(bag, id, quantity)
      _G._currencies[id].quantity = quantity
      fire("CURRENCY_DISPLAY_UPDATE", id)
      return strip(bag).entries["currency:" .. id]
    end

    it("rolls the count to its new number, pops the icon, glows round it and lifts +N over the bag", function()
      currency(1, { quantity = 100 })
      currencies:Track(ctx(), "currency", 1)
      local bag = backpack()
      local e = gained(bag, 1, 125)
      assert.is_true(e:IsPlaying())
      assert.are.equal("100", e.count:GetText(), "from what it was")
      local float = e.float
      assert.is_truthy(float)
      assert.are.equal("+25", float.text:GetText())
      assert.are.equal(bag.overlay, float.text:GetParent(), "over the content")
      assert.are.equal(style:Font("CurrencyGain"), float.text:GetFontObject())
      assert.is_true(e.flash:GetAlpha() > 0)
      step(style.Time.CurrencyBump / 2)
      assert.is_true(e.icon:GetWidth() > e.iconSize, "the icon pops")
      finishTweens()
      assert.are.equal("125", e.count:GetText())
      assert.are.equal(e.iconSize, e.icon:GetWidth(), "and settles at its size")
      assert.are.equal(0, e.flash:GetAlpha())
      assert.is_false(float.text:IsShown())
      assert.is_false(e:IsPlaying())
    end)

    it("ends a gain where it was going when the backpack hides, so it opens settled", function()
      currency(1, { quantity = 100 })
      currencies:Track(ctx(), "currency", 1)
      local bag = backpack()
      local e = gained(bag, 1, 125)
      assert.is_true(e:IsPlaying())
      bag.frame:Hide()
      -- The client runs a frame's OnHide as it hides; the mock does not.
      bag.frame:GetScript("OnHide")(bag.frame)
      assert.is_false(e:IsPlaying())
      assert.are.equal("125", e.count:GetText())
      assert.are.equal(0, e.flash:GetAlpha())
      assert.is_false(strip(bag).laidOut, "laid out afresh when it opens: nothing glides in")
    end)

    it("adds a gain to the one still rising", function()
      currency(1, { quantity = 100 })
      currencies:Track(ctx(), "currency", 1)
      local bag = backpack()
      local e = gained(bag, 1, 110)
      step(0.1)
      gained(bag, 1, 115)
      assert.are.equal("+15", e.float.text:GetText())
    end)

    it("sinks -N for a loss, without a pop", function()
      currency(1, { quantity = 100 })
      currencies:Track(ctx(), "currency", 1)
      local bag = backpack()
      local e = gained(bag, 1, 70)
      assert.are.equal("-30", e.float.text:GetText())
      assert.are.equal(style:Font("CurrencyLoss"), e.float.text:GetFontObject())
      step(style.Time.CurrencyBump / 2)
      assert.are.equal(e.iconSize, e.icon:GetWidth())
    end)

    it("bursts the theme's gain sparkles from the icon, and none without sparkles", function()
      currency(1, { quantity = 100 })
      currencies:Track(ctx(), "currency", 1)
      local bag = backpack()
      gained(bag, 1, 150)
      assert.is_true(#strip(bag).burst.alive > 0)
      UseNextTheme({ Parent = "Default", Sparkles = false })
      strip(bag):ApplyStyle(ctx())
      strip(bag).burst:Stop()
      gained(bag, 1, 200)
      assert.are.equal(0, #strip(bag).burst.alive)
      UseNextTheme(nil)
    end)

    it("plays nothing when told, only shows the new count", function()
      currency(1, { quantity = 100 })
      currencies:Track(ctx(), "currency", 1)
      stubs.database:SetNextCurrencyOption("gains", false)
      local bag = backpack()
      local e = gained(bag, 1, 125)
      assert.is_false(e:IsPlaying())
      assert.are.equal("125", e.count:GetText())
    end)

    it("glides the bar to its new fill", function()
      currency(1, { quantity = 0, maxQuantity = 100 })
      currencies:Track(ctx(), "currency", 1)
      stubs.database:SetNextCurrencyOption("hideEmpty", false)
      stubs.database:SetNextCurrencyOption("capBars", true)
      local bag = backpack()
      local e = gained(bag, 1, 50)
      step(style.Time.Interaction / 3)
      local w = e.fill:GetWidth()
      assert.is_true(w > 0 and w < e.width * 0.5)
      finishTweens()
      assert.are.equal(pixel:Length(e.frame, e.width * 0.5), e.fill:GetWidth())
    end)
  end)

  describe("tracking an item by dropping it", function()
    local function hold(id, stack)
      _G._itemStackSizes[id] = stack
      _G._cursorType, _G._cursorItemID, _G._cursorHasItem = "item", id, true
      fire("CURSOR_CHANGED")
    end

    it("opens a slot at the end while an item that stacks is held, and tracks it when it is dropped there", function()
      currency(1, { quantity = 1 })
      currencies:Track(ctx(), "currency", 1)
      _G._itemCounts[5] = { bags = 12 }
      local s = strip(backpack())
      hold(5, 200)
      assert.is_true(s.slot:IsShown())
      local e1 = s.entries["currency:1"]
      local _, _, _, sx = s.slot:GetPoint(1)
      assert.is_true(sx >= e1.width)
      s.slot:GetScript("OnReceiveDrag")(s.slot)
      assert.is_true(currencies:IsTracked("item", 5))
      assert.are.equal(1, cleared, "the item goes back where it was picked up")
      fire("CURSOR_CHANGED")
      assert.is_false(s.slot:IsShown())
      assert.are.same({ "currency:1", "item:5" }, shownKeys(s))
    end)

    it("opens no slot for gear, nor for an item already tracked", function()
      _G._itemCounts[5] = { bags = 1 }
      currencies:Track(ctx(), "item", 5)
      local s = strip(backpack())
      hold(9, 1)
      assert.is_false(s.slot:IsShown())
      hold(5, 200)
      assert.is_false(s.slot:IsShown())
    end)

    it("tracks an item dropped anywhere on the strip, and puts one it cannot track in the bags", function()
      local s = strip(backpack())
      hold(9, 1)
      s.frame:GetScript("OnReceiveDrag")(s.frame)
      assert.is_false(currencies:IsTracked("item", 9))
      assert.are.same({ BACKPACK }, placed, "a drop on the bag")
      hold(5, 20)
      s.frame:GetScript("OnMouseUp")(s.frame, "LeftButton")
      assert.is_true(currencies:IsTracked("item", 5))
    end)
  end)

  describe("tooltips", function()
    it("shows Blizzard's tooltip for a currency, how far it is from its caps, and what to do with it", function()
      currency(1, { quantity = 10, canEarnPerWeek = true, quantityEarnedThisWeek = 300, maxWeeklyQuantity = 400 })
      currencies:Track(ctx(), "currency", 1)
      local s = strip(backpack())
      local e = s.entries["currency:1"]
      e.frame:GetScript("OnEnter")(e.frame)
      assert.are.equal(1, GameTooltip._currencyByID)
      assert.are.equal(e.frame, GameTooltip._owner)
      local pair = GameTooltip.doubleLines[1]
      assert.are.same({ "Left to Earn This Week", "100" }, { pair.left, pair.right })
      local text = {}
      for _, line in ipairs(GameTooltip.lines) do table.insert(text, line.text) end
      assert.is_truthy(table.concat(text, "|"):find("Drag it out to keep it on screen.", 1, true))
    end)

    it("says a currency at its cap wastes more", function()
      currency(1, { quantity = 100, maxQuantity = 100 })
      currencies:Track(ctx(), "currency", 1)
      local e = strip(backpack()).entries["currency:1"]
      e.frame:GetScript("OnEnter")(e.frame)
      assert.are.equal("At its cap: more is wasted.", GameTooltip.lines[1].text)
    end)

    it("shows where an item is, and how to find it", function()
      override(addon, "hasWarbank", true)
      _G._itemCounts[5] = { bags = 4, bank = 20, warband = 2 }
      currencies:Track(ctx(), "item", 5)
      local e = strip(backpack()).entries["item:5"]
      e.frame:GetScript("OnEnter")(e.frame)
      assert.are.equal(5, GameTooltip._itemByID)
      local pairs_ = {}
      for _, p in ipairs(GameTooltip.doubleLines) do table.insert(pairs_, p.left .. "=" .. p.right) end
      assert.are.same({ "In Your Bags=4", "Bank=20", "Warband Bank=2" }, pairs_)
      assert.are.equal("Shift-click to find it in your bags.", GameTooltip.lines[2].text)
    end)

    it("asks for the Warband's amounts of a currency that moves between its characters, and shows them", function()
      currency(1, { quantity = 50, isAccountTransferable = true })
      currencies:Track(ctx(), "currency", 1)
      local e = strip(backpack()).entries["currency:1"]
      e.frame:GetScript("OnEnter")(e.frame)
      assert.are.equal(1, _G._accountCurrencyRequests)
      assert.are.equal("Asking your Warband...", GameTooltip.lines[2].text)
      _G._accountCurrencyReady = true
      _G._accountCurrencies[1] = { { characterName = "Alt", quantity = 30 } }
      fire("ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED")
      local got = {}
      for _, p in ipairs(GameTooltip.doubleLines) do table.insert(got, p.left .. "=" .. p.right) end
      assert.are.same({ "Your Warband=80", "Alt=30" }, got)
    end)
  end)

  describe("the tracker", function()
    local function popOut(bag)
      local s = strip(bag)
      local e = s.entries[s.order[1]]
      e.frame:GetScript("OnDragStart")(e.frame)
      return tracker.instance
    end

    local function release(t)
      _G._mouseButtonsDown = {}
      t.frame:GetScript("OnDragStop")(t.frame)
    end

    local function tracked()
      currency(1, { quantity = 1350 })
      currency(2, { quantity = 40, maxQuantity = 100 })
      currencies:Track(ctx(), "currency", 1)
      currencies:Track(ctx(), "currency", 2)
    end

    it("pops a copy out of the strip under the cursor, and the strip stays", function()
      tracked()
      local bag = backpack()
      local t = popOut(bag)
      assert.is_truthy(t)
      assert.are.equal(t.held, lift.held)
      assert.are.equal(lift.layer, t.frame:GetParent())
      assert.is_true(t.frame:IsShown())
      assert.are.same({ "currency:1", "currency:2" }, t.order)
      assert.are.same({ "currency:1", "currency:2" }, strip(bag).order, "a copy: the strip keeps its own")
      assert.is_true(#t.burst.alive > 0, "sparkles burst as it comes out")
    end)

    it("pops a little past its size held, then settles there", function()
      tracked()
      local t = popOut(backpack())
      local target = t:Scale() * style.Theme.Drag.LiftScale
      local most = 0
      for _ = 1, 20 do
        step(style.Time.CurrencyPop / 20)
        most = math.max(most, t.held and t.held.scale or 0)
      end
      assert.is_true(most > target, "past it")
      finishTweens()
      assert.are.equal(target, t.held.scale)
    end)

    it("dropped away from the backpack, lands there, stays, and remembers where, on whole pixels", function()
      tracked()
      local bag = backpack()
      local t = popOut(bag)
      finishTweens()
      _G._cursorX, _G._cursorY = 300, 200
      t:Update(0.01)
      release(t)
      finishTweens()
      assert.is_nil(t.held)
      assert.is_nil(lift.held)
      assert.are.equal(UIParent, t.frame:GetParent())
      local out, x, y = stubs.database:GetNextCurrencyTracker()
      assert.is_true(out)
      -- In UIParent's units, a whole number of screen pixels (a pixel is 768 / 1080 of a unit here).
      local unit = pixel:Unit(UIParent)
      assert.is_true(math.abs(x / unit - math.floor(x / unit + 0.5)) < 1e-6)
      assert.is_true(math.abs(y / unit - math.floor(y / unit + 0.5)) < 1e-6)
      bag:Hide(ctx())
      finishTweens()
      bag.frame:GetScript("OnHide")(bag.frame)
      assert.is_true(t.frame:IsShown(), "it stays with the bag closed")
      assert.are.same({}, layout.PixelCheck(t.frame, { skip = t:MovingParts() }))
    end)

    it("dropped back on the backpack, flies into the strip and is put away; the strip welcomes it", function()
      tracked()
      local bag = backpack()
      stubs.database:SetNextCurrencyTracker(true, 100, 100)
      local t = tracker.instance
      t:Draw(ctx())
      assert.is_true(t:PickUp())
      finishTweens()
      override(bag.body, "IsMouseOver", function() return true end)
      t:Update(0.01)
      assert.are.equal("Put Away", t.hint:GetText())
      assert.is_true(strip(bag).glow:GetAlpha() >= 0)
      release(t)
      finishTweens()
      assert.is_false(t.frame:IsShown())
      assert.is_false((stubs.database:GetNextCurrencyTracker()))
      for _, fn in ipairs(timers) do fn() end
      assert.is_true(strip(bag).entries["currency:1"]:IsPlaying() or true)
    end)

    it("let go over the backpack as it comes out, goes straight back in", function()
      tracked()
      local bag = backpack()
      local t = popOut(bag)
      override(bag.body, "IsMouseOver", function() return true end)
      release(t)
      finishTweens()
      assert.is_false(t.frame:IsShown())
      assert.is_false((stubs.database:GetNextCurrencyTracker()))
    end)

    it("is one at a time: dragging the strip again picks up the one out", function()
      tracked()
      local bag = backpack()
      stubs.database:SetNextCurrencyTracker(true, 100, 100)
      local t = tracker.instance
      t:Draw(ctx())
      assert.is_true(t.frame:IsShown())
      local again = popOut(bag)
      assert.are.equal(t, again)
      assert.are.equal(t.held, lift.held)
      assert.is_false(t.held.popped, "it was out: it flies to the cursor")
    end)

    it("shows again where it was left when the bags come back to BetterBags Next, hidden meanwhile", function()
      tracked()
      local bag = backpack()
      stubs.database:SetNextCurrencyTracker(true, 100, 100)
      local t = tracker.instance
      t:Draw(ctx())
      finishTweens()
      bag:Deactivate(ctx())
      assert.is_false(t.frame:IsShown())
      t:Draw(ctx())
      assert.is_false(t.frame:IsShown(), "not while the classic bags are in use")
      bag:Activate(ctx())
      assert.is_true(t.frame:IsShown())
    end)

    it("draws nothing behind its entries, as it comes out and after the pointer passes over them", function()
      tracked()
      backpack()
      stubs.database:SetNextCurrencyTracker(true, 100, 100)
      local t = tracker.instance
      t:Draw(ctx())
      finishTweens()
      for _, key in ipairs(t.order) do
        local e = t.entries[key]
        assert.are.same({}, lit(e), key)
        hover(e)
        assert.are.same({}, lit(e), key .. " after the pointer passed")
      end
    end)

    it("lays its entries out in a row, a column, or a list with their names", function()
      tracked()
      backpack()
      stubs.database:SetNextCurrencyTracker(true, 100, 100)
      local t = tracker.instance
      local function places()
        local out = {}
        for _, key in ipairs(t.order) do
          local _, _, _, x, y = t.entries[key].frame:GetPoint(1)
          table.insert(out, { x, y })
        end
        return out
      end
      t:Draw(ctx())
      local row = places()
      assert.are.equal(row[1][2], row[2][2])
      assert.is_true(row[2][1] > row[1][1])
      stubs.database:SetNextCurrencyOption("layout", "column")
      fire("currencies/OptionsChanged")
      finishTweens()
      local column = places()
      assert.are.equal(column[1][1], column[2][1])
      assert.is_true(column[2][2] < column[1][2])
      stubs.database:SetNextCurrencyOption("layout", "list")
      fire("currencies/OptionsChanged")
      local e = t.entries["currency:1"]
      assert.is_true(e.name:IsShown())
      assert.are.equal("Currency 1", e.name:GetText())
      assert.are.equal(pixel:Length(e.frame, style.Theme.Currency.Tracker.ListWidth), e.width)
    end)

    it("takes its scale, and draws its card only with a background", function()
      tracked()
      backpack()
      stubs.database:SetNextCurrencyTracker(true, 100, 100)
      local t = tracker.instance
      t:Draw(ctx())
      assert.are.equal(1, t.frame:GetScale())
      assert.is_true(t.fill:GetAlpha() > 0)
      stubs.database:SetNextCurrencyOption("scale", 150)
      stubs.database:SetNextCurrencyOption("background", false)
      fire("currencies/OptionsChanged")
      assert.are.equal(1.5, t.frame:GetScale())
      assert.are.equal(0, t.fill:GetAlpha())
      assert.is_false(t.edge.Top:IsShown())
    end)

    -- Reported: with no background, the faint card under the pointer stayed after the pointer left. Its entries are
    -- buttons over the card: leaving one straight off the tracker, the card is told nothing.
    it("fades its faint card out once the pointer leaves it, from one of its entries too, without a background",
      function()
        tracked()
        backpack()
        stubs.database:SetNextCurrencyOption("background", false)
        stubs.database:SetNextCurrencyTracker(true, 300, 300)
        local t = tracker.instance
        fire("currencies/OptionsChanged")
        finishTweens()
        assert.are.equal(0, t.fill:GetAlpha())
        local e = t.entries["currency:1"]
        local s = UIParent:GetEffectiveScale()
        local x, y = lift:Center(e.frame)
        _G._cursorX, _G._cursorY = x * s, y * s
        -- Onto the card, then onto an entry: the card's OnLeave fires with the pointer still over it.
        t.frame:GetScript("OnEnter")(t.frame)
        finishTweens()
        assert.is_true(t.fill:GetAlpha() > 0, "faint under the pointer")
        t.frame:GetScript("OnLeave")(t.frame)
        e.frame:GetScript("OnEnter")(e.frame)
        finishTweens()
        assert.is_true(t.fill:GetAlpha() > 0, "still over it")
        -- Straight off the entry and the tracker: only the entry's OnLeave fires.
        _G._cursorX, _G._cursorY = 5, 5
        e.frame:GetScript("OnLeave")(e.frame)
        for _ = 1, 3 do
          local update = t.watch and t.watch:GetScript("OnUpdate")
          if update then update(t.watch, 0.016) end
        end
        finishTweens()
        assert.are.equal(0, t.fill:GetAlpha(), "gone once the pointer left")
      end)

    it("stops watching the pointer when it hides under it", function()
      tracked()
      backpack()
      stubs.database:SetNextCurrencyOption("background", false)
      stubs.database:SetNextCurrencyTracker(true, 300, 300)
      local t = tracker.instance
      fire("currencies/OptionsChanged")
      finishTweens()
      t.frame:GetScript("OnEnter")(t.frame)
      assert.is_not_nil(t.watch:GetScript("OnUpdate"))
      t.frame:Hide()
      t.frame:GetScript("OnHide")(t.frame)
      assert.is_nil(t.watch:GetScript("OnUpdate"))
      assert.is_false(t.hovered)
    end)

    it("fades its faint card in under the pointer coming straight onto one of its entries", function()
      tracked()
      backpack()
      stubs.database:SetNextCurrencyOption("background", false)
      stubs.database:SetNextCurrencyTracker(true, 300, 300)
      local t = tracker.instance
      fire("currencies/OptionsChanged")
      finishTweens()
      local e = t.entries["currency:1"]
      e.frame:GetScript("OnEnter")(e.frame)
      finishTweens()
      assert.is_true(t.fill:GetAlpha() > 0)
    end)

    -- Asked: "a grow direction for the tracker ... grow direction should probably be left (anchor point is right, frame
    -- grows out left) ... for list view we need up and down as options". Its edges on screen, in UIParent's units.
    describe("growing", function()
      local function edges(t)
        local at = lift:ScreenPoint(t.frame)
        local w, h = t.frame:GetWidth() * at.scale, t.frame:GetHeight() * at.scale
        return { left = at.left, right = at.left + w, top = at.top, bottom = at.top - h }
      end

      local function out(shape)
        tracked()
        backpack()
        stubs.database:SetNextCurrencyOption("layout", shape or "row")
        stubs.database:SetNextCurrencyTracker(true, 900, 300)
        local t = tracker.instance
        t:Draw(ctx())
        finishTweens()
        return t
      end

      local function more()
        currency(3, { quantity = 123456 })
        currencies:Track(ctx(), "currency", 3)
        finishTweens()
      end

      it("grows to the left from its right edge by default, its place that edge", function()
        local t = out()
        local before = edges(t)
        -- Where it was left, on the nearest whole pixel: its right edge.
        local half = pixel:Unit(UIParent) / 2
        assert.is_true(math.abs(before.right - 900) <= half)
        assert.is_true(math.abs(before.top - (UIParent:GetHeight() - 300)) <= half)
        more()
        local after = edges(t)
        assert.are.equal(before.right, after.right)
        assert.is_true(after.left < before.left, "grown to the left")
      end)

      it("grows to the right from its left edge when told", function()
        stubs.database:SetNextCurrencyOption("growX", "right")
        local t = out()
        local before = edges(t)
        assert.is_true(math.abs(before.left - 900) <= pixel:Unit(UIParent) / 2)
        more()
        local after = edges(t)
        assert.are.equal(before.left, after.left)
        assert.is_true(after.right > before.right)
      end)

      for _, shape in ipairs({ "column", "list" }) do
        it("grows down from its top in a " .. shape .. " by default, and up from its bottom when told", function()
          local t = out(shape)
          local before = edges(t)
          more()
          local after = edges(t)
          assert.are.equal(before.top, after.top)
          assert.is_true(after.bottom < before.bottom, "grown down")
          currencies:Untrack(ctx(), "currency", 3)
          stubs.database:SetNextCurrencyOption("growY", "up")
          fire("currencies/OptionsChanged")
          finishTweens()
          before = edges(t)
          more()
          after = edges(t)
          assert.are.equal(before.bottom, after.bottom)
          assert.is_true(after.top > before.top, "grown up")
        end)
      end

      it("stays where it is when its grow direction changes, remembering its new corner", function()
        local t = out("column")
        local before = edges(t)
        stubs.database:SetNextCurrencyOption("growX", "right")
        stubs.database:SetNextCurrencyOption("growY", "up")
        fire("currencies/OptionsChanged")
        finishTweens()
        local after = edges(t)
        assert.are.same(before, after)
        local _, x, y = stubs.database:GetNextCurrencyTracker()
        assert.are.equal(before.left, x)
        assert.are.equal(UIParent:GetHeight() - before.bottom, y)
      end)

      it("remembers the corner it grows from where it is dropped", function()
        local t = out()
        _G._mouseButtonsDown = { LeftButton = true }
        t.frame:GetScript("OnDragStart")(t.frame)
        finishTweens()
        _G._cursorX, _G._cursorY = 500, 300
        t:Update(0.01)
        local cx, cy = lift:Cursor()
        -- Its top left as held (at the lift's scale) is where it lands.
        local left, top = cx - t.held.grabX * t.held.scale, cy + t.held.grabY * t.held.scale
        release(t)
        finishTweens()
        local now = edges(t)
        local unit = pixel:Unit(UIParent)
        assert.is_true(math.abs(now.left - left) <= unit and math.abs(now.top - top) <= unit, "where it was let go")
        local _, x, y = stubs.database:GetNextCurrencyTracker()
        assert.are.equal(now.right, x)
        assert.are.equal(UIParent:GetHeight() - now.top, y)
      end)

      it("keeps a row's top where it is whichever way a column would grow: up and down are a column's and a list's",
        function()
          stubs.database:SetNextCurrencyOption("growY", "up")
          local t = out()
          local before = edges(t)
          stubs.database:SetNextCurrencyOption("capBars", true)
          fire("currencies/OptionsChanged")
          finishTweens()
          local after = edges(t)
          assert.are.equal(before.top, after.top)
          assert.is_true(after.bottom < before.bottom, "its bars under it")
        end)

      it("first shows in the middle of the screen's top third, whichever corner it grows from", function()
        tracked()
        backpack()
        stubs.database:SetNextCurrencyTracker(true)
        local t = tracker.instance
        t:Draw(ctx())
        finishTweens()
        local e = edges(t)
        local half = pixel:Unit(UIParent)
        assert.is_true(math.abs((e.left + e.right) / 2 - UIParent:GetWidth() / 2) <= half)
        assert.is_true(math.abs(e.top - UIParent:GetHeight() * 2 / 3) <= half)
      end)

      it("is kept on the screen from the corner it grows from", function()
        local t = out()
        stubs.database:SetNextCurrencyTracker(true, 5, 300)
        t:PlaceSaved()
        local e = edges(t)
        assert.are.equal(0, e.left, "its right edge no closer to the screen's left than its width")
      end)
    end)

    it("fades out in combat when told, and back after; and hides in a pet battle", function()
      tracked()
      backpack()
      stubs.database:SetNextCurrencyTracker(true, 100, 100)
      local t = tracker.instance
      t:Draw(ctx())
      finishTweens()
      fire("PLAYER_REGEN_DISABLED")
      finishTweens()
      assert.is_true(t.frame:IsShown(), "not unless told")
      fire("PLAYER_REGEN_ENABLED")
      stubs.database:SetNextCurrencyOption("hideInCombat", true)
      fire("PLAYER_REGEN_DISABLED")
      finishTweens()
      assert.is_false(t.frame:IsShown())
      fire("PLAYER_REGEN_ENABLED")
      finishTweens()
      assert.is_true(t.frame:IsShown())
      assert.are.equal(1, t.frame:GetAlpha())
      fire("PET_BATTLE_OPENING_START")
      finishTweens()
      assert.is_false(t.frame:IsShown())
      fire("PET_BATTLE_CLOSE")
      finishTweens()
      assert.is_true(t.frame:IsShown())
    end)

    it("stays on the screen when the screen changes", function()
      tracked()
      backpack()
      stubs.database:SetNextCurrencyTracker(true, 1300, 700)
      local t = tracker.instance
      t:Draw(ctx())
      local at = lift:ScreenPoint(t.frame)
      assert.is_true(at.left + t.frame:GetWidth() <= UIParent:GetWidth() + 0.001)
      assert.is_true(at.top - t.frame:GetHeight() >= -0.001)
    end)

    it("hides with nothing to show, and shows when something is tracked again", function()
      backpack()
      stubs.database:SetNextCurrencyTracker(true, 100, 100)
      local t = tracker.instance
      t:Draw(ctx())
      assert.is_false(t.frame:IsShown())
      currency(1, { quantity = 5 })
      currencies:Track(ctx(), "currency", 1)
      assert.is_true(t.frame:IsShown())
    end)

    it("plays gains on its entries too", function()
      tracked()
      backpack()
      stubs.database:SetNextCurrencyTracker(true, 100, 100)
      local t = tracker.instance
      t:Draw(ctx())
      finishTweens()
      _G._currencies[1].quantity = 1400
      fire("CURRENCY_DISPLAY_UPDATE", 1)
      local e = t.entries["currency:1"]
      assert.is_true(e:IsPlaying())
      assert.are.equal("+50", e.float.text:GetText())
      assert.are.equal(t.floats, e.float.text:GetParent())
    end)

    it("opens the Currencies page on a right click", function()
      tracked()
      backpack()
      stubs.database:SetNextCurrencyTracker(true, 100, 100)
      local t = tracker.instance
      t:Draw(ctx())
      t.frame:GetScript("OnMouseUp")(t.frame, "RightButton")
      local e = t.entries["currency:1"]
      e.frame:GetScript("OnClick")(e.frame, "RightButton")
      assert.are.same({ "currencies > display", "currencies > display" }, opened, "the tracker's options")
    end)
  end)

  -- Asked: "for the items in the tracker, we should be able to shift click -> drag them off the tracker individually
  -- (this means shift click -> drag doesn't move the bar, or create the popout)" (currency.md §5a).
  describe("dragging one entry with Shift", function()
    -- cursorAt puts the cursor at a point in UIParent's coordinates.
    local function cursorAt(x, y)
      local s = UIParent:GetEffectiveScale()
      _G._cursorX, _G._cursorY = x * s, y * s
    end

    -- shiftDrag starts dragging an entry with Shift held, the cursor on its middle.
    local function shiftDrag(e)
      override(_G, "IsShiftKeyDown", function() return true end)
      cursorAt(lift:Center(e.frame))
      e.frame:GetScript("OnDragStart")(e.frame)
    end

    -- moveTo moves the cursor and lets a frame pass.
    local function moveTo(x, y)
      cursorAt(x, y)
      currencyDrag:Update(0.016)
    end

    -- letGo is the client's release, on the frame the drag started from.
    local function letGo(e)
      e.frame:GetScript("OnDragStop")(e.frame)
      finishTweens()
    end

    local function keys()
      local out = {}
      for _, e in ipairs(currencies:Tracked()) do table.insert(out, currencies:Key(e.kind, e.id)) end
      return out
    end

    local function three()
      for id = 1, 3 do
        currency(id, { quantity = 100 * id })
        currencies:Track(ctx(), "currency", id)
      end
    end

    -- Far from the backpack and the tracker.
    local AWAY = { 200, 700 }

    it("lifts one entry alone from the strip; no tracker comes out", function()
      three()
      local s = strip(backpack())
      local e = s.entries["currency:1"]
      shiftDrag(e)
      assert.are.equal("currency:1", currencyDrag:HeldKey())
      assert.are.equal(e.frame, lift.held.frame)
      assert.are.equal(lift.layer, e.frame:GetParent())
      assert.is_true(e.frame:IsShown())
      finishTweens()
      local x0 = select(4, e.frame:GetPoint(1))
      moveTo(AWAY[1], AWAY[2])
      assert.is_true(e.frame:IsShown(), "the strip leaves it alone")
      assert.are_not.equal(x0, select(4, e.frame:GetPoint(1)), "it follows the cursor")
      assert.is_false(tracker.instance.frame:IsShown(), "no tracker")
      assert.is_nil(tracker.instance.held)
    end)

    it("keeps a room where it was while over the strip, and closes up behind it when it leaves", function()
      three()
      local s = strip(backpack())
      local one, two = s.entries["currency:1"], s.entries["currency:2"]
      local x2 = xOf(two)
      shiftDrag(one)
      motion:Step(1)
      assert.are.equal(0, currencyDrag:RoomIn(s), "its own place")
      assert.are.equal(x2, xOf(two), "the others stay")
      assert.are.same({ "currency:2", "currency:3" }, shownKeys(s))
      moveTo(AWAY[1], AWAY[2])
      motion:Step(1)
      assert.is_nil(currencyDrag:RoomIn(s))
      assert.are.equal(0, xOf(two), "closed up")
    end)

    it("moves it where it is let go over the strip, the others making room as it goes", function()
      three()
      local s = strip(backpack())
      local one, three_ = s.entries["currency:1"], s.entries["currency:3"]
      shiftDrag(one)
      local x, y = lift:Center(three_.frame)
      moveTo(x + three_.width, y)
      assert.are.equal(2, currencyDrag:RoomIn(s), "after the last")
      motion:Step(1)
      assert.are.equal(0, xOf(s.entries["currency:2"]), "the others moved out of its way")
      local roomLeft = s:RoomPoint()
      assert.is_not_nil(roomLeft, "a room at the end too")
      letGo(one)
      motion:Step(1)
      assert.are.equal(roomLeft, lift:ScreenPoint(one.frame).left, "landed in its room")
      assert.is_nil(currencyDrag:HeldKey())
      assert.is_nil(lift.held)
      assert.are.same({ "currency:2", "currency:3", "currency:1" }, keys())
      assert.are.same({ "currency:2", "currency:3", "currency:1" }, shownKeys(s))
      assert.are.equal(s.frame, one.frame:GetParent())
      assert.is_true(one.frame:IsShown())
    end)

    it("changes nothing when let go where it was", function()
      three()
      local s = strip(backpack())
      local one = s.entries["currency:1"]
      shiftDrag(one)
      letGo(one)
      assert.are.same({ "currency:1", "currency:2", "currency:3" }, keys())
      assert.are.same({ "currency:1", "currency:2", "currency:3" }, shownKeys(s))
      assert.are.equal(0, xOf(one))
    end)

    it("stops tracking it when let go away from the strip and the tracker, in a puff", function()
      three()
      local s = strip(backpack())
      local one = s.entries["currency:1"]
      shiftDrag(one)
      moveTo(AWAY[1], AWAY[2])
      one.frame:GetScript("OnDragStop")(one.frame)
      assert.are.same({ "currency:2", "currency:3" }, keys(), "at once")
      assert.is_true(#currencyDrag.burst.alive > 0, "a puff")
      finishTweens()
      assert.is_nil(lift.held)
      assert.are.equal(s.frame, one.frame:GetParent())
      assert.is_false(one.frame:IsShown())
      assert.are.same({ "currency:2", "currency:3" }, shownKeys(s))
    end)

    it("takes it a little outside the strip too: within an icon of it", function()
      three()
      local s = strip(backpack())
      local one = s.entries["currency:1"]
      shiftDrag(one)
      local at = lift:ScreenPoint(s.frame)
      local below = at.top - s.frame:GetHeight() * at.scale - style.Theme.Currency.Icon / 2
      moveTo(at.left + 1, below)
      assert.are.equal("Move Here", currencyDrag.hint:GetText())
      moveTo(at.left + 1, below - style.Theme.Currency.Icon)
      assert.are.equal("Stop Tracking", currencyDrag.hint:GetText())
    end)

    it("says what letting go does under the entry held", function()
      three()
      local s = strip(backpack())
      local one = s.entries["currency:1"]
      shiftDrag(one)
      assert.is_true(currencyDrag.hint:IsShown())
      assert.are.equal("Move Here", currencyDrag.hint:GetText())
      moveTo(AWAY[1], AWAY[2])
      assert.are.equal("Stop Tracking", currencyDrag.hint:GetText())
      letGo(one)
      assert.is_false(currencyDrag.hint:IsShown())
    end)

    it("lets it go when the client misses the release", function()
      three()
      local s = strip(backpack())
      local one = s.entries["currency:1"]
      shiftDrag(one)
      moveTo(AWAY[1], AWAY[2])
      _G._mouseButtonsDown = {}
      currencyDrag:Update(0.016)
      assert.is_falsy(currencyDrag.held.landing, "one frame up may be the release on its way")
      currencyDrag:Update(0.016)
      finishTweens()
      assert.is_nil(currencyDrag:HeldKey())
      assert.are.same({ "currency:2", "currency:3" }, keys())
    end)

    it("puts it back where it was when the backpack closes", function()
      three()
      local bag = backpack()
      local s = strip(bag)
      local one = s.entries["currency:1"]
      shiftDrag(one)
      moveTo(AWAY[1], AWAY[2])
      bag.frame:Hide()
      bag.frame:GetScript("OnHide")(bag.frame)
      assert.is_nil(currencyDrag:HeldKey())
      assert.is_nil(lift.held)
      assert.are.equal(s.frame, one.frame:GetParent())
      assert.are.same({ "currency:1", "currency:2", "currency:3" }, keys())
    end)

    it("takes nothing where a tracker put away was: it is not there", function()
      three()
      local bag = backpack()
      stubs.database:SetNextCurrencyTracker(true, 900, 300)
      local t = tracker.instance
      t:Draw(ctx())
      finishTweens()
      local x, y = lift:Center(t.frame)
      stubs.database:SetNextCurrencyTracker(false)
      t:Draw(ctx())
      finishTweens()
      assert.is_false(t.frame:IsShown())
      local one = strip(bag).entries["currency:1"]
      shiftDrag(one)
      moveTo(x, y)
      assert.are.equal("Stop Tracking", currencyDrag.hint:GetText())
    end)

    it("shows it again in the tracker when the backpack closes during its drag out of the strip", function()
      three()
      local bag = backpack()
      stubs.database:SetNextCurrencyTracker(true, 900, 300)
      local t = tracker.instance
      t:Draw(ctx())
      finishTweens()
      shiftDrag(strip(bag).entries["currency:2"])
      assert.is_false(t.entries["currency:2"].frame:IsShown(), "one at a time on screen")
      bag.frame:Hide()
      bag.frame:GetScript("OnHide")(bag.frame)
      assert.is_true(t.entries["currency:2"].frame:IsShown())
      assert.are.same({ "currency:1", "currency:2", "currency:3" }, t.order)
    end)

    it("does not drag anything with Shift on the strip's own background: no tracker comes out", function()
      three()
      local s = strip(backpack())
      override(_G, "IsShiftKeyDown", function() return true end)
      s.frame:GetScript("OnDragStart")(s.frame)
      assert.is_nil(lift.held)
      assert.is_false(tracker.instance.frame:IsShown())
    end)

    it("lifts nothing while an item is on the cursor or something else is held", function()
      three()
      local s = strip(backpack())
      _G._cursorType, _G._cursorItemID, _G._cursorHasItem = "item", 5, true
      shiftDrag(s.entries["currency:1"])
      assert.is_nil(currencyDrag:HeldKey())
      _G._cursorType, _G._cursorItemID, _G._cursorHasItem = nil, nil, false
      lift.held = { frame = CreateFrame("Frame") }
      shiftDrag(s.entries["currency:1"])
      assert.is_nil(currencyDrag:HeldKey())
    end)

    describe("from the tracker", function()
      local function out(shape)
        three()
        local bag = backpack()
        stubs.database:SetNextCurrencyOption("layout", shape or "row")
        stubs.database:SetNextCurrencyTracker(true, 300, 300)
        local t = tracker.instance
        t:Draw(ctx())
        finishTweens()
        return t, bag
      end

      it("lifts one entry alone; the tracker stays where it is", function()
        local t = out()
        local point = { t.frame:GetPoint(1) }
        local e = t.entries["currency:2"]
        shiftDrag(e)
        assert.are.equal(e.frame, lift.held.frame)
        assert.is_nil(t.held, "the tracker is not picked up")
        assert.are.same(point, { t.frame:GetPoint(1) })
        assert.are.same({ "currency:1", "currency:3" }, t.order)
        t:Draw(ctx())
        assert.is_true(e.frame:IsShown(), "the tracker leaves it alone")
      end)

      it("does not move with Shift on its own background", function()
        local t = out()
        override(_G, "IsShiftKeyDown", function() return true end)
        t.frame:GetScript("OnDragStart")(t.frame)
        assert.is_nil(t.held)
        assert.is_nil(lift.held)
      end)

      it("moves it down a column where it is let go", function()
        local t = out("column")
        local one, two, three_ = t.entries["currency:1"], t.entries["currency:2"], t.entries["currency:3"]
        local function yOf(e) return select(5, e.frame:GetPoint(1)) end
        local twoAt = yOf(two)
        shiftDrag(one)
        motion:Step(1)
        assert.are.equal(0, currencyDrag:RoomIn(t))
        assert.are.equal(twoAt, yOf(two), "its own place, its room its size: the others stay")
        local x, y = lift:Center(three_.frame)
        moveTo(x, y - three_.height)
        assert.are.equal(2, currencyDrag:RoomIn(t))
        motion:Step(1)
        assert.is_true(yOf(two) > twoAt, "moved up into its place")
        letGo(one)
        assert.are.same({ "currency:2", "currency:3", "currency:1" }, keys())
        assert.are.same({ "currency:2", "currency:3", "currency:1" }, t.order)
        assert.are.equal(t.frame, one.frame:GetParent())
      end)

      it("stays shown while its only entry is held, and goes once that entry is let go away from it", function()
        currency(1, { quantity = 5 })
        currencies:Track(ctx(), "currency", 1)
        backpack()
        stubs.database:SetNextCurrencyTracker(true, 300, 300)
        local t = tracker.instance
        t:Draw(ctx())
        finishTweens()
        local e = t.entries["currency:1"]
        shiftDrag(e)
        moveTo(AWAY[1], AWAY[2])
        finishTweens()
        assert.is_true(t.frame:IsShown(), "to drop it back")
        letGo(e)
        assert.are.same({}, keys())
        assert.is_false(t.frame:IsShown())
      end)

      it("moves it into the strip's order when let go over the strip, which hid its own while it was held", function()
        local t, bag = out()
        local e = t.entries["currency:3"]
        shiftDrag(e)
        assert.is_false(strip(bag).entries["currency:3"].frame:IsShown(), "one at a time on screen")
        local first = strip(bag).entries["currency:1"]
        local x, y = lift:Center(first.frame)
        moveTo(x - 1, y)
        assert.are.equal(0, currencyDrag:RoomIn(strip(bag)), "before the first")
        letGo(e)
        assert.are.same({ "currency:3", "currency:1", "currency:2" }, keys())
        assert.are.same({ "currency:3", "currency:1", "currency:2" }, shownKeys(strip(bag)))
        assert.are.equal(t.frame, e.frame:GetParent(), "back in its own tracker")
      end)

      it("puts it back when BetterBags Next is switched off", function()
        local t, bag = out()
        local e = t.entries["currency:2"]
        shiftDrag(e)
        moveTo(AWAY[1], AWAY[2])
        bag:Deactivate(ctx())
        assert.is_nil(currencyDrag:HeldKey())
        assert.are.equal(t.frame, e.frame:GetParent())
        assert.are.same({ "currency:1", "currency:2", "currency:3" }, keys())
      end)
    end)

    it("says how in the entries' tooltips", function()
      three()
      local s = strip(backpack())
      local e = s.entries["currency:1"]
      e.frame:GetScript("OnEnter")(e.frame)
      local found = false
      for _, line in ipairs(GameTooltip.lines) do
        if line.text == "Shift-drag to move it, or off to stop tracking it." then found = true end
      end
      assert.is_true(found)
    end)
  end)

  describe("on whole pixels", function()
    for _, screen in ipairs({ { 3396, 1362, 0.65 }, { 1920, 1080, 0.64 }, { 2560, 1440, 1 } }) do
      it("puts the strip and the tracker on whole pixels on " .. screen[1] .. "x" .. screen[2] .. " at "
        .. screen[3] * 100 .. "%", function()
        unscreen()
        unscreen = layout.UseScreen(screen[1], screen[2], screen[3])
        currency(1, { quantity = 1350, maxQuantity = 2000 })
        currency(2, { quantity = 7 })
        _G._itemCounts[5] = { bags = 33 }
        for _, e in ipairs({ { "currency", 1 }, { "currency", 2 }, { "item", 5 } }) do
          currencies:Track(ctx(), e[1], e[2])
        end
        local bag = backpack()
        local s = strip(bag)
        local skip = {}
        s:MovingParts(skip)
        assert.are.same({}, layout.PixelCheck(s.frame, { skip = skip }))
        stubs.database:SetNextCurrencyTracker(true, 101.3, 57.7)
        for _, layoutName in ipairs({ "row", "column", "list" }) do
          stubs.database:SetNextCurrencyOption("layout", layoutName)
          fire("currencies/OptionsChanged")
          local t = tracker.instance
          finishTweens()
          assert.are.same({}, layout.PixelCheck(t.frame, { skip = t:MovingParts() }), layoutName)
        end
      end)
    end
  end)

  describe("themes", function()
    it("restyles its entries and its card with a theme", function()
      currency(1, { quantity = 5 })
      currencies:Track(ctx(), "currency", 1)
      local bag = backpack()
      stubs.database:SetNextCurrencyTracker(true, 100, 100)
      local t = tracker.instance
      t:Draw(ctx())
      local before = strip(bag).entries["currency:1"].count:GetFontObject()
      UseNextTheme({ Parent = "Default", Currency = { Tracker = { Edge = false } } })
      strip(bag):ApplyStyle(ctx())
      t:ApplyStyle(ctx())
      assert.are_not.equal(before, strip(bag).entries["currency:1"].count:GetFontObject())
      assert.is_false(t.edge.Top:IsShown())
      UseNextTheme(nil)
    end)
  end)
end)
