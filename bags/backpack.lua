---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)

---@class BackpackBehavior: AceModule
---@field proto BackpackBehaviorProto
local backpack = addon:NewModule("BackpackBehavior")

---@class Localization: AceModule
local L = addon:GetModule("Localization")

---@class Constants: AceModule
local const = addon:GetModule("Constants")

---@class Events: AceModule
local events = addon:GetModule("Events")

---@class Debug: AceModule
local debug = addon:GetModule("Debug")

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class BagSlots: AceModule
local bagSlots = addon:GetModule("BagSlots")

---@class SearchBox: AceModule
local searchBox = addon:GetModule("SearchBox")

---@class Currency: AceModule
local currency = addon:GetModule("Currency")

---@class ThemeConfig: AceModule
local themeConfig = addon:GetModule("ThemeConfig")

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

-------
--- Backpack Behavior Prototype
-------

--- BackpackBehaviorProto defines the behavior specific to the player's backpack.
---@class BackpackBehaviorProto
---@field bag Bag Reference to the parent bag
backpack.proto = {}

function backpack.proto:OnShow(ctx)
	PlaySound(SOUNDKIT.IG_BACKPACK_OPEN)

	-- Lazy resize tabs on first show to account for fonts loaded by other addons (e.g., GW2 UI)
	if not self.bag.tabsResizedAfterLoad then
		if self.bag.tabs then
			self.bag.tabs:ResizeAllTabs(ctx)
			self.bag.tabsResizedAfterLoad = true
		end
	end

	-- Use fade animation if enabled
	if database:GetEnableBagFading() then
		self.bag.fadeInGroup:Play()
	else
		self.bag.frame:Show()
	end

	ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
end

---@param ctx Context
function backpack.proto:OnHide(ctx)
	addon.ForceHideBlizzardBags()
	PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)

	-- Use fade animation if enabled
	if database:GetEnableBagFading() then
		-- Set up callback to handle post-hide logic
		self.bag.fadeOutGroup.callback = function()
			self.bag.fadeOutGroup.callback = nil  -- Clean up callback
			self.bag.searchFrame:Hide()
			if self.bag.drawOnClose then
				debug:Log("draw", "Drawing bag on close")
				self.bag.drawOnClose = false
				self.bag:Refresh(ctx)
			end
			ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
		end
		self.bag.fadeOutGroup:Play()
	else
		self.bag.frame:Hide()
		self.bag.searchFrame:Hide()
		if self.bag.drawOnClose then
			debug:Log("draw", "Drawing bag on close")
			self.bag.drawOnClose = false
			self.bag:Refresh(ctx)
		end
		ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
	end
end

---@param ctx Context
function backpack.proto:OnCreate(ctx)
	-- Search frame
	self.bag.searchFrame = searchBox:Create(ctx, self.bag.frame)

	-- Bag slots panel
	local slots = bagSlots:CreatePanel(ctx, const.BAG_KIND.BACKPACK)
	slots.frame:SetPoint("BOTTOMLEFT", self.bag.frame, "TOPLEFT", 0, 8)
	slots.frame:SetParent(self.bag.frame)
	slots.frame:Hide()
	self.bag.slots = slots

	-- Currency icon grid (bottom of backpack)
	self.bag.currencyIconGrid = currency:CreateIconGrid(self.bag.frame)

	-- Theme config
	self.bag.themeConfigFrame = themeConfig:Create(self.bag.sideAnchor)
	self.bag.windowGrouping:AddWindow("themeConfig", self.bag.themeConfigFrame)

	-- Group tabs
	self.bag.tabs = tabs:Create(self.bag.frame, const.BAG_KIND.BACKPACK)

	-- Set up tab click handler
	local behavior = self
	self.bag.tabs:SetClickHandler(function(ectx, tabID, button)
		return behavior:OnTabClicked(ectx, tabID, button)
	end)

	-- Only show tabs if groups are enabled
	if database:GetGroupsEnabled(const.BAG_KIND.BACKPACK) then
		-- Generate initial group tabs
		self:GenerateGroupTabs(ctx)

		-- Set the active group tab
		local activeGroup = database:GetActiveGroup(const.BAG_KIND.BACKPACK)
		self.bag.tabs:SetTabByID(ctx, activeGroup)
	else
		self.bag.tabs.frame:Hide()
	end
end

---@param ctx Context
function backpack.proto:OnRefresh(ctx)
	events:SendMessage(ctx, "bags/RefreshBackpack")
end

---@return FrameStrata
function backpack.proto:GetFrameStrata()
	return "MEDIUM"
end

---@return number
function backpack.proto:GetFrameLevel()
	return 500
end

---@param bottomBar Frame
---@return Money
function backpack.proto:SetupMoneyFrame(bottomBar)
	local moneyFrame = money:Create()
	moneyFrame.frame:SetPoint("BOTTOMRIGHT", bottomBar, "BOTTOMRIGHT", -4, 0)
	moneyFrame.frame:SetParent(self.bag.frame)
	return moneyFrame
end

function backpack.proto:RegisterEvents()
	local bag = self.bag
	local behavior = self

	events:BucketEvent("BAG_UPDATE_COOLDOWN", function(ectx)
		bag:OnCooldown(ectx)
	end)

	-- Listen for group changes to regenerate tabs
	events:RegisterMessage("groups/Created", function(ctx, group)
		if group.kind == const.BAG_KIND.BACKPACK then
			behavior:GenerateGroupTabs(ctx)
		end
	end)

	events:RegisterMessage("groups/Changed", function(ctx, _, _, _, kind)
		if kind == const.BAG_KIND.BACKPACK then
			behavior:GenerateGroupTabs(ctx)
		end
	end)

	events:RegisterMessage("groups/Deleted", function(ctx, groupID, _, kind)
		if kind ~= const.BAG_KIND.BACKPACK then return end
		-- If the deleted group was active, switch to Backpack
		local activeGroup = database:GetActiveGroup(const.BAG_KIND.BACKPACK)
		if activeGroup == groupID then
			behavior:SwitchToGroup(ctx, 1) -- Switch to Backpack
		end
		behavior:GenerateGroupTabs(ctx)
	end)

	-- Listen for groups enabled/disabled toggle
	events:RegisterMessage("groups/EnabledChanged", function(ctx, kind, _)
		if kind == const.BAG_KIND.BACKPACK then
			behavior:GenerateGroupTabs(ctx)
		end
	end)
end

---@return boolean
function backpack.proto:ShouldHandleSort()
	return true
end

function backpack.proto:SwitchToBankAndWipe()
	-- No-op for backpack - this method only applies to bank
end

-------
--- Group Tab Methods
-------

-- Special ID for the "New Group" tab (using 0 to avoid negative ID secure button handling)
local NEW_GROUP_TAB_ID = 0
local NEW_GROUP_TAB_ICON = "communities-icon-addchannelplus"

-- GenerateGroupTabs creates tabs for all groups.
---@param ctx Context
function backpack.proto:GenerateGroupTabs(ctx)
	-- Skip tab generation if groups are disabled
	if not database:GetGroupsEnabled(const.BAG_KIND.BACKPACK) then
		self.bag.tabs.frame:Hide()
		return
	end

	-- Show tabs frame in case it was hidden
	self.bag.tabs.frame:Show()

	local allGroups = groups:GetAllGroups(const.BAG_KIND.BACKPACK)

	-- Create tabs for each group that doesn't exist yet
	for groupID, group in pairs(allGroups) do
		if not self.bag.tabs:TabExistsByID(groupID) then
			self.bag.tabs:AddTab(ctx, group.name, groupID)
		else
			-- Update name if it changed
			if self.bag.tabs:GetTabNameByID(groupID) ~= group.name then
				self.bag.tabs:RenameTabByID(ctx, groupID, group.name)
			end
			self.bag.tabs:ShowTabByID(groupID)
		end
	end

	-- Hide tabs for groups that no longer exist (skip the "+" tab with ID 0)
	for _, tab in pairs(self.bag.tabs.tabIndex) do
		if tab.id and tab.id > 0 and not allGroups[tab.id] then
			self.bag.tabs:HideTabByID(tab.id)
		end
	end

	-- Add "+" tab for creating new groups (using special ID 0)
	if not self.bag.tabs:TabExistsByID(NEW_GROUP_TAB_ID) then
		self.bag.tabs:AddTab(ctx, L:G("New Group"), NEW_GROUP_TAB_ID)
		-- Set the icon for the tab (this will hide the text and show the icon)
		self.bag.tabs:SetTabIconByID(ctx, NEW_GROUP_TAB_ID, NEW_GROUP_TAB_ICON)
		-- Set up tooltip for the "+" tab
		self:SetupPlusTabTooltip(ctx)
	end

	-- Sort tabs: groups by ID, "+" tab always last
	self.bag.tabs:SortTabsByID()

	-- Move "+" tab to end
	self.bag.tabs:MoveToEnd(L:G("New Group"))

	-- Ensure tab 1 (Backpack) is selected with proper highlight
	self.bag.tabs:SetTabByID(ctx, 1)
	database:SetActiveGroup(const.BAG_KIND.BACKPACK, 1)
end

-- OnTabClicked handles tab click events.
---@param ctx Context
---@param tabID number
---@param button string
---@return boolean? shouldSelect
function backpack.proto:OnTabClicked(ctx, tabID, button)
	-- "+" tab (ID = 0) - show create dialog, don't select
	if tabID == NEW_GROUP_TAB_ID then
		self:ShowCreateGroupDialog()
		return false -- Prevent selection
	end

	-- Right-click handling
	if button == "RightButton" and tabID then
		-- Backpack (ID 1) should not show context menu
		if tabID == 1 then
			return false -- Do nothing on right-click for Backpack
		end
		-- Other groups show context menu
		self:ShowGroupContextMenu(ctx, tabID)
		return false -- Don't change selection on right-click
	end

	-- Left-click - switch to group
	if tabID and tabID > 0 then
		self:SwitchToGroup(ctx, tabID)
		return true -- Allow selection
	end

	return true
end

-- SetupPlusTabTooltip adds a tooltip to the "+" tab.
---@param ctx Context
function backpack.proto:SetupPlusTabTooltip(ctx)
	---@class Themes: AceModule
	local themes = addon:GetModule("Themes")

	-- Find the tab by ID
	for _, tab in pairs(self.bag.tabs.tabIndex) do
		if tab.id == NEW_GROUP_TAB_ID then
			local decoration = themes:GetTabButton(ctx, tab)
			decoration:SetScript("OnEnter", function(f)
				GameTooltip:SetOwner(f, "ANCHOR_TOP")
				GameTooltip:SetText(L:G("New Group..."), 1, 1, 1, 1, true)
				GameTooltip:AddLine(L:G("Click to create a new group for organizing categories."), 1, 1, 1, true)
				GameTooltip:Show()
			end)
			decoration:SetScript("OnLeave", function()
				GameTooltip:Hide()
			end)
			break
		end
	end
end

-- SwitchToGroup switches to a specific group.
---@param ctx Context
---@param groupID number
function backpack.proto:SwitchToGroup(ctx, groupID)
	local group = groups:GetGroup(const.BAG_KIND.BACKPACK, groupID)
	if not group then
		debug:Log("groups", "Cannot switch to non-existent group: %d", groupID)
		return
	end

	database:SetActiveGroup(const.BAG_KIND.BACKPACK, groupID)
	self.bag.tabs:SetTabByID(ctx, groupID)

	debug:Log("groups", "Switched to group: %s (ID: %d)", group.name, groupID)

	-- Trigger a refresh to filter sections by group
	events:SendMessage(ctx, "bags/RefreshBackpack")
end

-- ShowCreateGroupDialog shows a dialog to create a new group.
function backpack.proto:ShowCreateGroupDialog()
	local question = addon:GetModule('Question')
	question:AskForInput(
		L:G("Create New Backpack Tab"),
		L:G("Enter group name:"),
		function(name)
			local ctx = context:New("CreateGroup")
			local newGroup = groups:CreateGroup(ctx, const.BAG_KIND.BACKPACK, name)
			local bag = addon.Bags.Backpack
			if bag and bag.behavior then
				bag.behavior:SwitchToGroup(ctx, newGroup.id)
			end
		end
	)
end

-- ShowGroupContextMenu shows a context menu for a group tab.
---@param ctx Context
---@param groupID number
function backpack.proto:ShowGroupContextMenu(ctx, groupID)
	local group = groups:GetGroup(const.BAG_KIND.BACKPACK, groupID)
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

	-- Delete option (not for default Backpack group)
	if groupID ~= 1 then
		table.insert(menuList, {
			text = L:G("Delete Group"),
			notCheckable = true,
			func = function()
				contextMenu:Hide(ctx)
				behavior:ShowDeleteGroupConfirm(groupID)
			end,
		})
	end

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

-- ShowRenameGroupDialog shows a dialog to rename a group.
---@param groupID number
function backpack.proto:ShowRenameGroupDialog(groupID)
	local group = groups:GetGroup(const.BAG_KIND.BACKPACK, groupID)
	if not group then return end

	-- Define the static popup if not already defined
	if not StaticPopupDialogs["BETTERBAGS_RENAME_GROUP"] then
		StaticPopupDialogs["BETTERBAGS_RENAME_GROUP"] = {
			text = L:G("Enter new group name:"),
			hasEditBox = true,
			button1 = L:G("Rename"),
			button2 = L:G("Cancel"),
			OnAccept = function(f)
				local name = f.EditBox:GetText()
				if name and name ~= "" then
					local ctx = context:New("RenameGroup")
					groups:RenameGroup(ctx, f.data.groupID, name)
				end
			end,
			OnShow = function(f)
				local currentGroup = groups:GetGroup(const.BAG_KIND.BACKPACK, f.data.groupID)
				if currentGroup then
					f.EditBox:SetText(currentGroup.name)
					f.EditBox:HighlightText()
				end
				f.EditBox:SetFocus()
			end,
			EditBoxOnEnterPressed = function(f)
				local parent = f:GetParent()
				local name = parent.EditBox:GetText()
				if name and name ~= "" then
					local ctx = context:New("RenameGroup")
					groups:RenameGroup(ctx, parent.data.groupID, name)
				end
				parent:Hide()
			end,
			EditBoxOnEscapePressed = function(f)
				f:GetParent():Hide()
			end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
	end

	StaticPopup_Show("BETTERBAGS_RENAME_GROUP", nil, nil, { groupID = groupID })
end

-- ShowDeleteGroupConfirm shows a confirmation dialog to delete a group.
---@param groupID number
function backpack.proto:ShowDeleteGroupConfirm(groupID)
	local group = groups:GetGroup(const.BAG_KIND.BACKPACK, groupID)
	if not group then return end

	-- Define the static popup if not already defined
	if not StaticPopupDialogs["BETTERBAGS_DELETE_GROUP"] then
		StaticPopupDialogs["BETTERBAGS_DELETE_GROUP"] = {
			text = L:G("Are you sure you want to delete the group '%s'? Categories in this group will be moved back to Backpack."),
			button1 = L:G("Delete"),
			button2 = L:G("Cancel"),
			OnAccept = function(f)
				local ctx = context:New("DeleteGroup")
				groups:DeleteGroup(ctx, f.data.groupID)
			end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
	end

	StaticPopup_Show("BETTERBAGS_DELETE_GROUP", group.name, nil, { groupID = groupID })
end

-------
--- BackpackBehavior Module Functions
-------

---@param bag Bag
---@return BackpackBehaviorProto
function backpack:Create(bag)
	local b = {}
	setmetatable(b, { __index = backpack.proto })
	b.bag = bag
	return b
end
