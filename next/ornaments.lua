local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

-- NextOrnaments draws a Next theme's ornaments on a panel (Panel.Ornaments, next-themes.md §12): art anchored to
-- the body's corners and edges, the roots along a druid bag's edge, a gem on a filigree, a lantern hanging by the
-- title. Asked: borders in the spirit of the classic race themes, "smaller and less large, more tasteful, and
-- animated feeling". A theme draws its ornaments for a body whose inner side (the one away from its screen edge)
-- is on the left, and they are mirrored on a panel whose inner side is on the right. Pieces at rest are on whole
-- pixels (docs/next-pixel-perfect.md); moving ones loop on the client's animation groups, which cost no Lua while
-- they run, and only while the panel shows.
---@class NextOrnaments: AceModule
local ornaments = addon:NewModule('NextOrnaments')

-- A body's corners, for an inner side on the left.
local CORNERS = { TOPINNER = "TOPLEFT", TOPOUTER = "TOPRIGHT", BOTTOMINNER = "BOTTOMLEFT", BOTTOMOUTER = "BOTTOMRIGHT" }
-- A piece's points a motion turns about, for an inner side on the left.
local ORIGINS = {
  CENTER = "CENTER", TOP = "TOP", BOTTOM = "BOTTOM", INNER = "LEFT", OUTER = "RIGHT",
  TOPINNER = "TOPLEFT", TOPOUTER = "TOPRIGHT", BOTTOMINNER = "BOTTOMLEFT", BOTTOMOUTER = "BOTTOMRIGHT",
}
local MIRRORED = {
  TOPLEFT = "TOPRIGHT", TOPRIGHT = "TOPLEFT", BOTTOMLEFT = "BOTTOMRIGHT", BOTTOMRIGHT = "BOTTOMLEFT",
  LEFT = "RIGHT", RIGHT = "LEFT", TOP = "TOP", BOTTOM = "BOTTOM", CENTER = "CENTER",
}
-- The values a theme may give, for SonataNext:Check.
ornaments.POINTS = { INNER = true, OUTER = true, TOP = true, BOTTOM = true, TOPINNER = true, TOPOUTER = true,
  BOTTOMINNER = true, BOTTOMOUTER = true }
ornaments.ANCHORS = CORNERS
ornaments.ORIGINS = ORIGINS
ornaments.SIZES = { Full = true, Small = true }
ornaments.MOTIONS = { Sway = true, Spin = true, Pulse = true, Bob = true, Period = true, Delay = true, Origin = true }

---@class (exact) NextOrnamentPiece
---@field texture Texture
---@field spec table The theme's entry it draws.
---@field shown boolean Shown at the panel's size.
---@field groups? table<string, AnimationGroup> Its motions' groups, made the first time it moves.
---@field phase number Where its motions start (Motion.Delay).

---@class (exact) NextOrnamentSet
---@field panel table The panel: its frame, its body, its side, IsSmall.
---@field pieces NextOrnamentPiece[] Every piece made; the first count are the theme's.
---@field count number
---@field mirrored boolean Drawn for an inner side on the right.
---@field running boolean Moving (the panel shows).
local setProto = {}
addon:GetModule('Perf'):RegisterPrototype(setProto, 'NextOrnamentSet')

-- Create gives a panel its ornaments, none until styled (Style). Its body's size changing repeats a span's art
-- down its new length.
---@param panel table
---@return NextOrnamentSet
function ornaments:Create(panel)
  local set = setmetatable({ panel = panel, pieces = {}, count = 0, mirrored = false, running = false },
    { __index = setProto })
  -- A plain hook: it runs on every frame of a resize, and addon.HookScript makes a Context per call.
  panel.body:HookScript("OnSizeChanged", function()
    set:Tile()
  end)
  return set
end

-- Style draws the theme's ornaments: each piece's art, its place (Layout) and its motion; pieces the theme no
-- longer has hide and stop. Moving while the panel showed, they move again (Start).
function setProto:Style()
  local running = self.running
  self:Stop()
  local list = style.Theme.Panel.Ornaments or {}
  self.mirrored = self:Mirrored()
  for i, spec in ipairs(list) do
    local piece = self.pieces[i]
    if piece == nil then
      piece = { texture = self.panel.frame:CreateTexture(nil, "ARTWORK"), shown = false, phase = 0 }
      self.pieces[i] = piece
    end
    piece.spec = spec
    self:paint(piece)
    self:move(piece)
  end
  for i = #list + 1, #self.pieces do
    local piece = self.pieces[i]
    piece.spec, piece.shown = nil, false
    piece.texture:Hide()
  end
  self.count = #list
  self:Layout()
  if running then
    self:Start()
  end
end

-- Mirrored says whether the panel's inner side is on the right: it belongs to the left of the screen.
---@return boolean
function setProto:Mirrored()
  return self.panel.side == "LEFT"
end

-- paint draws a piece's art: its file (a Textures name), loaded repeating along a span with a Tile and smooth
-- (TRILINEAR: art drawn smaller than it is), in its color and alpha, blend mode and layer.
---@private
---@param piece NextOrnamentPiece
function setProto:paint(piece)
  local o, t = piece.spec, piece.texture
  local tiled = o.Tile ~= nil
  local across = o.Point == "TOP" or o.Point == "BOTTOM"
  t:SetTexture(style:TexturePath(o.Texture), (tiled and across) and "REPEAT" or nil,
    (tiled and not across) and "REPEAT" or nil, "TRILINEAR")
  local r, g, b, a = style:RGBA(o.Color or "White", o.Alpha)
  t:SetVertexColor(r, g, b, a)
  t:SetBlendMode(o.BlendMode or "BLEND")
  t:SetDesaturated(o.Desaturated == true)
  t:SetDrawLayer(o.Layer or "ARTWORK", o.SubLevel or 0)
end

-- Layout places every piece for the panel's size and side: shown at the size it is for (Sizes), anchored to the
-- body in whole pixels of the frame's grid, its art mirrored for an inner side on the right. A panel's side never
-- changes, but a panel built mirrored before it styled takes it here too.
function setProto:Layout()
  local panel = self.panel
  local small = panel:IsSmall()
  if self:Mirrored() ~= self.mirrored then
    self.mirrored = self:Mirrored()
    for i = 1, self.count do
      self:move(self.pieces[i])
    end
  end
  for i = 1, self.count do
    local piece = self.pieces[i]
    local o = piece.spec
    piece.shown = o.Sizes == nil or (o.Sizes == "Small") == small
    if piece.shown then
      self:place(piece)
      piece.texture:Show()
      if self.running then
        self:play(piece)
      end
    else
      self:stopPiece(piece)
      piece.texture:Hide()
    end
  end
  self:Tile()
end

-- place anchors a piece: a span between two of the body's corners (along its INNER or OUTER side, Start from
-- the top and End from the bottom; along its TOP or BOTTOM, Start from the inner end and End from the outer), X
-- toward the body's middle from its side and Y down; or a piece at a corner (Point), by its own point (Anchor,
-- the same corner when unset), X toward the middle and Y down.
---@private
---@param piece NextOrnamentPiece
function setProto:place(piece)
  local o, t, body = piece.spec, piece.texture, self.panel.body
  local mirrored = self.mirrored
  local x, y = pixel:Snap(t, o.X or 0), pixel:Snap(t, o.Y or 0)
  local start, finish = pixel:Snap(t, o.Start or 0), pixel:Snap(t, o.End or 0)
  t:ClearAllPoints()
  if o.Point == "INNER" or o.Point == "OUTER" then
    local left = (o.Point == "INNER") ~= mirrored
    local side = left and "LEFT" or "RIGHT"
    local dx = left and x or -x
    t:SetPoint("TOP" .. side, body, "TOP" .. side, dx, -start)
    t:SetPoint("BOTTOM" .. side, body, "BOTTOM" .. side, dx, finish)
    pixel:Width(t, o.Width)
  elseif o.Point == "TOP" or o.Point == "BOTTOM" then
    local inner, outer = mirrored and "RIGHT" or "LEFT", mirrored and "LEFT" or "RIGHT"
    t:SetPoint(o.Point .. inner, body, o.Point .. inner, mirrored and -start or start, -y)
    t:SetPoint(o.Point .. outer, body, o.Point .. outer, mirrored and finish or -finish, -y)
    pixel:Height(t, o.Height)
  else
    local point = CORNERS[o.Point]
    local anchor = CORNERS[o.Anchor or o.Point]
    if mirrored then
      point, anchor = MIRRORED[point], MIRRORED[anchor]
    end
    -- Toward the middle: right from a left corner, left from a right one.
    local dx = point:find("LEFT") and x or -x
    t:SetPoint(anchor, body, point, dx, -y)
    pixel:Size(t, o.Width, o.Height)
  end
end

-- Tile repeats each span's art every Tile along its length, as long as the body is now, mirrored with the panel;
-- other pieces show their art once.
function setProto:Tile()
  local body = self.panel.body
  for i = 1, self.count do
    local piece = self.pieces[i]
    local o, t = piece.spec, piece.texture
    local left, right = 0, 1
    if self.mirrored then
      left, right = 1, 0
    end
    if o.Tile ~= nil and (o.Point == "INNER" or o.Point == "OUTER") then
      local length = body:GetHeight() - pixel:Snap(t, o.Start or 0) - pixel:Snap(t, o.End or 0)
      t:SetTexCoord(left, right, 0, math.max(0, length) / o.Tile)
    elseif o.Tile ~= nil then
      local length = body:GetWidth() - pixel:Snap(t, o.Start or 0) - pixel:Snap(t, o.End or 0)
      local reach = math.max(0, length) / o.Tile
      t:SetTexCoord(self.mirrored and reach or 0, self.mirrored and 0 or reach, 0, 1)
    else
      t:SetTexCoord(left, right, 0, 1)
    end
  end
end

-- group returns a piece's animation group for a motion, emptied: made once and kept, so a theme's motion is
-- rebuilt on the same texture (RemoveAnimations, every client).
---@param piece NextOrnamentPiece
---@param kind string
---@return AnimationGroup
local function group(piece, kind)
  piece.groups = piece.groups or {}
  local g = piece.groups[kind]
  if g == nil then
    g = piece.texture:CreateAnimationGroup()
    piece.groups[kind] = g
  end
  g:Stop()
  g:RemoveAnimations()
  return g
end

-- move builds a piece's motion (Motion), mirrored with the panel: Sway, degrees either way of its rest about
-- Origin (BOTTOM when unset), a full swing every Period; Spin, a turn every Period about its middle (1 clockwise,
-- -1 the other way); Pulse, its alpha from the first value to the second and back every Period; Bob, up that far
-- and back every Period. Delay is where in its motion it starts, so pieces do not move in step. A piece without
-- motion has no groups; one that had them keeps them empty.
---@private
---@param piece NextOrnamentPiece
function setProto:move(piece)
  if piece.groups ~= nil then
    for kind in pairs(piece.groups) do
      group(piece, kind)
    end
  end
  local M = piece.spec.Motion
  if not M then
    return
  end
  local period, mirror = M.Period or 4, self.mirrored and -1 or 1
  piece.phase = M.Delay or 0
  local function origin(name, default)
    local point = ORIGINS[name or default]
    return self.mirrored and MIRRORED[point] or point
  end
  if M.Sway then
    local g = group(piece, "Sway")
    local turn = origin(M.Origin, "BOTTOM")
    -- Eased only where it turns, so it passes rest at full speed: out of rest slowing to its first turn, across
    -- between its turns, from its last turn speeding back through rest. Eased in and out on every step, it stopped
    -- dead at rest once a cycle (reported in game: "very jerky").
    for order, step in ipairs({ { 1, 0.25, "OUT" }, { -2, 0.5, "IN_OUT" }, { 1, 0.25, "IN" } }) do
      local a = g:CreateAnimation("Rotation")
      a:SetDegrees(M.Sway * step[1] * mirror)
      a:SetDuration(period * step[2])
      a:SetOrder(order)
      a:SetOrigin(turn, 0, 0)
      a:SetSmoothing(step[3])
    end
    g:SetLooping("REPEAT")
  end
  if M.Spin then
    local g = group(piece, "Spin")
    local a = g:CreateAnimation("Rotation")
    a:SetDegrees(-360 * M.Spin * mirror)
    a:SetDuration(period)
    a:SetOrigin(origin(M.Origin, "CENTER"), 0, 0)
    a:SetSmoothing("NONE")
    g:SetLooping("REPEAT")
  end
  if M.Pulse then
    local g = group(piece, "Pulse")
    local a = g:CreateAnimation("Alpha")
    a:SetFromAlpha(M.Pulse[1])
    a:SetToAlpha(M.Pulse[2])
    a:SetDuration(period / 2)
    a:SetSmoothing("IN_OUT")
    g:SetLooping("BOUNCE")
  end
  if M.Bob then
    local g = group(piece, "Bob")
    local a = g:CreateAnimation("Translation")
    a:SetOffset(0, pixel:Snap(piece.texture, M.Bob))
    a:SetDuration(period / 2)
    a:SetSmoothing("IN_OUT")
    g:SetLooping("BOUNCE")
  end
end

-- moving says whether a piece has motion to play.
---@param piece NextOrnamentPiece
---@return boolean
local function moving(piece)
  if piece.groups == nil then
    return false
  end
  for _, g in pairs(piece.groups) do
    if g:GetAnimations() ~= nil then
      return true
    end
  end
  return false
end

-- play starts a piece's motion from its own phase (Play's offset); a group already playing goes on.
---@private
---@param piece NextOrnamentPiece
function setProto:play(piece)
  if not moving(piece) then
    return
  end
  for _, g in pairs(piece.groups) do
    if g:GetAnimations() ~= nil then
      g:Play(false, piece.phase)
    end
  end
end

-- Start plays the motion of every piece shown at the panel's size; one a size switch shows later moves at once.
function setProto:Start()
  self.running = true
  for i = 1, self.count do
    local piece = self.pieces[i]
    if piece.shown then
      self:play(piece)
    end
  end
end

---@private
---@param piece NextOrnamentPiece
function setProto:stopPiece(piece)
  for _, g in pairs(piece.groups or {}) do
    g:Stop()
  end
end

-- Stop ends every piece's motion, back at rest (the panel hid).
function setProto:Stop()
  self.running = false
  for _, piece in ipairs(self.pieces) do
    self:stopPiece(piece)
  end
end

-- MovingParts adds the pieces shown with motion to skip: they rest nowhere, so the pixel checks leave them out.
---@param skip table<table, boolean>
function setProto:MovingParts(skip)
  for i = 1, self.count do
    local piece = self.pieces[i]
    if piece.shown and moving(piece) then
      skip[piece.texture] = true
    end
  end
end
