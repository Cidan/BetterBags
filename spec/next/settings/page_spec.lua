-- page_spec.lua -- NextSettingsRows and NextSettingsPage (next/settings/rows.lua, page.lua): the rows
-- of BetterBags Next's settings window and the page that lays them out (next-settings.md §3): a
-- setting's name and its control, read and written through the settings catalog's options; text,
-- buttons and links across the page; sections in a card, two columns when there is room.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
local L = StubBetterBagsModule("Localization")
L.G = L.G or function(_, key) return key end
LoadBetterBagsModule("render/render.lua")
LoadBetterBagsModule("render/drawable.lua")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" },
  { "NextButton", "next/controls/button.lua" }, { "NextToggle", "next/controls/toggle.lua" },
  { "NextInput", "next/controls/input.lua" }, { "NextSlider", "next/controls/slider.lua" },
  { "NextMenu", "next/controls/menu.lua" }, { "NextDropdown", "next/controls/dropdown.lua" },
  { "NextSwatch", "next/controls/swatch.lua" }, { "NextDialog", "next/controls/dialog.lua" },
  { "NextSettingsRows", "next/settings/rows.lua" }, { "NextSettingsPage", "next/settings/page.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local rows = addon:GetModule("NextSettingsRows")
local nextPage = addon:GetModule("NextSettingsPage")
local nextDialog = addon:GetModule("NextDialog")
local controls = addon:GetModule("NextControls")
local render = addon:GetModule("Render")
local context = addon:GetModule("Context")
local style = addon:GetModule("NextStyle")

local function C()
  return style.Theme.Settings.Content
end

local function ctx()
  return context:New("spec")
end

describe("NextSettingsRows", function()
  local owner, value, writes, savedReload, reloads

  local function option(kind, extra)
    local o = {
      kind = kind, title = "Merge Stacks", description = "Stackable items will merge.",
      get = function() return value end,
      set = function(_, v) table.insert(writes, v) value = v end,
    }
    for k, v in pairs(extra or {}) do o[k] = v end
    return o
  end

  before_each(function()
    owner = CreateFrame("Frame", "SpecWindow", UIParent)
    owner:Show()
    writes = {}
    reloads = 0
    savedReload = _G.ReloadUI
    _G.ReloadUI = function() reloads = reloads + 1 end
    _G.UISpecialFrames = {}
    controls.escape = {}
  end)

  after_each(function()
    nextDialog:Hide()
    _G.ReloadUI = savedReload
  end)

  it("draws a toggle's name on the left and its switch on the right, showing and writing its value", function()
    value = true
    local row = rows:Create(owner, option("toggle"), owner)
    assert.are.equal("Merge Stacks", row.label:GetText())
    assert.are.equal(style:Font(C().LabelFont), row.label:GetFontObject())
    assert.is_true(row.control:GetChecked())
    assert.is_false(row.wide)
    row.control.frame:GetScript("OnClick")(row.control.frame, "LeftButton")
    assert.are.same({ false }, writes)
    value = true
    row:Refresh(ctx())
    assert.is_true(row.control:GetChecked(), "shows the value again when told")
  end)

  it("makes the control of each kind", function()
    value = "Quality"
    local d = rows:Create(owner, option("dropdown", { items = { "Alphabetically", "Quality" } }), owner)
    assert.are.equal("Quality", d.control.text:GetText())
    value = 60
    local s = rows:Create(owner, option("slider", { min = 0, max = 100, step = 1 }), owner)
    assert.are.equal(60, s.control:GetValue())
    value = { 1, 0.5, 0, 1 }
    local c = rows:Create(owner, option("color", { hasOpacity = true }), owner)
    assert.are.same({ 1, 0.5, 0, 1 }, c.control:GetColor())
    assert.has_error(function() rows:Create(owner, option("nonsense"), owner) end, "a settings row has no control for nonsense")
  end)

  it("lays its name and control out RowPad in, the name wrapping, at least RowHeight tall", function()
    value = true
    local row = rows:Create(owner, option("toggle"), owner)
    local height = row:Measure(330)
    local toggle = style.Theme.Controls.Toggle
    assert.are.equal(330 - toggle.Width - 3 * C().RowPad, row.label:GetWidth())
    assert.are.equal(C().RowHeight, height)
    row.label:SetText(string.rep("A long setting name ", 12))
    assert.is_true(row:Measure(330) > C().RowHeight, "a name that wraps makes the row taller")
    row:Place(10, 40, 330, height)
    assert.are.same({ "TOPLEFT", owner, "TOPLEFT", 10, -40 }, { row.frame:GetPoint(1) })
    assert.are.same({ "LEFT", row.frame, "LEFT", C().RowPad, 0 }, { row.label:GetPoint(1) })
    assert.are.same({ "RIGHT", row.frame, "RIGHT", -C().RowPad, 0 }, { row.control.frame:GetPoint(1) })
  end)

  it("shows the setting again when its change was refused", function()
    value = false
    local row = rows:Create(owner, option("toggle", { set = function() return false end }), owner)
    row.control.frame:GetScript("OnClick")(row.control.frame, "LeftButton")
    assert.is_false(row.control:GetChecked())
  end)

  it("asks to reload the UI after a change that needs one, in a dialog over its window", function()
    value = true
    local row = rows:Create(owner, option("toggle", { reload = true }), owner)
    row.control.frame:GetScript("OnClick")(row.control.frame, "LeftButton")
    assert.is_true(nextDialog:IsShown())
    assert.are.equal(owner, nextDialog.frame:GetParent())
    nextDialog.buttons[2].frame:GetScript("OnClick")(nextDialog.buttons[2].frame, "LeftButton")
    assert.are.equal(1, reloads)
  end)

  it("lights up under the pointer, and shows its name and description in a tooltip", function()
    value = true
    local row = rows:Create(owner, option("toggle"), owner)
    row.frame:GetScript("OnEnter")(row.frame)
    assert.is_true(row.hover:IsShown())
    assert.is_true(GameTooltip:IsOwned(row.frame))
    row.frame:GetScript("OnLeave")(row.frame)
    assert.is_false(row.hover:IsShown())
    assert.is_false(GameTooltip:IsShown())
  end)

  it("stays lit while the pointer is over its control", function()
    value = true
    local row = rows:Create(owner, option("toggle"), owner)
    row.frame:_SetRect(0, 0, 330, 44)
    _G._cursorX, _G._cursorY = 300, 20
    row.control.frame:GetScript("OnEnter")(row.control.frame)
    assert.is_true(row.hover:IsShown())
    row.frame:GetScript("OnLeave")(row.frame)
    assert.is_true(row.hover:IsShown(), "the pointer is still in the row")
    _G._cursorX = 900
    row.control.frame:GetScript("OnLeave")(row.control.frame)
    assert.is_false(row.hover:IsShown())
    _G._cursorX, _G._cursorY = 0, 0
  end)

  it("makes rows across the page: text, buttons, a link", function()
    local text = rows:CreateText(owner, "Export your categories.")
    assert.is_true(text.wide)
    assert.are.equal(style:Font(C().TextFont), text.label:GetFontObject())
    assert.is_true(text:Measure(600) >= 12)
    local clicked = {}
    local buttons = rows:CreateButtons(owner, {
      { text = "Export", onClick = function() table.insert(clicked, "export") end },
      { text = "Delete", style = "Danger", onClick = function() table.insert(clicked, "delete") end },
    })
    assert.is_true(buttons.wide)
    assert.are.equal(2, #buttons.buttons)
    buttons.buttons[2].frame:GetScript("OnClick")(buttons.buttons[2].frame, "LeftButton")
    assert.are.same({ "delete" }, clicked)
    local link = rows:CreateLink(owner, "Backpack > Items", function() table.insert(clicked, "link") end)
    assert.is_true(link.wide)
    link.button.frame:GetScript("OnClick")(link.button.frame, "LeftButton")
    assert.are.same({ "delete", "link" }, clicked)
  end)
end)

describe("NextSettingsPage", function()
  local parent

  -- A row of a fixed height: just enough to be laid out.
  local function fakeRow(height, wide)
    local row = { frame = CreateFrame("Frame"), wide = wide == true, refreshed = 0, placed = nil }
    function row:Measure(width) self.measured = width return height end
    function row:Place(x, y, width, h)
      self.placed = { x, y, width, h }
      self.frame:Show()
    end
    function row:Refresh() self.refreshed = self.refreshed + 1 end
    return row
  end

  local function layout(page, width)
    return render:NewRenderChain(page, { ctx = ctx() }, { Width = width })
  end

  before_each(function()
    render:Init()
    parent = CreateFrame("Frame")
  end)

  it("lays a section's rows out in two columns, a pair as tall as its taller row", function()
    local page = nextPage:Create(parent)
    local a, b, c = fakeRow(60), fakeRow(44), fakeRow(44)
    page:SetSections({ { title = "Order", rows = { a, b, c } } })
    local result = layout(page, 760)
    local inner = 760 - 2 * C().Pad
    local column = inner / 2
    local top = C().Top + C().TitleHeight
    assert.are.same({ C().Pad, top, column, 60 }, a.placed)
    assert.are.same({ C().Pad + column, top, column, 60 }, b.placed)
    assert.are.same({ C().Pad, top + 60, column, 44 }, c.placed)
    assert.are.equal(top + 60 + 44 + C().Bottom, result.Height)
    assert.are.equal(760, result.Width)
    assert.are.equal("ORDER", page.titles[1]:GetText(), "section titles in capitals")
  end)

  it("lays its rows in one column when the page is narrower than two", function()
    local page = nextPage:Create(parent)
    local a, b = fakeRow(44), fakeRow(44)
    page:SetSections({ { title = "Order", rows = { a, b } } })
    layout(page, 2 * C().MinColumn + 2 * C().Pad - 1)
    local inner = 2 * C().MinColumn - 1
    assert.are.same({ C().Pad, C().Top + C().TitleHeight, inner, 44 }, a.placed)
    assert.are.same({ C().Pad, C().Top + C().TitleHeight + 44, inner, 44 }, b.placed)
  end)

  it("lays a wide row across both columns, on a line of its own", function()
    local page = nextPage:Create(parent)
    local a, wide, b = fakeRow(44), fakeRow(30, true), fakeRow(44)
    page:SetSections({ { title = "Import", rows = { a, wide, b } } })
    layout(page, 760)
    local inner = 760 - 2 * C().Pad
    local top = C().Top + C().TitleHeight
    assert.are.same({ C().Pad, top, inner / 2, 44 }, a.placed)
    assert.are.same({ C().Pad, top + 44, inner, 30 }, wide.placed)
    assert.are.same({ C().Pad, top + 74, inner / 2, 44 }, b.placed)
  end)

  it("stacks its sections SectionGap apart, each with its title and note, in a card", function()
    local page = nextPage:Create(parent)
    page:SetSections({
      { title = "Order", rows = { fakeRow(44) } },
      { title = "Slots", note = "(per bag)", rows = { fakeRow(44), fakeRow(44) } },
    })
    local result = layout(page, 760)
    local first = C().Top + C().TitleHeight
    local second = first + 44 + C().SectionGap + C().TitleHeight
    assert.are.equal(second + 44 + C().Bottom, result.Height)
    assert.are.equal("SLOTS", page.titles[2]:GetText())
    assert.are.equal("(per bag)", page.notes[2]:GetText())
    assert.is_true(page.notes[2]:IsShown())
    assert.is_false(page.notes[1]:IsShown())
    local card = page.cards[2]
    assert.are.same({ "TOPLEFT", page.frame, "TOPLEFT", C().Pad, -second }, { card:GetPoint(1) })
    assert.are.same({ 760 - 2 * C().Pad, 44 }, { card:GetSize() })
  end)

  it("draws a line between the rows of a card and between its columns", function()
    local page = nextPage:Create(parent)
    page:SetSections({ { title = "Order", rows = { fakeRow(44), fakeRow(44), fakeRow(44) } } })
    layout(page, 760)
    local shown = 0
    for _, line in ipairs(page.lines) do
      if line:IsShown() then shown = shown + 1 end
    end
    assert.are.equal(2, shown, "one between the two lines, one between the columns of the pair")
  end)

  it("tells its rows to show their values again", function()
    local page = nextPage:Create(parent)
    local a = fakeRow(44)
    page:SetSections({ { title = "Order", rows = { a } } })
    page:Refresh(ctx())
    assert.are.equal(1, a.refreshed)
  end)

  it("hides the sections and rows of a page it no longer shows", function()
    local page = nextPage:Create(parent)
    local a = fakeRow(44)
    page:SetSections({ { title = "Order", rows = { a } }, { title = "Slots", rows = { fakeRow(44) } } })
    layout(page, 760)
    page:SetSections({ { title = "Only", rows = { fakeRow(44) } } })
    layout(page, 760)
    assert.is_false(a.frame:IsShown())
    assert.is_false(page.titles[2]:IsShown())
    assert.is_false(page.cards[2]:IsShown())
  end)

  it("says so when it has nothing to show", function()
    local page = nextPage:Create(parent)
    page:SetSections({})
    page:SetEmptyText("No settings match \"zzz\".")
    local result = layout(page, 760)
    assert.is_true(page.empty:IsShown())
    assert.are.equal("No settings match \"zzz\".", page.empty:GetText())
    assert.is_true(result.Height > 0)
  end)
end)
