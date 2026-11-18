local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class HelpArticles: AceModule
local articles = addon:GetModule('HelpArticles')

articles:Group({ id = "automation", title = L:G("Automation") })

articles:Define({
  id = "auto-sell", group = "automation", featured = true,
  title = L:G("Auto Sell"),
  summary = L:G("Automatic selling at merchants and vendor confirmation"),
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
    { text = L:G("Auto Sell sells a category's backpack items when you visit a merchant. Because Confirm Auto Sell is on by default, opening a merchant sells nothing immediately unless you turn Confirm Auto Sell off: in BetterBags Next with Enable Vendor Window on, confirming categories wait in the vendor window for your confirmation, while in the classic bags (or with Enable Vendor Window off), confirming categories are not sold on merchant open.") },
    { heading = L:G("Automation Tab") },
    { text = L:G("Open the Settings Window, select Categories, choose a category, and open its Automation tab. Unconverted Blizzard Category entries have no Automation tab, and equipment set categories hide the Merchants and Bank sections.") },
    { list = {
      L:G("Auto Sell (Merchants section): Enables selling for the category's backpack items at merchants."),
      L:G("Confirm Auto Sell (Merchants section): On by default, disabled while Auto Sell is off. While on, items wait for confirmation instead of selling when the merchant opens; turn this off to sell as soon as a merchant opens."),
      L:G("Destroy What Can't Be Sold (Merchants section): Disabled while Auto Sell is off, and turns off if you disable Auto Sell. Marks items in the category that no merchant buys for one-at-a-time destruction."),
      L:G("Auto Deposit and Deposit Into (Bank section): Deposits the category's backpack items into your bank (or Warbank on retail) when the bank opens."),
      L:G("Skip Recent Items (Recent Items section): Sends items assigned to the category straight to its section instead of Recent Items."),
    } },
    { setting = "categorySell" },
    { heading = L:G("Merchant Behavior") },
    { text = L:G("What happens when you talk to a merchant depends on Confirm Auto Sell and your bag design:") },
    { list = {
      L:G("Confirm Auto Sell off: BetterBags starts selling the category's backpack items immediately when the merchant opens, including newly looted items still shown in Recent Items. Hold Shift while opening the merchant to skip this immediate sale."),
      L:G("Confirm Auto Sell on in BetterBags Next (with Enable Vendor Window on): Each confirming category whose section is visible in the backpack's current view moves to the vendor window to wait for your double-click, once per merchant visit. Categories on other group tabs or items shown only in Recent Items do not move over, and holding Shift on merchant open does not skip docking them."),
      L:G("Confirm Auto Sell on in the classic bags (or with Enable Vendor Window off): Nothing sells automatically when the merchant opens. To sell a category manually there, enable Enable Category Sell and Deposit (General page, General tab, Items section; off by default) and right-click the section title. Right-clicking a section title sells at most 10 items per click and checks only whether items are locked, refundable, or buyable, without Auto Sell protections such as equipment sets."),
    } },
    { heading = L:G("Protected Items") },
    { text = L:G("Auto Sell acts only on backpack items and never sells items in any equipment set, items that can still be refunded, items merchants do not buy, or items whose data or upgrade status has not loaded yet. If an item's upgrade status is still pending when a merchant opens, an immediate sale waits up to 10 seconds before starting.") },
    { text = L:G("BetterBags also skips selling at merchants that buy nothing and skips any item a merchant has already refused. Refused items are remembered for that merchant for the rest of your session, or for that visit only when inside a dungeon or raid.") },
    { heading = L:G("Sale Pace") },
    { text = L:G("Every sale sends one item at a time at an interval equal to the larger of your home and world latency, and at least 0.2 seconds, pausing if your cursor holds an item. If the game reports That object is busy., BetterBags moves that item to the end of the queue after a skipped beat and sends it up to 3 times in total, including the first attempt.") },
    { text = L:G("BetterBags prints a chat summary of items sold and gold received only for the immediate sale that runs when a merchant opens, not for sales confirmed in the vendor window or started by right-clicking a section title.") },
    { open = { page = "categories", tab = "automation", text = L:G("Open Category Automation") } },
    { see = "confirm-sale" },
    { see = "destroy" },
    { see = "move-category" },
  },
})

articles:Define({
  id = "confirm-sale", group = "automation",
  title = L:G("Confirm Auto Sell"),
  summary = L:G("Confirmation for automatic and dragged section sales"),
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
    { text = L:G("Confirm Auto Sell is on by default whenever you turn on Auto Sell on a category's Automation tab on the Categories page. While Confirm Auto Sell is on, items in that category do not sell on their own when you open a merchant.") },
    { heading = L:G("Vendor Dock") },
    { text = L:G("In BetterBags Next with Enable Vendor Window on, qualifying Backpack sections dock in glowing cards in the Vendor window so you can review and confirm each sale.") },
    { list = {
      L:G("Sections dock only while both the Vendor window and your Backpack are open; if you open your Backpack later during the same merchant visit, qualifying sections dock then."),
      L:G("A category docks only if its section is in the Backpack's current view rather than on another group tab, its items are not all in Recent Items, and it holds items Auto Sell would sell to this merchant now."),
      L:G("In Show Blizzard Bags, a bag's section docks when that bag holds items a Confirm Auto Sell category would sell to this merchant now."),
      L:G("A category with Destroy What Can't Be Sold on that holds unsellable items docks as a red destroy card even when it has nothing to sell, regardless of Confirm Auto Sell."),
      L:G("Sections dock once per merchant visit, and dock again if the Vendor window returns from TradeSkillMaster's window during that visit."),
    } },
    { text = L:G("Double-click a waiting sale card to sell its items one at a time (a single click does nothing for a sale), or right-click the card to cancel and return the section to your Backpack until the visit ends or the Vendor window returns from TradeSkillMaster's window. When more than 12 items are queued, the card warns that only the last 12 items sold can be bought back.") },
    { text = L:G("After a sale ends, if the category also has Destroy What Can't Be Sold on and still holds unsellable items, the card stays docked and turns red for destroying. Otherwise, if any items from the section remain in your Backpack (such as refused items, unsellable items, equipment set items, or refundable purchases), the section returns to your Backpack; if everything sold, the section moves into the Vendor window.") },
    { heading = L:G("Blizzard Vendor") },
    { text = L:G("In the classic bags, or in BetterBags Next with Enable Vendor Window off, Blizzard's merchant window has no sell dock, so categories with Confirm Auto Sell on do not sell on their own. To sell a section from your bags there, turn on Enable Category Sell and Deposit (off by default) and right-click the section's title.") },
    { setting = "categorySell" },
    { text = L:G("Each right-click sells at most 10 stacks from that section, and in BetterBags Next the right-click sells the section only when your cursor holds no item.") },
    { heading = L:G("Dragged Sections") },
    { text = L:G("In BetterBags Next with Enable Vendor Window on, you can drag any category section from your Backpack by its header onto the Vendor window to sell the items in it that the merchant buys, leaving out refundable purchases and items this merchant refused. Recent Items and Free Space cannot be dragged, and sections cannot be dragged in Show Blizzard Bags.") },
    { list = {
      L:G("A dragged section with 12 or fewer sellable items starts selling as soon as it docks."),
      L:G("A dragged section with more than 12 sellable items waits in a card until you double-click to sell or right-click to cancel."),
    } },
    { see = "auto-sell" },
    { see = "next-vendor" },
    { see = "move-category" },
  },
})

articles:Define({
  id = "destroy", group = "automation",
  title = L:G("Item Destruction"),
  summary = L:G("Deletion of unsellable backpack items"),
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
    { text = L:G("Destroy What Can't Be Sold, under Merchants on a category's Automation tab on the Categories page, marks unsellable items in your Backpack so you can delete them one stack at a time. Destroy What Can't Be Sold requires Auto Sell to be on, and turning Auto Sell off turns Destroy What Can't Be Sold off as well. Unconverted sections under Blizzard Categories show only the Blizzard Category tab until you click Convert to Category, and equipment set categories hide the Merchants section on Automation.") },
    { list = {
      L:G("BetterBags queues only items in your Backpack that no merchant buys, ignoring Recent Items when determining each item's category."),
      L:G("BetterBags skips items whose data has not loaded yet, items whose upgrade state is not known yet, refundable purchases, and items in an equipment set."),
      L:G("BetterBags never queues items that a merchant buys."),
    } },
    { heading = L:G("Vendor Card") },
    { text = L:G("In BetterBags Next with Enable Vendor Window on, each Backpack category section in the current view that holds queued items docks in a red card in the Vendor window while both your Backpack and the Vendor window are open. In Show Blizzard Bags, a bag's section docks in the Vendor window when that bag holds queued items. Sections hidden on another group tab or whose items are all in Recent Items do not dock.") },
    { list = {
      L:G("A section that also holds items waiting for Confirm Auto Sell docks as a sale card first and turns red only after that sale ends."),
      L:G("Hover over the red card to inspect the next stack queued for destruction."),
      L:G("Each click on the red card destroys the next queued stack in that section; a double-click counts as two clicks and destroys two stacks."),
      L:G("Right-click the red card to return the section to your Backpack for the rest of that merchant visit, or until the Vendor window returns from TradeSkillMaster's window."),
      L:G("Once no queued items remain in the section, the section leaves the card and moves into the Vendor window."),
    } },
    { text = L:G("In the classic bags, or in BetterBags Next with Enable Vendor Window off, no Vendor dock exists, so use the Destroy Next Item key binding instead.") },
    { heading = L:G("Key Binding") },
    { text = L:G("Bind Destroy Next Item under BetterBags in the game's Key Bindings menu to destroy queued items anywhere, at a merchant or away from one, in either bag design. Each press destroys the next queued stack in your Backpack across all categories with Destroy What Can't Be Sold on.") },
    { heading = L:G("Restrictions") },
    { text = L:G("World of Warcraft permits an addon to destroy only one stack per click or key press. BetterBags checks whether you are in combat or holding an item on your cursor, refuses to destroy in either state, and prints a message in chat.") },
    { warning = L:G("Destroyed items are deleted permanently and cannot be recovered from Buyback.") },
    { open = { page = "categories", tab = "automation", text = L:G("Open Category Automation") } },
    { see = "auto-sell" },
    { see = "confirm-sale" },
    { see = "slash-commands" },
  },
})

articles:Define({
  id = "auto-deposit", group = "automation",
  title = L:G("Auto Deposit"),
  summary = L:G("Automatic deposits into your bank or Warbank"),
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
    { text = L:G("When Auto Deposit is turned on in the Bank section on a category's Automation tab on the Categories page, BetterBags deposits that category's items from your Backpack whenever you open the bank. Auto Deposit checks each item in your Backpack by its underlying category without Recent Items, so newly looted items in that category deposit as well.") },
    { text = L:G("Deposits run as soon as the bank opens without a confirmation card, in both the classic bags and BetterBags Next. Hold Shift while opening the bank to skip Auto Deposit for that visit.") },
    { heading = L:G("Bank Selection") },
    { text = L:G("Unconverted Blizzard Categories have no Automation tab, and Equipment Set categories hide the Bank section. On retail, Deposit Into selects between Bank, the default, and Warbank; Deposit Into is disabled while Auto Deposit is off.") },
    { text = L:G("On WoW: Forever, Classic Era, The Burning Crusade Anniversary, and Mists of Pandaria Classic, Deposit Into does not appear and Auto Deposit always sends items to your character bank, even for a category imported from retail with Warbank selected.") },
    { heading = L:G("Warbank Refusals") },
    { text = L:G("When Deposit Into is set to Warbank, items the Warbank does not accept remain in your Backpack instead of moving into your character bank. If another character on your account is using the Warbank, BetterBags skips Warbank deposits.") },
    { text = L:G("After depositing, BetterBags prints the number of items sent to each bank in chat. That count includes every item BetterBags sent, including any item a full bank refuses.") },
    { heading = L:G("Skipped Items") },
    { list = {
      L:G("Purchases you can still refund stay in your Backpack."),
      L:G("Items whose item data or upgrade state has not loaded yet when the bank opens stay in your Backpack until your next visit."),
      L:G("On retail, WoW: Forever, and Mists of Pandaria Classic, items in an equipment set are never deposited automatically."),
    } },
    { heading = L:G("Combined Automation") },
    { text = L:G("Auto Deposit and Auto Sell are separate settings, so you can enable both on the same category. At the bank, Auto Deposit transfers the category's items when the bank opens, and at a merchant, Auto Sell applies.") },
    { list = {
      L:G("With Confirm Auto Sell turned off, BetterBags sells the category's items as soon as the merchant opens unless you hold Shift."),
      L:G("With Confirm Auto Sell turned on (the default) in BetterBags Next with Enable Vendor Window on, BetterBags docks the category's section in the Vendor window only while your Backpack is open and only if the category has a section in your Backpack's current view."),
      L:G("In the classic bags, or in BetterBags Next with Enable Vendor Window off, no vendor dock exists, so a category with Confirm Auto Sell turned on does not sell on its own at a merchant."),
    } },
    { open = { page = "categories", tab = "automation", text = L:G("Open Category Automation") } },
    { see = "warbank" },
    { see = "bank-basics" },
    { see = "move-category" },
  },
})

articles:Define({
  id = "move-category", group = "automation",
  title = L:G("Section Moves"),
  summary = L:G("Transfers and sales of whole bag sections"),
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
    { text = L:G("Right-clicking a section title, or dragging a section in BetterBags Next, acts on the whole section at once, including extra piles hidden inside merged stacks, subject to each target window's limits.") },
    { heading = L:G("Title Right-Click") },
    { text = L:G("In both bag designs, right-clicking a section title moves its items to the open target window. In the classic bags, right-clicking a title runs even if your cursor holds an item; in BetterBags Next, your cursor must be empty, and right-clicking the Free Space header does nothing.") },
    { list = {
      L:G("Bank: Moves Backpack sections into your Bank and Bank sections into your Backpack. On retail, when your Bank displays the Warbank, right-clicking a Backpack section moves its items into the Warbank."),
      L:G("Guild Bank: No right-click moves items into the Guild Bank. In BetterBags Next with Enable Guild Bank Window on, right-clicking a Guild Bank section title in the items view withdraws its items to your Backpack."),
      L:G("Mailbox: Moves the section's items into outgoing mail slots while the Send Mail frame is visible."),
      L:G("Trade: Moves the section's items into the trade window while a trade is open."),
    } },
    { heading = L:G("Vendor Right-Click") },
    { text = L:G("With Enable Category Sell and Deposit on, right-clicking a section title at a merchant sells at most 10 stacks from that section, one at a time. Enable Category Sell and Deposit is off by default and affects only vendor right-clicks; right-click transfers to your Bank, mailbox, and trade window work regardless of this setting.") },
    { setting = "categorySell" },
    { heading = L:G("Section Dragging") },
    { text = L:G("In BetterBags Next, drag any category section by its header to reorder it, assign it to a group tab, move its items to another open bag, or sell its items at the Vendor window. Recent Items and Free Space cannot be dragged, and dragging is disabled in bag-by-bag views: Show Blizzard Bags, the Bank with Show Bank Tabs on, and the Guild Bank showing a single tab.") },
    { list = {
      L:G("Reordering and grouping: Drop a section on its own bag body to reorder it, or drop a section on another group tab in the same bag to assign its category to that group; every group tab appears during a drag even if Hide Empty Groups is on. Neither action moves items."),
      L:G("Bank transfers: Drag a section between your Backpack and your Bank to move its items. Dropping on a group tab or on the Bank body while groups are shown also assigns the category to that group, whereas dropping on a bank tab with Show Bank Tabs on moves the items into that bank type without assigning a group."),
      L:G("Guild Bank transfers: With Enable Guild Bank Window on, drag a Backpack section onto the Guild Bank body or a guild tab you can deposit into to deposit its unbound items; if you cannot withdraw from that tab, the section docks in a confirmation card until you double-click to deposit or right-click to cancel. Drag a Guild Bank section onto your Backpack to withdraw its items."),
      L:G("Vendor sales: With Enable Vendor Window on, drop a Backpack section on the Vendor window to sell items the merchant buys, excluding refundable purchases and items this merchant refused. A section with 12 or fewer sellable items starts selling immediately; a section with more than 12 docks in a card until you double-click to confirm or right-click to cancel."),
    } },
    { see = "confirm-sale" },
    { see = "auto-deposit" },
    { see = "next-dragging" },
  },
})

articles:Define({
  id = "skip-recent", group = "automation",
  title = L:G("Skip Recent Items"),
  summary = L:G("Bypassing Recent Items for specific categories"),
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
    { text = L:G("Skip Recent Items, under Recent Items on a category's Automation tab on the Categories page, sends new items assigned to that category straight to the category's section instead of Recent Items. It works independently of Auto Sell and Auto Deposit in both the classic bags and BetterBags Next.") },
    { heading = L:G("Eligible Categories") },
    { text = L:G("The Automation tab is available for your own categories, converted Blizzard categories, plugin categories, and equipment set categories. Built-in Blizzard Categories that have not been converted do not have an Automation tab.") },
    { text = L:G("Skip Recent Items applies only in the bags where that category is enabled under Used In on the category's Settings tab.") },
    { heading = L:G("Item Behavior") },
    { text = L:G("When an item lands in a category with Skip Recent Items turned on, BetterBags ends its new-item timer, clears the game's new-item flag and glow, and places the item directly in the category. Turning Skip Recent Items on moves any matching items already in Recent Items out immediately, while turning it off affects only future items.") },
    { tip = L:G("If an item's upgrade check has not finished yet, BetterBags keeps the item in Recent Items until the check completes.") },
    { open = { page = "categories", tab = "automation", text = L:G("Open Category Automation") } },
    { see = "recent-items" },
  },
})
