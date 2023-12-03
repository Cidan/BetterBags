local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Debug
local debug = addon:GetModule('Debug')

---@param frame Frame The frame to draw the debug border around.
---@param r number The color of the debug border.
---@param g number The color of the debug border.
---@param b number The color of the debug border.
---@param offset? boolean Whether to offset the border by 2px or not.
function debug:DrawBorder(frame, r, g, b, offset)
  assert(frame, 'No frame provided.')
  assert(r, 'No red color provided.')
  assert(g, 'No green color provided.')
  assert(b, 'No blue color provided.')
  local border = CreateFrame("Frame", nil, frame, "ThinBorderTemplate")
  if offset then
    border:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
  else
    border:SetAllPoints(frame)
  end
  for _, tex in pairs({"TopLeft", "TopRight", "BottomLeft", "BottomRight", "Top", "Bottom", "Left", "Right"}) do
    border[tex]:SetVertexColor(r, g, b)
  end
  border:SetFrameStrata("HIGH")
  border:Show()
end