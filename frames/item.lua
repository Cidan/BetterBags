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

---@class Sonata: AceModule
local sonata = addon:GetModule("Sonata")

---@class SonataElements: AceModule
local elements = addon:GetModule("SonataElements")

---@class Context: AceModule
local context = addon:GetModule("Context")

---@class Debug: AceModule
local debug = addon:GetModule("Debug")

-- Alpha floor for the additive quality halo the instant it turns on, just above
-- the halo threshold. The halo ramps from this value at (threshold + 1) up to a
-- blinding 1.0 at intensity 100, so it is already clearly visible the moment it
-- kicks in rather than fading up from invisible. See DrawQualityGlow.
local HALO_MIN_ALPHA = 0.4

-- qualityColorOf returns the color a theme draws an item quality with: Uncommon and above,
-- none for Poor and Common (Blizzard's SetItemButtonQuality draws them no border either).
---@param quality? number
---@return number[]?
local function qualityColorOf(quality)
	if quality and quality > const.ITEM_QUALITY.Common then
		return const.ITEM_QUALITY_COLOR[quality]
	end
	return nil
end

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
---@field drawState table|nil The inputs of the last full draw (see DrawInputChanged).
---@field cooldownState table|nil The cooldown last applied (see UpdateCooldown).
itemFrame.itemProto = {}
-- Bumped by RestyleButtons; part of every button's draw record.
itemFrame.styleGeneration = 0
addon:GetModule('Perf'):RegisterPrototype(itemFrame.itemProto, 'Item')

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

-- searchMatch is the search state a full draw applies: the live search result when a
-- search is active, else the client's own filter.
---@param data ItemData
---@return boolean
local function searchMatch(data)
	if data.isSearchResult ~= nil then
		return data.isSearchResult
	end
	return not (data.containerInfo and data.containerInfo.isFiltered)
end

-- Each button records in item.drawState the inputs of its last full draw. A redraw whose
-- inputs all match skips the setters: the decoration still shows what they would set. The
-- inputs are the item's itemHash (item ID, enchant, gems, bonus IDs, binding, item level
-- and stats), every other ItemData field the setters read, the data phase's draw generation
-- (a new one after every wipe sweep and restyling recalculation), the button style generation (RestyleButtons: settings
-- the setters read, such as glow intensity, changed with no new data), and the decoration
-- and theme generation the button was drawn with. ResetVisuals (a release or a change
-- between item, free slot and empty slot) and Lock clear the record; UpdateSearch keeps its
-- search match current.
-- stackHidesItemLevel says whether an item's virtual stack hides its item level: a stack of
-- more than one armor or weapon piece shows its count instead (with Merge Unstackable, a
-- setting that redraws every button when it changes). Shared by DrawItemLevel and the draw
-- record, so the record holds exactly what the draw uses.
---@param data ItemData
---@return boolean
local function stackHidesItemLevel(data)
	local classID = data.itemInfo.classID
	return (classID == Enum.ItemClass.Armor or classID == Enum.ItemClass.Weapon)
		and data.stackedCount ~= nil and data.stackedCount > 1
end

-- DrawInputChanged returns the name of the first input of a full item draw that differs
-- from the button's record, or nil when the redraw can be skipped ("record" when there is no
-- valid record, "staticData" for item rows, which never skip). It is a method of the Item
-- prototype so the profiler's call trace records the answer for every draw, which is how a
-- capture shows why a button redrew (data-driven.md).
---@param decoration ItemButton
---@param data ItemData
---@return string|nil
function itemFrame.itemProto:DrawInputChanged(decoration, data)
	local s = self.drawState
	if not s or not s.valid then return "record" end
	if self.staticData then return "staticData" end
	local info, quest, container = data.itemInfo, data.questInfo, data.containerInfo
	if s.decoration ~= decoration then return "decoration" end
	if s.decorationGeneration ~= sonata:GetGeneration() then return "decorationGeneration" end
	if s.styleGeneration ~= itemFrame.styleGeneration then return "styleGeneration" end
	if s.drawGeneration ~= data.drawGeneration then return "drawGeneration" end
	if s.bagid ~= data.bagid then return "bagid" end
	if s.itemHash ~= data.itemHash then return "itemHash" end
	if s.itemLink ~= info.itemLink then return "itemLink" end
	if s.itemIcon ~= info.itemIcon then return "itemIcon" end
	if s.itemQuality ~= info.itemQuality then return "itemQuality" end
	if s.isBound ~= info.isBound then return "isBound" end
	if s.currentItemLevel ~= info.currentItemLevel then return "currentItemLevel" end
	if s.classID ~= info.classID then return "classID" end
	if s.shownCount ~= (data.stackedCount or info.currentItemCount) then return "shownCount" end
	if s.stackHidesLevel ~= stackHidesItemLevel(data) then return "stackHidesLevel" end
	if s.isNewItem ~= info.isNewItem then return "isNewItem" end
	if s.isBattlePayItem ~= info.isBattlePayItem then return "isBattlePayItem" end
	if s.isQuestItem ~= quest.isQuestItem then return "isQuestItem" end
	if s.questID ~= quest.questID then return "questID" end
	if s.isActive ~= quest.isActive then return "isActive" end
	if s.readable ~= (container and container.isReadable) then return "readable" end
	if s.noValue ~= (container and container.hasNoValue) then return "noValue" end
	if s.matches ~= searchMatch(data) then return "matches" end
	if s.isUpgrade ~= data.isUpgrade then return "isUpgrade" end
	if s.itemContextMatchResult ~= data.itemContextMatchResult then return "itemContextMatchResult" end
	return nil
end

---@param item Item
---@param decoration ItemButton
---@param data ItemData
local function recordItemDraw(item, decoration, data)
	local s = item.drawState or {}
	item.drawState = s
	local info, quest, container = data.itemInfo, data.questInfo, data.containerInfo
	s.decoration = decoration
	s.decorationGeneration = sonata:GetGeneration()
	s.styleGeneration = itemFrame.styleGeneration
	s.drawGeneration = data.drawGeneration
	s.bagid = data.bagid
	s.itemHash = data.itemHash
	s.itemLink = info.itemLink
	s.itemIcon = info.itemIcon
	s.itemQuality = info.itemQuality
	s.isBound = info.isBound
	s.currentItemLevel = info.currentItemLevel
	s.classID = info.classID
	-- What the draw uses of the counts: the number shown and whether the stack hides the item
	-- level. The raw stack total is empty when stacking is off (Show Bags) and equal to the
	-- item's own count for a single pile otherwise; recording it redrew every item on each
	-- Show Bags toggle with nothing on screen changed.
	s.shownCount = data.stackedCount or info.currentItemCount
	s.stackHidesLevel = stackHidesItemLevel(data)
	s.isNewItem = info.isNewItem
	s.isBattlePayItem = info.isBattlePayItem
	s.isQuestItem = quest.isQuestItem
	s.questID = quest.questID
	s.isActive = quest.isActive
	s.readable = container and container.isReadable
	s.noValue = container and container.hasNoValue
	s.matches = searchMatch(data)
	s.isUpgrade = data.isUpgrade
	s.itemContextMatchResult = data.itemContextMatchResult
	s.valid = true
end

-- FreeDrawInputChanged is DrawInputChanged for a free-slot draw.
---@param decoration ItemButton
---@param data ItemData
---@param count number
---@param nocount? boolean
---@return string|nil
function itemFrame.itemProto:FreeDrawInputChanged(decoration, data, count, nocount)
	local s = self.drawState
	if not s or not s.valid then return "record" end
	local info = data.itemInfo
	if s.decoration ~= decoration then return "decoration" end
	if s.decorationGeneration ~= sonata:GetGeneration() then return "decorationGeneration" end
	if s.styleGeneration ~= itemFrame.styleGeneration then return "styleGeneration" end
	if s.bagid ~= data.bagid then return "bagid" end
	if s.count ~= count then return "count" end
	if s.nocount ~= (nocount and true or false) then return "nocount" end
	if s.emptySlotName ~= (info and info.emptySlotName) then return "emptySlotName" end
	if s.emptySlotFamilyIcon ~= (info and info.emptySlotFamilyIcon) then return "emptySlotFamilyIcon" end
	if s.itemQuality ~= (info and info.itemQuality) then return "itemQuality" end
	return nil
end

---@param item Item
---@param decoration ItemButton
---@param data ItemData
---@param count number
---@param nocount? boolean
local function recordFreeDraw(item, decoration, data, count, nocount)
	local s = item.drawState or {}
	item.drawState = s
	local info = data.itemInfo
	s.decoration = decoration
	s.decorationGeneration = sonata:GetGeneration()
	s.styleGeneration = itemFrame.styleGeneration
	s.bagid = data.bagid
	s.count = count
	s.nocount = nocount and true or false
	s.emptySlotName = info and info.emptySlotName
	s.emptySlotFamilyIcon = info and info.emptySlotFamilyIcon
	s.itemQuality = info and info.itemQuality
	s.valid = true
end

-- GetDecoration returns the button's decoration: the ContainerFrameItemButtonTemplate button
-- one level below the interaction button that draws the item. It is made once, styled by
-- Sonata as an ItemButton element (a theme restyles it; it never builds its own), and
-- announced with item/NewButton (Masque adds it to its group).
---@param ctx Context
---@return ItemButton
function itemFrame.itemProto:GetDecoration(ctx)
	local decoration = self._decoration
	if decoration == nil then
		decoration = itemFrame:CreateDecoration(self)
		self._decoration = decoration
		sonata:RegisterElement("ItemButton", decoration)
		events:SendMessage(ctx, 'item/NewButton', self, decoration)
	end
	return decoration
end

---@param ctx Context
---@param found? boolean
function itemFrame.itemProto:UpdateSearch(ctx, found)
	self.blank = false
	if self.slotkey == nil then
		return
	end
	local decoration = self:GetDecoration(ctx)
	decoration:SetMatchesSearch(found and true or false)
	if self.drawState then
		self.drawState.matches = found and true or false
	end
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

-- UpdateCooldown applies the client's cooldown for the item to the button: the cooldown
-- spiral, the dimmed icon while a used item's cooldown has not started, and (retail) the
-- has-item state. Blizzard's update reads the cooldown with GetContainerItemCooldown and
-- applies all three; the button records what it applied (cooldownState). With
-- onlyIfChanged (the BAG_UPDATE_COOLDOWN refresh, bag:OnCooldown) it reads the cooldown
-- with the same bag and slot Blizzard's update would, and skips the update when the
-- cooldown, the icon, the decoration and the theme generation all match the record. A
-- full draw always applies. ResetVisuals and SetFreeSlots, which clear the cooldown,
-- invalidate the record. Item rows never skip.
---@param ctx Context
---@param data ItemData
---@param onlyIfChanged? boolean
function itemFrame.itemProto:UpdateCooldown(ctx, data, onlyIfChanged)
	self.blank = false
	assert(data, "data must be provided")
	if data.isItemEmpty then
		return
	end
	local decoration = self:GetDecoration(ctx)
	local retail = decoration.UpdateCooldown ~= nil
	if not retail and data.bagid == nil then
		return
	end
	local readCooldown = C_Container and C_Container.GetContainerItemCooldown
	local bag, slot, start, duration, enable
	if readCooldown then
		if retail then
			bag, slot = decoration:GetBagID(), decoration:GetID()
		else
			bag, slot = data.bagid, decoration:GetID()
		end
		start, duration, enable = readCooldown(bag, slot)
	end
	local icon = data.itemInfo.itemIcon
	local s = self.cooldownState
	if onlyIfChanged and readCooldown and not self.staticData and s and s.valid
		and s.decoration == decoration and s.decorationGeneration == sonata:GetGeneration()
		and s.bag == bag and s.slot == slot and s.icon == icon
		and s.start == start and s.duration == duration and s.enable == enable then
		return
	end
	if retail then
		decoration:UpdateCooldown(icon)
	else
		ContainerFrame_UpdateCooldown(data.bagid, decoration)
	end
	s = s or {}
	self.cooldownState = s
	s.decoration = decoration
	s.decorationGeneration = sonata:GetGeneration()
	s.bag, s.slot, s.icon = bag, slot, icon
	s.start, s.duration, s.enable = start, duration, enable
	s.valid = readCooldown ~= nil
end

---@param ctx Context
function itemFrame.itemProto:Lock(ctx)
	self.blank = false
	local decoration = self:GetDecoration(ctx)
	SetItemButtonDesaturated(decoration, true)
	if self.drawState then
		self.drawState.valid = false
	end
end

---@param ctx Context
function itemFrame.itemProto:Unlock(ctx)
	self.blank = false
	local decoration = self:GetDecoration(ctx)
	SetItemButtonDesaturated(decoration, false)
end

---@param data ItemData
function itemFrame.itemProto:ShowItemLevel(data)
	self.blank = false
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
	self.blank = false
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

	if mergeOpts.mergeUnstackable and stackHidesItemLevel(data) then
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
	self.blank = false
	assert(data, "data must be provided")
	if data.isItemEmpty then
		return
	end
	local decoration = self:GetDecoration(ctx)
	SetItemButtonCount(decoration, data.stackedCount or data.itemInfo.currentItemCount)
end

---@param ctx Context
---@param data ItemData
function itemFrame.itemProto:UpdateUpgrade(ctx, data)
	self.blank = false
	local decoration = self:GetDecoration(ctx)
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
	self.blank = false
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
	local mode = data.isItemEmpty and "empty" or "item"
	if self.drawnAs ~= mode and not self.blank then
		self:ResetVisuals(ctx)
	end
	self.drawnAs = mode
	self.blank = false
	self.released = false
	self.currentData = data
	self.slotkey = data.slotkey
	local decoration = self:GetDecoration(ctx)
	decoration._itemData = data
	self.kind = bagKindFromBagID(data.bagid)

	if mode == "item" and not self:DrawInputChanged(decoration, data) then
		-- The new-item glow loops; a full draw replays the one-shot flash whenever the glow
		-- has stopped, so a new item still goes through UpdateNewItem.
		if data.itemInfo.isNewItem then
			self:UpdateNewItem(ctx, data)
		end
		self:FinishItemDraw(ctx, decoration)
		return
	end

	local tooltipOwner = GameTooltip:GetOwner()

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
	local quality = data.itemInfo.itemQuality
	if not elements:DrawItemQuality(decoration, qualityColorOf(quality), quality) then
		self:DrawQualityGlow(decoration, quality)
	end
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
	elements:DrawItemQuest(decoration, questInfo)
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
	self:UpdateUpgrade(ctx, data)
	recordItemDraw(self, decoration, data)
	self:FinishItemDraw(ctx, decoration)
end

-- FinishItemDraw is the part of an item draw that runs even when the drawn inputs are
-- unchanged: it keeps the decoration below the interaction button and the button shown.
---@param _ctx Context
---@param decoration ItemButton
function itemFrame.itemProto:FinishItemDraw(_ctx, decoration)
	decoration:SetFrameLevel(math.max(0, self.button:GetFrameLevel() - 1))

	-- Classic quality glow fix: the interaction button's own NormalTexture
	-- (Interface\Buttons\UI-Quickslot2, a 64x64 beveled frame) is re-shown by
	-- Blizzard's drag/update logic and, because the decoration sits one frame
	-- level BELOW self.button, that frame drew OVER the decoration's quality glow
	-- and hid it. A plain Hide() loses to the re-show, so clear the texture value
	-- itself -- nothing renders even when it is re-shown, and the additive glow
	-- from DrawQualityGlow becomes visible, matching retail behavior
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
	self.blank = false
	local decoration = self:GetDecoration(ctx)
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
	self.blank = false
	local decoration = self:GetDecoration(ctx)
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
	self.blank = false
	local decoration = self:GetDecoration(ctx)
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
	local decoration = self:GetDecoration(ctx)
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
	local decoration = self:GetDecoration(ctx)
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
-- DrawQualityGlow draws the item quality indicator on the decoration's IconBorder,
-- scaled by the per-kind "Quality Glow" intensity slider (0-100). Poor/Common items
-- never get a border (matching Blizzard's SetItemButtonQuality, which returns no
-- color for them) and neither does intensity 0. The slider then has two phases,
-- both colored by the item's quality:
--   * intensity 1..threshold (60): a flat colored border (WhiteIconFrame, BLEND)
--     whose alpha fades in as intensity/threshold, reaching a solid border at the
--     threshold. No glow yet.
--   * intensity threshold+1..100: the additive glowing halo (UI-ActionButton-Border,
--     ADD) that alphas in from HALO_MIN_ALPHA to a blinding 1.0 at 100.
-- Retail and Classic share this single path.
---@param decoration Frame
---@param quality number
function itemFrame.itemProto:DrawQualityGlow(decoration, quality)
	self.blank = false
	local border = decoration.IconBorder
	if not border then return end
	local intensity = database:GetGlowIntensity(self.kind)
	if not (quality and quality > const.ITEM_QUALITY.Common) or not intensity or intensity <= 0 then
		border:Hide()
		return
	end
	local qualityColor = const.ITEM_QUALITY_COLOR[quality] or const.ITEM_QUALITY_COLOR[const.ITEM_QUALITY.Common]
	local threshold = const.GLOW_INTENSITY_HALO_THRESHOLD
	local baseAlpha = qualityColor[4] or 1
	if intensity <= threshold then
		-- Flat colored quality border, fading in with intensity. No halo.
		border:SetTexture([[Interface\Common\WhiteIconFrame]])
		border:SetBlendMode("BLEND")
		border:SetTexCoord(0, 1, 0, 1)
		local alpha = intensity / threshold
		border:SetVertexColor(qualityColor[1], qualityColor[2], qualityColor[3], baseAlpha * alpha)
	else
		-- Additive glowing halo ramping from a clearly-visible floor to full.
		border:SetTexture([[Interface\Buttons\UI-ActionButton-Border]])
		border:SetBlendMode("ADD")
		border:SetTexCoord(14 / 64, 49 / 64, 15 / 64, 50 / 64)
		local t = (intensity - threshold) / (const.GLOW_INTENSITY_MAX - threshold)
		local alpha = HALO_MIN_ALPHA + (1 - HALO_MIN_ALPHA) * t
		border:SetVertexColor(qualityColor[1], qualityColor[2], qualityColor[3], baseAlpha * alpha)
	end
	border:Show()
end

-- DrawClassicQualityBorder draws a thin colored quality border for free slots on
-- Classic (special bags with a non-common bag quality). Only Uncommon+ gets a
-- border, matching Blizzard's SetItemButtonQuality (no color for Poor/Common):
-- drawing a white border on a plain empty slot double-borders the empty-slot
-- texture and reads as a stray/offset frame.
---@param decoration Frame
---@param quality number
function itemFrame.itemProto:DrawClassicQualityBorder(decoration, quality)
	self.blank = false
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
	local decoration = self:GetDecoration(ctx)
	assert(data, "data must be provided")
	if self.drawnAs ~= "free" and not self.blank then
		self:ResetVisuals(ctx)
	end
	self.drawnAs = "free"
	self.blank = false
	self.released = false
	local bagid, slotid = data.bagid, data.slotid
	self.slotkey = data.slotkey or items:GetSlotKeyFromBagAndSlot(bagid, slotid)
	self.kind = bagKindFromBagID(bagid)

	if not self:FreeDrawInputChanged(decoration, data, count, nocount) then
		self.frame:Show()
		self.button:Show()
		return
	end

	if count == 0 then
		self.button:Disable()
	else
		self.button:Enable()
	end

	self.stackCount = 1
	if nocount then
		-- Clear a count left by the previous draw while the minimum is 1, so 0 stays
		-- hidden (with the -1 minimum below, a count of 0 would show "0").
		decoration.minDisplayCount = 1
		SetItemButtonCount(decoration, 0)
	end
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
	if self.cooldownState then
		self.cooldownState.valid = false
	end
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

	-- No `or Common` fallback: a nil quality must stay nil so SetItemButtonQuality (and, on
	-- classic, DrawClassicQualityBorder) draw no border. Coercing to Common would paint one,
	-- since ColorManager returns a color for Common. The aggregated free-slot "stack" button
	-- deliberately carries no quality so it renders borderless like a plain empty slot.
	local quality = data.itemInfo and data.itemInfo.itemQuality
	SetItemButtonQuality(decoration, quality, nil, false, false)
	decoration.IconBorder:SetTexture([[Interface\Common\WhiteIconFrame]])
	decoration.IconBorder:SetBlendMode("BLEND")
	decoration.IconBorder:SetTexCoord(0, 1, 0, 1)
	if not elements:DrawItemQuality(decoration, qualityColorOf(quality), quality) and not addon.isRetail then
		self:DrawClassicQualityBorder(decoration, quality)
	end
	self.isFreeSlot = true
	if addon.isRetail and decoration.ItemSlotBackground then decoration.ItemSlotBackground:Show() end
	self.frame:SetAlpha(1)
	recordFreeDraw(self, decoration, data, count, nocount)
	events:SendMessage(ctx, "item/Updated", self, decoration)
	self.frame:Show()
	self.button:Show()
end

---@param alpha number
function itemFrame.itemProto:SetAlpha(alpha)
	self.blank = false
	self.frame:SetAlpha(alpha)
end

---@param ctx Context
function itemFrame.itemProto:Release(ctx)
	self:Wipe(ctx)
end

-- Wipe takes the button off screen and resets it. A button not drawn since its last
-- release is left alone: a full teardown (bag:Wipe, DeleteTabView) followed by a draw
-- pass sweep must not release it twice, or a virtual button would enter its pool twice.
---@param ctx Context
function itemFrame.itemProto:Wipe(ctx)
	if self.released then
		return
	end
	self.frame:Hide()
	self.frame:SetParent(nil)
	self.frame:ClearAllPoints()
	self:ClearItem(ctx)
	self.released = true
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
	local decoration = self:GetDecoration(ctx)
	events:SendMessage(ctx, "item/Clearing", self, decoration)
	self.frame:ClearAllPoints()
	self.frame:SetParent(nil)
	self.frame:Hide()
	self:ResetVisuals(ctx)
	-- Size and static data are set by the caller before drawing (item rows size the
	-- button and use SetStaticItemFromData), so only a release clears them.
	self:ResetSize(ctx)
	self.stacks = {}
	self.staticData = nil
end

-- ResetVisuals returns the button to a blank slot without taking it off screen. Draws
-- call it only when the button changes what it shows (item, free slot, empty slot):
-- SetItemFromData and SetFreeSlots each set every visual of their own kind, so a
-- button redrawn as the same kind needs no reset.
---@param ctx Context
function itemFrame.itemProto:ResetVisuals(ctx)
	local decoration = self:GetDecoration(ctx)
	if self.drawState then
		self.drawState.valid = false
	end
	if decoration.BetterBagsFamilyIcon then decoration.BetterBagsFamilyIcon:Hide() end
	self.currentData = nil
	self.kind = nil
	self.drawnAs = nil
	self.frame:SetAlpha(1)
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
	elements:DrawItemQuality(decoration, nil, nil)
	decoration.minDisplayCount = 1
	SetItemButtonCount(decoration, 0)
	SetItemButtonDesaturated(decoration, false)
	if ClearItemButtonOverlay then ClearItemButtonOverlay(decoration) end
	if decoration.UpdateCooldown then decoration:UpdateCooldown(false) end
	if self.cooldownState then
		self.cooldownState.valid = false
	end
	if decoration.ItemSlotBackground then decoration.ItemSlotBackground:Hide() end
	self.button:Enable()
	self.ilvlText:SetText("")
	self.ilvlText:Hide()
	self.stackCount = 1
	self.stackid = nil
	self.isFreeSlot = false
	self.freeSlotName = ""
	self.freeSlotCount = 0
	decoration.UpgradeIcon:SetShown(false)
	-- Blank until something draws on it: a draw skips its mode-change reset for a blank
	-- button (a release already reset it). Everything that changes the button's look outside
	-- a full draw clears this.
	self.blank = true
end

-- CreateDecoration makes an item button's decoration, shown, behind the item's interaction
-- button. The template's normal, pushed, battle pay and new item textures are cleared: with
-- an empty slot drawn transparent on Classic they bleed through as a blue glow
-- (item-drawing.md section 6).
---@param item Item
---@return ItemButton
function itemFrame:CreateDecoration(item)
	local parent = item.frame
	local name = item.button:GetName() .. "Decoration"
	---@type ItemButton
	local button
	if addon.isRetail then
		button = CreateFrame("ItemButton", name, parent, "ContainerFrameItemButtonTemplate") --[[@as ItemButton]]
	else
		button = CreateFrame("Button", name, parent, "ContainerFrameItemButtonTemplate") --[[@as ItemButton]]
		---@diagnostic disable-next-line: duplicate-set-field
		button.SetMatchesSearch = function(me, match)
			if match then
				me.searchOverlay:Hide()
			else
				me.searchOverlay:Show()
			end
		end
	end
	button:SetAllPoints()

	if addon.isRetail then
		button.ItemSlotBackground = button:CreateTexture(nil, "BACKGROUND", "ItemSlotBackgroundCombinedBagsTemplate", -6)
		button.ItemSlotBackground:SetAllPoints(button)
		button.ItemSlotBackground:Hide()
	end

	button:SetFrameLevel(parent:GetFrameLevel() > 0 and parent:GetFrameLevel() - 1 or 0)
	button.IconTexture = _G[name .. "IconTexture"]
	if not button.IconQuestTexture then
		button.IconQuestTexture = _G[name .. "IconQuestTexture"]
	end
	if button.GetNormalTexture and button:GetNormalTexture() then
		button:GetNormalTexture():SetTexture("")
		button:GetNormalTexture():Hide()
	end
	if button.GetPushedTexture and button:GetPushedTexture() then
		button:GetPushedTexture():SetTexture("")
		button:GetPushedTexture():Hide()
	end
	if button.BattlepayItemTexture then button.BattlepayItemTexture:Hide() end
	if button.NewItemTexture then button.NewItemTexture:Hide() end
	button:Show()
	return button
end

function itemFrame:Init()
	self.buttonsBySlotkey = {}
	self.virtualPool = {}
	self.activeItems = setmetatable({}, { __mode = "k" })
end

-- RestyleButtons makes the next draw of every button run all of its setters, for settings
-- the setters read that change with no new item data (glow intensity, item level display).
function itemFrame:RestyleButtons()
	self.styleGeneration = self.styleGeneration + 1
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
	-- Retail character bank tabs hold up to 98 slots, like Warbank tabs: a capture of
	-- opening the bank created slots 41-98 of every character tab at runtime.
	if addon.isRetail and const.BANK_ONLY_BAGS then
		for bagID in pairs(const.BANK_ONLY_BAGS) do
			for slotID = 41, 98 do
				self:GetButton(ctx, bagID .. "_" .. slotID)
			end
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

	-- Cache a lazy reference to the decoration, so the mouse events below touch no addon
	-- tables (a context made during a mouse event can taint a protected click that follows).
	local decoration
	local getDecoration = function()
		if not decoration then
			decoration = i:GetDecoration(context:New("itemButton_init"))
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
		local decoration = item:GetDecoration(ctx)
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
	item.released = false
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
