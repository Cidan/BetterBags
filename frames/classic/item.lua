---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class MasqueTheme: AceModule
local masque = addon:GetModule('Masque')

---@class ItemFrame: AceModule
local itemFrame = addon:GetModule('ItemFrame')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Color: AceModule
local color = addon:GetModule('Color')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class EquipmentSets: AceModule
local equipmentSets = addon:GetModule('EquipmentSets')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

local buttonCount = 0
local children = {
  "IconQuestTexture",
  "IconTexture",
  "Count",
  "Stock",
  "IconBorder",
  "Cooldown",
  "NormalTexture",
  "NewItemTexture",
  "IconOverlay2",
  "ItemContextOverlay",
  "IconBorder"
}

function itemFrame.itemProto:UpdateCooldown()
  ContainerFrame_UpdateCooldown(self.frame:GetID(), self.button)
end

---@param data ItemData
function itemFrame.itemProto:SetItem(data)
  assert(data, 'item must be provided')
  self.data = data
  --local tooltipOwner = GameTooltip:GetOwner();
  local bagid, slotid = data.bagid, data.slotid
  if bagid ~= nil and slotid ~= nil then
    self.button:SetID(slotid)
    self.frame:SetID(bagid)
    if const.BANK_BAGS[bagid] or const.REAGENTBANK_BAGS[bagid] then
      self.kind = const.BAG_KIND.BANK
    else
      self.kind = const.BAG_KIND.BACKPACK
    end
  else
    self.kind = const.BAG_KIND.BACKPACK
  end

  if data.isItemEmpty then
    return
  end


  local ilvlOpts = database:GetItemLevelOptions(self.kind)
  if (ilvlOpts.enabled and data.itemInfo.currentItemLevel > 0 and data.itemInfo.currentItemCount == 1) and
    (data.itemInfo.classID == Enum.ItemClass.Armor or
    data.itemInfo.classID == Enum.ItemClass.Weapon or
    data.itemInfo.classID == Enum.ItemClass.Gem) then
      self.ilvlText:SetText(tostring(data.itemInfo.currentItemLevel) or "")
      if ilvlOpts.color then
        local r, g, b = color:GetItemLevelColor(data.itemInfo.currentItemLevel)
        self.ilvlText:SetTextColor(r, g, b, 1)
      else
        self.ilvlText:SetTextColor(1, 1, 1, 1)
      end
      self.ilvlText:Show()
  else
    self.ilvlText:Hide()
  end

  self.button.minDisplayCount = 1
  SetItemButtonTexture(self.button, data.itemInfo.itemIcon)
  self.button.IconBorder:SetTexture([[Interface\Common\WhiteIconFrame]])
  self.button.IconBorder:SetVertexColor(unpack(const.ITEM_QUALITY_COLOR[data.itemInfo.itemQuality]))
  self.button.IconBorder:SetBlendMode("BLEND")
  self.button.IconBorder:Show()
  SetItemButtonCount(self.button, data.itemInfo.currentItemCount)
  SetItemButtonDesaturated(self.button, data.itemInfo.isLocked)
  self.IconQuestTexture:Hide()
  self:SetLock(data.itemInfo.isLocked)
  if data.bagid ~= nil then
    ContainerFrame_UpdateCooldown(data.bagid, self.button)
  end
  self.button.BattlepayItemTexture:SetShown(false)
  self.button.NewItemTexture:Hide()
  self.button.UpgradeIcon:SetShown(PawnIsContainerItemAnUpgrade and PawnIsContainerItemAnUpgrade(bagid, slotid) or false)
  --self.button:SetItemButtonTexture(data.itemInfo.itemIcon)
  --self.button.
--[[
  ClearItemButtonOverlay(self.button)
  self.button:SetHasItem(data.itemInfo.itemIcon)
  self.button:SetItemButtonTexture(data.itemInfo.itemIcon)
  SetItemButtonQuality(self.button, data.itemInfo.itemQuality, data.itemInfo.itemLink, false, bound);
  SetItemButtonCount(self.button, data.itemInfo.currentItemCount)
  SetItemButtonDesaturated(self.button, data.itemInfo.isLocked)
  self.button:UpdateExtended()
  self.button:UpdateQuestItem(isQuestItem, questID, isActive)
  self.button:UpdateNewItem(data.itemInfo.itemQuality)
  self.button:UpdateJunkItem(data.itemInfo.itemQuality, noValue)
  self.button:UpdateItemContextMatching()
  self.button:UpdateCooldown(data.itemInfo.itemIcon)
  self.button:SetReadable(readable)
  self.button:CheckUpdateTooltip(tooltipOwner)
  self.button:SetMatchesSearch(not isFiltered)
--]]
  self:AddToMasqueGroup()
  self:SetAlpha(1)
  self.frame:Show()
  self.button:Show()
end


-- SetFreeSlots will set the item button to a free slot.
---@param bagid number
---@param slotid number
---@param count number
---@param reagent boolean
function itemFrame.itemProto:SetFreeSlots(bagid, slotid, count, reagent)
  if const.BANK_BAGS[bagid] or const.REAGENTBANK_BAGS[bagid] then
    self.kind = const.BAG_KIND.BANK
  else
    self.kind = const.BAG_KIND.BACKPACK
  end
  self.data = {bagid = bagid, slotid = slotid, isItemEmpty = true, itemInfo = {}} --[[@as table]]
  if count == 0 then
    self.button:Disable()
  else
    self.button:Enable()
  end
  self.button.minDisplayCount = -1
  self.button:SetID(slotid)
  self.frame:SetID(bagid)

  SetItemButtonCount(self.button, count)
  SetItemButtonQuality(self.button, false)
  SetItemButtonDesaturated(self.button, false)
  SetItemButtonTexture(self.button, [[Interface\PaperDoll\UI-Backpack-EmptySlot]])
  self.button.IconBorder:SetTexture([[Interface\Common\WhiteIconFrame]])
  self.button.IconBorder:SetVertexColor(unpack(const.ITEM_QUALITY_COLOR[Enum.ItemQuality.Common]))
  self.button.IconBorder:Show()
  self.IconQuestTexture:Hide()
  self.button.BattlepayItemTexture:SetShown(false)
  self.button.NewItemTexture:Hide()
  self.ilvlText:SetText("")
  self.LockTexture:Hide()
  self.button.UpgradeIcon:SetShown(false)

  if reagent then
    SetItemButtonQuality(self.button, Enum.ItemQuality.Artifact, nil, false, false)
  end

  self:AddToMasqueGroup()
  self.button.IconBorder:SetBlendMode("BLEND")
  self.frame:SetAlpha(1)
  self.frame:Show()
  self.button:Show()
end


function itemFrame.itemProto:ClearItem()
  self:RemoveFromMasqueGroup()
  self.kind = nil
  self.frame:ClearAllPoints()
  self.frame:SetParent(nil)
  self.frame:SetAlpha(1)
  self.frame:Hide()
  --self.button:SetHasItem(false)
  --self.button:SetItemButtonTexture(0)
 -- self.button:UpdateQuestItem(false, nil, nil)
  --self.button:UpdateNewItem(false)
  --self.button:UpdateJunkItem(false, false)
  --self.button:UpdateItemContextMatching()
  SetItemButtonQuality(self.button, false)
  SetItemButtonCount(self.button, 0)
  SetItemButtonDesaturated(self.button, false)
  SetItemButtonTexture(self.button, 0)
  self.button.BattlepayItemTexture:SetShown(false)
  self.button.NewItemTexture:Hide()
  --ClearItemButtonOverlay(self.button)
  self.frame:SetID(0)
  self.button:SetID(0)
  self.button.minDisplayCount = 1
  self.button:Enable()
  self.ilvlText:SetText("")
  self.LockTexture:Hide()
  self:SetSize(37, 37)
  self.button.UpgradeIcon:SetShown(false)
  self.data = nil
end

function itemFrame.itemProto:UpdateTooltip()
  if self.button:GetParent():GetID() == -1 then
    BankFrameItemButton_OnEnter(self.button)
  else
    ContainerFrameItemButton_OnEnter(self.button)
  end
end

---@return Item
function itemFrame:_DoCreate()
  local i = setmetatable({}, { __index = itemFrame.itemProto })
  -- Generate the item button name. This is needed because item
  -- button textures are named after the button itself.
  local name = format("BetterBagsItemButton%d", buttonCount)
  buttonCount = buttonCount + 1
  -- Create a hidden parent to the ItemButton frame to work around
  -- item taint introduced in 10.x
  local p = CreateFrame("Button")

  ---@class Button
  local button = CreateFrame("Button", name, p, "ContainerFrameItemButtonTemplate") --[[@as Button]]
  -- Assign the global item button textures to the item button.
  for _, child in pairs(children) do
    i[child] = _G[name..child] ---@type texture
  end

  p:SetSize(37, 37)
  button:SetSize(37, 37)
  button:RegisterForDrag("LeftButton")
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:SetPassThroughButtons("MiddleButton")
  button:SetAllPoints(p)
  i.button = button
  i.frame = p

  i.LockTexture = button:CreateTexture(name.."LockButton", "OVERLAY")
  i.LockTexture:SetAtlas("UI-CharacterCreate-PadLock")
  i.LockTexture:SetPoint("TOP")
  i.LockTexture:SetSize(32,32)
  i.LockTexture:SetVertexColor(255/255, 66/255, 66/255)
  i.LockTexture:Hide()

  p:RegisterForClicks("MiddleButtonUp")
  p:SetScript("OnClick", function()
    i:ToggleLock()
  end)

  button.SetMatchesSearch = function(me, match)
    if match then
      me.searchOverlay:Hide()
    else
      me.searchOverlay:Show()
    end
  end

  button.GetInventorySlot = ButtonInventorySlot
  button.UpdateTooltip = function() i:UpdateTooltip() end
  button:SetScript("OnEnter", function() i:UpdateTooltip() end)
  local ilvlText = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  ilvlText:SetPoint("BOTTOMLEFT", 2, 2)

  i.ilvlText = ilvlText

  return i
end

---@return Item
function itemFrame:Create()
  ---@return Item
  return self._pool:Acquire()
end
