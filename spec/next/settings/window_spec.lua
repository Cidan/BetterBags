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
      assert.are.same({ 1000, 720 }, { S().Width, S().Height }, "asked: taller, for the Categories page")
      tween:Step(1)
      -- In the middle of the screen by its top left, on whole pixels (docs/next-pixel-perfect.md).
      assert.are.same({ "TOPLEFT", UIParent, "TOPLEFT", math.floor((UIParent:GetWidth() - S().Width) / 2),
        -math.floor((UIParent:GetHeight() - S().Height) / 2) }, { frame:GetPoint(1) }, "once it has slid in")
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
      -- x is how far right of where it rests the window is.
      local function x(frame)
        local _, _, _, ox = frame:GetPoint(1)
        return ox - settings.slideFrom[4]
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
        assert.are.equal(0, x(frame))
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

      -- The client leaves a moved frame wherever the pointer let go: it is put on whole pixels from there
      -- (docs/next-pixel-perfect.md), on the reporter's window at 65%.
      -- The check run in game from /bbdb (debug/pixelaudit.lua, next-pixel-perfect.md).
      it("registers with the pixel check run in game, and says it changed as it shows a page while it watches", function()
        local audit = addon:GetModule("PixelAudit")
        local frame = open()
        local w = audit:WindowOf(frame)
        assert.are.equal("Settings", w.title)
        assert.are.equal(settings, w.owners.settings)
        local changed = {}
        local savedChanged, savedWatching = rawget(audit, "Changed"), rawget(audit, "watching")
        finally(function() audit.Changed, audit.watching = savedChanged, savedWatching end)
        audit.Changed = function(_, root) table.insert(changed, root) end
        settings:Select("general")
        assert.are.same({}, changed, "off")
        audit.watching = true
        settings:Select("general")
        assert.are.same({ frame }, changed)
      end)

      it("lands on whole pixels where it was dropped after a drag", function()
        local layout = dofile("spec/helpers/layout.lua")
        local pixel = addon:GetModule("NextPixel")
        local undo = layout.UseScreen(3396, 1362, 0.65)
        local frame = open()
        finally(function()
          frame._rect = nil
          undo()
        end)
        tween:Step(1)
        settings.header:GetScript("OnDragStart")(settings.header)
        frame:_SetRect(301.37, 207.81, frame:GetWidth(), frame:GetHeight())
        settings.header:GetScript("OnDragStop")(settings.header)
        local point, relativeTo, relativePoint, ox, oy = frame:GetPoint(1)
        assert.are.same({ "TOPLEFT", UIParent, "TOPLEFT" }, { point, relativeTo, relativePoint })
        local unit = pixel:Unit(frame)
        assert.is_true(math.abs(ox / unit - math.floor(ox / unit + 0.5)) < 1e-6, "whole pixels across")
        assert.is_true(math.abs(oy / unit - math.floor(oy / unit + 0.5)) < 1e-6, "whole pixels down")
        assert.is_true(math.abs(ox - 301.37) <= unit / 2, "where it was dropped")
        local top = 207.81 + frame:GetHeight() - UIParent:GetTop()
        assert.is_true(math.abs(oy - top) <= unit / 2)
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
      -- By their top left, centered on the field's height by whole pixels (docs/next-pixel-perfect.md).
      local function down(height)
        return -math.floor((I.Height - height) / 2)
      end
      local function check()
        local insetLeft, insetRight = settings.search.frame:GetTextInsets()
        assert.are.same({ left, I.Padding }, { insetLeft, insetRight })
        local _, helpHeight = settings.search.help:GetFont()
        assert.are.same({ "TOPLEFT", settings.search.frame, "TOPLEFT", left, down(helpHeight) },
          { settings.search.help:GetPoint(1) })
        assert.are.equal(style.Theme.Textures[SR.Icon], settings.search.icon:GetTexture())
        assert.are.same({ "TOPLEFT", settings.search.frame, "TOPLEFT", I.Padding, down(SR.IconSize) },
          { settings.search.icon:GetPoint(1) })
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
  -- A page with its own list (pages.lua sidebar, next-settings.md §5): choosing it slides the pages
  -- out of the sidebar and its list in, Back on top; its heading and actions in the header; its tabs
  -- shown while they say so. Asked: the first Escape goes back, the next closes the window.
  describe("a page with its own list", function()
    local state, made

    before_each(function()
      state = { title = "Mats", description = "2 items", rule = false, refreshed = 0, actionsRefreshed = 0 }
      made = {}
      pages:Define({
        id = "cats", group = "BetterBags", title = "Categories", description = "Every category.",
        sidebar = function(parent, owner)
          local sb = { frame = CreateFrame("Frame", nil, parent), parent = parent, owner = owner }
          function sb:Place(w, h) self.placed = { w, h } end
          function sb:Refresh() state.refreshed = state.refreshed + 1 end
          table.insert(made, sb)
          return sb
        end,
        heading = function() return state.title, state.description end,
        actions = function(parent, owner)
          local a = { frame = CreateFrame("Frame", nil, parent), owner = owner }
          a.frame:SetSize(160, 28)
          function a:Refresh() state.actionsRefreshed = state.actionsRefreshed + 1 end
          state.actions = a
          return a
        end,
        tabs = {
          { id = "settings", title = "Settings", sections = { { title = "S", rows = { { text = "Its settings." } } } } },
          { id = "rule", title = "Rule", shown = function() return state.rule end,
            sections = { { title = "R", rows = { { text = "Its rule." } } } } },
          { id = "items", title = "Added Items", sections = { { title = "I", rows = { { text = "Its items." } } } } },
        },
      })
    end)

    local function tabTitles()
      local list = {}
      for _, t in ipairs(settings.tabs.list) do table.insert(list, t.text) end
      return list
    end

    local function settle()
      tween:Step(10)
    end

    it("slides the pages out and its list in when chosen, and back with Back", function()
      open()
      settle()
      local W = S().Sidebar.Width
      settings:Select("cats")
      assert.are.equal(pages:Get("cats"), settings.sidebarPage)
      assert.are.equal(1, #made, "its list, made once")
      assert.are.equal(settings.listHost, made[1].parent)
      assert.are.equal(settings.frame, made[1].owner)
      assert.are.same({ W, S().Height - S().Brand.Height }, made[1].placed)
      assert.is_true(state.refreshed > 0)
      assert.is_true(settings.sidebar:DoesClipChildren())
      tween:Step(style.Time.Interaction / 2)
      local _, _, _, navX = settings.navPanel:GetPoint(1)
      local _, _, _, listX = settings.listPanel:GetPoint(1)
      assert.is_true(navX < 0 and navX > -W, "the pages on their way out")
      assert.is_true(listX > 0 and listX < W, "its list on its way in")
      settle()
      assert.is_false(settings.navPanel:IsShown())
      assert.are.same({ "TOPLEFT", settings.sidebar, "TOPLEFT", 0, 0 }, { settings.listPanel:GetPoint(1) })
      assert.are.equal("All Settings", settings.backLabel:GetText())
      settings.back:GetScript("OnClick")(settings.back, "LeftButton")
      assert.is_nil(settings.sidebarPage)
      settle()
      assert.is_true(settings.navPanel:IsShown())
      assert.is_false(settings.listPanel:IsShown())
      assert.are.same({ "TOPLEFT", settings.sidebar, "TOPLEFT", 0, 0 }, { settings.navPanel:GetPoint(1) })
      settings:Select("cats")
      assert.are.equal(1, #made, "the same list the next time")
    end)

    it("goes back to the page and tab it came from, or the first page", function()
      open("backpack", "items")
      settings:Select("cats")
      settings:Back()
      assert.are.same({ "backpack", "items" }, { settings.pageId, settings.tabId })
      settings:Init()
      open("cats")
      settings:Back()
      assert.are.equal("general", settings.pageId)
    end)

    it("still goes back to where it came from after its list chose something else", function()
      open("backpack", "items")
      settings:Select("cats")
      settings:Reselect()
      settings:Select("cats", "items")
      settings:Back()
      assert.are.same({ "backpack", "items" }, { settings.pageId, settings.tabId })
    end)

    it("reads nothing again while closed", function()
      open()
      settings:Select("cats")
      settings:Close()
      tween:Step(10)
      local refreshed = state.refreshed
      settings:Reselect()
      assert.are.equal(refreshed, state.refreshed)
    end)

    it("opens straight on its list, without sliding", function()
      open("cats")
      assert.is_false(settings.navPanel:IsShown())
      assert.is_true(settings.listPanel:IsShown())
      assert.are.equal(1, settings.listPanel:GetAlpha())
    end)

    it("goes back on the first Escape, and closes the window on the next", function()
      open()
      settings:Select("cats")
      assert.are.same({ "BetterBagsNextSettingsBack" }, UISpecialFrames)
      local key = settings.backKey
      key:Hide()
      key:GetScript("OnHide")(key)
      assert.is_nil(settings.sidebarPage)
      assert.is_true(settings:IsShown())
      for _, fn in ipairs(timers) do fn() end
      assert.are.same({ "BetterBagsNextSettings" }, UISpecialFrames)
    end)

    it("gives Escape back when the window closes on its list, and takes it again when it opens there", function()
      open()
      settings:Select("cats")
      settings:Close()
      tween:Step(10)
      local key = settings.backKey
      key:GetScript("OnHide")(key)
      assert.are.equal(pages:Get("cats"), settings.sidebarPage, "closing is not going back")
      assert.is_false(key:IsShown(), "no hidden frame left to take Escape")
      for _, fn in ipairs(timers) do fn() end
      assert.are.same({}, UISpecialFrames)
      open()
      assert.are.equal(pages:Get("cats"), settings.sidebarPage, "it opens on the list it showed")
      assert.are.same({ "BetterBagsNextSettingsBack" }, UISpecialFrames)
    end)

    it("goes back on the first Escape when opened again while it fades out on its list", function()
      open()
      settings:Select("cats")
      settings:Close()
      tween:Step(style.Time.Close / 2)
      open()
      for _, fn in ipairs(timers) do fn() end
      assert.are.same({ "BetterBagsNextSettingsBack" }, UISpecialFrames)
      assert.are.same({ settings.frame, settings.backKey }, controls.escape)
    end)

    it("shows its heading and its actions in the header, and the page's own elsewhere", function()
      open()
      settings:Select("cats")
      assert.are.equal("Mats", settings.title:GetText())
      assert.are.equal("2 items", settings.description:GetText())
      local a = state.actions
      assert.are.equal(settings.header, a.frame:GetParent())
      assert.are.equal(settings.frame, a.owner)
      assert.is_true(a.frame:IsShown())
      assert.is_true(state.actionsRefreshed > 0)
      local H, X = S().Header, S().Header.Close
      assert.are.same({ "TOPRIGHT", settings.header, "TOPRIGHT", -(X.Inset + X.Size + H.Actions.Gap), -H.Actions.Top },
        { a.frame:GetPoint(1) })
      -- Short of the buttons by their width rounded up, from the header's corner (docs/next-pixel-perfect.md).
      local right = X.Inset + X.Size + H.Actions.Gap + math.ceil(a.frame:GetWidth()) + H.Actions.Gap
      assert.are.same({ "TOPRIGHT", settings.header, "TOPRIGHT", -right, -H.TitleTop }, { settings.title:GetPoint(2) })
      settings:Select("general")
      assert.is_false(a.frame:IsShown())
      assert.are.equal("General", settings.title:GetText())
      assert.is_nil(settings.title:GetPoint(2), "the title as wide as it likes")
    end)

    it("shows only the tabs that say so, the first shown for one hidden", function()
      open()
      settings:Select("cats", "rule")
      assert.are.same({ "Settings", "Added Items" }, tabTitles())
      assert.are.equal("settings", settings.tabId)
      state.rule = true
      settings:Select("cats", "rule")
      assert.are.same({ "Settings", "Rule", "Added Items" }, tabTitles())
      assert.are.equal("rule", settings.tabId)
    end)

    -- The list chooses what the page shows (the Categories page: the first category, when none is), so
    -- the tabs are read after it.
    it("reads its tabs after its list, which may change what they show", function()
      local savedSidebar = pages:Get("cats").sidebar
      pages:Get("cats").sidebar = function(parent, owner)
        local sb = savedSidebar(parent, owner)
        function sb:Refresh() state.rule = true end
        return sb
      end
      open()
      settings:Select("cats", "rule")
      assert.are.same({ "Settings", "Rule", "Added Items" }, tabTitles())
      assert.are.equal("rule", settings.tabId)
    end)

    it("reads its heading, actions, tabs and list again when told (Reselect)", function()
      open()
      settings:Select("cats", "items")
      local refreshed, actions = state.refreshed, state.actionsRefreshed
      state.title, state.rule = "Metals", true
      settings:Reselect()
      assert.are.equal("Metals", settings.title:GetText())
      assert.are.same({ "Settings", "Rule", "Added Items" }, tabTitles())
      assert.are.equal("items", settings.tabId, "on the same tab")
      assert.is_true(state.refreshed > refreshed and state.actionsRefreshed > actions)
    end)

    it("leaves its list for a search", function()
      open()
      settings:Select("cats")
      settings:Search(addon:GetModule("Context"):New("spec"), "merge")
      assert.is_nil(settings.sidebarPage)
      for _, fn in ipairs(timers) do fn() end
      assert.are.same({ "BetterBagsNextSettings" }, UISpecialFrames)
    end)
  end)

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
