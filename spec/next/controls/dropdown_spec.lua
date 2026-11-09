-- dropdown_spec.lua -- NextMenu and NextDropdown (next/controls/menu.lua, next/controls/dropdown.lua):
-- BetterBags Next's menu of choices and the dropdown that opens it (next-settings.md §2), drawn from
-- the theme's Controls.Menu and Controls.Dropdown.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextFrameArt", "next/frameart.lua" }, { "NextFill", "next/fill.lua" }, { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" },
  { "NextInput", "next/controls/input.lua" }, { "NextMenu", "next/controls/menu.lua" }, { "NextDropdown", "next/controls/dropdown.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local nextMenu = addon:GetModule("NextMenu")
local nextDropdown = addon:GetModule("NextDropdown")
local controls = addon:GetModule("NextControls")
local style = addon:GetModule("NextStyle")

local function M()
  return style.Theme.Controls.Menu
end

local function D()
  return style.Theme.Controls.Dropdown
end

local function alphaOf(texture)
  return texture._colorTexture and texture._colorTexture.a
end

describe("NextMenu", function()
  local picked, anchor, timers, saved

  local function items(n)
    local list = {}
    for i = 1, n do
      list[i] = { text = "Choice " .. i, value = i, selected = i == 2 }
    end
    return list
  end

  local function open(list, opts)
    opts = opts or {}
    opts.items = list
    opts.onPick = function(_, item) table.insert(picked, item.value) end
    nextMenu:Open(anchor, opts)
    return nextMenu.frame
  end

  before_each(function()
    picked, timers = {}, {}
    saved = { _G.UISpecialFrames, C_Timer.After }
    _G.UISpecialFrames = {}
    C_Timer.After = function(_, fn) table.insert(timers, fn) end
    controls.escape = {}
    anchor = CreateFrame("Button", nil, CreateFrame("Frame"))
    anchor:SetSize(170, 26)
    anchor:Show()
  end)

  after_each(function()
    nextMenu:Close()
    _G.UISpecialFrames, C_Timer.After = saved[1], saved[2]
    UseNextTheme(nil)
    nextMenu:ApplyStyle()
  end)

  it("opens below what opened it, Gap down, at least as wide, over everything, a row per choice", function()
    local frame = open(items(3))
    assert.is_true(frame:IsShown())
    assert.are.equal("BetterBagsNextMenu", frame:GetName())
    assert.are.equal("FULLSCREEN_DIALOG", frame:GetFrameStrata())
    assert.is_true(frame:IsClampedToScreen())
    assert.are.same({ "TOPLEFT", anchor, "BOTTOMLEFT", 0, -M().Gap }, { frame:GetPoint(1) })
    assert.is_true(frame:GetWidth() >= 170)
    assert.are.equal(3 * M().ItemHeight + 2 * M().Padding, frame:GetHeight())
    assert.are.equal(3, #nextMenu:Rows())
    assert.are.equal("Choice 1", nextMenu:Rows()[1].label:GetText())
    assert.is_true(nextMenu:IsOpenFor(anchor))
  end)

  -- Seen in game: a menu opened from an item cell (36 wide) read "Rem..." for Remove. Its rows sit in a
  -- list inset Padding on both sides, which the width left out.
  it("gives every choice its whole text, however narrow what opened it", function()
    anchor:SetSize(36, 36)
    local frame = open({ { text = "Remove", value = 1 }, { text = "Remove From Category", value = 2 } })
    local check = M().Check
    local textLeft = M().Padding + check.Size + M().Padding
    local room = frame:GetWidth() - 2 * M().Padding - textLeft - M().Padding
    for _, row in ipairs(nextMenu:Rows()) do
      assert.is_true(room >= row.label:GetStringWidth(), row.label:GetText())
    end
  end)

  -- The menu is drawn at UIParent's scale; what opened it may be in a window drawn smaller (the settings
  -- window scales itself to fit a small screen): as wide as it on screen, not in its units.
  it("is at least as wide on screen as what opened it, in a window drawn smaller", function()
    anchor:GetParent():SetScale(0.5)
    anchor:SetSize(300, 26)
    local frame = open(items(2))
    assert.are.equal(150, frame:GetWidth(), "300 of its units are 150 of the menu's")
    anchor:GetParent():SetScale(1)
  end)

  it("marks the chosen choice with its check and its font", function()
    open(items(3))
    local rows = nextMenu:Rows()
    assert.is_true(rows[2].check:IsShown())
    assert.are.equal(style:Font("MenuItemSelected"), rows[2].label:GetFontObject())
    assert.is_false(rows[1].check:IsShown())
    assert.are.equal(style:Font("MenuItem"), rows[1].label:GetFontObject())
  end)

  it("lights a row under the pointer, and picks it on a click, closing", function()
    open(items(3))
    local row = nextMenu:Rows()[3]
    row.frame:GetScript("OnEnter")(row.frame)
    assert.is_true(row.hover:IsShown())
    row.frame:GetScript("OnLeave")(row.frame)
    assert.is_false(row.hover:IsShown())
    row.frame:GetScript("OnClick")(row.frame, "LeftButton")
    assert.are.same({ 3 }, picked)
    assert.is_false(nextMenu.frame:IsShown())
  end)

  it("does not pick a disabled choice", function()
    local list = items(2)
    list[1].disabled = true
    open(list)
    local row = nextMenu:Rows()[1]
    assert.are.equal(style:Font("ControlMuted"), row.label:GetFontObject())
    row.frame:GetScript("OnClick")(row.frame, "LeftButton")
    assert.are.same({}, picked)
    assert.is_true(nextMenu.frame:IsShown())
  end)

  it("scrolls past MaxRows, with BetterBags Next's scroll bar", function()
    local frame = open(items(M().MaxRows + 5))
    assert.are.equal(M().MaxRows * M().ItemHeight + 2 * M().Padding, frame:GetHeight())
    assert.are.equal(M().MaxRows + 5, #nextMenu:Rows())
    assert.is_not_nil(nextMenu.bar.box)
    assert.are.equal((M().MaxRows + 5) * M().ItemHeight, nextMenu.list:GetHeight())
  end)

  it("closes on a click outside it, on a second click of what opened it, and when that hides", function()
    open(items(2))
    nextMenu.catcher:GetScript("OnMouseDown")(nextMenu.catcher, "LeftButton")
    assert.is_false(nextMenu.frame:IsShown())
    open(items(2))
    nextMenu:Toggle(anchor, { items = items(2), onPick = function() end })
    assert.is_false(nextMenu.frame:IsShown(), "opening it again for the same frame closes it")
    open(items(2))
    anchor:Hide()
    anchor:GetScript("OnHide")(anchor)
    assert.is_false(nextMenu.frame:IsShown())
  end)

  it("closes with Escape before the window it is in", function()
    local window = CreateFrame("Frame", "SpecSettings")
    window:Show()
    controls:PushEscape(window)
    open(items(2))
    assert.are.same({ "BetterBagsNextMenu" }, UISpecialFrames)
    nextMenu:Close()
    for _, fn in ipairs(timers) do fn() end
    assert.are.same({ "SpecSettings" }, UISpecialFrames)
  end)

  it("is drawn from the theme, restyled by it", function()
    local frame = open(items(2))
    local r, g, b = style:RGBA("Card")
    assert.are.same({ r = r, g = g, b = b, a = select(4, style:RGBA("Card")) }, nextMenu.fill._colorTexture)
    assert.are.equal(M().Edge.Alpha, alphaOf(nextMenu.edge.Top))
    UseNextTheme({ Controls = { Menu = { ItemHeight = 30 } } })
    nextMenu:ApplyStyle()
    assert.are.equal(2 * 30 + 2 * M().Padding, frame:GetHeight())
  end)
end)

-- A menu to find a choice in by typing (issue #1270: the category picker an item dropped on a bag's title opens): a
-- head saying what it is for, a field over the choices that reads them again as the player types, the choice Enter
-- takes lit, Up and Down moving the light.
describe("NextMenu, with a field to find a choice", function()
  local anchor, saved, picked, seen

  local NAMES = { "Travel", "Toys", "Trade Goods", "Junk" }

  local function P()
    return style.Theme.Controls.Menu.Picker
  end

  -- choices lists the names with the text in them, Junk disabled (a plugin's), each with a red dot; the first lit
  -- once something is typed.
  local function choices(text)
    table.insert(seen, text)
    local list = {}
    for _, name in ipairs(NAMES) do
      if text == "" or name:lower():find(text:lower(), 1, true) then
        table.insert(list, { text = name, value = name, color = { 1, 0, 0 }, disabled = name == "Junk",
          note = name == "Junk" and "Made by a plugin" or nil })
      end
    end
    return list, text ~= "" and 1 or nil
  end

  local function open(head, items)
    nextMenu:Open(anchor, { head = head, filter = { help = "Find a category", items = items or choices },
      onPick = function(_, item) table.insert(picked, item.value) end })
    return nextMenu.frame
  end

  local function typeText(text)
    local field = nextMenu.field.frame
    field:SetText(text)
    field:GetScript("OnTextChanged")(field, true)
  end

  local function press(key)
    nextMenu.field.frame:GetScript("OnArrowPressed")(nextMenu.field.frame, key)
  end

  local function lit()
    local out = {}
    for i, row in ipairs(nextMenu:Rows()) do
      if row.hover:IsShown() then table.insert(out, i) end
    end
    return out
  end

  before_each(function()
    picked, seen = {}, {}
    saved = { _G.UISpecialFrames, C_Timer.After }
    _G.UISpecialFrames = {}
    C_Timer.After = function(_, fn) fn() end
    controls.escape = {}
    anchor = CreateFrame("Button", nil, CreateFrame("Frame"))
    anchor:SetSize(120, 26)
    anchor:Show()
  end)

  after_each(function()
    nextMenu:Close()
    _G.UISpecialFrames, C_Timer.After = saved[1], saved[2]
    UseNextTheme(nil)
    nextMenu:ApplyStyle()
  end)

  it("shows its head and its field above the choices, the field focused, at least Picker.Width wide", function()
    local frame = open({ icon = 134400, text = "Hearthstone", note = "In Travel" })
    local I = style.Theme.Controls.Input
    assert.are.equal(134400, nextMenu.headIcon:GetTexture())
    assert.are.same({ P().IconSize, P().IconSize }, { nextMenu.headFrame:GetSize() })
    assert.are.equal("Hearthstone", nextMenu.headText:GetText())
    assert.are.equal(style:Font(P().HeadFont), nextMenu.headText:GetFontObject())
    assert.are.equal("In Travel", nextMenu.headNote:GetText())
    assert.are.equal(style:Font(P().NoteFont), nextMenu.headNote:GetFontObject())
    assert.is_true(nextMenu.field.frame:IsShown())
    assert.is_true(nextMenu.field.frame:HasFocus())
    assert.are.equal("Find a category", nextMenu.field.help:GetText())
    assert.are.same({ "" }, seen, "its choices read for an empty field")
    assert.is_true(frame:GetWidth() >= P().Width)
    local above = P().IconSize + P().Gap + I.Height + P().Gap
    assert.are.same({ "TOPLEFT", frame, "TOPLEFT", M().Padding, -(M().Padding + above) }, { nextMenu.box:GetPoint(1) })
    assert.are.equal(above + 4 * M().ItemHeight + 2 * M().Padding, frame:GetHeight())
    assert.are.same({}, lit(), "nothing lit until something is typed")
  end)

  it("leaves out a head it was not given, and both from a menu without a field", function()
    local frame = open(nil)
    local I = style.Theme.Controls.Input
    assert.is_false(nextMenu.headFrame:IsShown() or nextMenu.headText:IsShown() or nextMenu.headNote:IsShown())
    assert.are.same({ "TOPLEFT", frame, "TOPLEFT", M().Padding, -(M().Padding + I.Height + P().Gap) },
      { nextMenu.box:GetPoint(1) })
    nextMenu:Close()
    nextMenu:Open(anchor, { items = { { text = "One", value = 1 } }, onPick = function() end })
    assert.is_false(nextMenu.field.frame:IsShown())
    assert.is_false(nextMenu.headFrame:IsShown())
    assert.are.same({ "TOPLEFT", nextMenu.frame, "TOPLEFT", M().Padding, -M().Padding }, { nextMenu.box:GetPoint(1) })
  end)

  it("reads its choices again as the player types, lighting the one Enter takes", function()
    open(nil)
    typeText("t")
    assert.are.same({ "", "t" }, seen)
    assert.are.same({ "Travel", "Toys", "Trade Goods" }, (function()
      local out = {}
      for _, row in ipairs(nextMenu:Rows()) do table.insert(out, row.label:GetText()) end
      return out
    end)())
    assert.are.same({ 1 }, lit())
    typeText("toy")
    assert.are.equal(1, #nextMenu:Rows())
    assert.are.same({ 1 }, lit())
    assert.is_true(nextMenu.field.frame:HasFocus(), "still typing")
  end)

  it("moves the light with Up and Down, past choices it cannot take, and no further than the ends", function()
    open(nil)
    press("DOWN")
    assert.are.same({ 1 }, lit())
    press("DOWN")
    press("DOWN")
    assert.are.same({ 3 }, lit())
    press("DOWN")
    assert.are.same({ 3 }, lit(), "Junk, a plugin's, is never lit")
    press("UP")
    assert.are.same({ 2 }, lit())
    press("UP")
    press("UP")
    assert.are.same({ 1 }, lit())
    press("LEFT")
    assert.are.same({ 1 }, lit(), "Left and Right move the text's cursor, not the light")
  end)

  it("keeps the lit choice in sight as the light moves past the rows shown", function()
    local many = function(text)
      local list = {}
      for i = 1, P().MaxRows + 6 do
        list[i] = { text = "Choice " .. i, value = i }
      end
      return list, text ~= "" and 1 or nil
    end
    open(nil, many)
    local box = nextMenu.box
    for _ = 1, P().MaxRows + 3 do
      press("DOWN")
    end
    local offset = box:GetDerivedScrollOffset()
    local row = (P().MaxRows + 3 - 1) * M().ItemHeight
    assert.is_true(offset > 0, "scrolled")
    assert.is_true(row >= offset and row + M().ItemHeight <= offset + box:GetVisibleExtent() + 0.5, "the lit row is seen")
  end)

  it("takes the lit choice on Enter, closing; with none lit, Enter closes, taking nothing", function()
    open(nil)
    typeText("toy")
    nextMenu.field.frame:GetScript("OnEnterPressed")(nextMenu.field.frame)
    assert.are.same({ "Toys" }, picked)
    assert.is_false(nextMenu.frame:IsShown())
    open(nil)
    nextMenu.field.frame:GetScript("OnEnterPressed")(nextMenu.field.frame)
    assert.are.same({ "Toys" }, picked)
    assert.is_false(nextMenu.frame:IsShown())
  end)

  it("closes on Escape in its field, letting go of focus", function()
    open(nil)
    nextMenu.field.frame:GetScript("OnEscapePressed")(nextMenu.field.frame)
    assert.is_false(nextMenu.frame:IsShown())
    assert.is_false(nextMenu.field.frame:HasFocus())
  end)

  it("keeps the light where the pointer leaves it, so Enter takes what was last pointed at", function()
    open(nil)
    local row = nextMenu:Rows()[2]
    row.frame:GetScript("OnEnter")(row.frame)
    row.frame:GetScript("OnLeave")(row.frame)
    assert.are.same({ 2 }, lit())
    nextMenu.field.frame:GetScript("OnEnterPressed")(nextMenu.field.frame)
    assert.are.same({ "Toys" }, picked)
  end)

  it("draws each choice's dot in its color before its name, and its note at its right", function()
    open(nil)
    local travel, junk = nextMenu:Rows()[1], nextMenu:Rows()[4]
    assert.is_true(travel.dot:IsShown())
    local c = travel.dot._colorTexture
    assert.are.same({ 1, 0, 0, 1 }, { c.r, c.g, c.b, c.a })
    assert.are.same({ P().Dot, P().Dot }, { travel.dot:GetSize() })
    local _, _, _, dotX = travel.dot:GetPoint(1)
    local _, _, _, labelX = travel.label:GetPoint(1)
    -- A text sits a quarter pixel right of its whole pixel (next-pixel-perfect.md §2).
    assert.are.equal(dotX + P().Dot + M().Padding + 0.25, labelX, "the name after its dot")
    assert.is_false(travel.note:IsShown())
    assert.is_true(junk.note:IsShown())
    assert.are.equal("Made by a plugin", junk.note:GetText())
    assert.are.equal(style:Font(P().NoteFont), junk.note:GetFontObject())
    local point, rel = junk.note:GetPoint(1)
    assert.are.same({ "TOPRIGHT", junk.frame }, { point, rel })
    nextMenu:Close()
    nextMenu:Open(anchor, { items = { { text = "One", value = 1 } }, onPick = function() end })
    assert.is_false(nextMenu:Rows()[1].dot:IsShown() or nextMenu:Rows()[1].note:IsShown(), "a menu without them")
  end)

  it("moves the light past a choice it cannot take between two it can", function()
    open(nil, function(text)
      local list = {}
      for _, name in ipairs(NAMES) do
        table.insert(list, { text = name, value = name, disabled = name == "Toys" })
      end
      return list, text ~= "" and 1 or nil
    end)
    press("DOWN")
    press("DOWN")
    assert.are.same({ 3 }, lit(), "Trade Goods, past Toys")
    press("UP")
    assert.are.same({ 1 }, lit(), "Travel, past Toys")
  end)

  -- Found in review: a note at its row's right edge sat under the scroll bar, which sits over the rows' right edge.
  it("keeps each choice's note clear of the scroll bar in a menu that scrolls", function()
    local S = style.Theme.Controls.ScrollBar
    local function noteX()
      local _, _, _, x = nextMenu:Rows()[1].note:GetPoint(1)
      return x
    end
    open(nil, function()
      local list = {}
      for i = 1, P().MaxRows + 6 do
        list[i] = { text = "Choice " .. i, value = i, note = i .. " items" }
      end
      return list, nil
    end)
    assert.are.equal(-(M().Padding + S.Width + S.Inset) + 0.25, noteX())
    nextMenu:Close()
    open(nil)
    local _, _, _, x = nextMenu:Rows()[4].note:GetPoint(1)
    assert.are.equal(-M().Padding + 0.25, x, "no bar, no room for one")
  end)

  -- Found in review: typing lit a row below the rows shown, and a theme applied while it was open scrolled back to the
  -- top, leaving the lit row out of sight: Enter took a choice the player could not see.
  it("keeps the lit choice in sight as the choices are read again, and as a theme restyles it", function()
    local n = P().MaxRows + 8
    local function inSight(i)
      local box, height = nextMenu.box, M().ItemHeight
      local offset = box:GetDerivedScrollOffset()
      return (i - 1) * height >= offset - 0.5 and i * height <= offset + box:GetVisibleExtent() + 0.5
    end
    open(nil, function(text)
      local list = {}
      for i = 1, n do
        list[i] = { text = "Choice " .. i, value = i }
      end
      return list, text ~= "" and (P().MaxRows + 4) or nil
    end)
    typeText("c")
    assert.are.same({ P().MaxRows + 4 }, lit())
    assert.is_true(inSight(P().MaxRows + 4), "after typing")
    press("DOWN")
    press("DOWN")
    nextMenu:ApplyStyle()
    assert.are.same({ P().MaxRows + 6 }, lit())
    assert.is_true(inSight(P().MaxRows + 6), "after a restyle")
  end)

  -- Found in the second review: rows a whole number of pixels are a fraction of a unit tall wherever a row is not a whole
  -- number of units, and the box rounds what it shows (ScrollBox.lua GetVisibleExtent), so a menu whose rows all show had
  -- a range of up to half a unit (on a 4K screen at UI scale 1, 0.42 with 8 rows, more than a pixel's 0.36), and lighting
  -- its last row scrolled it.
  it("never scrolls a menu whose rows all show, however its rows round on the screen", function()
    local screenSize = _G.GetPhysicalScreenSize
    finally(function() _G.GetPhysicalScreenSize = screenSize end)
    _G.GetPhysicalScreenSize = function() return 3840, 2160 end
    for _, n in ipairs({ 2, 8, 14 }) do
      open(nil, function(text)
        local list = {}
        for i = 1, n do
          list[i] = { text = "Choice " .. i, value = i }
        end
        return list, text ~= "" and n or nil
      end)
      typeText("c")
      assert.are.equal(0, nextMenu.box:GetDerivedScrollOffset(), n .. " rows, typed")
      press("UP")
      press("DOWN")
      assert.are.equal(0, nextMenu.box:GetDerivedScrollOffset(), n .. " rows, arrows")
      nextMenu:Close()
    end
  end)

  -- Seen in game: a picker of three categories, all shown, drew its scroll bar over their notes.
  it("shows no scroll bar while its rows all show, however they round on the screen", function()
    local screenSize = _G.GetPhysicalScreenSize
    finally(function() _G.GetPhysicalScreenSize = screenSize end)
    _G.GetPhysicalScreenSize = function() return 3840, 2160 end
    open(nil, function(text)
      return { { text = "Keep", value = 1, note = "7 items" }, { text = "Junk", value = 2, note = "1 item" } },
        text ~= "" and 2 or nil
    end)
    assert.is_false(nextMenu.bar.frame:IsShown())
    typeText("j")
    assert.is_false(nextMenu.bar.frame:IsShown())
  end)

  -- Asked: "make sure the window is reasonably long as well in general (when there are enough categories) -- generally
  -- speaking, micro windows with tiny interactions for lots of elements is bad."
  it("shows up to Picker.MaxRows choices before it scrolls, more than a menu without a field", function()
    local n = P().MaxRows + 5
    local frame = open(nil, function()
      local list = {}
      for i = 1, n do
        list[i] = { text = "Choice " .. i, value = i }
      end
      return list, nil
    end)
    assert.is_true(P().MaxRows > M().MaxRows)
    local I = style.Theme.Controls.Input
    assert.are.equal(I.Height + P().Gap + P().MaxRows * M().ItemHeight + 2 * M().Padding, frame:GetHeight())
    assert.is_true(nextMenu.bar.frame:IsShown())
    nextMenu:Close()
    -- More rows than a dropdown shows, but no more than it does: no bar, and no room left at the right for one.
    open(nil, function()
      local list = {}
      for i = 1, M().MaxRows + 1 do
        list[i] = { text = "Choice " .. i, value = i, note = "1 item" }
      end
      return list, nil
    end)
    assert.is_false(nextMenu.bar.frame:IsShown())
    local _, _, _, noteX = nextMenu:Rows()[1].note:GetPoint(1)
    assert.are.equal(-M().Padding + 0.25, noteX)
    nextMenu:Close()
    local plain = {}
    for i = 1, n do
      plain[i] = { text = "Choice " .. i, value = i }
    end
    nextMenu:Open(anchor, { items = plain, onPick = function() end })
    assert.are.equal(M().MaxRows * M().ItemHeight + 2 * M().Padding, nextMenu.frame:GetHeight(), "a dropdown as before")
  end)

  -- Found in the second review: each keystroke put the list back at the top, then glided it down to the lit choice.
  it("jumps to the lit choice as the choices are read again, and glides as the arrow keys move the light", function()
    open(nil, function(text)
      local list = {}
      for i = 1, P().MaxRows + 8 do
        list[i] = { text = "Choice " .. i, value = i }
      end
      return list, text ~= "" and (P().MaxRows + 4) or nil
    end)
    typeText("c")
    assert.is_true(nextMenu.box:GetDerivedScrollOffset() > 0)
    assert.is_true(nextMenu.box._noInterpolation, "at once")
    for _ = 1, 3 do
      press("DOWN")
    end
    assert.is_falsy(nextMenu.box._noInterpolation, "gliding")
  end)

  -- Found in review: crossing a plugin's row took the light (Enter's choice) away without moving it anywhere.
  it("keeps the light where it was as the pointer crosses a choice it cannot take", function()
    open(nil)
    press("DOWN")
    local junk = nextMenu:Rows()[4]
    junk.frame:GetScript("OnEnter")(junk.frame)
    junk.frame:GetScript("OnLeave")(junk.frame)
    assert.are.same({ 1 }, lit())
    nextMenu.field.frame:GetScript("OnEnterPressed")(nextMenu.field.frame)
    assert.are.same({ "Travel" }, picked)
  end)

  -- A choice that does something other than choose (making a new category) shows a glyph where the check goes.
  it("draws a choice's glyph where its check goes, in its color, with no ring", function()
    UseNextTheme({ Controls = { Menu = { Check = { Texture = "IconCheck", Color = "Gold", Size = 12,
      Off = { Atlas = "common-dropdown-tickradial" } } } } })
    nextMenu:Open(anchor, { items = { { text = "New", value = 1, glyph = { Texture = "IconPlus", Color = "Lavender" } },
      { text = "Two", value = 2 } }, onPick = function() end })
    local new, two = nextMenu:Rows()[1], nextMenu:Rows()[2]
    assert.is_true(new.check:IsShown())
    assert.are.equal(style:TexturePath("IconPlus"), new.check:GetTexture())
    local r, g, b = style:RGBA("Lavender")
    local vr, vg, vb = new.check:GetVertexColor()
    assert.are.same({ r, g, b }, { vr, vg, vb })
    assert.is_false(new.ring:IsShown(), "no ring under a glyph")
    assert.is_false(two.check:IsShown())
    assert.is_true(two.ring:IsShown())
  end)
end)

describe("NextMenu, themed", function()
  local anchor, saved

  before_each(function()
    saved = { _G.UISpecialFrames, C_Timer.After }
    _G.UISpecialFrames = {}
    C_Timer.After = function(_, fn) fn() end
    controls.escape = {}
    anchor = CreateFrame("Button", nil, CreateFrame("Frame"))
    anchor:SetSize(170, 26)
    anchor:Show()
  end)

  after_each(function()
    nextMenu:Close()
    _G.UISpecialFrames, C_Timer.After = saved[1], saved[2]
    UseNextTheme(nil)
    nextMenu:ApplyStyle()
  end)

  -- The Plain theme (docs/next-plain-theme.md): Classic's menu, common-dropdown-classic-bg 3 past it, over black 3 in
  -- (MenuStyle1Mixin, Blizzard_Menu/Classic/MenuTemplates.lua).
  it("draws its border art over its fill, each inset or past it as its theme says", function()
    UseNextTheme({ Controls = { Menu = {
      Fill = { Color = { 0, 0, 0, 0.8 }, Inset = { Left = 3, Right = 3, Top = 3, Bottom = 2 } },
      Border = { Atlas = "common-dropdown-classic-bg", Color = "White", Alpha = 1,
        Inset = { Left = -3, Right = -3, Top = -3, Bottom = -4 } } } } })
    nextMenu:Open(anchor, { items = { { text = "One", value = 1 } }, onPick = function() end })
    assert.are.equal("common-dropdown-classic-bg", nextMenu.border:GetAtlas())
    assert.are.same({ "TOPLEFT", nextMenu.frame, "TOPLEFT", -3, 3 }, { nextMenu.border:GetPoint(1) })
    assert.are.same({ "BOTTOMRIGHT", nextMenu.frame, "BOTTOMRIGHT", 3, -4 }, { nextMenu.border:GetPoint(2) })
    assert.are.same({ "TOPLEFT", nextMenu.frame, "TOPLEFT", 3, -3 }, { nextMenu.fill:GetPoint(1) })
    UseNextTheme(nil)
    nextMenu:ApplyStyle()
    assert.is_false(nextMenu.border:IsShown(), "a theme without one")
  end)

  -- Blizzard's menus inset their list unevenly (MenuStyle1Mixin:GetInset: 8, 8, 8 and 15 on retail).
  it("insets its list by its Inset on each side, sized round it", function()
    UseNextTheme({ Controls = { Menu = { Padding = 4, ItemHeight = 20, Inset = { Left = 8, Top = 8, Right = 9, Bottom = 15 } } } })
    nextMenu:Open(anchor, { items = { { text = "One", value = 1 }, { text = "Two", value = 2 } }, onPick = function() end })
    local frame, box = nextMenu.frame, nextMenu.box
    assert.are.same({ "TOPLEFT", frame, "TOPLEFT", 8, -8 }, { box:GetPoint(1) })
    assert.are.same({ "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -9, 15 }, { box:GetPoint(2) })
    assert.are.equal(2 * 20 + 8 + 15, frame:GetHeight())
    local list = box:GetWidth()
    nextMenu:Close()
    UseNextTheme({ Controls = { Menu = { Padding = 4, ItemHeight = 20 } } })
    nextMenu:ApplyStyle()
    nextMenu:Open(anchor, { items = { { text = "One", value = 1 }, { text = "Two", value = 2 } }, onPick = function() end })
    assert.are.same({ "TOPLEFT", nextMenu.frame, "TOPLEFT", 4, -4 }, { nextMenu.box:GetPoint(1) })
    assert.are.equal(2 * 20 + 2 * 4, nextMenu.frame:GetHeight())
    assert.is_number(list)
  end)

  -- Blizzard's radio menus (MenuVariants.CreateRadio) draw an empty ring on every choice: retail draws the yellow tick
  -- over the ring on the chosen one (two textures, the tick at the ring's top left), Classic draws the tick in its
  -- place (one texture). Each at its atlas size.
  describe("radio rings", function()
    local function open3()
      nextMenu:Open(anchor, { items = { { text = "One", value = 1 }, { text = "Two", value = 2, selected = true } },
        onPick = function() end })
      return nextMenu.rows[1], nextMenu.rows[2]
    end

    before_each(function()
      ResetMockAtlases()
      MockAtlas("ring", 16, 16)
      MockAtlas("tick", 12, 12)
    end)

    after_each(function()
      ResetMockAtlases()
    end)

    it("draws its Off ring on the rows not chosen and its Under ring under the chosen row's tick", function()
      UseNextTheme({ Controls = { Menu = { Check = { Atlas = "tick", Color = "White", Size = "Atlas",
        Off = { Atlas = "ring" }, Under = { Atlas = "ring" } } } } })
      nextMenu:ApplyStyle()
      local other, chosen = open3()
      assert.is_false(other.check:IsShown())
      assert.is_true(other.ring:IsShown())
      assert.are.equal("ring", other.ring:GetAtlas())
      assert.are.same({ 16, 16 }, { other.ring:GetSize() })
      assert.is_true(chosen.check:IsShown())
      assert.are.equal("tick", chosen.check:GetAtlas())
      assert.are.same({ 12, 12 }, { chosen.check:GetSize() })
      assert.is_true(chosen.ring:IsShown())
      assert.are.same({ "TOPLEFT", chosen.ring, "TOPLEFT", 0, 0 }, { chosen.check:GetPoint(1) }, "the tick over the ring")
    end)

    it("draws only the tick on the chosen row without an Under ring", function()
      UseNextTheme({ Controls = { Menu = { Check = { Atlas = "tick", Color = "White", Size = "Atlas", Off = { Atlas = "ring" } } } } })
      nextMenu:ApplyStyle()
      local other, chosen = open3()
      assert.is_true(other.ring:IsShown())
      assert.is_false(chosen.ring:IsShown())
      assert.is_true(chosen.check:IsShown())
    end)

    it("draws no ring for a theme without one", function()
      local other, chosen = open3()
      assert.is_false(other.ring:IsShown())
      assert.is_false(chosen.ring:IsShown())
      assert.is_true(chosen.check:IsShown())
    end)
  end)

  -- Blizzard's menus mark the chosen choice with an atlas (common-dropdown-icon-radialtick-yellow, MenuVariants.lua).
  it("marks the chosen row with an atlas when its theme names one", function()
    UseNextTheme({ Controls = { Menu = { Check = { Atlas = "common-dropdown-icon-radialtick-yellow", Color = "White", Size = 16 } } } })
    nextMenu:Open(anchor, { items = { { text = "One", value = 1, selected = true } }, onPick = function() end })
    local row = nextMenu.rows[1]
    assert.are.equal("common-dropdown-icon-radialtick-yellow", row.check:GetAtlas())
    assert.is_true(row.check:IsShown())
  end)
end)

describe("NextDropdown", function()
  local current, changes, savedSpecial

  local function make(opts)
    opts = opts or {}
    return nextDropdown:Create(CreateFrame("Frame"), {
      width = opts.width,
      items = opts.items or { "Alphabetically", "Size Descending", "Size Ascending" },
      itemsFunction = opts.itemsFunction,
      get = function() return current end,
      onChange = function(_, item) table.insert(changes, item) current = item end,
    })
  end

  before_each(function()
    current, changes = "Size Descending", {}
    savedSpecial = _G.UISpecialFrames
    _G.UISpecialFrames = {}
    controls.escape = {}
  end)

  after_each(function()
    nextMenu:Close()
    _G.UISpecialFrames = savedSpecial
    UseNextTheme(nil)
    nextDropdown:ApplyStyle()
  end)

  -- Blizzard's settings dropdown (WowStyle2DropdownTemplate, WowStyle2DropdownMixin; DropdownWithSteppersTemplate): its
  -- art for each state, the arrow hung 5 below its bottom and shown only under the pointer, the back and next steppers
  -- 5 left and 4 right of it stepping through the choices, and its menu in MenuStyle2.
  describe("as Blizzard's settings dropdown", function()
    local function art(atlas) return { Atlas = atlas, Color = "White", Alpha = 1 } end
    local STYLE2 = { Controls = { Dropdown = {
      Fill = art("common-dropdown-c-button"), HoverFill = art("common-dropdown-c-button-hover-1"),
      PressedFill = art("common-dropdown-c-button-pressedhover-1"), OpenFill = art("common-dropdown-c-button-open"),
      DisabledFill = art("common-dropdown-c-button-disabled"), Edge = false, Justify = "CENTER",
      Chevron = { Atlas = "common-dropdown-c-button-hover-arrow", Color = "White", Size = 12, Anchor = "BOTTOM",
        Point = { X = 0, Y = -5 }, HoverOnly = true },
      Steppers = { Width = 26, Height = 25, BackGap = 5, NextGap = 4,
        Back = { Atlas = "common-dropdown-icon-back", Disabled = { Atlas = "common-dropdown-icon-back-disabled" } },
        Next = { Atlas = "common-dropdown-icon-next", Disabled = { Atlas = "common-dropdown-icon-next-disabled" } },
        Fill = art("common-dropdown-c-button"), HoverFill = art("common-dropdown-c-button-hover-2"),
        PressedFill = art("common-dropdown-c-button-pressedhover-2"), DisabledFill = art("common-dropdown-c-button-disabled") },
      Menu = { Fill = art("common-dropdown-c-bg"), Border = false },
    } } }

    before_each(function()
      UseNextTheme(STYLE2)
      nextDropdown:ApplyStyle()
    end)

    it("draws its art for its state: pressed under the pointer and disabled too", function()
      local d = make()
      assert.are.equal("common-dropdown-c-button", d.fill:GetAtlas())
      d.frame:GetScript("OnEnter")(d.frame)
      assert.are.equal("common-dropdown-c-button-hover-1", d.fill:GetAtlas())
      d.frame:GetScript("OnMouseDown")(d.frame, "LeftButton")
      assert.are.equal("common-dropdown-c-button-pressedhover-1", d.fill:GetAtlas())
      d.frame:GetScript("OnMouseUp")(d.frame, "LeftButton")
      d.frame:GetScript("OnLeave")(d.frame)
      d:SetEnabled(false)
      assert.are.equal("common-dropdown-c-button-disabled", d.fill:GetAtlas())
    end)

    it("hangs its arrow by its bottom, 5 below the dropdown's, and shows it only under the pointer", function()
      local d = make()
      assert.are.same({ "BOTTOM", d.frame, "BOTTOM", 0, -5 }, { d.chevron:GetPoint(1) })
      assert.is_false(d.chevron:IsShown())
      d.frame:GetScript("OnEnter")(d.frame)
      assert.is_true(d.chevron:IsShown())
      d.frame:GetScript("OnLeave")(d.frame)
      assert.is_false(d.chevron:IsShown())
      assert.are.equal("CENTER", d.text:GetJustifyH(), "the choice centered")
    end)

    it("steps to the choice before and after with its steppers, 5 left and 4 right of it, off at the ends", function()
      local d = make()
      assert.are.same({ "RIGHT", d.frame, "LEFT", -5, 0 }, { d.back.frame:GetPoint(1) })
      assert.are.same({ "LEFT", d.frame, "RIGHT", 4, 0 }, { d.next.frame:GetPoint(1) })
      assert.are.same({ 26, 25 }, { d.back.frame:GetSize() })
      assert.are.equal("common-dropdown-icon-back", d.back.icon:GetAtlas())
      d.next.frame:GetScript("OnClick")(d.next.frame, "LeftButton")
      assert.are.same({ "Size Ascending" }, changes)
      assert.is_false(d.next.frame:IsEnabled(), "the last choice")
      assert.are.equal("common-dropdown-icon-next-disabled", d.next.icon:GetAtlas())
      assert.are.equal("common-dropdown-c-button-disabled", d.next.fill:GetAtlas())
      d.back.frame:GetScript("OnClick")(d.back.frame, "LeftButton")
      d.back.frame:GetScript("OnClick")(d.back.frame, "LeftButton")
      assert.are.same({ "Size Ascending", "Size Descending", "Alphabetically" }, changes)
      assert.is_false(d.back.frame:IsEnabled(), "the first choice")
      d:SetEnabled(false)
      assert.is_false(d.next.frame:IsEnabled(), "both off while it is")
      UseNextTheme(nil)
      nextDropdown:ApplyStyle()
      assert.is_false(d.back.frame:IsShown(), "none for a theme without")
    end)

    it("opens its menu in its own style, other menus keeping theirs", function()
      local d = make()
      d:Click(addon:GetModule("Context"):New("spec"))
      assert.are.equal("common-dropdown-c-bg", nextMenu.fill:GetAtlas())
      nextMenu:Close()
      nextMenu:Open(CreateFrame("Button"), { items = { { text = "A", value = 1 } }, onPick = function() end })
      assert.are_not.equal("common-dropdown-c-bg", nextMenu.fill:GetAtlas())
    end)
  end)

  it("shows the choice made, its chevron on the right, over its fill and edge", function()
    local d = make()
    assert.are.same({ D().Width, D().Height }, { d.frame:GetSize() })
    assert.are.equal("Size Descending", d.text:GetText())
    assert.are.equal(style:Font("ControlText"), d.text:GetFontObject())
    assert.are.equal(style.Theme.Textures.IconChevron, d.chevron:GetTexture())
    assert.are.same({ D().Chevron.Size, D().Chevron.Size }, { d.chevron:GetSize() })
    -- By its top right, centered on its height by whole pixels (docs/next-pixel-perfect.md).
    assert.are.same({ "TOPRIGHT", d.frame, "TOPRIGHT", -D().Padding, -math.floor((D().Height - D().Chevron.Size) / 2) },
      { d.chevron:GetPoint(1) })
    assert.are.equal(D().Edge.Idle, alphaOf(d.edge.Top))
  end)

  it("opens its menu of choices on a click, the one made marked, and takes the one picked", function()
    local d = make()
    d.frame:GetScript("OnClick")(d.frame, "LeftButton")
    assert.is_true(nextMenu:IsOpenFor(d.frame))
    assert.are.equal(D().Edge.Open, alphaOf(d.edge.Top))
    local rows = nextMenu:Rows()
    assert.are.equal(3, #rows)
    assert.is_true(rows[2].check:IsShown())
    rows[3].frame:GetScript("OnClick")(rows[3].frame, "LeftButton")
    assert.are.same({ "Size Ascending" }, changes)
    assert.are.equal("Size Ascending", d.text:GetText())
    assert.are.equal(D().Edge.Idle, alphaOf(d.edge.Top))
  end)

  -- The Plain theme (docs/next-plain-theme.md): WowStyle1DropdownTemplate's background, 9 and 8 pixels past it.
  -- WowStyle1DropdownTemplate's arrow is an atlas (common-dropdown-classic-a-buttonDown).
  it("draws its chevron as an atlas when its theme names one", function()
    UseNextTheme({ Controls = { Dropdown = { Chevron = { Atlas = "common-dropdown-classic-a-buttonDown", Color = "White", Size = 20 } } } })
    local d = make()
    assert.are.equal("common-dropdown-classic-a-buttonDown", d.chevron:GetAtlas())
    assert.are.same({ 20, 20 }, { d.chevron:GetSize() })
  end)

  it("draws its fill past it where its theme says", function()
    UseNextTheme({ Controls = { Dropdown = { Fill = { Atlas = "common-dropdown-classic-textholder", Color = "White", Alpha = 1,
      Inset = { Left = -9, Top = -8, Right = -8, Bottom = -9 } } } } })
    local d = make()
    assert.are.equal("common-dropdown-classic-textholder", d.fill:GetAtlas())
    assert.are.same({ "TOPLEFT", d.frame, "TOPLEFT", -9, 8 }, { d.fill:GetPoint(1) })
    assert.are.same({ "BOTTOMRIGHT", d.frame, "BOTTOMRIGHT", 8, -9 }, { d.fill:GetPoint(2) })
  end)

  it("calls nothing back for the choice already made", function()
    local d = make()
    d.frame:GetScript("OnClick")(d.frame, "LeftButton")
    nextMenu:Rows()[2].frame:GetScript("OnClick")(nextMenu:Rows()[2].frame, "LeftButton")
    assert.are.same({}, changes)
  end)

  it("reads its choices each time it opens (late providers, form-dropdowns.md)", function()
    local list = { "None", "BetterBags" }
    local d = make({ itemsFunction = function() return list end })
    d.frame:GetScript("OnClick")(d.frame, "LeftButton")
    assert.are.equal(2, #nextMenu:Rows())
    nextMenu:Close()
    table.insert(list, "Pawn")
    d.frame:GetScript("OnClick")(d.frame, "LeftButton")
    assert.are.equal(3, #nextMenu:Rows())
  end)

  it("shows the choice again when told, and nothing for none", function()
    local d = make()
    current = "Alphabetically"
    d:Refresh()
    assert.are.equal("Alphabetically", d.text:GetText())
    current = nil
    d:Refresh()
    assert.are.equal("", d.text:GetText())
  end)

  it("lights under the pointer, and opens nothing while disabled", function()
    local d = make()
    d.frame:GetScript("OnEnter")(d.frame)
    assert.are.equal(D().Edge.Hover, alphaOf(d.edge.Top))
    d.frame:GetScript("OnLeave")(d.frame)
    d:SetEnabled(false)
    d.frame:GetScript("OnClick")(d.frame, "LeftButton")
    assert.is_false(nextMenu:IsOpenFor(d.frame))
  end)

  -- Blizzard's dropdown arrow (WowStyle1DropdownTemplate, GetWowStyle1ArrowButtonState): its own art idle, under the
  -- pointer, pressed, while its menu is open and disabled, each at its atlas size (useAtlasSize), anchored by its
  -- right at RIGHT 1, -3; disabled, its text gray (DISABLED_FONT_COLOR) and nothing dimmed.
  describe("Blizzard's arrow", function()
    before_each(function()
      ResetMockAtlases()
      MockAtlas("arrow", 18, 17)
      MockAtlas("arrow-hover", 18, 17)
      MockAtlas("arrow-pressedhover", 18, 17)
      MockAtlas("arrow-open", 18, 17)
      MockAtlas("arrow-disabled", 18, 17)
      MockAtlas("holder-small", 60, 30)
      UseNextTheme({ Fonts = { Gray = { Size = 12, Color = "Muted" } }, Controls = { Dropdown = {
        DisabledFont = "Gray", DisabledAlpha = 1,
        Chevron = { Atlas = "arrow", Color = "White", Size = "Atlas", Point = { X = 1, Y = -3 },
          Hover = { Atlas = "arrow-hover" }, Pressed = { Atlas = "arrow-pressedhover" }, Open = { Atlas = "arrow-open" },
          Disabled = { Atlas = "arrow-disabled" } },
      } } })
      nextDropdown:ApplyStyle()
    end)

    after_each(function()
      ResetMockAtlases()
    end)

    it("draws its arrow at its atlas size, by its right at its Point", function()
      local d = make()
      assert.are.equal("arrow", d.chevron:GetAtlas())
      assert.are.same({ 18, 17 }, { d.chevron:GetSize() })
      assert.are.same({ "RIGHT", d.frame, "RIGHT", 1, -3 }, { d.chevron:GetPoint(1) })
    end)

    it("draws its arrow's art under the pointer, pressed and while its menu is open", function()
      local d = make()
      d.frame:GetScript("OnEnter")(d.frame)
      assert.are.equal("arrow-hover", d.chevron:GetAtlas())
      d.frame:GetScript("OnMouseDown")(d.frame, "LeftButton")
      assert.are.equal("arrow-pressedhover", d.chevron:GetAtlas())
      d.frame:GetScript("OnMouseUp")(d.frame, "LeftButton")
      assert.are.equal("arrow-hover", d.chevron:GetAtlas())
      d.frame:GetScript("OnClick")(d.frame, "LeftButton")
      assert.is_true(nextMenu:IsOpenFor(d.frame))
      assert.are.equal("arrow-open", d.chevron:GetAtlas())
      nextMenu:Close()
      d.frame:GetScript("OnLeave")(d.frame)
      assert.are.equal("arrow", d.chevron:GetAtlas())
    end)

    it("draws its disabled arrow and text while disabled, dimming nothing", function()
      local d = make()
      d:SetEnabled(false)
      assert.are.equal("arrow-disabled", d.chevron:GetAtlas())
      assert.are.equal(style:Font("Gray"), d.text:GetFontObject())
      assert.are.equal(1, d.frame:GetAlpha())
      d.frame:GetScript("OnEnter")(d.frame)
      assert.are.equal("arrow-disabled", d.chevron:GetAtlas(), "not lit")
      d.frame:GetScript("OnLeave")(d.frame)
      d:SetEnabled(true)
      assert.are.equal("arrow", d.chevron:GetAtlas())
      assert.are.equal(style:Font(D().Font), d.text:GetFontObject())
    end)

    -- Classic's dropdown: its choice written right, against the arrow (justifyH RIGHT), and its narrow background at
    -- 100 wide or less (common-dropdown-classic-textholder-small, OnSizeChanged).
    it("writes its choice where its theme justifies it, and draws its narrow fill when narrow", function()
      UseNextTheme({ Controls = { Dropdown = { Justify = "RIGHT", NarrowWidth = 100,
        NarrowFill = { Atlas = "holder-small", Color = "White", Alpha = 1 } } } })
      nextDropdown:ApplyStyle()
      local narrow = make({ width = 90 })
      assert.are.equal("RIGHT", narrow.text:GetJustifyH())
      assert.are.equal("holder-small", narrow.fill:GetAtlas())
      narrow.frame:GetScript("OnEnter")(narrow.frame)
      assert.are.equal("holder-small", narrow.fill:GetAtlas(), "in every state")
      narrow.frame:GetScript("OnLeave")(narrow.frame)
      local wide = make({ width = 170 })
      assert.are_not.equal("holder-small", wide.fill:GetAtlas())
      UseNextTheme(nil)
      nextDropdown:ApplyStyle()
      assert.are.equal("LEFT", narrow.text:GetJustifyH())
    end)
  end)
end)
