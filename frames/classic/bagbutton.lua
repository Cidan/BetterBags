---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class MasqueTheme: AceModule
local masque = addon:GetModule('Masque')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class BagButtonFrame: AceModule
local BagButtonFrame = addon:NewModule('BagButton')

local buttonCount = 0

---@class BagButton
---@field frame Button
---@field masqueGroup string
---@field bag Enum.BagIndex
---@field empty boolean
---@field kind BagKind
---@field canBuy boolean
local bagButtonProto = {}

function bagButtonProto:Draw()
  if not self.bag then return end
  self:SetBag(self.bag)
end

function bagButtonProto:Release()
  BagButtonFrame._pool:Release(self)
end

function bagButtonProto:CheckForPurchase()
  local _, full = GetNumBankSlots()
  if full then return end
  local cost = GetBankSlotCost(self.bag)
  BankFrame.nextSlotCost = cost
  PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
  StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
end

---@param bag Enum.BagIndex
function bagButtonProto:SetBag(bag)
  self.bag = bag
  if const.BANK_ONLY_BAGS[bag] then
    self.kind = const.BAG_KIND.BANK
  else
    self.kind = const.BAG_KIND.BACKPACK
  end
  if self.kind == const.BAG_KIND.BANK then
    local slotsPurchased = GetNumBankSlots()
    for i, id in ipairs(const.BANK_ONLY_BAGS_LIST) do
      if slotsPurchased >= i and id == self.bag  then
        self.canBuy = false
      elseif id == self.bag then
        self.canBuy = true
      end
    end
  else
    self.canBuy = false
  end

  self.invID = C_Container.ContainerIDToInventoryID(bag)
  local icon = GetInventoryItemTexture("player", self.invID) --[[@as number|string]]
  local hasItem = not not icon
  if hasItem then
    --TODO(lobato): Set count, other properties
    self.frame.ItemSlotBackground:Hide()
    self.empty = false
  else
    --icon = [[Interface\PaperDoll\UI-PaperDoll-Slot-Bag]]
    --self.frame.ItemSlotBackground:Show()
    self.empty = true
  end
  --SetItemButtonTexture(self.frame, icon)
  --SetItemButtonQuality(self.frame, GetInventoryItemQuality("player", self.invID))
  --SetItemButtonCount(self.frame, 1)
end

function bagButtonProto:ClearBag()
  masque:RemoveButtonFromGroup(self.masqueGroup, self.frame)
  self.masqueGroup = nil
  self.invID = nil
  self.bag = nil
  self.empty = nil
  self.kind = nil
  self.canBuy = nil
  --self.frame.ItemSlotBackground:Hide()
  --SetItemButtonTexture(self.frame, nil)
  --SetItemButtonQuality(self.frame, nil)
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
  if self.empty and self.kind == const.BAG_KIND.BANK and self.canBuy then
    GameTooltip:SetOwner(self.frame, "ANCHOR_LEFT")
    GameTooltip:SetText(BANK_BAG_PURCHASE, 1, 1, 1)
    local cost = GetBankSlotCost(self.bag)
    local costInfo = strjoin("", COSTS_LABEL, " ", GetCoinTextureString(cost))
    GameTooltip:AddLine(costInfo, 1, 1, 1, true)
    GameTooltip:Show()
    CursorUpdate(self.frame)
    return
  elseif self.empty then
    GameTooltip:SetOwner(self.frame, "ANCHOR_LEFT")
    GameTooltip:SetText(L:G("Empty Bag Slot"), 1, 1, 1)
    GameTooltip:Show()
    return
  end
  GameTooltip:SetOwner(self.frame, "ANCHOR_LEFT")
  GameTooltip:SetInventoryItem("player", self.invID)
  GameTooltip:Show()
  CursorUpdate(self.frame)
end

function bagButtonProto:OnLeave()
  GameTooltip:Hide()
end

function bagButtonProto:OnClick()
  if self.empty and self.kind == const.BAG_KIND.BANK then self:CheckForPurchase() return end
  if IsModifiedClick("PICKUPITEM") then
    PickupBagFromSlot(self.invID)
  else
    PutItemInBag(self.invID)
  end
end

function bagButtonProto:OnDragStart()
  PickupBagFromSlot(self.invID)
end

function bagButtonProto:OnReceiveDrag()
  PutItemInBag(self.invID)
end

function BagButtonFrame:OnInitialize()
  self._pool = CreateObjectPool(self._DoCreate, self._DoReset)
end

---@return BagButton
function BagButtonFrame:Create()
  return self._pool:Acquire()
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

  local f = CreateFrame("Button", name)
  f:SetSize(37, 37)
  f:RegisterForDrag("LeftButton")
  f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  f:SetScript("OnEnter", function() b:OnEnter() end)
  f:SetScript("OnLeave", function() b:OnLeave() end)
  f:SetScript("OnClick", function() b:OnClick() end)
  f:SetScript("OnDragStart", function() b:OnDragStart() end)
  f:SetScript("OnReceiveDrag", function() b:OnReceiveDrag() end)
  b.frame = f
  --f.ItemSlotBackground = f:CreateTexture(nil, "BACKGROUND", "ItemSlotBackgroundCombinedBagsTemplate", -6);
  --f.ItemSlotBackground:SetAllPoints(f);
  --f.ItemSlotBackground:Hide()
  return b
end

BagButtonFrame:Enable()