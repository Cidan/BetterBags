local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

-- NextSparkles is a small particle emitter (next.md §4): star sprites born where Spawn says,
-- drifting left while they twinkle, spin, shrink and fade. Sprites are pooled. An emitter runs
-- only while started, and its driver is a child of the frame it draws on, so it also stops while
-- that frame is hidden. It spawns nothing in combat; sparkles already out finish their lives.
---@class NextSparkles: AceModule
local sparkles = addon:NewModule('NextSparkles')

-- The share of a sparkle's life it spends fading in, and fading out.
local FADE_IN = 0.15
local FADE_OUT = 0.4
-- How fast a sparkle twinkles (radians a second) and how deep.
local TWINKLE_SPEED = 7
local TWINKLE_DEPTH = 0.3
-- How much a sparkle shrinks by the end of its life.
local SHRINK = 0.35
-- How fast a sparkle wobbles up and down (radians a second).
local WOBBLE_SPEED = 2.3

---@class (exact) NextSparklesOptions
---@field Rate number Sparkles a second.
---@field Max number The most alive at once.
---@field Life number[] { shortest, longest } in seconds.
---@field Size number[] { smallest, largest } in pixels.
---@field Speed number[] { slowest, fastest } leftward drift, pixels a second.
---@field Rise number[] { lowest, highest } vertical drift, pixels a second (up is positive).
---@field Wobble number How far a sparkle bobs up and down, in pixels.
---@field Spin number How fast a sparkle spins, radians a second.
---@field Spawn fun(): number, number Where one is born, from the parent's top left.
---@field Colors? number[][] The palette; default starlight gold, white and moon lavender.
---@field Texture? string Default the cooldown star.
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
  self.frame:SetScript("OnUpdate", function(_, elapsed)
    self:Step(elapsed)
  end)
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
  local texture = table.remove(self.pool)
  if texture == nil then
    texture = self.frame:CreateTexture(nil, "OVERLAY")
    texture:SetTexture(o.Texture or style.SPARKLE_TEXTURE)
    texture:SetBlendMode("ADD")
  end
  local colors = o.Colors or { style.Color.Gold, style.Color.White, style.Color.Lavender }
  local color = colors[math.min(#colors, math.floor(random() * #colors) + 1)]
  texture:SetVertexColor(color[1], color[2], color[3], 1)
  local x, y = o.Spawn()
  local spinDirection = random() < 0.5 and -1 or 1
  ---@type NextSparkle
  local p = {
    texture = texture,
    x = x,
    y = y,
    vx = -between(random, o.Speed),
    vy = between(random, o.Rise),
    age = 0,
    life = between(random, o.Life),
    size = between(random, o.Size),
    angle = random() * math.pi * 2,
    spin = o.Spin * (0.5 + random()) * spinDirection,
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
  local o = self.options
  local f = p.age / p.life
  local fade = 1
  if f < FADE_IN then
    fade = f / FADE_IN
  elseif f > 1 - FADE_OUT then
    fade = (1 - f) / FADE_OUT
  end
  local twinkle = 1 - TWINKLE_DEPTH + TWINKLE_DEPTH * math.sin(p.age * TWINKLE_SPEED + p.phase)
  local wobble = (o.Wobble or 0) * math.sin(p.age * WOBBLE_SPEED + p.phase)
  local size = p.size * (1 - SHRINK * f)
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
