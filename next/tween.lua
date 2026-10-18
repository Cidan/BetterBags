local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- NextTween runs BetterBagsNext's animations (next.md §5): one tween per key, all on a single
-- OnUpdate that exists only while something tweens. A tween reports its value through onUpdate:
-- at once with its start value (so a delayed tween holds it), then every frame, and its end
-- value last.
---@class NextTween: AceModule
local tween = addon:NewModule('NextTween')

---@alias NextEase "linear"|"outCubic"|"inCubic"|"inOutSine"|"inOutCubic"|"outBack"|"outBackSoft"

-- The overshoot of outBack: about a tenth past the end at its furthest. For an overshoot s, the
-- furthest past the end is 4 s^3 / (27 (s + 1)^2).
local BACK = 1.70158
-- outBackSoft's: about a fiftieth (2%) past the end, for long moves (a chained bag falling into
-- place) where outBack's tenth would be a hundred pixels or more.
local BACK_SOFT = 0.75

-- Ease maps a time from 0 to 1 to progress from 0 to 1.
---@type table<NextEase, fun(t: number): number>
tween.Ease = {
  linear = function(t) return t end,
  outCubic = function(t) return 1 - (1 - t) ^ 3 end,
  inCubic = function(t) return t * t * t end,
  inOutSine = function(t) return 0.5 - math.cos(math.pi * t) / 2 end,
  -- Slow off the mark and into place, three times its average speed in the middle.
  inOutCubic = function(t)
    if t < 0.5 then
      return 4 * t * t * t
    end
    local u = 2 - 2 * t
    return 1 - u * u * u / 2
  end,
  outBack = function(t)
    local u = t - 1
    return 1 + (BACK + 1) * u * u * u + BACK * u * u
  end,
  outBackSoft = function(t)
    local u = t - 1
    return 1 + (BACK_SOFT + 1) * u * u * u + BACK_SOFT * u * u
  end,
}

---@class (exact) NextTweenOptions
---@field duration number Seconds.
---@field from number
---@field to number
---@field ease? NextEase Default outCubic.
---@field delay? number Seconds before it starts moving, holding its start value.
---@field onUpdate fun(value: number)
---@field onDone? fun()

---@class (exact) NextTweenState
---@field options NextTweenOptions
---@field elapsed number

function tween:Init()
  self.tweens = {} ---@type table<any, NextTweenState>
  if self.driver ~= nil then
    self.driver:SetScript("OnUpdate", nil)
  end
end

tween:Init()

-- Play starts a tween for key, replacing the one it had.
---@param key any
---@param options NextTweenOptions
function tween:Play(key, options)
  self.tweens[key] = { options = options, elapsed = 0 }
  options.onUpdate(options.from)
  if self.driver == nil then
    self.driver = CreateFrame("Frame")
  end
  if self.driver:GetScript("OnUpdate") == nil then
    self.driver:SetScript("OnUpdate", function(_, elapsed)
      self:Step(elapsed)
    end)
  end
end

---@param key any
---@return boolean
function tween:IsPlaying(key)
  return self.tweens[key] ~= nil
end

-- Stop ends key's tween where it is, or at its end (calling it back) with finish.
---@param key any
---@param finish? boolean
function tween:Stop(key, finish)
  local state = self.tweens[key]
  if state == nil then
    return
  end
  self.tweens[key] = nil
  if finish then
    state.options.onUpdate(state.options.to)
    if state.options.onDone then
      state.options.onDone()
    end
  end
  self:stopIfIdle()
end

---@private
function tween:stopIfIdle()
  if next(self.tweens) == nil and self.driver ~= nil then
    self.driver:SetScript("OnUpdate", nil)
  end
end

-- Step moves every tween elapsed seconds along. A finished tween is removed before it is called
-- back, so its callback can start the next tween of the same key.
---@param elapsed number
function tween:Step(elapsed)
  local due = {}
  for key, state in pairs(self.tweens) do
    due[key] = state
  end
  for key, state in pairs(due) do
    if self.tweens[key] == state then
      local options = state.options
      state.elapsed = state.elapsed + elapsed
      local t = (state.elapsed - (options.delay or 0)) / options.duration
      if t >= 1 then
        self.tweens[key] = nil
        options.onUpdate(options.to)
        if options.onDone then
          options.onDone()
        end
      elseif t > 0 then
        local ease = tween.Ease[options.ease or "outCubic"]
        options.onUpdate(options.from + (options.to - options.from) * ease(t))
      end
    end
  end
  self:stopIfIdle()
end
