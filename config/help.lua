local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Config: AceModule
local config = addon:GetModule('Config')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@return AceConfig.OptionsTable
function config:GenerateHelp()
  ---@type AceConfig.OptionsTable
  local options = {
    type = "group",
    name = L:G("Help"),
    args = {
      mainHelp = {
        type = "group",
        name = L:G("Help"),
        inline = true,
        order = 1,
        args = {
          text = {
            type = "description",
            name = L:G("Welcome to Better Bags! Please select a help item from the left menu for FAQ's and other information."),
            order = 1,
          }
        }
      }
    }
  }
  for _, helpItem in pairs(self.helpText) do
    if not options.args[helpItem.group] then
      options.args[helpItem.group] = {
        type = "group",
        name = helpItem.group,
        order = 1,
        args = {}
      }
    end
    options.args[helpItem.group].args[helpItem.title] = {
      type = "group",
      name = helpItem.title,
      order = 1,
      inline = true,
      args = {
        text = {
          type = "description",
          name = helpItem.text,
          order = 1,
        }
      }
    }
  end
  return options
end

---@param helpItem HelpText
function config:AddHelp(helpItem)
  table.insert(self.helpText, helpItem)
end

function config:CreateAllHelp()
  self:AddHelp({
    group = L:G("Custom Categories"),
    title = L:G("Why are some of my items not showing up in my custom categories?"),
    text = L:G("Items can only be in one category at a time. If you have a category that is missing items, it is likely that the items in that category are already in another category.")
  })
  self:AddHelp({
    group = L:G("Custom Categories"),
    title = L:G("Why does a custom category reappear after I delete it?"),
    text = L:G("If you delete a custom category that was created by another addon/plugin, it will reappear the next time you log in/reload. To permanently delete a custom category created by a plugin/another addon, you must disable the addon creating the category and then delete the category in the UI.")
  })
  self:AddHelp({
    group = L:G("Custom Categories"),
    title = L:G("How do I delete an item from a custom category?"),
    text = L:G("When viewing a custom category configuration, you can right click on an item to open it's menu and select 'delete' to delete it from the category.")
  })
 self:AddHelp({
  group = L:G("Search"),
  title = L:G("How do I search for items?"),
  text = L:G([[
    You can bind a key to open the search bar in the World of Warcraft keybindings menu. You can also open the search bar by shift clicking on the bag button at the top of the bag frame.
    Once the search bar is open, you can type in the name of an item to search for it.
    The BetterBags search engine is extremly comprehensive and supports many different search operators and grouping.
    You can search for items by a number of fields, such as name, type, subtype, expansion, and more, or combine multiple fields to create complex searches.

    Logical Operators include:
    - `AND` to combine multiple search terms (e.g. `axe AND sword`)
    - `OR` to search for items that match any of the search terms (e.g. `axe OR sword`)
    - `NOT` to exclude items that match a search term (e.g. `NOT axe`)
    - `(` and `)` to group search terms (e.g. `(axe OR sword) AND epic`)

    Comparison Operators include:
    - `>` to search for items with a value greater than a number (e.g. `level > 10`)
    - `<` to search for items with a value less than a number (e.g. `level < 10`)
    - `=` to search for items with a value equal to a number or text (e.g. `level = 10 or name = axe`)
    - `>=` to search for items with a value greater than or equal to a number (e.g. `level >= 10`)
    - `<=` to search for items with a value less than or equal to a number (e.g. `level <= 10`)

    The following fields are supported:
    - `name` to search for items by name (e.g. `name = axe`)
    - `type` to search for items by type (e.g. `type = weapon`)
    - `subtype` to search for items by subtype (e.g. `subtype = axe`)
    - `quality` to search for items by quality (e.g. `quality = epic`)
    - `equipmentLocation` to search for items by equipment location (e.g. `equipmentLocation = head`)
    - `expansion` to search for items by expansion (e.g. `expansion = classic`)
    - `level` to search for items by level (e.g. `level > 10`)
    - `rarity` to search for items by rarity (e.g. `rarity = rare`)
    - `id` to search for items by id (e.g. `id = 12345`)
    - `stackCount` to search for items by stack count (e.g. `stackCount > 10`)
    - `class` to search for items by classID (e.g. `class = 10`)
    - `subclass` to search for items by subclassID (e.g. `subclass = 10`)
    - `bagid` to search for items by bagID (e.g. `bagid = 0`)
    - `slotid` to search for items by slotID (e.g. `slotid = 0`)
    - `reagent` to search for items by reagent (e.g. `reagent = true`)
    - `bound` to search for items by bound status (e.g. `bound = true`)
    - `quest` to search for items by quest status (e.g. `quest = true`)
    - `activeQuest` to search for items by active quest status (e.g. `activeQuest = true`)
  
    For rarity, you can use numerical comparison operators on rarity names, for example:
    - `rarity = poor`
    - `rarity > common`
    - `rarity >= uncommon`
    - ...etc
    
    For expansions, you can use the following expansions shortcuts (e.g. `exp:classic`):
    - `classic`
    - `tbc`
    - `wotlk`
    - `cata`
    - `mop`
    - `wod`
    - `legion`
    - `bfa`
    - `shadowlands`
    - `dragonflight`
  ]])
 })
end
