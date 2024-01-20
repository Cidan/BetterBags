local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Database: AceModule
local DB = addon:GetModule('Database')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Config: AceModule
local config = addon:GetModule('Config')

---@param kind BagKind
---@return AceConfig.OptionsTable
function config:GetBagOptions(kind)
  ---@type AceConfig.OptionsTable
  local options = {
    type = "group",
    name = kind == const.BAG_KIND.BACKPACK and L:G("Backpack") or L:G("Bank"),
    args = {

      categories = {
        type = "multiselect",
        name = L:G("Categories"),
        desc = L:G("Select which categories to show in this bag. If an option is checked, items that belong to the checked category will be put into a section for that category."),
        order = 1,
        get = function(_, value)
          return DB:GetCategoryFilter(kind, value)
        end,
        set = function(_, value)
          DB:SetCategoryFilter(kind, value, not DB:GetCategoryFilter(kind, value))
          if not DB:GetCategoryFilter(kind, "RecentItems") then
            config:GetBag(kind):ClearRecentItems()
          end
          config:GetBag(kind):Wipe()
          config:GetBag(kind):Refresh()
        end,
        values = {
          ["RecentItems"] = L:G("Recent Items"),
          ["Type"] = L:G("Type"),
          ["Expansion"] = L:G("Expansion"),
          ["TradeSkill"] = L:G("Trade Skill")
        }
      },

      itemCompaction = {
        type = "select",
        name = L:G("Item Compaction"),
        desc = L:G("If Simple is selected, item sections will be sorted from left to right, however if a section can fit in the same row as the section above it, the section will move up."),
        order = 2,
        style = "radio",
        get = function()
          return DB:GetBagCompaction(kind)
        end,
        set = function(_, value)
          DB:SetBagCompaction(kind, value)
          config:GetBag(kind):Wipe()
          config:GetBag(kind):Refresh()
        end,
        values =  {
          [const.GRID_COMPACT_STYLE.NONE] = L:G("None"),
          [const.GRID_COMPACT_STYLE.SIMPLE] = L:G("Simple"),
        }
      },

      sectionSorting = {
        type = "select",
        name = L:G("Section Sorting"),
        desc = L:G("Select how sections should be sorted."),
        order = 3,
        style = "radio",
        get = function()
          return DB:GetSectionSortType(kind, DB:GetBagView(kind))
        end,
        set = function(_, value)
          DB:SetSectionSortType(kind, DB:GetBagView(kind), value)
          config:GetBag(kind):Wipe()
          config:GetBag(kind):Refresh()
        end,
        values = {
          [const.SECTION_SORT_TYPE.ALPHABETICALLY] = L:G("Alphabetically"),
          [const.SECTION_SORT_TYPE.SIZE_DESCENDING] = L:G("Size Descending"),
          [const.SECTION_SORT_TYPE.SIZE_ASCENDING] = L:G("Size Ascending"),
        }
      },

      itemSorting = {
        type = "select",
        name = L:G("Item Sorting"),
        desc = L:G("Select how items should be sorted."),
        order = 4,
        style = "radio",
        get = function()
          return DB:GetItemSortType(kind, DB:GetBagView(kind))
        end,
        set = function(_, value)
          DB:SetItemSortType(kind, DB:GetBagView(kind), value)
          config:GetBag(kind):Wipe()
          config:GetBag(kind):Refresh()
        end,
        values = {
          [const.ITEM_SORT_TYPE.QUALITY_THEN_ALPHABETICALLY] = L:G("Quality, then Alphabetically"),
          [const.ITEM_SORT_TYPE.ALPHABETICALLY_THEN_QUALITY] = L:G("Alphabetically, then Quality"),
        }
      },

    }
  }
  return options
end