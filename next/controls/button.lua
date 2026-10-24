local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextControls: AceModule
local controls = addon:GetModule('NextControls')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

-- NextButton is BetterBags Next's button (next-settings.md §2), drawn from the theme
-- (Controls.Button): Plain, Primary (the accent: Done, Apply), Danger (Delete) or Link (its text
-- alone). Its fill and edge light up under the pointer and when pressed; disabled, it is drawn at
-- DisabledAlpha and does nothing.
---@class NextButton: AceModule
---@field all NextButtonFrame[]
local nextButton = addon:NewModule('NextButton')

---@alias NextButtonStyle "Plain"|"Primary"|"Danger"|"Link"

---@class (exact) NextButtonOptions
---@field text string
---@field style? NextButtonStyle Plain when unset.
---@field width? number A fixed width; unset: as wide as the label and the padding.
---@field onClick fun(ctx: Context, mouse: string)
---@field tooltip? string|fun(): string

---@class NextButtonFrame
---@field frame Button
---@field fill Texture
---@field edge NextEdge
---@field label FontString
---@field style NextButtonStyle
---@field width? number
---@field hovered boolean
---@field pressed boolean
---@field onClick fun(ctx: Context, mouse: string)
---@field tooltip? string|fun(): string
local buttonProto = {}
addon:GetModule('Perf'):RegisterPrototype(buttonProto, 'NextButtonFrame')

nextButton.all = {}

-- ApplyStyle restyles every button made (SonataNext applied a theme).
---@param ctx? Context
function nextButton:ApplyStyle(ctx)
  local _ = ctx
  for _, b in ipairs(self.all) do
    b:Style()
  end
end

---@param parent Frame
---@param opts NextButtonOptions
---@return NextButtonFrame
function nextButton:Create(parent, opts)
  local frame = CreateFrame("Button", nil, parent)
  frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  frame:SetMotionScriptsWhileDisabled(true)
  local fill = frame:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints(frame)
  local label = frame:CreateFontString(nil, "OVERLAY")
  ---@type NextButtonFrame
  local b = setmetatable({
    frame = frame, fill = fill, edge = controls:CreateEdge(frame), label = label,
    style = opts.style or "Plain", width = opts.width, hovered = false, pressed = false,
    onClick = opts.onClick, tooltip = opts.tooltip,
  }, { __index = buttonProto })
  b.edge.label = label
  style:SetFont(label, self:Look(b.style).Font)
  label:SetText(opts.text)
  addon.SetScript(frame, "OnClick", function(ctx, _, mouse) b:Click(ctx, mouse) end)
  addon.SetScript(frame, "OnEnter", function() b:Enter() end)
  addon.SetScript(frame, "OnLeave", function() b:Leave() end)
  addon.SetScript(frame, "OnMouseDown", function() b:SetPressed(true) end)
  addon.SetScript(frame, "OnMouseUp", function() b:SetPressed(false) end)
  table.insert(self.all, b)
  sonataNext:RegisterWidget(self)
  b:Style()
  return b
end

-- Look returns a style's look in the current theme.
---@param name NextButtonStyle
---@return table
function nextButton:Look(name)
  return controls:Theme("Button")[name]
end

-- Style sizes the button to its label and draws it as it is.
function buttonProto:Style()
  local B, look = controls:Theme("Button"), nextButton:Look(self.style)
  style:SetFont(self.label, look.Font)
  pixel:Height(self.frame, B.Height)
  self:Fit()
  self.frame:SetAlpha(self.frame:IsEnabled() and 1 or B.DisabledAlpha)
  self:Paint()
end

-- Fit sizes the button to its label: a link is its text, a button its label and Padding either
-- side, at least MinWidth; a fixed width wins. All in whole pixels, its label centered in it by its top
-- left (docs/next-pixel-perfect.md): its width and font height rounded up and split, the odd pixel after.
function buttonProto:Fit()
  local B = controls:Theme("Button")
  local frame, label = self.frame, self.label
  local text = pixel:Ceil(frame, label:GetStringWidth())
  local width = self.width
  if width == nil then
    width = self.style == "Link" and text or math.max(pixel:Length(frame, B.MinWidth), text + 2 * pixel:Length(frame, B.Padding))
  end
  frame:SetWidth(pixel:Length(frame, width))
  label:ClearAllPoints()
  pixel:Row(label, "TOPLEFT", frame, pixel:Middle(frame, frame:GetWidth(), text), frame:GetHeight())
end

-- SetWidth gives the button a fixed width, or (nil) sizes it to its label again.
---@param width? number
function buttonProto:SetWidth(width)
  self.width = width
  self:Fit()
end

-- Paint draws the fill, edge and font for the button's state: pressed, under the pointer, or idle.
function buttonProto:Paint()
  local look = nextButton:Look(self.style)
  local lit = self.hovered and self.frame:IsEnabled()
  local fill = look.Fill
  if lit and self.pressed then
    fill = look.PressedFill
  elseif lit then
    fill = look.HoverFill
  end
  controls:Paint(self.fill, fill)
  controls:PaintEdge(self.edge, lit and look.HoverEdge or look.Edge)
  style:SetFont(self.label, (lit and look.HoverFont) or look.Font)
  -- The hover font can be another size: centered again.
  self:Fit()
end

---@param text string
function buttonProto:SetText(text)
  self.label:SetText(text)
  self:Fit()
end

---@param enabled boolean
function buttonProto:SetEnabled(enabled)
  self.frame:SetEnabled(enabled)
  self.frame:SetAlpha(enabled and 1 or controls:Theme("Button").DisabledAlpha)
  self:Paint()
end

---@param ctx Context
---@param mouse string
function buttonProto:Click(ctx, mouse)
  if not self.frame:IsEnabled() then
    return
  end
  self.onClick(ctx, mouse)
end

function buttonProto:Enter()
  self.hovered = true
  self:Paint()
  local tip = self.tooltip
  if type(tip) == "function" then
    tip = tip()
  end
  if tip then
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:SetText(tip, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end
end

function buttonProto:Leave()
  self.hovered = false
  self.pressed = false
  self:Paint()
  if self.tooltip then
    GameTooltip:Hide()
  end
end

---@param pressed boolean
function buttonProto:SetPressed(pressed)
  self.pressed = pressed
  self:Paint()
end
