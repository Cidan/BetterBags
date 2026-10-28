local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

-- NextSmoke brings a Next panel in out of a puff of smoke (Panel.Smoke, next-themes.md §23; the Halloween theme;
-- asked: "the bags should appear in a puff of smoke from bottom to top (get that smoke right! make it feel really
-- good)"). A front rises up the body over Open.Rise, quick off the floor and slowing as it nears the top; rows of
-- cartoon puffs (flat, cel-shaded balls of smoke: Puffs) pop out of it as it passes them, a little past their size and
-- back, the bottom row bursting sideways along the floor, every puff billowing up and out from the body's middle and
-- turning as it goes; each holds, then shrinks away, so the smoke clears from the bottom up, the first born first, and
-- the panel, shown under it while it covers the body (Open.Reveal), comes out of it from the bottom to the top. Star
-- sparks (Sparks) twinkle in the smoke as it rises. A run (Begin) is one panel's smoke on the smoke layer, a frame
-- over the screen above every panel; the panel drives it (next/panel.lua). A burst (Burst) covers a rect with puffs at
-- once and lives out on the layer by itself (the bats' close, NextBats). A theme without Panel.Smoke has none.
---@class NextSmoke: AceModule
local smoke = addon:NewModule('NextSmoke')

-- Where the smoke takes its randomness (a source of numbers in [0, 1)): replaced by the specs.
smoke.Random = math.random

-- The keys of Panel.Smoke, of its Puffs (a puff's look, a burst's too), its Sparks, its Open, and a burst's timing,
-- for SonataNext:Check.
smoke.KEYS = { Puffs = true, Sparks = true, Open = true }
smoke.PUFF_KEYS = { Texture = true, Colors = true, Size = true, Alpha = true, BlendMode = true, Spin = true }
smoke.SPARK_KEYS = { Texture = true, Colors = true, Count = true, Size = true, Life = true, Spin = true, Alpha = true,
  BlendMode = true }
smoke.OPEN_KEYS = { Rise = true, Spacing = true, Grow = true, Hold = true, Shrink = true, Lift = true, Spread = true,
  Burst = true, Reveal = true, Jitter = true }
smoke.BURST_KEYS = { Spacing = true, Grow = true, Hold = true, Shrink = true, Lift = true, Spread = true, Jitter = true }

-- How far past its size a puff pops (an ease out with that overshoot, outBack's c1): about a tenth.
local POP = 1.70158

---@class (exact) NextSmokePuff
---@field texture Texture
---@field x number Where it is born, on the layer (UIParent's units, y up).
---@field y number
---@field born number When, seconds into its run.
---@field size number
---@field vx number Units a second across: out from the middle.
---@field vy number Up.
---@field spin number Radians a second.
---@field alpha number

---@class (exact) NextSmokeSpark
---@field texture Texture
---@field x number
---@field y number
---@field born number
---@field life number
---@field size number
---@field spin number
---@field alpha number

---@class (exact) NextSmokeRun
---@field look table Its puffs' look (Panel.Smoke.Puffs, or a burst's own).
---@field timing table Its puffs' timing (Panel.Smoke.Open, or a burst's).
---@field puffs NextSmokePuff[]
---@field sparks NextSmokeSpark[]
---@field reveal? number[] When the panel shows under it (an open's Reveal).
---@field elapsed number How long a burst has lived out.
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

-- Opens says whether the theme's panels come in out of a puff of smoke instead of sliding in.
---@return boolean
function smoke:Opens()
  local S = self:Spec()
  return S ~= nil and S.Open ~= nil
end

-- OpenLock is when the panel has shown fully under the smoke (its threads draw in and its sections cascade from then);
-- OpenTime is the whole open: the last row is born as the front reaches the top, then pops, holds and shrinks away.
---@return number
function smoke:OpenLock()
  local O = self:Spec().Open
  return O.Reveal and O.Reveal[2] or O.Rise
end

---@return number
function smoke:OpenTime()
  local O = self:Spec().Open
  return O.Rise + (O.Grow or 0) + (O.Hold or 0) + (O.Shrink or 0)
end

-- Layer returns the smoke layer, made the first time: a frame over the whole screen, in the DIALOG strata (above the
-- panels, HIGH), taking no mouse, with the driver that lives bursts out.
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

-- grid lays puffs over a rect (left and top on the layer, y up; its width and height) in rows and columns about
-- spacing apart, a column half a spacing outside each side, each moved up to jitter of a spacing either way; born says
-- when a row's puffs come out (by its height up the rect, 0 to 1). The bottom row bursts sideways (burst times as fast).
---@param run NextSmokeRun
---@param rect {left: number, top: number, width: number, height: number}
---@param scale number
---@param born fun(f: number): number
local function grid(run, rect, scale, born)
  local L, T = run.look, run.timing
  local spacing = T.Spacing * scale
  local cols = math.max(1, math.ceil(rect.width / spacing - 1e-9))
  local rows = math.max(1, math.ceil(rect.height / spacing - 1e-9))
  local sw, sh = rect.width / cols, rect.height / rows
  local bottom = rect.top - rect.height
  local middle = rect.left + rect.width / 2
  local jitter = T.Jitter or 0
  for k = 0, rows do
    local f = k / rows
    for i = 0, cols + 1 do
      local x = rect.left + (i - 0.5) * sw + (2 * smoke.Random() - 1) * jitter * sw
      local y = bottom + k * sh + (2 * smoke.Random() - 1) * jitter * sh
      local t = texture(smoke.pool, "ARTWORK", math.min(7, k - 8))
      style:Paint(t, { Texture = L.Texture, Color = pick(L.Colors), BlendMode = L.BlendMode or "BLEND" })
      local share = math.abs(x - middle) / (rect.width / 2)
      local side = x < middle and -1 or 1
      local burst = k == 0 and (T.Burst or 1) or 1
      local spread = between(T.Spread or { 0, 0 }) * scale
      table.insert(run.puffs, { texture = t, x = x, y = y, born = born(f), size = between(L.Size) * scale,
        vx = side * spread * share * burst, vy = between(T.Lift or { 0, 0 }) * scale,
        spin = math.rad((2 * smoke.Random() - 1) * (L.Spin or 0)), alpha = L.Alpha or 1 })
    end
  end
end

-- popAt is how big a puff is, as a share of its size, age seconds after it came out: popping a little past it over
-- Grow (an ease out with an overshoot), held over Hold, shrinking to nothing over Shrink (an ease in); and its share of
-- its alpha (fading over the second half of its shrinking). Nil once it is gone.
---@param T table
---@param age number
---@return number? scale, number alpha
local function popAt(T, age)
  local grow, hold, shrink = T.Grow or 0, T.Hold or 0, T.Shrink or 0
  if age < grow then
    local q = age / grow - 1
    return 1 + (POP + 1) * q * q * q + POP * q * q, 1
  end
  if age < grow + hold then
    return 1, 1
  end
  if age < grow + hold + shrink then
    local r = (age - grow - hold) / shrink
    return 1 - r * r, 1 - smoothstep(0.5, 1, r)
  end
  return nil, 0
end

-- draw puts a puff where it is t seconds into its run: hidden until it is born and once it has gone.
---@param p NextSmokePuff
---@param T table
---@param t number
local function draw(p, T, t)
  local tex = p.texture
  local age = t - p.born
  local scale, fade
  if age >= 0 then
    scale, fade = popAt(T, age)
  end
  if scale == nil then
    tex:Hide()
    return
  end
  local size = p.size * math.max(0.001, scale)
  tex:SetPoint("CENTER", smoke:Layer(), "BOTTOMLEFT", p.x + p.vx * age, p.y + p.vy * age)
  tex:SetSize(size, size)
  tex:SetRotation(p.spin * age)
  tex:SetAlpha(p.alpha * fade)
  tex:Show()
end

-- Begin readies a panel's smoke on the smoke layer, unseen until its open draws it: puffs over its body where its
-- BodyRect puts it on the screen (at its scale), each born as the front reaches its row, and the sparks.
---@param panel table
---@return NextSmokeRun
function smoke:Begin(panel)
  local S = self:Spec()
  local O = S.Open
  local left, top, height, width, scale = panel:BodyRect()
  local rect = { left = left, top = top, width = width, height = height }
  ---@type NextSmokeRun
  local run = setmetatable({ look = S.Puffs, timing = O, puffs = {}, sparks = {}, reveal = O.Reveal, elapsed = 0 },
    { __index = runProto })
  -- The front: 1 - (1 - u)^2 of the way up u of the way through its rise; a row f of the way up is reached then.
  grid(run, rect, scale or 1, function(f)
    return O.Rise * (1 - math.sqrt(1 - math.min(1, f)))
  end)
  local P = S.Sparks
  for _ = 1, P and P.Count or 0 do
    local born = O.Rise * self.Random()
    local front = 1 - (1 - born / O.Rise) ^ 2
    local t = texture(self.sparkPool, "OVERLAY", 7)
    style:Paint(t, { Texture = P.Texture, Color = pick(P.Colors), BlendMode = P.BlendMode or "ADD" })
    table.insert(run.sparks, { texture = t, x = left + width * self.Random(),
      y = top - height + height * front * self.Random(), born = born, life = between(P.Life or { 0.3, 0.3 }),
      size = between(P.Size or { 12, 12 }) * (scale or 1), spin = math.rad((2 * self.Random() - 1) * (P.Spin or 0)),
      alpha = P.Alpha or 1 })
  end
  return run
end

-- Open draws a panel's smoke t seconds into its open, and returns the panel's alpha: shown under the smoke over
-- Reveal (from nothing at its first to full at its second).
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
      local size = s.size * math.sin(math.pi * age / s.life)
      tex:SetPoint("CENTER", smoke:Layer(), "BOTTOMLEFT", s.x, s.y)
      tex:SetSize(math.max(0.001, size), math.max(0.001, size))
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

-- Burst covers a rect (left and top on the layer, y up; its width and height) with puffs at once, in a look and a
-- timing of its own (spec: Puffs' keys and a burst's: Spacing, Grow, Hold, Shrink, Lift, Spread, Jitter), at a scale,
-- and lives it out on the layer's driver: gone once its puffs have.
---@param rect {left: number, top: number, width: number, height: number}
---@param scale number
---@param spec table
---@return NextSmokeRun
function smoke:Burst(rect, scale, spec)
  ---@type NextSmokeRun
  local run = setmetatable({ look = spec, timing = spec, puffs = {}, sparks = {}, elapsed = 0 }, { __index = runProto })
  grid(run, rect, scale or 1, function() return 0 end)
  run:Open(0)
  self.living[run] = true
  local driver = self:Layer().driver
  if driver:GetScript("OnUpdate") == nil then
    driver:SetScript("OnUpdate", function(_, elapsed)
      smoke:Step(elapsed)
    end)
  end
  return run
end

-- Step lives every burst on elapsed seconds, giving back those whose puffs have all gone, and stops the driver when
-- none is left.
---@param elapsed number
function smoke:Step(elapsed)
  for run in pairs(self.living) do
    run.elapsed = run.elapsed + elapsed
    local T = run.timing
    if run.elapsed > (T.Grow or 0) + (T.Hold or 0) + (T.Shrink or 0) then
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
