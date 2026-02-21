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

	self.bag.tabs = tabs:Create(self.bag.frame)

	self.bag.tabs:SetClickHandler(function(ectx, tabID, _)
		if tabID == NEW_GROUP_TAB_ID then
			behavior:ShowCreateGroupDialog()
			return false
		end

		if tabID == -1 or tabID == -2 then
			return false -- Purchase tabs handled by secure templates
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

	events:RegisterEvent("BANK_TAB_SETTINGS_UPDATED", function(ectx, _)
		behavior:GenerateGroupTabs(ectx)
	end)

	events:RegisterMessage("groups/Created", function(_, ectx, group)
		if group.kind == const.BAG_KIND.BANK then
			behavior:GenerateGroupTabs(ectx)
		end
	end)

	events:RegisterMessage("groups/Changed", function(_, ectx, groupID)
		local group = groups:GetGroup(groupID)
		if group and group.kind == const.BAG_KIND.BANK then
			behavior:GenerateGroupTabs(ectx)
		end
	end)

	events:RegisterMessage("groups/Deleted", function(_, ectx, groupID)
		local activeGroup = database:GetActiveGroup(const.BAG_KIND.BANK)
		if activeGroup == groupID then
			local defaultBankGroup = groups:GetDefaultBankGroup()
			if defaultBankGroup then
				behavior:SwitchToGroup(ectx, defaultBankGroup.id)
			end
		end
		behavior:GenerateGroupTabs(ectx)
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

	local allGroups = groups:GetGroupsByKind(const.BAG_KIND.BANK)

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

		if addon.isRetail and C_Bank.CanPurchaseBankTab(Enum.BankType.Account) and not C_Bank.HasMaxBankTabs(Enum.BankType.Account) then
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
	if not StaticPopupDialogs["BETTERBAGS_CREATE_BANK_GROUP"] then
		StaticPopupDialogs["BETTERBAGS_CREATE_BANK_GROUP"] = {
			text = L:G("Create New Bank Tab") .. "\n\n" .. L:G("1. Enter group name:"),
			hasEditBox = true,
			button1 = L:G("Create"),
			button2 = L:G("Cancel"),
			OnShow = function(f)
				f.EditBox:SetFocus()
				f.EditBox:SetText("")

				if not f.bankTypeDropdown then
					local dropdown = CreateFrame("Frame", "BetterBagsBankTypeDropdown", f, "UIDropDownMenuTemplate")
					dropdown:SetPoint("TOP", f.EditBox, "BOTTOM", 0, -15)
					UIDropDownMenu_SetWidth(dropdown, 120)
					UIDropDownMenu_SetText(dropdown, L:G("Bank"))
					f.bankType = Enum.BankType and Enum.BankType.Character or 1

					UIDropDownMenu_Initialize(dropdown, function(_, _, _)
						local info = UIDropDownMenu_CreateInfo()

						info.text = L:G("Bank")
						info.func = function()
							UIDropDownMenu_SetText(dropdown, L:G("Bank"))
							f.bankType = Enum.BankType and Enum.BankType.Character or 1
						end
						UIDropDownMenu_AddButton(info)

						if addon.isRetail then
							info.text = L:G("Warbank")
							info.func = function()
								UIDropDownMenu_SetText(dropdown, L:G("Warbank"))
								f.bankType = Enum.BankType and Enum.BankType.Account or 2
							end
							UIDropDownMenu_AddButton(info)
						end
					end)
					f.bankTypeDropdown = dropdown
				end
				-- Reset to Bank by default
				UIDropDownMenu_SetText(f.bankTypeDropdown, L:G("Bank"))
				f.bankType = Enum.BankType and Enum.BankType.Character or 1

				f:SetHeight(180)
			end,
			OnAccept = function(f)
				local name = f.EditBox:GetText()
				if name and name ~= "" then
					local ctx = context:New("CreateGroup")
					local newGroup = groups:CreateGroup(ctx, name, const.BAG_KIND.BANK, f.bankType)
					local bag = addon.Bags.Bank
					if bag and bag.behavior then
						bag.behavior:SwitchToGroup(ctx, newGroup.id)
					end
				end
			end,
			EditBoxOnEnterPressed = function(f)
				local parent = f:GetParent()
				local name = parent.EditBox:GetText()
				if name and name ~= "" then
					local ctx = context:New("CreateGroup")
					local newGroup = groups:CreateGroup(ctx, name, const.BAG_KIND.BANK, parent.bankType)
					local bag = addon.Bags.Bank
					if bag and bag.behavior then
						bag.behavior:SwitchToGroup(ctx, newGroup.id)
					end
				end
				parent:Hide()
			end,
			EditBoxOnEscapePressed = function(f)
				f:GetParent():Hide()
			end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
		}
	end
	StaticPopup_Show("BETTERBAGS_CREATE_BANK_GROUP")
end

function bank.proto:SwitchToGroup(ctx, groupID)
	local group = groups:GetGroup(groupID)
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
