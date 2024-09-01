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

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class Config: AceModule
local config = addon:GetModule('Config')

---@class Context: AceModule
local context = addon:GetModule('Context')

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
      local ctx = context:New('on_click')
      events:SendMessage(ctx, 'bags/FullRefreshAll')
    end,
    values = {}
  }
  for category, _ in pairs(categories:GetAllCategories()) do
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
              local ctx = context:New('on_click')
              events:SendMessage(ctx, 'bags/FullRefreshAll')
            end,
            values = {
              ["RecentItems"] = L:G("Recent Items"),
              ["Type"] = L:G("Type"),
              ["TradeSkill"] = L:G("Trade Skill"),
              ["GearSet"] = L:G("Gear Set"),
              ["EquipmentLocation"] = L:G("Equipment Location"),
            }
          },
          customCategories = config:GetCustomCategoryOptions(kind),
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
          local ctx = context:New('on_click')
          events:SendMessage(ctx, 'bags/FullRefreshAll')
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
          local ctx = context:New('on_click')
          events:SendMessage(ctx, 'bags/FullRefreshAll')
        end,
        values = {
          [const.ITEM_SORT_TYPE.QUALITY_THEN_ALPHABETICALLY] = L:G("Quality, then Alphabetically"),
          [const.ITEM_SORT_TYPE.ALPHABETICALLY_THEN_QUALITY] = L:G("Alphabetically, then Quality"),
          [const.ITEM_SORT_TYPE.ITEM_LEVEL] = L:G("Item Level"),
        }
      },
      stacking = {
        type = "group",
        name = L:G("Stacking"),
        order = 6,
        inline = true,
        args = {
          mergeStacks = {
            type = "toggle",
            name = L:G("Merge Stacks"),
            desc = L:G("Merge stacks of the same item into a single stack."),
            order = 1,
            get = function()
              return DB:GetStackingOptions(kind).mergeStacks
            end,
            set = function(_, value)
              DB:SetMergeItems(kind, value)
              local ctx = context:New('on_click')
              events:SendMessage(ctx, 'bags/FullRefreshAll')
            end,
          },
          mergeUnstackable = {
            type = "toggle",
            name = L:G("Merge Unstackable"),
            desc = L:G("Merge unstackable items of the same kind into a single stack, such as armors, bags, etc."),
            order = 2,
            get = function()
              return DB:GetStackingOptions(kind).mergeUnstackable
            end,
            set = function(_, value)
              DB:SetMergeUnstackable(kind, value)
              local ctx = context:New('on_click')
              events:SendMessage(ctx, 'bags/FullRefreshAll')
            end,
          },
          unmergeAtShop = {
            type = "toggle",
            name = L:G("Unmerge at Shop"),
            desc = L:G("Unmerge all items when visiting a vendor."),
            order = 3,
            get = function()
              return DB:GetStackingOptions(kind).unmergeAtShop
            end,
            set = function(_, value)
              DB:SetUnmergeAtShop(kind, value)
              local ctx = context:New('on_click')
              events:SendMessage(ctx, 'bags/FullRefreshAll')
            end,
          },
          dontMergePartial = {
            type = "toggle",
            name = L:G("Don't Merge Partial"),
            desc = L:G("Don't merge stacks of items that aren't full stacks."),
            order = 3,
            get = function()
              return DB:GetStackingOptions(kind).dontMergePartial
            end,
            set = function(_, value)
              DB:SetDontMergePartial(kind, value)
              local ctx = context:New('on_click')
              events:SendMessage(ctx, 'bags/FullRefreshAll')
            end,
          },
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
              local ctx = context:New('on_click')
              events:SendMessage(ctx, 'bags/FullRefreshAll')
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
              local ctx = context:New('on_click')
              events:SendMessage(ctx, 'bags/FullRefreshAll')
            end,
          },
        }
      },
      display = {
        type = "group",
        name = L:G("Display"),
        order = 8,
        inline = true,
        args = {
          showFullSectionNames = {
            type = "toggle",
            name = L:G("Show Full Section Names"),
            desc = L:G("Show the full section in the bag window without truncating it with '...'"),
            order = 0,
            width = "full",
            get = function()
              return DB:GetShowFullSectionNames(kind)
            end,
            set = function(_, value)
              DB:SetShowFullSectionNames(kind, value)
              local ctx = context:New('on_click')
              events:SendMessage(ctx, 'bags/FullRefreshAll')
            end,
          },
          showAllFreeSpace = {
            type = "toggle",
            name = L:G("Show All Free Space Slots"),
            desc = L:G("Show all free space slots in the bag window."),
            order = 1,
            width = "full",
            get = function()
              return DB:GetShowAllFreeSpace(kind)
            end,
            set = function(_, value)
              DB:SetShowAllFreeSpace(kind, value)
              local ctx = context:New('on_click')
              events:SendMessage(ctx, 'bags/FullRefreshAll')
            end,
          },
          showExtraGlowyButtons = {
            type = "toggle",
            name = L:G("Use Extra Glowy Item Buttons"),
            desc = L:G("Use extra glowy item buttons for items in this bag."),
            order = 2,
            width = "full",
            get = function()
              return DB:GetExtraGlowyButtons(kind)
            end,
            set = function(_, value)
              DB:SetExtraGlowyButtons(kind, value)
              local ctx = context:New('on_click')
              events:SendMessage(ctx, 'bags/FullRefreshAll')
            end,
          },
          itemsPerRow = {
            type = "range",
            name = L:G("Items Per Row"),
            desc = L:G("Set the number of items per row in this bag."),
            order = 3,
            min = 3,
            max = 20,
            step = 1,
            get = function()
              return DB:GetBagSizeInfo(kind, DB:GetBagView(kind)).itemsPerRow
            end,
            set = function(_, value)
              DB:SetBagViewSizeItems(kind, DB:GetBagView(kind), value)
              bucket:Later("setItemsPerRow", 0.2, function()
                local ctx = context:New('on_click')
                events:SendMessage(ctx, 'bags/FullRefreshAll')
              end)
            end,
          },
          opacity = {
            type = "range",
            name = L:G("Opacity"),
            desc = L:G("Set the opacity of this bag."),
            order = 4,
            min = 60,
            max = 100,
            step = 1,
            get = function()
              return DB:GetBagSizeInfo(kind, DB:GetBagView(kind)).opacity
            end,
            set = function(_, value)
              DB:SetBagViewSizeOpacity(kind, DB:GetBagView(kind), value)
              themes:UpdateOpacity()
            end,
          },
          sectionsPerRow = {
            type = "range",
            name = L:G("Columns"),
            desc = L:G("Set the number of columns sections will fit into."),
            order = 5,
            min = 1,
            max = 20,
            step = 1,
            get = function()
              return DB:GetBagSizeInfo(kind, DB:GetBagView(kind)).columnCount
            end,
            set = function(_, value)
              DB:SetBagViewSizeColumn(kind, DB:GetBagView(kind), value)
              bucket:Later("setSectionsPerRow", 0.2, function()
                local ctx = context:New('on_click')
                events:SendMessage(ctx, 'bags/FullRefreshAll')
              end)
            end,
          },
          scale = {
            type = "range",
            name = L:G("Scale"),
            desc = L:G("Set the scale of this bag."),
            order = 6,
            min = 60,
            max = 160,
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