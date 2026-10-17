-- bagcanvas_spec.lua -- The bag's canvas (frames/bagcanvas.lua): the drawable inside the bag's
-- scroll box that plans and arranges the Recent Items header, the active tab view and the Free
-- Space footer. A layout is a function of items per row and columns alone; sized to its content
-- the canvas uses the bag's settings, and given a width (a window the player sized) it takes the
-- densest layout that fits. It centers the layout in its width and reports the layout's own width
-- (FitWidth), which lays out the same: a window snapped to it shows the same items with equal
-- padding (window.md 3b, render-pipeline.md, the layout engine).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")

-- Stubs this file creates are removed after it (the teardown at the end), so a later spec
-- file can load the real modules.
local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local const = trackStub("Constants")
const.BAG_KIND = const.BAG_KIND or { BACKPACK = 0, BANK = 1 }
const.BAG_VIEW = const.BAG_VIEW or { SECTION_GRID = 2, SECTION_ALL_BAGS = 4 }

local db = trackStub("Database")
local sizeInfo = { itemsPerRow = 7, columnCount = 2 }
local originalGetBagSizeInfo, originalGetBagView = db.GetBagSizeInfo, db.GetBagView
local originalAnimate = db.GetAnimateItemMovement
local animate = true

LoadBetterBagsModule("render/render.lua")
LoadBetterBagsModule("render/drawable.lua")
LoadBetterBagsModule("render/flow.lua")
ResetModuleStub("BagCanvas", "frames/bagcanvas.lua")
LoadBetterBagsModule("frames/bagcanvas.lua")

local render = addon:GetModule("Render")
local motion = addon:GetModule("Motion")
local flow = addon:GetModule("Flow")
local bagCanvas = addon:GetModule("BagCanvas")
local context = addon:GetModule("Context")

-- section stands in for a section of count 37-pixel items: at N items per row it is 41 * min(N,
-- count) + 8 wide (cells 4 apart, 6 pixels of padding each side) and its title (24) plus its rows
-- tall, as frames/section.lua measures it.
local function section(count, name)
  local s = { count = count, name = name or ("s" .. count), measures = 0, widestAsked = 0 }
  function s:Measure(_, itemsPerRow)
    self.measures = self.measures + 1
    self.widestAsked = math.max(self.widestAsked, itemsPerRow)
    local perRow = math.min(self.count, itemsPerRow)
    local rows = math.ceil(self.count / itemsPerRow)
    return { itemsPerRow = itemsPerRow, width = 41 * perRow + 8, height = 24 + 41 * rows - 4, content = {} }
  end
  function s:GetItemsPerRowCap() return math.max(1, self.count) end
  return s
end

-- view packs its sections with the real packing (render/flow.lua), as views/views.lua does.
local function view(sections)
  local v = { sections = {}, list = sections, arranged = nil }
  for _, s in ipairs(sections) do v.sections[s.name] = s end
  function v:Measure(itemsPerRow, columns, measureSection)
    local measures, sizes = {}, {}
    for i, s in ipairs(self.list) do
      measures[s] = measureSection and measureSection(s, itemsPerRow) or s:Measure(nil, itemsPerRow)
      sizes[i] = { measures[s].width, measures[s].height }
    end
    local packed = flow:Pack(sizes, { rowLimit = 41 * itemsPerRow + 16, columns = columns })
    return { itemsPerRow = itemsPerRow, columns = columns, sections = measures, content = packed,
      width = packed.width, height = packed.height }
  end
  function v:Arrange(measured)
    self.arranged = measured
    return measured.width, measured.height
  end
  return v
end

-- bag has a view and, optionally, Recent Items (all columns wide) and Free Space.
local function bag(sections, recent, free, freeShowAll)
  local b = { kind = const.BAG_KIND.BACKPACK, currentView = view(sections or {}), recent = recent, free = free }
  function b:GetGlobalLayoutSections()
    local out = {}
    if self.recent then table.insert(out, { section = self.recent, spansColumns = true, place = "header" }) end
    if self.free then table.insert(out, { section = self.free, spansColumns = freeShowAll == true, place = "footer" }) end
    return out
  end
  function b:MeasureGlobalSections(itemsPerRow, columns, measureSection)
    local out = {}
    for _, g in ipairs(self:GetGlobalLayoutSections()) do
      local n = g.spansColumns and itemsPerRow * columns or itemsPerRow
      out[g.place] = measureSection and measureSection(g.section, n) or g.section:Measure(nil, n)
    end
    return out
  end
  function b:ArrangeGlobalSections(measured)
    self.arrangedGlobal = measured
    local h, f = measured.header, measured.footer
    return h and h.width or 0, h and h.height or 0, f and f.width or 0, f and f.height or 0
  end
  return b
end

local function draw(canvas, constraint)
  return render:NewRenderChain(canvas, { ctx = context:New("spec") }, constraint)
end

describe("BagCanvas", function()
  before_each(function()
    render:Init()
    motion:Init()
    db.GetBagSizeInfo = function() return sizeInfo end
    animate = true
    db.GetAnimateItemMovement = function() return animate end
    db.GetBagView = function() return const.BAG_VIEW.SECTION_GRID end
    sizeInfo = { itemsPerRow = 7, columnCount = 2 }
  end)

  after_each(function()
    db.GetBagSizeInfo = originalGetBagSizeInfo
    db.GetBagView = originalGetBagView
    db.GetAnimateItemMovement = originalAnimate
  end)

  teardown(function()
    ResetModuleStub("BagCanvas", "frames/bagcanvas.lua")
  end)

  it("stacks the header, view and footer containers from its top", function()
    local canvas = bagCanvas:Create(bag(), CreateFrame("Frame"))
    assert.are.same({ "TOPLEFT", canvas.frame, "TOPLEFT", 0, 0 }, { canvas.headerContainer:GetPoint(1) })
    assert.are.same({ "TOPLEFT", canvas.headerContainer, "TOPLEFT", 0, 0 }, { canvas.tabContainer:GetPoint(1) })
    assert.are.same({ "TOPLEFT", canvas.headerContainer, "TOPLEFT", 0, 0 }, { canvas.footerContainer:GetPoint(1) })
  end)

  -- An empty container is kept 1 pixel tall, but it never pushes the next one down: a recording
  -- of a bag with no Recent Items had its Free Space 1 pixel past the bottom of the canvas, cut by
  -- the scroll box. Each container sits where the plan puts it, and the content ends exactly at
  -- the height the canvas reports.
  it("places each container where the plan puts it, so the content ends at its height", function()
    local b = bag({ section(9), section(3) }, nil, section(4, "free"))
    local canvas = bagCanvas:Create(b, CreateFrame("Frame"))
    local result = draw(canvas)
    local tabH = b.currentView.arranged.height
    local footerH = b.arrangedGlobal.footer.height
    assert.are.same({ "TOPLEFT", canvas.headerContainer, "TOPLEFT", 0, 0 }, { canvas.tabContainer:GetPoint(1) })
    assert.are.same({ "TOPLEFT", canvas.headerContainer, "TOPLEFT", 0, -tabH }, { canvas.footerContainer:GetPoint(1) })
    assert.are.same({ 1, 1 }, { canvas.tabContainer:GetNumPoints(), canvas.footerContainer:GetNumPoints() })
    assert.are.same({ canvas.plan.width, canvas.plan.width }, { canvas.tabContainer:GetWidth(), canvas.footerContainer:GetWidth() })
    assert.are.equal(tabH + footerH, result.Height)

    local withRecent = bag({ section(9) }, section(2, "recent"), section(4, "free"))
    canvas = bagCanvas:Create(withRecent, CreateFrame("Frame"))
    result = draw(canvas)
    local headerH = withRecent.arrangedGlobal.header.height
    tabH = withRecent.currentView.arranged.height
    assert.are.same({ "TOPLEFT", canvas.headerContainer, "TOPLEFT", 0, -headerH }, { canvas.tabContainer:GetPoint(1) })
    assert.are.same({ "TOPLEFT", canvas.headerContainer, "TOPLEFT", 0, -(headerH + tabH) }, { canvas.footerContainer:GetPoint(1) })
    assert.are.equal(headerH + tabH + withRecent.arrangedGlobal.footer.height, result.Height)
  end)

  it("lays out with the bag's settings when sized to its content, and arranges what it measured", function()
    local b = bag({ section(9), section(3) }, section(2, "recent"), section(4, "free"))
    local canvas = bagCanvas:Create(b, CreateFrame("Frame"))
    local result = draw(canvas)
    assert.are.same({ 7, 2 }, { canvas.plan.itemsPerRow, canvas.plan.columns })
    assert.are.equal(7, b.currentView.arranged.itemsPerRow)
    assert.are.equal(14, b.arrangedGlobal.header.itemsPerRow)
    assert.are.equal(7, b.arrangedGlobal.footer.itemsPerRow)
    assert.are.equal(canvas.plan.width, result.Width)
    assert.are.equal(result.Width, result.FitWidth)
    assert.are.equal(b.arrangedGlobal.header.height + b.currentView.arranged.height + b.arrangedGlobal.footer.height, result.Height)
    assert.are.same({ result.Width, result.Height }, { canvas.frame:GetWidth(), canvas.frame:GetHeight() })
    assert.are.equal(b.currentView.arranged.height, canvas.tabContainer:GetHeight())
  end)

  it("takes the densest layout that fits a width it is given", function()
    sizeInfo = { itemsPerRow = 7, columnCount = 1 }
    local b = bag({ section(12), section(5), section(3) })
    local canvas = bagCanvas:Create(b, CreateFrame("Frame"))
    draw(canvas, { Width = 41 * 9 + 8 })
    assert.are.equal(9, canvas.plan.itemsPerRow)
    draw(canvas, { Width = 41 * 9 + 7 })
    assert.are.equal(8, canvas.plan.itemsPerRow)
  end)

  -- The render recorder prints it: the number that decided the layout (render-recorder.md).
  it("remembers the width it planned for: the layout width, else its width, none when sized to its content", function()
    local canvas = bagCanvas:Create(bag({ section(4) }), CreateFrame("Frame"))
    draw(canvas, { Width = 500 })
    assert.are.equal(500, canvas.plannedFor)
    draw(canvas, { Width = 500, LayoutWidth = 300 })
    assert.are.equal(300, canvas.plannedFor)
    draw(canvas)
    assert.is_nil(canvas.plannedFor)
  end)

  it("keeps one item per row when nothing fits", function()
    local canvas = bagCanvas:Create(bag({ section(4) }), CreateFrame("Frame"))
    draw(canvas, { Width = 20 })
    assert.are.equal(1, canvas.plan.itemsPerRow)
  end)

  -- The candidates run from the items per row past which nothing changes down to one, the same
  -- list for any width: whatever fits a width, the densest of it also fits its own width, so the
  -- layout at the snapped width is the same, item for item.
  it("lays out the same at its own width as at any width it was chosen for (the snap)", function()
    local seed = 4242
    local function random(n) seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n end
    local failures = {}
    for run = 1, 300 do
      local sections = {}
      for i = 1, 1 + random(14) do sections[i] = section(1 + random(16), "s" .. i) end
      local columns = 1 + random(3)
      sizeInfo = { itemsPerRow = 7, columnCount = columns }
      local recent = random(2) == 0 and section(1 + random(20), "recent") or nil
      local free = section(1 + random(3), "free")
      local b = bag(sections, recent, free, random(2) == 0)
      local canvas = bagCanvas:Create(b, CreateFrame("Frame"))
      local width = 150 + random(1400)
      local chosen = draw(canvas, { Width = width })
      local plan = canvas.plan
      local snapped = draw(canvas, { Width = chosen.FitWidth })
      local again = canvas.plan
      local ok = again.itemsPerRow == plan.itemsPerRow and again.width == plan.width
        and chosen.FitWidth == plan.width and (plan.width <= width or plan.itemsPerRow == 1)
        and snapped.FitWidth == plan.width
      if not ok then
        table.insert(failures, string.format("run %d: width %d chose ipr %d (%d wide), at %d chose ipr %d (%d wide)",
          run, width, plan.itemsPerRow, plan.width, chosen.FitWidth, again.itemsPerRow, again.width))
      end
    end
    assert.are.same({}, failures)
  end)

  -- Densest means no more items per row fit: every larger items per row is wider than the width,
  -- or, past the point where nothing changes any more, the very same layout.
  it("never leaves out a denser layout that fits", function()
    sizeInfo = { itemsPerRow = 7, columnCount = 2 }
    local b = bag({ section(12), section(9), section(7), section(3), section(2) }, section(6, "recent"), section(1, "free"))
    local canvas = bagCanvas:Create(b, CreateFrame("Frame"))
    for width = 200, 1600, 37 do
      draw(canvas, { Width = width })
      local plan = canvas.plan
      for n = plan.itemsPerRow + 1, 60 do
        local denser = canvas:Measure(n, 2)
        assert.is_true(denser.width > width or (denser.width == plan.width and denser.height == plan.height),
          string.format("width %d: %d per row is %d x %d, chosen %d per row is %d x %d", width, n, denser.width,
            denser.height, plan.itemsPerRow, plan.width, plan.height))
      end
    end
  end)

  -- The view and Free Space slide to their new places when what is above them changes height
  -- (Recent Items appearing, a row more or less), through Motion (render/motion.lua): only while
  -- the bag is shown, and never into a bag that just opened (render-pipeline.md, motion).
  describe("in motion", function()
    local function recentAppears(parent)
      local b = bag({ section(9) }, nil, section(4, "free"))
      local canvas = bagCanvas:Create(b, parent)
      draw(canvas)
      b.recent = section(3, "recent")
      draw(canvas)
      return canvas, b
    end

    it("slides the view and Free Space down when Recent Items appears, while shown", function()
      local canvas, b = recentAppears(CreateFrame("Frame"))
      local headerH = b.arrangedGlobal.header.height
      local tabH = b.currentView.arranged.height
      assert.are.same({ 0, 0, 0, -headerH }, { motion:GetMove(canvas.tabContainer) })
      assert.are.same({ 0, -tabH, 0, -(headerH + tabH) }, { motion:GetMove(canvas.footerContainer) })
      assert.are.same({ "TOPLEFT", canvas.headerContainer, "TOPLEFT", 0, 0 }, { canvas.tabContainer:GetPoint(1) })
    end)

    -- Animate Item Movement (off by default) turns it on.
    it("places everything at once while animating item movement is off, and forgets what it placed", function()
      animate = false
      local canvas, b = recentAppears(CreateFrame("Frame"))
      assert.is_nil(motion:GetMove(canvas.tabContainer))
      assert.are.same({ "TOPLEFT", canvas.headerContainer, "TOPLEFT", 0, -b.arrangedGlobal.header.height },
        { canvas.tabContainer:GetPoint(1) })
      animate = true
      b.recent = nil
      draw(canvas)
      assert.is_nil(motion:GetMove(canvas.tabContainer), "its first pass once turned on places at once")
    end)

    it("places everything at once while hidden, and forgets what it placed", function()
      local parent = CreateFrame("Frame")
      parent:Hide()
      local canvas, b = recentAppears(parent)
      assert.is_nil(motion:GetMove(canvas.tabContainer))
      assert.are.same({ "TOPLEFT", canvas.headerContainer, "TOPLEFT", 0, -b.arrangedGlobal.header.height },
        { canvas.tabContainer:GetPoint(1) })
      parent:Show()
      b.recent = nil
      draw(canvas)
      assert.is_nil(motion:GetMove(canvas.tabContainer), "its first pass once shown places at once")
    end)

    it("ends its moves where they were going and forgets them when it hides", function()
      local canvas, b = recentAppears(CreateFrame("Frame"))
      canvas.frame:GetScript("OnHide")(canvas.frame)
      assert.is_nil(motion:GetMove(canvas.tabContainer))
      assert.are.same({ "TOPLEFT", canvas.headerContainer, "TOPLEFT", 0, -b.arrangedGlobal.header.height },
        { canvas.tabContainer:GetPoint(1) })
      b.recent = nil
      draw(canvas)
      assert.is_nil(motion:GetMove(canvas.tabContainer))
    end)

    -- Grids placed outside a bag's render (the currency icons, the slots panels) are no part of its
    -- passes: they are placed at once.
    it("closes its pass when it is done", function()
      local canvas = bagCanvas:Create(bag({ section(3) }), CreateFrame("Frame"))
      local other, parent = CreateFrame("Frame"), CreateFrame("Frame")
      other:Show()
      draw(canvas)
      motion:Place(other, parent, 0, 0)
      draw(canvas)
      motion:Place(other, parent, 50, 0)
      assert.is_nil(motion:GetMove(other))
      assert.are.same({ "TOPLEFT", parent, "TOPLEFT", 50, 0 }, { other:GetPoint(1) })
    end)

    -- Parents are placed before what hangs from them, so an item that changes container starts
    -- from where its new container is anchored at that moment (render/motion.lua).
    it("hangs its containers before it arranges what is in them", function()
      local b = bag({ section(9) }, section(2, "recent"), section(4, "free"))
      local canvas = bagCanvas:Create(b, CreateFrame("Frame"))
      local order = {}
      local place = motion.Place
      motion.Place = function(self, frame, ...)
        if frame == canvas.tabContainer then table.insert(order, "tab") end
        if frame == canvas.footerContainer then table.insert(order, "footer") end
        return place(self, frame, ...)
      end
      local arrangeGlobal, arrangeView = b.ArrangeGlobalSections, b.currentView.Arrange
      b.ArrangeGlobalSections = function(...) table.insert(order, "global") return arrangeGlobal(...) end
      b.currentView.Arrange = function(...) table.insert(order, "view") return arrangeView(...) end
      draw(canvas)
      motion.Place = place
      assert.are.same({ "tab", "footer", "global", "view" }, order)
    end)

    it("leaves the header container to the centering: it follows the window, it does not travel", function()
      sizeInfo = { itemsPerRow = 7, columnCount = 1 }
      local canvas = bagCanvas:Create(bag({ section(3) }), CreateFrame("Frame"))
      draw(canvas, { Width = 400 })
      draw(canvas, { Width = 500 })
      assert.is_nil(motion:GetMove(canvas.headerContainer))
    end)
  end)

  it("measures each section once per items per row it needs, never past where it stops changing", function()
    sizeInfo = { itemsPerRow = 7, columnCount = 1 }
    local big, small = section(30), section(3)
    local canvas = bagCanvas:Create(bag({ big, small }), CreateFrame("Frame"))
    draw(canvas, { Width = 1300 })
    assert.is_true(big.measures <= 30, tostring(big.measures))
    assert.are.equal(30, big.widestAsked)
    assert.are.equal(3, small.widestAsked)
  end)

  -- A section spanning the columns has columns times the items per row, so it stops changing at
  -- its own cap over the columns.
  it("counts a section spanning the columns at its cap over the columns", function()
    local canvas = bagCanvas:Create(bag({ section(4) }, section(30, "recent"), section(2, "free"), false), CreateFrame("Frame"))
    local bounds = canvas:boundsOf(3, function(s, n) return s:Measure(nil, n) end)
    assert.are.equal(10, bounds.sectionsCap)
    bounds = canvas:boundsOf(1, function(s, n) return s:Measure(nil, n) end)
    assert.are.equal(30, bounds.sectionsCap)
  end)

  -- A resize renders again and again with the same sections: their measures are kept until the bag
  -- binds new data to them (bag:Draw calls ForgetMeasures before it renders).
  it("keeps its section measures across renders until it is told to forget them", function()
    sizeInfo = { itemsPerRow = 7, columnCount = 1 }
    local big = section(30)
    local canvas = bagCanvas:Create(bag({ big, section(3) }), CreateFrame("Frame"))
    draw(canvas, { Width = 600 })
    local after = big.measures
    for width = 601, 640 do draw(canvas, { Width = width }) end
    assert.are.equal(after, big.measures)
    big.count = 31
    canvas:ForgetMeasures()
    draw(canvas, { Width = 600 })
    assert.is_true(big.measures > after)
    assert.is_true(canvas.plan.width <= 600)
  end)

  -- Equal padding on both sides of the longest row, always: the header, view and footer share one
  -- left edge and are centered together in the width the canvas is shown at.
  describe("centering", function()
    local function offsets(canvas)
      local _, _, _, left = canvas.headerContainer:GetPoint(1)
      local _, _, _, right = canvas.headerContainer:GetPoint(2)
      return left, right
    end

    it("centers the layout in a wider width", function()
      sizeInfo = { itemsPerRow = 7, columnCount = 1 }
      local canvas = bagCanvas:Create(bag({ section(3) }), CreateFrame("Frame"))
      draw(canvas, { Width = 500 })
      local spare = (500 - canvas.plan.width) / 2
      assert.are.same({ "TOPLEFT", canvas.frame, "TOPLEFT", spare, 0 }, { canvas.headerContainer:GetPoint(1) })
      assert.are.same({ "TOPRIGHT", canvas.frame, "TOPRIGHT", -spare, 0 }, { canvas.headerContainer:GetPoint(2) })
      assert.are.equal(500, canvas.frame:GetWidth())
    end)

    it("needs no offset when sized to its content, or at its own width", function()
      local canvas = bagCanvas:Create(bag({ section(9), section(3) }), CreateFrame("Frame"))
      draw(canvas)
      assert.are.same({ 0, 0 }, { offsets(canvas) })
      local fit = draw(canvas, { Width = 700 }).FitWidth
      draw(canvas, { Width = fit })
      assert.are.same({ 0, 0 }, { offsets(canvas) })
    end)

    it("lays out for a layout width and centers in the width it is shown at", function()
      sizeInfo = { itemsPerRow = 7, columnCount = 1 }
      local canvas = bagCanvas:Create(bag({ section(12) }), CreateFrame("Frame"))
      draw(canvas, { Width = 800, LayoutWidth = 41 * 9 + 8 })
      assert.are.equal(9, canvas.plan.itemsPerRow)
      assert.are.equal(800, canvas.frame:GetWidth())
      local spare = (800 - (41 * 9 + 8)) / 2
      assert.are.same({ spare, -spare }, { offsets(canvas) })
    end)
  end)

  it("lays out the global sections even before a view was drawn", function()
    local b = bag(nil, section(2, "recent"))
    b.currentView = nil
    local canvas = bagCanvas:Create(b, CreateFrame("Frame"))
    local result = draw(canvas)
    assert.are.same({ 41 * 2 + 8, 24 + 37 }, { result.Width, result.Height })
  end)

  it("never sizes its frame or containers to zero", function()
    local b = bag()
    b.currentView = nil
    local canvas = bagCanvas:Create(b, CreateFrame("Frame"))
    draw(canvas)
    assert.are.same({ 1, 1 }, { canvas.frame:GetWidth(), canvas.frame:GetHeight() })
    assert.are.equal(1, canvas.tabContainer:GetHeight())
  end)

  it("is a drawable prototype the profiler measures", function()
    local perf = addon:GetModule("Perf")
    local canvas = bagCanvas:Create(bag(), CreateFrame("Frame"))
    local name
    for _, entry in ipairs(perf.prototypes) do
      if entry.tbl == getmetatable(canvas).__index then name = entry.name end
    end
    assert.are.equal("BagCanvasFrame", name)
  end)
end)

teardown(function()
  for i = #createdStubs, 1, -1 do
    ResetModuleStub(createdStubs[i])
  end
end)
