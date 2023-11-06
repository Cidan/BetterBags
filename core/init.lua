local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Database: AceModule
local DB = addon:GetModule('Database')

---@class Hooks: AceModule
local Hooks = addon:GetModule('Hooks')

-- OnInitialize is called when the addon is loaded.
function addon:OnInitialize()
  -- Disable the bag tutorial screens, as Better Bags does not match
  -- the base UI/UX these screens refer to.
  if addon.isRetail then
		C_CVar.SetCVarBitfield("closedInfoFrames", LE_FRAME_TUTORIAL_EQUIP_REAGENT_BAG, true)
		C_CVar.SetCVar("professionToolSlotsExampleShown", 1)
		C_CVar.SetCVar("professionAccessorySlotsExampleShown", 1)
	end
end

-- OnEnable is called when the addon is enabled.
function addon:OnEnable()
  Hooks:On()
end