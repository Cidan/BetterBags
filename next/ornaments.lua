local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

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
-- The corners by their sides, and their mirror images, for what else is placed as a corner piece is (NextMenuButton).
ornaments.CORNERS = CORNERS
ornaments.MIRRORED = MIRRORED
-- The values a theme may give, for SonataNext:Check.
ornaments.POINTS = { INNER = true, OUTER = true, TOP = true, BOTTOM = true, TOPINNER = true, TOPOUTER = true,
  BOTTOMINNER = true, BOTTOMOUTER = true, BODY = true }
ornaments.ANCHORS = CORNERS
ornaments.ORIGINS = ORIGINS
ornaments.SIZES = { Full = true, Small = true }
-- The panels a piece may be shown on (Panels), by the name of the bag kind each panel shows (const.BAG_KIND).
ornaments.PANELS = { Backpack = "BACKPACK", Bank = "BANK", Vendor = "UNDEFINED", GuildBank = "GUILD" }
ornaments.MOTIONS = { Sway = true, Spin = true, Pulse = true, Bob = true, Period = true, Delay = true, Origin = true,
  Scroll = true, Glitch = true, Blink = true, Flicker = true, Flash = true }
-- The keys of a Glitch motion, a Blink, a Flicker and a Flash.
ornaments.GLITCH = { Every = true, Hold = true, Jump = true, Blink = true, Slip = true }
ornaments.BLINK = { Every = true, Time = true, Twice = true }
ornaments.FLICKER = { Low = true, Speed = true }
ornaments.FLASH = { Every = true, Time = true, First = true }
-- Seconds between a glitch's rolls while it lasts: each roll jumps, blinks and slips the piece anew.
ornaments.GLITCH_STEP = 0.06
-- Where Scroll, Glitch, Blink and Flicker take their randomness (a source of numbers in [0, 1)): replaced by the specs.
ornaments.Random = math.random

---@class (exact) NextOrnamentPiece
---@field texture Texture Its texture on the frame it is drawn on.
---@field host Frame The frame it is drawn on: the panel's, or its overlay for a piece that says Above.
---@field hosts table<Frame, table> Its texture, mask and motions on each frame it has been drawn on.
---@field mask? MaskTexture What cuts its art (Mask), made the first time one does.
---@field spec table The theme's entry it draws.
---@field shown boolean Shown at the panel's size.
---@field groups? table<string, AnimationGroup> Its motions' groups, made the first time it moves.
---@field phase number Where its motions start (Motion.Delay).
---@field scrollU? number How far its art has scrolled across, in tiles (Motion.Scroll), within a tile.
---@field scrollV? number And down.
---@field glitch? table Its Glitch motion's state: wait (seconds to its next glitch), left (of the one under way), roll.
---@field jx? number A glitch's jump across (units, on whole pixels).
---@field jy? number And up.
---@field blink? number A glitch's share of its alpha.
---@field slip? number A glitch's slip of its art across, in tiles.
---@field blinking? table Its Blink's state: wait (seconds to its next blink), shut (seconds left of one under way),
---second (blinking again right after one).
---@field shut? boolean Shut by a blink: drawn at no alpha.
---@field flick? table Its Flicker's state: at (its share of its alpha now), to (where it wanders), left (seconds to the
---next).
---@field flicker? number A flicker's share of its alpha.
---@field flashing? table Its Flash's state: wait (seconds to its next flash), left (seconds left of one under way).
---@field flash? number A flash's share of its alpha: none at rest.

---@class (exact) NextOrnamentSet
---@field panel table The panel: its frame, its body, its side, IsSmall.
---@field pieces NextOrnamentPiece[] Every piece made; the first count are the theme's.
---@field count number
---@field mirrored boolean Drawn for an inner side on the right.
---@field running boolean Moving (the panel shows).
---@field driver? Frame Runs the pieces' Scroll, Glitch, Blink and Flicker motions while they move, made the first
---time one does.
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
      piece = { shown = false, phase = 0, hosts = {} }
      self.pieces[i] = piece
    end
    piece.spec = spec
    self:onHost(piece, spec.Above and self:overlay() or self.panel.frame)
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

-- overlay returns the panel's frame over its content (next/panel.lua), for pieces that say Above.
---@private
---@return Frame
function setProto:overlay()
  if self.panel.overlay == nil then
    error("this panel has no overlay to draw an ornament above its content on")
  end
  return self.panel.overlay
end

-- onHost puts a piece on host: the panel's frame, or its overlay for a piece that says Above (the original bags' menu
-- button, over their border and search box). A piece keeps its texture, mask and motions on each frame it has been on,
-- and hides the one it leaves.
---@private
---@param piece NextOrnamentPiece
---@param host Frame
function setProto:onHost(piece, host)
  if piece.host == host then
    return
  end
  local old = piece.host and piece.hosts[piece.host]
  if old ~= nil then
    old.mask, old.groups = piece.mask, piece.groups
    piece.texture:Hide()
  end
  local own = piece.hosts[host]
  if own == nil then
    own = { texture = host:CreateTexture(nil, "ARTWORK") }
    piece.hosts[host] = own
  end
  piece.host, piece.texture, piece.mask, piece.groups = host, own.texture, own.mask, own.groups
end

-- Mirrored says whether the panel's inner side is on the right: it belongs to the left of the screen.
---@return boolean
function setProto:Mirrored()
  return self.panel.side == "LEFT"
end

-- paint draws a piece's art: its file (a Textures name), loaded repeating along a span with a Tile and smooth
-- (TRILINEAR: art drawn smaller than it is), or its Atlas; or a unit's portrait (Unit) while there is one; in its
-- color and alpha, blend mode and layer, cut by its Mask.
---@private
---@param piece NextOrnamentPiece
function setProto:paint(piece)
  local o, t = piece.spec, piece.texture
  self:art(piece)
  local r, g, b, a = style:RGBA(o.Color or "White", o.Alpha)
  t:SetVertexColor(r, g, b, a)
  t:SetBlendMode(o.BlendMode or "BLEND")
  t:SetDesaturated(o.Desaturated == true)
  t:SetDrawLayer(o.Layer or "ARTWORK", o.SubLevel or 0)
  self:cut(piece)
  -- A piece that flashes is light, unseen at rest (its color's alpha is its texture's, next-themes.md §10).
  if o.Motion ~= nil and o.Motion.Flash ~= nil then
    self:fade(piece)
  end
end

-- DrawArt draws a piece's picture on a texture: the portrait of its Unit while the client has that unit
-- (SetPortraitTexture, as Blizzard's windows show the NPC they belong to: SetPortraitToUnit("npc")), else its Atlas or
-- its file (repeating along a span with a Tile), else nothing.
---@param t Texture
---@param o table
function ornaments:DrawArt(t, o)
  if o.Unit ~= nil and UnitExists(o.Unit) then
    SetPortraitTexture(t, o.Unit)
  elseif o.Atlas ~= nil then
    t:SetAtlas(o.Atlas)
  elseif o.Texture ~= nil then
    local tiled = o.Tile ~= nil
    local across = o.Point == "TOP" or o.Point == "BOTTOM" or o.Point == "BODY"
    local down = o.Point ~= "TOP" and o.Point ~= "BOTTOM"
    t:SetTexture(style:TexturePath(o.Texture), (tiled and across) and "REPEAT" or nil,
      (tiled and down) and "REPEAT" or nil, "TRILINEAR")
  else
    t:SetTexture(nil)
  end
end

-- Cut masks a texture's art with M (Texture: a mask file, such as Blizzard's round portrait mask; Inset: Left, Right,
-- Top, Bottom into it, mirrored when asked), the mask made on host the first time (mask, when it has one), or takes
-- the mask off for no M. Returns the texture's mask.
---@param t Texture
---@param M? table|false
---@param host Frame
---@param mask? MaskTexture
---@param mirrored? boolean
---@return MaskTexture?
function ornaments:Cut(t, M, host, mask, mirrored)
  if not M then
    if mask ~= nil then
      t:RemoveMaskTexture(mask)
      mask:Hide()
    end
    return mask
  end
  if mask == nil then
    -- On the texture's own frame.
    mask = host:CreateMaskTexture()
  end
  mask:SetTexture(style:TexturePath(M.Texture), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  local inset = M.Inset or {}
  local left, right = inset.Left or 0, inset.Right or 0
  if mirrored then
    left, right = right, left
  end
  mask:ClearAllPoints()
  mask:SetPoint("TOPLEFT", t, "TOPLEFT", pixel:Snap(t, left), -pixel:Snap(t, inset.Top or 0))
  mask:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -pixel:Snap(t, right), pixel:Snap(t, inset.Bottom or 0))
  mask:Show()
  t:AddMaskTexture(mask)
  return mask
end

-- art draws a piece's picture (DrawArt).
---@private
---@param piece NextOrnamentPiece
function setProto:art(piece)
  ornaments:DrawArt(piece.texture, piece.spec)
end

-- cut masks a piece's art with its Mask, mirrored with the panel, or takes the mask off a piece that has none now (Cut).
---@private
---@param piece NextOrnamentPiece
function setProto:cut(piece)
  piece.mask = ornaments:Cut(piece.texture, piece.spec.Mask, piece.host, piece.mask, self:Mirrored())
end

-- OnPanel says whether a piece is for this panel: every panel, or those its Panels names.
---@private
---@param o table
---@return boolean
function setProto:OnPanel(o)
  if o.Panels == nil then
    return true
  end
  for _, name in ipairs(o.Panels) do
    if const.BAG_KIND[ornaments.PANELS[name]] == self.panel.kind then
      return true
    end
  end
  return false
end

-- Layout places every piece for the panel's size and side: shown at the size it is for (Sizes) on the panels it
-- is for (Panels), anchored to the body in whole pixels of the frame's grid, its art mirrored for an inner side on
-- the right. A panel's side never changes, but a panel built mirrored before it styled takes it here too.
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
    piece.shown = (o.Sizes == nil or (o.Sizes == "Small") == small) and self:OnPanel(o)
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
  if self.running then
    self:drive()
  end
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
  -- A glitch's jump (Motion.Glitch), on whole pixels: right and up.
  local jx, jy = piece.jx or 0, piece.jy or 0
  t:ClearAllPoints()
  if o.Point == "BODY" then
    -- Over the whole body, Inset into it (Left on its inner side), mirrored.
    local inset = o.Inset or {}
    local left, right = pixel:Snap(t, inset.Left or 0), pixel:Snap(t, inset.Right or 0)
    if mirrored then
      left, right = right, left
    end
    t:SetPoint("TOPLEFT", body, "TOPLEFT", left + jx, -pixel:Snap(t, inset.Top or 0) + jy)
    t:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -right + jx, pixel:Snap(t, inset.Bottom or 0) + jy)
  elseif o.Point == "INNER" or o.Point == "OUTER" then
    local left = (o.Point == "INNER") ~= mirrored
    local side = left and "LEFT" or "RIGHT"
    local dx = left and x or -x
    t:SetPoint("TOP" .. side, body, "TOP" .. side, dx + jx, -start + jy)
    t:SetPoint("BOTTOM" .. side, body, "BOTTOM" .. side, dx + jx, finish + jy)
    pixel:Width(t, o.Width)
  elseif o.Point == "TOP" or o.Point == "BOTTOM" then
    local inner, outer = mirrored and "RIGHT" or "LEFT", mirrored and "LEFT" or "RIGHT"
    t:SetPoint(o.Point .. inner, body, o.Point .. inner, (mirrored and -start or start) + jx, -y + jy)
    t:SetPoint(o.Point .. outer, body, o.Point .. outer, (mirrored and finish or -finish) + jx, -y + jy)
    pixel:Height(t, o.Height)
  else
    local point = CORNERS[o.Point]
    local anchor = CORNERS[o.Anchor or o.Point]
    if mirrored then
      point, anchor = MIRRORED[point], MIRRORED[anchor]
    end
    -- Toward the middle: right from a left corner, left from a right one.
    local dx = point:find("LEFT") and x or -x
    t:SetPoint(anchor, body, point, dx + jx, -y + jy)
    pixel:Size(t, o.Width, o.Height)
  end
end

-- Tile repeats each span's art every Tile along its length, as long as the body is now, mirrored with the panel;
-- other pieces show their art once, cropped to their TexCoords (left, right, top, bottom: art that is part of
-- its file), mirrored with the panel too.
function setProto:Tile()
  for i = 1, self.count do
    self:tilePiece(self.pieces[i])
  end
end

-- tilePiece sets a piece's texture coordinates (Tile), moved by how far its art has scrolled (Motion.Scroll) and a
-- glitch's slip (Motion.Glitch). A piece over the whole body with a Tile repeats it both ways.
---@private
---@param piece NextOrnamentPiece
function setProto:tilePiece(piece)
  local body = self.panel.body
  local o, t = piece.spec, piece.texture
  -- A tiled span's TexCoords crop it across (its strip of the file: Classic's title band, _UI-Frame-TitleTileBg).
  local c = o.TexCoords or { 0, 1, 0, 1 }
  local u0, u1, v0, v1
  if o.Tile ~= nil and o.Point == "BODY" then
    local w, h = t:GetWidth() / o.Tile, t:GetHeight() / o.Tile
    if self.mirrored then
      u0, u1 = w, 0
    else
      u0, u1 = 0, w
    end
    v0, v1 = 0, h
  elseif o.Tile ~= nil and (o.Point == "INNER" or o.Point == "OUTER") then
    local length = body:GetHeight() - pixel:Snap(t, o.Start or 0) - pixel:Snap(t, o.End or 0)
    if self.mirrored then
      u0, u1 = c[2], c[1]
    else
      u0, u1 = c[1], c[2]
    end
    v0, v1 = 0, math.max(0, length) / o.Tile
  elseif o.Tile ~= nil then
    local length = body:GetWidth() - pixel:Snap(t, o.Start or 0) - pixel:Snap(t, o.End or 0)
    local reach = math.max(0, length) / o.Tile
    u0, u1, v0, v1 = self.mirrored and reach or 0, self.mirrored and 0 or reach, c[3], c[4]
  elseif self.mirrored and o.Mirror ~= false then
    -- Mirror = false: art that must not be flipped (a portrait, an icon), placed mirrored all the same.
    u0, u1, v0, v1 = c[2], c[1], c[3], c[4]
  else
    u0, u1, v0, v1 = c[1], c[2], c[3], c[4]
  end
  local du, dv = (piece.scrollU or 0) + (piece.slip or 0), piece.scrollV or 0
  t:SetTexCoord(u0 + du, u1 + du, v0 + dv, v1 + dv)
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
  local M = piece.spec and piece.spec.Motion
  if M and (M.Glitch or M.Blink or M.Flicker or M.Flash or (M.Scroll and piece.spec.Tile)) then
    return true
  end
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
  for _, g in pairs(piece.groups or {}) do
    if g:GetAnimations() ~= nil then
      g:Play(false, piece.phase)
    end
  end
end

-- Start plays the motion of every piece shown at the panel's size; one a size switch shows later moves at once. As
-- the panel shows, a unit's portrait is drawn again: the NPC it belongs to may be another one, or none.
function setProto:Start()
  self.running = true
  for i = 1, self.count do
    local piece = self.pieces[i]
    if piece.spec.Unit ~= nil then
      self:art(piece)
    end
    if piece.shown then
      self:play(piece)
    end
  end
  self:Tile()
  self:drive()
end

-- luaMotion says whether a piece moves on the set's driver: art that scrolls (a tiled piece's Scroll), glitches, blinks
-- or flickers.
---@param piece NextOrnamentPiece
---@return boolean
local function luaMotion(piece)
  local M = piece.spec and piece.spec.Motion
  return M ~= nil and (M.Glitch ~= nil or M.Blink ~= nil or M.Flicker ~= nil or M.Flash ~= nil
    or (M.Scroll ~= nil and piece.spec.Tile ~= nil))
end

-- drive runs the set's driver while a piece shown moves on it (Scroll, Glitch, Blink, Flicker), and stops it when none
-- does. A child
-- of the panel's frame: it stops while the panel hides.
---@private
function setProto:drive()
  local any = false
  for i = 1, self.count do
    local piece = self.pieces[i]
    if piece.shown and luaMotion(piece) then
      any = true
    end
  end
  if not any then
    if self.driver ~= nil then
      self.driver:SetScript("OnUpdate", nil)
    end
    return
  end
  if self.driver == nil then
    self.driver = CreateFrame("Frame", nil, self.panel.frame)
  end
  self.driver:SetScript("OnUpdate", function(_, elapsed)
    self:Step(elapsed)
  end)
end

-- Step moves the pieces on the driver elapsed seconds along: art that scrolls moves on (Motion.Scroll: X units a second
-- toward the outer side, Y down; kept within a tile), a piece that glitches waits for its next glitch, or rolls a
-- glitch under way anew every GLITCH_STEP until it ends, back at rest (Motion.Glitch), one that blinks waits for its
-- next blink or holds one shut (Motion.Blink), and one that flickers wanders its alpha on (Motion.Flicker).
---@param elapsed number
function setProto:Step(elapsed)
  for i = 1, self.count do
    local piece = self.pieces[i]
    local o = piece.spec
    local M = o.Motion
    if piece.shown and M ~= nil then
      if M.Scroll ~= nil and o.Tile ~= nil then
        piece.scrollU = ((piece.scrollU or 0) - (M.Scroll.X or 0) * elapsed / o.Tile) % 1
        piece.scrollV = ((piece.scrollV or 0) - (M.Scroll.Y or 0) * elapsed / o.Tile) % 1
        self:tilePiece(piece)
      end
      if M.Glitch ~= nil then
        self:glitchStep(piece, M.Glitch, elapsed)
      end
      if M.Blink ~= nil then
        self:blinkStep(piece, M.Blink, elapsed)
      end
      if M.Flicker ~= nil then
        self:flickerStep(piece, M.Flicker, elapsed)
      end
      if M.Flash ~= nil then
        self:flashStep(piece, M.Flash, elapsed)
      end
    end
  end
end

---@param range number[]
---@return number
local function between(range)
  return range[1] + (range[2] - range[1]) * ornaments.Random()
end

-- blinkStep blinks a piece now and then (asked, of the Halloween theme's black cat, next-themes.md §23): it waits Every
-- (soonest, latest), is shut for Time (drawn at no alpha), and now and then (Twice: the share of blinks) blinks again
-- as soon as it has been open as long as it was shut, never a third time.
---@private
---@param piece NextOrnamentPiece
---@param B table
---@param elapsed number
function setProto:blinkStep(piece, B, elapsed)
  local st = piece.blinking
  if st == nil then
    st = { wait = between(B.Every), second = false }
    piece.blinking = st
  end
  local time = B.Time or 0.12
  if st.shut ~= nil then
    st.shut = st.shut - elapsed
    if st.shut <= 0 then
      st.shut = nil
      piece.shut = nil
      if not st.second and ornaments.Random() < (B.Twice or 0) then
        st.second = true
        st.wait = time
      else
        st.second = false
        st.wait = between(B.Every)
      end
      self:fade(piece)
    end
    return
  end
  st.wait = st.wait - elapsed
  if st.wait <= 0 then
    st.shut = time
    piece.shut = true
    self:fade(piece)
  end
end

-- flickerStep flickers a piece like a candle (the Halloween theme's jack-o'-lantern): its alpha wanders, never still,
-- between Low of its own and its own, toward somewhere new every half to one and a half of a Speed'th of a second.
---@private
---@param piece NextOrnamentPiece
---@param F table
---@param elapsed number
function setProto:flickerStep(piece, F, elapsed)
  local st = piece.flick
  if st == nil then
    st = { at = 1, to = 1, left = 0 }
    piece.flick = st
  end
  local low, speed = F.Low or 0.6, F.Speed or 8
  st.left = st.left - elapsed
  if st.left <= 0 then
    st.to = low + (1 - low) * ornaments.Random()
    st.left = (0.5 + ornaments.Random()) / speed
  end
  st.at = st.at + (st.to - st.at) * math.min(1, elapsed * speed * 1.5)
  piece.flicker = st.at
  self:fade(piece)
end

-- flashStep flashes a piece now and then (asked: the Make It So theme's comm badge, next-themes.md §24): unseen at rest,
-- it waits First after the panel shows (else Every: soonest, latest), then over Time it comes up to its alpha and goes
-- out again (half a sine), and waits Every for the next.
---@private
---@param piece NextOrnamentPiece
---@param F table
---@param elapsed number
function setProto:flashStep(piece, F, elapsed)
  local st = piece.flashing
  if st == nil then
    st = { wait = F.First or between(F.Every) }
    piece.flashing = st
  end
  local time = F.Time or 0.3
  if st.left == nil then
    st.wait = st.wait - elapsed
    if st.wait > 0 then
      return
    end
    -- What it waited past is how far into its flash it is.
    st.left = time + st.wait
  else
    st.left = st.left - elapsed
  end
  if st.left <= 0 then
    st.left = nil
    st.wait = between(F.Every)
    piece.flash = 0
  else
    piece.flash = math.sin(math.pi * (1 - st.left / time))
  end
  self:fade(piece)
end

-- nextWait is how long a piece waits for its next glitch: Every on average, from 0.3 to 1.7 of it.
---@param G table
---@return number
local function nextWait(G)
  return (G.Every or 5) * (0.3 + 1.4 * ornaments.Random())
end

---@private
---@param piece NextOrnamentPiece
---@param G table
---@param elapsed number
function setProto:glitchStep(piece, G, elapsed)
  local st = piece.glitch
  if st == nil then
    st = { wait = nextWait(G) }
    piece.glitch = st
  end
  if st.left ~= nil then
    st.left = st.left - elapsed
    if st.left <= 0 then
      st.left = nil
      st.wait = nextWait(G)
      self:rest(piece)
      return
    end
    st.roll = st.roll - elapsed
    if st.roll <= 0 then
      self:roll(piece, G)
    end
    return
  end
  st.wait = st.wait - elapsed
  if st.wait <= 0 then
    st.left = G.Hold or 0.12
    self:roll(piece, G)
  end
end

-- roll jumps a piece up to Jump units either way across and up or down (on whole pixels), blinks it to Blink of its
-- alpha half the time, and slips its art up to Slip of a tile either way.
---@private
---@param piece NextOrnamentPiece
---@param G table
function setProto:roll(piece, G)
  local random, t = ornaments.Random, piece.texture
  local jump = G.Jump or 0
  piece.jx = pixel:Snap(t, (2 * random() - 1) * jump)
  piece.jy = pixel:Snap(t, (2 * random() - 1) * jump)
  piece.blink = random() < 0.5 and (G.Blink or 1) or 1
  piece.slip = (2 * random() - 1) * (G.Slip or 0)
  piece.glitch.roll = ornaments.GLITCH_STEP
  self:show(piece)
end

-- rest puts a glitched piece back: no jump, blink or slip.
---@private
---@param piece NextOrnamentPiece
function setProto:rest(piece)
  piece.jx, piece.jy, piece.blink, piece.slip = nil, nil, nil, nil
  self:show(piece)
end

-- show draws a piece as its glitch state says: placed, its art's coordinates, its alpha (fade).
---@private
---@param piece NextOrnamentPiece
function setProto:show(piece)
  self:place(piece)
  self:tilePiece(piece)
  self:fade(piece)
end

-- fade draws a piece at its alpha: its own, times a glitch's blink, a flicker's share, and none while a blink has it
-- shut.
---@private
---@param piece NextOrnamentPiece
function setProto:fade(piece)
  local _, _, _, a = style:RGBA(piece.spec.Color or "White", piece.spec.Alpha)
  local M = piece.spec.Motion
  local flash = 1
  if M ~= nil and M.Flash ~= nil then
    flash = piece.flash or 0
  end
  piece.texture:SetAlpha(piece.shut and 0 or a * (piece.blink or 1) * (piece.flicker or 1) * flash)
end

---@private
---@param piece NextOrnamentPiece
function setProto:stopPiece(piece)
  for _, g in pairs(piece.groups or {}) do
    g:Stop()
  end
end

-- Stop ends every piece's motion, back at rest (the panel hid): a glitch, a blink or a flicker under way ends.
function setProto:Stop()
  self.running = false
  if self.driver ~= nil then
    self.driver:SetScript("OnUpdate", nil)
  end
  for _, piece in ipairs(self.pieces) do
    self:stopPiece(piece)
    if piece.glitch ~= nil then
      piece.glitch = nil
      if piece.spec ~= nil then
        self:rest(piece)
      end
    end
    if piece.blinking ~= nil or piece.flick ~= nil or piece.flashing ~= nil then
      piece.blinking, piece.shut, piece.flick, piece.flicker = nil, nil, nil, nil
      piece.flashing, piece.flash = nil, nil
      if piece.spec ~= nil then
        self:fade(piece)
      end
    end
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
