local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextControls: AceModule
local controls = addon:GetModule('NextControls')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- NextScrollBar is BetterBags Next's scroll bar (next-settings.md §2), drawn from the theme
-- (Controls.ScrollBar), in place of Blizzard's MinimalScrollBar on every Next scroll box (the bags'
-- too, render/scrollbox.lua's CreateBar). It drives a Blizzard scroll box the way ScrollUtil binds a
-- bar to one (Blizzard_SharedXML/Shared/Scroll/ScrollUtil.lua RegisterWithScrollBox): the box's
-- OnScroll moves the thumb, and the thumb dragged, the track clicked and the wheel over the bar scroll
-- the box (SetScrollPercentage, ScrollToOffset, ScrollInDirection). It hides while nothing scrolls.
---@class NextScrollBar: AceModule
---@field all NextScrollBarFrame[]
local scrollBar = addon:NewModule('NextScrollBar')

---@class (exact) NextScrollBarOptions
---@field AutoHide? boolean Seen only while the box scrolls or the pointer is over the bar.

---@class NextScrollBarFrame
---@field frame Button Takes the clicks on the track and the wheel.
---@field track Texture
---@field thumb Frame Dragged.
---@field thumbTexture Texture
---@field box? WowScrollBox
---@field visible number The share of the content the box shows.
---@field percentage number How far it is scrolled, from 0 to 1.
---@field hovered boolean
---@field dragging boolean
---@field grab number Where the thumb was grabbed, down from its top.
---@field autoHide boolean
---@field driver? Frame Fades an auto-hiding bar, each frame while the bar shows.
---@field idle number Seconds since the box last scrolled.
local barProto = {}
addon:GetModule('Perf'):RegisterPrototype(barProto, 'NextScrollBarFrame')

scrollBar.all = {}

-- ApplyStyle restyles every bar made (SonataNext applied a theme).
---@param ctx? Context
function scrollBar:ApplyStyle(ctx)
  local _ = ctx
  for _, bar in ipairs(self.all) do
    bar:Style()
  end
end

-- Create makes a bar in parent's right edge (the scroll box it drives; Bind binds it).
---@param parent Frame
---@param opts? NextScrollBarOptions
---@return NextScrollBarFrame
function scrollBar:Create(parent, opts)
  local frame = CreateFrame("Button", nil, parent)
  frame:EnableMouse(true)
  frame:EnableMouseWheel(true)
  local track = frame:CreateTexture(nil, "BACKGROUND")
  local thumb = CreateFrame("Frame", nil, frame)
  thumb:EnableMouse(true)
  local thumbTexture = thumb:CreateTexture(nil, "ARTWORK")
  thumbTexture:SetAllPoints(thumb)
  ---@type NextScrollBarFrame
  local bar = setmetatable({
    frame = frame, track = track, thumb = thumb, thumbTexture = thumbTexture,
    visible = 0, percentage = 0, hovered = false, dragging = false, grab = 0,
    autoHide = opts ~= nil and opts.AutoHide == true, idle = 0,
  }, { __index = barProto })
  addon.SetScript(frame, "OnMouseDown", function(_, _, button) bar:OnTrackClick(button) end)
  addon.SetScript(frame, "OnMouseWheel", function(_, _, delta) bar:OnWheel(delta) end)
  addon.SetScript(frame, "OnEnter", function() bar:SetHovered(true) end)
  addon.SetScript(frame, "OnLeave", function() bar:SetHovered(false) end)
  addon.SetScript(frame, "OnSizeChanged", function() bar:Layout() end)
  addon.SetScript(thumb, "OnEnter", function() bar:SetHovered(true) end)
  addon.SetScript(thumb, "OnLeave", function() bar:SetHovered(false) end)
  addon.SetScript(thumb, "OnMouseDown", function(_, _, button) bar:StartDrag(button) end)
  addon.SetScript(thumb, "OnMouseUp", function() bar:StopDrag() end)
  if bar.autoHide then
    -- A child of the bar updates only while the bar is shown; it starts invisible each time the bar
    -- shows again.
    local driver = CreateFrame("Frame", nil, frame)
    driver:SetScript("OnUpdate", function(_, elapsed) bar:UpdateFade(elapsed) end)
    driver:SetScript("OnShow", function() bar:HideNow() end)
    bar.driver = driver
  end
  table.insert(self.all, bar)
  sonataNext:RegisterWidget(self)
  bar:Style()
  if bar.autoHide then
    bar:HideNow()
  end
  return bar
end

-- Style places the bar in its parent's right edge and draws it from the theme.
function barProto:Style()
  local S = controls:Theme("ScrollBar")
  local frame, parent = self.frame, self.frame:GetParent()
  frame:ClearAllPoints()
  frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -S.Inset, 0)
  frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -S.Inset, 0)
  frame:SetWidth(S.Width)
  self.track:ClearAllPoints()
  self.track:SetPoint("TOP", frame, "TOP", 0, 0)
  self.track:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
  self.track:SetWidth(S.Size)
  controls:Paint(self.track, S.Track)
  self:Paint()
  self:Layout()
end

-- Paint draws the thumb as it is: dragged, under the pointer, or idle.
function barProto:Paint()
  local S = controls:Theme("ScrollBar")
  local active = self.hovered or self.dragging
  self.thumb:SetWidth(active and S.HoverSize or S.Size)
  controls:Paint(self.thumbTexture, self.dragging and S.ThumbDrag or (self.hovered and S.ThumbHover or S.Thumb))
end

-- Bind makes the bar drive box and follow it: it listens to the box's scroll, size and scrolling
-- being allowed, as ScrollUtil's registration does, once per box.
---@param box WowScrollBox
function barProto:Bind(box)
  if self.box == box then
    return
  end
  self.box = box
  box:RegisterCallback(BaseScrollBoxEvents.OnScroll, function(_, percentage, visible)
    self:OnScroll(percentage, visible)
  end, self)
  box:RegisterCallback(BaseScrollBoxEvents.OnSizeChanged, function(_, _, _, visible)
    self:OnScroll(self.percentage, visible)
  end, self)
  box:RegisterCallback(BaseScrollBoxEvents.OnAllowScrollChanged, function(_, allowScroll)
    self.frame:EnableMouse(allowScroll)
  end, self)
  self:OnScroll(box:GetScrollPercentage(), box:GetVisibleExtentPercentage())
end

-- OnScroll follows the box: how far it is scrolled and how much of its content it shows. The bar
-- shows only while there is something to scroll.
---@param percentage number
---@param visible number
function barProto:OnScroll(percentage, visible)
  local moved = self.percentage ~= percentage
  self.percentage = percentage or 0
  self.visible = visible or 0
  local scrollable = self.visible > 0.0001 and self.visible < 0.9999
  self.frame:SetShown(scrollable)
  if moved then
    self.idle = 0
  end
  self:Layout()
end

-- thumbHeight returns the thumb's height: the share of the bar the content shown is, at least
-- MinThumb, at most the bar.
---@return number
function barProto:thumbHeight()
  local height = self.frame:GetHeight()
  local S = controls:Theme("ScrollBar")
  return math.min(height, math.max(S.MinThumb, height * self.visible))
end

-- Layout sizes the thumb and places it the share of its room the box is scrolled.
function barProto:Layout()
  local height = self.frame:GetHeight()
  local thumb = self:thumbHeight()
  self.thumb:SetHeight(thumb)
  self.thumb:ClearAllPoints()
  self.thumb:SetPoint("TOP", self.frame, "TOP", 0, -((height - thumb) * self.percentage))
end

-- cursorDown returns how far below the bar's top the pointer is, in the bar's units.
---@return number?
function barProto:cursorDown()
  local top = self.frame:GetTop()
  if top == nil then
    return nil
  end
  local _, y = GetCursorPosition()
  return top - y / self.frame:GetEffectiveScale()
end

-- StartDrag grabs the thumb with the left button where the pointer is.
---@param button string
function barProto:StartDrag(button)
  local down = button == "LeftButton" and self:cursorDown()
  if not down then
    return
  end
  local height, thumb = self.frame:GetHeight(), self:thumbHeight()
  self.grab = down - (height - thumb) * self.percentage
  self.dragging = true
  self:Paint()
  addon.SetScript(self.thumb, "OnUpdate", function() self:UpdateDrag() end)
end

-- UpdateDrag scrolls the box so the thumb stays under the pointer, without interpolating, until the
-- left button is let go.
function barProto:UpdateDrag()
  if not IsMouseButtonDown("LeftButton") then
    self:StopDrag()
    return
  end
  local down = self:cursorDown()
  local room = self.frame:GetHeight() - self:thumbHeight()
  if down == nil or room <= 0 or self.box == nil then
    return
  end
  local percentage = math.max(0, math.min(1, (down - self.grab) / room))
  self.box:SetScrollPercentage(percentage, true)
end

-- StopDrag lets go of the thumb.
function barProto:StopDrag()
  if not self.dragging then
    return
  end
  self.dragging = false
  self.thumb:SetScript("OnUpdate", nil)
  self:Paint()
end

-- OnTrackClick pages the box by its height toward where the track was clicked.
---@param button string
function barProto:OnTrackClick(button)
  local down = button == "LeftButton" and self:cursorDown()
  if not down or self.box == nil then
    return
  end
  local height, thumb = self.frame:GetHeight(), self:thumbHeight()
  local top = (height - thumb) * self.percentage
  local box = self.box
  if down < top then
    box:ScrollToOffset(box:GetDerivedScrollOffset() - box:GetVisibleExtent())
  elseif down > top + thumb then
    box:ScrollToOffset(box:GetDerivedScrollOffset() + box:GetVisibleExtent())
  end
end

-- OnWheel scrolls the box by its pan extent, as the wheel over the box does.
---@param delta number
function barProto:OnWheel(delta)
  local box = self.box
  if box == nil then
    return
  end
  local direction = delta < 0 and ScrollControllerMixin.Directions.Increase or ScrollControllerMixin.Directions.Decrease
  box:ScrollInDirection(box:CalculatePanExtentPercentage(), direction)
end

---@param hovered boolean
function barProto:SetHovered(hovered)
  self.hovered = hovered
  self:Paint()
end

-- HideNow makes an auto-hiding bar invisible until the box scrolls or the pointer is over it.
function barProto:HideNow()
  self.idle = controls:Theme("ScrollBar").Linger
  self.frame:SetAlpha(0)
end

-- UpdateFade fades an auto-hiding bar in while the pointer is over it, it is dragged, or the box
-- scrolled less than Linger seconds ago, and out otherwise.
---@param elapsed number
function barProto:UpdateFade(elapsed)
  local S = controls:Theme("ScrollBar")
  if self.frame:IsMouseOver() or self.dragging then
    self.idle = 0
  else
    self.idle = self.idle + elapsed
  end
  local alpha = self.frame:GetAlpha()
  if self.idle < S.Linger then
    alpha = math.min(1, alpha + elapsed / S.FadeIn)
  else
    alpha = math.max(0, alpha - elapsed / S.FadeOut)
  end
  if alpha ~= self.frame:GetAlpha() then
    self.frame:SetAlpha(alpha)
  end
end
