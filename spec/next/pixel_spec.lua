-- pixel_spec.lua -- NextPixel (next/pixel.lua): BetterBags Next on the screen's pixel grid
-- (docs/next-pixel-perfect.md). One screen pixel in a region's units is 768 over the screen's height,
-- over the region's effective scale; lengths and offsets are whole pixels of it.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
-- NextPixel follows the grid through BetterBags' Events module; the tests capture what it registers.
local events, createdEvents = StubBetterBagsModule("Events")
ResetModuleStub("NextPixel", "next/pixel.lua")
LoadBetterBagsModule("next/pixel.lua")
ResetModuleStub("NextStyle", "next/style.lua")
LoadBetterBagsModule("next/style.lua")
local pixel = addon:GetModule("NextPixel")
local layout = dofile("spec/helpers/layout.lua")

describe("NextPixel", function()
  local undo

  teardown(function()
    if createdEvents then
      ResetModuleStub("Events")
    end
  end)

  before_each(function()
    -- The reporter's window (Logs/gx.log) at the game's UI scale of 65%: a unit is 1.153 pixels.
    undo = layout.UseScreen(3396, 1362, 0.65)
  end)

  after_each(function()
    undo()
  end)

  local function near(a, b)
    return math.abs(a - b) < 1e-9
  end

  it("measures a screen pixel in a region's units, from the screen's height and its scale", function()
    local unit = (768 / 1362) / 0.65
    assert.is_true(near(unit, pixel:Unit(UIParent)))
    local panel = CreateFrame("Frame", nil, UIParent)
    panel:SetScale(0.5)
    local inside = CreateFrame("Frame", nil, panel)
    assert.is_true(near(unit / 0.5, pixel:Unit(inside)), "a scaled panel has its own grid")
  end)

  it("rounds offsets to whole pixels, half away from zero, none staying none", function()
    local unit = pixel:Unit(UIParent)
    assert.are.equal(9, pixel:Pixels(UIParent, 8), "8 units are 9.22 pixels")
    assert.are.equal(-9, pixel:Pixels(UIParent, -8))
    assert.is_true(near(9 * unit, pixel:Snap(UIParent, 8)))
    assert.is_true(near(-9 * unit, pixel:Snap(UIParent, -8)))
    assert.are.equal(0, pixel:Snap(UIParent, 0.2))
    assert.are.equal(0, pixel:Snap(UIParent, 0))
  end)

  it("rounds lengths to whole pixels, never below one when not none", function()
    local unit = pixel:Unit(UIParent)
    assert.is_true(near(51 * unit, pixel:Length(UIParent, 44)), "44 units are 50.7 pixels")
    assert.is_true(near(unit, pixel:Length(UIParent, 0.2)))
    assert.is_true(near(-unit, pixel:Length(UIParent, -0.2)))
    assert.are.equal(0, pixel:Length(UIParent, 0))
  end)

  it("anchors, insets and sizes regions on whole pixels", function()
    local window = CreateFrame("Frame", nil, UIParent)
    pixel:Size(window, 554, 700.3)
    pixel:Point(window, "TOPRIGHT", UIParent, "TOPRIGHT", -13.7, -21.1)
    local fill = window:CreateTexture()
    pixel:Inset(fill, window, 96, 0, 1, 2.6)
    local line = window:CreateTexture()
    pixel:Point(line, "TOPLEFT", window, "TOPLEFT", 18.4, -40)
    pixel:Size(line, 300, 1)
    local text = window:CreateFontString()
    text:SetFontObject(GameFontNormal)
    text:SetText("Backpack")
    pixel:Point(text, "TOPLEFT", window, "TOPLEFT", 22, -24.5)
    assert.are.same({}, layout.PixelCheck(window))
    local point, rel, relPoint = fill:GetPoint(2)
    assert.are.equal("BOTTOMRIGHT", point)
    assert.are.equal(window, rel)
    assert.are.equal("BOTTOMRIGHT", relPoint)
  end)

  it("anchors by the same point when no relative point is named", function()
    local window = CreateFrame("Frame", nil, UIParent)
    pixel:Point(window, "BOTTOMLEFT", UIParent, nil, 3, 3)
    assert.are.equal("BOTTOMLEFT", select(3, window:GetPoint(1)))
  end)

  it("centers a region on whole pixels, the odd pixel to the right and bottom", function()
    local unit = pixel:Unit(UIParent)
    local button = CreateFrame("Button", nil, UIParent)
    button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    button:SetSize(25 * unit, 25 * unit)
    local icon = button:CreateTexture()
    pixel:Center(icon, button, 25 * unit, 25 * unit, 16 * unit, 16 * unit)
    local _, _, _, x, y = icon:GetPoint(1)
    assert.is_true(near(4 * unit, x) and near(-4 * unit, y), "9 pixels left over: 4 before, 5 after")
    assert.is_true(near(16 * unit, icon:GetWidth()))
    pixel:Center(icon, button, 25 * unit, 25 * unit, 16 * unit, 16 * unit, 2 * unit, 1 * unit)
    _, _, _, x, y = icon:GetPoint(1)
    assert.is_true(near(6 * unit, x) and near(-3 * unit, y), "moved off the middle by whole pixels")
    assert.are.same({}, layout.PixelCheck(button))
  end)

  it("names the grid by UIParent's scale and the screen's height", function()
    assert.are.equal("0.650000@1362", pixel:Key())
    UIParent:SetScale(0.7)
    assert.are.equal("0.700000@1362", pixel:Key())
  end)

  -- A new grid (the UI scale, the window's size) changes every whole-pixel length and font height: the
  -- current Next theme is applied again, unsaved, so fonts are made again and everything lays out again.
  describe("a new grid", function()
    local sonataNext, style, applied, saved, handlers

    before_each(function()
      sonataNext = addon:GetModule("SonataNext")
      style = addon:GetModule("NextStyle")
      saved = { apply = sonataNext.ApplyTheme, register = events.RegisterEvent, current = sonataNext.current,
        started = sonataNext.started, watching = pixel.watching }
      sonataNext.current, sonataNext.started = "Default", true
      applied, handlers = {}, {}
      sonataNext.ApplyTheme = function(_, ctx, key, save)
        table.insert(applied, { ctx ~= nil, key, save })
      end
      events.RegisterEvent = function(_, event, fn)
        handlers[event] = handlers[event] or {}
        table.insert(handlers[event], fn)
      end
      pixel.watching = nil
      pixel:Init()
      style.gridKey = pixel:Key()
    end)

    after_each(function()
      sonataNext.ApplyTheme, events.RegisterEvent = saved.apply, saved.register
      sonataNext.current, sonataNext.started, pixel.watching = saved.current, saved.started, saved.watching
    end)

    local function fire(event)
      for _, fn in ipairs(handlers[event] or {}) do
        fn({})
      end
    end

    it("applies the current theme again, unsaved, when the UI scale or the screen's size changes it", function()
      assert.are.equal(1, #handlers.UI_SCALE_CHANGED)
      assert.are.equal(1, #handlers.DISPLAY_SIZE_CHANGED)
      UIParent:SetScale(0.7)
      fire("UI_SCALE_CHANGED")
      assert.are.same({ { true, "Default", false } }, applied)
      undo()
      undo = layout.UseScreen(3440, 1440, 0.7)
      fire("DISPLAY_SIZE_CHANGED")
      assert.are.equal(2, #applied)
    end)

    it("does nothing when the grid is the one the theme was applied for", function()
      fire("UI_SCALE_CHANGED")
      fire("DISPLAY_SIZE_CHANGED")
      assert.are.same({}, applied)
    end)

    it("does nothing before BetterBags Next's look has started", function()
      sonataNext.started = false
      UIParent:SetScale(0.7)
      fire("UI_SCALE_CHANGED")
      assert.are.same({}, applied)
    end)

    it("registers once however often it starts", function()
      pixel:Init()
      assert.are.equal(1, #handlers.UI_SCALE_CHANGED)
    end)
  end)

  it("remembers the grid each theme's fonts were made for", function()
    local style = addon:GetModule("NextStyle")
    style:Use(style.Theme)
    assert.are.equal(pixel:Key(), style.gridKey)
  end)

  it("rounds a font's height to whole pixels at UIParent's grid", function()
    local unit = pixel:Unit(UIParent)
    assert.is_true(near(15 * unit, pixel:FontHeight(13)), "13 units are 14.99 pixels")
    assert.is_true(near(14 * unit, pixel:FontHeight(12)), "12 units are 13.84 pixels")
  end)
end)
