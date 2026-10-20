-- drag_spec.lua -- NextDrag (next/drag.lua): moving sections by their headers (next.md §7). A section
-- is picked up with its real item buttons and follows the cursor; the other sections slide out of
-- its way; dropping it reorders it (saving its place), moves it to a tab, or moves its items to the
-- other bag, on the real backpack and bank panels.
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
  guildBank = trackStub("GuildBank"),
  question = trackStub("Question"),
  color = trackStub("Color"),
  elements = trackStub("SonataElements"),
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
  { "NextDrag", "next/drag.lua" }, { "NextChain", "next/chain.lua" }, { "NextPanel", "next/panel.lua" }, { "NextBag", "next/bag.lua" },
  { "NextBank", "next/bank.lua" }, { "NextGuildButton", "next/guildbutton.lua" }, { "NextGuildBank", "next/guildbank.lua" } }
for _, m in ipairs(modules) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local nextBag = addon:GetModule("NextBag")
local nextBank = addon:GetModule("NextBank")
local nextGuildBank = addon:GetModule("NextGuildBank")
local nextDrag = addon:GetModule("NextDrag")
local style = addon:GetModule("NextStyle")
local tween = addon:GetModule("NextTween")
local render = addon:GetModule("Render")
local motion = addon:GetModule("Motion")
local context = addon:GetModule("Context")

local CHAR, ACCOUNT = 1, 2
local SECTION_GRID, SECTION_ALL_BAGS = 2, 4
-- The canvas's top on screen, below each panel's header.
local CANVAS_TOP = 1090

describe("NextDrag", function()
  local buttons, sent, pins, db, backpackGroups, bankGroups, slots, calls, backpack, bank, guild

  -- An item button: a holder frame and, inside it, the button the player clicks. Like Blizzard's
  -- (ContainerFrameItemButtonMixin:OnReceiveDrag calls OnDragStart, which is a left click), a drag
  -- released over that button picks its item up.
  local function fakeButton(slotkey)
    local b = { slotkey = slotkey, frame = CreateFrame("Frame") }
    b.frame:SetSize(37, 37)
    b.button = CreateFrame("Button", nil, b.frame)
    b.button:SetScript("OnReceiveDrag", function()
      table.insert(calls.pickedUp, slotkey)
    end)
    function b:SetItemFromData(_, data) self.data = data self.isFreeSlot = false end
    function b:SetFreeSlots(_, data) self.data = data self.isFreeSlot = true end
    function b:SetSize(_, w, h) self.frame:SetSize(w, h) end
    function b:GetItemData() return self.data end
    function b:UpdateSearch() end
    function b:UpdateCooldown() return "unchanged" end
    function b:Release() end
    return b
  end

  local function item(slotkey, category)
    local bag, slot = slotkey:match("^(%-?%d+)_(%d+)$")
    return { slotkey = slotkey, bagid = tonumber(bag), slotid = tonumber(slot), itemInfo = { category = category } }
  end

  local function tab(names, items)
    local categories = {}
    for _, n in ipairs(names) do table.insert(categories, { name = n }) end
    return { categories = categories, items = items }
  end

  local function backpackData()
    return {
      sortedItems = { item("0_9", "Recent Items") },
      tabs = {
        [1] = tab({ "Armor", "Cloth", "Herbs", "Ore" }, {
          item("0_1", "Armor"), item("0_2", "Cloth"), item("0_3", "Herbs"), item("0_4", "Herbs"), item("0_5", "Ore"),
        }),
        [2] = tab({ "Gems" }, { item("0_6", "Gems") }),
      },
    }
  end

  local function bankData()
    return {
      sortedItems = {},
      tabs = {
        [10] = tab({ "Leather", "Mail" }, { item("6_1", "Leather"), item("6_2", "Mail") }),
        [11] = tab({ "Potions" }, { item("12_1", "Potions") }),
        [12] = tab({ "Gold" }, { item("6_3", "Gold") }),
      },
    }
  end

  local function ctx() return context:New("spec") end

  local function finishTweens()
    for _ = 1, 400 do
      local update = tween.driver and tween.driver:GetScript("OnUpdate")
      if update == nil then return end
      update(tween.driver, 0.05)
    end
  end

  local function cursor(x, y)
    _G._cursorX, _G._cursorY = x, y
  end

  -- layout puts a panel's frames where the client would: the canvas below the header, each
  -- section where the canvas laid it out, the tabs down the rail, the scroll area.
  local function layout(panel)
    local left = panel.side == "LEFT" and 0 or (1920 - style.WIDTH)
    local bodyLeft = panel.side == "LEFT" and left or (left + style.FEATHER)
    panel.body:_SetRect(bodyLeft, 0, style.BODY_WIDTH, 1200)
    panel.scroll.frame:_SetRect(bodyLeft + style.PAD, style.FOOTER, style.BODY_WIDTH - 2 * style.PAD,
      1200 - style.CONTENT_TOP - style.FOOTER)
    local canvas = panel.content.frame
    local height = canvas:GetHeight()
    canvas:_SetRect(bodyLeft + style.PAD + 14, CANVAS_TOP - height, style.GRID_WIDTH, height)
    for _, section in ipairs(panel.content.order) do
      if section.frame:GetParent() == canvas then
        section.frame:_SetRect(bodyLeft + style.PAD + 14, CANVAS_TOP - section.y - section.height,
          style.GRID_WIDTH, section.height)
      end
    end
    local tabLeft = panel.side == "LEFT" and (bodyLeft + style.BODY_WIDTH) or (bodyLeft - 100)
    for i, t in ipairs(panel.tabs.tabs) do
      t.button:_SetRect(tabLeft, CANVAS_TOP - i * (style.TAB_HEIGHT + style.TAB_SPACING), 100, style.TAB_HEIGHT)
    end
  end

  local function flush()
    render:Flush()
    motion:Step(1)
    layout(backpack)
    if bank then layout(bank) end
    if guild then layout(guild) end
  end

  local function section(panel, name)
    return panel.content.byName[name]
  end

  local function sectionNames(panel)
    local out = {}
    for _, s in ipairs(panel.content.order) do table.insert(out, s.name) end
    return out
  end

  local function sentNamed(name)
    local out = {}
    for _, m in ipairs(sent) do
      if m[1] == name then table.insert(out, m[2]) end
    end
    return out
  end

  -- pickUp presses on a section's header at a point inside it and drags.
  local function pickUp(panel, name, dx, dy)
    local s = section(panel, name)
    cursor(s.frame:GetLeft() + (dx or 20), s.frame:GetTop() - (dy or 10))
    _G._mouseButtonsDown = { LeftButton = true }
    s.header:GetScript("OnDragStart")(s.header)
    return s
  end

  local function moveTo(x, y)
    cursor(x, y)
    nextDrag:Update(0.016)
  end

  local function drop(s)
    _G._mouseButtonsDown = nil
    s.header:GetScript("OnDragStop")(s.header)
  end

  local function centerOf(frame)
    local x, y = frame:GetCenter()
    return x, y
  end

  before_each(function()
    render:Init()
    tween:Init()
    motion:Init()
    nextDrag:Init()
    buttons, sent = {}, {}
    pins = {}
    db = { view = { [BACKPACK] = SECTION_GRID, [BANK] = SECTION_GRID }, active = { [BACKPACK] = 1, [BANK] = 10 },
      showBankTabs = false }
    backpackGroups = { [1] = { id = 1, name = "Backpack" }, [2] = { id = 2, name = "Gems" } }
    bankGroups = {
      [10] = { id = 10, name = "Bank", bankType = CHAR, isDefault = true },
      [11] = { id = 11, name = "Warbank", bankType = ACCOUNT, isDefault = true },
      [12] = { id = 12, name = "Vault", bankType = CHAR },
    }
    slots = { [BACKPACK] = backpackData(), [BANK] = bankData() }
    calls = { moved = {}, assigned = {}, scrolled = {}, titleDrops = {}, pickedUp = {}, deposited = {}, withdrawn = {} }
    guild = nil

    override(addon, "isRetail", true)
    override(addon, "isForever", false)
    override(addon, "hasWarbank", true)
    override(addon, "atBank", true)
    override(const, "BANK_TAB", { BANK = -2, ACCOUNT_BANK_1 = 12 })
    override(const, "BAG_VIEW", { SECTION_GRID = SECTION_GRID, SECTION_ALL_BAGS = SECTION_ALL_BAGS })
    override(const, "ACCOUNT_BANK_BAGS", { [12] = 12, [13] = 13 })
    override(Enum.BagIndex, "Characterbanktab", -2)
    override(Enum.BagIndex, "CharacterBankTab_1", 6)
    override(Enum.BagIndex, "AccountBankTab_1", 12)
    UIParent:_SetRect(0, 0, 1920, 1200)

    override(stubs.L, "G", function(_, key) return key end)
    override(stubs.itemFrame, "GetButton", function(_, _, slotkey)
      buttons[slotkey] = buttons[slotkey] or fakeButton(slotkey)
      return buttons[slotkey]
    end)
    override(stubs.items, "GetAllSlotInfo", function() return slots end)
    override(stubs.items, "ExpireRecentItems", function() return false end)
    override(stubs.items, "ClearBankCache", function() end)
    override(stubs.database, "GetGroupsEnabled", function() return true end)
    override(stubs.database, "GetActiveGroup", function(_, kind) return db.active[kind] end)
    override(stubs.database, "SetActiveGroup", function(_, kind, id) db.active[kind] = id end)
    override(stubs.database, "GetNextChain", function() return "apart" end)
    override(stubs.database, "GetNextSize", function() return "full" end)
    override(stubs.database, "GetInBagSearch", function() return true end)
    override(stubs.database, "GetShowBankTabs", function() return db.showBankTabs end)
    override(stubs.database, "SetShowBankTabs", function(_, on) db.showBankTabs = on end)
    override(stubs.database, "GetBagView", function(_, kind) return db.view[kind] end)
    override(stubs.database, "SetBagView", function(_, kind, view) db.view[kind] = view end)
    override(stubs.database, "GetPreviousView", function() return SECTION_GRID end)
    override(stubs.database, "SetPreviousView", function() end)
    override(stubs.database, "GetCustomSectionSort", function(_, kind)
      pins[kind] = pins[kind] or {}
      return pins[kind]
    end)
    override(stubs.database, "SetCustomSectionSort", function(_, kind, name, index)
      pins[kind] = pins[kind] or {}
      pins[kind][name] = index
    end)
    override(stubs.groups, "GetAllGroups", function(_, kind) return kind == BANK and bankGroups or backpackGroups end)
    override(stubs.groups, "GetGroup", function(_, kind, id) return (kind == BANK and bankGroups or backpackGroups)[id] end)
    override(stubs.groups, "IsDefaultGroup", function(_, kind, id)
      local g = (kind == BANK and bankGroups or backpackGroups)[id]
      return g ~= nil and (g.isDefault == true or (kind == BACKPACK and id == 1))
    end)
    override(stubs.groups, "GetDefaultBankGroup", function() return bankGroups[10] end)
    override(stubs.groups, "AssignCategoryToGroup", function(_, c, kind, name, id, bankType)
      assert.is_not_nil(c)
      table.insert(calls.assigned, { kind, name, id, bankType })
    end)
    override(stubs.events, "SendMessage", function(_, _, name, opts) table.insert(sent, { name, opts }) end)
    override(stubs.events, "RegisterMessage", function() end)
    override(stubs.events, "RegisterEvent", function() end)
    override(stubs.events, "BucketEvent", function() end)
    override(stubs.searchBox, "CreateBox", function(_, kind, parent)
      local box = { kind = kind, frame = CreateFrame("Frame", nil, parent) }
      -- As searchBox:CreateBox makes it (frames/search.lua): a BagSearchBoxTemplate edit box.
      box.textBox = CreateFrame("EditBox", nil, box.frame, "BagSearchBoxTemplate")
      box.helpText = box.textBox.Instructions
      return box
    end)
    override(stubs.sonata, "UnregisterElement", function() end)
    override(stubs.money, "Create", function()
      return { frame = CreateFrame("Frame"), Update = function() end }
    end)
    override(stubs.cursorPlacement, "PlaceCursorItem", function() return "placed" end)
    override(stubs.backpackBehavior, "Create", function() return {} end)
    override(stubs.bankBehavior, "SuppressBlizzardBankPanel", function() end)
    override(stubs.bankBehavior, "proto", { UpdatePurchaseBankButton = function() end })
    override(stubs.bankSlots, "GetBagSocketIndex", function() return nil end)
    override(stubs.sectionFrame, "MoveItems", function(_, list, bankType)
      local keys = {}
      for _, data in ipairs(list) do table.insert(keys, data.slotkey) end
      table.insert(calls.moved, { keys, bankType })
    end)
    override(stubs.sectionFrame, "OnTitleClickOrDrop", function(_, c, adapter)
      assert.is_not_nil(c)
      table.insert(calls.titleDrops, { adapter:GetKind(), adapter:GetTitle() })
    end)
    override(C_Bank, "FetchPurchasedBankTabData", function(bankType)
      if bankType == CHAR then return { { ID = 6, name = "Base", icon = 1 } } end
      return { { ID = 12, name = "Shared", icon = 2 } }
    end)
    override(C_Bank, "FetchNextPurchasableBankTabData", function() return nil end)
    override(C_Bank, "CloseBankFrame", function() end)
    override(C_Container, "SortBankBags", function() end)
    override(addon, "SetBlizzardBankType", function() end)
    override(addon, "TriggerItemContextChanged", function() end)
    override(addon, "ForceHideBlizzardBags", function() end)
    override(_G, "PlaySound", function() end)
    override(_G, "InCombatLockdown", function() return false end)
    _G._cursorHasItem = false

    backpack = nextBag:Create(ctx())
    bank = nextBank:Create(ctx())
    for _, panel in ipairs({ backpack, bank }) do
      panel:Show(ctx())
      panel:Draw(ctx(), slots[panel.kind], function() end)
    end
    finishTweens()
    flush()
    -- Every other test starts with the scroll area unscrolled.
    for _, panel in ipairs({ backpack, bank }) do
      local box = panel.scroll.scrollBox
      box._scrollRange, box._scrollPercentage = 500, 0
    end
  end)

  after_each(function()
    nextDrag:Cancel()
    restore()
    _G._cursorX, _G._cursorY = 0, 0
    _G._cursorHasItem = false
    _G._mouseButtonsDown = nil
  end)

  teardown(function()
    UseNextTheme(nil)
    for i = #modules, 1, -1 do ResetModuleStub(modules[i][1]) end
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  describe("picking up", function()
    it("lifts the real section, with its item buttons, into the drag layer where it was", function()
      local herbs = section(backpack, "Herbs")
      local left, top = herbs.frame:GetLeft(), herbs.frame:GetTop()
      pickUp(backpack, "Herbs")
      assert.are.equal(nextDrag.layer, herbs.frame:GetParent())
      assert.are.equal("TOOLTIP", herbs.frame:GetFrameStrata())
      assert.are.equal(herbs.cells, buttons["0_3"].frame:GetParent(), "its buttons come with it")
      assert.are.same({ "TOPLEFT", UIParent, "BOTTOMLEFT", left, top }, { herbs.frame:GetPoint(1) })
      assert.is_true(nextDrag.shadow:IsShown())
    end)

    -- A Next theme (next-themes.md) draws the lift: its scale, the shadow and the hint's role.
    it("lifts by the theme's scale, with its shadow, naming the drop in its role", function()
      UseNextTheme({ Fonts = { Hint = { Size = 10 } },
        Drag = { LiftScale = 0.8, Shadow = { Color = "Gold", Alpha = 0.5, Spread = 4 }, HintFont = "Hint" } })
      nextDrag:ApplyStyle(context:New("spec"))
      local herbs = pickUp(backpack, "Herbs")
      finishTweens()
      assert.are.equal(0.8, nextDrag.current.scale)
      assert.are.equal(0.5, nextDrag.shadow:GetAlpha())
      local c = nextDrag.shadow._colorTexture
      assert.are.same({ 1, 0.84, 0.5, 1 }, { c.r, c.g, c.b, c.a })
      assert.are.same({ "TOPLEFT", herbs.frame, "TOPLEFT", -4, 4 }, { nextDrag.shadow:GetPoint(1) })
      assert.are.equal(style:Font("Hint"), nextDrag.hint:GetFontObject())
      UseNextTheme(nil)
      nextDrag:ApplyStyle(context:New("spec"))
      assert.are.same(style.Color.Black, { nextDrag.shadow._colorTexture.r, nextDrag.shadow._colorTexture.g,
        nextDrag.shadow._colorTexture.b, nextDrag.shadow._colorTexture.a }, "restyled while lifted")
      drop(herbs)
      finishTweens()
    end)

    it("shrinks a little around the point that was grabbed, which stays under the cursor", function()
      local herbs = pickUp(backpack, "Herbs", 30, 12)
      local cx, cy = _G._cursorX, _G._cursorY
      finishTweens()
      local s = herbs.frame:GetScale()
      assert.are.equal(0.94, s)
      local _, _, _, ox, oy = herbs.frame:GetPoint(1)
      assert.is_true(math.abs((ox * s + 30 * s) - cx) < 1e-6, "the grabbed point's x")
      assert.is_true(math.abs((oy * s - 12 * s) - cy) < 1e-6, "the grabbed point's y")
    end)

    it("keeps a gap where it was, so nothing moves until the cursor does", function()
      local ore = section(backpack, "Ore")
      pickUp(backpack, "Herbs")
      render:Flush()
      assert.is_nil(motion:GetMove(ore.frame))
    end)

    it("picks up only categories, never in the Show Bags view, and one section at a time", function()
      pickUp(backpack, "Recent Items")
      assert.is_false(nextDrag:IsActive())
      db.view[BACKPACK] = SECTION_ALL_BAGS
      pickUp(backpack, "Herbs")
      assert.is_false(nextDrag:IsActive())
      db.view[BACKPACK] = SECTION_GRID
      pickUp(backpack, "Herbs")
      assert.is_true(nextDrag:IsActive())
      local cloth = section(backpack, "Cloth")
      cloth.header:GetScript("OnDragStart")(cloth.header)
      assert.are.equal(backpack.content.frame, cloth.frame:GetParent())
    end)

    it("follows the cursor", function()
      local herbs = pickUp(backpack, "Herbs", 20, 10)
      finishTweens()
      moveTo(1300, 600)
      local s = herbs.frame:GetScale()
      local _, _, _, ox, oy = herbs.frame:GetPoint(1)
      assert.is_true(math.abs(ox * s - (1300 - 20 * s)) < 1e-6)
      assert.is_true(math.abs(oy * s - (600 + 10 * s)) < 1e-6)
    end)
  end)

  describe("making room", function()
    it("moves the gap under the cursor, the other sections sliding out of its way", function()
      local armor = section(backpack, "Armor")
      local herbs = pickUp(backpack, "Herbs")
      -- A frame passes between the pickup and the cursor moving.
      render:Flush()
      local x = herbs.frame:GetLeft() + 20
      -- Above Armor's middle: the gap goes first among the categories (Recent Items stays first).
      moveTo(x, armor.frame:GetTop() - 5)
      assert.are.equal(2, backpack.content.drag.index)
      render:Flush()
      local _, y0, _, y1 = motion:GetMove(armor.frame)
      assert.is_true(y1 < y0, "Armor slides down")
    end)

    it("scrolls toward the edge it is held near, faster the closer", function()
      local herbs = pickUp(backpack, "Herbs")
      local box = backpack.scroll.scrollBox
      local x = herbs.frame:GetLeft() + 20
      moveTo(x, style.FOOTER + 30)
      local slow = box:GetDerivedScrollOffset()
      assert.is_true(slow > 0, "scrolls down near the bottom")
      moveTo(x, style.FOOTER + 2)
      assert.is_true(box:GetDerivedScrollOffset() - slow > slow, "faster closer to the edge")
      local before = box:GetDerivedScrollOffset()
      moveTo(x, CANVAS_TOP - 30)
      local up = before - box:GetDerivedScrollOffset()
      assert.is_true(up > 0, "up near the top")
      before = box:GetDerivedScrollOffset()
      moveTo(x, CANVAS_TOP - 3)
      assert.is_true(before - box:GetDerivedScrollOffset() > up, "faster closer to the top")
      before = box:GetDerivedScrollOffset()
      moveTo(x, 600)
      assert.are.equal(before, box:GetDerivedScrollOffset(), "not in the middle")
    end)
  end)

  describe("reordering", function()
    it("drops the section into its gap, saves its place and recalculates the bag", function()
      local armor = section(backpack, "Armor")
      local herbs = pickUp(backpack, "Herbs")
      moveTo(herbs.frame:GetLeft() + 20, armor.frame:GetTop() - 5)
      flush()
      drop(herbs)
      assert.are.same({ Herbs = 0 }, pins[BACKPACK])
      assert.is_true(nextDrag:IsActive(), "still landing")
      finishTweens()
      assert.is_false(nextDrag:IsActive())
      assert.are.equal(backpack.content.frame, herbs.frame:GetParent())
      assert.are.equal(1, herbs.frame:GetScale())
      assert.are.equal(backpack.frame:GetFrameStrata(), herbs.frame:GetFrameStrata())
      assert.is_false(nextDrag.shadow:IsShown())
      assert.are.same({ "Recent Items", "Herbs", "Armor", "Cloth", "Ore" }, sectionNames(backpack))
      assert.are.same({ { backpack = true, bank = false } }, sentNamed("bags/Rederive"))
      render:Flush()
      assert.is_nil(motion:GetMove(herbs.frame), "lands exactly where the canvas puts it")
    end)

    it("starts landing from exactly where it was dropped", function()
      local herbs = pickUp(backpack, "Herbs", 20, 10)
      finishTweens()
      moveTo(1600, 700)
      drop(herbs)
      tween:Step(0.0001)
      local s = herbs.frame:GetScale()
      local _, _, _, ox, oy = herbs.frame:GetPoint(1)
      assert.is_true(math.abs(ox * s - (1600 - 20 * 0.94)) < 2)
      assert.is_true(math.abs(oy * s - (700 + 10 * 0.94)) < 2)
    end)

    it("lands back in its old place when dropped outside after its gap moved", function()
      local armor = section(backpack, "Armor")
      local herbs = pickUp(backpack, "Herbs")
      local oldY = herbs.y
      moveTo(herbs.frame:GetLeft() + 20, armor.frame:GetTop() - 5)
      flush()
      moveTo(900, 600)
      drop(herbs)
      flush()
      finishTweens()
      local _, rel, _, _, y = herbs.frame:GetPoint(1)
      assert.are.equal(backpack.content.frame, rel)
      assert.are.equal(-oldY, y)
    end)

    it("lands back where it was when dropped outside any panel, saving nothing", function()
      local herbs = pickUp(backpack, "Herbs")
      moveTo(900, 600)
      drop(herbs)
      finishTweens()
      assert.are.same({}, pins[BACKPACK] or {})
      assert.are.same({}, sentNamed("bags/Rederive"))
      assert.are.same({ "Recent Items", "Armor", "Cloth", "Herbs", "Ore" }, sectionNames(backpack))
      assert.are.equal(backpack.content.frame, herbs.frame:GetParent())
    end)

    describe("saving the order", function()
      it("pins what comes up to the dropped section, after the pinned list's other entries", function()
        pins[BACKPACK] = { Gems = 0 }
        nextDrag:SaveOrder(BACKPACK, { "Armor", "Herbs", "Cloth", "Ore" }, 2)
        assert.are.same({ Gems = 0, Armor = 1, Herbs = 2 }, pins[BACKPACK])
      end)

      it("keeps the tab's block where its first pinned category was, and other tabs' order", function()
        pins[BACKPACK] = { Gems = 0, Armor = 1, Leather = 2, Cloth = 3 }
        nextDrag:SaveOrder(BACKPACK, { "Herbs", "Armor", "Cloth", "Ore" }, 1)
        assert.are.same({ Gems = 0, Herbs = 1, Armor = 2, Cloth = 3, Leather = 4 }, pins[BACKPACK])
      end)

      it("moves a pinned category down among unpinned ones, leaving the rest to the sort", function()
        pins[BACKPACK] = { Armor = 0, Cloth = 1 }
        nextDrag:SaveOrder(BACKPACK, { "Cloth", "Herbs", "Armor", "Ore" }, 3)
        assert.are.same({ Cloth = 0, Herbs = 1, Armor = 2 }, pins[BACKPACK])
      end)
    end)
  end)

  describe("dropping on a tab of its own bag", function()
    it("lights the tab and names the move, then assigns the category to its group", function()
      local gems = backpack.tabs:Tab(2)
      local herbs = pickUp(backpack, "Herbs")
      moveTo(centerOf(gems.button))
      assert.are.equal(2, backpack.tabs.dropTarget)
      assert.are.equal("Move to Gems", nextDrag.hint:GetText())
      assert.is_true(nextDrag.hint:IsShown())
      drop(herbs)
      assert.are.same({ { BACKPACK, "Herbs", 2 } }, calls.assigned)
      assert.is_nil(backpack.tabs.dropTarget)
    end)

    it("flies into the tab, then leaves the column until it is gone, and the tab pulses", function()
      local gems = backpack.tabs:Tab(2)
      local herbs = pickUp(backpack, "Herbs")
      moveTo(centerOf(gems.button))
      drop(herbs)
      tween:Step(style.Time.FlyAway / 2)
      assert.is_true(herbs.frame:GetScale() < 0.94)
      assert.is_true(herbs.frame:GetAlpha() < 1)
      finishTweens()
      assert.are.equal(backpack.content.frame, herbs.frame:GetParent())
      assert.is_false(herbs.frame:IsShown())
      assert.are.equal(1, herbs.frame:GetScale(), "full size when it comes back")
      assert.is_not_nil(backpack.content.leaving.Herbs)
      assert.are.same({ { backpack = true, bank = false, resetLayout = true } }, sentNamed("bags/Rederive"))
    end)

    it("pulses the tab it flew into", function()
      local gems = backpack.tabs:Tab(2)
      local herbs = pickUp(backpack, "Herbs")
      moveTo(centerOf(gems.button))
      drop(herbs)
      tween:Step(style.Time.FlyAway + 0.001)
      assert.is_true(gems.glow:IsShown())
      assert.is_true(gems.glow:GetAlpha() > 0.5)
    end)

    it("is no target on the tab shown or the tab that makes a group", function()
      local herbs = pickUp(backpack, "Herbs")
      moveTo(centerOf(backpack.tabs:Tab(1).button))
      assert.is_nil(backpack.tabs.dropTarget)
      moveTo(centerOf(backpack.tabs:Tab(0).button))
      assert.is_nil(backpack.tabs.dropTarget)
      assert.is_false(nextDrag.hint:IsShown())
      drop(herbs)
      finishTweens()
      assert.are.same({}, calls.assigned)
    end)

    it("takes a bank category only to a group of the same bank type", function()
      local leather = pickUp(bank, "Leather")
      moveTo(centerOf(bank.tabs:Tab(11).button))
      assert.is_nil(bank.tabs.dropTarget, "the Warbank's group")
      moveTo(centerOf(bank.tabs:Tab(12).button))
      assert.are.equal(12, bank.tabs.dropTarget)
      drop(leather)
      assert.are.same({ { BANK, "Leather", 12 } }, calls.assigned)
    end)
  end)

  describe("dropping on the other bag", function()
    it("moves the section's items to the bank, the bank glowing and the move named", function()
      local herbs = pickUp(backpack, "Herbs")
      moveTo(300, 600)
      assert.is_true(bank.dropGlow:IsShown())
      assert.are.equal("Move to the Bank", nextDrag.hint:GetText())
      drop(herbs)
      assert.are.same({ { { "0_3", "0_4" } } }, calls.moved)
      assert.are.same({}, calls.assigned)
      finishTweens()
      assert.is_false(bank.dropGlow:IsShown())
      assert.is_not_nil(backpack.content.leaving.Herbs)
      assert.is_false(herbs.frame:IsShown())
    end)

    it("names the Warbank while the bank shows it", function()
      bank:SwitchToGroup(ctx(), 11)
      local herbs = pickUp(backpack, "Herbs")
      moveTo(300, 600)
      assert.are.equal("Move to the Warbank", nextDrag.hint:GetText())
      drop(herbs)
    end)

    it("moves into a bank group's bank type and assigns the category to it there", function()
      local herbs = pickUp(backpack, "Herbs")
      moveTo(centerOf(bank.tabs:Tab(11).button))
      assert.are.equal(11, bank.tabs.dropTarget)
      assert.are.equal("Move to Warbank", nextDrag.hint:GetText())
      drop(herbs)
      assert.are.same({ { { "0_3", "0_4" }, ACCOUNT } }, calls.moved)
      assert.are.same({ { BANK, "Herbs", 11, ACCOUNT } }, calls.assigned)
      finishTweens()
      assert.are.same({ { resetLayout = true } }, sentNamed("bags/Rederive"))
    end)

    it("moves bank items to the backpack and assigns the category to a backpack group", function()
      local leather = pickUp(bank, "Leather")
      moveTo(centerOf(backpack.tabs:Tab(2).button))
      drop(leather)
      assert.are.same({ { { "6_1" } } }, calls.moved)
      assert.are.same({ { BACKPACK, "Leather", 2 } }, calls.assigned)
    end)

    it("is no target on a purchase tab", function()
      override(C_Bank, "FetchNextPurchasableBankTabData", function() return { tabCost = 1 } end)
      bank:ToggleBankTabs(ctx())
      flush()
      local herbs = pickUp(backpack, "Herbs")
      moveTo(centerOf(bank.tabs:Tab(-1).button))
      assert.is_nil(bank.tabs.dropTarget)
      drop(herbs)
      assert.are.same({}, calls.moved)
    end)

    it("moves into a Blizzard bank tab's bank type in the bank's Bank Tabs mode", function()
      bank:ToggleBankTabs(ctx())
      bank:Draw(ctx(), slots[BANK], function() end)
      flush()
      local herbs = pickUp(backpack, "Herbs")
      moveTo(centerOf(bank.tabs:Tab(12).button))
      drop(herbs)
      assert.are.same({ { { "0_3", "0_4" }, ACCOUNT } }, calls.moved)
      assert.are.same({}, calls.assigned)
    end)

    it("is no target away from the bank", function()
      override(addon, "atBank", false)
      local herbs = pickUp(backpack, "Herbs")
      moveTo(300, 600)
      assert.is_false(bank.dropGlow:IsShown())
      moveTo(centerOf(bank.tabs:Tab(11).button))
      assert.is_nil(bank.tabs.dropTarget)
      drop(herbs)
      assert.are.same({}, calls.moved)
    end)
  end)

  -- BetterBags Next's guild bank (guild-bank.md §5): at the guild bank, a backpack section dropped on
  -- it is deposited, into the tab it is dropped on or its deposit tab; a guild section dropped on the
  -- backpack is withdrawn. The guild bank's own sections are reordered as any panel's.
  describe("the guild bank", function()
    local GUILD, ALL = 2, 1
    local asked, guildTabs

    local function guildInfo(n, name, opts)
      opts = opts or {}
      return { tab = n, container = 1000 + n, name = name, icon = n, viewable = true,
        canDeposit = opts.canDeposit ~= false, numWithdrawals = opts.numWithdrawals or 5, remainingWithdrawals = 5 }
    end

    local function guildData()
      local ore, cloth = item("1002_4", "Ore"), item("1001_1", "Cloth")
      ore.guildTab, cloth.guildTab = 2, 1
      return { sortedItems = {}, tabs = { [ALL] = tab({ "Cloth", "Ore" }, { cloth, ore }) } }
    end

    before_each(function()
      asked = nil
      guildTabs = { guildInfo(1, "Gear"), guildInfo(2, "Mats"), guildInfo(3, "Locked", { canDeposit = false }),
        guildInfo(4, "Donations", { numWithdrawals = 0 }) }
      override(const, "BAG_KIND", { UNDEFINED = -1, BACKPACK = BACKPACK, BANK = BANK, GUILD = GUILD })
      override(const, "GUILD_BANK_ALL_TAB", ALL)
      override(const, "GUILD_BANK_BAGS", { [1001] = 1, [1002] = 2, [1003] = 3, [1004] = 4 })
      override(const, "BACKPACK_BAGS", { [0] = 0 })
      override(addon, "atBank", false)
      override(addon, "atGuildBank", true)
      db.view[GUILD] = SECTION_GRID
      slots[GUILD] = guildData()
      override(stubs.database, "GetShowGuildBankTabs", function() return false end)
      override(stubs.database, "SetShowGuildBankTabs", function() end)
      override(stubs.guildBank, "Tabs", function() return guildTabs end)
      override(stubs.guildBank, "TabInfo", function(_, n) return guildTabs[n] end)
      override(stubs.guildBank, "TabOf", function(_, container) return const.GUILD_BANK_BAGS[container] end)
      override(stubs.guildBank, "ContainerOf", function(_, n) return 1000 + n end)
      override(stubs.guildBank, "CurrentTab", function() return 2 end)
      override(stubs.guildBank, "CanBuyTab", function() return true end)
      override(stubs.guildBank, "Close", function() end)
      override(stubs.guildBank, "DepositSlots", function(_, list, n)
        local keys = {}
        for _, slot in ipairs(list) do table.insert(keys, slot.bag .. "_" .. slot.slot) end
        table.insert(calls.deposited, { keys, n })
        return #list
      end)
      override(stubs.guildBank, "WithdrawItems", function(_, list)
        local keys = {}
        for _, data in ipairs(list) do table.insert(keys, data.slotkey) end
        table.insert(calls.withdrawn, keys)
        return #list
      end)
      override(stubs.sectionFrame, "WithStacks", function(_, list) return list end)
      override(stubs.question, "YesNo", function(_, title, text, yes) asked = { title = title, text = text, yes = yes } end)
      bank.frame:Hide()
      bank = nil
      guild = nextGuildBank:Create(ctx())
      guild.content:SetButtonSource({
        GetButton = function(_, _, slotkey)
          buttons[slotkey] = buttons[slotkey] or fakeButton(slotkey)
          return buttons[slotkey]
        end,
      })
      guild:Show(ctx())
      guild:Draw(ctx(), slots[GUILD], function() end)
      finishTweens()
      flush()
      guild.scroll.scrollBox._scrollRange, guild.scroll.scrollBox._scrollPercentage = 500, 0
    end)

    it("deposits a backpack section into the guild bank's current tab, the guild bank glowing and the move named", function()
      local herbs = pickUp(backpack, "Herbs")
      moveTo(300, 600)
      assert.is_true(guild.dropGlow:IsShown())
      assert.are.equal("Move to the Guild Bank", nextDrag.hint:GetText())
      drop(herbs)
      assert.are.same({ { { "0_3", "0_4" }, 2 } }, calls.deposited)
      finishTweens()
      assert.is_not_nil(backpack.content.leaving.Herbs)
    end)

    it("deposits into the guild tab it is dropped on, which pulses", function()
      local herbs = pickUp(backpack, "Herbs")
      moveTo(centerOf(guild.tabs:Tab(1001).button))
      assert.are.equal(1001, guild.tabs.dropTarget)
      assert.are.equal("Move to Gear", nextDrag.hint:GetText())
      drop(herbs)
      assert.are.same({ { { "0_3", "0_4" }, 1 } }, calls.deposited)
      assert.are.same({}, calls.assigned)
    end)

    it("is no target on a tab the player may not deposit in, nor All Tabs, nor buying a tab", function()
      local herbs = pickUp(backpack, "Herbs")
      for _, id in ipairs({ 1003, ALL, 0 }) do
        moveTo(centerOf(guild.tabs:Tab(id).button))
        assert.is_nil(guild.tabs.dropTarget)
      end
      drop(herbs)
      assert.are.same({}, calls.deposited)
    end)

    it("is no target when the player may deposit in no tab the guild bank would use", function()
      guildTabs[2].canDeposit = false
      local herbs = pickUp(backpack, "Herbs")
      moveTo(300, 600)
      assert.is_false(guild.dropGlow:IsShown())
      drop(herbs)
      assert.are.same({}, calls.deposited)
    end)

    it("docks a deposit into a tab the player cannot take items back from, and deposits on a double click", function()
      local herbs = pickUp(backpack, "Herbs")
      moveTo(centerOf(guild.tabs:Tab(1004).button))
      drop(herbs)
      finishTweens()
      assert.are.same({}, calls.deposited)
      assert.is_nil(asked, "no dialog")
      local d = nextDrag.dock
      assert.is_true(d.frame:IsShown())
      assert.are.equal(guild.frame, d.frame:GetParent())
      assert.are.equal("Deposit 2 items?", d.title:GetText())
      assert.are.equal("You cannot take them back out of Donations.", d.warning:GetText())
      assert.are.equal(d.card, herbs.frame:GetParent())
      assert.are.equal(herbs, backpack.content.drag.section, "the backpack keeps its gap")
      d.catcher:GetScript("OnDoubleClick")(d.catcher, "LeftButton")
      assert.are.same({ { { "0_3", "0_4" }, 4 } }, calls.deposited)
      finishTweens()
      assert.is_not_nil(backpack.content.leaving.Herbs)
      assert.is_false(d.frame:IsShown())
    end)

    it("withdraws a guild section into the backpack", function()
      local ore = pickUp(guild, "Ore")
      moveTo(1700, 600)
      assert.is_true(backpack.dropGlow:IsShown())
      assert.are.equal("Move to the Backpack", nextDrag.hint:GetText())
      drop(ore)
      assert.are.same({ { "1002_4" } }, calls.withdrawn)
      finishTweens()
      assert.is_not_nil(guild.content.leaving.Ore)
    end)

    it("withdraws into a backpack group, assigning the category to it", function()
      local ore = pickUp(guild, "Ore")
      moveTo(centerOf(backpack.tabs:Tab(2).button))
      drop(ore)
      assert.are.same({ { "1002_4" } }, calls.withdrawn)
      assert.are.same({ { BACKPACK, "Ore", 2 } }, calls.assigned)
      finishTweens()
      assert.are.same({ { resetLayout = true } }, sentNamed("bags/Rederive"))
    end)

    it("reorders the guild bank's own sections, saving their order for the guild bank", function()
      local ore = pickUp(guild, "Ore")
      moveTo(300, CANVAS_TOP - 5)
      drop(ore)
      finishTweens()
      assert.are.same({ "Ore", "Cloth" }, sectionNames(guild))
      assert.are.equal(0, pins[GUILD].Ore)
    end)

    it("does not drop a guild section on the guild bank's own tabs", function()
      local ore = pickUp(guild, "Ore")
      moveTo(centerOf(guild.tabs:Tab(1001).button))
      assert.is_nil(guild.tabs.dropTarget)
      drop(ore)
      assert.are.same({}, calls.withdrawn)
      assert.are.same({}, calls.assigned)
    end)

    it("is no target away from the guild bank", function()
      override(addon, "atGuildBank", false)
      local herbs = pickUp(backpack, "Herbs")
      moveTo(300, 600)
      assert.is_false(guild.dropGlow:IsShown())
      drop(herbs)
      local ore = pickUp(guild, "Ore")
      moveTo(1700, 600)
      assert.is_false(backpack.dropGlow:IsShown())
      drop(ore)
      assert.are.same({}, calls.deposited)
      assert.are.same({}, calls.withdrawn)
    end)
  end)

  -- A panel that buys sections (BetterBags Next's vendor, next.md §10): a backpack section dropped
  -- anywhere on it, its body or its tabs, is sold. The seller says what sells and sells it.
  describe("dropping on a seller", function()
    local seller

    local function keys(list)
      local out = {}
      for _, data in ipairs(list) do table.insert(out, data.slotkey) end
      return out
    end

    before_each(function()
      override(addon, "atBank", false)
      bank.frame:Hide()
      seller = { kind = -1, closing = false, glows = {}, sales = {}, asked = {}, sells = nil, answer = "sold" }
      seller.frame = CreateFrame("Frame")
      seller.body = CreateFrame("Frame")
      seller.body:_SetRect(0, 0, style.BODY_WIDTH, 1200)
      seller.scroll = { frame = CreateFrame("Frame") }
      seller.scroll.frame:_SetRect(style.PAD, style.FOOTER, 300, 900)
      local tabButton = CreateFrame("Button")
      tabButton:_SetRect(style.BODY_WIDTH, 900, 100, style.TAB_HEIGHT)
      seller.tabs = { TabAt = function()
        return tabButton:IsMouseOver() and { id = 2, button = tabButton } or nil
      end }
      seller.tabButton = tabButton
      function seller:IsShown() return self.frame:IsShown() end
      function seller:SetDropGlow(on) table.insert(self.glows, on) end
      function seller:SaleOf(list) return self.sells or list end
      -- As the vendor's: "sold", or "confirm" and the text to confirm with while unconfirmed.
      function seller:Sell(c, sale, confirmed)
        assert.is_not_nil(c)
        if self.answer == "confirm" and not confirmed then
          table.insert(self.asked, keys(sale))
          return "confirm", { title = "Sell 2 items?", warning = "Only the last 12 items sold can be bought back.",
            hint = "Double-click to sell · Right-click to cancel" }
        end
        table.insert(self.sales, keys(sale))
        return "sold"
      end
      nextDrag:RegisterSeller(seller)
    end)

    it("sells a backpack section dropped on it, lit and the sale named, flying into it", function()
      local herbs = pickUp(backpack, "Herbs")
      moveTo(300, 600)
      assert.are.same({ true }, seller.glows)
      assert.are.equal("Sell 2 items", nextDrag.hint:GetText())
      drop(herbs)
      assert.are.same({ { "0_3", "0_4" } }, seller.sales)
      assert.are.same({}, calls.moved)
      finishTweens()
      assert.are.same({ true, false }, seller.glows)
      assert.is_not_nil(backpack.content.leaving.Herbs)
      assert.is_false(herbs.frame:IsShown())
    end)

    it("takes it on its tabs too, and names a single item", function()
      local armor = pickUp(backpack, "Armor")
      moveTo(centerOf(seller.tabButton))
      assert.are.equal("Sell 1 item", nextDrag.hint:GetText())
      drop(armor)
      assert.are.same({ { "0_1" } }, seller.sales)
    end)

    it("lands back when nothing in it sells", function()
      seller.sells = {}
      local herbs = pickUp(backpack, "Herbs")
      moveTo(300, 600)
      assert.are.equal("Nothing in it sells", nextDrag.hint:GetText())
      drop(herbs)
      finishTweens()
      assert.are.same({}, seller.sales)
      assert.is_true(herbs.frame:IsShown())
      assert.are.equal(backpack.content.frame, herbs.frame:GetParent())
    end)

    -- Asked: a sale past what buyback keeps asked in a dialog that "blends right in", and the section
    -- snapped back to the backpack meanwhile, drawing the eye away. Now the section stays in the
    -- seller, glowing, until it is confirmed with a double click or cancelled.
    describe("a sale it confirms first", function()
      local herbs

      local function dock()
        return nextDrag.dock
      end

      before_each(function()
        seller.answer = "confirm"
        herbs = pickUp(backpack, "Herbs")
        moveTo(300, 600)
        drop(herbs)
        finishTweens()
      end)

      local function doubleClick()
        local catcher = dock().catcher
        catcher:GetScript("OnDoubleClick")(catcher, "LeftButton")
      end

      local function click(mouse)
        local catcher = dock().catcher
        catcher:GetScript("OnClick")(catcher, mouse)
      end

      local function backInPlace()
        assert.are.equal(backpack.content.frame, herbs.frame:GetParent())
        assert.is_true(herbs.frame:IsShown())
        assert.is_false(dock().frame:IsShown())
        assert.is_false(nextDrag:IsActive())
        assert.is_nil(backpack.content.drag)
        assert.is_nil(backpack.content.leaving.Herbs)
      end

      it("docks the section in the seller with what it asks, selling nothing and keeping the backpack's gap", function()
        assert.are.same({ { "0_3", "0_4" } }, seller.asked)
        assert.are.same({}, seller.sales)
        local d = dock()
        assert.is_true(d.frame:IsShown())
        assert.are.equal(seller.frame, d.frame:GetParent())
        assert.are.equal("Sell 2 items?", d.title:GetText())
        assert.are.equal("Only the last 12 items sold can be bought back.", d.warning:GetText())
        assert.are.equal("Double-click to sell · Right-click to cancel", d.hint:GetText())
        assert.are.equal(d.card, herbs.frame:GetParent())
        assert.is_true(herbs.frame:IsShown())
        assert.is_true(d.scrim:IsShown(), "the seller's own items dim behind it")
        assert.are.equal(herbs, backpack.content.drag.section, "the backpack keeps its gap")
        assert.is_nil(backpack.content.leaving.Herbs)
        assert.is_true(nextDrag:IsActive())
        assert.are.same({ true, false }, seller.glows)
        assert.is_false(nextDrag.hint:IsShown())
        assert.is_false(nextDrag.cover:IsShown())
      end)

      -- A Next theme draws the dock, and one applied while it waits restyles it.
      it("draws the dock from the theme, restyling it while it waits", function()
        UseNextTheme({ Palette = { Paper = { 0.9, 0.85, 0.7, 1 } }, Fonts = { Big = { Size = 20 } },
          Dock = { Card = { Color = "Paper" }, Pad = 20, Halo = false, TitleFont = "Big",
            Glow = { Color = "White", Width = 4, Low = 0.2, High = 0.6, Period = 2 } } })
        nextDrag:ApplyStyle(context:New("spec"))
        local d = dock()
        local c = d.background._colorTexture
        assert.are.same({ 0.9, 0.85, 0.7, 1 }, { c.r, c.g, c.b, c.a })
        assert.are.equal(4, d.glow[1]:GetHeight())
        assert.are.equal(4, d.glow[3]:GetWidth())
        assert.are.same({ 1, 1, 1, 1 }, { d.glow[1]:GetVertexColor() })
        assert.is_false(d.halo:IsShown())
        assert.are.equal(style:Font("Big"), d.title:GetFontObject())
        assert.are.equal(herbs.frame:GetWidth() + 40, d.card:GetWidth())
        d.elapsed = 0
        d.frame:GetScript("OnUpdate")(d.frame, 0)
        assert.is_true(math.abs(d.glow[1]:GetAlpha() - 0.4) < 1e-6, "halfway between its low and high")
        UseNextTheme(nil)
        nextDrag:ApplyStyle(context:New("spec"))
        assert.is_true(d.halo:IsShown())
      end)

      it("keeps the section's item buttons from taking the clicks", function()
        local d = dock()
        local function maxLevel(f)
          local level = f:GetFrameLevel()
          for _, child in ipairs({ f:GetChildren() }) do level = math.max(level, maxLevel(child)) end
          return level
        end
        assert.is_true(d.catcher:IsMouseEnabled())
        assert.is_true(d.catcher:GetFrameLevel() > maxLevel(herbs.frame))
      end)

      it("sells on a double click, with the section's items as they are then, and flies it in", function()
        slots[BACKPACK].tabs[1] = tab({ "Armor", "Cloth", "Herbs", "Ore" }, {
          item("0_1", "Armor"), item("0_2", "Cloth"), item("0_3", "Herbs"), item("0_5", "Ore"),
        })
        backpack:Draw(ctx(), slots[BACKPACK], function() end)
        flush()
        doubleClick()
        assert.are.same({ { "0_3" } }, seller.sales)
        finishTweens()
        assert.is_false(dock().frame:IsShown())
        assert.is_false(herbs.frame:IsShown())
        assert.is_not_nil(backpack.content.leaving.Herbs)
        assert.is_false(nextDrag:IsActive())
        assert.is_nil(backpack.content.drag)
      end)

      it("does nothing on a single click", function()
        click("LeftButton")
        finishTweens()
        assert.are.same({}, seller.sales)
        assert.is_true(dock().frame:IsShown())
        assert.are.equal(dock().card, herbs.frame:GetParent())
      end)

      it("cancels on a right click: the section lands back in its gap, nothing sold", function()
        click("RightButton")
        finishTweens()
        assert.are.same({}, seller.sales)
        backInPlace()
      end)

      it("covers the seller's own items, so nothing behind it is bought, and cancels on a right click there too", function()
        local d = dock()
        assert.is_true(d.frame:IsMouseEnabled())
        d.frame:GetScript("OnMouseUp")(d.frame, "LeftButton")
        assert.is_true(d.frame:IsShown())
        d.frame:GetScript("OnMouseUp")(d.frame, "RightButton")
        finishTweens()
        assert.are.same({}, seller.sales)
        backInPlace()
      end)

      it("sells nothing on a double click once the seller is closing, and lands back", function()
        seller.closing = true
        doubleClick()
        finishTweens()
        assert.are.same({}, seller.sales)
        backInPlace()
      end)

      it("lands back when nothing is left to sell at the double click", function()
        seller.sells = {}
        doubleClick()
        finishTweens()
        assert.are.same({}, seller.sales)
        backInPlace()
      end)

      it("cancels when the seller closes", function()
        seller.frame:Hide()
        nextDrag:PanelHidden(seller)
        assert.are.same({}, seller.sales)
        backInPlace()
      end)

      it("puts the section back first when another one is picked up", function()
        local armor = pickUp(backpack, "Armor")
        assert.are.equal(armor, nextDrag.current.section)
        assert.are.equal(backpack.content.frame, herbs.frame:GetParent())
        assert.is_false(dock().frame:IsShown())
        drop(armor)
      end)

      it("goes away with the section when its category leaves the data", function()
        slots[BACKPACK].tabs[1] = tab({ "Armor", "Cloth", "Ore" }, {
          item("0_1", "Armor"), item("0_2", "Cloth"), item("0_5", "Ore"),
        })
        backpack:Draw(ctx(), slots[BACKPACK], function() end)
        flush()
        assert.is_false(dock().frame:IsShown())
        assert.is_false(nextDrag:IsActive())
        assert.are.same({}, seller.sales)
      end)

      it("pulses its glow", function()
        local d = dock()
        local update = d.frame:GetScript("OnUpdate")
        local alphas = {}
        for _ = 1, 6 do
          update(d.frame, 0.2)
          table.insert(alphas, d.glow[1]:GetAlpha())
        end
        local low, high = math.min(unpack(alphas)), math.max(unpack(alphas))
        assert.is_true(high - low > 0.3, "it pulses: " .. table.concat(alphas, ", "))
        for _, edge in ipairs(d.glow) do assert.are.equal(alphas[#alphas], edge:GetAlpha()) end
      end)
    end)

    it("sells nothing without the release", function()
      local herbs = pickUp(backpack, "Herbs")
      moveTo(300, 600)
      _G._mouseButtonsDown = nil
      nextDrag:Update(0.016)
      nextDrag:Update(0.016)
      finishTweens()
      assert.are.same({}, seller.sales)
      assert.is_true(herbs.frame:IsShown())
    end)

    it("is no target while hidden or closing, nor for a bank section", function()
      seller.frame:Hide()
      local herbs = pickUp(backpack, "Herbs")
      moveTo(300, 600)
      assert.are.same({}, seller.glows)
      drop(herbs)
      finishTweens()
      seller.frame:Show()
      seller.closing = true
      herbs = pickUp(backpack, "Herbs")
      moveTo(300, 600)
      drop(herbs)
      finishTweens()
      seller.closing = false
      bank.frame:Show()
      local leather = pickUp(bank, "Leather")
      moveTo(300, 600)
      assert.are.same({}, seller.glows)
      drop(leather)
      assert.are.same({}, seller.sales)
    end)
  end)

  -- The client starts a drag only once the cursor has moved a little, so by then it can be over the
  -- section's first item rather than its header. The release goes to the mouse-enabled frame under
  -- the cursor (warcraft.wiki.gg UIHANDLER_OnReceiveDrag: also when dragging widgets), and over an
  -- item button that is a click that picks the item up.
  describe("the release", function()
    local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6,
      FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }

    -- topmost is the frame the client gives the release to, of those under the cursor: the
    -- highest visible, mouse-enabled one, by strata, then level.
    local function topmost(frames)
      local best
      for _, f in ipairs(frames) do
        if f:IsVisible() and f:IsMouseEnabled() then
          local a, b = STRATA[f:GetFrameStrata()], best and STRATA[best:GetFrameStrata()]
          if best == nil or a > b or (a == b and f:GetFrameLevel() > best:GetFrameLevel()) then
            best = f
          end
        end
      end
      return best
    end

    -- underCursor lists what is under the cursor while a section is dragged by a point of its own:
    -- that point's item button, and the cover over the section when it reaches the point.
    local function underCursor(s, itemButton)
      local frames = { itemButton }
      local cover = nextDrag.cover
      if cover ~= nil and cover:IsShown() then
        local state = nextDrag.current
        local p1, p2 = { cover:GetPoint(1) }, { cover:GetPoint(2) }
        assert.are.same({ "TOPLEFT", s.frame, "TOPLEFT" }, { p1[1], p1[2], p1[3] })
        assert.are.same({ "BOTTOMRIGHT", s.frame, "BOTTOMRIGHT" }, { p2[1], p2[2], p2[3] })
        local left, top, right, bottom = -p1[4], p1[5], s.frame:GetWidth() + p2[4], s.frame:GetHeight() - p2[5]
        if state.grabX >= -left and state.grabX <= right and state.grabY >= -top and state.grabY <= bottom then
          table.insert(frames, cover)
        end
      end
      return frames
    end

    local function release(s, itemButton)
      local focus = topmost(underCursor(s, itemButton))
      local onReceive = focus and focus:GetScript("OnReceiveDrag")
      if onReceive then
        onReceive(focus)
      end
      drop(s)
    end

    it("never picks up the item the cursor was over when the drag started", function()
      local herbs = pickUp(backpack, "Herbs", 20, style.SECTION_HEADER + 10)
      local armor = section(backpack, "Armor")
      moveTo(herbs.frame:GetLeft() + 20, armor.frame:GetTop() - 5)
      release(herbs, buttons["0_3"].button)
      finishTweens()
      assert.are.same({}, calls.pickedUp)
      assert.are.same({ Herbs = 0 }, pins[BACKPACK], "the reorder still happens")
    end)

    it("never picks up an item dropping the section on the other bag", function()
      local herbs = pickUp(backpack, "Herbs", 20, style.SECTION_HEADER + 10)
      moveTo(300, 600)
      release(herbs, buttons["0_3"].button)
      assert.are.same({}, calls.pickedUp)
      assert.are.same({ { { "0_3", "0_4" } } }, calls.moved, "the move still happens")
    end)

    it("covers the section, and a margin past its edges, above everything in it", function()
      local herbs = pickUp(backpack, "Herbs")
      local cover = nextDrag.cover
      assert.is_true(cover:IsShown())
      assert.is_true(cover:IsMouseEnabled())
      assert.are.equal("TOOLTIP", cover:GetFrameStrata())
      local p1, p2 = { cover:GetPoint(1) }, { cover:GetPoint(2) }
      assert.is_true(p1[4] < 0 and p1[5] > 0, "past the top left")
      assert.is_true(p2[4] > 0 and p2[5] < 0, "past the bottom right")
      local function check(f)
        assert.is_true(cover:GetFrameLevel() > f:GetFrameLevel())
        for _, child in ipairs({ f:GetChildren() }) do check(child) end
      end
      check(herbs.frame)
    end)

    it("goes above a frame far above the section, as a skin or a template's level can put one", function()
      local herbs = section(backpack, "Herbs")
      local high = buttons["0_3"].button
      high:SetFrameLevel(herbs.frame:GetFrameLevel() + 300)
      pickUp(backpack, "Herbs")
      assert.is_true(nextDrag.cover:GetFrameLevel() > high:GetFrameLevel())
    end)

    -- Lowering a frame's level lowers every frame in it, and one that would go below 0 jumps to the
    -- top level, 10000 (warcraft.wiki.gg "Frame Strata"), where the cover cannot be above it.
    it("never sends a frame of the section to the top level, picked up or put back", function()
      local herbs = section(backpack, "Herbs")
      local before = {}
      local function levels(f, out)
        out[f] = f:GetFrameLevel()
        for _, child in ipairs({ f:GetChildren() }) do levels(child, out) end
        return out
      end
      levels(herbs.frame, before)
      pickUp(backpack, "Herbs")
      for f in pairs(levels(herbs.frame, {})) do
        assert.is_true(f:GetFrameLevel() < 10000)
      end
      nextDrag:Cancel()
      for f, level in pairs(levels(herbs.frame, {})) do
        assert.are.equal(before[f], level)
      end
    end)

    it("takes the cover away when the section is back in its bag", function()
      local herbs = pickUp(backpack, "Herbs")
      moveTo(900, 600)
      drop(herbs)
      assert.is_true(nextDrag.cover:IsShown(), "while it lands")
      finishTweens()
      assert.is_false(nextDrag.cover:IsShown())
      pickUp(backpack, "Cloth")
      nextDrag:Cancel()
      assert.is_false(nextDrag.cover:IsShown())
    end)
  end)

  describe("cancelling", function()
    it("puts the section straight back when its panel closes mid-drag", function()
      local herbs = pickUp(backpack, "Herbs")
      backpack.frame:Hide()
      backpack.frame:GetScript("OnHide")(backpack.frame)
      assert.is_false(nextDrag:IsActive())
      assert.are.equal(backpack.content.frame, herbs.frame:GetParent())
      drop(herbs)
      assert.are.same({}, calls.moved)
    end)

    -- The client may miss the release (another window took the mouse); Blizzard's own drags
    -- check the button too (FloatingChatFrame.lua). Without the release's hardware event no item
    -- can be moved.
    it("drops when the button is up without a release, never moving items then", function()
      local armor = section(backpack, "Armor")
      local herbs = pickUp(backpack, "Herbs")
      moveTo(herbs.frame:GetLeft() + 20, armor.frame:GetTop() - 5)
      _G._mouseButtonsDown = nil
      nextDrag:Update(0.016)
      assert.is_nil(pins[BACKPACK] and pins[BACKPACK].Herbs, "the release's OnDragStop gets a frame first")
      nextDrag:Update(0.016)
      assert.are.same({ Herbs = 0 }, pins[BACKPACK], "a reorder still saves")
      finishTweens()
      assert.is_false(nextDrag:IsActive())
      local cloth = pickUp(backpack, "Cloth")
      moveTo(300, 600)
      _G._mouseButtonsDown = nil
      nextDrag:Update(0.016)
      nextDrag:Update(0.016)
      finishTweens()
      assert.are.same({}, calls.moved)
      assert.are.equal(backpack.content.frame, cloth.frame:GetParent())
      assert.is_true(cloth.frame:IsShown(), "it lands back")
    end)

    it("ends the drag when the section leaves the data", function()
      pickUp(backpack, "Herbs")
      slots[BACKPACK].tabs[1] = tab({ "Armor" }, { item("0_1", "Armor") })
      backpack:Draw(ctx(), slots[BACKPACK], function() end)
      assert.is_false(nextDrag:IsActive())
    end)
  end)

  describe("the header", function()
    it("passes an item clicked or dropped on it to its panel, and moves the section on a right click", function()
      local herbs = section(backpack, "Herbs")
      _G._cursorHasItem = true
      herbs.header:GetScript("OnClick")(herbs.header, "LeftButton")
      herbs.header:GetScript("OnReceiveDrag")(herbs.header)
      assert.are.same({ { BACKPACK, "Herbs" }, { BACKPACK, "Herbs" } }, calls.titleDrops)
      _G._cursorHasItem = false
      herbs.header:GetScript("OnClick")(herbs.header, "RightButton")
      assert.are.same({ { { "0_3", "0_4" } } }, calls.moved)
    end)

    it("moves nothing on a right click of Free Space", function()
      slots[BACKPACK].tabs[1].freeSpace = { showAll = false, buttons = { { slotkey = "1_5", count = 4 } } }
      backpack:Draw(ctx(), slots[BACKPACK], function() end)
      local free = section(backpack, "Free Space")
      free.header:GetScript("OnClick")(free.header, "RightButton")
      assert.are.same({}, calls.moved)
    end)

    it("moves only items on a right click, never a free slot", function()
      slots[BACKPACK].tabs[1] = tab({ "Herbs" }, { item("0_3", "Herbs"), { slotkey = "0_7", isFreeSlot = true,
        itemInfo = { category = "Herbs" } } })
      backpack:Draw(ctx(), slots[BACKPACK], function() end)
      local herbs = section(backpack, "Herbs")
      herbs.header:GetScript("OnClick")(herbs.header, "RightButton")
      assert.are.same({ { { "0_3" } } }, calls.moved)
    end)
  end)
end)
