local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class HelpArticles: AceModule
local articles = addon:GetModule('HelpArticles')

articles:Group({ id = "categories", title = L:G("Categories") })

articles:Define({
  id = "categories-intro", group = "categories", featured = true,
  title = L:G("Category Basics"),
  summary = L:G("What a category is, and which one an item goes in when it fits more than one."),
  keywords = { L:G("category"), L:G("categories"), L:G("custom category"), L:G("priority"), L:G("order"), L:G("wins"),
    L:G("which category"), L:G("Categories page"),
    L:G("how categories work"), L:G("duplicate category priority"), L:G("section sorting"), L:G("item groups")
  },
  questions = { L:G("What is a category?"), L:G("Why is my item not in my category?"),
    L:G("Which category does an item go in?"), L:G("How do I change a category's priority?"),
    L:G("How do categories work in BetterBags?"), L:G("What happens when an item matches two categories?"),
    L:G("Can an item show up in more than one section?"), L:G("Why does an item only appear in one category?"),
    L:G("Where is the Categories page in settings?"),
    L:G("How does BetterBags decide which category gets an item first?")
  },
  pages = { "categories" },
  related = { "category-make", "category-rule", "category-items", "sections", "wrong-category" },
  body = {
    { text = L:G("A category is a set of items with a name. Each one shows as a section in your bags. A category holds the items you add to it by hand, the items its search rule finds, or both.") },
    { heading = L:G("Category Priority") },
    { text = L:G("An item shows in one category only. When it fits more than one, the category higher in the list on the Categories page wins. Drag categories up and down that list to change which wins. A new category starts at the top.") },
    { text = L:G("An item you add to a category by hand stays in that category, no matter what else it fits.") },
    { heading = L:G("Categories Page") },
    { text = L:G("Open the settings and choose Categories. The pages slide out of the sidebar and your categories slide in, with a box to find a category and New Category under them. Choose a category to see its tabs: Settings, Search Rule, Added Items, Ignored Items, Automation, and Item Order. All Settings at the top takes you back.") },
    { open = { page = "categories", text = L:G("Open the Categories page") } },
  },
})

articles:Define({
  id = "category-make", group = "categories",
  title = L:G("New Categories"),
  summary = L:G("Every way to make a new category: from the settings, from an item, or from a search."),
  keywords = { L:G("new category"), L:G("create category"), L:G("make category"), L:G("add category"),
    L:G("enter to make category"),
    L:G("new section"), L:G("custom group"), L:G("make bag filter"),
    L:G("Making a Category")
  },
  questions = { L:G("How do I make a new category?"), L:G("How do I create a custom category?"),
    L:G("How do I make a category from an item?"), L:G("How do I make a category from a search?"),
    L:G("How do I create a new category?"), L:G("How do I turn a search into a category?"),
    L:G("Can I make a category right from an item in my bag?"), L:G("Where do I go to add a custom section?"),
    L:G("How do I group specific items together in their own box?"),
    L:G("What are the ways to make a category in settings?")
  },
  settings = { "enterToMakeCategory" },
  related = { "categories-intro", "category-rule", "category-items" },
  body = {
    { heading = L:G("Settings Page") },
    { steps = {
      L:G("Open the settings and choose Categories."),
      L:G("Click New Category under the list, and name it."),
      L:G("Give it a search rule on its Search Rule tab, add items on its Added Items tab, or both."),
    } },
    { heading = L:G("Bag Button") },
    { text = L:G("In the classic bags, pick up an item and click the bag button at the top left, or drop the item on it. Name the category, and the item goes into it.") },
    { heading = L:G("Search Box") },
    { text = L:G("In the classic bags, turn on Enable Enter to Make Category on the General page. Type a search and press Enter. The Categories page asks for a name, and the search becomes the new category's rule.") },
    { setting = "enterToMakeCategory" },
  },
})

articles:Define({
  id = "category-rule", group = "categories", featured = true,
  title = L:G("Search Rules"),
  summary = L:G("A category that fills itself with every item a search finds."),
  keywords = { L:G("search rule"), L:G("rule"), L:G("query"), L:G("smart category"), L:G("dynamic"), L:G("automatic category"),
    L:G("group by"), L:G("search category"),
    L:G("dynamic category"), L:G("auto filter section"),
    L:G("Search Rule Categories")
  },
  questions = { L:G("How do I make a category that adds items by itself?"), L:G("How do I use a search as a category?"),
    L:G("How do I split a category by type?"),
    L:G("How do I make a category that updates automatically from a search?"),
    L:G("What does Group By do in a search rule category?"),
    L:G("How do I set up a dynamic filter like in ArkInventory?"),
    L:G("Can a category automatically put new matching items inside it?"),
    L:G("How do I split a search category by expansion or item type?"),
    L:G("Why would I use a search rule instead of adding items one by one?")
  },
  pages = { "categories:rule" },
  related = { "search-basics", "search-examples", "category-make", "category-settings" },
  body = {
    { text = L:G("A category's search rule works like a search you type in your bags. Every item it finds goes into the category, and new items join as they arrive.") },
    { steps = {
      L:G("On the Categories page, choose the category and open its Search Rule tab."),
      L:G("Type the rule. The items it finds in your bags show under it as you type."),
      L:G("Click Apply Search Rule."),
    } },
    { example = "type = consumable", text = L:G("Every consumable.") },
    { example = "rarity = poor", text = L:G("Every gray item.") },
    { heading = L:G("Group By") },
    { text = L:G("Group By, on the category's Settings tab, splits the category into a section for each Type, Subtype, or Expansion of its items. You can also end the rule with group by type, group by subtype, or group by expansion.") },
    { example = "exp = mid group by type", text = L:G("A section for each type of item from Midnight.") },
    { tip = L:G("In a rule, category means the category an item would have without any search rule, so one search category never matches another.") },
  },
})

articles:Define({
  id = "category-items", group = "categories",
  title = L:G("Adding Items"),
  summary = L:G("Putting items in a category by hand, and taking them out again."),
  keywords = { L:G("add item"), L:G("remove item"), L:G("added items"), L:G("manual"), L:G("drag item"), L:G("shift drop"),
    L:G("put in category"), L:G("take out"),
    L:G("add item category"), L:G("remove item section"), L:G("manual sorting"), L:G("drag item category"),
    L:G("added by mistake")
  },
  questions = { L:G("How do I add an item to a category?"), L:G("How do I remove an item from a category?"),
    L:G("How do I move an item to another category?"),
    L:G("How do I add an item to a category manually?"), L:G("How do I take an item out of a custom category?"),
    L:G("Can I drag and drop an item into a section?"), L:G("How do I move a single item into my own group?"),
    L:G("Why is an item stuck in a category I put it in earlier?"),
    L:G("How do I remove items from a category by hand?"),
    L:G("take an item back out"),
    L:G("Adding and Removing Items")
  },
  pages = { "categories:items" },
  related = { "category-ignored", "categories-intro", "dropping" },
  body = {
    { text = L:G("An item you add to a category by hand stays in it, no matter what else it fits.") },
    { heading = L:G("Adding Items") },
    { list = {
      L:G("In your bags: hold Shift and drop the item on the category's section title. In BetterBags Next, drop it on the title without Shift."),
      L:G("On the Categories page: drop the item anywhere on the category's Added Items tab."),
    } },
    { heading = L:G("Removing Items") },
    { text = L:G("On the category's Added Items tab, right-click the item and choose Remove. Remove All asks first, then empties the list. Use the box at the top of the tab to find an item in a long list.") },
    { open = { page = "categories", tab = "items", text = L:G("Open the Added Items tab") } },
  },
})

articles:Define({
  id = "category-ignored", group = "categories",
  title = L:G("Ignored Items"),
  summary = L:G("Keeping an item out of a category, no matter what would put it there."),
  keywords = { L:G("ignore"), L:G("ignored"), L:G("exclude"), L:G("never"), L:G("keep out"), L:G("exception"),
    L:G("ignored items"), L:G("exclude from category"), L:G("category blacklist"), L:G("block item section")
  },
  questions = { L:G("How do I keep an item out of a category?"), L:G("How do I exclude an item from a search category?"),
    L:G("How do I keep an item out of a category forever?"),
    L:G("How do I exclude a specific item from a search rule category?"),
    L:G("Can I blacklist an item from going into a plugin category?"),
    L:G("Why do I keep seeing this item in a category I don't want it in?"),
    L:G("How do I stop an item from matching a category rule?"),
    L:G("Where do I manage ignored items for a category?"),
    L:G("keeps getting pulled in"), L:G("How do I keep one item out of a category for good?")
  },
  pages = { "categories:ignored" },
  related = { "category-items", "category-rule", "wrong-category" },
  body = {
    { text = L:G("A category's Ignored Items tab lists the items it never takes, whether you added them by hand, its search rule finds them, or a plugin lists them. An ignored item goes to the next category that wants it, or to its usual section.") },
    { list = {
      L:G("Drop an item anywhere on the Ignored Items tab to ignore it."),
      L:G("Right-click it there and choose Remove to stop ignoring it."),
    } },
    { text = L:G("This works for a plugin's categories too.") },
  },
})

articles:Define({
  id = "category-settings", group = "categories",
  title = L:G("Category Settings"),
  summary = L:G("Choosing the bags a category is used in, hiding it, setting its color, and splitting it."),
  keywords = { L:G("color"), L:G("colour"), L:G("used in"), L:G("hide in"), L:G("hide category"), L:G("group by"),
    L:G("rename"), L:G("delete"), L:G("export"),
    L:G("category settings"), L:G("hide section"), L:G("category color"), L:G("rename delete category"),
    L:G("A Category's Settings")
  },
  questions = { L:G("How do I color a category?"), L:G("How do I hide a category?"),
    L:G("How do I use a category only in my bank?"), L:G("How do I rename a category?"),
    L:G("How do I hide a category I don't want to see?"),
    L:G("Can I use a category only in my bank and not my backpack?"),
    L:G("How do I change the color of a category header?"), L:G("How do I rename or delete a category?"),
    L:G("What does splitting a category do?"), L:G("Can I export just one category from its settings?")
  },
  pages = { "categories:settings" },
  related = { "categories-intro", "category-share", "category-rule" },
  body = {
    { text = L:G("Choose a category on the Categories page and open its Settings tab.") },
    { list = {
      L:G("Used In: the bags the category is used in. If you turn a category off in a bag, its items go to the next category that fits them there."),
      L:G("Hide In: the bags where the category's items stay hidden. The items stay in your bags, and the bag's footer shows how many are hidden."),
      L:G("Group By: splits the category into a section for each Type, Subtype, or Expansion of its items."),
      L:G("Color: the color of the section's title. Reset Color restores its usual color."),
    } },
    { text = L:G("Below these settings, the tab counts the category's items currently in each of your bags.") },
    { heading = L:G("Page Buttons") },
    { text = L:G("The buttons at the top of the page rename the category, delete it, or export it as text to share.") },
  },
})

articles:Define({
  id = "blizzard-categories", group = "categories",
  title = L:G("Blizzard Categories"),
  summary = L:G("The automatic sections named after item types, and making one your own."),
  keywords = { L:G("automatic"), L:G("built-in"), L:G("type"), L:G("subtype"), L:G("expansion"), L:G("equipment location"),
    L:G("trade skill"), L:G("convert"), L:G("Blizzard Categories"),
    L:G("default sections"), L:G("built-in categories"), L:G("item type groups"),
    L:G("item type sections"),
    L:G("Blizzard's Categories")
  },
  questions = { L:G("How do I split items by expansion?"), L:G("How do I sort items by armor type?"),
    L:G("What are the Blizzard categories?"), L:G("How do I edit a Blizzard category?"),
    L:G("Where do categories like Consumable and Trade Goods come from?"),
    L:G("Why can't I edit or delete a default category?"),
    L:G("How do I customize one of Blizzard's automatic categories?"),
    L:G("Can I turn a built-in item type section into my own category?"),
    L:G("How do I add or remove items in Consumables or Quest?"),
    L:G("Why do some sections lack delete and rule options?")
  },
  settings = { "filterEquipmentLocation", "filterExpansion", "filterTradeSkill", "filterType", "filterSubtype" },
  pages = { "backpack:categories", "bank:categories", "guild:categories", "categories:blizzard" },
  related = { "sections", "category-gearsets", "recent-items" },
  body = {
    { text = L:G("Items that none of your categories take go into sections named from the game's item data. On a bag's Categories tab, under Automatic, choose how they are named:") },
    { list = {
      L:G("Type: by type, such as Armor or Consumable."),
      L:G("Sub Type: by subtype as well, such as Armor - Plate."),
      L:G("Expansion: by the expansion the item is from as well."),
      L:G("Equipment Location: gear by its slot, such as Head or Main Hand."),
      L:G("Trade Skill: reagents by the profession they are for."),
    } },
    { setting = "filterExpansion", bag = "Backpack" },
    { heading = L:G("Converting") },
    { text = L:G("Under Blizzard Categories, the Categories page lists the sections your backpack currently shows. Choose one and click Convert to Category to make it one of your categories. Its items still show in it, and you can change its color, hide it, automate it, add or ignore items, and give it a search rule. A converted category can't use Group By.") },
    { open = { page = "backpack", tab = "categories", text = L:G("Open the Backpack's Categories tab") } },
  },
})

articles:Define({
  id = "category-gearsets", group = "categories",
  title = L:G("Equipment Sets"),
  summary = L:G("The category each equipment set gets, and what you can change about it."),
  keywords = { L:G("gear set"), L:G("equipment set"), L:G("equipment manager"), L:G("gear:"), L:G("set"), L:G("outfit"),
    L:G("equipment set category"), L:G("gear sets"), L:G("outfit sections"), L:G("transmog armor sets"),
    L:G("loadout"), L:G("gear loadout"),
    L:G("armor swap"), L:G("spec gear"),
    L:G("Equipment Set Categories")
  },
  questions = { L:G("Why is there a Gear: category?"), L:G("How do I turn off equipment set categories?"),
    L:G("Why are my set items not sold?"),
    L:G("How do I put each of my equipment sets in its own category?"),
    L:G("Why did my gear set get its own section in my bags?"),
    L:G("What can I change about an equipment set category?"),
    L:G("Can I hide or color the section for my PvP or raid gear set?"),
    L:G("What happens if an item belongs to two equipment sets?"),
    L:G("How do I separate my offspec gear from the rest of my armor?")
  },
  settings = { "filterGearSet" },
  related = { "categories-intro", "category-settings", "auto-sell" },
  body = {
    { text = L:G("Each equipment set you save in the Equipment Manager gets a category named Gear: followed by the set's name. It holds the set's items.") },
    { list = {
      L:G("It works like your other categories: drag it in the list, color it, choose its bags, hide it, ignore items, and give its items an order of their own."),
      L:G("Rename a set in the Equipment Manager and its category follows, keeping your settings. It can't be renamed in BetterBags, and items can't be added to it by hand."),
      L:G("Delete a set and its settings are forgotten."),
      L:G("Nothing in an equipment set is ever sold, destroyed, or deposited on its own."),
    } },
    { text = L:G("Turn off Equipment Set on a bag's Categories tab to disable these categories in that bag.") },
    { setting = "filterGearSet", bag = "Backpack" },
    { tip = L:G("A set's settings are saved under the id the game gives the set, so characters on the same profile share them. Give characters their own profiles to keep their sets apart.") },
  },
})

articles:Define({
  id = "category-item-order", group = "categories",
  title = L:G("Own Item Order"),
  summary = L:G("Ordering one category's items its own way in every bag."),
  keywords = { L:G("own item order"), L:G("item order"), L:G("sort category"), L:G("then by"),
    L:G("category item order"), L:G("custom item sorting"), L:G("sort within section")
  },
  questions = { L:G("How do I sort one category differently?"), L:G("How do I order a category by item level?"),
    L:G("How do I sort the items inside just one category differently?"),
    L:G("Can I order one section by item level and leave the rest alone?"),
    L:G("How do I put items inside a specific category in my own order?"),
    L:G("Does a category's item order apply in both my bags and my bank?"),
    L:G("Why are items in one section sorted differently from my other bags?"),
    L:G("How do I change how items are arranged inside a single category?"),
    L:G("sort one category differently"), L:G("sort by stack count"),
    L:G("A Category's Own Item Order")
  },
  pages = { "categories:order" },
  related = { "item-order", "category-settings" },
  body = {
    { text = L:G("Turn on Own Item Order on a category's Item Order tab, and choose Item Order, Then By, and And Then By. Its items follow that order in every bag the category is used in. When Own Item Order is off, they follow the order of the bag they are in.") },
    { see = "item-order" },
  },
})

articles:Define({
  id = "category-share", group = "categories",
  title = L:G("Import and Export"),
  summary = L:G("Exporting your categories as text, and importing someone else's."),
  keywords = { L:G("import"), L:G("export"), L:G("share"), L:G("string"), L:G("copy"), L:G("paste"), L:G("backup"),
    L:G("share categories"), L:G("import export string"), L:G("copy categories"), L:G("backup categories"),
    L:G("back up"),
    L:G("Sharing Categories")
  },
  questions = { L:G("How do I share my categories?"), L:G("How do I import categories?"),
    L:G("How do I copy one category to a friend?"),
    L:G("How do I share my categories with a friend or guildmate?"),
    L:G("How do I import a category string I found online?"), L:G("Can I export all of my categories at once?"),
    L:G("How do I export just a single category to share?"),
    L:G("Where do I paste someone else's category text to import it?"),
    L:G("How do I move my custom categories to another account?")
  },
  pages = { "profiles:transfer" },
  related = { "profiles", "category-settings" },
  body = {
    { text = L:G("You can share categories as a line of text. Only categories are shared, never your other settings.") },
    { heading = L:G("All Categories") },
    { steps = {
      L:G("Open the Profiles page and go to its Import / Export tab."),
      L:G("Click Export Categories, then copy the text with Ctrl+C."),
    } },
    { heading = L:G("Single Category") },
    { text = L:G("Choose the category on the Categories page and click Export at the top of the page.") },
    { heading = L:G("Importing") },
    { text = L:G("Paste the text into Import on the Import / Export tab with Ctrl+V and click Import Categories. Importing all categories replaces your current ones and asks you to reload. Importing one category adds it to your list, and asks what to do if you already have a category with that name.") },
    { open = { page = "profiles", tab = "transfer", text = L:G("Open Import / Export") } },
  },
})

articles:Define({
  id = "category-plugins", group = "categories",
  title = L:G("Plugin Categories"),
  summary = L:G("Categories another addon makes, and what you can do with them."),
  keywords = { L:G("plugin"), L:G("addon"), L:G("third party"), L:G("made by a plugin"),
    L:G("plugin categories"), L:G("third party categories"), L:G("addon sections"), L:G("external categories"),
    L:G("Categories From Plugins")
  },
  questions = { L:G("Where did this category come from?"), L:G("Can I change a plugin's category?"),
    L:G("Where did these extra categories from another addon come from?"),
    L:G("What can I change on a category created by a plugin?"),
    L:G("Can I hide, recolor, or ignore items in a plugin category?"),
    L:G("Why can't I edit the rules of a category from a BetterBags plugin?"),
    L:G("How do I manage categories added by third-party addons?"),
    L:G("Can I use plugin categories with auto sell or auto deposit?"),
    L:G("I can't delete a plugin's category")
  },
  related = { "plugins", "category-deleted-returns", "category-ignored" },
  body = {
    { text = L:G("BetterBags plugins can make categories of their own. The Categories page marks them Made by a plugin.") },
    { text = L:G("You can move a plugin's category in the list, color it, choose its bags, hide it, ignore items in it, order its items, and automate it. You can see its search rule and its items, but only the plugin can change them.") },
    { see = "category-deleted-returns" },
  },
})
