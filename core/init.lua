---@diagnostic disable: duplicate-set-field,duplicate-doc-field,deprecated
local addonName = ... ---@type string

---@class BetterBags: AceAddon
---@field _buttons CheckButton[]|MainMenuBagButton[]
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

---@class ContextMenu: AceModule
local contextMenu = addon:GetModule('ContextMenu')

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

---@class SimpleItemLevel: AceModule
local simpleItemLevel = addon:GetModule('SimpleItemLevel')

---@class Refresh: AceModule
local refresh = addon:GetModule('Refresh')

---@class SectionConfig: AceModule
local sectionConfig = addon:GetModule('SectionConfig')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class Views: AceModule
local views = addon:GetModule('Views')

---@class SearchCategoryConfig: AceModule
local searchCategoryConfig = addon:GetModule('SearchCategoryConfig')

---@class Async: AceModule
local async = addon:GetModule('Async')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class BagFrames
---@field Backpack Bag
---@field Bank Bag
addon.Bags = {}

addon.atBank = false
addon.atWarbank = false

-- BetterBags_ToggleBags is a wrapper function for the ToggleAllBags function.
function BetterBags_ToggleBags()
  addon:ToggleAllBags()
end

local function CheckKeyBindings()
  if InCombatLockdown() then
    addon._bindingFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  addon._bindingFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
  ClearOverrideBindings(addon._bindingFrame)
  local bindings = {
    "TOGGLEBACKPACK",
    "TOGGLEREAGENTBAG",
    "TOGGLEBAG1",
    "TOGGLEBAG2",
    "TOGGLEBAG3",
    "TOGGLEBAG4",
    "OPENALLBAGS"
  }
  for _, binding in pairs(bindings) do
    local key, otherkey = GetBindingKey(binding)
    if key ~= nil then
      SetOverrideBinding(addon._bindingFrame, true, key, "BETTERBAGS_TOGGLEBAGS")
    end
    if otherkey ~= nil then
      SetOverrideBinding(addon._bindingFrame, true, otherkey, "BETTERBAGS_TOGGLEBAGS")
    end
  end
end

-- OnInitialize is called when the addon is loaded.
function addon:OnInitialize()
  -- Disable the bag tutorial screens, as Better Bags does not match
  -- the base UI/UX these screens refer to.
  if addon.isRetail then
		C_CVar.SetCVar("professionToolSlotsExampleShown", 1)
		C_CVar.SetCVar("professionAccessorySlotsExampleShown", 1)
	end
  addon._bindingFrame = addon._bindingFrame or CreateFrame("Frame")
  addon._bindingFrame:RegisterEvent("PLAYER_LOGIN")
  addon._bindingFrame:RegisterEvent("UPDATE_BINDINGS")
  addon._bindingFrame:SetScript("OnEvent", CheckKeyBindings)
  addon._buttons = {
    MainMenuBarBackpackButton --[[@as MainMenuBagButton]],
    _G["CharacterBag0Slot"],
    _G["CharacterBag1Slot"],
    _G["CharacterBag2Slot"],
    _G["CharacterBag3Slot"],
    KeyRingButton,
  }

  if CharacterReagentBag0Slot then
    table.insert(addon._buttons, CharacterReagentBag0Slot)
  end

  for _, button in pairs(addon._buttons) do
    button:HookScript("OnClick",
    function()
      addon:ToggleAllBags()
    end)
  end
end


---@param bagid number
---@return Bag
function addon:GetBagFromBagID(bagid)
  if const.BACKPACK_BAGS[bagid] then
    return addon.Bags.Backpack
  elseif const.BANK_BAGS[bagid] then
    return addon.Bags.Bank
  elseif const.REAGENTBANK_BAGS[bagid] then
    return addon.Bags.Bank
  elseif const.ACCOUNT_BANK_BAGS[bagid] then
    return addon.Bags.Bank
  else
    error("invalid bagid")
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

function addon:UpdateButtonHighlight()
  for _, button in pairs(addon._buttons) do
    button.SlotHighlightTexture:SetShown(addon.Bags.Backpack:IsShown())
  end
end

local function applyCompat()
  C_Timer.After(5, function()
    if C_AddOns.IsAddOnLoaded("BetterBagsElvUISkin") then
      question:Alert("Disable ElvUI Plugin", "The ElvUI BetterBags plugin you have installed is not compatible with BetterBags. It has been disabled -- please reload your UI to apply the changes.")
      C_AddOns.DisableAddOn("BetterBagsElvUISkin")
    end
  end)
end

-- OnEnable is called when the addon is enabled.
function addon:OnEnable()
  applyCompat()
  debug:Enable()
  masque:Enable()
  itemFrame:Enable()
  sectionFrame:Enable()
  simpleItemLevel:Enable()
  contextMenu:Enable()
  items:Enable()
  config:Enable()
  categories:Enable()
  currency:Enable()
  search:Enable()
  pawn:Enable()
  question:Enable()
  refresh:Enable()
  views:Enable()
  searchCategoryConfig:Enable()
  async:Enable()

  self:HideBlizzardBags()
  addon.Bags.Backpack = BagFrame:Create(const.BAG_KIND.BACKPACK)
  addon.Bags.Bank = BagFrame:Create(const.BAG_KIND.BANK)

  -- Apply themes globally -- do not instantiate new windows after this call.
  themes:Enable()

  addon.Bags.Backpack:SetTitle(L:G("Backpack"))

  table.insert(UISpecialFrames, addon.Bags.Backpack:GetName())
  table.insert(UISpecialFrames, addon.Bags.Bank:GetName())

  consoleport:Enable()

  self:SecureHook('ToggleAllBags')
  self:SecureHook('CloseSpecialWindows')

  events:RegisterEvent('BANKFRAME_CLOSED', self.CloseBank)
  events:RegisterEvent('PLAYER_INTERACTION_MANAGER_FRAME_SHOW', self.OpenInteractionWindow)
  events:RegisterEvent('PLAYER_INTERACTION_MANAGER_FRAME_HIDE', self.CloseInteractionWindow)

  events:RegisterMessage('items/RefreshBackpack/Done', function(_, args)
    debug:Log("init/OnInitialize/items", "Drawing bag")
    addon.Bags.Backpack:Draw(args[1], args[2], function()
      events:SendMessage('bags/Draw/Backpack/Done', args[1])
      if not addon.Bags.Backpack.loaded then
        addon.Bags.Backpack.loaded = true
        events:SendMessage('bags/Draw/Backpack/Loaded')
      end
    end)
   end)

  events:RegisterMessage('items/RefreshBank/Done', function(_, args)
    debug:Log("init/OnInitialize/items", "Drawing bank")
     -- Show the bank frame if it's not already shown.
    if not addon.Bags.Bank:IsShown() and addon.atBank then
      addon.Bags.Bank:Show()
    end
    addon.Bags.Bank:Draw(args[1], args[2], function()
      events:SendMessage('bags/Draw/Bank/Done')
      if not addon.Bags.Bank.loaded then
        addon.Bags.Bank.loaded = true
        events:SendMessage('bags/Draw/Bank/Loaded')
      end
    end)
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
end
