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

    For a more complete breakdown of the available search terms, please visit the README at https://github.com/Cidan/BetterBags.


    When searching for bare words (eg. "Signet"), the search will match any item that has the word in the entire text of the default indices, which includes `name`, `type`, `subtype`, `category`, `equipmentLocation`, and `binding`.
    When searching in an index (eg. "name = Signet"), using the `=` operator will search in a prefix style, meaning the things you are searching for must start with what you type. To support full-text searching of each field, use the `%=` operator.  

    If you would like to exclude items in gear sets from your searches, the easiest way to do so is add `and not category = "gear:"` to the end of your search. (eg. `slot = finger or slot = neck and not (category = 'gear:')` will highlight all rings and necklaces that are NOT part of a gear set)


Search allows you to find items by the following indices:

Strings:
    - `name` (name = "Tome of Unstable Power") The name of the item.
    - `type` (type = Armor) The type of the item.
    - `subtype` (subtype = Miscellaneous) The subtype of the item.
    - `category` (category = "Gear: MW DPS") The category that the item is sorted
          into in BetterBags.
    - `equipmentLocation` or `slot` (slot = Trinket) The item slot that the gear is for.
    - `expansion` or `exp` (expansion = DF) The expansion that the item is from.
          Values are: Classic, BC, WotLK, Cata, MoP, WoD, Legion, BfA, SL, DF, TWW.
    - `equipmentSet` (equipmentSet = "MW DPS") The equipment set(s) that a piece
          of gear is part of.
    - `guid` (guid = 'item-60-0-4000000CAEA5CBE3') The GUID of the item.
    - `binding` (binding = boe) The text description of the binding type of the item.
          Values include nonbinding, boe, bou, quest, soulbound, refundable,
                warbound, bnet, or wue.
          Note: soulbound and warbound are only available on Retail.

Numbers:
    - `level` or `ilvl` (ilvl = 528) The item level of the item.
    - `rarity` (rarity = epic or rarity = 4) The rarity of the item.
          Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5.
    - `id` (id = 212685) The internal itemID of the item.
    - `stackCount` or `count` (stackCount = 1) The number of items in the stack.
          NOTE: Currently count only takes into account the stack size of the
                "base" stack when using virtual stacks.
    - `class` (class = 4) The numeric representation of itemType.
    - `subclass` (subclass = 0) The numeric representation of itemSubtype.
    - `bagid` (bagid = 2) The location of the bag containing the item.
          BagID is 0 for the main backpack, 1-4 for the bags,
                5 for a reagent bag (Retail only), -1 for the main bank window,
                6-12 for bank bags, -3 for the reagent bank,
                -2 for the keyring (Classic only), and 13-17 for warbank tabs.
    - `slotid` (slotid = 11) The slot that the item is in, in the bag that contains it.
    - `bindtype` (bindtype = 1) The binding type returned by GetItemInfo().
          1 = BoP, 2 = BoE, 3 = BoU, 4 = Quest, 7 = BtA, 8 = BtW, 9 = WuE.

Booleans:
    - `reagent` (reagent = false) Is the item classified as a reagent?
    - `bound` (bound = true) Is the item bound to the character or warband?
    - `isbound` (isbound = true) Is the item bound to the character or account?
    - `quest` (quest = false) Is the item for a non-active quest?
    - `activeQuest` (activeQuest = false) Is the item for an active quest?

Logical Operators:
    - `AND` (slot = Legs AND ilvl > 500) Items must match both sides of the AND.
    - `OR` (slot = Legs OR ilvl > 500) Items can match either or both sides of the OR.
    - `NOT` (NOT slot = Legs) Items must not match the NOT.
    - `(` and `)` To group search terms.
    - `=` (type = Armor, ilvl = 506) Items with a value equal to the right side.
    - `%=` (slot %= Hand) Items with the value in the full text of the field(s).
    - `!=` (expansion != DF) Items with a value not equal to the right side.
    - `"` or `'` (slot = "Main Hand") To search for a multi-word string.

Comparison Operators:
    Note: These only work on numerical fields. Rarity can be used with these.
    - `>` Items with a value greater than the number on the right side.
    - `<` Items with a value less than the number on the right side.
    - `>=` Items with a value greater than or equal to the number on the right side.
    - `<=` Items with a value less than or equal to the number on the right side.
  ]])
 })
end
