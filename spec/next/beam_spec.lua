-- beam_spec.lua -- NextBeam (next/beam.lua): a Next theme's panel beaming in and out as a starship's transporter does
-- (Panel.Beam, next-themes.md §24; the Make It So theme; asked: "the bags obviously need the star trek beam down, and
-- beam up animation for appearing and closing ... most important part is beam down/beam up"). A run lays sparkles over
-- the panel's body, a column of light past its sides and a glow over it. The sparkles twinkle, and drift up and down
-- round the body. Each part grows in and out over an envelope of its own: a beam down's (Open) as the panel shows under
-- it over its Reveal, a beam up's (Close) as the panel fades out of it over its Fade. The run lingers on its own layer
-- after the panel's part, until its last part has gone out (Linger).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextBeam", "next/beam.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end
local beam = addon:GetModule("NextBeam")
local style = addon:GetModule("NextStyle")

local BEAM = {
  Sparkles = { Texture = "Glint", Colors = { "White", "Gold" }, Density = 2, Size = { 8, 8 }, Stretch = 2,
    Alpha = { 0.8, 0.8 }, BlendMode = "ADD", Twinkle = { 4, 4 }, Sharpness = 2, Drift = { 30, 30 }, Spread = 10 },
  Column = { Texture = "Column", Color = "White", Alpha = 0.5, BlendMode = "ADD", Spread = 20, Shimmer = { 0.2, 3 },
    Scroll = 0.5 },
  Glow = { Texture = "Glow", Color = "Gold", Alpha = 0.6, BlendMode = "ADD" },
  Open = { Reveal = { 0.3, 0.6 }, Sparkles = { 0, 0.2, 0.5, 0.8 }, Column = { 0, 0.15, 0.55, 0.9 },
    Glow = { 0.1, 0.35, 0.45, 0.7 } },
  Close = { Fade = { 0.2, 0.5 }, Sparkles = { 0, 0.15, 0.5, 0.8 }, Column = { 0, 0.1, 0.5, 0.95 },
    Glow = { 0, 0.2, 0.35, 0.6 } },
}

local function copy(t)
  local out = {}
  for k, v in pairs(t) do
    out[k] = type(v) == "table" and copy(v) or v
  end
  return out
end

local function theme(spec)
  UseNextTheme({
    Textures = { Glint = "glint.png", Column = "column.png", Glow = "glow.png" },
    Panel = { Beam = spec },
  })
end

local function near(a, b, eps)
  return math.abs(a - b) <= (eps or 1e-6)
end

local function smoothstep(e0, e1, x)
  local t = math.max(0, math.min(1, (x - e0) / (e1 - e0)))
  return t * t * (3 - 2 * t)
end

-- An envelope's strength t seconds in: in over its first two numbers, out over its last two.
local function envelope(e, t)
  return smoothstep(e[1], e[2], t) * (1 - smoothstep(e[3], e[4], t))
end

-- Where a texture is on the layer, by the point it hangs from (y up).
local function at(t)
  local point, rel, relPoint, x, y = t:GetPoint(1)
  assert.are.equal(beam:Layer(), rel)
  assert.are.equal("BOTTOMLEFT", relPoint)
  return x, y, point
end

describe("NextBeam", function()
  local savedRandom

  -- panelOn makes what the beam reads of a panel: its body's rect on the screen (left 1000, top 900, 400 x 600, so from
  -- 300 up to 900), at a scale.
  local function panelOn(scale)
    local s = scale or 1
    local panel = { frame = CreateFrame("Frame", nil, UIParent), side = "RIGHT" }
    function panel:BodyRect() return 1000, 900, 600 * s, 400 * s, s end
    return panel
  end

  before_each(function()
    savedRandom = beam.Random
    local seed = 5
    beam.Random = function()
      seed = (seed * 16807) % 2147483647
      return seed / 2147483647
    end
    beam:Init()
    theme(copy(BEAM))
  end)

  after_each(function()
    beam.Random = savedRandom
    beam:Init()
    UseNextTheme(nil)
  end)

  it("beams down only with an Open and up only with a Close; the panel's part, and when the shimmer is gone", function()
    assert.is_true(beam:Opens())
    assert.is_true(beam:Closes())
    assert.are.equal(0.6, beam:OpenLock())
    assert.are.equal(0.6, beam:OpenTime())
    assert.are.equal(0.5, beam:CloseTime())
    assert.are.equal(0.9, beam:ClearTime("Open"))
    assert.are.equal(0.95, beam:ClearTime("Close"))
    local s = copy(BEAM)
    s.Close = { Fade = { 0.2, 0.5 } }
    theme(s)
    assert.are.equal(0, beam:ClearTime("Close"), "nothing to linger without an envelope")
    s = copy(BEAM)
    s.Open = nil
    theme(s)
    assert.is_false(beam:Opens())
    assert.is_true(beam:Closes())
    s = copy(BEAM)
    s.Close = nil
    theme(s)
    assert.is_true(beam:Opens())
    assert.is_false(beam:Closes())
    UseNextTheme({})
    assert.is_false(beam:Opens())
    assert.is_false(beam:Closes())
    assert.is_nil(beam:Spec())
  end)

  it("draws on a layer over the screen above the panels, taking no mouse", function()
    local layer = beam:Layer()
    assert.are.equal("DIALOG", layer:GetFrameStrata())
    assert.is_false(layer:IsMouseEnabled())
    local run = beam:Begin(panelOn(), "Open")
    for _, s in ipairs(run.sparkles) do
      assert.are.equal(layer, s.texture:GetParent())
    end
    assert.are.equal(layer, run.column:GetParent())
    assert.are.equal(layer, run.glow:GetParent())
  end)

  it("lays its sparkles over the body by their density, a little past its sides, unseen until it draws", function()
    local run = beam:Begin(panelOn(), "Open")
    -- 400 x 600 is 24 squares of 100: 2 to a square.
    assert.are.equal(48, #run.sparkles)
    local colors, up, down = {}, 0, 0
    for _, s in ipairs(run.sparkles) do
      local t = s.texture
      assert.is_false(t:IsShown())
      assert.are.equal("glint.png", t:GetTexture())
      assert.are.equal("ADD", t:GetBlendMode())
      assert.is_true(s.x >= 990 and s.x <= 1410, "across the body, Spread past its sides")
      assert.is_true(s.y >= 300 and s.y <= 900, "down it")
      if s.drift > 0 then up = up + 1 else down = down + 1 end
      assert.are.equal(30, math.abs(s.drift))
      local r, g, b = t:GetVertexColor()
      colors[string.format("%.3f %.3f %.3f", r, g, b)] = true
    end
    assert.is_true(up > 5 and down > 5, "rippling both ways")
    local wr, wg, wb = style:RGBA("White")
    local gr, gg, gb = style:RGBA("Gold")
    assert.is_true(colors[string.format("%.3f %.3f %.3f", wr, wg, wb)])
    assert.is_true(colors[string.format("%.3f %.3f %.3f", gr, gg, gb)])
    assert.is_false(run.column:IsShown())
    assert.is_false(run.glow:IsShown())
  end)

  it("twinkles each sparkle, drifting up or down round the body, in and out over its envelope", function()
    local run = beam:Begin(panelOn(), "Open")
    local seen = 0
    for t = 0.05, 0.75, 0.05 do
      run:Draw(t)
      local env = envelope(BEAM.Open.Sparkles, t)
      for _, s in ipairs(run.sparkles) do
        local tw = ((1 + math.sin(2 * math.pi * s.twinkle * t + s.phase)) / 2) ^ 2
        local tex = s.texture
        assert.is_true(near(tex:GetAlpha(), env * tw * 0.8, 1e-6), "its twinkle in its envelope")
        assert.is_true(near(tex:GetWidth(), 8 * (0.5 + 0.5 * tw)), "swelling as it flashes")
        assert.is_true(near(tex:GetHeight(), 2 * tex:GetWidth()), "a fleck drawn out up and down")
        local x, y, point = at(tex)
        assert.are.equal("CENTER", point)
        assert.are.equal(s.x, x)
        assert.is_true(near(y, 300 + (s.y - 300 + s.drift * t) % 600), "drifting round the body")
        if tex:IsShown() then seen = seen + 1 end
      end
    end
    assert.is_true(seen > 100)
    local phases = {}
    for _, s in ipairs(run.sparkles) do phases[string.format("%.4f", s.phase)] = true end
    local n = 0
    for _ in pairs(phases) do n = n + 1 end
    assert.is_true(n > 40, "each twinkling from a phase of its own")
    run:Draw(0)
    for _, s in ipairs(run.sparkles) do
      assert.is_false(s.texture:IsShown(), "nothing before its envelope starts")
    end
    run:Draw(0.8)
    for _, s in ipairs(run.sparkles) do
      assert.is_false(s.texture:IsShown(), "nothing once it has ended")
    end
  end)

  it("keeps drifting sparkles on the body, wrapping round from top to bottom", function()
    local s = copy(BEAM)
    s.Open.Sparkles = { 0, 0.1, 100, 101 }
    theme(s)
    local run = beam:Begin(panelOn(), "Open")
    run:Draw(20)
    for _, sp in ipairs(run.sparkles) do
      local _, y = at(sp.texture)
      assert.is_true(y >= 300 and y < 900, "still on the body after drifting 600: " .. y)
    end
  end)

  it("lights a column over the body and past its sides, shimmering and flowing up", function()
    local run = beam:Begin(panelOn(), "Open")
    local c = run.column
    assert.are.equal("column.png", c:GetTexture())
    assert.are.equal("ADD", c:GetBlendMode())
    -- Its art repeats down its length as its coordinates scroll (the REPEAT wrap mode), not tiled by the client.
    assert.are.equal("REPEAT", c._wrapV)
    assert.is_false(c:GetVertTile())
    for _, t in ipairs({ 0.1, 0.3, 0.5, 0.7 }) do
      run:Draw(t)
      local x, y, point = at(c)
      assert.are.equal("TOPLEFT", point)
      assert.are.same({ 980, 900 }, { x, y })
      assert.are.same({ 440, 600 }, { c:GetWidth(), c:GetHeight() })
      local shimmer = 1 - 0.2 + 0.2 * (0.5 + 0.5 * math.sin(2 * math.pi * 3 * t))
      assert.is_true(near(c:GetAlpha(), envelope(BEAM.Open.Column, t) * 0.5 * shimmer), "at " .. t)
      local _, top = c:GetTexCoord()
      assert.is_true(near(top, (0.5 * t) % 1), "flowing")
    end
    run:Draw(0.95)
    assert.is_false(c:IsShown())
  end)

  it("glows over the body as it materializes", function()
    local run = beam:Begin(panelOn(), "Open")
    local g = run.glow
    assert.are.equal("glow.png", g:GetTexture())
    run:Draw(0.05)
    assert.is_false(g:IsShown(), "not yet")
    for _, t in ipairs({ 0.2, 0.4, 0.6 }) do
      run:Draw(t)
      assert.is_true(g:IsShown())
      local x, y, point = at(g)
      assert.are.equal("TOPLEFT", point)
      assert.are.same({ 1000, 900 }, { x, y })
      assert.are.same({ 400, 600 }, { g:GetWidth(), g:GetHeight() })
      assert.is_true(near(g:GetAlpha(), envelope(BEAM.Open.Glow, t) * 0.6), "at " .. t)
      local r, gg, b = g:GetVertexColor()
      local cr, cg, cb = style:RGBA("Gold")
      assert.are.same({ cr, cg, cb }, { r, gg, b })
    end
  end)

  it("shows the panel under it over its Reveal as it beams down", function()
    local run = beam:Begin(panelOn(), "Open")
    assert.are.equal(0, run:Draw(0.3))
    assert.is_true(near(0.5, run:Draw(0.45)))
    assert.are.equal(1, run:Draw(0.6))
    assert.are.equal(1, run:Draw(0.8))
  end)

  it("fades the panel out of it over its Fade as it beams up, by its own envelopes", function()
    local run = beam:Begin(panelOn(), "Close")
    assert.are.equal(1, run:Draw(0.1))
    assert.is_true(near(0.5, run:Draw(0.35)))
    assert.are.equal(0, run:Draw(0.5))
    run:Draw(0.05)
    assert.is_true(near(run.glow:GetAlpha(), envelope(BEAM.Close.Glow, 0.05) * 0.6))
    local shimmer = 1 - 0.2 + 0.2 * (0.5 + 0.5 * math.sin(2 * math.pi * 3 * 0.05))
    assert.is_true(near(run.column:GetAlpha(), envelope(BEAM.Close.Column, 0.05) * 0.5 * shimmer))
    run:Draw(0.92)
    assert.is_true(run.column:IsShown(), "its column out by its own envelope")
  end)

  -- Asked: "make sure it covers the window + it's decoration fully, it's a bit too small on all sides"; then "it's too
  -- far to the left (leave tabs out) and not enough on the right".
  it("covers the window and its decoration: a Margin past the body evenly all round, its tabs left out", function()
    local s = copy(BEAM)
    s.Margin = 12
    theme(s)
    for _, side in ipairs({ "RIGHT", "LEFT" }) do
      local panel = panelOn()
      panel.side = side
      panel.tabs = { Width = function() return 60 end }
      local run = beam:Begin(panel, "Open")
      -- 424 x 624 is 26.5 squares of 100: 2 to a square.
      assert.are.equal(53, #run.sparkles)
      for _, sp in ipairs(run.sparkles) do
        assert.is_true(sp.x >= 988 - 10 and sp.x <= 1412 + 10, side .. " across")
        assert.is_true(sp.y >= 288 and sp.y <= 912, side .. " down")
      end
      run:Draw(0.3)
      local x, y = at(run.glow)
      assert.are.same({ 988, 912, 424, 624 }, { x, y, run.glow:GetWidth(), run.glow:GetHeight() })
      x, y = at(run.column)
      assert.are.same({ 968, 912, 464, 624 }, { x, y, run.column:GetWidth(), run.column:GetHeight() })
      run:Release()
    end
    -- At the panel's scale: its margin a half.
    local run = beam:Begin(panelOn(0.5), "Open")
    run:Draw(0.3)
    local x, y = at(run.glow)
    assert.are.same({ 994, 906, 212, 312 }, { x, y, run.glow:GetWidth(), run.glow:GetHeight() })
  end)

  -- Asked: "the top and bottom beam are cut off extremely clean on the horizontal plane, almost like it's clipped at the
  -- top and bottom".
  describe("its ends (Ends)", function()
    local function withEnds(ends)
      local s = copy(BEAM)
      s.Ends = ends
      theme(s)
    end

    it("runs its column and glow Ends past the top and bottom of what it covers", function()
      withEnds(50)
      local run = beam:Begin(panelOn(), "Open")
      run:Draw(0.3)
      local x, y = at(run.column)
      assert.are.same({ 980, 950, 440, 700 }, { x, y, run.column:GetWidth(), run.column:GetHeight() })
      x, y = at(run.glow)
      assert.are.same({ 1000, 950, 400, 700 }, { x, y, run.glow:GetWidth(), run.glow:GetHeight() })
    end)

    it("fades its column out to nothing over each end: a mask at its top and one at its bottom, the column's own", function()
      withEnds(50)
      local run = beam:Begin(panelOn(), "Open")
      local c = run.column
      assert.are.equal(2, c:GetNumMaskTextures())
      local masks = { c:GetMaskTexture(1), c:GetMaskTexture(2) }
      for i, m in ipairs(masks) do
        -- Each its own image: a mask's coordinates are ignored by the client (spec/helpers/wow_mocks.lua).
        assert.are.equal(beam.END_MASKS[i == 1 and "TOP" or "BOTTOM"], m:GetTexture())
        assert.are.equal(50, m:GetHeight())
        local corner = i == 1 and "TOP" or "BOTTOM"
        local seen = {}
        for p = 1, m:GetNumPoints() do
          local point, rel, relPoint, px, py = m:GetPoint(p)
          assert.are.equal(c, rel)
          assert.are.equal(point, relPoint)
          assert.are.same({ 0, 0 }, { px, py })
          seen[point] = true
        end
        assert.are.same({ [corner .. "LEFT"] = true, [corner .. "RIGHT"] = true }, seen)
      end
      assert.are_not.equal(beam.END_MASKS.TOP, beam.END_MASKS.BOTTOM)
      run:Draw(0.3)
      local _, top = c:GetTexCoord()
      assert.is_true(near(top, 0.5 * 0.3), "its own art still scrolls")
    end)

    it("gives its masks back with its column, so a texture reused for a sparkle is not cut", function()
      withEnds(50)
      local run = beam:Begin(panelOn(), "Open")
      local c = run.column
      run:Release()
      assert.are.equal(0, c:GetNumMaskTextures())
      theme(copy(BEAM))
      local next = beam:Begin(panelOn(), "Open")
      for _, sp in ipairs(next.sparkles) do
        assert.are.equal(0, sp.texture:GetNumMaskTextures())
      end
      assert.are.equal(0, next.column:GetNumMaskTextures(), "no ends, no masks")
    end)

    it("scatters its sparkles over the ends too, as dense, fading out over them as the column does", function()
      withEnds(50)
      local run = beam:Begin(panelOn(), "Open")
      -- 400 x 700 is 28 squares of 100: 2 to a square.
      assert.are.equal(56, #run.sparkles)
      local over = 0
      for _, sp in ipairs(run.sparkles) do
        assert.is_true(sp.y >= 250 and sp.y <= 950)
        if sp.y > 900 or sp.y < 300 then over = over + 1 end
      end
      assert.is_true(over > 0, "some over the ends")
      for _, t in ipairs({ 0.25, 0.3, 0.35, 0.4 }) do
        run:Draw(t)
        local env = envelope(BEAM.Open.Sparkles, t)
        for _, sp in ipairs(run.sparkles) do
          local _, y = at(sp.texture)
          assert.is_true(y >= 250 and y < 950, "drifting round the beam, ends and all")
          local fade = smoothstep(250, 300, y) * (1 - smoothstep(900, 950, y))
          local tw = ((1 + math.sin(2 * math.pi * sp.twinkle * t + sp.phase)) / 2) ^ 2
          assert.is_true(near(sp.texture:GetAlpha(), env * tw * 0.8 * fade, 1e-6), "faded by where it is: " .. y)
        end
      end
    end)

    it("runs past its ends at the panel's scale", function()
      withEnds(50)
      local run = beam:Begin(panelOn(0.5), "Open")
      run:Draw(0.3)
      local _, y = at(run.column)
      assert.are.same({ 925, 350 }, { y, run.column:GetHeight() })
      assert.are.equal(25, run.column:GetMaskTexture(1):GetHeight())
    end)
  end)

  it("draws only its sparkles when it has no column or glow", function()
    local s = copy(BEAM)
    s.Column, s.Glow = nil, nil
    theme(s)
    local run = beam:Begin(panelOn(), "Open")
    assert.is_nil(run.column)
    assert.is_nil(run.glow)
    run:Draw(0.3)
    assert.is_true(run.sparkles[1].texture:IsShown() or run.sparkles[2].texture:IsShown())
  end)

  it("beams a panel at its scale: the same sparkles, smaller and slower, its column's Spread scaled", function()
    -- Every fleck at the far left of where it may be: its Spread (10) at the scale of a half, past the body's side.
    local saved = beam.Random
    beam.Random = function() return 0 end
    local edge = beam:Begin(panelOn(0.5), "Open")
    for _, s in ipairs(edge.sparkles) do
      assert.are.equal(995, s.x)
    end
    edge:Release()
    beam.Random = saved
    local run = beam:Begin(panelOn(0.5), "Open")
    assert.are.equal(48, #run.sparkles)
    run:Draw(0.3)
    for _, s in ipairs(run.sparkles) do
      assert.are.equal(15, math.abs(s.drift))
      assert.is_true(s.texture:GetWidth() <= 4 + 1e-9)
    end
    local x = at(run.column)
    assert.are.equal(990, x)
    assert.are.equal(220, run.column:GetWidth())
  end)

  describe("lingering", function()
    it("lives on by itself from where the panel left it, then is given back and stops", function()
      local run = beam:Begin(panelOn(), "Open")
      run:Draw(0.6)
      run:Linger(0.6)
      local driver = beam:Layer().driver
      local step = driver:GetScript("OnUpdate")
      assert.is_not_nil(step)
      step(driver, 0.1)
      assert.is_true(beam.living[run])
      assert.is_true(near(run.column:GetAlpha(), envelope(BEAM.Open.Column, 0.7) * 0.5
        * (1 - 0.2 + 0.2 * (0.5 + 0.5 * math.sin(2 * math.pi * 3 * 0.7)))), "drawn where it is")
      step(driver, 0.15)
      assert.is_true(beam.living[run], "its column out at 0.9")
      local textures = { run.column, run.glow }
      for _, s in ipairs(run.sparkles) do table.insert(textures, s.texture) end
      step(driver, 0.1)
      assert.is_nil(beam.living[run])
      assert.is_nil(driver:GetScript("OnUpdate"), "cleared, and the driver stopped")
      for _, t in ipairs(textures) do
        assert.is_false(t:IsShown())
      end
    end)

    it("gives everything back as it is released, and a new run takes it again; Init lets go of what lingers", function()
      local run = beam:Begin(panelOn(), "Open")
      run:Draw(0.3)
      local textures = { [run.column] = true, [run.glow] = true }
      for _, s in ipairs(run.sparkles) do textures[s.texture] = true end
      run:Release()
      run:Release()
      for t in pairs(textures) do
        assert.is_false(t:IsShown())
      end
      local again = beam:Begin(panelOn(), "Open")
      local reused = 0
      for _, s in ipairs(again.sparkles) do
        if textures[s.texture] then reused = reused + 1 end
      end
      if textures[again.column] then reused = reused + 1 end
      if textures[again.glow] then reused = reused + 1 end
      assert.are.equal(50, reused)
      again:Draw(0.3)
      local column = again.column
      assert.is_true(column:IsShown())
      again:Linger(0.3)
      beam:Init()
      assert.is_nil(next(beam.living))
      assert.is_false(column:IsShown())
      assert.is_nil(beam:Layer().driver:GetScript("OnUpdate"))
    end)
  end)
end)
