local addonName = ...
---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:NewModule('Constants')

local WOW_PROJECT_WRATH_CLASSIC = 11

-- Constants for detecting WoW version.
addon.isRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
addon.isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
addon.isBCC = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
addon.isWrath = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC

---@enum BagKind
const.BAG_KIND = {
  BACKPACK = 0,
  BANK = 1,
}

const.BANK_BAGS = {
  [Enum.BagIndex.Bank] = Enum.BagIndex.Bank,
  [Enum.BagIndex.BankBag_1] = Enum.BagIndex.BankBag_1,
  [Enum.BagIndex.BankBag_2] = Enum.BagIndex.BankBag_2,
  [Enum.BagIndex.BankBag_3] = Enum.BagIndex.BankBag_3,
  [Enum.BagIndex.BankBag_4] = Enum.BagIndex.BankBag_4,
  [Enum.BagIndex.BankBag_5] = Enum.BagIndex.BankBag_5,
  [Enum.BagIndex.BankBag_6] = Enum.BagIndex.BankBag_6,
  [Enum.BagIndex.BankBag_7] = Enum.BagIndex.BankBag_7,
}