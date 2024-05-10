---@diagnostic disable: duplicate-set-field,duplicate-doc-field,duplicate-doc-alias
local addonName = ... ---@type string
---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Constants: AceModule
local const = addon:NewModule('Constants')

-- Constants for detecting WoW version.
addon.isRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
addon.isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
addon.isBCC = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
addon.isCata = WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC

---@enum BagKind
const.BAG_KIND = {
  UNDEFINED = -1,
  BACKPACK = 0,
  BANK = 1,
  REAGENT_BANK = 2,
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

---@enum ItemSortType
const.ITEM_SORT_TYPE = {
  ALPHABETICALLY_THEN_QUALITY = 1,
  QUALITY_THEN_ALPHABETICALLY = 2,
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

const.OFFSETS = {
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

if not addon.isRetail then
  Enum.ItemQuality.Poor = 0
  Enum.ItemQuality.Common = 1
  Enum.ItemQuality.Uncommon = 2
  Enum.ItemQuality.Rare = 3
  Enum.ItemQuality.Epic = 4
  Enum.ItemQuality.Legendary = 5
  Enum.ItemQuality.Artifact = 6
  Enum.ItemQuality.Heirloom = 7
  Enum.ItemQuality.WoWToken = 8
end

const.ITEM_QUALITY_COLOR = {
  [Enum.ItemQuality.Poor] = {0.62, 0.62, 0.62, 1},
  [Enum.ItemQuality.Common] = {1, 1, 1, 1},
  [Enum.ItemQuality.Uncommon] = {0.12, 1, 0, 1},
  [Enum.ItemQuality.Rare] = {0.00, 0.44, 0.87, 1},
  [Enum.ItemQuality.Epic] = {0.64, 0.21, 0.93, 1},
  [Enum.ItemQuality.Legendary] = {1, 0.50, 0, 1},
  [Enum.ItemQuality.Artifact] = {0.90, 0.80, 0.50, 1},
  [Enum.ItemQuality.Heirloom] = {0, 0.8, 1, 1},
  [Enum.ItemQuality.WoWToken] = {0, 0.8, 1, 1},
}

const.ITEM_QUALITY_HIGHLIGHT = {
  [Enum.ItemQuality.Poor] = {0.682, 0.682, 0.682, 1},
  [Enum.ItemQuality.Common] = {1, 1, 1, 1},
  [Enum.ItemQuality.Uncommon] = {0.132, 1, 0, 1},
  [Enum.ItemQuality.Rare] = {0, 0.484, 0.957, 1},
  [Enum.ItemQuality.Epic] = {0.704, 0.231, 1, 1},
  [Enum.ItemQuality.Legendary] = {1, 0.55, 0, 1},
  [Enum.ItemQuality.Artifact] = {0.99, 0.88, 0.55, 1},
  [Enum.ItemQuality.Heirloom] = {0, 0.88, 1, 1},
  [Enum.ItemQuality.WoWToken] = {0, 0.88, 1, 1},
}
const.ITEM_QUALITY_COLOR_HIGH = {
  [Enum.ItemQuality.Poor] = {0.558, 0.558, 0.558, 0.3},
  [Enum.ItemQuality.Common] = {0.9, 0.9, 0.9, 0.3},
  [Enum.ItemQuality.Uncommon] = {0.108, 0.9, 0, 0.3},
  [Enum.ItemQuality.Rare] = {0, 0.396, 0.783, 0.3},
  [Enum.ItemQuality.Epic] = {0.576, 0.189, 0.837, 0.3},
  [Enum.ItemQuality.Legendary] = {0.9, 0.45, 0, 0.3},
  [Enum.ItemQuality.Artifact] = {0.81, 0.72, 0.45, 0.3},
  [Enum.ItemQuality.Heirloom] = {0, 0.72, 0.9, 0.3},
  [Enum.ItemQuality.WoWToken] = {0, 0.72, 0.9, 0.3},
}

const.ITEM_QUALITY_COLOR_LOW = {
  [Enum.ItemQuality.Poor] = {0.558, 0.558, 0.558, 0.1},
  [Enum.ItemQuality.Common] = {0.9, 0.9, 0.9, 0.1},
  [Enum.ItemQuality.Uncommon] = {0.108, 0.9, 0, 0.1},
  [Enum.ItemQuality.Rare] = {0, 0.396, 0.783, 0.1},
  [Enum.ItemQuality.Epic] = {0.576, 0.189, 0.837, 0.1},
  [Enum.ItemQuality.Legendary] = {0.9, 0.45, 0, 0.1},
  [Enum.ItemQuality.Artifact] = {0.81, 0.72, 0.45, 0.1},
  [Enum.ItemQuality.Heirloom] = {0, 0.72, 0.9, 0.1},
  [Enum.ItemQuality.WoWToken] = {0, 0.72, 0.9, 0.1},
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
  [_G.LE_EXPANSION_SHADOWLANDS] = "shadowlands",
  [_G.LE_EXPANSION_DRAGONFLIGHT] = "dragonflight",
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

---@class CustomCategoryFilter
---@field name string
---@field enabled table<BagKind, boolean>
---@field itemList table<number, boolean>
---@field readOnly boolean

---@class databaseOptions
const.DATABASE_DEFAULTS = {
  profile = {
    firstTimeMenu = true,
    enabled = true,
    showBagButton = true,
    debug = false,
    inBagSearch = false,
    showKeybindWarning = true,
    stacking = {
      [const.BAG_KIND.BACKPACK]  = {
        mergeStacks = true,
        mergeUnstackable = true,
        unmergeAtShop = true,
        dontMergePartial = false,
      },
      [const.BAG_KIND.BANK]  = {
        mergeStacks = true,
        mergeUnstackable = true,
        unmergeAtShop = true,
        dontMergePartial = false,
      }
    },
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
      [const.BAG_KIND.BANK] = const.GRID_COMPACT_STYLE.SIMPLE,
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
    size = {
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
        }
      },
      [const.BAG_VIEW.SECTION_GRID] = {
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
        }
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
        }
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
        }
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
    ---@type table<string, CustomCategoryFilter>
    customCategoryFilters = {},
    ---@type table<string, CustomCategoryFilter>
    ephemeralCategoryFilters = {},
    ---@type table<number, string>
    customCategoryIndex = {},
    categoryFilters = {
      [const.BAG_KIND.BACKPACK] = {
        Type = true,
        Expansion = false,
        TradeSkill = false,
        RecentItems = true,
        GearSet = true,
        EquipmentLocation = true,
      },
      [const.BAG_KIND.BANK] = {
        Type = true,
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
  },
  char = {}
}