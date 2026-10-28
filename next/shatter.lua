local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

-- NextShatter breaks a Next panel's body into shards of ice and freezes it together from them (Panel.Shatter,
-- next-themes.md §22; the Frost theme; asked: "a cool blue and cold theme, icy in nature ... go crazy on the show and hide
-- animations"). The body is cut into triangles that tile it exactly (Mesh): a grid of cells about Shards.Size across,
-- its inner corners jittered, each cell cut along a diagonal. Each triangle is a texture whose four corners are moved
-- onto its three (SetVertexOffset, the fourth on the third), carrying the body's own fill where it lies on the body
-- (SetTexCoord's eight numbers), with a second over it carrying frost; the edges between them are the seams, Lines
-- that are its cracks. A run (Begin) is one panel's shards on the shatter layer, a frame over the screen above every
-- panel, so it shows over the panel's content and flies on once the panel has hidden. The panel drives it
-- (next/panel.lua): opening, it Assembles the shards, flying in from around the body and locking into place, the
-- seams flashing, the panel showing under them as they thaw away; closing, it Freezes (frost spreading over the panel,
-- then cracks running along the seams out from where it breaks) and Shatters (the panel gone, the shards flying apart
-- from there, turning as they fall and catching the light, fading). A theme without Panel.Shatter has none.
---@class NextShatter: AceModule
local shatter = addon:NewModule('NextShatter')

-- Where the shatter takes its randomness (a source of numbers in [0, 1)): replaced by the specs.
shatter.Random = math.random

-- The keys of Panel.Shatter, of its Open's Storm and the storm's flakes and mist, and the corners a storm grows from, for
-- SonataNext:Check.
shatter.KEYS = { Shards = true, Frost = true, Seams = true, Open = true, Close = true }
shatter.STORM_KEYS = { From = true, Appear = true, Flakes = true, Mist = true }
shatter.FLAKE_KEYS = { Texture = true, Count = true, Size = true, Life = true, Speed = true, Swirl = true, Spin = true,
  Colors = true, Alpha = true, BlendMode = true }
shatter.MIST_KEYS = { Texture = true, Count = true, Size = true, Growth = true, Life = true, Speed = true, Color = true,
  Alpha = true, BlendMode = true }
shatter.CORNERS = { BOTTOMINNER = true, BOTTOMOUTER = true, TOPINNER = true, TOPOUTER = true }

-- Blizzard's vertex indices (Blizzard_FrameXMLBase/Constants.lua, every client).
local UL, LL, UR, LR = 1, 2, 3, 4

-- How far a vertex next to the focus may be jittered, at most, as a share of a cell: the focus sits up to half a cell
-- from its vertex's place on the grid, and its triangles must not fold over.
local NEAR_FOCUS_JITTER = 0.15

-- A frost texture's light, as a share of its alpha, when a shard faces the viewer square on: turning, it catches more.
local GLINT_LOW = 0.4

---@class (exact) NextShatterVertex
---@field x number Where it is on the screen, in UIParent's units (y up).
---@field y number
---@field u number Where it is across the body, 0 to 1 from its left.
---@field v number Where it is down the body, 0 to 1 from its top.

---@class (exact) NextShatterMesh
---@field verts NextShatterVertex[]
---@field tris integer[][] Each triangle's three vertices.
---@field edges table[] Every seam once ({ a, b, rank }), nearest the focus first: rank is how many seams from it.
---@field focus integer The vertex it breaks from.

---@class NextShatterShard
---@field a NextShatterVertex
---@field b NextShatterVertex
---@field c NextShatterVertex
---@field cx number Its middle.
---@field cy number
---@field art Texture The body's fill on it.
---@field frost Texture Frost on it.

---@class (exact) NextShatterRun
---@field spec table The theme's Panel.Shatter it began with.
---@field mesh NextShatterMesh
---@field shards NextShatterShard[]
---@field seams Line[] Each edge's seam, as mesh.edges orders them.
---@field elapsed number How long it has flown.
local runProto = {}
addon:GetModule('Perf'):RegisterPrototype(runProto, 'NextShatterRun')

function shatter:Init()
  for run in pairs(self.flying or {}) do
    run:Release()
  end
  self.flying = {}
  self.storms = self.storms or {}
  self.arts = self.arts or {}
  self.frosts = self.frosts or {}
  self.lines = self.lines or {}
  if self.layer ~= nil then
    self.layer.driver:SetScript("OnUpdate", nil)
  end
end

-- Spec returns the theme's Panel.Shatter, nil without one.
---@return table?
function shatter:Spec()
  return style.Theme.Panel.Shatter or nil
end

-- OpenLock is how long the theme's open takes until its shards have all formed (its seams flash then with Flash, its threads draw
-- in and its sections cascade from then): a storm's crossing and a shard's forming, else the stagger and a shard's
-- flight. OpenTime is the whole open: that and its Clear.
---@return number
function shatter:OpenLock()
  local O = self:Spec().Open
  if O.Storm then
    return O.Time + (O.Storm.Appear or 0)
  end
  return (O.Stagger or 0) + O.Time
end

---@return number
function shatter:OpenTime()
  return self:OpenLock() + (self:Spec().Open.Clear or 0)
end

-- Opens says whether the theme's panels freeze together from shards as they open instead of sliding in; Closes,
-- whether they shatter as they close.
---@return boolean
function shatter:Opens()
  local S = self:Spec()
  return S ~= nil and S.Open ~= nil
end

---@return boolean
function shatter:Closes()
  local S = self:Spec()
  return S ~= nil and S.Close ~= nil
end

-- Layer returns the shatter layer, made the first time: a frame over the whole screen, in the DIALOG strata (above the
-- panels, HIGH), taking no mouse, with the driver that flies shattered shards.
---@return Frame
function shatter:Layer()
  if self.layer == nil then
    local layer = CreateFrame("Frame", nil, UIParent)
    layer:SetAllPoints(UIParent)
    layer:SetFrameStrata("DIALOG")
    layer:EnableMouse(false)
    layer.driver = CreateFrame("Frame", nil, layer)
    self.layer = layer
  end
  return self.layer
end

---@param range number[]
---@return number
local function between(range)
  return range[1] + (range[2] - range[1]) * shatter.Random()
end

---@param x number
---@return number
local function clamp01(x)
  return math.max(0, math.min(1, x))
end

---@param e0 number
---@param e1 number
---@param x number
---@return number
local function smoothstep(e0, e1, x)
  local t = clamp01((x - e0) / (e1 - e0))
  return t * t * (3 - 2 * t)
end

-- Mesh cuts a rect (left and top, in UIParent's units, y up, its width and height) into triangles that tile it exactly:
-- a grid of cells about size across (at least one), its inner vertices moved up to jitter of a cell either way, those
-- on an edge only along it, its corners still; each cell cut in two along a diagonal, either one. With a focus inside
-- it (where it breaks), the inner vertex nearest it is moved onto it, its neighbours jittered less so nothing folds.
-- Every vertex knows where it lies across the rect (u, v); the seams are ordered by how many seams they are from the
-- focus vertex (the nearest the rect's middle without one).
---@param rect {left: number, top: number, width: number, height: number}
---@param size number
---@param jitter number
---@param focus? {x: number, y: number}
---@return NextShatterMesh
function shatter:Mesh(rect, size, jitter, focus)
  local cols = math.max(1, math.ceil(rect.width / size - 1e-9))
  local rows = math.max(1, math.ceil(rect.height / size - 1e-9))
  local cw, ch = rect.width / cols, rect.height / rows
  local function index(i, j)
    return j * (cols + 1) + i + 1
  end
  -- The lattice vertex nearest the focus, when it is an inner one.
  local fi, fj
  if focus ~= nil and cols > 1 and rows > 1 then
    fi = math.floor((focus.x - rect.left) / cw + 0.5)
    fj = math.floor((rect.top - focus.y) / ch + 0.5)
    if fi < 1 or fi > cols - 1 or fj < 1 or fj > rows - 1 then
      fi, fj = nil, nil
    end
  end
  local verts = {}
  for j = 0, rows do
    for i = 0, cols do
      local x, y = rect.left + i * cw, rect.top - j * ch
      local amount = jitter
      if fi ~= nil and math.abs(i - fi) <= 1 and math.abs(j - fj) <= 1 then
        amount = math.min(jitter, NEAR_FOCUS_JITTER)
      end
      local innerX, innerY = i > 0 and i < cols, j > 0 and j < rows
      if innerX then
        x = x + (2 * self.Random() - 1) * amount * cw
      end
      if innerY then
        y = y + (2 * self.Random() - 1) * amount * ch
      end
      if i == fi and j == fj then
        -- Within half a cell of its place on the grid, less a little, so its triangles keep their way round.
        local limitX, limitY = 0.45 * cw, 0.45 * ch
        local gx, gy = rect.left + i * cw, rect.top - j * ch
        x = gx + math.max(-limitX, math.min(limitX, focus.x - gx))
        y = gy + math.max(-limitY, math.min(limitY, focus.y - gy))
      end
      verts[index(i, j)] = { x = x, y = y, u = (x - rect.left) / rect.width, v = (rect.top - y) / rect.height }
    end
  end
  local tris = {}
  for j = 0, rows - 1 do
    for i = 0, cols - 1 do
      local tl, tr, bl, br = index(i, j), index(i + 1, j), index(i, j + 1), index(i + 1, j + 1)
      if self.Random() < 0.5 then
        table.insert(tris, { tl, bl, tr })
        table.insert(tris, { tr, bl, br })
      else
        table.insert(tris, { tl, bl, br })
        table.insert(tris, { tl, br, tr })
      end
    end
  end
  -- The focus vertex: the moved one, else the one nearest the focus (or the middle).
  local center = focus or { x = rect.left + rect.width / 2, y = rect.top - rect.height / 2 }
  local focusIndex = fi ~= nil and index(fi, fj) or nil
  if focusIndex == nil then
    local best
    for k, v in ipairs(verts) do
      local d = (v.x - center.x) ^ 2 + (v.y - center.y) ^ 2
      if best == nil or d < best then
        best, focusIndex = d, k
      end
    end
  end
  -- The seams: every triangle's edges once, with each vertex's neighbours.
  local edges, seen, neighbours = {}, {}, {}
  for _, tri in ipairs(tris) do
    for k = 1, 3 do
      local a, b = tri[k], tri[k % 3 + 1]
      local lo, hi = math.min(a, b), math.max(a, b)
      local key = lo * 100000 + hi
      if not seen[key] then
        seen[key] = true
        table.insert(edges, { lo, hi })
        neighbours[lo] = neighbours[lo] or {}
        neighbours[hi] = neighbours[hi] or {}
        table.insert(neighbours[lo], hi)
        table.insert(neighbours[hi], lo)
      end
    end
  end
  -- How many seams each vertex is from the focus (breadth first), an edge's rank its nearer end's.
  local hops, queue, head = { [focusIndex] = 0 }, { focusIndex }, 1
  while head <= #queue do
    local at = queue[head]
    head = head + 1
    for _, n in ipairs(neighbours[at] or {}) do
      if hops[n] == nil then
        hops[n] = hops[at] + 1
        table.insert(queue, n)
      end
    end
  end
  for _, e in ipairs(edges) do
    local a, b = verts[e[1]], verts[e[2]]
    e.rank = math.min(hops[e[1]], hops[e[2]])
    e.reach = ((a.x + b.x) / 2 - center.x) ^ 2 + ((a.y + b.y) / 2 - center.y) ^ 2
  end
  table.sort(edges, function(p, q)
    if p.rank ~= q.rank then
      return p.rank < q.rank
    end
    return p.reach < q.reach
  end)
  return { verts = verts, tris = tris, edges = edges, focus = focusIndex }
end

---@param pool table[]
---@param make fun(): table
---@return table
local function acquire(pool, make)
  local item = table.remove(pool)
  if item == nil then
    item = make()
  end
  return item
end

-- texture makes a shard's texture on the layer: drawn without the client's sharpening (texture-sharpening.md),
-- its rect a unit square at the layer's bottom left that its corners are moved off.
---@param layer Frame
---@param sublevel number
---@return Texture
local function texture(layer, sublevel)
  local t = layer:CreateTexture(nil, "ARTWORK", nil, sublevel)
  t:SetPoint("BOTTOMLEFT", layer, "BOTTOMLEFT", 0, 0)
  t:SetSize(1, 1)
  t:SetSnapToPixelGrid(false)
  t:SetTexelSnappingBias(0)
  return t
end

-- paint draws a pooled texture or seam in a spec, only when it last drew another (a theme changed): a full panel's run
-- takes about 240 textures and 300 seams from the pools, every open and close. Its alpha is set as it is drawn, its
-- texture coordinates after.
---@param t Texture|Line
---@param spec table
local function paint(t, spec)
  if t.shatterSpec ~= spec then
    style:Paint(t, spec)
    t.shatterSpec = spec
  end
end

-- place moves a shard texture's corners onto a triangle (its fourth corner on its third), each point { x, y } in the
-- layer's units: an offset is from where the corner is in the unit square, y up.
---@param t Texture
---@param a number[]
---@param b number[]
---@param c number[]
local function place(t, a, b, c)
  t:SetVertexOffset(UL, a[1], a[2] - 1)
  t:SetVertexOffset(LL, b[1], b[2])
  t:SetVertexOffset(UR, c[1] - 1, c[2] - 1)
  t:SetVertexOffset(LR, c[1] - 1, c[2])
end

-- Begin cuts a panel's body into shards on the shatter layer, unseen until the panel's open or close shows them: the
-- body where the panel's BodyRect puts it on the screen, the art over the fill's rect (FillRect: it can reach past the
-- body), the frost over the body. With a focus (where it breaks), the cracks run out from there; without, from the
-- middle.
---@param panel table
---@param focus? {x: number, y: number}
---@return NextShatterRun
function shatter:Begin(panel, focus)
  local S = self:Spec()
  local layer = self:Layer()
  local left, top, height, width = panel:BodyRect()
  local rect = { left = left, top = top, width = width, height = height }
  local fl, ft, fw, fh = panel:FillRect()
  if fl == nil then
    fl, ft, fw, fh = left, top, width, height
  end
  local mesh = self:Mesh(rect, S.Shards.Size, S.Shards.Jitter or 0, focus)
  ---@type NextShatterRun
  local run = setmetatable({ spec = S, mesh = mesh, shards = {}, seams = {}, elapsed = 0 }, { __index = runProto })
  run.center = { x = left + width / 2, y = top - height / 2 }
  run.focusPoint = focus or run.center
  local O, C = S.Open or {}, S.Close or {}
  local farthest = 0
  for _, tri in ipairs(mesh.tris) do
    local a, b, c = mesh.verts[tri[1]], mesh.verts[tri[2]], mesh.verts[tri[3]]
    local s = { a = a, b = b, c = c, cx = (a.x + b.x + c.x) / 3, cy = (a.y + b.y + c.y) / 3 }
    s.art = acquire(self.arts, function() return texture(layer, 0) end)
    s.frost = acquire(self.frosts, function() return texture(layer, 1) end)
    paint(s.art, S.Shards)
    s.art:SetTexCoord((a.x - fl) / fw, (ft - a.y) / fh, (b.x - fl) / fw, (ft - b.y) / fh, (c.x - fl) / fw,
      (ft - c.y) / fh, (c.x - fl) / fw, (ft - c.y) / fh)
    paint(s.frost, S.Frost)
    s.frost:SetTexCoord(a.u, a.v, b.u, b.v, c.u, c.v, c.u, c.v)
    -- Where it flies in from (opening): away from the middle, turned.
    local dx, dy = s.cx - run.center.x, s.cy - run.center.y
    local d = math.sqrt(dx * dx + dy * dy)
    s.fromMiddle = d
    farthest = math.max(farthest, d)
    local angle = (d > 0 and math.atan2(dy, dx) or 2 * math.pi * self.Random()) + (self.Random() - 0.5) * 0.8
    local spread = between(O.Spread or { 0, 0 })
    s.sx, s.sy = s.cx + math.cos(angle) * spread, s.cy + math.sin(angle) * spread
    s.turn = math.rad((2 * self.Random() - 1) * (O.Spin or 0))
    -- How it flies apart (closing): away from where it breaks, turning one way or the other.
    local fx, fy = s.cx - run.focusPoint.x, s.cy - run.focusPoint.y
    local fd = math.sqrt(fx * fx + fy * fy)
    local away = (fd > 0 and math.atan2(fy, fx) or 2 * math.pi * self.Random()) + (self.Random() - 0.5) * 0.5
    local speed = between(C.Speed or { 0, 0 })
    s.vx, s.vy = math.cos(away) * speed, math.sin(away) * speed + (C.Lift or 0)
    s.spin = math.rad((self.Random() < 0.5 and -1 or 1) * (0.4 + 0.6 * self.Random()) * (C.Spin or 0))
    s.art:SetAlpha(0)
    s.frost:SetAlpha(0)
    s.art:Show()
    s.frost:Show()
    place(s.art, { a.x, a.y }, { b.x, b.y }, { c.x, c.y })
    place(s.frost, { a.x, a.y }, { b.x, b.y }, { c.x, c.y })
    table.insert(run.shards, s)
  end
  -- Nearer the middle first: the ice forms from the middle out.
  for _, s in ipairs(run.shards) do
    s.delay = (O.Stagger or 0) * ((farthest > 0 and s.fromMiddle / farthest or 0) * 0.9 + 0.1 * self.Random())
  end
  if O.Storm then
    run:beginStorm(panel, rect)
  end
  for _, e in ipairs(mesh.edges) do
    local line = acquire(self.lines, function()
      local l = layer:CreateLine(nil, "OVERLAY")
      l:SetSnapToPixelGrid(false)
      l:SetTexelSnappingBias(0)
      return l
    end)
    paint(line, S.Seams)
    line:SetThickness(S.Seams.Thickness or 1)
    local a, b = mesh.verts[e[1]], mesh.verts[e[2]]
    line:SetStartPoint("BOTTOMLEFT", layer, a.x, a.y)
    line:SetEndPoint("BOTTOMLEFT", layer, b.x, b.y)
    line:Hide()
    table.insert(run.seams, line)
  end
  return run
end

-- draw puts a shard where it is now: its middle at (x, y), turned by angle (radians), at a scale of its size, each
-- texture at its alpha.
---@param s NextShatterShard
---@param x number
---@param y number
---@param angle number
---@param scale number
---@param artAlpha number
---@param frostAlpha number
local function draw(s, x, y, angle, scale, artAlpha, frostAlpha)
  local cos, sin = math.cos(angle) * scale, math.sin(angle) * scale
  local function at(v)
    local dx, dy = v.x - s.cx, v.y - s.cy
    return { x + dx * cos - dy * sin, y + dx * sin + dy * cos }
  end
  local a, b, c = at(s.a), at(s.b), at(s.c)
  place(s.art, a, b, c)
  place(s.frost, a, b, c)
  s.art:SetAlpha(artAlpha)
  s.frost:SetAlpha(frostAlpha)
end

-- glint is how much of the frost's light a shard turned by angle catches: least square on, most across a turn.
---@param angle number
---@return number
local function glint(angle)
  return GLINT_LOW + (1 - GLINT_LOW) * math.abs(math.sin(2 * angle))
end

---@param spec table
---@return number
local function alphaOf(spec)
  return spec.Alpha or 1
end

-- flash shows the seams fading over the open's Clear (f, 0 to 1) when the open says Flash; without, they never show as it
-- opens (asked, of the Frost theme: "these lines, don't need to show").
---@param f number
function runProto:flash(f)
  local S = self.spec
  for _, line in ipairs(self.seams) do
    if S.Open.Flash then
      line:SetAlpha(alphaOf(S.Seams) * (1 - f))
      line:Show()
    else
      line:Hide()
    end
  end
end

-- Assemble draws the open t seconds in, and returns the panel's alpha: out of a frost storm with Open.Storm (stormAt),
-- else each shard flies in from around the body over
-- Open.Time, starting up to Stagger later the farther from the middle it is (easing out, turning to rest, growing to
-- its size, catching the light as it turns), the panel unseen; once all have locked, over Clear, the seams flash and
-- fade (with Open.Flash), the frost thaws and the shards go as the panel shows under them.
---@param t number
---@return number alpha The panel's.
function runProto:Assemble(t)
  if self.storm ~= nil then
    return self:stormAt(t)
  end
  local S = self.spec
  local O = S.Open
  local artA, frostA = alphaOf(S.Shards), alphaOf(S.Frost)
  local lock = (O.Stagger or 0) + O.Time
  -- Locked at lock, whatever the float error in adding up its times.
  if t < lock - 1e-9 then
    for _, s in ipairs(self.shards) do
      local q = O.Time > 0 and clamp01((t - s.delay) / O.Time) or 1
      local e = 1 - (1 - q) ^ 3
      local angle = s.turn * (1 - e)
      local seen = math.min(1, q * 3)
      draw(s, s.sx + (s.cx - s.sx) * e, s.sy + (s.cy - s.sy) * e, angle, 0.5 + 0.5 * e, artA * seen,
        frostA * glint(angle) * seen)
    end
    for _, line in ipairs(self.seams) do
      line:Hide()
    end
    return 0
  end
  local f = (O.Clear or 0) > 0 and clamp01((t - lock) / O.Clear) or 1
  for _, s in ipairs(self.shards) do
    draw(s, s.cx, s.cy, 0, 1, artA * (1 - smoothstep(0.4, 1, f)), frostA * (1 - f))
  end
  self:flash(f)
  return smoothstep(0, 0.6, f)
end

-- Freeze draws the close's frost and cracks t seconds in, and returns the panel's alpha (it shows throughout): frost
-- spreads over the body over Close.Frost (the shards' frost, their art unseen), then cracks run along the seams out
-- from where it breaks over Close.Crack.
---@param t number
---@return number alpha The panel's.
function runProto:Freeze(t)
  local S = self.spec
  local C = S.Close
  local frostTime, crackTime = C.Frost or 0, C.Crack or 0
  local f = frostTime > 0 and clamp01(t / frostTime) or 1
  for _, s in ipairs(self.shards) do
    s.art:SetAlpha(0)
    s.frost:SetAlpha(alphaOf(S.Frost) * f)
  end
  -- Nothing cracks while the frost spreads: the cracks' share is nothing until it has.
  local g = crackTime > 0 and clamp01((t - frostTime) / crackTime) or (t > frostTime and 1 or 0)
  local shown = math.floor(g * #self.seams + 0.5)
  for i, line in ipairs(self.seams) do
    if i <= shown then
      line:SetAlpha(alphaOf(S.Seams))
      line:Show()
    else
      line:Hide()
    end
  end
  return 1
end

-- Shatter breaks the body apart: the shards shown whole (the panel goes as they do), the seams gone, and the run handed
-- to the layer's driver, which flies them apart from where it broke over Close.Time (thrown outward and up by Lift,
-- falling under Gravity, turning, shrinking, catching the light, fading), then gives everything back.
function runProto:Shatter()
  local S = self.spec
  for _, s in ipairs(self.shards) do
    draw(s, s.cx, s.cy, 0, 1, alphaOf(S.Shards), alphaOf(S.Frost))
  end
  for _, line in ipairs(self.seams) do
    line:Hide()
  end
  self.elapsed = 0
  shatter.flying[self] = true
  local driver = shatter:Layer().driver
  if driver:GetScript("OnUpdate") == nil then
    driver:SetScript("OnUpdate", function(_, elapsed)
      shatter:Step(elapsed)
    end)
  end
end

-- fly moves a shattered run elapsed seconds on; it gives everything back once Close.Time has passed.
---@param elapsed number
function runProto:fly(elapsed)
  local S = self.spec
  local C = S.Close
  self.elapsed = self.elapsed + elapsed
  local t = self.elapsed
  local p = (C.Time or 0) > 0 and t / C.Time or 1
  if p >= 1 then
    self:Release()
    return
  end
  local fade = 1 - smoothstep(0.3, 1, p)
  local g = C.Gravity or 0
  for _, s in ipairs(self.shards) do
    local angle = s.spin * t
    draw(s, s.cx + s.vx * t, s.cy + s.vy * t - 0.5 * g * t * t, angle, 1 - 0.35 * p, alphaOf(S.Shards) * fade,
      alphaOf(S.Frost) * glint(angle) * fade)
  end
end

-- Step flies every shattered run on, and stops the driver when none is left.
---@param elapsed number
function shatter:Step(elapsed)
  for run in pairs(self.flying) do
    run:fly(elapsed)
  end
  if next(self.flying) == nil then
    self:Layer().driver:SetScript("OnUpdate", nil)
  end
end

-- beginStorm readies the open's frost storm (Open.Storm): it grows out of the body's From corner (by the panel's sides:
-- inner is the side away from its screen edge), a quarter circle reaching the corner across as it ends its crossing, and
-- each shard forms as the storm reaches its middle.
---@param panel table
---@param rect {left: number, top: number, width: number, height: number}
function runProto:beginStorm(panel, rect)
  local W = self.spec.Open.Storm
  local from = W.From or "BOTTOMINNER"
  local innerLeft = panel.side ~= "LEFT"
  local inner = from:find("INNER", 1, true) ~= nil
  local left = inner == innerLeft
  local bottom = from:find("^BOTTOM") ~= nil
  local x = left and rect.left or rect.left + rect.width
  local y = bottom and rect.top - rect.height or rect.top
  local reach = math.sqrt(rect.width ^ 2 + rect.height ^ 2)
  self.storm = { particles = {}, flakes = 0, mist = 0, last = 0, x = x, y = y, ux = left and 1 or -1,
    uy = bottom and 1 or -1, reach = reach, rect = rect }
  for _, s in ipairs(self.shards) do
    s.arrive = math.sqrt((s.cx - x) ^ 2 + (s.cy - y) ^ 2) / reach * self.spec.Open.Time
  end
end

-- spawn sends a storm's particles of one kind (its flakes, or its mist) out at its front, as many as are due by now: Count
-- over the crossing. Each at a point of the front inside the body (a few tries; none if the front has left the body
-- there), heading out from the corner at Speed, its own size, life, turn and swirl.
---@param spec table
---@param mist boolean
---@param crossing number How far across it has grown, 0 to 1.
function runProto:spawn(spec, mist, crossing)
  local st = self.storm
  local key = mist and "mist" or "flakes"
  local due = math.floor((spec.Count or 0) * crossing)
  local rect = st.rect
  local layer = shatter:Layer()
  while st[key] < due do
    st[key] = st[key] + 1
    local radius = st.reach * crossing
    local x, y
    for _ = 1, 6 do
      local angle = math.pi / 2 * shatter.Random()
      local r = radius * (0.8 + 0.25 * shatter.Random())
      local px, py = st.x + st.ux * math.cos(angle) * r, st.y + st.uy * math.sin(angle) * r
      if px >= rect.left and px <= rect.left + rect.width and py <= rect.top and py >= rect.top - rect.height then
        x, y = px, py
        break
      end
    end
    if x ~= nil then
      local t = table.remove(shatter.storms) or texture(layer, 2)
      t:ClearAllPoints()
      local color = spec.Color
      if not mist then
        local colors = spec.Colors or { "White" }
        color = colors[math.min(#colors, math.floor(shatter.Random() * #colors) + 1)]
      end
      style:Paint(t, { Texture = spec.Texture, Color = color or "White", BlendMode = spec.BlendMode or "ADD" })
      t:SetRotation(0)
      t:SetAlpha(0)
      t:Show()
      local dx, dy = x - st.x, y - st.y
      local d = math.sqrt(dx * dx + dy * dy)
      local speed = between(spec.Speed or { 0, 0 })
      local p = { texture = t, mist = mist, x = x, y = y, age = 0, life = between(spec.Life or { 0.5, 0.5 }),
        size = between(spec.Size or { 8, 8 }), angle = 0,
        vx = (d > 0 and dx / d or st.ux) * speed, vy = (d > 0 and dy / d or st.uy) * speed,
        swirl = (shatter.Random() < 0.5 and -1 or 1) * (spec.Swirl or 0),
        spin = math.rad((2 * shatter.Random() - 1) * (spec.Spin or 0)),
        alpha = type(spec.Alpha) == "table" and between(spec.Alpha) or (spec.Alpha or 1), growth = spec.Growth or 1 }
      table.insert(st.particles, p)
    end
  end
end

-- stormAt draws the open's frost storm t seconds in, and returns the panel's alpha: its front grows across the body over
-- Open.Time, flakes curling and turning in it and mist rolling and growing with it; each shard forms where it lies over
-- Appear once the storm has reached it (from frost to its art, turning to rest); once all have formed, over Clear, the
-- seams flash and fade (with Open.Flash), the frost thaws and the shards go as the panel shows under them, and the storm blows away.
---@param t number
---@return number alpha The panel's.
function runProto:stormAt(t)
  local S = self.spec
  local O = S.Open
  local W = O.Storm
  local st = self.storm
  local dt = math.max(0, t - st.last)
  st.last = t
  local appear = W.Appear or 0
  local lock = O.Time + appear
  local locked = t >= lock - 1e-9
  local f = 0
  if locked then
    f = (O.Clear or 0) > 0 and clamp01((t - lock) / O.Clear) or 1
  end
  local crossing = O.Time > 0 and clamp01(t / O.Time) or 1
  -- Those already blowing move on; those born now are drawn where they are born, and move from the next frame.
  local blowing = #st.particles
  if W.Flakes then
    self:spawn(W.Flakes, false, crossing)
  end
  if W.Mist then
    self:spawn(W.Mist, true, crossing)
  end
  for i = #st.particles, 1, -1 do
    local p = st.particles[i]
    if i > blowing then
      p.born = true
    end
  end
  for i = #st.particles, 1, -1 do
    local p = st.particles[i]
    local step = p.born and 0 or dt
    p.born = false
    p.age = p.age + step
    if p.age >= p.life then
      p.texture:Hide()
      table.insert(shatter.storms, p.texture)
      table.remove(st.particles, i)
    else
      local turn = p.swirl * step
      local cos, sin = math.cos(turn), math.sin(turn)
      p.vx, p.vy = p.vx * cos - p.vy * sin, p.vx * sin + p.vy * cos
      p.x, p.y = p.x + p.vx * step, p.y + p.vy * step
      p.angle = p.angle + p.spin * step
      local age = p.age / p.life
      local size = p.size * (1 + (p.growth - 1) * age)
      local t2 = p.texture
      t2:SetPoint("CENTER", shatter:Layer(), "BOTTOMLEFT", p.x, p.y)
      t2:SetSize(size, size)
      t2:SetRotation(p.angle)
      t2:SetAlpha(p.alpha * math.min(1, age / 0.2) * (1 - age) * (1 - f))
    end
  end
  local artA, frostA = alphaOf(S.Shards), alphaOf(S.Frost)
  if not locked then
    for _, s in ipairs(self.shards) do
      local q
      if appear > 0 then
        q = clamp01((t - s.arrive) / appear)
      else
        q = t >= s.arrive and 1 or 0
      end
      local e = 1 - (1 - q) ^ 2
      local angle = s.turn * 0.25 * (1 - e)
      draw(s, s.cx, s.cy, angle, 0.8 + 0.2 * e, artA * e, frostA * math.min(1, q * 4) * (1 - 0.4 * e))
    end
    for _, line in ipairs(self.seams) do
      line:Hide()
    end
    return 0
  end
  for _, s in ipairs(self.shards) do
    draw(s, s.cx, s.cy, 0, 1, artA * (1 - smoothstep(0.4, 1, f)), frostA * (1 - f))
  end
  self:flash(f)
  return smoothstep(0, 0.6, f)
end

-- Release gives the run's textures and seams back, hidden, at once; a run released again does nothing.
function runProto:Release()
  shatter.flying[self] = nil
  if self.storm ~= nil then
    for _, p in ipairs(self.storm.particles) do
      p.texture:Hide()
      table.insert(shatter.storms, p.texture)
    end
    self.storm.particles = {}
  end
  for _, s in ipairs(self.shards) do
    s.art:Hide()
    s.frost:Hide()
    table.insert(shatter.arts, s.art)
    table.insert(shatter.frosts, s.frost)
  end
  for _, line in ipairs(self.seams) do
    line:Hide()
    table.insert(shatter.lines, line)
  end
  self.shards = {}
  self.seams = {}
end
