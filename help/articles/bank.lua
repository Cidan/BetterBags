local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class HelpArticles: AceModule
local articles = addon:GetModule('HelpArticles')

articles:Group({ id = "bank", title = L:G("Bank and Warbank") })

articles:Define({
  id = "classic-currency", group = "bags", design = "classic",
  shown = function() return addon.isRetail or addon.isMists end,
  title = L:G("Backpack Currencies"),
  summary = L:G("Classic backpack currencies and the Currency page"),
  keywords = { L:G("currency"), L:G("currencies"), L:G("tokens"), L:G("show in backpack"), L:G("backpack currency"),
    L:G("tracked currencies"), L:G("backpack currency bar"), L:G("show currency bottom"), L:G("watch tokens"),
    L:G("old style currencies")
  },
  questions = { L:G("How do I show a currency in my backpack?"), L:G("Why can't I see more than seven currencies?"),
    L:G("How do I choose which currencies show at the bottom of my backpack?"),
    L:G("Why aren't my crests or valorstones showing in my bag?"),
    L:G("How do I add or remove watched currencies in the classic bags?"),
    L:G("Can I pin more currencies to the bottom of my backpack?"),
    L:G("Where did the currency tracker at the bottom of my bags go?"),
    L:G("How do I change which tokens appear next to my gold?"),
    L:G("crests at the bottom"),
    L:G("Currencies at the Bottom of Your Backpack")
  },
  pages = { "currency", "currency:main" },
  related = { "item-buttons", "designs" },
  body = {
    { text = L:G("On retail, WoW: Forever, and Mists of Pandaria Classic, the classic Backpack displays selected currencies along its bottom-left edge. Point at any currency icon there to view its game tooltip.") },
    { heading = L:G("Currency Page") },
    { text = L:G("Open the Settings Window and select Currency under BetterBags to choose which currencies appear on your Backpack. Because the Currency page has only a single Currency tab, no tab bar appears at the top of the page.") },
    { list = {
      L:G("The Currencies section expands all game currency headings and lists each currency with its icon, name, current count, and a toggle switch."),
      L:G("Whenever a currency has a maximum, the count shows have / max even before you reach that cap."),
      L:G("If your character has no currencies yet, the page displays You have no currencies yet."),
      L:G("Clicking a switch or anywhere on its currency row updates the game's own setting to show that currency on your Backpack, rather than BetterBags Next's Tracked list."),
    } },
    { heading = L:G("Display Limit") },
    { text = L:G("The classic Backpack displays up to 7 currencies at a time. When more than 7 currencies have the game's backpack display setting enabled, only the first 7 in the list appear at the bottom of your Backpack.") },
    { open = { page = "currency", tab = "main", text = L:G("Open Currency Settings") } },
  },
})

articles:Define({
  id = "bank-basics", group = "bank",
  title = L:G("Your Bank"),
  summary = L:G("BetterBags bank window and settings overview"),
  keywords = { L:G("bank"), L:G("bank window"), L:G("banker"), L:G("bank tabs"), L:G("enable bank bags"), L:G("blizzard bank"),
    L:G("reload"),
    L:G("disable bank skin"), L:G("default bank frame"),
    L:G("bank only")
  },
  questions = { L:G("How do I use the Blizzard bank instead?"), L:G("How do I sort my bank?"),
    L:G("Why does my bank look different?"),
    L:G("How do I use Blizzard's default bank window instead of BetterBags?"),
    L:G("Why does my bank look different when I open it?"), L:G("How does BetterBags display my bank items?"),
    L:G("Can I turn off BetterBags for the bank but keep it for my bags?"),
    L:G("Where are my reagent bank and regular bank items?"),
    L:G("How do I switch back to the game's normal bank UI?"),
    L:G("How do I turn off BetterBags for the bank only?"), L:G("How is the bank organized?")
  },
  settings = { "enableBankBags" },
  pages = { "bank", "bank:general" },
  related = { "warbank", "bank-tabs", "next-bank", "move-category" },
  body = {
    { text = L:G("When Enable Bank Bags is on, BetterBags replaces Blizzard's bank frame with its own Bank window in both the classic bags and BetterBags Next, displaying your bank items organized into categories.") },
    { heading = L:G("Bank Settings") },
    { text = L:G("The Bank page in the settings window configures your bank separately from your backpack across its Layout, Items, Categories, Order, and BetterBags Next Size tabs. Its General tab contains Enable Bank Bags and, on retail, Include Tradeable Reagents for Warbank deposits.") },
    { text = L:G("Turn off Enable Bank Bags on the General tab of the Bank page to use Blizzard's default bank window instead. BetterBags prompts you to choose Reload or Later because changing Enable Bank Bags requires a UI reload to take effect.") },
    { setting = "enableBankBags", bag = "Bank" },
    { heading = L:G("Sorting") },
    { text = L:G("In BetterBags Next, right-click the Bank window title to sort the bank wherever the game client supports bank sorting; on retail, this sorts the Warbank while a Warbank tab is active. In the classic bags, open the bank menu from the round bag button and click Sort Bank (or Clean Up Warbank on retail), or right-click the round bag button on retail and WoW: Forever.") },
    { heading = L:G("Moving Sections") },
    { text = L:G("Right-click a section title in either design (with an empty cursor in BetterBags Next) to move that section's items between your bank and your backpack. In BetterBags Next, you can also drag category sections by their titles to reorder them, assign them to group tabs, or move items to your backpack, except while Show Bank Tabs is turned on.") },
    { heading = L:G("Dropping Items") },
    { text = L:G("Drop an item anywhere on the Bank window, or left-click the window while holding an item, to place the item into the first available matching specialized bag or free slot, starting with the active bank tab. Dropping an item picked up from the bank returns it to its slot, and a refundable item dropped while a Warbank tab is showing is not placed.") },
    { open = { page = "bank", tab = "general", text = L:G("Open Bank General") } },
    { open = { page = "bank", text = L:G("Open Bank Settings") } },
    { see = "bank-tabs" },
  },
})

articles:Define({
  id = "warbank", group = "bank", shown = function() return addon.hasWarbank end,
  title = L:G("Warband Bank"),
  summary = L:G("Warbound deposits, gold, and Warbank tabs"),
  keywords = { L:G("warbank"), L:G("warband bank"), L:G("account bank"), L:G("warbound"), L:G("deposit warbound"),
    L:G("gold"), L:G("tradeable reagents"), L:G("clean up warbank"),
    L:G("Warbank gold"), L:G("Warbank tabs"),
    L:G("shared bank"), L:G("shared storage"),
    L:G("The Warband Bank")
  },
  questions = { L:G("How do I deposit warbound items?"), L:G("How do I put gold in the Warbank?"),
    L:G("How do I deposit reagents into the Warbank?"), L:G("How do I rename a Warbank tab?"),
    L:G("How do I deposit all my warbound items into the Warbank?"),
    L:G("How do I put gold into or take gold out of my Warband Bank?"),
    L:G("How do I buy, rename, or change icons on Warbank tabs?"),
    L:G("Can I manage my Warbank tabs inside BetterBags?"),
    L:G("Where is the button to deposit warbound gear for my alts?"),
    L:G("How does the Warband Bank work in BetterBags?")
  },
  settings = { "bankAutoDepositReagents" },
  related = { "bank-basics", "auto-deposit", "next-bank" },
  body = {
    { text = L:G("On retail, your Warband bank shares the BetterBags Bank window with your character bank. Warbank groups appear alongside your Bank groups—with a teal accent in BetterBags Next—and Warbank tabs appear beside your character tabs in the bank tabs view.") },
    { heading = L:G("Warbound Deposits") },
    { text = L:G("Use Deposit All Warbound Items to move every warbound item from your bags into the Warbank. If any warbound item in your bags can still be refunded, BetterBags prompts for confirmation before depositing because placing it in the Warbank removes its refund timer.") },
    { list = {
      L:G("Classic bags: open the bank menu from the round bag button (or the Open Menu button in the Guild Wars 2 theme) and choose Deposit All Warbound Items, or Shift-right-click the round bag button."),
      L:G("BetterBags Next: click the Deposit All Warbound Items button in the Bank header (or in the bag-button menu on themes that move header buttons there), or Shift-right-click the Bank title."),
    } },
    { text = L:G("Enable Include Tradeable Reagents to deposit tradeable reagents into the Warbank alongside warbound items during Deposit All Warbound Items. This setting mirrors the game client's per-character setting (enabled by default) and appears both under Warbank on the Bank page's General tab and in the classic bank's left-click menu.") },
    { setting = "bankAutoDepositReagents", bag = "Bank" },
    { heading = L:G("Warbank Gold") },
    { text = L:G("In the classic Bank window (and in BetterBags Next on retail), the gold counter at the bottom displays your Warbank gold balance. Left-click the gold amount to withdraw gold, and right-click it to deposit gold.") },
    { heading = L:G("Warbank Tabs") },
    { text = L:G("Right-clicking a custom group tab opens options to rename or delete that group, not Blizzard's tab configuration. To change a Warbank tab's name, icon, or deposit rules—or to purchase a new Warbank tab—switch to the bank tabs view first.") },
    { list = {
      L:G("Classic bags: select Show Bags in the bank menu (or click the Show Bags action button in the Guild Wars 2 theme) to open the bank tabs panel below the window."),
      L:G("BetterBags Next: click Show Bank Tabs in the Bank header to display your character and Warbank tabs down the side."),
    } },
    { text = L:G("In the bank tabs view, right-click any purchased Warbank tab to open Blizzard's tab settings, or click an unpurchased plus slot to buy a new tab.") },
    { heading = L:G("Bank Cleanup") },
    { text = L:G("To sort your Warbank, select Clean Up Warbank in the classic bank menu. You can also right-click the classic round bag button (or click Sort Bags in the Guild Wars 2 theme), or right-click the Bank title in BetterBags Next, while a Warbank group or Warbank tab is active.") },
    { heading = L:G("Category Automation") },
    { text = L:G("To deposit a category's items automatically whenever you open the bank, select the category on the Categories page, open its Automation tab, enable Auto Deposit, and set Deposit Into to Warbank. Hold Shift while opening the bank to skip Auto Deposit. Items the Warbank does not accept—such as soulbound items—as well as equipment set items and refundable purchases stay in your bags.") },
    { open = { page = "bank", tab = "general", text = L:G("Open Bank Settings") } },
    { see = "auto-deposit" },
    { see = "bank-tabs" },
  },
})

articles:Define({
  id = "bank-tabs", group = "bank", shown = function() return addon.isRetail end,
  title = L:G("Bank Tabs"),
  summary = L:G("Viewing individual bank tabs instead of groups"),
  keywords = { L:G("bank tabs"), L:G("character bank"), L:G("show bank tabs"), L:G("buy bank tab"), L:G("purchase bank"),
    L:G("character bank tabs"), L:G("view bank tabs"), L:G("bank tab view"), L:G("separate bank tabs"),
    L:G("bank pages"), L:G("individual tabs")
  },
  questions = { L:G("How do I see my bank tabs one by one?"), L:G("How do I buy a bank tab?"),
    L:G("How do I view my character bank by individual tabs instead of categories?"),
    L:G("Can I switch between grouped categories and my actual bank tabs?"),
    L:G("Why are all my bank tabs combined into one big list?"),
    L:G("How do I see what is in each tab of my character bank?"),
    L:G("Where is the option to browse character bank tabs separately?"),
    L:G("How do I check my bank tabs one by one?"),
    L:G("each bank tab separately")
  },
  related = { "bank-basics", "next-bank", "warbank" },
  body = {
    { text = L:G("On Retail and WoW: Forever, you can switch the bank from your category groups to Blizzard's own bank tabs to view one bank tab at a time. BetterBags stores your choice for the next time you open the bank, and you cannot switch modes while in combat.") },
    { heading = L:G("Classic Bags") },
    { steps = {
      L:G("Open the bank menu from the bag button at the top left and click Show Bags."),
      L:G("Click any purchased tab in the panel below the bank to show only that tab's items, character tabs first and Warbank tabs after."),
      L:G("Click a green + slot to buy the next unpurchased tab."),
      L:G("Right-click a purchased tab to open Blizzard's tab settings beside the bank."),
      L:G("Click Show Bags again in the bank menu to return to your category groups."),
    } },
    { heading = L:G("BetterBags Next") },
    { steps = {
      L:G("Click Show Bank Tabs in the bank header, or open the bag button's menu and click Show Bank Tabs in the Plain theme."),
      L:G("Click a purchased tab in the side tab rail to view only that tab's items."),
      L:G("Click a + tab at the end of a bank type's tabs to buy the next unpurchased tab."),
      L:G("Right-click a purchased tab to open Blizzard's tab settings beside the bank."),
      L:G("Click Show Bank Tabs again to return to your category groups."),
    } },
    { see = "bank-basics" },
    { see = "warbank" },
    { see = "next-bank" },
  },
})

articles:Define({
  id = "bank-bags", group = "bank", shown = function() return not addon.isRetail or addon.isForever end,
  title = L:G("Bank Bags"),
  summary = L:G("Bank bag slots and tabbed bag sockets"),
  keywords = { L:G("bank bag"), L:G("bank bag slot"), L:G("buy slot"), L:G("red slot"), L:G("bank space"),
    L:G("bank bags"), L:G("bank bag slots"), L:G("equip bank bag"), L:G("buy bank slot")
  },
  questions = { L:G("How do I buy a bank bag slot?"), L:G("How do I put a bag in my bank?"),
    L:G("How do I buy more bank bag slots?"), L:G("How do I put a bigger bag into one of my bank bag slots?"),
    L:G("Where do I equip or swap bags in my bank?"), L:G("I bought a new bag for my bank, where do I drop it?"),
    L:G("Can I see and manage my bank bag slots in BetterBags?"),
    L:G("Why can't I find the slot to equip a new bank bag?")
  },
  related = { "show-bags", "bank-basics" },
  body = {
    { text = L:G("How you buy bank storage and equip bags in your bank depends on whether you play a classic game version or WoW: Forever.") },
    { heading = L:G("Classic Versions") },
    { text = L:G("On Classic Era, The Burning Crusade Anniversary, and Mists of Pandaria Classic, your bank has 7 purchasable bank bag slots. In the classic bags, open the bank menu from the round bag button and choose Show Bags to display those slots below the bank.") },
    { list = {
      L:G("Unpurchased bank bag slots are tinted red; hover a slot to see its cost and click it outside combat to confirm the purchase."),
      L:G("Drop a bag onto a purchased slot, or click the slot while holding a bag, to equip or swap it."),
      L:G("Drag a slot or Shift-click it to pick up the equipped bag."),
    } },
    { tip = L:G("BetterBags Next does not show bank bag slots on classic game versions. Switch to the classic bags or turn off Enable Bank Bags temporarily when you want to buy or swap bank bags.") },
    { heading = L:G("WoW: Forever") },
    { text = L:G("On WoW: Forever, the first character bank tab is a fixed base bank without a bag slot, while every purchased character bank tab after the first is a bag socket that requires an equipped bag to store items. You manage these tabs and their bags in both designs.") },
    { list = {
      L:G("In the classic bags, open the bank menu and choose Show Bags to open the bank tab panel. Each tab retains its own icon with a small corner badge showing the equipped bag or an empty bag slot, and greys out the tab icon when no bag is equipped."),
      L:G("In BetterBags Next, click Show Bank Tabs in the bank header. Each socketed tab displays the equipped bag's icon directly, or an empty bag slot icon when empty."),
      L:G("Click a + tab to buy the next bank tab, drop or left-click a bag onto a purchased socket tab to equip or swap a bag, and drag or Shift-left-click a socketed tab to remove its bag."),
    } },
    { warning = L:G("You cannot buy or change bank bags while you are in combat.") },
    { see = "show-bags" },
    { see = "bank-basics" },
  },
})
