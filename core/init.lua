local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)
---@cast addon +AceHook-3.0

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Database: AceModule
local DB = addon:GetModule('Database')

---@class BagFrame: AceModule
local BagFrame = addon:GetModule('BagFrame')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class BagFrames
---@field Backpack Bag
---@field Bank Bag
addon.Bags = {}

-- OnInitialize is called when the addon is loaded.
function addon:OnInitialize()
  -- Disable the bag tutorial screens, as Better Bags does not match
  -- the base UI/UX these screens refer to.
  if addon.isRetail then
		C_CVar.SetCVarBitfield("closedInfoFrames", LE_FRAME_TUTORIAL_EQUIP_REAGENT_BAG, true)
		C_CVar.SetCVar("professionToolSlotsExampleShown", 1)
		C_CVar.SetCVar("professionAccessorySlotsExampleShown", 1)
	end

  -- Create the bag frames.

  addon.Bags.Backpack = BagFrame:Create(const.BAG_KIND.BACKPACK)
  addon.Bags.Bank = BagFrame:Create(const.BAG_KIND.BANK)

  items:Enable()
end

-- OnEnable is called when the addon is enabled.
function addon:OnEnable()
  self:SecureHook('OpenAllBags')
  self:SecureHook('CloseAllBags')
  self:SecureHook('ToggleAllBags')
end