local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

-- NextFrameArt draws a nine-slice frame round a region, as Blizzard frames its windows (next-themes.md §15): from
-- one of the client's own layouts by name (NineSliceUtil.GetLayout: the client's art and offsets, Forever's own
-- adjustments included), or from a theme's pieces. Pieces are placed by the rules of Blizzard's
-- NineSliceUtil.ApplyLayout (Blizzard_SharedXML/NineSlice.lua, every client): each corner at its corner by its offsets
-- at its atlas size; each edge between its two corners, as thick as its atlas, tiled as its atlas says; the center
-- between the top left and bottom right corners. A layout that mirrors itself (mirrorLayout) flips its mirrored
-- pieces; a panel whose inner side is on the right draws the whole frame mirrored, as its ornaments are. Drawn on
-- the owner's own textures, in one layer, whole pixels at rest (docs/next-pixel-perfect.md). Asked for the Plain
-- theme: "looks like the default UI for the version of WoW we're playing on" (docs/next-plain-theme.md).
---@class NextFrameArt: AceModule
local frameArt = addon:NewModule('NextFrameArt')

-- Blizzard's piece setup (NineSlice.lua's nineSliceSetup), in its order: corners before the edges anchored to
-- them, the center last.
local SETUP = {
  { name = "TopLeftCorner", point = "TOPLEFT", corner = true },
  { name = "TopRightCorner", point = "TOPRIGHT", mirrorH = true, corner = true },
  { name = "BottomLeftCorner", point = "BOTTOMLEFT", mirrorV = true, corner = true },
  { name = "BottomRightCorner", point = "BOTTOMRIGHT", mirrorH = true, mirrorV = true, corner = true },
  { name = "TopEdge", point = "TOPLEFT", relativePoint = "TOPRIGHT", between = { "TopLeftCorner", "TopRightCorner" } },
  { name = "BottomEdge", point = "BOTTOMLEFT", relativePoint = "BOTTOMRIGHT",
    between = { "BottomLeftCorner", "BottomRightCorner" }, mirrorV = true },
  { name = "LeftEdge", point = "TOPLEFT", relativePoint = "BOTTOMLEFT", between = { "TopLeftCorner", "BottomLeftCorner" } },
  { name = "RightEdge", point = "TOPRIGHT", relativePoint = "BOTTOMRIGHT",
    between = { "TopRightCorner", "BottomRightCorner" }, mirrorH = true },
  { name = "Center" },
}
local MIRROR_NAME = {
  TopLeftCorner = "TopRightCorner", TopRightCorner = "TopLeftCorner", BottomLeftCorner = "BottomRightCorner",
  BottomRightCorner = "BottomLeftCorner", LeftEdge = "RightEdge", RightEdge = "LeftEdge", TopEdge = "TopEdge",
  BottomEdge = "BottomEdge", Center = "Center",
}
local MIRROR_POINT = {
  TOPLEFT = "TOPRIGHT", TOPRIGHT = "TOPLEFT", BOTTOMLEFT = "BOTTOMRIGHT", BOTTOMRIGHT = "BOTTOMLEFT",
  LEFT = "RIGHT", RIGHT = "LEFT", TOP = "TOP", BOTTOM = "BOTTOM", CENTER = "CENTER",
}
-- Every piece a frame has, for SonataNext:Check.
frameArt.PIECES = {}
for _, setup in ipairs(SETUP) do
  frameArt.PIECES[setup.name] = true
end

---@class (exact) NextFrameArtSet
---@field owner Frame The frame whose textures the pieces are, unless drawn above its content.
---@field region ScriptRegion What the frame is drawn round.
---@field above? Frame The frame over the owner's content the pieces are drawn on for Above.
---@field hosts table<Frame, table<string, Texture>> The pieces on each frame they have been drawn on.
---@field pieces table<string, Texture> Each piece's texture, by the place it is drawn in, on the frame drawn on last.
---@field bands Texture[] The bands across the top (Bands), under the pieces.
---@field own table<Texture, table> Each texture's own pixel snapping, given back when a layout turned it off.
local setProto = {}
addon:GetModule('Perf'):RegisterPrototype(setProto, 'NextFrameArtSet')

-- Create gives owner the textures of a frame round region, drawn nowhere until Apply. above, when given, is a frame over
-- the owner's content the pieces are drawn on for a frame that says Above (the original bags' border, over their
-- content); without Above they are the owner's own, under everything in its child frames (Blizzard's settings window:
-- its NineSlice at the window's own level).
---@param owner Frame
---@param region ScriptRegion
---@param above? Frame
---@return NextFrameArtSet
function frameArt:Create(owner, region, above)
  local set = setmetatable({ owner = owner, region = region, above = above, hosts = {}, own = {}, bands = {} },
    { __index = setProto })
  set.pieces = set:piecesOn(owner)
  return set
end

-- piecesOn returns the frame's pieces drawn on host, made the first time.
---@private
---@param host Frame
---@return table<string, Texture>
function setProto:piecesOn(host)
  local pieces = self.hosts[host]
  if pieces == nil then
    pieces = {}
    for _, setup in ipairs(SETUP) do
      local texture = host:CreateTexture(nil, "ARTWORK", nil, 5)
      texture:Hide()
      pieces[setup.name] = texture
      self.own[texture] = { snap = texture:IsSnappingToPixelGrid(), bias = texture:GetTexelSnappingBias() }
    end
    self.hosts[host] = pieces
  end
  return pieces
end

-- layoutOf returns what a theme's Frame draws as Blizzard's layout format: one of the client's layouts by name
-- (Layout), or the theme's pieces (Pieces: Atlas, or Texture with TexCoords, Width, Height, HorizTile, VertTile; X,
-- Y and, for an edge or the center, X1, Y1).
---@param spec table
---@return table
local function layoutOf(spec)
  if spec.Layout ~= nil then
    local layout = NineSliceUtil.GetLayout(spec.Layout)
    if layout == nil then
      error("the client has no nine-slice layout named " .. tostring(spec.Layout))
    end
    if layout.setupPieceVisualsFunction ~= nil then
      error("BetterBags Next cannot draw " .. spec.Layout .. ": it sets its pieces up itself")
    end
    for _, setup in ipairs(SETUP) do
      local piece = layout[setup.name]
      if piece ~= nil and type(piece.atlas) == "string" and piece.atlas:find("%", 1, true) then
        error("BetterBags Next cannot draw " .. spec.Layout .. ": it needs a texture kit")
      end
    end
    return layout
  end
  local layout = {}
  for name, p in pairs(spec.Pieces or {}) do
    layout[name] = { atlas = p.Atlas, file = p.Texture, texCoords = p.TexCoords, width = p.Width, height = p.Height,
      horizTile = p.HorizTile, vertTile = p.VertTile, x = p.X, y = p.Y, x1 = p.X1, y1 = p.Y1, point = p.Point,
      relativePoint = p.RelativePoint }
  end
  return layout
end

-- Apply draws spec round the region (false or nil: nothing), mirrored for a panel whose inner side is on the right.
-- spec: Layout (a client layout's name) or Pieces; Color and Alpha tint every piece (white when unset); Layer and
-- SubLevel are where they draw (ARTWORK 5 when unset: above the theme's ornaments, below the title); Above, on the frame
-- over the owner's content (Create's above); Bands, strips across the region's top (texture specs, each Height tall,
-- Left and Right in from its sides, Top down from its top), in the owner's BACKGROUND layer over its fills.
---@param spec? table|false
---@param mirrored? boolean
function setProto:Apply(spec, mirrored)
  if spec and spec.Above and self.above == nil then
    error("this frame cannot be drawn above its content")
  end
  for _, pieces in pairs(self.hosts) do
    for _, texture in pairs(pieces) do
      texture:Hide()
    end
  end
  if not spec then
    self:drawBands(nil, mirrored)
    return
  end
  self:drawBands(spec.Bands, mirrored)
  self.pieces = self:piecesOn(spec.Above and self.above or self.owner)
  local layout = layoutOf(spec)
  local r, g, b, a = style:RGBA(spec.Color or "White", spec.Alpha)
  local layer, subLevel = spec.Layer or "ARTWORK", spec.SubLevel or 5
  for _, setup in ipairs(SETUP) do
    local slot = mirrored and MIRROR_NAME[setup.name] or setup.name
    local texture = self.pieces[slot]
    texture:SetDrawLayer(layer, subLevel)
    self:sharpen(texture, layout.disableSharpening == true)
    local piece = layout[setup.name]
    local drawn = piece ~= nil and self:paint(texture, setup, piece, layout, mirrored)
    if piece ~= nil then
      self:place(texture, setup, piece, layout, mirrored)
    elseif setup.corner then
      -- A corner the layout lacks still holds its edges' ends, as Blizzard's empty piece does.
      texture:ClearAllPoints()
      local point = mirrored and MIRROR_POINT[setup.point] or setup.point
      texture:SetPoint(point, self.region, point, 0, 0)
      texture:SetSize(0, 0)
    end
    texture:SetVertexColor(r, g, b, a)
    texture:SetShown(drawn == true)
  end
end

-- drawBands draws the frame's bands across the top (DefaultPanelTemplate's TopTileStreaks, Classic's
-- _UI-Frame-TitleTileBg), each over the one before, in the owner's BACKGROUND layer as Blizzard's are in its frame's: over
-- the owner's fills, under the frame's pieces and everything in the owner's child frames. Those it no longer has hide.
---@private
---@param list? table[]
---@param mirrored? boolean
function setProto:drawBands(list, mirrored)
  list = list or {}
  for i, spec in ipairs(list) do
    local band = self.bands[i]
    if band == nil then
      band = self.owner:CreateTexture(nil, "BACKGROUND", nil, i)
      self.bands[i] = band
    end
    self:band(band, spec, mirrored)
  end
  for i = #list + 1, #self.bands do
    self.bands[i]:Hide()
  end
end

-- band draws one band, its sides swapped on a mirrored frame.
---@private
---@param band Texture
---@param spec table
---@param mirrored? boolean
function setProto:band(band, spec, mirrored)
  local region = self.region
  style:Paint(band, spec, spec.Alpha)
  local left, right = spec.Left or 0, spec.Right or 0
  if mirrored then
    left, right = right, left
  end
  local top = spec.Top or 0
  band:ClearAllPoints()
  pixel:Point(band, "TOPLEFT", region, "TOPLEFT", left, -top)
  pixel:Point(band, "TOPRIGHT", region, "TOPRIGHT", -right, -top)
  pixel:Height(band, spec.Height or 0)
  band:Show()
end

-- sharpen turns a texture's pixel snapping off for a layout that says so (NineSliceUtil.DisableSharpening), or gives
-- it its own back.
---@private
---@param texture Texture
---@param off boolean
function setProto:sharpen(texture, off)
  local own = self.own[texture]
  texture:SetSnapToPixelGrid(not off and own.snap)
  texture:SetTexelSnappingBias(off and 0 or own.bias)
end

-- paint draws a piece's art: an atlas the client has (C_Texture.GetAtlasInfo) at its size, tiled as it says; or a
-- file with its coordinates, size and tiling. Its coordinates flipped where the layout mirrors itself and where the
-- frame is mirrored. It returns whether there was art to draw.
---@private
---@return boolean
function setProto:paint(texture, setup, piece, layout, mirrored)
  texture:SetTexCoord(0, 1, 0, 1)
  texture:SetHorizTile(false)
  texture:SetVertTile(false)
  local width, height = piece.width, piece.height
  if piece.atlas ~= nil then
    local info = C_Texture.GetAtlasInfo(piece.atlas)
    if info == nil then
      return false
    end
    texture:SetAtlas(piece.atlas, false)
    texture:SetHorizTile(info.tilesHorizontally == true)
    texture:SetVertTile(info.tilesVertically == true)
    width, height = width or info.width, height or info.height
  elseif piece.file ~= nil then
    local wrapH = piece.horizTile and "REPEAT" or nil
    local wrapV = piece.vertTile and "REPEAT" or nil
    texture:SetTexture(style:TexturePath(piece.file), wrapH, wrapV)
    texture:SetHorizTile(piece.horizTile == true)
    texture:SetVertTile(piece.vertTile == true)
  else
    return false
  end
  if width ~= nil then
    pixel:Width(texture, width)
  end
  if height ~= nil then
    pixel:Height(texture, height)
  end
  local c = piece.texCoords or { 0, 1, 0, 1 }
  local left, right, top, bottom = c[1], c[2], c[3], c[4]
  local selfMirrored = piece.mirrorLayout
  if selfMirrored == nil then
    selfMirrored = layout.mirrorLayout
  end
  local flipH = (selfMirrored and setup.mirrorH) or false
  if mirrored then
    flipH = not flipH
  end
  if flipH then
    left, right = right, left
  end
  if selfMirrored and setup.mirrorV then
    top, bottom = bottom, top
  end
  texture:SetTexCoord(left, right, top, bottom)
  return true
end

-- place anchors a piece as Blizzard does, mirrored when the frame is: every point turned left for right, every
-- horizontal offset negated, and every piece it hangs from the mirror of its own.
---@private
function setProto:place(texture, setup, piece, layout, mirrored)
  local region = self.region
  local function point(p)
    return mirrored and MIRROR_POINT[p] or p
  end
  local function x(value)
    value = value or 0
    return mirrored and -value or value
  end
  local function slot(name)
    return self.pieces[mirrored and MIRROR_NAME[name] or name]
  end
  texture:ClearAllPoints()
  if setup.corner then
    pixel:Point(texture, point(piece.point or setup.point), region, point(piece.relativePoint or setup.point), x(piece.x),
      piece.y or 0)
  elseif setup.between ~= nil then
    if layout.threeSliceVertical or layout.threeSliceHorizontal then
      pixel:Point(texture, point(setup.point), region, point(setup.point), x(piece.x), piece.y or 0)
      pixel:Point(texture, point(setup.relativePoint), region, point(setup.relativePoint), x(piece.x1), piece.y1 or 0)
    else
      pixel:Point(texture, point(setup.point), slot(setup.between[1]), point(setup.relativePoint), x(piece.x), piece.y or 0)
      pixel:Point(texture, point(setup.relativePoint), slot(setup.between[2]), point(setup.point), x(piece.x1),
        piece.y1 or 0)
    end
  elseif layout.threeSliceVertical then
    pixel:Point(texture, point("TOPLEFT"), slot("TopEdge"), point("BOTTOMLEFT"), x(piece.x), piece.y or 0)
    pixel:Point(texture, point("BOTTOMRIGHT"), slot("BottomEdge"), point("TOPRIGHT"), x(piece.x1), piece.y1 or 0)
  elseif layout.threeSliceHorizontal then
    pixel:Point(texture, point("TOPLEFT"), slot("LeftEdge"), point("TOPRIGHT"), x(piece.x), piece.y or 0)
    pixel:Point(texture, point("BOTTOMRIGHT"), slot("RightEdge"), point("BOTTOMLEFT"), x(piece.x1), piece.y1 or 0)
  else
    pixel:Point(texture, point("TOPLEFT"), slot("TopLeftCorner"), point("BOTTOMRIGHT"), x(piece.x), piece.y or 0)
    pixel:Point(texture, point("BOTTOMRIGHT"), slot("BottomRightCorner"), point("TOPLEFT"), x(piece.x1), piece.y1 or 0)
  end
end
