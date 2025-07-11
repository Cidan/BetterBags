---@diagnostic disable: duplicate-set-field,duplicate-doc-field



local addon = GetBetterBags()

local const = addon:GetConstants()
---@class ItemFrame: AceModule
---@field emptyItemTooltip GameTooltip
local itemFrame = addon:NewModule('ItemFrame')

local events = addon:GetEvents()

local database = addon:GetDatabase()

---@class Color: AceModule
local color = addon:GetModule('Color')

local categories = addon:GetCategories()

---@class EquipmentSets: AceModule
local equipmentSets = addon:GetModule('EquipmentSets')

local L = addon:GetLocalization()

local items = addon:GetItems()

local themes = addon:GetThemes()

---@class Search: AceModule
local search = addon:GetModule('Search')

local context = addon:GetContext()

---@class Pool: AceModule
local pool = addon:GetModule('Pool')

local debug = addon:GetDebug()

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

---@param ctx Context
---@param found? boolean
function itemFrame.itemProto:UpdateSearch(ctx, found)
  if self.slotkey == nil then return end
  local decoration = themes:GetItemButton(ctx, self)
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

---@param ctx Context
function itemFrame.itemProto:UpdateCooldown(ctx)
  if self.slotkey == nil then return end
  local data = items:GetItemDataFromSlotKey(self.slotkey)
  if not data or data.isItemEmpty then return end
  local decoration = themes:GetItemButton(ctx, self)
  decoration:UpdateCooldown(data.itemInfo.itemIcon)
end

---@param ctx Context
function itemFrame.itemProto:Lock(ctx)
  local decoration = themes:GetItemButton(ctx, self)
  SetItemButtonDesaturated(decoration, true)
end

---@param ctx Context
function itemFrame.itemProto:Unlock(ctx)
  local decoration = themes:GetItemButton(ctx, self)
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

---@param ctx Context
function itemFrame.itemProto:UpdateCount(ctx)
  if not self.slotkey then return end
  if not self.kind then return end
  local data = items:GetItemDataFromSlotKey(self.slotkey)
  if not data or data.isItemEmpty then return end
  ---@type number
  local count = 0
  local opts = database:GetStackingOptions(self.kind)
  local stack = items:GetStackData(data)
  if (not opts.mergeStacks) or
  (opts.unmergeAtShop and addon.atInteracting) or
  (opts.dontMergePartial and data.itemInfo.currentItemCount < data.itemInfo.itemStackCount and data.itemInfo.itemStackCount ~= 1) or
  (not opts.mergeUnstackable and data.itemInfo.itemStackCount == 1) or
  database:GetBagView(self.kind) == const.BAG_VIEW.SECTION_ALL_BAGS then
    count = data.itemInfo.currentItemCount
  elseif opts.dontMergePartial and data.itemInfo.currentItemCount == data.itemInfo.itemStackCount and stack then
    count = data.itemInfo.currentItemCount
    for slotKey in pairs(stack.slotkeys) do
      local childData = items:GetItemDataFromSlotKey(slotKey)
      if childData.itemInfo.currentItemCount == childData.itemInfo.itemStackCount then
        count = count + childData.itemInfo.currentItemCount
      end
    end
  else
    if stack then
      count = items:GetItemDataFromSlotKey(stack.rootItem).itemInfo.currentItemCount
      if stack.count > 1 then
        for slotKey in pairs(stack.slotkeys) do
          local itemData = items:GetItemDataFromSlotKey(slotKey)
          count = count + itemData.itemInfo.currentItemCount
        end
      end
    end
  end

  local decoration = themes:GetItemButton(ctx, self)
  SetItemButtonCount(decoration, count)
end

---@param ctx Context
function itemFrame.itemProto:UpdateUpgrade(ctx)
  local data = self:GetItemData()
  local decoration = themes:GetItemButton(ctx, self)
  if not data or not data.inventorySlots then return end
  if self.staticData then return end

  if not C_Item.IsEquippableItem(data.itemInfo.itemLink) then
    decoration.UpgradeIcon:SetShown(false)
    return
  end

  if database:GetUpgradeIconProvider() == "None" then
    decoration.UpgradeIcon:SetShown(false)
    return
  end

  for _, slot in pairs(data.inventorySlots) do
    local equippedItem = items:GetItemDataFromInventorySlot(slot)
    -- If the item is an offhand and the mainhand is a 2H weapon
    -- don't show the upgrade icon.
    if slot == INVSLOT_OFFHAND then
      local mainhand = items:GetItemDataFromInventorySlot(INVSLOT_MAINHAND)
      if mainhand and (mainhand.itemInfo.itemEquipLoc == "INVTYPE_2HWEAPON" or mainhand.itemInfo.itemEquipLoc == "INVTYPE_RANGED") then
        decoration.UpgradeIcon:SetShown(false)
        break
      end
    end
    if equippedItem and data.itemInfo.currentItemLevel > equippedItem.itemInfo.currentItemLevel then
      decoration.UpgradeIcon:SetShown(true)
      break
    elseif equippedItem and equippedItem.isItemEmpty and slot >= INVSLOT_FIRST_EQUIPPED and slot <= INVSLOT_LAST_EQUIPPED then
      print("upgrade icon for secondary" .. data.itemInfo.itemLink)
      decoration.UpgradeIcon:SetShown(true)
      break
    else
      decoration.UpgradeIcon:SetShown(false)
    end
  end
end

---@return ItemData
function itemFrame.itemProto:GetItemData()
  if self.staticData then
    return self.staticData
  end
  return items:GetItemDataFromSlotKey(self.slotkey)
end

---@param ctx Context
---@param data ItemData
function itemFrame.itemProto:SetStaticItemFromData(ctx, data)
  self.staticData = data
  self:SetItemFromData(ctx, data)
end

---@param ctx Context
---@param slotkey string
function itemFrame.itemProto:SetItem(ctx, slotkey)
  assert(slotkey, 'item must be provided')
  local data = items:GetItemDataFromSlotKey(slotkey)
  self:SetItemFromData(ctx, data)
end

---@param item ItemButton
---@return integer
function itemFrame.GetItemContextMatchResult(item)
  local itemLocation = ItemLocation:CreateFromBagAndSlot(item.bagID, item:GetID())
  if itemLocation and itemLocation:HasAnyLocation() and itemLocation:IsBagAndSlot() and itemLocation:IsValid() then
    local result = ItemButtonUtil.GetItemContextMatchResultForItem( itemLocation ) --[[@as integer]]
    if not const.BACKPACK_BAGS[item.bagID] then return ItemButtonUtil.ItemContextMatchResult.Match end
    if result == ItemButtonUtil.ItemContextMatchResult.Match then return ItemButtonUtil.ItemContextMatchResult.Match end
    if addon.atBank and addon.Bags.Bank.bankTab >= const.BANK_TAB.ACCOUNT_BANK_1 then
      if not C_Bank.IsItemAllowedInBankType( Enum.BankType.Account, itemLocation ) then
        return ItemButtonUtil.ItemContextMatchResult.Mismatch
      else
        return ItemButtonUtil.ItemContextMatchResult.Match
      end
    end
    return result or ItemButtonUtil.ItemContextMatchResult.Match
  end
  return ItemButtonUtil.ItemContextMatchResult.DoesNotApply
end

---@param ctx Context
---@param data ItemData
function itemFrame.itemProto:SetItemFromData(ctx, data)
  assert(data, 'data must be provided')
  self.slotkey = data.slotkey
  local decoration = themes:GetItemButton(ctx, self)
  local tooltipOwner = GameTooltip:GetOwner()
  local bagid, slotid = data.bagid, data.slotid
  if bagid and slotid then
    self.button:SetID(slotid)
    decoration:SetID(slotid)
    decoration.bagID = bagid
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

  --override default to avoid https://github.com/Stanzilla/WoWUIBugs/issues/640
  decoration.GetItemContextMatchResult = itemFrame.GetItemContextMatchResult
  decoration:SetItemButtonTexture(data.itemInfo.itemIcon)
  SetItemButtonQuality(decoration, data.itemInfo.itemQuality, data.itemInfo.itemLink, false, bound)
  if database:GetExtraGlowyButtons(self.kind) and data.itemInfo.itemQuality > Enum.ItemQuality.Common then
    decoration.IconBorder:SetTexture([[Interface\Buttons\UI-ActionButton-Border]])
    decoration.IconBorder:SetBlendMode("ADD")
    decoration.IconBorder:SetTexCoord(14/64, 49/64, 15/64, 50/64)
  else
    decoration.IconBorder:SetTexture([[Interface\Common\WhiteIconFrame]])
    decoration.IconBorder:SetBlendMode("BLEND")
    decoration.IconBorder:SetTexCoord(0, 1, 0, 1)
  end
  self:UpdateCount(ctx)
  --self:SetLock(data.itemInfo.isLocked)
  decoration:UpdateExtended()
  decoration:UpdateQuestItem(isQuestItem, questID, isActive)
  if not self.staticData then
    self:UpdateNewItem(ctx, data.itemInfo.itemQuality)
  end
  decoration:UpdateJunkItem(data.itemInfo.itemQuality, noValue)
  decoration:UpdateItemContextMatching()
  decoration:UpdateCooldown(data.itemInfo.itemIcon)
  decoration:SetReadable(readable)
  decoration:CheckUpdateTooltip(tooltipOwner)
  decoration:SetMatchesSearch(not isFiltered)
  self:Unlock(ctx)

  self.freeSlotName = ""
  self.freeSlotCount = 0
  self.isFreeSlot = nil
  self:SetAlpha(1)
  if self.slotkey ~= nil then
    events:SendMessage(ctx, 'item/Updated', self, decoration)
  end
  decoration:SetFrameLevel(self.button:GetFrameLevel() - 1)
  self:UpdateUpgrade(ctx)
  self.frame:Show()
  self.button:Show()
end

---@param ctx Context
function itemFrame.itemProto:FlashItem(ctx)
  local decoration = themes:GetItemButton(ctx, self)
  decoration.NewItemTexture:SetAtlas("bags-glow-white")
  decoration.NewItemTexture:Show()
  if (not decoration.flashAnim:IsPlaying() and not decoration.newitemglowAnim:IsPlaying()) then
    decoration.flashAnim:Play()
    decoration.newitemglowAnim:Play()
  end
end

---@param ctx Context
function itemFrame.itemProto:ClearFlashItem(ctx)
  local decoration = themes:GetItemButton(ctx, self)
  decoration.BattlepayItemTexture:Hide()
  decoration.NewItemTexture:Hide()
  if (decoration.flashAnim:IsPlaying() or decoration.newitemglowAnim:IsPlaying()) then
    decoration.flashAnim:Stop()
    decoration.newitemglowAnim:Stop()
  end
end

---@param ctx Context
---@param quality Enum.ItemQuality
function itemFrame.itemProto:UpdateNewItem(ctx, quality)
  local decoration = themes:GetItemButton(ctx, self)
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

---@param ctx Context
function itemFrame.itemProto:ResetSize(ctx)
  local decoration = themes:GetItemButton(ctx, self)
  self:SetSize(ctx, 37, 37)
  decoration.NormalTexture:SetSize(64, 64)
end

---@param ctx Context
---@param width number
---@param height number
function itemFrame.itemProto:SetSize(ctx, width, height)
  local decoration = themes:GetItemButton(ctx, self)
  self.frame:SetSize(width, height)
  self.button:SetSize(width, height)
  decoration:SetSize(width, height)
  decoration.IconBorder:SetSize(width, height)
  decoration.NormalTexture:SetSize(64/width, 64/height)
  decoration.IconQuestTexture:SetSize(width, height)
  decoration.IconTexture:SetSize(width, height)
  decoration.IconOverlay:SetSize(width, height)
end

---@param bagid number
---@return string
function itemFrame.itemProto:GetBagType(bagid)
  local invid = C_Container.ContainerIDToInventoryID(bagid)
  local baglink = GetInventoryItemLink("player", invid)
  if baglink ~= nil and invid ~= nil then
    local class, subclass = select(6, C_Item.GetItemInfoInstant(baglink)) --[[@as number]]
    local name = C_Item.GetItemSubClassInfo(class, subclass)
    return name
  else
    local name = C_Item.GetItemSubClassInfo(Enum.ItemClass.Container, 0)
    return name
  end
end

---@param bagid number
---@return Enum.ItemQuality
function itemFrame.itemProto:GetBagTypeQuality(bagid)
  local invid = C_Container.ContainerIDToInventoryID(bagid)
  local baglink = GetInventoryItemLink("player", invid)
  if baglink ~= nil and invid ~= nil then
    local class, subclass = select(6, C_Item.GetItemInfoInstant(baglink)) --[[@as number]]
    if class == Enum.ItemClass.Quiver then
      return const.BAG_SUBTYPE_TO_QUALITY[99]
    end
    return const.BAG_SUBTYPE_TO_QUALITY[subclass]
  else
    return const.BAG_SUBTYPE_TO_QUALITY[0]
  end
end

-- SetFreeSlots will set the item button to a free slot.
---@param ctx Context
---@param bagid number
---@param slotid number
---@param count number
---@param nocount? boolean
function itemFrame.itemProto:SetFreeSlots(ctx, bagid, slotid, count, nocount)
  local decoration = themes:GetItemButton(ctx, self)
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
  decoration.GetItemContextMatchResult = nil
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

  self.freeSlotName = self:GetBagType(bagid)
  if database:GetShowAllFreeSpace(self.kind) and const.BACKPACK_ONLY_REAGENT_BAGS[bagid] then
    SetItemButtonQuality(decoration, Enum.ItemQuality.Uncommon, nil, false, false)
  else
    SetItemButtonQuality(decoration, Enum.ItemQuality.Common, nil, false, false)
  end
  decoration.IconBorder:SetTexture([[Interface\Common\WhiteIconFrame]])
  decoration.IconBorder:SetBlendMode("BLEND")
  decoration.IconBorder:SetTexCoord(0, 1, 0, 1)
  self.isFreeSlot = true
  decoration.ItemSlotBackground:Show()
  self.frame:SetAlpha(1)
  events:SendMessage(ctx, 'item/Updated', self, decoration)
  self.frame:Show()
  self.button:Show()
end

---@param ctx Context
---@return boolean
function itemFrame.itemProto:IsNewItem(ctx)
  local decoration = themes:GetItemButton(ctx, self)
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

---@param ctx Context
function itemFrame.itemProto:Release(ctx)
  itemFrame._pool:Release(ctx, self)
end

---@param ctx Context
function itemFrame.itemProto:Wipe(ctx)
  self.frame:Hide()
  self.frame:SetParent(nil)
  self.frame:ClearAllPoints()
  self:ClearItem(ctx)
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

---@param ctx Context
function itemFrame.itemProto:ClearItem(ctx)
  local decoration = themes:GetItemButton(ctx, self)
  events:SendMessage(ctx, 'item/Clearing', self, decoration)
  self.kind = nil
  self.frame:ClearAllPoints()
  self.frame:SetParent(nil)
  self.frame:SetAlpha(1)
  self.frame:Hide()
  decoration:SetHasItem(false)
  self.button:SetHasItem(false)
  decoration.GetItemContextMatchResult = nil
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
  self:ResetSize(ctx)
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
  self._pool = pool:Create(self._DoCreate, self._DoReset)
  --self._pool = CreateObjectPool(self._DoCreate, self._DoReset)
end

function itemFrame:OnEnable()
  self.emptyItemTooltip = CreateFrame("GameTooltip", "BetterBagsEmptySlotTooltip", UIParent, "GameTooltipTemplate") --[[@as GameTooltip]]
  self.emptyItemTooltip:SetScale(GameTooltip:GetScale())

  local ctx = context:New('itemFrame_OnEnable')
  -- Pre-populate the pool with 600 items. This is done
  -- so that items acquired during combat do not taint
  -- the bag frame.
  ---@type Item[]
  local frames = {}
  for i = 1, 700 do
    frames[i] = self:Create(ctx)
  end
  for _, frame in pairs(frames) do
    frame:Release(ctx)
  end

end

---@param ctx Context
---@param i Item
function itemFrame._DoReset(ctx, i)
  i:ClearItem(ctx)
end

---@return Item
function itemFrame:_DoCreate(_)
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
  addon.HookScript(button, "OnMouseDown", function(ectx)
    themes:GetItemButton(ectx, i):GetPushedTexture():Show()
  end)

  addon.HookScript(button, "OnMouseUp", function(ectx)
    themes:GetItemButton(ectx, i):GetPushedTexture():Hide()
  end)

  addon.HookScript(button, "OnLeave", function(ectx)
    themes:GetItemButton(ectx, i):GetHighlightTexture():Hide()
    themes:GetItemButton(ectx, i):GetPushedTexture():Hide()
  end)

  addon.HookScript(button, "OnEnter", function(ectx)
    themes:GetItemButton(ectx, i):GetHighlightTexture():Show()
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

---@param ctx Context
---@return Item
function itemFrame:Create(ctx)
  ---@return Item
  return self._pool:Acquire(ctx)
end
