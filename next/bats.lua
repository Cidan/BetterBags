local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

-- NextBats breaks a closing Next panel up and turns it into bats, and sends a few fluttering out of its header now and
-- then while it shows (Panel.Bats, next-themes.md §23; the Halloween theme; asked: "make the bag 'turn into' several
-- bats, like 10-15 bats, and fly away in random directions off screen. like old school cartoon vampires turning into
-- bats", then: "no puff of smokes: how the frost theme shatters, we want the bag break up *and morph* into bats and fly
-- away. almost a surreal effect"). A bat is a flipbook: the art holds Frames pictures of it flapping side by side, shown
-- in turn FrameRate a second, each bat from its own. Closing (Close): the panel trembles (Shudder, Tremble), then
-- breaks into about Count pieces of its own art (Pieces: the fill, cut as the body lies where its BodyRect puts it, in a
-- grid of cells their inner corners moved up to Jitter of a cell, tiling it exactly; each a texture whose four corners
-- are moved onto its own, SetVertexOffset, carrying the fill where it lies), on the bats layer, a frame over the screen
-- above the panels, which carries them on after the panel has hidden. The pieces drift apart straight out from where it
-- breaks (the pointer over the body, else its middle: Gap over Break); then each in its own time (Delay, nearer where it
-- broke first) turns into a bat over Morph: it shrinks toward the bat's size, its top spreading into wings and its bottom
-- drawn in, flapping, banking, darkening toward Dark, as the bat comes out of it, and it is gone into it. The bat flies
-- away (give or take Spread degrees) faster and faster, wobbling across its way and banking toward where it goes, until
-- it is off the screen (Life at most). Fluttering (Flutter): every Every, Count bats one after another fly out of the
-- header band of the body toward its inner side, out into the world, over Travel, fading as they end it; drawn on the
-- panel's frame, under its content, only while it shows. A theme without Panel.Bats has none.
---@class NextBats: AceModule
local bats = addon:NewModule('NextBats')

-- Where the bats take their randomness (a source of numbers in [0, 1)): replaced by the specs.
bats.Random = math.random

-- The keys of Panel.Bats, of its Close and of its Flutter, for SonataNext:Check.
bats.KEYS = { Texture = true, Frames = true, FrameRate = true, Color = true, BlendMode = true, Close = true,
  Flutter = true }
bats.CLOSE_KEYS = { Count = true, Pieces = true, Jitter = true, Shudder = true, Tremble = true, Break = true, Gap = true,
  Morph = true, Dark = true, Delay = true, Size = true, Speed = true, Accel = true, Wobble = true, Tilt = true,
  Life = true, Spread = true }
bats.FLUTTER_KEYS = { Every = true, Count = true, Size = true, Speed = true, Wobble = true, Stagger = true,
  Travel = true, Band = true, Rise = true, Alpha = true, OnOpen = true, Layer = true, SubLevel = true }

-- Blizzard's vertex indices (Blizzard_FrameXMLBase/Constants.lua, every client).
local UL, LL, UR, LR = 1, 2, 3, 4

-- How fast a panel trembles before it breaks (swings a second).
local TREMBLE_RATE = 24

-- As a piece turns into its bat: how much wider its top spreads, how much its bottom is drawn in, and how high its wings
-- flap (a share of its bat's size), at the end of its morph.
local SPREAD_TOP = 0.6
local DRAW_IN = 0.7
local FLAP = 0.4

---@class (exact) NextBat
---@field texture Texture
---@field x number A flutter's start, from the panel's top left, y down.
---@field y number
---@field dx number The way it flies (1 toward the right, -1 the left).
---@field dy number
---@field speed number Units a second.
---@field size number
---@field phase number Where its flapping starts, in frames.
---@field wobble number Where its wobble starts, in radians.
---@field rise number Units a second up (y down: negative is up).
---@field age number Seconds out (negative: not yet).

---@class (exact) NextBatPiece
---@field art Texture The fill where the piece lies.
---@field bat Texture The bat it turns into.
---@field corners number[][] Where its upper left, upper right, lower right and lower left are on the layer (y up).
---@field cx number Its middle.
---@field cy number
---@field local_ number[][] Its corners from its middle.
---@field sx number Straight out from where it broke, a unit vector.
---@field sy number
---@field dx number The way its bat flies, a unit vector.
---@field dy number
---@field delay number Seconds after the break before it turns.
---@field speed number Units a second as its bat sets off.
---@field size number Its bat's size.
---@field reach number Its own size (the square root of its area).
---@field phase number Where its bat's flapping starts, in frames.
---@field wobble number Where its wobble starts, in radians.
---@field gone? boolean Off the screen.

---@class (exact) NextBatRun
---@field spec table The theme's Panel.Bats it began with.
---@field pieces NextBatPiece[]
---@field scale number
---@field elapsed number How long since it broke.
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
  self.arts = self.arts or {}
  if self.layer ~= nil then
    self.layer.driver:SetScript("OnUpdate", nil)
  end
end

-- Spec returns the theme's Panel.Bats, nil without one.
---@return table?
function bats:Spec()
  return style.Theme.Panel.Bats or nil
end

-- Closes says whether the theme's panels break up into bats as they close instead of sliding out.
---@return boolean
function bats:Closes()
  local S = self:Spec()
  return S ~= nil and S.Close ~= nil
end

-- Layer returns the bats layer, made the first time: a frame over the whole screen, in the DIALOG strata (above the
-- panels, HIGH), taking no mouse, with the driver that flies them.
---@return Frame
function bats:Layer()
  if self.layer == nil then
    local layer = CreateFrame("Frame", nil, UIParent)
    layer:SetAllPoints(UIParent)
    layer:SetFrameStrata("DIALOG")
    layer:SetFrameLevel(20)
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

---@param e0 number
---@param e1 number
---@param x number
---@return number
local function smoothstep(e0, e1, x)
  local t = math.max(0, math.min(1, (x - e0) / (e1 - e0)))
  return t * t * (3 - 2 * t)
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
---@param tex Texture
---@param phase number
---@param S table
---@param t number
local function flap(tex, phase, S, t)
  local frames = S.Frames or 1
  local f = math.floor(phase + t * (S.FrameRate or 0)) % frames
  tex:SetTexCoord(f / frames, (f + 1) / frames, 0, 1)
end

-- place moves a piece's art's corners onto four points ({ x, y } on the layer, y up: its upper left, upper right, lower
-- right and lower left); an offset is from where the corner is in the unit square at the layer's bottom left.
---@param t Texture
---@param cs number[][]
local function place(t, cs)
  t:SetVertexOffset(UL, cs[1][1], cs[1][2] - 1)
  t:SetVertexOffset(UR, cs[2][1] - 1, cs[2][2] - 1)
  t:SetVertexOffset(LR, cs[3][1] - 1, cs[3][2])
  t:SetVertexOffset(LL, cs[4][1], cs[4][2])
end

-- Begin readies a closing panel's pieces on the bats layer, unseen until it breaks: about Count of them (in a grid as
-- near square as the body allows), cut where its body is (BodyRect, at its scale), their art the fill where they lie
-- (FillRect: it can reach past the body), each to fly from where it breaks (focus: the pointer over the body; without
-- one, its middle).
---@param panel table
---@param focus? {x: number, y: number}
---@return NextBatRun
function bats:Begin(panel, focus)
  local S = self:Spec()
  local C = S.Close
  local left, top, height, width, scale = panel:BodyRect()
  scale = scale or 1
  local fl, ft, fw, fh = panel:FillRect()
  if fl == nil then
    fl, ft, fw, fh = left, top, width, height
  end
  local n = math.max(1, math.floor(between(C.Count or { 12, 12 }) + 0.5))
  local cols = math.max(1, math.floor(math.sqrt(n * width / height) + 0.5))
  local rows = math.max(1, math.floor(n / cols + 0.5))
  local cw, ch = width / cols, height / rows
  local jitter = C.Jitter or 0
  -- The grid's corners, the inner ones moved up to Jitter of a cell either way (those on an edge only along it).
  local verts = {}
  for j = 0, rows do
    verts[j] = {}
    for i = 0, cols do
      local x, y = left + i * cw, top - j * ch
      if i > 0 and i < cols then x = x + (2 * self.Random() - 1) * jitter * cw end
      if j > 0 and j < rows then y = y + (2 * self.Random() - 1) * jitter * ch end
      verts[j][i] = { x, y }
    end
  end
  local fx, fy = left + width / 2, top - height / 2
  if focus ~= nil then
    fx, fy = focus.x, focus.y
  end
  local layer = self:Layer()
  ---@type NextBatRun
  local run = setmetatable({ spec = S, pieces = {}, scale = scale, elapsed = 0 }, { __index = runProto })
  local farthest = 0
  for j = 0, rows - 1 do
    for i = 0, cols - 1 do
      local cs = { verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i] }
      local cx, cy = 0, 0
      for _, c in ipairs(cs) do
        cx, cy = cx + c[1] / 4, cy + c[2] / 4
      end
      local art = table.remove(self.arts)
      if art == nil then
        art = layer:CreateTexture(nil, "ARTWORK", nil, 0)
        art:SetPoint("BOTTOMLEFT", layer, "BOTTOMLEFT", 0, 0)
        art:SetSize(1, 1)
        art:SetSnapToPixelGrid(false)
        art:SetTexelSnappingBias(0)
      end
      style:Paint(art, C.Pieces or { Color = "White" })
      art:SetTexCoord((cs[1][1] - fl) / fw, (ft - cs[1][2]) / fh, (cs[4][1] - fl) / fw, (ft - cs[4][2]) / fh,
        (cs[2][1] - fl) / fw, (ft - cs[2][2]) / fh, (cs[3][1] - fl) / fw, (ft - cs[3][2]) / fh)
      art:Hide()
      local ox, oy = cx - fx, cy - fy
      local d = math.sqrt(ox * ox + oy * oy)
      farthest = math.max(farthest, d)
      local sx, sy
      if d > 0 then
        sx, sy = ox / d, oy / d
      else
        local a = 2 * math.pi * self.Random()
        sx, sy = math.cos(a), math.sin(a)
      end
      local away = math.atan2(sy, sx) + math.rad((2 * self.Random() - 1) * (C.Spread or 40))
      local area = 0
      for k = 1, 4 do
        local a, b = cs[k], cs[k % 4 + 1]
        area = area + a[1] * b[2] - b[1] * a[2]
      end
      local localCorners = {}
      for k = 1, 4 do
        localCorners[k] = { cs[k][1] - cx, cs[k][2] - cy }
      end
      table.insert(run.pieces, { art = art, bat = texture(self.pool, layer, S, "ARTWORK", 2), corners = cs,
        cx = cx, cy = cy, local_ = localCorners, sx = sx, sy = sy, dx = math.cos(away), dy = math.sin(away),
        delay = d, speed = between(C.Speed or { 200, 200 }) * scale, size = between(C.Size or { 40, 40 }) * scale,
        reach = math.sqrt(math.abs(area) / 2), phase = (S.Frames or 1) * self.Random(),
        wobble = 2 * math.pi * self.Random() })
    end
  end
  -- Nearer where it broke first, give or take a little.
  local delay = C.Delay or { 0, 0 }
  for _, p in ipairs(run.pieces) do
    local share = farthest > 0 and p.delay / farthest or 0
    p.delay = delay[1] + (delay[2] - delay[1]) * (0.8 * share + 0.2 * self.Random())
  end
  return run
end

-- Shudder is how far the panel stands from its place t seconds into its trembling before it breaks (across): Tremble
-- either way, dying away to nothing over Shudder.
---@param t number
---@return number
function runProto:Shudder(t)
  local C = self.spec.Close
  local time = C.Shudder or 0
  if time <= 0 or t >= time then
    return 0
  end
  return (C.Tremble or 0) * self.scale * math.sin(2 * math.pi * TREMBLE_RATE * t) * (1 - t / time)
end

-- Break shows the pieces where the body was (the panel hides as they show) and flies them on the bats layer's driver.
function runProto:Break()
  self.elapsed = 0
  for _, p in ipairs(self.pieces) do
    place(p.art, p.corners)
    p.art:SetVertexColor(1, 1, 1)
    p.art:SetAlpha(1)
    p.art:Show()
  end
  bats.flying[self] = true
  local driver = bats:Layer().driver
  if driver:GetScript("OnUpdate") == nil then
    driver:SetScript("OnUpdate", function(_, elapsed)
      bats:Step(elapsed)
    end)
  end
end

-- fly moves a run elapsed seconds on: its pieces drift apart over Break; each then turns into its bat over Morph after
-- its delay, and the bat flies away; a bat off the screen is hidden. The run is given back when every bat is, or after
-- Life.
---@param elapsed number
function runProto:fly(elapsed)
  local S = self.spec
  local C = S.Close
  self.elapsed = self.elapsed + elapsed
  local e = self.elapsed
  if e >= (C.Life or 3) then
    self:Release()
    return
  end
  local layer = bats:Layer()
  local W, H = UIParent:GetWidth(), UIParent:GetHeight()
  local breakTime = C.Break or 0
  local gap = (C.Gap or 0) * self.scale * (breakTime > 0 and smoothstep(0, breakTime, e) or 1)
  local morph = C.Morph or 0
  local wobble = C.Wobble or { 0, 0 }
  local accel = C.Accel or 0
  local tilt = math.rad(C.Tilt or 0)
  local dr, dg, db = style:RGBA(C.Dark or "Black")
  local flapRate = (S.FrameRate or 0) / (S.Frames or 1)
  local left = 0
  for _, p in ipairs(self.pieces) do
    if not p.gone then
      local t = e - breakTime - p.delay
      local ox, oy = p.cx + p.sx * gap, p.cy + p.sy * gap
      if t < 0 then
        -- Broken off and drifting apart, not turning yet.
        local cs = {}
        for k = 1, 4 do
          cs[k] = { ox + p.local_[k][1], oy + p.local_[k][2] }
        end
        place(p.art, cs)
      else
        local q = morph > 0 and math.min(1, t / morph) or 1
        local m = smoothstep(0, 1, q)
        local ramp = morph > 0 and smoothstep(0, morph, t) or 1
        local along = p.speed * (t + accel * t * t / 2) * ramp
        local across = wobble[1] * self.scale * math.sin(p.wobble + 2 * math.pi * (wobble[2] or 0) * t) * ramp
        local x = ox + p.dx * along - p.dy * across
        local y = oy + p.dy * along + p.dx * across
        local bank = -tilt * p.dx
        if q < 1 then
          -- The piece shrinks toward its bat's size, its top spreading into wings and its bottom drawn in, flapping,
          -- banking as its bat will, darkening toward Dark.
          local k = 1 + (p.size / p.reach - 1) * m
          local wing = FLAP * p.size * m * math.sin(2 * math.pi * flapRate * t)
          local c, s = math.cos(bank * m), math.sin(bank * m)
          local cs = {}
          for idx = 1, 4 do
            local lx, ly = p.local_[idx][1] * k, p.local_[idx][2] * k
            if idx <= 2 then
              lx, ly = lx * (1 + SPREAD_TOP * m), ly + wing
            else
              lx = lx * (1 - DRAW_IN * m)
            end
            cs[idx] = { x + lx * c - ly * s, y + lx * s + ly * c }
          end
          place(p.art, cs)
          local dark = smoothstep(0.1, 0.7, q)
          p.art:SetVertexColor(1 + (dr - 1) * dark, 1 + (dg - 1) * dark, 1 + (db - 1) * dark)
          p.art:SetAlpha(1 - smoothstep(0.65, 1, q))
        else
          p.art:Hide()
        end
        local alpha = smoothstep(0.45, 0.9, q)
        local bat = p.bat
        if alpha > 0 then
          local size = p.size * (0.7 + 0.3 * m) * (1 + 0.15 * math.max(0, t - morph))
          bat:SetPoint("CENTER", layer, "BOTTOMLEFT", x, y)
          bat:SetSize(size, size)
          bat:SetRotation(bank)
          bat:SetAlpha(alpha)
          flap(bat, p.phase, S, t)
          if x < -p.size or x > W + p.size or y < -p.size or y > H + p.size then
            p.gone = true
            bat:Hide()
            p.art:Hide()
          else
            bat:Show()
          end
        end
      end
    end
    if not p.gone then
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
  for _, p in ipairs(self.pieces) do
    p.art:Hide()
    p.bat:Hide()
    table.insert(bats.arts, p.art)
    table.insert(bats.pool, p.bat)
  end
  self.pieces = {}
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
  flap(tex, b.phase, S, t)
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
