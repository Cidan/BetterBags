local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

-- NextSparkles is a small particle emitter (next.md §4): star sprites born where Spawn says,
-- drifting left (or right) while they twinkle, spin, shrink and fade. Sprites are pooled. An emitter runs
-- only while started, and its driver is a child of the frame it draws on, so it also stops while
-- that frame is hidden. It spawns nothing in combat; sparkles already out finish their lives. How a
-- sparkle looks and fades, twinkles, shrinks and wobbles, and whether it turns (Upright: never), is the Next theme's (Sparkles,
-- next-themes.md), read as sparkles are born and drawn; an emitter a theme turns off (SetEnabled)
-- never starts.
---@class NextSparkles: AceModule
local sparkles = addon:NewModule('NextSparkles')

---@class (exact) NextSparklesOptions
---@field Rate number Sparkles a second.
---@field Max number The most alive at once.
---@field Life number[] { shortest, longest } in seconds.
---@field Size number[] { smallest, largest } in pixels.
---@field Speed number[] { slowest, fastest } drift, pixels a second.
---@field Direction? number The way they drift: -1 left (the default), 1 right.
---@field Rise number[] { lowest, highest } vertical drift, pixels a second (up is positive).
---@field Wobble number How far a sparkle bobs up and down, in pixels.
---@field Spin number How fast a sparkle spins, radians a second.
---@field Spawn fun(): number, number Where one is born, from the parent's top left.
---@field Colors? (string|number[])[] Palette names or colors; default the theme's (Sparkles.Colors).
---@field Texture? string|number Default the theme's (Sparkles.Texture).
---@field Alpha? number The brightest a sparkle gets; default 0.9.
---@field Random? fun(): number A source of numbers in [0, 1); default math.random.

---@class (exact) NextSparkle
---@field texture Texture
---@field x number
---@field y number
---@field vx number
---@field vy number
---@field age number
---@field life number
---@field size number
---@field angle number
---@field spin number
---@field phase number

---@class NextSparkleEmitter
---@field frame Frame The driver, and what the sprites are drawn on.
---@field anchor Frame What positions are relative to.
---@field options NextSparklesOptions
---@field alive NextSparkle[]
---@field pool Texture[]
---@field accumulated number Sparkles owed since the last spawn.
---@field disabled? boolean Turned off by the theme: it never starts (SetEnabled).
local emitterProto = {}
addon:GetModule('Perf'):RegisterPrototype(emitterProto, 'NextSparkleEmitter')

---@param parent Frame
---@param options NextSparklesOptions
---@return NextSparkleEmitter
function sparkles:Create(parent, options)
  local e = setmetatable({}, { __index = emitterProto })
  e.anchor = parent
  e.options = options
  e.alive = {}
  e.pool = {}
  e.accumulated = 0
  e.frame = CreateFrame("Frame", nil, parent)
  e.frame:SetAllPoints(parent)
  return e
end

---@param random fun(): number
---@param range number[]
---@return number
local function between(random, range)
  return range[1] + (range[2] - range[1]) * random()
end

function emitterProto:Start()
  if self.disabled then
    return
  end
  self.frame:SetScript("OnUpdate", function(_, elapsed)
    self:Step(elapsed)
  end)
end

-- Burst spawns up to n sparkles at once (never past Max, none in combat), and runs the driver so
-- they live out their lives.
---@param n number
function emitterProto:Burst(n)
  if InCombatLockdown() or self.disabled then
    return
  end
  for _ = 1, n do
    if #self.alive >= self.options.Max then
      break
    end
    self:spawn()
  end
  if self.frame:GetScript("OnUpdate") == nil then
    self:Start()
  end
end

-- SetEnabled turns the emitter on or off (a theme's Sparkles): off, it stops and never starts.
---@param on boolean
function emitterProto:SetEnabled(on)
  self.disabled = not on
  if self.disabled then
    self:Stop()
  end
end

-- Stop clears every sparkle and stops the driver.
function emitterProto:Stop()
  self.frame:SetScript("OnUpdate", nil)
  for i = #self.alive, 1, -1 do
    self:recycle(i)
  end
  self.accumulated = 0
end

---@private
---@param index number
function emitterProto:recycle(index)
  local p = table.remove(self.alive, index)
  p.texture:Hide()
  table.insert(self.pool, p.texture)
end

---@private
function emitterProto:spawn()
  local o = self.options
  local random = o.Random or math.random
  local S = style.Theme.Sparkles
  local texture = table.remove(self.pool) or self.frame:CreateTexture(nil, "OVERLAY")
  texture:SetTexture(style:TexturePath(o.Texture or S.Texture))
  texture:SetBlendMode(S.BlendMode or "ADD")
  local colors = o.Colors or S.Colors
  local color = colors[math.min(#colors, math.floor(random() * #colors) + 1)]
  local r, g, b = style:RGBA(color)
  texture:SetVertexColor(r, g, b, 1)
  local x, y = o.Spawn()
  local spinDirection = random() < 0.5 and -1 or 1
  -- Upright (square pixels): never turned.
  local upright = S.Upright == true
  ---@type NextSparkle
  local p = {
    texture = texture,
    x = x,
    y = y,
    vx = (o.Direction or -1) * between(random, o.Speed),
    vy = between(random, o.Rise),
    age = 0,
    life = between(random, o.Life),
    size = between(random, o.Size),
    angle = upright and 0 or random() * math.pi * 2,
    spin = upright and 0 or o.Spin * (0.5 + random()) * spinDirection,
    phase = random() * math.pi * 2,
  }
  texture:ClearAllPoints()
  table.insert(self.alive, p)
  self:draw(p)
  texture:Show()
end

---@private
---@param p NextSparkle
function emitterProto:draw(p)
  local o, S = self.options, style.Theme.Sparkles
  local f = p.age / p.life
  local fade = 1
  if f < S.FadeIn then
    fade = f / S.FadeIn
  elseif f > 1 - S.FadeOut then
    fade = (1 - f) / S.FadeOut
  end
  local twinkle = 1 - S.TwinkleDepth + S.TwinkleDepth * math.sin(p.age * S.TwinkleSpeed + p.phase)
  local wobble = (o.Wobble or 0) * math.sin(p.age * S.WobbleSpeed + p.phase)
  local size = p.size * (1 - S.Shrink * f)
  local texture = p.texture
  texture:SetPoint("CENTER", self.anchor, "TOPLEFT", p.x, p.y + wobble)
  texture:SetSize(size, size)
  texture:SetRotation(p.angle)
  texture:SetAlpha(math.max(0, (o.Alpha or 0.9) * fade * twinkle))
end

-- Step ages and moves every sparkle elapsed seconds, retires those past their life, and spawns
-- what the rate owes (none in combat, none past Max).
---@param elapsed number
function emitterProto:Step(elapsed)
  for i = #self.alive, 1, -1 do
    local p = self.alive[i]
    p.age = p.age + elapsed
    if p.age >= p.life then
      self:recycle(i)
    else
      p.x = p.x + p.vx * elapsed
      p.y = p.y + p.vy * elapsed
      p.angle = p.angle + p.spin * elapsed
      self:draw(p)
    end
  end
  if InCombatLockdown() then
    self.accumulated = 0
    return
  end
  self.accumulated = self.accumulated + elapsed * self.options.Rate
  while self.accumulated >= 1 and #self.alive < self.options.Max do
    self:spawn()
    self.accumulated = self.accumulated - 1
  end
  if #self.alive >= self.options.Max then
    self.accumulated = math.min(self.accumulated, 1)
  end
end
