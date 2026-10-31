-- stopmotion_spec.lua -- NextStopMotion (next/stopmotion.lua): a Next theme whose animations run as stop motion
-- (Motion.StopMotion, next-themes.md §25; the Papercraft theme; asked: "the animations? should be stop-motion esque.
-- meaning they are not just staggered in that stop motion FPS, but imperfect in their placement from frame to frame").
-- Every tween holds each pose for a whole frame and lands a little off its even spacing, except its last, which is exact.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

ResetModuleStub("NextTween", "next/tween.lua")
LoadBetterBagsModule("next/tween.lua")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextStopMotion", "next/stopmotion.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end
local tween = addon:GetModule("NextTween")
local stopMotion = addon:GetModule("NextStopMotion")

describe("NextStopMotion", function()
  local STOP = { FPS = 10, Spacing = 0.4, Wobble = 2 }

  local function theme(spec)
    UseNextTheme({ Motion = { StopMotion = spec } })
  end

  local function tick(dt)
    local update = tween.driver and tween.driver:GetScript("OnUpdate")
    if update ~= nil then update(tween.driver, dt) end
  end

  before_each(function()
    UseNextTheme()
    tween:Init()
  end)

  after_each(function()
    UseNextTheme()
    tween:Init()
  end)

  describe("the theme's say", function()
    it("has none under a theme without one", function()
      assert.is_nil(stopMotion:Spec())
    end)

    it("tells what steps itself through NextStyle, as themes come and go", function()
      local style = addon:GetModule("NextStyle")
      assert.is_nil(style.StopMotion)
      theme(STOP)
      assert.are.equal(10, style.StopMotion.FPS)
      UseNextTheme()
      assert.is_nil(style.StopMotion)
    end)

    it("reads a theme's Motion.StopMotion", function()
      theme(STOP)
      assert.are.equal(10, stopMotion:Spec().FPS)
    end)
  end)

  describe("frames", function()
    it("counts whole frames, whatever the float error in adding up time", function()
      assert.are.equal(0, stopMotion:Frame(0, 10))
      assert.are.equal(0, stopMotion:Frame(0.099, 10))
      assert.are.equal(1, stopMotion:Frame(0.1, 10))
      assert.are.equal(3, stopMotion:Frame(0.1 + 0.1 + 0.1, 10))
      assert.are.equal(29, stopMotion:Frame(0.29, 100), "0.29 * 100 is a hair under 29")
    end)
  end)

  describe("noise", function()
    it("gives the same number for the same frame and key: a held frame never moves", function()
      assert.are.equal(stopMotion:Noise(7, 3), stopMotion:Noise(7, 3))
    end)

    it("stays between -1 and 1, and changes frame to frame and key to key", function()
      local seen = {}
      for frame = 1, 200 do
        local n = stopMotion:Noise(frame, 1)
        assert.is_true(n >= -1 and n <= 1)
        seen[n] = true
      end
      local count = 0
      for _ in pairs(seen) do count = count + 1 end
      assert.is_true(count > 150, "nearly every frame its own")
      assert.are_not.equal(stopMotion:Noise(5, 1), stopMotion:Noise(5, 2))
    end)
  end)

  describe("a tween under it", function()
    local function play(extra)
      local values = {}
      local options = { duration = 1, from = 0, to = 100, ease = "linear",
        onUpdate = function(v) table.insert(values, v) end }
      for k, v in pairs(extra or {}) do options[k] = v end
      tween:Play("key", options)
      return values
    end

    it("runs every frame without a stop motion", function()
      local values = play()
      for _ = 1, 5 do tick(0.016) end
      assert.are.equal(6, #values)
    end)

    it("holds each pose for a whole frame", function()
      theme(STOP)
      local values = play()
      assert.are.equal(1, #values, "its start, as ever")
      for _ = 1, 5 do tick(0.016) end
      assert.are.equal(1, #values, "still its first pose, a tenth of a second not gone")
      tick(0.03)
      assert.are.equal(2, #values, "the next pose")
      for _ = 1, 3 do tick(0.016) end
      assert.are.equal(2, #values, "held")
    end)

    it("lands near its even spacing, not on it", function()
      theme(STOP)
      local values = play()
      tick(0.1)
      tick(0.1)
      tick(0.1)
      tick(0.1)
      local off = 0
      for i = 2, #values do
        local even = (i - 1) * 10
        -- Spacing is how far off, as a share of a frame's step.
        assert.is_true(math.abs(values[i] - even) <= 10 * STOP.Spacing + 1e-6, "within its spacing")
        off = math.max(off, math.abs(values[i] - even))
      end
      assert.is_true(off > 0.01, "off its even spacing")
      for i = 2, #values do
        assert.is_true(values[i] > values[i - 1], "never going back: under a frame's step off either way")
      end
    end)

    it("ends exactly at its end", function()
      theme(STOP)
      local done = false
      local values = play({ onDone = function() done = true end })
      for _ = 1, 20 do tick(0.1) end
      assert.are.equal(100, values[#values])
      assert.is_true(done)
    end)

    it("never lands past its end, however far off its spacing", function()
      theme({ FPS = 10, Spacing = 0.4 })
      local noise = tween.Noise
      tween.Noise = function() return 1 end
      local values = {}
      tween:Play("key", { duration = 0.32, from = 0, to = 100, ease = "linear", onUpdate = function(v)
        table.insert(values, v)
      end })
      for _ = 1, 10 do tick(0.1) end
      tween.Noise = noise
      for _, v in ipairs(values) do
        assert.is_true(v <= 100, tostring(v))
      end
    end)

    it("holds its start through a delay, then steps from it", function()
      theme(STOP)
      local values = play({ delay = 0.5 })
      for _ = 1, 4 do tick(0.1) end
      assert.are.equal(1, #values)
      tick(0.1)
      tick(0.1)
      assert.are.equal(2, #values)
      assert.is_true(values[2] > 0 and values[2] < 20)
    end)

    it("leaves a tween that says it is smooth to run every frame", function()
      theme(STOP)
      local values = play({ smooth = true })
      for _ = 1, 5 do tick(0.016) end
      assert.are.equal(6, #values)
    end)

    it("catches up when a slow frame skips poses", function()
      theme(STOP)
      local values = play()
      tick(0.35)
      assert.are.equal(2, #values)
      assert.is_true(math.abs(values[2] - 30) <= 10 * STOP.Spacing + 1e-6)
    end)

    it("makes each tween's spacing its own", function()
      theme(STOP)
      local a, b = {}, {}
      tween:Play("a", { duration = 1, from = 0, to = 100, ease = "linear", onUpdate = function(v) table.insert(a, v) end })
      tween:Play("b", { duration = 1, from = 0, to = 100, ease = "linear", onUpdate = function(v) table.insert(b, v) end })
      tick(0.1)
      assert.are_not.equal(a[2], b[2])
    end)

    it("stops stepping as soon as the theme goes", function()
      theme(STOP)
      local values = play()
      tick(0.1)
      local n = #values
      UseNextTheme()
      tick(0.016)
      tick(0.016)
      assert.are.equal(n + 2, #values)
    end)
  end)
end)
