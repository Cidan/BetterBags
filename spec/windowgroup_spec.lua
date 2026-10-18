-- windowgroup_spec.lua -- Unit tests for util/windowgroup.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
LoadBetterBagsModule("util/windowgroup.lua")
local windowGroup = addon:GetModule("WindowGroup")

--- Create a mock frame with Show/Hide/IsShown and fadeIn/fadeOut.
---@param name string
---@return table
local function MockFrame(name)
  local shown = false
  return {
    name = name,
    fadeIn = true,  -- just needs to be truthy for the assert in AddWindow
    fadeOut = true,
    Show = function(self)
      shown = true
    end,
    Hide = function(self, callback)
      shown = false
      if callback then callback() end
    end,
    IsShown = function()
      return shown
    end,
  }
end

describe("WindowGrouping", function()

  local group

  before_each(function()
    group = windowGroup:Create()
  end)

  -- ─── Create ─────────────────────────────────────────────────────────────────

  describe("Create", function()

    it("creates a new window group", function()
      assert.is_not_nil(group)
    end)

    it("creates independent groups", function()
      local group2 = windowGroup:Create()
      local frame = MockFrame("test")
      group:AddWindow("test", frame)
      -- group2 should not have the window
      assert.is_nil(group2.windows["test"])
    end)
  end)

  -- ─── AddWindow ──────────────────────────────────────────────────────────────

  describe("AddWindow", function()

    it("registers a frame by name", function()
      local frame = MockFrame("panel")
      group:AddWindow("panel", frame)
      assert.are.equal(frame, group.windows["panel"])
    end)

    it("errors if frame lacks fadeIn/fadeOut animations", function()
      local badFrame = {
        Show = function() end,
        Hide = function() end,
        IsShown = function() return false end,
      }
      assert.has_error(function()
        group:AddWindow("bad", badFrame)
      end)
    end)
  end)

  -- ─── Show ───────────────────────────────────────────────────────────────────

  describe("Show", function()

    it("shows a window that is not currently shown", function()
      local frame = MockFrame("panel")
      group:AddWindow("panel", frame)
      group:Show("panel")
      assert.is_true(frame:IsShown())
    end)

    it("hides a window that is currently shown (toggle behavior)", function()
      local frame = MockFrame("panel")
      group:AddWindow("panel", frame)
      group:Show("panel")
      assert.is_true(frame:IsShown())
      group:Show("panel")
      assert.is_false(frame:IsShown())
    end)

    it("hides other windows when showing a new one", function()
      local frameA = MockFrame("a")
      local frameB = MockFrame("b")
      group:AddWindow("a", frameA)
      group:AddWindow("b", frameB)

      group:Show("a")
      assert.is_true(frameA:IsShown())
      assert.is_false(frameB:IsShown())

      group:Show("b")
      assert.is_true(frameB:IsShown())
      assert.is_false(frameA:IsShown())
    end)

    it("shows the target via callback after hiding the first other window", function()
      local frameA = MockFrame("a")
      local frameB = MockFrame("b")
      local frameC = MockFrame("c")
      group:AddWindow("a", frameA)
      group:AddWindow("b", frameB)
      group:AddWindow("c", frameC)

      -- Show A and B
      frameA:Show()
      frameB:Show()

      -- Now show C - should hide A (with callback to show C) and B (immediate)
      group:Show("c")
      assert.is_true(frameC:IsShown())
      assert.is_false(frameA:IsShown())
      assert.is_false(frameB:IsShown())
    end)

    it("works correctly with no other windows registered", function()
      local frame = MockFrame("solo")
      group:AddWindow("solo", frame)
      group:Show("solo")
      assert.is_true(frame:IsShown())
    end)
  end)
end)
