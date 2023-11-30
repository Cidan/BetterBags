local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Resize: AceModule
local resize = addon:NewModule('Resize')

---@param frame Frame
function resize:MakeResizable(frame)
  frame:SetResizable(true)
  frame:SetResizeBounds(300, 300)
  local resizeHandle = CreateFrame("Button", nil, frame)
  resizeHandle:EnableMouse(true)
  resizeHandle:SetPoint("BOTTOMRIGHT")
  resizeHandle:SetSize(16, 16)
  resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  resizeHandle:SetScript("OnMouseDown", function(p)
    p:GetParent():StartSizing("BOTTOMRIGHT")
  end)
  resizeHandle:SetScript("OnMouseUp", function(p)
    p:GetParent():StopMovingOrSizing("BOTTOMRIGHT")
  end)
end

function resize:HideResize(frame)

end