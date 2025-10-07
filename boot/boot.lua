---@diagnostic disable-next-line: unbalanced-assignments
---@type string, table
local _name, space = ...

---@class BetterBags
---@field globalFrame Frame
---@field space table
---@field classes table<string, table>
local BetterBags = {
	globalFrame = CreateFrame("Frame"),
	space = space,
	classes = {},
}

---@param name string
---@return table
function BetterBags:NewClass(name)
	self.classes[name] = {}
	return self.classes[name]
end

function BetterBags:Load()
	self.globalFrame:RegisterEvent("ADDON_LOADED")
	self.globalFrame:SetScript("OnEvent", function(_, event, addonName)
		if event == "ADDON_LOADED" and addonName == "BetterBags" then
			self.globalFrame:UnregisterAllEvents()
			self.globalFrame:SetScript("OnEvent", nil)
			self:Start()
		end
	end)
end

function BetterBags:Start()
	-- All modules and saved variables are loaded from this point on.
	-- Note: Moonlight is already loaded as a standalone addon via OptionalDeps

	-- Initialize BetterBags modules
	local backpack = self:GetBackpack()
	local bank = self:GetBank()
	local binds = self:GetBinds()

	-- Boot the bag modules
	backpack:Boot()
	bank:Boot()

	binds:Boot()
end

---@return backpack
function BetterBags:GetBackpack()
	return self.classes.backpack
end

---@return bank
function BetterBags:GetBank()
	return self.classes.bank
end

---@return bagdata
function BetterBags:GetBagdata()
	return self.classes.bagdata
end

---@return stack
function BetterBags:GetStack()
	return self.classes.stack
end

---@return binds
function BetterBags:GetBinds()
	return self.classes.binds
end

---@return bagconstants
function BetterBags:GetBagConstants()
	return self.classes.bagconstants
end

---@return BetterBags
function GetBetterBags()
	return BetterBags
end
