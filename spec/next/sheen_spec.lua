-- sheen_spec.lua -- NextSheen (next/sheen.lua): a Next theme's panel catching the light as it opens and closes
-- (Panel.Sheen, next-themes-glass.md §26; the Rainy Window theme; asked, of a fog and a wash first tried: "kind of lame
-- -- something more... elegant?"). Opening, a soft band of light sweeps across the body from its inner side out, tilted
-- down, as the panel and its glass fade in under it; closing, it sweeps back the other way as they fade out. The band's
-- art is laid over the body by its coordinates, clamped to nothing past it, so the body's edges cut it. A run lingers on
-- its own layer after the panel's part, until the band has crossed.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

for _, m in ipairs({ { "NextPixel", "next/pixel.lua" }, { "NextStyle", "next/style.lua" }, { "NextSheen", "next/sheen.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end
local sheen = addon:GetModule("NextSheen")

local function copy(t)
  local out = {}
  for k, v in pairs(t) do
    out[k] = type(v) == "table" and copy(v) or v
  end
  return out
end

local SHEEN = {
  Band = { Texture = "Sheen", Color = "White", Alpha = 0.5, BlendMode = "ADD", Width = 200, Angle = 30 },
  Glow = { Color = "White", Alpha = 0.08, BlendMode = "ADD" },
  Open = { Time = 0.5, Reveal = 0.3 },
  Close = { Time = 0.4, Fade = 0.25 },
}

local function near(a, b, eps)
  return math.abs(a - b) <= (eps or 1e-6)
end

local function smoothstep(e0, e1, x)
  local t = math.max(0, math.min(1, (x - e0) / (e1 - e0)))
  return t * t * (3 - 2 * t)
end

describe("NextSheen", function()
  local function theme(spec)
    UseNextTheme({ Textures = { Sheen = "sheen.png" }, Panel = { Sheen = spec } })
  end

  -- panelOn makes what the sheen reads of a panel: its side and its body's rect on the screen (left 1000, top 900,
  -- 400 x 600, so from 300 up to 900).
  local function panelOn(side)
    local panel = { frame = CreateFrame("Frame", nil, UIParent), side = side or "RIGHT" }
    function panel:BodyRect() return 1000, 900, 600, 400, 1 end
    return panel
  end

  local function lingering()
    local n = 0
    for _ in pairs(sheen.living) do n = n + 1 end
    return n
  end

  -- Where the band's middle is along its way, at each corner of the body (UL, LL, UR, LR): its art's u there, where
  -- 0.5 is its middle and a band's width is 1.
  local function corners(run)
    local ulu, _, llu, _, uru, _, lru = run.band:GetTexCoord()
    return { ulu, llu, uru, lru }
  end

  before_each(function()
    sheen:Init()
    theme(copy(SHEEN))
  end)

  after_each(function()
    sheen:Init()
    UseNextTheme(nil)
  end)

  it("opens and closes in a sheen only with each; the panel's parts, and when the band has crossed", function()
    assert.is_true(sheen:Opens())
    assert.is_true(sheen:Closes())
    assert.are.equal(0.3, sheen:OpenLock())
    assert.are.equal(0.3, sheen:OpenTime(), "the panel shown once revealed")
    assert.are.equal(0.25, sheen:CloseTime(), "gone once faded")
    assert.are.equal(0.5, sheen:Begin(panelOn(), "Open").clear)
    assert.are.equal(0.4, sheen:Begin(panelOn(), "Close").clear)
    local s = copy(SHEEN)
    s.Open = nil
    theme(s)
    assert.is_false(sheen:Opens())
    assert.is_true(sheen:Closes())
    UseNextTheme({})
    assert.is_false(sheen:Opens())
    assert.is_false(sheen:Closes())
    assert.is_nil(sheen:Spec())
  end)

  it("draws its band over the body on a layer above the panels, taking no mouse, clamped to nothing past its art", function()
    local layer = sheen:Layer()
    assert.are.equal("DIALOG", layer:GetFrameStrata())
    assert.is_false(layer:IsMouseEnabled())
    local run = sheen:Begin(panelOn(), "Open")
    local t = run.band
    assert.are.equal(layer, t:GetParent())
    assert.are.equal("sheen.png", t:GetTexture())
    assert.are.same({ "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE" }, { t._wrapH, t._wrapV })
    assert.are.equal("ADD", t:GetBlendMode())
    local point, rel, relPoint, x, y = t:GetPoint(1)
    assert.are.same({ "TOPLEFT", layer, "BOTTOMLEFT", 1000, 900 }, { point, rel, relPoint, x, y })
    assert.are.same({ 400, 600 }, { t:GetWidth(), t:GetHeight() })
    assert.is_false(t:IsShown(), "unseen until it draws")
  end)

  it("sweeps its band across the body from its inner side out, tilted down, as the panel fades in", function()
    local run = sheen:Begin(panelOn("RIGHT"), "Open")
    -- Its way: 30 degrees down from the inner side (the left) toward the outer.
    local a = math.rad(30)
    local dx, dy = math.cos(a), -math.sin(a)
    local function along(x, y) return (x - 1200) * dx + (y - 600) * dy end
    local ds = { along(1000, 900), along(1000, 300), along(1400, 900), along(1400, 300) }
    local low, high = math.min(unpack(ds)), math.max(unpack(ds))
    local function expected(t)
      local e = smoothstep(0, 0.5, t)
      local s = low - 100 + e * (high - low + 200)
      local out = {}
      for i, d in ipairs(ds) do out[i] = (d - s) / 200 + 0.5 end
      return out
    end
    for _, t in ipairs({ 0, 0.1, 0.25, 0.4 }) do
      local alpha = run:Draw(t)
      assert.is_true(near(smoothstep(0, 0.3, t), alpha), "the panel fading in under it")
      local got, want = corners(run), expected(t)
      for i = 1, 4 do
        assert.is_true(near(want[i], got[i], 1e-9), t .. ": corner " .. i)
      end
    end
    -- Starting before the nearest corner (every corner ahead of it, past its art) and ending past the farthest.
    run:Draw(0)
    for _, u in ipairs(corners(run)) do assert.is_true(u >= 1) end
    run:Draw(0.4999)
    for _, u in ipairs(corners(run)) do assert.is_true(u <= 0.01) end
    run:Draw(0.5)
    assert.is_false(run.band:IsShown(), "gone once it has crossed")
    run:Draw(0.25)
    assert.is_true(run.band:IsShown())
    assert.is_true(near(0.5, run.band:GetAlpha()))
    assert.is_true(near(0.08 * math.sin(math.pi * 0.5), run.glow:GetAlpha()), "the pane lit most as it crosses")
  end)

  it("sweeps a panel on the left of the screen from its right, and sweeps back the other way as it closes", function()
    local function first(side, phase)
      local run = sheen:Begin(panelOn(side), phase)
      run:Draw(0.05)
      local u = corners(run)
      -- Which side the band is still nearest: the corners on that side are nearest its middle, the rest far ahead.
      return u[1] < u[3] and "left" or "right"
    end
    assert.are.equal("left", first("RIGHT", "Open"))
    assert.are.equal("right", first("LEFT", "Open"))
    assert.are.equal("right", first("RIGHT", "Close"))
    assert.are.equal("left", first("LEFT", "Close"))
  end)

  -- Found in review: a bag turned back part way (closed as it opened, opened again as it closed) jumped to full, or to
  -- nothing, and faded from there. A run can start where its panel's alpha already is.
  it("says how far into an open or a close a panel at an alpha is", function()
    local open, close = sheen:Begin(panelOn(), "Open"), sheen:Begin(panelOn(), "Close")
    assert.are.equal(0, sheen:OpenAt(0))
    assert.is_true(near(0.3, sheen:OpenAt(1)))
    assert.are.equal(0, sheen:CloseAt(1))
    assert.is_true(near(0.25, sheen:CloseAt(0)))
    for _, a in ipairs({ 0.1, 0.37, 0.5, 0.82 }) do
      assert.is_true(near(a, open:Draw(sheen:OpenAt(a)), 1e-9), "open at " .. a)
      assert.is_true(near(a, close:Draw(sheen:CloseAt(a)), 1e-9), "close at " .. a)
    end
  end)

  -- Found in review: a bag closed while its open's band still crossed showed two bands at once, going opposite ways.
  it("gives back a panel's lingering band when it begins another, and leaves other panels' alone", function()
    local panel, other = panelOn(), panelOn("LEFT")
    local open = sheen:Begin(panel, "Open")
    open:Draw(0.3)
    open:Linger(0.3)
    local others = sheen:Begin(other, "Open")
    others:Draw(0.3)
    others:Linger(0.3)
    local close = sheen:Begin(panel, "Close")
    assert.are.equal(1, lingering(), "the other panel's still crossing")
    assert.is_true(sheen.living[others])
    assert.is_nil(open.band, "the open's band given back")
    close:Release()
    others:Release()
  end)

  -- A close from a bag barely shown draws its band and glow that faintly (panel.lua's sheenOut).
  it("draws its band and glow as strongly as it is begun with", function()
    local run = sheen:Begin(panelOn(), "Close", 0.4)
    run:Draw(0.2)
    assert.is_true(near(0.5 * 0.4, run.band:GetAlpha()))
    assert.is_true(near(0.08 * 0.4 * math.sin(math.pi * 0.5), run.glow:GetAlpha()))
    run:Release()
  end)

  it("fades the panel out as it closes", function()
    local run = sheen:Begin(panelOn(), "Close")
    assert.are.equal(1, run:Draw(0))
    assert.is_true(near(1 - smoothstep(0, 0.25, 0.1), run:Draw(0.1)))
    assert.are.equal(0, run:Draw(0.25))
  end)

  it("lingers until its band has crossed, then gives it back; released again, nothing", function()
    local run = sheen:Begin(panelOn(), "Open")
    run:Draw(0.3)
    run:Linger(0.3)
    assert.are.equal(1, lingering())
    local d = sheen:Layer().driver
    d:GetScript("OnUpdate")(d, 0.1)
    assert.is_true(run.band:IsShown())
    local band = run.band
    d:GetScript("OnUpdate")(d, 0.15)
    assert.are.equal(0, lingering())
    assert.is_false(band:IsShown())
    assert.is_nil(d:GetScript("OnUpdate"))
    run:Release()
  end)
end)
