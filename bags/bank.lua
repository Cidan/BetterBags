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

-------
--- Bank Behavior Prototype
-------

--- BankBehaviorProto defines the behavior specific to the player's bank.
---@class BankBehaviorProto
---@field bag Bag Reference to the parent bag
bank.proto = {}

---@param ctx Context
---@param bag Bag
function bank.proto:OnShow(ctx, bag)
	PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)

	-- CRITICAL: BankPanel taint handling (see patterns.md)
	-- Configure and show BankPanel so GetActiveBankType works
	if BankPanel then
		-- Make BankPanel invisible but functional
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

	self:GenerateCharacterBankTabs(ctx, bag)
	self:GenerateWarbankTabs(ctx, bag)

	if addon.atWarbank then
		self:HideBankAndReagentTabs(bag)
		bag.tabs:SetTabByID(ctx, 13)
		-- Set the active bank type for warbank
		if BankPanel and BankPanel.SetBankType then
			BankPanel:SetBankType(Enum.BankType.Account)
		end
	else
		self:ShowBankAndReagentTabs(bag)
		-- Set first tab when using multiple character bank tabs
		if database:GetCharacterBankTabsEnabled() then
			local firstTabID = const.BANK_ONLY_BAGS_LIST[1]
			bag.bankTab = firstTabID -- Important: set bankTab before SetTabByID
			bag.tabs:SetTabByID(ctx, firstTabID)
			ctx:Set("filterBagID", firstTabID) -- Set the filter for the initial tab
		else
			bag.bankTab = Enum.BagIndex.Bank
			bag.tabs:SetTabByID(ctx, 1)
		end
		-- Set the active bank type for character bank
		if BankPanel and BankPanel.SetBankType then
			BankPanel:SetBankType(Enum.BankType.Character)
		end
	end

	bag.moneyFrame:Update()
	bag.frame:Show()
	ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
end

---@param ctx Context
---@param bag Bag
function bank.proto:OnHide(ctx, bag)
	addon.ForceHideBlizzardBags()
	PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
	bag.frame:Hide()

	-- Hide BankPanel to prevent taint from affecting other container operations
	if BankPanel then
		BankPanel:Hide()
	end

	if C_Bank then
		C_Bank.CloseBankFrame()
	else
		CloseBankFrame()
	end

	ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
end

---@param ctx Context
---@param bag Bag
function bank.proto:OnCreate(ctx, bag)
	-- Capture behavior reference for closures
	local behavior = self

	-- Move the settings menu to the bag frame.
	BankPanel.TabSettingsMenu:SetParent(bag.frame)
	BankPanel.TabSettingsMenu:ClearAllPoints()
	BankPanel.TabSettingsMenu:SetPoint("BOTTOMLEFT", bag.frame, "BOTTOMRIGHT", 10, 0)

	-- Adjust the settings function so the tab settings menu is populated correctly.
	BankPanel.TabSettingsMenu.GetBankFrame = function()
		return {
			GetTabData = function(_, id)
				-- Check if this is a character bank tab request
				if BankPanel.bankType == Enum.BankType.Character then
					-- For character bank tabs, we need to get the bag information
					local bagID = const.BANK_ONLY_BAGS_LIST[id]
					if bagID then
						local invid = C_Container.ContainerIDToInventoryID(bagID)
						local baglink = GetInventoryItemLink("player", invid)
						local icon = nil
						local tabName = format("Bank Tab %d", id)

						if baglink then
							icon = C_Item.GetItemIconByID(baglink)
							local itemName = C_Item.GetItemNameByID(baglink)
							if itemName and itemName ~= "" then
								tabName = itemName
							end
						end

						-- Try to get character bank tab data from API if available
						local characterTabData = C_Bank
							and C_Bank.FetchPurchasedBankTabData
							and C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)
						local depositFlags = nil

						if characterTabData then
							for _, data in pairs(characterTabData) do
								if data.ID == id then
									tabName = data.name or tabName
									icon = data.icon or icon
									depositFlags = data.depositFlags
									break
								end
							end
						end

						return {
							ID = id,
							icon = icon or 133633, -- Default bag icon
							name = tabName,
							depositFlags = depositFlags,
							bankType = Enum.BankType.Character,
						}
					end
				else
					-- Original warbank tab data handling
					local bankTabData = behavior:GetWarbankTabDataByID(id)
					return {
						ID = id,
						icon = bankTabData.icon,
						name = bag.tabs:GetTabNameByID(id),
						depositFlags = bankTabData.depositFlags,
						bankType = Enum.BankType.Account,
					}
				end
			end,
		}
	end

	bag.tabs = tabs:Create(bag.frame)

	-- Always create Bank tab
	if not bag.tabs:TabExistsByID(1) then
		bag.tabs:AddTab(ctx, "Bank", 1)
	end

	-- Set initial tab if not using character bank tabs
	if not database:GetCharacterBankTabsEnabled() then
		bag.tabs:SetTabByID(ctx, 1)
	end

	bag.tabs:SetClickHandler(function(ectx, tabID, button)
		-- Check if this is a character bank tab
		if tabID and tabID >= Enum.BagIndex.CharacterBankTab_1 and tabID <= Enum.BagIndex.CharacterBankTab_6 then
			if button == "RightButton" then
				-- Show settings menu for character bank tabs
				if BankPanel.SetBankType then
					BankPanel:SetBankType(Enum.BankType.Character)
				end
				local bagIndex = tabID
				-- Try to get character bank tab data if available
				local characterTabData = C_Bank
					and C_Bank.FetchPurchasedBankTabData
					and C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)
				if characterTabData then
					BankPanel:FetchPurchasedBankTabData()
				end
				BankPanel.TabSettingsMenu:Show()
				BankPanel.TabSettingsMenu:SetSelectedTab(bagIndex)
				BankPanel.TabSettingsMenu:Update()
			else
				BankPanel.TabSettingsMenu:Hide()
				if BankPanel.SetBankType then
					BankPanel:SetBankType(Enum.BankType.Character)
				end
			end
			behavior:SwitchToCharacterBankTab(ectx, tabID, bag)
			return true -- Tab switch handled, allow selection
		elseif tabID == 1 then
			-- Bank tab
			BankPanel.TabSettingsMenu:Hide()
			if BankPanel.SetBankType then
				BankPanel:SetBankType(Enum.BankType.Character)
			end
			behavior:SwitchToBank(ectx, bag)
			return true -- Tab switch handled, allow selection
		else
			-- Warbank tabs
			if button == "RightButton" or BankPanel.TabSettingsMenu:IsShown() then
				if BankPanel.SetBankType then
					BankPanel:SetBankType(Enum.BankType.Account)
				end
				BankPanel:FetchPurchasedBankTabData()
				BankPanel.TabSettingsMenu:Show()
				BankPanel.TabSettingsMenu:SetSelectedTab(tabID)
				BankPanel.TabSettingsMenu:Update()
			end
			behavior:SwitchToAccountBank(ectx, tabID, bag)
			return true -- Tab switch handled, allow selection
		end
	end)
end

---@param ctx Context
---@param bag Bag
function bank.proto:OnRefresh(ctx, bag)
	-- Retail bank is event-driven, non-retail sends refresh message
	if not addon.isRetail then
		events:SendMessage(ctx, "bags/RefreshBank")
	end
end

---@return FrameStrata
function bank.proto:GetFrameStrata()
	return "HIGH"
end

---@return number|nil
function bank.proto:GetFrameLevel()
	return nil -- Use default
end

---@param bag Bag
---@param bottomBar Frame
---@return Money
function bank.proto:SetupMoneyFrame(bag, bottomBar)
	local moneyFrame = money:Create(true) -- Warbank-enabled
	moneyFrame.frame:SetPoint("BOTTOMRIGHT", bottomBar, "BOTTOMRIGHT", -4, 0)
	moneyFrame.frame:SetParent(bag.frame)
	return moneyFrame
end

---@param bag Bag
function bank.proto:RegisterEvents(bag)
	-- Capture behavior reference for closures
	local behavior = self

	events:RegisterEvent("PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", function(ectx)
		behavior:GenerateWarbankTabs(ectx, bag)
	end)
	events:RegisterEvent("BANK_TAB_SETTINGS_UPDATED", function(ectx)
		-- Update both warbank and character bank tabs when settings change
		behavior:GenerateWarbankTabs(ectx, bag)
		if database:GetCharacterBankTabsEnabled() then
			behavior:GenerateCharacterBankTabs(ectx, bag)
		end
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
---@param bag Bag
function bank.proto:GenerateCharacterBankTabs(ctx, bag)
	-- Only generate individual tabs if enabled
	if not database:GetCharacterBankTabsEnabled() then
		-- Hide all character bank tabs
		local bankBags = const.BANK_ONLY_BAGS_LIST
		for _, bagID in ipairs(bankBags) do
			if bag.tabs:TabExistsByID(bagID) then
				bag.tabs:HideTabByID(bagID)
			end
		end

		-- Show single bank tab
		if not bag.tabs:TabExistsByID(1) then
			bag.tabs:AddTab(ctx, "Bank", 1)
		else
			bag.tabs:ShowTabByID(1)
		end

		-- Sort tabs to ensure Bank tab is first
		bag.tabs:SortTabsByID()
		return
	end

	-- Hide the single bank tab when multiple tabs are enabled
	if bag.tabs:TabExistsByID(1) then
		bag.tabs:HideTabByID(1)
	end

	-- Try to get character bank tab data from the API
	local characterTabData = C_Bank
		and C_Bank.FetchPurchasedBankTabData
		and C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)

	for _, data in pairs(characterTabData) do
		if not bag.tabs:TabExistsByID(data.ID) then
			bag.tabs:AddTab(ctx, data.name, data.ID)
		else
			-- Update the name if it changed
			if bag.tabs:GetTabNameByID(data.ID) ~= data.name then
				bag.tabs:RenameTabByID(ctx, data.ID, data.name)
			end
			bag.tabs:ShowTabByID(data.ID)
		end
	end

	-- Sort tabs by ID to ensure proper order
	bag.tabs:SortTabsByID()

	-- Adjust frame width if needed
	local w = bag.tabs.width
	if
		bag.frame:GetWidth() + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET
		< w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET
	then
		bag.frame:SetWidth(w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET)
	end
end

---@param ctx Context
---@param bag Bag
function bank.proto:GenerateWarbankTabs(ctx, bag)
	local tabData = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account)
	for _, data in pairs(tabData) do
		if bag.tabs:TabExistsByID(data.ID) and bag.tabs:GetTabNameByID(data.ID) ~= data.name then
			bag.tabs:RenameTabByID(ctx, data.ID, data.name)
		elseif not bag.tabs:TabExistsByID(data.ID) then
			bag.tabs:AddTab(ctx, data.name, data.ID)
		end
	end

	local w = bag.tabs.width
	if
		bag.frame:GetWidth() + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET
		< w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET
	then
		bag.frame:SetWidth(w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET)
	end
end

---@param id number
---@return BankTabData
function bank.proto:GetWarbankTabDataByID(id)
	local tabData = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account)
	for _, data in pairs(tabData) do
		if data.ID == id then
			return data
		end
	end
	return {}
end

---@param bag Bag
function bank.proto:HideBankAndReagentTabs(bag)
	if database:GetCharacterBankTabsEnabled() then
		-- Hide all character bank tabs
		local bankBags = const.BANK_ONLY_BAGS_LIST
		for _, bagID in ipairs(bankBags) do
			local tabID = bagID
			if bag.tabs:TabExistsByID(tabID) then
				bag.tabs:HideTabByID(tabID)
			end
		end
	else
		bag.tabs:HideTabByID(1) -- Hide Bank tab
	end
end

---@param bag Bag
function bank.proto:ShowBankAndReagentTabs(bag)
	if database:GetCharacterBankTabsEnabled() then
		-- Show all character bank tabs
		local bankBags = const.BANK_ONLY_BAGS_LIST
		for _, bagID in ipairs(bankBags) do
			local tabID = bagID
			if bag.tabs:TabExistsByID(tabID) then
				bag.tabs:ShowTabByID(tabID)
			end
		end
	else
		bag.tabs:ShowTabByID(1)
	end
end

---@param ctx Context
---@param bag Bag
function bank.proto:SwitchToBank(ctx, bag)
	bag.bankTab = Enum.BagIndex.Bank
	BankFrame.selectedTab = 1
	bag:SetTitle(L:G("Bank"))
	bag.currentItemCount = -1
	BankFrame.activeTabIndex = 1
	BankPanel.selectedTabID = nil
	-- Set the active bank type so right-click item movement works correctly
	if BankPanel and BankPanel.SetBankType then
		BankPanel:SetBankType(Enum.BankType.Character)
	end
	-- Clear bank cache to ensure clean state
	items:ClearBankCache(ctx)
	bag:Wipe(ctx)
	ctx:Set("wipe", true)
	ctx:Set("filterBagID", nil) -- Clear filter for single bank tab
	-- Update visual tab selection
	bag.tabs:SetTabByID(ctx, 1)
	-- Trigger a full refresh and redraw
	events:SendMessage(ctx, "bags/RefreshBank")
	ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
end

---@param ctx Context
---@param tabID number
---@param bag Bag
function bank.proto:SwitchToCharacterBankTab(ctx, tabID, bag)
	bag.bankTab = tabID
	BankFrame.selectedTab = 1
	BankFrame.activeTabIndex = 1
	BankPanel.selectedTabID = nil
	-- Set the active bank type so right-click item movement works correctly
	if BankPanel and BankPanel.SetBankType then
		BankPanel:SetBankType(Enum.BankType.Character)
	end
	bag:SetTitle(format(L:G("Bank Tab %d"), tabID - const.BANK_ONLY_BAGS_LIST[1] + 1))
	bag.currentItemCount = -1
	-- Clear bank cache to ensure no items from other tabs remain
	items:ClearBankCache(ctx)
	bag:Wipe(ctx)
	ctx:Set("wipe", true)
	ctx:Set("filterBagID", tabID)
	-- Update visual tab selection
	bag.tabs:SetTabByID(ctx, tabID)
	-- Trigger a full refresh and redraw
	events:SendMessage(ctx, "bags/RefreshBank")
	ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
end

---@param ctx Context
---@param tabIndex number
---@param bag Bag
---@return boolean
function bank.proto:SwitchToAccountBank(ctx, tabIndex, bag)
	bag.bankTab = tabIndex
	BankFrame.selectedTab = 1
	BankFrame.activeTabIndex = 3
	-- Set the active bank type so right-click item movement works correctly
	if BankPanel and BankPanel.SetBankType then
		BankPanel:SetBankType(Enum.BankType.Account)
	end
	local tabData = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account)
	for _, data in pairs(tabData) do
		if data.ID == tabIndex then
			if BankPanel.SelectTab then
				BankPanel:SelectTab(data.ID)
			else
				BankPanel.selectedTabID = data.ID
			end
			break
		end
	end
	BankPanel:TriggerEvent(BankPanelMixin.Event.BankTabClicked, tabIndex)
	bag:SetTitle(ACCOUNT_BANK_PANEL_TITLE)
	bag.currentItemCount = -1
	bag:Wipe(ctx)
	ctx:Set("wipe", true)
	ctx:Set("filterBagID", nil) -- Clear filter for account bank
	-- Update visual tab selection
	bag.tabs:SetTabByID(ctx, tabIndex)
	items:RefreshBank(ctx)
	ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
	return true
end

---@param ctx Context
---@param bag Bag
function bank.proto:SwitchToBankAndWipe(ctx, bag)
	ctx:Set("wipe", true)
	bag.tabs:SetTabByID(ctx, 1)
	bag.bankTab = Enum.BagIndex.Bank
	BankFrame.selectedTab = 1
	BankFrame.activeTabIndex = 1
	-- Set the active bank type so right-click item movement works correctly
	if BankPanel and BankPanel.SetBankType then
		BankPanel:SetBankType(Enum.BankType.Character)
	end
	bag:SetTitle(L:G("Bank"))
	items:ClearBankCache(ctx)
	bag:Wipe(ctx)
end

-------
--- BankBehavior Module Functions
-------

---@return BankBehaviorProto
function bank:Create()
	local b = {}
	setmetatable(b, { __index = bank.proto })
	return b
end
