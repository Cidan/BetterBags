<div align="center" style="text-align:center">

# BetterBags
[![CurseForge BetterBags](https://img.shields.io/badge/CurseForge-BetterBags-F16436.svg?style=flat)](https://www.curseforge.com/wow/addons/better-bags)
[![Discord BetterBags](https://img.shields.io/badge/Discord-BetterBags-5865F2.svg?style=flat)](https://discord.gg/a6DQuK8hV7)
[![Package and release](https://github.com/Cidan/BetterBags/actions/workflows/release.yml/badge.svg)](https://github.com/Cidan/BetterBags/actions/workflows/release.yml)
[![Wago BetterBags](https://img.shields.io/badge/Wago-BetterBags-C1272D.svg?style=flat)](https://addons.wago.io/addons/betterbags/versions?stability=stable)


<img src="https://i.imgur.com/AyITAAV.png" alt="BetterBags Logo">

BetterBags is a bag replacement addon for World of Warcraft, inspired by AdiBags.  
It has a fresh, clean look, updated to the 2024 World of Warcraft art style.

It currently includes most of the features of AdiBags and is being worked on daily.  
One of the last major features currently missing is user selectable themes.  
If you have any feedback, please let us know in the [Discord](https://discord.gg/a6DQuK8hV7).

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
- Items are organized into categories and displayed in a Section Grid.
- Support for bags, bank, reagent bank, and Warband bank.
- The bag and bank can be anchored to a location and grow in specified directions.
- Dynamic number of columns. (TODO)
- Customizable categories that hold items with multiple sorting options that can be pinned and toggled.
- Search based categories where the items within the category are defined by a search function.
- Items within categories have multiple sorting and stacking options (stack all, stack non-stackable, don't stack different transmogs).
- Powerful recent items support with customizable duration (mark all new items as recent, flash all recent items).
- Right-click category header to move or vendor all items currently in the category.
- Comprehensive Search that allows you to find an item most properties of an item (`Type`, `Subtype`, `iLvl`, and many more).
- Multiple built-in themes with plugin support for the creation of more themes.
- Robust plugin system allows for custom categories, configurations for user fine-tuning and even localization.
- Integration support for [Pawn](https://www.curseforge.com/wow/addons/pawn) (upgrade arrows) and [Simple Item Levels](https://www.curseforge.com/wow/addons/simple-item-level) (item level coloring).

More additions are being added all the time.

# Features

## Bag & Bank View
BetterBags offers its users a powerful category-based view, which also carry over to the bank.  

### Section Grid
This view sorts your inventory into their own visually distinct categories, allowing you to categorize items at a basic level that is easier for humans to understand by grouping like items together. 

The Section Grid offers:
- Customizable columns and number of items per row.
- Categories can be sorted either alphabetically (top to bottom), size descending, or size ascending.
- Categories can be pinned to the top, enabled, disabled or hidden at will.
- Items within these categories can be sorted alphabetically and then by quality (or vice versa).
- Multiple stacking options for fine-tuning your own experience.

<div align="center" style="text-align:center">
<img src="https://i.imgur.com/JLlOHxR.png" alt="Section Grid View in Retail.">

*Section Grid View in Retail.*
</div>

### Show Bags
This temporary view allows you to see your bags and the items within them how they currently are. It also allows you to swap out which bags are equipped for both the backpack and the bank.

<div align="center" style="text-align:center">
<img src="https://i.imgur.com/4YAG0Rm.png" alt="Show Bags in Retail.">

*Show Bags in Retail.*
</div>

### Bag Anchor
By default, the bag and bank will grow from the bottom-left corner. Extending both up and right depending on the number of items per row and number of columns.
A specific anchor can be turned on by left-clicking the bag icon in the top-left corner of the bag and bank. It will allow you to drag the anchor to a specific pixel and grow the bag from whichever corner the anchor is in. Selecting `Enable` will turn on the anchor. Selecting `Show` will allow you to manipulate the anchor and choose the location.

<div align="center" style="text-align:center">
<img src="https://i.imgur.com/ZiyLfvF.png" alt="Bag Anchor in Retail.">

*Bag Anchor in Retail.*
</div>

### Free Spaces
The default view for free spaces is to have them in 1 icon with a number showing how many free spaces you have in each type of container equipped. Regular bag slots are on the right and special containers (like Reagent Bags) are on the left.
If you would rather see all of the spaces with their own icon, there is a setting in the config window to display them in that manner. When free spaces are all shown, non-regular bag containers will have a border around them to denote what type of container they belong to (Green for Reagent Bag on Retail).

<table>
	<tr>
		<td align="middle">
			<a href="https://i.imgur.com/6nMUB3s.png" target="_blank"><img src="https://i.imgur.com/6nMUB3s.png" alt="Free Space Icons in Retail."></a></td>
		</td>
		<td align="middle">
			<a href="https://i.imgur.com/NdUYAaj.pngg" target="_blank"><img src="https://i.imgur.com/NdUYAaj.png" alt="Show All Free Spaces in Retail."></a></td>
		</td>
	</tr>
	<tr>
		<td align="middle">
			Free Space Icons in Retail.
		</td>
		<td align="middle">
			Show All Free Spaces in Retail.
		</td>
	</tr>
</table>

### Show Currencies
Currencies can be tracked at the bottom of the bag window. Up to 7 currencies can be shown at a time and tracking them is as simple as clicking on the currencies in the `Show Currencies` side window. Any currency that is highlighted is currently tracked. If you attempt to track more than 7 currencies, only the first 7 in the list will be shown at the bottom of the bag.

<div align="center" style="text-align:center">
<img src="https://i.imgur.com/R4neqb2.png" alt="Currencies Side Window in Retail.">  

*Currencies Side Window in Retail.*
</div>

<div align="center" style="text-align:center">
<img src="https://i.imgur.com/2HeRBue.png" alt="Tracked Currencies in Retail.">  

*Tracked Currencies in Retail.*
</div>

### Configure Categories
Categories have a few ways in which they can be configured. All categories can be pinned or hidden. Non-dynamic categories can also be enabled or disabled. Custom categories can be deleted. Hovering over a category will bring up a tooltip that describes the actions that can be taken for that category.  
- Pinning categories (Drag or Shift Left Click) will display them in the listed order at the top of the bags. Any categories that are not pinned will be automatically ordered based on the `Section Sorting` option chosen in config.
- Hiding categories (Right Click) will keep the items sorted into the category, but the category and all items within it will not be displayed in your bags.
- Enabling or Disabling a category (Left Click) will stop items from being sorted into that category and will show as the category name not being high-lighted in the list.
- Deleting a category (Right Click) will permanently delete the category. If a category is created by a plugin, the plugin might create the category again when reloading the game.

<table>
	<tr>
		<td align="middle">
			<a href="https://i.imgur.com/0UwlZst.png" target="_blank"><img src="https://i.imgur.com/0UwlZst.png" alt="The Configure Categories Side Window in Retail."></a></td>
		</td>
		<td align="middle">
			<a href="https://i.imgur.com/Mr2bmzO.png" target="_blank"><img src="https://i.imgur.com/Mr2bmzO.png" alt="Category Options in Configure Categories in Retail."></a></td>
		</td>
	</tr>
	<tr>
		<td align="middle">
			The Configure Categories Side Window in Retail.
		</td>
		<td align="middle">
			Category Options in Configure Categories in Retail.
		</td>
	</tr>
	<tr>
		<td align="middle">
			<a href="https://i.imgur.com/vJmB95P.png" target="_blank"><img src="https://i.imgur.com/vJmB95P.png" alt="Configure Custom Categories in Retail."></a></td>
		</td>
		<td align="middle">	
			<a href="https://i.imgur.com/sR9V9Cb.png" target="_blank"><img src="https://i.imgur.com/sR9V9Cb.png" alt="Configure Search Category in Retail."></a></td>
		</td>
	</tr>
	<tr>
		<td align="middle">
			Configure Custom Categories in Retail.
		</td>
		<td align="middle">
			Configure Search Category in Retail.
		</td>
	</tr>
</table>

## Bank
### Bank Tabs
BetterBags displays the different types of bank as tabs along the bottom of the bank window. It also includes the option to purchase the Reagent Bank and any available Warband Bank tabs.  
Tabs include:
- Bank (Showing all base bank slots as well as bank bags).
- Reagent Bank.
- Warband Bank Tabs 1-5 (Called `Warbank Tab` in BetterBags).

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

### Warbank Tabs
To purchase Warbank tabs, click on the `Purchase Warbank Tab` button, then click purchase on the Blizzard pop-up.  
Warbank tabs can be renamed and certain item types can be assigned to them by right-clicking on the tab at the bottom of the bank. This will bring up the Blizzard prompt to make any changes. Depositing items into the Warbank tabs will deposit them using Blizzard's rules for depositting items into the Warbank.

<div align="center" style="text-align:center">
<img src="https://i.imgur.com/98Hgf2I.png" alt="Editing Warbank Tab in Retail.">  

*Editing Warbank Tab in Retail.*
</div>

To deposit or withdraw gold from the Warbank, hover over the gold amount at the bottom of the bank/warbank window and left or right click. This works from any tab in the bank window.

<div align="center" style="text-align:center">
<img src="https://i.imgur.com/LQmRp1m.png" alt="Manipulating Warbank Money in Retail.">  

*Manipulating Warbank Money in Retail.*
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

To disable recent items, uncheck the `Recent Items` category in the config window and set the `New Item Duration` to 0. After hovering over the item and changing anything in the bags, it will stop flashing.

## Move Categories
Right-clicking on a category header in your bank or bags will move the entire contents of the category to whatever other window you currently have open.
Supported windows include bags, all bank tabs, the mailbox, the trade window, and vendor windows.

<div align="center" style="text-align:center">
<img src="https://i.imgur.com/9ahFi16.gif" alt="Move Category in Retail">

*Move Cateogry in Retail.*
</div>

## Search
BetterBags offers a comprehensive Search option that can be toggled with a keybinding (`BetterBags > Search Bags`).

If you do not specify a search index, search will default to searching in all of `name`, `type`, `subtype`, `category`, and `equipmentLocation` using full text searches. By using the `=` operator, searches will be done in a prefix style, meaning the things you are searching for must start with what you type. To support full-text searching of each field, use the `%=` operator.  
Search allows you to find items by the following indices (based on the item below):

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
- `expansion` or `exp` (expansion = DF) The expansion that the item is originally from. Shorthands are: Classic, BC, WotLK, Cata, MoP, WoD, Legion, BfA, SL, DF, TWW.
- `equipmentSet` (None in the example) The equipment set(s) that a piece of gear is part of.

### Numbers
- `level` or `ilvl` (ilvl = 506) The item level of the item. Non-gear items have item levels as well, but they are not shown to the user.
- `rarity` (rarity = epic or rarity = 4) The rarity of the item. Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5.
- `id` (id = 207133) The internal itemID of the item. A number uniquely identifying the item. Specific ItemIDs can be found in the url on the item's WoWHead page.
- `stackCount` or `count` (stackCount = 1) The number of items in the stack for the item.
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
- `OR` (slot = Legs OR ilvl > 500 \[This will match items that are leg pieces or are greater than 500 ilvl.\]) The union of two terms. Items can match either or both sides of the OR.
- `NOT` (NOT slot = Legs \[This will match any item that cannot be equipped in the leg slot.\]) The complement of a term. Items must not match the NOT.
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
<img src="https://i.imgur.com/H2jgRO8.png" alt="Complex Search in Retail.">

*Complex Search in Retail.*
</div>

BetterBags also allows you to turn on a search bar near the top of the bag instead of the floating search box.

<div align="center" style="text-align:center">
<img src="https://i.imgur.com/S0W5Gmw.png" alt="In-Bag Search Bar in Retail.">

*In-Bag Search Bar in Retail.*
</div>

## Custom Categories
BetterBags allows items to be grouped into custom categories. These categories can be manually populated by the user, created by plugins, or created from a search.

### Manual Custom Categories
To manually create custom categories that you can add items to, left-click on an item, then hover over the bag button in the top-left of the bag, and left-click again. You can also left-click and drag the item to the bag button, then drop it. Enter in a name for the new category and your item will be added to it. To add new items into categories, you can do the same procedure with any category name, but hold shift while dropping the item.

<table>
	<tr>
		<td align="middle">
			<a href="https://i.imgur.com/i5Z9hdu.png" target="_blank"><img src="https://i.imgur.com/i5Z9hdu.png" alt="Create a New Category in Retail."></a></td>
		</td>
		<td align="middle">
			<a href="https://i.imgur.com/vAa6NkE.png" target="_blank"><img src="https://i.imgur.com/vAa6NkE.png" alt="Name a New Category in Retail."></a></td>
		</td>
		<td align="middle">
			<a href="https://i.imgur.com/mRnottG.png" target="_blank"><img src="https://i.imgur.com/mRnottG.png" alt="Add an Item to a Category in Retail."></a></td>
		</td>
	</tr>
	<tr>
		<td align="middle">
			Create a New Category in Retail.
		</td>
		<td align="middle">
			Name a New Category in Retail.
		</td>
		<td align="middle">
			Add an Item to a Category in Retail.
		</td>
	</tr>
</table>

### Search-based Custom Categories
Any search you complete has the option to be turned into a custom category. These categories will dynamically update as new items are added to the bag that match the search criteria.  
To create a Search Category, type in a search, then press `Enter`. Fill out the required information in the dialogue box and save.
- Category Name (string) is what the new category will be named.
- Search Query (string) is the search that will be run to determine which items will be in the category. Any search options (described above) will work in the query.
- Priority (number) is the order in which search categories will "steal" items. Items can only be in 1 category at a time and higher priority will get items first.

<table>
	<tr>
		<td align="middle">
			<a href="https://i.imgur.com/wOUmfRi.png" target="_blank"><img src="https://i.imgur.com/wOUmfRi.png" alt="Creating a Search Category in Retail."></a></td>
		</td>
		<td align="middle">
			<a href="https://i.imgur.com/AqFBVrp.png" target="_blank"><img src="https://i.imgur.com/AqFBVrp.png" alt="Configure Search Category in Retail."></a></td>
		</td>
	</tr>
	<tr>
		<td align="middle">
			Creating a Search Category in Retail.
		</td>
		<td align="middle">
			Configure Search Category in Retail.
		</td>
	</tr>
</table>

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

## Plugin System
BetterBags has a robust plugin system that allows developers to write custom categories.

Plugins have the following options:
- Custom Category API, to create new categories through the plugin.
- Config Module API, allowing plugin authors to let users fine-tune their own experience.
- Theme API, to allow plugins to create new themes.
- Localization module, which allows the plugin author to localize their text.

<div align="center" style="text-align:center">
<img src="https://i.imgur.com/B6KTWAJ.png" alt="Plugin System (BetterBags - Appearances) in Retail">

*Plugin System (<a href="https://www.curseforge.com/wow/addons/betterbags-appearances">BetterBags - Appearances</a>) in Retail.*
</div>

# Upcoming Updates
BetterBags is constantly getting new features and updates.  
Github hosts both our [Progress Board](https://github.com/users/Cidan/projects/2) and means to [report bugs and request new features](https://github.com/Cidan/BetterBags/issues/new/choose).

The following features are under active development:
- Searching for BoE/BoA/WuE items.

These features are planned for the long term:
- Dynamic number of columns.
- User customizable themes.
- A new config system using a forms style like the search-based category window.
- Reagent bag markers for items in the reagent bag.
- Faster/smoother item updates.
- And much more!