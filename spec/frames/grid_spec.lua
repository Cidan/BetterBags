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

