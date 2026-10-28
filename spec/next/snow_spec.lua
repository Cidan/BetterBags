-- snow_spec.lua -- NextSnow (next/snow.lua): a Next theme's snow (Panel.Snow, next-themes.md §22; the Frost theme):
-- flakes drifting down across the body behind its content and down the feather, carried toward the panel's inner side
-- (out into the world) by a breeze that gusts now and then, a gust's streaks of wind sweeping across; drawn on the
-- panel's own frame (under its tabs and content), only while the panel shows.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextSnow", "next/snow.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end
local snow = addon:GetModule("NextSnow")
local style = addon:GetModule("NextStyle")

describe("NextSnow", function()
  local savedRandom, savedCombat, combat

  -- panelOn makes what the snow reads of a panel: its frame (600 tall), where its body starts in it and how wide it is,
  -- the side of the screen it belongs to and its size.
  local function panelOn(side, small)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(496, 600)
    local panel = { frame = frame, side = side, small = small == true }
    function panel:IsSmall() return self.small end
    function panel:BodyLeft() return self.side == "LEFT" and 0 or 96 end
    function panel:BodyWidth() return 400 end
    panel.snow = snow:Create(panel)
    return panel
  end

  local BODY = { Where = "Body", Texture = "Flake", Count = 10, Size = { 4, 8 }, Fall = { 20, 20 }, Drift = 10,
    Wobble = { 0, 1 }, Spin = 90, Alpha = { 0.3, 0.6 }, Colors = { "Gold", "White" }, BlendMode = "ADD",
    Layer = "BORDER", SubLevel = 3 }
  local GUSTS = { Every = 10, Time = 2, Strength = 100,
    Streaks = { Texture = "Streak", Count = 3, Length = { 100, 200 }, Thickness = { 2, 4 }, Alpha = 0.3,
      Color = "White", BlendMode = "ADD", Tilt = 10 } }

  local function with(base, changes)
    local spec = {}
    for k, v in pairs(base) do spec[k] = v end
    for k, v in pairs(changes or {}) do spec[k] = v end
    return spec
  end

  local function theme(flakes, gusts)
    UseNextTheme({
      Textures = { Flake = "flake.png", Streak = "streak.png" },
      Panel = { Snow = { Flakes = flakes, Gusts = gusts } },
    })
  end

  local function started(flakes, gusts, side, small)
    theme(flakes, gusts)
    local panel = panelOn(side or "RIGHT", small)
    panel.snow:Style()
    panel.snow:Start()
    return panel
  end

  local function step(panel, dt)
    local d = panel.snow.driver
    d:GetScript("OnUpdate")(d, dt)
  end

  -- Where a flake's middle is, from the panel's top left, y down.
  local function at(t)
    local point, rel, relPoint, x, y = t:GetPoint(1)
    assert.are.same({ "CENTER", "TOPLEFT" }, { point, relPoint })
    return x, -y, rel
  end

  before_each(function()
    savedRandom = snow.Random
    local seed = 3
    snow.Random = function()
      seed = (seed * 16807) % 2147483647
      return seed / 2147483647
    end
    savedCombat = _G.InCombatLockdown
    combat = false
    _G.InCombatLockdown = function() return combat end
  end)

  after_each(function()
    snow.Random = savedRandom
    _G.InCombatLockdown = savedCombat
    UseNextTheme(nil)
  end)

  it("draws nothing for a theme without snow", function()
    UseNextTheme({})
    local panel = panelOn("RIGHT")
    panel.snow:Style()
    panel.snow:Start()
    assert.are.equal(0, #panel.snow.flakes)
    assert.is_nil(panel.snow.driver:GetScript("OnUpdate"))
  end)

  it("draws each entry's flakes on the panel's own frame, as the theme says", function()
    local panel = started({ BODY })
    local flakes = panel.snow.flakes
    assert.are.equal(10, #flakes)
    local sizes = {}
    for _, f in ipairs(flakes) do
      local t = f.texture
      assert.are.equal(panel.frame, t:GetParent())
      assert.are.same({ "BORDER", 3 }, { t:GetDrawLayer() })
      assert.are.equal("flake.png", t:GetTexture())
      assert.are.equal("ADD", t:GetBlendMode())
      assert.is_true(t:IsShown())
      local w = t:GetWidth()
      assert.are.equal(w, t:GetHeight())
      assert.is_true(w >= 4 and w <= 8)
      sizes[w] = true
      local a = t:GetAlpha()
      assert.is_true(a >= 0.3 - 1e-9 and a <= 0.6 + 1e-9)
      local r, g, b = t:GetVertexColor()
      local gold = { style:RGBA("Gold") }
      local white = { style:RGBA("White") }
      assert.is_true((r == gold[1] and g == gold[2] and b == gold[3]) or (r == white[1] and g == white[2] and b == white[3]))
    end
    local n = 0
    for _ in pairs(sizes) do n = n + 1 end
    assert.is_true(n > 1, "flakes of several sizes")
  end)

  it("scatters body flakes across the body, and feather flakes down the feather on the body's inner side", function()
    local feather = with(BODY, { Where = "Feather" })
    local right = started({ BODY, feather }, nil, "RIGHT")
    for _, f in ipairs(right.snow.flakes) do
      local x, y = at(f.texture)
      if f.entry.Where == "Body" then
        assert.is_true(x >= 96 and x <= 496, "body: " .. x)
      else
        assert.is_true(x >= 96 - style.FEATHER and x <= 96, "feather: " .. x)
      end
      assert.is_true(y >= 0 and y <= 600)
    end
    local left = started({ feather }, nil, "LEFT")
    for _, f in ipairs(left.snow.flakes) do
      local x = at(f.texture)
      assert.is_true(x >= 400 and x <= 400 + style.FEATHER, "the bank's feather is on its right: " .. x)
    end
  end)

  -- A size switch lays the snow out again (the panel's geometry), not anew: a full panel's feather flakes have nowhere
  -- to fall on a small one, and fall again once it is full.
  it("hides its feather flakes while the panel is small, and lets them fall again once it is full", function()
    local panel = started({ with(BODY, { Where = "Feather", Count = 3 }) }, nil, "RIGHT")
    panel.small = true
    panel.snow:Layout()
    for _, f in ipairs(panel.snow.flakes) do
      assert.is_false(f.texture:IsShown())
    end
    step(panel, 0.1)
    for _, f in ipairs(panel.snow.flakes) do
      assert.is_false(f.texture:IsShown())
    end
    panel.small = false
    panel.snow:Layout()
    step(panel, 0.1)
    for _, f in ipairs(panel.snow.flakes) do
      assert.is_true(f.texture:IsShown())
      local x = at(f.texture)
      assert.is_true(x >= 96 - style.FEATHER - 8 and x <= 96 + 8)
    end
  end)

  it("draws no feather flakes on a small panel, which has none", function()
    local panel = started({ with(BODY, { Where = "Feather" }) }, nil, "RIGHT", true)
    assert.are.equal(0, #panel.snow.flakes)
  end)

  it("lets the flakes fall and drift toward the panel's inner side, turning", function()
    local right = started({ BODY }, nil, "RIGHT")
    local f = right.snow.flakes[1]
    local x0, y0 = at(f.texture)
    local r0 = f.texture:GetRotation()
    step(right, 0.5)
    local x1, y1 = at(f.texture)
    assert.is_true(math.abs((y1 - y0) - 10) < 1e-6, "20 a second down")
    assert.is_true(x1 < x0, "out of a backpack's left side")
    assert.are_not.equal(r0, f.texture:GetRotation())
    local left = started({ BODY }, nil, "LEFT")
    local g = left.snow.flakes[1]
    local lx0 = at(g.texture)
    step(left, 0.5)
    assert.is_true((at(g.texture)) > lx0, "out of the bank's right side")
  end)

  it("starts a flake again at the top once it has fallen past the bottom, and upwind once it has blown past", function()
    local panel = started({ with(BODY, { Fall = { 100, 100 }, Drift = 0, Count = 1 }) })
    local f = panel.snow.flakes[1]
    f.y = 598
    step(panel, 0.1)
    local _, y = at(f.texture)
    assert.is_true(y < 0, "above the top: " .. y)
    local side = started({ with(BODY, { Fall = { 0, 0 }, Drift = 200, Count = 1 }) })
    local g = side.snow.flakes[1]
    g.x = 100
    step(side, 0.1)
    local x = at(g.texture)
    assert.is_true(x > 496 - 20, "back on the upwind (right) side: " .. x)
  end)

  it("starts none again in combat, and starts them again once it ends", function()
    local panel = started({ with(BODY, { Fall = { 100, 100 }, Drift = 0, Count = 1 }) })
    local f = panel.snow.flakes[1]
    combat = true
    f.y = 598
    step(panel, 0.1)
    assert.is_false(f.texture:IsShown())
    step(panel, 0.1)
    assert.is_false(f.texture:IsShown())
    combat = false
    step(panel, 0.1)
    assert.is_true(f.texture:IsShown())
    local _, y = at(f.texture)
    assert.is_true(y < 20, "from the top: " .. y)
  end)

  describe("the breeze's gusts", function()
    local function streaks(panel)
      local out = {}
      for _, s in ipairs(panel.snow.streaks) do
        if s.texture:IsShown() then table.insert(out, s) end
      end
      return out
    end

    it("blows now and then, the flakes carried faster while it does, its streaks sweeping across", function()
      local panel = started({ with(BODY, { Fall = { 0, 0 }, Wobble = { 0, 1 } }) }, GUSTS)
      local f = panel.snow.flakes[1]
      assert.are.equal(0, #streaks(panel))
      local x0 = at(f.texture)
      step(panel, 0.1)
      local calm = x0 - at(f.texture)
      -- Every 10 seconds on average (4 to 16): by 16 one has blown.
      local blown = false
      for _ = 1, 160 do
        step(panel, 0.1)
        if panel.snow.gust ~= nil then blown = true break end
      end
      assert.is_true(blown)
      assert.are.equal(3, #streaks(panel))
      step(panel, 0.9)
      local x1 = at(f.texture)
      step(panel, 0.1)
      local gusting = x1 - at(f.texture)
      assert.is_true(gusting > calm * 3, "carried faster in the gust: " .. gusting .. " against " .. calm)
      step(panel, 1.1)
      assert.is_nil(panel.snow.gust)
      assert.are.equal(0, #streaks(panel))
    end)

    it("sweeps its streaks downwind, tilted down along the wind, their head first", function()
      local right = started({ BODY }, GUSTS, "RIGHT")
      right.snow:Gust()
      local s = streaks(right)[1]
      local x0 = at(s.texture)
      step(right, 0.2)
      local x1 = at(s.texture)
      assert.is_true(x1 < x0, "toward the backpack's inner side")
      assert.is_true(s.texture:GetRotation() < 0 or s.texture:GetRotation() > 0)
      -- Its head is the art's right end: mirrored to lead going left.
      assert.are.same({ 1, 0, 0, 1 }, s.texture._texCoords)
      local w = s.texture:GetWidth()
      assert.is_true(w >= 100 and w <= 200)
      assert.are.equal("streak.png", s.texture:GetTexture())
      local left = started({ BODY }, GUSTS, "LEFT")
      left.snow:Gust()
      local ls = streaks(left)[1]
      assert.are.same({ 0, 1, 0, 1 }, ls.texture._texCoords)
      local lx0 = at(ls.texture)
      step(left, 0.2)
      assert.is_true((at(ls.texture)) > lx0)
    end)

    it("blows as the panel shows when the theme says so", function()
      local panel = started({ BODY }, with(GUSTS, { OnOpen = true }))
      assert.is_not_nil(panel.snow.gust)
    end)
  end)

  it("falls only while the panel shows, its streaks gone when it stops", function()
    local panel = started({ BODY }, GUSTS)
    panel.snow:Gust()
    assert.is_not_nil(panel.snow.driver:GetScript("OnUpdate"))
    panel.snow:Stop()
    assert.is_nil(panel.snow.driver:GetScript("OnUpdate"))
    for _, s in ipairs(panel.snow.streaks) do
      assert.is_false(s.texture:IsShown())
    end
    assert.is_nil(panel.snow.gust)
  end)

  it("takes a new theme's snow, falling on, and none from a theme without", function()
    local panel = started({ BODY })
    local first = panel.snow.flakes[1].texture
    theme({ with(BODY, { Count = 4, Texture = "Streak" }) })
    panel.snow:Style()
    assert.are.equal(4, #panel.snow.flakes)
    assert.are.equal("streak.png", panel.snow.flakes[1].texture:GetTexture())
    assert.is_not_nil(panel.snow.driver:GetScript("OnUpdate"))
    UseNextTheme({})
    panel.snow:Style()
    assert.are.equal(0, #panel.snow.flakes)
    assert.is_false(first:IsShown())
    assert.is_nil(panel.snow.driver:GetScript("OnUpdate"))
  end)

  it("keeps its flakes inside the panel when it changes size, leaving those still inside where they are", function()
    local panel = started({ BODY })
    local before = {}
    for i, f in ipairs(panel.snow.flakes) do
      local x, y = at(f.texture)
      before[i] = { x, y }
    end
    panel.frame:SetSize(496, 300)
    panel.snow:Layout()
    local kept = 0
    for i, f in ipairs(panel.snow.flakes) do
      local x, y = at(f.texture)
      assert.is_true(y <= 300, "inside the shorter panel: " .. y)
      if before[i][2] <= 300 then
        assert.are.same(before[i], { x, y })
        kept = kept + 1
      end
    end
    assert.is_true(kept > 0)
  end)

  it("names every flake and streak a moving part", function()
    local panel = started({ BODY }, GUSTS)
    panel.snow:Gust()
    local skip = {}
    panel.snow:MovingParts(skip)
    for _, f in ipairs(panel.snow.flakes) do
      assert.is_true(skip[f.texture])
    end
    for _, s in ipairs(panel.snow.streaks) do
      assert.is_true(skip[s.texture])
    end
  end)
end)
