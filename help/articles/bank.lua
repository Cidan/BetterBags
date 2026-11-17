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
  summary = L:G("Choosing which currencies appear at the bottom of the classic backpack."),
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
    { text = L:G("The classic backpack shows up to seven currencies at the bottom: the ones the game marks Show in Backpack.") },
    { text = L:G("The Currency page lists every currency you have under its headings, with a switch beside each. Click a row to show or hide that currency in your backpack. If more than seven are switched on, the backpack shows the first seven.") },
    { open = { page = "currency", text = L:G("Open the Currency page") } },
  },
})

articles:Define({
  id = "bank-basics", group = "bank",
  title = L:G("Your Bank"),
  summary = L:G("How BetterBags shows your bank, and how to use Blizzard's bank window instead."),
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
    { text = L:G("When you open your bank, BetterBags shows it in its own window with its items in your categories, just like your backpack. The Bank settings page lays it out and sorts it separately from your backpack.") },
    { list = {
      L:G("Right-click the bank's bag button, or the title of a BetterBags Next bank, to sort it."),
      L:G("Right-click a section's title to move everything in it to your bags."),
      L:G("Drop an item anywhere on the bank to store it in the bank you are viewing."),
    } },
    { heading = L:G("Blizzard's Bank") },
    { text = L:G("Turn off Enable Bank Bags on the Bank page's General tab to use Blizzard's bank window. This change takes effect after a reload, and BetterBags offers to reload.") },
    { setting = "enableBankBags", bag = "Bank" },
  },
})

articles:Define({
  id = "warbank", group = "bank", shown = function() return addon.hasWarbank end,
  title = L:G("Warband Bank"),
  summary = L:G("Depositing warbound items and gold in the Warbank, and managing its tabs."),
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
    { text = L:G("Your Warband bank appears beside your bank in its own tabs or groups.") },
    { heading = L:G("Warbound Deposits") },
    { list = {
      L:G("Classic bags: Shift-right-click the bank's bag button, or use the Warbank's deposit options in its bag menu."),
      L:G("BetterBags Next: click Deposit All Warbound Items at the top of the bank."),
    } },
    { text = L:G("Include Tradeable Reagents, on the Bank page's General tab, also puts your tradeable reagents into the Warbank when you deposit all warbound items. This is the game's own setting, saved per character.") },
    { setting = "bankAutoDepositReagents", bag = "Bank" },
    { heading = L:G("Gold") },
    { text = L:G("In the classic bank, click the Warbank's gold at the bottom of the window, from any tab: left-click to withdraw gold, right-click to deposit it.") },
    { heading = L:G("Warbank Tabs") },
    { text = L:G("To change a Warbank tab's name, icon and which items it takes, first show the bank's own tabs: choose Show Bags in the classic bank's menu, or click Show Bank Tabs in BetterBags Next. Then right-click the tab. Clean Up Warbank, in the classic bank's menu, sorts your Warbank tabs and puts items back in the tabs meant for them.") },
    { tip = L:G("A category can deposit into the Warbank on its own. See Auto Deposit.") },
  },
})

articles:Define({
  id = "bank-tabs", group = "bank", shown = function() return addon.isRetail end,
  title = L:G("Bank Tabs"),
  summary = L:G("Viewing each of your bank's own tabs instead of your groups."),
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
    { text = L:G("Your bank can show your groups or the bank's own tabs one at a time.") },
    { list = {
      L:G("Classic bags: choose Show Bags in the bank's menu. Your bank tabs, and your Warbank tabs where there are any, replace your groups under the bank. Click a tab to see it alone, click + to buy a tab, or right-click a tab to change its name, icon and deposit settings."),
      L:G("BetterBags Next: click Show Bank Tabs at the top of the bank. You can buy a new tab there, and right-click a tab to change its name, icon, and deposit settings."),
    } },
  },
})

articles:Define({
  id = "bank-bags", group = "bank", shown = function() return not addon.isRetail or addon.isForever end,
  title = L:G("Bank Bags"),
  summary = L:G("Buying bank bag slots and putting bags in them."),
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
    { text = L:G("On classic versions of the game, turn on Show Bags in the bank's menu to show your bank's bag slots. Click a red slot to buy it, and drop a bag into a slot to use it.") },
    { text = L:G("In WoW: Forever, your bank's bags go in its tabs. Choose Show Bags in the classic bank's menu, or click Show Bank Tabs in BetterBags Next. Then click + to buy a tab, and drop a bag on a tab to use it.") },
  },
})
