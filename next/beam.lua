local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

-- NextBeam beams a Next panel in and out as a starship's transporter does (Panel.Beam, next-themes.md §24; the Make It So
-- theme; asked: "the bags obviously need the star trek beam down, and beam up animation for appearing and closing ...
-- most important part is beam down/beam up"). A run is one panel's beam on the beam layer, a frame over the screen
-- above every panel; the panel drives it (next/panel.lua). It has three parts:
--   Sparkles: flecks of light laid over the body (Density of them to every 100 x 100 units of it, Spread past its
--     sides), each twinkling (Twinkle flashes a second, Sharpness making them brief), swelling as it flashes, drawn out
--     up and down (Stretch), drifting up or down (Drift) round the body, as the transporter's shimmer ripples.
--   Column: a column of light over the body and Spread past its sides, shimmering (Shimmer: how deep, how fast) and its
--     art flowing up (Scroll, of its height a second).
--   Glow: the body lit as it materializes or dematerializes.
-- It covers the body and Margin past it all round, and runs Ends past that above and below, where its column and its
-- sparkles fade out to nothing and its glow's art softens, so it has no hard top or bottom.
-- Each part grows in and out over an envelope of its own ({ in, full, out, gone } seconds): a beam down's (Open), the
-- panel shown under it over its Reveal; a beam up's (Close), the panel fading out of it over its Fade. The run lingers
-- on its own layer after the panel's part, until its last part has gone out (Linger). A theme without Panel.Beam has none.
---@class NextBeam: AceModule
local beam = addon:NewModule('NextBeam')

-- Where the beam takes its randomness (a source of numbers in [0, 1)): replaced by the specs.
beam.Random = math.random

-- The keys of Panel.Beam, of its Sparkles, its Column, its Glow, its Open and its Close, for SonataNext:Check.
beam.KEYS = { Sparkles = true, Column = true, Glow = true, Open = true, Close = true, Margin = true, Ends = true }
beam.SPARKLE_KEYS = { Texture = true, Colors = true, Density = true, Size = true, Stretch = true, Alpha = true,
  BlendMode = true, Twinkle = true, Sharpness = true, Drift = true, Spread = true }
beam.COLUMN_KEYS = { Texture = true, Color = true, Alpha = true, BlendMode = true, Spread = true, Shimmer = true,
  Scroll = true }
beam.GLOW_KEYS = { Texture = true, Color = true, Alpha = true, BlendMode = true }
beam.OPEN_KEYS = { Reveal = true, Sparkles = true, Column = true, Glow = true }
beam.CLOSE_KEYS = { Fade = true, Sparkles = true, Column = true, Glow = true }
-- The parts with an envelope.
beam.ENVELOPES = { "Sparkles", "Column", "Glow" }
-- The mask that fades the column's ends (tools/textures/next_masks.py): nothing at its top, all at its bottom.
beam.END_MASK = "Interface\\AddOns\\BetterBags\\textures\\next\\beam_end.png"

---@class (exact) NextBeamSparkle
---@field texture Texture
---@field x number Its middle, on the layer (UIParent's units, y up).
---@field y number Where it is as the run starts.
---@field drift number Units a second up (down, negative).
---@field size number
---@field twinkle number Flashes a second.
---@field phase number Where its twinkle starts, radians.
---@field alpha number

---@class (exact) NextBeamRun
---@field spec table The theme's Panel.Beam it began with.
---@field timing table Its phase's: Panel.Beam.Open or Close.
---@field phase string "Open" or "Close".
---@field sparkles NextBeamSparkle[]
---@field column? Texture
---@field glow? Texture
---@field masks MaskTexture[] The column's, fading its ends.
---@field bottom number The bottom of where it runs on the layer, its ends included.
---@field height number Of where it runs, its ends included.
---@field ends number How far it runs past what it covers, above and below, on the layer.
---@field clear number When its last part has gone out.
---@field elapsed number How long it has lived, while it lingers.
local runProto = {}
addon:GetModule('Perf'):RegisterPrototype(runProto, 'NextBeamRun')

function beam:Init()
  for run in pairs(self.living or {}) do
    run:Release()
  end
  self.living = {}
  self.pool = self.pool or {}
  self.maskPool = self.maskPool or {}
  if self.layer ~= nil then
    self.layer.driver:SetScript("OnUpdate", nil)
  end
end

-- Spec returns the theme's Panel.Beam, nil without one.
---@return table?
function beam:Spec()
  return style.Theme.Panel.Beam or nil
end

-- Opens says whether the theme's panels beam down instead of sliding in.
---@return boolean
function beam:Opens()
  local S = self:Spec()
  return S ~= nil and S.Open ~= nil
end

-- Closes says whether the theme's panels beam up instead of sliding out.
---@return boolean
function beam:Closes()
  local S = self:Spec()
  return S ~= nil and S.Close ~= nil
end

-- OpenLock is when the panel has materialized (its threads draw in and its sections cascade from then); OpenTime is the
-- panel's part of the beam down, until then (it says it has shown); CloseTime the panel's part of the beam up, until it
-- has gone; ClearTime when a phase's last part has gone out (the latest end of its envelopes; none without one).
---@return number
function beam:OpenLock()
  return self:Spec().Open.Reveal[2]
end

---@return number
function beam:OpenTime()
  return self:OpenLock()
end

---@return number
function beam:CloseTime()
  return self:Spec().Close.Fade[2]
end

---@param phase string "Open" or "Close".
---@return number
function beam:ClearTime(phase)
  local O = self:Spec()[phase]
  local clear = 0
  for _, part in ipairs(self.ENVELOPES) do
    if O[part] ~= nil then
      clear = math.max(clear, O[part][4])
    end
  end
  return clear
end

-- Layer returns the beam layer, made the first time: a frame over the whole screen, in the DIALOG strata (above the
-- panels, HIGH), taking no mouse, with the driver that lets a beam linger.
---@return Frame
function beam:Layer()
  if self.layer == nil then
    local layer = CreateFrame("Frame", nil, UIParent)
    layer:SetAllPoints(UIParent)
    layer:SetFrameStrata("DIALOG")
    layer:SetFrameLevel(15)
    layer:EnableMouse(false)
    layer.driver = CreateFrame("Frame", nil, layer)
    self.layer = layer
  end
  return self.layer
end

---@param range number[]
---@return number
local function between(range)
  return range[1] + (range[2] - range[1]) * beam.Random()
end

---@param e0 number
---@param e1 number
---@param x number
---@return number
local function smoothstep(e0, e1, x)
  local t = math.max(0, math.min(1, (x - e0) / (e1 - e0)))
  return t * t * (3 - 2 * t)
end

-- envelope is how strong a part is t seconds in: in over its first two numbers, out over its last two.
---@param e number[]
---@param t number
---@return number
local function envelope(e, t)
  return smoothstep(e[1], e[2], t) * (1 - smoothstep(e[3], e[4], t))
end

---@param list string[]?
---@return string
local function pick(list)
  local colors = list or { "White" }
  return colors[math.min(#colors, math.floor(beam.Random() * #colors) + 1)]
end

-- texture takes a texture from the pool, or makes one on the layer: drawn without the client's sharpening
-- (texture-sharpening.md).
---@param layer string
---@param sublevel number
---@return Texture
local function texture(layer, sublevel)
  local t = table.remove(beam.pool)
  if t == nil then
    t = beam:Layer():CreateTexture(nil, layer, nil, sublevel)
    t:SetSnapToPixelGrid(false)
    t:SetTexelSnappingBias(0)
  end
  t:SetDrawLayer(layer, sublevel)
  t:ClearAllPoints()
  t:Hide()
  return t
end

-- over hangs a texture from the layer by its top left at a rect's (y up) and sizes it to the rect.
---@param t Texture
---@param left number
---@param top number
---@param width number
---@param height number
local function over(t, left, top, width, height)
  t:SetPoint("TOPLEFT", beam:Layer(), "BOTTOMLEFT", left, top)
  t:SetSize(width, height)
end

-- endMask takes a mask from the pool, or makes one on the layer, drawn with the end's art.
---@return MaskTexture
local function endMask()
  local m = table.remove(beam.maskPool)
  if m == nil then
    m = beam:Layer():CreateMaskTexture()
    m:SetTexture(beam.END_MASK, "CLAMPTOWHITE", "CLAMPTOWHITE")
  end
  m:ClearAllPoints()
  m:Show()
  return m
end

-- Reach is the rect a panel's beam covers, on the screen: its body where its BodyRect puts it and Margin past it evenly
-- all round, at its scale (asked: "make sure it covers the window + it's decoration fully", then "too far to the left
-- (leave tabs out) and not enough on the right": its tabs, sticking out of its inner side, are left out). Its left and
-- top, its height and width, its scale.
---@param panel table
---@return number left, number top, number height, number width, number scale
function beam:Reach(panel)
  local left, top, height, width, scale = panel:BodyRect()
  scale = scale or 1
  local margin = (self:Spec().Margin or 0) * scale
  return left - margin, top + margin, height + 2 * margin, width + 2 * margin, scale
end

-- Begin readies a panel's beam on the beam layer, unseen until it draws: its phase ("Open", a beam down; "Close", a
-- beam up), its sparkles over what it covers (Reach) and its ends, its column and glow. Asked of the ends: "the top and
-- bottom beam are cut off extremely clean on the horizontal plane, almost like it's clipped at the top and bottom".
---@param panel table
---@param phase string
---@return NextBeamRun
function beam:Begin(panel, phase)
  local S = self:Spec()
  local left, top, height, width, scale = self:Reach(panel)
  local ends = (S.Ends or 0) * scale
  top, height = top + ends, height + 2 * ends
  ---@type NextBeamRun
  local run = setmetatable({ spec = S, timing = S[phase], phase = phase, sparkles = {}, masks = {},
    bottom = top - height, height = height, ends = ends, clear = self:ClearTime(phase), elapsed = 0 },
    { __index = runProto })
  local C = S.Column
  if C ~= nil then
    local t = texture("ARTWORK", 0)
    style:Paint(t, { Texture = C.Texture, Color = C.Color or "White", BlendMode = C.BlendMode or "ADD" })
    -- Loaded repeating down its length, so its coordinates scroll its art round (not tiled by the client).
    t:SetTexture(style:TexturePath(C.Texture), nil, "REPEAT", "TRILINEAR")
    local spread = (C.Spread or 0) * scale
    over(t, left - spread, top, width + 2 * spread, height)
    run.column = t
    -- Its ends fade to nothing: a mask over each, the art's own coordinates left to scroll.
    if ends > 0 then
      for i, edge in ipairs({ "TOP", "BOTTOM" }) do
        local m = endMask()
        m:SetPoint(edge .. "LEFT", t, edge .. "LEFT", 0, 0)
        m:SetPoint(edge .. "RIGHT", t, edge .. "RIGHT", 0, 0)
        m:SetHeight(ends)
        m:SetTexCoord(0, 1, i == 1 and 0 or 1, i == 1 and 1 or 0)
        t:AddMaskTexture(m)
        table.insert(run.masks, m)
      end
    end
  end
  local G = S.Glow
  if G ~= nil then
    local t = texture("ARTWORK", 1)
    style:Paint(t, { Texture = G.Texture, Color = G.Color or "White", BlendMode = G.BlendMode or "ADD" })
    over(t, left, top, width, height)
    run.glow = t
  end
  local P = S.Sparkles
  local count = math.max(1, math.floor(P.Density * (width / scale) * (height / scale) / 10000 + 0.5))
  local spread = (P.Spread or 0) * scale
  for _ = 1, count do
    local t = texture("OVERLAY", 0)
    style:Paint(t, { Texture = P.Texture, Color = pick(P.Colors), BlendMode = P.BlendMode or "ADD" })
    local drift = between(P.Drift or { 0, 0 }) * scale
    if self.Random() < 0.5 then
      drift = -drift
    end
    table.insert(run.sparkles, { texture = t, x = left - spread + (width + 2 * spread) * self.Random(),
      y = top - height * self.Random(), drift = drift, size = between(P.Size) * scale,
      twinkle = between(P.Twinkle or { 4, 4 }), phase = 2 * math.pi * self.Random(),
      alpha = type(P.Alpha) == "table" and between(P.Alpha) or (P.Alpha or 1) })
  end
  return run
end

-- Draw draws the beam t seconds into its phase, and returns the panel's alpha: shown over its Reveal as it beams down
-- (from nothing at its first to full at its second), faded over its Fade as it beams up.
---@param t number
---@return number alpha The panel's.
function runProto:Draw(t)
  local S, O = self.spec, self.timing
  local P = S.Sparkles
  local stretch, sharpness = P.Stretch or 1, P.Sharpness or 1
  local env = O.Sparkles and envelope(O.Sparkles, t) or 0
  local bottom, top, ends = self.bottom, self.bottom + self.height, self.ends
  for _, s in ipairs(self.sparkles) do
    local tex = s.texture
    local tw = ((1 + math.sin(2 * math.pi * s.twinkle * t + s.phase)) / 2) ^ sharpness
    if env <= 0 then
      tex:Hide()
    else
      local size = s.size * (0.5 + 0.5 * tw)
      local y = bottom + (s.y - bottom + s.drift * t) % self.height
      -- Fading out over its ends, as the column does.
      local fade = ends > 0 and smoothstep(bottom, bottom + ends, y) * (1 - smoothstep(top - ends, top, y)) or 1
      tex:SetPoint("CENTER", beam:Layer(), "BOTTOMLEFT", s.x, y)
      tex:SetSize(size, size * stretch)
      tex:SetAlpha(env * tw * s.alpha * fade)
      tex:Show()
    end
  end
  local C = S.Column
  if self.column ~= nil then
    local strength = O.Column and envelope(O.Column, t) or 0
    if strength <= 0 then
      self.column:Hide()
    else
      local shimmer = C.Shimmer or { 0, 0 }
      local depth = shimmer[1]
      local a = strength * (C.Alpha or 1) * (1 - depth + depth * (0.5 + 0.5 * math.sin(2 * math.pi * shimmer[2] * t)))
      local v = ((C.Scroll or 0) * t) % 1
      self.column:SetTexCoord(0, 1, v, v + 1)
      self.column:SetAlpha(a)
      self.column:Show()
    end
  end
  if self.glow ~= nil then
    local strength = O.Glow and envelope(O.Glow, t) or 0
    if strength <= 0 then
      self.glow:Hide()
    else
      self.glow:SetAlpha(strength * (S.Glow.Alpha or 1))
      self.glow:Show()
    end
  end
  if self.phase == "Open" then
    return smoothstep(O.Reveal[1], O.Reveal[2], t)
  end
  return 1 - smoothstep(O.Fade[1], O.Fade[2], t)
end

-- Linger lets the run live on by itself on the beam layer's driver from t seconds into it (the panel's part is done),
-- until its last part has gone out.
---@param t number
function runProto:Linger(t)
  self.elapsed = t
  beam.living[self] = true
  local driver = beam:Layer().driver
  if driver:GetScript("OnUpdate") == nil then
    driver:SetScript("OnUpdate", function(_, elapsed)
      beam:Step(elapsed)
    end)
  end
end

-- Step lives every lingering run on elapsed seconds, giving back those that have gone out, and stops the driver when
-- none is left.
---@param elapsed number
function beam:Step(elapsed)
  for run in pairs(self.living) do
    run.elapsed = run.elapsed + elapsed
    if run.elapsed >= run.clear then
      run:Release()
    else
      run:Draw(run.elapsed)
    end
  end
  if next(self.living) == nil then
    self:Layer().driver:SetScript("OnUpdate", nil)
  end
end

-- Release gives the run's textures and masks back, hidden, at once (the masks off its column first, so a texture used
-- again is not cut); a run released again does nothing.
function runProto:Release()
  beam.living[self] = nil
  for _, m in ipairs(self.masks) do
    self.column:RemoveMaskTexture(m)
    m:Hide()
    table.insert(beam.maskPool, m)
  end
  self.masks = {}
  for _, s in ipairs(self.sparkles) do
    s.texture:Hide()
    table.insert(beam.pool, s.texture)
  end
  self.sparkles = {}
  for _, key in ipairs({ "column", "glow" }) do
    local t = self[key]
    if t ~= nil then
      t:Hide()
      table.insert(beam.pool, t)
      self[key] = nil
    end
  end
end
