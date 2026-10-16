-- searchcategory_spec.lua -- The search category editor (frames/searchcategory.lua): a Dialog
-- window (window/window.lua) of a fixed size the player can move, opened next to the frame
-- that asked for it, fading in and out with the theme.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")

-- Stubs this file creates are removed after it (the teardown at the end), so a later spec
-- file can load the real modules.
local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local const = trackStub("Constants")
const.SEARCH_CATEGORY_GROUP_BY = const.SEARCH_CATEGORY_GROUP_BY or { NONE = 0, TYPE = 1, SUBTYPE = 2, EXPANSION = 3 }

local db = trackStub("Database")
local savedTheme = "Default"
local originalGetTheme, originalSetTheme = db.GetTheme, db.SetTheme

local fonts = trackStub("Fonts")
fonts.UnitFrame12Yellow = fonts.UnitFrame12Yellow or CreateFont("BetterBagsSearchCategorySpecYellow")

local categories, createdCategories = StubBetterBagsModule("Categories")

local libWindow = LibStub:NewLibrary("LibWindow-1.1", 1) or LibStub("LibWindow-1.1")
libWindow.RegisterConfig = libWindow.RegisterConfig or function() end
libWindow.RestorePosition = libWindow.RestorePosition or function() end
libWindow.SavePosition = libWindow.SavePosition or function() end

LoadBetterBagsModule("render/render.lua")
LoadBetterBagsModule("render/drawable.lua")
LoadBetterBagsModule("sonata/engine.lua")
LoadBetterBagsModule("sonata/apply.lua")
LoadBetterBagsModule("sonata/decoration.lua")
LoadBetterBagsModule("window/window.lua")

local sonata = addon:GetModule("Sonata")
local render = addon:GetModule("Render")
local events = addon:GetModule("Events")
local context = addon:GetModule("Context")

describe("SearchCategoryConfig", function()
  local config, originalSend, originalThemes, originalRegisterElement, savedRetail
  local sent, created, deleted, registered

  before_each(function()
    render:Init()
    originalThemes = sonata.themes
    sonata.themes = {}
    sonata:Init()
    assert(loadfile("sonata/themes/base.lua"))("BetterBags")
    assert(loadfile("sonata/themes/default.lua"))("BetterBags")
    savedTheme = "Default"
    db.GetTheme = function() return savedTheme end
    db.SetTheme = function(_, key) savedTheme = key end
    sent, created, deleted, registered = {}, {}, {}, {}
    originalSend = events.SendMessage
    events.SendMessage = function(_, _, message, payload) table.insert(sent, { message, payload }) end
    categories.DoesCategoryExist = function() return false end
    categories.CreateCategory = function(_, _, filter) table.insert(created, filter) end
    categories.DeleteCategory = function(_, _, name) table.insert(deleted, name) end
    originalRegisterElement = sonata.RegisterElement
    sonata.RegisterElement = function(self, kind, element)
      registered[element] = kind
      return originalRegisterElement(self, kind, element)
    end
    savedRetail = addon.isRetail
    addon.isRetail = true
    sonata:ApplyTheme(context:New("spec"), "Default")
    ResetModuleStub("SearchCategoryConfig", "frames/searchcategory.lua")
    LoadBetterBagsModule("frames/searchcategory.lua")
    config = addon:GetModule("SearchCategoryConfig")
    config:OnEnable()
  end)

  after_each(function()
    events.SendMessage = originalSend
    sonata.RegisterElement = originalRegisterElement
    sonata.themes = originalThemes
    addon.isRetail = savedRetail
    db.GetTheme, db.SetTheme = originalGetTheme, originalSetTheme
  end)

  teardown(function()
    ResetModuleStub("SearchCategoryConfig", "frames/searchcategory.lua")
    if createdCategories then ResetModuleStub("Categories") end
  end)

  local function filter(name, query)
    return { name = name, priority = 10, searchCategory = { query = query or "type = weapon" } }
  end

  it("is a titled Dialog window of a fixed size, above the bags, that the player can move", function()
    local w = config.window
    assert.are.equal("Dialog", w.kind)
    assert.are.equal(config.frame, w.frame)
    assert.are.equal("BetterBagsSearchCategoryConfig", w.frame:GetName())
    assert.are.equal("Configure Search Category", w:GetTitle())
    assert.are.equal("DIALOG", w.frame:GetFrameStrata())
    assert.are.same({ 430, 450 }, { w.frame:GetWidth(), w.frame:GetHeight() })
    assert.is_false(w.frame._resizable)
    assert.is_true(w.frame._movable)
    assert.is_false(w.frame:IsShown())
  end)

  it("lays its fields out in the window's content box", function()
    local content = config.window.content
    assert.are.same({ "TOPLEFT", content, "TOPLEFT", 15, -15 }, { config.nameBoxLabel:GetPoint(1) })
    assert.are.same({ "BOTTOMRIGHT", content, "BOTTOMRIGHT", -15, 15 }, { config.saveButton:GetPoint(1) })
    assert.are.equal(390, config.errorText:GetWidth())
  end)

  it("opens next to the frame that asked, fading in, then focuses the name", function()
    local anchor = CreateFrame("Frame")
    config:Open(filter("Weapons"), anchor)
    local w = config.window
    assert.are.same({ "TOPRIGHT", anchor, "TOPLEFT", -10, 0 }, { w.frame:GetPoint(1) })
    assert.is_true(w.frame:IsShown())
    assert.is_true(w.showAnimation:IsPlaying())
    assert.is_false(config.nameBox:HasFocus())
    w.showAnimation:_complete()
    assert.is_true(config.nameBox:HasFocus())
    assert.are.equal("Weapons", config.nameBox:GetText())
    assert.are.equal("type = weapon", config.queryBox.EditBox:GetText())
  end)

  it("opens in the middle of the screen with no frame, and closes when opened again for the same category", function()
    config:Open(filter("Weapons"))
    local w = config.window
    assert.are.same({ "CENTER", UIParent, "CENTER", 0, 0 }, { w.frame:GetPoint(1) })
    w.showAnimation:_complete()
    config:Open(filter("Weapons"))
    assert.is_true(w:IsClosing())
    w.hideAnimation:_complete()
    assert.is_false(config:IsShown())
  end)

  it("saves the category, recalculates the bags and closes", function()
    config:Open(filter("Weapons"))
    config.window.showAnimation:_complete()
    config.nameBox:SetText("Swords")
    config.queryBox.EditBox:SetText("type = sword")
    config.priorityBox:SetText("5")
    config.errorText:SetText("")
    config.saveButton:GetScript("OnClick")(config.saveButton, "LeftButton")
    assert.are.equal("Swords", created[1].name)
    assert.are.equal("type = sword", created[1].searchCategory.query)
    assert.are.equal(5, created[1].priority)
    assert.are.same({ "Weapons" }, deleted)
    assert.are.same({ "bags/Rederive", { resetLayout = true, buttons = true } }, sent[#sent])
    assert.is_true(config.window:IsClosing())
  end)

  it("closes on Cancel, and calls back once closed", function()
    config:Open(filter("Weapons"))
    config.window.showAnimation:_complete()
    config.cancelButton:GetScript("OnClick")(config.cancelButton, "LeftButton")
    assert.is_true(config.window:IsClosing())
    config.window.hideAnimation:_complete()
    config:Open(filter("Armor"))
    config.window.showAnimation:_complete()
    local closed = false
    config:Close(function() closed = true end)
    assert.is_false(closed)
    config.window.hideAnimation:_complete()
    assert.is_true(closed)
  end)

  it("styles its fields and buttons through Sonata", function()
    assert.are.equal("EditBox", registered[config.nameBox])
    assert.are.equal("EditBox", registered[config.priorityBox])
    assert.are.equal("Button", registered[config.saveButton])
    assert.are.equal("Button", registered[config.cancelButton])
  end)
end)

teardown(function()
  for i = #createdStubs, 1, -1 do
    ResetModuleStub(createdStubs[i])
  end
end)
