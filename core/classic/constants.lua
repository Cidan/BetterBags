---@diagnostic disable: duplicate-set-field,duplicate-doc-field,duplicate-doc-alias
local addonName = ... ---@type string
---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

_G.NUM_TOTAL_BAG_FRAMES = 5

-- BANK_BAGS contains all the bags that are part of the bank, including
-- the main bank view.
-- The Enum.BagIndex values for bank bags is broken in Classic, so we have to subtract 1.
const.BANK_BAGS = {
  [Enum.BagIndex.Bank] = Enum.BagIndex.Bank,
  [Enum.BagIndex.BankBag_1 - 1] = Enum.BagIndex.BankBag_1 - 1,
  [Enum.BagIndex.BankBag_2 - 1] = Enum.BagIndex.BankBag_2 - 1,
  [Enum.BagIndex.BankBag_3 - 1] = Enum.BagIndex.BankBag_3 - 1,
  [Enum.BagIndex.BankBag_4 - 1] = Enum.BagIndex.BankBag_4 - 1,
  [Enum.BagIndex.BankBag_5 - 1] = Enum.BagIndex.BankBag_5 - 1,
  [Enum.BagIndex.BankBag_6 - 1] = Enum.BagIndex.BankBag_6 - 1,
}


-- BANK_ONLY_BAGS contains all the bags that are part of the bank, excluding
-- the main bank view.
const.BANK_ONLY_BAGS = {
  [Enum.BagIndex.BankBag_1 - 1] = Enum.BagIndex.BankBag_1 - 1,
  [Enum.BagIndex.BankBag_2 - 1] = Enum.BagIndex.BankBag_2 - 1,
  [Enum.BagIndex.BankBag_3 - 1] = Enum.BagIndex.BankBag_3 - 1,
  [Enum.BagIndex.BankBag_4 - 1] = Enum.BagIndex.BankBag_4 - 1,
  [Enum.BagIndex.BankBag_5 - 1] = Enum.BagIndex.BankBag_5 - 1,
  [Enum.BagIndex.BankBag_6 - 1] = Enum.BagIndex.BankBag_6 - 1,
}
const.BANK_ONLY_BAGS_LIST = {
  Enum.BagIndex.BankBag_1 - 1,
  Enum.BagIndex.BankBag_2 - 1,
  Enum.BagIndex.BankBag_3 - 1,
  Enum.BagIndex.BankBag_4 - 1,
  Enum.BagIndex.BankBag_5 - 1,
  Enum.BagIndex.BankBag_6 - 1,
}

-- BACKPACK_BAGS contains all the bags that are part of the backpack, including
-- the main backpack bag.
const.BACKPACK_BAGS = {
  [Enum.BagIndex.Backpack] = Enum.BagIndex.Backpack,
  [Enum.BagIndex.Bag_1] = Enum.BagIndex.Bag_1,
  [Enum.BagIndex.Bag_2] = Enum.BagIndex.Bag_2,
  [Enum.BagIndex.Bag_3] = Enum.BagIndex.Bag_3,
  [Enum.BagIndex.Bag_4] = Enum.BagIndex.Bag_4,
  [Enum.BagIndex.Keyring] = Enum.BagIndex.Keyring,
}

-- BACKPACK_ONLY_BAGS contains all the bags that are part of the backpack, excluding
-- the main backpack bag.
const.BACKPACK_ONLY_BAGS = {
  [Enum.BagIndex.Bag_1] = Enum.BagIndex.Bag_1,
  [Enum.BagIndex.Bag_2] = Enum.BagIndex.Bag_2,
  [Enum.BagIndex.Bag_3] = Enum.BagIndex.Bag_3,
  [Enum.BagIndex.Bag_4] = Enum.BagIndex.Bag_4,
  [Enum.BagIndex.Keyring] = Enum.BagIndex.Keyring,
}

const.BACKPACK_ONLY_BAGS_LIST = {
  Enum.BagIndex.Bag_1,
  Enum.BagIndex.Bag_2,
  Enum.BagIndex.Bag_3,
  Enum.BagIndex.Bag_4,
}


const.OFFSETS = {
  -- This is the offset from the top of the bag window to the start of the
  -- content frame.
  BAG_TOP_INSET = -38,
  -- This is the offset from the left of the bag window to the start of the
  -- content frame.
  BAG_LEFT_INSET = 6,
  -- This is the offset from the right of the bag window to the start of the
  -- content frame.
  BAG_RIGHT_INSET = -6,
  -- This is the offset from the bottom of the bag window to the start of the
  -- content frame.
  BAG_BOTTOM_INSET = 3,

  -- This is the height of the bag window bottom bar. 
  BOTTOM_BAR_HEIGHT = 20,
  -- This is how far the bottom bar is inset from the bottom of the bag window.
  BOTTOM_BAR_BOTTOM_INSET = 6,
  -- This is how far the bottom bar is inset from the left of the bag window.
  BOTTOM_BAR_LEFT_INSET = 6,
  -- This is how far the bottom bar is inset from the right of the bag window.
  BOTTOM_BAR_RIGHT_INSET = -6,
}
