<div align="center" style="text-align:center">

# BetterBags
[![CurseForge BetterBags](https://img.shields.io/badge/CurseForge-BetterBags-F16436.svg?style=flat)](https://www.curseforge.com/wow/addons/better-bags)
[![Discord BetterBags](https://img.shields.io/badge/Discord-BetterBags-5865F2.svg?style=flat)](https://discord.gg/a6DQuK8hV7)
[![Package and release](https://github.com/Cidan/BetterBags/actions/workflows/release.yml/badge.svg)](https://github.com/Cidan/BetterBags/actions/workflows/release.yml)
[![Wago BetterBags](https://img.shields.io/badge/Wago-BetterBags-C1272D.svg?style=flat)](https://addons.wago.io/addons/betterbags/versions?stability=stable)


<img src="https://i.imgur.com/AyITAAV.png" alt="BetterBags Logo">

BetterBags is a bag replacement addon for World of Warcraft, inspired by AdiBags.  
It has a fresh, clean look, updated to the 2024 World of Warcraft art style.

It currently does not include all the features of AdiBags, but will slowly incorporate more and more changes over time.

BetterBags currently supports the following versions of World of Warcraft:  
Retail (including WoW: Remix and The War Within Pre-Patch)  
Classic (Era, Cataclysm Classic, SoD, etc.)  
The War Within Beta
</div>

# Screenshots

<table>
	<tr>
		<td align="middle">
			<a href="https://i.imgur.com/3gYANZp.png" target="_blank"><img src="https://i.imgur.com/3gYANZp.png" alt="The Retail main player bag view with multiple custom categories."></a></td>
		</td>
		<td align="middle">
			<a href="https://i.imgur.com/JFkb968.png" target="_blank"><img src="https://i.imgur.com/JFkb968.png" alt="Currency selection in Retail."></a></td>
		</td>
	</tr>
	<tr>
		<td align="middle">
			The Retail main player bag view with multiple custom categories.
		</td>
		<td align="middle">
			Currency selection in Retail.
		</td>
	</tr>
	<tr>
		<td align="middle">
			<a href="https://i.imgur.com/vJmB95P.png" target="_blank"><img src="https://i.imgur.com/vJmB95P.png" alt="Configure Categories in Retail, allows you to pin and enable (highlighted) and disable a category."></a></td>
		</td>
		<td align="middle">	
			<a href="https://i.imgur.com/COhpLdo.png" target="_blank"><img src="https://i.imgur.com/COhpLdo.png" alt="Extensive View options that can be fine-tuned by the user."></a></td>
		</td>
	</tr>
	<tr>
		<td align="middle">
			Configure Categories in Retail, allows you to pin and enable (highlighted) and disable a category.
		</td>
		<td align="middle">
			Extensive View options that can be fine-tuned by the user.
		</td>
	</tr>
</table>

# Summary
- Three distinct bag and bank views: One Bag, Section Grid, List.
- Support for bags, bank, reagent bank, and Warband bank.
- Customizable categories that hold items with multiple sorting options that can be pinned and toggled.
- Items within categories have multiple sorting and stacking options (stack all, stack non-stackable, don't stack different transmogs).
- Robust plugin system allows for custom categories, configurations for user fine-tuning and even localization.
- Powerful recent items support with customizable duration (mark all new items as recent, flash all recent items).
- Comprehensive Search that allows you to find an item most properties of an item (`Type`, `Subtype`, `iLvl`, and many more).
- Integration support for [Pawn](https://www.curseforge.com/wow/addons/pawn) (upgrade arrows) and [Simple Item Levels](https://www.curseforge.com/wow/addons/simple-item-level) (item level coloring).

More additions are being added all the time.
# Features

## Three Bag & Bank Views
BetterBags offers its users three powerful and distinctly different bag views, which also carry over to the bank.  

### One Bag
A simple and clean one bag window that holds all your items.

<div align="center" style="text-align:center">
<img src="https://i.imgur.com/Gu5a3x9.png" alt="One Bag View in Retail.">

*One Bag View in Retail.*
</div>

### Section Grid
This view sorts your inventory into their own visually distinct categories, allowing you to categorize items at a basic level that is easier for humans to understand by grouping like items together. 

The Section Grid offers:
- Customizable columns and number of items per row.
- Categories can be sorted either alphabetically (top to bottom), size descending, or size ascending.
- Categories can be pinned to the top and enabled or disabled at will.
- Items within these categories can be sorted alphabetically and then by quality (or vice versa).
- Multiple stacking options for fine-tuning your own experience.

<div align="center" style="text-align:center">
<img src="https://i.imgur.com/JLlOHxR.png" alt="Section Grid View in Retail.">

*Section Grid View in Retail.*
</div>

### List View
The List view provides a simple scrolling list with items sorted into the same distinct categories as the Section Grid view.

<div align="center" style="text-align:center">
<img src="https://i.imgur.com/Q8NbPwp.png" alt="List View in Retail.">  

*List View in Retail.*
</div>

## Bank
### Bank Tabs
BetterBags displays the different types of bank as tabs along the bottom of the bank window. It also includes the option to purchase the Reagent Bank and any available Warband Bank tabs.  
Tabs include:
- Bank (Showing all base bank slots as well as bank bags).
- Reagent Bank
- Warband Bank Tabs 1-5 (Called `Warbank Tab` in BetterBags)

<div align="center" style="text-align:center">
<img src="https://i.imgur.com/sxbCWNT.png" alt="Bank Tabs in Retail.">  

*Bank Tabs in Retail.*
</div>

### Bank Bags
To purchase bank bag slots, turn on `Show Bags` and click on any red bag slot.

<div align="center" style="text-align:center">
<img src="https://i.imgur.com/UTl2bDg.png" alt="Purchasing Bank Bag Slots in Retail.">  

*Purchasing Bank Bag Slots in Retail.*
</div>

## Plugin System
BetterBags has a robust plugin system that allows developers to write custom categories.

Plugins have the following options:
- Custom Category API, to create new categories through the plugin.
- Config Module API, allowing plugin authors to let users fine-tune their own experience.
- Localization module, which allows the plugin author to localize their text.

<div align="center" style="text-align:center">
<img src="https://i.imgur.com/B6KTWAJ.png" alt="Plugin System (BetterBags - Appearances) in Retail">

*Plugin System (<a href="https://www.curseforge.com/wow/addons/betterbags-appearances">BetterBags - Appearances</a>) in Retail.*
</div>

## Recent Items
BetterBags places items that have been flagged as new by the WoW client in a special category at the top of your bag so that you can quickly find these looted items.  
**Note: To clear recent items manually, right-click the bag icon. On Cataclysm and Classic, you must install the [SortBags Addon](https://www.curseforge.com/wow/addons/sortbags) to manually clear recent items.**

These can be further fine-tuned by:
- Setting a custom duration before they are sorted into their categories.
- Marking **all** items as recent (bank --> bag transfer, opening containers, etc.).
- Flashing new items in the stack to help the user find updated stacks more quickly.

<div align="center" style="text-align:center">
<img src="https://i.imgur.com/svPb2eT.gif" alt="Recent Items in Retail">

*Recent Items in Retail.*
</div>

## Search
BetterBags offers a comprehensive Search option that can be toggled with a keybinding (`BetterBags > Search Bags`).

By default searches are done in a prefix style, meaning the things you are searching for must start with what you type. To support full-text searching of each field, use the `%=` operator. If you do not specify a search index, search will default to searching in all of `name`, `type`, `subtype`, `category`, and `equipmentLocation`.  
Search allows you to find items by (based on the item below):

<div align="center" style="text-align:center">
<img src="https://i.imgur.com/m7CTReP.png" alt="Example Item in Retail.">

*Example Item in Retail.*
</div>

### Strings
- `name` (name = Silent Tormentor's Hood) The name of the item; the first line in the tooltip.
- `type` (type = Armor) The type of the item. Some examples include Armor, Weapon, Consumable, and Reagent.
- `subtype` (subtype = Leather) The subtype of the item. Some examples include Leather, Potion, Bag, and Bows. See the [Wiki](https://warcraft.wiki.gg/wiki/ItemType) for more information regarding type and subtype.
- `category` (category = Head) The category that the item is sorted into in BetterBags.
- `equipmentLocation` or `slot` (slot = Head) The item slot that the gear is for. Examples include Head, Legs, Main-Hand, and Finger.
- `expansion` (expansion = Dragonflight) The expansion that the item is originally from. Shorthands are: Classic, BC, WotLK, Cata, MoP, WoD, Legion, BfA, SL, DF, TWW.
- `equipmentSet` (None in the example) The equipment set(s) that a piece of gear is part of.

### Numbers
- `level` or `ilvl` (ilvl = 506) The item level of the item. Non-gear items have item levels as well, but they are not shown to the user.
- `rarity` (rarity = epic or rarity = 4) The rarity of the item. Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5.
- `id` (id = 207133) The internal itemID of the item. A number uniquely identifying the item. Specific ItemIDs can be found in the url on the item's WoWHead page.
- `stackCount` (stackCount = 1) The number of items in the stack for the item.
- `class` (class = 4) The numeric representation of itemType.
- `subclass` (subclass = 2) The numeric representation of itemSubtype. See the [Wiki](https://warcraft.wiki.gg/wiki/ItemType) for more information regarding class and subclass.
- `bagid` (bagid = 3) The location of the bag containing the item. BagID is 0 for the main backpack, 1-4 for the bags, 5 for a reagent bag (Retail only), -1 for the main bank window, 6-12 for bank bags, -3 for the reagent bank, -2 for the keyring (Classic only), and 13-17 for warbank tabs.
- `slotid` (slotid = 6) The slot that the item is in, in the bag that contains it. Numbered from 1 to N for each bagID, where N is the size of the container.

### Booleans
- `reagent` (reagent = false) Is the item classified as a reagent?
- `bound` (bound = true) Is the item bound to the character?
- `quest` (quest = false) Is the item for a non-active quest?
- `activeQuest` (activeQuest = false) Is the item for an active quest?

### Logical Operators
- `AND` (slot = Legs AND ilvl > 500 \[This will match leg pieces that are also greater than 500 ilvl.\]) The intersection of two terms. Items must match both sides of the AND.
- `OR` (slot = Legs OR ilvl > 500 \[This will match items that are leg pieces or are greater than 500 ilvl.\] The union of two terms. Items can match either or both sides of the OR.
- `NOT` (NOT slot = Legs \[This will match any item that cannot be equipped in the leg slot.\] The complement of a term. Items must not match the NOT.
- `(` and `)` To group search terms.
- `=` (type = Armor, ilvl = 506) Items with a value equal to the text or number on the right side. This will find any items starting with the value.
- `%=` (slot %= Hand \[This will match any gear pieces that are slotted into any slot with `Hand` in the name. eg. Hands, Main Hand, Offhand\]) Items with the value in the full text of the field(s).
- `"` or `'` (slot = "Main Hand") To search for a multi-word string.

### Comparison Operators
**Note: These only work on numerical fields. Rarity names can be used with these operators.**
- `>` Items with a value greater than the number on the right side.
- `<` Items with a value less than the number on the right side.
- `>=` Items with a value greater than or equal to the number on the right side.
- `<=` Items with a value less than or equal to the number on the right side.

<div align="center" style="text-align:center">
<img src="https://i.imgur.com/dKNAizb.png" alt="Armor Type Search in Retail.">

*Armor Type Search in Retail.*
</div>

BetterBags also allows you to turn on a search bar in the header of the bag instead of the floating search box.

<div align="center" style="text-align:center">
<img src="https://i.imgur.com/piOPl1B.png" alt="In-Bag Search Bar in Retail.">

*In-Bag Search Bar in Retail.*
</div>

## Themes
BetterBags offers a few built-in themes and an API to allow addon authors to create their own themes.  
BetterBags will detect if you have ElvUI or GW2 UI installed and offer an addon specific theme.

<table>
	<tr>
		<td align="middle">
			<a href="https://i.imgur.com/wf62OjY.png" target="_blank"><img src="https://i.imgur.com/wf62OjY.png" alt="Simple Dark Theme in Retail."></a></td>
		</td>
		<td align="middle">
			<a href="https://i.imgur.com/AYL78rY.png" target="_blank"><img src="https://i.imgur.com/AYL78rY.png" alt="GW2 UI Theme in Retail."></a></td>
		</td>
	</tr>
	<tr>
		<td align="middle">
			Simple Dark Theme in Retail.
		</td>
		<td align="middle">
			GW2 UI Theme in Retail.
		</td>
	</tr>
</table>

# Upcoming Updates
BetterBags is constantly getting new features and updates.  
Github hosts both our [Progress Board](https://github.com/users/Cidan/projects/2) and means to [report bugs and request new features](https://github.com/Cidan/BetterBags/issues/new/choose).

The following features are under active development:
- Moving all items in a category by clicking on the category name.

These features are planned for the long term:
- Bag anchors.
- Reagent bag markers for items in the reagent bag.
- Faster/smoother item updates.
- And much more!