---@diagnostic disable: duplicate-set-field,duplicate-doc-field
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

---@class ItemFrame: AceModule
local itemFrame = addon:GetModule('ItemFrame')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class MasqueTheme: AceModule
local masque = addon:GetModule('Masque')

---@class SectionFrame: AceModule
local sectionFrame = addon:GetModule('SectionFrame')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Config: AceModule
local config = addon:GetModule('Config')

---@class Config: AceModule
local currency = addon:GetModule('Currency')

---@class Search: AceModule
local search = addon:GetModule('Search')

---@class ConsolePort: AceModule
local consoleport = addon:GetModule('ConsolePort')

---@class Pawn: AceModule
local pawn = addon:GetModule('Pawn')

---@class Question: AceModule
local question = addon:GetModule('Question')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class BagFrames
---@field Backpack Bag
---@field Bank Bag
addon.Bags = {}

addon.atBank = false

-- OnInitialize is called when the addon is loaded.
function addon:OnInitialize()
  -- Disable the bag tutorial screens, as Better Bags does not match
  -- the base UI/UX these screens refer to.
  if addon.isRetail then
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

local function CheckKeyBindings()
  if GetBindingKey("OPENALLBAGS") == nil then
    question:Alert("No Binding Set", [[
      Better Bags does not have a key binding set for opening all bags.
      Please set a key binding for "Open All Bags" in the key bindings menu.
    ]])
  end
end
-- OnEnable is called when the addon is enabled.
function addon:OnEnable()
  itemFrame:Enable()
  sectionFrame:Enable()
  masque:Enable()
  context:Enable()
  items:Enable()
  config:Enable()
  categories:Enable()
  currency:Enable()
  search:Enable()
  pawn:Enable()
  question:Enable()

  self:HideBlizzardBags()
  addon.Bags.Backpack = BagFrame:Create(const.BAG_KIND.BACKPACK)
  addon.Bags.Bank = BagFrame:Create(const.BAG_KIND.BANK)

  consoleport:Enable()

  self:SecureHook('ToggleAllBags')
  self:SecureHook('CloseSpecialWindows')

  events:RegisterEvent('BANKFRAME_CLOSED', self.CloseBank)
  events:RegisterEvent('PLAYER_INTERACTION_MANAGER_FRAME_SHOW', self.OpenInteractionWindow)
  events:RegisterEvent('PLAYER_INTERACTION_MANAGER_FRAME_HIDE', self.CloseInteractionWindow)

  events:RegisterMessage('items/RefreshBackpack/Done', function(_, args)
    debug:Log("init/OnInitialize/items", "Drawing bag")
    addon.Bags.Backpack:Draw(args[1])
   end)

  events:RegisterMessage('items/RefreshBank/Done', function(_, itemData)
   debug:Log("init/OnInitialize/items", "Drawing bank")
   if addon.Bags.Bank.currentView then
    addon.Bags.Bank.currentView.fullRefresh = true
   end
   addon.Bags.Bank:Draw(itemData)

  end)

  events:RegisterEvent('PLAYER_REGEN_ENABLED', function()
    if addon.Bags.Backpack.drawAfterCombat then
      addon.Bags.Backpack.drawAfterCombat = false
      events:SendMessage('bags/FullRefreshAll')
    end
    if addon.Bags.Bank.drawAfterCombat then
      addon.Bags.Bank.drawAfterCombat = false
      events:SendMessage('bags/FullRefreshAll')
    end
  end)

  events:RegisterMessage('bags/OpenClose', addon.OnUpdate)

  --This tutorial bitfield change does not persist when set in OnInitialize()
  if addon.isRetail then
    -- Disable the mount equipment tutorial as it triggers a taint error from micromenu flashing.
    -- BetterBags blamed because of ContainerFrameItemButtonTemplate hooking by Tutorials
    -- https://github.com/Stanzilla/WoWUIBugs/issues/434
    C_CVar.SetCVarBitfield("closedInfoFrames", LE_FRAME_TUTORIAL_MOUNT_EQUIPMENT_SLOT_FRAME --[[@as number]], true)
    -- Disable the reagent bag tutorial, as Better Bags does not match
    -- the base UI/UX these screens refer to.
    C_CVar.SetCVarBitfield("closedInfoFrames", LE_FRAME_TUTORIAL_EQUIP_REAGENT_BAG --[[@as number]], true)
  end

  C_Timer.After(5, CheckKeyBindings)
end