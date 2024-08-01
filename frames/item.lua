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

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class Search: AceModule
local search = addon:GetModule('Search')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class ItemStack
---@field button Item
---@field data? ItemData
---@field children? table<string, ItemData>

---@class (exact) Item
---@field frame Frame
---@field button ItemButton|Button
---@field slotkey string
---@field staticData ItemData
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
---@field NormalTexture Texture
---@field NewItemTexture Texture
---@field IconOverlay Texture
---@field ItemContextOverlay Texture
---@field Cooldown Cooldown
---@field UpdateTooltip function
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
  "UpgradeIcon",
  "BattlepayItemTexture",
  "HighlightTexture"
}

---@param found? boolean
function itemFrame.itemProto:UpdateSearch(found)
  if self.slotkey == nil then return end
  local decoration = themes:GetItemButton(self)
  decoration:SetMatchesSearch(found and true or false)
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
  if self.slotkey == nil then return end
  local data = items:GetItemDataFromSlotKey(self.slotkey)
  if not data or data.isItemEmpty then return end
  local decoration = themes:GetItemButton(self)
  decoration:UpdateCooldown(data.itemInfo.itemIcon)
end

function itemFrame.itemProto:Lock()
  local decoration = themes:GetItemButton(self)
  SetItemButtonDesaturated(decoration, true)
end

function itemFrame.itemProto:Unlock()
  local decoration = themes:GetItemButton(self)
  SetItemButtonDesaturated(decoration, false)
end

function itemFrame.itemProto:ShowItemLevel()
  local ilvlOpts = database:GetItemLevelOptions(self.kind)
  local data = items:GetItemDataFromSlotKey(self.slotkey)
  local ilvl = data.itemInfo.currentItemLevel
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
  if not self.slotkey then return end
  if not self.kind then return end
  local ilvlOpts = database:GetItemLevelOptions(self.kind)
  local mergeOpts = database:GetStackingOptions(self.kind)
  local data = items:GetItemDataFromSlotKey(self.slotkey)
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
  if not self.slotkey then return end
  if not self.kind then return end
  local data = items:GetItemDataFromSlotKey(self.slotkey)
  if not data or data.isItemEmpty then return end
  local count = data.stackedCount or data.itemInfo.currentItemCount
  local decoration = themes:GetItemButton(self)
  SetItemButtonCount(decoration, count)
end

---@return ItemData
function itemFrame.itemProto:GetItemData()
  if self.staticData then
    return self.staticData
  end
  return items:GetItemDataFromSlotKey(self.slotkey)
end

---@param data ItemData
function itemFrame.itemProto:SetStaticItemFromData(data)
  self.staticData = data
  self:SetItemFromData(data)
end

---@param slotkey string
function itemFrame.itemProto:SetItem(slotkey)
  assert(slotkey, 'item must be provided')
  local data = items:GetItemDataFromSlotKey(slotkey)
  self:SetItemFromData(data)
end

---@param data ItemData
function itemFrame.itemProto:SetItemFromData(data)
  assert(data, 'data must be provided')
  self.slotkey = data.slotkey
  local decoration = themes:GetItemButton(self)
  local tooltipOwner = GameTooltip:GetOwner()
  local bagid, slotid = data.bagid, data.slotid
  if bagid and slotid then
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
  decoration.minDisplayCount = 1
  self:DrawItemLevel()
  decoration.ItemSlotBackground:Hide()
  ClearItemButtonOverlay(decoration)
  decoration:SetHasItem(data.itemInfo.itemIcon)
  self.button:SetHasItem(data.itemInfo.itemIcon)
  decoration:SetItemButtonTexture(data.itemInfo.itemIcon)
  SetItemButtonQuality(decoration, data.itemInfo.itemQuality, data.itemInfo.itemLink, false, bound)
  self:UpdateCount()
  --self:SetLock(data.itemInfo.isLocked)
  decoration:UpdateExtended()
  decoration:UpdateQuestItem(isQuestItem, questID, isActive)
  if not self.staticData then
    self:UpdateNewItem(data.itemInfo.itemQuality)
  end
  decoration:UpdateJunkItem(data.itemInfo.itemQuality, noValue)
  decoration:UpdateItemContextMatching()
  decoration:UpdateCooldown(data.itemInfo.itemIcon)
  decoration:SetReadable(readable)
  decoration:CheckUpdateTooltip(tooltipOwner)
  decoration:SetMatchesSearch(not isFiltered)
  self:Unlock()

  self.freeSlotName = ""
  self.freeSlotCount = 0
  self.isFreeSlot = nil
  self:SetAlpha(1)
  if self.slotkey ~= nil then
    events:SendMessage('item/Updated', self)
  end
  decoration:SetFrameLevel(self.button:GetFrameLevel() - 1)
  self.frame:Show()
  self.button:Show()
end

function itemFrame.itemProto:FlashItem()
  local decoration = themes:GetItemButton(self)
  decoration.NewItemTexture:SetAtlas("bags-glow-white")
  decoration.NewItemTexture:Show()
  if (not decoration.flashAnim:IsPlaying() and not decoration.newitemglowAnim:IsPlaying()) then
    decoration.flashAnim:Play()
    decoration.newitemglowAnim:Play()
  end
end

function itemFrame.itemProto:ClearFlashItem()
  local decoration = themes:GetItemButton(self)
  decoration.BattlepayItemTexture:Hide()
  decoration.NewItemTexture:Hide()
  if (decoration.flashAnim:IsPlaying() or decoration.newitemglowAnim:IsPlaying()) then
    decoration.flashAnim:Stop()
    decoration.newitemglowAnim:Stop()
  end
end

function itemFrame.itemProto:UpdateNewItem(quality)
  local decoration = themes:GetItemButton(self)
	if(not decoration.BattlepayItemTexture and not self.NewItemTexture) then
		return
	end

	if items:IsNewItem(self:GetItemData()) then
		if C_Container.IsBattlePayItem(self.button:GetBagID(), self.button:GetID()) then
			decoration.NewItemTexture:Hide()
			decoration.BattlepayItemTexture:Show();
		else
			if (quality and NEW_ITEM_ATLAS_BY_QUALITY[quality]) then
				decoration.NewItemTexture:SetAtlas(NEW_ITEM_ATLAS_BY_QUALITY[quality]);
			else
				decoration.NewItemTexture:SetAtlas("bags-glow-white");
			end
			decoration.BattlepayItemTexture:Hide();
			decoration.NewItemTexture:Show();
		end
		if (not decoration.flashAnim:IsPlaying() and not decoration.newitemglowAnim:IsPlaying()) then
			decoration.flashAnim:Play();
			decoration.newitemglowAnim:Play();
		end
	else
		decoration.BattlepayItemTexture:Hide();
		decoration.NewItemTexture:Hide();
		if (decoration.flashAnim:IsPlaying() or decoration.newitemglowAnim:IsPlaying()) then
			decoration.flashAnim:Stop();
			decoration.newitemglowAnim:Stop();
		end
	end
end

function itemFrame.itemProto:ResetSize()
  local decoration = themes:GetItemButton(self)
  self:SetSize(37, 37)
  decoration.NormalTexture:SetSize(64, 64)
end

function itemFrame.itemProto:SetSize(width, height)
  local decoration = themes:GetItemButton(self)
  self.frame:SetSize(width, height)
  self.button:SetSize(width, height)
  decoration:SetSize(width, height)
  decoration.IconBorder:SetSize(width, height)
  decoration.NormalTexture:SetSize(64/width, 64/height)
  decoration.IconQuestTexture:SetSize(width, height)
  decoration.IconTexture:SetSize(width, height)
  decoration.IconOverlay:SetSize(width, height)
end

-- SetFreeSlots will set the item button to a free slot.
---@param bagid number
---@param slotid number
---@param count number
---@param name string
---@param nocount? boolean
function itemFrame.itemProto:SetFreeSlots(bagid, slotid, count, name, nocount)
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
    self.button:SetID(slotid)
    decoration:SetID(slotid)
    self.frame:SetID(bagid)
  end

  self.stackCount = 1
  decoration.minDisplayCount = -1
  self.freeSlotCount = count

  ClearItemButtonOverlay(decoration)
  decoration:SetHasItem(false)
  self.button:SetHasItem(false)
  if not nocount then
    SetItemButtonCount(decoration, count)
  end
  decoration:SetItemButtonTexture(0)
  decoration:UpdateQuestItem(false, nil, nil)
  decoration:UpdateNewItem(false)
  decoration:UpdateJunkItem(false, false)
  decoration:UpdateItemContextMatching()
  SetItemButtonDesaturated(decoration, false)
  decoration:UpdateCooldown(false)
  self.ilvlText:SetText("")
  self.ilvlText:Hide()
  decoration.UpgradeIcon:SetShown(false)

  self.freeSlotName = name
  SetItemButtonQuality(decoration, Enum.ItemQuality.Common, nil, false, false)

  self.isFreeSlot = true
  decoration.ItemSlotBackground:Show()
  self.frame:SetAlpha(1)
  events:SendMessage('item/Updated', self)
  self.frame:Show()
  self.button:Show()
end

---@return boolean
function itemFrame.itemProto:IsNewItem()
  local decoration = themes:GetItemButton(self)
  local data = items:GetItemDataFromSlotKey(self.slotkey)
  if decoration.NewItemTexture:IsShown() then
    return true
  end
  return data.itemInfo.isNewItem
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
  self:ClearItem()
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
  local decoration = themes:GetItemButton(self)
  events:SendMessage('item/Clearing', self, decoration)
  self.kind = nil
  self.frame:ClearAllPoints()
  self.frame:SetParent(nil)
  self.frame:SetAlpha(1)
  self.frame:Hide()
  decoration:SetHasItem(false)
  self.button:SetHasItem(false)
  decoration:SetItemButtonTexture(0)
  decoration:UpdateQuestItem(false, nil, nil)
  decoration:UpdateNewItem(false)
  decoration:UpdateJunkItem(false, false)
  decoration:UpdateItemContextMatching()
  SetItemButtonQuality(decoration, false)
  decoration.minDisplayCount = 1
  SetItemButtonCount(decoration, 0)
  SetItemButtonDesaturated(decoration, false)
  ClearItemButtonOverlay(decoration)
  decoration:UpdateCooldown(false)
  decoration.ItemSlotBackground:Hide()
  self.frame:SetID(0)
  self.button:SetID(0)
  decoration:SetID(0)
  self.button:Enable()
  self.ilvlText:SetText("")
  self.ilvlText:Hide()
  self:ResetSize()
  self.slotkey = ""
  self.stacks = {}
  self.stackCount = 1
  self.stackid = nil
  self.isFreeSlot = false
  self.freeSlotName = ""
  self.freeSlotCount = 0
  self.staticData = nil
  decoration.UpgradeIcon:SetShown(false)
end

function itemFrame:OnInitialize()
  self._pool = CreateObjectPool(self._DoCreate, self._DoReset)
  if self._pool.SetResetDisallowedIfNew then
    self._pool:SetResetDisallowedIfNew()
  end
end

function itemFrame:OnEnable()
  self.emptyItemTooltip = CreateFrame("GameTooltip", "BetterBagsEmptySlotTooltip", UIParent, "GameTooltipTemplate") --[[@as GameTooltip]]
  self.emptyItemTooltip:SetScale(GameTooltip:GetScale())

  -- Pre-populate the pool with 600 items. This is done
  -- so that items acquired during combat do not taint
  -- the bag frame.
  ---@type Item[]
  local frames = {}
  for i = 1, 700 do
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
  local p = CreateFrame("Button", name.."parent")

  ---@class ItemButton
  local button = CreateFrame("ItemButton", name, p, "ContainerFrameItemButtonTemplate")

  -- Install special handlers for themed interaction textures.
  button.PushedTexture:SetTexture("")
  button.NormalTexture:SetTexture("")
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

  -- Hide all the default textures on the clickable button.
  for _, child in pairs(children) do
    if _G[name..child] then
      _G[name..child]:Hide() ---@type texture
    end
  end
  button.BattlepayItemTexture:Hide()
  button.NewItemTexture:Hide()
  button.ItemContextOverlay:SetAlpha(0)

  -- Small fix for missing texture
  i.IconOverlay = button['IconOverlay']

  button:RegisterForDrag("LeftButton")
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  i.button = button
  button:SetAllPoints(p)

  button:HookScript("OnEnter", function()
    i:OnEnter()
  end)

  button:HookScript("OnLeave", function()
    i:OnLeave()
  end)

  i.frame = p

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
