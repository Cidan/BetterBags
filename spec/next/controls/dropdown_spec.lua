-- dropdown_spec.lua -- NextMenu and NextDropdown (next/controls/menu.lua, next/controls/dropdown.lua):
-- BetterBags Next's menu of choices and the dropdown that opens it (next-settings.md §2), drawn from
-- the theme's Controls.Menu and Controls.Dropdown.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" },
  { "NextMenu", "next/controls/menu.lua" }, { "NextDropdown", "next/controls/dropdown.lua" } }) do
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
end)
