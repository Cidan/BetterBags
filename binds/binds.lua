local bb = GetBetterBags()
local moonlight = GetMoonlight()
local bagconst = bb:GetBagConstants()

--- Describe in a comment what this module does. Note the lower case starting letter -- this denotes a module package accessor.
---@class binds
local binds = bb:NewClass("binds")

---@param fn function
function binds:OnBagToggle(fn)
	ToggleAllBags = fn
end

function binds:Boot()
	local event = moonlight:GetEvent()
	local backpack = bb:GetBackpack():GetBackpack()
	local bank = bb:GetBank():GetBank()

	-- Hide the Blizzard bags.
	binds:HideBlizzardBags()

	-- Hide the Blizzard bank frame.
	binds:HideBlizzardBank()

	-- Close special frames when demanded (i.e. escape)
	hooksecurefunc("CloseSpecialWindows", function(f)
		self:CloseSpecialWindows(f)
	end)

	-- Register the backpack and bank as special frames.
	table.insert(UISpecialFrames, backpack:GetName())
	table.insert(UISpecialFrames, bank:GetName())

	-- Register for interaction open and close events
	event:ListenForEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(...)
		self:OpenInteractionWindow(...)
	end)

	event:ListenForEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(...)
		self:CloseInteractionWindow(...)
	end)
end

function binds:HideBlizzardBags()
	local sneaky = CreateFrame("Frame")
	sneaky:Hide()
	ContainerFrameCombinedBags:SetParent(sneaky)
	for i = 1, bagconst.MAX_BLIZZARD_CONTAINER_FRAMES do
		_G["ContainerFrame" .. i]:SetParent(sneaky)
	end
end

function binds:HideBlizzardBank()
	-- Hide the main BankFrame by reparenting to hidden frame (prevents visibility).
	local sneaky = CreateFrame("Frame")
	sneaky:Hide()
	if BankFrame ~= nil then
		BankFrame:SetParent(sneaky)
	end

	-- Configure BankPanel to be invisible when shown (prevents taint).
	-- CRITICAL: Do NOT show BankPanel at initialization - this causes permanent taint!
	-- BankPanel will be shown invisibly when bank opens (see bank.lua BANKFRAME_OPENED handler).
	if BankPanel ~= nil then
		BankPanel:SetAlpha(bagconst.BANKPANEL_INVISIBLE_ALPHA)
		BankPanel:EnableMouse(false)
		BankPanel:EnableKeyboard(false)
		-- Keep hidden initially - will be shown when bank actually opens
	end
end

---@param interaction Enum.PlayerInteractionType
function binds:OpenInteractionWindow(interaction)
	local const = moonlight:GetConst()
	local backpack = bb:GetBackpack():GetBackpack()
	if const.EVENTS_THAT_OPEN_BACKPACK[interaction] ~= true then
		return
	end
	if GameMenuFrame:IsShown() then
		return
	end
	backpack:Show(false)
end

---@param interaction Enum.PlayerInteractionType
function binds:CloseInteractionWindow(interaction)
	local const = moonlight:GetConst()
	local backpack = bb:GetBackpack():GetBackpack()
	if const.EVENTS_THAT_OPEN_BACKPACK[interaction] == nil then
		return
	end
	backpack:Hide(false)
end

---@param interactingFrame Frame
function binds:CloseSpecialWindows(interactingFrame)
	if interactingFrame ~= nil then
		return
	end
	local backpack = bb:GetBackpack():GetBackpack()
	local bank = bb:GetBank():GetBank()
	backpack:Hide(false)
	bank:Hide(false)
end
