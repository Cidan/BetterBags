-- dock_spec.lua -- NextDock (next/dock.lua): sections waiting in a panel for the player (next.md §7,
-- "Docked sections"). Asked: "we probably have a list of categories that move over to the vendor
-- window (scroll the vendor window if needed) to double click to sell, and selling (or cancelling)
-- animates the next section to the position above it (can autosell a section in the middle, for
-- example)"; the destroy section "should function just like the above, but with a red outline".
-- One interface for every confirmed move (CLAUDE.md, "UI Consistency" 5): a section dragged onto the
-- vendor or the guild bank, a category Auto Sell offers, a category's items to destroy.
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

local itemFrame = trackStub("ItemFrame")
local originalGetButton = itemFrame.GetButton
local buttons = {}
itemFrame.GetButton = function(_, _, slotkey)
  if buttons[slotkey] == nil then
    local b = { slotkey = slotkey, frame = CreateFrame("Frame") }
    b.frame:SetSize(37, 37)
    function b:SetItemFromData() end
    function b:SetSize(_, w, h) self.frame:SetSize(w, h) end
    buttons[slotkey] = b
  end
  return buttons[slotkey]
end

LoadBetterBagsModule("render/render.lua")
LoadBetterBagsModule("render/drawable.lua")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextLift", "next/lift.lua" }, { "NextContent", "next/content.lua" }, { "NextDockCard", "next/dockcard.lua" },
  { "NextDock", "next/dock.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local nextDock = addon:GetModule("NextDock")
local nextContent = addon:GetModule("NextContent")
local style = addon:GetModule("NextStyle")
local tween = addon:GetModule("NextTween")
local motion = addon:GetModule("Motion")
local render = addon:GetModule("Render")
local lift = addon:GetModule("NextLift")
local context = addon:GetModule("Context")

describe("NextDock", function()
  local source, target

  local function ctx() return context:New("spec") end

  local function finishTweens()
    for _ = 1, 400 do
      local update = tween.driver and tween.driver:GetScript("OnUpdate")
      if update == nil then return end
      update(tween.driver, 0.05)
    end
  end

  local function draw(canvas)
    return render:NewRenderChain(canvas, { ctx = ctx() }, { Width = style.GRID_WIDTH })
  end

  local function settle()
    draw(source.content)
    draw(target.content)
    motion:Step(1)
  end

  -- panel makes a panel: a frame, its canvas, its scroll area and its tabs.
  local function panel()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Show()
    local p = { frame = frame, content = nextContent:Create(frame), pulsed = {} }
    p.scroll = { frame = CreateFrame("Frame", nil, frame) }
    p.scroll.frame:_SetRect(0, 0, 400, 600)
    p.tabs = { Pulse = function(_, id) table.insert(p.pulsed, id) end }
    return p
  end

  local function item(slotkey, category)
    return { slotkey = slotkey, itemInfo = { category = category } }
  end

  -- bindSource binds categories to the bag, one item each by default.
  local function bindSource(names, extra)
    local categories, list = {}, {}
    for i, name in ipairs(names) do
      table.insert(categories, { name = name })
      table.insert(list, item("0_" .. i, name))
    end
    for _, it in ipairs(extra or {}) do table.insert(list, it) end
    source.content:Bind(ctx(), { sortedItems = {}, tabs = { [1] = { categories = categories, items = list } } }, 1, {})
    draw(source.content)
  end

  local function section(name)
    return source.content.byName[name]
  end

  -- offer is what a docked section is for, recording what it is asked.
  local function offer(opts)
    opts = opts or {}
    local o = { confirms = 0, clicks = 0, title = opts.title or "Sell 2 items?" }
    o.text = function() return o.title, "Only the last 12 items sold can be bought back.", "Double-click to sell" end
    if opts.color then
      o.color = function() return o.colorName end
      o.colorName = opts.color
    end
    o.confirm = function()
      o.confirms = o.confirms + 1
      return o.answer
    end
    if opts.click then
      o.click = function()
        o.clicks = o.clicks + 1
        return o.answer
      end
    end
    o.answer = opts.answer
    return o
  end

  local function dock(name, o)
    return nextDock:Add(target, { section = section(name), source = source, offer = o or offer() })
  end

  local function click(entry, button)
    entry.catcher:GetScript("OnClick")(entry.catcher, button or "LeftButton")
  end

  local function doubleClick(entry)
    entry.catcher:GetScript("OnDoubleClick")(entry.catcher, "LeftButton")
  end

  local function topOf(frame)
    local _, _, _, _, y = frame:GetPoint(1)
    return -y
  end

  before_each(function()
    UseNextTheme(nil)
    render:Init()
    tween:Init()
    motion:Init()
    nextDock:Init()
    source, target = panel(), panel()
    bindSource({ "A", "B", "C" })
    draw(target.content)
  end)

  teardown(function()
    L.G = originalG
    itemFrame.GetButton = originalGetButton
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  describe("docking", function()
    it("takes the section out of its bag into a card at the top of the panel's column", function()
      local entry = dock("B")
      assert.is_true(source.content:IsAway(section("B")))
      settle()
      assert.are.equal(entry.box.frame, section("B").frame:GetParent())
      assert.are.same({ "TOPLEFT", entry.box.slot, "TOPLEFT", 0, 0 }, { section("B").frame:GetPoint(1) })
      local leads = target.content.lead(style.GRID_WIDTH)
      assert.are.equal(1, #leads)
      assert.are.equal(entry.holder, leads[1].frame)
      assert.are.equal(0, topOf(entry.holder), "first in the column")
      assert.is_true(entry.holder:IsShown())
    end)

    it("says what its offer says, in the dock's look", function()
      local entry = dock("B", offer({ title = "Sell 23 items?" }))
      settle()
      assert.are.same({ "Sell 23 items?", "Only the last 12 items sold can be bought back.", "Double-click to sell" },
        { entry.box.title:GetText(), entry.box.warning:GetText(), entry.box.hint:GetText() })
      local r, g, b = entry.box.glow[1]:GetVertexColor()
      assert.are.same({ style:RGBA(style.Theme.Dock.Glow.Color) }, { r, g, b, 1 })
    end)

    -- Asked: "with a red outline like we have now, when it's destroying".
    it("glows in the color its offer gives", function()
      local entry = dock("B", offer({ color = style.Theme.Dock.DestroyColor }))
      settle()
      local r, g, b = entry.box.glow[1]:GetVertexColor()
      local er, eg, eb = style:RGBA(style.Theme.Dock.DestroyColor)
      assert.are.same({ er, eg, eb }, { r, g, b })
    end)

    it("fits the section in the column, its card's halo inside it", function()
      local entry = dock("B")
      settle()
      local D = style.Theme.Dock
      local s = section("B").frame:GetScale()
      assert.is_true(s < 1)
      assert.is_true(math.abs(section("B").frame:GetWidth() * s + 2 * D.Pad - entry.box.frame:GetWidth()) < 1e-6)
      assert.is_true(entry.box.frame:GetWidth() + 2 * D.Halo.Spread <= style.GRID_WIDTH + 1e-6)
      assert.are.same({ "TOP", entry.holder, "TOP", 0, -D.Halo.Spread }, { entry.box.frame:GetPoint(1) })
    end)

    it("flies the section from where it was into its card", function()
      section("B").frame:_SetRect(100, 300, style.GRID_WIDTH, 60)
      local entry = dock("B")
      assert.are.equal(lift.layer, section("B").frame:GetParent(), "on its way")
      settle()
      finishTweens()
      assert.are.equal(entry.box.frame, section("B").frame:GetParent())
      assert.is_true(entry.scale < 1)
      assert.are.equal(entry.scale, section("B").frame:GetScale(), "seated at the card's scale")
    end)

    it("lays the column out again when its section's size changes", function()
      local entry = dock("B")
      settle()
      local driver = nextDock:ListOf(target).driver
      driver:GetScript("OnUpdate")(driver, 0.01)
      render:Flush()
      driver:GetScript("OnUpdate")(driver, 0.01)
      assert.is_false(render:IsDirty(target.content), "nothing changed")
      bindSource({ "A", "B", "C" }, { item("0_8", "B"), item("0_9", "B"), item("1_1", "B"), item("1_2", "B"),
        item("1_3", "B"), item("1_4", "B"), item("1_5", "B"), item("1_6", "B"), item("1_7", "B") })
      driver:GetScript("OnUpdate")(driver, 0.01)
      assert.is_true(render:IsDirty(target.content))
      local before = entry.box.frame:GetHeight()
      draw(target.content)
      assert.is_true(entry.box.frame:GetHeight() > before)
    end)

    it("keeps the clicks from the section's item buttons", function()
      local entry = dock("B")
      settle()
      assert.is_true(entry.catcher:GetFrameLevel() > lift:MaxLevel(section("B").frame))
      assert.is_true(entry.catcher:IsMouseEnabled())
    end)

    it("docks a section once", function()
      local first = dock("B")
      assert.are.equal(first, dock("B"))
      assert.are.equal(1, #nextDock:Entries(target))
      assert.are.equal(first, nextDock:EntryOf(target, "B"))
      assert.is_nil(nextDock:EntryOf(target, "A"))
    end)

    it("stacks the sections one under another, in the order they came", function()
      local b, a = dock("B"), dock("A")
      settle()
      assert.are.same({ b, a }, nextDock:Entries(target))
      local D = style.Theme.Dock
      assert.are.equal(D.Halo.Spread + b.box.frame:GetHeight() + style.SECTION_SPACING, topOf(a.holder))
    end)

    -- Asked: "scroll the vendor window if needed".
    it("scrolls the panel, a frame after its column is laid out, to show a card out of view", function()
      local timers, scrolled = {}, {}
      local originalAfter = C_Timer.After
      C_Timer.After = function(_, fn) table.insert(timers, fn) end
      local offset = 500
      target.scroll.scrollBox = {
        GetDerivedScrollOffset = function() return offset end,
        GetVisibleExtent = function() return 300 end,
        ScrollToOffset = function(_, to) table.insert(scrolled, to) offset = to end,
      }
      local first = dock("B")
      draw(target.content)
      assert.are.same({}, scrolled, "not while it is laid out")
      for _, fn in ipairs(timers) do fn() end
      timers = {}
      assert.are.same({ 0 }, scrolled, "up to the card's top")
      target.scroll.scrollBox.GetVisibleExtent = function() return 5000 end
      dock("A")
      draw(target.content)
      for _, fn in ipairs(timers) do fn() end
      timers = {}
      assert.are.same({ 0 }, scrolled, "already in view: no scroll")
      target.scroll.scrollBox.GetVisibleExtent = function() return first.bottom end
      local third = dock("C")
      draw(target.content)
      for _, fn in ipairs(timers) do fn() end
      C_Timer.After = originalAfter
      assert.are.same({ 0, third.bottom - first.bottom }, scrolled, "down until the card's bottom shows")
    end)

    it("pulses its cards", function()
      local entry = dock("B")
      settle()
      local driver = nextDock:ListOf(target).driver
      local alphas = {}
      for _ = 1, 6 do
        driver:GetScript("OnUpdate")(driver, 0.2)
        table.insert(alphas, entry.box.glow[1]:GetAlpha())
      end
      assert.is_true(math.max(unpack(alphas)) - math.min(unpack(alphas)) > 0.3)
    end)
  end)

  describe("answering", function()
    it("does what the double click confirms: moved, the section flies into the panel and leaves its bag", function()
      local o = offer({ answer = "moved" })
      local b = dock("B", o)
      local a = dock("A")
      settle()
      local before = topOf(a.holder)
      doubleClick(b)
      assert.are.equal(1, o.confirms)
      assert.are.same({ a }, nextDock:Entries(target))
      draw(target.content)
      local _, y0, _, y1 = motion:GetMove(a.holder)
      assert.are.same({ -before, 0 }, { y0, y1 }, "the next slides up into its place")
      finishTweens()
      assert.are.equal(source.content.frame, section("B").frame:GetParent())
      assert.is_false(section("B").frame:IsShown())
      assert.is_false(source.content:IsAway(section("B")))
      assert.is_true(source.content:IsLeaving(section("B")))
      assert.is_false(b.holder:IsShown())
    end)

    it("pulses the tab a section came in by when it moves", function()
      local entry = nextDock:Add(target, { section = section("B"), source = source, offer = offer({ answer = "moved" }),
        tab = { id = 4, button = CreateFrame("Button") } })
      settle()
      doubleClick(entry)
      finishTweens()
      assert.are.same({ 4 }, target.pulsed)
    end)

    it("keeps it waiting, restyled, when the offer stays", function()
      local o = offer({ answer = "stay" })
      local entry = dock("B", o)
      settle()
      o.title, o.colorName = "Destroy 1 item", style.Theme.Dock.DestroyColor
      o.color = function() return o.colorName end
      doubleClick(entry)
      settle()
      assert.are.same({ entry }, nextDock:Entries(target))
      assert.are.equal("Destroy 1 item", entry.box.title:GetText())
      local r, g, b = entry.box.glow[1]:GetVertexColor()
      local er, eg, eb = style:RGBA(style.Theme.Dock.DestroyColor)
      assert.are.same({ er, eg, eb }, { r, g, b })
    end)

    it("does nothing on a double click the offer does not act on", function()
      local entry = dock("B", offer())
      settle()
      doubleClick(entry)
      assert.are.same({ entry }, nextDock:Entries(target))
      assert.are.equal(entry.box.frame, section("B").frame:GetParent())
    end)

    it("leaves a single click to the offer: nothing for a sale, one item for a destroy", function()
      local sale = offer()
      local entry = dock("B", sale)
      settle()
      click(entry)
      assert.are.equal(0, sale.confirms)
      local destroy = offer({ click = true, answer = "stay" })
      local other = dock("A", destroy)
      settle()
      click(other)
      assert.are.equal(1, destroy.clicks)
      assert.are.same({ entry, other }, nextDock:Entries(target))
    end)

    it("sends it back when the offer says so", function()
      local entry = dock("B", offer({ click = true, answer = "back" }))
      settle()
      click(entry)
      settle()
      finishTweens()
      assert.are.same({}, nextDock:Entries(target))
      assert.are.equal(source.content.frame, section("B").frame:GetParent())
    end)

    it("aims at its place in its bag as it flies back", function()
      section("B").frame:_SetRect(100, 300, style.GRID_WIDTH, 60)
      source.content.frame:_SetRect(20, 0, style.GRID_WIDTH, 1000)
      local entry = dock("B")
      settle()
      finishTweens()
      click(entry, "RightButton")
      draw(source.content)
      source.content.frame:_SetRect(20, 0, style.GRID_WIDTH, 1000)
      tween:Step(style.Time.Land - 0.001)
      tween:Step(0.0005)
      local frame = section("B").frame
      local s = frame:GetScale()
      local _, _, _, ox, oy = frame:GetPoint(1)
      assert.is_true(math.abs(ox * s - 20) < 0.5)
      assert.is_true(math.abs(oy * s - (1000 - section("B").y)) < 0.5, "its place: " .. oy * s)
    end)

    it("sends it back to its place in its bag on a right click", function()
      section("B").frame:_SetRect(100, 300, style.GRID_WIDTH, 60)
      local o = offer()
      local entry = dock("B", o)
      settle()
      finishTweens()
      click(entry, "RightButton")
      assert.are.equal(0, o.confirms)
      assert.are.same({}, nextDock:Entries(target))
      assert.is_true(source.content:IsAway(section("B")), "flying back")
      draw(source.content)
      finishTweens()
      motion:Step(1)
      assert.is_false(source.content:IsAway(section("B")))
      assert.are.equal(source.content.frame, section("B").frame:GetParent())
      assert.are.equal(1, section("B").frame:GetScale())
      assert.are.equal(section("B").y, topOf(section("B").frame))
      assert.is_true(section("B").frame:IsShown())
      assert.is_true(topOf(section("C").frame) > section("B").y, "C made room below it")
    end)
  end)

  -- A sale takes a while (the seller sends one item at a time): its card waits on, says what is left as
  -- it goes, and answers once the sale ends.
  describe("answering later", function()
    it("tells its offer it is docked, with its entry", function()
      local seen
      local o = offer()
      o.docked = function(entry) seen = entry end
      local entry = dock("B", o)
      assert.are.equal(entry, seen)
    end)

    it("takes an answer from its offer later, the next sliding up", function()
      local b = dock("B", offer())
      local a = dock("A")
      settle()
      nextDock:Answer(b, "moved")
      assert.are.same({ a }, nextDock:Entries(target))
      finishTweens()
      assert.is_true(source.content:IsLeaving(section("B")))
      nextDock:Answer(a, "back")
      finishTweens()
      assert.are.same({}, nextDock:Entries(target))
      assert.is_false(source.content:IsAway(section("A")))
      nextDock:Answer(a, "moved")
      assert.is_false(source.content:IsLeaving(section("A")), "nothing for one no longer docked")
    end)

    -- A sale that ends as it starts (the merchant buys nothing) answers while its double click is still
    -- answering.
    it("does nothing with an answer for a section already gone", function()
      local o = offer()
      local reads = 0
      local text = o.text
      o.text = function() reads = reads + 1 return text() end
      local entry
      o.confirm = function()
        nextDock:Answer(entry, "back")
        return "moved"
      end
      entry = dock("B", o)
      settle()
      local before = reads
      doubleClick(entry)
      assert.are.equal(before, reads, "not read again")
      assert.are.same({}, nextDock:Entries(target))
      assert.are.equal(1, #nextDock:ListOf(target).free, "its card freed once")
      finishTweens()
      assert.is_false(source.content:IsLeaving(section("B")), "sent back, not moved")
    end)

    it("reads its card again when its offer asks", function()
      local o = offer({ title = "Selling 3 items..." })
      local entry = dock("B", o)
      settle()
      o.title = "Selling 2 items..."
      nextDock:Refresh(entry)
      assert.are.equal("Selling 2 items...", entry.box.title:GetText())
    end)

    it("tells its offer to stop when it leaves the dock, whichever way", function()
      local stopped = {}
      local function stopping(name)
        local o = offer({ answer = "moved" })
        o.cancel = function() table.insert(stopped, name) end
        return o
      end
      local b = dock("B", stopping("B"))
      local a = dock("A", stopping("A"))
      local c = dock("C", stopping("C"))
      settle()
      click(b, "RightButton")
      assert.are.same({ "B" }, stopped)
      doubleClick(a)
      assert.are.same({ "B", "A" }, stopped, "moved")
      nextDock:PanelHidden(target)
      assert.are.same({ "B", "A", "C" }, stopped, "the panel closed")
      local _ = c
    end)
  end)

  describe("ending", function()
    it("goes when its section leaves its bag's data, giving the frame back first", function()
      local entry = dock("B")
      settle()
      bindSource({ "A", "C" })
      assert.are.same({}, nextDock:Entries(target))
      assert.are.equal(source.content.frame, section("A").frame:GetParent())
      assert.is_false(entry.holder:IsShown())
      local pooled = source.content.pool[#source.content.pool]
      assert.are.equal(source.content.frame, pooled.frame:GetParent(), "pooled in its own canvas")
    end)

    it("sends every section back at once when the panel closes", function()
      dock("B")
      dock("A")
      settle()
      nextDock:PanelHidden(target)
      assert.are.same({}, nextDock:Entries(target))
      for _, name in ipairs({ "A", "B" }) do
        assert.is_false(source.content:IsAway(section(name)))
        assert.are.equal(source.content.frame, section(name).frame:GetParent())
      end
    end)

    it("sends its sections back at once when their bag closes", function()
      dock("B")
      settle()
      nextDock:PanelHidden(source)
      assert.are.same({}, nextDock:Entries(target))
      assert.is_false(source.content:IsAway(section("B")))
    end)

    it("stops pulsing with nothing left", function()
      local entry = dock("B", offer({ answer = "moved" }))
      settle()
      doubleClick(entry)
      finishTweens()
      assert.is_nil(nextDock:ListOf(target).driver:GetScript("OnUpdate"))
    end)

    it("restyles its cards with a theme", function()
      local entry = dock("B")
      settle()
      UseNextTheme({ Dock = { Glow = { Color = "White", Width = 4 } } })
      nextDock:ApplyStyle(ctx())
      assert.are.equal(4, entry.box.glow[1]:GetHeight())
      UseNextTheme(nil)
      nextDock:ApplyStyle(ctx())
    end)
  end)
end)
