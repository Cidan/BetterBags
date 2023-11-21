local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class MasqueTheme: AceModule
local masque = addon:GetModule('Masque')

---@class BagButtonFrame: AceModule
local BagButtonFrame = addon:NewModule('BagButton')

local buttonCount = 0

---@class BagButton
---@field frame ItemButton
---@field masqueGroup string
---@field bag number
local bagButtonProto = {}

function bagButtonProto:Draw()
  if not self.bag then return end
  self:SetBag(self.bag)
end

---@param bag number
function bagButtonProto:SetBag(bag)
  self.bag = bag
  self.invID = C_Container.ContainerIDToInventoryID(bag)
  local icon = GetInventoryItemTexture("player", self.invID) --[[@as number|string]]
  local hasItem = not not icon
  if hasItem then
    --TODO(lobato): Set count, other properties
  else
    icon = [[Interface\PaperDoll\UI-PaperDoll-Slot-Bag]]
  end
  SetItemButtonTexture(self.frame, icon)
  SetItemButtonQuality(self.frame, GetInventoryItemQuality("player", self.invID))
  SetItemButtonCount(self.frame, 1)
end

function bagButtonProto:ClearBag()
  masque:RemoveButtonFromGroup(self.masqueGroup, self.frame)
  self.masqueGroup = nil
  self.invID = nil
  self.bag = nil
  SetItemButtonTexture(self.frame, nil)
  SetItemButtonQuality(self.frame, nil)
end

---@param kind BagKind
function bagButtonProto:AddToMasqueGroup(kind)
  if kind == const.BAG_KIND.BANK then
    self.masqueGroup = "Bank"
    masque:AddButtonToGroup(self.masqueGroup, self.frame)
  else
    self.masqueGroup = "Backpack"
    masque:AddButtonToGroup(self.masqueGroup, self.frame)
  end
end

function bagButtonProto:OnEnter()
  GameTooltip:SetOwner(self.frame, "ANCHOR_LEFT")
  GameTooltip:SetInventoryItem("player", self.invID)
  GameTooltip:Show()
  CursorUpdate(self.frame)
end

function bagButtonProto:OnLeave()
  GameTooltip:Hide()
end

function bagButtonProto:OnClick()
  if IsModifiedClick("PICKUPITEM") then
    PickupBagFromSlot(self.invID)
  else
    PutItemInBag(self.invID)
  end
end

function BagButtonFrame:OnInitialize()
  self._pool = CreateObjectPool(self._DoCreate, self._DoReset)
end

---@return BagButton
function BagButtonFrame:Create()
  return self._pool:Acquire()
end

---@param b BagButton
function BagButtonFrame:Release(b)
  self._pool:Release(b)
end

---@param b BagButton
function BagButtonFrame:_DoReset(b)
  b:ClearBag()
end

---@return BagButton
function BagButtonFrame:_DoCreate()
  local b = setmetatable({}, {__index = bagButtonProto})
  local name = format("BetterBagsBagButton%d", buttonCount)
  buttonCount = buttonCount + 1

  local f = CreateFrame("ItemButton", name)
  f:SetSize(37, 37)
  f:RegisterForDrag("LeftButton")
  f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  f:SetScript("OnEnter", function() b:OnEnter() end)
  f:SetScript("OnLeave", function() b:OnLeave() end)
  f:SetScript("OnClick", function() b:OnClick() end)
  b.frame = f
  return b
end

BagButtonFrame:Enable()