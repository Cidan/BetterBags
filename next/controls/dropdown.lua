local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextControls: AceModule
local controls = addon:GetModule('NextControls')

---@class NextMenu: AceModule
local nextMenu = addon:GetModule('NextMenu')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

---@class NextFill: AceModule
local fills = addon:GetModule('NextFill')

-- NextDropdown is BetterBags Next's dropdown (next-settings.md §2), drawn from the theme
-- (Controls.Dropdown): a field showing the choice made and a chevron. A click opens a NextMenu of its
-- choices, read each time it opens (itemsFunction: a provider that registers late shows,
-- form-dropdowns.md), the one made checked; picking another calls back.
---@class NextDropdown: AceModule
---@field all NextDropdownFrame[]
local nextDropdown = addon:NewModule('NextDropdown')

---@class (exact) NextDropdownOptions
---@field items? string[]
---@field itemsFunction? fun(ctx: Context): string[]
---@field get fun(ctx: Context): string? The choice made.
---@field onChange fun(ctx: Context, item: string)
---@field width? number

---@class NextDropdownFrame
---@field frame Button
---@field fill Texture
---@field edge NextEdge
---@field text FontString
---@field chevron Texture
---@field hovered boolean
---@field pressed? boolean Pressed under the pointer (its arrow's Pressed art).
---@field opts NextDropdownOptions
local dropdownProto = {}
addon:GetModule('Perf'):RegisterPrototype(dropdownProto, 'NextDropdownFrame')

nextDropdown.all = {}

---@param ctx? Context
function nextDropdown:ApplyStyle(ctx)
  local _ = ctx
  for _, d in ipairs(self.all) do
    d:Style()
  end
end

---@param parent Frame
---@param opts NextDropdownOptions
---@return NextDropdownFrame
function nextDropdown:Create(parent, opts)
  local frame = CreateFrame("Button", nil, parent)
  frame:RegisterForClicks("LeftButtonUp")
  local fill = frame:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints(frame)
  fills:Wrap(fill, frame)
  local text = frame:CreateFontString(nil, "OVERLAY")
  text:SetJustifyH("LEFT")
  text:SetWordWrap(false)
  local chevron = frame:CreateTexture(nil, "ARTWORK")
  ---@type NextDropdownFrame
  local d = setmetatable({
    frame = frame, fill = fill, edge = controls:CreateEdge(frame), text = text, chevron = chevron,
    hovered = false, opts = opts,
  }, { __index = dropdownProto })
  style:SetFont(text, controls:Theme("Dropdown").Font)
  addon.SetScript(frame, "OnClick", function(ctx) d:Click(ctx) end)
  addon.SetScript(frame, "OnEnter", function() d:SetHovered(true) end)
  addon.SetScript(frame, "OnLeave", function() d:SetHovered(false) end)
  -- Pressed: its arrow's Pressed art (Blizzard's pressedhover).
  addon.SetScript(frame, "OnMouseDown", function() d.pressed = true d:Paint() end)
  addon.SetScript(frame, "OnMouseUp", function() d.pressed = false d:Paint() end)
  table.insert(self.all, d)
  sonataNext:RegisterWidget(self)
  d:Style()
  d:Refresh()
  return d
end

-- Style lays the dropdown out in whole pixels (docs/next-pixel-perfect.md): the chevron the padding in
-- from the right (or by its right at its Point, Blizzard's arrow), the choice from the left up to it, justified as
-- the theme says, each centered on its height by its top. Disabled, it is drawn at DisabledAlpha (the buttons'
-- when unset).
function dropdownProto:Style()
  local D = controls:Theme("Dropdown")
  local frame = self.frame
  pixel:Size(frame, self.opts.width or D.Width, D.Height)
  self.text:SetJustifyH(D.Justify or "LEFT")
  local height, pad = frame:GetHeight(), pixel:Length(frame, D.Padding)
  self:paintChevron()
  self.text:ClearAllPoints()
  pixel:Row(self.text, "TOPLEFT", frame, pad, height)
  local point = D.Chevron.Point
  local right = point and (self.chevron:GetWidth() - pixel:Snap(frame, point.X or 0)) or (pad + self.chevron:GetWidth())
  pixel:Row(self.text, "TOPRIGHT", frame, right + pixel:Floor(frame, pad / 2), height)
  local disabledAlpha = D.DisabledAlpha or controls:Theme("Button").DisabledAlpha
  frame:SetAlpha(frame:IsEnabled() and 1 or disabledAlpha)
  self:Paint()
end

-- chevronArt returns the art the chevron draws now: its Disabled art while disabled, Open while its menu is open,
-- Pressed while pressed under the pointer, Hover under the pointer, else its own (Blizzard's dropdown arrow:
-- GetWowStyle1ArrowButtonState). A state without art draws the chevron's own.
---@private
---@return table
function dropdownProto:chevronArt()
  local C = controls:Theme("Dropdown").Chevron
  local frame = self.frame
  if not frame:IsEnabled() then
    return C.Disabled or C
  end
  if nextMenu:IsOpenFor(frame) and C.Open then
    return C.Open
  end
  if self.hovered and self.pressed and C.Pressed then
    return C.Pressed
  end
  if self.hovered and C.Hover then
    return C.Hover
  end
  return C
end

-- paintChevron draws the chevron for its state, at its Size (or its art's atlas size, Size = "Atlas"), placed by its
-- right at Point from the dropdown's right edge, or the padding in from the right and centered by its top.
---@private
function dropdownProto:paintChevron()
  local D = controls:Theme("Dropdown")
  local C, frame = D.Chevron, self.frame
  local art = self:chevronArt()
  local width, height = style:SizeOf(C, art, 12)
  pixel:Size(self.chevron, width, height)
  self.chevron:ClearAllPoints()
  if C.Point then
    pixel:Point(self.chevron, "RIGHT", frame, "RIGHT", C.Point.X or 0, C.Point.Y or 0)
  else
    pixel:Row(self.chevron, "TOPRIGHT", frame, pixel:Length(frame, D.Padding), frame:GetHeight())
  end
  -- A glyph, or an atlas (Blizzard's dropdown arrow).
  controls:Paint(self.chevron, { Texture = art.Texture or (not art.Atlas and C.Texture) or nil, Atlas = art.Atlas,
    Color = art.Color or C.Color })
end

-- Paint draws the fill and edge: open, under the pointer, or idle; at NarrowWidth or less its NarrowFill in every
-- state (Classic's narrow dropdown art). Its chevron for its state, and its text in its DisabledFont while
-- disabled.
function dropdownProto:Paint()
  local D = controls:Theme("Dropdown")
  local open = nextMenu:IsOpenFor(self.frame)
  local lit = self.hovered and self.frame:IsEnabled()
  local narrow = D.NarrowFill and D.NarrowWidth and self.frame:GetWidth() <= D.NarrowWidth
  controls:Paint(self.fill, (narrow and D.NarrowFill) or (open and D.OpenFill) or (lit and D.HoverFill) or D.Fill)
  self:paintChevron()
  style:SetFont(self.text, (not self.frame:IsEnabled() and D.DisabledFont) or D.Font)
  -- A theme may draw no edge (Edge = false: Blizzard's dropdown border is its fill).
  local E, strength = D.Edge, nil
  if E then
    strength = (open and E.Open) or (lit and E.Hover) or E.Idle
  end
  controls:PaintEdge(self.edge, E, strength)
end

-- Refresh shows the choice made, nothing for none.
---@param ctx? Context
function dropdownProto:Refresh(ctx)
  local item = self.opts.get(ctx)
  self.text:SetText(item or "")
end

-- items returns the choices: the list given, or the function's, read now.
---@private
---@param ctx Context
---@return string[]
function dropdownProto:items(ctx)
  if self.opts.itemsFunction then
    return self.opts.itemsFunction(ctx)
  end
  return self.opts.items or {}
end

-- Click opens (or closes) the menu of choices.
---@param ctx Context
function dropdownProto:Click(ctx)
  if not self.frame:IsEnabled() then
    return
  end
  local current = self.opts.get(ctx)
  local list = {}
  for i, item in ipairs(self:items(ctx)) do
    list[i] = { text = item, value = item, selected = item == current }
  end
  nextMenu:Toggle(self.frame, {
    items = list,
    onPick = function(pctx, item) self:Pick(pctx, item.value) end,
    onClose = function() self:Paint() end,
  })
  self:Paint()
end

-- Pick takes a choice: shown, and called back unless it was the one made.
---@param ctx Context
---@param item string
function dropdownProto:Pick(ctx, item)
  if item ~= self.opts.get(ctx) then
    self.opts.onChange(ctx, item)
  end
  self:Refresh(ctx)
  self:Paint()
end

---@param enabled boolean
function dropdownProto:SetEnabled(enabled)
  self.frame:SetEnabled(enabled)
  if not enabled and nextMenu:IsOpenFor(self.frame) then
    nextMenu:Close()
  end
  self:Style()
end

---@param hovered boolean
function dropdownProto:SetHovered(hovered)
  self.hovered = hovered
  if not hovered then
    self.pressed = false
  end
  self:Paint()
end
