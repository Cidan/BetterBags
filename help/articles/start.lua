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
  summary = L:G("BetterBags overview and core features"),
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
    { text = L:G("BetterBags replaces Blizzard's bag windows and sorts items into sections by category. BetterBags replaces your backpack on every client and replaces your bank while Enable Bank Bags is on (the default). In BetterBags Next, while Enable Vendor Window and Enable Guild Bank Window are on (both on by default), BetterBags also replaces the vendor window and, on every client except Classic Era, the guild bank window.") },
    { heading = L:G("Core Features") },
    { list = {
      L:G("Sections and search: BetterBags groups items into titled category sections and provides a search bar or search box to find items by name, type, subtype, item level, rarity, and other properties."),
      L:G("Custom categories: Create categories on the Categories page by placing items under Added Items, writing a Search Rule, or combining both. You can also convert a Blizzard category to your own while your backpack shows a section of that Blizzard category in its category view."),
      L:G("Automation: On a category's Automation tab, Auto Sell, Destroy What Can't Be Sold, and Auto Deposit act on items in your categories, converted Blizzard categories, and plugin categories. Equipment set categories and unconverted Blizzard categories do not use these automation settings, and the Warbank target for Auto Deposit exists only on retail."),
      L:G("Groups: Group tabs organize categories into separate views. Enable Groups on the Backpack page's Layout tab (under Tabs, on by default) shows or hides only the backpack's group tabs; the bank's group tabs (on retail and WoW: Forever in the classic bags, and on every client in BetterBags Next) do not depend on Enable Groups."),
    } },
    { heading = L:G("Bag Designs") },
    { text = L:G("BetterBags has two designs: the classic bags and BetterBags Next. Switch between them with BetterBags Next (experimental) on the General page or with /bb next; switching works only out of combat and away from the bank, vendors, and the guild bank.") },
    { text = L:G("The classic bags draw one movable window per bag. BetterBags Next panels start as Small Bags, which are small, movable panels; the size button in the backpack's header (or the Small Bags entry in the bag button's menu under the Plain theme) switches them to Full Size Bags along the screen edges.") },
    { heading = L:G("Themes") },
    { text = L:G("Choose a theme on the Appearance page. The classic bags offer Default, Simple Dark, Dark, Parchment, and Slate, while BetterBags Next offers Default, Plain, Quiet, Parchment, Ember, Frost, Glitch, Halloween, Make It So, Papercraft, and Rainy Window. Both designs also offer the ElvUI theme while ElvUI is loaded and the Guild Wars 2 theme while GW2 UI is loaded.") },
    { heading = L:G("Help Page") },
    { text = L:G("Open the Help page from the settings window or by typing /bb help in chat. Type words after /bb help to open the Help page directly on the search results for those words.") },
  },
})

articles:Define({
  id = "opening", group = "start",
  title = L:G("Opening BetterBags"),
  summary = L:G("Opening bags, settings, help, and key bindings"),
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
    { text = L:G("BetterBags intercepts the game's default bag key bindings and bag bar buttons so your normal controls open and close your BetterBags backpack.") },
    { heading = L:G("Settings Window") },
    { text = L:G("You can open the Settings Window in several ways depending on your bag design and theme.") },
    { list = {
      L:G("Type /bb in chat from any bag design or theme."),
      L:G("In the classic bags, left-click the round bag button in the top-left corner of the bag and choose Open Options Screen. In the classic Guild Wars 2 theme, which has no round bag button, click the Open Settings action button or click Open Menu and choose Open Options Screen."),
      L:G("In BetterBags Next, click the settings button in the backpack header. When using the Plain theme in BetterBags Next, only Close stays in the header and all other header buttons move into the corner bag button's menu, where Open Options Screen is the last entry."),
    } },
    { text = L:G("Down the left side of the Settings Window, pages are listed under group headings, and pages with multiple views show tabs across the top. The search box at the top of the sidebar searches every active setting by name, description, keywords, or section title, displaying matching live controls by page and tab along with matching guides under Help Articles.") },
    { heading = L:G("General Page") },
    { text = L:G("The General page holds addon-wide settings on its single General tab, showing only options that apply to your active bag design and game client.") },
    { list = {
      L:G("Bags contains BetterBags Next (experimental) to switch bag designs, Show Blizzard Bag Button, and Clamp Bags to Screen, plus Enable Bag Fading and Animate Item Movement in the classic bags."),
      L:G("Interactions chooses whether your backpack uses Open and Close, Open Only, or Leave Alone when opening Trade, Bank, Vendor, Mailbox, Auction House, and client-supported windows including Warband Bank, Guild Bank, Void Storage, Scrapper, and Item Upgrade."),
      L:G("Search contains Enable In-Bag Search and, in the classic bags, Enable Enter to Make Category."),
      L:G("Items contains Upgrade Icon Provider, New Item Duration, and Enable Category Sell and Deposit."),
      L:G("What's New contains Show What's New on Login."),
    } },
    { heading = L:G("In-Game Help") },
    { text = L:G("Open this Help by selecting Help in the Settings Window sidebar, by clicking any article under Help Articles in a settings search, or by typing /bb help in chat.") },
    { heading = L:G("Key Bindings") },
    { text = L:G("Under the game's Key Bindings menu in the BetterBags section, BetterBags adds three bindable actions.") },
    { list = {
      L:G("Toggle Bags opens or closes the backpack only."),
      L:G("Search Bags toggles the search window over the backpack in the classic bags. In BetterBags Next, it opens the backpack and places the cursor in the search box, or clears focus from that box; it never closes the box, and no search box exists while Enable In-Bag Search is turned off."),
      L:G("Destroy Next Item destroys the entire stack in the next queued Backpack slot from categories with Destroy What Can't Be Sold enabled, skipping items merchants buy, items in an equipment set, refundable items, and items whose data or upgrade status is not yet known."),
    } },
    { open = { page = "general", text = L:G("Open General Settings") } },
    { see = "slash-commands" },
    { see = "settings-window" },
    { see = "bag-menu" },
  },
})

articles:Define({
  id = "designs", group = "start", featured = true,
  title = L:G("Bag Designs"),
  summary = L:G("Classic bags and BetterBags Next compared"),
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
    { text = L:G("BetterBags includes two bag designs: the classic bags and BetterBags Next.") },
    { heading = L:G("Design Differences") },
    { list = {
      L:G("The classic bags draw one movable window for each bag and leave merchants and the guild bank to Blizzard's default windows."),
      L:G("BetterBags Next draws panels that start as Small Bags you can move and resize anywhere, with a header button that switches them to Full Size Bags docked on the screen edges."),
      L:G("BetterBags Next opens merchants in its own panel while Enable Vendor Window is on, and opens the guild bank in its own panel on clients with a guild bank while Enable Guild Bank Window is on; both settings are enabled by default."),
    } },
    { heading = L:G("Switching Designs") },
    { text = L:G("Toggle BetterBags Next (experimental) on the General settings page, or type /bb next in chat to switch between designs.") },
    { text = L:G("Switching takes effect immediately without reloading the UI.") },
    { warning = L:G("BetterBags cannot switch designs during combat or while the bank, a vendor, or the guild bank is open.") },
    { heading = L:G("Design Settings") },
    { text = L:G("The settings window displays only the pages, tabs, and options that belong to the design currently in use.") },
    { setting = "nextEnabled" },
  },
})

articles:Define({
  id = "slash-commands", group = "start",
  title = L:G("Commands & Keys"),
  summary = L:G("BetterBags chat commands and key bindings"),
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
    { text = L:G("BetterBags registers three chat commands (/bb, /bbanchor, and /bbdb), with help, changelog, and next recognized after /bb, and adds three bindings under Key Bindings in the BetterBags section.") },
    { heading = L:G("Chat Commands") },
    { list = {
      L:G("/bb: Opens the Settings Window for the bag design currently in use."),
      L:G("/bb help: Opens the Help page in the Settings Window. Type words after /bb help (such as /bb help auto sell) to open directly on the search results for those words."),
      L:G("/bb changelog: Opens the window titled What's New in BetterBags."),
      L:G("/bb next: Switches between the classic bags and BetterBags Next. Switching works only out of combat and away from the bank, a vendor, and the guild bank."),
      L:G("/bbanchor: Activates and displays the classic backpack and bank anchors. In BetterBags Next, /bbanchor does nothing; instead, the backpack and bank panels have an anchor button while Small Bags is active (Full Size Bags, the vendor panel, and the guild bank panel have none). With the Plain theme, that anchor entry appears in the corner bag button's menu while Small Bags is active."),
      L:G("/bbdb: Toggles the debug window for inspecting item data and recording performance captures."),
    } },
    { heading = L:G("Key Bindings") },
    { text = L:G("Assign keys to these actions under Key Bindings in the BetterBags section:") },
    { list = {
      L:G("Toggle Bags: Opens or closes your backpack in either design."),
      L:G("Search Bags: In the classic bags, opens your backpack and toggles the overlay Search window above it. In BetterBags Next, opens your backpack and places the cursor in its search box (or clears focus if already focused), which exists only while Enable In-Bag Search is on."),
      L:G("Destroy Next Item: Destroys the whole stack in the next queued backpack slot from categories with Destroy What Can't Be Sold on (requires Auto Sell on). It takes only items no merchant buys, skips items in an equipment set, refundable items, and items whose data or upgrade status is not known yet, and refuses to run in combat or while your cursor holds an item."),
    } },
    { see = "opening" },
    { see = "anchors" },
    { see = "destroy" },
    { see = "performance" },
  },
})

articles:Define({
  id = "settings-window", group = "start",
  title = L:G("Settings Window"),
  summary = L:G("Settings window layout, search, and pages"),
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
    { heading = L:G("Window Layout") },
    { text = L:G("The Settings Window lists its pages down the left sidebar under group headings and displays the selected page on the right. Pages with more than one visible view show tabs across the top of the page, and the footer holds What's New and Done.") },
    { list = {
      L:G("Moving and closing: Drag the page header or the BetterBags brand at the top of the sidebar to move the window, which opens centered each time. Click Done, click the close button, or press Escape to close the window."),
      L:G("Plain theme: Every shipped theme except Plain shows the BetterBags brand in the sidebar. Plain shows no brand and places BetterBags in a title bar that moves the window instead, and Plain can draw this window in both bag designs."),
      L:G("Page lists: Opening Categories or Help slides that page's own list into the sidebar with All Settings at the top. Click All Settings or press Escape to return to the page you left, or to General if the window opened straight onto that list."),
    } },
    { heading = L:G("Settings Search") },
    { text = L:G("Every shipped theme places the search box at the top of the sidebar, under the brand in themes that show it. Typing in this box searches every visible setting for your active design and game client by name, description, keywords, or section title.") },
    { list = {
      L:G("Results by page and tab: Matches are grouped under headings such as Backpack > Items, or under the page name when only one tab is shown, each led by a link that opens that page and tab."),
      L:G("Live controls and pickers: Matching settings appear as live controls you can change directly from the results. Matches on a list or picker block, including Theme, Bag Theme, Settings Window Theme, Category Order, and the currency lists, show only the link to their tab."),
      L:G("Help results and clearing: Up to four matching guides appear at the bottom under Help Articles and open on the Help page. Clear the box or press Escape inside it to return to the page you were viewing."),
    } },
    { heading = L:G("General Page") },
    { text = L:G("The General page holds addon-wide settings on its single General tab, so no tab strip appears across the top.") },
    { list = {
      L:G("Bags: BetterBags Next (experimental) switches designs, Show Blizzard Bag Button controls the game's bag button, and Clamp Bags to Screen keeps movable windows inside the screen. In the classic bags, this section also includes Enable Bag Fading and Animate Item Movement."),
      L:G("Interactions: Each dropdown chooses Open and Close, Open Only, or Leave Alone for your backpack when opening another window. Trade, Bank, Vendor, Mailbox, and Auction House appear on every client; Warband Bank and Scrapper appear on retail; Guild Bank appears on every client except Classic Era; Void Storage appears on Mists of Pandaria Classic and Cataclysm Classic; Item Upgrade appears on retail and Mists of Pandaria Classic, not on WoW: Forever."),
      L:G("Search: Enable In-Bag Search turns on the search field inside your bags, and Enable Enter to Make Category lets pressing Enter on a classic bag search create a category."),
      L:G("Items and What's New: Items holds Upgrade Icon Provider, New Item Duration, and Enable Category Sell and Deposit, and What's New holds Show What's New on Login."),
    } },
    { heading = L:G("Bag Pages") },
    { text = L:G("Under the Bags heading, each bag has its own page for layout, items, automatic categories, and category order, plus a Size tab in BetterBags Next.") },
    { list = {
      L:G("Backpack: Backpack has no General tab because it is always active. Its Enable Groups setting appears only on Backpack, under Layout."),
      L:G("Bank: Bank starts with a General tab for Enable Bank Bags and, on retail, the Warbank section with Include Tradeable Reagents."),
      L:G("Guild Bank: The Guild Bank page exists only in BetterBags Next on clients with a guild bank (every client except Classic Era), starting with a General tab for Enable Guild Bank Window."),
      L:G("Vendor: The Vendor page exists only in BetterBags Next and has only General (for Enable Vendor Window) and Size tabs, because Vendor is not a bag that categories are assigned to; the vendor window lays merchant items out in your backpack's categories."),
    } },
    { heading = L:G("Missing Settings") },
    { text = L:G("The Settings Window displays only pages, tabs, sections, and settings that apply to the bag design in use and your game client.") },
    { list = {
      L:G("Classic-only options: Enable Bag Fading, Animate Item Movement, Enable Enter to Make Category, Appearance > Bag Theme and Settings Window Theme, the Currency page, and each bag's Layout > Window and Layout > Sections (Show Full Section Names) appear only while using the classic bags."),
      L:G("BetterBags Next-only options: The Guild Bank, Vendor, Currencies, and Food & Drink pages, Appearance > Animation, each bag's Size tab, and BetterBags Next's Layout > Sections (Section Columns, Compact Sections, Gap Between Sections, Fill Order, Wide Sections Span Columns, Wide Column Limit) appear only while using BetterBags Next. Appearance > Glass appears only in BetterBags Next while a glass theme is active or previewed."),
      L:G("Client differences: Show Keystone Level on Backpack and Bank appears only on retail and WoW: Forever. With the classic bags, the Currency page exists on retail, WoW: Forever, and Mists of Pandaria Classic, not on Classic Era or The Burning Crusade Anniversary."),
    } },
    { open = { page = "general", text = L:G("Open General Settings") } },
    { see = "opening" },
    { see = "designs" },
    { see = "profiles" },
  },
})

articles:Define({
  id = "whats-new", group = "start",
  title = L:G("What's New"),
  summary = L:G("Release notes at login and on demand"),
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
    { text = L:G("The What's New in BetterBags window displays release notes for your game client across both bag designs.") },
    { heading = L:G("Automatic Opening") },
    { text = L:G("BetterBags opens the window automatically once per session, after your first loading screen, when you log in after an update that contains changes you have not seen yet. Closing the window by clicking Okay!, clicking its close button, or pressing Escape marks all bundled releases as seen so it does not reopen for those releases on your next login.") },
    { heading = L:G("Release List") },
    { text = L:G("The window lists every bundled release that applies to your game client, sorted newest first. Releases you have not seen yet carry a New badge beside their date, and alpha builds note Alpha beside the date.") },
    { text = L:G("Under each release header, entries appear in the order the release lists them rather than grouped by category, with each entry showing its own category tag such as New, Improved, Fixed, or Changed.") },
    { heading = L:G("Opening Manually") },
    { text = L:G("You can reopen the window at any time to review past releases.") },
    { list = {
      L:G("Type /bb changelog in chat."),
      L:G("Click What's New in the bottom-left footer of the Settings Window."),
      L:G("In the classic bags, left-click the round bag button and click What's New in the menu (if you use the classic Guild Wars 2 theme, click its Open Menu action button instead)."),
    } },
    { heading = L:G("Disabling Auto-Open") },
    { text = L:G("Turn off Show What's New on Login on the General page to stop the window from opening automatically after updates, or check Don't show me this again at the bottom left of the What's New window itself. Both controls change the same account-wide setting.") },
    { setting = "changelogOnLogin" },
    { see = "slash-commands" },
  },
})
