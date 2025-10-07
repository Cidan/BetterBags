local bb = GetBetterBags()
local moonlight = GetMoonlight()

--- Describe in a comment what this module does. Note the lower case starting letter -- this denotes a module package accessor.
---@class bagdata
---@field pool Pool
local bagdata = bb:NewClass("bagdata")

--- This is the instance of a module, and where the module
--- functionality actually is. Note the upper case starting letter -- this denotes a module instance.
--- Make sure to define all instance variables here. Private variables start with a lower case, public variables start with an upper case.
---@class Bagdata
---@field sectionSet Sectionset
---@field frame_Scrollbox Scrollbox
---@field allSectionsByName table<string, Section>
---@field allSectionsByItem table<MoonlightItem, Section>
---@field allItemButtonsByItem table<MoonlightItem, MoonlightItemButton>
---@field allItemsByBagAndSlot table<BagID, table<SlotID, MoonlightItem>>
---@field drawCallback fun(fullRedraw: boolean)
---@field config BagDataConfig
local Bagdata = {}

---@return Bagdata
local bagdataConstructor = function()
	local secset = moonlight:GetSectionset():New()
	local sb = moonlight:GetScrollbox():New()
	sb:SetChild(secset)
	local instance = {
		allSectionsByItem = {},
		allSectionsByName = {},
		allItemButtonsByItem = {},
		allItemsByBagAndSlot = {},
		sectionSet = secset,
		frame_Scrollbox = sb,
		-- Define your instance variables here
	}
	return setmetatable(instance, {
		__index = Bagdata,
	})
end

---@param _w Bagdata
local bagdataDeconstructor = function(_w) end

--- This creates a new instance of a module, and optionally, initializes the module.
---@return Bagdata
function bagdata:New()
	local loader = moonlight:GetLoader()
	if self.pool == nil then
		self.pool = moonlight:GetPool():New(bagdataConstructor, bagdataDeconstructor)
	end
	local d = self.pool:TakeOne("Bagdata")
	loader:TellMeWhenABagIsUpdated(function(bags)
		if d.drawCallback == nil then
			error("a draw callback was not set for bag data, did you call RegisterCallbackWhenItemsChange?")
		end
		if d.config == nil then
			error("there is no config for this bag data, did yo call SetConfig?")
		end
		d:theseBagsHaveBeenUpdated(bags)
	end)

	return d
end

---@param c BagDataConfig
function Bagdata:SetConfig(c)
	self.config = c
	if self.config.SectionSetConfig ~= nil then
		self.sectionSet:SetConfig(self.config.SectionSetConfig)
	end
end

function Bagdata:GetMyDrawable()
	return self.frame_Scrollbox
end

function Bagdata:GetMySectionSet()
	return self.sectionSet
end

---@param f fun(fullRedraw: boolean)
function Bagdata:RegisterCallbackWhenItemsChange(f)
	self.drawCallback = f
end

---@param bagID BagID
---@param slotID SlotID
---@return MoonlightItem
function Bagdata:getItemByBagAndSlot(bagID, slotID)
	local item = moonlight:GetItem()
	if self.allItemsByBagAndSlot[bagID] == nil then
		self.allItemsByBagAndSlot[bagID] = {}
	else
		if self.allItemsByBagAndSlot[bagID][slotID] ~= nil then
			return self.allItemsByBagAndSlot[bagID][slotID]
		end
	end
	local mitem = item:New()
	self.allItemsByBagAndSlot[bagID][slotID] = mitem
	return mitem
end

---@param i MoonlightItem
---@return "REDRAW" | "REMOVED" | "NO_OP"
function Bagdata:figureOutWhereAnItemGoes(i)
	local section = moonlight:GetSection()
	local itemButton = moonlight:GetItembutton()
	if i == nil then
		error("i is nil")
	end
	local data = i:GetItemData()
	local oldSection = self.allSectionsByItem[i]

	-- If the item is empty, we need to find its old section and remove its frame.
	if data.Empty then
		if oldSection == nil then
			-- This item was already gone, nothing to do.
			return "NO_OP"
		end

		-- Item is now empty, so remove it but keep the space with a placeholder.
		local frame = self.allItemButtonsByItem[i]
		if frame ~= nil then
			oldSection:RemoveItemButKeepSpace(frame)
			self.allItemButtonsByItem[i] = nil
		end
		self.allSectionsByItem[i] = nil

		if oldSection:GetNumberOfChildren() == 0 and oldSection:IsVisible() == false then
			self.sectionSet:RemoveSection(oldSection)
			self.allSectionsByName[oldSection:GetTitle()] = nil
			oldSection:Release()
			return "REDRAW" -- Section was removed, must redraw.
		end
		return "REMOVED" -- Item removed, but defer redraw.
	end

	-- Item is NOT empty.
	local category = i:GetDisplayCategory()
	local newSection = self.allSectionsByName[category]
	if newSection == nil then
		newSection = section:New()
		newSection:SetTitle(category)
		self.sectionSet:AddSection(newSection)
		self.allSectionsByName[category] = newSection
	end

	local frame = self.allItemButtonsByItem[i]

	if oldSection == newSection then
		-- Item didn't move sections. Just update its frame.
		if frame ~= nil then
			frame:Update()
		else
			-- This case is weird, item exists but has no frame. Create it.
			frame = itemButton:New()
			frame:SetItem(i)
			newSection:AddItem(frame)
			self.allItemButtonsByItem[i] = frame
			return "REDRAW" -- A frame was added.
		end
		return "NO_OP"
	end

	-- Item moved sections or is new.
	if oldSection ~= nil then
		-- It moved.
		if frame ~= nil then
			-- Don't remove items in New Items while the window is visible.
			if oldSection:GetTitle() == "New Items" and oldSection:IsVisible() == true then
				frame:Update()
				return "REMOVED"
			else
				-- Remove without placeholder - item is being relocated, not removed
				oldSection:RemoveItem(frame)
			end
		end
		-- Remove the old section if it no longer contains an item.
		if oldSection:GetNumberOfChildren() == 0 and oldSection:IsVisible() == false then
			self.sectionSet:RemoveSection(oldSection)
			self.allSectionsByName[oldSection:GetTitle()] = nil
			oldSection:Release()
		end
	end

	-- Add to new section.
	if frame == nil then
		frame = itemButton:New()
		frame:SetItem(i)
		self.allItemButtonsByItem[i] = frame
	end

	-- Try to replace a placeholder first, otherwise add normally
	if newSection:TryReplacePlaceholder(frame) == false then
		newSection:AddItem(frame)
	end

	frame:Update()
	self.allSectionsByItem[i] = newSection

	return "REDRAW"
end
---@param i MoonlightItem
---@return "REDRAW" | "REMOVED" | "NO_OP"
function Bagdata:figureOutWhereAnItemGoesWithBagsShown(i)
	local section = moonlight:GetSection()
	local itemButton = moonlight:GetItembutton()

	-- Determine the category (bag name)
	local category = format("%d: %s", i:GetItemData().BagID + 1, i:GetItemData().BagName)

	if category == nil then
		return "NO_OP"
	end

	-- Find or create the section for this bag
	local currentSection = self.allSectionsByName[category]
	if currentSection == nil then
		currentSection = section:New()
		currentSection:SetTitle(category)
		self.sectionSet:AddSection(currentSection)
		self.allSectionsByName[category] = currentSection
	end

	-- Find or create the item button for this slot
	local frame = self.allItemButtonsByItem[i]
	if frame == nil then
		-- If the button is new, create it and add it to the section
		frame = itemButton:New()
		frame:SetItem(i)
		self.allItemButtonsByItem[i] = frame

		-- Try to replace a placeholder first, otherwise add normally
		if currentSection:TryReplacePlaceholder(frame) == false then
			currentSection:AddItem(frame)
		end
	end

	-- Always update the button's appearance
	frame:Update()

	-- Ensure the section is associated with the item
	self.allSectionsByItem[i] = currentSection

	return "REDRAW"
end

---@param item MoonlightItem
---@return "REDRAW" | "REMOVED" | "NO_OP"
function Bagdata:figureOutWhereAnItemGoesWithOneBag(item)
	local sectionModule = moonlight:GetSection()
	local itemButtonModule = moonlight:GetItembutton()
	local data = item:GetItemData()

	local newSectionName = "All Items"
	local categorySection = self.allSectionsByName[newSectionName]
	if categorySection == nil then
		categorySection = sectionModule:New()
		categorySection:SetTitle(newSectionName)
		self.sectionSet:AddSection(categorySection)
		self.allSectionsByName[newSectionName] = categorySection
	end

	local oldCategorySection = self.allSectionsByItem[item]
	local itemButtonFrame = self.allItemButtonsByItem[item]

	-- If the item is empty and we are not showing empty slots, remove it.
	if data.Empty and not self.config.ShowEmptySlots then
		if oldCategorySection == nil then
			return "NO_OP" -- Already gone.
		end

		-- It exists, so remove it but keep the space with a placeholder.
		if itemButtonFrame ~= nil then
			oldCategorySection:RemoveItemButKeepSpace(itemButtonFrame)
			self.allItemButtonsByItem[item] = nil
		end
		self.allSectionsByItem[item] = nil
		-- Unlike other modes, we don't remove the "All Items" section if it becomes empty.
		return "REMOVED"
	end

	-- The item should be shown. This includes non-empty items, and empty items if ShowEmptySlots is true.
	if itemButtonFrame == nil then
		itemButtonFrame = itemButtonModule:New()
		itemButtonFrame:SetItem(item)
		self.allItemButtonsByItem[item] = itemButtonFrame
	end

	if oldCategorySection ~= categorySection then
		if oldCategorySection ~= nil then
			oldCategorySection:RemoveItemButKeepSpace(itemButtonFrame)
		end

		-- Try to replace a placeholder first, otherwise add normally
		if categorySection:TryReplacePlaceholder(itemButtonFrame) == false then
			categorySection:AddItem(itemButtonFrame)
		end

		self.allSectionsByItem[item] = categorySection
	end

	itemButtonFrame:Update()
	return "REDRAW"
end

---@param bagToMixins table<BagID, ItemMixin[]>
function Bagdata:theseBagsHaveBeenUpdated(bagToMixins)
	local stack = bb:GetStack()
	local forceRedraw = false

	-- Filter bags based on BagFilter config if specified
	local filteredBags = {}
	if self.config.BagFilter ~= nil then
		for bagID, mixins in pairs(bagToMixins) do
			if self.config.BagFilter[bagID] == true then
				filteredBags[bagID] = mixins
			end
		end
	else
		filteredBags = bagToMixins
	end

	for bagID, mixins in pairs(filteredBags) do
		-- Loop and update all items first before we attempt to draw them.
		for _, mixin in pairs(mixins) do
			local itemLocation = mixin:GetItemLocation()
			---@diagnostic disable-next-line: need-check-nil
			---@type any, SlotID
			local _, slotID = itemLocation:GetBagAndSlot()
			local mitem = self:getItemByBagAndSlot(bagID, slotID)
			mitem:SetItemMixin(mixin)
			mitem:ReadItemData()
			stack:UpdateStack(mitem.itemData)
		end
	end
	-- Sort all the stacks.
	stack:SortAllStacks()

	for bagID, mixins in pairs(filteredBags) do
		-- Now draw all items that stacks and data are updated.
		for _, mixin in pairs(mixins) do
			local itemLocation = mixin:GetItemLocation()
			---@diagnostic disable-next-line: need-check-nil
			---@type any, SlotID
			local _, slotID = itemLocation:GetBagAndSlot()
			local mitem = self:getItemByBagAndSlot(bagID, slotID)
			local status
			if self.config.CombineAllItems then
				status = self:figureOutWhereAnItemGoesWithOneBag(mitem)
			elseif self.config.BagNameAsSections then
				status = self:figureOutWhereAnItemGoesWithBagsShown(mitem)
			else
				status = self:figureOutWhereAnItemGoes(mitem)
			end
			if status == "REDRAW" then
				forceRedraw = true
			end
		end
	end

	local itemSortFunction = self.config.ItemSortFunction

	-- Sort within each section.
	for _, section in ipairs(self.sectionSet:GetAllSections()) do
		---@type MoonlightItemButton[]
		local children = section:GetChildren()
		table.sort(children, itemSortFunction)

		-- Build set of sort keys already occupied by placeholders.
		-- Performance optimization: Use a Set (Lua table) for O(1) lookups instead of nested O(n²) loop.
		-- Algorithm:
		-- 1. Create a Set of actual item buttons for constant-time membership testing
		-- 2. Check each grid child against the Set to identify placeholders in O(n) time
		local grid = section.grid
		local allGridChildren = grid:GetChildren()
		local occupiedSortKeys = {}

		-- First, create a Set of actual item buttons for O(1) lookup
		local itemButtonSet = {}
		for _, itemButton in ipairs(children) do
			itemButtonSet[itemButton] = true
		end

		-- Now identify placeholders in O(n) time instead of O(n²)
		for _, child in ipairs(allGridChildren) do
			-- Check if this child is a placeholder by checking Set membership
			-- Per patterns.md: use explicit comparison instead of implicit truthiness
			if itemButtonSet[child] ~= true then
				occupiedSortKeys[child:GetSortKey()] = true
			end
		end

		-- Assign sort keys to items, skipping positions occupied by placeholders
		local nextSortKey = 1
		for _, button in ipairs(children) do
			-- Skip sort keys occupied by placeholders
			while occupiedSortKeys[nextSortKey] ~= nil do
				nextSortKey = nextSortKey + 1
			end
			button:SetSortKey(nextSortKey)
			nextSortKey = nextSortKey + 1
		end
	end

	self.drawCallback(forceRedraw)
end

function Bagdata:RemoveUnusedSections()
	for name, section in pairs(self.allSectionsByName) do
		if section:GetNumberOfChildren() == 0 then
			self.sectionSet:RemoveSection(section)
			self.allSectionsByName[name] = nil
			section:Release()
		end
	end
end
