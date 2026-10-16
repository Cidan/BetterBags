-- question_spec.lua -- Question dialogs (frames/question.lua): pooled Dialog windows
-- (window/window.lua) sized to their contents through the render pipeline. One question is
-- open at a time; its buttons and edit box are Sonata elements.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")

local db = StubBetterBagsModule("Database")
local savedTheme = "Default"
local originalGetTheme, originalSetTheme = db.GetTheme, db.SetTheme

local fonts = StubBetterBagsModule("Fonts")
fonts.UnitFrame12Yellow = fonts.UnitFrame12Yellow or CreateFont("BetterBagsQuestionSpecYellow")

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
ResetModuleStub("Question", "frames/question.lua")
LoadBetterBagsModule("frames/question.lua")

local sonata = addon:GetModule("Sonata")
local render = addon:GetModule("Render")
local question = addon:GetModule("Question")
local events = addon:GetModule("Events")
local context = addon:GetModule("Context")

describe("Question", function()
  local originalSend, originalThemes, originalRegisterElement
  local registered

  before_each(function()
    render:Init()
    originalThemes = sonata.themes
    sonata.themes = {}
    assert(loadfile("sonata/themes/base.lua"))("BetterBags")
    assert(loadfile("sonata/themes/default.lua"))("BetterBags")
    sonata:Init()
    savedTheme = "Default"
    db.GetTheme = function() return savedTheme end
    db.SetTheme = function(_, key) savedTheme = key end
    originalSend = events.SendMessage
    events.SendMessage = function() end
    registered = {}
    originalRegisterElement = sonata.RegisterElement
    sonata.RegisterElement = function(self, kind, element)
      table.insert(registered, { kind, element })
      return originalRegisterElement(self, kind, element)
    end
    sonata:ApplyTheme(context:New("spec"), "Default")
    question:OnEnable()
  end)

  after_each(function()
    events.SendMessage = originalSend
    sonata.RegisterElement = originalRegisterElement
    sonata.themes = originalThemes
    db.GetTheme, db.SetTheme = originalGetTheme, originalSetTheme
  end)

  teardown(function()
    ResetModuleStub("Question", "frames/question.lua")
  end)

  local function current()
    local q = next(question._pool.active)
    return q
  end

  it("asks yes or no in a titled Dialog window above the settings, centered", function()
    local answered
    question:YesNo("Delete", "Delete this group?", function() answered = "yes" end, function() answered = "no" end)
    local q = current()
    assert.are.equal("Dialog", q.window.kind)
    assert.are.equal("Delete", q.window:GetTitle())
    assert.are.equal("Delete", q.window.decoration:GetTemplateFrame().TitleContainer.TitleText:GetText())
    assert.are.equal("DIALOG", q.window.frame:GetFrameStrata())
    assert.are.equal(600, q.window.frame:GetFrameLevel())
    assert.are.same({ "CENTER", UIParent, "CENTER", 0, 0 }, { q.window.frame:GetPoint(1) })
    assert.is_nil(q.window.frame:GetScript("OnDragStart"))
    assert.is_true(q.window.frame:IsShown())
    assert.are.equal(1, q.window.frame:GetAlpha())
    assert.are.equal("Delete this group?", q.text:GetText())
    assert.is_true(q.yes:IsShown())
    assert.is_true(q.no:IsShown())
    assert.is_false(q.ok:IsShown())
    assert.is_false(q.input:IsShown())
    q.yes:GetScript("OnClick")(q.yes, "LeftButton")
    assert.are.equal("yes", answered)
    assert.is_false(q.window.frame:IsShown())
    assert.is_nil(current())
  end)

  it("is as wide as before and as tall as its text, buttons and padding", function()
    question:YesNo("T", "Short", function() end, function() end)
    local q = current()
    q.yes:SetHeight(22)
    q.body:Invalidate()
    render:RenderNow(q.window, { ctx = context:New("spec") })
    local textHeight = q.text:GetStringHeight()
    assert.are.equal(250, q.text:GetWidth())
    assert.are.equal(300, q.window.frame:GetWidth())
    assert.are.equal(textHeight + 22 + 110, q.window.frame:GetHeight())
  end)

  it("answers no", function()
    local answered
    question:YesNo("T", "Q", function() answered = "yes" end, function() answered = "no" end)
    local q = current()
    q.no:GetScript("OnClick")(q.no, "LeftButton")
    assert.are.equal("no", answered)
    assert.is_false(q.window.frame:IsShown())
  end)

  it("asks one question at a time", function()
    question:YesNo("First", "1", function() end, function() end)
    question:Alert("Second", "2")
    assert.are.equal(1, question._pool:GetNumActive())
    assert.are.equal("First", current().window:GetTitle())
  end)

  it("tells with an Okay button", function()
    question:Alert("Done", "It worked.")
    local q = current()
    assert.is_false(q.yes:IsShown())
    assert.is_false(q.no:IsShown())
    assert.is_true(q.ok:IsShown())
    q.ok:GetScript("OnClick")(q.ok, "LeftButton")
    assert.is_false(q.window.frame:IsShown())
  end)

  it("asks for input, and ignores an empty answer", function()
    local got = {}
    question:AskForInput("Name", "What name?", function(text) table.insert(got, text) end)
    local q = current()
    assert.is_true(q.input:IsShown())
    q.yes:GetScript("OnClick")(q.yes, "LeftButton")
    assert.are.same({}, got)
    question:AskForInput("Name", "What name?", function(text) table.insert(got, text) end)
    q = current()
    q.input:SetText("Herbs")
    q.input:GetScript("OnEnterPressed")(q.input)
    assert.are.same({ "Herbs" }, got)
    question:AskForInput("Name", "What name?", function(text) table.insert(got, text) end)
    q = current()
    q.input:GetScript("OnEscapePressed")(q.input)
    assert.is_false(q.window.frame:IsShown())
    assert.are.same({ "Herbs" }, got)
  end)

  it("reuses a dialog it released, cleared", function()
    question:AskForInput("Name", "What name?", function() end)
    local first = current()
    first.input:SetText("left over")
    first.no:GetScript("OnClick")(first.no, "LeftButton")
    question:YesNo("Again", "Q", function() end, function() end)
    local second = current()
    assert.are.equal(first, second)
    assert.are.equal("", second.input:GetText())
    assert.are.equal("Again", second.window:GetTitle())
  end)

  it("styles its buttons and edit box through Sonata", function()
    question:YesNo("T", "Q", function() end, function() end)
    local q = current()
    local kinds = {}
    for _, entry in ipairs(registered) do
      kinds[entry[2]] = entry[1]
    end
    assert.are.equal("Button", kinds[q.yes])
    assert.are.equal("Button", kinds[q.no])
    assert.are.equal("Button", kinds[q.ok])
    assert.are.equal("EditBox", kinds[q.input])
  end)
end)
