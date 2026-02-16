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

  local border = CreateFrame("Frame", nil, frame)
  border:SetAllPoints(frame)
  border:SetFrameStrata("HIGH")

  -- Create textures manually for each edge (compatible with all WoW versions)
  local textures = {}

  -- Top Left Corner
  textures.TopLeft = border:CreateTexture(nil, "BORDER")
  textures.TopLeft:SetTexture("Interface\\Common\\ThinBorder2-Corner")
  textures.TopLeft:SetSize(8, 8)
  textures.TopLeft:SetPoint("TOPLEFT", border, "TOPLEFT", -3, 3)
  textures.TopLeft:SetVertexColor(r, g, b)

  -- Top Right Corner
  textures.TopRight = border:CreateTexture(nil, "BORDER")
  textures.TopRight:SetTexture("Interface\\Common\\ThinBorder2-Corner")
  textures.TopRight:SetSize(8, 8)
  textures.TopRight:SetPoint("TOPRIGHT", border, "TOPRIGHT", 3, 3)
  textures.TopRight:SetTexCoord(1, 0, 0, 1)
  textures.TopRight:SetVertexColor(r, g, b)

  -- Bottom Left Corner
  textures.BottomLeft = border:CreateTexture(nil, "BORDER")
  textures.BottomLeft:SetTexture("Interface\\Common\\ThinBorder2-Corner")
  textures.BottomLeft:SetSize(8, 8)
  textures.BottomLeft:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", -3, -3)
  textures.BottomLeft:SetTexCoord(0, 1, 1, 0)
  textures.BottomLeft:SetVertexColor(r, g, b)

  -- Bottom Right Corner
  textures.BottomRight = border:CreateTexture(nil, "BORDER")
  textures.BottomRight:SetTexture("Interface\\Common\\ThinBorder2-Corner")
  textures.BottomRight:SetSize(8, 8)
  textures.BottomRight:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 3, -3)
  textures.BottomRight:SetTexCoord(1, 0, 1, 0)
  textures.BottomRight:SetVertexColor(r, g, b)

  -- Top Edge
  textures.Top = border:CreateTexture(nil, "BORDER")
  textures.Top:SetTexture("Interface\\Common\\ThinBorder2-Top")
  textures.Top:SetPoint("TOPLEFT", textures.TopLeft, "TOPRIGHT")
  textures.Top:SetPoint("BOTTOMRIGHT", textures.TopRight, "BOTTOMLEFT")
  textures.Top:SetVertexColor(r, g, b)

  -- Bottom Edge
  textures.Bottom = border:CreateTexture(nil, "BORDER")
  textures.Bottom:SetTexture("Interface\\Common\\ThinBorder2-Top")
  textures.Bottom:SetPoint("TOPLEFT", textures.BottomLeft, "TOPRIGHT")
  textures.Bottom:SetPoint("BOTTOMRIGHT", textures.BottomRight, "BOTTOMLEFT")
  textures.Bottom:SetTexCoord(0, 1, 1, 0)
  textures.Bottom:SetVertexColor(r, g, b)

  -- Left Edge
  textures.Left = border:CreateTexture(nil, "BORDER")
  textures.Left:SetTexture("Interface\\Common\\ThinBorder2-Left")
  textures.Left:SetPoint("TOPLEFT", textures.TopLeft, "BOTTOMLEFT")
  textures.Left:SetPoint("BOTTOMRIGHT", textures.BottomLeft, "TOPRIGHT")
  textures.Left:SetVertexColor(r, g, b)

  -- Right Edge
  textures.Right = border:CreateTexture(nil, "BORDER")
  textures.Right:SetTexture("Interface\\Common\\ThinBorder2-Left")
  textures.Right:SetPoint("TOPLEFT", textures.TopRight, "BOTTOMLEFT")
  textures.Right:SetPoint("BOTTOMRIGHT", textures.BottomRight, "TOPRIGHT")
  textures.Right:SetTexCoord(1, 0, 0, 1)
  textures.Right:SetVertexColor(r, g, b)

  -- Store references for potential future use
  for key, texture in pairs(textures) do
    border[key] = texture
  end

  if mouseover then
    frame:HookScript("OnEnter", function() border:Show() end)
    frame:HookScript("OnLeave", function() border:Hide() end)
    border:Hide()
  else
    border:Show()
  end
end

-- WalkAndFixAnchorGraph will fix the anchor graph of a frame. Use this function
-- to fix the dreaded "frames disappear unless you move the parent" bug.
---@param frame Frame
---@param visited? table<Frame, boolean>
function debug:WalkAndFixAnchorGraph(frame, visited)
  visited = visited or {};

  if visited[frame] then
    return
  end

  visited[frame] = true;
  frame:GetSize()
  for i = 1, frame:GetNumPoints() do
    local _, relativeTo = frame:GetPoint(i);
    if relativeTo then
      self:WalkAndFixAnchorGraph(relativeTo --[[@as Frame]], visited);
    end
  end
end
