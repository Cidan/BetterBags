local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Load required real modules
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")

local events = addon:GetModule("Events")
events:Init()

local ctx = addon:GetModule("Context")

-- Stub dependencies needed to load frames/bagslots.lua
local L = StubBetterBagsModule("Localization")
L.G = function(_, key) return key end

local database = StubBetterBagsModule("Database")
database.GetGroupsEnabled = function() return false end

local const = StubBetterBagsModule("Constants")
const.BAG_KIND = { BACKPACK = 1, BANK = 2 }
const.BAG_VIEW = { SECTION_GRID = 1, SECTION_ALL_BAGS = 2 }
const.BACKPACK_ONLY_BAGS_LIST = { 1, 2, 3, 4 }
const.BANK_ONLY_BAGS_LIST = { 5, 6, 7, 8 }
const.OFFSETS = {
  BAG_LEFT_INSET = 6,
  BAG_RIGHT_INSET = -6,
}

local themes = StubBetterBagsModule("Themes")
themes.RegisterFlatWindow = function() end
themes.GetFlatHeaderHeight = function() return 30 end

local debug = StubBetterBagsModule("Debug")
debug.Log = function() end

local animations = StubBetterBagsModule("Animations")
animations.AttachFadeAndSlideTop = function()
  local g = { Play = function() end, Stop = function() end, HookScript = function() end }
  return g, g
end

StubBetterBagsModule("BagButton")
StubBetterBagsModule("Grid")

ResetModuleStub("BagSlots", "frames/bagslots.lua")
LoadBetterBagsModule("frames/bagslots.lua")

-- CLASSIC_PADDING must match the constant used inside frames/bagslots.lua.
local PAD = 8

---Builds a minimal bag-slots panel object bound to the real bagSlotProto, with a
---content grid that reports a fixed (w, h) and a container/frame that record the
---layout points the Draw method assigns.
local function newPanel(contentW, contentH)
  local bagSlots = addon:GetModule("BagSlots")
  local panel = setmetatable({}, { __index = bagSlots.bagSlotProto })

  local container = { points = {} }
  container.ClearAllPoints = function(self) self.points = {} end
  container.SetPoint = function(self, point, _, _, x, y)
    self.points[point] = { x = x, y = y }
  end

  panel.frame = {
    width = nil,
    height = nil,
    SetWidth = function(self, w) self.width = w end,
    SetHeight = function(self, h) self.height = h end,
  }

  panel.content = {
    cells = {},
    Draw = function() return contentW, contentH end,
    GetContainer = function() return container end,
  }
  panel._container = container
  return panel
end

describe("BagSlots panel layout", function()
  local savedIsRetail, savedIsForever
  before_each(function() savedIsRetail = addon.isRetail; savedIsForever = addon.isForever end)
  after_each(function() addon.isRetail = savedIsRetail; addon.isForever = savedIsForever end)

  it("centers the bags with symmetric padding on Classic/Era (flat panel, no title bar)", function()
    addon.isRetail = false
    local panel = newPanel(120, 40)
    panel:Draw(ctx:New("test"))

    -- The frame wraps the content with equal padding on every side, so the bag
    -- grid is centered both horizontally and vertically.
    assert.are.equal(120 + PAD * 2, panel.frame.width)
    assert.are.equal(40 + PAD * 2, panel.frame.height)

    local c = panel._container
    assert.are.equal(PAD, c.points["TOPLEFT"].x)
    assert.are.equal(-PAD, c.points["TOPLEFT"].y)
    assert.are.equal(-PAD, c.points["BOTTOMRIGHT"].x)
    assert.are.equal(PAD, c.points["BOTTOMRIGHT"].y)
  end)

  it("aligns the first bag button with the item column on Camelot (headerless tooltip panel)", function()
    addon.isRetail = true
    addon.isForever = true
    local panel = newPanel(120, 40)
    panel:Draw(ctx:New("test"))

    -- Camelot is headerless (no phantom themed header, so symmetric vertical padding),
    -- but the left inset matches the main window's item column (BAG_LEFT_INSET + 4) so
    -- the first bag button lines up with the first item column -- NOT the fully
    -- symmetric CLASSIC_PADDING left inset, which would sit ~2px too far left.
    local leftInset = const.OFFSETS.BAG_LEFT_INSET + 4
    assert.are.equal(120 + leftInset + PAD, panel.frame.width)
    assert.are.equal(40 + PAD * 2, panel.frame.height)
    local c = panel._container
    assert.are.equal(leftInset, c.points["TOPLEFT"].x)
    assert.are.equal(-PAD, c.points["TOPLEFT"].y)
    assert.are.equal(-PAD, c.points["BOTTOMRIGHT"].x)
    assert.are.equal(PAD, c.points["BOTTOMRIGHT"].y)
  end)

  it("keeps the retail themed-header layout unchanged", function()
    addon.isRetail = true
    addon.isForever = false
    local panel = newPanel(120, 40)
    panel:Draw(ctx:New("test"))

    -- Retail reserves the themed flat-window header (GetFlatHeaderHeight == 30)
    -- at the top and 12px at the bottom.
    assert.are.equal(120 + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET + 4, panel.frame.width)
    assert.are.equal(40 + 30 + 12, panel.frame.height)

    local c = panel._container
    assert.are.equal(-30, c.points["TOPLEFT"].y)
    assert.are.equal(12, c.points["BOTTOMRIGHT"].y)
  end)
end)
