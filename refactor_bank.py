import re

with open("bags/bank.lua", "r") as f:
    text = f.read()

# Replace GenerateCharacterBankTabs and GenerateWarbankTabs with GenerateGroupTabs
pattern1 = r"---@param ctx Context\nfunction bank\.proto:GenerateCharacterBankTabs\(ctx\).*?(?=---@param id number)"
replacement1 = """local NEW_GROUP_TAB_ID = 0
local NEW_GROUP_TAB_NAME = "New Group"
local NEW_GROUP_TAB_ICON = "communities-icon-addchannelplus"

---@class Groups: AceModule
local groups = addon:GetModule("Groups")

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
		self.bag.tabs:AddTab(ctx, NEW_GROUP_TAB_NAME, NEW_GROUP_TAB_ID)
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
	self.bag.tabs:MoveToEnd(NEW_GROUP_TAB_NAME)

	local w = self.bag.tabs.width
	if self.bag.frame:GetWidth() + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET < w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET then
		self.bag.frame:SetWidth(w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET)
	end
end

function bank.proto:SetupPlusTabTooltip(ctx)
	local plusTab = self.bag.tabs:GetTabByName(NEW_GROUP_TAB_NAME)
	if plusTab then
		plusTab:SetScript("OnEnter", function(button)
			GameTooltip:SetOwner(button, "ANCHOR_TOP")
			GameTooltip:SetText(L:G("Create New Group Tab"))
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
			text = L:G("Create New Bank Tab") .. "\\n\\n" .. L:G("1. Enter group name:"),
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
					f.bankType = Enum.BankType.Character
					
					UIDropDownMenu_Initialize(dropdown, function(self, level, menuList)
						local info = UIDropDownMenu_CreateInfo()
						
						info.text = L:G("Bank")
						info.func = function()
							UIDropDownMenu_SetSelectedID(dropdown, 1)
							f.bankType = Enum.BankType.Character
						end
						UIDropDownMenu_AddButton(info)
						
						if addon.isRetail then
							info.text = L:G("Warbank")
							info.func = function()
								UIDropDownMenu_SetSelectedID(dropdown, 2)
								f.bankType = Enum.BankType.Account
							end
							UIDropDownMenu_AddButton(info)
						end
					end)
					f.bankTypeDropdown = dropdown
				end
				-- Reset to Bank by default
				UIDropDownMenu_SetSelectedID(f.bankTypeDropdown, 1)
				f.bankType = Enum.BankType.Character
				
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
		self.bag.bankTab = Enum.BagIndex.Characterbanktab
	end

	self.bag:SetTitle(group.name)
	self.bag.currentItemCount = -1

	items:ClearBankCache(ctx)
	self.bag:Wipe(ctx)
	ctx:Set("wipe", true)

	events:SendMessage(ctx, "bags/RefreshBank")
	ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
end

"""
text = re.sub(pattern1, replacement1, text, flags=re.DOTALL)

# Delete SwitchToBank, SwitchToAccountBank, SwitchToCharacterBankTab
text = re.sub(r"---@param ctx Context\nfunction bank\.proto:SwitchToBank\(ctx\).*?(?=---@param ctx Context\nfunction bank\.proto:SwitchToBankAndWipe)", "", text, flags=re.DOTALL)

# Update OnShow
text = re.sub(r"self:GenerateCharacterBankTabs\(ctx\)\n\tself:GenerateWarbankTabs\(ctx\)", "self:GenerateGroupTabs(ctx)", text)

text = re.sub(r"if addon\.atWarbank then.*?else.*?end", """local activeGroup = database:GetActiveGroup(const.BAG_KIND.BANK)
				self.bag.tabs:SetTabByID(ctx, activeGroup)
				self:SwitchToGroup(ctx, activeGroup)""", text, flags=re.DOTALL)

# The second occurrence inside the else block of bag fading:
# It starts with "if addon.atWarbank then" and ends before "self.bag.moneyFrame:Update()"
pattern_onshow2 = r"if addon\.atWarbank then.*?self\.bag\.moneyFrame:Update\(\)"
text = re.sub(pattern_onshow2, """local activeGroup = database:GetActiveGroup(const.BAG_KIND.BANK)
		self.bag.tabs:SetTabByID(ctx, activeGroup)
		self:SwitchToGroup(ctx, activeGroup)

		self.bag.moneyFrame:Update()""", text, flags=re.DOTALL, count=1)


# Update OnCreate
# Remove the old click handler and replace with SwitchToGroup logic
pattern_oncreate_click = r"self\.bag\.tabs:SetClickHandler\(function\(ectx, tabID, button\).*?end\)"
replacement_click = """self.bag.tabs:SetClickHandler(function(ectx, tabID, button)
		if tabID == NEW_GROUP_TAB_ID then
			behavior:ShowCreateGroupDialog()
			return false
		end
		
		if button == "RightButton" and tabID > 0 then
			-- Show settings? Maybe we don't need this for virtual tabs, or use groups renaming.
			if tabID > 3 then -- Can't delete 1, 2, 3
				-- Could trigger a delete context menu, but for now just switch
			end
		end

		if tabID == -1 or tabID == -2 then
			return false -- Purchase tabs handled by secure templates
		end

		behavior:SwitchToGroup(ectx, tabID)
		return true
	end)"""
text = re.sub(pattern_oncreate_click, replacement_click, text, flags=re.DOTALL)

# Remove the old AddTab("Bank", 1) logic from OnCreate
text = re.sub(r"-- Always create Bank tab.*?if not database:GetCharacterBankTabsEnabled\(\) then.*?end", "", text, flags=re.DOTALL)

# Update RegisterEvents
text = re.sub(r"events:RegisterEvent\(\"PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED\", function\(ectx\).*?(?=events:RegisterEvent\(\"BANK_TAB_SETTINGS_UPDATED\")", 
"""events:RegisterEvent("PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", function(ectx)
		behavior:GenerateGroupTabs(ectx)
	end)
	
	events:RegisterMessage("groups/Created", function(_, ectx, group)
		if group.kind == const.BAG_KIND.BANK then
			behavior:GenerateGroupTabs(ectx)
		end
	end)
	events:RegisterMessage("groups/Deleted", function(_, ectx, groupID)
		local activeGroup = database:GetActiveGroup(const.BAG_KIND.BANK)
		if activeGroup == groupID then
			behavior:SwitchToGroup(ectx, 2) -- Default to Bank
		end
		behavior:GenerateGroupTabs(ectx)
	end)
	
	""", text, flags=re.DOTALL)

text = re.sub(r"events:RegisterEvent\(\"BANK_TAB_SETTINGS_UPDATED\".*?end\)\n", """events:RegisterEvent("BANK_TAB_SETTINGS_UPDATED", function(ectx, bankType)
		behavior:GenerateGroupTabs(ectx)
	end)\n""", text, flags=re.DOTALL)

with open("bags/bank.lua", "w") as f:
    f.write(text)

