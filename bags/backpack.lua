---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)

---@class BackpackBehavior: AceModule
---@field proto BackpackBehaviorProto
local backpack = addon:NewModule("BackpackBehavior")

---@class Constants: AceModule
local const = addon:GetModule("Constants")

---@class Events: AceModule
local events = addon:GetModule("Events")

---@class Debug: AceModule
local debug = addon:GetModule("Debug")

---@class BagSlots: AceModule
local bagSlots = addon:GetModule("BagSlots")

---@class SearchBox: AceModule
local searchBox = addon:GetModule("SearchBox")

---@class Currency: AceModule
local currency = addon:GetModule("Currency")

---@class ThemeConfig: AceModule
local themeConfig = addon:GetModule("ThemeConfig")

---@class MoneyFrame: AceModule
local money = addon:GetModule("MoneyFrame")

-------
--- Backpack Behavior Prototype
-------

--- BackpackBehaviorProto defines the behavior specific to the player's backpack.
---@class BackpackBehaviorProto
---@field bag Bag Reference to the parent bag
backpack.proto = {}

---@param ctx Context
---@param bag Bag
function backpack.proto:OnShow(ctx, bag)
	PlaySound(SOUNDKIT.IG_BACKPACK_OPEN)
	bag.frame:Show()
	ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
end

---@param ctx Context
---@param bag Bag
function backpack.proto:OnHide(ctx, bag)
	addon.ForceHideBlizzardBags()
	PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)
	bag.frame:Hide()
	bag.searchFrame:Hide()
	if bag.drawOnClose then
		debug:Log("draw", "Drawing bag on close")
		bag.drawOnClose = false
		bag:Refresh(ctx)
	end
	ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
end

---@param ctx Context
---@param bag Bag
function backpack.proto:OnCreate(ctx, bag)
	-- Search frame
	bag.searchFrame = searchBox:Create(ctx, bag.frame)

	-- Bag slots panel
	local slots = bagSlots:CreatePanel(ctx, const.BAG_KIND.BACKPACK)
	slots.frame:SetPoint("BOTTOMLEFT", bag.frame, "TOPLEFT", 0, 8)
	slots.frame:SetParent(bag.frame)
	slots.frame:Hide()
	bag.slots = slots

	-- Currency frame
	local currencyFrame = currency:Create(bag.sideAnchor, bag.frame)
	currencyFrame:Hide()
	bag.currencyFrame = currencyFrame

	-- Theme config
	bag.themeConfigFrame = themeConfig:Create(bag.sideAnchor)
	bag.windowGrouping:AddWindow("themeConfig", bag.themeConfigFrame)
	bag.windowGrouping:AddWindow("currencyConfig", bag.currencyFrame)
end

---@param ctx Context
---@param bag Bag
function backpack.proto:OnRefresh(ctx, bag)
	events:SendMessage(ctx, "bags/RefreshBackpack")
end

---@return FrameStrata
function backpack.proto:GetFrameStrata()
	return "MEDIUM"
end

---@return number
function backpack.proto:GetFrameLevel()
	return 500
end

---@param bag Bag
---@param bottomBar Frame
---@return Money
function backpack.proto:SetupMoneyFrame(bag, bottomBar)
	local moneyFrame = money:Create()
	moneyFrame.frame:SetPoint("BOTTOMRIGHT", bottomBar, "BOTTOMRIGHT", -4, 0)
	moneyFrame.frame:SetParent(bag.frame)
	return moneyFrame
end

---@param bag Bag
function backpack.proto:RegisterEvents(bag)
	events:BucketEvent("BAG_UPDATE_COOLDOWN", function(ectx)
		bag:OnCooldown(ectx)
	end)
end

---@return boolean
function backpack.proto:ShouldHandleSort()
	return true
end

-------
--- BackpackBehavior Module Functions
-------

---@return BackpackBehaviorProto
function backpack:Create()
	local b = {}
	setmetatable(b, { __index = backpack.proto })
	return b
end
