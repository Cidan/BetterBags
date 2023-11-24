local addonName = ... ---@type string
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

-- BANK_BAGS contains all the bags that are part of the bank, including
-- the main bank view.
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

-- BANK_ONLY_BAGS contains all the bags that are part of the bank, excluding
-- the main bank view.
const.BANK_ONLY_BAGS = {
  [Enum.BagIndex.BankBag_1] = Enum.BagIndex.BankBag_1,
  [Enum.BagIndex.BankBag_2] = Enum.BagIndex.BankBag_2,
  [Enum.BagIndex.BankBag_3] = Enum.BagIndex.BankBag_3,
  [Enum.BagIndex.BankBag_4] = Enum.BagIndex.BankBag_4,
  [Enum.BagIndex.BankBag_5] = Enum.BagIndex.BankBag_5,
  [Enum.BagIndex.BankBag_6] = Enum.BagIndex.BankBag_6,
  [Enum.BagIndex.BankBag_7] = Enum.BagIndex.BankBag_7,
}

-- REAGENTBANK_BAGS contains the reagent bank bag.
const.REAGENTBANK_BAGS = {
  [Enum.BagIndex.Reagentbank] = Enum.BagIndex.Reagentbank,
}

-- BACKPACK_BAGS contains all the bags that are part of the backpack, including
-- the main backpack bag.
const.BACKPACK_BAGS = {
  [Enum.BagIndex.Backpack] = Enum.BagIndex.Backpack,
  [Enum.BagIndex.Bag_1] = Enum.BagIndex.Bag_1,
  [Enum.BagIndex.Bag_2] = Enum.BagIndex.Bag_2,
  [Enum.BagIndex.Bag_3] = Enum.BagIndex.Bag_3,
  [Enum.BagIndex.Bag_4] = Enum.BagIndex.Bag_4,
  [Enum.BagIndex.ReagentBag] = Enum.BagIndex.ReagentBag,
}

-- BACKPACK_ONLY_BAGS contains all the bags that are part of the backpack, excluding
-- the main backpack bag.
const.BACKPACK_ONLY_BAGS = {
  [Enum.BagIndex.Bag_1] = Enum.BagIndex.Bag_1,
  [Enum.BagIndex.Bag_2] = Enum.BagIndex.Bag_2,
  [Enum.BagIndex.Bag_3] = Enum.BagIndex.Bag_3,
  [Enum.BagIndex.Bag_4] = Enum.BagIndex.Bag_4,
  [Enum.BagIndex.ReagentBag] = Enum.BagIndex.ReagentBag,
}

const.BACKPACK_ONLY_REAGENT_BAGS = {
  [Enum.BagIndex.ReagentBag] = Enum.BagIndex.ReagentBag,
}

---@class databaseOptions
const.DATABASE_DEFAULTS = {
  profile = {
    enabled = true,
    positions = {
      Backpack = {},
      Bank = {},
    },
  },
  char = {}
}