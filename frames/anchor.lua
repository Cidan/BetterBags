local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class LibWindow-1.1: AceAddon
local Window = LibStub('LibWindow-1.1')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Anchor: AceModule
local anchor = addon:NewModule('Anchor')

---@class (exact) AnchorFrame
---@field frame Frame
---@field anchorFor Frame
---@field label FontString
---@field positionLabel FontString
---@field anchorPoint string
---@field kind BagKind
local anchorFrame = {}

---@param frame Frame
---@return string
local function GetFrameScreenQuadrant(frame)
  local screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight()
  local screenCenterX, screenCenterY = screenWidth / 2, screenHeight / 2
  local frameLeft, frameBottom, frameWidth, frameHeight = frame:GetRect()
  local frameCenterX = frameLeft + (frameWidth / 2)
  local frameCenterY = frameBottom + (frameHeight / 2)
  if frameCenterX < screenCenterX then
      if frameCenterY > screenCenterY then
          return "TOPLEFT"
      else
          return "BOTTOMLEFT"
      end
  else
      if frameCenterY > screenCenterY then
          return "TOPRIGHT"
      else
          return "BOTTOMRIGHT"
      end
  end
end

-- Activate will make the anchor frame clamped to the screen and "turn on" the anchor.
function anchorFrame:Activate()
  self.frame:SetClampedToScreen(true)
  self.frame:EnableMouse(true)
  database:GetAnchorState(self.kind).enabled = true
  self:OnDragUpdate()
end

function anchorFrame:Deactivate()
  self.frame:SetClampedToScreen(false)
  self.frame:EnableMouse(false)
  database:GetAnchorState(self.kind).enabled = false
end

function anchorFrame:ToggleActive()
  if self:IsActive() then
    self:Deactivate()
  else
    self:Activate()
  end
end

function anchorFrame:ToggleShown()
  if self.frame:IsShown() then
    self:Hide()
  else
    self:Show()
  end
end

---@return boolean
function anchorFrame:IsActive()
  return self.frame:IsClampedToScreen()
end

function anchorFrame:Show()
  self.frame:Show()
  database:GetAnchorState(self.kind).shown = true
end

function anchorFrame:Hide()
  self.frame:Hide()
  database:GetAnchorState(self.kind).shown = false
end

-- SetStaticAnchorPoint will set the anchor point to a specific anchor point on the frame.
-- If nil, automatic anchoring will be used.
---@param point? string
function anchorFrame:SetStaticAnchorPoint(point)
  database:GetAnchorState(self.kind).staticPoint = point
  self:OnDragUpdate()
end

function anchorFrame:OnDragStart()
  self.frame:StartMoving()
end

function anchorFrame:OnDragStop()
  self.frame:StopMovingOrSizing()
end

function anchorFrame:OnDragUpdate()
  local state = database:GetAnchorState(self.kind)
  if not state.enabled then return end
  local quadrant = state.staticPoint or GetFrameScreenQuadrant(self.frame)
  self.anchorFor:ClearAllPoints()
  self.anchorFor:SetPoint(quadrant, self.frame, quadrant)
  self.positionLabel:SetText(string.format("%dx %dy", self.frame:GetCenter()))
  self.anchorPoint = quadrant
  Window.SavePosition(self.frame)
end

function anchorFrame:Load()
  -- Load the anchor position from settings.
  Window.RestorePosition(self.frame)
  local state = database:GetAnchorState(self.kind)
  local quadrant = state.staticPoint or GetFrameScreenQuadrant(self.frame)
  if state.enabled then
    self:Activate()
    self.anchorFor:ClearAllPoints()
    self.anchorFor:SetPoint(quadrant, self.frame, quadrant)
  else
    self:Deactivate()
  end
  if state.shown then
    self:Show()
  else
    self:Hide()
  end
  self.positionLabel:SetText(string.format("%dx %dy", self.frame:GetCenter()))
  self.anchorPoint = quadrant
end

---@param kind BagKind
---@param anchorFor Frame
---@param label string
---@return AnchorFrame
function anchor:New(kind, anchorFor, label)
  local af = setmetatable({}, { __index = anchorFrame })
  af.frame = CreateFrame('Frame', anchorFor:GetName() .. "Anchor", UIParent, "BackdropTemplate") --[[@as Frame]]
  af.frame:SetSize(72, 72)
  af.frame:SetPoint('CENTER', UIParent, 'CENTER')
  af.frame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    -- Pick a straight edge.
    edgeFile = "Interface/Tooltips/UI-Tooltip-Background",
    tile = true,
    tileSize = 16,
    edgeSize = 1,
    insets = {
      left = 1,
      right = 1,
      top = 1,
      bottom = 1
    }
  })
  af.frame:RegisterForDrag("LeftButton")
  af.frame:SetScript("OnDragStart", function()
    af:OnDragStart()
  end)
  af.frame:SetScript("OnDragStop", function()
    af:OnDragStop()
  end)
  af.frame:SetScript("OnUpdate", function()
    if not af.frame:IsDragging() then return end
    af:OnDragUpdate()
  end)

  af.frame:SetScript("OnMouseDown", function(_, button)
    if button == "RightButton" then
      af:Hide()
    end
  end)

  af.frame:SetBackdropColor(48 / 255, 168 / 255, 255 / 255, 1)
  af.frame:SetBackdropBorderColor(0, 0, 0, 1)
  af.frame:SetMovable(true)
  af.frame:EnableMouse(false)

  af.label = af.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  af.label:SetTextColor(0.9, 0.9, 0.9)
  af.label:SetPoint("TOP", af.frame, "TOP", 0, -4)
  af.label:SetWidth(af.frame:GetWidth())
  af.label:SetText(label)

  af.positionLabel = af.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  af.positionLabel:SetTextColor(0.9, 0.9, 0.9)
  af.positionLabel:SetPoint("BOTTOM", af.frame, "BOTTOM", 0, 4)
  af.positionLabel:SetWidth(af.frame:GetWidth())
  af.positionLabel:SetText("")

  af.frame:SetFrameStrata("FULLSCREEN_DIALOG")
  af.frame:Hide()

  af.anchorFor = anchorFor
  af.kind = kind

  -- Register the anchor frame with the config system.
  Window.RegisterConfig(af.frame, database:GetAnchorPosition(kind))

  af:Load()
  return af
end