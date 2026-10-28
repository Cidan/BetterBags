-- smoke_spec.lua -- NextSmoke (next/smoke.lua): a Next theme's panel appearing out of a puff of smoke (Panel.Smoke,
-- next-themes.md §23; the Halloween theme; asked: "the bags should appear in a puff of smoke from bottom to top (get that
-- smoke right! make it feel really good)"). A front rises up the body; rows of cartoon puffs pop out of it (a little past
-- their size and back), billow up and out from the middle, hold, then shrink away, the first born (the bottom) first, so
-- the smoke clears from the bottom up as the panel shows under it. Sparks twinkle in it. A burst (Burst) covers a rect at
-- once and lives out on its own (the bats' close).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextSmoke", "next/smoke.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end
local smoke = addon:GetModule("NextSmoke")
local style = addon:GetModule("NextStyle")

local SMOKE = {
  Puffs = { Texture = "Puff", Colors = { "White", "Gold" }, Size = { 80, 80 }, Alpha = 0.9, BlendMode = "BLEND",
    Spin = 30 },
  Sparks = { Texture = "Star", Count = 6, Size = { 12, 12 }, Life = { 0.2, 0.2 }, Spin = 180, Colors = { "Gold" },
    Alpha = 1, BlendMode = "ADD" },
  Open = { Rise = 0.4, Spacing = 50, Grow = 0.12, Hold = 0.2, Shrink = 0.2, Lift = { 30, 30 }, Spread = { 40, 40 },
    Burst = 3, Reveal = { 0.1, 0.35 }, Jitter = 0 },
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
    Textures = { Puff = "puff.png", Star = "star.png" },
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

  it("opens only for a theme with a smoke open, its lock the reveal's end and its time the last puff's", function()
    assert.is_true(smoke:Opens())
    assert.are.equal(0.35, smoke:OpenLock())
    -- The last row is born as the front reaches the top (Rise), then pops, holds and shrinks.
    assert.is_true(near(0.4 + 0.12 + 0.2 + 0.2, smoke:OpenTime()))
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

  it("pops each puff out of the rising front, the bottom first, the top as the front reaches it", function()
    local run = smoke:Begin(panelOn())
    run:Open(0)
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
    run:Open(0.4)
    for _, p in ipairs(run.puffs) do
      assert.is_true(p.texture:IsShown(), "all out once the front is at the top")
    end
  end)

  it("pops a puff a little past its size, holds it there, then shrinks it away", function()
    local run = smoke:Begin(panelOn())
    local p
    for _, q in ipairs(run.puffs) do
      if near(q.y, 300) then p = q break end
    end
    run:Open(0.02)
    assert.is_true(p.texture:GetWidth() < 80, "growing")
    run:Open(0.12 * 0.75)
    assert.is_true(p.texture:GetWidth() > 80, "past its size")
    run:Open(0.12 + 0.1)
    assert.is_true(near(80, p.texture:GetWidth()))
    assert.are.equal(p.texture:GetWidth(), p.texture:GetHeight())
    assert.is_true(near(0.9, p.texture:GetAlpha()))
    run:Open(0.12 + 0.2 + 0.1)
    -- Half way through its shrinking, an ease in: 1 - 0.5^2 of its size.
    assert.is_true(near(80 * 0.75, p.texture:GetWidth()), "shrinking, slowly at first")
    run:Open(0.12 + 0.2 + 0.19)
    assert.is_true(p.texture:GetAlpha() < 0.9 * 0.2, "fading as it goes")
    run:Open(0.12 + 0.2 + 0.2 + 0.001)
    assert.is_false(p.texture:IsShown(), "gone")
  end)

  it("clears from the bottom up", function()
    local run = smoke:Begin(panelOn())
    -- The bottom row has gone (0.52) while the rows above still hold.
    run:Open(0.55)
    local shownBelow, shownAbove = 0, 0
    for _, p in ipairs(run.puffs) do
      if near(p.y, 300) and p.texture:IsShown() then shownBelow = shownBelow + 1 end
      if near(p.y, 900) and p.texture:IsShown() then shownAbove = shownAbove + 1 end
    end
    assert.are.equal(0, shownBelow)
    assert.are.equal(10, shownAbove)
    run:Open(smoke:OpenTime() + 0.001)
    for _, p in ipairs(run.puffs) do
      assert.is_false(p.texture:IsShown())
    end
  end)

  it("shows the panel under the smoke as it covers it", function()
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

  it("billows up and out from the middle, the bottom row bursting sideways along the floor", function()
    local run = smoke:Begin(panelOn())
    run:Open(0.45)
    local ok = 0
    for _, p in ipairs(run.puffs) do
      if p.texture:IsShown() then
        local x, y = at(p.texture)
        local age = 0.45 - p.born
        assert.is_true(near(y, p.y + 30 * age, 1e-6), "rising 30 a second")
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

  it("turns each puff as it goes, in the theme's colours and look", function()
    local run = smoke:Begin(panelOn())
    local colors = {}
    run:Open(0.3)
    for _, p in ipairs(run.puffs) do
      local t = p.texture
      assert.are.equal("puff.png", t:GetTexture())
      assert.are.equal("BLEND", t:GetBlendMode())
      local r, g, b = t:GetVertexColor()
      colors[string.format("%.3f %.3f %.3f", r, g, b)] = true
      if t:IsShown() then
        local age = 0.3 - p.born
        assert.is_true(near(t:GetRotation(), p.spin * age))
        assert.is_true(math.abs(p.spin) <= math.rad(30) + 1e-9)
      end
    end
    local wr, wg, wb = style:RGBA("White")
    local gr, gg, gb = style:RGBA("Gold")
    assert.is_true(colors[string.format("%.3f %.3f %.3f", wr, wg, wb)])
    assert.is_true(colors[string.format("%.3f %.3f %.3f", gr, gg, gb)])
  end)

  it("twinkles sparks in the smoke as it rises, each out and gone over its life", function()
    local run = smoke:Begin(panelOn())
    assert.are.equal(6, #run.sparks)
    for _, s in ipairs(run.sparks) do
      assert.is_true(s.born >= 0 and s.born <= 0.4)
      assert.is_true(s.x >= 1000 and s.x <= 1400)
      assert.is_true(s.y >= 300 and s.y <= 900)
      assert.are.equal("star.png", s.texture:GetTexture())
      run:Open(s.born + 0.05)
      assert.is_true(near(12 * math.sin(math.pi / 4), s.texture:GetWidth()), "growing a quarter through its life")
      run:Open(s.born + 0.1)
      assert.is_true(s.texture:IsShown())
      assert.is_true(near(12, s.texture:GetWidth()), "at its size half way through its life")
      run:Open(s.born + 0.2 + 0.001)
      assert.is_false(s.texture:IsShown())
    end
  end)

  it("draws the smoke of a panel at its scale", function()
    local run = smoke:Begin(panelOn(0.5))
    -- 300 / 25 = 12 rows apart and 200 / 25 = 8 columns apart: the same puffs, at half their size.
    assert.are.equal(130, #run.puffs)
    run:Open(0.12 + 0.1)
    for _, p in ipairs(run.puffs) do
      if p.texture:IsShown() and near(p.y, 900 - 300) then
        assert.is_true(near(40, p.texture:GetWidth()))
      end
    end
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

  describe("a burst", function()
    local BURST = { Texture = "Puff", Colors = { "White" }, Size = { 60, 60 }, Alpha = 1, Spacing = 40, Grow = 0.1,
      Hold = 0.1, Shrink = 0.2, Lift = { 20, 20 }, Spread = { 30, 30 }, Jitter = 0 }

    it("covers a rect at once and lives out on its own, then stops", function()
      local run = smoke:Burst({ left = 100, top = 500, width = 120, height = 80 }, 1, BURST)
      -- 120 / 40 = 3 columns apart, and one outside each side: 5; 80 / 40 = 2 rows apart: 3.
      assert.are.equal(15, #run.puffs)
      local puffs = run.puffs
      local driver = smoke:Layer().driver
      local step = driver:GetScript("OnUpdate")
      assert.is_not_nil(step)
      step(driver, 0.05)
      for _, p in ipairs(run.puffs) do
        assert.is_true(p.texture:IsShown(), "every puff out at once")
      end
      step(driver, 0.4)
      assert.is_nil(driver:GetScript("OnUpdate"), "gone, and the driver stopped")
      for _, p in ipairs(puffs) do
        assert.is_false(p.texture:IsShown())
      end
    end)

    it("is given back when the smoke starts again", function()
      local run = smoke:Burst({ left = 100, top = 500, width = 120, height = 80 }, 1, BURST)
      local puffs = run.puffs
      local step = smoke:Layer().driver:GetScript("OnUpdate")
      step(smoke:Layer().driver, 0.05)
      smoke:Init()
      assert.are.equal(15, #puffs)
      for _, p in ipairs(puffs) do
        assert.is_false(p.texture:IsShown())
      end
      assert.is_nil(smoke:Layer().driver:GetScript("OnUpdate"))
    end)
  end)
end)
