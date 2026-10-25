-- A text sits a quarter pixel right of and above its whole pixel (next-pixel-perfect.md §2); one pixel is one unit here.
local TEXT = 0.25
-- input_spec.lua -- NextInput and NextTextArea (next/controls/input.lua): BetterBags Next's text
-- field and text area (next-settings.md §2), drawn from the theme's Controls.Input.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextFrameArt", "next/frameart.lua" }, { "NextFill", "next/fill.lua" }, { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" },
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
    -- Above and below, the room left over by its font's height, split (docs/next-pixel-perfect.md): the
    -- line the client centers in what is left lands on a whole pixel.
    local _, fontHeight = f.frame:GetFont()
    local above = math.floor((I().Height - fontHeight) / 2)
    assert.are.same({ I().Padding + TEXT, I().Padding - TEXT, above - TEXT, I().Height - fontHeight - above + TEXT },
      { f.frame:GetTextInsets() })
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

  it("draws an icon inside its left edge, its text and help after it, read from the theme each time", function()
    local spec = { Texture = "IconSearch", Size = 14, Color = "Lavender" }
    local f = make({ icon = function() return spec end, help = "Search" })
    local left = I().Padding + 14 + I().Padding / 2
    assert.are.equal(style.Theme.Textures.IconSearch, f.icon:GetTexture())
    assert.are.same({ 14, 14 }, { f.icon:GetSize() })
    -- By their top left, centered on its height by whole pixels (docs/next-pixel-perfect.md).
    assert.are.same({ "TOPLEFT", f.frame, "TOPLEFT", I().Padding, -math.floor((I().Height - 14) / 2) },
      { f.icon:GetPoint(1) })
    local insetLeft, insetRight = f.frame:GetTextInsets()
    assert.are.same({ left + TEXT, I().Padding - TEXT }, { insetLeft, insetRight })
    local _, helpHeight = f.help:GetFont()
    assert.are.same({ "TOPLEFT", f.frame, "TOPLEFT", left + TEXT, -math.floor((I().Height - helpHeight) / 2) + TEXT },
      { f.help:GetPoint(1) })
    spec = { Texture = "IconSearch", Size = 20, Color = "Gold" }
    nextInput:ApplyStyle()
    assert.are.same({ 20, 20 }, { f.icon:GetSize() })
    assert.are.equal(I().Padding + 20 + I().Padding / 2 + TEXT, (f.frame:GetTextInsets()))
    local plain = make()
    assert.is_nil(plain.icon)
  end)

  -- A field saved when it is left (the Categories page's priority), as when Enter is pressed: once, and
  -- not for a field left unchanged or by Escape.
  it("commits what changed when it loses focus, with commitOnBlur", function()
    local committed = {}
    local f = make({ commitOnBlur = true, onEnter = function(_, text) table.insert(committed, text) end })
    f.frame:GetScript("OnEditFocusGained")(f.frame)
    f.frame:SetText("12")
    f.frame:GetScript("OnEditFocusLost")(f.frame)
    assert.are.same({ "12" }, committed)
    f.frame:GetScript("OnEditFocusGained")(f.frame)
    f.frame:GetScript("OnEditFocusLost")(f.frame)
    assert.are.same({ "12" }, committed, "unchanged")
    f.frame:GetScript("OnEditFocusGained")(f.frame)
    f.frame:SetText("13")
    f:Commit(addon:GetModule("Context"):New("spec"))
    f.frame:GetScript("OnEditFocusLost")(f.frame)
    assert.are.same({ "12", "13" }, committed, "Enter, then the focus it lets go of")
    f.frame:GetScript("OnEditFocusGained")(f.frame)
    f.frame:SetText("99")
    f:Cancel()
    f.frame:GetScript("OnEditFocusLost")(f.frame)
    assert.are.same({ "12", "13" }, committed, "Escape")
    local got = false
    local plain = make({ onEnter = function() got = true end })
    plain.frame:GetScript("OnEditFocusGained")(plain.frame)
    plain.frame:SetText("5")
    plain.frame:GetScript("OnEditFocusLost")(plain.frame)
    assert.is_false(got, "only with commitOnBlur")
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

  -- The Plain theme (docs/next-plain-theme.md): InputBoxVisualTemplate's border, 20 tall, its left cap 5 past the box.
  it("draws its fill in pieces, reaching past it where its theme says", function()
    UseNextTheme({ Controls = { Input = { Fill = { Pieces = "Horizontal", Thickness = 20, Inset = { Left = -5 },
      Color = "White", Alpha = 1, Begin = { Atlas = "common-search-border-left", Size = 8 },
      Middle = { Atlas = "common-search-border-middle" }, End = { Atlas = "common-search-border-right", Size = 8 } } } } })
    local f = make()
    local fill = addon:GetModule("NextFill"):Of(f.fill)
    assert.are.same({ "LEFT", f.frame, "LEFT", -5, 0 }, { fill.Begin:GetPoint(1) })
    assert.are.same({ 8, 20 }, { fill.Begin:GetSize() })
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

  -- Its box (docs/next-plain-theme.md, round three): the area drew the input's fill, which for a fill in pieces at its
  -- own thickness (Plain's 20-pixel search border) covered a strip of what takes its clicks. It draws its own fill, edge
  -- and frame (Controls.TextArea), the input's when the theme gives it none.
  describe("its box", function()
    after_each(function()
      UseNextTheme(nil)
      nextInput:ApplyStyle()
    end)

    it("is drawn in the input's fill and edge when the theme gives it none of its own", function()
      UseNextTheme({ Controls = { Input = { Fill = { Color = { 0.1, 0.2, 0.3, 1 } } } } })
      local area = make()
      local c = area.fill._colorTexture
      assert.are.same({ 0.1, 0.2, 0.3, 1 }, { c.r, c.g, c.b, c.a })
      assert.is_true(area.edge.Top:IsShown())
      assert.is_false(area.frameArt.pieces.TopLeftCorner:IsShown())
    end)

    it("is drawn in its own fill, edge and frame round the whole box when the theme gives them", function()
      UseNextTheme({ Controls = { TextArea = { Fill = false, FocusFill = false, Edge = false, Frame = { Pieces = {
        TopLeftCorner = { Texture = "Interface\\Common\\Common-Input-Border-TL", Width = 8, Height = 8, X = -5, Y = 5 },
        BottomRightCorner = { Texture = "Interface\\Common\\Common-Input-Border-BR", Width = 8, Height = 8, X = 5, Y = -5 },
      } } } } })
      local area = make()
      assert.is_false(area.fill:IsShown())
      assert.is_false(area.edge.Top:IsShown())
      local tl, br = area.frameArt.pieces.TopLeftCorner, area.frameArt.pieces.BottomRightCorner
      assert.is_true(tl:IsShown() and br:IsShown())
      assert.are.same({ "TOPLEFT", area.frame, "TOPLEFT", -5, 5 }, { tl:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", area.frame, "BOTTOMRIGHT", 5, -5 }, { br:GetPoint(1) })
      -- Focused, still its own: no fill.
      area.editBox:SetFocus()
      area:OnFocus(true)
      assert.is_false(area.fill:IsShown())
    end)
  end)

  it("takes no typing while disabled, faded, and lets go of focus", function()
    local area = make()
    area.editBox:SetFocus()
    area:SetEnabled(false)
    assert.is_false(area.editBox:IsEnabled())
    assert.is_false(area.editBox:HasFocus())
    assert.are.equal(addon:GetModule("NextControls"):Theme("Button").DisabledAlpha, area.frame:GetAlpha())
    area:SetEnabled(true)
    assert.is_true(area.editBox:IsEnabled())
    assert.are.equal(1, area.frame:GetAlpha())
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
