local bb = GetBetterBags()
local moonlight = GetMoonlight()
local bagconst = bb:GetBagConstants()

--- Describe in a comment what this module does. Note the lower case starting letter -- this denotes a module package accessor.
---@class backpack
local backpack = bb:NewClass("backpack")

---@class (exact) Backpack: Bag
---@field container Container
---@field bagWidth number
---@field views table<string, Bagdata>
local Backpack = {}

---@return Backpack
function backpack:GetBackpack()
	return Backpack
end
--- Boot creates the backpack bag.
function backpack:Boot()
	Backpack.bagWidth = bagconst.BACKPACK_DEFAULT_WIDTH
	local window = moonlight:GetWindow()
	local engine = moonlight:GetSonataEngine()
	local container = moonlight:GetContainer()
	local bagData = bb:GetBagdata()
	local popup = moonlight:GetPopup()
	Backpack.views = {}
	Backpack.window = window:New("backpack")
	local tf = Backpack:GetWindow():GetFrame()
	tf:SetScript("OnMouseDown", function()
		popup:Display({
			Title = "BetterBags Options",
			Elements = {
				[1] = {
					Type = "item",
					CloseOnClick = true,
					Title = "Disable",
					CanToggle = false,
				},
				[2] = {
					Type = "divider",
					CanToggle = false,
					CloseOnClick = false,
					Title = "doot",
				},
			},
		})
	end)
	local sectionView = bagData:New()
	local bagView = bagData:New()
	local oneView = bagData:New()

	Backpack.views["SectionView"] = sectionView
	Backpack.views["BagView"] = bagView
	Backpack.views["OneView"] = oneView

	sectionView:SetConfig({
		BagNameAsSections = false,
		ShowEmptySlots = false,
		StackSimilarItems = true,
		CombineAllItems = false,
		BagFilter = bagconst.ALL_BACKPACK_BAGS,
		SectionSetConfig = {
			SectionOffset = bagconst.DEFAULT_SECTION_OFFSET,
			Columns = bagconst.DEFAULT_SECTION_COLUMNS_TWO,
			HeaderSections = {bagconst.NEW_ITEMS_SECTION}
		},
		ItemSortFunction = function(a, b)
			local adata = a:GetItemData()
			local bdata = b:GetItemData()
			return adata.itemData.ItemName > bdata.itemData.ItemName
		end,
	})

	bagView:SetConfig({
		BagNameAsSections = true,
		ShowEmptySlots = true,
		StackSimilarItems = false,
		CombineAllItems = false,
		BagFilter = bagconst.ALL_BACKPACK_BAGS,
		ItemSortFunction = function(a, b)
			local adata = a:GetItemData()
			local bdata = b:GetItemData()
			return adata.itemData.SlotID > bdata.itemData.SlotID
		end,
	})

	oneView:SetConfig({
		BagNameAsSections = false,
		ShowEmptySlots = true,
		StackSimilarItems = false,
		CombineAllItems = true,
		BagFilter = bagconst.ALL_BACKPACK_BAGS,
		SectionSetConfig = {
			SectionOffset = bagconst.DEFAULT_SECTION_OFFSET,
			Columns = bagconst.DEFAULT_SECTION_COLUMNS_ONE,
		},
		ItemSortFunction = function(a, b)
			local adata = a:GetItemData()
			local bdata = b:GetItemData()
			if adata.itemData.BagID == bdata.itemData.BagID then
				return adata.itemData.SlotID > bdata.itemData.SlotID
			end
			return adata.itemData.BagID > bdata.itemData.BagID
		end,
	})

	sectionView:RegisterCallbackWhenItemsChange(function(fullRedraw)
		if Backpack.window:IsVisible() and not fullRedraw then
			return
		end
		if Backpack.container:GetActiveChildName() ~= "Backpack" then
			return
		end
		window:RenderAWindowByName("backpack")
		--Backpack.container:RecalculateHeight()
	end)

	bagView:RegisterCallbackWhenItemsChange(function(fullRedraw)
		if Backpack.window:IsVisible() and not fullRedraw then
			return
		end
		if Backpack.container:GetActiveChildName() ~= "Bags" then
			return
		end
		window:RenderAWindowByName("backpack")
		--Backpack.container:RecalculateHeight()
	end)

	oneView:RegisterCallbackWhenItemsChange(function(fullRedraw)
		if Backpack.window:IsVisible() and not fullRedraw then
			return
		end
		if Backpack.container:GetActiveChildName() ~= "Everything" then
			return
		end
		window:RenderAWindowByName("backpack")
		--Backpack.container:RecalculateHeight()
	end)

	Backpack.container = container:New()
	Backpack.container:Apply(Backpack.window)
	Backpack.container:AddChild({
		Name = "Backpack",
		Drawable = sectionView:GetMyDrawable(),
		Icon = bagconst.DEFAULT_BAG_ICON,
		Title = format("%s's Backpack", UnitName("player")),
	})

	Backpack.container:AddChild({
		Name = "Bags",
		Drawable = bagView:GetMyDrawable(),
		Icon = bagconst.DEFAULT_BAG_ICON,
		Title = format("All Bags"),
	})

	Backpack.container:AddChild({
		Name = "Everything",
		Drawable = oneView:GetMyDrawable(),
		Icon = bagconst.DEFAULT_BAG_ICON,
		Title = bagconst.ALL_ITEMS_SECTION,
	})

	Backpack.container:CreateTabsForThisContainer({
		Point = {
			Point = "TOPLEFT",
			RelativeTo = Backpack.window:GetFrame(),
			RelativePoint = "BOTTOMLEFT",
			XOffset = bagconst.TAB_HORIZONTAL_OFFSET,
			YOffset = bagconst.TAB_VERTICAL_OFFSET,
		},
		Spacing = bagconst.TAB_SPACING,
		Orientation = "HORIZONTAL",
		GrowDirection = "RIGHT",
		TooltipAnchor = "ANCHOR_LEFT",
		HoverAnimationDistance = bagconst.TAB_HOVER_ANIMATION_DISTANCE,
		HoverAnimationDuration = bagconst.TAB_HOVER_ANIMATION_DURATION,
		SelectedAnimationDistance = bagconst.TAB_SELECTED_ANIMATION_DISTANCE,
	})

	Backpack.window:SetWidth(Backpack.bagWidth)
	Backpack.window:SetHeight(bagconst.DEFAULT_WINDOW_HEIGHT)
	Backpack.window:SetPoint({
		Point = "RIGHT",
		RelativeTo = UIParent,
		RelativePoint = "RIGHT",
	})
	Backpack.window:SetStrata("FULLSCREEN")

	engine:RegisterBag(Backpack)

	Backpack:SetSectionSortFunction()
	Backpack:BindBagShowAndHideEvents()

	Backpack.container:SwitchToChild("Backpack")
	Backpack.window:Hide(true)
end

function Backpack:SetSectionSortFunction()
	for _, view in pairs(self.views) do
		view:GetMySectionSet():SetSortFunction(function(a, b)
			return a:GetTitle() < b:GetTitle()
		end)
	end
end

function Backpack:BindBagShowAndHideEvents()
	local binds = bb:GetBinds()
	binds:OnBagToggle(function()
		if self.window:IsVisible() then
			C_Timer.After(0, function()
				self:Hide()
			end)
		else
			C_Timer.After(0, function()
				self:Show()
			end)
		end
	end)
end

function Backpack:GetFrame()
	return self.window:GetFrame()
end

---@param b SonataBag
function Backpack:SetDecoration(b)
	self.window:SetDecoration(b)
end

function Backpack:Redraw()
	local render = moonlight:GetRender()
	render:NewRenderChain(self.container, { OnlyRedraw = false })
	self.isDirty = false
end

function Backpack:Hide(doNotAnimate)
	if self.window:IsVisible() == false then
		return
	end
	self.window:Hide(doNotAnimate)
	-- TODO(lobato): Add callback support to Drawable Hide and Show
	C_Timer.After(1, function()
		-- Check if bag was reopened during timer - if so, don't clean up placeholders
		if self.window:IsVisible() == true then
			return
		end
		for _, view in pairs(self.views) do
			-- Clear all placeholders from sections when bag closes
			local sectionSet = view:GetMySectionSet()
			for _, section in ipairs(sectionSet:GetAllSections()) do
				section:ForceFullRedraw()
			end
			view:RemoveUnusedSections()
		end
		self:Redraw()
	end)
end

function Backpack:Show(doNotAnimate)
	if self.window:IsVisible() == true then
		return
	end
	self.window:Show(doNotAnimate)
end

function Backpack:GetTitle()
	return self.window:GetTitle()
end
function Backpack:GetWindow()
	return self.window
end

function Backpack:GetName()
	return self:GetFrame():GetName()
end
