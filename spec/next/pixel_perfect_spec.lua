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

  -- What moves by nature (docs/next-pixel-perfect.md) lands on the grid only by chance: sparkles and the
  -- spark fly, the cloud's puffs breathe every frame, the braid's lights run along it.
  local function moving(panel)
    local skip = {}
    for _, key in ipairs({ "sparkles", "edgeSparkles", "cloudSparkles", "knotSparkles" }) do
      if panel[key] ~= nil then skip[panel[key].frame] = true end
    end
    for _, puff in ipairs(panel.cloud.puffs) do skip[puff.texture] = true end
    skip[panel.spark] = true
    skip[panel.braid.layer] = true
    return skip
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

  -- A new grid (the UI scale, the window's size) applies the theme again (NextPixel), which lays everything
  -- out again for it.
  it("puts open bags back on whole pixels when the grid changes under them", function()
    for _, size in ipairs({ "full", "small" }) do
      db.size = size
      useScreen(1920, 1080, 1)
      sonataNext:Init()
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
      sonataNext:Init()
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
end)
