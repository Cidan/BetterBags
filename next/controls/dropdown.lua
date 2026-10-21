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
  table.insert(self.all, d)
  sonataNext:RegisterWidget(self)
  d:Style()
  d:Refresh()
  return d
end

function dropdownProto:Style()
  local D = controls:Theme("Dropdown")
  local frame = self.frame
  frame:SetSize(self.opts.width or D.Width, D.Height)
  style:SetFont(self.text, D.Font)
  local chevron = D.Chevron
  self.chevron:SetSize(chevron.Size, chevron.Size)
  self.chevron:ClearAllPoints()
  self.chevron:SetPoint("RIGHT", frame, "RIGHT", -D.Padding, 0)
  controls:Paint(self.chevron, { Texture = chevron.Texture, Color = chevron.Color })
  self.text:ClearAllPoints()
  self.text:SetPoint("LEFT", frame, "LEFT", D.Padding, 0)
  self.text:SetPoint("RIGHT", self.chevron, "LEFT", -D.Padding / 2, 0)
  frame:SetAlpha(frame:IsEnabled() and 1 or controls:Theme("Button").DisabledAlpha)
  self:Paint()
end

-- Paint draws the fill and edge: open, under the pointer, or idle.
function dropdownProto:Paint()
  local D = controls:Theme("Dropdown")
  local open = nextMenu:IsOpenFor(self.frame)
  local lit = self.hovered and self.frame:IsEnabled()
  controls:Paint(self.fill, (open and D.OpenFill) or (lit and D.HoverFill) or D.Fill)
  local strength = D.Edge.Idle
  if open then
    strength = D.Edge.Open
  elseif lit then
    strength = D.Edge.Hover
  end
  controls:PaintEdge(self.edge, D.Edge, strength)
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
  self:Paint()
end
