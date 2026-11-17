local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class HelpArticles: AceModule
local articles = addon:GetModule('HelpArticles')

articles:Group({ id = "automation", title = L:G("Selling and Depositing") })

articles:Define({
  id = "auto-sell", group = "automation", featured = true,
  title = L:G("Auto Sell"),
  summary = L:G("Selling a category's items whenever you open a merchant."),
  keywords = { L:G("auto sell"), L:G("sell junk"), L:G("vendor"), L:G("merchant"), L:G("sell"), L:G("junk"), L:G("gray items"),
    L:G("automation"), L:G("vendor trash"),
    L:G("sell vendor trash"), L:G("auto sell gray"), L:G("vendor junk")
  },
  questions = { L:G("How do I sell my junk automatically?"), L:G("How do I auto sell a category?"),
    L:G("How do I stop BetterBags from selling something?"), L:G("Why didn't my items sell?"),
    L:G("How do I automatically sell vendor trash when I talk to a merchant?"),
    L:G("How do I set a category to auto sell at vendors?"), L:G("What items will BetterBags never auto sell?"),
    L:G("Why is auto sell selling items one at a time instead of all at once?"),
    L:G("Can BetterBags auto sell soulbound greens or old gear?"),
    L:G("How do I stop auto sell from vendoring something valuable?")
  },
  pages = { "categories:automation" },
  related = { "confirm-sale", "destroy", "category-rule", "search-examples", "move-category" },
  body = {
    { text = L:G("When Auto Sell is on for a category, BetterBags sells its items in your backpack at a merchant. With Confirm Auto Sell on, which is the default, you confirm each sale first. Turn Confirm Auto Sell off to sell as soon as you open the merchant.") },
    { steps = {
      L:G("Open the settings and choose Categories."),
      L:G("Choose the category, or make one whose search rule finds what you want to sell, such as rarity = poor."),
      L:G("On its Automation tab, turn on Auto Sell."),
    } },
    { text = L:G("Hold Shift as you open the merchant to keep the items this time.") },
    { heading = L:G("Protected Items") },
    { list = {
      L:G("Items in an equipment set."),
      L:G("Purchases you can still refund."),
      L:G("Anything a merchant won't buy: it stays in your bags, and the next merchant that takes it buys it."),
    } },
    { heading = L:G("Selling Speed") },
    { text = L:G("BetterBags sells one item at a time, as fast as your connection allows. Selling everything at once makes the game answer That object is busy.") },
    { see = "confirm-sale" },
  },
})

articles:Define({
  id = "confirm-sale", group = "automation",
  title = L:G("Confirm Auto Sell"),
  summary = L:G("Holding a category at the vendor until you double-click to sell it, instead of selling at once."),
  keywords = { L:G("confirm auto sell"), L:G("confirm"), L:G("double click"), L:G("waiting"), L:G("dock"), L:G("glowing"),
    L:G("put back"), L:G("sell section"),
    L:G("confirm sale"), L:G("double click sell"), L:G("vendor dock"), L:G("safe sell"),
    L:G("review before selling"), L:G("check before selling")
  },
  questions = { L:G("Why is a section glowing at the vendor?"), L:G("How do I confirm a sale?"),
    L:G("How do I sell a whole section at the vendor?"), L:G("How do I put a section back?"),
    L:G("How do I make BetterBags ask before selling a category?"),
    L:G("Why is a category waiting in a box at the vendor for me to double-click?"),
    L:G("Can I drag any section to the vendor panel to sell it?"),
    L:G("How do I confirm a sale when I'm using Blizzard's merchant window?"),
    L:G("How do I sell a whole category without turning on instant auto sell?"),
    L:G("How do I sell items safely so I don't vendor the wrong thing?"),
    L:G("Confirming a Sale at the Vendor")
  },
  related = { "auto-sell", "next-vendor", "move-category" },
  body = {
    { text = L:G("Confirm Auto Sell, on a category's Automation tab, is on by default. In BetterBags Next's vendor window, the category's section flies over to the vendor and waits there, glowing.") },
    { list = {
      L:G("Double-click it to sell its items."),
      L:G("Right-click it to put it back."),
    } },
    { text = L:G("With Confirm Auto Sell off, the items sell as soon as you open the merchant.") },
    { heading = L:G("Right-Click Selling") },
    { text = L:G("With the classic bags, or with Enable Vendor Window off, nothing waits at the vendor, and nothing sells by itself. Turn on Enable Category Sell and Deposit on the General page, then right-click the category's section title. Each right-click sells up to 10 of its items.") },
    { heading = L:G("Dropped Sections") },
    { text = L:G("In BetterBags Next, drag any section from your backpack onto the vendor to sell it. A section of 12 items or fewer sells as soon as you drop it, since you can buy all of it back. A larger one waits there the same way, to be sold with a double click.") },
    { tip = L:G("A waiting section holds only the items it shows, and a category on another tab of your backpack does not fly over.") },
  },
})

articles:Define({
  id = "destroy", group = "automation",
  title = L:G("Destroying Items"),
  summary = L:G("Getting rid of a category's items that no merchant buys, one click at a time."),
  keywords = { L:G("destroy"), L:G("delete item"), L:G("throw away"), L:G("trash"), L:G("unsellable"), L:G("destroy next item"),
    L:G("keybind"),
    L:G("destroy items"), L:G("delete unsellable"), L:G("trash worthless items"), L:G("destroy junk")
  },
  questions = { L:G("How do I destroy items I can't sell?"), L:G("How do I delete junk automatically?"),
    L:G("Why does it only destroy one item per click?"),
    L:G("How do I get rid of items that vendors won't buy?"),
    L:G("Can BetterBags help me delete unsellable junk from my bags?"),
    L:G("Why can't I delete a whole category of worthless items with one click?"),
    L:G("How do I mark a category to be destroyed one click at a time?"),
    L:G("Where do unsellable items show up when I want to destroy them?"),
    L:G("How do I clean out gray or soulbound items with no vendor price?"),
    L:G("Destroying What Can't Be Sold")
  },
  related = { "auto-sell", "confirm-sale", "slash-commands" },
  body = {
    { text = L:G("Destroy What Can't Be Sold, on a category's Automation tab, works only when Auto Sell is on. It destroys the category's items that no merchant buys.") },
    { list = {
      L:G("In BetterBags Next's vendor window, the category's section waits at the vendor like a sale, glowing red. Each click destroys the next item, a whole stack at a time."),
      L:G("You can do the same anywhere with the Destroy Next Item key binding, under Key Bindings in the BetterBags section."),
    } },
    { warning = L:G("The game lets an addon destroy only one item per key press or click, so each item takes its own press or click. Destroyed items are gone for good.") },
  },
})

articles:Define({
  id = "auto-deposit", group = "automation",
  title = L:G("Auto Deposit"),
  summary = L:G("Sending a category's items to your bank, or the Warbank, whenever you open it."),
  keywords = { L:G("auto deposit"), L:G("deposit"), L:G("bank"), L:G("warbank"), L:G("materials"), L:G("reagents"),
    L:G("store"), L:G("deposit into"),
    L:G("bank automation"), L:G("auto bank reagents"), L:G("deposit to warbank"),
    L:G("quick stash"), L:G("stash automatically")
  },
  questions = { L:G("How do I put materials in my bank automatically?"), L:G("How do I deposit a category to the Warbank?"),
    L:G("Why did some items stay in my bags?"),
    L:G("How do I automatically deposit reagents when I open my bank?"),
    L:G("Can BetterBags send a category straight to my Warbank automatically?"),
    L:G("How do I make crafting mats go to the bank every time I visit?"),
    L:G("Why did my items move to my bank on their own when I opened it?"),
    L:G("How do I set up auto deposit for a specific category?"),
    L:G("Can I automatically deposit items into my character bank or Warbank?")
  },
  related = { "warbank", "bank-basics", "move-category" },
  body = {
    { text = L:G("With Auto Deposit on, under Bank on a category's Automation tab, the category's items in your backpack go into your bank when you open it.") },
    { list = {
      L:G("Deposit Into lets you choose your bank or the Warbank, where there is one. Items the Warbank won't take, such as soulbound items, stay in your bags."),
      L:G("Hold Shift as you open the bank to keep the items this time."),
      L:G("You can turn on both Auto Sell and Auto Deposit for the same category."),
    } },
    { text = L:G("Items in an equipment set and purchases you can still refund are never deposited on their own.") },
  },
})

articles:Define({
  id = "move-category", group = "automation",
  title = L:G("Moving Sections"),
  summary = L:G("Sending everything in a section to the bank, the mailbox, a trade or a vendor with one click."),
  keywords = { L:G("move category"), L:G("right-click header"), L:G("sell all"), L:G("deposit all"), L:G("mail"),
    L:G("trade"), L:G("move all"), L:G("category sell"),
    L:G("move whole section"), L:G("send category mail"), L:G("deposit entire category"), L:G("quick move section"),
    L:G("bulk move")
  },
  questions = { L:G("How do I move a whole category to my bank?"), L:G("How do I mail a whole category?"),
    L:G("How do I sell everything in a section?"),
    L:G("How do I move every item in a category to my bank at once?"),
    L:G("Can I put a whole section into a trade window or mailbox?"),
    L:G("How do I sell an entire section at a vendor with one click?"),
    L:G("How do I move a whole category in BetterBags Next?"),
    L:G("Is there a shortcut to deposit or mail a full section?"),
    L:G("How do I send a bunch of items to an alt without dragging them one by one?"),
    L:G("move all at once"),
    L:G("Moving or Selling a Whole Section")
  },
  settings = { "categorySell" },
  related = { "confirm-sale", "auto-deposit", "next-dragging" },
  body = {
    { text = L:G("Right-click a section's title to move everything in it to the window you have open: your bags, the bank, the mailbox or a trade.") },
    { text = L:G("At a vendor, this sells up to 10 of the section's items at a time, so you can still buy them back. It works only if Enable Category Sell and Deposit on the General page is on.") },
    { setting = "categorySell" },
    { heading = L:G("BetterBags Next") },
    { text = L:G("Drag a section by its title onto the other bag, or one of its tabs, to move everything in it there. Drop it on the vendor to sell it: at once when it holds 12 items or fewer, or after a double click when it holds more.") },
  },
})

articles:Define({
  id = "skip-recent", group = "automation",
  title = L:G("Skip Recent Items"),
  summary = L:G("Sending new items straight to their category instead of Recent Items."),
  keywords = { L:G("skip recent"), L:G("recent items"), L:G("new items"), L:G("not new"),
    L:G("skip recent items"), L:G("bypass new items"), L:G("disable recent category"), L:G("no recent items"),
    L:G("new item highlight")
  },
  questions = { L:G("How do I keep some items out of Recent Items?"), L:G("Why does my junk show in Recent Items?"),
    L:G("How do I stop new loot from going into Recent Items?"),
    L:G("Can I make a category skip Recent Items when I pick something up?"),
    L:G("Why do new drops go into Recent Items instead of their own category?"),
    L:G("How do I send newly looted items straight to their real section?"),
    L:G("How do I turn off Recent Items for certain categories?"), L:G("What does Skip Recent Items do?")
  },
  related = { "recent-items", "auto-sell" },
  body = {
    { text = L:G("Skip Recent Items, under Recent Items on a category's Automation tab, sends new items for that category straight to it. They show there at once and are no longer marked new.") },
    { text = L:G("It works on any category, even if it does not sell or deposit.") },
  },
})
