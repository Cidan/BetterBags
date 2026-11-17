local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class HelpArticles: AceModule
local articles = addon:GetModule('HelpArticles')

articles:Group({ id = "start", title = L:G("Getting Started") })

articles:Define({
  id = "welcome", group = "start", featured = true,
  title = L:G("Welcome"),
  summary = L:G("What BetterBags does with your bags and where to go next."),
  keywords = { L:G("introduction"), L:G("overview"), L:G("getting started"), L:G("basics"), L:G("new"), L:G("bags"),
    L:G("addon overview"), L:G("new user"), L:G("bag addon"),
    L:G("addon"), L:G("what it does"),
    L:G("quick tour"),
    L:G("Welcome to BetterBags")
  },
  questions = { L:G("What does BetterBags do?"), L:G("How do I use BetterBags?"), L:G("Where do I start?"),
    L:G("How do I get started with BetterBags?"), L:G("Where should I start after installing?"),
    L:G("What features does this bag addon have?"), L:G("I just installed BetterBags and everything looks different"),
    L:G("What is the difference between the two bag styles?"),
    L:G("What does this addon do?")
  },
  related = { "designs", "opening", "sections", "categories-intro", "search-basics" },
  body = {
    { text = L:G("BetterBags replaces your bags with one window that sorts your items into sections: armor in one, potions in another, and quest items in a third. Each section is a category, and you decide which categories you have, what goes in them, and what order they appear in.") },
    { heading = L:G("Features") },
    { list = {
      L:G("Find any item by typing in the search box, from its name to its item level, stats, or price."),
      L:G("Make your own categories, by hand or from a search that keeps finding new items for you."),
      L:G("Sell your junk, destroy what no merchant buys, and automatically send materials to your bank."),
      L:G("Put categories on their own tabs, called groups, to keep your bags short."),
      L:G("Pick a theme, from Blizzard's look to glass, frost, and paper."),
    } },
    { heading = L:G("Two Designs") },
    { text = L:G("BetterBags has two designs for your bags. The classic bags give you a window you can move and resize. BetterBags Next is a newer, experimental design with panels that slide in from the edges of the screen. Both use the same categories and settings.") },
    { see = "designs" },
    { tip = L:G("Type /bb help in chat to open this help from anywhere, or /bb help followed by a few words to search it.") },
  },
})

articles:Define({
  id = "opening", group = "start",
  title = L:G("Bags and Settings"),
  summary = L:G("How to open your bags, the settings window, and this help."),
  keywords = { L:G("open"), L:G("toggle"), L:G("settings"), L:G("options"), L:G("config"), L:G("menu"), L:G("bag button"),
    L:G("key binding"), L:G("hotkey"),
    L:G("open settings"), L:G("keybinds"), L:G("help window"), L:G("toggle bags")
  },
  questions = { L:G("How do I open the settings?"), L:G("Where are the options?"), L:G("How do I open my bags?"),
    L:G("Is there a key to open my bags?"),
    L:G("How do I open BetterBags settings?"), L:G("How do I get back to this help page?"),
    L:G("What key opens my bags?"), L:G("How do I bind a key to open my bags?"),
    L:G("My bags won't open when I press B"), L:G("Where is the config menu?"),
    L:G("Opening Your Bags and the Settings")
  },
  pages = { "general" },
  related = { "slash-commands", "settings-window", "bag-menu" },
  body = {
    { text = L:G("Open your bags the way you always do: with your bag key or by clicking a bag on your action bar. BetterBags opens in their place.") },
    { heading = L:G("Settings") },
    { list = {
      L:G("Type /bb in chat."),
      L:G("In the classic bags, click the bag button at the top left of your backpack and choose Open Options Screen."),
      L:G("In BetterBags Next, click the settings button at the top of your backpack."),
    } },
    { text = L:G("The settings window lists pages down the left side. Search for a setting by name using the box at the top of that list.") },
    { heading = L:G("Help") },
    { text = L:G("Choose Help at the bottom of the settings window's list of pages, or type /bb help in chat. Add a few words after /bb help to search the help at once.") },
    { heading = L:G("Key Bindings") },
    { text = L:G("BetterBags adds its own key bindings under Key Bindings in the BetterBags section. Toggle Bags opens and closes your bags, Search Bags opens the search box, and Destroy Next Item destroys the next item a category is set to destroy. In BetterBags Next, Search Bags needs Enable In-Bag Search on.") },
    { see = "slash-commands" },
  },
})

articles:Define({
  id = "designs", group = "start", featured = true,
  title = L:G("Next or Classic"),
  summary = L:G("The two designs for your bags and how to switch between them."),
  keywords = { L:G("BetterBags Next"), L:G("next"), L:G("classic"), L:G("experimental"), L:G("new design"),
    L:G("old bags"), L:G("switch"), L:G("panel"), L:G("redesign"),
    L:G("switch design"), L:G("Next mode"), L:G("classic layout"), L:G("change UI"),
    L:G("visual style"), L:G("two styles"), L:G("old look")
  },
  questions = { L:G("What is BetterBags Next?"), L:G("How do I turn on BetterBags Next?"),
    L:G("How do I go back to the old bags?"), L:G("Why do my bags slide in from the side?"),
    L:G("How do I switch between BetterBags Next and classic?"),
    L:G("Why do my bags look different from screenshots?"), L:G("Can I go back to the old BetterBags look?"),
    L:G("What is BetterBags Next compared to classic bags?"), L:G("How do I disable the new bag design?"),
    L:G("BetterBags Next and the Classic Bags")
  },
  settings = { "nextEnabled" },
  related = { "next-panels", "classic-window", "slash-commands" },
  body = {
    { text = L:G("BetterBags has two designs. Both sort your items into the same categories and use the same settings, though they look and move differently.") },
    { heading = L:G("Classic Bags") },
    { text = L:G("The classic bags use one window for your backpack and one for your bank, which you can move, anchor, and resize yourself. A bag menu in the top-left corner holds most of what you can do.") },
    { heading = L:G("BetterBags Next") },
    { text = L:G("BetterBags Next is an experimental design. Your backpack is a panel that slides in from the right edge of the screen, and your bank mirrors it on the left, with your groups as tabs down the side. Vendors and the guild bank open in their own panels with their items in your categories. Panels start small and movable, and a button in the backpack's header makes them full height.") },
    { heading = L:G("Switching") },
    { steps = {
      L:G("Open the settings with /bb."),
      L:G("On the General page, turn BetterBags Next (experimental) on or off."),
    } },
    { setting = "nextEnabled" },
    { text = L:G("You can also type /bb next to switch. The switch happens immediately, but not while you are in combat, at the bank, or at a vendor.") },
    { text = L:G("The settings window shows only the settings for the design you are using, so some settings appear in only one design.") },
  },
})

articles:Define({
  id = "slash-commands", group = "start",
  title = L:G("Commands and Keys"),
  summary = L:G("Every chat command and key binding BetterBags adds."),
  keywords = { L:G("slash"), L:G("command"), L:G("chat"), L:G("/bb"), L:G("bbanchor"), L:G("bbdb"), L:G("keybind"),
    L:G("key binding"), L:G("hotkey"), L:G("shortcut"),
    L:G("chat commands"), L:G("slash command"), L:G("hotkeys"), L:G("bb command")
  },
  questions = { L:G("What slash commands are there?"), L:G("How do I bind a key to search my bags?"),
    L:G("What does /bb do?"),
    L:G("What are all the BetterBags slash commands?"), L:G("How do I open settings from chat?"),
    L:G("What key bindings does BetterBags add?"), L:G("Is there a chat command to open my bank or bags?"),
    L:G("How do I set a hotkey for BetterBags?"), L:G("Why doesn't /bags work?"),
    L:G("Slash Commands and Key Bindings")
  },
  related = { "opening", "performance", "anchors", "destroy" },
  body = {
    { heading = L:G("Chat Commands") },
    { list = {
      L:G("/bb opens the settings window."),
      L:G("/bb help opens this help. Add words after it to search, like /bb help auto sell."),
      L:G("/bb changelog opens What's New."),
      L:G("/bb next switches between BetterBags Next and the classic bags."),
      L:G("/bbanchor shows the anchors for the classic bags so you can position them to the pixel."),
      L:G("/bbdb opens the debug window, where you can record what slows your game down."),
    } },
    { heading = L:G("Key Bindings") },
    { text = L:G("Under Key Bindings in the game's options, the BetterBags section has three bindings:") },
    { list = {
      L:G("Toggle Bags opens and closes your bags."),
      L:G("Search Bags opens the search box. In BetterBags Next, it needs Enable In-Bag Search on."),
      L:G("Destroy Next Item destroys the next item a category is set to destroy, one per key press."),
    } },
  },
})

articles:Define({
  id = "settings-window", group = "start",
  title = L:G("Finding Settings"),
  summary = L:G("How the settings window is laid out and how to find a setting."),
  keywords = { L:G("settings window"), L:G("options"), L:G("find a setting"), L:G("search settings"), L:G("pages"),
    L:G("tabs"), L:G("sidebar"),
    L:G("find setting"), L:G("search options"), L:G("config layout"), L:G("bag options"),
    L:G("missing setting")
  },
  questions = { L:G("Where is the setting for...?"), L:G("How do I find a setting?"), L:G("Why can't I find a setting?"),
    L:G("How do I find a setting in the options window?"), L:G("Can I search for a setting by name?"),
    L:G("Where are the settings for just my bank or backpack?"), L:G("Why can't I find an option I saw earlier?"),
    L:G("How is the settings menu organized?"), L:G("Where did a classic setting go in BetterBags Next?"),
    L:G("Where did a setting go?"), L:G("I can't find a toggle"),
    L:G("Finding Your Way in the Settings")
  },
  pages = { "general", "general:main" },
  related = { "opening", "designs", "profiles" },
  body = {
    { text = L:G("The settings window lists pages down the left side under these headings: BetterBags, Bags, Profiles, Integrations, and Help. A page with more than one tab shows its tabs across the top.") },
    { heading = L:G("Settings Search") },
    { text = L:G("Type in the box at the top of the page list. Every setting whose name or description matches appears live under its page and tab, with a link to that page. Matching help articles appear as well.") },
    { heading = L:G("Bag Settings") },
    { text = L:G("The Backpack and Bank pages, and with BetterBags Next the Guild Bank and Vendor pages, hold each bag's own settings, such as how it lays out its sections, sorts its items, and shows its item buttons. Changing one bag leaves the others as they are.") },
    { heading = L:G("Missing Settings") },
    { text = L:G("The window shows only the settings for the design you are using. A BetterBags Next setting does not appear while you are using the classic bags, and the other way around.") },
    { open = { page = "general", text = L:G("Open the General page") } },
  },
})

articles:Define({
  id = "whats-new", group = "start",
  title = L:G("What's New"),
  summary = L:G("The list of changes in each BetterBags update."),
  keywords = { L:G("changelog"), L:G("what's new"), L:G("updates"), L:G("patch notes"), L:G("release notes"), L:G("version"),
    L:G("recent updates"), L:G("version changes"),
    L:G("bug fixes"), L:G("new features")
  },
  questions = { L:G("What changed in the last update?"), L:G("How do I stop the changelog from opening?"),
    L:G("What changed in the latest BetterBags update?"), L:G("Where can I read the patch notes?"),
    L:G("How do I see what's new after an update?"), L:G("What new features were added recently?"),
    L:G("Can I check the changelog inside the game?"), L:G("Did an update change how my bags work?"),
    L:G("What was added?")
  },
  settings = { "changelogOnLogin" },
  related = { "slash-commands" },
  body = {
    { text = L:G("After an update, BetterBags shows What's New when you log in: the changes for your version of the game, newest first, with the updates you have not seen marked New.") },
    { list = {
      L:G("Open it anytime with /bb changelog, What's New in the bag menu, or What's New at the bottom of the settings window."),
      L:G("To stop it from opening on its own, check Don't show me this again in its window, or turn off Show What's New on Login."),
    } },
    { setting = "changelogOnLogin" },
  },
})
