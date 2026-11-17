local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class HelpArticles: AceModule
local articles = addon:GetModule('HelpArticles')

articles:Group({ id = "bags", title = L:G("Your Bags") })

articles:Define({
  id = "sections", group = "bags",
  title = L:G("Sections"),
  summary = L:G("How your bags sort items into sections, and where each section comes from."),
  keywords = { L:G("section"), L:G("category"), L:G("grid"), L:G("header"), L:G("title"), L:G("built-in"), L:G("automatic"),
    L:G("free space"),
    L:G("item categories"), L:G("AdiBags sections"), L:G("category priority"), L:G("auto grouping"),
    L:G("headers"),
    L:G("item grouping"),
    L:G("Sections and Categories")
  },
  questions = { L:G("Why are my items split into groups?"), L:G("Where do sections come from?"),
    L:G("Why does my item show under Armor - Plate?"),
    L:G("How does BetterBags group my items into sections?"), L:G("Why did an item go into the wrong category?"),
    L:G("Which category wins if an item matches more than one?"), L:G("Where do the default sections come from?"),
    L:G("How do categories work compared to AdiBags?"), L:G("Why is my gear in a different section than I expected?"),
    L:G("how items are grouped"),
    L:G("How does BetterBags decide which section an item goes in?")
  },
  related = { "categories-intro", "section-order", "item-order", "blizzard-categories" },
  body = {
    { text = L:G("Each section in your bags is a category, with its name on top and its items under it. An item shows in one section only.") },
    { heading = L:G("Section Sources") },
    { list = {
      L:G("Your own categories: what you add to them by hand, or what their search rule finds."),
      L:G("Your equipment sets: each set is a category named Gear: followed by the set's name."),
      L:G("Categories from plugins you have installed."),
      L:G("Blizzard's item types: anything no other category takes goes into a section named after its type, such as Consumable or Armor, and its subtype and expansion when you turn them on, as in Armor - Plate - Classic."),
    } },
    { text = L:G("Recent Items, the items you just got, shows first. Free Space, your empty slots, shows last.") },
    { heading = L:G("Section Ordering") },
    { text = L:G("When an item fits more than one category, the one higher in the list on the Categories page wins. An item you added to a category by hand stays in that category.") },
    { see = "categories-intro" },
  },
})

articles:Define({
  id = "bag-menu", group = "bags",
  title = L:G("Bag Menu"),
  summary = L:G("What the bag button and the buttons at the top of your bags do."),
  keywords = { L:G("bag button"), L:G("menu"), L:G("header"), L:G("top left"), L:G("buttons"), L:G("context menu"),
    L:G("close button"), L:G("settings button"),
    L:G("header icons"), L:G("top buttons"), L:G("bag icon"), L:G("toolbar buttons"),
    L:G("clickable icons")
  },
  questions = { L:G("What does the bag button do?"), L:G("Where is the bag menu?"), L:G("What are the buttons at the top of my backpack?"),
    L:G("What do the buttons at the top of my bag do?"), L:G("What does the icon in the top corner of my bags open?"),
    L:G("How do I know what each header button is for?"), L:G("Where did the bag menu go in BetterBags Next?"),
    L:G("How do I reach bag actions from the title bar?"),
    L:G("icons along the top"),
    L:G("The Bag Menu and Header Buttons")
  },
  related = { "sorting", "show-bags", "anchors", "next-panels" },
  body = {
    { heading = L:G("Classic Bags") },
    { text = L:G("The round bag button at the top left of the backpack and the bank does several things:") },
    { list = {
      L:G("Left-click opens the bag menu."),
      L:G("Right-click sorts the bag."),
      L:G("Shift-left-click opens the search."),
      L:G("With an item on your cursor, left-click makes a new category for it."),
    } },
    { text = L:G("The backpack's menu holds Drag to Resize, Show Bags, Show Bag Button, Bag Anchor, Switch to Next, What's New and Open Options Screen. The bank's menu holds Drag to Resize, Show Bags, Bag Anchor, Sort Bank, What's New and Open Options Screen, and with a Warband bank, Clean Up Warbank and the Warbank's deposit options.") },
    { heading = L:G("BetterBags Next") },
    { text = L:G("The buttons along the top of the backpack close it, open the settings, show its anchor, show your bags themselves (Show Blizzard Bags), and switch every bag between small and full size. Right-click a bag's title to sort it. Some themes gather these buttons into a menu behind a bag button of their own.") },
  },
})

articles:Define({
  id = "sorting", group = "bags",
  title = L:G("Sorting"),
  summary = L:G("How to sort your backpack and your bank."),
  keywords = { L:G("sort"), L:G("clean up"), L:G("organize"), L:G("tidy"), L:G("stack"), L:G("SortBags"),
    L:G("clean up bags"), L:G("sort button"), L:G("organize inventory"), L:G("bank sort"),
    L:G("Sorting Your Bags")
  },
  questions = { L:G("How do I sort my bags?"), L:G("How do I sort the bank?"), L:G("Why does sorting do nothing on Classic?"),
    L:G("How do I sort my backpack?"), L:G("How do I clean up and organize my bank?"),
    L:G("Where is the sort button?"), L:G("Why aren't my bags sorting in the order I expect?"),
    L:G("Does BetterBags use Blizzard's bag sort?"), L:G("Can I sort my bags automatically?")
  },
  related = { "item-order", "section-order", "bag-menu", "warbank" },
  body = {
    { text = L:G("Sorting moves your items between your bag slots, the way the game's own Clean Up Bags does. Inside a section, items are always shown in the order you choose on the bag's Layout tab, sorted or not.") },
    { list = {
      L:G("Classic bags: right-click the bag button at the top left."),
      L:G("BetterBags Next: right-click the bag's title."),
      L:G("At the bank, doing the same sorts the bank, or the Warband bank while you view it."),
    } },
    { warning = L:G("On classic versions of the game, sorting uses the SortBags addon. Install it to sort your bags there.") },
    { see = "item-order" },
  },
})

articles:Define({
  id = "section-layout", group = "bags", design = "next",
  title = L:G("Section Columns"),
  summary = L:G("Laying your sections out side by side in BetterBags Next."),
  keywords = { L:G("columns"), L:G("section columns"), L:G("compact"), L:G("gap"), L:G("fill order"), L:G("wide sections"),
    L:G("side by side"), L:G("layout"),
    L:G("grid columns"), L:G("bag layout"),
    L:G("single column"), L:G("one tall column")
  },
  questions = { L:G("How do I show sections side by side?"), L:G("How do I make my bags more compact?"),
    L:G("Why does one section take two columns?"),
    L:G("How do I put sections side by side in BetterBags Next?"),
    L:G("How do I change how many columns of sections my bags show?"),
    L:G("Why are all my sections stacked in one tall column?"),
    L:G("How do I make my bag window wider instead of taller?"),
    L:G("Can I change the layout of sections in my backpack and bank?"),
    L:G("My sections look cramped across the window"),
    L:G("next to each other"), L:G("How do I put sections next to each other?"),
    L:G("Section Columns and Layout")
  },
  settings = { "sectionColumns", "sectionCompact", "sectionGap", "sectionFill", "sectionSpan", "sectionWideRows" },
  pages = { "backpack:layout", "bank:layout", "guild:layout" },
  related = { "next-size", "section-order", "free-space" },
  body = {
    { text = L:G("In BetterBags Next, each bag lists its sections in columns. These settings are on each bag's Layout tab, under Sections, and each bag keeps its own.") },
    { list = {
      L:G("Section Columns sets how many columns of sections sit side by side. A bag too narrow for them shows fewer."),
      L:G("Compact Sections packs sections as tightly as their icons and names allow, placing as many side by side as fit and filling any space beside taller sections. Every icon stays on the bag's grid, and no name is cut short."),
      L:G("Gap Between Sections leaves one empty icon space between sections that sit side by side, so each stands apart."),
      L:G("Fill Order fills columns left to right before starting a new row (Side to Side), or down one column before moving to the next (Top to Bottom)."),
      L:G("Wide Sections Span Columns lets a long section take more than one column, so it does not run far down a single one."),
      L:G("Wide Column Limit sets how many rows in one column make a section wide. At 2, any section longer than one row spans out."),
    } },
    { setting = "sectionColumns", bag = "Backpack" },
    { setting = "sectionCompact", bag = "Backpack" },
    { open = { page = "backpack", tab = "layout", text = L:G("Open the Backpack's Layout tab") } },
  },
})

articles:Define({
  id = "classic-window", group = "bags", design = "classic",
  title = L:G("Classic Window"),
  summary = L:G("Sizing the classic bags: items per row, columns, opacity, scale and resizing."),
  keywords = { L:G("size"), L:G("resize"), L:G("items per row"), L:G("columns"), L:G("opacity"), L:G("scale"),
    L:G("transparent"), L:G("drag to resize"), L:G("snap"), L:G("fade"), L:G("animation"),
    L:G("window opacity"), L:G("classic scale"), L:G("background transparency")
  },
  questions = { L:G("How do I make my bags bigger?"), L:G("How do I change how many items are in a row?"),
    L:G("How do I make the bag background transparent?"), L:G("How do I resize the bag window?"),
    L:G("How do I change how many items fit in a row in classic bags?"),
    L:G("How do I make the classic bag window transparent?"), L:G("How do I resize the classic bag window?"),
    L:G("How do I change the scale and columns of classic bags?"),
    L:G("Why does my classic bag window animate when it changes size?"),
    L:G("Can I turn off window motion in the classic design?"),
    L:G("The Classic Bags' Window")
  },
  settings = { "resizableWindow", "snapToContent", "itemsPerRow", "columns", "opacity", "scale", "fullSectionNames",
    "bagFading", "animateItemMovement" },
  pages = { "backpack:layout", "bank:layout" },
  related = { "anchors", "section-order", "bag-menu" },
  body = {
    { text = L:G("The classic backpack and bank each have these settings on their Layout tab, under Window and Sections.") },
    { list = {
      L:G("Items Per Row sets how many items fit across one section."),
      L:G("Columns sets how many sections sit side by side."),
      L:G("Opacity sets how see-through the window's background is."),
      L:G("Scale sets the size of the whole window."),
      L:G("Show Full Section Names shows each section's whole name instead of cutting it short."),
    } },
    { heading = L:G("Manual Sizing") },
    { text = L:G("With Resizable Window on, you resize the bag by dragging its corner, and its sections fill the window. When it is off, the bag sizes itself to fit its items, Items Per Row wide. Drag to Resize in the bag menu turns the same setting on and off.") },
    { text = L:G("Snap to Content shrinks the window to fit its items when you let go after resizing it, so no empty space is left at its sides or below them.") },
    { setting = "resizableWindow", bag = "Backpack" },
    { heading = L:G("Motion") },
    { text = L:G("On the General page, Enable Bag Fading fades the bags in and out as they open and close, and Animate Item Movement glides items, sections and rows to their new places when the bags rearrange.") },
    { open = { page = "backpack", tab = "layout", text = L:G("Open the Backpack's Layout tab") } },
  },
})

articles:Define({
  id = "section-order", group = "bags",
  title = L:G("Section Order"),
  summary = L:G("Choosing which sections show first: sorting them, and pinning the ones you want on top."),
  keywords = { L:G("section order"), L:G("pin"), L:G("pinned"), L:G("top"), L:G("alphabetical"), L:G("size"), L:G("reorder"),
    L:G("move section"), L:G("hide section"), L:G("show section"),
    L:G("pin section"), L:G("section priority"), L:G("sort categories"), L:G("top sections")
  },
  questions = { L:G("How do I put a section at the top?"), L:G("How do I change the order of my categories?"),
    L:G("How do I hide a section?"), L:G("How do I sort sections alphabetically?"),
    L:G("How do I put my favorite sections at the top of my bags?"),
    L:G("How do I pin a category so it always shows first?"), L:G("How do I change the order my sections appear in?"),
    L:G("Why does a section keep moving around?"), L:G("Can I sort sections alphabetically or by size?"),
    L:G("How do I move Recent Items or Hearthstone to the top?"),
    L:G("The Order of Your Sections")
  },
  settings = { "sectionOrder" },
  pages = { "backpack:order", "bank:order", "guild:order" },
  related = { "next-dragging", "sections", "item-order", "category-settings" },
  body = {
    { text = L:G("Each bag decides the order of its own sections.") },
    { list = {
      L:G("Section Order, on a bag's Layout tab, sorts the sections you have not pinned: Alphabetically, Size Descending or Size Ascending."),
      L:G("A bag's Order tab lists its categories under Pinned and Other Categories. Shift-click a category to pin or unpin it: pinned categories show first, in the order you drag them into."),
      L:G("A name that is no longer a category, such as one you deleted, shows Remove. Remove takes the name off the list, along with the pins and tabs it had in every bag."),
    } },
    { text = L:G("To keep a category out of a bag altogether, choose the bags it is used in on its Settings tab on the Categories page.") },
    { tip = L:G("In BetterBags Next, you can also drag a section by its title and drop it where you want it. It stays there.") },
    { setting = "sectionOrder", bag = "Backpack" },
    { open = { page = "backpack", tab = "order", text = L:G("Open the Backpack's Order tab") } },
  },
})

articles:Define({
  id = "item-order", group = "bags",
  title = L:G("Item Order"),
  summary = L:G("How the items inside each section are ordered, and how to change it."),
  keywords = { L:G("item order"), L:G("sort items"), L:G("then by"), L:G("quality"), L:G("item level"), L:G("name"),
    L:G("equipment slot"), L:G("upgrade track"), L:G("sell price"), L:G("item type"),
    L:G("item sorting"), L:G("sort by ilvl"), L:G("sort by quality"), L:G("alphabetical items"),
    L:G("line up")
  },
  questions = { L:G("How do I sort items by item level?"), L:G("How do I put my best gear first?"),
    L:G("How are items ordered inside a section?"),
    L:G("How do I change the order of items inside a section?"),
    L:G("Can I sort items inside categories by item level or rarity?"),
    L:G("Why are items inside my sections in a weird order?"),
    L:G("How do I sort items alphabetically inside each category?"),
    L:G("Can I sort gear by highest item level first?"),
    L:G("How do I keep items in the same order inside a section?"),
    L:G("sort within a section"),
    L:G("The Order of Items in a Section")
  },
  settings = { "itemOrder", "itemOrderThen", "itemOrderLast" },
  pages = { "backpack:layout", "bank:layout", "guild:layout" },
  related = { "category-item-order", "section-order", "sorting" },
  body = {
    { text = L:G("On a bag's Layout tab, under Order, three dropdowns set how the items in each section line up.") },
    { list = {
      L:G("Item Order sets what items are ordered by first: quality, name, item level, Equipment Slot (as on your character sheet), Item Type, Upgrade Track (Myth first, then Hero, Champion and so on), Sell Price, and more."),
      L:G("Then By breaks the ties Item Order leaves."),
      L:G("And Then By breaks the ties Then By leaves."),
    } },
    { text = L:G("Items that are still equal go by name, with the bigger pile first.") },
    { setting = "itemOrder", bag = "Backpack" },
    { tip = L:G("You can give a category its own item order across every bag on its Item Order tab on the Categories page.") },
    { see = "category-item-order" },
  },
})

articles:Define({
  id = "free-space", group = "bags",
  title = L:G("Free Space"),
  summary = L:G("How your empty bag slots show, and keeping a gap where an item was."),
  keywords = { L:G("free space"), L:G("empty slots"), L:G("free slots"), L:G("gaps"), L:G("reagent bag"), L:G("space left"),
    L:G("bag spaces"), L:G("slot gaps"), L:G("remaining space"),
    L:G("empty squares")
  },
  questions = { L:G("How many free slots do I have?"), L:G("How do I see every empty slot?"),
    L:G("Why does an empty space stay where I sold an item?"),
    L:G("How do I see all my empty bag slots instead of one icon?"),
    L:G("Why is there an empty gap left where an item used to be?"),
    L:G("How do I turn off empty slot gaps when I move or sell things?"),
    L:G("Why do my bags only show one slot for free space?"), L:G("Can I see how many free slots I have left?"),
    L:G("How do I stop items from shifting around when I sell something?"),
    L:G("Free Space and Gaps")
  },
  settings = { "showAllFreeSpace", "preserveGaps" },
  pages = { "backpack:layout", "bank:layout", "guild:layout" },
  related = { "sections", "show-bags" },
  body = {
    { text = L:G("Free Space, the last section of a bag, shows your empty slots. By default, each kind of bag shows one icon with the number of free slots it has: one for your regular bags, and one for a reagent bag or profession bag.") },
    { list = {
      L:G("Show All Free Space Slots shows every empty slot as its own icon instead. Slots in special bags are edged in their bag's color."),
      L:G("Preserve Empty Slots as Gaps keeps an empty space where an item was used, sold or moved, until you close the bag or sort it, so nothing jumps around while you work. New items go elsewhere and never fill the gap."),
    } },
    { text = L:G("Both settings are on each bag's Layout tab, under Slots.") },
    { setting = "showAllFreeSpace", bag = "Backpack" },
    { setting = "preserveGaps", bag = "Backpack" },
  },
})

articles:Define({
  id = "stacking", group = "bags",
  title = L:G("Stacking"),
  summary = L:G("Showing multiple stacks of an item as one button, and when not to."),
  keywords = { L:G("stack"), L:G("merge"), L:G("combine"), L:G("partial stacks"), L:G("transmog"), L:G("unmerge"),
    L:G("unstackable"), L:G("duplicates"),
    L:G("merge stacks"), L:G("virtual stacks"), L:G("combine icons"), L:G("unstack items"),
    L:G("Stacking and Merging")
  },
  questions = { L:G("How do I combine stacks into one button?"), L:G("Why are my stacks not merged?"),
    L:G("Why did my stacks split at the vendor?"),
    L:G("How do I combine multiple stacks of the same item into one icon?"),
    L:G("Why do five stacks of cloth show as one button in my bags?"),
    L:G("How do I turn off stack merging so I see every real stack?"),
    L:G("Can I keep unstackable items or certain bags from merging?"),
    L:G("Why does the count on an item look higher than one stack?"), L:G("How do I split or disable merged stacks?")
  },
  settings = { "mergeStacks", "mergeUnstackable", "dontMergePartial", "dontMergeTransmog", "unmergeAtShop" },
  pages = { "backpack:items", "bank:items", "guild:items" },
  related = { "recent-items", "item-buttons" },
  body = {
    { text = L:G("These settings are on each bag's Items tab, under Stacking. They change only how stacks are shown, never where the items are.") },
    { list = {
      L:G("Merge Stacks shows every stack of an item as one button with the total count."),
      L:G("Merge Unstackable does the same for items that do not stack, such as armor and weapons."),
      L:G("Don't Merge Partial Stacks keeps a stack that is not full separate from the others."),
      L:G("Split Transmogged Items gives transmogged items a button of their own."),
      L:G("Unmerge on Interactions splits merged buttons apart while you are at a vendor, mailbox, auction house or the like, so you can pick the stack you want."),
    } },
    { setting = "mergeStacks", bag = "Backpack" },
  },
})

articles:Define({
  id = "item-buttons", group = "bags",
  title = L:G("Item Buttons"),
  summary = L:G("What item buttons show: item levels, a quality border or glow, and keystone levels."),
  keywords = { L:G("item level"), L:G("ilvl"), L:G("glow"), L:G("quality"), L:G("border"), L:G("rarity color"),
    L:G("keystone"), L:G("mythic plus"), L:G("extra glowy"),
    L:G("ilvl text"), L:G("rarity border"), L:G("keystone level"), L:G("item glow")
  },
  questions = { L:G("How do I show item levels on my items?"), L:G("How do I turn off the glow around items?"),
    L:G("How do I see my keystone's level?"), L:G("How do I make items glow more?"),
    L:G("How do I show item levels on gear in my bags?"),
    L:G("How do I turn off the colored quality border around items?"),
    L:G("Can BetterBags show Mythic+ keystone levels on the key icon?"),
    L:G("Why aren't item levels showing on my gear?"),
    L:G("How do I adjust the glow or border on rare and epic items?"),
    L:G("Can I hide item level numbers on low level items?"),
    L:G("Item Level, Quality Glow and Keystones")
  },
  settings = { "itemLevel", "itemLevelColor", "keystoneLevel", "glowIntensity" },
  pages = { "backpack:items", "bank:items", "guild:items" },
  related = { "item-colors", "upgrades", "stacking" },
  body = {
    { text = L:G("Use each bag's Items tab to choose what its item buttons show.") },
    { heading = L:G("Item Level") },
    { list = {
      L:G("Show Item Level writes the item level on gear."),
      L:G("Show Item Level Color colors that number by how it compares to the best gear you have seen."),
      L:G("Show Keystone Level writes a keystone's level on it (Retail)."),
    } },
    { setting = "itemLevel", bag = "Backpack" },
    { heading = L:G("Quality") },
    { text = L:G("Quality Glow Intensity sets how strongly a button shows its quality color, from 0 to 100. At 0 there is no border at all. Up to 60 it is a flat colored border that fades in. Above 60 a glowing halo joins it, at its brightest at 100.") },
    { setting = "glowIntensity", bag = "Backpack" },
    { see = "item-colors" },
  },
})

articles:Define({
  id = "item-colors", group = "bags",
  title = L:G("Item Level Colors"),
  summary = L:G("The colors item levels are drawn in, and how they follow your gear."),
  keywords = { L:G("item level color"), L:G("colors"), L:G("ilvl color"), L:G("max item level"), L:G("reset colors"),
    L:G("ilvl colors"), L:G("green ilvl"), L:G("color gradient"), L:G("gear comparison"),
    L:G("number color"), L:G("ilvl tint")
  },
  questions = { L:G("How do I change the item level colors?"), L:G("Why are my item levels a different color?"),
    L:G("How do I reset the highest item level?"),
    L:G("Why are item level numbers different colors?"), L:G("What do the item level colors mean?"),
    L:G("How do item level colors compare against my equipped gear?"), L:G("Can I turn off colored item level text?"),
    L:G("Why is a lower item level drawn in gray or red?"), L:G("How do I change how item level text is colored?")
  },
  pages = { "itemcolors", "itemcolors:main" },
  related = { "item-buttons", "upgrades" },
  body = {
    { text = L:G("With Show Item Level Color on, an item level is drawn in one of four colors: Low, Mid, High and Max. The ranges follow the highest item level you have seen, so they move up as you get better gear.") },
    { text = L:G("Change the four colors on the Item Colors page. Reset Colors puts them back as they were, and Reset Max Item Level forgets the highest item level seen, so the ranges start again from your current gear.") },
    { open = { page = "itemcolors", text = L:G("Open the Item Colors page") } },
  },
})

articles:Define({
  id = "upgrades", group = "bags",
  title = L:G("Upgrade Arrows"),
  summary = L:G("The green arrow on gear that would be an upgrade, and what decides."),
  keywords = { L:G("upgrade"), L:G("arrow"), L:G("green arrow"), L:G("better gear"), L:G("Pawn"), L:G("SimpleItemLevel"),
    L:G("upgrade provider"),
    L:G("upgrade arrow"), L:G("Pawn integration"), L:G("gear upgrade")
  },
  questions = { L:G("What is the green arrow on my item?"), L:G("Why doesn't my upgrade show an arrow?"),
    L:G("How do I use Pawn for upgrade arrows?"),
    L:G("What does the green arrow on an item mean?"), L:G("Why isn't the upgrade arrow showing on gear in my bags?"),
    L:G("How does BetterBags decide if an item is an upgrade?"), L:G("Does the green upgrade arrow work with Pawn?"),
    L:G("How do I turn off the green upgrade arrows?"),
    L:G("Why does a lower item level piece have or not have an upgrade arrow?")
  },
  settings = { "upgradeProvider" },
  related = { "pawn", "item-buttons" },
  body = {
    { text = L:G("Gear in your bags that would be an upgrade gets a green arrow in its top corner. Upgrade Icon Provider, on the General page under Items, sets what decides:") },
    { list = {
      L:G("None shows no arrows."),
      L:G("BetterBags compares item levels with what you wear. Gear for an empty slot counts as an upgrade."),
      L:G("Pawn weighs stats by your Pawn scales, when the Pawn addon is installed."),
      L:G("SimpleItemLevel uses its own check, when that addon is installed."),
    } },
    { text = L:G("Until you choose one yourself, BetterBags uses Pawn when it is installed, or else SimpleItemLevel when it is.") },
    { heading = L:G("Missing Arrows") },
    { text = L:G("With BetterBags deciding, an item gets no arrow if your character cannot use it, is not high enough level for it, or if the item is not your armor type or has a main stat your specialization does not use. When you have a two-handed weapon equipped, one-handers, shields and off-hands get no arrow, and the other way around.") },
    { setting = "upgradeProvider" },
  },
})

articles:Define({
  id = "recent-items", group = "bags", featured = true,
  title = L:G("Recent Items"),
  summary = L:G("The section of items you just got, how long they stay there, and how to clear it."),
  keywords = { L:G("recent"), L:G("new items"), L:G("loot"), L:G("new"), L:G("flash"), L:G("clear recent"),
    L:G("duration"), L:G("glow new"),
    L:G("looted gear"), L:G("recent timer")
  },
  questions = { L:G("How do I clear recent items?"), L:G("How do I turn off Recent Items?"),
    L:G("How long do items stay recent?"), L:G("Why are my new items at the top?"),
    L:G("How do I clear the Recent Items section?"), L:G("How long do newly looted items stay in Recent Items?"),
    L:G("How do I turn off the Recent Items category?"),
    L:G("Why do items I bought or looted go to the top under Recent Items?"),
    L:G("Can I change how long new items stay marked as recent?"), L:G("Why won't an item leave Recent Items?")
  },
  settings = { "filterRecentItems", "newItemDuration", "markRecentItems", "newItemFlash" },
  related = { "skip-recent", "stacking", "sections" },
  body = {
    { text = L:G("Items the game marks as new, such as loot, go in Recent Items at the top of your bags, so you can find what you just got. After a while they move to their usual section.") },
    { list = {
      L:G("New Item Duration, on the General page, sets how many minutes an item stays recent."),
      L:G("All Items Recent, on a bag's Items tab, marks everything that enters the bag as recent, including items moved from the bank and from opened containers."),
      L:G("Flash Stacks makes a stack flash when it gets new items."),
    } },
    { heading = L:G("Clearing") },
    { text = L:G("Sorting your bags clears Recent Items: right-click the bag button on the classic bags, or the title on a BetterBags Next bag. On classic versions of the game, this requires the SortBags addon.") },
    { heading = L:G("Disabling") },
    { text = L:G("Turn off Recent Items on a bag's Categories tab.") },
    { setting = "newItemDuration" },
    { see = "skip-recent" },
  },
})

articles:Define({
  id = "show-bags", group = "bags",
  title = L:G("Show Bags"),
  summary = L:G("Seeing your bags as they are, swapping bags, and buying bank bag slots."),
  keywords = { L:G("show bags"), L:G("bag slots"), L:G("equip bag"), L:G("swap bag"), L:G("change bag"), L:G("bank bag slot"),
    L:G("Show Blizzard Bags"), L:G("buy bag slot"),
    L:G("equipped bags"), L:G("swap bags"), L:G("buy bank slots"),
    L:G("new bag"), L:G("bigger bag"), L:G("equip a bag")
  },
  questions = { L:G("How do I change my bags?"), L:G("How do I put on a bigger bag?"), L:G("How do I buy a bank bag slot?"),
    L:G("How do I see which bag an item is in?"),
    L:G("How do I equip or swap a bigger bag?"), L:G("Where can I see my equipped bags like in the default UI?"),
    L:G("How do I buy extra bank bag slots?"),
    L:G("How do I view items by which bag they are in instead of categories?"),
    L:G("Can I see my reagent bag separately?"), L:G("How do I turn off categories and look at my raw bags?"),
    L:G("Where do I put a new bag I bought?"), L:G("How do I equip a bag?"),
    L:G("Show Bags: Your Bags Themselves")
  },
  related = { "bag-menu", "free-space", "bank-bags" },
  body = {
    { text = L:G("Show Bags shows your bags themselves: each bag in its slot, and your items bag by bag, in slot order. Use it to swap a bag for a bigger one.") },
    { list = {
      L:G("Classic bags: choose Show Bags in the bag menu."),
      L:G("BetterBags Next: click Show Blizzard Bags at the top of the backpack. Your bags show in the tabs: drop a bag on a tab to put it in, or drag a bag off its tab to take it out. Click the button again to see your categories."),
    } },
    { text = L:G("On classic versions of the game, turn on Show Bags in the classic bank and click a red bag slot to buy it. On Retail and WoW: Forever, Show Bags at the bank shows your bank tabs instead.") },
  },
})

articles:Define({
  id = "dropping", group = "bags",
  title = L:G("Dropping Items"),
  summary = L:G("Dropping an item anywhere on a bag, not just on an empty slot."),
  keywords = { L:G("drop"), L:G("drag item"), L:G("put item"), L:G("unequip"), L:G("cursor"), L:G("inventory is full"),
    L:G("place item"),
    L:G("drop item"), L:G("drag to bag"), L:G("put in bank"), L:G("quick deposit")
  },
  questions = { L:G("How do I put an item in my bags?"), L:G("How do I unequip gear into my bags?"),
    L:G("Where does an item I drop go?"),
    L:G("Can I drop an item anywhere on the bag window to put it away?"),
    L:G("Do I have to aim for an empty slot when dragging items into my bags?"),
    L:G("How do I drag something from my bank or mail into my backpack?"),
    L:G("Why did dropping an item on a category put it into my bags?"),
    L:G("What happens when I drop an item onto the BetterBags window?"),
    L:G("How do I move an item into my bank by dragging?"),
    L:G("Dropping Items Into Your Bags")
  },
  related = { "category-items", "show-bags" },
  body = {
    { text = L:G("Drop an item anywhere on a bag or bank window, not just on an empty slot: drag it there and let go, or pick it up and click the window. It is the quickest way to unequip gear from your character window into your bags.") },
    { list = {
      L:G("The item goes into the first free slot of a bag made for it, such as a profession bag of its kind, the reagent bag for crafting reagents, or the keyring for keys. Otherwise it goes into your first regular bag, starting with your backpack."),
      L:G("If you drop it on the bank, it goes into the bank you are viewing, starting with your selected tab."),
      L:G("An item you picked up from the same window goes back where it came from."),
      L:G("If there is no room, the game says your bags or your bank are full, and the item stays on your cursor."),
      L:G("If you drop it on another item, the two swap places as usual."),
    } },
    { tip = L:G("Hold Shift and drop an item on a section's title to add it to that category. In BetterBags Next, drop it on the title without Shift.") },
    { warning = L:G("Items you are buying from a vendor are not placed this way: drop them on an empty slot.") },
  },
})

articles:Define({
  id = "anchors", group = "bags",
  title = L:G("Moving Bags"),
  summary = L:G("Moving your bags, pinning them to a corner, and keeping them on the screen."),
  keywords = { L:G("move"), L:G("anchor"), L:G("position"), L:G("corner"), L:G("grow"), L:G("lock"), L:G("bbanchor"),
    L:G("clamp"), L:G("off screen"),
    L:G("move bags"), L:G("pin corner"), L:G("lock window"),
    L:G("move the window"), L:G("reposition"),
    L:G("corner snap")
  },
  questions = { L:G("How do I move my bags?"), L:G("How do I make my bags grow upward?"), L:G("How do I lock my bags in place?"),
    L:G("My bag is off the screen, how do I get it back?"),
    L:G("How do I move my bag window around the screen?"),
    L:G("How do I anchor my bags so they grow up instead of down?"),
    L:G("My bag window went off the edge of the screen, how do I fix it?"),
    L:G("Why do my bags move back or shift when I open them?"),
    L:G("How do I pin my bags to the bottom right corner?"),
    L:G("How do I keep my bags from going off screen when they grow?"),
    L:G("Which corner does my bag grow from?"),
    L:G("Moving and Anchoring Your Bags")
  },
  settings = { "clampBagsToScreen" },
  related = { "next-panels", "bag-menu", "slash-commands" },
  body = {
    { text = L:G("A bag grows away from one of its corners as it fills, and that corner stays where you put it.") },
    { heading = L:G("Classic Bags") },
    { text = L:G("Drag a bag by its top to move it. By default it grows from its bottom left corner. For more control, open Bag Anchor in the bag menu:") },
    { list = {
      L:G("Enable turns the anchor on."),
      L:G("Show displays the blue anchor square: drag it to place the bag to the pixel. Right-click the square to hide it again."),
      L:G("Manual Anchor picks the corner the bag grows from. Automatic grows it away from the closest corner of the screen."),
    } },
    { text = L:G("/bbanchor turns on and shows the anchors of both bags.") },
    { heading = L:G("BetterBags Next") },
    { text = L:G("A small bag holds one corner and grows away from it. When you drag it by its title, it holds a bottom corner: bottom right on the right half of the screen, and bottom left on the left half. The anchor button at the top of the backpack and the bank cycles through three states: click once to show the anchor square, click again to lock the bag, and click a third time to unlock it. Drag the anchor square to position the bag and pick its corner based on the quarter of the screen it sits in.") },
    { heading = L:G("Screen Clamping") },
    { text = L:G("Clamp Bags to Screen, on the General page, keeps bags from being moved or growing past the edges of the screen.") },
    { setting = "clampBagsToScreen" },
  },
})

articles:Define({
  id = "groups", group = "bags",
  title = L:G("Groups"),
  summary = L:G("Putting categories on tabs of their own to keep your bags short."),
  keywords = { L:G("group"), L:G("tab"), L:G("tabs"), L:G("new tab"), L:G("rename tab"), L:G("delete tab"), L:G("empty tab"),
    L:G("plus"), L:G("enable groups"),
    L:G("bag tabs"), L:G("category tabs"), L:G("tab groups"), L:G("split categories"),
    L:G("pages"), L:G("too tall")
  },
  questions = { L:G("How do I make a new tab?"), L:G("How do I move a category to another tab?"),
    L:G("How do I turn off tabs?"), L:G("How do I hide empty tabs?"), L:G("How do I reorder my tabs?"),
    L:G("How do I put categories onto separate tabs?"),
    L:G("My bags are too tall, how do I organize sections into tabs?"),
    L:G("How do I create a new tab group for gear or professions?"), L:G("What are groups and how do tabs work?"),
    L:G("How do I move a category onto a different tab?"), L:G("Can I use tabs in my backpack as well as my bank?"),
    L:G("Groups: Tabs of Categories")
  },
  settings = { "enableGroups", "hideEmptyGroups" },
  pages = { "backpack:layout", "bank:layout" },
  related = { "next-dragging", "section-order" },
  body = {
    { text = L:G("Groups put categories on tabs of their own. The first tab, Backpack, holds every category you have not moved elsewhere.") },
    { steps = {
      L:G("Click the + tab to make a new group and name it."),
      L:G("Drag a category's section onto a tab to move the category to that group."),
      L:G("Right-click a tab to rename or delete its group."),
    } },
    { list = {
      L:G("Enable Groups, on the backpack's Layout tab, turns groups on and off. When off, every category shows in one view."),
      L:G("Hide Empty Groups hides the tab of any group that has no items in the bag. All tabs appear while you drag a section, so you can drop it on any of them."),
      L:G("In BetterBags Next, drag a tab up or down to change the order of your tabs. In the classic bags, hold Shift and drag a tab left or right. Your order is saved."),
    } },
    { setting = "enableGroups", bag = "Backpack" },
  },
})

articles:Define({
  id = "interactions", group = "bags",
  title = L:G("Auto Open"),
  summary = L:G("Choosing whether your backpack opens when you talk to a vendor, open the bank, trade and more."),
  keywords = { L:G("auto open"), L:G("open bags"), L:G("close bags"), L:G("vendor"), L:G("mailbox"), L:G("trade"),
    L:G("auction house"), L:G("open and close"), L:G("leave alone"), L:G("interactions"),
    L:G("mailbox bags"), L:G("vendor open"),
    L:G("pop up"), L:G("pops up"), L:G("opens by itself")
  },
  questions = { L:G("How do I stop my bags opening at the mailbox?"), L:G("Why do my bags open at a vendor?"),
    L:G("How do I keep my bags open after the bank?"),
    L:G("How do I make my bags open automatically at the mailbox or auction house?"),
    L:G("How do I stop my backpack from opening when I talk to a vendor?"),
    L:G("Why don't my bags open when I trade with someone?"),
    L:G("Can I choose which windows automatically open my bags?"),
    L:G("Why do my bags stay open or close when I leave a merchant?"),
    L:G("How do I make my bags open at the bank or guild bank?"),
    L:G("Opening Your Bags at a Vendor, Bank or Mailbox")
  },
  settings = { "interactionTrade", "interactionBank", "interactionWarbank", "interactionVendor", "interactionMail",
    "interactionAuctionHouse", "interactionGuildBank", "interactionVoidStorage", "interactionScrapper",
    "interactionItemUpgrade" },
  related = { "auto-sell", "bank-basics" },
  body = {
    { text = L:G("On the General page, under Interactions, each kind of window has a dropdown for what your backpack does when you open it: Trade, Bank, Warband Bank, Vendor, Mailbox, Auction House, Guild Bank, Void Storage, Scrapper and Item Upgrade. Each dropdown appears only on versions of the game that have that window.") },
    { list = {
      L:G("Open and Close: the backpack opens, and closes again when you are done."),
      L:G("Open Only: the backpack opens, and stays open after."),
      L:G("Leave Alone: the backpack stays as it is."),
    } },
    { setting = "interactionVendor" },
    { setting = "interactionMail" },
  },
})

articles:Define({
  id = "blizzard-button", group = "bags",
  title = L:G("Blizzard Bag Button"),
  summary = L:G("Showing or hiding the game's own bag button."),
  keywords = { L:G("bag button"), L:G("micro menu"), L:G("action bar"), L:G("backpack button"), L:G("hide button"),
    L:G("micro bar"), L:G("bag bar"), L:G("default button"), L:G("hide bag icon")
  },
  questions = { L:G("How do I hide the Blizzard bag button?"), L:G("Where did the bag button on my action bar go?"),
    L:G("How do I hide the default Blizzard bag button on my action bar?"), L:G("Where did the game's bag bar go?"),
    L:G("Can I bring back the standard Blizzard backpack icon?"),
    L:G("How do I show or hide the built-in WoW bag button?"),
    L:G("Why is the default bag icon still showing on my screen?"),
    L:G("Is there a setting to toggle the Blizzard bag bar?"),
    L:G("The Blizzard Bag Button")
  },
  settings = { "showBagButton" },
  related = { "opening", "bag-menu" },
  body = {
    { text = L:G("Show Blizzard Bag Button, on the General page, shows or hides the game's own bag button next to your action bars. Show Bag Button in the classic bag menu does the same.") },
    { setting = "showBagButton" },
  },
})
