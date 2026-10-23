-- theme_panel_spec.lua -- BetterBags Next's panels drawn from a Next theme (next-themes.md): the
-- body, feathers, wash, edge, title, cloud, ribbon, spark, header buttons, search box, footer,
-- sparkles, braid, sizes and animations, all restyled live when SonataNext applies a theme. Run on
-- the real backpack and bank panels.
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
  { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" },
  { "NextSparkles", "next/sparkles.lua" }, { "NextTabs", "next/tabs.lua" }, { "NextContent", "next/content.lua" },
  { "NextLift", "next/lift.lua" }, { "NextDockCard", "next/dockcard.lua" }, { "NextDrag", "next/drag.lua" }, { "NextChain", "next/chain.lua" }, { "NextPanel", "next/panel.lua" },
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

local SECTION_GRID = 2

describe("BetterBags Next's panels and themes", function()
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

  before_each(function()
    render:Init()
    tween:Init()
    motion:Init()
    nextDrag:Init()
    chain:Init()
    sent, buttons, placed = {}, {}, {}
    db = { size = "full", theme = "Default", places = {}, smallChain = "apart", view = { [BACKPACK] = SECTION_GRID, [BANK] = SECTION_GRID },
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
    override(stubs.database, "GetNextTheme", function() return db.theme end)
    override(stubs.database, "SetNextTheme", function(_, key) db.theme = key end)
    override(stubs.database, "GetNextSize", function() return db.size end)
    override(stubs.database, "SetNextSize", function(_, size) db.size = size end)
    override(stubs.database, "GetNextSmallPlace", function(_, kind)
      local p = db.places[kind]
      if p then return p[1], p[2] end
    end)
    override(stubs.database, "SetNextSmallPlace", function(_, kind, x, y) db.places[kind] = { x, y } end)
    override(stubs.database, "GetNextSmallSize", function() return nil end)
    override(stubs.database, "SetNextSmallSize", function() end)
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
    sonataNext:Init()
  end)

  after_each(function()
    UseNextTheme(nil)
    restore()
    _G._cursorHasItem = false
    _G._cursorType = nil
  end)

  teardown(function()
    for i = #modules, 1, -1 do ResetModuleStub(modules[i][1]) end
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
    FreshNextThemes()
  end)


  -- apply registers t as the theme "Spec" and applies it, as the theme pane's preview does.
  local function apply(t)
    sonataNext.themes.Spec = nil
    t.Name = "Spec"
    sonataNext:RegisterTheme(t)
    sonataNext:ApplyTheme(ctx(), "Spec", false)
  end

  local function backToDefault()
    sonataNext:ApplyTheme(ctx(), "Default", false)
  end

  local function opened(create)
    local panel = create(ctx())
    panel:Show(ctx())
    finishTweens()
    return panel
  end

  local function rgba(c) return { c.r, c.g, c.b, c.a } end

  describe("the body", function()
    it("restyles every panel when a theme is applied", function()
      local bag, bank = nextBag:Create(ctx()), nextBank:Create(ctx())
      apply({ Palette = { Body = { 0.2, 0.1, 0.05, 0.9 } } })
      assert.are.same({ 0.2, 0.1, 0.05, 0.9 }, rgba(bag.fill._colorTexture))
      assert.are.same({ 0.2, 0.1, 0.05, 0.9 }, rgba(bank.fill._colorTexture))
    end)

    it("fills the body with art when the theme names some, tiled and tinted, and back", function()
      local bag = nextBag:Create(ctx())
      apply({ Textures = { Marble = "Interface\\FrameGeneral\\UI-Background-Marble" },
        Palette = { Stone = { 0.8, 0.8, 0.9, 1 } },
        Panel = { Fill = { Texture = "Marble", Color = "Stone", HorizTile = true, VertTile = true } } })
      assert.are.equal("Interface\\FrameGeneral\\UI-Background-Marble", bag.fill:GetTexture())
      assert.are.equal("REPEAT", bag.fill._wrapH)
      assert.is_true(bag.fill:GetHorizTile())
      assert.are.same({ 0.8, 0.8, 0.9, 1 }, { bag.fill:GetVertexColor() })
      backToDefault()
      assert.is_nil(bag.fill:GetTexture())
      assert.are.same(style.Color.Body, rgba(bag.fill._colorTexture))
      assert.is_false(bag.fill:GetHorizTile())
      assert.are.same({ 1, 1, 1, 1 }, { bag.fill:GetVertexColor() })
    end)

    it("feathers its inner edge in its color, or not at all", function()
      local bag = nextBag:Create(ctx())
      apply({ Palette = { Ink = { 0.1, 0.2, 0.3, 0.5 } }, Panel = { Feather = { Color = "Ink" } } })
      local g = bag.feather._gradient
      assert.are.same({ 0.1, 0.2, 0.3, 0.5 }, { g.max.r, g.max.g, g.max.b, g.max.a })
      assert.are.equal(0, g.min.a)
      apply({ Panel = { Feather = false } })
      assert.are.equal(0, bag.feather._gradient.max.a)
      assert.are.equal(0, bag.outerFeather._gradient.min.a)
    end)

    it("washes its top in the color for what it shows, at its height and blend, or not at all", function()
      local bank = nextBank:Create(ctx())
      bank:SetWash("Warbank", true)
      apply({ Palette = { Sea = { 0, 0.5, 0.6, 0.3 } }, Panel = { Wash = { Height = 100, BlendMode = "BLEND" },
        Washes = { Warbank = "Sea" } } })
      assert.are.same({ 0, 0.5, 0.6, 0.3 }, bank.washColor)
      assert.are.equal(0.3, bank.wash._gradient.max.a)
      assert.are.equal(100, bank.wash:GetHeight())
      assert.are.equal("BLEND", bank.wash:GetBlendMode())
      assert.is_true(bank.wash:IsShown())
      apply({ Panel = { Wash = false } })
      assert.is_false(bank.wash:IsShown())
      backToDefault()
      assert.is_true(bank.wash:IsShown())
      assert.are.same(style.Color.WarbankWash, bank.washColor)
    end)

    it("draws its border in its color, alpha and size, on full panels too when it says, or never", function()
      db.size = "small"
      local bag = nextBag:Create(ctx())
      apply({ Panel = { Edge = { Color = "Gold", Alpha = 0.8, Size = 2 } } })
      local top, left = bag.edges[1], bag.edges[3]
      assert.are.same({ 1, 0.84, 0.5, 0.8 }, { top:GetVertexColor() })
      assert.are.equal(2, top:GetHeight())
      assert.are.equal(2, left:GetWidth())
      assert.is_true(top:IsShown())
      apply({ Panel = { Edge = false } })
      assert.is_false(top:IsShown())
      db.size = "full"
      local full = nextBag:Create(ctx())
      assert.is_false(full.edges[1]:IsShown())
      apply({ Panel = { Edge = { Full = true } } })
      assert.is_true(full.edges[1]:IsShown())
    end)

    it("keeps a border it draws at both sizes through a switch", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      apply({ Panel = { Edge = { Full = true } } })
      bag.sizeButton:GetScript("OnClick")(bag.sizeButton, "LeftButton")
      tween.driver:GetScript("OnUpdate")(tween.driver, style.Time.Morph / 2)
      assert.are.equal(0.35, bag.edges[1]:GetAlpha(), "never fades")
      finishTweens()
      assert.is_true(bag.edges[1]:IsShown())
      assert.are.equal(0.35, bag.edges[1]:GetAlpha())
    end)

    it("lights a drop target in its glow, or not at all", function()
      local bag = nextBag:Create(ctx())
      apply({ Panel = { DropGlow = { Color = "Gold", Alpha = 0.4, BlendMode = "BLEND" } } })
      bag:SetDropGlow(true)
      finishTweens()
      assert.are.equal(0.4, bag.dropGlow:GetAlpha())
      local r, g, b = bag.dropGlow:GetVertexColor()
      assert.are.same({ 1, 0.84, 0.5 }, { r, g, b })
      assert.are.equal("BLEND", bag.dropGlow:GetBlendMode())
      bag:SetDropGlow(false)
      finishTweens()
      apply({ Panel = { DropGlow = false } })
      bag:SetDropGlow(true)
      finishTweens()
      assert.is_false(bag.dropGlow:IsShown())
    end)
  end)

  -- A texture's alpha is its vertex color's (next-themes.md §10, FloatingChatFrame.lua): coloring a
  -- texture must never undo the alpha it shows, and a fade must never undo its theme's alpha.
  describe("alphas", function()
    it("keeps the title's glow dark through a theme applied, and lit while hovered", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      assert.are.equal(0, bag.titleGlow:GetAlpha())
      apply({ Header = { TitleGlow = { Color = "White" } } })
      assert.are.equal(0, bag.titleGlow:GetAlpha(), "still dark")
      bag.titleButton:GetScript("OnEnter")(bag.titleButton)
      finishTweens()
      apply({ Header = { TitleGlow = { Color = "Gold" } } })
      assert.are.equal(0.3, bag.titleGlow:GetAlpha(), "still lit")
      local r, g, b = bag.titleGlow:GetVertexColor()
      assert.are.same({ 1, 0.84, 0.5 }, { r, g, b })
    end)

    it("draws a small panel's border at its theme's alpha after a size switch, fading by it on the way", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      bag.sizeButton:GetScript("OnClick")(bag.sizeButton, "LeftButton")
      tween.driver:GetScript("OnUpdate")(tween.driver, style.Time.Morph + 0.001)
      tween.driver:GetScript("OnUpdate")(tween.driver, style.Time.MorphFade / 2)
      local fading = select(4, bag.edges[1]:GetVertexColor())
      assert.is_true(fading > 0 and fading < 0.35, "part of 0.35 on the way: " .. fading)
      finishTweens()
      for _, edge in ipairs(bag.edges) do
        assert.are.equal(0.35, edge:GetAlpha())
      end
      bag.sizeButton:GetScript("OnClick")(bag.sizeButton, "LeftButton")
      finishTweens()
      bag.sizeButton:GetScript("OnClick")(bag.sizeButton, "LeftButton")
      finishTweens()
      assert.are.equal(0.35, bag.edges[1]:GetAlpha(), "the same after any number of switches")
    end)

    it("keeps the spark dark through a theme applied while the shimmer waits", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      -- A shimmer starting over: it waits before the spark glides in, the spark dark meanwhile.
      tween:Stop(bag.spark)
      apply({ Header = { Spark = { Color = "Lavender" } } })
      assert.is_true(tween:IsPlaying(bag.spark))
      assert.are.equal(0, bag.spark:GetAlpha())
      apply({ Header = { Spark = { Color = "White" } } })
      assert.are.equal(0, bag.spark:GetAlpha())
    end)

    it("keeps a hidden drop glow dark through a theme applied, and fades it in from nothing", function()
      local bag = nextBag:Create(ctx())
      apply({ Panel = { DropGlow = { Color = "White" } } })
      assert.are.equal(0, bag.dropGlow:GetAlpha())
      bag:SetDropGlow(true)
      tween.driver:GetScript("OnUpdate")(tween.driver, 0.01)
      assert.is_true(bag.dropGlow:GetAlpha() < 0.12)
    end)

    it("lets the cloud settle when a theme turns the spark off mid-shimmer", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      bag.cloud.swell = 0.8
      apply({ Header = { Spark = false } })
      assert.are.equal(0, bag.cloud.swell)
    end)
  end)

  describe("the header", function()
    it("writes the title in its role, where its layout puts it", function()
      local bag, bank = nextBag:Create(ctx()), nextBank:Create(ctx())
      apply({ Fonts = { Big = { Size = 30, Color = "Gold" } }, Header = { Title = { Font = "Big" } },
        Layout = { TitleInset = 10, TitleTop = 30 } })
      assert.are.equal(style:Font("Big"), bag.title:GetFontObject())
      assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", style.PAD + 10, -30 }, { bag.title:GetPoint(1) })
      assert.are.same({ "TOPRIGHT", bank.body, "TOPRIGHT", -(style.PAD + 10), -30 }, { bank.title:GetPoint(1) })
    end)

    it("lights the title's glow on hover, by its alpha and spread, or not at all", function()
      local bag = nextBag:Create(ctx())
      apply({ Header = { TitleGlow = { Texture = "Glow", Color = "White", Alpha = 0.5, X = 10, Y = 5 } } })
      local glow = bag.titleGlow
      assert.are.same({ "TOPLEFT", bag.title, "TOPLEFT", -10, 5 }, { glow:GetPoint(1) })
      local r, g, b = glow:GetVertexColor()
      assert.are.same({ 1, 1, 1 }, { r, g, b })
      bag.titleButton:GetScript("OnEnter")(bag.titleButton)
      finishTweens()
      assert.are.equal(0.5, glow:GetAlpha())
      bag.titleButton:GetScript("OnLeave")(bag.titleButton)
      finishTweens()
      apply({ Header = { TitleGlow = false } })
      bag.titleButton:GetScript("OnEnter")(bag.titleButton)
      finishTweens()
      assert.are.equal(0, glow:GetAlpha())
      assert.is_false(glow:IsShown())
    end)

    it("draws its cloud's puffs, as many as it lists, or no cloud", function()
      local bag = nextBag:Create(ctx())
      local built = #bag.cloud.puffs
      apply({ Header = { Cloud = { Puffs = {
        { F = 0.2, Y = 0, W = 40, H = 30, Color = "White", A = 0.3 },
        { F = 0.6, Y = 4, W = 20, H = 20, Color = "Gold", A = 0.2 },
      } } } })
      assert.are.equal(2, #bag.cloud.puffs)
      local r, g, b = bag.cloud.puffs[1].texture:GetVertexColor()
      assert.are.same({ 1, 1, 1 }, { r, g, b })
      assert.are.equal(40, bag.cloud.puffs[1].texture:GetWidth())
      local hidden = 0
      for _, t in ipairs(bag.cloud.pool) do
        if not t:IsShown() then hidden = hidden + 1 end
      end
      assert.are.equal(built - 2, hidden, "the puffs it no longer lists are hidden")
      apply({ Header = { Cloud = false } })
      for _, t in ipairs(bag.cloud.pool) do assert.is_false(t:IsShown()) end
      assert.is_false(bag.cloud.join:IsShown())
      bag.cloud.driver:GetScript("OnUpdate")(bag.cloud.driver, 0.1)
      backToDefault()
      assert.are.equal(built, #bag.cloud.puffs)
      assert.is_true(bag.cloud.join:IsShown())
    end)

    it("draws its ribbon's lines, as many as it lists, at its length and thickness, or none", function()
      local bag = nextBag:Create(ctx())
      apply({ Header = { Ribbon = { Length = 200, Thickness = 4, Color = "Lavender", Glow = { { 0, 1 }, { 3, 0.2 } } } } })
      assert.are.equal(2, #bag.ribbonLines)
      local line = bag.ribbonLines[2]
      assert.are.equal(200, line:GetWidth())
      assert.are.equal(4, line:GetHeight())
      local g = line._gradient
      assert.are.same({ 0.78, 0.72, 1.0, 0.2 }, { g.max.r, g.max.g, g.max.b, g.max.a })
      assert.are.equal(bag.ribbonLines[1], bag.ribbon)
      local shown = 0
      for _, l in ipairs(bag.ribbonPool) do if l:IsShown() then shown = shown + 1 end end
      assert.are.equal(2, shown)
      apply({ Header = { Ribbon = false } })
      for _, l in ipairs(bag.ribbonPool) do assert.is_false(l:IsShown()) end
    end)

    it("glides its spark in at its size and color, or never", function()
      local bag = nextBag:Create(ctx())
      apply({ Header = { Spark = { Texture = "Sparkle", Size = 40, Growth = 0, Color = "White", BlendMode = "ADD" } } })
      assert.are.equal(40, bag.spark:GetWidth())
      local r, g, b = bag.spark:GetVertexColor()
      assert.are.same({ 1, 1, 1 }, { r, g, b })
      apply({ Header = { Spark = false } })
      bag:Show(ctx())
      assert.is_false(tween:IsPlaying(bag.spark))
      assert.is_false(bag.spark:IsShown())
    end)

    it("sizes, spaces and tints its buttons, with its own icons by key, and back", function()
      local bag = nextBag:Create(ctx())
      apply({ Layout = { HeaderButton = 30, HeaderButtonGap = 4, HeaderButtonTop = 20 },
        Header = { Buttons = { Color = "Gold", HoverColor = "Lavender",
          Icons = { sortButton = { Atlas = "my-sort" }, sizeButtonFull = { Texture = "Interface\\Small" } } } } })
      local first, second = bag.headerButtons[1], bag.headerButtons[2]
      assert.are.equal(30, first:GetWidth())
      assert.are.same({ "TOPRIGHT", bag.body, "TOPRIGHT", -style.PAD, -20 }, { first:GetPoint(1) })
      assert.are.same({ "RIGHT", first, "LEFT", -4, 0 }, { second:GetPoint(1) })
      assert.are.same({ 1, 0.84, 0.5, 1 }, { first.icon:GetVertexColor() })
      first:GetScript("OnEnter")(first)
      assert.are.same({ 0.78, 0.72, 1.0, 1 }, { first.icon:GetVertexColor() })
      first:GetScript("OnLeave")(first)
      assert.are.same({ 1, 0.84, 0.5, 1 }, { first.icon:GetVertexColor() })
      assert.are.equal("my-sort", bag.sortButton.icon:GetAtlas())
      assert.are.equal("Interface\\Small", bag.sizeButton.icon:GetTexture())
      backToDefault()
      assert.are.equal("sort", NextIconName(bag.sortButton))
      assert.is_nil(bag.sortButton.icon:GetAtlas())
      assert.are.equal("small", NextIconName(bag.sizeButton))
      assert.are.same({ 0.85, 0.82, 1, 1 }, { first.icon:GetVertexColor() })
    end)
  end)

  -- Every header button is a glyph in the gear's style (asked: "make icons for each button we use ...
  -- in the same style"; "these buttons should be colorable via themes, and even replacable with custom
  -- art"). A tint suits a white glyph and darkens full-color art into a silhouette (asked with a
  -- Parchment screenshot), so a theme's own art says which it is (Glyph = false: art).
  describe("header icons", function()
    local function color(button)
      local r, g, b = button.icon:GetVertexColor()
      return { r, g, b }
    end

    local function every(panel, fn)
      for _, button in ipairs(panel.headerButtons) do fn(button) end
    end

    it("draws every button in Default's icon color", function()
      local bag, bank = nextBag:Create(ctx()), nextBank:Create(ctx())
      for _, panel in ipairs({ bag, bank }) do
        every(panel, function(button)
          assert.are.same({ 0.85, 0.82, 1, 1 }, { button.icon:GetVertexColor() }, button.key)
          assert.is_false(button.icon:IsDesaturated(), button.key)
        end)
      end
    end)

    it("draws every glyph in the theme's colors, hovered and not", function()
      local bag, bank = nextBag:Create(ctx()), nextBank:Create(ctx())
      apply({ Palette = { Ink = { 0.2, 0.1, 0.05, 1 }, Wax = { 0.6, 0.1, 0.1, 1 } },
        Header = { Buttons = { Color = "Ink", HoverColor = "Wax" } } })
      for _, panel in ipairs({ bag, bank }) do
        every(panel, function(button) assert.are.same({ 0.2, 0.1, 0.05 }, color(button), button.key) end)
      end
      bag.sortButton:GetScript("OnEnter")(bag.sortButton)
      assert.are.same({ 0.6, 0.1, 0.1 }, color(bag.sortButton))
      bag.sortButton:GetScript("OnLeave")(bag.sortButton)
      assert.are.same({ 0.2, 0.1, 0.05 }, color(bag.sortButton))
    end)

    it("draws a theme's own art in its art colors, and its own glyph in the glyph colors", function()
      local bag = nextBag:Create(ctx())
      apply({ Palette = { Ink = { 0.2, 0.1, 0.05, 1 }, Plain = { 0.9, 0.9, 0.9, 1 } },
        Header = { Buttons = { Color = "Ink", ArtColor = "Plain", ArtHoverColor = "Gold",
          Icons = { sortButton = { Atlas = "my-art", Glyph = false },
            settingsButton = { Texture = "Interface\\MyGear" },
            classicButton = { Texture = "Interface\\Sheet", TexCoords = { 0.5, 1, 0, 0.5 }, Glyph = false } } } } })
      assert.are.equal("my-art", bag.sortButton.icon:GetAtlas())
      assert.are.same({ 0.9, 0.9, 0.9 }, color(bag.sortButton))
      bag.sortButton:GetScript("OnEnter")(bag.sortButton)
      assert.are.same({ 1, 0.84, 0.5 }, color(bag.sortButton), "art brightens in its own hover color")
      bag.sortButton:GetScript("OnLeave")(bag.sortButton)
      assert.are.equal("Interface\\MyGear", bag.settingsButton.icon:GetTexture())
      assert.are.same({ 0.2, 0.1, 0.05 }, color(bag.settingsButton), "a glyph unless it says otherwise")
      assert.are.equal("Interface\\Sheet", bag.classicButton.icon:GetTexture())
      assert.are.same({ 0.5, 1, 0, 0.5 }, bag.classicButton.icon._texCoords)
      assert.are.same({ 0.9, 0.9, 0.9 }, color(bag.classicButton))
      backToDefault()
      assert.are.equal("sort", NextIconName(bag.sortButton))
      assert.are.same({ 0, 1, 0, 1 }, bag.classicButton.icon._texCoords)
    end)

    it("colors one button its own way", function()
      local bank = nextBank:Create(ctx())
      apply({ Palette = { Wax = { 0.6, 0.1, 0.1, 1 } },
        Header = { Buttons = { Icons = { closeButton = { Color = "Wax", HoverColor = "Gold" } } } } })
      assert.are.same({ 0.6, 0.1, 0.1 }, color(bank.closeButton))
      bank.closeButton:GetScript("OnEnter")(bank.closeButton)
      assert.are.same({ 1, 0.84, 0.5 }, color(bank.closeButton))
      bank.closeButton:GetScript("OnLeave")(bank.closeButton)
      assert.are.same({ 0.85, 0.82, 1 }, color(bank.settingsButton), "the others in the theme's")
      assert.are.equal("close", NextIconName(bank.closeButton), "its art kept")
    end)

    -- A white glyph looks the same desaturated, so a disabled button fades (DisabledAlpha) instead,
    -- art desaturated too; under the pointer it stays disabled.
    it("fades a disabled button, glyph or art, hovered or not, and brings it back", function()
      local bank = nextBank:Create(ctx())
      local alpha = style.Theme.Header.Buttons.DisabledAlpha
      assert.is_true(alpha > 0 and alpha < 1)
      bank:SetHeaderButtonEnabled(bank.settingsButton, false)
      assert.is_false(bank.settingsButton:IsEnabled())
      assert.are.same({ 0.85, 0.82, 1, alpha }, { bank.settingsButton.icon:GetVertexColor() })
      assert.is_false(bank.settingsButton.icon:IsDesaturated())
      bank.settingsButton:GetScript("OnEnter")(bank.settingsButton)
      assert.are.same({ 0.85, 0.82, 1, alpha }, { bank.settingsButton.icon:GetVertexColor() })
      bank.settingsButton:GetScript("OnLeave")(bank.settingsButton)
      bank:SetHeaderButtonEnabled(bank.settingsButton, true)
      assert.are.same({ 0.85, 0.82, 1, 1 }, { bank.settingsButton.icon:GetVertexColor() })
      apply({ Header = { Buttons = { DisabledAlpha = 0.5, Icons = { settingsButton = { Atlas = "my-art", Glyph = false } } } } })
      bank:SetHeaderButtonEnabled(bank.settingsButton, false)
      local _, _, _, a = bank.settingsButton.icon:GetVertexColor()
      assert.are.equal(0.5, a)
      assert.is_true(bank.settingsButton.icon:IsDesaturated())
      bank:SetHeaderButtonEnabled(bank.settingsButton, true)
      assert.is_false(bank.settingsButton.icon:IsDesaturated())
    end)

    it("keeps a button disabled through a theme switch", function()
      local bank = nextBank:Create(ctx())
      bank:SetHeaderButtonEnabled(bank.settingsButton, false)
      apply({ Header = { Buttons = { DisabledAlpha = 0.4 } } })
      local _, _, _, a = bank.settingsButton.icon:GetVertexColor()
      assert.are.equal(0.4, a)
    end)

    -- Asked: "we need to scale our icons as part of the quiet theme (icon scale should be part of
    -- theme spec in sonata)". An icon's size is a share of its button (Header.Buttons.Scale, times its
    -- own Scale), centered in it; the button, its click area and its place stay the layout's.
    local function iconSize(button)
      return { button.icon:GetWidth(), button.icon:GetHeight() }
    end

    it("draws every icon its button's size in Default, centered on it", function()
      local bag, bank = nextBag:Create(ctx()), nextBank:Create(ctx())
      for _, panel in ipairs({ bag, bank }) do
        every(panel, function(button)
          assert.are.same({ style.HEADER_BUTTON, style.HEADER_BUTTON }, iconSize(button), button.key)
          assert.are.same({ "CENTER", button, "CENTER", 0, 0 }, { button.icon:GetPoint(1) }, button.key)
        end)
      end
    end)

    it("scales every icon in its button by the theme's Scale, one icon by its own too", function()
      local bag, bank = nextBag:Create(ctx()), nextBank:Create(ctx())
      apply({ Header = { Buttons = { Scale = 0.5, Icons = { closeButton = { Scale = 0.5 } } } } })
      assert.are.same({ 11, 11 }, iconSize(bag.settingsButton))
      assert.are.same({ 11, 11 }, iconSize(bag.sizeButton))
      assert.are.same({ 5.5, 5.5 }, iconSize(bank.closeButton))
      assert.are.equal(22, bag.settingsButton:GetWidth(), "the button keeps its size")
      assert.are.same({ "CENTER", bag.settingsButton, "CENTER", 0, 0 }, { bag.settingsButton.icon:GetPoint(1) })
      bag:UpdateSizeButton()
      assert.are.same({ 11, 11 }, iconSize(bag.sizeButton), "through a size switch")
      apply({ Layout = { HeaderButton = 30 }, Header = { Buttons = { Scale = 0.5 } } })
      assert.are.same({ 15, 15 }, iconSize(bag.settingsButton), "a share of the layout's button")
      backToDefault()
      assert.are.same({ 22, 22 }, iconSize(bag.settingsButton))
      assert.are.same({ 22, 22 }, iconSize(bank.closeButton))
    end)

    it("names the button whose icon the theme does not give", function()
      local bag = nextBag:Create(ctx())
      assert.has_error(function() bag:SetHeaderIcon(bag.sortButton, "nopeButton") end,
        "the Next theme has no icon for nopeButton")
    end)
  end)

  describe("the search box", function()
    it("sits where its layout says, in its fill, border and magnifier colors", function()
      local bag = nextBag:Create(ctx())
      apply({ Layout = { SearchTop = 80, SearchHeight = 30 }, Palette = { Field = { 0.3, 0.3, 0.3, 1 } },
        Search = { Fill = "Field", Edge = { Color = "Gold", Size = 2, Idle = 0.5 }, Icon = { Color = "White", Idle = 0.7 } } })
      local frame = bag.searchBox.frame
      assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", style.PAD, -80 }, { frame:GetPoint(1) })
      assert.are.equal(30, frame:GetHeight())
      assert.are.same({ 0.3, 0.3, 0.3, 1 }, { bag.searchFill:GetVertexColor() })
      assert.are.same({ 1, 0.84, 0.5, 0.5 }, { bag.searchEdges[1]:GetVertexColor() })
      assert.are.equal(2, bag.searchEdges[1]:GetHeight())
      assert.are.equal(2, bag.searchEdges[3]:GetWidth())
      assert.are.same({ 1, 1, 1, 0.7 }, { bag.searchBox.textBox.searchIcon:GetVertexColor() })
      apply({ Search = { Edge = false } })
      for _, edge in ipairs(bag.searchEdges) do assert.is_false(edge:IsShown()) end
    end)

    -- Blizzard's search template gives its help text a color of its own (InputBoxInstructionsTemplate's
    -- XML <Color>, 0.35 gray), so the help's role color is set on it too, with every theme.
    it("writes what is typed and its help in its roles' colors, the help's over the template's", function()
      local bag = nextBag:Create(ctx())
      local t = bag.searchBox.textBox
      apply({ Fonts = { SearchText = { Size = 15, Color = "Gold" }, Search = { Size = 11, Color = "White" } } })
      assert.are.equal(style:Font("SearchText"), t:GetFontObject())
      assert.are.same({ 1, 0.84, 0.5, 1 }, { t:GetTextColor() })
      assert.are.equal(style:Font("Search"), t.Instructions:GetFontObject())
      assert.are.same({ 1, 1, 1, 1 }, { t.Instructions:GetTextColor() })
      backToDefault()
      assert.are.same(style.Color.Text, { t:GetTextColor() })
      assert.are.same(style.Color.Muted, { t.Instructions:GetTextColor() })
    end)
  end)

  describe("its tabs and sections", function()
    it("restyles its tab rail and its sections with the panel", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      bag:Draw(ctx(), slots[BACKPACK])
      local bank = opened(function(c) return nextBank:Create(c) end)
      -- Tabs of its own: this bank has no groups or tabs bought.
      bank.tabs:SetTabs({ { id = 1, name = "One" }, { id = 2, name = "Two" } })
      local section = bag.content.order[1]
      assert.is_not_nil(section)
      apply({ Fonts = { Small = { Size = 9 } }, Tabs = { Font = "Small", SelectedFont = "Small" },
        Sections = { Line = false } })
      for _, tab in ipairs(bank.tabs.tabs) do
        assert.are.equal(style:Font("Small"), tab.text:GetFontObject())
      end
      assert.is_true(#bank.tabs.tabs > 0)
      assert.is_false(section.line:IsShown())
    end)
  end)

  describe("the footer and content", function()
    it("draws its line in its colors and size, or none, and its text in its roles", function()
      local bag = nextBag:Create(ctx())
      apply({ Fonts = { Small = { Size = 9 } }, Footer = { Line = { Color = "Gold", Inner = 0.1, Outer = 0.9, Size = 2 },
        Font = "Small", EmptyFont = "Small" } })
      local g = bag.footerLine._gradient
      assert.are.equal(0.9, g.min.a, "toward the screen edge on the backpack")
      assert.are.equal(0.1, g.max.a)
      assert.are.equal(2, bag.footerLine:GetHeight())
      assert.are.equal(style:Font("Small"), bag.freeText:GetFontObject())
      assert.are.equal(style:Font("Small"), bag.emptyText:GetFontObject())
      apply({ Footer = { Line = false } })
      assert.is_false(bag.footerLine:IsShown())
    end)

    it("lays its content out between its header and footer, by its layout", function()
      local bag = nextBag:Create(ctx())
      apply({ Layout = { Pad = 10, ContentTop = 120, Footer = 50, FooterText = 20 } })
      local scroll = bag.scroll.frame
      assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", 10, -120 }, { scroll:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", bag.body, "BOTTOMRIGHT", -10, 50 }, { scroll:GetPoint(2) })
      assert.are.same({ "BOTTOMLEFT", bag.body, "BOTTOMLEFT", 10 + style.TITLE_INSET, 20 }, { bag.freeText:GetPoint(1) })
    end)

    it("takes its sizes at once: the body, the feather, and its buttons drawn again at its icon size", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      bag:Draw(ctx(), slots[BACKPACK])
      apply({ Layout = { Icon = 36, PerRow = 6, Pad = 10, Feather = 40 } })
      assert.are.equal(6 * 36 + 5 * style.GAP + style.GUTTER + 20, style.BODY_WIDTH)
      assert.are.equal(40 + style.BODY_WIDTH, bag.frame:GetWidth())
      assert.are.same({ 40, 0, 0, 0 }, { bag.frame:GetHitRectInsets() })
      assert.are.equal(36, buttons["0_1"].frame:GetWidth())
    end)

    it("draws a hidden panel's content at its sizes when it shows", function()
      local bag = nextBag:Create(ctx())
      bag:Draw(ctx(), slots[BACKPACK])
      apply({ Layout = { Icon = 30 } })
      bag:Show(ctx())
      finishTweens()
      assert.are.equal(30, buttons["0_1"].frame:GetWidth())
    end)
  end)

  describe("sparkles", function()
    it("gives each emitter its rate, life, size and look, or turns it off", function()
      local bag = nextBag:Create(ctx())
      apply({ Sparkles = { Colors = { "White" }, Ribbon = { Rate = 1, Max = 2, Life = { 1, 2 }, Size = { 3, 4 },
        Speed = { 5, 6 }, Rise = { 0, 1 }, Wobble = 0, Spin = 0, Alpha = 0.5, Spread = 30 }, Edge = false } })
      local o = bag.sparkles.options
      assert.are.same({ 1, 2, { 1, 2 }, { 3, 4 }, 0.5 }, { o.Rate, o.Max, o.Life, o.Size, o.Alpha })
      assert.are.equal(30, bag.sparkSpread)
      bag:Show(ctx())
      assert.is_nil(bag.edgeSparkles.frame:GetScript("OnUpdate"), "its edge sparkles are off")
      assert.is_not_nil(bag.sparkles.frame:GetScript("OnUpdate"))
      backToDefault()
      assert.is_not_nil(bag.edgeSparkles.frame:GetScript("OnUpdate"), "back on while it shows")
    end)

    it("stops an emitter a theme turns off while the panel shows", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      apply({ Sparkles = { Cloud = false } })
      assert.is_nil(bag.cloudSparkles.frame:GetScript("OnUpdate"))
    end)
  end)

  describe("the braid", function()
    it("twists as many segments as it says, in its colors, or never", function()
      local bag = nextBag:Create(ctx())
      apply({ Chain = { Segments = 4, Beads = 1, Color = "Lavender" } })
      assert.are.equal(4, #bag.braid.strands[1])
      assert.are.equal(1, #bag.braid.beads)
      assert.are.same({ 0.78, 0.72, 1.0, 1 }, { bag.braid.strands[1][1]:GetVertexColor() })
      bag:SetCoupling(1, 100, true, 0, 0, 120)
      assert.is_true(bag.braid.strands[1][1]:IsShown())
      apply({ Chain = { Segments = 2 } })
      bag:SetCoupling(1, 100, true, 0, 0, 120)
      for i, line in ipairs(bag.braid.linePools[1]) do
        assert.are.equal(i <= 2, line:IsShown(), "segment " .. i)
      end
      apply({ Chain = { Braid = false } })
      bag:SetCoupling(1, 100, true, 0, 0, 120)
      for _, strand in ipairs(bag.braid.strands) do
        for _, line in ipairs(strand) do assert.is_false(line:IsShown()) end
      end
      assert.is_false(bag.braid.knot:IsShown())
    end)
  end)

  -- Every theme BetterBags ships, applied in turn to open bags at both sizes, draws without an error
  -- (SonataNext reports a widget's failure to the error handler and carries on).
  describe("every shipped theme", function()
    it("applies to open, drawn bags at both sizes, in turn, and back to Default", function()
      local errors = {}
      override(_G, "geterrorhandler", function() return function(e) table.insert(errors, tostring(e)) end end)
      for _, size in ipairs({ "full", "small" }) do
        db.size = size
        sonataNext:Init()
        local bag = opened(function(c) return nextBag:Create(c) end)
        local bank = opened(function(c) return nextBank:Create(c) end)
        bag:Draw(ctx(), slots[BACKPACK])
        bank:Draw(ctx(), slots[BANK])
        local keys = {}
        for key in pairs(sonataNext:GetThemes()) do table.insert(keys, key) end
        table.sort(keys)
        assert.is_true(#keys >= 4)
        for _, key in ipairs(keys) do
          sonataNext:ApplyTheme(ctx(), key, false)
          finishTweens()
          assert.are.equal(bag:Width(), bag.frame:GetWidth(), key .. ": shaped for its sizes")
          assert.are.equal(bank:Width(), bank.frame:GetWidth(), key)
        end
        backToDefault()
        finishTweens()
        assert.are.same({}, errors, size)
        assert.are.same(style.Color.Body, rgba(bag.fill._colorTexture))
      end
    end)
  end)

  describe("animations", function()
    it("opens in its time and ease", function()
      local bag = nextBag:Create(ctx())
      apply({ Motion = { Time = { Open = 1 }, Ease = { Open = "linear" } } })
      bag:Show(ctx())
      local from = bag:HiddenOffset()
      tween.driver:GetScript("OnUpdate")(tween.driver, 0.5)
      assert.is_true(math.abs(bag.offset - from / 2) < 1e-6, "halfway, linearly: " .. bag.offset)
      assert.are.equal(4, style.OVERREACH, "no overshoot to cover")
    end)

    it("closes in its time and ease", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      apply({ Motion = { Time = { Close = 1 }, Ease = { Close = "linear" } } })
      bag:Hide(ctx())
      tween.driver:GetScript("OnUpdate")(tween.driver, 0.25)
      assert.is_true(math.abs(bag.offset - bag:HiddenOffset() / 4) < 1e-6)
    end)
  end)
end)
