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

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class MasqueTheme: AceModule
local masque = addon:GetModule('Masque')

---@class SectionFrame: AceModule
local sectionFrame = addon:GetModule('SectionFrame')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

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
end

-- HideBlizzardBags will hide the default Blizzard bag frames.
function addon:HideBlizzardBags()
  local sneakyFrame = CreateFrame("Frame")
  sneakyFrame:Hide()
  ContainerFrameCombinedBags:SetParent(sneakyFrame)
  for i = 1, 13 do
    _G["ContainerFrame"..i]:SetParent(sneakyFrame)
  end
  BankFrame:SetParent(sneakyFrame)
  BankFrame:SetScript("OnHide", nil)
  BankFrame:SetScript("OnShow", nil)
  BankFrame:SetScript("OnEvent", nil)
end

-- OnEnable is called when the addon is enabled.
function addon:OnEnable()
  self:HideBlizzardBags()
  sectionFrame:Enable()
  masque:Enable()
  context:Enable()
  items:Enable()

  addon.Bags.Backpack = BagFrame:Create(const.BAG_KIND.BACKPACK)
  addon.Bags.Bank = BagFrame:Create(const.BAG_KIND.BANK)

  self:SecureHook('CloseAllBags')

  self:SecureHook('OpenAllBags', self.OpenAllBags)
  self:SecureHook('ToggleAllBags', self.ToggleAllBags)

  events:RegisterEvent('BANKFRAME_CLOSED', self.CloseBank)

  events:RegisterMessage('items/RefreshBackpack/Done', function(event, itemData)
    debug:Log("init/OnInitialize/items", "Drawing bag")
    addon.Bags.Backpack:DrawSectionGridBag(itemData)
   end)

   events:RegisterMessage('items/RefreshBank/Done', function(event, itemData)
    debug:Log("init/OnInitialize/items", "Drawing bank")
    addon.Bags.Bank.content.maxCellWidth = 20
    addon.Bags.Bank:DrawOneBag(itemData)
    --addon.Bags.Bank:DrawSectionGridBag(itemData)
    if not addon.Bags.Bank:IsShown() then
      addon.Bags.Bank:Show()
    end
   end)

   debug:Log("init", "about refresh all items")
   items:RefreshBackpack()
end