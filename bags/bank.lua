---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)

---@class BankBehavior: AceModule
---@field proto BankBehaviorProto
local bank = addon:NewModule("BankBehavior")

---@class Localization: AceModule
local L = addon:GetModule("Localization")

---@class Constants: AceModule
local const = addon:GetModule("Constants")

---@class Events: AceModule
local events = addon:GetModule("Events")

---@class Items: AceModule
local items = addon:GetModule("Items")

---@class Database: AceModule
local database = addon:GetModule("Database")

---@class MoneyFrame: AceModule
local money = addon:GetModule("MoneyFrame")

---@class Tabs: AceModule
local tabs = addon:GetModule("Tabs")

---@class Groups: AceModule
local groups = addon:GetModule("Groups")

---@class Context: AceModule
local context = addon:GetModule("Context")

---@class ContextMenu: AceModule
local contextMenu = addon:GetModule("ContextMenu")

local NEW_GROUP_TAB_ID = 0
local NEW_GROUP_TAB_ICON = "communities-icon-addchannelplus"

-------
--- Bank Behavior Prototype
-------

-- Guard flag to prevent recursive CloseBankFrame() calls from the Hide hook.
-- Set to true when the hook calls CloseBankFrame(), cleared after event processing.
local isClosingBank = false

--- BankBehaviorProto defines the behavior specific to the player's bank.
---@class BankBehaviorProto
---@field bag Bag Reference to the parent bag
bank.proto = {}

---@param ctx Context
function bank.proto:OnShow(ctx)
	PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)

	-- Lazy resize tabs on first show to account for fonts loaded by other addons (e.g., GW2 UI)
	if not self.bag.tabsResizedAfterLoad then
		if self.bag.tabs then
			self.bag.tabs:ResizeAllTabs(ctx)
			self.bag.tabsResizedAfterLoad = true
		end
	end

	-- Generate tabs before showing frame
	self:GenerateGroupTabs(ctx)

	-- Use fade animation if enabled
	if database:GetEnableBagFading() then
		-- Set up callback to handle BankPanel and tab initialization
		self.bag.fadeInGroup.callback = function()
			self.bag.fadeInGroup.callback = nil  -- Clean up callback

			-- CRITICAL: BankPanel taint handling (see patterns.md)
			-- BankPanel must be shown (even invisibly) for GetActiveBankType to work.
			if BankPanel then
				BankPanel:SetAlpha(0)
				BankPanel:EnableMouse(false)
				BankPanel:EnableKeyboard(false)
				if BankPanel.MoneyFrame then
					BankPanel.MoneyFrame:Hide()
				end
				if BankPanel.AutoDepositFrame then
					BankPanel.AutoDepositFrame:Hide()
				end
				if BankPanel.Header then
					BankPanel.Header:Hide()
				end
				BankPanel:Show()
			end

			local activeGroup = database:GetActiveGroup(const.BAG_KIND.BANK)
			self.bag.tabs:SetTabByID(ctx, activeGroup)
			self:SwitchToGroup(ctx, activeGroup)

			self.bag.moneyFrame:Update()
			ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
		end
		self.bag.fadeInGroup:Play()
	else
		-- Direct show path (existing logic)
		-- CRITICAL: BankPanel taint handling (see patterns.md)
		-- BankPanel must be shown (even invisibly) for GetActiveBankType to work.
		if BankPanel then
			BankPanel:SetAlpha(0)
			BankPanel:EnableMouse(false)
			BankPanel:EnableKeyboard(false)
			if BankPanel.MoneyFrame then
				BankPanel.MoneyFrame:Hide()
			end
			if BankPanel.AutoDepositFrame then
				BankPanel.AutoDepositFrame:Hide()
			end
			if BankPanel.Header then
				BankPanel.Header:Hide()
			end
			BankPanel:Show()
		end

		local activeGroup = database:GetActiveGroup(const.BAG_KIND.BANK)
		self.bag.tabs:SetTabByID(ctx, activeGroup)
		self:SwitchToGroup(ctx, activeGroup)

		self.bag.moneyFrame:Update()
		self.bag.frame:Show()
		ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
	end
end

function bank.proto:OnHide()
	-- IMPORTANT: Do NOT touch BankPanel or call CloseBankFrame() here.
	-- OnHide runs in protected context when triggered by UISpecialFrames (ESC key).
	-- Any BankPanel manipulation here causes persistent taint that breaks UseContainerItem()
	-- for ALL containers (including backpack) after the bank is closed.
	-- See patterns.md for details.

	addon.ForceHideBlizzardBags()
	PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)

	-- Use fade animation if enabled
	if database:GetEnableBagFading() then
		self.bag.fadeOutGroup.callback = function()
			self.bag.fadeOutGroup.callback = nil  -- Clean up callback
			ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
		end
		self.bag.fadeOutGroup:Play()
	else
		self.bag.frame:Hide()
		ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
	end
end

---@param ctx Context
function bank.proto:OnCreate(_)
	-- Capture behavior reference for closures
	local behavior = self

	self.bag.tabs = tabs:Create(self.bag.frame, const.BAG_KIND.BANK)

	self.bag.tabs:SetClickHandler(function(ectx, tabID, button)
		if tabID == NEW_GROUP_TAB_ID then
			behavior:ShowCreateGroupDialog()
			return false
		end

		if tabID == -1 or tabID == -2 then
			return false -- Purchase tabs handled by secure templates
		end

		-- Right-click on non-default groups shows context menu
		if button == "RightButton" and tabID and tabID > 0 then
			if not groups:IsDefaultGroup(const.BAG_KIND.BANK, tabID) then
				behavior:ShowGroupContextMenu(ectx, tabID)
			end
			return false
		end

		behavior:SwitchToGroup(ectx, tabID)
		return true
	end)
end

function bank.proto:OnRefresh()
	-- Retail bank is event-driven, refresh handled via BANKFRAME events
end

---@return FrameStrata
function bank.proto:GetFrameStrata()
	return "HIGH"
end

---@return number|nil
function bank.proto:GetFrameLevel()
	return nil -- Use default
end

---@param bottomBar Frame
---@return Money
function bank.proto:SetupMoneyFrame(bottomBar)
	local moneyFrame = money:Create(true) -- Warbank-enabled
	moneyFrame.frame:SetPoint("BOTTOMRIGHT", bottomBar, "BOTTOMRIGHT", -4, 0)
	moneyFrame.frame:SetParent(self.bag.frame)
	return moneyFrame
end

function bank.proto:RegisterEvents()
	-- Capture behavior reference for closures
	local behavior = self

	events:RegisterEvent("PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", function(ectx)
		behavior:GenerateGroupTabs(ectx)
	end)

	events:RegisterEvent("BANK_TAB_SETTINGS_UPDATED", function(ctx, _)
		behavior:GenerateGroupTabs(ctx)
	end)

	events:RegisterMessage("groups/Created", function(ctx, group)
		if group.kind == const.BAG_KIND.BANK then
			behavior:GenerateGroupTabs(ctx)
		end
	end)

	events:RegisterMessage("groups/Changed", function(ctx, _, _, _, kind)
		if kind == const.BAG_KIND.BANK then
			behavior:GenerateGroupTabs(ctx)
		end
	end)

	events:RegisterMessage("groups/Deleted", function(ctx, groupID, _, kind)
		if kind ~= const.BAG_KIND.BANK then return end
		local activeGroup = database:GetActiveGroup(const.BAG_KIND.BANK)
		if activeGroup == groupID then
			local defaultBankGroup = groups:GetDefaultBankGroup()
			if defaultBankGroup then
				behavior:SwitchToGroup(ctx, defaultBankGroup.id)
			end
		end
		behavior:GenerateGroupTabs(ctx)
	end)
end

---@return boolean
function bank.proto:ShouldHandleSort()
	return false
end

-------
--- Bank Tab Methods
-------

---@param ctx Context
function bank.proto:GenerateGroupTabs(ctx)
	if not database:GetGroupsEnabled(const.BAG_KIND.BANK) then
		self.bag.tabs.frame:Hide()
		return
	end

	self.bag.tabs.frame:Show()

	local allGroups = groups:GetAllGroups(const.BAG_KIND.BANK)

	for groupID, group in pairs(allGroups) do
		if not self.bag.tabs:TabExistsByID(groupID) then
			self.bag.tabs:AddTab(ctx, group.name, groupID)
		else
			if self.bag.tabs:GetTabNameByID(groupID) ~= group.name then
				self.bag.tabs:RenameTabByID(ctx, groupID, group.name)
			end
			self.bag.tabs:ShowTabByID(groupID)
		end
	end

	for _, tab in pairs(self.bag.tabs.tabIndex) do
		if tab.id and tab.id > 0 and not allGroups[tab.id] then
			self.bag.tabs:HideTabByID(tab.id)
		end
	end

	if not self.bag.tabs:TabExistsByID(NEW_GROUP_TAB_ID) then
		self.bag.tabs:AddTab(ctx, L:G("New Group"), NEW_GROUP_TAB_ID)
		self.bag.tabs:SetTabIconByID(ctx, NEW_GROUP_TAB_ID, NEW_GROUP_TAB_ICON)
		self:SetupPlusTabTooltip(ctx)
	end

	if C_Bank and C_Bank.CanPurchaseBankTab and C_Bank.HasMaxBankTabs then
		if C_Bank.CanPurchaseBankTab(Enum.BankType.Character) and not C_Bank.HasMaxBankTabs(Enum.BankType.Character) then
			if not self.bag.tabs:TabExistsByID(-1) then
				self.bag.tabs:AddTab(ctx, L:G("Purchase Bank Tab"), -1, nil, nil, self.bag.frame, "BankPanelPurchaseButtonScriptTemplate")
				local purchaseTab = self.bag.tabs:GetTabByName(L:G("Purchase Bank Tab"))
				if purchaseTab then purchaseTab:SetAttribute("overrideBankType", Enum.BankType.Character) end
			else
				self.bag.tabs:ShowTabByID(-1)
			end
		elseif self.bag.tabs:TabExistsByID(-1) then
			self.bag.tabs:HideTabByID(-1)
		end

		-- Disable rendering the purchase warbank tab button for now
		local ENABLE_WARBANK_PURCHASE_TAB = false
		if ENABLE_WARBANK_PURCHASE_TAB and addon.isRetail and C_Bank.CanPurchaseBankTab(Enum.BankType.Account) and not C_Bank.HasMaxBankTabs(Enum.BankType.Account) then
			if not self.bag.tabs:TabExistsByID(-2) then
				self.bag.tabs:AddTab(ctx, L:G("Purchase Warbank Tab"), -2, nil, nil, self.bag.frame, "BankPanelPurchaseButtonScriptTemplate")
				local purchaseTab = self.bag.tabs:GetTabByName(L:G("Purchase Warbank Tab"))
				if purchaseTab then purchaseTab:SetAttribute("overrideBankType", Enum.BankType.Account) end
			else
				self.bag.tabs:ShowTabByID(-2)
			end
		elseif self.bag.tabs:TabExistsByID(-2) then
			self.bag.tabs:HideTabByID(-2)
		end
	end

	self.bag.tabs:SortTabsByID()
	self.bag.tabs:MoveToEnd(L:G("New Group"))

	local w = self.bag.tabs.width
	if self.bag.frame:GetWidth() + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET < w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET then
		self.bag.frame:SetWidth(w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET)
	end
end

function bank.proto:SetupPlusTabTooltip(_)
	local plusTab = self.bag.tabs:GetTabByName(L:G("New Group"))
	if plusTab then
		plusTab:SetScript("OnEnter", function(button)
			GameTooltip:SetOwner(button, "ANCHOR_TOP")
			GameTooltip:SetText(L:G("Create New Group Tab"), 1, 1, 1, 1, true)
			GameTooltip:AddLine(L:G("Click to create a new group tab for organizing your items."), 1, 1, 1)
			GameTooltip:Show()
		end)
		plusTab:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end
end

function bank.proto:ShowCreateGroupDialog()
	local groupDialog = addon:GetModule('GroupDialog')
	groupDialog:Show(
		L:G("Create New Bank Tab"),
		L:G("1. Enter group name:"),
		addon.isRetail,
		Enum.BankType and Enum.BankType.Character or 1,
		function(name, bankType)
			local ctx = context:New("CreateGroup")
			local newGroup = groups:CreateGroup(ctx, const.BAG_KIND.BANK, name, bankType)
			local bag = addon.Bags.Bank
			if bag and bag.behavior then
				bag.behavior:SwitchToGroup(ctx, newGroup.id)
			end
		end
	)
end

-- ShowGroupContextMenu shows a context menu for a bank group tab.
---@param ctx Context
---@param groupID number
function bank.proto:ShowGroupContextMenu(ctx, groupID)
	local group = groups:GetGroup(const.BAG_KIND.BANK, groupID)
	if not group then return end

	local behavior = self
	---@type MenuList[]
	local menuList = {}

	-- Title
	table.insert(menuList, {
		text = group.name,
		isTitle = true,
		notCheckable = true,
	})

	-- Rename option
	table.insert(menuList, {
		text = L:G("Rename Group"),
		notCheckable = true,
		func = function()
			contextMenu:Hide(ctx)
			behavior:ShowRenameGroupDialog(groupID)
		end,
	})

	-- Delete option
	table.insert(menuList, {
		text = L:G("Delete Group"),
		notCheckable = true,
		func = function()
			contextMenu:Hide(ctx)
			behavior:ShowDeleteGroupConfirm(groupID)
		end,
	})

	-- Close menu option
	table.insert(menuList, {
		text = L:G("Close Menu"),
		notCheckable = true,
		func = function()
			contextMenu:Hide(ctx)
		end,
	})

	contextMenu:Show(ctx, menuList)
end

-- ShowRenameGroupDialog shows a dialog to rename a bank group.
---@param groupID number
function bank.proto:ShowRenameGroupDialog(groupID)
	local group = groups:GetGroup(const.BAG_KIND.BANK, groupID)
	if not group then return end

	local groupDialog = addon:GetModule('GroupDialog')
	groupDialog:Show(
		L:G("Rename Group"),
		L:G("Enter new group name:"),
		false,
		nil,
		function(name)
			local ctx = context:New("RenameGroup")
			groups:RenameGroup(ctx, const.BAG_KIND.BANK, groupID, name)
		end,
		group.name,
		L:G("Rename")
	)
end

-- ShowDeleteGroupConfirm shows a confirmation dialog to delete a bank group.
---@param groupID number
function bank.proto:ShowDeleteGroupConfirm(groupID)
	local group = groups:GetGroup(const.BAG_KIND.BANK, groupID)
	if not group then return end

	local question = addon:GetModule('Question')
	question:YesNo(
		L:G("Delete Group"),
		string.format(L:G("Are you sure you want to delete the group '%s'? Categories in this group will be moved back to Bank."), group.name),
		function()
			local ctx = context:New("DeleteGroup")
			groups:DeleteGroup(ctx, const.BAG_KIND.BANK, groupID)
		end,
		function() end
	)
end

function bank.proto:SwitchToGroup(ctx, groupID)
	local group = groups:GetGroup(const.BAG_KIND.BANK, groupID)
	if not group then return end

	database:SetActiveGroup(const.BAG_KIND.BANK, groupID)
	self.bag.tabs:SetTabByID(ctx, groupID)

	-- Update bankType
	if addon.isRetail and group.bankType == Enum.BankType.Account then
		if BankPanel and BankPanel.SetBankType then
			BankPanel:SetBankType(Enum.BankType.Account)
		end
		self.bag.bankTab = Enum.BagIndex.AccountBankTab_1 -- Set a default so right-click deposits know it's a Warbank tab
	else
		if BankPanel and BankPanel.SetBankType then
			BankPanel:SetBankType(Enum.BankType.Character)
		end
		self.bag.bankTab = Enum.BagIndex.Characterbanktab or Enum.BagIndex.Bank or -1
	end

	self.bag:SetTitle(group.name)
	self.bag.currentItemCount = -1

	items:ClearBankCache(ctx)
	self.bag:Wipe(ctx)
	ctx:Set("wipe", true)

	events:SendMessage(ctx, "bags/RefreshBank")
	ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
end

function bank.proto:SwitchToBankAndWipe(ctx)
	-- Fallback used in event hooks when closing bank
	ctx:Set("wipe", true)
	self.bag.bankTab = Enum.BagIndex.Characterbanktab or Enum.BagIndex.Bank or -1
	if BankPanel and BankPanel.SetBankType then
		BankPanel:SetBankType(Enum.BankType.Character)
	end
	if self.bag.tabs then
		local activeGroup = database:GetActiveGroup(const.BAG_KIND.BANK)
		self.bag.tabs:SetTabByID(ctx, activeGroup)
	end
	self.bag:SetTitle(L:G("Bank"))
	items:ClearBankCache(ctx)
	self.bag:Wipe(ctx)
end

-------
--- BankBehavior Module Functions
-------

---@param bag Bag
---@return BankBehaviorProto
function bank:Create(bag)
	local b = {}
	setmetatable(b, { __index = bank.proto })
	b.bag = bag

	-- Hook the bag's Hide method to automatically exit banking mode.
	-- This fixes the X button issue for ALL themes (including external themes)
	-- by ensuring CloseBankFrame() is called whenever the bank is hidden.
	-- NOTE: Only needed for Retail - Classic/Era handle bank closing differently.
	hooksecurefunc(bag, "Hide", function()
		-- Skip CloseBankFrame() call in Classic/Era to avoid recursion.
		-- Classic/Era versions handle bank closing through their OnHide methods
		-- and BANKFRAME_CLOSED event handlers without needing this hook.
		if not addon.isRetail then
			return
		end

		-- Guard against recursion: if we're already closing the bank, don't call CloseBankFrame() again.
		-- This prevents infinite recursion when BANKFRAME_CLOSED event handler calls Hide():
		--   Hide() → hook calls CloseBankFrame() → BANKFRAME_CLOSED → addon.CloseBank() → Hide() → loop
		if isClosingBank then
			return
		end

		-- Set guard flag before calling CloseBankFrame()
		isClosingBank = true

		-- After bag hides, call CloseBankFrame() to exit banking mode (Retail only).
		-- This handles the X button close path (ESC key path already calls CloseBankFrame()).
		if C_Bank then
			C_Bank.CloseBankFrame()
		elseif CloseBankFrame then
			CloseBankFrame()
		end

		-- Clear the guard flag after event processing completes.
		-- Using C_Timer.After(0, ...) ensures the flag is cleared after the current
		-- event chain finishes, allowing future bank closes to work properly.
		C_Timer.After(0, function()
			isClosingBank = false
		end)
	end)

	return b
end
