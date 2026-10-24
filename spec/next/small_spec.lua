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
  { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" },
  { "NextSparkles", "next/sparkles.lua" }, { "NextLift", "next/lift.lua" }, { "NextTabs", "next/tabs.lua" }, { "NextContent", "next/content.lua" },
  { "NextDockCard", "next/dockcard.lua" }, { "NextDock", "next/dock.lua" }, { "NextDrag", "next/drag.lua" }, { "NextChain", "next/chain.lua" }, { "NextOrnaments", "next/ornaments.lua" }, { "NextPanel", "next/panel.lua" },
  { "NextBag", "next/bag.lua" }, { "NextBank", "next/bank.lua" } }
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
local render = addon:GetModule("Render")
local motion = addon:GetModule("Motion")
local context = addon:GetModule("Context")

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

  before_each(function()
    render:Init()
    tween:Init()
    motion:Init()
    nextDrag:Init()
    chain:Init()
    sent, buttons, placed = {}, {}, {}
    db = { size = "small", places = {}, sizes = {}, smallChain = "apart", view = { [BACKPACK] = SECTION_GRID, [BANK] = SECTION_GRID },
      active = { [BACKPACK] = 1, [BANK] = 10 } }
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
    override(stubs.database, "SetNextSize", function(_, size) db.size = size end)
    override(stubs.database, "GetNextSmallPlace", function(_, kind)
      local p = db.places[kind]
      if p then return p[1], p[2] end
    end)
    override(stubs.database, "SetNextSmallPlace", function(_, kind, x, y) db.places[kind] = { x, y } end)
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
    -- The Size tab's scales (docs/next-appearance-size.md), in percent.
    db.iconScale, db.bagScale = 100, 100
    override(stubs.database, "GetNextIconScale", function() return db.iconScale end)
    override(stubs.database, "GetNextBagScale", function() return db.bagScale end)
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
      assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", style.PAD + style.TITLE_INSET, -style.TITLE_TOP },
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
      assert.are.same({ 600, 800 }, db.places[BACKPACK])
      assert.are.same({ 600, 800 }, { topLeft(bag) })
      assert.is_nil(db.places[BANK])
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
      assert.are.same({ 100, 900 }, db.places[BANK])
    end)

    it("keeps its place on the screen", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      drag(bag, nil, 1900, 1500)
      assert.are.same({ UIParent:GetWidth() - style.BODY_WIDTH, UIParent:GetHeight() }, db.places[BACKPACK])
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
      assert.are.same({ 500, 100 + bag.frame:GetHeight() }, db.places[BACKPACK])
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

    local function perRow(panel)
      local width = panel.root:PreRender().Width - panel.scroll:GetGutterWidth()
      local STEP = style.ICON + style.GAP
      return math.floor((width + style.GAP) / STEP)
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
        local header = 2 * style.PAD + style.TITLE_INSET + row + 12 + style.Small.MinTitle
        local column = 2 * style.PAD + style.GUTTER + style.ICON
        assert.are.equal(math.ceil(math.max(header, column)), bag:MinWidth())
        assert.are.equal(style.CONTENT_TOP + style.FOOTER + style.SECTION_HEADER + style.ICON, bag:MinHeight())
      end)

      it("leaves room for the footer's free slots and money", function()
        local bag = nextBag:Create(ctx())
        bag.freeText:SetText(string.rep("8", 60))
        bag.moneyFrame.frame:SetWidth(128)
        local footer = 2 * style.PAD + style.TITLE_INSET + bag.freeText:GetStringWidth() + 12 + 128
        assert.are.equal(math.ceil(footer), bag:MinWidth())
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

      it("keeps the size it is let go at, without snapping, saved for its kind with its place", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        local x0, y0 = topLeft(bag)
        resize(bag, "RIGHT", 377, 640)
        assert.are.same({ 377, 640 }, { bag.frame:GetWidth(), bag.frame:GetHeight() })
        assert.are.same({ 377, 640 }, db.sizes[BACKPACK])
        assert.are.same({ x0, y0 }, { topLeft(bag) })
        assert.are.same({ x0, y0 }, db.places[BACKPACK])
        assert.is_nil(db.sizes[BANK])
        finishTweens()
        assert.are.same({ 377, 640 }, { bag.frame:GetWidth(), bag.frame:GetHeight() }, "no snap")
      end)

      it("moves its left edge from the left grip, its right edge still", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        local x0, y0 = topLeft(bag)
        local right = x0 + bag.frame:GetWidth()
        resize(bag, "LEFT", 600, 500)
        assert.are.same({ right - 600, y0 }, { topLeft(bag) })
        assert.are.same({ right - 600, y0 }, db.places[BACKPACK])
        assert.are.equal(600, bag.frame:GetWidth())
      end)

      it("cuts its title short in the room its header buttons leave", function()
        local bank = opened(function(c) return nextBank:Create(c) end)
        resize(bank, "LEFT", bank:MinWidth(), 500)
        local row = 0
        for _, button in ipairs(bank.headerButtons) do
          if button:IsShown() then row = row + style.HEADER_BUTTON + style.HEADER_BUTTON_GAP end
        end
        row = row - style.HEADER_BUTTON_GAP
        assert.are.equal(bank:MinWidth() - (style.PAD + style.TITLE_INSET) - (style.PAD + row) - 12, bank.title:GetWidth())
        assert.is_false(bank.title._wordWrap)
        nextPanel:SetSize(ctx(), "full")
        finishTweens()
        assert.are.equal(0, bank.title:GetWidth(), "a full panel's title is as long as it is")
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
          local header = 2 * style.PAD + 40 + style.TITLE_INSET + 12 + style.Small.MinTitle
          local cells = 2 * style.PAD + 40 + style.GUTTER + style.ICON
          assert.are.equal(math.ceil(math.max(header, cells)), bag:MinWidth())
          bag.freeText:SetText(string.rep("8", 60))
          bag.moneyFrame.frame:SetWidth(128)
          local footer = 2 * style.PAD + 40 + style.TITLE_INSET + bag.freeText:GetStringWidth() + 12 + 128
          assert.are.equal(math.ceil(footer), bag:MinWidth())
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

      it("stops resizing when it hides, keeping the size it had", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        press(bag.grips.RIGHT)
        sizeTo(bag, "RIGHT", 400, 500)
        bag.frame:Hide()
        bag.frame:GetScript("OnHide")(bag.frame)
        assert.is_nil(bag.frame._sizing)
        assert.is_nil(bag.sizing)
        assert.are.same({ 400, 500 }, db.sizes[BACKPACK])
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

      it("glides it back to its default size, its top left still from the right grip", function()
        db.sizes[BACKPACK] = { 700, 500 }
        local bag = opened(function(c) return nextBag:Create(c) end)
        local x0, y0 = topLeft(bag)
        shiftClick(bag.grips.RIGHT)
        assert.is_nil(bag.frame._sizing, "a Shift-click does not size it")
        step(style.Time.Resize / 2)
        local w, h = bag.frame:GetWidth(), bag.frame:GetHeight()
        assert.is_true(w > style.BODY_WIDTH and w < 700, "width " .. w)
        assert.is_true(h > 500 and h < smallHeight(), "height " .. h)
        assert.are.same({ x0, y0 }, { topLeft(bag) })
        finishTweens()
        assert.are.same({ style.BODY_WIDTH, smallHeight() }, { bag.frame:GetWidth(), bag.frame:GetHeight() })
        assert.is_nil(db.sizes[BACKPACK], "the default follows the screen again")
        assert.are.same({ x0, y0 }, { topLeft(bag) })
        assert.are.same({ x0, y0 }, db.places[BACKPACK])
      end)

      it("keeps its right edge still from the left grip", function()
        db.sizes[BACKPACK] = { 700, 500 }
        local bag = opened(function(c) return nextBag:Create(c) end)
        local x0, y0 = topLeft(bag)
        local right = x0 + 700
        shiftClick(bag.grips.LEFT)
        step(style.Time.Resize / 2)
        local x = topLeft(bag)
        assert.are.equal(right, x + bag.frame:GetWidth())
        finishTweens()
        assert.are.same({ right - style.BODY_WIDTH, y0 }, { topLeft(bag) })
        assert.are.same({ right - style.BODY_WIDTH, y0 }, db.places[BACKPACK])
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
        assert.is_false(tween:IsPlaying(bag.resetKey))
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
        resize(bank, "LEFT", 620, 480)
        finishTweens()
        assert.are.equal(bankRight, select(1, topLeft(bank)) + 620, "the bank's chained side is still")
        assert.are.equal(bagLeft, select(1, topLeft(bag)))
        assert.are.same({ chain:ChainedPlace(bank, bag, bag.placeX, bag.placeY) }, { topLeft(bank) })
        -- The backpack's right edge is 40 from the screen's; the client keeps a sized frame on it.
        resize(bag, "RIGHT", 490, 480)
        finishTweens()
        assert.are.equal(bagLeft, select(1, topLeft(bag)))
        assert.are.equal(bankRight, select(1, topLeft(bank)) + 620)
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
      -- stays beside the bank's chained side, and the braid spans the gap there.
      it("works out where it is from its frame while it is sized", function()
        local bank = opened(function(c) return nextBank:Create(c) end)
        local bag = opened(function(c) return nextBag:Create(c) end)
        db.smallChain = "companion"
        chain:Update(ctx())
        finishTweens()
        local x, y = bag:SmallPlace()
        press(bank.grips.LEFT)
        sizeTo(bank, "LEFT", 620, 480)
        assert.are.same({ x, y }, { bag:SmallPlace() }, "the backpack's spot does not move")
        local gap = bag:SmallLeft() - (bank.frame:GetLeft() + 620)
        chain:Turn(0.016)
        assert.are.equal(gap / 2, bag.braid.half)
        release(bank.grips.LEFT)
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

    it("chains a bag dropped beside its partner's facing side, gliding it into place, its tops aligned", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = opened(function(c) return nextBank:Create(c) end)
      local x, y = besideBag(bag, bank)
      drag(bank, x - style.Small.SnapReach + 1, y + style.Small.SnapRise - 1)
      assert.are.equal("backpack", db.smallChain, "the backpack is the anchor")
      finishTweens()
      assert.are.same({ x, y }, { topLeft(bank) })
      assert.are.same({ x, y }, db.places[BANK])
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
      assert.are.same({ 1000, 1000 }, db.places[BACKPACK])
      assert.are.same({ 1000 - gap - style.BODY_WIDTH, 1000 }, db.places[BANK])
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
      assert.are.same({ 100, 900 }, db.places[BANK])
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
        assert.are.same({ 300, 900 }, db.places[BACKPACK])
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
        bag.frame:_SetRect(x, y - 600, 500, 600)
        bag.frame:GetScript("OnSizeChanged")(bag.frame, 500, 600)
        grip:GetScript("OnMouseUp")(grip, "LeftButton")
        assert.are.same({ 500, 600 }, db.sizes[BACKPACK])
        assert.are.same({ x * 0.5, y * 0.5 }, db.places[BACKPACK])
        assert.are.same({ x * 0.5, y * 0.5 }, { onScreen(bag) })
      end)

      it("glides back to its default size from a grip, the corner across from it still", function()
        db.bagScale = 50
        db.sizes[BACKPACK] = { 600, 500 }
        local bag = opened(function(c) return nextBag:Create(c) end)
        local x, y = onScreen(bag)
        _G._isShiftKeyDown = true
        local grip = bag.grips.LEFT
        grip:GetScript("OnMouseUp")(grip, "LeftButton")
        _G._isShiftKeyDown = false
        tween:Step(style.Time.Resize / 2)
        local mx = onScreen(bag)
        assert.is_true(mx > x and mx < x + (600 - bodyWidth()) * 0.5, "on its way")
        finishTweens()
        assert.are.same({ bodyWidth(), smallHeight() }, { bag.frame:GetSize() })
        assert.are.same({ x + (600 - bodyWidth()) * 0.5, y }, { onScreen(bag) }, "its top right kept")
      end)

      it("takes a new scale at once while open, placed and kept on the screen", function()
        local bag = opened(function(c) return nextBag:Create(c) end)
        db.bagScale = 150
        scalesChanged()
        assert.are.equal(1.5, bag.frame:GetScale())
        assert.are.same({ UIParent:GetWidth() - bodyWidth() * 1.5 - style.Small.Margin,
          (UIParent:GetHeight() + smallHeight() * 1.5) / 2 }, { onScreen(bag) })
        db.places[BACKPACK] = { 1500, 1100 }
        db.bagScale = 50
        scalesChanged()
        assert.are.same({ 1500, 1100 }, { onScreen(bag) })
        db.bagScale = 150
        scalesChanged()
        assert.are.same({ UIParent:GetWidth() - bodyWidth() * 1.5, 1188 }, { onScreen(bag) }, "kept on the screen")
      end)

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
end)
