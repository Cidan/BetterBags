-- bagcanvas_spec.lua -- The bag's canvas (frames/bagcanvas.lua): the drawable inside the bag's
-- scroll box that lays out the Recent Items header, the active tab view and the Free Space
-- footer. Sized to its content it uses the bag's items per row and columns; given a width (a
-- window the player sized) it fits as many items per row as the width allows.
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
  local bag = { kind = const.BAG_KIND.BACKPACK, layouts = {} }
  function bag:LayoutGlobalSections(layout)
    table.insert(self.layouts, { "global", layout })
    return header[1], header[2], footer[1], footer[2]
  end
  bag.currentView = {
    Layout = function(_, ctx, layout)
      assert(ctx ~= nil)
      table.insert(bag.layouts, { "view", layout })
      return view[1], view[2]
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

    assert.are.same({ itemsPerRow = 7, columns = 2 }, bag.layouts[1][2])
    assert.are.same({ itemsPerRow = 7, columns = 2 }, bag.layouts[2][2])
    assert.are.equal(590, result.Width)
    assert.are.equal(40 + 200 + 41, result.Height)
    assert.are.same({ 590, 281 }, { canvas.frame:GetWidth(), canvas.frame:GetHeight() })
    assert.are.equal(200, canvas.tabContainer:GetHeight())
  end)

  -- A view column is at most 41 * N + 20 wide (two sections sharing a row, frames/grid.lua), so
  -- a width fits N items per row in each column when it holds that many columns that wide.
  it("fits as many items per row as a given width allows, and fills it", function()
    local bag = fakeBag({ 0, 0 }, { 300, 100 }, { 0, 0 })
    local canvas = bagCanvas:Create(bag, CreateFrame("Frame"))

    local result = render:NewRenderChain(canvas, { ctx = context:New("spec") }, { Width = 2 * (41 * 9 + 20) })

    assert.are.same({ itemsPerRow = 9, columns = 2 }, bag.layouts[2][2])
    assert.are.equal(2 * (41 * 9 + 20), result.Width)
    assert.are.equal(100, result.Height)
    assert.are.same({ itemsPerRow = 8, columns = 2 }, canvas:GetLayout(2 * (41 * 9 + 20) - 0.01))
  end)

  -- The widest view the grid can make for N items per row: every row two sections whose items add
  -- up to N (41 * N + 20 with the gap between them), in every column. Laid out by the real grid
  -- with the view's limits (views/views.lua), it must fit the width the layout was chosen for.
  it("never lays a view out wider than the width it was given", function()
    local canvas = bagCanvas:Create(fakeBag({ 0, 0 }, { 0, 0 }, { 0, 0 }), CreateFrame("Frame"))
    local overflow = {}
    for _, columns in ipairs({ 1, 2, 3 }) do
      sizeInfo = { itemsPerRow = 7, columnCount = columns }
      for step = 0, 600 do
        local width = columns * 61 + step * 3.37
        local ipr = canvas:GetLayout(width).itemsPerRow
        local g = grid:Create(CreateFrame("Frame"), false)
        for row = 1, columns * 4 do
          local left = 1 + (row % math.max(1, ipr - 1))
          for _, items in ipairs({ left, math.max(1, ipr - left) }) do
            local f = CreateFrame("Frame")
            f:SetSize(41 * items + 8, 61)
            g:AddCell("s" .. row .. "_" .. items .. "_" .. _, { frame = f })
          end
        end
        local w = g:Draw({ cells = g.cells, maxWidthPerRow = (37 + 4) * ipr + 16, columns = columns })
        if w > width then
          table.insert(overflow, string.format("%d columns, width %.2f: %d per row laid out %d", columns, width, ipr, w))
        end
      end
    end
    assert.are.same({}, overflow)
  end)

  it("keeps at least one item per row in a narrow window", function()
    local canvas = bagCanvas:Create(fakeBag({ 0, 0 }, { 0, 0 }, { 0, 0 }), CreateFrame("Frame"))
    assert.are.same({ itemsPerRow = 1, columns = 2 }, canvas:GetLayout(10))
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
