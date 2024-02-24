---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

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

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class (exact) Item
---@field frame Frame
---@field button ItemButton|Button
---@field data ItemData
---@field isFreeSlot boolean
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
---@field UpdateTooltip function
---@field LockTexture Texture
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
  "IconOverlay2",
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

function itemFrame.itemProto:UpdateCooldown()
  if self.data.isItemEmpty then return end
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

function itemFrame.itemProto:DrawItemLevel()
  local data = self.data
  local ilvlOpts = database:GetItemLevelOptions(self.kind)
  local ilvl = data.itemInfo.currentItemLevel
  if (ilvlOpts.enabled and ilvl and ilvl > 1 and data.itemInfo.currentItemCount == 1) and
    (data.itemInfo.classID == Enum.ItemClass.Armor or
    data.itemInfo.classID == Enum.ItemClass.Weapon or
    data.itemInfo.classID == Enum.ItemClass.Gem) then
      self.ilvlText:SetText(tostring(ilvl))
      if ilvlOpts.color then
        local r, g, b = color:GetItemLevelColor(ilvl)
        self.ilvlText:SetTextColor(r, g, b, 1)
      else
        self.ilvlText:SetTextColor(1, 1, 1, 1)
      end
      self.ilvlText:Show()
  else
    self.ilvlText:Hide()
  end

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

  self.button.minDisplayCount = 1
  self:DrawItemLevel()
  self.button.ItemSlotBackground:Hide()
  ClearItemButtonOverlay(self.button)
  self.button:SetHasItem(data.itemInfo.itemIcon)
  self.button:SetItemButtonTexture(data.itemInfo.itemIcon)
  SetItemButtonQuality(self.button, data.itemInfo.itemQuality, data.itemInfo.itemLink, false, bound);
  SetItemButtonCount(self.button, data.itemInfo.currentItemCount)
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

  self:SetAlpha(1)
  events:SendMessage('item/Updated', self)
  self.frame:Show()
  self.button:Show()
end

function itemFrame.itemProto:SetSize(width, height)
  self.frame:SetSize(width, height)
  self.button:SetSize(width, height)
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
    self.button:SetID(slotid)
    self.frame:SetID(bagid)
  end

  self.button.minDisplayCount = -1

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

  if reagent then
    SetItemButtonQuality(self.button, Enum.ItemQuality.Artifact, nil, false, false)
  else
    SetItemButtonQuality(self.button, Enum.ItemQuality.Common, nil, false, false)
  end

  self.isFreeSlot = true
  self.button.ItemSlotBackground:Show()
  self.frame:SetAlpha(1)
  events:SendMessage('item/Updated', self)
  self.frame:Show()
  self.button:Show()
end

function itemFrame.itemProto:GetCategory()

  if self.kind == const.BAG_KIND.BACKPACK and addon.Bags.Backpack.slots:IsShown() then
    ---@type string
    local bagname = self.data.bagid == Enum.BagIndex.Keyring and L:G('Keyring') or C_Container.GetBagName(self.data.bagid)
    local displayid = self.data.bagid == Enum.BagIndex.Keyring and 6 or self.data.bagid+1
    self.data.itemInfo.category = format("#%d: %s", displayid, bagname)
    return self.data.itemInfo.category
  end

  if self.kind == const.BAG_KIND.BANK and addon.Bags.Bank.slots:IsShown() then
    local id = self.data.bagid
    if id == -1 then
      self.data.itemInfo.category = format("#%d: %s", 1, L:G('Bank'))
    elseif id == -3 then
      self.data.itemInfo.category = format("#%d: %s", 1, L:G('Reagent Bank'))
    else
      self.data.itemInfo.category = format("#%d: %s", id - 4, C_Container.GetBagName(id))
    end
    return self.data.itemInfo.category
  end

  if self.data.isItemEmpty then return L:G('Empty Slot') end

  if database:GetCategoryFilter(self.kind, "RecentItems") then
    if items:IsNewItem(self.data) then
      self.data.itemInfo.category = L:G("Recent Items")
      return self.data.itemInfo.category
    end
  end

  -- Check for equipment sets first, as it doesn't make sense to put them anywhere else..
  if self.data.itemInfo.equipmentSet then
    self.data.itemInfo.category = "Gear: " .. self.data.itemInfo.equipmentSet
    return self.data.itemInfo.category
  end

  -- Return the custom category if it exists next.
  local customCategory = categories:GetCustomCategory(self.kind, self.data)
  if customCategory then
    self.data.itemInfo.category = customCategory
    return customCategory
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

  -- Add the subtype filter to the category if enabled, but same as with
  -- the type filter we don't add it to trade goods when the tradeskill
  -- filter is enabled.
  if database:GetCategoryFilter(self.kind, "Subtype") and not
  (self.data.itemInfo.classID == Enum.ItemClass.Tradegoods and database:GetCategoryFilter(self.kind, "TradeSkill")) and
  self.data.itemInfo.itemSubType then
    if category ~= "" then
      category = category .. " - "
    end
    category = category .. self.data.itemInfo.itemSubType
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
  self:SetSize(37, 37)
  self.data = nil
  self.isFreeSlot = false
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

  p:SetSize(37, 37)
  button:SetSize(37, 37)
  button:RegisterForDrag("LeftButton")
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  i.button = button
  button:SetAllPoints(p)
  button:SetPassThroughButtons("MiddleButton")
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

  p:RegisterForClicks("MiddleButtonUp")
  p:SetScript("OnClick", function()
    i:ToggleLock()
  end)

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
