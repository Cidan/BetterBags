-- bagcanvas_spec.lua -- The bag's canvas (frames/bagcanvas.lua): the drawable inside the bag's
-- scroll box that lays out the Recent Items header, the active tab view and the Free Space
-- footer. Sized to its content it uses the bag's items per row and columns; given a width (a
-- window the player sized) it fits as many items per row as the width allows and packs rows up
-- to each column's width. It centers what it laid out in the width it is shown at, and reports
-- the narrowest width that lays out the same (a window snapping to its content).
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

local debugModule = trackStub("Debug")
debugModule.Log = debugModule.Log or function() end
const.GRID_COMPACT_STYLE = const.GRID_COMPACT_STYLE or { NONE = 0, SIMPLE = 1, COMPACT = 2 }

local db = trackStub("Database")
local sizeInfo = { itemsPerRow = 7, columnCount = 2 }
local originalGetBagSizeInfo, originalGetBagView = db.GetBagSizeInfo, db.GetBagView

LoadBetterBagsModule("render/render.lua")
LoadBetterBagsModule("render/drawable.lua")
LoadBetterBagsModule("frames/bagcanvas.lua")
ResetModuleStub("Grid", "frames/grid.lua")
LoadBetterBagsModule("frames/grid.lua")
local grid = addon:GetModule("Grid")

local render = addon:GetModule("Render")
local bagCanvas = addon:GetModule("BagCanvas")
local context = addon:GetModule("Context")

-- fakeBag lays out a header, a view and a footer of fixed sizes, recording the layouts it got.
local function fakeBag(header, view, footer)
  -- The view's widest column: the whole view unless the test says.
  local bag = { kind = const.BAG_KIND.BACKPACK, layouts = {} }
  function bag:LayoutGlobalSections(layout)
    table.insert(self.layouts, { "global", layout })
    return header[1], header[2], footer[1], footer[2]
  end
  bag.currentView = {
    Layout = function(_, ctx, layout)
      assert(ctx ~= nil)
      table.insert(bag.layouts, { "view", layout })
      return view[1], view[2], view[3] or view[1]
    end,
  }
  return bag
end

describe("BagCanvas", function()
  before_each(function()
    render:Init()
    db.GetBagSizeInfo = function() return sizeInfo end
    db.GetBagView = function() return const.BAG_VIEW.SECTION_GRID end
    sizeInfo = { itemsPerRow = 7, columnCount = 2 }
  end)

  after_each(function()
    db.GetBagSizeInfo = originalGetBagSizeInfo
    db.GetBagView = originalGetBagView
  end)

  it("stacks the header, view and footer containers", function()
    local canvas = bagCanvas:Create(fakeBag({ 0, 0 }, { 0, 0 }, { 0, 0 }), CreateFrame("Frame"))
    assert.are.same({ "TOPLEFT", canvas.frame, "TOPLEFT", 0, 0 }, { canvas.headerContainer:GetPoint(1) })
    assert.are.same({ "TOPLEFT", canvas.headerContainer, "BOTTOMLEFT", 0, 0 }, { canvas.tabContainer:GetPoint(1) })
    assert.are.same({ "TOPLEFT", canvas.tabContainer, "BOTTOMLEFT", 0, 0 }, { canvas.footerContainer:GetPoint(1) })
  end)

  it("lays out with the bag's settings when sized to its content", function()
    local bag = fakeBag({ 300, 40 }, { 590, 200 }, { 120, 41 })
    local canvas = bagCanvas:Create(bag, CreateFrame("Frame"))

    local result = render:NewRenderChain(canvas, { ctx = context:New("spec") })

    assert.are.same({ itemsPerRow = 7, columns = 2, rowWidth = 41 * 7 + 16 }, bag.layouts[1][2])
    assert.are.same({ itemsPerRow = 7, columns = 2, rowWidth = 41 * 7 + 16 }, bag.layouts[2][2])
    assert.are.equal(590, result.Width)
    assert.are.equal(40 + 200 + 41, result.Height)
    assert.are.same({ 590, 281 }, { canvas.frame:GetWidth(), canvas.frame:GetHeight() })
    assert.are.equal(200, canvas.tabContainer:GetHeight())
  end)

  -- A section of N items is 41 * N + 8 wide (37-pixel cells 4 apart, 6 pixels of padding on
  -- each side), so a width fits N items per row in each column when each column holds one such
  -- section; rows of sections pack up to the column's width (4 less: the grid lets a row run 4
  -- past its limit, the gap before its last section, frames/grid.lua layoutSingleColumn).
  it("fits as many items per row as a given width allows, and fills it", function()
    local bag = fakeBag({ 0, 0 }, { 300, 100 }, { 0, 0 })
    local canvas = bagCanvas:Create(bag, CreateFrame("Frame"))

    local result = render:NewRenderChain(canvas, { ctx = context:New("spec") }, { Width = 2 * (41 * 9 + 8) })

    assert.are.same({ itemsPerRow = 9, columns = 2, rowWidth = 41 * 9 + 8 - 4 }, bag.layouts[2][2])
    assert.are.equal(2 * (41 * 9 + 8), result.Width)
    assert.are.equal(100, result.Height)
    assert.are.equal(8, canvas:GetLayout(2 * (41 * 9 + 8) - 0.01).itemsPerRow)
  end)

  -- The widest view the grid can make for a width: rows of sections as wide as the layout lets
  -- them be, in every column. Laid out by the real grid with the layout's row width (the limit
  -- views/views.lua packs rows to), it must fit the width the layout was chosen for.
  it("never lays a view out wider than the width it was given", function()
    local canvas = bagCanvas:Create(fakeBag({ 0, 0 }, { 0, 0 }, { 0, 0 }), CreateFrame("Frame"))
    local overflow = {}
    for _, columns in ipairs({ 1, 2, 3 }) do
      sizeInfo = { itemsPerRow = 7, columnCount = columns }
      for step = 0, 600 do
        local width = columns * 61 + step * 3.37
        local layout = canvas:GetLayout(width)
        local ipr = layout.itemsPerRow
        local g = grid:Create(CreateFrame("Frame"), false)
        for row = 1, columns * 4 do
          local left = 1 + (row % math.max(1, ipr - 1))
          for _, items in ipairs({ left, math.max(1, ipr - left) }) do
            local f = CreateFrame("Frame")
            f:SetSize(41 * items + 8, 61)
            g:AddCell("s" .. row .. "_" .. items .. "_" .. _, { frame = f })
          end
        end
        local w = g:Draw({ cells = g.cells, maxWidthPerRow = layout.rowWidth, columns = columns })
        if w > width then
          table.insert(overflow, string.format("%d columns, width %.2f: %d per row laid out %d", columns, width, ipr, w))
        end
      end
    end
    assert.are.same({}, overflow)
  end)

  it("keeps at least one item per row in a narrow window", function()
    local canvas = bagCanvas:Create(fakeBag({ 0, 0 }, { 0, 0 }, { 0, 0 }), CreateFrame("Frame"))
    assert.are.equal(1, canvas:GetLayout(10).itemsPerRow)
  end)

  -- Equal padding on both sides of the longest row, always: the header, view and footer share
  -- one left edge and are centered together in the width the canvas is shown at.
  describe("centering", function()
    local function offsets(canvas)
      local _, _, _, left = canvas.headerContainer:GetPoint(1)
      local _, _, _, right = canvas.headerContainer:GetPoint(2)
      return left, right
    end

    it("centers what it laid out in a wider width", function()
      local bag = fakeBag({ 100, 40 }, { 300, 200 }, { 120, 41 })
      local canvas = bagCanvas:Create(bag, CreateFrame("Frame"))
      render:NewRenderChain(canvas, { ctx = context:New("spec") }, { Width = 754 })
      assert.are.same({ "TOPLEFT", canvas.frame, "TOPLEFT", 227, 0 }, { canvas.headerContainer:GetPoint(1) })
      assert.are.same({ "TOPRIGHT", canvas.frame, "TOPRIGHT", -227, 0 }, { canvas.headerContainer:GetPoint(2) })
      assert.are.same({ "TOPLEFT", canvas.headerContainer, "BOTTOMLEFT", 0, 0 }, { canvas.tabContainer:GetPoint(1) })
      assert.are.same({ "TOPLEFT", canvas.tabContainer, "BOTTOMLEFT", 0, 0 }, { canvas.footerContainer:GetPoint(1) })
      assert.are.equal(754, canvas.frame:GetWidth())
    end)

    it("centers on the widest of the header, view and footer", function()
      local canvas = bagCanvas:Create(fakeBag({ 500, 40 }, { 300, 200 }, { 120, 41 }), CreateFrame("Frame"))
      render:NewRenderChain(canvas, { ctx = context:New("spec") }, { Width = 754 })
      assert.are.same({ 127, -127 }, { offsets(canvas) })
    end)

    it("needs no offset when sized to its content", function()
      local canvas = bagCanvas:Create(fakeBag({ 100, 40 }, { 300, 200 }, { 120, 41 }), CreateFrame("Frame"))
      render:NewRenderChain(canvas, { ctx = context:New("spec") })
      assert.are.same({ 0, 0 }, { offsets(canvas) })
    end)

    it("lays out for a layout width and centers in the width it is shown at", function()
      local bag = fakeBag({ 0, 0 }, { 700, 200, 350 }, { 0, 0 })
      local canvas = bagCanvas:Create(bag, CreateFrame("Frame"))
      render:NewRenderChain(canvas, { ctx = context:New("spec") }, { Width = 800, LayoutWidth = 760 })
      assert.are.same({ itemsPerRow = 9, columns = 2, rowWidth = 376 }, bag.layouts[2][2])
      assert.are.equal(800, canvas.frame:GetWidth())
      assert.are.same({ 50, -50 }, { offsets(canvas) })
    end)
  end)

  -- The narrowest width that lays the content out the same: the widest column in every column
  -- (and the header and footer), so a window can snap to it without a single item moving.
  describe("fit width", function()
    it("is the widest column times the columns when that keeps the items per row", function()
      local bag = fakeBag({ 100, 40 }, { 700, 200, 380 }, { 120, 41 })
      local canvas = bagCanvas:Create(bag, CreateFrame("Frame"))
      local result = render:NewRenderChain(canvas, { ctx = context:New("spec") }, { Width = 800 })
      assert.are.equal(9, bag.layouts[2][2].itemsPerRow)
      assert.are.equal(760, result.FitWidth)
      assert.are.equal(9, canvas:GetLayout(result.FitWidth).itemsPerRow)
    end)

    it("is at least as wide as the header and footer", function()
      local canvas = bagCanvas:Create(fakeBag({ 790, 40 }, { 700, 200, 380 }, { 120, 41 }), CreateFrame("Frame"))
      local result = render:NewRenderChain(canvas, { ctx = context:New("spec") }, { Width = 800 })
      assert.are.equal(790, result.FitWidth)
    end)

    it("keeps the items per row when the columns are narrower than a full row", function()
      local bag = fakeBag({ 0, 0 }, { 600, 200, 300 }, { 0, 0 })
      local canvas = bagCanvas:Create(bag, CreateFrame("Frame"))
      local result = render:NewRenderChain(canvas, { ctx = context:New("spec") }, { Width = 800 })
      assert.are.equal(9, bag.layouts[2][2].itemsPerRow)
      assert.are.equal(2 * (41 * 9 + 8), result.FitWidth)
    end)

    it("is the content's width when sized to its content", function()
      local canvas = bagCanvas:Create(fakeBag({ 100, 40 }, { 300, 200 }, { 120, 41 }), CreateFrame("Frame"))
      local result = render:NewRenderChain(canvas, { ctx = context:New("spec") })
      assert.are.equal(300, result.FitWidth)
    end)
  end)

  it("lays out the global sections even before a view was drawn", function()
    local bag = fakeBag({ 100, 40 }, { 0, 0 }, { 0, 0 })
    bag.currentView = nil
    local canvas = bagCanvas:Create(bag, CreateFrame("Frame"))
    local result = render:NewRenderChain(canvas, { ctx = context:New("spec") })
    assert.are.same({ 100, 40 }, { result.Width, result.Height })
  end)

  it("never sizes its frame or containers to zero", function()
    local canvas = bagCanvas:Create(fakeBag({ 0, 0 }, { 0, 0 }, { 0, 0 }), CreateFrame("Frame"))
    render:NewRenderChain(canvas, { ctx = context:New("spec") })
    assert.are.same({ 1, 1 }, { canvas.frame:GetWidth(), canvas.frame:GetHeight() })
    assert.are.equal(1, canvas.tabContainer:GetHeight())
  end)

  it("is a drawable prototype the profiler measures", function()
    local perf = addon:GetModule("Perf")
    local canvas = bagCanvas:Create(fakeBag({ 0, 0 }, { 0, 0 }, { 0, 0 }), CreateFrame("Frame"))
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
