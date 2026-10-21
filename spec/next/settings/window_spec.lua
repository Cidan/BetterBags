-- window_spec.lua -- NextSettings and NextSettingsPages (next/settings/window.lua, pages.lua): BetterBags
-- Next's settings window (next-settings.md §3), on pages registered for the spec: the sidebar of
-- pages under their headings with its search box, a page's header and tabs, its sections scrolling
-- in the content, the footer, search, Escape and a theme.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("render/render.lua")
LoadBetterBagsModule("render/drawable.lua")
LoadBetterBagsModule("render/scrollbox.lua")
local L = StubBetterBagsModule("Localization")
L.G = L.G or function(_, key) return key end
local events = StubBetterBagsModule("Events")
StubBetterBagsModule("SettingsCatalog")
local bagSystem = StubBetterBagsModule("BagSystem")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" },
  { "NextButton", "next/controls/button.lua" }, { "NextToggle", "next/controls/toggle.lua" },
  { "NextInput", "next/controls/input.lua" }, { "NextSlider", "next/controls/slider.lua" },
  { "NextMenu", "next/controls/menu.lua" }, { "NextDropdown", "next/controls/dropdown.lua" },
  { "NextSwatch", "next/controls/swatch.lua" }, { "NextTopTabs", "next/controls/toptabs.lua" },
  { "NextDialog", "next/controls/dialog.lua" }, { "NextSettingsRows", "next/settings/rows.lua" },
  { "NextSettingsPage", "next/settings/page.lua" }, { "NextSettingsPages", "next/settings/pages.lua" },
  { "NextSettings", "next/settings/window.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local settings = addon:GetModule("NextSettings")
local pages = addon:GetModule("NextSettingsPages")
local nextMenu = addon:GetModule("NextMenu")
local nextDialog = addon:GetModule("NextDialog")
local controls = addon:GetModule("NextControls")
local render = addon:GetModule("Render")
local tween = addon:GetModule("NextTween")
local style = addon:GetModule("NextStyle")

local function S()
  return style.Theme.Settings
end

describe("NextSettings", function()
  local values, sent, saved, timers, design

  local function toggle(title, key, description, keywords)
    return {
      option = {
        kind = "toggle", title = title, description = description or "", keywords = keywords,
        get = function() return values[key] end,
        set = function(_, v) values[key] = v end,
      },
    }
  end

  local function define()
    pages:Clear()
    pages:Define({
      id = "general", group = "BetterBags", title = "General", description = "How BetterBags works.",
      tabs = { { id = "main", title = "General", sections = {
        { title = "Bags", rows = { toggle("Enable Bank Bags", "bank", "Use BetterBags at the bank."),
          toggle("Show Blizzard Bag Button", "button") } },
        { title = "Search", rows = { toggle("Enable In-Bag Search", "search", "A search bar in your bags.") } },
      } } },
    })
    pages:Define({
      id = "backpack", group = "Bags", title = "Backpack", description = "How the backpack shows its items.",
      tabs = {
        { id = "layout", title = "Layout", sections = {
          { title = "Slots", rows = { toggle("Show All Free Space Slots", "free", "Every free slot by itself.") } },
        } },
        { id = "items", title = "Items", sections = {
          { title = "Stacking", rows = { toggle("Merge Stacks", "merge", "Stackable items merge.", { "combine" }) } },
        } },
      },
    })
    pages:Define({
      id = "hidden", group = "Bags", title = "Guild Bank", description = "",
      shown = function() return false end,
      tabs = { { id = "main", title = "Guild Bank", sections = {} } },
    })
    pages:Define({
      id = "profiles", group = "Profiles", title = "Profiles", description = "Settings saved under a name.",
      tabs = { { id = "main", title = "Profiles", sections = {
        { title = "Text", rows = { { text = "Profiles are shared." } } },
      } } },
    })
  end

  local function open(...)
    settings:Open(...)
    return settings.frame
  end

  local function navRow(title)
    for _, row in ipairs(settings.navRows) do
      if row.page and row.page.title == title then return row end
    end
  end

  local function shownRows()
    local titles = {}
    for _, section in ipairs(settings.page.sections) do
      for _, row in ipairs(section.rows) do
        if row.label then table.insert(titles, row.label:GetText()) end
      end
    end
    return titles
  end

  before_each(function()
    values = { bank = true, button = false, search = true, free = false, merge = true }
    sent = {}
    timers = {}
    saved = { _G.UISpecialFrames, C_Timer.After, events.SendMessage, bagSystem.ActiveDesign }
    design = "next"
    bagSystem.ActiveDesign = function() return design end
    _G.UISpecialFrames = {}
    C_Timer.After = function(_, fn) table.insert(timers, fn) end
    events.SendMessage = function(_, _, message, ...) table.insert(sent, { message, ... }) end
    controls.escape = {}
    render:Init()
    tween:Init()
    define()
    settings:Init()
  end)

  after_each(function()
    if settings.frame then settings:Close() end
    nextMenu:Close()
    nextDialog:Hide()
    _G.UISpecialFrames, C_Timer.After, events.SendMessage, bagSystem.ActiveDesign = saved[1], saved[2], saved[3], saved[4]
    UseNextTheme(nil)
  end)

  teardown(function()
    ResetModuleStub("SettingsCatalog")
    pages:Clear()
  end)

  describe("its window", function()
    it("is built the first time it opens, named, over the bags, centered, the theme's size", function()
      assert.is_nil(settings.frame)
      local frame = open()
      assert.are.equal("BetterBagsNextSettings", frame:GetName())
      assert.is_true(frame:IsShown())
      assert.are.equal("DIALOG", frame:GetFrameStrata())
      assert.is_true(frame:IsToplevel())
      assert.is_true(frame:IsClampedToScreen())
      assert.are.same({ S().Width, S().Height }, { frame:GetSize() })
      tween:Step(1)
      assert.are.same({ "CENTER", UIParent, "CENTER", 0, 0 }, { frame:GetPoint(1) }, "once it has slid in")
    end)

    it("draws its body, the wash at its top and its edge from the theme", function()
      open()
      local r, g, b, a = style:RGBA("Body")
      assert.are.same({ r = r, g = g, b = b, a = a }, settings.fill._colorTexture)
      assert.are.equal(S().Wash.Height, settings.wash:GetHeight())
      assert.are.equal("VERTICAL", settings.wash._gradient.orientation)
      assert.are.equal(S().Edge.Alpha, settings.edge.Top._colorTexture.a)
    end)

    it("moves when its header is dragged", function()
      local frame = open()
      assert.is_true(frame:IsMovable())
      settings.header:GetScript("OnDragStart")(settings.header)
      assert.is_true(frame._moving)
      settings.header:GetScript("OnDragStop")(settings.header)
      assert.is_false(frame._moving)
    end)

    it("shrinks to fit a small screen, never below its own size's share", function()
      local savedH = UIParent:GetHeight()
      UIParent:SetHeight(600)
      local frame = open()
      assert.is_true(frame:GetScale() < 1)
      assert.is_true(S().Height * frame:GetScale() <= 600 * 0.95 + 0.01)
      UIParent:SetHeight(savedH)
      settings:Close()
      tween:Step(1)
      open()
      assert.are.equal(1, frame:GetScale())
    end)

    it("closes with its close button and with Done, and Escape closes it", function()
      local frame = open()
      assert.are.same({ "BetterBagsNextSettings" }, UISpecialFrames)
      settings.closeButton:GetScript("OnClick")(settings.closeButton, "LeftButton")
      tween:Step(1)
      assert.is_false(frame:IsShown())
      for _, fn in ipairs(timers) do fn() end
      assert.are.same({}, UISpecialFrames)
      open()
      settings.done.frame:GetScript("OnClick")(settings.done.frame, "LeftButton")
      tween:Step(1)
      assert.is_false(frame:IsShown())
    end)

    -- Asked: it comes and goes as a detached (small) bag does: sliding Small.Slide in from its side as
    -- it fades in, over Time.Open with the SmallOpen ease, and out over Time.Close with SmallClose.
    describe("coming and going", function()
      local function x(frame)
        local _, _, _, ox = frame:GetPoint(1)
        return ox
      end

      it("fades in sliding from the right, as a detached bag does", function()
        local frame = open()
        assert.are.equal(0, frame:GetAlpha())
        assert.are.equal(style.Small.Slide, x(frame))
        tween:Step(style.Time.Open / 2)
        assert.is_true(frame:GetAlpha() > 0 and frame:GetAlpha() < 1)
        assert.is_true(x(frame) > 0 and x(frame) < style.Small.Slide)
        tween:Step(style.Time.Open)
        assert.are.equal(1, frame:GetAlpha())
        assert.are.same({ "CENTER", UIParent, "CENTER", 0, 0 }, { frame:GetPoint(1) })
      end)

      it("fades out sliding right, then hides; it is closed from the start", function()
        local frame = open()
        tween:Step(1)
        settings:Close()
        assert.is_false(settings:IsShown())
        assert.is_true(frame:IsShown(), "still fading out")
        tween:Step(style.Time.Close / 2)
        assert.is_true(frame:GetAlpha() < 1 and x(frame) > 0)
        tween:Step(style.Time.Close)
        assert.is_false(frame:IsShown())
        assert.are.equal(1, frame:GetAlpha(), "ready for the next time")
        for _, fn in ipairs(timers) do fn() end
        assert.are.same({}, UISpecialFrames)
      end)

      it("fades out from where it was moved to", function()
        local frame = open()
        tween:Step(1)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 100, 700)
        settings:Close()
        tween:Step(style.Time.Close / 2)
        local point, _, _, ox, oy = frame:GetPoint(1)
        assert.are.equal("TOPLEFT", point)
        assert.is_true(ox > 100 and oy == 700)
      end)

      it("comes back from where it is when opened again while fading out", function()
        local frame = open()
        tween:Step(1)
        settings:Close()
        tween:Step(style.Time.Close / 2)
        local before, alpha = x(frame), frame:GetAlpha()
        open()
        assert.are.equal(before, x(frame), "no jump")
        assert.are.equal(alpha, frame:GetAlpha())
        assert.is_true(settings:IsShown())
        tween:Step(1)
        assert.is_true(frame:IsShown())
        assert.are.equal(1, frame:GetAlpha())
        assert.are.equal(0, x(frame))
      end)

      it("settles into place when dragged while it slides in, and moves from there", function()
        local frame = open()
        tween:Step(style.Time.Open / 3)
        settings.header:GetScript("OnDragStart")(settings.header)
        assert.is_false(tween:IsPlaying(settings.motion))
        assert.are.equal(1, frame:GetAlpha())
        assert.are.equal(0, x(frame))
        assert.is_true(frame._moving)
      end)

      it("closes at once on Escape, as a bag does, and fades in again the next time", function()
        local frame = open()
        tween:Step(style.Time.Open / 2)
        frame:Hide()
        frame:GetScript("OnHide")(frame)
        assert.is_false(settings:IsShown())
        assert.are.equal(1, frame:GetAlpha())
        assert.is_false(tween:IsPlaying(settings.motion), "its slide stops")
        tween:Step(1)
        assert.is_false(frame:IsShown(), "nothing shows it again")
        assert.are.equal(1, frame:GetAlpha())
        open()
        assert.are.equal(0, frame:GetAlpha())
      end)
    end)

    it("closes the menu and the dialog open over it as it closes", function()
      open()
      nextDialog:Show(settings.frame, { title = "T", text = "x", buttons = { { text = "OK", onClick = function() end } } })
      settings:Close()
      assert.is_false(nextDialog:IsShown())
    end)

    -- render-recorder.md §2: while rendering is recorded, each page shown is snapshotted.
    it("gives the render recorder the window each time it shows a page, while it records", function()
      local recorder = addon:GetModule("RenderRecorder", true) or StubBetterBagsModule("RenderRecorder")
      local savedRecording, savedRendered = rawget(recorder, "recording"), rawget(recorder, "SettingsRendered")
      local given = {}
      recorder.SettingsRendered = function(_, frame) table.insert(given, frame) end
      recorder.recording = false
      open()
      assert.are.same({}, given, "not while stopped")
      recorder.recording = true
      settings:Select("backpack")
      settings:Select("backpack", "items")
      recorder.recording, recorder.SettingsRendered = savedRecording, savedRendered
      assert.are.same({ settings.frame, settings.frame }, given)
    end)

    it("opens the changelog from What's New", function()
      open()
      settings.whatsNew.frame:GetScript("OnClick")(settings.whatsNew.frame, "LeftButton")
      assert.are.equal("changelog/Open", sent[1][1])
    end)
  end)

  describe("its sidebar", function()
    it("has the brand, the search box and the version", function()
      open()
      assert.are.equal(S().Sidebar.Width, settings.sidebar:GetWidth())
      assert.are.equal("BetterBags", settings.brandText:GetText())
      assert.are.equal(style:Font(S().Brand.Font), settings.brandText:GetFontObject())
      assert.are.equal(style.Theme.Textures.IconBags, settings.brandIcon:GetTexture())
      assert.are.equal("Search settings", settings.search.help:GetText())
      assert.is_true(settings.version:GetText():find("^v") ~= nil or settings.version:GetText() == "")
    end)

    -- Seen in game after changing themes: the help text over the magnifier. A theme restyles every
    -- widget in no set order, and the text fields put back the room the window had made for it.
    it("keeps its search box's text clear of the magnifier, whatever restyles last", function()
      open()
      local I, SR = style.Theme.Controls.Input, style.Theme.Settings.Search
      local left = I.Padding + SR.IconSize + I.Padding / 2
      local function check()
        assert.are.same({ left, I.Padding, 0, 0 }, { settings.search.frame:GetTextInsets() })
        assert.are.same({ "LEFT", settings.search.frame, "LEFT", left, 0 }, { settings.search.help:GetPoint(1) })
        assert.are.equal(style.Theme.Textures[SR.Icon], settings.search.icon:GetTexture())
        assert.are.same({ "LEFT", settings.search.frame, "LEFT", I.Padding, 0 }, { settings.search.icon:GetPoint(1) })
      end
      check()
      settings:ApplyStyle()
      addon:GetModule("NextInput"):ApplyStyle()
      check()
    end)

    it("lists the pages shown under their headings, in order, the first one chosen", function()
      open()
      local seen = {}
      for _, row in ipairs(settings.navRows) do
        if row.frame:IsShown() then
          table.insert(seen, row.group and ("# " .. row.group) or row.page.title)
        end
      end
      assert.are.same({ "# BetterBags", "General", "# Bags", "Backpack", "# Profiles", "Profiles" }, seen)
      local general = navRow("General")
      assert.are.equal(style:Font(S().Nav.SelectedFont), general.label:GetFontObject())
      assert.is_true(general.indicator:IsShown())
      assert.is_false(navRow("Backpack").indicator:IsShown())
    end)

    it("shows a page when its entry is clicked, its header and its sections", function()
      open()
      local backpack = navRow("Backpack")
      backpack.frame:GetScript("OnClick")(backpack.frame, "LeftButton")
      assert.are.equal("backpack", settings.pageId)
      assert.are.equal("Backpack", settings.title:GetText())
      assert.are.equal("How the backpack shows its items.", settings.description:GetText())
      assert.are.same({ "Show All Free Space Slots" }, shownRows())
      assert.is_true(backpack.indicator:IsShown())
      assert.is_false(navRow("General").indicator:IsShown())
    end)

    it("lights an entry under the pointer", function()
      open()
      local row = navRow("Backpack")
      row.frame:GetScript("OnEnter")(row.frame)
      assert.is_true(row.hover:IsShown())
      assert.are.equal(style:Font(S().Nav.HoverFont), row.label:GetFontObject())
      row.frame:GetScript("OnLeave")(row.frame)
      assert.is_false(row.hover:IsShown())
    end)

    it("lists a page newly defined the next time it opens", function()
      open()
      settings:Close()
      pages:Define({ id = "plugin", group = "Plugins", title = "Some Plugin", description = "",
        tabs = { { id = "main", title = "Some Plugin", sections = {} } } })
      open()
      assert.is_not_nil(navRow("Some Plugin"))
    end)
  end)

  describe("a page", function()
    it("shows tabs across its top only when it has more than one, the first chosen", function()
      open()
      assert.is_false(settings.tabs.frame:IsShown())
      open("backpack")
      assert.is_true(settings.tabs.frame:IsShown())
      assert.are.equal("layout", settings.tabs:GetSelected())
      settings.tabs.tabs[2].frame:GetScript("OnClick")(settings.tabs.tabs[2].frame, "LeftButton")
      assert.are.equal("items", settings.tabId)
      assert.are.same({ "Merge Stacks" }, shownRows())
    end)

    it("scrolls its sections in the content, with BetterBags Next's scroll bar", function()
      open()
      assert.are.equal(settings.page, settings.scroll:GetChild())
      assert.is_not_nil(settings.scroll.bar)
      assert.are.same({ "Enable Bank Bags", "Show Blizzard Bag Button", "Enable In-Bag Search" }, shownRows())
      assert.are.equal(S().Sidebar.Width, select(4, settings.scroll.frame:GetPoint(1)))
    end)

    it("shows the page and tab it showed last, or the one asked for", function()
      open("backpack", "items")
      assert.are.equal("items", settings.tabId)
      settings:Close()
      open()
      assert.are.equal("backpack", settings.pageId)
      assert.are.equal("items", settings.tabId)
      settings:Close()
      open("profiles")
      assert.are.equal("profiles", settings.pageId)
    end)

    it("shows every setting's value again when it opens", function()
      open()
      settings:Close()
      values.bank = false
      open()
      assert.is_false(settings.page.sections[1].rows[1].control:GetChecked())
    end)

    it("tells the page it leaves, for another page or when it closes", function()
      local left = {}
      pages:Define({ id = "appearance", group = "BetterBags", title = "Appearance", description = "",
        tabs = { { id = "main", title = "Appearance", sections = { { title = "Themes", rows = {
          { block = function(parent)
            local row = addon:GetModule("NextSettingsRows"):CreateText(parent, "themes")
            function row:OnPageLeft() table.insert(left, "left") end
            return row
          end, title = "Theme" },
        } } } } } })
      open("appearance")
      open("general")
      assert.are.same({ "left" }, left)
      open("appearance")
      settings:Close()
      assert.are.same({ "left", "left" }, left)
    end)

    it("shows the page's values again when told", function()
      open()
      values.bank = false
      settings:Refresh()
      assert.is_false(settings.page.sections[1].rows[1].control:GetChecked())
    end)

    it("leaves out a section with no rows (a bag without the setting)", function()
      pages:Define({ id = "empty", group = "Bags", title = "Empty", description = "",
        tabs = { { id = "main", title = "Empty", sections = {
          { title = "Nothing", rows = {} },
          { title = "Something", rows = { toggle("Something", "bank") } },
        } } } })
      open("empty")
      assert.are.equal(1, #settings.page.sections)
      assert.are.equal("Something", settings.page.sections[1].title)
    end)

    it("forgets the page of a window from an earlier session", function()
      local left = 0
      pages:Define({ id = "leaving", group = "Bags", title = "Leaving", description = "",
        tabs = { { id = "main", title = "Leaving", sections = { { title = "S", rows = {
          { block = function(parent)
            local row = addon:GetModule("NextSettingsRows"):CreateText(parent, "x")
            function row:OnPageLeft() left = left + 1 end
            return row
          end, title = "x" },
        } } } } } })
      open("leaving")
      settings:Close()
      settings:Init()
      open("general")
      assert.are.equal(1, left, "only the close left it")
    end)

    it("shows General for a page that is not shown", function()
      open("hidden")
      assert.are.equal("general", settings.pageId)
    end)
  end)

  describe("searching", function()
    local function search(text)
      settings.search.frame:SetText(text)
      settings.search.frame:GetScript("OnTextChanged")(settings.search.frame, true)
    end

    it("lists every setting that matches, live, under its page and tab", function()
      open()
      search("merge")
      assert.are.equal("Search", settings.title:GetText())
      assert.is_false(settings.tabs.frame:IsShown())
      local sections = settings.page.sections
      assert.are.equal(1, #sections)
      assert.are.equal("Backpack > Items", sections[1].title)
      assert.are.same({ "Merge Stacks" }, shownRows())
      local toggleRow = sections[1].rows[2]
      toggleRow.control.frame:GetScript("OnClick")(toggleRow.control.frame, "LeftButton")
      assert.is_false(values.merge, "changed from the results")
    end)

    it("matches names, descriptions and searching words, in any case", function()
      open()
      search("BAG")
      assert.are.same({ "Enable Bank Bags", "Show Blizzard Bag Button", "Enable In-Bag Search" }, shownRows())
      search("every free")
      assert.are.same({ "Show All Free Space Slots" }, shownRows())
      search("combine")
      assert.are.same({ "Merge Stacks" }, shownRows())
    end)

    it("goes to a result's page from its link, leaving the search", function()
      open()
      search("merge")
      local link = settings.page.sections[1].rows[1]
      link.button.frame:GetScript("OnClick")(link.button.frame, "LeftButton")
      assert.are.equal("backpack", settings.pageId)
      assert.are.equal("items", settings.tabId)
      assert.are.equal("", settings.search:GetText())
      assert.are.equal("Backpack", settings.title:GetText())
    end)

    it("says when nothing matches, and goes back to the page when cleared", function()
      open()
      search("zzz")
      assert.are.equal(0, #settings.page.sections)
      assert.is_true(settings.page.empty:IsShown())
      search("")
      assert.are.equal("General", settings.title:GetText())
      assert.are.same({ "Enable Bank Bags", "Show Blizzard Bag Button", "Enable In-Bag Search" }, shownRows())
    end)

    it("leaves out the pages that are not shown", function()
      pages:Define({ id = "secret", group = "Bags", title = "Secret", description = "",
        shown = function() return false end,
        tabs = { { id = "main", title = "Secret", sections = { { title = "S", rows = { toggle("Merge Secret", "x") } } } } } })
      open()
      search("merge")
      assert.are.equal(1, #settings.page.sections)
    end)
  end)

  -- The window shows what the bags in use read (next-settings.md §7): a page, section or row with a
  -- design shows only while that design is in use.
  -- A row or a section can be hidden while a function says so (a plugin's hidden, AceConfig): checked
  -- at every layout, and the window lays itself out again after every change on the page.
  describe("rows and sections hidden while a function says so", function()
    local hide

    local function laidOut()
      local list = {}
      for _, section in ipairs(settings.page.sections) do
        for _, row in ipairs(section.rows) do
          if row.frame:IsShown() then table.insert(list, row.label:GetText()) end
        end
      end
      return list
    end

    local function titles()
      local list = {}
      for _, title in ipairs(settings.page.titles) do
        if title:IsShown() then table.insert(list, title:GetText()) end
      end
      return list
    end

    before_each(function()
      hide = { row = true, section = false }
      local function sometimes(title, key)
        local row = toggle(title, key)
        row.hidden = function() return hide.row end
        return row
      end
      pages:Define({ id = "hiding", group = "Bags", title = "Hiding", description = "",
        tabs = { { id = "main", title = "Hiding", sections = {
          { title = "Shown", rows = { toggle("Always", "bank"), sometimes("Sometimes", "free") } },
          { title = "Maybe", hidden = function() return hide.section end, rows = { toggle("In Maybe", "merge") } },
          { title = "Only Hidden", rows = { sometimes("Alone", "search") } },
        } } } })
    end)

    it("leaves out a hidden row, and shows it once a refresh finds it shown", function()
      open("hiding")
      assert.are.same({ "Always", "In Maybe" }, laidOut())
      hide.row = false
      settings:Refresh()
      render:Flush()
      assert.are.same({ "Always", "Sometimes", "In Maybe", "Alone" }, laidOut())
    end)

    it("leaves out a hidden section, title and all, and one whose rows are all hidden", function()
      open("hiding")
      assert.are.same({ "SHOWN", "MAYBE" }, titles())
      hide.section = true
      settings:Refresh()
      render:Flush()
      assert.are.same({ "SHOWN" }, titles())
      assert.are.same({ "Always" }, laidOut())
    end)

    it("can hide a section's title alone, keeping its rows", function()
      pages:Define({ id = "untitled", group = "Bags", title = "Untitled", description = "",
        tabs = { { id = "main", title = "Untitled", sections = {
          { title = "First", rows = { toggle("Top", "bank") } },
          { title = "Quiet", titleHidden = function() return hide.row end, rows = { toggle("Under", "merge") } },
        } } } })
      local function under()
        local _, _, _, _, y = settings.page.sections[2].rows[1].frame:GetPoint(1)
        return y
      end
      open("untitled")
      assert.are.same({ "FIRST" }, titles())
      assert.are.same({ "Top", "Under" }, laidOut())
      local without = under()
      hide.row = false
      settings:Refresh()
      render:Flush()
      assert.are.same({ "FIRST", "QUIET" }, titles())
      assert.are.equal(style.Theme.Settings.Content.TitleHeight, without - under(), "no room kept for a hidden title")
    end)

    it("finds no hidden row", function()
      open("hiding")
      settings:Search(addon:GetModule("Context"):New("spec"), "sometimes")
      assert.are.same({}, shownRows())
      hide.row = false
      settings:Search(addon:GetModule("Context"):New("spec"), "sometimes")
      assert.are.same({ "Sometimes" }, shownRows())
      hide.section = true
      settings:Search(addon:GetModule("Context"):New("spec"), "in maybe")
      assert.are.same({}, shownRows(), "nor a row of a hidden section")
    end)
  end)

  describe("by design", function()
    local function only(d, def)
      def.design = d
      return def
    end

    before_each(function()
      pages:Define({ id = "nextonly", group = "Bags", title = "Next Only", description = "", design = "next",
        tabs = { { id = "main", title = "Next Only", sections = { { title = "N", rows = { toggle("Next Thing", "bank") } } } } } })
      pages:Define({ id = "mixed", group = "Bags", title = "Mixed", description = "",
        tabs = { { id = "main", title = "Mixed", sections = {
          { title = "Both", rows = { toggle("Both Thing", "bank"), only("classic", toggle("Classic Row", "button")) } },
          only("classic", { title = "Classic Section", rows = { toggle("Classic Thing", "search") } }),
        } } } })
    end)

    it("shows a page, section or row only while its design is in use", function()
      open()
      assert.is_not_nil(navRow("Next Only"))
      open("mixed")
      assert.are.same({ "Both Thing" }, shownRows())
      settings:Close()
      tween:Step(1)
      design = "classic"
      open()
      assert.is_nil(navRow("Next Only"))
      open("mixed")
      assert.are.same({ "Both Thing", "Classic Row", "Classic Thing" }, shownRows())
    end)

    it("shows the settings of the design the bags switch to, staying open", function()
      open("nextonly")
      design = "classic"
      settings:OnDesignChanged(addon:GetModule("Context"):New("spec"))
      assert.is_true(settings:IsShown())
      assert.are.equal("general", settings.pageId, "its page is gone: the first page")
      assert.is_nil(navRow("Next Only"))
      open("mixed")
      assert.are.same({ "Both Thing", "Classic Row", "Classic Thing" }, shownRows())
      design = "next"
      settings:OnDesignChanged(addon:GetModule("Context"):New("spec"))
      assert.are.equal("mixed", settings.pageId, "a page both designs have stays")
      assert.are.same({ "Both Thing" }, shownRows())
    end)

    it("does nothing for a switch while it is closed", function()
      open("mixed")
      settings:Close()
      tween:Step(1)
      local page = settings.page
      design = "classic"
      settings:OnDesignChanged(addon:GetModule("Context"):New("spec"))
      assert.is_false(settings.frame:IsShown())
      assert.are.equal(page, settings.page, "no page built for a closed window")
    end)

    it("finds only the settings of the design in use", function()
      open()
      settings:Search(addon:GetModule("Context"):New("spec"), "thing")
      assert.are.same({ "Next Thing", "Both Thing" }, shownRows())
      settings:Search(addon:GetModule("Context"):New("spec"), "row")
      assert.are.same({}, shownRows(), "a row of the other design")
      design = "classic"
      settings:Search(addon:GetModule("Context"):New("spec"), "thing")
      assert.are.same({ "Both Thing", "Classic Thing" }, shownRows())
      settings:Search(addon:GetModule("Context"):New("spec"), "row")
      assert.are.same({ "Classic Row" }, shownRows())
    end)
  end)

  describe("a theme", function()
    -- The shipped Parchment, applied through SonataNext as the Appearance page applies it.
    it("is restyled by a theme SonataNext applies, controls and all", function()
      local sonataNext = addon:GetModule("SonataNext")
      LoadBetterBagsModule("sonata/themes/next/parchment.lua")
      local db = StubBetterBagsModule("Database")
      local savedGet = db.GetNextTheme
      db.GetNextTheme = function() return "Default" end
      open()
      sonataNext:ApplyTheme(addon:GetModule("Context"):New("spec"), "Parchment", false)
      local paper = "Interface\\AddOns\\BetterBags\\textures\\moonlight\\parchment.png"
      assert.are.equal(paper, settings.fill:GetTexture())
      assert.is_false(settings.wash:IsShown())
      local r, g, b = style:RGBA("Seal")
      local edge = style.Theme.Controls.Button.Primary.Edge
      assert.are.equal("Seal", edge.Color)
      assert.are.same({ r = r, g = g, b = b, a = edge.Alpha }, settings.done.edge.Top._colorTexture, "its Done button sealed")
      sonataNext:ApplyTheme(addon:GetModule("Context"):New("spec"), "Default", false)
      db.GetNextTheme = savedGet
      assert.is_true(settings.wash:IsShown())
    end)

    it("restyles the window: its sizes, sidebar and fonts", function()
      open()
      UseNextTheme({ Settings = { Width = 900, Sidebar = { Width = 200 } } })
      settings:ApplyStyle()
      assert.are.equal(900, settings.frame:GetWidth())
      assert.are.equal(200, settings.sidebar:GetWidth())
      assert.are.equal(200, select(4, settings.scroll.frame:GetPoint(1)))
    end)
  end)
end)
