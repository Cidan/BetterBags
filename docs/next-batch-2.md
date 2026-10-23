# Next batch 2: eight changes in one PR (asked 2026-10-22)

Asked as one batch, to be built end to end in one pull request while the author is away ("i'll be
playing skyrim, so just, go"). This file records each request as asked, what the code does today,
the plan, and every decision taken without asking. Each section ends with its status.

## 1. Skip Recent Items (a category setting)

**Asked:** "a new toggle option under automation for categories (not under 'merchant' though), 'Skip
Recent Items', which makes items that get assigned that category skip the recent items list (it gets
unmarked as a new item, goes right to the category) -- this is 100% independent of autosell, etc. can
apply to any category".

**Today:** an item is in Recent Items while its GUID has a timer (`items:IsNewItem`, recent-items.md
§1); the harvest starts a timer for an item the client flags new, and "All Items Recent" for an item
that is new to the bag. `items:GetCategory` returns "Recent Items" before anything else. The
Automation tab has one section, "Merchants" (Auto Sell, Confirm Auto Sell, Destroy What Can't Be
Sold).

**Plan:**
- Stored on the category as `skipRecent = true` (no field when off), set with
  `categories:UpdateCategory { skipRecent }` (no recalculation of categories needed beyond the bags'
  Recent Items, so it asks for a recalculation), saved in a plugin's state like its automation, read
  with `categories:SkipsRecentOf(name)` (a group by's sections as their category).
- The Automation tab gets a second section, "Recent Items", with one switch, "Skip Recent Items",
  shown for every category, a plugin's too. Independent of the Merchants switches.
- In the data phase, once this sweep's categories are known (Phase 8, after the search cache), each
  item that is new (`IsNewItem`) and whose own category (ignoring Recent Items) skips Recent Items is
  unmarked: its timer ends and the client's new-item flag is removed (`ClearNewItemFromData`), so it
  shows in its category at once, with no glow. Virtual stack roots are recent only by piles still new.

**Status:** done. `data/items.lua` (`SkipRecentItems`), `data/categories.lua`, `core/database.lua`,
`next/settings/categories.lua` (`RecentOptions`), `next/settings/content.lua`; recent-items.md §4. 18
mutations: one led to a test (a search category matched on the item's first read); two single-point
mutations of the recalculation check are equivalent (both halves must change to skip it; the test
catches them together).

## 2. Ignored Items (a category tab)

**Asked:** "a new tab next to 'Added Items' called 'Ignored Items', same interface/layout as Added
Items, but items in this are *ignored* from the category and never land in there under any
circumstance, no matter if it's added in Added Items, or in a Search Filter."

**Today:** a category gets items two ways: Added Items (`customCategoryIndex[itemID]`, read by
`categories:GetCustomCategory`; a plugin's item lists and category functions there too) and its search
rule (`items:RefreshSearchCache`, the first matching category by priority). The Added Items tab
(`NextSettingsCategories:CreateItemsTab`) lists the items, takes drops, removes on a right click and
has Remove All.

**Plan:**
- Stored on the category as `ignoredItems = { [itemID] = true }`, a plugin's in its saved state (the
  player's choice, as its color). `categories:IgnoreItem`, `UnignoreItem`, `ClearIgnoredItems`,
  `IgnoresItem(name, itemID)`; each sends `categories/Changed` and recalculates the bags.
- Resolution: `GetCustomCategory` skips a category that ignores the item (Added Items, a plugin's
  list, a plugin's category function); `RefreshSearchCache` skips it for that item, so the next
  matching category by priority (or the item's own) takes it. A group by's sections ignore what their
  category ignores. Ignore wins over Added Items.
- The tab: "Ignored Items", right after "Added Items", the same tab (one implementation, two lists):
  the count, the filter, Remove All, the help ("Drag an item here so it never shows in this
  category."), the item grid (drop to ignore, right-click to remove). Editable for a plugin's category
  too. An item in your bags says where it shows instead.

**Status:** done. An item both added and ignored stays in Added Items (faded, "Ignored in this
category."): ignoring wins, as asked. `data/categories.lua`, `core/database.lua`, `data/items.lua`
(`RefreshSearchCache`), `next/settings/categories.lua` (`CreateItemsTab` with mode `"ignored"`),
`next/settings/content.lua`; category-lifecycle.md §8, next-settings.md §5. 27 mutations: one led to a
test (Remove All letting a plugin's function name the item again).

## 3. A close button on the backpack

**Asked:** "an X at the top right of the backpack to close it".

**Today:** the bank, guild bank and vendor have a header close button (`closeButton`, first in their
`GetHeaderButtons`, "in order from the screen edge"); the backpack has settings, sort, the classic
switch and the size button.

**Plan:** the backpack's header gets `closeButton` first (its panel is on the right, so first is the
top right), hiding the backpack, the same button and icon as the other panels.

**Status:** done. `next/bag.lua`; tests in `spec/next/bag_spec.lua` (its place and icon, closing).

## 4. Show Blizzard Bags (the backpack's bags in its tab rail)

**Asked:** "the 'Switch to Classic Bags' icon now becomes 'Show Blizzard Bags', with our left tabs
replaced with the bag icons for the Blizzard Bags, so users can swap out their bags -- the view of
items switches to the full stack of bags, just like in our Original bags view, same functionality."

**Today:** the backpack's header has "Switch to Classic Bags" (`classicButton`). The classic bags'
Show Bags (`ContextMenu:ToggleBagSlots`) shows the bag slots panel (classic bag buttons:
`PutItemInBag`, `PickupBagFromSlot`, refused in combat) and switches the view to `SECTION_ALL_BAGS`
(every bag a section, slot order). The Next bank already has the same kind of switch,
`ToggleBankTabs` (Blizzard's bank tabs in its rail, the Show Bags view).

**Plan:**
- The header button becomes "Show Blizzard Bags" (a bag icon; "Show Categories" while on). The way
  back to the classic bags stays in the settings (the BetterBags Next switch) and `/bb next`.
- On: the view is saved (`SetPreviousView`) and becomes `SECTION_ALL_BAGS`; the rail lists the
  backpack's bags (the backpack, its bag slots, the reagent bag where there is one), each tab its bag's
  icon (an empty bag slot's art when empty) and name. A tab is the bag slot: dropping a bag on it or
  clicking it while holding one puts the bag there, dragging it or Shift-clicking it picks the bag up,
  hovering shows the bag's tooltip, all refused in combat, the classic bag buttons' actions moved into
  shared functions both use. The backpack itself has no slot to swap. Off: the previous view and the
  group tabs come back. The mode is the view itself (`SECTION_ALL_BAGS`), so it survives a reload as
  the classic one does.
- The rail redraws when bags change (`BAG_CONTAINER_UPDATE`, `PLAYER_EQUIPMENT_CHANGED`).

**Status:** done, with these choices:
- The tabs are the bag slots the classic Show Bags panel lists (`BACKPACK_ONLY_BAGS_LIST`); the backpack
  itself has no slot to swap, so no tab. Its items still show, as the first bag.
- A tab shows its bag's icon and name (as the bank's Blizzard tabs show theirs); the art for an empty
  slot is Blizzard's empty bag slot.
- The rail redraws on `BAG_CONTAINER_UPDATE` only, as the classic slots panel does.
- No section can be dropped on a bag slot's tab (group and bag IDs overlap), and a section dropped on the
  backpack's items while it shows its bags only moves.
- The icon key is now `bagsButton` (was `classicButton`); no theme outside BetterBags named it.
`next/bag.lua`, `frames/bagbutton.lua` (`PickupBag`, `PutInBag`, shared with the classic bag buttons),
`next/tabs.lua` (`bag`), `next/drag.lua`, `sonata/themes/next/default.lua`; next.md §3, next-themes.md.
32 mutations: four led to tests (one with `GetBagName` mocked as documented, never nil).

## 5. Reorderable tabs in every Next window

**Asked:** "all tabs in all Next windows should be reorderable by clicking and holding to slide.
animate the slide, but pin the X axis so you can't move it left and right, just drag it up and down.
animate this transition and make sure it saves."

**Today:** the tab rails (`NextTabs`) list tabs in a fixed order: groups by ID (the bank's Warbank
groups after its own), Blizzard bank tabs by number, guild tabs by number, the vendor's Buy, Buyback,
Repair.

**Plan:**
- Pressing a tab and moving (`OnDragStart`) lifts it as sections and settings rows are lifted
  (`NextLift`), but it only follows the cursor up and down, its X pinned; the other tabs slide out of
  its way (animated); letting go lands it in its place (animated). One drag at a time.
- The order is saved per rail (`database` profile, `nextTabOrder[key]`: `backpack`, `bank`,
  `bankTabs`, `guild`, `vendor`) and applied whenever the rail lists its tabs: saved tabs in their
  saved order, new ones after them in their old order.
- What does not move: the "+" tab and purchase tabs (always last); tabs whose drag already means
  something else (the Show Blizzard Bags tabs pick up a bag; WoW: Forever's bank sockets do too). The
  bank's Warbank groups move only among Warbank groups and its own only among its own (they are two
  blocks).
- "All Next windows" means the vertical tab rails. The settings window's tabs are horizontal (the
  top tabs): pinning X would leave nothing to drag, so they are left as they are.

**Status:** planned.

## 6. Moving a category between the bank and a backpack tab (bug)

**Asked:** "moving a category out of the bank and into the backpack (or vice versa) via a non-default
tab, i.e. Bank -> Custom tab in backpack, does not work. at least, if you have the tab open and drag
to the item space, it shows up visually, but when you sort the bag, it snaps back to backpack. make
drag + drop work for the item space and on a tab directly."

**Today (read in the code):** `NextDrag:Drop` for a drop on the other panel's body (`"bag"`) only moves
the items (`SectionFrame:MoveItems`); it never assigns the category to the group that panel shows. The
moved items show in Recent Items, which every tab shows, so they look like they arrived; once they
are no longer recent (a sort clears Recent Items) they go to their category's group, which is still
the default tab. A drop on a tab (`"bagtab"`) assigns the group. Not measured in game.

**Plan:**
- A body drop does what a drop on the tab the panel shows does: the items move (into that tab's bank
  type for the bank), and the category is assigned to that group (the default group clears the
  assignment).
- Tests through the real tab partition (`ItemBelongsToTab`) for both directions and both drop places:
  after the move and a sort, the category's items are in the tab it was dropped on.

**Status:** done. The data side was already right: a test through the real database, groups and tab
partition (`spec/bank_tab_category_routing_spec.lua`) shows an unassigned category in the default tab
(where it snapped back) and an assigned one in its group. The drop on a tab directly already assigned
the group; the drop on the items did not. `NextDrag:ShownTab` makes a drop on a panel's items a drop on
the tab it shows (the group, or the Blizzard tab in Bank Tabs mode), the guild bank's withdrawals
included; with groups off, or only a tab to buy, the items only move. `next/drag.lua`; next.md §7.
6 mutations: two led to tests (Bank Tabs mode with groups off; a bank with only a tab to buy).

## 7. Animated switches in the settings

**Asked:** "animate our toggle switches in the options screen please :)"

**Today:** `NextToggle:Click` slides the knob, but the settings row refreshes at once after saving
(`control:SetChecked(value)`), which stops the slide and puts the knob at its end. Every switch (the
settings rows, a bag's Categories tab, a category's bags, currencies) does the same.

**Plan:** `SetChecked` without animating leaves a slide already going to that state running; a row
refreshing a switch whose state changed while it shows slides it (a switch turned off by another, as
Auto Sell takes Destroy with it).

**Status:** done. `next/controls/toggle.lua`, `next/settings/rows.lua`; tests in
`spec/next/controls/button_spec.lua`, `spec/next/settings/page_spec.lua`; 5 mutations, all caught.

## 8. Dropping an item on a category header

**Asked:** "make it so if you drag and drop an item onto a category header, it becomes an Added Item in
that category. if we ever drag an item away back to it's original category, handle the case where we
drag it back to the category but we don't add it to Added Items if it would naturally fit there
already, i.e. if it's a Blizzard defined category, and it would match into that category at that
moment in time, don't add it to Added Items for that category, just strip it's manual assignment and
let it land where it should."

**Today:** a Next section header passes an item dropped on it to `SectionFrame:OnTitleClickOrDrop`:
with Shift, the item is added to the category; without, it goes into the bag (the window's drop).

**Plan (BetterBags Next's headers):**
- Dropping (or clicking with) an item on a category header, no Shift needed:
  - where the item lands without any Added Items assignment ("naturally": its search categories, a
    plugin's, the built-in categories, ignoring Recent Items) is that category: its manual assignment
    is removed, and it lands there;
  - else, one of your categories (a group by's section: its category): the item is added to Added
    Items (moving it from the category it was added to), and taken off that category's Ignored Items;
  - else (a plugin's category it does not fit): nothing changes, and it says so.
- The item goes back to its slot. Recent Items and Free Space headers still put the item in the bag.
- The classic bags' titles keep their behavior (Shift adds; issue #408's drop zone): this is BetterBags
  Next's header.

**Status:** done, with two changes to the plan:
- A built-in category the item does not fit gets a category of yours with its name, holding the item,
  which shows in the same section (the classic title's Shift drop always did this). The request implies
  it: "don't add it to Added Items for that category" is the exception for a Blizzard category the item
  fits, so one it does not fit takes it in Added Items.
- A gear set's section ("Gear: ...") takes nothing and says the Equipment Manager makes gear sets; a
  plugin's category says a plugin fills it. In both the item stays on the cursor.
`data/categories.lua` (`FileItem`, `GetCustomCategory` without Added Items), `data/items.lua`
(`NaturalCategory`), `next/panel.lua` (`FileCursorItem`); category-lifecycle.md §9, next.md §7. 22
mutations: one led to a test (a merchant's item on the cursor).

## Order of work

7 (small, self-contained), 3, 1, 2, 8, 6, 4, 5: each with tests first, its rules file updated, lint,
the full suite and its mutations, then one commit; one pull request for all of them, not merged until
the author is back.
