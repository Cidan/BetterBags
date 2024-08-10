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
  self:OnDragUpdate()
end

function anchorFrame:Deactivate()
  self.frame:SetClampedToScreen(false)
  self.frame:EnableMouse(false)
end

---@return boolean
function anchorFrame:IsActive()
  return self.frame:IsClampedToScreen()
end

function anchorFrame:Show()
  self.frame:Show()
end

function anchorFrame:Hide()
  self.frame:Hide()
end

function anchorFrame:OnDragStart()
  self.frame:StartMoving()
end

function anchorFrame:OnDragStop()
  self.frame:StopMovingOrSizing()
end

function anchorFrame:OnDragUpdate()
  local quadrant = GetFrameScreenQuadrant(self.frame)
  self.anchorFor:ClearAllPoints()
  self.anchorFor:SetPoint(quadrant, self.frame, quadrant)
  self.positionLabel:SetText(string.format("%dx %dy", self.frame:GetCenter()))
  self.anchorPoint = quadrant
  Window.SavePosition(self.frame)
end

function anchorFrame:Load()
  -- Load the anchor position from settings.
  Window.RestorePosition(self.frame)
  local quadrant = GetFrameScreenQuadrant(self.frame)
  local state = database:GetAnchorState(self.kind)
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