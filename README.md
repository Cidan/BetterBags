<div align="center" style="text-align:center">

# BetterBags
[![Discord BetterBags](https://discordapp.com/api/guilds/1063213796845428876/widget.png?style=banner2)](https://discord.gg/a6DQuK8hV7)

[![CurseForge BetterBags](https://img.shields.io/badge/CurseForge-BetterBags-F16436.svg?style=flat)](https://www.curseforge.com/wow/addons/better-bags)
[![Wago BetterBags](https://img.shields.io/badge/Wago-BetterBags-C1272D.svg?style=flat)](https://addons.wago.io/addons/betterbags/versions?stability=stable)
[![Package and release](https://github.com/Cidan/BetterBags/actions/workflows/release.yml/badge.svg)](https://github.com/Cidan/BetterBags/actions/workflows/release.yml)


<img src="https://i.imgur.com/AyITAAV.png" alt="BetterBags Logo">

BetterBags is a bag replacement addon for World of Warcraft, inspired by AdiBags.  
It has a fresh, clean look, updated to the 2026 World of Warcraft art style.

It currently includes most of the features of AdiBags and is being worked on daily.  
If you have any feedback, please let us know in the [Discord](https://discord.gg/a6DQuK8hV7).

BetterBags currently supports the following versions of World of Warcraft:  
Retail (including Midnight and the various WoW: Remix versions as they come out)  
Classic (Era, MoP Classic, SoD, BC Anniversary, etc.)  
</div>

# Screenshots

<table>
	<tr>
		<td align="middle">
			<a href="https://i.imgur.com/3gYANZp.png" target="_blank"><img src="https://i.imgur.com/3gYANZp.png" alt="The Retail main player bag view with multiple custom categories."></a></td>
		</td>
		<td align="middle">
			<a href="https://i.imgur.com/nSjeaev.png" target="_blank"><img src="https://i.imgur.com/nSjeaev.png" alt="Currency selection in Retail."></a></td>
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
			<a href="https://i.imgur.com/LzdVdH0.png" target="_blank"><img src="https://i.imgur.com/LzdVdH0.png" alt="Configure Categories in Retail, allows you to pin and sort categories."></a></td>
		</td>
		<td align="middle">	
			<a href="https://i.imgur.com/hMHiCDz.png" target="_blank"><img src="https://i.imgur.com/hMHiCDz.png" alt="Extensive View options that can be fine-tuned by the user."></a></td>
		</td>
	</tr>
	<tr>
		<td align="middle">
			Configure Categories in Retail, allows you to pin and sort categories.
		</td>
		<td align="middle">
			Extensive View options that can be fine-tuned by the user.
		</td>
	</tr>
</table>

# Summary
- Items are organized into categories and displayed in a Section Grid.
- Optionally, categories are organized into groups/tabs.
- Support for bags, bank, reagent bank, and Warband bank.
- The bag and bank can be anchored to a location and grow in specified directions.
- Customizable categories that hold items with multiple sorting options that can be pinned and toggled.
- Search based categories where the items within the category are defined by a search function.
- Items within categories have multiple sorting and stacking options (stack all, stack non-stackable, don't stack different transmogs).
- Powerful recent items support with customizable duration (mark all new items as recent, flash all recent items).
- Right-click category header to move or vendor all items currently in the category.
- Comprehensive Search that allows you to find an item most properties of an item (`Type`, `Subtype`, `iLvl`, and many more).
- Multiple built-in themes (Default, Simple Dark, Slate, Dark, Parchment, and ElvUI and GW2 UI themes when those are installed), with a declarative theme API for creating more.
- Bags that size themselves to their items, or windows you resize by dragging their corner (Settings > Resizable Window).
- Profiles to allow easy swapping of layouts and categories between characters.
- Category import and export strings to easily share your categories between friends.
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
- Built-in categories are named after the item's type and, when turned on in the options, its subtype and expansion (for example `Armor - Plate - Classic`). A subtype named like its type is not repeated, so quest items read `Quest` rather than `Quest - Quest`.

<div align="center" style="text-align:center">
<a href="https://i.imgur.com/JLlOHxR.png" target="_blank"><img src="https://i.imgur.com/JLlOHxR.png" alt="Section Grid View in Retail."></a>

*Section Grid View in Retail.*
</div>

### Navigation
Most options and other important information in BetterBags can be reached by left-clicking on the bag button in the top-left corner of the bag (or bank) and bringing up the menu. Hovering over the bag icon will bring up a list of mouse-clicks that can be done for various functions. Some of the important functions in the menu are described in the following sections. Any options not in the menu directly are instead in the options screen (access by choosing `Open Options Screen` in the menu or the slash command `/bb`).

<div align="center" style="text-align:center">
<a href="https://i.imgur.com/jpMjAcP.png" target="_blank"><img src="https://i.imgur.com/jpMjAcP.png" alt="Menu in Retail."></a>

*Menu in Retail.*
</div>

### Show Bags
This temporary view allows you to see your bags and the items within them how they currently are. It also allows you to swap out which bags are equipped for both the backpack and the bank.

<div align="center" style="text-align:center">
<a href="https://i.imgur.com/4YAG0Rm.png" target="_blank"><img src="https://i.imgur.com/4YAG0Rm.png" alt="Show Bags in Retail."></a>

*Show Bags in Retail.*
</div>

### Dropping Items Into Your Bags
You can drop an item anywhere on the bag or bank window, not just on an empty slot: drag it there and let go, or pick it up and left-click the window. This is the quickest way to unequip gear, by dragging it from your character panel onto your bags.
- The item goes into the first free slot of a bag made for it (a profession bag of its kind, the reagent bag for crafting reagents, the keyring for keys on Classic Era and WoW: Forever), otherwise into the first ordinary bag, starting with your backpack. It is never put in a special bag it doesn't fit.
- Dropping on the bank window stores the item in the bank type you are looking at (your character bank or the Warband bank), starting with the tab you have selected.
- An item you picked up from the same window goes back where it came from.
- If there is no room, you get the usual "Inventory is full." message and the item stays on your cursor.
- Dropping on an item swaps with it as always, and holding Shift while dropping on a category name still adds the item to that category.
- Items dragged from a vendor (buying) are not placed this way; drop them on a slot.
- A refundable item dropped on the Warband bank stays on your cursor, because putting it in the Warband bank ends its refund. Drop it on a Warband bank slot if that is what you want.

### Bag Anchor
By default, the bag and bank will grow from the bottom-left corner. Extending both up and right depending on the number of items per row and number of columns.
A specific anchor can be turned on by left-clicking the bag icon in the top-left corner of the bag and bank. It will allow you to drag the anchor to a specific pixel and grow the bag from whichever corner the anchor is in. Selecting `Enable` will turn on the anchor. Selecting `Show` will allow you to manipulate the anchor and choose the location. `Manual Anchor` will allow you to choose which corner you want the bag to grow from. If you leave it on `Automatic`, the bag will grow away from the closest corner.  
You can also enable and show the anchors with the slash command `/bbanchor`. To hide the anchor (but keep it enabled), simply right-click anywhere in the blue anchor.

<div align="center" style="text-align:center">
<a href="https://i.imgur.com/USio26V.png" target="_blank"><img src="https://i.imgur.com/USio26V.png" alt="Bag Anchor in Retail."></a>

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

### Extra Glowy Item Buttons
If you would like more glow on the action buttons (more like what AdiBags had), there is a setting to turn on Extra Glowy Action Buttons in the options screen.

<div align="center" style="text-align:center">
	<table>
		<tr>
			<td align="middle">
				<a href="https://i.imgur.com/JaWJ90x.png" target="_blank"><img src="https://i.imgur.com/JaWJ90x.png" alt="Normal Icons in Retail."></a></td>
			</td>
			<td align="middle">
				<a href="https://i.imgur.com/abtd1fn.pngg" target="_blank"><img src="https://i.imgur.com/abtd1fn.png" alt="Extra Glowy Icons in Retail."></a></td>
			</td>
		</tr>
		<tr>
			<td align="middle">
				Normal Icons in Retail.
			</td>
			<td align="middle">
				Extra Glowy Icons in Retail.
			</td>
		</tr>
	</table>
</div>

### Item Level Upgrade Arrow
Equipment in your bags that is an item level upgrade compared to the gear you are currently wearing will have a green upgrade arrow in the top corner of the item in your bags. This lets you easily see which pieces of gear in your bags might be an upgrade, such as when you're leveling and your item level is rapidly increasing.

Gear for an empty equipment slot counts as an upgrade too. An item gets no arrow if your character can't use it, isn't high enough level for it, it isn't your armor type, or it has a primary stat (Strength, Agility, Intellect) that your current specialization doesn't use. While you hold a two-handed weapon, one-handers, shields and off-hands get no arrow, and while you hold a one-hander, two-handed melee weapons get none; a one-hander is compared with your off hand only if you can dual wield. For stat-weighted upgrades, choose Pawn as the upgrade provider.

<div align="center" style="text-align:center">
<a href="https://i.imgur.com/QGjlIYX.png" target="_blank"><img src="https://i.imgur.com/QGjlIYX.png" alt="Item Level Upgrade in Retail.">  </a>

*Item Level Upgrade in Retail.*
</div>

### Show Currencies
Currencies can be tracked at the bottom of the bag window. Up to 7 currencies can be shown at a time and tracking them is as simple as clicking on the currencies in the `Currency` screen in the Settings and choosing `Show in Backpack`. Any currency that is highlighted is currently tracked. If you attempt to track more than 7 currencies, only the first 7 in the list will be shown at the bottom of the bag.

<div align="center" style="text-align:center">
<a href="https://i.imgur.com/I8B0zn3.png" target="_blank"><img src="https://i.imgur.com/I8B0zn3.png" alt="Currencies Options in Retail."></a>

*Currencies Options in Retail.*
</div>

<div align="center" style="text-align:center">
<a href="https://i.imgur.com/2HeRBue.png" target="_blank"><img src="https://i.imgur.com/2HeRBue.png" alt="Tracked Currencies in Retail."></a>

*Tracked Currencies in Retail.*
</div>

### Configure Categories
Categories have a few ways in which they can be configured. All categories can be pinned. Custom categories can be deleted.  
- Pinning categories (Drag to the `Pinned` section) will display them in the listed order at the top of the bags. Any categories that are not pinned will be automatically ordered based on the `Section Sorting` option chosen in config.
- Deleting a category (`Delete Category` button after selecting the category) will permanently delete the category. If a category is created by a plugin, the plugin might create the category again when reloading the game.

<table>
	<tr>
		<td align="middle">
			<a href="https://i.imgur.com/Ux8j5nM.png" target="_blank"><img src="https://i.imgur.com/Ux8j5nM.png" alt="The Configure Categories Options in Retail."></a></td>
		</td>
		<td align="middle">
			<a href="https://i.imgur.com/Ke069nk.gif" target="_blank"><img src="https://i.imgur.com/Ke069nk.gif" alt="Moving a Category in Configure Categories in Retail."></a></td>
		</td>
	</tr>
	<tr>
		<td align="middle">
			The Configure Categories Options in Retail.
		</td>
		<td align="middle">
			Moving a Category in Configure Categories in Retail.
		</td>
	</tr>
	<tr>
		<td align="middle">
			<a href="https://i.imgur.com/XlO0Ab4.png" target="_blank"><img src="https://i.imgur.com/XlO0Ab4.png" alt="Configure Custom Categories in Retail."></a></td>
		</td>
		<td align="middle">	
			<a href="https://i.imgur.com/fdDvwRI.png" target="_blank"><img src="https://i.imgur.com/fdDvwRI.png" alt="Configure Search Category in Retail."></a></td>
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

### Category Groups
Category Groups allow you to put different categories onto different tabs to minimize the space required for your bags and focus on the most important items in your bags. Just hit the green plus icon to create a new group, then drag any categories you want onto the tab at the bottom of your bags. The default "Backpack" tab is always first and includes all categories that haven't been moved into a different group. Other groups can be renamed and deleted.  
If you don't want to use groups, you can turn it off in the settings.

<table>
	<tr>
		<td align="middle">
			<a href="https://i.imgur.com/JtzBCFm.gif" target="_blank"><img src="https://i.imgur.com/JtzBCFm.gif" alt="Moving a Category to a New Group in Retail."></a></td>
		</td>
		<td align="middle">
			<a href="https://i.imgur.com/jJ8DPfv.png" target="_blank"><img src="https://i.imgur.com/jJ8DPfv.png" alt="Create a New Group in Retail."></a></td>
		</td>
	</tr>
	<tr>
		<td align="middle">
			Moving a category to a new group in Retail.
		</td>
		<td align="middle">
			Create a New Group in Retail.
		</td>
	</tr>
		<td align="middle">	
			<a href="https://i.imgur.com/mkPGOzj.png" target="_blank"><img src="https://i.imgur.com/mkPGOzj.png" alt="An Empty Group in Retail."></a></td>
		</td>
		<td align="middle">	
			<a href="https://i.imgur.com/TmbFBBn.png" target="_blank"><img src="https://i.imgur.com/TmbFBBn.png" alt="Group Options in Retail."></a></td>
		</td>
	</tr>
	<tr>
		<td align="middle">
			An Empty Group in Retail.
		</td>
		<td align="middle">
			Group Options in Retail.
		</td>
	</tr>
</table>

## Bank
### Bank Tabs
BetterBags displays the different types of bank as tabs along the bottom of the bank window. It also includes the option to purchase the Reagent Bank and any available Warband Bank tabs.  
Tabs include:
- Bank (Showing all base bank tabs as well as bank bags for older versions).
- Warband Bank Tabs 1-5 (Called `Warbank Tab` in BetterBags).

<div align="center" style="text-align:center">
<a href="https://i.imgur.com/sxbCWNT.png" target="_blank"><img src="https://i.imgur.com/sxbCWNT.png" alt="Bank Tabs in Retail."></a>

*Bank Tabs in Retail.*
</div>

### Bank Bags
To purchase bank bag slots, turn on `Show Bags` and click on any red bag slot.

<div align="center" style="text-align:center">
<a href="https://i.imgur.com/UTl2bDg.png" target="_blank"><img src="https://i.imgur.com/UTl2bDg.png" alt="Purchasing Bank Bag Slots in Retail."></a>

*Purchasing Bank Bag Slots in Retail.*
</div>

### Character Bank Tabs
To show Character Bank Tabs, turn on the option in the Bank Menu. This allows all of the Bank Tabs to become tabs on the bottom of the Bank, beside the Warbank Tabs. When the tabs are shown, they act just like Warbank Tabs described below.

<div align="center" style="text-align:center">
<a href="https://i.imgur.com/UdAJJAZ.png" target="_blank"><img src="https://i.imgur.com/UdAJJAZ.png" alt="Showing Character Bank Tabs in Retail."></a>

*Showing Character Bank Tabs in Retail.*
</div>

<div align="center" style="text-align:center">
<a href="https://i.imgur.com/8zHRoGY.png" target="_blank"><img src="https://i.imgur.com/8zHRoGY.png" alt="Character Bank Tabs and Warbank Tabs in Retail."></a>

*Character Bank Tabs and Warbank Tabs in Retail.*
</div>

### Warbank Tabs
Warbank tabs can be renamed and certain item types can be assigned to them by right-clicking on the tab at the bottom of the bank. This will bring up the Blizzard prompt to make any changes. Depositing items into the Warbank tabs will deposit them using Blizzard's rules for depositting items into the Warbank.

<div align="center" style="text-align:center">
<a href="https://i.imgur.com/98Hgf2I.png" target="_blank"><img src="https://i.imgur.com/98Hgf2I.png" alt="Editing Warbank Tab in Retail."></a>

*Editing Warbank Tab in Retail.*
</div>

To deposit or withdraw gold from the Warbank, hover over the gold amount at the bottom of the bank/warbank window and left or right click. This works from any tab in the bank window.

<div align="center" style="text-align:center">
<a href="https://i.imgur.com/LQmRp1m.png" target="_blank"><img src="https://i.imgur.com/LQmRp1m.png" alt="Manipulating Warbank Money in Retail."></a>

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
<a href="https://i.imgur.com/svPb2eT.gif" target="_blank"><img src="https://i.imgur.com/svPb2eT.gif" alt="Recent Items in Retail"></a>

*Recent Items in Retail.*
</div>

To disable recent items, uncheck the `Recent Items` category in the config window and set the `New Item Duration` to 0. After hovering over the item and changing anything in the bags, it will stop flashing.

## Move Categories
Right-clicking on a category header in your bank or bags will move the entire contents of the category to whatever other window you currently have open.
Supported windows include bags, all bank tabs, the mailbox, the trade window, and vendor windows. Selling items to vendors by right-clicking the header must be turned on in settings.

<div align="center" style="text-align:center">
<a href="https://i.imgur.com/b8BZTlX.gif" target="_blank"><img src="https://i.imgur.com/b8BZTlX.gif" alt="Move Category in Retail"></a>

*Move Category in Retail.*
</div>

## Search
BetterBags offers a comprehensive Search option that can be toggled with a keybinding (`BetterBags > Search Bags`).

When searching for bare words (eg. "Signet"), the search will match any item that has the word in the entire text of the default indices, which includes `name`, `type`, `subtype`, `category`, `equipmentLocation`, `binding`, and `tooltip`. When searching in an index (eg. "name = Signet"), using the `=` operator will search in a prefix style, meaning the things you are searching for must start with what you type. To support full-text searching of each field, use the `%=` operator. The exception is `tooltip`: there, `=` and `!=` match the text anywhere in the tooltip, the same as `%=`.  
If you would like to exclude items in gear sets from your searches, the easiest way to do so is add `and not category = "gear:"` to the end of your search. (eg. `slot = finger or slot = neck and not (category = 'gear:')` will highlight all rings and necklaces that are NOT part of a gear set)
Search allows you to find items by the following indices (based on the item below):

<div align="center" style="text-align:center">
<a href="https://i.imgur.com/Sc0JHZX.png" target="_blank"><img src="https://i.imgur.com/Sc0JHZX.png" alt="Example Item in Retail."></a>

*Example Item in Retail.*
</div>

### Strings
- `name` (name = "Tome of Unstable Power") The name of the item; the first line in the tooltip.
- `type` (type = Armor) The type of the item. Some examples include Armor, Weapon, Consumable, and Reagent.
- `subtype` (subtype = Miscellaneous) The subtype of the item. Some examples include Leather, Potion, Bag, and Bows. See the [Warcraft Wiki](https://warcraft.wiki.gg/wiki/ItemType) for more information regarding type and subtype.
- `category` (category = "Gear: MW DPS") The category that the item is sorted into in BetterBags. In a search category's query, it is the category the item has without any search category (a custom category, a gear set, or its type), so a search category is never matched through its own name or another search category's.
- `equipmentLocation` or `slot` (slot = Trinket) The item slot that the gear is for. Examples include Head, Legs, Main-Hand, and Finger.
- `expansion` or `exp` (expansion = DF) The expansion that the item is originally from. Shorthands are: Classic, BC, WotLK, Cata, MoP, WoD, Legion, BfA, SL, DF, TWW, Mid. `<`, `<=`, `>` and `>=` compare expansions in release order (`exp < legion` finds everything from before Legion), and an expansion can be given by its number (`exp = 3` for Cataclysm, 0 being Classic). In a comparison the start of a name works when only one expansion starts that way (`exp >= mid`, not `exp >= c`).
- `equipmentSet` (equipmentSet = "MW DPS") The equipment set(s) that a piece of gear is part of.
- `guid` (guid = 'item-60-0-4000000CAEA5CBE3') The globally unique identifier of the item. This string is unique to the specific instance of an item.
- `binding` (binding = soulbound) The text description of the binding type of the item. Possible values include nonbinding (items that do not bind), boe (bind on equip), bou (bind on use), quest (a soulbound quest item), soulbound (bound to a specific character), refundable (items that can be sold back to a vendor for a full refund), warbound (bound to a warband), bnet (bound to a battle.net account), or wue (warbound until equipped). **Note:** soulbound and warbound are only available on Retail because of API limitations on non-Retail versions.
- `tooltip` (tooltip = health) The full text of the item's tooltip. Unlike the other string fields, `=` and `!=` match the value anywhere in the tooltip, not only at the start.
- `bagname` or `bag` (bag = "Herb Satchel") The name of the bag the item is in: Backpack, the bag's own name, Keyring, Bank, Reagent Bank, a bank bag's name, or a guild bank tab's name. A plain search word does not look in it.
- `track` (track = hero) The upgrade track of upgradeable gear (Retail): Explorer, Adventurer, Veteran, Champion, Hero, Myth, in the game's language.
- `stat` (stat = haste) The stats on the item, by name: Haste, Critical Strike, Versatility, Mastery, Stamina, Strength, Agility, Intellect, Leech, Speed, Avoidance, sockets, and so on. `stat = crit` finds Critical Strike, as names match from their start.

### Numbers
- `level` or `ilvl` (ilvl = 528) The item level of the item. Non-gear items have item levels as well, but they are not shown to the user.
- `rarity` (rarity = epic or rarity = 4) The rarity of the item. Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Artifact = 6, Heirloom = 7.
- `quality` (quality >= 2) The crafting quality tier of a profession reagent or a crafted item, the number its quality icon shows (Retail only). Items without a tier have none, so `quality != 2` includes them. For Poor to Legendary, use `rarity`.
- `id` (id = 212685) The internal itemID of the item. A number uniquely identifying the base item. Specific ItemIDs can be found in the url on the item's WoWHead page.
- `stackCount` or `count` (stackCount = 1) The number of items in the stack for the item. **NOTE:** Currently count only takes into account the stack size of the "base" stack when using virtual stacks. For example, a virtual stack of 20, 20, and 3 to total 43 items will only be matched with either 20 or 3, not both.
- `class` (class = 4) The numeric representation of itemType.
- `subclass` (subclass = 0) The numeric representation of itemSubtype. See the [Warcraft Wiki](https://warcraft.wiki.gg/wiki/ItemType) for more information regarding class and subclass.
- `bagid` (bagid = 2) The location of the bag containing the item. BagID is 0 for the main backpack, 1-4 for the bags, 5 for a reagent bag (Retail only), -1 for the main bank window, 5-10 (Classic) / 5-11 (MoP) / 6-11 (Retail) for bank bags, -1 for the bank (Classic/MoP), -2 for the keyring (Classic), -1 for the keyring (WoW: Forever), and 12-16 for warbank tabs. See the [Warcraft Wiki](https://warcraft.wiki.gg/wiki/BagID) for specifics for each version of the game.
- `slotid` (slotid = 11) The slot that the item is in, in the bag that contains it. Numbered from 1 to N for each bagID, where N is the size of the container.
- `bindtype` (bindtype = 1) The binding type of the item returned by GetItemInfo(). 1 = BoP, 2 = BoE, 3 = BoU, 4 = Quest, 7 = BtA, 8 = BtW, 9 = WuE. See the [Warcraft Wiki](https://warcraft.wiki.gg/wiki/Enum.ItemBind) for specifics.
- `minlevel` (minlevel > 70) The character level required to use the item, 0 for none. Not the item level (that is `level`).
- `stacksize` (stacksize = 200) The most of the item one stack holds. The size of a stack in your bags is `count`.
- `price` (price > 10000) The vendor sell price of one of the item, in copper (10000 is 1 gold). 0 for items a vendor will not buy.
- `maxlevel` (maxlevel >= 600) The item level of upgradeable gear once fully upgraded (Retail); for anything else, its item level.
- `upgradelevel`, `upgrademax` (upgradelevel = 3) How many upgrades upgradeable gear has, and how many its track has (Retail): an item shown as "Hero 3/6" has upgradelevel 3 and upgrademax 6.
- `petcount`, `petlimit` (petcount = 0) How many of a battle pet item's pet you have, and how many you may have (Retail).
- `total` (total >= 100) How many of the item the bags hold altogether (the backpack's bags for the backpack, the bank's for the bank), counting every stack of it.

### Booleans
- `reagent` (reagent = false) Is the item classified as a reagent?
- `bound` (bound = true) Is the item bound to the character or warband? (From BetterBags internal module)
- `isbound` (isbound = true) Is the item bound to the character or account? (From Blizzard C_Item)
- `quest` (quest = false) Is the item for a non-active quest?
- `activeQuest` (activeQuest = false) Is the item for an active quest?
- `equipment` (equipment = true) Can the item be equipped (gear, and bags, which go in the bag slots)?
- `hasuse` (hasuse = true) Does the item have a Use: line in its tooltip, "Use: Teaches you..." on recipes and pets included?
- `cosmetic` (cosmetic = true) Is the item cosmetic gear (Retail)?
- `pet` (pet = true) Does the item teach a battle pet (Retail)?
- `upgradeable` (upgradeable = true) Is the item gear on an upgrade track (Retail)?
- `scrappable` (scrappable = true) Can the item be scrapped (Retail)?
- `inset` (inset = true) Is the item in any equipment set? (`equipmentSet` names one.)
- `upgrade` (upgrade = true) Does BetterBags show the upgrade arrow on the item? It follows the upgrade provider chosen in the settings (BetterBags, Pawn or SimpleItemLevel).
- `usable` (usable = false) Can your character use the item? (Weapon and armor skills, level, professions, reputation: the red text in its tooltip.)
- `equippable` (equippable = true) Is the item gear your character can wear?
- `transmoggable` (transmoggable = true) Does the item have an appearance (Retail)?
- `collectable` (collectable = true) Is the item a battle pet you can still learn one more of (Retail)?
- `toy` (toy = true) Is the item a toy? (Its tooltip says "Toy".)
- `known` (known = true) Does the item's tooltip say "Already known" (a toy, recipe, pet or mount you already have)?

The fields `quality`, `track`, `stat`, `minlevel`, `stacksize`, `price`, `maxlevel`, `upgradelevel`, `upgrademax`, `equipment`, `hasuse`, `cosmetic`, `pet`, `upgradeable`, `scrappable`, `toy`, `known`, `transmoggable`, `usable`, `equippable` and `upgrade` are read once the game has sent the item's data, and `petcount`, `petlimit` and `collectable` once your pet journal has loaded: an item that has just arrived may match none of them for a moment.

### Logical Operators
- `AND` (slot = Legs AND ilvl > 500 \[This will match leg pieces that are also greater than 500 ilvl.\]) The intersection of two terms. Items must match both sides of the AND.
- `OR` (slot = Legs OR ilvl > 500 \[This will match items that are leg pieces or are greater than 500 ilvl.\]) The union of two terms. Items can match either or both sides of the OR.
- `NOT` (NOT slot = Legs \[This will match any item that cannot be equipped in the leg slot.\]) The complement of a term. Items must not match the NOT. It works on its own, inside an `OR`, and before a group (`NOT (rarity = poor OR rarity = common)`).
- `(` and `)` To group search terms.
- **Precedence:** `NOT` applies first, then `AND`, then `OR`, as in most query languages: `type = armor OR type = weapon AND ilvl > 200` matches all armor, and weapons above item level 200. Use parentheses to group differently: `(type = armor OR type = weapon) AND ilvl > 200`. Rules saved before this precedence were rewritten once with parentheses, so they still mean what they meant.
- `=` (type = Armor, ilvl = 506) Items with a value equal to the text or number on the right side. This will find any items starting with the value.
- `%=` (slot %= Hand \[This will match any gear pieces that are slotted into any slot with `Hand` in the name. eg. Hands, Main Hand, Offhand\]) Items with the value in the full text of the field(s).
- `!=` (expansion != DF) Items with a value not equal to the text or number on the right side. This will find any items NOT starting with the value.
- `"` or `'` (slot = "Main Hand") To search for a multi-word string.

### Comparison Operators
**Note: These only work on numerical fields. Rarity names can be used with these operators.**
- `>` Items with a value greater than the number on the right side.
- `<` Items with a value less than the number on the right side.
- `>=` Items with a value greater than or equal to the number on the right side.
- `<=` Items with a value less than or equal to the number on the right side.

<div align="center" style="text-align:center">
<a href="https://i.imgur.com/H2jgRO8.png" target="_blank"><img src="https://i.imgur.com/H2jgRO8.png" alt="Complex Search in Retail."></a>

*Complex Search in Retail.*
</div>

BetterBags also allows you to turn on a search bar near the top of the bag instead of the floating search box.

<div align="center" style="text-align:center">
<a href="https://i.imgur.com/S0W5Gmw.png" target="_blank"><img src="https://i.imgur.com/S0W5Gmw.png" alt="In-Bag Search Bar in Retail."></a>

*In-Bag Search Bar in Retail.*
</div>

## Custom Categories
BetterBags allows items to be grouped into custom categories. These categories can be manually populated by the user, created by plugins, or created from a search.  
The title colour of the category can be chosen. Make a beautiful rainbow with all your categories!

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
		<td align="middle">
			<a href="https://i.imgur.com/PztK78R.png" target="_blank"><img src="https://i.imgur.com/PztK78R.png" alt="Remove an Item from a Category in Retail."></a></td>
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
		<td align="middle">
			Remove an Item from a Category in Retail.
		</td>
	</tr>
</table>

### Search-based Custom Categories
Any search you complete has the option to be turned into a custom category. These categories will dynamically update as new items are added to the bag that match the search criteria.  
To create a Search Category, type in a search, then press `Enter`. Fill out the required information in the dialogue box and save.
- Category Name (string) is what the new category will be named.
- Search Query (string) is the search that will be run to determine which items will be in the category. Any search options (described above) will work in the query.
- Priority (number) is the order in which search categories will "steal" items. Items can only be in 1 category at a time and higher priority will get items first.
- Group By (string) allows you to create multiple categories from 1 string. Valid options are none, type, subtype, and expansion. This can be chosen as an option or included directly in the search string.  
`exp = mid and not "housing decor" group by type` will create a category for every type of item from the Midnight expansion, eg. "Midnight - Armor", "Midnight - Weapon", etc.

<table>
	<tr>
		<td align="middle">
			<a href="https://i.imgur.com/wOUmfRi.png" target="_blank"><img src="https://i.imgur.com/wOUmfRi.png" alt="Creating a Search Category in Retail."></a></td>
		</td>
		<td align="middle">
			<a href="https://i.imgur.com/DpdkrYT.png" target="_blank"><img src="https://i.imgur.com/DpdkrYT.png" alt="Configure Search Category in Retail."></a></td>
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
BetterBags offers built-in themes, chosen in Settings > Theme: Default (Blizzard's look), Simple Dark, and Slate, Dark and Parchment, from BetterBags' sister addon Moonlight.  
BetterBags will detect if you have ElvUI or GW2 UI installed and offer an addon specific theme that follows your ElvUI or GW2 UI settings.

Themes are data: a theme describes how each kind of window and element looks, and BetterBags applies it to every bag, bank, dialog, panel, item button, tab, section title, search box and button. Addon authors can write their own; see [`sonata/README.md`](sonata/README.md).

<table>
	<tr>
		<td align="middle">
			<a href="https://i.imgur.com/P2clwi6.png" target="_blank"><img src="https://i.imgur.com/P2clwi6.png" alt="Simple Dark Theme in Retail (with additional theme options from BetterBags - Themes)."></a></td>
		</td>
		<td align="middle">
			<a href="https://i.imgur.com/pddxrSV.png" target="_blank"><img src="https://i.imgur.com/pddxrSV.png" alt="GW2 UI Theme in Retail."></a></td>
		</td>
	</tr>
	<tr>
		<td align="middle">
			Simple Dark Theme in Retail (with additional theme options from <a href="https://www.curseforge.com/wow/addons/betterbags-themes">BetterBags - Themes</a>).
		</td>
		<td align="middle">
			GW2 UI Theme in Retail.
		</td>
	</tr>
</table>

## Profiles
BetterBags allows you to set up profiles per character. By default, all characters will use the "Default" profile.  
Profiles will save all settings, including categories, anchor, theme, etc.

<div align="center" style="text-align:center">
<a href="https://i.imgur.com/iaoX1vE.png" target="_blank"><img src="https://i.imgur.com/iaoX1vE.png" alt="Profile Options in Retail."></a>

*Profile Options in Retail.*
</div>

## Import/Export
BetterBags supports import and export strings to easily share your category settings with other users.  
Import and Export strings only contain category information. Set your own style for the bags, then import the best category setup!

<table>
	<tr>
		<td align="middle">
			<a href="https://i.imgur.com/KzaicF4.png" target="_blank"><img src="https://i.imgur.com/KzaicF4.png" alt="Import/Export Options in Retail."></a></td>
		</td>
		<td align="middle">
			<a href="https://i.imgur.com/daQTr5L.png" target="_blank"><img src="https://i.imgur.com/daQTr5L.png" alt="Example Export String."></a></td>
		</td>
	</tr>
	<tr>
		<td align="middle">
			Import/Export Options in Retail.
		</td>
		<td align="middle">
			Example Export String.
		</td>
	</tr>
</table>

## BetterBags Next (experimental)
An early look at a new design for your bags. Turn it on with **BetterBags Next (experimental)** in the settings, or type `/bb next`; BetterBags asks to reload the UI for it to take effect, and the same setting or command turns it off again.

- Your backpack becomes a full-height panel that slides in from the right edge of the screen, and your bank its mirror image on the left, both with soft, feathered edges instead of a border.
- Your groups become tabs down the inner side of each panel: click one to switch, right-click one to rename or delete it, and click **+** to make a new group.
- Your categories are listed in one column, each its own row of large icons, with Recent Items first and Free Space last. The list scrolls.
- Sections fade in as a panel opens, items glide to their new places when you sort or loot, and sparkles drift out of the window from the title.
- Drag a category by its header to move it: the whole section comes with your cursor and the others slide out of its way. Drop it where you want it and it stays there. Drop it on a tab to move the category to that group, or (at the bank) on the other bag, or one of its tabs, to move everything in it there. Right-click a header to move the section to whatever window is open, as in the regular bags.
- Searching, sorting, the settings button, dropping items onto the panel, cooldowns and tooltips work as they do in the regular bags.
- In the bank, your Warbank groups are listed after your bank groups, in teal, and the top of the panel turns teal while one shows. The buttons at the top close the bank, deposit your Warbound items, sort the bank (or the Warbank, while it shows) and switch between your groups and the bank's own tabs, where you can see each tab on its own, buy tabs, and right-click a tab to change its name, icon and deposit settings. In WoW: Forever, drop a bag on a bank tab to use it.

Not there yet: the backpack's Show Bags panel, currencies, the bag anchor, the bag menu, and the size and opacity settings (the panels have one size). It is an experiment and may change or go away; please report what you think.

## Reporting Performance Problems
If BetterBags makes your game stutter, you can record exactly what it was doing and send that along with your report.

1. Type `/bbdb` to open the debug window and switch to the **Performance** tab.
2. Press **Start Capture**, do whatever causes the stutter (open your bags, loot, use the abilities that lag), then press **Stop Capture**. To record the load-in itself, tick **Capture next reload** and type `/reload` instead.
3. The capture is saved as a session in the list on the left. Select it to see a flame graph of where the time went, the slowest frames, and a summary.
4. Log out or `/reload` so the game writes the session to `WTF/Account/<ACCOUNT>/SavedVariables/BetterBags.lua`, and attach that file to your report.

Profiling is always off unless you start it, and it is never left running across a reload. Saved sessions can be deleted from the same tab.

## Plugin System
BetterBags has a robust plugin system that allows developers to write custom categories.

Plugins have the following options:
- Custom Category API, to create new categories through the plugin.
- Config Module API, allowing plugin authors to let users fine-tune their own experience.
- Theme API, to allow plugins to create new themes ([`sonata/README.md`](sonata/README.md)).
- Localization module, which allows the plugin author to localize their text.

<div align="center" style="text-align:center">
<a href="https://i.imgur.com/XgGTR18.png" target="_blank"><img src="https://i.imgur.com/XgGTR18.png" alt="Plugin System (BetterBags - Appearances) in Retail"></a>

*Plugin System (<a href="https://www.curseforge.com/wow/addons/betterbags-appearances">BetterBags - Appearances</a>) in Retail.*
</div>

# Upcoming Updates
BetterBags is constantly getting new features and updates.  
Github hosts both our [Progress Board](https://github.com/users/Cidan/projects/2) and means to [report bugs and request new features](https://github.com/Cidan/BetterBags/issues/new/choose).

The following features are under active development:
- Virtual Bank Groups, just like Category Groups in Bags!
- Integration with [QuickFind](https://www.curseforge.com/wow/addons/quickfind).

These features are planned for the long term:
- Feature parity between search categories and manual categories.
- Dynamic number of columns.
- Reagent bag markers for items in the reagent bag.
- Faster/smoother item updates.
- And much more!