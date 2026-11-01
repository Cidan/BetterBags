-- style_spec.lua -- NextStyle (next/style.lua): BetterBagsNext's timings. 0.24 seconds is the time
-- for everything that moves in answer to the player (next.md §5); the panel's slides in and out
-- keep their own.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

ResetModuleStub("NextStyle", "next/style.lua")
LoadBetterBagsModule("next/style.lua")

local style = addon:GetModule("NextStyle")

describe("NextStyle timings", function()
  it("moves everything that answers the player in 0.24 seconds", function()
    local t = style.Time
    assert.are.equal(0.24, t.Interaction)
    for _, name in ipairs({ "Glide", "Land", "FlyAway" }) do
      assert.are.equal(t.Interaction, t[name], name)
    end
  end)

  it("keeps the panel's slides, feedback and fades at their own times", function()
    local t = style.Time
    assert.are.same({ 0.45, 0.24, 0.32, 0.12, 0.15, 0.6, 0.44 },
      { t.Open, t.Close, t.Cascade, t.Lift, t.Hover, t.Pulse, t.Wash })
  end)
end)

-- The Size tab's Icon Scale (docs/next-appearance-size.md): an item button is the theme's icon size
-- times the player's scale; the grid keeps the theme's width, so a row fits as many as it can.
describe("NextStyle Icon Scale", function()
  local base

  local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
  end

  local function gridWidth(L)
    return L.PerRow * L.Icon + (L.PerRow - 1) * L.Gap
  end

  before_each(function()
    base = style.Theme
  end)

  after_each(function()
    style:SetIconScale(100)
    style:Use(base)
  end)

  it("draws item buttons at the theme's icon size at 100%", function()
    assert.are.equal(100, style.iconScale)
    assert.are.equal(base.Layout.Icon, style.ICON)
    assert.are.equal(base.Layout.Icon, style.CARD_HEIGHT)
    assert.are.equal(gridWidth(base.Layout), style.GRID_WIDTH)
  end)

  it("scales the item buttons, in whole pixels, keeping the grid's width and the vendor's card width", function()
    local cardWidth, body, width = style.VENDOR_CARD_WIDTH, style.BODY_WIDTH, style.WIDTH
    style:SetIconScale(150)
    assert.are.equal(66, style.ICON, "44 x 1.5")
    assert.are.equal(gridWidth(base.Layout), style.GRID_WIDTH)
    assert.are.same({ cardWidth, body, width }, { style.VENDOR_CARD_WIDTH, style.BODY_WIDTH, style.WIDTH })
    assert.are.equal(66, style.CARD_HEIGHT, "as tall as its icon")
    style:SetIconScale(75)
    assert.are.equal(33, style.ICON)
    assert.are.equal(44, style.CARD_HEIGHT, "never shorter than its name and price need")
    style:SetIconScale(55)
    assert.are.equal(24, style.ICON, "24.2, whole")
  end)

  -- Asked: "account for the fact that themes can set icon scale!"
  it("scales whatever icon size the theme sets, and keeps the scale across themes", function()
    local quiet = copy(base)
    quiet.Layout.Icon = 38
    style:SetIconScale(150)
    style:Use(quiet)
    assert.are.equal(57, style.ICON, "the theme's 38 x 1.5")
    assert.are.equal(57, style.CARD_HEIGHT)
    assert.are.equal(gridWidth(quiet.Layout), style.GRID_WIDTH)
    style:Use(base)
    assert.are.equal(66, style.ICON)
  end)

  -- A theme application makes new font objects, which can never be freed (next-themes.md): a slider
  -- dragged through its steps must not make one per step.
  it("makes no font object when the scale changes", function()
    local made = 0
    local createFont = _G.CreateFont
    _G.CreateFont = function(...)
      made = made + 1
      return createFont(...)
    end
    style:SetIconScale(120)
    style:SetIconScale(80)
    _G.CreateFont = createFont
    assert.are.equal(0, made)
  end)
end)

teardown(function()
  ResetModuleStub("NextStyle")
end)
