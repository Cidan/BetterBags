local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextControls: AceModule
local controls = addon:GetModule('NextControls')

---@class NextScrollBar: AceModule
local nextScrollBar = addon:GetModule('NextScrollBar')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- NextInput is BetterBags Next's text field and text area (next-settings.md §2), drawn from the theme
-- (Controls.Input): a fill (lighter while focused) and an edge (stronger under the pointer and while
-- focused), the text Padding in, help text while empty. Only what the player types is reported
-- (onChange); Enter reports the text (onEnter) and lets go of focus, Escape puts back the text the
-- field had when it was focused.
---@class NextInput: AceModule
---@field all (NextInputFrame|NextTextAreaFrame)[]
local nextInput = addon:NewModule('NextInput')

-- A field's width when none is given.
local DEFAULT_WIDTH = 200

---@class (exact) NextInputOptions
---@field text? string
---@field help? string Shown while it is empty and not focused.
---@field width? number
---@field numeric? boolean Digits only (EditBox:SetNumeric).
---@field maxLetters? number
---@field onChange? fun(ctx: Context, text: string, userInput: boolean)
---@field onEnter? fun(ctx: Context, text: string)

---@class NextInputFrame
---@field frame EditBox
---@field fill Texture
---@field edge NextEdge
---@field help FontString
---@field hovered boolean
---@field focusText string The text it had when focused, put back by Escape.
---@field opts NextInputOptions
local inputProto = {}
addon:GetModule('Perf'):RegisterPrototype(inputProto, 'NextInputFrame')

---@class (exact) NextTextAreaOptions
---@field height number
---@field help? string
---@field onChange? fun(ctx: Context, text: string, userInput: boolean)

---@class NextTextAreaFrame
---@field frame Frame
---@field fill Texture
---@field edge NextEdge
---@field box WowScrollBox
---@field bar NextScrollBarFrame
---@field editBox EditBox
---@field help FontString
---@field opts NextTextAreaOptions
local areaProto = {}
addon:GetModule('Perf'):RegisterPrototype(areaProto, 'NextTextAreaFrame')

nextInput.all = {}

---@param ctx? Context
function nextInput:ApplyStyle(ctx)
  local _ = ctx
  for _, f in ipairs(self.all) do
    f:Style()
  end
end

---@param parent Frame
---@param opts? NextInputOptions
---@return NextInputFrame
function nextInput:Create(parent, opts)
  opts = opts or {}
  local frame = CreateFrame("EditBox", nil, parent)
  frame:SetAutoFocus(false)
  frame:SetWidth(opts.width or DEFAULT_WIDTH)
  if opts.numeric then
    frame:SetNumeric(true)
  end
  if opts.maxLetters then
    frame:SetMaxLetters(opts.maxLetters)
  end
  local fill = frame:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints(frame)
  local help = frame:CreateFontString(nil, "ARTWORK")
  ---@type NextInputFrame
  local f = setmetatable({
    frame = frame, fill = fill, edge = controls:CreateEdge(frame), help = help, hovered = false,
    focusText = "", opts = opts,
  }, { __index = inputProto })
  style:SetFont(frame, controls:Theme("Input").Font)
  style:SetFont(help, controls:Theme("Input").HelpFont)
  help:SetText(opts.help or "")
  frame:SetText(opts.text or "")
  addon.SetScript(frame, "OnEnter", function() f:SetHovered(true) end)
  addon.SetScript(frame, "OnLeave", function() f:SetHovered(false) end)
  addon.SetScript(frame, "OnEditFocusGained", function() f:OnFocus(true) end)
  addon.SetScript(frame, "OnEditFocusLost", function() f:OnFocus(false) end)
  addon.SetScript(frame, "OnEscapePressed", function() f:Cancel() end)
  addon.SetScript(frame, "OnEnterPressed", function(ctx) f:Commit(ctx) end)
  addon.SetScript(frame, "OnTextChanged", function(ctx, _, userInput) f:OnTextChanged(ctx, userInput) end)
  table.insert(self.all, f)
  sonataNext:RegisterWidget(self)
  f:Style()
  return f
end

function inputProto:Style()
  local I = controls:Theme("Input")
  local frame = self.frame
  frame:SetHeight(I.Height)
  frame:SetTextInsets(I.Padding, I.Padding, 0, 0)
  style:SetFont(frame, I.Font)
  style:SetFont(self.help, I.HelpFont)
  self.help:ClearAllPoints()
  self.help:SetPoint("LEFT", frame, "LEFT", I.Padding, 0)
  self.help:SetPoint("RIGHT", frame, "RIGHT", -I.Padding, 0)
  self.help:SetJustifyH("LEFT")
  self.help:SetWordWrap(false)
  frame:SetAlpha(frame:IsEnabled() and 1 or controls:Theme("Button").DisabledAlpha)
  self:Paint()
end

-- Paint draws the fill and edge for the field's state, and shows the help while it is empty and not
-- focused.
function inputProto:Paint()
  local I = controls:Theme("Input")
  local focused = self.frame:HasFocus()
  controls:Paint(self.fill, focused and I.FocusFill or I.Fill)
  local strength = I.Edge.Idle
  if focused then
    strength = I.Edge.Focus
  elseif self.hovered then
    strength = I.Edge.Hover
  end
  controls:PaintEdge(self.edge, I.Edge, strength)
  self.help:SetShown(not focused and (self.frame:GetText() or "") == "")
end

---@return string
function inputProto:GetText()
  return self.frame:GetText() or ""
end

-- SetText shows a text set from code: nothing is reported.
---@param text string
function inputProto:SetText(text)
  self.frame:SetText(text or "")
  self:Paint()
end

function inputProto:SetFocus()
  self.frame:SetFocus()
  self:OnFocus(true)
end

---@param enabled boolean
function inputProto:SetEnabled(enabled)
  self.frame:SetEnabled(enabled)
  if not enabled then
    self.frame:ClearFocus()
  end
  self.frame:SetAlpha(enabled and 1 or controls:Theme("Button").DisabledAlpha)
  self:Paint()
end

---@param hovered boolean
function inputProto:SetHovered(hovered)
  self.hovered = hovered
  self:Paint()
end

---@param focused boolean
function inputProto:OnFocus(focused)
  if focused then
    self.focusText = self:GetText()
  end
  self:Paint()
end

-- Cancel puts back the text the field had when it was focused, and lets go of focus.
function inputProto:Cancel()
  self.frame:SetText(self.focusText)
  self.frame:ClearFocus()
  self:Paint()
end

-- Commit reports the text and lets go of focus.
---@param ctx Context
function inputProto:Commit(ctx)
  local text = self:GetText()
  self.focusText = text
  self.frame:ClearFocus()
  self:Paint()
  if self.opts.onEnter then
    self.opts.onEnter(ctx, text)
  end
end

---@param ctx Context
---@param userInput boolean
function inputProto:OnTextChanged(ctx, userInput)
  self:Paint()
  if userInput and self.opts.onChange then
    self.opts.onChange(ctx, self:GetText(), true)
  end
end

-- CreateArea makes a text area: a multi-line edit box scrolling in a Blizzard scroll box with
-- BetterBags Next's scroll bar, opts.height tall, as wide as its anchors make it. A click anywhere in
-- it focuses the text; it takes the wheel only while focused, so the page around it scrolls.
---@param parent Frame
---@param opts NextTextAreaOptions
---@return NextTextAreaFrame
function nextInput:CreateArea(parent, opts)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetHeight(opts.height)
  local fill = frame:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints(frame)
  local box = CreateFrame("Frame", nil, frame, "WowScrollBox") --[[@as WowScrollBox]]
  box:SetInterpolateScroll(true)
  box:EnableMouseWheel(false)
  local editBox = CreateFrame("EditBox", nil, box)
  editBox:SetMultiLine(true)
  editBox:SetAutoFocus(false)
  editBox:SetCountInvisibleLetters(false)
  editBox.scrollable = true
  local help = frame:CreateFontString(nil, "ARTWORK")
  local view = CreateScrollBoxLinearView()
  view:SetPanExtent(20)
  box:Init(view)
  local bar = nextScrollBar:Create(box)
  bar:Bind(box)
  ---@type NextTextAreaFrame
  local area = setmetatable({
    frame = frame, fill = fill, edge = controls:CreateEdge(frame), box = box, bar = bar, editBox = editBox,
    help = help, opts = opts,
  }, { __index = areaProto })
  style:SetFont(editBox, controls:Theme("Input").Font)
  style:SetFont(help, controls:Theme("Input").HelpFont)
  help:SetText(opts.help or "")
  addon.SetScript(box, "OnMouseDown", function() editBox:SetFocus() end)
  addon.SetScript(editBox, "OnEditFocusGained", function() area:OnFocus(true) end)
  addon.SetScript(editBox, "OnEditFocusLost", function() area:OnFocus(false) end)
  addon.SetScript(editBox, "OnEscapePressed", function() editBox:ClearFocus() end)
  addon.SetScript(editBox, "OnTextChanged", function(ctx, _, userInput) area:OnTextChanged(ctx, userInput) end)
  addon.SetScript(editBox, "OnCursorChanged", function(_, _, _, y, _, height) area:FollowCursor(y, height) end)
  table.insert(self.all, area)
  sonataNext:RegisterWidget(self)
  area:Style()
  return area
end

function areaProto:Style()
  local I = controls:Theme("Input")
  local pad = I.Padding
  self.box:ClearAllPoints()
  self.box:SetPoint("TOPLEFT", self.frame, "TOPLEFT", pad, -pad)
  self.box:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -pad, pad)
  -- The text stops short of the bar in the box's right edge.
  local S = controls:Theme("ScrollBar")
  self.editBox:SetTextInsets(0, S.Width + S.Inset, 0, 0)
  style:SetFont(self.editBox, I.Font)
  style:SetFont(self.help, I.HelpFont)
  self.help:ClearAllPoints()
  self.help:SetPoint("TOPLEFT", self.frame, "TOPLEFT", pad, -pad)
  self:Paint()
end

function areaProto:Paint()
  local I = controls:Theme("Input")
  local focused = self.editBox:HasFocus()
  controls:Paint(self.fill, focused and I.FocusFill or I.Fill)
  controls:PaintEdge(self.edge, I.Edge, focused and I.Edge.Focus or I.Edge.Idle)
  self.help:SetShown(not focused and self:GetText() == "")
end

---@param focused boolean
function areaProto:OnFocus(focused)
  self.box:EnableMouseWheel(focused)
  self:Paint()
end

---@param ctx Context
---@param userInput boolean
function areaProto:OnTextChanged(ctx, userInput)
  self.box:FullUpdate(true)
  self:Paint()
  if userInput and self.opts.onChange then
    self.opts.onChange(ctx, self:GetText(), true)
  end
end

-- FollowCursor scrolls the box so the cursor (y down from the text's top, height tall) stays seen.
---@param y number
---@param height number
function areaProto:FollowCursor(y, height)
  local box = self.box
  local offset, visible = box:GetDerivedScrollOffset(), box:GetVisibleExtent()
  local top, bottom = -y, -y + height
  if top < offset then
    box:ScrollToOffset(top)
  elseif bottom > offset + visible then
    box:ScrollToOffset(bottom - visible)
  end
end

---@return string
function areaProto:GetText()
  return self.editBox:GetText() or ""
end

-- SetText shows a text set from code: nothing is reported.
---@param text string
function areaProto:SetText(text)
  self.editBox:SetText(text or "")
  self.box:FullUpdate(true)
  self:Paint()
end

-- SelectAll focuses the text and selects all of it (to copy it).
function areaProto:SelectAll()
  self.editBox:SetFocus()
  self.editBox:HighlightText()
  self:OnFocus(true)
end
