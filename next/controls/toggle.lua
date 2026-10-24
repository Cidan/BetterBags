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
-- click flips it and calls back; a state given to it (SetChecked) calls nothing back.
---@class NextToggle: AceModule
---@field all NextToggleFrame[]
local nextToggle = addon:NewModule('NextToggle')

---@class (exact) NextToggleOptions
---@field checked? boolean
---@field onChange fun(ctx: Context, checked: boolean)

---@class NextToggleFrame
---@field frame Button
---@field off Texture The track while off.
---@field on Texture The track's on color, as strong as the switch is on.
---@field edge NextEdge
---@field knob Texture
---@field hover Texture
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
  local knob = frame:CreateTexture(nil, "ARTWORK")
  local checked = opts.checked == true
  ---@type NextToggleFrame
  local t = setmetatable({
    frame = frame, off = off, on = on, hover = hover, knob = knob, edge = controls:CreateEdge(frame),
    checked = checked, amount = checked and 1 or 0, onChange = opts.onChange,
  }, { __index = toggleProto })
  addon.SetScript(frame, "OnClick", function(ctx) t:Click(ctx) end)
  addon.SetScript(frame, "OnEnter", function() t:SetHovered(true) end)
  addon.SetScript(frame, "OnLeave", function() t:SetHovered(false) end)
  table.insert(self.all, t)
  sonataNext:RegisterWidget(self)
  t:Style()
  return t
end

-- Style sizes the switch and draws it at how far it is on.
function toggleProto:Style()
  local T = controls:Theme("Toggle")
  pixel:Size(self.frame, T.Width, T.Height)
  pixel:Size(self.knob, T.KnobSize, T.KnobSize)
  controls:Paint(self.off, T.Off)
  controls:PaintEdge(self.edge, T.Edge)
  controls:Paint(self.hover, T.Hover)
  self.hover:SetShown(self.hovered == true and self.frame:IsEnabled())
  self.frame:SetAlpha(self.frame:IsEnabled() and 1 or controls:Theme("Button").DisabledAlpha)
  self:Place(self.amount)
end

-- Place puts the knob amount of the way from the off end to the on end, the on color that strong. At
-- either end (at rest) the knob is on whole pixels, centered on the track's height by its top
-- (docs/next-pixel-perfect.md); sliding, it moves smoothly between them.
---@param amount number
function toggleProto:Place(amount)
  local T = controls:Theme("Toggle")
  self.amount = amount
  local frame, knob = self.frame, self.knob
  local inset = pixel:Snap(frame, T.KnobInset)
  local travel = frame:GetWidth() - 2 * inset - knob:GetWidth()
  knob:ClearAllPoints()
  knob:SetPoint("TOPLEFT", frame, "TOPLEFT", inset + travel * amount,
    -pixel:Middle(frame, frame:GetHeight(), knob:GetHeight()))
  controls:Paint(self.on, T.On, (T.On.Alpha or 1) * amount)
  controls:Paint(self.knob, amount >= 0.5 and T.KnobOn or T.Knob)
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
