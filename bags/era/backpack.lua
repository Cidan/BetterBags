---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)

---@class BackpackBehavior: AceModule
local backpack = addon:GetModule("BackpackBehavior")

---@class Constants: AceModule
local const = addon:GetModule("Constants")

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Tabs: AceModule
local tabs = addon:GetModule("Tabs")

-------
--- Era Backpack Behavior Overrides
--- Classic Era doesn't have the currency system (GetCurrencyListInfo API).
--- Search, bag slots, and theme config are already created inline in frames/era/bag.lua.
-------

---@param ctx Context
function backpack.proto:OnCreate(ctx)
	-- Era: Search frame, bag slots, and theme config are created inline in frames/era/bag.lua
	-- Currency doesn't exist in Era (no GetCurrencyListInfo API)

	-- Group tabs
	self.bag.tabs = tabs:Create(self.bag.frame)

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
