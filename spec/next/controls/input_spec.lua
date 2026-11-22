-- A text sits a quarter pixel right of and above its whole pixel (next-pixel-perfect.md §2); one pixel is one unit here.
local TEXT = 0.25
-- input_spec.lua -- NextInput and NextTextArea (next/controls/input.lua): BetterBags Next's text
-- field and text area (next-settings.md §2), drawn from the theme's Controls.Input.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextFrameArt", "next/frameart.lua" }, { "NextFill", "next/fill.lua" }, { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" },
  { "NextInput", "next/controls/input.lua" }, { "NextMenu", "next/controls/menu.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local nextInput = addon:GetModule("NextInput")
local nextMenu = addon:GetModule("NextMenu")
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

  -- A field as wide as a theme says (a settings row's: Controls.Dropdown.Width) follows the theme as it restyles; found
  -- in review: it kept the width it was made with while the dropdowns beside it widened with ElvUI's font size.
  it("takes its width from a function read again every time it restyles, and keeps a width it was given", function()
    local width = 150
    local follows = nextInput:Create(CreateFrame("Frame"), { width = function() return width end })
    local fixed = nextInput:Create(CreateFrame("Frame"), { width = 90 })
    assert.are.same({ 150, 90 }, { follows.frame:GetWidth(), fixed.frame:GetWidth() })
    width = 260
    nextInput:ApplyStyle()
    assert.are.same({ 260, 90 }, { follows.frame:GetWidth(), fixed.frame:GetWidth() })
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

  -- A field that finds a choice (a menu's, NextMenu): Up and Down move through the choices, as Blizzard's group
  -- finder's search box moves through its suggestions (LFGListSearchPanelSearchBox_OnArrowPressed), and Escape leaves.
  it("says which arrow key was pressed, and that Escape was, after putting its text back", function()
    local keys, escaped = {}, {}
    local f
    f = make({ onArrow = function(_, key) table.insert(keys, key) end,
      onEscape = function() table.insert(escaped, f:GetText()) end })
    f.frame:GetScript("OnArrowPressed")(f.frame, "DOWN")
    f.frame:GetScript("OnArrowPressed")(f.frame, "UP")
    assert.are.same({ "DOWN", "UP" }, keys)
    f:SetText("before")
    f.frame:SetFocus()
    f.frame:GetScript("OnEditFocusGained")(f.frame)
    f.frame:SetText("after")
    f.frame:GetScript("OnEscapePressed")(f.frame)
    assert.are.same({ "before" }, escaped)
    local plain = make()
    plain.frame:GetScript("OnArrowPressed")(plain.frame, "UP")
    plain.frame:GetScript("OnEscapePressed")(plain.frame)
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

  it("holds at most the letters it is given", function()
    local area = nextInput:CreateArea(CreateFrame("Frame"), { height = 120, maxLetters = 500 })
    assert.are.equal(500, area.editBox:GetMaxLetters())
  end)

  -- A guild bank tab's info text, for a member who may not edit it (guild-bank.md §5): Blizzard's Info tab shows it in its
  -- edit box and takes no focus (GuildBankInfoScrollFrame's OnMouseDown).
  it("shows its text read only: no typing, no focus from a click, drawn as ever", function()
    local area = make()
    area.editBox:SetText("Ore and herbs")
    area.editBox:SetFocus()
    area:SetReadOnly(true)
    assert.is_false(area.editBox:IsEnabled())
    assert.is_false(area.editBox:HasFocus())
    assert.are.equal(1, area.frame:GetAlpha(), "not faded: it is there to be read")
    area.box:GetScript("OnMouseDown")(area.box)
    assert.is_false(area.editBox:HasFocus())
    area:SetReadOnly(false)
    assert.is_true(area.editBox:IsEnabled())
    area.box:GetScript("OnMouseDown")(area.box)
    assert.is_true(area.editBox:HasFocus())
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

  -- Without suggestions, the game's own keys: Enter starts a new line, Tab and the arrows are the edit box's.
  it("leaves Enter, Tab and the arrows to the game when it has no suggestions", function()
    local area = make()
    assert.is_nil(area.editBox:GetScript("OnEnterPressed"))
    assert.is_nil(area.editBox:GetScript("OnTabPressed"))
    assert.is_nil(area.editBox:GetScript("OnKeyDown"))
    assert.is_nil(area.caret)
  end)
end)

-- A text area with suggestions at its cursor (search-completion.md §4: a search rule's): read once a frame after the
-- player types, shown in a NextMenu at the cursor, given its keys by the area, which keeps focus.
describe("NextTextArea, with suggestions", function()
  local area, changes, asked, timers, saved, offer

  local function flush()
    local run = timers
    timers = {}
    for _, fn in ipairs(run) do fn() end
  end

  -- typeText is the player typing: the text, the cursor at its end (or where given), the change reported.
  local function typeText(text, cursor)
    area.editBox:SetText(text)
    area.editBox:SetCursorPosition(cursor or #text)
    area.editBox:GetScript("OnTextChanged")(area.editBox, true)
  end

  local function press(script, ...)
    area.editBox:GetScript(script)(area.editBox, ...)
  end

  local function shown()
    return nextMenu:IsOpenFor(area.caret)
  end

  local function labels()
    local out = {}
    for i, row in ipairs(nextMenu:Rows()) do out[i] = row.label:GetText() end
    return out
  end

  local function lit()
    local out = {}
    for i, row in ipairs(nextMenu:Rows()) do
      if row.hover:IsShown() then table.insert(out, i) end
    end
    return out
  end

  before_each(function()
    changes, asked, timers = {}, {}, {}
    saved = { _G.UISpecialFrames, C_Timer.After }
    _G.UISpecialFrames = {}
    C_Timer.After = function(_, fn) table.insert(timers, fn) end
    addon:GetModule("NextControls").escape = {}
    -- offer: two suggestions for the last word typed, replacing it; "rarity " chains.
    offer = function(text, cursor)
      local from = (text:sub(1, cursor):find("%S*$"))
      if text:sub(from, cursor) == "" then return nil end
      local head, tail = text:sub(1, from - 1), text:sub(cursor + 1)
      return { from = from, items = {
        { text = "rarity", note = "3 results", value = { text = head .. "rarity " .. tail, cursor = #head + 7, chain = true } },
        { text = "rare", note = "1 result", value = { text = head .. "rare " .. tail, cursor = #head + 5 } },
      } }
    end
    area = nextInput:CreateArea(CreateFrame("Frame"), {
      height = 120,
      onChange = function(_, text, user) table.insert(changes, { text, user }) end,
      complete = function(text, cursor)
        table.insert(asked, { text, cursor })
        return offer(text, cursor)
      end,
    })
    area.frame:SetWidth(300)
    area.editBox:SetFocus()
  end)

  after_each(function()
    nextMenu:Close()
    _G.UISpecialFrames, C_Timer.After = saved[1], saved[2]
  end)

  it("shows the suggestions at the start of the word at the cursor, once a frame after the player types", function()
    typeText("type = ra")
    typeText("type = rar")
    assert.is_false(shown(), "read once the frame ends")
    flush()
    assert.same({ { "type = rar", 10 } }, asked, "once for both keys")
    assert.is_true(shown())
    assert.same({ "rarity", "rare" }, labels())
    assert.are.equal("3 results", nextMenu:Rows()[1].note:GetText())
    assert.same({ 1 }, lit())
    -- The mock edit box measures 6 a letter: the cursor at 60, the word "rar" 18 wide.
    assert.are.same({ "TOPLEFT", area.editBox, "TOPLEFT", 42, 0 }, { area.caret:GetPoint(1) })
    assert.are.equal(area.caret, nextMenu.anchor)
  end)

  it("asks nothing when the cursor moves with no suggestions shown", function()
    area.editBox:SetText("type = ra")
    area.editBox:SetCursorPosition(3)
    flush()
    assert.same({}, asked)
    assert.is_false(shown())
  end)

  it("takes the lit suggestion with Tab: its text and cursor, reported as typed, the next ones at once when it chains", function()
    typeText("ra")
    flush()
    press("OnTabPressed")
    assert.are.equal("rarity ", area:GetText())
    assert.are.equal(7, area.editBox:GetCursorPosition())
    assert.same({ { "ra", true }, { "rarity ", true } }, changes)
    assert.is_false(shown())
    offer = function() return { from = 8, items = { { text = "=", value = { text = "rarity = ", cursor = 9 } },
      { text = ">", value = { text = "rarity > ", cursor = 9 } } } } end
    flush()
    assert.same({ "ra", 2 }, asked[1])
    assert.same({ "rarity ", 7 }, asked[2], "asked again for what follows")
    assert.same({ "=", ">" }, labels())
  end)

  it("takes the lit suggestion with Enter, and with the suggestions closed starts a new line", function()
    typeText("ra")
    flush()
    press("OnKeyDown", "DOWN")
    press("OnEnterPressed")
    assert.are.equal("rare ", area:GetText())
    assert.is_false(shown())
    flush()
    assert.are.equal(1, #asked, "a suggestion that does not chain asks nothing more")
    area.editBox:SetCursorPosition(2)
    press("OnEnterPressed")
    assert.are.equal("ra\nre ", area:GetText())
    assert.are.equal(3, area.editBox:GetCursorPosition())
    assert.same({ "ra\nre ", true }, changes[#changes])
  end)

  it("takes a suggestion clicked", function()
    typeText("ra")
    flush()
    local row = nextMenu:Rows()[2]
    row.frame:GetScript("OnClick")(row.frame, "LeftButton")
    assert.are.equal("rare ", area:GetText())
    assert.is_true(area.editBox:HasFocus())
  end)

  -- Whether the edit box moves its cursor a line before or after its key runs is not known: the cursor is put back
  -- where the suggestions were read once the frame ends, whichever came first.
  it("moves the light with Up and Down, putting the cursor back where it was", function()
    typeText("type = ra")
    flush()
    press("OnKeyDown", "DOWN")
    area.editBox:SetCursorPosition(0)
    flush()
    assert.are.equal(9, area.editBox:GetCursorPosition())
    assert.same({ 2 }, lit())
    flush()
    assert.are.equal(1, #asked, "nothing changed: not asked again")
    assert.is_true(shown())
    press("OnKeyDown", "UP")
    flush()
    assert.same({ 1 }, lit())
    press("OnKeyDown", "LEFT")
    area.editBox:SetCursorPosition(8)
    flush()
    assert.are.equal(8, area.editBox:GetCursorPosition(), "left and right move the cursor: it stays where it went")
    assert.same({ "type = ra", 8 }, asked[#asked], "read again where it went")
  end)

  -- Found in review: suggestions are read once a frame, so a key typed in the same frame as Tab, Enter or an arrow
  -- left the list (and the cursor to put back) of the text before it.
  it("reads the suggestions again before Tab or Enter takes one, for a key typed in the same frame", function()
    typeText("type = ra")
    flush()
    typeText("type = ra ")
    press("OnTabPressed")
    assert.are.equal("type = ra ", area:GetText(), "after a space there is no word: nothing taken")
    assert.is_false(shown())
    press("OnEnterPressed")
    assert.are.equal("type = ra \n", area:GetText(), "a new line")
    typeText("type = ra")
    flush()
    typeText("type = rar")
    press("OnTabPressed")
    assert.same({ "type = rar", 10 }, asked[#asked])
    assert.are.equal("type = rarity ", area:GetText())
  end)

  it("puts the cursor back after Up or Down only when no key changed the text in the same frame", function()
    typeText("type = ra")
    flush()
    press("OnKeyDown", "DOWN")
    typeText("type = rax")
    flush()
    assert.are.equal(10, area.editBox:GetCursorPosition())
    assert.same({ "type = rax", 10 }, asked[#asked])
  end)

  -- Found in review: the box takes the wheel while focused, and with no catcher the list stayed by a line scrolled away.
  it("closes them when the box scrolls with the wheel", function()
    typeText("ra")
    flush()
    area.box:GetScript("OnMouseWheel")(area.box, -1)
    assert.is_false(shown())
  end)

  it("reads them again as the cursor moves while they show, and closes them when there are none", function()
    typeText("type = ra")
    flush()
    area.editBox:SetCursorPosition(8)
    flush()
    assert.same({ "type = ra", 8 }, asked[2])
    assert.is_true(shown())
    area.editBox:SetCursorPosition(7)
    flush()
    assert.is_false(shown(), "after a space, no word: none")
  end)

  it("closes them on Escape, keeping focus, until the next key typed", function()
    typeText("ra")
    flush()
    press("OnEscapePressed")
    assert.is_false(shown())
    assert.is_true(area.editBox:HasFocus())
    area.editBox:SetCursorPosition(1)
    flush()
    assert.is_false(shown())
    typeText("rar")
    flush()
    assert.is_true(shown())
    nextMenu:Close()
    press("OnEscapePressed")
    assert.is_false(area.editBox:HasFocus(), "with none shown, Escape lets go of focus")
  end)

  it("closes them when it loses focus, its text is set from code, or it is disabled", function()
    typeText("ra")
    flush()
    area.editBox:ClearFocus()
    press("OnEditFocusLost")
    assert.is_false(shown())
    area.editBox:SetFocus()
    typeText("ra")
    flush()
    area:SetText("exp = mid")
    assert.is_false(shown())
    typeText("ra")
    flush()
    area:SetEnabled(false)
    assert.is_false(shown())
    area:SetEnabled(true)
    area.editBox:SetFocus()
    typeText("ra")
    flush()
    assert.is_true(shown())
    area:SetReadOnly(true)
    assert.is_false(shown(), "made read only")
  end)

  it("shows nothing while it does not have focus", function()
    area.editBox:ClearFocus()
    typeText("ra")
    flush()
    assert.is_false(shown())
  end)
end)
