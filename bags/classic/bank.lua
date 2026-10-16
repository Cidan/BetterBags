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

---@class BagSlots: AceModule
local bagSlots = addon:GetModule("BagSlots")

-------
--- Classic Bank Behavior Overrides
--- Classic (MoP Remix, Cata) doesn't have BankPanel, tabs, or warbank.
--- The unified frames/bag.lua delegates bag-slots creation to the behavior's
--- OnCreate (the legacy frames/classic/bag.lua created it inline for both bags
--- and was removed in #1044), so this override must create the bank's panel —
--- otherwise bag.slots is never set and the context menu's "Show Bags" entry
--- (gated on bag.slots) disappears from the bank.
-------

---@param ctx Context
function bank.proto:OnShow(ctx)
	PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
	self.bag.window:Show(ctx)
	addon.TriggerItemContextChanged()
end

-- OnHide closes the bank window, then the bank itself. CloseBankFrame fires BANKFRAME_CLOSED,
-- which hides the bag again: the guard stops that while this hide runs, and the window's own
-- state (hidden, or fading out) stops it afterwards.
---@param ctx Context
function bank.proto:OnHide(ctx)
	if self.isHiding then
		return
	end
	self.isHiding = true

	addon.ForceHideBlizzardBags()
	PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)

	self.bag.window:Hide(ctx, function()
		CloseBankFrame()
		addon.TriggerItemContextChanged()
	end)
	self.isHiding = false
end

---@param ctx Context
function bank.proto:OnCreate(ctx)
	-- Classic bank doesn't have tabs or BankPanel settings
	self.bag.bankTab = const.BANK_TAB.BANK

	-- Bag slots panel (bank bags, including purchasable bank bag slots)
	local slots = bagSlots:CreatePanel(ctx, const.BAG_KIND.BANK, self.bag.frame)
	self.bag.slots = slots
end

---@param ctx Context
function bank.proto:OnRefresh(ctx)
	events:SendMessage(ctx, 'bags/Rederive', { backpack = false, bank = true })
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
