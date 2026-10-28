local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextSmoke: AceModule
local smoke = addon:GetModule('NextSmoke')

-- NextBats turns a closing Next panel into bats and sends a few fluttering out of its header now and then while it
-- shows (Panel.Bats, next-themes.md §23; the Halloween theme; asked: "for the bag closing, make the bag 'turn into'
-- several bats, like 10-15 bats, and fly away in random directions off screen. like old school cartoon vampires turning
-- into bats and flying away type of effect"). A bat is a flipbook: the art holds Frames pictures of it flapping side by
-- side, shown in turn FrameRate a second, each bat from its own. Closing (Close): a puff of smoke covers the body
-- (NextSmoke's Burst, Close.Puff) and the panel vanishes under it over Vanish, then Count bats burst out of it from
-- across the body, each after its own Delay, growing in, flying away from the body's middle (give or take) faster and
-- faster, wobbling across its way and banking toward where it goes, until it is off the screen (Life at most), on the
-- bats layer, a frame over the screen above the smoke's, which carries them on after the panel has hidden. Fluttering
-- (Flutter): every Every, Count bats one after another fly out of the header band of the body toward its inner side,
-- out into the world, over Travel, fading as they end it; drawn on the panel's frame, under its content, only while it
-- shows. A theme without Panel.Bats has none.
---@class NextBats: AceModule
local bats = addon:NewModule('NextBats')

-- Where the bats take their randomness (a source of numbers in [0, 1)): replaced by the specs.
bats.Random = math.random

-- The keys of Panel.Bats, of its Close and of its Flutter, for SonataNext:Check.
bats.KEYS = { Texture = true, Frames = true, FrameRate = true, Color = true, BlendMode = true, Close = true,
  Flutter = true }
bats.CLOSE_KEYS = { Count = true, Size = true, Speed = true, Accel = true, Wobble = true, Grow = true, Delay = true,
  Tilt = true, Life = true, Vanish = true, Spread = true, Puff = true }
bats.FLUTTER_KEYS = { Every = true, Count = true, Size = true, Speed = true, Wobble = true, Stagger = true,
  Travel = true, Band = true, Rise = true, Alpha = true, OnOpen = true, Layer = true, SubLevel = true }

-- How far past its size a bat pops as it comes out (an ease out with that overshoot, outBack's c1), and how big it is
-- as it starts.
local POP = 1.70158
local FIRST = 0.3

---@class (exact) NextBat
---@field texture Texture
---@field x number Where it starts: on the layer (UIParent's units, y up) as it closes; from the panel's top left, y
---down, as it flutters.
---@field y number
---@field dx number The way it flies, a unit vector (y up on the layer, y down on the panel).
---@field dy number
---@field speed number Units a second as it sets off.
---@field size number
---@field delay? number Seconds before it comes out, as it closes (a flutter's starts at a negative age instead).
---@field phase number Where its flapping starts, in frames.
---@field wobble number Where its wobble starts, in radians.
---@field rise? number A flutter's units a second up (y down: negative is up).
---@field age? number A flutter's seconds out.
---@field gone? boolean Off the screen, or done.

---@class (exact) NextBatRun
---@field spec table The theme's Panel.Bats it began with.
---@field rect {left: number, top: number, width: number, height: number}
---@field scale number
---@field bats NextBat[]
---@field puffed boolean Its puff has started.
---@field elapsed number How long its bats have flown.
local runProto = {}
addon:GetModule('Perf'):RegisterPrototype(runProto, 'NextBatRun')

---@class (exact) NextBatSet
---@field panel table The panel: its frame, its side, BodyLeft, BodyWidth.
---@field driver Frame Runs its flutters while the panel shows; a child of the panel's frame.
---@field onUpdate fun(frame: Frame, elapsed: number)
---@field flutters NextBat[]
---@field pool Texture[]
---@field running boolean
---@field untilFlutter? number Seconds until the next flutter.
local setProto = {}
addon:GetModule('Perf'):RegisterPrototype(setProto, 'NextBatSet')

function bats:Init()
  for run in pairs(self.flying or {}) do
    run:Release()
  end
  self.flying = {}
  self.pool = self.pool or {}
  if self.layer ~= nil then
    self.layer.driver:SetScript("OnUpdate", nil)
  end
end

-- Spec returns the theme's Panel.Bats, nil without one.
---@return table?
function bats:Spec()
  return style.Theme.Panel.Bats or nil
end

-- Closes says whether the theme's panels turn into bats as they close instead of sliding out.
---@return boolean
function bats:Closes()
  local S = self:Spec()
  return S ~= nil and S.Close ~= nil
end

-- Layer returns the bats layer, made the first time: a frame over the whole screen, in the DIALOG strata above the smoke
-- layer (the bats burst out of the smoke), taking no mouse, with the driver that flies them.
---@return Frame
function bats:Layer()
  if self.layer == nil then
    local layer = CreateFrame("Frame", nil, UIParent)
    layer:SetAllPoints(UIParent)
    layer:SetFrameStrata("DIALOG")
    layer:SetFrameLevel(smoke:Layer():GetFrameLevel() + 10)
    layer:EnableMouse(false)
    layer.driver = CreateFrame("Frame", nil, layer)
    self.layer = layer
  end
  return self.layer
end

---@param range number[]
---@return number
local function between(range)
  return range[1] + (range[2] - range[1]) * bats.Random()
end

-- texture takes a bat's texture from a pool, or makes one on a frame, painted in the theme's bat: drawn without the
-- client's sharpening (texture-sharpening.md).
---@param pool Texture[]
---@param host Frame
---@param S table
---@param layer? string
---@param sublevel? number
---@return Texture
local function texture(pool, host, S, layer, sublevel)
  local t = table.remove(pool)
  if t == nil then
    t = host:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
    t:SetSnapToPixelGrid(false)
    t:SetTexelSnappingBias(0)
  end
  t:SetDrawLayer(layer or "ARTWORK", sublevel or 0)
  style:Paint(t, { Texture = S.Texture, Color = S.Color or "White", BlendMode = S.BlendMode or "BLEND" })
  t:ClearAllPoints()
  t:SetRotation(0)
  t:Hide()
  return t
end

-- flap shows the frame of the art a bat is at, t seconds out.
---@param b NextBat
---@param S table
---@param t number
local function flap(b, S, t)
  local frames = S.Frames or 1
  local f = math.floor(b.phase + t * (S.FrameRate or 0)) % frames
  b.texture:SetTexCoord(f / frames, (f + 1) / frames, 0, 1)
end

-- Begin readies a closing panel's bats over its body where its BodyRect puts it on the screen, at its scale: its puff
-- comes as it vanishes (Vanish), its bats as it has (Fly).
---@param panel table
---@return NextBatRun
function bats:Begin(panel)
  local left, top, height, width, scale = panel:BodyRect()
  return setmetatable({ spec = self:Spec(), rect = { left = left, top = top, width = width, height = height },
    scale = scale or 1, bats = {}, puffed = false, elapsed = 0 }, { __index = runProto })
end

-- Vanish draws the close t seconds in, and returns the panel's alpha: the puff of smoke over the body comes out at once
-- (once), and the panel fades away under it over Vanish.
---@param t number
---@return number alpha The panel's.
function runProto:Vanish(t)
  local C = self.spec.Close
  if not self.puffed then
    self.puffed = true
    if C.Puff then
      smoke:Burst(self.rect, self.scale, C.Puff)
    end
  end
  local vanish = C.Vanish or 0
  if vanish <= 0 or t >= vanish then
    return 0
  end
  local p = t / vanish
  return 1 - p * p * (3 - 2 * p)
end

-- Fly sends the bats out of the smoke: Count of them from across the body (its middle four fifths), each away from the
-- body's middle give or take Spread (degrees either way), on the bats layer's driver.
function runProto:Fly()
  local C = self.spec.Close
  local rect = self.rect
  local cx, cy = rect.left + rect.width / 2, rect.top - rect.height / 2
  local layer = bats:Layer()
  local count = math.floor(between(C.Count or { 12, 12 }) + 0.5)
  for _ = 1, count do
    local x = cx + (bats.Random() - 0.5) * rect.width * 0.8
    local y = cy + (bats.Random() - 0.5) * rect.height * 0.8
    local away = math.atan2(y - cy, x - cx) + math.rad((2 * bats.Random() - 1) * (C.Spread or 40))
    local b = { texture = texture(bats.pool, layer, self.spec), x = x, y = y, dx = math.cos(away), dy = math.sin(away),
      speed = between(C.Speed or { 200, 200 }) * self.scale, size = between(C.Size or { 40, 40 }) * self.scale,
      delay = between(C.Delay or { 0, 0 }), phase = (self.spec.Frames or 1) * bats.Random(),
      wobble = 2 * math.pi * bats.Random() }
    table.insert(self.bats, b)
  end
  self.elapsed = 0
  bats.flying[self] = true
  local driver = layer.driver
  if driver:GetScript("OnUpdate") == nil then
    driver:SetScript("OnUpdate", function(_, elapsed)
      bats:Step(elapsed)
    end)
  end
end

-- fly moves a run's bats elapsed seconds on: each, once out, along its way (its speed growing by Accel of itself a
-- second), wobbling across it (Wobble: units either way, swings a second), banked by Tilt toward the side it flies to,
-- popping in to its size and growing a little as it comes nearer; hidden once off the screen. The run is given back
-- when every bat is, or after Life.
---@param elapsed number
function runProto:fly(elapsed)
  local S = self.spec
  local C = S.Close
  self.elapsed = self.elapsed + elapsed
  if self.elapsed >= (C.Life or 3) then
    self:Release()
    return
  end
  local layer = bats:Layer()
  local W, H = UIParent:GetWidth(), UIParent:GetHeight()
  local wobble = C.Wobble or { 0, 0 }
  local accel = C.Accel or 0
  local grow = C.Grow or 0
  local left = 0
  for _, b in ipairs(self.bats) do
    local t = self.elapsed - b.delay
    if not b.gone and t >= 0 then
      local along = b.speed * (t + accel * t * t / 2)
      local across = wobble[1] * self.scale * math.sin(b.wobble + 2 * math.pi * (wobble[2] or 0) * t)
      local x = b.x + b.dx * along - b.dy * across
      local y = b.y + b.dy * along + b.dx * across
      local scale = 1 + 0.15 * math.max(0, t - grow)
      if t < grow then
        local q = t / grow - 1
        scale = FIRST + (1 - FIRST) * (1 + (POP + 1) * q * q * q + POP * q * q)
      end
      local size = b.size * scale
      local tex = b.texture
      tex:SetPoint("CENTER", layer, "BOTTOMLEFT", x, y)
      tex:SetSize(size, size)
      tex:SetRotation(-math.rad(C.Tilt or 0) * b.dx)
      flap(b, S, t)
      if x < -b.size or x > W + b.size or y < -b.size or y > H + b.size then
        b.gone = true
        tex:Hide()
      else
        tex:Show()
      end
    end
    if not b.gone then
      left = left + 1
    end
  end
  if left == 0 then
    self:Release()
  end
end

-- Step flies every run on, and stops the driver when none is left.
---@param elapsed number
function bats:Step(elapsed)
  for run in pairs(self.flying) do
    run:fly(elapsed)
  end
  if next(self.flying) == nil then
    self:Layer().driver:SetScript("OnUpdate", nil)
  end
end

-- Release gives the run's textures back, hidden, at once; a run released again does nothing.
function runProto:Release()
  bats.flying[self] = nil
  for _, b in ipairs(self.bats) do
    b.texture:Hide()
    table.insert(bats.pool, b.texture)
  end
  self.bats = {}
end

-- Create gives a panel its fluttering bats, none until it shows (Start).
---@param panel table
---@return NextBatSet
function bats:Create(panel)
  local set = setmetatable({ panel = panel, flutters = {}, pool = {}, running = false }, { __index = setProto })
  set.driver = CreateFrame("Frame", nil, panel.frame)
  set.onUpdate = function(_, elapsed)
    set:Step(elapsed)
  end
  return set
end

-- Flutter returns the theme's Panel.Bats.Flutter, nil without one.
---@private
---@return table?
function setProto:Flutter()
  local S = bats:Spec()
  return S and S.Flutter or nil
end

-- Style takes the theme's bats: a flutter under way ends; fluttering while the panel showed, they flutter on (Start).
function setProto:Style()
  local running = self.running
  self:Stop()
  if running then
    self:Start()
  end
end

-- Start lets them flutter (the panel shows): the next flutter due, one now with OnOpen.
function setProto:Start()
  self.running = true
  local F = self:Flutter()
  if F == nil then
    self.driver:SetScript("OnUpdate", nil)
    return
  end
  self.untilFlutter = between(F.Every)
  if F.OnOpen then
    self:Send()
  end
  self.driver:SetScript("OnUpdate", self.onUpdate)
end

-- Stop ends them (the panel hid): every bat gone, none due.
function setProto:Stop()
  self.running = false
  self.untilFlutter = nil
  for _, b in ipairs(self.flutters) do
    b.texture:Hide()
    table.insert(self.pool, b.texture)
  end
  self.flutters = {}
  self.driver:SetScript("OnUpdate", nil)
end

-- Send sends a flutter out: Count bats, Stagger apart, each from somewhere in the header band of the body (Band: down
-- from its top), flying toward the inner side, out into the world, rising or falling a little (Rise).
function setProto:Send()
  local S = bats:Spec()
  local F = S.Flutter
  local panel = self.panel
  local left, width = panel:BodyLeft(), panel:BodyWidth()
  local dir = panel.side == "LEFT" and 1 or -1
  local count = math.floor(between(F.Count or { 1, 1 }) + 0.5)
  for i = 1, count do
    local b = { texture = texture(self.pool, panel.frame, S, F.Layer or "BORDER", F.SubLevel or 5),
      x = left + width * (0.25 + 0.75 * bats.Random()), y = between(F.Band or { 30, 60 }), dx = dir, dy = 0,
      speed = between(F.Speed or { 100, 100 }), size = between(F.Size or { 24, 24 }),
      phase = (S.Frames or 1) * bats.Random(), wobble = 2 * math.pi * bats.Random(),
      rise = between(F.Rise or { 0, 0 }), age = -((i - 1) * (F.Stagger or 0)) }
    if dir > 0 then
      b.x = left + width * 0.75 * bats.Random()
    end
    table.insert(self.flutters, b)
    self:draw(b)
  end
end

-- draw places a fluttering bat where it is: hidden until it is out; along its way at its speed, rising, wobbling up
-- and down, flapping, faded in over the first tenth of its Travel and out over the last quarter.
---@private
---@param b NextBat
function setProto:draw(b)
  local S = bats:Spec()
  local F = S.Flutter
  local t = b.age
  local tex = b.texture
  if t < 0 then
    tex:Hide()
    return
  end
  local travel = F.Travel or 300
  local p = b.speed * t / travel
  local wobble = F.Wobble or { 0, 0 }
  local y = b.y + b.rise * t + wobble[1] * math.sin(b.wobble + 2 * math.pi * (wobble[2] or 0) * t)
  tex:SetPoint("CENTER", self.panel.frame, "TOPLEFT", b.x + b.dx * b.speed * t, -y)
  tex:SetSize(b.size, b.size)
  tex:SetAlpha((F.Alpha or 1) * math.min(1, p / 0.1) * math.min(1, (1 - p) / 0.25))
  flap(b, S, t)
  tex:Show()
end

-- Step moves the flutters elapsed seconds on (each given back once it has flown its Travel), and sends the next when it
-- is due: none in combat (it is due again Every later).
---@param elapsed number
function setProto:Step(elapsed)
  local F = self:Flutter()
  if F == nil then
    return
  end
  local flying = {}
  for _, b in ipairs(self.flutters) do
    b.age = b.age + elapsed
    if b.age >= 0 and b.speed * b.age >= (F.Travel or 300) then
      b.texture:Hide()
      table.insert(self.pool, b.texture)
    else
      self:draw(b)
      table.insert(flying, b)
    end
  end
  self.flutters = flying
  if self.untilFlutter ~= nil then
    self.untilFlutter = self.untilFlutter - elapsed
    if self.untilFlutter <= 0 then
      if not InCombatLockdown() then
        self:Send()
      end
      self.untilFlutter = between(F.Every)
    end
  end
end

-- MovingParts adds every fluttering bat to skip: they rest nowhere, so the pixel checks leave them out.
---@param skip table<table, boolean>
function setProto:MovingParts(skip)
  for _, b in ipairs(self.flutters) do
    skip[b.texture] = true
  end
end
