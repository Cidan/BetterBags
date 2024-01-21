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
        values = {},
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
          name = {
            name = L:G("Name"),
            type = "input",
            width = "full",
            order = 1,
            get = function()
              return ""
            end,
            set = function(_, value)
              --categories:CreateCategory(value)
              --config:Refresh()
            end,
          },
          create = {
            name = L:G("Create"),
            type = "execute",
            width = "half",
            order = 2,
            func = function()
              --categories:CreateCategory()
              --config:Refresh()
            end,
          },
        }
      }
    },
  }

  for category, _ in pairs(DB:GetAllItemCategories()) do
    options.args[category] = config:CreateCustomCategoryConfig(category)
  end
  return options
end