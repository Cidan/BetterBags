local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Database: AceModule
local DB = addon:GetModule('Database')

---@class Config: AceModule
local config = addon:GetModule('Config')

---@param kind BagKind
---@return AceConfig.OptionsTable
function config:GetBagOptions(kind)
  ---@type AceConfig.OptionsTable
  local options = {
    type = "group",
    name = L:G("Bags"),
    args = {
      categories = {
        type = "multiselect",
        name = L:G("Categories"),
        desc = L:G("Select which categories to show in this bag. If an option is checked, items that belong to the checked category will be put into a section for that category."),
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
      }
    }
  }
  return options
end