-- nav_spec.lua -- NextSettingsNav (next/settings/nav.lua): the rows of a list down the settings window's sidebar,
-- entries under headings, drawn from the theme's Settings.Nav: the window's pages and the Help page's articles share
-- them (next-settings.md §3, help.md §4).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- A text sits a quarter pixel right of and above its whole pixel (next-pixel-perfect.md §2); one pixel is one unit here.
local TEXT = 0.25

LoadBetterBagsModule("core/context.lua")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextFill", "next/fill.lua" }, { "NextControls", "next/controls/base.lua" },
  { "NextSettingsNav", "next/settings/nav.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local nav = addon:GetModule("NextSettingsNav")
local style = addon:GetModule("NextStyle")

local function N()
  return style.Theme.Settings.Nav
end

describe("NextSettingsNav", function()
  local parent

  before_each(function()
    UseNextTheme(nil)
    parent = CreateFrame("Frame", nil, UIParent)
    parent:SetSize(232, 400)
  end)

  after_each(function()
    UseNextTheme(nil)
  end)

  it("makes a row: a button with its fill, its light, its bar and a label that does not wrap", function()
    local row = nav:CreateRow(parent)
    assert.are.equal("Button", row.frame:GetObjectType())
    assert.is_truthy(row.fill)
    assert.is_truthy(row.hover)
    assert.is_truthy(row.indicator)
    assert.are.equal("LEFT", row.label:GetJustifyH())
    assert.is_false(row.label:CanWordWrap())
    assert.is_false(row.hovered)
  end)

  it("puts a row y down its list, across it", function()
    local row = nav:CreateRow(parent)
    nav:PlaceRow(row, parent, 40)
    local point, rel, relPoint, x, y = row.frame:GetPoint(1)
    assert.are.same({ "TOPLEFT", parent, "TOPLEFT", 0, -40 }, { point, rel, relPoint, x, y })
    local point2, _, _, _, y2 = row.frame:GetPoint(2)
    assert.are.equal("TOPRIGHT", point2)
    assert.are.equal(-40, y2)
  end)

  it("puts a row ItemWidth wide from its left when the theme says", function()
    UseNextTheme({ Settings = { Nav = { ItemWidth = 175 } } })
    local row = nav:CreateRow(parent)
    nav:PlaceRow(row, parent, 0)
    assert.are.equal(1, row.frame:GetNumPoints())
    assert.are.equal(175, row.frame:GetWidth())
  end)

  it("draws a heading in the group font above its bottom, without a light or a bar", function()
    local row = nav:CreateRow(parent)
    row.hovered = true
    nav:PaintHeading(row, parent, 1)
    assert.are.equal(N().GroupFont, style.texts[row.label])
    local point, _, _, x = row.label:GetPoint(1)
    assert.are.equal("BOTTOMLEFT", point)
    assert.are.equal(style.Theme.Settings.Sidebar.Pad + TEXT, x)
    assert.is_false(row.hover:IsShown())
    assert.is_false(row.indicator:IsShown())
  end)

  it("draws the theme's heading art behind a heading, and none for a theme without", function()
    local row = nav:CreateRow(parent)
    nav:PaintHeading(row, parent, 3)
    assert.is_false(row.fill:IsShown())
    UseNextTheme({ Settings = { Nav = { GroupFills = { { Color = "Gold" }, { Color = "Lavender" } } } } })
    nav:PaintHeading(row, parent, 3)
    assert.is_true(row.fill:IsShown())
  end)

  it("draws an entry Indent in: idle, under the pointer, and chosen with its bar and fill", function()
    local row = nav:CreateRow(parent)
    row.frame:SetHeight(N().ItemHeight)
    nav:PaintEntry(row, parent, false)
    assert.are.equal(N().Font, style.texts[row.label])
    assert.is_false(row.fill:IsShown())
    assert.is_false(row.hover:IsShown())
    assert.is_false(row.indicator:IsShown())
    local _, _, _, x = row.label:GetPoint(1)
    assert.are.equal(style.Theme.Settings.Sidebar.Pad + N().Indent + TEXT, x)

    row.hovered = true
    nav:PaintEntry(row, parent, false)
    assert.are.equal(N().HoverFont, style.texts[row.label])
    assert.is_true(row.hover:IsShown())
    assert.is_false(row.fill:IsShown())

    nav:PaintEntry(row, parent, true)
    assert.are.equal(N().SelectedFont, style.texts[row.label])
    assert.is_true(row.fill:IsShown())
    assert.is_false(row.hover:IsShown())
    assert.is_true(row.indicator:IsShown())
    assert.are.equal(N().Indicator.Width, row.indicator:GetWidth())
  end)

  it("draws no bar for a theme without one", function()
    UseNextTheme({ Settings = { Nav = { Indicator = false } } })
    local row = nav:CreateRow(parent)
    nav:PaintEntry(row, parent, true)
    assert.is_false(row.indicator:IsShown())
    assert.is_true(row.fill:IsShown())
  end)

  it("leaves the chosen entry's fill and bar to a marker that draws them, in the same keys", function()
    local row = nav:CreateRow(parent)
    nav:PaintEntry(row, parent, true, true)
    assert.are.equal(N().SelectedFont, style.texts[row.label], "still in the chosen font")
    assert.is_false(row.fill:IsShown())
    assert.is_false(row.indicator:IsShown())
    local marker = nav:CreateMarker(parent)
    nav:PaintMarker(marker)
    assert.is_true(marker.fill:IsShown())
    assert.is_true(marker.indicator:IsShown())
    assert.are.equal(N().Indicator.Width, marker.indicator:GetWidth())
    UseNextTheme({ Settings = { Nav = { Indicator = false } } })
    nav:PaintMarker(marker)
    assert.is_false(marker.indicator:IsShown())
  end)

  it("gives the list's lengths in whole pixels", function()
    local m = nav:Metrics(parent)
    assert.are.equal(N().GroupGap, m.groupGap)
    assert.are.equal(N().GroupHeight, m.groupHeight)
    assert.are.equal(N().ItemHeight, m.itemHeight)
    assert.are.equal(0, m.spacing)
  end)
end)
