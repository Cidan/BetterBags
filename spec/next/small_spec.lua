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
  { "NextSparkles", "next/sparkles.lua" }, { "NextTabs", "next/tabs.lua" }, { "NextContent", "next/content.lua" },
  { "NextDrag", "next/drag.lua" }, { "NextChain", "next/chain.lua" }, { "NextPanel", "next/panel.lua" },
  { "NextBag", "next/bag.lua" }, { "NextBank", "next/bank.lua" } }
for _, m in ipairs(modules) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local nextBag = addon:GetModule("NextBag")
local nextBank = addon:GetModule("NextBank")
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
    db = { size = "small", places = {}, view = { [BACKPACK] = SECTION_GRID, [BANK] = SECTION_GRID },
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
    override(stubs.database, "GetNextChain", function() return "apart" end)
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
end)
