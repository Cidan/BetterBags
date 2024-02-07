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

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

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
