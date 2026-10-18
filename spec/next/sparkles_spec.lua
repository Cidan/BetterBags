-- sparkles_spec.lua -- NextSparkles (next/sparkles.lua): star sprites that drift left out of the
-- window while they twinkle, spin and fade; pooled, capped, and quiet in combat (next.md §4).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

ResetModuleStub("NextStyle", "next/style.lua")
LoadBetterBagsModule("next/style.lua")
ResetModuleStub("NextSparkles", "next/sparkles.lua")
LoadBetterBagsModule("next/sparkles.lua")
local sparkles = addon:GetModule("NextSparkles")

describe("NextSparkles", function()
  local parent, combat, originalCombat

  before_each(function()
    parent = CreateFrame("Frame")
    parent:Show()
    combat = false
    originalCombat = _G.InCombatLockdown
    _G.InCombatLockdown = function() return combat end
  end)

  after_each(function()
    _G.InCombatLockdown = originalCombat
  end)

  -- emitter makes one with a fixed random source, spawning at 100, -20 from the parent's top left.
  local function emitter(opts)
    local options = {
      Rate = 10, Max = 6, Life = { 2, 2 }, Size = { 10, 10 }, Speed = { 40, 40 }, Rise = { 0, 0 },
      Wobble = 0, Spin = 1,
      Spawn = function() return 100, -20 end,
      Random = function() return 0.5 end,
    }
    for k, v in pairs(opts or {}) do options[k] = v end
    return sparkles:Create(parent, options)
  end

  local function step(e, dt)
    e.frame:GetScript("OnUpdate")(e.frame, dt)
  end

  local function xOf(p)
    local _, _, _, x = p.texture:GetPoint(1)
    return x
  end

  it("draws nothing until it starts, and runs only while started", function()
    local e = emitter()
    assert.is_nil(e.frame:GetScript("OnUpdate"))
    e:Start()
    assert.is_not_nil(e.frame:GetScript("OnUpdate"))
    e:Stop()
    assert.is_nil(e.frame:GetScript("OnUpdate"))
  end)

  it("spawns at its rate, as star sprites drawn additively, up to its cap", function()
    local e = emitter()
    e:Start()
    step(e, 0.3)
    assert.are.equal(3, #e.alive)
    local p = e.alive[1]
    assert.are.equal("Interface\\Cooldown\\star4", p.texture:GetTexture())
    assert.are.equal("ADD", p.texture:GetBlendMode())
    assert.is_true(p.texture:IsShown())
    step(e, 1)
    assert.are.equal(6, #e.alive, "capped")
  end)

  it("drifts its sparkles left, spinning them", function()
    local e = emitter({ Rate = 1 })
    e:Start()
    step(e, 1)
    local p = e.alive[1]
    local x0, angle0 = xOf(p), p.angle
    step(e, 0.5)
    assert.is_true(math.abs((x0 - xOf(p)) - 20) < 1e-6, "left, 40 a second for half a second")
    assert.is_true(p.angle ~= angle0, "spins")
  end)

  -- The bank's panel is on the left of the screen: its sparkles drift right, out of its window.
  it("drifts its sparkles right when its direction says so", function()
    local e = emitter({ Rate = 1, Direction = 1 })
    e:Start()
    step(e, 1)
    local p = e.alive[1]
    local x0 = xOf(p)
    step(e, 0.5)
    assert.is_true(math.abs((xOf(p) - x0) - 20) < 1e-6, "right, 40 a second for half a second")
  end)

  it("fades a sparkle in, then out to nothing at the end of its life, and reuses its sprite", function()
    local e = emitter({ Rate = 1, Max = 1 })
    e:Start()
    step(e, 1)
    local p = e.alive[1]
    local texture = p.texture
    assert.is_true(texture:GetAlpha() < 0.2, "barely there as it is born")
    step(e, 1)
    assert.is_true(texture:GetAlpha() > 0.2, "bright in the middle of its life")
    step(e, 0.99)
    assert.is_true(texture:GetAlpha() < 0.05, "nearly gone at the end")
    step(e, 0.02)
    assert.are.equal(1, #e.alive)
    assert.are_not.equal(p, e.alive[1], "gone after its life")
    assert.are.equal(texture, e.alive[1].texture, "its sprite is reused for the next one")
  end)

  it("spawns nothing in combat, and lets the sparkles already out finish", function()
    local e = emitter({ Rate = 2 })
    e:Start()
    step(e, 1)
    assert.are.equal(2, #e.alive)
    combat = true
    step(e, 1)
    assert.are.equal(2, #e.alive)
    step(e, 1.5)
    assert.are.equal(0, #e.alive)
  end)

  it("clears every sparkle when it stops", function()
    local e = emitter()
    e:Start()
    step(e, 0.5)
    local textures = {}
    for _, p in ipairs(e.alive) do table.insert(textures, p.texture) end
    e:Stop()
    assert.are.equal(0, #e.alive)
    for _, t in ipairs(textures) do assert.is_false(t:IsShown()) end
  end)

  it("tints each sparkle with a color of its palette", function()
    local picks = { 0.0, 0.99 }
    local i = 0
    local e = emitter({
      Rate = 2, Colors = { { 1, 0, 0, 1 }, { 0, 0, 1, 1 } },
      Random = function() i = i + 1 return picks[(i - 1) % 2 + 1] end,
    })
    e:Start()
    step(e, 1)
    local seen = {}
    for _, p in ipairs(e.alive) do
      local r, _, b = p.texture:GetVertexColor()
      seen[r == 1 and "red" or b == 1 and "blue" or "other"] = true
    end
    assert.is_true(seen.red or seen.blue)
    assert.is_nil(seen.other)
  end)
end)
