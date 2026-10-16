-- search_overlay_spec.lua -- The overlay search panel (frames/search.lua, searchBox:Create): the
-- box the search keybinding toggles above the backpack. It is a Search window
-- (window/window.lua) of a fixed size, drawn and animated by the theme (sonata.md section 3b).
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

local const = stubModule("Constants")
const.BAG_KIND = const.BAG_KIND or { UNDEFINED = -1, BACKPACK = 0, BANK = 1 }
local database = stubModule("Database")
local search = stubModule("Search")
stubModule("SearchCategoryConfig")
local fonts = stubModule("Fonts")
fonts.UnitFrame12Yellow = fonts.UnitFrame12Yellow or CreateFont("BetterBagsSearchOverlaySpecYellow")

local libWindow = LibStub:NewLibrary("LibWindow-1.1", 1) or LibStub("LibWindow-1.1")
libWindow.RegisterConfig = libWindow.RegisterConfig or function() end
libWindow.RestorePosition = libWindow.RestorePosition or function() end
libWindow.SavePosition = libWindow.SavePosition or function() end

ResetModuleStub("Animations", "animations/fade.lua")
LoadBetterBagsModule("animations/fade.lua")
LoadBetterBagsModule("render/render.lua")
LoadBetterBagsModule("render/drawable.lua")
LoadBetterBagsModule("sonata/engine.lua")
LoadBetterBagsModule("sonata/apply.lua")
LoadBetterBagsModule("sonata/decoration.lua")
LoadBetterBagsModule("window/window.lua")
ResetModuleStub("SearchBox", "frames/search.lua")
LoadBetterBagsModule("frames/search.lua")

local sonata = addon:GetModule("Sonata")
local render = addon:GetModule("Render")
local searchBox = addon:GetModule("SearchBox")

describe("the overlay search panel", function()
  local saved, originalThemes, savedBags, bagShows, searches, resets, parent

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  before_each(function()
    saved = {}
    render:Init()
    originalThemes = sonata.themes
    sonata.themes = {}
    assert(loadfile("sonata/themes/base.lua"))("BetterBags")
    assert(loadfile("sonata/themes/default.lua"))("BetterBags")
    sonata:Init()
    override(database, "GetTheme", function() return "Default" end)
    override(database, "SetTheme", function() end)
    override(database, "GetEnterToMakeCategory", function() return false end)
    override(search, "Search", function(_, text) return { query = text } end)
    sonata:ApplyTheme(context:New("spec"), "Default")
    bagShows, searches, resets = 0, {}, 0
    savedBags = addon.Bags
    addon.Bags = { Backpack = {
      Show = function() bagShows = bagShows + 1 end,
      Search = function(_, _, results) table.insert(searches, results.query) end,
      ResetSearch = function() resets = resets + 1 end,
    } }
    parent = CreateFrame("Frame", nil, UIParent)
  end)

  after_each(function()
    sonata.themes = originalThemes
    addon.Bags = savedBags
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
  end)

  teardown(function()
    ResetModuleStub("SearchBox", "frames/search.lua")
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  local function create()
    return searchBox:Create(context:New("spec"), parent)
  end

  it("is a Search window of a fixed size above the backpack, hidden until toggled", function()
    local sf = create()
    local w = sf.window
    assert.are.equal("Search", w.kind)
    assert.are.equal(w.frame, sf.frame)
    assert.are.equal("BetterBagsSearchFrame", w.frame:GetName())
    assert.are.equal("HIGH", w.frame:GetFrameStrata())
    assert.are.equal(700, w.frame:GetFrameLevel())
    assert.are.same({ 400, 75 }, { w.frame:GetWidth(), w.frame:GetHeight() })
    assert.is_false(w.frame._resizable)
    assert.are.same({ "BOTTOM", parent, "TOP", 0, 10 }, { w.frame:GetPoint(1) })
    assert.is_nil(w.frame:GetScript("OnDragStart"))
    assert.is_false(w.frame:IsShown())
    assert.are.equal(sf, searchBox.searchFrame)
  end)

  it("lays its box and labels out in the window's content box", function()
    local sf = create()
    local content = sf.window.content
    assert.are.equal(content, sf.textBox:GetParent())
    assert.are.same({ "TOPLEFT", content, "TOPLEFT", 0, 0 }, { sf.textBox:GetPoint(1) })
    assert.are.same({ "BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0 }, { sf.textBox:GetPoint(2) })
    assert.are.same({ "BOTTOMRIGHT", content, "BOTTOMRIGHT", 6, 6 }, { sf.enterLabel:GetPoint(1) })
  end)

  it("opens the backpack and fades in, focusing the box once shown", function()
    local sf = create()
    sf:Toggle(context:New("spec"))
    assert.are.equal(1, bagShows)
    assert.is_true(sf.frame:IsShown())
    assert.is_true(sf.window.showAnimation:IsPlaying())
    assert.is_false(sf.textBox:HasFocus())
    sf.window.showAnimation:_complete()
    assert.is_true(sf.textBox:HasFocus())
  end)

  it("fades out on the next toggle, then empties the box and shows its help again", function()
    local sf = create()
    sf:Toggle(context:New("spec"))
    sf.window.showAnimation:_complete()
    sf.textBox:SetText("herb")
    sf.helpText:Hide()
    sf:Toggle(context:New("spec"))
    assert.is_true(sf.window:IsClosing())
    assert.is_false(sf.textBox:HasFocus())
    sf.window.hideAnimation:_complete()
    assert.is_false(sf.frame:IsShown())
    assert.are.equal("", sf.textBox:GetText())
    assert.is_true(sf.helpText:IsShown())
  end)

  it("closes with the other special windows, and when the backpack closes", function()
    local sf = create()
    sf:Toggle(context:New("spec"))
    sf.window.showAnimation:_complete()
    events:SendMessage(context:New("spec"), "addon/CloseSpecialWindows")
    assert.is_true(sf.window:IsClosing())
    sf.window.hideAnimation:_complete()
    sf:Toggle(context:New("spec"))
    sf.window.showAnimation:_complete()
    sf:Hide()
    assert.is_true(sf.window:IsClosing())
  end)

  it("searches both bags as the player types", function()
    local sf = create()
    sf:Toggle(context:New("spec"))
    sf.textBox:SetText("herb")
    sf.textBox:GetScript("OnTextChanged")(sf.textBox, true)
    assert.are.same({ "herb" }, searches)
    sf.textBox:SetText("")
    sf.textBox:GetScript("OnTextChanged")(sf.textBox, true)
    assert.are.equal(1, resets)
  end)
end)
