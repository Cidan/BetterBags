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

-------
--- Era Bank Behavior Overrides
--- Classic Era doesn't have BankPanel, tabs, or warbank.
-------

function bank.proto:OnShow()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
	self.bag.frame:Show()
	ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
end

function bank.proto:OnHide()
	addon.ForceHideBlizzardBags()
	PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
	self.bag.frame:Hide()
	CloseBankFrame()
	ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
end

function bank.proto:OnCreate()
	-- Era bank doesn't have tabs or BankPanel settings
	self.bag.bankTab = const.BANK_TAB.BANK
end

---@param ctx Context
function bank.proto:OnRefresh(ctx)
	events:SendMessage(ctx, "bags/RefreshBank")
end

---@return Money|nil
function bank.proto:SetupMoneyFrame()
	-- Era bank doesn't have a money frame
	return nil
end

function bank.proto:RegisterEvents()
	-- No bank-specific events in Era
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
