-- panel_controls_spec.lua -- NextSwatch, NextTopTabs and NextDialog (next/controls/swatch.lua,
-- toptabs.lua, dialog.lua): a color swatch that opens Blizzard's color picker, the tabs across a page
-- and a dialog over a window (next-settings.md §2), drawn from the theme's Controls.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" },
  { "NextButton", "next/controls/button.lua" }, { "NextInput", "next/controls/input.lua" },
  { "NextSwatch", "next/controls/swatch.lua" }, { "NextTopTabs", "next/controls/toptabs.lua" },
  { "NextDialog", "next/controls/dialog.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local nextSwatch = addon:GetModule("NextSwatch")
local nextTopTabs = addon:GetModule("NextTopTabs")
local nextDialog = addon:GetModule("NextDialog")
local controls = addon:GetModule("NextControls")
local style = addon:GetModule("NextStyle")
local tween = addon:GetModule("NextTween")

local function C(name)
  return style.Theme.Controls[name]
end

local function alphaOf(texture)
  return texture._colorTexture and texture._colorTexture.a
end

describe("NextSwatch", function()
  local changes

  local function make(color, hasOpacity)
    return nextSwatch:Create(CreateFrame("Frame"), {
      color = color or { 0.2, 0.4, 0.6, 1 },
      hasOpacity = hasOpacity,
      onChange = function(_, c) table.insert(changes, c) end,
    })
  end

  before_each(function()
    changes = {}
    ColorPickerFrame:Hide()
  end)

  it("is a square of its color, Size wide, edged, the edge stronger under the pointer", function()
    local s = make()
    assert.are.same({ C("Swatch").Size, C("Swatch").Size }, { s.frame:GetSize() })
    assert.are.same({ r = 0.2, g = 0.4, b = 0.6, a = 1 }, s.color._colorTexture)
    assert.are.equal(C("Swatch").Edge.Alpha, alphaOf(s.edge.Top))
    s.frame:GetScript("OnEnter")(s.frame)
    assert.are.equal(C("Swatch").HoverEdge.Alpha, alphaOf(s.edge.Top))
    s.frame:GetScript("OnLeave")(s.frame)
    assert.are.equal(C("Swatch").Edge.Alpha, alphaOf(s.edge.Top))
  end)

  it("opens Blizzard's color picker with its color, and takes each color picked", function()
    local s = make({ 0.2, 0.4, 0.6, 0.5 }, true)
    s.frame:GetScript("OnClick")(s.frame, "LeftButton")
    assert.is_true(ColorPickerFrame:IsShown())
    assert.are.same({ 0.2, 0.4, 0.6, 0.5, true }, { ColorPickerFrame.info.r, ColorPickerFrame.info.g,
      ColorPickerFrame.info.b, ColorPickerFrame.info.opacity, ColorPickerFrame.info.hasOpacity })
    ColorPickerFrame:_Pick(1, 0, 0)
    assert.are.same({ 1, 0, 0, 0.5 }, changes[1])
    assert.are.same({ r = 1, g = 0, b = 0, a = 0.5 }, s.color._colorTexture)
    ColorPickerFrame:_Pick(1, 0, 0, 0.25)
    assert.are.same({ 1, 0, 0, 0.25 }, s:GetColor())
  end)

  it("puts its color back, and says so, when the picker is cancelled", function()
    local s = make({ 0.2, 0.4, 0.6, 1 })
    s.frame:GetScript("OnClick")(s.frame, "LeftButton")
    ColorPickerFrame:_Pick(1, 1, 1)
    ColorPickerFrame:_Cancel()
    assert.are.same({ 0.2, 0.4, 0.6, 1 }, s:GetColor())
    assert.are.same({ 0.2, 0.4, 0.6, 1 }, changes[#changes])
  end)

  it("shows a color it is given, calling nothing back", function()
    local s = make()
    s:SetColor({ 0.5, 0.5, 0.5, 1 })
    assert.are.same({ r = 0.5, g = 0.5, b = 0.5, a = 1 }, s.color._colorTexture)
    assert.are.same({}, changes)
  end)
end)

describe("NextTopTabs", function()
  local selected

  local function make()
    local tabs = nextTopTabs:Create(CreateFrame("Frame"), {
      onSelect = function(_, id) table.insert(selected, id) end,
    })
    tabs:SetTabs({ { id = "layout", text = "Layout" }, { id = "items", text = "Items" },
      { id = "categories", text = "Categories" } })
    tabs:Select("layout")
    return tabs
  end

  local function markerX(tabs)
    local _, _, _, x = tabs.marker:GetPoint(1)
    return x
  end

  before_each(function()
    selected = {}
    tween:Init()
  end)

  it("lays its tabs out left to right, Gap apart, Height tall, the chosen one in its font", function()
    local tabs = make()
    local T = C("TopTabs")
    assert.are.equal(T.Height, tabs.frame:GetHeight())
    assert.are.equal(3, #tabs.tabs)
    assert.are.same({ "BOTTOMLEFT", tabs.frame, "BOTTOMLEFT", 0, 0 }, { tabs.tabs[1].frame:GetPoint(1) })
    assert.are.same({ "BOTTOMLEFT", tabs.tabs[1].frame, "BOTTOMRIGHT", T.Gap, 0 }, { tabs.tabs[2].frame:GetPoint(1) })
    assert.are.equal(#"Layout" * 6, tabs.tabs[1].frame:GetWidth())
    assert.are.equal(style:Font("TopTabSelected"), tabs.tabs[1].label:GetFontObject())
    assert.are.equal(style:Font("TopTab"), tabs.tabs[2].label:GetFontObject())
    assert.are.equal("layout", tabs:GetSelected())
  end)

  it("underlines the chosen tab with its marker, Indicator.Height thick, over the line under them all", function()
    local tabs = make()
    assert.are.equal(C("TopTabs").Indicator.Height, tabs.marker:GetHeight())
    assert.are.equal(#"Layout" * 6, tabs.marker:GetWidth())
    assert.are.equal(0, markerX(tabs))
    assert.are.equal(C("TopTabs").Line.Size, tabs.line:GetHeight())
    assert.are.equal(C("TopTabs").Line.Alpha, alphaOf(tabs.line))
  end)

  it("draws its marker in art when its indicator names some", function()
    UseNextTheme({ Controls = { TopTabs = { Indicator = { Texture = "Interface\\Spec\\mark.png", Color = "White", Height = 4 } } } })
    local tabs = make()
    assert.are.equal("Interface\\Spec\\mark.png", tabs.marker:GetTexture())
    assert.are.equal(4, tabs.marker:GetHeight())
    UseNextTheme(nil)
    tabs:Style()
    assert.is_nil(tabs.marker:GetTexture())
  end)

  it("selects a tab on a click, gliding its marker there, and says which", function()
    local tabs = make()
    tabs.tabs[2].frame:GetScript("OnClick")(tabs.tabs[2].frame, "LeftButton")
    assert.are.same({ "items" }, selected)
    assert.are.equal("items", tabs:GetSelected())
    assert.is_true(tween:IsPlaying(tabs))
    tween:Step(1)
    assert.are.equal(#"Layout" * 6 + C("TopTabs").Gap, markerX(tabs))
    assert.are.equal(#"Items" * 6, tabs.marker:GetWidth())
    assert.are.equal(style:Font("TopTabSelected"), tabs.tabs[2].label:GetFontObject())
    tabs.tabs[2].frame:GetScript("OnClick")(tabs.tabs[2].frame, "LeftButton")
    assert.are.same({ "items" }, selected, "nothing for the tab already chosen")
  end)

  it("brightens a tab under the pointer", function()
    local tabs = make()
    tabs.tabs[3].frame:GetScript("OnEnter")(tabs.tabs[3].frame)
    assert.are.equal(style:Font("TopTabHover"), tabs.tabs[3].label:GetFontObject())
    tabs.tabs[3].frame:GetScript("OnLeave")(tabs.tabs[3].frame)
    assert.are.equal(style:Font("TopTab"), tabs.tabs[3].label:GetFontObject())
  end)

  it("hides the tabs it no longer has", function()
    local tabs = make()
    tabs:SetTabs({ { id = "only", text = "Only" } })
    tabs:Select("only")
    assert.is_true(tabs.tabs[1].frame:IsShown())
    assert.is_false(tabs.tabs[2].frame:IsShown())
    assert.are.equal("only", tabs:GetSelected())
  end)
end)

describe("NextDialog", function()
  local owner, log, timers, saved

  local function show(opts)
    opts = opts or {}
    opts.title = opts.title or "Delete Profile"
    opts.text = opts.text or "Delete profile 'Raid'? This cannot be undone."
    opts.buttons = opts.buttons or {
      { text = "Cancel", onClick = function() table.insert(log, "cancel") end },
      { text = "Delete", style = "Danger", onClick = function(_, text) table.insert(log, { "delete", text }) end },
    }
    nextDialog:Show(owner, opts)
    return nextDialog
  end

  before_each(function()
    log, timers = {}, {}
    saved = { _G.UISpecialFrames, C_Timer.After }
    _G.UISpecialFrames = {}
    C_Timer.After = function(_, fn) table.insert(timers, fn) end
    controls.escape = {}
    owner = CreateFrame("Frame", "SpecSettingsWindow", UIParent)
    owner:SetSize(1000, 660)
    owner:Show()
  end)

  after_each(function()
    nextDialog:Hide()
    _G.UISpecialFrames, C_Timer.After = saved[1], saved[2]
  end)

  it("covers its window with a scrim and shows a card Width wide over it, titled, its text wrapped", function()
    local d = show()
    local D = C("Dialog")
    assert.is_true(d.frame:IsShown())
    assert.are.equal("BetterBagsNextDialog", d.frame:GetName())
    assert.are.equal(owner, d.frame:GetParent())
    assert.is_true(d.frame:GetFrameLevel() > owner:GetFrameLevel())
    assert.is_true(d.frame:IsMouseEnabled(), "the scrim takes the clicks meant for the window")
    assert.are.equal(D.Width, d.card:GetWidth())
    -- In the middle of the window by its top left, in whole pixels (docs/next-pixel-perfect.md).
    local point, rel, relPoint, x, y = d.card:GetPoint(1)
    assert.are.same({ "TOPLEFT", d.frame, "TOPLEFT" }, { point, rel, relPoint })
    assert.are.equal(math.floor((1000 - D.Width) / 2), x)
    assert.are.equal(-math.floor((660 - d.card:GetHeight()) / 2), y)
    assert.are.equal("Delete Profile", d.title:GetText())
    assert.are.equal(style:Font("DialogTitle"), d.title:GetFontObject())
    assert.are.equal(style:Font("DialogText"), d.text:GetFontObject())
    assert.are.equal(D.Width - 2 * D.Pad, d.text:GetWidth())
    assert.is_false(d.input.frame:IsShown())
  end)

  it("lays its buttons out from the right, in the order given, and closes after one is clicked", function()
    local d = show()
    local cancel, delete = d.buttons[1], d.buttons[2]
    assert.are.same({ "BOTTOMRIGHT", d.card, "BOTTOMRIGHT", -C("Dialog").Pad, C("Dialog").Pad }, { delete.frame:GetPoint(1) })
    assert.are.same({ "TOPRIGHT", delete.frame, "TOPLEFT", -C("Dialog").ButtonGap, 0 }, { cancel.frame:GetPoint(1) })
    assert.are.equal(style:Font("ButtonDanger"), delete.label:GetFontObject())
    delete.frame:GetScript("OnClick")(delete.frame, "LeftButton")
    assert.are.same({ { "delete", "" } }, log)
    assert.is_false(d.frame:IsShown())
  end)

  it("asks for text with a field, hands it to the button, and confirms with Enter", function()
    local d = show({
      title = "New Profile", text = "Name the new profile:",
      input = { text = "Raid", help = "Profile name", maxLetters = 48 },
      buttons = {
        { text = "Cancel", onClick = function() table.insert(log, "cancel") end },
        { text = "Create", style = "Primary", onClick = function(_, text) table.insert(log, { "create", text }) end },
      },
    })
    assert.is_true(d.input.frame:IsShown())
    assert.are.equal("Raid", d.input:GetText())
    assert.are.equal(48, d.input.frame:GetMaxLetters())
    assert.is_true(d.input.frame:HasFocus())
    d.input.frame:SetText("Mythic")
    d.input.frame:GetScript("OnEnterPressed")(d.input.frame)
    assert.are.same({ { "create", "Mythic" } }, log)
    assert.is_false(d.frame:IsShown())
  end)

  it("stays open when a button says so (a name already taken)", function()
    local d = show({ buttons = { { text = "OK", onClick = function() table.insert(log, "ok") return true end } } })
    d.buttons[1].frame:GetScript("OnClick")(d.buttons[1].frame, "LeftButton")
    assert.is_true(d.frame:IsShown())
  end)

  it("closes with Escape before its window, cancelling", function()
    controls:PushEscape(owner)
    local d = show()
    assert.are.same({ "BetterBagsNextDialog" }, UISpecialFrames)
    d.frame:Hide()
    d.frame:GetScript("OnHide")(d.frame)
    assert.are.same({ "cancel" }, log, "Escape is the first button, the one that answers no")
    for _, fn in ipairs(timers) do fn() end
    assert.are.same({ "SpecSettingsWindow" }, UISpecialFrames)
  end)

  it("shows new content each time, with only the buttons asked for", function()
    show()
    local d = show({ buttons = { { text = "OK", onClick = function() end } } })
    assert.is_true(d.buttons[1].frame:IsShown())
    assert.are.equal("OK", d.buttons[1].label:GetText())
    assert.is_false(d.buttons[2].frame:IsShown())
  end)
end)
