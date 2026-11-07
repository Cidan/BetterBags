local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

-- NextGlass draws a Next theme's body as a pane of glass (Panel.Glass, next-themes-glass.md §26; the Rainy Window
-- theme; asked: "that rainy glass pane was... chefs kiss", then of a bag's clarity, smoked glass whose tint the player
-- sets). Glass has no shader: it is blend modes, alpha and a light worked out in Lua.
--   Tint: a MOD texture over the fill multiplies the world behind by the smoke's color (it darkens, never brightens, so
--     nothing bright behind the bag washes its items out), Strength of the way from clear to the smoke (the player's
--     Glass Tint); a Veil BLENDed over it scatters light, lifting the dark and flattening detail behind the glass.
--   Grain: the glass's texture, tiled over it.
--   Reflections: bands of reflected light across the body, their art repeating along texture coordinates turned to
--     Angle, so the body's own rect cuts them; they hold Parallax of the way still on the screen as the bag moves
--     (moving only 1 - Parallax of the way with it), the glass sliding under them, as a room's reflection does in a
--     window.
--   Lamp: the pointer is a lamp. A soft light on the body under it (its art's coordinates centred there, clamped to
--     nothing past the art's edge, so it is cut at the body's edges too), glints along the body's edges near it (Rim),
--     and each drop's highlight on the side toward it and the light it focuses on the far side (the sky above, without
--     it). Reach is how far it lights.
--   Rain: drops on the body behind the content (Density of them to every 100 x 100 units), beading up one after another
--     as the panel shows (each somewhere in Appear), a few Runners swelling, then running down in fits, a slide and a
--     catch, leaving beads behind that dry; none starts again in combat.
--   Presence: a panel fading in or out (NextSheen) fades its tint's strength with it (SetPresence), so the smoke fades
--     with the panel whatever the client does with a MOD texture's alpha.
--   Lightning: now and then (Every), a flash over the body over Time, lighting its drops and edges; none in combat.
-- Everything is the panel frame's own textures, under its tabs and content. It moves only while the panel shows (its
-- driver is a child of the panel's frame).
---@class NextGlass: AceModule
local glass = addon:NewModule('NextGlass')

-- Where the glass takes its randomness (a source of numbers in [0, 1)): replaced by the specs.
glass.Random = math.random

-- The keys of Panel.Glass and of each of its parts, for SonataNext:Check.
glass.KEYS = { Tint = true, Grain = true, Reflections = true, Lamp = true, Rim = true, Rain = true, Lightning = true }
glass.TINT_KEYS = { Color = true, Strength = true, Veil = true }
glass.VEIL_KEYS = { Color = true, Alpha = true }
glass.GRAIN_KEYS = { Texture = true, Color = true, Alpha = true, BlendMode = true, Size = true }
glass.REFLECTION_KEYS = { Texture = true, Color = true, Alpha = true, BlendMode = true, Angle = true, Period = true,
  Parallax = true }
glass.LAMP_KEYS = { Texture = true, Color = true, Alpha = true, BlendMode = true, Size = true, Reach = true }
glass.RIM_KEYS = { Color = true, Alpha = true, Size = true, Piece = true }
glass.RAIN_KEYS = { Texture = true, Color = true, Alpha = true, Density = true, Size = true, Appear = true,
  Highlight = true, Caustic = true, Runners = true }

-- How long a drop takes to bead up once its turn comes (Rain.Appear).
local BEAD_TIME = 0.3
glass.SHINE_KEYS = { Texture = true, Color = true, Alpha = true, BlendMode = true }
glass.RUNNER_KEYS = { Count = true, Size = true, Speed = true, Wait = true, Slide = true, Catch = true, Every = true,
  Beads = true, BeadSize = true, BeadLife = true }
glass.LIGHTNING_KEYS = { Every = true, Time = true, Color = true, Alpha = true }

-- Every panel's glass, so a new tint reaches them all at once (Retint).
glass.sets = setmetatable({}, { __mode = "k" })

-- The textures over the whole body or fill, made once with the panel.
local SURFACES = { "tint", "veil", "grain", "reflections", "lamp", "flash" }

---@class (exact) NextGlassDrop
---@field body Texture
---@field highlight Texture
---@field caustic Texture
---@field x number Its middle, from the panel's top left.
---@field y number Down from the panel's top.
---@field size number Across.
---@field scale number Of its size it shows (a runner swells).
---@field fade number 0 to 1.
---@field life number A bead's seconds left (0: none).
---@field max? number A bead's whole life.
---@field wait? number A runner's seconds still swelling.
---@field vy? number A runner's speed down.
---@field run? number A runner's seconds left sliding, or caught.
---@field lastBead? number Where a runner last left a bead.
---@field dormant? boolean A runner gone off the bottom in combat, waiting to start again.

---@class (exact) NextGlassRim
---@field texture Texture
---@field x number Its middle, from the panel's top left.
---@field y number
---@field nx number The way the edge faces, y down.
---@field ny number

---@class NextGlassSet
---@field panel table The panel: its frame, body, fill, BodyLeft and BodyWidth.
---@field driver Frame
---@field onUpdate fun(frame: Frame, elapsed: number)
---@field tint Texture
---@field veil Texture
---@field grain Texture
---@field reflections Texture
---@field lamp Texture
---@field flash Texture
---@field rims NextGlassRim[]
---@field drops NextGlassDrop[] Still on the glass.
---@field runners NextGlassDrop[]
---@field beads NextGlassDrop[]
---@field nextBead number
---@field pool Texture[]
---@field running boolean
---@field px? number The pointer, from the panel's top left (nil: not known).
---@field py? number
---@field near boolean The pointer was near enough to light anything.
---@field left? number The frame's left and top the reflections were laid for.
---@field top? number
---@field bright number The lightning's flash now, 0 to 1.
---@field strike? {t: number} A flash under way.
---@field untilStrike? number
local setProto = {}
addon:GetModule('Perf'):RegisterPrototype(setProto, 'NextGlassSet')

---@param v number
---@param lo number
---@param hi number
---@return number
local function clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

---@param range number[]
---@return number
local function between(range)
  return range[1] + (range[2] - range[1]) * glass.Random()
end

-- Spec returns the theme's Panel.Glass, nil without one.
---@return table?
function glass:Spec()
  return style.Theme.Panel.Glass or nil
end

-- Tint returns the theme's glass at its strength: the color the tint multiplies the world by, and the veil's color and
-- alpha. Clear (white, no veil) without one.
---@return number r, number g, number b, number vr, number vg, number vb, number va
function glass:Tint()
  local G = self:Spec()
  local T = G and G.Tint
  if not T then
    return 1, 1, 1, 1, 1, 1, 0
  end
  local s = clamp(T.Strength or 0, 0, 1)
  local r, g, b = style:RGBA(T.Color or "White")
  local vr, vg, vb, va = 1, 1, 1, 0
  if T.Veil then
    vr, vg, vb = style:RGBA(T.Veil.Color or "White")
    va = (T.Veil.Alpha or 0) * s
  end
  return 1 - s * (1 - r), 1 - s * (1 - g), 1 - s * (1 - b), vr, vg, vb, va
end

-- Retint draws every panel's tint again: the player changed its strength.
function glass:Retint()
  for set in pairs(self.sets) do
    set:paintTint()
  end
end

---@param frame Frame
---@param anchor ScriptRegion
---@param layer string
---@param sublevel number
---@return Texture
local function surface(frame, anchor, layer, sublevel)
  local t = frame:CreateTexture(nil, layer, nil, sublevel)
  t:SetAllPoints(anchor)
  t:Hide()
  return t
end

-- Create gives a panel its glass, none until styled (Style).
---@param panel table
---@return NextGlassSet
function glass:Create(panel)
  local frame = panel.frame
  local set = setmetatable({ panel = panel, rims = {}, drops = {}, runners = {}, beads = {}, nextBead = 1, pool = {},
    running = false, near = false, bright = 0, presence = 1, beading = false }, { __index = setProto })
  set.tint = surface(frame, panel.fill, "BACKGROUND", 1)
  set.tint:SetColorTexture(1, 1, 1, 1)
  set.veil = surface(frame, panel.fill, "BACKGROUND", 2)
  set.veil:SetColorTexture(1, 1, 1, 1)
  set.grain = surface(frame, panel.fill, "BACKGROUND", 3)
  set.reflections = surface(frame, panel.body, "BORDER", 2)
  set.lamp = surface(frame, panel.body, "BORDER", 2)
  set.flash = surface(frame, panel.body, "BORDER", 5)
  set.flash:SetColorTexture(1, 1, 1, 1)
  set.driver = CreateFrame("Frame", nil, frame)
  set.onUpdate = function(_, elapsed)
    set:Step(elapsed)
  end
  self.sets[set] = true
  return set
end

-- area returns the body on the panel's frame: its left, width and height.
---@private
---@return number left, number width, number height
function setProto:area()
  local panel = self.panel
  return panel:BodyLeft(), panel:BodyWidth(), panel.frame:GetHeight()
end

---@private
---@return Texture
function setProto:texture(layer, sublevel)
  local t = table.remove(self.pool)
  if t == nil then
    t = self.panel.frame:CreateTexture(nil, layer, nil, sublevel)
    t:SetSnapToPixelGrid(false)
    t:SetTexelSnappingBias(0)
  end
  t:SetDrawLayer(layer, sublevel)
  t:SetTexCoord(0, 1, 0, 1)
  return t
end

---@private
---@param t Texture
function setProto:release(t)
  t:Hide()
  t:ClearAllPoints()
  table.insert(self.pool, t)
end

-- paintArt draws a surface from a part of the theme's glass (its texture loaded with a wrap mode, its color, blend mode
-- and alpha), or hides it without one.
---@param t Texture
---@param spec? table
---@param wrap string
---@param alpha? number
local function paintArt(t, spec, wrap, alpha)
  if not spec then
    t:Hide()
    return
  end
  local r, g, b = style:RGBA(spec.Color or "White")
  t:SetTexture(style:TexturePath(spec.Texture), wrap, wrap)
  t:SetBlendMode(spec.BlendMode or "ADD")
  t:SetVertexColor(r, g, b)
  t:SetAlpha(alpha or spec.Alpha or 1)
  t:Show()
end

-- paintTint draws the tint and the veil at the theme's strength (Tint), or hides them for glass without a tint.
function setProto:paintTint()
  local G = glass:Spec()
  if not (G and G.Tint) then
    self.tint:Hide()
    self.veil:Hide()
    return
  end
  local r, g, b, vr, vg, vb, va = glass:Tint()
  local p = self.presence
  self.tint:SetBlendMode("MOD")
  self.tint:SetVertexColor(1 - p * (1 - r), 1 - p * (1 - g), 1 - p * (1 - b))
  self.tint:SetAlpha(1)
  self.tint:Show()
  self.veil:SetBlendMode("BLEND")
  self.veil:SetVertexColor(vr, vg, vb)
  self.veil:SetAlpha(va * p)
  self.veil:Show()
end

-- SetPresence fades the tint and veil with the panel, 0 to 1 (NextSheen's open and close; 1 at rest).
---@param presence number
function setProto:SetPresence(presence)
  self.presence = presence
  self:paintTint()
end

-- clear gives back every rim piece and drop.
---@private
function setProto:clear()
  for _, piece in ipairs(self.rims) do
    self:release(piece.texture)
  end
  for _, list in ipairs({ self.drops, self.runners, self.beads }) do
    for _, d in ipairs(list) do
      self:release(d.body)
      self:release(d.highlight)
      self:release(d.caustic)
    end
  end
  self.rims, self.drops, self.runners, self.beads, self.nextBead = {}, {}, {}, {}, 1
end

---@private
---@param t Texture
---@param spec table
---@param blend string
local function paintDropPart(t, spec, blend)
  local r, g, b = style:RGBA(spec.Color or "White")
  t:SetTexture(style:TexturePath(spec.Texture))
  t:SetBlendMode(spec.BlendMode or blend)
  t:SetVertexColor(r, g, b)
  t:SetAlpha(0)
end

-- newDrop makes a drop's three textures: its body, its highlight and the light it focuses (its caustic), unseen until
-- drawn.
---@private
---@return NextGlassDrop
function setProto:newDrop()
  local R = glass:Spec().Rain
  local d = { body = self:texture("BORDER", 3), highlight = self:texture("BORDER", 3),
    caustic = self:texture("BORDER", 3), x = 0, y = 0, size = 1, scale = 1, fade = 1, life = 0 }
  paintDropPart(d.body, R, "BLEND")
  paintDropPart(d.highlight, R.Highlight or { Texture = "Glow" }, "ADD")
  paintDropPart(d.caustic, R.Caustic or { Texture = "Glow" }, "ADD")
  return d
end

---@param d NextGlassDrop
---@param shown boolean
local function showDrop(d, shown)
  d.body:SetShown(shown)
  d.highlight:SetShown(shown)
  d.caustic:SetShown(shown)
end

-- Style takes the theme's glass: its tint, grain, reflections, lamp and flash, its rim and its rain made again for it,
-- laid out (Layout). Moving while the panel showed, it moves on (Start).
function setProto:Style()
  local running = self.running
  self:Stop()
  self:clear()
  local G = glass:Spec()
  if not G then
    for _, key in ipairs(SURFACES) do
      self[key]:Hide()
    end
    -- Still showing: nothing moves (no driver without glass), but a theme with glass applied again moves at once.
    if running then
      self:Start()
    end
    return
  end
  self:paintTint()
  paintArt(self.grain, G.Grain, "REPEAT")
  paintArt(self.reflections, G.Reflections, "REPEAT")
  paintArt(self.lamp, G.Lamp, "CLAMPTOBLACKADDITIVE", 0)
  local L = G.Lightning
  if L then
    local r, g, b = style:RGBA(L.Color or "White")
    self.flash:SetBlendMode("ADD")
    self.flash:SetVertexColor(r, g, b)
    self.flash:SetAlpha(0)
    self.flash:Show()
  else
    self.flash:Hide()
  end
  local R = G.Rain
  if R then
    local U = R.Runners
    for _ = 1, U and U.Count or 0 do
      table.insert(self.runners, self:newDrop())
    end
    for _ = 1, U and U.Beads or 0 do
      local b = self:newDrop()
      b.life = 0
      table.insert(self.beads, b)
    end
  end
  self:Layout(true)
  if running then
    self:Start()
  end
end

-- Layout lays the glass out for the panel's size: its grain's tiles, its reflections, its rim, as many drops as its
-- body holds (counted here: a panel styles its glass as it is built, before it has a size), kept on the body (scattered
-- anew with scatter, a new style; else only those now off it), and every light drawn again.
---@param scatter? boolean
function setProto:Layout(scatter)
  local G = glass:Spec()
  if not G then
    return
  end
  local left, width, height = self:area()
  self.laid = { left, width, height }
  if G.Grain then
    local size = G.Grain.Size or 256
    self.grain:SetTexCoord(0, width / size, 0, height / size)
  end
  self:placeReflections()
  self:layoutRims()
  local R = G.Rain
  local count = R and math.max(0, math.floor((R.Density or 0) * width * height / 10000 + 0.5)) or 0
  while #self.drops > count do
    local d = table.remove(self.drops)
    self:release(d.body)
    self:release(d.highlight)
    self:release(d.caustic)
  end
  -- Drops made for a body that grows while the glass shows bead up in their own turn (Rain.Appear), as those it showed
  -- with did (found in review: they came in at full).
  local A = R and R.Appear
  while #self.drops < count do
    local d = self:newDrop()
    -- Small drops far more often than large.
    d.size = R.Size[1] + (R.Size[2] - R.Size[1]) * glass.Random() ^ 2
    d.x, d.y = left + width * glass.Random(), height * glass.Random()
    if self.running and A then
      d.appear, d.scale, d.fade = between(A), 0.3, 0
      self.beading = true
    end
    table.insert(self.drops, d)
  end
  for _, d in ipairs(self.drops) do
    if scatter or d.x < left or d.x > left + width or d.y > height then
      d.x = left + width * glass.Random()
      d.y = height * glass.Random()
    end
    showDrop(d, true)
  end
  -- What a smaller body leaves outside it: runners start again on it, drawn there at once, or in combat wait unseen as at
  -- the body's foot; beads dry at once (found in review: left drawn over the world for the rest of their wait or life;
  -- and in the third, started again in combat and drawn where they had been).
  local combat = InCombatLockdown()
  for _, d in ipairs(self.runners) do
    if not d.dormant and (d.x < left or d.x > left + width or d.y + d.size * d.scale / 2 > height) then
      if combat then
        d.dormant = true
        showDrop(d, false)
      else
        self:launch(d)
        self:drawDrop(d)
      end
    end
  end
  for _, b in ipairs(self.beads) do
    if b.life > 0 and (b.x < left or b.x > left + width or b.y + b.size / 2 > height) then
      b.life = 0
      showDrop(b, false)
    end
  end
  self:relight()
end

-- resized says whether the body is another size, or somewhere else on the frame, than the glass was last laid out for: a
-- small panel sized by a grip, fitted or snapped, none of which lays the panel's geometry out again (found in review).
---@private
---@return boolean
function setProto:resized()
  local laid = self.laid
  if laid == nil then
    return true
  end
  local left, width, height = self:area()
  return left ~= laid[1] or width ~= laid[2] or height ~= laid[3]
end

-- placeReflections turns the reflections' art across the body to the theme's Angle, its bands repeating every Period,
-- moved by Parallax of where the panel is on the screen.
---@private
function setProto:placeReflections()
  local G = glass:Spec()
  local F = G and G.Reflections
  local frame = self.panel.frame
  self.left, self.top = frame:GetLeft(), frame:GetTop()
  if not F then
    return
  end
  local left, width, height = self:area()
  local a = math.rad(F.Angle or 0)
  local nx, ny, tx, ty = -math.sin(a), math.cos(a), math.cos(a), math.sin(a)
  local shift = (F.Parallax or 0) * ((self.left or 0) * nx + (self.top or 0) * ny)
  local period = F.Period
  local function uv(x, y)
    return (x * nx + y * ny + shift) / period, (x * tx + y * ty) / period
  end
  local ulu, ulv = uv(left, 0)
  local llu, llv = uv(left, -height)
  local uru, urv = uv(left + width, 0)
  local lru, lrv = uv(left + width, -height)
  self.reflections:SetTexCoord(ulu, ulv, llu, llv, uru, urv, lru, lrv)
end

-- layoutRims cuts the body's edges into pieces about Piece long, each a strip Size thick inside the edge, on whole pixels
-- of the panel's grid (next-pixel-perfect.md): every piece ends where the next begins.
---@private
function setProto:layoutRims()
  for _, piece in ipairs(self.rims) do
    self:release(piece.texture)
  end
  self.rims = {}
  local R = glass:Spec().Rim
  if not R then
    return
  end
  local left, width, height = self:area()
  local frame = self.panel.frame
  local size = pixel:Length(frame, R.Size or 1)
  local function snap(v)
    return pixel:Snap(frame, v)
  end
  local r, g, b = style:RGBA(R.Color or "White")
  local function add(x, y, w, h, nx, ny)
    local t = self:texture("BORDER", 4)
    t:SetColorTexture(1, 1, 1, 1)
    t:SetBlendMode("ADD")
    t:SetVertexColor(r, g, b)
    t:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
    t:SetSize(w, h)
    t:Show()
    table.insert(self.rims, { texture = t, x = x + w / 2, y = y + h / 2, nx = nx, ny = ny })
  end
  local across = math.max(1, math.floor(width / R.Piece + 0.5))
  local down = math.max(1, math.floor(height / R.Piece + 0.5))
  local bottom, right = snap(height) - size, snap(left + width) - size
  for i = 1, across do
    local x1, x2 = snap(left + width * (i - 1) / across), snap(left + width * i / across)
    if x2 > x1 then
      add(x1, 0, x2 - x1, size, 0, -1)
      add(x1, bottom, x2 - x1, size, 0, 1)
    end
  end
  for i = 1, down do
    local y1, y2 = snap(height * (i - 1) / down), snap(height * i / down)
    if y2 > y1 then
      add(snap(left), y1, size, y2 - y1, -1, 0)
      add(right, y1, size, y2 - y1, 1, 0)
    end
  end
end

-- lampAt is how strongly the pointer lights a place on the panel's frame, 0 to 1.
---@private
---@param x number
---@param y number
---@return number
function setProto:lampAt(x, y)
  local L = glass:Spec().Lamp
  if not L or self.px == nil then
    return 0
  end
  local dx, dy = x - self.px, y - self.py
  return math.exp(-(dx * dx + dy * dy) / (L.Reach * L.Reach))
end

-- readPointer reads where the pointer is on the panel's frame, and says whether it moved.
---@private
---@return boolean
function setProto:readPointer()
  local frame = self.panel.frame
  local left, top = frame:GetLeft(), frame:GetTop()
  local px, py
  if left ~= nil and top ~= nil then
    local scale = frame:GetEffectiveScale()
    local x, y = GetCursorPosition()
    px, py = x / scale - left, top - y / scale
  end
  local moved = px ~= self.px or py ~= self.py
  self.px, self.py = px, py
  return moved
end

-- nearBody says whether the pointer is near enough to the body to light any of it.
---@private
---@return boolean
function setProto:nearBody()
  local L = glass:Spec().Lamp
  if not L or self.px == nil then
    return false
  end
  local left, width, height = self:area()
  local dx = math.max(0, left - self.px, self.px - left - width)
  local dy = math.max(0, -self.py, self.py - height)
  return dx * dx + dy * dy < (3 * L.Reach) ^ 2
end

-- drawLamp centres the lamp's light on the pointer: its art's coordinates over the body, so it is cut at the body's edges,
-- fading out as the pointer goes off it, gone at Reach away.
---@private
function setProto:drawLamp()
  local L = glass:Spec().Lamp
  if not L then
    return
  end
  if self.px == nil then
    self.lamp:SetAlpha(0)
    return
  end
  local left, width, height = self:area()
  local rx, ry = self.px - left, self.py
  local size = L.Size
  self.lamp:SetTexCoord((size / 2 - rx) / size, (width + size / 2 - rx) / size, (size / 2 - ry) / size,
    (height + size / 2 - ry) / size)
  local dx = math.max(0, -rx, rx - width)
  local dy = math.max(0, -ry, ry - height)
  local away = math.sqrt(dx * dx + dy * dy)
  self.lamp:SetAlpha((L.Alpha or 1) * clamp(1 - away / L.Reach, 0, 1))
end

-- shadeRims lights each piece of the rim by the lamp (squarer to it, brighter) and the lightning.
---@private
function setProto:shadeRims()
  local R = glass:Spec().Rim
  if not R then
    return
  end
  local low, high = R.Alpha[1], R.Alpha[2]
  for _, piece in ipairs(self.rims) do
    local light = 0
    local lamp = self:lampAt(piece.x, piece.y)
    if lamp > 0 then
      local dx, dy = self.px - piece.x, self.py - piece.y
      local d = math.sqrt(dx * dx + dy * dy)
      local facing = d < 1 and 1 or 0.6 + 0.4 * math.max(0, (dx * piece.nx + dy * piece.ny) / d)
      light = lamp * facing
    end
    piece.texture:SetAlpha(low + (high - low) * clamp(light + self.bright, 0, 1))
  end
end

-- drawDrop places a drop and lights it: its highlight on the side toward the light (the lamp, else the sky above), the
-- light it focuses on the far side, both brighter with the lamp close or the lightning.
---@private
---@param d NextGlassDrop
function setProto:drawDrop(d)
  local R = glass:Spec().Rain
  local frame = self.panel.frame
  local size = d.size * (d.scale or 1)
  local lamp = self:lampAt(d.x, d.y)
  local lx, ly = 0, -(1 - lamp)
  if lamp > 0 then
    local dx, dy = self.px - d.x, self.py - d.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > 0 then
      lx, ly = lx + dx / dist * lamp, ly + dy / dist * lamp
    end
  end
  local len = math.sqrt(lx * lx + ly * ly)
  if len > 0 then
    lx, ly = lx / len, ly / len
  else
    lx, ly = 0, -1
  end
  local strength = clamp(0.35 + 0.65 * lamp + self.bright, 0, 1)
  local H = R.Highlight or {}
  local C = R.Caustic or {}
  d.body:SetPoint("CENTER", frame, "TOPLEFT", d.x, -d.y)
  d.body:SetSize(size, size)
  d.body:SetAlpha((R.Alpha or 1) * d.fade)
  d.highlight:SetPoint("CENTER", frame, "TOPLEFT", d.x + lx * 0.22 * size, -(d.y + ly * 0.22 * size))
  d.highlight:SetSize(0.55 * size, 0.55 * size)
  d.highlight:SetAlpha((H.Alpha or 1) * strength * d.fade)
  d.caustic:SetPoint("CENTER", frame, "TOPLEFT", d.x - lx * 0.24 * size, -(d.y - ly * 0.24 * size))
  d.caustic:SetSize(0.65 * size, 0.65 * size)
  d.caustic:SetAlpha((C.Alpha or 1) * strength * d.fade)
end

-- relight draws everything the light falls on again: the lamp, the rim, the drops still on the glass.
---@private
function setProto:relight()
  self.near = self:nearBody()
  self:drawLamp()
  self:shadeRims()
  for _, d in ipairs(self.drops) do
    self:drawDrop(d)
  end
end

-- launch starts a runner swelling somewhere in the upper half of the body, unseen at first.
---@private
---@param d NextGlassDrop
function setProto:launch(d)
  local U = glass:Spec().Rain.Runners
  local left, width, height = self:area()
  d.x = left + width * glass.Random()
  d.y = height * (0.1 + 0.4 * glass.Random())
  d.size = between(U.Size)
  d.scale = 0.6
  d.wait = between(U.Wait)
  d.swell, d.fade = 0, 0
  d.vy, d.run = 0, 0
  d.lastBead = d.y
  d.dormant = false
  showDrop(d, true)
end

-- bead leaves a small drop behind a runner, drying over its life; none that would lie past the body's foot.
---@private
---@param d NextGlassDrop
function setProto:bead(d)
  local b = self.beads[self.nextBead]
  if b == nil then
    return
  end
  local U = glass:Spec().Rain.Runners
  local size = between(U.BeadSize)
  local y = d.y - d.size * d.scale * 0.45
  local _, _, height = self:area()
  if y + size / 2 > height then
    return
  end
  self.nextBead = self.nextBead % #self.beads + 1
  b.x, b.y = d.x, y
  b.size, b.scale, b.fade = size, 1, 1
  b.life = between(U.BeadLife)
  b.max = b.life
  showDrop(b, true)
  self:drawDrop(b)
end

-- runDrop moves a runner on: swelling into sight (while it waits, and on as it runs if its wait was short), then
-- sliding and catching in turn, a bead left every Every units; fading out as its foot nears the body's, where it starts
-- again (found in review: a small bag's runners slid on out below it), unless in combat (then it waits, unseen, until
-- combat ends).
---@private
---@param d NextGlassDrop
---@param elapsed number
---@param combat boolean
function setProto:runDrop(d, elapsed, combat)
  local U = glass:Spec().Rain.Runners
  if d.dormant then
    if not combat then
      self:launch(d)
      self:drawDrop(d)
    end
    return
  end
  d.swell = math.min(1, (d.swell or 1) + elapsed * 1.5)
  d.scale = math.min(1, d.scale + elapsed * 0.4)
  if d.wait > 0 then
    d.wait = d.wait - elapsed
    d.fade = d.swell
    self:drawDrop(d)
    return
  end
  d.run = d.run - elapsed
  if d.run <= 0 then
    if d.vy > 0 then
      d.vy, d.run = 0, between(U.Catch)
    else
      d.vy, d.run = between(U.Speed), between(U.Slide)
    end
  end
  if d.vy > 0 then
    d.y = d.y + d.vy * elapsed
    d.x = d.x + (glass.Random() - 0.5) * 0.15 * d.vy * elapsed
    if d.y - d.lastBead >= (U.Every or 10) - 1e-9 then
      self:bead(d)
      d.lastBead = d.y
    end
  end
  local _, _, height = self:area()
  local foot = height - d.y - d.size * d.scale / 2
  if foot <= 0 then
    if combat then
      d.dormant = true
      showDrop(d, false)
      return
    end
    self:launch(d)
  else
    d.fade = d.swell * clamp(foot / d.size, 0, 1)
  end
  self:drawDrop(d)
end

-- beadUp lets each drop still to bead up wait out its turn, then grow and fade in over BEAD_TIME; done once all have.
---@private
---@param elapsed number
function setProto:beadUp(elapsed)
  local waiting = false
  for _, d in ipairs(self.drops) do
    if d.appear ~= nil then
      d.appear = d.appear - elapsed
      local k = clamp(-d.appear / BEAD_TIME, 0, 1)
      d.scale, d.fade = 0.3 + 0.7 * k, k
      if k >= 1 then
        d.appear = nil
      else
        waiting = true
      end
      self:drawDrop(d)
    end
  end
  self.beading = waiting
end

-- dry lets each bead dry on: fading over the last 40% of its life, then gone.
---@private
---@param elapsed number
function setProto:dry(elapsed)
  for _, b in ipairs(self.beads) do
    if b.life > 0 then
      b.life = b.life - elapsed
      if b.life <= 0 then
        b.life = 0
        b.body:SetAlpha(0)
        b.highlight:SetAlpha(0)
        b.caustic:SetAlpha(0)
        showDrop(b, false)
      else
        b.fade = math.min(1, b.life / (0.4 * b.max))
        self:drawDrop(b)
      end
    end
  end
end

-- envelope is a flash p of the way through it: a bright strike, then a weaker one.
---@param p number
---@return number
local function envelope(p)
  local function bump(a, b)
    if p <= a or p >= b then
      return 0
    end
    return math.sin(math.pi * (p - a) / (b - a))
  end
  return math.max(bump(0, 0.35), 0.6 * bump(0.5, 0.9))
end

-- strikeOn lets a flash run on, and strikes when the next is due (none in combat: it is due again Every later).
---@private
---@param elapsed number
---@param combat boolean
function setProto:strikeOn(elapsed, combat)
  local L = glass:Spec().Lightning
  if not L then
    self.bright = 0
    return
  end
  if self.strike ~= nil then
    self.strike.t = self.strike.t + elapsed
    if self.strike.t >= L.Time then
      self.strike = nil
      self.bright = 0
    else
      self.bright = envelope(self.strike.t / L.Time)
    end
  end
  if self.untilStrike ~= nil then
    self.untilStrike = self.untilStrike - elapsed
    if self.untilStrike <= 0 then
      if not combat then
        self.strike = { t = -self.untilStrike }
        self.bright = envelope(self.strike.t / L.Time)
      end
      self.untilStrike = between(L.Every)
    end
  end
  self.flash:SetAlpha((L.Alpha or 1) * self.bright)
end

-- Step moves the glass on elapsed seconds: the reflections laid again once the panel has moved, everything the light
-- falls on drawn again once the pointer has moved near the body (or left it) or the lightning flashes, the runners run
-- and the beads dry.
---@param elapsed number
function setProto:Step(elapsed)
  local G = glass:Spec()
  if not G then
    self:drive()
    return
  end
  local combat = InCombatLockdown()
  local frame = self.panel.frame
  local relight = false
  if self:resized() then
    self:Layout()
  end
  if frame:GetLeft() ~= self.left or frame:GetTop() ~= self.top then
    self:placeReflections()
    relight = true
  end
  if self:readPointer() and (self.near or self:nearBody()) then
    relight = true
  end
  local bright = self.bright
  self:strikeOn(elapsed, combat)
  if self.bright ~= bright then
    relight = true
  end
  if relight then
    self:relight()
  end
  if self.beading then
    self:beadUp(elapsed)
  end
  if G.Rain then
    for _, d in ipairs(self.runners) do
      self:runDrop(d, elapsed, combat)
    end
    self:dry(elapsed)
  end
end

-- drive runs the driver while the glass shows, and stops it when it does not.
---@private
function setProto:drive()
  if self.running and glass:Spec() ~= nil then
    self.driver:SetScript("OnUpdate", self.onUpdate)
  else
    self.driver:SetScript("OnUpdate", nil)
  end
end

-- Start lets the glass move (the panel shows): its drops beading up again one after another (Rain.Appear; at once
-- without it), its runners swelling again, the next flash due, everything lit for where the pointer is.
function setProto:Start()
  self.running = true
  local G = glass:Spec()
  if G then
    if self:resized() then
      self:Layout()
    end
    local A = G.Rain and G.Rain.Appear
    for _, d in ipairs(self.drops) do
      if A then
        d.appear, d.scale, d.fade = between(A), 0.3, 0
      else
        d.appear, d.scale, d.fade = nil, 1, 1
      end
    end
    self.beading = A ~= nil and #self.drops > 0
    for _, d in ipairs(self.runners) do
      self:launch(d)
      self:drawDrop(d)
    end
    self.untilStrike = G.Lightning and between(G.Lightning.Every) or nil
    self:readPointer()
    self:relight()
  end
  self:drive()
end

-- Stop ends the glass's motion (the panel hid): no flash, its beads gone.
function setProto:Stop()
  self.running = false
  self.strike, self.untilStrike, self.bright = nil, nil, 0
  self.flash:SetAlpha(0)
  for _, b in ipairs(self.beads) do
    b.life = 0
    showDrop(b, false)
  end
  self.driver:SetScript("OnUpdate", nil)
end

-- MovingParts adds every drop's textures to skip: they rest nowhere, so the pixel checks leave them out.
---@param skip table<table, boolean>
function setProto:MovingParts(skip)
  for _, list in ipairs({ self.drops, self.runners, self.beads }) do
    for _, d in ipairs(list) do
      skip[d.body] = true
      skip[d.highlight] = true
      skip[d.caustic] = true
    end
  end
end
