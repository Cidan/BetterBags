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

---@class Items: AceModule
local items = addon:GetModule("Items")

---@class Database: AceModule
local database = addon:GetModule("Database")

---@class ContextMenu: AceModule
local contextMenu = addon:GetModule("ContextMenu")

---@class Views: AceModule
local views = addon:GetModule("Views")

---@class Resize: AceModule
local resize = addon:GetModule("Resize")

---@class Groups: AceModule
local groups = addon:GetModule("Groups")

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

---@class ItemFrame: AceModule
local itemFrame = addon:GetModule("ItemFrame")

---@class SearchBox: AceModule
local searchBox = addon:GetModule("SearchBox")

---@class Search: AceModule
local search = addon:GetModule("Search")

---@class Themes: AceModule
local themes = addon:GetModule("Themes")

---@class WindowGroup: AceModule
local windowGroup = addon:GetModule("WindowGroup")

---@class Anchor: AceModule
local anchor = addon:GetModule("Anchor")

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
---@field currencyFrame CurrencyIconGrid The currency frame.
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
---@field blizzardBankTab number? When set, the bank is filtered to show only items from this specific Blizzard bag index (set by the bank slots panel).
---@field behavior BackpackBehaviorProto|BankBehaviorProto The bag-type-specific behavior
bagFrame.bagProto = {}

---@param ctx Context
function bagFrame.bagProto:Show(ctx)
	if self.frame:IsShown() then
		return
	end
	self.behavior:OnShow(ctx)
	if self.drawPendingOnShow then
		self.drawPendingOnShow = false
		if self.lastSlotInfo then
			self:Draw(ctx, self.lastSlotInfo, function() end)
		end
	end
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
	self:WipeGlobalSections(ctx)
	if self.currentView then
		self.currentView:Wipe(ctx)
	end
end

---@param ctx Context
---@param tabID number
function bagFrame.bagProto:DeleteTabView(ctx, tabID)
	if not self.tabViews then return end
	local layouts = {const.BAG_VIEW.SECTION_GRID, const.BAG_VIEW.SECTION_ALL_BAGS}
	for _, layout in ipairs(layouts) do
		local viewKey = layout .. "_" .. tostring(tabID)
		local view = self.tabViews[viewKey]
		if view then
			view:Wipe(ctx)
			view:GetContent():Wipe()
			self.tabViews[viewKey] = nil
		end
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

function bagFrame.bagProto:GetCurrentTabID()
	if self.kind == const.BAG_KIND.BANK and database:GetShowBankTabs() then
		return self.blizzardBankTab or -1
	end
	if database:GetGroupsEnabled(self.kind) then
		return database:GetActiveGroup(self.kind) or 1
	end
	return 1
end

function bagFrame.bagProto:GetViewForTab(_, tabID)
	local layout = database:GetBagView(self.kind)
	local viewKey = layout .. "_" .. tostring(tabID)
	if not self.tabViews then
		self.tabViews = {}
	end
	if not self.tabViews[viewKey] then
		if layout == const.BAG_VIEW.SECTION_GRID then
			self.tabViews[viewKey] = views:NewGrid(self.tabContainer or self.frame, self.kind, tabID)
		else
			self.tabViews[viewKey] = views:NewBagView(self.tabContainer or self.frame, self.kind, tabID)
		end
	end
	return self.tabViews[viewKey]
end

---@param slotkey string
---@return number, number
function bagFrame.bagProto:ParseSlotKey(slotkey)
	local bagid, slotid = strsplit('_', slotkey)
	return tonumber(bagid), tonumber(slotid)
end

---@param ctx Context
---@param slotkey string
---@return Item
function bagFrame.bagProto:GetOrCreateGlobalItemButton(ctx, slotkey)
	self.itemFrames = self.itemFrames or {}
	local item = itemFrame:GetButton(ctx, slotkey)
	tinsert(self.itemFrames, item)
	return item
end

---@param ctx Context
function bagFrame.bagProto:WipeGlobalSections(ctx)
	if self.itemFrames then
		for _, item in pairs(self.itemFrames) do
			item:Release(ctx)
		end
		wipe(self.itemFrames)
	end
	if self.freeSlot then
		self.freeSlot:Release(ctx)
		self.freeSlot = nil
	end
	if self.freeReagentSlot then
		self.freeReagentSlot:Release(ctx)
		self.freeReagentSlot = nil
	end
	if self.globalSections then
		local k, section = next(self.globalSections)
		while k do
			self.globalSections[k] = nil
			section:ReleaseAllCells(ctx)
			section:Release(ctx)
			k, section = next(self.globalSections)
		end
	end
end

function bagFrame.bagProto:ShowScrollBar()
	if not self.scrollBar then return end
	self.scrollBar:SetAttribute("nodeignore", false)
	self.scrollBar:SetAlpha(1)
	self.scrollBar:Show()
end

function bagFrame.bagProto:HideScrollBar()
	if not self.scrollBar then return end
	self.scrollBar:Hide()
	self.scrollBar:SetAlpha(0)
	self.scrollBar:SetAttribute("nodeignore", true)
end

---@param w number
---@param h number
function bagFrame.bagProto:UpdateBagBounds(w, h)
	-- Set size and scrollbars
	if w < 260 then w = 260 end
	if self.tabs and w < self.tabs.width then
		w = self.tabs.width
	end
	if self.slots and self.slots:IsShown() then
		local minW = self.slots.frame:GetWidth()
			- const.OFFSETS.BAG_LEFT_INSET
			+ const.OFFSETS.BAG_RIGHT_INSET
			- const.OFFSETS.SCROLLBAR_WIDTH
		if w < minW then
			w = minW
		end
	end
	if h < 100 then h = 100 end
	if database:GetInBagSearch() then
		h = h + 20
	end

	local bagHeight = h +
		const.OFFSETS.BAG_BOTTOM_INSET + -const.OFFSETS.BAG_TOP_INSET +
		const.OFFSETS.BOTTOM_BAR_HEIGHT + const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET

	local maxHeight = UIParent:GetHeight() * 0.90
	local bagWidth = w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET + const.OFFSETS.SCROLLBAR_WIDTH
	if bagHeight > maxHeight then
		bagHeight = maxHeight
		self:ShowScrollBar()
	else
		self:HideScrollBar()
	end

	self.frame:SetWidth(bagWidth)
	self.frame:SetHeight(bagHeight)

	if self.scrollBox then
		if database:GetInBagSearch() then
			self.scrollBox:SetPoint("TOPLEFT", self.frame, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET, const.OFFSETS.BAG_TOP_INSET - 20)
		else
			self.scrollBox:SetPoint("TOPLEFT", self.frame, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET, const.OFFSETS.BAG_TOP_INSET)
		end
	end
end

---@param ctx Context
---@param slotInfo SlotInfo
---@return number headerW, number headerH, number footerW, number footerH
function bagFrame.bagProto:DrawGlobalSections(ctx, slotInfo)
	self:WipeGlobalSections(ctx)

	if not self.headerContainer then
		return 0, 0, 0, 0
	end

	local currentView = database:GetBagView(self.kind)
	local sizeInfo = database:GetBagSizeInfo(self.kind, currentView)

	-- 1. Scan and draw Recent Items inside self.headerContainer
	local recentItems = {}
	if currentView ~= const.BAG_VIEW.SECTION_ALL_BAGS then
		local itemsGetter = slotInfo.GetVisibleItems or slotInfo.GetCurrentItems
		for _, item in pairs(itemsGetter(slotInfo)) do
			if not item.isItemEmpty and item.itemInfo and item.itemInfo.category == L:G("Recent Items") then
				table.insert(recentItems, item)
			end
		end
	end

	local headerW, headerH = 0, 0
	if #recentItems > 0 then
		local sectionFrame = addon:GetModule("SectionFrame")
		local recentSection = sectionFrame:Create(ctx)
		recentSection.frame:SetParent(self.headerContainer)
		recentSection.frame:ClearAllPoints()
		recentSection.frame:SetPoint("TOPLEFT", self.headerContainer, "TOPLEFT", 0, 0)
		recentSection:SetTitle(L:G("Recent Items"))
		self.globalSections[L:G("Recent Items")] = recentSection

		recentSection:SetMaxCellWidth(sizeInfo.itemsPerRow * sizeInfo.columnCount)

		for _, item in ipairs(recentItems) do
			local itemButton = self:GetOrCreateGlobalItemButton(ctx, item.slotkey)
			if itemButton.SetItemFromData then
				itemButton:SetItemFromData(ctx, item)
			else
				itemButton.staticData = item
				itemButton:SetItem(ctx, item.slotkey)
			end
			recentSection:AddCell(item.slotkey, itemButton)
		end
		headerW, headerH = recentSection:Draw(self.kind, currentView, false)
	end
	self.headerContainer:SetHeight(math.max(1, headerH))

	-- 2. Scan and draw Free Space inside self.footerContainer (except SECTION_ALL_BAGS mode)
	local footerW, footerH = 0, 0
	if currentView ~= const.BAG_VIEW.SECTION_ALL_BAGS then
		local function IncludeBagInFreeSpace(bagid)
			if self.kind == const.BAG_KIND.BACKPACK then
				return const.BACKPACK_BAGS[bagid] ~= nil
			end
			local tabID = self:GetCurrentTabID()
			if database:GetShowBankTabs() then
				if addon.isRetail then
					if tabID == const.BANK_TAB.BANK then
						return const.ACCOUNT_BANK_BAGS == nil or const.ACCOUNT_BANK_BAGS[bagid] == nil
					else
						return bagid == tabID
					end
				else
					return const.BANK_BAGS[bagid] ~= nil or bagid == -1
				end
			end
			if database:GetGroupsEnabled(const.BAG_KIND.BANK) and addon.isRetail then
				local activeGroup = groups:GetGroup(const.BAG_KIND.BANK, tabID)
				if activeGroup then
					local itemIsAccountBank = (const.ACCOUNT_BANK_BAGS and const.ACCOUNT_BANK_BAGS[bagid] ~= nil) or false
					local tabIsAccountBank = (Enum.BankType and activeGroup.bankType == Enum.BankType.Account) or false
					return itemIsAccountBank == tabIsAccountBank
				end
			end
			return const.ACCOUNT_BANK_BAGS == nil or const.ACCOUNT_BANK_BAGS[bagid] == nil
		end

		local sectionFrame = addon:GetModule("SectionFrame")
		local freeSlotsSection = sectionFrame:Create(ctx)
		freeSlotsSection.frame:SetParent(self.footerContainer)
		freeSlotsSection.frame:ClearAllPoints()
		freeSlotsSection.frame:SetPoint("TOPLEFT", self.footerContainer, "TOPLEFT", 0, 0)
		freeSlotsSection:SetTitle(L:G("Free Space"))
		self.globalSections[L:G("Free Space")] = freeSlotsSection

		if database:GetShowAllFreeSpace(self.kind) then
			freeSlotsSection:SetMaxCellWidth(sizeInfo.itemsPerRow * sizeInfo.columnCount)
			for _, item in ipairs(slotInfo.emptySlotsSorted) do
				if IncludeBagInFreeSpace(item.bagid) then
					local itemButton = self:GetOrCreateGlobalItemButton(ctx, item.slotkey)
					itemButton:SetFreeSlots(ctx, item.bagid, item.slotid, 1, true)
					freeSlotsSection:AddCell(item.slotkey, itemButton)
				end
			end
			footerW, footerH = freeSlotsSection:Draw(self.kind, currentView, true, true)
		else
			freeSlotsSection:SetMaxCellWidth(sizeInfo.itemsPerRow)
			local aggregatedCounts = {}
			local firstSlotKeyForSubclass = {}
			if slotInfo.emptySlotsByBag then
				for bagid, info in pairs(slotInfo.emptySlotsByBag) do
					if IncludeBagInFreeSpace(bagid) then
						aggregatedCounts[info.name] = (aggregatedCounts[info.name] or 0) + info.count
						if not firstSlotKeyForSubclass[info.name] and slotInfo.freeSlotKeysByBag and slotInfo.freeSlotKeysByBag[bagid] then
							firstSlotKeyForSubclass[info.name] = slotInfo.freeSlotKeysByBag[bagid]
						end
					end
				end
			end
			for name, freeSlotCount in pairs(aggregatedCounts) do
				local slotKey = firstSlotKeyForSubclass[name]
				if freeSlotCount > 0 and slotKey ~= nil then
					local itemButton = self:GetOrCreateGlobalItemButton(ctx, slotKey)
					local freeSlotBag, freeSlotID = self:ParseSlotKey(slotKey)
					itemButton:SetFreeSlots(ctx, freeSlotBag, freeSlotID, freeSlotCount)
					freeSlotsSection:AddCell(name, itemButton)
				end
			end
			footerW, footerH = freeSlotsSection:Draw(self.kind, currentView, false)
		end
	end
	self.footerContainer:SetHeight(math.max(1, footerH))

	return headerW, headerH, footerW, footerH
end

-- Draw will draw the correct bag view based on the bag view configuration.
---@param ctx Context
---@param slotInfo SlotInfo
---@param callback fun()
function bagFrame.bagProto:Draw(ctx, slotInfo, callback)
	if not self:IsShown() then
		self.lastSlotInfo = slotInfo
		self.drawPendingOnShow = true
		if callback then
			callback()
		end
		return
	end
	local tabID = self:GetCurrentTabID()
	local view = self:GetViewForTab(ctx, tabID)

	if view == nil then
		assert(view, "No view found for bag view: " .. database:GetBagView(self.kind))
		return
	end

	if ctx:GetBool("tab_switch") and not view.isNew then
		if self.currentView and self.currentView ~= view then
			self.currentView:GetContent():Hide()
		end
		view:GetContent():Show()
		self.currentView = view

		local totalW = 0
		local totalH = 0
		if self.tabContainer then
			local headerW, headerH = 0, 0
			if self.globalSections and self.globalSections[L:G("Recent Items")] then
				headerW, headerH = self.globalSections[L:G("Recent Items")].frame:GetSize()
			end
			local footerW, footerH = 0, 0
			if self.globalSections and self.globalSections[L:G("Free Space")] then
				footerW, footerH = self.globalSections[L:G("Free Space")].frame:GetSize()
			end

			local tabW, tabH = view.content.contentWidth or 0, view.content.contentHeight or 0
			self.tabContainer:SetHeight(math.max(1, tabH))
			self.tabContainer:SetWidth(math.max(1, tabW))

			totalW = math.max(headerW, tabW, footerW)
			totalH = headerH + tabH + footerH
			if self.scrollChild then
				self.scrollChild:SetSize(math.max(1, totalW), math.max(1, totalH))
			end
		end

		self:UpdateBagBounds(totalW, totalH)

		if self.scrollBox and self.scrollBox.FullUpdate then
			self.scrollBox:FullUpdate(true)
		end

		self.frame:SetScale(database:GetBagSizeInfo(self.kind, database:GetBagView(self.kind)).scale / 100)
		local text = searchBox:GetText()
		if text ~= "" and text ~= nil then
			self:Search(ctx, search:Search(text))
		end
		self:OnResize()
		if callback then
			callback()
		end
		return
	end

	if self.currentView and self.currentView ~= view then
		self.currentView:GetContent():Hide()
	end

	-- Render other background persistent views first to keep them in a consistent data state
	local currentLayout = database:GetBagView(self.kind)
	if not ctx:GetBool("tab_switch") and self.tabViews then
		for viewKey, tView in pairs(self.tabViews) do
			local layoutStr, tabIDStr = string.split("_", viewKey)
			local layout = tonumber(layoutStr)
			local tTabID = tonumber(tabIDStr)
			if layout == currentLayout and tTabID ~= tabID then
				tView:Render(ctx, self, slotInfo, function() end)
				tView:GetContent():Hide()
			end
		end
	end

	local headerW, headerH, footerW, footerH = self:DrawGlobalSections(ctx, slotInfo)

	debug:StartProfile("Bag Render %d", self.kind)
	view:Render(ctx, self, slotInfo, function()
		debug:EndProfile("Bag Render %d", self.kind)
		view:GetContent():Show()
		self.currentView = view

		local tabW, tabH = view.content.contentWidth or 0, view.content.contentHeight or 0
		local totalW = tabW
		local totalH = tabH
		if self.tabContainer then
			self.tabContainer:SetHeight(math.max(1, tabH))
			self.tabContainer:SetWidth(math.max(1, tabW))

			totalW = math.max(headerW, tabW, footerW)
			totalH = headerH + tabH + footerH
			if self.scrollChild then
				self.scrollChild:SetSize(math.max(1, totalW), math.max(1, totalH))
			end
		end

		self:UpdateBagBounds(totalW, totalH)

		if self.scrollBox and self.scrollBox.FullUpdate then
			self.scrollBox:FullUpdate(true)
		end

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
	if self.previousSize and self.loaded then
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

	b.tabViews = {}
	b.itemFrames = {}
	b.globalSections = {}

	-- Create the single global scrollBox and scrollBar
	local scrollBox = CreateFrame("Frame", "BetterBagsBagScroll" .. name, b.frame, "WowScrollBox")
	scrollBox:SetInterpolateScroll(true)
	local scrollBar = CreateFrame("EventFrame", nil, scrollBox, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", -12, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", -12, 0)
	scrollBar:SetInterpolateScroll(true)
	scrollBar:SetHideIfUnscrollable(true)

	local scrollChild = CreateFrame("Frame", nil, scrollBox)
	scrollChild:SetPoint("TOPLEFT", scrollBox, "TOPLEFT")
	scrollChild:SetPoint("TOPRIGHT", scrollBox, "TOPRIGHT")
	scrollChild:SetSize(200, 200)

	local scrollView = CreateScrollBoxLinearView()
	scrollView:SetPanExtent(100)
	scrollChild:SetParent(scrollBox)
	scrollChild.scrollable = true
	ScrollUtil.InitScrollBoxWithScrollBar(scrollBox, scrollBar, scrollView)

	b.scrollBox = scrollBox
	b.scrollBar = scrollBar
	b.scrollChild = scrollChild
	b.scrollView = scrollView

	-- Create headerContainer, tabContainer, and footerContainer inside scrollChild
	local headerContainer = CreateFrame("Frame", nil, scrollChild)
	headerContainer:SetPoint("TOPLEFT", scrollChild, "TOPLEFT")
	headerContainer:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT")
	headerContainer:SetHeight(1)

	local tabContainer = CreateFrame("Frame", nil, scrollChild)
	tabContainer:SetPoint("TOPLEFT", headerContainer, "BOTTOMLEFT", 0, 0)
	tabContainer:SetPoint("TOPRIGHT", headerContainer, "BOTTOMRIGHT", 0, 0)
	tabContainer:SetHeight(1)

	local footerContainer = CreateFrame("Frame", nil, scrollChild)
	footerContainer:SetPoint("TOPLEFT", tabContainer, "BOTTOMLEFT", 0, 0)
	footerContainer:SetPoint("TOPRIGHT", tabContainer, "BOTTOMRIGHT", 0, 0)
	footerContainer:SetHeight(1)

	b.headerContainer = headerContainer
	b.tabContainer = tabContainer
	b.footerContainer = footerContainer

	b.scrollBox:SetPoint("TOPLEFT", b.frame, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET, const.OFFSETS.BAG_TOP_INSET)
	b.scrollBox:SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMRIGHT", const.OFFSETS.BAG_RIGHT_INSET, const.OFFSETS.BAG_BOTTOM_INSET + const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET + 20)

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

	events:RegisterMessage("groups/Deleted", function(ectx, groupID, _, groupKind)
		if groupKind == b.kind then
			b:DeleteTabView(ectx, groupID)
		end
	end)
	-- Setup the context menu.
	b.menuList = contextMenu:CreateContextMenu(b)
	return b
end
