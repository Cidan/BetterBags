--[[
  This is an example of how to create a category plugin for BetterBags.
  Your addon must be a loadable addon, and it must have a .toc file,
  and it must have a dependency on BetterBags.
  You do not need to bundle Ace or any other library with your addon, as
  BetterBags will provide them for you.
]]--

-- This will get a handle to the BetterBags addon.
---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon("BetterBags")

-- This will get a handle to the Categories module, which exposes
-- the API for creating categories.
---@class Categories: AceModule
local categories = addon:GetModule('Categories')

-- This will get a handle to the Config module, which exposes
-- the API for creating a configuration entry in the BetterBags config panel.
---@class Config: AceModule
local config = addon:GetModule('Config')

-- This will get a handle to the localization module, which should be
-- used for all text your users will see. For all category names,
-- you should use the L:G() function to get the localized string.
---@class Localization: AceModule
local L = addon:GetModule('Localization')

-- This is the context module, which is required for most API calls.
-- The context module is used to track the state of the addon and it's
-- calls, including a call stack across events, across frames.
---@class Context: AceModule
local context = addon:GetModule('Context')

-- Create a new context.
-- Set the event for the context. This is used for tracking the state of the addon
-- and can be any string you want. It tells the addon where this call originated from
-- even across frames.
local ctx = context:New('MyAddon_Event')

-- Use this API for creating a custom category based on the item's ID. These categories are
-- not persistant, such that if a user disables your addon, the categories will disappear.
categories:AddItemToCategory(ctx, 12345, L:G("My Category"))

-- Use this API to delete all the items in a category. This will not delete the category itself,
-- but will empty it's item list from the persistant store. This is useful if you want to
-- make sure the user's categories are in a known state, i.e. on every load of your plugin,
-- you wipe and then add all the items to the category.
categories:WipeCategory(ctx, L:G("My Category"))

-- This this API to explicitly create a category with the defined parameters. This option
-- replaces the old Create* functions, and is the preferred way to create categories.
categories:CreateCategory(ctx, {
  name = L:G("My Category"), -- The name of the category
  itemList = {[12345] = true}, -- A list of item IDs that should be in this category
  save = true, -- If set, this category will persist between sessions. Optional, default is false.
  searchCategory = { -- If set, this will obviate the itemList and ignore it. Optional.
    query = "type = armor or type = weapon" -- A search query that will be used to populate the category
  },
  note = L:G("Created by Cidan"), -- A free form note for future use. Optional.
  priority = 1, -- The priority of the category. A lower number means it will be displayed first. Optional, and only works for search categories.
})

-- Use this API to register a function that will be called for every item in the player's bags.
-- The function you provide will be given an ItemData table, which contains all properties of an item
-- loaded from the Blizzard API. From here, you can call any custom code you want to analyze the item.
-- Your function must return a string, which is the category name that the item should be placed in.
-- If your function returns nil, the item will not be placed in any category.
-- Results of this function, including nil, are cached, so you do not need to worry about performance
-- after the first scan.
categories:RegisterCategoryFunction("my register function", function (data)
  if data.itemInfo.expacID == LE_EXPANSION_DRAGONFLIGHT then
    if data.itemInfo.itemName == "Some Currency Item" then
      return L:G("Dragonflight Currency")
    end
  end
  return nil
end)