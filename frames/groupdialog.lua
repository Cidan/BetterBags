local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class (exact) GroupDialog: AceModule
---@field frame Frame|DefaultPanelFlatTemplate
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

	local f = CreateFrame('Frame', "BetterBagsGroupDialog", UIParent, "DefaultPanelFlatTemplate")
	self.frame = f
	f:SetFrameStrata("DIALOG")
	f:SetFrameLevel(600)
	f:SetSize(300, 200)
	f:SetPoint("CENTER")
	f:Hide()

	self.text = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	self.text:SetTextColor(1, 1, 1)
	self.text:SetPoint('TOP', 0, -30)
	self.text:SetWidth(250)
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
	self.yes:SetPoint("BOTTOMLEFT", 40, 15)
	self.no:SetPoint("BOTTOMRIGHT", -40, 15)

	self.input:SetScript("OnEscapePressed", function()
		self:Hide()
	end)
	self.input:SetAutoFocus(false)

	f:SetScript("OnHide", function()
		self.open = false
	end)

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

		if addon.isRetail then
			local info2 = UIDropDownMenu_CreateInfo()
			info2.text = L:G("Warbank")
			info2.func = function()
				UIDropDownMenu_SetText(self.dropdown, L:G("Warbank"))
				self.bankType = Enum.BankType and Enum.BankType.Account or 2
			end
			UIDropDownMenu_AddButton(info2)
		end
	end)
end

function groupDialog:Hide()
	if self.frame then
		self.frame:Hide()
	end
end

function groupDialog:Show(title, text, showDropdown, defaultBankType, onInput)
	if self.open then return end

	if not self.frame then
		self:Initialize()
	end

	self.frame:SetTitle(title)
	self.text:SetText(text)
	self.input:SetText("")

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

		self.frame:SetHeight(150 + self.text:GetStringHeight())
	else
		self.dropdown:Hide()
		self.input:ClearAllPoints()
		self.input:SetPoint("TOP", self.text, "BOTTOM", 0, -20)
		self.frame:SetHeight(120 + self.text:GetStringHeight())
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

	self.frame:Show()
	self.input:SetFocus()
	self.open = true
end