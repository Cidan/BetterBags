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

-- Alpha multiplier for the quality glow when "Extra Glowy Item Buttons" is off.
-- The glow is always the additive UI-ActionButton-Border texture; this dims it
-- to a subtle level so item quality is still visible (Classic's default bags
-- draw no quality border at all) while "Extra Glowy" is the full-intensity look.
local SUBTLE_QUALITY_GLOW_ALPHA = 0.55

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

---@param bagid number?
---@return BagKind
local function bagKindFromBagID(bagid)
	if bagid and (const.BANK_BAGS[bagid] or (const.ACCOUNT_BANK_BAGS and const.ACCOUNT_BANK_BAGS[bagid])) then
		return const.BAG_KIND.BANK
	end
	return const.BAG_KIND.BACKPACK
end

-- Size of the small family-bag glyph drawn in the center of a specialized empty slot. The
-- source atlas is large (e.g. Mobile-Herbalism is 128x128); this sizes it well under the
-- 37x37 slot so it reads as an icon and not a slot background.
local FAMILY_ICON_SIZE = 24
-- The glyph is drawn at reduced opacity so it hints at the bag type without dominating the slot.
local FAMILY_ICON_ALPHA = 0.4

-- getFamilyIconTexture lazily creates (and returns) the centered family-bag glyph on a themed
-- item-button decoration. It lives in the OVERLAY layer so it sits above the empty-slot art,
-- and is stored on the decoration itself so it survives across draws and theme swaps.
---@param decoration ItemButton
---@return Texture
local function getFamilyIconTexture(decoration)
	if not decoration.BetterBagsFamilyIcon then
		local tex = decoration:CreateTexture(nil, "OVERLAY")
		tex:SetSize(FAMILY_ICON_SIZE, FAMILY_ICON_SIZE)
		tex:SetPoint("CENTER", decoration, "CENTER", 0, 0)
		tex:SetAlpha(FAMILY_ICON_ALPHA)
		tex:Hide()
		decoration.BetterBagsFamilyIcon = tex
	end
	return decoration.BetterBagsFamilyIcon
end

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

-- Classic/TBC only. The clickable button is a ContainerFrameItemButtonTemplate, whose
-- native OnEnter shows the tooltip via GameTooltip:SetBagItem(GetParent():GetID(), GetID()).
-- For the main bank container (bag id -1) that becomes SetBagItem(-1, slot) -- a path
-- Blizzard's own bank UI never uses and which renders a degenerate "vendor price only"
-- tooltip when the item's data is cold/evicted. Blizzard's bank buttons instead go through
-- BankFrameItemButton_OnEnter, which uses GameTooltip:SetInventoryItem("player",
-- BankButtonIDToInvSlotID(slot)). Route main-bank hovers there and everything else through
-- the standard container path.
function itemFrame.itemProto:UpdateTooltip()
	if self.button:GetParent():GetID() == -1 then
		BankFrameItemButton_OnEnter(self.button)
	else
		ContainerFrameItemButton_OnEnter(self.button)
	end
end

---@param ctx Context
---@param data ItemData
function itemFrame.itemProto:UpdateCooldown(ctx, data)
	assert(data, "data must be provided")
	if data.isItemEmpty then
		return
	end
	local decoration = themes:GetItemButton(ctx, self)
	if decoration.UpdateCooldown then
		decoration:UpdateCooldown(data.itemInfo.itemIcon)
	elseif data.bagid ~= nil then
		ContainerFrame_UpdateCooldown(data.bagid, decoration)
	end
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
	if data.isItemEmpty or self.staticData then
		decoration.UpgradeIcon:SetShown(false)
		return
	end
	decoration.UpgradeIcon:SetShown(data.isUpgrade or false)
end

---@return ItemData?
function itemFrame.itemProto:GetItemData()
	return self.currentData or self.staticData
end

---@param ctx Context
---@param data ItemData
function itemFrame.itemProto:SetStaticItemFromData(ctx, data)
	self.staticData = data
	self:SetItemFromData(ctx, data)
end

---@param item ItemButton|Item
---@return integer
function itemFrame.GetItemContextMatchResult(item)
	local data = item and (item._itemData or (item.GetItemData and item:GetItemData()) or item.currentData)
	if data and data.itemContextMatchResult then
		return data.itemContextMatchResult
	end
	if _G.ItemButtonUtil and _G.ItemButtonUtil.ItemContextMatchResult then
		return _G.ItemButtonUtil.ItemContextMatchResult.Match
	end
	return 0
end

---@param ctx Context
---@param data ItemData
function itemFrame.itemProto:SetItemFromData(ctx, data)
	assert(data, "data must be provided")
	self.currentData = data
	self.slotkey = data.slotkey
	local decoration = themes:GetItemButton(ctx, self)
	decoration._itemData = data
	local tooltipOwner = GameTooltip:GetOwner()
	self.kind = bagKindFromBagID(data.bagid)

	-- Any real (or empty) item drawn into the slot clears the specialized-bag glyph.
	if decoration.BetterBagsFamilyIcon then decoration.BetterBagsFamilyIcon:Hide() end

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
	if decoration.ItemSlotBackground then decoration.ItemSlotBackground:Hide() end
	if ClearItemButtonOverlay then ClearItemButtonOverlay(decoration) end
	if decoration.SetHasItem then decoration:SetHasItem(data.itemInfo.itemIcon) end
	if self.button.SetHasItem then self.button:SetHasItem(data.itemInfo.itemIcon) end

	--override default to avoid https://github.com/Stanzilla/WoWUIBugs/issues/640
	decoration.GetItemContextMatchResult = itemFrame.GetItemContextMatchResult
	if decoration.SetItemButtonTexture then decoration:SetItemButtonTexture(data.itemInfo.itemIcon) else SetItemButtonTexture(decoration, data.itemInfo.itemIcon) end
	SetItemButtonQuality(decoration, data.itemInfo.itemQuality, data.itemInfo.itemLink, false, bound)
	self:DrawQualityGlow(decoration, data.itemInfo.itemQuality)
	self:UpdateCount(ctx, data)
	--self:SetLock(data.itemInfo.isLocked)
	if addon.isRetail then
		if self.button.UpdateExtended then
			self.button:UpdateExtended()
		end
		if decoration.UpdateExtended then
			decoration:UpdateExtended()
		end
	end
	if decoration.UpdateQuestItem then decoration:UpdateQuestItem(isQuestItem, questID, isActive) end
	if not self.staticData then
		self:UpdateNewItem(ctx, data)
	end
	if decoration.UpdateJunkItem then decoration:UpdateJunkItem(data.itemInfo.itemQuality, noValue) end
	if decoration.UpdateItemContextMatching then decoration:UpdateItemContextMatching() end
	self:UpdateCooldown(ctx, data)
	if decoration.SetReadable then decoration:SetReadable(readable) end
	if decoration.CheckUpdateTooltip then decoration:CheckUpdateTooltip(tooltipOwner) end
	if decoration.SetMatchesSearch then
		if data.isSearchResult ~= nil then
			decoration:SetMatchesSearch(data.isSearchResult)
		else
			decoration:SetMatchesSearch(not isFiltered)
		end
	end
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

	-- Classic quality glow fix: the interaction button's own NormalTexture
	-- (Interface\Buttons\UI-Quickslot2, a 64x64 beveled frame) is re-shown by
	-- Blizzard's drag/update logic and, because the decoration sits one frame
	-- level BELOW self.button, that frame drew OVER the decoration's quality glow
	-- and hid it. A plain Hide() loses to the re-show, so clear the texture value
	-- itself -- nothing renders even when it is re-shown, and the additive glow
	-- from DrawQualityGlow (above) becomes visible, matching retail behavior
	-- (same halo, same "Extra Glowy" intensity control). Retail has no such
	-- re-show, so leave it untouched.
	if not addon.isRetail and self.button.GetNormalTexture and self.button:GetNormalTexture() then
		self.button:GetNormalTexture():SetTexture(nil)
	end

	self.frame:Show()
	self.button:Show()
end

---@param ctx Context
function itemFrame.itemProto:FlashItem(ctx)
	local decoration = themes:GetItemButton(ctx, self)
	if decoration.NewItemTexture then
		decoration.NewItemTexture:SetAtlas("bags-glow-white")
		decoration.NewItemTexture:Show()
	end
	if not decoration.flashAnim:IsPlaying() and not decoration.newitemglowAnim:IsPlaying() then
		decoration.flashAnim:Play()
		decoration.newitemglowAnim:Play()
	end
end

---@param ctx Context
function itemFrame.itemProto:ClearFlashItem(ctx)
	local decoration = themes:GetItemButton(ctx, self)
	if decoration.BattlepayItemTexture then
		decoration.BattlepayItemTexture:Hide()
	end
	if decoration.NewItemTexture then
		decoration.NewItemTexture:Hide()
	end
	if decoration.flashAnim:IsPlaying() or decoration.newitemglowAnim:IsPlaying() then
		decoration.flashAnim:Stop()
		decoration.newitemglowAnim:Stop()
	end
end

---@param ctx Context
---@param data ItemData
function itemFrame.itemProto:UpdateNewItem(ctx, data)
	local decoration = themes:GetItemButton(ctx, self)
	assert(data, "data must be provided")
	if not decoration.NewItemTexture then
		return
	end
	if data.isItemEmpty then
		if decoration.BattlepayItemTexture then
			decoration.BattlepayItemTexture:Hide()
		end
		decoration.NewItemTexture:Hide()
		return
	end
	local quality = data.itemInfo.itemQuality

	if data.itemInfo.isNewItem then
		if data.itemInfo.isBattlePayItem and decoration.BattlepayItemTexture then
			decoration.NewItemTexture:Hide()
			decoration.BattlepayItemTexture:Show()
		else
			if quality and NEW_ITEM_ATLAS_BY_QUALITY[quality] then
				decoration.NewItemTexture:SetAtlas(NEW_ITEM_ATLAS_BY_QUALITY[quality])
			else
				decoration.NewItemTexture:SetAtlas("bags-glow-white")
			end
			if decoration.BattlepayItemTexture then
				decoration.BattlepayItemTexture:Hide()
			end
			decoration.NewItemTexture:Show()
		end
		if not decoration.flashAnim:IsPlaying() and not decoration.newitemglowAnim:IsPlaying() then
			decoration.flashAnim:Play()
			decoration.newitemglowAnim:Play()
		end
	else
		if decoration.BattlepayItemTexture then
			decoration.BattlepayItemTexture:Hide()
		end
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
	if decoration.NormalTexture then
		decoration.NormalTexture:SetSize(64, 64)
	elseif decoration.GetNormalTexture and decoration:GetNormalTexture() then
		decoration:GetNormalTexture():SetSize(64, 64)
	end
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
	if decoration.NormalTexture then
		decoration.NormalTexture:SetSize(64 / width, 64 / height)
	elseif decoration.GetNormalTexture and decoration:GetNormalTexture() then
		decoration:GetNormalTexture():SetSize(64 / width, 64 / height)
	end
	if decoration.IconQuestTexture then decoration.IconQuestTexture:SetSize(width, height) end
	if decoration.IconTexture then decoration.IconTexture:SetSize(width, height) end
	if decoration.IconOverlay then decoration.IconOverlay:SetSize(width, height) end
end

-- Blizzard's Classic SetItemButtonQuality (Blizzard_ItemButton/Classic/ItemButtonTemplate.lua)
-- has its quality-color block commented out and always ends with IconBorder:Hide(), so
-- non-retail clients have to draw the rarity border themselves.
---@param decoration ItemButton
---@param quality number?
-- DrawQualityGlow draws the item quality indicator on the decoration's IconBorder.
-- Uncommon+ items get an additive quality glow (UI-ActionButton-Border); "Extra
-- Glowy" is the full-intensity version, otherwise the glow is dimmed to a subtle
-- level so quality is still visible without the option (Classic's default bags
-- draw no quality border at all). Poor/Common items get no border, matching
-- Blizzard's own SetItemButtonQuality (which returns no color for Poor/Common) and
-- avoiding a stray border on plain items. Retail and Classic share this path.
---@param decoration Frame
---@param quality number
function itemFrame.itemProto:DrawQualityGlow(decoration, quality)
	local border = decoration.IconBorder
	if not border then return end
	if quality and quality > const.ITEM_QUALITY.Common then
		local qualityColor = const.ITEM_QUALITY_COLOR[quality] or const.ITEM_QUALITY_COLOR[const.ITEM_QUALITY.Common]
		border:SetTexture([[Interface\Buttons\UI-ActionButton-Border]])
		border:SetBlendMode("ADD")
		border:SetTexCoord(14 / 64, 49 / 64, 15 / 64, 50 / 64)
		local alpha = database:GetExtraGlowyButtons(self.kind) and 1 or SUBTLE_QUALITY_GLOW_ALPHA
		border:SetVertexColor(qualityColor[1], qualityColor[2], qualityColor[3], (qualityColor[4] or 1) * alpha)
		border:Show()
	else
		border:Hide()
	end
end

-- DrawClassicQualityBorder draws a thin colored quality border for free slots on
-- Classic (special bags with a non-common bag quality). Only Uncommon+ gets a
-- border, matching Blizzard's SetItemButtonQuality (no color for Poor/Common):
-- drawing a white border on a plain empty slot double-borders the empty-slot
-- texture and reads as a stray/offset frame.
---@param decoration Frame
---@param quality number
function itemFrame.itemProto:DrawClassicQualityBorder(decoration, quality)
	if not decoration.IconBorder then return end
	local qualityColor = quality and quality > const.ITEM_QUALITY.Common and const.ITEM_QUALITY_COLOR[quality]
	if qualityColor then
		decoration.IconBorder:SetVertexColor(unpack(qualityColor))
		decoration.IconBorder:Show()
	else
		decoration.IconBorder:Hide()
	end
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
	self.kind = bagKindFromBagID(bagid)

	if count == 0 then
		self.button:Disable()
	else
		self.button:Enable()
	end

	self.stackCount = 1
	decoration.minDisplayCount = -1
	self.freeSlotCount = count

	if ClearItemButtonOverlay then ClearItemButtonOverlay(decoration) end
	if decoration.SetHasItem then decoration:SetHasItem(false) end
	if self.button.SetHasItem then self.button:SetHasItem(false) end
	if not nocount then
		SetItemButtonCount(decoration, count)
	end
	decoration.GetItemContextMatchResult = nil
	if addon.isRetail then
		if decoration.SetItemButtonTexture then decoration:SetItemButtonTexture(0) else SetItemButtonTexture(decoration, 0) end
	else
		if decoration.SetItemButtonTexture then decoration:SetItemButtonTexture([[Interface\PaperDoll\UI-Backpack-EmptySlot]]) else SetItemButtonTexture(decoration, [[Interface\PaperDoll\UI-Backpack-EmptySlot]]) end
		if decoration.ExtendedSlot then decoration.ExtendedSlot:Hide() end
	end
	if decoration.UpdateQuestItem then decoration:UpdateQuestItem(false, nil, nil) end
	if decoration.UpdateNewItem then decoration:UpdateNewItem(false) end
	if decoration.UpdateJunkItem then decoration:UpdateJunkItem(false, false) end
	if decoration.UpdateItemContextMatching then decoration:UpdateItemContextMatching() end
	SetItemButtonDesaturated(decoration, false)
	if decoration.UpdateCooldown then decoration:UpdateCooldown(false) end
	self.ilvlText:SetText("")
	self.ilvlText:Hide()
	decoration.UpgradeIcon:SetShown(false)
	if addon.isRetail then
		if self.button.UpdateExtended then
			self.button:UpdateExtended()
		end
		if decoration.UpdateExtended then
			decoration:UpdateExtended()
		end
	end

	self.freeSlotName = data.itemInfo and data.itemInfo.emptySlotName or ""

	-- Specialized bags (reagent, quiver, soul, herb, ...) carry a pre-resolved glyph atlas,
	-- drawn centered and semi-transparent. Generic bags leave it nil, so the overlay stays hidden.
	local familyIcon = data.itemInfo and data.itemInfo.emptySlotFamilyIcon
	local familyTexture = getFamilyIconTexture(decoration)
	if familyIcon then
		familyTexture:SetAtlas(familyIcon)
		familyTexture:SetSize(FAMILY_ICON_SIZE, FAMILY_ICON_SIZE)
		familyTexture:Show()
	else
		familyTexture:Hide()
	end

	local quality = data.itemInfo and data.itemInfo.itemQuality or const.ITEM_QUALITY.Common
	SetItemButtonQuality(decoration, quality, nil, false, false)
	decoration.IconBorder:SetTexture([[Interface\Common\WhiteIconFrame]])
	decoration.IconBorder:SetBlendMode("BLEND")
	decoration.IconBorder:SetTexCoord(0, 1, 0, 1)
	if not addon.isRetail then
		self:DrawClassicQualityBorder(decoration, quality)
	end
	self.isFreeSlot = true
	if addon.isRetail and decoration.ItemSlotBackground then decoration.ItemSlotBackground:Show() end
	self.frame:SetAlpha(1)
	events:SendMessage(ctx, "item/Updated", self, decoration)
	self.frame:Show()
	self.button:Show()
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
	if self.isVirtual then
		itemFrame:ReleaseVirtualButton(self)
	end
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
	if decoration.BetterBagsFamilyIcon then decoration.BetterBagsFamilyIcon:Hide() end
	self.currentData = nil
	self.kind = nil
	self.frame:ClearAllPoints()
	self.frame:SetParent(nil)
	self.frame:SetAlpha(1)
	self.frame:Hide()
	if decoration.SetHasItem then decoration:SetHasItem(false) end
	if self.button.SetHasItem then self.button:SetHasItem(false) end
	decoration.GetItemContextMatchResult = nil
	if addon.isRetail then
		if decoration.SetItemButtonTexture then decoration:SetItemButtonTexture(0) else SetItemButtonTexture(decoration, 0) end
	else
		if decoration.SetItemButtonTexture then decoration:SetItemButtonTexture([[Interface\PaperDoll\UI-Backpack-EmptySlot]]) else SetItemButtonTexture(decoration, [[Interface\PaperDoll\UI-Backpack-EmptySlot]]) end
		if decoration.ExtendedSlot then decoration.ExtendedSlot:Hide() end
	end
	if decoration.UpdateQuestItem then decoration:UpdateQuestItem(false, nil, nil) end
	if decoration.UpdateNewItem then decoration:UpdateNewItem(false) end
	if decoration.UpdateJunkItem then decoration:UpdateJunkItem(false, false) end
	if decoration.UpdateItemContextMatching then decoration:UpdateItemContextMatching() end
	SetItemButtonQuality(decoration, false)
	decoration.minDisplayCount = 1
	SetItemButtonCount(decoration, 0)
	SetItemButtonDesaturated(decoration, false)
	if ClearItemButtonOverlay then ClearItemButtonOverlay(decoration) end
	if decoration.UpdateCooldown then decoration:UpdateCooldown(false) end
	if decoration.ItemSlotBackground then decoration.ItemSlotBackground:Hide() end
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

function itemFrame:Init()
	self.buttonsBySlotkey = {}
	self.virtualPool = {}
	self.activeItems = setmetatable({}, { __mode = "k" })
end

function itemFrame:OnEnable()
	self.emptyItemTooltip = CreateFrame("GameTooltip", "BetterBagsEmptySlotTooltip", UIParent, "GameTooltipTemplate") --[[@as GameTooltip]]
	if self.emptyItemTooltip.GetScale then
		self.emptyItemTooltip:SetScale(self.emptyItemTooltip:GetScale())
	end

	events:RegisterMessage("itemLevel/MaxChanged", function()
		self:RefreshItemLevelColors()
	end)

	local ctx = context:New("itemFrame_OnEnable")
	-- Pre-allocate virtual item buttons for non-physical/virtual slots.
	for _ = 1, 50 do
		local vItem = self:_DoCreate(ctx, -3)
		vItem.isVirtual = true
		vItem.frame:Hide()
		tinsert(self.virtualPool, vItem)
	end

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
	if button.PushedTexture then button.PushedTexture:SetTexture("") elseif button.GetPushedTexture and button:GetPushedTexture() then button:GetPushedTexture():SetTexture("") end
	if button.NormalTexture then button.NormalTexture:SetTexture("") elseif button.GetNormalTexture and button:GetNormalTexture() then button:GetNormalTexture():SetTexture("") end

	-- On Classic/TBC, replace the template's native tooltip handler so the main bank
	-- container (bag id -1) uses BankFrameItemButton_OnEnter (SetInventoryItem) instead of
	-- the SetBagItem(-1, slot) path (see itemProto:UpdateTooltip). This is set before the
	-- OnEnter/OnLeave HookScripts below so those (highlight, i:OnEnter) layer on top of it,
	-- and UpdateTooltip is overridden so GameTooltip's 0.2s re-poll uses the same dispatcher.
	-- Retail's ItemButtonMixin:OnEnter resolves bank slots correctly, so it is left untouched.
	if not addon.isRetail then
		button.GetInventorySlot = ButtonInventorySlot
		button.UpdateTooltip = function() i:UpdateTooltip() end
		button:SetScript("OnEnter", function() i:UpdateTooltip() end)
	end

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
		-- Acquire from pre-allocated virtual item pool.
		return self:AcquireVirtualItem(ctx, slotkey)
	end
end

---@param ctx Context
---@param slotkey string
---@return Item
function itemFrame:AcquireVirtualItem(ctx, slotkey)
	local item
	if self.virtualPool and #self.virtualPool > 0 then
		item = tremove(self.virtualPool)
	else
		debug:Log("ItemFrame", "Virtual item pool empty, creating dynamic button for %s", tostring(slotkey))
		item = self:Create(ctx, -3)
	end
	item.isVirtual = true
	item.slotkey = slotkey
	self.buttonsBySlotkey[slotkey] = item
	return item
end

---@param item Item
function itemFrame:ReleaseVirtualButton(item)
	if not item or not item.isVirtual then return end
	if item.slotkey then
		self.buttonsBySlotkey[item.slotkey] = nil
		item.slotkey = nil
	end
	if self.virtualPool then
		tinsert(self.virtualPool, item)
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
		if item.currentData and not item.currentData.isItemEmpty and not item.isFreeSlot then
			item:DrawItemLevel(item.currentData)
		end
	end
end
