-- tween_spec.lua -- NextTween (next/tween.lua): one tween per key on a single OnUpdate that exists
-- only while something tweens (next.md §5).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

ResetModuleStub("NextTween", "next/tween.lua")
LoadBetterBagsModule("next/tween.lua")
local tween = addon:GetModule("NextTween")

describe("NextTween", function()
  before_each(function()
    tween:Init()
  end)

  local function tick(dt)
    local update = tween.driver and tween.driver:GetScript("OnUpdate")
    if update ~= nil then update(tween.driver, dt) end
  end

  local function near(expected, actual, what)
    assert.is_true(math.abs(expected - actual) < 1e-6, string.format("%s: %s, not %s", what or "", actual, expected))
  end

  it("eases from 0 to 1, each the way its name says", function()
    for name, ease in pairs(tween.Ease) do
      near(0, ease(0), name .. " at 0")
      near(1, ease(1), name .. " at 1")
    end
    near(0.5, tween.Ease.linear(0.5))
    assert.is_true(tween.Ease.outCubic(0.5) > 0.5, "out starts fast")
    assert.is_true(tween.Ease.inCubic(0.5) < 0.5, "in starts slow")
    near(0.5, tween.Ease.inOutSine(0.5))
    -- In-out cubic: slow off the mark, three times its average speed in the middle, slow into
    -- place, and symmetric (chaining's flights, next.md §12).
    local cubic = tween.Ease.inOutCubic
    near(0.5, cubic(0.5))
    near(4 * 0.25 ^ 3, cubic(0.25))
    for i = 1, 49 do
      near(1 - cubic(1 - i / 100), cubic(i / 100), "symmetric")
    end
    -- (A numeric speed: the acceleration flips at the middle, so allow for the step.)
    local speed = (cubic(0.5 + 1e-5) - cubic(0.5 - 1e-5)) / 2e-5
    assert.is_true(math.abs(speed - 3) < 1e-3, "three times as fast in the middle: " .. speed)
    assert.is_true(cubic(0.1) < tween.Ease.inOutSine(0.1), "softer off the mark than sine")
    -- outBackSoft settles just past its end and back: about a fiftieth (a chained bag falling into
    -- place across the screen, next.md §12), where outBack goes a tenth past.
    local soft, furthest, backFurthest = tween.Ease.outBackSoft, 0, 0
    for i = 1, 999 do
      furthest = math.max(furthest, soft(i / 1000))
      backFurthest = math.max(backFurthest, tween.Ease.outBack(i / 1000))
    end
    assert.is_true(furthest > 1.015 and furthest < 1.025, "a fiftieth past: " .. furthest)
    assert.is_true(backFurthest > 1.09, "outBack a tenth: " .. backFurthest)
    assert.is_true(soft(1 / 30) > 0.1, "quick off the mark")
    local overshoots = false
    for i = 1, 99 do
      if tween.Ease.outBack(i / 100) > 1 then overshoots = true end
    end
    assert.is_true(overshoots, "back passes its end and returns")
  end)

  it("starts at its start value at once, reaches its end on time, and calls back once", function()
    local values, done = {}, 0
    tween:Play("a", { duration = 0.2, from = 10, to = 20, ease = "linear",
      onUpdate = function(v) table.insert(values, v) end, onDone = function() done = done + 1 end })
    assert.are.same({ 10 }, values)
    tick(0.1)
    near(15, values[2])
    assert.is_true(tween:IsPlaying("a"))
    tick(0.1)
    near(20, values[3])
    assert.are.equal(1, done)
    assert.is_false(tween:IsPlaying("a"))
    assert.is_nil(tween.driver:GetScript("OnUpdate"), "the driver stops once nothing tweens")
  end)

  it("holds its start value through its delay", function()
    local last
    tween:Play("a", { duration = 0.1, delay = 0.1, from = 0, to = 1, ease = "linear",
      onUpdate = function(v) last = v end })
    tick(0.05)
    near(0, last)
    tick(0.1)
    near(0.5, last)
  end)

  it("replaces the tween of the same key, without calling the old one back", function()
    local oldDone, newValues = 0, {}
    tween:Play("a", { duration = 1, from = 0, to = 1, onUpdate = function() end,
      onDone = function() oldDone = oldDone + 1 end })
    tween:Play("a", { duration = 0.1, from = 5, to = 6, ease = "linear",
      onUpdate = function(v) table.insert(newValues, v) end })
    tick(0.2)
    assert.are.equal(0, oldDone)
    assert.are.same({ 5, 6 }, newValues)
  end)

  it("runs tweens of different keys side by side", function()
    local a, b
    tween:Play("a", { duration = 0.1, from = 0, to = 1, ease = "linear", onUpdate = function(v) a = v end })
    tween:Play({}, { duration = 0.2, from = 0, to = 2, ease = "linear", onUpdate = function(v) b = v end })
    tick(0.1)
    near(1, a)
    near(1, b)
  end)

  it("stops a tween where it is, or at its end and calls back when asked to finish", function()
    local last, done = nil, 0
    tween:Play("a", { duration = 1, from = 0, to = 1, ease = "linear",
      onUpdate = function(v) last = v end, onDone = function() done = done + 1 end })
    tick(0.25)
    tween:Stop("a")
    near(0.25, last)
    assert.are.equal(0, done)
    tween:Play("b", { duration = 1, from = 0, to = 1, ease = "linear",
      onUpdate = function(v) last = v end, onDone = function() done = done + 1 end })
    tween:Stop("b", true)
    near(1, last)
    assert.are.equal(1, done)
    assert.is_nil(tween.driver:GetScript("OnUpdate"))
  end)

  it("skips a tween stopped by another one's callback in the same frame", function()
    local keys, calls, armed = {}, 0, false
    for i = 1, 20 do keys[i] = "k" .. i end
    for _, key in ipairs(keys) do
      tween:Play(key, { duration = 1, from = 0, to = 1, onUpdate = function()
        if not armed then return end
        calls = calls + 1
        for _, other in ipairs(keys) do
          if other ~= key then tween:Stop(other) end
        end
      end })
    end
    armed = true
    tick(0.1)
    assert.are.equal(1, calls)
  end)

  it("lets a callback start the next tween of its own key", function()
    local stage = {}
    tween:Play("a", { duration = 0.1, from = 0, to = 1, onUpdate = function() end, onDone = function()
      tween:Play("a", { duration = 0.1, from = 1, to = 2, ease = "linear", onUpdate = function(v) stage.v = v end })
    end })
    tick(0.1)
    assert.is_true(tween:IsPlaying("a"))
    tick(0.1)
    near(2, stage.v)
  end)
end)
