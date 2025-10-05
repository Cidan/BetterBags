---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)

---@class ContextMenu: AceModule
---@field frame Frame
local contextMenu = addon:NewModule("ContextMenu")

---@class Constants: AceModule
local const = addon:GetModule("Constants")

---@class Database: AceModule
local database = addon:GetModule("Database")

---@class SliderFrame: AceModule
local slider = addon:GetModule("Slider")

---@class Categories: AceModule
local categories = addon:GetModule("Categories")

---@class Events: AceModule
local events = addon:GetModule("Events")

---@class Items: AceModule
local items = addon:GetModule("Items")

---@class Localization: AceModule
local L = addon:GetModule("Localization")

---@class Context: AceModule
local context = addon:GetModule("Context")

local LibDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")

---@class (exact) MenuList
---@field text string
---@field value? any
---@field checked? boolean|function
---@field isNotRadio? boolean
---@field isTitle? boolean
---@field disabled? boolean
---@field tooltipTitle? string
---@field tooltipText? string
---@field func? function
---@field notCheckable? boolean
---@field hasArrow? boolean
---@field menuList? MenuList[]
---@field keepShownOnClick? boolean
---@field tooltipOnButton? boolean
local menuListProto = {}

function contextMenu:OnInitialize()
	self.sabt = {}
	--self:CreateContext()
end

function contextMenu:GetPurchaseSabt(title, bankType)
	if self.sabt[title] ~= nil then
		return self.sabt[title]
	end
	local clickFrame = CreateFrame("Frame", nil, nil, "UIDropDownCustomMenuEntryTemplate")
	clickFrame:SetWidth(120)
	clickFrame:SetHeight(16)

	local p = CreateFrame("Button", nil, clickFrame, "BankPanelPurchaseButtonScriptTemplate")
	p:SetAttribute("overrideBankType", bankType)
	p:SetAllPoints()

	local text1 = p:CreateFontString(name and (name .. "NormalText") or nil)
	p:SetFontString(text1)
	text1:SetPoint("LEFT", p, 0, 0)
	p:SetNormalFontObject("GameFontHighlightSmallLeft")
	p:SetHighlightFontObject("GameFontHighlightSmallLeft")
	p:SetDisabledFontObject("GameFontDisableSmallLeft")

	p.Highlight = p:CreateTexture(name and (name .. "Highlight") or nil, "BACKGROUND")
	p.Highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	p.Highlight:SetBlendMode("ADD")
	p.Highlight:SetAllPoints()
	p.Highlight:Hide()

	p:SetScript("OnEnter", function()
		p.Highlight:Show()
	end)
	p:SetScript("OnLeave", function()
		p.Highlight:Hide()
	end)
	p:SetText(title)
	self.sabt[title] = clickFrame
	return clickFrame
end

function contextMenu:OnEnable()
	local frame = LibDD:Create_UIDropDownMenu("BetterBagsContextMenu", UIParent)
	LibDD:EasyMenu_Initialize(frame, 4, {})
	self.frame = frame
end

---@param ctx Context
---@param menuList MenuList[]
function contextMenu:Show(ctx, menuList)
	LibDD:EasyMenu(menuList, self.frame, "cursor", 0, 0, "MENU")
	events:SendMessage(ctx, "context/show")
end

---@param ctx Context
function contextMenu:Hide(ctx)
	LibDD:HideDropDownMenu(1)
	events:SendMessage(ctx, "context/hide")
end

function contextMenu:AddDivider(menuList)
	table.insert(menuList, {
		text = "",
		isTitle = true,
		hasArrow = false,
		notCheckable = true,
		iconOnly = true,
		isUninteractable = true,
		icon = "Interface\\Common\\UI-TooltipDivider-Transparent",
		iconInfo = {
			tCoordLeft = 0,
			tCoordRight = 1,
			tCoordTop = 0,
			tCoordBottom = 1,
			tSizeX = 0,
			tSizeY = 8,
			tFitDropDownSizeX = true,
		},
	})
end

---@param menu MenuList[]
local function enableTooltips(menu)
	for _, m in ipairs(menu) do
		m.tooltipOnButton = true
		if m.menuList then
			enableTooltips(m.menuList)
		end
	end
end

---@param bag Bag
---@return MenuList[]
function contextMenu:CreateContextMenu(bag)
	---@type MenuList[]
	local menuList = {}

	-- Context Menu title.
	table.insert(menuList, {
		--@debug@
		text = addonName .. " Dev Mode",
		--@end-debug@
		--[===[@non-debug@
		text = addonName..' @project-version@',
		--@end-non-debug@]===]
		isTitle = true,
		notCheckable = true,
	})

	table.insert(menuList, {
		text = L:G("Bag Anchor"),
		notCheckable = true,
		hasArrow = true,
		menuList = {
			{
				text = L:G("Enable"),
				notCheckable = false,
				checked = function()
					return bag.anchor:IsActive()
				end,
				func = function()
					local ctx = context:New("ToggleAnchor")
					bag.anchor:ToggleActive()
					contextMenu:Hide(ctx)
				end,
			},
			{
				text = L:G("Show"),
				notCheckable = false,
				checked = function()
					return bag.anchor.frame:IsShown()
				end,
				func = function()
					local ctx = context:New("ToggleAnchor")
					bag.anchor:ToggleShown()
					contextMenu:Hide(ctx)
				end,
			},
			{
				text = L:G("Manual Anchor"),
				notCheckable = true,
				hasArrow = true,
				menuList = {
					{
						text = L:G("Top Left"),
						notCheckable = false,
						checked = function()
							return database:GetAnchorState(bag.kind).staticPoint == "TOPLEFT"
						end,
						func = function()
							local ctx = context:New("SetStaticAnchorPoint")
							bag.anchor:SetStaticAnchorPoint("TOPLEFT")
							contextMenu:Hide(ctx)
						end,
					},
					{
						text = L:G("Top Right"),
						notCheckable = false,
						checked = function()
							return database:GetAnchorState(bag.kind).staticPoint == "TOPRIGHT"
						end,
						func = function()
							local ctx = context:New("SetStaticAnchorPoint")
							bag.anchor:SetStaticAnchorPoint("TOPRIGHT")
							contextMenu:Hide(ctx)
						end,
					},
					{
						text = L:G("Bottom Left"),
						notCheckable = false,
						checked = function()
							return database:GetAnchorState(bag.kind).staticPoint == "BOTTOMLEFT"
						end,
						func = function()
							local ctx = context:New("SetStaticAnchorPoint")
							bag.anchor:SetStaticAnchorPoint("BOTTOMLEFT")
							contextMenu:Hide(ctx)
						end,
					},
					{
						text = L:G("Bottom Right"),
						notCheckable = false,
						checked = function()
							return database:GetAnchorState(bag.kind).staticPoint == "BOTTOMRIGHT"
						end,
						func = function()
							local ctx = context:New("SetStaticAnchorPoint")
							bag.anchor:SetStaticAnchorPoint("BOTTOMRIGHT")
							contextMenu:Hide(ctx)
						end,
					},
					{
						text = L:G("Automatic"),
						notCheckable = false,
						checked = function()
							return database:GetAnchorState(bag.kind).staticPoint == nil
						end,
						func = function()
							local ctx = context:New("SetStaticAnchorPoint")
							bag.anchor:SetStaticAnchorPoint(nil)
							contextMenu:Hide(ctx)
						end,
					},
				},
			},
		},
	})

	if bag.kind == const.BAG_KIND.BANK then
		-- Add character bank tabs toggle
		if addon.isRetail then
			table.insert(menuList, {
				text = L:G("Show Character Bank Tabs"),
				checked = function()
					return database:GetCharacterBankTabsEnabled()
				end,
				tooltipTitle = L:G("Show Character Bank Tabs"),
				tooltipText = L:G(
					"Display individual tabs for each character bank slot instead of a single Bank tab. Requires UI reload."
				),
				func = function()
					database:SetCharacterBankTabsEnabled(not database:GetCharacterBankTabsEnabled())
					-- Reload UI to ensure clean state
					C_UI.Reload()
				end,
			})
		end

		if C_Bank.HasMaxBankTabs(Enum.BankType.Account) == false then
			table.insert(menuList, {
				text = L:G("Purchase Warbank Tab"),
				notCheckable = true,
				tooltipTitle = L:G("Purchase Warbank Tab"),
				tooltipText = L:G("Purchase a new Warbank tab"),
				customFrame = self:GetPurchaseSabt("Purchase Warbank Tab", Enum.BankType.Account),
			})
		end
		if C_Bank.HasMaxBankTabs(Enum.BankType.Character) == false then
			table.insert(menuList, {
				text = L:G("Purchase Character Tab"),
				notCheckable = true,
				tooltipTitle = L:G("Purchase Character Tab"),
				tooltipText = L:G("Purchase a new Character tab"),
				customFrame = self:GetPurchaseSabt("Purchase Bank Tab", Enum.BankType.Bank),
			})
		end
		table.insert(menuList, {
			text = L:G("Sort Bank"),
			notCheckable = true,
			tooltipTitle = L:G("Sort Bank"),
			tooltipText = L:G("Click to sort the bank."),
			func = function()
				PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)
				C_Bank.AutoDepositItemsIntoBank(Enum.BankType.Character)
				C_Container.SortBankBags()
			end,
		})
		table.insert(menuList, {
			text = L:G("Clean Up Warbank"),
			notCheckable = true,
			tooltipTitle = L:G("Clean Up Warbank"),
			tooltipText = L:G("Click to clean up your Warbanks and resort items into correct tabs."),
			func = function()
				PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)
				C_Container.SortAccountBankBags()
			end,
		})
	end

	-- Show bag slot toggle (only if slots are available).
	if bag.slots then
		table.insert(menuList, {
			text = L:G("Show Bags"),
			checked = function()
				return bag.slots and bag.slots:IsShown()
			end,
			tooltipTitle = L:G("Show Bags"),
			tooltipText = L:G("Click to toggle the display of the bag slots."),
			func = function()
				if InCombatLockdown() then
					print("BetterBags: " .. L:G("Cannot toggle bag slots in combat."))
					return
				end
				if not bag.slots then
					return
				end
				local ctx = context:New("ToggleBagSlots")
				if bag.slots and bag.slots:IsShown() then
					bag.slots:Hide()
				elseif bag.slots then
					bag.slots:Draw(ctx)
					bag.slots:Show()
				end
			end,
		})
	end

	if bag.kind == const.BAG_KIND.BACKPACK then
		-- Show bag slot toggle.
		table.insert(menuList, {
			text = L:G("Show Currencies"),
			checked = function()
				return bag.currencyFrame:IsShown()
			end,
			tooltipTitle = L:G("Show Currencies"),
			tooltipText = L:G("Click to toggle the display of the currencies side panel."),
			func = function()
				if bag.currencyFrame:IsShown() then
					bag.currencyFrame:Hide()
				else
					bag.windowGrouping:Show("currencyConfig")
				end
			end,
		})
	end

	-- Show bag slot toggle.
	table.insert(menuList, {
		text = L:G("Configure Categories"),
		checked = function()
			return bag.sectionConfigFrame:IsShown()
		end,
		tooltipTitle = L:G("Configure Categories"),
		tooltipText = L:G("Click to toggle the display of the category configuration side panel."),
		func = function()
			if bag.sectionConfigFrame:IsShown() then
				bag.sectionConfigFrame:Hide()
			else
				bag.windowGrouping:Show("sectionConfig")
			end
		end,
	})

	if bag.kind == const.BAG_KIND.BACKPACK then
		-- Show theme selection window.
		table.insert(menuList, {
			text = L:G("Themes"),
			checked = function()
				return bag.themeConfigFrame:IsShown()
			end,
			tooltipTitle = L:G("Themes"),
			tooltipText = L:G("Click to toggle the display of the theme configuration side panel."),
			func = function()
				if bag.themeConfigFrame:IsShown() then
					bag.themeConfigFrame:Hide()
				else
					bag.windowGrouping:Show("themeConfig")
				end
			end,
		})

		-- Show the Blizzard bag button toggle.
		table.insert(menuList, {
			text = L:G("Show Bag Button"),
			tooltipTitle = L:G("Show Bag Button"),
			tooltipText = L:G("Click to toggle the display of the Blizzard bag button."),
			checked = function()
				local sneakyFrame = _G["BetterBagsSneakyFrame"] ---@type Frame
				return BagsBar:GetParent() ~= sneakyFrame
			end,
			func = function()
				local sneakyFrame = _G["BetterBagsSneakyFrame"] ---@type Frame
				local isShown = BagsBar:GetParent() ~= sneakyFrame
				if isShown then
					BagsBar:SetParent(sneakyFrame)
				else
					BagsBar:SetParent(UIParent)
				end
				database:SetShowBagButton(not isShown)
			end,
		})
	end

	table.insert(menuList, {
		text = L:G("Open Options Screen"),
		notCheckable = true,
		tooltipTitle = L:G("Open Options Screen"),
		tooltipText = L:G("Click to open the options screen."),
		func = function()
			local ctx = context:New("OpenOptions")
			contextMenu:Hide(ctx)
			events:SendMessage(ctx, "config/Open")
		end,
	})

	table.insert(menuList, {
		text = L:G("Close Menu"),
		notCheckable = true,
		func = function()
			local ctx = context:New("CloseMenu")
			contextMenu:Hide(ctx)
		end,
	})
	enableTooltips(menuList)
	return menuList
end
