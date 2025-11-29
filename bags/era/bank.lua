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

---@param ctx Context
---@param bag Bag
function bank.proto:OnShow(ctx, bag)
	PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
	bag.frame:Show()
	ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
end

---@param ctx Context
---@param bag Bag
function bank.proto:OnHide(ctx, bag)
	addon.ForceHideBlizzardBags()
	PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
	bag.frame:Hide()
	CloseBankFrame()
	ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
end

---@param ctx Context
---@param bag Bag
function bank.proto:OnCreate(ctx, bag)
	-- Era bank doesn't have tabs or BankPanel settings
	bag.bankTab = const.BANK_TAB.BANK
end

---@param ctx Context
---@param bag Bag
function bank.proto:OnRefresh(ctx, bag)
	events:SendMessage(ctx, "bags/RefreshBank")
end

---@param bag Bag
---@param bottomBar Frame
---@return Money|nil
function bank.proto:SetupMoneyFrame(bag, bottomBar)
	-- Era bank doesn't have a money frame
	return nil
end

---@param bag Bag
function bank.proto:RegisterEvents(bag)
	-- No bank-specific events in Era
end

---@param ctx Context
---@param bag Bag
function bank.proto:SwitchToBankAndWipe(ctx, bag)
	ctx:Set("wipe", true)
	bag.bankTab = const.BANK_TAB.BANK
	BankFrame.selectedTab = 1
	bag:SetTitle(L:G("Bank"))
	items:ClearBankCache(ctx)
	bag:Wipe(ctx)
end
