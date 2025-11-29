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

function backpack.proto:OnShow()
	PlaySound(SOUNDKIT.IG_BACKPACK_OPEN)
	self.bag.frame:Show()
	ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
end

---@param ctx Context
function backpack.proto:OnHide(ctx)
	addon.ForceHideBlizzardBags()
	PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)
	self.bag.frame:Hide()
	self.bag.searchFrame:Hide()
	if self.bag.drawOnClose then
		debug:Log("draw", "Drawing bag on close")
		self.bag.drawOnClose = false
		self.bag:Refresh(ctx)
	end
	ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
end

---@param ctx Context
function backpack.proto:OnCreate(ctx)
	-- Search frame
	self.bag.searchFrame = searchBox:Create(ctx, self.bag.frame)

	-- Bag slots panel
	local slots = bagSlots:CreatePanel(ctx, const.BAG_KIND.BACKPACK)
	slots.frame:SetPoint("BOTTOMLEFT", self.bag.frame, "TOPLEFT", 0, 8)
	slots.frame:SetParent(self.bag.frame)
	slots.frame:Hide()
	self.bag.slots = slots

	-- Currency frame
	local currencyFrame = currency:Create(self.bag.sideAnchor, self.bag.frame)
	currencyFrame:Hide()
	self.bag.currencyFrame = currencyFrame

	-- Theme config
	self.bag.themeConfigFrame = themeConfig:Create(self.bag.sideAnchor)
	self.bag.windowGrouping:AddWindow("themeConfig", self.bag.themeConfigFrame)
	self.bag.windowGrouping:AddWindow("currencyConfig", self.bag.currencyFrame)
end

---@param ctx Context
function backpack.proto:OnRefresh(ctx)
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

---@param bottomBar Frame
---@return Money
function backpack.proto:SetupMoneyFrame(bottomBar)
	local moneyFrame = money:Create()
	moneyFrame.frame:SetPoint("BOTTOMRIGHT", bottomBar, "BOTTOMRIGHT", -4, 0)
	moneyFrame.frame:SetParent(self.bag.frame)
	return moneyFrame
end

function backpack.proto:RegisterEvents()
	local bag = self.bag
	events:BucketEvent("BAG_UPDATE_COOLDOWN", function(ectx)
		bag:OnCooldown(ectx)
	end)
end

---@return boolean
function backpack.proto:ShouldHandleSort()
	return true
end

function backpack.proto:SwitchToBankAndWipe()
	-- No-op for backpack - this method only applies to bank
end

-------
--- BackpackBehavior Module Functions
-------

---@param bag Bag
---@return BackpackBehaviorProto
function backpack:Create(bag)
	local b = {}
	setmetatable(b, { __index = backpack.proto })
	b.bag = bag
	return b
end
