-- A text sits a quarter pixel right of and above its whole pixel (next-pixel-perfect.md §2); one pixel is one unit here.
local TEXT = 0.25
-- small_spec.lua -- BetterBags Next's small mode (docs/next-small-mode.md): smaller, movable panels
-- that keep Next's look, for smaller screens, switched to and from the full panels with a button,
-- animated. Run on the real backpack and bank panels.
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
  bagSystem = trackStub("BagSystem"),
}

local replaced = {}
local function override(tbl, key, value)
  table.insert(replaced, { tbl, key, rawget(tbl, key) })
  tbl[key] = value
end

-- countCalls counts the calls to obj's method, put back after the test (override), and returns a reader of the count.
-- Never spy.on a panel's method: luassert's spy deep-copies every call's arguments, and a panel's first is the panel, the
-- whole mocked UI behind it (over 100 MB a call; the suite outgrew CI's 4 GB limit on two such calls).
---@param obj table
---@param method string
---@return fun(): number
local function countCalls(obj, method)
  local calls, original = 0, obj[method]
  override(obj, method, function(...)
    calls = calls + 1
    return original(...)
  end)
  return function() return calls end
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
-- The classic bags' anchor (frames/anchor.lua), whose square a small bag's anchor shows (docs/next-bag-anchor.md); it saves
-- the classic anchor's place with LibWindow-1.1.
local libWindow = LibStub:NewLibrary("LibWindow-1.1", 1) or LibStub("LibWindow-1.1")
libWindow.RegisterConfig = libWindow.RegisterConfig or function() end
libWindow.RestorePosition = libWindow.RestorePosition or function() end
libWindow.SavePosition = libWindow.SavePosition or function() end
local modules = { { "Anchor", "frames/anchor.lua" }, { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextFrameArt", "next/frameart.lua" }, { "NextFill", "next/fill.lua" }, { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" },
  { "NextSparkles", "next/sparkles.lua" }, { "NextLift", "next/lift.lua" }, { "NextTabs", "next/tabs.lua" }, { "NextContent", "next/content.lua" },
  { "NextDockCard", "next/dockcard.lua" }, { "NextDock", "next/dock.lua" }, { "NextDrag", "next/drag.lua" }, { "NextChain", "next/chain.lua" }, { "NextUIPanels", "next/uipanels.lua" }, { "NextOrnaments", "next/ornaments.lua" }, { "NextMenuButton", "next/menubutton.lua" }, { "NextGlitch", "next/glitch.lua" }, { "NextRain", "next/rain.lua" }, { "NextShatter", "next/shatter.lua" }, { "NextSnow", "next/snow.lua" }, { "NextThreads", "next/threads.lua" }, { "NextSmoke", "next/smoke.lua" }, { "NextBats", "next/bats.lua" }, { "NextBeam", "next/beam.lua" }, { "NextStopMotion", "next/stopmotion.lua" }, { "NextPaper", "next/paper.lua" }, { "NextGlass", "next/glass.lua" }, { "NextSheen", "next/sheen.lua" }, { "NextPanel", "next/panel.lua" },
  { "Currencies", "data/currencies.lua" }, { "NextCurrencyEntry", "next/currencyentry.lua" },
  { "NextCurrencyDrag", "next/currencydrag.lua" },
  { "NextCurrencyTracker", "next/currencytracker.lua" }, { "NextCurrencyStrip", "next/currencystrip.lua" }, { "NextBag", "next/bag.lua" }, { "NextBank", "next/bank.lua" } }
for _, m in ipairs(modules) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local nextBag = addon:GetModule("NextBag")
local nextBank = addon:GetModule("NextBank")
local nextPanel = addon:GetModule("NextPanel")
local nextDrag = addon:GetModule("NextDrag")
local chain = addon:GetModule("NextChain")
local style = addon:GetModule("NextStyle")
local tween = addon:GetModule("NextTween")
local pixel = addon:GetModule("NextPixel")
local render = addon:GetModule("Render")
local motion = addon:GetModule("Motion")
local context = addon:GetModule("Context")
local scrollbox = addon:GetModule("Scrollbox")

local SECTION_GRID = 2

describe("BetterBags Next's small mode", function()
  local db, sent, buttons, slots, placed

  local function ctx() return context:New("spec") end

  local function finishTweens()
    for _ = 1, 400 do
      local update = tween.driver and tween.driver:GetScript("OnUpdate")
      if update == nil then return end
      update(tween.driver, 0.05)
    end
  end

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

  -- The small panel's height on this screen, and the frame's top left in UIParent's units.
  local function smallHeight()
    return math.floor(UIParent:GetHeight() * style.Small.Height)
  end

  local function topLeft(panel)
    local point, rel, relPoint, x, y = panel.frame:GetPoint(1)
    assert.are.same({ "TOPLEFT", UIParent, "BOTTOMLEFT" }, { point, rel, relPoint })
    return x, y
  end

  -- cornerFor is the corner saved for a small panel whose top left is x, y on the screen and that was placed by its title
  -- (docs/next-bag-anchor.md): its bottom left, or bottom right, on the half of the screen its middle is on (or side), at its
  -- size on the screen now.
  local function cornerFor(panel, x, y, side)
    local s = panel.frame:GetScale()
    local w, h = panel.frame:GetWidth() * s, panel.frame:GetHeight() * s
    side = side or (x + w / 2 < UIParent:GetWidth() / 2 and "LEFT" or "RIGHT")
    return { side == "RIGHT" and x + w or x, y - h, side, "BOTTOM" }
  end

  before_each(function()
    UseNextCurrencies(stubs.database, override)
    render:Init()
    tween:Init()
    motion:Init()
    nextDrag:Init()
    chain:Init()
    sent, buttons, placed = {}, {}, {}
    db = { size = "small", places = {}, corners = {}, anchors = {}, sizes = {}, smallChain = "apart",
      view = { [BACKPACK] = SECTION_GRID, [BANK] = SECTION_GRID }, active = { [BACKPACK] = 1, [BANK] = 10 } }
    slots = {
      [BACKPACK] = { sortedItems = {}, tabs = { [1] = { categories = { { name = "Herbs" } }, items = { item("0_1", "Herbs") } } } },
      [BANK] = { sortedItems = {}, tabs = { [10] = { categories = { { name = "Ore" } }, items = { item("6_1", "Ore") } } } },
    }
    UIParent:_SetRect(0, 0, 1920, 1200)
    override(addon, "isRetail", true)
    override(addon, "isForever", false)
    override(addon, "hasWarbank", true)
    override(addon, "atBank", false)
    override(const, "BANK_TAB", { BANK = -2, ACCOUNT_BANK_1 = 12 })
    override(const, "BAG_VIEW", { SECTION_GRID = SECTION_GRID, SECTION_ALL_BAGS = 4 })
    override(const, "ACCOUNT_BANK_BAGS", { [12] = 12 })
    override(stubs.L, "G", function(_, key) return key end)
    override(stubs.itemFrame, "GetButton", function(_, _, slotkey)
      buttons[slotkey] = buttons[slotkey] or fakeButton(slotkey)
      return buttons[slotkey]
    end)
    override(stubs.items, "GetAllSlotInfo", function() return slots end)
    override(stubs.items, "ExpireRecentItems", function() return false end)
    override(stubs.items, "ClearBankCache", function() end)
    override(stubs.database, "GetNextSize", function() return db.size end)
    override(stubs.database, "GetNextSectionColumns", function() return 1 end)
    override(stubs.database, "GetNextSectionFill", function() return "across" end)
    override(stubs.database, "GetNextSectionSpan", function() return false end)
    override(stubs.database, "GetNextSectionCompact", function() return false end)
    override(stubs.database, "GetNextSectionWideRows", function() return 2 end)
    override(stubs.database, "SetNextSize", function(_, size) db.size = size end)
    -- Where a small panel was left before it held its bottom corner (docs/next-bag-anchor.md): its top left, taken over the
    -- first time it shows.
    override(stubs.database, "GetNextSmallPlace", function(_, kind)
      local p = db.places[kind]
      if p then return p[1], p[2] end
    end)
    override(stubs.database, "ClearNextSmallPlace", function(_, kind) db.places[kind] = nil end)
    -- The corner it holds, and its anchor (docs/next-bag-anchor.md).
    override(stubs.database, "GetNextSmallCorner", function(_, kind)
      local c = db.corners[kind]
      if c then return c[1], c[2], c[3], c[4] or "BOTTOM" end
    end)
    override(stubs.database, "SetNextSmallCorner", function(_, kind, x, y, side, edge)
      db.corners[kind] = { x, y, side, edge }
    end)
    override(stubs.database, "GetNextAnchorState", function(_, kind) return db.anchors[kind] or "free" end)
    override(stubs.database, "SetNextAnchorState", function(_, kind, state)
      db.anchors[kind] = state ~= "free" and state or nil
    end)
    override(stubs.database, "GetNextSmallSize", function(_, kind)
      local size = db.sizes[kind]
      if size then return size[1], size[2] end
    end)
    override(stubs.database, "SetNextSmallSize", function(_, kind, w, h)
      db.sizes[kind] = w ~= nil and { w, h } or nil
    end)
    override(stubs.database, "GetNextSmallChain", function() return db.smallChain end)
    override(stubs.database, "SetNextSmallChain", function(_, layout) db.smallChain = layout end)
    override(stubs.database, "GetNextChain", function() return "apart" end)
    -- Clamp Bags to Screen (window.md §3a): on here, so a small panel stays on the screen; off by default.
    db.clamp = true
    override(stubs.database, "GetClampBagsToScreen", function() return db.clamp end)
    -- The Size tab's scales (docs/next-appearance-size.md), in percent.
    db.iconScale, db.bagScale = 100, 100
    override(stubs.database, "GetNextIconScale", function() return db.iconScale end)
    override(stubs.database, "GetNextBagScale", function() return db.bagScale end)
    -- Fit Names While Open (next.md §14g): off by default.
    db.fitNames = false
    override(stubs.database, "GetNextFitNamesWhileOpen", function() return db.fitNames end)
    -- Autosize Bags (next-small-autosize.md): on by default, off here, so the specs of sizes the player gives see them;
    -- "autosizing its height" turns it on.
    db.autosize = false
    override(stubs.database, "GetNextAutosize", function() return db.autosize end)
    -- No tab order saved (docs/next-batch-2.md §5).
    override(stubs.database, "GetNextTabOrder", function() return {} end)
    override(stubs.database, "GetGroupsEnabled", function() return false end)
    override(stubs.database, "GetActiveGroup", function(_, kind) return db.active[kind] end)
    override(stubs.database, "SetActiveGroup", function(_, kind, id) db.active[kind] = id end)
    override(stubs.database, "GetInBagSearch", function() return true end)
    override(stubs.database, "GetShowBankTabs", function() return false end)
    override(stubs.database, "GetBagView", function(_, kind) return db.view[kind] end)
    override(stubs.database, "SetBagView", function(_, kind, view) db.view[kind] = view end)
    override(stubs.groups, "GetAllGroups", function() return {} end)
    override(stubs.groups, "GetGroup", function(_, kind, id)
      if kind == BANK and id == 10 then return { id = 10, name = "Bank", bankType = 1, isDefault = true } end
    end)
    override(stubs.groups, "GetDefaultBankGroup", function() return { id = 10, name = "Bank", bankType = 1, isDefault = true } end)
    override(stubs.groups, "IsDefaultGroup", function() return true end)
    override(stubs.events, "SendMessage", function(_, _, name, opts) table.insert(sent, { name, opts }) end)
    override(stubs.events, "RegisterMessage", function() end)
    override(stubs.events, "RegisterEvent", function() end)
    override(stubs.events, "BucketEvent", function() end)
    override(stubs.searchBox, "CreateBox", function(_, kind, parent)
      local box = { kind = kind, frame = CreateFrame("Frame", nil, parent) }
      box.textBox = CreateFrame("EditBox", nil, box.frame, "BagSearchBoxTemplate")
      box.helpText = box.textBox.Instructions
      return box
    end)
    override(stubs.sonata, "UnregisterElement", function() end)
    override(stubs.money, "Create", function()
      return { frame = CreateFrame("Frame"), Update = function() end }
    end)
    override(stubs.cursorPlacement, "PlaceCursorItem", function(_, kind) table.insert(placed, kind) return "placed" end)
    override(stubs.backpackBehavior, "Create", function() return {} end)
    override(stubs.bankBehavior, "SuppressBlizzardBankPanel", function() end)
    override(stubs.bankBehavior, "proto", { UpdatePurchaseBankButton = function() end })
    override(stubs.bankSlots, "GetBagSocketIndex", function() return nil end)
    override(C_Bank, "FetchPurchasedBankTabData", function() return {} end)
    override(C_Bank, "FetchNextPurchasableBankTabData", function() return nil end)
    override(C_Bank, "CloseBankFrame", function() end)
    override(addon, "SetBlizzardBankType", function() end)
    override(addon, "TriggerItemContextChanged", function() end)
    override(addon, "ForceHideBlizzardBags", function() end)
    override(_G, "PlaySound", function() end)
    override(_G, "InCombatLockdown", function() return false end)
    _G._cursorHasItem = false
    _G._cursorType = nil
  end)

  after_each(function()
    restore()
    _G._cursorHasItem = false
    _G._cursorType = nil
  end)

  teardown(function()
    for i = #modules, 1, -1 do ResetModuleStub(modules[i][1]) end
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  describe("a small panel", function()
    it("is the body alone, a share of the screen tall, the backpack on the right by default", function()
      local bag = nextBag:Create(ctx())
      assert.are.equal(style.BODY_WIDTH, bag.frame:GetWidth())
      assert.are.equal(smallHeight(), bag.frame:GetHeight())
      local x, y = topLeft(bag)
      assert.are.equal(UIParent:GetWidth() - style.BODY_WIDTH - style.Small.Margin, x)
      assert.are.equal((UIParent:GetHeight() + smallHeight()) / 2, y)
    end)

    it("puts a companion on the left by default", function()
      local bank = nextBank:Create(ctx())
      local x, y = topLeft(bank)
      assert.are.equal(style.Small.Margin, x)
      assert.are.equal((UIParent:GetHeight() + smallHeight()) / 2, y)
    end)

    it("has no feathered edge: its body is the whole frame, and it takes clicks everywhere", function()
      local bag = nextBag:Create(ctx())
      assert.is_false(bag.feather:IsShown())
      assert.are.same({ 0, 0, 0, 0 }, { bag.frame:GetHitRectInsets() })
      assert.are.same({ "TOPLEFT", bag.frame, "TOPLEFT", 0, 0 }, { bag.body:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", bag.frame, "BOTTOMRIGHT", 0, 0 }, { bag.body:GetPoint(2) })
      assert.are.same({ "TOPLEFT", bag.frame, "TOPLEFT", 0, 0 }, { bag.fill:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", bag.frame, "BOTTOMRIGHT", 0, 0 }, { bag.fill:GetPoint(2) })
      assert.is_false(bag.outerFeather:IsShown())
    end)

    it("draws a faint lavender edge all round, which the full panel has not", function()
      local bag = nextBag:Create(ctx())
      assert.are.equal(4, #bag.edges)
      local l = style.Color.Lavender
      for _, edge in ipairs(bag.edges) do
        assert.is_true(edge:IsShown())
        local r, g, b, a = edge:GetVertexColor()
        assert.are.same({ l[1], l[2], l[3], style.Small.Edge }, { r, g, b, a })
      end
      db.size = "full"
      local full = nextBank:Create(ctx())
      for _, edge in ipairs(full.edges) do assert.is_false(edge:IsShown()) end
    end)

    it("has a shorter beam", function()
      local bag = nextBag:Create(ctx())
      assert.are.equal(style.Small.Ribbon, bag.ribbonLength)
      for _, line in ipairs(bag.ribbonLines) do assert.are.equal(style.Small.Ribbon, line:GetWidth()) end
    end)

    -- Sparkles are born where the panel's parts are: the backpack's inner side is its left edge.
    it("sends its edge sparkles out of its inner side, and its ribbon sparkles along its ribbon", function()
      local bag = nextBag:Create(ctx())
      for _ = 1, 20 do
        local x = bag.edgeSparkles.options.Spawn()
        assert.is_true(x <= 0 and x >= -24, "edge sparkle at " .. x)
        local rx = bag.sparkles.options.Spawn()
        -- The ribbon starts at the body's left edge: the title is PAD + 4 in, the join PAD + 4 out.
        assert.is_true(rx <= 0 and rx >= -bag.sparkSpread, "ribbon sparkle at " .. rx)
      end
      local bank = nextBank:Create(ctx())
      for _ = 1, 20 do
        local x = bank.edgeSparkles.options.Spawn()
        assert.is_true(x >= style.BODY_WIDTH and x <= style.BODY_WIDTH + 24, "bank edge sparkle at " .. x)
      end
    end)

    it("hands its content the room between its header and its footer", function()
      local bag = nextBag:Create(ctx())
      local pre = bag.root:PreRender()
      assert.are.equal(smallHeight() - style.CONTENT_TOP - style.FOOTER, pre.Height)
      local result = bag.root:Render()
      assert.are.same({ style.BODY_WIDTH, smallHeight() }, { result.Width, result.Height })
    end)

    -- A small panel's title has a width (FitTitle: cut short in the room its header buttons leave), and
    -- text is centered in its width unless justified otherwise (UI.xsd: justifyH defaults to CENTER):
    -- the backpack's title moved right of where it starts (reported: titles "shift right" in small
    -- mode, and sit where they should at full size, where the title is as wide as its text). It is
    -- justified toward the side it is anchored on, through a theme's restyle too.
    it("keeps its title where it starts, justified toward its anchor", function()
      local bag = nextBag:Create(ctx())
      assert.is_true(bag.title:GetWidth() > 0, "a small panel's title has a width")
      assert.are.equal("LEFT", bag.title:GetJustifyH())
      assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", style.PAD + style.TITLE_INSET + TEXT, -style.TITLE_TOP + TEXT },
        { bag.title:GetPoint(1) })
      bag.title:SetJustifyH("CENTER")
      bag:StyleParts()
      assert.are.equal("LEFT", bag.title:GetJustifyH())
      local bank = nextBank:Create(ctx())
      assert.are.equal("RIGHT", bank.title:GetJustifyH())
    end)

    it("opens where it was left, kept on the screen", function()
      db.places[BACKPACK] = { 300, 900 }
      local bag = nextBag:Create(ctx())
      assert.are.same({ 300, 900 }, { topLeft(bag) })
      db.places[BANK] = { -500, 5000 }
      local bank = nextBank:Create(ctx())
      assert.are.same({ 0, UIParent:GetHeight() }, { topLeft(bank) })
    end)
  end)

  -- It opens where it was left, coming a short way in from its edge side as it fades in, and leaves
  -- the same way (docs/next-small-mode.md, "A small panel").
  -- Most players play with detached panels (asked), and a panel let go snaps to what its icons need.
  describe("with section columns", function()
    local function sections(sizes)
      local categories, items, n = {}, {}, 0
      for name, size in pairs(sizes) do
        table.insert(categories, { name = name })
        for _ = 1, size do
          n = n + 1
          table.insert(items, item("0_" .. n, name))
        end
      end
      return { sortedItems = {}, tabs = { [1] = { categories = categories, items = items } } }
    end

    local function bagOf(sizes)
      override(stubs.database, "GetNextSectionColumns", function() return 2 end)
      local bag = nextBag:Create(ctx())
      bag:Show(ctx())
      finishTweens()
      bag:Draw(ctx(), sections(sizes), function() end)
      render:Flush()
      return bag
    end

    -- Found reviewing the defaults: every column as wide as the largest section left a bag of 14, 4 and 7 let go at 25 cells
    -- 25 wide, 11 empty beside its 14. Asked of one column: "if i drag the [bag too wide] it should shrink back down".
    describe("on the defaults, wide sections spanning columns", function()
      -- holding puts sections of as many items as each says in a bag, nothing held from what it showed before.
      local function holding(bag, list)
        local categories, items, n = {}, {}, 0
        for _, s in ipairs(list) do
          table.insert(categories, { name = s[1] })
          for _ = 1, s[2] do
            n = n + 1
            table.insert(items, item("0_" .. n, s[1]))
          end
        end
        bag.content:Settle()
        bag:Draw(ctx(), { sortedItems = {}, tabs = { [1] = { categories = categories, items = items } } }, function() end)
        render:Flush()
      end

      local function bagIn(list, wideRows, fill)
        override(stubs.database, "GetNextSectionColumns", function() return 2 end)
        override(stubs.database, "GetNextSectionSpan", function() return true end)
        override(stubs.database, "GetNextSectionWideRows", function() return wideRows or 2 end)
        override(stubs.database, "GetNextSectionFill", function() return fill or "across" end)
        local bag = nextBag:Create(ctx())
        bag:Show(ctx())
        finishTweens()
        holding(bag, list)
        return bag, bag:ContentRoom()
      end

      for _, fill in ipairs({ "across", "down" }) do
        it("shrinks to what a section spanning them and the rest need, filling " .. fill, function()
          local bag, room = bagIn({ { "A", 14 }, { "B", 4 }, { "C", 7 } }, 2, fill)
          local at = bag.content:RowWidth(14) + room
          assert.are.equal(at, bag:SnapWidth(bag.content:RowWidth(25) + room))
          assert.are.equal(at, bag:SnapWidth(at), "and stays there")
          assert.are.equal(2, bag.content:ColumnSplit(at - room).count, "its columns kept")
        end)
      end

      it("keeps side by side what stood side by side where it was let go", function()
        local bag, room = bagIn({ { "A", 3 }, { "B", 1 } })
        assert.are.equal(bag.content:RowWidth(6) + room, bag:SnapWidth(bag.content:RowWidth(20) + room))
      end)

      it("leaves a section as wide as a column where it is, by its own cells", function()
        local bag, room = bagIn({ { "A", 10 }, { "B", 9 }, { "C", 9 } })
        local at = bag.content:RowWidth(20) + room
        assert.are.equal(at, bag:SnapWidth(bag.content:RowWidth(25) + room))
        assert.are.equal(at, bag:SnapWidth(at))
      end)

      it("shares among the columns it spans what keeps a section beside another under the limit", function()
        override(stubs.database, "GetNextSectionColumns", function() return 3 end)
        local bag, room = bagIn({ { "A", 14 }, { "B", 3 } })
        override(stubs.database, "GetNextSectionColumns", function() return 3 end)
        bag.content:Invalidate()
        render:Flush()
        local at = bag.content:RowWidth(21) + room
        assert.are.equal(at, bag:SnapWidth(bag.content:RowWidth(30) + room))
        assert.are.equal(at, bag:SnapWidth(at))
      end)

      -- Alone in its row it can take the row, so nothing beside it asks for a column as wide as it.
      it("hugs a section alone in its row, an odd number of cells too", function()
        local bag, room = bagIn({ { "A", 5 }, { "B", 2 } })
        local at = bag.content:RowWidth(5) + room
        assert.are.equal(at, bag:SnapWidth(bag.content:RowWidth(8) + room))
        assert.are.equal(at, bag:SnapWidth(at))
        local lone, loneRoom = bagIn({ { "A", 11 } })
        local width = lone.content:RowWidth(11) + loneRoom
        assert.are.equal(width, lone:SnapWidth(lone.content:RowWidth(20) + loneRoom))
      end)

      it("hugs what keeps a lone section under a higher limit", function()
        local bag, room = bagIn({ { "A", 30 } }, 3)
        local at = bag.content:RowWidth(15) + room
        assert.are.equal(at, bag:SnapWidth(bag.content:RowWidth(20) + room))
        assert.are.equal(at, bag:SnapWidth(at))
      end)

      it("keeps a section alone in its row a column wide with wide sections off", function()
        local bag, room = bagIn({ { "A", 6 } })
        override(stubs.database, "GetNextSectionSpan", function() return false end)
        bag.content:Settle()
        assert.are.equal(bag.content:RowWidth(12) + room, bag:SnapWidth(bag.content:RowWidth(20) + room))
      end)

      it("keeps a section in its column filling down, though it stands alone in its row", function()
        local bag, room = bagIn({ { "A", 3 }, { "B", 10 }, { "C", 3 } }, 2, "down")
        local at = bag.content:RowWidth(20) + room
        assert.are.equal(at, bag:SnapWidth(bag.content:RowWidth(25) + room))
        assert.are.equal(at, bag:SnapWidth(at))
      end)

      -- Asked of compact sections: a bag let go too wide comes back to its widest row, every row as it stands.
      it("snaps compact sections to their widest row, and stays there", function()
        local bag, room = bagIn({ { "A", 1 }, { "B", 1 }, { "C", 3 } })
        override(stubs.database, "GetNextSectionCompact", function() return true end)
        bag.content:Settle()
        local at = bag.content:RowWidth(5) + room
        assert.are.equal(at, bag:SnapWidth(bag.content:RowWidth(20) + room))
        assert.are.equal(at, bag:SnapWidth(at))
      end)

      it("keeps every compact row through a grip let go too wide, and a press that moves nothing", function()
        finally(dofile("spec/helpers/layout.lua").UseScreen(3396, 1362, 0.65))
        local bag = bagIn({ { "A", 1 }, { "B", 1 }, { "C", 3 } })
        override(stubs.database, "GetNextSectionCompact", function() return true end)
        bag.content:Invalidate()
        render:Flush()
        local room = bag:ContentRoom()
        local function rows()
          local c = bag.content.byName
          return { c.A.x, c.A.y, c.B.x, c.B.y, c.C.x, c.C.y }
        end
        local before = rows()
        local snapped = bag.content:RowWidth(5) + room
        bag:StartSizing("RIGHT")
        bag.frame:SetSize(bag.content:RowWidth(20) + room, bag.frame:GetHeight())
        bag:Resized()
        render:Flush()
        bag:StopSizing()
        finishTweens()
        render:Flush()
        assert.are.same(before, rows())
        assert.is_true(math.abs(snapped - bag:SmallWidth()) < 1)
        local width = bag:SmallWidth()
        bag:StartSizing("RIGHT")
        bag:Resized()
        render:Flush()
        bag:StopSizing()
        finishTweens()
        render:Flush()
        assert.are.same(before, rows())
        assert.are.equal(width, bag:SmallWidth())
      end)

      -- Found by the bug review: the snap packed afresh, and a section that had lost items since would come in a cell.
      it("moves nothing on a press of a grip, when compact sections no longer stand as a fresh layout would", function()
        finally(dofile("spec/helpers/layout.lua").UseScreen(3396, 1362, 0.65))
        local bag = bagIn({ { "A", 8 }, { "B", 4 } })
        override(stubs.database, "GetNextSectionCompact", function() return true end)
        override(stubs.database, "GetNextSectionSpan", function() return false end)
        bag.content:Invalidate()
        render:Flush()
        local slotInfo = { sortedItems = {}, tabs = { [1] = { categories = { { name = "A" }, { name = "B" } },
          items = { item("0_1", "A"), item("0_2", "A"), item("0_9", "B"), item("0_10", "B"), item("0_11", "B"), item("0_12", "B") } } } }
        local width = bag:SmallWidth()
        bag:Draw(ctx(), slotInfo, function() end)
        render:Flush()
        local xB = bag.content.byName.B.x
        bag:StartSizing("RIGHT")
        bag:Resized()
        render:Flush()
        bag:StopSizing()
        finishTweens()
        render:Flush()
        assert.are.equal(width, bag:SmallWidth())
        assert.are.equal(xB, bag.content.byName.B.x)
      end)

      -- A width let go at snaps to one the snap leaves alone, the same number of columns, never wider, for any bag.
      it("snaps to a width it stays at, its columns kept, across random bags", function()
        local count, wideRows, fill = 2, 2, "across"
        local bag, room = bagIn({ { "S1", 1 } })
        override(stubs.database, "GetNextSectionColumns", function() return count end)
        override(stubs.database, "GetNextSectionWideRows", function() return wideRows end)
        override(stubs.database, "GetNextSectionFill", function() return fill end)
        for seed = 1, 200 do
          math.randomseed(seed)
          count, wideRows, fill = math.random(2, 4), math.random(2, 4), seed % 2 == 0 and "across" or "down"
          local list = {}
          for i = 1, math.random(1, 8) do
            list[i] = { "S" .. i, math.random() < 0.2 and math.random(10, 40) or math.random(1, 6) }
          end
          holding(bag, list)
          local width = math.max(bag:MinWidth(), bag.content:RowWidth(math.random(count * 2, 30)) + room + math.random() * 40)
          local to = bag:SnapWidth(width)
          local before, after = bag.content:ColumnSplit(width - room), bag.content:ColumnSplit(to - room)
          assert.are.equal(before and before.count or 1, after and after.count or 1, "columns, seed " .. seed)
          assert.is_true(math.abs(to - bag:SnapWidth(to)) < 1e-6, "stays there, seed " .. seed)
          assert.is_true(to <= width + 1e-6, "never wider, seed " .. seed)
        end
      end)

      it("never adds cells a section spanning them would like", function()
        local bag, room = bagIn({ { "A", 30 } })
        local width = bag.content:RowWidth(20) + room
        assert.are.equal(width, bag:SnapWidth(width))
      end)

      it("keeps two cells a column for what needs fewer", function()
        local bag, room = bagIn({ { "A", 1 }, { "B", 1 } })
        assert.are.equal(4, bag.content:PerRow(bag:SnapWidth(bag.content:RowWidth(20) + room) - room))
      end)
    end)

    it("snaps to what its columns need: two columns of its largest section", function()
      local bag = bagOf({ A = 3, B = 1 })
      local room = bag:ContentRoom()
      local at = bag.content:RowWidth(6) + room
      assert.are.equal(at, bag:SnapWidth(bag.content:RowWidth(20) + room))
    end)

    it("snaps to no fewer cells than keep its columns", function()
      local bag = bagOf({ A = 1, B = 1 })
      local room = bag:ContentRoom()
      local snapped = bag:SnapWidth(bag.content:RowWidth(20) + room)
      assert.are.equal(4, bag.content:PerRow(snapped - room))
    end)

    -- Found by the adversarial review: a whole-pixel frame can be a fraction under the width its columns take, and
    -- the snap read that as a cell fewer. Asked: "never normalize such that the column count changes away from the user".
    for _, screen in ipairs({ { 1920, 1080, 0.64 }, { 3396, 1362, 0.65 } }) do
      it(string.format("keeps its columns through a press on a grip that moves nothing, at %dx%d", screen[1], screen[2]), function()
        local undo = dofile("spec/helpers/layout.lua").UseScreen(screen[1], screen[2], screen[3])
        finally(undo)
        for _, cells in ipairs({ 6, 7, 8, 9, 10, 11 }) do
          local bag = bagOf({ A = 30, B = 30, C = 30 })
          override(stubs.database, "GetNextSectionColumns", function() return 3 end)
          local room = bag:ContentRoom()
          bag:StartSizing("RIGHT")
          bag.frame:SetSize(bag.content:RowWidth(cells) + room + 7, bag.frame:GetHeight())
          bag:Resized()
          render:Flush()
          bag:StopSizing()
          finishTweens()
          render:Flush()
          local held, width = bag.content.grid.cells, bag:SmallWidth()
          for _ = 1, 3 do
            bag:StartSizing("RIGHT")
            bag:Resized()
            render:Flush()
            assert.are.equal(held, bag.content.grid.cells, "while it is pressed")
            bag:StopSizing()
            finishTweens()
            render:Flush()
            assert.are.equal(held, bag.content.grid.cells, cells .. " cells")
            assert.are.equal(width, bag:SmallWidth())
          end
          bag:Hide(ctx())
          finishTweens()
        end
      end)
    end

    it("still lays out for what the player sees a whole pixel from the width it rests at", function()
      local undo = dofile("spec/helpers/layout.lua").UseScreen(1920, 1080, 0.64)
      finally(undo)
      local bag = bagOf({ A = 30, B = 30 })
      local resting = bag:RestingLayoutWidth()
      local unit = bag:PixelUnit()
      bag:StartSizing("RIGHT")
      assert.are.equal(resting, bag:FrameLayoutWidth(resting - unit * 0.49))
      assert.are.equal(resting, bag:FrameLayoutWidth(resting + unit * 0.49))
      assert.are.equal(resting - unit, bag:FrameLayoutWidth(resting - unit))
      assert.are.equal(resting + unit, bag:FrameLayoutWidth(resting + unit))
      assert.are.equal(resting - unit * 0.51, bag:FrameLayoutWidth(resting - unit * 0.51))
      bag:StopSizing()
    end)

    -- Found by the adversarial review: sizing forgets where things stood, so the second column jumped hundreds of
    -- pixels the moment the grip was let go, with the window still wide behind it.
    it("glides its columns as it snaps, from where they stood when it was let go", function()
      local bag = bagOf({ A = 3, B = 1 })
      local room = bag:ContentRoom()
      bag:StartSizing("RIGHT")
      bag.frame:SetSize(bag.content:RowWidth(20) + room, bag.frame:GetHeight())
      bag:Resized()
      render:Flush()
      local B = bag.content.byName.B
      local before = B.x
      assert.is_true(before > 200)
      bag:StopSizing()
      render:Flush()
      local x0, _, x1 = motion:GetMove(B.frame)
      assert.is_not_nil(x0, "it is moving")
      assert.are.equal(before, x0)
      assert.are.equal(B.x, x1)
      assert.is_true(B.x < before)
      finishTweens()
      motion:Step(1)
    end)

    it("keeps the cells it was let go at when its sections fill them", function()
      local bag = bagOf({ A = 30, B = 30 })
      local room = bag:ContentRoom()
      local width = bag.content:RowWidth(9) + room
      assert.are.equal(width, bag:SnapWidth(width + 10))
    end)
  end)

  describe("opening and closing", function()
    local function offsetX(panel)
      local x = topLeft(panel)
      return x - panel.placeX
    end

    it("slides in from its edge side as it fades in, to its place", function()
      local bag = nextBag:Create(ctx())
      bag:Show(ctx())
      assert.are.equal(style.Small.Slide, offsetX(bag), "the backpack comes from the right")
      assert.are.equal(0, bag.frame:GetAlpha())
      finishTweens()
      assert.are.equal(0, offsetX(bag))
      assert.are.equal(1, bag.frame:GetAlpha())
      local bank = nextBank:Create(ctx())
      bank:Show(ctx())
      assert.are.equal(-style.Small.Slide, offsetX(bank), "the bank comes from the left")
    end)

    it("slides back toward its edge side as it fades out, then hides", function()
      local bag = nextBag:Create(ctx())
      bag:Show(ctx())
      finishTweens()
      bag:Hide(ctx())
      assert.is_true(bag:IsClosing())
      finishTweens()
      assert.is_false(bag:IsShown())
      assert.are.equal(style.Small.Slide, offsetX(bag))
      assert.are.equal(0, bag.frame:GetAlpha())
    end)

    it("opens again from where it is when it was sliding out", function()
      local bag = nextBag:Create(ctx())
      bag:Show(ctx())
      finishTweens()
      bag:Hide(ctx())
      local update = tween.driver:GetScript("OnUpdate")
      update(tween.driver, style.Time.Close / 2)
      local partway = offsetX(bag)
      assert.is_true(partway > 0 and partway < style.Small.Slide)
      bag:Show(ctx())
      assert.are.equal(partway, offsetX(bag))
      finishTweens()
      assert.are.equal(0, offsetX(bag))
    end)

    it("takes the screen as it is when it opens: its height, and a place still on it", function()
      db.places[BACKPACK] = { 1400, 1100 }
      local bag = nextBag:Create(ctx())
      UIParent:_SetRect(0, 0, 1280, 720)
      bag:Show(ctx())
      finishTweens()
      assert.are.equal(math.floor(720 * style.Small.Height), bag.frame:GetHeight())
      assert.are.same({ 1280 - style.BODY_WIDTH, 720 }, { topLeft(bag) })
    end)

    -- The layout full mode saved (nextChain) is kept for full mode, and must not send a small bag
    -- off through its partner's edge, across the screen.
    it("closes toward its own edge side even with a chain layout saved", function()
      override(stubs.database, "GetNextChain", function() return "left" end)
      local bank = nextBank:Create(ctx())
      local bag = nextBag:Create(ctx())
      bank:Show(ctx())
      bag:Show(ctx())
      finishTweens()
      bag:Hide(ctx())
      finishTweens()
      assert.are.equal(bag:HiddenOffset(), bag.offset)
      assert.are.equal(style.Small.Slide, bag.offset)
    end)

    it("is never chained, nor waits for its partner", function()
      override(stubs.database, "GetNextChain", function() return "right" end)
      local bank = nextBank:Create(ctx())
      bank:Show(ctx())
      assert.is_false(bank.waiting)
      local bag = nextBag:Create(ctx())
      bag:Show(ctx())
      finishTweens()
      assert.is_nil((chain:Pair()))
      assert.are.equal(0, bank.offset)
      assert.are.equal("small", chain:Click(ctx(), bank))
      assert.are.equal("Drag to move it.", chain:Tooltip(bank))
    end)
  end)

  -- Dragging its title row (or the title) moves it, and each kind of bag keeps its place.
  describe("moving it", function()
    local function drag(panel, frame, left, top)
      frame = frame or panel.mover
      frame:GetScript("OnDragStart")(frame, "LeftButton")
      -- The client moves the frame with the mouse.
      panel.frame:_SetRect(left, top - panel.frame:GetHeight(), panel.frame:GetWidth(), panel.frame:GetHeight())
      frame:GetScript("OnDragStop")(frame)
    end

    local function opened(create)
      local panel = create(ctx())
      panel:Show(ctx())
      finishTweens()
      return panel
    end

    it("moves by its title row, saving its place for its kind and anchoring it there", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      assert.is_true(bag.mover:IsShown())
      assert.is_true(bag.frame:IsMovable())
      assert.is_true(bag.frame:IsClampedToScreen())
      drag(bag, nil, 600, 800)
      assert.is_false(bag.frame._moving)
      assert.are.same(cornerFor(bag, 600, 800), db.corners[BACKPACK])
      assert.are.same({ 600, 800 }, { topLeft(bag) })
      assert.is_nil(db.corners[BANK])
    end)

    it("does not let the client keep its place in its layout cache", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      bag.mover:GetScript("OnDragStart")(bag.mover, "LeftButton")
      assert.is_true(bag.frame._moving)
      assert.is_false(bag.frame:IsUserPlaced())
    end)

    it("moves by its title too", function()
      local bank = opened(function(c) return nextBank:Create(c) end)
      drag(bank, bank.titleButton, 100, 900)
      assert.are.same(cornerFor(bank, 100, 900), db.corners[BANK])
    end)

    it("keeps its place on the screen", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      drag(bag, nil, 1900, 1500)
      assert.are.same(cornerFor(bag, UIParent:GetWidth() - style.BODY_WIDTH, UIParent:GetHeight()), db.corners[BACKPACK])
    end)

    it("does not move with something on the cursor: pressing on it is a drop", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      _G._cursorType = "item"
      bag.mover:GetScript("OnDragStart")(bag.mover, "LeftButton")
      assert.is_nil(bag.frame._moving)
      bag.mover:GetScript("OnReceiveDrag")(bag.mover)
      bag.mover:GetScript("OnMouseUp")(bag.mover, "LeftButton")
      assert.are.same({ BACKPACK, BACKPACK }, placed)
    end)

    it("finishes opening before it moves", function()
      local bag = nextBag:Create(ctx())
      bag:Show(ctx())
      bag.mover:GetScript("OnDragStart")(bag.mover, "LeftButton")
      assert.is_false(tween:IsPlaying(bag))
      assert.are.equal(1, bag.frame:GetAlpha())
    end)

    it("stops moving when it hides", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      bag.mover:GetScript("OnDragStart")(bag.mover, "LeftButton")
      bag.frame:_SetRect(500, 100, bag.frame:GetWidth(), bag.frame:GetHeight())
      bag.frame:Hide()
      bag.frame:GetScript("OnHide")(bag.frame)
      assert.is_false(bag.frame._moving)
      assert.are.same(cornerFor(bag, 500, 100 + bag.frame:GetHeight()), db.corners[BACKPACK])
    end)

    it("keeps its header buttons clickable above the title row", function()
      local bag = nextBag:Create(ctx())
      for _, button in ipairs(bag.headerButtons) do
        assert.is_true(button:GetFrameLevel() > bag.mover:GetFrameLevel())
      end
      assert.is_true(bag.titleButton:GetFrameLevel() > bag.mover:GetFrameLevel())
    end)

    it("is kept on a screen that changes while it is open, its height the new screen's share", function()
      db.places[BACKPACK] = { 1400, 1100 }
      local bag = opened(function(c) return nextBag:Create(c) end)
      local renders = 0
      override(render, "Invalidate", function(_, d) if d == bag.root then renders = renders + 1 end end)
      UIParent:_SetRect(0, 0, 1280, 720)
      chain:Update(ctx(), true)
      assert.are.equal(math.floor(720 * style.Small.Height), bag.frame:GetHeight())
      assert.are.same({ 1280 - style.BODY_WIDTH, 720 }, { topLeft(bag) })
      assert.are.equal(1, renders, "its content is laid out again")
    end)

    it("does not move a full panel", function()
      db.size = "full"
      local bag = opened(function(c) return nextBag:Create(c) end)
      assert.is_false(bag.mover:IsShown())
      assert.is_false(bag.frame:IsMovable())
      assert.is_false(bag.frame:IsClampedToScreen())
      bag.titleButton:GetScript("OnDragStart")(bag.titleButton, "LeftButton")
      assert.is_nil(bag.frame._moving)
    end)
  end)

  -- Clamp Bags to Screen (asked: "a toggle of 'clamp bags to screen', and it should default to off ... an all
  -- bags setting"; window.md §3a). Off, a small panel goes where the player puts it, off the screen too, as WoW
  -- lets any frame, still on whole pixels; turned on, an open one is pulled back on the screen at once.
  describe("with Clamp Bags to Screen", function()
    local handlers

    local function opened(create)
      local panel = create(ctx())
      panel:Show(ctx())
      finishTweens()
      return panel
    end

    local function drag(panel, left, top)
      panel.mover:GetScript("OnDragStart")(panel.mover, "LeftButton")
      panel.frame:_SetRect(left, top - panel.frame:GetHeight(), panel.frame:GetWidth(), panel.frame:GetHeight())
      panel.mover:GetScript("OnDragStop")(panel.mover)
    end

    local function turned(on)
      db.clamp = on
      handlers["bags/ClampChanged"](ctx())
    end

    before_each(function()
      db.clamp = false
      handlers = {}
      override(stubs.events, "RegisterMessage", function(_, name, fn) handlers[name] = fn end)
    end)

    it("is not clamped while it is off, and goes where it is moved, off the screen too, on whole pixels", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      assert.is_false(bag.frame:IsClampedToScreen())
      drag(bag, 1900.4, 1500.3)
      assert.are.same(cornerFor(bag, 1900, 1500), db.corners[BACKPACK])
      assert.are.same({ 1900, 1500 }, { topLeft(bag) })
    end)

    it("opens where it was left, off the screen too", function()
      db.places[BANK] = { -500, 5000 }
      local bank = opened(function(c) return nextBank:Create(c) end)
      assert.are.same({ -500, 5000 }, { topLeft(bank) })
    end)

    -- It holds its bottom right (docs/next-bag-anchor.md): the corner stays, the new height grows up from it.
    it("stays where it is when the screen changes, its height the new screen's share over the corner it holds", function()
      db.places[BACKPACK] = { 1400, 1100 }
      local bag = opened(function(c) return nextBag:Create(c) end)
      local corner = cornerFor(bag, 1400, 1100)
      assert.are.same(corner, db.corners[BACKPACK])
      UIParent:_SetRect(0, 0, 1280, 720)
      chain:Update(ctx(), true)
      local h = math.floor(720 * style.Small.Height)
      assert.are.equal(h, bag.frame:GetHeight())
      assert.are.same({ corner[1] - style.BODY_WIDTH, corner[2] + h }, { topLeft(bag) })
    end)

    it("pulls an open panel back on the screen once turned on, and saves it there; a closed one as it opens", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      drag(bag, 1900, 1500)
      db.places[BANK] = { -500, 5000 }
      local bank = nextBank:Create(ctx())
      turned(true)
      local onScreen = { UIParent:GetWidth() - style.BODY_WIDTH, UIParent:GetHeight() }
      assert.is_true(bag.frame:IsClampedToScreen())
      assert.are.same(onScreen, { topLeft(bag) })
      assert.are.same(cornerFor(bag, onScreen[1], onScreen[2]), db.corners[BACKPACK], "where it was put back is where it stays")
      assert.is_true(bank.frame:IsClampedToScreen())
      assert.are.same({ -500, 5000 }, db.places[BANK], "a closed panel is not moved")
      assert.is_nil(db.corners[BANK])
      bank:Show(ctx())
      finishTweens()
      assert.are.same({ 0, UIParent:GetHeight() }, { topLeft(bank) })
    end)

    it("moves nothing once turned off, and lets the panel go", function()
      db.clamp = true
      db.places[BACKPACK] = { 300, 900 }
      local bag = opened(function(c) return nextBag:Create(c) end)
      assert.is_true(bag.frame:IsClampedToScreen())
      turned(false)
      assert.is_false(bag.frame:IsClampedToScreen())
      assert.are.same({ 300, 900 }, { topLeft(bag) })
      assert.are.same(cornerFor(bag, 300, 900), db.corners[BACKPACK])
    end)

    -- A smaller screen put it back on the screen without saving where (the player's place is kept for a
    -- bigger screen); turning the clamp off does not send it back there.
    it("leaves a panel the screen's edge put back where it is once turned off", function()
      db.clamp = true
      db.places[BACKPACK] = { 1400, 1100 }
      local bag = opened(function(c) return nextBag:Create(c) end)
      local corner = cornerFor(bag, 1400, 1100)
      UIParent:_SetRect(0, 0, 1280, 720)
      chain:Update(ctx(), true)
      local onScreen = { 1280 - style.BODY_WIDTH, 720 }
      assert.are.same(onScreen, { topLeft(bag) })
      turned(false)
      assert.are.same(onScreen, { topLeft(bag) })
      assert.are.same(corner, db.corners[BACKPACK])
    end)

    it("puts a chained bag back beside its anchor, where the anchor was put back", function()
      db.smallChain = "companion"
      db.places[BANK] = { -500, 900 }
      local bank = opened(function(c) return nextBank:Create(c) end)
      local bag = opened(function(c) return nextBag:Create(c) end)
      assert.are.equal(bank, chain:SmallAnchorOf(bag), "chained beside the bank")
      turned(true)
      assert.are.same({ 0, 900 }, { topLeft(bank) })
      local x, y = chain:ChainedPlace(bag, bank, 0, 900)
      local beside = { pixel:Snap(UIParent, x), pixel:Snap(UIParent, y) }
      assert.are.same(beside, { topLeft(bag) })
      -- Each saved on the side it held (a backpack never placed holds its own, the right).
      assert.are.same(cornerFor(bag, beside[1], beside[2], "RIGHT"), db.corners[BACKPACK])
      assert.are.same(cornerFor(bank, 0, 900, "LEFT"), db.corners[BANK])
    end)

    it("never clamps a full panel, which rests at its screen edge, nor moves it", function()
      db.size = "full"
      local bag = opened(function(c) return nextBag:Create(c) end)
      local width, height = bag.frame:GetWidth(), bag.frame:GetHeight()
      turned(true)
      assert.is_false(bag.frame:IsClampedToScreen())
      assert.are.same({ width, height }, { bag.frame:GetWidth(), bag.frame:GetHeight() })
      assert.is_nil(db.places[BACKPACK], "no small place saved")
    end)
  end)

  -- A grip on each bottom corner resizes a small panel, its content reflowing as it goes, like an
  -- element in a web page (asked: "a window handle when in minimized mode that lets users resize the
  -- window, dom like, just like the original bags ... static though, i.e. no snapping"; "both sides,
  -- but disable it on the side it's chained on"; "remember what the custom window sizing is"; a
  -- tooltip; "shift + left click the grip to reset to default size (animated, of course)").
  describe("resizing it", function()
    local function step(seconds)
      tween.driver:GetScript("OnUpdate")(tween.driver, seconds)
    end

    local function opened(create)
      local panel = create(ctx())
      panel:Show(ctx())
      finishTweens()
      return panel
    end

    local function press(grip)
      grip:GetScript("OnMouseDown")(grip, "LeftButton")
    end

    local function release(grip)
      grip:GetScript("OnMouseUp")(grip, "LeftButton")
    end

    -- The client sizes the frame with the mouse from the corner pressed, the opposite corner still;
    -- the frame says so (OnSizeChanged).
    local function sizeTo(panel, side, w, h)
      local f = panel.frame
      -- Where it is: the rect the client last gave it, else its anchor (the mock works out no rect
      -- from anchors).
      local left, top = f:GetLeft(), f:GetTop()
      if left == nil then
        left, top = topLeft(panel)
      end
      local right = left + f:GetWidth()
      f:_SetRect(side == "LEFT" and right - w or left, top - h, w, h)
      f:GetScript("OnSizeChanged")(f, w, h)
    end

    local function resize(panel, side, w, h)
      press(panel.grips[side])
      sizeTo(panel, side, w, h)
      release(panel.grips[side])
    end

    -- gripTo drags panel's grip on side until the panel is w wide, the corner across from it still, as the client does on a
    -- screen that lays the frames out from their anchors (spec/helpers/layout.lua's UseScreen), and lets go.
    local function gripTo(panel, side, w)
      local f = panel.frame
      local left, top = f:GetLeft(), f:GetTop()
      local right = left + f:GetWidth()
      press(panel.grips[side])
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", side == "LEFT" and right - w or left, top)
      f:SetSize(w, f:GetHeight())
      f:GetScript("OnSizeChanged")(f, w, f:GetHeight())
      release(panel.grips[side])
    end

    local function perRow(panel)
      local width = panel.root:PreRender().Width - panel.scroll:GetGutterWidth()
      local STEP = style.ICON + style.GAP
      return math.floor((width + style.GAP) / STEP)
    end

    -- The width a panel needs for n columns of icons: its padding, the scroll box's room for its bar on both
    -- sides, and the icons with the gaps between them.
    local function columnsWidth(n)
      return 2 * style.PAD + scrollbox:GutterWidthFor({ Symmetric = true }) + n * (style.ICON + style.GAP) - style.GAP
    end

    -- The narrowest grid step at least width wide (next.md §14g): whole cells of icons and the room beside them, a side
    -- rail's too.
    local function gridStep(width)
      local n = 1
      while columnsWidth(n) + style.RAIL < width - 1e-6 do n = n + 1 end
      return columnsWidth(n) + style.RAIL
    end

    describe("the grips", function()
      it("sits on both bottom corners of a small panel, there but unseen until the pointer is over it", function()
        local bag = nextBag:Create(ctx())
        local inset = style.Small.Grip.Inset
        assert.are.same({ "BOTTOMLEFT", bag.body, "BOTTOMLEFT", inset, inset }, { bag.grips.LEFT:GetPoint(1) })
        assert.are.same({ "BOTTOMRIGHT", bag.body, "BOTTOMRIGHT", -inset, inset }, { bag.grips.RIGHT:GetPoint(1) })
        for _, side in ipairs({ "LEFT", "RIGHT" }) do
          local grip = bag.grips[side]
          assert.is_true(grip:IsShown(), side)
          assert.is_true(grip:IsMouseEnabled(), side .. " is found by the pointer")
          assert.are.equal(0, grip:GetAlpha(), side .. " is unseen until hovered")
          assert.are.same({ style.Small.Grip.Size, style.Small.Grip.Size }, { grip:GetWidth(), grip:GetHeight() })
          assert.is_true(grip:GetFrameLevel() > bag.frame:GetFrameLevel())
        end
      end)

      it("has no grips at full size", function()
        db.size = "full"
        local bag = nextBag:Create(ctx())
        assert.is_false(bag.grips.LEFT:IsShown())
        assert.is_false(bag.grips.RIGHT:IsShown())
        assert.is_false(bag.frame:IsResizable())
      end)

      -- Blizzard's own resize button (FloatingChatFrame.xml): the size grabber, its highlight and
      -- its pressed art. The original bags draw the same.
      it("draws Blizzard's chat size grabber, turned around on the left corner", function()
        local bag = nextBag:Create(ctx())
        local right, left = bag.grips.RIGHT, bag.grips.LEFT
        assert.are.equal("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up", right:GetNormalTexture():GetTexture())
        assert.are.equal("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight", right:GetHighlightTexture():GetTexture())
        assert.are.equal("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down", right:GetPushedTexture():GetTexture())
        -- GetTexCoord gives the corners: upper left x first, upper right x fifth.
        for _, get in ipairs({ "GetNormalTexture", "GetHighlightTexture", "GetPushedTexture" }) do
          local c = { right[get](right):GetTexCoord() }
          assert.are.same({ 0, 1 }, { c[1], c[5] }, get)
          c = { left[get](left):GetTexCoord() }
          assert.are.same({ 1, 0 }, { c[1], c[5] }, get .. " mirrored")
        end
      end)

      -- Asked, after trying it: "can we auto-hide the handles so they only show on hover?" As the
      -- original bags' grip (window.lua, ShowOnHover), faded as Next's other hovers are.
      it("fades in while the pointer is over it, and out once it leaves", function()
        local bag = nextBag:Create(ctx())
        local grip = bag.grips.LEFT
        grip:GetScript("OnEnter")(grip)
        step(style.Time.Hover / 2)
        local a = grip:GetAlpha()
        assert.is_true(a > 0 and a < 1, "fading in: " .. a)
        finishTweens()
        assert.are.equal(1, grip:GetAlpha())
        assert.are.equal(0, bag.grips.RIGHT:GetAlpha(), "only the grip under the pointer")
        grip:GetScript("OnLeave")(grip)
        step(style.Time.Hover / 2)
        a = grip:GetAlpha()
        assert.is_true(a > 0 and a < 1, "fading out: " .. a)
        finishTweens()
        assert.are.equal(0, grip:GetAlpha())
      end)

      it("stays shown while it is dragged, the pointer over it or not, and fades once let go", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        local grip = bag.grips.RIGHT
        grip:GetScript("OnEnter")(grip)
        press(grip)
        grip:GetScript("OnLeave")(grip)
        finishTweens()
        assert.are.equal(1, grip:GetAlpha())
        release(grip)
        finishTweens()
        assert.are.equal(0, grip:GetAlpha())
      end)

      it("stays shown when let go with the pointer still over it", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        local grip = bag.grips.RIGHT
        grip:GetScript("OnEnter")(grip)
        press(grip)
        release(grip)
        finishTweens()
        assert.are.equal(1, grip:GetAlpha())
      end)

      it("keeps each grip as the pointer has it when a theme restyles them", function()
        local bag = nextBag:Create(ctx())
        local grip = bag.grips.LEFT
        grip:GetScript("OnEnter")(grip)
        finishTweens()
        bag:StyleParts()
        assert.are.equal(1, grip:GetAlpha())
        assert.are.equal(0, bag.grips.RIGHT:GetAlpha())
      end)

      it("shows them at all times for a theme whose grips do not hide", function()
        local G = {}
        for key, value in pairs(style.Small.Grip) do G[key] = value end
        G.ShowOnHover = false
        override(style.Small, "Grip", G)
        local bag = nextBag:Create(ctx())
        assert.are.equal(1, bag.grips.LEFT:GetAlpha())
        assert.are.equal(1, bag.grips.RIGHT:GetAlpha())
        bag.grips.LEFT:GetScript("OnEnter")(bag.grips.LEFT)
        bag.grips.LEFT:GetScript("OnLeave")(bag.grips.LEFT)
        finishTweens()
        assert.are.equal(1, bag.grips.LEFT:GetAlpha())
      end)

      it("shows them at once for a theme that stops hiding them, a fade out cut short", function()
        local bag = nextBag:Create(ctx())
        local grip = bag.grips.LEFT
        grip:GetScript("OnEnter")(grip)
        finishTweens()
        grip:GetScript("OnLeave")(grip)
        step(style.Time.Hover / 2)
        local G = {}
        for key, value in pairs(style.Small.Grip) do G[key] = value end
        G.ShowOnHover = false
        override(style.Small, "Grip", G)
        bag:StyleParts()
        assert.are.equal(1, grip:GetAlpha())
        finishTweens()
        assert.are.equal(1, grip:GetAlpha())
      end)

      it("says what it does when the pointer is over it", function()
        local bag = nextBag:Create(ctx())
        local grip = bag.grips.RIGHT
        grip:GetScript("OnEnter")(grip)
        assert.is_true(GameTooltip:IsOwned(grip))
        assert.are.equal("Resize", GameTooltip:GetText())
        local lines = {}
        for _, line in ipairs(GameTooltip.lines) do table.insert(lines, line.text) end
        assert.are.same({ "Drag to resize.", "Shift-click to reset to the default size." }, lines)
        grip:GetScript("OnLeave")(grip)
        assert.is_false(GameTooltip:IsShown())
      end)
    end)

    describe("dragging a grip", function()
      it("sizes it from the corner pressed, from where it was pressed", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        assert.is_true(bag.frame:IsResizable())
        press(bag.grips.RIGHT)
        assert.are.equal("BOTTOMRIGHT", bag.frame._sizing)
        assert.is_true(bag.frame._sizingFromMouse)
        release(bag.grips.RIGHT)
        press(bag.grips.LEFT)
        assert.are.equal("BOTTOMLEFT", bag.frame._sizing)
        release(bag.grips.LEFT)
      end)

      it("goes no smaller than its header, footer and one column need, nor larger than the screen", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        press(bag.grips.RIGHT)
        local b = bag.frame._resizeBounds
        assert.are.same({ bag:MinWidth(), bag:MinHeight(), UIParent:GetWidth(), UIParent:GetHeight() },
          { b.minWidth, b.minHeight, b.maxWidth, b.maxHeight })
        release(bag.grips.RIGHT)
        local row = 0
        for _, button in ipairs(bag.headerButtons) do
          if button:IsShown() then row = row + style.HEADER_BUTTON + style.HEADER_BUTTON_GAP end
        end
        row = row - style.HEADER_BUTTON_GAP
        -- Its whole title and a pixel (next.md §14g), on a grid step.
        local header = 2 * style.PAD + style.TITLE_INSET + row + 12 + bag.title:GetStringWidth() + bag:PixelUnit()
        local column = 2 * style.PAD + style.GUTTER + style.ICON
        assert.are.equal(gridStep(math.max(header, column)), bag:MinWidth())
        assert.are.equal(style.CONTENT_TOP + style.FOOTER + style.SECTION_HEADER + style.ICON, bag:MinHeight())
      end)

      -- The backpack's currencies took the free slots' place (currency.md).
      it("leaves room for the footer's currencies and money", function()
        local bag = nextBag:Create(ctx())
        bag.moneyFrame.frame:SetWidth(400)
        local footer = 2 * style.PAD + style.TITLE_INSET + bag.currencyStrip:MinWidth() + 12 + 400
        assert.is_true(bag.currencyStrip:MinWidth() > 0)
        assert.are.equal(gridStep(footer), bag:MinWidth())
      end)

      it("reflows its content at once as it is dragged", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        local invalidated = 0
        local invalidate = render.Invalidate
        override(render, "Invalidate", function(r, d)
          if d == bag.root then invalidated = invalidated + 1 end
          return invalidate(r, d)
        end)
        press(bag.grips.RIGHT)
        assert.is_true(bag.content.instant, "nothing glides to its place while the grip is dragged")
        sizeTo(bag, "RIGHT", 358, 600)
        assert.are.equal(1, invalidated)
        assert.are.equal(358 - 2 * style.PAD, bag.root:PreRender().Width)
        assert.are.equal(600 - style.CONTENT_TOP - style.FOOTER, bag.root:PreRender().Height)
        assert.are.equal(6, perRow(bag))
        sizeTo(bag, "RIGHT", 708, 600)
        assert.are.equal(13, perRow(bag))
        release(bag.grips.RIGHT)
        assert.is_false(bag.content.instant)
      end)

      it("keeps the height it is let go at and its columns' width, saved for its kind with its place", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        local x0, y0 = topLeft(bag)
        resize(bag, "RIGHT", 377, 640)
        assert.are.same({ columnsWidth(6), 640 }, db.sizes[BACKPACK])
        finishTweens()
        assert.are.same({ columnsWidth(6), 640 }, { bag.frame:GetWidth(), bag.frame:GetHeight() })
        assert.are.same({ x0, y0 }, { topLeft(bag) })
        -- The corner it holds (docs/next-bag-anchor.md): the bottom right it was left at, the side it held.
        assert.are.same({ x0 + columnsWidth(6), y0 - 640, "RIGHT", "BOTTOM" }, db.corners[BACKPACK])
        assert.is_nil(db.sizes[BANK])
      end)

      it("moves its left edge from the left grip, its right edge still", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        local x0, y0 = topLeft(bag)
        local right = x0 + bag.frame:GetWidth()
        resize(bag, "LEFT", 600, 500)
        local w = columnsWidth(10)
        assert.are.same({ right, y0 - 500, "RIGHT", "BOTTOM" }, db.corners[BACKPACK])
        finishTweens()
        assert.are.same({ right - w, y0 }, { topLeft(bag) })
        assert.are.equal(w, bag.frame:GetWidth())
      end)

      -- Cut short only where even the screen cannot hold it, or it is a secret ("keeping its names whole").
      it("fits its title in the room its header buttons leave, on one line, whole at its minimum", function()
        local bank = opened(function(c) return nextBank:Create(c) end)
        resize(bank, "LEFT", bank:MinWidth(), 500)
        local row = 0
        for _, button in ipairs(bank.headerButtons) do
          if button:IsShown() then row = row + style.HEADER_BUTTON + style.HEADER_BUTTON_GAP end
        end
        row = row - style.HEADER_BUTTON_GAP
        assert.are.equal(bank:MinWidth() - (style.PAD + style.TITLE_INSET) - (style.PAD + row) - 12, bank.title:GetWidth())
        assert.is_false(bank.title._wordWrap)
        assert.is_false(bank.title:IsTruncated(), "whole at its minimum")
        nextPanel:SetSize(ctx(), "full")
        finishTweens()
        assert.are.equal(bank.title:GetStringWidth(), bank.title:GetWidth(), "a full panel's title is as long as it is")
        assert.is_false(bank.title:IsTruncated())
      end)

      -- A theme that puts the header buttons down a side rail (Header.Buttons.Rail, docs/next-gw2-theme.md).
      describe("with its header buttons down a side rail", function()
        after_each(function()
          UseNextTheme(nil)
        end)

        local function railed()
          UseNextTheme({ Header = { Buttons = { Rail = { Width = 40, Top = 64, Gap = 6 } } } })
        end

        local function column(panel)
          local n = 0
          for _, button in ipairs(panel.headerButtons) do
            if button:IsShown() then n = n + 1 end
          end
          return n * style.HEADER_BUTTON + (n - 1) * 6
        end

        it("goes no narrower than the strip and its header, footer and column need", function()
          railed()
          local bag = opened(function(c) return nextBag:Create(c) end)
          local header = 2 * style.PAD + 40 + style.TITLE_INSET + 12 + bag.title:GetStringWidth() + bag:PixelUnit()
          local cells = 2 * style.PAD + 40 + style.GUTTER + style.ICON
          local currencies = 2 * style.PAD + 40 + style.TITLE_INSET + bag.currencyStrip:MinWidth() + 12
            + bag.moneyFrame.frame:GetWidth()
          assert.are.equal(40, style.RAIL)
          assert.are.equal(gridStep(math.max(header, cells, currencies)), bag:MinWidth())
          bag.moneyFrame.frame:SetWidth(400)
          local footer = 2 * style.PAD + 40 + style.TITLE_INSET + bag.currencyStrip:MinWidth() + 12 + 400
          assert.are.equal(gridStep(footer), bag:MinWidth())
        end)

        it("goes no shorter than its buttons down the strip need", function()
          railed()
          local bag = opened(function(c) return nextBag:Create(c) end)
          local content = style.CONTENT_TOP + style.FOOTER + style.SECTION_HEADER + style.ICON
          assert.are.equal(math.max(content, 64 + column(bag) + style.PAD), bag:MinHeight())
          UseNextTheme({ Header = { Buttons = { Rail = { Width = 40, Top = 600, Gap = 6 } } } })
          assert.are.equal(600 + column(bag) + style.PAD, bag:MinHeight(), "a strip whose buttons start low")
        end)

        -- A button pinned to a corner (Pinned) keeps its room in the title's row.
        it("keeps the title clear of a pinned button", function()
          UseNextTheme({ Header = { Buttons = { Rail = { Width = 40, Top = 64 },
            Pinned = { closeButton = { Point = "TOPRIGHT", X = -5, Y = -4 } } } } })
          local bank = opened(function(c) return nextBank:Create(c) end)
          resize(bank, "LEFT", bank:MinWidth(), 500)
          local pinned = style.HEADER_BUTTON + 5
          assert.are.equal(bank:MinWidth() - 40 - (style.PAD + style.TITLE_INSET) - style.PAD - pinned - 12, bank.title:GetWidth())
          local header = 2 * style.PAD + 40 + style.TITLE_INSET + pinned + 12 + style.Small.MinTitle
          assert.is_true(bank:MinWidth() >= math.ceil(header))
        end)

        -- Asked: the size button beside the X at the top right. Two pins along the top keep the title clear of the
        -- farther one, not of both added up; a pin at a bottom corner takes no room from it.
        it("keeps the title clear of its farthest pin along the top", function()
          UseNextTheme({ Header = { Buttons = { Rail = { Width = 40, Top = 64 }, Pinned = {
            closeButton = { Point = "TOPRIGHT", X = -4, Y = -4 },
            sizeButton = { Point = "TOPRIGHT", X = -40, Y = -4 },
            settingsButton = { Point = "BOTTOMRIGHT", X = -100, Y = 4 } } } } })
          -- The backpack: it has a size button (the bank has none).
          local bag = opened(function(c) return nextBag:Create(c) end)
          assert.is_true(bag.sizeButton:IsShown())
          resize(bag, "RIGHT", 500, 500)
          local room = 40 + style.HEADER_BUTTON
          assert.are.equal(bag:BodyWidth() - 40 - (style.PAD + style.TITLE_INSET) - style.PAD - room - 12, bag.title:GetWidth())
        end)

        -- A strip outside the body (Outside) is kept on the screen with it.
        it("keeps a strip outside its body on the screen", function()
          UseNextTheme({ Header = { Buttons = { Rail = { Width = 40, Top = 64, Outside = true } } } })
          local bag = opened(function(c) return nextBag:Create(c) end)
          local bank = opened(function(c) return nextBank:Create(c) end)
          assert.are.equal(40, select(1, bag:clampPlace(0, 500)), "the backpack's strip is on its left")
          local right = UIParent:GetWidth() - bank:SmallWidth() * bank:Scale()
          assert.are.equal(right - 40, select(1, bank:clampPlace(right, 500)), "the bank's on its right")
        end)

        it("leaves its title the whole header row, past the strip", function()
          railed()
          local bank = opened(function(c) return nextBank:Create(c) end)
          resize(bank, "LEFT", bank:MinWidth(), 500)
          assert.are.equal(bank:MinWidth() - 40 - (style.PAD + style.TITLE_INSET) - style.PAD - 12, bank.title:GetWidth())
        end)

        it("snaps to its widest row of icons with the strip beside them", function()
          railed()
          local bag = opened(function(c) return nextBag:Create(c) end)
          local list = {}
          for i = 1, 9 do table.insert(list, item("0_" .. i, "Herbs")) end
          slots[BACKPACK].tabs[1].items = list
          bag:Draw(ctx(), slots[BACKPACK], function() end)
          render:Flush()
          resize(bag, "RIGHT", columnsWidth(15) + 40, 500)
          finishTweens()
          assert.are.equal(columnsWidth(9) + 40, bag.frame:GetWidth())
        end)
      end)

      it("does not resize with something on the cursor: pressing a grip is a drop", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        _G._cursorType = "item"
        press(bag.grips.RIGHT)
        assert.is_nil(bag.frame._sizing)
        release(bag.grips.RIGHT)
        bag.grips.LEFT:GetScript("OnReceiveDrag")(bag.grips.LEFT)
        assert.are.same({ BACKPACK, BACKPACK }, placed)
      end)

      it("finishes opening before it resizes", function()
        local bag = nextBag:Create(ctx())
        bag:Show(ctx())
        press(bag.grips.RIGHT)
        assert.is_false(tween:IsPlaying(bag))
        assert.are.equal(1, bag.frame:GetAlpha())
      end)

      it("places its content at once while a grip is dragged, nothing gliding there", function()
        local herbs = {}
        for i = 1, 10 do table.insert(herbs, item("0_" .. i, "Herbs")) end
        slots[BACKPACK].tabs[1].items = herbs
        local bag = opened(function(c) return nextBag:Create(c) end)
        bag:Draw(ctx(), slots[BACKPACK], function() end)
        render:Flush()
        press(bag.grips.RIGHT)
        sizeTo(bag, "RIGHT", 358, 600)
        render:Flush()
        local _, _, _, x, y = buttons["0_7"].frame:GetPoint(1)
        assert.are.same({ 0, -(style.ICON + style.GAP) }, { x, y }, "the 7th icon starts the second row of 6")
        assert.is_nil(motion:GetMove(buttons["0_7"].frame))
        release(bag.grips.RIGHT)
      end)

      -- Only a grip's dragging reflows it: a size change of its own (a switch, which lays its content
      -- out at its end) does not.
      it("lays its content out only while a grip sizes it", function()
        db.size = "full"
        local bag = opened(function(c) return nextBag:Create(c) end)
        local renders = 0
        override(render, "Invalidate", function(_, d) if d == bag.root then renders = renders + 1 end end)
        nextPanel:SetSize(ctx(), "small")
        step(style.Time.Morph / 2)
        local before = renders
        bag.frame:GetScript("OnSizeChanged")(bag.frame, bag.frame:GetWidth(), bag.frame:GetHeight())
        assert.are.equal(before, renders)
      end)

      -- A press let go without sizing it keeps nothing: the default size still follows the screen.
      it("saves nothing for a press that does not size it", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        local w, h = bag.frame:GetWidth(), bag.frame:GetHeight()
        press(bag.grips.RIGHT)
        sizeTo(bag, "RIGHT", w + 0.2, h - 0.2)
        release(bag.grips.RIGHT)
        assert.is_nil(db.sizes[BACKPACK])
        assert.is_nil(db.places[BACKPACK])
        assert.are.same({ w, h }, { bag.frame:GetWidth(), bag.frame:GetHeight() })
      end)

      it("stops resizing when it hides, keeping the height it had and its columns' width", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        press(bag.grips.RIGHT)
        sizeTo(bag, "RIGHT", 400, 500)
        bag.frame:Hide()
        bag.frame:GetScript("OnHide")(bag.frame)
        assert.is_nil(bag.frame._sizing)
        assert.is_nil(bag.sizing)
        assert.are.same({ columnsWidth(6), 500 }, db.sizes[BACKPACK])
        assert.are.equal(columnsWidth(6), bag.frame:GetWidth(), "no glide while hidden")
        assert.is_false(bag.sizeGliding)
      end)
    end)

    -- Asked: let go, a panel snaps "to the nearest exact width needed to fit the columns the user released it at",
    -- "never normalize such that the column count changes away from the user"; then, shown a panel let go far wider
    -- than its icons (its widest row 14 of 25 columns): "if i drag the window to be too big like in that screenshot,
    -- it should shrink back down to where the icon is". The height stays where it is let go ("only X").
    describe("snapping to its icons", function()
      -- filled draws the tab a panel shows with a section of each size (tab 1: groups are off).
      local function filled(panel, sizes)
        local kind = panel.kind
        local tab = panel:GetCurrentTabID()
        local categories, list = {}, {}
        for s, n in ipairs(sizes) do
          local name = "S" .. s
          table.insert(categories, { name = name })
          for i = 1, n do table.insert(list, item(((kind == BANK and 6 or 0) + s) .. "_" .. i, name)) end
        end
        slots[kind].tabs[tab] = { categories = categories, items = list }
        panel:Draw(ctx(), slots[kind], function() end)
        render:Flush()
        return panel
      end

      local function backpack(sizes)
        return filled(opened(function(c) return nextBag:Create(c) end), sizes)
      end

      it("shrinks to its widest row of icons when let go, every row as it was", function()
        local bag = backpack({ 14, 4, 7 })
        resize(bag, "RIGHT", columnsWidth(25) + 20, 600)
        finishTweens()
        render:Flush()
        assert.are.same({ columnsWidth(14), 600 }, { bag.frame:GetWidth(), bag.frame:GetHeight() })
        assert.are.equal(14, perRow(bag), "the widest section still on one row")
        assert.are.same({ columnsWidth(14), 600 }, db.sizes[BACKPACK])
      end)

      it("keeps a section wider than it wrapping where it wrapped, never adding a column", function()
        local bag = backpack({ 20, 3 })
        resize(bag, "RIGHT", columnsWidth(12) + 30, 600)
        finishTweens()
        assert.are.equal(columnsWidth(12), bag.frame:GetWidth())
        resize(bag, "RIGHT", columnsWidth(13) - 1, 600)
        finishTweens()
        assert.are.equal(columnsWidth(12), bag.frame:GetWidth(), "a unit short of thirteen columns shows twelve")
        resize(bag, "RIGHT", columnsWidth(13), 600)
        finishTweens()
        assert.are.equal(columnsWidth(13), bag.frame:GetWidth(), "exactly thirteen stays")
      end)

      -- Asked: "if we have a default sized bag, if we drag just a bit bigger, but not big enough so icons move, and
      -- then let go, it will snap back to default size."
      it("snaps a default-sized panel dragged a little wider back to its default size, saving nothing", function()
        local bag = backpack({ 10 })
        local w, h = bag.frame:GetWidth(), bag.frame:GetHeight()
        assert.are.equal(columnsWidth(8), w, "the default is eight columns' width")
        resize(bag, "RIGHT", w + 30, h)
        finishTweens()
        assert.are.same({ w, h }, { bag.frame:GetWidth(), bag.frame:GetHeight() })
        assert.is_nil(db.sizes[BACKPACK], "the default size still follows the screen")
        assert.is_nil(db.places[BACKPACK])
        resize(bag, "RIGHT", w + 30, h - 100)
        assert.are.same({ w, h - 100 }, db.sizes[BACKPACK], "a new height alone is saved")
      end)

      it("hugs fewer icons than its default holds", function()
        local bag = backpack({ 5, 2 })
        resize(bag, "RIGHT", bag.frame:GetWidth() + 30, 600)
        finishTweens()
        assert.are.equal(math.max(bag:MinWidth(), columnsWidth(5)), bag.frame:GetWidth())
      end)

      -- Only a grip let go hugs its icons: its default width is the columns it holds, whatever it shows, so it does not
      -- change as items come and go.
      it("keeps its default width at its columns whatever it shows", function()
        local bag = backpack({ 3 })
        bag:FitSmall()
        assert.are.equal(columnsWidth(8), bag.frame:GetWidth())
        assert.are.equal(columnsWidth(8) - 2 * style.PAD, bag.root:PreRender().LayoutWidth)
      end)

      it("never goes narrower than its minimum, nor saves less", function()
        local bank = filled(opened(function(c) return nextBank:Create(c) end), { 1 })
        resize(bank, "LEFT", columnsWidth(12), 500)
        finishTweens()
        assert.are.equal(bank:MinWidth(), bank.frame:GetWidth())
        assert.are.same({ bank:MinWidth(), 500 }, db.sizes[BANK])
      end)

      it("snaps to the columns it shows while it shows no icons", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        resize(bag, "RIGHT", columnsWidth(7) + 20, 600)
        finishTweens()
        assert.are.equal(columnsWidth(7), bag.frame:GetWidth())
      end)

      -- The render recorder (render-recorder.md §2) gets each step of a grip sizing a panel and of its snap, to show in
      -- game where the client puts it and its icons while it is sized.
      it("gives the render recorder each step of a grip sizing it and of its snap, only while it records", function()
        local recorder, created = StubBetterBagsModule("RenderRecorder")
        local steps = {}
        override(recorder, "recording", false)
        override(recorder, "PanelSizing", function(_, panel, name) table.insert(steps, { panel, name }) end)
        finally(function()
          if created then ResetModuleStub("RenderRecorder") end
        end)
        local bag = backpack({ 14 })
        resize(bag, "RIGHT", columnsWidth(20), 600)
        finishTweens()
        assert.are.same({}, steps, "nothing while it does not record")
        recorder.recording = true
        press(bag.grips.RIGHT)
        sizeTo(bag, "RIGHT", columnsWidth(20), 600)
        render:Flush()
        release(bag.grips.RIGHT)
        step(style.Time.Snap / 2)
        finishTweens()
        local names = {}
        for _, s in ipairs(steps) do
          assert.are.equal(bag, s[1])
          if names[#names] ~= s[2] then table.insert(names, s[2]) end
        end
        assert.are.same({ "start", "resized", "rendered", "let go", "snap", "snapped" }, names)
      end)

      -- onScreen runs fn on the reporter's screen (3396x1362: a unit is 0.564 pixels at scale 1), then puts the
      -- screen back, whatever fn does.
      local function onScreen(fn)
        local saved = _G.GetPhysicalScreenSize
        _G.GetPhysicalScreenSize = function() return 3396, 1362 end
        local ok, err = pcall(fn)
        _G.GetPhysicalScreenSize = saved
        assert(ok, err)
      end

      local function wholePixels(frame, what)
        local unit = pixel:Unit(frame)
        for _, length in ipairs({ frame:GetWidth(), frame:GetHeight() }) do
          local px = length / unit
          assert.is_true(math.abs(px - math.floor(px + 0.5)) < 1e-6, what .. ": " .. px .. " pixels")
        end
      end

      -- Measured in game (texture-sharpening.md §5): while it snapped its scroll box's edge stood a fraction of a pixel
      -- off the grid each frame, and what the box clips was drawn stretched across that fraction (icons toward the far
      -- side moved up to a third of a pixel, the near side none), until it came to rest; a grip dragged sizes it in
      -- whole pixels, and showed none.
      it("sizes itself in whole pixels at every step of its snap, as a grip dragged does", function()
        onScreen(function()
          local bag = backpack({ 14, 4, 7 })
          resize(bag, "RIGHT", columnsWidth(25) + 20, 600)
          local steps = 0
          while bag.sizeGliding do
            step(1 / 60)
            wholePixels(bag.frame, "step " .. steps)
            steps = steps + 1
          end
          assert.is_true(steps > 10, "it snapped")
          assert.are.equal(pixel:Length(bag.frame, columnsWidth(14)), bag.frame:GetWidth())
        end)
      end)

      it("reflows as it is dragged again once a snap has ended", function()
        local bag = backpack({ 20 })
        resize(bag, "RIGHT", columnsWidth(7) + 20, 600)
        finishTweens()
        press(bag.grips.RIGHT)
        sizeTo(bag, "RIGHT", columnsWidth(10), 600)
        assert.are.equal(columnsWidth(10) - 2 * style.PAD, bag.root:PreRender().LayoutWidth)
        assert.are.equal(columnsWidth(10) - 2 * style.PAD, bag.root:PreRender().Width)
        release(bag.grips.RIGHT)
      end)

      -- The original bags' bounce (window.md §3b): past the target by a tenth of the distance (at most 10), then back.
      it("bounces past its icons' width and settles, as the original bags do", function()
        local bag = backpack({ 14 })
        local from, to = columnsWidth(25), columnsWidth(14)
        resize(bag, "RIGHT", from, 600)
        assert.is_true(bag.sizeGliding)
        step(style.Time.Snap * 0.65)
        assert.is_true(math.abs(bag.frame:GetWidth() - (to - 10)) < 0.01, "width " .. bag.frame:GetWidth())
        assert.are.equal(600, bag.frame:GetHeight(), "its height stays")
        finishTweens()
        assert.are.equal(to, bag.frame:GetWidth())
        assert.is_false(bag.sizeGliding)
      end)

      it("keeps its rows through the bounce, nothing reflowing", function()
        local bag = backpack({ 14 })
        local to = columnsWidth(14)
        resize(bag, "RIGHT", columnsWidth(25), 600)
        step(style.Time.Snap * 0.65)
        assert.is_true(bag.frame:GetWidth() < to, "past its width")
        assert.are.equal(to - 2 * style.PAD, bag.root:PreRender().Width)
        assert.are.equal(to - 2 * style.PAD, bag.root:PreRender().LayoutWidth)
        assert.are.equal(14, perRow(bag))
      end)

      it("moves the edge its grip moved: the left grip's left edge, its right edge still", function()
        local bag = backpack({ 14 })
        local x0, y0 = topLeft(bag)
        local right = x0 + bag.frame:GetWidth()
        local to = columnsWidth(14)
        resize(bag, "LEFT", columnsWidth(25), 600)
        step(style.Time.Snap * 0.65)
        assert.is_true(math.abs(select(1, topLeft(bag)) + bag.frame:GetWidth() - right) < 0.01, "the right edge still")
        assert.are.equal(y0, select(2, topLeft(bag)))
        finishTweens()
        assert.are.same({ right - to, y0 }, { topLeft(bag) })
        assert.are.same({ right, y0 - 600, "RIGHT", "BOTTOM" }, db.corners[BACKPACK])
      end)

      it("ends its snap at its width when anything else places or sizes it", function()
        local to = columnsWidth(14)
        local function snapping()
          local bag = backpack({ 14 })
          resize(bag, "RIGHT", columnsWidth(20), 600)
          step(0.05)
          assert.is_true(bag.sizeGliding)
          return bag
        end
        local bag = snapping()
        press(bag.grips.RIGHT)
        assert.are.equal(to, bag.frame:GetWidth(), "a grip pressed")
        assert.is_false(bag.sizeGliding)
        release(bag.grips.RIGHT)
        bag:Hide(ctx())
        finishTweens()
        bag = snapping()
        bag.mover:GetScript("OnDragStart")(bag.mover, "LeftButton")
        assert.are.equal(to, bag.frame:GetWidth(), "moved")
        bag.mover:GetScript("OnDragStop")(bag.mover)
        bag:Hide(ctx())
        finishTweens()
        bag = snapping()
        bag.frame:Hide()
        bag.frame:GetScript("OnHide")(bag.frame)
        assert.are.equal(to, bag.frame:GetWidth(), "hidden")
      end)

      it("keeps a chained bag's chained side still as it snaps", function()
        local bag = backpack({ 8 })
        local bank = filled(opened(function(c) return nextBank:Create(c) end), { 9 })
        db.smallChain = "backpack"
        chain:Update(ctx())
        finishTweens()
        local bagLeft = topLeft(bag)
        local bankRight = select(1, topLeft(bank)) + bank.frame:GetWidth()
        resize(bank, "LEFT", columnsWidth(15), 480)
        step(style.Time.Snap * 0.5)
        assert.is_true(math.abs(select(1, topLeft(bank)) + bank.frame:GetWidth() - bankRight) < 0.01, "on its way")
        finishTweens()
        assert.are.equal(columnsWidth(9), bank.frame:GetWidth())
        assert.are.equal(bankRight, select(1, topLeft(bank)) + columnsWidth(9))
        assert.are.equal(bagLeft, select(1, topLeft(bag)))
        assert.are.same({ chain:ChainedPlace(bank, bag, bag.placeX, bag.placeY) }, { topLeft(bank) })
      end)

      it("leaves a section waiting in a dock out of its widest row", function()
        local bag = backpack({ 14, 6 })
        bag.content:HoldOut(bag.content.byName.S1)
        resize(bag, "RIGHT", columnsWidth(20), 600)
        finishTweens()
        assert.are.equal(columnsWidth(6), bag.frame:GetWidth())
      end)

      -- The vendor lays its items out as cards (NextCanvas:SetCards).
      it("snaps a panel of cards to its widest row of cards", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        bag.content:SetCards(true)
        filled(bag, { 3 })
        local card = style.VENDOR_CARD_WIDTH + style.GAP
        local room = 2 * style.PAD + scrollbox:GutterWidthFor({ Symmetric = true })
        resize(bag, "LEFT", room + 5 * card - style.GAP + 20, 500)
        finishTweens()
        assert.are.equal(room + 3 * card - style.GAP, bag.frame:GetWidth())
      end)
    end)

    -- Asked: "we need to make sure this never happens by always have the bag width sit at the minimum step ... such that no
    -- text is truncated in bag title or section title". Reported with a screenshot: a backpack four cells wide in two
    -- columns, its title "Backp..." and "Miscellaneo... 2" cut short beside "Consumable 1". A small panel sits at the first
    -- grid step from the width the player chose at which neither its title nor any section's name is cut: as it opens, and
    -- where a grip let go snaps. With Fit Names While Open on it follows what it shows while open; off, the default, nothing
    -- changes its width while it is open ("with it disabled, behavior is as it is now").
    describe("keeping its names whole", function()
      local REPORTED = { { "Consumable", 1 }, { "Miscellaneous", 2 }, { "Trade Goods", 2 }, { "Quest", 1 } }
      -- 2 + 240 + 8 + 6 = 256 with its count: more than a column of four cells (194) or five (244), a column of six.
      local LONG = string.rep("n", 40)

      local function slotsOf(list)
        local categories, items, n = {}, {}, 0
        for _, s in ipairs(list) do
          table.insert(categories, { name = s[1] })
          for _ = 1, s[2] do
            n = n + 1
            table.insert(items, item("0_" .. n, s[1]))
          end
        end
        return { sortedItems = {}, tabs = { [1] = { categories = categories, items = items,
          freeSpace = { showAll = false, buttons = { { slotkey = "9_1", count = 30 } } } } } }
      end

      -- tabOf is a tab holding list's sections, each item's slot key starting with prefix: each bag its own buttons.
      local function tabOf(prefix, list)
        local categories, items, n = {}, {}, 0
        for _, s in ipairs(list) do
          table.insert(categories, { name = s[1] })
          for _ = 1, s[2] do
            n = n + 1
            table.insert(items, item(prefix .. n, s[1]))
          end
        end
        return { categories = categories, items = items }
      end

      -- The defaults: two columns side to side, wide sections on, a Wide Column Limit of two.
      local function inColumns()
        override(stubs.database, "GetNextSectionColumns", function() return 2 end)
        override(stubs.database, "GetNextSectionSpan", function() return true end)
      end

      local function holding(panel, list)
        panel:Draw(ctx(), slotsOf(list), function() end)
        render:Flush()
      end

      -- cut lists what is cut short: its title, and each section's name.
      local function cut(panel)
        local out = {}
        if panel.title:IsTruncated() then table.insert(out, "title") end
        for _, s in ipairs(panel.content.order) do
          if s.titleCut then table.insert(out, s.name) end
        end
        return out
      end

      -- measured gives a section's name a width of its own, as the client measures its font.
      local function measured(panel, name, width)
        panel.content.byName[name].title.GetStringWidth = function() return width end
      end

      local function backpack()
        return opened(function(c) return nextBag:Create(c) end)
      end

      local function reopen(panel)
        panel:Hide(ctx())
        finishTweens()
        panel:Show(ctx())
        finishTweens()
        render:Flush()
      end

      describe("as it opens and as a grip is let go", function()
        -- Three cells hold it in one column; four (two columns of two) and five (three and two) cut it; six (three and three)
        -- hold it. The snap searches up from where it snaps, the player's columns kept, never down to the fewest.
        it("snaps the reported bag let go wide to six cells, every name whole, and saves that", function()
          inColumns()
          local bag = backpack()
          holding(bag, REPORTED)
          measured(bag, "Miscellaneous", 100)
          resize(bag, "RIGHT", columnsWidth(12), 600)
          finishTweens()
          render:Flush()
          assert.are.equal(columnsWidth(6), bag.frame:GetWidth())
          assert.are.same({ columnsWidth(6), 600 }, db.sizes[BACKPACK])
          assert.are.equal(2, bag.content.grid.count, "its columns kept")
          assert.are.same({}, cut(bag))
          resize(bag, "RIGHT", columnsWidth(5), 600)
          finishTweens()
          render:Flush()
          assert.are.equal(columnsWidth(6), bag.frame:GetWidth(), "let go at five")
        end)

        -- Clamp Bags to Screen is on here. Let go a grip's width from the screen's edge, a name takes it wider than the
        -- screen leaves room for: its place is put back on the screen, and both its edges glide there.
        it("glides both its edges where a grip let go snaps it wider than the screen's edge leaves room for", function()
          inColumns()
          db.places[BACKPACK] = { UIParent:GetWidth() - columnsWidth(8) - 30, 900 }
          local bag = backpack()
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          resize(bag, "RIGHT", columnsWidth(8) + 10, 600)
          local x1 = UIParent:GetWidth() - columnsWidth(12)
          assert.are.equal(x1, bag.placeX)
          step(style.Time.Snap * 0.7)
          assert.is_true(bag.sizeGliding)
          local x = topLeft(bag)
          assert.is_true(math.abs(x + bag.frame:GetWidth() - UIParent:GetWidth()) < 0.01, "its right edge at the screen's")
          finishTweens()
          assert.are.same({ x1, 900 }, { topLeft(bag) })
          assert.are.same({ columnsWidth(12), 600 }, db.sizes[BACKPACK])
        end)

        -- Found by the fourth bug review (as for a glide for its names, "with Fit Names While Open on" below): a grip let go
        -- wider than the screen's edge leaves room for, at the backpack's default place, glided its left edge between two
        -- pixels on a frame or two.
        for _, screen in ipairs({ { 2560, 1440, 0.71, 125 }, { 1920, 1080, 0.64, 100 }, { 1920, 1080, 1, 85 } }) do
          it(string.format("glides both its edges on whole screen pixels where a grip let go puts it back, %dx%d at %s, Bag Scale %d%%",
            screen[1], screen[2], screen[3], screen[4]), function()
            local layoutHelper = dofile("spec/helpers/layout.lua")
            finally(layoutHelper.UseScreen(screen[1], screen[2], screen[3]))
            db.bagScale = screen[4]
            local bag = backpack()
            local x0 = bag.placeX
            gripTo(bag, "RIGHT", bag.frame:GetWidth() + 101)
            assert.is_true(bag.placeX < x0 - 10, "its place put back on the screen: " .. x0 .. " to " .. bag.placeX)
            local ppu = layoutHelper.PixelsPerUnit()
            local frames = 0
            while bag.sizeGliding do
              step(1 / 60)
              frames = frames + 1
              local rect = layoutHelper.Rect(bag.frame)
              for _, edge in ipairs({ "left", "right" }) do
                local px = rect[edge] * ppu
                assert.is_true(math.abs(px - math.floor(px + 0.5)) < 1e-3, "its " .. edge .. " edge, frame " .. frames .. ": " .. px)
              end
            end
            assert.is_true(frames > 5)
          end)
        end

        it("stays where its names put it through a press on a grip that moves nothing", function()
          inColumns()
          local bag = backpack()
          holding(bag, REPORTED)
          measured(bag, "Miscellaneous", 100)
          resize(bag, "RIGHT", columnsWidth(12), 600)
          finishTweens()
          render:Flush()
          db.sizes[BACKPACK] = nil
          press(bag.grips.RIGHT)
          release(bag.grips.RIGHT)
          assert.is_false(bag.sizeGliding)
          assert.is_nil(db.sizes[BACKPACK], "nothing saved")
          assert.are.equal(columnsWidth(6), bag.frame:GetWidth())
        end)

        it("snaps one column to the cells its section's name needs", function()
          local bag = backpack()
          holding(bag, { { "Item Enhancement", 2 } })
          measured(bag, "Item Enhancement", 250)
          resize(bag, "RIGHT", columnsWidth(10), 600)
          finishTweens()
          render:Flush()
          -- 2 + 250 + 8 + 6 = 266: a whole row of six (294), less the pixel and a half its frame may lose, holds it.
          assert.are.equal(columnsWidth(6), bag.frame:GetWidth())
          assert.are.same({}, cut(bag))
        end)

        it("opens a saved width too narrow for its names at the width they need, keeping what was saved", function()
          inColumns()
          db.sizes[BACKPACK] = { columnsWidth(4), 600 }
          local bag = backpack()
          holding(bag, REPORTED)
          measured(bag, "Miscellaneous", 100)
          assert.are.equal(columnsWidth(4), bag.frame:GetWidth())
          reopen(bag)
          assert.are.equal(columnsWidth(6), bag.frame:GetWidth())
          assert.are.equal(columnsWidth(6) - 2 * style.PAD, bag.root:PreRender().LayoutWidth)
          assert.are.same({ columnsWidth(4), 600 }, db.sizes[BACKPACK], "what was saved is kept")
          assert.are.same({}, cut(bag))
        end)

        it("goes no narrower than its whole title, at the first grid step that holds it", function()
          local bag = backpack()
          bag:SetTitle(string.rep("t", 26))
          local room, slack = bag:titleEnd()
          local need = bag:TitleStart() + room + slack + 26 * 6
          local min, cr = bag:MinWidth(), bag:ContentRoom()
          assert.is_true(min >= need, "its title whole")
          assert.are.equal(min, cr + bag.content:RowWidth(bag.content:PerRow(min - cr)), "on a step")
          assert.is_true(min - (style.ICON + style.GAP) < need + bag:PixelUnit(), "the first that holds it")
          db.sizes[BACKPACK] = { 1, 500 }
          reopen(bag)
          assert.are.equal(min, bag.frame:GetWidth())
          assert.is_false(bag.title:IsTruncated())
        end)

        -- The frame stands on the whole pixel nearest its width, and the title's room is rounded to a whole pixel too: a
        -- minimum that left exactly the title's width cut it by a fraction of a pixel at some Bag Scales.
        it("never cuts its title at its minimum, at any Bag Scale, a title's need landing on a grid step too", function()
          for _, screen in ipairs({ false, { 3396, 1362, 0.65 } }) do
            local undo = screen and dofile("spec/helpers/layout.lua").UseScreen(screen[1], screen[2], screen[3])
            for _, scale in ipairs({ 85, 100, 115, 135 }) do
              db.bagScale = scale
              db.sizes[BANK] = { 1, 500 }
              local bank = nextBank:Create(ctx())
              local room, slack = bank:titleEnd()
              local start = bank:TitleStart() + room + slack
              for cells = 5, 8 do
                for _, off in ipairs({ -0.6, -0.3, -0.01, 0, 0.01, 0.3, 0.6 }) do
                  local width = columnsWidth(cells) - start + off
                  bank.title.GetStringWidth = function() return width end
                  bank:SetTitle("Bank")
                  bank:FitSmall()
                  assert.is_false(bank.title:IsTruncated(),
                    string.format("%s at %d%%, a title %.2f wide", screen and "a 3396x1362 screen" or "1920x1200", scale, width))
                end
              end
            end
            if undo then undo() end
          end
        end)

        -- A whole row is drawn in whole pixels: its frame on the nearest pixel, the scroll bar's room on each side too, so it
        -- can be up to two pixels short of its cells' width (RowWidth). A name that row was found to hold is never cut.
        it("never cuts a name its whole row was found to hold, at any Bag Scale", function()
          for _, screen in ipairs({ false, { 3396, 1362, 0.65 }, { 1920, 1080, 0.64 } }) do
            local undo = screen and dofile("spec/helpers/layout.lua").UseScreen(screen[1], screen[2], screen[3])
            for _, scale in ipairs({ 85, 100, 115, 135 }) do
              db.bagScale = scale
              local bag = backpack()
              holding(bag, { { "A", 1 } })
              for cells = 6, 8 do
                db.sizes[BACKPACK] = { columnsWidth(cells - 1), 600 }
                for off = -3, 1, 0.25 do
                  -- The title's place, the gap and the count (2 + 8 + 6) take the rest of the row's width. A new
                  -- measure is a new name: the canvas lays it out again.
                  measured(bag, "A", bag.content:RowWidth(cells) - 16 + off)
                  bag.content:Invalidate()
                  reopen(bag)
                  assert.are.same({}, cut(bag), string.format("%s at %d%%, %d cells %+.2f",
                    screen and (screen[1] .. "x" .. screen[2]) or "1920x1200", scale, cells, off))
                end
              end
              bag:Hide(ctx())
              finishTweens()
            end
            if undo then undo() end
          end
        end)

        -- The client measures a font string at the width it was cut to (next-themes-art.md §14): a title cut short is measured
        -- whole as it is set again, so the panel still knows how wide it needs to be.
        it("measures its whole title, though the client measures a title at the width it was cut to", function()
          local bag = backpack()
          local whole = 400
          bag.title.GetStringWidth = function(self)
            local width = self._width
            if width ~= nil and width > 0 and width < whole then return width end
            return whole
          end
          bag:SetTitle("Backpack")
          assert.are.equal(whole, bag.titleWhole)
          assert.is_true(bag.title:GetStringWidth() < whole, "cut at its default width")
          bag:StyleParts()
          assert.are.equal(whole, bag.titleWhole, "and through a restyle")
          reopen(bag)
          assert.is_true(bag.frame:GetWidth() >= bag:TitleStart() + select(1, bag:titleEnd()) + 12 + whole)
        end)

        it("measures its title again as a theme restyles it", function()
          local bag = backpack()
          local width = 100
          bag.title.GetStringWidth = function() return width end
          bag:SetTitle("Backpack")
          assert.are.equal(100, bag.titleWhole)
          -- The theme's font is wider.
          width = 300
          bag:StyleParts()
          assert.are.equal(300, bag.titleWhole)
        end)

        -- Found by the bug review: the title's cloud is laid out for the title as the client measures it, cut short, as it is
        -- set; the bank sets its tab's name as it opens (OnShowing), before the open makes room for it (FitSmall), and nothing
        -- laid the cloud out again for the title shown whole.
        it("lays its title's cloud out again once it opens wide enough to show its title whole", function()
          local bank = opened(function(c) return nextBank:Create(c) end)
          local whole = 70 * 6
          bank.title.GetStringWidth = function(self)
            local width = self._width
            if width ~= nil and width > 0 and width < whole then return width end
            return whole
          end
          bank:Hide(ctx())
          finishTweens()
          bank:SetTitle(string.rep("b", 70))
          local span = bank:CloudSpan()
          assert.is_true(span < whole, "cut short where it is set")
          bank:Show(ctx())
          finishTweens()
          render:Flush()
          assert.is_true(bank:CloudSpan() > span, "shown whole")
          local drawn = {}
          for i, puff in ipairs(bank.cloud.puffs) do
            drawn[i] = { puff.base.x, puff.base.w }
          end
          assert.is_true(#drawn > 0, "the theme has a cloud")
          bank:LayoutCloud()
          for i, puff in ipairs(bank.cloud.puffs) do
            assert.are.same({ puff.base.x, puff.base.w }, drawn[i], "puff " .. i .. " laid out for the title it shows")
          end
        end)

        -- At 85% a pixel is 1/0.85 units: the screen a fraction of a pixel wider moves no frame edge, but what it lays out for
        -- (held at the screen's width, unrounded) is wider.
        it("lays its content out again when the width it lays out for changes, though its frame does not", function()
          db.bagScale = 85
          db.sizes[BACKPACK] = { 5000, 600 }
          local bag = backpack()
          local renders = 0
          local invalidate = render.Invalidate
          override(render, "Invalidate", function(r, d)
            if d == bag.root then renders = renders + 1 end
            return invalidate(r, d)
          end)
          local width = bag.frame:GetWidth()
          UIParent:_SetRect(0, 0, UIParent:GetWidth() + 0.3, UIParent:GetHeight())
          chain:Update(ctx(), true)
          assert.are.equal(width, bag.frame:GetWidth(), "on the same whole pixel")
          assert.are.equal(1, renders)
          assert.is_true(math.abs(bag:RestingLayoutWidth() - UIParent:GetWidth() / 0.85) < 1e-9)
        end)

        it("cuts its title only where even the screen's width cannot hold it", function()
          local bag = backpack()
          bag:SetTitle(string.rep("t", 400))
          reopen(bag)
          assert.are.equal(UIParent:GetWidth(), bag.frame:GetWidth())
          assert.is_true(bag.root:PreRender().LayoutWidth <= UIParent:GetWidth() - 2 * style.PAD, "laid out for the screen")
          assert.is_true(bag.title:IsTruncated())
          bag:SetTitle("Backpack")
          reopen(bag)
          assert.is_false(bag.title:IsTruncated())
        end)
      end)

      describe("with Fit Names While Open off", function()
        it("changes neither its width nor the width it lays out for while it is open, and fits as it next opens", function()
          inColumns()
          local bag = backpack()
          holding(bag, { { "A", 1 }, { "B", 1 } })
          local width, layout = bag.frame:GetWidth(), bag.root:PreRender().LayoutWidth
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          assert.are.equal(width, bag.frame:GetWidth())
          assert.are.equal(layout, bag.root:PreRender().LayoutWidth)
          assert.is_false(bag.sizeGliding)
          assert.are.same({ LONG }, cut(bag), "cut until it next opens")
          reopen(bag)
          assert.are.equal(columnsWidth(12), bag.frame:GetWidth(), "a column of six beside a column of six")
          assert.are.same({}, cut(bag))
          assert.is_nil(db.sizes[BACKPACK])
        end)

        -- It was "Known, not fixed" (next-columns.md): a panel at its minimum laid out for a minimum that followed its footer's
        -- text, while its frame took it only when fitted, so a free-slot count gaining a digit could lay out a cell more than
        -- the frame held.
        it("lays out for the width it took while its footer's minimum grows, until it is fitted again", function()
          db.sizes[BANK] = { 1, 500 }
          local bank = nextBank:Create(ctx())
          -- What the bank draws as it opens (OnShowing), and after: its free slots in the tab it shows.
          local function bankSlots(free)
            slots[BANK] = { sortedItems = {}, tabs = { [bank:GetCurrentTabID()] = { categories = { { name = "Ore" } },
              items = { item("6_1", "Ore") }, freeSpace = { showAll = false, buttons = { { slotkey = "6_9", count = free } } } } } }
            return slots[BANK]
          end
          -- 36 + 4 + 12 and the money: "1 free slots" (72) leaves it at nine cells, "100000 free slots" (102) needs ten.
          bank.moneyFrame.frame:SetWidth(380)
          bankSlots(1)
          bank:Show(ctx())
          finishTweens()
          render:Flush()
          assert.are.equal(columnsWidth(9), bank.frame:GetWidth())
          local layout = bank.root:PreRender().LayoutWidth
          bank:Draw(ctx(), bankSlots(100000), function() end)
          render:Flush()
          assert.are.equal(columnsWidth(9), bank.frame:GetWidth())
          assert.are.equal(layout, bank.root:PreRender().LayoutWidth, "it lays out for the width it took")
          reopen(bank)
          assert.are.equal(columnsWidth(10), bank.frame:GetWidth())
          assert.are.equal(columnsWidth(10) - 2 * style.PAD, bank.root:PreRender().LayoutWidth)
        end)
      end)

      describe("with Fit Names While Open on", function()
        before_each(function()
          db.fitNames = true
        end)

        it("glides wider as a long name comes in, every name whole on the way, and back as it goes, saving nothing", function()
          inColumns()
          local bag = backpack()
          holding(bag, { { "A", 1 }, { "B", 1 } })
          local width = bag.frame:GetWidth()
          local right = select(1, topLeft(bag)) + width
          assert.are.equal(columnsWidth(8), width)
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          assert.is_true(bag.sizeGliding, "it glides")
          local frames = 0
          while bag.sizeGliding do
            step(1 / 60)
            render:Flush()
            frames = frames + 1
            assert.are.same({}, cut(bag), "frame " .. frames)
            local w = bag.frame:GetWidth()
            assert.is_true(w >= width and w <= columnsWidth(12), "frame " .. frames .. ": " .. w)
            assert.is_true(math.abs(select(1, topLeft(bag)) + w - right) < 0.01, "its right edge still, at its default place")
          end
          assert.is_true(frames > 5)
          assert.are.equal(columnsWidth(12), bag.frame:GetWidth())
          assert.are.same({}, cut(bag))
          holding(bag, { { "A", 1 }, { "B", 1 } })
          assert.is_true(bag.sizeGliding, "it glides back")
          finishTweens()
          render:Flush()
          assert.are.equal(width, bag.frame:GetWidth())
          assert.are.same({ right - width }, { (topLeft(bag)) })
          assert.is_nil(db.sizes[BACKPACK])
          assert.is_nil(db.places[BACKPACK])
        end)

        it("narrows back to the width the player saved, its place kept", function()
          inColumns()
          db.sizes[BACKPACK] = { columnsWidth(9), 600 }
          db.places[BACKPACK] = { 300, 900 }
          local bag = backpack()
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          finishTweens()
          assert.are.equal(columnsWidth(12), bag.frame:GetWidth())
          assert.are.same({ 300, 900 }, { topLeft(bag) }, "its left edge still")
          holding(bag, { { "A", 1 } })
          finishTweens()
          assert.are.equal(columnsWidth(9), bag.frame:GetWidth())
          assert.are.same({ 300, 900 }, { topLeft(bag) })
          assert.are.same({ columnsWidth(9), 600 }, db.sizes[BACKPACK])
          -- The bottom left it holds (docs/next-bag-anchor.md), taken over from where it was left as it opened.
          assert.are.same({ 300, 300, "LEFT", "BOTTOM" }, db.corners[BACKPACK])
        end)

        -- A frame on: what sets a new title draws what it shows next in the same frame, and that draw fits both at once.
        it("widens for its title a frame after it is given a longer one, drawn or not", function()
          local bag = backpack()
          bag:SetTitle(string.rep("t", 60))
          assert.is_false(bag.sizeGliding, "a frame on")
          step(1 / 60)
          assert.is_true(bag.sizeGliding)
          finishTweens()
          assert.is_false(bag.title:IsTruncated())
          assert.are.equal(bag:MinWidth(), bag.frame:GetWidth())
          bag:SetTitle("Backpack")
          finishTweens()
          assert.are.equal(columnsWidth(8), bag.frame:GetWidth())
          assert.is_nil(db.sizes[BACKPACK])
        end)

        -- The footer's text is set before the panel fits and lays out: a count gaining a digit is fitted in the same draw.
        it("fits its footer's minimum in the draw that grows it", function()
          db.sizes[BANK] = { 1, 500 }
          local bank = nextBank:Create(ctx())
          local function bankSlots(free)
            slots[BANK] = { sortedItems = {}, tabs = { [bank:GetCurrentTabID()] = { categories = { { name = "Ore" } },
              items = { item("6_1", "Ore") }, freeSpace = { showAll = false, buttons = { { slotkey = "6_9", count = free } } } } } }
            return slots[BANK]
          end
          bank.moneyFrame.frame:SetWidth(380)
          bankSlots(1)
          bank:Show(ctx())
          finishTweens()
          assert.are.equal(columnsWidth(9), bank.frame:GetWidth())
          bank:Draw(ctx(), bankSlots(100000), function() end)
          assert.is_true(bank.sizeGliding)
          assert.are.equal(columnsWidth(10), bank.snap.body, "laid out at once for the width it glides to")
          finishTweens()
          assert.are.equal(columnsWidth(10), bank.frame:GetWidth())
        end)

        it("waits while a grip holds it, and fits as the grip is let go", function()
          inColumns()
          local bag = backpack()
          holding(bag, { { "A", 1 }, { "B", 1 } })
          press(bag.grips.RIGHT)
          sizeTo(bag, "RIGHT", bag.frame:GetWidth(), bag.frame:GetHeight())
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          assert.is_false(bag.sizeGliding)
          assert.are.equal(columnsWidth(8), bag.frame:GetWidth())
          release(bag.grips.RIGHT)
          finishTweens()
          render:Flush()
          assert.are.equal(columnsWidth(12), bag.frame:GetWidth())
          assert.are.same({}, cut(bag))
        end)

        it("waits while it is moved, and follows once it is dropped", function()
          inColumns()
          local bag = backpack()
          holding(bag, { { "A", 1 }, { "B", 1 } })
          bag.mover:GetScript("OnDragStart")(bag.mover, "LeftButton")
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          assert.is_false(bag.sizeGliding)
          assert.are.equal(columnsWidth(8), bag.frame:GetWidth())
          bag.mover:GetScript("OnDragStop")(bag.mover)
          assert.is_false(bag.sizeGliding, "a frame on: what ended may have been cut short by something placing it")
          step(1 / 60)
          assert.is_true(bag.sizeGliding)
          finishTweens()
          assert.are.equal(columnsWidth(12), bag.frame:GetWidth())
          assert.is_nil(db.sizes[BACKPACK])
        end)

        -- Cut short by a move, a glide ends as it is going (endSizeGlide); what the names asked for waits for the move, never
        -- gliding under the mouse.
        it("never glides while it is moved, though the glide a move cut short owed one", function()
          inColumns()
          local bag = backpack()
          holding(bag, { { "A", 1 }, { "B", 1 } })
          resize(bag, "RIGHT", columnsWidth(20), 600)
          step(0.05)
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          bag.mover:GetScript("OnDragStart")(bag.mover, "LeftButton")
          assert.is_true(bag.moving)
          assert.is_false(bag.sizeGliding)
          step(1 / 60)
          step(1 / 60)
          assert.is_false(bag.sizeGliding, "not while it is moved")
          bag.mover:GetScript("OnDragStop")(bag.mover)
          finishTweens()
          assert.are.equal(columnsWidth(12), bag.frame:GetWidth())
        end)

        it("waits while its size glides, and follows once it ends", function()
          inColumns()
          local bag = backpack()
          holding(bag, { { "A", 1 }, { "B", 1 } })
          resize(bag, "RIGHT", columnsWidth(20), 600)
          step(0.05)
          assert.is_true(bag.sizeGliding)
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          assert.are.equal(columnsWidth(4), bag.snap.body, "its snap goes on where it was going")
          step(style.Time.Snap)
          step(1 / 60)
          assert.is_true(bag.sizeGliding, "following once the snap has ended")
          assert.are.equal(columnsWidth(12), bag.snap.body)
          finishTweens()
          render:Flush()
          assert.are.equal(columnsWidth(12), bag.frame:GetWidth())
          assert.are.same({ columnsWidth(4), 600 }, db.sizes[BACKPACK], "what the grip saved")
          assert.are.same({}, cut(bag))
        end)

        -- Opening fits it (FitSmall): the draw it opens with does not glide it too.
        it("opens at the width its names need at once, without a glide", function()
          inColumns()
          local bag = nextBag:Create(ctx())
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          local glides = countCalls(bag, "snapTo")
          bag:Show(ctx())
          assert.are.equal(0, glides())
          assert.is_false(bag.sizeGliding)
          assert.are.equal(columnsWidth(12), bag.frame:GetWidth())
        end)

        -- Clamp Bags to Screen is on here: wider, its place is put back on the screen, so both its edges move. It holds its
        -- left (a corner saved on a wider screen, docs/next-bag-anchor.md), so it widens toward the screen's right edge.
        it("glides both its edges where the screen's edge puts it back", function()
          inColumns()
          db.corners[BACKPACK] = { UIParent:GetWidth() - columnsWidth(8) - 20, 900 - smallHeight(), "LEFT", "BOTTOM" }
          local bag = backpack()
          holding(bag, { { "A", 1 }, { "B", 1 } })
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          local x1 = UIParent:GetWidth() - columnsWidth(12)
          assert.are.equal(x1, bag.placeX)
          -- Past the snap's turn a size that grows is at its width.
          step(style.Time.Snap * 0.7)
          assert.is_true(bag.sizeGliding)
          local x = topLeft(bag)
          assert.is_true(math.abs(x + bag.frame:GetWidth() - UIParent:GetWidth()) < 0.01, "its right edge at the screen's")
          assert.is_true(math.abs(x - x1) < 0.01)
          finishTweens()
          assert.are.same({ x1, 900 }, { topLeft(bag) })
          assert.are.same({ UIParent:GetWidth() - columnsWidth(8) - 20, 900 - smallHeight(), "LEFT", "BOTTOM" }, db.corners[BACKPACK],
            "its place kept")
        end)

        -- Found by the fourth bug review: gliding to its new place with its width, its left edge was never put on a whole
        -- pixel, and stood between two on 11 or 12 of the glide's 21 frames: the scroll box it holds, clipped there, drew its
        -- icons stretched across the fraction (texture-sharpening.md §5).
        for _, screen in ipairs({ { 2560, 1440, 0.71, 125 }, { 1920, 1080, 0.64, 100 }, { 1920, 1080, 1, 85 } }) do
          it(string.format("glides both its edges on whole screen pixels where the screen's edge puts it back, %dx%d at %s, Bag Scale %d%%",
            screen[1], screen[2], screen[3], screen[4]), function()
            local layoutHelper = dofile("spec/helpers/layout.lua")
            finally(layoutHelper.UseScreen(screen[1], screen[2], screen[3]))
            db.bagScale = screen[4]
            inColumns()
            -- Holding its left near the screen's right edge (a corner saved on a wider screen, docs/next-bag-anchor.md).
            local bag = nextBag:Create(ctx())
            db.corners[BACKPACK] = { UIParent:GetWidth() - columnsWidth(8) * screen[4] / 100 - 6,
              UIParent:GetHeight() - 30 - bag.frame:GetHeight() * screen[4] / 100, "LEFT" }
            bag:Show(ctx())
            finishTweens()
            holding(bag, { { "A", 1 }, { "B", 1 } })
            finishTweens()
            local x0 = bag.placeX
            holding(bag, { { "A", 1 }, { LONG, 1 } })
            assert.is_true(bag.placeX < x0 - 10, "its place put back on the screen: " .. x0 .. " to " .. bag.placeX)
            local ppu = layoutHelper.PixelsPerUnit()
            local frames = 0
            while bag.sizeGliding do
              step(1 / 60)
              frames = frames + 1
              local rect = layoutHelper.Rect(bag.frame)
              for _, edge in ipairs({ "left", "right" }) do
                local px = rect[edge] * ppu
                assert.is_true(math.abs(px - math.floor(px + 0.5)) < 1e-3, "its " .. edge .. " edge, frame " .. frames .. ": " .. px)
              end
            end
            assert.is_true(frames > 5)
          end)
        end

        it("settles a chained partner that was busy itself as it glided", function()
          inColumns()
          local bag = backpack()
          local bank = opened(function(c) return nextBank:Create(c) end)
          db.smallChain = "backpack"
          chain:Update(ctx())
          finishTweens()
          holding(bag, { { "A", 1 }, { "B", 1 } })
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          assert.is_true(bag.sizeGliding)
          step(0.05)
          -- The bank's own snap (it shows nothing: to the cells it was let go at), on through the backpack's glide.
          resize(bank, "LEFT", columnsWidth(11) + 20, 480)
          assert.is_true(bank.sizeGliding)
          finishTweens()
          local cx, cy = chain:ChainedPlace(bank, bag, bag.placeX, bag.placeY)
          local bx, by = topLeft(bank)
          assert.is_true(math.abs(cx - bx) < 1 and math.abs(cy - by) < 1, bx .. " beside " .. cx)
        end)

        -- What the anchor's glide owed the bag beside it is paid once it is settled (chain:Settle): its own grip let go after,
        -- its spot still, glides it nowhere, though the place a grip saves stands a fraction of a pixel from its spot.
        it("owes a busy partner it settled nothing more as that partner's own grip is let go after", function()
          local layoutHelper = dofile("spec/helpers/layout.lua")
          finally(layoutHelper.UseScreen(2560, 1440, 0.71))
          db.bagScale = 125
          inColumns()
          local bag = backpack()
          local bank = opened(function(c) return nextBank:Create(c) end)
          db.smallChain = "backpack"
          chain:Update(ctx())
          finishTweens()
          holding(bag, { { "A", 1 }, { "B", 1 } })
          finishTweens()
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          assert.is_true(bag.sizeGliding)
          step(0.05)
          gripTo(bank, "LEFT", bank.frame:GetWidth() + 40)
          assert.is_true(bank.sizeGliding)
          finishTweens()
          local cx = chain:ChainedPlace(bank, bag, bag.placeX, bag.placeY)
          assert.is_true(math.abs(cx - bank.placeX) < 1, "settled beside it")
          for _ = 1, 60 do chain:Turn(1 / 60) end
          for _, wider in ipairs({ 37, 101, 213, 333 }) do
            gripTo(bank, "LEFT", bank.frame:GetWidth() + wider)
            for frame = 1, 45 do
              step(1 / 60)
              chain:Turn(1 / 60)
              local why = "let go " .. wider .. " wider, frame " .. frame
              assert.is_false(tween:IsPlaying(bank), "it glides into no spot: " .. why)
              assert.is_true(chain.coupling ~= nil and chain.coupling.target == 1, "braided: " .. why)
            end
            finishTweens()
          end
        end)

        -- holdAt presses panel's grip on side and sizes it w wide, the corner across from it still, as the client does on a
        -- screen that lays the frames out from their anchors, and holds it there.
        local function holdAt(panel, side, w)
          local f = panel.frame
          local left, top = f:GetLeft(), f:GetTop()
          local right = left + f:GetWidth()
          press(panel.grips[side])
          f:ClearAllPoints()
          f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", side == "LEFT" and right - w or left, top)
          f:SetSize(w, f:GetHeight())
          f:GetScript("OnSizeChanged")(f, w, f:GetHeight())
        end

        -- dragBy drags panel dx along by its title row and drops it, the mover's frame (its OnUpdate) run between unless
        -- dropped in the frame it was picked up.
        local function dragBy(panel, dx, aFrame)
          local s = panel.frame:GetScale()
          panel.mover:GetScript("OnDragStart")(panel.mover, "LeftButton")
          panel.frame:ClearAllPoints()
          panel.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (panel.placeX + dx) / s, panel.placeY / s)
          if aFrame then
            panel.mover:GetScript("OnUpdate")(panel.mover, 1 / 60)
          end
          panel.mover:GetScript("OnDragStop")(panel.mover)
          finishTweens()
        end

        -- Found by the fourth bug review: what the anchor's glide owed the bag beside it was paid only by settling it
        -- (chain:Settle), so a bag put back on its spot some other way kept owing it, and its own left grip let go after ran
        -- the chain's update, which glided it over the fraction of a pixel its let-go place stands from its spot (the older
        -- rounding, next-small-resize.md §14g), and the braid let go for 15 frames. Each way of putting it on its spot pays
        -- what it owed. Each starts as the test above does: the backpack glides for a long name while the bank's left grip
        -- holds it at its width, so the glide owes it, and a grip let go at that width snaps nothing.
        local OWED = {
          { "a refit puts it on its spot", function(_, bank)
            for _ = 1, 40 do step(1 / 60) end
            release(bank.grips.LEFT)
            finishTweens()
            chain:Update(ctx(), true)
            finishTweens()
          end },
          { "its anchor is dragged and dropped", function(bag, bank)
            for _ = 1, 40 do step(1 / 60) end
            release(bank.grips.LEFT)
            finishTweens()
            dragBy(bag, -200, true)
            assert.are.equal("backpack", db.smallChain)
          end },
          { "its anchor is dropped in the frame it was picked up", function(bag, bank)
            for _ = 1, 40 do step(1 / 60) end
            release(bank.grips.LEFT)
            finishTweens()
            dragBy(bag, -200, false)
            assert.are.equal("backpack", db.smallChain)
          end },
          -- Dropped within the reach of its old spot beside the bank, the backpack chains to the bank (chain:Dropped reads the
          -- old saved place, next-small-names.md §14g: reported, not fixed): the drop places nothing beside it, its frame of the drag did.
          { "its anchor is dragged a little and chains to it", function(bag, bank)
            for _ = 1, 40 do step(1 / 60) end
            release(bank.grips.LEFT)
            finishTweens()
            dragBy(bag, -30, true)
            assert.are.equal("companion", db.smallChain)
          end },
          -- Let go while the backpack still glides, the bank is placed by the glide's next frame; a press on the backpack's grip
          -- then ends the glide (endSizeGlide), which settles no chain.
          { "its anchor's glide places it and is cut short", function(bag, bank)
            for _ = 1, 3 do step(1 / 60) end
            release(bank.grips.LEFT)
            step(1 / 60)
            assert.is_true(bag.sizeGliding)
            press(bag.grips.RIGHT)
            release(bag.grips.RIGHT)
            finishTweens()
          end },
        }
        for _, way in ipairs(OWED) do
          for _, wider in ipairs({ 37, 53, 101, 157 }) do
            it(string.format("owes a busy partner nothing once %s, its own left grip let go %d wider after", way[1], wider), function()
              local layoutHelper = dofile("spec/helpers/layout.lua")
              finally(layoutHelper.UseScreen(2560, 1440, 0.71))
              db.bagScale = 125
              inColumns()
              local bag = backpack()
              local bank = opened(function(c) return nextBank:Create(c) end)
              db.smallChain = "backpack"
              chain:Update(ctx())
              finishTweens()
              holding(bag, { { "A", 1 }, { "B", 1 } })
              finishTweens()
              holding(bag, { { "A", 1 }, { LONG, 1 } })
              assert.is_true(bag.sizeGliding)
              step(0.05)
              holdAt(bank, "LEFT", bank.frame:GetWidth())
              way[2](bag, bank)
              for _ = 1, 60 do chain:Turn(1 / 60) end
              assert.is_true(chain.coupling ~= nil and chain.coupling.amount == 1, "braided")
              gripTo(bank, "LEFT", bank.frame:GetWidth() + wider)
              for frame = 1, 45 do
                step(1 / 60)
                chain:Turn(1 / 60)
                local why = "frame " .. frame
                assert.is_false(tween:IsPlaying(bag) or tween:IsPlaying(bank), "nothing glides into a spot: " .. why)
                assert.is_true(chain.coupling ~= nil and chain.coupling.target == 1, "braided: " .. why)
              end
            end)
          end
        end

        -- The bank busy with its own snap is left to it (busy): placed by the backpack's glide on each frame, its snap would
        -- end at once (setOffset ends a size glide), a jump to its width.
        it("leaves a chained partner's own snap gliding frame by frame as it glides", function()
          inColumns()
          local bag = backpack()
          local bank = opened(function(c) return nextBank:Create(c) end)
          db.smallChain = "backpack"
          chain:Update(ctx())
          finishTweens()
          holding(bag, { { "A", 1 }, { "B", 1 } })
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          step(0.05)
          resize(bank, "LEFT", columnsWidth(11) + 20, 480)
          local was, frames = bank.frame:GetWidth(), 0
          local distance = was - columnsWidth(11)
          while bag.sizeGliding do
            step(1 / 60)
            frames = frames + 1
            local w = bank.frame:GetWidth()
            assert.is_true(bank.sizeGliding, "its own snap goes on, frame " .. frames)
            assert.is_true(math.abs(w - was) < distance / 2, "frame " .. frames .. ": " .. was .. " to " .. w)
            was = w
          end
          assert.is_true(frames > 5)
          finishTweens()
          assert.are.equal(columnsWidth(11), bank.frame:GetWidth())
        end)

        it("waits for a Shift-click's glide back, and follows once it ends", function()
          inColumns()
          db.sizes[BACKPACK] = { columnsWidth(10), 600 }
          local bag = backpack()
          holding(bag, { { "A", 1 }, { "B", 1 } })
          finally(function() _G._isShiftKeyDown = false end)
          _G._isShiftKeyDown = true
          press(bag.grips.RIGHT)
          release(bag.grips.RIGHT)
          _G._isShiftKeyDown = false
          assert.is_true(bag.sizeGliding)
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          finishTweens()
          render:Flush()
          assert.are.equal(columnsWidth(12), bag.frame:GetWidth())
          assert.is_nil(db.sizes[BACKPACK], "the reset cleared it, and the follow saves nothing")
        end)

        it("waits while it switches size, and is fitted as it arrives", function()
          inColumns()
          db.size = "full"
          local bag = backpack()
          holding(bag, { { "A", 1 }, { "B", 1 } })
          nextPanel:SetSize(ctx(), "small")
          step(style.Time.Morph / 2)
          assert.is_not_nil(bag.morph)
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          assert.is_false(bag.sizeGliding, "not while it switches")
          finishTweens()
          render:Flush()
          assert.are.equal(columnsWidth(12), bag.frame:GetWidth())
          assert.are.same({}, cut(bag))
        end)

        -- A drag cancelled draws nothing after it: the follow it waited for comes as the drag ends (nextDrag's finish).
        it("waits while a section is dragged on it, and follows once the drag ends", function()
          inColumns()
          local bag = backpack()
          holding(bag, { { "A", 1 }, { "B", 1 } })
          local a = bag.content.byName.A
          -- Where the client drew it: a section is picked up from its place on the screen.
          a.frame:_SetRect(100, 500, 100, 40)
          assert.is_true(nextDrag:Begin(bag, a))
          holding(bag, { { "A", 1 }, { "B", 1 }, { LONG, 1 } })
          assert.is_false(bag.sizeGliding, "not under a section dragged")
          assert.is_true(bag.namesOwed)
          nextDrag:Cancel()
          assert.is_false(bag.sizeGliding, "a frame on")
          step(1 / 60)
          assert.is_true(bag.sizeGliding, "with no draw after the drag")
          finishTweens()
          -- Under A, a first column of six: six and five.
          assert.are.equal(columnsWidth(11), bag.frame:GetWidth())
        end)

        it("waits for its opening slide, and follows once it is open", function()
          inColumns()
          local bag = nextBag:Create(ctx())
          bag:Show(ctx())
          assert.is_true(tween:IsPlaying(bag))
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          assert.is_false(bag.sizeGliding)
          finishTweens()
          render:Flush()
          assert.are.equal(columnsWidth(12), bag.frame:GetWidth())
          assert.are.same({}, cut(bag))
        end)

        it("keeps a chained partner beside it, and the braid between them, as it widens", function()
          finally(dofile("spec/helpers/layout.lua").UseScreen(1920, 1080, 0.64))
          inColumns()
          local bag = backpack()
          local bank = opened(function(c) return nextBank:Create(c) end)
          db.smallChain = "backpack"
          chain:Update(ctx())
          finishTweens()
          holding(bag, { { "A", 1 }, { "B", 1 } })
          assert.is_not_nil(chain.coupling, "braided")
          local gap = chain:SmallGap(bank, bag)
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          assert.is_true(bag.sizeGliding)
          local frames = 0
          while bag.sizeGliding do
            step(1 / 60)
            chain:Turn(1 / 60)
            frames = frames + 1
            local between = bag.frame:GetLeft() - (bank.frame:GetLeft() + bank.frame:GetWidth())
            assert.is_true(math.abs(between - gap) < 1, "frame " .. frames .. ": " .. between .. " apart")
            assert.is_true(math.abs(2 * bag.braid.half - between) < 1, "the braid across the gap, frame " .. frames)
          end
          finishTweens()
          assert.is_true(frames > 5)
          assert.are.equal(pixel:LengthIn(bag:PixelUnit(), columnsWidth(12)), bag.frame:GetWidth())
          -- Its spot, on the screen's whole pixels.
          local cx, cy = chain:ChainedPlace(bank, bag, bag.placeX, bag.placeY)
          local bx, by = topLeft(bank)
          assert.is_true(math.abs(cx - bx) < 1 and math.abs(cy - by) < 1, bx .. ", " .. by)
          assert.are.same({ bank.placeX, bank.placeY }, { bx, by })
          assert.is_not_nil(chain.coupling, "still braided")
        end)

        -- Found by the bug review: drawn in the same update (items moved between them), both glided at once, and the anchor
        -- moves its partner only while the partner is settled: the partner glided from where the anchor's edge was as it
        -- started, and they overlapped by up to 136 pixels. A chained pair glides for its names one at a time.
        for _, order in ipairs({ "backpack first", "bank first" }) do
          it("glides a chained pair for their names one at a time, never overlapping, drawn " .. order, function()
            finally(dofile("spec/helpers/layout.lua").UseScreen(1920, 1080, 0.64))
            inColumns()
            local bag = backpack()
            local bank = opened(function(c) return nextBank:Create(c) end)
            db.smallChain = "backpack"
            chain:Update(ctx())
            finishTweens()
            local function drawn(panel, prefix, list)
              panel:Draw(ctx(), { sortedItems = {}, tabs = { [panel:GetCurrentTabID()] = tabOf(prefix, list) } }, function() end)
            end
            drawn(bag, "0_", { { "A", 1 }, { "B", 1 } })
            drawn(bank, "6_", { { "C", 1 }, { "D", 1 } })
            render:Flush()
            finishTweens()
            assert.is_not_nil(chain.coupling, "braided")
            local gap = chain:SmallGap(bank, bag)
            local function between()
              return bag.frame:GetLeft() - (bank.frame:GetLeft() + bank.frame:GetWidth())
            end
            if order == "backpack first" then
              drawn(bag, "0_", { { "A", 1 }, { LONG, 1 } })
              drawn(bank, "6_", { { "C", 1 }, { LONG .. "x", 1 } })
            else
              drawn(bank, "6_", { { "C", 1 }, { LONG .. "x", 1 } })
              drawn(bag, "0_", { { "A", 1 }, { LONG, 1 } })
            end
            local glided = { [bag] = false, [bank] = false }
            for frame = 1, 120 do
              step(1 / 60)
              chain:Turn(1 / 60)
              glided[bag] = glided[bag] or bag.sizeGliding
              glided[bank] = glided[bank] or bank.sizeGliding
              assert.is_false(bag.sizeGliding and bank.sizeGliding, "one at a time, frame " .. frame)
              assert.is_true(math.abs(between() - gap) < 1, "frame " .. frame .. ": " .. between() .. " apart")
            end
            assert.is_true(glided[bag] and glided[bank], "each glided")
            assert.is_false(bag.sizeGliding or bank.sizeGliding)
            render:Flush()
            assert.are.same({}, cut(bag))
            assert.are.same({}, cut(bank))
            assert.are.equal(pixel:LengthIn(bag:PixelUnit(), columnsWidth(12)), bag.frame:GetWidth())
            assert.are.equal(pixel:LengthIn(bank:PixelUnit(), columnsWidth(12)), bank.frame:GetWidth())
            assert.is_not_nil(chain.coupling, "still braided")
          end)
        end

        -- Found by the bug review: the glide kept the scroll offset read at the last grip press (keptScroll), scrolling the
        -- bag back there. It keeps where the player has it scrolled as it starts.
        it("keeps where it is scrolled as it glides for a name", function()
          finally(dofile("spec/helpers/layout.lua").UseScreen(1920, 1080, 0.64))
          inColumns()
          db.sizes[BACKPACK] = { 700, 260 }
          local list = {}
          for s, n in ipairs({ 40, 60, 80, 30, 50 }) do
            table.insert(list, { "S" .. s, n })
          end
          local bag = backpack()
          holding(bag, list)
          finishTweens()
          local box = bag.scroll.scrollBox
          -- It holds more than it shows: a range to scroll (the mock works out no extent without rects).
          box._scrollRange = 1000
          box:ScrollToOffset(73, true)
          press(bag.grips.RIGHT)
          release(bag.grips.RIGHT)
          finishTweens()
          box:ScrollToOffset(40, true)
          -- Longer than its twelve cells' columns hold.
          table.insert(list, { string.rep("n", 70), 1 })
          holding(bag, list)
          assert.is_true(bag.sizeGliding)
          local frames = 0
          while bag.sizeGliding do
            step(1 / 60)
            render:Flush()
            -- The client fires the scroll box's OnSizeChanged as the frame's size changes (Blizzard's handler, then KeepScroll).
            box:GetScript("OnSizeChanged")(box, box:GetWidth(), box:GetHeight())
            frames = frames + 1
            assert.is_true(math.abs(box:GetDerivedScrollOffset() - 40) < 0.001,
              "frame " .. frames .. ": " .. box:GetDerivedScrollOffset())
          end
          assert.is_true(frames > 5)
        end)

        -- Found by the bug review: a bank tab switch sets the new tab's title before it draws the tab; the title glided the bank
        -- for the old tab's sections, then the draw glided it again, the new tab's long name cut through the first glide. A new
        -- title is fitted a frame on, so the draw after it in the same frame fits both in one glide.
        it("glides once as a bank tab is switched, its title and sections together, no name cut on the way", function()
          inColumns()
          override(stubs.database, "GetGroupsEnabled", function() return true end)
          -- A title that holds it wider than its sections, short of the width the new tab's names take, beside its header's
          -- buttons (its anchor button among them, docs/next-bag-anchor.md).
          local groupsById = {
            [10] = { id = 10, name = string.rep("b", 60), bankType = 1, isDefault = true },
            [11] = { id = 11, name = "Ore", bankType = 1 },
          }
          override(stubs.groups, "GetGroup", function(_, kind, id) if kind == BANK then return groupsById[id] end end)
          override(stubs.groups, "GetDefaultBankGroup", function() return groupsById[10] end)
          slots[BANK].tabs[10] = tabOf("6_", { { "A", 1 }, { "B", 1 } })
          slots[BANK].tabs[11] = tabOf("6_", { { "A", 1 }, { LONG, 1 } })
          local bank = opened(function(c) return nextBank:Create(c) end)
          render:Flush()
          assert.are.same({}, cut(bank))
          local width = bank.frame:GetWidth()
          assert.is_true(width > columnsWidth(8), "its title holds it wider than its sections")
          local glides = countCalls(bank, "snapTo")
          bank:SwitchToGroup(ctx(), 11)
          render:Flush()
          assert.are.same({}, cut(bank), "as it switches")
          for frame = 1, 90 do
            step(1 / 60)
            render:Flush()
            assert.are.same({}, cut(bank), "frame " .. frame)
          end
          assert.are.equal(1, glides())
          assert.is_false(bank.sizeGliding)
          assert.are.equal(columnsWidth(12), bank.frame:GetWidth())
        end)

        -- A backpack and the bank chained beside it, each drawn with two short names, braided.
        local function chainedPair()
          local bag = backpack()
          local bank = opened(function(c) return nextBank:Create(c) end)
          db.smallChain = "backpack"
          chain:Update(ctx())
          finishTweens()
          holding(bag, { { "A", 1 }, { "B", 1 } })
          bank:Draw(ctx(), { sortedItems = {}, tabs = { [bank:GetCurrentTabID()] = tabOf("6_", { { "C", 1 }, { "D", 1 } }) } },
            function() end)
          render:Flush()
          finishTweens()
          return bag, bank
        end

        -- Found by the second bug review: a bag waiting for its chained partner's glide followed only when what ended that glide
        -- called back for it. Dragged away, the partner's glide was cut short (StartMove) and the pair unchained (chain:Detach),
        -- so the partner's let-go called back for nobody; closing, the slide cut it short. The backpack stayed cut until its
        -- next draw. What a panel owes is tried again each frame while it waits.
        it("follows once the chained partner it waited for is dragged away mid-glide", function()
          inColumns()
          local bag, bank = chainedPair()
          resize(bank, "LEFT", bank.frame:GetWidth() + 300, bank.frame:GetHeight())
          step(0.05)
          assert.is_true(bank.sizeGliding)
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          assert.is_true(bag.namesOwed, "it waits for its partner's glide")
          bank.mover:GetScript("OnDragStart")(bank.mover, "LeftButton")
          assert.are.equal("apart", db.smallChain)
          bank.frame:_SetRect(100, 300, bank.frame:GetWidth(), bank.frame:GetHeight())
          bank.mover:GetScript("OnDragStop")(bank.mover)
          finishTweens()
          render:Flush()
          assert.are.equal(columnsWidth(12), bag.frame:GetWidth())
          assert.are.same({}, cut(bag))
          assert.is_false(tween:IsPlaying(bag.namesKey), "nothing left trying")
        end)

        it("follows once the chained partner it waited for closes mid-glide", function()
          inColumns()
          local bag, bank = chainedPair()
          resize(bank, "LEFT", bank.frame:GetWidth() + 300, bank.frame:GetHeight())
          step(0.05)
          assert.is_true(bank.sizeGliding)
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          assert.is_true(bag.namesOwed)
          bank:Hide(ctx())
          finishTweens()
          render:Flush()
          assert.is_false(bank:IsShown())
          assert.are.equal(columnsWidth(12), bag.frame:GetWidth())
          assert.are.same({}, cut(bag))
        end)

        -- Found by the second bug review: a bag waited only for its partner's grip or size glide, so once the anchor was
        -- dragged (which cuts its glide short) the bag beside it glided under the move, and the anchor, placing it every frame
        -- as it moves (StartMove), ended that glide at once: it jumped to its width. It waits while its partner is moved.
        it("waits while its chained anchor is dragged, and glides for its names once the anchor is dropped", function()
          inColumns()
          local bag, bank = chainedPair()
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          step(0.05)
          assert.is_true(bag.sizeGliding)
          bank:Draw(ctx(), { sortedItems = {}, tabs = { [bank:GetCurrentTabID()] = tabOf("6_", { { "C", 1 }, { LONG .. "x", 1 } }) } },
            function() end)
          assert.is_true(bank.namesOwed, "it waits for its anchor's glide")
          local width = bank.frame:GetWidth()
          bag.mover:GetScript("OnDragStart")(bag.mover, "LeftButton")
          assert.is_false(bag.sizeGliding, "the move ends the anchor's glide")
          for frame = 1, 30 do
            step(1 / 60)
            bag.mover:GetScript("OnUpdate")(bag.mover, 1 / 60)
            assert.is_false(bank.sizeGliding, "not under the move, frame " .. frame)
            assert.are.equal(width, bank.frame:GetWidth(), "frame " .. frame)
          end
          bag.mover:GetScript("OnDragStop")(bag.mover)
          local glided = false
          for _ = 1, 60 do
            step(1 / 60)
            glided = glided or bank.sizeGliding
          end
          assert.is_true(glided, "it glides once its anchor is dropped")
          finishTweens()
          render:Flush()
          assert.are.equal(columnsWidth(12), bank.frame:GetWidth())
          assert.are.same({}, cut(bank))
        end)

        -- Only an open partner makes it wait: one closing slides off its place, and, closed, stays off it (its slide's end).
        it("waits for no chained anchor that closes", function()
          inColumns()
          local bag, bank = chainedPair()
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          step(0.05)
          assert.is_true(bag.sizeGliding)
          bank:Draw(ctx(), { sortedItems = {}, tabs = { [bank:GetCurrentTabID()] = tabOf("6_", { { "C", 1 }, { LONG .. "x", 1 } }) } },
            function() end)
          assert.is_true(bank.namesOwed)
          bag:Hide(ctx())
          local glided = false
          for _ = 1, 3 do
            step(1 / 60)
            glided = glided or bank.sizeGliding
          end
          assert.is_true(bag:IsClosing())
          assert.is_true(glided, "as its anchor slides out")
          finishTweens()
          render:Flush()
          assert.is_false(bag:IsShown())
          assert.are.equal(columnsWidth(12), bank.frame:GetWidth())
          assert.are.same({}, cut(bank))
          assert.is_false(tween:IsPlaying(bank.namesKey))
        end)

        -- A closed anchor rests off its place (its slide's end), so it is never settled: waiting for it, the bank beside it waited
        -- for good, its name cut.
        it("waits for no chained anchor that is closed", function()
          inColumns()
          local bag, bank = chainedPair()
          bag:Hide(ctx())
          finishTweens()
          assert.is_false(bag:IsShown())
          bank:Draw(ctx(), { sortedItems = {}, tabs = { [bank:GetCurrentTabID()] = tabOf("6_", { { "C", 1 }, { LONG .. "x", 1 } }) } },
            function() end)
          finishTweens()
          render:Flush()
          assert.are.equal(columnsWidth(12), bank.frame:GetWidth())
          assert.are.same({}, cut(bank))
          assert.is_false(tween:IsPlaying(bank.namesKey), "nothing left trying")
        end)

        -- A glide into its spot (GlideTo) puts the panel on its place as it starts (its offset 0), as the Ice Shatter, Smoke, Beam
        -- and Paper opens do: only the tween playing on it says it is busy. It follows once it is there, beside its anchor.
        it("waits while it glides into its spot, and follows once it is there", function()
          inColumns()
          local bag, bank = chainedPair()
          override(bag.tabs, "Width", function() return 140 end)
          chain:Update(ctx())
          assert.is_true(tween:IsPlaying(bank), "gliding into its new spot")
          assert.are.equal(0, bank.offset)
          bank:Draw(ctx(), { sortedItems = {}, tabs = { [bank:GetCurrentTabID()] = tabOf("6_", { { "C", 1 }, { LONG .. "x", 1 } }) } },
            function() end)
          assert.is_true(bank.namesOwed, "it waits")
          local glided = false
          for frame = 1, 90 do
            step(1 / 60)
            assert.is_false(bank.sizeGliding and tween:IsPlaying(bank), "not while it glides into its spot, frame " .. frame)
            glided = glided or bank.sizeGliding
          end
          assert.is_true(glided, "it follows once there")
          finishTweens()
          render:Flush()
          assert.are.equal(columnsWidth(12), bank.frame:GetWidth())
          assert.are.same({}, cut(bank))
          assert.are.same({ chain:ChainedPlace(bank, bag, bag.placeX, bag.placeY) }, { topLeft(bank) })
        end)

        -- Found by the third bug review (as for a grip let go, "chained" below): a glide for its names that leaves the side the bag
        -- beside it hangs from still (the backpack where the player left it, its right edge gliding; the bank beside it, its
        -- left) leaves that bag and the braid as they are.
        for _, screen in ipairs({ { 2560, 1440, 0.71, 125 }, { 1920, 1080, 0.64, 125 }, { 1920, 1080, 1, 85 } }) do
          it(string.format("never moves the bag beside it as it glides for its names with that side still, %dx%d at %s, Bag Scale %d%%",
            screen[1], screen[2], screen[3], screen[4]), function()
            local layoutHelper = dofile("spec/helpers/layout.lua")
            finally(layoutHelper.UseScreen(screen[1], screen[2], screen[3]))
            db.bagScale = screen[4]
            inColumns()
            -- Where the player left it, with room on both sides for both bags at the width their names take, holding its bottom
            -- left (docs/next-bag-anchor.md: a corner saved on a wider screen), so its right edge glides.
            db.corners[BACKPACK] = { UIParent:GetWidth() / 2, 20, "LEFT", "BOTTOM" }
            local bag, bank = chainedPair()
            for _ = 1, 60 do chain:Turn(1 / 60) end
            assert.is_true(chain.coupling ~= nil and chain.coupling.amount == 1, "braided")
            local ppu = layoutHelper.PixelsPerUnit()
            local function left(panel)
              return layoutHelper.Rect(panel.frame).left * ppu
            end
            for _, case in ipairs({ { bag, bank, "0_", "backpack" }, { bank, bag, "6_", "bank" } }) do
              local sized, other = case[1], case[2]
              local at = left(other)
              sized:Draw(ctx(), { sortedItems = {}, tabs = { [sized:GetCurrentTabID()] = tabOf(case[3], { { "A", 1 }, { LONG, 1 } }) } },
                function() end)
              local glided = false
              for frame = 1, 60 do
                step(1 / 60)
                chain:Turn(1 / 60)
                glided = glided or sized.sizeGliding
                local why = "the " .. case[4] .. "'s glide, frame " .. frame
                assert.are.equal(at, left(other), "the bag beside it still: " .. why)
                assert.is_false(tween:IsPlaying(bag) or tween:IsPlaying(bank), "nothing glides into a spot: " .. why)
                assert.is_true(chain.coupling ~= nil and chain.coupling.target == 1, "braided: " .. why)
              end
              assert.is_true(glided, "the " .. case[4] .. " glided")
              finishTweens()
              render:Flush()
              assert.are.same({}, cut(sized))
            end
          end)
        end

        it("tries again each frame while it waits, and stops once it follows, once it closes and once the setting is off", function()
          inColumns()
          local bag = backpack()
          holding(bag, { { "A", 1 }, { "B", 1 } })
          local function waiting(why)
            for frame = 1, 3 do
              step(1 / 60)
              assert.is_true(tween:IsPlaying(bag.namesKey), why .. ", frame " .. frame)
            end
          end
          -- A grip holds it: tried each frame until the grip lets it go and it follows.
          press(bag.grips.RIGHT)
          sizeTo(bag, "RIGHT", bag.frame:GetWidth(), bag.frame:GetHeight())
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          waiting("held")
          release(bag.grips.RIGHT)
          finishTweens()
          assert.are.equal(columnsWidth(12), bag.frame:GetWidth())
          assert.is_false(tween:IsPlaying(bag.namesKey), "followed")
          -- Turned off while a grip holds it.
          press(bag.grips.RIGHT)
          sizeTo(bag, "RIGHT", bag.frame:GetWidth(), bag.frame:GetHeight())
          holding(bag, { { "A", 1 }, { LONG, 1 }, { "B", 1 } })
          waiting("held again")
          db.fitNames = false
          step(1 / 60)
          assert.is_false(tween:IsPlaying(bag.namesKey), "off")
          release(bag.grips.RIGHT)
          finishTweens()
          -- Closed while it slides in.
          db.fitNames = true
          bag:Hide(ctx())
          finishTweens()
          bag:Show(ctx())
          holding(bag, { { "A", 1 }, { "B", 1 } })
          waiting("sliding in")
          bag:Hide(ctx())
          step(1 / 60)
          assert.is_false(tween:IsPlaying(bag.namesKey), "closing")
          finishTweens()
        end)

        -- Found by the second bug review: the backpack glided for its names while the bank dropped beside it glided into its
        -- spot (a glide of the panel's own, GlideTo, keyed on the panel): it waited only for a partner's grip or size glide, and
        -- the anchor moves its partner only while the partner is settled, so the bank glided to the spot of the backpack's old
        -- width and they overlapped by 136 pixels. A panel waits while its open chained partner is busy in any way.
        -- A backpack and the bank apart, each with short names, on a screen the client lays out from the frames' anchors.
        local function pairApart()
          finally(dofile("spec/helpers/layout.lua").UseScreen(1920, 1080, 0.64))
          local bag = backpack()
          local bank = opened(function(c) return nextBank:Create(c) end)
          holding(bag, { { "A", 1 }, { "B", 1 } })
          bank:Draw(ctx(), { sortedItems = {}, tabs = { [bank:GetCurrentTabID()] = tabOf("6_", { { "C", 1 } }) } }, function() end)
          render:Flush()
          finishTweens()
          return bag, bank
        end

        -- dropBeside drops the bank a little short of its spot beside the backpack, where the backpack is now: it chains, and
        -- glides into its spot.
        local function dropBeside(bag, bank)
          local x, y = chain:ChainedPlace(bank, bag, bag:LivePlace())
          bank.mover:GetScript("OnDragStart")(bank.mover, "LeftButton")
          bank.frame:ClearAllPoints()
          bank.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x - 10, y - 10)
          bank.mover:GetScript("OnDragStop")(bank.mover)
          assert.are.equal("backpack", db.smallChain, "chained")
          assert.is_true(tween:IsPlaying(bank), "gliding into its spot")
        end

        local function apart(bag, bank)
          return bag.frame:GetLeft() - (bank.frame:GetLeft() + bank.frame:GetWidth())
        end

        for _, first in ipairs({ "the drop", "its names" }) do
          it("keeps a chained pair apart as one glides into its spot and the other for its names, " .. first .. " first", function()
            inColumns()
            local bag, bank = pairApart()
            local gap = chain:SmallGap(bank, bag)
            local function between()
              return apart(bag, bank)
            end
            if first == "the drop" then
              dropBeside(bag, bank)
              holding(bag, { { "A", 1 }, { LONG, 1 } })
              assert.is_true(bag.namesOwed, "it waits for the bag gliding into its spot")
            else
              holding(bag, { { "A", 1 }, { LONG, 1 } })
              assert.is_true(bag.sizeGliding)
              dropBeside(bag, bank)
            end
            local closest = math.huge
            for frame = 1, 120 do
              step(1 / 60)
              chain:Turn(1 / 60)
              closest = math.min(closest, between())
              if first == "the drop" then
                assert.is_false(bag.sizeGliding and tween:IsPlaying(bank), "one at a time, frame " .. frame)
              end
            end
            assert.is_true(closest > gap - 1, "never closer than their gap (" .. gap .. "): " .. closest)
            assert.is_true(math.abs(between() - gap) < 1, between() .. " apart")
            assert.is_not_nil(chain.coupling, "braided")
            render:Flush()
            assert.are.same({}, cut(bag))
            assert.are.equal(pixel:LengthIn(bag:PixelUnit(), columnsWidth(12)), bag.frame:GetWidth())
          end)
        end

        -- A bag gliding into its spot is placed by the glide of the bag beside it too (spotGlide), to wherever that glide ends,
        -- cut short or not: on its own it would be a frame behind whenever it goes first in a frame.
        it("keeps a bag gliding into its spot beside its anchor as the anchor's glide is cut short", function()
          inColumns()
          local bag, bank = pairApart()
          local gap = chain:SmallGap(bank, bag)
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          step(1 / 60)
          dropBeside(bag, bank)
          step(1 / 60)
          assert.is_true(bag.sizeGliding)
          bag:endSizeGlide()
          assert.is_true(tween:IsPlaying(bank), "still gliding into its spot")
          assert.is_true(apart(bag, bank) > gap - 1, apart(bag, bank) .. " apart")
          finishTweens()
          assert.is_true(math.abs(apart(bag, bank) - gap) < 1)
        end)

        it("lets go of its glide into its spot as that glide ends or stops short", function()
          inColumns()
          local bag, bank = pairApart()
          dropBeside(bag, bank)
          assert.is_not_nil(bank.spotGlide)
          bank:Hide(ctx())
          assert.is_nil(bank.spotGlide, "stopped by its slide out")
          finishTweens()
          bank:Show(ctx())
          finishTweens()
          dropBeside(bag, bank)
          finishTweens()
          assert.is_nil(bank.spotGlide, "ended")
        end)

        -- The Glitch theme's bursts: one every 14 seconds (none scheduled here), shoving the panel up to 14 pixels.
        local function glitchBursts()
          local glitch = addon:GetModule("NextGlitch")
          override(glitch, "Spec", function() return { Bursts = { Every = 14, Time = 0.3 }, Step = 0.06, Jitter = 14 } end)
          override(glitch, "Random", function() return 0.99 end)
          override(C_Timer, "After", function() end)
        end

        -- Found by the second bug review: a burst shoves the panel off its place (setOffset) while nothing else moves it, and a
        -- glide for its names started then set out from the shoved place, and jumped 14 pixels as it ended. A panel off its
        -- place is not settled: it follows once the burst has put it back.
        it("waits for a Glitch burst to put it back on its place, and glides from there", function()
          glitchBursts()
          inColumns()
          local bag = backpack()
          holding(bag, { { "A", 1 }, { "B", 1 } })
          finishTweens()
          local right = (topLeft(bag)) + bag.frame:GetWidth()
          bag:burst()
          step(0.15)
          assert.are_not.equal(0, bag.offset, "shoved")
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          assert.is_false(bag.sizeGliding, "not while shoved")
          local glided = false
          for frame = 1, 90 do
            step(1 / 60)
            if bag.sizeGliding then
              glided = true
              assert.is_true(math.abs((topLeft(bag)) + bag.frame:GetWidth() - right) < 0.01, "its right edge still, frame " .. frame)
            end
          end
          assert.is_true(glided)
          assert.are.equal(columnsWidth(12), bag.frame:GetWidth())
          assert.are.equal(right, (topLeft(bag)) + bag.frame:GetWidth())
        end)

        -- A burst stopped part-way (a parent hiding the panel, Alt+Z) left it shoved off its place for good, and so waiting for
        -- its names for good. It goes back to where the burst found it.
        it("goes back to its place when a burst is stopped part-way, and follows its names from there", function()
          glitchBursts()
          inColumns()
          local bag = backpack()
          holding(bag, { { "A", 1 }, { "B", 1 } })
          finishTweens()
          local x = topLeft(bag)
          bag:burst()
          step(0.15)
          assert.are_not.equal(0, bag.offset, "shoved")
          -- UIParent hidden: the panel's OnHide runs with its own shown flag still set.
          bag.frame:GetScript("OnHide")(bag.frame)
          assert.are.equal(0, bag.offset)
          assert.are.equal(x, (topLeft(bag)))
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          finishTweens()
          assert.are.equal(columnsWidth(12), bag.frame:GetWidth())
          assert.is_false(tween:IsPlaying(bag.namesKey))
        end)

        -- A parent hiding the panel (Alt+Z) stops what moves it (OnHidden): its opening slide stopped part-way left it off its
        -- place, faded, once shown again, and so waiting for its names until something placed it. It comes back on its place.
        it("comes back on its place when a parent shows it again after stopping its slide in, and follows its names", function()
          inColumns()
          local bag = nextBag:Create(ctx())
          bag:Show(ctx())
          step(style.Time.Open / 4)
          assert.are_not.equal(0, bag.offset, "sliding in")
          bag.frame:GetScript("OnHide")(bag.frame)
          bag.frame:GetScript("OnShow")(bag.frame)
          assert.are.equal(0, bag.offset)
          assert.are.equal(1, bag.frame:GetAlpha())
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          finishTweens()
          assert.are.equal(columnsWidth(12), bag.frame:GetWidth())
          assert.is_false(tween:IsPlaying(bag.namesKey))
        end)

        it("leaves where it is a panel its parent shows again as it slides out, and a full bag beside its anchor", function()
          local bag = backpack()
          bag.frame:GetScript("OnHide")(bag.frame)
          bag:Hide(ctx())
          step(style.Time.Close / 2)
          local offset = bag.offset
          assert.are_not.equal(0, offset, "sliding out")
          bag.frame:GetScript("OnShow")(bag.frame)
          assert.are.equal(offset, bag.offset, "its slide out goes on")
          finishTweens()
          db.size = "full"
          override(stubs.database, "GetNextChain", function() return "right" end)
          opened(function(c) return nextBag:Create(c) end)
          local bank = opened(function(c) return nextBank:Create(c) end)
          local rest = chain:RestOffset(bank)
          assert.are_not.equal(0, rest)
          bank.frame:GetScript("OnHide")(bank.frame)
          bank.frame:GetScript("OnShow")(bank.frame)
          assert.are.equal(rest, bank.offset, "beside its anchor")
        end)

        it("leaves the panel to a move that stops a burst", function()
          glitchBursts()
          local bag = backpack()
          bag:burst()
          step(0.15)
          bag.mover:GetScript("OnDragStart")(bag.mover, "LeftButton")
          local offsets = countCalls(bag, "setOffset")
          step(1 / 60)
          assert.are.equal(0, offsets())
          bag.mover:GetScript("OnDragStop")(bag.mover)
        end)

        -- A burst shoves the panel 14 pixels at most; the glide of the bag it sits beside places it all the same, which ends the
        -- burst, rather than leave it where it was as that bag grows into it.
        it("keeps a chained partner beside it through a burst on the partner as it glides", function()
          glitchBursts()
          finally(dofile("spec/helpers/layout.lua").UseScreen(1920, 1080, 0.64))
          inColumns()
          local bag, bank = chainedPair()
          local gap = chain:SmallGap(bank, bag)
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          assert.is_true(bag.sizeGliding)
          step(1 / 60)
          bank:burst()
          for frame = 1, 40 do
            step(1 / 60)
            local between = bag.frame:GetLeft() - (bank.frame:GetLeft() + bank.frame:GetWidth())
            assert.is_true(between > gap - 15, "frame " .. frame .. ": " .. between .. " apart")
          end
          finishTweens()
          assert.is_true(math.abs(bag.frame:GetLeft() - (bank.frame:GetLeft() + bank.frame:GetWidth()) - gap) < 1)
        end)

        -- A full bag chained beside its anchor rests away from its screen edge (next-chain.md §12), and a new screen places it
        -- at once (PlaceAt), which ends a burst under way: the burst leaves it there, not where the burst found it.
        it("leaves a full panel where a new screen puts it, ending a burst", function()
          glitchBursts()
          db.size = "full"
          override(stubs.database, "GetNextChain", function() return "right" end)
          opened(function(c) return nextBag:Create(c) end)
          local bank = opened(function(c) return nextBank:Create(c) end)
          local before = chain:RestOffset(bank)
          assert.are.equal(before, bank.offset, "beside the backpack")
          bank:burst()
          step(0.15)
          assert.are_not.equal(before, bank.offset, "shoved")
          UIParent:_SetRect(0, 0, 2000, 1200)
          chain:Update(ctx(), true)
          local after = chain:RestOffset(bank)
          assert.are_not.equal(before, after)
          step(1 / 60)
          assert.are.equal(after, bank.offset)
        end)
      end)

      -- Found by the bug review: a glide something else ended (endSizeGlide: here a size switch, which lets go of the braid
      -- first) settled the chain as it ended, braiding the pair again while they switched.
      for _, how in ipairs({ "its names", "a grip let go" }) do
        it("leaves a chained pair unbraided as it switches size while its size glides for " .. how, function()
          db.fitNames = how == "its names"
          inColumns()
          local bag = backpack()
          opened(function(c) return nextBank:Create(c) end)
          db.smallChain = "backpack"
          chain:Update(ctx())
          finishTweens()
          holding(bag, { { "A", 1 }, { "B", 1 } })
          finishTweens()
          assert.is_not_nil(chain.coupling, "braided")
          if how == "its names" then
            holding(bag, { { "A", 1 }, { LONG, 1 } })
          else
            press(bag.grips.RIGHT)
            sizeTo(bag, "RIGHT", bag.frame:GetWidth() + 300, bag.frame:GetHeight())
            release(bag.grips.RIGHT)
          end
          step(0.03)
          assert.is_true(bag.sizeGliding)
          nextPanel:SetSize(ctx(), "full")
          assert.is_nil(chain.coupling, "let go as it switches")
          step(0.05)
          assert.is_nil(chain.coupling, "not braided again while it switches")
          finishTweens()
        end)
      end

      it("fits every open small panel as Fit Names While Open is turned on (next/FitNamesChanged)", function()
        local handlers = {}
        override(stubs.events, "RegisterMessage", function(_, name, fn) handlers[name] = fn end)
        inColumns()
        local bag = backpack()
        holding(bag, { { "A", 1 }, { "B", 1 } })
        holding(bag, { { "A", 1 }, { LONG, 1 } })
        assert.are.equal(columnsWidth(8), bag.frame:GetWidth(), "off")
        db.fitNames = true
        handlers["next/FitNamesChanged"](ctx())
        render:Flush()
        assert.are.equal(columnsWidth(12), bag.frame:GetWidth())
        assert.is_nil(db.sizes[BACKPACK])
        assert.are.same({}, cut(bag))
      end)

      -- glidingFor starts the panel's size gliding: for its names (the setting on), a grip let go 300 wider, or a Shift-click
      -- back to its default from a saved width. It returns the section whose name the panel shows second.
      local function glidingFor(how)
        db.fitNames = how == "its names"
        if how == "a Shift-click" then
          db.sizes[BACKPACK] = { columnsWidth(10), 600 }
        end
        local bag = backpack()
        holding(bag, { { "A", 1 }, { "B", 1 } })
        finishTweens()
        local second = "B"
        if how == "its names" then
          second = LONG
          holding(bag, { { "A", 1 }, { LONG, 1 } })
        elseif how == "a grip let go" then
          resize(bag, "RIGHT", bag.frame:GetWidth() + 300, bag.frame:GetHeight())
        else
          _G._isShiftKeyDown = true
          press(bag.grips.RIGHT)
          release(bag.grips.RIGHT)
          _G._isShiftKeyDown = false
        end
        step(0.05)
        assert.is_true(bag.sizeGliding)
        return bag, second
      end

      -- Its frame, the size it took and the width it lays out for are one size: the one it takes now.
      local function sizedAsItTakes(bag)
        local w, h, fitted = bag:SmallSize()
        assert.are.same({ w, h }, { bag.frame:GetSize() })
        assert.are.same({ w, h, fitted }, { bag.smallWidth, bag.smallHeight, bag.restingWidth })
        assert.is_true(math.abs(bag:LayoutWidth() - bag.frame:GetWidth()) < bag:PixelUnit(), "laid out for its frame")
      end

      -- Found by the second bug review: a restyle (ApplyGeometry: a theme, an Animation switch) or a refit (FitSmall: here Clamp
      -- Bags to Screen turned on) sized the frame, then ended the size glide running (setOffset, endSizeGlide), whose end sized it
      -- again to what the glide set out for: the frame kept that, while the size it took and the width it laid out for were the
      -- new ones, until it next opened. What sizes the frame ends the glide first.
      for _, how in ipairs({ "its names", "a grip let go", "a Shift-click" }) do
        for _, by in ipairs({ "a restyle", "a refit" }) do
          it("takes the size " .. by .. " gives it while its size glides for " .. how, function()
            finally(function() _G._isShiftKeyDown = false end)
            inColumns()
            local bag, second = glidingFor(how)
            -- The new look: a taller share of the screen, and a wider font for the second section's name.
            override(style.Small, "Height", style.Small.Height + 0.1)
            measured(bag, second, 420)
            if by == "a restyle" then
              bag:ApplyStyle(ctx())
            else
              chain:ClampChanged(ctx())
            end
            finishTweens()
            render:Flush()
            sizedAsItTakes(bag)
            assert.are.same({}, cut(bag))
          end)
        end
      end

      -- Found by the second bug review: opened again as it slid out, a panel was not fitted (Show fitted only one that had
      -- finished closing), so a name it was given to show as it closed stayed cut until it next opened, setting on or off. It
      -- is fitted as any opening is, its slide going on from where it is, the edge its place holds still.
      for _, on in ipairs({ false, true }) do
        it("fits a panel opened again as it slides out, from where it is, Fit Names While Open " .. (on and "on" or "off"), function()
          db.fitNames = on
          inColumns()
          local bag = backpack()
          holding(bag, { { "A", 1 }, { "B", 1 } })
          finishTweens()
          bag:Hide(ctx())
          step(style.Time.Close / 2)
          holding(bag, { { "A", 1 }, { LONG, 1 } })
          local partway = (topLeft(bag)) - bag.placeX
          local right = (topLeft(bag)) + bag.frame:GetWidth()
          assert.is_true(partway > 0 and partway < style.Small.Slide, "part way out")
          bag:Show(ctx())
          assert.are.equal(columnsWidth(12), bag.frame:GetWidth())
          assert.are.equal(partway, (topLeft(bag)) - bag.placeX, "its slide goes on from where it is")
          assert.are.equal(right, (topLeft(bag)) + bag.frame:GetWidth(), "its right edge, which its default place holds, still")
          finishTweens()
          render:Flush()
          assert.are.equal(0, (topLeft(bag)) - bag.placeX)
          assert.are.equal(columnsWidth(12), bag.frame:GetWidth())
          assert.are.same({}, cut(bag))
          assert.is_nil(db.sizes[BACKPACK])
        end)
      end

      -- Found by the second bug review: a new Bag Scale (or screen) refits every open small panel (chain:Update, snapping), and
      -- that left alone one whose size glided: it kept its old scale and size until it next opened. A glide is refitted (its end
      -- first); only a panel a grip holds is left alone.
      for _, how in ipairs({ "its names", "a grip let go" }) do
        it("takes a new Bag Scale while its size glides for " .. how, function()
          inColumns()
          local bag = glidingFor(how)
          db.bagScale = 125
          chain:ScalesChanged(ctx())
          assert.are.equal(1.25, bag.frame:GetScale())
          assert.is_false(bag.sizeGliding)
          finishTweens()
          render:Flush()
          assert.are.equal(1.25, bag.frame:GetScale())
          sizedAsItTakes(bag)
          assert.are.same({}, cut(bag))
        end)
      end

      -- The backpack chained beside the bank: the bank anchors, and its names glide moves its facing side. Refitted mid-glide,
      -- the anchor is refitted first (its glide ended), so the backpack's spot is measured from where the anchor ends.
      it("keeps a bag beside its anchor as a new Bag Scale refits the anchor mid-glide", function()
        finally(dofile("spec/helpers/layout.lua").UseScreen(1920, 1080, 0.64))
        db.fitNames = true
        inColumns()
        local bag = backpack()
        local bank = opened(function(c) return nextBank:Create(c) end)
        db.smallChain = "companion"
        chain:Update(ctx())
        finishTweens()
        holding(bag, { { "A", 1 } })
        bank:Draw(ctx(), { sortedItems = {}, tabs = { [bank:GetCurrentTabID()] = tabOf("6_", { { "C", 1 } }) } }, function() end)
        render:Flush()
        finishTweens()
        assert.are.equal(bank, chain:SmallAnchorOf(bag))
        bank:Draw(ctx(), { sortedItems = {}, tabs = { [bank:GetCurrentTabID()] = tabOf("6_", { { "C", 1 }, { LONG, 1 } }) } },
          function() end)
        step(0.1)
        assert.is_true(bank.sizeGliding)
        db.bagScale = 125
        chain:ScalesChanged(ctx())
        local gap = chain:SmallGap(bank, bag)
        for frame = 0, 30 do
          local between = (bag.frame:GetLeft() - (bank.frame:GetLeft() + bank.frame:GetWidth())) * 1.25
          assert.is_true(math.abs(between - gap) < 1, "frame " .. frame .. ": " .. between .. " apart, not " .. gap)
          step(1 / 60)
        end
      end)
    end)

    describe("its size", function()
      it("opens at its saved size, where it was left", function()
        db.sizes[BACKPACK] = { 640, 500 }
        db.places[BACKPACK] = { 300, 900 }
        local bag = opened(function(c) return nextBag:Create(c) end)
        assert.are.same({ 640, 500 }, { bag.frame:GetWidth(), bag.frame:GetHeight() })
        assert.are.same({ 300, 900 }, { topLeft(bag) })
        assert.are.same({ 640, 500 }, { bag.root:Render().Width, bag.root:Render().Height })
      end)

      it("keeps its saved size within its minimum and the screen", function()
        db.sizes[BACKPACK] = { 10, 10 }
        db.sizes[BANK] = { 5000, 5000 }
        local bag = nextBag:Create(ctx())
        local bank = nextBank:Create(ctx())
        assert.are.same({ bag:MinWidth(), bag:MinHeight() }, { bag.frame:GetWidth(), bag.frame:GetHeight() })
        assert.are.same({ UIParent:GetWidth(), UIParent:GetHeight() }, { bank.frame:GetWidth(), bank.frame:GetHeight() })
        assert.are.same({ 10, 10 }, db.sizes[BACKPACK], "what was saved is kept")
      end)

      it("keeps a wide panel on the screen, the backpack a margin in from its edge by default", function()
        db.sizes[BACKPACK] = { 640, 500 }
        local bag = nextBag:Create(ctx())
        assert.are.equal(UIParent:GetWidth() - 640 - style.Small.Margin, topLeft(bag))
        db.places[BANK] = { 1800, 900 }
        db.sizes[BANK] = { 640, 500 }
        local bank = nextBank:Create(ctx())
        assert.are.equal(UIParent:GetWidth() - 640, topLeft(bank))
      end)

      it("lays its content out again on a screen that changes only its width", function()
        db.sizes[BACKPACK] = { 640, 500 }
        local bag = opened(function(c) return nextBag:Create(c) end)
        local renders = 0
        override(render, "Invalidate", function(_, d) if d == bag.root then renders = renders + 1 end end)
        UIParent:_SetRect(0, 0, 600, 1200)
        chain:Update(ctx(), true)
        assert.are.equal(600, bag.frame:GetWidth())
        assert.are.equal(1, renders)
      end)

      it("comes back at its saved size after a switch to full size and back", function()
        db.sizes[BACKPACK] = { 640, 500 }
        local bag = opened(function(c) return nextBag:Create(c) end)
        nextPanel:SetSize(ctx(), "full")
        finishTweens()
        assert.are.same({ style.WIDTH, UIParent:GetHeight() }, { bag.frame:GetWidth(), bag.frame:GetHeight() })
        nextPanel:SetSize(ctx(), "small")
        finishTweens()
        assert.are.same({ 640, 500 }, { bag.frame:GetWidth(), bag.frame:GetHeight() })
      end)

      -- Reported in game, with Guild Wars 2: a white border round the bag on a switch either way. A size switch showed
      -- the border's four lines whatever the theme, and a theme without a border never colors them, so they showed as
      -- created, white.
      it("shows no border on a switch either way under a theme without one, part way or after", function()
        UseNextTheme({ Panel = { Edge = false } })
        local bag = opened(function(c) return nextBag:Create(c) end)
        local seen = {}
        for _, size in ipairs({ "full", "small" }) do
          nextPanel:SetSize(ctx(), size)
          local function look(when)
            for _, edge in ipairs(bag.edges) do
              if edge:IsShown() then table.insert(seen, size .. " " .. when) return end
            end
          end
          look("as it starts")
          step(style.Time.Morph / 2)
          look("part way")
          finishTweens()
          look("after")
        end
        UseNextTheme(nil)
        assert.are.same({}, seen)
      end)

      it("glides its width as it switches to and from a small size of its own", function()
        db.sizes[BACKPACK] = { 640, 500 }
        local bag = opened(function(c) return nextBag:Create(c) end)
        nextPanel:SetSize(ctx(), "full")
        step(style.Time.Morph / 2)
        local width = bag.frame:GetWidth() - style.FEATHER
        assert.is_true(width > style.BODY_WIDTH and width < 640, "body width " .. width)
        finishTweens()
        nextPanel:SetSize(ctx(), "small")
        step(style.Time.Morph / 2)
        width = bag.frame:GetWidth()
        assert.is_true(width > style.BODY_WIDTH and width < 640, "growing body width " .. width)
        finishTweens()
        assert.are.equal(640, bag.frame:GetWidth())
      end)

      -- Narrowing, its content is laid out at once for the width it ends at, so nothing is cut off
      -- on the way; widening, once it is there.
      it("lays its content out for the narrower width when a switch starts", function()
        db.sizes[BACKPACK] = { 640, 500 }
        local bag = opened(function(c) return nextBag:Create(c) end)
        local renders = 0
        local invalidate = render.Invalidate
        override(render, "Invalidate", function(r, d)
          if d == bag.root then renders = renders + 1 end
          return invalidate(r, d)
        end)
        nextPanel:SetSize(ctx(), "full")
        assert.are.equal(1, renders, "narrowing: at once")
        finishTweens()
        assert.are.equal(2, renders, "and once it is there")
        renders = 0
        nextPanel:SetSize(ctx(), "small")
        assert.are.equal(0, renders, "widening: not yet")
        finishTweens()
        assert.are.equal(1, renders)
      end)

      it("is its saved size on a screen that changes, kept on it", function()
        db.sizes[BACKPACK] = { 640, 500 }
        local bag = opened(function(c) return nextBag:Create(c) end)
        UIParent:_SetRect(0, 0, 1280, 720)
        chain:Update(ctx(), true)
        assert.are.same({ 640, 500 }, { bag.frame:GetWidth(), bag.frame:GetHeight() })
        UIParent:_SetRect(0, 0, 600, 400)
        chain:Update(ctx(), true)
        assert.are.same({ 600, 400 }, { bag.frame:GetWidth(), bag.frame:GetHeight() })
        assert.are.same({ 640, 500 }, db.sizes[BACKPACK])
      end)

      it("sends its edge sparkles out of its inner side at its own width", function()
        db.sizes[BANK] = { 600, 500 }
        local bank = nextBank:Create(ctx())
        for _ = 1, 20 do
          local x = bank.edgeSparkles.options.Spawn()
          assert.is_true(x >= 600 and x <= 624, "bank edge sparkle at " .. x)
        end
      end)
    end)

    describe("Shift-clicking a grip", function()
      local function shiftClick(grip)
        _G._isShiftKeyDown = true
        press(grip)
        release(grip)
        _G._isShiftKeyDown = false
      end

      after_each(function()
        _G._isShiftKeyDown = false
      end)

      -- It holds its bottom (docs/next-bag-anchor.md): the right grip keeps its bottom left.
      it("glides it back to its default size, its bottom left still from the right grip", function()
        db.sizes[BACKPACK] = { 700, 500 }
        local bag = opened(function(c) return nextBag:Create(c) end)
        local x0, y0 = topLeft(bag)
        local bottom = y0 - 500
        shiftClick(bag.grips.RIGHT)
        assert.is_nil(bag.frame._sizing, "a Shift-click does not size it")
        step(style.Time.Resize / 2)
        local w, h = bag.frame:GetWidth(), bag.frame:GetHeight()
        assert.is_true(w > style.BODY_WIDTH and w < 700, "width " .. w)
        assert.is_true(h > 500 and h < smallHeight(), "height " .. h)
        local x, y = topLeft(bag)
        assert.are.equal(x0, x)
        assert.is_true(math.abs(y - h - bottom) <= 1, "its bottom still: " .. (y - h))
        finishTweens()
        assert.are.same({ style.BODY_WIDTH, smallHeight() }, { bag.frame:GetWidth(), bag.frame:GetHeight() })
        assert.is_nil(db.sizes[BACKPACK], "the default follows the screen again")
        assert.are.same({ x0, bottom + smallHeight() }, { topLeft(bag) })
        assert.are.same({ x0 + style.BODY_WIDTH, bottom, "RIGHT", "BOTTOM" }, db.corners[BACKPACK])
      end)

      -- texture-sharpening.md §5: its scroll box clips what it holds, which a fractional size drew stretched.
      it("glides in whole pixels, its far corner still on a whole pixel, from either grip", function()
        for _, side in ipairs({ "RIGHT", "LEFT" }) do
          local saved = _G.GetPhysicalScreenSize
          _G.GetPhysicalScreenSize = function() return 3396, 1362 end
          local ok, err = pcall(function()
            db.sizes[BACKPACK] = { 700, 500 }
            local bag = opened(function(c) return nextBag:Create(c) end)
            shiftClick(bag.grips[side])
            local unit = pixel:Unit(bag.frame)
            local steps = 0
            while bag.sizeGliding do
              step(1 / 60)
              local x, y = topLeft(bag)
              for _, v in ipairs({ bag.frame:GetWidth(), bag.frame:GetHeight(), x, y }) do
                local px = v / unit
                assert.is_true(math.abs(px - math.floor(px + 0.5)) < 1e-6, side .. " step " .. steps .. ": " .. px)
              end
              steps = steps + 1
            end
            assert.is_true(steps > 10, "it glided")
          end)
          _G.GetPhysicalScreenSize = saved
          assert(ok, err)
        end
      end)

      -- Its corner glides too when the default size would not fit where it is, put back on the screen (clampPlace).
      it("glides its corner in whole pixels when the screen's edge moves it", function()
        local saved = _G.GetPhysicalScreenSize
        _G.GetPhysicalScreenSize = function() return 3396, 1362 end
        local ok, err = pcall(function()
          db.sizes[BACKPACK] = { 300, 300 }
          db.places[BACKPACK] = { UIParent:GetWidth() - 301.3, 300.7 }
          local bag = opened(function(c) return nextBag:Create(c) end)
          local x0, y0 = topLeft(bag)
          shiftClick(bag.grips.RIGHT)
          local unit = pixel:Unit(bag.frame)
          local moved = false
          while bag.sizeGliding do
            step(1 / 60)
            local x, y = topLeft(bag)
            moved = moved or math.abs(x - x0) > unit or math.abs(y - y0) > unit
            for _, v in ipairs({ x, y }) do
              local px = v / unit
              assert.is_true(math.abs(px - math.floor(px + 0.5)) < 1e-6, px .. " pixels")
            end
          end
          assert.is_true(moved, "the screen's edge moved its corner")
        end)
        _G.GetPhysicalScreenSize = saved
        assert(ok, err)
      end)

      it("keeps its bottom right still from the left grip", function()
        db.sizes[BACKPACK] = { 700, 500 }
        local bag = opened(function(c) return nextBag:Create(c) end)
        local x0, y0 = topLeft(bag)
        local right, bottom = x0 + 700, y0 - 500
        shiftClick(bag.grips.LEFT)
        step(style.Time.Resize / 2)
        local x = topLeft(bag)
        assert.are.equal(right, x + bag.frame:GetWidth())
        finishTweens()
        assert.are.same({ right - style.BODY_WIDTH, bottom + smallHeight() }, { topLeft(bag) })
        assert.are.same({ right, bottom, "RIGHT", "BOTTOM" }, db.corners[BACKPACK])
      end)

      it("reflows its content as it glides, nothing gliding to its place", function()
        db.sizes[BACKPACK] = { 700, 500 }
        local bag = opened(function(c) return nextBag:Create(c) end)
        local invalidated = 0
        local invalidate = render.Invalidate
        override(render, "Invalidate", function(r, d)
          if d == bag.root then invalidated = invalidated + 1 end
          return invalidate(r, d)
        end)
        shiftClick(bag.grips.RIGHT)
        step(style.Time.Resize / 2)
        assert.is_true(invalidated >= 2)
        assert.is_true(bag.content.instant)
        assert.are.equal(bag.frame:GetWidth() - 2 * style.PAD, bag.root:PreRender().Width)
        finishTweens()
        assert.is_false(bag.content.instant)
        assert.are.equal(8, perRow(bag))
      end)

      it("does nothing at its default size", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        assert.are.equal("default", bag:ResetSize("RIGHT"))
        assert.is_false(tween:IsPlaying(bag.sizeGlideKey))
      end)

      it("ends the glide where it was going when it is moved, sized or closed", function()
        db.sizes[BACKPACK] = { 700, 500 }
        local bag = opened(function(c) return nextBag:Create(c) end)
        shiftClick(bag.grips.RIGHT)
        step(style.Time.Resize / 4)
        bag.mover:GetScript("OnDragStart")(bag.mover, "LeftButton")
        assert.are.same({ style.BODY_WIDTH, smallHeight() }, { bag.frame:GetWidth(), bag.frame:GetHeight() })
        bag.mover:GetScript("OnDragStop")(bag.mover)
        db.sizes[BACKPACK] = { 700, 500 }
        bag.frame:SetSize(700, 500)
        shiftClick(bag.grips.RIGHT)
        step(style.Time.Resize / 4)
        press(bag.grips.RIGHT)
        assert.are.equal(style.BODY_WIDTH, bag.frame:GetWidth())
        release(bag.grips.RIGHT)
        -- Escape hides it at once (no slide).
        db.sizes[BACKPACK] = { 700, 500 }
        bag.frame:SetSize(700, 500)
        shiftClick(bag.grips.RIGHT)
        step(style.Time.Resize / 4)
        assert.is_true(bag.frame:GetWidth() > style.BODY_WIDTH, "gliding")
        bag.frame:Hide()
        bag.frame:GetScript("OnHide")(bag.frame)
        assert.is_nil(db.sizes[BACKPACK])
        assert.are.equal(style.BODY_WIDTH, bag.frame:GetWidth())
      end)

      it("ends the glide where it was going as it starts to close", function()
        db.sizes[BACKPACK] = { 700, 500 }
        local bag = opened(function(c) return nextBag:Create(c) end)
        shiftClick(bag.grips.RIGHT)
        step(style.Time.Resize / 4)
        bag:Hide(ctx())
        assert.are.equal(style.BODY_WIDTH, bag.frame:GetWidth())
      end)

      it("does nothing while it closes", function()
        db.sizes[BACKPACK] = { 700, 500 }
        local bag = opened(function(c) return nextBag:Create(c) end)
        bag:Hide(ctx())
        assert.are.equal("closing", bag:ResetSize("RIGHT"))
        assert.are.same({ 700, 500 }, db.sizes[BACKPACK])
      end)

      -- A size switch mid-glide starts from where the glide was going: from the left grip, the
      -- default width with its right edge where it was.
      it("switches size from the end of the glide", function()
        db.sizes[BACKPACK] = { 700, 500 }
        local bag = opened(function(c) return nextBag:Create(c) end)
        local right = topLeft(bag) + 700
        shiftClick(bag.grips.LEFT)
        step(style.Time.Resize / 4)
        nextPanel:SetSize(ctx(), "full")
        assert.are.equal(style.BODY_WIDTH, bag.morph.at.w)
        assert.are.equal(right - style.BODY_WIDTH, bag.morph.at.x)
      end)
    end)

    -- Chained, a grip on the side facing the partner would push the partner: it is off there.
    describe("chained", function()
      -- The bank chained beside the backpack, settled into its spot.
      local function chainBank(bag, bank)
        db.smallChain = "backpack"
        chain:Update(ctx())
        finishTweens()
        return bag, bank
      end

      it("turns off the grip on the side each bag is chained on, while it is chained", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        local bank = opened(function(c) return nextBank:Create(c) end)
        assert.is_true(bag.grips.LEFT:IsShown() and bank.grips.RIGHT:IsShown(), "apart")
        chainBank(bag, bank)
        assert.is_false(bank.grips.RIGHT:IsShown(), "the bank, beside the backpack")
        assert.is_true(bank.grips.LEFT:IsShown())
        assert.is_false(bag.grips.LEFT:IsShown(), "the backpack, the bank beside it")
        assert.is_true(bag.grips.RIGHT:IsShown())
        bank:Hide(ctx())
        assert.is_true(bag.grips.LEFT:IsShown(), "nothing beside the backpack once the bank closes")
        finishTweens()
        bag:Hide(ctx())
        finishTweens()
        bank:Show(ctx())
        finishTweens()
        assert.is_false(bank.grips.RIGHT:IsShown(), "the bank's place hangs from the backpack's, open or not")
      end)

      it("turns them off the same way with the backpack chained beside the bank", function()
        local bank = opened(function(c) return nextBank:Create(c) end)
        local bag = opened(function(c) return nextBag:Create(c) end)
        db.smallChain = "companion"
        chain:UpdateCoupling()
        assert.is_false(bag.grips.LEFT:IsShown())
        assert.is_false(bank.grips.RIGHT:IsShown())
        assert.is_true(bag.grips.RIGHT:IsShown() and bank.grips.LEFT:IsShown())
      end)

      it("turns the grip off as soon as a drop chains the bag", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        local bank = opened(function(c) return nextBank:Create(c) end)
        local x, y = chain:ChainedPlace(bank, bag, bag.placeX, bag.placeY)
        bank.mover:GetScript("OnDragStart")(bank.mover, "LeftButton")
        bank.frame:_SetRect(x, y - bank.frame:GetHeight(), bank.frame:GetWidth(), bank.frame:GetHeight())
        bank.mover:GetScript("OnDragStop")(bank.mover)
        assert.are.equal("backpack", db.smallChain)
        assert.is_false(bank.grips.RIGHT:IsShown(), "before it has glided in")
      end)

      it("keeps a bag's chained side beside its partner as it is resized", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        local bank = opened(function(c) return nextBank:Create(c) end)
        chainBank(bag, bank)
        local bagLeft = topLeft(bag)
        local bankRight = select(1, topLeft(bank)) + bank.frame:GetWidth()
        local wide = columnsWidth(11)
        resize(bank, "LEFT", wide, 480)
        finishTweens()
        assert.are.equal(bankRight, select(1, topLeft(bank)) + wide, "the bank's chained side is still")
        assert.are.equal(bagLeft, select(1, topLeft(bag)))
        assert.are.same({ chain:ChainedPlace(bank, bag, bag.placeX, bag.placeY) }, { topLeft(bank) })
        -- The backpack's right edge is 40 from the screen's; the client keeps a sized frame on it.
        resize(bag, "RIGHT", 490, 480)
        finishTweens()
        assert.are.equal(bagLeft, select(1, topLeft(bag)))
        assert.are.equal(bankRight, select(1, topLeft(bank)) + wide)
      end)

      -- Found by the third bug review: a grip let go on a chained pair glided the bag beside it a pixel and back, or untwisted
      -- the braid and twisted it again: the snap placed the bag beside an anchor every frame, from the grip's edge, which stands
      -- a fraction of a pixel from where the place it saves puts it, and settled the chain as it ended (chain:Update), which
      -- glided a bag over that pixel. A grip never moves the side a bag is chained on (it has none there): the bag beside it and
      -- the braid are left as they are. Clamp Bags to Screen is off (its default): a snap wider than the screen leaves room for
      -- would move both edges.
      for _, screen in ipairs({ { 2560, 1440, 0.71, 125 }, { 1920, 1080, 1, 125 }, { 1920, 1080, 1, 85 } }) do
        for _, layout in ipairs({ "backpack", "companion" }) do
          it(string.format("never moves the bag beside it as a grip on either bag is let go, %dx%d at %s, Bag Scale %d%%, %s anchoring",
            screen[1], screen[2], screen[3], screen[4], layout), function()
            local layoutHelper = dofile("spec/helpers/layout.lua")
            finally(layoutHelper.UseScreen(screen[1], screen[2], screen[3]))
            db.bagScale = screen[4]
            db.clamp = false
            local bag = opened(function(c) return nextBag:Create(c) end)
            local bank = opened(function(c) return nextBank:Create(c) end)
            db.smallChain = layout
            chain:Update(ctx())
            finishTweens()
            bag:Draw(ctx(), { sortedItems = {}, tabs = { [1] = { categories = { { name = "A" }, { name = "B" } },
              items = { item("0_1", "A"), item("0_2", "B") },
              freeSpace = { showAll = false, buttons = { { slotkey = "9_1", count = 30 } } } } } }, function() end)
            bank:Draw(ctx(), { sortedItems = {}, tabs = { [bank:GetCurrentTabID()] = { categories = { { name = "C" } },
              items = { item("6_1", "C") } } } }, function() end)
            render:Flush()
            finishTweens()
            -- The braid twisted all the way.
            for _ = 1, 60 do chain:Turn(1 / 60) end
            assert.is_true(chain.coupling ~= nil and chain.coupling.amount == 1, "braided")
            local ppu = layoutHelper.PixelsPerUnit()
            local function left(panel)
              return layoutHelper.Rect(panel.frame).left * ppu
            end
            -- Each bag's grip away from the other: the backpack's right, the bank's left.
            for _, sized in ipairs({ bag, bank }) do
              local other = sized == bag and bank or bag
              local side = sized == bag and "RIGHT" or "LEFT"
              for _, wider in ipairs({ 37, 101, 213, 333 }) do
                local at = left(other)
                gripTo(sized, side, sized.frame:GetWidth() + wider)
                for frame = 1, 45 do
                  step(1 / 60)
                  chain:Turn(1 / 60)
                  local why = string.format("the %s's grip let go %d wider, frame %d", sized == bag and "backpack" or "bank", wider,
                    frame)
                  assert.are.equal(at, left(other), "the bag beside it still: " .. why)
                  assert.is_false(tween:IsPlaying(bag) or tween:IsPlaying(bank), "nothing glides into a spot: " .. why)
                  assert.is_true(chain.coupling ~= nil and chain.coupling.target == 1, "braided: " .. why)
                end
                finishTweens()
              end
            end
          end)
        end
      end

      -- With Clamp Bags to Screen on, a grip let go a little wider than the screen's edge leaves room for at the width it snaps
      -- to puts its place back on the screen: both its edges glide (snapTo's toX), the chained side too, and the bag beside it
      -- moves with it, settled as it ends.
      it("takes the bag beside it along where a grip let go moves both its edges", function()
        local layoutHelper = dofile("spec/helpers/layout.lua")
        finally(layoutHelper.UseScreen(2560, 1440, 0.71))
        db.bagScale = 125
        local bag = opened(function(c) return nextBag:Create(c) end)
        local bank = opened(function(c) return nextBank:Create(c) end)
        chainBank(bag, bank)
        local function between()
          return (bag.frame:GetLeft() - (bank.frame:GetLeft() + bank.frame:GetWidth())) * 1.25
        end
        local gap = chain:SmallGap(bank, bag)
        assert.is_true(math.abs(between() - gap) < 1)
        local left = bag.placeX
        gripTo(bag, "RIGHT", bag.frame:GetWidth() + 101)
        assert.is_true(bag.placeX < left - 10, "its place put back on the screen: " .. left .. " to " .. bag.placeX)
        local frames = 0
        while bag.sizeGliding do
          step(1 / 60)
          frames = frames + 1
          assert.is_true(math.abs(between() - gap) < 1, "frame " .. frames .. ": " .. between() .. " apart, not " .. gap)
        end
        finishTweens()
        assert.is_true(frames > 5)
        assert.is_true(math.abs(between() - gap) < 1)
        assert.are.same({ bank:SmallPlace() }, { bank.placeX, bank.placeY })
        assert.is_not_nil(chain.coupling)
      end)

      it("keeps the grip it is dragged by while a chain forms, until it is let go", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        local bank = opened(function(c) return nextBank:Create(c) end)
        press(bank.grips.RIGHT)
        db.smallChain = "backpack"
        chain:UpdateCoupling()
        assert.is_true(bank.grips.RIGHT:IsShown())
        release(bank.grips.RIGHT)
        assert.is_false(bank.grips.RIGHT:IsShown())
        local _ = bag
      end)

      -- The chain moves no bag the player is sizing: it places itself once let go.
      it("leaves a bag being sized where it is", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        local bank = opened(function(c) return nextBank:Create(c) end)
        chainBank(bag, bank)
        press(bank.grips.LEFT)
        sizeTo(bank, "LEFT", 620, 480)
        chain:Update(ctx())
        assert.is_false(tween:IsPlaying(bank))
        chain:Update(ctx(), true)
        assert.are.same({ 620, 480 }, { bank.frame:GetWidth(), bank.frame:GetHeight() })
        release(bank.grips.LEFT)
      end)

      -- While a bag is sized, where it is comes from its frame: the backpack chained beside the bank
      -- stays beside the bank's chained side, level with its bottom as it is now (docs/next-bag-anchor.md), and the
      -- braid spans the gap there.
      it("works out where it is from its frame while it is sized", function()
        local bank = opened(function(c) return nextBank:Create(c) end)
        local bag = opened(function(c) return nextBag:Create(c) end)
        db.smallChain = "companion"
        chain:Update(ctx())
        finishTweens()
        local x = bag:SmallPlace()
        local bankTop = select(2, topLeft(bank))
        press(bank.grips.LEFT)
        sizeTo(bank, "LEFT", 620, 480)
        local bx, by = bag:SmallPlace()
        assert.are.equal(x, bx, "the backpack's spot beside the bank's chained side")
        assert.are.equal(math.min(UIParent:GetHeight(), bankTop - 480 + bag.frame:GetHeight()), by,
          "level with the bank's bottom as it is now")
        local gap = bag:SmallLeft() - (bank.frame:GetLeft() + 620)
        chain:Turn(0.016)
        assert.are.equal(gap / 2, bag.braid.half)
        release(bank.grips.LEFT)
      end)

      -- Chained bags share a bottom line (docs/next-bag-anchor.md): a grip that moves the anchor's bottom leaves the bag beside
      -- it where it is while it is dragged, and glides it level once it is let go.
      it("glides the bag beside it level once a grip that moved its bottom is let go", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        local bank = opened(function(c) return nextBank:Create(c) end)
        chainBank(bag, bank)
        local bagTop = select(2, topLeft(bag))
        local bankAt = { topLeft(bank) }
        press(bag.grips.RIGHT)
        sizeTo(bag, "RIGHT", bag.frame:GetWidth(), 900)
        assert.are.equal(bagTop - 900 + bank.frame:GetHeight(), select(2, bank:SmallPlace()), "its spot level with it")
        assert.are.same(bankAt, { topLeft(bank) }, "left where it was while the grip is dragged")
        release(bag.grips.RIGHT)
        step(1 / 60)
        assert.is_true(tween:IsPlaying(bank), "gliding level")
        finishTweens()
        local _, bankTop = topLeft(bank)
        assert.are.equal(bagTop - 900, bankTop - bank.frame:GetHeight(), "their bottoms level")
        assert.are.same({ bank:SmallPlace() }, { bank.placeX, bank.placeY })
      end)

      it("does not chain a backpack too wide to sit beside the bank on the screen", function()
        db.sizes[BACKPACK] = { 1000, 480 }
        db.places[BANK] = { 400, 900 }
        local bank = opened(function(c) return nextBank:Create(c) end)
        local bag = opened(function(c) return nextBag:Create(c) end)
        local x, y = chain:ChainedPlace(bag, bank, bank.placeX, bank.placeY)
        assert.is_nil((chain:Dropped(bag, x, y)))
      end)

      it("sits beside a partner of any width", function()
        db.sizes[BANK] = { 620, 480 }
        db.sizes[BACKPACK] = { 560, 480 }
        local bag = nextBag:Create(ctx())
        local bank = nextBank:Create(ctx())
        local gap = chain:SmallGap(bank, bag)
        assert.are.same({ 1000 - gap - 620, 900 }, { chain:ChainedPlace(bank, bag, 1000, 900) })
        assert.are.same({ 100 + 620 + gap, 900 }, { chain:ChainedPlace(bag, bank, 100, 900) })
      end)

      it("braids across the gap between bags of any width", function()
        db.sizes[BANK] = { 620, 480 }
        local bag = opened(function(c) return nextBag:Create(c) end)
        local bank = opened(function(c) return nextBank:Create(c) end)
        chainBank(bag, bank)
        local gap = bag:SmallLeft() - (bank:SmallLeft() + 620)
        assert.are.equal(gap / 2, bank.braid.half)
      end)
    end)

    -- Autosize Bags (Appearance → Size, next-small-autosize.md). Asked: "it should make it so the bag grows on the vertical
    -- (Y axis) to hold all items + free space the user currently has, keeping the X size as is"; then, of the plan: "follow
    -- live", "yes always at least as tall as tab rail", "yes move the bag up just enough", "yes vendor bag too".
    describe("autosizing its height", function()
      local layoutHelper = dofile("spec/helpers/layout.lua")

      before_each(function()
        db.autosize = true
      end)

      -- contents is a tab of n items in one category, and Free Space.
      local function contents(n)
        local items = {}
        for i = 1, n do table.insert(items, item("0_" .. i, "Herbs")) end
        return { sortedItems = {}, tabs = { [1] = { categories = { { name = "Herbs" } }, items = items,
          freeSpace = { showAll = false, buttons = { { slotkey = "9_1", count = 30 } } } } } }
      end

      -- settle runs two seconds of frames, each rendering what waits for it: an opening, a glide and what follows it end in
      -- less. A panel's effects (its sparkles, its spark) play for as long as it is open.
      local function settle()
        for _ = 1, 120 do
          render:Flush()
          local update = tween.driver and tween.driver:GetScript("OnUpdate")
          if update ~= nil then
            update(tween.driver, 1 / 60)
          end
        end
        render:Flush()
      end

      local function holding(panel, n)
        panel:Draw(ctx(), contents(n), function() end)
        render:Flush()
      end

      -- holds opens a backpack holding n items.
      local function holds(n)
        local bag = nextBag:Create(ctx())
        bag:Draw(ctx(), contents(n), function() end)
        bag:Show(ctx())
        settle()
        return bag
      end

      -- fitted is the height that shows everything panel holds: its header, what it holds as laid out, then as much room as
      -- between its sections down to its footer's line (asked: the room from the last section's item buttons "to the border to
      -- the currency/money section, is too small, make this a bit wider"), and the footer below the line.
      local function fitted(panel)
        local line = select(5, panel.footerLine:GetPoint(1))
        return style.CONTENT_TOP + panel.content.frame:GetHeight() + style.SECTION_SPACING + line
      end

      -- showsAll says its scroll area is as tall as what it holds: nothing to scroll.
      local function showsAll(panel)
        return panel.root:PreRender().Height >= panel.content.frame:GetHeight()
      end

      local function top(panel)
        return select(2, topLeft(panel))
      end

      local LONG = string.rep("n", 40)

      -- The defaults: two columns side to side, wide sections on (so its width decides its rows, and a long name its width).
      local function inColumns()
        override(stubs.database, "GetNextSectionColumns", function() return 2 end)
        override(stubs.database, "GetNextSectionSpan", function() return true end)
      end

      -- twoSections is a backpack tab of n items in "A" and one in a section named name.
      local function twoSections(n, name)
        local items = { item("0_0", name) }
        for i = 1, n do table.insert(items, item("0_" .. i, "A")) end
        return { sortedItems = {}, tabs = { [1] = { categories = { { name = "A" }, { name = name } }, items = items } } }
      end

      -- dragTo drags panel by its title row and drops it with its top left at x, y on the screen.
      local function dragTo(panel, x, y)
        panel.mover:GetScript("OnDragStart")(panel.mover, "LeftButton")
        local f, s = panel.frame, panel:Scale()
        f:_SetRect(x / s, y / s - f:GetHeight(), f:GetWidth(), f:GetHeight())
        panel.mover:GetScript("OnDragStop")(panel.mover)
      end

      -- bankTab is the bank's tab of n items.
      local function bankTab(bank, n)
        local items = {}
        for i = 1, n do table.insert(items, item("6_" .. i, "Ore")) end
        return { sortedItems = {}, tabs = { [bank:GetCurrentTabID()] = { categories = { { name = "Ore" } }, items = items } } }
      end

      -- Never placed, it holds its own side's bottom corner where a bag of the default size has it (docs/next-bag-anchor.md).
      it("opens as tall as its header, what it holds and its footer, as wide as it was, over the bottom it holds", function()
        local bag = holds(20)
        local h = bag.frame:GetHeight()
        assert.are.equal(style.BODY_WIDTH, bag.frame:GetWidth())
        assert.are.equal(fitted(bag), h)
        assert.is_true(h < smallHeight(), "shorter than the share of the screen it takes otherwise")
        assert.is_true(showsAll(bag))
        assert.are.equal((UIParent:GetHeight() - smallHeight()) / 2 + h, top(bag))
        assert.is_nil(db.sizes[BACKPACK])
      end)

      it("is never shorter than its minimum", function()
        local bag = nextBag:Create(ctx())
        bag:Draw(ctx(), { sortedItems = {}, tabs = { [1] = { categories = {}, items = {} } } }, function() end)
        bag:Show(ctx())
        settle()
        assert.is_true(fitted(bag) < bag:MinHeight())
        assert.are.equal(bag:MinHeight(), bag.frame:GetHeight())
      end)

      it("glides taller as items come in and shorter as they go, a frame on, its bottom where it was left, saving nothing", function()
        db.places[BACKPACK] = { 300, 700 }
        local bag = holds(8)
        local short = bag.frame:GetHeight()
        assert.are.equal(fitted(bag), short)
        local bottom = 700 - short
        holding(bag, 64)
        assert.is_false(bag.sizeGliding, "a frame on")
        step(1 / 60)
        assert.is_true(bag.sizeGliding)
        local tall = fitted(bag)
        assert.is_true(tall > short)
        local frames = 0
        while bag.sizeGliding do
          step(1 / 60)
          render:Flush()
          frames = frames + 1
          local h = bag.frame:GetHeight()
          assert.is_true(h >= short and h <= tall, "frame " .. frames .. ": " .. h)
          assert.are.equal(bottom, top(bag) - h, "its bottom still")
          assert.are.equal(style.BODY_WIDTH, bag.frame:GetWidth(), "its width as it was")
        end
        assert.is_true(frames > 5)
        settle()
        assert.are.equal(tall, bag.frame:GetHeight())
        assert.is_true(showsAll(bag))
        holding(bag, 8)
        settle()
        assert.are.equal(short, bag.frame:GetHeight())
        assert.are.same({ 300, 700 }, { topLeft(bag) })
        assert.is_nil(db.sizes[BACKPACK])
        assert.are.same({ 300, bottom, "LEFT", "BOTTOM" }, db.corners[BACKPACK])
      end)

      it("keeps the bottom it holds where it was never placed, on the way too", function()
        local bag = holds(8)
        local bottom = (UIParent:GetHeight() - smallHeight()) / 2
        holding(bag, 64)
        step(1 / 60)
        assert.is_true(bag.sizeGliding)
        while bag.sizeGliding do
          step(1 / 60)
          render:Flush()
          local h = bag.frame:GetHeight()
          assert.are.equal(bottom, top(bag) - h, "its bottom still: " .. top(bag) .. ", " .. h)
        end
        settle()
        local h = bag.frame:GetHeight()
        assert.are.equal(fitted(bag), h)
        assert.are.equal(bottom + h, top(bag))
      end)

      it("grows no taller than the screen, and what it holds past that scrolls", function()
        local bag = holds(8)
        holding(bag, 800)
        settle()
        assert.are.equal(UIParent:GetHeight(), bag.frame:GetHeight())
        assert.are.equal(UIParent:GetHeight(), top(bag))
        assert.is_false(showsAll(bag))
      end)

      -- Its top kept on the screen as it grows, pushed down and back up: "holding its bottom corner" (docs/next-bag-anchor.md),
      -- at Bag Scale 100% and 150%. It held its top before, and was raised to keep its bottom on the screen.

      it("is never shorter than its tab rail, as tabs come and go too", function()
        override(stubs.database, "GetGroupsEnabled", function() return true end)
        local all = {}
        for i = 1, 16 do all[i] = { id = i, name = "Group " .. i } end
        override(stubs.groups, "GetAllGroups", function() return all end)
        local bag = holds(1)
        local rail = bag.tabs.frame
        assert.is_true(rail:IsShown())
        assert.is_true(style.CONTENT_TOP + rail:GetHeight() > fitted(bag), "its tabs reach past what it holds")
        assert.are.equal(math.ceil(style.CONTENT_TOP + rail:GetHeight() - 1e-6), bag.frame:GetHeight())
        local h = bag.frame:GetHeight()
        for i = 17, 20 do all[i] = { id = i, name = "Group " .. i } end
        bag:RefreshTabs()
        settle()
        assert.is_true(bag.frame:GetHeight() > h)
        assert.are.equal(math.ceil(style.CONTENT_TOP + rail:GetHeight() - 1e-6), bag.frame:GetHeight())
      end)

      it("waits while it is moved, and fits once it is dropped", function()
        db.places[BACKPACK] = { 300, 1100 }
        local bag = holds(8)
        local short = bag.frame:GetHeight()
        bag.mover:GetScript("OnDragStart")(bag.mover, "LeftButton")
        holding(bag, 64)
        step(1 / 60)
        step(1 / 60)
        assert.is_false(bag.sizeGliding, "not while it is moved")
        assert.are.equal(short, bag.frame:GetHeight())
        bag.mover:GetScript("OnDragStop")(bag.mover)
        settle()
        assert.are.equal(fitted(bag), bag.frame:GetHeight())
      end)

      -- Asked: "don't lock dragging on the Y axis when resizing the window. let it drag larger, but then "bounce" it back to the
      -- size it should be on the Y axis."
      it("lets a grip size it either way, then bounces its height back to what the width it is let go at shows, over the bottom "
        .. "it holds", function()
        -- Low enough that it never reaches the screen's top.
        db.places[BACKPACK] = { 300, 800 }
        local bag = holds(40)
        local h0 = bag.frame:GetHeight()
        local bottom = 800 - h0
        press(bag.grips.RIGHT)
        local b = bag.frame._resizeBounds
        assert.are.same({ bag:MinWidth(), bag:MinHeight(), UIParent:GetWidth(), UIParent:GetHeight() },
          { b.minWidth, b.minHeight, b.maxWidth, b.maxHeight }, "its height free, as with the setting off")
        sizeTo(bag, "RIGHT", columnsWidth(4), h0 + 300)
        render:Flush()
        assert.are.equal(h0 + 300 - style.CONTENT_TOP - style.FOOTER, bag.root:PreRender().Height, "as tall as it is dragged")
        release(bag.grips.RIGHT)
        assert.is_true(bag.sizeGliding)
        local lowest = math.huge
        while bag.sizeGliding do
          step(1 / 60)
          render:Flush()
          lowest = math.min(lowest, bag.frame:GetHeight())
          assert.are.equal(300, (topLeft(bag)), "its left edge still")
        end
        settle()
        local h = bag.frame:GetHeight()
        assert.are.equal(columnsWidth(4), bag.frame:GetWidth())
        assert.are.equal(fitted(bag), h)
        assert.is_true(h > h0 and h < h0 + 300, "back from where it was dragged, taller for its narrower rows")
        assert.is_true(lowest < h, "bouncing past it: " .. lowest .. ", " .. h)
        assert.are.same({ 300, bottom + h }, { topLeft(bag) }, "back over the bottom it holds")
        assert.are.same({ 300, bottom, "LEFT", "BOTTOM" }, db.corners[BACKPACK])
        assert.are.same({ columnsWidth(4) }, db.sizes[BACKPACK], "its width saved, and no height")
      end)

      it("bounces back to what it shows where a grip only dragged it taller or shorter, saving nothing", function()
        db.places[BACKPACK] = { 300, 1100 }
        local bag = holds(40)
        local w0, h0 = bag.frame:GetWidth(), bag.frame:GetHeight()
        for _, dh in ipairs({ 250, -150 }) do
          resize(bag, "RIGHT", w0, h0 + dh)
          assert.is_true(bag.sizeGliding, "bouncing back from " .. dh)
          step(1 / 60)
          local first = bag.frame:GetHeight()
          assert.is_true(math.abs(first - h0) > 1 and math.abs(first - (h0 + dh)) < math.abs(dh),
            "gliding from where it was let go, not jumping: " .. first)
          settle()
          assert.are.same({ w0, h0 }, { bag.frame:GetWidth(), bag.frame:GetHeight() }, "back from " .. dh)
          assert.are.same({ 300, 1100 }, { topLeft(bag) })
        end
        assert.is_nil(db.sizes[BACKPACK])
        -- What it was taken over at as it opened (docs/next-bag-anchor.md), and nothing since.
        assert.are.same({ 300, 1100 - h0, "LEFT", "BOTTOM" }, db.corners[BACKPACK])
      end)

      it("leaves as much room below what it shows, down to its footer's line, as between its sections", function()
        local bag = holds(20)
        local line = select(5, bag.footerLine:GetPoint(1))
        local below = bag.frame:GetHeight() - style.CONTENT_TOP - bag.content.frame:GetHeight() - line
        assert.are.equal(style.SECTION_SPACING, below)
      end)

      -- Found by the bug review: the let-go laid out at the width it was let go at, took that height, and then glided again to
      -- the height of the width it snapped to (wider for a name), up to the screen's height first.
      it("glides its height once where a grip let go snaps wider for a section's name, never past where it ends", function()
        db.places[BACKPACK] = { 300, 1100 }
        local bag = nextBag:Create(ctx())
        bag:Draw(ctx(), twoSections(60, LONG), function() end)
        bag:Show(ctx())
        settle()
        local snaps = countCalls(bag, "snapTo")
        resize(bag, "RIGHT", columnsWidth(3), bag.frame:GetHeight())
        local highest = 0
        for _ = 1, 120 do
          step(1 / 60)
          render:Flush()
          highest = math.max(highest, bag.frame:GetHeight())
        end
        assert.are.equal(1, snaps(), "one glide")
        assert.are.equal(fitted(bag), bag.frame:GetHeight())
        assert.is_true(highest <= bag.frame:GetHeight() + 1e-6, "never taller than it ends: " .. highest)
      end)

      it("glides its height and width together where a grip let go fits it", function()
        db.places[BACKPACK] = { 300, 1100 }
        local bag = holds(40)
        local h0 = bag.frame:GetHeight()
        local snaps = countCalls(bag, "snapTo")
        resize(bag, "RIGHT", columnsWidth(4) + 20, h0)
        assert.is_true(bag.sizeGliding)
        settle()
        assert.are.equal(1, snaps(), "one glide")
        assert.are.same({ columnsWidth(4), fitted(bag) }, { bag.frame:GetWidth(), bag.frame:GetHeight() })
      end)

      -- Clamp Bags to Screen off: a grip let go that makes it taller grows it up from the bottom it holds as it glides
      -- (docs/next-bag-anchor.md), and it goes back down as it shrinks.
      it("grows up from the bottom it holds where a grip let go makes it taller, and back down as it shrinks", function()
        db.clamp = false
        db.places[BACKPACK] = { 300, 600 }
        local bag = holds(40)
        local h0 = bag.frame:GetHeight()
        assert.is_true(h0 < 600)
        assert.are.equal(600, top(bag))
        local bottom = 600 - h0
        resize(bag, "RIGHT", columnsWidth(3), h0)
        assert.is_true(bag.sizeGliding)
        while bag.sizeGliding do
          step(1 / 60)
          render:Flush()
          assert.are.equal(bottom, top(bag) - bag.frame:GetHeight(), "its bottom still")
        end
        settle()
        local h = bag.frame:GetHeight()
        assert.is_true(h > 600)
        assert.are.equal(fitted(bag), h)
        assert.are.equal(bottom + h, top(bag))
        assert.are.same({ 300, bottom, "LEFT", "BOTTOM" }, db.corners[BACKPACK], "where it was left, saved")
        holding(bag, 8)
        settle()
        assert.are.equal(bottom + bag.frame:GetHeight(), top(bag))
      end)

      -- Pushed down to keep its top on the screen, a Shift-click saves the bottom it holds, not where it was pushed to, so it
      -- goes back up once the width it glides to shows it all (the mirror of a bag that held its top and was raised).
      it("goes back up to the bottom it holds once the width Shift-click glides it to shows it all", function()
        db.clamp = false
        db.sizes[BACKPACK] = { columnsWidth(3), 300 }
        db.corners[BACKPACK] = { 300, 600, "LEFT", "BOTTOM" }
        local bag = holds(40)
        local h = bag.frame:GetHeight()
        assert.is_true(600 + h > UIParent:GetHeight())
        assert.are.equal(UIParent:GetHeight(), top(bag), "pushed down as it opened")
        assert.are.equal("resetting", bag:ResetSize("RIGHT"))
        settle()
        assert.are.equal(columnsWidth(8), bag.frame:GetWidth())
        assert.are.equal(fitted(bag), bag.frame:GetHeight())
        assert.are.equal(600, top(bag) - bag.frame:GetHeight())
        assert.are.same({ 300, 600, "LEFT", "BOTTOM" }, db.corners[BACKPACK])
      end)

      -- Clamp Bags to Screen keeps a top saved past the screen's on it as it opens; that is where it is taken over, and a grip
      -- let go saves where it is then, as before (the setting on: found by the bug review, it kept the saved top past the
      -- screen's).
      for _, on in ipairs({ false, true }) do
        it("saves where Clamp Bags to Screen keeps its top as a grip is let go, the setting " .. (on and "on" or "off"), function()
          db.autosize = on
          db.places[BACKPACK] = { 300, UIParent:GetHeight() + 200 }
          local bag = holds(8)
          assert.are.equal(UIParent:GetHeight(), top(bag))
          local h0 = bag.frame:GetHeight()
          resize(bag, "RIGHT", columnsWidth(6) + 5, bag.frame:GetHeight())
          settle()
          assert.are.same({ 300, UIParent:GetHeight() - h0, "LEFT", "BOTTOM" }, db.corners[BACKPACK])
        end)
      end

      it("opens at the height what it holds needs at the width it opens at, with nothing to glide after", function()
        inColumns()
        local bag = nextBag:Create(ctx())
        bag:Draw(ctx(), twoSections(30, "B"), function() end)
        bag:Show(ctx())
        settle()
        local narrow = bag.frame:GetWidth()
        bag:Hide(ctx())
        settle()
        bag:Draw(ctx(), twoSections(30, LONG), function() end)
        local snaps = countCalls(bag, "snapTo")
        bag:Show(ctx())
        settle()
        assert.is_true(bag.frame:GetWidth() > narrow, "wider for its names")
        assert.are.equal(fitted(bag), bag.frame:GetHeight())
        assert.are.equal(0, snaps(), "taken as it opened")
      end)

      it("keeps the height the player gave it for when Autosize is off", function()
        db.sizes[BACKPACK] = { columnsWidth(8), 300 }
        local bag = holds(64)
        assert.are.equal(fitted(bag), bag.frame:GetHeight())
        assert.is_true(bag.frame:GetHeight() > 300)
        resize(bag, "RIGHT", columnsWidth(6) + 5, bag.frame:GetHeight())
        settle()
        assert.are.same({ columnsWidth(6), 300 }, db.sizes[BACKPACK])
      end)

      it("takes the height the player gave it once turned off, and fits again once turned on (next/AutosizeChanged)", function()
        local handlers = {}
        override(stubs.events, "RegisterMessage", function(_, name, fn) handlers[name] = fn end)
        db.sizes[BACKPACK] = { columnsWidth(8), 300 }
        local bag = holds(64)
        local h = fitted(bag)
        assert.are.equal(h, bag.frame:GetHeight())
        assert.is_true(h > 300)
        db.autosize = false
        handlers["next/AutosizeChanged"](ctx())
        settle()
        assert.are.equal(300, bag.frame:GetHeight())
        db.autosize = true
        handlers["next/AutosizeChanged"](ctx())
        settle()
        assert.are.equal(h, bag.frame:GetHeight())
      end)

      it("glides back to its default width with Shift-click, then fits what that width holds", function()
        db.sizes[BACKPACK] = { columnsWidth(4), 300 }
        db.places[BACKPACK] = { 300, 1100 }
        local bag = holds(40)
        assert.are.equal(columnsWidth(4), bag.frame:GetWidth())
        local narrow = bag.frame:GetHeight()
        assert.are.equal(fitted(bag), narrow)
        assert.are.equal("resetting", bag:ResetSize("RIGHT"))
        settle()
        assert.are.equal(columnsWidth(8), bag.frame:GetWidth())
        assert.are.equal(fitted(bag), bag.frame:GetHeight())
        assert.is_true(bag.frame:GetHeight() < narrow)
        assert.is_nil(db.sizes[BACKPACK])
      end)

      -- Chained bags share a bottom line (docs/next-bag-anchor.md): level is their bottoms.
      it("keeps the bag chained beside it level with it as its top moves", function()
        finally(layoutHelper.UseScreen(1920, 1200, 0.64))
        local bag = holds(8)
        local bank = nextBank:Create(ctx())
        bank:Show(ctx())
        db.smallChain = "backpack"
        chain:Update(ctx())
        settle()
        local function level()
          local a, b = layoutHelper.Rect(bag.frame).bottom, layoutHelper.Rect(bank.frame).bottom
          return math.abs(a - b) < 0.01, a .. ", " .. b
        end
        assert.is_true(level())
        holding(bag, 80)
        step(1 / 60)
        assert.is_true(bag.sizeGliding)
        local y0 = layoutHelper.Rect(bag.frame).top
        while bag.sizeGliding do
          step(1 / 60)
          render:Flush()
          local ok, why = level()
          assert.is_true(ok, "level on the way: " .. why)
        end
        settle()
        assert.is_true(layoutHelper.Rect(bag.frame).top > y0, "its top moved, up from its bottom")
        assert.is_true(level())
        assert.are.same({ chain:ChainedPlace(bank, bag, bag.placeX, bag.placeY) }, { bank.placeX, bank.placeY })
      end)

      it("glides a chained pair's heights one at a time, level all the way", function()
        finally(layoutHelper.UseScreen(1920, 1200, 0.64))
        local bag = holds(8)
        local bank = nextBank:Create(ctx())
        bank:Show(ctx())
        db.smallChain = "backpack"
        chain:Update(ctx())
        settle()
        local function level()
          return math.abs(layoutHelper.Rect(bag.frame).bottom - layoutHelper.Rect(bank.frame).bottom) < 0.01
        end
        holding(bag, 80)
        bank:Draw(ctx(), bankTab(bank, 60), function() end)
        render:Flush()
        local both = false
        for frame = 1, 120 do
          step(1 / 60)
          render:Flush()
          both = both or (bag.sizeGliding and bank.sizeGliding)
          assert.is_true(level(), "level, frame " .. frame)
        end
        assert.is_false(both, "one at a time")
        settle()
        assert.are.equal(fitted(bag), bag.frame:GetHeight())
        assert.are.equal(fitted(bank), bank.frame:GetHeight())
        assert.is_true(level())
      end)

      -- Found by the bug review: switching to small, the backpack beside a companion took its spot from the companion's top for
      -- the companion's old height, glided there, and jumped 184 pixels as the switch ended.
      it("switches a chained pair to small level all the way there, the backpack beside a companion", function()
        finally(layoutHelper.UseScreen(1920, 1200, 0.64))
        db.size = "full"
        db.smallChain = "companion"
        local bag = holds(64)
        local bank = nextBank:Create(ctx())
        bank:Draw(ctx(), bankTab(bank, 8), function() end)
        bank:Show(ctx())
        settle()
        nextPanel:SetSize(ctx(), "small")
        local last
        for _ = 1, 200 do
          if bag.morph == nil then break end
          step(1 / 60)
          render:Flush()
          if bag.morph ~= nil then last = layoutHelper.Rect(bag.frame).top end
        end
        settle()
        local a, b = layoutHelper.Rect(bag.frame).bottom, layoutHelper.Rect(bank.frame).bottom
        assert.is_true(math.abs(a - b) < 0.01, "level: " .. a .. ", " .. b)
        local t = layoutHelper.Rect(bag.frame).top
        assert.is_true(math.abs(last - t) < 0.01, "the switch glided it there: " .. last .. ", " .. t)
      end)

      -- Found by the bug review: a companion whose size glide moved the backpack beside it (its centered top following its
      -- height, or its edge for a name) saved nowhere where the backpack went, so once the companion closed the backpack's next
      -- height glide took it back to where it was saved, its left edge jumping as the glide ended. Their bottoms level now
      -- (docs/next-bag-anchor.md), the companion's height no longer moves it: it stays where it is, and holds its bottom.
      for _, how in ipairs({ "its height", "a name", "a Bag Scale", "height, closed by Escape" }) do
        it("keeps the backpack where a companion's " .. how .. " left it, once the companion closes", function()
          finally(layoutHelper.UseScreen(1920, 1200, 0.64))
          db.fitNames = how == "a name"
          local bank = nextBank:Create(ctx())
          bank:Draw(ctx(), bankTab(bank, 4), function() end)
          bank:Show(ctx())
          settle()
          local bag = holds(8)
          db.smallChain = "companion"
          chain:Update(ctx())
          settle()
          -- As a drop beside the bank saves it (StopMove).
          db.corners[BACKPACK] = cornerFor(bag, bag.placeX, bag.placeY)
          local x0, y0 = bag.placeX, bag.placeY
          if how == "a name" then
            local long = string.rep("W", 70)
            bank:Draw(ctx(), { sortedItems = {}, tabs = { [bank:GetCurrentTabID()] = { categories = { { name = "Ore" },
              { name = long } }, items = { item("6_1", "Ore"), item("6_2", long) } } } }, function() end)
          elseif how == "a Bag Scale" then
            db.bagScale = 85
            chain:ScalesChanged(ctx())
          else
            bank:Draw(ctx(), bankTab(bank, 60), function() end)
          end
          render:Flush()
          settle()
          local x1, y1 = bag.placeX, bag.placeY
          local b1 = y1 - bag.frame:GetHeight() * bag:Scale()
          if how == "its height" or how == "height, closed by Escape" then
            assert.are.same({ x0, y0 }, { x1, y1 }, "level with the bank's bottom, which the bank holds: not moved")
          else
            assert.is_true(x1 ~= x0 or y1 ~= y0, "moved with the bank")
          end
          if how == "height, closed by Escape" then
            -- Escape hides it at once, with no slide; the client fires its OnHide (OnHidden), the mock does not.
            bank.frame:Hide()
            bank.frame:GetScript("OnHide")(bank.frame)
          else
            bank:Hide(ctx())
          end
          settle()
          holding(bag, 40)
          local left = layoutHelper.Rect(bag.frame).left
          for frame = 1, 60 do
            step(1 / 60)
            render:Flush()
            assert.is_true(math.abs(layoutHelper.Rect(bag.frame).left - left) < 0.01, "its left edge still, frame " .. frame)
          end
          settle()
          assert.are.same({ x1, b1 }, { bag.placeX, bag.placeY - bag.frame:GetHeight() * bag:Scale() }, "its bottom still")
        end)
      end

      -- Found by the second bug review: the chain kept which bag was chained only where it updated, which a pair chained by a
      -- size switch or a drop never did, so closing the companion saved nothing; the backpack's next height glide slid it 550
      -- units to its default place, or back to where it was dropped.
      for _, how in ipairs({ "switching to small", "a drop, the companion's glide cut short by its close" }) do
        it("keeps the backpack where it stands as its companion closes, chained by " .. how, function()
          finally(layoutHelper.UseScreen(1920, 1200, 0.64))
          local bag, bank
          if how == "switching to small" then
            db.size = "full"
            db.smallChain = "companion"
            bag = holds(8)
            bank = nextBank:Create(ctx())
            bank:Draw(ctx(), bankTab(bank, 8), function() end)
            bank:Show(ctx())
            settle()
            nextPanel:SetSize(ctx(), "small")
            settle()
          else
            bank = nextBank:Create(ctx())
            bank:Draw(ctx(), bankTab(bank, 4), function() end)
            bank:Show(ctx())
            settle()
            bag = holds(8)
            local wx, wy = chain:ChainedPlace(bag, bank, bank:SmallPlace())
            dragTo(bag, wx + 3, wy - 3)
            settle()
            assert.are.equal("companion", db.smallChain)
            bank:Draw(ctx(), bankTab(bank, 80), function() end)
            render:Flush()
            for _ = 1, 4 do
              step(1 / 60)
              render:Flush()
            end
            assert.is_true(bank.sizeGliding, "the bank's height glides as it closes")
          end
          bank:Hide(ctx())
          settle()
          local x1 = bag.placeX
          local b1 = bag.placeY - bag.frame:GetHeight()
          holding(bag, 40)
          local left = layoutHelper.Rect(bag.frame).left
          for frame = 1, 60 do
            step(1 / 60)
            render:Flush()
            assert.is_true(math.abs(layoutHelper.Rect(bag.frame).left - left) < 0.01, "its left edge still, frame " .. frame)
          end
          settle()
          assert.are.same({ x1, b1 }, { bag.placeX, bag.placeY - bag.frame:GetHeight() }, "its bottom still")
        end)
      end

      -- A backpack closed beside its companion keeps the place it had (where it was dropped) as the companion closes after it.
      -- A name widening the companion moves it (their bottoms level, the companion's height no longer does).
      it("leaves a closed backpack's place as it was as its companion closes after it", function()
        finally(layoutHelper.UseScreen(1920, 1200, 0.64))
        db.fitNames = true
        local bank = nextBank:Create(ctx())
        bank:Draw(ctx(), bankTab(bank, 4), function() end)
        bank:Show(ctx())
        settle()
        local bag = holds(8)
        db.smallChain = "companion"
        chain:Update(ctx())
        settle()
        db.corners[BACKPACK] = cornerFor(bag, bag.placeX, bag.placeY)
        local saved = { db.corners[BACKPACK][1], db.corners[BACKPACK][2], db.corners[BACKPACK][3], db.corners[BACKPACK][4] }
        local x0 = bag.placeX
        local long = string.rep("W", 70)
        bank:Draw(ctx(), { sortedItems = {}, tabs = { [bank:GetCurrentTabID()] = { categories = { { name = "Ore" },
          { name = long } }, items = { item("6_1", "Ore"), item("6_2", long) } } } }, function() end)
        render:Flush()
        settle()
        assert.is_true(bag.placeX ~= x0, "carried with the bank's edge")
        bag:Hide(ctx())
        settle()
        bank:Hide(ctx())
        settle()
        assert.are.same(saved, db.corners[BACKPACK])
      end)

      -- Found by the third bug review: the client fires OnHide as the slide's end hides the companion, and that saved the backpack
      -- again, with the top its own growth had raised it to meanwhile; and a backpack raised beside its companion kept that raise.
      -- Holding its bottom (docs/next-bag-anchor.md), the mirror: pushed down to keep its top on the screen, it goes back up.
      for _, clamp in ipairs({ false, true }) do
        for _, how in ipairs({ "as it closes", "as its slide ends" }) do
          it("goes back up to its spot beside a companion once that closes, pushed down " .. how .. ", Clamp Bags to Screen "
            .. (clamp and "on" or "off"), function()
            db.clamp = clamp
            db.places[BANK] = { 100, 900 }
            local bank = nextBank:Create(ctx())
            bank:Draw(ctx(), bankTab(bank, 4), function() end)
            bank:Show(ctx())
            settle()
            -- The client fires OnHide as a shown frame hides; the mock does not.
            local hide = bank.frame.Hide
            override(bank.frame, "Hide", function(f)
              local was = f:IsShown()
              hide(f)
              if was then f:GetScript("OnHide")(f) end
            end)
            local bag = holds(how == "as it closes" and 80 or 8)
            db.smallChain = "companion"
            chain:Update(ctx())
            settle()
            assert.are.equal(900, top(bank))
            local spot = top(bank) - bank.frame:GetHeight()
            bank:Hide(ctx())
            if how == "as its slide ends" then
              holding(bag, 80)
            end
            settle()
            assert.is_true(top(bag) - bag.frame:GetHeight() < spot, "pushed down")
            holding(bag, 8)
            settle()
            assert.are.equal(spot, top(bag) - bag.frame:GetHeight(), "back up to its spot beside the bank")
          end)
        end
      end

      -- Found by the fourth bug review: the slide's end saved the backpack's place a second time, after its close had, and what
      -- had changed in the slide's 0.24 s was saved over it: the companion's top where a shrinking glide the close cut short was
      -- going, a second companion opened meanwhile, a drop.
      describe("as a companion's close slide ends (the client fires its OnHide)", function()
        local function firesOnHide(panel)
          local hide = panel.frame.Hide
          override(panel.frame, "Hide", function(f)
            local was = f:IsShown()
            hide(f)
            if was then f:GetScript("OnHide")(f) end
          end)
        end

        -- chained opens a bank that comes to hold n items and a backpack beside it, its place saved where it is, as a drop does.
        local function chained(n)
          local bank = nextBank:Create(ctx())
          bank:Draw(ctx(), bankTab(bank, 4), function() end)
          bank:Show(ctx())
          settle()
          bank:Draw(ctx(), bankTab(bank, n), function() end)
          render:Flush()
          settle()
          firesOnHide(bank)
          local bag = holds(8)
          db.smallChain = "companion"
          chain:Update(ctx())
          settle()
          db.corners[BACKPACK] = cornerFor(bag, bag.placeX, bag.placeY)
          return bank, bag
        end

        local function savedCorner()
          local c = db.corners[BACKPACK]
          return { c[1], c[2], c[3], c[4] }
        end

        it("keeps the place its close saved where it cut a glide lowering the companion's top short", function()
          finally(layoutHelper.UseScreen(1920, 1200, 0.64))
          local bank, bag = chained(50)
          bank:Draw(ctx(), bankTab(bank, 4), function() end)
          render:Flush()
          for _ = 1, 2 do
            step(1 / 60)
            render:Flush()
          end
          bank:Hide(ctx())
          local saved = savedCorner()
          settle()
          assert.are.same(saved, db.corners[BACKPACK])
          local stood = top(bag) - bag.frame:GetHeight()
          holding(bag, 9)
          settle()
          assert.are.equal(stood, top(bag) - bag.frame:GetHeight(), "its bottom where it stood")
        end)

        it("keeps the place its close saved as another companion opens while it slides out", function()
          finally(layoutHelper.UseScreen(1920, 1200, 0.64))
          local OTHER = 77
          db.places[OTHER] = { 300, 1000 }
          local bank, bag = chained(4)
          local other = nextBank:Create(ctx())
          other.kind = OTHER
          firesOnHide(other)
          other:Draw(ctx(), bankTab(other, 4), function() end)
          local x0 = bag.placeX
          bank:Hide(ctx())
          local saved = savedCorner()
          other:Show(ctx())
          settle()
          assert.is_true(bag.placeX ~= x0, "beside the other companion now")
          assert.are.same(saved, db.corners[BACKPACK])
        end)

        -- Found by the fifth bug review: a parent hiding it mid-slide (Alt+Z) cuts the close short, and it comes back open with
        -- no Show; its next close, Escape's, saved nothing, and the backpack's next height glide took it back down 175 units.
        -- widened gives the bank a section name it widens for (Fit Names While Open), its right edge moving the backpack beside
        -- it (their bottoms level, docs/next-bag-anchor.md: its height no longer moves it).
        local function widened(bank)
          local long = string.rep("W", 70)
          bank:Draw(ctx(), { sortedItems = {}, tabs = { [bank:GetCurrentTabID()] = { categories = { { name = "Ore" },
            { name = long } }, items = { item("6_1", "Ore"), item("6_2", long) } } } }, function() end)
          render:Flush()
          settle()
        end

        it("saves where the backpack stands as Escape closes a companion whose close a parent's hide cut short", function()
          finally(layoutHelper.UseScreen(1920, 1200, 0.64))
          db.fitNames = true
          local bank, bag = chained(4)
          bank:Hide(ctx())
          step(1 / 60)
          render:Flush()
          for _, panel in ipairs({ bank, bag }) do panel.frame:GetScript("OnHide")(panel.frame) end
          for _, panel in ipairs({ bank, bag }) do panel.frame:GetScript("OnShow")(panel.frame) end
          settle()
          assert.is_true(bank.frame:IsShown() and not bank.closing, "open again")
          local x0 = bag.placeX
          widened(bank)
          local x1, y1 = bag.placeX, bag.placeY
          assert.is_true(x1 ~= x0, "moved with the bank")
          bank.frame:Hide()
          settle()
          assert.are.same(cornerFor(bag, x1, y1), db.corners[BACKPACK])
        end)

        -- Opened again as it slides out, it is open: its next close saves again, Escape's too.
        it("saves where the backpack stands as Escape closes a companion opened again as it slid out", function()
          finally(layoutHelper.UseScreen(1920, 1200, 0.64))
          db.fitNames = true
          local bank, bag = chained(4)
          bank:Hide(ctx())
          step(1 / 60)
          bank:Show(ctx())
          settle()
          local x0 = bag.placeX
          widened(bank)
          local x1, y1 = bag.placeX, bag.placeY
          assert.is_true(x1 ~= x0, "moved with the bank")
          bank.frame:Hide()
          settle()
          assert.are.same(cornerFor(bag, x1, y1), db.corners[BACKPACK])
        end)

        for _, clamp in ipairs({ false, true }) do
          it("keeps a drop made while it slides out, Clamp Bags to Screen " .. (clamp and "on" or "off"), function()
            finally(layoutHelper.UseScreen(1920, 1200, 0.64))
            db.clamp = clamp
            local bank, bag = chained(4)
            bank:Hide(ctx())
            step(1 / 60)
            render:Flush()
            dragTo(bag, 1100, 1000)
            local saved = savedCorner()
            settle()
            assert.are.same(saved, db.corners[BACKPACK])
          end)
        end
      end)

      -- A companion's close finishes part way through a size switch (PrepareResize ends it), its OnHidden before it or the backpack
      -- has the size the switch gives it: nothing is saved for the backpack then, but what the close saved as it started (a
      -- small one's; one never small has no place yet).
      for _, to in ipairs({ "small", "full" }) do
        it("saves nothing more for the backpack as a companion's close ends in a switch to " .. to, function()
          finally(layoutHelper.UseScreen(1920, 1200, 0.64))
          db.size = to == "small" and "full" or "small"
          db.smallChain = "companion"
          holds(8)
          local bank = nextBank:Create(ctx())
          bank:Draw(ctx(), bankTab(bank, 8), function() end)
          bank:Show(ctx())
          settle()
          local hide = bank.frame.Hide
          override(bank.frame, "Hide", function(f)
            local was = f:IsShown()
            hide(f)
            if was then f:GetScript("OnHide")(f) end
          end)
          bank:Hide(ctx())
          local saved = db.corners[BACKPACK]
          saved = saved and { saved[1], saved[2], saved[3], saved[4] }
          assert.has_no.errors(function() nextPanel:SetSize(ctx(), to) end)
          settle()
          assert.are.same(saved, db.corners[BACKPACK])
        end)
      end

      -- Found by the third bug review: a parent hiding the companion (Alt+Z) is no close, and saved the backpack's place.
      it("saves nothing as a parent hides a companion and shows it again", function()
        finally(layoutHelper.UseScreen(1920, 1200, 0.64))
        db.fitNames = true
        local bank = nextBank:Create(ctx())
        bank:Draw(ctx(), bankTab(bank, 4), function() end)
        bank:Show(ctx())
        settle()
        local bag = holds(8)
        db.smallChain = "companion"
        chain:Update(ctx())
        settle()
        db.corners[BACKPACK] = cornerFor(bag, bag.placeX, bag.placeY)
        local saved = { db.corners[BACKPACK][1], db.corners[BACKPACK][2], db.corners[BACKPACK][3], db.corners[BACKPACK][4] }
        local x0 = bag.placeX
        -- A name widens the bank, its right edge moving the backpack beside it (docs/next-bag-anchor.md: their bottoms level,
        -- its height no longer does).
        local long = string.rep("W", 70)
        bank:Draw(ctx(), { sortedItems = {}, tabs = { [bank:GetCurrentTabID()] = { categories = { { name = "Ore" },
          { name = long } }, items = { item("6_1", "Ore"), item("6_2", long) } } } }, function() end)
        render:Flush()
        settle()
        assert.is_true(bag.placeX ~= x0, "moved with the bank")
        -- Alt+Z: UIParent hides; each frame's own flag stays set; the client fires each OnHide, then each OnShow.
        bank.frame:GetScript("OnHide")(bank.frame)
        bag.frame:GetScript("OnHide")(bag.frame)
        bank.frame:GetScript("OnShow")(bank.frame)
        bag.frame:GetScript("OnShow")(bag.frame)
        settle()
        bag:Hide(ctx())
        settle()
        bank:Hide(ctx())
        settle()
        assert.are.same(saved, db.corners[BACKPACK])
      end)

      -- Found by the second bug review: dragged off its companion, the backpack stayed the chain's bag beside it, and its own
      -- height glide's end saved the top it rose to, so it never went back down to where it was dropped.
      for _, how in ipairs({ "the bank closes", "the bank's height glides" }) do
        it("goes back down to where it was dropped after it is dragged off its companion and " .. how, function()
          db.clamp = false
          local bank = nextBank:Create(ctx())
          bank:Draw(ctx(), bankTab(bank, 4), function() end)
          bank:Show(ctx())
          settle()
          local bag = holds(8)
          db.smallChain = "companion"
          chain:Update(ctx())
          settle()
          dragTo(bag, 1200, 400)
          settle()
          assert.are.equal("apart", db.smallChain)
          local dropped = cornerFor(bag, 1200, 400)
          assert.are.same(dropped, db.corners[BACKPACK])
          holding(bag, 80)
          settle()
          assert.is_true(top(bag) > 400, "it rose as it grew")
          if how == "the bank closes" then
            bank:Hide(ctx())
          else
            bank:Draw(ctx(), bankTab(bank, 60), function() end)
          end
          settle()
          holding(bag, 8)
          settle()
          assert.are.same(dropped, db.corners[BACKPACK], "where it was dropped, saved")
          assert.are.equal(400, top(bag), "back down where it was dropped")
        end)
      end

      -- Found by the second bug review: a grip let go took its place from the top it had been raised to, so a raised bag a grip
      -- made shorter stayed up until its height next changed. Holding its bottom (docs/next-bag-anchor.md), the mirror: pushed
      -- down to keep its top on the screen, a grip that makes it shorter lets it back up.
      for _, clamp in ipairs({ false, true }) do
        it("goes back up where a grip let go makes a pushed-down bag shorter, Clamp Bags to Screen " .. (clamp and "on" or "off"),
          function()
          db.clamp = clamp
          db.sizes[BACKPACK] = { columnsWidth(3) }
          db.corners[BACKPACK] = { 300, 600, "LEFT", "BOTTOM" }
          local bag = holds(40)
          local h = bag.frame:GetHeight()
          assert.is_true(600 + h > UIParent:GetHeight())
          assert.are.equal(UIParent:GetHeight(), top(bag), "pushed down as it opened")
          resize(bag, "RIGHT", columnsWidth(8) + 5, h)
          settle()
          assert.is_true(600 + bag.frame:GetHeight() < UIParent:GetHeight())
          assert.are.same({ 300, 600, "LEFT", "BOTTOM" }, db.corners[BACKPACK], "saved where it was left")
          assert.are.equal(600, top(bag) - bag.frame:GetHeight(), "back up to where it was left")
        end)
      end

      -- Found by the second bug review: a chained bag's grip let go saved its left edge with a top it had once been dropped at.
      it("saves a chained bag's place where it stands as its grip is let go", function()
        finally(layoutHelper.UseScreen(1920, 1200, 0.64))
        local bank = nextBank:Create(ctx())
        bank:Draw(ctx(), bankTab(bank, 4), function() end)
        bank:Show(ctx())
        settle()
        db.corners[BACKPACK] = { 100, 300 - smallHeight(), "LEFT", "BOTTOM" }
        local bag = holds(8)
        db.smallChain = "companion"
        chain:Update(ctx())
        settle()
        assert.is_true(bag.placeY > 300)
        local f = bag.frame
        local px, py = topLeft(bag)
        press(bag.grips.RIGHT)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", px, py)
        f:SetSize(columnsWidth(5) + 5, f:GetHeight())
        f:GetScript("OnSizeChanged")(f, columnsWidth(5) + 5, f:GetHeight())
        release(bag.grips.RIGHT)
        settle()
        -- Its spot, on the side it held (docs/next-bag-anchor.md: sizing keeps its side).
        assert.are.same(cornerFor(bag, bag.placeX, bag.placeY, "LEFT"), db.corners[BACKPACK], "saved where it stands")
      end)

      -- Found by the second bug review: a bag that was small before took the height of the width it had then, and glided again.
      it("switches back to small in one glide after its names asked for another width while it was full", function()
        inColumns()
        local bag = nextBag:Create(ctx())
        bag:Draw(ctx(), twoSections(60, "B"), function() end)
        bag:Show(ctx())
        settle()
        local narrow = bag.frame:GetWidth()
        nextPanel:SetSize(ctx(), "full")
        settle()
        bag:Draw(ctx(), twoSections(60, LONG), function() end)
        settle()
        local snaps = countCalls(bag, "snapTo")
        nextPanel:SetSize(ctx(), "small")
        settle()
        assert.is_true(bag.frame:GetWidth() > narrow, "wider for its names")
        assert.are.equal(fitted(bag), bag.frame:GetHeight())
        assert.are.equal(0, snaps(), "nothing more to glide once it has switched")
      end)

      -- As a grip's snap leaves the bag chained beside it alone (next-small-resize.md §14g, from the third bug review): a glide of
      -- its height alone, its bottom where it was left (docs/next-bag-anchor.md), moves nothing beside it, and the braid stays
      -- twisted.
      for _, screen in ipairs({ { 2560, 1440, 0.71, 125 }, { 1920, 1080, 1, 85 } }) do
        it(string.format("never moves the bag chained beside it as its height glides with its bottom still, %dx%d at %s, Bag Scale %d%%",
          screen[1], screen[2], screen[3], screen[4]), function()
          finally(layoutHelper.UseScreen(screen[1], screen[2], screen[3]))
          db.bagScale = screen[4]
          db.clamp = false
          db.places[BANK] = { 200, UIParent:GetHeight() / 2 }
          local bank = nextBank:Create(ctx())
          bank:Draw(ctx(), bankTab(bank, 4), function() end)
          bank:Show(ctx())
          settle()
          local bag = holds(8)
          db.smallChain = "companion"
          chain:Update(ctx())
          settle()
          for _ = 1, 60 do chain:Turn(1 / 60) end
          assert.is_true(chain.coupling ~= nil and chain.coupling.amount == 1, "braided")
          local ppu = layoutHelper.PixelsPerUnit()
          local at = layoutHelper.Rect(bag.frame).left * ppu
          local bottom0 = layoutHelper.Rect(bank.frame).bottom
          bank:Draw(ctx(), bankTab(bank, 30), function() end)
          render:Flush()
          step(1 / 60)
          assert.is_true(bank.sizeGliding, "its height glides")
          for frame = 1, 45 do
            step(1 / 60)
            render:Flush()
            chain:Turn(1 / 60)
            assert.are.equal(at, layoutHelper.Rect(bag.frame).left * ppu, "the bag beside it still, frame " .. frame)
            assert.is_false(tween:IsPlaying(bag), "nothing glides into a spot, frame " .. frame)
            assert.is_true(chain.coupling ~= nil and chain.coupling.target == 1, "braided, frame " .. frame)
          end
          settle()
          local h, unit = bank.frame:GetHeight(), bank:PixelUnit()
          assert.is_true(h >= fitted(bank) - 1e-6 and h < fitted(bank) + 2 * unit, "as tall as what it shows, in whole pixels")
          assert.is_true(math.abs(layoutHelper.Rect(bank.frame).bottom - bottom0) < 0.01, "its bottom still")
        end)
      end

      it("leaves a full panel the screen's height", function()
        db.size = "full"
        local bag = holds(8)
        assert.are.equal(UIParent:GetHeight(), bag:Height())
        assert.are.equal("closed", bag:FollowHeight())
      end)

      -- Narrower small than full, it shows more rows small: the switch glides to that height, not the full width's.
      it("switches to small in one glide, to the height that shows what it holds there", function()
        db.size = "full"
        db.sizes[BACKPACK] = { columnsWidth(4), 300 }
        local bag = holds(64)
        local snaps = countCalls(bag, "snapTo")
        nextPanel:SetSize(ctx(), "small")
        local last
        for _ = 1, 200 do
          if bag.morph == nil then break end
          step(1 / 60)
          render:Flush()
          if bag.morph ~= nil then last = bag.frame:GetHeight() end
        end
        assert.is_nil(bag.morph)
        settle()
        assert.are.equal(0, snaps(), "nothing more to glide once it has switched")
        assert.are.equal(columnsWidth(4), bag.frame:GetWidth())
        assert.are.equal(fitted(bag), bag.frame:GetHeight())
        assert.is_true(math.abs(last - bag.frame:GetHeight()) < 0.01, "the switch glided all the way: " .. last)
      end)

      it("says what it did, for profiler traces", function()
        local bag = nextBag:Create(ctx())
        assert.are.equal("closed", bag:FollowHeight())
        bag:Show(ctx())
        settle()
        assert.are.equal("fits", bag:FollowHeight())
        db.autosize = false
        assert.are.equal("off", bag:FollowHeight())
        db.autosize = true
        assert.are.equal("owed", bag:FollowHeight(true))
        holding(bag, 64)
        assert.are.equal("following", bag:FollowHeight())
        assert.are.equal("owed", bag:FollowHeight(), "while it glides")
        settle()
      end)

      -- With Fit Names While Open on, what its names ask for glides its width alone: its height, owed by the draw before, glides
      -- after, never jumping there as the width starts to glide.
      it("glides its width for its names and its height for what it shows, neither jumping", function()
        db.fitNames = true
        inColumns()
        db.places[BACKPACK] = { 300, 700 }
        local bag = nextBag:Create(ctx())
        bag:Draw(ctx(), twoSections(4, "B"), function() end)
        bag:Show(ctx())
        settle()
        local short, narrow = bag.frame:GetHeight(), bag.frame:GetWidth()
        local bottom = 700 - short
        bag:Draw(ctx(), twoSections(60, "B"), function() end)
        render:Flush()
        assert.is_true(fitted(bag) > short, "what it shows asks for more height, a frame on")
        bag:Draw(ctx(), twoSections(60, LONG), function() end)
        assert.is_true(bag.sizeGliding, "its names glide it as it draws (FollowNames)")
        step(1 / 60)
        assert.is_true(bag.frame:GetWidth() > narrow, "its width glides")
        assert.are.equal(short, bag.frame:GetHeight(), "its height as it was")
        settle()
        assert.are.equal(columnsWidth(12), bag.frame:GetWidth())
        assert.are.equal(fitted(bag), bag.frame:GetHeight())
        assert.are.same({ 300, bottom + bag.frame:GetHeight() }, { topLeft(bag) }, "its bottom left still")
      end)

      -- Each Bag Scale puts its pixels' edges elsewhere in its header's and footer's fixed units: the height is rounded up past
      -- both the room the root hands its scroll box and the scroll box as its snapped anchors place it.
      for _, screen in ipairs({ { 2560, 1440, 0.71 }, { 1920, 1080, 0.64 }, { 3396, 1362, 0.65 } }) do
        it(string.format("takes whole screen pixels and shows all it holds at every Bag Scale, %dx%d at %s",
          screen[1], screen[2], screen[3]), function()
          finally(layoutHelper.UseScreen(screen[1], screen[2], screen[3]))
          local bag = holds(8)
          for scale = 50, 150, 5 do
            db.bagScale = scale
            chain:ScalesChanged(ctx())
            for _, n in ipairs({ 13, 40 }) do
              holding(bag, n)
              settle()
              local why = string.format("Bag Scale %d%%, %d items", scale, n)
              local unit = bag:PixelUnit()
              local h = bag.frame:GetHeight()
              assert.is_true(math.abs(h / unit - math.floor(h / unit + 0.5)) < 1e-6, "whole pixels: " .. h / unit .. ", " .. why)
              -- The room down to its footer's line within a pixel: the line stands on a whole pixel (pixel:Point).
              assert.is_true(h > fitted(bag) - unit and h < fitted(bag) + 2 * unit,
                "no taller than whole pixels need: " .. h .. ", " .. fitted(bag) .. ", " .. why)
              assert.is_true(showsAll(bag), why)
              local rect = layoutHelper.Rect(bag.scroll.frame)
              local box = (rect.top - rect.bottom) / bag.scroll.frame:GetEffectiveScale()
              assert.is_true(box >= bag.content.frame:GetHeight() - 1e-6, "its scroll box, as anchored: " .. box .. ", " .. why)
            end
          end
        end)
      end
    end)
  end)

  -- A button on the backpack switches every panel between full and small, animated
  -- (docs/next-small-mode.md, "Switching sizes").
  describe("switching sizes", function()
    local function step(seconds)
      tween.driver:GetScript("OnUpdate")(tween.driver, seconds)
    end

    local function opened(create)
      local panel = create(ctx())
      panel:Show(ctx())
      finishTweens()
      return panel
    end

    local function click(bag)
      bag.sizeButton:GetScript("OnClick")(bag.sizeButton, "LeftButton")
    end

    -- The body's top left and height on screen while it morphs (the frame anchored by its top left).
    local function body(panel)
      local x, y = topLeft(panel)
      return x + panel:BodyLeft(), y, panel.frame:GetHeight()
    end

    local function between(v, a, b, what)
      local lo, hi = math.min(a, b), math.max(a, b)
      assert.is_true(v > lo and v < hi, what .. ": " .. v .. " is not between " .. a .. " and " .. b)
    end

    -- How strongly a feather shows, 0 to 1: its gradient's solid end against the body's alpha. A
    -- gradient is the texture's vertex colors (warcraft.wiki.gg TextureBase:SetGradient); the switch
    -- fades the feathers through it, as Next fades every gradient (paintWash), not with SetAlpha,
    -- which left them as they were in game.
    local function strength(texture)
      local g = texture._gradient
      return math.max(g.min.a, g.max.a) / style.Color.Body[4]
    end

    -- How strong the border is, 0 to 1: its alpha against the theme's (a texture's alpha is its
    -- vertex color's, so the border fades through it, next-themes.md §10). Rounded: 0.35 * x / 0.35.
    local function edgeAlpha(bag)
      local alpha = bag.edges[1]:GetAlpha()
      for _, edge in ipairs(bag.edges) do assert.are.equal(alpha, edge:GetAlpha(), "every edge alike") end
      return math.floor(alpha / style.Small.Edge * 1e9 + 0.5) / 1e9
    end

    it("has a button on the backpack drawn with arrows in while full and arrows out while small", function()
      db.size = "full"
      local bag = nextBag:Create(ctx())
      assert.are.equal("small", NextIconName(bag.sizeButton))
      click(bag)
      assert.are.equal("full", NextIconName(bag.sizeButton))
      click(bag)
      assert.are.equal("small", NextIconName(bag.sizeButton))
    end)

    it("sits after the Show Blizzard Bags button, saying what it does", function()
      db.size = "full"
      local bag = nextBag:Create(ctx())
      assert.are.same({ "TOPRIGHT", bag.bagsButton, "TOPLEFT", -8, 0 }, { bag.sizeButton:GetPoint(1) })
      bag.sizeButton:GetScript("OnEnter")(bag.sizeButton)
      assert.are.equal("Small Bags", GameTooltip:GetText())
      click(bag)
      bag.sizeButton:GetScript("OnEnter")(bag.sizeButton)
      assert.are.equal("Full Size Bags", GameTooltip:GetText())
    end)

    it("draws the same on Classic", function()
      override(addon, "isRetail", false)
      db.size = "full"
      local bag = nextBag:Create(ctx())
      assert.are.equal("small", NextIconName(bag.sizeButton))
      click(bag)
      assert.are.equal("full", NextIconName(bag.sizeButton))
    end)

    it("saves the size, and does nothing when it is already the size", function()
      db.size = "full"
      local bag = nextBag:Create(ctx())
      assert.are.equal("same", nextPanel:SetSize(ctx(), "full"))
      assert.are.equal("switched", nextPanel:SetSize(ctx(), "small"))
      assert.are.equal("small", db.size)
      assert.are.equal("small", bag.size)
    end)

    -- A full companion moves Blizzard's panels past it (next-uipanels.md); a small one is a window the player places.
    it("gives Blizzard's panel layout its left edge back as a full companion switches to small, and takes it again", function()
      db.size = "full"
      opened(function(c) return nextBank:Create(c) end)
      assert.is_true(GetUIPanelLayoutAttribute("LEFT_OFFSET") > style.BODY_WIDTH, "beside the full bank")
      nextPanel:SetSize(ctx(), "small")
      assert.are.equal(16, GetUIPanelLayoutAttribute("LEFT_OFFSET"), "at once")
      finishTweens()
      assert.are.equal(16, GetUIPanelLayoutAttribute("LEFT_OFFSET"))
      nextPanel:SetSize(ctx(), "full")
      assert.is_true(GetUIPanelLayoutAttribute("LEFT_OFFSET") > style.BODY_WIDTH, "at once")
      finishTweens()
      nextPanel:SetSize(ctx(), "small")
      finishTweens()
    end)

    it("switches a closed panel at once, its content laid out for its new height", function()
      db.size = "full"
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = nextBank:Create(ctx())
      local renders = 0
      override(render, "Invalidate", function(_, d) if d == bank.root then renders = renders + 1 end end)
      click(bag)
      assert.are.equal(1, renders)
      assert.is_nil(bank.morph)
      assert.are.equal("small", bank.size)
      assert.are.equal(style.BODY_WIDTH, bank.frame:GetWidth())
      assert.is_false(bank.feather:IsShown())
      bank:Show(ctx())
      finishTweens()
      assert.are.same({ style.Small.Margin, (UIParent:GetHeight() + smallHeight()) / 2 }, { topLeft(bank) })
    end)

    it("glides an open panel's body from its edge to its small place, shrinking to its height", function()
      db.size = "full"
      local bag = opened(function(c) return nextBag:Create(c) end)
      local w, h = UIParent:GetWidth(), UIParent:GetHeight()
      click(bag)
      step(style.Time.Morph / 2)
      local x, y, height = body(bag)
      between(x, w - style.BODY_WIDTH, w - style.BODY_WIDTH - style.Small.Margin, "left")
      between(y, h, (h + smallHeight()) / 2, "top")
      between(height, h, smallHeight(), "height")
      finishTweens()
      assert.are.same({ w - style.BODY_WIDTH - style.Small.Margin, (h + smallHeight()) / 2 }, { topLeft(bag) })
      assert.are.same({ style.BODY_WIDTH, smallHeight() }, { bag.frame:GetWidth(), bag.frame:GetHeight() })
      assert.are.equal(1, bag.frame:GetAlpha())
    end)

    -- Asked: shrinking, the border appeared while the feather was still there, "making it look like
    -- the feathering is spilled out": a "2 step" animation, the size with the feather and the beam
    -- first, then the border.
    it("shrinks first, its feather fading and its beam shortening, and shows its border only once small", function()
      db.size = "full"
      local bag = opened(function(c) return nextBag:Create(c) end)
      click(bag)
      step(style.Time.Morph / 2)
      assert.is_true(bag.feather:IsShown())
      between(strength(bag.feather), 0, 1, "feather")
      assert.are.equal(0, edgeAlpha(bag), "no border while it shrinks")
      between(bag.ribbonLength, style.RIBBON_LENGTH, style.Small.Ribbon, "beam")
      step(style.Time.Morph / 2 + 0.001)
      assert.are.equal(0, strength(bag.feather), "the feather is gone once it is small")
      assert.are.equal(smallHeight(), bag.frame:GetHeight())
      assert.are.equal(style.Small.Ribbon, bag.ribbonLength)
      assert.are.equal(0, edgeAlpha(bag))
      step(style.Time.MorphFade / 2)
      between(edgeAlpha(bag), 0, 1, "the border fades in")
      assert.are.equal(0, strength(bag.feather))
      assert.are.equal(smallHeight(), bag.frame:GetHeight())
      finishTweens()
      assert.is_false(bag.feather:IsShown())
      assert.are.equal(1, strength(bag.feather))
      assert.are.equal(1, strength(bag.outerFeather), "ready for a full panel's flights")
      assert.are.equal(1, edgeAlpha(bag))
      assert.are.equal(style.Small.Ribbon, bag.ribbonLength)
    end)

    -- The same in reverse: the border goes first, then the size with the feather and the beam.
    -- Asked, of the version that let the border go before moving: "it doesn't feel good that it
    -- doesn't start moving right away": the border fades out during the move, then the feathers fade
    -- in, "basically the inverse of shrinking".
    it("grows at once, its border fading out on the way, then fades its feathers in", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      local w, h0 = UIParent:GetWidth(), UIParent:GetHeight()
      local x0 = topLeft(bag)
      click(bag)
      step(0.01)
      local x = body(bag)
      assert.is_true(x > x0, "it starts moving at once")
      step(style.Time.Morph / 2 - 0.01)
      between(edgeAlpha(bag), 0, 1, "the border fades out on the way")
      local _, _, h = body(bag)
      between(h, smallHeight(), h0, "height")
      between(bag.ribbonLength, style.Small.Ribbon, style.RIBBON_LENGTH, "beam")
      assert.are.equal(0, strength(bag.feather), "no feather while it grows")
      assert.are.equal(0, strength(bag.outerFeather))
      step(style.Time.Morph / 2 + 0.001)
      assert.are.same({ w - style.BODY_WIDTH, h0, h0 }, { body(bag) }, "at its edge")
      assert.are.equal(0, edgeAlpha(bag), "no border once it is there")
      assert.are.equal(style.RIBBON_LENGTH, bag.ribbonLength)
      assert.are.equal(0, strength(bag.feather))
      step(style.Time.MorphFade / 2)
      between(strength(bag.feather), 0, 1, "the feathers fade in")
      assert.are.equal(0, strength(bag.outerFeather), "no far feather at its screen edge")
      assert.are.same({ w - style.BODY_WIDTH, h0, h0 }, { body(bag) })
      assert.are.equal(0, edgeAlpha(bag))
      finishTweens()
      assert.are.same({ "TOPRIGHT", UIParent, "TOPRIGHT", 0, 0 }, { bag.frame:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0 }, { bag.frame:GetPoint(2) })
      assert.are.equal(style.WIDTH, bag.frame:GetWidth())
      assert.is_true(bag.feather:IsShown())
      assert.are.equal(1, strength(bag.feather))
      for _, edge in ipairs(bag.edges) do assert.is_false(edge:IsShown()) end
      assert.is_true(bag.docked)
      assert.are.equal(style.RIBBON_LENGTH, bag.ribbonLength)
      assert.are.equal(1, strength(bag.outerFeather))
    end)

    -- Its border outlines its body, not the frame: a full panel's frame reaches over its feather.
    it("draws its border round its body", function()
      local bag = nextBag:Create(ctx())
      for _, edge in ipairs(bag.edges) do
        for i = 1, edge:GetNumPoints() do
          local _, rel = edge:GetPoint(i)
          assert.are.equal(bag.body, rel)
        end
      end
    end)

    it("glides back with its border as it was, then fades the rest of it in, when switched back mid-grow", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      click(bag)
      step(style.Time.Morph / 4)
      local edge = edgeAlpha(bag)
      between(edge, 0, 1, "border")
      click(bag)
      step(style.Time.Morph / 2)
      assert.are.equal(edge, edgeAlpha(bag), "the border waits until it is small again")
      step(style.Time.Morph / 2 + 0.001)
      assert.are.equal(edge, edgeAlpha(bag))
      -- In its share of the fade's time, not all of it.
      step(style.Time.MorphFade * (1 - edge) + 0.001)
      assert.are.equal(1, edgeAlpha(bag))
      assert.is_nil(bag.morph)
    end)

    it("ends where it started at once when switched twice in a row", function()
      db.size = "full"
      local bag = opened(function(c) return nextBag:Create(c) end)
      click(bag)
      click(bag)
      assert.is_nil(bag.morph)
      assert.are.same({ "TOPRIGHT", UIParent, "TOPRIGHT", 0, 0 }, { bag.frame:GetPoint(1) })
      assert.are.equal(1, strength(bag.feather))
    end)

    -- A full panel at its screen edge has no far feather. Shrinking from its edge, then growing back
    -- to a spot beside its partner (chained meanwhile), its far feather fades in from nothing at the
    -- fade's pace, though the near one has only half to go.
    it("fades each feather in at the fade's pace when it grows back to a spot beside its partner", function()
      db.size = "full"
      local layout = "apart"
      override(stubs.database, "GetNextChain", function() return layout end)
      local bag = opened(function(c) return nextBag:Create(c) end)
      opened(function(c) return nextBank:Create(c) end)
      click(bag)
      step(style.Time.Morph / 2)
      assert.are.equal(0, strength(bag.outerFeather))
      layout = "left"
      click(bag)
      step(style.Time.Morph + 0.001)
      assert.are_not.equal(0, bag.offset, "beside its partner")
      step(style.Time.MorphFade / 2 + 0.001)
      between(strength(bag.outerFeather), 0, 1, "far feather")
      finishTweens()
      assert.are.equal(1, strength(bag.outerFeather))
      assert.is_true(bag.outerFeather:IsShown())
    end)

    it("turns around from where it is while its border fades in", function()
      db.size = "full"
      local bag = opened(function(c) return nextBag:Create(c) end)
      click(bag)
      step(style.Time.Morph + 0.001)
      step(style.Time.MorphFade / 2)
      local edge = edgeAlpha(bag)
      between(edge, 0, 1, "border")
      click(bag)
      assert.are.equal(edge, edgeAlpha(bag), "the border fades back from where it was")
      step(0.01)
      assert.is_true(edgeAlpha(bag) < edge, "on the way back")
      step(style.Time.Morph)
      assert.are.equal(0, edgeAlpha(bag), "gone by the time it is back")
      finishTweens()
      assert.are.same({ "TOPRIGHT", UIParent, "TOPRIGHT", 0, 0 }, { bag.frame:GetPoint(1) })
      assert.is_false(bag.edges[1]:IsShown())
    end)

    it("turns around from where it is when switched back mid-glide", function()
      db.size = "full"
      local bag = opened(function(c) return nextBag:Create(c) end)
      click(bag)
      step(style.Time.Morph / 2)
      local x, y, h = body(bag)
      local feather = strength(bag.feather)
      local ribbon = bag.ribbonLength
      click(bag)
      local x2, y2, h2 = body(bag)
      assert.is_true(math.abs(x2 - x) < 1e-6 and math.abs(y2 - y) < 1e-6 and math.abs(h2 - h) < 1e-6,
        "it starts back from where it was")
      assert.is_true(math.abs(strength(bag.feather) - feather) < 1e-6)
      assert.is_true(math.abs(bag.ribbonLength - ribbon) < 1e-6)
      -- No border to fade (it had none yet): it glides back at once.
      step(0.01)
      local _, _, hNext = body(bag)
      assert.is_true(hNext > h, "it is on its way back")
      -- The first glide would have ended here: it was stopped, and does not end the second.
      step(style.Time.Morph / 2 + 0.01)
      assert.is_not_nil(bag.morph)
      local _, _, h3 = body(bag)
      between(h3, h, UIParent:GetHeight(), "height on the way back")
      finishTweens()
      assert.are.same({ "TOPRIGHT", UIParent, "TOPRIGHT", 0, 0 }, { bag.frame:GetPoint(1) })
      assert.are.equal(1, strength(bag.feather))
    end)

    it("drops its glide when it is switched after Escape closed it mid-glide", function()
      db.size = "full"
      local bag = opened(function(c) return nextBag:Create(c) end)
      click(bag)
      step(style.Time.Morph / 2)
      bag.frame:Hide()
      bag.frame:GetScript("OnHide")(bag.frame)
      click(bag)
      assert.is_nil(bag.morph)
      assert.are.equal("full", bag.size)
      assert.are.equal(style.WIDTH, bag.frame:GetWidth())
    end)

    it("keeps gliding when the open bag is shown again (a refresh)", function()
      db.size = "full"
      local bag = opened(function(c) return nextBag:Create(c) end)
      click(bag)
      step(style.Time.Morph / 2)
      bag:Show(ctx())
      assert.is_not_nil(bag.morph)
    end)

    it("keeps its feather on its inner side after shrinking and growing back", function()
      db.size = "full"
      local bag = opened(function(c) return nextBag:Create(c) end)
      click(bag)
      finishTweens()
      click(bag)
      finishTweens()
      assert.are.equal(2, bag.feather:GetNumPoints())
      assert.are.same({ "TOPLEFT", bag.frame, "TOPLEFT", 0, 0 }, { bag.feather:GetPoint(1) })
      assert.are.same({ "BOTTOMLEFT", bag.frame, "BOTTOMLEFT", 0, 0 }, { bag.feather:GetPoint(2) })
    end)

    it("does not reach past the screen edge while it morphs", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      click(bag)
      step(style.Time.Morph / 2)
      assert.is_false(bag.docked)
      local _, _, _, x = bag.fill:GetPoint(2)
      assert.are.equal(0, x)
    end)

    it("lays its content out once, at the end", function()
      db.size = "full"
      local bag = opened(function(c) return nextBag:Create(c) end)
      local renders = 0
      override(render, "Invalidate", function(_, d) if d == bag.root then renders = renders + 1 end end)
      click(bag)
      step(style.Time.Morph / 2)
      assert.are.equal(0, renders)
      finishTweens()
      assert.are.equal(1, renders)
    end)

    it("finishes the morph first when it starts to close", function()
      db.size = "full"
      local bag = opened(function(c) return nextBag:Create(c) end)
      click(bag)
      step(style.Time.Morph / 2)
      bag:Hide(ctx())
      assert.is_false(bag.feather:IsShown())
      assert.are.equal(1, edgeAlpha(bag), "its border at full strength")
      finishTweens()
      assert.is_false(bag:IsShown())
      assert.are.equal(style.Small.Slide, bag.offset)
    end)

    it("finishes the morph first when it is moved", function()
      db.size = "full"
      local bag = opened(function(c) return nextBag:Create(c) end)
      click(bag)
      step(style.Time.Morph / 2)
      bag.mover:GetScript("OnDragStart")(bag.mover, "LeftButton")
      assert.is_nil(bag.morph)
      assert.are.same({ UIParent:GetWidth() - style.BODY_WIDTH - style.Small.Margin,
        (UIParent:GetHeight() + smallHeight()) / 2 }, { topLeft(bag) })
      assert.are.equal(1, edgeAlpha(bag), "both steps are finished")
    end)

    it("finishes closing before it switches a closing panel", function()
      db.size = "full"
      local bag = opened(function(c) return nextBag:Create(c) end)
      bag:Hide(ctx())
      click(bag)
      assert.is_false(bag:IsShown())
      assert.is_nil(bag.morph, "a closed bag does not glide")
      assert.are.equal("small", bag.size)
      assert.are.equal(style.BODY_WIDTH, bag.frame:GetWidth())
    end)

    -- A full pair chained on one edge braids its ribbons (next.md §12); small panels are not
    -- chained yet, so it lets go at once, and braids again once both are full and in place.
    it("lets go of a chained pair's braid at once, and braids again when they grow back", function()
      db.size = "full"
      override(stubs.database, "GetNextChain", function() return "right" end)
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = opened(function(c) return nextBank:Create(c) end)
      assert.is_not_nil(chain.coupling)
      click(bag)
      assert.is_nil(chain.coupling)
      assert.are.equal(0, bank.braid.amount)
      finishTweens()
      assert.is_nil(chain.coupling)
      click(bag)
      step(style.Time.Morph / 2)
      assert.are.equal("on its way", chain:UpdateCoupling(), "not while they still glide to their places")
      assert.is_nil(chain.coupling)
      finishTweens()
      assert.is_not_nil(chain.coupling)
      assert.are.equal(1, chain.coupling.amount)
      assert.are.equal(chain:RestOffset(bank), bank.offset)
    end)
  end)

  -- Dragged close to its partner, a small bag chains to it (docs/next-small-mode.md, "Chaining by
  -- dragging them together"): the one dropped beside is the anchor; dragging the anchor moves both,
  -- dragging the other lets it go; their ribbons braid across the gap.
  describe("chaining small bags", function()
    local function step(seconds)
      tween.driver:GetScript("OnUpdate")(tween.driver, seconds)
    end

    local function opened(create)
      local panel = create(ctx())
      panel:Show(ctx())
      finishTweens()
      return panel
    end

    local function startDrag(panel)
      panel.mover:GetScript("OnDragStart")(panel.mover, "LeftButton")
    end

    -- The client moves the frame with the mouse; each frame the panel follows (its mover's OnUpdate).
    local function moveTo(panel, left, top)
      panel.frame:_SetRect(left, top - panel.frame:GetHeight(), panel.frame:GetWidth(), panel.frame:GetHeight())
      local update = panel.mover:GetScript("OnUpdate")
      if update then update(panel.mover, 0.016) end
    end

    local function stopDrag(panel)
      panel.mover:GetScript("OnDragStop")(panel.mover)
    end

    local function drag(panel, left, top)
      startDrag(panel)
      moveTo(panel, left, top)
      stopDrag(panel)
    end

    -- Where a bank sits chained beside the backpack, and the backpack beside a bank.
    local function besideBag(bag, bank)
      return bag.placeX - chain:SmallGap(bag, bank) - style.BODY_WIDTH, bag.placeY
    end

    local function besideBank(bank, bag)
      return bank.placeX + style.BODY_WIDTH + chain:SmallGap(bag, bank), bank.placeY
    end

    it("keeps chained bags apart by both tab rails, never closer than the minimum", function()
      local bag = nextBag:Create(ctx())
      local bank = nextBank:Create(ctx())
      assert.are.equal(style.Small.MinGap, chain:SmallGap(bag, bank))
      override(bag.tabs, "Width", function() return 120 end)
      override(bank.tabs, "Width", function() return 90 end)
      assert.are.equal(120 + 90 + 2 * style.TAB_HOVER + style.Chain.TabMargin, chain:SmallGap(bag, bank))
    end)

    -- Their bottoms aligned (docs/next-bag-anchor.md); of the same height here, their tops too.
    it("chains a bag dropped beside its partner's facing side, gliding it into place, their bottoms aligned", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = opened(function(c) return nextBank:Create(c) end)
      local x, y = besideBag(bag, bank)
      drag(bank, x - style.Small.SnapReach + 1, y + style.Small.SnapRise - 1)
      assert.are.equal("backpack", db.smallChain, "the backpack is the anchor")
      finishTweens()
      assert.are.same({ x, y }, { topLeft(bank) })
      assert.are.same(cornerFor(bank, x, y), db.corners[BANK])
      assert.is_not_nil(chain.coupling)
      assert.are.equal(bag, chain.coupling.anchor)
      assert.are.equal(bank, chain.coupling.chained)
      assert.are.equal(1, chain.coupling.amount)
    end)

    it("chains the backpack dropped beside a companion, the companion the anchor", function()
      local bank = opened(function(c) return nextBank:Create(c) end)
      local bag = opened(function(c) return nextBag:Create(c) end)
      local x, y = besideBank(bank, bag)
      drag(bag, x + 20, y - 30)
      assert.are.equal("companion", db.smallChain)
      finishTweens()
      assert.are.same({ x, y }, { topLeft(bag) })
      assert.are.equal(bank, chain.coupling.anchor)
    end)

    it("does not chain a bag dropped too far, too high, or facing away", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = opened(function(c) return nextBank:Create(c) end)
      local x, y = besideBag(bag, bank)
      drag(bank, x - style.Small.SnapReach - 1, y)
      assert.are.equal("apart", db.smallChain)
      drag(bank, x, y - style.Small.SnapRise - 1)
      assert.are.equal("apart", db.smallChain)
      -- On the backpack's right: the bank's inner side faces away from it.
      drag(bank, bag.placeX + style.BODY_WIDTH + chain:SmallGap(bag, bank) - 400, y)
      assert.are.equal("apart", db.smallChain)
      finishTweens()
      assert.is_nil(chain.coupling)
    end)

    it("does not chain a pair that would not fit on the screen", function()
      -- The bank's spot is 30 off the screen's left edge: dropped at the edge, it is within reach.
      UIParent:_SetRect(0, 0, 990, 1200)
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = opened(function(c) return nextBank:Create(c) end)
      local x, y = besideBag(bag, bank)
      assert.are.equal(-30, x)
      drag(bank, 0, y)
      assert.are.equal("apart", db.smallChain)
    end)

    it("braids their ribbons across the gap between them, the chained bag showing the knot", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = opened(function(c) return nextBank:Create(c) end)
      local x, y = besideBag(bag, bank)
      drag(bank, x, y)
      finishTweens()
      local half = chain:SmallGap(bag, bank) / 2
      assert.are.equal(half, bag.braid.half)
      assert.are.equal(half, bank.braid.half)
      assert.is_true(bank.braid.chained)
      assert.is_false(bag.braid.chained)
    end)

    -- Asked: "still want the sparkles between them/coming out the side". Between them, never over the
    -- other bag: a sparkle is born up to 24 out of its bag's inner side and drifts at most its speed
    -- times its life.
    it("keeps its edge sparkles in the gap while braided, and lets them drift as before once apart", function()
      db.smallChain = "backpack"
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = opened(function(c) return nextBank:Create(c) end)
      local gap = chain:SmallGap(bag, bank)
      for _, panel in ipairs({ bag, bank }) do
        local o = panel.edgeSparkles.options
        assert.is_true(24 + o.Speed[2] * o.Life[2] < gap, "within the gap: " .. o.Speed[2] * o.Life[2])
      end
      bank:Hide(ctx())
      finishTweens()
      assert.are.same({ 14, 36 }, bag.edgeSparkles.options.Speed)
      assert.are.same({ 2.4, 4.2 }, bag.edgeSparkles.options.Life)
    end)

    it("moves both when the anchor is dragged, the braid kept, and saves both places", function()
      db.smallChain = "backpack"
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = opened(function(c) return nextBank:Create(c) end)
      assert.is_not_nil(chain.coupling)
      startDrag(bag)
      moveTo(bag, 1000, 1000)
      local gap = chain:SmallGap(bag, bank)
      assert.are.same({ 1000 - gap - style.BODY_WIDTH, 1000 }, { topLeft(bank) })
      assert.is_not_nil(chain.coupling)
      stopDrag(bag)
      assert.are.same(cornerFor(bag, 1000, 1000), db.corners[BACKPACK])
      assert.are.same(cornerFor(bank, 1000 - gap - style.BODY_WIDTH, 1000), db.corners[BANK])
      assert.is_nil(bag.mover:GetScript("OnUpdate"), "it stops following once let go")
      assert.are.equal("kept", chain:UpdateCoupling())
    end)

    it("lets the other bag go when it is dragged, and chains it again when dropped back beside", function()
      db.smallChain = "backpack"
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = opened(function(c) return nextBank:Create(c) end)
      local x, y = besideBag(bag, bank)
      startDrag(bank)
      assert.are.equal("apart", db.smallChain)
      assert.are.equal(0, chain.coupling.target, "the braid comes apart as soon as it is dragged")
      moveTo(bank, 100, 900)
      stopDrag(bank)
      finishTweens()
      assert.is_nil(chain.coupling)
      assert.are.same(cornerFor(bank, 100, 900), db.corners[BANK])
      drag(bank, x + 10, y)
      finishTweens()
      assert.are.equal("backpack", db.smallChain)
      assert.is_not_nil(chain.coupling)
    end)

    it("opens a companion beside its open anchor, and the pair braids", function()
      db.smallChain = "backpack"
      db.places[BACKPACK] = { 1200, 1000 }
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = nextBank:Create(ctx())
      bank:Show(ctx())
      finishTweens()
      assert.are.same({ 1200 - chain:SmallGap(bag, bank) - style.BODY_WIDTH, 1000 }, { topLeft(bank) })
      assert.is_not_nil(chain.coupling)
    end)

    it("opens a companion beside where its anchor was left, before the anchor opens", function()
      db.smallChain = "backpack"
      db.places[BACKPACK] = { 1200, 1000 }
      local bag = nextBag:Create(ctx())
      local bank = opened(function(c) return nextBank:Create(c) end)
      assert.are.same({ 1200 - chain:SmallGap(bag, bank) - style.BODY_WIDTH, 1000 }, { topLeft(bank) })
      assert.is_nil(chain.coupling)
      bag:Show(ctx())
      assert.is_nil(chain.coupling, "not while the backpack still slides in")
      finishTweens()
      assert.is_not_nil(chain.coupling)
    end)

    it("opens the backpack beside the open companion it was chained to", function()
      db.smallChain = "companion"
      db.places[BANK] = { 100, 900 }
      local bank = opened(function(c) return nextBank:Create(c) end)
      local bag = opened(function(c) return nextBag:Create(c) end)
      assert.are.same({ 100 + style.BODY_WIDTH + chain:SmallGap(bag, bank), 900 }, { topLeft(bag) })
      assert.is_not_nil(chain.coupling)
    end)

    it("lets go of the braid when one of the pair closes, and braids again when it opens", function()
      db.smallChain = "backpack"
      opened(function(c) return nextBag:Create(c) end)
      local bank = opened(function(c) return nextBank:Create(c) end)
      bank:Hide(ctx())
      finishTweens()
      assert.is_nil(chain.coupling)
      assert.are.equal("backpack", db.smallChain, "still chained")
      bank:Show(ctx())
      finishTweens()
      assert.is_not_nil(chain.coupling)
    end)

    it("glides the chained bag to its new spot when the gap changes", function()
      db.smallChain = "backpack"
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = opened(function(c) return nextBank:Create(c) end)
      override(bag.tabs, "Width", function() return 140 end)
      chain:Update(ctx())
      step(0.05)
      local x = topLeft(bank)
      local wanted = besideBag(bag, bank)
      assert.is_true(x ~= wanted, "it glides there")
      finishTweens()
      assert.are.same({ wanted, bag.placeY }, { topLeft(bank) })
      assert.is_not_nil(chain.coupling)
    end)

    -- Found by the third bug review: a glide into a spot reads the spot each frame (its anchor's size may glide meanwhile), and a
    -- bank closing is no longer the backpack's anchor (the chain's companion is an open one), so the spot became the
    -- backpack's saved place and it jumped back 10 units. Let go by its anchor, it goes on to the spot it read last.
    it("glides on to its spot as the anchor it glides beside closes", function()
      db.smallChain = "companion"
      local bank = opened(function(c) return nextBank:Create(c) end)
      local bag = opened(function(c) return nextBag:Create(c) end)
      -- Where it was dropped: its place saved at its spot.
      db.places[BACKPACK] = { bag.placeX, bag.placeY }
      override(bank.tabs, "Width", function() return 140 end)
      chain:Update(ctx())
      assert.is_true(tween:IsPlaying(bag), "it glides to its new spot")
      local spot = { bag:SmallPlace() }
      assert.is_true(spot[1] > db.places[BACKPACK][1], "the spot moved right")
      step(0.05)
      local before = topLeft(bag)
      bank:Hide(ctx())
      step(1 / 60)
      local after = topLeft(bag)
      assert.is_true(after >= before, "on toward its spot, not back: " .. before .. " to " .. after)
      finishTweens()
      assert.are.same(spot, { topLeft(bag) })
      assert.are.same(spot, { bag.placeX, bag.placeY })
    end)

    -- A slide or a switch is never cut short: the slide's end says the bag has shown (a bank open
    -- waits for it to read the bank).
    it("glides a chained bag to a spot that moved while it slid in only once it is in", function()
      db.smallChain = "backpack"
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = nextBank:Create(ctx())
      local shown = 0
      bank:Show(ctx(), nil, function() shown = shown + 1 end)
      override(bag.tabs, "Width", function() return 140 end)
      chain:Update(ctx())
      assert.are.equal(0, shown)
      finishTweens()
      assert.are.equal(1, shown)
      assert.are.same({ besideBag(bag, bank) }, { topLeft(bank) })
      assert.is_not_nil(chain.coupling)
    end)

    it("glides a chained bag to a spot that moved while it switched size only once it has", function()
      db.size = "full"
      db.smallChain = "backpack"
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = opened(function(c) return nextBank:Create(c) end)
      nextPanel:SetSize(ctx(), "small")
      step(style.Time.Morph / 2)
      override(bag.tabs, "Width", function() return 140 end)
      chain:Update(ctx())
      assert.is_not_nil(bank.morph)
      assert.is_false(tween:IsPlaying(bank))
      assert.is_nil(chain.coupling, "not while they switch size")
      finishTweens()
      assert.are.same({ besideBag(bag, bank) }, { topLeft(bank) })
      assert.is_not_nil(chain.coupling)
    end)

    it("leaves a bag chained to a closed backpack where it is when its spot moves", function()
      db.smallChain = "backpack"
      local bag = nextBag:Create(ctx())
      local bank = opened(function(c) return nextBank:Create(c) end)
      local x, y = topLeft(bank)
      override(bank.tabs, "Width", function() return 140 end)
      chain:Update(ctx())
      finishTweens()
      assert.are.same({ x, y }, { topLeft(bank) })
      local _ = bag
    end)

    it("takes a partner still gliding into place along when the anchor is dragged", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = opened(function(c) return nextBank:Create(c) end)
      local x, y = besideBag(bag, bank)
      drag(bank, x + 40, y)
      step(style.Time.Glide / 3)
      startDrag(bag)
      moveTo(bag, 1000, 1000)
      -- Its glide does not pull it back toward its old spot.
      step(0.01)
      assert.are.same({ 1000 - chain:SmallGap(bag, bank) - style.BODY_WIDTH, 1000 }, { topLeft(bank) })
      stopDrag(bag)
    end)

    it("keeps each size's chain: switching to full and back braids the small pair again", function()
      db.smallChain = "backpack"
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = opened(function(c) return nextBank:Create(c) end)
      nextPanel:SetSize(ctx(), "full")
      finishTweens()
      assert.is_nil(chain.coupling, "full bags follow the full chain, which keeps them apart")
      assert.are.equal("backpack", db.smallChain)
      nextPanel:SetSize(ctx(), "small")
      finishTweens()
      assert.is_not_nil(chain.coupling)
      assert.are.same({ besideBag(bag, bank) }, { topLeft(bank) })
    end)
  end)

  -- The Size tab (docs/next-appearance-size.md): its sliders send next/ScalesChanged, which the chain
  -- listens to, once, for every panel.
  describe("the Size tab's scales", function()
    local handlers

    before_each(function()
      handlers = {}
      override(stubs.events, "RegisterMessage", function(_, name, fn)
        handlers[name] = handlers[name] or {}
        table.insert(handlers[name], fn)
      end)
    end)

    after_each(function()
      style:SetIconScale(100)
    end)

    local function scalesChanged()
      for _, fn in ipairs(handlers["next/ScalesChanged"] or {}) do fn(ctx()) end
    end

    local function opened(create)
      local panel = create(ctx())
      panel:Show(ctx())
      finishTweens()
      return panel
    end

    local function herbs(n)
      local list = {}
      for i = 1, n do table.insert(list, item("0_" .. i, "Herbs")) end
      slots[BACKPACK].tabs[1].items = list
    end

    local function perRow(panel)
      local width = panel.root:PreRender().Width - panel.scroll:GetGutterWidth()
      return math.floor((width + style.GAP) / (style.ICON + style.GAP))
    end

    describe("Icon Scale", function()
      -- Asked: "it can adjust based on scale, if buttons are huge, less fit per row naturally. if buttons
      -- are small, more per row fit."
      it("draws item buttons at the theme's size times Icon Scale, each row taking as many as fit", function()
        db.size = "full"
        herbs(10)
        local bag = opened(function(c) return nextBag:Create(c) end)
        bag:Draw(ctx(), slots[BACKPACK], function() end)
        render:Flush()
        assert.are.equal(1, #handlers["next/ScalesChanged"], "listened to once, by the chain")
        assert.are.equal(8, perRow(bag))
        db.iconScale = 150
        scalesChanged()
        render:Flush()
        assert.are.equal(66, style.ICON)
        assert.are.same({ 66, 66 }, { buttons["0_1"].frame:GetSize() })
        assert.are.equal(5, perRow(bag), "fewer per row")
        motion:Step(1)
        local _, _, _, x, y = buttons["0_6"].frame:GetPoint(1)
        assert.are.same({ 0, -(66 + style.GAP) }, { x, y }, "the 6th starts the second row")
        assert.are.equal(style.WIDTH, bag.frame:GetWidth(), "the panel keeps its width")
        db.iconScale = 50
        scalesChanged()
        render:Flush()
        assert.are.same({ 22, 22 }, { buttons["0_1"].frame:GetSize() })
        assert.is_true(perRow(bag) >= 10, "more per row")
        motion:Step(1)
        _, _, _, x, y = buttons["0_10"].frame:GetPoint(1)
        assert.are.same({ 9 * (22 + style.GAP), 0 }, { x, y }, "all ten on one row")
      end)

      it("sizes the buttons of a closed bag when it opens", function()
        herbs(3)
        local bag = nextBag:Create(ctx())
        bag:Draw(ctx(), slots[BACKPACK], function() end)
        db.iconScale = 120
        scalesChanged()
        bag:Show(ctx())
        finishTweens()
        render:Flush()
        assert.are.same({ 53, 53 }, { buttons["0_1"].frame:GetSize() })
      end)

      it("keeps a small panel at least one row of its icons tall, as they are now", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        local before = bag:MinHeight()
        db.iconScale = 150
        scalesChanged()
        assert.are.equal(before + (66 - 44), bag:MinHeight())
      end)

      -- The default small width is the width of the columns the full body's width holds (asked: "default should
      -- probably be exact too"), so it leaves no room past its last column at any Icon Scale.
      local function defaultWidth()
        local step = style.ICON + style.GAP
        local columns = math.floor((style.GRID_WIDTH + style.GAP) / step)
        return 2 * style.PAD + scrollbox:GutterWidthFor({ Symmetric = true }) + columns * step - style.GAP
      end

      it("opens a small panel at the width of the columns its default holds, at any Icon Scale", function()
        style:SetIconScale(120)
        assert.is_true(defaultWidth() < style.BODY_WIDTH, "the full body's width leaves room past its columns")
        local bag = opened(function(c) return nextBag:Create(c) end)
        assert.are.equal(defaultWidth(), bag.frame:GetWidth())
        assert.are.equal(defaultWidth() - 2 * style.PAD, bag.root:PreRender().LayoutWidth)
      end)

      it("fits an open panel at its default size to its columns when Icon Scale changes, keeping a saved size", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        assert.are.equal(style.BODY_WIDTH, bag.frame:GetWidth(), "exact at 100%")
        db.iconScale = 120
        scalesChanged()
        assert.are.equal(defaultWidth(), bag.frame:GetWidth())
        db.sizes[BACKPACK] = { 700, 500 }
        db.iconScale = 150
        scalesChanged()
        assert.are.equal(700, bag.frame:GetWidth(), "the size the player gave it")
      end)
    end)

    -- Asked: a "bag scale" slider; "bag scale should just not apply when docked to the side".
    describe("Bag Scale", function()
      local bodyWidth = function() return style.BODY_WIDTH end

      -- Where a panel's top left is on the screen: its anchor's offsets are in its own units.
      local function onScreen(panel)
        local x, y = topLeft(panel)
        local s = panel.frame:GetScale()
        return x * s, y * s
      end

      local function near(a, b)
        return math.abs(a - b) < 1e-6
      end

      -- The client moves a frame with the mouse: its rect in its own units.
      local function dragTo(panel, x, y)
        local s = panel.frame:GetScale()
        panel.mover:GetScript("OnDragStart")(panel.mover, "LeftButton")
        panel.frame:_SetRect(x / s, y / s - panel.frame:GetHeight(), panel.frame:GetWidth(), panel.frame:GetHeight())
        local update = panel.mover:GetScript("OnUpdate")
        if update then update(panel.mover, 0.016) end
        panel.mover:GetScript("OnDragStop")(panel.mover)
      end

      it("scales a small panel: its size in its own units, its place on the screen", function()
        db.bagScale = 50
        local bag = nextBag:Create(ctx())
        assert.are.equal(0.5, bag.frame:GetScale())
        assert.are.same({ bodyWidth(), smallHeight() }, { bag.frame:GetSize() })
        assert.are.same({ UIParent:GetWidth() - bodyWidth() * 0.5 - style.Small.Margin,
          (UIParent:GetHeight() + smallHeight() * 0.5) / 2 }, { onScreen(bag) })
        local bank = nextBank:Create(ctx())
        assert.are.equal(0.5, bank.frame:GetScale())
        assert.are.same({ style.Small.Margin, (UIParent:GetHeight() + smallHeight() * 0.5) / 2 }, { onScreen(bank) })
      end)

      it("leaves a full panel, docked to its screen edge, at its size", function()
        db.size = "full"
        db.bagScale = 50
        local bag = nextBag:Create(ctx())
        assert.are.equal(1, bag.frame:GetScale())
        assert.are.same({ "TOPRIGHT", UIParent, "TOPRIGHT", 0, 0 }, { bag.frame:GetPoint(1) })
        assert.are.equal(style.WIDTH, bag.frame:GetWidth())
      end)

      it("keeps a scaled panel on the screen, and never bigger than it", function()
        db.bagScale = 150
        db.places[BACKPACK] = { 1900, 1200 }
        db.sizes[BACKPACK] = { 2000, 2000 }
        local bag = nextBag:Create(ctx())
        assert.are.same({ 1920 / 1.5, 1200 / 1.5 }, { bag.frame:GetSize() }, "the screen, in its own units")
        assert.are.same({ 0, 1200 }, { onScreen(bag) })
      end)

      it("saves where it is moved to, on the screen", function()
        db.bagScale = 50
        local bag = opened(function(c) return nextBag:Create(c) end)
        dragTo(bag, 300, 900)
        assert.are.same(cornerFor(bag, 300, 900), db.corners[BACKPACK])
        assert.are.same({ 300, 900 }, { onScreen(bag) })
        assert.are.same({ 300, 900 }, { bag:LivePlace() })
      end)

      it("sizes from a grip within the screen at its scale, its size saved in its own units", function()
        db.bagScale = 50
        local bag = opened(function(c) return nextBag:Create(c) end)
        local grip = bag.grips.RIGHT
        grip:GetScript("OnMouseDown")(grip, "LeftButton")
        local bounds = bag.frame._resizeBounds
        assert.are.same({ 1920 / 0.5, 1200 / 0.5 }, { bounds.maxWidth, bounds.maxHeight })
        local x, y = topLeft(bag)
        -- Nine columns' width (next.md §14g: it snaps to its columns' width).
        local w = 2 * style.PAD + scrollbox:GutterWidthFor({ Symmetric = true }) + 9 * (style.ICON + style.GAP) - style.GAP
        bag.frame:_SetRect(x, y - 600, w, 600)
        bag.frame:GetScript("OnSizeChanged")(bag.frame, w, 600)
        grip:GetScript("OnMouseUp")(grip, "LeftButton")
        assert.are.same({ w, 600 }, db.sizes[BACKPACK])
        -- Its bottom right where it was let go, on the screen (docs/next-bag-anchor.md).
        assert.are.same({ (x + w) * 0.5, (y - 600) * 0.5, "RIGHT", "BOTTOM" }, db.corners[BACKPACK])
        assert.are.same({ x * 0.5, y * 0.5 }, { onScreen(bag) })
      end)

      it("glides back to its default size from a grip, its bottom and the side across from it still", function()
        db.bagScale = 50
        db.sizes[BACKPACK] = { 600, 500 }
        local bag = opened(function(c) return nextBag:Create(c) end)
        local x, y = onScreen(bag)
        local bottom = y - 500 * 0.5
        _G._isShiftKeyDown = true
        local grip = bag.grips.LEFT
        grip:GetScript("OnMouseUp")(grip, "LeftButton")
        _G._isShiftKeyDown = false
        tween:Step(style.Time.Resize / 2)
        local mx = onScreen(bag)
        assert.is_true(mx > x and mx < x + (600 - bodyWidth()) * 0.5, "on its way")
        finishTweens()
        assert.are.same({ bodyWidth(), smallHeight() }, { bag.frame:GetSize() })
        assert.are.same({ x + (600 - bodyWidth()) * 0.5, bottom + smallHeight() * 0.5 }, { onScreen(bag) },
          "its bottom right kept")
      end)

      it("takes a new scale at once while open, placed and kept on the screen", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        db.bagScale = 150
        scalesChanged()
        assert.are.equal(1.5, bag.frame:GetScale())
        assert.are.same({ UIParent:GetWidth() - bodyWidth() * 1.5 - style.Small.Margin,
          (UIParent:GetHeight() + smallHeight() * 1.5) / 2 }, { onScreen(bag) })
        -- Held by its bottom right (docs/next-bag-anchor.md): each scale grows it up and left from there.
        db.corners[BACKPACK] = { 1500 + bodyWidth() * 0.5, 1100 - smallHeight() * 0.5, "RIGHT", "BOTTOM" }
        db.bagScale = 50
        scalesChanged()
        assert.are.same({ 1500, 1100 }, { onScreen(bag) })
        db.bagScale = 150
        scalesChanged()
        local x = math.min(UIParent:GetWidth() - bodyWidth() * 1.5, 1500 + bodyWidth() * 0.5 - bodyWidth() * 1.5)
        assert.are.same({ x, UIParent:GetHeight() }, { onScreen(bag) }, "kept on the screen")
      end)

      -- Found by the bug review: with Fit Names While Open on, the redraw a new scale asks for (ApplyScales) glided the panel
      -- toward the width its names take at the new scale before it was refitted, and the refit leaves a gliding panel alone
      -- (chain:Update), so it kept its old scale. It is refitted first, then drawn.
      for _, case in ipairs({ { 105, "saved" }, { 150, "saved" }, { 150, "a name no step holds" } }) do
        it("takes a new scale at once while open with Fit Names While Open on, " .. case[1] .. "%, " .. case[2], function()
          db.fitNames = true
          if case[2] == "saved" then
            db.sizes[BACKPACK] = { 5000, 600 }
          else
            local name = string.rep("n", 300)
            slots[BACKPACK].tabs[1] = { categories = { { name = name } }, items = { item("0_1", name) } }
          end
          local bag = opened(function(c) return nextBag:Create(c) end)
          bag:Draw(ctx(), slots[BACKPACK], function() end)
          render:Flush()
          finishTweens()
          db.bagScale = case[1]
          scalesChanged()
          local scale = case[1] / 100
          assert.are.equal(scale, bag.frame:GetScale())
          assert.is_false(bag.sizeGliding)
          finishTweens()
          render:Flush()
          assert.are.equal(scale, bag.frame:GetScale())
          assert.is_true(bag.frame:GetWidth() * scale <= UIParent:GetWidth() + 1e-6, "on the screen")
        end)
      end

      it("chains small bags side by side on the screen, the gap and the braid at their scale", function()
        db.bagScale = 50
        local bag = opened(function(c) return nextBag:Create(c) end)
        local bank = opened(function(c) return nextBank:Create(c) end)
        assert.are.equal(style.Small.MinGap * 0.5, chain:SmallGap(bag, bank))
        override(bag.tabs, "Width", function() return 120 end)
        override(bank.tabs, "Width", function() return 90 end)
        local gap = (120 + 90 + 2 * style.TAB_HOVER + style.Chain.TabMargin) * 0.5
        assert.are.equal(gap, chain:SmallGap(bag, bank))
        local bx, by = onScreen(bag)
        local x, y = bx - gap - bodyWidth() * 0.5, by
        dragTo(bank, x - 10, y + 10)
        assert.are.equal("backpack", db.smallChain)
        finishTweens()
        local cx, cy = onScreen(bank)
        assert.is_true(near(x, cx) and near(y, cy), "beside it")
        assert.is_not_nil(chain.coupling)
        chain:applyCoupling()
        assert.is_true(near(gap / 2 / 0.5, bank.braid.half), "half the gap, in its own units")
        assert.is_true(near(gap / 2 / 0.5, bag.braid.half))
      end)

      it("does not chain a bag whose spot beside its partner is off the screen at its scale", function()
        db.bagScale = 150
        db.places[BACKPACK] = { 500, 1100 }
        local bag = opened(function(c) return nextBag:Create(c) end)
        local bank = opened(function(c) return nextBank:Create(c) end)
        local x = 500 - chain:SmallGap(bag, bank) - bodyWidth() * 1.5
        assert.is_true(x < 0)
        dragTo(bank, 0, 1100)
        assert.are.equal("apart", db.smallChain)
      end)

      it("glides its scale with its size when it switches, nothing jumping", function()
        db.size = "full"
        db.bagScale = 50
        local bag = opened(function(c) return nextBag:Create(c) end)
        assert.are.equal(1, bag.frame:GetScale())
        nextPanel:SetSize(ctx(), "small")
        tween:Step(0.0001)
        local x, y = onScreen(bag)
        assert.is_true(math.abs(x - (UIParent:GetWidth() - bodyWidth())) < 1 and math.abs(y - UIParent:GetHeight()) < 1,
          "from where the full panel's body was")
        tween:Step(style.Time.Morph / 2)
        local mid = bag.frame:GetScale()
        assert.is_true(mid < 1 and mid > 0.5, "on its way: " .. mid)
        finishTweens()
        assert.are.equal(0.5, bag.frame:GetScale())
        assert.are.same({ bodyWidth(), smallHeight() }, { bag.frame:GetSize() })
        assert.are.same({ UIParent:GetWidth() - bodyWidth() * 0.5 - style.Small.Margin,
          (UIParent:GetHeight() + smallHeight() * 0.5) / 2 }, { onScreen(bag) })
        nextPanel:SetSize(ctx(), "full")
        finishTweens()
        assert.are.equal(1, bag.frame:GetScale())
        assert.are.same({ "TOPRIGHT", UIParent, "TOPRIGHT", 0, 0 }, { bag.frame:GetPoint(1) })
      end)

      it("glides a chained bag into its spot on the screen", function()
        db.bagScale = 50
        local bag = opened(function(c) return nextBag:Create(c) end)
        local bank = opened(function(c) return nextBank:Create(c) end)
        local bx, by = onScreen(bag)
        local x, y = bx - chain:SmallGap(bag, bank) - bodyWidth() * 0.5, by
        dragTo(bank, x - 10, y + 10)
        tween:Step(style.Time.Glide / 2)
        local mx, my = onScreen(bank)
        assert.is_true(mx > x - 10 and mx < x and my < y + 10 and my > y, "on its way: " .. mx .. ", " .. my)
        finishTweens()
      end)

      it("brings a chained bag along beside its anchor as the anchor is dragged, the braid between them", function()
        db.bagScale = 50
        local bag = opened(function(c) return nextBag:Create(c) end)
        local bank = opened(function(c) return nextBank:Create(c) end)
        local bx, by = onScreen(bag)
        local gap = chain:SmallGap(bag, bank)
        dragTo(bank, bx - gap - bodyWidth() * 0.5, by)
        finishTweens()
        assert.is_not_nil(chain.coupling)
        bag.mover:GetScript("OnDragStart")(bag.mover, "LeftButton")
        -- The client moves the backpack: its rect in its own units.
        bag.frame:_SetRect(1400 / 0.5, 1000 / 0.5 - bag.frame:GetHeight(), bag.frame:GetWidth(), bag.frame:GetHeight())
        bag.mover:GetScript("OnUpdate")(bag.mover, 0.016)
        local cx, cy = onScreen(bank)
        assert.is_true(near(1400 - gap - bodyWidth() * 0.5, cx) and near(1000, cy), "beside it: " .. cx .. ", " .. cy)
        chain:applyCoupling()
        assert.is_true(near(gap / 2 / 0.5, bank.braid.half), "the braid across the gap as it is now")
        bag.mover:GetScript("OnDragStop")(bag.mover)
      end)

      it("chains the backpack beside a companion on the screen, at their scale", function()
        db.bagScale = 50
        local bank = opened(function(c) return nextBank:Create(c) end)
        local bag = opened(function(c) return nextBag:Create(c) end)
        local kx, ky = onScreen(bank)
        local x = kx + bodyWidth() * 0.5 + chain:SmallGap(bag, bank)
        dragTo(bag, x + 10, ky - 10)
        assert.are.equal("companion", db.smallChain)
        finishTweens()
        local cx, cy = onScreen(bag)
        assert.is_true(near(x, cx) and near(ky, cy), "beside it")
      end)

      it("does not chain the backpack whose spot beside a companion ends past the screen at its scale", function()
        db.bagScale = 150
        db.places[BANK] = { 500, 1200 }
        local bank = opened(function(c) return nextBank:Create(c) end)
        local bag = opened(function(c) return nextBag:Create(c) end)
        local wx = 500 + bodyWidth() * 1.5 + chain:SmallGap(bag, bank)
        assert.is_true(wx + bodyWidth() * 1.5 > UIParent:GetWidth() and wx + bodyWidth() <= UIParent:GetWidth())
        dragTo(bag, wx, 1200)
        assert.are.equal("apart", db.smallChain)
      end)

      it("starts a switch to full size from where the small panel is on the screen, at its size there", function()
        db.bagScale = 50
        local bag = opened(function(c) return nextBag:Create(c) end)
        local x, y = onScreen(bag)
        nextPanel:SetSize(ctx(), "full")
        tween:Step(0.0001)
        local s = bag.frame:GetScale()
        local fx, fy = onScreen(bag)
        assert.is_true(math.abs(fx + style.FEATHER * s - x) < 1 and math.abs(fy - y) < 1, "its body where it was")
        assert.is_true(math.abs((bag.frame:GetWidth() - style.FEATHER) * s - bodyWidth() * 0.5) < 1, "as wide")
        assert.is_true(math.abs(bag.frame:GetHeight() * s - smallHeight() * 0.5) < 2, "as tall")
        finishTweens()
      end)

      it("lays its content out at once when the switch narrows it in its own units", function()
        db.bagScale = 50
        db.sizes[BACKPACK] = { 600, 500 }
        local bag = opened(function(c) return nextBag:Create(c) end)
        render:Flush()
        assert.is_false(render:IsDirty(bag.root))
        nextPanel:SetSize(ctx(), "full")
        assert.is_true(render:IsDirty(bag.root), "laid out for the full body's width before the glide")
        finishTweens()
      end)

      it("takes its size's scale when it switches while closed", function()
        db.bagScale = 50
        local bag = nextBag:Create(ctx())
        nextPanel:SetSize(ctx(), "full")
        assert.are.equal(1, bag.frame:GetScale())
        nextPanel:SetSize(ctx(), "small")
        assert.are.equal(0.5, bag.frame:GetScale())
      end)
    end)
  end)

  -- A small bag holds its bottom corner (docs/next-bag-anchor.md). Asked: "always auto-grow the bag based on it's bottom half
  -- quadrant, so lower right, grow from lower right of bag, lower left, grow from lower left (or maybe just left right split
  -- on the screen, rather). this is just on and works"; then, of the reading that it holds its bottom edge and its left or
  -- right corner by the half of the screen it is on: "yes".
  describe("holding its bottom corner", function()
    local W, H = 1920, 1200

    local function step(seconds)
      tween.driver:GetScript("OnUpdate")(tween.driver, seconds)
    end

    -- settle runs two seconds of frames, each rendering what waits for it.
    local function settle()
      for _ = 1, 120 do
        render:Flush()
        local update = tween.driver and tween.driver:GetScript("OnUpdate")
        if update ~= nil then
          update(tween.driver, 1 / 60)
        end
      end
      render:Flush()
    end

    -- contents is a tab of n items in one category, and Free Space.
    local function contents(n)
      local list = {}
      for i = 1, n do table.insert(list, item("0_" .. i, "Herbs")) end
      return { sortedItems = {}, tabs = { [1] = { categories = { { name = "Herbs" } }, items = list,
        freeSpace = { showAll = false, buttons = { { slotkey = "9_1", count = 30 } } } } } }
    end

    local function holding(panel, n)
      panel:Draw(ctx(), contents(n), function() end)
      render:Flush()
    end

    -- holds opens a backpack holding n items.
    local function holds(n)
      local bag = nextBag:Create(ctx())
      bag:Draw(ctx(), contents(n), function() end)
      bag:Show(ctx())
      settle()
      return bag
    end

    local function opened(create)
      local panel = create(ctx())
      panel:Show(ctx())
      finishTweens()
      return panel
    end

    -- dragTo drags panel by its title row and drops it with its top left at x, y on the screen.
    local function dragTo(panel, x, y)
      panel.mover:GetScript("OnDragStart")(panel.mover, "LeftButton")
      local f, s = panel.frame, panel:Scale()
      f:_SetRect(x / s, y / s - f:GetHeight(), f:GetWidth(), f:GetHeight())
      panel.mover:GetScript("OnDragStop")(panel.mover)
    end

    -- edges are where a small panel is on the screen: its left, its bottom, its right and its top (its anchor's offsets and
    -- its size are in its own units).
    local function edges(panel)
      local x, y = topLeft(panel)
      local s = panel:Scale()
      local w, h = panel.frame:GetWidth() * s, panel.frame:GetHeight() * s
      return x * s, y * s - h, x * s + w, y * s
    end

    local function bottom(panel)
      return (select(2, edges(panel)))
    end

    local function right(panel)
      return (select(3, edges(panel)))
    end

    before_each(function()
      UIParent:_SetRect(0, 0, W, H)
    end)

    it("holds its own side's bottom corner where it was never placed, where a bag of the default size always stood", function()
      local bag = nextBag:Create(ctx())
      local default = math.floor(H * style.Small.Height)
      assert.are.same({ W - style.Small.Margin, (H - default) / 2, "RIGHT", "BOTTOM" }, { bag:HeldCorner() })
      assert.are.same({ W - style.Small.Margin - style.BODY_WIDTH, (H + default) / 2 }, { topLeft(bag) })
      local bank = nextBank:Create(ctx())
      assert.are.same({ style.Small.Margin, (H - default) / 2, "LEFT", "BOTTOM" }, { bank:HeldCorner() })
      assert.is_nil(db.corners[BACKPACK], "nothing saved until it is placed")
    end)

    it("holds the bottom corner of the half of the screen it is dropped on, saved for its kind", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      local w, h = bag.frame:GetWidth(), bag.frame:GetHeight()
      dragTo(bag, 300, 900)
      assert.are.same({ 300, 900 - h, "LEFT", "BOTTOM" }, db.corners[BACKPACK])
      assert.are.same({ 300, 900 }, { topLeft(bag) })
      dragTo(bag, 1400, 900)
      assert.are.same({ 1400 + w, 900 - h, "RIGHT", "BOTTOM" }, db.corners[BACKPACK])
      assert.are.same({ 1400, 900 }, { topLeft(bag) })
      -- By its middle: just left of the screen's, the left; on it, the right.
      dragTo(bag, W / 2 - w / 2 - 1, 900)
      assert.are.equal("LEFT", db.corners[BACKPACK][3])
      dragTo(bag, W / 2 - w / 2, 900)
      assert.are.equal("RIGHT", db.corners[BACKPACK][3])
      assert.is_nil(db.corners[BANK])
    end)

    describe("with Autosize Bags on", function()
      before_each(function()
        db.autosize = true
        db.clamp = false
      end)

      for _, case in ipairs({ { "right", 1400 }, { "left", 300 } }) do
        it("grows up from its bottom as items come in, and back down as they go, its " .. case[1] .. " edge still, saving "
          .. "nothing", function()
          local bag = holds(8)
          -- Low enough that it never reaches the screen's top.
          dragTo(bag, case[2], 700)
          settle()
          local saved = { db.corners[BACKPACK][1], db.corners[BACKPACK][2], db.corners[BACKPACK][3], db.corners[BACKPACK][4] }
          local l0, b0, r0, t0 = edges(bag)
          holding(bag, 64)
          step(1 / 60)
          assert.is_true(bag.sizeGliding)
          while bag.sizeGliding do
            step(1 / 60)
            render:Flush()
            local l, b, r = edges(bag)
            assert.are.same({ l0, b0, r0 }, { l, b, r }, "its bottom and sides still")
          end
          settle()
          local _, b1, _, t1 = edges(bag)
          assert.are.equal(b0, b1)
          assert.is_true(t1 > t0, "taller, upward")
          holding(bag, 8)
          settle()
          assert.are.same({ l0, b0, r0, t0 }, { edges(bag) })
          assert.are.same(saved, db.corners[BACKPACK])
        end)
      end

      it("grows up from its bottom where it was never placed", function()
        local bag = holds(8)
        local default = math.floor(H * style.Small.Height)
        local _, b0, r0 = edges(bag)
        assert.are.same({ (H - default) / 2, W - style.Small.Margin }, { b0, r0 })
        holding(bag, 64)
        settle()
        assert.are.same({ b0, r0 }, { bottom(bag), right(bag) })
        assert.is_nil(db.corners[BACKPACK])
      end)

      for _, scale in ipairs({ 100, 150 }) do
        it("is pushed down no further than keeps its top on the screen as it grows, and back up as it shrinks, Bag Scale "
          .. scale .. "%", function()
          db.bagScale = scale
          local bag = holds(8)
          dragTo(bag, 300, 1150)
          settle()
          local b0 = bottom(bag)
          local saved = db.corners[BACKPACK][2]
          assert.are.equal(b0, saved)
          holding(bag, 80)
          step(1 / 60)
          assert.is_true(bag.sizeGliding)
          while bag.sizeGliding do
            step(1 / 60)
            render:Flush()
            assert.is_true(select(4, edges(bag)) <= H + 1e-6, "its top on the screen")
          end
          settle()
          local _, b1, _, t1 = edges(bag)
          assert.is_true(math.abs(t1 - H) <= 0.5, "its top at the screen's: " .. t1)
          assert.is_true(b1 < b0, "pushed down")
          assert.are.equal(saved, db.corners[BACKPACK][2], "where it was left, saved")
          holding(bag, 8)
          settle()
          assert.are.equal(b0, bottom(bag))
        end)
      end

      -- The drop is where the player put it: one that leaves its bottom off the screen is put back up as it lands.
      it("puts a drop that leaves its bottom off the screen back up, and holds it there", function()
        local bag = holds(8)
        local h = bag.frame:GetHeight()
        dragTo(bag, 300, h - 100)
        assert.are.same({ 300, 0, "LEFT", "BOTTOM" }, db.corners[BACKPACK])
        assert.are.same({ 300, h }, { topLeft(bag) })
      end)

      it("keeps its bottom where a grip let go bounces its height back, the bottom it was left at its held one", function()
        local bag = holds(40)
        dragTo(bag, 1400, 900)
        settle()
        local l0, b0, r0 = edges(bag)
        local grip = bag.grips.RIGHT
        grip:GetScript("OnMouseDown")(grip, "LeftButton")
        local f = bag.frame
        f:_SetRect(l0, b0 - 200, f:GetWidth(), f:GetHeight() + 200)
        f:GetScript("OnSizeChanged")(f, f:GetWidth(), f:GetHeight())
        grip:GetScript("OnMouseUp")(grip, "LeftButton")
        settle()
        assert.are.same({ l0, b0, r0 }, { (edges(bag)), bottom(bag), right(bag) })
        assert.are.same({ r0, b0, "RIGHT", "BOTTOM" }, db.corners[BACKPACK])
      end)

      it("widens away from the side it holds as a long name comes in, Fit Names While Open on", function()
        db.fitNames = true
        override(stubs.database, "GetNextSectionColumns", function() return 2 end)
        override(stubs.database, "GetNextSectionSpan", function() return true end)
        local LONG = string.rep("n", 40)
        local function sections(list)
          local categories, list2, n = {}, {}, 0
          for _, s in ipairs(list) do
            table.insert(categories, { name = s[1] })
            for _ = 1, s[2] do
              n = n + 1
              table.insert(list2, item("0_" .. n, s[1]))
            end
          end
          return { sortedItems = {}, tabs = { [1] = { categories = categories, items = list2 } } }
        end
        local bag = holds(1)
        dragTo(bag, 1400, 900)
        bag:Draw(ctx(), sections({ { "A", 1 }, { "B", 1 } }), function() end)
        settle()
        local l0, b0, r0 = edges(bag)
        bag:Draw(ctx(), sections({ { "A", 1 }, { LONG, 1 } }), function() end)
        settle()
        local l1, b1, r1 = edges(bag)
        assert.is_true(l1 < l0, "wider to the left")
        assert.are.same({ b0, r0 }, { b1, r1 }, "its bottom right still")
      end)
    end)

    describe("with Autosize Bags off", function()
      local function sizeBy(panel, side, w, h)
        local grip = panel.grips[side]
        grip:GetScript("OnMouseDown")(grip, "LeftButton")
        -- The client sizes it from the grip's corner, the corner across still.
        local f = panel.frame
        local left, top = topLeft(panel)
        local r = left + f:GetWidth()
        f:_SetRect(side == "LEFT" and r - w or left, top - h, w, h)
        f:GetScript("OnSizeChanged")(f, w, h)
        grip:GetScript("OnMouseUp")(grip, "LeftButton")
        finishTweens()
      end

      it("holds the bottom a grip leaves it at, and keeps its side", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        dragTo(bag, 1400, 1000)
        local l0, _, _, t0 = edges(bag)
        sizeBy(bag, "RIGHT", bag.frame:GetWidth(), 500)
        local l, b, r, t = edges(bag)
        assert.are.same({ l0, t0, t0 - 500 }, { l, t, b }, "sized from its bottom right, its top left still")
        assert.are.same({ r, b, "RIGHT", "BOTTOM" }, db.corners[BACKPACK])
      end)

      it("glides back to its default size with Shift-click, its bottom and the side across from the grip still", function()
        db.sizes[BACKPACK] = { style.BODY_WIDTH + 100, 500 }
        local bag = opened(function(c) return nextBag:Create(c) end)
        dragTo(bag, 1200, 900)
        local _, b0, r0 = edges(bag)
        local default = math.floor(H * style.Small.Height)
        local grip = bag.grips.LEFT
        override(_G, "IsShiftKeyDown", function() return true end)
        grip:GetScript("OnMouseUp")(grip, "LeftButton")
        step(1 / 60)
        assert.is_true(bag.sizeGliding)
        while bag.sizeGliding do
          step(1 / 60)
          assert.is_true(math.abs(bottom(bag) - b0) <= 1 and math.abs(right(bag) - r0) <= 1, "its bottom right still")
        end
        finishTweens()
        assert.are.same({ style.BODY_WIDTH, default }, { bag.frame:GetWidth(), bag.frame:GetHeight() })
        assert.are.same({ b0, r0 }, { bottom(bag), right(bag) })
        assert.are.same({ r0, b0, "RIGHT", "BOTTOM" }, db.corners[BACKPACK])
      end)
    end)

    -- Chained bags hold the same bottom line, each growing up on its own.
    it("lines a chained bag up with its anchor by their bottoms", function()
      db.autosize = true
      local bag = holds(64)
      local bank = opened(function(c) return nextBank:Create(c) end)
      settle()
      assert.are_not.equal(bag.frame:GetHeight(), bank.frame:GetHeight(), "of different heights")
      local bx, by = topLeft(bag)
      local x, y = chain:ChainedPlace(bank, bag, bx, by)
      dragTo(bank, x + 10, y - 10)
      assert.are.equal("backpack", db.smallChain)
      settle()
      assert.are.equal(bottom(bag), bottom(bank))
      holding(bag, 8)
      settle()
      assert.are.equal(bottom(bag), bottom(bank), "still, as the anchor shrinks")
    end)

    -- Where it was left before (a top left) is taken over as it first shows: it stays where it was, and holds its bottom from
    -- then on.
    for _, case in ipairs({ { 300, "LEFT" }, { 1400, "RIGHT" } }) do
      it("takes a place saved before over where it is as it first shows, its " .. case[2] .. " corner", function()
        db.autosize = true
        db.clamp = false
        db.places[BACKPACK] = { case[1], 700 }
        local bag = nextBag:Create(ctx())
        assert.are.same({ case[1], 700 }, { topLeft(bag) }, "where it was, while it has not shown")
        assert.is_nil(db.corners[BACKPACK])
        bag:Draw(ctx(), contents(8), function() end)
        bag:Show(ctx())
        settle()
        local h = bag.frame:GetHeight()
        assert.are.same({ case[1], 700 }, { topLeft(bag) })
        local x = case[2] == "RIGHT" and case[1] + bag.frame:GetWidth() or case[1]
        assert.are.same({ x, 700 - h, case[2], "BOTTOM" }, db.corners[BACKPACK])
        assert.is_nil(db.places[BACKPACK], "the old place cleared")
        holding(bag, 64)
        settle()
        assert.are.equal(700 - h, bottom(bag), "its bottom held")
      end)
    end

    -- Asked: "let's do the 4 quadrant anchoring instead of just left and right ... top anchors only work when you drag via the
    -- box, not the title". A top corner comes from the anchor square alone; the bag then holds its top and grows down.
    describe("holding a top corner", function()
      it("grows down from its top as items come in, and back up as they go, its side still, saving nothing", function()
        db.autosize = true
        db.clamp = false
        db.corners[BACKPACK] = { 1700, 1000, "RIGHT", "TOP" }
        local bag = holds(8)
        local l0, b0, r0, t0 = edges(bag)
        assert.are.same({ 1700, 1000 }, { r0, t0 })
        holding(bag, 64)
        step(1 / 60)
        assert.is_true(bag.sizeGliding)
        while bag.sizeGliding do
          step(1 / 60)
          render:Flush()
          local l, _, r, t = edges(bag)
          assert.are.same({ l0, r0, t0 }, { l, r, t }, "its top and sides still")
        end
        settle()
        assert.is_true(bottom(bag) < b0, "taller, downward")
        assert.are.equal(t0, select(4, edges(bag)))
        holding(bag, 8)
        settle()
        assert.are.same({ l0, b0, r0, t0 }, { edges(bag) })
        assert.are.same({ 1700, 1000, "RIGHT", "TOP" }, db.corners[BACKPACK])
      end)

      it("is pushed up no further than keeps its bottom on the screen as it grows, and back down as it shrinks", function()
        db.autosize = true
        db.clamp = false
        db.corners[BACKPACK] = { 300, 400, "LEFT", "TOP" }
        local bag = holds(8)
        local _, b0, _, t0 = edges(bag)
        assert.are.equal(400, t0)
        assert.is_true(b0 >= 0)
        holding(bag, 80)
        step(1 / 60)
        assert.is_true(bag.sizeGliding)
        while bag.sizeGliding do
          step(1 / 60)
          render:Flush()
          assert.is_true(bottom(bag) >= -1e-6, "its bottom on the screen")
        end
        settle()
        local _, b1, _, t1 = edges(bag)
        assert.is_true(math.abs(b1) <= 0.5, "its bottom at the screen's: " .. b1)
        assert.is_true(t1 > t0, "pushed up")
        assert.are.same({ 300, 400, "LEFT", "TOP" }, db.corners[BACKPACK], "where it was left, saved")
        holding(bag, 8)
        settle()
        assert.are.equal(t0, select(4, edges(bag)))
      end)

      it("holds the top a grip leaves it at, Autosize Bags off", function()
        db.autosize = false
        db.corners[BACKPACK] = { 1700, 1000, "RIGHT", "TOP" }
        local bag = opened(function(c) return nextBag:Create(c) end)
        local grip, f = bag.grips.RIGHT, bag.frame
        grip:GetScript("OnMouseDown")(grip, "LeftButton")
        local left, top = topLeft(bag)
        f:_SetRect(left, top - 500, f:GetWidth() + 40, 500)
        f:GetScript("OnSizeChanged")(f, f:GetWidth(), 500)
        grip:GetScript("OnMouseUp")(grip, "LeftButton")
        finishTweens()
        local _, b, r, t = edges(bag)
        assert.are.same({ 1000, 500 }, { t, b }, "its top still")
        assert.are.same({ r, 1000, "RIGHT", "TOP" }, db.corners[BACKPACK])
      end)

      it("glides back to its default size with Shift-click, its top and the side across from the grip still", function()
        db.autosize = false
        db.sizes[BACKPACK] = { style.BODY_WIDTH + 100, 500 }
        db.corners[BACKPACK] = { 1700, 1000, "RIGHT", "TOP" }
        local bag = opened(function(c) return nextBag:Create(c) end)
        local grip = bag.grips.LEFT
        override(_G, "IsShiftKeyDown", function() return true end)
        grip:GetScript("OnMouseUp")(grip, "LeftButton")
        step(1 / 60)
        assert.is_true(bag.sizeGliding)
        while bag.sizeGliding do
          step(1 / 60)
          local _, _, r, t = edges(bag)
          assert.is_true(math.abs(t - 1000) <= 1 and math.abs(r - 1700) <= 1, "its top right still")
        end
        finishTweens()
        assert.are.same({ style.BODY_WIDTH, math.floor(H * style.Small.Height) }, { bag.frame:GetWidth(), bag.frame:GetHeight() })
        assert.are.same({ 1700, 1000, "RIGHT", "TOP" }, db.corners[BACKPACK])
      end)

      -- Asked: "when dragging by title bar == left/right anchor only".
      it("holds the bottom corner of its half once dragged by its title, dropped in the top half too", function()
        db.autosize = false
        db.corners[BACKPACK] = { 300, 1000, "LEFT", "TOP" }
        local bag = opened(function(c) return nextBag:Create(c) end)
        local w, h = bag.frame:GetWidth(), bag.frame:GetHeight()
        dragTo(bag, 1400, 1150)
        assert.are.same({ 1400 + w, 1150 - h, "RIGHT", "BOTTOM" }, db.corners[BACKPACK])
        assert.are.same({ 1400, 1150 }, { topLeft(bag) })
      end)

      -- Chained bags line up by the edge their anchor holds: its top, each growing down on its own.
      it("lines a chained bag up with an anchor holding its top by their tops", function()
        db.autosize = true
        db.corners[BACKPACK] = { 1700, 1000, "RIGHT", "TOP" }
        local bag = holds(64)
        local bank = opened(function(c) return nextBank:Create(c) end)
        settle()
        assert.are_not.equal(bag.frame:GetHeight(), bank.frame:GetHeight(), "of different heights")
        local bx, by = topLeft(bag)
        local x, y = chain:ChainedPlace(bank, bag, bx, by)
        assert.are.equal(by, y, "its spot's top the anchor's")
        dragTo(bank, x + 10, y - 10)
        assert.are.equal("backpack", db.smallChain)
        settle()
        assert.are.equal(select(4, edges(bag)), select(4, edges(bank)))
        holding(bag, 8)
        settle()
        assert.are.equal(select(4, edges(bag)), select(4, edges(bank)), "still, as the anchor shrinks")
      end)

      -- topPair opens a backpack holding a top right corner and a bank chained beside it, of another height.
      local function topPair(autosize)
        db.autosize = autosize
        db.clamp = false
        db.corners[BACKPACK] = { 1700, 1000, "RIGHT", "TOP" }
        local bag = holds(64)
        local bank = nextBank:Create(ctx())
        local list = {}
        for i = 1, 4 do table.insert(list, item("6_" .. i, "Ore")) end
        bank:Draw(ctx(), { sortedItems = {}, tabs = { [bank:GetCurrentTabID()] = { categories = { { name = "Ore" } },
          items = list } } }, function() end)
        bank:Show(ctx())
        settle()
        db.smallChain = "backpack"
        chain:Update(ctx())
        settle()
        return bag, bank
      end

      -- Found by the bug review: dragged by its title it holds a bottom corner once dropped, and the bag beside it, carried by
      -- their tops on the way, jumped to line up by their bottoms (446 units at once). It glides there, as a drop beside a
      -- partner does.
      it("glides the bag beside it level by their bottoms once it is dropped by its title, never jumping", function()
        local bag, bank = topPair(true)
        assert.are_not.equal(bag.frame:GetHeight(), bank.frame:GetHeight(), "of different heights")
        assert.are.equal(select(4, edges(bag)), select(4, edges(bank)), "tops level")
        bag.mover:GetScript("OnDragStart")(bag.mover, "LeftButton")
        local f = bag.frame
        local x, y = topLeft(bag)
        f:_SetRect(x - 400, y - 50 - f:GetHeight(), f:GetWidth(), f:GetHeight())
        bag.mover:GetScript("OnUpdate")(bag.mover, 0.016)
        local during = { edges(bank) }
        bag.mover:GetScript("OnDragStop")(bag.mover)
        assert.are.equal("BOTTOM", db.corners[BACKPACK][4])
        assert.are.same(during, { edges(bank) }, "where the drag carried it, as it is dropped")
        step(1 / 60)
        assert.is_true(tween:IsPlaying(bank), "gliding level")
        settle()
        assert.are.equal(bottom(bag), bottom(bank), "their bottoms level")
        assert.are.equal("backpack", db.smallChain)
      end)

      -- Found by the bug review of that glide: it glided wherever the bag beside it had a new spot, so a drop the screen's edge
      -- moves (Autosize Bags keeping all of it on the screen) moved the anchor at once and slid its partner after it, and at a
      -- Bag Scale whose gap is a fraction of a pixel an ordinary drop glided it a pixel. Only a drop that changes the edge the
      -- pair lines up by glides; any other moves the pair together, as before.
      for _, scale in ipairs({ 100, 90, 115 }) do
        it("moves the bag beside it with it at once where the drop keeps the edge it held, Bag Scale " .. scale .. "%", function()
          db.autosize = true
          db.clamp = false
          db.bagScale = scale
          local bag = holds(8)
          local bank = nextBank:Create(ctx())
          bank:Show(ctx())
          settle()
          db.smallChain = "backpack"
          chain:Update(ctx())
          settle()
          local f = bag.frame
          for i, top in ipairs({ 1350, 900.37, 700.81, 650.5 }) do
            bag.mover:GetScript("OnDragStart")(bag.mover, "LeftButton")
            local left = 1100 + i * 7.29
            local s = bag:Scale()
            f:_SetRect(left / s, top / s - f:GetHeight(), f:GetWidth(), f:GetHeight())
            bag.mover:GetScript("OnUpdate")(bag.mover, 0.016)
            bag.mover:GetScript("OnDragStop")(bag.mover)
            assert.is_false(tween:IsPlaying(bank), "no glide, dropped at " .. top)
            assert.is_true(math.abs(bottom(bag) - bottom(bank)) < 1, "level at once, dropped at " .. top)
            settle()
          end
        end)
      end

      -- Its Shift-click keeps the edge it lines up with its anchor by (HeldEdge): its top beside an anchor holding a top corner.
      it("keeps the bag beside it level by their tops as that bag's Shift-click glides it to its default size", function()
        db.sizes[BANK] = { style.BODY_WIDTH + 100, 500 }
        local bag, bank = topPair(false)
        assert.are.equal(select(4, edges(bag)), select(4, edges(bank)))
        override(_G, "IsShiftKeyDown", function() return true end)
        local grip = bank.grips.LEFT
        grip:GetScript("OnMouseUp")(grip, "LeftButton")
        step(1 / 60)
        assert.is_true(bank.sizeGliding)
        while bank.sizeGliding do
          step(1 / 60)
          assert.is_true(math.abs(select(4, edges(bag)) - select(4, edges(bank))) <= 1, "level by their tops")
        end
        settle()
        assert.are.equal(select(4, edges(bag)), select(4, edges(bank)))
      end)

      it("keeps its top where a grip let go bounces its height back, Autosize Bags on", function()
        db.autosize = true
        db.clamp = false
        db.corners[BACKPACK] = { 1700, 1000, "RIGHT", "TOP" }
        local bag = holds(8)
        local grip, f = bag.grips.LEFT, bag.frame
        grip:GetScript("OnMouseDown")(grip, "LeftButton")
        local left, top = topLeft(bag)
        local w = f:GetWidth() + 120
        f:_SetRect(left + f:GetWidth() - w, top - f:GetHeight() - 60, w, f:GetHeight() + 60)
        f:GetScript("OnSizeChanged")(f, w, f:GetHeight())
        grip:GetScript("OnMouseUp")(grip, "LeftButton")
        assert.are.equal(1000, bag.placeY, "placed from the top it holds")
        while bag.sizeGliding do
          step(1 / 60)
          assert.are.equal(1000, select(4, edges(bag)), "its top still as its height bounces back")
        end
        settle()
        assert.are.same({ 1700, 1000, "RIGHT", "TOP" }, db.corners[BACKPACK])
      end)

      -- Pushed up to keep its bottom on the screen, a grip and a Shift-click save the top it holds, not where it was pushed
      -- to, so it goes back down as it shrinks.
      it("keeps the top it holds through a grip let go on it pushed up, Autosize Bags on", function()
        db.autosize = true
        db.clamp = false
        db.corners[BACKPACK] = { 300, 400, "LEFT", "TOP" }
        local bag = holds(80)
        assert.is_true(select(4, edges(bag)) > 400, "pushed up")
        local grip, f = bag.grips.RIGHT, bag.frame
        grip:GetScript("OnMouseDown")(grip, "LeftButton")
        local left, top = topLeft(bag)
        f:_SetRect(left, top - f:GetHeight() - 50, f:GetWidth() + 120, f:GetHeight() + 50)
        f:GetScript("OnSizeChanged")(f, f:GetWidth(), f:GetHeight())
        grip:GetScript("OnMouseUp")(grip, "LeftButton")
        settle()
        assert.are.same({ 300, 400, "LEFT", "TOP" }, db.corners[BACKPACK])
        holding(bag, 8)
        settle()
        assert.are.equal(400, select(4, edges(bag)), "back down to the top it holds")
      end)

      it("glides its top to the one it holds with Shift-click where it was pushed up, Autosize Bags on", function()
        db.autosize = true
        db.clamp = false
        -- Three columns of icons wide: far taller than at its default width.
        db.sizes[BACKPACK] = { 2 * style.PAD + scrollbox:GutterWidthFor({ Symmetric = true }) + 3 * (style.ICON + style.GAP)
          - style.GAP }
        db.corners[BACKPACK] = { 300, 700, "LEFT", "TOP" }
        local bag = holds(40)
        assert.is_true(select(4, edges(bag)) > 700, "pushed up")
        assert.are.equal("resetting", bag:ResetSize("RIGHT"))
        settle()
        assert.are.same({ 300, 700, "LEFT", "TOP" }, db.corners[BACKPACK])
        assert.is_true(bag.frame:GetHeight() < 700, "it fits under the top it holds at its default width")
        assert.are.equal(700, select(4, edges(bag)), "back down to the top it holds")
      end)

      it("keeps a top corner as Clamp Bags to Screen is turned on", function()
        db.autosize = true
        db.clamp = false
        db.corners[BACKPACK] = { 1700, 1000, "RIGHT", "TOP" }
        holds(16)
        db.clamp = true
        chain:ClampChanged(ctx())
        settle()
        assert.are.same({ 1700, 1000, "RIGHT", "TOP" }, db.corners[BACKPACK])
      end)
    end)
  end)

  -- The anchor button (docs/next-bag-anchor.md). Asked: "replace the 'clean up bags' button in the header since it's duplicate
  -- functionality now that you can right click the header to clean up bags. instead, let's replace it with an anchor control
  -- ... button at the top toggles our visible anchors for the bag *and* switches to anchor mode. they drag the visible anchor
  -- with the same mechanics as the classic bags ... press the button again to lock the anchor and bags so they can't be
  -- dragged ... press the button again to release anchor (basically, tri-state button)"; then: "resize is locked too".
  describe("its anchor", function()
    local function opened(create)
      local panel = create(ctx())
      panel:Show(ctx())
      finishTweens()
      return panel
    end

    local function click(panel)
      panel.anchorButton:GetScript("OnClick")(panel.anchorButton, "LeftButton")
    end

    local function dragTo(panel, x, y)
      panel.mover:GetScript("OnDragStart")(panel.mover, "LeftButton")
      local f = panel.frame
      f:_SetRect(x, y - f:GetHeight(), f:GetWidth(), f:GetHeight())
      panel.mover:GetScript("OnDragStop")(panel.mover)
    end

    -- squareAt says where panel's anchor square's corner is: its point, and where.
    local function squareAt(panel)
      local point, rel, relPoint, x, y = panel.anchorSquare:GetPoint(1)
      assert.are.same({ UIParent, "BOTTOMLEFT" }, { rel, relPoint })
      return point, x, y
    end

    -- dragSquare drags panel's square with the client (its rect) so its bottom left is at x, y, a frame of it.
    local function dragSquare(panel, x, y)
      local square = panel.anchorSquare
      square:_SetRect(x, y, square:GetWidth(), square:GetHeight())
      square:GetScript("OnUpdate")(square, 0.016)
    end

    it("is the button where the sort button was, in the backpack's and the bank's header, while they are small", function()
      local bag = nextBag:Create(ctx())
      local bank = nextBank:Create(ctx())
      assert.is_nil(bag.sortButton, "sorted by a right click on its title")
      assert.is_nil(bank.sortButton, "sorted by a right click on its title")
      for _, panel in ipairs({ bag, bank }) do
        assert.is_true(panel.anchorButton:IsShown())
        assert.are.equal("anchorButtonFree", panel.anchorButton.iconKey)
      end
      local keys = {}
      for _, button in ipairs(bag.headerButtons) do table.insert(keys, button.key) end
      assert.are.same({ "closeButton", "settingsButton", "anchorButton", "bagsButton", "sizeButton" }, keys)
      nextPanel:SetSize(ctx(), "full")
      assert.is_false(bag.anchorButton:IsShown(), "a full-size bag rests at its screen edge: nothing to anchor")
      assert.is_false(bank.anchorButton:IsShown())
      nextPanel:SetSize(ctx(), "small")
      assert.is_true(bag.anchorButton:IsShown())
    end)

    it("cycles free, shown, locked and free again, saved for its kind, its icon and tooltip saying what a click does", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      local button = bag.anchorButton
      local function tip()
        button:GetScript("OnEnter")(button)
        local text = GameTooltip:GetText()
        button:GetScript("OnLeave")(button)
        return text
      end
      assert.are.equal("Show Bag Anchor", tip())
      click(bag)
      assert.are.equal("shown", db.anchors[BACKPACK])
      assert.are.equal("anchorButtonShown", button.iconKey)
      assert.are.equal("Lock Bag", tip())
      click(bag)
      assert.are.equal("locked", db.anchors[BACKPACK])
      assert.are.equal("anchorButtonLocked", button.iconKey)
      assert.are.equal("Unlock Bag", tip())
      click(bag)
      assert.is_nil(db.anchors[BACKPACK], "free saves nothing")
      assert.are.equal("anchorButtonFree", button.iconKey)
      assert.is_nil(db.anchors[BANK])
    end)

    it("names what a click does in a theme's bag button menu", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      local spec = bag.anchorButton.spec
      assert.are.equal("Show Bag Anchor", spec.label())
      click(bag)
      assert.are.equal("Lock Bag", spec.label())
      click(bag)
      assert.are.equal("Unlock Bag", spec.label())
    end)

    -- The classic bags' anchor (frames/anchor.lua): one look for both designs.
    it("shows the classic bags' anchor square on the corner it holds while shown, and only while it is open", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      dragTo(bag, 1400, 900)
      assert.is_nil(bag.anchorSquare, "made when first shown")
      click(bag)
      local square = bag.anchorSquare
      assert.is_true(square:IsShown())
      assert.are.same({ 72, 72 }, { square:GetSize() })
      assert.are.same({ 48 / 255, 168 / 255, 1, 1 }, { square:GetBackdropColor() })
      assert.are.same({ 0, 0, 0, 1 }, { square:GetBackdropBorderColor() })
      assert.are.equal("FULLSCREEN_DIALOG", square:GetFrameStrata())
      assert.is_true(square:IsClampedToScreen())
      local c = db.corners[BACKPACK]
      assert.are.same({ "BOTTOMRIGHT", c[1], c[2] }, { squareAt(bag) })
      assert.are.equal("Backpack", square.label:GetText())
      assert.are.equal(string.format("%dx %dy", c[1], c[2]), square.positionLabel:GetText())
      bag:Hide(ctx())
      assert.is_false(square:IsShown(), "it closes with the bag")
      finishTweens()
      bag:Show(ctx())
      finishTweens()
      assert.is_true(square:IsShown())
      click(bag)
      assert.is_false(square:IsShown(), "locked: hidden")
      click(bag)
      assert.is_false(square:IsShown(), "free: hidden")
      dragTo(bag, 300, 900)
      click(bag)
      local cl = db.corners[BACKPACK]
      assert.are.same({ "BOTTOMLEFT", cl[1], cl[2] }, { squareAt(bag) }, "a bag holding its left")
    end)

    it("hides its square as a full-size bag, and shows it again small", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      click(bag)
      nextPanel:SetSize(ctx(), "full")
      assert.is_false(bag.anchorSquare:IsShown())
      finishTweens()
      nextPanel:SetSize(ctx(), "small")
      assert.is_true(bag.anchorSquare:IsShown())
    end)

    -- The classic anchor's drag: the bag's corner pinned to the square's same corner, the side its half of the screen.
    it("moves the bag with its square, the bag's corner on the square's, the side following the half of the screen it is on",
      function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      click(bag)
      local square = bag.anchorSquare
      local w, h = bag.frame:GetWidth(), bag.frame:GetHeight()
      square:GetScript("OnDragStart")(square, "LeftButton")
      assert.is_true(square._moving)
      dragSquare(bag, 1500, 300)
      assert.are.same({ 1572, 300, "RIGHT", "BOTTOM" }, db.corners[BACKPACK])
      assert.are.same({ 1572 - w, 300 + h }, { topLeft(bag) }, "its bottom right on the square's")
      assert.are.equal("1572x 300y", square.positionLabel:GetText())
      dragSquare(bag, 200, 150)
      assert.are.same({ 200, 150, "LEFT", "BOTTOM" }, db.corners[BACKPACK])
      assert.are.same({ 200, 150 + h }, { topLeft(bag) }, "its bottom left on the square's")
      square:GetScript("OnDragStop")(square)
      assert.is_false(square._moving)
      assert.are.same({ "BOTTOMLEFT", 200, 150 }, { squareAt(bag) })
      assert.is_nil(square:GetScript("OnUpdate"), "it stops following once let go")
      assert.are.same({ 200, 150, "LEFT", "BOTTOM" }, db.corners[BACKPACK])
      assert.are.same({ 200, 150 + h }, { topLeft(bag) })
    end)

    it("moves the square with the bag dragged by its title", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      click(bag)
      local h = bag.frame:GetHeight()
      bag.mover:GetScript("OnDragStart")(bag.mover, "LeftButton")
      local f = bag.frame
      f:_SetRect(300, 1000 - h, f:GetWidth(), h)
      bag.mover:GetScript("OnUpdate")(bag.mover, 0.016)
      assert.are.same({ "BOTTOMLEFT", 300, 1000 - h }, { squareAt(bag) }, "following it as it is dragged")
      bag.mover:GetScript("OnDragStop")(bag.mover)
      assert.are.same({ "BOTTOMLEFT", 300, 1000 - h }, { squareAt(bag) })
    end)

    -- Asked: "let's do the 4 quadrant anchoring instead of just left and right ... top anchors only work when you drag via the
    -- box, not the title": the square's quadrant (its middle's) picks the bag's corner, the top ones in the top half.
    it("takes any of its four corners from its square, a top one in the top half of the screen", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      click(bag)
      local square = bag.anchorSquare
      local w = bag.frame:GetWidth()
      square:GetScript("OnDragStart")(square, "LeftButton")
      dragSquare(bag, 1500, 900)
      assert.are.same({ 1572, 972, "RIGHT", "TOP" }, db.corners[BACKPACK])
      assert.are.same({ 1572 - w, 972 }, { topLeft(bag) }, "its top right on the square's")
      assert.are.equal("1572x 972y", square.positionLabel:GetText())
      dragSquare(bag, 200, 800)
      assert.are.same({ 200, 872, "LEFT", "TOP" }, db.corners[BACKPACK])
      assert.are.same({ 200, 872 }, { topLeft(bag) }, "its top left on the square's")
      -- By its middle: just under the screen's, a bottom corner; on it, a top one.
      local half = UIParent:GetHeight() / 2
      dragSquare(bag, 200, half - 36 - 1)
      assert.are.equal("BOTTOM", db.corners[BACKPACK][4])
      dragSquare(bag, 200, half - 36)
      assert.are.equal("TOP", db.corners[BACKPACK][4])
      dragSquare(bag, 200, 800)
      square:GetScript("OnDragStop")(square)
      assert.are.same({ "TOPLEFT", 200, 872 }, { squareAt(bag) })
      assert.are.same({ 200, 872, "LEFT", "TOP" }, db.corners[BACKPACK])
    end)

    it("shows its square on the top corner it holds", function()
      db.corners[BACKPACK] = { 1700, 1000, "RIGHT", "TOP" }
      local bag = opened(function(c) return nextBag:Create(c) end)
      click(bag)
      assert.are.same({ "TOPRIGHT", 1700, 1000 }, { squareAt(bag) })
      assert.are.equal("1700x 1000y", bag.anchorSquare.positionLabel:GetText())
    end)

    -- Asked: "when dragging by title bar == left/right anchor only": the square follows a title drag on the bottom corner of
    -- the bag's half of the screen, wherever it is.
    it("moves its square on the bottom corner of its half as a bag holding its top is dragged by its title", function()
      db.corners[BACKPACK] = { 1700, 1000, "RIGHT", "TOP" }
      local bag = opened(function(c) return nextBag:Create(c) end)
      click(bag)
      local h = bag.frame:GetHeight()
      bag.mover:GetScript("OnDragStart")(bag.mover, "LeftButton")
      local f = bag.frame
      f:_SetRect(300, 1100 - h, f:GetWidth(), h)
      bag.mover:GetScript("OnUpdate")(bag.mover, 0.016)
      assert.are.same({ "BOTTOMLEFT", 300, 1100 - h }, { squareAt(bag) })
      bag.mover:GetScript("OnDragStop")(bag.mover)
      assert.are.same({ 300, 1100 - h, "LEFT", "BOTTOM" }, db.corners[BACKPACK])
      assert.are.same({ "BOTTOMLEFT", 300, 1100 - h }, { squareAt(bag) })
    end)

    -- Asked (the classic anchor's): a right click on the square hides it, the bag still anchored: locked.
    it("locks the bag as its square is right-clicked", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      click(bag)
      bag.anchorSquare:GetScript("OnMouseDown")(bag.anchorSquare, "RightButton")
      assert.are.equal("locked", db.anchors[BACKPACK])
      assert.is_false(bag.anchorSquare:IsShown())
      assert.are.equal("anchorButtonLocked", bag.anchorButton.iconKey)
    end)

    it("neither moves nor resizes while locked, its grips hidden, and says so; unlocked, both again", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      local x0, y0 = topLeft(bag)
      click(bag)
      click(bag)
      assert.is_true(bag:Held())
      bag.mover:GetScript("OnDragStart")(bag.mover, "LeftButton")
      assert.is_nil(bag.frame._moving, "its title row does not drag it")
      bag.titleButton:GetScript("OnDragStart")(bag.titleButton, "LeftButton")
      assert.is_nil(bag.frame._moving, "nor its title")
      assert.is_false(bag.grips.LEFT:IsShown() or bag.grips.RIGHT:IsShown(), "its grips hidden")
      assert.is_false(bag:StartSizing("RIGHT"))
      db.sizes[BACKPACK] = { 700, 500 }
      assert.are.equal("locked", bag:ResetSize("RIGHT"))
      assert.are.same({ 700, 500 }, db.sizes[BACKPACK], "Shift-click does not reset it")
      assert.are.same({ x0, y0 }, { topLeft(bag) })
      assert.are.equal("Locked in place: unlock it with its anchor button.", chain:Tooltip(bag))
      click(bag)
      assert.is_false(bag:Held())
      assert.is_true(bag.grips.LEFT:IsShown() and bag.grips.RIGHT:IsShown())
      assert.are.equal("Drag to move it.", chain:Tooltip(bag))
      bag.mover:GetScript("OnDragStart")(bag.mover, "LeftButton")
      assert.is_true(bag.frame._moving)
      bag.mover:GetScript("OnDragStop")(bag.mover)
    end)

    -- Asked: "anchoring the chained bag (the one sitting beside its partner) unchains it, the same as dragging it does"; and
    -- "locking a bag holds the bag chained beside it too".
    it("unchains the bag that sits beside its partner as its anchor shows", function()
      db.smallChain = "backpack"
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = opened(function(c) return nextBank:Create(c) end)
      assert.are.equal(bag, chain:SmallAnchorOf(bank))
      click(bank)
      assert.are.equal("apart", db.smallChain)
      assert.is_nil(chain:SmallAnchorOf(bank))
    end)

    it("unchains the backpack chained beside a companion that is not open, as its anchor shows", function()
      db.smallChain = "companion"
      local bag = opened(function(c) return nextBag:Create(c) end)
      click(bag)
      assert.are.equal("apart", db.smallChain, "it would sit beside the next companion that opens")
    end)

    it("keeps the chain of a bag whose anchor shows where the bag beside it is the other", function()
      db.smallChain = "backpack"
      local bag = opened(function(c) return nextBag:Create(c) end)
      opened(function(c) return nextBank:Create(c) end)
      click(bag)
      assert.are.equal("backpack", db.smallChain, "the backpack anchors the pair")
    end)

    it("never chains a bag whose anchor shows, dropped beside its partner", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = opened(function(c) return nextBank:Create(c) end)
      click(bank)
      local x, y = chain:ChainedPlace(bank, bag, bag.placeX, bag.placeY)
      dragTo(bank, x, y)
      assert.are.equal("apart", db.smallChain)
    end)

    -- A locked bag cannot be dragged: its chain is asked directly (chain:Dropped), as a drop would.
    it("never chains a locked bag dropped beside its partner", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = opened(function(c) return nextBank:Create(c) end)
      click(bank)
      click(bank)
      local x, y = chain:ChainedPlace(bank, bag, bag.placeX, bag.placeY)
      assert.is_nil((chain:Dropped(bank, x, y)))
      assert.are.equal("apart", db.smallChain)
    end)

    it("holds the bag chained beside a locked bag", function()
      db.smallChain = "backpack"
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = opened(function(c) return nextBank:Create(c) end)
      click(bag)
      click(bag)
      assert.is_true(bank:Held())
      assert.is_false(bank:StartMove())
      assert.is_false(bank.grips.LEFT:IsShown(), "its grips hidden too")
      assert.are.equal("Locked beside the Backpack.", chain:Tooltip(bank))
      click(bag)
      assert.is_false(bank:Held())
      assert.is_true(bank.grips.LEFT:IsShown())
    end)

    -- Found by the second bug review: anchoring a chained bag part way through its height's glide saved its corner from its place
    -- at the glide's height less its height at rest, its bottom off its partner's; it dropped at its next height change.
    it("saves its bottom level with its partner's as it is anchored part way through its height's glide", function()
      db.autosize = true
      db.smallChain = "companion"
      local function contents(n)
        local list = {}
        for i = 1, n do table.insert(list, item("0_" .. i, "Herbs")) end
        return { sortedItems = {}, tabs = { [1] = { categories = { { name = "Herbs" } }, items = list } } }
      end
      local bank = opened(function(c) return nextBank:Create(c) end)
      local bag = nextBag:Create(ctx())
      bag:Draw(ctx(), contents(8), function() end)
      bag:Show(ctx())
      finishTweens()
      render:Flush()
      finishTweens()
      local level = select(2, topLeft(bank)) - bank.frame:GetHeight()
      bag:Draw(ctx(), contents(64), function() end)
      render:Flush()
      for _ = 1, 3 do tween.driver:GetScript("OnUpdate")(tween.driver, 1 / 60) end
      assert.is_true(bag.sizeGliding, "its height part way through its glide")
      click(bag)
      assert.are.equal("apart", db.smallChain, "unchained")
      assert.are.equal(level, db.corners[BACKPACK][2], "its bottom level with the bank's")
      assert.are.equal(level, select(3, squareAt(bag)), "its square there")
      finishTweens()
      bag:Draw(ctx(), contents(30), function() end)
      render:Flush()
      finishTweens()
      render:Flush()
      finishTweens()
      assert.are.equal(level, select(2, topLeft(bag)) - bag.frame:GetHeight(), "still there as its height changes")
    end)

    -- Found by the second bug review: locking a bag already anchored (chained to none) set the chain "apart", letting go of
    -- another companion chained beside the backpack.
    it("keeps another companion chained beside the backpack as a bag already anchored is locked", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = opened(function(c) return nextBank:Create(c) end)
      dragTo(bank, 100, 900)
      click(bank)
      local other = opened(function(c) return nextBank:Create(c) end)
      other.kind = 77
      local x, y = chain:ChainedPlace(other, bag, bag.placeX, bag.placeY)
      dragTo(other, x, y)
      finishTweens()
      assert.are.equal("backpack", db.smallChain)
      click(bank)
      assert.are.equal("locked", db.anchors[BANK])
      assert.are.equal("backpack", db.smallChain, "the other companion's chain kept")
      assert.are.equal(bag, chain:SmallAnchorOf(other))
    end)

    -- Found by the second bug review: a bag freed where the chain sits it beside a partner (layout "backpack", set by another
    -- companion's drop) was chained at once but left where it was drawn, and jumped beside the backpack at the next move.
    -- Freed, it follows the chain's rule: it glides into its spot beside its partner, and the pair braids.
    it("glides a freed bag into the spot the chain gives it beside its partner, and braids", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = opened(function(c) return nextBank:Create(c) end)
      dragTo(bank, 100, 900)
      click(bank)
      click(bank)
      local other = opened(function(c) return nextBank:Create(c) end)
      other.kind = 77
      local x, y = chain:ChainedPlace(other, bag, bag.placeX, bag.placeY)
      dragTo(other, x, y)
      finishTweens()
      other:Hide(ctx())
      finishTweens()
      click(bank)
      assert.is_nil(db.anchors[BANK], "free")
      assert.is_true(tween:IsPlaying(bank), "gliding into its spot")
      finishTweens()
      local spot = { chain:ChainedPlace(bank, bag, bag.placeX, bag.placeY) }
      assert.are.same(spot, { topLeft(bank) })
      assert.are.same(spot, { bank.placeX, bank.placeY })
      assert.is_not_nil(chain.coupling, "braided")
    end)

    -- Found by the third bug review: freed part way through its open slide, its glide into its spot replaced the slide, whose end
    -- says it has shown (onShown, next/PanelShown: a bank's contents wait for it), so it never finished opening. Busy, it is owed
    -- the glide (spotMoved), which its slide's end pays (chain:Arrived).
    it("finishes opening a bag freed part way through its open slide, then glides it into its spot", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = opened(function(c) return nextBank:Create(c) end)
      dragTo(bank, 100, 900)
      click(bank)
      click(bank)
      bank:Hide(ctx())
      finishTweens()
      db.smallChain = "backpack"
      local shown = 0
      bank:Show(ctx(), nil, function() shown = shown + 1 end)
      for _ = 1, 3 do tween.driver:GetScript("OnUpdate")(tween.driver, 1 / 60) end
      assert.is_true(tween:IsPlaying(bank), "its open slide")
      click(bank)
      assert.is_nil(db.anchors[BANK], "free")
      finishTweens()
      assert.are.equal(1, shown, "it finished opening")
      assert.is_nil(bank.onShown)
      assert.are.same({ chain:ChainedPlace(bank, bag, bag.placeX, bag.placeY) }, { topLeft(bank) })
      assert.is_not_nil(chain.coupling, "braided")
    end)

    -- Found by the third bug review: freed part way through its height's glide, its glide into its spot started from where the
    -- size glide ends and both placed it each frame: it jumped 187 units in the frame of the click.
    it("finishes its height's glide where it was freed, then glides into its spot", function()
      db.autosize = true
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = nextBank:Create(ctx())
      local function tabbed(n)
        local list = {}
        for i = 1, n do table.insert(list, item("6_" .. i, "Ore")) end
        return { sortedItems = {}, tabs = { [bank:GetCurrentTabID()] = { categories = { { name = "Ore" } }, items = list } } }
      end
      bank:Draw(ctx(), tabbed(8), function() end)
      bank:Show(ctx())
      finishTweens()
      render:Flush()
      finishTweens()
      dragTo(bank, 100, 900)
      finishTweens()
      click(bank)
      click(bank)
      db.smallChain = "backpack"
      bank:Draw(ctx(), tabbed(64), function() end)
      render:Flush()
      for _ = 1, 3 do tween.driver:GetScript("OnUpdate")(tween.driver, 1 / 60) end
      assert.is_true(bank.sizeGliding, "its height glides")
      local x0, y0 = topLeft(bank)
      click(bank)
      assert.are.same({ x0, y0 }, { topLeft(bank) }, "the click moves it nowhere")
      local spotGlide = false
      for frame = 1, 40 do
        tween.driver:GetScript("OnUpdate")(tween.driver, 1 / 60)
        assert.is_false(bank.sizeGliding and tween:IsPlaying(bank), "one glide at a time, frame " .. frame)
        if bank.sizeGliding then
          assert.are.equal(x0, (topLeft(bank)), "its height glides where it was, frame " .. frame)
        end
        spotGlide = spotGlide or tween:IsPlaying(bank)
      end
      assert.is_true(spotGlide, "it glided into its spot after")
      finishTweens()
      render:Flush()
      finishTweens()
      assert.are.same({ chain:ChainedPlace(bank, bag, bag.placeX, bag.placeY) }, { topLeft(bank) })
      assert.is_not_nil(chain.coupling, "braided")
    end)

    -- As the third bug review found for a freed bag: a grip let go on an anchor glided the bag beside it level on top of its open
    -- slide, which then never finished. It is owed the glide, paid as its slide ends.
    it("finishes opening the bag beside an anchor whose grip moved its bottom as it opened, then glides it level", function()
      db.autosize = false
      db.smallChain = "backpack"
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = nextBank:Create(ctx())
      local shown = 0
      bank:Show(ctx(), nil, function() shown = shown + 1 end)
      for _ = 1, 3 do tween.driver:GetScript("OnUpdate")(tween.driver, 1 / 60) end
      assert.is_true(tween:IsPlaying(bank), "its open slide")
      -- The right grip pressed, the client sizing it 900 tall from its top left, let go.
      local grip, f = bag.grips.RIGHT, bag.frame
      grip:GetScript("OnMouseDown")(grip, "LeftButton")
      local left, top = topLeft(bag)
      f:_SetRect(left, top - 900, f:GetWidth(), 900)
      f:GetScript("OnSizeChanged")(f, f:GetWidth(), 900)
      grip:GetScript("OnMouseUp")(grip, "LeftButton")
      finishTweens()
      assert.are.equal(1, shown, "it finished opening")
      local _, bagTop = topLeft(bag)
      local _, bankTop = topLeft(bank)
      assert.are.equal(bagTop - bag.frame:GetHeight(), bankTop - bank.frame:GetHeight(), "their bottoms level")
    end)

    -- A click in its close slide's 0.24 s frees it without a glide into its spot, which would fight the slide; it opens there.
    it("does not glide a bag freed as it closes into its spot", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = opened(function(c) return nextBank:Create(c) end)
      dragTo(bank, 100, 900)
      click(bank)
      click(bank)
      local other = opened(function(c) return nextBank:Create(c) end)
      other.kind = 77
      local x, y = chain:ChainedPlace(other, bag, bag.placeX, bag.placeY)
      dragTo(other, x, y)
      finishTweens()
      other:Hide(ctx())
      finishTweens()
      bank:Hide(ctx())
      assert.is_true(bank.closing)
      local glides = 0
      override(bank, "GlideTo", function() glides = glides + 1 end)
      click(bank)
      assert.is_nil(db.anchors[BANK], "free")
      assert.are.equal(0, glides)
      finishTweens()
      assert.is_false(bank.frame:IsShown(), "closed")
    end)

    -- Found by the bug review: another companion dropped beside the backpack sets the layout to "backpack", which chained every
    -- companion, the anchored bank too: it was drawn beside the backpack, its square left where its corner is.
    for _, state in ipairs({ "shown", "locked" }) do
      it("keeps a " .. state .. " bank where it holds as another companion is dropped beside the backpack", function()
        local OTHER = 77
        local bag = opened(function(c) return nextBag:Create(c) end)
        local bank = opened(function(c) return nextBank:Create(c) end)
        dragTo(bank, 100, 900)
        local held = { db.corners[BANK][1], db.corners[BANK][2], db.corners[BANK][3], db.corners[BANK][4] }
        click(bank)
        if state == "locked" then click(bank) end
        local other = opened(function(c) return nextBank:Create(c) end)
        other.kind = OTHER
        local x, y = chain:ChainedPlace(other, bag, bag.placeX, bag.placeY)
        dragTo(other, x, y)
        assert.are.equal("backpack", db.smallChain, "the other companion chains to the backpack")
        finishTweens()
        assert.is_nil(chain:SmallAnchorOf(bank), "the anchored bank is not chained")
        assert.are.same({ 100, 900 }, { topLeft(bank) })
        assert.are.same(held, db.corners[BANK])
        bag.mover:GetScript("OnDragStart")(bag.mover, "LeftButton")
        bag.frame:_SetRect(1300, 900 - bag.frame:GetHeight(), bag.frame:GetWidth(), bag.frame:GetHeight())
        bag.mover:GetScript("OnUpdate")(bag.mover, 0.016)
        bag.mover:GetScript("OnDragStop")(bag.mover)
        assert.are.same({ 100, 900 }, { topLeft(bank) }, "the backpack dragged does not carry it")
        assert.are.same(held, db.corners[BANK])
      end)
    end

    -- Found by the bug review: a companion closing while the backpack beside it glided to a new height saved the backpack's
    -- corner from its height part way through the glide, so it jumped at its next height change.
    it("saves the backpack's bottom level with a companion that closes while the backpack's height glides", function()
      db.autosize = true
      db.smallChain = "companion"
      local function contents(n)
        local list = {}
        for i = 1, n do table.insert(list, item("0_" .. i, "Herbs")) end
        return { sortedItems = {}, tabs = { [1] = { categories = { { name = "Herbs" } }, items = list } } }
      end
      local bank = opened(function(c) return nextBank:Create(c) end)
      local bag = nextBag:Create(ctx())
      bag:Draw(ctx(), contents(8), function() end)
      bag:Show(ctx())
      finishTweens()
      render:Flush()
      finishTweens()
      local level = select(2, topLeft(bank)) - bank.frame:GetHeight()
      assert.are.equal(level, select(2, topLeft(bag)) - bag.frame:GetHeight(), "level beside the bank")
      bag:Draw(ctx(), contents(64), function() end)
      render:Flush()
      tween.driver:GetScript("OnUpdate")(tween.driver, 1 / 60)
      tween.driver:GetScript("OnUpdate")(tween.driver, 1 / 60)
      tween.driver:GetScript("OnUpdate")(tween.driver, 1 / 60)
      assert.is_true(bag.sizeGliding, "its height part way through its glide")
      bank:Hide(ctx())
      assert.are.equal(level, db.corners[BACKPACK][2], "its bottom level with the bank's")
      finishTweens()
      render:Flush()
      finishTweens()
      bag:Draw(ctx(), contents(30), function() end)
      render:Flush()
      finishTweens()
      render:Flush()
      finishTweens()
      assert.are.equal(level, select(2, topLeft(bag)) - bag.frame:GetHeight(), "still there as its height changes")
    end)

    -- Found by the bug review: a parent's hide (Alt+Z) part way through the close slide cuts the close short and leaves the
    -- bag open with no Show; its square was hidden as it closed and stayed hidden.
    it("shows its square again where a parent's hide cut its close short", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      click(bag)
      bag:Hide(ctx())
      assert.is_false(bag.anchorSquare:IsShown())
      tween.driver:GetScript("OnUpdate")(tween.driver, 1 / 60)
      bag.frame:GetScript("OnHide")(bag.frame)
      bag.frame:GetScript("OnShow")(bag.frame)
      finishTweens()
      assert.is_true(bag.frame:IsShown() and not bag.closing, "open again")
      assert.is_true(bag.anchorSquare:IsShown())
    end)

    -- Its height waits while its square is dragged, as it does while it is moved by its title, and glides once it is let go.
    it("waits to follow what it shows while its square is dragged, and glides once it is let go", function()
      db.autosize = true
      local bag = opened(function(c) return nextBag:Create(c) end)
      click(bag)
      local square = bag.anchorSquare
      square:GetScript("OnDragStart")(square, "LeftButton")
      local list = {}
      for i = 1, 64 do table.insert(list, item("0_" .. i, "Herbs")) end
      bag:Draw(ctx(), { sortedItems = {}, tabs = { [1] = { categories = { { name = "Herbs" } }, items = list } } }, function() end)
      render:Flush()
      local h = bag.frame:GetHeight()
      for _ = 1, 3 do
        dragSquare(bag, 1500, 300)
        tween.driver:GetScript("OnUpdate")(tween.driver, 1 / 60)
      end
      assert.is_false(bag.sizeGliding, "not while its square is dragged")
      assert.are.equal(h, bag.frame:GetHeight())
      square:GetScript("OnDragStop")(square)
      tween.driver:GetScript("OnUpdate")(tween.driver, 1 / 60)
      tween.driver:GetScript("OnUpdate")(tween.driver, 1 / 60)
      assert.is_true(bag.sizeGliding, "it glides once let go")
      finishTweens()
    end)
  end)
end)
