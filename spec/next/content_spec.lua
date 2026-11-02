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
    function b:SetItemFromData(_, data)
      self.data, self.isFreeSlot = data, nil
      table.insert(self.drawn, { "item", data })
    end
    function b:SetFreeSlots(_, data, count, nocount)
      self.data, self.isFreeSlot = data, true
      table.insert(self.drawn, { "free", data, count, nocount })
    end
    function b:GetItemData() return self.data end
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
ResetModuleStub("NextFill", "next/fill.lua")
LoadBetterBagsModule("next/fill.lua")
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

  -- Reported by the adversarial review: a bank of 500 items on 6 tabs started 1,057 flights opening, each tab's read
  -- re-sorting everything while the last tab's flights were under way (refresh-scheduler.md §11a).
  it("places what a read that adds a tab moved at once, and glides again on the read after", function()
    bind(data({ categories = { { name = "A" } }, items = { item("0_1", "A"), item("0_2", "A") } }))
    draw()
    local arrived = data({ categories = { { name = "A" } }, items = { item("0_2", "A"), item("0_1", "A") } })
    arrived.tabArrived, arrived.layoutResets = true, 1
    bind(arrived)
    draw()
    assert.is_nil(motion:GetMove(buttons["0_1"].frame))
    assert.is_nil(motion:GetMove(buttons["0_2"].frame))
    assert.are.equal(0, (select(4, buttons["0_2"].frame:GetPoint(1))))
    bind(data({ categories = { { name = "A" } }, items = { item("0_1", "A"), item("0_2", "A") } }))
    draw()
    assert.is_not_nil(motion:GetMove(buttons["0_1"].frame))
    motion:Step(1)
  end)

  -- It stays on the committed data until the next read: a draw of that read again (a tab switched, a redraw) glides.
  it("places at once only the draw of the read that added a tab", function()
    local function read(first, second)
      local slotInfo = data({ categories = { { name = "A" } }, items = { item(first, "A"), item(second, "A") } })
      slotInfo.tabArrived, slotInfo.layoutResets = true, 1
      return slotInfo
    end
    bind(read("0_1", "0_2"))
    draw()
    bind(read("0_2", "0_1"))
    draw()
    assert.is_not_nil(motion:GetMove(buttons["0_1"].frame))
    motion:Step(1)
  end)

  -- A font string keeps the width its text took through a font change, and cuts what no longer fits (next-themes.md §14).
  it("measures a title again in the font a theme gives it", function()
    bind(data({ categories = { { name = "A" } }, items = { item("0_1", "A") } }))
    draw()
    local title = canvas.byName.A.title
    local widths, texts = {}, {}
    local setWidth, setText = title.SetWidth, title.SetText
    title.SetWidth = function(self, w) table.insert(widths, w) return setWidth(self, w) end
    title.SetText = function(self, t) table.insert(texts, t) return setText(self, t) end
    canvas:ApplyStyle(context:New("spec"))
    title.SetWidth, title.SetText = nil, nil
    assert.are.equal(0, widths[1])
    assert.are.equal("A", texts[1])
  end)

  it("moves an item a pose at a time under a theme's stop motion", function()
    local saved = style.StopMotion
    local stepping = { FPS = 10 }
    style.StopMotion = stepping
    bind(data({ categories = { { name = "A" } }, items = { item("0_1", "A"), item("0_2", "A") } }))
    draw()
    bind(data({ categories = { { name = "A" } }, items = { item("0_2", "A") } }))
    draw()
    style.StopMotion = saved
    assert.are.equal(stepping, motion.moves[buttons["0_2"].frame].stepping)
    motion:Step(1)
  end)

  -- BetterBags Next's vendor (next.md §10) binds sections of its own buttons, taller than an icon
  -- (the price is under it).
  -- A tab shown in slot order draws its empty slots in place and carries no Free Space (the data
  -- phase leaves it out: the section took a slot's only button out of its place). The panel's
  -- footer still says how many slots are free.
  -- Reported: put an item in the backpack, sort, take it out, sort, and icons flew about though every item showed where it was. Each
  -- button belongs to a bag slot, and a sort moves items between slots. A move follows the icon, not the button.
  describe("moving what shows, not the slot behind it", function()
    local function shown(slotkey, category, hash)
      local d = item(slotkey, category)
      d.itemHash = hash
      return d
    end

    local function moving()
      local count = 0
      for _, button in pairs(buttons) do
        if motion:GetMove(button.frame) then count = count + 1 end
      end
      return count
    end

    local function place(slotkey)
      local _, _, _, x, y = buttons[slotkey].frame:GetPoint(1)
      return x, y
    end

    -- onScreen adds a frame's anchors up to the canvas.
    local function onScreen(frame)
      local x, y, f = 0, 0, frame
      while f ~= canvas.frame do
        local _, relativeTo, _, ox, oy = f:GetPoint(1)
        assert.is_not_nil(relativeTo, "anchored all the way up")
        x, y, f = x + ox, y + oy, relativeTo
      end
      return x, y
    end

    local function layout(list)
      local items = {}
      for _, entry in ipairs(list) do table.insert(items, shown(entry[1], entry[2], entry[3])) end
      return data({ categories = { { name = "A" }, { name = "B" } }, items = items })
    end

    it("moves nothing when a sort leaves every item showing where it was", function()
      bind(layout({ { "0_1", "A", "sword" }, { "0_2", "A", "axe" }, { "0_3", "A", "bow" }, { "0_4", "B", "ring" } }))
      draw()
      local x2, y2 = place("0_2")
      bind(layout({ { "1_1", "A", "sword" }, { "0_1", "A", "axe" }, { "0_2", "A", "bow" }, { "0_3", "B", "ring" } }))
      draw()
      assert.are.equal(0, moving())
      local x, y = place("0_1")
      assert.are.same({ x2, y2 }, { x, y }, "the button of slot 0_1 now stands where the axe stood")
    end)

    it("moves nothing when identical stacks change slots", function()
      bind(layout({ { "0_1", "A", "potion" }, { "0_2", "A", "potion" } }))
      draw()
      bind(layout({ { "0_2", "A", "potion" }, { "0_1", "A", "potion" } }))
      draw()
      assert.are.equal(0, moving())
    end)

    it("moves an item a sort does put somewhere else, on the button that shows it now", function()
      bind(layout({ { "0_1", "A", "sword" }, { "0_2", "A", "axe" } }))
      draw()
      local swordX, swordY = place("0_1")
      local axeX = place("0_2")
      bind(layout({ { "0_1", "A", "axe" }, { "0_2", "A", "sword" } }))
      draw()
      assert.are.same({ swordX, swordY, axeX, swordY }, { motion:GetMove(buttons["0_2"].frame) })
      assert.are.same({ axeX, swordY, swordX, swordY }, { motion:GetMove(buttons["0_1"].frame) })
    end)

    it("moves an item from its old section to its new one, on a different button", function()
      bind(layout({ { "0_1", "A", "sword" }, { "0_2", "B", "ring" } }))
      draw()
      bind(layout({ { "0_2", "A", "ring" }, { "0_1", "B", "sword" } }))
      draw()
      assert.are.equal(2, moving())
    end)

    -- The Recent Items section is released in the same draw that moves its last item out.
    it("moves an item out of Recent Items to its section when Recent Items goes away", function()
      local new = shown("0_3", L:G("Recent Items"), "gem")
      local old = shown("0_1", "A", "sword")
      bind(data({ recent = { new }, categories = { { name = "A" } }, items = { old } }))
      draw()
      assert.are.equal(L:G("Recent Items"), canvas.order[1].name)
      local wasX, wasY = onScreen(buttons["0_3"].frame)
      bind(data({ categories = { { name = "A" } }, items = { shown("0_1", "A", "sword"), shown("0_2", "A", "gem") } }))
      draw()
      assert.is_not_nil(motion:GetMove(buttons["0_2"].frame), "it flies")
      local nowX, nowY = onScreen(buttons["0_2"].frame)
      assert.are.same({ wasX, wasY }, { nowX, nowY }, "from where it showed")
      assert.is_nil(motion:GetMove(buttons["0_1"].frame), "the sword stays in its section")
    end)

    it("shows a looted stack's new count where it stands, on its own button", function()
      local before, after = shown("0_1", "A", "potion"), shown("0_1", "A", "potion")
      before.stackedCount, after.stackedCount = 5, 12
      bind(data({ categories = { { name = "A" } }, items = { before } }))
      draw()
      local x, y = place("0_1")
      bind(data({ categories = { { name = "A" } }, items = { after } }))
      draw()
      assert.are.equal(0, moving())
      assert.are.equal(12, buttons["0_1"].data.stackedCount)
      assert.are.same({ x, y }, { place("0_1") })
    end)

    -- Bank and guild bank tabs share a canvas and its sections, and hold items that look alike.
    it("flies nothing when another tab shows an item the last tab showed", function()
      local tabs = {
        [1] = { categories = { { name = "A" } }, items = { shown("6_1", "A", "herb"), shown("6_2", "A", "ore") } },
        [2] = { categories = { { name = "A" } }, items = {
          shown("7_1", "A", "cloth"), shown("7_2", "A", "leather"), shown("7_3", "A", "herb") } },
      }
      local info = { sortedItems = {}, tabs = tabs }
      bind(info, 1)
      draw()
      bind(info, 2)
      draw()
      assert.are.equal(0, moving())
    end)

    it("still flies what changed place when the same tab is drawn again", function()
      local function onTab(category)
        return { sortedItems = {}, tabs = { [2] = { categories = { { name = "A" }, { name = "B" } }, items = {
          shown("0_1", "A", "ore"), shown("0_2", category, "herb") } } } }
      end
      bind(onTab("A"), 2)
      draw()
      bind(onTab("B"), 2)
      draw()
      assert.are.equal(1, moving())
    end)

    it("places what it left of a pass another render left open, when it renders with none of its own", function()
      bind(layout({ { "0_1", "A", "sword" } }))
      draw()
      motion:BeginPass({})
      canvas:SetInstant(true)
      bind(layout({ { "0_1", "A", "sword" }, { "0_2", "A", "axe" } }))
      draw()
      canvas:SetInstant(false)
      assert.is_nil(motion.pass)
      assert.are.equal(1, buttons["0_2"].frame:GetNumPoints())
    end)

    it("still moves the items that close a gap when a sort takes it away", function()
      local sword, ax = shown("0_1", "A", "sword"), shown("0_3", "A", "axe")
      bind(data({ categories = { { name = "A" } }, items = { sword, gap("0_2", "A"), ax } }))
      draw()
      bind(layout({ { "0_1", "A", "sword" }, { "0_2", "A", "axe" } }))
      draw()
      assert.are.equal(1, moving())
      assert.is_not_nil(motion:GetMove(buttons["0_2"].frame))
    end)

    it("does not fly a free slot from where another one stood", function()
      local free = { buttons = { { slotkey = "0_9", count = 3 } } }
      bind(data({ categories = {}, items = {}, free = free }))
      draw()
      bind(data({ categories = {}, items = {}, free = { buttons = { { slotkey = "0_8", count = 2 } } } }))
      draw()
      assert.are.equal(0, moving())
    end)

    it("places everything at once on the first draw after it hid", function()
      bind(layout({ { "0_1", "A", "sword" }, { "0_2", "A", "axe" } }))
      draw()
      parent:Hide()
      draw()
      parent:Show()
      bind(layout({ { "0_1", "A", "axe" }, { "0_2", "A", "sword" } }))
      draw()
      assert.are.equal(0, moving())
    end)

    it("places everything at once while it is sized", function()
      bind(layout({ { "0_1", "A", "sword" }, { "0_2", "A", "axe" } }))
      draw()
      canvas:SetInstant(true)
      bind(layout({ { "0_1", "A", "axe" }, { "0_2", "A", "sword" } }))
      draw()
      assert.are.equal(0, moving())
      canvas:SetInstant(false)
    end)
  end)

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

    -- Icon Scale sizes a card's icon too, and its name and price still need the theme's icon size (issue #1221).
    it("steps down by the scaled icon size, for a card never less than its text needs", function()
      local theme = style.Theme.Layout.Icon
      style:SetIconScale(150)
      canvas:SetCards(true)
      assert.are.same({ style.VENDOR_CARD_WIDTH, style.ICON }, { canvas:CellWidth(), canvas:CellHeight() })
      style:SetIconScale(50)
      assert.are.same({ style.VENDOR_CARD_WIDTH, theme }, { canvas:CellWidth(), canvas:CellHeight() })
      canvas:SetCards(false)
      assert.are.same({ style.ICON, style.ICON }, { canvas:CellWidth(), canvas:CellHeight() })
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
  -- Asked: a layout option for N columns, sections sorted across rows or down columns, the window deciding
  -- each column's size. Hard rule: never disjoint rows: sections side by side share a title line.
  describe("section columns", function()
    local HEADER, SPACING = style.SECTION_HEADER, style.SECTION_SPACING

    before_each(function()
      canvas:SetInstant(true)
    end)

    -- sections binds categories of as many items as each says: { { "A", 8 }, { "B", 8 } }.
    local function sections(list, opts)
      opts = opts or {}
      local categories, items, n = {}, {}, 0
      for _, s in ipairs(list) do
        table.insert(categories, { name = s[1] })
        for _ = 1, s[2] do
          n = n + 1
          table.insert(items, item("0_" .. n, s[1]))
        end
      end
      bind(data({ categories = categories, items = items, recent = opts.recent, free = opts.free }))
    end

    local function columns(count, fill)
      canvas:SetColumnSource(function() return count, fill end)
    end

    local function place(name)
      local _, x, y = at(canvas.byName[name].frame)
      return { x, -y }
    end

    local function height(rows)
      return HEADER + rows * STEP - style.GAP
    end

    it("splits its width into whole cells, with the icon gap between the columns", function()
      columns(2, "across")
      sections({ { "A", 8 }, { "B", 8 } })
      local result = draw()
      assert.are.same({ 0, 0 }, place("A"))
      assert.are.same({ 4 * STEP, 0 }, place("B"))
      assert.are.equal(4 * STEP - style.GAP, canvas.byName.A.frame:GetWidth())
      assert.are.equal(4 * STEP - style.GAP, canvas.byName.B.frame:GetWidth())
      local _, x, y = at(buttons["0_13"].frame)
      assert.are.same({ 0, -STEP }, { x, y }, "B's fifth item starts its second row")
      assert.are.equal(height(2), result.Height)
    end)

    it("gives the cells left over to the first columns", function()
      columns(3, "across")
      sections({ { "A", 1 }, { "B", 1 }, { "C", 1 } })
      draw()
      assert.are.same({ 0, 3 * STEP, 6 * STEP }, { place("A")[1], place("B")[1], place("C")[1] })
      assert.are.equal(3 * STEP - style.GAP, canvas.byName.B.frame:GetWidth())
      assert.are.equal(2 * STEP - style.GAP, canvas.byName.C.frame:GetWidth())
    end)

    it("fills side to side: across a row, then the next", function()
      columns(2, "across")
      sections({ { "A", 1 }, { "B", 1 }, { "C", 1 }, { "D", 1 }, { "E", 1 } })
      draw()
      local row = height(1) + SPACING
      assert.are.same({ { 0, 0 }, { 200, 0 }, { 0, row }, { 200, row }, { 0, 2 * row } },
        { place("A"), place("B"), place("C"), place("D"), place("E") })
    end)

    it("fills top to bottom: down a column, then the next, its rows still lined up", function()
      columns(2, "down")
      sections({ { "A", 1 }, { "B", 1 }, { "C", 1 }, { "D", 1 }, { "E", 1 } })
      draw()
      local row = height(1) + SPACING
      assert.are.same({ { 0, 0 }, { 0, row }, { 0, 2 * row }, { 200, 0 }, { 200, row } },
        { place("A"), place("B"), place("C"), place("D"), place("E") })
    end)

    it("makes a row as tall as its tallest section, in either fill", function()
      for _, fill in ipairs({ "across", "down" }) do
        columns(2, fill)
        sections({ { "A", 9 }, { "B", 1 }, { "C", 1 }, { "D", 1 } })
        draw()
        local second = fill == "across" and place("C") or place("B")
        assert.are.equal(height(3) + SPACING, second[2], fill)
      end
    end)

    -- The hard rule, whatever the bag holds: every section's title is on its row's line, and each row starts
    -- below the tallest section of the row above. Nothing ever stands between rows.
    it("never lets sections side by side sit on different lines, across random bags", function()
      for seed = 1, 40 do
        math.randomseed(seed)
        local count = math.random(2, 4)
        local fill = seed % 2 == 0 and "across" or "down"
        local list = {}
        for i = 1, math.random(1, 16) do list[i] = { "S" .. string.format("%02d", i), math.random(1, 30) } end
        columns(count, fill)
        sections(list)
        local result = draw()
        local rows = {}
        local byLine = {}
        for _, s in ipairs(canvas.order) do
          local x, y = unpack(place(s.name))
          assert.are.equal(s.y, y)
          assert.are.equal(s.x, x)
          if not byLine[y] then
            byLine[y] = {}
            table.insert(rows, y)
          end
          assert.is_nil(byLine[y][x], "two sections in one cell, seed " .. seed)
          byLine[y][x] = s
        end
        table.sort(rows)
        local expect = 0
        for _, y in ipairs(rows) do
          assert.are.equal(expect, y, "a row starts below the tallest of the row above, seed " .. seed)
          local tallest = 0
          for _, s in pairs(byLine[y]) do tallest = math.max(tallest, s.height) end
          expect = y + tallest + SPACING
        end
        assert.are.equal(expect - SPACING, result.Height, "seed " .. seed)
        local sorted = { unpack(canvas.order) }
        table.sort(sorted, function(a, b)
          if fill == "across" then
            return a.y < b.y or (a.y == b.y and a.x < b.x)
          end
          return a.x < b.x or (a.x == b.x and a.y < b.y)
        end)
        for i, s in ipairs(sorted) do
          assert.are.equal(canvas.order[i].name, s.name, "reading order, seed " .. seed)
        end
      end
    end)

    -- As in one column: held in a drag or flying back from a dock it is drawn on another grid, and its room is its height
    -- on the column's, so the rows below stay on whole pixels.
    for _, case in ipairs({ "held in a drag", "flying back from a dock" }) do
      it("gives a section " .. case .. " its height in its row on the column's grid, drawn on another", function()
        local layout = dofile("spec/helpers/layout.lua")
        local undo = layout.UseScreen(3396, 1362, 0.65)
        parent:SetParent(UIParent)
        parent:SetScale(0.55)
        finally(function()
          parent:SetScale(1)
          parent:SetParent(nil)
          undo()
        end)
        columns(2, "across")
        sections({ { "A", 1 }, { "B", 9 }, { "C", 1 } })
        draw()
        local before = place("C")[2]
        local B = canvas.byName.B
        local away = CreateFrame("Frame", nil, UIParent)
        away:SetScale(0.55 * 0.94)
        if case == "held in a drag" then
          canvas:BeginDrag(B)
        else
          canvas:HoldOut(B)
          draw()
          canvas:Returning(B)
        end
        B.frame:SetParent(away)
        B.frame:ClearAllPoints()
        B.frame:SetPoint("TOPLEFT", away, "TOPLEFT", 0, 0)
        draw()
        assert.is_true(math.abs(place("C")[2] - before) < 1e-9, string.format("C at %.4f, %.4f before", place("C")[2], before))
      end)
    end

    it("keeps Recent Items above and Free Space below the columns, at the full width", function()
      columns(2, "across")
      sections({ { "A", 1 }, { "B", 1 } }, {
        recent = { item("0_9", "Recent Items") },
        free = { showAll = false, buttons = { { slotkey = "1_5", count = 3 } } },
      })
      draw()
      local row = height(1) + SPACING
      local free = canvas.order[#canvas.order]
      assert.are.equal("free", free.kind)
      assert.are.same({ 0, 0 }, place(canvas.order[1].name))
      assert.are.equal(style.GRID_WIDTH, canvas.order[1].frame:GetWidth())
      assert.are.same({ { 0, row }, { 200, row } }, { place("A"), place("B") })
      assert.are.same({ 0, 2 * row }, place(free.name))
      assert.are.equal(style.GRID_WIDTH, free.frame:GetWidth())
    end)

    it("shows fewer columns when the window cannot give each two cells", function()
      columns(4, "across")
      sections({ { "A", 1 }, { "B", 1 }, { "C", 1 } })
      draw(canvas:RowWidth(5))
      assert.are.same({ 0, 3 * STEP }, { place("A")[1], place("B")[1] }, "two columns fit five cells")
      assert.are.equal(0, place("C")[1])
      draw(canvas:RowWidth(3))
      assert.are.same({ 0, 0, 0 }, { place("A")[1], place("B")[1], place("C")[1] }, "one column")
      assert.is_nil(canvas.grid)
    end)

    it("decides its columns on the width to lay out for, not the width it is drawn in", function()
      columns(2, "across")
      sections({ { "A", 5 }, { "B", 1 } })
      render:NewRenderChain(canvas, { ctx = context:New("spec") },
        { Width = canvas:RowWidth(8) - 1, LayoutWidth = canvas:RowWidth(8) })
      assert.are.equal(4 * STEP, place("B")[1])
    end)

    it("stays one column without a source, and at one column", function()
      sections({ { "A", 9 }, { "B", 1 } })
      draw()
      assert.are.equal(0, place("B")[1])
      assert.are.equal(style.GRID_WIDTH, canvas.byName.B.frame:GetWidth())
      assert.is_nil(canvas.grid)
      columns(1, "down")
      draw()
      assert.are.equal(0, place("B")[1])
      assert.is_nil(canvas.grid)
    end)

    it("goes back to the full width when the columns go", function()
      columns(2, "across")
      sections({ { "A", 8 }, { "B", 8 } })
      draw()
      assert.is_not_nil(canvas.grid)
      columns(1, "across")
      local result = draw()
      assert.are.equal(style.GRID_WIDTH, canvas.byName.B.frame:GetWidth())
      assert.are.equal(0, canvas.byName.B.x)
      assert.are.equal(2 * height(1) + SPACING, result.Height)
      local _, x = at(buttons["0_16"].frame)
      assert.are.equal(7 * STEP, x)
    end)

    describe("titles", function()
      local LONG = string.rep("x", 40)

      it("cuts a title too long for its column short, keeping its count in the column", function()
        columns(2, "across")
        sections({ { LONG, 1 }, { "B", 1 } })
        draw()
        local s = canvas.byName[LONG]
        local room = s.frame:GetWidth() - style.Theme.Sections.Title.X - style.Theme.Sections.CountGap
          - s.count:GetStringWidth()
        assert.are.equal(room, s.title:GetWidth())
        assert.is_false(s.title:CanWordWrap())
        local _, cx = at(s.count)
        assert.is_true(cx + s.count:GetStringWidth() <= s.frame:GetWidth() + 0.5)
      end)

      it("gives a title back its whole length when there is room again", function()
        columns(2, "across")
        sections({ { LONG, 1 }, { "B", 1 } })
        draw()
        local s = canvas.byName[LONG]
        columns(1, "across")
        local widths, texts = {}, {}
        local setWidth, setText = s.title.SetWidth, s.title.SetText
        s.title.SetWidth = function(self, w) table.insert(widths, w) return setWidth(self, w) end
        s.title.SetText = function(self, t) table.insert(texts, t) return setText(self, t) end
        draw()
        assert.are.same({ 0 }, widths)
        assert.are.same({ LONG }, texts)
        assert.is_nil(s.titleCut)
      end)

      it("leaves a title that fits alone", function()
        columns(2, "across")
        sections({ { "A", 1 }, { "B", 1 } })
        spy.on(canvas.byName.A.title, "SetWidth")
        draw()
        assert.spy(canvas.byName.A.title.SetWidth).was_not.called()
      end)

      it("draws no line after a title that leaves it no room, and draws it again when there is", function()
        columns(2, "across")
        sections({ { LONG, 1 }, { "B", 1 } })
        draw()
        assert.is_false(canvas.byName[LONG].line:IsShown())
        assert.is_true(canvas.byName.B.line:IsShown())
        columns(1, "across")
        draw()
        assert.is_true(canvas.byName[LONG].line:IsShown())
      end)

      it("draws no line in a window too narrow for one, at one column too", function()
        sections({ { LONG, 1 } })
        draw(canvas:RowWidth(4))
        assert.is_false(canvas.byName[LONG].line:IsShown())
      end)

      it("leaves a theme's missing line missing", function()
        override(style.Theme.Sections, "Line", false)
        columns(2, "across")
        sections({ { "A", 1 }, { "B", 1 } })
        canvas:ApplyStyle(context:New("spec"))
        draw()
        assert.is_false(canvas.byName.A.line:IsShown())
      end)
    end)

    -- Asked: wide rows consume multiple columns, as a toggle. A section past three rows in its column takes as many as
    -- keep it within three, and order is never given up to do it.
    describe("wide sections", function()
      local function spanning(count, fill, limit)
        canvas:SetColumnSource(function() return count, fill, true, limit or 4 end)
      end

      local function widthOf(name)
        return canvas.byName[name].frame:GetWidth()
      end

      it("takes the columns it needs: both of two", function()
        spanning(2, "across")
        sections({ { "A", 16 }, { "B", 1 }, { "C", 1 } })
        draw()
        assert.are.equal(style.GRID_WIDTH, widthOf("A"))
        assert.are.same({ 0, height(2) + SPACING }, place("B"))
        assert.are.same({ 4 * STEP, height(2) + SPACING }, place("C"))
      end)

      it("takes only the columns it needs: two of three, the third beside it", function()
        spanning(3, "across")
        sections({ { "A", 16 }, { "B", 1 } })
        draw()
        assert.are.equal(6 * STEP - style.GAP, widthOf("A"))
        assert.are.same({ 6 * STEP, 0 }, place("B"))
        assert.are.equal(2 * STEP - style.GAP, widthOf("B"))
      end)

      it("starts a new row rather than give up the order, leaving the rest of the row empty", function()
        spanning(2, "across")
        sections({ { "A", 1 }, { "B", 16 }, { "C", 1 } })
        draw()
        assert.are.same({ 0, 0 }, place("A"))
        assert.are.same({ 0, height(1) + SPACING }, place("B"))
        assert.are.equal(style.GRID_WIDTH, widthOf("B"))
        assert.are.same({ 0, height(1) + SPACING + height(2) + SPACING }, place("C"))
      end)

      it("takes what is left of a row when that is enough", function()
        spanning(4, "across")
        sections({ { "A", 1 }, { "B", 12 } })
        draw(canvas:RowWidth(16))
        assert.are.same({ 4 * STEP, 0 }, place("B"))
        assert.are.equal(4 * STEP - style.GAP, widthOf("B"), "exactly three rows in its column is not wide")
      end)

      it("is wide just past three rows in its column", function()
        spanning(2, "across")
        sections({ { "A", 12 }, { "B", 13 } })
        draw()
        assert.are.equal(4 * STEP - style.GAP, widthOf("A"))
        assert.are.equal(style.GRID_WIDTH, widthOf("B"))
      end)

      it("takes every column when even they run past three rows", function()
        spanning(2, "across")
        sections({ { "A", 197 } })
        local result = draw()
        assert.are.equal(style.GRID_WIDTH, widthOf("A"))
        assert.are.equal(height(25), result.Height)
      end)

      -- Asked, of a limit of 2: "you can see tradeskill not expand out into columns" (6 items, 2 rows in a column of 4).
      it("counts as wide once it would reach the bag's limit of rows", function()
        spanning(2, "across", 2)
        sections({ { "Tradeskill", 6 }, { "Back", 1 }, { "Quest", 4 } })
        draw()
        assert.are.equal(style.GRID_WIDTH, widthOf("Tradeskill"), "two rows in its column")
        assert.are.equal(4 * STEP - style.GAP, widthOf("Back"), "one row")
        assert.are.equal(4 * STEP - style.GAP, widthOf("Quest"), "one row, its column full")
      end)

      it("takes only the columns that keep it under the limit", function()
        spanning(3, "across", 2)
        sections({ { "A", 6 }, { "B", 1 } })
        draw()
        assert.are.equal(6 * STEP - style.GAP, widthOf("A"))
        assert.are.same({ 6 * STEP, 0 }, place("B"))
      end)

      it("lets a higher limit keep more in its column", function()
        spanning(2, "across", 3)
        sections({ { "A", 8 }, { "B", 9 } })
        draw()
        assert.are.equal(4 * STEP - style.GAP, widthOf("A"), "two rows, under three")
        assert.are.equal(style.GRID_WIDTH, widthOf("B"), "three rows")
      end)

      it("decides again when the limit changes while it shows", function()
        spanning(2, "across", 3)
        sections({ { "A", 8 }, { "B", 1 } })
        draw()
        assert.are.equal(4 * STEP - style.GAP, widthOf("A"))
        spanning(2, "across", 2)
        draw()
        assert.are.equal(style.GRID_WIDTH, widthOf("A"))
      end)

      it("stays in its column with the toggle off", function()
        canvas:SetColumnSource(function() return 2, "across", false end)
        sections({ { "A", 16 }, { "B", 1 } })
        draw()
        assert.are.equal(4 * STEP - style.GAP, widthOf("A"))
        assert.are.same({ 4 * STEP, 0 }, place("B"))
      end)

      it("takes a row of its own filling top to bottom, the others filling down between", function()
        spanning(2, "down")
        sections({ { "A", 1 }, { "B", 1 }, { "C", 16 }, { "D", 1 }, { "E", 1 }, { "F", 1 } })
        draw()
        local row = height(1) + SPACING
        assert.are.same({ { 0, 0 }, { 4 * STEP, 0 } }, { place("A"), place("B") })
        assert.are.same({ 0, row }, place("C"))
        assert.are.equal(style.GRID_WIDTH, widthOf("C"))
        local below = row + height(2) + SPACING
        assert.are.same({ { 0, below }, { 0, below + row }, { 4 * STEP, below } }, { place("D"), place("E"), place("F") })
      end)

      -- Asked: "content changes and isn't always stable, so rows above or below it might get gapped out". What a section
      -- takes is decided once, and held until the layout starts afresh, as gaps are.
      describe("while its contents change", function()
        it("stays in its column as it grows past three rows, only growing taller", function()
          spanning(2, "across")
          sections({ { "A", 12 }, { "B", 1 }, { "C", 1 } })
          draw()
          sections({ { "A", 20 }, { "B", 1 }, { "C", 1 } })
          draw()
          assert.are.equal(4 * STEP - style.GAP, widthOf("A"))
          assert.are.same({ 4 * STEP, 0 }, place("B"), "nothing moves sideways")
          assert.are.same({ 0, height(5) + SPACING }, place("C"), "what is below moves down for it")
        end)

        it("stays wide as it shrinks, leaving nothing to fill", function()
          spanning(2, "across")
          sections({ { "B", 1 }, { "C", 1 }, { "D", 20 }, { "E", 1 } })
          draw()
          local before = place("E")
          sections({ { "B", 1 }, { "C", 1 }, { "D", 13 }, { "E", 1 } })
          draw()
          assert.are.equal(style.GRID_WIDTH, widthOf("D"))
          assert.are.equal(before[1], place("E")[1])
          sections({ { "B", 1 }, { "C", 1 }, { "D", 2 }, { "E", 1 } })
          draw()
          assert.are.equal(style.GRID_WIDTH, widthOf("D"), "even down to two")
        end)

        it("gives a section new while it shows its own width, and holds it", function()
          spanning(2, "across")
          sections({ { "A", 1 } })
          draw()
          sections({ { "A", 1 }, { "B", 20 } })
          draw()
          assert.are.equal(style.GRID_WIDTH, widthOf("B"))
          sections({ { "A", 1 }, { "B", 2 } })
          draw()
          assert.are.equal(style.GRID_WIDTH, widthOf("B"))
        end)

        -- Reported by the second adversarial review: holding what a section needs on opening, with nothing laid out, held a
        -- width the bag did not show, and the next read moved everything. A bag opening lays out, so the two agree.
        it("lays out as it shows in columns: a section that grew while it was open takes its width then", function()
          spanning(2, "across", 2)
          sections({ { "A", 4 }, { "B", 1 } })
          draw()
          local narrow = widthOf("A")
          sections({ { "A", 5 }, { "B", 1 } })
          draw()
          assert.are.equal(narrow, widthOf("A"), "held while it shows")
          canvas.frame:GetScript("OnHide")(canvas.frame)
          assert.are.same({}, canvas.heldCells)
          canvas.frame:GetScript("OnShow")(canvas.frame)
          assert.is_true(render:IsDirty(canvas))
          draw()
          assert.are.equal(style.GRID_WIDTH, widthOf("A"))
          sections({ { "A", 2 }, { "B", 1 } })
          draw()
          assert.are.equal(style.GRID_WIDTH, widthOf("A"), "and holds it again")
        end)

        it("lays nothing out as it shows in one column", function()
          sections({ { "A", 4 } })
          draw()
          canvas.frame:GetScript("OnShow")(canvas.frame)
          assert.is_false(render:IsDirty(canvas))
        end)

        it("lets go of what it holds when told to, and lays out only in columns", function()
          spanning(2, "across")
          sections({ { "A", 12 }, { "B", 1 } })
          draw()
          sections({ { "A", 20 }, { "B", 1 } })
          draw()
          assert.are.equal(4 * STEP - style.GAP, widthOf("A"))
          canvas:ReleaseWidths()
          assert.is_true(render:IsDirty(canvas))
          draw()
          assert.are.equal(style.GRID_WIDTH, widthOf("A"))
        end)

        -- Found by the third adversarial review: released with what it held, a section coming back took a width it no longer needed.
        it("decides again for a section that left its bag's data and came back", function()
          spanning(2, "across", 2)
          sections({ { "A", 20 }, { "B", 1 }, { "C", 1 } })
          draw()
          assert.are.equal(style.GRID_WIDTH, widthOf("A"))
          sections({ { "B", 1 }, { "C", 1 } })
          draw()
          sections({ { "A", 1 }, { "B", 1 }, { "C", 1 } })
          draw()
          assert.are.equal(4 * STEP - style.GAP, widthOf("A"))
        end)

        it("decides again once its bag closes", function()
          spanning(2, "across")
          sections({ { "A", 12 }, { "B", 1 } })
          draw()
          sections({ { "A", 20 }, { "B", 1 } })
          canvas:Settle()
          draw()
          assert.are.equal(style.GRID_WIDTH, widthOf("A"))
        end)

        it("holds nothing while it does not show: what it holds on opening decides", function()
          spanning(2, "across")
          sections({ { "A", 12 }, { "B", 1 } })
          parent:Hide()
          draw()
          sections({ { "A", 20 }, { "B", 1 } })
          parent:Show()
          draw()
          assert.are.equal(style.GRID_WIDTH, widthOf("A"))
        end)

        it("decides again when the bag's layout starts afresh (a sort)", function()
          spanning(2, "across")
          local function info(n, resets)
            local items = { item("0_90", "B") }
            for i = 1, n do table.insert(items, item("0_" .. i, "A")) end
            local slotInfo = data({ categories = { { name = "A" }, { name = "B" } }, items = items })
            slotInfo.layoutResets = resets
            return slotInfo
          end
          bind(info(12, 1))
          draw()
          bind(info(20, 1))
          draw()
          assert.are.equal(4 * STEP - style.GAP, widthOf("A"), "a read that keeps the layout keeps it")
          bind(info(20, 2))
          draw()
          assert.are.equal(style.GRID_WIDTH, widthOf("A"))
        end)

        it("decides again on another tab", function()
          spanning(2, "across")
          local items = {}
          for i = 1, 20 do items[i] = item("0_" .. i, "A") end
          local slotInfo = data({ categories = { { name = "A" } }, items = { item("0_90", "A") } })
          slotInfo.tabs[2] = { categories = { { name = "A" } }, items = items }
          bind(slotInfo, 1)
          draw()
          assert.are.equal(4 * STEP - style.GAP, widthOf("A"))
          bind(slotInfo, 2)
          draw()
          assert.are.equal(style.GRID_WIDTH, widthOf("A"))
        end)

        it("fills top to bottom by what it holds too", function()
          spanning(2, "down")
          sections({ { "A", 12 }, { "B", 1 } })
          draw()
          sections({ { "A", 20 }, { "B", 1 } })
          draw()
          assert.are.equal(4 * STEP - style.GAP, widthOf("A"))
          assert.are.same({ 4 * STEP, 0 }, place("B"))
        end)
      end)

      -- Found by the adversarial review: filling down it asked only of the first column, so a section landing in a narrower
      -- one reached the limit. Asked of the narrowest instead, a split of 5 and 4 gave up all that columns gain.
      describe("filling down, by the column each section lands in", function()
        it("makes a section wide that reaches the limit in the narrower column", function()
          spanning(2, "down", 2)
          sections({ { "A", 1 }, { "B", 5 } })
          draw(canvas:RowWidth(9))
          assert.are.same({ 5, 4 }, canvas.grid.split)
          assert.are.equal(canvas:RowWidth(9), widthOf("B"), "it takes a row of its own")
          assert.are.equal(0, place("B")[1])
        end)

        it("leaves a section where it is that fits the wider column it lands in", function()
          spanning(2, "down", 2)
          sections({ { "A", 5 }, { "B", 1 } })
          draw(canvas:RowWidth(9))
          assert.are.equal(canvas:RowWidth(5), widthOf("A"))
          assert.is_true(place("B")[1] > 0, "B beside it")
        end)

        it("lands the sections either side of a wide one again, each run filling its own columns", function()
          spanning(2, "down", 2)
          sections({ { "A", 5 }, { "B", 4 }, { "C", 5 }, { "D", 4 } })
          draw(canvas:RowWidth(9))
          assert.are.equal(canvas:RowWidth(9), widthOf("C"), "C lands in the narrower column")
          assert.are.equal(0, place("A")[1])
          assert.is_true(place("B")[1] > 0, "A and B fill their own columns above it")
          assert.are.equal(place("A")[2], place("B")[2])
          assert.is_true(place("C")[2] > place("A")[2])
          assert.is_true(place("D")[2] > place("C")[2], "D below it")
        end)
      end)

      -- Whatever the bag holds, the hard rule holds: rows line up, nothing overlaps, and no section passes another.
      it("keeps every row on one line and the order, across random bags", function()
        for seed = 1, 40 do
          math.randomseed(seed)
          local count = math.random(2, 4)
          local fill = seed % 2 == 0 and "across" or "down"
          local list = {}
          for i = 1, math.random(1, 16) do
            list[i] = { "S" .. string.format("%02d", i), math.random() < 0.3 and math.random(13, 60) or math.random(1, 8) }
          end
          spanning(count, fill)
          sections(list)
          canvas:Settle()
          local result = draw()
          local lines, rows = {}, {}
          for _, s in ipairs(canvas.order) do
            if not lines[s.y] then
              lines[s.y] = {}
              table.insert(rows, s.y)
            end
            table.insert(lines[s.y], s)
          end
          table.sort(rows)
          local expect = 0
          for _, y in ipairs(rows) do
            assert.are.equal(expect, y, "seed " .. seed)
            table.sort(lines[y], function(a, b) return a.x < b.x end)
            local tallest, right = 0, 0
            for _, s in ipairs(lines[y]) do
              assert.is_true(s.x >= right, "no overlap, seed " .. seed)
              right = s.x + s.frame:GetWidth()
              assert.is_true(right <= style.GRID_WIDTH + 0.5, "inside the width, seed " .. seed)
              tallest = math.max(tallest, s.height)
            end
            expect = y + tallest + SPACING
          end
          assert.are.equal(expect - SPACING, result.Height, "seed " .. seed)
          if fill == "across" then
            local read = {}
            for _, y in ipairs(rows) do
              for _, s in ipairs(lines[y]) do table.insert(read, s.name) end
            end
            assert.are.same(names(), read, "reading order, seed " .. seed)
          end
        end
      end)
    end)

    -- Asked: "implement drag to reorder for columns ... we're not storing column positions, just list positions here, so
    -- what we save is still just an ordered list." The room goes to the place in the list whose slot is under the cursor.
    describe("reordering by drag", function()
      local function indexAt(x, y)
        return canvas:DragIndexAt(y, x)
      end

      local function moveTo(x, y)
        canvas:SetDragIndex(indexAt(x, y))
        draw()
      end

      local function slot()
        return { canvas:GetDragSlotX(), canvas:GetDragSlotY() }
      end

      local ROW = height(1) + SPACING
      local COLUMN = 4 * STEP

      before_each(function()
        columns(2, "across")
        sections({ { "A", 1 }, { "B", 1 }, { "C", 1 }, { "D", 1 } })
        draw()
      end)

      it("keeps its room where it was until the cursor moves, the others staying put", function()
        canvas:BeginDrag(canvas.byName.C)
        draw()
        assert.are.same({ 0, ROW }, slot())
        assert.are.same({ COLUMN, 0 }, place("B"))
        assert.are.same({ COLUMN, ROW }, place("D"))
      end)

      it("moves its room to the slot under the cursor, in a row and between rows, the others making way", function()
        canvas:BeginDrag(canvas.byName.C)
        draw()
        moveTo(COLUMN + 20, 10)
        assert.are.same({ COLUMN, 0 }, slot(), "beside A")
        assert.are.same({ 0, 0 }, place("A"))
        assert.are.same({ 0, ROW }, place("B"), "B goes to the next row")
        assert.are.same({ COLUMN, ROW }, place("D"))
        moveTo(10, 10)
        assert.are.same({ 0, 0 }, slot(), "first")
        assert.are.same({ COLUMN, 0 }, place("A"))
        moveTo(COLUMN + 20, ROW + 10)
        assert.are.same({ COLUMN, ROW }, slot(), "last")
        assert.are.same({ 0, ROW }, place("D"))
      end)

      it("takes its place in the one list when it ends", function()
        canvas:BeginDrag(canvas.byName.D)
        draw()
        moveTo(COLUMN + 20, 10)
        canvas:EndDrag(true)
        assert.are.same({ "A", "D", "B", "C" }, names())
      end)

      it("keeps the place it had when it is cancelled", function()
        canvas:BeginDrag(canvas.byName.D)
        draw()
        moveTo(COLUMN + 20, 10)
        canvas:EndDrag(false)
        assert.are.same({ "A", "B", "C", "D" }, names())
      end)

      it("goes to the slot nearest a cursor outside every slot", function()
        canvas:BeginDrag(canvas.byName.A)
        draw()
        assert.are.equal(1, indexAt(-50, -50))
        assert.are.equal(4, indexAt(COLUMN + 50, 10000))
      end)

      it("goes to the slot nearest across as well as down, from under a column's last section", function()
        sections({ { "A", 1 }, { "B", 1 }, { "C", 1 } })
        draw()
        canvas:BeginDrag(canvas.byName.C)
        draw()
        moveTo(COLUMN + 60, ROW + 5)
        assert.are.same({ COLUMN, 0 }, slot(), "beside A, not back under it a column away")
      end)

      it("stands its room and its slots under Recent Items", function()
        sections({ { "A", 1 }, { "B", 1 }, { "C", 1 }, { "D", 1 } }, { recent = { item("0_50", "Recent Items") } })
        draw()
        local top = place("A")[2]
        assert.is_true(top > 0)
        canvas:BeginDrag(canvas.byName.D)
        draw()
        assert.are.same({ COLUMN, top + ROW }, slot())
        moveTo(10, top + 10)
        assert.are.same({ 0, top }, slot(), "first of the list, under Recent Items")
        assert.are.same({ COLUMN, top }, place("A"))
        moveTo(COLUMN + 10, top + 10)
        assert.are.same({ COLUMN, top }, slot(), "second")
        assert.are.same({ 0, top }, place("A"))
      end)

      -- The room moving must not change where the cursor sends it: it would flip between two places every frame.
      it("gives one answer for a cursor wherever the room stands", function()
        canvas:BeginDrag(canvas.byName.A)
        draw()
        for _, cursor in ipairs({ { 10, 10 }, { COLUMN + 10, 10 }, { 10, ROW + 10 }, { COLUMN + 10, ROW + 10 }, { COLUMN, ROW } }) do
          local first = indexAt(cursor[1], cursor[2])
          canvas:SetDragIndex(first)
          draw()
          assert.are.equal(first, indexAt(cursor[1], cursor[2]))
        end
      end)

      it("fills down when its bag does, the room in the column under the cursor", function()
        columns(2, "down")
        draw()
        canvas:BeginDrag(canvas.byName.D)
        draw()
        assert.are.same({ COLUMN, ROW }, slot())
        moveTo(10, 10)
        assert.are.same({ 0, 0 }, slot())
        assert.are.same({ 0, ROW }, place("A"), "down its column")
        assert.are.same({ COLUMN, 0 }, place("B"))
        canvas:EndDrag(true)
        assert.are.same({ "D", "A", "B", "C" }, names())
      end)

      it("passes a section spanning its columns, either side of it", function()
        canvas:SetColumnSource(function() return 2, "across", true, 2 end)
        sections({ { "A", 1 }, { "W", 20 }, { "B", 1 } })
        draw()
        canvas:BeginDrag(canvas.byName.B)
        draw()
        local wide = place("W")
        assert.are.same({ 0, ROW }, wide, "W starts a row of its own")
        moveTo(10, 10)
        assert.are.same({ 0, 0 }, slot(), "above it, first")
        assert.are.same({ COLUMN, 0 }, place("A"))
        moveTo(COLUMN + 10, 10)
        assert.are.same({ COLUMN, 0 }, slot(), "beside A, above it")
        assert.are.same({ 0, ROW }, place("W"))
        canvas:EndDrag(true)
        assert.are.same({ "A", "B", "W" }, names())
      end)

      -- Reported, with Back, Consumable (spanning) and Quest: "i can't drag a span section under the last single item
      -- section ... quest doesn't move above consumable". After Back and after Quest it stands in the same place, as Quest
      -- beside Back leaves the row it starts the same.
      describe("a section spanning its columns, whose places can stand in one spot", function()
        local function wide(list)
          canvas:SetColumnSource(function() return 2, "across", true, 2 end)
          sections(list)
          draw()
        end

        local function index()
          return canvas.drag.index
        end

        it("goes under the section after it, which moves up beside the one before", function()
          wide({ { "Back", 1 }, { "W", 20 }, { "Quest", 1 } })
          canvas:BeginDrag(canvas.byName.W)
          draw()
          local where = slot()
          assert.are.same({ 0, ROW }, where)
          moveTo(20, where[2] + canvas.byName.W.height + 5)
          assert.are.same(where, slot(), "it stands where it stood")
          assert.are.same({ COLUMN, 0 }, place("Quest"), "Quest moves up beside Back")
          canvas:EndDrag(true)
          assert.are.same({ "Back", "Quest", "W" }, names())
        end)

        it("stays there with the cursor held still", function()
          wide({ { "Back", 1 }, { "W", 20 }, { "Quest", 1 } })
          canvas:BeginDrag(canvas.byName.W)
          draw()
          local cursorY = slot()[2] + canvas.byName.W.height + 5
          for _ = 1, 4 do
            moveTo(20, cursorY)
            assert.are.equal(3, index())
          end
        end)

        it("does not move when picked up, with or without a hole above it", function()
          wide({ { "Back", 1 }, { "W", 20 }, { "Quest", 1 } })
          canvas:BeginDrag(canvas.byName.W)
          draw()
          local where = slot()
          assert.are.equal(2, indexAt(where[1] + 20, where[2] + 8), "a hole beside Back: as it was saved")
          canvas:EndDrag(false)
          wide({ { "Back", 1 }, { "Quest", 1 }, { "W", 20 } })
          canvas:BeginDrag(canvas.byName.W)
          draw()
          where = slot()
          assert.are.equal(3, indexAt(where[1] + 20, where[2] + 8), "no hole")
        end)

        it("stays in its place while the cursor moves around inside its slot", function()
          wide({ { "Back", 1 }, { "Quest", 1 }, { "W", 20 } })
          canvas:BeginDrag(canvas.byName.W)
          draw()
          local where = slot()
          local tall = canvas.byName.W.height
          for _, y in ipairs({ 2, tall / 2, tall - 2 }) do
            assert.are.equal(3, indexAt(COLUMN + 5, where[2] + y))
          end
        end)

        it("comes into a spot from elsewhere at its place with no hole", function()
          wide({ { "A", 1 }, { "B", 1 }, { "C", 1 }, { "D", 1 }, { "W", 20 } })
          canvas:BeginDrag(canvas.byName.W)
          draw()
          moveTo(20, 10)
          assert.are.equal(1, index())
          moveTo(20, ROW + 10)
          assert.are.equal(3, index(), "A and B above it, not A with a hole beside it")
          assert.are.same({ COLUMN, 0 }, place("B"))
        end)

        it("reaches the last place from anywhere below", function()
          wide({ { "A", 1 }, { "W", 20 }, { "B", 1 }, { "C", 1 }, { "D", 1 } })
          canvas:BeginDrag(canvas.byName.W)
          draw()
          assert.are.equal(5, indexAt(20, 100000))
        end)

        it("holds its place among three that share a spot, and leaves it only past the bottom", function()
          canvas:SetColumnSource(function() return 3, "across", true, 2 end)
          sections({ { "A", 1 }, { "B", 1 }, { "W", 20 }, { "C", 1 } })
          draw()
          canvas:BeginDrag(canvas.byName.W)
          draw()
          local where = slot()
          assert.are.equal(3, indexAt(where[1] + 20, where[2] + 8))
          assert.are.equal(4, indexAt(where[1] + 20, where[2] + canvas.byName.W.height + 5))
        end)

        it("goes by where the section is, the cursor less the point grabbed", function()
          wide({ { "Back", 1 }, { "W", 20 }, { "Quest", 1 } })
          canvas:BeginDrag(canvas.byName.W)
          draw()
          local bottom = slot()[2] + canvas.byName.W.height
          assert.are.equal(2, canvas:DragIndexAt(bottom + 5, 20, 20, 10), "the cursor is past the bottom, the section's top not")
          assert.are.equal(3, canvas:DragIndexAt(bottom + 15, 20, 20, 10))
        end)

        it("does not move for a cursor just above the spot: a nudge reorders nothing", function()
          canvas:SetColumnSource(function() return 2, "across", true, 3 end)
          sections({ { "T", 8 }, { "U", 8 }, { "W", 9 } })
          draw()
          canvas:BeginDrag(canvas.byName.W)
          draw()
          local where = slot()
          assert.are.equal(3, indexAt(20, where[2] + 8))
          assert.are.equal(3, indexAt(20, where[2] - 2))
          canvas:EndDrag(false)
          sections({ { "T", 8 }, { "W", 9 }, { "U", 8 } })
          draw()
          canvas:BeginDrag(canvas.byName.W)
          draw()
          where = slot()
          assert.are.equal(2, indexAt(20, where[2] - 2), "nor with a hole above it")
        end)

        -- A spanning section a row tall leaves a gap between its slots, where the first place used to be taken.
        it("ends in one place however fast the cursor moves", function()
          for _, frames in ipairs({ 1, 2, 4, 8, 16, 40 }) do
            wide({ { "Wide", 8 }, { "Alpha", 1 }, { "Beta", 1 } })
            canvas:BeginDrag(canvas.byName.Wide)
            draw()
            for i = 1, frames do
              moveTo(20, 10 + ROW * i / frames)
            end
            assert.are.equal(3, index(), frames .. " frames")
            canvas:EndDrag(false)
            draw()
          end
        end)

        it("goes by a place's nearest corner, whatever it spans", function()
          wide({ { "A", 1 }, { "W", 20 }, { "B", 1 } })
          canvas:BeginDrag(canvas.byName.B)
          draw()
          assert.are.equal(1, indexAt(COLUMN / 2 - 1, 10), "nearer the first")
          assert.are.equal(2, indexAt(COLUMN / 2 + 1, 10), "nearer the second, inside the first's width")
        end)

        it("is no spot where the next place at that corner is another size", function()
          canvas:SetColumnSource(function() return 3, "down", true, 2 end)
          sections({ { "S01", 2 }, { "S02", 1 }, { "S03", 3 }, { "S04", 2 } })
          local width = canvas:RowWidth(7)
          draw(width)
          canvas:BeginDrag(canvas.byName.S03)
          draw(width)
          local slots = canvas:dragSlots()
          assert.are.same({ slots[2].x, slots[2].y }, { slots[3].x, slots[3].y })
          assert.is_true(slots[2].width ~= slots[3].width)
          canvas:SetDragIndex(1)
          draw(width)
          assert.are.equal(2, indexAt(slots[2].x + 2, slots[2].y + 2))
        end)

        it("spans only the places side by side in the list and of one size, filling down", function()
          canvas:SetColumnSource(function() return 3, "down", true, 3 end)
          sections({ { "A", 41 }, { "B", 5 }, { "C", 9 }, { "D", 8 }, { "E", 9 }, { "F", 1 }, { "G", 8 }, { "H", 1 } })
          local width = canvas:RowWidth(14)
          draw(width)
          canvas:BeginDrag(canvas.byName.C)
          draw(width)
          local slots = canvas:dragSlots()
          local shared = false
          for i, spot in ipairs(slots) do
            for j, other in ipairs(slots) do
              shared = shared or (i ~= j and other.x == spot.x and other.y == spot.y and other.width ~= spot.width)
            end
          end
          assert.is_true(shared, "the bag has a corner two sizes share")
          for i, spot in ipairs(slots) do
            local to = indexAt(spot.x + 2, spot.y + 2)
            local first
            for _, other in ipairs(slots) do
              if other.x == spot.x and other.y == spot.y then
                first = first or other
              end
            end
            for _, between in ipairs(slots) do
              if between.index >= first.index and between.index <= to then
                assert.are.same({ first.x, first.y, first.width }, { between.x, between.y, between.width }, "place " .. i)
              end
            end
          end
        end)

        it("reaches every spot in random bags, and a pick-up never moves it", function()
          for seed = 1, 60 do
            math.randomseed(seed)
            canvas:SetColumnSource(function() return 2 + seed % 2, seed % 3 == 0 and "down" or "across", true, 2 end)
            local list = {}
            for i = 1, math.random(3, 9) do
              list[i] = { "S" .. string.format("%02d", i), ({ 1, 2, 3, 20, 25 })[math.random(1, 5)] }
            end
            sections(list)
            draw()
            local dragged = canvas.byName[list[math.random(1, #list)][1]]
            canvas:BeginDrag(dragged)
            draw()
            local start = canvas.drag.index
            local where = slot()
            assert.are.equal(start, indexAt(where[1] + 20, where[2] + 8), "picked up, seed " .. seed)
            local spots, reached = {}, 0
            for k = 1, #list do
              canvas:SetDragIndex(k)
              draw()
              spots[slot()[1] .. ":" .. slot()[2]] = slot()
            end
            for _, spot in pairs(spots) do
              canvas:SetDragIndex(indexAt(spot[1] + 3, spot[2] + 3))
              draw()
              assert.are.same(spot, slot(), "spot, seed " .. seed)
              reached = reached + 1
            end
            assert.is_true(reached > 0)
            canvas:SetDragIndex(indexAt(20, 100000))
            draw()
            canvas:EndDrag(false)
            draw()
          end
        end)
      end)

      -- Reported of the review: a section narrowing over a column of fewer cells hopped sideways, off the cursor.
      it("keeps the shape it was picked up in while held, taking its place's when it ends", function()
        canvas:SetColumnSource(function() return 3, "across", false, 2 end)
        sections({ { "A", 3 }, { "B", 1 }, { "C", 1 } })
        draw()
        local a = canvas.byName.A
        local wide, tall = a.frame:GetWidth(), a.frame:GetHeight()
        assert.are.equal(3 * STEP - style.GAP, wide)
        assert.are.equal(height(1), tall)
        canvas:BeginDrag(a)
        draw()
        canvas:SetDragIndex(3)
        draw()
        assert.are.equal(6 * STEP, slot()[1], "over the narrow third column")
        assert.are.same({ wide, tall }, { a.frame:GetWidth(), a.frame:GetHeight() })
        assert.are.equal(height(2), canvas.drag.height, "its room as tall as it will be there")
        canvas:EndDrag(true)
        draw()
        assert.are.same({ 2 * STEP - style.GAP, height(2) }, { a.frame:GetWidth(), a.frame:GetHeight() })
      end)

      it("keeps its height through a drag, so the scroll box never pulls it out from under the cursor", function()
        canvas:SetColumnSource(function() return 2, "across", true, 2 end)
        sections({ { "Back", 1 }, { "W", 20 }, { "Quest", 1 } })
        local before = draw().Height
        canvas:BeginDrag(canvas.byName.W)
        assert.are.equal(before, draw().Height)
        canvas:SetDragIndex(3)
        assert.are.equal(before, draw().Height, "Quest moved up, the bag no shorter")
        assert.are.equal(before, canvas.frame:GetHeight())
        canvas:EndDrag(true)
        assert.is_true(draw().Height < before, "shorter once it ends")
      end)

      it("lets its height go over the time it is told, to where the rows end", function()
        canvas:SetColumnSource(function() return 2, "across", true, 2 end)
        sections({ { "Back", 1 }, { "W", 20 }, { "Quest", 1 } })
        local before = draw().Height
        canvas:BeginDrag(canvas.byName.W)
        draw()
        canvas:SetDragIndex(3)
        draw()
        assert.are.equal(ROW, canvas:HeldHeightExtra(), "Quest went up a row")
        canvas:ReleaseHeight(0.2)
        draw()
        tween.driver:GetScript("OnUpdate")(tween.driver, 0.1)
        local partWay = draw().Height
        assert.is_true(partWay < before)
        finishTweens()
        local after = draw().Height
        assert.is_true(after < partWay)
        assert.are.equal(0, canvas:HeldHeightExtra())
        canvas:EndDrag(true)
        assert.are.equal(after, draw().Height)
      end)

      -- A drop can move the room and ask for the height in one frame, before any render has seen the room's new place.
      it("comes down to where the rows end after a room moved just before it was asked", function()
        canvas:SetColumnSource(function() return 2, "across", true, 2 end)
        sections({ { "Back", 1 }, { "W", 20 }, { "Quest", 1 } })
        local before = draw().Height
        canvas:BeginDrag(canvas.byName.W)
        draw()
        canvas:SetDragIndex(3)
        canvas:ReleaseHeight(0.2)
        assert.are.equal(before, draw().Height, "starts from what it held")
        tween.driver:GetScript("OnUpdate")(tween.driver, 0.1)
        local partWay = draw().Height
        assert.is_true(partWay < before)
        finishTweens()
        assert.are.equal(before - ROW, draw().Height)
      end)

      it("is down in the time it is told, rendered every step of the way", function()
        canvas:SetColumnSource(function() return 2, "across", true, 2 end)
        sections({ { "Back", 1 }, { "W", 20 }, { "Quest", 1 } })
        local before = draw().Height
        canvas:BeginDrag(canvas.byName.W)
        draw()
        canvas:SetDragIndex(3)
        draw()
        canvas:ReleaseHeight(0.2)
        draw()
        for _ = 1, 5 do
          local update = tween.driver:GetScript("OnUpdate")
          if update ~= nil then
            update(tween.driver, 0.05)
          end
          draw()
        end
        assert.are.equal(before - ROW, draw().Height)
      end)

      it("asks for no render when the height it holds is where the rows end", function()
        canvas:SetColumnSource(function() return 2, "across", true, 2 end)
        sections({ { "A", 1 }, { "B", 1 } })
        draw()
        canvas:BeginDrag(canvas.byName.A)
        draw()
        canvas:ReleaseHeight(0.2)
        draw()
        local real, asked = canvas.Invalidate, 0
        canvas.Invalidate = function(...)
          asked = asked + 1
          return real(...)
        end
        finishTweens()
        canvas.Invalidate = nil
        assert.are.equal(0, asked)
      end)

      it("lays it out once for a read that lands while it lands", function()
        canvas:SetColumnSource(function() return 2, "across", true, 2 end)
        sections({ { "Back", 1 }, { "W", 20 }, { "Quest", 1 } })
        draw()
        local w = canvas.byName.W
        canvas:BeginDrag(w)
        draw()
        canvas:ReleaseHeight(0.2)
        draw()
        local real, laidOut = canvas.LayoutSection, 0
        canvas.LayoutSection = function(self, section, ...)
          if section == w then
            laidOut = laidOut + 1
          end
          return real(self, section, ...)
        end
        sections({ { "Back", 1 }, { "W", 22 }, { "Quest", 1 } })
        draw()
        assert.are.equal(1, laidOut, "its new items placed")
        draw()
        canvas.LayoutSection = nil
        assert.are.equal(1, laidOut, "and left alone again")
      end)

      it("does not bounce when a read lands while it comes down", function()
        canvas:SetColumnSource(function() return 2, "across", true, 2 end)
        sections({ { "Back", 1 }, { "W", 20 }, { "Quest", 1 } })
        draw()
        canvas:BeginDrag(canvas.byName.W)
        draw()
        canvas:SetDragIndex(3)
        draw()
        canvas:ReleaseHeight(0.2)
        draw()
        tween.driver:GetScript("OnUpdate")(tween.driver, 0.05)
        draw()
        sections({ { "Back", 1 }, { "W", 20 }, { "Quest", 1 } })
        local atTheRead = draw().Height
        if tween.driver and tween.driver:GetScript("OnUpdate") then
          tween.driver:GetScript("OnUpdate")(tween.driver, 0.05)
        end
        assert.is_true(draw().Height <= atTheRead)
      end)

      -- Its frame changes scale as it lands: laid out on each frame's new grid it would restyle every button, every frame.
      it("leaves the section alone while it lands", function()
        canvas:SetColumnSource(function() return 2, "across", true, 2 end)
        sections({ { "Back", 1 }, { "W", 20 }, { "Quest", 1 } })
        draw()
        local w = canvas.byName.W
        canvas:BeginDrag(w)
        draw()
        canvas:SetDragIndex(3)
        draw()
        canvas:ReleaseHeight(0.2)
        local real, laidOut = canvas.LayoutSection, 0
        canvas.LayoutSection = function(self, section, ...)
          if section == w then
            laidOut = laidOut + 1
          end
          return real(self, section, ...)
        end
        draw()
        tween.driver:GetScript("OnUpdate")(tween.driver, 0.1)
        draw()
        assert.are.equal(0, laidOut)
        canvas:EndDrag(true)
        draw()
        canvas.LayoutSection = nil
        assert.are.equal(1, laidOut, "once it is back")
      end)

      it("works its slots out again when its fill, wide sections or limit change, with no read", function()
        for _, source in ipairs({ { 2, "down", true, 2, 1 }, { 2, "across", false, 2, 12 }, { 2, "across", true, 5, 12 } }) do
          canvas:SetColumnSource(function() return 2, "across", true, 2 end)
          sections({ { "W", source[5] }, { "V", source[5] == 1 and 1 or 7 }, { "B", 1 }, { "C", 1 } })
          draw()
          canvas:BeginDrag(canvas.byName.C)
          draw()
          indexAt(10, 10)
          canvas:SetColumnSource(function() return source[1], source[2], source[3], source[4] end)
          canvas.heldCells = {}
          draw()
          for _, spot in ipairs(canvas:dragSlots()) do
            canvas:SetDragIndex(spot.index)
            draw()
            assert.are.same({ spot.x, spot.y }, slot(), source[2] .. " place " .. spot.index)
          end
          canvas:EndDrag(false)
          draw()
        end
      end)

      it("lets its height go when a read changes what its sections hold", function()
        canvas:SetColumnSource(function() return 2, "across", true, 2 end)
        sections({ { "Back", 1 }, { "W", 20 }, { "Quest", 1 } })
        local before = draw().Height
        canvas:BeginDrag(canvas.byName.W)
        draw()
        sections({ { "Back", 1 }, { "W", 1 }, { "Quest", 1 } })
        assert.is_true(draw().Height < before)
      end)

      it("works its slots out again when it lets go of the widths it holds", function()
        canvas:SetColumnSource(function() return 2, "across", true, 3 end)
        sections({ { "A", 9 }, { "B", 1 }, { "C", 1 } })
        draw()
        sections({ { "A", 1 }, { "B", 1 }, { "C", 1 } })
        draw()
        canvas:BeginDrag(canvas.byName.C)
        draw()
        indexAt(10, 10)
        canvas:ReleaseWidths()
        draw()
        canvas:SetDragIndex(indexAt(COLUMN + 5, 5))
        draw()
        assert.are.same({ COLUMN, 0 }, slot(), "A no longer spans")
      end)

      it("keeps the room's height for a report", function()
        canvas:SetColumnSource(function() return 2, "across", true, 2 end)
        sections({ { "A", 4 }, { "B", 1 } })
        draw()
        canvas:BeginDrag(canvas.byName.A)
        canvas.drag.height = 0
        draw()
        assert.are.equal(height(1), canvas.drag.height)
      end)

      it("never passes Recent Items or Free Space", function()
        sections({ { "A", 1 }, { "B", 1 }, { "C", 1 } }, {
          recent = { item("0_50", "Recent Items") },
          free = { showAll = true, buttons = { { slotkey = "0_60", data = item("0_60", "Free Space") } } },
        })
        draw()
        assert.are.equal("Recent Items", names()[1])
        canvas:BeginDrag(canvas.byName.B)
        draw()
        moveTo(10, -100)
        canvas:EndDrag(true)
        local after = names()
        assert.are.same({ "Recent Items", "B", "A", "C" }, { after[1], after[2], after[3], after[4] })
        canvas:BeginDrag(canvas.byName.B)
        draw()
        moveTo(COLUMN + 10, 100000)
        canvas:EndDrag(true)
        after = names()
        assert.are.equal("B", after[#after - 1], "before Free Space")
      end)

      it("works its slots out again when a read changes what its sections hold", function()
        canvas:BeginDrag(canvas.byName.D)
        draw()
        indexAt(10, ROW + 10)
        sections({ { "A", 9 }, { "B", 9 }, { "C", 1 }, { "D", 1 } })
        draw()
        local tall = canvas.byName.A.height + SPACING
        assert.is_true(tall > ROW)
        canvas:SetDragIndex(indexAt(10, tall + 5))
        draw()
        assert.are.equal(tall, slot()[2])
        canvas:SetDragIndex(indexAt(10, ROW + 5))
        draw()
        assert.are.same({ 0, 0 }, slot(), "where the second row was is the first row's now")
      end)

      it("works its slots out again when its columns change, with no read", function()
        canvas:BeginDrag(canvas.byName.D)
        draw()
        indexAt(10, 10)
        columns(3, "across")
        draw()
        canvas:SetDragIndex(indexAt(3 * STEP + 5, 5))
        draw()
        assert.are.same({ 3 * STEP, 0 }, slot(), "beside A, in a narrower column")
      end)

      it("works its slots out once, however often the cursor moves, asked before its first render too", function()
        canvas:BeginDrag(canvas.byName.D)
        indexAt(10, 10)
        draw()
        local real, measured = canvas.MeasureSection, 0
        canvas.MeasureSection = function(...)
          measured = measured + 1
          return real(...)
        end
        indexAt(COLUMN + 10, 10)
        indexAt(10, ROW + 10)
        canvas.MeasureSection = nil
        assert.are.equal(0, measured)
      end)

      -- The hard rule holds with the room in any place, in both fills: rows line up and nothing overlaps.
      it("keeps every row on its line with the room anywhere, its slot where it said, across random bags", function()
        for seed = 1, 40 do
          math.randomseed(seed)
          local fill = seed % 2 == 0 and "across" or "down"
          canvas:SetColumnSource(function() return 2 + seed % 3, fill, seed % 4 ~= 0, 2 end)
          local list = {}
          for i = 1, math.random(2, 12) do list[i] = { "S" .. string.format("%02d", i), math.random(1, 30) } end
          sections(list)
          draw()
          local dragged = canvas.byName[list[math.random(1, #list)][1]]
          canvas:BeginDrag(dragged)
          draw()
          for k = 1, #list do
            canvas:SetDragIndex(k)
            draw()
            local rx, ry = canvas:GetDragSlotX(), canvas:GetDragSlotY()
            local seen = {}
            seen[rx .. ":" .. ry] = true
            for _, s in ipairs(canvas.order) do
              if s ~= dragged then
                local key = s.x .. ":" .. s.y
                assert.is_nil(seen[key], "two in one place, seed " .. seed)
                seen[key] = true
              end
            end
            -- The cursor on the slot sends it to a place with that slot.
            local to = indexAt(rx + 2, ry + 2)
            canvas:SetDragIndex(to)
            draw()
            assert.are.same({ rx, ry }, { canvas:GetDragSlotX(), canvas:GetDragSlotY() }, "seed " .. seed .. " place " .. k)
          end
          canvas:EndDrag(false)
          draw()
        end
      end)

      it("still reads a height in one column", function()
        columns(1, "across")
        draw()
        canvas:BeginDrag(canvas.byName.C)
        draw()
        assert.are.equal(1, indexAt(0, 0))
        canvas:EndDrag(false)
      end)
    end)

    describe("what moves", function()
      it("keeps a dragged section's place in its column, the others staying put", function()
        columns(2, "across")
        sections({ { "A", 1 }, { "B", 1 }, { "C", 1 } })
        draw()
        assert.is_not_nil(canvas.grid)
        canvas:BeginDrag(canvas.byName.B)
        draw()
        assert.are.same({ 4 * STEP, 0 }, { canvas:GetDragSlotX(), canvas:GetDragSlotY() })
        assert.are.same({ 0, 0 }, place("A"))
        assert.are.same({ 0, height(1) + SPACING }, place("C"))
        canvas:EndDrag(false)
        draw()
        assert.are.same({ 4 * STEP, 0 }, place("B"))
      end)

      it("lands a drag at the left in one column", function()
        sections({ { "A", 1 }, { "B", 1 } })
        draw()
        assert.are.equal(0, canvas.byName.B.x)
      end)

      it("closes up over a section held out, and keeps its room while it flies back", function()
        columns(2, "across")
        sections({ { "A", 1 }, { "B", 1 }, { "C", 1 } })
        draw()
        local b = canvas.byName.B
        canvas:HoldOut(b)
        draw()
        assert.are.equal(4 * STEP, canvas.byName.C.x, "C takes B's place")
        canvas:Returning(b)
        draw()
        assert.are.equal(4 * STEP, b.x)
        assert.are.equal(0, canvas.byName.C.x)
        canvas:Return(b)
        assert.are.same({ canvas.frame, 4 * STEP, 0 }, { at(b.frame) })
      end)

      it("closes up over a section leaving", function()
        columns(2, "across")
        sections({ { "A", 1 }, { "B", 1 }, { "C", 1 } })
        canvas:MarkLeaving("A", 3)
        draw()
        assert.is_false(canvas.byName.A.frame:IsShown())
        assert.are.same({ 0, 0 }, place("B"))
        assert.are.same({ 4 * STEP, 0 }, place("C"))
      end)
    end)

    describe("how wide it needs to be", function()
      it("needs its columns' cells, at most its largest section's in each", function()
        columns(2, "across")
        sections({ { "A", 3 }, { "B", 1 } })
        draw()
        assert.are.equal(6, canvas:Widest(canvas:RowWidth(12)))
      end)

      it("never needs so little its columns would go", function()
        columns(2, "across")
        sections({ { "A", 1 }, { "B", 1 } })
        draw()
        assert.are.equal(4, canvas:Widest(canvas:RowWidth(12)))
      end)

      it("needs what Recent Items holds, at the full width", function()
        columns(2, "across")
        local recent = {}
        for i = 1, 7 do recent[i] = item("0_9" .. i, "Recent Items") end
        sections({ { "A", 1 }, { "B", 1 } }, { recent = recent })
        draw()
        assert.are.equal(7, canvas:Widest(canvas:RowWidth(12)))
      end)

      it("needs its largest section's at one column", function()
        sections({ { "A", 3 }, { "B", 1 } })
        draw()
        assert.are.equal(3, canvas:Widest(canvas:RowWidth(12)))
        assert.are.equal(3, canvas:Widest())
      end)
    end)
  end)

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
  describe("a section's header art", function()
    it("keeps its end cap's shape in a narrower section: the fill's pieces", function()
      override(style.Theme.Sections, "Header", { Pieces = "Horizontal", Texture = "Glow", Color = "Gold", Height = 20,
        Begin = { TexCoords = { 0, 0.0625, 0, 1 }, Size = 20 }, Middle = { TexCoords = { 0.0625, 1, 0, 1 } } })
      bind(data({ categories = { { name = "A" } }, items = { item("0_1", "A") } }))
      draw()
      canvas:ApplyStyle(context:New("spec"))
      local fill = canvas.byName.A.rowFill
      assert.are.equal(20, fill.Begin:GetWidth())
      assert.is_true(fill.Begin:IsShown())
      assert.is_true(canvas.byName.A.row:IsShown())
      local _, relative = canvas.byName.A.row:GetPoint(1)
      assert.are.equal(fill.Begin, relative)
    end)

    it("draws no art for a theme without any, and hides its cap too", function()
      override(style.Theme.Sections, "Header", { Pieces = "Horizontal", Texture = "Glow", Color = "Gold", Height = 20,
        Begin = { Size = 20 } })
      bind(data({ categories = { { name = "A" } }, items = { item("0_1", "A") } }))
      draw()
      canvas:ApplyStyle(context:New("spec"))
      override(style.Theme.Sections, "Header", false)
      canvas:ApplyStyle(context:New("spec"))
      assert.is_false(canvas.byName.A.row:IsShown())
      assert.is_false(canvas.byName.A.rowFill.Begin:IsShown())
    end)
  end)

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
      assert.are.same({ "TOPLEFT", s.rowArea, "TOPLEFT", 0, 0 }, { s.row:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", s.rowArea, "BOTTOMRIGHT", 0, 0 }, { s.row:GetPoint(2) })
      assert.are.same({ "TOPLEFT", s.inner, "TOPLEFT", 0, 0 }, { s.rowArea:GetPoint(1) })
      assert.are.same({ "TOPRIGHT", s.inner, "TOPRIGHT", 0, 0 }, { s.rowArea:GetPoint(2) })
      assert.are.equal(32, s.row:GetHeight())
      assert.are.equal("BACKGROUND", s.row:GetDrawLayer(), "behind the title, the count and the line")
      assert.is_true(s.row:IsShown())
      UseNextTheme(nil)
      canvas:ApplyStyle(context:New("spec"))
      assert.is_false(s.row:IsShown())
    end)

    -- Reported with the Make It So theme: a bar as tall as its row sat right on the first row of icons. Its art may be
    -- shorter than the row (Height), from its top, the cells still under the whole row.
    it("draws its row's art Height tall from the row's top, its cells still under the whole row", function()
      sections()
      UseNextTheme({ Layout = { SectionHeader = 28 },
        Sections = { Header = { Texture = "Interface\\Spec\\sep.png", Color = "White", Height = 20 } } })
      canvas:ApplyStyle(context:New("spec"))
      draw()
      local s = canvas.byName.A
      assert.are.equal(20, s.row:GetHeight())
      assert.are.equal(20, s.rowArea:GetHeight())
      assert.are.same({ "TOPLEFT", s.inner, "TOPLEFT", 0, 0 }, { s.rowArea:GetPoint(1) })
      assert.are.same({ "TOPLEFT", s.inner, "TOPLEFT", 0, -28 }, { s.cells:GetPoint(1) })
      assert.are.equal(28, s.header:GetHeight())
      UseNextTheme(nil)
      canvas:ApplyStyle(context:New("spec"))
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
