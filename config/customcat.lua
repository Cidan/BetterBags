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

---@class Context: AceModule
local context = addon:GetModule('Context')

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
          local ctx = context:New('DeleteCategory_Menu')
          categories:DeleteCategory(ctx, category)
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
          afterHelp = {
            type = "description",
            name = L:G("After creating a category, you can use the side menu via the bag menu, Configure Categories, to add or remove items"),
            order = 2,
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
              local ctx = context:New('CreateCategory_Menu')
              categories:CreateCategory(ctx, {
                name = value,
                save = true,
                enabled = {
                  [const.BAG_KIND.BACKPACK] = true,
                  [const.BAG_KIND.BANK] = true,
                },
                itemList = {},
                readOnly = false,
              })
            end,
          }
        }
      }
    },
  }
  return options
end