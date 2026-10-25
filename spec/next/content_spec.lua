-- A text sits a quarter pixel right of and above its whole pixel (next-pixel-perfect.md §2); one pixel is one unit here.
local TEXT = 0.25
-- content_spec.lua -- NextContent (next/content.lua): BetterBagsNext's canvas. It binds a tab's
-- data as sections in one column (Recent Items, the tab's categories in order, Free Space),
-- drawing and claiming the static item buttons, lays them out in rows of as many 44-pixel icons
-- as fit, and fades sections in one after the other (next.md §2).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")

local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local L = trackStub("Localization")
local originalG = L.G
L.G = function(_, key) return key end

-- The item buttons: one per slot key, as itemFrame:GetButton keeps them.
local itemFrame = trackStub("ItemFrame")
local masque = trackStub("Masque")
local originalGetButton = itemFrame.GetButton
local buttons
itemFrame.GetButton = function(_, _, slotkey)
  if buttons[slotkey] == nil then
    local b = { slotkey = slotkey, frame = CreateFrame("Frame"), drawn = {}, sized = 0 }
    b.frame:SetSize(37, 37)
    function b:SetItemFromData(_, data) table.insert(self.drawn, { "item", data }) end
    function b:SetFreeSlots(_, data, count, nocount) table.insert(self.drawn, { "free", data, count, nocount }) end
    function b:SetSize(_, w, h)
      self.sized = self.sized + 1
      self.frame:SetSize(w, h)
    end
    buttons[slotkey] = b
  end
  return buttons[slotkey]
end

LoadBetterBagsModule("render/render.lua")
LoadBetterBagsModule("render/drawable.lua")
ResetModuleStub("NextStyle", "next/style.lua")
LoadBetterBagsModule("next/style.lua")
ResetModuleStub("NextTween", "next/tween.lua")
LoadBetterBagsModule("next/tween.lua")
ResetModuleStub("NextContent", "next/content.lua")
LoadBetterBagsModule("next/content.lua")

local nextContent = addon:GetModule("NextContent")
local style = addon:GetModule("NextStyle")
local tween = addon:GetModule("NextTween")
local motion = addon:GetModule("Motion")
local render = addon:GetModule("Render")
local context = addon:GetModule("Context")

local STEP = style.ICON + style.GAP

describe("NextContent", function()
  local parent, canvas, claims

  before_each(function()
    render:Init()
    tween:Init()
    motion:Init()
    buttons = {}
    parent = CreateFrame("Frame")
    parent:Show()
    canvas = nextContent:Create(parent)
    claims = {}
  end)

  teardown(function()
    L.G = originalG
    itemFrame.GetButton = originalGetButton
    ResetModuleStub("NextContent", "next/content.lua")
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  local replaced = {}
  local function override(tbl, key, value)
    table.insert(replaced, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  after_each(function()
    for i = #replaced, 1, -1 do replaced[i][1][replaced[i][2]] = replaced[i][3] end
    replaced = {}
  end)

  local function item(slotkey, category)
    return { slotkey = slotkey, itemInfo = { category = category } }
  end

  local function gap(slotkey, category)
    return { slotkey = "gap:" .. slotkey, isItemGap = true, itemInfo = { category = category } }
  end

  -- data builds slot info: tab 1 with its categories in order, and Recent Items in sortedItems.
  local function data(opts)
    return {
      sortedItems = opts.recent or {},
      tabs = { [1] = { categories = opts.categories or {}, items = opts.items or {}, freeSpace = opts.free } },
    }
  end

  local function bind(slotInfo, tabID)
    canvas:Bind(context:New("spec"), slotInfo, tabID or 1, claims)
  end

  local function draw(width)
    return render:NewRenderChain(canvas, { ctx = context:New("spec") }, { Width = width or style.GRID_WIDTH })
  end

  local function names()
    local out = {}
    for _, section in ipairs(canvas.order) do table.insert(out, section.name) end
    return out
  end

  local function at(frame)
    local _, rel, _, x, y = frame:GetPoint(1)
    return rel, x, y
  end

  local function finishTweens()
    for _ = 1, 200 do
      local update = tween.driver and tween.driver:GetScript("OnUpdate")
      if update == nil then return end
      update(tween.driver, 0.05)
    end
  end

  it("binds Recent Items first, the tab's categories in their order, then Free Space", function()
    bind(data({
      recent = { item("0_9", "Recent Items"), item("0_1", "Armor") },
      categories = { { name = "Weapons" }, { name = "Empty" }, { name = "Armor" } },
      items = { item("0_1", "Armor"), item("0_2", "Weapons"), item("0_3", "Armor") },
      free = { showAll = false, buttons = { { slotkey = "1_5", count = 12, key = "Bag" } } },
    }))
    assert.are.same({ "Recent Items", "Weapons", "Armor", "Free Space" }, names(), "a category with nothing is left out")
    assert.are.equal("recent", canvas.order[1].kind)
    assert.are.equal("free", canvas.order[4].kind)
    local armor = canvas.order[3]
    assert.are.equal(buttons["0_1"], armor.entries[1].item)
    assert.are.equal(buttons["0_3"], armor.entries[2].item)
  end)

  it("shows an item whose category the tab does not list, after the listed ones", function()
    bind(data({
      categories = { { name = "Armor" } },
      items = { item("0_1", "Stray"), item("0_2", "Armor") },
    }))
    assert.are.same({ "Armor", "Stray" }, names())
  end)

  it("draws every button it shows from its data, claims it and hangs it in its section", function()
    local sword = item("0_2", "Weapons")
    local slot = { slotkey = "0_4", isFreeSlot = true, itemInfo = { category = "Weapons" } }
    bind(data({
      categories = { { name = "Weapons" } },
      items = { sword, slot },
      free = { showAll = false, buttons = { { slotkey = "1_5", count = 12, key = "Bag" } } },
    }))
    assert.are.same({ { "item", sword } }, buttons["0_2"].drawn)
    assert.are.same({ { "free", slot, -1 } }, buttons["0_4"].drawn)
    assert.are.equal(12, buttons["1_5"].drawn[1][3])
    for key in pairs({ ["0_2"] = true, ["0_4"] = true, ["1_5"] = true }) do
      assert.is_true(claims[buttons[key]], key)
    end
    assert.are.equal(canvas.order[1].cells, buttons["0_2"].frame:GetParent())
    assert.are.equal(buttons["0_2"], canvas.buttons["0_2"])
  end)

  it("draws every free slot one by one when the data shows them all", function()
    local slots = { { slotkey = "1_5", count = 1 }, { slotkey = "1_6", count = 1 } }
    bind(data({ free = { showAll = true, buttons = slots } }))
    assert.are.same({ "free", slots[1], 1, true }, buttons["1_5"].drawn[1])
    assert.are.equal("2", canvas.order[1].count:GetText())
  end)

  it("sizes its buttons to big icons, once", function()
    bind(data({ categories = { { name = "A" } }, items = { item("0_1", "A") } }))
    assert.are.equal(style.ICON, buttons["0_1"].frame:GetWidth())
    bind(data({ categories = { { name = "A" } }, items = { item("0_1", "A") } }))
    assert.are.equal(1, buttons["0_1"].sized)
  end)

  it("titles each section and counts what it holds", function()
    bind(data({
      categories = { { name = "Armor" } },
      items = { item("0_1", "Armor"), gap("0_2", "Armor"), item("0_3", "Armor") },
      free = { showAll = false, buttons = { { slotkey = "1_5", count = 12 }, { slotkey = "5_1", count = 30 } } },
    }))
    assert.are.equal("Armor", canvas.order[1].title:GetText())
    assert.are.equal("2", canvas.order[1].count:GetText(), "gaps are not counted")
    assert.are.equal("42", canvas.order[2].count:GetText(), "free slots in every bag")
    assert.are.equal(42, canvas.freeTotal)
    bind(data({ categories = { { name = "Armor" } }, items = { item("0_1", "Armor") } }))
    assert.are.equal(0, canvas.freeTotal, "none without free space")
  end)

  it("lays its sections out in one column, in rows of as many icons as fit", function()
    local items = {}
    for i = 1, 10 do table.insert(items, item("0_" .. i, "A")) end
    table.insert(items, item("1_1", "B"))
    bind(data({ categories = { { name = "A" }, { name = "B" } }, items = items }))
    local result = draw(style.GRID_WIDTH)
    local a, b = canvas.order[1], canvas.order[2]
    assert.are.same({ canvas.frame, 0, 0 }, { at(a.frame) })
    local aHeight = style.SECTION_HEADER + 2 * STEP - style.GAP
    assert.are.same({ canvas.frame, 0, -(aHeight + style.SECTION_SPACING) }, { at(b.frame) })
    assert.are.same({ a.cells, 0, 0 }, { at(buttons["0_1"].frame) })
    assert.are.same({ a.cells, 7 * STEP, 0 }, { at(buttons["0_8"].frame) })
    assert.are.same({ a.cells, 0, -STEP }, { at(buttons["0_9"].frame) }, "eight to a row")
    local bHeight = style.SECTION_HEADER + STEP - style.GAP
    assert.are.same({ style.GRID_WIDTH, aHeight + style.SECTION_SPACING + bHeight }, { result.Width, result.Height })
  end)

  -- A small panel let go snaps to its widest row of icons (next.md §14g): the canvas says how many cells a width
  -- holds and how wide they are, in units, as it decides its rows (MeasureSection), and how many its largest section
  -- in the column holds.
  it("says how many cells its largest section in the column holds", function()
    assert.are.equal(0, canvas:Widest(), "none while it shows nothing")
    local items = {}
    for i = 1, 10 do table.insert(items, item("0_" .. i, "A")) end
    for i = 1, 3 do table.insert(items, item("1_" .. i, "B")) end
    table.insert(items, gap("1_4", "B"))
    bind(data({ categories = { { name = "A" }, { name = "B" } }, items = items }))
    draw()
    assert.are.equal(10, canvas:Widest())
    local a = canvas.byName.A
    canvas:HoldOut(a)
    assert.are.equal(4, canvas:Widest(), "a section waiting in a dock is out of the column; a gap takes a cell")
    canvas:Returning(a)
    assert.are.equal(10, canvas:Widest(), "one flying back has its room again")
    canvas:Return(a)
    canvas:MarkLeaving("A")
    assert.are.equal(4, canvas:Widest(), "one leaving is out of the column")
  end)

  it("says how many cells a width to lay out for holds, and how wide they are", function()
    assert.are.equal(8, canvas:PerRow(style.GRID_WIDTH))
    assert.are.equal(7, canvas:PerRow(style.GRID_WIDTH - 1))
    assert.are.equal(1, canvas:PerRow(1), "one, however narrow")
    assert.are.equal(style.GRID_WIDTH, canvas:RowWidth(8))
    assert.are.equal(7 * STEP - style.GAP, canvas:RowWidth(7))
    canvas:SetCards(true)
    local card = style.VENDOR_CARD_WIDTH + style.GAP
    assert.are.equal(3, canvas:PerRow(3 * card - style.GAP))
    assert.are.equal(3 * card - style.GAP, canvas:RowWidth(3))
    canvas:SetCards(false)
  end)

  it("fits fewer icons to a row in a narrower width", function()
    local items = {}
    for i = 1, 6 do table.insert(items, item("0_" .. i, "A")) end
    bind(data({ categories = { { name = "A" } }, items = items }))
    draw(5 * STEP - style.GAP)
    assert.are.same({ canvas.order[1].cells, 0, -STEP }, { at(buttons["0_6"].frame) })
  end)

  -- Reported: a panel's items moved between rows as its Bag Scale changed (next-pixel-perfect.md §3). How
  -- many go in a row comes from the width to lay out for (LayoutWidth) in units, with the theme's icon and
  -- gap, so it is the same on every grid; the items stand on the grid's whole-pixel step.
  it("decides how many icons go in a row from the width to lay out for, the same on every grid", function()
    local layout = dofile("spec/helpers/layout.lua")
    local undo = layout.UseScreen(3396, 1362, 0.65)
    -- Under UIParent, as a panel is: its grid is the UI scale times its own.
    parent:SetParent(UIParent)
    finally(function()
      parent:SetParent(nil)
      undo()
    end)
    local items = {}
    for i = 1, 13 do table.insert(items, item("0_" .. i, "A")) end
    bind(data({ categories = { { name = "A" } }, items = items }))
    -- Placed at once: a canvas shown moves what changed place.
    canvas:SetInstant(true)
    local width = 7 * STEP - style.GAP + 0.5
    for percent = 50, 150, 5 do
      parent:SetScale(percent / 100)
      render:NewRenderChain(canvas, { ctx = context:New("spec") }, { Width = width, LayoutWidth = width })
      local cells = canvas.order[1].cells
      local _, _, _, x7, y7 = buttons["0_7"].frame:GetPoint(1)
      local _, _, _, x8, y8 = buttons["0_8"].frame:GetPoint(1)
      assert.is_true(y7 == 0 and x7 > 0, "seven in the first row at " .. percent .. "%")
      assert.are.same({ cells, 0 }, { select(2, buttons["0_8"].frame:GetPoint(1)), x8 }, "the eighth starts the next row at " .. percent .. "%")
      assert.is_true(y8 < 0)
      -- The row fits the width it is drawn in, every gap the same: where the grid's rounded lengths would run
      -- past it, the gap closes by the pixel or two the rounding added.
      local section = canvas.order[1]
      local _, _, _, x2 = buttons["0_2"].frame:GetPoint(1)
      for i = 2, 7 do
        local _, _, _, x = buttons["0_" .. i].frame:GetPoint(1)
        assert.is_true(math.abs(x - (i - 1) * x2) < 1e-6, "even steps at " .. percent .. "%")
      end
      assert.is_true(x7 + buttons["0_7"].frame:GetWidth() <= section.frame:GetWidth() + 1e-6,
        string.format("the row fits at %d%%: %.3f past", percent, x7 + buttons["0_7"].frame:GetWidth() - section.frame:GetWidth()))
    end
    parent:SetScale(1)
    canvas:SetInstant(false)
  end)

  -- Reported: "resizing the window in general ... causes a ton of item icon jitter all over". Simulated with a grip
  -- dragged a pixel a frame: a pixel or two after each column was added, every icon jumped again, up to 19 pixels
  -- across and a pixel or three down, the gaps closed for the width drawn opening again. A column count keeps one
  -- layout whatever the width it is drawn in.
  it("keeps one layout for a column count whatever the width it is drawn in, on every grid", function()
    local layout = dofile("spec/helpers/layout.lua")
    local undo = layout.UseScreen(3396, 1362, 0.65)
    parent:SetParent(UIParent)
    finally(function()
      parent:SetParent(nil)
      undo()
    end)
    local items = {}
    for i = 1, 20 do table.insert(items, item("0_" .. i, "A")) end
    bind(data({ categories = { { name = "A" } }, items = items }))
    canvas:SetInstant(true)
    local function places()
      local out = {}
      for i = 1, 20 do
        local _, _, _, x, y = buttons["0_" .. i].frame:GetPoint(1)
        out[i] = x .. "," .. y
      end
      return out
    end
    for percent = 50, 150, 5 do
      parent:SetScale(percent / 100)
      local expected
      local from = canvas:RowWidth(7)
      for width = from, canvas:RowWidth(8) - 0.25, 0.25 do
        render:NewRenderChain(canvas, { ctx = context:New("spec") }, { Width = width, LayoutWidth = width })
        expected = expected or places()
        assert.are.same(expected, places(), string.format("seven to a row at %d%%, %.2f wide", percent, width))
      end
      local section = canvas.order[1]
      local _, _, _, x7 = buttons["0_7"].frame:GetPoint(1)
      render:NewRenderChain(canvas, { ctx = context:New("spec") }, { Width = from, LayoutWidth = from })
      assert.is_true(x7 + buttons["0_7"].frame:GetWidth() <= section.frame:GetWidth() + 1e-6,
        string.format("the row fits its own width at %d%%", percent))
    end
    parent:SetScale(1)
    canvas:SetInstant(false)
  end)

  -- A section laid out again with no width to lay out for (in a dock card, at the card's scale) keeps the
  -- rows it had.
  it("keeps a section's rows when it is laid out again without a width to lay out for", function()
    local items = {}
    for i = 1, 13 do table.insert(items, item("0_" .. i, "A")) end
    bind(data({ categories = { { name = "A" } }, items = items }))
    render:NewRenderChain(canvas, { ctx = context:New("spec") }, { Width = 7 * STEP, LayoutWidth = 6 * STEP - style.GAP })
    local section = canvas.order[1]
    assert.are.same({ section.cells, 0, -STEP }, { at(buttons["0_7"].frame) }, "six to a row")
    canvas:LayoutSection(section, 9 * STEP)
    assert.are.same({ section.cells, 0, -STEP }, { at(buttons["0_7"].frame) }, "still six")
  end)

  it("keeps a gap's cell empty", function()
    bind(data({ categories = { { name = "A" } }, items = { item("0_1", "A"), gap("0_2", "A"), item("0_3", "A") } }))
    draw()
    assert.are.same({ canvas.order[1].cells, 2 * STEP, 0 }, { at(buttons["0_3"].frame) })
  end)

  it("reuses a section drawn again, and hides and pools one that is not", function()
    bind(data({ categories = { { name = "A" }, { name = "B" } }, items = { item("0_1", "A"), item("0_2", "B") } }))
    local a, b = canvas.order[1], canvas.order[2]
    assert.is_true(a.isNew)
    bind(data({ categories = { { name = "A" } }, items = { item("0_1", "A") } }))
    assert.are.equal(a, canvas.order[1])
    assert.is_false(a.isNew)
    assert.is_false(b.frame:IsShown())
    assert.are.equal(b, canvas.pool[1])
    bind(data({ categories = { { name = "A" }, { name = "C" } }, items = { item("0_1", "A"), item("0_3", "C") } }))
    assert.are.equal(b, canvas.order[2], "a pooled section is used again")
    assert.is_true(b.isNew)
    assert.are.equal("C", b.title:GetText())
  end)

  it("fades sections in one after the other, rising into place", function()
    bind(data({ categories = { { name = "A" }, { name = "B" } }, items = { item("0_1", "A"), item("0_2", "B") } }))
    draw()
    local a, b = canvas.order[1], canvas.order[2]
    canvas:Cascade(true)
    assert.are.equal(0, a.frame:GetAlpha())
    assert.are.same({ a.frame, 0, -style.RISE }, { at(a.inner) })
    tween:Step(style.Time.Stagger)
    assert.is_true(a.frame:GetAlpha() > 0)
    assert.are.equal(0, b.frame:GetAlpha(), "the next one waits its turn")
    finishTweens()
    assert.are.equal(1, a.frame:GetAlpha())
    assert.are.equal(1, b.frame:GetAlpha())
    assert.are.same({ a.frame, 0, 0 }, { at(a.inner) })
  end)

  it("fades in only the sections that are new, on an ordinary draw", function()
    bind(data({ categories = { { name = "A" } }, items = { item("0_1", "A") } }))
    canvas:Cascade(true)
    finishTweens()
    bind(data({ categories = { { name = "A" }, { name = "B" } }, items = { item("0_1", "A"), item("0_2", "B") } }))
    canvas:Cascade(false)
    assert.are.equal(1, canvas.order[1].frame:GetAlpha())
    assert.are.equal(0, canvas.order[2].frame:GetAlpha())
  end)

  it("moves what changed place while shown, and places at once while hidden", function()
    local function bindTwo(first)
      bind(data({ categories = { { name = "A" } }, items = { item(first, "A"), item("0_2", "A") } }))
    end
    bindTwo("0_1")
    draw()
    bind(data({ categories = { { name = "A" } }, items = { item("0_2", "A") } }))
    draw()
    assert.are.same({ STEP, 0, 0, 0 }, { motion:GetMove(buttons["0_2"].frame) })
    motion:Step(1)
    parent:Hide()
    bindTwo("0_1")
    draw()
    assert.is_nil(motion:GetMove(buttons["0_2"].frame))
    assert.are.same({ canvas.order[1].cells, STEP, 0 }, { at(buttons["0_2"].frame) })
  end)

  -- Everything that moves in answer to the player takes NextStyle.Time.Interaction (next.md §5).
  it("glides an item to its new place in the interaction time, easing in and out", function()
    bind(data({ categories = { { name = "A" } }, items = { item("0_1", "A"), item("0_2", "A") } }))
    draw()
    bind(data({ categories = { { name = "A" } }, items = { item("0_2", "A") } }))
    draw()
    local frame = buttons["0_2"].frame
    motion:Step(style.Time.Interaction / 4)
    local x = select(4, frame:GetPoint(1))
    assert.is_true(math.abs(x - STEP * (1 - (3 * 0.25 ^ 2 - 2 * 0.25 ^ 3))) < 1e-6, tostring(x))
    motion:Step(style.Time.Interaction * 3 / 4)
    assert.are.equal(0, (select(4, frame:GetPoint(1))))
    assert.is_nil(motion:GetMove(frame))
  end)

  -- BetterBags Next's vendor (next.md §10) binds sections of its own buttons, taller than an icon
  -- (the price is under it).
  -- A tab shown in slot order draws its empty slots in place and carries no Free Space (the data
  -- phase leaves it out: the section took a slot's only button out of its place). The panel's
  -- footer still says how many slots are free.
  describe("free slots drawn in place", function()
    local function emptySlot(slotkey, category)
      return { slotkey = slotkey, isFreeSlot = true, itemInfo = { category = category } }
    end

    it("counts them in its free slots, drawn as free slots where they are", function()
      bind(data({
        categories = { { name = "#1: Bag" } },
        items = { item("0_1", "#1: Bag"), emptySlot("0_2", "#1: Bag"), emptySlot("0_3", "#1: Bag") },
      }))
      assert.are.equal(2, canvas.freeTotal)
      assert.is_nil(canvas.byName["Free Space"])
      assert.are.same({ "free", -1 }, { buttons["0_2"].drawn[1][1], buttons["0_2"].drawn[1][3] })
    end)

    it("adds them to the free slots Free Space counts", function()
      bind(data({
        categories = { { name = "#1: Bag" } },
        items = { emptySlot("0_2", "#1: Bag") },
        free = { showAll = false, buttons = { { slotkey = "1_1", count = 5, key = "Bag" } } },
      }))
      assert.are.equal(6, canvas.freeTotal)
      assert.are.equal("5", canvas.byName["Free Space"].count:GetText())
    end)
  end)

  -- The guild bank's slots are not bag slots: its canvas takes its buttons from the guild bank's own
  -- buttons (NextGuildButton) instead of the item buttons (guild-bank.md §5).
  describe("a source of buttons of its own", function()
    it("draws every button, Free Space's too, from the source it is given, and claims them", function()
      local made = {}
      local source = {
        GetButton = function(_, _, slotkey)
          made[slotkey] = made[slotkey] or { slotkey = slotkey, frame = CreateFrame("Frame"), drawn = {},
            SetItemFromData = function(self, _, d) table.insert(self.drawn, { "item", d }) end,
            SetFreeSlots = function(self, _, d, count) table.insert(self.drawn, { "free", d, count }) end,
            SetSize = function(self, _, w, h) self.frame:SetSize(w, h) end }
          return made[slotkey]
        end,
      }
      canvas:SetButtonSource(source)
      bind(data({
        categories = { { name = "Ore" } },
        items = { item("1001_1", "Ore") },
        free = { showAll = false, buttons = { { slotkey = "1001_2", bagid = 1001, slotid = 2, count = 96, key = "Gear" } } },
      }))
      assert.are.same({}, buttons, "no item button is taken")
      assert.are.equal("item", made["1001_1"].drawn[1][1])
      assert.are.same({ "free", 96 }, { made["1001_2"].drawn[1][1], made["1001_2"].drawn[1][3] })
      assert.is_true(claims[made["1001_1"]])
      assert.is_true(claims[made["1001_2"]])
      assert.are.equal(made["1001_1"], canvas.buttons["1001_1"])
    end)
  end)

  describe("sections of other buttons", function()
    local function vendorButton(key)
      local f = CreateFrame("Button")
      f:SetSize(style.ICON, style.ICON + 14)
      return { key = key, frame = f }
    end

    it("lays out the sections it is given, in their order, with their own counts", function()
      local a, b, c = vendorButton("v1"), vendorButton("v2"), vendorButton("v3")
      canvas:BindSections({
        { name = "Food", buttons = { a, b } },
        { name = "Armor", buttons = { c }, count = "9" },
      })
      draw()
      assert.are.same({ "Food", "Armor" }, { canvas.order[1].name, canvas.order[2].name })
      assert.are.equal("2", canvas.order[1].count:GetText())
      assert.are.equal("9", canvas.order[2].count:GetText())
      assert.are.equal(canvas.order[1].cells, a.frame:GetParent())
      assert.are.same({ canvas.order[1].cells, STEP, 0 }, { at(b.frame) })
      assert.are.same({ v1 = a, v2 = b, v3 = c }, canvas.buttons)
    end)

    -- The vendor's buttons are cards: an icon with its name and price beside it, in the theme's
    -- columns at the full width, and more of them in a wider small panel.
    it("steps across by its cards in the theme's columns, and down by its icons", function()
      canvas:SetCards(true)
      local width = style.VENDOR_CARD_WIDTH
      assert.are.same({ width, style.ICON }, { canvas:CellWidth(), canvas:CellHeight() })
      local list = {}
      for i = 1, 5 do list[i] = vendorButton("v" .. i) end
      canvas:BindSections({ { name = "Food", buttons = list } })
      draw()
      local columns = style.VENDOR_COLUMNS
      assert.are.same({ canvas.order[1].cells, width + style.GAP, 0 }, { at(list[2].frame) })
      local rowStep = style.ICON + style.GAP
      assert.are.same({ canvas.order[1].cells, 0, -rowStep }, { at(list[columns + 1].frame) })
      assert.are.equal(style.SECTION_HEADER + math.ceil(5 / columns) * rowStep - style.GAP, canvas.order[1].height)
      canvas:SetInstant(true)
      draw(3 * width + 2 * style.GAP)
      assert.are.same({ canvas.order[1].cells, 2 * (width + style.GAP), 0 }, { at(list[3].frame) }, "three in a wider panel")
      canvas:SetInstant(false)
      canvas:SetCards(false)
      assert.are.same({ style.ICON, style.ICON }, { canvas:CellWidth(), canvas:CellHeight() })
    end)

    -- Icon Scale sizes the bags' item buttons, not the vendor's cards (docs/next-appearance-size.md).
    it("steps down by the theme's icon size for cards, by the scaled one for item buttons", function()
      style:SetIconScale(150)
      canvas:SetCards(true)
      assert.are.same({ style.VENDOR_CARD_WIDTH, style.CARD_ICON }, { canvas:CellWidth(), canvas:CellHeight() })
      canvas:SetCards(false)
      assert.are.same({ style.ICON, style.ICON }, { canvas:CellWidth(), canvas:CellHeight() })
      assert.are_not.equal(style.ICON, style.CARD_ICON)
      style:SetIconScale(100)
    end)

    -- BetterBags Next draws its item buttons on whole screen pixels (docs/next-pixel-perfect.md): each button
    -- it lays out is fitted (NextItemFit), its decoration with the item level text on its interaction
    -- button, or the parts a button names (a guild bank button); cards and plain frames are left alone.
    it("fits each item button it lays out, by its decoration or the parts it names", function()
      local fit = addon:GetModule("NextItemFit")
      local fitted = {}
      override(fit, "Fit", function(_, ctx, decoration, extras, fittedItem)
        table.insert(fitted, { ctx ~= nil, decoration, extras, fittedItem })
        return "placed"
      end)
      bind(data({ categories = { { name = "A" } }, items = { item("0_1", "A"), item("0_2", "A") } }))
      local a, b = buttons["0_1"], buttons["0_2"]
      local decoration, ilvl = CreateFrame("Frame"), {}
      a.ilvlText = ilvl
      function a:GetDecoration() return decoration end
      local own, part = CreateFrame("Frame"), {}
      function b:PixelParts() return own, { part } end
      draw()
      assert.are.same({ { true, decoration, { ilvl }, a }, { true, own, { part }, b } }, fitted)
    end)

    -- Reported: two borders round each item with a quality border, with Masque, after a /reload. Masque
    -- skins an item button as it is announced and on every full draw (integrations/masque.lua), before the
    -- canvas lays it out; the fitter then pulled Masque's quality border in to fill the button, inside the
    -- skin's own frame (Caith's: 42 / 36 of the button, centered). Laid out, a button Masque skins keeps
    -- Masque's border where Masque put it.
    it("leaves the border Masque skinned where Masque put it as it lays a button out", function()
      override(masque, "IsSkinned", function(_, button) return button.masqued == true end)
      bind(data({ categories = { { name = "A" } }, items = { item("0_1", "A") } }))
      local a = buttons["0_1"]
      local decoration = CreateFrame("Button", nil, a.frame)
      decoration:SetAllPoints(a.frame)
      decoration.masqued = true
      decoration.IconBorder = decoration:CreateTexture(nil, "OVERLAY")
      decoration.IconBorder:SetSize(43, 43)
      decoration.IconBorder:SetPoint("CENTER", decoration, "CENTER", 0, 0)
      a.ilvlText = a.frame:CreateFontString(nil, "OVERLAY")
      function a:GetDecoration() return decoration end
      draw()
      local border = decoration.IconBorder
      assert.is_nil(border._allPoints, "not pulled in to fill the button")
      assert.are.same({ 1, { "CENTER", decoration, "CENTER", 0, 0 }, 43, 43 },
        { border:GetNumPoints(), { border:GetPoint(1) }, border:GetWidth(), border:GetHeight() })
    end)

    it("reuses a section of the same name and releases the rest", function()
      canvas:BindSections({ { name = "Food", buttons = { vendorButton("a") } }, { name = "Gone", buttons = {} } })
      draw()
      local food, gone = canvas.byName.Food, canvas.byName.Gone
      canvas:BindSections({ { name = "Food", buttons = { vendorButton("b") } } })
      draw()
      assert.are.equal(food, canvas.byName.Food)
      assert.is_false(food.isNew)
      assert.is_false(gone.frame:IsShown())
    end)
  end)

  -- A section dragged by its header (next.md §7).
  describe("dragging a section", function()
    local function threeSections(opts)
      opts = opts or {}
      bind(data({
        recent = opts.recent and { item("0_9", "Recent Items") } or nil,
        categories = { { name = "A" }, { name = "B" }, { name = "C" } },
        items = { item("0_1", "A"), item("0_2", "B"), item("0_3", "C") },
        free = opts.free and { showAll = false, buttons = { { slotkey = "1_5", count = 3 } } } or nil,
      }))
      draw()
      return canvas.byName
    end

    local ONE = style.SECTION_HEADER + style.ICON + style.SECTION_SPACING

    local function y(section)
      local _, _, _, _, oy = section.frame:GetPoint(1)
      return -oy
    end

    it("keeps a gap where a section was picked up, the others staying put", function()
      local s = threeSections()
      canvas:BeginDrag(s.B)
      draw()
      assert.are.equal(0, y(s.A))
      assert.are.equal(2 * ONE, y(s.C))
      assert.is_nil(motion:GetMove(s.C.frame))
      assert.are.equal(ONE, canvas:GetDragSlotY())
    end)

    it("moves the gap where it is asked, the others sliding out of its way", function()
      local s = threeSections()
      canvas:BeginDrag(s.B)
      draw()
      canvas:SetDragIndex(1)
      draw()
      assert.are.equal(0, canvas:GetDragSlotY())
      assert.are.same({ 0, 0, 0, -ONE }, { motion:GetMove(s.A.frame) })
      assert.are.equal(2 * ONE, y(s.C))
    end)

    it("slides the others out of the gap's way faster than other moves, easing in and out", function()
      local s = threeSections()
      canvas:BeginDrag(s.B)
      draw()
      canvas:SetDragIndex(1)
      draw()
      motion:Step(style.Time.Interaction / 4)
      local moved = y(s.A)
      assert.is_true(moved > 0 and moved < ONE * 0.25, "starts slow: " .. moved)
      motion:Step(style.Time.Interaction * 3 / 4)
      assert.are.equal(ONE, y(s.A))
      assert.is_nil(motion:GetMove(s.A.frame))
    end)

    it("moves sections in the interaction time once nothing is dragged too", function()
      local s = threeSections()
      canvas:BeginDrag(s.B)
      canvas:SetDragIndex(3)
      canvas:EndDrag(true)
      draw()
      assert.is_not_nil(motion:GetMove(s.C.frame))
      motion:Step(style.Time.Interaction - 0.01)
      assert.is_not_nil(motion:GetMove(s.C.frame), "still moving")
      motion:Step(0.01)
      assert.is_nil(motion:GetMove(s.C.frame))
    end)

    it("keeps a gap after the last section", function()
      local s = threeSections()
      canvas:BeginDrag(s.A)
      canvas:SetDragIndex(3)
      draw()
      assert.are.equal(2 * ONE, canvas:GetDragSlotY())
    end)

    it("keeps the gap among the categories, after Recent Items and before Free Space", function()
      local s = threeSections({ recent = true, free = true })
      canvas:BeginDrag(s.B)
      canvas:SetDragIndex(1)
      assert.are.equal(2, canvas.drag.index)
      canvas:SetDragIndex(99)
      assert.are.equal(4, canvas.drag.index, "before Free Space")
    end)

    it("finds the insertion point under a height by the others' midpoints", function()
      local s = threeSections()
      canvas:BeginDrag(s.B)
      draw()
      assert.are.equal(1, canvas:DragIndexAt(5))
      assert.are.equal(2, canvas:DragIndexAt(ONE - 5))
      assert.are.equal(2, canvas:DragIndexAt(ONE + 5))
      assert.are.equal(3, canvas:DragIndexAt(ONE + ONE / 2 + 5))
      assert.are.equal(3, canvas:DragIndexAt(500))
      assert.are.equal(1, canvas:DragIndexAt(-50))
    end)

    it("puts a dropped section at its new place, and leaves it where it was otherwise", function()
      local s = threeSections()
      canvas:BeginDrag(s.B)
      canvas:SetDragIndex(3)
      canvas:EndDrag(true)
      assert.are.same({ "A", "C", "B" }, names())
      draw()
      motion:Step(1)
      assert.are.equal(2 * ONE, y(s.B))
      canvas:BeginDrag(s.A)
      canvas:SetDragIndex(3)
      canvas:EndDrag(false)
      assert.are.same({ "A", "C", "B" }, names())
      assert.is_nil(canvas.drag)
    end)

    it("keeps a leaving section's place when another is dropped", function()
      local s = threeSections()
      override(_G, "GetTime", function() return 100 end)
      canvas:MarkLeaving("A", 3)
      canvas:BeginDrag(s.C)
      canvas:SetDragIndex(1)
      canvas:EndDrag(true)
      local out = {}
      for _, section in ipairs(canvas.order) do table.insert(out, section.name) end
      assert.are.same({ "A", "C", "B" }, out)
    end)

    it("leaves out a leaving section until its time is up with its items still there", function()
      local s = threeSections()
      local now = 100
      override(_G, "GetTime", function() return now end)
      canvas:MarkLeaving("B", 3)
      draw()
      motion:Step(1)
      assert.is_false(s.B.frame:IsShown())
      assert.are.equal(ONE, y(s.C))
      now = 104
      draw()
      motion:Step(1)
      assert.is_true(s.B.frame:IsShown())
      assert.are.equal(2 * ONE, y(s.C))
    end)

    -- Reported: a section sold into the vendor that the merchant did not take all of stayed hidden in
    -- the backpack ("limbo"): nothing drew the bag again once its time was up.
    it("lays the column out again when a leaving section's time is up, showing it while its items are there", function()
      local s = threeSections()
      local now, timers = 100, {}
      override(_G, "GetTime", function() return now end)
      override(C_Timer, "After", function(delay, fn) table.insert(timers, { delay = delay, fn = fn }) end)
      canvas:MarkLeaving("B")
      local leavingTimer
      for _, t in ipairs(timers) do
        if t.delay == nextContent.LEAVING_SECONDS then leavingTimer = t end
      end
      assert.is_not_nil(leavingTimer)
      render:Flush()
      assert.is_false(s.B.frame:IsShown())
      now = 100 + nextContent.LEAVING_SECONDS
      leavingTimer.fn()
      assert.is_true(render:IsDirty(canvas))
      render:Flush()
      assert.is_true(s.B.frame:IsShown())
    end)

    it("does not lay the column out for a leaving section already forgotten", function()
      threeSections()
      local timers = {}
      override(C_Timer, "After", function(delay, fn) table.insert(timers, { delay = delay, fn = fn }) end)
      canvas:MarkLeaving("B", 3)
      render:Flush()
      bind(data({ categories = { { name = "A" }, { name = "C" } }, items = { item("0_1", "A"), item("0_3", "C") } }))
      render:Flush()
      for _, t in ipairs(timers) do
        if t.delay == 3 then t.fn() end
      end
      assert.is_false(render:IsDirty(canvas))
    end)

    it("keeps hiding a leaving section with nothing but gaps, and forgets it once it is gone", function()
      local now = 100
      override(_G, "GetTime", function() return now end)
      threeSections()
      canvas:MarkLeaving("B", 3)
      bind(data({ categories = { { name = "A" }, { name = "B" }, { name = "C" } },
        items = { item("0_1", "A"), gap("0_2", "B"), item("0_3", "C") } }))
      now = 104
      draw()
      assert.is_false(canvas.byName.B.frame:IsShown())
      bind(data({ categories = { { name = "A" }, { name = "C" } }, items = { item("0_1", "A"), item("0_3", "C") } }))
      assert.is_nil(canvas.leaving.B)
    end)

    it("tells the drag when the section it picked up leaves the data or is torn down", function()
      local s = threeSections()
      local lost = 0
      canvas:BeginDrag(s.B, function() lost = lost + 1 end)
      bind(data({ categories = { { name = "A" }, { name = "C" } }, items = { item("0_1", "A"), item("0_3", "C") } }))
      assert.are.equal(1, lost)
      assert.is_nil(canvas.drag)
      s = threeSections()
      canvas:BeginDrag(s.A, function() lost = lost + 1 end)
      canvas:Release()
      assert.are.equal(2, lost)
    end)

    it("does not fade in a section being dragged", function()
      local s = threeSections()
      canvas:BeginDrag(s.B)
      canvas:Cascade(true)
      assert.are.equal(1, s.B.frame:GetAlpha())
      assert.are.equal(0, s.A.frame:GetAlpha())
    end)
  end)

  -- A section waiting in another panel's dock (NextDock, next.md §7) is held out of its column; sent back,
  -- it flies to its place, which the column keeps for it, then takes it.
  describe("holding sections out", function()
    local ONE = style.SECTION_HEADER + style.ICON + style.SECTION_SPACING

    local function threeSections()
      bind(data({
        categories = { { name = "A" }, { name = "B" }, { name = "C" } },
        items = { item("0_1", "A"), item("0_2", "B"), item("0_3", "C") },
      }))
      draw()
      return canvas.byName
    end

    -- y returns where a section is in the column once its slide (Motion) has ended.
    local function y(section)
      motion:Step(1)
      local _, _, _, _, oy = section.frame:GetPoint(1)
      return -oy
    end

    it("takes a held section out of the column, the others closing up, its frame left alone", function()
      local s = threeSections()
      local dock = CreateFrame("Frame")
      canvas:HoldOut(s.B)
      s.B.frame:SetParent(dock)
      s.B.frame:ClearAllPoints()
      s.B.frame:SetPoint("TOPLEFT", dock, "TOPLEFT", 3, -4)
      draw()
      assert.are.equal(ONE, y(s.C), "C closes up")
      assert.are.same({ dock, 3, -4 }, { at(s.B.frame) })
      assert.is_true(canvas:IsAway(s.B))
      assert.are.same({ "A", "B", "C" }, names(), "still bound")
    end)

    it("keeps a returning section's room without placing it, then places it once it is back", function()
      local s = threeSections()
      canvas:HoldOut(s.B)
      draw()
      local dock = CreateFrame("Frame")
      s.B.frame:SetParent(dock)
      s.B.frame:ClearAllPoints()
      s.B.frame:SetPoint("TOPLEFT", dock, "TOPLEFT", 3, -4)
      canvas:Returning(s.B)
      draw()
      assert.are.equal(2 * ONE, y(s.C), "C makes room")
      assert.are.equal(ONE, s.B.y, "where it flies to")
      assert.are.same({ dock, 3, -4 }, { at(s.B.frame) }, "not placed while it flies")
      s.B.frame:SetParent(canvas.frame)
      canvas:Return(s.B)
      assert.are.same({ canvas.frame, 0, -ONE }, { at(s.B.frame) }, "at its place at once")
      assert.is_false(canvas:IsAway(s.B))
      draw()
      assert.is_nil(motion:GetMove(s.B.frame))
      assert.are.equal(ONE, y(s.B))
    end)

    -- Found by the pixel check in game (next-pixel-perfect.md §3): a section held in a drag is drawn shrunk, and one
    -- flying back from a dock at its card's scale, on other grids than the column's. The room either takes is its
    -- height in the column, on the column's grid: the sections below stay on whole pixels.
    for _, case in ipairs({ "held in a drag", "flying back from a dock" }) do
      it("gives a section " .. case .. " its room on the column's grid, drawn on another", function()
        local layout = dofile("spec/helpers/layout.lua")
        local undo = layout.UseScreen(3396, 1362, 0.65)
        parent:SetParent(UIParent)
        parent:SetScale(0.55)
        canvas:SetInstant(true)
        finally(function()
          canvas:SetInstant(false)
          parent:SetScale(1)
          parent:SetParent(nil)
          undo()
        end)
        local s = threeSections()
        local before = y(s.C)
        -- Drawn on another grid: on a frame at another scale, as the lift draws a held section shrunk and a dock
        -- card draws its section.
        local away = CreateFrame("Frame", nil, UIParent)
        away:SetScale(0.55 * 0.94)
        if case == "held in a drag" then
          canvas:BeginDrag(s.B)
        else
          canvas:HoldOut(s.B)
          draw()
          canvas:Returning(s.B)
        end
        s.B.frame:SetParent(away)
        s.B.frame:ClearAllPoints()
        s.B.frame:SetPoint("TOPLEFT", away, "TOPLEFT", 0, 0)
        draw()
        assert.is_true(math.abs(y(s.C) - before) < 1e-9, string.format("C at %.4f, %.4f before", y(s.C), before))
      end)
    end

    it("calls back when a held section leaves the data, before letting it go", function()
      local s = threeSections()
      local lost, shownWhenLost = 0, nil
      canvas:HoldOut(s.B, function()
        lost = lost + 1
        shownWhenLost = s.B.frame:IsShown()
      end)
      bind(data({ categories = { { name = "A" }, { name = "C" } }, items = { item("0_1", "A"), item("0_3", "C") } }))
      assert.are.equal(1, lost)
      assert.is_true(shownWhenLost)
      assert.is_false(canvas:IsAway(s.B))
    end)

    it("keeps held sections out of a drag's places, and in their place in the order when it commits", function()
      local s = threeSections()
      canvas:HoldOut(s.B)
      canvas:BeginDrag(s.C)
      assert.are.equal(2, canvas.drag.index, "after A only")
      canvas:SetDragIndex(1)
      canvas:EndDrag(true)
      assert.are.same({ "C", "B", "A" }, names(), "B keeps its place; C and A swap")
    end)

    it("never fades a held section in", function()
      local s = threeSections()
      canvas:HoldOut(s.B)
      s.B.frame:SetAlpha(1)
      canvas:Cascade(true)
      assert.is_false(tween:IsPlaying(s.B))
    end)
  end)

  -- The cards a panel's dock holds (NextDock) lead its column, above its sections.
  describe("leading frames", function()
    it("lays them out first, centered, as tall as they say, the sections below them", function()
      bind(data({ categories = { { name = "A" } }, items = { item("0_1", "A") } }))
      local one, two = CreateFrame("Frame", nil, canvas.frame), CreateFrame("Frame", nil, canvas.frame)
      one:SetSize(100, 50)
      two:SetSize(style.GRID_WIDTH, 30)
      local widths = {}
      canvas:SetLead(function(width)
        table.insert(widths, width)
        return { { frame = one, height = 50 }, { frame = two, height = 30 } }
      end)
      local result = draw()
      assert.are.same({ style.GRID_WIDTH }, widths)
      assert.are.same({ canvas.frame, (style.GRID_WIDTH - 100) / 2, 0 }, { at(one) })
      assert.are.same({ canvas.frame, 0, -(50 + style.SECTION_SPACING) }, { at(two) })
      local _, _, sy = at(canvas.byName.A.frame)
      assert.are.equal(-(50 + 30 + 2 * style.SECTION_SPACING), sy)
      assert.are.equal(50 + 30 + 2 * style.SECTION_SPACING + canvas.byName.A.height, result.Height)
    end)

    it("slides what is below one that goes", function()
      bind(data({ categories = { { name = "A" } }, items = { item("0_1", "A") } }))
      local one, two = CreateFrame("Frame", nil, canvas.frame), CreateFrame("Frame", nil, canvas.frame)
      one:SetSize(style.GRID_WIDTH, 50)
      two:SetSize(style.GRID_WIDTH, 30)
      local leads = { { frame = one, height = 50 }, { frame = two, height = 30 } }
      canvas:SetLead(function() return leads end)
      parent:Show()
      canvas.frame:Show()
      draw()
      draw()
      table.remove(leads, 1)
      draw()
      local _, y0, _, y1 = motion:GetMove(two)
      assert.are.same({ -(50 + style.SECTION_SPACING), 0 }, { y0, y1 })
      assert.is_not_nil(motion:GetMove(canvas.byName.A.frame))
    end)
  end)

  describe("section headers", function()
    it("gives each section a header across its title row that passes drags and clicks to its handler", function()
      local seen = {}
      canvas:SetHeaderHandler({
        OnHeaderDragStart = function(_, section) table.insert(seen, { "start", section.name }) end,
        OnHeaderDragStop = function(_, section) table.insert(seen, { "stop", section.name }) end,
        OnHeaderClick = function(_, ctx, section, button)
          assert.is_not_nil(ctx)
          table.insert(seen, { "click", section.name, button })
        end,
        OnHeaderReceiveDrag = function(_, ctx, section)
          assert.is_not_nil(ctx)
          table.insert(seen, { "drop", section.name })
        end,
      })
      bind(data({ categories = { { name = "A" } }, items = { item("0_1", "A") } }))
      draw()
      local header = canvas.order[1].header
      assert.are.same({ "TOPLEFT", canvas.order[1].inner, "TOPLEFT", 0, 0 }, { header:GetPoint(1) })
      assert.are.equal(style.SECTION_HEADER, header:GetHeight())
      assert.are.same({ "LeftButton" }, header._registeredDrags)
      header:GetScript("OnDragStart")(header)
      header:GetScript("OnDragStop")(header)
      header:GetScript("OnClick")(header, "RightButton")
      header:GetScript("OnReceiveDrag")(header)
      assert.are.same({ { "start", "A" }, { "stop", "A" }, { "click", "A", "RightButton" }, { "drop", "A" } }, seen)
    end)
  end)

  -- A Next theme (next-themes.md): everything the canvas draws comes from it, and a theme applied
  -- while sections are out restyles them.
  describe("a theme", function()
    after_each(function()
      UseNextTheme(nil)
    end)

    local function sections()
      bind(data({ recent = { item("0_9", "Recent Items") }, categories = { { name = "A" } },
        items = { item("0_1", "A"), item("0_2", "A") }, free = { buttons = {} } }))
      draw()
    end

    it("lays rows out with its icons, gaps, headers and spacing, read as it draws", function()
      sections()
      UseNextTheme({ Layout = { Icon = 30, Gap = 2, SectionHeader = 18, SectionSpacing = 5 } })
      canvas:ApplyStyle(context:New("spec"))
      -- Hidden, it places at once (shown, Motion carries each button to its new place).
      parent:Hide()
      bind(data({ categories = { { name = "A" }, { name = "B" } },
        items = { item("0_1", "A"), item("0_2", "A"), item("0_3", "B") } }))
      draw(100)
      local perRow = math.floor((100 + 2) / 32)
      assert.are.equal(3, perRow)
      assert.are.same({ canvas.order[1].cells, 32, 0 }, { at(buttons["0_2"].frame) })
      assert.are.equal(30, buttons["0_1"].frame:GetWidth(), "its buttons at its icon size")
      assert.are.equal(18 + 30, canvas.order[1].height)
      assert.are.same({ canvas.frame, 0, -(18 + 30 + 5) }, { at(canvas.order[2].frame) })
      assert.are.same({ "TOPLEFT", canvas.order[1].inner, "TOPLEFT", 0, -18 }, { canvas.order[1].cells:GetPoint(1) })
      assert.are.equal(18, canvas.order[1].header:GetHeight())
    end)

    it("draws section titles and counts in its roles, by kind, moving them to new fonts", function()
      sections()
      local recent, category = canvas.byName["Recent Items"], canvas.byName.A
      UseNextTheme({
        Fonts = { Loud = { Size = 20, Color = "Gold" }, Small = { Size = 9, Color = "Muted" } },
        Sections = { TitleFont = "Loud", RecentFont = "Small", CountFont = "Small" },
      })
      canvas:ApplyStyle(context:New("spec"))
      assert.are.equal(style:Font("Loud"), category.title:GetFontObject())
      assert.are.equal(style:Font("Small"), recent.title:GetFontObject())
      assert.are.equal(style:Font("Small"), category.count:GetFontObject())
      bind(data({ recent = { item("0_9", "Recent Items") }, categories = { { name = "A" } },
        items = { item("0_1", "A") } }))
      assert.are.equal(style:Font("Small"), canvas.byName["Recent Items"].title:GetFontObject())
    end)

    it("draws the line after a title and the header's highlight in its colors, or none", function()
      sections()
      UseNextTheme({ Palette = { Rose = { 1, 0.4, 0.6, 1 } },
        Sections = { Line = { Color = "Rose", From = 0.8, To = 0.2, Size = 2 }, Highlight = false } })
      canvas:ApplyStyle(context:New("spec"))
      local section = canvas.byName.A
      local g = section.line._gradient
      assert.are.same({ 1, 0.4, 0.6, 0.8 }, { g.min.r, g.min.g, g.min.b, g.min.a })
      assert.are.equal(0.2, g.max.a)
      assert.are.equal(2, section.line:GetHeight())
      assert.is_true(section.line:IsShown())
      assert.is_false(section.highlight:IsShown())
      UseNextTheme({ Sections = { Line = false } })
      canvas:ApplyStyle(context:New("spec"))
      assert.is_false(section.line:IsShown())
      assert.is_true(section.highlight:IsShown())
      assert.are.equal(0.12, section.highlight._gradient.min.a)
    end)

    -- GW2_UI's bag section headers (GwBagHeaderTemplate, Inventory/SharedTemplates.xml): a 32-high row of
    -- bag\bag-sep.png behind the name, across the section (docs/next-gw2-theme.md, round two).
    it("draws a row of art behind the title row, across the section, and none after", function()
      sections()
      UseNextTheme({ Layout = { SectionHeader = 32 },
        Sections = { Header = { Texture = "Interface\\Spec\\sep.png", Color = "White", Alpha = 0.9 } } })
      canvas:ApplyStyle(context:New("spec"))
      draw()
      local s = canvas.byName.A
      assert.are.equal("Interface\\Spec\\sep.png", s.row:GetTexture())
      assert.are.equal(0.9, s.row:GetAlpha())
      assert.are.same({ "TOPLEFT", s.inner, "TOPLEFT", 0, 0 }, { s.row:GetPoint(1) })
      assert.are.same({ "TOPRIGHT", s.inner, "TOPRIGHT", 0, 0 }, { s.row:GetPoint(2) })
      assert.are.equal(32, s.row:GetHeight())
      assert.are.equal("BACKGROUND", s.row:GetDrawLayer(), "behind the title, the count and the line")
      assert.is_true(s.row:IsShown())
      UseNextTheme(nil)
      canvas:ApplyStyle(context:New("spec"))
      assert.is_false(s.row:IsShown())
    end)

    it("draws the line and the highlight in art when they name some, and colors after", function()
      sections()
      UseNextTheme({ Sections = {
        Line = { Texture = "Interface\\Spec\\line.png", Color = "White", Size = 4 },
        Highlight = { Texture = "Interface\\Spec\\glow.png", Color = "White", Alpha = 0.5 } } })
      canvas:ApplyStyle(context:New("spec"))
      local s = canvas.byName.A
      assert.are.equal("Interface\\Spec\\line.png", s.line:GetTexture())
      assert.is_nil(s.line._gradient)
      assert.are.equal(4, s.line:GetHeight())
      assert.are.equal("Interface\\Spec\\glow.png", s.highlight:GetTexture())
      assert.is_nil(s.highlight._gradient)
      assert.are.equal(0.5, s.highlight:GetAlpha())
      UseNextTheme(nil)
      canvas:ApplyStyle(context:New("spec"))
      assert.is_nil(s.line:GetTexture())
      assert.is_not_nil(s.line._gradient)
      assert.is_nil(s.highlight:GetTexture())
      assert.is_not_nil(s.highlight._gradient)
    end)

    -- Each by its top left, after the text before it (its width rounded up to a whole pixel), centered on
    -- the title by the fonts' heights (docs/next-pixel-perfect.md): never by a text's middle or right edge.
    it("places a section's title, count and line where it says", function()
      sections()
      UseNextTheme({ Sections = { Title = { X = 9, Y = -2 }, CountGap = 3, LineGap = 7 } })
      canvas:ApplyStyle(context:New("spec"))
      draw()
      local s = canvas.byName.A
      local _, titleHeight = s.title:GetFont()
      local _, countHeight = s.count:GetFont()
      local countX = 9 + math.ceil(s.title:GetStringWidth()) + 3
      assert.are.same({ "TOPLEFT", s.inner, "TOPLEFT", 9 + TEXT, -2 + TEXT }, { s.title:GetPoint(1) })
      assert.are.same({ "TOPLEFT", s.inner, "TOPLEFT", countX + TEXT, -2 - math.floor((titleHeight - countHeight) / 2) + TEXT },
        { s.count:GetPoint(1) })
      local lineX = countX + math.ceil(s.count:GetStringWidth()) + 7
      local lineY = -2 - math.floor((titleHeight - s.line:GetHeight()) / 2)
      assert.are.same({ "TOPLEFT", s.inner, "TOPLEFT", lineX, lineY }, { s.line:GetPoint(1) })
      assert.are.same({ "TOPRIGHT", s.inner, "TOPRIGHT", 0, lineY }, { s.line:GetPoint(2) })
    end)

    it("restyles the sections it keeps for later too", function()
      sections()
      bind(data({ categories = {}, items = {} }))
      draw()
      local pooled = canvas.pool[1]
      assert.is_not_nil(pooled)
      UseNextTheme({ Sections = { Line = false } })
      canvas:ApplyStyle(context:New("spec"))
      assert.is_false(pooled.line:IsShown())
    end)

    it("cascades with its ease, time and rise", function()
      UseNextTheme({ Motion = { Time = { Cascade = 1, Stagger = 0 }, Ease = { Cascade = "linear" }, Rise = 40 } })
      sections()
      canvas:Cascade(true)
      local update = tween.driver:GetScript("OnUpdate")
      update(tween.driver, 0.5)
      local s = canvas.order[1]
      assert.is_true(math.abs(s.frame:GetAlpha() - 0.5) < 1e-6, "linear")
      assert.is_true(math.abs(s.rise - 20) < 1e-6)
    end)
  end)

  it("ends its moves and cascades when it hides", function()
    bind(data({ categories = { { name = "A" } }, items = { item("0_1", "A"), item("0_2", "A") } }))
    draw()
    canvas:Cascade(true)
    bind(data({ categories = { { name = "A" } }, items = { item("0_2", "A") } }))
    draw()
    canvas.frame:GetScript("OnHide")(canvas.frame)
    assert.is_nil(motion:GetMove(buttons["0_2"].frame))
    assert.are.equal(1, canvas.order[1].frame:GetAlpha())
    assert.is_false(tween:IsPlaying(canvas.order[1]))
  end)
end)
