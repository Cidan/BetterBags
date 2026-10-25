-- slider_spec.lua -- NextSlider (next/controls/slider.lua): BetterBags Next's slider (next-settings.md
-- §2), drawn from the theme's Controls.Slider: a track filled up to a thumb, dragged or clicked,
-- snapped to its step, and a number box beside it to type a value.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextFrameArt", "next/frameart.lua" }, { "NextFill", "next/fill.lua" }, { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" },
  { "NextInput", "next/controls/input.lua" }, { "NextSlider", "next/controls/slider.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local nextSlider = addon:GetModule("NextSlider")
local style = addon:GetModule("NextStyle")

local function S()
  return style.Theme.Controls.Slider
end

describe("NextSlider", function()
  local changes

  -- A slider from 0 to 100 by 1, its track at the screen's (100, 100).
  local function make(opts)
    opts = opts or {}
    local slider = nextSlider:Create(CreateFrame("Frame"), {
      min = opts.min or 0, max = opts.max or 100, step = opts.step or 1, value = opts.value or 60,
      onChange = function(_, value) table.insert(changes, value) end,
    })
    slider.track:_SetRect(100, 100, S().Width, S().Height)
    return slider
  end

  local function thumbX(slider)
    local _, _, _, x = slider.thumb:GetPoint(1)
    return x
  end

  -- At value v of 0..100: the thumb's left edge, from the track's left.
  local function at(v)
    return (S().Width - S().ThumbSize) * v / 100
  end

  before_each(function()
    changes = {}
    _G._cursorX, _G._cursorY = 0, 0
    _G._mouseButtonsDown = {}
  end)

  after_each(function()
    _G._mouseButtonsDown = {}
    UseNextTheme(nil)
    nextSlider:ApplyStyle()
  end)

  it("is a track Width wide and a number box ValueWidth wide after it, the thumb at its value", function()
    local slider = make()
    assert.are.equal(S().Width + S().ValueGap + S().ValueWidth, slider.frame:GetWidth())
    assert.are.same({ S().Width, S().Height }, { slider.track:GetSize() })
    assert.are.equal(S().TrackSize, slider.bar:GetHeight())
    assert.are.same({ S().ThumbSize, S().ThumbSize }, { slider.thumb:GetSize() })
    -- In whole pixels (docs/next-pixel-perfect.md): the thumb's place rounded.
    assert.are.equal(math.floor(at(60) + 0.5), thumbX(slider))
    assert.are.equal(math.floor(at(60) + 0.5) + math.floor(S().ThumbSize / 2), slider.fill:GetWidth(),
      "filled up to the thumb's middle")
    assert.are.equal("60", slider.value:GetText())
    assert.are.equal(S().ValueWidth, slider.value.frame:GetWidth())
    assert.is_true(slider.value.frame._numeric)
  end)

  it("shows a value it is given snapped to its step and kept in its range, calling nothing back", function()
    local slider = make({ min = 3, max = 20 })
    slider:SetValue(7.4)
    assert.are.equal(7, slider:GetValue())
    slider:SetValue(25)
    assert.are.equal(20, slider:GetValue())
    slider:SetValue(-4)
    assert.are.equal(3, slider:GetValue())
    assert.are.same({}, changes)
  end)

  it("jumps to where its track is pressed and follows the pointer until let go, calling back on each change", function()
    local slider = make()
    local half = S().ThumbSize / 2
    _G._cursorX = 100 + half + at(20)
    _G._mouseButtonsDown = { LeftButton = true }
    slider.track:GetScript("OnMouseDown")(slider.track, "LeftButton")
    assert.are.equal(20, slider:GetValue())
    assert.are.same({ 20 }, changes)
    _G._cursorX = 100 + half + at(45)
    slider.track:GetScript("OnUpdate")(slider.track, 0.016)
    slider.track:GetScript("OnUpdate")(slider.track, 0.016)
    assert.are.equal(45, slider:GetValue())
    assert.are.same({ 20, 45 }, changes, "once per change")
    assert.are.equal("45", slider.value:GetText())
    _G._cursorX = 5000
    slider.track:GetScript("OnUpdate")(slider.track, 0.016)
    assert.are.equal(100, slider:GetValue())
    _G._mouseButtonsDown = {}
    slider.track:GetScript("OnUpdate")(slider.track, 0.016)
    assert.is_nil(slider.track:GetScript("OnUpdate"))
    slider.track:GetScript("OnMouseDown")(slider.track, "RightButton")
    assert.are.equal(100, slider:GetValue(), "not on a right click")
  end)

  it("takes a typed value on Enter, snapped and kept in range, and puts back one it cannot read", function()
    local slider = make()
    slider.value.frame:SetText("75")
    slider.value.frame:GetScript("OnEnterPressed")(slider.value.frame)
    assert.are.equal(75, slider:GetValue())
    assert.are.same({ 75 }, changes)
    slider.value.frame:SetText("900")
    slider.value.frame:GetScript("OnEnterPressed")(slider.value.frame)
    assert.are.equal(100, slider:GetValue())
    assert.are.equal("100", slider.value:GetText())
    slider.value.frame:SetText("")
    slider.value.frame:GetScript("OnEnterPressed")(slider.value.frame)
    assert.are.equal("100", slider.value:GetText())
    assert.are.same({ 75, 100 }, changes)
  end)

  it("lights its thumb under the pointer and while dragged", function()
    local slider = make()
    local r, g, b = style:RGBA("White")
    slider.track:GetScript("OnEnter")(slider.track)
    assert.are.same({ r = r, g = g, b = b, a = 1 }, slider.thumb._colorTexture)
    slider.track:GetScript("OnLeave")(slider.track)
    r, g, b = style:RGBA("Lavender")
    assert.are.same({ r = r, g = g, b = b, a = 1 }, slider.thumb._colorTexture)
  end)

  -- The Plain theme (docs/next-plain-theme.md): MinimalSliderTemplate's bar, Minimal_SliderBar_Left, a middle and
  -- Minimal_SliderBar_Right, along the track where the bar is.
  it("draws its bar in three pieces where the bar goes", function()
    UseNextTheme({ Controls = { Slider = { Track = { Pieces = "Horizontal", Color = "White", Alpha = 1,
      Begin = { Atlas = "Minimal_SliderBar_Left", Size = 6 }, Middle = { Atlas = "_Minimal_SliderBar_Middle" },
      End = { Atlas = "Minimal_SliderBar_Right", Size = 6 } } } } })
    local slider = make()
    local bar = addon:GetModule("NextFill"):Of(slider.bar)
    assert.are.equal("Minimal_SliderBar_Left", bar.Begin:GetAtlas())
    assert.are.same({ "TOPLEFT", slider.barFrame, "TOPLEFT", 0, 0 }, { bar.Begin:GetPoint(1) })
    assert.are.equal("_Minimal_SliderBar_Middle", slider.bar:GetAtlas())
    -- The bar's place: along the track, TrackSize tall, centered on it.
    assert.are.equal(S().TrackSize, slider.barFrame:GetHeight())
    local _, rel, _, _, y = slider.barFrame:GetPoint(1)
    assert.are.same({ slider.track, -math.floor((S().Height - S().TrackSize) / 2) }, { rel, y })
  end)

  -- MinimalSliderTemplate's thumb: Minimal_SliderBar_Button at its atlas size (useAtlasSize).
  it("draws its thumb at its atlas's size", function()
    ResetMockAtlases()
    MockAtlas("Minimal_SliderBar_Button", 20, 19)
    UseNextTheme({ Controls = { Slider = { ThumbSize = "Atlas",
      Thumb = { Atlas = "Minimal_SliderBar_Button", Color = "White", Alpha = 1 },
      ThumbHover = { Atlas = "Minimal_SliderBar_Button", Color = "White", Alpha = 1 } } } })
    local slider = make()
    assert.are.same({ 20, 19 }, { slider.thumb:GetSize() })
    assert.are.equal(math.floor((S().Width - 20) * 0.6 + 0.5), thumbX(slider))
    ResetMockAtlases()
  end)

  it("is restyled, every slider made, by a theme", function()
    local slider = make()
    UseNextTheme({ Controls = { Slider = { Width = 200, Fill = { Color = "Lavender", Alpha = 1 } } } })
    nextSlider:ApplyStyle()
    assert.are.equal(200, slider.track:GetWidth())
    assert.are.equal(math.floor((200 - S().ThumbSize) * 0.6 + 0.5), thumbX(slider))
  end)
end)
