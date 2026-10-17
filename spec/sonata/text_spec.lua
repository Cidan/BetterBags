-- text_spec.lua -- Sonata's text roles (sonata/engine.lua, sonata/themes/base.lua): the fonts of
-- BetterBags' own text in windows and on the bag are font objects, one per role of the theme's
-- Text table, restyled on every theme switch; text set to a role follows it.
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

local db = trackStub("Database")
trackStub("Fonts")
local savedTheme = "Default"
local originalGetTheme, originalSetTheme = db.GetTheme, db.SetTheme

LoadBetterBagsModule("sonata/engine.lua")
LoadBetterBagsModule("sonata/apply.lua")
local sonata = addon:GetModule("Sonata")
local context = addon:GetModule("Context")
local events = addon:GetModule("Events")

local FLAGS = { "isRetail", "isForever", "isClassic", "isBCC", "isMists", "isAnniversary", "isCata" }

describe("Sonata text roles", function()
  local originalThemes, originalSend, savedFlags

  before_each(function()
    originalThemes = sonata.themes
    sonata.themes = {}
    sonata:Init()
    savedTheme = "Default"
    db.GetTheme = function() return savedTheme end
    db.SetTheme = function(_, key) savedTheme = key end
    originalSend = events.SendMessage
    events.SendMessage = function() end
    savedFlags = {}
    for _, flag in ipairs(FLAGS) do savedFlags[flag] = addon[flag] end
    addon.isRetail, addon.isForever, addon.isClassic = true, false, false
    assert(loadfile("sonata/themes/base.lua"))("BetterBags")
    sonata:RegisterTheme({ Name = "Default" })
  end)

  after_each(function()
    sonata.themes = originalThemes
    events.SendMessage = originalSend
    db.GetTheme, db.SetTheme = originalGetTheme, originalSetTheme
    for _, flag in ipairs(FLAGS) do addon[flag] = savedFlags[flag] end
  end)

  teardown(function()
    for i = #createdStubs, 1, -1 do
      ResetModuleStub(createdStubs[i])
    end
  end)

  local function apply(key)
    sonata:ApplyTheme(context:New("spec"), key)
  end

  local function color(font)
    local r, g, b, a = font:GetTextColor()
    return { r, g, b, a }
  end

  local function shadow(font)
    local r, g, b, a = font:GetShadowColor()
    local x, y = font:GetShadowOffset()
    return { r, g, b, a, x, y }
  end

  it("makes one font object per role, uniquely named, styled from the current theme", function()
    local body = sonata:GetTextFont("Body")
    assert.are.equal(body, sonata:GetTextFont("Body"))
    assert.is_truthy(body:GetName():match("^BetterBagsTextBody%d+$"))
    assert.are.same({ GameFontHighlight:GetFont() }, { body:GetFont() })
    assert.are.same({ 1, 1, 1, 1 }, color(body))
    assert.are.same({ 0, 0, 0, 1, 1, -1 }, shadow(body))
  end)

  -- Base gives every role the look its text had before roles: the client font object it used
  -- and its color, so every theme that does not change them looks as before.
  it("gives every role the look BetterBags' text had", function()
    local GOLD, WHITE = { 1, 0.82, 0, 1 }, { 1, 1, 1, 1 }
    local SOFT, MUTED = { 0.75, 0.75, 0.75, 1 }, { 0.6, 0.6, 0.6, 1 }
    local HOVER = { 1, 0.9, 0.5, 1 }
    local SHADOW, GLOW = { 0, 0, 0, 1, 1, -1 }, { 1, 0.8, 0.3, 0.8, 0, 0 }
    local expected = {
      Heading = { GameFontNormalLarge, WHITE, SHADOW },
      Title = { GameFontNormalLarge, GOLD, SHADOW },
      Label = { GameFontNormalLarge, SOFT, SHADOW },
      Description = { GameFontHighlight, SOFT, SHADOW },
      Body = { GameFontHighlight, WHITE, SHADOW },
      BodySmall = { GameFontHighlightSmall, WHITE, SHADOW },
      BodyLarge = { GameFontNormalLarge, WHITE, SHADOW },
      FieldSmall = { GameFontNormalSmall, GOLD, SHADOW },
      MutedSmall = { GameFontNormalSmall, MUTED, SHADOW },
      Search = { GameFontNormalHuge, WHITE, SHADOW },
      Field = { GameFontNormal, GOLD, SHADOW },
      Muted = { GameFontNormal, MUTED, SHADOW },
      Empty = { GameFontNormalLarge, MUTED, SHADOW },
      Positive = { GameFontHighlight, { 0.2, 0.8, 0.2, 1 }, SHADOW },
      Negative = { GameFontHighlight, { 1, 0.125, 0.125, 1 }, SHADOW },
      Nav = { GameFontNormalLarge, WHITE, SHADOW },
      NavHover = { GameFontNormalLarge, HOVER, GLOW },
      NavActive = { GameFontNormalLarge, GOLD, GLOW },
      NavSub = { GameFontNormal, WHITE, SHADOW },
      NavSubHover = { GameFontNormal, HOVER, GLOW },
      NavSubActive = { GameFontNormal, GOLD, GLOW },
      Count = { Number12Font, WHITE, { 0, 0, 0, 0, 0, 0 } },
      Money = { Number12Font, WHITE, { 0, 0, 0, 0, 0, 0 } },
    }
    apply("Default")
    for role, want in pairs(expected) do
      local font = sonata:GetTextFont(role)
      assert.are.same({ want[1]:GetFont() }, { font:GetFont() }, role)
      assert.are.same(want[2], color(font), role)
      assert.are.same(want[3], shadow(font), role)
    end
  end)

  -- A font object is styled once, when it is made, and never changed: a font object changed
  -- while text used it left that text out of step once the text switched font objects
  -- (hovering a settings entry changed its size). A theme makes new font objects and moves its
  -- text to them.
  it("moves text to new font objects when a theme is applied, leaving the old ones unchanged", function()
    local text = sonata:CreateText(UIParent, "Body")
    local heading = sonata:CreateText(UIParent, "Heading", "ARTWORK")
    assert.are.equal("ARTWORK", heading._drawLayer)
    local defaultBody = sonata:GetTextFont("Body")
    assert.are.equal(defaultBody, text:GetFontObject())
    sonata:RegisterTheme({
      Name = "Paper",
      Variables = {
        TextColor = { 0.1, 0.2, 0.3, 1 },
        TextShadow = { Color = { 0, 0, 0, 0 }, X = 0, Y = 0 },
      },
    })
    apply("Paper")
    local paperBody = sonata:GetTextFont("Body")
    assert.are_not.equal(defaultBody, paperBody)
    assert.are.equal(paperBody, text:GetFontObject())
    assert.are.equal(sonata:GetTextFont("Heading"), heading:GetFontObject())
    assert.are.same({ 0.1, 0.2, 0.3, 1 }, { text:GetTextColor() })
    assert.are.same({ 0.1, 0.2, 0.3, 1 }, { heading:GetTextColor() })
    assert.are.same({ 0, 0, 0, 0, 0, 0 }, shadow(paperBody))
    assert.are.same({ 1, 1, 1, 1 }, color(defaultBody))
    apply("Default")
    assert.are_not.equal(paperBody, text:GetFontObject())
    assert.are.same({ 1, 1, 1, 1 }, { text:GetTextColor() })
    assert.are.same({ 0.1, 0.2, 0.3, 1 }, color(paperBody))
  end)

  it("never changes a font object once it is made, through theme switches and text rescales", function()
    local originalCreateFont = _G.CreateFont
    local made = {}
    _G.CreateFont = function(name)
      local font = originalCreateFont(name)
      table.insert(made, font)
      return font
    end
    local function freeze()
      for _, font in ipairs(made) do
        for _, method in ipairs({ "SetFont", "SetFontHeight", "SetFontObject", "CopyFontObject", "SetTextColor",
          "SetShadowColor", "SetShadowOffset", "SetJustifyH" }) do
          font[method] = function() error("a font object was changed after it was made: " .. method) end
        end
      end
    end
    sonata:RegisterTheme({ Name = "Paper", Variables = { TextColor = { 0.1, 0.2, 0.3, 1 } } })
    sonata.textFonts = {}
    local ok, err = pcall(function()
      sonata:CreateText(UIParent, "Body")
      sonata:CreateText(UIParent, "Nav")
      freeze()
      apply("Paper")
      freeze()
      EventRegistry:TriggerEvent("TextSizeManager.OnTextScaleUpdated", 1)
      freeze()
      apply("Default")
    end)
    _G.CreateFont = originalCreateFont
    sonata.textFonts = {}
    assert.is_true(ok, tostring(err))
  end)

  it("moves a button's text to the new font object for its role when a theme is applied", function()
    local button = CreateFrame("Button", nil, UIParent)
    sonata:SetButtonTextRole(button, "Money")
    local before = button:GetNormalFontObject()
    assert.are.equal(sonata:GetTextFont("Money"), before)
    sonata:RegisterTheme({ Name = "Paper", Variables = { TextColor = { 0.1, 0.2, 0.3, 1 } } })
    apply("Paper")
    assert.are_not.equal(before, button:GetNormalFontObject())
    assert.are.equal(sonata:GetTextFont("Money"), button:GetNormalFontObject())
    assert.are.same({ 0.1, 0.2, 0.3, 1 }, color(button:GetNormalFontObject()))
  end)

  it("leaves text on its font object when the new theme has no such role", function()
    local text = sonata:CreateText(UIParent, "Body")
    local before = text:GetFontObject()
    sonata:RegisterTheme({ Name = "Bare", Text = { Body = false } })
    apply("Bare")
    assert.are.equal(before, text:GetFontObject())
  end)

  it("switches text between roles", function()
    local text = sonata:CreateText(UIParent, "Nav")
    sonata:SetTextRole(text, "NavActive")
    assert.are.equal(sonata:GetTextFont("NavActive"), text:GetFontObject())
    assert.are.same({ 1, 0.82, 0, 1 }, { text:GetTextColor() })
  end)

  -- Text sized to its content keeps its size when its font changes (a button's font string,
  -- Blizzard's QuestLogTitleButton_Resize), so its owner refits it after every font change.
  it("calls a watched text back after every change of its font: a role, a theme, the client's text size", function()
    local text = sonata:CreateText(UIParent, "Nav")
    local fonts = {}
    sonata:WatchTextFont(text, function(t)
      assert.are.equal(text, t)
      table.insert(fonts, t:GetFontObject())
    end)
    sonata:SetTextRole(text, "NavHover")
    assert.are.same({ sonata:GetTextFont("NavHover") }, fonts)
    sonata:RegisterTheme({ Name = "Paper", Variables = { TextColor = { 0.1, 0.2, 0.3, 1 } } })
    apply("Paper")
    assert.are.equal(2, #fonts)
    assert.are.equal(sonata:GetTextFont("NavHover"), fonts[2])
    EventRegistry:TriggerEvent("TextSizeManager.OnTextScaleUpdated", 1)
    assert.are.equal(3, #fonts)
    assert.are.equal(text:GetFontObject(), fonts[3])
    local other = sonata:CreateText(UIParent, "Body")
    sonata:SetTextRole(other, "Heading")
    assert.are.equal(3, #fonts)
  end)

  it("lets a theme restyle one role, keeping the rest", function()
    sonata:RegisterTheme({ Name = "Green", Text = { Field = { Color = { 0, 1, 0, 1 } } } })
    apply("Green")
    assert.are.same({ 0, 1, 0, 1 }, color(sonata:GetTextFont("Field")))
    assert.are.same({ GameFontNormal:GetFont() }, { sonata:GetTextFont("Field"):GetFont() })
    assert.are.same({ 1, 0.82, 0, 1 }, color(sonata:GetTextFont("Title")))
  end)

  -- The bag's money used NumberFontNormalRight outside retail (frames/money.lua).
  it("draws money in NumberFontNormalRight on Classic", function()
    addon.isRetail, addon.isClassic = false, true
    apply("Default")
    local money = sonata:GetTextFont("Money")
    assert.are.same({ NumberFontNormalRight:GetFont() }, { money:GetFont() })
    assert.are.equal("RIGHT", money:GetJustifyH())
    assert.are.same({ Number12Font:GetFont() }, { sonata:GetTextFont("Count"):GetFont() })
  end)

  -- Blizzard rescales its fonts (the Text Size setting) after VARIABLES_LOADED and whenever the
  -- setting changes (TextSizeManager.lua). Role fonts are copies, so the rescale makes new ones,
  -- and the text moves to them.
  it("makes new role fonts at the client's sizes when the client rescales its fonts", function()
    local height = GameFontNormalLarge:GetFontHeight()
    local text = sonata:CreateText(UIParent, "Nav")
    local before = text:GetFontObject()
    GameFontNormalLarge:SetFontHeight(20)
    EventRegistry:TriggerEvent("TextSizeManager.OnTextScaleUpdated", 1.25)
    local after = text:GetFontObject()
    local hover = sonata:GetTextFont("NavHover")
    GameFontNormalLarge:SetFontHeight(height)
    EventRegistry:TriggerEvent("TextSizeManager.OnTextScaleUpdated", 1)
    assert.are_not.equal(before, after)
    assert.are.equal(20, select(2, after:GetFont()))
    assert.are.equal(20, select(2, hover:GetFont()))
    assert.are.equal(height, select(2, before:GetFont()))
    assert.are.equal(height, select(2, text:GetFontObject():GetFont()))
  end)

  -- A role font is a copy of its client font (CopyFontObject), as Blizzard makes its own runtime
  -- font objects (FontableFrameMixin.lua), never one that inherits from it (Font:SetFontObject).
  it("makes each role font a copy of its client font, never one that inherits from it", function()
    local originalCreateFont = _G.CreateFont
    sonata:Init()
    _G.CreateFont = function(name)
      local font = originalCreateFont(name)
      font.SetFontObject = function() error("a role font must not inherit from another font") end
      return font
    end
    local ok, result = pcall(function() return sonata:GetTextFont("MutedSmall") end)
    local appliedOk, appliedErr = pcall(function() sonata:ApplyTheme(context:New("spec"), "Default") end)
    _G.CreateFont = originalCreateFont
    assert.is_true(ok, tostring(result))
    assert.is_true(appliedOk, tostring(appliedErr))
    assert.are.same({ GameFontNormalSmall:GetFont() }, { result:GetFont() })
  end)

  it("listens for the client's text size changes once, however often it is initialized", function()
    local calls = 0
    local original = sonata.newTextFonts
    sonata.newTextFonts = function(self) calls = calls + 1; return original(self) end
    sonata:Init()
    sonata:Init()
    EventRegistry:TriggerEvent("TextSizeManager.OnTextScaleUpdated", 1)
    sonata.newTextFonts = original
    assert.are.equal(1, calls)
  end)

  it("errors on a role no theme defines", function()
    assert.has_error(function() sonata:GetTextFont("Nonsense") end, "unknown text role: Nonsense")
  end)
end)
