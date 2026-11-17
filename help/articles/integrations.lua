local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class HelpArticles: AceModule
local articles = addon:GetModule('HelpArticles')

articles:Group({ id = "integrations", title = L:G("Integrations") })

articles:Define({
  id = "quickfind", group = "integrations",
  title = L:G("QuickFind"),
  summary = L:G("Searching BetterBags items from the QuickFind addon"),
  keywords = { L:G("QuickFind"), L:G("quick find"), L:G("spotlight"), L:G("launcher"),
    L:G("QuickFind search"), L:G("QuickFind integration"), L:G("search bags QuickFind"),
    L:G("item finder"), L:G("finder addon")
  },
  questions = { L:G("How do I find my items with QuickFind?"), L:G("How do I turn off the QuickFind integration?"),
    L:G("How does QuickFind work with BetterBags?"), L:G("Can I use the QuickFind addon to search my bags and bank?"),
    L:G("Why aren't BetterBags items showing up in QuickFind?"),
    L:G("How do I find items across my bags using QuickFind?"),
    L:G("Does BetterBags support QuickFind out of the box?"),
    L:G("Can QuickFind highlight or locate items inside BetterBags?")
  },
  settings = { "quickFind" },
  pages = { "quickfind", "quickfind:main" },
  related = { "search-basics" },
  body = {
    { text = L:G("When the QuickFind addon is loaded, BetterBags registers your items with QuickFind in both bag designs on every game client.") },
    { heading = L:G("Registered Items") },
    { text = L:G("BetterBags adds your backpack items to QuickFind at all times. Bank items appear in QuickFind only while the bank is open in that session, because closing the bank clears BetterBags' bank item data.") },
    { text = L:G("Each item entry includes these searchable tags in QuickFind:") },
    { list = {
      L:G("The item's type and subtype."),
      L:G("The section where the item currently displays, such as Recent Items for a new item or the bag's name in Show Bags or Show Blizzard Bags."),
      L:G("The game's internal slot code, such as INVTYPE_HEAD."),
      L:G("The container location, either Backpack or Bank."),
    } },
    { heading = L:G("Item Selection") },
    { text = L:G("Pressing Enter on an item in QuickFind opens the bag holding it (Backpack or Bank). For a Backpack item, BetterBags switches to the tab holding that item only when Enable Groups is on. For a Bank item, BetterBags opens the bank without selecting a bank or Warbank tab.") },
    { text = L:G("BetterBags also places the item's name into the bag's search box, focuses the search box, and selects the text so the item stands out while non-matching items dim. Because unquoted searches of multiple words match by the first word, a multi-word item name searches using its first word.") },
    { heading = L:G("Search Requirement") },
    { text = L:G("Enable In-Bag Search (under General) must be on for QuickFind to populate the bag's search box. When Enable In-Bag Search is off, pressing Enter in QuickFind still opens the bag and prints a chat message reminding you to turn it on.") },
    { heading = L:G("Integration Settings") },
    { text = L:G("The QuickFind page under Integrations holds the QuickFind tab with Enable QuickFind Integration and a How it works summary. Enable QuickFind Integration defaults to on and takes effect on the next QuickFind search without reloading the UI.") },
    { setting = "quickFind" },
    { open = { page = "quickfind", tab = "main", text = L:G("Open QuickFind Settings") } },
    { see = "search-basics" },
  },
})

articles:Define({
  id = "pawn", group = "integrations",
  title = L:G("Upgrade Addons"),
  summary = L:G("Using Pawn and SimpleItemLevel for gear upgrade arrows"),
  keywords = { L:G("Pawn"), L:G("SimpleItemLevel"), L:G("Simple Item Level"), L:G("stat weights"), L:G("scales"),
    L:G("upgrade arrow"),
    L:G("gear upgrade icon"),
    L:G("gear advisor"), L:G("stat weight addon"),
    L:G("Pawn and SimpleItemLevel")
  },
  questions = { L:G("How do I use Pawn with BetterBags?"), L:G("Why doesn't Pawn's arrow show right away?"),
    L:G("How do I make BetterBags use Pawn for upgrade arrows on gear?"),
    L:G("Why is there a green upgrade arrow on an item in my bags?"),
    L:G("How do I switch upgrade arrows between Pawn and SimpleItemLevel?"),
    L:G("Can BetterBags show Pawn upgrades in my bags?"), L:G("Why is Pawn not marking upgrades on my items?"),
    L:G("How do I pick which addon decides item upgrade arrows?")
  },
  related = { "upgrades" },
  body = {
    { text = L:G("When Pawn or SimpleItemLevel is installed, BetterBags adds it to Upgrade Icon Provider on the General page under Items alongside None and BetterBags.") },
    { heading = L:G("Provider Selection") },
    { text = L:G("Until you select an option in Upgrade Icon Provider yourself, BetterBags automatically uses Pawn if it is installed, or SimpleItemLevel if Pawn is not installed. Once you choose a provider in Upgrade Icon Provider, BetterBags uses your selection.") },
    { heading = L:G("Pawn") },
    { text = L:G("Pawn evaluates items using your Pawn stat weights and scales. Registering BetterBags with Pawn also turns off Pawn upgrade arrows on Blizzard bag frames, and requires Pawn 2.13.1 or later.") },
    { text = L:G("Pawn limits how many items it checks each quarter second and returns no answer while its budget is spent or item data is still loading. Outside combat, BetterBags queues unanswered items and checks them every quarter second for up to 20 attempts until the next bag refresh.") },
    { text = L:G("While an item has no answer from Pawn yet, BetterBags shows no upgrade arrow on it, leaves it out of the upgrade search field, and prevents Auto Sell and Skip Recent Items from acting on it. Items that already have a Pawn answer keep their current arrow until a recheck completes.") },
    { heading = L:G("SimpleItemLevel") },
    { text = L:G("SimpleItemLevel evaluates each item link through its own upgrade check and marks gear with an upgrade arrow whenever SimpleItemLevel reports it as an upgrade.") },
    { setting = "upgradeProvider" },
    { see = "upgrades" },
  },
})

articles:Define({
  id = "tsm", group = "integrations", design = "next",
  title = L:G("TradeSkillMaster"),
  summary = L:G("Vendor window switching with TradeSkillMaster"),
  keywords = { L:G("TradeSkillMaster"), L:G("TSM"), L:G("vendoring"), L:G("WoW UI"),
    L:G("TSM vendor"), L:G("TSM window"), L:G("merchant UI conflict")
  },
  questions = { L:G("How do I open TradeSkillMaster's vendor window?"), L:G("How do I get back to the BetterBags vendor from TSM?"),
    L:G("How do I use the TradeSkillMaster vendor window instead of BetterBags Next?"),
    L:G("Why did BetterBags Next replace my TSM merchant screen?"),
    L:G("How do I switch between TSM and BetterBags at a vendor?"),
    L:G("Can I use TradeSkillMaster alongside BetterBags Next?"),
    L:G("Where did my TSM vendor tab go when I talk to a merchant?"),
    L:G("How do I bring back the TradeSkillMaster vendor UI?")
  },
  related = { "next-vendor" },
  body = {
    { text = L:G("When TradeSkillMaster is installed while BetterBags Next is in use with Enable Vendor Window on, BetterBags Next's vendor window and TradeSkillMaster's vendor window swap in place so only one opens at a time. Without TradeSkillMaster installed, the TradeSkillMaster button stays hidden; with Enable Vendor Window off, TradeSkillMaster swaps with Blizzard's merchant frame instead.") },
    { heading = L:G("Switching Windows") },
    { list = {
      L:G("To open TradeSkillMaster from BetterBags Next's vendor window, click the TradeSkillMaster button in the vendor window header (or in the bag button menu when your theme moves header buttons into a menu). The button becomes active one frame after the merchant opens."),
      L:G("BetterBags Next's vendor window slides out while the merchant visit remains open, so right-clicking items in your backpack continues to sell them. Any backpack sections waiting in the vendor's dock return to your backpack immediately, and any active sale in a dock card stops while items already sold stay sold."),
      L:G("To switch back to BetterBags Next's vendor window, click the WoW UI button in TradeSkillMaster's vendor window. BetterBags Next reopens its vendor window on the Buy tab."),
      L:G("When BetterBags Next's vendor window returns, it docks again only the categories that Auto Sell offers and the Shopping List. Any backpack section you previously dragged onto the vendor window remains in your backpack unless you drag that section over again."),
      L:G("Closing TradeSkillMaster's vendor window with its close button or Escape ends the merchant visit, and BetterBags Next's vendor window stays closed."),
    } },
    { heading = L:G("Next Merchant Visit") },
    { text = L:G("TradeSkillMaster saves your last window selection across your entire account. The next merchant you visit on any character opens directly in whichever window you switched to last: TradeSkillMaster's vendor window if you switched to TradeSkillMaster, or BetterBags Next's vendor window if you switched back with WoW UI.") },
    { see = "next-vendor" },
  },
})

articles:Define({
  id = "shopping-list", group = "integrations", design = "next",
  title = L:G("Profession Shopping List"),
  summary = L:G("Tracked recipe reagents at BetterBags Next vendors"),
  keywords = { L:G("Profession Shopping List"), L:G("shopping list"), L:G("buy reagents"), L:G("crafting"), L:G("recipes"),
    L:G("buy shopping list"), L:G("vendor auto buy"), L:G("craft mats vendor")
  },
  questions = { L:G("How do I buy everything on my shopping list?"), L:G("What is the green card at the vendor?"),
    L:G("How do I buy everything on my Profession Shopping List at a vendor in one go?"),
    L:G("Does BetterBags work with the Profession Shopping List addon?"),
    L:G("Where is the button to buy my Profession Shopping List materials?"),
    L:G("Can BetterBags auto buy crafting supplies from my shopping list?"),
    L:G("Why isn't the Profession Shopping List vendor button showing up?"),
    L:G("How do I bulk buy vendor reagents for a tracked recipe?")
  },
  related = { "next-vendor", "confirm-sale" },
  body = {
    { text = L:G("When Profession Shopping List (v12.1.5-02 or later) is loaded and Enable Vendor Window is on, BetterBags Next collects the reagents your tracked recipes still need that the open merchant sells into a Shopping List section on the Buy tab. Those items leave their normal categories and appear in Shopping List instead. While TradeSkillMaster's saved choice is its own vendor window, BetterBags Next's vendor window stays closed and no Shopping List appears.") },
    { heading = L:G("Docked Card") },
    { text = L:G("Once per vendor visit, BetterBags Next docks the Shopping List section in a card at the top of the vendor window's column, above all sections. This happens on the first Buy draw that contains needed items, either when the vendor opens or later in the visit when your tracked recipes change. The docked card stays at the top of the column if you switch to Buyback or Repair.") },
    { text = L:G("The card glows in the theme's buy color, which is green on Default and most themes and cyan on Glitch. The card displays how many different items it buys and the total price of the needed quantities. Inside the section, each button displays the price of the needed quantity and shows that needed quantity as its count only when the quantity is 2 or more.") },
    { list = {
      L:G("Double-click anywhere on the card to run Profession Shopping List's purchase for all needed items at the open vendor. While the backpack is open, the Shopping List section animates into the backpack; when the backpack is closed, the section leaves with no animation. If any items are not bought, those items reappear in the Shopping List section on Buy without docking again during that visit. Once the list needs nothing more at that vendor, the Shopping List section disappears and the vendor's items return to their categories."),
      L:G("Right-click anywhere on the card to cancel. While the Shopping List section is docked, a click layer covers the card, so a right-click sends the section back to the top of the Buy tab without buying anything."),
    } },
    { heading = L:G("Buy Tab") },
    { text = L:G("Once the Shopping List section is back on the Buy tab, its buttons behave like other vendor buttons. Right-clicking a Shopping List button buys one purchase from the vendor.") },
    { see = "next-vendor" },
    { see = "confirm-sale" },
  },
})

articles:Define({
  id = "masque", group = "integrations",
  title = L:G("Masque"),
  summary = L:G("Masque skin groups for item buttons"),
  keywords = { L:G("Masque"), L:G("button skin"), L:G("skins"), L:G("borders"),
    L:G("skin item buttons"), L:G("button borders"), L:G("Masque support")
  },
  questions = { L:G("How do I skin my bag buttons with Masque?"), L:G("Why doesn't my Masque skin show?"),
    L:G("How do I skin BetterBags item slots with Masque?"), L:G("Does Masque work with BetterBags item buttons?"),
    L:G("Why aren't my Masque icon borders applying to BetterBags?"),
    L:G("Where do I find BetterBags inside Masque's settings?"),
    L:G("Can I change the shape and border of bag item icons using Masque?"),
    L:G("Why do my bag icons look different from my action bars in Masque?")
  },
  related = { "themes", "item-buttons" },
  body = {
    { heading = L:G("Button Groups") },
    { text = L:G("When Masque is installed, BetterBags creates five groups under BetterBags in Masque so you can skin each set of buttons separately.") },
    { list = {
      L:G("Backpack skins item buttons in your Backpack in both designs, and backpack bag slot buttons in the classic bags."),
      L:G("Bank skins item buttons in your Bank in both designs when Enable Bank Bags is on, and bank bag slot buttons in the classic bags on Classic Era, The Burning Crusade Anniversary (TBC), and Mists of Pandaria Classic."),
      L:G("Vendor skins vendor buttons in BetterBags Next when Enable Vendor Window is on, and skins Log and Money Log entries in the BetterBags Next Guild Bank regardless of Enable Vendor Window."),
      L:G("Guild Bank skins only item buttons in the BetterBags Next Guild Bank on clients other than Classic Era when Enable Guild Bank Window is on."),
      L:G("Food & Drink skins the buttons on the Food & Drink Bar in BetterBags Next."),
    } },
    { text = L:G("In BetterBags Next, bag tabs are not bag slot buttons, so Masque does not skin them. On retail and WoW: Forever, there are no bank bag slot buttons.") },
    { heading = L:G("ElvUI Theme") },
    { text = L:G("Only the classic ElvUI Bag Theme turns Masque off; no BetterBags Next theme turns Masque off. When the classic ElvUI Bag Theme is in use, BetterBags removes item, vendor, guild bank, and Food & Drink buttons from their Masque groups, while classic bag slot buttons stay in their Masque groups.") },
    { text = L:G("BetterBags reads whether Masque is used from the saved classic Bag Theme in both designs. If you switch to BetterBags Next while your saved classic Bag Theme is ElvUI, Masque stays off, and BetterBags Next does not show Bag Theme on the Appearance page; switch back to the classic bags to select another Bag Theme if you want Masque skins in BetterBags Next.") },
    { text = L:G("BetterBags uses the ElvUI Bag Theme only while the ElvUI addon is loaded. Without ElvUI loaded, Default applies for the session while keeping your saved choice, and Masque stays active.") },
    { open = { page = "appearance", tab = "theme", text = L:G("Open Theme Settings") } },
    { see = "themes" },
    { see = "item-buttons" },
  },
})

articles:Define({
  id = "gamepad", group = "integrations",
  title = L:G("Controllers"),
  summary = L:G("Controller navigation with ConsolePort and WoW: Forever"),
  keywords = { L:G("controller"), L:G("gamepad"), L:G("ConsolePort"), L:G("console"), L:G("joystick"), L:G("Steam Deck"),
    L:G("d-pad"),
    L:G("controller support"), L:G("Steam Deck bags")
  },
  questions = { L:G("Can I use BetterBags with a controller?"), L:G("Does BetterBags work with ConsolePort?"),
    L:G("How do I use BetterBags with a controller or Steam Deck?"),
    L:G("How do I navigate my bags using WoW: Forever's gamepad interface?"),
    L:G("Why can't I move my cursor over bag items with my controller?"),
    L:G("How do I set up BetterBags for gamepad play?"),
    L:G("What controller buttons work inside BetterBags with ConsolePort?"),
    L:G("Playing With a Controller")
  },
  related = { "next-panels" },
  body = {
    { text = L:G("BetterBags supports controller navigation in both bag designs on every client through the ConsolePort addon, and on WoW: Forever through WoW: Forever's built-in gamepad interface.") },
    { heading = L:G("ConsolePort") },
    { text = L:G("When ConsolePort is installed on any client, BetterBags adds Backpack, Bank (when Enable Bank Bags is on), and BetterBags Next's Guild Bank (on clients with a guild bank when Enable Guild Bank Window is on) to ConsolePort's interface cursor. BetterBags does not register BetterBags Next's vendor window with ConsolePort, binds no controller buttons, and performs no combat handling for ConsolePort.") },
    { text = L:G("ConsolePort's interface cursor receives only the menus that BetterBags opens through its classic dropdown menu: the classic bag menu, the classic Open Menu action, the classic group tab menus, and the Plain theme's bag button menu in BetterBags Next. When one of those menus opens, BetterBags adds the menu and its buttons to ConsolePort's interface cursor and selects the second button. BetterBags Next's own menus, including the category picker, the currency More menu, and settings dropdowns, are not given to ConsolePort.") },
    { heading = L:G("WoW: Forever") },
    { text = L:G("On WoW: Forever, while the gamepad interface style is active, BetterBags adds every open bag window to Blizzard's gamepad window list in both designs: Backpack and Bank (when Enable Bank Bags is on) in either design, plus BetterBags Next's vendor window (when Enable Vendor Window is on) and Guild Bank (when Enable Guild Bank Window is on). Blizzard frames that BetterBags replaces are removed from Blizzard's gamepad window list. Switching between the gamepad and mouse interface styles takes effect on the next frame.") },
    { heading = L:G("Cursor Navigation") },
    { text = L:G("On WoW: Forever's gamepad interface, the directional pad moves the cursor across backpack and bank item buttons, BetterBags Next vendor and guild bank buttons, and every tab in both designs, not only group tabs. Other controls, including header buttons, search boxes, section headers, and scroll bars, are skipped. Moving to a button inside a window's scrollable area scrolls that button into view. When multiple bag windows are open, the controller triggers move focus between windows, and trigger hints appear on neighboring windows.") },
    { heading = L:G("Button Actions") },
    { text = L:G("On WoW: Forever's gamepad interface, Blizzard's input legend beneath the focused window displays the active actions for A, X, and B.") },
    { list = {
      L:G("A clicks the selected button. On a tab, A switches to that tab. On a backpack or bank item button, A picks up or places the item. On a BetterBags Next vendor button, A buys on Buy, buys back on Buyback, repairs on Repair, or sells when an item is held on the cursor. On a BetterBags Next guild bank button, A interacts with that slot."),
      L:G("X right-clicks the selected item on backpack and bank item buttons to use it, sell it at a merchant, move it into a bank, or place it into mail, trade, or auction windows. On BetterBags Next vendor and guild bank buttons, X is not bound and the legend shows no X prompt."),
      L:G("B returns an item held on the cursor, or closes the focused window when no item is held."),
    } },
    { heading = L:G("Radial Menu") },
    { text = L:G("On WoW: Forever's gamepad interface, the radial menu's Bags entry toggles BetterBags' Backpack. The radial menu's Character entry opens BetterBags' Backpack only when Blizzard's own hidden backpack reads closed, so if B closed only the BetterBags window, Character leaves BetterBags' Backpack closed.") },
    { heading = L:G("Combat") },
    { text = L:G("When combat starts on WoW: Forever's gamepad interface, BetterBags unbinds X and removes all BetterBags windows from Blizzard's gamepad window list, hiding their legends and trigger hints. Gamepad navigation does not control bag windows during combat, though mouse clicks continue to work. When combat ends, open windows rejoin Blizzard's gamepad window list with the previously focused window focused again, and each window reselects its previous button only if that button still shows in that window.") },
    { see = "next-panels" },
  },
})

articles:Define({
  id = "elvui-gw2", group = "integrations",
  title = L:G("Addon Themes"),
  summary = L:G("Themes following ElvUI and GW2 UI"),
  keywords = { L:G("ElvUI"), L:G("GW2 UI"), L:G("GW2_UI"), L:G("Guild Wars 2"), L:G("UI pack"), L:G("match my UI"),
    L:G("ElvUI theme"), L:G("GW2 UI theme"), L:G("match UI skin"), L:G("ElvUI bags"),
    L:G("ui overhaul"), L:G("blend in")
  },
  questions = { L:G("How do I make BetterBags match ElvUI?"), L:G("Does BetterBags have a GW2 UI theme?"),
    L:G("How do I make BetterBags look like ElvUI?"), L:G("Is there a theme that matches GW2 UI?"),
    L:G("Why don't my bags match my ElvUI fonts and colors?"),
    L:G("How do I turn on the ElvUI or GW2 UI theme in BetterBags?"),
    L:G("Can I use BetterBags instead of ElvUI bags and keep the same look?"),
    L:G("Where do I find the ElvUI and GW2 UI skins?"),
    L:G("ElvUI and GW2 UI")
  },
  related = { "themes" },
  body = {
    { text = L:G("When ElvUI or GW2 UI is installed and loaded, BetterBags offers matching themes in Appearance. Under the classic bags, choose them under Bag Theme; under BetterBags Next, choose them on the Theme tab, where they also style the Settings Window.") },
    { heading = L:G("ElvUI") },
    { text = L:G("In the classic bags, the ElvUI theme reads your ElvUI colors, textures, border settings, and icon crop when applied, and turns off Masque on item buttons.") },
    { text = L:G("In BetterBags Next, the ElvUI theme builds windows, controls, item buttons, and the Settings Window using ElvUI textures, colors, icon crop, and fonts. When you change ElvUI media colors, bar or gloss textures, icon crop, quest item colors, general font, font style, font size, or bag count and item level fonts in ElvUI options, BetterBags Next updates and redraws automatically.") },
    { text = L:G("Window text and control sizes grow with ElvUI's general font size, except vendor card names and prices, which stay fixed to fit beside their icons, and stack counts and item levels, which follow ElvUI's bag font settings. BetterBags keeps its own colors for item levels and text rather than using ElvUI's text or item-level colors, and changing ElvUI's Thin Borders setting requires a UI reload in ElvUI.") },
    { heading = L:G("GW2 UI") },
    { text = L:G("In both designs, the Guild Wars 2 theme draws windows, controls, item buttons, and the side action panel using GW2 UI textures and follows GW2 UI's font settings.") },
    { see = "themes" },
  },
})

articles:Define({
  id = "plugins", group = "integrations",
  title = L:G("Plugins"),
  summary = L:G("Plugin additions and where plugin settings appear"),
  keywords = { L:G("plugin"), L:G("plugins"), L:G("addon"), L:G("extension"), L:G("BetterBags plugin"), L:G("third party"),
    L:G("BetterBags plugins"), L:G("addon extensions"), L:G("extra modules"), L:G("plugin settings"),
    L:G("curseforge"), L:G("companion addons"), L:G("addon packs")
  },
  questions = { L:G("What are BetterBags plugins?"), L:G("Where are a plugin's settings?"),
    L:G("What are BetterBags plugins and where do I see them?"),
    L:G("How do I install or use extra category addons for BetterBags?"),
    L:G("Where do plugin settings appear inside BetterBags?"),
    L:G("Can third-party plugins add new themes or categories?"),
    L:G("Why do I have extra options from another addon in my bag settings?"),
    L:G("How do plugins work with BetterBags?")
  },
  related = { "category-plugins" },
  body = {
    { text = L:G("Separate plugin addons can extend BetterBags using its plugin APIs. Both the classic bags and BetterBags Next support BetterBags plugins.") },
    { heading = L:G("Plugin Additions") },
    { list = {
      L:G("Custom categories that sort matching items in your bags and appear on the Categories page."),
      L:G("Plugin settings pages inside the BetterBags Settings Window."),
      L:G("Custom themes for BetterBags windows and controls."),
      L:G("Localized text for plugin labels and categories."),
    } },
    { heading = L:G("Plugin Settings") },
    { text = L:G("When a plugin registers configuration options with BetterBags, a page with that plugin's name appears under Integrations in the Settings Window. Each page displays the plugin's sections, toggles, dropdowns, sliders, inputs, color pickers, and action buttons, updating dynamically as options are changed.") },
    { see = "category-plugins" },
  },
})
