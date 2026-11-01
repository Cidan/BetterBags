-- coins_spec.lua -- NextCoins (next/coins.lua): the money a BetterBags Next footer shows (the shared money
-- frame, frames/money.lua, its own instance) on whole screen pixels (docs/next-pixel-perfect.md), its coins
-- and amounts by their corners, again whenever the amounts change.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
local events = addon:GetModule("Events")
events:Init()
local debug = StubBetterBagsModule("Debug")
debug.Log = function() end
local db = StubBetterBagsModule("Database")
local originalGetTheme = db.GetTheme
db.GetTheme = function() return "Default" end
UseSonataTextRoles()

ResetModuleStub("MoneyFrame", "frames/money.lua")
LoadBetterBagsModule("frames/money.lua")
ResetModuleStub("NextCoins", "next/coins.lua")
LoadBetterBagsModule("next/coins.lua")
local money = addon:GetModule("MoneyFrame")
local coins = addon:GetModule("NextCoins")
local pixel = addon:GetModule("NextPixel")
local layout = dofile("spec/helpers/layout.lua")

describe("NextCoins", function()
  local undo, window

  teardown(function()
    db.GetTheme = originalGetTheme
  end)

  before_each(function()
    UseSonataTextRoles()
    _G._playerMoney = 1234567
    -- The reporter's window at 65%: a unit is 1.153 pixels.
    undo = layout.UseScreen(3396, 1362, 0.65)
    window = CreateFrame("Frame", nil, UIParent)
    window:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    pixel:Size(window, 400, 100)
  end)

  after_each(function()
    undo()
  end)

  local function made()
    local m = money:Create(false)
    m.frame:SetParent(window)
    m.frame:ClearAllPoints()
    m.frame:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -pixel:Snap(window, 12), pixel:Snap(window, 5))
    return m
  end

  it("finds the shared money frame's coins between pixels where a unit is not a pixel", function()
    made()
    assert.is_true(#layout.PixelCheck(window) > 0)
  end)

  it("puts its coins and amounts on whole pixels, each by its corner", function()
    local m = made()
    coins:Fit(m)
    assert.are.same({}, layout.PixelCheck(window))
    local _, _, _, x = m.silverButton:GetPoint(1)
    assert.are.equal(-pixel:Snap(window, 4), x, "4 apart, rounded")
  end)

  describe("in a font of a theme's", function()
    local sonata = addon:GetModule("Sonata")
    local hand = CreateFont("SpecHandFont")
    hand:SetFont("Hand.ttf", 14, "")

    local function buttons(m)
      return { m.copperButton, m.silverButton, m.goldButton }
    end

    it("draws its amounts in it, on whole pixels", function()
      local m = made()
      coins:Fit(m)
      coins:Style(m, hand)
      for _, button in ipairs(buttons(m)) do
        assert.are.equal(hand, button:GetNormalFontObject())
      end
      assert.are.same({}, layout.PixelCheck(window))
    end)

    it("keeps them in it when the bags' theme makes new fonts", function()
      local m = made()
      coins:Fit(m)
      coins:Style(m, hand)
      sonata:newTextFonts()
      for _, button in ipairs(buttons(m)) do
        assert.are.equal(hand, button:GetNormalFontObject())
      end
    end)

    it("gives them back to the shared money frame's own role, which a theme moves again", function()
      local m = made()
      coins:Fit(m)
      coins:Style(m, hand)
      coins:Style(m, nil)
      for _, button in ipairs(buttons(m)) do
        assert.are.equal(sonata:GetTextFont("Money"), button:GetNormalFontObject())
      end
      sonata:newTextFonts()
      for _, button in ipairs(buttons(m)) do
        assert.are.equal(sonata:GetTextFont("Money"), button:GetNormalFontObject())
      end
    end)

    it("lets each amount take its text's width in the new font, and writes it again", function()
      local m = made()
      coins:Fit(m)
      local text = m.goldButton:GetFontString()
      text:SetWidth(40)
      m.goldButton:SetText("gone")
      coins:Style(m, hand)
      assert.are.equal(0, text._width or 0, "a font string keeps the width it was sized to through a font change")
      assert.are_not.equal("gone", m.goldButton:GetText())
    end)
  end)

  it("keeps them there when the amounts change, each button as wide as its amount and coin", function()
    local m = made()
    coins:Fit(m)
    _G._playerMoney = 99999999
    m:Update()
    assert.are.same({}, layout.PixelCheck(window))
    local coin = pixel:Length(window, 13)
    for _, b in ipairs({ m.goldButton, m.silverButton, m.copperButton }) do
      assert.is_true(math.abs(b:GetWidth() - (pixel:Ceil(b, b:GetTextWidth()) + coin)) < 1e-9)
    end
  end)

  it("leaves another money frame alone (the classic bags' own)", function()
    local other = made()
    local before = { other.copperButton:GetPoint(1) }
    coins:Fit(made())
    assert.are.same(before, { other.copperButton:GetPoint(1) })
  end)
end)
