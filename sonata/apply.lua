local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- SonataApply turns the small specs themes are written in (colors, fonts, textures, anchors,
-- button states) into widget calls. Window decorations and element styles share them.
---@class SonataApply: AceModule
local apply = addon:NewModule('SonataApply')

---@class SonataColor: number[] { r, g, b, a? }

---@class SonataFont
---@field Object? string A font object: BetterBags' own (Fonts module) first, then a global one.
---@field Path? string A font file, with Size and Flags.
---@field Size? number
---@field Flags? string
---@field Color? SonataColor
---@field Shadow? {Color?: SonataColor, X?: number, Y?: number}
---@field Justify? "LEFT"|"CENTER"|"RIGHT"

---@class SonataTexture
---@field Texture? string|number A texture file or file ID.
---@field Atlas? string
---@field Color? SonataColor A solid color texture.
---@field Layer? DrawLayer
---@field SubLevel? number
---@field SliceMode? "Stretched"|"Tiled"
---@field SliceMargins? {Left: number, Top: number, Right: number, Bottom: number}
---@field TexCoords? number[] { left, right, top, bottom }
---@field VertexColor? SonataColor
---@field BlendMode? BlendMode
---@field Desaturated? boolean
---@field HorizTile? boolean
---@field VertTile? boolean
---@field Alpha? number

---@class SonataPoint
---@field Point FramePoint
---@field RelativeTo? string What the point is relative to; the default is the owner frame.
---@field RelativePoint? FramePoint The default is Point.
---@field X? number
---@field Y? number

-- Color reads a color as a list { r, g, b, a? } or keyed { r =, g =, b =, a? }.
---@param color? SonataColor|{r: number, g: number, b: number, a?: number}
---@param fallback? SonataColor
---@return number r, number g, number b, number a
function apply:Color(color, fallback)
  local c = color or fallback or { 1, 1, 1, 1 }
  if c.r ~= nil then
    return c.r, c.g or 1, c.b or 1, c.a or 1
  end
  return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
end

-- FontObject returns a font object: one given as an object, or one of BetterBags' (core/fonts.lua)
-- or the client's by name.
---@param name string|FontObject
---@return FontObject
function apply:FontObject(name)
  if type(name) == "table" then
    return name
  end
  local fonts = addon:GetModule('Fonts', true)
  local object = fonts and fonts[name]
  if type(object) ~= "table" then
    object = _G[name]
  end
  if object == nil then
    error("unknown font object: " .. tostring(name))
  end
  return object
end

-- Font applies spec to a font string or edit box: the font object first (with its color and
-- shadow, so nothing set by an earlier style stays), then a font file, then the color, shadow
-- and justification the spec sets.
---@param fontString FontString|EditBox
---@param spec? SonataFont
function apply:Font(fontString, spec)
  if type(spec) ~= "table" then
    return
  end
  if spec.Object ~= nil then
    local object = self:FontObject(spec.Object)
    fontString:SetFontObject(object)
    if object.GetTextColor ~= nil then
      fontString:SetTextColor(object:GetTextColor())
      fontString:SetShadowColor(object:GetShadowColor())
      fontString:SetShadowOffset(object:GetShadowOffset())
    end
  end
  if spec.Path ~= nil then
    fontString:SetFont(spec.Path, spec.Size or 12, spec.Flags or "")
  end
  if spec.Color ~= nil then
    fontString:SetTextColor(self:Color(spec.Color))
  end
  if spec.Shadow ~= nil then
    fontString:SetShadowColor(self:Color(spec.Shadow.Color, { 0, 0, 0, 1 }))
    fontString:SetShadowOffset(spec.Shadow.X or 1, spec.Shadow.Y or -1)
  end
  if spec.Justify ~= nil then
    fontString:SetJustifyH(spec.Justify)
  end
end

-- Texture applies spec to texture. The texture is reset first, then given its file, atlas or
-- color, then whatever else the spec sets, so a reused texture keeps nothing of what it drew
-- before and an atlas keeps the texture coordinates, tiling and slicing it brings.
---@param texture Texture
---@param spec SonataTexture
function apply:Texture(texture, spec)
  local layer = spec.Layer
  if layer == nil then
    layer = texture:GetDrawLayer()
  end
  texture:SetDrawLayer(layer, spec.SubLevel or 0)
  texture:ClearTextureSlice()
  texture:SetTexCoord(0, 1, 0, 1)
  texture:SetHorizTile(false)
  texture:SetVertTile(false)
  texture:SetVertexColor(1, 1, 1, 1)
  texture:SetBlendMode("BLEND")
  texture:SetDesaturated(false)
  texture:SetAlpha(1)

  if spec.Atlas ~= nil then
    texture:SetAtlas(spec.Atlas, spec.UseAtlasSize == true)
  elseif spec.Color ~= nil then
    texture:SetColorTexture(self:Color(spec.Color))
  else
    texture:SetTexture(spec.Texture)
  end

  if spec.SliceMargins ~= nil then
    local m = spec.SliceMargins
    texture:SetTextureSliceMargins(m.Left or 0, m.Top or 0, m.Right or 0, m.Bottom or 0)
    texture:SetTextureSliceMode(Enum.UITextureSliceMode[spec.SliceMode or "Stretched"])
  end
  local coords = spec.TexCoords
  if coords ~= nil then
    texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
  end
  if spec.HorizTile ~= nil then
    texture:SetHorizTile(spec.HorizTile)
  end
  if spec.VertTile ~= nil then
    texture:SetVertTile(spec.VertTile)
  end
  if spec.VertexColor ~= nil then
    texture:SetVertexColor(self:Color(spec.VertexColor))
  end
  if spec.BlendMode ~= nil then
    texture:SetBlendMode(spec.BlendMode)
  end
  if spec.Desaturated ~= nil then
    texture:SetDesaturated(spec.Desaturated)
  end
  if spec.Alpha ~= nil then
    texture:SetAlpha(spec.Alpha)
  end
end

-- ResetTexture returns a texture to blank, for reuse.
---@param texture Texture
function apply:ResetTexture(texture)
  texture:Hide()
  texture:ClearAllPoints()
  texture:SetSize(0, 0)
  texture:SetTexture(nil)
  texture:ClearTextureSlice()
  texture:SetTexCoord(0, 1, 0, 1)
  texture:SetHorizTile(false)
  texture:SetVertTile(false)
  texture:SetVertexColor(1, 1, 1, 1)
  texture:SetBlendMode("BLEND")
  texture:SetDesaturated(false)
  texture:SetAlpha(1)
end

-- Points anchors region by points. resolve turns a RelativeTo name into a region; points
-- without one are relative to owner.
---@param region Region
---@param points SonataPoint[]
---@param owner Region
---@param resolve? fun(name: string): Region?
function apply:Points(region, points, owner, resolve)
  region:ClearAllPoints()
  for _, p in ipairs(points) do
    local relativeTo = owner
    if p.RelativeTo ~= nil then
      relativeTo = resolve and resolve(p.RelativeTo)
      if relativeTo == nil then
        error("unknown anchor target: " .. tostring(p.RelativeTo))
      end
    end
    region:SetPoint(p.Point, relativeTo, p.RelativePoint or p.Point, p.X or 0, p.Y or 0)
  end
end

-- Inset anchors region to fill owner, inset on each side.
---@param region Region
---@param owner Region
---@param inset? {Left?: number, Right?: number, Top?: number, Bottom?: number}
function apply:Inset(region, owner, inset)
  local i = inset or {}
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", owner, "TOPLEFT", i.Left or 0, -(i.Top or 0))
  region:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -(i.Right or 0), i.Bottom or 0)
end

local STATES = {
  { key = "Normal", setTexture = "SetNormalTexture", setAtlas = "SetNormalAtlas", get = "GetNormalTexture", clear = "ClearNormalTexture" },
  { key = "Highlight", setTexture = "SetHighlightTexture", setAtlas = "SetHighlightAtlas", get = "GetHighlightTexture", clear = "ClearHighlightTexture" },
  { key = "Pushed", setTexture = "SetPushedTexture", setAtlas = "SetPushedAtlas", get = "GetPushedTexture", clear = "ClearPushedTexture" },
  { key = "Disabled", setTexture = "SetDisabledTexture", setAtlas = "SetDisabledAtlas", get = "GetDisabledTexture", clear = "ClearDisabledTexture" },
}

-- ButtonStates applies spec.Normal, spec.Highlight, spec.Pushed and spec.Disabled to a
-- button's state textures. A state given a file, atlas or color draws it; a state with only a
-- tint, coordinates, blend mode, inset or alpha changes the art the button has; false clears
-- the state; a state left out keeps what the button has.
---@param button Button
---@param spec table<string, SonataTexture|false|nil>
function apply:ButtonStates(button, spec)
  for _, state in ipairs(STATES) do
    local s = spec[state.key]
    if s == false then
      button[state.clear](button)
    elseif type(s) == "table" then
      local art = s.Atlas ~= nil or s.Color ~= nil or s.Texture ~= nil
      if s.Atlas ~= nil then
        button[state.setAtlas](button, s.Atlas)
      elseif s.Color ~= nil then
        button[state.setTexture](button, "Interface\\Buttons\\WHITE8X8")
      elseif s.Texture ~= nil then
        button[state.setTexture](button, s.Texture)
      end
      local region = button[state.get](button)
      if region ~= nil and art then
        if s.Atlas == nil then
          region:SetTexCoord(0, 1, 0, 1)
        end
        region:SetVertexColor(1, 1, 1, 1)
        region:SetAlpha(1)
        region:ClearAllPoints()
        region:SetAllPoints(button)
      end
      if region ~= nil then
        local coords = s.TexCoords
        if coords ~= nil then
          region:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        end
        if s.Color ~= nil then
          region:SetVertexColor(self:Color(s.Color))
        elseif s.VertexColor ~= nil then
          region:SetVertexColor(self:Color(s.VertexColor))
        end
        if s.BlendMode ~= nil then
          region:SetBlendMode(s.BlendMode)
        end
        if s.Inset ~= nil then
          self:Inset(region, button, s.Inset)
        end
        if s.Alpha ~= nil then
          region:SetAlpha(s.Alpha)
        end
      end
    end
  end
end
