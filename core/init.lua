local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)
---@cast addon +AceHook-3.0

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Database: AceModule
local database = addon:GetModule('Database')

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
		C_CVar.SetCVarBitfield("closedInfoFrames", LE_FRAME_TUTORIAL_EQUIP_REAGENT_BAG --[[@as number]], true)
		C_CVar.SetCVar("professionToolSlotsExampleShown", 1)
		C_CVar.SetCVar("professionAccessorySlotsExampleShown", 1)
	end
end

-- HideBlizzardBags will hide the default Blizzard bag frames.
function addon:HideBlizzardBags()
  local sneakyFrame = CreateFrame("Frame", "BetterBagsSneakyFrame")
  sneakyFrame:Hide()
  ContainerFrameCombinedBags:SetParent(sneakyFrame)
  for i = 1, 13 do
    _G["ContainerFrame"..i]:SetParent(sneakyFrame)
  end

  MainMenuBarBackpackButton:SetScript("OnClick", function()
    self:ToggleAllBags()
  end)

  BagBarExpandToggle:SetParent(sneakyFrame)
  for i = 0, 3 do
    local bagButton = _G["CharacterBag"..i.."Slot"] --[[@as Button]]
    bagButton:SetParent(sneakyFrame)
  end
  for i = 0, 0 do
    local bagButton = _G["CharacterReagentBag"..i.."Slot"] --[[@as Button]]
    bagButton:SetParent(sneakyFrame)
  end

  if not database:GetShowBagButton() then
    BagsBar:SetParent(sneakyFrame)
  end

  BankFrame:SetParent(sneakyFrame)
  BankFrame:SetScript("OnHide", nil)
  BankFrame:SetScript("OnShow", nil)
  BankFrame:SetScript("OnEvent", nil)
end

-- OnEnable is called when the addon is enabled.
function addon:OnEnable()
  sectionFrame:Enable()
  masque:Enable()
  context:Enable()
  items:Enable()
  self:HideBlizzardBags()

  addon.Bags.Backpack = BagFrame:Create(const.BAG_KIND.BACKPACK)
  addon.Bags.Bank = BagFrame:Create(const.BAG_KIND.BANK)

  --[[
  self:SecureHook('OpenAllBags')
  self:SecureHook('OpenBackpack')
  self:SecureHook('ToggleBackpack')
  self:SecureHook('CloseBackpack')
  self:SecureHook('CloseAllBags')
  --]]
  self:SecureHook('CloseSpecialWindows')
  self:SecureHook('ToggleAllBags')

  events:RegisterEvent('BANKFRAME_CLOSED', self.CloseBank)

  events:RegisterMessage('items/RefreshBackpack/Done', function(_, itemData)
    debug:Log("init/OnInitialize/items", "Drawing bag")
    addon.Bags.Backpack:Draw(itemData)
   end)

   events:RegisterMessage('items/RefreshBank/Done', function(_, itemData)
    debug:Log("init/OnInitialize/items", "Drawing bank")
    addon.Bags.Bank:Draw(itemData)
    if not addon.Bags.Bank:IsShown() then
      addon.Bags.Bank:Show()
    end
   end)

   debug:Log("init", "about refresh all items")
   items:RefreshBackpack()
end