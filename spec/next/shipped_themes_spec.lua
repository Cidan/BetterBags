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
  { "NextTopTabs", "next/controls/toptabs.lua" }, { "NextDialog", "next/controls/dialog.lua" },
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
    -- Guild Wars 2 is offered while GW2_UI is loaded.
    _G._loadedAddOns = { GW2_UI = true }
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
