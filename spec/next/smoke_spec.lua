-- smoke_spec.lua -- NextSmoke (next/smoke.lua): a Next theme's panel appearing out of smoke (Panel.Smoke, next-themes.md
-- §23; the Halloween theme; asked: "the bags should appear in a puff of smoke from bottom to top (get that smoke right!
-- make it feel really good)", then, of a first cartoon version: "can you make it more real-ish?"). A front rises up the
-- body; rows of soft, wispy puffs are born from it, each swelling as it rises (faster and faster, warm), drifting out
-- from the middle and swirling, turning from an angle of its own, fading in quickly and thinning slowly away; the first
-- born first, so the smoke clears from the bottom up as the panel shows under it. Embers rise in it. The panel has shown
-- once it has fully appeared; the smoke lingers on its own layer until it has cleared (Linger).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextSmoke", "next/smoke.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end
local smoke = addon:GetModule("NextSmoke")
local style = addon:GetModule("NextStyle")

local SMOKE = {
  Puffs = { Texture = "Smoke", Colors = { "White", "Gold" }, Size = { 100, 100 }, Alpha = { 0.6, 0.6 },
    BlendMode = "BLEND", Spin = 30 },
  Sparks = { Texture = "Glow", Count = 6, Size = { 6, 6 }, Life = { 0.4, 0.4 }, Rise = { 50, 50 },
    Colors = { "Gold" }, Alpha = 1, BlendMode = "ADD" },
  Open = { Rise = 0.4, Spacing = 50, Jitter = 0, Life = { 0.5, 0.5 }, Start = 0.5, Growth = 2, FadeIn = 0.1,
    Lift = { 30, 30 }, Buoyancy = 40, Spread = { 40, 40 }, Burst = 3, Swirl = { 0, 0 }, Reveal = { 0.1, 0.35 } },
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
    Textures = { Smoke = "smoke.png", Glow = "glow.png" },
    Panel = { Smoke = spec },
  })
end

local function near(a, b, eps)
  return math.abs(a - b) <= (eps or 1e-6)
end

-- Where a texture's middle is on the layer, y up.
local function at(t)
  local point, rel, relPoint, x, y = t:GetPoint(1)
  assert.are.same({ "CENTER", "BOTTOMLEFT" }, { point, relPoint })
  assert.are.equal(smoke:Layer(), rel)
  return x, y
end

local function smoothstep(e0, e1, x)
  local t = math.max(0, math.min(1, (x - e0) / (e1 - e0)))
  return t * t * (3 - 2 * t)
end

describe("NextSmoke", function()
  local savedRandom

  -- panelOn makes what the smoke reads of a panel: its body's rect on the screen (left 1000, top 900, 400 x 600, so from
  -- 300 up to 900), at a scale.
  local function panelOn(scale)
    local frame = CreateFrame("Frame", nil, UIParent)
    local panel = { frame = frame, side = "RIGHT" }
    function panel:BodyRect() return 1000, 900, 600 * (scale or 1), 400 * (scale or 1), scale or 1 end
    return panel
  end

  -- A puff of the bottom row.
  local function bottomPuff(run)
    for _, p in ipairs(run.puffs) do
      if near(p.y, 300) then return p end
    end
  end

  before_each(function()
    savedRandom = smoke.Random
    local seed = 7
    smoke.Random = function()
      seed = (seed * 16807) % 2147483647
      return seed / 2147483647
    end
    smoke:Init()
    theme(copy(SMOKE))
  end)

  after_each(function()
    smoke.Random = savedRandom
    smoke:Init()
    UseNextTheme(nil)
  end)

  it("opens only for a theme with a smoke open; the panel has shown as the reveal ends, the smoke clears later", function()
    assert.is_true(smoke:Opens())
    assert.are.equal(0.35, smoke:OpenLock())
    assert.are.equal(0.35, smoke:OpenTime())
    -- The last row is born as the front reaches the top (Rise), and lives its Life.
    assert.is_true(near(0.4 + 0.5, smoke:ClearTime()))
    local s = copy(SMOKE)
    s.Open = nil
    theme(s)
    assert.is_false(smoke:Opens())
    UseNextTheme({})
    assert.is_false(smoke:Opens())
    assert.is_nil(smoke:Spec())
  end)

  it("draws on a layer over the screen above the panels, taking no mouse", function()
    local layer = smoke:Layer()
    assert.are.equal("DIALOG", layer:GetFrameStrata())
    assert.is_false(layer:IsMouseEnabled())
    local run = smoke:Begin(panelOn())
    for _, p in ipairs(run.puffs) do
      assert.are.equal(layer, p.texture:GetParent())
    end
  end)

  it("covers the body in rows and columns of puffs, a column outside each side", function()
    local run = smoke:Begin(panelOn())
    -- 600 / 50 = 12 rows apart: 13 rows; 400 / 50 = 8 columns apart, and one outside each side: 10.
    assert.are.equal(130, #run.puffs)
    local xs, ys = {}, {}
    for _, p in ipairs(run.puffs) do
      xs[p.x] = true
      ys[p.y] = true
    end
    local cols, rows = {}, {}
    for x in pairs(xs) do table.insert(cols, x) end
    for y in pairs(ys) do table.insert(rows, y) end
    table.sort(cols)
    table.sort(rows)
    assert.are.equal(10, #cols)
    assert.are.equal(13, #rows)
    assert.is_true(near(975, cols[1]) and near(1425, cols[10]), "half a column past each side")
    assert.is_true(near(300, rows[1]) and near(900, rows[13]), "from the bottom to the top")
  end)

  it("is born from the rising front, the bottom first, the top as the front reaches it", function()
    local run = smoke:Begin(panelOn())
    run:Open(0.001)
    for _, p in ipairs(run.puffs) do
      assert.are.equal(near(p.y, 300), p.texture:IsShown(), "only the bottom row at first")
    end
    -- Half way up the body (f = 0.5) when 1 - (1 - u)^2 = 0.5: u = 1 - sqrt(0.5).
    local half = 0.4 * (1 - math.sqrt(0.5))
    run:Open(half - 0.01)
    for _, p in ipairs(run.puffs) do
      if p.y > 600 + 1e-6 then
        assert.is_false(p.texture:IsShown(), "above the front: not yet")
      end
    end
    run:Open(half + 0.01)
    for _, p in ipairs(run.puffs) do
      if p.y <= 600 + 1e-6 then
        assert.is_true(p.texture:IsShown(), "below the front: out")
      end
    end
    run:Open(0.401)
    for _, p in ipairs(run.puffs) do
      assert.is_true(p.texture:IsShown(), "all out once the front is at the top")
    end
  end)

  -- Real smoke: born small and dense, swelling as it goes, thinning away rather than shrinking.
  it("swells from half its size to twice it, fading in quickly and thinning slowly away", function()
    local run = smoke:Begin(panelOn())
    local p = bottomPuff(run)
    run:Open(0.0001)
    assert.is_true(near(50, p.texture:GetWidth(), 0.1), "half its size as it is born")
    assert.is_true(p.texture:GetAlpha() < 0.01, "fading in")
    run:Open(0.05)
    -- A tenth through its life: 1 - (1 - 0.1)^2 of the way from half its size to twice it; fully in.
    assert.is_true(near(100 * (0.5 + 1.5 * 0.19), p.texture:GetWidth()))
    assert.are.equal(p.texture:GetWidth(), p.texture:GetHeight())
    assert.is_true(near(0.6, p.texture:GetAlpha()), "in, at its own alpha")
    run:Open(0.25)
    assert.is_true(near(100 * (0.5 + 1.5 * 0.75), p.texture:GetWidth()), "half through: swollen, slowing")
    assert.is_true(near(0.6 * (1 - smoothstep(0.3, 1, 0.5)), p.texture:GetAlpha()), "thinning")
    run:Open(0.475)
    assert.is_true(p.texture:GetAlpha() < 0.6 * 0.05, "nearly gone")
    run:Open(0.5001)
    assert.is_false(p.texture:IsShown(), "gone once its life is over")
  end)

  it("clears from the bottom up", function()
    local run = smoke:Begin(panelOn())
    run:Open(0.52)
    local shownBelow, shownAbove = 0, 0
    for _, p in ipairs(run.puffs) do
      if near(p.y, 300) and p.texture:IsShown() then shownBelow = shownBelow + 1 end
      if near(p.y, 900) and p.texture:IsShown() then shownAbove = shownAbove + 1 end
    end
    assert.are.equal(0, shownBelow)
    assert.are.equal(10, shownAbove)
    run:Open(smoke:ClearTime() + 0.001)
    for _, p in ipairs(run.puffs) do
      assert.is_false(p.texture:IsShown())
    end
  end)

  it("shows the panel under the smoke over its reveal", function()
    local run = smoke:Begin(panelOn())
    assert.are.equal(0, run:Open(0))
    assert.are.equal(0, run:Open(0.1))
    local last = 0
    for t = 0.1, 0.35, 0.025 do
      local a = run:Open(t)
      assert.is_true(a >= last)
      last = a
    end
    local a = run:Open(0.225)
    assert.is_true(near(0.5, a), "half shown half way through its Reveal: " .. a)
    assert.are.equal(1, run:Open(0.35))
    assert.are.equal(1, run:Open(0.8))
  end)

  it("rises faster and faster and drifts out from the middle, the bottom row along the floor", function()
    local run = smoke:Begin(panelOn())
    run:Open(0.45)
    local ok = 0
    for _, p in ipairs(run.puffs) do
      if p.texture:IsShown() then
        local x, y = at(p.texture)
        local age = 0.45 - p.born
        assert.is_true(near(y, p.y + 30 * age + 0.5 * 40 * age * age, 1e-6), "rising 30 a second, buoyed")
        if p.x < 1200 - 1e-6 then
          assert.is_true(x < p.x, "left of the middle: out to the left")
        elseif p.x > 1200 + 1e-6 then
          assert.is_true(x > p.x, "right of it: out to the right")
        end
        local share = math.abs(p.x - 1200) / 200
        local burst = near(p.y, 300) and 3 or 1
        assert.is_true(near(math.abs(x - p.x), 40 * share * burst * age, 1e-6))
        ok = ok + 1
      end
    end
    assert.is_true(ok > 50)
  end)

  it("swirls across its drift, no more than its Swirl", function()
    local s = copy(SMOKE)
    s.Open.Swirl = { 12, 1.5 }
    s.Open.Spread = { 0, 0 }
    theme(s)
    local run = smoke:Begin(panelOn())
    local seen = 0
    for t = 0.05, 0.45, 0.05 do
      run:Open(t)
      for _, p in ipairs(run.puffs) do
        if p.texture:IsShown() then
          local x = at(p.texture)
          assert.is_true(math.abs(x - p.x) <= 12 + 1e-6)
          if math.abs(x - p.x) > 1 then seen = seen + 1 end
        end
      end
    end
    assert.is_true(seen > 20, "swirling")
  end)

  it("curls from a phase of its own, growing in over the first two fifths of its life", function()
    local s = copy(SMOKE)
    -- Never swinging (0 a second), so each puff stands off its line by its own phase alone.
    s.Open.Swirl = { 12, 0 }
    s.Open.Spread = { 0, 0 }
    theme(s)
    local run = smoke:Begin(panelOn())
    local off, phases = 0, {}
    for t = 0.02, 0.42, 0.04 do
      run:Open(t)
      for _, p in ipairs(run.puffs) do
        phases[string.format("%.4f", p.swirl)] = true
        if p.texture:IsShown() then
          local x = at(p.texture)
          local q = (t - p.born) / p.life
          assert.is_true(near(x - p.x, 12 * math.sin(p.swirl) * smoothstep(0, 0.4, q), 1e-6), "grown in by its age")
          if math.abs(x - p.x) > 1 then off = off + 1 end
        end
      end
    end
    local n = 0
    for _ in pairs(phases) do n = n + 1 end
    assert.is_true(n > 100, "each from its own phase")
    assert.is_true(off > 20, "off its line")
  end)

  it("turns each puff as it goes from an angle of its own, in the theme's colours and at its own alpha", function()
    local s = copy(SMOKE)
    s.Puffs.Alpha = { 0.4, 0.8 }
    theme(s)
    local run = smoke:Begin(panelOn())
    local colors, angles, alphas = {}, {}, {}
    for _, p in ipairs(run.puffs) do
      local t = p.texture
      assert.are.equal("smoke.png", t:GetTexture())
      assert.are.equal("BLEND", t:GetBlendMode())
      local r, g, b = t:GetVertexColor()
      colors[string.format("%.3f %.3f %.3f", r, g, b)] = true
      angles[string.format("%.4f", p.angle)] = true
      assert.is_true(p.alpha >= 0.4 and p.alpha <= 0.8)
      alphas[string.format("%.3f", p.alpha)] = true
      assert.is_true(math.abs(p.spin) <= math.rad(30) + 1e-9)
    end
    run:Open(0.3)
    for _, p in ipairs(run.puffs) do
      if p.texture:IsShown() then
        assert.is_true(near(p.texture:GetRotation(), p.angle + p.spin * (0.3 - p.born)))
      end
    end
    local wr, wg, wb = style:RGBA("White")
    local gr, gg, gb = style:RGBA("Gold")
    assert.is_true(colors[string.format("%.3f %.3f %.3f", wr, wg, wb)])
    assert.is_true(colors[string.format("%.3f %.3f %.3f", gr, gg, gb)])
    local n, m = 0, 0
    for _ in pairs(angles) do n = n + 1 end
    for _ in pairs(alphas) do m = m + 1 end
    assert.is_true(n > 100, "each from its own angle")
    assert.is_true(m > 100, "each at its own alpha")
  end)

  it("sends embers up through the smoke as it rises, each twinkling out and gone over its life", function()
    local run = smoke:Begin(panelOn())
    assert.are.equal(6, #run.sparks)
    for _, s in ipairs(run.sparks) do
      assert.is_true(s.born >= 0 and s.born <= 0.4)
      assert.is_true(s.x >= 1000 and s.x <= 1400)
      assert.is_true(s.y >= 300 and s.y <= 900)
      assert.are.equal("glow.png", s.texture:GetTexture())
      run:Open(s.born + 0.1)
      assert.is_true(near(6 * math.sin(math.pi / 4), s.texture:GetWidth()), "growing a quarter through its life")
      local _, y0 = at(s.texture)
      assert.is_true(near(s.y + 50 * 0.1, y0), "rising 50 a second")
      run:Open(s.born + 0.2)
      assert.is_true(s.texture:IsShown())
      assert.is_true(near(6, s.texture:GetWidth()), "at its size half way through its life")
      run:Open(s.born + 0.4 + 0.001)
      assert.is_false(s.texture:IsShown())
    end
  end)

  it("draws the smoke of a panel at its scale", function()
    local run = smoke:Begin(panelOn(0.5))
    -- 300 / 25 = 12 rows apart and 200 / 25 = 8 columns apart: the same puffs, at half their size, rising half as fast.
    assert.are.equal(130, #run.puffs)
    run:Open(0.0001)
    for _, p in ipairs(run.puffs) do
      if p.texture:IsShown() then
        assert.is_true(near(25, p.texture:GetWidth(), 0.1))
        assert.are.equal(15, p.vy)
      end
    end
    -- Buoyed half as much: 40 a second a second at its scale of a half.
    run:Open(0.3)
    local seen = 0
    for _, p in ipairs(run.puffs) do
      if p.texture:IsShown() then
        local _, y = at(p.texture)
        local age = 0.3 - p.born
        assert.is_true(near(y, p.y + 15 * age + 0.5 * 20 * age * age, 1e-6))
        seen = seen + 1
      end
    end
    assert.is_true(seen > 20)
  end)

  it("gives everything back as it is released, and a new run takes it again", function()
    local run = smoke:Begin(panelOn())
    run:Open(0.3)
    local textures = {}
    for _, p in ipairs(run.puffs) do textures[p.texture] = true end
    run:Release()
    for t in pairs(textures) do
      assert.is_false(t:IsShown())
    end
    run:Release()
    local again = smoke:Begin(panelOn())
    local reused = 0
    for _, p in ipairs(again.puffs) do
      if textures[p.texture] then reused = reused + 1 end
    end
    assert.are.equal(130, reused)
  end)

  describe("lingering", function()
    it("lives on by itself from where the panel left it, then is given back and stops", function()
      local run = smoke:Begin(panelOn())
      run:Open(0.35)
      local puffs = run.puffs
      run:Linger(0.35)
      local driver = smoke:Layer().driver
      local step = driver:GetScript("OnUpdate")
      assert.is_not_nil(step)
      step(driver, 0.2)
      -- 0.55 in: the top row (born at 0.4) still out, the bottom (born at 0, living 0.5) gone.
      local top, bottom = 0, 0
      for _, p in ipairs(puffs) do
        if p.texture:IsShown() then
          if near(p.y, 900) then top = top + 1 end
          if near(p.y, 300) then bottom = bottom + 1 end
        end
      end
      assert.are.equal(10, top)
      assert.are.equal(0, bottom)
      -- 0.85 in: the top row lives until 0.9, so the smoke still lingers.
      step(driver, 0.3)
      assert.is_true(smoke.living[run])
      assert.is_true(puffs[#puffs].texture:IsShown(), "the last puff still out")
      step(driver, 0.1)
      assert.is_nil(driver:GetScript("OnUpdate"), "cleared, and the driver stopped")
      for _, p in ipairs(puffs) do
        assert.is_false(p.texture:IsShown())
      end
      assert.is_nil(next(smoke.living))
    end)

    it("is given back when the smoke starts again", function()
      local run = smoke:Begin(panelOn())
      run:Open(0.35)
      local puffs = run.puffs
      run:Linger(0.35)
      smoke:Init()
      assert.are.equal(130, #puffs)
      for _, p in ipairs(puffs) do
        assert.is_false(p.texture:IsShown())
      end
      assert.is_nil(smoke:Layer().driver:GetScript("OnUpdate"))
    end)
  end)
end)
