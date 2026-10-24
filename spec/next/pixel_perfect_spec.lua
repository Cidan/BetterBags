-- pixel_perfect_spec.lua -- BetterBags Next, pixel perfect (docs/next-pixel-perfect.md): at rest, every
-- frame and texture of a Next window on whole screen pixels and every text's anchor on one, at any screen
-- size, UI scale, Bag Scale and theme. Run on the real panels, with the spec layout resolver
-- (spec/helpers/layout.lua) working out where each region is the way the client does.
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
  { "NextDockCard", "next/dockcard.lua" }, { "NextDock", "next/dock.lua" }, { "NextDrag", "next/drag.lua" }, { "NextChain", "next/chain.lua" }, { "NextPanel", "next/panel.lua" },
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
local sonataNext = addon:GetModule("SonataNext")
local pixel = addon:GetModule("NextPixel")
local nextPanel = addon:GetModule("NextPanel")

local SECTION_GRID = 2

local layout = dofile("spec/helpers/layout.lua")

describe("BetterBags Next, pixel perfect", function()
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
    -- What the button draws, so the check sees where the canvas put it.
    b.icon = b.frame:CreateTexture()
    b.icon:SetAllPoints(b.frame)
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
      [BACKPACK] = { sortedItems = {}, tabs = { [1] = { categories = { { name = "Herbs" }, { name = "Ore" }, { name = "Cloth" } },
        items = { item("0_1", "Herbs"), item("0_2", "Herbs"), item("0_3", "Herbs"), item("0_4", "Herbs"), item("0_5", "Herbs"),
          item("0_6", "Herbs"), item("0_7", "Herbs"), item("0_8", "Herbs"), item("0_9", "Herbs"), item("0_10", "Ore"),
          item("0_11", "Ore"), item("0_12", "Cloth") } } } },
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
    override(stubs.database, "SetNextSmallChain", function(_, chained) db.smallChain = chained end)
    override(stubs.database, "GetNextChain", function() return "apart" end)
    -- The Size tab's scales (docs/next-appearance-size.md), in percent.
    db.iconScale, db.bagScale, db.theme = 100, 100, "Default"
    override(stubs.database, "GetNextTheme", function() return db.theme end)
    override(stubs.database, "SetNextTheme", function(_, key) db.theme = key end)
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


  -- The reporter's window (Logs/gx.log: 3396x1362, maximized) at 65% and 70%, the same monitor in
  -- fullscreen (3440x1440), and other common screens and UI scales.
  local SCREENS = {
    { 3396, 1362, 0.65 }, { 3396, 1362, 0.70 }, { 3440, 1440, 0.65 }, { 1920, 1080, 0.64 },
    { 1920, 1080, 1 }, { 2560, 1440, 1 }, { 2560, 1440, 1.15 },
  }

  local function screenName(screen)
    return string.format("%dx%d at %d%%", screen[1], screen[2], math.floor(screen[3] * 100 + 0.5))
  end

  -- What moves by nature (docs/next-pixel-perfect.md) lands on the grid only by chance: the panel names it
  -- (MovingParts), for these checks and the one run in game (PixelAudit).
  local function moving(panel)
    return panel:MovingParts()
  end

  local function settle()
    for _ = 1, 3 do
      finishTweens()
      render:Flush()
      motion:Step(10)
    end
  end

  -- offGrid lists what of a panel is not on whole screen pixels, at rest.
  local function offGrid(panel)
    settle()
    return layout.PixelCheck(panel.frame, { owners = { panel = panel }, skip = moving(panel) })
  end

  local function open(create, kind)
    local panel = create(ctx())
    panel:Show(ctx())
    finishTweens()
    panel:Draw(ctx(), slots[kind])
    return panel
  end

  local function bags()
    return open(function(c) return nextBag:Create(c) end, BACKPACK), open(function(c) return nextBank:Create(c) end, BANK)
  end

  -- useScreen sets a screen up (layout.UseScreen), putting the one before it back first, so the spec's own
  -- screen comes back at the end whatever a test set.
  local undo
  local function useScreen(width, height, uiScale)
    if undo ~= nil then
      undo()
    end
    undo = layout.UseScreen(width, height, uiScale)
  end

  after_each(function()
    if undo ~= nil then
      undo()
      undo = nil
    end
  end)

  for _, screen in ipairs(SCREENS) do
    for _, size in ipairs({ "full", "small" }) do
      it("puts every part of the backpack and the bank on whole pixels, " .. size .. ", on " .. screenName(screen), function()
        db.size = size
        useScreen(screen[1], screen[2], screen[3])
        local bag, bank = bags()
        assert.are.same({}, offGrid(bag), "the backpack")
        assert.are.same({}, offGrid(bank), "the bank")
      end)
    end
  end

  -- Found by the pixel check in game: a small backpack whose Bag Scale was changed from 90% to 95% while it was
  -- open had its ribbon and its lines off the grid (their left edges), each still as long as it was rounded to
  -- the old scale's grid. The slider redraws and refits every open panel (chain:ScalesChanged); everything is
  -- on whole pixels of the new grid, alone and chained.
  for _, chained in ipairs({ "apart", "chained" }) do
    it("puts a small panel back on whole pixels when its Bag Scale changes while it is open, " .. chained, function()
      db.size, db.bagScale, db.smallChain = "small", 90, chained
      useScreen(3396, 1362, 0.65)
      local bag, bank = bags()
      for _, scale in ipairs({ 95, 85, 100, 115 }) do
        db.bagScale = scale
        chain:ScalesChanged(ctx())
        assert.are.same({}, offGrid(bag), "the backpack at " .. scale .. "%")
        assert.are.same({}, offGrid(bank), "the bank at " .. scale .. "%")
      end
    end)
  end

  for _, scale in ipairs({ 50, 85, 115, 150 }) do
    it("puts a small panel on whole pixels at a Bag Scale of " .. scale .. "%", function()
      db.size, db.bagScale = "small", scale
      for _, screen in ipairs({ SCREENS[1], SCREENS[4] }) do
        useScreen(screen[1], screen[2], screen[3])
        local bag, bank = bags()
        assert.are.same({}, offGrid(bag), screenName(screen))
        assert.are.same({}, offGrid(bank), screenName(screen))
        bag:Hide(ctx())
        bank:Hide(ctx())
        finishTweens()
        chain:Init()
      end
    end)
  end

  for _, scale in ipairs({ 85, 115 }) do
    it("puts item buttons on whole pixels at an Icon Scale of " .. scale .. "%", function()
      db.iconScale = scale
      style:SetIconScale(scale)
      useScreen(3396, 1362, 0.65)
      local bag = open(function(c) return nextBag:Create(c) end, BACKPACK)
      local problems = offGrid(bag)
      style:SetIconScale(100)
      assert.are.same({}, problems)
    end)
  end

  it("chains small bags side by side on whole pixels", function()
    db.size, db.smallChain = "small", "backpack"
    useScreen(3396, 1362, 0.65)
    local bag, bank = bags()
    chain:Update(ctx(), true)
    assert.are.same({}, offGrid(bag))
    assert.are.same({}, offGrid(bank))
  end)

  it("chains full bags side by side on whole pixels", function()
    db.size = "full"
    override(stubs.database, "GetNextChain", function() return "right" end)
    useScreen(3396, 1362, 0.65)
    local bag, bank = bags()
    chain:Update(ctx(), true)
    assert.is_not_nil(chain:Pair(), "chained")
    assert.are.same({}, offGrid(bag))
    assert.are.same({}, offGrid(bank))
  end)

  -- startSonataNext starts BetterBags Next's look (SonataNext:Init), its state put back after the test: started,
  -- a spec that registers a theme later would read the saved theme from a Database without one.
  local function startSonataNext()
    for _, key in ipairs({ "widgets", "current", "resolved", "generation", "started", "active", "itemButtonStyle" }) do
      override(sonataNext, key, rawget(sonataNext, key))
    end
    sonataNext:Init()
  end

  -- A new grid (the UI scale, the window's size) applies the theme again (NextPixel), which lays everything
  -- out again for it.
  it("puts open bags back on whole pixels when the grid changes under them", function()
    for _, size in ipairs({ "full", "small" }) do
      db.size = size
      useScreen(1920, 1080, 1)
      startSonataNext()
      local bag, bank = bags()
      useScreen(3396, 1362, 0.65)
      assert.is_true(pixel:OnGridChanged(ctx()))
      assert.are.same({}, offGrid(bag), size)
      assert.are.same({}, offGrid(bank), size)
      bag:Hide(ctx())
      bank:Hide(ctx())
      finishTweens()
      chain:Init()
    end
  end)

  it("puts every part on whole pixels in every shipped theme, at both sizes", function()
    useScreen(3396, 1362, 0.65)
    local keys = {}
    for key in pairs(sonataNext:GetThemes()) do table.insert(keys, key) end
    table.sort(keys)
    assert.is_true(#keys >= 4)
    for _, size in ipairs({ "full", "small" }) do
      db.size = size
      startSonataNext()
      local bag, bank = bags()
      for _, key in ipairs(keys) do
        sonataNext:ApplyTheme(ctx(), key, false)
        assert.are.same({}, offGrid(bag), key .. " " .. size)
        assert.are.same({}, offGrid(bank), key .. " " .. size)
      end
      sonataNext:ApplyTheme(ctx(), "Default", false)
      bag:Hide(ctx())
      bank:Hide(ctx())
      finishTweens()
      chain:Init()
    end
  end)

  -- Everything it can show besides its resting look, each on whole pixels.
  describe("in every state it shows", function()
    for _, size in ipairs({ "full", "small" }) do
      it("puts its group tabs on whole pixels: their names, the selected one, one slid out under the pointer, " .. size, function()
        db.size = size
        override(stubs.database, "GetGroupsEnabled", function() return true end)
        override(stubs.groups, "GetAllGroups", function(_, kind)
          if kind == BACKPACK then
            return { [1] = { name = "Backpack" }, [2] = { name = "Gems and Things" }, [3] = { name = "Odd" } }
          end
          return {}
        end)
        useScreen(3396, 1362, 0.65)
        local bag = open(function(c) return nextBag:Create(c) end, BACKPACK)
        bag:RefreshTabs()
        assert.is_true(#bag.tabs.tabs >= 3)
        assert.are.same({}, offGrid(bag))
        local hovered = bag.tabs:Tab(2).button
        hovered:GetScript("OnEnter")(hovered)
        assert.are.same({}, offGrid(bag), "slid out")
        bag.tabs:Select(3)
        assert.are.same({}, offGrid(bag), "another selected")
      end)

      it("lights the title's glow and the drop glow on whole pixels, " .. size, function()
        db.size = size
        useScreen(3396, 1362, 0.65)
        local bag = open(function(c) return nextBag:Create(c) end, BACKPACK)
        bag.titleButton:GetScript("OnEnter")(bag.titleButton)
        bag:SetDropGlow(true)
        settle()
        assert.is_true(bag.titleGlow:GetAlpha() > 0 and bag.dropGlow:GetAlpha() > 0, "lit")
        assert.are.same({}, offGrid(bag))
      end)

      it("focuses its search box on whole pixels, its clear button showing, " .. size, function()
        db.size = size
        useScreen(3396, 1362, 0.65)
        local bag = open(function(c) return nextBag:Create(c) end, BACKPACK)
        local t = bag.searchBox.textBox
        t:SetText("ore")
        t:GetScript("OnEditFocusGained")(t)
        t:GetScript("OnTextChanged")(t)
        settle()
        assert.is_true(t.clearButton:IsShown())
        assert.are.same({}, offGrid(bag))
      end)

      it("draws Recent Items and Free Space on whole pixels, " .. size, function()
        db.size = size
        useScreen(3396, 1362, 0.65)
        slots[BACKPACK].sortedItems = { { slotkey = "0_20", itemInfo = { category = "Recent Items" } } }
        slots[BACKPACK].tabs[1].freeSpace = { showAll = false, buttons = { { slotkey = "free_0", count = 12 },
          { slotkey = "free_5", count = 3 } } }
        local bag = open(function(c) return nextBag:Create(c) end, BACKPACK)
        assert.is_not_nil(bag.content.byName["Recent Items"])
        assert.is_not_nil(bag.content.byName["Free Space"])
        assert.are.same({}, offGrid(bag))
      end)

      it("shows its empty text on whole pixels, " .. size, function()
        db.size = size
        useScreen(3396, 1362, 0.65)
        slots[BACKPACK].tabs[1].items = {}
        local bag = open(function(c) return nextBag:Create(c) end, BACKPACK)
        assert.is_true(bag.emptyText:IsShown())
        assert.are.same({}, offGrid(bag))
      end)
    end

    for _, size in ipairs({ "full", "small" }) do
      it("keeps its content on whole pixels scrolled partway, " .. size, function()
        db.size = size
        useScreen(3396, 1362, 0.65)
        local bag = open(function(c) return nextBag:Create(c) end, BACKPACK)
        local box = bag.scroll.scrollBox
        box._scrollRange = pixel:Length(bag.frame, 413)
        for _, share in ipairs({ 0.13, 0.37, 0.88 }) do
          box:SetScrollPercentage(share, true)
          assert.are.same({}, offGrid(bag), "at " .. share)
        end
        box._scrollRange = nil
      end)
    end

    -- Blizzard's own button (it must keep its template: its OnClick opens Blizzard's purchase dialog,
    -- camelot-forever.md §10), its art and its text rounded in place.
    for _, screen in ipairs(SCREENS) do
      for _, size in ipairs({ "full", "small" }) do
        it("shows the bank's Purchase Bank button on whole pixels, " .. size .. ", on " .. screenName(screen), function()
          db.size = size
          useScreen(screen[1], screen[2], screen[3])
          stubs.bankBehavior.proto.UpdatePurchaseBankButton = function(helper)
            helper.bag.purchaseBankButton:Show()
          end
          local bank = open(function(c) return nextBank:Create(c) end, BANK)
          bank:UpdatePurchaseBankButton()
          assert.is_true(bank.purchaseBankButton:IsShown())
          -- Its highlight (drawn under the pointer) is judged with the rest.
          assert.are.same({}, offGrid(bank))
        end)
      end
    end

    -- Show Blizzard Bags lists the bag slots as tabs with their bags' icons (ListBags); the bank's Blizzard
    -- tabs come in two blocks a gap apart, the Warbank's in its accent, each block followed by a purchase
    -- tab (ListBankTabs).
    for _, size in ipairs({ "full", "small" }) do
      it("puts tabs with icons, in blocks a gap apart, with a purchase tab, on whole pixels, " .. size, function()
        db.size = size
        useScreen(3396, 1362, 0.65)
        local bank = open(function(c) return nextBank:Create(c) end, BANK)
        bank.tabs:SetTabs({
          { id = 6, name = "Tab One", icon = 133633, block = "bank" },
          { id = 7, name = "Second", icon = 133634, block = "bank" },
          { id = -101, name = "+", secure = 1, fixed = true },
          { id = 12, name = "Warband Things", icon = 133635, accent = "Warbank", block = "warbank", gap = 13.7 },
          { id = -102, name = "+", secure = 2, fixed = true },
        })
        bank.tabs:Select(12)
        assert.are.same({}, offGrid(bank))
      end)
    end

    -- The client moves and sizes a frame with the mouse wherever the pointer goes; let go, a small panel
    -- rests on whole pixels again (a rect set here stands for the client's until the panel anchors itself
    -- again: then the anchors decide, as in the client).
    for _, scale in ipairs({ 100, 85 }) do
      it("rests on whole pixels after a drag and after a grip resize, at a Bag Scale of " .. scale .. "%", function()
        db.size, db.bagScale = "small", scale
        useScreen(3396, 1362, 0.65)
        local bag = open(function(c) return nextBag:Create(c) end, BACKPACK)
        local f = bag.frame
        bag.mover:GetScript("OnDragStart")(bag.mover, "LeftButton")
        f:_SetRect(733.37, 211.61, f:GetWidth(), f:GetHeight())
        bag.mover:GetScript("OnDragStop")(bag.mover)
        f._rect = nil
        assert.are.same({}, offGrid(bag), "dropped")
        local grip = bag.grips.RIGHT
        grip:GetScript("OnMouseDown")(grip, "LeftButton")
        f:_SetRect(733.37, 101.23, 517.81, 611.43)
        f:GetScript("OnSizeChanged")(f, 517.81, 611.43)
        grip:GetScript("OnMouseUp")(grip, "LeftButton")
        f._rect = nil
        assert.are.same({}, offGrid(bag), "resized")
      end)
    end

    it("rests on whole pixels once it has switched between sizes", function()
      db.size = "full"
      useScreen(3396, 1362, 0.65)
      local bag = open(function(c) return nextBag:Create(c) end, BACKPACK)
      nextPanel:SetSize(ctx(), "small")
      assert.are.same({}, offGrid(bag), "small")
      nextPanel:SetSize(ctx(), "full")
      assert.are.same({}, offGrid(bag), "full again")
    end)

    -- The check run in game from /bbdb (debug/pixelaudit.lua, next-pixel-perfect.md): every panel registers
    -- as it is made, its parts named from the panel, its moving parts left out, its size and scales said.
    it("registers each panel with the pixel check run in game", function()
      local audit = addon:GetModule("PixelAudit")
      db.size, db.bagScale, db.iconScale = "small", 85, 110
      local bag, bank = bags()
      local w = audit:WindowOf(bag.frame)
      assert.are.equal("Backpack", w.title)
      assert.are.equal(bag, w.owners.panel)
      assert.are.same(bag:MovingParts(), w.skip())
      assert.is_true(next(w.skip()) ~= nil)
      assert.are.equal("small, Bag Scale 85%, Icon Scale 110%", w.describe())
      assert.are.equal("Bank", audit:WindowOf(bank.frame).title)
    end)

    -- For a report (PixelAudit): every section of the column with its state, where it hangs in units and pixels,
    -- and whether Motion still moves it; the canvas and the scroll offset.
    it("describes its column for a report", function()
      useScreen(3396, 1362, 0.65)
      local audit = addon:GetModule("PixelAudit")
      local bag = open(function(c) return nextBag:Create(c) end, BACKPACK)
      local lines = audit:WindowOf(bag.frame).layout()
      assert.is_truthy(lines[1]:find("^canvas "), lines[1])
      assert.is_truthy(lines[1]:find("scroll ", 1, true), lines[1])
      assert.are.equal("drag: column none | dragging none | lift holds nothing | left button up", lines[2])
      local names = {}
      for i = 3, #lines do
        names[#names + 1] = lines[i]:match("^%d+ ([^:]+):")
        assert.is_truthy(lines[i]:find("shown=true", 1, true), lines[i])
        assert.is_truthy(lines[i]:find("hangs from canvas", 1, true), lines[i])
        assert.is_truthy(lines[i]:find(" y ", 1, true), lines[i])
        assert.is_truthy(lines[i]:find("still", 1, true), lines[i])
      end
      assert.are.same({ "Herbs", "Ore", "Cloth" }, names)
      -- A drag in progress: which section the column keeps a room for, where, the drag, what the lift holds.
      local ore = bag.content.byName["Ore"]
      local sc = ore.frame:GetEffectiveScale()
      _G._cursorX, _G._cursorY = (ore.frame:GetLeft() + 20) * sc, (ore.frame:GetTop() - 10) * sc
      _G._mouseButtonsDown = { LeftButton = true }
      ore.header:GetScript("OnDragStart")(ore.header)
      finally(function()
        _G._mouseButtonsDown = nil
        nextDrag:Cancel()
      end)
      lines = audit:WindowOf(bag.frame).layout()
      assert.is_truthy(lines[2]:find("^drag: column Ore index 2 room "), lines[2])
      assert.is_truthy(lines[2]:find("| dragging Ore | lift holds Ore | left button down$"), lines[2])
      assert.is_falsy(lines[4]:find("hangs from canvas", 1, true), lines[4])
    end)

    it("says it changed as it renders, only while the check watches", function()
      local audit = addon:GetModule("PixelAudit")
      local bag = open(function(c) return nextBag:Create(c) end, BACKPACK)
      local changed = {}
      override(audit, "Changed", function(_, root) table.insert(changed, root) end)
      render:Invalidate(bag.root)
      render:Flush()
      assert.are.same({}, changed, "off")
      override(audit, "watching", true)
      render:Invalidate(bag.root)
      render:Flush()
      assert.are.same({ bag.frame }, changed)
    end)

    -- Reported: scaling the bags up or down moved items between rows ("every item should technically render
    -- in exactly the same place, no exception"): 13 Consumables in rows of 7 at a Bag Scale of 100%, of 8 at
    -- 105%. Items per row were decided on lengths rounded to the panel's pixel grid, which changes with its
    -- scale; a probe over widths 380 to 520 found 16 to 28 of 71 widths laid out differently across Bag Scales
    -- 50% to 150% on these screens. Widths near where a row takes one more item, on the reporter's screen at
    -- 65% and 70% and a common one: every item in the same row and column at every Bag Scale.
    -- What a panel's rows are decided on (NextContent:LayoutSection): its body's width in its own units, as the
    -- player left it, never rounded to its grid; while a grip sizes it, the frame's.
    it("hands its content the width to lay out for in its own units, not rounded to its grid", function()
      useScreen(3396, 1362, 0.65)
      db.size, db.bagScale = "small", 85
      db.sizes[BACKPACK] = { 406.3, 600 }
      local bag = open(function(c) return nextBag:Create(c) end, BACKPACK)
      assert.is_true(math.abs(bag.root:PreRender().LayoutWidth - (406.3 - 2 * style.PAD)) < 1e-9)
      assert.is_true(math.abs(bag:SmallWidth() - 406.3) > 1e-6, "the frame is rounded to its grid")
      bag.sizing = "RIGHT"
      bag.frame:SetWidth(431.7)
      assert.is_true(math.abs(bag.root:PreRender().LayoutWidth - (431.7 - 2 * style.PAD)) < 1e-9, "while sized")
      bag.sizing = nil
      nextPanel:SetSize(ctx(), "full")
      finishTweens()
      assert.is_false(bag:IsSmall())
      assert.is_true(math.abs(bag.root:PreRender().LayoutWidth - (style.BODY_WIDTH - 2 * style.PAD)) < 1e-9)
    end)

    it("puts every item in the same row and column at every Bag Scale", function()
      local list = {}
      for i = 1, 13 do table.insert(list, item("0_" .. i, "Consumable")) end
      slots[BACKPACK] = { sortedItems = {}, tabs = { [1] = { categories = { { name = "Consumable" } }, items = list } } }
      -- placesOf is each item's column and row: where its button is in the section's cells over the step
      -- between buttons (the panel's grid's, which differs with its scale).
      local function placesOf(bag)
        local section = bag.content.byName["Consumable"]
        local step = math.huge
        for _, e in ipairs(section.entries) do
          local _, _, _, x = e.item.frame:GetPoint(1)
          if x > 0.5 then step = math.min(step, x) end
        end
        local out = {}
        for _, e in ipairs(section.entries) do
          local _, _, _, x, y = e.item.frame:GetPoint(1)
          out[e.item.slotkey] = math.floor(x / step + 0.5) .. "," .. math.floor(-y / step + 0.5)
        end
        return out
      end
      for _, screen in ipairs({ { 3396, 1362, 0.65 }, { 3396, 1362, 0.70 }, { 1920, 1080, 0.64 } }) do
        useScreen(screen[1], screen[2], screen[3])
        db.size, db.bagScale = "small", 100
        local bag = open(function(c) return nextBag:Create(c) end, BACKPACK)
        for _, w in ipairs({ 402, 404, 406, 408, 410 }) do
          local expected
          for scale = 50, 150, 5 do
            db.sizes[BACKPACK] = { w, 600 }
            db.bagScale = scale
            chain:ScalesChanged(ctx())
            bag:FitSmall()
            settle()
            local places = placesOf(bag)
            expected = expected or places
            assert.are.same(expected, places, string.format("%s, width %d, Bag Scale %d%%", screenName(screen), w, scale))
          end
        end
      end
    end)

    -- Found by the pixel check in game: after a section was dragged up one place in a small backpack at Bag Scale
    -- 55% (3396x1362 at 65%), six of eight sections and their items stood 0.062 pixel off the grid, the dragged
    -- section taking no room and a room open before the second: the column of a drag in progress. The column keeps
    -- a room for the section while it is held and while it lands (NextContent:BeginDrag, nextDrag:land), and the
    -- room is the section's height; the held section is drawn shrunk (Drag.LiftScale), on another grid. The column
    -- stays on whole pixels throughout: held over its new place, landing, and settled.
    for _, case in ipairs({ { name = "up one place", from = "S3", over = "S2", before = true },
      { name = "down", from = "S3", over = "S6", before = false } }) do
      it("keeps the column on whole pixels while a section is dragged " .. case.name .. ", as it lands, and after", function()
        db.size, db.bagScale = "small", 55
        useScreen(3396, 1362, 0.65)
        local cats, list = {}, {}
        for i = 1, 8 do
          table.insert(cats, { name = "S" .. i })
          for j = 1, 2 + i do table.insert(list, item(i .. "_" .. j, "S" .. i)) end
        end
        slots[BACKPACK] = { sortedItems = {}, tabs = { [1] = { categories = cats, items = list } } }
        -- The order a drop saves (nextDrag:SaveOrder).
        local pins = {}
        override(stubs.database, "GetCustomSectionSort", function() return pins end)
        override(stubs.database, "SetCustomSectionSort", function(_, _, name, i) pins[name] = i end)
        local bag = open(function(c) return nextBag:Create(c) end, BACKPACK)
        assert.are.same({}, offGrid(bag), "before")
        -- column checks the panel with every move of its column at rest, the held section's tweens left running.
        local function column()
          render:Flush()
          motion:Step(10)
          return layout.PixelCheck(bag.frame, { owners = { panel = bag }, skip = moving(bag) })
        end
        local dragged, over = bag.content.byName[case.from], bag.content.byName[case.over]
        -- The cursor is in absolute units (GetCursorPosition); a section's edges in its own.
        local sc = dragged.frame:GetEffectiveScale()
        local x, top = dragged.frame:GetLeft() + 20, dragged.frame:GetTop() - 10
        local to = case.before and (over.frame:GetTop() - 2) or (over.frame:GetBottom() - 5)
        _G._cursorX, _G._cursorY = x * sc, top * sc
        _G._mouseButtonsDown = { LeftButton = true }
        dragged.header:GetScript("OnDragStart")(dragged.header)
        -- frame runs one frame of the game: tweens (the lift's shrink), the drag, renders, the column's moves.
        local function frame(elapsed)
          local update = tween.driver:GetScript("OnUpdate")
          if update ~= nil then update(tween.driver, elapsed) end
          nextDrag:Update(elapsed)
          render:Flush()
          motion:Step(elapsed)
        end
        for step = 1, 30 do
          _G._cursorY = (top + (to - top) * math.min(1, step / 12)) * sc
          frame(0.016)
        end
        assert.is_true(math.abs(dragged.frame:GetEffectiveScale() - bag.content.frame:GetEffectiveScale()) > 1e-3,
          "drawn shrunk while held")
        assert.is_not_nil(bag.content.drag, "held")
        assert.are.same({}, column(), "held over its new place")
        _G._mouseButtonsDown = nil
        dragged.header:GetScript("OnDragStop")(dragged.header)
        assert.is_not_nil(bag.content.drag, "landing")
        assert.are.same({}, column(), "as it lands")
        settle()
        assert.is_nil(bag.content.drag, "landed")
        local order = {}
        for _, section in ipairs(bag.content.order) do table.insert(order, section.name) end
        assert.are_not.same({ "S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8" }, order, "moved")
        assert.are.same({}, offGrid(bag), "after")
      end)
    end

    it("shows a small panel's grips on whole pixels under the pointer", function()
      db.size = "small"
      for _, scale in ipairs({ 100, 85 }) do
        db.bagScale = scale
        useScreen(3396, 1362, 0.65)
        local bag = open(function(c) return nextBag:Create(c) end, BACKPACK)
        for _, grip in pairs(bag.grips) do
          grip:GetScript("OnEnter")(grip)
        end
        settle()
        assert.are.same({}, offGrid(bag), scale .. "%")
        bag:Hide(ctx())
        finishTweens()
        chain:Init()
      end
    end)
  end)
end)
