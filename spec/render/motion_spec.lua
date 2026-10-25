-- motion_spec.lua -- Motion (render/motion.lua): the one place a layout's frames are positioned. In a
-- pass of a root (a bag's canvas render), a frame the root's previous pass also placed moves from
-- where it is to its new place, slow, fast, slow; anything else is placed at once
-- (render-pipeline.md, motion).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local motion = addon:GetModule("Motion")

-- How long a move takes (render/motion.lua MOVE_DURATION).
local DURATION = 0.3

describe("Motion", function()
  local root, key

  before_each(function()
    motion:Init()
    root = CreateFrame("Frame")
    key = {}
  end)

  local function anchorOf(f)
    return { f:GetPoint(1) }
  end

  local function tick(dt)
    local update = motion.driver and motion.driver:GetScript("OnUpdate")
    if update ~= nil then
      update(motion.driver, dt)
    end
  end

  -- A window snapping to its content (window.md §3b) and a BetterBags Next panel snapping to its columns (next.md §14g)
  -- bounce the same way.
  describe("a size snapping", function()
    it("follows a bounce curve: from the start, past the end, back to the end", function()
      assert.are.equal(700, motion.SnapSizeAt(700, 412, 10, 0))
      assert.are.equal(412, motion.SnapSizeAt(700, 412, 10, 1))
      assert.are.equal(402, motion.SnapSizeAt(700, 412, 10, 0.65))
      local previous = 700
      for i = 1, 100 do
        local width = motion.SnapSizeAt(700, 412, 10, i / 100)
        assert.is_true(math.abs(width - previous) < 40, "no jumps")
        previous = width
      end
    end)

    it("bounces a tenth of the way past, at most 10, never below a floor nor for a size that grows", function()
      assert.are.equal(4, motion.SnapOvershoot(500, 460, 100))
      assert.are.equal(10, motion.SnapOvershoot(700, 412, 100))
      assert.are.equal(3, motion.SnapOvershoot(700, 412, 409), "no lower than the floor")
      assert.are.equal(0, motion.SnapOvershoot(460, 500, 100), "growing, it does not bounce")
    end)
  end)

  local function pass(passKey, fn)
    motion:BeginPass(passKey)
    fn()
    return motion:EndPass()
  end

  local function frameIn(parent, x, y)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    f:Show()
    return f
  end

  local function shown()
    local f = CreateFrame("Frame")
    f:Show()
    return f
  end

  local function finish()
    for _ = 1, 100 do tick(0.016) end
  end

  -- hermite is the curve: from x0 at speed v0 to x1 at rest over d seconds, e seconds in.
  local function hermite(x0, v0, x1, d, e)
    local u = e / d
    local u2, u3 = u * u, u * u * u
    local x = (2 * u3 - 3 * u2 + 1) * x0 + (u3 - 2 * u2 + u) * d * v0 + (3 * u2 - 2 * u3) * x1
    local v = ((6 * u2 - 6 * u) * x0 + (3 * u2 - 4 * u + 1) * d * v0 + (6 * u - 6 * u2) * x1) / d
    return x, v
  end

  it("places a frame at once outside a pass", function()
    local f = shown()
    motion:Place(f, root, 10, -20)
    assert.are.same({ "TOPLEFT", root, "TOPLEFT", 10, -20 }, anchorOf(f))
    assert.are.equal(1, f:GetNumPoints())
    assert.is_nil(motion:GetMove(f))
  end)

  it("places at once in a root's first pass, even a frame anchored somewhere already", function()
    local f = shown()
    motion:Place(f, root, 0, 0)
    pass(key, function() motion:Place(f, root, 50, 0) end)
    assert.are.same({ "TOPLEFT", root, "TOPLEFT", 50, 0 }, anchorOf(f))
    assert.is_nil(motion:GetMove(f))
  end)

  it("puts a frame exactly where it goes, even a fraction of a pixel away", function()
    local f = shown()
    motion:Place(f, root, 30.3, -5)
    motion:Place(f, root, 30, -5)
    assert.are.same({ "TOPLEFT", root, "TOPLEFT", 30, -5 }, anchorOf(f))
  end)

  it("places at once in a root's first pass, and a frame its previous pass did not place", function()
    local f, g = shown(), shown()
    pass(key, function() motion:Place(f, root, 0, 0) end)
    pass(key, function()
      motion:Place(f, root, 0, 0)
      motion:Place(g, root, 50, 0)
    end)
    assert.are.same({ "TOPLEFT", root, "TOPLEFT", 50, 0 }, anchorOf(g))
    assert.is_nil(motion:GetMove(g))
    pass(key, function() motion:Place(g, root, 50, 0) end)
    pass(key, function() motion:Place(f, root, 90, 0) end)
    assert.are.same({ "TOPLEFT", root, "TOPLEFT", 90, 0 }, anchorOf(f), "it skipped a pass")
    assert.is_nil(motion:GetMove(f))
  end)

  it("moves a frame its previous pass placed from where it is to its new place", function()
    local f = shown()
    pass(key, function() motion:Place(f, root, 0, 0) end)
    pass(key, function() motion:Place(f, root, 100, -40) end)
    assert.are.same({ "TOPLEFT", root, "TOPLEFT", 0, 0 }, anchorOf(f), "starts where it was")
    assert.are.same({ 0, 0, 100, -40 }, { motion:GetMove(f) })
    finish()
    assert.are.same({ "TOPLEFT", root, "TOPLEFT", 100, -40 }, anchorOf(f))
    assert.is_nil(motion:GetMove(f))
    assert.is_nil(motion.driver:GetScript("OnUpdate"), "the driver stops once nothing moves")
  end)

  it("moves slow, then fast, then slow, in the time a move takes", function()
    local f = shown()
    pass(key, function() motion:Place(f, root, 0, 0) end)
    pass(key, function() motion:Place(f, root, 300, 0) end)
    local xs = { 0 }
    while motion:GetMove(f) ~= nil and #xs < 200 do
      tick(0.01)
      table.insert(xs, (select(4, f:GetPoint(1))))
    end
    local steps, peak, peakAt = {}, 0, 0
    for i = 2, #xs do
      steps[i - 1] = xs[i] - xs[i - 1]
      if steps[i - 1] > peak then peak, peakAt = steps[i - 1], i - 1 end
    end
    assert.is_true(math.abs(#steps * 0.01 - DURATION) < 0.011, tostring(#steps))
    assert.is_true(peakAt >= #steps * 0.4 and peakAt <= #steps * 0.6 + 1, tostring(peakAt) .. " of " .. #steps)
    for i = 2, peakAt do assert.is_true(steps[i] >= steps[i - 1] - 1e-9, "speeds up") end
    for i = peakAt + 1, #steps do assert.is_true(steps[i] <= steps[i - 1] + 1e-9, "slows down") end
    assert.is_true(steps[1] < peak * 0.25 and steps[#steps] < peak * 0.25, "starts and ends slow")
    assert.are.equal(300, xs[#xs])
  end)

  -- A pass may give its moves their own duration: BetterBags Next's sections making room for a
  -- dragged section move faster (next.md §7).
  it("moves in a pass's own time, with the same slow, fast, slow curve", function()
    local f = shown()
    pass(key, function() motion:Place(f, root, 0, 0) end)
    motion:BeginPass(key, 0.2)
    motion:Place(f, root, 300, 0)
    motion:EndPass()
    tick(0.05)
    local quarter = select(4, f:GetPoint(1))
    assert.is_true(math.abs(quarter - 300 * (3 * 0.25 ^ 2 - 2 * 0.25 ^ 3)) < 1e-6, tostring(quarter))
    tick(0.05)
    assert.is_true(math.abs(select(4, f:GetPoint(1)) - 150) < 1e-6, "halfway at half its time")
    tick(0.1)
    assert.are.same({ "TOPLEFT", root, "TOPLEFT", 300, 0 }, anchorOf(f))
    assert.is_nil(motion:GetMove(f))
  end)

  it("keeps the usual time for a pass that gives none", function()
    local f = shown()
    pass(key, function() motion:Place(f, root, 0, 0) end)
    motion:BeginPass(key, 0.2)
    motion:Place(f, root, 0, 0)
    motion:EndPass()
    pass(key, function() motion:Place(f, root, 300, 0) end)
    tick(0.2)
    assert.is_not_nil(motion:GetMove(f), "still moving after 0.2 s")
    tick(DURATION - 0.2)
    assert.is_nil(motion:GetMove(f))
  end)

  it("keeps its speed turning toward a new place in a pass with its own time", function()
    local f = shown()
    pass(key, function() motion:Place(f, root, 0, 0) end)
    motion:BeginPass(key, 0.2)
    motion:Place(f, root, 300, 0)
    motion:EndPass()
    tick(0.11)
    local at, speed = hermite(0, 0, 300, 0.2, 0.11)
    assert.is_true(math.abs(select(4, f:GetPoint(1)) - at) < 1e-6)
    motion:BeginPass(key, 0.2)
    motion:Place(f, root, 600, 0)
    motion:EndPass()
    tick(0.01)
    local expected = hermite(at, speed, 600, 0.2, 0.01)
    assert.is_true(math.abs(select(4, f:GetPoint(1)) - expected) < 1e-6,
      string.format("%.4f, expected %.4f", select(4, f:GetPoint(1)), expected))
    tick(0.2)
    assert.are.same({ "TOPLEFT", root, "TOPLEFT", 600, 0 }, anchorOf(f))
  end)

  -- A drag ends mid-slide: a quick move turns into one of the usual time.
  it("carries its speed into a move of another duration", function()
    local f = shown()
    pass(key, function() motion:Place(f, root, 0, 0) end)
    motion:BeginPass(key, 0.2)
    motion:Place(f, root, 300, 0)
    motion:EndPass()
    tick(0.11)
    local at, speed = hermite(0, 0, 300, 0.2, 0.11)
    pass(key, function() motion:Place(f, root, 600, 0) end)
    tick(0.01)
    local expected = hermite(at, speed, 600, DURATION, 0.01)
    assert.is_true(math.abs(select(4, f:GetPoint(1)) - expected) < 1e-6,
      string.format("%.4f, expected %.4f", select(4, f:GetPoint(1)), expected))
    tick(DURATION)
    assert.are.same({ "TOPLEFT", root, "TOPLEFT", 600, 0 }, anchorOf(f))
  end)

  it("leaves a frame that stays where it is alone", function()
    local f = shown()
    pass(key, function() motion:Place(f, root, 30, -5) end)
    local calls = 0
    local setPoint = f.SetPoint
    f.SetPoint = function(...) calls = calls + 1 return setPoint(...) end
    pass(key, function() motion:Place(f, root, 30, -5) end)
    assert.are.equal(0, calls)
    assert.is_nil(motion:GetMove(f))
  end)

  it("keeps heading for the same place across passes without starting over", function()
    local f = shown()
    pass(key, function() motion:Place(f, root, 0, 0) end)
    pass(key, function() motion:Place(f, root, 100, 0) end)
    tick(0.15)
    local halfway = select(4, f:GetPoint(1))
    pass(key, function() motion:Place(f, root, 100, 0) end)
    assert.are.same({ 0, 0, 100, 0 }, { motion:GetMove(f) })
    tick(0.15)
    assert.are.same({ "TOPLEFT", root, "TOPLEFT", 100, 0 }, anchorOf(f))
    assert.is_true(halfway > 40 and halfway < 60, tostring(halfway))
  end)

  it("turns toward a new place without stopping first", function()
    local f = shown()
    pass(key, function() motion:Place(f, root, 0, 0) end)
    pass(key, function() motion:Place(f, root, 300, 0) end)
    for _ = 1, 10 do tick(0.01) end
    local before = select(4, f:GetPoint(1))
    tick(0.01)
    local at = select(4, f:GetPoint(1))
    local speed = at - before
    pass(key, function() motion:Place(f, root, 600, 0) end)
    assert.are.equal(at, (select(1, motion:GetMove(f))), "the new move starts where it was")
    tick(0.01)
    local after = select(4, f:GetPoint(1)) - at
    assert.is_true(after > speed * 0.7, string.format("kept its speed: %.2f then %.2f", speed, after))
    finish()
    assert.are.same({ "TOPLEFT", root, "TOPLEFT", 600, 0 }, anchorOf(f))
  end)

  -- An item that changes section keeps its place on screen and travels from there: its start is
  -- worked out from the anchors of both parents, up to the frame they share.
  it("carries a frame to another parent from where it was", function()
    local a, b = frameIn(root, 0, 0), frameIn(root, 200, -100)
    local f = frameIn(a, 10, -10)
    pass(key, function() motion:Place(f, a, 10, -10) end)
    pass(key, function() motion:Place(f, b, 5, -5) end)
    assert.are.same({ "TOPLEFT", b, "TOPLEFT", -190, 90 }, anchorOf(f))
    assert.are.same({ -190, 90, 5, -5 }, { motion:GetMove(f) })
    finish()
    assert.are.same({ "TOPLEFT", b, "TOPLEFT", 5, -5 }, anchorOf(f))
  end)

  -- A section's cells hang from a frame Blizzard's scroll box positions, not from an anchor of
  -- ours; the section links it to its own frame with the offset its cells start at.
  it("follows a link through a frame whose place is not one of its anchors", function()
    local section = frameIn(root, 50, -60)
    local inner = CreateFrame("Frame", nil, section)
    motion:Link(inner, section, function() return 6, -18 end)
    local b = frameIn(root, 300, 0)
    local f = frameIn(inner, 41, 0)
    pass(key, function() motion:Place(f, inner, 41, 0) end)
    pass(key, function() motion:Place(f, b, 0, 0) end)
    assert.are.same({ -203, -78, 0, 0 }, { motion:GetMove(f) })
  end)

  it("places at once when its old place does not lead to the new parent's frame", function()
    local a = CreateFrame("Frame")
    local b = frameIn(root, 200, -100)
    local f = frameIn(a, 10, -10)
    pass(key, function() motion:Place(f, a, 10, -10) end)
    pass(key, function() motion:Place(f, b, 5, -5) end)
    assert.are.same({ "TOPLEFT", b, "TOPLEFT", 5, -5 }, anchorOf(f))
    assert.is_nil(motion:GetMove(f))
  end)

  it("drops a move when something else releases, hides or moves the frame", function()
    local function moving()
      local f = shown()
      local k = {}
      pass(k, function() motion:Place(f, root, 0, 0) end)
      pass(k, function() motion:Place(f, root, 100, 0) end)
      tick(0.05)
      return f
    end
    local released = moving()
    released:ClearAllPoints()
    tick(0.05)
    assert.is_nil(motion:GetMove(released))
    assert.is_nil(released:GetPoint(1))

    local hidden = moving()
    hidden:Hide()
    tick(0.05)
    assert.is_nil(motion:GetMove(hidden))

    local moved = moving()
    moved:SetPoint("TOPLEFT", root, "TOPLEFT", 999, 0)
    tick(0.05)
    assert.is_nil(motion:GetMove(moved))
    assert.are.same({ "TOPLEFT", root, "TOPLEFT", 999, 0 }, anchorOf(moved))
  end)

  it("forgets a root: its moves end where they were going, and its next pass places at once", function()
    local f = shown()
    pass(key, function() motion:Place(f, root, 0, 0) end)
    pass(key, function() motion:Place(f, root, 100, 0) end)
    tick(0.05)
    motion:Forget(key)
    assert.are.same({ "TOPLEFT", root, "TOPLEFT", 100, 0 }, anchorOf(f))
    assert.is_nil(motion:GetMove(f))
    pass(key, function() motion:Place(f, root, 200, 0) end)
    assert.are.same({ "TOPLEFT", root, "TOPLEFT", 200, 0 }, anchorOf(f))
    assert.is_nil(motion:GetMove(f))
  end)

  it("counts only the passes of the same root", function()
    local f = shown()
    pass({}, function() motion:Place(f, root, 0, 0) end)
    pass(key, function() motion:Place(f, root, 50, 0) end)
    assert.is_nil(motion:GetMove(f))
  end)

  it("ends a pass with the number of moves it started", function()
    local f, g, h = shown(), shown(), shown()
    pass(key, function()
      motion:Place(f, root, 0, 0)
      motion:Place(g, root, 0, 0)
      motion:Place(h, root, 0, 0)
    end)
    local started = pass(key, function()
      motion:Place(f, root, 10, 0)
      motion:Place(g, root, 0, 0)
      motion:Place(h, root, 0, -10)
    end)
    assert.are.equal(2, started)
  end)
end)
