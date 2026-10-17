local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Load required modules
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")

-- Stub modules before loading grid
local const = StubBetterBagsModule("Constants")
const.GRID_COMPACT_STYLE = { NONE = 0 }

local debug = StubBetterBagsModule("Debug")
debug.Log = function() end

-- Mock WoW Scroll APIs if they don't exist
_G.CreateScrollBoxLinearView = function()
  return {
    SetPanExtent = function() end
  }
end

_G.ScrollUtil = {
  InitScrollBoxWithScrollBar = function() end
}

-- Ensure that CreateFrame returns objects with SetInterpolateScroll
local originalCreateFrame = _G.CreateFrame
_G.CreateFrame = function(frameType, name, parent, template)
  local frame = originalCreateFrame(frameType, name, parent, template)
  frame.SetInterpolateScroll = function() end
  return frame
end

-- Load Grid module
ResetModuleStub("Grid", "frames/grid.lua")
LoadBetterBagsModule("frames/grid.lua")
local grid = addon:GetModule("Grid")

describe("Grid scrollbar and mousewheel tests", function()
  it("should create a scrollable grid and verify scrollbar methods can be called", function()
    local parent = CreateFrame("Frame")
    local g = grid:Create(parent, true)
    assert.is_true(g.scrollable)

    -- These should work fine because self.bar is defined
    g:HideScrollBar()
    g:ShowScrollBar()
    g:EnableMouseWheelScroll(true)
  end)

  it("should create a non-scrollable grid and verify scrollbar methods gracefully no-op without crashes", function()
    local parent = CreateFrame("Frame")
    local g = grid:Create(parent, false)
    assert.is_false(g.scrollable)

    -- Under the old implementation, this would throw "attempt to index a nil value" because self.bar was nil
    -- Under our new implementation, it should gracefully return without error
    assert.has_no.errors(function()
      g:HideScrollBar()
      g:ShowScrollBar()
      g:EnableMouseWheelScroll(true)
    end)
  end)
end)

describe("Grid gap layout tests", function()
  it("does not reparent a cell that is already in this grid", function()
    local parent = CreateFrame("Frame")
    local g = grid:Create(parent, false)
    local f = CreateFrame("Frame")
    f:SetSize(37, 37)
    g:AddCell("a", { frame = f })
    g:Draw({ cells = g.cells, maxWidthPerRow = 205 })
    assert.is_equal(g.inner, f:GetParent())

    local reparented = 0
    local setParent = f.SetParent
    f.SetParent = function(self, p)
      reparented = reparented + 1
      return setParent(self, p)
    end
    g:Draw({ cells = g.cells, maxWidthPerRow = 205 })
    assert.is_equal(0, reparented)
    assert.is_equal(g.inner, f:GetParent())
  end)

  it("should layout cells with gaps correctly using absolute coordinates", function()
    local parent = CreateFrame("Frame")
    local g = grid:Create(parent, false)
    g.spacing = 4

    -- Let's define some cells.
    -- Cell 1: real frame
    local f1 = CreateFrame("Frame")
    f1:SetSize(37, 37)
    local cell1 = { frame = f1 }

    -- Cell 2: gap
    local cell2 = { isGap = true, width = 37, height = 37 }

    -- Cell 3: real frame
    local f3 = CreateFrame("Frame")
    f3:SetSize(37, 37)
    local cell3 = { frame = f3 }

    g:AddCell("cell1", cell1)
    g:AddCell("cell2", cell2)
    g:AddCell("cell3", cell3)

    -- Render in a grid that can fit all 3 in one row.
    -- Width per row before wrapping = 205 (can fit all 3: 37 + 4 + 37 + 4 + 37 = 119)
    g:Draw({
      cells = g.cells,
      maxWidthPerRow = 205
    })

    -- Since cell1 is first, its TOPLEFT is at (0, 0)
    local point1, _, _, x1, y1 = f1:GetPoint(1)
    assert.is_equal("TOPLEFT", point1)
    assert.is_equal(0, x1)
    assert.is_equal(0, y1)

    -- Since cell2 is a gap of size 37, and spacing is 4, cell3 should start at 37 + 4 (cell1) + 37 (gap) + 4 = 82
    local point3, _, _, x3, y3 = f3:GetPoint(1)
    assert.is_equal("TOPLEFT", point3)
    assert.is_equal(82, x3)
    assert.is_equal(0, y3)
  end)

  it("should handle a row starting with a gap correctly", function()
    local parent = CreateFrame("Frame")
    local g = grid:Create(parent, false)
    g.spacing = 4

    -- Cell 1: gap
    local cell1 = { isGap = true, width = 37, height = 37 }

    -- Cell 2: real frame
    local f2 = CreateFrame("Frame")
    f2:SetSize(37, 37)
    local cell2 = { frame = f2 }

    g:AddCell("cell1", cell1)
    g:AddCell("cell2", cell2)

    g:Draw({
      cells = g.cells,
      maxWidthPerRow = 205
    })

    -- Since cell1 is a gap, cell2 should start at 37 + 4 = 41
    local point2, _, _, x2, y2 = f2:GetPoint(1)
    assert.is_equal("TOPLEFT", point2)
    assert.is_equal(41, x2)
    assert.is_equal(0, y2)
  end)

  it("should handle a row consisting entirely of gaps correctly", function()
    local parent = CreateFrame("Frame")
    local g = grid:Create(parent, false)
    g.spacing = 4

    -- Cell 1: gap
    local cell1 = { isGap = true, width = 37, height = 37 }

    -- Cell 2: gap
    local cell2 = { isGap = true, width = 37, height = 37 }

    g:AddCell("cell1", cell1)
    g:AddCell("cell2", cell2)

    local _, height = g:Draw({
      cells = g.cells,
      maxWidthPerRow = 205
    })

    -- Height should be exactly 37, and width should be calculated properly
    assert.is_equal(37, height)
  end)
end)


-- Frames report their size back with float noise (a bag at 0.65 scale), and the grid decides where
-- cells go by comparing those sizes with its row width and column height limits. A size a hair
-- over its whole value at a limit flipped the layout between two states on every redraw (a render
-- recording of a bank: two 131-wide sections against a 262-wide row, laid out side by side in one
-- render and wrapped in the next, moving every section below).
describe("Grid layout under measurement noise", function()
  local function sectionCell(width, height)
    local f = CreateFrame("Frame")
    f:SetSize(width, height)
    return { frame = f }
  end

  local function positions(g)
    local out = {}
    for i, cell in ipairs(g.cells) do
      local _, _, _, x, y = cell.frame:GetPoint(1)
      out[i] = { x, y }
    end
    return out
  end

  it("keeps two sections that exactly fill a row on that row, whatever noise their widths carry", function()
    for _, noise in ipairs({ 0, 0.00001, -0.00001, 0.004 }) do
      local g = grid:Create(CreateFrame("Frame"), false)
      g:AddCell("feet", sectionCell(131 + noise, 61))
      g:AddCell("finger", sectionCell(131 + noise, 61))
      g:Draw({ cells = g.cells, maxWidthPerRow = (37 + 4) * 6 + 16 })
      assert.are.same({ { 0, 0 }, { 135, 0 } }, positions(g), tostring(noise))
    end
  end)

  it("lays cells out the same with and without sub-pixel noise in their sizes, over 1000 layouts", function()
    local seed = 1234567
    local function random(n)
      seed = (seed * 1103515245 + 12345) % 2147483648
      return seed % n
    end
    for run = 1, 1000 do
      local ipr = 2 + random(9)
      local columns = 1 + random(3)
      local count = 4 + random(26)
      local sizes = {}
      for i = 1, count do
        local items = 1 + random(ipr)
        local rows = 1 + random(4)
        sizes[i] = { 41 * items + 8, 41 * rows + 20 }
      end
      local function layout(noisy)
        local g = grid:Create(CreateFrame("Frame"), false)
        for i, size in ipairs(sizes) do
          local nw = noisy and ((random(3) - 1) * 0.00003) or 0
          local nh = noisy and ((random(3) - 1) * 0.00003) or 0
          g:AddCell("s" .. i, sectionCell(size[1] + nw, size[2] + nh))
        end
        local w, h = g:Draw({ cells = g.cells, maxWidthPerRow = (37 + 4) * ipr + 16, columns = columns })
        return positions(g), w, h
      end
      local exact, ew, eh = layout(false)
      local noisy, nw, nh = layout(true)
      assert.are.same(exact, noisy, "layout " .. run)
      assert.are.same({ ew, eh }, { nw, nh }, "layout " .. run)
    end
  end)
end)

-- Every cell of every grid is placed by Motion (render/motion.lua): in a pass of a root, a cell
-- whose place changed moves there from where it was; the others stay put (render-pipeline.md,
-- motion).
describe("Grid cells in motion", function()
  local motion = addon:GetModule("Motion")

  before_each(function()
    motion:Init()
  end)

  local function cell()
    local f = CreateFrame("Frame")
    f:SetSize(37, 37)
    return { frame = f }
  end

  local function draw(g, perRow, key)
    if key ~= nil then motion:BeginPass(key) end
    g:Draw({ cells = g.cells, maxWidthPerRow = 41 * perRow + 16 })
    if key ~= nil then return motion:EndPass() end
  end

  it("moves only the cells whose place changed, each from where it was", function()
    local g = grid:Create(CreateFrame("Frame"), false)
    local a, b, c = cell(), cell(), cell()
    g:AddCell("a", a)
    g:AddCell("b", b)
    g:AddCell("c", c)
    local key = {}
    draw(g, 3, key)
    assert.are.equal(1, draw(g, 2, key))
    assert.is_nil(motion:GetMove(a.frame))
    assert.is_nil(motion:GetMove(b.frame))
    assert.are.same({ 82, 0, 0, -41 }, { motion:GetMove(c.frame) })
    assert.are.same({ "TOPLEFT", g.inner, "TOPLEFT", 82, 0 }, { c.frame:GetPoint(1) })
    assert.is_true(c.frame:IsShown())
  end)

  it("places every cell at once outside a pass", function()
    local g = grid:Create(CreateFrame("Frame"), false)
    local a, b = cell(), cell()
    g:AddCell("a", a)
    g:AddCell("b", b)
    draw(g, 2)
    draw(g, 1)
    assert.is_nil(motion:GetMove(b.frame))
    assert.are.same({ "TOPLEFT", g.inner, "TOPLEFT", 0, -41 }, { b.frame:GetPoint(1) })
  end)
end)
