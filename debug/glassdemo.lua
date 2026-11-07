-- luacheck: globals SLASH_BETTERBAGSGLASS1 SlashCmdList
local addonName = ... ---@type string

-- A throwaway tech demo: glass, without shaders. At login three windows open, each a different glass (frosted, stained,
-- a plain window), with a sun you can drag about the screen; the cursor is a second, smaller light. /glass shows or
-- hides it all. It is built from nothing but blend modes, alpha, color and a light model in Lua:
--   MOD   multiplies the screen behind by a color: glass that filters what is behind it, darkening, never brightening.
--   BLEND toward a color: glass that scatters light (frost), or has a body color of its own.
--   ADD   light the glass passes on or reflects.
-- Every ADD layer's alpha comes from where that part of the glass is on the screen against the two lights, so moving a
-- window, the sun or the cursor moves its glints, reflections and glow, and the light and shadow it casts.

-- Blizzard's vertex indices (Blizzard_FrameXMLBase/Constants.lua).
local UL, LL, UR, LR = 1, 2, 3, 4

local WHITE = "Interface\\Buttons\\WHITE8X8"
local ART = "Interface\\AddOns\\" .. addonName .. "\\textures\\next\\"
local GLOW = ART .. "glow.png"
local GLINT = ART .. "makeitso\\glint.png"
local NOISE = ART .. "glitch\\noise.png"
local FROST = ART .. "frost\\frost.png"
local VIGNETTE = ART .. "glitch\\vignette.png"
local DOT = ART .. "icons\\circle.png"
local NOISE_SIZE = 128

local sqrt, exp, sin, cos, abs = math.sqrt, math.exp, math.sin, math.cos, math.abs
local min, max, floor, ceil = math.min, math.max, math.floor, math.ceil
local pi, random = math.pi, math.random

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function smoothstep(e0, e1, x)
  local t = clamp((x - e0) / (e1 - e0), 0, 1)
  return t * t * (3 - 2 * t)
end

-- Two colors reused for every gradient: SetGradient reads them as it is called.
local gradA, gradB = CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 1)
local function gradient(t, orient, r1, g1, b1, a1, r2, g2, b2, a2)
  gradA:SetRGBA(r1, g1, b1, a1)
  gradB:SetRGBA(r2, g2, b2, a2)
  t:SetGradient(orient, gradA, gradB)
end

-- paint makes a texture on a frame: a file (plain white without one), a blend mode and a color. Tiled, the file repeats
-- past its edges, for texture coordinates beyond 0 to 1.
local function paint(frame, layer, sub, file, blend, r, g, b, a, tiled)
  local t = frame:CreateTexture(nil, layer, nil, sub)
  if tiled then
    t:SetTexture(file, "REPEAT", "REPEAT")
  else
    t:SetTexture(file or WHITE)
  end
  t:SetBlendMode(blend or "BLEND")
  t:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
  return t
end

-- loose makes a texture whose corners are moved where they are needed (quad): its rect is a unit square at the frame's
-- bottom left, never snapped to the pixel grid so it moves smoothly.
local function loose(frame, layer, sub, file, blend, r, g, b, a)
  local t = paint(frame, layer, sub, file, blend, r, g, b, a)
  t:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  t:SetSize(1, 1)
  t:SetSnapToPixelGrid(false)
  t:SetTexelSnappingBias(0)
  return t
end

-- quad moves a loose texture's four corners onto four points in its frame's units (bottom left origin, y up).
local function quad(t, ulx, uly, llx, lly, urx, ury, lrx, lry)
  t:SetVertexOffset(UL, ulx, uly - 1)
  t:SetVertexOffset(LL, llx, lly)
  t:SetVertexOffset(UR, urx - 1, ury - 1)
  t:SetVertexOffset(LR, lrx - 1, lry)
end

-- tri lays a loose texture on a triangle, its fourth corner on its third. Points are { x, y }.
local function tri(t, a, b, c)
  quad(t, a[1], a[2], b[1], b[2], c[1], c[2], c[1], c[2])
end

-- oblong lays a loose texture on a turned rect: its middle at (cx, cy), its length along angle.
local function oblong(t, cx, cy, angle, length, width)
  local ux, uy = cos(angle), sin(angle)
  local nx, ny = -uy, ux
  local hl, hw = length / 2, width / 2
  quad(t, cx - ux * hl + nx * hw, cy - uy * hl + ny * hw,
    cx - ux * hl - nx * hw, cy - uy * hl - ny * hw,
    cx + ux * hl + nx * hw, cy + uy * hl + ny * hw,
    cx + ux * hl - nx * hw, cy + uy * hl - ny * hw)
end

-- band lays two loose textures as one soft band of light: each half a gradient from the band's middle line out to
-- nothing, so it is brightest along its middle.
local function band(lo, hi, cx, cy, angle, length, width)
  local nx, ny = -sin(angle), cos(angle)
  local q = width / 4
  oblong(lo, cx - nx * q, cy - ny * q, angle, length, width / 2)
  oblong(hi, cx + nx * q, cy + ny * q, angle, length, width / 2)
end

-- place puts a texture over a rect in its frame's units.
local function place(t, frame, x, y, w, h)
  t:ClearAllPoints()
  t:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, y)
  t:SetSize(w, h)
end

-- centre puts a texture's middle at a point in its frame's units.
local function centre(t, frame, x, y, w, h)
  t:ClearAllPoints()
  t:SetPoint("CENTER", frame, "BOTTOMLEFT", x, y)
  t:SetSize(w, h or w)
end

-- outline draws a rect's four edges, thick pixels wide, inside it.
local function outline(frame, layer, sub, x, y, w, h, thick, r, g, b, a)
  place(paint(frame, layer, sub, WHITE, "BLEND", r, g, b, a), frame, x, y + h - thick, w, thick)
  place(paint(frame, layer, sub, WHITE, "BLEND", r, g, b, a), frame, x, y, w, thick)
  place(paint(frame, layer, sub, WHITE, "BLEND", r, g, b, a), frame, x, y + thick, thick, h - 2 * thick)
  place(paint(frame, layer, sub, WHITE, "BLEND", r, g, b, a), frame, x + w - thick, y + thick, thick, h - 2 * thick)
end

---------------------------------------------------------------------------------------------------------------------
-- The light. Positions are in UIParent's units, y up. The sun is far-reaching and falls off slowly; the cursor is a
-- lamp, bright close up and gone a little way off.

local light = { sx = 0, sy = 0, cx = -10000, cy = -10000, t = 0, dirty = true }
local SUN_REACH, LAMP_REACH = 520, 150

local function sunAt(x, y)
  local dx, dy = x - light.sx, y - light.sy
  return 1 / (1 + (dx * dx + dy * dy) / (SUN_REACH * SUN_REACH))
end

local function lampAt(x, y)
  local dx, dy = x - light.cx, y - light.cy
  return exp(-(dx * dx + dy * dy) / (LAMP_REACH * LAMP_REACH))
end

-- facing is how squarely an edge at (x, y), whose outward normal is (nx, ny), faces a light at (lx, ly): the far side
-- of an edge still glints a little.
local function facing(x, y, nx, ny, lx, ly)
  local dx, dy = lx - x, ly - y
  local d = sqrt(dx * dx + dy * dy)
  if d < 1 then return 1 end
  return 0.2 + 0.8 * max(0, (dx * nx + dy * ny) / d)
end

-- away is the way from the sun to a point, as a unit vector, and how far it is.
local function away(x, y)
  local dx, dy = x - light.sx, y - light.sy
  local d = sqrt(dx * dx + dy * dy)
  if d < 1 then return 0, -1, d end
  return dx / d, dy / d, d
end

---------------------------------------------------------------------------------------------------------------------
-- Rims: a pane's edges, cut into short pieces, each shaded from the light at its two ends, so an edge glints where the
-- sun or the cursor falls on it and the glint fades along it.

local function newRim(frame, x, y, w, h, segments, thick, strength)
  local rim = { pieces = {}, strength = strength }
  local edges = {
    { x, y + h, x + w, y + h, 0, 1 },
    { x, y, x + w, y, 0, -1 },
    { x, y, x, y + h, -1, 0 },
    { x + w, y, x + w, y + h, 1, 0 },
  }
  for _, e in ipairs(edges) do
    local ax, ay, bx, by, nx, ny = unpack(e)
    local across = ny ~= 0
    for i = 1, segments do
      local x1, y1 = ax + (bx - ax) * (i - 1) / segments, ay + (by - ay) * (i - 1) / segments
      local x2, y2 = ax + (bx - ax) * i / segments, ay + (by - ay) * i / segments
      local t = paint(frame, "OVERLAY", 2, WHITE, "ADD")
      if across then
        place(t, frame, x1, ny > 0 and (y1 - thick) or y1, x2 - x1, thick)
      else
        place(t, frame, nx > 0 and (x1 - thick) or x1, y1, thick, y2 - y1)
      end
      table.insert(rim.pieces, {
        t = t, x1 = x1, y1 = y1, x2 = x2, y2 = y2, nx = nx, ny = ny, orient = across and "HORIZONTAL" or "VERTICAL",
      })
    end
  end
  return rim
end

local function rimLight(x, y, nx, ny)
  return 0.9 * sunAt(x, y) * facing(x, y, nx, ny, light.sx, light.sy)
    + 1.1 * lampAt(x, y) * facing(x, y, nx, ny, light.cx, light.cy)
end

-- shadeRim lights a rim whose frame's bottom left is at (ox, oy) on the screen.
local function shadeRim(rim, ox, oy)
  for _, p in ipairs(rim.pieces) do
    local a1 = min(1, 0.05 + rim.strength * rimLight(ox + p.x1, oy + p.y1, p.nx, p.ny))
    local a2 = min(1, 0.05 + rim.strength * rimLight(ox + p.x2, oy + p.y2, p.nx, p.ny))
    gradient(p.t, p.orient, 1, 0.97, 0.92, a1, 1, 0.97, 0.92, a2)
  end
end

---------------------------------------------------------------------------------------------------------------------
-- Shadows: what a window's solid parts cast on the screen behind it, away from the sun. Their rects (in the window's
-- units, a fifth number for how much light that part stops) are drawn black four times, a pixel or two apart, so the
-- shadow's edge is soft; on a frame under every window, moved each time the light or the window does.

local SHADOW_TAPS = { { 0, 0 }, { 1.6, 0.4 }, { -0.4, 1.6 }, { 0.9, -1.4 } }

local function newShadow(f, rects, alpha, reach)
  local s = CreateFrame("Frame", nil, f)
  s:SetFrameStrata("LOW")
  s:SetSize(f:GetWidth(), f:GetHeight())
  for _, tap in ipairs(SHADOW_TAPS) do
    for _, r in ipairs(rects) do
      local each = 1 - (1 - alpha * (r[5] or 1)) ^ (1 / #SHADOW_TAPS)
      place(paint(s, "ARTWORK", 0, WHITE, "BLEND", 0, 0, 0, each), s, r[1] + tap[1], r[2] + tap[2], r[3], r[4])
    end
  end
  return { frame = s, owner = f, reach = reach }
end

local function castShadow(sh)
  local cx, cy = sh.owner:GetCenter()
  local dx, dy, d = away(cx, cy)
  local reach = sh.reach * clamp(d / 450, 0.3, 1.5)
  sh.frame:ClearAllPoints()
  sh.frame:SetPoint("CENTER", sh.owner, "CENTER", dx * reach, dy * reach)
  sh.frame:SetAlpha(0.45 + 0.55 * sunAt(cx, cy))
end

---------------------------------------------------------------------------------------------------------------------
-- slab draws the solid parts of a window's frame: each rect shaded by its height on the window (lit from above), with
-- one grain running across all of them so they read as one piece. A rect with a fifth value true is bevelled.

local function slab(frame, rects, H, lo, hi, tint)
  for _, r in ipairs(rects) do
    local x, y, w, h = r[1], r[2], r[3], r[4]
    local fill = paint(frame, "BACKGROUND", 0, WHITE, "BLEND")
    place(fill, frame, x, y, w, h)
    local foot, head = lo + (hi - lo) * y / H, lo + (hi - lo) * (y + h) / H
    gradient(fill, "VERTICAL", foot * tint[1], foot * tint[2], foot * tint[3], 1,
      head * tint[1], head * tint[2], head * tint[3], 1)
    local grain = paint(frame, "BACKGROUND", 1, NOISE, "BLEND", 0, 0, 0, 0.32, true)
    place(grain, frame, x, y, w, h)
    grain:SetTexCoord(x / NOISE_SIZE, (x + w) / NOISE_SIZE, (H - y - h) / NOISE_SIZE, (H - y) / NOISE_SIZE)
    if r[5] then
      place(paint(frame, "BACKGROUND", 2, WHITE, "BLEND", 1, 1, 1, 0.1), frame, x, y + h - 1, w, 1)
      place(paint(frame, "BACKGROUND", 2, WHITE, "BLEND", 0, 0, 0, 0.4), frame, x, y, w, 1)
    end
  end
end

---------------------------------------------------------------------------------------------------------------------
-- Windows

local windows = {}

local function newWindow(title, note, w, h, x, y)
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetSize(w, h)
  f:SetPoint("CENTER", UIParent, "CENTER", x, y)
  f:SetFrameStrata("MEDIUM")
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetScript("OnShow", function(self) self.ox = nil end)
  local base = f:GetFrameLevel()
  -- Over the glass: its frame, lead and rims.
  f.over = CreateFrame("Frame", nil, f)
  f.over:SetAllPoints()
  f.over:SetFrameLevel(base + 10)
  f.chrome = CreateFrame("Frame", nil, f)
  f.chrome:SetAllPoints()
  f.chrome:SetFrameLevel(base + 20)
  f.title = f.chrome:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.title:SetPoint("TOP", f, "TOP", 0, -8)
  f.title:SetText(title)
  f.note = f.chrome:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.note:SetPoint("BOTTOM", f, "BOTTOM", 0, 6)
  f.note:SetText(note)
  local close = CreateFrame("Button", nil, f.chrome)
  close:SetSize(20, 20)
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
  f.mark = close:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.mark:SetPoint("CENTER", 0, 1)
  f.mark:SetText("x")
  f.mark:SetAlpha(0.7)
  close:SetScript("OnEnter", function() f.mark:SetAlpha(1) end)
  close:SetScript("OnLeave", function() f.mark:SetAlpha(0.7) end)
  close:SetScript("OnClick", function() f:Hide() end)
  table.insert(windows, f)
  return f
end

---------------------------------------------------------------------------------------------------------------------
-- Frosted: ground glass with mist on it. The glass cools and dims what is behind it (MOD), scatters it (a veil BLENDed
-- toward white, the nearest a texture gets to a blur), and has a grain. Over that, mist: a fine grid of cells, each a
-- gradient into its neighbours, that the cursor wipes away along its path and that slowly forms again, unevenly. A
-- light glows broadly through it, where it falls on the pane, the way frosted glass spreads a lamp behind it.

local function buildFrosted()
  local W, H, CELL, MIST, BRUSH = 280, 330, 8, 0.42, 24
  local f = newWindow("Frosted", "move the cursor across it to wipe the mist", W, H, -370, -10)
  -- Etched into the glass: dark text, a light line under it.
  for _, text in ipairs({ f.title, f.note, f.mark }) do
    text:SetTextColor(0.1, 0.14, 0.2, 0.9)
    text:SetShadowColor(1, 1, 1, 0.55)
    text:SetShadowOffset(0, -1)
  end

  paint(f, "BACKGROUND", 0, WHITE, "MOD", 0.84, 0.89, 0.96):SetAllPoints()
  paint(f, "BACKGROUND", 1, WHITE, "BLEND", 0.86, 0.92, 1, 0.14):SetAllPoints()
  -- The grain: one noise twice, once lighter, once darker and mirrored so the two never line up.
  local grainLight = paint(f, "BACKGROUND", 2, NOISE, "ADD", 0.8, 0.9, 1, 0.08, true)
  grainLight:SetAllPoints()
  grainLight:SetTexCoord(0, W / NOISE_SIZE, 0, H / NOISE_SIZE)
  local grainDark = paint(f, "BACKGROUND", 3, NOISE, "BLEND", 0.04, 0.06, 0.1, 0.07, true)
  grainDark:SetAllPoints()
  grainDark:SetTexCoord(0.41 + W / NOISE_SIZE, 0.41, 0.73, 0.73 + H / NOISE_SIZE)
  -- Frost is thickest by the frame.
  paint(f, "BACKGROUND", 4, VIGNETTE, "BLEND", 0.9, 0.95, 1, 0.45):SetAllPoints()

  -- The mist. Cells count up from the bottom left, a row at a time.
  local cols, rows = ceil(W / CELL), ceil(H / CELL)
  local cells, fog, rate, wiped, wet, touched = {}, {}, {}, {}, {}, {}
  for r = 0, rows - 1 do
    for c = 0, cols - 1 do
      local i = r * cols + c + 1
      local t = paint(f, "BORDER", 0, WHITE, "BLEND")
      place(t, f, c * CELL, r * CELL, min(CELL, W - c * CELL), min(CELL, H - r * CELL))
      cells[i], fog[i], rate[i], touched[i] = t, 1, 0.7 + 0.6 * random(), true
    end
  end
  -- seen is a cell's mist as drawn: softened with the cells above and below it (the gradient softens it across).
  local function seen(c, r)
    local i = r * cols + clamp(c, 0, cols - 1) + 1
    local up = r < rows - 1 and fog[i + cols] or fog[i]
    local down = r > 0 and fog[i - cols] or fog[i]
    return (2 * fog[i] + up + down) / 4
  end
  local function shade(i)
    local c, r = (i - 1) % cols, floor((i - 1) / cols)
    local here = seen(c, r)
    local left, right = (seen(c - 1, r) + here) / 2, (seen(c + 1, r) + here) / 2
    gradient(cells[i], "HORIZONTAL", 0.93, 0.96, 1, MIST * left, 0.93, 0.96, 1, MIST * right)
  end
  -- touch marks a cell, and every cell drawn from it, to be drawn again.
  local function touch(i)
    local c, r = (i - 1) % cols, floor((i - 1) / cols)
    for rr = max(0, r - 1), min(rows - 1, r + 1) do
      for cc = max(0, c - 1), min(cols - 1, c + 1) do
        touched[rr * cols + cc + 1] = true
      end
    end
  end
  local function wipeAt(x, y)
    for r = max(0, floor((y - BRUSH) / CELL)), min(rows - 1, floor((y + BRUSH) / CELL)) do
      for c = max(0, floor((x - BRUSH) / CELL)), min(cols - 1, floor((x + BRUSH) / CELL)) do
        local dx, dy = (c + 0.5) * CELL - x, (r + 0.5) * CELL - y
        local d = sqrt(dx * dx + dy * dy)
        if d < BRUSH then
          local i = r * cols + c + 1
          local left = 0.06 + 0.94 * smoothstep(BRUSH * 0.3, BRUSH, d)
          if left < fog[i] then
            fog[i], wiped[i], wet[i] = left, light.t, true
            touch(i)
          end
        end
      end
    end
  end
  -- Mist forms again a moment after a wipe, slowly at first, each cell at its own pace.
  local function regrow(dt)
    for i in pairs(wet) do
      if light.t - wiped[i] > 1.2 then
        fog[i] = min(1, fog[i] + dt * 0.14 * rate[i] * (0.4 + fog[i]))
        touch(i)
        if fog[i] >= 1 then wet[i] = nil end
      end
    end
  end

  -- Ice grown from the corners: not mist, so it stays where the mist is wiped, and sparkles as the light falls on it.
  paint(f, "ARTWORK", 0, FROST, "BLEND", 0.93, 0.97, 1, 0.6):SetAllPoints()
  local sparkle = paint(f, "ARTWORK", 1, FROST, "ADD", 0.6, 0.8, 1, 1)
  sparkle:SetAllPoints()
  sparkle:SetAlpha(0)
  -- Lit as a whole, frosted glass glows.
  local bloom = paint(f, "ARTWORK", 2, WHITE, "ADD", 1, 0.97, 0.92, 1)
  bloom:SetAllPoints()
  bloom:SetAlpha(0)

  local clip = CreateFrame("Frame", nil, f)
  clip:SetAllPoints()
  clip:SetClipsChildren(true)
  local lit = CreateFrame("Frame", nil, clip)
  lit:SetAllPoints()
  local sunSpot = paint(lit, "ARTWORK", 0, GLOW, "ADD", 1, 0.92, 0.78, 1)
  local lampSpot = paint(lit, "ARTWORK", 1, GLOW, "ADD", 0.85, 0.93, 1, 1)

  -- The pane's edge: a hairline catching the light, and a darker line inside it, the glass's thickness.
  outline(f.over, "ARTWORK", 0, 0, 0, W, H, 1, 1, 1, 1, 0.25)
  outline(f.over, "ARTWORK", 0, 2, 2, W - 4, H - 4, 1, 0.05, 0.08, 0.12, 0.18)
  local rim = newRim(f.over, 0, 0, W, H, 14, 2, 1)
  local shadow = newShadow(f, { { 0, 0, W, H } }, 0.14, 14)

  local clock, px, py = 0, nil, nil
  function f:Tick(dt, relight)
    local ox, oy = self:GetLeft(), self:GetBottom()
    if not ox then return end
    if ox ~= self.ox or oy ~= self.oy then
      relight = true
      self.ox, self.oy = ox, oy
    end
    -- The cursor wipes the whole way it moved this frame, not only where it stopped. Dragging the window moves the
    -- cursor with it, so that wipes nothing.
    local lx, ly = light.cx - ox, light.cy - oy
    if lx >= 0 and lx <= W and ly >= 0 and ly <= H then
      if px == nil or lx ~= px or ly ~= py then
        local fromX, fromY = px or lx, py or ly
        local dx, dy = lx - fromX, ly - fromY
        local steps = max(1, ceil(sqrt(dx * dx + dy * dy) / 4))
        for s = 1, steps do
          wipeAt(fromX + dx * s / steps, fromY + dy * s / steps)
        end
      end
      px, py = lx, ly
    else
      px, py = nil, nil
    end
    clock = clock + dt
    if clock >= 0.05 then
      regrow(clock)
      clock = 0
    end
    for i in pairs(touched) do
      shade(i)
      touched[i] = nil
    end
    if not relight then return end
    -- Each light glows where it is nearest the pane: on it, or along the edge nearest it, broader and fainter the
    -- farther off it is.
    local sx, sy = light.sx - ox, light.sy - oy
    local nx, ny = clamp(sx, 0, W), clamp(sy, 0, H)
    local d = sqrt((sx - nx) ^ 2 + (sy - ny) ^ 2)
    centre(sunSpot, lit, nx, ny, clamp(240 + d * 1.1, 240, 720))
    sunSpot:SetAlpha(0.5 * sunAt(ox + nx, oy + ny))
    local cx, cy = light.cx - ox, light.cy - oy
    local mx, my = clamp(cx, 0, W), clamp(cy, 0, H)
    local md = sqrt((cx - mx) ^ 2 + (cy - my) ^ 2)
    centre(lampSpot, lit, mx, my, clamp(150 + md * 1.4, 150, 600))
    lampSpot:SetAlpha(0.55 * lampAt(ox + mx, oy + my))
    local sunHere = sunAt(ox + W / 2, oy + H / 2)
    bloom:SetAlpha(0.02 + 0.1 * sunHere)
    sparkle:SetAlpha(clamp(0.15 + 0.55 * sunHere + 0.6 * lampAt(ox + W / 2, oy + H / 2), 0, 1))
    shadeRim(rim, ox, oy)
    castShadow(shadow)
  end
  return f
end

---------------------------------------------------------------------------------------------------------------------
-- Stained: a rose window of 128 triangles, each a texture with its corners moved onto the triangle. Each piece is three
-- layers: a MOD filter (it tints the world behind it, the way colored glass takes out the other colors), a BLEND body
-- with a streak through it (old glass is uneven), and an ADD glow, the light it passes, bright where the sun or the
-- cursor is behind it and drifting as clouds cross the sun. The lead between them is Lines, its edge facing the sun
-- catching the light. The window casts its colors on the screen away from the sun: the pieces again, a little apart
-- (the lead's shadow between them), drawn three times a pixel apart to soften them.

local PALETTE = {
  ruby = { 0.78, 0.07, 0.12 }, sapphire = { 0.09, 0.2, 0.72 }, azure = { 0.16, 0.48, 0.86 },
  emerald = { 0.05, 0.52, 0.26 }, amber = { 0.96, 0.58, 0.07 }, gold = { 1, 0.8, 0.22 },
  opal = { 0.94, 0.86, 0.6 }, violet = { 0.42, 0.13, 0.6 }, deep = { 0.05, 0.1, 0.38 },
}

-- cloud is how much of the sun gets through at a point on the screen: clouds drifting across it.
local function cloud(x, y, t)
  return 0.76 + 0.24 * sin(t * 0.45 + x * 0.011 + y * 0.004) * sin(t * 0.21 - x * 0.005 + y * 0.009 + 1.3)
end

local function buildStained()
  local G, SIDE, TOP, BOTTOM, FILTER = 300, 12, 30, 24, 0.72
  local W, H = G + 2 * SIDE, G + TOP + BOTTOM
  local f = newWindow("Stained Glass", "drag the sun behind it", W, H, 0, 10)
  f.title:SetTextColor(1, 0.84, 0.45)
  f.note:SetTextColor(0.85, 0.8, 0.7)
  local stone = { { 0, BOTTOM + G, W, TOP, true }, { 0, 0, W, BOTTOM, true }, { 0, BOTTOM, SIDE, G }, { W - SIDE, BOTTOM, SIDE, G } }
  slab(f, stone, H, 0.07, 0.2, { 1.05, 1, 0.9 })

  local glass = CreateFrame("Frame", nil, f)
  glass:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", SIDE, BOTTOM)
  glass:SetSize(G, G)

  -- The mesh: a hub, three rings, and the corners out to the square.
  local verts, ringOf = {}, {}
  local C, R = G / 2, G / 2 - 8
  local function vert(x, y, ring)
    verts[#verts + 1] = { x, y }
    ringOf[#verts] = ring
    return #verts
  end
  local function ring(n, radius, phase, tag)
    local ids = {}
    for k = 0, n - 1 do
      local a = phase + k * 2 * pi / n
      ids[k] = vert(C + radius * cos(a), C + radius * sin(a), tag)
    end
    return ids
  end
  local function at(ids, k, n) return ids[k % n] end
  local hub = vert(C, C, 0)
  local p1 = ring(8, R * 0.2, 0, 1)
  local p2 = ring(16, R * 0.45, 0, 2)
  local p3 = ring(16, R * 0.7, pi / 16, 3)
  local p4 = ring(16, R, 0, 4)
  local rim = {}
  for k = 0, 15 do
    local a = k * pi / 8
    local dx, dy = cos(a), sin(a)
    local reach = C / max(abs(dx), abs(dy))
    rim[k] = vert(C + dx * reach, C + dy * reach, 5)
  end
  local pieces = {}
  local function piece(a, b, c, colour) pieces[#pieces + 1] = { a, b, c, colour = colour } end
  for k = 0, 7 do
    piece(hub, at(p1, k, 8), at(p1, k + 1, 8), k % 2 == 0 and "gold" or "amber")
    piece(at(p1, k, 8), at(p2, 2 * k, 16), at(p2, 2 * k + 1, 16), "ruby")
    piece(at(p1, k, 8), at(p2, 2 * k + 1, 16), at(p1, k + 1, 8), "azure")
    piece(at(p1, k + 1, 8), at(p2, 2 * k + 1, 16), at(p2, 2 * k + 2, 16), "ruby")
  end
  for j = 0, 15 do
    piece(at(p2, j, 16), at(p2, j + 1, 16), at(p3, j, 16), "emerald")
    piece(at(p3, j - 1, 16), at(p3, j, 16), at(p2, j, 16), "opal")
    piece(at(p4, j, 16), at(p4, j + 1, 16), at(p3, j, 16), j % 2 == 0 and "violet" or "ruby")
    piece(at(p3, j - 1, 16), at(p3, j, 16), at(p4, j, 16), "sapphire")
    piece(at(p4, j, 16), at(rim, j, 16), at(rim, j + 1, 16), "deep")
    piece(at(p4, j, 16), at(rim, j + 1, 16), at(p4, j + 1, 16), "sapphire")
  end

  for _, p in ipairs(pieces) do
    local hue = PALETTE[p.colour]
    local lift = 0.82 + 0.32 * random()
    local r = clamp(hue[1] * lift * (0.9 + 0.2 * random()), 0, 1)
    local g = clamp(hue[2] * lift * (0.9 + 0.2 * random()), 0, 1)
    local b = clamp(hue[3] * lift * (0.9 + 0.2 * random()), 0, 1)
    p.r, p.g, p.b = r, g, b
    local va, vb, vc = verts[p[1]], verts[p[2]], verts[p[3]]
    p.cx, p.cy = (va[1] + vb[1] + vc[1]) / 3, (va[2] + vb[2] + vc[2]) / 3
    tri(loose(glass, "BACKGROUND", 0, WHITE, "MOD", 1 - FILTER * (1 - r), 1 - FILTER * (1 - g), 1 - FILTER * (1 - b)),
      va, vb, vc)
    local body = loose(glass, "BORDER", 0, WHITE, "BLEND")
    tri(body, va, vb, vc)
    local lo, hi = 0.72 + 0.12 * random(), 1.1 + 0.15 * random()
    if random() < 0.5 then lo, hi = hi, lo end
    gradient(body, random() < 0.5 and "HORIZONTAL" or "VERTICAL",
      min(1, r * lo), min(1, g * lo), min(1, b * lo), 0.4, min(1, r * hi), min(1, g * hi), min(1, b * hi), 0.4)
    p.glow = loose(glass, "ARTWORK", 0, WHITE, "ADD", min(1, r * 1.3 + 0.04), min(1, g * 1.3 + 0.04),
      min(1, b * 1.3 + 0.04), 1)
    tri(p.glow, va, vb, vc)
    p.glow:SetAlpha(0)
  end
  -- Old glass is seedy: a coarse grain through it, and bubbles caught in it.
  local seedy = paint(glass, "ARTWORK", 2, NOISE, "BLEND", 0, 0, 0, 0.1, true)
  seedy:SetAllPoints()
  seedy:SetTexCoord(0, G / 64, 0, G / 64)
  local fleck = paint(glass, "ARTWORK", 3, NOISE, "ADD", 1, 1, 1, 0.05, true)
  fleck:SetAllPoints()
  fleck:SetTexCoord(0.5 + G / NOISE_SIZE, 0.5, 0.2, 0.2 + G / NOISE_SIZE)
  for _ = 1, 36 do
    centre(paint(glass, "ARTWORK", 4, DOT, "ADD", 1, 1, 1, 0.18 + 0.25 * random()), glass,
      10 + random() * (G - 20), 10 + random() * (G - 20), 1.5 + 2 * random())
  end

  -- The sun, seen through the glass when it is behind it.
  local clip = CreateFrame("Frame", nil, glass)
  clip:SetAllPoints()
  clip:SetClipsChildren(true)
  local behind = CreateFrame("Frame", nil, clip)
  behind:SetAllPoints()
  local sunHalo = paint(behind, "ARTWORK", 0, GLOW, "ADD", 1, 0.9, 0.7, 0.45)
  local sunCore = paint(behind, "ARTWORK", 1, GLOW, "ADD", 1, 0.97, 0.88, 0.9)

  -- The lead: a came along every edge between two pieces (the stone holds the outer ones), heavier round the rose, with
  -- a light line along each side of it that shows when that side faces the sun. Solder at every joint.
  local lead = CreateFrame("Frame", nil, glass)
  lead:SetAllPoints()
  lead:SetFrameLevel(behind:GetFrameLevel() + 1)
  local done, cames = {}, {}
  local function came(i, j)
    if ringOf[i] == 5 and ringOf[j] == 5 then return end
    local key = min(i, j) .. ":" .. max(i, j)
    if done[key] then return end
    done[key] = true
    local a, b = verts[i], verts[j]
    local dx, dy = b[1] - a[1], b[2] - a[2]
    local len = sqrt(dx * dx + dy * dy)
    local nx, ny = -dy / len, dx / len
    local heavy = ringOf[i] == 4 and ringOf[j] == 4
    local line = lead:CreateLine(nil, "ARTWORK", nil, 0)
    line:SetColorTexture(0.06, 0.055, 0.05, 1)
    line:SetThickness(heavy and 4 or 3)
    line:SetStartPoint("BOTTOMLEFT", lead, a[1], a[2])
    line:SetEndPoint("BOTTOMLEFT", lead, b[1], b[2])
    local e = { mx = (a[1] + b[1]) / 2, my = (a[2] + b[2]) / 2, sides = {} }
    local off = heavy and 1.4 or 1
    for _, sign in ipairs({ 1, -1 }) do
      local edge = lead:CreateLine(nil, "ARTWORK", nil, 1)
      edge:SetColorTexture(0.8, 0.76, 0.68, 1)
      edge:SetThickness(1)
      edge:SetStartPoint("BOTTOMLEFT", lead, a[1] + nx * off * sign, a[2] + ny * off * sign)
      edge:SetEndPoint("BOTTOMLEFT", lead, b[1] + nx * off * sign, b[2] + ny * off * sign)
      edge:SetAlpha(0)
      table.insert(e.sides, { line = edge, nx = nx * sign, ny = ny * sign })
    end
    cames[#cames + 1] = e
  end
  for _, p in ipairs(pieces) do
    came(p[1], p[2])
    came(p[2], p[3])
    came(p[3], p[1])
  end
  for i, v in ipairs(verts) do
    if ringOf[i] ~= 5 then
      centre(paint(lead, "OVERLAY", 0, DOT, "BLEND", 0.07, 0.065, 0.06, 1), lead, v[1], v[2], ringOf[i] == 4 and 7 or 5.5)
    end
  end

  -- The stone: a recess the glass sits in, its outer edge catching the light.
  local inset = paint(f.over, "ARTWORK", 0, WHITE, "BLEND")
  place(inset, f.over, SIDE, BOTTOM + G - 8, G, 8)
  gradient(inset, "VERTICAL", 0, 0, 0, 0, 0, 0, 0, 0.5)
  local side = paint(f.over, "ARTWORK", 0, WHITE, "BLEND")
  place(side, f.over, SIDE, BOTTOM, 8, G)
  gradient(side, "HORIZONTAL", 0, 0, 0, 0.4, 0, 0, 0, 0)
  outline(f.over, "ARTWORK", 1, 0, 0, W, H, 1, 0, 0, 0, 0.6)
  local stoneRim = newRim(f.over, 0, 0, W, H, 12, 1, 0.55)

  local shadowRects = {}
  for _, r in ipairs(stone) do
    table.insert(shadowRects, { r[1], r[2], r[3], r[4] })
  end
  table.insert(shadowRects, { SIDE, BOTTOM, G, G, 0.3 })
  local shadow = newShadow(f, shadowRects, 0.4, 16)

  -- The light it casts, on a frame under the window, a little spread.
  local cast = CreateFrame("Frame", nil, f)
  cast:SetFrameStrata("LOW")
  cast:SetFrameLevel(shadow.frame:GetFrameLevel() + 1)
  cast:SetSize(G, G)
  local TAPS, SPREAD = { { 1.8, 0 }, { -0.9, 1.6 }, { -0.9, -1.6 } }, 1.1
  for _, p in ipairs(pieces) do
    local pts = {}
    for k = 1, 3 do
      local v = verts[p[k]]
      local dx, dy = p.cx - v[1], p.cy - v[2]
      local d = sqrt(dx * dx + dy * dy)
      local x, y = v[1] + dx / d * 1.8, v[2] + dy / d * 1.8
      pts[k] = { C + (x - C) * SPREAD, C + (y - C) * SPREAD }
    end
    for _, tap in ipairs(TAPS) do
      tri(loose(cast, "ARTWORK", 0, WHITE, "ADD", min(1, p.r * 1.2 + 0.03), min(1, p.g * 1.2 + 0.03),
        min(1, p.b * 1.2 + 0.03), 0.16),
        { pts[1][1] + tap[1], pts[1][2] + tap[2] }, { pts[2][1] + tap[1], pts[2][2] + tap[2] },
        { pts[3][1] + tap[1], pts[3][2] + tap[2] })
    end
  end

  function f:Tick(_, relight)
    local ox, oy = glass:GetLeft(), glass:GetBottom()
    if not ox then return end
    if ox ~= self.ox or oy ~= self.oy then
      relight = true
      self.ox, self.oy = ox, oy
    end
    local now = light.t
    for _, p in ipairs(pieces) do
      local x, y = ox + p.cx, oy + p.cy
      local s = sunAt(x, y)
      p.glow:SetAlpha(clamp(0.08 + 0.95 * s * s * cloud(x, y, now) + 0.75 * lampAt(x, y), 0, 1))
    end
    local wx, wy = ox + G / 2, oy + G / 2
    cast:SetAlpha(clamp((0.3 + 0.7 * sunAt(wx, wy) ^ 1.5) * cloud(wx, wy, now), 0, 1))
    if not relight then return end
    centre(sunCore, behind, light.sx - ox, light.sy - oy, 90)
    centre(sunHalo, behind, light.sx - ox, light.sy - oy, 320)
    for _, e in ipairs(cames) do
      local x, y = ox + e.mx, oy + e.my
      local dx, dy = light.sx - x, light.sy - y
      local d = max(1, sqrt(dx * dx + dy * dy))
      local s = sunAt(x, y)
      for _, sideOf in ipairs(e.sides) do
        local face = max(0, (sideOf.nx * dx + sideOf.ny * dy) / d)
        sideOf.line:SetAlpha(0.6 * face * (0.3 + 0.7 * s))
      end
    end
    local dx, dy, d = away(wx, wy)
    local reach = clamp(30 + d * 0.16, 30, 130)
    cast:ClearAllPoints()
    cast:SetPoint("CENTER", glass, "CENTER", dx * reach, dy * reach)
    shadeRim(stoneRim, self.ox - SIDE, self.oy - BOTTOM)
    castShadow(shadow)
  end
  return f
end

---------------------------------------------------------------------------------------------------------------------
-- Window: plain glass, which is the hard one, as it is nearly invisible. What shows it is what it reflects and what is on
-- it. Bands of reflected light that stay (nearly) put on the screen as the window moves, the way a reflection of the
-- room holds still while a pane slides across it; a sky at its top and the ground at its foot; the green of its
-- thickness at the edges of each pane; its edges glinting where the light falls on them; smudges that only show when
-- lit; and rain: drops with a highlight on the side toward the light and the light they focus on the other, a few
-- running down in fits, leaving a trail of beads that dry.

local function buildClear()
  local W, H, SASH, TOP, BOTTOM, BAR = 270, 350, 9, 28, 24, 6
  local f = newWindow("Window", "move it: the reflections hold still", W, H, 370, -10)
  local gx, gy, gw, gh = SASH, BOTTOM, W - 2 * SASH, H - TOP - BOTTOM
  local pw, ph = (gw - BAR) / 2, (gh - BAR) / 2
  local glass = CreateFrame("Frame", nil, f)
  glass:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", gx, gy)
  glass:SetSize(gw, gh)

  paint(glass, "BACKGROUND", 0, WHITE, "MOD", 0.93, 0.975, 0.965):SetAllPoints()
  local sky = paint(glass, "BACKGROUND", 1, WHITE, "BLEND")
  sky:SetAllPoints()
  gradient(sky, "VERTICAL", 0.08, 0.1, 0.12, 0.08, 0.8, 0.88, 1, 0.1)
  local panes = { { 0, 0, pw, ph }, { pw + BAR, 0, pw, ph }, { 0, ph + BAR, pw, ph }, { pw + BAR, ph + BAR, pw, ph } }
  for _, p in ipairs(panes) do
    place(paint(glass, "BACKGROUND", 2, VIGNETTE, "BLEND", 0.3, 0.55, 0.5, 0.22), glass, p[1], p[2], p[3], p[4])
  end
  local smudges = {}
  for i = 1, 7 do
    local t = loose(glass, "BORDER", 0, GLOW, "ADD", 1, 1, 1, 1)
    local x, y = 20 + random() * (gw - 40), 20 + random() * (gh - 40)
    oblong(t, x, y, random() * pi, 30 + 50 * random(), 10 + 14 * random())
    smudges[i] = { t = t, x = x, y = y }
  end

  local clip = CreateFrame("Frame", nil, glass)
  clip:SetAllPoints()
  clip:SetClipsChildren(true)
  local shine = CreateFrame("Frame", nil, clip)
  shine:SetAllPoints()
  -- Bands of reflection: a broad one, a narrow one beside it and a hairline, again every PERIOD across the screen.
  local ANGLE, PERIOD, PARALLAX = math.rad(62), 330, 0.8
  local STRIPES = { { 0, 64, 0.075 }, { 36, 14, 0.13 }, { 50, 3, 0.2 } }
  local groups = {}
  for k = 1, 3 do
    groups[k] = {}
    for _, stripe in ipairs(STRIPES) do
      local lo, hi = loose(shine, "ARTWORK", 0, WHITE, "ADD"), loose(shine, "ARTWORK", 0, WHITE, "ADD")
      gradient(lo, "VERTICAL", 0.92, 0.96, 1, 0, 0.92, 0.96, 1, stripe[3])
      gradient(hi, "VERTICAL", 0.92, 0.96, 1, stripe[3], 0.92, 0.96, 1, 0)
      table.insert(groups[k], { lo = lo, hi = hi, stripe = stripe })
    end
  end
  -- The lights reflected in it.
  local lampGlow = paint(shine, "ARTWORK", 1, GLOW, "ADD", 0.9, 0.95, 1, 0.2)
  local lampGlint = paint(shine, "ARTWORK", 2, GLINT, "ADD", 1, 1, 1, 0.4)
  local sunGlow = paint(shine, "ARTWORK", 1, GLOW, "ADD", 1, 0.93, 0.8, 0.4)
  local sunGlint = paint(shine, "ARTWORK", 2, GLINT, "ADD", 1, 0.97, 0.9, 0.8)

  -- Rain.
  local wet = CreateFrame("Frame", nil, clip)
  wet:SetAllPoints()
  wet:SetFrameLevel(shine:GetFrameLevel() + 1)
  local function newDrop()
    local d = {
      dark = paint(wet, "ARTWORK", 0, DOT, "BLEND", 0.08, 0.1, 0.12, 1),
      lens = paint(wet, "ARTWORK", 1, DOT, "ADD", 0.75, 0.85, 1, 1),
      spec = paint(wet, "ARTWORK", 2, GLOW, "ADD", 1, 1, 1, 1),
      caustic = paint(wet, "ARTWORK", 2, GLOW, "ADD", 0.85, 0.95, 1, 1),
      x = 0, y = 0, r = 2, fade = 1, life = 0,
    }
    d.dark:SetAlpha(0)
    d.lens:SetAlpha(0)
    d.spec:SetAlpha(0)
    d.caustic:SetAlpha(0)
    return d
  end
  local function drawDrop(d, ox, oy)
    local sx, sy = ox + d.x, oy + d.y
    local s, l = sunAt(sx, sy), lampAt(sx, sy)
    local lx = (light.sx - sx) * s + (light.cx - sx) * l * 1.5
    local ly = (light.sy - sy) * s + (light.cy - sy) * l * 1.5
    local len = sqrt(lx * lx + ly * ly)
    if len < 0.001 then
      lx, ly = -0.6, 0.8
    else
      lx, ly = lx / len, ly / len
    end
    local r, a = d.r, d.fade
    centre(d.dark, wet, d.x, d.y - r * 0.1, r * 2.1)
    d.dark:SetAlpha(0.28 * a)
    centre(d.lens, wet, d.x - lx * r * 0.2, d.y - ly * r * 0.2, r * 1.3)
    d.lens:SetAlpha(0.1 * a)
    centre(d.spec, wet, d.x + lx * r * 0.42, d.y + ly * r * 0.42, r * 1.1)
    d.spec:SetAlpha(min(1, 0.35 + 0.9 * max(s, l)) * a)
    centre(d.caustic, wet, d.x - lx * r * 0.45, d.y - ly * r * 0.45, r * 1.3)
    d.caustic:SetAlpha((0.15 + 0.4 * max(s, l)) * a)
  end
  local still = {}
  for i = 1, 30 do
    local d = newDrop()
    d.x, d.y, d.r = 4 + random() * (gw - 8), 4 + random() * (gh - 8), 1.4 + 3.2 * random() ^ 2
    still[i] = d
  end
  local beads, nextBead = {}, 1
  for i = 1, 40 do
    beads[i] = newDrop()
  end
  -- A runner swells where it is, then runs in fits, a stretch of sliding then a catch, leaving beads behind it.
  local function launch(d)
    d.x, d.y = 10 + random() * (gw - 20), gh * (0.55 + 0.4 * random())
    d.size = 3.4 + 1.6 * random()
    d.r, d.fade, d.vy, d.run = d.size * 0.6, 0, 0, 0
    d.wait = 1 + 3 * random()
    d.lastBead = d.y
  end
  local runners = {}
  for i = 1, 3 do
    runners[i] = newDrop()
    launch(runners[i])
  end
  local function runDrop(d, dt)
    if d.wait > 0 then
      d.wait = d.wait - dt
      d.fade = min(1, d.fade + dt * 1.5)
      d.r = min(d.size, d.r + dt * d.size * 0.3)
      return
    end
    d.run = d.run - dt
    if d.run <= 0 then
      if d.vy > 0 then
        d.vy, d.run = 0, 0.15 + 0.7 * random()
      else
        d.vy, d.run = 25 + 45 * random(), 0.3 + 0.9 * random()
      end
    end
    if d.vy > 0 then
      d.y = d.y - d.vy * dt
      d.x = d.x + (random() - 0.5) * 0.15 * d.vy * dt
      if d.lastBead - d.y > 6 then
        local b = beads[nextBead]
        nextBead = nextBead % #beads + 1
        b.x, b.y, b.r = d.x + (random() - 0.5) * 1.2, d.y + d.r * 0.8, 0.8 + 0.9 * random()
        b.life, b.fade = 7 + 4 * random(), 1
        d.lastBead = d.y
      end
    end
    if d.y < -8 then launch(d) end
  end

  -- The sash: over the glass, so the rain runs behind its bars.
  local solid = {
    { 0, H - TOP, W, TOP, true }, { 0, 0, W, BOTTOM, true }, { 0, BOTTOM, SASH, gh }, { W - SASH, BOTTOM, SASH, gh },
    { gx + pw, gy, BAR, gh }, { gx, gy + ph, gw, BAR, true },
  }
  slab(f.over, solid, H, 0.1, 0.2, { 0.95, 1, 1.06 })
  local rims = { newRim(f.over, 0, 0, W, H, 12, 1, 0.5) }
  for _, p in ipairs(panes) do
    outline(f.over, "ARTWORK", 0, gx + p[1], gy + p[2], p[3], p[4], 1, 0, 0, 0, 0.4)
    table.insert(rims, newRim(f.over, gx + p[1] + 1, gy + p[2] + 1, p[3] - 2, p[4] - 2, 8, 1.5, 1))
  end
  local shadowRects = {}
  for _, r in ipairs(solid) do
    table.insert(shadowRects, { r[1], r[2], r[3], r[4] })
  end
  table.insert(shadowRects, { gx, gy, gw, gh, 0.07 })
  local shadow = newShadow(f, shadowRects, 0.42, 16)

  function f:Tick(dt, relight)
    local ox, oy = glass:GetLeft(), glass:GetBottom()
    if not ox then return end
    if ox ~= self.ox or oy ~= self.oy then
      relight = true
      self.ox, self.oy = ox, oy
    end
    for _, d in ipairs(runners) do
      runDrop(d, dt)
      drawDrop(d, ox, oy)
    end
    for _, b in ipairs(beads) do
      if b.life > 0 then
        b.life = b.life - dt
        b.fade = clamp(b.life / 3, 0, 1)
        drawDrop(b, ox, oy)
      end
    end
    if not relight then return end
    for _, d in ipairs(still) do
      drawDrop(d, ox, oy)
    end
    -- The bands: where they lie across the glass now, most of the window's move taken back out of them.
    local ux, uy = cos(ANGLE), sin(ANGLE)
    local nx, ny = -uy, ux
    local low = min(0, gw * nx, gh * ny, gw * nx + gh * ny)
    local base = -PARALLAX * (ox * nx + oy * ny)
    local first = ceil((low - 80 - base) / PERIOD)
    local along = (gw / 2) * ux + (gh / 2) * uy
    local bright = 0.45 + 0.55 * sunAt(ox + gw / 2, oy + gh / 2)
    for k = 1, 3 do
      local at = base + (first + k - 1) * PERIOD
      for _, part in ipairs(groups[k]) do
        local s = at + part.stripe[1]
        band(part.lo, part.hi, nx * s + ux * along, ny * s + uy * along, ANGLE, 2 * (gw + gh), part.stripe[2])
        part.lo:SetAlpha(bright)
        part.hi:SetAlpha(bright)
      end
    end
    for _, s in ipairs(smudges) do
      local x, y = ox + s.x, oy + s.y
      s.t:SetAlpha(0.012 + 0.2 * sunAt(x, y) ^ 3 + 0.3 * lampAt(x, y))
    end
    centre(lampGlow, shine, light.cx - ox, light.cy - oy, 90)
    centre(lampGlint, shine, light.cx - ox, light.cy - oy, 40)
    centre(sunGlow, shine, light.sx - ox, light.sy - oy, 180)
    centre(sunGlint, shine, light.sx - ox, light.sy - oy, 120)
    for _, rim in ipairs(rims) do
      shadeRim(rim, ox - gx, oy - gy)
    end
    castShadow(shadow)
  end
  return f
end

---------------------------------------------------------------------------------------------------------------------
-- The sun: drag it anywhere. It sits under the windows, so behind the stained glass it shines through it.

local function buildSun()
  local s = CreateFrame("Frame", nil, UIParent)
  s:SetSize(40, 40)
  s:SetPoint("CENTER", UIParent, "CENTER", -150, 290)
  s:SetFrameStrata("BACKGROUND")
  s:SetMovable(true)
  s:SetClampedToScreen(true)
  s:EnableMouse(true)
  s:RegisterForDrag("LeftButton")
  s:SetScript("OnDragStart", s.StartMoving)
  s:SetScript("OnDragStop", s.StopMovingOrSizing)
  centre(paint(s, "BACKGROUND", 0, GLOW, "ADD", 1, 0.82, 0.55, 0.3), s, 20, 20, 260)
  centre(paint(s, "ARTWORK", 0, GLOW, "ADD", 1, 0.95, 0.82, 1), s, 20, 20, 64)
  s.rays = paint(s, "ARTWORK", 1, GLINT, "ADD", 1, 0.95, 0.85, 0.85)
  centre(s.rays, s, 20, 20, 140)
  s.rays2 = paint(s, "ARTWORK", 2, GLINT, "ADD", 1, 0.9, 0.75, 0.45)
  centre(s.rays2, s, 20, 20, 90)
  local label = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("TOP", s, "BOTTOM", 0, -14)
  label:SetText("drag the sun")
  label:SetAlpha(0.7)
  return s
end

---------------------------------------------------------------------------------------------------------------------

local sun
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(_, dt)
  light.t = light.t + dt
  local scale = UIParent:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  cx, cy = cx / scale, cy / scale
  local sx, sy = sun:GetCenter()
  local changed = light.dirty or cx ~= light.cx or cy ~= light.cy or sx ~= light.sx or sy ~= light.sy
  light.cx, light.cy, light.sx, light.sy, light.dirty = cx, cy, sx, sy, false
  sun.rays:SetRotation(light.t * 0.08)
  sun.rays2:SetRotation(pi / 4 - light.t * 0.05)
  for _, w in ipairs(windows) do
    if w:IsShown() then
      w:Tick(dt, changed)
    end
  end
end)

local function toggle()
  local show = not driver:IsShown()
  for _, w in ipairs(windows) do
    w:SetShown(show)
  end
  sun:SetShown(show)
  driver:SetShown(show)
  light.dirty = true
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  sun = buildSun()
  buildFrosted()
  buildStained()
  buildClear()
  light.dirty = true
  driver:Show()
end)

SLASH_BETTERBAGSGLASS1 = "/glass"
SlashCmdList["BETTERBAGSGLASS"] = function()
  if sun then toggle() end
end
