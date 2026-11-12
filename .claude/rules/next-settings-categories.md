---
paths:
  - "next/settings/categories.lua"
  - "next/settings/bagcategories.lua"
  - "next/settings/reorder.lua"
  - "spec/next/settings/categories_spec.lua"
  - "spec/next/settings/bagcategories_spec.lua"
  - "spec/next/settings/reorder_spec.lua"
---
## 5. Categories: the Categories page and each bag's arrangement

Asked (2026-10-20): categories get a dedicated space, as currency did; defined once, applied to bags;
item and search categories combined, each able to hold both. Then (2026-10-21), after the first version
crowded a list and an editor into one box (a cut-off button, a scrolling page, unclear "Placed Here",
icons over text, no room to drop onto a long list): the list moves to the sidebar, the category gets
the whole content area in three tabs, and the window grew to 720. A fourth, Automation, came with
category automation (2026-10-22, automation.md). The data model is
category-lifecycle.md §6. Every question is a `NextDialog` over the window.

**The Categories page** (`next/settings/categories.lua`, `NextSettingsCategories`; page `categories`,
BetterBags group after Item Colors, both designs). It is a page with its own list (next-settings.md §3): its sidebar is
`CreateList`, its heading `Heading()`, its buttons `CreateActions`, and its tabs one wide block each,
their section titles hidden, each filling the content without scrolling (`ContentHeight` less the
page's `Content.Top` and `Bottom`).
- **The list** (in the sidebar): a filter box where the settings search box is; every category, yours
  and the plugins', in their order, which is their priority (category-lifecycle.md §7), a group by's
  sub-categories left out; each row a color dot, the name and how many of the shown bags' items it
  holds, "N items matching" ("1 item matching"; asked: "just have the subtext to categories say 'x
  items matching'"). The count is the Settings tab's Current Items in this Group: each item once, its
  group by's sections with it, in the bags the settings show (`matchingCounts`, one pass over the
  items, each counted for its category and every name its category is a section of: `isShownIn`'s
  rule). It is counted again on `items/Refresh<Kind>/Done` (every bag) while the list shows. New
  Category at the bottom where the version is (`{ name, itemList = {}, save = true }`, chosen, on top).
  Dragging a row moves its category (`listProto:Drop` → `categories:MoveCategory`): after the row above
  where it is let go, or right before the first row shown when let go above them; the categories a
  filter hides keep their places. The rows are arranged and dragged by `NextListReorder` (below). No
  tooltip (asked: no help text yet). The first category is chosen when
  none is (`EnsureChosen`); clicking one chooses it (`Choose`, then `Reselect`). On `categories/Changed` while
  it shows, the page shows again, the first chosen for one that is gone.
- **The header**: the chosen category's name, and its line (a plugin's starts "Made by a plugin");
  "Categories" and "Make a category to sort your items your way." for none. Rename and Delete for your
  categories; for a plugin's or none they hide and the buttons' frame shrinks so the title takes the
  room.
- **The two item boxes stay put** (asked: boxes a few pixels apart made switching tabs messy): the
  Settings and Search Rule tabs put their box's name row and their box at the same place
  (`boxRows`: under three rows of settings, a row for the name, the box down to the tab's bottom).
- **Settings tab**: four rows, Used In (a switch per bag the settings show, the guild bank like any),
  Hide In (a switch per bag, off where it is not used, asking in a `NextDialog` before hiding; turning it off asks nothing;
  category-lifecycle.md §10), Group By (yours only; the row stays empty for a plugin's), Color (and
  Reset Color: none, drawn in gold); then **Current Items in this Group** (the player's wording): how
  many items each bag shows in it (its group by's sections too) and those items in a read-only grid,
  one cell per item with how many there are, by name, or "There are no current items in your
  inventory that match this category". With no category it says to make one.
- **Search Rule tab** (asked: "Search Rule" everywhere; yours, and a plugin's that has a rule): the
  search in a field taking the room down to the **Search Results** row, which counts them beside its
  name as it is typed ("Search Results (3 results)", "(invalid search)" for a mistake, caught from
  `Search:Search` in a protected call; asked: no line about an empty rule), with Apply Search Rule on
  its right, on only when the rule changed and has no mistake (it saves it, none for an empty one).
  The results are a grid in full color (asked), those showing in this category first; the tooltip of
  one showing elsewhere says "Shows in X." What is typed is kept while the same category shows. A
  plugin's rule shows read-only (the field disabled, no Apply Search Rule).
- **Added Items tab** (asked: "Placed Here" made no sense; its line "Drag an item here to manually add
  it to this category."): how many items were added (or "3 of 12"
  while filtered), a filter by name, Remove All (asks first; `WipeCategory`, then the bags
  recalculated), and the items in a `NextItemGrid` that holds thousands: icons at once
  (`GetItemInfoInstant`), names and qualities from `C_Item.GetItemNameByID` / `GetItemQualityByID`, the
  names not loaded yet asked for once per category (`ContinuableContainer`) and the list shown again
  when they arrive; by name, those not known yet last. An item in your bags that shows in another
  category is faded, "Shows in X instead." An item dropped anywhere on the grid is added
  (`AddPermanentItemToCategory`, `ClearCursor`, the bags recalculated; asked: the items themselves
  are drop targets); a right click offers Remove. A plugin's items show read-only (no drop, no remove,
  no Remove All). An added item the category ignores is faded, "Ignored in this category."
- **Ignored Items tab** (asked: "a new tab next to 'Added Items' called 'Ignored Items', same
  interface/layout as Added Items"; category-lifecycle.md §8): the Added Items tab itself
  (`CreateItemsTab(parent, owner, bags, "ignored")`), the same count ("1 ignored item"), filter, Remove
  All (`ClearIgnoredItems`), names loading and grid, its line "Drag an item here so it never shows in this
  category." and "No items ignored."; a drop ignores the item (`IgnoreItem`), a right click stops
  ignoring it (`UnignoreItem`), the bags recalculated each time. Editable for a plugin's category too:
  what it ignores is the player's choice. An ignored item in your bags says where it shows ("Shows in
  X."), not faded.
- **One items tab** (`NextSettingsItemsTab`, `next/settings/itemstab.lua`): Added Items and Ignored Items are two
  sources of the shared items tab (`CreateItemsTab` makes it with the chosen category's lists), which the Currencies
  page's Items tab uses too (currency.md §6). What differs between them is the source's (`NextItemsSource`: the list,
  read-only, help, words, notes, add, remove, clear, Remove All's question); the tab's look, its filter, names loading,
  drops, right click and Remove All are one. The page's tabs share its frame helpers (`TabHeight`, `Metrics`,
  `PlaceTab`).
- **Automation tab** (automation.md §5): a section ("Merchants") of three settings rows, drawn as every
  page's settings (not controls of its own): Auto Sell, Confirm Auto Sell (on by default) and Destroy
  What Can't Be Sold, the last two disabled while Auto Sell is off, saved at once
  (`NextSettingsCategories:AutomationOptions`); a section ("Bank", automation.md §7) of Auto Deposit and
  Deposit Into, the bank or the Warbank (`DepositOptions`, the dropdown left out where there is no
  Warbank); and Recent Items. Shown while a category is chosen, a plugin's too. The heading's line ends
  "Sells at merchants" or "Sells, destroys the rest", then "Deposits in the bank" or "Deposits in the
  Warbank".
- `NextSettingsCategories:Show(name)` chooses a category for the next time the page shows (a bag's tab
  links here); `NewFromSearch(query)` makes the list ask for a new category's name with the search as
  its rule (the search box's Enter to Make Category, through `config/NewCategoryFromSearch`, which
  Config handles by opening the page). Both are used once.

**A bag's Categories tab** is Automatic (the built-in filters). **Its Order tab** (asked: "move that to a new tab next to
categories, called 'Order', and make that the whole tab") is its categories' order and nothing else
(`next/settings/bagcategories.lua`, `NextSettingsBagCategories`, `Create(parent, window, bag)`): a filter box; "Pinned" in their
order (`customSectionSort[kind]`), then "Other Categories" by name: the categories defined and the bag's sections from its
committed items (not empty slots, Recent Items, Free Space, or Show Bags' bags).
- **No scroll box within a tab** (asked: "no scrollbox within tabs, just make the whole list scroll the tab content itself"). The
  list is as tall as its filter and every row (`Measure`) and the tab's own content scrolls it, filter included. When a filter, a read
  or a category changes its height it asks the page to lay out again (`NextSettings:Relayout`, which reads no value: `Refresh` runs
  from the page's own). Its drag scrolls the window's box, and `NextListReorder` reads where a list is from its `content` on the
  screen, so a list can stand anywhere in what its box scrolls. Since the window's box resets on every page shown, Back scrolls back
  to where the page was left (`returnTo.scroll`). Not yet the same: the Categories page's item grids and the Currencies page's list,
  which fill their tab and scroll inside it (`itemsTab:TabHeight`).
- **Whether a bag uses a category is set on the Categories page alone** (asked: "no duplicate controls here"; the switch that was
  here is gone). A defined category not used in this bag says so ("Not used in this bag"), as its order has no effect there; its
  name opens it on the Categories page (`Show`, then `NextSettings:Open("categories")`), and Back returns to the bag's tab.
- A group by's sub-category says whose it is ("Grouped by Potions") and opens that one.
- A built-in section says "Automatic"; a pinned name that is neither (a leftover) has Remove
  (category-lifecycle.md §4).
- Shift-click pins at the top or unpins; dragging a row drops it after the entry above the pointer's
  half of a row (above the "Other Categories" heading pinned there, below it unpinned; never above the
  "Pinned" heading, `first = 2`). The order is saved from 1 (the pins a filter hides keep their order
  after the ones it shows) and the bags recalculated (`bags/Rederive { resetLayout, buttons }`). Read
  again on the bag's `items/Refresh<Kind>/Done` and on `categories/Changed` while it shows.

**Dragging a row** (`NextListReorder`, `next/settings/reorder.lua`), shared by both lists (and the Currencies page's
Tracked list, currency.md §6). Asked:
"instead of a line on drag, let's animate the move like we do categories (again, re-inventing drag
handling, we do this amazingly in the bags today, look how it's done, be careful)". The first version
drew a gold line where the row would land, a drag of its own; now a row moves exactly as a bag's
section does (next-drag.md §7), through the same code:
- **Each entry has its own row** (`rowOf`: the Categories page keys them by name, the bag's tab by name
  and a heading by a key of its own, so a category named like a heading still has its own). Rows of
  entries no longer listed (a filter, a delete) hide and wait to be reused. So when a category moves in
  the order, its own row slides there.
- **Arranging** (`Arrange(width)`): the rows one under another, each as wide as the list (Motion anchors
  only a frame's top left), placed through Motion in a pass of the list (`BeginPass(list,
  Time.Interaction)`), as the canvas places sections: while the list shows, a row whose place changed
  slides there (0.24 s, the bags' interaction time); a row newly shown, and everything while the list is
  hidden, is put there at once. The content is as tall as the rows. Both lists call it after every
  layout, and when they are placed (a new width).
- **Picking up** (the row's `OnDragStart`): the row is lifted with `NextLift` (`next/lift.lua`, moved out
  of NextDrag so both drags are one): onto the drag layer where it was on screen, a cover over it, the
  theme's shadow under it, shrinking to `Drag.LiftScale` around the point grabbed over `Time.Lift`,
  following the cursor. The list keeps a room the row's height where it was. One drag at a time, and
  none while NextLift holds another frame (a section waiting in the vendor's dock).
- **Making room**: every frame the room goes before the first other row whose middle is below the cursor
  (counting what the list is scrolled), never before `first`, and the rows slide out of its way. Near the
  list's top or bottom (40 pixels) the list scrolls toward the edge, faster closer (`NextLift:AutoScroll`,
  the bags' auto-scroll).
- **Letting go** (the left button found up): the row lands into its room over `Time.Land`, back to full
  size, aiming at the room every frame (`NextLift:Land`), then goes back in the list there. Its owner is
  told what it lands after, counted with the row itself (`onDrop(name, after)`, 0 before the first:
  the owners' `Drop` contract), unless it landed where it was. An owner that draws the list again (the
  bag's tab, and the Categories page through `categories/Changed`) shows the new order; otherwise the
  list reorders its entries itself, so nothing slides back.
- **Ending early**: the list hiding mid-drag, or the dragged entry leaving the list, puts the row
  straight back in its place.
- No hardware event is needed (nothing protected runs), so letting go is read from the mouse button
  each frame, as the bags read a missed release.
- Mutation-tested with the shared lift and NextDrag on it: 74 mutations. Twelve first survived: ten led
  to tests (a frame with its own strata, the level it is put back at, a second drag, the half-row rule,
  following the cursor, ignoring the cursor while landing, a scrolled landing, reusing rows put away,
  the Pinned heading staying on top, NextDrag's landing aiming at its gap), one was a redundant tween stop
  in NextDrag's Cancel (removed: putting the frame back stops it), and one cannot be told apart with the
  mocks (NextDrag finishing a section's flight into the dock before it leaves the dock: the mock frames'
  screen rectangles do not follow their anchors). That last one is NextDrag's behavior from before,
  unchanged.

Coverage: `spec/next/settings/categories_spec.lua` (the list: order, place, filter, choosing,
a category chosen elsewhere, New Category, a search waiting, changes; "N items matching" as the Settings
tab counts, in the bags shown, counted again when a bag is read while it shows; a drag lifting a row,
the others making room, landing it and moving its category; each category's own row, its width, rows put
away; the heading and which tabs show;
Rename and Delete; the Settings tab: its height, none, fields, saving, a plugin's, what the bags show
and reading them again; the Search Rule tab: its names, the count as typed, the results in full color,
the box where the Settings tab's is, Apply Search Rule, typed text kept, a plugin's; the Added Items
tab: order, icons, faded items, the filter, names loading once, drops, removing, Remove All, a plugin's,
its line, an ignored item; the Ignored Items tab: its count, line, filter, drops (a plugin's too),
removing, Remove All), `spec/next/controls/itemgrid_spec.lua` (columns, only the rows in view, scrolling to the
end, empty text, cells, tooltips, clicks, drops, the theme), `spec/next/settings/window_spec.lua` ("a
page with its own list": sliding, Back, opening on it, the first Escape, closing and reopening on it, a
fade-out, heading and buttons, tabs shown, tabs read after the list, Reselect, a search, nothing while
closed), `spec/next/settings/bagcategories_spec.lua` (and its drag: lifted, room made, pinned where
it lands, never above the Pinned heading; its own rows, a category named like a heading),
`spec/next/settings/reorder_spec.lua` (arranging: places, widths, height, at once while hidden, sliding
while shown in the interaction time; dragging: the lift, the room under the cursor, `first`, scrolled,
no place on screen, auto-scroll, one drag at a time; letting go: landing aimed at the room, what it lands
after, before every other, the order shown by the list or its owner, nothing for no move; ending when the
list hides or the entry goes), `spec/next/lift_spec.lua` (the shared lift), `spec/next/settings/content_spec.lua` (the page's
list, heading, buttons and three tabs, the bags shown), `spec/integration/next_settings_spec.lua`
(every tab built on the whole addon; the list in the sidebar and the first Escape on the real window),
`spec/next/controls/input_spec.lua` (`commitOnBlur`, a disabled text area),
`spec/next/controls/dropdown_spec.lua` (a menu's whole text from a narrow anchor), `spec/frames/search_spec.lua`
and `spec/config/config_spec.lua` (Enter to Make Category). Mutation-tested: the window's list mode and
the grid (37 mutations; the three survivors led to two tests and dead code removed), the tabs (50; the
survivors led to three tests and two dead guards removed), the controls and the recorder (10; one
equivalent).
