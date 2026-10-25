-- currencies_spec.lua -- NextSettingsCurrencies (next/settings/currencies.lua): BetterBags Next's Currencies page's own
-- parts (currency.md §6). The Tracked tab lists what is tracked, in order, each with how many and Remove, dragged to
-- move (NextListReorder); the Items tab is the shared items tab (NextSettingsItemsTab) over the items tracked. The data
-- is the real Currencies module over the spec's Database; the window (NextSettings) is stood in for.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local const = StubBetterBagsModule("Constants")
LoadBetterBagsModule("core/context.lua")
local L = StubBetterBagsModule("Localization")
L.G = L.G or function(_, key) return key end
local events = StubBetterBagsModule("Events")
local db = StubBetterBagsModule("Database")
local settings = StubBetterBagsModule("NextSettings")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextFrameArt", "next/frameart.lua" }, { "NextFill", "next/fill.lua" }, { "NextControls", "next/controls/base.lua" },
  { "NextScrollBar", "next/controls/scrollbar.lua" }, { "NextButton", "next/controls/button.lua" },
  { "NextInput", "next/controls/input.lua" }, { "NextMenu", "next/controls/menu.lua" },
  { "NextDialog", "next/controls/dialog.lua" }, { "NextItemGrid", "next/controls/itemgrid.lua" },
  { "NextLift", "next/lift.lua" }, { "NextListReorder", "next/settings/reorder.lua" },
  { "Currencies", "data/currencies.lua" }, { "NextSettingsItemsTab", "next/settings/itemstab.lua" },
  { "NextSettingsCurrencies", "next/settings/currencies.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local page = addon:GetModule("NextSettingsCurrencies")
local currencies = addon:GetModule("Currencies")
local nextDialog = addon:GetModule("NextDialog")
local nextMenu = addon:GetModule("NextMenu")
local controls = addon:GetModule("NextControls")
local context = addon:GetModule("Context")
local style = addon:GetModule("NextStyle")
local lift = addon:GetModule("NextLift")
local tween = addon:GetModule("NextTween")
local motion = addon:GetModule("Motion")

local CONTENT_HEIGHT = 530

describe("NextSettingsCurrencies", function()
  local owner, saved, sent, handlers, itemNames, printed

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  local function ctx()
    return context:New("spec")
  end

  local function click(b, mouse)
    b.frame:GetScript("OnClick")(b.frame, mouse or "LeftButton")
  end

  local function answer(text)
    assert.is_true(nextDialog:IsShown(), "a dialog is shown")
    for i, spec in ipairs(nextDialog.opts.buttons) do
      if spec.text == text then
        click(nextDialog.buttons[i])
        return
      end
    end
    error("the dialog has no button " .. text)
  end

  -- fire runs every handler of a message, as the Events module would.
  local function fire(message)
    for _, fn in ipairs(handlers[message] or {}) do fn(ctx()) end
  end

  local function finishTweens()
    for _ = 1, 400 do
      local update = tween.driver and tween.driver:GetScript("OnUpdate")
      if update == nil then return end
      update(tween.driver, 0.05)
    end
  end

  local function tracked()
    local out = {}
    for _, e in ipairs(currencies:Tracked()) do table.insert(out, currencies:Key(e.kind, e.id)) end
    return out
  end

  local function ids(grid)
    local list = {}
    for _, e in ipairs(grid.entries) do table.insert(list, e.itemID) end
    return list
  end

  local function entryOf(grid, itemID)
    for _, e in ipairs(grid.entries) do
      if e.itemID == itemID then return e end
    end
  end

  -- A currency as GetCurrencyInfo returns it (CurrencyInfoDocumentation.lua).
  local function currency(id, fields)
    local info = { name = "Currency " .. id, currencyID = id, quantity = 0, iconFileID = 1000 + id, maxQuantity = 0,
      discovered = true, quality = 1 }
    for k, v in pairs(fields or {}) do info[k] = v end
    _G._currencies[id] = info
  end

  before_each(function()
    saved, sent, handlers, printed = {}, {}, {}, {}
    ResetMockCurrencies()
    UseNextCurrencies(db, override)
    itemNames = { [5] = "Mycobloom", [6] = "Bismuth" }
    override(_G, "UISpecialFrames", {})
    override(const, "ITEM_QUALITY_COLOR", { [0] = { 0.62, 0.62, 0.62, 1 }, [1] = { 1, 1, 1, 1 },
      [2] = { 0.12, 1, 0, 1 }, [3] = { 0, 0.44, 0.87, 1 } })
    controls.escape = {}
    override(events, "SendMessage", function(_, ectx, message, ...)
      table.insert(sent, message)
      for _, fn in ipairs(handlers[message] or {}) do fn(ectx, ...) end
    end)
    override(events, "RegisterMessage", function(_, message, fn)
      handlers[message] = handlers[message] or {}
      table.insert(handlers[message], fn)
    end)
    override(events, "RegisterEvent", function() end)
    override(settings, "ContentHeight", function() return CONTENT_HEIGHT end)
    override(C_Item, "GetItemNameByID", function(id) return itemNames[id] end)
    override(C_Item, "GetItemQualityByID", function() return 1 end)
    override(C_Item, "GetItemInfoInstant", function(id) return id, "Tradeskill", "Herb", "", 2000 + id end)
    override(_G, "print", function(text) table.insert(printed, text) end)
    _G._itemStackSizes[5], _G._itemStackSizes[6] = 200, 200
    _G._itemStackSizes[7] = 1
    _G._itemCounts[5] = { bags = 4, bank = 20 }
    owner = CreateFrame("Frame", nil, UIParent)
    currencies:Init()
    currencies:OnEnable()
  end)

  after_each(function()
    nextDialog:Hide()
    nextMenu:Close()
    lift.held = nil
    _G._cursorType, _G._cursorItemID, _G._cursorHasItem = nil, nil, false
    _G._mouseButtonsDown = nil
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
  end)

  describe("the Tracked tab", function()
    local list

    local function make()
      list = page:CreateTracked(CreateFrame("Frame", nil, owner), owner)
      list:Refresh(ctx())
      list:Place(0, 0, 720, list:Measure(720))
      return list
    end

    local function shown()
      local out = {}
      for _, entry in ipairs(list.entries) do table.insert(out, entry.name) end
      return out
    end

    -- yOf returns where a row is in the list once its slide (Motion) has ended.
    local function yOf(key)
      motion:Step(1)
      local _, _, _, _, y = list:RowFor(key).frame:GetPoint(1)
      return -y
    end

    before_each(function()
      currency(1, { name = "Valorstones", quantity = 1350, maxQuantity = 2000, iconFileID = 11 })
      currency(2, { name = "Kej", quantity = 0, iconFileID = 12 })
      currencies:Track(ctx(), "currency", 1)
      currencies:Track(ctx(), "item", 5)
      currencies:Track(ctx(), "currency", 2)
    end)

    it("fills the page's content, its help first", function()
      make()
      assert.is_true(list.wide)
      local C = style.Theme.Settings.Content
      assert.are.equal(CONTENT_HEIGHT - C.Top - C.Bottom, list:Measure(720))
      assert.are.equal(L:G("What shows at the bottom of your backpack and in its tracker, in this order. Drag one to "
        .. "move it. Add currencies on the Currencies tab, and items on the Items tab or by dropping them on your "
        .. "backpack's currencies."), list.help:GetText())
    end)

    it("lists what is tracked in its order, each with its icon, its name, how many (of its most) and Remove", function()
      make()
      assert.are.same({ "currency:1", "item:5", "currency:2" }, shown())
      local valor = list:RowFor("currency:1")
      assert.are.equal(11, valor.icon:GetTexture())
      assert.are.equal("Valorstones", valor.label:GetText())
      assert.are.equal("1,350 / 2,000", valor.note:GetText())
      assert.is_true(valor.remove.frame:IsShown())
      local herb = list:RowFor("item:5")
      assert.are.equal("Mycobloom", herb.label:GetText())
      assert.are.equal("24", herb.note:GetText(), "counted everywhere")
      assert.is_false(list.empty:IsShown())
      local K = style.Theme.Settings.BagCategories
      assert.are.equal(0, yOf("currency:1"))
      assert.are.equal(K.RowHeight, yOf("item:5"))
      assert.are.equal(2 * K.RowHeight, yOf("currency:2"))
    end)

    it("draws what you have none of desaturated", function()
      make()
      assert.is_true(list:RowFor("currency:2").icon:IsDesaturated())
      assert.is_false(list:RowFor("currency:1").icon:IsDesaturated())
    end)

    it("names an item the client has not loaded by its ID, and by its name once it arrives", function()
      itemNames[6] = nil
      local finish
      override(ContinuableContainer, "Create", function()
        local c = {}
        function c:AddContinuable() end
        function c:ContinueOnLoad(fn) finish = fn end
        return c
      end)
      currencies:Track(ctx(), "item", 6)
      make()
      assert.are.equal("Item 6", list:RowFor("item:6").label:GetText())
      itemNames[6] = "Bismuth"
      finish()
      assert.are.equal("Bismuth", list:RowFor("item:6").label:GetText(), "currencies/Updated shows it again")
    end)

    it("stops tracking one with Remove, which leaves the list", function()
      make()
      click(list:RowFor("item:5").remove)
      assert.are.same({ "currency:1", "currency:2" }, tracked())
      assert.are.same({ "currency:1", "currency:2" }, shown())
      assert.is_nil(list:RowFor("item:5"))
    end)

    it("says when nothing is tracked", function()
      for _, key in ipairs({ { "currency", 1 }, { "item", 5 }, { "currency", 2 } }) do
        currencies:Untrack(ctx(), key[1], key[2])
      end
      make()
      assert.are.same({}, shown())
      assert.is_true(list.empty:IsShown())
      assert.are.equal("Nothing tracked yet.", list.empty:GetText())
    end)

    it("moves an entry where a dragged row lands, each row its own in its new place", function()
      make()
      local row = list:RowFor("currency:2")
      list:Drop("currency:2", 0)
      assert.are.same({ "currency:2", "currency:1", "item:5" }, tracked())
      assert.are.same({ "currency:2", "currency:1", "item:5" }, shown())
      assert.are.equal(row, list:RowFor("currency:2"))
      assert.are.equal(0, yOf("currency:2"))
    end)

    -- As the bags drag a section, and every settings list drags its rows (NextListReorder).
    it("drags a row: lifted, the others making room, landing where let go", function()
      make()
      local K = style.Theme.Settings.BagCategories
      list.listBox:_SetRect(0, 0, 300, 300)
      local row = list:RowFor("currency:2")
      row.frame:_SetRect(0, 300 - yOf("currency:2") - K.RowHeight, 300, K.RowHeight)
      -- A quarter of the way down the first row: in its top half, so before it.
      _G._cursorX, _G._cursorY = 20, 300 - 0.25 * K.RowHeight
      _G._mouseButtonsDown = { LeftButton = true }
      row.frame:GetScript("OnDragStart")(row.frame)
      assert.are.equal(lift.layer, row.frame:GetParent(), "lifted")
      list.drag:Update(0.016)
      assert.are.equal(K.RowHeight, yOf("currency:1"), "the first makes room above it")
      _G._mouseButtonsDown = {}
      list.drag:Update(0.016)
      finishTweens()
      _G._cursorX, _G._cursorY = 0, 0
      assert.are.same({ "currency:2", "currency:1", "item:5" }, tracked())
      assert.are.equal(list.listContent, row.frame:GetParent())
      assert.are.equal(0, yOf("currency:2"))
    end)

    it("follows what is tracked and what each reads while it shows, not while it is hidden", function()
      make()
      list.frame:Show()
      currencies:Untrack(ctx(), "currency", 1)
      assert.are.same({ "item:5", "currency:2" }, shown(), "currencies/Changed")
      _G._currencies[2].quantity = 7
      currencies:Refresh(ctx())
      assert.are.equal("7", list:RowFor("currency:2").note:GetText(), "currencies/Updated")
      list.frame:Hide()
      currencies:Untrack(ctx(), "currency", 2)
      assert.are.same({ "item:5", "currency:2" }, shown(), "hidden: read again when shown")
    end)

    it("is drawn again by a theme", function()
      make()
      local row = list:RowFor("currency:1")
      row.hovered = true
      list:Style()
      local K = style.Theme.Settings.BagCategories
      assert.is_true(row.hover:IsShown())
      assert.are.equal(K.Fill.Alpha, list.fill._colorTexture.a)
    end)
  end)

  describe("the Items tab", function()
    local tab

    local function make()
      tab = page:CreateItems(CreateFrame("Frame", nil, owner), owner)
      tab:Refresh(ctx())
      tab:Place(0, 0, 720, tab:Measure(720))
      return tab
    end

    before_each(function()
      currency(1, { quantity = 10 })
      currencies:Track(ctx(), "currency", 1)
      currencies:Track(ctx(), "item", 5)
      currencies:Track(ctx(), "item", 6)
    end)

    it("lists the items tracked, not the currencies, by name, and how many there are", function()
      make()
      assert.are.equal("2 tracked items", tab.count:GetText())
      assert.are.same({ 6, 5 }, ids(tab.grid), "Bismuth, Mycobloom")
      assert.are.equal("Drag an item here to track it at the bottom of your backpack. Only items that stack can be "
        .. "tracked.", tab.help:GetText())
      assert.are.equal("No items tracked yet.", tab.grid.empty:GetText())
    end)

    it("shows how many you have and where, and fades what you have none of", function()
      make()
      local herb = entryOf(tab.grid, 5)
      assert.are.equal(24, herb.count)
      assert.are.equal("4 in your bags, 20 in your bank", herb.note)
      assert.is_false(herb.dim)
      local ore = entryOf(tab.grid, 6)
      assert.is_true(ore.dim)
      assert.are.equal("You have none.", ore.note)
    end)

    it("tracks an item dropped on it that stacks, and refuses one that does not, leaving it on the cursor", function()
      make()
      _G._cursorType, _G._cursorItemID, _G._cursorHasItem = "item", 7, true
      tab.grid.frame:GetScript("OnReceiveDrag")(tab.grid.frame)
      assert.are.same({ "BetterBags: Only items that stack can be tracked." }, printed)
      assert.is_true(CursorHasItem())
      assert.are.same({ "currency:1", "item:5", "item:6" }, tracked())
      _G._itemStackSizes[8] = 20
      itemNames[8] = "Thread"
      _G._cursorType, _G._cursorItemID, _G._cursorHasItem = "item", 8, true
      tab.grid.frame:GetScript("OnReceiveDrag")(tab.grid.frame)
      assert.is_false(CursorHasItem())
      assert.are.same({ "currency:1", "item:5", "item:6", "item:8" }, tracked())
      assert.are.same({ 6, 5, 8 }, ids(tab.grid))
    end)

    it("stops tracking an item from a right click on it", function()
      make()
      local cell = tab.grid.cells[1]
      assert.are.equal(6, cell.entry.itemID)
      cell.frame:GetScript("OnClick")(cell.frame, "RightButton")
      nextMenu:Rows()[1].frame:GetScript("OnClick")(nextMenu:Rows()[1].frame, "LeftButton")
      assert.are.same({ "currency:1", "item:5" }, tracked())
      assert.are.same({ 5 }, ids(tab.grid))
    end)

    it("stops tracking every item after asking, with Remove All, keeping the currencies", function()
      make()
      click(tab.removeAll)
      assert.are.equal("Stop tracking 2 tracked items? Drop them here again to track them.", nextDialog.text:GetText())
      answer("Cancel")
      assert.are.same({ "currency:1", "item:5", "item:6" }, tracked())
      click(tab.removeAll)
      answer("Remove All")
      assert.are.same({ "currency:1" }, tracked())
      assert.are.same({}, ids(tab.grid))
      assert.is_false(tab.removeAll.frame:IsEnabled())
    end)

    it("shows again what is tracked elsewhere while it shows", function()
      make()
      tab.frame:Show()
      currencies:Untrack(ctx(), "item", 6)
      assert.are.same({ 5 }, ids(tab.grid), "currencies/Changed")
      _G._itemCounts[5] = { bags = 9 }
      fire("items/RefreshBackpack/Done")
      assert.are.equal(9, entryOf(tab.grid, 5).count, "the bags read")
    end)
  end)
end)
