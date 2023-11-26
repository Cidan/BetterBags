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

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

local LSM = LibStub('LibSharedMedia-3.0')

---@class bagButton
local bagButtonProto = {}

---@class bagSlots
---@field frame Frame
---@field content Grid
local bagSlotProto = {}

function bagSlotProto:Draw()
  for _, cell in ipairs(self.content.cells) do
    cell:Draw()
  end
  local w, h = self.content:Draw()
  self.frame:SetWidth(w + 20)
  self.frame:SetHeight(h + 38)
end

function bagSlotProto:SetShown(shown)
  if shown then
    self:Show()
  else
    self:Hide()
  end
end

function bagSlotProto:Show()
  PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
  self.frame:Show()
end

function bagSlotProto:Hide()
  PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
  self.frame:Hide()
end

function bagSlotProto:IsShown()
  return self.frame:IsShown()
end

---@param kind BagKind
---@return bagSlots
function BagSlots:CreatePanel(kind)
  ---@class bagSlots
  local b = {}
  setmetatable(b, {__index = bagSlotProto})
  local name = kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"
  ---@class Frame: BackdropTemplate
  local f = CreateFrame("Frame", name .. "BagSlots", UIParent, "BetterBagsBagSlotPanelTemplate")
  b.frame = f

  b.frame:SetTitle(L:G("Equipped Bags"))

  b.content = grid:Create(b.frame)
  b.content.frame:SetPoint("TOPLEFT", b.frame, "TOPLEFT", 12, -30)
  b.content.frame:SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMRIGHT", -12, 12)
  b.content.maxCellWidth = 10
  b.content:Show()

  local bags = kind == const.BAG_KIND.BACKPACK and const.BACKPACK_ONLY_BAGS_LIST or const.BANK_ONLY_BAGS_LIST
  for i, bag in pairs(bags) do
    local iframe = bagButton:Create()
    iframe:SetBag(bag)
    iframe:AddToMasqueGroup(kind)
    b.content:AddCell(tostring(i), iframe)
  end

  events:RegisterEvent("BAG_CONTAINER_UPDATE", function() b:Draw() end)
  b:Hide()
  return b
end