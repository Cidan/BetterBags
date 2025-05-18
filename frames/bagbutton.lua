---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Pool: AceModule
local pool = addon:GetModule('Pool')

---@class BagButtonFrame: AceModule
local BagButtonFrame = addon:NewModule('BagButton')

local buttonCount = 0

---@class BagButton
---@field frame ItemButton|Button
---@field masqueGroup string
---@field bag Enum.BagIndex
---@field empty boolean
---@field kind BagKind
---@field canBuy boolean
BagButtonFrame.bagButtonProto = {}

---@param ctx Context
function BagButtonFrame.bagButtonProto:Draw(ctx)
  if not self.bag then return end
  self:SetBag(ctx, self.bag)
end

---@param ctx Context
function BagButtonFrame.bagButtonProto:Release(ctx)
  BagButtonFrame._pool:Release(ctx, self)
end

function BagButtonFrame.bagButtonProto:CheckForPurchase()
  local _, full = GetNumBankSlots()
  if full then return end
  if not self.canBuy then return end
  local cost = GetBankSlotCost(self.bag)
  BankFrame.nextSlotCost = cost
  PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
  StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
end

---@param ctx Context
---@param bag Enum.BagIndex
function BagButtonFrame.bagButtonProto:SetBag(ctx, bag)
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
        self.frame.ItemSlotBackground:SetVertexColor(1.0,1.0,1.0)
      elseif id == self.bag then
        self.canBuy = true
        self.frame.ItemSlotBackground:SetVertexColor(1.0,0.1,0.1)
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
    self.frame.ItemSlotBackground:Show()
    self.empty = true
  end
  SetItemButtonTexture(self.frame, icon)
  SetItemButtonQuality(self.frame, GetInventoryItemQuality("player", self.invID))
  SetItemButtonCount(self.frame, 1)
  events:SendMessage(ctx, 'bagbutton/Updated', self)
end

---@param ctx Context
function BagButtonFrame.bagButtonProto:ClearBag(ctx)
  events:SendMessage(ctx, 'bagbutton/Clearing', self)
  self.masqueGroup = nil
  self.invID = nil
  self.bag = nil
  self.empty = nil
  self.kind = nil
  self.canBuy = nil
  self.frame.ItemSlotBackground:Hide()
  self.frame.ItemSlotBackground:SetVertexColor(1.0,1.0,1.0)
  SetItemButtonTexture(self.frame, nil)
  SetItemButtonQuality(self.frame, nil)
end

function BagButtonFrame.bagButtonProto:OnEnter()
  if self.empty and self.kind == const.BAG_KIND.BANK and self.canBuy then
    GameTooltip:SetOwner(self.frame, "ANCHOR_LEFT")
    GameTooltip:SetText(BANK_BAG_PURCHASE, 1, 1, 1)
    local cost = GetBankSlotCost(self.bag)
    local costInfo = strjoin("", COSTS_LABEL, " ", C_CurrencyInfo.GetCoinTextureString(cost))
    GameTooltip:AddLine(costInfo, 1, 1, 1, true)
    GameTooltip:Show()
    CursorUpdate(self.frame)
    return
  elseif self.empty then
    GameTooltip:SetOwner(self.frame, "ANCHOR_LEFT")
    if const.BACKPACK_ONLY_REAGENT_BAGS[self.bag] then
      GameTooltip:SetText(L:G("Empty Reagent Bag Slot"), 1, 1, 1)
    else
      GameTooltip:SetText(L:G("Empty Bag Slot"), 1, 1, 1)
    end
    GameTooltip:Show()
    return
  end
  GameTooltip:SetOwner(self.frame, "ANCHOR_LEFT")
  GameTooltip:SetInventoryItem("player", self.invID)
  GameTooltip:Show()
  CursorUpdate(self.frame)
end

function BagButtonFrame.bagButtonProto:OnLeave()
  GameTooltip:Hide()
end

function BagButtonFrame.bagButtonProto:OnClick()
  if InCombatLockdown() then
    print("BetterBags: "..L:G("Cannot change bags in combat."))
    return
  end
  if self.empty and self.kind == const.BAG_KIND.BANK and self.canBuy then self:CheckForPurchase() return end
  if IsModifiedClick("PICKUPITEM") then
    PickupBagFromSlot(self.invID)
  else
    PutItemInBag(self.invID)
  end
end

function BagButtonFrame.bagButtonProto:OnDragStart()
  if InCombatLockdown() then
    print("BetterBags: "..L:G("Cannot change bags in combat."))
    return
  end
  PickupBagFromSlot(self.invID)
end

function BagButtonFrame.bagButtonProto:OnReceiveDrag()
  if InCombatLockdown() then
    print("BetterBags: "..L:G("Cannot change bags in combat."))
    return
  end
  PutItemInBag(self.invID)
end

function BagButtonFrame:OnInitialize()
  self._pool = pool:Create(self._DoCreate, self._DoReset)
end

---@param ctx Context
---@return BagButton
function BagButtonFrame:Create(ctx)
  return self._pool:Acquire(ctx)
end

---@param ctx Context
---@param b BagButton
function BagButtonFrame._DoReset(ctx, b)
  b:ClearBag(ctx)
end

---@return BagButton
function BagButtonFrame:_DoCreate()
  local b = setmetatable({}, {__index = BagButtonFrame.bagButtonProto})
  local name = format("BetterBagsBagButton%d", buttonCount)
  buttonCount = buttonCount + 1

  local f = CreateFrame("ItemButton", name)
  f:SetSize(37, 37)
  f:RegisterForDrag("LeftButton")
  f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  f:SetScript("OnEnter", function() b:OnEnter() end)
  f:SetScript("OnLeave", function() b:OnLeave() end)
  f:SetScript("OnClick", function() b:OnClick() end)
  f:SetScript("OnDragStart", function() b:OnDragStart() end)
  f:SetScript("OnReceiveDrag", function() b:OnReceiveDrag() end)
  b.frame = f
  f.ItemSlotBackground = f:CreateTexture(nil, "BACKGROUND", "ItemSlotBackgroundCombinedBagsTemplate", -6);
  f.ItemSlotBackground:SetAllPoints(f);
  f.ItemSlotBackground:Hide()
  return b
end

BagButtonFrame:Enable()