local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class List: AceModule
local list = addon:GetModule('List')

---@class Animations: AceModule
local animations = addon:GetModule('Animations')

---@class SectionItemList: AceModule
local sectionItemList = addon:NewModule('SectionItemList')

---@class SectionItemListElement
---@field name string

---@class SectionItemListFrame
---@field frame Frame
---@field content ListFrame
---@field package fadeIn AnimationGroup
---@field package fadeOut AnimationGroup
local sectionItemListFrame = {}

---@param callback? fun()
function sectionItemListFrame:Show(callback)
  PlaySound(SOUNDKIT.GUILD_BANK_OPEN_BAG)
  if callback then
    self.fadeIn.callback = function()
      self.fadeIn.callback = nil
      callback()
    end
  end
  self.fadeIn:Play()
end

---@param callback? fun()
function sectionItemListFrame:Hide(callback)
  PlaySound(SOUNDKIT.GUILD_BANK_OPEN_BAG)
  if callback then
    self.fadeOut.callback = function()
      self.fadeOut.callback = nil
      callback()
    end
  end
  self.fadeOut:Play()
end

function sectionItemListFrame:IsShown()
  return self.frame:IsShown()
end

---@param category string
function sectionItemListFrame:ShowCategory(category)
  if self:IsShown() then
    self:Hide(function()
      self:ShowCategory(category)
    end)
    return
  end
  -- TODO(lobato): Render stuff.
  self:Show()
end

---@param parent Frame
---@return SectionItemListFrame
function sectionItemList:Create(parent)
  local sc = setmetatable({}, {__index = sectionItemListFrame})
  sc.frame = CreateFrame("Frame", nil, parent, "DefaultPanelTemplate") --[[@as Frame]]
  sc.frame:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMLEFT', -10, 0)
  sc.frame:SetPoint('TOPRIGHT', parent, 'TOPLEFT', -10, 0)
  sc.frame:SetWidth(300)
  sc.fadeIn, sc.fadeOut = animations:AttachFadeAndSlideLeft(sc.frame)
  sc.content = list:Create(sc.frame)
  sc.content.frame:SetAllPoints()

  sc.frame:Hide()
  return sc
end