local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class HelpArticles: AceModule
local articles = addon:GetModule('HelpArticles')

articles:Group({ id = "troubleshooting", title = L:G("Troubleshooting") })

articles:Define({
  id = "wrong-category", group = "troubleshooting", featured = true,
  title = L:G("Wrong Category"),
  summary = L:G("Checks for misplaced items"),
  keywords = { L:G("wrong category"), L:G("missing item"), L:G("not showing"), L:G("item missing"), L:G("wrong section"),
    L:G("can't find item"), L:G("category not working"),
    L:G("misplaced item"), L:G("item wrong section"), L:G("fix item category"),
    L:G("wrong place"), L:G("unexpected section"),
    L:G("reassign an item")
  },
  questions = { L:G("Why is my item not in my category?"), L:G("Why are some of my items missing from my custom category?"),
    L:G("Where did my item go?"), L:G("Why doesn't my search category show anything?"),
    L:G("Why is an item in the wrong category?"), L:G("How do I move an item out of a category it shouldn't be in?"),
    L:G("Why did my gear or crafting mat go into the wrong section?"),
    L:G("How do I find out what put an item into a specific category?"),
    L:G("An item keeps landing in the wrong group, how do I fix it?"),
    L:G("Why isn't my custom category catching an item that is in another section?"),
    L:G("Why is my item in the wrong place?"),
    L:G("landing in the wrong section"),
    L:G("An Item Is in the Wrong Category")
  },
  related = { "categories-intro", "category-ignored", "category-settings", "category-rule" },
  body = {
    { heading = L:G("Recent Items") },
    { text = L:G("First check whether you are in a bag-by-bag view (Show Bags in the classic bags, or Show Blizzard Bags, Show Bank Tabs, and a single guild bank tab in BetterBags Next), which groups items by physical bag or tab instead of category. In a category view, newly acquired items go to Recent Items before any other category while Recent Items is enabled on that bag's Categories tab.") },
    { text = L:G("An item leaves Recent Items when you close the bag after New Item Duration has passed, when you sort the bag, when you move the item to another slot (on the next update, even while the bag is open), or at once when the category assigned to the item has Skip Recent Items enabled.") },
    { heading = L:G("Category Order") },
    { text = L:G("Each item appears in one section only. When a Search Rule category, a plugin category, or an Equipment Set category (on retail, WoW: Forever, and Mists of Pandaria Classic, while that bag's Equipment Set switch is on) all match the same item, the category higher in the list on the Categories page applies. A new category starts at the top of that list.") },
    { text = L:G("An item you add by hand to one of your own categories stays in that category regardless of list order, unless that category ignores the item or does not apply to that bag.") },
    { heading = L:G("Added Items") },
    { text = L:G("An item can belong to only one category's Added Items; adding an item to another category removes it from the previous category's Added Items. On the Categories page, open the category's Added Items tab: if the item appears faded with the note Shows in <section> instead., another category such as Recent Items is claiming it.") },
    { text = L:G("Also check the Group By dropdown on the category's Settings tab (None, Type, Subtype, or Expansion, with the label reading Subtype). When Group By is set to anything other than None, even hand-added items split into sub-sections. Group By is hidden for plugin categories and categories made from a Blizzard Category.") },
    { heading = L:G("Ignored Items") },
    { text = L:G("Open the category's Ignored Items tab on the Categories page. Any item listed on Ignored Items is never assigned to that category from Added Items, a plugin, an Equipment Set, or a Search Rule. If an item in Added Items is also ignored, that entry appears faded with the note Ignored in this category.") },
    { heading = L:G("Bag Visibility") },
    { text = L:G("On the category's Settings tab, check Used In and Hide In. Turn on Used In for every bag where you want the category to apply; the Guild Bank switch under Used In exists only in BetterBags Next on clients with a guild bank. If a bag is off under Used In, items in that bag pass to the next matching category or their Blizzard Category.") },
    { text = L:G("Hide In (available only while Used In is on for that bag) hides the category's items in that bag's category view while displaying a hidden count in the footer. Hidden items still appear in Recent Items while new and in the bag-by-bag views: Show Bags, Show Blizzard Bags, Show Bank Tabs, and a single guild bank tab.") },
    { heading = L:G("Search Rule") },
    { text = L:G("Open the category's Search Rule tab and inspect the live Search Results preview. On text fields other than tooltip, = matches values that start with your text (ignoring case) rather than anywhere inside; use %= to match anywhere in those fields. On the tooltip field, = and != match anywhere in the text.") },
    { text = L:G("Item type, subtype, slot, upgrade track, stat, and rarity names in a rule must match the game client's words in its own language.") },
    { heading = L:G("Category Field") },
    { text = L:G("Inside a Search Rule, the category field never matches another Search Rule category or Recent Items. Instead, category matches the item's own category before search rules and Recent Items run: a category containing the item in Added Items, an Equipment Set category, a plugin category, or the item's Blizzard Category.") },
    { text = L:G("A gear item's Blizzard Category comes from the filters on that bag's Categories tab, in the client's language. Poor-quality items go to Junk before Equipment Location is checked. Otherwise, gear uses its equipment slot name (such as Head or Chest) while Equipment Location is on (the default). With Equipment Location off, the item type shows only while Type is on (the default), and Expansion (off by default) adds the expansion. With Trade Skill on, a trade good's Blizzard Category is its trade skill name (plus the expansion when Expansion is on) without its type.") },
    { example = "category = 'Junk'", text = L:G("On an English client, finds poor-quality items that no hand-added, plugin, or equipment set category already includes, even while those items show in Recent Items.") },
    { open = { page = "categories", tab = "settings", text = L:G("Open Category Settings") } },
    { open = { page = "categories", tab = "rule", text = L:G("Open Search Rules") } },
    { see = "categories-intro" },
    { see = "category-ignored" },
    { see = "category-settings" },
    { see = "category-rule" },
  },
})

articles:Define({
  id = "category-deleted-returns", group = "troubleshooting",
  title = L:G("Deleted Categories"),
  summary = L:G("Addon categories that reappear after reload"),
  keywords = { L:G("deleted category"), L:G("comes back"), L:G("reappears"), L:G("can't delete"), L:G("plugin category"),
    L:G("deleted category returns"), L:G("category keeps returning"), L:G("can't delete category"),
    L:G("reappearing section"),
    L:G("keeps coming back")
  },
  questions = { L:G("Why does a category reappear after I delete it?"), L:G("How do I get rid of a plugin's category?"),
    L:G("Why does a category I deleted keep coming back after I reload?"),
    L:G("How do I permanently stop a deleted category from reappearing?"),
    L:G("I deleted a section and now it is back again, why?"),
    L:G("Why can't I permanently remove a plugin or Blizzard category?"),
    L:G("How do I get rid of an unwanted category if deleting it doesn't stick?"),
    L:G("Why did a deleted category recreate itself when I logged back in?"),
    L:G("A Deleted Category Comes Back")
  },
  related = { "category-plugins", "plugins" },
  body = {
    { heading = L:G("Addon Categories") },
    { text = L:G("Another addon or BetterBags plugin runs its setup again each time you log in or run /reload. On the Categories page, BetterBags displays Delete only for categories saved as yours, and does not display Delete for plugin categories labeled Made by a plugin. If another addon creates a category saved as yours, deleting that category removes it only until the next /reload recreates it.") },
    { heading = L:G("Category Settings") },
    { text = L:G("Instead of deleting a category made by another addon, turn off the bags where you do not want that category to appear under Used In on its Settings tab.") },
    { steps = {
      L:G("Open the Categories page in the Settings Window and select the category."),
      L:G("Open the Settings tab."),
      L:G("Under Used In, turn off Backpack, Bank, and Guild Bank for the bags where you do not want the category to include items."),
    } },
    { text = L:G("The Guild Bank switch under Used In appears only with BetterBags Next on clients with a guild bank (every client except Classic Era).") },
    { text = L:G("When a plugin registers its categories again after /reload, BetterBags preserves the Used In bags you chose for them. When another addon recreates a category saved as yours, BetterBags preserves the Used In bags you chose only when that addon passes no bags of its own.") },
    { heading = L:G("Plugin Pages") },
    { text = L:G("A plugin may also add its own page under Integrations in the Settings Window, built from its own options. Whether that page provides a way to turn off the plugin's categories depends on the plugin.") },
    { open = { page = "categories", tab = "settings", text = L:G("Open Category Settings") } },
    { see = "category-plugins" },
    { see = "plugins" },
  },
})

articles:Define({
  id = "bags-not-opening", group = "troubleshooting",
  title = L:G("Blizzard Windows"),
  summary = L:G("Default Blizzard windows instead of BetterBags"),
  keywords = { L:G("blizzard bags"), L:G("default bags"), L:G("not working"), L:G("old bags"), L:G("bank not working"),
    L:G("vendor window"), L:G("guild bank window"),
    L:G("bags not opening"), L:G("Blizzard bags showing"), L:G("BetterBags not working"), L:G("default bags open"),
    L:G("still default")
  },
  questions = { L:G("Why do I see Blizzard's bags?"), L:G("Why is my bank the default one?"),
    L:G("Why is the vendor window Blizzard's?"),
    L:G("Why do Blizzard's default bags open instead of BetterBags?"),
    L:G("BetterBags stopped opening when I press B, how do I fix it?"),
    L:G("Why is my bank showing the standard game window instead of BetterBags?"),
    L:G("Could another addon like ElvUI or Bagnon be overriding BetterBags?"),
    L:G("How do I get BetterBags to open again when I click my bag bar?"),
    L:G("Why do my bags look like the normal WoW bags?"),
    L:G("default bags still show"),
    L:G("My Bags Look Like Blizzard's")
  },
  related = { "bank-basics", "next-vendor", "next-guildbank", "show-bags" },
  body = {
    { heading = L:G("Bank Window") },
    { text = L:G("When Blizzard's default bank window opens instead of BetterBags in either the classic bags or BetterBags Next, Enable Bank Bags is turned off.") },
    { text = L:G("Open the Bank page in the Settings Window, go to the General tab, and turn on Enable Bank Bags under Bank Window. BetterBags prompts you to reload the UI, and the BetterBags bank window appears after the reload.") },
    { heading = L:G("Vendor Window") },
    { text = L:G("In the classic bags, BetterBags does not replace the default Blizzard vendor window. In BetterBags Next, Blizzard's vendor window appears instead of BetterBags Next's panel when Enable Vendor Window is off.") },
    { text = L:G("Open Vendor > General in BetterBags Next and turn on Enable Vendor Window under Vendor Window. You must close any open vendor before switching, and the change takes effect immediately.") },
    { heading = L:G("Guild Bank") },
    { text = L:G("In the classic bags, BetterBags does not replace Blizzard's guild bank window. In BetterBags Next on game clients that have a guild bank, Blizzard's window appears instead when Enable Guild Bank Window is off.") },
    { text = L:G("Open Guild Bank > General in BetterBags Next and turn on Enable Guild Bank Window under Guild Bank Window while away from a guild bank. The change takes effect immediately without a reload.") },
    { heading = L:G("Bag View") },
    { text = L:G("If your BetterBags backpack or classic bank opens showing individual bags in slot order instead of your category sections, the physical bag view is turned on. That view stays active across reloads until you turn it off, and cannot be toggled during combat.") },
    { list = {
      L:G("In the classic bags, click the round bag button in the top-left corner and uncheck Show Bags, or click the Show Bags action button if your theme displays one."),
      L:G("In BetterBags Next, click the Show Blizzard Bags button in the backpack header, whose tooltip reads Show Categories while the bag view is active, to return to your categories."),
    } },
    { setting = "enableBankBags", bag = "Bank" },
    { see = "bank-basics" },
    { see = "next-vendor" },
    { see = "next-guildbank" },
    { see = "show-bags" },
  },
})

articles:Define({
  id = "performance", group = "troubleshooting",
  title = L:G("Performance Captures"),
  summary = L:G("Profiler captures for reporting game stutters"),
  keywords = { L:G("lag"), L:G("stutter"), L:G("slow"), L:G("fps"), L:G("performance"), L:G("freeze"), L:G("bbdb"),
    L:G("profiler"), L:G("capture"), L:G("bug report"),
    L:G("lag spikes"), L:G("FPS drop"), L:G("stutter report"), L:G("profiler capture")
  },
  questions = { L:G("Why does my game stutter when I open my bags?"), L:G("How do I report a performance problem?"),
    L:G("How do I record what BetterBags is doing?"),
    L:G("How do I record a lag spike or FPS drop to send in a bug report?"),
    L:G("My game stutters when I open my bags or loot items, how do I report it?"),
    L:G("How do I capture performance data when BetterBags slows down?"),
    L:G("Where is the profiler tool to record a slowdown?"),
    L:G("What should I attach when reporting a BetterBags freeze or hitch?"),
    L:G("How do I check what BetterBags was doing during a frame drop?"),
    L:G("Reporting Stutters and Slowdowns")
  },
  related = { "slash-commands", "effects" },
  body = {
    { heading = L:G("Profiler State") },
    { text = L:G("BetterBags includes a built-in profiler for both the classic bags and BetterBags Next. Capturing is always off by default and costs nothing unless you start a capture, and BetterBags never leaves a capture running across reloads on its own.") },
    { heading = L:G("Recording Stutters") },
    { text = L:G("Use the Performance tab in the debug window to capture a stutter while playing or during a reload.") },
    { steps = {
      L:G("Type /bbdb in chat to open the debug window, then click the Performance tab."),
      L:G("Click Start Capture, perform the actions that cause the stutter such as opening your bags, looting, or casting abilities, and then click Stop Capture."),
      L:G("To capture a login or reload instead, check Capture next reload, type /reload or relaunch the game, wait for the slowdown to finish, and click Stop Capture."),
      L:G("Type /reload or log out so World of Warcraft writes the saved capture to disk before you attach the file to a bug report."),
    } },
    { tip = L:G("Capture next reload applies to a single load and turns itself off as soon as that load begins. If you log out while a capture is still running, BetterBags stops and saves the session automatically.") },
    { heading = L:G("Saved Sessions") },
    { text = L:G("Each completed capture appears under Saved Sessions on the left of the Performance tab, newest first, up to 10 sessions by default. Select a session to view its flame graph, function timings, worst frames, call trace, timeline, and summary.") },
    { text = L:G("World of Warcraft writes BetterBags' profiler data to WTF/Account/<ACCOUNT>/SavedVariables/BetterBags.lua when you /reload or log out. Attach that file to your report, and use Delete, Delete All, Remove Trace, or All Traces on the Performance tab to clear old data when finished.") },
    { see = "slash-commands" },
    { see = "effects" },
  },
})
