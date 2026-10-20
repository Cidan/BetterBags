-- themepane_spec.lua -- The settings window's Theme pane (config/themepane.lua): the themes
-- Sonata knows, which one is applied, and applying another.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
local events = addon:GetModule("Events")
events:Init()
local context = addon:GetModule("Context")

local createdStubs = {}
local function stubModule(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local db = stubModule("Database")
local fonts = stubModule("Fonts")
fonts.UnitFrame12White = fonts.UnitFrame12White or CreateFont("BetterBagsThemePaneSpecWhite")

-- A list that keeps its entries in order (frames/list.lua's AddToEnd, AddToStart, Wipe).
local list = stubModule("List")

LoadBetterBagsModule("sonata/engine.lua")
LoadBetterBagsModule("sonata/apply.lua")
local sonata = addon:GetModule("Sonata")

ResetModuleStub("ThemePane", "config/themepane.lua")
LoadBetterBagsModule("config/themepane.lua")
local themePane = addon:GetModule("ThemePane")

describe("ThemePane", function()
  local saved, originalThemes, savedTheme

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  before_each(function()
    saved = {}
    originalThemes = sonata.themes
    sonata.themes = {}
    sonata:Init()
    -- The real Base: the pane draws its text with Base's text roles.
    assert(loadfile("sonata/themes/base.lua"))("BetterBags")
    sonata:RegisterTheme({ Name = "Default", DisplayName = "Default", Description = "The default theme." })
    sonata:RegisterTheme({ Name = "SimpleDark", DisplayName = "Simple Dark", Description = "A simple dark theme." })
    sonata:RegisterTheme({ Name = "elvui", DisplayName = "ElvUI", Available = function() return false end })
    savedTheme = "Default"
    override(db, "GetTheme", function() return savedTheme end)
    override(db, "SetTheme", function(_, key) savedTheme = key end)
    override(events, "SendMessage", function() end)
    override(list, "Create", function(_, parent)
      local l = { frame = CreateFrame("Frame", nil, parent), items = {} }
      l.ScrollBox = { ForEachFrame = function() end }
      function l:SetupDataSource() end
      function l:Wipe() self.items = {} end
      function l:AddToEnd(data) table.insert(self.items, data) end
      function l:AddToStart(data) table.insert(self.items, 1, data) end
      return l
    end)
    sonata:ApplyTheme(context:New("spec"), "Default")
  end)

  after_each(function()
    sonata.themes = originalThemes
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
  end)

  teardown(function()
    ResetModuleStub("ThemePane", "config/themepane.lua")
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  local function newPane()
    return themePane:New(CreateFrame("Frame", nil, UIParent))
  end

  it("lists every theme Sonata knows by its name, in order, those it cannot use too", function()
    local pane = newPane()
    pane:RefreshList()
    local names = {}
    for _, entry in ipairs(pane.listFrame.items) do
      table.insert(names, entry.name)
    end
    assert.are.same({ "Default", "ElvUI", "Simple Dark" }, names)
    local byKey = {}
    for _, entry in ipairs(pane.listFrame.items) do byKey[entry.key] = entry end
    assert.is_true(byKey.Default.active)
    assert.is_false(byKey.SimpleDark.active)
    assert.is_true(byKey.SimpleDark.available)
    assert.is_false(byKey.elvui.available)
    assert.are.equal("A simple dark theme.", byKey.SimpleDark.description)
  end)

  it("shows whether a theme is applied, available or not", function()
    local pane = newPane()
    -- The status is drawn with a text role, so a theme can color it.
    for key, expected in pairs({
      Default = { "Currently Active", false, "Active", "Positive" },
      SimpleDark = { "Previewing", true, "Apply Theme", "Description" },
      elvui = { "Unavailable", false, "Unavailable", "Negative" },
    }) do
      pane:SelectTheme(key)
      local detail = pane.themeDetail
      assert.are.equal(expected[1], detail.statusLabel:GetText(), key)
      assert.are.equal(expected[2], detail.applyButton:IsEnabled(), key)
      assert.are.equal(expected[3], detail.applyButton:GetText(), key)
      assert.are.equal(sonata:GetTextFont(expected[4]), detail.statusLabel:GetFontObject(), key)
      assert.is_nil(detail.statusLabel._textColor, key)
    end
    pane:SelectTheme("SimpleDark")
    assert.are.equal("Simple Dark", pane.themeDetail.nameLabel:GetText())
  end)

  it("applies the chosen theme through Sonata, and then shows it applied", function()
    local pane = newPane()
    pane:RefreshList()
    pane:SelectTheme("SimpleDark")
    pane.themeDetail.applyButton:GetScript("OnClick")(pane.themeDetail.applyButton, "LeftButton")
    assert.are.equal("SimpleDark", sonata:GetCurrentThemeKey())
    assert.are.equal("SimpleDark", savedTheme)
    assert.are.equal("Currently Active", pane.themeDetail.statusLabel:GetText())
    for _, entry in ipairs(pane.listFrame.items) do
      assert.are.equal(entry.key == "SimpleDark", entry.active, entry.key)
    end
  end)

  -- Picking a theme previews it on the next frame (applying restyles and resizes the settings
  -- window, which must not happen inside the click on the list); only Apply saves it. Leaving
  -- the pane (another settings page, or closing the settings window, both hide it) puts the
  -- saved theme back.
  describe("previewing", function()
    local queued

    before_each(function()
      queued = {}
      override(_G.C_Timer, "After", function(_, fn) table.insert(queued, fn) end)
    end)

    -- nextFrame runs what was waiting for the next frame; what that schedules waits for the one after.
    local function nextFrame()
      local due = queued
      queued = {}
      for _, fn in ipairs(due) do fn() end
    end

    local function hide(pane)
      pane.frame:GetScript("OnHide")(pane.frame)
    end

    local function countApplies()
      local count = { n = 0 }
      local originalApply = sonata.ApplyTheme
      override(sonata, "ApplyTheme", function(...)
        count.n = count.n + 1
        return originalApply(...)
      end)
      return count
    end

    it("applies a picked theme on the next frame, not in the click, without saving it", function()
      local pane = newPane()
      pane:RefreshList()
      pane:SelectTheme("SimpleDark")
      assert.are.equal("Default", sonata:GetCurrentThemeKey())
      assert.are.equal("Previewing", pane.themeDetail.statusLabel:GetText())
      nextFrame()
      assert.are.equal("SimpleDark", sonata:GetCurrentThemeKey())
      assert.are.equal("Default", savedTheme)
      for _, entry in ipairs(themePane:Entries()) do
        assert.are.equal(entry.key == "Default", entry.active, entry.key)
      end
    end)

    it("previews only the last theme picked before the frame passes, once", function()
      local pane = newPane()
      local applies = countApplies()
      pane:SelectTheme("SimpleDark")
      pane:SelectTheme("Default")
      assert.are.equal(1, #queued)
      nextFrame()
      assert.are.equal("Default", sonata:GetCurrentThemeKey())
      assert.are.equal(0, applies.n)
      pane:SelectTheme("Default")
      pane:SelectTheme("SimpleDark")
      nextFrame()
      assert.are.equal("SimpleDark", sonata:GetCurrentThemeKey())
      assert.are.equal(1, applies.n)
    end)

    it("saves the previewed theme when Apply is pressed, and keeps it after leaving", function()
      local pane = newPane()
      pane:SelectTheme("SimpleDark")
      nextFrame()
      pane.themeDetail.applyButton:GetScript("OnClick")(pane.themeDetail.applyButton, "LeftButton")
      assert.are.equal("SimpleDark", savedTheme)
      hide(pane)
      assert.are.equal("SimpleDark", sonata:GetCurrentThemeKey())
    end)

    it("puts the saved theme back when the pane hides, and forgets the pick", function()
      local pane = newPane()
      pane.frame:GetScript("OnShow")(pane.frame)
      nextFrame()
      pane:SelectTheme("SimpleDark")
      nextFrame()
      hide(pane)
      assert.are.equal("Default", sonata:GetCurrentThemeKey())
      assert.are.equal("Default", savedTheme)
      assert.is_nil(pane.selectedTheme)
      assert.is_true(pane.emptyDetail:IsShown())
    end)

    it("previews nothing when the pane hides before the frame passes", function()
      local pane = newPane()
      local applies = countApplies()
      pane:SelectTheme("SimpleDark")
      hide(pane)
      nextFrame()
      assert.are.equal("Default", sonata:GetCurrentThemeKey())
      assert.are.equal(0, applies.n)
    end)

    it("shows the saved theme while an unavailable theme or the saved one is picked", function()
      local pane = newPane()
      pane:SelectTheme("SimpleDark")
      nextFrame()
      pane:SelectTheme("elvui")
      nextFrame()
      assert.are.equal("Default", sonata:GetCurrentThemeKey())
      pane:SelectTheme("SimpleDark")
      nextFrame()
      pane:SelectTheme("Default")
      nextFrame()
      assert.are.equal("Default", sonata:GetCurrentThemeKey())
    end)

    it("applies nothing when the pane hides without a preview, or a picked theme twice", function()
      local pane = newPane()
      local applies = countApplies()
      hide(pane)
      pane:SelectTheme("SimpleDark")
      nextFrame()
      pane:SelectTheme("SimpleDark")
      nextFrame()
      assert.are.equal(1, applies.n)
    end)
  end)

  it("marks the theme applied, not a saved theme that is not loaded", function()
    savedTheme = "elvui"
    local pane = newPane()
    pane:RefreshList()
    for _, entry in ipairs(pane.listFrame.items) do
      assert.are.equal(entry.key == "Default", entry.active, entry.key)
    end
  end)

  -- BetterBags Next's themes (next-themes.md) are picked the same way, in their own pane over
  -- SonataNext: listed by name, previewed on the next frame without saving, saved by Apply, the
  -- saved one put back when the pane hides.
  describe("BetterBags Next's themes", function()
    local sonataNext, savedNext, queued

    before_each(function()
      sonataNext = FreshNextThemes()
      -- SonataNext hands every theme to Next's style.
      ResetModuleStub("NextStyle", "next/style.lua")
      LoadBetterBagsModule("next/style.lua")
      sonataNext:RegisterTheme({ Name = "Sunset", DisplayName = "Sunset", Description = "Warm." })
      sonataNext:RegisterTheme({ Name = "Elvish", DisplayName = "Elvish", Requires = { "ElvUI" } })
      savedNext = "Default"
      override(db, "GetNextTheme", function() return savedNext end)
      override(db, "SetNextTheme", function(_, key) savedNext = key end)
      sonataNext:Init()
      queued = {}
      override(_G.C_Timer, "After", function(_, fn) table.insert(queued, fn) end)
    end)

    teardown(function()
      FreshNextThemes()
    end)

    local function nextFrame()
      local due = queued
      queued = {}
      for _, fn in ipairs(due) do fn() end
    end

    local function nextPane()
      return themePane:New(CreateFrame("Frame", nil, UIParent), sonataNext)
    end

    it("lists Next's themes, not the bags' themes, those it cannot use too", function()
      local pane = nextPane()
      pane:RefreshList()
      local byKey, names = {}, {}
      for _, entry in ipairs(pane.listFrame.items) do
        byKey[entry.key] = entry
        table.insert(names, entry.name)
      end
      -- BetterBags' own Next themes are listed too (sonata/themes/next).
      assert.are.same({ "Default", "Elvish", "Ember", "Parchment", "Quiet", "Sunset" }, names)
      assert.is_true(byKey.Default.active)
      assert.is_false(byKey.Elvish.available)
      assert.are.equal("Warm.", byKey.Sunset.description)
    end)

    it("previews a picked theme on the next frame without saving it, and Apply saves it", function()
      local pane = nextPane()
      pane:SelectTheme("Sunset")
      assert.are.equal("Default", sonataNext:GetCurrentThemeKey())
      nextFrame()
      assert.are.equal("Sunset", sonataNext:GetCurrentThemeKey())
      assert.are.equal("Default", savedNext)
      assert.are.equal("Default", sonata:GetCurrentThemeKey(), "the bags' theme is left alone")
      pane.themeDetail.applyButton:GetScript("OnClick")(pane.themeDetail.applyButton, "LeftButton")
      assert.are.equal("Sunset", savedNext)
      assert.are.equal("Currently Active", pane.themeDetail.statusLabel:GetText())
    end)

    it("puts the saved theme back when the pane hides", function()
      local pane = nextPane()
      pane:SelectTheme("Sunset")
      nextFrame()
      pane.frame:GetScript("OnHide")(pane.frame)
      assert.are.equal("Default", sonataNext:GetCurrentThemeKey())
      assert.are.equal("Default", savedNext)
    end)

    it("shows a theme whose addon is not loaded as unavailable, and previews the saved one", function()
      local pane = nextPane()
      pane:SelectTheme("Elvish")
      assert.are.equal("Unavailable", pane.themeDetail.statusLabel:GetText())
      nextFrame()
      assert.are.equal("Default", sonataNext:GetCurrentThemeKey())
    end)
  end)
end)
