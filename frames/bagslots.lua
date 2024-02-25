---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- Create the bagslot module.
---@class BagSlots: AceModule
local BagSlots = addon:NewModule('BagSlots')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class GridFrame: AceModule
local grid = addon:GetModule('Grid')

---@class BagButtonFrame: AceModule
local bagButton = addon:GetModule('BagButton')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Animations: AceModule
local animations = addon:GetModule('Animations')


---@class bagSlots
---@field frame Frame
---@field content Grid
---@field kind BagKind
---@field fadeInGroup AnimationGroup
---@field fadeOutGroup AnimationGroup
BagSlots.bagSlotProto = {}

function BagSlots.bagSlotProto:Draw()
  for _, cell in ipairs(self.content.cells) do
    cell:Draw(const.BAG_KIND.UNDEFINED, const.BAG_VIEW.UNDEFINED, false)
  end
  local w, h = self.content:Draw()
  self.frame:SetWidth(w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET + 4)
  self.frame:SetHeight(h + 42)
  events:SendMessage('bags/FullRefreshAll')
end

function BagSlots.bagSlotProto:SetShown(shown)
  if shown then
    self:Show()
  else
    self:Hide()
  end
end

function BagSlots.bagSlotProto:Show()
  PlaySound(SOUNDKIT.GUILD_BANK_OPEN_BAG)
  self.fadeInGroup:Play()
end

function BagSlots.bagSlotProto:Hide()
  PlaySound(SOUNDKIT.GUILD_BANK_OPEN_BAG)
  self.fadeOutGroup:Play()
end

function BagSlots.bagSlotProto:IsShown()
  return self.frame:IsShown()
end

---@param kind BagKind
---@return bagSlots
function BagSlots:CreatePanel(kind)
  ---@class bagSlots
  local b = {}
  setmetatable(b, {__index = BagSlots.bagSlotProto})
  local name = kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"
  ---@class Frame: BackdropTemplate
  local f = CreateFrame("Frame", name .. "BagSlots", UIParent, "BetterBagsBagSlotPanelTemplate")
  b.frame = f

  b.frame:SetTitle(L:G("Equipped Bags"))
  b.content = grid:Create(b.frame)
  b.content:GetContainer():SetPoint("TOPLEFT", b.frame, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET + 4, -30)
  b.content:GetContainer():SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMRIGHT", const.OFFSETS.BAG_RIGHT_INSET, 12)
  b.content.maxCellWidth = 10
  b.content:HideScrollBar()
  b.content:Show()

  local bags = kind == const.BAG_KIND.BACKPACK and const.BACKPACK_ONLY_BAGS_LIST or const.BANK_ONLY_BAGS_LIST
  for i, bag in pairs(bags) do
    local iframe = bagButton:Create()
    iframe:SetBag(bag)
    b.content:AddCell(tostring(i), iframe)
  end

  b.fadeInGroup, b.fadeOutGroup = animations:AttachFadeAndSlideTop(b.frame)
  b.fadeInGroup:HookScript("OnFinished", function()
    items:FullRefreshAll()
    --[[
    if b.kind == const.BAG_KIND.BACKPACK then
      addon.Bags.Backpack:Refresh()
    elseif b.kind == const.BAG_KIND.BANK then
      addon.Bags.Bank:Refresh()
    end
    ]]--
  end)
  b.fadeOutGroup:HookScript("OnFinished", function()
    items:FullRefreshAll()
    --[[
    if b.kind == const.BAG_KIND.BACKPACK and addon.Bags.Backpack then
      addon.Bags.Backpack:Refresh()
    elseif b.kind == const.BAG_KIND.BANK and addon.Bags.Bank then
      addon.Bags.Bank:Refresh()
    end
    ]]--
  end)
  events:RegisterEvent('BAG_CONTAINER_UPDATE', function() b:Draw() end)
  events:RegisterEvent('PLAYERBANKBAGSLOTS_CHANGED', function() b:Draw() end)
  b.kind = kind
  b.frame:Hide()
  return b
end