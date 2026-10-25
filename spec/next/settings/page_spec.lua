-- A text sits a quarter pixel right of and above its whole pixel (next-pixel-perfect.md §2); one pixel is one unit here.
local TEXT = 0.25
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
  { "NextFrameArt", "next/frameart.lua" }, { "NextFill", "next/fill.lua" }, { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" },
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

  -- Blizzard's settings rows (Blizzard_SettingControls.*), the Plain theme's: 26 tall; the name 37 in, up to 85 left of
  -- the row's middle; the check box from 80 left of the middle, the dropdown 48 left and 3 up, the slider 80 left and 3
  -- up, the swatch 73 left, a button 40 left; lit under the pointer from 10 past its left to 5 short of its right
  -- (HoverBackgroundTemplate).
  describe("laid out as Blizzard's list", function()
    local LIST = { Settings = { Content = { Layout = "List", RowHeight = 26, LabelX = 37, LabelRight = -85,
      Controls = { toggle = { X = -80 }, dropdown = { X = -48, Y = 3 }, slider = { X = -80, Y = 3 }, color = { X = -73 },
        input = { X = -80 }, buttons = { X = -40 } },
      HoverInset = { Left = -10, Right = 5 } } } }

    before_each(function() UseNextTheme(LIST) end)
    after_each(function() UseNextTheme(nil) end)

    local function x(region) local _, _, _, px = region:GetPoint(1) return px end
    local function y(region) local _, _, _, _, py = region:GetPoint(1) return py end

    it("puts a setting's name 37 in and its control from the row's middle, the row 26 tall", function()
      value = true
      local row = rows:Create(owner, option("toggle"), owner)
      assert.are.equal(26, row:Measure(635))
      row:Place(25, 64, 635, 26)
      assert.are.equal(37 + TEXT, x(row.label))
      assert.are.equal(317 - 85 - 37, row.label:GetWidth(), "up to 85 left of the middle")
      assert.are.equal(317 - 80, x(row.control.frame))
      assert.are.same({ "TOPLEFT", row.frame, "TOPLEFT", -10, 0 }, { row.hover:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", row.frame, "BOTTOMRIGHT", -5, 0 }, { row.hover:GetPoint(2) })
    end)

    it("puts each kind's control where Blizzard's is, 3 up for the dropdown and the slider", function()
      value = 5
      local toggle = rows:Create(owner, option("toggle"), owner)
      local dropdown = rows:Create(owner, option("dropdown", { items = { "One", "Two" } }), owner)
      local slider = rows:Create(owner, option("slider", { min = 0, max = 10, step = 1 }), owner)
      local swatch = rows:Create(owner, option("color", { get = function() return { r = 1, g = 1, b = 1, a = 1 } end }), owner)
      for _, row in ipairs({ toggle, dropdown, slider, swatch }) do row:Place(25, 0, 635, 26) end
      assert.are.equal(317 - 48, x(dropdown.control.frame))
      assert.are.equal(317 - 80, x(slider.control.frame))
      assert.are.equal(317 - 73, x(swatch.control.frame))
      local centered = -math.floor((26 - dropdown.control.frame:GetHeight()) / 2)
      assert.are.equal(centered + 3, y(dropdown.control.frame), "3 up")
    end)

    it("puts a row of buttons from 40 left of its middle", function()
      local row = rows:CreateButtons(owner, { { text = "Export", onClick = function() end }, { text = "Delete", onClick = function() end } })
      row:Place(25, 0, 635, 26)
      assert.are.equal(317 - 40, x(row.buttons[1].frame))
      assert.is_true(x(row.buttons[2].frame) > x(row.buttons[1].frame) + row.buttons[1].frame:GetWidth() - 1)
    end)
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

  -- Asked: "animate our toggle switches in the options screen".
  it("slides a switch it shows again with another value, and keeps a click's slide going", function()
    local tween = addon:GetModule("NextTween")
    tween:Init()
    value = false
    local row = rows:Create(owner, option("toggle"), owner)
    row.control.frame:GetScript("OnClick")(row.control.frame, "LeftButton")
    row:Refresh(ctx())
    assert.is_true(tween:IsPlaying(row.control), "the click's slide goes on")
    tween:Step(1)
    value = false
    row:Refresh(ctx())
    assert.is_true(tween:IsPlaying(row.control), "changed elsewhere (another switch): it slides")
    tween:Step(1)
    row:Refresh(ctx())
    assert.is_false(tween:IsPlaying(row.control), "unchanged: nothing")
    owner:Hide()
    value = true
    row:Refresh(ctx())
    assert.is_false(tween:IsPlaying(row.control), "hidden: at once")
    assert.is_true(row.control:GetChecked())
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
    -- From the row's corners, centered on its height by their tops (docs/next-pixel-perfect.md): the name by
    -- its lines' height rounded up.
    local labelTop = math.max(0, math.floor((height - math.ceil(row.label:GetStringHeight())) / 2))
    assert.are.same({ "TOPLEFT", row.frame, "TOPLEFT", C().RowPad + TEXT, -labelTop + TEXT }, { row.label:GetPoint(1) })
    assert.are.same({ "TOPRIGHT", row.frame, "TOPRIGHT", -C().RowPad, -math.floor((height - toggle.Height) / 2) },
      { row.control.frame:GetPoint(1) })
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

  it("makes a one-line text kind, writing what is typed on Enter", function()
    value = "Bags"
    local row = rows:Create(owner, option("input"), owner)
    assert.are.equal("Bags", row.control:GetText())
    row.control.frame:SetText("Loot")
    row.control.frame:GetScript("OnEnterPressed")(row.control.frame)
    assert.are.same({ "Loot" }, writes)
  end)

  it("draws a setting it says is disabled as disabled, read again each time", function()
    local off = true
    value = true
    local row = rows:Create(owner, option("toggle", { disabled = function() return off end }), owner)
    row:Refresh(ctx())
    assert.is_false(row.control.frame:IsEnabled())
    off = false
    row:Refresh(ctx())
    assert.is_true(row.control.frame:IsEnabled())
    value = 5
    local s = rows:Create(owner, option("slider", { min = 0, max = 10, step = 1, disabled = true }), owner)
    s:Refresh(ctx())
    assert.is_false(s.control.track:IsEnabled())
    value = { 1, 1, 1, 1 }
    local c = rows:Create(owner, option("color", { disabled = true }), owner)
    c:Refresh(ctx())
    assert.is_false(c.control.frame:IsEnabled())
  end)

  it("reads a text row's text again when it is a function", function()
    local n = 1
    local text = rows:CreateText(owner, function() return "Default: " .. n .. " characters" end)
    assert.are.equal("Default: 1 characters", text.label:GetText())
    n = 2
    text:Refresh(ctx())
    assert.are.equal("Default: 2 characters", text.label:GetText())
  end)

  it("makes a text area across the page, its height and the row's padding tall", function()
    local area = rows:CreateArea(owner, { height = 120, help = "Paste here" })
    assert.is_true(area.wide)
    assert.are.equal("Paste here", area.area.help:GetText())
    assert.are.equal(120 + C().RowPad, area:Measure(600))
    area:Place(0, 0, 600, 134)
    assert.are.same({ "TOPLEFT", area.frame, "TOPLEFT", C().RowPad, -C().RowPad / 2 }, { area.area.frame:GetPoint(1) })
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

  -- Blizzard's settings list (Blizzard_SettingsList.*, Blizzard_SettingControls.*), the Plain theme's: one column, 25 in,
  -- 10 from the top; a section's title element 45 tall, its title 7 in and 16 down, as written; rows 26 tall; 9 between
  -- every element; no cards or lines.
  describe("laid out as Blizzard's list", function()
    local LIST = { Settings = { Content = { Layout = "List", Pad = 25, PadRight = 0, Top = 10, Bottom = 10, RowGap = 9,
      SectionHeight = 45, TitleX = 7, TitleTop = 16, TitleUpper = false, RowHeight = 26, Card = false, Divider = false } } }

    before_each(function() UseNextTheme(LIST) end)
    after_each(function() UseNextTheme(nil) end)

    it("puts each row on a line of its own, 9 apart, under a 45-pixel title written as it is", function()
      local page = nextPage:Create(parent)
      local a, b, c = fakeRow(26), fakeRow(26), fakeRow(26, true)
      page:SetSections({ { title = "Bags", rows = { a, b } }, { title = "Search", rows = { c } } })
      local result = layout(page, 660)
      assert.are.same({ 25, 10 + 45 + 9, 635, 26 }, a.placed, "one column, 25 in, under the title")
      assert.are.same({ 25, 10 + 45 + 9 + 26 + 9, 635, 26 }, b.placed)
      local second = 10 + 45 + 9 + 26 + 9 + 26 + 9
      assert.are.same({ 25, second + 45 + 9, 635, 26 }, c.placed)
      assert.are.equal(second + 45 + 9 + 26 + 10, result.Height)
      assert.are.equal("Bags", page.titles[1]:GetText(), "as written")
      assert.are.same({ "TOPLEFT", page.frame, "TOPLEFT", 25 + 7 + TEXT, -(10 + 16) + TEXT }, { page.titles[1]:GetPoint(1) })
      assert.are.same({ "TOPLEFT", page.frame, "TOPLEFT", 25 + 7 + TEXT, -(second + 16) + TEXT }, { page.titles[2]:GetPoint(1) })
      for _, card in ipairs(page.cards) do assert.is_false(card:IsShown()) end
      for _, line in ipairs(page.lines) do assert.is_false(line:IsShown()) end
    end)

    it("starts a section without a shown title with its first row", function()
      local page = nextPage:Create(parent)
      local a = fakeRow(26)
      page:SetSections({ { title = "Hidden", titleHidden = function() return true end, rows = { a } } })
      layout(page, 660)
      assert.are.same({ 25, 10, 635, 26 }, a.placed)
    end)
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

  -- The Plain theme on Default's layout (docs/next-plain-theme.md, round three): Blizzard writes its section titles as
  -- they are, in cards too.
  it("writes its section titles as they are for a theme that says so, in cards too", function()
    UseNextTheme({ Settings = { Content = { TitleUpper = false } } })
    local page = nextPage:Create(parent)
    page:SetSections({ { title = "Slots", rows = { fakeRow(44) } } })
    layout(page, 760)
    assert.are.equal("Slots", page.titles[1]:GetText())
    UseNextTheme(nil)
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

  -- The Plain theme (docs/next-plain-theme.md): Blizzard's settings rows have no lines between them.
  it("draws no line for a theme without a divider", function()
    UseNextTheme({ Settings = { Content = { Divider = false } } })
    local page = nextPage:Create(parent)
    page:SetSections({ { title = "Order", rows = { fakeRow(44), fakeRow(44), fakeRow(44) } } })
    layout(page, 760)
    for _, line in ipairs(page.lines) do
      assert.is_false(line:IsShown())
    end
    UseNextTheme(nil)
  end)

  it("tells its rows when the page is left (a theme preview ends)", function()
    local page = nextPage:Create(parent)
    local a = fakeRow(44)
    local left = 0
    function a:OnPageLeft() left = left + 1 end
    page:SetSections({ { title = "Order", rows = { a, fakeRow(44) } } })
    page:Leave(ctx())
    assert.are.equal(1, left)
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
