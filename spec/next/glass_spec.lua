-- glass_spec.lua -- NextGlass (next/glass.lua): a Next theme's body as a pane of glass (Panel.Glass, next-themes-glass.md
-- §26; the Rainy Window theme). Smoked: a MOD tint over the fill, as strong as the player sets it, and a veil that
-- scatters light; a grain through it; bands of reflected light that hold nearly still on the screen as the bag moves;
-- the pointer as a lamp (a soft light on the body, glints along its edges, the drops lit from its side); raindrops behind
-- the content, a few running down in fits and leaving beads that dry; lightning now and then. Drawn on the panel's own
-- frame, under its tabs and content, moving only while the panel shows.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

for _, m in ipairs({ { "NextPixel", "next/pixel.lua" }, { "NextStyle", "next/style.lua" }, { "NextGlass", "next/glass.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end
local glass = addon:GetModule("NextGlass")

local SMOKE = { 0.2, 0.3, 0.4, 1 }
local MIST = { 0.8, 0.85, 0.9, 1 }

local function copy(t)
  local out = {}
  for k, v in pairs(t) do
    out[k] = type(v) == "table" and copy(v) or v
  end
  return out
end

local GLASS = {
  Tint = { Color = "Smoke", Strength = 0.5, Veil = { Color = "Mist", Alpha = 0.2 } },
  Grain = { Texture = "Fog", Color = "White", Alpha = 0.06, Size = 256 },
  Reflections = { Texture = "Reflection", Color = "White", Alpha = 0.5, Angle = 60, Period = 300, Parallax = 0.8 },
  Lamp = { Texture = "Glow", Color = "White", Alpha = 0.2, Size = 200, Reach = 150 },
  Rim = { Color = "White", Alpha = { 0.05, 0.65 }, Size = 1, Piece = 20 },
  Rain = { Texture = "Drop", Color = "White", Alpha = 0.9, Density = 0.5, Size = { 4, 8 },
    Highlight = { Texture = "Glow", Color = "White", Alpha = 0.8 },
    Caustic = { Texture = "Glow", Color = "White", Alpha = 0.3 },
    Runners = { Count = 2, Size = { 8, 8 }, Speed = { 50, 50 }, Wait = { 1, 1 }, Slide = { 0.5, 0.5 },
      Catch = { 0.2, 0.2 }, Every = 10, Beads = 6, BeadSize = { 2, 2 }, BeadLife = { 4, 4 } } },
  Lightning = { Every = { 10, 10 }, Time = 0.4, Color = "White", Alpha = 0.4 },
}

local function near(a, b, eps)
  return math.abs(a - b) <= (eps or 1e-6)
end

describe("NextGlass", function()
  local savedRandom, savedCombat, combat

  local function theme(spec)
    UseNextTheme({
      Palette = { Smoke = SMOKE, Mist = MIST },
      Textures = { Fog = "fog.png", Reflection = "reflection.png", Glow = "glow.png", Drop = "drop.png" },
      Panel = { Glass = spec },
    })
  end

  -- panelOn makes what the glass reads of a panel: its frame (496 x 600, its left at 1000 and its top at 700 on the
  -- screen), its body (a frame) and fill (a texture), where its body starts in it and how wide it is, and its side.
  local function panelOn(side)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:_SetRect(1000, 100, 496, 600)
    local panel = { frame = frame, side = side or "RIGHT" }
    panel.body = CreateFrame("Frame", nil, frame)
    panel.fill = frame:CreateTexture(nil, "BACKGROUND")
    function panel:BodyLeft() return self.side == "LEFT" and 0 or 96 end
    function panel:BodyWidth() return self.width or 400 end
    panel.glass = glass:Create(panel)
    return panel
  end

  local function started(spec, side)
    theme(spec or copy(GLASS))
    local panel = panelOn(side)
    panel.glass:Style()
    panel.glass:Start()
    return panel
  end

  local function step(panel, dt)
    local d = panel.glass.driver
    local update = d:GetScript("OnUpdate")
    assert.is_not_nil(update, "the glass moves while it shows")
    update(d, dt)
  end

  -- pointAt puts the pointer at a place on the panel's frame (from its top left, y down).
  local function pointAt(x, y)
    _G._cursorX, _G._cursorY = 1000 + x, 700 - y
  end

  -- Where a texture's middle is, from the panel's top left, y down.
  local function at(t)
    local point, _, relPoint, x, y = t:GetPoint(1)
    assert.are.same({ "CENTER", "TOPLEFT" }, { point, relPoint })
    return x, -y
  end

  local function rgb(t)
    local r, g, b = t:GetVertexColor()
    return { r, g, b }
  end

  local function same(a, b, eps)
    for i = 1, #a do
      if not near(a[i], b[i], eps) then
        return false
      end
    end
    return true
  end

  before_each(function()
    savedRandom = glass.Random
    local seed = 7
    glass.Random = function()
      seed = (seed * 16807) % 2147483647
      return seed / 2147483647
    end
    savedCombat = _G.InCombatLockdown
    combat = false
    _G.InCombatLockdown = function() return combat end
    _G._cursorX, _G._cursorY = -5000, -5000
  end)

  after_each(function()
    glass.Random = savedRandom
    _G.InCombatLockdown = savedCombat
    _G._cursorX, _G._cursorY = nil, nil
    UseNextTheme(nil)
  end)

  it("draws no glass for a theme without one, and nothing moves", function()
    UseNextTheme({})
    local panel = panelOn()
    panel.glass:Style()
    panel.glass:Start()
    for _, key in ipairs({ "tint", "veil", "grain", "reflections", "lamp", "flash" }) do
      assert.is_false(panel.glass[key]:IsShown(), key)
    end
    assert.are.equal(0, #panel.glass.drops)
    assert.are.equal(0, #panel.glass.rims)
    assert.is_nil(panel.glass.driver:GetScript("OnUpdate"))
  end)

  it("smokes what is behind it over its fill: a MOD tint at the theme's strength and a veil scattering light", function()
    local panel = started()
    local G = panel.glass
    assert.are.equal(panel.frame, G.tint:GetParent())
    assert.are.same({ "BACKGROUND", 1 }, { G.tint:GetDrawLayer() })
    assert.are.equal(panel.fill, select(2, G.tint:GetPoint(1)), "over the fill, past the screen edge with it")
    assert.are.equal("MOD", G.tint:GetBlendMode())
    -- Half way from clear (white) to the smoke.
    assert.is_true(same({ 0.6, 0.65, 0.7 }, rgb(G.tint)), "the tint at half strength")
    assert.are.equal(1, G.tint:GetAlpha())
    assert.are.equal(panel.fill, select(2, G.veil:GetPoint(1)))
    assert.are.same({ "BACKGROUND", 2 }, { G.veil:GetDrawLayer() })
    assert.are.equal("BLEND", G.veil:GetBlendMode())
    assert.is_true(same({ 0.8, 0.85, 0.9 }, rgb(G.veil)))
    assert.is_true(near(0.1, G.veil:GetAlpha()), "the veil's alpha at half strength")
    for _, s in ipairs({ { 0, { 1, 1, 1 }, 0 }, { 1, { 0.2, 0.3, 0.4 }, 0.2 } }) do
      local spec = copy(GLASS)
      spec.Tint.Strength = s[1]
      local p = started(spec)
      assert.is_true(same(s[2], rgb(p.glass.tint)), "strength " .. s[1])
      assert.is_true(near(s[3], p.glass.veil:GetAlpha()), "strength " .. s[1])
    end
  end)

  it("takes a new strength on every panel at once (Retint)", function()
    local a, b = started(), panelOn()
    b.glass:Style()
    addon:GetModule("NextStyle").Theme.Panel.Glass.Tint.Strength = 1
    glass:Retint()
    for _, panel in ipairs({ a, b }) do
      assert.is_true(same({ 0.2, 0.3, 0.4 }, rgb(panel.glass.tint)))
      assert.is_true(near(0.2, panel.glass.veil:GetAlpha()))
    end
    local r, g, bl, vr, vg, vb, va = glass:Tint()
    assert.is_true(same({ 0.2, 0.3, 0.4, 0.8, 0.85, 0.9, 0.2 }, { r, g, bl, vr, vg, vb, va }))
  end)

  it("is clear glass without a tint, and the tint it hands out is none", function()
    local spec = copy(GLASS)
    spec.Tint = nil
    local panel = started(spec)
    assert.is_false(panel.glass.tint:IsShown())
    assert.is_false(panel.glass.veil:IsShown())
    local r, g, b, _, _, _, va = glass:Tint()
    assert.are.same({ 1, 1, 1, 0 }, { r, g, b, va })
  end)

  -- A sheen fades a panel in and out (NextSheen); the tint's strength follows it, so the smoke fades with the panel
  -- whatever the client does with a MOD texture's alpha.
  it("fades its tint and veil with the panel's presence, and back at full", function()
    local G = started().glass
    G:SetPresence(0.5)
    assert.is_true(same({ 0.8, 0.825, 0.85 }, rgb(G.tint)), "a quarter of the way to the smoke")
    assert.is_true(near(0.05, G.veil:GetAlpha()))
    G:SetPresence(0)
    assert.is_true(same({ 1, 1, 1 }, rgb(G.tint)))
    glass:Retint()
    assert.is_true(same({ 1, 1, 1 }, rgb(G.tint)), "a new tint keeps the presence")
    G:SetPresence(1)
    assert.is_true(same({ 0.6, 0.65, 0.7 }, rgb(G.tint)))
  end)

  it("beads its drops up one after another as it shows (Rain.Appear), each in its own time", function()
    local spec = copy(GLASS)
    spec.Rain.Appear = { 0.2, 0.6 }
    local panel = started(spec)
    local drops = panel.glass.drops
    for _, d in ipairs(drops) do
      assert.are.equal(0, d.body:GetAlpha(), "not there yet")
    end
    step(panel, 0.4)
    local shown, waiting = 0, 0
    for _, d in ipairs(drops) do
      if d.body:GetAlpha() > 0 then shown = shown + 1 else waiting = waiting + 1 end
    end
    assert.is_true(shown > 0 and waiting > 0, "some beaded up, some still to: " .. shown .. " and " .. waiting)
    step(panel, 0.6)
    for _, d in ipairs(drops) do
      assert.is_true(near(0.9, d.body:GetAlpha()), "all there once the last has beaded up")
      assert.is_true(near(d.size, d.body:GetWidth()))
    end
    -- Without Appear, there at once.
    assert.is_true(near(0.9, started().glass.drops[1].body:GetAlpha()))
  end)

  it("lays a grain over the glass, tiled at its size", function()
    local G = started().glass
    local t = G.grain
    assert.are.same({ "BACKGROUND", 3 }, { t:GetDrawLayer() })
    assert.are.equal("fog.png", t:GetTexture())
    assert.are.same({ "REPEAT", "REPEAT" }, { t._wrapH, t._wrapV })
    assert.are.equal("ADD", t:GetBlendMode())
    assert.is_true(near(0.06, t:GetAlpha()))
    local ulx, uly, _, lly, urx = t:GetTexCoord()
    assert.is_true(near(0, ulx) and near(0, uly))
    assert.is_true(near(400 / 256, urx), "across the body")
    assert.is_true(near(600 / 256, lly), "down it")
  end)

  it("reflects bands of light across the body that hold nearly still on the screen as the bag moves", function()
    local panel = started()
    local t = panel.glass.reflections
    assert.are.equal(panel.body, select(2, t:GetPoint(1)), "over the body, so cut at its edges")
    assert.are.same({ "BORDER", 2 }, { t:GetDrawLayer() })
    assert.are.equal("reflection.png", t:GetTexture())
    assert.are.same({ "REPEAT", "REPEAT" }, { t._wrapH, t._wrapV })
    assert.are.equal("ADD", t:GetBlendMode())
    assert.is_true(near(0.5, t:GetAlpha()))
    local theta = math.rad(60)
    local nx, ny, tx, ty = -math.sin(theta), math.cos(theta), math.cos(theta), math.sin(theta)
    local function expected(left, top)
      local out = {}
      for _, c in ipairs({ { 96, 0 }, { 96, -600 }, { 496, 0 }, { 496, -600 } }) do
        table.insert(out, (c[1] * nx + c[2] * ny + 0.8 * (left * nx + top * ny)) / 300)
        table.insert(out, (c[1] * tx + c[2] * ty) / 300)
      end
      return out
    end
    assert.is_true(same(expected(1000, 700), { t:GetTexCoord() }, 1e-9))
    -- Moved 100 to the right: the bands move with it a fifth of the way.
    panel.frame:_SetRect(1100, 100, 496, 600)
    step(panel, 0.016)
    assert.is_true(same(expected(1100, 700), { t:GetTexCoord() }, 1e-9))
  end)

  it("lights the body softly under the pointer, never past its edges", function()
    local panel = started()
    local t = panel.glass.lamp
    assert.are.equal(panel.body, select(2, t:GetPoint(1)))
    assert.are.equal("glow.png", t:GetTexture())
    assert.are.same({ "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE" }, { t._wrapH, t._wrapV },
      "nothing past the art's edge")
    assert.are.equal("ADD", t:GetBlendMode())
    assert.are.equal(0, t:GetAlpha(), "the pointer is far away")
    -- Over the body's middle: the light's 200 across centred there.
    pointAt(96 + 200, 300)
    step(panel, 0.016)
    assert.is_true(near(0.2, t:GetAlpha()))
    assert.is_true(same({ -0.5, -1, -0.5, 2, 1.5, -1, 1.5, 2 }, { t:GetTexCoord() }))
    -- Half its reach off the body's left edge: half as bright.
    pointAt(96 - 75, 300)
    step(panel, 0.016)
    assert.is_true(near(0.1, t:GetAlpha()))
    pointAt(-2000, 300)
    step(panel, 0.016)
    assert.are.equal(0, t:GetAlpha())
  end)

  it("glints along its edges where the pointer's light falls", function()
    local panel = started()
    local rims = panel.glass.rims
    -- A piece every 20 along each edge: 400 across, 600 down.
    assert.are.equal(20 + 20 + 30 + 30, #rims)
    for _, piece in ipairs(rims) do
      assert.are.equal(panel.frame, piece.texture:GetParent())
      assert.are.same({ "BORDER", 4 }, { piece.texture:GetDrawLayer() })
      assert.is_true(near(0.05, piece.texture:GetAlpha()), "faint while the pointer is away")
    end
    pointAt(96 + 10, 10)
    step(panel, 0.016)
    local first, last
    for _, piece in ipairs(rims) do
      if piece.ny == -1 then
        first = first or piece
        last = piece
      end
    end
    assert.is_true(first.x < last.x)
    assert.is_true(first.texture:GetAlpha() > 0.3, "the top edge by the pointer glints")
    assert.is_true(near(0.05, last.texture:GetAlpha(), 0.01), "its far end does not")
  end)

  it("scatters its drops over the body by their density, behind its content", function()
    local panel = started()
    local drops = panel.glass.drops
    -- 400 x 600 is 24 squares of 100: half a drop to each.
    assert.are.equal(12, #drops)
    for _, d in ipairs(drops) do
      assert.is_true(d.x >= 96 and d.x <= 496 and d.y >= 0 and d.y <= 600, "on the body")
      assert.is_true(d.size >= 4 and d.size <= 8)
      assert.are.equal(panel.frame, d.body:GetParent())
      assert.are.same({ "BORDER", 3 }, { d.body:GetDrawLayer() })
      assert.are.equal("drop.png", d.body:GetTexture())
      assert.are.equal("BLEND", d.body:GetBlendMode())
      assert.is_true(near(0.9, d.body:GetAlpha()))
      assert.are.equal("glow.png", d.highlight:GetTexture())
      assert.are.equal("ADD", d.highlight:GetBlendMode())
      assert.are.equal("ADD", d.caustic:GetBlendMode())
      local x, y = at(d.body)
      assert.is_true(near(d.x, x) and near(d.y, y))
      assert.is_true(near(d.size, d.body:GetWidth()))
    end
  end)

  it("lights each drop from the pointer: its highlight toward it, the light it focuses away", function()
    local panel = started()
    local d = panel.glass.drops[1]
    -- The sky above lights it while the pointer is away: its highlight up, its caustic down.
    local hx, hy = at(d.highlight)
    local cx, cy = at(d.caustic)
    assert.is_true(hy < d.y and cy > d.y)
    assert.is_true(near(hx, d.x) and near(cx, d.x))
    pointAt(d.x + 40, d.y)
    step(panel, 0.016)
    hx = at(d.highlight)
    cx = at(d.caustic)
    assert.is_true(hx > d.x, "its highlight toward the pointer")
    assert.is_true(cx < d.x, "its caustic away from it")
    assert.is_true(d.highlight:GetAlpha() > 0.8 * 0.35, "brighter with the lamp close")
  end)

  it("runs a few drops down in fits, leaving beads behind that dry", function()
    local panel = started()
    local runners = panel.glass.runners
    assert.are.equal(2, #runners)
    local r = runners[1]
    local y0 = r.y
    assert.is_true(y0 >= 60 and y0 <= 300, "from the upper half of the body")
    assert.are.equal(0, r.body:GetAlpha(), "swelling into sight")
    step(panel, 0.5)
    assert.are.equal(y0, r.y, "still swelling")
    assert.is_true(r.body:GetAlpha() > 0 and r.body:GetAlpha() < 0.9)
    step(panel, 0.5)
    step(panel, 0.1)
    assert.is_true(near(y0 + 5, r.y), "sliding down")
    step(panel, 0.2)
    step(panel, 0.2)
    assert.is_true(near(y0 + 25, r.y))
    local beads = 0
    for _, b in ipairs(panel.glass.beads) do
      if b.life > 0 then
        beads = beads + 1
        assert.is_true(b.y < r.y, "behind it")
        assert.is_true(b.body:IsShown())
      end
    end
    assert.is_true(beads >= 2, "a bead every 10 it runs")
    step(panel, 0.2)
    local caught = r.y
    step(panel, 0.1)
    assert.are.equal(caught, r.y, "caught for a moment")
    step(panel, 0.2)
    assert.is_true(r.y > caught, "and off again")
    for _ = 1, 30 do step(panel, 0.2) end
    for _, b in ipairs(panel.glass.beads) do
      if b.life <= 0 then
        assert.are.equal(0, b.body:GetAlpha(), "dried")
      end
    end
  end)

  it("starts a runner again from the top once it has run off the bottom, none in combat", function()
    local panel = started()
    local r = panel.glass.runners[1]
    r.wait, r.vy, r.run, r.y = 0, 50, 10, 607
    step(panel, 0.1)
    assert.is_true(r.y < 600 and r.wait > 0, "started again, swelling")
    combat = true
    r.wait, r.vy, r.run, r.y = 0, 50, 10, 607
    step(panel, 0.1)
    assert.is_true(r.dormant)
    assert.is_false(r.body:IsShown())
    step(panel, 0.1)
    assert.is_true(r.dormant, "not in combat")
    combat = false
    step(panel, 0.1)
    assert.is_false(r.dormant)
    assert.is_true(r.body:IsShown())
  end)

  it("flashes with lightning now and then, lighting its drops and edges, never in combat", function()
    local panel = started()
    local flash = panel.glass.flash
    assert.are.equal(panel.body, select(2, flash:GetPoint(1)))
    assert.are.same({ "BORDER", 5 }, { flash:GetDrawLayer() })
    assert.are.equal("ADD", flash:GetBlendMode())
    assert.are.equal(0, flash:GetAlpha())
    local d = panel.glass.drops[1]
    local before = d.highlight:GetAlpha()
    local rim = panel.glass.rims[1].texture:GetAlpha()
    step(panel, 9.9)
    assert.are.equal(0, flash:GetAlpha())
    step(panel, 0.2)
    assert.is_true(flash:GetAlpha() > 0.2, "a flash: " .. flash:GetAlpha())
    assert.is_true(d.highlight:GetAlpha() > before, "its drops lit")
    assert.is_true(panel.glass.rims[1].texture:GetAlpha() > rim, "its edges lit")
    step(panel, 0.5)
    assert.are.equal(0, flash:GetAlpha(), "and gone")
    assert.is_true(near(before, d.highlight:GetAlpha()))
    combat = true
    step(panel, 10)
    assert.are.equal(0, flash:GetAlpha(), "none in combat")
  end)

  it("leaves out its rain, lightning and lamp where the theme does", function()
    local spec = copy(GLASS)
    spec.Rain, spec.Lightning, spec.Lamp, spec.Rim = nil, nil, nil, nil
    local panel = started(spec)
    assert.are.equal(0, #panel.glass.drops)
    assert.are.equal(0, #panel.glass.runners)
    assert.are.equal(0, #panel.glass.rims)
    assert.is_false(panel.glass.flash:IsShown())
    assert.is_false(panel.glass.lamp:IsShown())
    assert.is_true(panel.glass.tint:IsShown())
  end)

  -- A panel's glass is styled as it is built, before it has a size.
  it("counts its drops for the body's size once it has one, more on a bigger body and fewer on a smaller", function()
    theme(copy(GLASS))
    local panel = panelOn()
    panel.frame:_SetRect(1000, 700, 496, 0)
    panel.glass:Style()
    assert.are.equal(0, #panel.glass.drops)
    panel.frame:_SetRect(1000, 100, 496, 600)
    panel.glass:Layout()
    assert.are.equal(12, #panel.glass.drops)
    panel.width = 200
    panel.glass:Layout()
    assert.are.equal(6, #panel.glass.drops)
    for _, d in ipairs(panel.glass.drops) do
      assert.is_true(d.body:IsShown() and d.x >= 96 and d.x <= 296)
    end
    panel.width = 400
    panel.glass:Layout()
    assert.are.equal(12, #panel.glass.drops)
  end)

  it("keeps its drops on the body when it changes size, and on the left of a panel on the left", function()
    local panel = started()
    panel.width = 200
    panel.glass:Layout()
    for _, d in ipairs(panel.glass.drops) do
      assert.is_true(d.x >= 96 and d.x <= 296, "inside the narrower body")
    end
    local left = started(nil, "LEFT")
    for _, d in ipairs(left.glass.drops) do
      assert.is_true(d.x >= 0 and d.x <= 400)
    end
  end)

  it("stops when the panel hides, its beads gone, and starts again as it shows", function()
    local panel = started()
    step(panel, 1.3)
    panel.glass:Stop()
    assert.is_nil(panel.glass.driver:GetScript("OnUpdate"))
    for _, b in ipairs(panel.glass.beads) do
      assert.is_true(b.life <= 0)
      assert.is_false(b.body:IsShown())
    end
    panel.glass:Start()
    assert.is_not_nil(panel.glass.driver:GetScript("OnUpdate"))
  end)

  it("names its drops as moving parts, for the pixel checks", function()
    local panel = started()
    step(panel, 1.3)
    local skip = {}
    panel.glass:MovingParts(skip)
    for _, list in ipairs({ panel.glass.drops, panel.glass.runners, panel.glass.beads }) do
      for _, d in ipairs(list) do
        assert.is_true(skip[d.body] and skip[d.highlight] and skip[d.caustic])
      end
    end
  end)

  it("draws again for a new theme, giving its old drops back", function()
    local panel = started()
    local old = panel.glass.drops[1].body
    UseNextTheme({})
    panel.glass:Style()
    assert.are.equal(0, #panel.glass.drops)
    assert.is_false(old:IsShown())
    assert.is_false(panel.glass.tint:IsShown())
    theme(copy(GLASS))
    panel.glass:Style()
    assert.are.equal(12, #panel.glass.drops)
  end)

  -- Found in review: a theme previewed without glass on an open bag, then this one again (leaving the theme pane), left
  -- the glass still for good: no runners, lamp, lightning or parallax until the bag was closed and opened.
  it("moves on through a theme without glass and back while the panel shows", function()
    local panel = started()
    UseNextTheme({})
    panel.glass:Style()
    assert.is_nil(panel.glass.driver:GetScript("OnUpdate"), "nothing to move without glass")
    theme(copy(GLASS))
    panel.glass:Style()
    assert.is_true(panel.glass.running)
    assert.is_not_nil(panel.glass.driver:GetScript("OnUpdate"), "moving again")
    local r = panel.glass.runners[1]
    assert.is_true(r.body:IsShown() and r.wait > 0, "its runners swelling again")
  end)

  -- Found in review: a small bag resized by its grip (or fitted, or snapped) kept its rim and drops where its old size
  -- put them, over the world outside it.
  it("lays itself out again as it moves when its body changes size, its height or its width", function()
    local panel = started()
    panel.frame:_SetRect(1000, 300, 496, 400)
    step(panel, 0.016)
    for _, d in ipairs(panel.glass.drops) do
      assert.is_true(d.y <= 400, "on the shorter body")
    end
    for _, piece in ipairs(panel.glass.rims) do
      assert.is_true(piece.y <= 400, "its rim on the shorter body's edges")
    end
    local _, _, _, lly = panel.glass.grain:GetTexCoord()
    assert.is_true(near(400 / 256, lly), "its grain tiled down the shorter body")
    panel.width = 200
    step(panel, 0.016)
    for _, d in ipairs(panel.glass.drops) do
      assert.is_true(d.x >= 96 and d.x <= 296, "on the narrower body")
    end
    for _, piece in ipairs(panel.glass.rims) do
      assert.is_true(piece.x <= 296, "its rim on the narrower body's edges")
    end
  end)

  it("lays itself out again as it shows when its body changed size while it was hidden", function()
    local panel = started()
    panel.glass:Stop()
    panel.frame:_SetRect(1000, 300, 496, 400)
    panel.glass:Start()
    for _, d in ipairs(panel.glass.drops) do
      assert.is_true(d.y <= 400, "on the shorter body")
    end
  end)

  -- outside leaves a bead dropped by the first runner at (x, y), and the second runner waiting at (x, wy), both 8 across.
  local function outside(panel, x, y, wy)
    local r, waiting = panel.glass.runners[1], panel.glass.runners[2]
    r.x, r.y, r.size, r.scale = x, y + 8 * 0.45, 8, 1
    panel.glass:bead(r)
    local bead = panel.glass.beads[1]
    assert.is_true(bead.life > 0 and bead.body:IsShown() and near(y, bead.y))
    waiting.x, waiting.y, waiting.wait, waiting.size, waiting.scale = x, wy, 2, 8, 1
    return bead, waiting
  end

  -- Found in review: a body shrunk by its grip left beads drying, and runners waiting, past its new foot; a bead or a
  -- runner is past it once its foot is, not its middle.
  it("dries beads and starts runners again whose foot a shorter body leaves outside it, drawn there at once", function()
    local panel = started()
    local bead, waiting = outside(panel, 200, 399.5, 398)
    panel.frame:_SetRect(1000, 300, 496, 400)
    panel.glass:Layout()
    assert.are.equal(0, bead.life)
    assert.is_false(bead.body:IsShown(), "dried")
    assert.is_true(waiting.y + waiting.size * waiting.scale / 2 <= 400, "started again on the body: " .. waiting.y)
    local _, y = at(waiting.body)
    assert.is_true(near(waiting.y, y), "drawn where it starts again, not left where it was: " .. y)
  end)

  it("dries beads and starts runners again that a narrower body leaves outside it", function()
    local panel = started()
    local bead, waiting = outside(panel, 380, 300, 200)
    panel.width = 200
    panel.glass:Layout()
    assert.are.equal(0, bead.life)
    assert.is_false(bead.body:IsShown(), "dried")
    assert.is_true(waiting.x >= 96 and waiting.x <= 296, "started again on the body: " .. waiting.x)
  end)

  -- Found in the third review: a body shrunk in combat started a runner again, which none does in combat.
  it("leaves a runner a smaller body leaves outside it waiting, unseen, in combat", function()
    local panel = started()
    local _, waiting = outside(panel, 200, 300, 450)
    combat = true
    panel.frame:_SetRect(1000, 300, 496, 400)
    step(panel, 0.016)
    assert.is_true(waiting.dormant)
    assert.is_false(waiting.body:IsShown())
    combat = false
    step(panel, 0.016)
    assert.is_false(waiting.dormant)
    assert.is_true(waiting.body:IsShown() and waiting.y + waiting.size * waiting.scale / 2 <= 400)
  end)

  -- Found in review: drops made for a body that grew as they beaded up came in at full; and in the third, once they had
  -- all beaded up, never came at all.
  for _, case in ipairs({ { "as its drops bead up", 0.1 }, { "after its drops have beaded up", 1.5 } }) do
    it("beads up drops made for a body that grows " .. case[1], function()
      local spec = copy(GLASS)
      spec.Rain.Appear = { 0.2, 0.6 }
      local panel = started(spec)
      step(panel, case[2])
      local before = #panel.glass.drops
      panel.frame:_SetRect(1000, 0, 496, 700)
      step(panel, 0.016)
      assert.is_true(#panel.glass.drops > before)
      for i = before + 1, #panel.glass.drops do
        assert.are.equal(0, panel.glass.drops[i].body:GetAlpha(), "beading up in its turn")
      end
      step(panel, 1.2)
      for _, d in ipairs(panel.glass.drops) do
        assert.is_true(near(0.9, d.body:GetAlpha()))
      end
    end)
  end

  -- Found in review: on a small bag a runner slid out below the body and left beads there, over the world.
  it("fades a runner out at the body's foot, starts it again there, and leaves no bead below it", function()
    local panel = started()
    local r = panel.glass.runners[1]
    r.wait, r.vy, r.run, r.y, r.swell = 0, 50, 10, 594, 1
    r.lastBead = 580
    step(panel, 0.04)
    assert.is_true(r.body:GetAlpha() < 0.9 * 0.5, "fading at the foot: " .. r.body:GetAlpha())
    step(panel, 0.1)
    assert.is_true(r.y < 600 and r.wait > 0, "started again once it reached the foot")
    -- A hitch: one long frame carries it past the foot, where its bead would lie.
    for _, b in ipairs(panel.glass.beads) do
      b.life = 0
    end
    r.wait, r.vy, r.run, r.y, r.swell, r.scale, r.lastBead = 0, 50, 10, 590, 1, 1, 580
    step(panel, 0.4)
    for _, b in ipairs(panel.glass.beads) do
      assert.are.equal(0, b.life, "no bead left past the foot: " .. b.y)
    end
  end)

  -- Found in review: a runner whose wait was shorter than its swell ran down part faded the whole way.
  it("finishes swelling as it runs when its wait is short", function()
    local spec = copy(GLASS)
    spec.Rain.Runners.Wait = { 0, 0 }
    local panel = started(spec)
    local r = panel.glass.runners[1]
    r.y = 100
    for _ = 1, 10 do step(panel, 0.1) end
    assert.is_true(near(0.9, r.body:GetAlpha()), "fully there: " .. r.body:GetAlpha())
  end)
end)
