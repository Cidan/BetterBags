local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

---@class NextFill: AceModule
local fills = addon:GetModule('NextFill')

-- NextControls is what every BetterBags Next control draws with (next-settings.md §2): fills and
-- edges read from the Next theme's Controls. A control is BetterBags' own, made of plain frames and
-- textures, and restyled on every theme.
---@class NextControls: AceModule
local controls = addon:NewModule('NextControls')

-- An edge: four lines inside a frame's border, and the rings outlining it (an edge spec's Outlines).
---@class (exact) NextEdge
---@field frame Frame
---@field Top Texture
---@field Bottom Texture
---@field Left Texture
---@field Right Texture
---@field outlines? NextOutlines
---@field label? FontString The text of its control, for the render recorder.

-- Outlines: rings of four lines round a frame (ElvUI's black lines inside and outside every edge outside its pixel
-- mode, General/Toolkit.lua, SetTemplate), each its outer side Offset outside the frame (inside for less than 0), Size
-- thick, in its Color at its Alpha. Their lines are owner's, in its layer; each ring is listed with the edges.
---@class (exact) NextOutlines
---@field owner Frame
---@field frame Frame
---@field layer DrawLayer
---@field subLevel? number
---@field rings NextEdge[]
---@field specs table[] The outlines placed.

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
-- the fill's. False or nil hides the texture. A texture wrapped as a NextFill is drawn by its fill: inset
-- or past its region, or in three pieces (next-themes.md §16).
---@param texture Texture
---@param fill? string|number[]|table|false
---@param alpha? number
function controls:Paint(texture, fill, alpha)
  local wrapped = fills:Of(texture)
  if wrapped ~= nil then
    wrapped:Paint(fill and specOf(fill), alpha)
    return
  end
  if not fill then
    texture:Hide()
    return
  end
  local spec = specOf(fill)
  style:Paint(texture, spec, alpha or spec.Alpha)
  texture:Show()
end

-- Every edge made, for the render recorder (render-recorder.md §2), held weakly.
controls.edges = setmetatable({}, { __mode = "k" }) ---@type table<NextEdge, boolean>

-- CreateEdge makes the four lines of an edge round frame, in layer (BORDER when unset); round around instead when
-- given, its lines still frame's (drawn among frame's own textures by their layers: a slider's thumb over its edge).
---@param frame Frame
---@param layer? DrawLayer
---@param subLevel? number
---@param around? Frame
---@return NextEdge
function controls:CreateEdge(frame, layer, subLevel, around)
  local edge = { frame = around or frame }
  for _, side in ipairs(SIDES) do
    edge[side] = frame:CreateTexture(nil, layer or "BORDER", nil, subLevel)
  end
  edge.outlines = self:CreateOutlines(frame, layer, subLevel, around)
  self.edges[edge] = true
  return edge
end

-- CreateOutlines makes a set of outlines round frame (round around when given), their lines frame's, in layer (BORDER
-- when unset). Its rings are made as outlines are placed.
---@param frame Frame
---@param layer? DrawLayer
---@param subLevel? number
---@param around? Frame
---@return NextOutlines
function controls:CreateOutlines(frame, layer, subLevel, around)
  return { owner = frame, frame = around or frame, layer = layer or "BORDER", subLevel = subLevel, rings = {}, specs = {} }
end

-- placeRing lays a ring's four lines round frame, its outer side out outside the frame (inside for less than 0), size
-- thick: the top and bottom lines across, the sides between them.
---@param ring NextEdge
---@param frame Frame
---@param out number
---@param size number
local function placeRing(ring, frame, out, size)
  ring.Top:ClearAllPoints()
  ring.Top:SetPoint("TOPLEFT", frame, "TOPLEFT", -out, out)
  ring.Top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", out, out)
  ring.Top:SetHeight(size)
  ring.Bottom:ClearAllPoints()
  ring.Bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -out, -out)
  ring.Bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", out, -out)
  ring.Bottom:SetHeight(size)
  ring.Left:ClearAllPoints()
  ring.Left:SetPoint("TOPLEFT", frame, "TOPLEFT", -out, out - size)
  ring.Left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -out, -out + size)
  ring.Left:SetWidth(size)
  ring.Right:ClearAllPoints()
  ring.Right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", out, out - size)
  ring.Right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", out, -out + size)
  ring.Right:SetWidth(size)
end

-- signedLength rounds a ring's offset as a length (NextPixel:Length): whole pixels, never fewer than one unless it is
-- none, its sign kept. Rounded as an offset it fell to nothing on a coarse grid, while its line kept its pixel, and the
-- rings fell on the edge's own row (found in review).
---@param frame Frame
---@param units number
---@return number
local function signedLength(frame, units)
  if units == 0 then
    return 0
  end
  local n = pixel:Length(frame, math.abs(units))
  return units < 0 and -n or n
end

-- EdgeDepth is how far in from a frame's sides an edge spec reaches, in whole pixels of its grid: its lines (Size) and
-- each ring inside it (a negative Offset), as PaintEdge rounds them, so what sits just inside an edge (a check box's
-- mark: KnobInset = "Edge") meets its innermost line on any grid. 0 for no edge.
---@param frame Frame
---@param spec? table|false
---@return number
function controls:EdgeDepth(frame, spec)
  if not spec then
    return 0
  end
  local depth = pixel:Length(frame, spec.Size or 1)
  for _, outline in ipairs(type(spec.Outlines) == "table" and spec.Outlines or {}) do
    local off = outline.Offset or 0
    if off < 0 then
      depth = math.max(depth, -signedLength(frame, off) + pixel:Length(frame, outline.Size or 1))
    end
  end
  return depth
end

-- PlaceOutlines lays a ring for each of outlines (a list of { Offset, Size, Color, Alpha }; nil or false: none) round
-- the set's frame, on whole pixels of its grid (docs/next-pixel-perfect.md; the offset rounded as a length), making the rings it lacks (hidden until
-- shown); rings past the list are hidden, the others keep whether they show. It returns the lines it made, so a part
-- that masks its lines (a panel's rounded corners) masks them too.
---@param set NextOutlines
---@param outlines? table[]|false
---@return Texture[]
function controls:PlaceOutlines(set, outlines)
  local list = type(outlines) == "table" and outlines or {}
  local made = {}
  set.specs = list
  for n, outline in ipairs(list) do
    local ring = set.rings[n]
    if ring == nil then
      ring = { frame = set.frame }
      for _, side in ipairs(SIDES) do
        local line = set.owner:CreateTexture(nil, set.layer, nil, set.subLevel)
        line:Hide()
        ring[side] = line
        table.insert(made, line)
      end
      set.rings[n] = ring
      self.edges[ring] = true
    end
    placeRing(ring, set.frame, signedLength(set.frame, outline.Offset or 0), pixel:Length(set.frame, outline.Size or 1))
  end
  for n = #list + 1, #set.rings do
    for _, side in ipairs(SIDES) do
      set.rings[n][side]:Hide()
    end
  end
  return made
end

-- ColorOutlines colors the rings placed, each in its Color (black unless given) at its Alpha times strength (1 when
-- unset: a part fading its edge fades them with it), keeping whether they show.
---@param set NextOutlines
---@param strength? number
function controls:ColorOutlines(set, strength)
  for n, outline in ipairs(set.specs) do
    local ring = set.rings[n]
    for _, side in ipairs(SIDES) do
      style:Paint(ring[side], { Color = outline.Color or "Black" }, (outline.Alpha or 1) * (strength or 1))
    end
  end
end

-- ShowOutlines shows the rings placed, or hides every ring.
---@param set NextOutlines
---@param shown boolean
function controls:ShowOutlines(set, shown)
  local count = #set.specs
  for n, ring in ipairs(set.rings) do
    for _, side in ipairs(SIDES) do
      ring[side]:SetShown(shown and n <= count)
    end
  end
end

-- PaintOutlines places, colors and shows outlines (PlaceOutlines, ColorOutlines, ShowOutlines): for a part whose edge
-- shows as it is painted.
---@param set NextOutlines
---@param outlines? table[]|false
---@param strength? number
function controls:PaintOutlines(set, outlines, strength)
  self:PlaceOutlines(set, outlines)
  self:ColorOutlines(set, strength)
  self:ShowOutlines(set, true)
end

-- PaintEdge draws an edge from its spec (Color, Alpha, Size: the lines' thickness; Outlines, rings round it,
-- PlaceOutlines), alpha replacing the spec's when given (an edge stronger under the pointer). False or nil hides it.
---@param edge NextEdge
---@param spec? table|false
---@param alpha? number
function controls:PaintEdge(edge, spec, alpha)
  if not spec then
    for _, side in ipairs(SIDES) do
      edge[side]:Hide()
    end
    self:PaintOutlines(edge.outlines, nil)
    return
  end
  -- Whole pixels thick on the frame's grid, never thinner than one (docs/next-pixel-perfect.md): from the
  -- frame's corners, so on whole pixels when the frame is.
  local frame = edge.frame
  local size = pixel:Length(frame, spec.Size or 1)
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
  -- Its outlines at their own alpha: a strength is the edge's (a field lit under the pointer), not theirs.
  self:PaintOutlines(edge.outlines, spec.Outlines)
end

-- Escape closes the innermost thing open: a menu, then a dialog, then the window. Each takes the
-- place of the one under it in UISpecialFrames while it is open (Blizzard's CloseSpecialWindows
-- hides every shown frame the list names; SetPropagateKeyboardInput, which would let a frame take
-- Escape itself, is protected). CloseSpecialWindows walks the list with pairs while it hides frames,
-- so a hide never changes the list: ReleaseEscape waits for the next frame.
controls.escape = {} ---@type Frame[] Bottom to top.

-- setSpecial names a frame in UISpecialFrames, once, or takes it out.
---@param name string
---@param on boolean
local function setSpecial(name, on)
  local list = UISpecialFrames
  for i = #list, 1, -1 do
    if list[i] == name then
      table.remove(list, i)
    end
  end
  if on then
    table.insert(list, name)
  end
end

-- PushEscape makes frame (a named frame, just shown) the one Escape closes, in place of the one under
-- it.
---@param frame Frame
function controls:PushEscape(frame)
  local stack = self.escape
  for i = #stack, 1, -1 do
    if stack[i] == frame then
      table.remove(stack, i)
    end
  end
  local under = stack[#stack]
  if under ~= nil then
    setSpecial(under:GetName(), false)
  end
  table.insert(stack, frame)
  setSpecial(frame:GetName(), true)
end

-- ReleaseEscape, from frame's OnHide, gives Escape back to the frame under it on the next frame,
-- unless frame was shown again by then.
---@param frame Frame
function controls:ReleaseEscape(frame)
  C_Timer.After(0, function()
    if frame:IsShown() then
      return
    end
    local stack = self.escape
    for i = #stack, 1, -1 do
      if stack[i] == frame then
        table.remove(stack, i)
      end
    end
    setSpecial(frame:GetName(), false)
    local top = stack[#stack]
    if top ~= nil and top:IsShown() then
      setSpecial(top:GetName(), true)
    end
  end)
end

-- Theme returns the current theme's spec of a control (Controls[name]).
---@param name string
---@return table
function controls:Theme(name)
  return style.Theme.Controls[name]
end
