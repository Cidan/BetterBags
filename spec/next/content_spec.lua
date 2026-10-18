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

  it("fits fewer icons to a row in a narrower width", function()
    local items = {}
    for i = 1, 6 do table.insert(items, item("0_" .. i, "A")) end
    bind(data({ categories = { { name = "A" } }, items = items }))
    draw(5 * STEP - style.GAP)
    assert.are.same({ canvas.order[1].cells, 0, -STEP }, { at(buttons["0_6"].frame) })
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
      assert.is_true(style.Time.MakeRoom < 0.3)
      motion:Step(style.Time.MakeRoom / 4)
      local moved = y(s.A)
      assert.is_true(moved > 0 and moved < ONE * 0.25, "starts slow: " .. moved)
      motion:Step(style.Time.MakeRoom * 3 / 4)
      assert.are.equal(ONE, y(s.A))
      assert.is_nil(motion:GetMove(s.A.frame))
    end)

    it("moves sections at the usual speed once nothing is dragged", function()
      local s = threeSections()
      canvas:BeginDrag(s.B)
      canvas:SetDragIndex(3)
      canvas:EndDrag(true)
      draw()
      assert.is_not_nil(motion:GetMove(s.C.frame))
      motion:Step(style.Time.MakeRoom)
      assert.is_not_nil(motion:GetMove(s.C.frame), "still moving")
      motion:Step(0.3 - style.Time.MakeRoom)
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
