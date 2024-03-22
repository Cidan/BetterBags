---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class ItemFrame: AceModule
---@field emptyItemTooltip GameTooltip
local itemFrame = addon:NewModule('ItemFrame')

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

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class ItemStack
---@field button Item
---@field data? ItemData
---@field children? table<string, ItemData>

---@class (exact) Item
---@field frame Frame
---@field button ItemButton|Button
---@field data ItemData
---@field stacks table<string, ItemData>
---@field stackCount number
---@field stackid number
---@field isFreeSlot boolean
---@field freeSlotName string
---@field freeSlotCount number
---@field kind BagKind
---@field masqueGroup string
---@field ilvlText FontString
---@field IconTexture Texture
---@field Count FontString
---@field Stock FontString
---@field IconBorder Texture
---@field IconQuestTexture Texture
---@field NormalTexture Texture
---@field NewItemTexture Texture
---@field IconOverlay Texture
---@field ItemContextOverlay Texture
---@field Cooldown Cooldown
---@field UpdateTooltip function
---@field LockTexture Texture
---@field IconQuestTexture Texture
itemFrame.itemProto = {}

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
  "ItemContextOverlay",
  "UpgradeIcon"
}

-- parseQuery will parse a query string and return a set of boolean
-- filters that can be matched against an item.
---@param query string
---@return string[]
local function parseQuery(query)
  local filters = {}
  for filter in string.gmatch(query, "([^&]+)") do
      table.insert(filters, string.trim(filter))
  end
  return filters
end

---@param filter string
---@param data ItemData
---@return boolean
local function matchFilter(filter, data)
  if filter == "" then return true end
  if data.isItemEmpty then return false end
  ---@type string, string
  local prefix, value = strsplit(":", filter, 2)
  -- If no prefix is provided, assume the filter is a name or type filter.
  if value == nil then
    if
    data.itemInfo.itemName and (
    string.find(data.itemInfo.itemName:lower(), prefix, 1, true) or
    string.find(data.itemInfo.itemType:lower(), prefix, 1, true) or
    string.find(data.itemInfo.itemSubType:lower(), prefix, 1, true)) then
      return true
    end
    return false
  -- If the value exists but is empty, user is typing and we should not match.
  elseif value == "" then return false end

  -- If a prefix is provided, match against the prefix first. Prefix
  -- keywords are exact matches.
  if prefix == "type" then
    if string.find(data.itemInfo.itemType:lower(), value, 1, true) then
      return true
    end
  elseif prefix == "subtype" then
    if string.find(data.itemInfo.itemSubType:lower(), value, 1, true) then
      return true
    end
  elseif prefix == "name" then
    if string.find(data.itemInfo.itemName:lower(), value, 1, true) then
      return true
    end
  elseif prefix == "exp" and data.itemInfo.expacID ~= nil and const.BRIEF_EXPANSION_MAP[data.itemInfo.expacID] ~= nil then
    if string.find(const.BRIEF_EXPANSION_MAP[data.itemInfo.expacID]:lower(), value, 1, true) then
      return true
    end
  elseif prefix == "gear" and data.itemInfo.equipmentSet ~= nil then
    if string.find(data.itemInfo.equipmentSet:lower(), value, 1, true) then
      return true
    end
  end
  return false
end

---@param text? string
function itemFrame.itemProto:UpdateSearch(text)
  if not text or text == "" then
    self.button:SetMatchesSearch(true)
    return
  end
  local filters = parseQuery(string.lower(text))
  for _, filter in pairs(filters) do
    if not matchFilter(filter, self.data) then
      self.button:SetMatchesSearch(false)
      return
    end
  end
  self.button:SetMatchesSearch(true)
end

function itemFrame.itemProto:OnEnter()
  debug:ShowItemTooltip(self)
  if not self.isFreeSlot then return end
  if not self.freeSlotName or self.freeSlotName == "" then return end
  if self.freeSlotCount == -1 then return end

  itemFrame.emptyItemTooltip:SetOwner(self.frame, "ANCHOR_NONE")
  ContainerFrameItemButton_CalculateItemTooltipAnchors(self.frame, itemFrame.emptyItemTooltip)
  itemFrame.emptyItemTooltip:AddLine(self.freeSlotName)
  itemFrame.emptyItemTooltip:AddLine("\n")
  itemFrame.emptyItemTooltip:AddDoubleLine(L:G("Free Slots"), self.freeSlotCount, 1, 1, 1, 1, 1, 1)
  itemFrame.emptyItemTooltip:Show()
end

function itemFrame.itemProto:OnLeave()
  debug:HideItemTooltip(self)
  itemFrame.emptyItemTooltip:Hide()
end

function itemFrame.itemProto:UpdateCooldown()
  if self.data == nil or self.data.isItemEmpty then return end
  self.button:UpdateCooldown(self.data.itemInfo.itemIcon)
end

function itemFrame.itemProto:ToggleLock()
  if self.data.isItemEmpty or self.data.basic then return end
  local itemLocation = ItemLocation:CreateFromBagAndSlot(self.data.bagid, self.data.slotid)
  if C_Item.IsLocked(itemLocation) then
    self:Unlock()
  else
    self:Lock()
  end
end

function itemFrame.itemProto:SetLock(lock)
  if self.data.isItemEmpty or self.data.basic then return end
  if lock then
    self:Lock()
  else
    self:Unlock()
  end
end

function itemFrame.itemProto:Lock()
  if self.data.isItemEmpty or self.data.basic then return end
  local itemLocation = ItemLocation:CreateFromBagAndSlot(self.data.bagid, self.data.slotid)
  if itemLocation == nil or (itemLocation.IsValid and not itemLocation:IsValid()) then return end
  C_Item.LockItem(itemLocation)
  self.data.itemInfo.isLocked = true
  SetItemButtonDesaturated(self.button, self.data.itemInfo.isLocked)
  self.LockTexture:Show()
  self.ilvlText:Hide()
  database:SetItemLock(self.data.itemInfo.itemGUID, true)
end

function itemFrame.itemProto:Unlock()
  if self.data.isItemEmpty or self.data.basic then return end
  local itemLocation = ItemLocation:CreateFromBagAndSlot(self.data.bagid, self.data.slotid)
  if itemLocation == nil or (itemLocation.IsValid and not itemLocation:IsValid()) then return end
  C_Item.UnlockItem(itemLocation)
  self.data.itemInfo.isLocked = false
  SetItemButtonDesaturated(self.button, self.data.itemInfo.isLocked)
  self.LockTexture:Hide()
  self:DrawItemLevel()
  database:SetItemLock(self.data.itemInfo.itemGUID, false)
end

function itemFrame.itemProto:ShowItemLevel()
  local ilvlOpts = database:GetItemLevelOptions(self.kind)
  local ilvl = self.data.itemInfo.currentItemLevel
  self.ilvlText:SetText(tostring(ilvl))
  if ilvlOpts.color then
    local r, g, b = color:GetItemLevelColor(ilvl)
    self.ilvlText:SetTextColor(r, g, b, 1)
  else
    self.ilvlText:SetTextColor(1, 1, 1, 1)
  end
  self.ilvlText:Show()
end

function itemFrame.itemProto:DrawItemLevel()
  local data = self.data
  local ilvlOpts = database:GetItemLevelOptions(self.kind)
  local mergeOpts = database:GetStackingOptions(self.kind)
  local ilvl = data.itemInfo.currentItemLevel

  if not ilvlOpts.enabled then
    self.ilvlText:Hide()
    return
  end

  if (data.itemInfo.classID ~= Enum.ItemClass.Armor and
  data.itemInfo.classID ~= Enum.ItemClass.Weapon) then
    self.ilvlText:Hide()
    return
  end

  if mergeOpts.mergeUnstackable and data.stackedCount and data.stackedCount > 1 then
    self.ilvlText:Hide()
    return
  end

  if not ilvl or ilvl < 2 then
    self.ilvlText:Hide()
    return
  end

  self:ShowItemLevel()
end

function itemFrame.itemProto:UpdateCount()
  if self.data == nil or self.data.isItemEmpty then return end
  local count = self.data.stackedCount or self.data.itemInfo.currentItemCount
  SetItemButtonCount(self.button, count)
end

---@param data ItemData
function itemFrame.itemProto:AddToStack(data)
  if self.stacks[data.itemInfo.itemGUID] ~= nil then
    return
  end
  self.stacks[data.itemInfo.itemGUID] = data
  self.stackCount = self.stackCount + 1
end

function itemFrame.itemProto:RemoveFromStack(guid)
  if self.stacks[guid] == nil then
    return
  end
  self.stacks[guid] = nil
  self.stackCount = self.stackCount - 1
end

function itemFrame.itemProto:IsInStack(guid)
  return self.stacks[guid] ~= nil
end

function itemFrame.itemProto:HasStacks()
  return self.stackCount > 1
end

function itemFrame.itemProto:PromoteStack()
  for guid, data in pairs(self.stacks) do
    self:RemoveFromStack(guid)
    self:SetItem(data)
    return
  end
end

function itemFrame.itemProto:ClearStacks()
  wipe(self.stacks)
  self.stackCount = 1
  self:UpdateCount()
end

---@param item Item
function itemFrame.itemProto:MergeStacks(item)
  if not self:IsInStack(item.data.itemInfo.itemGUID) then
    self:AddToStack(item.data)
  end
  for guid, data in pairs(item.stacks) do
    if not self:IsInStack(guid) and data ~= nil and not data.isItemEmpty then
      self:AddToStack(data)
    end
  end
  item:ClearStacks()
end

---@param data ItemData
function itemFrame.itemProto:SetItem(data)
  assert(data, 'item must be provided')
  self.data = data
  local tooltipOwner = GameTooltip:GetOwner();
  local bagid, slotid = data.bagid, data.slotid
  if bagid and slotid then
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

  -- TODO(lobato): Figure out what to do with empty items.
  if data.isItemEmpty then
    return
  end

  local questInfo = data.questInfo
  local info = data.containerInfo
  local readable = info and info.isReadable;
  local isFiltered = info and info.isFiltered;
  local noValue = info and info.hasNoValue;
  local isQuestItem = questInfo.isQuestItem;
  local questID = questInfo.questID;
  local isActive = questInfo.isActive

  local bound = data.itemInfo.isBound

  self.stackid = data.itemInfo.itemID
  self.button.minDisplayCount = 1
  self:DrawItemLevel()
  self.button.ItemSlotBackground:Hide()
  ClearItemButtonOverlay(self.button)
  self.button:SetHasItem(data.itemInfo.itemIcon)
  self.button:SetItemButtonTexture(data.itemInfo.itemIcon)
  SetItemButtonQuality(self.button, data.itemInfo.itemQuality, data.itemInfo.itemLink, false, bound);
  self:UpdateCount()
  self:SetLock(data.itemInfo.isLocked)
  self.button:UpdateExtended()
  self.button:UpdateQuestItem(isQuestItem, questID, isActive)
  self.button:UpdateNewItem(data.itemInfo.itemQuality)
  self.button:UpdateJunkItem(data.itemInfo.itemQuality, noValue)
  self.button:UpdateItemContextMatching()
  self.button:UpdateCooldown(data.itemInfo.itemIcon)
  self.button:SetReadable(readable)
  self.button:CheckUpdateTooltip(tooltipOwner)
  self.button:SetMatchesSearch(not isFiltered)

  self.freeSlotName = ""
  self.freeSlotCount = 0
  self.isFreeSlot = nil
  self:SetAlpha(1)
  events:SendMessage('item/Updated', self)
  self.frame:Show()
  self.button:Show()
end

function itemFrame.itemProto:ResetSize()
  self:SetSize(37, 37)
  self.button.NormalTexture:SetSize(64, 64)
end

function itemFrame.itemProto:SetSize(width, height)
  self.frame:SetSize(width, height)
  self.button:SetSize(width, height)
  self.button.IconBorder:SetSize(width, height)
  self.button.NormalTexture:SetSize(64/width, 64/height)
  self.IconQuestTexture:SetSize(width, height)
  self.IconTexture:SetSize(width, height)
  self.IconOverlay:SetSize(width, height)
end

-- SetFreeSlots will set the item button to a free slot.
---@param bagid number
---@param slotid number
---@param count number
---@param name string
function itemFrame.itemProto:SetFreeSlots(bagid, slotid, count, name)
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
    self.button:SetID(slotid)
    self.frame:SetID(bagid)
  end

  self.stackCount = 1
  self.button.minDisplayCount = -1
  self.freeSlotCount = count

  ClearItemButtonOverlay(self.button)
  self.button:SetHasItem(false)
  SetItemButtonCount(self.button, count)
  self.button:SetItemButtonTexture(0)
  self.button:UpdateQuestItem(false, nil, nil)
  self.button:UpdateNewItem(false)
  self.button:UpdateJunkItem(false, false)
  self.button:UpdateItemContextMatching()
  SetItemButtonDesaturated(self.button, false)
  self.ilvlText:SetText("")
  self.ilvlText:Hide()
  self.LockTexture:Hide()
  self.button.UpgradeIcon:SetShown(false)

  self.freeSlotName = name
  SetItemButtonQuality(self.button, Enum.ItemQuality.Common, nil, false, false)

  self.isFreeSlot = true
  self.button.ItemSlotBackground:Show()
  self.frame:SetAlpha(1)
  events:SendMessage('item/Updated', self)
  self.frame:Show()
  self.button:Show()
end

---@return boolean
function itemFrame.itemProto:IsNewItem()
  if self.button.NewItemTexture:IsShown() then
    return true
  end
  return self.data.itemInfo.isNewItem
end

---@param alpha number
function itemFrame.itemProto:SetAlpha(alpha)
  self.frame:SetAlpha(alpha)
end

function itemFrame.itemProto:Release()
  itemFrame._pool:Release(self)
end

function itemFrame.itemProto:Wipe()
  self.frame:Hide()
  self.frame:SetParent(nil)
  self.frame:ClearAllPoints()
end

-- Unlink will remove and hide this item button
-- but will not release it back to the pool nor
-- release it's data.
function itemFrame.itemProto:Unlink()
  self.frame:ClearAllPoints()
  self.frame:SetParent(nil)
  self.frame:SetAlpha(1)
  self.frame:Hide()
end

function itemFrame.itemProto:ClearItem()
  events:SendMessage('item/Clearing', self)
  self.kind = nil
  self.frame:ClearAllPoints()
  self.frame:SetParent(nil)
  self.frame:SetAlpha(1)
  self.frame:Hide()
  self.button:SetHasItem(false)
  self.button:SetItemButtonTexture(0)
  self.button:UpdateQuestItem(false, nil, nil)
  self.button:UpdateNewItem(false)
  self.button:UpdateJunkItem(false, false)
  self.button:UpdateItemContextMatching()
  SetItemButtonQuality(self.button, false)
  self.button.minDisplayCount = 1
  SetItemButtonCount(self.button, 0)
  SetItemButtonDesaturated(self.button, false)
  ClearItemButtonOverlay(self.button)
  self.button.ItemSlotBackground:Hide()
  self.frame:SetID(0)
  self.button:SetID(0)
  self.button:Enable()
  self.ilvlText:SetText("")
  self.ilvlText:Hide()
  self.LockTexture:Hide()
  self:ResetSize()
  self.data = nil
  self.stacks = {}
  self.stackCount = 1
  self.stackid = nil
  self.isFreeSlot = false
  self.freeSlotName = ""
  self.freeSlotCount = 0
  self.button.UpgradeIcon:SetShown(false)
end

function itemFrame:OnInitialize()
  self._pool = CreateObjectPool(self._DoCreate, self._DoReset)
  self._pool:SetResetDisallowedIfNew()
end

function itemFrame:OnEnable()
  -- Pre-populate the pool with 600 items. This is done
  -- so that items acquired during combat do not taint
  -- the bag frame.
  ---@type Item[]
  local frames = {}
  for i = 1, 600 do
    frames[i] = self:Create()
  end
  for _, frame in pairs(frames) do
    frame:Release()
  end

  self.emptyItemTooltip = CreateFrame("GameTooltip", "BetterBagsEmptySlotTooltip", UIParent, "GameTooltipTemplate") --[[@as GameTooltip]]
  --self.emptyItemTooltip:CopyTooltip()
  self.emptyItemTooltip:SetScale(GameTooltip:GetScale())
end

---@param i Item
function itemFrame:_DoReset(i)
  i:ClearItem()
end

function itemFrame:_DoCreate()
  local i = setmetatable({}, { __index = itemFrame.itemProto })
  -- Generate the item button name. This is needed because item
  -- button textures are named after the button itself.
  local name = format("BetterBagsItemButton%d", buttonCount)
  buttonCount = buttonCount + 1
  -- Create a hidden parent to the ItemButton frame to work around
  -- item taint introduced in 10.x
  local p = CreateFrame("Button", name.."parent")

  ---@class ItemButton
  local button = CreateFrame("ItemButton", name, p, "ContainerFrameItemButtonTemplate")

  -- Assign the global item button textures to the item button.
  for _, child in pairs(children) do
    i[child] = _G[name..child] ---@type texture
  end

  -- Small fix for missing texture
  i.IconOverlay = button['IconOverlay']

  button:RegisterForDrag("LeftButton")
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  i.button = button
  button:SetAllPoints(p)
  button:SetPassThroughButtons("MiddleButton")

  button:HookScript("OnEnter", function()
    i:OnEnter()
  end)

  button:HookScript("OnLeave", function()
    i:OnLeave()
  end)

  i.frame = p

  button.ItemSlotBackground = button:CreateTexture(nil, "BACKGROUND", "ItemSlotBackgroundCombinedBagsTemplate", -6);
  button.ItemSlotBackground:SetAllPoints(button);
  button.ItemSlotBackground:Hide()

  i.LockTexture = button:CreateTexture(name.."LockButton", "OVERLAY")
  i.LockTexture:SetAtlas("UI-CharacterCreate-PadLock")
  i.LockTexture:SetPoint("TOP")
  i.LockTexture:SetSize(32,32)
  i.LockTexture:SetVertexColor(255/255, 66/255, 66/255)
  i.LockTexture:Hide()

  --p:RegisterForClicks("MiddleButtonUp")
  --p:SetScript("OnClick", function()
  --  i:ToggleLock()
  --end)

  local ilvlText = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  ilvlText:SetPoint("BOTTOMLEFT", 2, 2)
  i.ilvlText = ilvlText

  i.stacks = {}
  i.stackCount = 1
  return i
end

---@return Item
function itemFrame:Create()
  ---@return Item
  return self._pool:Acquire()
end
