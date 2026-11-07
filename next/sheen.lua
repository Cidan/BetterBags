local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

-- NextSheen opens and closes a Next panel as a pane of glass catching the light (Panel.Sheen, next-themes-glass.md §26;
-- the Rainy Window theme; asked, of a fog and a wash first tried: "kind of lame -- something more... elegant?"). A run is
-- one panel's on the sheen layer, a frame over the screen above every panel; the panel drives it (next/panel.lua).
--   Band: a soft band of light Width across sweeps over the body from its inner side out, tilted down Angle degrees, as
--     a sheet of glass turned toward you catches the light; closing, it sweeps back the other way. Its art (a profile
--     across it) is laid over the body by its texture coordinates, clamped to nothing past the art, so the body's edges
--     cut it and it needs no clipping frame. It starts past the body's first corner and ends past its last, over Time.
--   Glow: the whole pane lit faintly as the band crosses, most at its middle.
--   The panel fades in over Open.Reveal (the panel's part of the open) and out over Close.Fade (of the close); the panel
--     fades its glass's tint with it (NextGlass:SetPresence). The run lingers on its own layer after the panel's part,
--     until the band has crossed (Linger). A theme without Panel.Sheen has none.
---@class NextSheen: AceModule
local sheen = addon:NewModule('NextSheen')

-- The keys of Panel.Sheen and of its parts, for SonataNext:Check.
sheen.KEYS = { Band = true, Glow = true, Open = true, Close = true }
sheen.BAND_KEYS = { Texture = true, Color = true, Alpha = true, BlendMode = true, Width = true, Angle = true }
sheen.GLOW_KEYS = { Color = true, Alpha = true, BlendMode = true }
sheen.OPEN_KEYS = { Time = true, Reveal = true }
sheen.CLOSE_KEYS = { Time = true, Fade = true }

---@class NextSheenRun
---@field panel table Whose it is.
---@field strength number How strongly its band and glow are drawn, 0 to 1.
---@field spec table The theme's Panel.Sheen it began with.
---@field timing table Its phase's: Panel.Sheen.Open or Close.
---@field phase string "Open" or "Close".
---@field band Texture
---@field glow? Texture
---@field ds number[] How far along the band's way each corner of the body is from its middle: UL, LL, UR, LR.
---@field low number The nearest corner's.
---@field high number The farthest's.
---@field width number The band's, on the layer.
---@field clear number When the band has crossed.
---@field elapsed number How long it has lived, while it lingers.
local runProto = {}
addon:GetModule('Perf'):RegisterPrototype(runProto, 'NextSheenRun')

function sheen:Init()
  for run in pairs(self.living or {}) do
    run:Release()
  end
  self.living = {}
  self.pool = self.pool or {}
  if self.layer ~= nil then
    self.layer.driver:SetScript("OnUpdate", nil)
  end
end

-- Spec returns the theme's Panel.Sheen, nil without one.
---@return table?
function sheen:Spec()
  return style.Theme.Panel.Sheen or nil
end

-- Opens says whether the theme's panels catch the light as they open instead of sliding in.
---@return boolean
function sheen:Opens()
  local S = self:Spec()
  return S ~= nil and S.Open ~= nil
end

-- Closes says whether the theme's panels catch the light as they close instead of sliding out.
---@return boolean
function sheen:Closes()
  local S = self:Spec()
  return S ~= nil and S.Close ~= nil
end

-- OpenLock is when the panel has faded in (its threads draw in and its sections cascade from then); OpenTime the
-- panel's part of the open, the same (it says it has shown); CloseTime the panel's part of the close, until it has faded
-- out. The band crosses on after both, over its phase's Time.
---@return number
function sheen:OpenLock()
  return self:Spec().Open.Reveal
end

---@return number
function sheen:OpenTime()
  return self:OpenLock()
end

---@return number
function sheen:CloseTime()
  return self:Spec().Close.Fade
end

-- unsmooth is the x in 0 to 1 whose smoothstep is y.
---@param y number
---@return number
local function unsmooth(y)
  if y <= 0 then
    return 0
  elseif y >= 1 then
    return 1
  end
  return 0.5 - math.sin(math.asin(1 - 2 * y) / 3)
end

-- OpenAt is how far into an open a panel at an alpha is, and CloseAt how far into a close: a panel turned back part way
-- (closed as it opened, opened again as it closed) goes on from where it is (found in review: it jumped to full, or to
-- nothing, and faded from there).
---@param alpha number
---@return number
function sheen:OpenAt(alpha)
  return self:Spec().Open.Reveal * unsmooth(alpha)
end

---@param alpha number
---@return number
function sheen:CloseAt(alpha)
  return self:Spec().Close.Fade * unsmooth(1 - alpha)
end

-- Layer returns the sheen layer, made the first time: a frame over the whole screen, in the DIALOG strata (above the
-- panels, HIGH), taking no mouse, with the driver that lets a band cross on after the panel's part.
---@return Frame
function sheen:Layer()
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

---@param e0 number
---@param e1 number
---@param x number
---@return number
local function smoothstep(e0, e1, x)
  local t = math.max(0, math.min(1, (x - e0) / (e1 - e0)))
  return t * t * (3 - 2 * t)
end

-- texture takes a texture from the pool, or makes one on the layer, drawn without the client's sharpening
-- (texture-sharpening.md), unseen, hung from the layer over a rect (its top left, y up).
---@param sublevel number
---@param left number
---@param top number
---@param width number
---@param height number
---@return Texture
local function texture(sublevel, left, top, width, height)
  local t = table.remove(sheen.pool)
  if t == nil then
    t = sheen:Layer():CreateTexture(nil, "ARTWORK", nil, sublevel)
    t:SetSnapToPixelGrid(false)
    t:SetTexelSnappingBias(0)
  end
  t:SetDrawLayer("ARTWORK", sublevel)
  t:SetTexCoord(0, 1, 0, 1)
  t:ClearAllPoints()
  t:SetPoint("TOPLEFT", sheen:Layer(), "BOTTOMLEFT", left, top)
  t:SetSize(width, height)
  t:Hide()
  return t
end

-- Begin readies a panel's run on the sheen layer, unseen until it draws: its phase ("Open" or "Close") over its body
-- where its BodyRect puts it on the screen, the band's way from the panel's inner side out (back again as it closes). A
-- band the panel's last run still has crossing goes at once (found in review: a bag closed as its open's band crossed
-- showed two, going opposite ways). Its band and glow are drawn at strength (1 unless said: a close from a bag barely
-- shown draws them that faintly).
---@param panel table
---@param phase string
---@param strength? number 0 to 1.
---@return NextSheenRun
function sheen:Begin(panel, phase, strength)
  for other in pairs(self.living) do
    if other.panel == panel then
      other:Release()
    end
  end
  local S = self:Spec()
  local B = S.Band
  local left, top, height, width, scale = panel:BodyRect()
  scale = scale or 1
  local O = S[phase]
  local a = math.rad(B.Angle or 0)
  -- A panel on the right of the screen has its inner side on the left.
  local out = panel.side == "LEFT" and -1 or 1
  local dx, dy = out * math.cos(a), -math.sin(a)
  if phase == "Close" then
    dx, dy = -dx, -dy
  end
  local cx, cy = left + width / 2, top - height / 2
  local function along(x, y)
    return (x - cx) * dx + (y - cy) * dy
  end
  local ds = { along(left, top), along(left, top - height), along(left + width, top), along(left + width, top - height) }
  ---@type NextSheenRun
  local run = setmetatable({ panel = panel, strength = strength or 1, spec = S, timing = O, phase = phase, ds = ds,
    low = math.min(unpack(ds)), high = math.max(unpack(ds)), width = (B.Width or 1) * scale, clear = O.Time,
    elapsed = 0 }, { __index = runProto })
  local r, g, b = style:RGBA(B.Color or "White")
  run.band = texture(1, left, top, width, height)
  run.band:SetTexture(style:TexturePath(B.Texture), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  run.band:SetBlendMode(B.BlendMode or "ADD")
  run.band:SetVertexColor(r, g, b)
  local G = S.Glow
  if G ~= nil then
    local gr, gg, gb = style:RGBA(G.Color or "White")
    run.glow = texture(0, left, top, width, height)
    run.glow:SetColorTexture(1, 1, 1, 1)
    run.glow:SetBlendMode(G.BlendMode or "ADD")
    run.glow:SetVertexColor(gr, gg, gb)
  end
  return run
end

-- Draw draws the run t seconds into its phase, and returns the panel's alpha: an open's, faded in over its Reveal; a
-- close's, faded out over its Fade.
---@param t number
---@return number alpha The panel's.
function runProto:Draw(t)
  local S, O = self.spec, self.timing
  local p = math.max(0, math.min(1, t / O.Time))
  if p >= 1 then
    self.band:Hide()
    if self.glow then self.glow:Hide() end
  else
    local w = self.width
    local s = self.low - w / 2 + smoothstep(0, 1, p) * (self.high - self.low + w)
    local ds = self.ds
    self.band:SetTexCoord((ds[1] - s) / w + 0.5, 0, (ds[2] - s) / w + 0.5, 1, (ds[3] - s) / w + 0.5, 0,
      (ds[4] - s) / w + 0.5, 1)
    self.band:SetAlpha((S.Band.Alpha or 1) * self.strength)
    self.band:Show()
    if self.glow then
      self.glow:SetAlpha((S.Glow.Alpha or 0) * self.strength * math.sin(math.pi * p))
      self.glow:Show()
    end
  end
  if self.phase == "Open" then
    return smoothstep(0, O.Reveal, t)
  end
  return 1 - smoothstep(0, O.Fade, t)
end

-- Linger lets the run live on by itself on the sheen layer's driver from t seconds into it (the panel's part is done),
-- until the band has crossed.
---@param t number
function runProto:Linger(t)
  self.elapsed = t
  sheen.living[self] = true
  local driver = sheen:Layer().driver
  if driver:GetScript("OnUpdate") == nil then
    driver:SetScript("OnUpdate", function(_, elapsed)
      sheen:Step(elapsed)
    end)
  end
end

-- Step lives every lingering run on elapsed seconds, giving back those whose band has crossed, and stops the driver when
-- none is left.
---@param elapsed number
function sheen:Step(elapsed)
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

-- Release gives the run's textures back, hidden, at once; a run released again does nothing.
function runProto:Release()
  sheen.living[self] = nil
  for _, key in ipairs({ "band", "glow" }) do
    local t = self[key]
    if t ~= nil then
      t:Hide()
      t:ClearAllPoints()
      table.insert(sheen.pool, t)
      self[key] = nil
    end
  end
end
