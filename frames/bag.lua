---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)

---@class BagFrame: AceModule
local bagFrame = addon:NewModule("BagFrame")

---@class Localization: AceModule
local L = addon:GetModule("Localization")

---@class Sonata: AceModule
local sonata = addon:GetModule("Sonata")

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

---@class Events: AceModule
local events = addon:GetModule("Events")

---@class Question: AceModule
local question = addon:GetModule("Question")

---@class Categories: AceModule
local categories = addon:GetModule("Categories")

---@class ItemFrame: AceModule
local itemFrame = addon:GetModule("ItemFrame")

---@class Render: AceModule
local render = addon:GetModule("Render")

---@class Texels: AceModule
local texels = addon:GetModule("Texels")

---@class WindowModule: AceModule
local windowModule = addon:GetModule("Window")

---@class Scrollbox: AceModule
local scrollbox = addon:GetModule("Scrollbox")

---@class BagCanvas: AceModule
local bagCanvas = addon:GetModule("BagCanvas")

---@class BagMenuButton: AceModule
local menuButton = addon:GetModule("BagMenuButton")

---@class BagActions: AceModule
local bagActions = addon:GetModule("BagActions")

---@class SearchBox: AceModule
local searchBox = addon:GetModule("SearchBox")

---@class Anchor: AceModule
local anchor = addon:GetModule("Anchor")

---@class BackpackBehavior: AceModule
local backpackBehavior = addon:GetModule("BackpackBehavior")

---@class BankBehavior: AceModule
local bankBehavior = addon:GetModule("BankBehavior")

---@class CursorPlacement: AceModule
local cursorPlacement = addon:GetModule("CursorPlacement")

-- The smallest content a bag window shows: the old fixed minimum of the bag's content box.
local MIN_CONTENT_WIDTH = 260

-- The bag's scroll box keeps the bar's room on both sides, so the content stays centered and still
-- when the bar shows, and its bar shows only while it is used (window.md, centering).
local SCROLL_OPTIONS = { Symmetric = true, AutoHideBar = true }
local MIN_CONTENT_HEIGHT = 100

-------
--- Bag Prototype
-------

--- Bag is a view of a single bag object. Note that this is not
--- a single bag slot, but a combined view of all bags for a given
--- kind (i.e. bank, backpack).
---@class (exact) Bag
---@field kind BagKind
---@field currentView View
---@field frame Frame The bag window's frame.
---@field window BetterBagsWindow The bag's window: its frame, chrome, layout, moving and resizing.
---@field scroll ScrollboxDrawable The scroll box the bag's content scrolls in.
---@field canvas BagCanvasDrawable The bag's content: Recent Items, the active view, Free Space.
---@field searchBox SearchFrame The in-bag search box.
---@field appliedView? BagView The view whose size mode the window last took.
---@field appliedSizeMode? WindowSizeMode
---@field menuButton BagButton The menu button at the window's top left.
---@field actions BagActionSet The action buttons a theme gives the window (Layout.Actions).
---@field headerContainer Frame
---@field tabContainer Frame
---@field footerContainer Frame
---@field scrollBox WowScrollBox
---@field anchor AnchorFrame The anchor frame for the bag.
---@field bottomBar Frame The bottom bar of the bag.
---@field recentItems Section The recent items section.
---@field currencyFrame CurrencyIconGrid The currency frame.
---@field currentItemCount number
---@field private sections table<string, Section>
---@field slots bagSlots
---@field decorator Texture
---@field bg Texture
---@field moneyFrame Money
---@field drawOnClose boolean
---@field drawAfterCombat boolean
---@field menuList MenuList[]
---@field toRelease Item[]
---@field toReleaseSections Section[]
---@field views table<BagView, View>
---@field loaded boolean
---@field keptLeft? number Where a bag sized to its content is kept, its bottom left in its own units (OnResize): nil until it has drawn what it holds.
---@field keptBottom? number
---@field bankOpening? boolean The bank's tabs are still reading in on this visit: its saved position decides where it is (OnBankOpening).
---@field searchFrame SearchFrame
---@field tabs Tab
---@field bankTab BankTab
---@field blizzardBankTab number? When set, the bank is filtered to show only items from this specific Blizzard bag index (set by the bank slots panel).
---@field purchaseBankButton Button? Retail bank: shown in the middle of the bank while the character owns no character bank tab.
---@field loadingText FontString Loading..., in the middle of the bag while what it shows has never been read.
---@field loading boolean What the bag shows has never been read.
---@field behavior BackpackBehaviorProto|BankBehaviorProto The bag-type-specific behavior
bagFrame.bagProto = {}
addon:GetModule('Perf'):RegisterPrototype(bagFrame.bagProto, 'Bag')

-- Show shows the bag and draws a draw deferred while it was hidden, with slotInfo when
-- given (the caller's current data; the deferred one can be an older object: the bank's is
-- replaced when its cache is cleared). It returns whether it drew, so a caller about to draw
-- the same data does not draw it twice. onShown runs once the window has finished showing (at
-- once without a fade, when a fade still playing ends; never for a fade cut short), which is
-- when a bank open loads the bank (refresh-scheduler.md §11).
---@param ctx Context
---@param slotInfo? SlotInfo
---@param onShown? fun()
---@return boolean drew
function bagFrame.bagProto:Show(ctx, slotInfo, onShown)
	if self.window:IsShown() and not self.window:IsClosing() then
		if onShown ~= nil then
			self.window:Show(ctx, onShown)
		end
		return false
	end
	self.behavior:OnShow(ctx, onShown)
	if self.drawPendingOnShow then
		self.drawPendingOnShow = false
		local data = slotInfo or self.lastSlotInfo
		if data then
			self:Draw(ctx, data, function() end)
			return true
		end
	end
	return false
end

---@param ctx Context
function bagFrame.bagProto:Hide(ctx)
	if not self.window:IsShown() or self.window:IsClosing() then
		return
	end
	self.behavior:OnHide(ctx)
end

-- OnClosed runs when the bag has closed. Recent Items expire only here, so nothing leaves
-- that section while the bag is open, and the one refresh that applies the expiry and
-- collapses held gaps runs while the bag is hidden.
---@param ctx Context
function bagFrame.bagProto:OnClosed(ctx)
	-- OnHide also fires when only a parent hid (Alt+Z hides UIParent); the bag is still open.
	if self.frame:IsShown() then
		return
	end
	local expired = items:ExpireRecentItems(self.kind)
	if expired or self.drawOnClose then
		self.drawOnClose = false
		self:Refresh(ctx)
	end
end

-- Deactivate switches the bag off with the classic design (next.md §11): it hides at once (its
-- OnHide still runs its close work), lets go of every button it drew, and hides its overlay search
-- and its anchor's frame, keeping the anchor's saved state.
---@param ctx Context
function bagFrame.bagProto:Deactivate(ctx)
	if self.frame:IsShown() then
		self.frame:Hide()
	end
	self:Wipe(ctx)
	if self.searchFrame then
		self.searchFrame:Hide(ctx)
	end
	if self.anchor then
		self.anchor.frame:Hide()
	end
end

-- Activate catches the bag up when the classic design is switched back on: what its handlers would
-- have done while they were off (the search box's setting, its behavior's tabs and buttons, the
-- money, the currencies, the slots panel), and its anchor as saved.
---@param ctx Context
function bagFrame.bagProto:Activate(ctx)
	self:UpdateSearchShown()
	self.behavior:Resync(ctx)
	if self.moneyFrame then
		self.moneyFrame:Update()
	end
	if self.currencyIconGrid then
		self.currencyIconGrid:Update()
	end
	if self.slots then
		self.slots:Draw(ctx)
	end
	if self.anchor then
		self.anchor:Load()
	end
end

-- WatchForClose runs OnClosed from the frame's own OnHide, which every way of closing the
-- bag fires: the toggle, the close button, ESC (UISpecialFrames hides the frame directly,
-- skipping behavior:OnHide) and the end of the fade-out.
function bagFrame.bagProto:WatchForClose()
	addon.HookScript(self.frame, "OnHide", function(ctx)
		self:OnClosed(ctx)
	end)
end

-- WatchMouse makes the window a drop target: an item dropped anywhere on it, or a left click
-- on it while holding one, goes into a free slot of its bags (issue #408). Item buttons,
-- section titles and the bag button take their own drops first. The window moves the bag
-- when dragged (BuildWindow), except while an item is on the cursor: then pressing on the
-- window is a drop and never moves it.
function bagFrame.bagProto:WatchMouse()
	addon.SetScript(self.frame, "OnReceiveDrag", function()
		self:PlaceCursorItem()
	end)
	addon.SetScript(self.frame, "OnMouseUp", function(_, _, button)
		if button == "LeftButton" then
			self:PlaceCursorItem()
		end
	end)
end

-- PlaceCursorItem puts the item on the cursor into a free slot of this window's bags.
---@return string result What CursorPlacement:PlaceCursorItem did.
function bagFrame.bagProto:PlaceCursorItem()
	return cursorPlacement:PlaceCursorItem(self.kind, self.bankTab)
end

---@param ctx Context
function bagFrame.bagProto:Toggle(ctx)
	if self.window:IsShown() and not self.window:IsClosing() then
		self:Hide(ctx)
	else
		self:Show(ctx)
	end
end

function bagFrame.bagProto:IsShown()
	return self.frame:IsShown()
end

-- IsClosing says the bag is fading out: closed, though its frame still shows.
---@return boolean
function bagFrame.bagProto:IsClosing()
	return self.window:IsClosing()
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
	if self.kind == const.BAG_KIND.BANK then
		if addon.isRetail and self.bankTab and Enum and Enum.BagIndex and Enum.BagIndex.AccountBankTab_1 and self.bankTab >= Enum.BagIndex.AccountBankTab_1 then
			events:SendMessage(ctx, "bags/SortWarbank")
		else
			events:SendMessage(ctx, "bags/SortBank")
		end
	else
		events:SendMessage(ctx, "bags/SortBackpack")
	end
end

-- Wipe tears the bag's drawing down: every view and global section and every item button
-- the last passes drew (including a pass that failed before its sweep) is released.
---@param ctx Context
function bagFrame.bagProto:Wipe(ctx)
	self:WipeGlobalSections(ctx)
	for _, tView in pairs(self.tabViews or {}) do
		tView:Wipe(ctx)
	end
	for _, drawn in ipairs({ self.drawnButtons or {}, self.claims or {} }) do
		for item in pairs(drawn) do
			item:Release(ctx)
		end
	end
	self.drawnButtons = {}
	self.claims = nil
	self.loading = true
	self:UpdateLoadingText()
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

-- Refresh recalculates this bag's items from what was last read, and redraws the bag.
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
	if self.claims then
		self.claims[item] = true
	end
	return item
end

-- BeginGlobalSections starts the global sections' part of a draw pass. Last pass's
-- Recent Items and Free Space sections are set aside for reuse; nothing is released.
function bagFrame.bagProto:BeginGlobalSections()
	if self.staleGlobalSections then return end
	self.staleGlobalSections = self.globalSections or {}
	self.globalSections = {}
	if self.itemFrames then
		wipe(self.itemFrames)
	end
end

-- GetOrCreateGlobalSection returns the named global section for this pass, reusing last
-- pass's section of the same name.
---@param ctx Context
---@param name string
---@return Section
function bagFrame.bagProto:GetOrCreateGlobalSection(ctx, name)
	local section = self.staleGlobalSections and self.staleGlobalSections[name]
	if section then
		self.staleGlobalSections[name] = nil
		section:PrepareForReuse()
	else
		section = addon:GetModule("SectionFrame"):Create(ctx)
	end
	self.globalSections[name] = section
	return section
end

-- FinishGlobalSections releases the global sections this pass did not draw again. Their
-- item buttons are left to the draw pass sweep.
---@param ctx Context
function bagFrame.bagProto:FinishGlobalSections(ctx)
	local stale = self.staleGlobalSections
	self.staleGlobalSections = nil
	for _, section in pairs(stale or {}) do
		section:Release(ctx)
	end
end

-- WipeGlobalSections tears the global sections down outside a draw pass: every section
-- and every item button they drew is released.
---@param ctx Context
function bagFrame.bagProto:WipeGlobalSections(ctx)
	self:FinishGlobalSections(ctx)
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

-- BindGlobalSections puts this pass's Recent Items and Free Space data into the global
-- sections (the header and footer of the bag, outside the tab views) and ends their part of
-- the pass. The canvas measures and arranges them (MeasureGlobalSections, ArrangeGlobalSections).
---@param ctx Context
---@param slotInfo SlotInfo
function bagFrame.bagProto:BindGlobalSections(ctx, slotInfo)
	self:BeginGlobalSections()
	self.recentSection = nil
	self.freeSpaceSection = nil
	self.freeSpaceShowAll = false

	if not self.headerContainer then
		return
	end

	local currentView = database:GetBagView(self.kind)

	-- Recent Items follows the ordered, gap-carrying layout the data pipeline committed
	-- (slotInfo.sortedItems from BuildOrderedItems), never a pairs() scan of the visible items:
	-- that is the stable order, and the only place gaps for consumed items live.
	local recentItems = {}
	if currentView ~= const.BAG_VIEW.SECTION_ALL_BAGS then
		if slotInfo.sortedItems then
			for _, item in ipairs(slotInfo.sortedItems) do
				if item.itemInfo and item.itemInfo.category == L:G("Recent Items") then
					table.insert(recentItems, item)
				end
			end
		else
			local itemsGetter = slotInfo.GetVisibleItems or slotInfo.GetCurrentItems
			for _, item in pairs(itemsGetter(slotInfo)) do
				if not item.isItemEmpty and item.itemInfo and item.itemInfo.category == L:G("Recent Items") then
					table.insert(recentItems, item)
				end
			end
		end
	end

	if #recentItems > 0 then
		local recentSection = self:GetOrCreateGlobalSection(ctx, L:G("Recent Items"))
		recentSection.frame:SetParent(self.headerContainer)
		recentSection.frame:ClearAllPoints()
		recentSection.frame:SetPoint("TOPLEFT", self.headerContainer, "TOPLEFT", 0, 0)
		recentSection:SetTitle(L:G("Recent Items"))
		for _, item in ipairs(recentItems) do
			if item.isItemGap then
				recentSection:AddCell(item.slotkey, { isGap = true, width = 37, height = 37 })
			else
				local itemButton = self:GetOrCreateGlobalItemButton(ctx, item.slotkey)
				itemButton:SetItemFromData(ctx, item)
				recentSection:AddCell(item.slotkey, itemButton)
			end
		end
		self.recentSection = recentSection
	end

	-- Free Space only when this tab's data carries it: the data phase leaves it out of a tab
	-- with no free slots.
	local tabID = self:GetCurrentTabID()
	local tabData = slotInfo.tabs and slotInfo.tabs[tabID] or slotInfo
	local freeSpaceData = tabData.freeSpace
	if currentView ~= const.BAG_VIEW.SECTION_ALL_BAGS and freeSpaceData then
		local freeSlotsSection = self:GetOrCreateGlobalSection(ctx, L:G("Free Space"))
		freeSlotsSection.frame:SetParent(self.footerContainer)
		freeSlotsSection.frame:ClearAllPoints()
		freeSlotsSection.frame:SetPoint("TOPLEFT", self.footerContainer, "TOPLEFT", 0, 0)
		freeSlotsSection:SetTitle(L:G("Free Space"))
		if freeSpaceData.showAll then
			for _, btn in ipairs(freeSpaceData.buttons) do
				local itemButton = self:GetOrCreateGlobalItemButton(ctx, btn.slotkey)
				itemButton:SetFreeSlots(ctx, btn, 1, true)
				freeSlotsSection:AddCell(btn.slotkey, itemButton)
			end
		else
			for _, btn in ipairs(freeSpaceData.buttons) do
				local itemButton = self:GetOrCreateGlobalItemButton(ctx, btn.slotkey)
				itemButton:SetFreeSlots(ctx, btn, btn.count)
				freeSlotsSection:AddCell(btn.key, itemButton)
			end
		end
		self.freeSpaceSection = freeSlotsSection
		self.freeSpaceShowAll = freeSpaceData.showAll == true
	end

	self:FinishGlobalSections(ctx)
end

---@class (exact) GlobalLayoutSection
---@field section Section
---@field spansColumns boolean It takes the items per row of every column.
---@field place "header"|"footer"

-- GetGlobalLayoutSections lists the global sections the draw bound: Recent Items above the view,
-- spanning every column, and Free Space below it, one section wide, or spanning every column when
-- it shows every free slot.
---@return GlobalLayoutSection[]
function bagFrame.bagProto:GetGlobalLayoutSections()
	local listed = {}
	if self.recentSection then
		table.insert(listed, { section = self.recentSection, spansColumns = true, place = "header" })
	end
	if self.freeSpaceSection then
		table.insert(listed, { section = self.freeSpaceSection, spansColumns = self.freeSpaceShowAll == true, place = "footer" })
	end
	return listed
end

-- MeasureGlobalSections measures the global sections for a layout of itemsPerRow in columns,
-- moving nothing (by measureSection when given: the canvas caches measures across layouts).
---@param itemsPerRow number
---@param columns number
---@param measureSection? SectionMeasurer
---@return {header?: SectionMeasure, footer?: SectionMeasure}
function bagFrame.bagProto:MeasureGlobalSections(itemsPerRow, columns, measureSection)
	local measured = {}
	for _, global in ipairs(self:GetGlobalLayoutSections()) do
		local perRow = global.spansColumns and itemsPerRow * columns or itemsPerRow
		if measureSection ~= nil then
			measured[global.place] = measureSection(global.section, perRow)
		else
			measured[global.place] = global.section:Measure(self.kind, perRow)
		end
	end
	return measured
end

-- ArrangeGlobalSections applies a measure of the global sections and sizes the header and footer
-- containers to them.
---@param measured {header?: SectionMeasure, footer?: SectionMeasure}
---@return number headerW, number headerH, number footerW, number footerH
function bagFrame.bagProto:ArrangeGlobalSections(measured)
	local headerW, headerH, footerW, footerH = 0, 0, 0, 0
	if self.recentSection and measured.header then
		headerW, headerH = self.recentSection:Arrange(self.kind, measured.header)
	end
	if self.headerContainer then
		self.headerContainer:SetHeight(math.max(1, headerH))
	end
	if self.freeSpaceSection and measured.footer then
		footerW, footerH = self.freeSpaceSection:Arrange(self.kind, measured.footer)
	end
	if self.footerContainer then
		self.footerContainer:SetHeight(math.max(1, footerH))
	end
	return headerW, headerH, footerW, footerH
end

-- FinishDrawPass ends a draw pass once every renderer has run: views release the
-- sections they did not draw again (every section of a view that was not rendered), and
-- the item buttons the previous pass drew that no renderer claimed this pass are
-- released.
---@param ctx Context
---@param claims table<Item, boolean>
function bagFrame.bagProto:FinishDrawPass(ctx, claims)
	for _, tView in pairs(self.tabViews or {}) do
		tView:FinishRender(ctx)
	end
	self:FinishGlobalSections(ctx)
	for item in pairs(self.drawnButtons or {}) do
		if not claims[item] then
			item:Release(ctx)
		end
	end
	self.drawnButtons = claims
	self.claims = nil
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
	self:ShowHiddenCount(slotInfo, tabID)

	if self.currentView and self.currentView ~= view then
		self.currentView:GetContent():Hide()
	end

	-- Every physical slot has exactly one static item button, shared by the global
	-- Recent Items / Free Space sections and by every tab view. A draw pass claims, then
	-- sweeps: nothing is released up front, every renderer claims the buttons it draws and
	-- reuses last pass's section for each category it draws again, and once every
	-- renderer has run, the buttons the previous pass drew that nobody claimed are
	-- released (FinishDrawPass). A button drawn in consecutive passes is therefore never
	-- hidden or unparented, which would run the item button template's OnHide/OnShow
	-- handlers on every redraw. Only the active tab is rendered; a tab is rendered when it
	-- is switched to.
	if self.claims then
		-- The previous pass failed before its sweep: what it claimed is on screen.
		self.drawnButtons = self.drawnButtons or {}
		for item in pairs(self.claims) do
			self.drawnButtons[item] = true
		end
	end
	local claims = {}
	self.claims = claims
	self:FinishGlobalSections(ctx)
	self:BeginGlobalSections()
	for _, tView in pairs(self.tabViews or {}) do
		tView:FinishRender(ctx)
		tView:BeginRender(ctx, claims)
	end

	self:BindGlobalSections(ctx, slotInfo)
	view:Bind(ctx, self, slotInfo)
	self:FinishDrawPass(ctx, claims)
	view:GetContent():Show()
	self.currentView = view

	self.lastSlotInfo = slotInfo
	-- Data with no tabs has never been read (the bank's after it closed, until its open's read).
	self.loading = slotInfo.tabs == nil
	self:UpdateLoadingText()
	self:ApplySizeSettings()

	-- The window lays the bound sections out (the canvas, frames/bagcanvas.lua) and sizes
	-- itself, now, so the draw is complete when Draw returns. The sections hold new data: the
	-- canvas measures them again.
	self.canvas:ForgetMeasures()
	render:RenderNow(self.window, { ctx = ctx })
	-- Its window, sections and theme art; each item button draws its own (texture-sharpening.md).
	texels:Unsharpen(self.frame)

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
end

-- OnResize runs after every render of the bag's window (window.md §3c). A bag the player sized
-- stays where the player put it, and a bag with its anchor on follows it. Any other bag is sized to
-- its content: until it has drawn what it holds, its saved position decides where it is, so it
-- opens where it was dropped; from then on it keeps that bottom left (it grows upward), and its own
-- growth never takes it off the screen. Only a player's drag can (Window:Fit).
function bagFrame.bagProto:OnResize()
	if self.window:GetSizeMode() == "window" then
		return
	end
	if self.anchor and self.anchor:IsActive() then
		self.frame:ClearAllPoints()
		self.frame:SetPoint(self.anchor.anchorPoint, self.anchor.frame, self.anchor.anchorPoint)
		--- HACKFIX(lobato): This fixes a bug in the WoW rendering engine.
		-- The frame needs to be polled in some way for it to render correctly in the pipeline,
		-- otherwise relative frames will not always render correctly across the bottom edge.
		self.frame:GetBottom()
		return
	end
	if self.loading or self.bankOpening then
		return
	end
	if self.keptLeft == nil then
		self:KeepPlace()
	end
	local left, bottom = self.window:Fit(self.keptLeft, self.keptBottom)
	self.frame:ClearAllPoints()
	self.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
end

-- KeepPlace makes where the bag is now the place it keeps as it changes size.
function bagFrame.bagProto:KeepPlace()
	self.keptLeft, self.keptBottom = self.frame:GetLeft(), self.frame:GetBottom()
end

-- OnBankOpening starts a bank visit: back at its saved position, which decides where it is while its
-- tabs read in one at a time (refresh-scheduler.md §11a). Each makes it taller, and keeping the first
-- one's bottom edge would push its top up by all the others.
function bagFrame.bagProto:OnBankOpening()
	self.bankOpening = true
	self.keptLeft, self.keptBottom = nil, nil
	if not (self.anchor and self.anchor:IsActive()) then
		self.window:RestorePosition()
	end
end

-- OnBankLoaded ends that: the bank has drawn what it holds.
function bagFrame.bagProto:OnBankLoaded()
	self.bankOpening = false
	self:OnResize()
end

function bagFrame.bagProto:SetTitle(text)
	self.window:SetTitle(text)
end

---@return SizeInfo
function bagFrame.bagProto:GetSizeInfo()
	return database:GetBagSizeInfo(self.kind, database:GetBagView(self.kind))
end

-- ApplySizeSettings gives the window the scale, opacity and size mode of the view the bag
-- shows (each view keeps its own). The size mode is applied only when it or the view changed:
-- applying it takes the saved size, which would undo a resize in progress.
function bagFrame.bagProto:ApplySizeSettings()
	self.window:UpdateScale(true)
	self.window:UpdateOpacity()
	local view = database:GetBagView(self.kind)
	local mode = database:GetBagSizeMode(self.kind)
	if view ~= self.appliedView or mode ~= self.appliedSizeMode then
		if mode ~= self.appliedSizeMode then
			-- The grip may have moved its edges meanwhile: what it kept is out of date.
			self.keptLeft, self.keptBottom = nil, nil
		end
		self.appliedView = view
		self.appliedSizeMode = mode
		self.window:UpdateSizeMode()
	end
end

-- BuildWindow creates the bag's window, the scroll box its content scrolls in, and the
-- canvas the content is laid out on.
---@param name string Backpack or Bank.
function bagFrame.bagProto:BuildWindow(name)
	local kind = self.kind
	self.window = windowModule:Create({
		Kind = "Bag",
		Name = "BetterBagsBag" .. name,
		Title = name,
		Strata = self.behavior:GetFrameStrata(),
		Level = self.behavior:GetFrameLevel(),
		Toplevel = true,
		Position = database:GetBagPosition(kind),
		CanMove = function()
			return not CursorHasItem()
		end,
		OnMoved = function()
			self:KeepPlace()
			self:OnResize()
		end,
		Opacity = function()
			return self:GetSizeInfo().opacity
		end,
		Scale = function()
			return self:GetSizeInfo().scale / 100
		end,
		SizeMode = function()
			return database:GetBagSizeMode(kind)
		end,
		Size = function()
			return database:GetBagViewFrameSize(kind, database:GetBagView(kind))
		end,
		OnResized = function(_, width, height)
			database:SetBagViewFrameSize(kind, database:GetBagView(kind), width, height)
		end,
		SnapToContent = function()
			return database:GetBagSnapToContent(kind)
		end,
		MinWidth = function()
			if self.slots and self.slots:IsShown() then
				return self.slots.frame:GetWidth()
			end
			return 0
		end,
		-- Read as the window is styled, which for a bag made after a theme was applied is before its
		-- scroll box and tabs exist (next.md §11f).
		MinContentWidth = function()
			local tabsWidth = self.tabs and self.tabs.width or 0
			return math.max(MIN_CONTENT_WIDTH, tabsWidth) + scrollbox:GutterWidthFor(SCROLL_OPTIONS)
		end,
		MinContentHeight = MIN_CONTENT_HEIGHT,
		Fade = function()
			return database:GetEnableBagFading()
		end,
		-- One setting for every bag (Clamp Bags to Screen, window.md §3a).
		Clamp = function()
			return database:GetClampBagsToScreen()
		end,
		OnClose = function(ctx)
			self:Hide(ctx)
		end,
		OnRendered = function()
			self:OnResize()
		end,
		OnDecorated = function(ctx, decoration)
			self:PlaceParts(ctx, decoration)
		end,
	})
	self.frame = self.window.frame
	self.frame:SetSize(200, 200)

	self.scroll = scrollbox:Create(self.frame, "BetterBagsBagScroll" .. name, SCROLL_OPTIONS)
	self.canvas = bagCanvas:Create(self, self.scroll.scrollChild)
	self.scroll:SetChild(self.canvas)
	self.window:SetContent(self.scroll)
	self.scrollBox = self.scroll.scrollBox
	self.headerContainer = self.canvas.headerContainer
	self.tabContainer = self.canvas.tabContainer
	self.footerContainer = self.canvas.footerContainer

	-- Loading... in the middle of the bag, above its content, while what it shows has never been
	-- read (UpdateLoadingText): nothing is drawn yet.
	local loading = CreateFrame("Frame", nil, self.frame)
	loading:SetSize(1, 1)
	loading:SetPoint("CENTER", self.scrollBox, "CENTER", 0, 0)
	loading:SetFrameLevel(self.scrollBox:GetFrameLevel() + 10)
	self.loadingText = sonata:CreateText(loading, "Empty", "OVERLAY")
	self.loadingText:SetPoint("CENTER", loading, "CENTER", 0, 0)
	self.loadingText:SetText(L:G("Loading..."))
	self.loading = true
	self:UpdateLoadingText()
end

-- UpdateLoadingText shows Loading... while what the bag shows has never been read (the bank waits
-- for its window to finish showing before it is read, refresh-scheduler.md §11), unless the retail
-- bank's Purchase Bank button, in the same place, shows.
function bagFrame.bagProto:UpdateLoadingText()
	local purchase = self.purchaseBankButton
	self.loadingText:SetShown(self.loading and not (purchase ~= nil and purchase:IsShown()))
end

-- BuildParts creates the parts of the bag window the theme places: the in-bag search box, the
-- menu button, the action buttons a theme may give it, and the footer bar along the bottom.
function bagFrame.bagProto:BuildParts()
	self.searchBox = searchBox:CreateBox(self.kind, self.frame)
	self.menuButton = menuButton:Create(self)
	self.actions = bagActions:Create(self)

	local bottomBar = CreateFrame("Frame", nil, self.frame)
	bottomBar:SetHeight(20)
	bottomBar:Show()
	self.bottomBar = bottomBar

	self.hiddenText = sonata:CreateText(bottomBar, "Count")
	self.hiddenText:Hide()
end

-- ShowHiddenCount says in the footer how many items a hidden category keeps out of the tab shown (Hide In,
-- category-lifecycle.md §10), so a player can tell where they went.
---@param slotInfo SlotInfo
---@param tabID number
function bagFrame.bagProto:ShowHiddenCount(slotInfo, tabID)
	local tab = slotInfo.tabs and slotInfo.tabs[tabID]
	local hidden = tab and tab.hiddenItems or 0
	self.hiddenText:SetShown(hidden > 0)
	if hidden > 0 then
		self.hiddenText:SetText(format(L:G("%d hidden"), hidden))
	end
end

-- PlaceParts puts the bag's own parts where the theme's layout says, and reserves the room
-- they take inside the window's content box. It runs after every theme the window took.
---@param ctx Context
---@param decoration SonataWindowDecoration
function bagFrame.bagProto:PlaceParts(ctx, decoration)
	-- A window registered after a theme was applied is styled as it registers, before BuildParts
	-- (the classic bags made by a switch, next.md §11); PlacePartsIfDecorated places them once made.
	if self.searchBox == nil then
		return
	end
	local layout = decoration:GetLayout()
	local overlay = decoration:GetOverlayFrame()

	local search = type(layout.Search) == "table" and layout.Search or nil
	if search ~= nil then
		local box = self.searchBox.frame
		box:ClearAllPoints()
		for _, p in ipairs(search.Points or {}) do
			box:SetPoint(p.Point, self.frame, p.RelativePoint or p.Point, p.X or 0, p.Y or 0)
		end
		box:SetFrameLevel(overlay:GetFrameLevel() + 2)
	end
	self.searchLayout = search

	local footer = type(layout.Footer) == "table" and layout.Footer or nil
	self.footerLayout = footer
	if footer ~= nil then
		self.bottomBar:ClearAllPoints()
		self.bottomBar:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", footer.Left or 0, footer.Bottom or 0)
		self.bottomBar:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -(footer.Right or 0), footer.Bottom or 0)
		self.bottomBar:SetHeight(footer.Height or 20)
		self.bottomBar:Show()
	else
		self.bottomBar:Hide()
	end
	self.hiddenText:ClearAllPoints()
	if self.moneyFrame then
		self.hiddenText:SetPoint("BOTTOMRIGHT", self.moneyFrame.frame, "BOTTOMLEFT", -4, 3)
	else
		self.hiddenText:SetPoint("BOTTOMRIGHT", self.bottomBar, "BOTTOMRIGHT", -4, 3)
	end

	menuButton:Place(self.menuButton, layout.MenuButton, self.frame, overlay)
	bagActions:Place(self.actions, layout.Actions, self.frame, overlay)
	self:PlaceTabs()
	self:UpdateSearchShown()
	if self.slots and self.slots:IsShown() then
		self.slots:Draw(ctx)
	end
end

-- PlacePartsIfDecorated places the bag's parts once they are made: all of them when the window
-- was styled before they existed (a bag made after a theme was applied, next.md §11), else the tab
-- bar, which the behavior made after the parts.
---@param ctx Context
function bagFrame.bagProto:PlacePartsIfDecorated(ctx)
	if self.window.decoration then
		self:PlaceParts(ctx, self.window.decoration)
	else
		self:PlaceTabs()
	end
end

-- PlaceTabs hangs the tab bar below the bag where the theme's layout says (Layout.Tabs.Offset:
-- where the bar's top left sits from the bag's bottom left), 2 into the window without one.
-- Themes whose art reaches far below the window hang it below that art.
function bagFrame.bagProto:PlaceTabs()
	if self.tabs == nil then
		return
	end
	local tabsLayout = self.window:GetLayout().Tabs
	local offset = type(tabsLayout) == "table" and tabsLayout.Offset or {}
	local x, y = offset.X or 0, offset.Y or 2
	local bar = self.tabs.frame
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", self.frame, "BOTTOMLEFT", x, y)
	bar:SetPoint("TOPRIGHT", self.frame, "BOTTOMRIGHT", x, y)
end

-- UpdateSearchShown shows the in-bag search box when in-bag search is on, and reserves the
-- room the theme's layout gives it, and the footer's, inside the window's content box.
function bagFrame.bagProto:UpdateSearchShown()
	local shown = database:GetInBagSearch() and self.searchLayout ~= nil
	self.searchBox.frame:SetShown(shown)
	self.window:SetExtraInsets({
		Top = shown and (self.searchLayout.Reserve or 0) or 0,
		Bottom = self.footerLayout and (self.footerLayout.Reserve or 0) or 0,
	})
end

-- SetSearchShown follows the in-bag search setting: the box shows or hides, and the bags are
-- recalculated (their search results come from whichever box holds the query).
---@param ctx Context
function bagFrame.bagProto:SetSearchShown(ctx)
	self:UpdateSearchShown()
	events:SendMessage(ctx, 'bags/Rederive', { resetLayout = true, buttons = true, categoriesUnchanged = true })
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

-- refreshCooldown refreshes one button's cooldown; it returns whether it checked the button
-- and whether Blizzard's update ran.
---@param ctx Context
---@param item Item
---@return boolean checked, boolean applied
local function refreshCooldown(ctx, item)
	-- A button reused as a free slot still carries the data of the item it last drew.
	if item.isFreeSlot then
		return false, false
	end
	local data = item:GetItemData()
	if not data then
		return false, false
	end
	local reason = item:UpdateCooldown(ctx, data, true)
	return true, reason ~= "unchanged" and reason ~= "empty"
end

-- OnCooldown refreshes the cooldown of every visible item button: the active tab
-- view's buttons and the global Recent Items section's, which lives outside the view. It
-- returns how many buttons it checked and how many it applied Blizzard's update to, for the
-- profiler's call trace.
---@param ctx Context
---@return number checked, number applied
function bagFrame.bagProto:OnCooldown(ctx)
	if not self:IsShown() then
		return 0, 0
	end
	local checked, applied = 0, 0
	local function refresh(item)
		local c, a = refreshCooldown(ctx, item)
		if c then checked = checked + 1 end
		if a then applied = applied + 1 end
	end
	if self.currentView then
		for _, item in pairs(self.currentView:GetItemsByBagAndSlot()) do
			refresh(item)
		end
	end
	for _, item in ipairs(self.itemFrames or {}) do
		refresh(item)
	end
	return checked, applied
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
			events:SendMessage(ctx, 'bags/Rederive', { resetLayout = true, buttons = true })
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
	b.bankTab = addon.isRetail and Enum.BagIndex.Characterbanktab or (const.BANK_TAB and const.BANK_TAB.BANK or 1)
	b.sections = {}
	b.toRelease = {}
	b.toReleaseSections = {}
	b.kind = kind

	-- Instantiate the appropriate behavior based on bag kind
	if kind == const.BAG_KIND.BACKPACK then
		b.behavior = backpackBehavior:Create(b)
	else
		b.behavior = bankBehavior:Create(b)
	end

	local name = kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"
	b.tabViews = {}
	b.itemFrames = {}
	b.globalSections = {}
	b:BuildWindow(name)
	b:BuildParts()

	-- Setup money frame via behavior
	b.moneyFrame = b.behavior:SetupMoneyFrame(b.bottomBar)

	-- Call behavior-specific creation (slots, currency, tabs, etc.)
	b.behavior:OnCreate(ctx)
	b:PlacePartsIfDecorated(ctx)

	b:WatchMouse()

	b.anchor = anchor:New(kind, b.frame, name)

	-- Register behavior-specific events
	b.behavior:RegisterEvents()
	b:WatchForClose()

	events:RegisterMessage("search/SetInFrame", function(ectx)
		b:SetSearchShown(ectx)
	end)

	if kind == const.BAG_KIND.BANK then
		events:RegisterMessage("bags/BankOpening", function()
			b:OnBankOpening()
		end)
		events:RegisterMessage("bags/BankLoaded", function()
			b:OnBankLoaded()
		end)
	end

	events:RegisterMessage("bag/RedrawIcons", function(ectx)
		if not b.currentView then
			return
		end
		for _, item in pairs(b.currentView:GetItemsByBagAndSlot()) do
			local data = item:GetItemData()
			if data then
				item:UpdateUpgrade(ectx, data)
			end
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
