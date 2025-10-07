local bb = GetBetterBags()
local moonlight = GetMoonlight()

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
	Backpack.bagWidth = 300
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
		BagFilter = {
			[0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true -- Backpack bags only
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
		BagFilter = {
			[0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true -- Backpack bags only
		},
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
		BagFilter = {
			[0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true -- Backpack bags only
		},
		SectionSetConfig = {
			SectionOffset = 4,
			Columns = 1,
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
		Icon = [[interface/icons/inv_misc_bag_08.blp]],
		Title = format("%s's Backpack", UnitName("player")),
	})

	Backpack.container:AddChild({
		Name = "Bags",
		Drawable = bagView:GetMyDrawable(),
		Icon = [[interface/icons/inv_misc_bag_08.blp]],
		Title = format("All Bags"),
	})

	Backpack.container:AddChild({
		Name = "Everything",
		Drawable = oneView:GetMyDrawable(),
		Icon = [[interface/icons/inv_misc_bag_08.blp]],
		Title = "All Items",
	})

	Backpack.container:CreateTabsForThisContainer({
		Point = {
			Point = "TOPLEFT",
			RelativeTo = Backpack.window:GetFrame(),
			RelativePoint = "BOTTOMLEFT",
			XOffset = 10,
			YOffset = -2,
		},
		Spacing = 4,
		Orientation = "HORIZONTAL",
		GrowDirection = "RIGHT",
		TooltipAnchor = "ANCHOR_LEFT",
		HoverAnimationDistance = 3,  -- Distance in pixels for hover animation
		HoverAnimationDuration = 0.1,  -- Duration in seconds for hover animation
		SelectedAnimationDistance = 7,  -- Distance in pixels for selected tab animation
	})

	Backpack.window:SetWidth(Backpack.bagWidth)
	Backpack.window:SetHeight(500)
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
		for _, view in pairs(self.views) do
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
