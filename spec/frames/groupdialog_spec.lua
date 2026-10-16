-- groupdialog_spec.lua -- The group dialog (frames/groupdialog.lua): the "New Group" / rename
-- dialog, a Panel window (window/window.lua) sized to its text through the render pipeline.
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

local L = trackStub("Localization")
L.G = L.G or function(_, text) return text end

local const = trackStub("Constants")
const.BAG_KIND = const.BAG_KIND or { BACKPACK = 0, BANK = 1 }

local db = trackStub("Database")
local savedTheme = "Default"
local originals = { GetTheme = db.GetTheme, SetTheme = db.SetTheme, GetBagSizeInfo = db.GetBagSizeInfo, GetBagView = db.GetBagView }

local fonts = trackStub("Fonts")
fonts.UnitFrame12Yellow = fonts.UnitFrame12Yellow or CreateFont("BetterBagsGroupDialogSpecYellow")

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

describe("GroupDialog", function()
  local groupDialog, originalSend, originalThemes, originalRegisterElement, savedEnum, savedWarbank
  local registered

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
    db.GetBagView = function() return 1 end
    db.GetBagSizeInfo = function() return { opacity = 60 } end
    originalSend = events.SendMessage
    events.SendMessage = function() end
    registered = {}
    originalRegisterElement = sonata.RegisterElement
    sonata.RegisterElement = function(self, kind, element)
      registered[element] = kind
      return originalRegisterElement(self, kind, element)
    end
    savedEnum, savedWarbank = _G.Enum.BankType, addon.hasWarbank
    _G.Enum.BankType = { Character = 0, Account = 2 }
    addon.hasWarbank = true
    sonata:ApplyTheme(context:New("spec"), "Default")
    ResetModuleStub("GroupDialog", "frames/groupdialog.lua")
    LoadBetterBagsModule("frames/groupdialog.lua")
    groupDialog = addon:GetModule("GroupDialog")
  end)

  after_each(function()
    events.SendMessage = originalSend
    sonata.RegisterElement = originalRegisterElement
    sonata.themes = originalThemes
    _G.Enum.BankType, addon.hasWarbank = savedEnum, savedWarbank
    for k, v in pairs(originals) do db[k] = v end
  end)

  teardown(function()
    ResetModuleStub("GroupDialog", "frames/groupdialog.lua")
  end)

  local function show(opts)
    opts = opts or {}
    groupDialog:Show(opts.title or "New Group", opts.text or "Name the group", opts.dropdown == true,
      opts.bankType, opts.onInput or function() end, opts.initial, opts.confirm)
  end

  it("is a titled Panel window above the settings, centered, with the backpack's opacity", function()
    show({ title = "Rename Group" })
    local w = groupDialog.window
    assert.are.equal("Panel", w.kind)
    assert.are.equal(groupDialog.frame, w.frame)
    assert.are.equal("BetterBagsGroupDialog", w.frame:GetName())
    assert.are.equal("Rename Group", w:GetTitle())
    assert.are.equal("DIALOG", w.frame:GetFrameStrata())
    assert.are.equal(600, w.frame:GetFrameLevel())
    assert.are.same({ "CENTER", UIParent, "CENTER", 0, 0 }, { w.frame:GetPoint(1) })
    assert.are.equal(60, w:GetOpacity())
    assert.is_true(w.frame:IsShown())
    assert.are.equal(1, w.frame:GetAlpha())
    assert.is_true(groupDialog.input:HasFocus())
  end)

  it("is as wide as before and as tall as its text, with room for the dropdown when it shows", function()
    show({ text = "Name the group" })
    local w = groupDialog.window
    local textHeight = groupDialog.text:GetStringHeight()
    assert.are.equal(250, groupDialog.text:GetWidth())
    assert.are.same({ 300, 120 + textHeight }, { w.frame:GetWidth(), w.frame:GetHeight() })
    groupDialog:Hide()
    show({ text = "Name the group", dropdown = true })
    assert.are.same({ 300, 150 + textHeight }, { w.frame:GetWidth(), w.frame:GetHeight() })
    assert.is_true(groupDialog.dropdown:IsShown())
  end)

  it("hands the name and bank type to its owner and closes", function()
    local got
    show({ dropdown = true, bankType = Enum.BankType.Account, onInput = function(name, bankType) got = { name, bankType } end })
    assert.are.equal("Warbank", UIDropDownMenu_GetText(groupDialog.dropdown))
    groupDialog.input:SetText("Herbs")
    groupDialog.yes:GetScript("OnClick")(groupDialog.yes, "LeftButton")
    assert.are.same({ "Herbs", Enum.BankType.Account }, got)
    assert.is_false(groupDialog.frame:IsShown())
  end)

  it("ignores an empty name, and closes on Cancel, Escape or its close button", function()
    local called = false
    show({ onInput = function() called = true end })
    groupDialog.input:GetScript("OnEnterPressed")(groupDialog.input)
    assert.is_false(called)
    assert.is_true(groupDialog.frame:IsShown())
    groupDialog.no:GetScript("OnClick")(groupDialog.no, "LeftButton")
    assert.is_false(groupDialog.frame:IsShown())
    show()
    assert.is_true(groupDialog.frame:IsShown())
    groupDialog.input:GetScript("OnEscapePressed")(groupDialog.input)
    assert.is_false(groupDialog.frame:IsShown())
    show()
    assert.is_true(groupDialog.frame:IsShown())
    local close = groupDialog.window.decoration:GetCloseButton()
    close:GetScript("OnClick")(close, "LeftButton")
    assert.is_false(groupDialog.frame:IsShown())
    -- The spec frame mock does not fire OnHide; the client does on every hide.
    groupDialog.frame:GetScript("OnHide")(groupDialog.frame)
    show()
    assert.is_true(groupDialog.frame:IsShown())
  end)

  it("opens again after being closed by any path, and only once at a time", function()
    show({ title = "First" })
    show({ title = "Second" })
    assert.are.equal("First", groupDialog.window:GetTitle())
    groupDialog.frame:Hide()
    groupDialog.frame:GetScript("OnHide")(groupDialog.frame)
    show({ title = "Third" })
    assert.are.equal("Third", groupDialog.window:GetTitle())
  end)

  it("pre-fills the name and labels the confirm button for a rename", function()
    show({ initial = "Old", confirm = "Rename" })
    assert.are.equal("Old", groupDialog.input:GetText())
    assert.are.equal("Rename", groupDialog.yes:GetText())
  end)

  it("offers the Warbank only where there is one", function()
    show({ dropdown = true })
    local labels = {}
    for _, info in ipairs(groupDialog.dropdown._dropdownButtons) do table.insert(labels, info.text) end
    assert.are.same({ "Bank", "Warbank" }, labels)
  end)

  it("styles its buttons and edit box through Sonata", function()
    show()
    assert.are.equal("Button", registered[groupDialog.yes])
    assert.are.equal("Button", registered[groupDialog.no])
    assert.are.equal("EditBox", registered[groupDialog.input])
  end)
end)

teardown(function()
  for i = #createdStubs, 1, -1 do
    ResetModuleStub(createdStubs[i])
  end
end)
