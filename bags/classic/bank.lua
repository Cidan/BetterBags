---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)

---@class BankBehavior: AceModule
local bank = addon:GetModule("BankBehavior")

---@class Constants: AceModule
local const = addon:GetModule("Constants")

---@class Items: AceModule
local items = addon:GetModule("Items")

---@class Events: AceModule
local events = addon:GetModule("Events")

---@class Localization: AceModule
local L = addon:GetModule("Localization")

---@class Database: AceModule
local database = addon:GetModule('Database')

-------
--- Classic Bank Behavior Overrides
--- Classic (MoP Remix, Cata) doesn't have BankPanel, tabs, or warbank.
-------

function bank.proto:OnShow()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)

	-- Use fade animation if enabled
	if database:GetEnableBagFading() then
		self.bag.fadeInGroup:Play()
	else
		self.bag.frame:Show()
	end

	ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
end

function bank.proto:OnHide()
	-- Guard against re-entry to prevent recursion.
	if self.isHiding then
		return
	end
	self.isHiding = true

	addon.ForceHideBlizzardBags()
	PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)

	-- Use fade animation if enabled
	if database:GetEnableBagFading() then
		self.bag.fadeOutGroup.callback = function()
			self.bag.fadeOutGroup.callback = nil  -- Clean up callback
			self.isHiding = false  -- Clear flag after animation completes
			CloseBankFrame()
			ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
		end
		self.bag.fadeOutGroup:Play()
	else
		self.bag.frame:Hide()
		self.isHiding = false  -- Clear flag immediately
		CloseBankFrame()
		ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
	end
end

function bank.proto:OnCreate()
	-- Classic bank doesn't have tabs or BankPanel settings
	self.bag.bankTab = const.BANK_TAB.BANK
end

---@param ctx Context
function bank.proto:OnRefresh(ctx)
	events:SendMessage(ctx, "bags/RefreshBank")
end

---@return Money|nil
function bank.proto:SetupMoneyFrame()
	-- Classic bank doesn't have a money frame
	return nil
end

function bank.proto:RegisterEvents()
	-- No bank-specific events in Classic
end

---@param ctx Context
function bank.proto:SwitchToBankAndWipe(ctx)
	ctx:Set("wipe", true)
	self.bag.bankTab = const.BANK_TAB.BANK
	BankFrame.selectedTab = 1
	self.bag:SetTitle(L:G("Bank"))
	items:ClearBankCache(ctx)
	self.bag:Wipe(ctx)
end
