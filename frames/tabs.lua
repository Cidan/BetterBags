local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)

---@class Tabs: AceModule
local tabs = addon:NewModule("Tabs")

---@class Themes: AceModule
local themes = addon:GetModule("Themes")

---@class Debug: AceModule
local debug = addon:GetModule("Debug")

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
function tabFrame:AddTab(ctx, name, id, onClick, sabtClick)
	---@type TabButton
	local tab = CreateFrame("Button", format("%sTab%d", self.frame:GetName(), self.tabCount), self.frame) --[[@as TabButton]]
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

	-- Collect visible tabs
	for _, tab in ipairs(self.tabIndex) do
		if tab:IsShown() then
			table.insert(visibleTabs, tab)
		end
	end

	-- Reanchor visible tabs
	for i, tab in ipairs(visibleTabs) do
		tab:ClearAllPoints()
		local anchorFrame = self.frame
		local anchorPoint = "TOPLEFT"
		if i > 1 then
			anchorFrame = visibleTabs[i - 1]
			anchorPoint = "TOPRIGHT"
		end
		tab:SetPoint("TOPLEFT", anchorFrame, anchorPoint, 5, 0)
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
	table.sort(self.tabIndex, function(a, b)
		-- Special case: Bank tab (ID 1) should always be first
		if a.id == 1 then
			return true
		end
		if b.id == 1 then
			return false
		end

		-- If both have IDs, sort by ID
		if a.id and b.id then
			return a.id < b.id
		end
		-- If only one has an ID, put the one with ID first
		if a.id and not b.id then
			return true
		end
		if not a.id and b.id then
			return false
		end
		-- If neither has an ID, maintain current order (by index)
		return a.index < b.index
	end)

	-- Update the index values after sorting
	for i, tab in ipairs(self.tabIndex) do
		tab.index = i
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
---@param index number
function tabFrame:ResizeTabByIndex(ctx, index)
	local tab = self.tabIndex[index]
	local decoration = themes:GetTabButton(ctx, tab)
	decoration.Text:SetText(tab.name)

	PanelTemplates_TabResize(decoration)
	tab:SetWidth(decoration:GetWidth())
	tab:SetHeight(32)

	decoration:SetFrameLevel(tab:GetFrameLevel() + 1)
	if not tab.sabtClick then
		addon.SetScript(decoration, "OnClick", function(ectx, _, button)
			if tab.onClick then
				tab.onClick()
				return
			end
			if self.clickHandler and (self.selectedTab ~= index or button == "RightButton") then
				local shouldSelect = self.clickHandler(ectx, tab.id or tab.index, button)
				if shouldSelect ~= false then
					if tab.id then
						self:SetTabByID(ectx, tab.id)
					else
						self:SetTabByIndex(ectx, index)
					end
				end
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

---@param parent Frame
---@return Tab
function tabs:Create(parent)
	local container = setmetatable({}, { __index = tabFrame })
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
	return container
end
