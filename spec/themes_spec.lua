-- themes_spec.lua -- Unit tests for themes/themes.lua and flat frame layout offsets.

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Stub dependencies
local const = StubBetterBagsModule("Constants")
const.WINDOW_KIND = {
  PORTRAIT = "portrait",
  SIMPLE = "simple",
  FLAT = "flat"
}

local L = StubBetterBagsModule("Localization")
L.G = function(self, key) return key end

local events = StubBetterBagsModule("Events")
events.SendMessage = function() end

local async = StubBetterBagsModule("Async")
async.AfterCombat = function(self, fn) fn() end

local db = StubBetterBagsModule("Database")

-- Load the real Context module
LoadBetterBagsModule("core/context.lua")

-- Load the real Themes module
LoadBetterBagsModule("themes/themes.lua")
local themes = addon:GetModule("Themes")

describe("Themes", function()
  local activeTheme = "Default"

  before_each(function()
    activeTheme = "Default"
    db.GetTheme = function() return activeTheme end
    db.SetTheme = function(self, key) activeTheme = key end
    db.GetBagSizeInfo = function() return { opacity = 100 } end
    db.GetBagView = function() return "section" end
    db.GetInBagSearch = function() return false end

    themes.themes = {}
    themes:OnInitialize()
  end)

  after_each(function()
    ResetModuleStub("Themes", "themes/themes.lua")
    ResetModuleStub("Context", "core/context.lua")
  end)

  describe("GetFlatHeaderHeight", function()
    it("should return 30 for any frame with a non-empty title", function()
      local frame = CreateFrame("Frame", "TestFlatFrameWithTitle")
      themes:RegisterFlatWindow(frame, "Some Title")

      -- Assert height is 30
      assert.are.equal(30, themes:GetFlatHeaderHeight(frame))
    end)

    it("should return 30 for flat frame with empty title in Default theme", function()
      local frame = CreateFrame("Frame", "TestFlatFrameNoTitleDefault")
      themes:RegisterFlatWindow(frame, "")

      -- Assert height is 30
      assert.are.equal(30, themes:GetFlatHeaderHeight(frame))
    end)

    it("should return 0 for flat frame with empty title in SimpleDark theme", function()
      local frame = CreateFrame("Frame", "TestFlatFrameNoTitleSimpleDark")
      themes:RegisterFlatWindow(frame, "")

      -- Setup simple dark theme mock
      themes:RegisterTheme("SimpleDark", {
        Name = "Simple Dark",
        Available = true,
        Portrait = function() end,
        Simple = function() end,
        Flat = function() end,
        Opacity = function() end,
        SectionFont = function() end,
        Reset = function() end,
        SetTitle = function() end,
        ToggleSearch = function() end,
      })
      activeTheme = "SimpleDark"

      -- Assert height is 0
      assert.are.equal(0, themes:GetFlatHeaderHeight(frame))
    end)

    it("should return custom value from theme callback if defined", function()
      local frame = CreateFrame("Frame", "TestFlatFrameNoTitleCustom")
      themes:RegisterFlatWindow(frame, "")

      -- Setup a theme with custom callback
      themes:RegisterTheme("CustomTheme", {
        Name = "Custom Theme",
        Available = true,
        Portrait = function() end,
        Simple = function() end,
        Flat = function() end,
        Opacity = function() end,
        SectionFont = function() end,
        Reset = function() end,
        SetTitle = function() end,
        ToggleSearch = function() end,
        GetFlatHeaderHeight = function(f)
          return 45
        end,
      })
      activeTheme = "CustomTheme"

      -- Assert height is 45
      assert.are.equal(45, themes:GetFlatHeaderHeight(frame))
    end)
  end)
end)
