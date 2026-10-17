-- changelog_spec.lua -- The changelog window (frames/changelog.lua): a Sonata Panel window
-- (window/window.lua) listing the bundled releases (data/changelog.lua), newest first, every
-- entry showing its details and highlighted under the pointer, with a "Don't show me this again" checkbox at the
-- bottom left and an "Okay!" button at the bottom right. It opens by itself after the first
-- loading screen when the player has not turned that off and has not seen a release, and on
-- changelog/Open. Closing it marks every bundled release seen.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local context = LoadFreshBetterBagsModule("Context", "core/context.lua")
local events = LoadFreshBetterBagsModule("Events", "core/events.lua")

-- Stubs this file creates are removed after it (the teardown at the end), so a later spec
-- file can load the real modules.
local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local L = trackStub("Localization")
L.G = L.G or function(_, text) return text end

local const = trackStub("Constants")
const.BAG_KIND = const.BAG_KIND or { BACKPACK = 0, BANK = 1 }

local db = trackStub("Database")
local data = trackStub("ChangelogData")
local savedDB = {}
for _, k in ipairs({ "GetTheme", "SetTheme", "GetBagSizeInfo", "GetBagView", "GetChangelogLastSeen",
  "SetChangelogLastSeen", "GetChangelogAutoOpen", "SetChangelogAutoOpen" }) do
  savedDB[k] = rawget(db, k)
end
local savedReleases = rawget(data, "releases")

local fonts = trackStub("Fonts")
fonts.UnitFrame12Yellow = fonts.UnitFrame12Yellow or CreateFont("BetterBagsChangelogSpecYellow")

local libWindow = LibStub:NewLibrary("LibWindow-1.1", 1) or LibStub("LibWindow-1.1")
libWindow.RegisterConfig = libWindow.RegisterConfig or function() end
libWindow.RestorePosition = libWindow.RestorePosition or function() end
libWindow.SavePosition = libWindow.SavePosition or function() end

LoadBetterBagsModule("render/render.lua")
LoadBetterBagsModule("render/drawable.lua")
LoadBetterBagsModule("render/scrollbox.lua")
LoadBetterBagsModule("sonata/engine.lua")
LoadBetterBagsModule("sonata/apply.lua")
LoadBetterBagsModule("sonata/decoration.lua")
LoadBetterBagsModule("window/window.lua")
ResetModuleStub("Changelog", "data/changelog.lua")
LoadBetterBagsModule("data/changelog.lua")

local sonata = addon:GetModule("Sonata")
local render = addon:GetModule("Render")

local RELEASES = {
  { id = 200, version = "v0.5.17", channel = "release", date = "2026-10-10", headline = "Tabs for every theme.",
    entries = {
      { category = "New", title = "Tabs for every theme", details = "Each theme now styles the group tabs to match its art.", clients = {} },
      { category = "Fixed", title = "Windows stay on the screen", details = "A bank sized past the screen could not be resized back.", clients = { "Retail", "Forever" } },
      { category = "Changed", title = "A plain title", details = "", clients = {} },
    } },
  { id = 100, version = "v0.5.16", channel = "release", date = "2026-10-01", headline = "An older release.",
    entries = { { category = "Improved", title = "Faster sorting", details = "Sorting reads the bags once.", clients = {} } } },
  { id = 300, version = "v0.5.17-2-gabcdef0", channel = "alpha", date = "2026-10-17", headline = "Forever only.",
    entries = { { category = "Fixed", title = "Keyring free slots", details = "The keyring is not free space.", clients = { "Forever" } } } },
}

describe("ChangelogWindow", function()
  local cw, state, pending, originalAfter, originalThemes, originalRegisterElement, registered, flavor

  local function advance()
    local due = pending
    pending = {}
    for _, fn in ipairs(due) do fn() end
  end

  before_each(function()
    events:Init()
    render:Init()
    pending = {}
    originalAfter = _G.C_Timer.After
    _G.C_Timer.After = function(_, fn) table.insert(pending, fn) end
    _G.UISpecialFrames = {}
    originalThemes = sonata.themes
    sonata.themes = {}
    sonata:Init()
    assert(loadfile("sonata/themes/base.lua"))("BetterBags")
    assert(loadfile("sonata/themes/default.lua"))("BetterBags")
    db.GetTheme = function() return "Default" end
    db.SetTheme = function() end
    db.GetBagView = function() return 1 end
    db.GetBagSizeInfo = function() return { opacity = 60 } end
    state = { lastSeen = 0, autoOpen = true }
    db.GetChangelogLastSeen = function() return state.lastSeen end
    db.SetChangelogLastSeen = function(_, id) state.lastSeen = id end
    db.GetChangelogAutoOpen = function() return state.autoOpen end
    db.SetChangelogAutoOpen = function(_, value) state.autoOpen = value end
    data.releases = RELEASES
    flavor = { isRetail = addon.isRetail, isForever = addon.isForever }
    addon.isRetail, addon.isForever = true, false
    registered = {}
    originalRegisterElement = sonata.RegisterElement
    sonata.RegisterElement = function(self, kind, element)
      registered[element] = kind
      return originalRegisterElement(self, kind, element)
    end
    UseSonataTextRoles()
    sonata:ApplyTheme(context:New("spec"), "Default")
    ResetModuleStub("ChangelogWindow", "frames/changelog.lua")
    LoadBetterBagsModule("frames/changelog.lua")
    cw = addon:GetModule("ChangelogWindow")
    cw:OnEnable()
  end)

  after_each(function()
    _G.C_Timer.After = originalAfter
    sonata.RegisterElement = originalRegisterElement
    sonata.themes = originalThemes
    addon.isRetail, addon.isForever = flavor.isRetail, flavor.isForever
  end)

  teardown(function()
    for k, v in pairs(savedDB) do db[k] = v end
    data.releases = savedReleases
    ResetModuleStub("ChangelogWindow", "frames/changelog.lua")
    ResetModuleStub("Changelog", "data/changelog.lua")
  end)

  local function open()
    cw:Open(context:New("spec"))
    advance()
  end

  local function topOffset(frame)
    local _, _, _, _, y = frame:GetPoint(1)
    return y
  end

  it("is a titled Sonata Panel window in the dialog strata, closing with Escape, at a fixed size", function()
    open()
    local w = cw.window
    assert.are.equal("Panel", w.kind)
    assert.is_not_nil(w.decoration)
    assert.are.equal("BetterBagsChangelog", w.frame:GetName())
    assert.are.same({ "BetterBagsChangelog" }, _G.UISpecialFrames)
    assert.are.equal("What's New in BetterBags", w:GetTitle())
    assert.are.equal("DIALOG", w.frame:GetFrameStrata())
    assert.are.same({ 560, 540 }, { w.frame:GetWidth(), w.frame:GetHeight() })
    assert.are.equal("window", w:GetSizeMode())
    assert.is_false(w.frame._resizable)
    assert.are.equal(60, w:GetOpacity())
    assert.is_true(w.frame:IsShown())
  end)

  it("lists the releases newest first, with their version, date and headline, and the entries for this client", function()
    open()
    local headers = cw.canvas.headers
    assert.are.equal("v0.5.17", headers[1].version:GetText())
    assert.are.equal("2026-10-10", headers[1].date:GetText())
    assert.are.equal("Tabs for every theme.", headers[1].headline:GetText())
    assert.are.equal("v0.5.16", headers[2].version:GetText())
    assert.is_false(headers[3] ~= nil and headers[3].frame:IsShown())
    local titles = {}
    for _, row in ipairs(cw.canvas.rows) do
      if row.button:IsShown() then table.insert(titles, row.title:GetText()) end
    end
    assert.are.same({ "Tabs for every theme", "Windows stay on the screen", "A plain title", "Faster sorting" }, titles)
    assert.are.equal("New", cw.canvas.rows[1].tag:GetText())
    assert.are.equal("Fixed", cw.canvas.rows[2].tag:GetText())
  end)

  it("names an alpha build as one", function()
    addon.isForever = true
    open()
    assert.are.equal("v0.5.17-2-gabcdef0", cw.canvas.headers[1].version:GetText())
    assert.are.equal("2026-10-17 - Alpha", cw.canvas.headers[1].date:GetText())
  end)

  it("marks the releases the player has not seen", function()
    state.lastSeen = 100
    open()
    assert.is_true(cw.canvas.headers[1].badge:IsShown())
    assert.are.equal("New", cw.canvas.headers[1].badge:GetText())
    assert.is_false(cw.canvas.headers[2].badge:IsShown())
  end)

  it("lays the releases out top to bottom across the scroll area, and scrolls them", function()
    open()
    local insets = cw.window:GetContentInsets()
    -- The scroll area stops 10 short of the content box's right edge, so the bar's 17-wide
    -- buttons (centered on the 8-wide bar) end 9.5 in from it, clear of a frame border drawn
    -- over the content box's edge.
    local canvasWidth = 560 - insets.Left - insets.Right - 10 - cw.scroll:GetBarWidth()
    assert.are.equal(canvasWidth, cw.canvas.frame:GetWidth())
    local last = 1
    local function below(frame)
      local y = topOffset(frame)
      assert.is_true(y < last, "laid out below the previous part")
      last = y
    end
    below(cw.canvas.headers[1].frame)
    for i = 1, 3 do below(cw.canvas.rows[i].button) end
    below(cw.canvas.headers[2].frame)
    below(cw.canvas.rows[4].button)
    assert.are.equal(canvasWidth - 20, cw.canvas.rows[1].button:GetWidth())
    assert.are.equal(cw.canvas.frame:GetHeight(), cw.scroll.scrollChild:GetHeight())
    assert.is_true(cw.canvas.frame:GetHeight() > -last)
  end)

  it("shows every entry's details under its title, and highlights the entry under the pointer", function()
    open()
    local row = cw.canvas.rows[1]
    assert.is_true(row.details:IsShown())
    assert.are.equal("Each theme now styles the group tabs to match its art.", row.details:GetText())
    assert.are.same({ "TOPLEFT", row.title, "BOTTOMLEFT", 0, -4 }, { row.details:GetPoint(1) })
    assert.are.equal(3 + row.title:GetStringHeight() + 4 + row.details:GetStringHeight() + 3, row.button:GetHeight())
    assert.are.equal("HIGHLIGHT", row.highlight:GetDrawLayer())
    assert.is_nil(row.button:GetScript("OnClick"))
    assert.is_nil(row.marker)
  end)

  it("shows an entry with no details as its title alone", function()
    open()
    local row = cw.canvas.rows[3]
    assert.is_false(row.details:IsShown())
    assert.are.equal(3 + row.title:GetStringHeight() + 3, row.button:GetHeight())
  end)

  it("puts the category tag first, and the title beside it", function()
    open()
    local row = cw.canvas.rows[1]
    assert.are.same({ "TOPLEFT", row.button, "TOPLEFT", 0, -3 }, { row.tag:GetPoint(1) })
    assert.are.same({ "TOPLEFT", row.button, "TOPLEFT", 70, -3 }, { row.title:GetPoint(1) })
  end)

  it("puts the checkbox at the bottom left and the Okay! button at the bottom right, under the scroll area", function()
    open()
    local body = cw.body.frame
    assert.are.same({ "BOTTOMLEFT", body, "BOTTOMLEFT", 4, 4 }, { cw.checkbox:GetPoint(1) })
    assert.are.equal("Don't show me this again", cw.checkboxLabel:GetText())
    assert.are.same({ "BOTTOMRIGHT", body, "BOTTOMRIGHT", -6, 6 }, { cw.okay:GetPoint(1) })
    assert.are.equal("Okay!", cw.okay:GetText())
    assert.are.same({ "BOTTOMRIGHT", body, "BOTTOMRIGHT", -10, 34 }, { cw.scroll.frame:GetPoint(2) })
    -- The list scrolls in the scroll area: the content box less the bottom row and the 10 pixels
    -- on the right.
    assert.are.same({ Width = 490, Height = 466 }, cw.body:PreRender({ Width = 500, Height = 500 }))
    assert.are.equal("Button", registered[cw.okay])
  end)

  it("turns opening on login off and on with its checkbox, and shows the setting when it opens", function()
    state.autoOpen = false
    open()
    assert.is_true(cw.checkbox:GetChecked())
    cw.checkbox:SetChecked(false)
    cw.checkbox:GetScript("OnClick")(cw.checkbox, "LeftButton")
    assert.is_true(state.autoOpen)
    cw.checkbox:SetChecked(true)
    cw.checkbox:GetScript("OnClick")(cw.checkbox, "LeftButton")
    assert.is_false(state.autoOpen)
  end)

  it("closes on Okay!, and closing it any way marks every bundled release seen", function()
    open()
    cw.okay:GetScript("OnClick")(cw.okay, "LeftButton")
    assert.is_false(cw.window.frame:IsShown())
    assert.are.equal(0, state.lastSeen)
    -- The spec frame mock does not fire OnHide; the client does on every hide (Escape, X, Okay!).
    cw.window.frame:GetScript("OnHide")(cw.window.frame)
    assert.are.equal(300, state.lastSeen)
  end)

  it("opens by itself after the first loading screen when allowed and something is unseen, once per session", function()
    events._eventMap.LOADING_SCREEN_DISABLED.fn("LOADING_SCREEN_DISABLED")
    advance()
    assert.is_true(cw.window.frame:IsShown())
    cw.window.frame:Hide()
    events._eventMap.LOADING_SCREEN_DISABLED.fn("LOADING_SCREEN_DISABLED")
    assert.is_false(cw.window.frame:IsShown())
  end)

  it("stays closed on login when the player turned that off, or has seen every release", function()
    state.autoOpen = false
    events._eventMap.LOADING_SCREEN_DISABLED.fn("LOADING_SCREEN_DISABLED")
    assert.is_nil(cw.window)
    ResetModuleStub("ChangelogWindow", "frames/changelog.lua")
    events:Init()
    LoadBetterBagsModule("frames/changelog.lua")
    cw = addon:GetModule("ChangelogWindow")
    cw:OnEnable()
    state.autoOpen, state.lastSeen = true, 300
    events._eventMap.LOADING_SCREEN_DISABLED.fn("LOADING_SCREEN_DISABLED")
    assert.is_nil(cw.window)
  end)

  it("opens when asked, even with nothing unseen", function()
    state.lastSeen = 300
    events:SendMessage(context:New("spec"), "changelog/Open")
    advance()
    assert.is_true(cw.window.frame:IsShown())
    assert.are.equal("v0.5.17", cw.canvas.headers[1].version:GetText())
  end)

  it("says so when there is nothing to show, and lists again when there is", function()
    data.releases = {}
    open()
    assert.is_true(cw.canvas.empty:IsShown())
    assert.are.equal("There are no changes to show yet.", cw.canvas.empty:GetText())
    cw.window.frame:Hide()
    data.releases = RELEASES
    open()
    assert.is_false(cw.canvas.empty:IsShown())
    assert.is_true(cw.canvas.rows[1].button:IsShown())
  end)
end)

teardown(function()
  for i = #createdStubs, 1, -1 do
    ResetModuleStub(createdStubs[i])
  end
end)
