local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Animations: AceModule
local animations = addon:GetModule('Animations')

---@class Search: AceModule
---@field searchFrame SearchFrame
local search = addon:NewModule('Search')

---@class (exact) SearchFrame
---@field frame Frame
---@field fadeInGroup AnimationGroup
---@field fadeOutGroup AnimationGroup
search.searchProto = {}

-- BetterBags_ToggleSearch toggles the search view. This function is used in the
-- search key bind.
function BetterBags_ToggleSearch()
  search.searchFrame:Toggle()
end

function search.searchProto:Toggle()
  if self.frame:IsShown() then
    self.fadeOutGroup:Play()
  else
    self.fadeInGroup:Play()
  end
end

---@return SearchFrame
function search:Create()
  local sf = setmetatable({}, {__index = search.searchProto})
  local f = CreateFrame("Frame", "BetterBagsSearchFrame", UIParent, "BetterBagsSearchPanelTemplate") --[[@as Frame]]
  sf.fadeInGroup, sf.fadeOutGroup = animations:AttachFadeAndSlideLeft(f)
  f:SetSize(300, 500)
  f:SetPoint("RIGHT", UIParent, "RIGHT", -100, 0)
  f:Hide()
  sf.frame = f
  return sf
end

function search:OnEnable()
  self.searchFrame = self:Create()
end