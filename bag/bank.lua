local bb = GetBetterBags()
local moonlight = GetMoonlight()
local bagconst = bb:GetBagConstants()

--- Bank module provides character bank and account-wide warband bank functionality for BetterBags.
---@class bank
local bank = bb:NewClass("bank")

---@class (exact) Bank: Bag
---@field container Container
---@field bagWidth number
---@field views table<string, Bagdata>
---@field currentBankType Enum.BankType
local Bank = {}

---@return Bank
function bank:GetBank()
	return Bank
end

--- Boot creates the bank bag with character and account bank views.
function bank:Boot()
	Bank.bagWidth = bagconst.BANK_DEFAULT_WIDTH
	local window = moonlight:GetWindow()
	local engine = moonlight:GetSonataEngine()
	local container = moonlight:GetContainer()
	local bagData = bb:GetBagdata()

	Bank.views = {}
	Bank.currentBankType = Enum.BankType.Character
	Bank.window = window:New("bank")

	-- Create container first (tabs will be created when bank opens)
	Bank.container = container:New()
	Bank.container:Apply(Bank.window)

	-- Set window properties (left side of screen, opposite backpack)
	Bank.window:SetWidth(Bank.bagWidth)
	Bank.window:SetHeight(bagconst.DEFAULT_WINDOW_HEIGHT)
	Bank.window:SetPoint({
		Point = "LEFT",
		RelativeTo = UIParent,
		RelativePoint = "LEFT",
		XOffset = bagconst.BANK_LEFT_OFFSET,
	})
	Bank.window:SetStrata("FULLSCREEN")

	-- Register with theme engine
	engine:RegisterBag(Bank)

	Bank:BindBankShowAndHideEvents()
	Bank.window:Hide(true)
end

function Bank:RefreshTabs()
	local window = moonlight:GetWindow()
	local bagData = bb:GetBagdata()

	-- Fetch bank tabs from API (only available when bank is open)
	local characterBankTabData = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)
	local accountBankTabData = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account)

	-- Sort tabs by bag ID (numerical order)
	if characterBankTabData ~= nil then
		table.sort(characterBankTabData, function(a, b) return a.ID < b.ID end)
	end
	if accountBankTabData ~= nil then
		table.sort(accountBankTabData, function(a, b) return a.ID < b.ID end)
	end

	-- Create individual views for each character bank tab
	if characterBankTabData ~= nil then
		for _, tabData in ipairs(characterBankTabData) do
			local viewName = format("CharBank_%d", tabData.ID)

			-- Only create if this view doesn't exist yet
			if self.views[viewName] == nil then
				local view = bagData:New()
				view:SetConfig({
					BagNameAsSections = false,
					ShowEmptySlots = false,
					StackSimilarItems = true,
					CombineAllItems = false,
					BagFilter = {
						[tabData.ID] = true -- Only this specific bank tab
					},
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

				self.views[viewName] = view

				-- Register callback
				view:RegisterCallbackWhenItemsChange(function(fullRedraw)
					if self.window:IsVisible() and not fullRedraw then
						return
					end
					if self.container:GetActiveChildName() ~= viewName then
						return
					end
					window:RenderAWindowByName("bank")
				end)

				-- Add as container child with API-provided name and icon
				self.container:AddChild({
					Name = viewName,
					Drawable = view:GetMyDrawable(),
					Icon = tabData.icon,
					Title = tabData.name,
					Tooltip = tabData.name,
					SortKey = tabData.ID,
					OnTabClick = function()
						-- Set bank type to Character when clicking character bank tabs
						if BankPanel ~= nil and BankPanel.SetBankType ~= nil then
							BankPanel:SetBankType(Enum.BankType.Character)
						end
					end,
				})
			end
		end
	end

	-- Create individual views for each account bank (warband) tab
	if accountBankTabData ~= nil then
		for _, tabData in ipairs(accountBankTabData) do
			local viewName = format("Warband_%d", tabData.ID)

			-- Only create if this view doesn't exist yet
			if self.views[viewName] == nil then
				local view = bagData:New()
				view:SetConfig({
					BagNameAsSections = false,
					ShowEmptySlots = false,
					StackSimilarItems = true,
					CombineAllItems = false,
					BagFilter = {
						[tabData.ID] = true -- Only this specific warband tab
					},
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

				self.views[viewName] = view

				-- Register callback
				view:RegisterCallbackWhenItemsChange(function(fullRedraw)
					if self.window:IsVisible() and not fullRedraw then
						return
					end
					if self.container:GetActiveChildName() ~= viewName then
						return
					end
					window:RenderAWindowByName("bank")
				end)

				-- Add as container child with API-provided name and icon
				self.container:AddChild({
					Name = viewName,
					Drawable = view:GetMyDrawable(),
					Icon = tabData.icon,
					Title = tabData.name,
					Tooltip = tabData.name,
					SortKey = tabData.ID,
					OnTabClick = function()
						-- Set bank type to Account when clicking warband bank tabs
						if BankPanel ~= nil and BankPanel.SetBankType ~= nil then
							BankPanel:SetBankType(Enum.BankType.Account)
						end
					end,
				})
			end
		end
	end

	-- Create or update tabs UI
	if self.container.tab == nil then
		-- First time: create tabs
		self.container:CreateTabsForThisContainer({
			Point = {
				Point = "TOPLEFT",
				RelativeTo = self.window:GetFrame(),
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
	else
		-- Subsequent times: update existing tabs
		self.container:UpdateContainerTabs()
	end

	-- Set section sort functions
	for _, view in pairs(self.views) do
		view:GetMySectionSet():SetSortFunction(function(a, b)
			return a:GetTitle() < b:GetTitle()
		end)
	end

	-- Switch to first available tab
	if characterBankTabData ~= nil and characterBankTabData[1] ~= nil then
		local firstTabName = format("CharBank_%d", characterBankTabData[1].ID)
		self.container:SwitchToChild(firstTabName)
	elseif accountBankTabData ~= nil and accountBankTabData[1] ~= nil then
		local firstTabName = format("Warband_%d", accountBankTabData[1].ID)
		self.container:SwitchToChild(firstTabName)
	end
end

function Bank:BindBankShowAndHideEvents()
	local event = moonlight:GetEvent()
	local loader = moonlight:GetLoader()

	-- Listen for bank opened event
	event:ListenForEvent("BANKFRAME_OPENED", function()
		-- Refresh tabs first (API data only available when bank is open)
		self:RefreshTabs()

		-- Scan bank bags so we have item mixins ready
		loader:ScanAllBankBags()

		-- Refresh bank data to populate items
		loader:FullRefreshAllBagData()

		-- Show BankPanel invisibly to prevent taint (per patterns.md)
		if BankPanel ~= nil then
			BankPanel:Show()
			if BankPanel.SetBankType ~= nil then
				BankPanel:SetBankType(Enum.BankType.Character)
			end
		end

		-- Show our bank window
		C_Timer.After(0, function()
			self:Show()
		end)
	end)

	-- Listen for bank closed event
	event:ListenForEvent("BANKFRAME_CLOSED", function()
		-- Hide BankPanel to prevent taint affecting other operations
		if BankPanel ~= nil then
			BankPanel:Hide()
		end

		-- Hide our bank window
		C_Timer.After(0, function()
			self:Hide()
		end)
	end)
end

function Bank:GetFrame()
	return self.window:GetFrame()
end

---@param b SonataBag
function Bank:SetDecoration(b)
	self.window:SetDecoration(b)
end

function Bank:Redraw()
	local render = moonlight:GetRender()
	render:NewRenderChain(self.container, { OnlyRedraw = false })
	self.isDirty = false
end

function Bank:Hide(doNotAnimate)
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

function Bank:Show(doNotAnimate)
	if self.window:IsVisible() == true then
		return
	end
	self.window:Show(doNotAnimate)
end

function Bank:GetTitle()
	return self.window:GetTitle()
end

function Bank:GetWindow()
	return self.window
end

function Bank:GetName()
	return self:GetFrame():GetName()
end
