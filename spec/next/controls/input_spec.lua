-- input_spec.lua -- NextInput and NextTextArea (next/controls/input.lua): BetterBags Next's text
-- field and text area (next-settings.md §2), drawn from the theme's Controls.Input.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" },
  { "NextInput", "next/controls/input.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local nextInput = addon:GetModule("NextInput")
local style = addon:GetModule("NextStyle")

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

local function I()
  return style.Theme.Controls.Input
end

describe("NextInput", function()
  local log

  local function make(opts)
    opts = opts or {}
    opts.onEnter = opts.onEnter or function(_, text) table.insert(log, { "enter", text }) end
    opts.onChange = opts.onChange or function(_, text, user) table.insert(log, { "change", text, user }) end
    return nextInput:Create(CreateFrame("Frame"), opts)
  end

  before_each(function()
    log = {}
  end)

  after_each(function()
    UseNextTheme(nil)
    nextInput:ApplyStyle()
  end)

  it("is a field Height tall, its text Padding in, in its font, over its fill and edge", function()
    local f = make({ width = 200 })
    assert.are.equal("EditBox", f.frame:GetObjectType())
    assert.are.same({ 200, I().Height }, { f.frame:GetSize() })
    assert.are.same({ I().Padding, I().Padding, 0, 0 }, { f.frame:GetTextInsets() })
    assert.are.equal(style:Font("ControlText"), f.frame:GetFontObject())
    assert.are.same(rgb("ControlFill"), colorOf(f.fill))
    assert.are.equal(I().Edge.Idle, alphaOf(f.edge.Top))
    assert.is_false(f.frame:IsAutoFocus())
  end)

  it("shows its help while empty and not focused", function()
    local f = make({ help = "Search settings" })
    assert.are.equal("Search settings", f.help:GetText())
    assert.are.equal(style:Font("ControlHelp"), f.help:GetFontObject())
    assert.is_true(f.help:IsShown())
    f:SetText("glow")
    assert.is_false(f.help:IsShown())
    f:SetText("")
    assert.is_true(f.help:IsShown())
    f:SetFocus()
    assert.is_false(f.help:IsShown())
  end)

  it("lights its edge under the pointer and its fill and edge while focused", function()
    local f = make()
    f.frame:GetScript("OnEnter")(f.frame)
    assert.are.equal(I().Edge.Hover, alphaOf(f.edge.Top))
    f.frame:GetScript("OnLeave")(f.frame)
    assert.are.equal(I().Edge.Idle, alphaOf(f.edge.Top))
    f.frame:SetFocus()
    f.frame:GetScript("OnEditFocusGained")(f.frame)
    assert.are.equal(I().Edge.Focus, alphaOf(f.edge.Top))
    assert.are.same(rgb("ControlHover"), colorOf(f.fill))
    f.frame:ClearFocus()
    f.frame:GetScript("OnEditFocusLost")(f.frame)
    assert.are.equal(I().Edge.Idle, alphaOf(f.edge.Top))
  end)

  it("calls back as its text changes, saying whether the player typed it, and on Enter, and lets go of focus", function()
    local f = make()
    f.frame:SetText("12")
    f.frame:GetScript("OnTextChanged")(f.frame, true)
    f:SetText("7")
    -- The client reports a text set from code as not typed (OnTextChanged with userInput false).
    f.frame:GetScript("OnTextChanged")(f.frame, false)
    assert.are.same({ { "change", "12", true } }, log, "a text set from code is not reported")
    f.frame:SetFocus()
    f.frame:GetScript("OnEnterPressed")(f.frame)
    assert.are.same({ "enter", "7" }, log[2])
    assert.is_false(f.frame:HasFocus())
  end)

  it("lets go of focus on Escape, putting back the text it had when focused", function()
    local f = make()
    f:SetText("before")
    f.frame:SetFocus()
    f.frame:GetScript("OnEditFocusGained")(f.frame)
    f.frame:SetText("after")
    f.frame:GetScript("OnEscapePressed")(f.frame)
    assert.are.equal("before", f:GetText())
    assert.is_false(f.frame:HasFocus())
  end)

  it("takes only digits when numeric, and at most its letters", function()
    local f = make({ numeric = true, maxLetters = 2 })
    assert.is_true(f.frame._numeric)
    assert.are.equal(2, f.frame:GetMaxLetters())
  end)

  it("takes no input while disabled, drawn faded", function()
    local f = make()
    f:SetEnabled(false)
    assert.is_false(f.frame:IsEnabled())
    assert.are.equal(style.Theme.Controls.Button.DisabledAlpha, f.frame:GetAlpha())
    f:SetEnabled(true)
    assert.are.equal(1, f.frame:GetAlpha())
  end)

  it("is restyled, every field made, by a theme", function()
    local f = make()
    UseNextTheme({ Controls = { Input = { Height = 30, Fill = { Color = "Lavender", Alpha = 0.2 } } } })
    nextInput:ApplyStyle()
    assert.are.equal(30, f.frame:GetHeight())
    assert.are.same(rgb("Lavender"), colorOf(f.fill))
  end)
end)

describe("NextTextArea", function()
  local changes

  local function make()
    changes = {}
    local area = nextInput:CreateArea(CreateFrame("Frame"), {
      height = 120,
      onChange = function(_, text, user) table.insert(changes, { text, user }) end,
    })
    area.frame:SetWidth(300)
    return area
  end

  it("is a field Padding round a scrolling, multi-line edit box with BetterBags Next's scroll bar", function()
    local area = make()
    assert.are.equal(120, area.frame:GetHeight())
    assert.is_true(area.editBox:IsMultiLine())
    assert.is_false(area.editBox:IsAutoFocus())
    assert.are.equal(area.box:GetScrollTarget(), area.editBox:GetParent(), "the box scrolls it")
    assert.are.equal(area.box, area.bar.box)
    assert.are.same({ "TOPLEFT", area.frame, "TOPLEFT", I().Padding, -I().Padding }, { area.box:GetPoint(1) })
    assert.are.equal(style:Font("ControlText"), area.editBox:GetFontObject())
  end)

  it("focuses its edit box on a click anywhere in it, and takes the wheel only while focused", function()
    local area = make()
    assert.is_false(area.box:IsMouseWheelEnabled())
    area.box:GetScript("OnMouseDown")(area.box)
    assert.is_true(area.editBox:HasFocus())
    area.editBox:GetScript("OnEditFocusGained")(area.editBox)
    assert.is_true(area.box:IsMouseWheelEnabled())
    assert.are.equal(I().Edge.Focus, alphaOf(area.edge.Top))
    area.editBox:GetScript("OnEditFocusLost")(area.editBox)
    assert.is_false(area.box:IsMouseWheelEnabled())
  end)

  it("lays its text out again as it changes, and reports what the player typed", function()
    local area = make()
    local updates = area.box._fullUpdates or 0
    area.editBox:SetText("one\ntwo")
    area.editBox:GetScript("OnTextChanged")(area.editBox, true)
    assert.are.equal(updates + 1, area.box._fullUpdates)
    assert.are.same({ { "one\ntwo", true } }, changes)
    area:SetText("from code")
    assert.are.equal("from code", area:GetText())
    assert.are.equal(1, #changes)
  end)

  it("selects all of its text when asked, focused", function()
    local area = make()
    area:SetText("export string")
    area:SelectAll()
    assert.is_true(area.editBox:HasFocus())
    assert.are.same({ 0, -1 }, area.editBox._highlight)
  end)

  it("lets go of focus on Escape", function()
    local area = make()
    area.editBox:SetFocus()
    area.editBox:GetScript("OnEscapePressed")(area.editBox)
    assert.is_false(area.editBox:HasFocus())
  end)
end)
