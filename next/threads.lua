local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

-- NextThreads draws a Next theme's threads of light on a panel (Panel.Threads, next-themes.md §22; the Frost theme's
-- gold, after the gold light wrapping round the screenshot asked for: "the shades of blue and gold should be like the
-- screenshot"). Each thread is a smooth curve (Catmull-Rom) through the theme's points round the body, drawn as Segments
-- Lines on the panel's own frame (under every child frame: its content), in a soft line art. It sways slowly (each point
-- on its own phase), a glint runs along it now and then, it draws itself in from its start as the panel opens (DrawIn,
-- its tip bright) and unravels back as it closes (Unravel). A point is { x, y }: x a share of the body's width from its
-- inner side (beyond 0 or 1: out past it), y by its Anchor: TOP units down from the body's top, BOTTOM units up from its
-- bottom, BODY a share of its height. Mirrored on a panel whose inner side is on the right. It moves only while the
-- panel shows (its driver is a child of the panel's frame).
---@class NextThreads: AceModule
local threads = addon:NewModule('NextThreads')

-- Where the threads take their randomness (a source of numbers in [0, 1)): replaced by the specs.
threads.Random = math.random

-- The keys of a Panel.Threads entry, of its Sway and its Glint, and its anchors, for SonataNext:Check.
threads.KEYS = { Anchor = true, Points = true, Segments = true, Width = true, Texture = true, Color = true,
  Alpha = true, BlendMode = true, Layer = true, SubLevel = true, Sway = true, Glint = true, Draw = true, Sizes = true }
threads.SWAY_KEYS = { Amplitude = true, Period = true }
threads.GLINT_KEYS = { Every = true, Time = true, Length = true, Color = true, Strength = true }
threads.ANCHORS = { TOP = true, BOTTOM = true, BODY = true }

-- How often a swaying thread is laid out again, at most: its points move a few units over seconds, so 20 times a second
-- shows no steps and costs a third of every frame.
local SWAY_STEP = 0.05

-- How wide the bright tip of a thread drawing itself in is, as a share of its length.
local TIP = 0.05

---@class (exact) NextThread
---@field entry table The theme's entry.
---@field lines Line[]
---@field phases number[] Each point's sway phases (two each).
---@field samples number[][] Where its curve runs now: Segments + 1 points { x, y }, from the body's top left, y down.
---@field lengths number[] How far along it each sample is, 0 to 1.
---@field glint? {t: number} The glint running along it, if any.
---@field untilGlint? number Seconds until its next glint.

---@class (exact) NextThreadSet
---@field panel table The panel: its frame, its body, its side, IsSmall.
---@field driver Frame
---@field onUpdate fun(frame: Frame, elapsed: number)
---@field threads NextThread[]
---@field pool Line[]
---@field running boolean
---@field time number The sway's clock.
---@field sinceLayout number Seconds since the threads were last laid out (the sway's).
---@field reveal number How much of each thread shows, 0 to 1.
---@field reveal0 number Where a draw-in or unravel starts.
---@field revealTo number Where it ends.
---@field revealTime? number Its length, while one runs.
---@field revealAt number How far into it, less its delay.
local setProto = {}
addon:GetModule('Perf'):RegisterPrototype(setProto, 'NextThreadSet')

-- Create gives a panel its threads, none until styled (Style). The panel's frame changing size lays them out again.
---@param panel table
---@return NextThreadSet
function threads:Create(panel)
  local set = setmetatable({ panel = panel, threads = {}, pool = {}, running = false, time = 0, sinceLayout = 0,
    reveal = 1, reveal0 = 1, revealTo = 1, revealAt = 0 }, { __index = setProto })
  set.driver = CreateFrame("Frame", nil, panel.frame)
  set.onUpdate = function(_, elapsed)
    set:Step(elapsed)
  end
  panel.frame:HookScript("OnSizeChanged", function()
    if #set.threads > 0 then
      set:Layout()
    end
  end)
  return set
end

-- Style takes the theme's threads: each made again with its Segments lines in its look, laid out (Layout). Moving while
-- the panel showed, they move on (Start).
function setProto:Style()
  local running = self.running
  self:Stop()
  for _, t in ipairs(self.threads) do
    for _, line in ipairs(t.lines) do
      line:Hide()
      table.insert(self.pool, line)
    end
  end
  self.threads = {}
  for _, entry in ipairs(style.Theme.Panel.Threads or {}) do
    local t = { entry = entry, lines = {}, phases = {}, samples = {}, lengths = {} }
    for k = 1, #entry.Points do
      t.phases[k] = { 2 * math.pi * threads.Random(), 2 * math.pi * threads.Random() }
    end
    for _ = 1, entry.Segments or 16 do
      local line = table.remove(self.pool)
      if line == nil then
        line = self.panel.frame:CreateLine(nil, entry.Layer or "ARTWORK", nil, entry.SubLevel or 0)
        line:SetSnapToPixelGrid(false)
        line:SetTexelSnappingBias(0)
      end
      line:SetDrawLayer(entry.Layer or "ARTWORK", entry.SubLevel or 0)
      style:Paint(line, { Texture = entry.Texture, Color = entry.Color or "White", BlendMode = entry.BlendMode })
      line:SetThickness(entry.Width or 2)
      table.insert(t.lines, line)
    end
    table.insert(self.threads, t)
  end
  self:Layout()
  if running then
    self:Start()
  end
end

-- shows says whether a thread is drawn at the panel's size (Sizes: Full or Small; both when unset).
---@private
---@param t NextThread
---@return boolean
function setProto:shows(t)
  local sizes = t.entry.Sizes
  if sizes == nil then
    return true
  end
  return (sizes == "Small") == (self.panel:IsSmall() == true)
end

-- point returns where a thread's point is now, from the body's top left (y down): swayed, mirrored on a panel whose
-- inner side is on the right.
---@private
---@param t NextThread
---@param k integer
---@param width number
---@param height number
---@return number x, number y
function setProto:point(t, k, width, height)
  local e = t.entry
  local p = e.Points[k]
  local x = p[1] * width
  if self.panel.side == "LEFT" then
    x = width - x
  end
  local y
  if e.Anchor == "BOTTOM" then
    y = height - p[2]
  elseif e.Anchor == "BODY" then
    y = p[2] * height
  else
    y = p[2]
  end
  local S = e.Sway
  if S and S.Amplitude and (S.Period or 0) > 0 then
    local w = 2 * math.pi / S.Period
    x = x + S.Amplitude * math.sin(w * self.time + t.phases[k][1])
    y = y + S.Amplitude * math.cos(0.83 * w * self.time + t.phases[k][2])
  end
  return x, y
end

-- curve samples a thread's curve: a Catmull-Rom spline through its points (its ends doubled), Segments + 1 samples
-- spread evenly over its spans, and how far along it each is.
---@private
---@param t NextThread
function setProto:curve(t)
  local body = self.panel.body
  local width, height = body:GetWidth(), body:GetHeight()
  local pts = {}
  for k = 1, #t.entry.Points do
    local x, y = self:point(t, k, width, height)
    pts[k] = { x, y }
  end
  local n = #t.lines
  local spans = math.max(1, #pts - 1)
  for i = 0, n do
    local u = i / n * spans
    local k = math.min(spans, math.floor(u) + 1)
    local f = u - (k - 1)
    local p0, p1 = pts[math.max(1, k - 1)], pts[k]
    local p2, p3 = pts[math.min(#pts, k + 1)], pts[math.min(#pts, k + 2)]
    local f2, f3 = f * f, f * f * f
    local function at(c)
      return 0.5 * ((2 * p1[c]) + (-p0[c] + p2[c]) * f + (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * f2
        + (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * f3)
    end
    t.samples[i + 1] = { at(1), at(2) }
  end
  local total, lengths = 0, { 0 }
  for i = 2, n + 1 do
    local a, b = t.samples[i - 1], t.samples[i]
    total = total + math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
    lengths[i] = total
  end
  for i = 1, n + 1 do
    t.lengths[i] = total > 0 and lengths[i] / total or (i - 1) / n
  end
end

-- Layout lays every thread out for the body as it is now, swayed to the sway's clock, and draws it.
function setProto:Layout()
  for _, t in ipairs(self.threads) do
    self:curve(t)
    self:draw(t)
  end
end

-- draw puts a thread's lines along its curve as far as it shows (reveal; the segment it ends in cut there), each in its
-- colour: its own, brightened toward its glint's where the glint runs and at its tip while it draws itself in.
---@private
---@param t NextThread
function setProto:draw(t)
  local e = t.entry
  local body = self.panel.body
  local shown = self:shows(t)
  local r, g, b, a = style:RGBA(e.Color or "White", e.Alpha)
  local G = e.Glint
  local center, gr, gg, gb
  if t.glint ~= nil and G then
    local length = G.Length or 0.1
    center = -length + (1 + 2 * length) * math.min(1, t.glint.t / G.Time)
    gr, gg, gb = style:RGBA(G.Color or "White")
  end
  local drawing = self.revealTime ~= nil
  local reveal = self.reveal
  for i, line in ipairs(t.lines) do
    local s0, s1 = t.lengths[i], t.lengths[i + 1]
    if not shown or s0 >= reveal or reveal <= 0 then
      line:Hide()
    else
      local p0, p1 = t.samples[i], t.samples[i + 1]
      local x1, y1 = p1[1], p1[2]
      local reach = s1
      if s1 > reveal then
        local f = (reveal - s0) / (s1 - s0)
        x1, y1 = p0[1] + (p1[1] - p0[1]) * f, p0[2] + (p1[2] - p0[2]) * f
        reach = reveal
      end
      line:SetStartPoint("TOPLEFT", body, p0[1], -p0[2])
      line:SetEndPoint("TOPLEFT", body, x1, -y1)
      local light = 0
      if center ~= nil then
        light = (G.Strength or 1) * math.exp(-(((s0 + reach) / 2 - center) / (G.Length or 0.1)) ^ 2)
      end
      local tr, tg, tb = gr or 1, gg or 1, gb or 1
      if drawing and reveal < 1 then
        local tip = math.exp(-((reach - reveal) / TIP) ^ 2)
        if tip > light then
          light, tr, tg, tb = tip, 1, 1, 1
        end
      end
      line:SetVertexColor(r + (tr - r) * light, g + (tg - g) * light, b + (tb - b) * light)
      line:SetAlpha(a + (1 - a) * light)
      line:Show()
    end
  end
end

-- moves says whether anything moves on the driver: a thread that sways or glints, or a draw-in or unravel.
---@private
---@return boolean
function setProto:moves()
  if self.revealTime ~= nil then
    return true
  end
  for _, t in ipairs(self.threads) do
    if t.entry.Sway or t.entry.Glint then
      return true
    end
  end
  return false
end

---@private
function setProto:drive()
  if self.running and self:moves() then
    self.driver:SetScript("OnUpdate", self.onUpdate)
  else
    self.driver:SetScript("OnUpdate", nil)
  end
end

---@private
---@param G table
---@return number
local function untilNext(G)
  return G.Every * (0.4 + 1.2 * threads.Random())
end

-- Step moves the threads elapsed seconds on: a draw-in or unravel goes on (eased out), each thread's glint runs along
-- it and the next is due, and a swaying one is laid out again (at most every SWAY_STEP).
---@param elapsed number
function setProto:Step(elapsed)
  self.time = self.time + elapsed
  self.sinceLayout = self.sinceLayout + elapsed
  local redraw = false
  if self.revealTime ~= nil then
    self.revealAt = self.revealAt + elapsed
    local p = self.revealTime > 0 and math.max(0, math.min(1, self.revealAt / self.revealTime)) or 1
    local e = 1 - (1 - p) ^ 2
    self.reveal = self.reveal0 + (self.revealTo - self.reveal0) * e
    if p >= 1 then
      self.revealTime = nil
      self.reveal = self.revealTo
    end
    redraw = true
  end
  local sway = false
  for _, t in ipairs(self.threads) do
    local G = t.entry.Glint
    if G then
      if t.glint ~= nil then
        t.glint.t = t.glint.t + elapsed
        if t.glint.t >= G.Time then
          t.glint = nil
          t.untilGlint = untilNext(G)
        end
        redraw = true
      else
        t.untilGlint = (t.untilGlint or untilNext(G)) - elapsed
        if t.untilGlint <= 0 then
          t.untilGlint = nil
          t.glint = { t = 0 }
          redraw = true
        end
      end
    end
    sway = sway or t.entry.Sway ~= nil
  end
  if sway and self.sinceLayout >= SWAY_STEP then
    self.sinceLayout = 0
    self:Layout()
  elseif redraw then
    for _, t in ipairs(self.threads) do
      self:draw(t)
    end
  end
  if self.revealTime == nil and not self:moves() then
    self.driver:SetScript("OnUpdate", nil)
  end
end

-- runReveal runs a draw-in or an unravel: from where it is to `to` over time seconds, after delay.
---@private
---@param to number
---@param time number
---@param delay number
function setProto:runReveal(to, time, delay)
  self.reveal0 = self.reveal
  self.revealTo = to
  self.revealTime = time
  self.revealAt = -(delay or 0)
  for _, t in ipairs(self.threads) do
    self:draw(t)
  end
  self:drive()
end

-- DrawIn draws every thread in from nothing, from its start, after delay seconds, over its theme's Draw seconds (the
-- longest of the panel's threads; at once without).
---@param delay? number
function setProto:DrawIn(delay)
  local time = 0
  for _, t in ipairs(self.threads) do
    time = math.max(time, t.entry.Draw or 0)
  end
  self.reveal = 0
  self:runReveal(1, time, delay or 0)
end

-- Unravel draws every thread back to nothing over time seconds.
---@param time number
function setProto:Unravel(time)
  self:runReveal(0, time, 0)
end

-- Start moves the threads (the panel shows): whole, unless the panel's open has asked for a draw-in (DrawIn).
function setProto:Start()
  self.running = true
  if self.revealTime == nil then
    self.reveal = 1
  end
  self:Layout()
  self:drive()
end

-- Stop holds the threads still (the panel hid).
function setProto:Stop()
  self.running = false
  self.revealTime = nil
  self.driver:SetScript("OnUpdate", nil)
end

-- MovingParts adds every line to skip: curves rest on no pixel grid, so the pixel checks leave them out.
---@param skip table<table, boolean>
function setProto:MovingParts(skip)
  for _, t in ipairs(self.threads) do
    for _, line in ipairs(t.lines) do
      skip[line] = true
    end
  end
end
