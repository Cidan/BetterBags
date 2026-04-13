-- color_spec.lua -- Unit tests for util/color.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Database stub (Color depends on it)
local database = StubBetterBagsModule("Database")

LoadBetterBagsModule("util/color.lua")
local color = addon:GetModule("Color")

-- Default color config matching typical user settings
local function defaultColors()
  return {
    low  = {red = 0.6, green = 0.6, blue = 0.6},
    mid  = {red = 0.0, green = 1.0, blue = 0.0},
    high = {red = 0.0, green = 0.5, blue = 1.0},
    max  = {red = 1.0, green = 0.5, blue = 0.0},
  }
end

describe("Color", function()

  before_each(function()
    database.GetMaxItemLevel = function() return 489 end
    database.GetItemLevelColors = function() return defaultColors() end
  end)

  describe("GetItemLevelColor", function()

    it("returns max color at max item level", function()
      local r, g, b = color:GetItemLevelColor(489)
      assert.are.equal(1.0, r)
      assert.are.equal(0.5, g)
      assert.are.equal(0.0, b)
    end)

    it("returns max color above max item level", function()
      local r, g, b = color:GetItemLevelColor(500)
      assert.are.equal(1.0, r)
      assert.are.equal(0.5, g)
      assert.are.equal(0.0, b)
    end)

    it("returns high color at the high breakpoint", function()
      -- highPoint = floor(489 * 0.86) = floor(420.54) = 420
      local r, g, b = color:GetItemLevelColor(420)
      assert.are.equal(0.0, r)
      assert.are.equal(0.5, g)
      assert.are.equal(1.0, b)
    end)

    it("returns mid color at the mid breakpoint", function()
      -- midPoint = floor(489 * 0.61) = floor(298.29) = 298
      local r, g, b = color:GetItemLevelColor(298)
      assert.are.equal(0.0, r)
      assert.are.equal(1.0, g)
      assert.are.equal(0.0, b)
    end)

    it("returns low color below the mid breakpoint", function()
      local r, g, b = color:GetItemLevelColor(100)
      assert.are.equal(0.6, r)
      assert.are.equal(0.6, g)
      assert.are.equal(0.6, b)
    end)

    it("returns low color for item level 1", function()
      local r, g, b = color:GetItemLevelColor(1)
      assert.are.equal(0.6, r)
      assert.are.equal(0.6, g)
      assert.are.equal(0.6, b)
    end)

    it("adapts breakpoints when max item level changes", function()
      database.GetMaxItemLevel = function() return 1000 end
      -- midPoint = floor(1000 * 0.61) = 610
      -- highPoint = floor(1000 * 0.86) = 860
      local r, g, b = color:GetItemLevelColor(700)
      -- 700 >= 610 (midPoint) but < 860 (highPoint), so mid color
      assert.are.equal(0.0, r)
      assert.are.equal(1.0, g)
      assert.are.equal(0.0, b)
    end)

    it("works with custom user colors", function()
      database.GetItemLevelColors = function()
        return {
          low  = {red = 1.0, green = 0.0, blue = 0.0},
          mid  = {red = 0.0, green = 1.0, blue = 0.0},
          high = {red = 0.0, green = 0.0, blue = 1.0},
          max  = {red = 1.0, green = 1.0, blue = 1.0},
        }
      end
      local r, g, b = color:GetItemLevelColor(1)
      assert.are.equal(1.0, r)
      assert.are.equal(0.0, g)
      assert.are.equal(0.0, b)
    end)

    it("handles edge case where item level equals high breakpoint exactly", function()
      -- highPoint = floor(489 * 0.86) = 420
      -- 420 >= 420, so high color
      local r, g, b = color:GetItemLevelColor(420)
      assert.are.equal(0.0, r)
      assert.are.equal(0.5, g)
      assert.are.equal(1.0, b)
    end)

    it("returns high color just below max", function()
      local r, g, b = color:GetItemLevelColor(488)
      -- 488 >= 420 (highPoint) but < 489 (max)
      assert.are.equal(0.0, r)
      assert.are.equal(0.5, g)
      assert.are.equal(1.0, b)
    end)
  end)
end)
