---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

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

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

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
  "IconBorder",
  "HighlightTexture"
}

function itemFrame.itemProto:UpdateCooldown()
  local decoration = themes:GetItemButton(self)
  ContainerFrame_UpdateCooldown(decoration:GetID(), decoration)
end

function itemFrame.itemProto:ResetSize()
  self:SetSize(37, 37)
end

function itemFrame.itemProto:SetSize(width, height)
  local decoration = themes:GetItemButton(self)
  self.frame:SetSize(width, height)
  self.button:SetSize(width, height)
  decoration.IconBorder:SetSize(width, height)
  decoration.IconQuestTexture:SetSize(width, height)
  decoration.IconTexture:SetSize(width, height)
end

---@param data ItemData
function itemFrame.itemProto:SetItemFromData(data)
  assert(data, 'data must be provided')
  self.slotkey = data.slotkey
  local decoration = themes:GetItemButton(self)
  local bagid, slotid = data.bagid, data.slotid
  if bagid ~= nil and slotid ~= nil then
    self.button:SetID(slotid)
    decoration:SetID(slotid)
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

  SetItemButtonQuality(decoration, data.itemInfo.itemQuality)
  decoration.minDisplayCount = 1
  SetItemButtonTexture(decoration, data.itemInfo.itemIcon)
  if database:GetExtraGlowyButtons(self.kind) and data.itemInfo.itemQuality > Enum.ItemQuality.Common then
    decoration.IconBorder:SetTexture([[Interface\Buttons\UI-ActionButton-Border]])
    decoration.IconBorder:SetBlendMode("ADD")
    decoration.IconBorder:SetTexCoord(14/64, 49/64, 15/64, 50/64)
  else
    decoration.IconBorder:SetTexture([[Interface\Common\WhiteIconFrame]])
    decoration.IconBorder:SetBlendMode("BLEND")
    decoration.IconBorder:SetTexCoord(0, 1, 0, 1)
  end
  decoration.IconBorder:SetVertexColor(unpack(const.ITEM_QUALITY_COLOR[data.itemInfo.itemQuality]))
  decoration.IconBorder:Show()
  self:UpdateCount()
  SetItemButtonDesaturated(decoration, data.itemInfo.isLocked)
  decoration.IconQuestTexture:Hide()
  --self:SetLock(data.itemInfo.isLocked)
  if data.bagid ~= nil then
    ContainerFrame_UpdateCooldown(data.bagid, decoration)
  end
  self.button.BattlepayItemTexture:SetShown(false)
  self.button.NewItemTexture:Hide()
  decoration:SetMatchesSearch(true)
  --self.button.UpgradeIcon:SetShown(IsContainerItemAnUpgrade(bagid, slotid) or false)
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
  self.freeSlotName = ""
  self.freeSlotCount = 0
  self.isFreeSlot = nil
  self:SetAlpha(1)
  if self.slotkey ~= nil then
    events:SendMessage('item/Updated', self, decoration)
  end
  self:UpdateUpgrade()
  self.frame:Show()
  self.button:Show()
end

-- SetFreeSlots will set the item button to a free slot.
---@param bagid number
---@param slotid number
---@param count number
function itemFrame.itemProto:SetFreeSlots(bagid, slotid, count)
  local decoration = themes:GetItemButton(self)
  self.slotkey = items:GetSlotKeyFromBagAndSlot(bagid, slotid)
  if const.BANK_BAGS[bagid] or const.REAGENTBANK_BAGS[bagid] then
    self.kind = const.BAG_KIND.BANK
  else
    self.kind = const.BAG_KIND.BACKPACK
  end
  if count == 0 then
    self.button:Disable()
  else
    self.button:Enable()
  end
  self.button.minDisplayCount = -1
  self.button:SetID(slotid)
  decoration:SetID(slotid)
  self.frame:SetID(bagid)
  self.freeSlotCount = count
  self.isFreeSlot = true
  local quality = self:GetBagTypeQuality(bagid)

  SetItemButtonCount(decoration, count)
  SetItemButtonQuality(decoration, false)
  SetItemButtonDesaturated(decoration, false)
  SetItemButtonTexture(decoration, [[Interface\PaperDoll\UI-Backpack-EmptySlot]])
  self:UpdateCooldown()
  decoration.IconBorder:SetTexture([[Interface\Common\WhiteIconFrame]])
  decoration.IconBorder:SetBlendMode("BLEND")
  decoration.IconBorder:SetTexCoord(0, 1, 0, 1)
  decoration.IconBorder:SetVertexColor(unpack(const.ITEM_QUALITY_COLOR[quality]))
  decoration.IconBorder:Show()
  decoration.IconQuestTexture:Hide()
  decoration.BattlepayItemTexture:SetShown(false)
  decoration.NewItemTexture:Hide()
  self.ilvlText:SetText("")
  decoration.UpgradeIcon:SetShown(false)

  self.freeSlotName = self:GetBagType(bagid)
  --SetItemButtonQuality(decoration, 4, nil, false, false)
  self:Unlock()

  decoration.IconBorder:SetBlendMode("BLEND")
  self.frame:SetAlpha(1)
  events:SendMessage('item/Updated', self, decoration)
  self.frame:Show()
  self.button:Show()
end


function itemFrame.itemProto:ClearItem()
  local decoration = themes:GetItemButton(self)
  events:SendMessage('item/Clearing', self, decoration)
  self.kind = nil
  self.frame:ClearAllPoints()
  self.frame:SetParent(nil)
  self.frame:SetAlpha(1)
  self.frame:Hide()
  SetItemButtonQuality(decoration, false)
  SetItemButtonCount(decoration, 0)
  SetItemButtonDesaturated(decoration, false)
  SetItemButtonTexture(decoration, 0)
  decoration.BattlepayItemTexture:SetShown(false)
  decoration.NewItemTexture:Hide()
  self.frame:SetID(0)
  self.button:SetID(0)
  decoration:SetID(0)
  decoration.minDisplayCount = 1
  self.button:Enable()
  self.ilvlText:SetText("")
  self:SetSize(37, 37)
  decoration.UpgradeIcon:SetShown(false)
  self.freeSlotName = ""
  self.freeSlotCount = 0
  self.isFreeSlot = nil
  self.slotkey = ""
  self.staticData = nil
  self:UpdateCooldown()
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

  -- Backwards compatibility for item data.
  i.data = setmetatable({}, { __index = function(_, key)
    local d = items:GetItemDataFromSlotKey(i.slotkey)
    if d == nil then return nil end
    return d[key]
  end})

  -- Generate the item button name. This is needed because item
  -- button textures are named after the button itself.
  local name = format("BetterBagsItemButton%d", buttonCount)
  buttonCount = buttonCount + 1
  -- Create a hidden parent to the ItemButton frame to work around
  -- item taint introduced in 10.x
  local p = CreateFrame("Button")

  ---@class Button
  local button = CreateFrame("Button", name, p, "ContainerFrameItemButtonTemplate") --[[@as Button]]

  button:GetPushedTexture():SetTexture("")
  button:GetNormalTexture():SetTexture("")

  button:HookScript("OnMouseDown", function()
    themes:GetItemButton(i):GetPushedTexture():Show()
  end)
  button:HookScript("OnMouseUp", function()
    themes:GetItemButton(i):GetPushedTexture():Hide()
  end)
  button:HookScript("OnLeave", function()
    themes:GetItemButton(i):GetHighlightTexture():Hide()
    themes:GetItemButton(i):GetPushedTexture():Hide()
  end)
  button:HookScript("OnEnter", function()
    themes:GetItemButton(i):GetHighlightTexture():Show()
  end)

  -- Assign the global item button textures to the item button.
  for _, child in pairs(children) do
    if _G[name..child] then
      _G[name..child]:Hide()
    end
  end
  button.BattlepayItemTexture:Hide()

  p:SetSize(37, 37)
  button:SetSize(37, 37)
  button:RegisterForDrag("LeftButton")
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:SetAllPoints(p)
  i.button = button

  button:HookScript("OnLeave", function()
    i:OnLeave()
  end)

  i.frame = p

  button.GetInventorySlot = ButtonInventorySlot
  button.UpdateTooltip = function() i:UpdateTooltip() end
  button:SetScript("OnEnter", function() i:UpdateTooltip() i:OnEnter() end)
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
