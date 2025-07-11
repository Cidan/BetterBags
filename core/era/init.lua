---@diagnostic disable: duplicate-set-field,duplicate-doc-field



local addon = GetBetterBags()
---@cast addon +AceHook-3.0

local L = addon:GetLocalization()

local database = addon:GetDatabase()

local BagFrame = addon:GetBagFrame()

local const = addon:GetConstants()
local items = addon:GetItems()

local itemFrame = addon:GetItemFrame()

local events = addon:GetEvents()

local masque = addon:GetMasque()

local sectionFrame = addon:GetSectionFrame()

local categories = addon:GetCategories()

local contextMenu = addon:GetContextMenu()

local config = addon:GetConfig()

local currency = addon:GetCurrency()

local debug = addon:GetDebug()

function addon:HideBlizzardBags()
  local sneakyFrame = CreateFrame("Frame", "BetterBagsSneakyFrame")
  sneakyFrame:Hide()

  for i = 1, 13 do
    _G["ContainerFrame"..i]:SetParent(sneakyFrame)
  end

  BankFrame:SetParent(sneakyFrame)
  BankFrame:SetScript("OnHide", nil)
  BankFrame:SetScript("OnShow", nil)
  BankFrame:SetScript("OnEvent", nil)
end

function addon:UpdateButtonHighlight()
  for _, button in pairs(addon._buttons) do
    button:SetChecked(addon.Bags.Backpack:IsShown())
  end
end