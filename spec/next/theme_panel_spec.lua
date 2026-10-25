-- A text sits a quarter pixel right of and above its whole pixel (next-pixel-perfect.md §2); one pixel is one unit here.
local TEXT = 0.25
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
  { "NextFrameArt", "next/frameart.lua" }, { "NextFill", "next/fill.lua" }, { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" },
  { "NextSparkles", "next/sparkles.lua" }, { "NextLift", "next/lift.lua" }, { "NextTabs", "next/tabs.lua" }, { "NextContent", "next/content.lua" },
  { "NextDockCard", "next/dockcard.lua" }, { "NextDock", "next/dock.lua" }, { "NextDrag", "next/drag.lua" }, { "NextChain", "next/chain.lua" },
  { "NextOrnaments", "next/ornaments.lua" }, { "NextMenuButton", "next/menubutton.lua" }, { "NextPanel", "next/panel.lua" },
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
    db = { size = "full", theme = "Default", animation = {}, places = {}, smallChain = "apart", view = { [BACKPACK] = SECTION_GRID, [BANK] = SECTION_GRID },
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
    override(stubs.database, "GetNextAnimation", function(_, name) return db.animation[name] ~= false end)
    override(stubs.database, "GetNextIconScale", function() return 100 end)
    override(stubs.database, "GetNextBagScale", function() return 100 end)
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

  -- The Plain theme draws the original bags' window (asked: "the stone window background ... same texture please. just
  -- like the What's New window", and "the bag icon we use in our original bags"; docs/next-plain-theme.md, round two):
  -- Sonata's Default bag window, DefaultPanelTemplate (Blizzard_SharedXML/<Family>/SharedUIPanelTemplates.xml) with its
  -- NineSlice raised over the content, and the menu button's art (frames/menubutton.lua), on every client.
  describe("the Plain theme", function()
    local FLAGS = { "isRetail", "isForever", "isClassic", "isBCC", "isMists", "isAnniversary", "isCata" }
    local CLIENTS = {
      Retail = { flags = { isRetail = true }, layouts = "Retail", sizes = "Retail", corner = "UI-Frame-Metal-CornerTopLeft" },
      Era = { flags = { isClassic = true }, layouts = "Classic", sizes = "Era", corner = "UI-Frame-TopLeftCornerNoPortrait" },
    }
    local function plain(client)
      for _, flag in ipairs(FLAGS) do override(addon, flag, client.flags[flag] == true) end
      UseNineSliceLayouts(client.layouts)
      ResetMockAtlases()
      UseRealAtlasSizes(client.sizes)
      db.size = "small"
      sonataNext:ApplyTheme(ctx(), "Plain", false)
    end
    after_each(function()
      UseNineSliceLayouts("Retail")
      ResetMockAtlases()
      backToDefault()
    end)
    local function near(a, b) return math.abs(a - b) < 0.01 end

    for _, name in ipairs({ "Retail", "Era" }) do
      local client = CLIENTS[name]
      it("draws the original bags' window on " .. name .. ": the stone 6, 21, 2 and 2 in, the frame over the content, the streaks", function()
        plain(client)
        local bag = opened(function(c) return nextBag:Create(c) end)
        assert.are.equal("Interface\\FrameGeneral\\UI-Background-Rock", bag.fill:GetTexture())
        assert.is_true(bag.fill:GetHorizTile() and bag.fill:GetVertTile(), "tiled both ways")
        assert.are.same({ 1, 1, 1, 1 }, { bag.fill:GetVertexColor() }, "untinted and solid")
        local p, rel, rp, x, y = bag.fill:GetPoint(1)
        assert.are.same({ "TOPLEFT", bag.frame, "TOPLEFT" }, { p, rel, rp })
        assert.is_true(near(x, 6) and near(y, -21), x .. "," .. y)
        p, rel, rp, x, y = bag.fill:GetPoint(2)
        assert.are.same({ "BOTTOMRIGHT", bag.frame, "BOTTOMRIGHT" }, { p, rel, rp })
        assert.is_true(near(x, -2) and near(y, 2), x .. "," .. y)
        local corner = bag.frameArt.pieces.TopLeftCorner
        assert.are.equal(client.corner, corner:GetAtlas(), "ButtonFrameTemplateNoPortrait, the client's own")
        assert.is_true(corner:IsShown())
        assert.are.equal(bag.overlay, corner:GetParent(), "over the content")
        local streaks = bag.frameArt.bands[1]
        assert.is_true(streaks:IsShown())
        assert.is_true(streaks:GetHorizTile())
        assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", 6, -21 }, { streaks:GetPoint(1) })
        assert.are.same({ "TOPRIGHT", bag.body, "TOPRIGHT", -2, -21 }, { streaks:GetPoint(2) })
        if name == "Retail" then
          assert.are.equal("_UI-Frame-TopTileStreaks", streaks:GetAtlas())
          assert.are.equal(43, streaks:GetHeight())
          assert.is_false(bag.frameArt.bands[2] ~= nil and bag.frameArt.bands[2]:IsShown(), "retail draws no title band")
        else
          assert.are.equal("Interface\\FrameGeneral\\_UI-Frame", streaks:GetTexture())
          local _, top, _, bottom = streaks:GetTexCoord()
          assert.are.same({ 0.671875, 0.9609375 }, { top, bottom })
          assert.are.equal(37, streaks:GetHeight())
          local band = bag.frameArt.bands[2]
          assert.is_true(band:IsShown())
          assert.are.equal("Interface\\FrameGeneral\\_UI-Frame", band:GetTexture())
          assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", 7, -4 }, { band:GetPoint(1) })
          assert.are.same({ "TOPRIGHT", bag.body, "TOPRIGHT", -24, -4 }, { band:GetPoint(2) })
          assert.are.equal(17, band:GetHeight())
        end
      end)

      -- Round three (asked: "remove all top bar buttons ... bring back the drop down menu with these options, just like the
      -- original bags"): the bag is a button holding the header's actions; only the close stays in the header.
      it("draws the original bags' bag button on " .. name .. ", holding the header's actions, the close alone in the header", function()
        plain(client)
        local bag = opened(function(c) return nextBag:Create(c) end)
        local button = bag.menuButton.frame
        assert.is_true(button:IsShown())
        local p, rel, rp, x, y = button:GetPoint(1)
        assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT" }, { p, rel, rp })
        assert.is_true(near(x, -12) and near(y, 15), x .. "," .. y)
        assert.is_true(near(button:GetWidth(), 40) and near(button:GetHeight(), 40))
        assert.is_true(button:GetFrameLevel() > bag.overlay:GetFrameLevel(), "over the frame and the search box")
        local icon = bag.menuButton.layers[1]
        assert.are.equal("Interface\\Containerframe\\Bagslots2x", icon:GetTexture())
        local ulx, uly, _, lly, urx = icon:GetTexCoord()
        assert.are.same({ 0, 0.2, 0, 1 }, { ulx, urx, uly, lly })
        -- 48 x 60, 14 out and 17 above the corner, as the original's art.
        p, rel, rp, x, y = icon:GetPoint(1)
        assert.are.same({ "TOPLEFT", button, "TOPLEFT" }, { p, rel, rp })
        assert.is_true(near(x, -2) and near(y, 2), x .. "," .. y)
        local glow = bag.menuButton.highlight
        assert.are.equal("Interface\\Containerframe\\Bagslots2x", glow:GetTexture())
        ulx, _, _, _, urx = glow:GetTexCoord()
        assert.are.same({ 0.2, 0.3992 }, { ulx, urx }, "its gold glow")
        for _, b in ipairs(bag.headerButtons) do
          assert.are.equal(b == bag.closeButton, b:IsVisible(), b.key)
        end
        local bank = opened(function(c) return nextBank:Create(c) end)
        p, rel, rp, x, y = bank.menuButton.frame:GetPoint(1)
        assert.are.same({ "TOPRIGHT", bank.body, "TOPRIGHT" }, { p, rel, rp })
        assert.is_true(near(x, 12) and near(y, 15), "the bank's too, as the original's: " .. x .. "," .. y)
        ulx, _, _, _, urx = bank.menuButton.layers[1]:GetTexCoord()
        assert.are.same({ 0, 0.2 }, { ulx, urx }, "never flipped")
      end)
    end
  end)

  describe("the body", function()
    -- Reported in game, opening the bank with Guild Wars 2 applied: "next/panel.lua:2075: attempt to index upvalue
    -- 'from' (a nil value)" in SetWash, from bank.lua useBankType. A panel made under a theme without a wash
    -- (Guild Wars 2, Parchment, Quiet) never painted one, so it had no wash color to fade from.
    it("changes its wash under a theme without one, and shows it in that color once a theme has one", function()
      apply({ Panel = { Wash = false } })
      local bank = nextBank:Create(ctx())
      bank:Show(ctx())
      bank:SetWash("Warbank")
      finishTweens()
      assert.is_false(bank.wash:IsShown())
      backToDefault()
      assert.is_true(bank.wash:IsShown())
      local r, g, b, a = style:RGBA(style.Theme.Panel.Washes.Warbank)
      assert.are.same({ r, g, b, a }, bank.washColor, "the Warbank's, which it showed meanwhile")
      bank:SetWash("Default")
      finishTweens()
      assert.are.same({ style:RGBA(style.Theme.Panel.Washes.Default) }, bank.washColor)
    end)

    -- GW2_UI's windows start their painting below their header (CreateFrameHeaderWithBody), so the header art is
    -- drawn over whatever is behind the window. Asked: "the top window border ... should be somewhat transparent".
    -- Blizzard insets a window's fill into its frame (PortraitFrameFlatBaseTemplate: 2, 20, 2, 3); GW2_UI starts its
    -- painting below its header. Fill.Inset is drawn for the backpack, whose inner side is on the left, mirrored on the
    -- bank; while docked, the side at the screen edge reaches past it instead (the opening bounce, SetDocked).
    it("insets its fill into its body, mirrored on the bank, past the screen edge while docked", function()
      local bag, bank = nextBag:Create(ctx()), nextBank:Create(ctx())
      apply({ Panel = { Fill = { Color = "Body", Inset = { Left = 2, Right = 3, Top = 20, Bottom = 4 } } } })
      local function corners(panel)
        local _, _, _, x1, y1 = panel.fill:GetPoint(1)
        local _, _, _, x2, y2 = panel.fill:GetPoint(2)
        return { x1, y1, x2, y2 }
      end
      local feather = style.FEATHER
      bag:SetDocked(false)
      bank:SetDocked(false)
      assert.are.same({ feather + 2, -20, -3, 4 }, corners(bag), "inner side left")
      assert.are.same({ 3, -20, -(feather + 2), 4 }, corners(bank), "inner side right")
      local reach = style.OVERREACH
      bag:SetDocked(true)
      bank:SetDocked(true)
      assert.are.same({ feather + 2, -20, reach, 4 }, corners(bag))
      assert.are.same({ -reach, -20, -(feather + 2), 4 }, corners(bank))
      backToDefault()
      bag:SetDocked(false)
      assert.are.same({ feather, 0, 0, 0 }, corners(bag), "a theme without")
    end)

    -- The Plain theme (docs/next-plain-theme.md): Blizzard's own frame round the body, one of the client's nine-slice
    -- layouts by name (NextFrameArt), mirrored on the bank as its ornaments are.
    it("draws a frame round its body, mirrored on the bank, and none for a theme without", function()
      ResetMockAtlases()
      MockAtlas("ui-frame-portraitmetal-cornertopleftsmall", 64, 64)
      MockAtlas("UI-Frame-Metal-CornerTopRight", 32, 32)
      MockAtlas("UI-Frame-Metal-CornerBottomLeft", 16, 16)
      MockAtlas("UI-Frame-Metal-CornerBottomRight", 16, 16)
      MockAtlas("_UI-Frame-Metal-EdgeTop", 32, 32, true, false)
      local bag, bank = nextBag:Create(ctx()), nextBank:Create(ctx())
      apply({ Panel = { Frame = { Layout = "HeldBagLayout" } } })
      local corner = bag.frameArt.pieces.TopLeftCorner
      assert.are.equal("ui-frame-portraitmetal-cornertopleftsmall", corner:GetAtlas())
      assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", -13, 16 }, { corner:GetPoint(1) })
      assert.is_true(corner:IsShown())
      local mirrored = bank.frameArt.pieces.TopRightCorner
      assert.are.equal("ui-frame-portraitmetal-cornertopleftsmall", mirrored:GetAtlas(), "the portrait corner at its inner side")
      assert.are.same({ "TOPRIGHT", bank.body, "TOPRIGHT", 13, 16 }, { mirrored:GetPoint(1) })
      backToDefault()
      assert.is_false(corner:IsShown())
      assert.is_false(mirrored:IsShown())
      ResetMockAtlases()
    end)

    -- The original bags' border is above their content (Sonata's Default: NineSlice at +500), their title and close
    -- button above it (TitleContainer and the close at +510): a frame that says Above is drawn on the panel's overlay, a
    -- frame over the content, and the title and the header's buttons sit above that.
    it("draws a frame that says Above over its content, its title and header buttons over the frame", function()
      ResetMockAtlases()
      MockAtlas("UI-Frame-Metal-CornerTopLeft", 75, 75)
      local bag = nextBag:Create(ctx())
      apply({ Panel = { Frame = { Layout = "ButtonFrameTemplateNoPortrait", Above = true } } })
      local corner = bag.frameArt.pieces.TopLeftCorner
      assert.are.equal(bag.overlay, corner:GetParent())
      assert.is_true(corner:IsShown())
      assert.is_false(bag.overlay:IsMouseEnabled(), "the window stays the drop target")
      assert.is_true(bag.overlay:GetFrameLevel() > bag.content.frame:GetFrameLevel() + 10, "over the content and its sections")
      assert.are.equal(bag.overlay, bag.title:GetParent(), "the title on it, drawn over its art")
      assert.are.same("OVERLAY", (bag.title:GetDrawLayer()))
      assert.is_true(bag.closeButton:GetFrameLevel() > bag.overlay:GetFrameLevel())
      assert.is_true(bag.sortButton:GetFrameLevel() > bag.overlay:GetFrameLevel())
      backToDefault()
      assert.is_false(corner:IsShown())
      ResetMockAtlases()
    end)

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
      assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", style.PAD + 10 + TEXT, -30 + TEXT }, { bag.title:GetPoint(1) })
      assert.are.same({ "TOPRIGHT", bank.body, "TOPRIGHT", -(style.PAD + 10) + TEXT, -30 + TEXT }, { bank.title:GetPoint(1) })
    end)

    it("lights the title's glow on hover, by its alpha and spread, or not at all", function()
      local bag = nextBag:Create(ctx())
      apply({ Header = { TitleGlow = { Texture = "Glow", Color = "White", Alpha = 0.5, X = 10, Y = 5 } } })
      local glow = bag.titleGlow
      -- From the body's corner by whole pixels (docs/next-pixel-perfect.md): the title's place less the
      -- spread, as wide as its text (rounded up) and as tall as its font, plus the spread on each side.
      local inset = style.PAD + style.TITLE_INSET
      assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", inset - 10, -(style.TITLE_TOP - 5) }, { glow:GetPoint(1) })
      local _, fontHeight = bag.title:GetFont()
      assert.are.same({ math.ceil(bag.title:GetStringWidth()) + 20, fontHeight + 10 }, { glow:GetSize() })
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
      assert.are.same({ "TOPRIGHT", first, "TOPLEFT", -4, 0 }, { second:GetPoint(1) })
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
  -- The Plain theme (docs/next-plain-theme.md): Blizzard's close button sits in the window's top corner; the other
  -- header buttons go in the title bar beside it, the row starting RowStart in from the outer edge.
  describe("a header row starting past a pinned button (RowStart)", function()
    it("starts the row RowStart in, and leaves the title the room the row and the pins take, once", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      apply({ Header = { Title = { Font = "Title", Justify = "CENTER" }, Buttons = { RowStart = 30,
        Pinned = { closeButton = { Point = "TOPOUTER", X = 1, Y = 0 } } } } })
      local first
      for _, button in ipairs(bag.headerButtons) do
        if button:IsShown() and button ~= bag.closeButton then
          first = first or button
        end
      end
      local point, rel, relPoint, x = first:GetPoint(1)
      assert.are.same({ "TOPRIGHT", bag.body, "TOPRIGHT", -30 }, { point, rel, relPoint, x })
      local inset = bag:InnerPad() + style.TITLE_INSET
      local room = 30 + bag:headerButtonsWidth()
      assert.are.equal(bag:BodyWidth() - inset - room - 12, bag.title:GetWidth())
    end)
  end)

  -- The Plain theme (docs/next-plain-theme.md, round three; asked: "remove all top bar buttons, make sure our bag title
  -- is always correctly centered from the right of the bag button, to the left of the close button", and "bring back
  -- the drop down menu with these options, just like the original bags"): a theme can put its header's row in a menu
  -- on a bag button at a corner (Header.Buttons.Menu, NextMenuButton).
  describe("a header row in a menu (Header.Buttons.Menu)", function()
    local BAGSLOTS = "Interface\\Containerframe\\Bagslots2x"
    local function menuTheme()
      apply({ Header = { Title = { Font = "Title", Justify = "CENTER" }, Buttons = {
        Menu = { Point = "TOPINNER", X = -12, Y = -15, Width = 40, Height = 40,
          Layers = { { Texture = BAGSLOTS, TexCoords = { 0, 0.2, 0, 1 } } } },
        Pinned = { closeButton = { Point = "TOPOUTER", X = 1, Y = 0 } } } } })
    end

    after_each(function()
      backToDefault()
    end)

    it("takes its row's buttons out of the header, keeping whether the panel shows them, and puts them back after", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      local level = bag.sortButton:GetFrameLevel()
      menuTheme()
      assert.is_true(bag.menuButton.frame:IsShown())
      assert.are.equal(bag.menuHolder, bag.sortButton:GetParent())
      assert.is_true(bag.sortButton:IsShown(), "still shown by the panel, for the menu")
      assert.is_false(bag.sortButton:IsVisible())
      assert.are.equal(bag.frame, bag.closeButton:GetParent(), "a pinned button stays")
      assert.is_true(bag.closeButton:IsVisible())
      backToDefault()
      assert.is_false(bag.menuButton.frame:IsShown())
      assert.are.equal(bag.frame, bag.sortButton:GetParent())
      assert.is_true(bag.sortButton:IsVisible())
      assert.is_true(bag.sortButton:GetFrameLevel() > bag.overlay:GetFrameLevel(), "over the frame above the content again")
      assert.are.equal(level, bag.sortButton:GetFrameLevel(), "at the level it was made at")
    end)

    -- A new parent changes a frame's level (Blizzard's LFDFrame.lua, FrameUtil.SetParentMaintainRenderLayering), and a
    -- button back from the holder at one above the panel sat under a small panel's mover, which lies over the title row
    -- and took its clicks (reported: after the Plain theme and back, the header buttons did nothing until a reload).
    it("gives its row's buttons back their clicks over a small panel's mover", function()
      db.size = "small"
      local bag = opened(function(c) return nextBag:Create(c) end)
      menuTheme()
      backToDefault()
      for _, key in ipairs({ "settingsButton", "sortButton", "bagsButton", "sizeButton" }) do
        assert.is_true(bag[key]:GetFrameLevel() > bag.mover:GetFrameLevel(), key)
        assert.is_true(bag[key]:GetFrameLevel() > bag.overlay:GetFrameLevel(), key)
      end
    end)

    it("centers its title between the bag button and the close button, on either side", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      local bank = opened(function(c) return nextBank:Create(c) end)
      menuTheme()
      -- The bag button reaches 28 in (12 out, 40 wide); the close takes its width less the pixel it sits past the edge.
      local close = style.HEADER_BUTTON - 1
      local p, rel, rp, x = bag.title:GetPoint(1)
      assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", 28 + TEXT }, { p, rel, rp, x })
      assert.are.equal(bag:BodyWidth() - 28 - close, bag.title:GetWidth())
      assert.are.equal("CENTER", bag.title:GetJustifyH())
      p, rel, rp, x = bank.title:GetPoint(1)
      assert.are.same({ "TOPRIGHT", bank.body, "TOPRIGHT", -28 + TEXT }, { p, rel, rp, x })
      assert.are.equal(bank:BodyWidth() - 28 - close, bank.title:GetWidth())
    end)

    it("lists the backpack's actions in its menu, Open Options Screen last, its toggles checked as they are", function()
      local list
      override(StubBetterBagsModule("ContextMenu"), "Show", function(_, _, entries) list = entries end)
      local bag = opened(function(c) return nextBag:Create(c) end)
      menuTheme()
      bag.menuButton:Open(ctx())
      local names = {}
      for i = 2, #list do
        names[i - 1] = list[i].text
      end
      assert.are.same({ "Sort Bags", "Show Blizzard Bags", "Small Bags", "Open Options Screen" }, names)
      assert.is_false(list[3].checked())
      assert.are.equal(bag:IsSmall(), list[4].checked())
    end)

    it("draws its bag button again each time it shows (a vendor's portrait)", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      menuTheme()
      local painted = 0
      override(bag.menuButton, "Paint", function() painted = painted + 1 end)
      bag:Hide(ctx())
      finishTweens()
      bag:Show(ctx())
      assert.are.equal(1, painted)
    end)
  end)

  -- The Plain theme (docs/next-plain-theme.md): Blizzard centers a window's title in the room its buttons leave
  -- (PortraitFrameBaseTemplate's TitleContainer). Its click area and glow follow the text where it is drawn.
  describe("a centered title", function()
    it("centers the title in the room the header buttons leave, its button over the text, mirrored on the bank", function()
      local bag, bank = opened(function(c) return nextBag:Create(c) end), opened(function(c) return nextBank:Create(c) end)
      apply({ Header = { Title = { Font = "Title", Justify = "CENTER" } } })
      for _, panel in ipairs({ bag, bank }) do
        local title = panel.title
        assert.are.equal("CENTER", title:GetJustifyH())
        assert.is_false(title:CanWordWrap())
        local inset = panel:InnerPad() + style.TITLE_INSET
        local room = panel:BodyWidth() - inset - (style.PAD + panel:headerButtonsWidth()) - panel:pinnedRoom() - 12
        assert.are.equal(room, title:GetWidth())
        local shift = math.floor((room - math.ceil(title:GetStringWidth())) / 2)
        local point, rel, relPoint, x = panel.titleButton:GetPoint(1)
        if panel.side == "LEFT" then
          assert.are.same({ "TOPRIGHT", panel.body, "TOPRIGHT", -(inset + shift - 8) }, { point, rel, relPoint, x })
        else
          assert.are.same({ "TOPLEFT", panel.body, "TOPLEFT", inset + shift - 8 }, { point, rel, relPoint, x })
        end
      end
      backToDefault()
      assert.are.equal("LEFT", bag.title:GetJustifyH())
      assert.are.equal(0, bag.title:GetWidth(), "as long as it is again")
    end)
  end)

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
            bagsButton = { Texture = "Interface\\Sheet", TexCoords = { 0.5, 1, 0, 0.5 }, Glyph = false } } } } })
      assert.are.equal("my-art", bag.sortButton.icon:GetAtlas())
      assert.are.same({ 0.9, 0.9, 0.9 }, color(bag.sortButton))
      bag.sortButton:GetScript("OnEnter")(bag.sortButton)
      assert.are.same({ 1, 0.84, 0.5 }, color(bag.sortButton), "art brightens in its own hover color")
      bag.sortButton:GetScript("OnLeave")(bag.sortButton)
      assert.are.equal("Interface\\MyGear", bag.settingsButton.icon:GetTexture())
      assert.are.same({ 0.2, 0.1, 0.05 }, color(bag.settingsButton), "a glyph unless it says otherwise")
      assert.are.equal("Interface\\Sheet", bag.bagsButton.icon:GetTexture())
      assert.are.same({ 0.5, 1, 0, 0.5 }, bag.bagsButton.icon._texCoords)
      assert.are.same({ 0.9, 0.9, 0.9 }, color(bag.bagsButton))
      backToDefault()
      assert.are.equal("sort", NextIconName(bag.sortButton))
      assert.are.same({ 0, 1, 0, 1 }, bag.bagsButton.icon._texCoords)
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
    -- own Scale), centered in it; the button, its click area and its place stay the layout's. Both in
    -- whole pixels, the icon centered by its top left with the odd pixel to the right and bottom
    -- (docs/next-pixel-perfect.md).
    local function iconSize(button)
      return { button.icon:GetWidth(), button.icon:GetHeight() }
    end

    it("draws every icon its button's size in Default, centered on it", function()
      local bag, bank = nextBag:Create(ctx()), nextBank:Create(ctx())
      for _, panel in ipairs({ bag, bank }) do
        every(panel, function(button)
          assert.are.same({ style.HEADER_BUTTON, style.HEADER_BUTTON }, iconSize(button), button.key)
          assert.are.same({ "TOPLEFT", button, "TOPLEFT", 0, 0 }, { button.icon:GetPoint(1) }, button.key)
        end)
      end
    end)

    it("scales every icon in its button by the theme's Scale, one icon by its own too", function()
      local bag, bank = nextBag:Create(ctx()), nextBank:Create(ctx())
      apply({ Header = { Buttons = { Scale = 0.5, Icons = { closeButton = { Scale = 0.5 } } } } })
      assert.are.same({ 11, 11 }, iconSize(bag.settingsButton))
      assert.are.same({ 11, 11 }, iconSize(bag.sizeButton))
      assert.are.same({ 6, 6 }, iconSize(bank.closeButton), "5.5 rounded to a whole pixel")
      assert.are.equal(22, bag.settingsButton:GetWidth(), "the button keeps its size")
      assert.are.same({ "TOPLEFT", bag.settingsButton, "TOPLEFT", 5, -5 }, { bag.settingsButton.icon:GetPoint(1) })
      assert.are.same({ "TOPLEFT", bank.closeButton, "TOPLEFT", 8, -8 }, { bank.closeButton.icon:GetPoint(1) })
      bag:UpdateSizeButton()
      assert.are.same({ 11, 11 }, iconSize(bag.sizeButton), "through a size switch")
      apply({ Layout = { HeaderButton = 30 }, Header = { Buttons = { Scale = 0.5 } } })
      assert.are.same({ 15, 15 }, iconSize(bag.settingsButton), "a share of the layout's button")
      backToDefault()
      assert.are.same({ 22, 22 }, iconSize(bag.settingsButton))
      assert.are.same({ 22, 22 }, iconSize(bank.closeButton))
    end)

    -- GW2_UI highlights its buttons by drawing art over their icon while hovered (a button's highlight texture: its
    -- bag's `-down` art, its micro menu's own icon again, Micromenu/micromenu.lua). Asked: one highlight for every
    -- side button, as the Show Blizzard Bags one does.
    it("draws an icon's highlight over it under the pointer, in its blend mode, never while disabled", function()
      local bag = nextBag:Create(ctx())
      apply({ Header = { Buttons = { Icons = {
        closeButton = { Texture = "Interface\\Spec\\close.png", Glyph = false,
          Highlight = { Texture = "Interface\\Spec\\close-hover.png" } },
        sortButton = { Atlas = "spec-sort", Highlight = { Atlas = "spec-sort", BlendMode = "ADD" } },
      } } } })
      local close, sort = bag.closeButton, bag.sortButton
      assert.are.equal("Interface\\Spec\\close.png", close.icon:GetTexture())
      assert.is_false(close.highlight:IsShown())
      close:GetScript("OnEnter")(close)
      assert.are.equal("Interface\\Spec\\close.png", close.icon:GetTexture(), "the icon stays")
      assert.is_true(close.highlight:IsShown())
      assert.are.equal("Interface\\Spec\\close-hover.png", close.highlight:GetTexture())
      assert.are.equal("BLEND", close.highlight:GetBlendMode())
      assert.are.same({ close.icon:GetPoint(1) }, { close.highlight:GetPoint(1) }, "over it")
      assert.are.same({ close.icon:GetSize() }, { close.highlight:GetSize() })
      close:GetScript("OnLeave")(close)
      assert.is_false(close.highlight:IsShown())
      sort:GetScript("OnEnter")(sort)
      assert.are.equal("spec-sort", sort.highlight:GetAtlas())
      assert.are.equal("ADD", sort.highlight:GetBlendMode())
      sort:GetScript("OnLeave")(sort)
      bag:SetHeaderButtonEnabled(close, false)
      close:GetScript("OnEnter")(close)
      assert.is_false(close.highlight:IsShown(), "disabled")
      close:GetScript("OnLeave")(close)
      backToDefault()
      close:GetScript("OnEnter")(close)
      assert.is_false(close.highlight:IsShown(), "a theme without one")
      close:GetScript("OnLeave")(close)
    end)

    -- The Plain theme (docs/next-plain-theme.md): Blizzard's close button has art of its own pressed and disabled
    -- (UIPanelCloseButtonNoScripts: RedButton-exit-pressed, RedButton-Exit-Disabled).
    it("draws an icon's own art while pressed and while disabled, its disabled art neither dimmed nor grayed", function()
      local bag = nextBag:Create(ctx())
      apply({ Header = { Buttons = { Icons = { closeButton = { Atlas = "RedButton-Exit", Glyph = false,
        Pushed = { Atlas = "RedButton-exit-pressed" }, Disabled = { Atlas = "RedButton-Exit-Disabled" } } } } } })
      local close = bag.closeButton
      assert.are.equal("RedButton-Exit", close.icon:GetAtlas())
      close:GetScript("OnMouseDown")(close, "LeftButton")
      assert.are.equal("RedButton-exit-pressed", close.icon:GetAtlas())
      close:GetScript("OnMouseUp")(close, "LeftButton")
      assert.are.equal("RedButton-Exit", close.icon:GetAtlas())
      close:GetScript("OnMouseDown")(close, "LeftButton")
      close:GetScript("OnLeave")(close)
      assert.are.equal("RedButton-Exit", close.icon:GetAtlas(), "not once the pointer leaves")
      bag:SetHeaderButtonEnabled(close, false)
      assert.are.equal("RedButton-Exit-Disabled", close.icon:GetAtlas())
      assert.is_false(close.icon:IsDesaturated())
      local _, _, _, a = close.icon:GetVertexColor()
      assert.are.equal(select(4, style:RGBA(style.Theme.Header.Buttons.ArtColor)), a, "not dimmed")
      close:GetScript("OnMouseDown")(close, "LeftButton")
      assert.are.equal("RedButton-Exit-Disabled", close.icon:GetAtlas(), "not pressed while disabled")
      close:GetScript("OnMouseUp")(close, "LeftButton")
      bag:SetHeaderButtonEnabled(close, true)
      assert.are.equal("RedButton-Exit", close.icon:GetAtlas())
      backToDefault()
      bag:SetHeaderButtonEnabled(close, false)
      assert.are.equal(style:TexturePath(style.Theme.Header.Buttons.Icons.closeButton.Texture), close.icon:GetTexture(),
        "a theme without: its icon, dimmed")
      bag:SetHeaderButtonEnabled(close, true)
    end)

    it("names the button whose icon the theme does not give", function()
      local bag = nextBag:Create(ctx())
      assert.has_error(function() bag:SetHeaderIcon(bag.sortButton, "nopeButton") end,
        "the Next theme has no icon for nopeButton")
    end)
  end)

  -- Asked, for the Guild Wars 2 theme: "you can move the top icon buttons to be side buttons, and side buttons
  -- can be left on backpack, and right on other bags" (docs/next-gw2-theme.md).
  describe("a side rail (Header.Buttons.Rail)", function()
    local RAIL = { Width = 40, Top = 64, Gap = 6,
      Fill = { Texture = "Interface\\AddOns\\Spec\\rail.png", TexCoords = { 0, 1, 0, 0.5 } } }

    local function shown(panel)
      local out = {}
      for _, button in ipairs(panel.headerButtons) do
        if button:IsShown() then table.insert(out, button) end
      end
      return out
    end

    local function coords(texture)
      local ulx, uly, _, lly, urx = texture:GetTexCoord()
      return { ulx, urx, uly, lly }
    end

    it("puts the header buttons down the backpack's left and the bank's right, from its top, centered across it", function()
      local bag, bank = nextBag:Create(ctx()), nextBank:Create(ctx())
      apply({ Header = { Buttons = { Rail = RAIL } } })
      local x, step = math.floor((40 - style.HEADER_BUTTON) / 2), style.HEADER_BUTTON + 6
      assert.is_true(#shown(bag) > 1 and #shown(bank) > 1)
      for i, button in ipairs(shown(bag)) do
        assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", x, -(64 + (i - 1) * step) }, { button:GetPoint(1) }, button.key)
      end
      for i, button in ipairs(shown(bank)) do
        assert.are.same({ "TOPRIGHT", bank.body, "TOPRIGHT", -x, -(64 + (i - 1) * step) }, { button:GetPoint(1) }, button.key)
      end
    end)

    it("closes the gap a hidden button leaves, and takes the header's gap without its own", function()
      local bag = nextBag:Create(ctx())
      apply({ Header = { Buttons = { Rail = { Width = 40, Top = 64 } } } })
      local list = shown(bag)
      assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", 9, -(64 + style.HEADER_BUTTON + style.HEADER_BUTTON_GAP) },
        { list[2]:GetPoint(1) })
      list[1]:Hide()
      bag:LayoutHeader()
      assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", 9, -64 }, { list[2]:GetPoint(1) })
    end)

    it("draws its strip down the inner side in its art, mirrored on the bank, and none without art or a rail", function()
      local bag, bank = nextBag:Create(ctx()), nextBank:Create(ctx())
      assert.is_false(bag.rail:IsShown(), "Default has no rail")
      apply({ Header = { Buttons = { Rail = RAIL } } })
      assert.is_true(bag.rail:IsShown())
      assert.are.equal("Interface\\AddOns\\Spec\\rail.png", bag.rail:GetTexture())
      assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", 0, 0 }, { bag.rail:GetPoint(1) })
      assert.are.same({ "BOTTOMLEFT", bag.body, "BOTTOMLEFT", 0, 0 }, { bag.rail:GetPoint(2) })
      assert.are.equal(40, bag.rail:GetWidth())
      assert.are.same({ 0, 1, 0, 0.5 }, coords(bag.rail))
      assert.are.same({ "TOPRIGHT", bank.body, "TOPRIGHT", 0, 0 }, { bank.rail:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", bank.body, "BOTTOMRIGHT", 0, 0 }, { bank.rail:GetPoint(2) })
      assert.are.same({ 1, 0, 0, 0.5 }, coords(bank.rail), "mirrored")
      apply({ Header = { Buttons = { Rail = { Width = 40, Top = 64, Fill = false } } } })
      assert.is_false(bag.rail:IsShown(), "room for the buttons, no art")
      backToDefault()
      assert.is_false(bag.rail:IsShown())
      assert.are.same({ "TOPRIGHT", bag.body, "TOPRIGHT", -style.PAD, -style.HEADER_BUTTON_TOP }, { shown(bag)[1]:GetPoint(1) },
        "back across the header")
    end)

    it("widens the body by the strip, everything inside keeping its room on the inner side", function()
      local bag, bank = nextBag:Create(ctx()), nextBank:Create(ctx())
      local width = style.BODY_WIDTH
      apply({ Header = { Buttons = { Rail = RAIL } } })
      assert.are.equal(width + 40, style.BODY_WIDTH)
      assert.are.equal(style.FEATHER + style.BODY_WIDTH, bag.frame:GetWidth())
      assert.are.equal(width - 2 * style.PAD, bag.root:PreRender().Width, "the content as wide as without one")
      assert.are.equal(width - 2 * style.PAD, bag.root:PreRender().LayoutWidth)
      local inner, pad = style.PAD + 40, style.PAD
      assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", inner, -style.CONTENT_TOP }, { bag.scroll.frame:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", bag.body, "BOTTOMRIGHT", -pad, bag:ContentBottom() }, { bag.scroll.frame:GetPoint(2) })
      assert.are.same({ "TOPLEFT", bank.body, "TOPLEFT", pad, -style.CONTENT_TOP }, { bank.scroll.frame:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", bank.body, "BOTTOMRIGHT", -inner, bank:ContentBottom() }, { bank.scroll.frame:GetPoint(2) })
      assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", inner + style.TITLE_INSET + TEXT, -style.TITLE_TOP + TEXT }, { bag.title:GetPoint(1) })
      assert.are.same({ "TOPRIGHT", bank.body, "TOPRIGHT", -(inner + style.TITLE_INSET) + TEXT, -style.TITLE_TOP + TEXT }, { bank.title:GetPoint(1) })
      local search = bag.searchBox.frame
      assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", inner, -style.SEARCH_TOP }, { search:GetPoint(1) })
      assert.are.same({ "TOPRIGHT", bag.body, "TOPRIGHT", -pad, -style.SEARCH_TOP }, { search:GetPoint(2) })
      local bankSearch = bank.searchBox.frame
      assert.are.same({ "TOPLEFT", bank.body, "TOPLEFT", pad, -style.SEARCH_TOP }, { bankSearch:GetPoint(1) })
      assert.are.same({ "TOPRIGHT", bank.body, "TOPRIGHT", -inner, -style.SEARCH_TOP }, { bankSearch:GetPoint(2) })
      assert.are.same({ "BOTTOMLEFT", bag.body, "BOTTOMLEFT", inner, style.FOOTER - 4 }, { bag.footerLine:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", bag.body, "BOTTOMRIGHT", -pad, style.FOOTER - 4 }, { bag.footerLine:GetPoint(2) })
      assert.are.same({ "BOTTOMRIGHT", bank.body, "BOTTOMRIGHT", -inner, style.FOOTER - 4 }, { bank.footerLine:GetPoint(2) })
      assert.are.same({ "BOTTOMLEFT", bag.body, "BOTTOMLEFT", inner + style.TITLE_INSET + TEXT, style.FOOTER_TEXT + TEXT }, { bag.freeText:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", bank.body, "BOTTOMRIGHT", -(inner + style.TITLE_INSET) + TEXT, style.FOOTER_TEXT + TEXT },
        { bank.freeText:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", bag.body, "BOTTOMRIGHT", -pad, style.FOOTER_MONEY }, { bag.moneyFrame.frame:GetPoint(1) },
        "the money stays on the outer side")
      assert.are.same({ "LEFT", -(inner + style.TITLE_INSET), 1 }, { bag:TitleJoin() })
      assert.are.same({ "RIGHT", inner + style.TITLE_INSET, -1 }, { bank:TitleJoin() })
      backToDefault()
      assert.are.equal(width, style.BODY_WIDTH)
      assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", pad, -style.CONTENT_TOP }, { bag.scroll.frame:GetPoint(1) })
    end)

    it("keeps what is drawn about the title with it: its glow behind it, its cloud across it", function()
      local bag, bank = nextBag:Create(ctx()), nextBank:Create(ctx())
      local span = bag:CloudSpan()
      apply({ Header = { Buttons = { Rail = RAIL } } })
      local G = style.Theme.Header.TitleGlow
      local inset = style.PAD + 40 + style.TITLE_INSET
      assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", inset - G.X, -(style.TITLE_TOP - G.Y) }, { bag.titleGlow:GetPoint(1) })
      assert.are.same({ "TOPRIGHT", bank.body, "TOPRIGHT", -(inset - G.X), -(style.TITLE_TOP - G.Y) }, { bank.titleGlow:GetPoint(1) })
      assert.are.equal(span + 40, bag:CloudSpan(), "from the window's edge, past the strip")
    end)

    -- The ribbon starts at the window's hard edge, the strip or not, a theme applied after the panel was made too.
    it("starts its sparkles where the ribbon starts, at the window's edge", function()
      local bag, bank = nextBag:Create(ctx()), nextBank:Create(ctx())
      override(math, "random", function() return 0 end)
      local function starts(panel)
        local x = panel.sparkles.options.Spawn()
        return x
      end
      assert.are.equal(bag:BodyLeft(), starts(bag))
      assert.are.equal(bank:BodyLeft() + bank:BodyWidth(), starts(bank))
      apply({ Header = { Buttons = { Rail = RAIL } } })
      assert.are.equal(bag:BodyLeft(), starts(bag))
      assert.are.equal(bank:BodyLeft() + bank:BodyWidth(), starts(bank))
    end)

    -- GW2_UI's side panel stands beside its windows, outside them (docs/next-gw2-theme.md, round two).
    describe("outside the body (Outside)", function()
      local OUTSIDE = { Width = 40, Top = 64, Gap = 6, Outside = true, Fill = RAIL.Fill }

      it("stands the strip beside the body's inner edge, the body and its content keeping their room", function()
        local bag, bank = nextBag:Create(ctx()), nextBank:Create(ctx())
        local width = style.BODY_WIDTH
        apply({ Header = { Buttons = { Rail = OUTSIDE } } })
        assert.are.equal(width, style.BODY_WIDTH)
        assert.are.same({ "TOPRIGHT", bag.body, "TOPLEFT", 0, 0 }, { bag.rail:GetPoint(1) })
        assert.are.same({ "BOTTOMRIGHT", bag.body, "BOTTOMLEFT", 0, 0 }, { bag.rail:GetPoint(2) })
        assert.are.same({ "TOPLEFT", bank.body, "TOPRIGHT", 0, 0 }, { bank.rail:GetPoint(1) })
        assert.are.same({ "BOTTOMLEFT", bank.body, "BOTTOMRIGHT", 0, 0 }, { bank.rail:GetPoint(2) })
        assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", style.PAD, -style.CONTENT_TOP }, { bag.scroll.frame:GetPoint(1) })
        assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", style.PAD + style.TITLE_INSET + TEXT, -style.TITLE_TOP + TEXT }, { bag.title:GetPoint(1) })
        local step = style.HEADER_BUTTON + 6
        for i, button in ipairs(shown(bag)) do
          assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", -(40 - 9), -(64 + (i - 1) * step) }, { button:GetPoint(1) }, button.key)
        end
        for i, button in ipairs(shown(bank)) do
          assert.are.same({ "TOPRIGHT", bank.body, "TOPRIGHT", 40 - 9, -(64 + (i - 1) * step) }, { button:GetPoint(1) }, button.key)
        end
      end)

      -- GW2_UI's side panel runs from its window's top line (GwWindowLeftPanel), the middle of its header.
      it("starts the strip's art Start below the body's top", function()
        local bag = nextBag:Create(ctx())
        apply({ Header = { Buttons = { Rail = { Width = 40, Top = 64, Outside = true, Start = 42, Fill = RAIL.Fill } } } })
        assert.are.same({ "TOPRIGHT", bag.body, "TOPLEFT", 0, -42 }, { bag.rail:GetPoint(1) })
        assert.are.same({ "BOTTOMRIGHT", bag.body, "BOTTOMLEFT", 0, 0 }, { bag.rail:GetPoint(2) })
      end)

      it("hangs the tabs past the strip, and spaces a chained pair for both strips", function()
        local bag, bank = nextBag:Create(ctx()), nextBank:Create(ctx())
        -- A narrow feather and no small minimum, so the tab rails (not the feathers) set the gaps.
        apply({ Layout = { Feather = 10 }, Small = { MinGap = 0 } })
        local gap, small = chain:Gap(bag, bank), chain:SmallGap(bag, bank)
        apply({ Layout = { Feather = 10 }, Small = { MinGap = 0 }, Header = { Buttons = { Rail = OUTSIDE } } })
        assert.are.same({ "TOPRIGHT", bag.body, "TOPLEFT", -40, -style.CONTENT_TOP }, { bag.tabs.frame:GetPoint(1) })
        assert.are.same({ "TOPLEFT", bank.body, "TOPRIGHT", 40, -style.CONTENT_TOP }, { bank.tabs.frame:GetPoint(1) })
        assert.are.equal(gap + 80, chain:Gap(bag, bank))
        assert.are.equal(small + 80, chain:SmallGap(bag, bank))
        backToDefault()
        assert.are.same({ "TOPRIGHT", bag.body, "TOPLEFT", 0, -style.CONTENT_TOP }, { bag.tabs.frame:GetPoint(1) })
      end)
    end)

    -- Asked: "X button should still be top right" (docs/next-gw2-theme.md, round two).
    describe("pinned buttons (Pinned)", function()
      local PINNED = { closeButton = { Point = "TOPRIGHT", X = -5, Y = -4 } }

      it("puts a pinned button at its corner of the body on every panel, by WoW offsets, apart from the rail", function()
        local bag, bank = nextBag:Create(ctx()), nextBank:Create(ctx())
        apply({ Header = { Buttons = { Rail = RAIL, Pinned = PINNED } } })
        assert.are.same({ "TOPRIGHT", bag.body, "TOPRIGHT", -5, -4 }, { bag.closeButton:GetPoint(1) })
        assert.are.same({ "TOPRIGHT", bank.body, "TOPRIGHT", -5, -4 }, { bank.closeButton:GetPoint(1) })
        local first = shown(bag)[1] == bag.closeButton and shown(bag)[2] or shown(bag)[1]
        assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", 9, -64 }, { first:GetPoint(1) }, "the rail starts past it")
        local step = style.HEADER_BUTTON + 6
        local y = 64
        for _, button in ipairs(shown(bank)) do
          if button ~= bank.closeButton then
            assert.are.same({ "TOPRIGHT", bank.body, "TOPRIGHT", -9, -y }, { button:GetPoint(1) }, button.key)
            y = y + step
          end
        end
      end)

      -- A corner named by its side (as ornaments name theirs, next-themes.md §12): drawn for the backpack, whose inner
      -- side is on the left, mirrored on the panels whose inner side is on the right.
      it("pins a button to its top outer corner, top right on the backpack and top left mirrored", function()
        local bag, bank = nextBag:Create(ctx()), nextBank:Create(ctx())
        apply({ Header = { Buttons = { Rail = RAIL, Pinned = { closeButton = { Point = "TOPOUTER", X = -6, Y = -6 } } } } })
        assert.are.same({ "TOPRIGHT", bag.body, "TOPRIGHT", -6, -6 }, { bag.closeButton:GetPoint(1) })
        assert.are.same({ "TOPLEFT", bank.body, "TOPLEFT", 6, -6 }, { bank.closeButton:GetPoint(1) })
        apply({ Header = { Buttons = { Pinned = { closeButton = { Point = "BOTTOMINNER", X = 3, Y = 4 } } } } })
        assert.are.same({ "BOTTOMLEFT", bag.body, "BOTTOMLEFT", 3, 4 }, { bag.closeButton:GetPoint(1) })
        assert.are.same({ "BOTTOMRIGHT", bank.body, "BOTTOMRIGHT", -3, 4 }, { bank.closeButton:GetPoint(1) })
      end)

      it("pins a button out of the header row too, and the row closes up without it", function()
        local bag = nextBag:Create(ctx())
        apply({ Header = { Buttons = { Pinned = PINNED } } })
        assert.are.same({ "TOPRIGHT", bag.body, "TOPRIGHT", -5, -4 }, { bag.closeButton:GetPoint(1) })
        local rest = {}
        for _, button in ipairs(shown(bag)) do
          if button ~= bag.closeButton then table.insert(rest, button) end
        end
        assert.are.same({ "TOPRIGHT", bag.body, "TOPRIGHT", -style.PAD, -style.HEADER_BUTTON_TOP }, { rest[1]:GetPoint(1) })
        assert.are.same({ "TOPRIGHT", rest[1], "TOPLEFT", -style.HEADER_BUTTON_GAP, 0 }, { rest[2]:GetPoint(1) })
        -- The row is as wide as its own buttons, the pinned one not among them.
        local row = #rest * style.HEADER_BUTTON + (#rest - 1) * style.HEADER_BUTTON_GAP
        assert.are.equal(row, bag:headerButtonsWidth())
      end)
    end)

    it("shows a button's tooltip away from the panel, beside the strip", function()
      local bag, bank = nextBag:Create(ctx()), nextBank:Create(ctx())
      apply({ Header = { Buttons = { Rail = RAIL } } })
      bag.settingsButton:GetScript("OnEnter")(bag.settingsButton)
      assert.are.equal("ANCHOR_LEFT", GameTooltip._anchor)
      bank.closeButton:GetScript("OnEnter")(bank.closeButton)
      assert.are.equal("ANCHOR_RIGHT", GameTooltip._anchor)
      backToDefault()
      bag.settingsButton:GetScript("OnEnter")(bag.settingsButton)
      assert.are.equal("ANCHOR_BOTTOMLEFT", GameTooltip._anchor)
    end)
  end)

  describe("the search box", function()
    -- Blizzard's magnifier is gray only while the box is empty and not typed in, white while it holds a search or is
    -- typed in (SearchBoxTemplate_OnEditFocusLost and OnEditFocusGained, InputBoxTemplates.lua).
    it("draws its magnifier in ActiveColor while it holds a search", function()
      local bag = nextBag:Create(ctx())
      apply({ Palette = { Gray = { 0.6, 0.6, 0.6, 1 } },
        Search = { Icon = { Color = "Gray", Idle = 1, Active = 1, FocusColor = "White", ActiveColor = "White" } } })
      local t = bag.searchBox.textBox
      local icon = t.searchIcon
      assert.are.same({ 0.6, 0.6, 0.6, 1 }, { icon:GetVertexColor() }, "idle")
      t:GetScript("OnEnter")(t)
      assert.are.same({ 0.6, 0.6, 0.6, 1 }, { icon:GetVertexColor() }, "under the pointer, empty")
      t:GetScript("OnLeave")(t)
      t:SetText("potion")
      t:GetScript("OnTextChanged")(t)
      assert.are.same({ 1, 1, 1, 1 }, { icon:GetVertexColor() }, "holding a search")
      t:GetScript("OnEnter")(t)
      assert.are.same({ 1, 1, 1, 1 }, { icon:GetVertexColor() }, "holding a search, under the pointer")
      t:GetScript("OnLeave")(t)
      t:SetText("")
      t:GetScript("OnTextChanged")(t)
      assert.are.same({ 0.6, 0.6, 0.6, 1 }, { icon:GetVertexColor() }, "empty again")
    end)

    -- The Plain theme (docs/next-plain-theme.md): Blizzard's own bag search box (BagSearchBoxTemplate's border,
    -- InputBoxVisualTemplate), not Next's fill and edges.
    it("keeps its template's own border for a theme that says so, and Next's look for one that does not", function()
      local bag = nextBag:Create(ctx())
      apply({ Search = { Template = true } })
      local t = bag.searchBox.textBox
      for _, key in ipairs({ "Left", "Middle", "Right" }) do
        assert.are.equal(1, t[key]:GetAlpha(), key)
      end
      assert.is_false(bag.searchFill:IsShown())
      for _, edge in ipairs(bag.searchEdges) do
        assert.is_false(edge:IsShown())
      end
      t:GetScript("OnEditFocusGained")(t)
      assert.is_false(bag.searchFill:IsShown(), "focused too")
      t:GetScript("OnEditFocusLost")(t)
      backToDefault()
      for _, key in ipairs({ "Left", "Middle", "Right" }) do
        assert.are.equal(0, t[key]:GetAlpha(), key)
      end
      assert.is_true(bag.searchFill:IsShown())
      assert.is_true(bag.searchEdges[1]:IsShown())
    end)

    -- SearchBoxTemplate's insides (InputBoxTemplates.xml, every client): the magnifier 10 x 10 at LEFT 1, -1, the help and
    -- what is typed 16 in and 20 from the right (TextInsets; Instructions at 16, 0 to -20, 0), the clear button at
    -- RIGHT -3; and the box where the original BetterBags put it (sonata/themes/base.lua: 20 in, 10 from the right),
    -- mirrored on the bank. Reported in game: "search box is completely off" (docs/next-plain-theme.md, round two).
    it("sits Inset in from its body's sides and lays its insides out as its theme says", function()
      local bag, bank = nextBag:Create(ctx()), nextBank:Create(ctx())
      apply({ Layout = { SearchTop = 30, SearchHeight = 20 }, Search = { Template = true, Inset = { Left = 20, Right = 10 },
        Inner = { IconX = 1, IconY = -1, IconSize = 10, TextLeft = 16, TextRight = 20, ClearRight = 3 },
        HelpColor = { 0.35, 0.35, 0.35, 1 } } })
      local frame = bag.searchBox.frame
      assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", 20, -30 }, { frame:GetPoint(1) })
      assert.are.same({ "TOPRIGHT", bag.body, "TOPRIGHT", -10, -30 }, { frame:GetPoint(2) })
      assert.are.same({ "TOPLEFT", bank.body, "TOPLEFT", 10, -30 }, { bank.searchBox.frame:GetPoint(1) }, "its sides swapped on the bank")
      local t = bag.searchBox.textBox
      assert.are.same({ 10, 10 }, { t.searchIcon:GetSize() })
      assert.are.same({ "LEFT", t, "LEFT", 1, -1 }, { t.searchIcon:GetPoint(1) })
      assert.are.same({ 16 + TEXT, 20 - TEXT, -TEXT, TEXT }, { t:GetTextInsets() })
      assert.are.same({ "TOPLEFT", t, "TOPLEFT", 16 + TEXT, TEXT }, { t.Instructions:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", t, "BOTTOMRIGHT", -20 + TEXT, TEXT }, { t.Instructions:GetPoint(2) })
      assert.are.same("MIDDLE", t.Instructions:GetJustifyV())
      assert.are.same({ "RIGHT", t, "RIGHT", -3, 0 }, { t.clearButton:GetPoint(1) })
      -- InputBoxInstructionsTemplate's own color for its help (its XML <Color>), over the role's.
      assert.are.same({ 0.35, 0.35, 0.35, 1 }, { t.Instructions:GetTextColor() })
      backToDefault()
      assert.are.same(style.Color.Muted, { t.Instructions:GetTextColor() }, "the role's again")
      assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", style.PAD, -style.SEARCH_TOP }, { frame:GetPoint(1) }, "back to its pads")
      assert.are.equal("TOPLEFT", (t.searchIcon:GetPoint(1)), "Next's own layout again")
    end)

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
    -- GW2_UI's search bar art (bag\\bagsearchbg.png).
    it("fills the box with art when its fills are art, focused too, and with a color after", function()
      local bag = nextBag:Create(ctx())
      apply({ Search = { Fill = { Texture = "Interface\\Spec\\search.png", Color = "White" },
        FocusFill = { Texture = "Interface\\Spec\\search-focus.png", Color = "White" } } })
      assert.are.equal("Interface\\Spec\\search.png", bag.searchFill:GetTexture())
      bag.searchBox.textBox:SetFocus()
      bag:UpdateSearchLook(true)
      assert.are.equal("Interface\\Spec\\search-focus.png", bag.searchFill:GetTexture())
      bag.searchBox.textBox:ClearFocus()
      backToDefault()
      bag:UpdateSearchLook(true)
      assert.is_nil(bag.searchFill:GetTexture())
      assert.are.same(style.Color.SearchFill, { bag.searchFill:GetVertexColor() })
    end)

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

    it("draws its line in art when it names some, mirrored on the panels on the right, and a color after", function()
      local bag, bank = nextBag:Create(ctx()), nextBank:Create(ctx())
      apply({ Footer = { Line = { Texture = "Interface\\Spec\\sep.png", TexCoords = { 0, 1, 0, 0.5 }, Size = 3 } } })
      assert.are.equal("Interface\\Spec\\sep.png", bag.footerLine:GetTexture())
      assert.is_nil(bag.footerLine._gradient)
      assert.are.equal(3, bag.footerLine:GetHeight())
      local ulx, uly, _, lly, urx = bag.footerLine:GetTexCoord()
      assert.are.same({ 0, 1, 0, 0.5 }, { ulx, urx, uly, lly })
      ulx, uly, _, lly, urx = bank.footerLine:GetTexCoord()
      assert.are.same({ 1, 0, 0, 0.5 }, { ulx, urx, uly, lly })
      backToDefault()
      assert.is_nil(bag.footerLine:GetTexture())
      assert.is_not_nil(bag.footerLine._gradient)
    end)

    it("lays its content out between its header and footer, by its layout", function()
      local bag = nextBag:Create(ctx())
      apply({ Layout = { Pad = 10, ContentTop = 120, Footer = 50, FooterText = 20 } })
      local scroll = bag.scroll.frame
      assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT", 10, -120 }, { scroll:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", bag.body, "BOTTOMRIGHT", -10, 50 }, { scroll:GetPoint(2) })
      assert.are.same({ "BOTTOMLEFT", bag.body, "BOTTOMLEFT", 10 + style.TITLE_INSET + TEXT, 20 + TEXT }, { bag.freeText:GetPoint(1) })
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

  -- A theme's ornaments (Panel.Ornaments, next-themes.md §12) on the real panels: drawn for an inner side on the
  -- left, mirrored on the bank (its inner side is on the right), at their size, moving only while the panel shows.
  describe("ornaments", function()
    local LEAF = "Interface\\AddOns\\BetterBags\\textures\\next\\themes\\spec\\leaf.png"
    local function withOrnaments()
      apply({ Textures = { Leaf = LEAF }, Panel = { Ornaments = {
        { Texture = "Leaf", Point = "INNER", Width = 12, Tile = 40 },
        { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10, Motion = { Sway = 4, Period = 3 } },
        { Texture = "Leaf", Point = "TOPOUTER", Width = 10, Height = 10, Sizes = "Small" },
      } } })
    end

    it("draws a theme's ornaments on every panel's body, mirrored on the bank, and none in Default", function()
      local bag, bank = nextBag:Create(ctx()), nextBank:Create(ctx())
      withOrnaments()
      local roots = bag.ornaments.pieces[1].texture
      assert.are.equal(LEAF, roots:GetTexture())
      local point, rel, relPoint = roots:GetPoint(1)
      assert.are.same({ "TOPLEFT", bag.body, "TOPLEFT" }, { point, rel, relPoint }, "the backpack's inner side: left")
      point, rel, relPoint = bank.ornaments.pieces[1].texture:GetPoint(1)
      assert.are.same({ "TOPRIGHT", bank.body, "TOPRIGHT" }, { point, rel, relPoint }, "the bank's: right")
      assert.are.equal(bag.frame, roots:GetParent())
      backToDefault()
      assert.is_false(roots:IsShown())
    end)

    it("moves them only while the panel shows, through a theme applied meanwhile", function()
      withOrnaments()
      local bag = nextBag:Create(ctx())
      local sway = bag.ornaments.pieces[2].groups.Sway
      assert.is_false(sway:IsPlaying(), "hidden")
      bag:Show(ctx())
      finishTweens()
      assert.is_true(sway:IsPlaying(), "shown")
      withOrnaments()
      assert.is_true(bag.ornaments.pieces[2].groups.Sway:IsPlaying(), "a theme applied while it shows")
      bag:Hide(ctx())
      finishTweens()
      -- The client runs a frame's OnHide as it hides; the mock does not.
      bag.frame:GetScript("OnHide")(bag.frame)
      assert.is_false(bag.ornaments.pieces[2].groups.Sway:IsPlaying(), "hidden again")
    end)

    it("shows each at its size, switching with the panel", function()
      withOrnaments()
      local bag = opened(function(c) return nextBag:Create(c) end)
      local smallOnly = bag.ornaments.pieces[3].texture
      assert.is_false(smallOnly:IsShown())
      addon:GetModule("NextPanel"):SetSize(ctx(), "small")
      finishTweens()
      assert.is_true(bag:IsSmall())
      assert.is_true(smallOnly:IsShown())
      assert.is_true(bag.ornaments.pieces[2].groups.Sway:IsPlaying(), "still moving")
    end)

    it("leaves its moving ones out of the pixel checks", function()
      withOrnaments()
      local bag = opened(function(c) return nextBag:Create(c) end)
      local skip = bag:MovingParts()
      assert.is_true(skip[bag.ornaments.pieces[2].texture])
      assert.is_nil(skip[bag.ornaments.pieces[1].texture])
    end)
  end)

  -- Appearance > Animation (next-themes.md §20): each switch turned off takes its effect away on an open bag at once,
  -- whatever the theme, and turned on brings it back; no font object is made anew.
  describe("the Animation switches", function()
    local function switch(name, on)
      db.animation[name] = on
      sonataNext:ApplyAnimation(ctx())
    end

    it("stops every sparkle on an open bag, and starts them again", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      local font = bag.title:GetFontObject()
      assert.is_not_nil(bag.sparkles.frame:GetScript("OnUpdate"))
      switch("sparkles", false)
      for _, key in ipairs({ "sparkles", "edgeSparkles", "cloudSparkles", "knotSparkles" }) do
        assert.is_nil(bag[key].frame:GetScript("OnUpdate"), key)
        assert.are.equal(0, #bag[key].alive, key)
      end
      bag.knotSparkles:Burst(5)
      assert.are.equal(0, #bag.knotSparkles.alive, "nor from the knot")
      assert.are.equal(font, bag.title:GetFontObject(), "the same font objects")
      switch("sparkles", true)
      for _, key in ipairs({ "sparkles", "edgeSparkles", "cloudSparkles" }) do
        assert.is_not_nil(bag[key].frame:GetScript("OnUpdate"), key .. " again")
      end
    end)

    it("keeps them off through a theme applied, and on a bag made later", function()
      switch("sparkles", false)
      apply({ Palette = { Gold = { 1, 0.5, 0, 1 } } })
      local bag = opened(function(c) return nextBag:Create(c) end)
      assert.is_nil(bag.sparkles.frame:GetScript("OnUpdate"))
    end)

    it("stops the title's shimmer and brings it back", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      assert.is_true(bag.spark:IsShown())
      switch("shimmer", false)
      assert.is_false(bag.spark:IsShown())
      assert.is_false(tween:IsPlaying(bag.spark))
      switch("shimmer", true)
      assert.is_true(bag.spark:IsShown())
      assert.is_true(tween:IsPlaying(bag.spark), "gliding again")
    end)

    -- Reported: "turning off title shimmer causes the background behind the word Backpack to BLIND ME". Turned off,
    -- the shimmer settled the cloud's swell before the cloud's new puffs were laid out: drawing them failed (each
    -- widget restyles in a protected call, so silently), and the cloud's driver failed every frame after, leaving the
    -- puffs at full strength, added as light. No shipped theme has a cloud without a spark.
    it("leaves the title's cloud breathing at its own strength when the shimmer is turned off", function()
      local errors = {}
      override(_G, "geterrorhandler", function() return function(e) table.insert(errors, tostring(e)) end end)
      local bag = opened(function(c) return nextBag:Create(c) end)
      switch("shimmer", false)
      bag.cloud.driver:GetScript("OnUpdate")(bag.cloud.driver, 0.1)
      assert.are.same({}, errors)
      local C = style.Cloud
      assert.is_true(#bag.cloud.puffs > 0)
      for i, puff in ipairs(bag.cloud.puffs) do
        assert.is_true(puff.texture:GetAlpha() <= C.Puffs[i].A * (1 + C.Depth) + 1e-6, "puff " .. i .. " as it breathes")
      end
    end)

    it("settles a cloud the shimmer was swelling when the shimmer is turned off", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      bag:SetCloudSwell(1)
      switch("shimmer", false)
      assert.are.equal(0, bag.cloud.swell)
      assert.are.equal(style.Cloud.Join.A, bag.cloud.join:GetAlpha(), "the join's puff at its own strength")
    end)

    -- Every combination of the switches on an open bag draws without an error, every frame: each switch takes a
    -- part away that some theme leaves out, but not every theme leaves out the same ones together.
    it("draws an open bag under every combination of the switches, without an error", function()
      local errors = {}
      override(_G, "geterrorhandler", function() return function(e) table.insert(errors, tostring(e)) end end)
      local bag = opened(function(c) return nextBag:Create(c) end)
      local names = { "sparkles", "shimmer", "titleCloud", "ribbon", "braid", "ornaments" }
      for mask = 0, 2 ^ #names - 1 do
        for i, name in ipairs(names) do
          db.animation[name] = math.floor(mask / 2 ^ (i - 1)) % 2 == 0
        end
        sonataNext:ApplyAnimation(ctx())
        bag.cloud.driver:GetScript("OnUpdate")(bag.cloud.driver, 0.1)
        assert.are.same({}, errors, "mask " .. mask)
      end
    end)

    -- Asked: "can we have another option to turn off the spike that comes off of the bag?" (the ribbon).
    it("takes the title's ribbon away and brings it back", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      assert.is_true(#bag.ribbonLines > 0)
      switch("ribbon", false)
      assert.are.equal(0, #bag.ribbonLines)
      for _, line in ipairs(bag.ribbonPool) do assert.is_false(line:IsShown()) end
      assert.is_true(#bag.cloud.puffs > 0, "the cloud stays")
      switch("ribbon", true)
      assert.is_true(#bag.ribbonLines > 0)
      assert.is_true(bag.ribbonLines[1]:IsShown())
    end)

    it("takes the title's cloud away and brings it back", function()
      local bag = opened(function(c) return nextBag:Create(c) end)
      assert.is_true(#bag.cloud.puffs > 0)
      switch("titleCloud", false)
      assert.are.equal(0, #bag.cloud.puffs)
      for _, puff in ipairs(bag.cloud.pool) do assert.is_false(puff:IsShown()) end
      assert.is_false(bag.cloud.join:IsShown())
      assert.is_true(bag.ribbon:IsShown(), "the ribbon stays")
      switch("titleCloud", true)
      assert.is_true(#bag.cloud.puffs > 0)
    end)

    it("leaves a coupled pair's ribbons apart, and twists them again", function()
      local bag = nextBag:Create(ctx())
      bag:SetCoupling(1, 100, true, 0, 0, 120)
      assert.is_true(bag.braid.strands[1][1]:IsShown())
      switch("braid", false)
      bag:SetCoupling(1, 100, true, 0, 0, 120)
      for _, strand in ipairs(bag.braid.strands) do
        for _, line in ipairs(strand) do assert.is_false(line:IsShown()) end
      end
      switch("braid", true)
      bag:SetCoupling(1, 100, true, 0, 0, 120)
      assert.is_true(bag.braid.strands[1][1]:IsShown())
    end)

    it("stills a theme's moving ornaments, keeping their art, and moves them again", function()
      apply({ Textures = { Leaf = "Interface\\AddOns\\BetterBags\\textures\\next\\themes\\spec\\leaf.png" },
        Panel = { Ornaments = { { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10, Motion = { Sway = 4 } } } } })
      local bag = opened(function(c) return nextBag:Create(c) end)
      local piece = bag.ornaments.pieces[1]
      assert.is_true(piece.groups.Sway:IsPlaying())
      switch("ornaments", false)
      piece = bag.ornaments.pieces[1]
      assert.is_true(piece.groups.Sway == nil or not piece.groups.Sway:IsPlaying(), "still")
      assert.is_true(piece.texture:IsShown(), "its art stays")
      assert.is_nil(bag:MovingParts()[piece.texture], "no longer left out of the pixel checks")
      switch("ornaments", true)
      assert.is_true(bag.ornaments.pieces[1].groups.Sway:IsPlaying(), "moving again")
    end)
  end)

  -- Every theme BetterBags ships, applied in turn to open bags at both sizes, draws without an error
  -- (SonataNext reports a widget's failure to the error handler and carries on).
  describe("every shipped theme", function()
    it("applies to open, drawn bags at both sizes, in turn, and back to Default", function()
      local errors = {}
      override(_G, "geterrorhandler", function() return function(e) table.insert(errors, tostring(e)) end end)
      -- Guild Wars 2 is offered while GW2_UI is loaded.
      override(_G, "_loadedAddOns", { GW2_UI = true })
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
