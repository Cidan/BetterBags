local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Render: AceModule
local render = addon:GetModule('Render')

---@class DrawableModule: AceModule
local drawable = addon:GetModule('Drawable')

---@class WindowModule: AceModule
local window = addon:GetModule('Window')

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Context: AceModule
local context = addon:GetModule('Context')

-- The dialog's text is this wide; its content box is this wide (the window 300).
local TEXT_WIDTH = 250
local BODY_WIDTH = 296
-- The content's height around the text, with and without the bank type dropdown.
local BODY_PADDING = 86
local BODY_PADDING_WITH_DROPDOWN = 116

-- The group dialog is a Panel window (window/window.lua) whose content is its body: the text,
-- the name box, the bank type dropdown and the buttons, sized to the text.
---@class (exact) GroupDialog: AceModule
---@field window BetterBagsWindow
---@field body Drawable
---@field frame Frame
---@field text FontString
---@field yes Button|UIPanelButtonTemplate
---@field no Button|UIPanelButtonTemplate
---@field input EditBox|InputBoxTemplate
---@field dropdown Frame
---@field open boolean
---@field bankType number
local groupDialog = addon:NewModule('GroupDialog')

function groupDialog:Initialize()
	if self.frame then return end

	self.bankType = Enum.BankType and Enum.BankType.Character or 1

	self.window = window:Create({
		Kind = "Panel",
		Name = "BetterBagsGroupDialog",
		Title = L:G("New Group"),
		Strata = "DIALOG",
		Level = 600,
		Movable = false,
		Fade = function() return false end,
		Opacity = function()
			return database:GetBagSizeInfo(const.BAG_KIND.BACKPACK, database:GetBagView(const.BAG_KIND.BACKPACK)).opacity
		end,
		OnHide = function()
			self.open = false
		end,
	})
	self.frame = self.window.frame

	local f = CreateFrame('Frame')
	self.body = drawable:Create(self.bodyProto, { frame = f })

	self.text = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	self.text:SetTextColor(1, 1, 1)
	self.text:SetPoint('TOP', 0, 0)
	self.text:SetWidth(TEXT_WIDTH)
	self.text:SetWordWrap(true)
	self.text:SetJustifyH("CENTER")

	self.input = CreateFrame('EditBox', nil, f, "InputBoxTemplate")
	self.input:SetWidth(200)
	self.input:SetHeight(20)

	self.dropdown = CreateFrame("Frame", "BetterBagsGroupDialogDropdown", f, "UIDropDownMenuTemplate")
	UIDropDownMenu_SetWidth(self.dropdown, 120)

	self.yes = CreateFrame('Button', nil, f, "UIPanelButtonTemplate")
	self.no = CreateFrame('Button', nil, f, "UIPanelButtonTemplate")
	self.yes:SetWidth(100)
	self.no:SetWidth(100)
	self.yes:SetText(L:G("Create"))
	self.no:SetText(L:G("Cancel"))
	self.yes:SetPoint("BOTTOMLEFT", 36, 11)
	self.no:SetPoint("BOTTOMRIGHT", -40, 11)
	sonata:RegisterElement("Button", self.yes)
	sonata:RegisterElement("Button", self.no)
	sonata:RegisterElement("EditBox", self.input)

	self.input:SetScript("OnEscapePressed", function()
		self:Hide()
	end)
	self.input:SetAutoFocus(false)

	self.no:SetScript("OnClick", function()
		self:Hide()
	end)

	UIDropDownMenu_Initialize(self.dropdown, function()
		local info = UIDropDownMenu_CreateInfo()
		info.text = L:G("Bank")
		info.func = function()
			UIDropDownMenu_SetText(self.dropdown, L:G("Bank"))
			self.bankType = Enum.BankType and Enum.BankType.Character or 1
		end
		UIDropDownMenu_AddButton(info)

		if addon.hasWarbank then
			local info2 = UIDropDownMenu_CreateInfo()
			info2.text = L:G("Warbank")
			info2.func = function()
				UIDropDownMenu_SetText(self.dropdown, L:G("Warbank"))
				self.bankType = Enum.BankType and Enum.BankType.Account or 2
			end
			UIDropDownMenu_AddButton(info2)
		end
	end)
	self.window:SetContent(self.body)
end

---@class (exact) GroupDialogBody: Drawable
groupDialog.bodyProto = drawable:Extend({}, 'GroupDialogBody')

---@return RenderPlan
function groupDialog.bodyProto:GetRenderPlan()
	return { Plan = { { step = render.SELF } } }
end

---@return RenderResult
function groupDialog.bodyProto:Render()
	local text = groupDialog.text
	text:SetWidth(TEXT_WIDTH)
	local textHeight = text:GetStringHeight()
	text:SetHeight(textHeight)
	local padding = groupDialog.dropdown:IsShown() and BODY_PADDING_WITH_DROPDOWN or BODY_PADDING
	return { Width = BODY_WIDTH, Height = padding + textHeight }
end

-- Hide closes the dialog. Its frame's OnHide also marks it closed, for the close button.
function groupDialog:Hide()
	self.open = false
	if self.window then
		self.window:Hide(context:New('GroupDialog_Hide'))
	end
end

---@param title string
---@param text string
---@param showDropdown boolean
---@param defaultBankType? number
---@param onInput fun(name: string, bankType: number)
---@param initialValue? string Pre-fill the input box with this value (e.g., current group name for rename).
---@param confirmText? string Label for the confirm button (defaults to "Create").
function groupDialog:Show(title, text, showDropdown, defaultBankType, onInput, initialValue, confirmText)
	if self.open then return end

	if not self.frame then
		self:Initialize()
	end

	self.window:SetTitle(title)

	self.text:SetText(text)
	self.input:SetText(initialValue or "")
	self.yes:SetText(confirmText or L:G("Create"))

	self.bankType = defaultBankType or (Enum.BankType and Enum.BankType.Character or 1)

	if showDropdown then
		self.dropdown:Show()
		self.input:ClearAllPoints()
		self.input:SetPoint("TOP", self.text, "BOTTOM", 0, -20)
		self.dropdown:ClearAllPoints()
		self.dropdown:SetPoint("TOP", self.input, "BOTTOM", 0, -10)

		if self.bankType == (Enum.BankType and Enum.BankType.Account or 2) then
			UIDropDownMenu_SetText(self.dropdown, L:G("Warbank"))
		else
			UIDropDownMenu_SetText(self.dropdown, L:G("Bank"))
		end

	else
		self.dropdown:Hide()
		self.input:ClearAllPoints()
		self.input:SetPoint("TOP", self.text, "BOTTOM", 0, -20)
	end

	local commit = function()
		local name = self.input:GetText()
		if name and name ~= "" then
			xpcall(onInput, geterrorhandler(), name, self.bankType)
			self:Hide()
		end
	end

	self.yes:SetScript("OnClick", commit)
	self.input:SetScript("OnEnterPressed", commit)

	self.body:Invalidate()
	self.window:Show(context:New('GroupDialog_Show'))
	self.input:SetFocus()
	self.open = true
end