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

---@class Config: AceModule
local config = addon:GetModule('Config')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@return AceConfig.OptionsTable
function config:GetGeneralOptions()
  ---@type AceConfig.OptionsTable
  local options = {
    type = "group",
    name = L:G("General"),
    order = 0,
    args = {
      inBagSearch = {
        type = "toggle",
        width = "full",
        order = 0,
        name = L:G("Enable In-Bag Search"),
        desc = L:G("If enabled, a search bar will appear at the top of your bags."),
        get = function()
          return DB:GetInBagSearch()
        end,
        set = function(_, value)
          DB:SetInBagSearch(value)
          events:SendMessage(context:New('OnClick_InBagSearch'), 'search/SetInFrame', value)
        end,
      },
      categorySell = {
        type = "toggle",
        width = "full",
        order = 1,
        name = L:G("Enable Category Sell"),
        desc = L:G("If enabled, right-clicking a category header at a NPC shop will sell all its contents (limited to 10 stacks to allow buy-backs)."),
        get = function()
          return DB:GetCategorySell()
        end,
        set = function(_, value)
          DB:SetCategorySell(value)
        end,
      },
      newItemTime = {
        type = "range",
        order = 2,
        name = L:G("New Item Duration"),
        desc = L:G("The time, in minutes, to consider an item a new item."),
        min = 0,
        max = 240,
        step = 1,
        bigStep = 5,
        get = function()
          return DB:GetData().profile.newItemTime / 60
        end,
        set = function(_, value)
          DB:GetData().profile.newItemTime = value * 60
        end,
      }
    }
  }
  return options
end
