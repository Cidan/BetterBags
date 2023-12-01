local addonName = ... ---@type string
---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

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
const.BANK_ONLY_BAGS_LIST = {
  Enum.BagIndex.BankBag_1,
  Enum.BagIndex.BankBag_2,
  Enum.BagIndex.BankBag_3,
  Enum.BagIndex.BankBag_4,
  Enum.BagIndex.BankBag_5,
  Enum.BagIndex.BankBag_6,
  Enum.BagIndex.BankBag_7,
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

---@enum BagView
const.BAG_VIEW = {
  ONE_BAG = 1,
  SECTION_GRID = 2,
  LIST = 3,
}

---@enum GridCompactStyle
const.GRID_COMPACT_STYLE = {
  NONE = 0,
  SIMPLE = 1,
  COMPACT = 2,
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

---@class TradeSkillMap
---@type table<number, string>
const.TRADESKILL_MAP = {
	[ 0] = GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 0),   -- "Trade Goods (OBSOLETE)"
	[ 1] = L:G("Engineering"),                                  -- "Parts"
	[ 2] = GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 2),   -- "Explosives (OBSOLETE)"
	[ 3] = GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 3),   -- "Devices (OBSOLETE)"
	[ 4] = GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 4),   -- "Jewelcrafting"
	[ 5] = L:G("Tailoring"),                                    -- "Cloth"
	[ 6] = L:G("Leatherworking"),                               -- "Leather"
	[ 7] = L:G("Mining"),                                       -- "Metal & Stone"
	[ 8] = GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 8),   -- "Cooking"
	[ 9] = L:G("Herbalism"),                                    -- "Herb"
	[10] = GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 10), -- "Elemental"
	[11] = GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 11), -- "Other"
	[12] = GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 12), -- "Enchanting"
	[13] = GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 13), -- "Materials (OBSOLETE)"
	[14] = GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 14), -- "Item Enchantment (OBSOLETE)"
	[15] = GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 15), -- "Weapon Enchantment - Obsolete"
	[16] = GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 16), -- "Inscription"
	[17] = GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 17), -- "Explosives and Devices (OBSOLETE)"
	[18] = GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 18), -- "Optional Reagents"
	[19] = GetItemSubClassInfo(Enum.ItemClass.Tradegoods, 19), -- "Finishing Reagents"
}

---@class databaseOptions
const.DATABASE_DEFAULTS = {
  profile = {
    enabled = true,
    showBagButton = true,
    itemLevel = {
      [const.BAG_KIND.BACKPACK] = {
        enabled = true,
        color = true
      },
      [const.BAG_KIND.BANK] = {
        enabled = true,
        color = true
      }
    },
    positions = {
      [const.BAG_KIND.BACKPACK] = {},
      [const.BAG_KIND.BANK] = {},
    },
    compaction = {
      [const.BAG_KIND.BACKPACK] = const.GRID_COMPACT_STYLE.SIMPLE,
      [const.BAG_KIND.BANK] = const.GRID_COMPACT_STYLE.NONE,
    },
    size = {
      [const.BAG_VIEW.ONE_BAG] = {
        [const.BAG_KIND.BACKPACK] = {
          columnCount = 15,
          itemsPerRow = 15,
          scale = 100,
          width = 700,
          height = 500,
        },
        [const.BAG_KIND.BANK] = {
          columnCount = 15,
          itemsPerRow = 5,
          scale = 100,
          width = 700,
          height = 500,
        }
      },
      [const.BAG_VIEW.SECTION_GRID] = {
        [const.BAG_KIND.BACKPACK] = {
          columnCount = 1,
          itemsPerRow = 15,
          scale = 100,
          width = 700,
          height = 500,
        },
        [const.BAG_KIND.BANK] = {
          columnCount = 5,
          itemsPerRow = 5,
          scale = 100,
          width = 700,
          height = 500,
        }
      },
      [const.BAG_VIEW.LIST] = {
        [const.BAG_KIND.BACKPACK] = {
          columnCount = 1,
          itemsPerRow = 15,
          scale = 100,
          width = 700,
          height = 500,
        },
        [const.BAG_KIND.BANK] = {
          columnCount = 5,
          itemsPerRow = 5,
          scale = 100,
          width = 700,
          height = 500,
        }
      },
    },
    views = {
      [const.BAG_KIND.BACKPACK] = const.BAG_VIEW.SECTION_GRID,
      [const.BAG_KIND.BANK] = const.BAG_VIEW.SECTION_GRID,
    },
    categoryFilters = {
      [const.BAG_KIND.BACKPACK] = {
        Type = true,
        Expansion = false,
        TradeSkill = false,
      },
      [const.BAG_KIND.BANK] = {
        Type = true,
        Expansion = false,
        TradeSkill = false,
      },
    }
  },
  char = {}
}