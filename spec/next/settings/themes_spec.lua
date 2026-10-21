-- themes_spec.lua -- NextSettingsThemes (next/settings/themes.lua): the Appearance page's theme picker
-- (next-settings.md §4): a card per theme an engine lists (BetterBags Next's, or the bags' for item
-- buttons and dialogs), a pick previewed on the next frame, Apply Theme saving it, and the saved
-- theme put back when the page is left.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
local L = StubBetterBagsModule("Localization")
L.G = L.G or function(_, key) return key end
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" },
  { "NextButton", "next/controls/button.lua" }, { "NextSettingsThemes", "next/settings/themes.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local themes = addon:GetModule("NextSettingsThemes")
local context = addon:GetModule("Context")
local style = addon:GetModule("NextStyle")

local function K()
  return style.Theme.Settings.Cards
end

describe("NextSettingsThemes", function()
  local engine, timers, saved

  local function fakeEngine()
    local e = {
      themes = {
        Default = { Name = "Default", DisplayName = "Default", Description = "Moonlit." },
        Ember = { Name = "Ember", DisplayName = "Ember", Description = "Warm." },
        Gw2 = { Name = "Gw2", DisplayName = "Guild Wars 2", Description = "Needs GW2_UI." },
      },
      saved = "Default", current = "Default", applied = {},
    }
    function e:GetThemes() return self.themes end
    function e:IsAvailable(key) return key ~= "Gw2" end
    function e:IsSelectable(key) return key ~= "Gw2" end
    function e:GetCurrentThemeKey() return self.current end
    function e:GetSavedThemeKey() return self.saved end
    function e:ApplyTheme(_, key, save)
      table.insert(self.applied, { key, save ~= false })
      self.current = key
      if save ~= false then self.saved = key end
    end
    function e:RestoreSavedTheme()
      if self.current ~= self.saved then self:ApplyTheme(nil, self.saved, false) end
    end
    return e
  end

  local function make()
    local block = themes:Create(CreateFrame("Frame"), engine)
    block:Refresh(context:New("spec"))
    return block
  end

  local function card(block, name)
    for _, c in ipairs(block.cards) do
      if c.frame:IsShown() and c.name:GetText() == name then return c end
    end
  end

  local function nextFrame()
    local due = timers
    timers = {}
    for _, fn in ipairs(due) do fn() end
  end

  before_each(function()
    engine = fakeEngine()
    timers = {}
    saved = C_Timer.After
    C_Timer.After = function(_, fn) table.insert(timers, fn) end
  end)

  after_each(function()
    C_Timer.After = saved
  end)

  it("lists a card per theme, sorted by name, saying which is active and which cannot be used", function()
    local block = make()
    assert.is_true(block.wide)
    local names = {}
    for _, c in ipairs(block.cards) do
      if c.frame:IsShown() then table.insert(names, c.name:GetText()) end
    end
    assert.are.same({ "Default", "Ember", "Guild Wars 2" }, names)
    assert.are.equal("Active", card(block, "Default").status:GetText())
    assert.are.equal(style:Font(K().ActiveFont), card(block, "Default").status:GetFontObject())
    assert.are.equal("Unavailable", card(block, "Guild Wars 2").status:GetText())
    assert.are.equal("", card(block, "Ember").status:GetText())
    assert.are.equal("Warm.", card(block, "Ember").text:GetText())
    assert.are.equal(K().SelectedEdge.Alpha, card(block, "Default").edge.Top._colorTexture.a)
  end)

  it("lays its cards out in two columns when there is room, Height tall and Gap apart", function()
    local block = make()
    local width = 2 * K().MinWidth + K().Gap + 2 * style.Theme.Settings.Content.RowPad
    local height = block:Measure(width)
    block:Place(0, 0, width, height)
    local half = (width - 2 * style.Theme.Settings.Content.RowPad - K().Gap) / 2
    local cards = block.cards
    assert.are.same({ half, K().Height }, { cards[1].frame:GetSize() })
    assert.are.same({ "TOPLEFT", block.frame, "TOPLEFT", style.Theme.Settings.Content.RowPad + half + K().Gap,
      -(style.Theme.Settings.Content.RowPad / 2) }, { cards[2].frame:GetPoint(1) })
    assert.are.equal(2 * K().Height + K().Gap + style.Theme.Settings.Content.RowPad + block.apply.frame:GetHeight() + K().Gap,
      height)
    assert.is_true(block:Measure(K().MinWidth) > height, "one column when narrow")
  end)

  it("previews a theme picked on the next frame, never inside the click, and marks it", function()
    local block = make()
    local ember = card(block, "Ember")
    ember.frame:GetScript("OnClick")(ember.frame, "LeftButton")
    assert.are.same({}, engine.applied, "nothing inside the click")
    nextFrame()
    assert.are.same({ { "Ember", false } }, engine.applied)
    assert.are.equal("Previewing", card(block, "Ember").status:GetText())
    assert.are.equal(K().SelectedEdge.Alpha, card(block, "Ember").edge.Top._colorTexture.a)
    assert.is_true(block.apply.frame:IsEnabled())
  end)

  it("previews only the last pick made before the next frame", function()
    local block = make()
    card(block, "Ember").frame:GetScript("OnClick")(card(block, "Ember").frame, "LeftButton")
    card(block, "Default").frame:GetScript("OnClick")(card(block, "Default").frame, "LeftButton")
    nextFrame()
    assert.are.same({}, engine.applied, "the saved theme was picked last: nothing to preview")
  end)

  it("saves the theme previewed with Apply Theme, which is off when there is nothing to apply", function()
    local block = make()
    assert.is_false(block.apply.frame:IsEnabled())
    card(block, "Ember").frame:GetScript("OnClick")(card(block, "Ember").frame, "LeftButton")
    nextFrame()
    block.apply.frame:GetScript("OnClick")(block.apply.frame, "LeftButton")
    assert.are.same({ "Ember", true }, engine.applied[2])
    assert.are.equal("Ember", engine.saved)
    assert.are.equal("Active", card(block, "Ember").status:GetText())
    assert.is_false(block.apply.frame:IsEnabled())
  end)

  it("shows the saved theme for a pick that cannot be used", function()
    local block = make()
    card(block, "Ember").frame:GetScript("OnClick")(card(block, "Ember").frame, "LeftButton")
    nextFrame()
    card(block, "Guild Wars 2").frame:GetScript("OnClick")(card(block, "Guild Wars 2").frame, "LeftButton")
    nextFrame()
    assert.are.equal("Default", engine.current)
    assert.is_false(block.apply.frame:IsEnabled())
  end)

  it("puts the saved theme back and forgets the pick when the page is left", function()
    local block = make()
    card(block, "Ember").frame:GetScript("OnClick")(card(block, "Ember").frame, "LeftButton")
    nextFrame()
    block:OnPageLeft(context:New("spec"))
    assert.are.equal("Default", engine.current)
    assert.are.equal("", card(block, "Ember").status:GetText())
    assert.are.equal(K().SelectedEdge.Alpha, card(block, "Default").edge.Top._colorTexture.a)
  end)

  it("previews nothing when the page is left before the next frame", function()
    local block = make()
    card(block, "Ember").frame:GetScript("OnClick")(card(block, "Ember").frame, "LeftButton")
    block:OnPageLeft(context:New("spec"))
    nextFrame()
    assert.are.same({}, engine.applied)
  end)

  it("lights a card under the pointer", function()
    local block = make()
    local ember = card(block, "Ember")
    ember.frame:GetScript("OnEnter")(ember.frame)
    assert.are.equal(K().HoverFill.Alpha, ember.fill._colorTexture.a)
    ember.frame:GetScript("OnLeave")(ember.frame)
    assert.are.equal(K().Fill.Alpha, ember.fill._colorTexture.a)
  end)
end)
