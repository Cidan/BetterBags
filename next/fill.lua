local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

-- NextFill draws a fill as one piece, or as Blizzard draws its buttons, sliders, scroll bars and inputs: a begin
-- cap, a middle stretched between them and an end cap (next-themes.md §16). A fill wraps a texture a widget already
-- has: the texture stays the fill (the middle, when pieced), so the widget and its tests keep using it, and the fill
-- adds the caps beside it and anchors all of them inside its region, inset or reaching past it. NextControls:Paint
-- paints a wrapped texture through its fill. Asked for the Plain theme: "looks like the default UI for the version of
-- WoW we're playing on" (docs/next-plain-theme.md).
---@class NextFill: AceModule
local fills = addon:NewModule('NextFill')

-- Every wrapped texture's fill, held weakly.
fills.wrapped = setmetatable({}, { __mode = "k" }) ---@type table<Texture, NextFillSet>

---@class (exact) NextFillSet
---@field texture Texture The fill itself, its middle piece when pieced.
---@field region ScriptRegion What it fills.
---@field Begin? Texture The begin cap (left, or top), made the first time a pieced fill is drawn.
---@field End? Texture The end cap (right, or bottom).
local fillProto = {}
addon:GetModule('Perf'):RegisterPrototype(fillProto, 'NextFillSet')

-- Wrap makes texture a fill of region, drawn by Paint (NextControls:Paint finds it, Of).
---@param texture Texture
---@param region ScriptRegion
---@return NextFillSet
function fills:Wrap(texture, region)
  local fill = setmetatable({ texture = texture, region = region }, { __index = fillProto })
  self.wrapped[texture] = fill
  return fill
end

-- Of returns the fill texture is, or nil.
---@param texture Texture
---@return NextFillSet?
function fills:Of(texture)
  return self.wrapped[texture]
end

-- caps returns the fill's caps, made the first time, in the texture's layer, beside it.
---@private
---@return Texture begin, Texture finish
function fillProto:caps()
  if self.Begin == nil then
    local parent = self.texture:GetParent()
    local layer, subLevel = self.texture:GetDrawLayer()
    self.Begin = parent:CreateTexture(nil, layer, nil, subLevel)
    self.End = parent:CreateTexture(nil, layer, nil, subLevel)
  end
  return self.Begin, self.End
end

-- inset returns how far in from each side of its region the fill is (negative: past it), in whole pixels.
---@param texture Texture
---@param spec table
---@return number left, number right, number top, number bottom
local function inset(texture, spec)
  local i = spec.Inset or {}
  return pixel:Snap(texture, i.Left or 0), pixel:Snap(texture, i.Right or 0), pixel:Snap(texture, i.Top or 0),
    pixel:Snap(texture, i.Bottom or 0)
end

-- piece draws one piece of a pieced fill: its own art (Atlas, or Texture with TexCoords), else the fill's, tinted by
-- the fill's Color at alpha, tiled as its atlas says (C_Texture.GetAtlasInfo) or as told (HorizTile, VertTile). It
-- returns the piece's own size along the fill (Size, else its atlas's).
---@param texture Texture
---@param spec table The fill.
---@param own table The piece.
---@param alpha? number
---@param across boolean
---@return number?
local function piece(texture, spec, own, alpha, across)
  local art = { Color = spec.Color, BlendMode = spec.BlendMode, Desaturated = spec.Desaturated, TexCoords = own.TexCoords,
    HorizTile = own.HorizTile, VertTile = own.VertTile }
  if own.Atlas ~= nil then
    art.Atlas = own.Atlas
  elseif own.Texture ~= nil then
    art.Texture = own.Texture
  else
    art.Atlas, art.Texture = spec.Atlas, spec.Texture
  end
  style:Paint(texture, art, alpha or spec.Alpha)
  local size = own.Size
  if art.Atlas ~= nil then
    local info = C_Texture.GetAtlasInfo(art.Atlas)
    if info ~= nil then
      texture:SetHorizTile(info.tilesHorizontally == true)
      texture:SetVertTile(info.tilesVertically == true)
      size = size or (across and info.width or info.height)
    end
  end
  texture:Show()
  return size
end

-- Paint draws spec (false or nil: nothing): a color or texture spec filling the region (NextStyle:Paint), inset into
-- it (Inset: Left, Right, Top, Bottom; negative reaches past it); or pieced (Pieces = "Horizontal" or "Vertical"):
-- Begin, Middle and End, each its own Atlas or Texture with TexCoords (else the fill's), the caps Size long (else
-- their atlas's), all Thickness thick and centered (else the region's), tinted by the fill's Color and alpha.
---@param spec? table|false
---@param alpha? number
function fillProto:Paint(spec, alpha)
  local texture = self.texture
  if not spec then
    texture:Hide()
    if self.Begin ~= nil then
      self.Begin:Hide()
      self.End:Hide()
    end
    return
  end
  local left, right, top, bottom = inset(texture, spec)
  local region = self.region
  if spec.Pieces == nil then
    if self.Begin ~= nil then
      self.Begin:Hide()
      self.End:Hide()
    end
    style:Paint(texture, spec, alpha or spec.Alpha)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", region, "TOPLEFT", left, -top)
    texture:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", -right, bottom)
    texture:Show()
    return
  end
  if spec.Pieces ~= "Horizontal" and spec.Pieces ~= "Vertical" then
    error("a fill is pieced Horizontal or Vertical, not " .. tostring(spec.Pieces))
  end
  local across = spec.Pieces == "Horizontal"
  local begin, finish = self:caps()
  local beginSize = piece(begin, spec, spec.Begin or {}, alpha, across)
  local endSize = piece(finish, spec, spec.End or {}, alpha, across)
  piece(texture, spec, spec.Middle or {}, alpha, across)
  begin:ClearAllPoints()
  finish:ClearAllPoints()
  texture:ClearAllPoints()
  local thickness = spec.Thickness
  if across then
    if thickness ~= nil then
      -- Centered on the region's height inside its insets, as Blizzard anchors its caps by LEFT and RIGHT.
      local y = (bottom - top) / 2
      begin:SetPoint("LEFT", region, "LEFT", left, y)
      finish:SetPoint("RIGHT", region, "RIGHT", -right, y)
      pixel:Height(begin, thickness)
      pixel:Height(finish, thickness)
    else
      begin:SetPoint("TOPLEFT", region, "TOPLEFT", left, -top)
      begin:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", left, bottom)
      finish:SetPoint("TOPRIGHT", region, "TOPRIGHT", -right, -top)
      finish:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", -right, bottom)
    end
    pixel:Width(begin, beginSize or 0)
    pixel:Width(finish, endSize or 0)
    texture:SetPoint("TOPLEFT", begin, "TOPRIGHT", 0, 0)
    texture:SetPoint("BOTTOMRIGHT", finish, "BOTTOMLEFT", 0, 0)
  else
    if thickness ~= nil then
      local x = (left - right) / 2
      begin:SetPoint("TOP", region, "TOP", x, -top)
      finish:SetPoint("BOTTOM", region, "BOTTOM", x, bottom)
      pixel:Width(begin, thickness)
      pixel:Width(finish, thickness)
    else
      begin:SetPoint("TOPLEFT", region, "TOPLEFT", left, -top)
      begin:SetPoint("TOPRIGHT", region, "TOPRIGHT", -right, -top)
      finish:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", left, bottom)
      finish:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", -right, bottom)
    end
    pixel:Height(begin, beginSize or 0)
    pixel:Height(finish, endSize or 0)
    texture:SetPoint("TOPLEFT", begin, "BOTTOMLEFT", 0, 0)
    texture:SetPoint("BOTTOMRIGHT", finish, "TOPRIGHT", 0, 0)
  end
end
