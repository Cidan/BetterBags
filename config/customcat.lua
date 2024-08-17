local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class Database: AceModule
local DB = addon:GetModule('Database')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Config: AceModule
local config = addon:GetModule('Config')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@param category string
---@return AceConfig.OptionsTable
function config:CreateCustomCategoryConfig(category)
  ---@type AceConfig.OptionsTable
  local options = {
    name = category,
    type = "group",
    args = {
      items = {
        type = "multiselect",
        name = L:G("Items"),
        dialogControl = "ItemList",
        order = 1,
        values = categories:GetMergedCategory(category)
      },
      delete = {
        type = "execute",
        name = L:G("Delete Category"),
        confirm = true,
        confirmText = L:G("Are you sure you want to delete this category?"),
        order = 2,
        func = function()
          categories:DeleteCategory(category)
        end,
      }
    },
  }
  return options
end

---@return AceConfig.OptionsTable
function config:GetCustomCategoryConfig()
  ---@type AceConfig.OptionsTable
  local options = {
    name = L:G("Custom Categories"),
    type = "group",
    args = {
      createCategory = {
        name = L:G("Create Category"),
        type = "group",
        inline = true,
        args = {
          createHelp = {
            type = "description",
            name = L:G("Custom categories allow you to create your own categories for items. Type the name of the category you want to create in the box below and press enter to create an empty category."),
            order = 0,
          },
          useHelp = {
            type = "description",
            name = L:G("Categories you create can be enabled and disabled just like the default categories in the configuration menu option for the bag (Backpack or Bank) on the left. Once you have created a category, you can configure it by selecting it on the menu on the left."),
            order = 1,
          },
          name = {
            name = L:G("New Category Name"),
            type = "input",
            width = "full",
            order = 2,
            get = function()
              return ""
            end,
            set = function(_, value)
              if value == "" then return end

              local newCategoryName = value

              if DB:GetCreateCategoryForAllExpansions() then
                for full, abbr in pairs(const.BRIEF_DISPLAY_EXPANSION_MAP) do
                  if DB:GetCreateCategoryForAllExpansionsType() == "abbr" then
                    newCategoryName = value .. ' - ' .. abbr
                  else
                    newCategoryName = value .. ' - ' .. full
                  end
                  categories:CreateCategory({
                    name = newCategoryName,
                    save = true,
                    enabled = {
                      [const.BAG_KIND.BACKPACK] = true,
                      [const.BAG_KIND.BANK] = true,
                    },
                    itemList = {},
                    readOnly = false,
                  })
                end
              else
                categories:CreateCategory({
                  name = newCategoryName,
                  save = true,
                  enabled = {
                    [const.BAG_KIND.BACKPACK] = true,
                    [const.BAG_KIND.BANK] = true,
                  },
                  itemList = {},
                  readOnly = false,
                })
              end
            end,
          },
          createAllExpansions = {
            type = "toggle",
            width = "full",
            order = 3,
            name = L:G("Create Category For All Expansions"),
            desc = L:G("If checked, the category will be created for every expansion."),
            get = function()
              return DB:GetCreateCategoryForAllExpansions()
            end,
            set = function(_, value)
              DB:SetCreateCategoryForAllExpansions(value)
            end,
          },
          createAllExpansionsHelp = {
            type = "description",
            name = L:G("If enabled, creates the custom category for each expansion.\n" ..
            "For example, entering 'Alchemy' will create:\n\n" ..
            "Alchemy - The Burning Crusade\n" ..
            "Alchemy - Wrath of the Lich King\n" ..
            "Alchemy - Cataclysm\n" ..
            "etc."),
            order = 4,
          },
          createAllExpansionsType = {
            type = "select",
            name = L:G("Set expansion name type to include in category name"),
            desc = L:G("Set abbreviated or full expansion name."),
            order = 5,
            style = "radio",
            get = function()
              return DB:GetCreateCategoryForAllExpansionsType()
            end,
            set = function(_, value)
              DB:SetCreateCategoryForAllExpansionsType(value)
            end,
            values = {
              ["abbr"] = L:G("Abbreviated"),
              ["full"] = L:G("Full"),
            }
          },
        }
      }
    },
  }

  for category, _ in pairs(categories:GetAllCategories()) do
    options.args[category] = config:CreateCustomCategoryConfig(category)
  end
  return options
end