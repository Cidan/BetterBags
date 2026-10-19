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
    db = { size = "small", places = {}, smallChain = "apart", view = { [BACKPACK] = SECTION_GRID, [BANK] = SECTION_GRID },
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
    override(stubs.database, "GetNextSmallChain", function() return db.smallChain end)
    override(stubs.database, "SetNextSmallChain", function(_, layout) db.smallChain = layout end)
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

    local function edgeAlpha(bag)
      local alpha = bag.edges[1]:GetAlpha()
      for _, edge in ipairs(bag.edges) do assert.are.equal(alpha, edge:GetAlpha(), "every edge alike") end
      return alpha
    end

    it("has a button on the backpack with Blizzard's minimize art while full, maximize while small", function()
      db.size = "full"
      local bag = nextBag:Create(ctx())
      assert.are.equal("RedButton-Condense", bag.sizeButton.icon:GetAtlas())
      click(bag)
      assert.are.equal("RedButton-Expand", bag.sizeButton.icon:GetAtlas())
      click(bag)
      assert.are.equal("RedButton-Condense", bag.sizeButton.icon:GetAtlas())
    end)

    it("sits after the button back to the classic bags, saying what it does", function()
      db.size = "full"
      local bag = nextBag:Create(ctx())
      assert.are.same({ "RIGHT", bag.classicButton, "LEFT", -8, 0 }, { bag.sizeButton:GetPoint(1) })
      bag.sizeButton:GetScript("OnEnter")(bag.sizeButton)
      assert.are.equal("Small Bags", GameTooltip:GetText())
      click(bag)
      bag.sizeButton:GetScript("OnEnter")(bag.sizeButton)
      assert.are.equal("Full Size Bags", GameTooltip:GetText())
    end)

    it("uses Classic's own smaller and bigger buttons on Classic", function()
      override(addon, "isRetail", false)
      db.size = "full"
      local bag = nextBag:Create(ctx())
      assert.are.equal("Interface\\Buttons\\UI-Panel-SmallerButton-Up", bag.sizeButton.icon:GetTexture())
      click(bag)
      assert.are.equal("Interface\\Buttons\\UI-Panel-BiggerButton-Up", bag.sizeButton.icon:GetTexture())
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
      for _, edge in ipairs(bag.edges) do assert.are.equal(1, edge:GetAlpha()) end
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
end)
