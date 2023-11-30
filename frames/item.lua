local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class MasqueTheme: AceModule
local masque = addon:GetModule('Masque')

---@class ItemFrame: AceModule
local item = addon:NewModule('ItemFrame')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Color: AceModule
local color = addon:GetModule('Color')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Item
---@field name string
---@field private mixin ItemMixin
---@field guid string
---@field frame Frame
---@field button ItemButton
---@field itemType string
---@field itemSubType string
---@field masqueGroup string
---@field kind BagKind
---@field expacID number
---@field classID number
---@field subclassID number
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

-- OnEvent is the event handler for the item button.
---@param i Item
local function OnEvent(i)
  if i:GetMixin() == nil then
    return
  end
  i.button:UpdateCooldown(i:GetMixin():GetItemIcon())
end

---@param text? string
function itemProto:UpdateSearch(text)
  if not text or text == "" then
    self.button:SetMatchesSearch(true)
    return
  end

  if string.find(string.lower(self.name), string.lower(text), 1, true) then
    self.button:SetMatchesSearch(true)
    return
  end

  self.button:SetMatchesSearch(false)
end

---@param i ItemMixin
function itemProto:SetItem(i)
  assert(i, 'item must be provided')
  self.mixin = i
  self.name = i:GetItemName() or ""
  self.guid = i:GetItemGUID() or ""
  local tooltipOwner = GameTooltip:GetOwner();
  local bagid, slotid = i:GetItemLocation():GetBagAndSlot()
  self.button:SetID(slotid)
  self.frame:SetID(bagid)
  if const.BANK_BAGS[bagid] or const.REAGENTBANK_BAGS[bagid] then
    self.kind = const.BAG_KIND.BANK
  else
    self.kind = const.BAG_KIND.BACKPACK
  end
  local questInfo = i.questInfo
  local info = i.containerInfo
  local readable = info and info.isReadable;
  local isFiltered = info and info.isFiltered;
  local noValue = info and info.hasNoValue;
  local isQuestItem = questInfo.isQuestItem;
  local questID = questInfo.questID;
  local isActive = questInfo.isActive

  self.expacID = i.itemInfo.expacID
  self.classID = i.itemInfo.classID
  self.subclassID = i.itemInfo.subclassID
  self.itemType = i.itemInfo.itemType or "unknown"
  self.itemSubType = i.itemInfo.itemSubType or "unknown"
  local l = i:GetItemLocation()
  local bound = false
  if l ~= nil then
    bound = C_Item.IsBound(l)
  end

  local ilvlOpts = database:GetItemLevelOptions(self.kind)
  if ilvlOpts.enabled and
    i.itemInfo.classID == Enum.ItemClass.Armor or
    i.itemInfo.classID == Enum.ItemClass.Weapon or
    i.itemInfo.classID == Enum.ItemClass.Gem then
      self.ilvlText:SetText(tostring(i.itemInfo.effectiveIlvl) or "")
      if ilvlOpts.color then
        local r, g, b = color:GetItemLevelColor(i.itemInfo.effectiveIlvl)
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
  self.button:SetHasItem(i:GetItemIcon())
  self.button:SetItemButtonTexture(i:GetItemIcon())
  SetItemButtonQuality(self.button, i:GetItemQuality(), i:GetItemLink(), false, bound);
  SetItemButtonCount(self.button, i:GetStackCount())
  SetItemButtonDesaturated(self.button, i:IsItemLocked())
  self.button:UpdateExtended()
  self.button:UpdateQuestItem(isQuestItem, questID, isActive)
  self.button:UpdateNewItem(i:GetItemQuality())
  self.button:UpdateJunkItem(i:GetItemQuality(), noValue)
  self.button:UpdateItemContextMatching()
  self.button:UpdateCooldown(i:GetItemIcon())
  self.button:SetReadable(readable)
  self.button:CheckUpdateTooltip(tooltipOwner)
  self.button:SetMatchesSearch(not isFiltered)

  self.frame:Show()
  self.button:Show()
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
  if not self.kind then return L:G('Everything') end
  -- TODO(lobato): Handle cases such as new items here instead of in the layout engine.
  if self:GetMixin().containerInfo.quality == Enum.ItemQuality.Poor then
    return L:G('Junk')
  end

  local category = ""

  -- Add the type filter to the category if enabled, but not to trade goods
  -- when the tradeskill filter is enabled. This makes it so trade goods are
  -- labeled as "Tailoring" and not "Tradeskill - Tailoring", which is redundent.
  if database:GetCategoryFilter(self.kind, "Type") and not
  (self.classID == Enum.ItemClass.Tradegoods and database:GetCategoryFilter(self.kind, "TradeSkill")) then
    category = category .. self.itemType
  end

  -- Add the tradeskill filter to the category if enabled.
  if self.classID == Enum.ItemClass.Tradegoods and database:GetCategoryFilter(self.kind, "TradeSkill") then
    if category ~= "" then
      category = category .. " - "
    end
    category = category .. const.TRADESKILL_MAP[self.subclassID]
  end

  -- Add the expansion filter to the category if enabled.
  if database:GetCategoryFilter(self.kind, "Expansion") then
    if not self.expacID then return L:G('Unknown') end
    if category ~= "" then
      category = category .. " - "
    end
    category = category .. const.EXPANSION_MAP[self.expacID]
  end

  if category == "" then
    category = L:G('Everything')
  end

  return category
end

---@return boolean
function itemProto:IsNewItem()
  if self.button.NewItemTexture:IsShown() then
    return true
  end
  return C_NewItems.IsNewItem(self.mixin:GetItemLocation():GetBagAndSlot())
end

---@return ItemMixin
function itemProto:GetMixin()
  return self.mixin
end

function itemProto:Release()
  item._pool:Release(self)
end

function itemProto:ClearItem()
  masque:RemoveButtonFromGroup(self.masqueGroup, self.button)
  self.masqueGroup = nil
  self.mixin = nil
  self.guid = nil
  self.name = nil
  self.kind = nil
  self.expacID = nil
  self.classID = nil
  self.subclassID = nil
  self.frame:ClearAllPoints()
  self.frame:SetParent(nil)
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
  self.itemType = nil
  self.itemSubType = nil
  self.button.minDisplayCount = 1
  self.button:Enable()
  self.ilvlText:SetText("")
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

function item:OnInitialize()
  self._pool = CreateObjectPool(self._DoCreate, self._DoReset)
  self._pool:SetResetDisallowedIfNew()
end

---@param i Item
function item:_DoReset(i)
  i:ClearItem()
end

function item:_DoCreate()
  local i = setmetatable({}, { __index = itemProto })
  -- Generate the item button name. This is needed because item
  -- button textures are named after the button itself.
  local name = format("BetterBagsItemButton%d", buttonCount)
  buttonCount = buttonCount + 1

  -- Create a hidden parent to the ItemButton frame to work around
  -- item taint introduced in 10.x
  local p = CreateFrame("Frame")

  ---@class ItemButton
  local button = CreateFrame("ItemButton", name, p, "ContainerFrameItemButtonTemplate")

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

  events:RegisterEvent('BAG_UPDATE_COOLDOWN', function(_, ...) OnEvent(i) end)
  return i
end

---@return Item
function item:Create()
  ---@return Item
  return self._pool:Acquire()
end

item:Enable()
