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

---@class BagSlots: AceModule
local bagSlots = addon:GetModule("BagSlots")

---@class SearchBox: AceModule
local searchBox = addon:GetModule("SearchBox")

---@class Currency: AceModule
local currency = addon:GetModule("Currency")

---@class ThemeConfig: AceModule
local themeConfig = addon:GetModule("ThemeConfig")

-------
--- Classic Backpack Behavior Overrides
--- The unified frames/bag.lua delegates search/slots/currency/theme-config
--- creation to the behavior's OnCreate (the legacy frames/classic/bag.lua that
--- created them inline was removed in the UI unification, #1044), so the Classic
--- override must create them itself — otherwise bag.slots is never set and the
--- context menu's "Show Bags" entry (gated on bag.slots) disappears on Classic.
-------

---@param ctx Context
function backpack.proto:OnCreate(ctx)
	-- Search frame
	self.bag.searchFrame = searchBox:Create(ctx, self.bag.frame)

	-- Bag slots panel
	local slots = bagSlots:CreatePanel(ctx, const.BAG_KIND.BACKPACK, self.bag.frame)
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
