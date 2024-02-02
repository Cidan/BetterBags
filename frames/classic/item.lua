---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class MasqueTheme: AceModule
local masque = addon:GetModule('Masque')

---@class ItemFrame: AceModule
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

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class (exact) Item
---@field frame Frame
---@field button Button
---@field data ItemData
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
---@field IconOverlay2 Texture
---@field ItemContextOverlay Texture
---@field Cooldown Cooldown
local itemProto = {}

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
  "ItemContextOverlay"
}

---@param text? string
function itemProto:UpdateSearch(text)
  if not text or text == "" then
    self.button:SetMatchesSearch(true)
    return
  end
  local lowerText = string.lower(text)
  if string.find(string.lower(self.data.itemInfo.itemName), lowerText, 1, true) or
  string.find(string.lower(self.data.itemInfo.itemType), lowerText, 1, true) or
  string.find(string.lower(self.data.itemInfo.itemSubType), lowerText, 1, true) then
    self.button:SetMatchesSearch(true)
    return
  end

  self.button:SetMatchesSearch(false)
end

function itemProto:UpdateCooldown()
  self.button:UpdateCooldown(self.data.itemInfo.itemIcon)
end

---@param data ItemData
function itemProto:SetItem(data)
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
  local questInfo = data.questInfo
  local info = data.containerInfo
  local readable = info and info.isReadable;
  local isFiltered = info and info.isFiltered;
  local noValue = info and info.hasNoValue;
  local isQuestItem = questInfo.isQuestItem;
  local questID = questInfo.questID;
  local isActive = questInfo.isActive

  local bound = data.itemInfo.isBound

  local ilvlOpts = database:GetItemLevelOptions(self.kind)
  if (ilvlOpts.enabled and data.itemInfo.currentItemLevel > 0) and
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


  self.button.ItemSlotBackground:Hide()
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

  self.frame:Show()
  self.button:Show()
end

function itemProto:SetSize(width, height)
  self.frame:SetSize(width, height)
  self.button:SetSize(width, height)
end

-- SetFreeSlots will set the item button to a free slot.
---@param bagid number
---@param slotid number
---@param count number
---@param reagent boolean
function itemProto:SetFreeSlots(bagid, slotid, count, reagent)
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
  self.frame:SetID(bagid)

  ClearItemButtonOverlay(self.button)
  self.button:SetHasItem(false)
  SetItemButtonCount(self.button, count)

  if reagent then
    SetItemButtonQuality(self.button, Enum.ItemQuality.Artifact, nil, false, false)
  end

  if self.kind == const.BAG_KIND.BANK then
    self:AddToMasqueGroup(const.BAG_KIND.BANK)
  else
    self:AddToMasqueGroup(const.BAG_KIND.BACKPACK)
  end

  self.button.ItemSlotBackground:Show()
  self.frame:Show()
  self.button:Show()
end

function itemProto:GetCategory()
  if database:GetCategoryFilter(self.kind, "RecentItems") then
    if self:IsNewItem() then
      self.data.itemInfo.category = L:G("Recent Items")
      return self.data.itemInfo.category
    end
  end
  -- Return the custom category if it exists.
  local customCategory = categories:GetCustomCategory(self.kind, self.data)
  if customCategory then
    self.data.itemInfo.category = customCategory
    return customCategory
  end

  -- Check for equipment sets next.
  if self.data.itemInfo.equipmentSet then
    self.data.itemInfo.category = "Gear: " .. self.data.itemInfo.equipmentSet
    return self.data.itemInfo.category
  end

  if not self.kind then return L:G('Everything') end
  -- TODO(lobato): Handle cases such as new items here instead of in the layout engine.
  if self.data.containerInfo.quality == Enum.ItemQuality.Poor then
    self.data.itemInfo.category = L:G('Junk')
    return self.data.itemInfo.category
  end

  local category = ""

  -- Add the type filter to the category if enabled, but not to trade goods
  -- when the tradeskill filter is enabled. This makes it so trade goods are
  -- labeled as "Tailoring" and not "Tradeskill - Tailoring", which is redundent.
  if database:GetCategoryFilter(self.kind, "Type") and not
  (self.data.itemInfo.classID == Enum.ItemClass.Tradegoods and database:GetCategoryFilter(self.kind, "TradeSkill")) and
  self.data.itemInfo.itemType then
    category = category .. self.data.itemInfo.itemType --[[@as string]]
  end

  -- Add the tradeskill filter to the category if enabled.
  if self.data.itemInfo.classID == Enum.ItemClass.Tradegoods and database:GetCategoryFilter(self.kind, "TradeSkill") then
    if category ~= "" then
      category = category .. " - "
    end
    category = category .. const.TRADESKILL_MAP[self.data.itemInfo.subclassID]
  end

  -- Add the expansion filter to the category if enabled.
  if database:GetCategoryFilter(self.kind, "Expansion") then
    if not self.data.itemInfo.expacID then return L:G('Unknown') end
    if category ~= "" then
      category = category .. " - "
    end
    category = category .. const.EXPANSION_MAP[self.data.itemInfo.expacID] --[[@as string]]
  end

  if category == "" then
    category = L:G('Everything')
  end
  self.data.itemInfo.category = category
  return category
end

---@return boolean
function itemProto:IsNewItem()
  if self.button.NewItemTexture:IsShown() then
    return true
  end
  return self.data.itemInfo.isNewItem
end

---@param alpha number
function itemProto:SetAlpha(alpha)
  self.frame:SetAlpha(alpha)
end

function itemProto:Release()
  itemFrame._pool:Release(self)
end

function itemProto:ClearItem()
  masque:RemoveButtonFromGroup(self.masqueGroup, self.button)
  self.masqueGroup = nil
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
  SetItemButtonQuality(self.button, false);
  SetItemButtonCount(self.button, 0)
  SetItemButtonDesaturated(self.button, false)
  ClearItemButtonOverlay(self.button)
  self.button.ItemSlotBackground:Hide()
  self.frame:SetID(0)
  self.button:SetID(0)
  self.button.minDisplayCount = 1
  self.button:Enable()
  self.ilvlText:SetText("")
  self:SetSize(37, 37)
  self.data = nil
end

---@param kind BagKind
function itemProto:AddToMasqueGroup(kind)
  if kind == const.BAG_KIND.BANK then
    self.masqueGroup = "Bank"
    masque:AddButtonToGroup(self.masqueGroup, self.button)
  else
    self.masqueGroup = "Backpack"
    masque:AddButtonToGroup(self.masqueGroup, self.button)
  end
end

function itemFrame:OnInitialize()
  self._pool = CreateObjectPool(self._DoCreate, self._DoReset)
  self._pool:SetResetDisallowedIfNew()
end

function itemFrame:OnEnable()
  -- Pre-populate the pool with 300 items. This is done
  -- so that items acquired during combat do not taint
  -- the bag frame.
  ---@type Item[]
  local frames = {}
  for i = 1, 300 do
    frames[i] = self:Create()
  end
  for _, frame in pairs(frames) do
    frame:Release()
  end
end

---@param i Item
function itemFrame:_DoReset(i)
  i:ClearItem()
end

function itemFrame:_DoCreate()
  local i = setmetatable({}, { __index = itemProto })
  -- Generate the item button name. This is needed because item
  -- button textures are named after the button itself.
  local name = format("BetterBagsItemButton%d", buttonCount)
  buttonCount = buttonCount + 1
  -- Create a hidden parent to the ItemButton frame to work around
  -- item taint introduced in 10.x
  local p = CreateFrame("Frame")

  ---@class Button
  local button = CreateFrame("Button", name, p, "ContainerFrameItemButtonTemplate")

  -- Assign the global item button textures to the item button.
  for _, child in pairs(children) do
    i[child] = _G[name..child] ---@type texture
  end

  p:SetSize(37, 37)
  button:SetSize(37, 37)
  button:RegisterForDrag("LeftButton")
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  i.button = button
  button:SetAllPoints(p)
  i.frame = p

  button.ItemSlotBackground = button:CreateTexture(nil, "BACKGROUND", "ItemSlotBackgroundCombinedBagsTemplate", -6);
  button.ItemSlotBackground:SetAllPoints(button);
  button.ItemSlotBackground:Hide()

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
