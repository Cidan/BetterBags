---@diagnostic disable: duplicate-set-field,duplicate-doc-field,duplicate-doc-alias
local addonName = ... ---@type string
---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Constants: AceModule
local const = addon:NewModule('Constants')

---@class AnchorState
---@field enabled boolean
---@field shown boolean
---@field staticPoint? string

-- Constants for detecting WoW version.
addon.isRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
addon.isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
addon.isBCC = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
addon.isCata = WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC
addon.isMists = WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC
addon.isAnniversary = WOW_PROJECT_ID == 5

-- Get the interface/TOC version for patch-specific feature gating
-- Format: 110207 for patch 11.0.207, 120000 for 12.0.0 (Midnight), etc.
local _, _, _, tocVersion = GetBuildInfo()
addon.tocVersion = tocVersion

-- Helper to check if we're running Midnight (12.x) or later
addon.isMidnight = addon.isRetail and tocVersion >= 120000

---@enum BagKind
const.BAG_KIND = {
  UNDEFINED = -1,
  BACKPACK = 0,
  BANK = 1,
}

if addon.isRetail then
  -- BankTab is an enum for the different bank tabs.
  ---@enum BankTab
  const.BANK_TAB = {
    [Enum.BagIndex.Characterbanktab] = Enum.BagIndex.Characterbanktab,
    [Enum.BagIndex.CharacterBankTab_1] = Enum.BagIndex.CharacterBankTab_1,
    [Enum.BagIndex.CharacterBankTab_2] = Enum.BagIndex.CharacterBankTab_2,
    [Enum.BagIndex.CharacterBankTab_3] = Enum.BagIndex.CharacterBankTab_3,
    [Enum.BagIndex.CharacterBankTab_4] = Enum.BagIndex.CharacterBankTab_4,
    [Enum.BagIndex.CharacterBankTab_5] = Enum.BagIndex.CharacterBankTab_5,
    [Enum.BagIndex.CharacterBankTab_6] = Enum.BagIndex.CharacterBankTab_6,
    [Enum.BagIndex.AccountBankTab_1] = Enum.BagIndex.AccountBankTab_1,
    [Enum.BagIndex.AccountBankTab_2] = Enum.BagIndex.AccountBankTab_2,
    [Enum.BagIndex.AccountBankTab_3] = Enum.BagIndex.AccountBankTab_3,
    [Enum.BagIndex.AccountBankTab_4] = Enum.BagIndex.AccountBankTab_4,
    [Enum.BagIndex.AccountBankTab_5] = Enum.BagIndex.AccountBankTab_5,
  }
else
  -- BankTab is an enum for the different bank tabs.
  ---@enum BankTab
  const.BANK_TAB = {
    BANK = Enum.BagIndex.Bank,
    REAGENT = Enum.BagIndex.Reagentbank,
    ACCOUNT_BANK_1 = Enum.BagIndex.AccountBankTab_1,
    ACCOUNT_BANK_2 = Enum.BagIndex.AccountBankTab_2,
    ACCOUNT_BANK_3 = Enum.BagIndex.AccountBankTab_3,
    ACCOUNT_BANK_4 = Enum.BagIndex.AccountBankTab_4,
    ACCOUNT_BANK_5 = Enum.BagIndex.AccountBankTab_5,
  }
end
---@enum MovementFlowType
const.MOVEMENT_FLOW = {
  UNDEFINED = -1,
  BANK = 0,
  REAGENT = 1,
  WARBANK = 2,
  SENDMAIL = 3,
  TRADE = 4,
  NPCSHOP = 5
}

---@enum BindingScope  -- similar. but distinct from ItemBind
const.BINDING_SCOPE = {
  UNKNOWN = -1,
  NONBINDING = 0,
  BOUND = 1,
  BOE = 2,
  BOU = 3,
  QUEST = 4,
  SOULBOUND = 5,
  REFUNDABLE = 6,
  ACCOUNT = 7,
  BNET = 8,
  WUE = 9,
}

---@class BindingMap
---@type table<number, string>
const.BINDING_MAP = {
  [const.BINDING_SCOPE.UNKNOWN] = "",
  [const.BINDING_SCOPE.NONBINDING] = "nonbinding",
  [const.BINDING_SCOPE.BOUND] = "",
  [const.BINDING_SCOPE.BOE] = "boe",
  [const.BINDING_SCOPE.BOU] = "bou",
  [const.BINDING_SCOPE.QUEST] = "quest",
  [const.BINDING_SCOPE.SOULBOUND] = "soulbound",
  [const.BINDING_SCOPE.REFUNDABLE] = "refundable",
  [const.BINDING_SCOPE.ACCOUNT] = "warbound",
  [const.BINDING_SCOPE.BNET] = "bnet",
  [const.BINDING_SCOPE.WUE] = "wue",
}

if addon.isRetail then
  const.BANK_BAGS = {
    [Enum.BagIndex.Characterbanktab] = Enum.BagIndex.Characterbanktab,
    [Enum.BagIndex.CharacterBankTab_1] = Enum.BagIndex.CharacterBankTab_1,
    [Enum.BagIndex.CharacterBankTab_2] = Enum.BagIndex.CharacterBankTab_2,
    [Enum.BagIndex.CharacterBankTab_3] = Enum.BagIndex.CharacterBankTab_3,
    [Enum.BagIndex.CharacterBankTab_4] = Enum.BagIndex.CharacterBankTab_4,
    [Enum.BagIndex.CharacterBankTab_5] = Enum.BagIndex.CharacterBankTab_5,
    [Enum.BagIndex.CharacterBankTab_6] = Enum.BagIndex.CharacterBankTab_6,
  }
  const.BANK_ONLY_BAGS = {
    [Enum.BagIndex.CharacterBankTab_1] = Enum.BagIndex.CharacterBankTab_1,
    [Enum.BagIndex.CharacterBankTab_2] = Enum.BagIndex.CharacterBankTab_2,
    [Enum.BagIndex.CharacterBankTab_3] = Enum.BagIndex.CharacterBankTab_3,
    [Enum.BagIndex.CharacterBankTab_4] = Enum.BagIndex.CharacterBankTab_4,
    [Enum.BagIndex.CharacterBankTab_5] = Enum.BagIndex.CharacterBankTab_5,
    [Enum.BagIndex.CharacterBankTab_6] = Enum.BagIndex.CharacterBankTab_6,
  }
  const.BANK_ONLY_BAGS_LIST = {
    Enum.BagIndex.CharacterBankTab_1,
    Enum.BagIndex.CharacterBankTab_2,
    Enum.BagIndex.CharacterBankTab_3,
    Enum.BagIndex.CharacterBankTab_4,
    Enum.BagIndex.CharacterBankTab_5,
    Enum.BagIndex.CharacterBankTab_6,
  }
else
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
  const.BANK_ONLY_BAGS = {
    [Enum.BagIndex.BankBag_1] = Enum.BagIndex.BankBag_1,
    [Enum.BagIndex.BankBag_2] = Enum.BagIndex.BankBag_2,
    [Enum.BagIndex.BankBag_3] = Enum.BagIndex.BankBag_3,
    [Enum.BagIndex.BankBag_4] = Enum.BagIndex.BankBag_4,
    [Enum.BagIndex.BankBag_5] = Enum.BagIndex.BankBag_5,
    [Enum.BagIndex.BankBag_6] = Enum.BagIndex.BankBag_6,
    [Enum.BagIndex.BankBag_7] = Enum.BagIndex.BankBag_7,
  }
  const.BANK_ONLY_BAGS_LIST = {
    Enum.BagIndex.BankBag_1,
    Enum.BagIndex.BankBag_2,
    Enum.BagIndex.BankBag_3,
    Enum.BagIndex.BankBag_4,
    Enum.BagIndex.BankBag_5,
    Enum.BagIndex.BankBag_6,
    Enum.BagIndex.BankBag_7,
  }
end

if addon.isRetail then
  const.ACCOUNT_BANK_BAGS = {
    [Enum.BagIndex.AccountBankTab_1] = Enum.BagIndex.AccountBankTab_1,
    [Enum.BagIndex.AccountBankTab_2] = Enum.BagIndex.AccountBankTab_2,
    [Enum.BagIndex.AccountBankTab_3] = Enum.BagIndex.AccountBankTab_3,
    [Enum.BagIndex.AccountBankTab_4] = Enum.BagIndex.AccountBankTab_4,
    [Enum.BagIndex.AccountBankTab_5] = Enum.BagIndex.AccountBankTab_5,
  }
end

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

const.BACKPACK_ONLY_BAGS_LIST = {
  Enum.BagIndex.Bag_1,
  Enum.BagIndex.Bag_2,
  Enum.BagIndex.Bag_3,
  Enum.BagIndex.Bag_4,
  Enum.BagIndex.ReagentBag,
}

const.BACKPACK_ONLY_REAGENT_BAGS = {
  [Enum.BagIndex.ReagentBag] = Enum.BagIndex.ReagentBag,
}

const.ITEM_BAG_FAMILY = {
  [0] = L:G("Bags"),
  [1] = L:G("Quiver"),
  [2] = L:G("Ammo Pouch"),
  [4] = L:G("Soul Bag"),
  [8] = L:G("Leatherworking Bag"),
  [16] = L:G("Inscription Bag"),
  [32] = L:G("Herb Bag"),
  [64] = L:G("Enchanting Bag"),
  [128] = L:G("Engineering Bag"),
  [256] = L:G("Keyring"),
  [512] = L:G("Gem Bag"),
  [1024] = L:G("Mining Bag"),
}

---@enum WindowKind
const.WINDOW_KIND = {
  UNDEFINED = 0,
  PORTRAIT = 1,
  SIMPLE = 2,
  FLAT = 3,
}

---@enum BagView
const.BAG_VIEW = {
  UNDEFINED = 0,
  ONE_BAG = 1,
  SECTION_GRID = 2,
  LIST = 3,
  SECTION_ALL_BAGS = 4,
}

---@enum GridCompactStyle
const.GRID_COMPACT_STYLE = {
  NONE = 0,
  SIMPLE = 1,
  COMPACT = 2,
}

---@enum SectionSortType
const.SECTION_SORT_TYPE = {
  ALPHABETICALLY = 1,
  SIZE_DESCENDING = 2,
  SIZE_ASCENDING = 3,
}

---@enum SearchCategoryGroupBy
const.SEARCH_CATEGORY_GROUP_BY = {
  NONE = 0,
  TYPE = 1,
  SUBTYPE = 2,
  EXPANSION = 3,
}

---@enum ItemSortType
const.ITEM_SORT_TYPE = {
  ALPHABETICALLY_THEN_QUALITY = 1,
  QUALITY_THEN_ALPHABETICALLY = 2,
  ITEM_LEVEL = 3,
  EXPANSION = 4,
}

---@enum ExpansionType
const.EXPANSION_TYPE = {
  LE_EXPANSION_CLASSIC = 0,
  LE_EXPANSION_BURNING_CRUSADE = 1,
  LE_EXPANSION_WRATH_OF_THE_LICH_KING = 2,
  LE_EXPANSION_CATACLYSM = 3,
  LE_EXPANSION_MISTS_OF_PANDARIA = 4,
  LE_EXPANSION_WARLORDS_OF_DRAENOR = 5,
  LE_EXPANSION_LEGION = 6,
  LE_EXPANSION_BATTLE_FOR_AZEROTH = 7,
  LE_EXPANSION_SHADOWLANDS = 8,
  LE_EXPANSION_DRAGONFLIGHT = 9,
  LE_EXPANSION_WAR_WITHIN = 10,
  LE_EXPANSION_MIDNIGHT = 11,
}

const.OFFSETS = {
  -- Width allocated for the scrollbar when it appears.
  SCROLLBAR_WIDTH = 14,
  -- The left inset for the search box.
  SEARCH_LEFT_INSET = 46,
  -- The right inset for the search box.
  SEARCH_RIGHT_INSET = -46,
  -- The top inset for the search box.
  SEARCH_TOP_INSET = -30,

  -- This is the offset from the top of the bag window to the start of the
  -- content frame.
  BAG_TOP_INSET = -42,
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

---@enum ItemQuality
const.ITEM_QUALITY = {
  Poor = Enum.ItemQuality.Poor,
  Common = Enum.ItemQuality.Common,
  Uncommon = Enum.ItemQuality.Uncommon,
  Rare = Enum.ItemQuality.Rare,
  Epic = Enum.ItemQuality.Epic,
  Legendary = Enum.ItemQuality.Legendary,
  Artifact = Enum.ItemQuality.Artifact,
  Heirloom = Enum.ItemQuality.Heirloom,
  WoWToken = Enum.ItemQuality.WoWToken,
}

if addon.isMists or addon.isClassic or addon.isAnniversary then
  const.ITEM_QUALITY.Good = Enum.ItemQuality.Good
  const.ITEM_QUALITY.Uncommon = Enum.ItemQuality.Good

  const.ITEM_QUALITY.Standard = Enum.ItemQuality.Standard
  const.ITEM_QUALITY.Common = Enum.ItemQuality.Standard
end

const.BAG_SUBTYPES = {
  ["Bag"] = 0,
  ["Soul Bag"] = 1,
  ["Herb Bag"] = 2,
  ["Enchanting Bag"] = 3,
  ["Engineering Bag"] = 4,
  ["Gem Bag"] = 5,
  ["Mining Bag"] = 6,
  ["Leatherworking Bag"] = 7,
  ["Inscription Bag"] = 8,
  ["Tackle Box"] = 9,
  ["Cooking Bag"] = 10,
}

---@type table<number, ItemQuality>
const.BAG_SUBTYPE_TO_QUALITY = {
  [0] = const.ITEM_QUALITY.Poor,
  [1] = const.ITEM_QUALITY.Epic,
  [2] = const.ITEM_QUALITY.Uncommon,
  [3] = const.ITEM_QUALITY.Rare,
  [4] = const.ITEM_QUALITY.Artifact,
  [5] = const.ITEM_QUALITY.Heirloom,
  [6] = const.ITEM_QUALITY.Common,
  [7] = const.ITEM_QUALITY.Common,
  [8] = const.ITEM_QUALITY.Common,
  [9] = const.ITEM_QUALITY.Common,
  [10] = const.ITEM_QUALITY.Common,
  [99] = const.ITEM_QUALITY.Common
}

---@type table<string, ItemQuality>
const.ITEM_QUALITY_TO_ENUM = {
  ITEM_QUALITY0_DESC = const.ITEM_QUALITY.Poor,
  ITEM_QUALITY1_DESC = const.ITEM_QUALITY.Common,
  ITEM_QUALITY2_DESC = const.ITEM_QUALITY.Uncommon,
  ITEM_QUALITY3_DESC = const.ITEM_QUALITY.Rare,
  ITEM_QUALITY4_DESC = const.ITEM_QUALITY.Epic,
  ITEM_QUALITY5_DESC = const.ITEM_QUALITY.Legendary,
  ITEM_QUALITY6_DESC = const.ITEM_QUALITY.Artifact,
  ITEM_QUALITY7_DESC = const.ITEM_QUALITY.Heirloom,
  ITEM_QUALITY8_DESC = const.ITEM_QUALITY.WoWToken,
}

const.ITEM_QUALITY_TO_ENUM[string.lower(ITEM_QUALITY0_DESC)] = const.ITEM_QUALITY.Poor
const.ITEM_QUALITY_TO_ENUM[string.lower(ITEM_QUALITY1_DESC)] = const.ITEM_QUALITY.Common
const.ITEM_QUALITY_TO_ENUM[string.lower(ITEM_QUALITY2_DESC)] = const.ITEM_QUALITY.Uncommon
const.ITEM_QUALITY_TO_ENUM[string.lower(ITEM_QUALITY3_DESC)] = const.ITEM_QUALITY.Rare
const.ITEM_QUALITY_TO_ENUM[string.lower(ITEM_QUALITY4_DESC)] = const.ITEM_QUALITY.Epic
const.ITEM_QUALITY_TO_ENUM[string.lower(ITEM_QUALITY5_DESC)] = const.ITEM_QUALITY.Legendary
const.ITEM_QUALITY_TO_ENUM[string.lower(ITEM_QUALITY6_DESC)] = const.ITEM_QUALITY.Artifact
const.ITEM_QUALITY_TO_ENUM[string.lower(ITEM_QUALITY7_DESC)] = const.ITEM_QUALITY.Heirloom
const.ITEM_QUALITY_TO_ENUM[string.lower(ITEM_QUALITY8_DESC)] = const.ITEM_QUALITY.WoWToken

const.ITEM_QUALITY_COLOR = {
  [const.ITEM_QUALITY.Poor] = {0.62, 0.62, 0.62, 1},
  [const.ITEM_QUALITY.Common] = {1, 1, 1, 1},
  [const.ITEM_QUALITY.Uncommon] = {0.12, 1, 0, 1},
  [const.ITEM_QUALITY.Rare] = {0.00, 0.44, 0.87, 1},
  [const.ITEM_QUALITY.Epic] = {0.64, 0.21, 0.93, 1},
  [const.ITEM_QUALITY.Legendary] = {1, 0.50, 0, 1},
  [const.ITEM_QUALITY.Artifact] = {0.90, 0.80, 0.50, 1},
  [const.ITEM_QUALITY.Heirloom] = {0, 0.8, 1, 1},
  [const.ITEM_QUALITY.WoWToken] = {0, 0.8, 1, 1},
}

const.ITEM_QUALITY_HIGHLIGHT = {
  [const.ITEM_QUALITY.Poor] = {0.682, 0.682, 0.682, 1},
  [const.ITEM_QUALITY.Common] = {1, 1, 1, 1},
  [const.ITEM_QUALITY.Uncommon] = {0.132, 1, 0, 1},
  [const.ITEM_QUALITY.Rare] = {0, 0.484, 0.957, 1},
  [const.ITEM_QUALITY.Epic] = {0.704, 0.231, 1, 1},
  [const.ITEM_QUALITY.Legendary] = {1, 0.55, 0, 1},
  [const.ITEM_QUALITY.Artifact] = {0.99, 0.88, 0.55, 1},
  [const.ITEM_QUALITY.Heirloom] = {0, 0.88, 1, 1},
  [const.ITEM_QUALITY.WoWToken] = {0, 0.88, 1, 1},
}
const.ITEM_QUALITY_COLOR_HIGH = {
  [const.ITEM_QUALITY.Poor] = {0.558, 0.558, 0.558, 0.3},
  [const.ITEM_QUALITY.Common] = {0.9, 0.9, 0.9, 0.3},
  [const.ITEM_QUALITY.Uncommon] = {0.108, 0.9, 0, 0.3},
  [const.ITEM_QUALITY.Rare] = {0, 0.396, 0.783, 0.3},
  [const.ITEM_QUALITY.Epic] = {0.576, 0.189, 0.837, 0.3},
  [const.ITEM_QUALITY.Legendary] = {0.9, 0.45, 0, 0.3},
  [const.ITEM_QUALITY.Artifact] = {0.81, 0.72, 0.45, 0.3},
  [const.ITEM_QUALITY.Heirloom] = {0, 0.72, 0.9, 0.3},
  [const.ITEM_QUALITY.WoWToken] = {0, 0.72, 0.9, 0.3},
}

const.ITEM_QUALITY_COLOR_LOW = {
  [const.ITEM_QUALITY.Poor] = {0.558, 0.558, 0.558, 0.1},
  [const.ITEM_QUALITY.Common] = {0.9, 0.9, 0.9, 0.1},
  [const.ITEM_QUALITY.Uncommon] = {0.108, 0.9, 0, 0.1},
  [const.ITEM_QUALITY.Rare] = {0, 0.396, 0.783, 0.1},
  [const.ITEM_QUALITY.Epic] = {0.576, 0.189, 0.837, 0.1},
  [const.ITEM_QUALITY.Legendary] = {0.9, 0.45, 0, 0.1},
  [const.ITEM_QUALITY.Artifact] = {0.81, 0.72, 0.45, 0.1},
  [const.ITEM_QUALITY.Heirloom] = {0, 0.72, 0.9, 0.1},
  [const.ITEM_QUALITY.WoWToken] = {0, 0.72, 0.9, 0.1},
}
---@class ExpansionMap
---@type table<number, string>
const.EXPANSION_MAP = {
  [_G.LE_EXPANSION_CLASSIC] = _G.EXPANSION_NAME0,
  [_G.LE_EXPANSION_BURNING_CRUSADE] = _G.EXPANSION_NAME1,
  [_G.LE_EXPANSION_WRATH_OF_THE_LICH_KING] = _G.EXPANSION_NAME2,
  [_G.LE_EXPANSION_CATACLYSM] = _G.EXPANSION_NAME3,
  [_G.LE_EXPANSION_MISTS_OF_PANDARIA] = _G.EXPANSION_NAME4,
  [_G.LE_EXPANSION_WARLORDS_OF_DRAENOR] = _G.EXPANSION_NAME5,
  [_G.LE_EXPANSION_LEGION] = _G.EXPANSION_NAME6,
  [_G.LE_EXPANSION_BATTLE_FOR_AZEROTH] = _G.EXPANSION_NAME7,
  [_G.LE_EXPANSION_SHADOWLANDS] = _G.EXPANSION_NAME8,
  [_G.LE_EXPANSION_DRAGONFLIGHT] = _G.EXPANSION_NAME9,
}

if addon.isRetail then
  const.EXPANSION_MAP[_G.LE_EXPANSION_WAR_WITHIN] = _G.EXPANSION_NAME10
  const.EXPANSION_MAP[_G.LE_EXPANSION_MIDNIGHT] = _G.EXPANSION_NAME11
end

-- TBC Anniversary uses special expansion ID 254 for TBC items
if addon.isAnniversary then
  const.EXPANSION_MAP[254] = "The Burning Crusade"
end

---@class BriefExpansionMap
---@type table<number, string>
const.BRIEF_EXPANSION_MAP = {
  [_G.LE_EXPANSION_CLASSIC] = "classic",
  [_G.LE_EXPANSION_BURNING_CRUSADE] = "bc",
  [_G.LE_EXPANSION_WRATH_OF_THE_LICH_KING] = "wotlk",
  [_G.LE_EXPANSION_CATACLYSM] = "cata",
  [_G.LE_EXPANSION_MISTS_OF_PANDARIA] = "mop",
  [_G.LE_EXPANSION_WARLORDS_OF_DRAENOR] = "wod",
  [_G.LE_EXPANSION_LEGION] = "legion",
  [_G.LE_EXPANSION_BATTLE_FOR_AZEROTH] = "bfa",
  [_G.LE_EXPANSION_SHADOWLANDS] = "sl",
  [_G.LE_EXPANSION_DRAGONFLIGHT] = "df",
}

if addon.isRetail then
  const.BRIEF_EXPANSION_MAP[_G.LE_EXPANSION_WAR_WITHIN] = "tww"
  const.BRIEF_EXPANSION_MAP[_G.LE_EXPANSION_MIDNIGHT] = "midnight"
end

-- TBC Anniversary uses special expansion ID 254 for TBC items
if addon.isAnniversary then
  const.BRIEF_EXPANSION_MAP[254] = "bc"
end

---@class TradeSkillMap
---@type table<number, string>
const.TRADESKILL_MAP = {
	[ 0] = C_Item.GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 0),   -- "Trade Goods (OBSOLETE)"
	[ 1] = L:G("Engineering"),                                         -- "Parts"
	[ 2] = C_Item.GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 2),   -- "Explosives (OBSOLETE)"
	[ 3] = C_Item.GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 3),   -- "Devices (OBSOLETE)"
	[ 4] = C_Item.GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 4),   -- "Jewelcrafting"
	[ 5] = L:G("Tailoring"),                                           -- "Cloth"
	[ 6] = L:G("Leatherworking"),                                      -- "Leather"
	[ 7] = L:G("Mining"),                                              -- "Metal & Stone"
	[ 8] = C_Item.GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 8),   -- "Cooking"
	[ 9] = L:G("Herbalism"),                                           -- "Herb"
	[10] = C_Item.GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 10),  -- "Elemental"
	[11] = C_Item.GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 11),  -- "Other"
	[12] = C_Item.GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 12),  -- "Enchanting"
	[13] = C_Item.GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 13),  -- "Materials (OBSOLETE)"
	[14] = C_Item.GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 14),  -- "Item Enchantment (OBSOLETE)"
	[15] = C_Item.GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 15),  -- "Weapon Enchantment - Obsolete"
	[16] = C_Item.GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 16),  -- "Inscription"
	[17] = C_Item.GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 17),  -- "Explosives and Devices (OBSOLETE)"
	[18] = C_Item.GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 18),  -- "Optional Reagents"
	[19] = C_Item.GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 19),  -- "Finishing Reagents"
}

---@class EquipmentSlotsMap
---@type number[]
const.EQUIPMENT_SLOTS = {
  INVSLOT_AMMO,
  INVSLOT_BACK,
  INVSLOT_BODY,
  INVSLOT_CHEST,
  INVSLOT_FEET,
  INVSLOT_FINGER1,
  INVSLOT_FINGER2,
  INVSLOT_HAND,
  INVSLOT_HEAD,
  INVSLOT_LEGS,
  INVSLOT_MAINHAND,
  INVSLOT_NECK,
  INVSLOT_OFFHAND,
  INVSLOT_RANGED,
  INVSLOT_SHOULDER,
  INVSLOT_TABARD,
  INVSLOT_TRINKET1,
  INVSLOT_TRINKET2,
  INVSLOT_WAIST,
  INVSLOT_WRIST,
}

---@type table<number, number[]>
const.INVENTORY_TYPE_TO_INVENTORY_SLOTS = {
  [Enum.InventoryType.IndexHeadType] = {INVSLOT_HEAD},
  [Enum.InventoryType.IndexNeckType] = {INVSLOT_NECK},
  [Enum.InventoryType.IndexShoulderType] = {INVSLOT_SHOULDER},
  [Enum.InventoryType.IndexBodyType] = {INVSLOT_BODY},
  [Enum.InventoryType.IndexChestType] = {INVSLOT_CHEST},
  [Enum.InventoryType.IndexWaistType] = {INVSLOT_WAIST},
  [Enum.InventoryType.IndexLegsType] = {INVSLOT_LEGS},
  [Enum.InventoryType.IndexFeetType] = {INVSLOT_FEET},
  [Enum.InventoryType.IndexWristType] = {INVSLOT_WRIST},
  [Enum.InventoryType.IndexHandType] = {INVSLOT_HAND},
  [Enum.InventoryType.IndexFingerType] = {INVSLOT_FINGER1, INVSLOT_FINGER2},
  [Enum.InventoryType.IndexTrinketType] = {INVSLOT_TRINKET1, INVSLOT_TRINKET2},
  [Enum.InventoryType.IndexWeaponType] = {INVSLOT_MAINHAND, INVSLOT_OFFHAND},
  [Enum.InventoryType.IndexShieldType] = {INVSLOT_OFFHAND},
  [Enum.InventoryType.IndexRangedType] = {INVSLOT_MAINHAND},
  [Enum.InventoryType.IndexCloakType] = {INVSLOT_BACK},
  [Enum.InventoryType.Index2HweaponType] = {INVSLOT_MAINHAND},
  [Enum.InventoryType.IndexTabardType] = {INVSLOT_TABARD},
  [Enum.InventoryType.IndexRobeType] = {INVSLOT_CHEST},
  [Enum.InventoryType.IndexWeaponmainhandType] = {INVSLOT_MAINHAND},
  [Enum.InventoryType.IndexWeaponoffhandType] = {INVSLOT_OFFHAND},
  [Enum.InventoryType.IndexHoldableType] = {INVSLOT_OFFHAND},
  [Enum.InventoryType.IndexThrownType] = {INVSLOT_MAINHAND},
  [Enum.InventoryType.IndexRangedrightType] = {INVSLOT_MAINHAND},
}

-- FormLayout defines the layout type for a form.
---@enum FormLayoutType
const.FORM_LAYOUT = {
  -- TwoColumn is a form layout that has the section titles
  -- on the left and form elements on the right. The section
  -- title is pinned to the top as you scroll.
  TWO_COLUMN = 1,
  -- A stacked form is a simple form layout with all form
  -- elements stacked on top of each other. Section titles
  -- pin to the top as you scroll.
  STACKED = 2,
}

---@class SizeInfo
---@field columnCount number
---@field itemsPerRow number
---@field scale number
---@field width number
---@field height number
---@field opacity number

---@class (exact) CategoryOptions
---@field shown boolean

---@class (exact) Group
---@field id number Unique auto-incremented ID
---@field name string Display name for the tab
---@field order number Sort order for tab positioning

---@class databaseOptions
const.DATABASE_DEFAULTS = {
  profile = {
    firstTimeMenu = true,
    enabled = true,
    enableBagFading = false,
    showBagButton = true,
    enableBankBag = true,
    debug = false,
    inBagSearch = true,
    categorySell = false,
    showKeybindWarning = true,
    enterToMakeCategory = true,
    upgradeIconProvider = 'None',
    theme = 'Default',
    showFullSectionNames = {
      [const.BAG_KIND.BACKPACK] = false,
      [const.BAG_KIND.BANK] = false,
    },
    showAllFreeSpace = {
      [const.BAG_KIND.BACKPACK] = false,
      [const.BAG_KIND.BANK] = false,
    },
    extraGlowyButtons = {
      [const.BAG_KIND.BACKPACK] = false,
      [const.BAG_KIND.BANK] = false,
    },
    newItems = {
      [const.BAG_KIND.BACKPACK] = {
        markRecentItems = true,
        showNewItemFlash = false,
      },
      [const.BAG_KIND.BANK] = {
        markRecentItems = true,
        showNewItemFlash = false,
      },
    },
    stacking = {
      [const.BAG_KIND.BACKPACK]  = {
        mergeStacks = true,
        mergeUnstackable = true,
        unmergeAtShop = true,
        dontMergePartial = false,
        dontMergeTransmog = false,
      },
      [const.BAG_KIND.BANK]  = {
        mergeStacks = true,
        mergeUnstackable = true,
        unmergeAtShop = true,
        dontMergePartial = false,
        dontMergeTransmog = false,
      },
    },
    itemLevel = {
      [const.BAG_KIND.BACKPACK] = {
        enabled = true,
        color = true
      },
      [const.BAG_KIND.BANK] = {
        enabled = true,
        color = true
      },
    },
    itemLevelColor = {
      maxItemLevelByCharacter = {},  -- Per-character max item level tracking
      colors = {
        low = { red = 0.62, green = 0.62, blue = 0.62, alpha = 1 },   -- Gray
        mid = { red = 1, green = 1, blue = 1, alpha = 1 },            -- White
        high = { red = 0, green = 0.55, blue = 0.87, alpha = 1 },     -- Blue
        max = { red = 1, green = 0.5, blue = 0, alpha = 1 }           -- Orange
      }
    },
    positions = {
      [const.BAG_KIND.BACKPACK] = {},
      [const.BAG_KIND.BANK] = {},
    },
    anchorPositions = {
      [const.BAG_KIND.BACKPACK] = {},
      [const.BAG_KIND.BANK] = {},
    },
    ---@type table<BagKind, AnchorState>
    anchorState = {
      [const.BAG_KIND.BACKPACK] = {
        enabled = false,
        shown = false,
      },
      [const.BAG_KIND.BANK] = {
        enabled = false,
        shown = false,
      },
    },
    sectionSort = {
      [const.BAG_KIND.BACKPACK] = {
        [const.BAG_VIEW.ONE_BAG] = const.SECTION_SORT_TYPE.ALPHABETICALLY,
        [const.BAG_VIEW.SECTION_GRID] = const.SECTION_SORT_TYPE.ALPHABETICALLY,
        [const.BAG_VIEW.LIST] = const.SECTION_SORT_TYPE.ALPHABETICALLY,
        [const.BAG_VIEW.SECTION_ALL_BAGS] = const.SECTION_SORT_TYPE.ALPHABETICALLY,
      },
      [const.BAG_KIND.BANK] = {
        [const.BAG_VIEW.ONE_BAG] = const.SECTION_SORT_TYPE.ALPHABETICALLY,
        [const.BAG_VIEW.SECTION_GRID] = const.SECTION_SORT_TYPE.ALPHABETICALLY,
        [const.BAG_VIEW.LIST] = const.SECTION_SORT_TYPE.ALPHABETICALLY,
        [const.BAG_VIEW.SECTION_ALL_BAGS] = const.SECTION_SORT_TYPE.ALPHABETICALLY,
      },
    },
    itemSort = {
      [const.BAG_KIND.BACKPACK] = {
        [const.BAG_VIEW.ONE_BAG] = const.ITEM_SORT_TYPE.QUALITY_THEN_ALPHABETICALLY,
        [const.BAG_VIEW.SECTION_GRID] = const.ITEM_SORT_TYPE.QUALITY_THEN_ALPHABETICALLY,
        [const.BAG_VIEW.LIST] = const.ITEM_SORT_TYPE.QUALITY_THEN_ALPHABETICALLY,
        [const.BAG_VIEW.SECTION_ALL_BAGS] = const.ITEM_SORT_TYPE.QUALITY_THEN_ALPHABETICALLY,
      },
      [const.BAG_KIND.BANK] = {
        [const.BAG_VIEW.ONE_BAG] = const.ITEM_SORT_TYPE.QUALITY_THEN_ALPHABETICALLY,
        [const.BAG_VIEW.SECTION_GRID] = const.ITEM_SORT_TYPE.QUALITY_THEN_ALPHABETICALLY,
        [const.BAG_VIEW.LIST] = const.ITEM_SORT_TYPE.QUALITY_THEN_ALPHABETICALLY,
        [const.BAG_VIEW.SECTION_ALL_BAGS] = const.ITEM_SORT_TYPE.QUALITY_THEN_ALPHABETICALLY,
      },
    },
    customSectionSort = {
      ---@type table<string, number>
      [const.BAG_KIND.BACKPACK] = {},
      ---@type table<string, number>
      [const.BAG_KIND.BANK] = {},
      ---@type table<string, number>
    },
    collapsedSections = {
      ---@type table<string, boolean>
      [const.BAG_KIND.BACKPACK] = {},
      ---@type table<string, boolean>
      [const.BAG_KIND.BANK] = {},
    },
    size = {
      ---@type SizeInfo[]
      [const.BAG_VIEW.ONE_BAG] = {
        [const.BAG_KIND.BACKPACK] = {
          columnCount = 15,
          itemsPerRow = 15,
          scale = 100,
          width = 700,
          height = 500,
          opacity = 89,
        },
        [const.BAG_KIND.BANK] = {
          columnCount = 1,
          itemsPerRow = 15,
          scale = 100,
          width = 700,
          height = 500,
          opacity = 89,
        },
      },
      [const.BAG_VIEW.SECTION_GRID] = {
        [const.BAG_KIND.BACKPACK] = {
          columnCount = 2,
          itemsPerRow = 7,
          scale = 100,
          width = 700,
          height = 500,
          opacity = 89,
        },
        [const.BAG_KIND.BANK] = {
          columnCount = 2,
          itemsPerRow = 7,
          scale = 100,
          width = 700,
          height = 500,
          opacity = 89,
        },
      },
      [const.BAG_VIEW.LIST] = {
        [const.BAG_KIND.BACKPACK] = {
          columnCount = 1,
          itemsPerRow = 15,
          scale = 100,
          width = 700,
          height = 500,
          opacity = 89,
        },
        [const.BAG_KIND.BANK] = {
          columnCount = 5,
          itemsPerRow = 5,
          scale = 100,
          width = 700,
          height = 500,
          opacity = 89,
        },
      },
      [const.BAG_VIEW.SECTION_ALL_BAGS] = {
        [const.BAG_KIND.BACKPACK] = {
          columnCount = 1,
          itemsPerRow = 15,
          scale = 100,
          width = 700,
          height = 500,
          opacity = 89,
        },
        [const.BAG_KIND.BANK] = {
          columnCount = 1,
          itemsPerRow = 15,
          scale = 100,
          width = 700,
          height = 500,
          opacity = 89,
        },
      },
    },
    views = {
      [const.BAG_KIND.BACKPACK] = const.BAG_VIEW.SECTION_GRID,
      [const.BAG_KIND.BANK] = const.BAG_VIEW.SECTION_GRID,
    },
    previousViews = {
      [const.BAG_KIND.BACKPACK] = const.BAG_VIEW.SECTION_GRID,
      [const.BAG_KIND.BANK] = const.BAG_VIEW.SECTION_GRID,
    },
    ---@type table<string, CategoryOptions>
    categoryOptions = {},
    ---@type table<string, CustomCategoryFilter>
    customCategoryFilters = {},
    ---@type table<string, CustomCategoryFilter>
    ephemeralCategoryFilters = {},
    ---@type table<number, string>
    customCategoryIndex = {},
    categoryFilters = {
      [const.BAG_KIND.BACKPACK] = {
        Type = true,
        Subtype = false,
        Expansion = false,
        TradeSkill = false,
        RecentItems = true,
        GearSet = true,
        EquipmentLocation = true,
      },
      [const.BAG_KIND.BANK] = {
        Type = true,
        Subtype = false,
        Expansion = false,
        TradeSkill = false,
        RecentItems = true,
        GearSet = true,
        EquipmentLocation = true,
      },
    },
    ---@type table<string, boolean>
    lockedItems = {},
    ---@type number
    newItemTime = 300,
    -- Groups feature: virtual tabs for organizing categories in backpack
    ---@type table<number, Group>
    groups = {
      [1] = {
        id = 1,
        name = "Backpack",
        order = 1,
        kind = const.BAG_KIND.BACKPACK,
        isDefault = true,
      },
    },
    ---@type number
    groupCounter = 1,
    ---@type table<string, number>
    categoryToGroup = {},
    ---@type table<BagKind, number>
    activeGroup = {
      [const.BAG_KIND.BACKPACK] = 1,
    },
    ---@type table<BagKind, boolean>
    groupsEnabled = {
      [const.BAG_KIND.BACKPACK] = true,
      [const.BAG_KIND.BANK] = true,
    },
    -- Profile system migration flag
    __profileSystemMigrated = false,
  },
  char = {}
}
