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
	self:GenerateCharacterBankTabs(ctx)
	self:GenerateWarbankTabs(ctx)

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

			-- Set initial tab after frame is shown
			if addon.atWarbank then
				self:HideBankAndReagentTabs()
				self.bag.tabs:SetTabByID(ctx, 13)
				if BankPanel and BankPanel.SetBankType then
					BankPanel:SetBankType(Enum.BankType.Account)
				end
			else
				self:ShowBankAndReagentTabs()
				if database:GetCharacterBankTabsEnabled() then
					local firstTabID = const.BANK_ONLY_BAGS_LIST[1]
					self.bag.bankTab = firstTabID
					self.bag.tabs:SetTabByID(ctx, firstTabID)
					ctx:Set("filterBagID", firstTabID)
				else
					self.bag.bankTab = Enum.BagIndex.Characterbanktab
					self.bag.tabs:SetTabByID(ctx, 1)
				end
				if BankPanel and BankPanel.SetBankType then
					BankPanel:SetBankType(Enum.BankType.Character)
				end
			end

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

		if addon.atWarbank then
			self:HideBankAndReagentTabs()
			self.bag.tabs:SetTabByID(ctx, 13)
			if BankPanel and BankPanel.SetBankType then
				BankPanel:SetBankType(Enum.BankType.Account)
			end
		else
			self:ShowBankAndReagentTabs()
			if database:GetCharacterBankTabsEnabled() then
				local firstTabID = const.BANK_ONLY_BAGS_LIST[1]
				self.bag.bankTab = firstTabID
				self.bag.tabs:SetTabByID(ctx, firstTabID)
				ctx:Set("filterBagID", firstTabID)
			else
				self.bag.bankTab = Enum.BagIndex.Characterbanktab
				self.bag.tabs:SetTabByID(ctx, 1)
			end
			if BankPanel and BankPanel.SetBankType then
				BankPanel:SetBankType(Enum.BankType.Character)
			end
		end

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
function bank.proto:OnCreate(ctx)
	-- Capture behavior reference for closures
	local behavior = self

	-- Move the settings menu to the bag frame (with validation)
	if BankPanel and BankPanel.TabSettingsMenu then
		BankPanel.TabSettingsMenu:SetParent(self.bag.frame)
		BankPanel.TabSettingsMenu:ClearAllPoints()
		BankPanel.TabSettingsMenu:SetPoint("BOTTOMLEFT", self.bag.frame, "BOTTOMRIGHT", 10, 0)

		-- Adjust the settings function so the tab settings menu is populated correctly.
		BankPanel.TabSettingsMenu.GetBankFrame = function()
		return {
			GetTabData = function(_, id)
				-- Check if this is a character bank tab request using addon state
				-- instead of reading BankPanel.bankType field (avoids taint)
				if not addon.atWarbank then
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
						name = behavior.bag.tabs:GetTabNameByID(id),
						depositFlags = bankTabData.depositFlags,
						bankType = Enum.BankType.Account,
					}
				end
			end,
		}
	end
	end -- Close BankPanel validation check

	self.bag.tabs = tabs:Create(self.bag.frame)

	-- Always create Bank tab
	if not self.bag.tabs:TabExistsByID(1) then
		self.bag.tabs:AddTab(ctx, "Bank", 1)
	end

	-- Set initial tab if not using character bank tabs
	if not database:GetCharacterBankTabsEnabled() then
		self.bag.tabs:SetTabByID(ctx, 1)
	end

	self.bag.tabs:SetClickHandler(function(ectx, tabID, button)
		-- Check if this is a character bank tab
		if tabID and tabID >= Enum.BagIndex.CharacterBankTab_1 and tabID <= Enum.BagIndex.CharacterBankTab_6 then
			if button == "RightButton" then
				-- Show settings menu for character bank tabs
				if BankPanel and BankPanel.SetBankType then
					BankPanel:SetBankType(Enum.BankType.Character)
				end
				local bagIndex = tabID
				-- Try to get character bank tab data if available
				local characterTabData = C_Bank
					and C_Bank.FetchPurchasedBankTabData
					and C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)
				if characterTabData and BankPanel and BankPanel.FetchPurchasedBankTabData then
					BankPanel:FetchPurchasedBankTabData()
				end
				if BankPanel and BankPanel.TabSettingsMenu then
					BankPanel.TabSettingsMenu:Show()
					BankPanel.TabSettingsMenu:SetSelectedTab(bagIndex)
					BankPanel.TabSettingsMenu:Update()
				end
			else
				if BankPanel and BankPanel.TabSettingsMenu then
					BankPanel.TabSettingsMenu:Hide()
				end
				if BankPanel and BankPanel.SetBankType then
					BankPanel:SetBankType(Enum.BankType.Character)
				end
			end
			behavior:SwitchToCharacterBankTab(ectx, tabID)
			return true -- Tab switch handled, allow selection
		elseif tabID == 1 then
			-- Bank tab
			if BankPanel and BankPanel.TabSettingsMenu then
				BankPanel.TabSettingsMenu:Hide()
			end
			if BankPanel and BankPanel.SetBankType then
				BankPanel:SetBankType(Enum.BankType.Character)
			end
			behavior:SwitchToBank(ectx)
			return true -- Tab switch handled, allow selection
		else
			-- Warbank tabs
			local showSettings = button == "RightButton"
			if BankPanel and BankPanel.TabSettingsMenu then
				showSettings = showSettings or BankPanel.TabSettingsMenu:IsShown()
			end
			if showSettings then
				if BankPanel and BankPanel.SetBankType then
					BankPanel:SetBankType(Enum.BankType.Account)
				end
				if BankPanel and BankPanel.FetchPurchasedBankTabData then
					BankPanel:FetchPurchasedBankTabData()
				end
				if BankPanel and BankPanel.TabSettingsMenu then
					BankPanel.TabSettingsMenu:Show()
					BankPanel.TabSettingsMenu:SetSelectedTab(tabID)
					BankPanel.TabSettingsMenu:Update()
				end
			end
			behavior:SwitchToAccountBank(ectx, tabID)
			return true -- Tab switch handled, allow selection
		end
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
		-- Track tab count before regeneration to detect new purchases
		local oldTabData = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account) or {}
		local oldCount = #oldTabData

		behavior:GenerateWarbankTabs(ectx)

		-- If new tab was added, auto-select it
		local newTabData = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account) or {}
		if #newTabData > oldCount and #newTabData > 0 then
			local newestTab = newTabData[#newTabData]
			behavior:SwitchToAccountBank(ectx, newestTab.ID)
		end
	end)

	events:RegisterEvent("BANK_TAB_SETTINGS_UPDATED", function(ectx, bankType)
		-- Update tabs based on which bank type changed
		if bankType == Enum.BankType.Account then
			local oldTabData = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account) or {}
			local oldCount = #oldTabData

			behavior:GenerateWarbankTabs(ectx)

			local newTabData = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account) or {}
			if #newTabData > oldCount and #newTabData > 0 then
				local newestTab = newTabData[#newTabData]
				behavior:SwitchToAccountBank(ectx, newestTab.ID)
			end
		elseif bankType == Enum.BankType.Character and database:GetCharacterBankTabsEnabled() then
			local oldTabData = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character) or {}
			local oldCount = #oldTabData

			behavior:GenerateCharacterBankTabs(ectx)

			local newTabData = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character) or {}
			if #newTabData > oldCount and #newTabData > 0 then
				local newestTab = newTabData[#newTabData]
				behavior:SwitchToCharacterBankTab(ectx, newestTab.ID)
			end
		else
			-- Fallback for other bank types or when character tabs are disabled
			behavior:GenerateWarbankTabs(ectx)
			if database:GetCharacterBankTabsEnabled() then
				behavior:GenerateCharacterBankTabs(ectx)
			end
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
function bank.proto:GenerateCharacterBankTabs(ctx)
	-- Only generate individual tabs if enabled
	if not database:GetCharacterBankTabsEnabled() then
		-- Hide all character bank tabs
		local bankBags = const.BANK_ONLY_BAGS_LIST
		for _, bagID in ipairs(bankBags) do
			if self.bag.tabs:TabExistsByID(bagID) then
				self.bag.tabs:HideTabByID(bagID)
			end
		end

		-- Show single bank tab
		if not self.bag.tabs:TabExistsByID(1) then
			self.bag.tabs:AddTab(ctx, "Bank", 1)
		else
			self.bag.tabs:ShowTabByID(1)
		end

		-- Sort tabs to ensure Bank tab is first
		self.bag.tabs:SortTabsByID()
		return
	end

	-- Hide the single bank tab when multiple tabs are enabled
	if self.bag.tabs:TabExistsByID(1) then
		self.bag.tabs:HideTabByID(1)
	end

	-- Try to get character bank tab data from the API
	local characterTabData = C_Bank
		and C_Bank.FetchPurchasedBankTabData
		and C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)

	for _, data in pairs(characterTabData) do
		if not self.bag.tabs:TabExistsByID(data.ID) then
			self.bag.tabs:AddTab(ctx, data.name, data.ID)
		else
			-- Update the name if it changed
			if self.bag.tabs:GetTabNameByID(data.ID) ~= data.name then
				self.bag.tabs:RenameTabByID(ctx, data.ID, data.name)
			end
			self.bag.tabs:ShowTabByID(data.ID)
		end
	end

	-- Sort tabs by ID to ensure proper order
	self.bag.tabs:SortTabsByID()

	-- Add character bank purchase tab (special ID: -1) if available
	if C_Bank and C_Bank.CanPurchaseBankTab and C_Bank.HasMaxBankTabs
		and C_Bank.CanPurchaseBankTab(Enum.BankType.Character)
		and not C_Bank.HasMaxBankTabs(Enum.BankType.Character) then
		-- Add purchase tab if it doesn't exist
		if not self.bag.tabs:TabExistsByID(-1) then
			-- Use secure template without custom onClick - let template handle purchase
			self.bag.tabs:AddTab(ctx, L:G("Purchase Bank Tab"), -1, nil, nil, self.bag.frame, "BankPanelPurchaseButtonScriptTemplate")

			-- Set the bank type attribute required by the secure template
			local purchaseTab = self.bag.tabs:GetTabByName(L:G("Purchase Bank Tab"))
			if purchaseTab then
				purchaseTab:SetAttribute("overrideBankType", Enum.BankType.Character)
			end
		else
			self.bag.tabs:ShowTabByID(-1)
		end
	else
		-- Hide purchase tab if max tabs reached
		if self.bag.tabs:TabExistsByID(-1) then
			self.bag.tabs:HideTabByID(-1)
		end
	end

	-- Adjust frame width if needed
	local w = self.bag.tabs.width
	if
		self.bag.frame:GetWidth() + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET
		< w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET
	then
		self.bag.frame:SetWidth(w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET)
	end
end

---@param ctx Context
function bank.proto:GenerateWarbankTabs(ctx)
	local tabData = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account)
	for _, data in pairs(tabData) do
		if self.bag.tabs:TabExistsByID(data.ID) and self.bag.tabs:GetTabNameByID(data.ID) ~= data.name then
			self.bag.tabs:RenameTabByID(ctx, data.ID, data.name)
		elseif not self.bag.tabs:TabExistsByID(data.ID) then
			self.bag.tabs:AddTab(ctx, data.name, data.ID)
		end
	end

	-- Sort tabs by ID to ensure proper order (was missing - caused tab selection bugs)
	self.bag.tabs:SortTabsByID()

	-- Add account bank purchase tab (special ID: -2) if available
	if C_Bank and C_Bank.CanPurchaseBankTab and C_Bank.HasMaxBankTabs
		and C_Bank.CanPurchaseBankTab(Enum.BankType.Account)
		and not C_Bank.HasMaxBankTabs(Enum.BankType.Account) then
		-- Add purchase tab if it doesn't exist
		if not self.bag.tabs:TabExistsByID(-2) then
			-- Use secure template without custom onClick - let template handle purchase
			self.bag.tabs:AddTab(ctx, L:G("Purchase Warbank Tab"), -2, nil, nil, self.bag.frame, "BankPanelPurchaseButtonScriptTemplate")

			-- Set the bank type attribute required by the secure template
			local purchaseTab = self.bag.tabs:GetTabByName(L:G("Purchase Warbank Tab"))
			if purchaseTab then
				purchaseTab:SetAttribute("overrideBankType", Enum.BankType.Account)
			end
		else
			self.bag.tabs:ShowTabByID(-2)
		end
	else
		-- Hide purchase tab if max tabs reached
		if self.bag.tabs:TabExistsByID(-2) then
			self.bag.tabs:HideTabByID(-2)
		end
	end

	local w = self.bag.tabs.width
	if
		self.bag.frame:GetWidth() + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET
		< w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET
	then
		self.bag.frame:SetWidth(w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET)
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

function bank.proto:HideBankAndReagentTabs()
	if database:GetCharacterBankTabsEnabled() then
		-- Hide all character bank tabs
		local bankBags = const.BANK_ONLY_BAGS_LIST
		for _, bagID in ipairs(bankBags) do
			local tabID = bagID
			if self.bag.tabs:TabExistsByID(tabID) then
				self.bag.tabs:HideTabByID(tabID)
			end
		end
	else
		self.bag.tabs:HideTabByID(1) -- Hide Bank tab
	end
end

function bank.proto:ShowBankAndReagentTabs()
	if database:GetCharacterBankTabsEnabled() then
		-- Show all character bank tabs
		local bankBags = const.BANK_ONLY_BAGS_LIST
		for _, bagID in ipairs(bankBags) do
			local tabID = bagID
			if self.bag.tabs:TabExistsByID(tabID) then
				self.bag.tabs:ShowTabByID(tabID)
			end
		end
	else
		self.bag.tabs:ShowTabByID(1)
	end
end

---@param ctx Context
function bank.proto:SwitchToBank(ctx)
	self.bag.bankTab = Enum.BagIndex.Characterbanktab
	self.bag:SetTitle(L:G("Bank"))
	self.bag.currentItemCount = -1
	-- Set the active bank type so right-click item movement works correctly
	-- Let Blizzard handle BankFrame field updates via events
	if BankPanel and BankPanel.SetBankType then
		BankPanel:SetBankType(Enum.BankType.Character)
	end
	-- Clear bank cache to ensure clean state
	items:ClearBankCache(ctx)
	self.bag:Wipe(ctx)
	ctx:Set("wipe", true)
	ctx:Set("filterBagID", nil) -- Clear filter for single bank tab
	-- Update visual tab selection
	self.bag.tabs:SetTabByID(ctx, 1)
	-- Trigger a full refresh and redraw
	events:SendMessage(ctx, "bags/RefreshBank")
	ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
end

---@param ctx Context
---@param tabID number
function bank.proto:SwitchToCharacterBankTab(ctx, tabID)
	self.bag.bankTab = tabID
	-- Set the active bank type so right-click item movement works correctly
	-- Let Blizzard handle BankFrame field updates via events
	if BankPanel and BankPanel.SetBankType then
		BankPanel:SetBankType(Enum.BankType.Character)
	end
	self.bag:SetTitle(format(L:G("Bank Tab %d"), tabID - const.BANK_ONLY_BAGS_LIST[1] + 1))
	self.bag.currentItemCount = -1
	-- Clear bank cache to ensure no items from other tabs remain
	items:ClearBankCache(ctx)
	self.bag:Wipe(ctx)
	ctx:Set("wipe", true)
	ctx:Set("filterBagID", tabID)
	-- Update visual tab selection
	self.bag.tabs:SetTabByID(ctx, tabID)
	-- Trigger a full refresh and redraw
	events:SendMessage(ctx, "bags/RefreshBank")
	ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
end

---@param ctx Context
---@param tabIndex number
---@return boolean
function bank.proto:SwitchToAccountBank(ctx, tabIndex)
	self.bag.bankTab = tabIndex
	-- Set the active bank type so right-click item movement works correctly
	-- Let Blizzard handle BankFrame field updates via events
	if BankPanel and BankPanel.SetBankType then
		BankPanel:SetBankType(Enum.BankType.Account)
	end
	local tabData = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account)
	for _, data in pairs(tabData) do
		if data.ID == tabIndex then
			-- Use SelectTab method instead of direct field assignment
			if BankPanel and BankPanel.SelectTab then
				BankPanel:SelectTab(data.ID)
			end
			break
		end
	end
	if BankPanel and BankPanel.TriggerEvent then
		BankPanel:TriggerEvent(BankPanelMixin.Event.BankTabClicked, tabIndex)
	end
	self.bag:SetTitle(ACCOUNT_BANK_PANEL_TITLE)
	self.bag.currentItemCount = -1
	self.bag:Wipe(ctx)
	ctx:Set("wipe", true)
	ctx:Set("filterBagID", nil) -- Clear filter for account bank
	-- Update visual tab selection
	self.bag.tabs:SetTabByID(ctx, tabIndex)
	items:RefreshBank(ctx)
	ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
	return true
end

---@param ctx Context
function bank.proto:SwitchToBankAndWipe(ctx)
	ctx:Set("wipe", true)
	-- Set bankTab first to ensure it's always valid for refresh operations
	-- Use Characterbanktab as Bank was removed in TWW 11.2
	self.bag.bankTab = Enum.BagIndex.Characterbanktab
	-- Set the active bank type so right-click item movement works correctly
	-- Let Blizzard handle BankFrame field updates via events
	if BankPanel and BankPanel.SetBankType then
		BankPanel:SetBankType(Enum.BankType.Character)
	end
	if self.bag.tabs then
		self.bag.tabs:SetTabByID(ctx, 1)
	end
	self.bag:SetTitle(L:G("Bank"))
	items:ClearBankCache(ctx)
	self.bag:Wipe(ctx)
end

---@param bankType number
function bank.proto:TriggerPurchaseDialog(bankType)
	-- Use Blizzard's native purchase confirmation dialog
	if not C_Bank or not C_Bank.FetchNextPurchasableBankTabData then
		return
	end

	local tabData = C_Bank.FetchNextPurchasableBankTabData(bankType)
	if not tabData or not tabData.tabCost then
		return
	end

	-- Blizzard's CONFIRM_BUY_BANK_TAB dialog expects bankType in data parameter
	StaticPopup_Show("CONFIRM_BUY_BANK_TAB", tabData.tabCost, nil, {
		bankType = bankType
	})
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
