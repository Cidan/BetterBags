-- bats_spec.lua -- NextBats (next/bats.lua): a Next theme's panel turning into bats as it closes, and bats fluttering out
-- of its header now and then while it shows (Panel.Bats, next-themes.md §23; the Halloween theme; asked: "for the bag
-- closing, make the bag 'turn into' several bats, like 10-15 bats, and fly away in random directions off screen. like
-- old school cartoon vampires turning into bats and flying away"). Closing: a puff of smoke covers the body (NextSmoke's
-- Burst) and the panel vanishes under it, then the bats burst out of it, each flapping (a flipbook across the art),
-- growing in, flying away from the body's middle faster and faster, wobbling and banking, until it is off the screen.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextSmoke", "next/smoke.lua" },
  { "NextBats", "next/bats.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end
local bats = addon:GetModule("NextBats")
local smoke = addon:GetModule("NextSmoke")

local PUFF = { Texture = "Puff", Colors = { "White" }, Size = { 60, 60 }, Alpha = 1, Spacing = 50, Grow = 0.08,
  Hold = 0.1, Shrink = 0.2, Lift = { 10, 10 }, Spread = { 20, 20 }, Jitter = 0 }
local BATS = {
  Texture = "Bats", Frames = 4, FrameRate = 10, Color = "White", BlendMode = "BLEND",
  Close = { Count = { 12, 12 }, Size = { 40, 40 }, Speed = { 200, 200 }, Accel = 1, Wobble = { 10, 2 }, Grow = 0.2,
    Delay = { 0, 0.1 }, Tilt = 20, Life = 3, Vanish = 0.12, Puff = PUFF },
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
    Textures = { Bats = "bats.png", Puff = "puff.png" },
    Panel = { Bats = spec },
  })
end

local function near(a, b, eps)
  return math.abs(a - b) <= (eps or 1e-6)
end

describe("NextBats", function()
  local savedRandom, savedSmokeRandom, savedCombat, combat

  before_each(function()
    savedRandom, savedSmokeRandom = bats.Random, smoke.Random
    local seed = 11
    bats.Random = function()
      seed = (seed * 16807) % 2147483647
      return seed / 2147483647
    end
    smoke.Random = bats.Random
    savedCombat = _G.InCombatLockdown
    combat = false
    _G.InCombatLockdown = function() return combat end
    smoke:Init()
    bats:Init()
    theme(copy(BATS))
  end)

  after_each(function()
    bats.Random, smoke.Random = savedRandom, savedSmokeRandom
    _G.InCombatLockdown = savedCombat
    bats:Init()
    smoke:Init()
    UseNextTheme(nil)
  end)

  describe("closing", function()
    -- What the close reads of a panel: its body's rect on the screen (left 1000, top 900, 400 x 600: from 300 up to 900;
    -- its middle at 1200, 600), at a scale.
    local function panelOn(scale)
      local panel = { frame = CreateFrame("Frame", nil, UIParent), side = "RIGHT" }
      function panel:BodyRect() return 1000, 900, 600 * (scale or 1), 400 * (scale or 1), scale or 1 end
      return panel
    end

    local function step(dt)
      local d = bats:Layer().driver
      d:GetScript("OnUpdate")(d, dt)
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

    it("covers the body in a puff of smoke once, and the panel vanishes under it", function()
      local run = bats:Begin(panelOn())
      assert.are.equal(1, run:Vanish(0))
      run:Vanish(0.03)
      local puffs = 0
      for burst in pairs(smoke.living) do
        for _, p in ipairs(burst.puffs) do
          puffs = puffs + 1
          assert.is_true(p.x >= 1000 - 50 and p.x <= 1400 + 50)
          assert.is_true(p.y >= 300 - 1e-6 and p.y <= 900 + 1e-6)
        end
      end
      -- One burst over the body: 400 / 50 = 8 columns apart and one outside each side, 600 / 50 = 12 rows apart.
      assert.are.equal(10 * 13, puffs)
      local a = run:Vanish(0.06)
      assert.is_true(a > 0 and a < 1)
      assert.are.equal(0, run:Vanish(0.12))
      assert.are.equal(0, run:Vanish(0.2), "gone for good past its Vanish")
    end)

    it("turns it into bats that burst out of it, on a layer above the smoke", function()
      local run = bats:Begin(panelOn())
      run:Vanish(0.12)
      run:Fly()
      assert.are.equal(12, #run.bats)
      local layer = bats:Layer()
      assert.are.equal("DIALOG", layer:GetFrameStrata())
      assert.is_true(layer:GetFrameLevel() > smoke:Layer():GetFrameLevel())
      assert.is_false(layer:IsMouseEnabled())
      for _, b in ipairs(run.bats) do
        assert.are.equal(layer, b.texture:GetParent())
        assert.are.equal("bats.png", b.texture:GetTexture())
        assert.is_true(b.x >= 1000 and b.x <= 1400 and b.y >= 300 and b.y <= 900, "out of the body")
        assert.is_true(b.delay >= 0 and b.delay <= 0.1)
      end
      step(0.01)
      local waiting = 0
      for _, b in ipairs(run.bats) do
        assert.are.equal(b.delay <= 0.01, b.texture:IsShown(), "each out once its delay is up")
        if b.delay > 0.01 then waiting = waiting + 1 end
      end
      assert.is_true(waiting > 0, "some still waiting their turn")
    end)

    it("flaps its wings through the art's frames", function()
      local run = bats:Begin(panelOn())
      run:Fly()
      step(0.15)
      local b = run.bats[1]
      local seen = {}
      for _ = 1, 8 do
        -- The eight corners' coordinates: its upper left's across first, its upper right's fifth.
        local l, _, _, _, r = b.texture:GetTexCoord()
        assert.is_true(near(r - l, 0.25), "a frame a quarter of the art across")
        seen[math.floor(l * 4 + 0.5)] = true
        step(0.1)
      end
      for f = 0, 3 do
        assert.is_true(seen[f], "frame " .. f)
      end
    end)

    it("flies away from the body's middle, faster and faster, wobbling as it goes", function()
      local run = bats:Begin(panelOn())
      run:Fly()
      step(0.2)
      local start = {}
      for i, b in ipairs(run.bats) do
        local x, y = at(b.texture)
        start[i] = { x, y }
      end
      step(0.2)
      local mid = {}
      for i, b in ipairs(run.bats) do
        local x, y = at(b.texture)
        mid[i] = { x, y }
      end
      step(0.2)
      for i, b in ipairs(run.bats) do
        local x, y = at(b.texture)
        local d0 = math.sqrt((start[i][1] - 1200) ^ 2 + (start[i][2] - 600) ^ 2)
        local d2 = math.sqrt((x - 1200) ^ 2 + (y - 600) ^ 2)
        assert.is_true(d2 > d0, "away from the middle")
        -- Along its way (its wobble left out), it goes further in the later stretch.
        local along1 = (mid[i][1] - start[i][1]) * b.dx + (mid[i][2] - start[i][2]) * b.dy
        local along2 = (x - mid[i][1]) * b.dx + (y - mid[i][2]) * b.dy
        assert.is_true(along2 > along1, "faster and faster")
        local across = (x - b.x) * -b.dy + (y - b.y) * b.dx
        assert.is_true(math.abs(across) <= 10 + 1e-6, "wobbling no more than its Wobble across")
      end
    end)

    it("grows in as it comes out, at the panel's scale", function()
      local run = bats:Begin(panelOn(0.5))
      run:Fly()
      local b = run.bats[1]
      step(b.delay + 0.05)
      assert.is_true(b.texture:GetWidth() < 20, "small at first")
      step(0.3)
      assert.is_true(b.texture:GetWidth() >= 20 - 1e-6, "its size (40 at half scale) once out")
      assert.are.equal(b.texture:GetWidth(), b.texture:GetHeight())
    end)

    it("banks toward where it flies", function()
      local run = bats:Begin(panelOn())
      run:Fly()
      step(0.3)
      local checked = 0
      for _, b in ipairs(run.bats) do
        if b.dx > 0.3 then
          assert.is_true(b.texture:GetRotation() < 0, "right: leaning right")
          checked = checked + 1
        elseif b.dx < -0.3 then
          assert.is_true(b.texture:GetRotation() > 0, "left: leaning left")
          checked = checked + 1
        end
      end
      assert.is_true(checked > 4)
    end)

    it("is given back once it is off the screen, the driver stopping with the last", function()
      local run = bats:Begin(panelOn())
      run:Fly()
      local list = run.bats
      for _ = 1, 80 do
        if bats:Layer().driver:GetScript("OnUpdate") == nil then break end
        step(0.05)
      end
      assert.is_nil(bats:Layer().driver:GetScript("OnUpdate"))
      for _, b in ipairs(list) do
        assert.is_false(b.texture:IsShown())
      end
      assert.is_nil(next(bats.flying))
    end)

    it("is given back as soon as its last bat is off the screen, long before its Life", function()
      local s = copy(BATS)
      s.Close.Speed = { 3000, 3000 }
      s.Close.Life = 30
      theme(s)
      local run = bats:Begin(panelOn())
      run:Fly()
      step(0.3)
      step(0.3)
      assert.is_nil(next(bats.flying))
      assert.is_nil(bats:Layer().driver:GetScript("OnUpdate"))
    end)

    it("hides a bat as it leaves the screen, while the others fly on", function()
      local s = copy(BATS)
      s.Close.Speed = { 200, 1600 }
      theme(s)
      local run = bats:Begin(panelOn())
      run:Fly()
      local gone, flying = 0, 0
      for _ = 1, 8 do
        step(0.05)
      end
      for _, b in ipairs(run.bats) do
        local x, y = at(b.texture)
        local off = x < -b.size or x > 1920 + b.size or y < -b.size or y > 1200 + b.size
        if off then
          assert.is_false(b.texture:IsShown())
          gone = gone + 1
        elseif b.texture:IsShown() then
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
      run:Fly()
      step(2.9)
      assert.is_not_nil(next(bats.flying))
      step(0.2)
      assert.is_nil(next(bats.flying))
    end)

    it("gives back the bats flying when it starts again", function()
      local run = bats:Begin(panelOn())
      run:Fly()
      step(0.2)
      local list = run.bats
      bats:Init()
      for _, b in ipairs(list) do
        assert.is_false(b.texture:IsShown())
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
