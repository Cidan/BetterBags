local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class HelpArticles: AceModule
local articles = addon:GetModule('HelpArticles')

articles:Group({ id = "next", title = L:G("BetterBags Next") })

articles:Define({
  id = "next-panels", group = "next", design = "next", featured = true,
  title = L:G("Small or Full"),
  summary = L:G("BetterBags Next's two sizes: small bags you move anywhere, or full-height panels on the edges of the screen."),
  keywords = { L:G("small"), L:G("full size"), L:G("minimize"), L:G("maximize"), L:G("panel"), L:G("move bag"),
    L:G("size button"), L:G("small bags"), L:G("full height"), L:G("edge of the screen"),
    L:G("small mode"), L:G("side panel"), L:G("floating bag"),
    L:G("compact or tall"), L:G("tall panel")
  },
  questions = { L:G("How do I make my bags smaller?"), L:G("How do I move my bags in BetterBags Next?"),
    L:G("How do I make my bags full height?"), L:G("How do I close the backpack?"),
    L:G("What is the difference between small bags and full size panels?"),
    L:G("How do I switch between a full-height side panel and a small floating bag?"),
    L:G("Why does my bag take up the whole side of the screen?"),
    L:G("How do I make my BetterBags Next window a small movable box?"),
    L:G("What do the buttons at the top of the backpack do in Next?"),
    L:G("Can I dock my bags to the left or right edge of the screen?"),
    L:G("Small and Full Size Bags")
  },
  related = { "next-size", "next-chain", "anchors", "designs" },
  body = {
    { text = L:G("All BetterBags Next bags are either small or full size at the same time.") },
    { list = {
      L:G("Small bags, the default, are movable windows: drag one by its title to move it anywhere."),
      L:G("Full size bags are full-height panels: the backpack on the right edge of the screen, and the bank, the vendor, and the guild bank on the left."),
    } },
    { text = L:G("The size button at the top of the backpack switches between the two, and every bag glides to its new size. Its tooltip says which way it goes: Small Bags or Full Size Bags.") },
    { heading = L:G("Header Buttons") },
    { list = {
      L:G("The X closes the backpack."),
      L:G("The settings button opens the settings."),
      L:G("The anchor button shows the bag's anchor, locks it, or unlocks it."),
      L:G("Show Blizzard Bags shows your bags themselves so you can swap them."),
      L:G("Right-click the title to sort the bag."),
    } },
    { see = "next-size" },
  },
})

articles:Define({
  id = "next-size", group = "next", design = "next",
  title = L:G("Size and Scale"),
  summary = L:G("Icon size, bag scale, and how a small bag grows to fit what it holds."),
  keywords = { L:G("icon scale"), L:G("bag scale"), L:G("autosize"), L:G("fit names"), L:G("bigger icons"), L:G("resize"),
    L:G("grips"), L:G("height"), L:G("width"), L:G("zoom"),
    L:G("icon size"), L:G("resize window"), L:G("slot size"),
    L:G("shrink"), L:G("smaller window"),
    L:G("tiny icons"), L:G("icons too small")
  },
  questions = { L:G("How do I make the item icons bigger?"), L:G("How do I make my bag taller?"),
    L:G("Why does my bag change height?"), L:G("Why are section names cut off?"),
    L:G("How do I make the item icons bigger or smaller in BetterBags Next?"),
    L:G("How do I resize a small bag window?"), L:G("How do I change the UI scale of my bags?"),
    L:G("Why does my small bag keep changing size on its own?"),
    L:G("Can I drag the corner to resize BetterBags Next?"), L:G("The text and icons in my bags look too small"),
    L:G("How do I make the bag window smaller?"),
    L:G("I can't read the stack counts"),
    L:G("A Bag's Size and Scale")
  },
  settings = { "nextIconScale", "nextBagScale", "nextAutosize", "nextFitNamesWhileOpen" },
  pages = { "backpack:size", "bank:size", "guild:size", "vendor:size" },
  related = { "next-panels", "section-layout" },
  body = {
    { text = L:G("Each bag's settings page has a Size tab: the Backpack, Bank, Guild Bank, and Vendor pages each set their own bag.") },
    { list = {
      L:G("Icon Scale: how big the item buttons are, as a percentage of the theme's size. Each row fits as many buttons as it can."),
      L:G("Bag Scale: the size of the bag while it is small, as a percentage. A full size bag keeps its size."),
      L:G("Autosize: a small bag is as tall as what it holds and its Free Space, growing and shrinking as items come and go, as far as the screen allows. Its width stays as you set it. It is on by default, except for the vendor."),
      L:G("Fit Names While Open: while open, a small bag widens whenever a section name or its title would be cut short, and narrows again once they fit. When off, it fits its names when it opens and when you let go of its resize grip."),
    } },
    { heading = L:G("Resizing") },
    { text = L:G("Drag the grips at a small bag's bottom corners to set its width. With Autosize on, its height bounces back to fit when you let go; turn Autosize off to set its height yourself.") },
    { setting = "nextIconScale", bag = "Backpack" },
    { setting = "nextAutosize", bag = "Backpack" },
  },
})

articles:Define({
  id = "next-chain", group = "next", design = "next",
  title = L:G("Chaining Bags"),
  summary = L:G("Putting your backpack and your bank, vendor, or guild bank side by side."),
  keywords = { L:G("chain"), L:G("side by side"), L:G("together"), L:G("couple"), L:G("join"), L:G("braid"), L:G("next to"),
    L:G("partner"), L:G("companion"),
    L:G("dock windows"), L:G("snap bags"), L:G("chain panels"),
    L:G("Chaining Bags Together")
  },
  questions = { L:G("How do I put my bank next to my backpack?"), L:G("How do I chain my bags?"),
    L:G("How do I separate my bags again?"),
    L:G("How do I put my backpack right next to my bank or vendor window?"),
    L:G("Why do my bags snap together when I open the bank?"),
    L:G("How do I unchain my backpack from the bank or merchant?"),
    L:G("Can I keep my small backpack and bank attached side by side?"),
    L:G("Why do my bank and backpack overlap instead of sitting next to each other?"),
    L:G("How does chaining work for full size panels?")
  },
  related = { "next-panels", "anchors" },
  body = {
    { text = L:G("Your backpack can sit beside its companion (the bank, the vendor, or the guild bank, whichever is open) instead of at the other edge of the screen. Their ribbons twist together where they meet.") },
    { heading = L:G("Full Size Bags") },
    { list = {
      L:G("Click a bag's title to fly it over beside the other bag."),
      L:G("Click the title of the bag that came over to send it back."),
      L:G("Click the title of the bag that stayed to move both to the other side of the screen."),
    } },
    { heading = L:G("Small Bags") },
    { text = L:G("Drag one bag by its title close beside the other and let go: it glides into place and they chain together. Drag the bag that stayed to move both. Drag the bag that joined to unchain them; drop it beside the other again to chain them again.") },
    { text = L:G("Each size remembers its own chain across sessions.") },
  },
})

articles:Define({
  id = "next-dragging", group = "next", design = "next",
  title = L:G("Dragging"),
  summary = L:G("Moving sections, filing items and reordering tabs by dragging them in BetterBags Next."),
  keywords = { L:G("drag"), L:G("drop"), L:G("move section"), L:G("reorder"), L:G("rearrange"), L:G("drag tab"),
    L:G("drag section"), L:G("drop item on header"),
    L:G("drag and drop"), L:G("reorder tabs"), L:G("file item"),
    L:G("grab a section")
  },
  questions = { L:G("How do I move a section?"), L:G("How do I move a category to another tab?"),
    L:G("How do I add an item to a category by dragging?"), L:G("How do I reorder my tabs?"),
    L:G("How do I drag an item into a different category?"),
    L:G("Can I drag sections to reorder them in BetterBags Next?"), L:G("How do I rearrange the tabs on my bag?"),
    L:G("How do I assign an item to a category by dragging it?"), L:G("Can I drag a category onto another tab?"),
    L:G("Why didn't dragging an item move it where I wanted?"),
    L:G("rearrange with the mouse"),
    L:G("Dragging Sections, Items and Tabs")
  },
  related = { "section-order", "groups", "move-category", "category-items" },
  body = {
    { heading = L:G("Sections") },
    { text = L:G("Drag a section by its title: the whole section comes with your cursor and the others slide out of its way. Drop it where you want it, and it stays there.") },
    { list = {
      L:G("Drop it on a tab to move the category to that group."),
      L:G("At the bank, drop a section on the other bag or one of its tabs to move all of its items there."),
      L:G("At a vendor, drop a section on the vendor to sell it: at once when it holds 12 items or fewer, or after a double click when it holds more."),
    } },
    { heading = L:G("Items") },
    { text = L:G("Drop an item on a section's title to add it to that category. If you drop it on the category it would be in anyway, it goes back there without being added.") },
    { heading = L:G("Tabs") },
    { text = L:G("Press and drag a tab up or down to put your tabs in the order you like in the backpack, the bank, the guild bank, and at a vendor. Your order is saved.") },
  },
})

articles:Define({
  id = "next-vendor", group = "next", design = "next",
  title = L:G("Vendor Window"),
  summary = L:G("Buying, selling, buyback and repairs in BetterBags Next's own vendor window."),
  keywords = { L:G("vendor"), L:G("merchant"), L:G("shop"), L:G("buy"), L:G("buyback"), L:G("repair"), L:G("sell junk"),
    L:G("vendor window"), L:G("TradeSkillMaster"), L:G("TSM"),
    L:G("sell trash"), L:G("auto repair"), L:G("merchant frame"), L:G("buyback tab"),
    L:G("The Vendor Window")
  },
  questions = { L:G("How do I buy something at a vendor?"), L:G("How do I buy back an item I sold?"),
    L:G("How do I repair my gear?"), L:G("How do I use the Blizzard vendor window?"),
    L:G("How do I sell gray vendor trash items at a merchant?"),
    L:G("How do I use the BetterBags Next vendor window?"),
    L:G("Can I switch back to Blizzard's default merchant window?"),
    L:G("Where is the buyback list or repair button at a vendor?"),
    L:G("How do I buy back something I accidentally sold?"),
    L:G("Why does the merchant window look different in BetterBags Next?")
  },
  settings = { "nextVendor" },
  pages = { "vendor", "vendor:general" },
  related = { "confirm-sale", "auto-sell", "tsm", "next-size" },
  body = {
    { text = L:G("With BetterBags Next, a vendor opens in a panel of its own, with what it sells sorted into your categories and each price under its item.") },
    { list = {
      L:G("Right-click an item to buy it, as in the game's own window. Shift-click an item that stacks to choose how many to buy with minus, plus, and Max, which fills in as many as you can afford, up to one stack."),
      L:G("The window's tabs hold what the vendor sells, Buyback, and Repair when the vendor can repair. The Buyback tab flashes when a sale lands in it."),
      L:G("The buttons at the top sell all your junk, repair your gear, and repair it with guild funds where you can."),
      L:G("Use Search Vendor at the top to find what the vendor sells."),
    } },
    { heading = L:G("Blizzard's Vendor") },
    { text = L:G("Turn off Enable Vendor Window on the Vendor page's General tab to use Blizzard's vendor window instead. The change takes effect right away when you are away from a vendor.") },
    { setting = "nextVendor", bag = "Vendor" },
    { see = "tsm" },
  },
})

articles:Define({
  id = "next-guildbank", group = "next", design = "next", shown = function() return addon.hasGuildBank end,
  title = L:G("Guild Bank"),
  summary = L:G("Your guild bank in BetterBags Next, its items in your categories."),
  keywords = { L:G("guild bank"), L:G("guild"), L:G("guild vault"), L:G("deposit gold"), L:G("withdraw gold"), L:G("guild tabs"),
    L:G("log"),
    L:G("guild stash"), L:G("gbank"),
    L:G("shared guild storage")
  },
  questions = { L:G("How do I use the guild bank?"), L:G("How do I withdraw gold from the guild bank?"),
    L:G("How do I use the Blizzard guild bank?"),
    L:G("Does BetterBags Next restyle the guild bank?"), L:G("Why does my guild bank show items in categories?"),
    L:G("How do I switch tabs or deposit gold in the guild bank?"),
    L:G("Can I use the default Blizzard guild bank window instead?"),
    L:G("How do I search or organize items in my guild bank?"), L:G("Why does the guild bank look like my bags?"),
    L:G("organize the guild bank"),
    L:G("The Guild Bank Window")
  },
  settings = { "nextGuildBank" },
  pages = { "guild", "guild:general" },
  related = { "next-chain", "groups" },
  body = {
    { text = L:G("With BetterBags Next, the guild bank opens in a panel of its own on the left. Its items appear in your categories, sorted and searched just like your own bags.") },
    { list = {
      L:G("The buttons at the top deposit and withdraw gold."),
      L:G("The Guild Bank settings page lays it out, sorts it and shows its items, as the Backpack page does for your backpack."),
    } },
    { text = L:G("Turn off Enable Guild Bank Window on the Guild Bank page's General tab to use Blizzard's guild bank window instead. The change takes effect right away when you are away from the guild bank.") },
    { setting = "nextGuildBank", bag = "Guild Bank" },
  },
})

articles:Define({
  id = "next-currencies", group = "next", design = "next",
  title = L:G("Currency Tracker"),
  summary = L:G("The currencies and items shown at the bottom of your backpack, and the tracker you drag out of it."),
  keywords = { L:G("currency"), L:G("currencies"), L:G("track"), L:G("tracker"), L:G("tokens"), L:G("gold"), L:G("cap"),
    L:G("reagent count"), L:G("watch"),
    L:G("currency bar"), L:G("tracked tokens"), L:G("gold tracker"), L:G("watch currency")
  },
  questions = { L:G("How do I track a currency?"), L:G("How do I show a currency in my backpack?"),
    L:G("How do I keep my currencies on screen?"), L:G("How do I track how many reagents I have?"),
    L:G("How do I track currencies or tokens at the bottom of my bag?"),
    L:G("How do I drag a currency tracker out onto my screen?"),
    L:G("Can I track an item count like potions or reagents at the bottom of my bag?"),
    L:G("How do I stop tracking a currency I don't care about anymore?"),
    L:G("Why aren't my currencies showing at the bottom of my backpack?"),
    L:G("How do I change how tracked currencies are displayed?"),
    L:G("Tracking Currencies and Items")
  },
  settings = { "nextCurrencyCapBars", "nextCurrencyGains", "nextCurrencyHideEmpty", "nextCurrencyItemsEverywhere",
    "nextCurrencyTracker", "nextCurrencyLayout", "nextCurrencyGrow", "nextCurrencyScale", "nextCurrencyBackground",
    "nextCurrencyHideInCombat" },
  pages = { "currencies", "currencies:tracked", "currencies:currencies", "currencies:items", "currencies:display" },
  related = { "next-fooddrink", "classic-currency" },
  body = {
    { text = L:G("The bottom of your backpack shows the currencies and items you track. Choose them on the Currencies page.") },
    { list = {
      L:G("Currencies tab: switch a currency on to track it."),
      L:G("Items tab: drop an item on it to track how many you have."),
      L:G("Tracked tab: what you track, in order. Drag an entry to move it, or remove it."),
    } },
    { heading = L:G("Tracker") },
    { text = L:G("Drag the tracked currencies out of the bottom of your backpack to keep them on screen with your bags closed. Drop the tracker back on your backpack to put it away.") },
    { heading = L:G("Display") },
    { list = {
      L:G("Cap Bars: a thin bar under each currency with a cap, filling toward the cap. It turns a warning color once the cap is reached: what you earn past it is wasted."),
      L:G("Show Gains: a number floating off a currency or item as you gain or spend it."),
      L:G("Hide What You Have None Of: currencies and items you have none of wait behind +N, and are left out of the tracker."),
      L:G("Count Items Everywhere: counts a tracked item in your bank and Warband bank too."),
      L:G("Tracker Layout, Tracker Grows, Tracker Scale, Tracker Background and Hide Tracker in Combat set how the tracker looks."),
    } },
    { open = { page = "currencies", text = L:G("Open the Currencies page") } },
  },
})

articles:Define({
  id = "next-fooddrink", group = "next", design = "next",
  title = L:G("Food & Drink"),
  summary = L:G("Two buttons that stay on screen with the food and the drink in your bags."),
  keywords = { L:G("food"), L:G("drink"), L:G("eat"), L:G("water"), L:G("mana"), L:G("bar"), L:G("food and drink"),
    L:G("eat button"), L:G("water button"), L:G("mage food"), L:G("consumable bar")
  },
  questions = { L:G("How do I eat from a button?"), L:G("How do I show my food and drink on screen?"),
    L:G("Why is my buff food not on the bar?"),
    L:G("What are the two food and drink buttons on my screen?"),
    L:G("How do I turn on or hide the Food and Drink bar?"), L:G("How do I move the food and drink buttons?"),
    L:G("Why is the wrong food or drink showing on the bar?"),
    L:G("Can I have a quick button to eat and drink without opening my bags?"),
    L:G("How do I choose which food or water the bar uses?"),
    L:G("The Food & Drink Bar")
  },
  settings = { "nextFoodDrinkBar", "nextFoodDrinkPick", "nextFoodDrinkLayout", "nextFoodDrinkGrow", "nextFoodDrinkScale",
    "nextFoodDrinkBackground", "nextFoodDrinkHideInCombat" },
  pages = { "fooddrink", "fooddrink:display" },
  related = { "next-currencies" },
  body = {
    { text = L:G("The Food & Drink bar puts two buttons on screen with your bags open or closed: one for the food and one for the drink in your bags. Right-click a button to eat or drink.") },
    { list = {
      L:G("Show Food & Drink Bar turns it on. It comes out of your backpack; drop it back on your backpack to put it away."),
      L:G("Pick chooses which food and drink it offers: the highest item level, or the lowest to use up old food first."),
      L:G("Buff food and drinks with alcohol are never offered."),
      L:G("Bar Layout, Bar Grows, Bar Scale, Bar Background and Hide Bar in Combat set how it looks."),
    } },
    { setting = "nextFoodDrinkBar" },
  },
})

articles:Define({
  id = "next-bank", group = "next", design = "next",
  title = L:G("Bank Panel"),
  summary = L:G("Your bank's panel: its groups, its Warbank, its own tabs and its buttons."),
  keywords = { L:G("bank"), L:G("warbank"), L:G("warband bank"), L:G("bank tabs"), L:G("teal"), L:G("deposit warbound"),
    L:G("purchase bank"), L:G("show bank tabs"),
    L:G("account bank"), L:G("reagent bank"),
    L:G("bank panel"), L:G("bank window buttons"),
    L:G("bank screen")
  },
  questions = { L:G("How do I see my bank's own tabs?"), L:G("Why is part of my bank teal?"),
    L:G("How do I sort my bank in BetterBags Next?"),
    L:G("How do I switch between my personal bank and my Warbank?"),
    L:G("Where are my bank bag tabs and deposit reagents button?"), L:G("How do I use category groups in the bank?"),
    L:G("Why can't I find my Warband bank in BetterBags Next?"),
    L:G("How do I deposit all reagent or warbound items into the bank?"),
    L:G("What do the buttons on the BetterBags Next bank panel do?"),
    L:G("What do the buttons on the bank do?"),
    L:G("How does the bank panel work?"),
    L:G("The Bank in BetterBags Next")
  },
  related = { "bank-basics", "warbank", "next-chain" },
  body = {
    { text = L:G("The bank opens in a panel on the left of the screen, with your groups as tabs down its side.") },
    { list = {
      L:G("Your Warbank groups come after your bank groups in teal, and the top of the panel turns teal while one is shown."),
      L:G("Show Bank Tabs switches between your groups and the bank's own tabs, where you can see each tab on its own, buy tabs, and right-click a tab to change its name, icon and deposit settings."),
      L:G("Deposit All Warbound Items puts every warbound item in your bags into the Warbank."),
      L:G("Right-click the bank's title to sort the bank, or the Warbank while it is shown."),
    } },
    { tip = L:G("In WoW: Forever, drop a bag on a bank tab to use it.") },
  },
})
