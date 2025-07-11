---@diagnostic disable: duplicate-set-field,duplicate-doc-field



local addon = GetBetterBags()

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Events: AceModule
local events = addon:GetModule('Events')

local L = addon:GetLocalization()

---@class BagButtonFrame: AceModule
local BagButtonFrame = addon:GetModule('BagButton')

local buttonCount = 0


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
        self.frame:GetNormalTexture():SetVertexColor(1.0,1.0,1.0)
      elseif id == self.bag then
        self.canBuy = true
        self.frame:GetNormalTexture():SetVertexColor(1.0,0.1,0.1)
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
    SetItemButtonTexture(self.frame, icon)
    self.frame:GetNormalTexture():SetVertexColor(1.0,1.0,1.0)
    self.empty = false
  else
    local _, texture = GetInventorySlotInfo("Bag"..bag)
    SetItemButtonTexture(self.frame, texture)
    --icon = [[Interface\PaperDoll\UI-PaperDoll-Slot-Bag]]
    --self.frame.ItemSlotBackground:Show()
    self.empty = true
  end
  events:SendMessage(ctx, 'bagbutton/Updated', self)
  --SetItemButtonTexture(self.frame, icon)
  --SetItemButtonQuality(self.frame, GetInventoryItemQuality("player", self.invID))
  --SetItemButtonCount(self.frame, 1)
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
  self.frame:GetNormalTexture():SetVertexColor(1.0,1.0,1.0)
  --SetItemButtonTexture(self.frame, nil)
  --SetItemButtonQuality(self.frame, nil)
end


---@return BagButton
function BagButtonFrame:_DoCreate()
  local b = setmetatable({}, {__index = BagButtonFrame.bagButtonProto})
  local name = format("BetterBagsBagButton%d", buttonCount)
  buttonCount = buttonCount + 1

  local f = CreateFrame("Button", name, nil, "ItemButtonTemplate") --[[@as Button]]
  f:SetSize(37, 37)
  f:RegisterForDrag("LeftButton")
  f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  f:SetScript("OnEnter", function() b:OnEnter() end)
  f:SetScript("OnLeave", function() b:OnLeave() end)
  f:SetScript("OnClick", function() b:OnClick() end)
  f:SetScript("OnDragStart", function() b:OnDragStart() end)
  f:SetScript("OnReceiveDrag", function() b:OnReceiveDrag() end)
  b.frame = f
  --f.ItemSlotBackground:SetTexture([[Interface\PaperDoll\UI-Backpack-EmptySlot]])
  --f.ItemSlotBackground:SetTexture(texture)
  --f.ItemSlotBackground:Hide()
  return b
end

BagButtonFrame:Enable()