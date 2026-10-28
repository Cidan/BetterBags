-- bats_spec.lua -- NextBats (next/bats.lua): a Next theme's panel breaking up and turning into bats as it closes, and
-- bats fluttering out of its header now and then while it shows (Panel.Bats, next-themes.md §23; the Halloween theme;
-- asked: "make the bag 'turn into' several bats, like 10-15 bats, and fly away in random directions off screen", then:
-- "no puff of smokes: how the frost theme shatters, we want the bag break up *and morph* into bats and fly away. almost
-- a surreal effect"). Closing: the panel trembles, then breaks into pieces of its own art that drift apart from where it
-- breaks; each in its own time shrinks, stretches into wings, flaps and darkens as a bat comes out of it (a flipbook
-- across the art), and the bat flies away from where it broke, faster and faster, wobbling and banking, off the screen.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextBats", "next/bats.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end
local bats = addon:GetModule("NextBats")

-- Blizzard's vertex indices (Blizzard_FrameXMLBase/Constants.lua).
local UL, LL, UR, LR = 1, 2, 3, 4

local BATS = {
  Texture = "Bats", Frames = 4, FrameRate = 10, Color = "White", BlendMode = "BLEND",
  Close = { Count = { 12, 12 }, Pieces = { Texture = "Body", Color = "White" }, Jitter = 0, Shudder = 0.1, Tremble = 3,
    Break = 0.1, Gap = 10, Morph = 0.3, Dark = "Black", Delay = { 0, 0.2 }, Size = { 40, 40 }, Speed = { 200, 200 },
    Accel = 1, Wobble = { 10, 2 }, Tilt = 20, Life = 3, Spread = 40 },
  Flutter = { Every = { 5, 5 }, Count = { 2, 2 }, Size = { 24, 24 }, Speed = { 100, 100 }, Wobble = { 6, 3 },
    Stagger = 0.3, Travel = 300, Band = { 30, 60 }, Rise = { -20, 20 }, Alpha = 0.9 },
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
    Textures = { Bats = "bats.png", Body = "body.png" },
    Panel = { Bats = spec },
  })
end

local function near(a, b, eps)
  return math.abs(a - b) <= (eps or 1e-6)
end

describe("NextBats", function()
  local savedRandom, savedCombat, combat

  before_each(function()
    savedRandom = bats.Random
    local seed = 11
    bats.Random = function()
      seed = (seed * 16807) % 2147483647
      return seed / 2147483647
    end
    savedCombat = _G.InCombatLockdown
    combat = false
    _G.InCombatLockdown = function() return combat end
    bats:Init()
    theme(copy(BATS))
  end)

  after_each(function()
    bats.Random = savedRandom
    _G.InCombatLockdown = savedCombat
    bats:Init()
    UseNextTheme(nil)
  end)

  describe("closing", function()
    -- What the close reads of a panel: its body's rect on the screen (left 1000, top 900, 400 x 600: from 300 up to 900;
    -- its middle at 1200, 600), at a scale, and its fill's (the same).
    local function panelOn(scale)
      local panel = { frame = CreateFrame("Frame", nil, UIParent), side = "RIGHT" }
      local s = scale or 1
      function panel:BodyRect() return 1000, 900, 600 * s, 400 * s, s end
      function panel:FillRect() return 1000, 900, 400 * s, 600 * s end
      return panel
    end

    local function step(dt)
      local d = bats:Layer().driver
      d:GetScript("OnUpdate")(d, dt)
    end

    -- The corners a piece's art draws at: its rect's corners (anchored at the layer's bottom left, 1 x 1) moved by its
    -- offsets, as { x, y } for its upper left, upper right, lower right and lower left.
    local function corners(t)
      local natural = { [UL] = { 0, 1 }, [LL] = { 0, 0 }, [UR] = { 1, 1 }, [LR] = { 1, 0 } }
      local out = {}
      for _, i in ipairs({ UL, UR, LR, LL }) do
        local x, y = t:GetVertexOffset(i)
        table.insert(out, { natural[i][1] + x, natural[i][2] + y })
      end
      return out
    end

    local function middle(cs)
      local x, y = 0, 0
      for _, c in ipairs(cs) do
        x, y = x + c[1] / 4, y + c[2] / 4
      end
      return x, y
    end

    local function area(cs)
      local sum = 0
      for i = 1, 4 do
        local a, b = cs[i], cs[i % 4 + 1]
        sum = sum + a[1] * b[2] - b[1] * a[2]
      end
      return math.abs(sum) / 2
    end

    local function width(cs, top)
      local a, b = top and cs[1] or cs[4], top and cs[2] or cs[3]
      return math.abs(b[1] - a[1])
    end

    -- Where a bat's middle is on the layer, y up.
    local function at(t)
      local point, rel, relPoint, x, y = t:GetPoint(1)
      assert.are.same({ "CENTER", "BOTTOMLEFT" }, { point, relPoint })
      assert.are.equal(bats:Layer(), rel)
      return x, y
    end

    it("closes only for a theme with a bats close", function()
      assert.is_true(bats:Closes())
      local s = copy(BATS)
      s.Close = nil
      theme(s)
      assert.is_false(bats:Closes())
      UseNextTheme({})
      assert.is_false(bats:Closes())
      assert.is_nil(bats:Spec())
    end)

    it("cuts the body into pieces of its own art that tile it exactly, unseen until it breaks", function()
      local s = copy(BATS)
      s.Close.Jitter = 0.3
      theme(s)
      local run = bats:Begin(panelOn())
      -- 12 pieces: 3 across (sqrt(12 * 400 / 600), rounded) and 4 down.
      assert.are.equal(12, #run.pieces)
      local layer = bats:Layer()
      local total, found = 0, 0
      for _, p in ipairs(run.pieces) do
        assert.are.equal(layer, p.art:GetParent())
        assert.are.equal("body.png", p.art:GetTexture())
        assert.is_false(p.art:IsShown())
        assert.is_false(p.bat:IsShown())
        total = total + area(p.corners)
        for _, c in ipairs(p.corners) do
          for _, corner in ipairs({ { 1000, 900 }, { 1400, 900 }, { 1400, 300 }, { 1000, 300 } }) do
            if math.abs(c[1] - corner[1]) < 1e-6 and math.abs(c[2] - corner[2]) < 1e-6 then found = found + 1 end
          end
        end
      end
      assert.is_true(near(400 * 600, total, 1e-3), "they tile it: " .. total)
      assert.are.equal(4, found, "its four corners still")
      -- Each piece's art is the fill where the piece lies, at each of its corners (the fill's left is 1000, its top 900,
      -- 400 x 600).
      for _, p in ipairs(run.pieces) do
        local coords = { p.art:GetTexCoord() }
        local cs = p.corners
        for k, corner in ipairs({ cs[1], cs[4], cs[2], cs[3] }) do
          assert.is_true(near(coords[2 * k - 1], (corner[1] - 1000) / 400), "across at corner " .. k)
          assert.is_true(near(coords[2 * k], (900 - corner[2]) / 600), "down at corner " .. k)
        end
      end
      -- The inner corners moved off the grid's lines (3 across, 4 down: 133.3 by 150), both ways.
      local offX, offY = false, false
      for _, p in ipairs(run.pieces) do
        for _, c in ipairs(p.corners) do
          local i, j = (c[1] - 1000) / (400 / 3), (900 - c[2]) / 150
          if math.abs(i - math.floor(i + 0.5)) > 0.01 then offX = true end
          if math.abs(j - math.floor(j + 0.5)) > 0.01 then offY = true end
        end
      end
      assert.is_true(offX and offY, "jittered")
    end)

    it("cuts as near square as its body allows, on the grid's lines without Jitter", function()
      local run = bats:Begin(panelOn())
      for _, p in ipairs(run.pieces) do
        local cs = p.corners
        assert.is_true(near(cs[2][1] - cs[1][1], 400 / 3) and near(cs[1][2] - cs[4][2], 150),
          "3 across and 4 down: 133.3 by 150")
      end
    end)

    it("trembles before it breaks, settling back where it was", function()
      local run = bats:Begin(panelOn())
      assert.are.equal(0, run:Shudder(0))
      local most = 0
      for t = 0.005, 0.1, 0.005 do
        local dx = run:Shudder(t)
        assert.is_true(math.abs(dx) <= 3 + 1e-9)
        most = math.max(most, math.abs(dx))
      end
      assert.is_true(most > 1, "trembling")
      assert.are.equal(0, run:Shudder(0.1))
      assert.are.equal(0, run:Shudder(0.2))
    end)

    it("trembles less and less, by its Tremble at the panel's scale", function()
      -- Swinging 24 times a second, so out to one side at 1/96 of a second and again at 5/96, dying away over Shudder.
      local run = bats:Begin(panelOn())
      assert.is_true(near(run:Shudder(1 / 96), 3 * (1 - (1 / 96) / 0.1)))
      assert.is_true(near(run:Shudder(5 / 96), 3 * (1 - (5 / 96) / 0.1)))
      run:Release()
      run = bats:Begin(panelOn(2))
      assert.is_true(near(run:Shudder(1 / 96), 6 * (1 - (1 / 96) / 0.1)))
    end)

    it("shows its pieces where the body was as it breaks, then drifts them apart from where it breaks", function()
      local run = bats:Begin(panelOn(), { x = 1000, y = 900 })
      run:Break()
      for _, p in ipairs(run.pieces) do
        assert.is_true(p.art:IsShown())
        local cs = corners(p.art)
        for k = 1, 4 do
          assert.is_true(near(p.corners[k][1], cs[k][1]) and near(p.corners[k][2], cs[k][2]), "in place")
        end
      end
      step(0.1)
      for _, p in ipairs(run.pieces) do
        if p.delay > 0 then
          local x, y = middle(corners(p.art))
          local d0 = math.sqrt((p.cx - 1000) ^ 2 + (p.cy - 900) ^ 2)
          local d1 = math.sqrt((x - 1000) ^ 2 + (y - 900) ^ 2)
          assert.is_true(near(d1 - d0, 10, 1e-6), "Gap away from where it broke: " .. (d1 - d0))
        end
      end
    end)

    it("drifts its pieces apart over Break, half way half way through", function()
      local run = bats:Begin(panelOn(), { x = 1000, y = 900 })
      run:Break()
      step(0.05)
      for _, p in ipairs(run.pieces) do
        local x, y = middle(corners(p.art))
        local d0 = math.sqrt((p.cx - 1000) ^ 2 + (p.cy - 900) ^ 2)
        local d1 = math.sqrt((x - 1000) ^ 2 + (y - 900) ^ 2)
        assert.is_true(near(d1 - d0, 5, 1e-6), "half its Gap: " .. (d1 - d0))
      end
    end)

    it("turns its pieces into bats in their own time, nearer where it breaks first", function()
      local run = bats:Begin(panelOn(), { x = 1000, y = 900 })
      local near_, far = run.pieces[1], run.pieces[1]
      for _, p in ipairs(run.pieces) do
        assert.is_true(p.delay >= 0 and p.delay <= 0.2)
        local d = (p.cx - 1000) ^ 2 + (p.cy - 900) ^ 2
        if d < (near_.cx - 1000) ^ 2 + (near_.cy - 900) ^ 2 then near_ = p end
        if d > (far.cx - 1000) ^ 2 + (far.cy - 900) ^ 2 then far = p end
      end
      assert.is_true(near_.delay < far.delay)
    end)

    it("shrinks a piece into wings, flapping and darkening as a bat comes out of it", function()
      local run = bats:Begin(panelOn())
      run:Break()
      local p = run.pieces[1]
      local before = area(p.corners)
      step(0.1 + p.delay)
      assert.is_false(p.bat:IsShown(), "no bat yet")
      step(0.15)
      -- Half way through its morph.
      local cs = corners(p.art)
      assert.is_true(area(cs) < before * 0.9, "shrinking")
      assert.is_true(width(cs, true) > width(cs, false) * 1.5, "its top spread into wings, its bottom drawn in")
      local r = p.art:GetVertexColor()
      assert.is_true(r < 0.9, "darkening: " .. r)
      assert.is_true(p.bat:IsShown())
      local a = p.bat:GetAlpha()
      assert.is_true(a > 0 and a < 1, "the bat coming out of it: " .. a)
      step(0.16)
      assert.is_false(p.art:IsShown(), "the piece gone into its bat")
      assert.are.equal(1, p.bat:GetAlpha())
      assert.is_true(p.bat:GetWidth() >= 40 - 1e-6, "the bat at its size")
    end)

    it("spreads a piece's top into wings and draws its bottom in, as much as it has shrunk", function()
      local spec = copy(BATS)
      spec.Close.Delay = { 0, 0 }
      spec.Close.Tilt = 0
      theme(spec)
      local run = bats:Begin(panelOn())
      run:Break()
      local p = run.pieces[1]
      local top, bottom = p.local_[2][1] - p.local_[1][1], p.local_[3][1] - p.local_[4][1]
      step(0.1)
      step(0.15)
      -- Half way through its morph (0.15 of 0.3): m is a half, shrunk by k toward its bat's size.
      local k = 1 + (p.size / p.reach - 1) * 0.5
      local cs = corners(p.art)
      assert.is_true(near(width(cs, true), top * k * (1 + 0.6 * 0.5)), "its top spread")
      assert.is_true(near(width(cs, false), bottom * k * (1 - 0.7 * 0.5)), "its bottom drawn in")
      step(0.12)
      -- Nine tenths through, it has nearly gone into its bat.
      local a = p.art:GetAlpha()
      assert.is_true(a > 0 and a < 0.5, "fading into its bat: " .. a)
    end)

    it("flaps a piece's wings as it turns", function()
      -- Where its top's middle is above its own middle a third of the way through its morph, flapping or not (no delay,
      -- no banking: nothing else tells the two apart).
      local function topAbove(rate)
        local spec = copy(BATS)
        spec.FrameRate = rate
        spec.Close.Delay = { 0, 0 }
        spec.Close.Tilt = 0
        theme(spec)
        local run = bats:Begin(panelOn())
        run:Break()
        step(0.1)
        step(0.1)
        local cs = corners(run.pieces[1].art)
        local _, top = middle({ cs[1], cs[2], cs[1], cs[2] })
        local _, mid = middle(cs)
        run:Release()
        return top - mid
      end
      assert.is_false(near(topAbove(10), topAbove(0), 0.5), "its wings up or down from where they would be")
    end)

    it("flaps its bats' wings through the art's frames", function()
      local run = bats:Begin(panelOn())
      run:Break()
      step(0.7)
      local b = run.pieces[1].bat
      local seen = {}
      for _ = 1, 8 do
        -- The eight corners' coordinates: its upper left's across first, its upper right's fifth.
        local l, _, _, _, r = b:GetTexCoord()
        assert.is_true(near(r - l, 0.25), "a frame a quarter of the art across")
        seen[math.floor(l * 4 + 0.5)] = true
        step(0.1)
      end
      for f = 0, 3 do
        assert.is_true(seen[f], "frame " .. f)
      end
    end)

    it("flies its bats away from where it broke, faster and faster, wobbling as they go", function()
      local run = bats:Begin(panelOn())
      run:Break()
      step(0.7)
      local start, mid = {}, {}
      for i, p in ipairs(run.pieces) do
        start[i] = { at(p.bat) }
      end
      step(0.2)
      for i, p in ipairs(run.pieces) do
        mid[i] = { at(p.bat) }
      end
      step(0.2)
      for i, p in ipairs(run.pieces) do
        local x, y = at(p.bat)
        local d0 = math.sqrt((start[i][1] - 1200) ^ 2 + (start[i][2] - 600) ^ 2)
        local d2 = math.sqrt((x - 1200) ^ 2 + (y - 600) ^ 2)
        assert.is_true(d2 > d0, "away from the middle")
        local along1 = (mid[i][1] - start[i][1]) * p.dx + (mid[i][2] - start[i][2]) * p.dy
        local along2 = (x - mid[i][1]) * p.dx + (y - mid[i][2]) * p.dy
        assert.is_true(along2 > along1, "faster and faster")
        -- From where it drifted to as it broke: Gap straight out from where it broke.
        local ox, oy = p.cx + p.sx * 10, p.cy + p.sy * 10
        local across = (x - ox) * -p.dy + (y - oy) * p.dx
        assert.is_true(math.abs(across) <= 10 + 1e-6, "wobbling no more than its Wobble across")
      end
    end)

    it("sends its bats straight out from where it broke, give or take its Spread", function()
      local function offs(spread)
        local spec = copy(BATS)
        spec.Close.Spread = spread
        theme(spec)
        local run = bats:Begin(panelOn(), { x = 1000, y = 900 })
        local most = 0
        for _, p in ipairs(run.pieces) do
          local cos = math.max(-1, math.min(1, p.dx * p.sx + p.dy * p.sy))
          most = math.max(most, math.deg(math.acos(cos)))
        end
        run:Release()
        return most
      end
      assert.is_true(offs(0) < 1e-6, "straight out without Spread")
      local most = offs(40)
      assert.is_true(most > 5 and most <= 40 + 1e-6, "within its Spread: " .. most)
    end)

    it("eases its bats into their speed as they turn, and grows them as they fly on", function()
      local spec = copy(BATS)
      spec.Close.Delay = { 0, 0 }
      spec.Close.Tilt = 0
      spec.Close.Accel = 0
      spec.Close.Wobble = { 0, 0 }
      theme(spec)
      local run = bats:Begin(panelOn(), { x = 1000, y = 900 })
      run:Break()
      step(0.1)
      step(0.15)
      -- Half way through its morph: half its speed's way (eased in, 0.5 of 200 * 0.15), at 0.85 of its size.
      for _, p in ipairs(run.pieces) do
        local x, y = at(p.bat)
        local ox, oy = p.cx + p.sx * 10, p.cy + p.sy * 10
        assert.is_true(near((x - ox) * p.dx + (y - oy) * p.dy, 15), "eased in")
        assert.is_true(near(p.bat:GetWidth(), 40 * (0.7 + 0.3 * 0.5)), "coming out of it")
      end
      step(1.15)
      -- A second past its morph, 15 % bigger, as it nears the viewer.
      for _, p in ipairs(run.pieces) do
        if not p.gone then
          assert.is_true(near(p.bat:GetWidth(), 40 * 1.15), "growing as it flies")
        end
      end
    end)

    it("banks its bats toward where they fly", function()
      local run = bats:Begin(panelOn())
      run:Break()
      step(0.7)
      local checked = 0
      for _, p in ipairs(run.pieces) do
        if p.dx > 0.3 then
          assert.is_true(p.bat:GetRotation() < 0, "right: leaning right")
          checked = checked + 1
        elseif p.dx < -0.3 then
          assert.is_true(p.bat:GetRotation() > 0, "left: leaning left")
          checked = checked + 1
        end
      end
      assert.is_true(checked > 4)
    end)

    it("draws its bats at the panel's scale", function()
      local run = bats:Begin(panelOn(0.5))
      run:Break()
      step(0.7)
      local b = run.pieces[1].bat
      assert.is_true(b:GetWidth() >= 20 - 1e-6 and b:GetWidth() < 26)
    end)

    it("draws on a layer over the screen above the panels, taking no mouse", function()
      local layer = bats:Layer()
      assert.are.equal("DIALOG", layer:GetFrameStrata())
      assert.is_false(layer:IsMouseEnabled())
    end)

    it("is given back once its bats are off the screen, the driver stopping with the last", function()
      local run = bats:Begin(panelOn())
      run:Break()
      local list = run.pieces
      for _ = 1, 80 do
        if bats:Layer().driver:GetScript("OnUpdate") == nil then break end
        step(0.05)
      end
      assert.is_nil(bats:Layer().driver:GetScript("OnUpdate"))
      for _, p in ipairs(list) do
        assert.is_false(p.bat:IsShown())
        assert.is_false(p.art:IsShown())
      end
      assert.is_nil(next(bats.flying))
    end)

    it("is given back as soon as its last bat is off the screen, long before its Life", function()
      local s = copy(BATS)
      s.Close.Speed = { 3000, 3000 }
      s.Close.Life = 30
      theme(s)
      local run = bats:Begin(panelOn())
      run:Break()
      for _ = 1, 5 do
        if bats:Layer().driver:GetScript("OnUpdate") == nil then break end
        step(0.3)
      end
      assert.is_true(run.elapsed < 1.6, "long before its Life (30)")
      assert.is_nil(next(bats.flying))
      assert.is_nil(bats:Layer().driver:GetScript("OnUpdate"))
    end)

    it("hides a bat as it leaves the screen, while the others fly on", function()
      local s = copy(BATS)
      s.Close.Speed = { 200, 1600 }
      theme(s)
      local run = bats:Begin(panelOn())
      run:Break()
      for _ = 1, 22 do
        step(0.05)
      end
      local gone, flying = 0, 0
      for _, p in ipairs(run.pieces) do
        local x, y = at(p.bat)
        local off = x < -p.size or x > 1920 + p.size or y < -p.size or y > 1200 + p.size
        if off then
          assert.is_false(p.bat:IsShown())
          gone = gone + 1
        elseif p.bat:IsShown() then
          flying = flying + 1
        end
      end
      assert.is_true(gone > 0 and flying > 0)
    end)

    it("lives no longer than its Life", function()
      local s = copy(BATS)
      s.Close.Speed = { 0, 0 }
      s.Close.Accel = 0
      theme(s)
      local run = bats:Begin(panelOn())
      run:Break()
      step(2.9)
      assert.is_not_nil(next(bats.flying))
      step(0.2)
      assert.is_nil(next(bats.flying))
    end)

    it("gives everything back as it is released, before or after it breaks, and when it starts again", function()
      local run = bats:Begin(panelOn())
      local arts = {}
      for _, p in ipairs(run.pieces) do arts[p.art] = true end
      run:Release()
      for t in pairs(arts) do assert.is_false(t:IsShown()) end
      run = bats:Begin(panelOn())
      run:Break()
      step(0.2)
      local list = run.pieces
      bats:Init()
      for _, p in ipairs(list) do
        assert.is_false(p.art:IsShown())
        assert.is_false(p.bat:IsShown())
      end
      assert.is_nil(bats:Layer().driver:GetScript("OnUpdate"))
    end)
  end)

  describe("fluttering", function()
    -- What a flutter reads of a panel: its frame (600 tall), where its body starts in it and how wide it is, the side of
    -- the screen it belongs to.
    local function panelOn(side)
      local frame = CreateFrame("Frame", nil, UIParent)
      frame:SetSize(496, 600)
      local panel = { frame = frame, side = side }
      function panel:IsSmall() return false end
      function panel:BodyLeft() return self.side == "LEFT" and 0 or 96 end
      function panel:BodyWidth() return 400 end
      panel.bats = bats:Create(panel)
      return panel
    end

    local function started(spec, side)
      theme(spec or copy(BATS))
      local panel = panelOn(side or "RIGHT")
      panel.bats:Style()
      panel.bats:Start()
      return panel
    end

    local function step(panel, dt)
      local d = panel.bats.driver
      d:GetScript("OnUpdate")(d, dt)
    end

    -- Where a bat's middle is, from the panel's top left, y down.
    local function at(t)
      local point, rel, relPoint, x, y = t:GetPoint(1)
      assert.are.same({ "CENTER", "TOPLEFT" }, { point, relPoint })
      return x, -y, rel
    end

    local function shown(panel)
      local out = {}
      for _, b in ipairs(panel.bats.flutters) do
        if b.texture:IsShown() then table.insert(out, b) end
      end
      return out
    end

    it("draws nothing and runs nothing for a theme without a flutter", function()
      local s = copy(BATS)
      s.Flutter = nil
      local panel = started(s)
      assert.is_nil(panel.bats.driver:GetScript("OnUpdate"))
    end)

    it("flutters a few bats out of its header now and then, one after another", function()
      local panel = started()
      step(panel, 4.9)
      assert.are.equal(0, #shown(panel))
      step(panel, 0.15)
      assert.are.equal(1, #shown(panel))
      step(panel, 0.3)
      assert.are.equal(2, #shown(panel))
      for _, b in ipairs(shown(panel)) do
        local _, _, rel = at(b.texture)
        assert.are.equal(panel.frame, rel)
        assert.are.equal(panel.frame, b.texture:GetParent())
        assert.is_true(b.x >= 96 and b.x <= 496, "out of the body")
        assert.is_true(b.y >= 30 and b.y <= 60, "in its header")
      end
    end)

    it("flies toward the inner side, out into the world, flapping, fading as it ends its way", function()
      local panel = started()
      step(panel, 5.05)
      local b = shown(panel)[1]
      local x0 = at(b.texture)
      local l0 = b.texture:GetTexCoord()
      step(panel, 0.5)
      local x1 = at(b.texture)
      assert.is_true(x1 < x0, "toward the inner side")
      assert.is_true(near(x0 - x1, 50, 6), "about 100 a second")
      local l1 = b.texture:GetTexCoord()
      assert.are_not.equal(l0, l1, "flapping")
      assert.is_true(near(0.9, b.texture:GetAlpha(), 1e-6), "at its strength on its way")
      step(panel, 2.3)
      assert.is_true(b.texture:GetAlpha() < 0.9 * 0.5, "fading as it ends")
      step(panel, 0.3)
      assert.is_false(b.texture:IsShown(), "gone once it has flown its Travel (300 at 100 a second)")
    end)

    it("flies to the right on a panel on the left of the screen", function()
      local panel = started(nil, "LEFT")
      step(panel, 5.05)
      local b = shown(panel)[1]
      local x0 = at(b.texture)
      step(panel, 0.5)
      assert.is_true((at(b.texture)) > x0)
    end)

    it("sends none in combat, and none once stopped", function()
      local panel = started()
      combat = true
      step(panel, 6)
      assert.are.equal(0, #shown(panel))
      combat = false
      step(panel, 5.05)
      assert.are.equal(1, #shown(panel))
      panel.bats:Stop()
      assert.are.equal(0, #shown(panel))
      assert.is_nil(panel.bats.driver:GetScript("OnUpdate"))
    end)

    it("flutters out as the panel shows with OnOpen", function()
      local s = copy(BATS)
      s.Flutter.OnOpen = true
      local panel = started(s)
      step(panel, 0.01)
      assert.are.equal(1, #shown(panel))
    end)

    it("names its bats moving parts", function()
      local panel = started()
      step(panel, 5.05)
      local skip = {}
      panel.bats:MovingParts(skip)
      assert.is_true(skip[shown(panel)[1].texture])
    end)
  end)
end)
