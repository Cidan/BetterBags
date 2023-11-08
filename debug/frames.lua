local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Debug
local debug = addon:GetModule('Debug')

local LSM = LibStub('LibSharedMedia-3.0')

---@param frame BackdropTemplate The frame to draw the debug border around.
---@param r number The color of the debug border.
---@param g number The color of the debug border.
---@param b number The color of the debug border.
function debug:DrawDebugBorder(frame, r, g, b)
  assert(frame, 'No frame provided.')
  assert(r, 'No red color provided.')
  assert(g, 'No green color provided.')
  assert(b, 'No blue color provided.')
  frame:SetBackdrop({
    edgeFile = LSM:Fetch(LSM.MediaType.BORDER, "Blizzard Tooltip"),
    edgeSize = 16,
  })
  frame:SetBackdropBorderColor(r, g, b, 1)
end