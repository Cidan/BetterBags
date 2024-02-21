local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class Database: AceModule
local DB = addon:GetModule('Database')

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
        values = DB:GetItemCategory(category)
      },
      rename = {
        type = "input",
        name = L:G("Rename Category"),
        width = "double",
        order = 2,
        get = function() return "" end,
        set = function(_, value)
          if value == "" then return end
          categories:RenameCategory(category, value)
        end,
      },
      delete = {
        type = "execute",
        name = L:G("Delete Category"),
        confirm = true,
        confirmText = L:G("Are you sure you want to delete this category?"),
        order = 3,
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
              categories:CreateCategory(value)
            end,
          }
        }
      }
    },
  }

  for category, _ in pairs(DB:GetAllItemCategories()) do
    options.args[category] = config:CreateCustomCategoryConfig(category)
  end
  return options
end