---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule("Constants")

---@class ItemFrame: AceModule
---@field emptyItemTooltip GameTooltip
local itemFrame = addon:NewModule("ItemFrame")

---@class Events: AceModule
local events = addon:GetModule("Events")

---@class Database: AceModule
local database = addon:GetModule("Database")

---@class Color: AceModule
local color = addon:GetModule("Color")

---@class Localization: AceModule
local L = addon:GetModule("Localization")

---@class Items: AceModule
local items = addon:GetModule("Items")

---@class Themes: AceModule
local themes = addon:GetModule("Themes")

---@class Context: AceModule
local context = addon:GetModule("Context")

---@class Debug: AceModule
local debug = addon:GetModule("Debug")

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
	"HighlightTexture",
}

---@param ctx Context
---@param found? boolean
function itemFrame.itemProto:UpdateSearch(ctx, found)
	if self.slotkey == nil then
		return
	end
	local decoration = themes:GetItemButton(ctx, self)
	decoration:SetMatchesSearch(found and true or false)
end

function itemFrame.itemProto:OnEnter()
	debug:ShowItemTooltip(self)
	if not self.isFreeSlot then
		return
	end
	if not self.freeSlotName or self.freeSlotName == "" then
		return
	end
	if self.freeSlotCount == -1 then
		return
	end

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
---@param data ItemData
function itemFrame.itemProto:UpdateCooldown(ctx, data)
	assert(data, "data must be provided")
	if data.isItemEmpty then
		return
	end
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

---@param data ItemData
function itemFrame.itemProto:ShowItemLevel(data)
	local ilvlOpts = database:GetItemLevelOptions(self.kind)
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

---@param data ItemData
function itemFrame.itemProto:DrawItemLevel(data)
	assert(data, "data must be provided")
	if data.isItemEmpty then
		self.ilvlText:Hide()
		return
	end
	if not self.kind then
		return
	end
	local ilvlOpts = database:GetItemLevelOptions(self.kind)
	local mergeOpts = database:GetStackingOptions(self.kind)
	local ilvl = data.itemInfo.currentItemLevel

	if not ilvlOpts.enabled then
		self.ilvlText:Hide()
		return
	end

	if data.itemInfo.classID ~= Enum.ItemClass.Armor and data.itemInfo.classID ~= Enum.ItemClass.Weapon then
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

	self:ShowItemLevel(data)
end

---@param ctx Context
---@param data ItemData
function itemFrame.itemProto:UpdateCount(ctx, data)
	assert(data, "data must be provided")
	if data.isItemEmpty then
		return
	end
	local decoration = themes:GetItemButton(ctx, self)
	SetItemButtonCount(decoration, data.stackedCount or data.itemInfo.currentItemCount)
end

---@param ctx Context
---@param data ItemData
function itemFrame.itemProto:UpdateUpgrade(ctx, data)
	local decoration = themes:GetItemButton(ctx, self)
	assert(data, "data must be provided")
	if data.isItemEmpty then
		decoration.UpgradeIcon:SetShown(false)
		return
	end
	if self.staticData then
		return
	end
	if data.isUpgrade ~= nil then
		decoration.UpgradeIcon:SetShown(data.isUpgrade)
		return
	end

	if not data.inventorySlots or not C_Item.IsEquippableItem(data.itemInfo.itemLink) then
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
			if
				mainhand
				and (
					mainhand.itemInfo.itemEquipLoc == "INVTYPE_2HWEAPON"
					or mainhand.itemInfo.itemEquipLoc == "INVTYPE_RANGED"
				)
			then
				decoration.UpgradeIcon:SetShown(false)
				break
			end
		end
		if equippedItem and data.itemInfo.currentItemLevel > equippedItem.itemInfo.currentItemLevel then
			decoration.UpgradeIcon:SetShown(true)
			break
		elseif
			equippedItem
			and equippedItem.isItemEmpty
			and slot >= INVSLOT_FIRST_EQUIPPED
			and slot <= INVSLOT_LAST_EQUIPPED
		then
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
	assert(slotkey, "item must be provided")
	local data = items:GetItemDataFromSlotKey(slotkey)
	if not data then
		-- Item data can be nil when the global slotInfo was replaced by WipeSlotInfo
		-- between when the draw was queued (via SendMessageLater) and when it fires.
		-- Silently skip stale slotkeys rather than crashing.
		debug:Log("SetItem", "No item data for slotkey", slotkey, "- skipping stale draw")
		return
	end
	self:SetItemFromData(ctx, data)
end

---@param item ItemButton
---@return integer
function itemFrame.GetItemContextMatchResult(item)
	local itemLocation = ItemLocation:CreateFromBagAndSlot(item.bagID, item:GetID())
	if itemLocation and itemLocation:HasAnyLocation() and itemLocation:IsBagAndSlot() and itemLocation:IsValid() then
		local result = ItemButtonUtil.GetItemContextMatchResultForItem(itemLocation) --[[@as integer]]
		if not const.BACKPACK_BAGS[item.bagID] then
			return ItemButtonUtil.ItemContextMatchResult.Match
		end
		if result == ItemButtonUtil.ItemContextMatchResult.Match then
			return ItemButtonUtil.ItemContextMatchResult.Match
		end

		-- Debug logging to identify nil values
		if addon.isRetail and addon.atBank then
			debug:Log(
				"ItemContext",
				"Bank.bankTab: %s, ACCOUNT_BANK_1 value: %s",
				tostring(addon.Bags.Bank and addon.Bags.Bank.bankTab),
				tostring(const.BANK_TAB.ACCOUNT_BANK_1)
			)
			debug:Log("ItemContext", "AccountBankTab_1 enum value: %s", tostring(Enum.BagIndex.AccountBankTab_1))
		end

		-- Fix for retail WoW: use Enum.BagIndex.AccountBankTab_1 directly
		local accountBankStart = addon.isRetail and Enum.BagIndex.AccountBankTab_1 or const.BANK_TAB.ACCOUNT_BANK_1
		if
			addon.atBank
			and addon.Bags.Bank
			and addon.Bags.Bank.bankTab
			and accountBankStart
			and addon.Bags.Bank.bankTab >= accountBankStart
		then
			if not C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, itemLocation) then
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
	assert(data, "data must be provided")
	self.slotkey = data.slotkey
	local decoration = themes:GetItemButton(ctx, self)
	local tooltipOwner = GameTooltip:GetOwner()
	local bagid, slotid = data.bagid, data.slotid
	if bagid and slotid then
		if const.BANK_BAGS[bagid] then
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
	local readable = info and info.isReadable
	local isFiltered = info and info.isFiltered
	local noValue = info and info.hasNoValue
	local isQuestItem = questInfo.isQuestItem
	local questID = questInfo.questID
	local isActive = questInfo.isActive

	local bound = data.itemInfo.isBound

	self.stackid = data.itemInfo.itemID
	decoration.minDisplayCount = 1
	self:DrawItemLevel(data)
	decoration.ItemSlotBackground:Hide()
	ClearItemButtonOverlay(decoration)
	decoration:SetHasItem(data.itemInfo.itemIcon)
	self.button:SetHasItem(data.itemInfo.itemIcon)

	--override default to avoid https://github.com/Stanzilla/WoWUIBugs/issues/640
	decoration.GetItemContextMatchResult = itemFrame.GetItemContextMatchResult
	decoration:SetItemButtonTexture(data.itemInfo.itemIcon)
	SetItemButtonQuality(decoration, data.itemInfo.itemQuality, data.itemInfo.itemLink, false, bound)
	if database:GetExtraGlowyButtons(self.kind) and data.itemInfo.itemQuality > const.ITEM_QUALITY.Common then
		decoration.IconBorder:SetTexture([[Interface\Buttons\UI-ActionButton-Border]])
		decoration.IconBorder:SetBlendMode("ADD")
		decoration.IconBorder:SetTexCoord(14 / 64, 49 / 64, 15 / 64, 50 / 64)
	else
		decoration.IconBorder:SetTexture([[Interface\Common\WhiteIconFrame]])
		decoration.IconBorder:SetBlendMode("BLEND")
		decoration.IconBorder:SetTexCoord(0, 1, 0, 1)
	end
	self:UpdateCount(ctx, data)
	--self:SetLock(data.itemInfo.isLocked)
	if self.button.UpdateExtended then
		self.button:UpdateExtended()
	end
	if decoration.UpdateExtended then
		decoration:UpdateExtended()
	end
	decoration:UpdateQuestItem(isQuestItem, questID, isActive)
	if not self.staticData then
		self:UpdateNewItem(ctx, data)
	end
	decoration:UpdateJunkItem(data.itemInfo.itemQuality, noValue)
	decoration:UpdateItemContextMatching()
	decoration:UpdateCooldown(ctx, data)
	decoration:SetReadable(readable)
	decoration:CheckUpdateTooltip(tooltipOwner)
	decoration:SetMatchesSearch(not isFiltered)
	self:Unlock(ctx)

	self.freeSlotName = ""
	self.freeSlotCount = 0
	self.isFreeSlot = nil
	self:SetAlpha(1)
	if self.slotkey ~= nil then
		events:SendMessage(ctx, "item/Updated", self, decoration)
	end
	decoration:SetFrameLevel(math.max(0, self.button:GetFrameLevel() - 1))
	self:UpdateUpgrade(ctx, data)
	self.frame:Show()
	self.button:Show()
end

---@param ctx Context
function itemFrame.itemProto:FlashItem(ctx)
	local decoration = themes:GetItemButton(ctx, self)
	decoration.NewItemTexture:SetAtlas("bags-glow-white")
	decoration.NewItemTexture:Show()
	if not decoration.flashAnim:IsPlaying() and not decoration.newitemglowAnim:IsPlaying() then
		decoration.flashAnim:Play()
		decoration.newitemglowAnim:Play()
	end
end

---@param ctx Context
function itemFrame.itemProto:ClearFlashItem(ctx)
	local decoration = themes:GetItemButton(ctx, self)
	decoration.BattlepayItemTexture:Hide()
	decoration.NewItemTexture:Hide()
	if decoration.flashAnim:IsPlaying() or decoration.newitemglowAnim:IsPlaying() then
		decoration.flashAnim:Stop()
		decoration.newitemglowAnim:Stop()
	end
end

---@param ctx Context
---@param data ItemData
function itemFrame.itemProto:UpdateNewItem(ctx, data)
	local decoration = themes:GetItemButton(ctx, self)
	if not decoration.BattlepayItemTexture and not self.NewItemTexture then
		return
	end
	assert(data, "data must be provided")
	if data.isItemEmpty then
		decoration.BattlepayItemTexture:Hide()
		decoration.NewItemTexture:Hide()
		return
	end
	local quality = data.itemInfo.itemQuality

	if data.itemInfo.isNewItem then
		if data.itemInfo.isBattlePayItem then
			decoration.NewItemTexture:Hide()
			decoration.BattlepayItemTexture:Show()
		else
			if quality and NEW_ITEM_ATLAS_BY_QUALITY[quality] then
				decoration.NewItemTexture:SetAtlas(NEW_ITEM_ATLAS_BY_QUALITY[quality])
			else
				decoration.NewItemTexture:SetAtlas("bags-glow-white")
			end
			decoration.BattlepayItemTexture:Hide()
			decoration.NewItemTexture:Show()
		end
		if not decoration.flashAnim:IsPlaying() and not decoration.newitemglowAnim:IsPlaying() then
			decoration.flashAnim:Play()
			decoration.newitemglowAnim:Play()
		end
	else
		decoration.BattlepayItemTexture:Hide()
		decoration.NewItemTexture:Hide()
		if decoration.flashAnim:IsPlaying() or decoration.newitemglowAnim:IsPlaying() then
			decoration.flashAnim:Stop()
			decoration.newitemglowAnim:Stop()
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
	decoration.NormalTexture:SetSize(64 / width, 64 / height)
	decoration.IconQuestTexture:SetSize(width, height)
	decoration.IconTexture:SetSize(width, height)
	decoration.IconOverlay:SetSize(width, height)
end

-- SetFreeSlots will set the item button to a free slot.
---@param ctx Context
---@param data ItemData
---@param count number
---@param nocount? boolean
function itemFrame.itemProto:SetFreeSlots(ctx, data, count, nocount)
	local decoration = themes:GetItemButton(ctx, self)
	assert(data, "data must be provided")
	local bagid, slotid = data.bagid, data.slotid
	self.slotkey = data.slotkey or items:GetSlotKeyFromBagAndSlot(bagid, slotid)
	if const.BANK_BAGS[bagid] then
		self.kind = const.BAG_KIND.BANK
	else
		self.kind = const.BAG_KIND.BACKPACK
	end

	if count == 0 then
		self.button:Disable()
	else
		self.button:Enable()
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
	if self.button.UpdateExtended then
		self.button:UpdateExtended()
	end
	if decoration.UpdateExtended then
		decoration:UpdateExtended()
	end

	self.freeSlotName = data.itemInfo and data.itemInfo.emptySlotName or ""
	if database:GetShowAllFreeSpace(self.kind) and const.BACKPACK_ONLY_REAGENT_BAGS[bagid] then
		SetItemButtonQuality(decoration, const.ITEM_QUALITY.Uncommon, nil, false, false)
	else
		SetItemButtonQuality(decoration, const.ITEM_QUALITY.Common, nil, false, false)
	end
	decoration.IconBorder:SetTexture([[Interface\Common\WhiteIconFrame]])
	decoration.IconBorder:SetBlendMode("BLEND")
	decoration.IconBorder:SetTexCoord(0, 1, 0, 1)
	self.isFreeSlot = true
	decoration.ItemSlotBackground:Show()
	self.frame:SetAlpha(1)
	events:SendMessage(ctx, "item/Updated", self, decoration)
	self.frame:Show()
	self.button:Show()
end

---@param ctx Context
---@return boolean
function itemFrame.itemProto:IsNewItem(ctx)
	local decoration = themes:GetItemButton(ctx, self)
	if decoration.NewItemTexture:IsShown() then
		return true
	end
	local data = self:GetItemData()
	return data and data.itemInfo and data.itemInfo.isNewItem or false
end

---@param alpha number
function itemFrame.itemProto:SetAlpha(alpha)
	self.frame:SetAlpha(alpha)
end

---@param ctx Context
function itemFrame.itemProto:Release(ctx)
	self:Wipe(ctx)
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
	events:SendMessage(ctx, "item/Clearing", self, decoration)
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
	self.button:Enable()
	self.ilvlText:SetText("")
	self.ilvlText:Hide()
	self:ResetSize(ctx)
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
	self.buttonsBySlotkey = {}
	self.activeItems = setmetatable({}, { __mode = "k" })
end

function itemFrame:OnEnable()
	self.emptyItemTooltip = CreateFrame("GameTooltip", "BetterBagsEmptySlotTooltip", UIParent, "GameTooltipTemplate") --[[@as GameTooltip]]
	self.emptyItemTooltip:SetScale(GameTooltip:GetScale())

	events:RegisterMessage("itemLevel/MaxChanged", function()
		self:RefreshItemLevelColors()
	end)

	local ctx = context:New("itemFrame_OnEnable")
	-- Pre-populate all possible physical buttons to avoid allocations in combat.
	for bagID in pairs(const.BACKPACK_BAGS) do
		for slotID = 1, 40 do
			self:GetButton(ctx, bagID .. "_" .. slotID)
		end
	end
	for bagID in pairs(const.BANK_BAGS) do
		for slotID = 1, 40 do
			self:GetButton(ctx, bagID .. "_" .. slotID)
		end
	end
	if const.ACCOUNT_BANK_BAGS then
		for bagID in pairs(const.ACCOUNT_BANK_BAGS) do
			for slotID = 1, 98 do
				self:GetButton(ctx, bagID .. "_" .. slotID)
			end
		end
	end
	if Enum and Enum.BagIndex and Enum.BagIndex.Reagentbank then
		local reagentBagID = Enum.BagIndex.Reagentbank
		for slotID = 1, 98 do
			self:GetButton(ctx, reagentBagID .. "_" .. slotID)
		end
	end
end

---@param bagID? number
---@return Item
function itemFrame:_DoCreate(_, bagID)
	bagID = bagID or -3
	local i = setmetatable({}, { __index = itemFrame.itemProto })

	-- Backwards compatibility for item data.
	i.data = setmetatable({}, {
		__index = function(_, key)
			local d = items:GetItemDataFromSlotKey(i.slotkey)
			if d == nil then
				return nil
			end
			return d[key]
		end,
	})

	-- Generate the item button name. This is needed because item
	-- button textures are named after the button itself.
	local name = format("BetterBagsItemButton%d", buttonCount)
	buttonCount = buttonCount + 1

	local parent = CreateFrame("Frame", name .. "parent")
	parent:SetID(bagID)
	parent.IsCombinedBagContainer = function() return false end

	---@class ItemButton
	local button = CreateFrame("ItemButton", name, parent, "ContainerFrameItemButtonTemplate")

	-- Install special handlers for themed interaction textures.
	-- Use plain HookScript (not addon.HookScript) to avoid creating contexts during
	-- mouse events, which can cause taint when followed by protected clicks (e.g. UseContainerItem).
	button.PushedTexture:SetTexture("")
	button.NormalTexture:SetTexture("")

	-- Cache a lazy reference to get the decoration button. The decoration is retrieved
	-- via themes module, but we avoid touching addon tables during the actual mouse events.
	local decoration
	local getDecoration = function()
		if not decoration then
			local ctx = context:New("itemButton_init")
			decoration = themes:GetItemButton(ctx, i)
		end
		return decoration
	end

	button:HookScript("OnMouseDown", function()
		getDecoration():GetPushedTexture():Show()
	end)

	button:HookScript("OnMouseUp", function()
		getDecoration():GetPushedTexture():Hide()
	end)

	button:HookScript("OnLeave", function()
		local dec = getDecoration()
		dec:GetHighlightTexture():Hide()
		dec:GetPushedTexture():Hide()
	end)

	button:HookScript("OnEnter", function()
		getDecoration():GetHighlightTexture():Show()
	end)

	-- Hide all the default textures on the clickable button.
	for _, child in pairs(children) do
		if _G[name .. child] then
			_G[name .. child]:Hide() ---@type texture
		end
	end
	button.BattlepayItemTexture:Hide()
	button.NewItemTexture:Hide()
	button.ItemContextOverlay:SetAlpha(0)

	-- Small fix for missing texture
	i.IconOverlay = button["IconOverlay"]

	button:RegisterForDrag("LeftButton")
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	-- ContainerFrameItemButtonTemplate enables mouse wheel via its mixin, which would
	-- intercept scroll events before they reach the parent WowScrollBox container.
	-- Clear the handler and explicitly disable mouse wheel on this button so that
	-- scroll events fall through to the outer scrollable bag frame.
	button:SetScript("OnMouseWheel", nil)
	button:EnableMouseWheel(false)
	i.button = button

	button:HookScript("OnEnter", function()
		i:OnEnter()
	end)

	button:HookScript("OnLeave", function()
		i:OnLeave()
	end)

	parent:SetSize(37, 37)
	button:SetAllPoints(parent)
	i.frame = parent

	local ilvlText = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	ilvlText:SetPoint("BOTTOMLEFT", 2, 2)
	i.ilvlText = ilvlText

	i.stacks = {}
	i.stackCount = 1
	return i
end

---@param ctx Context
---@param slotkey string
---@return Item
function itemFrame:GetButton(ctx, slotkey)
	if self.buttonsBySlotkey[slotkey] then
		return self.buttonsBySlotkey[slotkey]
	end

	-- Check if slotkey is a physical slotkey, i.e., "bagID_slotID"
	local bagID, slotID = slotkey:match("^(%-?%d+)_(%d+)$")
	if bagID and slotID then
		bagID = tonumber(bagID)
		slotID = tonumber(slotID)
		local item = self:Create(ctx, bagID)
		-- Assign physical slot ID and bag ID exactly once on creation
		if item.button.Initialize then
			item.button:Initialize(bagID, slotID)
		else
			item.button:SetID(slotID)
			item.button.bagID = bagID
		end
		local decoration = themes:GetItemButton(ctx, item)
		if decoration.Initialize then
			decoration:Initialize(bagID, slotID)
		else
			decoration:SetID(slotID)
			decoration.bagID = bagID
		end
		item.slotkey = slotkey

		self.buttonsBySlotkey[slotkey] = item
		return item
	else
		-- This is a virtual slotkey (like "Container", "Reagent Bag", etc.)
		-- We can create a dynamic button on demand.
		local item = self:Create(ctx, -3)
		item.slotkey = slotkey
		self.buttonsBySlotkey[slotkey] = item
		return item
	end
end

---@param ctx Context
---@param bagID? number
---@return Item
function itemFrame:Create(ctx, bagID)
	local item = self:_DoCreate(ctx, bagID)
	if self.activeItems then
		self.activeItems[item] = true
	end
	return item
end

function itemFrame:RefreshItemLevelColors()
	for item in pairs(self.activeItems) do
		if item.slotkey and item.slotkey ~= "" and not item.isFreeSlot then
			local data = items:GetItemDataFromSlotKey(item.slotkey)
			if data and not data.isItemEmpty then
				item:DrawItemLevel(data)
			end
		end
	end
end
