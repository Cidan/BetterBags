local addon = GetBetterBags()

---@class Animations: AceModule
local animations = addon:NewModule('Animations')

---@param region Region
---@param nohide? boolean
---@return AnimationGroup, AnimationGroup
function animations:AttachFadeGroup(region, nohide)
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
    if fadeInGroup.callback then
      fadeInGroup.callback()
    end
  end)

  local fadeOutGroup = region:CreateAnimationGroup()
  local fadeOut = fadeOutGroup:CreateAnimation('Alpha')
  fadeOut:SetFromAlpha(1)
  fadeOut:SetToAlpha(0)
  fadeOut:SetDuration(0.10)
  fadeOut:SetSmoothing('IN')
  fadeOutGroup:SetScript('OnFinished', function()
    if not nohide then
      region:Hide()
    else
      region:SetAlpha(0)
    end
    if fadeOutGroup.callback then
      fadeOutGroup.callback()
    end
  end)
  return fadeInGroup, fadeOutGroup
end

---@param region Region
---@param nohide? boolean
---@return AnimationGroup, AnimationGroup
function animations:AttachFadeAndSlideLeft(region, nohide)
  local fadeInGroup, fadeOutGroup = self:AttachFadeGroup(region, nohide)
  local slideOut = fadeOutGroup:CreateAnimation('Translation')
  slideOut:SetOffset(10, 0)
  slideOut:SetDuration(0.10)
  slideOut:SetSmoothing('IN')
  return fadeInGroup, fadeOutGroup
end

---@param region Region
---@param nohide? boolean
---@return AnimationGroup, AnimationGroup
function animations:AttachFadeAndSlideTop(region, nohide)
  local fadeInGroup, fadeOutGroup = self:AttachFadeGroup(region, nohide)
  local slideOut = fadeOutGroup:CreateAnimation('Translation')
  slideOut:SetOffset(0, -10)
  slideOut:SetDuration(0.10)
  slideOut:SetSmoothing('IN')
  return fadeInGroup, fadeOutGroup
end
