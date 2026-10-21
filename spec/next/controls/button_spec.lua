-- button_spec.lua -- NextButton and NextToggle (next/controls/button.lua, next/controls/toggle.lua):
-- BetterBags Next's buttons (plain, primary, danger, a link) and switches (next-settings.md §2), drawn
-- from the theme's Controls.Button and Controls.Toggle.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextControls", "next/controls/base.lua" }, { "NextButton", "next/controls/button.lua" },
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

  it("is restyled, every switch made, by a theme", function()
    local t = make(true)
    UseNextTheme({ Controls = { Toggle = { Width = 44, On = { Color = "Lavender", Alpha = 1 } } } })
    nextToggle:ApplyStyle()
    assert.are.equal(44, t.frame:GetWidth())
    assert.are.same(rgb("Lavender"), colorOf(t.on))
    assert.are.equal(44 - T().KnobInset - T().KnobSize, knobX(t))
  end)
end)
