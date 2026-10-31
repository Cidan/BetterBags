-- paper_spec.lua -- NextPaper (next/paper.lua): a Next theme's panel as a sheet of paper (Panel.Paper, next-themes.md §25;
-- the Papercraft theme; asked: "the open animation should be the bags 'unfolding' in two parts (1/4th square, unfold into
-- half, unfold into full), and the close animation should it being crumbled up like a paper ball and being tossed up
-- slightly, then falling off the screen ... the animations? should be stop-motion esque. meaning they are not just
-- staggered in that stop motion FPS, but imperfect in their placement from frame to frame"). A run is one panel's sheet
-- on the paper layer, over every panel: a lattice of cells whose corners are moved where the fold or the crumple puts
-- them, drawn a pose at a time.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

for _, m in ipairs({
  { "NextStyle", "next/style.lua" },
  { "NextTween", "next/tween.lua" },
  { "NextStopMotion", "next/stopmotion.lua" },
  { "NextShatter", "next/shatter.lua" },
  { "NextPaper", "next/paper.lua" },
}) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end
local paper = addon:GetModule("NextPaper")
local shatter = addon:GetModule("NextShatter")

local function copy(t)
  local out = {}
  for k, v in pairs(t) do
    out[k] = type(v) == "table" and copy(v) or v
  end
  return out
end

local PAPER = {
  Front = { Texture = "Front", Color = "White" },
  Back = { Texture = "Back", Color = "White" },
  Edge = { Texture = "EdgeArt", Width = 10, Inside = 2, Tile = 64 },
  Shadow = { Texture = "ShadowArt", Color = "Black", Alpha = 0.4, Spread = 8, X = 2, Y = -3 },
  Rate = 10,
  Wobble = { Move = 2, Turn = 1, Vertex = 1, Pose = 5 },
  Open = {
    From = "TOPOUTER", Cells = 2, Curl = 0, Depth = 0, Lit = 0.5, Reveal = 2,
    Quarter = { { Scale = 1.2 }, {} },
    Half = { 120, 60, 0 },
    Full = { 120, 60, 0 },
    Note = { { Texture = "NoteArt", Color = "Black", Alpha = 0.8, Width = 40, Height = 20, X = 0, Y = 10 } },
  },
  Close = {
    Grab = 2, Tremble = 3, Cell = 100, Jitter = 0, Ball = 40, Lump = 0, Wrinkle = 0, Wrap = 0.9, Lag = 0, Lit = 0.5,
    Twist = 0, Poses = { 0.25, 0.5, 0.75, 1 },
    Toss = { Up = 300, Gravity = 1000, Drift = { 50, 50 }, Tumble = { 2, 2 }, Life = 3 },
  },
}

-- The poses a Spec paper's open runs through, at Rate 10: Quarter 0 and 1, Half 2 to 4, Full 5 to 7.
local LOCK = 8 / 10

describe("NextPaper", function()
  local savedRandom, savedShatterRandom
  local panel

  local function theme(spec, motion)
    UseNextTheme({
      Textures = { Front = "front.png", Back = "back.png", EdgeArt = "edge.png", ShadowArt = "shadow.png",
        NoteArt = "note.png" },
      Motion = motion,
      Panel = { Paper = spec },
    })
  end

  -- A sheet with no wobble, for exact places.
  local function still()
    local spec = copy(PAPER)
    spec.Wobble = nil
    return spec
  end

  -- What the paper reads of a panel: its body's rect on the screen (left 1000, top 900, 400 x 600, so down to 300), at a
  -- scale, its fill over the same rect, the side of the screen it belongs to.
  local function panelOn(side, scale)
    return {
      side = side or "RIGHT",
      BodyRect = function() return 1000, 900, 600, 400, scale or 1 end,
      FillRect = function() return 1000, 900, 400, 600 end,
    }
  end

  -- A texture's corners on the layer, from where its offsets moved a unit square at its bottom left: y up.
  local function corners(t)
    local ulx, uly = t:GetVertexOffset(1)
    local llx, lly = t:GetVertexOffset(2)
    local urx, ury = t:GetVertexOffset(3)
    local lrx, lry = t:GetVertexOffset(4)
    return { { ulx, uly + 1 }, { llx, lly }, { urx + 1, ury + 1 }, { lrx + 1, lry } }
  end

  -- The extent of the cells a run shows: the paper itself, without its edges or shadow.
  local function extent(run, keep)
    local left, right, bottom, top = math.huge, -math.huge, math.huge, -math.huge
    local shown = 0
    for _, cell in ipairs(run.cells) do
      if cell.texture:IsShown() and (keep == nil or keep(cell)) then
        shown = shown + 1
        for _, p in ipairs(corners(cell.texture)) do
          left, right = math.min(left, p[1]), math.max(right, p[1])
          bottom, top = math.min(bottom, p[2]), math.max(top, p[2])
        end
      end
    end
    return left, right, bottom, top, shown
  end

  local function near(a, b, eps)
    return math.abs(a - b) <= (eps or 1e-6)
  end

  local function assertExtent(run, l, r, b, t, eps)
    local left, right, bottom, top = extent(run)
    assert.is_true(near(left, l, eps), "left " .. left .. ", not " .. l)
    assert.is_true(near(right, r, eps), "right " .. right .. ", not " .. r)
    assert.is_true(near(bottom, b, eps), "bottom " .. bottom .. ", not " .. b)
    assert.is_true(near(top, t, eps), "top " .. top .. ", not " .. t)
  end

  before_each(function()
    savedRandom, savedShatterRandom = paper.Random, shatter.Random
    local seed = 7
    local function random()
      seed = (seed * 16807) % 2147483647
      return seed / 2147483647
    end
    paper.Random, shatter.Random = random, random
    paper:Init()
    shatter:Init()
    panel = panelOn()
    theme(still())
  end)

  after_each(function()
    paper:Init()
    paper.Random, shatter.Random = savedRandom, savedShatterRandom
    UseNextTheme()
  end)

  describe("the theme's say", function()
    it("has none under a theme without one", function()
      UseNextTheme()
      assert.is_nil(paper:Spec())
      assert.is_false(paper:Opens())
      assert.is_false(paper:Closes())
    end)

    it("opens with an Open, closes with a Close", function()
      assert.is_true(paper:Opens())
      assert.is_true(paper:Closes())
      local spec = still()
      spec.Open = nil
      theme(spec)
      assert.is_false(paper:Opens())
      assert.is_true(paper:Closes())
    end)

    it("takes its time from its poses and Rate", function()
      assert.is_true(near(paper:OpenLock(), LOCK))
      assert.is_true(near(paper:OpenTime(), LOCK))
      assert.is_true(near(paper:GrabTime(), 2 / 10))
    end)
  end)

  describe("the layer", function()
    it("is over the screen, above the panels, taking no mouse", function()
      local layer = paper:Layer()
      assert.are.equal("DIALOG", layer:GetFrameStrata())
      assert.is_false(layer:IsMouseEnabled())
      assert.are.equal(layer, paper:Layer())
    end)
  end)

  describe("unfolding", function()
    local run

    before_each(function()
      run = paper:Begin(panel, "Open")
    end)

    after_each(function()
      run:Release()
    end)

    -- Each pose t seconds in: the first of Quarter at 0, of Half at 0.2, of Full at 0.5.
    it("starts as a quarter of the sheet, in its From corner, a little big as it drops", function()
      run:Unfold(0)
      -- Top right of the body: 1200..1400 across, 600..900 down; its middle at 1300, 750; scaled by 1.2.
      assertExtent(run, 1300 - 120, 1300 + 120, 750 - 180, 750 + 180)
    end)

    it("lies a quarter of the sheet once dropped", function()
      run:Unfold(0.1)
      assertExtent(run, 1200, 1400, 600, 900)
    end)

    it("swings its flap out across the first fold, into half the sheet", function()
      run:Unfold(0.2) -- 120 degrees: past the hinge at 1200, 200 * cos(120) = -100 of it: over the quarter.
      local left, right = extent(run)
      assert.is_true(near(right, 1400))
      assert.is_true(near(left, 1200), "the flap is still over the quarter")
      run:Unfold(0.3) -- 60 degrees: 100 out from the hinge.
      left, right = extent(run)
      assert.is_true(near(left, 1100), "left " .. left)
      assert.is_true(near(right, 1400))
      run:Unfold(0.4) -- Flat: the top half of the sheet.
      assertExtent(run, 1000, 1400, 600, 900)
    end)

    it("swings the rest down across the second fold, into the whole sheet", function()
      run:Unfold(0.5) -- 120 degrees: 300 * cos(120) above the hinge at 600.
      local _, _, bottom = extent(run)
      assert.is_true(near(bottom, 600), "still over the top half")
      run:Unfold(0.6) -- 60 degrees: 150 below the hinge.
      _, _, bottom = extent(run)
      assert.is_true(near(bottom, 450), "bottom " .. bottom)
      run:Unfold(0.7) -- Flat: the whole sheet.
      assertExtent(run, 1000, 1400, 300, 900)
    end)

    it("shows the paper's back until the last fold's flap comes past upright", function()
      local function files()
        local front, back = 0, 0
        for _, cell in ipairs(run.cells) do
          if cell.texture:IsShown() then
            if cell.texture:GetTexture() == "front.png" then front = front + 1 else back = back + 1 end
          end
        end
        return front, back
      end
      run:Unfold(0.1)
      local front, back = files()
      assert.are.equal(0, front)
      assert.is_true(back > 0)
      run:Unfold(0.3)
      front = files()
      assert.are.equal(0, front, "folded in half, the paper's back shows on both sides of the fold")
      run:Unfold(0.5) -- Past upright: the fronts under it uncovered, its back to the viewer.
      front, back = files()
      assert.is_true(front > 0, "the top half uncovered")
      assert.is_true(back > 0, "the flap's back")
      run:Unfold(0.6) -- Before upright: its front to the viewer.
      front, back = files()
      assert.are.equal(0, back)
      assert.is_true(front > 0)
    end)

    it("shows the side of the swinging flap that faces the viewer: one half of it past upright, the other before", function()
      local function flap(lower)
        local n = 0
        for _, cell in ipairs(run.cells) do
          if cell.i >= 2 and (cell.j >= 2) == lower and cell.texture:IsShown() then
            n = n + 1
          end
        end
        return n
      end
      run:Unfold(0.2) -- 120 degrees: still over the sheet, the second fold's outside showing.
      assert.are.equal(0, flap(true))
      assert.is_true(flap(false) > 0)
      run:Unfold(0.3) -- 60 degrees: past upright.
      assert.are.equal(0, flap(false))
      assert.is_true(flap(true) > 0)
    end)

    it("maps the front of the sheet over the panel's fill, so it lies exactly where the fill is", function()
      run:Unfold(0.7)
      for _, cell in ipairs(run.cells) do
        assert.is_true(cell.texture:IsShown())
        local c = corners(cell.texture)
        local ulx, uly, llx, lly, urx, ury, lrx, lry = cell.texture:GetTexCoord()
        for i, uv in ipairs({ { ulx, uly }, { llx, lly }, { urx, ury }, { lrx, lry } }) do
          assert.is_true(near(uv[1], (c[i][1] - 1000) / 400), "u")
          assert.is_true(near(uv[2], (900 - c[i][2]) / 600), "v")
        end
      end
    end)

    it("keeps every quad the right way round, whichever way the paper has flipped: the client may cull a reversed one", function()
      for _, t in ipairs({ 0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7 }) do
        run:Unfold(t)
        for _, cell in ipairs(run.cells) do
          if cell.texture:IsShown() then
            local c = corners(cell.texture)
            local ax, ay = c[2][1] - c[1][1], c[2][2] - c[1][2]
            local bx, by = c[3][1] - c[1][1], c[3][2] - c[1][2]
            assert.is_true(ax * by - ay * bx >= -1e-6, "reversed at " .. t)
          end
        end
      end
    end)

    it("shades a flap as it turns from the light", function()
      run:Unfold(0.3)
      local lit, shaded = nil, nil
      for _, cell in ipairs(run.cells) do
        if cell.texture:IsShown() then
          local r = cell.texture:GetVertexColor()
          if cell.flap then shaded = r else lit = r end
        end
      end
      assert.is_true(near(lit, 1), "the part lying flat")
      assert.is_true(shaded < lit, "the flap")
      assert.is_true(near(shaded, 0.5 + 0.5 * math.cos(math.rad(60))), "Lit, and the rest by its angle")
    end)

    it("casts a shadow under what shows, and under a flap as it lifts", function()
      run:Unfold(0.1)
      assert.is_true(run.shadow:IsShown())
      assert.is_true(near(run.flapShadow:GetAlpha(), 0), "a flap lying down casts none")
      run:Unfold(0.3)
      assert.is_true(run.flapShadow:IsShown())
      assert.is_true(run.flapShadow:GetAlpha() > 0)
      run:Unfold(0.7)
      assert.is_true(near(run.flapShadow:GetAlpha(), 0))
    end)

    it("draws the note on the outside of the folded sheet, and only while that side shows", function()
      local note = run.notes[1]
      run:Unfold(0.1)
      assert.is_true(note.texture:IsShown())
      local c = corners(note.texture)
      -- Centered on the quarter (1300, 750), Y down by 10.
      assert.is_true(near(math.min(c[1][1], c[2][1], c[3][1], c[4][1]), 1280))
      assert.is_true(near(math.max(c[1][1], c[2][1], c[3][1], c[4][1]), 1320))
      assert.is_true(near(math.max(c[1][2], c[2][2], c[3][2], c[4][2]), 750))
      assert.is_true(near(math.min(c[1][2], c[2][2], c[3][2], c[4][2]), 730))
      run:Unfold(0.3)
      assert.is_false(note.texture:IsShown(), "past upright, that side faces the quarter")
    end)

    it("draws torn edges round what shows, and none along a fold", function()
      run:Unfold(0.7)
      local shown = 0
      for _, edge in ipairs(run.edges) do
        if edge.texture:IsShown() then shown = shown + 1 end
      end
      assert.are.equal(16, #run.edges, "two cells a half, four sides")
      assert.are.equal(16, shown, "the whole sheet: all its sides")
      run:Unfold(0.1)
      shown = 0
      for _, edge in ipairs(run.edges) do
        if edge.texture:IsShown() then shown = shown + 1 end
      end
      assert.is_true(shown > 0 and shown < 16)
    end)

    it("repeats the torn edge's art along the sheet in its Tile", function()
      run:Unfold(0.7)
      local edge = run.edges[1]
      local ulx, _, _, _, urx = edge.texture:GetTexCoord()
      -- A cell is 100 across and 150 down: that many repeats of a Tile of 64.
      assert.is_true(near(math.abs(urx - ulx), 100 / 64) or near(math.abs(urx - ulx), 150 / 64))
    end)

    it("says the panel is unseen until the last pose, then whole", function()
      assert.are.equal(0, run:Unfold(0))
      assert.are.equal(0, run:Unfold(0.7))
      assert.are.equal(1, run:Unfold(LOCK))
    end)

    it("lies flat from its last pose on, exactly where the body is", function()
      theme(PAPER, { StopMotion = { FPS = 10 } })
      local wobbly = paper:Begin(panel, "Open")
      wobbly:Unfold(LOCK)
      assertExtent(wobbly, 1000, 1400, 300, 900)
      wobbly:Release()
    end)

    it("from the other side of the screen, its From corner is mirrored", function()
      local left = paper:Begin(panelOn("LEFT"), "Open")
      left:Unfold(0.1)
      assertExtent(left, 1000, 1200, 600, 900)
      left:Unfold(0.3)
      local _, r = extent(left)
      assert.is_true(near(r, 1300), "swinging out to the right")
      left:Release()
    end)

    it("takes its From corner from the theme", function()
      local spec = still()
      spec.Open.From = "BOTTOMINNER"
      theme(spec)
      local other = paper:Begin(panel, "Open")
      other:Unfold(0.1)
      assertExtent(other, 1000, 1200, 300, 600)
      other:Release()
    end)

    it("bends a flap with Curl, and draws it nearer with Depth", function()
      local spec = still()
      spec.Open.Curl = 1
      theme(spec)
      local curled = paper:Begin(panel, "Open")
      curled:Unfold(0.3)
      local left = extent(curled)
      assert.is_true(left > 1100, "its far end still lifting")
      curled:Release()
      spec = still()
      spec.Open.Depth = 2
      theme(spec)
      local deep = paper:Begin(panel, "Open")
      deep:Unfold(0.3)
      local _, _, bottom, top = extent(deep)
      assert.is_true(top > 900 or bottom < 600, "its lifted end nearer the viewer, so larger")
      deep:Release()
    end)
  end)

  describe("as stop motion", function()
    local STOP = { StopMotion = { FPS = 10, Spacing = 0.3, Wobble = 1 } }

    local function snapshot(run)
      local out = {}
      for _, cell in ipairs(run.cells) do
        for _, p in ipairs(corners(cell.texture)) do
          table.insert(out, p[1])
          table.insert(out, p[2])
        end
      end
      return table.concat(out, ",")
    end

    it("holds a pose for its whole frame", function()
      theme(PAPER, STOP)
      local run = paper:Begin(panel, "Open")
      run:Unfold(0.31)
      local held = snapshot(run)
      run:Unfold(0.39)
      assert.are.equal(held, snapshot(run))
      run:Release()
    end)

    it("is placed a little differently each frame, the sheet and each corner of it", function()
      theme(PAPER, STOP)
      local run = paper:Begin(panel, "Open")
      run:Unfold(0.1)
      local a = snapshot(run)
      local la, ra = extent(run)
      assert.is_false(near(la, 1200, 0.001) and near(ra, 1400, 0.001), "not on its true place")
      -- Within what the wobble allows: moved, turned about its middle, each corner its own way.
      assert.is_true(near(la, 1200, 2 + 1 + math.rad(1) * 400))
      run:Unfold(0.0)
      assert.are_not.equal(a, snapshot(run))
      run:Release()
    end)

    it("moves each corner its own way, the sheet never tearing where its cells meet", function()
      local spec = copy(PAPER)
      spec.Wobble = { Vertex = 1 }
      theme(spec, STOP)
      local run = paper:Begin(panel, "Open")
      run:Unfold(0.1) -- A quarter of the sheet, 1200..1400 across: its cells 100 x 150.
      local moved = 0
      local byPlace = {}
      for _, cell in ipairs(run.cells) do
        if cell.texture:IsShown() then
          byPlace[cell.i .. "," .. cell.j] = cell
          for _, p in ipairs(corners(cell.texture)) do
            assert.is_true(math.abs(p[1] - math.floor(p[1] / 100 + 0.5) * 100) <= 1 + 1e-6, "by no more than Vertex")
            if not near(p[1], math.floor(p[1] / 100 + 0.5) * 100, 1e-6) then
              moved = moved + 1
            end
          end
        end
      end
      assert.is_true(moved > 4, "each corner off its true place")
      -- Folded in four, what shows of the first half across is the second half of it down.
      local a, b = byPlace["0,2"], byPlace["0,3"]
      assert.is_not_nil(a)
      assert.is_not_nil(b)
      assert.are.same(corners(a.texture)[2], corners(b.texture)[1], "a corner two cells share is one place")
      run:Release()
    end)

    it("draws a pose once, however many frames hold it", function()
      theme(PAPER, STOP)
      local run = paper:Begin(panel, "Open")
      local draws = 0
      local draw = run.drawFold
      run.drawFold = function(...)
        draws = draws + 1
        return draw(...)
      end
      run:Unfold(0.31)
      run:Unfold(0.35)
      run:Unfold(0.39)
      assert.are.equal(1, draws)
      run:Unfold(0.41)
      assert.are.equal(2, draws)
      run:Release()
    end)

    it("lands a frame's angle a little off its pose", function()
      theme(PAPER, STOP)
      local run = paper:Begin(panel, "Open")
      local angles = {}
      for i = 1, 40 do
        run.seed = i
        angles[run:PoseAngle(3)] = true
      end
      local count, off = 0, 0
      for angle in pairs(angles) do
        count = count + 1
        off = math.max(off, math.abs(angle - 60))
      end
      assert.is_true(count > 10, "a new one with each run's own noise")
      assert.is_true(off > 0 and off <= 5, "by up to its Pose")
      run:Release()
    end)

    it("holds its last pose of the fold exact, so the sheet lies flat", function()
      theme(PAPER, STOP)
      local run = paper:Begin(panel, "Open")
      assert.are.equal(0, run:PoseAngle(4))
      run:Release()
    end)

    it("without a stop motion, turns from the first fold to the second with the second's flap folded right over", function()
      theme(copy(PAPER))
      local run = paper:Begin(panel, "Open")
      local phase, angle
      local draw = run.drawFold
      run.drawFold = function(self, p, a, ...)
        phase, angle = p, a
        return draw(self, p, a, ...)
      end
      run:Unfold(0.45) -- Half way from the first fold's last pose (0) to the second's first (120): from 180 to 120.
      assert.are.equal("full", phase)
      assert.is_true(near(angle, 150), tostring(angle))
      run:Release()
    end)

    it("without a stop motion, runs between its poses every frame, with no wobble", function()
      local spec = copy(PAPER)
      theme(spec)
      local run = paper:Begin(panel, "Open")
      run:Unfold(0.35) -- Half way from 60 to 0 degrees: 30.
      local left = extent(run)
      assert.is_true(near(left, 1200 - 200 * math.cos(math.rad(30))), "left " .. left)
      run:Release()
    end)
  end)

  describe("revealing the panel", function()
    local function layerDriver()
      return paper:Layer().driver
    end

    it("goes a pose at a time as stop motion, held between", function()
      theme(PAPER, { StopMotion = { FPS = 10 } })
      local run = paper:Begin(panel, "Open")
      run:Unfold(LOCK)
      run:Linger()
      local update = layerDriver():GetScript("OnUpdate")
      local function alpha()
        return (select(4, run.cells[1].texture:GetVertexColor()))
      end
      update(layerDriver(), 0.04)
      assert.are.equal(1, alpha(), "its first pose: all of it")
      update(layerDriver(), 0.04)
      assert.are.equal(1, alpha(), "held")
      update(layerDriver(), 0.04)
      assert.is_true(near(alpha(), 0.5), "its second of two: half")
      run:Release()
    end)

    it("leaves the flat sheet over it for its Reveal, then gives everything back", function()
      local run = paper:Begin(panel, "Open")
      run:Unfold(LOCK)
      run:Linger()
      assert.is_true(paper.living[run])
      local update = layerDriver():GetScript("OnUpdate")
      assert.is_not_nil(update)
      update(layerDriver(), 0.1)
      local _, _, _, a = run.cells[1].texture:GetVertexColor()
      assert.is_true(a < 1 and a > 0, "fading in steps")
      update(layerDriver(), 0.1)
      assert.is_nil(paper.living[run])
      assert.is_nil(layerDriver():GetScript("OnUpdate"), "stopped with the last")
      assert.is_false(run.shadow and run.shadow:IsShown() or false)
    end)
  end)

  describe("its picture", function()
    it("loads a picture only when its texture draws another: a sheet turns every pose", function()
      local run = paper:Begin(panel, "Open")
      run:Unfold(0.3)
      local t = run.cells[#run.cells].texture
      for _, cell in ipairs(run.cells) do
        if cell.texture:IsShown() then
          t = cell.texture
        end
      end
      local loads = 0
      local load = t.SetTexture
      t.SetTexture = function(...)
        loads = loads + 1
        return load(...)
      end
      run:Unfold(0.35)
      assert.are.equal(0, loads)
      t.SetTexture = nil
      run:Release()
    end)

    it("loads it afresh on a texture from the pool, which may have to repeat along it", function()
      local spec = still()
      spec.Edge.Texture = "Front" -- The same file as the sheet, which does not repeat.
      theme(spec)
      local first = paper:Begin(panel, "Open")
      first:Unfold(LOCK)
      first:Release()
      local second = paper:Begin(panel, "Open")
      second:Unfold(LOCK)
      for _, edge in ipairs(second.edges) do
        assert.are.equal("REPEAT", edge.texture._wrapH)
      end
      for _, cell in ipairs(second.cells) do
        assert.is_nil(cell.texture._wrapH)
      end
      second:Release()
    end)
  end)

  describe("its pools", function()
    it("gives its textures back, and takes them again", function()
      local run = paper:Begin(panel, "Open")
      local first = run.cells[1].texture
      run:Unfold(0.3)
      run:Release()
      assert.is_false(first:IsShown())
      local pooled = #paper.pool
      assert.is_true(pooled > 0)
      local regions = select("#", paper:Layer():GetRegions())
      local again = paper:Begin(panel, "Open")
      assert.are.equal(regions, select("#", paper:Layer():GetRegions()), "the same sheet makes none")
      again:Release()
      assert.are.equal(pooled, #paper.pool)
    end)

    it("does nothing given back twice", function()
      local run = paper:Begin(panel, "Open")
      run:Release()
      local n = #paper.pool
      run:Release()
      assert.are.equal(n, #paper.pool)
    end)

    it("lets go of what lingers when it starts again", function()
      local run = paper:Begin(panel, "Open")
      run:Unfold(LOCK)
      run:Linger()
      paper:Init()
      assert.is_nil(next(paper.living))
      assert.are.equal(0, #run.cells, "given back")
    end)
  end)

  describe("crumpling", function()
    local run

    before_each(function()
      run = paper:Begin(panel, "Close")
    end)

    after_each(function()
      run:Release()
    end)

    local function driver()
      return paper:Layer().driver:GetScript("OnUpdate")
    end

    local function step(dt)
      local d = driver()
      if d ~= nil then d(paper:Layer().driver, dt) end
    end

    -- The extent of the triangles it shows.
    local function size()
      local left, right, bottom, top = math.huge, -math.huge, math.huge, -math.huge
      local shown = 0
      for _, tri in ipairs(run.tris) do
        if tri.texture:IsShown() then
          shown = shown + 1
          for _, p in ipairs(corners(tri.texture)) do
            left, right = math.min(left, p[1]), math.max(right, p[1])
            bottom, top = math.min(bottom, p[2]), math.max(top, p[2])
          end
        end
      end
      return right - left, top - bottom, (left + right) / 2, (top + bottom) / 2, shown
    end

    it("trembles where it stands as it is grabbed, weaker as it goes, and draws nothing yet", function()
      local a = run:Grab(0)
      local b = run:Grab(0.1)
      assert.is_true(math.abs(a) <= 3 and math.abs(b) <= 3)
      assert.are.equal(0, select(5, size()))
    end)

    it("shakes less and less, the same way all through a frame", function()
      run.noise = function() return 1 end
      assert.is_true(near(run:Grab(0), 3), "all of its Tremble")
      assert.is_true(near(run:Grab(0.05), 3), "held")
      assert.is_true(near(run:Grab(0.1), 1.5), "half way through the grab, half of it")
    end)

    it("cuts the sheet into triangles that tile the body", function()
      -- 400 / 100 by 600 / 100 cells, two triangles each.
      assert.are.equal(4 * 6 * 2, #run.tris)
    end)

    it("draws itself as the panel goes, and from then on on its own", function()
      run:Crumple()
      assert.is_true(paper.living[run])
      assert.is_not_nil(driver())
      assert.is_true(select(5, size()) > 0)
    end)

    it("shrinks pose by pose to a ball", function()
      run:Crumple()
      local width, height = size()
      for _ = 1, 3 do
        step(0.1)
        local w, h = size()
        assert.is_true(w < width, "narrower")
        assert.is_true(h < height, "shorter")
        width, height = w, h
      end
      local ballWidth, ballHeight = size()
      assert.is_true(near(ballWidth, 80, 16), "a ball Ball across each way: " .. ballWidth)
      assert.is_true(near(ballHeight, 80, 16), "a ball: " .. ballHeight)
    end)

    it("is tossed up a little, and falls off the screen under its Gravity", function()
      run:Crumple()
      for _ = 1, 3 do step(0.1) end
      local _, _, _, y0 = size()
      step(0.1)
      local _, _, x1, y1 = size()
      step(0.1)
      local _, _, x2, y2 = size()
      assert.is_true(y1 > y0, "up")
      assert.is_true(y2 > y1, "still rising, slower")
      assert.is_true(x2 ~= x1, "and drifting")
      local top = y2
      local fell = false
      for _ = 1, 60 do
        step(0.1)
        if paper.living[run] == nil then
          fell = true
          break
        end
        local _, _, _, y, shown = size()
        if shown > 0 then top = math.max(top, y) end
      end
      assert.is_true(top < y0 + 60, "tossed up only a little: 300^2 / 2000 = 45")
      assert.is_true(fell, "given back off the screen, within its Life")
    end)

    it("gives back the moment it is off the bottom of the screen, not before", function()
      run:Crumple()
      local lastY
      for _ = 1, 60 do
        step(0.1)
        if paper.living[run] == nil then break end
        local _, _, _, y = size()
        lastY = y
      end
      assert.is_nil(paper.living[run])
      assert.is_true(lastY > -80, "seen until it had gone: " .. lastY)
    end)

    it("gives back at its Life, wherever it is", function()
      local spec = still()
      spec.Close.Toss.Gravity = 0
      spec.Close.Toss.Up = 0
      spec.Close.Toss.Life = 1
      theme(spec)
      local floating = paper:Begin(panel, "Close")
      floating:Crumple()
      for _ = 1, 15 do step(0.1) end
      assert.is_nil(paper.living[floating])
      floating:Release()
    end)

    it("turns its faces away as it tumbles: some show the paper's back, and shade by their facing", function()
      run:Crumple()
      for _ = 1, 8 do step(0.1) end
      local shades = {}
      for _, tri in ipairs(run.tris) do
        if tri.texture:IsShown() then
          local r = tri.texture:GetVertexColor()
          shades[string.format("%.2f", r)] = true
        end
      end
      local n = 0
      for _ in pairs(shades) do n = n + 1 end
      assert.is_true(n > 4, "many shades on a ball's facets")
    end)

    it("shows the paper's back on a face turned from the viewer, and its front on one toward it", function()
      local function files()
        local seen = {}
        for _, tri in ipairs(run.tris) do
          if tri.texture:IsShown() then
            seen[tri.texture:GetTexture()] = true
          end
        end
        return seen
      end
      run:DrawCrumple(0, 0)
      assert.are.same({ ["front.png"] = true }, files())
      run.spinX, run.spinY = 0, math.pi
      run:DrawCrumple(0, 1) -- Turned right over, about its upright.
      assert.are.same({ ["back.png"] = true }, files())
    end)

    it("flecks its facets with Facet, more as it draws in", function()
      local function shades()
        local out = {}
        for i, tri in ipairs(run.tris) do
          tri.fleck = 0.1
          out[i] = 0
        end
        run:DrawCrumple(1, 0)
        for i, tri in ipairs(run.tris) do
          out[i] = tri.texture:GetVertexColor()
        end
        return out
      end
      run.spec.Close.Lit = 0.2
      local plain = shades()
      run.spec.Close.Facet = 0.5
      local flecked = shades()
      local checked = 0
      for i = 1, #plain do
        if plain[i] < 0.9 then
          checked = checked + 1
          assert.is_true(near(flecked[i], plain[i] + 0.05), "by Facet and the fleck")
        end
      end
      assert.is_true(checked > 0)
      run.spec.Close.Facet = nil
    end)

    it("tumbles toward the middle of the screen, whichever side it belongs to", function()
      assert.are.equal(-50, run.vx, "from the right of the screen: to the left")
      local left = paper:Begin(panelOn("LEFT"), "Close")
      assert.are.equal(50, left.vx, "from the left of the screen: to the right")
      left:Release()
    end)

    it("draws each pose of its crumple once, in its order, then the ball on its toss", function()
      theme(PAPER, { StopMotion = { FPS = 10 } })
      local moving = paper:Begin(panel, "Close")
      local seen = {}
      local draw = moving.DrawCrumple
      moving.DrawCrumple = function(self, c, toss)
        table.insert(seen, { c, toss })
        return draw(self, c, toss)
      end
      moving:Crumple()
      step(0.04)
      step(0.04)
      assert.are.equal(1, #seen, "held")
      step(0.04)
      assert.are.equal(2, #seen)
      for _ = 1, 2 do step(0.1) end
      assert.are.equal(4, #seen)
      assert.are.same({ 0.25, 0.5, 0.75, 1 }, { seen[1][1], seen[2][1], seen[3][1], seen[4][1] })
      step(0.1)
      assert.are.equal(1, seen[5][1])
      assert.is_true(near(seen[5][2], 0.1), "a frame into its toss")
      moving:Release()
    end)

    it("keeps every triangle the right way round", function()
      run:Crumple()
      for _ = 1, 10 do
        for _, tri in ipairs(run.tris) do
          if tri.texture:IsShown() then
            local c = corners(tri.texture)
            local ax, ay = c[2][1] - c[1][1], c[2][2] - c[1][2]
            local bx, by = c[3][1] - c[1][1], c[3][2] - c[1][2]
            assert.is_true(ax * by - ay * bx >= -1e-6)
          end
        end
        step(0.1)
      end
    end)

    it("draws nearer facets over farther ones", function()
      run:Crumple()
      for _ = 1, 5 do step(0.1) end
      local levels = {}
      for _, tri in ipairs(run.tris) do
        if tri.texture:IsShown() then
          local _, sub = tri.texture:GetDrawLayer()
          levels[sub] = true
        end
      end
      local n = 0
      for sub in pairs(levels) do
        n = n + 1
        assert.is_true(sub >= -8 and sub <= 7, "the client's sublevels")
      end
      assert.is_true(n > 2)
    end)

    it("draws torn edges along the sheet's sides as it crumples", function()
      run:Crumple()
      assert.are.equal(2 * (4 + 6), #run.edges)
      local shown = 0
      for _, edge in ipairs(run.edges) do
        if edge.texture:IsShown() then shown = shown + 1 end
      end
      assert.is_true(shown > 0)
    end)

    it("casts a shadow that goes as it draws in: a ball in the air casts none on the screen", function()
      run:DrawCrumple(0, 0)
      assert.is_true(run.shadow:IsShown())
      local _, _, _, full = run.shadow:GetVertexColor()
      assert.is_true(math.abs(full - 0.4) < 1e-6, "its own alpha")
      run:DrawCrumple(0.5, 0)
      local _, _, _, half = run.shadow:GetVertexColor()
      assert.is_true(half < full and half > 0)
      run:DrawCrumple(1, 0)
      assert.is_false(run.shadow:IsShown())
    end)

    it("makes its facets jagged with Jag, each corner its own way, most of all half way in", function()
      local spec = still()
      spec.Close.Jag = 10
      theme(spec)
      local jagged = paper:Begin(panel, "Close")
      local function offset(c)
        jagged:DrawCrumple(c, 0)
        local v = jagged.mesh.verts[10]
        local wx, wy = jagged:Warp(v.u, v.v, c)
        local at = jagged.lastAt[10]
        return math.abs(at.x - (jagged.cx + wx)) + math.abs(at.y - (jagged.cy + wy))
      end
      assert.is_true(offset(0) < 1e-6, "flat, it lies flat")
      assert.is_true(offset(0.5) > offset(1), "most jagged on the way")
      assert.is_true(offset(1) > 0, "a little still on the ball")
      jagged:Release()
    end)

    describe("where each point goes (Warp)", function()
      local function warp(u, v, c)
        return { run:Warp(u, v, c) }
      end

      local function apart(a, b)
        return math.abs(a[1] - b[1]) + math.abs(a[2] - b[2]) + math.abs(a[3] - b[3])
      end

      it("starts with the sheet's edges (Lag), a point near its middle not yet moving", function()
        run.spec.Close.Lag = 0.6
        local flat = warp(0.5, 0.4, 0)
        assert.is_true(apart(warp(0.5, 0.4, 0.3), flat) < 1e-9, "near its middle: still")
        assert.is_true(apart(warp(0, 0, 0.3), warp(0, 0, 0)) > 1, "its corner: on its way")
        run.spec.Close.Lag = 0
      end)

      it("makes the ball no sphere (Lump)", function()
        local round = warp(0.2, 0.3, 1)
        run.spec.Close.Lump = 0.3
        assert.is_true(apart(warp(0.2, 0.3, 1), round) > 0.01)
        run.spec.Close.Lump = 0
      end)

      it("wrinkles on the way (Wrinkle), the sheet flat before and the ball clean after", function()
        local flat, half, ball = warp(0.2, 0.3, 0), warp(0.2, 0.3, 0.5), warp(0.2, 0.3, 1)
        run.spec.Close.Wrinkle = 20
        assert.is_true(apart(warp(0.2, 0.3, 0), flat) < 1e-9)
        assert.is_true(apart(warp(0.2, 0.3, 0.5), half) > 0.01)
        assert.is_true(apart(warp(0.2, 0.3, 1), ball) < 1e-9)
        run.spec.Close.Wrinkle = 0
      end)

      it("twists as it draws in (Twist), none while flat", function()
        local flat, ball = warp(0.2, 0.3, 0), warp(0.2, 0.3, 1)
        run.spec.Close.Twist = 0.5
        assert.is_true(apart(warp(0.2, 0.3, 0), flat) < 1e-9)
        local twisted = warp(0.2, 0.3, 1)
        local turned = math.atan2(twisted[2], twisted[1]) - math.atan2(ball[2], ball[1])
        assert.is_true(near(math.abs((turned + math.pi) % (2 * math.pi) - math.pi), 0.5, 1e-6), tostring(turned))
        run.spec.Close.Twist = 0
      end)
    end)

    it("keeps each run's spec, so a theme changing under a ball in flight is no error", function()
      run:Crumple()
      UseNextTheme()
      step(0.1)
      step(0.1)
      assert.is_true(paper.living[run])
    end)
  end)

  describe("what is printed on the sheet", function()
    local function decalPanel()
      local p = panelOn()
      p.PaperDecals = function()
        return { { left = 1100, top = 800, width = 44, height = 44, texture = 12345 },
          { left = 1200, top = 500, width = 44, height = 44, texture = 67890 },
          { left = 1340, top = 340, width = 44, height = 44, texture = 11111 } }
      end
      return p
    end

    local function bounds(t)
      local xs, ys = {}, {}
      for _, p in ipairs(corners(t)) do
        table.insert(xs, p[1])
        table.insert(ys, p[2])
      end
      return math.min(unpack(xs)), math.max(unpack(xs)), math.min(unpack(ys)), math.max(unpack(ys))
    end

    it("carries the panel's items on the sheet as it crumples", function()
      local run = paper:Begin(decalPanel(), "Close")
      run:Crumple()
      assert.are.equal(3, #run.decals)
      assert.are.equal(12345, run.decals[1].texture:GetTexture())
      local l, r, b, t = bounds(run.decals[1].texture)
      assert.is_true(r - l < 44 and t - b < 44 and r - l > 0, "crumpling with the sheet")
      run:Release()
    end)

    it("starts each item exactly where it was", function()
      local run = paper:Begin(decalPanel(), "Close")
      run:DrawCrumple(0, 0)
      local l, r, b, t = bounds(run.decals[2].texture)
      assert.is_true(near(l, 1200) and near(r, 1244), "across")
      assert.is_true(near(t, 500) and near(b, 456), "down")
      run:Release()
    end)

    it("hides what has wrapped behind as it draws in, the nearest its middle last, and none on the ball", function()
      local run = paper:Begin(decalPanel(), "Close")
      run:DrawCrumple(0.8, 0)
      assert.is_false(run.decals[3].texture:IsShown(), "far from the sheet's middle: wrapped behind it")
      assert.is_true(run.decals[2].texture:IsShown(), "near its middle: still on its face")
      run:DrawCrumple(1, 0)
      for _, decal in ipairs(run.decals) do
        assert.is_false(decal.texture:IsShown(), "a clean ball: printed items on it read as stripes")
      end
      run:Release()
    end)

    it("hides what has turned from the viewer, wherever it lies", function()
      local run = paper:Begin(decalPanel(), "Close")
      run:DrawCrumple(0, 0)
      assert.is_true(run.decals[1].texture:IsShown())
      run.spinX, run.spinY = 0, math.pi
      run:DrawCrumple(0, 1)
      for _, decal in ipairs(run.decals) do
        assert.is_false(decal.texture:IsShown())
      end
      run:Release()
    end)

    it("gives them back with the run", function()
      local run = paper:Begin(decalPanel(), "Close")
      local t = run.decals[1].texture
      run:Release()
      assert.is_false(t:IsShown())
    end)
  end)
end)
