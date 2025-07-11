


local addon = GetBetterBags()

---@class Animations: AceModule
local animations = addon:GetModule('Animations')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Overlay: AceModule
local overlay = addon:NewModule('Overlay')

---@class OverlayFrame
---@field frame Frame
---@field fadeIn AnimationGroup
---@field fadeOut AnimationGroup
local overlayFrame = {}

---@param ctx Context
---@param event? string
function overlayFrame:Show(ctx, event)
  self.fadeIn.callback = function()
    self.fadeIn.callback = nil
    self.frame:Show()
    self.frame:SetAlpha(1)
    if event then
      events:SendMessage(ctx, event)
    end
  end
  self.fadeIn:Play()
end

---@param ctx Context
---@param event? string
function overlayFrame:Hide(ctx, event)
  self.fadeOut.callback = function()
    self.fadeOut.callback = nil
    if event then
      events:SendMessage(ctx, event)
    end
  end
  self.fadeOut:Play()
end

---@param parent Frame
---@return OverlayFrame
function overlay:New(parent)
  local o = setmetatable({}, { __index = overlayFrame })
  o.frame = CreateFrame('Frame', nil, parent, "BackdropTemplate") --[[@as Frame]]
  o.frame:SetAllPoints()
  o.frame:SetFrameStrata("DIALOG")
  o.frame:SetFrameLevel(parent:GetFrameLevel() + 1)
  o.frame:EnableMouse(true)
  o.frame:Hide()

  o.frame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    tile = true,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  o.frame:SetBackdropColor(0, 0, 0, 1)
  o.fadeIn, o.fadeOut = animations:AttachFadeGroup(o.frame)
  return o
end
