-- form_spec.lua -- Forms (forms/form.lua) are Panel windows (window/window.lua): the window owns
-- the frame, its chrome, moving and fading; the form's scroll box and index fill the window's
-- content box, so a theme's insets decide where they sit.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")

local const = StubBetterBagsModule("Constants")
const.FORM_LAYOUT = const.FORM_LAYOUT or { STACKED = 1 }
const.BAG_KIND = const.BAG_KIND or { BACKPACK = 0, BANK = 1 }

local db = StubBetterBagsModule("Database")
local savedTheme, opacity = "Default", 70
local originals = { GetTheme = db.GetTheme, SetTheme = db.SetTheme, GetBagSizeInfo = db.GetBagSizeInfo, GetBagView = db.GetBagView }

local fonts = StubBetterBagsModule("Fonts")
fonts.UnitFrame12Yellow = fonts.UnitFrame12Yellow or CreateFont("BetterBagsFormSpecYellow")

local libWindow = LibStub:NewLibrary("LibWindow-1.1", 1) or LibStub("LibWindow-1.1")
libWindow.RegisterConfig = libWindow.RegisterConfig or function() end
libWindow.RestorePosition = libWindow.RestorePosition or function() end
libWindow.SavePosition = libWindow.SavePosition or function() end

local layouts, createdLayouts = StubBetterBagsModule("FormLayouts")
local madeLayouts = {}
local originalNewStacked = layouts.NewStackedLayout

LoadBetterBagsModule("render/render.lua")
LoadBetterBagsModule("render/drawable.lua")
LoadBetterBagsModule("sonata/engine.lua")
LoadBetterBagsModule("sonata/apply.lua")
LoadBetterBagsModule("sonata/decoration.lua")
LoadBetterBagsModule("window/window.lua")
ResetModuleStub("Form", "forms/form.lua")
LoadBetterBagsModule("forms/form.lua")

local sonata = addon:GetModule("Sonata")
local render = addon:GetModule("Render")
local form = addon:GetModule("Form")
local events = addon:GetModule("Events")
local context = addon:GetModule("Context")

describe("Form", function()
  local originalSend, originalThemes

  before_each(function()
    render:Init()
    originalThemes = sonata.themes
    sonata.themes = {}
    assert(loadfile("sonata/themes/base.lua"))("BetterBags")
    assert(loadfile("sonata/themes/default.lua"))("BetterBags")
    sonata:Init()
    savedTheme, opacity = "Default", 70
    db.GetTheme = function() return savedTheme end
    db.SetTheme = function(_, key) savedTheme = key end
    db.GetBagView = function() return 1 end
    db.GetBagSizeInfo = function(_, kind)
      assert.are.equal(const.BAG_KIND.BACKPACK, kind)
      return { opacity = opacity }
    end
    madeLayouts = {}
    layouts.NewStackedLayout = function(_, inner, base, scrollBox, index, tabbed)
      local l = { inner = inner, base = base, scrollBox = scrollBox, index = index, tabbed = tabbed, height = 0, underlines = 0 }
      function l:UpdateUnderline() self.underlines = self.underlines + 1 end
      table.insert(madeLayouts, l)
      return l
    end
    originalSend = events.SendMessage
    events.SendMessage = function() end
  end)

  after_each(function()
    events.SendMessage = originalSend
    sonata.themes = originalThemes
    layouts.NewStackedLayout = originalNewStacked
    for k, v in pairs(originals) do db[k] = v end
  end)

  teardown(function()
    if createdLayouts then ResetModuleStub("FormLayouts") end
    ResetModuleStub("Form", "forms/form.lua")
  end)

  local function newForm(title)
    return form:Create({ title = title or "Settings", layout = const.FORM_LAYOUT.STACKED, index = true, tabbed = true })
  end

  local function apply()
    sonata:ApplyTheme(context:New("spec"), "Default")
  end

  it("is a Panel window titled with the form's title, above the bags", function()
    local f = newForm("BetterBags Settings")
    assert.are.equal("Panel", f.window.kind)
    assert.are.equal(f.window.frame, f:GetFrame())
    assert.is_truthy(f.frame:GetName():find("^BetterBagsForm%d+BetterBags Settings$"))
    assert.are.equal("DIALOG", f.frame:GetFrameStrata())
    assert.are.equal(500, f.frame:GetFrameLevel())
    assert.are.equal("BetterBags Settings", f.window:GetTitle())
    assert.is_false(f.frame:IsShown())
  end)

  it("fills the window's content box with its scroll box, and hands the layout the content box", function()
    local f = newForm()
    apply()
    assert.are.equal(f.window.content, f.ScrollBox:GetParent())
    assert.are.same({ "TOPLEFT", f.window.content, "TOPLEFT", 0, 0 }, { f.ScrollBox:GetPoint(1) })
    assert.are.same({ "BOTTOMRIGHT", f.window.content, "BOTTOMRIGHT", 0, 0 }, { f.ScrollBox:GetPoint(2) })
    assert.are.same({ "TOPLEFT", f.window.content, "TOPRIGHT", -16, -6 }, { f.ScrollBar:GetPoint(1) })
    assert.are.same({ "BOTTOMLEFT", f.window.content, "BOTTOMRIGHT", -16, 2 }, { f.ScrollBar:GetPoint(2) })
    local l = madeLayouts[1]
    assert.are.equal(f.inner, l.inner)
    assert.are.equal(f.window.content, l.base)
    assert.are.equal(f.ScrollBox, l.scrollBox)
    assert.is_true(l.index)
    assert.is_true(l.tabbed)
  end)

  it("keeps the size its owner gives it, which the player cannot change", function()
    local f = newForm()
    f:GetFrame():SetSize(850, 800)
    apply()
    sonata:ApplyTheme(context:New("spec"), "Default")
    assert.are.same({ 850, 800 }, { f.frame:GetWidth(), f.frame:GetHeight() })
    assert.is_false(f.frame._resizable)
    assert.is_true(f.window.resizeGrip == nil or not f.window.resizeGrip:IsShown())
  end)

  it("fades in and out through its window, and moves when dragged", function()
    local f = newForm()
    apply()
    f:Show()
    assert.is_true(f.frame:IsShown())
    assert.is_true(f.window.showAnimation:IsPlaying())
    assert.are.equal(1, madeLayouts[1].underlines)
    f.window.showAnimation:_complete()
    f:Hide()
    assert.is_true(f.window:IsClosing())
    f.window.hideAnimation:_complete()
    assert.is_false(f.frame:IsShown())
    assert.is_true(f.frame._movable)
    assert.are.same({ "LeftButton" }, f.frame._registeredDrags)
  end)

  it("takes the backpack's opacity", function()
    local f = newForm()
    apply()
    assert.are.equal(70, f.window:GetOpacity())
    assert.are.equal(0.7, f.window.decoration:GetTemplateFrame().Bg:GetAlpha())
    opacity = 30
    sonata:UpdateOpacity()
    assert.are.equal(0.3, f.window.decoration:GetTemplateFrame().Bg:GetAlpha())
  end)
end)
