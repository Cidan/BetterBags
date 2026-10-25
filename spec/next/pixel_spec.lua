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

  it("rounds room down and needs up, a hair past a whole pixel staying on it", function()
    local unit = pixel:Unit(UIParent)
    assert.is_true(near(9 * unit, pixel:Floor(UIParent, 9.9 * unit)))
    assert.is_true(near(10 * unit, pixel:Ceil(UIParent, 9.1 * unit)))
    assert.is_true(near(9 * unit, pixel:Floor(UIParent, 9 * unit - 1e-9)), "float error below a whole pixel")
    assert.is_true(near(9 * unit, pixel:Ceil(UIParent, 9 * unit + 1e-9)), "float error above one")
  end)

  it("works on the grid of an effective scale a region has not taken yet", function()
    local unit = pixel:UnitAt(0.65 * 0.85)
    assert.is_true(near((768 / 1362) / (0.65 * 0.85), unit))
    assert.is_true(near(9 * unit, pixel:SnapIn(unit, 9.3 * unit)))
    assert.is_true(near(unit, pixel:LengthIn(unit, 0.1 * unit)))
    assert.are.equal(0, pixel:LengthIn(unit, 0))
    assert.is_true(near(9 * unit, pixel:FloorIn(unit, 9.9 * unit)))
  end)

  it("rounds several lengths at once", function()
    local unit = pixel:Unit(UIParent)
    local a, b, c = pixel:Lengths(UIParent, 44, 4, 0)
    assert.is_true(near(51 * unit, a) and near(5 * unit, b))
    assert.are.equal(0, c)
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
    local unit = pixel:Unit(window)
    local _, _, _, tx, ty = text:GetPoint(1)
    assert.is_true(near(25.25 * unit, tx) and near(-27.75 * unit, ty), "a text a quarter pixel right and up")
    local _, _, _, lx, ly = line:GetPoint(1)
    assert.is_true(near(21 * unit, lx) and near(-46 * unit, ly), "a texture on whole pixels")
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

  -- A text or an icon centered on a row's height by its top: the room left over split, the odd pixel below.
  it("works out the offset that centers a length in another on whole pixels, the odd pixel after", function()
    local unit = pixel:Unit(UIParent)
    assert.is_true(near(4 * unit, pixel:Middle(UIParent, 25 * unit, 16 * unit)), "9 left over: 4 before")
    assert.is_true(near(5 * unit, pixel:Middle(UIParent, 26 * unit, 16 * unit)))
    assert.is_true(near(4 * unit, pixel:Middle(UIParent, 24.6 * unit, 16.2 * unit)), "both rounded first")
    assert.are.equal(0, pixel:Middle(UIParent, 10 * unit, 12 * unit), "never before the start")
  end)

  -- An icon or a text on a row of a control: by its corner, x in from the corner's side, centered on the
  -- row's height (a text by its font's), all in whole pixels.
  it("places a region on a row by its corner, centered on the row's height", function()
    local unit = pixel:Unit(UIParent)
    local button = CreateFrame("Button", nil, UIParent)
    button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    button:SetSize(100 * unit, 25 * unit)
    local icon = button:CreateTexture()
    icon:SetSize(16 * unit, 16 * unit)
    pixel:Row(icon, "TOPLEFT", button, 6 * unit, 25 * unit)
    local point, rel, relPoint, x, y = icon:GetPoint(1)
    assert.are.same({ "TOPLEFT", button, "TOPLEFT" }, { point, rel, relPoint })
    assert.is_true(near(6 * unit, x) and near(-4 * unit, y), "9 pixels left over: 4 above")
    local text = button:CreateFontString()
    text:SetFont("Fonts\\FRIZQT__.TTF", 12 * unit, "")
    pixel:Row(text, "TOPRIGHT", button, 6.3 * unit, 25 * unit, nil, 10 * unit)
    point, rel, relPoint, x, y = text:GetPoint(1)
    assert.are.same({ "TOPRIGHT", button, "TOPRIGHT" }, { point, rel, relPoint })
    assert.is_true(near(-5.75 * unit, x) and near(-15.75 * unit, y),
      "by its font's height, below a row 10 down, a quarter pixel right and up")
    assert.are.same({}, layout.PixelCheck(button))
  end)

  -- Measured in game (next-pixel-perfect.md §2): the client draws text in whole pixels, and a text exactly on a
  -- whole pixel was drawn in one or the next as float error of a thousandth of a pixel crossed it (tab names and an
  -- item count a pixel right as a panel's snap ended, their left edges at 2758.999, then 2759.000). A quarter pixel
  -- right of and above it, it is drawn in the same one whether the client rounds or truncates.
  describe("text, a quarter pixel in", function()
    local unit, frame
    before_each(function()
      unit = pixel:Unit(UIParent)
      frame = CreateFrame("Frame", nil, UIParent)
      frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
      frame:SetSize(100 * unit, 40 * unit)
    end)

    local function text()
      local t = frame:CreateFontString()
      t:SetFont("Fonts\\FRIZQT__.TTF", 12 * unit, "")
      t:SetText("13")
      return t
    end

    it("is the quarter pixel of a region's grid", function()
      assert.is_true(near(0.25 * unit, pixel:TextOffset(text())))
      local scaled = CreateFrame("Frame", nil, UIParent)
      scaled:SetScale(0.5)
      assert.is_true(near(0.5 * unit, pixel:TextOffset(scaled:CreateFontString())), "on its own grid")
    end)

    it("insets a text a quarter pixel right and up, keeping its size", function()
      local t = text()
      pixel:Inset(t, frame, 2 * unit, 3 * unit, 4 * unit, 5 * unit)
      local _, _, _, x1, y1 = t:GetPoint(1)
      local _, _, _, x2, y2 = t:GetPoint(2)
      assert.is_true(near(2.25 * unit, x1) and near(-3.75 * unit, y1))
      assert.is_true(near(-2.75 * unit, x2) and near(5.25 * unit, y2))
      assert.are.same({}, layout.PixelCheck(frame))
    end)

    it("sets an edit box's text insets in whole pixels, its text a quarter pixel right and up", function()
      local box = CreateFrame("EditBox", nil, frame)
      box:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
      box:SetSize(80 * unit, 20 * unit)
      pixel:TextInsets(box, 6.2 * unit, 4 * unit, 3.9 * unit, 4 * unit)
      local left, right, top, bottom = box:GetTextInsets()
      assert.is_true(near(6.25 * unit, left) and near(3.75 * unit, right), "6 and 4 pixels, a quarter right")
      assert.is_true(near(3.75 * unit, top) and near(4.25 * unit, bottom), "4 and 4 pixels, a quarter up")
      assert.are.same({}, layout.PixelCheck(frame))
    end)

    it("leaves textures and frames on whole pixels", function()
      local tex = frame:CreateTexture()
      pixel:Inset(tex, frame, 2 * unit, 3 * unit, 4 * unit, 5 * unit)
      pixel:Center(CreateFrame("Frame", nil, frame), frame, 100 * unit, 40 * unit, 15 * unit, 12 * unit)
      local _, _, _, x, y = tex:GetPoint(1)
      assert.is_true(near(2 * unit, x) and near(-4 * unit, y))
      assert.are.same({}, layout.PixelCheck(frame))
    end)
  end)

  -- A scroll box anchors its scroll target at the scroll offset, in UI units (ScrollBoxBaseMixin:
  -- SetScrollTargetOffset): scrolled to rest, what it holds lands between pixels unless that offset is
  -- rounded.
  describe("a scroll box", function()
    local box, row

    before_each(function()
      local window = CreateFrame("Frame", nil, UIParent)
      pixel:Point(window, "TOPLEFT", UIParent, "TOPLEFT", 40, -40)
      pixel:Size(window, 300, 200)
      box = CreateFrame("Frame", nil, window, "WowScrollBox")
      box:SetAllPoints(window)
      local content = CreateFrame("Frame", nil, box)
      content.scrollable = true
      content:SetHeight(pixel:Length(window, 700))
      box:Init(CreateScrollBoxLinearView())
      row = content:CreateTexture()
      pixel:Point(row, "TOPLEFT", content, "TOPLEFT", 6, -30)
      pixel:Size(row, 100, 1)
    end)

    it("puts what it holds between pixels where it is left scrolled", function()
      box:SetScrollPercentage(0.37, true)
      assert.is_true(#layout.PixelCheck(row) > 0)
    end)

    it("keeps what it holds on whole pixels wherever it is scrolled to, once its offset is rounded", function()
      pixel:SnapScroll(box)
      for _, share in ipairs({ 0, 0.1, 0.37, 0.5, 0.999, 1 }) do
        box:SetScrollPercentage(share, true)
        assert.are.same({}, layout.PixelCheck(row), "at " .. share)
      end
      box:FullUpdate(true)
      assert.are.same({}, layout.PixelCheck(row), "laid out again")
      pixel:SnapScroll(box)
      box:SetScrollPercentage(0.42, true)
      assert.are.same({}, layout.PixelCheck(row), "rounded once, however often asked")
      local _, _, _, _, y = box:GetScrollTarget():GetPoint(1)
      assert.is_true(math.abs(y - pixel:Snap(box, box:GetDerivedScrollOffset())) < 1e-9)
    end)
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
