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
addon:GetModule('Perf'):RegisterPrototype(anchorFrame, 'AnchorFrame')

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

---@class (exact) AnchorSquare: Frame
---@field label FontString
---@field positionLabel FontString

-- CreateSquare makes a bag's anchor as it shows, the one look of both designs' anchors (the classic bags' and BetterBags
-- Next's, docs/next-bag-anchor.md): a square 72 across on UIParent, Blizzard's tooltip background in blue with a black
-- straight edge, its label at its top and where it is at its bottom, over everything (FULLSCREEN_DIALOG), movable by a
-- left-button drag, hidden. What dragging it does is its owner's.
---@param name? string
---@param label string
---@return AnchorSquare
function anchor:CreateSquare(name, label)
  local frame = CreateFrame('Frame', name, UIParent, "BackdropTemplate") --[[@as AnchorSquare]]
  frame:SetSize(72, 72)
  frame:SetBackdrop({
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
  frame:RegisterForDrag("LeftButton")
  frame:SetBackdropColor(48 / 255, 168 / 255, 255 / 255, 1)
  frame:SetBackdropBorderColor(0, 0, 0, 1)
  frame:SetMovable(true)

  frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.label:SetTextColor(0.9, 0.9, 0.9)
  frame.label:SetPoint("TOP", frame, "TOP", 0, -4)
  frame.label:SetWidth(frame:GetWidth())
  frame.label:SetText(label)

  frame.positionLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.positionLabel:SetTextColor(0.9, 0.9, 0.9)
  frame.positionLabel:SetPoint("BOTTOM", frame, "BOTTOM", 0, 4)
  frame.positionLabel:SetWidth(frame:GetWidth())
  frame.positionLabel:SetText("")

  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:Hide()
  return frame
end

---@param kind BagKind
---@param anchorFor Frame
---@param label string
---@return AnchorFrame
function anchor:New(kind, anchorFor, label)
  local af = setmetatable({}, { __index = anchorFrame })
  local square = self:CreateSquare(anchorFor:GetName() .. "Anchor", label)
  af.frame = square
  af.label = square.label
  af.positionLabel = square.positionLabel
  af.frame:SetPoint('CENTER', UIParent, 'CENTER')
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

  af.frame:EnableMouse(false)

  af.anchorFor = anchorFor
  af.kind = kind

  -- Register the anchor frame with the config system.
  Window.RegisterConfig(af.frame, database:GetAnchorPosition(kind))

  af:Load()
  return af
end