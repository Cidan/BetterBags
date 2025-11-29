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

	bag:GenerateCharacterBankTabs(ctx)
	bag:GenerateWarbankTabs(ctx)

	if addon.atWarbank then
		bag:HideBankAndReagentTabs()
		bag.tabs:SetTabByID(ctx, 13)
		-- Set the active bank type for warbank
		if BankPanel and BankPanel.SetBankType then
			BankPanel:SetBankType(Enum.BankType.Account)
		end
	else
		bag:ShowBankAndReagentTabs()
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
					local bankTabData = bag:GetWarbankTabDataByID(id)
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
			bag:SwitchToCharacterBankTab(ectx, tabID)
			return true -- Tab switch handled, allow selection
		elseif tabID == 1 then
			-- Bank tab
			BankPanel.TabSettingsMenu:Hide()
			if BankPanel.SetBankType then
				BankPanel:SetBankType(Enum.BankType.Character)
			end
			bag:SwitchToBank(ectx)
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
			bag:SwitchToAccountBank(ectx, tabID)
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
	events:RegisterEvent("PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", function(ectx)
		bag:GenerateWarbankTabs(ectx)
	end)
	events:RegisterEvent("BANK_TAB_SETTINGS_UPDATED", function(ectx)
		-- Update both warbank and character bank tabs when settings change
		bag:GenerateWarbankTabs(ectx)
		if database:GetCharacterBankTabsEnabled() then
			bag:GenerateCharacterBankTabs(ectx)
		end
	end)
end

---@return boolean
function bank.proto:ShouldHandleSort()
	return false
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
