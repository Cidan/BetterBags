local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

-- NextSmoke brings a Next panel in out of smoke (Panel.Smoke, next-themes.md §23; the Halloween theme; asked: "the bags
-- should appear in a puff of smoke from bottom to top (get that smoke right! make it feel really good)", then, of a first
-- cartoon version: "can you make it more real-ish?"). A front rises up the body over Open.Rise, quick off the floor and
-- slowing near the top; rows of soft, wispy puffs (Puffs: translucent, each at an alpha and an angle of its own) are
-- born from it as it passes them, the bottom row bursting sideways along the floor. Each swells as it goes (from Start of
-- its size to Growth of it, quickly at first), rises faster and faster (Lift, Buoyancy: warm smoke), drifts out from the
-- body's middle (Spread) and swirls across that drift (Swirl), turns slowly (Spin), fades in quickly (FadeIn) and thins
-- slowly away over its Life; so the smoke clears from the bottom up, the first born first. The panel shows under it over
-- Open.Reveal and has shown once that ends; the smoke then lingers on its layer until it has cleared (Linger). Embers
-- (Sparks) rise through it. A run (Begin) is one panel's smoke on the smoke layer, a frame over the screen above every
-- panel; the panel drives it (next/panel.lua). A theme without Panel.Smoke has none.
---@class NextSmoke: AceModule
local smoke = addon:NewModule('NextSmoke')

-- Where the smoke takes its randomness (a source of numbers in [0, 1)): replaced by the specs.
smoke.Random = math.random

-- The keys of Panel.Smoke, of its Puffs, its Sparks and its Open, for SonataNext:Check.
smoke.KEYS = { Puffs = true, Sparks = true, Open = true }
smoke.PUFF_KEYS = { Texture = true, Colors = true, Size = true, Alpha = true, BlendMode = true, Spin = true }
smoke.SPARK_KEYS = { Texture = true, Colors = true, Count = true, Size = true, Life = true, Rise = true, Spin = true,
  Alpha = true, BlendMode = true }
smoke.OPEN_KEYS = { Rise = true, Spacing = true, Jitter = true, Life = true, Start = true, Growth = true, FadeIn = true,
  Lift = true, Buoyancy = true, Spread = true, Burst = true, Swirl = true, Reveal = true }

---@class (exact) NextSmokePuff
---@field texture Texture
---@field x number Where it is born, on the layer (UIParent's units, y up).
---@field y number
---@field born number When, seconds into its run.
---@field life number How long it lives.
---@field size number
---@field vx number Units a second across: out from the middle.
---@field vy number Up, as it is born (Buoyancy adds to it).
---@field buoyancy number Units a second its rise gains each second.
---@field angle number Its turn as it is born, radians.
---@field spin number Radians a second.
---@field swirl number Where its swirl starts, radians.
---@field alpha number

---@class (exact) NextSmokeSpark
---@field texture Texture
---@field x number
---@field y number
---@field born number
---@field life number
---@field size number
---@field rise number Units a second up.
---@field spin number
---@field alpha number

---@class (exact) NextSmokeRun
---@field look table Its puffs' look (Panel.Smoke.Puffs).
---@field timing table Its puffs' timing (Panel.Smoke.Open).
---@field puffs NextSmokePuff[]
---@field sparks NextSmokeSpark[]
---@field reveal? number[] When the panel shows under it.
---@field clear number When its last puff or ember is gone.
---@field elapsed number How long it has lived, while it lingers.
local runProto = {}
addon:GetModule('Perf'):RegisterPrototype(runProto, 'NextSmokeRun')

function smoke:Init()
  for run in pairs(self.living or {}) do
    run:Release()
  end
  self.living = {}
  self.pool = self.pool or {}
  self.sparkPool = self.sparkPool or {}
  if self.layer ~= nil then
    self.layer.driver:SetScript("OnUpdate", nil)
  end
end

-- Spec returns the theme's Panel.Smoke, nil without one.
---@return table?
function smoke:Spec()
  return style.Theme.Panel.Smoke or nil
end

-- Opens says whether the theme's panels come in out of smoke instead of sliding in.
---@return boolean
function smoke:Opens()
  local S = self:Spec()
  return S ~= nil and S.Open ~= nil
end

-- OpenLock is when the panel has shown fully under the smoke (its threads draw in and its sections cascade from then);
-- OpenTime is the panel's part of the open, until then (it says it has shown); ClearTime is when the smoke has cleared:
-- the last row is born as the front reaches the top and lives at most its Life, an ember its own.
---@return number
function smoke:OpenLock()
  local O = self:Spec().Open
  return O.Reveal and O.Reveal[2] or O.Rise
end

---@return number
function smoke:OpenTime()
  return self:OpenLock()
end

---@return number
function smoke:ClearTime()
  local S = self:Spec()
  local O = S.Open
  local life = O.Life and O.Life[2] or 0
  if S.Sparks and S.Sparks.Life then
    life = math.max(life, S.Sparks.Life[2])
  end
  return O.Rise + life
end

-- Layer returns the smoke layer, made the first time: a frame over the whole screen, in the DIALOG strata (above the
-- panels, HIGH), taking no mouse, with the driver that lets smoke linger.
---@return Frame
function smoke:Layer()
  if self.layer == nil then
    local layer = CreateFrame("Frame", nil, UIParent)
    layer:SetAllPoints(UIParent)
    layer:SetFrameStrata("DIALOG")
    layer:SetFrameLevel(10)
    layer:EnableMouse(false)
    layer.driver = CreateFrame("Frame", nil, layer)
    self.layer = layer
  end
  return self.layer
end

---@param range number[]
---@return number
local function between(range)
  return range[1] + (range[2] - range[1]) * smoke.Random()
end

---@param x number
---@return number
local function clamp01(x)
  return math.max(0, math.min(1, x))
end

---@param e0 number
---@param e1 number
---@param x number
---@return number
local function smoothstep(e0, e1, x)
  local t = clamp01((x - e0) / (e1 - e0))
  return t * t * (3 - 2 * t)
end

---@param list string[]?
---@return string
local function pick(list)
  local colors = list or { "White" }
  return colors[math.min(#colors, math.floor(smoke.Random() * #colors) + 1)]
end

-- texture takes a texture from a pool, or makes one on the layer: drawn without the client's sharpening
-- (texture-sharpening.md).
---@param pool Texture[]
---@param layer string
---@param sublevel number
---@return Texture
local function texture(pool, layer, sublevel)
  local t = table.remove(pool)
  if t == nil then
    t = smoke:Layer():CreateTexture(nil, layer, nil, sublevel)
    t:SetSnapToPixelGrid(false)
    t:SetTexelSnappingBias(0)
  end
  t:SetDrawLayer(layer, sublevel)
  t:ClearAllPoints()
  t:SetRotation(0)
  t:Hide()
  return t
end

-- grid lays puffs over a rect (left and top on the layer, y up; its width and height) in rows and columns about Spacing
-- apart, a column half a spacing outside each side, each moved up to Jitter of a spacing either way, each born as the
-- front reaches its row (born, by its height up the rect, 0 to 1). The bottom row drifts sideways Burst times as fast.
---@param run NextSmokeRun
---@param rect {left: number, top: number, width: number, height: number}
---@param scale number
---@param born fun(f: number): number
local function grid(run, rect, scale, born)
  local L, O = run.look, run.timing
  local spacing = O.Spacing * scale
  local cols = math.max(1, math.ceil(rect.width / spacing - 1e-9))
  local rows = math.max(1, math.ceil(rect.height / spacing - 1e-9))
  local sw, sh = rect.width / cols, rect.height / rows
  local bottom = rect.top - rect.height
  local middle = rect.left + rect.width / 2
  local jitter = O.Jitter or 0
  for k = 0, rows do
    local f = k / rows
    for i = 0, cols + 1 do
      local x = rect.left + (i - 0.5) * sw + (2 * smoke.Random() - 1) * jitter * sw
      local y = bottom + k * sh + (2 * smoke.Random() - 1) * jitter * sh
      local t = texture(smoke.pool, "ARTWORK", math.min(7, k - 8))
      style:Paint(t, { Texture = L.Texture, Color = pick(L.Colors), BlendMode = L.BlendMode or "BLEND" })
      local share = math.abs(x - middle) / (rect.width / 2)
      local side = x < middle and -1 or 1
      local burst = k == 0 and (O.Burst or 1) or 1
      local p = { texture = t, x = x, y = y, born = born(f), life = between(O.Life or { 0.6, 0.6 }),
        size = between(L.Size) * scale, vx = side * between(O.Spread or { 0, 0 }) * scale * share * burst,
        vy = between(O.Lift or { 0, 0 }) * scale, buoyancy = (O.Buoyancy or 0) * scale,
        angle = 2 * math.pi * smoke.Random(), spin = math.rad((2 * smoke.Random() - 1) * (L.Spin or 0)),
        swirl = 2 * math.pi * smoke.Random(),
        alpha = type(L.Alpha) == "table" and between(L.Alpha) or (L.Alpha or 1) }
      table.insert(run.puffs, p)
      run.clear = math.max(run.clear, p.born + p.life)
    end
  end
end

-- draw puts a puff where it is t seconds into its run, hidden until it is born and once it has lived its life: swollen
-- from Start of its size toward Growth of it (an ease out: quickly at first), risen and drifted, swirled across its
-- drift (Swirl: units either way, swings a second, growing in over the first two fifths of its life), turned, faded in
-- over FadeIn of its life and thinned away from three tenths of it on.
---@param p NextSmokePuff
---@param O table
---@param t number
local function draw(p, O, t)
  local tex = p.texture
  local age = t - p.born
  if age < 0 or age >= p.life then
    tex:Hide()
    return
  end
  local q = age / p.life
  local start, growth = O.Start or 1, O.Growth or 1
  local size = p.size * (start + (growth - start) * (1 - (1 - q) * (1 - q)))
  local fadeIn = O.FadeIn or 0
  local swirl = O.Swirl or { 0, 0 }
  local across = swirl[1] * math.sin(p.swirl + 2 * math.pi * (swirl[2] or 0) * age) * smoothstep(0, 0.4, q)
  tex:SetPoint("CENTER", smoke:Layer(), "BOTTOMLEFT", p.x + p.vx * age + across,
    p.y + p.vy * age + 0.5 * p.buoyancy * age * age)
  tex:SetSize(size, size)
  tex:SetRotation(p.angle + p.spin * age)
  tex:SetAlpha(p.alpha * (fadeIn > 0 and smoothstep(0, fadeIn, q) or 1) * (1 - smoothstep(0.3, 1, q)))
  tex:Show()
end

-- Begin readies a panel's smoke on the smoke layer, unseen until its open draws it: puffs over its body where its
-- BodyRect puts it on the screen (at its scale), each born as the front reaches its row, and the embers, each born
-- somewhere in the smoke below the front.
---@param panel table
---@return NextSmokeRun
function smoke:Begin(panel)
  local S = self:Spec()
  local O = S.Open
  local left, top, height, width, scale = panel:BodyRect()
  scale = scale or 1
  local rect = { left = left, top = top, width = width, height = height }
  ---@type NextSmokeRun
  local run = setmetatable({ look = S.Puffs, timing = O, puffs = {}, sparks = {}, reveal = O.Reveal, clear = 0,
    elapsed = 0 }, { __index = runProto })
  -- The front: 1 - (1 - u)^2 of the way up u of the way through its rise; a row f of the way up is reached then.
  grid(run, rect, scale, function(f)
    return O.Rise * (1 - math.sqrt(1 - math.min(1, f)))
  end)
  local P = S.Sparks
  for _ = 1, P and P.Count or 0 do
    local born = O.Rise * self.Random()
    local front = 1 - (1 - born / O.Rise) ^ 2
    local t = texture(self.sparkPool, "OVERLAY", 7)
    style:Paint(t, { Texture = P.Texture, Color = pick(P.Colors), BlendMode = P.BlendMode or "ADD" })
    local s = { texture = t, x = left + width * self.Random(), y = top - height + height * front * self.Random(),
      born = born, life = between(P.Life or { 0.5, 0.5 }), size = between(P.Size or { 6, 6 }) * scale,
      rise = between(P.Rise or { 0, 0 }) * scale, spin = math.rad((2 * self.Random() - 1) * (P.Spin or 0)),
      alpha = P.Alpha or 1 }
    table.insert(run.sparks, s)
    run.clear = math.max(run.clear, s.born + s.life)
  end
  return run
end

-- Open draws a panel's smoke t seconds into its open, and returns the panel's alpha: shown under the smoke over Reveal
-- (from nothing at its first to full at its second).
---@param t number
---@return number alpha The panel's.
function runProto:Open(t)
  for _, p in ipairs(self.puffs) do
    draw(p, self.timing, t)
  end
  for _, s in ipairs(self.sparks) do
    local age = t - s.born
    local tex = s.texture
    if age < 0 or age > s.life then
      tex:Hide()
    else
      local size = math.max(0.001, s.size * math.sin(math.pi * age / s.life))
      tex:SetPoint("CENTER", smoke:Layer(), "BOTTOMLEFT", s.x, s.y + s.rise * age)
      tex:SetSize(size, size)
      tex:SetRotation(s.spin * age)
      tex:SetAlpha(s.alpha)
      tex:Show()
    end
  end
  local R = self.reveal
  if R == nil then
    return 1
  end
  return smoothstep(R[1], R[2], t)
end

-- Linger lets the run live on by itself on the smoke layer's driver from t seconds into it (the panel has shown), until
-- its last puff and ember are gone.
---@param t number
function runProto:Linger(t)
  self.elapsed = t
  smoke.living[self] = true
  local driver = smoke:Layer().driver
  if driver:GetScript("OnUpdate") == nil then
    driver:SetScript("OnUpdate", function(_, elapsed)
      smoke:Step(elapsed)
    end)
  end
end

-- Step lives every lingering run on elapsed seconds, giving back those that have cleared, and stops the driver when none
-- is left.
---@param elapsed number
function smoke:Step(elapsed)
  for run in pairs(self.living) do
    run.elapsed = run.elapsed + elapsed
    if run.elapsed >= run.clear then
      run:Release()
    else
      run:Open(run.elapsed)
    end
  end
  if next(self.living) == nil then
    self:Layer().driver:SetScript("OnUpdate", nil)
  end
end

-- Release gives the run's textures back, hidden, at once; a run released again does nothing.
function runProto:Release()
  smoke.living[self] = nil
  for _, p in ipairs(self.puffs) do
    p.texture:Hide()
    table.insert(smoke.pool, p.texture)
  end
  for _, s in ipairs(self.sparks) do
    s.texture:Hide()
    table.insert(smoke.sparkPool, s.texture)
  end
  self.puffs = {}
  self.sparks = {}
end
