local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Debug
local debug = addon:GetModule('Debug')

---@param frame Frame The frame to draw the debug border around.
---@param r number The color of the debug border.
---@param g number The color of the debug border.
---@param b number The color of the debug border.
---@param mouseover? boolean If true, only show the frame on mouseover.
function debug:DrawBorder(frame, r, g, b, mouseover)
  assert(frame, 'No frame provided.')
  assert(r, 'No red color provided.')
  assert(g, 'No green color provided.')
  assert(b, 'No blue color provided.')
  local border = CreateFrame("Frame", nil, frame, "ThinBorderTemplate")
  border:SetAllPoints(frame)
  for _, tex in pairs({"TopLeft", "TopRight", "BottomLeft", "BottomRight", "Top", "Bottom", "Left", "Right"}) do
    border[tex]:SetVertexColor(r, g, b)
  end
  border:SetFrameStrata("HIGH")
  if mouseover then
    frame:HookScript("OnEnter", function() border:Show() end)
    frame:HookScript("OnLeave", function() border:Hide() end)
    border:Hide()
  else
    border:Show()
  end
end