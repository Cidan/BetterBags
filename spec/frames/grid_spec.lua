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
