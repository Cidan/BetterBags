-- anchor_spec.lua -- The classic bags' anchor (frames/anchor.lua): a blue square the bag's corner is pinned to. Its look is
-- Anchor:CreateSquare, which BetterBags Next's anchor shows too (docs/next-bag-anchor.md: one look for both designs).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")

-- Stubs this file creates are removed after it (the teardown at the end), so a later spec file can load the real modules.
local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local database = trackStub("Database")

local libWindow = LibStub:NewLibrary("LibWindow-1.1", 1) or LibStub("LibWindow-1.1")

ResetModuleStub("Anchor", "frames/anchor.lua")
LoadBetterBagsModule("frames/anchor.lua")

local anchor = addon:GetModule("Anchor")

describe("the bags' anchor", function()
  local replaced, registered, state

  local function override(tbl, key, value)
    table.insert(replaced, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  before_each(function()
    replaced, registered = {}, {}
    state = { enabled = false, shown = false }
    override(database, "GetAnchorState", function() return state end)
    override(database, "GetAnchorPosition", function() return {} end)
    override(libWindow, "RegisterConfig", function(frame, config) table.insert(registered, { frame, config }) end)
    override(libWindow, "RestorePosition", function() end)
    override(libWindow, "SavePosition", function() end)
  end)

  after_each(function()
    for i = #replaced, 1, -1 do
      replaced[i][1][replaced[i][2]] = replaced[i][3]
    end
  end)

  teardown(function()
    ResetModuleStub("Anchor")
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  describe("its square (CreateSquare)", function()
    it("is 72 across on UIParent, Blizzard's tooltip background in blue with a black edge, over everything, hidden", function()
      local square = anchor:CreateSquare("BetterBagsSpecSquare", "Backpack")
      assert.are.equal(UIParent, square:GetParent())
      assert.are.equal("BetterBagsSpecSquare", square:GetName())
      assert.are.same({ 72, 72 }, { square:GetSize() })
      local backdrop = square:GetBackdrop()
      assert.are.equal("Interface/Tooltips/UI-Tooltip-Background", backdrop.bgFile)
      assert.are.equal("Interface/Tooltips/UI-Tooltip-Background", backdrop.edgeFile)
      assert.are.equal(1, backdrop.edgeSize)
      assert.are.same({ 48 / 255, 168 / 255, 1, 1 }, { square:GetBackdropColor() })
      assert.are.same({ 0, 0, 0, 1 }, { square:GetBackdropBorderColor() })
      assert.are.equal("FULLSCREEN_DIALOG", square:GetFrameStrata())
      assert.is_true(square:IsMovable())
      assert.is_false(square:IsShown())
    end)

    it("says whose it is at its top, and where it is at its bottom", function()
      local square = anchor:CreateSquare(nil, "Bank")
      assert.are.equal("Bank", square.label:GetText())
      assert.are.same({ "TOP", square, "TOP", 0, -4 }, { square.label:GetPoint(1) })
      assert.are.equal("", square.positionLabel:GetText())
      assert.are.same({ "BOTTOM", square, "BOTTOM", 0, 4 }, { square.positionLabel:GetPoint(1) })
    end)
  end)

  describe("the classic bags' (New)", function()
    -- It reads where it is on the screen (its quadrant, its center): a screen that lays frames out from their anchors.
    local layoutHelper = dofile("spec/helpers/layout.lua")
    local restoreScreen

    before_each(function()
      restoreScreen = layoutHelper.UseScreen(1920, 1080, 1)
    end)

    after_each(function()
      restoreScreen()
    end)

    it("is the square, centered until placed, named for its bag, its place saved with LibWindow", function()
      local bag = CreateFrame("Frame", "BetterBagsSpecBag", UIParent)
      local a = anchor:New(0, bag, "Backpack")
      assert.are.equal("BetterBagsSpecBagAnchor", a.frame:GetName())
      assert.are.same({ 72, 72 }, { a.frame:GetSize() })
      assert.are.same({ 48 / 255, 168 / 255, 1, 1 }, { a.frame:GetBackdropColor() })
      assert.are.equal("FULLSCREEN_DIALOG", a.frame:GetFrameStrata())
      assert.are.equal("Backpack", a.label:GetText())
      assert.are.equal(a.frame.label, a.label)
      assert.are.equal(a.frame.positionLabel, a.positionLabel)
      assert.are.same({ "CENTER", UIParent, "CENTER", 0, 0 }, { a.frame:GetPoint(1) })
      assert.are.equal(a.frame, registered[1][1])
      assert.is_false(a.frame:IsShown(), "hidden as saved")
      assert.is_false(a.frame:IsMouseEnabled(), "off until enabled")
    end)

    it("hides on a right click, still enabled, and shows and pins the bag as saved", function()
      state = { enabled = true, shown = true }
      local bag = CreateFrame("Frame", "BetterBagsSpecBag2", UIParent)
      local a = anchor:New(0, bag, "Backpack")
      assert.is_true(a.frame:IsShown())
      assert.is_true(a:IsActive())
      a.frame:GetScript("OnMouseDown")(a.frame, "RightButton")
      assert.is_false(a.frame:IsShown())
      assert.is_false(state.shown)
      assert.is_true(state.enabled)
    end)
  end)
end)
