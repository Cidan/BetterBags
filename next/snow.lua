local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

-- NextSnow draws a Next theme's snow on a panel (Panel.Snow, next-themes.md §22; the Frost theme; asked: "themes are
-- ice, cool breeze"): flakes drifting down across the body behind its content (Where Body) and down the feather beside
-- its inner side (Where Feather, a full panel's only), each wobbling and turning as it falls, carried toward the panel's
-- inner side, out into the world, by a breeze. Now and then the breeze gusts (Gusts): for a while the flakes are blown
-- along much faster, and streaks of wind sweep across the panel ahead of it. Now and then a shooting star flies a short
-- way across the body (Flybys): a twinkling head and its tail, toward the inner side, falling a little along its tilt.
-- Each entry is a steady number of flakes: one that falls past the bottom starts again above the top, one blown past the
-- downwind side starts again upwind; in combat none starts again and no star sets off, so the snow thins out and stops,
-- as sparkles do, and comes back after. The flakes, streaks and stars are the panel frame's own textures, under every
-- child frame (tabs, content). It falls only while the panel shows (its driver is a child of the panel's frame).
---@class NextSnow: AceModule
local snow = addon:NewModule('NextSnow')

-- Where the snow takes its randomness (a source of numbers in [0, 1)): replaced by the specs.
snow.Random = math.random

-- The keys of Panel.Snow, of an entry of its Flakes, of its Gusts and their Streaks, of its Flybys and their Head, and
-- the places a flake falls, for SonataNext:Check.
snow.KEYS = { Flakes = true, Gusts = true, Flybys = true }
snow.FLAKE_KEYS = { Where = true, Texture = true, Count = true, Size = true, Fall = true, Drift = true, Wobble = true,
  Spin = true, Alpha = true, Colors = true, BlendMode = true, Layer = true, SubLevel = true }
snow.GUST_KEYS = { Every = true, Time = true, Strength = true, OnOpen = true, Streaks = true }
snow.STREAK_KEYS = { Texture = true, Count = true, Length = true, Thickness = true, Alpha = true, Color = true,
  BlendMode = true, Tilt = true, Layer = true, SubLevel = true }
snow.FLYBY_KEYS = { Every = true, Max = true, Travel = true, Speed = true, Length = true, Thickness = true, Tilt = true,
  Texture = true, Color = true, Alpha = true, BlendMode = true, Layer = true, SubLevel = true, Head = true }
snow.HEAD_KEYS = { Texture = true, Size = true, Color = true, Alpha = true, BlendMode = true, Twinkle = true }
snow.WHERE = { Body = true, Feather = true }

---@class (exact) NextSnowFlake
---@field entry table The theme's entry it falls for.
---@field texture Texture
---@field x number Its middle, from the panel's top left (before its wobble).
---@field y number Down from the panel's top.
---@field size number
---@field fall number Units a second down.
---@field amplitude number How far it wobbles either way.
---@field frequency number Wobbles a second.
---@field phase number
---@field spin number Radians a second.
---@field angle number
---@field alpha number
---@field dormant boolean Gone past an edge in combat, waiting to start again.
---@field turned boolean Turned since it took its texture (its rotation set at least once).
---@field away boolean Nowhere to fall: a feather flake on a small panel, hidden until the panel is full again.

---@class (exact) NextSnowStreak
---@field texture Texture
---@field x number Its middle, from the panel's top left.
---@field y number
---@field length number
---@field speed number Units a second downwind.

---@class (exact) NextSnowGust
---@field t number How long it has blown.

---@class (exact) NextSnowFlyby
---@field tail Texture
---@field head? Texture
---@field x number Its head's middle, from the panel's top left.
---@field y number Down from the panel's top.
---@field dx number Across, per unit flown (toward the inner side).
---@field dy number Down, per unit flown.
---@field speed number Units a second along its way.
---@field travel number How far it flies.
---@field flown number How far it has flown.
---@field length number Its tail's longest.
---@field thickness number
---@field phase number Where its head's twinkle starts.

---@class (exact) NextSnowSet
---@field panel table The panel: its frame, its side, IsSmall, BodyLeft, BodyWidth.
---@field driver Frame Runs the snow while it falls; a child of the panel's frame.
---@field onUpdate fun(frame: Frame, elapsed: number)
---@field flakes NextSnowFlake[]
---@field streaks NextSnowStreak[]
---@field flybys NextSnowFlyby[] The shooting stars flying.
---@field untilFlyby? number Seconds until the next sets off.
---@field pool Texture[] Textures no flake, streak or star holds.
---@field running boolean Falling (the panel shows).
---@field gust? NextSnowGust The gust blowing, if any.
---@field untilGust? number Seconds until the next gust.
---@field time number How long it has fallen (the wobbles' clock).
local setProto = {}
addon:GetModule('Perf'):RegisterPrototype(setProto, 'NextSnowSet')

-- Create gives a panel its snow, none until styled (Style). The panel's frame changing size (a small panel sized by a
-- grip, a size switch) lays it out again.
---@param panel table
---@return NextSnowSet
function snow:Create(panel)
  local set = setmetatable({ panel = panel, flakes = {}, streaks = {}, flybys = {}, pool = {}, running = false,
    time = 0 },
    { __index = setProto })
  set.driver = CreateFrame("Frame", nil, panel.frame)
  set.onUpdate = function(_, elapsed)
    set:Step(elapsed)
  end
  -- A plain hook: it runs on every frame of a resize, and addon.HookScript makes a Context per call.
  panel.frame:HookScript("OnSizeChanged", function()
    if #set.flakes > 0 then
      set:Layout()
    end
  end)
  return set
end

---@param range number[]
---@return number
local function between(range)
  return range[1] + (range[2] - range[1]) * snow.Random()
end

-- Spec returns the theme's Panel.Snow, nil without one.
---@return table?
function setProto:Spec()
  return style.Theme.Panel.Snow or nil
end

-- area returns where an entry's flakes fall, from the panel's top left: the left edge and the width. The feather is
-- beside the body's inner side (left of a panel that belongs to the right, right of one that belongs to the left), as
-- wide as the theme's feather; a small panel has none.
---@private
---@param entry table
---@return number? left, number width
function setProto:area(entry)
  local panel = self.panel
  if entry.Where == "Body" then
    return panel:BodyLeft(), panel:BodyWidth()
  end
  if panel:IsSmall() then
    return nil, 0
  end
  if panel.side == "LEFT" then
    return panel:BodyLeft() + panel:BodyWidth(), style.FEATHER
  end
  return panel:BodyLeft() - style.FEATHER, style.FEATHER
end

-- wind is the way the breeze blows across the panel: toward its inner side, out into the world (left on a panel that
-- belongs to the right of the screen, right on one that belongs to the left).
---@private
---@return number
function setProto:wind()
  return self.panel.side == "LEFT" and 1 or -1
end

---@private
---@param layer? string
---@param sublevel? number
---@return Texture
function setProto:texture(layer, sublevel)
  local t = table.remove(self.pool)
  if t == nil then
    t = self.panel.frame:CreateTexture(nil, layer or "BORDER", nil, sublevel or 3)
    t:SetSnapToPixelGrid(false)
    t:SetTexelSnappingBias(0)
  end
  t:SetDrawLayer(layer or "BORDER", sublevel or 3)
  return t
end

---@private
---@param t Texture
function setProto:release(t)
  t:Hide()
  t:ClearAllPoints()
  table.insert(self.pool, t)
end

-- Style takes the theme's snow: its flakes made again for its entries (Count each, their look), scattered over their
-- places (Layout). Falling while the panel showed, it falls on (Start).
function setProto:Style()
  local running = self.running
  self:Stop()
  for _, f in ipairs(self.flakes) do
    self:release(f.texture)
  end
  self.flakes = {}
  local S = self:Spec()
  for _, entry in ipairs(S and S.Flakes or {}) do
    if self:area(entry) ~= nil then
      for _ = 1, entry.Count or 0 do
        local f = { entry = entry, texture = self:texture(entry.Layer, entry.SubLevel), angle = 0, dormant = false,
          away = false }
        self:look(f)
        table.insert(self.flakes, f)
      end
    end
  end
  self:Layout(true)
  if running then
    self:Start()
  end
end

-- look gives a flake its own look and way of falling, at random within its entry's: size, colour, alpha, how fast it
-- falls, wobbles and turns.
---@private
---@param f NextSnowFlake
function setProto:look(f)
  local e = f.entry
  local t = f.texture
  f.size = between(e.Size or { 4, 4 })
  f.fall = between(e.Fall or { 0, 0 })
  local wobble = e.Wobble or { 0, 0 }
  f.amplitude = wobble[1] * (0.5 + 0.5 * snow.Random())
  f.frequency = (wobble[2] or 0) * (0.6 + 0.8 * snow.Random())
  f.phase = 2 * math.pi * snow.Random()
  f.spin = math.rad((2 * snow.Random() - 1) * (e.Spin or 0))
  f.alpha = between(e.Alpha or { 1, 1 })
  local colors = e.Colors or { "White" }
  local color = colors[math.min(#colors, math.floor(snow.Random() * #colors) + 1)]
  style:Paint(t, { Texture = e.Texture, Color = color, BlendMode = e.BlendMode or "ADD" })
  t:SetAlpha(f.alpha)
  t:SetSize(f.size, f.size)
  t:ClearAllPoints()
  t:SetRotation(0)
  f.angle = 0
  f.turned = false
  t:Show()
end

-- Layout keeps every flake inside its place for the panel's size and side: scattered anew with scatter (a new style),
-- else only those now outside it, so a resize (laid out on each of its frames) leaves the rest where they are. A flake
-- with nowhere to fall (a feather's, once a size switch made the panel small) hides until it has somewhere again.
---@param scatter? boolean
function setProto:Layout(scatter)
  local height = self.panel.frame:GetHeight()
  for _, f in ipairs(self.flakes) do
    local left, width = self:area(f.entry)
    if left == nil then
      f.away = true
      f.texture:Hide()
    else
      local back = f.away
      f.away = false
      if scatter or back or f.x == nil or f.x < left - f.size or f.x > left + width + f.size or f.y > height + f.size then
        f.x = left + width * snow.Random()
        f.y = height * snow.Random()
      end
      if back and not f.dormant then
        f.texture:Show()
      end
      self:draw(f)
    end
  end
end

-- draw places a flake where it is, wobbling, turned. Its one anchor is set again each frame (SetPoint replaces a point
-- already set), and a flake that does not spin is never turned again: a full backpack's snow moves every frame.
---@private
---@param f NextSnowFlake
function setProto:draw(f)
  local t = f.texture
  local wobble = f.amplitude * math.sin(f.phase + 2 * math.pi * f.frequency * self.time)
  t:SetPoint("CENTER", self.panel.frame, "TOPLEFT", f.x + wobble, -f.y)
  if f.spin ~= 0 or f.turned then
    t:SetRotation(f.angle)
    f.turned = f.spin ~= 0
  end
end

-- strength is the gust blowing now, in units a second added to the breeze: rising and falling over its Time.
---@private
---@return number
function setProto:strength()
  local G = self:Spec() and self:Spec().Gusts
  if self.gust == nil or not G then
    return 0
  end
  local p = math.min(1, self.gust.t / G.Time)
  return G.Strength * math.sin(math.pi * p) ^ 2
end

-- Gust blows now: its streaks sweep in from the upwind side across the panel and its feather, each at its own height,
-- some further upwind than others, all across within the gust's Time, tilted down along the wind, their head (the art's
-- right end) first.
function setProto:Gust()
  local G = self:Spec() and self:Spec().Gusts
  if not G then
    return
  end
  self:endGust()
  self.gust = { t = 0 }
  local frame = self.panel.frame
  local width, height = frame:GetWidth(), frame:GetHeight()
  local S = G.Streaks
  local dir = self:wind()
  for _ = 1, S and S.Count or 0 do
    local length = between(S.Length or { 100, 100 })
    local t = self:texture(S.Layer, S.SubLevel)
    style:Paint(t, { Texture = S.Texture, Color = S.Color or "White", BlendMode = S.BlendMode or "ADD" })
    if dir < 0 then
      t:SetTexCoord(1, 0, 0, 1)
    end
    t:SetSize(length, between(S.Thickness or { 2, 2 }))
    t:SetRotation(-dir * math.rad(S.Tilt or 0))
    local lead = width * 0.6 * snow.Random()
    local start = dir < 0 and width + length / 2 + lead or -length / 2 - lead
    local s = { texture = t, x = start, y = height * (0.05 + 0.9 * snow.Random()), length = length,
      speed = (width * 1.6 + length) / G.Time }
    t:SetAlpha(0)
    t:Show()
    table.insert(self.streaks, s)
    self:drawStreak(s)
  end
  self:drive()
end

---@private
---@param s NextSnowStreak
function setProto:drawStreak(s)
  local t = s.texture
  t:ClearAllPoints()
  t:SetPoint("CENTER", self.panel.frame, "TOPLEFT", s.x, -s.y)
end

-- endGust ends the gust blowing, its streaks given back.
---@private
function setProto:endGust()
  self.gust = nil
  for _, s in ipairs(self.streaks) do
    self:release(s.texture)
  end
  self.streaks = {}
end

-- untilNext is how long until the next gust: Every on average, from 0.4 to 1.6 of it.
---@private
---@return number?
function setProto:untilNext()
  local G = self:Spec() and self:Spec().Gusts
  if not G then
    return nil
  end
  return G.Every * (0.4 + 1.2 * snow.Random())
end

-- Flyby sends a shooting star off (asked, of streaks blown across the whole body: "more golden, and A LOT less of them,
-- more like... slower, shooting star, then don't even go the full length of the bag, more like... flyby twinkles"):
-- from somewhere in the body, far enough from its inner edge to fly its Travel inside it, toward the inner side, falling
-- along its Tilt; its tail (the art's right end its head, mirrored going left) grows behind its head as it sets off.
-- Nothing while Max are flying, or without a theme's flybys.
function setProto:Flyby()
  local S = self:Spec()
  local F = S and S.Flybys
  if not F or #self.flybys >= (F.Max or 1) then
    return
  end
  local panel = self.panel
  local left, width = panel:BodyLeft(), panel:BodyWidth()
  local height = panel.frame:GetHeight()
  local dir = self:wind()
  local tilt = math.rad(F.Tilt or 0)
  local travel = between(F.Travel)
  local across, down = travel * math.cos(tilt), travel * math.sin(tilt)
  local margin = 8
  local room = math.max(0, width - across - 2 * margin)
  local x = dir < 0 and left + width - margin - room * snow.Random() or left + margin + room * snow.Random()
  local top, bottom = 0.08 * height, math.max(0.08 * height, 0.85 * height - down)
  local y = top + (bottom - top) * snow.Random()
  local tail = self:texture(F.Layer, F.SubLevel)
  style:Paint(tail, { Texture = F.Texture, Color = F.Color or "White", BlendMode = F.BlendMode or "ADD" })
  if dir < 0 then
    tail:SetTexCoord(1, 0, 0, 1)
  else
    tail:SetTexCoord(0, 1, 0, 1)
  end
  tail:SetRotation(-dir * tilt)
  local f = { tail = tail, x = x, y = y, dx = dir * math.cos(tilt), dy = math.sin(tilt), speed = between(F.Speed),
    travel = travel, flown = 0, length = between(F.Length or { 40, 40 }),
    thickness = between(F.Thickness or { 2, 2 }), phase = 2 * math.pi * snow.Random() }
  local H = F.Head
  if H then
    local head = self:texture(F.Layer, F.SubLevel)
    style:Paint(head, { Texture = H.Texture, Color = H.Color or "White", BlendMode = H.BlendMode or "ADD" })
    local size = between(H.Size or { 8, 8 })
    head:SetSize(size, size)
    f.head = head
    head:Show()
  end
  tail:Show()
  table.insert(self.flybys, f)
  self:drawFlyby(f)
end

-- drawFlyby places a shooting star where its head has got to: its tail as long as it has flown, up to its Length,
-- behind its head; both faded in as it sets off and out over the second half of its way, its head twinkling.
---@private
---@param f NextSnowFlyby
function setProto:drawFlyby(f)
  local F = self:Spec().Flybys
  local p = f.flown / f.travel
  local strength = math.min(1, p / 0.15) * math.min(1, (1 - p) / 0.45)
  local length = math.max(1, math.min(f.length, f.flown))
  local frame = self.panel.frame
  f.tail:SetSize(length, f.thickness)
  f.tail:SetPoint("CENTER", frame, "TOPLEFT", f.x - f.dx * length / 2, -(f.y - f.dy * length / 2))
  f.tail:SetAlpha((F.Alpha or 1) * strength)
  if f.head then
    local H = F.Head
    local twinkle = 0.65 + 0.35 * math.sin(f.phase + 2 * math.pi * (H.Twinkle or 0) * f.flown / f.speed)
    f.head:SetPoint("CENTER", frame, "TOPLEFT", f.x, -f.y)
    f.head:SetAlpha((H.Alpha or 1) * strength * twinkle)
  end
end

-- endFlybys gives back every shooting star's textures.
---@private
function setProto:endFlybys()
  for _, f in ipairs(self.flybys) do
    self:release(f.tail)
    if f.head then
      self:release(f.head)
    end
  end
  self.flybys = {}
end

-- untilNextFlyby is how long until the next shooting star sets off: Every, between its soonest and latest.
---@private
---@return number?
function setProto:untilNextFlyby()
  local F = self:Spec() and self:Spec().Flybys
  if not F then
    return nil
  end
  return between(F.Every)
end

-- stepFlybys flies each shooting star on (one that has flown its way is given back), then sends the next off when it is
-- due (none in combat: it is due again Every later).
---@private
---@param elapsed number
---@param combat boolean
function setProto:stepFlybys(elapsed, combat)
  if not (self:Spec() and self:Spec().Flybys) then
    return
  end
  local flying = {}
  for _, f in ipairs(self.flybys) do
    f.flown = f.flown + f.speed * elapsed
    if f.flown >= f.travel then
      self:release(f.tail)
      if f.head then
        self:release(f.head)
      end
    else
      f.x = f.x + f.dx * f.speed * elapsed
      f.y = f.y + f.dy * f.speed * elapsed
      self:drawFlyby(f)
      table.insert(flying, f)
    end
  end
  self.flybys = flying
  if self.untilFlyby ~= nil then
    self.untilFlyby = self.untilFlyby - elapsed
    if self.untilFlyby <= 0 then
      if not combat then
        self:Flyby()
      end
      self.untilFlyby = self:untilNextFlyby()
    end
  end
end

-- Step lets every flake fall elapsed seconds (down, downwind with the breeze and the gust, wobbling and turning), starts
-- again those gone past an edge (not in combat), sweeps the streaks on and blows the next gust when it is due, and flies
-- the shooting stars on, sending the next off when it is due.
---@param elapsed number
function setProto:Step(elapsed)
  self.time = self.time + elapsed
  local G = self:Spec() and self:Spec().Gusts
  if self.gust ~= nil then
    self.gust.t = self.gust.t + elapsed
    if G == nil or self.gust.t >= G.Time then
      self:endGust()
      self.untilGust = self:untilNext()
    end
  elseif self.untilGust ~= nil then
    self.untilGust = self.untilGust - elapsed
    if self.untilGust <= 0 then
      self.untilGust = nil
      self:Gust()
    end
  end
  local combat = InCombatLockdown()
  local dir = self:wind()
  local gust = self:strength()
  local height = self.panel.frame:GetHeight()
  for _, f in ipairs(self.flakes) do
    local left, width = self:area(f.entry)
    -- A flake with nowhere to fall (hidden by Layout) waits until the panel lays its snow out again.
    if f.away or left == nil then
      f.away = true
    elseif f.dormant then
      if not combat then
        f.dormant = false
        f.x = left + width * snow.Random()
        f.y = -f.size
        f.texture:Show()
        self:draw(f)
      end
    else
      f.y = f.y + f.fall * elapsed
      f.x = f.x + dir * ((f.entry.Drift or 0) + gust) * elapsed
      f.angle = f.angle + f.spin * elapsed
      local gone = f.y > height + f.size or f.x < left - f.size or f.x > left + width + f.size
      if gone and combat then
        f.dormant = true
        f.texture:Hide()
      else
        if f.y > height + f.size then
          f.y = -f.size
          f.x = left + width * snow.Random()
        elseif f.x < left - f.size then
          f.x = left + width + f.size / 2
          f.y = height * snow.Random()
        elseif f.x > left + width + f.size then
          f.x = left - f.size / 2
          f.y = height * snow.Random()
        end
        self:draw(f)
      end
    end
  end
  if self.gust ~= nil then
    local p = math.min(1, self.gust.t / G.Time)
    local S = G.Streaks
    for _, s in ipairs(self.streaks) do
      s.x = s.x + dir * s.speed * elapsed
      s.y = s.y + s.speed * math.tan(math.rad(S.Tilt or 0)) * elapsed
      s.texture:SetAlpha((S.Alpha or 1) * math.sin(math.pi * p))
      self:drawStreak(s)
    end
  end
  self:stepFlybys(elapsed, combat)
end

-- drive runs the driver while it falls with something to move (or shooting stars to send), and stops it when there is
-- nothing.
---@private
function setProto:drive()
  if self.running and (#self.flakes > 0 or self.gust ~= nil or self.untilFlyby ~= nil) then
    self.driver:SetScript("OnUpdate", self.onUpdate)
  else
    self.driver:SetScript("OnUpdate", nil)
  end
end

-- Start lets the snow fall (the panel shows): the next gust due, one now when the theme's gusts blow on opening, and the
-- first shooting star due.
function setProto:Start()
  self.running = true
  local G = self:Spec() and self:Spec().Gusts
  self.untilGust = self:untilNext()
  self.untilFlyby = self:untilNextFlyby()
  if G and G.OnOpen then
    self:Gust()
  end
  self:drive()
end

-- Stop ends the snow (the panel hid): nothing moves, a gust blowing ends, the shooting stars are gone.
function setProto:Stop()
  self.running = false
  self:endGust()
  self:endFlybys()
  self.untilGust = nil
  self.untilFlyby = nil
  self.driver:SetScript("OnUpdate", nil)
end

-- MovingParts adds every flake, streak and shooting star to skip: they rest nowhere, so the pixel checks leave them out.
---@param skip table<table, boolean>
function setProto:MovingParts(skip)
  for _, f in ipairs(self.flakes) do
    skip[f.texture] = true
  end
  for _, s in ipairs(self.streaks) do
    skip[s.texture] = true
  end
  for _, f in ipairs(self.flybys) do
    skip[f.tail] = true
    if f.head then
      skip[f.head] = true
    end
  end
end
