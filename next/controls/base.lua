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

-- An edge: four lines inside a frame's border.
---@class (exact) NextEdge
---@field frame Frame
---@field Top Texture
---@field Bottom Texture
---@field Left Texture
---@field Right Texture
---@field label? FontString The text of its control, for the render recorder.

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
  self.edges[edge] = true
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
