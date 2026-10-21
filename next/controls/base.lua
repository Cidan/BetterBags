local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

-- NextControls is what every BetterBags Next control draws with (next-settings.md §2): fills and
-- edges read from the Next theme's Controls. A control is BetterBags' own, made of plain frames and
-- textures, and restyled on every theme.
---@class NextControls: AceModule
local controls = addon:NewModule('NextControls')

-- An edge: four lines inside a frame's border.
---@class (exact) NextEdge
---@field frame Frame
---@field Top Texture
---@field Bottom Texture
---@field Left Texture
---@field Right Texture

local SIDES = { "Top", "Bottom", "Left", "Right" }

-- specOf turns a fill into a texture spec: a palette color's name or a color given outright becomes
-- that color.
---@param fill string|number[]|table
---@return table
local function specOf(fill)
  if type(fill) == "string" or (type(fill) == "table" and fill[1] ~= nil) then
    return { Color = fill }
  end
  return fill
end

-- Paint draws a fill on a texture and shows it: a texture spec (Color and Alpha; or a Texture or
-- Atlas tinted by Color, NextStyle:Paint), a palette color, or a color. alpha, when given, replaces
-- the fill's. False or nil hides the texture.
---@param texture Texture
---@param fill? string|number[]|table|false
---@param alpha? number
function controls:Paint(texture, fill, alpha)
  if not fill then
    texture:Hide()
    return
  end
  local spec = specOf(fill)
  style:Paint(texture, spec, alpha or spec.Alpha)
  texture:Show()
end

-- CreateEdge makes the four lines of an edge round frame, in layer (BORDER when unset).
---@param frame Frame
---@param layer? DrawLayer
---@param subLevel? number
---@return NextEdge
function controls:CreateEdge(frame, layer, subLevel)
  local edge = { frame = frame }
  for _, side in ipairs(SIDES) do
    edge[side] = frame:CreateTexture(nil, layer or "BORDER", nil, subLevel)
  end
  return edge
end

-- PaintEdge draws an edge from its spec (Color, Alpha, Size: the lines' thickness), alpha replacing
-- the spec's when given (an edge stronger under the pointer). False or nil hides it.
---@param edge NextEdge
---@param spec? table|false
---@param alpha? number
function controls:PaintEdge(edge, spec, alpha)
  if not spec then
    for _, side in ipairs(SIDES) do
      edge[side]:Hide()
    end
    return
  end
  local frame, size = edge.frame, spec.Size or 1
  local top, bottom, left, right = edge.Top, edge.Bottom, edge.Left, edge.Right
  top:ClearAllPoints()
  top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  top:SetHeight(size)
  bottom:ClearAllPoints()
  bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  bottom:SetHeight(size)
  left:ClearAllPoints()
  left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -size)
  left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, size)
  left:SetWidth(size)
  right:ClearAllPoints()
  right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -size)
  right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, size)
  right:SetWidth(size)
  local color = { Color = spec.Color }
  for _, side in ipairs(SIDES) do
    self:Paint(edge[side], color, alpha or spec.Alpha)
  end
end

-- Theme returns the current theme's spec of a control (Controls[name]).
---@param name string
---@return table
function controls:Theme(name)
  return style.Theme.Controls[name]
end
