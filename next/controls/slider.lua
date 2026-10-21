local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextControls: AceModule
local controls = addon:GetModule('NextControls')

---@class NextInput: AceModule
local nextInput = addon:GetModule('NextInput')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- NextSlider is BetterBags Next's slider (next-settings.md §2), drawn from the theme
-- (Controls.Slider): a track filled up to a thumb, pressed or dragged with the left button, and a
-- number box after it to type a value; every value snapped to the step and kept in range. A change
-- the player makes calls back once per value; a value given (SetValue) calls nothing back. The
-- wheel is left to the page around it.
---@class NextSlider: AceModule
---@field all NextSliderFrame[]
local nextSlider = addon:NewModule('NextSlider')

---@class (exact) NextSliderOptions
---@field min number
---@field max number
---@field step number
---@field value number
---@field onChange fun(ctx: Context, value: number)

---@class NextSliderFrame
---@field frame Frame
---@field track Button The pressed and dragged area.
---@field bar Texture The empty track.
---@field fill Texture The track up to the thumb.
---@field thumb Texture
---@field value NextInputFrame
---@field current number
---@field hovered boolean
---@field dragging boolean
---@field opts NextSliderOptions
local sliderProto = {}
addon:GetModule('Perf'):RegisterPrototype(sliderProto, 'NextSliderFrame')

nextSlider.all = {}

---@param ctx? Context
function nextSlider:ApplyStyle(ctx)
  local _ = ctx
  for _, s in ipairs(self.all) do
    s:Style()
  end
end

---@param parent Frame
---@param opts NextSliderOptions
---@return NextSliderFrame
function nextSlider:Create(parent, opts)
  local frame = CreateFrame("Frame", nil, parent)
  local track = CreateFrame("Button", nil, frame)
  track:SetPoint("LEFT", frame, "LEFT", 0, 0)
  local bar = track:CreateTexture(nil, "BACKGROUND")
  local fill = track:CreateTexture(nil, "ARTWORK")
  local thumb = track:CreateTexture(nil, "OVERLAY")
  ---@type NextSliderFrame
  local s = setmetatable({
    frame = frame, track = track, bar = bar, fill = fill, thumb = thumb, hovered = false, dragging = false,
    current = opts.value, opts = opts,
  }, { __index = sliderProto })
  s.value = nextInput:Create(frame, {
    numeric = opts.min >= 0 and opts.step >= 1,
    onEnter = function(ctx, text) s:Type(ctx, text) end,
  })
  addon.SetScript(track, "OnMouseDown", function(ctx, _, button) s:Press(ctx, button) end)
  addon.SetScript(track, "OnEnter", function() s:SetHovered(true) end)
  addon.SetScript(track, "OnLeave", function() s:SetHovered(false) end)
  table.insert(self.all, s)
  sonataNext:RegisterWidget(self)
  s:Style()
  s:SetValue(opts.value)
  return s
end

function sliderProto:Style()
  local S = controls:Theme("Slider")
  local input = controls:Theme("Input")
  self.frame:SetSize(S.Width + S.ValueGap + S.ValueWidth, math.max(S.Height, input.Height))
  self.track:SetSize(S.Width, S.Height)
  self.bar:ClearAllPoints()
  self.bar:SetPoint("LEFT", self.track, "LEFT", 0, 0)
  self.bar:SetPoint("RIGHT", self.track, "RIGHT", 0, 0)
  self.bar:SetHeight(S.TrackSize)
  self.fill:SetHeight(S.TrackSize)
  self.thumb:SetSize(S.ThumbSize, S.ThumbSize)
  controls:Paint(self.bar, S.Track)
  controls:Paint(self.fill, S.Fill)
  local box = self.value.frame
  box:SetWidth(S.ValueWidth)
  box:ClearAllPoints()
  box:SetPoint("LEFT", self.track, "RIGHT", S.ValueGap, 0)
  self:Place()
end

-- snap returns value on its step from min, kept in range.
---@param value number
---@return number
function sliderProto:snap(value)
  local o = self.opts
  local snapped = o.min + math.floor((value - o.min) / o.step + 0.5) * o.step
  return math.max(o.min, math.min(o.max, snapped))
end

-- Place puts the thumb at the value, the fill up to its middle, and the value in the box.
function sliderProto:Place()
  local S = controls:Theme("Slider")
  local o = self.opts
  local share = o.max > o.min and (self.current - o.min) / (o.max - o.min) or 0
  local x = (S.Width - S.ThumbSize) * share
  self.thumb:ClearAllPoints()
  self.thumb:SetPoint("LEFT", self.track, "LEFT", x, 0)
  self.fill:ClearAllPoints()
  self.fill:SetPoint("LEFT", self.track, "LEFT", 0, 0)
  self.fill:SetWidth(math.max(1, x + S.ThumbSize / 2))
  controls:Paint(self.thumb, (self.hovered or self.dragging) and S.ThumbHover or S.Thumb)
  self.value:SetText(self:Format(self.current))
end

-- Format writes a value as the box shows it: whole for a whole step, else to two places.
---@param value number
---@return string
function sliderProto:Format(value)
  if self.opts.step >= 1 and math.floor(value) == value then
    return tostring(value)
  end
  return string.format("%.2f", value)
end

---@return number
function sliderProto:GetValue()
  return self.current
end

-- SetValue shows a value, snapped and kept in range, calling nothing back.
---@param value number
function sliderProto:SetValue(value)
  self.current = self:snap(value)
  self:Place()
end

-- change takes a value the player chose and calls back when it moved.
---@param ctx Context
---@param value number
function sliderProto:change(ctx, value)
  local snapped = self:snap(value)
  if snapped == self.current then
    self:Place()
    return
  end
  self.current = snapped
  self:Place()
  self.opts.onChange(ctx, snapped)
end

-- cursorValue returns the value under the pointer: the thumb's middle there.
---@return number?
function sliderProto:cursorValue()
  local left = self.track:GetLeft()
  if left == nil then
    return nil
  end
  local S = controls:Theme("Slider")
  local x = GetCursorPosition() / self.track:GetEffectiveScale() - left
  local share = (x - S.ThumbSize / 2) / (S.Width - S.ThumbSize)
  local o = self.opts
  return o.min + share * (o.max - o.min)
end

-- Press jumps to the pointer and follows it until the left button is let go.
---@param ctx Context
---@param button string
function sliderProto:Press(ctx, button)
  if button ~= "LeftButton" or not self.track:IsEnabled() then
    return
  end
  local value = self:cursorValue()
  if value == nil then
    return
  end
  self.dragging = true
  self:change(ctx, value)
  addon.SetScript(self.track, "OnUpdate", function(uctx) self:Follow(uctx) end)
end

---@param ctx Context
function sliderProto:Follow(ctx)
  if not IsMouseButtonDown("LeftButton") then
    self.dragging = false
    self.track:SetScript("OnUpdate", nil)
    self:Place()
    return
  end
  local value = self:cursorValue()
  if value ~= nil then
    self:change(ctx, value)
  end
end

-- Type takes a value typed in the box; one it cannot read puts the value back.
---@param ctx Context
---@param text string
function sliderProto:Type(ctx, text)
  local value = tonumber(text)
  if value == nil then
    self:Place()
    return
  end
  self:change(ctx, value)
end

-- SetEnabled takes or refuses the pointer and the box, drawn at DisabledAlpha while refusing.
---@param enabled boolean
function sliderProto:SetEnabled(enabled)
  self.track:SetEnabled(enabled)
  self.value:SetEnabled(enabled)
  self.frame:SetAlpha(enabled and 1 or controls:Theme("Button").DisabledAlpha)
end

---@param hovered boolean
function sliderProto:SetHovered(hovered)
  self.hovered = hovered
  self:Place()
end
