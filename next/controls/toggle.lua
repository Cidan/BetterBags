local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextTween: AceModule
local tween = addon:GetModule('NextTween')

---@class NextControls: AceModule
local controls = addon:GetModule('NextControls')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

-- NextToggle is BetterBags Next's switch (next-settings.md §2), drawn from the theme
-- (Controls.Toggle): a track, colored as it turns on, and a knob that slides to the end it is at. A
-- click flips it and calls back; a state given to it (SetChecked) calls nothing back. Three styles (Style):
-- "Square", a track filling the switch with a square knob in it; "Round", a thinner track with round ends
-- and a round knob over it, overhanging it (asked: "the round peg that sits over a smaller track"); "Check",
-- a check box: its box (Off) with the mark (On) over it as it turns on, and its own art while disabled
-- (Disabled, DisabledOn), as GW2_UI's check boxes are drawn (docs/next-gw2-theme.md).
---@class NextToggle: AceModule
---@field all NextToggleFrame[]
local nextToggle = addon:NewModule('NextToggle')

---@class (exact) NextToggleOptions
---@field checked? boolean
---@field onChange fun(ctx: Context, checked: boolean)

---@class NextToggleFrame
---@field frame Button
---@field off Texture The track while off (between its round ends in the round style).
---@field on Texture The track's on color, as strong as the switch is on.
---@field offLeft Texture The round style's track ends, while off.
---@field offRight Texture
---@field onLeft Texture Its ends' on color.
---@field onRight Texture
---@field edge NextEdge
---@field knob Texture
---@field shadow Texture The round style's soft shadow under the knob.
---@field hover Texture
---@field round boolean Drawn in the round style.
---@field check boolean Drawn as a check box.
---@field share? number How much of the circle each round end shows across.
---@field checked boolean
---@field amount number How far it is on, from 0 to 1, as the knob slides.
---@field onChange fun(ctx: Context, checked: boolean)
local toggleProto = {}
addon:GetModule('Perf'):RegisterPrototype(toggleProto, 'NextToggleFrame')

nextToggle.all = {}

---@param ctx? Context
function nextToggle:ApplyStyle(ctx)
  local _ = ctx
  for _, t in ipairs(self.all) do
    t:Style()
  end
end

---@param parent Frame
---@param opts NextToggleOptions
---@return NextToggleFrame
function nextToggle:Create(parent, opts)
  local frame = CreateFrame("Button", nil, parent)
  frame:RegisterForClicks("LeftButtonUp")
  frame:SetMotionScriptsWhileDisabled(true)
  local off = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
  off:SetAllPoints(frame)
  local on = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
  on:SetAllPoints(frame)
  -- Not the HIGHLIGHT layer: the client shows that under the pointer by itself, disabled or not.
  local hover = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
  hover:SetAllPoints(frame)
  hover:Hide()
  -- The round style's track ends, under the on color's.
  local offLeft = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
  local offRight = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
  local onLeft = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
  local onRight = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
  local shadow = frame:CreateTexture(nil, "ARTWORK", nil, -1)
  local knob = frame:CreateTexture(nil, "ARTWORK")
  local checked = opts.checked == true
  ---@type NextToggleFrame
  local t = setmetatable({
    frame = frame, off = off, on = on, hover = hover, knob = knob, edge = controls:CreateEdge(frame),
    offLeft = offLeft, offRight = offRight, onLeft = onLeft, onRight = onRight, shadow = shadow,
    checked = checked, amount = checked and 1 or 0, onChange = opts.onChange, round = false,
  }, { __index = toggleProto })
  addon.SetScript(frame, "OnClick", function(ctx) t:Click(ctx) end)
  addon.SetScript(frame, "OnEnter", function() t:SetHovered(true) end)
  addon.SetScript(frame, "OnLeave", function() t:SetHovered(false) end)
  table.insert(self.all, t)
  sonataNext:RegisterWidget(self)
  t:Style()
  return t
end

-- circled returns a fill drawn as the Circle texture (the round style's knob, track ends and halo) unless it
-- names art of its own.
---@param fill table|string|false
---@return table|false
local function circled(fill)
  if not fill then
    return fill
  end
  local spec = type(fill) == "table" and fill or { Color = fill }
  if spec.Texture ~= nil or spec.Atlas ~= nil then
    return spec
  end
  local copy = { Texture = "Circle" }
  for k, v in pairs(spec) do
    copy[k] = v
  end
  return copy
end

-- Style sizes the switch and draws it in its style at how far it is on.
function toggleProto:Style()
  local T = controls:Theme("Toggle")
  self.round = T.Style == "Round"
  self.check = T.Style == "Check"
  if self.round then
    pixel:Size(self.frame, T.Width, math.max(T.Height, T.KnobSize))
  else
    pixel:Size(self.frame, T.Width, T.Height)
  end
  pixel:Size(self.knob, T.KnobSize, T.KnobSize)
  if self.round then
    self:styleRound(T)
  elseif self.check then
    self:styleCheck(T)
  else
    self:styleSquare(T)
  end
  self.hover:SetShown(self.hovered == true and self.frame:IsEnabled())
  -- A check box with disabled art shows itself disabled; anything else is dimmed.
  local ownArt = self.check and T.Disabled
  self.frame:SetAlpha((self.frame:IsEnabled() or ownArt) and 1 or controls:Theme("Button").DisabledAlpha)
  self:Place(self.amount)
end

-- styleCheck draws the check style: the box (its disabled art while disabled) and the hover fill the switch; the
-- mark over them is drawn as it turns on (Place). No knob, no edge.
---@private
---@param T table The theme's Controls.Toggle.
function toggleProto:styleCheck(T)
  local frame = self.frame
  for _, texture in ipairs({ self.off, self.on, self.hover }) do
    texture:ClearAllPoints()
    texture:SetAllPoints(frame)
  end
  for _, texture in ipairs({ self.offLeft, self.offRight, self.onLeft, self.onRight, self.shadow, self.knob }) do
    texture:Hide()
  end
  controls:Paint(self.off, (not frame:IsEnabled() and T.Disabled) or T.Off)
  controls:PaintEdge(self.edge, false)
  controls:Paint(self.hover, T.Hover)
end

-- styleSquare draws the square style: the track, its on color and the hover fill the switch, an edge round it.
---@private
---@param T table The theme's Controls.Toggle.
function toggleProto:styleSquare(T)
  local frame = self.frame
  for _, texture in ipairs({ self.off, self.on, self.hover }) do
    texture:ClearAllPoints()
    texture:SetAllPoints(frame)
  end
  for _, texture in ipairs({ self.offLeft, self.offRight, self.onLeft, self.onRight, self.shadow }) do
    texture:Hide()
  end
  controls:Paint(self.off, T.Off)
  controls:PaintEdge(self.edge, T.Edge)
  controls:Paint(self.hover, T.Hover)
end

-- styleRound draws the round style, in whole pixels (docs/next-pixel-perfect.md): the track TrackHeight tall,
-- centered on the switch's height, in from each end by half of what the knob is taller, so the knob's middle
-- is over the middle of either end at rest; each end half a circle, the halves cut on a whole pixel (an odd
-- pixel left to the middle); the halo and the shadow round the knob, following it.
---@private
---@param T table The theme's Controls.Toggle.
function toggleProto:styleRound(T)
  local frame = self.frame
  local unit = pixel:Unit(frame)
  local width, height = frame:GetWidth(), frame:GetHeight()
  local track = pixel:Length(frame, T.TrackHeight)
  local inset = pixel:Snap(frame, (T.KnobSize - T.TrackHeight) / 2)
  local top = pixel:Middle(frame, height, track)
  local pixels = pixel:Pixels(frame, track)
  local half = math.floor(pixels / 2)
  local cap, share = half * unit, half / pixels
  local function place(middle, left, right)
    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -top)
    left:SetSize(cap, track)
    right:ClearAllPoints()
    right:SetPoint("TOPLEFT", frame, "TOPLEFT", width - inset - cap, -top)
    right:SetSize(cap, track)
    middle:ClearAllPoints()
    middle:SetPoint("TOPLEFT", frame, "TOPLEFT", inset + cap, -top)
    middle:SetSize(math.max(0, width - 2 * (inset + cap)), track)
  end
  place(self.off, self.offLeft, self.offRight)
  place(self.on, self.onLeft, self.onRight)
  controls:Paint(self.off, T.Off)
  self.share = share
  controls:Paint(self.offLeft, circled(T.Off))
  controls:Paint(self.offRight, circled(T.Off))
  self.offLeft:SetTexCoord(0, share, 0, 1)
  self.offRight:SetTexCoord(1 - share, 1, 0, 1)
  controls:PaintEdge(self.edge, false)
  local spread = pixel:Snap(frame, T.HoverSpread or 0)
  local hover = self.hover
  hover:ClearAllPoints()
  hover:SetPoint("TOPLEFT", self.knob, "TOPLEFT", -spread, spread)
  hover:SetSize(self.knob:GetWidth() + 2 * spread, self.knob:GetHeight() + 2 * spread)
  controls:Paint(hover, circled(T.Hover))
  local S, shadow = T.KnobShadow, self.shadow
  if S then
    local reach = pixel:Snap(frame, S.Spread or 0)
    shadow:ClearAllPoints()
    shadow:SetPoint("TOPLEFT", self.knob, "TOPLEFT", -reach, reach)
    shadow:SetSize(self.knob:GetWidth() + 2 * reach, self.knob:GetHeight() + 2 * reach)
    controls:Paint(shadow, S)
  else
    shadow:Hide()
  end
end

-- Place puts the knob amount of the way from the off end to the on end, the on color that strong. At
-- either end (at rest) the knob is on whole pixels, centered on the track's height by its top
-- (docs/next-pixel-perfect.md); sliding, it moves smoothly between them. A round knob goes from end to end
-- of the switch, over the track's round ends.
---@param amount number
function toggleProto:Place(amount)
  local T = controls:Theme("Toggle")
  self.amount = amount
  local frame, knob = self.frame, self.knob
  if self.check then
    -- The mark, as strong as the box is on; tinted its own way while disabled.
    local mark = (not frame:IsEnabled() and T.DisabledOn) or T.On
    controls:Paint(self.on, mark, (mark.Alpha or 1) * amount)
    return
  end
  local inset = self.round and 0 or pixel:Snap(frame, T.KnobInset)
  local travel = frame:GetWidth() - 2 * inset - knob:GetWidth()
  knob:ClearAllPoints()
  knob:SetPoint("TOPLEFT", frame, "TOPLEFT", inset + travel * amount,
    -pixel:Middle(frame, frame:GetHeight(), knob:GetHeight()))
  local alpha = (T.On.Alpha or 1) * amount
  controls:Paint(self.on, T.On, alpha)
  local knobSpec = amount >= 0.5 and T.KnobOn or T.Knob
  if self.round then
    controls:Paint(self.onLeft, circled(T.On), alpha)
    controls:Paint(self.onRight, circled(T.On), alpha)
    self.onLeft:SetTexCoord(0, self.share, 0, 1)
    self.onRight:SetTexCoord(1 - self.share, 1, 0, 1)
    knobSpec = circled(knobSpec)
  end
  controls:Paint(self.knob, knobSpec)
end

---@return boolean
function toggleProto:GetChecked()
  return self.checked
end

-- SetChecked shows a state, at once or sliding (animate), calling nothing back. Told the state it is
-- already sliding to, it keeps sliding: a settings row shows its value again right after a click saved
-- it.
---@param checked boolean
---@param animate? boolean
function toggleProto:SetChecked(checked, animate)
  if not animate and (checked == true) == self.checked and tween:IsPlaying(self) then
    return
  end
  self.checked = checked == true
  local target = self.checked and 1 or 0
  if not animate then
    tween:Stop(self)
    self:Place(target)
    return
  end
  tween:Play(self, {
    duration = style.Time.Toggle,
    ease = style:Ease("Toggle"),
    from = self.amount,
    to = target,
    onUpdate = function(value) self:Place(value) end,
  })
end

-- Click flips the switch, sliding, and calls back with its new state.
---@param ctx Context
function toggleProto:Click(ctx)
  if not self.frame:IsEnabled() then
    return
  end
  self:SetChecked(not self.checked, true)
  self.onChange(ctx, self.checked)
end

---@param enabled boolean
function toggleProto:SetEnabled(enabled)
  self.frame:SetEnabled(enabled)
  self:Style()
end

---@param hovered boolean
function toggleProto:SetHovered(hovered)
  self.hovered = hovered
  self.hover:SetShown(hovered and self.frame:IsEnabled())
end
