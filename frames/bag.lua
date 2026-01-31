---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)

---@class BagFrame: AceModule
local bagFrame = addon:NewModule("BagFrame")

---@class Localization: AceModule
local L = addon:GetModule("Localization")

---@class Constants: AceModule
local const = addon:GetModule("Constants")

---@class GridFrame: AceModule
local grid = addon:GetModule("Grid")

---@class Items: AceModule
local items = addon:GetModule("Items")

---@class ItemFrame: AceModule
local itemFrame = addon:GetModule("ItemFrame")

---@class BagSlots: AceModule
local bagSlots = addon:GetModule("BagSlots")

---@class SectionFrame: AceModule
local sectionFrame = addon:GetModule("SectionFrame")

---@class Database: AceModule
local database = addon:GetModule("Database")

---@class ContextMenu: AceModule
local contextMenu = addon:GetModule("ContextMenu")

---@class MoneyFrame: AceModule
local money = addon:GetModule("MoneyFrame")

---@class Views: AceModule
local views = addon:GetModule("Views")

---@class Resize: AceModule
local resize = addon:GetModule("Resize")

---@class Events: AceModule
local events = addon:GetModule("Events")

---@class Debug: AceModule
local debug = addon:GetModule("Debug")

---@class Question: AceModule
local question = addon:GetModule("Question")

---@class Categories: AceModule
local categories = addon:GetModule("Categories")

---@class LibWindow-1.1: AceAddon
local Window = LibStub("LibWindow-1.1")

---@class Currency: AceModule
local currency = addon:GetModule("Currency")

---@class Context: AceModule
local context = addon:GetModule("Context")

---@class SearchBox: AceModule
local searchBox = addon:GetModule("SearchBox")

---@class Search: AceModule
local search = addon:GetModule("Search")

---@class SectionConfig: AceModule
local sectionConfig = addon:GetModule("SectionConfig")

---@class ThemeConfig: AceModule
local themeConfig = addon:GetModule("ThemeConfig")

---@class Themes: AceModule
local themes = addon:GetModule("Themes")

---@class WindowGroup: AceModule
local windowGroup = addon:GetModule("WindowGroup")

---@class Anchor: AceModule
local anchor = addon:GetModule("Anchor")

---@class Tabs: AceModule
local tabs = addon:GetModule("Tabs")

---@class BackpackBehavior: AceModule
local backpackBehavior = addon:GetModule("BackpackBehavior")

---@class BankBehavior: AceModule
local bankBehavior = addon:GetModule("BankBehavior")

-------
--- Bag Prototype
-------

--- Bag is a view of a single bag object. Note that this is not
--- a single bag slot, but a combined view of all bags for a given
--- kind (i.e. bank, backpack).
---@class (exact) Bag
---@field kind BagKind
---@field currentView View
---@field frame Frame The fancy frame of the bag.
---@field anchor AnchorFrame The anchor frame for the bag.
---@field bottomBar Frame The bottom bar of the bag.
---@field recentItems Section The recent items section.
---@field currencyFrame CurrencyFrame The currency frame.
---@field sectionConfigFrame SectionConfigFrame The section config frame.
---@field themeConfigFrame ThemeConfigFrame The theme config frame.
---@field currentItemCount number
---@field private sections table<string, Section>
---@field slots bagSlots
---@field decorator Texture
---@field bg Texture
---@field moneyFrame Money
---@field resizeHandle Button
---@field drawOnClose boolean
---@field drawAfterCombat boolean
---@field menuList MenuList[]
---@field toRelease Item[]
---@field toReleaseSections Section[]
---@field views table<BagView, View>
---@field loaded boolean
---@field windowGrouping WindowGrouping
---@field sideAnchor Frame
---@field previousSize number
---@field searchFrame SearchFrame
---@field tabs Tab
---@field bankTab BankTab
---@field behavior BackpackBehaviorProto|BankBehaviorProto The bag-type-specific behavior
bagFrame.bagProto = {}

---@param ctx Context
function bagFrame.bagProto:Show(ctx)
	if self.frame:IsShown() then
		return
	end
	self.behavior:OnShow(ctx)
end

---@param ctx Context
function bagFrame.bagProto:Hide(ctx)
	if not self.frame:IsShown() then
		return
	end
	self.behavior:OnHide(ctx)
end

---@param ctx Context
function bagFrame.bagProto:Toggle(ctx)
	if self.frame:IsShown() then
		self:Hide(ctx)
	else
		self:Show(ctx)
	end
end

function bagFrame.bagProto:IsShown()
	return self.frame:IsShown()
end

---@return number x
---@return number y
function bagFrame.bagProto:GetPosition()
	local scale = self.frame:GetScale()
	local x, y = self.frame:GetCenter()
	return x * scale, y * scale
end

---@param ctx Context
function bagFrame.bagProto:Sort(ctx)
	if not self.behavior:ShouldHandleSort() then
		return
	end
	PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
	events:SendMessage(ctx, "bags/SortBackpack")
end

-- Wipe will wipe the contents of the bag and release all cells.
---@param ctx Context
function bagFrame.bagProto:Wipe(ctx)
	if self.currentView then
		self.currentView:Wipe(ctx)
	end
end

---@return string
function bagFrame.bagProto:GetName()
	return self.frame:GetName()
end

-- Refresh will refresh this bag's item database, and then redraw the bag.
-- This is what would be considered a "full refresh".
---@param ctx Context
function bagFrame.bagProto:Refresh(ctx)
	self.behavior:OnRefresh(ctx)
end

---@param ctx Context
---@param results table<string, boolean>
function bagFrame.bagProto:Search(ctx, results)
	if not self.currentView then
		return
	end
	for _, item in pairs(self.currentView:GetItemsByBagAndSlot()) do
		item:UpdateSearch(ctx, results[item.slotkey])
	end
end

---@param ctx Context
function bagFrame.bagProto:ResetSearch(ctx)
	if not self.currentView then
		return
	end
	for _, item in pairs(self.currentView:GetItemsByBagAndSlot()) do
		item:UpdateSearch(ctx, true)
	end
end

-- Draw will draw the correct bag view based on the bag view configuration.
---@param ctx Context
---@param slotInfo SlotInfo
---@param callback fun()
function bagFrame.bagProto:Draw(ctx, slotInfo, callback)
	local view = self.views[database:GetBagView(self.kind)]

	if view == nil then
		assert(view, "No view found for bag view: " .. database:GetBagView(self.kind))
		return
	end

	if self.currentView and self.currentView:GetBagView() ~= view:GetBagView() then
		self.currentView:Wipe(ctx)
		self.currentView:GetContent():Hide()
	end

	debug:StartProfile("Bag Render %d", self.kind)
	view:Render(ctx, self, slotInfo, function()
		debug:EndProfile("Bag Render %d", self.kind)
		view:GetContent():Show()
		self.currentView = view
		self.frame:SetScale(database:GetBagSizeInfo(self.kind, database:GetBagView(self.kind)).scale / 100)
		local text = searchBox:GetText()
		if text ~= "" and text ~= nil then
			self:Search(ctx, search:Search(text))
		end
		self:OnResize()
		if
			database:GetBagView(self.kind) == const.BAG_VIEW.SECTION_ALL_BAGS
			and self.slots
			and not self.slots:IsShown()
		then
			self.slots:Draw(ctx)
			self.slots:Show()
		end
		events:SendMessage(ctx, "bag/RedrawIcons", self)
		events:SendMessage(ctx, "bag/Rendered", self, slotInfo)
		callback()
	end)
end

function bagFrame.bagProto:KeepBagInBounds()
	local w, h = self.frame:GetSize()
	self.frame:SetClampRectInsets(0, -w + 50, 0, h - 50)
	-- Toggle the clamp setting to force the frame to rebind to the screen
	-- on the correct clamp insets.
	self.frame:SetClampedToScreen(false)
	self.frame:SetClampedToScreen(true)
end

function bagFrame.bagProto:OnResize()
	if database:GetBagView(self.kind) == const.BAG_VIEW.LIST and self.currentView ~= nil then
		self.currentView:UpdateListSize(self)
	end
	if self.anchor:IsActive() then
		self.frame:ClearAllPoints()
		self.frame:SetPoint(self.anchor.anchorPoint, self.anchor.frame, self.anchor.anchorPoint)
		--- HACKFIX(lobato): This fixes a bug in the WoW rendering engine.
		-- The frame needs to be polled in some way for it to render correctly in the pipeline,
		-- otherwise relative frames will not always render correctly across the bottom edge.
		self.frame:GetBottom()
		return
	end
	--Window.RestorePosition(self.frame)
	if self.previousSize and database:GetBagView(self.kind) ~= const.BAG_VIEW.LIST and self.loaded then
		local left = self.frame:GetLeft()
		self.frame:ClearAllPoints()
		self.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, self.previousSize) --, left, self.previousSize * self.frame:GetScale())
	end
	self:KeepBagInBounds()
	self.previousSize = self.frame:GetBottom()
end

function bagFrame.bagProto:SetTitle(text)
	themes:SetTitle(self.frame, text)
end

--- SwitchToBankAndWipe delegates to behavior for bank-specific implementation.
--- This proxy method exists because external code (hooks.lua) calls bag:SwitchToBankAndWipe().
---@param ctx Context
function bagFrame.bagProto:SwitchToBankAndWipe(ctx)
	if self.kind == const.BAG_KIND.BACKPACK then
		return
	end
	self.behavior:SwitchToBankAndWipe(ctx)
end

---@param ctx Context
function bagFrame.bagProto:OnCooldown(ctx)
	if not self.currentView then
		return
	end
	for _, item in pairs(self.currentView:GetItemsByBagAndSlot()) do
		item:UpdateCooldown(ctx)
	end
end

---@param ctx Context
---@param bagid number
---@param slotid number
function bagFrame.bagProto:OnLock(ctx, bagid, slotid)
	if not self.currentView then
		return
	end
	if slotid == nil then
		return
	end
	local slotkey = items:GetSlotKeyFromBagAndSlot(bagid, slotid)
	local button = self.currentView.itemsByBagAndSlot[slotkey]
	if button then
		button:Lock(ctx)
	end
end

---@param ctx Context
---@param bagid number
---@param slotid number
function bagFrame.bagProto:OnUnlock(ctx, bagid, slotid)
	if not self.currentView then
		return
	end
	if slotid == nil then
		return
	end
	local slotkey = items:GetSlotKeyFromBagAndSlot(bagid, slotid)
	local button = self.currentView.itemsByBagAndSlot[slotkey]
	if button then
		button:Unlock(ctx)
	end
end

function bagFrame.bagProto:UpdateContextMenu()
	self.menuList = contextMenu:CreateContextMenu(self)
end

---@param ctx Context
function bagFrame.bagProto:CreateCategoryForItemInCursor(ctx)
	local kind, itemID, itemLink = GetCursorInfo()
	if not itemLink or kind ~= "item" then
		return
	end
	---@cast itemID number
	question:AskForInput(
		"Create Category",
		format(L:G("What would you like to name the new category for %s?"), itemLink),
		function(input)
			if input == nil then
				return
			end
			if input == "" then
				return
			end
			categories:CreateCategory(ctx, {
				name = input,
				itemList = { [itemID] = true },
				save = true,
			})
			events:SendMessage(ctx, "bags/FullRefreshAll")
		end
	)
	GameTooltip:Hide()
	ClearCursor()
end

-------
--- Bag Frame
-------

--- Create creates a new bag view.
---@param ctx Context
---@param kind BagKind
---@return Bag
function bagFrame:Create(ctx, kind)
	---@class Bag
	local b = {}
	setmetatable(b, { __index = bagFrame.bagProto })
	b.currentItemCount = 0
	b.drawOnClose = false
	b.drawAfterCombat = false
	b.bankTab = Enum.BagIndex.Characterbanktab
	b.sections = {}
	b.toRelease = {}
	b.toReleaseSections = {}
	b.kind = kind
	b.windowGrouping = windowGroup:Create()

	-- Instantiate the appropriate behavior based on bag kind
	if kind == const.BAG_KIND.BACKPACK then
		b.behavior = backpackBehavior:Create(b)
	else
		b.behavior = bankBehavior:Create(b)
	end

	local name = kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"
	-- The main display frame for the bag.
	---@class Frame: BetterBagsBagPortraitTemplate
	local f = CreateFrame("Frame", "BetterBagsBag" .. name, nil)

	-- Register this window with the theme system.
	themes:RegisterPortraitWindow(f, name)

	-- Setup the main frame defaults.
	b.frame = f
	b.sideAnchor = CreateFrame("Frame", f:GetName() .. "LeftAnchor", b.frame)
	b.sideAnchor:SetWidth(1)
	b.sideAnchor:SetPoint("TOPRIGHT", b.frame, "TOPLEFT")
	b.sideAnchor:SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMLEFT")
	f.Owner = b
	b.frame:SetParent(UIParent)
	b.frame:SetToplevel(true)
	b.frame:SetFrameStrata(b.behavior:GetFrameStrata())
	local frameLevel = b.behavior:GetFrameLevel()
	if frameLevel then
		b.frame:SetFrameLevel(frameLevel)
	end
	b.frame:Hide()
	b.frame:SetSize(200, 200)

	-- Attach fade animations (created once, used conditionally based on settings)
	local animations = addon:GetModule('Animations')
	b.fadeInGroup, b.fadeOutGroup = animations:AttachFadeGroup(b.frame)

	--b.frame.Bg:SetAlpha(sizeInfo.opacity / 100)
	--b.frame.CloseButton:SetScript("OnClick", function()
	--  b:Hide()
	--  if b.kind == const.BAG_KIND.BANK then CloseBankFrame() end
	--end)

	b.views = {
		[const.BAG_VIEW.SECTION_GRID] = views:NewGrid(f, b.kind),
		[const.BAG_VIEW.SECTION_ALL_BAGS] = views:NewBagView(f, b.kind),
	}

	-- Register the bag frame so that window positions are saved.
	Window.RegisterConfig(b.frame, database:GetBagPosition(kind))

	-- Create the bottom bar for currency and money display.
	local bottomBar = CreateFrame("Frame", nil, b.frame)
	bottomBar:SetPoint(
		"BOTTOMLEFT",
		b.frame,
		"BOTTOMLEFT",
		const.OFFSETS.BOTTOM_BAR_LEFT_INSET,
		const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET
	)
	bottomBar:SetPoint(
		"BOTTOMRIGHT",
		b.frame,
		"BOTTOMRIGHT",
		const.OFFSETS.BOTTOM_BAR_RIGHT_INSET,
		const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET
	)
	bottomBar:SetHeight(20)
	bottomBar:Show()
	b.bottomBar = bottomBar

	-- Setup money frame via behavior
	b.moneyFrame = b.behavior:SetupMoneyFrame(bottomBar)

	-- Call behavior-specific creation (search, slots, currency, tabs, etc.)
	b.behavior:OnCreate(ctx)

	b.sectionConfigFrame = sectionConfig:Create(kind, b.sideAnchor)
	b.windowGrouping:AddWindow("sectionConfig", b.sectionConfigFrame)

	-- Enable dragging of the bag frame.
	b.frame:SetMovable(true)
	b.frame:EnableMouse(true)
	b.frame:RegisterForDrag("LeftButton")
	b.frame:SetClampedToScreen(true)
	b.frame:SetScript("OnDragStart", function(drag)
		b:KeepBagInBounds()
		drag:StartMoving()
	end)
	b.frame:SetScript("OnDragStop", function(drag)
		drag:StopMovingOrSizing()
		Window.SavePosition(b.frame)
		b.previousSize = b.frame:GetBottom()
		b:OnResize()
	end)

	b.anchor = anchor:New(kind, b.frame, name)
	-- Load the bag position from settings.
	Window.RestorePosition(b.frame)
	b.previousSize = b.frame:GetBottom()

	b.frame:SetScript("OnSizeChanged", function()
		b:OnResize()
	end)

	b.resizeHandle = resize:MakeResizable(b.frame, function()
		local fw, fh = b.frame:GetSize()
		database:SetBagViewFrameSize(b.kind, database:GetBagView(b.kind), fw, fh)
	end)
	b.resizeHandle:Hide()
	b:KeepBagInBounds()

	-- Register behavior-specific events
	b.behavior:RegisterEvents()

	events:RegisterMessage("search/SetInFrame", function(ectx, shown)
		themes:SetSearchState(ectx, b.frame, shown)
	end)

	events:RegisterMessage("bag/RedrawIcons", function(ectx)
		if not b.currentView then
			return
		end
		for _, item in pairs(b.currentView:GetItemsByBagAndSlot()) do
			item:UpdateUpgrade(ectx)
		end
	end)
	-- Setup the context menu.
	b.menuList = contextMenu:CreateContextMenu(b)
	return b
end
