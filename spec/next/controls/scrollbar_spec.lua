-- scrollbar_spec.lua -- NextScrollBar (next/controls/scrollbar.lua): BetterBags Next's own scroll bar
-- (next-settings.md §2), in place of Blizzard's MinimalScrollBar on every Next scroll box. It drives a
-- Blizzard scroll box the way ScrollUtil binds a bar to one (OnScroll, OnSizeChanged,
-- OnAllowScrollChanged; SetScrollPercentage, ScrollToOffset, ScrollInDirection), and is drawn from
-- the theme (Controls.ScrollBar).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")

for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local scrollBar = addon:GetModule("NextScrollBar")
local style = addon:GetModule("NextStyle")

describe("NextScrollBar", function()
  local box, bar

  -- A box 250 tall showing content 1000 tall, and its bar 200 tall at the screen's (0, 0).
  local function make(opts)
    local parent = CreateFrame("Frame")
    box = CreateFrame("Frame", nil, parent, "WowScrollBox")
    box:SetSize(300, 250)
    box:Init(CreateScrollBoxLinearView())
    box._extent = 1000
    bar = scrollBar:Create(box, opts)
    bar.frame:_SetRect(288, 0, 12, 200)
    bar:Bind(box)
    return bar
  end

  local function cursorAt(y)
    _G._cursorX, _G._cursorY = 294, y
  end

  local function thumbTop()
    local _, _, _, _, y = bar.thumb:GetPoint(1)
    return -y
  end

  local function S()
    return style.Theme.Controls.ScrollBar
  end

  before_each(function()
    _G._cursorX, _G._cursorY = 0, 0
    _G._mouseButtonsDown = {}
  end)

  after_each(function()
    _G._mouseButtonsDown = {}
    UseNextTheme(nil)
    scrollBar:ApplyStyle()
  end)

  describe("its look", function()
    it("sits in the box's right edge, Width wide, its track and thumb Size wide in the theme's colors", function()
      make()
      assert.are.equal(box, bar.frame:GetParent())
      assert.are.same({ "TOPRIGHT", box, "TOPRIGHT", -S().Inset, 0 }, { bar.frame:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", box, "BOTTOMRIGHT", -S().Inset, 0 }, { bar.frame:GetPoint(2) })
      assert.are.equal(S().Width, bar.frame:GetWidth())
      assert.are.equal(S().Size, bar.track:GetWidth())
      assert.are.equal(S().Size, bar.thumb:GetWidth())
      local r, g, b = style:RGBA("Lavender")
      assert.are.same({ r = r, g = g, b = b, a = S().Track.Alpha }, bar.track._colorTexture)
      assert.are.same({ r = r, g = g, b = b, a = S().Thumb.Alpha }, bar.thumbTexture._colorTexture)
    end)

    it("is restyled, every bar made, by a theme", function()
      make()
      UseNextTheme({ Controls = { ScrollBar = { Width = 10, Size = 8, Thumb = { Color = "Gold", Alpha = 1 } } } })
      scrollBar:ApplyStyle()
      assert.are.equal(10, bar.frame:GetWidth())
      assert.are.equal(8, bar.thumb:GetWidth())
      local r, g, b = style:RGBA("Gold")
      assert.are.same({ r = r, g = g, b = b, a = 1 }, bar.thumbTexture._colorTexture)
    end)
  end)

  describe("following its box", function()
    it("sizes its thumb to the share of the content shown, and moves it as the box scrolls", function()
      make()
      box:FullUpdate(true)
      assert.are.equal(50, bar.thumb:GetHeight(), "a quarter of the content shows: a quarter of the bar")
      assert.are.equal(0, thumbTop())
      box:SetScrollPercentage(0.5)
      assert.are.equal(75, thumbTop(), "halfway down the room the thumb moves in")
      box:SetScrollPercentage(1)
      assert.are.equal(150, thumbTop())
    end)

    it("keeps the thumb at least MinThumb tall", function()
      make()
      box._extent = 100000
      box:FullUpdate(true)
      assert.are.equal(S().MinThumb, bar.thumb:GetHeight())
      box:SetScrollPercentage(1)
      assert.are.equal(200 - S().MinThumb, thumbTop())
    end)

    it("hides while nothing scrolls, and shows again when something does", function()
      make()
      box._extent = 200
      box:FullUpdate(true)
      assert.is_false(bar.frame:IsShown())
      box._extent = 1000
      box:FullUpdate(true)
      assert.is_true(bar.frame:IsShown())
    end)

    it("lays its thumb out again when it changes size", function()
      make()
      box:FullUpdate(true)
      bar.frame:_SetRect(288, 0, 12, 400)
      bar.frame:GetScript("OnSizeChanged")(bar.frame, 12, 400)
      assert.are.equal(100, bar.thumb:GetHeight())
    end)

    it("is bound to one box once", function()
      make()
      bar:Bind(box)
      local count = 0
      for _ in pairs(box._callbacks[BaseScrollBoxEvents.OnScroll]) do count = count + 1 end
      assert.are.equal(1, count)
    end)
  end)

  describe("driving its box", function()
    it("scrolls the box as its thumb is dragged, at once, and stops when the button is let go", function()
      make()
      box:FullUpdate(true)
      cursorAt(175)
      _G._mouseButtonsDown = { LeftButton = true }
      bar.thumb:GetScript("OnMouseDown")(bar.thumb, "LeftButton")
      assert.is_true(bar.dragging)
      local r, g, b = style:RGBA("Gold")
      assert.are.same({ r = r, g = g, b = b, a = S().ThumbDrag.Alpha }, bar.thumbTexture._colorTexture)
      cursorAt(100)
      bar.thumb:GetScript("OnUpdate")(bar.thumb, 0.016)
      assert.are.equal(0.5, box:GetScrollPercentage())
      assert.is_true(box._noInterpolation, "without interpolating: it follows the pointer")
      cursorAt(-500)
      bar.thumb:GetScript("OnUpdate")(bar.thumb, 0.016)
      assert.are.equal(1, box:GetScrollPercentage(), "no further than the end")
      _G._mouseButtonsDown = {}
      bar.thumb:GetScript("OnUpdate")(bar.thumb, 0.016)
      assert.is_false(bar.dragging)
      assert.is_nil(bar.thumb:GetScript("OnUpdate"), "it stops following the pointer")
      assert.are.equal(S().Thumb.Alpha, bar.thumbTexture._colorTexture.a)
      assert.are.equal(1, box:GetScrollPercentage())
    end)

    it("pages by the box's height on a click on its track above or below the thumb", function()
      make()
      box:FullUpdate(true)
      box:SetScrollPercentage(0.5)
      cursorAt(10)
      bar.frame:GetScript("OnMouseDown")(bar.frame, "LeftButton")
      assert.are.equal((375 + 250) / 750, box:GetScrollPercentage(), "a click below pages down")
      cursorAt(195)
      bar.frame:GetScript("OnMouseDown")(bar.frame, "LeftButton")
      assert.are.equal(0.5, box:GetScrollPercentage(), "a click above pages up")
      bar.frame:GetScript("OnMouseDown")(bar.frame, "RightButton")
      assert.are.equal(0.5, box:GetScrollPercentage(), "not on a right click")
    end)

    it("scrolls the box with the wheel over it", function()
      make()
      box.view._panExtent = 75
      box:FullUpdate(true)
      bar.frame:GetScript("OnMouseWheel")(bar.frame, -1)
      assert.are.equal(0.1, box:GetScrollPercentage())
      bar.frame:GetScript("OnMouseWheel")(bar.frame, 1)
      assert.are.equal(0, box:GetScrollPercentage())
    end)
  end)

  describe("under the pointer", function()
    it("widens and lights its thumb, and gives both back when the pointer leaves", function()
      make()
      box:FullUpdate(true)
      bar.frame:GetScript("OnEnter")(bar.frame)
      assert.are.equal(S().HoverSize, bar.thumb:GetWidth())
      assert.are.equal(S().ThumbHover.Alpha, bar.thumbTexture._colorTexture.a)
      bar.frame:GetScript("OnLeave")(bar.frame)
      assert.are.equal(S().Size, bar.thumb:GetWidth())
      assert.are.equal(S().Thumb.Alpha, bar.thumbTexture._colorTexture.a)
    end)

    it("stays lit while dragged with the pointer gone", function()
      make()
      box:FullUpdate(true)
      cursorAt(175)
      _G._mouseButtonsDown = { LeftButton = true }
      bar.thumb:GetScript("OnMouseDown")(bar.thumb, "LeftButton")
      bar.frame:GetScript("OnLeave")(bar.frame)
      assert.are.equal(S().HoverSize, bar.thumb:GetWidth())
    end)
  end)

  describe("hiding itself (AutoHide)", function()
    local function step(seconds)
      local update = bar.driver:GetScript("OnUpdate")
      for _ = 1, math.floor(seconds / 0.05 + 0.5) do
        update(bar.driver, 0.05)
      end
    end

    it("is always seen without it", function()
      make()
      assert.is_nil(bar.driver)
      assert.are.equal(1, bar.frame:GetAlpha())
    end)

    it("is invisible until the box scrolls, then fades in, lingers and fades out", function()
      make({ AutoHide = true })
      box:FullUpdate(true)
      assert.are.equal(0, bar.frame:GetAlpha())
      box:SetScrollPercentage(0.2)
      step(S().FadeIn)
      assert.are.equal(1, bar.frame:GetAlpha())
      step(S().Linger - S().FadeIn - 0.1)
      assert.are.equal(1, bar.frame:GetAlpha(), "it stays Linger seconds after the box last scrolled")
      step(S().FadeOut + 0.2)
      assert.are.equal(0, bar.frame:GetAlpha())
    end)

    it("is seen while the pointer is over it", function()
      make({ AutoHide = true })
      box:FullUpdate(true)
      cursorAt(100)
      step(S().FadeIn + S().Linger + S().FadeOut + 1)
      assert.are.equal(1, bar.frame:GetAlpha())
      cursorAt(-100)
      _G._cursorX = 0
      step(S().Linger + S().FadeOut + 0.1)
      assert.are.equal(0, bar.frame:GetAlpha())
    end)

    it("starts invisible every time it shows again", function()
      make({ AutoHide = true })
      box:FullUpdate(true)
      box:SetScrollPercentage(0.2)
      step(S().FadeIn)
      bar.driver:GetScript("OnShow")(bar.driver)
      assert.are.equal(0, bar.frame:GetAlpha())
    end)
  end)
end)
