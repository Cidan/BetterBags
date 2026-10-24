-- dockcard_spec.lua -- NextDockCard (next/dockcard.lua): the card a dragged section waits in to be
-- confirmed (NextDrag's dock) and the vendor's destroy card (automation.md §4) share, so both look
-- alike: the theme's Dock fill, glowing edge and halo, which pulse, and its title, warning and hint.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

ResetModuleStub("NextStyle", "next/style.lua")
LoadBetterBagsModule("next/style.lua")
ResetModuleStub("NextDockCard", "next/dockcard.lua")
LoadBetterBagsModule("next/dockcard.lua")
local dockCard = addon:GetModule("NextDockCard")
local style = addon:GetModule("NextStyle")

describe("NextDockCard", function()
  local parent

  before_each(function()
    UseNextTheme(nil)
    parent = CreateFrame("Frame")
    parent:Show()
  end)

  after_each(function()
    UseNextTheme(nil)
  end)

  it("draws the theme's dock: its fill, its edge outside the card, its halo, its fonts", function()
    local D = style.Theme.Dock
    local c = dockCard:Create(parent)
    local fill = c.background._colorTexture
    local r, g, b, a = style:RGBA(D.Card.Color)
    assert.are.same({ r, g, b, a }, { fill.r, fill.g, fill.b, fill.a })
    local w = D.Glow.Width
    assert.are.equal(w, c.glow[1]:GetHeight())
    assert.are.equal(w, c.glow[3]:GetWidth())
    assert.are.same({ "TOPLEFT", c.frame, "TOPLEFT", -w, w }, { c.glow[1]:GetPoint(1) })
    local gr, gg, gb = c.glow[1]:GetVertexColor()
    local er, eg, eb = style:RGBA(D.Glow.Color)
    assert.are.same({ er, eg, eb }, { gr, gg, gb })
    assert.is_true(c.halo:IsShown())
    assert.are.same({ "TOPLEFT", c.frame, "TOPLEFT", -D.Halo.Spread, D.Halo.Spread }, { c.halo:GetPoint(1) })
    assert.are.equal(style:Font(D.TitleFont), c.title:GetFontObject())
    assert.are.equal(style:Font(D.WarningFont), c.warning:GetFontObject())
    assert.are.equal(style:Font(D.HintFont), c.hint:GetFontObject())
  end)

  it("glows in another color when given one, everything else the theme's", function()
    local D = style.Theme.Dock
    local c = dockCard:Create(parent)
    c:Style("White")
    local gr, gg, gb = c.glow[2]:GetVertexColor()
    assert.are.same({ 1, 1, 1 }, { gr, gg, gb })
    local hr, hg, hb = c.halo:GetVertexColor()
    assert.are.same({ 1, 1, 1 }, { hr, hg, hb })
    assert.are.equal(D.Glow.Width, c.glow[1]:GetHeight())
    assert.are.equal(style:Font(D.TitleFont), c.title:GetFontObject())
    c:Style()
    gr, gg, gb = c.glow[2]:GetVertexColor()
    local er, eg, eb = style:RGBA(D.Glow.Color)
    assert.are.same({ er, eg, eb }, { gr, gg, gb }, "styled again without one: the theme's")
  end)

  it("follows a theme with no glow or halo", function()
    UseNextTheme({ Dock = { Glow = false, Halo = false } })
    local c = dockCard:Create(parent)
    assert.is_false(c.glow[1]:IsShown())
    assert.is_false(c.halo:IsShown())
    assert.has_no.errors(function() c:Pulse(0.3) end)
  end)

  it("sizes itself round what it holds: its padding, title, warning, the slot and the hint", function()
    local D = style.Theme.Dock
    local c = dockCard:Create(parent)
    local height = c:Size(200, 37)
    assert.are.equal(D.Pad + D.TitleHeight + 4 + D.LineHeight + 10 + 37 + 8 + D.LineHeight + D.Pad, height)
    assert.are.equal(height, dockCard:Height(c.frame, 37))
    assert.are.equal(200 + 2 * D.Pad, c.frame:GetWidth())
    assert.are.equal(height, c.frame:GetHeight())
    assert.are.equal(200, c.slot:GetWidth())
    assert.are.equal(37, c.slot:GetHeight())
  end)

  it("pulses its edge and halo between the theme's low and high, the same on every edge", function()
    local G, H = style.Theme.Dock.Glow, style.Theme.Dock.Halo
    local c = dockCard:Create(parent)
    c:Pulse(0)
    assert.is_true(math.abs(c.glow[1]:GetAlpha() - (G.Low + G.High) / 2) < 1e-6, "halfway at the start")
    assert.is_true(math.abs(c.halo:GetAlpha() - (H.Low + H.High) / 2) < 1e-6)
    c:Pulse(G.Period / 4)
    assert.is_true(math.abs(c.glow[1]:GetAlpha() - G.High) < 1e-6, "at its high a quarter period in")
    for _, edge in ipairs(c.glow) do assert.are.equal(c.glow[1]:GetAlpha(), edge:GetAlpha()) end
  end)

  it("sets its three lines", function()
    local c = dockCard:Create(parent)
    c:SetText("Title", "Warning", "Hint")
    assert.are.same({ "Title", "Warning", "Hint" }, { c.title:GetText(), c.warning:GetText(), c.hint:GetText() })
  end)
end)
