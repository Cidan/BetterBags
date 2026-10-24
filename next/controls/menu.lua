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

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

---@class PixelAudit: AceModule
local pixelAudit = addon:GetModule('PixelAudit')

-- NextMenu is BetterBags Next's menu of choices (next-settings.md §2): one at a time, drawn from the
-- theme (Controls.Menu), below what opened it, over everything (FULLSCREEN_DIALOG), a row per
-- choice, the chosen one checked, scrolling past MaxRows. A click picks a choice and closes it; a
-- click or the wheel anywhere else, Escape, opening it again for the same frame, or that frame
-- hiding, closes it.
---@class NextMenu: AceModule
---@field frame Frame
---@field fill Texture
---@field edge NextEdge
---@field box WowScrollBox
---@field list Frame The rows, scrolled by box.
---@field bar NextScrollBarFrame
---@field catcher Button Takes clicks outside the menu, closing it.
---@field rows NextMenuRow[] Every row made; the first #items are shown.
---@field items NextMenuItem[]
---@field anchor? Frame
---@field opts? NextMenuOptions
---@field open boolean
---@field hooked table<Frame, boolean>
local nextMenu = addon:NewModule('NextMenu')

---@class (exact) NextMenuItem
---@field text string
---@field value? any
---@field selected? boolean
---@field disabled? boolean

---@class (exact) NextMenuOptions
---@field items NextMenuItem[]
---@field onPick fun(ctx: Context, item: NextMenuItem)
---@field onClose? fun()
---@field width? number At least this wide.

---@class NextMenuRow
---@field frame Button
---@field hover Texture
---@field label FontString
---@field check Texture
---@field item? NextMenuItem
local rowProto = {}
addon:GetModule('Perf'):RegisterPrototype(rowProto, 'NextMenuRow')

nextMenu.rows = {}
nextMenu.items = {}
nextMenu.open = false
nextMenu.hooked = setmetatable({}, { __mode = "k" })

-- build makes the menu's frames, the first time it opens.
---@private
function nextMenu:build()
  if self.frame ~= nil then
    return
  end
  local frame = CreateFrame("Frame", "BetterBagsNextMenu", UIParent)
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:Hide()
  self.fill = frame:CreateTexture(nil, "BACKGROUND")
  self.fill:SetAllPoints(frame)
  self.edge = controls:CreateEdge(frame)
  local box = CreateFrame("Frame", nil, frame, "WowScrollBox") --[[@as WowScrollBox]]
  box:SetInterpolateScroll(true)
  pixel:SnapScroll(box)
  local list = CreateFrame("Frame", nil, box)
  list.scrollable = true
  local view = CreateScrollBoxLinearView()
  view:SetPanExtent(24)
  box:Init(view)
  self.bar = nextScrollBar:Create(box)
  self.bar:Bind(box)
  local catcher = CreateFrame("Button", nil, UIParent)
  catcher:SetAllPoints(UIParent)
  catcher:SetFrameStrata("FULLSCREEN_DIALOG")
  catcher:EnableMouse(true)
  catcher:EnableMouseWheel(true)
  catcher:Hide()
  addon.SetScript(catcher, "OnMouseDown", function() self:Close() end)
  addon.SetScript(catcher, "OnMouseWheel", function() self:Close() end)
  addon.SetScript(frame, "OnHide", function() self:hidden() end)
  self.frame, self.box, self.list, self.catcher = frame, box, list, catcher
  sonataNext:RegisterWidget(self)
  pixelAudit:Register(frame, { title = "Menu", owners = { menu = self } })
end

-- row returns the i-th row, made the first time it is needed.
---@private
---@param i number
---@return NextMenuRow
function nextMenu:row(i)
  local row = self.rows[i]
  if row ~= nil then
    return row
  end
  local frame = CreateFrame("Button", nil, self.list)
  frame:RegisterForClicks("LeftButtonUp")
  local hover = frame:CreateTexture(nil, "BACKGROUND")
  hover:SetAllPoints(frame)
  hover:Hide()
  local label = frame:CreateFontString(nil, "OVERLAY")
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)
  local check = frame:CreateTexture(nil, "ARTWORK")
  row = setmetatable({ frame = frame, hover = hover, label = label, check = check }, { __index = rowProto })
  style:SetFont(label, controls:Theme("Menu").Font)
  addon.SetScript(frame, "OnClick", function(ctx) self:Pick(ctx, row) end)
  addon.SetScript(frame, "OnEnter", function() row:SetHovered(true) end)
  addon.SetScript(frame, "OnLeave", function() row:SetHovered(false) end)
  self.rows[i] = row
  return row
end

---@param hovered boolean
function rowProto:SetHovered(hovered)
  self.hover:SetShown(hovered and self.item ~= nil and not self.item.disabled)
end

-- Rows returns the rows of the choices shown.
---@return NextMenuRow[]
function nextMenu:Rows()
  local list = {}
  for i = 1, #self.items do
    list[i] = self.rows[i]
  end
  return list
end

---@param anchor Frame
---@return boolean
function nextMenu:IsOpenFor(anchor)
  return self.open and self.anchor == anchor
end

-- Open shows the menu below anchor with opts' choices, in place of any menu open.
---@param anchor Frame
---@param opts NextMenuOptions
function nextMenu:Open(anchor, opts)
  self:build()
  if self.open then
    self:Close()
  end
  self.anchor, self.opts, self.items = anchor, opts, opts.items
  if not self.hooked[anchor] then
    self.hooked[anchor] = true
    addon.HookScript(anchor, "OnHide", function()
      if self.anchor == anchor then
        self:Close()
      end
    end)
  end
  self:Style()
  self.open = true
  self.catcher:Show()
  self.frame:Show()
  controls:PushEscape(self.frame)
end

-- Toggle closes the menu when it is open for anchor, and opens it otherwise.
---@param anchor Frame
---@param opts NextMenuOptions
function nextMenu:Toggle(anchor, opts)
  if self:IsOpenFor(anchor) then
    self:Close()
  else
    self:Open(anchor, opts)
  end
end

function nextMenu:Close()
  if not self.open then
    return
  end
  self.frame:Hide()
  self:hidden()
end

-- hidden ends the menu however it hid (Close, Escape, its parent): once.
---@private
function nextMenu:hidden()
  if not self.open then
    return
  end
  self.open = false
  self.catcher:Hide()
  controls:ReleaseEscape(self.frame)
  local opts = self.opts
  self.anchor, self.opts = nil, nil
  if opts and opts.onClose then
    opts.onClose()
  end
end

-- Pick takes a row's choice, unless it is disabled, and closes.
---@param ctx Context
---@param row NextMenuRow
function nextMenu:Pick(ctx, row)
  local item = row.item
  if item == nil or item.disabled then
    return
  end
  local opts = self.opts
  self:Close()
  if opts then
    opts.onPick(ctx, item)
  end
end

-- ApplyStyle restyles the menu while it is open (SonataNext applied a theme).
---@param ctx? Context
function nextMenu:ApplyStyle(ctx)
  local _ = ctx
  if self.frame ~= nil and self.open then
    self:Style()
  end
end

-- Style lays the rows out and draws the menu: as wide as the widest choice (at least its anchor and
-- opts.width), MaxRows tall at most.
-- All in whole pixels on its own grid (UIParent's: docs/next-pixel-perfect.md), its anchor's width in its
-- units (the anchor may be in a window drawn smaller): its rows one ItemHeight apart, a check and a label
-- on each centered by its top.
function nextMenu:Style()
  local M = controls:Theme("Menu")
  local frame, items = self.frame, self.items
  frame:ClearAllPoints()
  pixel:Point(frame, "TOPLEFT", self.anchor, "BOTTOMLEFT", 0, -M.Gap)
  frame:SetFrameLevel(self.catcher:GetFrameLevel() + 2)
  controls:Paint(self.fill, M.Fill)
  controls:PaintEdge(self.edge, M.Edge)
  local check = M.Check
  local pad, itemHeight, checkSize = pixel:Lengths(frame, M.Padding, M.ItemHeight, check.Size)
  local textLeft = pad + checkSize + pad
  local widest = 0
  for i, item in ipairs(items) do
    local row = self:row(i)
    row.item = item
    local font = M.Font
    if item.disabled then
      font = "ControlMuted"
    elseif item.selected then
      font = M.SelectedFont
    end
    style:SetFont(row.label, font)
    row.label:SetText(item.text)
    widest = math.max(widest, row.label:GetStringWidth())
    controls:Paint(row.hover, M.HoverFill)
    row.hover:Hide()
    controls:Paint(row.check, { Texture = check.Texture, Color = check.Color })
    row.check:SetSize(checkSize, checkSize)
    row.check:ClearAllPoints()
    pixel:Row(row.check, "TOPLEFT", row.frame, pad, itemHeight)
    row.check:SetShown(item.selected == true)
    row.label:ClearAllPoints()
    pixel:Row(row.label, "TOPLEFT", row.frame, textLeft, itemHeight)
    pixel:Row(row.label, "TOPRIGHT", row.frame, pad, itemHeight)
    row.frame:ClearAllPoints()
    row.frame:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, -(i - 1) * itemHeight)
    row.frame:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", 0, -(i - 1) * itemHeight)
    row.frame:SetHeight(itemHeight)
    row.frame:Show()
  end
  for i = #items + 1, #self.rows do
    self.rows[i].item = nil
    self.rows[i].frame:Hide()
  end
  local shown = math.min(#items, M.MaxRows)
  local scrolls = #items > M.MaxRows
  local S = controls:Theme("ScrollBar")
  -- The rows sit in a list inset Padding on both sides: the menu holds that, the text's left, the
  -- widest text and the room right of it.
  local bar = scrolls and (pixel:Length(frame, S.Width) + pixel:Length(frame, S.Inset)) or 0
  local width = 2 * pad + textLeft + pixel:Ceil(frame, widest) + pad + bar
  local anchorWidth = self.anchor:GetWidth() * self.anchor:GetEffectiveScale() / frame:GetEffectiveScale()
  width = math.max(width, pixel:Ceil(frame, anchorWidth), pixel:Ceil(frame, self.opts.width or 0))
  frame:SetSize(width, shown * itemHeight + 2 * pad)
  pixel:Inset(self.box, frame, pad, pad, pad, pad)
  self.list:SetHeight(#items * itemHeight)
  self.box:FullUpdate(true)
  self.box:SetScrollPercentage(0, true)
end
