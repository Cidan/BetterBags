-- button_spec.lua -- NextButton and NextToggle (next/controls/button.lua, next/controls/toggle.lua):
-- BetterBags Next's buttons (plain, primary, danger, a link) and switches (next-settings.md §2), drawn
-- from the theme's Controls.Button and Controls.Toggle.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextFrameArt", "next/frameart.lua" }, { "NextFill", "next/fill.lua" }, { "NextControls", "next/controls/base.lua" }, { "NextButton", "next/controls/button.lua" },
  { "NextToggle", "next/controls/toggle.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local nextButton = addon:GetModule("NextButton")
local nextToggle = addon:GetModule("NextToggle")
local style = addon:GetModule("NextStyle")
local tween = addon:GetModule("NextTween")

local function alphaOf(texture)
  return texture._colorTexture and texture._colorTexture.a
end

local function colorOf(texture)
  local c = texture._colorTexture
  return { c.r, c.g, c.b }
end

local function rgb(name)
  local r, g, b = style:RGBA(name)
  return { r, g, b }
end

describe("NextButton", function()
  local clicks

  local function B()
    return style.Theme.Controls.Button
  end

  before_each(function()
    clicks = {}
  end)

  after_each(function()
    UseNextTheme(nil)
    nextButton:ApplyStyle()
  end)

  local function make(opts)
    opts = opts or {}
    opts.text = opts.text or "Done"
    opts.onClick = opts.onClick or function(_, mouse) table.insert(clicks, mouse) end
    return nextButton:Create(CreateFrame("Frame"), opts)
  end

  it("is as wide as its label and its padding, at least MinWidth, and Height tall", function()
    local b = make({ text = "Export Category Configuration" })
    assert.are.equal("Export Category Configuration", b.label:GetText())
    assert.are.equal(#"Export Category Configuration" * 6 + 2 * B().Padding, b.frame:GetWidth())
    assert.are.equal(B().Height, b.frame:GetHeight())
    local short = make({ text = "OK" })
    assert.are.equal(B().MinWidth, short.frame:GetWidth())
    local fixed = make({ text = "OK", width = 150 })
    assert.are.equal(150, fixed.frame:GetWidth())
  end)

  it("draws its style's fill, edge and font, and lights up under the pointer and when pressed", function()
    local b = make({ style = "Primary" })
    local P = B().Primary
    assert.are.same(rgb("Gold"), colorOf(b.fill))
    assert.are.equal(P.Fill.Alpha, alphaOf(b.fill))
    assert.are.equal(P.Edge.Alpha, alphaOf(b.edge.Top))
    assert.are.equal(style:Font("ButtonPrimary"), b.label:GetFontObject())
    b.frame:GetScript("OnEnter")(b.frame)
    assert.are.equal(P.HoverFill.Alpha, alphaOf(b.fill))
    assert.are.equal(P.HoverEdge.Alpha, alphaOf(b.edge.Top))
    b.frame:GetScript("OnMouseDown")(b.frame, "LeftButton")
    assert.are.equal(P.PressedFill.Alpha, alphaOf(b.fill))
    b.frame:GetScript("OnMouseUp")(b.frame, "LeftButton")
    assert.are.equal(P.HoverFill.Alpha, alphaOf(b.fill))
    b.frame:GetScript("OnLeave")(b.frame)
    assert.are.equal(P.Fill.Alpha, alphaOf(b.fill))
  end)

  it("draws a plain button by default, and a danger button in the warning color", function()
    assert.are.equal(style:Font("Button"), make().label:GetFontObject())
    local d = make({ style = "Danger" })
    assert.are.same(rgb("Danger"), colorOf(d.fill))
    assert.are.equal(style:Font("ButtonDanger"), d.label:GetFontObject())
  end)

  it("draws a link as its text alone, brighter under the pointer", function()
    local link = make({ style = "Link", text = "What's New" })
    assert.is_false(link.fill:IsShown())
    assert.is_false(link.edge.Top:IsShown())
    assert.are.equal(#"What's New" * 6, link.frame:GetWidth())
    assert.are.equal(style:Font("Link"), link.label:GetFontObject())
    link.frame:GetScript("OnEnter")(link.frame)
    assert.are.equal(style:Font("LinkHover"), link.label:GetFontObject())
    link.frame:GetScript("OnLeave")(link.frame)
    assert.are.equal(style:Font("Link"), link.label:GetFontObject())
  end)

  it("calls back on a click with the mouse button, not while disabled", function()
    local b = make()
    b.frame:GetScript("OnClick")(b.frame, "LeftButton")
    assert.are.same({ "LeftButton" }, clicks)
    b:SetEnabled(false)
    assert.are.equal(B().DisabledAlpha, b.frame:GetAlpha())
    assert.is_false(b.frame:IsEnabled())
    b.frame:GetScript("OnEnter")(b.frame)
    assert.are.equal(B().Plain.Fill.Alpha or 1, alphaOf(b.fill), "no light while disabled")
    b.frame:GetScript("OnClick")(b.frame, "LeftButton")
    assert.are.same({ "LeftButton" }, clicks)
    b:SetEnabled(true)
    assert.are.equal(1, b.frame:GetAlpha())
  end)

  it("takes a new label and sizes itself to it", function()
    local b = make({ text = "Rename" })
    b:SetText("Cannot Rename")
    assert.are.equal(#"Cannot Rename" * 6 + 2 * B().Padding, b.frame:GetWidth())
  end)

  it("takes a fixed width, and its label's width again for none", function()
    local b = make({ text = "Rename" })
    b:SetWidth(200)
    assert.are.equal(200, b.frame:GetWidth())
    b:SetText("New Category")
    assert.are.equal(200, b.frame:GetWidth(), "a fixed width wins")
    b:SetWidth(nil)
    assert.are.equal(#"New Category" * 6 + 2 * B().Padding, b.frame:GetWidth())
  end)

  it("shows its tooltip under the pointer", function()
    local b = make({ tooltip = "Copies the categories" })
    b.frame:GetScript("OnEnter")(b.frame)
    assert.is_true(GameTooltip:IsOwned(b.frame))
    b.frame:GetScript("OnLeave")(b.frame)
    assert.is_false(GameTooltip:IsShown())
  end)

  -- GW2_UI's buttons have disabled art of their own (uistuff\\button_disable.png).
  it("draws its disabled fill while disabled, at full alpha, when its style has one", function()
    UseNextTheme({ Controls = { Button = { Primary = { DisabledFill = { Texture = "Interface\\Spec\\off.png", Color = "White" } } } } })
    local b = make({ style = "Primary" })
    b:SetEnabled(false)
    assert.are.equal("Interface\\Spec\\off.png", b.fill:GetTexture())
    assert.are.equal(1, b.frame:GetAlpha(), "its art shows it disabled")
    b:SetEnabled(true)
    assert.are_not.equal("Interface\\Spec\\off.png", b.fill:GetTexture())
    b:SetEnabled(false)
    b:Style()
    assert.are.equal(1, b.frame:GetAlpha())
    local plain = make()
    plain:SetEnabled(false)
    assert.are.equal(B().DisabledAlpha, plain.frame:GetAlpha(), "a style without one dims")
    -- A theme that gives it one, applied while it is disabled, stops dimming it.
    UseNextTheme({ Controls = { Button = { Plain = { DisabledFill = { Texture = "Interface\\Spec\\off.png", Color = "White" } } } } })
    nextButton:ApplyStyle()
    assert.are.equal(1, plain.frame:GetAlpha())
    UseNextTheme(nil)
    nextButton:ApplyStyle()
    assert.are.equal(B().DisabledAlpha, plain.frame:GetAlpha())
  end)

  -- The Plain theme (docs/next-plain-theme.md): Blizzard's UIPanelButtonNoTooltipTemplate, three pieces of
  -- UI-Panel-Button-Up (its caps 12 wide), UI-Panel-Button-Highlight (ADD) over it under the pointer.
  it("draws a fill in three pieces, and its style's highlight over it under the pointer while enabled", function()
    local up = "Interface\\Buttons\\UI-Panel-Button-Up"
    UseNextTheme({ Controls = { Button = { Plain = {
      Fill = { Pieces = "Horizontal", Texture = up, Color = "White", Alpha = 1,
        Begin = { TexCoords = { 0, 0.09375, 0, 0.6875 }, Size = 12 }, Middle = { TexCoords = { 0.09375, 0.53125, 0, 0.6875 } },
        End = { TexCoords = { 0.53125, 0.625, 0, 0.6875 }, Size = 12 } },
      Highlight = { Texture = "Interface\\Buttons\\UI-Panel-Button-Highlight", TexCoords = { 0, 0.625, 0, 0.6875 },
        BlendMode = "ADD", Color = "White", Alpha = 1 },
    } } } })
    local b = make()
    local fill = addon:GetModule("NextFill"):Of(b.fill)
    assert.are.equal(up, fill.Begin:GetTexture())
    assert.are.equal(12, fill.Begin:GetWidth())
    assert.is_true(fill.End:IsShown())
    assert.is_false(b.highlight:IsShown())
    b.frame:GetScript("OnEnter")(b.frame)
    assert.is_true(b.highlight:IsShown())
    assert.are.equal("ADD", b.highlight:GetBlendMode())
    b:SetEnabled(false)
    assert.is_false(b.highlight:IsShown(), "not while disabled")
    b:SetEnabled(true)
    b.frame:GetScript("OnLeave")(b.frame)
    assert.is_false(b.highlight:IsShown())
    UseNextTheme(nil)
    nextButton:ApplyStyle()
    assert.is_false(fill.Begin:IsShown(), "one piece again")
    b.frame:GetScript("OnEnter")(b.frame)
    assert.is_false(b.highlight:IsShown(), "a style without a highlight")
    b.frame:GetScript("OnLeave")(b.frame)
  end)

  -- Blizzard's buttons write a disabled label in GameFontDisable (UIPanelButtonNoTooltipTemplate's DisabledFont).
  it("writes its label in its style's disabled font while disabled", function()
    UseNextTheme({ Fonts = { Gray = { Size = 12, Color = "Muted" } }, Controls = { Button = { Plain = { DisabledFont = "Gray" } } } })
    local b = make()
    b:SetEnabled(false)
    assert.are.equal(style:Font("Gray"), b.label:GetFontObject())
    b.frame:GetScript("OnEnter")(b.frame)
    assert.are.equal(style:Font("Gray"), b.label:GetFontObject(), "not lit under the pointer")
    b.frame:GetScript("OnLeave")(b.frame)
    b:SetEnabled(true)
    assert.are.equal(style:Font("Button"), b.label:GetFontObject())
  end)

  it("is restyled, every button made, by a theme", function()
    local b = make({ style = "Primary" })
    UseNextTheme({ Controls = { Button = { Height = 30, Primary = { Fill = { Color = "Lavender", Alpha = 0.5 } } } } })
    nextButton:ApplyStyle()
    assert.are.equal(30, b.frame:GetHeight())
    assert.are.same(rgb("Lavender"), colorOf(b.fill))
    assert.are.equal(0.5, alphaOf(b.fill))
  end)
end)

describe("NextToggle", function()
  local changes

  local function T()
    return style.Theme.Controls.Toggle
  end

  local function knobX(t)
    local _, _, _, x = t.knob:GetPoint(1)
    return x
  end

  local function make(checked)
    return nextToggle:Create(CreateFrame("Frame"), {
      checked = checked,
      onChange = function(_, value) table.insert(changes, value) end,
    })
  end

  before_each(function()
    changes = {}
    tween:Init()
  end)

  after_each(function()
    UseNextTheme(nil)
    nextToggle:ApplyStyle()
  end)

  it("is a track Width x Height with a knob KnobInset in from the end it is at", function()
    local t = make(false)
    assert.are.same({ T().Width, T().Height }, { t.frame:GetSize() })
    assert.are.same({ T().KnobSize, T().KnobSize }, { t.knob:GetSize() })
    assert.are.equal(T().KnobInset, knobX(t))
    assert.are.equal(0, alphaOf(t.on), "the on color hidden while off")
    assert.are.same(rgb("Track"), colorOf(t.off))
    local on = make(true)
    assert.are.equal(T().Width - T().KnobInset - T().KnobSize, knobX(on))
    assert.are.equal(T().On.Alpha, alphaOf(on.on))
    assert.are.same(rgb("White"), colorOf(on.knob))
  end)

  it("flips on a click, sliding its knob and calling back with the new state", function()
    local t = make(false)
    t.frame:GetScript("OnClick")(t.frame, "LeftButton")
    assert.is_true(t:GetChecked())
    assert.are.same({ true }, changes)
    assert.is_true(tween:IsPlaying(t))
    tween:Step(T().Width)
    assert.are.equal(T().Width - T().KnobInset - T().KnobSize, knobX(t))
    assert.are.equal(T().On.Alpha, alphaOf(t.on))
    t.frame:GetScript("OnClick")(t.frame, "LeftButton")
    tween:Step(1)
    assert.is_false(t:GetChecked())
    assert.are.same({ true, false }, changes)
    assert.are.equal(T().KnobInset, knobX(t))
  end)

  it("shows a state it is given without calling back, at once unless asked to slide", function()
    local t = make(false)
    t:SetChecked(true)
    assert.are.same({}, changes)
    assert.is_false(tween:IsPlaying(t))
    assert.are.equal(T().Width - T().KnobInset - T().KnobSize, knobX(t))
    t:SetChecked(false, true)
    assert.is_true(tween:IsPlaying(t))
  end)

  -- Asked: "animate our toggle switches in the options screen". A settings row shows its value again
  -- right after a click saves it: that must not stop the slide.
  it("keeps sliding when told the state it is sliding to", function()
    local t = make(false)
    t.frame:GetScript("OnClick")(t.frame, "LeftButton")
    tween:Step(style.Time.Toggle / 4)
    local midway = knobX(t)
    t:SetChecked(true)
    assert.is_true(tween:IsPlaying(t), "still sliding")
    assert.are.equal(midway, knobX(t), "not put at its end")
    tween:Step(1)
    assert.are.equal(T().Width - T().KnobInset - T().KnobSize, knobX(t))
    t.frame:GetScript("OnClick")(t.frame, "LeftButton")
    t:SetChecked(true)
    assert.is_false(tween:IsPlaying(t), "told another state: at once")
    assert.are.equal(T().Width - T().KnobInset - T().KnobSize, knobX(t))
  end)

  it("lights up under the pointer, and does nothing while disabled", function()
    local t = make(false)
    t.frame:GetScript("OnEnter")(t.frame)
    assert.is_true(t.hover:IsShown())
    t.frame:GetScript("OnLeave")(t.frame)
    assert.is_false(t.hover:IsShown())
    t:SetEnabled(false)
    t.frame:GetScript("OnClick")(t.frame, "LeftButton")
    assert.is_false(t:GetChecked())
    assert.are.same({}, changes)
    assert.is_true(t.frame:GetAlpha() < 1)
  end)

  -- Asked: switches themable between two styles, the square one and "the round peg that sits over a smaller
  -- track". Controls.Toggle.Style = "Round": a track TrackHeight tall with round ends, centered on the switch, and
  -- a round knob KnobSize across over it, overhanging it, its middle over the middle of either end at rest.
  describe("in the round style", function()
    local function round(extra)
      local toggle = { Style = "Round", Width = 34, Height = 20, TrackHeight = 12, KnobSize = 20, HoverSpread = 6,
        KnobShadow = { Texture = "Glow", Color = "Black", Alpha = 0.5, Spread = 3 } }
      for k, v in pairs(extra or {}) do toggle[k] = v end
      UseNextTheme({ Controls = { Toggle = toggle } })
    end

    local function at(region)
      local point, rel, relPoint, x, y = region:GetPoint(1)
      return { point, rel, relPoint, x, y }
    end

    it("draws a round knob over a thinner track with round ends, sliding from end to end", function()
      round()
      local t = make(false)
      assert.are.same({ 34, 20 }, { t.frame:GetSize() })
      -- The track: 4 in from each end (half of what the knob is taller), 4 down, its ends half circles 6 wide.
      local circle = style:TexturePath("Circle")
      for _, pair in ipairs({ { t.offLeft, t.offRight }, { t.onLeft, t.onRight } }) do
        local left, right = pair[1], pair[2]
        assert.are.same({ "TOPLEFT", t.frame, "TOPLEFT", 4, -4 }, at(left))
        assert.are.same({ 6, 12 }, { left:GetSize() })
        -- GetTexCoord gives each corner's (upper left, lower left, upper right, lower right).
        assert.are.same({ 0, 0, 0, 1, 0.5, 0, 0.5, 1 }, { left:GetTexCoord() }, "the circle's left half")
        assert.are.same({ "TOPLEFT", t.frame, "TOPLEFT", 24, -4 }, at(right))
        assert.are.same({ 0.5, 0, 0.5, 1, 1, 0, 1, 1 }, { right:GetTexCoord() }, "its right half")
        assert.are.equal(circle, left:GetTexture())
        assert.are.equal(circle, right:GetTexture())
      end
      assert.are.same({ "TOPLEFT", t.frame, "TOPLEFT", 10, -4 }, at(t.off))
      assert.are.same({ 14, 12 }, { t.off:GetSize() }, "between the ends")
      local r, g, b = t.offLeft:GetVertexColor()
      assert.are.same(rgb("Track"), { r, g, b }, "the ends in the track's color")
      -- The knob: round, its middle over the middle of the end it is at.
      assert.are.same({ 20, 20 }, { t.knob:GetSize() })
      assert.are.equal(circle, t.knob:GetTexture())
      assert.are.same({ "TOPLEFT", t.frame, "TOPLEFT", 0, 0 }, at(t.knob))
      assert.is_false(t.edge.Top:IsShown(), "no square edge")
      local on = make(true)
      assert.are.same({ "TOPLEFT", on.frame, "TOPLEFT", 14, 0 }, at(on.knob))
      assert.are.equal(T().On.Alpha, on.onLeft:GetAlpha())
      assert.are.equal(T().On.Alpha, on.onRight:GetAlpha())
      assert.are.equal(0, t.onLeft:GetAlpha(), "the on color hidden while off, its ends too")
    end)

    it("lights a halo round its knob under the pointer, and puts a soft shadow under it, both following it", function()
      round()
      local t = make(false)
      assert.are.same({ "TOPLEFT", t.knob, "TOPLEFT", -6, 6 }, at(t.hover))
      assert.are.same({ 32, 32 }, { t.hover:GetSize() })
      assert.are.equal(style:TexturePath("Circle"), t.hover:GetTexture())
      t.frame:GetScript("OnEnter")(t.frame)
      assert.is_true(t.hover:IsShown())
      assert.are.same({ "TOPLEFT", t.knob, "TOPLEFT", -3, 3 }, at(t.shadow))
      assert.are.same({ 26, 26 }, { t.shadow:GetSize() })
      assert.is_true(t.shadow:IsShown())
      assert.are.equal(0.5, t.shadow:GetAlpha())
      round({ KnobShadow = false })
      nextToggle:ApplyStyle()
      assert.is_false(t.shadow:IsShown(), "a theme without a shadow")
    end)

    it("slides its knob, and the on color with it, as the square switch does", function()
      round()
      local t = make(false)
      t.frame:GetScript("OnClick")(t.frame, "LeftButton")
      tween:Step(style.Time.Toggle / 2)
      local _, _, _, x = t.knob:GetPoint(1)
      assert.is_true(x > 0 and x < 14, "between its ends")
      assert.is_true(t.onLeft:GetAlpha() > 0 and t.onLeft:GetAlpha() < T().On.Alpha)
      tween:Step(1)
      assert.are.same({ "TOPLEFT", t.frame, "TOPLEFT", 14, 0 }, at(t.knob))
    end)

    it("goes back to the square style with a theme that sets none", function()
      round()
      local t = make(true)
      UseNextTheme(nil)
      nextToggle:ApplyStyle()
      for _, cap in ipairs({ t.offLeft, t.offRight, t.onLeft, t.onRight, t.shadow }) do
        assert.is_false(cap:IsShown())
      end
      assert.are.same({ T().Width, T().Height }, { t.frame:GetSize() })
      assert.are.equal(t.frame, t.off._allPoints, "the track fills the switch again")
      assert.are.equal(t.frame, t.hover._allPoints)
      assert.is_nil(t.knob:GetTexture(), "a square knob in its color")
      assert.is_true(t.edge.Top:IsShown())
      assert.are.equal(T().Width - T().KnobInset - T().KnobSize, knobX(t))
    end)
  end)

  -- GW2_UI's check boxes (Core/API/toolkit.lua, GwSkinCheckButton): its box, the check mark over it while checked,
  -- its disabled box, and the mark tinted while disabled (docs/next-gw2-theme.md, round two).
  describe("in the check style", function()
    local BOX, MARK, OFF = "Interface\\Spec\\box.png", "Interface\\Spec\\mark.png", "Interface\\Spec\\box-off.png"
    local function check()
      UseNextTheme({ Palette = { Gray = { 0.6, 0.6, 0.6, 1 } }, Controls = { Toggle = { Style = "Check", Width = 22, Height = 22,
        Off = { Texture = BOX, Color = "White" }, On = { Texture = MARK, Color = "White", Alpha = 1 },
        Disabled = { Texture = OFF, Color = "White" }, DisabledOn = { Texture = MARK, Color = "Gray" },
        Hover = { Color = "White", Alpha = 0.1 } } } })
      nextToggle:ApplyStyle()
    end

    it("draws its box, and the mark over it as it turns on, with no knob or edge", function()
      check()
      local t = make(false)
      assert.are.same({ 22, 22 }, { t.frame:GetSize() })
      assert.are.equal(BOX, t.off:GetTexture())
      assert.are.equal(MARK, t.on:GetTexture())
      assert.are.equal(0, t.on:GetAlpha(), "no mark while off")
      assert.is_false(t.knob:IsShown())
      assert.is_false(t.edge.Top:IsShown())
      for _, texture in ipairs({ t.offLeft, t.offRight, t.onLeft, t.onRight, t.shadow }) do
        assert.is_false(texture:IsShown())
      end
      t.frame:GetScript("OnClick")(t.frame, "LeftButton")
      assert.are.same({ true }, changes)
      tween:Step(1)
      assert.are.equal(1, t.on:GetAlpha())
      assert.is_false(t.knob:IsShown())
    end)

    it("draws its disabled box and tints its mark while disabled, at full alpha", function()
      check()
      local t = make(true)
      t:SetEnabled(false)
      assert.are.equal(OFF, t.off:GetTexture())
      assert.are.same({ 0.6, 0.6, 0.6, 1 }, { t.on:GetVertexColor() })
      assert.are.equal(1, t.frame:GetAlpha())
      t:SetEnabled(true)
      assert.are.equal(BOX, t.off:GetTexture())
      assert.are.same({ 1, 1, 1, 1 }, { t.on:GetVertexColor() })
    end)

    it("lights its hover over the whole box", function()
      check()
      local t = make(false)
      t.frame:GetScript("OnEnter")(t.frame)
      assert.is_true(t.hover:IsShown())
      assert.are.same({ "TOPLEFT", t.frame, "TOPLEFT", 0, 0 }, { t.hover:GetPoint(1) })
      t.frame:GetScript("OnLeave")(t.frame)
    end)

    it("goes back to a switch with a theme that sets none", function()
      check()
      local t = make(true)
      UseNextTheme(nil)
      nextToggle:ApplyStyle()
      assert.is_true(t.knob:IsShown())
      assert.are.same({ T().Width, T().Height }, { t.frame:GetSize() })
      assert.is_nil(t.off:GetTexture())
    end)
  end)

  it("is restyled, every switch made, by a theme", function()
    local t = make(true)
    UseNextTheme({ Controls = { Toggle = { Width = 44, On = { Color = "Lavender", Alpha = 1 } } } })
    nextToggle:ApplyStyle()
    assert.are.equal(44, t.frame:GetWidth())
    assert.are.same(rgb("Lavender"), colorOf(t.on))
    assert.are.equal(44 - T().KnobInset - T().KnobSize, knobX(t))
  end)
end)
