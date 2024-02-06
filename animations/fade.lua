local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Animations: AceModule
local animations = addon:NewModule('Animations')

---@param region Region
---@return AnimationGroup, AnimationGroup
function animations:AttachFadeGroup(region)
  local fadeInGroup = region:CreateAnimationGroup()
  local fadeIn = fadeInGroup:CreateAnimation('Alpha')
  fadeIn:SetFromAlpha(0)
  fadeIn:SetToAlpha(1)
  fadeIn:SetDuration(0.10)
  fadeIn:SetSmoothing('IN')
  fadeIn:SetScript('OnPlay', function()
    region:SetAlpha(0)
    region:Show()
  end)
  fadeInGroup:SetScript('OnFinished', function()
    region:SetAlpha(1)
    region:Show()
  end)

  local fadeOutGroup = region:CreateAnimationGroup()
  local fadeOut = fadeOutGroup:CreateAnimation('Alpha')
  fadeOut:SetFromAlpha(1)
  fadeOut:SetToAlpha(0)
  fadeOut:SetDuration(0.10)
  fadeOut:SetSmoothing('IN')
  fadeOutGroup:SetScript('OnFinished', function()
    region:Hide()
  end)
  return fadeInGroup, fadeOutGroup
end
