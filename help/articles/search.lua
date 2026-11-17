local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class HelpArticles: AceModule
local articles = addon:GetModule('HelpArticles')

articles:Group({ id = "search", title = L:G("Search") })

articles:Define({
  id = "search-basics", group = "search", featured = true,
  title = L:G("Searching"),
  summary = L:G("Finding items by typing: words, fields and the search box."),
  keywords = { L:G("search"), L:G("find"), L:G("filter"), L:G("look for"), L:G("search box"), L:G("search bar"),
    L:G("highlight"), L:G("query"),
    L:G("find item"), L:G("saved search"), L:G("filter bags"),
    L:G("Searching Your Bags")
  },
  questions = { L:G("How do I find an item in my bags?"), L:G("How do I search my bags?"),
    L:G("Where is the search box?"), L:G("How do I search by item level?"),
    L:G("How do I search my bags for an item?"), L:G("How do I open the search box?"),
    L:G("Can I make a custom category out of a search query?"), L:G("How do search fields work?"),
    L:G("Can I search by item type instead of just the item name?"),
    L:G("Why didn't my search find an item I know I have?")
  },
  settings = { "inBagSearch", "enterToMakeCategory" },
  related = { "search-text", "search-numbers", "search-flags", "search-operators", "search-examples", "category-rule" },
  body = {
    { text = L:G("Type in the search box and your bags show only what matches, live, as you type. Clear the box to see everything again.") },
    { heading = L:G("Search Box") },
    { list = {
      L:G("With Enable In-Bag Search on, a search bar sits at the top of your bags."),
      L:G("With the classic bags, you can search without it: press your Search Bags key, or Shift-click the bag button, to open a search box of its own. BetterBags Next has no search box while Enable In-Bag Search is off."),
    } },
    { setting = "inBagSearch" },
    { heading = L:G("Plain Words") },
    { text = L:G("A word on its own finds every item with that word in its name, type, subtype, category, equipment slot, binding or tooltip. Put a phrase in quotes to search for it as a whole.") },
    { example = "potion", text = L:G("Every item with potion in its name, type or tooltip.") },
    { example = "'flask of'", text = L:G("Items with the words flask of together.") },
    { heading = L:G("Fields") },
    { text = L:G("To search only one field, write a field, an operator and a value. = finds values that start with what you type, so name = sig finds Signet of Light.") },
    { example = "ilvl >= 600", text = L:G("Gear of item level 600 and up.") },
    { example = "slot = trinket", text = L:G("Your trinkets.") },
    { heading = L:G("Search Categories") },
    { text = L:G("A search can become a category that keeps finding new items for you: make a category and give it the search as its rule. With the classic bags and Enable Enter to Make Category on, pressing Enter in the search box offers to make one.") },
    { see = "category-rule" },
  },
})

articles:Define({
  id = "search-text", group = "search",
  title = L:G("Text Fields"),
  summary = L:G("The fields that hold text, such as name, type, slot and binding."),
  keywords = { L:G("name"), L:G("type"), L:G("subtype"), L:G("category"), L:G("slot"), L:G("equipmentLocation"),
    L:G("expansion"), L:G("exp"), L:G("equipmentSet"), L:G("binding"), L:G("tooltip"), L:G("bag"), L:G("bagname"),
    L:G("track"), L:G("stat"), L:G("guid"), L:G("boe"), L:G("soulbound"), L:G("warbound"),
    L:G("search by slot"), L:G("search binding"), L:G("search type"), L:G("search fields"),
    L:G("Search Fields: Text")
  },
  questions = { L:G("How do I search for soulbound items?"), L:G("How do I find items from an expansion?"),
    L:G("How do I search the tooltip?"), L:G("How do I find items by stat?"),
    L:G("What text fields can I use in BetterBags search?"), L:G("How do I search for BoE or soulbound items?"),
    L:G("How do I filter my bags by armor slot like trinket or helm?"),
    L:G("Can I search for items by expansion or item type?"),
    L:G("How do I search by item subtype like potion or cloth?"),
    L:G("What field name checks an item's binding or equip slot?")
  },
  related = { "search-numbers", "search-flags", "search-operators" },
  body = {
    { text = L:G("These fields hold text. = finds values that start with what you type; %= finds what you type anywhere in the value.") },
    { list = {
      L:G("name: the item's name, the first line of its tooltip."),
      L:G("type and subtype: the item's type and subtype, such as Armor and Plate, or Consumable and Potion."),
      L:G("category: the category the item is in."),
      L:G("slot, or equipmentLocation: where the gear goes, such as Head, Finger or Trinket."),
      L:G("expansion, or exp: the expansion the item is from (Classic, BC, WotLK, Cata, MoP, WoD, Legion, BfA, SL, DF, TWW or Mid). A number works too, with 0 for Classic, and < and > compare expansions in release order."),
      L:G("equipmentSet: the equipment sets the gear is in."),
      L:G("binding: nonbinding, boe, bou, quest, soulbound, refundable, warbound, bnet or wue. Both soulbound and warbound work on Retail only."),
      L:G("tooltip: the whole text of the tooltip. Here = finds the text anywhere in it, as %= does."),
      L:G("bag, or bagname: the name of the bag the item is in. A plain word never searches it."),
      L:G("track: the upgrade track of upgradeable gear, such as Champion, Hero or Myth (Retail)."),
      L:G("stat: the stats on the item, by name. Names match from their start, so stat = crit finds Critical Strike."),
      L:G("guid: the unique id of an individual item."),
    } },
    { example = "binding = boe", text = L:G("Items that bind when equipped.") },
    { example = "exp < legion", text = L:G("Everything from before Legion.") },
    { example = "tooltip %= 'use: restores'", text = L:G("Items whose tooltip has Use: Restores in it.") },
    { example = "stat = haste", text = L:G("Gear with Haste on it.") },
  },
})

articles:Define({
  id = "search-numbers", group = "search",
  title = L:G("Number Fields"),
  summary = L:G("The fields that hold numbers, such as item level, rarity, price and count."),
  keywords = { L:G("ilvl"), L:G("level"), L:G("item level"), L:G("rarity"), L:G("quality"), L:G("id"), L:G("count"),
    L:G("stackCount"), L:G("price"), L:G("minlevel"), L:G("stacksize"), L:G("maxlevel"), L:G("upgradelevel"),
    L:G("slotequipped"), L:G("total"), L:G("bagid"),
    L:G("search ilvl"), L:G("search rarity"), L:G("vendor price"), L:G("stack count"),
    L:G("number filter"), L:G("numeric fields"),
    L:G("Search Fields: Numbers")
  },
  questions = { L:G("How do I find epic items?"), L:G("How do I search by item level?"),
    L:G("How do I find items that sell for a lot of gold?"), L:G("How do I find an item by its id?"),
    L:G("How do I search for items above a certain item level?"),
    L:G("How do I search by item rarity like epic or rare?"),
    L:G("Can I find items worth more than a certain amount of gold?"), L:G("What numeric fields can I search with?"),
    L:G("How do I search for items with a specific stack count?"),
    L:G("Can I filter by price, rarity, or item level?")
  },
  related = { "search-text", "search-math", "search-operators" },
  body = {
    { text = L:G("These fields hold numbers. Compare them with =, !=, <, <=, > and >=.") },
    { list = {
      L:G("ilvl, or level: the item level."),
      L:G("rarity: Poor 0, Common 1, Uncommon 2, Rare 3, Epic 4, Legendary 5, Artifact 6, Heirloom 7. The names work too."),
      L:G("quality: the crafting quality tier of a reagent or a crafted item (Retail). For Poor to Legendary, use rarity."),
      L:G("id: the item's id, the number in its Wowhead link."),
      L:G("count, or stackCount: how many are in the stack."),
      L:G("stacksize: the most one stack holds."),
      L:G("total: how many of that item the bag holds in total, across all stacks."),
      L:G("price: what a vendor pays for one, in copper. 0 when a vendor won't buy it."),
      L:G("minlevel: the character level needed to use it."),
      L:G("maxlevel: the item level of upgradeable gear once fully upgraded (Retail)."),
      L:G("upgradelevel and upgrademax: an item shown as Hero 3/6 has upgradelevel 3 and upgrademax 6 (Retail)."),
      L:G("slotequipped: the lowest item level you wear in the gear's slots. slotbest: the best you have had in that slot (Retail)."),
      L:G("petcount and petlimit: how many of a battle pet you have, and the most you can have (Retail)."),
      L:G("class and subclass: the type and subtype, as numbers."),
      L:G("bagid and slotid: the bag and the slot the item is in."),
      L:G("bindtype: how the item binds, as a number."),
    } },
    { example = "rarity = epic", text = L:G("Your epic items.") },
    { example = "ilvl > slotequipped", text = L:G("Gear with a higher item level than what you wear in its slot.") },
    { example = "total >= 100", text = L:G("Items you have at least 100 of.") },
  },
})

articles:Define({
  id = "search-flags", group = "search",
  title = L:G("Yes/No Fields"),
  summary = L:G("The fields that are true or false, such as bound, reagent, toy and known."),
  keywords = { L:G("true"), L:G("false"), L:G("bound"), L:G("reagent"), L:G("quest"), L:G("equipment"), L:G("toy"),
    L:G("known"), L:G("pet"), L:G("cosmetic"), L:G("upgrade"), L:G("auctionable"), L:G("ah"), L:G("lootable"),
    L:G("usable"), L:G("collectable"), L:G("appearance"), L:G("transmog"), L:G("scrappable"),
    L:G("search toys"), L:G("uncollected transmog"), L:G("reagent search"), L:G("search flags"),
    L:G("true or false")
  },
  questions = { L:G("How do I find toys I already know?"), L:G("How do I find items I can sell on the auction house?"),
    L:G("How do I find transmog I haven't collected?"), L:G("How do I find lockboxes?"),
    L:G("How do I search for soulbound or unbound items?"),
    L:G("How do I find items or recipes I haven't learned yet?"),
    L:G("Is there a search filter for crafting reagents or toys?"),
    L:G("How do I search for items that are bound to my character?"),
    L:G("Can I filter for toys or known items in my bags?"), L:G("What yes or no flags can I use in a search?"),
    L:G("yes or no fields"),
    L:G("Search Fields: Yes or No")
  },
  related = { "search-text", "search-operators", "search-examples" },
  body = {
    { text = L:G("These fields are true or false. Write the field's name alone to find the items where it is true, or compare it: toy, toy = true and not toy all work.") },
    { list = {
      L:G("bound: bound to your character or warband. isbound asks the game the same."),
      L:G("reagent: a crafting reagent."),
      L:G("quest and activeQuest: for a quest you don't have yet, or one you have."),
      L:G("equipment: can be equipped, bags included. equippable: gear your character can wear."),
      L:G("usable: your character can use it (no red text in its tooltip)."),
      L:G("hasuse: has a Use: line in its tooltip."),
      L:G("toy: a toy. known: its tooltip says Already known."),
      L:G("pet: teaches a battle pet. collectable: a battle pet you can still learn one more of (Retail)."),
      L:G("cosmetic, upgradeable and scrappable (Retail)."),
      L:G("upgrade: BetterBags shows its upgrade arrow."),
      L:G("auctionable, or ah = true: can be posted on the auction house."),
      L:G("lootable: can be opened, such as a lockbox, a clam or a cache."),
      L:G("inset: in an equipment set."),
      L:G("transmoggable: has an appearance (Retail). appearance and source: known or unknown, whether its look is in your collection (Retail)."),
    } },
    { example = "toy = true and known = true", text = L:G("Toys you already have.") },
    { example = "appearance = unknown", text = L:G("Gear whose look you have not collected.") },
    { example = "pet = true and collectable = false", text = L:G("Battle pets you can't learn more of.") },
    { tip = L:G("Some of these fields fill in once the game has sent the item's data, so an item that just arrived may match none of them for a moment.") },
  },
})

articles:Define({
  id = "search-operators", group = "search",
  title = L:G("Operators"),
  summary = L:G("Combining searches with and, or and not, and comparing values."),
  keywords = { L:G("and"), L:G("or"), L:G("not"), L:G("operator"), L:G("parentheses"), L:G("equals"), L:G("greater than"),
    L:G("less than"), L:G("%="), L:G("=="), L:G("exact"), L:G("contains"), L:G("combine"),
    L:G("boolean search"), L:G("not operator"), L:G("combine filters"),
    L:G("and or not"), L:G("combine conditions"),
    L:G("Search Operators")
  },
  questions = { L:G("How do I search for two things at once?"), L:G("How do I exclude items from a search?"),
    L:G("How do I search for an exact name?"), L:G("How do I search for text anywhere in a field?"),
    L:G("How do I combine two search filters with AND or OR?"),
    L:G("How do I exclude something from a search using NOT?"),
    L:G("How do I search for item level greater than or less than a number?"),
    L:G("Can I use parentheses to group search rules?"), L:G("Why isn't my combined search expression working?"),
    L:G("How do I compare values in a search?")
  },
  related = { "search-text", "search-numbers", "search-math", "search-examples" },
  body = {
    { heading = L:G("Combining") },
    { list = {
      L:G("AND: items must match both sides."),
      L:G("OR: items may match either side."),
      L:G("NOT: items must not match what follows it."),
      L:G("( and ): group terms."),
    } },
    { text = L:G("NOT applies first, then AND, then OR. Use parentheses to group them another way.") },
    { example = "(type = armor or type = weapon) and ilvl > 200", text = L:G("Armor and weapons above item level 200.") },
    { heading = L:G("Comparing") },
    { list = {
      L:G("= finds values that start with what you type. != finds the rest."),
      L:G("%= finds what you type anywhere in the value."),
      L:G("== finds values that match what you type exactly, ignoring case. ~= finds the rest."),
      L:G("<, <=, > and >= compare numbers. Rarity names work with them too."),
      L:G("Put single or double quotes around a value with several words."),
    } },
    { example = "slot %= hand", text = L:G("Gloves, main hands and off hands.") },
    { example = "name == hearthstone", text = L:G("The Hearthstone, and not items whose name starts with it.") },
  },
})

articles:Define({
  id = "search-math", group = "search",
  title = L:G("Math and Money"),
  summary = L:G("Using math in a search, writing gold amounts, and comparing with your own character."),
  keywords = { L:G("math"), L:G("money"), L:G("gold"), L:G("copper"), L:G("silver"), L:G("player"), L:G("player.level"),
    L:G("player.ilvl"), L:G("player.class"), L:G("min"), L:G("max"), L:G("arithmetic"), L:G("my level"),
    L:G("gold search"), L:G("player ilvl"), L:G("search math"), L:G("silver copper"),
    L:G("multiply"), L:G("50g"),
    L:G("calculation"), L:G("gold amounts")
  },
  questions = { L:G("How do I find gear far below my item level?"), L:G("How do I search by vendor price in gold?"),
    L:G("How do I make a category only for one class?"),
    L:G("How do I write gold, silver, and copper amounts in a search?"),
    L:G("Can I compare an item's ilvl to my character's equipped item level?"),
    L:G("Can I do math inside a search query?"), L:G("How do I find items usable at my character's level?"),
    L:G("How do I filter for gear compared to what I am wearing?"),
    L:G("How do I search for items worth at least 100g?"),
    L:G("Math, Money and Your Character")
  },
  related = { "search-numbers", "search-operators", "search-examples" },
  body = {
    { text = L:G("Either side of a comparison can use math.") },
    { list = {
      L:G("+, -, *, / and % do arithmetic. Put spaces around the sign."),
      L:G("min(), max(), floor(), ceil() and abs() work on numbers."),
      L:G("Money: 5g, 50s, 1g50s and 20c are amounts in copper."),
      L:G("Fields can be compared with fields, item by item."),
    } },
    { heading = L:G("Character Values") },
    { text = L:G("player.level, player.ilvl (your average item level), player.equippedilvl (what you wear), player.class, player.classid, player.spec, player.specid, player.profession, player.name and player.realm read values from your character. Checking your character alone matches either every item or none, so player.class = mage and ... limits a category to one class.") },
    { example = "ilvl < player.ilvl - 50", text = L:G("Gear far below your item level.") },
    { example = "price * count > 5g", text = L:G("Stacks a vendor would pay more than 5 gold for.") },
    { example = "minlevel > player.level", text = L:G("Items you are not high enough level to use yet.") },
  },
})

articles:Define({
  id = "search-examples", group = "search",
  title = L:G("Example Searches"),
  summary = L:G("Ready-made searches to find junk, upgrades, collectibles and more."),
  keywords = { L:G("examples"), L:G("ideas"), L:G("junk"), L:G("vendor trash"), L:G("gray items"), L:G("old gear"),
    L:G("sample"), L:G("recipes"),
    L:G("search examples"), L:G("find vendor trash"), L:G("search transmog"), L:G("filter upgrades"),
    L:G("Useful Searches")
  },
  questions = { L:G("What can I search for?"), L:G("How do I find my junk?"), L:G("What is a good search for selling?"),
    L:G("How do I search for gray items in my bags?"), L:G("What can I type in the search bar to find BoE gear?"),
    L:G("How do I find collectibles and pets I haven't learned yet?"),
    L:G("Can I search for gear upgrades in my inventory?"), L:G("What are some useful search filters I can copy?"),
    L:G("How do I look up items by stats or item level?")
  },
  related = { "search-basics", "category-rule", "auto-sell" },
  body = {
    { text = L:G("Type any of these in the search box, or use one as a category's rule.") },
    { example = "rarity = poor", text = L:G("Gray items, worth selling.") },
    { example = "ilvl < player.ilvl - 50 and binding = soulbound", text = L:G("Old soulbound gear you have outgrown.") },
    { example = "toy = true and known = true", text = L:G("Toys you have already learned.") },
    { example = "lootable = true", text = L:G("Lockboxes, clams and caches to open.") },
    { example = "upgrade = true", text = L:G("Gear with an upgrade arrow.") },
    { example = "(slot = finger or slot = neck) and not category = 'gear:'", text = L:G("Rings and necklaces in no equipment set.") },
    { example = "reagent = true and exp = tww", text = L:G("Reagents from The War Within.") },
    { tip = L:G("A search like these makes a good Auto Sell category.") },
    { see = "auto-sell" },
  },
})
