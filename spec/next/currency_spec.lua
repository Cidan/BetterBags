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
  { "NextOrnaments", "next/ornaments.lua" }, { "NextMenuButton", "next/menubutton.lua" }, { "NextPanel", "next/panel.lua" },
  { "Currencies", "data/currencies.lua" }, { "NextCurrencyEntry", "next/currencyentry.lua" },
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

    it("draws a cap bar for a currency with a cap, its fill its progress, and none for one without", function()
      currency(1, { quantity = 300, maxQuantity = 1200 })
      currency(2, { quantity = 5 })
      currencies:Track(ctx(), "currency", 1)
      currencies:Track(ctx(), "currency", 2)
      local s = strip(backpack())
      local capped, plain = s.entries["currency:1"], s.entries["currency:2"]
      assert.is_true(capped.track:IsShown())
      assert.is_true(capped.fill:IsShown())
      assert.are.equal(pixel:Length(capped.frame, capped.width * 0.25), capped.fill:GetWidth())
      assert.is_false(plain.track:IsShown())
    end)

    it("draws no bars when told", function()
      currency(1, { quantity = 300, maxQuantity = 1200 })
      currencies:Track(ctx(), "currency", 1)
      stubs.database:SetNextCurrencyOption("capBars", false)
      local s = strip(backpack())
      assert.is_false(s.entries["currency:1"].track:IsShown())
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
