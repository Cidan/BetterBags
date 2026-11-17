-- cards_spec.lua -- NextSettingsCards (next/settings/cards.lua): the cards of the settings window, drawn from the
-- theme's Settings.Cards: a name, a status on the right and two lines of text under the name, filled, lit under the
-- pointer, edged, the chosen one edged in its own color. The theme picker's cards and the Help page's cards share them
-- (next-settings.md §4, help.md §5).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- A text sits a quarter pixel right of and above its whole pixel (next-pixel-perfect.md §2); one pixel is one unit here.
local TEXT = 0.25

LoadBetterBagsModule("core/context.lua")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextFill", "next/fill.lua" }, { "NextControls", "next/controls/base.lua" },
  { "NextSettingsCards", "next/settings/cards.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local cards = addon:GetModule("NextSettingsCards")
local style = addon:GetModule("NextStyle")

local function K()
  return style.Theme.Settings.Cards
end

describe("NextSettingsCards", function()
  local parent

  before_each(function()
    UseNextTheme(nil)
    parent = CreateFrame("Frame", nil, UIParent)
    parent:SetSize(600, 400)
  end)

  it("makes a card: a button with its fill, its edge, its name, its status and two lines of text", function()
    local card = cards:Create(parent)
    assert.are.equal("Button", card.frame:GetObjectType())
    assert.are.equal(K().NameFont, style.texts[card.name])
    assert.are.equal(K().TextFont, style.texts[card.text])
    assert.are.equal("RIGHT", card.status:GetJustifyH())
    assert.are.equal(2, card.text:GetMaxLines())
    assert.is_true(card.text:CanWordWrap())
    assert.is_false(card.hovered)
  end)

  -- look returns how a texture is drawn: its vertex color and its solid color, as the mock keeps them.
  local function look(texture)
    local c = texture._colorTexture or {}
    return { { texture:GetVertexColor() }, c.r, c.g, c.b, c.a }
  end

  it("lights a card under the pointer and edges the chosen one", function()
    local card = cards:Create(parent)
    cards:Paint(card, false)
    assert.is_true(card.fill:IsShown())
    local idle = look(card.fill)
    card.hovered = true
    cards:Paint(card, false)
    assert.are_not.same(idle, look(card.fill))
    local plain = look(card.edge.Top)
    cards:Paint(card, true)
    assert.are_not.same(plain, look(card.edge.Top))
  end)

  it("lays a card out: its name and status Pad in from its top, its text under its name", function()
    local card = cards:Create(parent)
    card.name:SetText("Default")
    card.status:SetText("Active")
    card.text:SetText("The theme BetterBags Next ships with.")
    cards:Place(card, parent, 10, 20, 300, K().Height)
    local point, rel, relPoint, x, y = card.frame:GetPoint(1)
    assert.are.same({ "TOPLEFT", parent, "TOPLEFT", 10, -20 }, { point, rel, relPoint, x, y })
    assert.are.equal(300, card.frame:GetWidth())
    assert.are.equal(K().Height, card.frame:GetHeight())
    local _, _, _, nx, ny = card.name:GetPoint(1)
    assert.are.same({ K().Pad + TEXT, -K().Pad + TEXT }, { nx, ny })
    local sp, _, _, sx = card.status:GetPoint(1)
    assert.are.equal("TOPRIGHT", sp)
    assert.are.equal(-K().Pad + TEXT, sx)
    local _, _, _, tx, ty = card.text:GetPoint(1)
    assert.are.equal(K().Pad + TEXT, tx)
    assert.is_true(ty < ny)
    assert.are.equal(300 - 2 * K().Pad, card.text:GetWidth())
  end)

  it("lays a card's parts out without moving it, for a card something else places", function()
    local card = cards:Create(parent)
    card.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 3, -4)
    cards:Layout(card, parent, 200, K().Height)
    assert.are.same({ "TOPLEFT", parent, "TOPLEFT", 3, -4 }, { card.frame:GetPoint(1) })
    assert.are.equal(200, card.frame:GetWidth())
    assert.are.equal(200 - 2 * K().Pad, card.text:GetWidth())
    local _, rel = card.name:GetPoint(1)
    assert.are.equal(card.frame, rel)
  end)

  it("gives the cards' lengths in whole pixels", function()
    local m = cards:Metrics(parent)
    assert.are.same({ height = K().Height, gap = K().Gap, pad = K().Pad, minWidth = K().MinWidth }, m)
  end)
end)
