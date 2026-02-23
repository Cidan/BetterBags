local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)

---@class Tabs: AceModule
local tabs = addon:NewModule("Tabs")

---@class Themes: AceModule
local themes = addon:GetModule("Themes")

---@class SectionFrame: AceModule
local sectionFrame = addon:GetModule("SectionFrame")

---@class Context: AceModule
local context = addon:GetModule("Context")

---@class Events: AceModule
local events = addon:GetModule("Events")

---@class Database: AceModule
local database = addon:GetModule("Database")

---@class Groups: AceModule
local groups = addon:GetModule("Groups")

---@class Constants: AceModule
local const = addon:GetModule("Constants")

-- Tab drag state (module-level to match section.lua pattern)
tabs.draggingTab = nil              ---@type TabButton? Tab button being dragged
tabs.dragStartIndex = nil           ---@type number? Original index before drag started
tabs.dragStartX = nil               ---@type number? Original X position (screen coords)
tabs.dragStartY = nil               ---@type number? Original Y position (LOCKED during drag)
tabs.dragOffsetX = nil              ---@type number? Cursor offset from tab left edge
tabs.currentTabFrame = nil          ---@type Tab? Reference to Tab object being dragged from
tabs.isDragging = false             ---@type boolean Whether drag is in progress
tabs.lastOverlapIndex = nil         ---@type number? Last detected overlap target (for debouncing)
tabs.lastInsertAfter = nil          ---@type boolean? Whether to insert after (true) or before (false) the overlap target
tabs.dropPlaceholder = nil          ---@type Frame? Visual placeholder showing where tab will land

---@class PanelTabButtonTemplate: Button
---@field Text FontString
---@field Left Texture
---@field Middle Texture
---@field Right Texture
---@field LeftActive Texture
---@field MiddleActive Texture
---@field RightActive Texture
---@field deselectedTextX number
---@field deselectedTextY number
---@field selectedTextX number
---@field selectedTextY number

---@class TabButton: Button
---@field name string
---@field index number
---@field id? number
---@field icon? string Optional atlas name to display instead of text
---@field onClick? fun()
---@field sabtClick? Button

---@class (exact) Tab
---@field frame Frame
---@field tabIndex TabButton[]
---@field buttonToName table<TabButton, string>
---@field selectedTab number
---@field clickHandler fun(ctx: Context, name: number, button: string): boolean?
---@field width number
---@field tabCount number
local tabFrame = {}

---@param ctx Context
---@param name string
---@param id? number
---@param onClick? fun()
---@param sabtClick? Button
---@param customParent? Frame
---@param template? string
function tabFrame:AddTab(ctx, name, id, onClick, sabtClick, customParent, template)
	---@type TabButton | Frame
	local parent = customParent or self.frame
	local tab = CreateFrame("Button", format("%sTab%d", self.frame:GetName(), self.tabCount), parent, template) --[[@as TabButton]]
	tab.sabtClick = sabtClick
	tab.onClick = onClick
	tab.name = name
	tab.id = id
	tab:SetNormalFontObject(GameFontNormalSmall)
	self.tabCount = self.tabCount + 1
	local anchorFrame = self.frame
	local anchorPoint = "TOPLEFT"
	if self.tabIndex[#self.tabIndex] then
		anchorFrame = self.tabIndex[#self.tabIndex]
		anchorPoint = "TOPRIGHT"
	end
	tab:SetPoint("TOPLEFT", anchorFrame, anchorPoint, 5, 0)
	table.insert(self.tabIndex, tab)
	tab.index = #self.tabIndex
	self.buttonToName[tab] = name
	self:DeselectTab(ctx, tab.index)
	self:ResizeTabByIndex(ctx, tab.index)
	self:ReanchorTabs()
end

---@param name string
---@return TabButton?
function tabFrame:GetTabByName(name)
	for _, tab in pairs(self.tabIndex) do
		if tab.name == name then
			return tab
		end
	end
	return nil
end

---@param name string
---@return boolean
function tabFrame:TabExists(name)
	return self:GetTabByName(name) ~= nil
end

---@param ctx Context
function tabFrame:Reload(ctx)
	for index in pairs(self.tabIndex) do
		self:ResizeTabByIndex(ctx, index)
	end
	self:SetTabByIndex(ctx, self.selectedTab)
end

function tabFrame:ReanchorTabs()
	self.width = 0
	local visibleTabs = {}

	-- Collect visible tabs (skip the one being dragged)
	for _, tab in ipairs(self.tabIndex) do
		if tab:IsShown() and tab ~= tabs.draggingTab then
			table.insert(visibleTabs, tab)
		end
	end

	-- Calculate absolute positions and anchor all tabs directly to container frame
	-- This prevents tabs from dragging along when anchored to each other
	local currentX = 5  -- Start with initial spacing
	for _, tab in ipairs(visibleTabs) do
		tab:ClearAllPoints()
		-- Anchor directly to container frame with calculated X position
		tab:SetPoint("TOPLEFT", self.frame, "TOPLEFT", currentX, 0)
		currentX = currentX + tab:GetWidth() + 5  -- Add tab width plus spacing
		self.width = self.width + tab:GetWidth() + 5
	end
end

function tabFrame:MoveToEnd(name)
	for i, tab in ipairs(self.tabIndex) do
		if tab.name == name then
			table.remove(self.tabIndex, i)
			table.insert(self.tabIndex, tab)
			break
		end
	end
	for i, tab in ipairs(self.tabIndex) do
		tab.index = i
	end
	self:ReanchorTabs()
end

-- Sort tabs by their ID
function tabFrame:SortTabsByID()
	-- Remember which tab was selected (by tab ID, not index) before sorting
	-- This prevents tab selection bugs when tabs are re-indexed
	local selectedTabID = nil
	if self.selectedTab and self.tabIndex[self.selectedTab] then
		selectedTabID = self.tabIndex[self.selectedTab].id
	end

	if self.kind == const.BAG_KIND.BANK then
		-- Bank tab sort order:
		--   Bank (default, Character) → user Bank tabs → Warbank (default, Account)
		--   → user Warbank tabs → "+" tab
		-- This groups bank and warbank tabs into clearly separated sections.
		local charBankType = Enum.BankType and Enum.BankType.Character or 1
		local accountBankType = Enum.BankType and Enum.BankType.Account or 2

		-- Returns a (section, secondaryOrder) pair for a bank tab.
		-- Section values:
		--   1 = Bank default (Character bankType, isDefault)
		--   2 = User-created Bank tabs (Character bankType)
		--   4 = Warbank default (Account bankType, isDefault)
		--   5 = User-created Warbank tabs (Account bankType)
		--   7 = "+" create tab (id=0)
		--   8 = Unknown/fallback
		local function getBankTabSection(tab)
			if tab.id == 0 then return 7, 0 end   -- "+" always last
			if tab.id and tab.id > 0 then
				local group = database:GetGroup(self.kind, tab.id)
				if group then
					if group.isDefault then
						if group.bankType == charBankType then
							return 1, 0  -- Bank default (always first in Bank section)
						elseif group.bankType == accountBankType then
							return 4, 0  -- Warbank default (always first in Warbank section)
						end
					else
						if group.bankType == charBankType then
							return 2, database:GetGroupOrder(self.kind, tab.id)  -- User Bank tab
						elseif group.bankType == accountBankType then
							return 5, database:GetGroupOrder(self.kind, tab.id)  -- User Warbank tab
						end
					end
				end
			end
			return 8, 0  -- Fallback
		end

		table.sort(self.tabIndex, function(a, b)
			local sectionA, orderA = getBankTabSection(a)
			local sectionB, orderB = getBankTabSection(b)
			if sectionA ~= sectionB then
				return sectionA < sectionB
			end
			if orderA ~= orderB then
				return orderA < orderB
			end
			if a.id and b.id and a.id ~= b.id then
				return a.id < b.id
			end
			return (a.name or "") < (b.name or "")
		end)
	else
		-- Non-bank sort (e.g., backpack): keep existing ID-based logic.
		table.sort(self.tabIndex, function(a, b)
			-- Special case: default tab (ID 1) should always be first
			if a.id == 1 then
				return true
			end
			if b.id == 1 then
				return false
			end

			-- Special case: Purchase tabs (negative IDs) should always be last
			if a.id and a.id < 0 and b.id and b.id > 0 then
				return false
			end
			if b.id and b.id < 0 and a.id and a.id > 0 then
				return true
			end

			-- If both have negative IDs (purchase tabs), sort by absolute value
			if a.id and b.id and a.id < 0 and b.id < 0 then
				return math.abs(a.id) < math.abs(b.id)
			end

			-- If both are reorderable groups, sort by their Group.order value
			if a.id and b.id and a.id > 0 and b.id > 0 and not groups:IsDefaultGroup(self.kind, a.id) and not groups:IsDefaultGroup(self.kind, b.id) then
				local orderA = database:GetGroupOrder(self.kind, a.id)
				local orderB = database:GetGroupOrder(self.kind, b.id)
				if orderA ~= orderB then
					return orderA < orderB
				end
				-- Fallback to ID if orders are equal
				return a.id < b.id
			end

			-- If both have IDs, sort by ID
			if a.id and b.id then
				if a.id ~= b.id then
					return a.id < b.id
				end
			end

			-- If only one has an ID, put the one with ID first
			if a.id and not b.id then
				return true
			end
			if not a.id and b.id then
				return false
			end

			-- If neither have IDs or IDs are identical, sort by name to guarantee deterministic order
			local nameA = a.name or ""
			local nameB = b.name or ""
			if nameA ~= nameB then
				return nameA < nameB
			end

			-- Absolute fallback to maintain stable order if names are identical
			return a.index < b.index
		end)
	end

	-- Update the index values after sorting
	for i, tab in ipairs(self.tabIndex) do
		tab.index = i
	end

	-- Restore selection by finding the tab with the remembered ID
	-- This fixes the bug where tabs become unselectable after sorting
	if selectedTabID then
		for i, tab in ipairs(self.tabIndex) do
			if tab.id == selectedTabID then
				self.selectedTab = i  -- Update to new index position
				break
			end
		end
	end

	self:ReanchorTabs()
end

---@param index number
---@return string
function tabFrame:GetTabName(index)
	return self.buttonToName[self.tabIndex[index]]
end

---@param id number
---@return string
function tabFrame:GetTabNameByID(id)
	for _, tab in pairs(self.tabIndex) do
		if tab.id == id then
			return tab.name
		end
	end
	return ""
end

---@param id number
---@return boolean
function tabFrame:TabExistsByID(id)
	for _, tab in pairs(self.tabIndex) do
		if tab.id == id then
			return true
		end
	end
	return false
end

---@param ctx Context
---@param id number
---@param name string
function tabFrame:RenameTabByID(ctx, id, name)
	for index, tab in pairs(self.tabIndex) do
		if tab.id == id then
			tab.name = name
			self.buttonToName[tab] = name
			self:ResizeTabByIndex(ctx, index)
			return
		end
	end
end

---@param ctx Context
---@param id number
---@param icon string Atlas name to use as the tab icon
function tabFrame:SetTabIconByID(ctx, id, icon)
	for index, tab in pairs(self.tabIndex) do
		if tab.id == id then
			tab.icon = icon
			self:ResizeTabByIndex(ctx, index)
			return
		end
	end
end

---@param ctx Context
---@param id number
function tabFrame:ClearTabIconByID(ctx, id)
	for index, tab in pairs(self.tabIndex) do
		if tab.id == id then
			tab.icon = nil
			self:ResizeTabByIndex(ctx, index)
			return
		end
	end
end

---@param ctx Context
---@param index number
function tabFrame:ResizeTabByIndex(ctx, index)
	local tab = self.tabIndex[index]
	local decoration = themes:GetTabButton(ctx, tab)

	-- Ensure decoration is shown before measuring/resizing
	-- PanelTemplates_TabResize needs the frame to be visible to properly measure text width
	decoration:Show()

	-- Ensure the decoration's text uses the same font as the tab button
	-- This fixes incorrect text width measurements on initial tab creation
	if decoration.Text then
		decoration.Text:SetFontObject(GameFontNormalSmall)
	end

	-- Handle icon tabs vs text tabs
	if tab.icon then
		-- Icon tab: hide text, show icon
		decoration.Text:SetText("")
		decoration.Text:SetAlpha(0)

		-- Create icon texture if it doesn't exist
		if not decoration.tabIcon then
			local icon = decoration:CreateTexture(nil, "OVERLAY")
			icon:SetSize(16, 16)
			icon:SetPoint("CENTER", decoration, "CENTER", 0, 1)
			decoration.tabIcon = icon
		end
		decoration.tabIcon:SetAtlas(tab.icon)
		decoration.tabIcon:Show()

		-- Ensure icon-only tabs are at least as wide as a short text tab (e.g. "Bank").
		-- Without a minimum, the tab only spans the left+right edge textures (~20px),
		-- making it noticeably smaller than text tabs.  50px matches a typical
		-- short-label tab width so the '+' button is the same size as its neighbours.
		PanelTemplates_TabResize(decoration, nil, 50)
		tab:SetWidth(decoration:GetWidth())
	else
		-- Text tab: show text, hide icon if it exists
		decoration.Text:SetText(tab.name)
		decoration.Text:SetAlpha(1)

		if decoration.tabIcon then
			decoration.tabIcon:Hide()
		end

		PanelTemplates_TabResize(decoration)
		tab:SetWidth(decoration:GetWidth())
	end

	tab:SetHeight(32)
	decoration:SetFrameLevel(tab:GetFrameLevel() + 1)

	-- For purchase tabs (negative IDs), make decoration forward clicks to the secure tab button
	-- while keeping mouse enabled for hover effects (highlighting from PanelTabButtonTemplate)
	if tab.id and tab.id < 0 then
		-- Make decoration act as a click forwarder to the secure purchase button
		decoration:SetAttribute("type", "click")
		decoration:SetAttribute("clickbutton", tab)
		return
	end

	if not tab.sabtClick then
		addon.SetScript(decoration, "OnClick", function(ectx, _, button)
			if tab.onClick then
				tab.onClick()
				return
			end
			-- Use tab.index instead of captured index parameter to handle re-indexing after sort
			if self.clickHandler and (self.selectedTab ~= tab.index or button == "RightButton") then
				local shouldSelect = self.clickHandler(ectx, tab.id or tab.index, button)
				if shouldSelect ~= false then
					if tab.id then
						self:SetTabByID(ectx, tab.id)
					else
						self:SetTabByIndex(ectx, tab.index)
					end
				end
			end
		end)

		-- Enable drag-to-reorder for reorderable tabs (group tabs, not Bank/"+" tabs)
		if tabs:IsTabReorderable(self.kind, tab) then
			decoration:SetScript("OnMouseDown", function(_, button)
				if button == "LeftButton" and IsShiftKeyDown() then
					tabs:StartTabDrag(tab, self)
				end
			end)

			decoration:SetScript("OnMouseUp", function(_, button)
				if button == "LeftButton" and tabs.isDragging and tabs.draggingTab == tab then
					tabs:StopTabDrag()
				end
			end)
		end
	end

	-- Set up drag-and-drop handling for group tabs (id > 0, not the "+" tab)
	if tab.id and tab.id > 0 then
		-- Store original highlight state
		local originalOnEnter = decoration:GetScript("OnEnter")
		local originalOnLeave = decoration:GetScript("OnLeave")

		decoration:SetScript("OnEnter", function(frame)
			-- Check if we're dragging a category
			if sectionFrame.draggingCategory then
				-- Validate that this tab accepts the dragged category:
				-- 1. Tab frame kind must match the section's kind (no cross-bag drops).
				-- 2. For bank tabs, the group's bankType must match draggingBankType
				--    (Character Bank categories cannot go to Warbank groups and vice versa).
				local isValidTarget = (sectionFrame.draggingKind == self.kind)
				if isValidTarget and self.kind == const.BAG_KIND.BANK and sectionFrame.draggingBankType ~= nil then
					local tabGroup = database:GetGroup(self.kind, tab.id)
					if tabGroup and tabGroup.bankType ~= sectionFrame.draggingBankType then
						isValidTarget = false
					end
				end

				if not isValidTarget then
					if originalOnEnter then originalOnEnter(frame) end
					return
				end

				-- Track this as the drop target
				sectionFrame.dragTargetTab = tab.id
				-- Highlight the tab to indicate it's a valid drop target
				decoration.MiddleActive:Show()
				decoration.LeftActive:Show()
				decoration.RightActive:Show()
				-- Show tooltip indicating what will happen
				GameTooltip:SetOwner(frame, "ANCHOR_TOP")
				if groups:IsDefaultGroup(self.kind, tab.id) then
					GameTooltip:SetText("Move to " .. tab.name)
					GameTooltip:AddLine("Remove group assignment from: " .. sectionFrame.draggingCategory, 1, 1, 1, true)
				else
					GameTooltip:SetText("Move to " .. tab.name)
					GameTooltip:AddLine("Assign " .. sectionFrame.draggingCategory .. " to this group", 1, 1, 1, true)
				end
				GameTooltip:Show()
			elseif originalOnEnter then
				originalOnEnter(frame)
			end
		end)

		decoration:SetScript("OnLeave", function(frame)
			-- Reset highlight if we were dragging
			if sectionFrame.draggingCategory then
				-- Clear the drop target if we're leaving this tab
				if sectionFrame.dragTargetTab == tab.id then
					sectionFrame.dragTargetTab = nil
				end
				-- Restore to normal deselected state (unless this tab is selected)
				if self.selectedTab ~= tab.index then
					decoration.MiddleActive:Hide()
					decoration.LeftActive:Hide()
					decoration.RightActive:Hide()
				end
				GameTooltip:Hide()
			elseif originalOnLeave then
				originalOnLeave(frame)
			end
		end)
	end
end

---@param ctx Context
---@param id number
function tabFrame:SetTabByID(ctx, id)
	for index, tab in pairs(self.tabIndex) do
		if tab.id == id and tab:IsShown() then
			self:SetTabByIndex(ctx, index)
			return
		end
	end
end

---@param ctx Context
---@param index number
function tabFrame:SetTabByIndex(ctx, index)
	for i, tab in pairs(self.tabIndex) do
		if tab:IsShown() then
			if i == index then
				self:SelectTab(ctx, i)
				self.selectedTab = index
			else
				self:DeselectTab(ctx, i)
			end
		end
	end
end

---@param index number
function tabFrame:ShowTabByIndex(index)
	self.tabIndex[index]:Show()
	self:ReanchorTabs()
end

---@param name string
function tabFrame:ShowTabByName(name)
	local tab = self:GetTabByName(name)
	if tab then
		tab:Show()
	end
	self:ReanchorTabs()
end

---@param id number
function tabFrame:ShowTabByID(id)
	for _, tab in pairs(self.tabIndex) do
		if tab.id == id then
			tab:Show()
			self:ReanchorTabs()
			return
		end
	end
end

---@param index number
function tabFrame:HideTabByIndex(index)
	self.tabIndex[index]:Hide()
	self:ReanchorTabs()
end

---@param name string
function tabFrame:HideTabByName(name)
	local tab = self:GetTabByName(name)
	if tab then
		tab:Hide()
	end
	self:ReanchorTabs()
end

---@param id number
function tabFrame:HideTabByID(id)
	for _, tab in pairs(self.tabIndex) do
		if tab.id == id then
			tab:Hide()
			self:ReanchorTabs()
			return
		end
	end
end

---@private
---@param ctx Context
---@param index number
function tabFrame:DeselectTab(ctx, index)
	local tab = self.tabIndex[index]
	local decoration = themes:GetTabButton(ctx, tab)
	decoration.Left:Show()
	decoration.Middle:Show()
	decoration.Right:Show()
	decoration:Enable()

	local offsetY = decoration.deselectedTextY or 2

	decoration.Text:SetPoint("CENTER", decoration, "CENTER", (decoration.deselectedTextX or 0), offsetY)

	decoration.LeftActive:Hide()
	decoration.MiddleActive:Hide()
	decoration.RightActive:Hide()
end

---@private
---@param ctx Context
---@param index number
function tabFrame:SelectTab(ctx, index)
	local tab = self.tabIndex[index]
	local decoration = themes:GetTabButton(ctx, tab)
	decoration:Show()
	decoration.Left:Hide()
	decoration.Middle:Hide()
	decoration.Right:Hide()
	--decoration:Disable()
	decoration:SetDisabledFontObject(GameFontHighlightSmall)

	local offsetY = decoration.selectedTextY or -3

	decoration.Text:SetPoint("CENTER", decoration, "CENTER", (decoration.selectedTextX or 0), offsetY)

	decoration.LeftActive:Show()
	decoration.MiddleActive:Show()
	decoration.RightActive:Show()

	local tooltip = GetAppropriateTooltip()
	if tooltip:IsOwned(decoration) then
		tooltip:Hide()
	end
end

---@param fn fun(ctx: Context, name: number, button: string): boolean?
function tabFrame:SetClickHandler(fn)
	self.clickHandler = fn
end


-- ResizeAllTabs recalculates the width of all tabs.
-- This is useful when fonts change after initial tab creation (e.g., theme addons loading).
---@param ctx Context
function tabFrame:ResizeAllTabs(ctx)
	for index, _ in ipairs(self.tabIndex) do
		self:ResizeTabByIndex(ctx, index)
	end
	self:ReanchorTabs()
end

---@param parent Frame
---@param kind BagKind
---@return Tab
function tabs:Create(parent, kind)
	local container = setmetatable({}, { __index = tabFrame })
	container.kind = kind
	container.frame = CreateFrame("Frame", parent:GetName() .. "TabContainer", parent)
	container.frame:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, 2)
	container.frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 2)
	container.frame:SetHeight(40)
	container.frame:SetFrameLevel(parent:GetFrameLevel() > 0 and parent:GetFrameLevel() - 1 or 0)
	container.width = 0
	container.tabs = {}
	container.tabIndex = {}
	container.buttonToName = {}
	container.tabCount = 0
	container.selectedTab = nil  -- Initialize to nil to avoid undefined state
	return container
end

-----------------------------------------------
-- Tab Drag-to-Reorder Functions
-----------------------------------------------

function tabs:CreateDropPlaceholder(_, _)
	if not self.dropPlaceholder then
		-- Create a thin vertical line as the insertion indicator
		self.dropPlaceholder = CreateFrame("Frame", nil, self.currentTabFrame.frame)
		self.dropPlaceholder:SetFrameStrata("HIGH")
		self.dropPlaceholder:SetFrameLevel(100)
		self.dropPlaceholder:SetSize(3, 32)  -- Thin line, tab height

		-- Create the line texture
		local line = self.dropPlaceholder:CreateTexture(nil, "OVERLAY")
		line:SetAllPoints()
		line:SetColorTexture(0.2, 0.8, 1.0, 0.95)  -- Bright blue, nearly opaque
		self.dropPlaceholder.line = line
	end

	self.dropPlaceholder:Hide()  -- Hidden until we detect overlap
end

---@param targetIndex number
---@param insertAfter boolean If true, show line after target tab; if false, show before
function tabs:UpdateDropPlaceholder(targetIndex, insertAfter)
	if not self.dropPlaceholder or not self.currentTabFrame or not self.draggingTab then return end

	-- Get the target tab from the array
	local targetTab = self.currentTabFrame.tabIndex[targetIndex]
	if not targetTab then return end

	-- Get the target tab's actual current screen position
	local targetLeft = targetTab:GetLeft()
	local targetRight = targetTab:GetRight()
	if not targetLeft or not targetRight then return end

	-- Get container's left edge to calculate relative offset
	local containerLeft = self.currentTabFrame.frame:GetLeft()
	if not containerLeft then return end

	-- Calculate insertion position based on which side of target tab
	local insertX
	if insertAfter then
		-- Line goes to the RIGHT of target tab (after it)
		insertX = targetRight - containerLeft + 5  -- Right edge + spacing
	else
		-- Line goes to the LEFT of target tab (before it)
		insertX = targetLeft - containerLeft  -- Left edge
	end

	-- Position the line (center the 3px line)
	self.dropPlaceholder:ClearAllPoints()
	self.dropPlaceholder:SetPoint("TOPLEFT", self.currentTabFrame.frame, "TOPLEFT", insertX - 1.5, 0)
	self.dropPlaceholder:Show()
end

function tabs:HideDropPlaceholder()
	if self.dropPlaceholder then
		self.dropPlaceholder:Hide()
	end
end

---@param kind BagKind
---@param tab TabButton
---@return boolean
function tabs:IsTabReorderable(kind, tab)
	if not tab.id then return false end
	if groups:IsDefaultGroup(kind, tab.id) then return false end    -- Default tabs always first
	if tab.id == 0 then return false end    -- "+" tab always last
	if tab.id < 0 then return false end     -- Purchase tabs always at end
	return true
end

---@param tab TabButton
---@param frame Tab
function tabs:StartTabDrag(tab, frame)
	-- Prevent dragging if already dragging
	if self.isDragging then return end

	-- Store drag state
	self.isDragging = true
	self.draggingTab = tab
	self.dragStartIndex = tab.index
	self.currentTabFrame = frame
	self.lastOverlapIndex = nil

	-- Capture cursor position relative to tab
	local cursorX = GetCursorPosition()
	local scale = tab:GetEffectiveScale()

	-- Get tab's current screen position
	local tabLeft = tab:GetLeft()

	-- Calculate offset from tab's top-left corner to cursor (in frame coords)
	self.dragOffsetX = (cursorX / scale) - tabLeft

	-- Visual feedback: raise frame level and dim slightly
	local ctx = context:New("StartTabDrag")
	local decoration = themes:GetTabButton(ctx, tab)
	tab:SetFrameLevel(tab:GetFrameLevel() + 10)
	decoration:SetAlpha(0.8)

	-- Create drop placeholder (shows where tab will land)
	self:CreateDropPlaceholder(ctx, tab)

	-- Start OnUpdate tracking
	decoration:SetScript("OnUpdate", function()
		tabs:UpdateTabDrag()
	end)

	-- Set cursor to indicate dragging
	SetCursor("Interface\\Cursor\\UI-Cursor-Move")
end

function tabs:UpdateTabDrag()
	if not self.isDragging or not self.draggingTab then return end

	-- Get current cursor position in screen coordinates
	local cursorX = GetCursorPosition()
	local scale = self.draggingTab:GetEffectiveScale()

	-- Calculate where the tab's left edge should be (cursor minus offset)
	local tabLeftScreen = (cursorX / scale) - self.dragOffsetX

	-- Get the container frame's position to calculate relative offset
	local containerLeft = self.currentTabFrame.frame:GetLeft()

	-- Calculate X offset relative to container frame (subtract initial spacing of 5)
	local offsetX = tabLeftScreen - containerLeft - 5

	-- Move the tab frame (horizontal only, Y stays at 0 relative to container)
	self.draggingTab:ClearAllPoints()
	self.draggingTab:SetPoint("TOPLEFT", self.currentTabFrame.frame, "TOPLEFT", offsetX, 0)

	-- Check for overlap with other tabs
	local targetIndex, insertAfter = self:CalculateOverlapTarget()

	-- Update visual feedback based on overlap
	if targetIndex then
		-- Show insertion line at target position (but don't reorder yet)
		self:UpdateDropPlaceholder(targetIndex, insertAfter)
		self.lastOverlapIndex = targetIndex
		self.lastInsertAfter = insertAfter
	else
		-- No overlap, hide placeholder
		self:HideDropPlaceholder()
		self.lastOverlapIndex = nil
		self.lastInsertAfter = nil
	end
end

---@return number?, boolean? Returns target index and whether to insert after (true) or before (false)
function tabs:CalculateOverlapTarget()
	if not self.draggingTab then return nil, nil end

	local draggedLeft = self.draggingTab:GetLeft()
	local draggedRight = self.draggingTab:GetRight()
	if not draggedLeft or not draggedRight then return nil, nil end
	local draggedCenter = (draggedLeft + draggedRight) / 2

	-- For the bank kind, determine the dragged tab's bankType so we can constrain
	-- reordering to within the same section: Bank tabs stay in the Bank section and
	-- Warbank tabs stay in the Warbank section.
	local draggingBankType = nil
	if self.currentTabFrame.kind == const.BAG_KIND.BANK and self.draggingTab.id and self.draggingTab.id > 0 then
		local draggingGroup = database:GetGroup(self.currentTabFrame.kind, self.draggingTab.id)
		draggingBankType = draggingGroup and draggingGroup.bankType or nil
	end

	-- Check each visible tab (skip the dragged one)
	for i, tab in ipairs(self.currentTabFrame.tabIndex) do
		if tab ~= self.draggingTab and tab:IsShown() then
			-- Only check reorderable tabs (skip default tabs, +, purchase tabs)
			if self:IsTabReorderable(self.currentTabFrame.kind, tab) then
				-- Constrain bank drag-and-drop: only allow drops within the same bankType section.
				local validTarget = true
				if draggingBankType ~= nil then
					local targetGroup = database:GetGroup(self.currentTabFrame.kind, tab.id)
					local targetBankType = targetGroup and targetGroup.bankType or nil
					if targetBankType ~= draggingBankType then
						validTarget = false
					end
				end

				if validTarget then
					local tabLeft = tab:GetLeft()
					local tabRight = tab:GetRight()
					if tabLeft and tabRight then
						local tabCenter = (tabLeft + tabRight) / 2

						-- Check if dragged center is within this tab's bounds
						local distance = math.abs(draggedCenter - tabCenter)
						local threshold = (tabRight - tabLeft) / 2

						if distance < threshold then
							-- Determine if we should insert before or after based on which half
							local insertAfter = draggedCenter > tabCenter
							return i, insertAfter
						end
					end
				end
			end
		end
	end

	return nil, nil  -- No valid overlap
end

---@param targetIndex number
function tabs:TriggerSlide(targetIndex)
	if not targetIndex or targetIndex == self.draggingTab.index then
		return
	end

	local currentIndex = self.draggingTab.index
	local tabArray = self.currentTabFrame.tabIndex

	-- Remove dragged tab from array
	table.remove(tabArray, currentIndex)

	-- Insert at target position
	table.insert(tabArray, targetIndex, self.draggingTab)

	-- Re-index all tabs
	for i, tab in ipairs(tabArray) do
		tab.index = i
	end

	-- Reanchor all tabs (except the dragging one, which follows cursor)
	self.currentTabFrame:ReanchorTabs()
end

function tabs:StopTabDrag()
	if not self.isDragging then return end

	local ctx = context:New("StopTabDrag")
	local decoration = themes:GetTabButton(ctx, self.draggingTab)
	local savedTabFrame = self.currentTabFrame
	local draggedTab = self.draggingTab
	local startIndex = self.dragStartIndex
	local targetIndex = self.lastOverlapIndex
	local insertAfter = self.lastInsertAfter

	-- Clear OnUpdate handler
	decoration:SetScript("OnUpdate", nil)

	-- Restore visual state
	draggedTab:SetFrameLevel(draggedTab:GetFrameLevel() - 10)
	decoration:SetAlpha(1.0)
	ResetCursor()

	-- Hide drop placeholder
	self:HideDropPlaceholder()

	-- Clear drag state BEFORE reordering (so ReanchorTabs includes this tab)
	self.isDragging = false
	self.draggingTab = nil
	self.dragStartIndex = nil
	self.currentTabFrame = nil
	self.lastOverlapIndex = nil
	self.lastInsertAfter = nil

	-- If we have a valid drop target, perform the reorder
	if targetIndex then
		-- Calculate the actual insertion index
		-- If insertAfter=true, we want to insert AFTER the target (index + 1)
		-- If insertAfter=false, we want to insert AT the target position
		-- But we also need to account for the fact that we remove the dragged tab first
		local finalIndex
		if insertAfter then
			-- Insert after target: if target is at 3, insert at 4
			-- But if we're moving left (startIndex > targetIndex), indices shift after remove
			finalIndex = targetIndex < startIndex and (targetIndex + 1) or targetIndex
		else
			-- Insert before target: if target is at 3, insert at 3
			finalIndex = targetIndex < startIndex and targetIndex or (targetIndex - 1)
		end

		if finalIndex ~= startIndex then
			-- Perform the actual reorder
			local tabArray = savedTabFrame.tabIndex
			table.remove(tabArray, startIndex)
			table.insert(tabArray, finalIndex, draggedTab)

			-- Re-index all tabs
			for i, tab in ipairs(tabArray) do
				tab.index = i
			end

			-- Update selectedTab to track the tab that was selected before reordering
			-- If the dragged tab was selected, update to its new index
			if savedTabFrame.selectedTab == startIndex then
				savedTabFrame.selectedTab = finalIndex
			elseif startIndex < finalIndex then
				-- Dragged tab moved right, tabs between startIndex and finalIndex shifted left
				if savedTabFrame.selectedTab > startIndex and savedTabFrame.selectedTab <= finalIndex then
					savedTabFrame.selectedTab = savedTabFrame.selectedTab - 1
				end
			else
				-- Dragged tab moved left, tabs between finalIndex and startIndex shifted right
				if savedTabFrame.selectedTab >= finalIndex and savedTabFrame.selectedTab < startIndex then
					savedTabFrame.selectedTab = savedTabFrame.selectedTab + 1
				end
			end

			-- Reanchor all tabs to their new positions
			savedTabFrame:ReanchorTabs()

			-- Persist new order to database
			self:SaveTabOrder(savedTabFrame)
		else
			savedTabFrame:ReanchorTabs()
		end
	else
		-- No reorder, just reanchor to original positions
		savedTabFrame:ReanchorTabs()
	end
end

---@param frame Tab
function tabs:SaveTabOrder(frame)
	local ctx = context:New("SaveTabOrder")

	-- Update Group.order for all reorderable tabs based on current position
	local orderCounter = 2  -- Start at 2 (Bank is always 1)

	for _, tab in ipairs(frame.tabIndex) do
		if tab.id and tab.id > 0 and not groups:IsDefaultGroup(frame.kind, tab.id) then  -- Skip default groups, "+" (0), purchase (<0)
			database:SetGroupOrder(frame.kind, tab.id, orderCounter)
			orderCounter = orderCounter + 1
		end
	end

	-- Notify other parts of addon
	events:SendMessage(ctx, 'groups/OrderChanged')
end
