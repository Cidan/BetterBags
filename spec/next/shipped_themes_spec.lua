-- shipped_themes_spec.lua -- every shipped BetterBags Next theme (sonata/themes/next/*.lua) draws Next's settings
-- window, its controls, its menus and its dialogs on every client. SonataNext restyles each widget in a protected
-- call and hands a failure to the error handler (RestyleWidgets), which the mocks drop, so a theme that breaks a
-- widget passed every other spec: this one fails on anything sent to the error handler. Added for the Plain theme
-- (docs/next-plain-theme.md), which turns off parts the other themes keep (Indicator = false, Divider = false).
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
local modules = { { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextFrameArt", "next/frameart.lua" }, { "NextFill", "next/fill.lua" }, { "NextControls", "next/controls/base.lua" },
  { "NextScrollBar", "next/controls/scrollbar.lua" }, { "NextButton", "next/controls/button.lua" },
  { "NextToggle", "next/controls/toggle.lua" }, { "NextInput", "next/controls/input.lua" },
  { "NextSlider", "next/controls/slider.lua" }, { "NextMenu", "next/controls/menu.lua" },
  { "NextDropdown", "next/controls/dropdown.lua" }, { "NextSwatch", "next/controls/swatch.lua" },
  { "NextTopTabs", "next/controls/toptabs.lua" }, { "NextLift", "next/lift.lua" }, { "NextDialog", "next/controls/dialog.lua" },
  { "NextSettingsRows", "next/settings/rows.lua" }, { "NextSettingsPage", "next/settings/page.lua" },
  { "NextSettingsPages", "next/settings/pages.lua" }, { "NextSettings", "next/settings/window.lua" } }
for _, m in ipairs(modules) do
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
local context = addon:GetModule("Context")
local sonataNext = addon:GetModule("SonataNext")

-- Every client SonataResolve knows, by the flags that pick its override keys (next_themes_spec.lua).
local FLAGS = { "isRetail", "isForever", "isClassic", "isBCC", "isMists", "isAnniversary", "isCata" }
local CLIENTS = {
  Retail = { isRetail = true },
  Forever = { isRetail = true, isForever = true },
  Era = { isClassic = true },
  TBC = { isBCC = true },
  Anniversary = { isAnniversary = true, isBCC = true },
  Mists = { isMists = true },
  Cata = { isCata = true },
}

describe("every shipped Next theme", function()
  local values, saved, savedFlags, errors, sharedWidgets

  local function ctx() return context:New("spec") end

  local function option(kind, key, extra)
    local o = { kind = kind, title = kind, description = "A " .. kind .. ".",
      get = function() return values[key] end, set = function(_, v) values[key] = v end }
    for k, v in pairs(extra or {}) do o[k] = v end
    return { option = o }
  end

  -- A page with a row of every kind a page draws, and a second tab, so the page's tabs show.
  local function define()
    pages:Clear()
    pages:Define({
      id = "general", group = "BetterBags", title = "General", description = "Every kind of row.",
      tabs = {
        { id = "main", title = "Controls", sections = {
          { title = "Rows", rows = {
            option("toggle", "toggle"),
            option("dropdown", "dropdown", { items = { "Alphabetically", "Size Descending" } }),
            option("slider", "slider", { min = 0, max = 100, step = 1 }),
            option("color", "color"),
            option("input", "input"),
            { text = "Some text across the page." },
            { buttons = { { text = "Export", onClick = function() end }, { text = "Delete", style = "Danger", onClick = function() end } } },
          } },
        } },
        { id = "more", title = "More", sections = { { title = "More", rows = { option("toggle", "other") } } } },
      },
    })
    pages:Define({ id = "profiles", group = "Profiles", title = "Profiles", description = "",
      tabs = { { id = "main", title = "Profiles", sections = { { title = "Text", rows = { { text = "Shared." } } } } } } })
  end

  -- exercise works every part of the window under the theme in effect: restyled, opened on the page, every control
  -- under the pointer and pressed, the dropdown's menu open, a dialog with a field, the other tab and page.
  local function exercise()
    sonataNext:RestyleWidgets(ctx())
    settings:Open("general")
    for _, section in ipairs(settings.page.sections) do
      for _, row in ipairs(section.rows) do
        local control = row.control
        local frame = control and (control.frame or control.track)
        if frame ~= nil then
          for _, script in ipairs({ "OnEnter", "OnMouseDown", "OnMouseUp", "OnLeave" }) do
            local fn = frame:GetScript(script)
            if fn then fn(frame, "LeftButton") end
          end
        end
        if control and control.SetEnabled then
          control:SetEnabled(false)
          control:SetEnabled(true)
        end
      end
    end
    for _, section in ipairs(settings.page.sections) do
      for _, row in ipairs(section.rows) do
        if row.control and row.control.opts and row.control.opts.items then
          row.control.frame:GetScript("OnClick")(row.control.frame, "LeftButton")
          for _, menuRow in ipairs(nextMenu:Rows()) do
            menuRow.frame:GetScript("OnEnter")(menuRow.frame)
            menuRow.frame:GetScript("OnLeave")(menuRow.frame)
          end
          nextMenu:Close()
        end
      end
    end
    nextDialog:Show(settings.frame, { title = "Rename", text = "A new name.", input = "Raid",
      buttons = { { text = "Cancel", onClick = function() end }, { text = "Rename", style = "Primary", onClick = function() end } } })
    nextDialog:Hide()
    settings:Select("general", "more", ctx())
    settings:Select("profiles", nil, ctx())
    for _, row in ipairs(settings.navRows) do
      local enter, leave = row.frame:GetScript("OnEnter"), row.frame:GetScript("OnLeave")
      if enter then enter(row.frame) leave(row.frame) end
    end
    settings.closeButton:GetScript("OnEnter")(settings.closeButton)
    settings.closeButton:GetScript("OnLeave")(settings.closeButton)
    settings:Close()
    tween:Step(1)
  end

  local function useClient(flags)
    for _, flag in ipairs(FLAGS) do addon[flag] = flags[flag] == true end
  end

  -- One window for the whole spec, built under Plain (as in game when Plain is the saved theme): a window per test
  -- would stay live for the rest of the run (UIParent keeps its children), about 8 MB each. Each test restyles it,
  -- as a theme switch does in game. Only the widgets this spec makes are restyled: other spec files' widgets were
  -- made against their own stubs.
  setup(function()
    sharedWidgets = sonataNext.widgets
    sonataNext.widgets = setmetatable({}, { __mode = "k" })
    saved = { _G.UISpecialFrames, C_Timer.After, events.SendMessage, bagSystem.ActiveDesign, _G.geterrorhandler,
      _G._loadedAddOns }
    savedFlags = {}
    for _, flag in ipairs(FLAGS) do savedFlags[flag] = addon[flag] end
    values = { toggle = true, other = false, dropdown = "Alphabetically", slider = 40, color = { r = 1, g = 1, b = 1, a = 1 },
      input = "Raid" }
    errors = {}
    bagSystem.ActiveDesign = function() return "next" end
    _G.UISpecialFrames = {}
    C_Timer.After = function(_, fn) fn() end
    events.SendMessage = function() end
    _G.geterrorhandler = function() return function(err) table.insert(errors, tostring(err)) end end
    -- Guild Wars 2 is offered while GW2_UI is loaded, ElvUI while ElvUI is.
    _G._loadedAddOns = { GW2_UI = true, ElvUI = true }
    controls.escape = {}
    render:Init()
    tween:Init()
    define()
    settings:Init()
    useClient(CLIENTS.Retail)
    style:Use(sonataNext:Resolve("Plain"))
    settings:Open("general")
    settings:Close()
    tween:Step(1)
  end)

  before_each(function()
    errors = {}
  end)

  after_each(function()
    nextMenu:Close()
    nextDialog:Hide()
  end)

  teardown(function()
    if settings.frame then settings:Close() end
    _G.UISpecialFrames, C_Timer.After, events.SendMessage, bagSystem.ActiveDesign, _G.geterrorhandler,
      _G._loadedAddOns = saved[1], saved[2], saved[3], saved[4], saved[5], saved[6]
    for _, flag in ipairs(FLAGS) do addon[flag] = savedFlags[flag] end
    UseNextTheme(nil)
    ResetModuleStub("SettingsCatalog")
    pages:Clear()
    sonataNext.widgets = sharedWidgets
  end)

  it("built its window under Plain without an error", function()
    assert.is_not_nil(settings.frame)
    assert.are.same({}, errors)
  end)

  local keys = {}
  for key in pairs(sonataNext:GetThemes()) do table.insert(keys, key) end
  table.sort(keys)

  it("ships the themes this spec draws", function()
    assert.is_true(#keys >= 6)
    assert.is_not_nil(sonataNext:GetThemes().Plain)
  end)

  -- Reported in game on the Papercraft theme: every pencilled field and button smeared past its edges.
  for _, key in ipairs(keys) do
    it("sizes all its art in the settings window with " .. key, function()
      local layout = dofile("spec/helpers/layout.lua")
      local undo = layout.UseScreen(1920, 1080, 1)
      useClient(CLIENTS.Retail)
      style:Use(sonataNext:Resolve(key))
      sonataNext:RestyleWidgets(ctx())
      settings:Open("general")
      local found = layout.ArtWithNoSize(settings.frame)
      nextDialog:Show(settings.frame, { title = "Rename", text = "A new name.", input = "Raid",
        buttons = { { text = "Rename", style = "Primary", onClick = function() end } } })
      local dialog = layout.ArtWithNoSize(settings.frame)
      nextDialog:Hide()
      settings:Close()
      tween:Step(1)
      undo()
      assert.are.same({}, found)
      assert.are.same({}, dialog)
    end)
  end

  -- The ElvUI theme's rows and widths grow with ElvUI's font size (next-themes-elvui.md §27): its settings window, every
  -- control, menu and dialog drawn at a large and a small one, and its art sized.
  for _, fontSize in ipairs({ 22, 9 }) do
    it("draws the settings window, its controls, menus and dialogs with ElvUI at ElvUI's font size " .. fontSize, function()
      local savedElvUI = rawget(_G, "ElvUI")
      _G.ElvUI = { { db = { general = { fontSize = fontSize } } } }
      local layout = dofile("spec/helpers/layout.lua")
      -- A UI unit a whole pixel, so a font is drawn at the size the theme gives it.
      local undo = layout.UseScreen(1536, 768, 1)
      useClient(CLIENTS.Retail)
      style:Use(sonataNext:Resolve("ElvUI"))
      local _, height = style:Font("SettingsLabel"):GetFont()
      local ok, err = pcall(exercise)
      sonataNext:RestyleWidgets(ctx())
      settings:Open("general")
      local found = layout.ArtWithNoSize(settings.frame)
      settings:Close()
      tween:Step(1)
      undo()
      _G.ElvUI = savedElvUI
      assert.are.equal(fontSize, height, "the settings text at ElvUI's size")
      assert.is_true(ok, tostring(err))
      assert.are.same({}, errors)
      assert.are.same({}, found)
    end)
  end

  -- Found in review: the sidebar and the controls widened with ElvUI's font size while the window kept its width, so
  -- from 30 the controls spilled off the page, and at 64 the sidebar was wider than the window; and a settings row's text
  -- field kept the width it was made with. The window grows as the text does (it shrinks itself to fit the screen).
  for _, fontSize in ipairs({ 12, 22, 30, 64 }) do
    it("keeps every control on the settings page with ElvUI at ElvUI's font size " .. fontSize, function()
      local savedElvUI = rawget(_G, "ElvUI")
      _G.ElvUI = { { db = { general = { fontSize = fontSize } } } }
      local layout = dofile("spec/helpers/layout.lua")
      local undo = layout.UseScreen(1920, 1080, 1)
      useClient(CLIENTS.Retail)
      style:Use(sonataNext:Resolve("ElvUI"))
      sonataNext:RestyleWidgets(ctx())
      settings:Open("general")
      local window, page = layout.Rect(settings.frame), layout.Rect(settings.scroll.frame)
      local spilled, input = {}, nil
      for _, section in ipairs(settings.page.sections) do
        for _, row in ipairs(section.rows) do
          local control = row.control
          local frame = control and (control.frame or control.track)
          if frame ~= nil then
            local r, held = layout.Rect(frame), layout.Rect(row.frame)
            if r.left < math.max(page.left, held.left) - 1e-6 or r.right > math.min(page.right, held.right) + 1e-6 then
              table.insert(spilled, ("%s %.1f..%.1f (row %.1f..%.1f, page %.1f..%.1f)"):format(
                row.option and row.option.kind or "?", r.left, r.right, held.left, held.right, page.left, page.right))
            end
            if row.option and row.option.kind == "input" then
              input = frame:GetWidth()
            end
          end
        end
      end
      local inScreen = window.left >= -1e-6 and window.right <= UIParent:GetWidth() + 1e-6
      -- ElvUI's size changed while the window is open: its text field follows the dropdowns' width.
      _G.ElvUI = { { db = { general = { fontSize = fontSize + 6 } } } }
      style:Use(sonataNext:Resolve("ElvUI"))
      sonataNext:RestyleWidgets(ctx())
      local after
      for _, section in ipairs(settings.page.sections) do
        for _, row in ipairs(section.rows) do
          if row.option and row.option.kind == "input" then
            after = row.control.frame:GetWidth()
          end
        end
      end
      local afterWidth = sonataNext:Resolve("ElvUI").Controls.Dropdown.Width
      -- Both on whole pixels of the window's grid: a pixel apart at most.
      local unit = addon:GetModule("NextPixel"):Unit(settings.frame)
      settings:Close()
      tween:Step(1)
      undo()
      _G.ElvUI = savedElvUI
      _G.ElvUI = { { db = { general = { fontSize = fontSize } } } }
      local dropdownWidth = sonataNext:Resolve("ElvUI").Controls.Dropdown.Width
      _G.ElvUI = savedElvUI
      assert.are.same({}, spilled)
      assert.is_true(inScreen, "the window on the screen")
      assert.is_not_nil(input)
      assert.is_true(math.abs(input - dropdownWidth) < 1, "the text field as wide as the dropdowns: " .. input)
      assert.is_true(math.abs(after - afterWidth) <= unit + 1e-6, "and after a restyle: " .. after .. " against " .. afterWidth)
    end)
  end

  -- Found in a second review: a theme of another size restyled while the window shows (a preview from the theme page,
  -- ElvUI's font size changed) resized it without fitting it to the screen or centering it again: from ElvUI's 13 it
  -- ran off the bottom of a 1080p screen, and back from 40 it stayed a small box in a corner.
  -- windowState settles the window and returns its rect and the screen's width and height, both in absolute units (a
  -- unit times its effective scale: layout.Rect).
  local function windowState()
    tween:Step(1)
    local layout = dofile("spec/helpers/layout.lua")
    local r, screen = layout.Rect(settings.frame), layout.Rect(UIParent)
    return r, screen.right - screen.left, screen.top - screen.bottom
  end

  it("fits the window to the screen and centers it again as a theme of another size is applied while it shows", function()
    local savedElvUI = rawget(_G, "ElvUI")
    local layout = dofile("spec/helpers/layout.lua")
    local undo = layout.UseScreen(1920, 1080, 1)
    useClient(CLIENTS.Retail)
    style:Use(sonataNext:Resolve("Default"))
    sonataNext:RestyleWidgets(ctx())
    settings:Open("general")
    local problems = {}
    for _, fontSize in ipairs({ 13, 18, 40, 12 }) do
      _G.ElvUI = { { db = { general = { fontSize = fontSize } } } }
      style:Use(sonataNext:Resolve("ElvUI"))
      sonataNext:RestyleWidgets(ctx())
      local r, w, h = windowState()
      if r.left < -0.5 or r.bottom < -0.5 or r.right > w + 0.5 or r.top > h + 0.5 then
        table.insert(problems, ("%d: off the screen %.1f..%.1f x %.1f..%.1f"):format(fontSize, r.left, r.right, r.bottom, r.top))
      end
      if math.abs(r.left - (w - r.right)) > 1 or math.abs(r.bottom - (h - r.top)) > 1 then
        table.insert(problems, ("%d: not centered %.1f..%.1f x %.1f..%.1f"):format(fontSize, r.left, r.right, r.bottom, r.top))
      end
      if fontSize == 12 then
        assert.are.equal(1, settings.frame:GetScale(), "back to its own size")
      end
    end
    settings:Close()
    tween:Step(1)
    undo()
    _G.ElvUI = savedElvUI
    assert.are.same({}, problems)
  end)

  -- Found in a third review: closing from a preview, the theme page puts the saved theme back as it is left, after the
  -- window says it is closed but while it is still on the screen, sliding out: it took the saved theme's size at the
  -- preview's scale, a small box in its corner, and opened again during the slide it stayed so.
  it("fits the window again when the saved theme comes back as it closes from a preview, and opens right during the slide", function()
    local savedElvUI = rawget(_G, "ElvUI")
    local layout = dofile("spec/helpers/layout.lua")
    local undo = layout.UseScreen(1920, 1080, 1)
    useClient(CLIENTS.Retail)
    style:Use(sonataNext:Resolve("Default"))
    sonataNext:RestyleWidgets(ctx())
    settings:Open("general")
    tween:Step(1)
    _G.ElvUI = { { db = { general = { fontSize = 40 } } } }
    style:Use(sonataNext:Resolve("ElvUI"))
    sonataNext:RestyleWidgets(ctx())
    tween:Step(1)
    assert.is_true(settings.frame:GetScale() < 1, "the preview fitted to the screen")
    -- As the theme page's OnPageLeft does (next/settings/themes.lua): the saved theme back as the page is left.
    local ended = settings.ended
    settings.ended = function(self)
      ended(self)
      style:Use(sonataNext:Resolve("Default"))
      sonataNext:RestyleWidgets(ctx())
    end
    settings:Close()
    settings.ended = ended
    local scale, width, height = settings.frame:GetScale(), settings.frame:GetWidth(), settings.frame:GetHeight()
    tween:Step(style.Time.Close / 3)
    settings:Open("general")
    local r, w, h = windowState()
    settings:Close()
    tween:Step(1)
    undo()
    _G.ElvUI = savedElvUI
    assert.are.same({ 1, 1000, 720 }, { scale, math.floor(width + 0.5), math.floor(height + 0.5) }, "sliding out at its size")
    assert.is_true(math.abs(r.left - (w - r.right)) <= 1 and math.abs(r.bottom - (h - r.top)) <= 1,
      ("opened again during the slide, centered: %.1f..%.1f x %.1f..%.1f"):format(r.left, r.right, r.bottom, r.top))
  end)

  -- Found in a fourth review: no spec held a slide under way through a re-center. A theme of another size landing part
  -- way through the window's slide in keeps it sliding, from where it was, to its new center.
  it("keeps a slide under way as a theme of another size centers the window again", function()
    local savedElvUI = rawget(_G, "ElvUI")
    local layout = dofile("spec/helpers/layout.lua")
    local undo = layout.UseScreen(1920, 1080, 1)
    useClient(CLIENTS.Retail)
    style:Use(sonataNext:Resolve("Default"))
    sonataNext:RestyleWidgets(ctx())
    settings:Open("general")
    tween:Step(style.Time.Open / 3)
    local offset = settings.offset
    _G.ElvUI = { { db = { general = { fontSize = 18 } } } }
    style:Use(sonataNext:Resolve("ElvUI"))
    sonataNext:RestyleWidgets(ctx())
    local kept, alpha = settings.offset, settings.frame:GetAlpha()
    local r, w, h = windowState()
    settings:Close()
    tween:Step(1)
    undo()
    _G.ElvUI = savedElvUI
    assert.is_true(offset > 0, "sliding in: " .. tostring(offset))
    assert.are.equal(offset, kept, "the slide kept")
    assert.is_true(alpha < 1, "still faded as it slides")
    assert.is_true(math.abs(r.left - (w - r.right)) <= 1 and math.abs(r.bottom - (h - r.top)) <= 1,
      ("landed centered: %.1f..%.1f x %.1f..%.1f"):format(r.left, r.right, r.bottom, r.top))
  end)

  -- A theme of another size the screen holds as it is, so nothing is fitted again: the window is centered again all
  -- the same (found in review: no spec ran this).
  it("centers the window again for a theme of another size that needs no new scale", function()
    local savedElvUI = rawget(_G, "ElvUI")
    local layout = dofile("spec/helpers/layout.lua")
    local undo = layout.UseScreen(3440, 1440, 0.64)
    useClient(CLIENTS.Retail)
    style:Use(sonataNext:Resolve("Default"))
    sonataNext:RestyleWidgets(ctx())
    settings:Open("general")
    _G.ElvUI = { { db = { general = { fontSize = 14 } } } }
    style:Use(sonataNext:Resolve("ElvUI"))
    sonataNext:RestyleWidgets(ctx())
    local r, w, h = windowState()
    local scale = settings.frame:GetScale()
    settings:Close()
    tween:Step(1)
    undo()
    _G.ElvUI = savedElvUI
    assert.are.equal(1, scale, "no new scale")
    assert.is_true(math.abs(r.left - (w - r.right)) <= 1 and math.abs(r.bottom - (h - r.top)) <= 1,
      ("centered: %.1f..%.1f x %.1f..%.1f"):format(r.left, r.right, r.bottom, r.top))
  end)

  -- A new scale lays every widget in the window out again for its grid (found in review: no spec ran this): with the
  -- controls restyled before the window, they were laid out on the old scale's grid.
  it("lays every widget out again for the new grid when a theme fits the window to another scale", function()
    local savedElvUI = rawget(_G, "ElvUI")
    local layout = dofile("spec/helpers/layout.lua")
    local undo = layout.UseScreen(1920, 1080, 1)
    useClient(CLIENTS.Retail)
    style:Use(sonataNext:Resolve("Default"))
    sonataNext:RestyleWidgets(ctx())
    settings:Open("general")
    tween:Step(1)
    _G.ElvUI = { { db = { general = { fontSize = 18 } } } }
    style:Use(sonataNext:Resolve("ElvUI"))
    for _, name in ipairs({ "NextButton", "NextToggle", "NextInput", "NextSlider", "NextDropdown", "NextSwatch",
      "NextTopTabs", "NextScrollBar", "NextSettingsRows", "NextSettingsPage", "NextSettings" }) do
      addon:GetModule(name):ApplyStyle(ctx())
    end
    tween:Step(1)
    local scale = settings.frame:GetScale()
    local off = layout.PixelCheck(settings.frame)
    settings:Close()
    tween:Step(1)
    undo()
    _G.ElvUI = savedElvUI
    assert.is_true(scale < 1, "fitted to another scale")
    assert.are.same({}, off)
  end)

  -- A window the player moved stays where they put it when the grid changes (a UI scale or a screen size: NextPixel
  -- applies the theme again): its size re-snaps to the new grid, but its theme gives it the same size, and it is centered
  -- again only for a theme of another size or a new scale (found in review: the re-snapped size moved it to the center).
  it("leaves a window the player moved where it is when the grid changes and its theme's size does not", function()
    local layout = dofile("spec/helpers/layout.lua")
    local undo = layout.UseScreen(1920, 1080, 1)
    useClient(CLIENTS.Retail)
    style:Use(sonataNext:Resolve("Default"))
    sonataNext:RestyleWidgets(ctx())
    settings:Open("general")
    tween:Step(1)
    settings.frame:ClearAllPoints()
    settings.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100)
    undo()
    undo = layout.UseScreen(1920, 1080, 0.9)
    style:Use(sonataNext:Resolve("Default"))
    sonataNext:RestyleWidgets(ctx())
    local point, _, _, x, y = settings.frame:GetPoint(1)
    local scale = settings.frame:GetScale()
    settings:Close()
    tween:Step(1)
    undo()
    assert.are.equal(1, scale)
    assert.are.same({ "TOPLEFT", 100, -100 }, { point, math.floor(x + 0.5), math.floor(y + 0.5) })
  end)

  -- Found in a second review: SonataNext restyles widgets in no set order, and a settings row measured its name beside
  -- its control's width before the control restyled (the window renders as it restyles): with ElvUI's controls
  -- widening with its font size, the name ran under the control. A row restyles its control before laying out by it
  -- (patterns-ui-themes.md, "Restyle a Control Before Laying Out by Its Size").
  it("lays a settings row's name beside its control whatever order the widgets restyle in", function()
    local savedElvUI = rawget(_G, "ElvUI")
    local layout = dofile("spec/helpers/layout.lua")
    -- A screen the window fits on at both sizes, so nothing is fitted again (a new scale restyles every widget again).
    local undo = layout.UseScreen(3440, 1440, 0.64)
    useClient(CLIENTS.Retail)
    _G.ElvUI = { { db = { general = { fontSize = 12 } } } }
    style:Use(sonataNext:Resolve("ElvUI"))
    sonataNext:RestyleWidgets(ctx())
    settings:Open("general")
    tween:Step(1)
    _G.ElvUI = { { db = { general = { fontSize = 16 } } } }
    style:Use(sonataNext:Resolve("ElvUI"))
    -- The page, then the window (which renders it), then the controls and the rows.
    for _, name in ipairs({ "NextSettingsPage", "NextSettings", "NextInput", "NextDropdown", "NextSlider", "NextToggle",
      "NextSwatch", "NextSettingsRows" }) do
      addon:GetModule(name):ApplyStyle(ctx())
    end
    assert.are.equal(1, settings.frame:GetScale(), "drawn at its own size: nothing fitted again")
    local overlaps = {}
    for _, section in ipairs(settings.page.sections) do
      for _, row in ipairs(section.rows) do
        local control = row.control
        local frame = control and (control.frame or control.track)
        if frame ~= nil and row.label ~= nil then
          local label, held = layout.Rect(row.label), layout.Rect(frame)
          -- Its width in its own units, its place in the screen's (a unit times its effective scale, layout.Rect).
          local right = label.left + row.label:GetWidth() * row.label:GetEffectiveScale()
          if right > held.left + 0.5 then
            table.insert(overlaps, ("%s: its name to %.1f, its control from %.1f"):format(
              row.option and row.option.kind or "?", right, held.left))
          end
        end
      end
    end
    settings:Close()
    tween:Step(1)
    undo()
    _G.ElvUI = savedElvUI
    assert.are.same({}, overlaps)
  end)

  local clientNames = {}
  for name in pairs(CLIENTS) do table.insert(clientNames, name) end
  table.sort(clientNames)
  for _, client in ipairs(clientNames) do
    for _, key in ipairs(keys) do
      it("draws the settings window, its controls, menus and dialogs with " .. key .. " on " .. client, function()
        useClient(CLIENTS[client])
        style:Use(sonataNext:Resolve(key))
        local ok, err = pcall(exercise)
        assert.is_true(ok, tostring(err))
        assert.are.same({}, errors)
      end)
    end
  end
end)
