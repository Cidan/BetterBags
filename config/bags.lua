---@diagnostic disable: duplicate-set-field,duplicate-doc-field,duplicate-doc-alias
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Database: AceModule
local DB = addon:GetModule('Database')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Bucket: AceModule
local bucket = addon:GetModule('Bucket')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class Config: AceModule
local config = addon:GetModule('Config')

---@param kind BagKind
---@return AceConfig.OptionsTable
function config:GetCustomCategoryOptions(kind)
  if categories:GetCategoryCount() == 0 then
    return {
      type = "group",
      name = L:G("Custom Categories"),
      order = -1,
      inline = true,
      args = {
        noCategories = {
          type = "description",
          name = L:G("No custom categories have been created yet."),
          order = 1,
        }
      }
    }
  end
  ---@type AceConfig.OptionsTable
  local options = {
    type = "multiselect",
    name = L:G("Custom Categories"),
    desc = L:G("Select which custom categories to show in this bag. If an option is checked, items that belong to the checked category will be put into a section for that category."),
    order = -1,
    get = function(_, value)
      return categories:IsCategoryEnabled(kind, value)
    end,
    set = function(_, value)
      categories:SetCategoryState(kind, value, not categories:IsCategoryEnabled(kind, value))
      config:GetBag(kind):Wipe()
      config:GetBag(kind):Refresh()
    end,
    values = {}
  }
  for category, _ in pairs(DB:GetAllItemCategories()) do
    if type(category) == "string" then
      options.values[category] = category
    else
      DB:DeleteItemCategory(category)
    end
  end
  return options
end

---@param kind BagKind
---@return AceConfig.OptionsTable
function config:GetBagOptions(kind)
  ---@type AceConfig.OptionsTable
  local options = {
    type = "group",
    name = kind == const.BAG_KIND.BACKPACK and L:G("Backpack") or L:G("Bank"),
    args = {

      categories = {
        type = "group",
        name = L:G("Categories"),
        order = 0,
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
              config:GetBag(kind):Wipe()
              config:GetBag(kind):Refresh()
            end,
            values = {
              ["RecentItems"] = L:G("Recent Items"),
              ["Type"] = L:G("Type"),
              ["Subtype"] = L:G("Subtype"),
              ["Expansion"] = L:G("Expansion"),
              ["TradeSkill"] = L:G("Trade Skill")
            }
          },
          customCategories = config:GetCustomCategoryOptions(kind),
        }
      },

      itemCompaction = {
        type = "select",
        name = L:G("Item Compaction"),
        desc = L:G("If Simple is selected, item sections will be sorted from left to right, however if a section can fit in the same row as the section above it, the section will move up."),
        order = 3,
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
        order = 4,
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
        order = 5,
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

      itemLevel = {
        type = "group",
        name = L:G("Item Level"),
        order = 6,
        inline = true,
        args = {
          enabled = {
            type = "toggle",
            name = L:G("Enabled"),
            desc = L:G("Show the item level of items in this bag."),
            order = 1,
            get = function()
              return DB:GetItemLevelOptions(kind).enabled
            end,
            set = function(_, value)
              DB:SetItemLevelEnabled(kind, value)
              config:GetBag(kind):Wipe()
              config:GetBag(kind):Refresh()
            end,
          },
          color = {
            type = "toggle",
            name = L:G("Color"),
            desc = L:G("Color the item level text based on the item's quality."),
            order = 2,
            get = function()
              return DB:GetItemLevelOptions(kind).color
            end,
            set = function(_, value)
              DB:SetItemLevelColorEnabled(kind, value)
              config:GetBag(kind):Wipe()
              config:GetBag(kind):Refresh()
            end,
          },
          dynamicColor = { 
            type = "toggle",
            name = L:G("Dynamic colors"),
            desc = L:G("Dynamically select the item level text color based on how the item's level compares to your average item level.\n\nSame or higher: Orange\n1-10 lower: Purple\n11-15 lower: Blue\n16-20 lower: Green\n21+ lower: Gray"),
            order = 3,
            get = function()
              return DB:GetItemLevelOptions(kind).dynamicColor
            end,
            set = function(_, value)
              DB:SetItemLevelDynamicColorEnabled(kind, value)
              config:GetBag(kind):Wipe()
              config:GetBag(kind):Refresh()
            end,
          },
        }
      },

      view = {
        type = "select",
        name = L:G("View"),
        desc = L:G("Select which view to use for this bag."),
        order = 7,
        style = "radio",
        get = function()
          return DB:GetBagView(kind)
        end,
        set = function(_, value)
          DB:SetBagView(kind, value)
          config:GetBag(kind):Wipe()
          config:GetBag(kind):Refresh()
        end,
        values = {
          [const.BAG_VIEW.SECTION_GRID] = L:G("Section Grid"),
          [const.BAG_VIEW.LIST] = L:G("List"),
          [const.BAG_VIEW.ONE_BAG] = L:G("One Bag"),
        }
      },

      display = {
        type = "group",
        name = L:G("Display"),
        order = 8,
        inline = true,
        args = {
          itemsPerRow = {
            type = "range",
            name = L:G("Items Per Row"),
            desc = L:G("Set the number of items per row in this bag."),
            order = 0,
            min = 3,
            max = 20,
            step = 1,
            get = function()
              return DB:GetBagSizeInfo(kind, DB:GetBagView(kind)).itemsPerRow
            end,
            set = function(_, value)
              DB:SetBagViewSizeItems(kind, DB:GetBagView(kind), value)
              bucket:Later("setItemsPerRow", 0.2, function()
                config:GetBag(kind):Wipe()
                config:GetBag(kind):Refresh()
              end)
            end,
          },
          sectionsPerRow = {
            type = "range",
            name = L:G("Sections Per Row"),
            desc = L:G("Set the number of sections per row in this bag."),
            order = 1,
            min = 1,
            max = 20,
            step = 1,
            get = function()
              return DB:GetBagSizeInfo(kind, DB:GetBagView(kind)).columnCount
            end,
            set = function(_, value)
              DB:SetBagViewSizeColumn(kind, DB:GetBagView(kind), value)
              bucket:Later("setSectionsPerRow", 0.2, function()
                config:GetBag(kind):Wipe()
                config:GetBag(kind):Refresh()
              end)
            end,
          },
          opacity = {
            type = "range",
            name = L:G("Opacity"),
            desc = L:G("Set the opacity of this bag."),
            order = 1,
            min = 60,
            max = 100,
            step = 1,
            get = function()
              return DB:GetBagSizeInfo(kind, DB:GetBagView(kind)).opacity
            end,
            set = function(_, value)
              config:GetBag(kind).frame.Bg:SetAlpha(value / 100)
              DB:SetBagViewSizeOpacity(kind, DB:GetBagView(kind), value)
            end,
          },
          scale = {
            type = "range",
            name = L:G("Scale"),
            desc = L:G("Set the scale of this bag."),
            order = 2,
            min = 60,
            max = 120,
            step = 1,
            get = function()
              return DB:GetBagSizeInfo(kind, DB:GetBagView(kind)).scale
            end,
            set = function(_, value)
              config:GetBag(kind).frame:SetScale(value / 100)
              DB:SetBagViewSizeScale(kind, DB:GetBagView(kind), value)
            end,
          },
        }
      },
    }
  }
  return options
end