local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextStopMotion: AceModule
local stopMotion = addon:GetModule('NextStopMotion')

---@class NextShatter: AceModule
local shatter = addon:GetModule('NextShatter')

-- NextPaper makes a Next panel a sheet of paper (Panel.Paper, next-themes.md §25; the Papercraft theme; asked: "the open
-- animation should be the bags 'unfolding' in two parts (1/4th square, unfold into half, unfold into full), and the close
-- animation should it being crumbled up like a paper ball and being tossed up slightly, then falling off the screen").
-- The client cannot draw a frame's content into a texture, so a run draws the sheet itself on the paper layer, a frame
-- over the screen above every panel, carrying the body's own art; the panel drives it (next/panel.lua).
--
-- Opening, the sheet is a lattice of cells whose corners a fold moves (SetVertexOffset, as the shatter's shards). A sheet
-- folded in four has two hinges, and a real one's layers show as a real one's would: folded, the outside of one quarter
-- shows; the first fold's flap swings across its hinge, and the half it leaves shows the paper's back; then the second
-- fold's flap swings down, its back to the viewer until it passes upright, and the front of the sheet shows under it
-- and on it. Each flap is strips turning about its hinge, bent by Curl and nearer the viewer by Depth, shaded as it
-- turns from the light. The panel shows once the sheet lies flat; the sheet then goes, a pose at a time, over it (Reveal).
--
-- Closing, the panel trembles a moment (Grab), then it is gone and the sheet takes its place, the panel's items printed
-- on it: triangles of the shatter's mesh, each corner going from where it lies to a place on a lumpy ball (Warp), its
-- edges first, facets shaded as they turn, wrinkling on the way. The ball is tossed up a little, tumbling, and falls off
-- the screen on the layer's driver.
--
-- Both are drawn a pose at a time (Open's and Close's lists, Rate a second). Under a theme's stop motion
-- (NextStopMotion) a pose is held for its whole frame and placed imperfectly: the sheet moved and turned, each corner of
-- it its own way, its angle off its pose (Wobble); without one it runs between its poses every frame, exactly.
---@class NextPaper: AceModule
local paper = addon:NewModule('NextPaper')

-- Where the paper takes its randomness (a source of numbers in [0, 1)): replaced by the specs.
paper.Random = math.random

-- The keys of Panel.Paper and its parts, the corners a sheet unfolds from, for SonataNext:Check.
paper.KEYS = { Front = true, Back = true, Edge = true, Shadow = true, Rate = true, Wobble = true, Open = true,
  Close = true }
paper.EDGE_KEYS = { Texture = true, Width = true, Inside = true, Tile = true, Color = true, Alpha = true }
paper.SHADOW_KEYS = { Texture = true, Color = true, Alpha = true, Spread = true, X = true, Y = true }
paper.WOBBLE_KEYS = { Move = true, Turn = true, Vertex = true, Pose = true }
paper.OPEN_KEYS = { From = true, Cells = true, Curl = true, Depth = true, Lit = true, Reveal = true, Quarter = true,
  Half = true, Full = true, Note = true }
paper.NOTE_KEYS = { Texture = true, Color = true, Alpha = true, Width = true, Height = true, X = true, Y = true,
  Frames = true }
paper.CLOSE_KEYS = { Grab = true, Tremble = true, Cell = true, Jitter = true, Ball = true, Lump = true, Wrinkle = true,
  Wrap = true, Lag = true, Lit = true, Twist = true, Facet = true, Jag = true, Poses = true, Toss = true, Mount = true,
  Crop = true }
paper.TOSS_KEYS = { Up = true, Gravity = true, Drift = true, Tumble = true, Life = true }
paper.CORNERS = { BOTTOMINNER = true, BOTTOMOUTER = true, TOPINNER = true, TOPOUTER = true }

-- Blizzard's vertex indices (Blizzard_FrameXMLBase/Constants.lua, every client).
local UL, LL, UR, LR = 1, 2, 3, 4

-- How much of a flap's angle Curl bends across its length, at most, in degrees: its far end lags behind its hinge.
local CURL = 60
-- Where a crumpled ball's light comes from: up and to the left of the viewer. A sheet lying flat faces it by its z, so
-- that is what full light is.
local LIGHT_X, LIGHT_Y, LIGHT_Z = -0.37, 0.52, 0.77
-- What is printed on the sheet shows until the sheet has drawn in on itself (PRINT_FROM), then only on the ball's near
-- side: how far toward the viewer, as a share of the ball, rising from PRINT_BEHIND to past the ball by PRINT_TO. Printed
-- items on a finished ball read as a beach ball's stripes.
local PRINT_FROM, PRINT_TO = 0.55, 0.97
local PRINT_BEHIND, PRINT_AHEAD = -0.5, 1.1
-- How much of a Jag stays on the finished ball, against half way in.
local JAG_REST = 0.3
-- How far below the screen a ball goes before it is given back, as a share of the ball: a lump may reach past it.
local OFF_SCREEN = 1.4
local SQRT2 = math.sqrt(2)

---@class (exact) NextPaperCorner
---@field x number Where it is on the layer (UIParent's units, y up).
---@field y number
---@field u number Where it is on its art.
---@field v number

---@class NextPaperRun
---@field spec table The theme's Panel.Paper it began with.
---@field phase string "Open" or "Close".
---@field stepped boolean Drawn as stop motion: a theme's Motion.StopMotion when it began.
---@field seed number Its own noise.
---@field frame? integer The frame it holds.
---@field elapsed number How long it has lived on its own.
---@field cells table[] An unfolding sheet's cells.
---@field tris table[] A crumpling sheet's triangles.
---@field edges table[] The torn edge along each side of it.
---@field notes table[] What is drawn on the outside of the folded sheet.
---@field decals table[] What is printed on a crumpling sheet.
local runProto = {}
addon:GetModule('Perf'):RegisterPrototype(runProto, 'NextPaperRun')

function paper:Init()
  for run in pairs(self.living or {}) do
    run:Release()
  end
  self.living = {}
  self.pool = self.pool or {}
  if self.layer ~= nil then
    self.layer.driver:SetScript("OnUpdate", nil)
  end
end

-- Spec returns the theme's Panel.Paper, nil without one.
---@return table?
function paper:Spec()
  return style.Theme.Panel.Paper or nil
end

-- Opens says whether the theme's panels unfold instead of sliding in.
---@return boolean
function paper:Opens()
  local S = self:Spec()
  return S ~= nil and S.Open ~= nil
end

-- Closes says whether the theme's panels crumple instead of sliding out.
---@return boolean
function paper:Closes()
  local S = self:Spec()
  return S ~= nil and S.Close ~= nil
end

-- OpenLock is when the sheet lies flat and the panel shows (its sections cascade from then, and it says it has shown);
-- OpenTime is the panel's part of the open, until then.
---@return number
function paper:OpenLock()
  local S = self:Spec()
  local O = S.Open
  return (#(O.Quarter or {}) + #O.Half + #O.Full) / S.Rate
end

---@return number
function paper:OpenTime()
  return self:OpenLock()
end

-- GrabTime is how long the panel trembles before the sheet takes its place.
---@return number
function paper:GrabTime()
  local S = self:Spec()
  return (S.Close.Grab or 0) / S.Rate
end

-- Layer returns the paper layer, made the first time: a frame over the whole screen, in the DIALOG strata (above the
-- panels, HIGH), taking no mouse, with the driver that carries a sheet on once the panel's part is done.
---@return Frame
function paper:Layer()
  if self.layer == nil then
    local layer = CreateFrame("Frame", nil, UIParent)
    layer:SetAllPoints(UIParent)
    layer:SetFrameStrata("DIALOG")
    layer:SetFrameLevel(20)
    layer:EnableMouse(false)
    layer.driver = CreateFrame("Frame", nil, layer)
    self.layer = layer
  end
  return self.layer
end

---@param x number
---@return number
local function clamp01(x)
  return math.max(0, math.min(1, x))
end

---@param range number[]
---@return number
local function between(range)
  return range[1] + (range[2] - range[1]) * paper.Random()
end

-- take gets a texture from the pool, or makes one: a unit square at the layer's bottom left that its corners are moved
-- off, drawn without the client's sharpening (texture-sharpening.md), hidden until it is drawn.
---@param drawLayer string
---@param sublevel number
---@return Texture
local function take(drawLayer, sublevel)
  local t = table.remove(paper.pool)
  if t == nil then
    local layer = paper:Layer()
    t = layer:CreateTexture(nil, "ARTWORK")
    t:SetPoint("BOTTOMLEFT", layer, "BOTTOMLEFT", 0, 0)
    t:SetSize(1, 1)
    t:SetSnapToPixelGrid(false)
    t:SetTexelSnappingBias(0)
  end
  t:SetDrawLayer(drawLayer, sublevel)
  t.paperArt = nil
  t:Hide()
  return t
end

-- art draws a texture's picture when it last drew another: a pooled texture turning from a sheet's back to its front
-- every few frames need not load it again. wrap repeats it along its width (a torn edge).
---@param t Texture
---@param file string|number
---@param wrap? boolean
---@param blend? string
local function art(t, file, wrap, blend)
  if t.paperArt ~= file then
    t:SetTexture(file, wrap and "REPEAT" or nil, nil)
    t:SetBlendMode(blend or "BLEND")
    t.paperArt = file
  end
end

-- quad moves a texture's corners, each { x, y, u, v } (upper left, lower left, upper right, lower right). A sheet that
-- has flipped over would turn them the other way round, which the client may not draw: left and right swap, each corner
-- taking its place on the art along, so the art still lies where it lay.
---@param t Texture
---@param a NextPaperCorner
---@param b NextPaperCorner
---@param c NextPaperCorner
---@param d NextPaperCorner
local function quad(t, a, b, c, d)
  if (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) < 0 then
    a, b, c, d = c, d, a, b
  end
  t:SetVertexOffset(UL, a.x, a.y - 1)
  t:SetVertexOffset(LL, b.x, b.y)
  t:SetVertexOffset(UR, c.x - 1, c.y - 1)
  t:SetVertexOffset(LR, d.x - 1, d.y)
  t:SetTexCoord(a.u, a.v, b.u, b.v, c.u, c.v, d.u, d.v)
end

-- tri moves a texture's corners onto a triangle, its fourth on its third, the right way round.
---@param t Texture
---@param a NextPaperCorner
---@param b NextPaperCorner
---@param c NextPaperCorner
local function tri(t, a, b, c)
  if (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) < 0 then
    b, c = c, b
  end
  t:SetVertexOffset(UL, a.x, a.y - 1)
  t:SetVertexOffset(LL, b.x, b.y)
  t:SetVertexOffset(UR, c.x - 1, c.y - 1)
  t:SetVertexOffset(LR, c.x - 1, c.y)
  t:SetTexCoord(a.u, a.v, b.u, b.v, c.u, c.v, c.u, c.v)
end

-- rgb reads a part's color now, so a theme going under a sheet in flight is no error.
---@param spec table
---@return number[]
local function rgba(spec)
  return { style:RGBA(spec.Color or "White", spec.Alpha) }
end

---@param spec table
---@return string
local function path(spec)
  return style:TexturePath(spec.Texture)
end

-- Begin lays a panel's sheet on the paper layer, unseen until it is drawn: its phase, "Open" to unfold, "Close" to crumple.
---@param panel table
---@param phase string
---@return NextPaperRun
function paper:Begin(panel, phase)
  local S = self:Spec()
  local left, top, height, width, scale = panel:BodyRect()
  scale = scale or 1
  local fl, ft, fw, fh = panel:FillRect()
  if fl == nil then
    fl, ft, fw, fh = left, top, width, height
  end
  ---@type NextPaperRun
  local run = setmetatable({
    spec = S, phase = phase, stepped = stopMotion:Spec() ~= nil, seed = self.Random() * 1000, elapsed = 0,
    cells = {}, tris = {}, edges = {}, notes = {}, decals = {},
    left = left, top = top, w = width, h = height, scale = scale,
    fl = fl, ft = ft, fw = fw, fh = fh,
    front = path(S.Front), back = path(S.Back), frontColor = rgba(S.Front), backColor = rgba(S.Back),
    wobble = S.Wobble or {},
    edgeFile = S.Edge and path(S.Edge) or nil, edgeColor = S.Edge and rgba(S.Edge) or nil,
    innerRight = panel.side ~= "LEFT",
  }, { __index = runProto })
  if S.Shadow then
    run.shadow = take("BACKGROUND", 0)
    art(run.shadow, path(S.Shadow), false)
    run.shadowColor = rgba(S.Shadow)
  end
  if phase == "Open" then
    run:beginFold()
  else
    run:beginCrumple(panel)
  end
  return run
end

-- Noise is the run's own noise for a frame and a key.
---@private
---@param frame number
---@param key number
---@return number
function runProto:noise(frame, key)
  return stopMotion:Noise(frame, key + self.seed)
end

-- beginFold lays out an unfolding sheet: Cells a half of it each way. a runs across it from its From corner and b down
-- or up it from there; each corner of the lattice knows where it lies on the front's art (the panel's fill) and on the back's.
---@private
function runProto:beginFold()
  local S = self.spec
  local O = S.Open
  local n = O.Cells or 4
  self.halves = n
  local from = O.From or "TOPOUTER"
  -- The panel's inner side is away from its screen edge: on the left of a panel belonging to the right of the screen.
  local inner = from:find("INNER", 1, true) ~= nil
  local atLeft = inner == self.innerRight
  local atBottom = from:find("^BOTTOM") ~= nil
  self.x0 = atLeft and self.left or self.left + self.w
  self.y0 = atBottom and self.top - self.h or self.top
  self.dirA = atLeft and 1 or -1
  self.dirB = atBottom and 1 or -1
  self.corners = {}
  for i = 0, 2 * n do
    local a = i * self.w / (2 * n)
    self.corners[i] = {}
    for j = 0, 2 * n do
      local b = j * self.h / (2 * n)
      local x, y = self.x0 + self.dirA * a, self.y0 + self.dirB * b
      self.corners[i][j] = { fu = (x - self.fl) / self.fw, fv = (self.ft - y) / self.fh, bu = a / self.w, bv = b / self.h }
    end
  end
  for i = 0, 2 * n - 1 do
    for j = 0, 2 * n - 1 do
      table.insert(self.cells, { i = i, j = j, texture = take("ARTWORK", 0) })
    end
  end
  if S.Edge then
    self:foldEdges(n)
  end
  -- The poses: the sheet folded in four is the first flap lying over, 180 degrees from flat.
  self.poses = {}
  for _, q in ipairs(O.Quarter or {}) do
    table.insert(self.poses, { phase = "half", angle = 180, scale = q.Scale or 1, turn = q.Turn or 0 })
  end
  for _, angle in ipairs(O.Half) do
    table.insert(self.poses, { phase = "half", angle = angle, scale = 1, turn = 0 })
  end
  for _, angle in ipairs(O.Full) do
    table.insert(self.poses, { phase = "full", angle = angle, scale = 1, turn = 0 })
  end
  for _, note in ipairs(O.Note or {}) do
    local t = take("ARTWORK", 5)
    art(t, path(note), false)
    table.insert(self.notes, { spec = note, texture = t, color = rgba(note) })
  end
  self.flapShadow = S.Shadow and take("ARTWORK", 2) or nil
  if self.flapShadow then
    art(self.flapShadow, path(S.Shadow), false)
  end
end

-- foldEdges readies a torn edge along each cell on the sheet's sides, repeating along its length in the art's Tile.
---@private
---@param n integer
function runProto:foldEdges(n)
  local E = self.spec.Edge
  local tile = (E.Tile or 128) * self.scale
  local function add(i, j, p, q, along0, along1)
    table.insert(self.edges, { cell = i .. "," .. j, p = p, q = q, u0 = along0 / tile, u1 = along1 / tile,
      texture = take("ARTWORK", 1) })
  end
  local cw, ch = self.w / (2 * n), self.h / (2 * n)
  for i = 0, 2 * n - 1 do
    add(i, 0, { i, 0 }, { i + 1, 0 }, i * cw, (i + 1) * cw)
    add(i, 2 * n - 1, { i, 2 * n }, { i + 1, 2 * n }, i * cw, (i + 1) * cw)
  end
  for j = 0, 2 * n - 1 do
    add(0, j, { 0, j }, { 0, j + 1 }, j * ch, (j + 1) * ch)
    add(2 * n - 1, j, { 2 * n, j }, { 2 * n, j + 1 }, j * ch, (j + 1) * ch)
  end
  for _, edge in ipairs(self.edges) do
    art(edge.texture, self.edgeFile, true)
  end
end

-- PoseAngle is a frame's angle, a little off its pose under a stop motion; a flap lying flat or folded right over lies
-- exactly so.
---@param frame integer
---@return number
function runProto:PoseAngle(frame)
  local pose = self.poses[frame + 1]
  local angle = pose.angle
  if angle == 0 or angle == 180 then
    return angle
  end
  if self.stepped then
    angle = angle + (self.wobble.Pose or 0) * self:noise(frame, 1)
  end
  return angle
end

-- flap works out a flap's strips at an angle (degrees from lying flat), turning about its hinge, length long: how far
-- out from the hinge each strip's edge lies, and how far above the sheet. Each strip lags behind the one before it by
-- Curl while the flap is up.
---@private
---@param angle number
---@param length number
---@return table
function runProto:flap(angle, length)
  local n = self.halves
  local curl = (self.spec.Open.Curl or 0) * CURL * math.sin(math.rad(angle))
  local out = { x = { [0] = 0 }, z = { [0] = 0 }, theta = {} }
  local ds = length / n
  for k = 1, n do
    local theta = math.max(-180, math.min(180, angle + curl * (k - 0.5) / n))
    local r = math.rad(theta)
    out.theta[k] = theta
    out.x[k] = out.x[k - 1] + ds * math.cos(r)
    out.z[k] = out.z[k - 1] + ds * math.sin(r)
  end
  return out
end

-- along is where a flap lies at a distance from its hinge, between its strips' edges.
---@param F table
---@param d number
---@param ds number
---@param n integer
---@return number x, number z
local function along(F, d, ds, n)
  local k = math.max(0, math.min(n - 1, math.floor(d / ds)))
  local f = (d - k * ds) / ds
  return F.x[k] + (F.x[k + 1] - F.x[k]) * f, F.z[k] + (F.z[k + 1] - F.z[k]) * f
end

-- placer returns what moves a point of the sheet where it is drawn this frame: nearer the viewer by how far it is off
-- the sheet (about mx, my), scaled about the middle of what shows, and as stop motion, moved and turned a little.
---@private
---@param frame integer
---@param mx number The flap's hinge's middle.
---@param my number
---@param scale number
---@param turn number
---@param cx number The middle of what shows.
---@param cy number
---@return fun(x: number, y: number, z: number, i?: integer, j?: integer): number, number
function runProto:placer(frame, mx, my, scale, turn, cx, cy)
  local O = self.spec.Open
  local depth = (O.Depth or 0) * math.max(self.w, self.h)
  local W = self.stepped and self.wobble or {}
  local unit = self.scale
  local dx, dy = (W.Move or 0) * unit * self:noise(frame, 2), (W.Move or 0) * unit * self:noise(frame, 3)
  local angle = math.rad(turn + (W.Turn or 0) * self:noise(frame, 4))
  local cos, sin = math.cos(angle), math.sin(angle)
  local vertex = (W.Vertex or 0) * unit
  return function(x, y, z, i, j)
    if depth > 0 and z ~= 0 then
      local s = depth / (depth - z)
      x, y = mx + (x - mx) * s, my + (y - my) * s
    end
    x, y = cx + (x - cx) * scale, cy + (y - cy) * scale
    local rx, ry = x - cx, y - cy
    x, y = cx + rx * cos - ry * sin + dx, cy + rx * sin + ry * cos + dy
    if vertex ~= 0 and i ~= nil then
      local key = i * 37 + j * 101
      x = x + vertex * self:noise(frame, key)
      y = y + vertex * self:noise(frame, key + 17)
    end
    return x, y
  end
end

-- drawCell draws a cell of the unfolding sheet: its corners, its art (front or back), its shade.
---@private
---@param cell table
---@param p table[][] Where each corner of the lattice is drawn.
---@param front boolean
---@param shade number
---@param sublevel integer
function runProto:drawCell(cell, p, front, shade, sublevel)
  local t = cell.texture
  local i, j = cell.i, cell.j
  local function corner(ci, cj)
    local c = self.corners[ci][cj]
    local at = p[ci][cj]
    return { x = at[1], y = at[2], u = front and c.fu or c.bu, v = front and c.fv or c.bv }
  end
  art(t, front and self.front or self.back, false)
  quad(t, corner(i, j), corner(i, j + 1), corner(i + 1, j), corner(i + 1, j + 1))
  local color = front and self.frontColor or self.backColor
  t:SetVertexColor(color[1] * shade, color[2] * shade, color[3] * shade, color[4])
  t:SetDrawLayer("ARTWORK", sublevel)
  t:Show()
  cell.shown, cell.shade = true, shade
  cell.at = { (p[i][j][1] + p[i + 1][j + 1][1]) / 2, (p[i][j][2] + p[i + 1][j + 1][2]) / 2 }
end

-- drawEdges draws the torn edge along each side of a shown cell: out from its side, away from its middle, as thick
-- whichever way the sheet is turned.
---@private
---@param p table[][]
---@param byCell table<string, table>
function runProto:drawEdges(p, byCell)
  local E = self.spec.Edge
  if E == nil then
    return
  end
  local width, inside = (E.Width or 0) * self.scale, (E.Inside or 0) * self.scale
  for _, edge in ipairs(self.edges) do
    local cell = byCell[edge.cell]
    local t = edge.texture
    if cell ~= nil and cell.shown then
      local a, b = p[edge.p[1]][edge.p[2]], p[edge.q[1]][edge.q[2]]
      self:drawEdge(t, a[1], a[2], b[1], b[2], cell.at[1], cell.at[2], width, inside, edge.u0, edge.u1)
      local c = self.edgeColor
      t:SetVertexColor(c[1] * cell.shade, c[2] * cell.shade, c[3] * cell.shade, c[4])
      t:SetDrawLayer("ARTWORK", cell.flap and 4 or 1)
      t:Show()
    else
      t:Hide()
    end
  end
end

-- drawEdge draws one length of torn edge, from (ax, ay) to (bx, by), out away from (cx, cy): the art's top is its outside.
---@private
function runProto:drawEdge(t, ax, ay, bx, by, cx, cy, width, inside, u0, u1)
  local dx, dy = bx - ax, by - ay
  local length = math.sqrt(dx * dx + dy * dy)
  if length < 1e-3 then
    t:Hide()
    return
  end
  local nx, ny = -dy / length, dx / length
  if nx * ((ax + bx) / 2 - cx) + ny * ((ay + by) / 2 - cy) < 0 then
    nx, ny = -nx, -ny
  end
  quad(t, { x = ax + nx * width, y = ay + ny * width, u = u0, v = 0 },
    { x = ax - nx * inside, y = ay - ny * inside, u = u0, v = 1 },
    { x = bx + nx * width, y = by + ny * width, u = u1, v = 0 },
    { x = bx - nx * inside, y = by - ny * inside, u = u1, v = 1 })
end

-- drawFold draws the sheet in a phase at an angle: "half", the first fold's flap swinging across its hinge, the second
-- fold still folded; "full", the second's flap swinging across its, the first lying flat; "flat", the whole sheet.
---@private
---@param phase string
---@param angle number
---@param scale number
---@param turn number
---@param frame integer
function runProto:drawFold(phase, angle, scale, turn, frame)
  local O = self.spec.Open
  local n = self.halves
  local w, h = self.w, self.h
  local x0, y0, dirA, dirB = self.x0, self.y0, self.dirA, self.dirB
  local cellA, cellB = w / (2 * n), h / (2 * n)
  local halfHinge = phase == "half"
  local F = phase ~= "flat" and self:flap(angle, halfHinge and w / 2 or h / 2) or nil
  -- The hinge's middle, and the middle of what shows (what it is scaled and turned about).
  local mx, my, cx, cy
  if halfHinge then
    mx, my = x0 + dirA * w / 2, y0 + dirB * h / 4
    cx, cy = x0 + dirA * w / 4, y0 + dirB * h / 4
  else
    mx, my = x0 + dirA * w / 2, y0 + dirB * h / 2
    cx, cy = mx, my
  end
  local place = self:placer(frame, mx, my, scale, turn, cx, cy)
  local still = phase == "flat"
  if still then
    place = function(x, y)
      return x, y
    end
  end
  local p = {}
  for i = 0, 2 * n do
    p[i] = {}
    for j = 0, 2 * n do
      local a, b, z = i * cellA, j * cellB, 0
      if halfHinge then
        -- The second fold is still folded: its half lies over the first.
        if j > n then
          b = (2 * n - j) * cellB
        end
        if i > n then
          a = w / 2 + F.x[i - n]
          z = F.z[i - n]
        end
      elseif phase == "full" and j > n then
        b = h / 2 + F.x[j - n]
        z = F.z[j - n]
      end
      local x, y = place(x0 + dirA * a, y0 + dirB * b, z, i, (halfHinge and j > n) and 2 * n - j or j)
      p[i][j] = { x, y }
    end
  end
  local lit = O.Lit or 0.6
  local byCell = {}
  for _, cell in ipairs(self.cells) do
    local i, j = cell.i, cell.j
    byCell[i .. "," .. j] = cell
    cell.shown, cell.flap = false, false
    if still then
      self:drawCell(cell, p, true, 1, 0)
    elseif halfHinge then
      local lower = j >= n
      if i < n then
        -- The second fold's half, its back to the viewer, over the first's; the first's is hidden under it.
        if lower then
          self:drawCell(cell, p, false, 1, 0)
        end
      else
        -- Past upright the flap's other face shows: the outside of the first's half.
        local theta = F.theta[i - n + 1]
        if (theta < 90) == lower then
          cell.flap = true
          self:drawCell(cell, p, false, lit + (1 - lit) * math.abs(math.cos(math.rad(theta))), 3)
        end
      end
    elseif j < n then
      self:drawCell(cell, p, true, 1, 0)
    else
      local theta = F.theta[j - n + 1]
      cell.flap = true
      self:drawCell(cell, p, theta < 90, lit + (1 - lit) * math.abs(math.cos(math.rad(theta))), 3)
    end
    if not cell.shown then
      cell.texture:Hide()
    end
  end
  self:drawEdges(p, byCell)
  self:drawShadows(phase, angle, F, place)
  self:drawNotes(phase, F, place, frame)
end

-- drawShadows draws the shadow under what shows, on the world, and the shadow a flap casts as it lifts.
---@private
---@param phase string
---@param angle number
---@param F? table
---@param place fun(x: number, y: number, z: number): number, number
function runProto:drawShadows(phase, angle, F, place)
  local S = self.spec.Shadow
  if S == nil then
    return
  end
  local left, right, bottom, top = math.huge, -math.huge, math.huge, -math.huge
  for _, cell in ipairs(self.cells) do
    if cell.shown then
      local c = { cell.texture:GetVertexOffset(UL) }
      local d = { cell.texture:GetVertexOffset(LR) }
      left = math.min(left, c[1], d[1] + 1)
      right = math.max(right, c[1], d[1] + 1)
      top = math.max(top, c[2] + 1, d[2])
      bottom = math.min(bottom, c[2] + 1, d[2])
    end
  end
  local unit = self.scale
  local spread = (S.Spread or 0) * unit
  local sx, sy = (S.X or 0) * unit, (S.Y or 0) * unit
  local t = self.shadow
  quad(t, { x = left - spread + sx, y = top + spread + sy, u = 0, v = 0 },
    { x = left - spread + sx, y = bottom - spread + sy, u = 0, v = 1 },
    { x = right + spread + sx, y = top + spread + sy, u = 1, v = 0 },
    { x = right + spread + sx, y = bottom - spread + sy, u = 1, v = 1 })
  local c = self.shadowColor
  t:SetVertexColor(c[1], c[2], c[3], c[4] * (self.fade or 1))
  t:Show()
  local flapShadow = self.flapShadow
  if flapShadow == nil then
    return
  end
  local strength = (F ~= nil) and math.abs(math.sin(math.rad(angle))) or 0
  flapShadow:SetVertexColor(c[1], c[2], c[3], c[4] * strength)
  if strength <= 0.001 or F == nil then
    flapShadow:Hide()
    return
  end
  -- From the hinge to under the flap's far end, a little past it, across the flap's width.
  local n = self.halves
  local reach, a0, b0
  if phase == "half" then
    reach, a0, b0 = F.x[n], self.w / 2, 0
    local a1 = a0 + reach * 1.15
    local x0, x1 = self.x0 + self.dirA * a0, self.x0 + self.dirA * a1
    local y0, y1 = self.y0 + self.dirB * b0, self.y0 + self.dirB * self.h / 2
    self:shadowQuad(flapShadow, place, x0, y0, x1, y1, spread)
  else
    reach, b0 = F.x[n], self.h / 2
    local b1 = b0 + reach * 1.15
    local x0, x1 = self.x0, self.x0 + self.dirA * self.w
    local y0, y1 = self.y0 + self.dirB * b0, self.y0 + self.dirB * b1
    self:shadowQuad(flapShadow, place, x0, y0, x1, y1, spread)
  end
  flapShadow:Show()
end

-- shadowQuad draws a flap's shadow over a rect of the sheet.
---@private
function runProto:shadowQuad(t, place, x0, y0, x1, y1, spread)
  local left, right = math.min(x0, x1) - spread, math.max(x0, x1) + spread
  local bottom, top = math.min(y0, y1) - spread, math.max(y0, y1) + spread
  local ax, ay = place(left, top, 0)
  local bx, by = place(left, bottom, 0)
  local cx, cy = place(right, top, 0)
  local dx, dy = place(right, bottom, 0)
  quad(t, { x = ax, y = ay, u = 0, v = 0 }, { x = bx, y = by, u = 0, v = 1 }, { x = cx, y = cy, u = 1, v = 0 },
    { x = dx, y = dy, u = 1, v = 1 })
end

-- drawNotes draws what is on the outside of the folded sheet (Open.Note: X across from the middle of the quarter, Y down
-- from it, both as it lies folded), upright as it lies folded, turning with the flap until it swings past upright.
---@private
---@param phase string
---@param F? table
---@param place fun(x: number, y: number, z: number, i?: integer, j?: integer): number, number
---@param frame integer
function runProto:drawNotes(phase, F, place, frame)
  local n = self.halves
  for _, note in ipairs(self.notes) do
    local t = note.texture
    if phase ~= "half" or F == nil or F.theta[n] < 90 then
      t:Hide()
    else
      local o = note.spec
      local unit = self.scale
      local length = self.w / 2
      -- Where it lies folded: the flap over the quarter, away from the hinge.
      local hinge = self.x0 + self.dirA * length
      local cx = self.x0 + self.dirA * length / 2 + (o.X or 0) * unit
      local cy = self.y0 + self.dirB * self.h / 4 - (o.Y or 0) * unit
      local hw, hh = (o.Width or 0) * unit / 2, (o.Height or 0) * unit / 2
      local ds = length / n
      local function corner(x, y, u, v)
        -- How far from the hinge it lies folded, and where the flap has that now.
        local d = (hinge - x) * self.dirA
        local fx, fz = along(F, d, ds, n)
        local px, py = place(self.x0 + self.dirA * (length + fx), y, fz)
        return { x = px, y = py, u = u, v = v }
      end
      local frames = o.Frames or 1
      local index = frame % frames
      local u0, u1 = index / frames, (index + 1) / frames
      quad(t, corner(cx - hw, cy + hh, u0, 0), corner(cx - hw, cy - hh, u0, 1), corner(cx + hw, cy + hh, u1, 0),
        corner(cx + hw, cy - hh, u1, 1))
      local c = note.color
      local theta = F.theta[n]
      local lit = self.spec.Open.Lit or 0.6
      local shade = lit + (1 - lit) * math.abs(math.cos(math.rad(theta)))
      t:SetVertexColor(c[1] * shade, c[2] * shade, c[3] * shade, c[4])
      t:Show()
    end
  end
end

-- Unfold draws the open t seconds in, and returns the panel's alpha: none until the sheet lies flat, then all of it. As
-- stop motion it draws a frame's pose once and holds it; without, it runs between its poses every call.
---@param t number
---@return number alpha The panel's.
function runProto:Unfold(t)
  local rate = self.spec.Rate
  local count = #self.poses
  local at = t * rate
  if at >= count - 1e-6 then
    if self.frame ~= count then
      self.frame = count
      self:drawFold("flat", 0, 1, 0, count)
    end
    return 1
  end
  local frame = math.max(0, math.floor(at + 1e-6))
  local pose = self.poses[frame + 1]
  if self.stepped then
    if self.frame ~= frame then
      self.frame = frame
      self:drawFold(pose.phase, self:PoseAngle(frame), pose.scale, pose.turn, frame)
    end
    return 0
  end
  local nextPose = self.poses[frame + 2] or pose
  local f = at - frame
  local from, phase = pose.angle, pose.phase
  -- Turning from the first fold to the second: the second's flap starts folded right over.
  if nextPose.phase ~= pose.phase then
    from, phase = 180, nextPose.phase
  end
  self:drawFold(phase, from + (nextPose.angle - from) * f, pose.scale + (nextPose.scale - pose.scale) * f,
    pose.turn + (nextPose.turn - pose.turn) * f, frame)
  return 0
end

-- Linger lets the flat sheet go by itself on the layer's driver, a pose at a time, over its Reveal: the panel shows
-- under it.
function runProto:Linger()
  self.elapsed = 0
  self.frame = nil
  paper:run(self)
end

-- setStrength draws the flat sheet at a share of its strength as it goes.
---@private
---@param strength number
function runProto:setStrength(strength)
  self.fade = strength
  local function fade(t, color, shade)
    t:SetVertexColor(color[1] * shade, color[2] * shade, color[3] * shade, color[4] * strength)
  end
  for _, cell in ipairs(self.cells) do
    if cell.shown then
      fade(cell.texture, self.frontColor, 1)
    end
  end
  for _, edge in ipairs(self.edges) do
    fade(edge.texture, self.edgeColor, 1)
  end
  if self.shadow ~= nil then
    local c = self.shadowColor
    self.shadow:SetVertexColor(c[1], c[2], c[3], c[4] * strength)
  end
end

-- live lives a run on elapsed seconds on the driver: an unfolded sheet going, or a crumpled ball flying.
---@private
---@param elapsed number
function runProto:live(elapsed)
  self.elapsed = self.elapsed + elapsed
  if self.phase == "Open" then
    local rate, frames = self.spec.Rate, self.spec.Open.Reveal or 0
    local at = self.elapsed * rate
    if at >= frames - 1e-6 then
      self:Release()
    elseif self.stepped then
      local frame = math.floor(at + 1e-6)
      if frame ~= self.frame then
        self.frame = frame
        self:setStrength(1 - frame / frames)
      end
    else
      self:setStrength(1 - at / frames)
    end
    return
  end
  self:flyOn()
end

-- run hands a run to the layer's driver.
---@private
---@param run NextPaperRun
function paper:run(run)
  self.living[run] = true
  local driver = self:Layer().driver
  if driver:GetScript("OnUpdate") == nil then
    driver:SetScript("OnUpdate", function(_, elapsed)
      self:Step(elapsed)
    end)
  end
end

-- Step lives every run on the driver on elapsed seconds, and stops the driver when none is left.
---@param elapsed number
function paper:Step(elapsed)
  for run in pairs(self.living) do
    run:live(elapsed)
  end
  if next(self.living) == nil then
    self:Layer().driver:SetScript("OnUpdate", nil)
  end
end

-- beginCrumple lays out a crumpling sheet: the shatter's mesh over the body, with where each corner goes (Warp), its
-- torn edge along the sheet's sides, and what is printed on it.
---@private
---@param panel table
function runProto:beginCrumple(panel)
  local S = self.spec
  local C = S.Close
  local unit = self.scale
  self.cx, self.cy = self.left + self.w / 2, self.top - self.h / 2
  local rect = { left = self.left, top = self.top, width = self.w, height = self.h }
  local mesh = shatter:Mesh(rect, (C.Cell or 64) * unit, C.Jitter or 0)
  self.mesh = mesh
  self.ball = (C.Ball or 40) * unit
  -- The sines its lumps and wrinkles are made of: a sheet's own, each run's.
  self.lumps = {}
  for k = 1, 4 do
    self.lumps[k] = {}
    for w = 1, 4 do
      self.lumps[k][w] = { fu = 2 + paper.Random() * 9, fv = 2 + paper.Random() * 9, p = paper.Random() * 6.283 }
    end
  end
  for _, vert in ipairs(mesh.verts) do
    vert.jx, vert.jy, vert.jz = 2 * paper.Random() - 1, 2 * paper.Random() - 1, 2 * paper.Random() - 1
  end
  for _, tr in ipairs(mesh.tris) do
    local t = take("ARTWORK", 0)
    table.insert(self.tris, { texture = t, a = tr[1], b = tr[2], c = tr[3], fleck = paper.Random() - 0.5 })
  end
  if S.Edge then
    local tile = (S.Edge.Tile or 128) * unit
    local eps = 1e-6
    local reach = (S.Edge.Width or 0) * unit
    for _, e in ipairs(mesh.edges) do
      local a, b = mesh.verts[e[1]], mesh.verts[e[2]]
      local du, dv
      if a.u < eps and b.u < eps then
        du, dv = -reach / self.w, 0
      elseif a.u > 1 - eps and b.u > 1 - eps then
        du, dv = reach / self.w, 0
      elseif a.v < eps and b.v < eps then
        du, dv = 0, -reach / self.h
      elseif a.v > 1 - eps and b.v > 1 - eps then
        du, dv = 0, reach / self.h
      end
      if du ~= nil then
        local t = take("ARTWORK", 0)
        art(t, self.edgeFile, true)
        local along0 = (a.u * self.w + a.v * self.h) / tile
        local along1 = (b.u * self.w + b.v * self.h) / tile
        table.insert(self.edges, { a = e[1], b = e[2], du = du, dv = dv, u0 = along0, u1 = along1, texture = t })
      end
    end
  end
  -- Each item printed on the sheet: its mount under it, and its icon.
  local crop = C.Crop or 0
  for _, d in ipairs(panel.PaperDecals and panel:PaperDecals() or {}) do
    local decal = {
      u0 = (d.left - self.left) / self.w, v0 = (self.top - d.top) / self.h,
      u1 = (d.left + d.width - self.left) / self.w, v1 = (self.top - d.top + d.height) / self.h,
      texture = take("OVERLAY", 1), crop = crop,
    }
    art(decal.texture, d.texture, false)
    decal.texture:SetVertexColor(1, 1, 1, 1)
    if C.Mount then
      decal.mount = take("OVERLAY", 0)
      art(decal.mount, path(C.Mount), false)
      decal.mountColor = rgba(C.Mount)
    end
    table.insert(self.decals, decal)
  end
  local T = C.Toss or {}
  local drift = between(T.Drift or { 0, 0 }) * unit
  self.vx = self.innerRight and -drift or drift
  self.vy = (T.Up or 0) * unit
  self.gravity = (T.Gravity or 0) * unit
  local tumble = T.Tumble or { 0, 0 }
  self.spinX = (paper.Random() < 0.5 and -1 or 1) * tumble[1]
  self.spinY = (paper.Random() < 0.5 and -1 or 1) * tumble[2]
end

-- wave is a smooth wander over the sheet, -1 to 1: lump k, its sines.
---@private
---@param k integer
---@param u number
---@param v number
---@return number
function runProto:wave(k, u, v)
  local sum = 0
  for _, s in ipairs(self.lumps[k]) do
    sum = sum + math.sin(s.fu * u + s.fv * v + s.p)
  end
  return sum / 4
end

-- Warp is where a point of the sheet (u, v: 0 to 1 across and down it) lies at a crumple's progress c (0 flat, 1 a ball),
-- from the sheet's middle, z toward the viewer. Wrapped round a ball from its middle out: its middle stays toward the
-- viewer and its edges gather behind. Its edges start first (Lag), lumps make the ball no sphere (Lump), and wrinkles
-- rise and sink on the way (Wrinkle).
---@param u number
---@param v number
---@param c number
---@return number x, number y, number z
function runProto:Warp(u, v, c)
  local C = self.spec.Close
  local nx, ny = 2 * u - 1, 2 * v - 1
  local r = math.min(1, math.sqrt(nx * nx + ny * ny) / SQRT2)
  local phi = math.atan2(-ny, nx) + (C.Twist or 0) * c
  local lag = (C.Lag or 0) * (1 - r)
  local q = clamp01((c - lag) / (1 - lag))
  local e = q * q * (3 - 2 * q)
  local alpha = r * math.pi * (C.Wrap or 0.92)
  local radius = self.ball * (1 + (C.Lump or 0) * self:wave(1, u, v))
  local sinA = math.sin(alpha)
  local fx, fy = (u - 0.5) * self.w, (0.5 - v) * self.h
  local wrinkle = (C.Wrinkle or 0) * self.scale * math.sin(math.pi * q)
  local x = fx + (radius * sinA * math.cos(phi) - fx) * e + wrinkle * self:wave(2, u, v)
  local y = fy + (radius * sinA * math.sin(phi) - fy) * e + wrinkle * self:wave(3, u, v)
  local z = radius * math.cos(alpha) * e + wrinkle * self:wave(4, u, v)
  return x, y, z
end

-- Grab is how far across the panel is shaken t seconds into being grabbed: less and less, a new way each frame.
---@param t number
---@return number
function runProto:Grab(t)
  local C = self.spec.Close
  local rate = self.spec.Rate
  local frame = stopMotion:Frame(t, rate)
  local time = paper:GrabTime()
  local left = time > 0 and clamp01(1 - frame / rate / time) or 0
  return (C.Tremble or 0) * self.scale * self:noise(frame, 5) * left
end

-- Crumple takes the panel's place: the sheet draws its first pose, and lives on by itself on the layer's driver.
function runProto:Crumple()
  self.elapsed = 0
  self.frame = nil
  self:flyOn()
  paper:run(self)
end

-- flyOn draws the crumple and the toss as far as the run has lived: its Poses, then the ball tossed up and falling. It
-- gives everything back once the ball is off the bottom of the screen, or at its Life. As stop motion it draws each
-- frame once and holds it.
---@private
function runProto:flyOn()
  local S = self.spec
  local C = S.Close
  local rate = S.Rate
  local poses = C.Poses
  local at = self.elapsed * rate
  local frame = math.floor(at + 1e-6)
  if self.elapsed >= ((C.Toss and C.Toss.Life) or 3) then
    self:Release()
    return
  end
  if self.stepped and frame == self.frame then
    return
  end
  self.frame = frame
  local last = #poses - 1
  local toss, c = 0, 1
  if frame >= last then
    toss = (self.stepped and frame / rate or self.elapsed) - last / rate
  elseif self.stepped then
    c = poses[frame + 1]
  else
    local f = at - frame
    c = poses[frame + 1] + (poses[frame + 2] - poses[frame + 1]) * f
  end
  local y = self.cy + self.vy * toss - 0.5 * self.gravity * toss * toss
  if y + self.ball * OFF_SCREEN < 0 then
    self:Release()
    return
  end
  self:DrawCrumple(c, toss)
end

-- DrawCrumple draws the sheet at a crumple's progress c, toss seconds after it was tossed: each corner where Warp puts
-- it, tumbled, carried along the toss's arc, placed imperfectly as stop motion; nearer facets over farther ones, shaded
-- by how they face the light, those facing away showing the paper's back.
---@param c number
---@param toss number
function runProto:DrawCrumple(c, toss)
  local S = self.spec
  local C = S.Close
  local frame = self.frame or 0
  local W = self.stepped and self.wobble or {}
  local unit = self.scale
  local ox = self.cx + self.vx * toss + (W.Move or 0) * unit * self:noise(frame, 6)
  local oy = self.cy + self.vy * toss - 0.5 * self.gravity * toss * toss + (W.Move or 0) * unit * self:noise(frame, 7)
  local ax, ay = self.spinX * toss, self.spinY * toss
  local cax, sax, cay, say = math.cos(ax), math.sin(ax), math.cos(ay), math.sin(ay)
  local turn = math.rad((W.Turn or 0) * self:noise(frame, 8))
  local ct, st = math.cos(turn), math.sin(turn)
  local vertex = (W.Vertex or 0) * unit
  local mesh = self.mesh
  local function place(u, v, key)
    local x, y, z = self:Warp(u, v, c)
    -- Tumbled about across and up.
    local y1, z1 = y * cax - z * sax, y * sax + z * cax
    local x2, z2 = x * cay + z1 * say, -x * say + z1 * cay
    local x3, y3 = x2 * ct - y1 * st, x2 * st + y1 * ct
    if vertex ~= 0 and key ~= nil then
      x3 = x3 + vertex * self:noise(frame, key)
      y3 = y3 + vertex * self:noise(frame, key + 13)
    end
    return ox + x3, oy + y3, z2
  end
  -- Each corner its own way, as a sheet's corners fold every which way: most on the way, a little left on the ball.
  local jag = (C.Jag or 0) * unit * (math.sin(math.pi * c) + JAG_REST * c)
  local at = {}
  for k, vert in ipairs(mesh.verts) do
    local x, y, z = place(vert.u, vert.v, k * 7)
    at[k] = { x = x + jag * vert.jx, y = y + jag * vert.jy, z = z + jag * vert.jz, fu = (vert.x - self.fl) / self.fw,
      fv = (self.ft - vert.y) / self.fh, bu = vert.u, bv = vert.v }
  end
  self.lastAt = at
  local lit, facet = C.Lit or 0.55, (C.Facet or 0) * c
  local depth = math.max(self.ball, 1)
  local function sublevel(z)
    return math.max(-8, math.min(7, math.floor((z / depth + 1) * 8) - 8))
  end
  for _, t in ipairs(self.tris) do
    local a, b, d = at[t.a], at[t.b], at[t.c]
    local ux, uy, uz = b.x - a.x, b.y - a.y, b.z - a.z
    local vx, vy, vz = d.x - a.x, d.y - a.y, d.z - a.z
    -- Its normal: the sheet's front faces the viewer as it lies flat.
    local nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    local len = math.sqrt(nx * nx + ny * ny + nz * nz)
    if len < 1e-6 then
      t.texture:Hide()
    else
      nx, ny, nz = nx / len, ny / len, nz / len
      local front = nz >= 0
      if not front then
        nx, ny, nz = -nx, -ny, -nz
      end
      local facing = (nx * LIGHT_X + ny * LIGHT_Y + nz * LIGHT_Z) / LIGHT_Z
      local shade = math.max(0, math.min(1, lit + (1 - lit) * math.max(0, math.min(1, facing)) + facet * t.fleck))
      local tex = t.texture
      art(tex, front and self.front or self.back, false)
      local function corner(p)
        return { x = p.x, y = p.y, u = front and p.fu or p.bu, v = front and p.fv or p.bv }
      end
      tri(tex, corner(a), corner(b), corner(d))
      local color = front and self.frontColor or self.backColor
      tex:SetVertexColor(color[1] * shade, color[2] * shade, color[3] * shade, color[4])
      tex:SetDrawLayer("ARTWORK", sublevel((a.z + b.z + d.z) / 3))
      tex:Show()
    end
  end
  self:drawCrumpleEdges(place, at, c, sublevel, jag)
  self:drawDecals(place, c)
  self:drawCrumpleShadow(ox, oy, c)
end

-- drawCrumpleShadow draws the shadow a crumpling sheet casts, drawing in with it, and gone by the time it is a ball: a ball
-- in the air casts none on the screen.
---@private
---@param ox number The sheet's middle.
---@param oy number
---@param c number
function runProto:drawCrumpleShadow(ox, oy, c)
  local t = self.shadow
  if t == nil then
    return
  end
  local left = 1 - c
  if left <= 0.02 then
    t:Hide()
    return
  end
  local S = self.spec.Shadow
  local unit = self.scale
  local spread = (S.Spread or 0) * unit
  local sx, sy = (S.X or 0) * unit, (S.Y or 0) * unit
  local width = self.ball + (self.w / 2 - self.ball) * left + spread
  local height = self.ball + (self.h / 2 - self.ball) * left + spread
  quad(t, { x = ox - width + sx, y = oy + height + sy, u = 0, v = 0 }, { x = ox - width + sx, y = oy - height + sy, u = 0, v = 1 },
    { x = ox + width + sx, y = oy + height + sy, u = 1, v = 0 }, { x = ox + width + sx, y = oy - height + sy, u = 1, v = 1 })
  local color = self.shadowColor
  t:SetVertexColor(color[1], color[2], color[3], color[4] * left)
  t:Show()
end

-- drawCrumpleEdges draws the torn edge along the sheet's sides, crumpling with it.
---@private
function runProto:drawCrumpleEdges(place, at, c, sublevel, jag)
  local color = self.edgeColor
  for _, edge in ipairs(self.edges) do
    local a, b = at[edge.a], at[edge.b]
    local va, vb = self.mesh.verts[edge.a], self.mesh.verts[edge.b]
    local ox0, oy0 = place(va.u + edge.du, va.v + edge.dv)
    local ox1, oy1 = place(vb.u + edge.du, vb.v + edge.dv)
    ox0, oy0 = ox0 + jag * va.jx, oy0 + jag * va.jy
    ox1, oy1 = ox1 + jag * vb.jx, oy1 + jag * vb.jy
    local t = edge.texture
    quad(t, { x = ox0, y = oy0, u = edge.u0, v = 0 }, { x = a.x, y = a.y, u = edge.u0, v = 1 },
      { x = ox1, y = oy1, u = edge.u1, v = 0 }, { x = b.x, y = b.y, u = edge.u1, v = 1 })
    local shade = 1 - 0.3 * c
    t:SetVertexColor(color[1] * shade, color[2] * shade, color[3] * shade, color[4])
    t:SetDrawLayer("ARTWORK", sublevel((a.z + b.z) / 2))
    t:Show()
  end
end

-- drawDecals draws what is printed on the sheet, each corner where Warp puts it, hidden once it has turned from the
-- viewer or gone round the ball's side (it draws over the paper, so paper cannot hide it).
---@private
function runProto:drawDecals(place, c)
  -- Nothing overlaps until the sheet has drawn in on itself; then only the ball's near side shows them.
  local front = -math.huge
  if c > PRINT_FROM then
    front = self.ball * (PRINT_BEHIND + clamp01((c - PRINT_FROM) / (PRINT_TO - PRINT_FROM)) * (PRINT_AHEAD - PRINT_BEHIND))
  end
  for _, d in ipairs(self.decals) do
    local ax, ay, az = place(d.u0, d.v0)
    local bx, by, bz = place(d.u0, d.v1)
    local cx, cy, cz = place(d.u1, d.v0)
    local ex, ey, ez = place(d.u1, d.v1)
    local facing = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
    local near = (az + bz + cz + ez) / 4
    local shown = facing > 0 and near >= front
    if shown then
      local crop = d.crop
      quad(d.texture, { x = ax, y = ay, u = crop, v = crop }, { x = bx, y = by, u = crop, v = 1 - crop },
        { x = cx, y = cy, u = 1 - crop, v = crop }, { x = ex, y = ey, u = 1 - crop, v = 1 - crop })
      d.texture:Show()
      if d.mount ~= nil then
        quad(d.mount, { x = ax, y = ay, u = 0, v = 0 }, { x = bx, y = by, u = 0, v = 1 }, { x = cx, y = cy, u = 1, v = 0 },
          { x = ex, y = ey, u = 1, v = 1 })
        local m = d.mountColor
        d.mount:SetVertexColor(m[1], m[2], m[3], m[4])
        d.mount:Show()
      end
    else
      d.texture:Hide()
      if d.mount ~= nil then
        d.mount:Hide()
      end
    end
  end
end

-- Release gives the run's textures back, hidden, at once; a run released again does nothing.
function runProto:Release()
  paper.living[self] = nil
  local function give(t)
    if t ~= nil then
      t:Hide()
      table.insert(paper.pool, t)
    end
  end
  for _, list in ipairs({ self.cells, self.tris, self.edges, self.notes }) do
    for _, item in ipairs(list) do
      give(item.texture)
    end
  end
  for _, d in ipairs(self.decals) do
    give(d.texture)
    give(d.mount)
  end
  give(self.shadow)
  give(self.flapShadow)
  self.cells, self.tris, self.edges, self.notes, self.decals = {}, {}, {}, {}, {}
  self.shadow, self.flapShadow = nil, nil
end
