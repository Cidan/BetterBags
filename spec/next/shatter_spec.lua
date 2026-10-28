-- shatter_spec.lua -- NextShatter (next/shatter.lua): a Next theme's panel breaking into shards of ice and freezing
-- together from them (Panel.Shatter, next-themes.md §22; the Frost theme). The body is cut into triangles that tile
-- it exactly, each a texture whose corners are moved onto its triangle (SetVertexOffset) and whose art is the body's
-- own fill, mapped where it lies (SetTexCoord's eight numbers), with frost over it; the seams between them are the
-- cracks. Opening: the shards fly in and lock into place, the seams flash, the panel shows under them as they thaw
-- away. Closing: frost spreads over the panel, cracks run along the seams out from where it breaks, and it shatters.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextShatter", "next/shatter.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end
local shatter = addon:GetModule("NextShatter")

-- Blizzard's vertex indices (Blizzard_FrameXMLBase/Constants.lua).
local UL, LL, UR, LR = 1, 2, 3, 4

local SHATTER = {
  Shards = { Size = 100, Jitter = 0.3, Texture = "Body", Color = "White", Alpha = 1 },
  Frost = { Texture = "Frost", Color = "White", Alpha = 0.6, BlendMode = "ADD" },
  Seams = { Texture = "Thread", Color = "White", Alpha = 0.9, Thickness = 2, BlendMode = "ADD" },
  Open = { Time = 0.4, Stagger = 0.2, Clear = 0.3, Spread = { 100, 200 }, Spin = 90, Flash = true },
  Close = { Frost = 0.2, Crack = 0.1, Time = 0.6, Speed = { 200, 400 }, Spin = 360, Gravity = 900, Lift = 100 },
}

local function copy(t)
  local out = {}
  for k, v in pairs(t) do
    out[k] = type(v) == "table" and copy(v) or v
  end
  return out
end

local function theme(spec)
  UseNextTheme({
    Textures = { Body = "body.png", Frost = "frost.png", Thread = "thread.png" },
    Panel = { Shatter = spec },
  })
end

-- The corners a texture draws at: its rect's corners (anchored at the layer's bottom left, 1 x 1) moved by its offsets.
local function corners(t)
  local natural = { [UL] = { 0, 1 }, [LL] = { 0, 0 }, [UR] = { 1, 1 }, [LR] = { 1, 0 } }
  local out = {}
  for i = 1, 4 do
    local x, y = t:GetVertexOffset(i)
    out[i] = { natural[i][1] + x, natural[i][2] + y }
  end
  return out
end

local function near(a, b, eps)
  return math.abs(a - b) <= (eps or 1e-6)
end

local function area(a, b, c)
  return math.abs((b[1] - a[1]) * (c[2] - a[2]) - (c[1] - a[1]) * (b[2] - a[2])) / 2
end

describe("NextShatter", function()
  local savedRandom, savedCombat

  -- panelOn makes what the shatter reads of a panel: its body's rect on the screen (left 1000, top 900, 400 x 600, at
  -- scale 1) and its fill's (reaching 66 past the body on its screen-edge side).
  local function panelOn(fill)
    local frame = CreateFrame("Frame", nil, UIParent)
    local panel = { frame = frame, side = "RIGHT" }
    function panel:BodyRect() return 1000, 900, 600, 400, 1 end
    function panel:FillRect()
      if fill then return 1000, 900, 466, 600 end
      return nil
    end
    return panel
  end

  before_each(function()
    savedRandom = shatter.Random
    local seed = 1
    -- A fixed sequence, so every run is the same.
    shatter.Random = function()
      seed = (seed * 16807) % 2147483647
      return seed / 2147483647
    end
    savedCombat = _G.InCombatLockdown
    _G.InCombatLockdown = function() return false end
    shatter:Init()
    theme(copy(SHATTER))
  end)

  after_each(function()
    shatter.Random = savedRandom
    _G.InCombatLockdown = savedCombat
    shatter:Init()
    UseNextTheme(nil)
  end)

  describe("the theme's spec", function()
    it("says whether panels freeze together on opening and shatter on closing", function()
      assert.is_true(shatter:Opens())
      assert.is_true(shatter:Closes())
      local spec = copy(SHATTER)
      spec.Open = nil
      theme(spec)
      assert.is_false(shatter:Opens())
      assert.is_true(shatter:Closes())
      UseNextTheme({})
      assert.is_nil(shatter:Spec())
      assert.is_false(shatter:Opens())
      assert.is_false(shatter:Closes())
    end)
  end)

  -- The body cut into a grid of cells about Size across, its inner corners moved up to Jitter of a cell, each cell cut
  -- in two along a diagonal: triangles that tile it exactly, whatever the jitter.
  describe("the mesh", function()
    local RECT = { left = 1000, top = 900, width = 400, height = 600 }

    it("tiles the rect exactly with triangles, its corners where the rect's are", function()
      local mesh = shatter:Mesh(RECT, 100, 0.3)
      local total = 0
      for _, tri in ipairs(mesh.tris) do
        local a, b, c = mesh.verts[tri[1]], mesh.verts[tri[2]], mesh.verts[tri[3]]
        total = total + area({ a.x, a.y }, { b.x, b.y }, { c.x, c.y })
      end
      assert.is_true(near(total, 400 * 600, 1e-3), "the triangles cover the rect once: " .. total)
      -- 4 x 6 cells, two triangles each.
      assert.are.equal(48, #mesh.tris)
      local found = {}
      for _, v in ipairs(mesh.verts) do
        assert.is_true(v.x >= 1000 - 1e-9 and v.x <= 1400 + 1e-9 and v.y <= 900 + 1e-9 and v.y >= 300 - 1e-9)
        for _, corner in ipairs({ { 1000, 900 }, { 1400, 900 }, { 1000, 300 }, { 1400, 300 } }) do
          if near(v.x, corner[1]) and near(v.y, corner[2]) then
            found[corner[1] .. "," .. corner[2]] = true
          end
        end
      end
      assert.are.equal(4, (function() local n = 0 for _ in pairs(found) do n = n + 1 end return n end)())
    end)

    it("keeps the vertices on its edges on those edges, and moves the inner ones", function()
      local mesh = shatter:Mesh(RECT, 100, 0.3)
      local across, down = false, false
      for _, v in ipairs(mesh.verts) do
        local onSide = near(v.x, 1000) or near(v.x, 1400)
        local onEdge = near(v.y, 900) or near(v.y, 300)
        if not onSide and not onEdge then
          local gx, gy = (v.x - 1000) / 100, (900 - v.y) / 100
          across = across or not near(gx, math.floor(gx + 0.5))
          down = down or not near(gy, math.floor(gy + 0.5))
          assert.is_true(math.abs(gx - math.floor(gx + 0.5)) <= 0.3 + 1e-9)
        end
      end
      assert.is_true(across and down, "the inner vertices are jittered both ways")
      -- Cells are cut along either diagonal: a triangle with its corners at a cell's top left and bottom right, and one
      -- with its top right and bottom left.
      local cols = 5
      local both = {}
      for c = 0, 23 do
        local i, j = c % 4, math.floor(c / 4)
        local tl, br = j * cols + i + 1, (j + 1) * cols + i + 2
        local cut = false
        for _, tri in ipairs(mesh.tris) do
          local has = {}
          for k = 1, 3 do has[tri[k]] = true end
          if has[tl] and has[br] then cut = true end
        end
        both[cut] = true
      end
      assert.is_true(both[true] and both[false], "both diagonals")
    end)

    it("gives each vertex its place across the rect for the art", function()
      local mesh = shatter:Mesh(RECT, 100, 0.3)
      for _, v in ipairs(mesh.verts) do
        assert.is_true(near(v.u, (v.x - 1000) / 400) and near(v.v, (900 - v.y) / 600))
      end
    end)

    it("moves the inner vertex nearest a focus onto it, and orders the seams out from it", function()
      local mesh = shatter:Mesh(RECT, 100, 0.3, { x = 1190, y = 640 })
      -- Its neighbours are jittered a little only (0.15 of a cell), so none of its triangles folds over.
      for _, v in ipairs(mesh.verts) do
        local gx, gy = (v.x - 1000) / 100, (900 - v.y) / 100
        local i, j = math.floor(gx + 0.5), math.floor(gy + 0.5)
        if math.abs(i - 2) <= 1 and math.abs(j - 3) <= 1 and not (i == 2 and j == 3) then
          assert.is_true(math.abs(gx - i) <= 0.15 + 1e-9 and math.abs(gy - j) <= 0.15 + 1e-9, i .. "," .. j)
        end
      end
      local total = 0
      for _, tri in ipairs(mesh.tris) do
        local a, b, c = mesh.verts[tri[1]], mesh.verts[tri[2]], mesh.verts[tri[3]]
        total = total + area({ a.x, a.y }, { b.x, b.y }, { c.x, c.y })
      end
      assert.is_true(near(total, 400 * 600, 1e-3), "still tiling it with the focus moved: " .. total)
      local focus = mesh.verts[mesh.focus]
      assert.are.same({ 1190, 640 }, { focus.x, focus.y })
      -- The first seams start at the focus; each later one is no nearer to it, in seams.
      local first = mesh.edges[1]
      assert.is_true(first[1] == mesh.focus or first[2] == mesh.focus)
      for i = 2, #mesh.edges do
        assert.is_true(mesh.edges[i].rank >= mesh.edges[i - 1].rank)
      end
      -- Every edge of every triangle is a seam, once.
      local seams = {}
      for _, e in ipairs(mesh.edges) do
        local key = math.min(e[1], e[2]) .. "-" .. math.max(e[1], e[2])
        assert.is_nil(seams[key])
        seams[key] = true
      end
      for _, tri in ipairs(mesh.tris) do
        for k = 1, 3 do
          local a, b = tri[k], tri[k % 3 + 1]
          assert.is_true(seams[math.min(a, b) .. "-" .. math.max(a, b)])
        end
      end
    end)

    it("breaks from its middle without a focus, and makes one cell of a body smaller than a cell", function()
      local mesh = shatter:Mesh({ left = 0, top = 50, width = 40, height = 30 }, 100, 0.3)
      assert.are.equal(2, #mesh.tris)
      local whole = shatter:Mesh(RECT, 100, 0.3)
      local f = whole.verts[whole.focus]
      assert.is_true(math.abs(f.x - 1200) <= 100 and math.abs(f.y - 600) <= 100)
    end)
  end)

  describe("the layer", function()
    it("lies over the screen above the panels, takes no mouse, and is made once", function()
      local layer = shatter:Layer()
      assert.are.equal(UIParent, layer:GetParent())
      assert.are.equal("DIALOG", layer:GetFrameStrata())
      assert.is_false(layer:IsMouseEnabled())
      assert.are.equal(layer, shatter:Layer())
    end)
  end)

  -- A run: the shards of one panel's body, drawn on the layer.
  describe("a run", function()
    local function centroid(t)
      local c = corners(t)
      return (c[UL][1] + c[LL][1] + c[UR][1]) / 3, (c[UL][2] + c[LL][2] + c[UR][2]) / 3
    end

    it("draws each triangle twice on the layer: the body's art and frost over it, its corners on its triangle", function()
      local run = shatter:Begin(panelOn(false))
      assert.are.equal(48, #run.shards)
      for _, s in ipairs(run.shards) do
        local a, b, c = s.a, s.b, s.c
        for _, t in ipairs({ s.art, s.frost }) do
          assert.are.equal(shatter:Layer(), t:GetParent())
          local k = corners(t)
          assert.is_true(near(k[UL][1], a.x) and near(k[UL][2], a.y))
          assert.is_true(near(k[LL][1], b.x) and near(k[LL][2], b.y))
          assert.is_true(near(k[UR][1], c.x) and near(k[UR][2], c.y))
          -- The fourth corner on the third: a triangle.
          assert.is_true(near(k[LR][1], c.x) and near(k[LR][2], c.y))
          assert.is_false(t:IsSnappingToPixelGrid())
        end
        assert.are.equal("body.png", s.art:GetTexture())
        assert.are.equal("frost.png", s.frost:GetTexture())
        assert.are.equal("ADD", s.frost:GetBlendMode())
        -- The art where it lies on the body: u across, v down.
        assert.are.same({ a.u, a.v, b.u, b.v, c.u, c.v, c.u, c.v }, s.art._texCoords)
        assert.are.same({ a.u, a.v, b.u, b.v, c.u, c.v, c.u, c.v }, s.frost._texCoords)
      end
    end)

    it("maps its art over the fill's rect, which reaches past the body", function()
      local run = shatter:Begin(panelOn(true))
      for _, s in ipairs(run.shards) do
        assert.is_true(near(s.art._texCoords[1], (s.a.x - 1000) / 466))
        assert.is_true(near(s.art._texCoords[2], (900 - s.a.y) / 600))
        -- Frost over the body alone.
        assert.is_true(near(s.frost._texCoords[1], (s.a.x - 1000) / 400))
      end
    end)

    it("draws a seam for every edge between shards, hidden until it cracks", function()
      local run = shatter:Begin(panelOn(false))
      assert.is_true(#run.seams > 0)
      for _, line in ipairs(run.seams) do
        assert.are.equal("Line", line._type)
        assert.are.equal(2, line:GetThickness())
        assert.is_false(line:IsShown())
      end
    end)

    -- Opening: the shards fly in from around the body and lock into place, nearer the middle first; then the seams
    -- flash and fade, the frost thaws, and the panel shows under the shards as they go.
    describe("assembling", function()
      it("starts with every shard away from its place, unseen, and the panel unseen", function()
        local run = shatter:Begin(panelOn(false))
        local alpha = run:Assemble(0)
        assert.are.equal(0, alpha)
        local away = 0
        for _, s in ipairs(run.shards) do
          assert.are.equal(0, s.art:GetAlpha())
          local x, y = centroid(s.art)
          if math.abs(x - s.cx) > 50 or math.abs(y - s.cy) > 50 then
            away = away + 1
          end
        end
        assert.are.equal(#run.shards, away)
      end)

      it("locks every shard into its place once they have all flown", function()
        local run = shatter:Begin(panelOn(false))
        assert.are.equal(0, run:Assemble(0.6))
        for _, s in ipairs(run.shards) do
          local k = corners(s.art)
          assert.is_true(near(k[UL][1], s.a.x, 1e-6) and near(k[UL][2], s.a.y, 1e-6))
          assert.is_true(near(k[UR][1], s.c.x, 1e-6) and near(k[UR][2], s.c.y, 1e-6))
          assert.are.equal(1, s.art:GetAlpha())
        end
        for _, line in ipairs(run.seams) do
          assert.is_true(line:IsShown())
          assert.are.equal(0.9, line:GetAlpha())
        end
      end)

      it("brings the shards nearer the middle in first", function()
        local run = shatter:Begin(panelOn(false))
        run:Assemble(0.25)
        local nearest, farthest
        for _, s in ipairs(run.shards) do
          local d = math.sqrt((s.cx - 1200) ^ 2 + (s.cy - 600) ^ 2)
          if nearest == nil or d < nearest.d then nearest = { d = d, s = s } end
          if farthest == nil or d > farthest.d then farthest = { d = d, s = s } end
        end
        local function off(s)
          local x, y = centroid(s.art)
          return math.sqrt((x - s.cx) ^ 2 + (y - s.cy) ^ 2)
        end
        assert.is_true(off(nearest.s) < off(farthest.s))
      end)

      it("shows the panel under the shards as they thaw away, the seams fading with them", function()
        local run = shatter:Begin(panelOn(false))
        local mid = run:Assemble(0.75)
        assert.is_true(mid > 0 and mid < 1)
        assert.are.equal(1, run:Assemble(0.9))
        for _, s in ipairs(run.shards) do
          assert.is_true(near(s.art:GetAlpha(), 0, 1e-9))
          assert.is_true(near(s.frost:GetAlpha(), 0, 1e-9))
        end
        for _, line in ipairs(run.seams) do
          assert.is_true(near(line:GetAlpha(), 0, 1e-9))
        end
      end)

      -- Asked, of the seams flashing at the end of the open: "these lines, don't need to show". Only with Flash.
      it("shows no seams as its shards lock without Flash", function()
        local spec = copy(SHATTER)
        spec.Open.Flash = nil
        theme(spec)
        local run = shatter:Begin(panelOn(false))
        for _, t in ipairs({ 0.3, 0.6, 0.75, 0.9 }) do
          run:Assemble(t)
          for _, line in ipairs(run.seams) do
            assert.is_false(line:IsShown(), "at " .. t)
          end
        end
      end)

      it("catches the light as a shard turns: its frost brightest across a turn", function()
        local run = shatter:Begin(panelOn(false))
        -- Every shard seen by now (a third of its flight in), none locked yet.
        run:Assemble(0.35)
        local seen = {}
        for _, s in ipairs(run.shards) do
          seen[math.floor(s.frost:GetAlpha() * 100)] = true
        end
        local n = 0
        for _ in pairs(seen) do n = n + 1 end
        assert.is_true(n > 3, "shards at other turns catch other light")
      end)
    end)

    -- Opening out of a frost storm (asked: "a sort of... frost storm that grows from the bottom left to the top right and
    -- the bag appears ... almost like the bag appearing out of the frost storm"): its front sweeps across the body from a
    -- corner (mirrored on a panel whose inner side is on the right) to the one across, flakes curling in it and mist
    -- rolling with it; behind it the shards form where they lie; once it has crossed, the panel shows under them as the
    -- storm blows away.
    describe("a frost storm", function()
      local STORM = { From = "BOTTOMINNER", Appear = 0.1,
        Flakes = { Texture = "Frost", Count = 60, Size = { 6, 12 }, Life = { 0.3, 0.6 }, Speed = { 100, 200 },
          Swirl = 4, Spin = 180, Colors = { "White" }, Alpha = { 0.6, 1 }, BlendMode = "ADD" },
        Mist = { Texture = "Frost", Count = 10, Size = { 100, 160 }, Growth = 1.5, Life = { 0.3, 0.5 },
          Speed = { 40, 80 }, Color = "White", Alpha = 0.3, BlendMode = "ADD" } }

      local function stormy(from)
        local spec = copy(SHATTER)
        spec.Open = { Time = 0.5, Clear = 0.3, Storm = copy(STORM) }
        spec.Open.Storm.From = from or "BOTTOMINNER"
        theme(spec)
      end

      local function particles(run)
        local out = {}
        for _, p in ipairs(run.storm.particles) do
          if p.texture:IsShown() then table.insert(out, p) end
        end
        return out
      end

      local function middle(t)
        local point, rel, relPoint, x, y = t:GetPoint(1)
        assert.are.same({ "CENTER", shatter:Layer(), "BOTTOMLEFT" }, { point, rel, relPoint })
        return x, y
      end

      before_each(function()
        stormy()
      end)

      it("sweeps its front from the body's bottom inner corner, flakes and mist in it, the panel unseen", function()
        local run = shatter:Begin(panelOn(false))
        local alpha = 0
        for t = 0, 0.15, 0.05 do alpha = run:Assemble(t) end
        assert.are.equal(0, alpha)
        local flakes, mist = 0, 0
        for _, p in ipairs(particles(run)) do
          local x, y = middle(p.texture)
          -- Grown 0.3 of the way out of its bottom left corner (1000, 300) across a 400 x 600 body: near that corner.
          assert.is_true(x < 1000 + 250 and y < 300 + 350, "near the bottom left: " .. x .. ", " .. y)
          if p.mist then mist = mist + 1 else flakes = flakes + 1 end
        end
        assert.is_true(flakes > 5, "flakes: " .. flakes)
        assert.is_true(mist > 0, "mist: " .. mist)
      end)

      it("forms each shard as the storm reaches it: the nearer its corner, the sooner", function()
        local run = shatter:Begin(panelOn(false))
        for t = 0, 0.25, 0.05 do run:Assemble(t) end
        local nearest, farthest
        for _, sh in ipairs(run.shards) do
          local d = (sh.cx - 1000) ^ 2 + (sh.cy - 300) ^ 2
          if nearest == nil or d < nearest.d then nearest = { d = d, s = sh } end
          if farthest == nil or d > farthest.d then farthest = { d = d, s = sh } end
        end
        assert.are.equal(1, nearest.s.art:GetAlpha(), "formed behind the front")
        assert.are.equal(0, farthest.s.art:GetAlpha(), "not reached yet")
        -- A shard forms where it lies.
        local k = corners(nearest.s.art)
        assert.is_true(near(k[UL][1], nearest.s.a.x, 1e-6) and near(k[UL][2], nearest.s.a.y, 1e-6))
      end)

      it("has every shard formed once it has crossed, and shows the panel as the storm blows away", function()
        local run = shatter:Begin(panelOn(false))
        for t = 0, 0.55, 0.05 do run:Assemble(t) end
        run:Assemble(0.6)
        for _, sh in ipairs(run.shards) do
          assert.are.equal(1, sh.art:GetAlpha())
        end
        local mid = run:Assemble(0.75)
        assert.is_true(mid > 0 and mid < 1)
        assert.are.equal(1, run:Assemble(0.9))
        for _, p in ipairs(particles(run)) do
          assert.is_true(near(p.texture:GetAlpha(), 0, 1e-9), "the storm gone")
        end
      end)

      -- Each is born on the storm's front (a quarter circle round its corner, 0.8 to 1.05 of how far it has grown), inside
      -- the body, and first moves the frame after.
      it("sends its flakes and mist out from its front, inside the body", function()
        local run = shatter:Begin(panelOn(false))
        run:Assemble(0)
        run:Assemble(0.3)
        local reach = math.sqrt(400 ^ 2 + 600 ^ 2) * 0.6
        local n = 0
        for _, p in ipairs(particles(run)) do
          local x, y = middle(p.texture)
          assert.is_true(x >= 1000 and x <= 1400 and y >= 300 and y <= 900, "inside: " .. x .. ", " .. y)
          local r = math.sqrt((x - 1000) ^ 2 + (y - 300) ^ 2)
          assert.is_true(r >= 0.8 * reach - 1e-6 and r <= 1.05 * reach + 1e-6, "on the front: " .. r)
          n = n + 1
        end
        assert.is_true(n > 10)
      end)

      it("gives a flake back once its life is over", function()
        local run = shatter:Begin(panelOn(false))
        for t = 0, 0.55, 0.05 do run:Assemble(t) end
        for _, p in ipairs(run.storm.particles) do
          assert.is_true(p.age < p.life)
        end
        assert.is_true(run.storm.flakes + run.storm.mist > #run.storm.particles, "some given back already")
      end)

      it("lets its flakes curl and turn as they blow, its mist grow as it rolls", function()
        local run = shatter:Begin(panelOn(false))
        run:Assemble(0)
        run:Assemble(0.1)
        local flake, puff
        for _, p in ipairs(particles(run)) do
          if p.mist then puff = puff or p else flake = flake or p end
        end
        local x0, y0 = middle(flake.texture)
        local r0 = flake.texture:GetRotation()
        local s0 = puff.texture:GetWidth()
        run:Assemble(0.15)
        local x1, y1 = middle(flake.texture)
        assert.is_true(math.abs(x1 - x0) + math.abs(y1 - y0) > 1, "blowing")
        run:Assemble(0.2)
        local x2, y2 = middle(flake.texture)
        -- Curling: the way it heads turns from one step to the next.
        local a1, a2 = math.atan2(y1 - y0, x1 - x0), math.atan2(y2 - y1, x2 - x1)
        assert.is_true(math.abs(a2 - a1) > 0.05, "curling: " .. a1 .. " then " .. a2)
        assert.are_not.equal(r0, flake.texture:GetRotation())
        assert.is_true(puff.texture:GetWidth() > s0, "the mist growing")
      end)

      it("grows from the bottom right on a panel whose inner side is on the right", function()
        local panel = panelOn(false)
        panel.side = "LEFT"
        local run = shatter:Begin(panel)
        for t = 0, 0.15, 0.05 do run:Assemble(t) end
        for _, p in ipairs(particles(run)) do
          local x = middle(p.texture)
          assert.is_true(x > 1400 - 250, "near the bottom right: " .. x)
        end
      end)

      it("grows from the corner its theme names", function()
        stormy("TOPOUTER")
        local run = shatter:Begin(panelOn(false))
        for t = 0, 0.15, 0.05 do run:Assemble(t) end
        for _, p in ipairs(particles(run)) do
          local x, y = middle(p.texture)
          assert.is_true(x > 1400 - 250 and y > 900 - 350, "near the top right: " .. x .. ", " .. y)
        end
      end)

      it("never shows its seams without Flash, and flashes them with it", function()
        local run = shatter:Begin(panelOn(false))
        for t = 0, 0.9, 0.05 do
          run:Assemble(t)
          for _, line in ipairs(run.seams) do
            assert.is_false(line:IsShown())
          end
        end
        local spec = copy(SHATTER)
        spec.Open = { Time = 0.5, Clear = 0.3, Flash = true, Storm = copy(STORM) }
        theme(spec)
        local flashed = shatter:Begin(panelOn(false))
        flashed:Assemble(0)
        flashed:Assemble(0.6)
        assert.is_true(flashed.seams[1]:IsShown())
      end)

      it("gives its storm back when released, and reuses it", function()
        local run = shatter:Begin(panelOn(false))
        for t = 0, 0.3, 0.05 do run:Assemble(t) end
        local shown = particles(run)
        assert.is_true(#shown > 0)
        run:Release()
        for _, p in ipairs(shown) do
          assert.is_false(p.texture:IsShown())
        end
        local made = #shatter:Layer()._textures
        local again = shatter:Begin(panelOn(false))
        for t = 0, 0.3, 0.05 do again:Assemble(t) end
        assert.are.equal(made, #shatter:Layer()._textures, "no texture made again")
      end)

      it("says how long its open takes to lock and in all", function()
        assert.is_true(near(shatter:OpenLock(), 0.6))
        assert.is_true(near(shatter:OpenTime(), 0.9))
        theme(copy(SHATTER))
        assert.is_true(near(shatter:OpenLock(), 0.6))
        assert.is_true(near(shatter:OpenTime(), 0.9))
      end)
    end)

    -- Closing: frost spreads over the body (the shards' frost, their art unseen: the panel shows under it), cracks run
    -- along the seams out from where it breaks, then it shatters.
    describe("freezing", function()
      it("frosts the body over, the panel still showing", function()
        local run = shatter:Begin(panelOn(false), { x = 1190, y = 640 })
        assert.are.equal(1, run:Freeze(0))
        for _, s in ipairs(run.shards) do
          assert.are.equal(0, s.frost:GetAlpha())
          assert.are.equal(0, s.art:GetAlpha())
        end
        assert.are.equal(1, run:Freeze(0.1))
        for _, s in ipairs(run.shards) do
          assert.is_true(near(s.frost:GetAlpha(), 0.3))
        end
        run:Freeze(0.2)
        for _, s in ipairs(run.shards) do
          assert.is_true(near(s.frost:GetAlpha(), 0.6))
        end
      end)

      it("cracks along the seams out from where it breaks", function()
        local run = shatter:Begin(panelOn(false), { x = 1190, y = 640 })
        run:Freeze(0.2)
        for _, line in ipairs(run.seams) do
          assert.is_false(line:IsShown())
        end
        run:Freeze(0.25)
        local shown, ranks = 0, {}
        for i, line in ipairs(run.seams) do
          if line:IsShown() then
            shown = shown + 1
            table.insert(ranks, run.mesh.edges[i].rank)
          end
        end
        assert.is_true(shown > 0 and shown < #run.seams, "half way, some cracks")
        local maxShown = math.max(unpack(ranks))
        for i, line in ipairs(run.seams) do
          if not line:IsShown() then
            assert.is_true(run.mesh.edges[i].rank >= maxShown)
          end
        end
        run:Freeze(0.3)
        for _, line in ipairs(run.seams) do
          assert.is_true(line:IsShown())
        end
      end)
    end)

    describe("shattering", function()
      local function fly(seconds)
        local d = shatter:Layer().driver
        local steps = math.floor(seconds / 0.05 + 0.5)
        for _ = 1, steps do
          -- The driver stops once nothing flies.
          local update = d:GetScript("OnUpdate")
          if update == nil then return end
          update(d, 0.05)
        end
      end

      it("shows the shards whole, hides the seams, and flies them apart from where it broke", function()
        local run = shatter:Begin(panelOn(false), { x = 1190, y = 640 })
        run:Freeze(0.3)
        run:Shatter()
        for _, s in ipairs(run.shards) do
          assert.are.equal(1, s.art:GetAlpha())
        end
        for _, line in ipairs(run.seams) do
          assert.is_false(line:IsShown())
        end
        fly(0.1)
        local outward = 0
        for _, s in ipairs(run.shards) do
          local x, y = centroid(s.art)
          local before = (s.cx - 1190) ^ 2 + (s.cy - 640) ^ 2
          local after = (x - 1190) ^ 2 + (y - 640) ^ 2
          if after > before then outward = outward + 1 end
        end
        assert.is_true(outward >= #run.shards * 0.9, outward .. " of " .. #run.shards .. " fly outward")
      end)

      it("lets them fall, turn and fade, and gives everything back at the end", function()
        local run = shatter:Begin(panelOn(false), { x = 1190, y = 640 })
        run:Shatter()
        local s = run.shards[1]
        local _, y0 = centroid(s.art)
        fly(0.1)
        local _, y1 = centroid(s.art)
        fly(0.1)
        local _, y2 = centroid(s.art)
        -- Gravity: each tenth of a second it goes down further (or up less) than the one before.
        assert.is_true((y2 - y1) < (y1 - y0) - 1, "falling")
        fly(0.1)
        local turned = corners(s.art)
        assert.is_true(s.art:GetAlpha() < 1)
        assert.is_false(near(turned[UL][1] - turned[LL][1], s.a.x - s.b.x, 1e-3), "turned")
        local art = s.art
        fly(0.4)
        assert.is_false(art:IsShown())
        assert.is_nil(shatter:Layer().driver:GetScript("OnUpdate"), "the driver stops with nothing flying")
        assert.are.equal(0, #run.shards)
      end)

      it("keeps flying while another run begins, and reuses what a run gave back", function()
        local first = shatter:Begin(panelOn(false))
        first:Shatter()
        local second = shatter:Begin(panelOn(false))
        assert.are.equal(48, #second.shards)
        fly(0.7)
        assert.are.equal(0, #first.shards)
        local made = #shatter:Layer()._textures
        second:Release()
        shatter:Begin(panelOn(false))
        assert.are.equal(made, #shatter:Layer()._textures, "no texture made again")
      end)
    end)

    it("draws a pooled texture in its spec again only once a theme has changed it", function()
      local run = shatter:Begin(panelOn(false))
      local art = run.shards[1].art
      run:Release()
      local painted = 0
      local paint = art.SetTexture
      art.SetTexture = function(t, ...)
        painted = painted + 1
        return paint(t, ...)
      end
      shatter:Begin(panelOn(false)):Release()
      assert.are.equal(0, painted, "the same spec: not drawn again")
      local spec = copy(SHATTER)
      spec.Shards.Texture = "Frost"
      theme(spec)
      shatter:Begin(panelOn(false))
      assert.are.equal(1, painted)
      assert.are.equal("frost.png", art:GetTexture())
    end)

    it("gives everything back at once when released", function()
      local run = shatter:Begin(panelOn(false))
      run:Assemble(0.3)
      local art, seam = run.shards[1].art, run.seams[1]
      run:Release()
      assert.is_false(art:IsShown())
      assert.is_false(seam:IsShown())
      assert.are.equal(0, #run.shards)
      run:Release()
    end)
  end)
end)
