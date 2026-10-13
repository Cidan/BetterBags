-- themes_spec.lua -- Unit tests for themes/themes.lua and flat frame layout offsets.

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Stub dependencies
local const = StubBetterBagsModule("Constants")
const.WINDOW_KIND = {
  PORTRAIT = "portrait",
  SIMPLE = "simple",
  FLAT = "flat"
}
const.BAG_KIND = {
  BACKPACK = 0,
  BANK = 1
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
ResetModuleStub("Themes", "themes/themes.lua")
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
    themes:Init()
  end)

  teardown(function()
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

  describe("ApplyTheme slot positioning and dynamic updates", function()
    local ctx

    before_each(function()
      ctx = {}
      -- Register Default theme
      themes:RegisterTheme("Default", {
        Name = "Default",
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
    end)

    it("should correctly position and redraw shown bank slots at the bottom", function()
      -- Create a mock portrait frame (like a bank window)
      local frame = CreateFrame("Frame", "TestBankWindow")
      local slotsDrawCalled = false
      local slotsFramePoints = {}

      local slotsMock = {
        frame = CreateFrame("Frame", "TestBankSlotsFrame"),
        IsShown = function() return true end,
        Draw = function(self, context)
          slotsDrawCalled = true
        end
      }

      slotsMock.frame.ClearAllPoints = function()
        slotsFramePoints = {}
      end
      slotsMock.frame.SetPoint = function(self, point, relFrame, relPoint, x, y)
        table.insert(slotsFramePoints, { point = point, relFrame = relFrame, relPoint = relPoint, x = x, y = y })
      end

      -- Owner represent the Bag/Bank controller
      frame.Owner = {
        kind = const.BAG_KIND.BANK,
        slots = slotsMock,
        sideAnchor = CreateFrame("Frame"),
      }

      -- Register as portrait window
      themes:RegisterPortraitWindow(frame, "Bank")

      -- Apply Default theme
      themes:ApplyTheme(ctx, "Default")

      -- Assert slots were positioned at the bottom of the bank window
      assert.is_true(#slotsFramePoints > 0)
      local lastPoint = slotsFramePoints[#slotsFramePoints]
      assert.are.equal("TOPLEFT", lastPoint.point)
      assert.are.equal(frame, lastPoint.relFrame)
      assert.are.equal("BOTTOMLEFT", lastPoint.relPoint)
      assert.are.equal(0, lastPoint.x)
      assert.are.equal(-2, lastPoint.y)

      -- Assert Draw was called on the shown bank slots
      assert.is_true(slotsDrawCalled)
    end)

    it("should correctly position and redraw shown backpack slots at the bottom", function()
      -- Create a mock portrait frame (like a backpack window)
      local frame = CreateFrame("Frame", "TestBackpackWindow")
      local slotsDrawCalled = false
      local slotsFramePoints = {}

      local slotsMock = {
        frame = CreateFrame("Frame", "TestBackpackSlotsFrame"),
        IsShown = function() return true end,
        Draw = function(self, context)
          slotsDrawCalled = true
        end
      }

      slotsMock.frame.ClearAllPoints = function()
        slotsFramePoints = {}
      end
      slotsMock.frame.SetPoint = function(self, point, relFrame, relPoint, x, y)
        table.insert(slotsFramePoints, { point = point, relFrame = relFrame, relPoint = relPoint, x = x, y = y })
      end

      -- Owner represent the Bag/Bank controller
      frame.Owner = {
        kind = const.BAG_KIND.BACKPACK,
        slots = slotsMock,
        sideAnchor = CreateFrame("Frame"),
      }

      -- Register as portrait window
      themes:RegisterPortraitWindow(frame, "Backpack")

      -- Apply Default theme
      themes:ApplyTheme(ctx, "Default")

      -- Assert slots were positioned at the bottom of the backpack window
      assert.is_true(#slotsFramePoints > 0)
      local lastPoint = slotsFramePoints[#slotsFramePoints]
      assert.are.equal("TOPLEFT", lastPoint.point)
      assert.are.equal(frame, lastPoint.relFrame)
      assert.are.equal("BOTTOMLEFT", lastPoint.relPoint)
      assert.are.equal(0, lastPoint.x)
      assert.are.equal(-2, lastPoint.y)

      -- Assert Draw was called on the shown backpack slots
      assert.is_true(slotsDrawCalled)
    end)

    it("should position hidden bank slots at the top starting position and NOT redraw them", function()
      local frame = CreateFrame("Frame", "TestHiddenBankWindow")
      local slotsDrawCalled = false
      local slotsFramePoints = {}

      local slotsMock = {
        frame = CreateFrame("Frame", "TestHiddenBankSlotsFrame"),
        IsShown = function() return false end,
        Draw = function(self, context)
          slotsDrawCalled = true
        end
      }

      slotsMock.frame.ClearAllPoints = function()
        slotsFramePoints = {}
      end
      slotsMock.frame.SetPoint = function(self, point, relFrame, relPoint, x, y)
        table.insert(slotsFramePoints, { point = point, relFrame = relFrame, relPoint = relPoint, x = x, y = y })
      end

      frame.Owner = {
        kind = const.BAG_KIND.BANK,
        slots = slotsMock,
        sideAnchor = CreateFrame("Frame"),
      }

      themes:RegisterPortraitWindow(frame, "Bank")
      themes:ApplyTheme(ctx, "Default")

      -- Assert slots were positioned at the top starting position
      assert.is_true(#slotsFramePoints > 0)
      local lastPoint = slotsFramePoints[#slotsFramePoints]
      assert.are.equal("BOTTOMLEFT", lastPoint.point)
      assert.are.equal(frame, lastPoint.relFrame)
      assert.are.equal("TOPLEFT", lastPoint.relPoint)
      assert.are.equal(0, lastPoint.x)
      assert.are.equal(14, lastPoint.y)

      -- Assert Draw was NOT called on hidden bank slots
      assert.is_false(slotsDrawCalled)
    end)

    it("should prioritize custom PositionBagSlots theme callback if defined", function()
      local frame = CreateFrame("Frame", "TestCustomCallbackWindow")
      local customCallbackCalled = false
      local slotsDrawCalled = false

      themes:RegisterTheme("CustomPositionTheme", {
        Name = "Custom Position Theme",
        Available = true,
        Portrait = function() end,
        Simple = function() end,
        Flat = function() end,
        Opacity = function() end,
        SectionFont = function() end,
        Reset = function() end,
        SetTitle = function() end,
        ToggleSearch = function() end,
        PositionBagSlots = function(f, bagSlotWindow)
          customCallbackCalled = true
        end
      })

      local slotsMock = {
        frame = CreateFrame("Frame", "TestCustomCallbackSlotsFrame"),
        IsShown = function() return true end,
        Draw = function(self, context)
          slotsDrawCalled = true
        end
      }

      frame.Owner = {
        kind = const.BAG_KIND.BACKPACK,
        slots = slotsMock,
        sideAnchor = CreateFrame("Frame"),
      }

      themes:RegisterPortraitWindow(frame, "Backpack")
      themes:ApplyTheme(ctx, "CustomPositionTheme")

      assert.is_true(customCallbackCalled)
      assert.is_true(slotsDrawCalled)
    end)
  end)

  describe("GW2 theme PositionBagSlots", function()
    local gw2Theme

    before_each(function()
      _G.GW2_ADDON = {
        CreateFrameHeaderWithBody = function() end,
        SkinBagSearchBox = function() end,
        BackdropTemplates = { Default = {} },
      }
      StubBetterBagsModule("ContextMenu")
      StubBetterBagsModule("SearchBox")
      local fonts = StubBetterBagsModule("Fonts")
      fonts.UnitFrame12White = {}

      -- Load gw2.lua
      local fn = assert(loadfile("themes/gw2.lua"))
      fn("BetterBags")
      gw2Theme = themes.themes["GW2"]
    end)

    after_each(function()
      _G.GW2_ADDON = nil
      ResetModuleStub("ContextMenu")
      ResetModuleStub("SearchBox")
      ResetModuleStub("Fonts")
    end)

    it("should anchor shown retail bank slots to the bottom", function()
      addon.isRetail = true
      local frame = CreateFrame("Frame", "TestGW2BankWindow")
      local slotsFramePoints = {}

      local slotsMock = {
        frame = CreateFrame("Frame", "TestGW2BankSlotsFrame"),
        IsShown = function() return true end,
      }

      slotsMock.frame.ClearAllPoints = function()
        slotsFramePoints = {}
      end
      slotsMock.frame.SetPoint = function(self, point, relFrame, relPoint, x, y)
        table.insert(slotsFramePoints, { point = point, relFrame = relFrame, relPoint = relPoint, x = x, y = y })
      end

      frame.Owner = {
        kind = const.BAG_KIND.BANK,
        slots = slotsMock,
      }

      gw2Theme.PositionBagSlots(frame, slotsMock.frame)

      assert.is_true(#slotsFramePoints > 0)
      local lastPoint = slotsFramePoints[#slotsFramePoints]
      assert.are.equal("TOPLEFT", lastPoint.point)
      assert.are.equal(frame, lastPoint.relFrame)
      assert.are.equal("BOTTOMLEFT", lastPoint.relPoint)
      assert.are.equal(0, lastPoint.x)
      assert.are.equal(-2, lastPoint.y)
    end)

    it("should anchor hidden retail bank slots to the top starting position", function()
      addon.isRetail = true
      local frame = CreateFrame("Frame", "TestGW2BankWindowHidden")
      local slotsFramePoints = {}

      local slotsMock = {
        frame = CreateFrame("Frame", "TestGW2BankSlotsFrameHidden"),
        IsShown = function() return false end,
      }

      slotsMock.frame.ClearAllPoints = function()
        slotsFramePoints = {}
      end
      slotsMock.frame.SetPoint = function(self, point, relFrame, relPoint, x, y)
        table.insert(slotsFramePoints, { point = point, relFrame = relFrame, relPoint = relPoint, x = x, y = y })
      end

      frame.Owner = {
        kind = const.BAG_KIND.BANK,
        slots = slotsMock,
      }

      gw2Theme.PositionBagSlots(frame, slotsMock.frame)

      assert.is_true(#slotsFramePoints > 0)
      local lastPoint = slotsFramePoints[#slotsFramePoints]
      assert.are.equal("BOTTOMLEFT", lastPoint.point)
      assert.are.equal(frame, lastPoint.relFrame)
      assert.are.equal("TOPLEFT", lastPoint.relPoint)
      assert.are.equal(8, lastPoint.x)
      assert.are.equal(16, lastPoint.y)
    end)

    it("should anchor retail backpack slots to the bottom position (0, -2) when shown", function()
      addon.isRetail = true
      local frame = CreateFrame("Frame", "TestGW2BackpackWindow")
      local slotsFramePoints = {}

      local slotsMock = {
        frame = CreateFrame("Frame", "TestGW2BackpackSlotsFrame"),
        IsShown = function() return true end,
      }

      slotsMock.frame.ClearAllPoints = function()
        slotsFramePoints = {}
      end
      slotsMock.frame.SetPoint = function(self, point, relFrame, relPoint, x, y)
        table.insert(slotsFramePoints, { point = point, relFrame = relFrame, relPoint = relPoint, x = x, y = y })
      end

      frame.Owner = {
        kind = const.BAG_KIND.BACKPACK,
        slots = slotsMock,
      }

      gw2Theme.PositionBagSlots(frame, slotsMock.frame)

      assert.is_true(#slotsFramePoints > 0)
      local lastPoint = slotsFramePoints[#slotsFramePoints]
      assert.are.equal("TOPLEFT", lastPoint.point)
      assert.are.equal(frame, lastPoint.relFrame)
      assert.are.equal("BOTTOMLEFT", lastPoint.relPoint)
      assert.are.equal(0, lastPoint.x)
      assert.are.equal(-2, lastPoint.y)
    end)

    it("should anchor retail backpack slots to the custom top position (8, 16) when hidden", function()
      addon.isRetail = true
      local frame = CreateFrame("Frame", "TestGW2BackpackWindowHidden")
      local slotsFramePoints = {}

      local slotsMock = {
        frame = CreateFrame("Frame", "TestGW2BackpackSlotsFrameHidden"),
        IsShown = function() return false end,
      }

      slotsMock.frame.ClearAllPoints = function()
        slotsFramePoints = {}
      end
      slotsMock.frame.SetPoint = function(self, point, relFrame, relPoint, x, y)
        table.insert(slotsFramePoints, { point = point, relFrame = relFrame, relPoint = relPoint, x = x, y = y })
      end

      frame.Owner = {
        kind = const.BAG_KIND.BACKPACK,
        slots = slotsMock,
      }

      gw2Theme.PositionBagSlots(frame, slotsMock.frame)

      assert.is_true(#slotsFramePoints > 0)
      local lastPoint = slotsFramePoints[#slotsFramePoints]
      assert.are.equal("BOTTOMLEFT", lastPoint.point)
      assert.are.equal(frame, lastPoint.relFrame)
      assert.are.equal("TOPLEFT", lastPoint.relPoint)
      assert.are.equal(8, lastPoint.x)
      assert.are.equal(16, lastPoint.y)
    end)

    it("should anchor classic bank slots to the bottom position (0, -2) when shown", function()
      addon.isRetail = false
      local frame = CreateFrame("Frame", "TestGW2ClassicBankWindow")
      local slotsFramePoints = {}

      local slotsMock = {
        frame = CreateFrame("Frame", "TestGW2ClassicBankSlotsFrame"),
        IsShown = function() return true end,
      }

      slotsMock.frame.ClearAllPoints = function()
        slotsFramePoints = {}
      end
      slotsMock.frame.SetPoint = function(self, point, relFrame, relPoint, x, y)
        table.insert(slotsFramePoints, { point = point, relFrame = relFrame, relPoint = relPoint, x = x, y = y })
      end

      frame.Owner = {
        kind = const.BAG_KIND.BANK,
        slots = slotsMock,
      }

      gw2Theme.PositionBagSlots(frame, slotsMock.frame)

      assert.is_true(#slotsFramePoints > 0)
      local lastPoint = slotsFramePoints[#slotsFramePoints]
      assert.are.equal("TOPLEFT", lastPoint.point)
      assert.are.equal(frame, lastPoint.relFrame)
      assert.are.equal("BOTTOMLEFT", lastPoint.relPoint)
      assert.are.equal(0, lastPoint.x)
      assert.are.equal(-2, lastPoint.y)
    end)

    it("should anchor classic bank slots to the custom top position (8, 16) when hidden", function()
      addon.isRetail = false
      local frame = CreateFrame("Frame", "TestGW2ClassicBankWindowHidden")
      local slotsFramePoints = {}

      local slotsMock = {
        frame = CreateFrame("Frame", "TestGW2ClassicBankSlotsFrameHidden"),
        IsShown = function() return false end,
      }

      slotsMock.frame.ClearAllPoints = function()
        slotsFramePoints = {}
      end
      slotsMock.frame.SetPoint = function(self, point, relFrame, relPoint, x, y)
        table.insert(slotsFramePoints, { point = point, relFrame = relFrame, relPoint = relPoint, x = x, y = y })
      end

      frame.Owner = {
        kind = const.BAG_KIND.BANK,
        slots = slotsMock,
      }

      gw2Theme.PositionBagSlots(frame, slotsMock.frame)

      assert.is_true(#slotsFramePoints > 0)
      local lastPoint = slotsFramePoints[#slotsFramePoints]
      assert.are.equal("BOTTOMLEFT", lastPoint.point)
      assert.are.equal(frame, lastPoint.relFrame)
      assert.are.equal("TOPLEFT", lastPoint.relPoint)
      assert.are.equal(8, lastPoint.x)
      assert.are.equal(16, lastPoint.y)
    end)
  end)

  -- Regression: issue #1076. themes:SetTitle is called during OnInitialize
  -- (ADDON_LOADED), before themes:OnEnable has run its fallback. If the saved
  -- theme key is not registered/available yet (e.g. a third-party theme whose
  -- addon has not loaded), SetTitle must fall back to the Default theme like
  -- its sibling accessors (GetCurrentTheme, GetFlatHeaderHeight, GetItemButton)
  -- instead of indexing a nil theme and aborting OnInitialize.
  describe("SetTitle fallback", function()
    before_each(function()
      themes:RegisterTheme("Default", {
        Name = "Default",
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
    end)

    it("does not error when the active theme is not registered", function()
      activeTheme = "SomeThirdPartyThemeNotLoadedYet"
      local frame = CreateFrame("Frame", "TestSetTitleFallbackFrame")
      assert.has_no.errors(function()
        themes:SetTitle(frame, "Backpack")
      end)
      assert.are.equal("Backpack", themes.titles[frame:GetName()])
    end)

    it("uses the Default theme's SetTitle when the active theme is unavailable", function()
      local defaultCalled = false
      themes:RegisterTheme("Default", {
        Name = "Default",
        Available = true,
        Portrait = function() end,
        Simple = function() end,
        Flat = function() end,
        Opacity = function() end,
        SectionFont = function() end,
        Reset = function() end,
        SetTitle = function() defaultCalled = true end,
        ToggleSearch = function() end,
      })
      themes:RegisterTheme("Broken", {
        Name = "Broken",
        Available = false,
        Portrait = function() end,
        Simple = function() end,
        Flat = function() end,
        Opacity = function() end,
        SectionFont = function() end,
        Reset = function() end,
        SetTitle = function() error("unavailable theme SetTitle must not run") end,
        ToggleSearch = function() end,
      })
      activeTheme = "Broken"
      local frame = CreateFrame("Frame", "TestSetTitleUnavailableFrame")
      assert.has_no.errors(function()
        themes:SetTitle(frame, "Bank")
      end)
      assert.is_true(defaultCalled)
    end)
  end)

  -- GetItemButton is called about ten times per item button on every redraw. Only the
  -- first lookup after a theme is applied may show the decoration and announce it with
  -- item/NewButton (Masque re-adds and re-skins a button on every announcement).
  describe("GetItemButton decoration cache", function()
    local announced
    local savedSendMessage
    local buttonCount = 0

    local function newItem()
      buttonCount = buttonCount + 1
      local holder = CreateFrame("Frame")
      local button = CreateFrame("Button", "TestDecorationCacheButton" .. buttonCount, holder)
      return { button = button, frame = holder }
    end

    local function theme(name, itemButton)
      return {
        Name = name,
        Available = true,
        Portrait = function() end,
        Simple = function() end,
        Flat = function() end,
        Opacity = function() end,
        SectionFont = function() end,
        Reset = function() end,
        SetTitle = function() end,
        ToggleSearch = function() end,
        ItemButton = itemButton,
      }
    end

    local function countShows(decoration)
      local shows = 0
      local show = decoration.Show
      decoration.Show = function(self)
        shows = shows + 1
        return show(self)
      end
      return function() return shows end
    end

    before_each(function()
      announced = {}
      savedSendMessage = events.SendMessage
      events.SendMessage = function(_, _, event, item)
        if event == "item/NewButton" then
          table.insert(announced, item)
        end
      end
      themes:RegisterTheme("Default", theme("Default"))
    end)

    after_each(function()
      events.SendMessage = savedSendMessage
    end)

    it("returns the cached decoration without showing or announcing it again", function()
      local item = newItem()
      local decoration = themes:GetItemButton(nil, item)
      local shows = countShows(decoration)
      assert.are.equal(1, #announced)

      for _ = 1, 10 do
        assert.are.equal(decoration, themes:GetItemButton(nil, item))
      end
      assert.are.equal(1, #announced)
      assert.are.equal(0, shows())
    end)

    it("shows and announces the decoration again after a theme is applied", function()
      local item = newItem()
      local decoration = themes:GetItemButton(nil, item)
      local shows = countShows(decoration)

      themes:ApplyTheme(nil, "Default")
      assert.are.equal(decoration, themes:GetItemButton(nil, item))
      assert.are.equal(1, shows())
      assert.are.equal(2, #announced)

      themes:GetItemButton(nil, item)
      assert.are.equal(1, shows())
      assert.are.equal(2, #announced)
    end)

    -- A theme with its own ItemButton (ElvUI) keeps its own decorations and re-applies
    -- per-lookup fixups (ElvUI re-pins its backdrop's frame level), so it is asked on
    -- every lookup; only the default decoration path is cached.
    it("asks a theme with its own ItemButton on every lookup, and falls back to the cache for Default", function()
      local custom = CreateFrame("Frame")
      local asked = 0
      themes:RegisterTheme("Custom", theme("Custom", function()
        asked = asked + 1
        return custom
      end))
      local item = newItem()
      local default = themes:GetItemButton(nil, item)

      activeTheme = "Custom"
      assert.are.equal(custom, themes:GetItemButton(nil, item))
      assert.are.equal(custom, themes:GetItemButton(nil, item))
      assert.are.equal(2, asked)

      -- Nothing hid the default decoration (only ApplyTheme does), so it is still cached.
      activeTheme = "Default"
      local shows = countShows(default)
      assert.are.equal(default, themes:GetItemButton(nil, item))
      assert.are.equal(0, shows())
    end)
  end)

  -- A theme only changes how the bags look: applying one redraws the bags and reads nothing.
  describe("ApplyTheme refresh", function()
    it("asks for a redraw with restyled buttons, not a full refresh", function()
      themes:RegisterTheme("Default", {
        Name = "Default",
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
      local sent = {}
      local original = events.SendMessage
      events.SendMessage = function(_, _, message, ...)
        table.insert(sent, { message = message, args = { ... } })
      end
      themes:ApplyTheme({}, "Default")
      events.SendMessage = original
      assert.equal(1, #sent)
      assert.equal("bags/Redraw", sent[1].message)
    end)
  end)
end)
