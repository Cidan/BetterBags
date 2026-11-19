---
paths:
  - "data/categories.lua"
  - "data/items.lua"
  - "data/equipmentsets.lua"
  - "core/database.lua"
  - "views/views.lua"
  - "frames/section.lua"
  - "next/settings/categories.lua"
  - "next/settings/bagcategories.lua"
  - "next/settings/content.lua"
  - "next/merchant.lua"
  - "spec/next/merchant_spec.lua"
  - "spec/categories_spec.lua"
  - "spec/equipmentsets_spec.lua"
  - "spec/database_migration_spec.lua"
  - "spec/next/settings/categories_spec.lua"
  - "spec/next/settings/bagcategories_spec.lua"
---
# Custom Category Lifecycle & Orphan Prevention

This document defines the invariants for creating, renaming, and **deleting** BetterBags
custom categories, and how orphaned categories are prevented and healed.

## 1. Category storage is spread across many side tables

A custom category's name is a key in **multiple** independent profile tables (`core/database.lua`):

- `customCategoryFilters[name]` — persistent categories (`save = true`). The authoritative
  filter (§6 for its shape), its automation included (automation.md). `GetItemCategory` /
  `GetAllItemCategories` read this.
- `ephemeralCategoryFilters[name]` — the saved state of plugins' (ephemeral) categories:
  their bags (`enabled`), flags (`dynamic`; groupBy sub-categories `"Parent - Suffix"`,
  `isGroupBySubcategory = true`) and the color, priority and automation a player set
  (automation.md: `automation`, `confirmSale`, `deposit`, `skipRecent`), and its own item order (`itemOrder`,
  item-sort.md §5). `itemList` is empty here: the
  plugin gives its items again each session. A gear set's category is not saved here but by its set's ID
  (`gearSets[setID]`, §12).
- `customCategoryIndex[itemID] = name` — the item's home: the persistent category it was placed
  in by hand. Rebuilt from the item lists at every load (§6).
- `categoryToGroup[kind][name]` (and, on retail bank, `categoryToGroup[kind][groupID][name]`)
  — tab/group assignment.
- `customSectionSort[kind][name] = index` — a bag's "Pinned" ordering.

`categoryOptions` (hidden sections) was dropped with hiding (§6).

The **in-memory** `categories.ephemeralCategories` (`data/categories.lua`) is a separate table
loaded at `OnEnable` **only** for `ephemeralCategoryFilters` entries with `dynamic == true`.
`categories:GetCategoryByName(name)` resolves against `customCategoryFilters` **or** the
in-memory `ephemeralCategories` only.

## 2. Delete must be symmetric with Rename (root-cause invariant)

**Rule:** deleting a category (`DB:DeleteItemCategory`, the target of
`categories:DeleteCategory`) must remove the name — and any grouped sub-categories
(`"name - …"`) — from **every** side table in §1, exactly as `DB:RenameCategory` already does.
For years `DeleteItemCategory` scrubbed only `customCategoryFilters`, `ephemeralCategoryFilters`
and `customCategoryIndex`, leaving `customSectionSort`, `categoryOptions` and `categoryToGroup`
behind (and `collapsedSections`, from section collapsing, since removed; `DB:Migrate` drops it).

**Failure mode (the "undeletable dynamic category" bug):** the classic settings window's Categories
pane (since replaced by the category manager, next-settings-categories.md §5, which lists what is pinned the same
way and keeps the Remove Category escape hatch of §4) — its
`categoryPaneProto:LoadPinnedItems` (`config/categorypane.lua`, removed) — inserted **every**
`customSectionSort[kind]` entry into the list with no existence check. A deleted-but-still-pinned
category therefore reappears forever under "Pinned". Selecting it makes
`categoryPaneProto:UpdateDetailPanel` call `GetCategoryByName` → `nil` → it falls through to
`ShowDynamicCategoryDetail`, which showed "This is a dynamic category. It cannot be edited or
deleted." with no delete button and no item list — so the user could neither delete it nor see
its (non-existent) contents. It is **self-perpetuating**: `UpdatePinnedItems` rebuilds
`customSectionSort` from the current list, re-persisting the ghost every time the pane is
touched. Coverage: `spec/database_spec.lua` ("DeleteItemCategory scrubs pinned sort, options,
and group for all kinds", "…scrubs grouped sub-categories from side tables").

## 3. Pins are never pruned at load (issue #1107)

**Rule:** nothing at load drops a pin because its name has no category store entry. Built-in
categories ("Armor", "Junk", "Miscellaneous", named by `items:GetCategory`, §5) have no entry
in `customCategoryFilters` or `ephemeralCategoryFilters` by design, and they can be pinned like
any other (the config pane lists the bag's sections as well as the stored categories).

**Failure mode (#1107, v0.5.5 to this fix):** `DB:PruneOrphanedSectionSort()` ran from
`DB:Migrate`, which runs on **every** load, and removed every pin whose name was in neither
store, to heal delete-orphans from the old `DeleteItemCategory`. That is every built-in category:
pins of custom categories survived a reload and pins of built-in ones did not ("other, junk,
armor", issue #1119). At load no items have been read, so there is no way to tell a built-in
category from a leftover, and the prune was removed (not narrowed).

Orphans are handled without it: deletes no longer create them (§2), every profile that loaded
v0.5.5 or later was already pruned once, and any orphan left in an older profile still has the
"Remove Category" button (§4). Coverage: `spec/database_migration_spec.lua` ("pinned categories
across a load") and `spec/debug_dump_harness_spec.lua` ("keeps every pinned category of a real
profile across a load, built-in ones included", on the real profile in `test.lua`).

## 4. UI escape hatch for any unfindable category

A bag's Order tab (`next/settings/bagcategories.lua`, next-settings-categories.md §5; before it the
category manager's and the classic pane's `ShowDynamicCategoryDetail`) marks a pinned name that is
neither a category (`GetCategoryByName == nil`) nor one of the bag's sections now as a leftover,
with a **Remove** link that calls `categories:DeleteCategory` on it after asking: the delete scrub
(§2) clears what it left in every bag (pins, tabs). Genuine in-memory dynamic/groupBy categories are
*findable*, and built-in sections show as automatic, so only orphans and persisted-but-unloaded
ephemerals reach it, both safe to scrub. This covers the sub-case §2 cannot (a non-dynamic ephemeral
pin still present in `ephemeralCategoryFilters` but never reloaded into memory by the
`if category.dynamic` guard in `categories:OnEnable`), and orphans left by deletes made before §2.
Do **not** drop that reload guard to "fix" this — it intentionally keeps transient non-dynamic
ephemerals out of the list; the correct levers are the delete scrub (§2) and this removal link.
Coverage: `spec/next/settings/bagcategories_spec.lua` ("removes a leftover after asking").

## 5. Built-in category names, and settings that follow a renamed one

Items no custom or search category claims are named by `items:GetCategory`
(`data/items.lua`) from the enabled filters, joined with " - ": item type, subtype,
trade skill, expansion. Their settings live in the same side tables as a custom category's
(§1), keyed by that name: `categoryToGroup` (tab/group), `customSectionSort` (pinned order).

- **A subtype equal to its type is not repeated** (issue #183). Quest items are type
  "Quest" and subtype "Quest", and with Type and Subtype on they read "Quest - Quest"; the
  subtype is now skipped when it equals the type added before it, so they read "Quest"
  (or "Quest - Classic" with Expansion). The subtype alone (Type off) is unchanged.
- **Renaming a built-in category moves its settings.** `DB:RenameRepeatedTypeCategories`
  (run from `DB:Migrate`) moves `customSectionSort[kind]` and `categoryToGroup[kind]` entries (including the retail bank's per-bank-type tables) from a
  name that repeated its type to the current name. It skips custom and persisted-ephemeral
  categories (a user may have named one "X - X"), keeps a setting already saved under the
  current name, and ignores legacy name = group entries at the top level of
  `categoryToGroup` (left by profiles from before groups were split by bag kind; nothing
  reads them). It is idempotent: once renamed, no name repeats its type.
- Any future change to how `GetCategory` composes names needs the same kind of migration.

Coverage: `spec/items_spec.lua` ("Category names from type and subtype (issue #183)") and
`spec/database_migration_spec.lua` ("category names that repeated their item type"; each guard
was mutation-tested).

## 6. One kind of category, defined once, used per bag

Asked (2026-10-20): categories are defined once and applied to bags; item and search categories
are one kind, each able to hold both; the guild bank is a bag like the others; hiding sections is
retired silently (tabs do it better); at equal priority an item placed by hand stays where it was
placed.

**A category** (`CustomCategoryFilter`, `data/categories.lua`) has a rule (`searchCategory.query`,
optional: the items its search matches belong to it), items placed by hand (`itemList`, optional;
an item has one home, `customCategoryIndex`, so placing it moves it), `groupBy` (its own: its
hand-placed items are grouped as its matches are), `priority`, `color`, and the bags it is used in
(`enabled[kind]`, one entry per bag kind: backpack, bank and guild bank alike). Plugins keep calling
the same API with the same table shape: `CreateCategory` moves a group by passed in the rule (where
it was) to the category's own, and `categories:RuleOf(filter)` reads a rule (nil for an empty one).

**Normalization** (`DB:NormalizeCategories`, from `DB:Migrate` at every load and after
`DB:ApplyImport`; it changes nothing a second time):
- every category gets a value for every bag: a bag it does not name, it is used in; the old single
  `enabled` boolean holds for every bag. Before, `CreateCategory` set only the backpack and bank,
  so (read from the code, not seen in game) no user category ever applied in the guild bank;
- every saved category is marked `save = true` and has an `itemList`;
- group by becomes the category's own (`groupBy`), from the rule or from a "group by <word>" clause
  left at the end of its search (a word merely ending in "group" is not a clause); an empty search
  is no rule (`searchCategory = nil`);
- the item index is rebuilt from the item lists. Two real profiles (`test.lua`) had drifted: an
  item listed in "Midnight" with no index entry (so not filed there), and an index entry naming a
  deleted category. An item listed in several categories keeps the one its index names, else the
  lowest priority number, then the first name, and leaves the others;
- `categoryOptions` is dropped.

Also: `DB:DeleteItemFromCategory` no longer unfiles an item from its home when asked to remove it
from another category (one way the index drifted); exports are version 2 (no hidden sections),
version 1 imports are normalized.

**The API** (`data/categories.lua`): a new category is used in every bag; one made again without
`enabled` keeps the bags it had (plugins make theirs at every load). `UpdateCategory(ctx, name,
fields)` changes a category in place, keeping its items: `color` (false for none), `priority`,
`enabled` (the bags named; the others kept), `rule` (empty for none), `groupBy`. For a plugin's
category only the bags, color and priority change, and they are saved
(`DB:UpdateEphemeralItemCategory`; `CreateOrUpdateCategory` keeps them, `CreateCategory` applies
them over the plugin's values). `GetCustomCategory` also returns the category it found.
`HideCategory`, `ShowCategory` and `ToggleCategoryShown` do nothing, and `IsCategoryShown` is always
true: what a plugin hides this way stays shown. Hiding came back as a player's per-bag setting (§10).

**Resolution** (`items:GetCategory`, and the vendor's copy in `next/merchant.lua`): an item added by
hand to a category of yours stays there, whatever the order (§7); a plugin's item lists compete with
rules by priority, the lower number winning, the list winning a tie (before §7, an item placed by hand
also only won ties). Both read "added by hand" from `GetCustomCategory`'s fourth result (`added`), not
from the category's `save` flag: a category of yours named after an equipment set takes the set's items
(§12) and competes for them by the order. A category with a group by shows a hand-placed
item in its sub-category for the item (`items:GroupedCategory`), made as for rule matches
(`items:ensureSubcategory`: the same bags, color and priority).

**Where it is edited**: the Categories page defines categories and which bags use them; each bag's Order tab orders
them (next-settings-categories.md §5). The search box's Enter to Make Category opens the Categories page with
the search as the new category's rule (the old search category dialog, whose Save wrote the
category whole and dropped its hand-placed items, was removed).

Coverage: `spec/database_migration_spec.lua` ("unified categories": bags, item lists and saved
flags, group by and clauses, the real profiles' index drifts, items listed twice, hidden sections,
idempotence), `spec/database_spec.lua` (`DeleteItemFromCategory` keeping a home, export version 2,
a version 1 import, a plugin's saved state), `spec/categories_spec.lua` (every bag, bags kept, group
by moved, `GetCustomCategory`'s category, rules, `UpdateCategory` for both kinds, hiding retired),
`spec/refresh_pipeline_spec.lua` (the tie, grouping hand-placed items), `spec/items_spec.lua` (every
category shows), `spec/next/merchant_spec.lua` (the vendor's tie). Mutation-tested (36 mutations; the
three survivors led to tests and a mock corrected to store a copy, as the database does).

## 7. The order of the Categories list is the priority

Asked (2026-10-22): "remove priority as a numbered concept, and instead just drag the categories in the
list so they are in priority order -- migrate priority first time as needed"; one list, yours and the
plugins' together; newest on top; "when tied, do alphabetical for first import"; an item added by hand
stays where it was put. No help text yet (a help system is planned).

- **The order** (`categories:GetOrder()`): every category but a group by's sections, by `priority`
  (10 when unset), then by name ignoring case. Higher in the list wins an item that fits more than one
  category. The Categories page's list shows it (next-settings-categories.md §5) and the rules are tried in it
  (`GetSortedSearchCategories`, same comparison), so the bags, the vendor and the list agree. Ties used
  to be decided by an unstable sort over a hash table.
- **The number stays underneath, never shown.** Rule matching, the vendor, an item's home among your
  lists (`DB:NormalizeCategories`) and plugins keep reading `priority`; nothing but the screen changed.
- **Moving** (`categories:MoveCategory(ctx, name, after)`): right after `after`, or to the top without
  one; then every category in the order is numbered from 1 (yours in their saved filters, a plugin's in
  its saved state, as `UpdateCategory` saves it), so none ties, and a group by's sections take their
  category's number. One `categories/Changed` and one `bags/Rederive { resetLayout, buttons }`. Nothing
  changes for an unknown name, an anchor that is none, or a category that lands where it was.
- **No migration writes anything.** A profile from before the order is already ordered: its numbers,
  ties alphabetical, which is what was asked for the first import. Writing numbers at load could not
  place a plugin's categories, which their plugins make later in the session; read this way they land
  where their own number puts them. The first drag numbers everything.
- **New categories go on top** (`CreateCategory`): one of yours never saved before, or a plugin's never
  seen before (no saved state), gets a number below every other (`topPriority`); a plugin's is saved
  with it, so it stays there next session. A plugin's category seen before keeps the number the player
  gave it, else its own; a category made again, and a group by's section, keep theirs. A category imported from
  text (`ImportCategory`, import-export.md §7) is new, so it goes on top too; one that replaces yours keeps its number.
- **Hand-added items** (§6, Resolution): an item you add to a category of yours stays there whatever
  the order; the order decides between rules, and between a rule and a plugin's item list.
- **Plugins** still pass `priority` to `CreateCategory`; it places a category the player has not moved,
  and only once its saved state exists (a category new to the player goes on top).

Coverage: `spec/categories_spec.lua` ("the order": the order and its ties, new categories of yours and
a plugin's on top and kept there, a plugin's seen before, a group by's section, moving and numbering
with one recalculation, the top, sections following, nothing changed; ties among rules),
`spec/refresh_pipeline_spec.lua` ("keeps an item added by hand to a category of yours there"),
`spec/next/merchant_spec.lua` (the vendor's copy), `spec/next/settings/categories_spec.lua` (the list,
dragging and dropping, a filter), `spec/next/settings/reorder_spec.lua` (the shared drag). 37 mutations
for the order, the list and the drag, and 2 for the vendor: four first survived and led to tests or
removed dead code; two are equivalent (the drop's check that the anchor is not the dragged category,
whose every case ends in no move anyway; clearing the dragged name after a drop).

## 8. Ignored Items: items a category never takes

Asked (2026-10-22): "a new tab next to 'Added Items' called 'Ignored Items', same interface/layout as
Added Items, but items in this are *ignored* from the category and never land in there under any
circumstance, no matter if it's added in Added Items, or in a Search Filter." docs/next-batch-2.md §2.

- **Stored on the category** as `ignoredItems = { [itemID] = true }` (none: no field). Yours in its saved
  filter (`customCategoryFilters[name]`, so renaming and deleting carry it as they carry the rest); a
  plugin's in its saved state (`ephemeralCategoryFilters[name]`, `saveState`, restored by
  `CreateCategory` and `DB:CreateOrUpdateCategory` when the plugin makes it again), the player's choice
  as its color is.
- **API** (`data/categories.lua`): `IgnoreItem(ctx, itemID, name)`, `UnignoreItem`, `ClearIgnoredItems`
  (each false for a name no category has; each starts a new generation; the bags are the caller's to
  recalculate, as `AddPermanentItemToCategory`'s are), `IgnoresItem(name, itemID)` (a group by's
  sections ignore what their category does; a built-in category ignores nothing), `GetIgnoredItems(name)`
  (a copy).
- **Ignoring wins over everything that gives the category the item:**
  - added by hand, or in a plugin's list: `GetCustomCategory` passes over a category that ignores the
    item, so the item lands where it would without it (an item stays in Added Items while ignored; the
    Added Items tab fades it, "Ignored in this category.");
  - a category function (a plugin's): the item is not filed there, and the next function is asked;
    with none left the item is remembered as having none (`itemsWithNoCategory`), which `UnignoreItem`
    and `ClearIgnoredItems` forget so the function is asked again;
  - a rule: `items:RefreshSearchCache` skips a rule for an item its category ignores, so the next rule
    by priority takes it, else its own category; a group by's sections included (they are their
    category's rule).
- The tab: next-settings-categories.md §5. Coverage: `spec/categories_spec.lua` ("Ignored Items"),
  `spec/database_spec.lua`, `spec/refresh_pipeline_spec.lua` ("Ignored Items (search rules)"),
  `spec/next/settings/categories_spec.lua` ("the Ignored Items tab"), `spec/next/settings/content_spec.lua`,
  `spec/integration/next_settings_spec.lua`.

## 9. Filing an item dropped on a BetterBags Next header

Asked (2026-10-22): "if you drag and drop an item onto a category header, it becomes an Added Item in that
category. if we ever drag an item away back to it's original category, handle the case where we drag it
back to the category but we don't add it to Added Items if it would naturally fit there already, i.e.
if it's a Blizzard defined category, and it would match into that category at that moment in time,
don't add it to Added Items for that category, just strip it's manual assignment and let it land where
it should." docs/next-batch-2.md §8.

- **Where it lands naturally** (`items:NaturalCategory(ctx, data)`): `GetCategory` with Recent Items
  left out and `withoutAdded` (`categories:GetCustomCategory(ctx, kind, data, true)` skips the category
  the item was added to by hand): its rules as this sweep matched them, a plugin's categories, gear
  sets, the built-in categories. Read from the item on the cursor as the bags last read it: its bag
  slot (`C_Cursor.GetCursorItem`), else an item of its ID in the bags, else not known (an equipped
  item).
- **`categories:FileItem(ctx, itemID, name, natural)`**, a group by's sections counting as their
  category on both sides:
  - lands there naturally: the category it was added to by hand is forgotten (`RemoveItemFromCategory`),
    nothing is added: `"natural"`;
  - else a gear set's category (§12): nothing: `"gear set"` (its items are its set's);
  - else a plugin's category: nothing: `"plugin"` (a plugin fills it; adding would make a category of
    yours with its name, hiding the plugin's);
  - else: added to the category's Added Items (`AddPermanentItemToCategory`, which takes it from the
    category it was in), the category no longer ignoring it (§8): `"added"`. A Blizzard category's name
    (one no saved category has) is made yours first (`Convert`, §11), so it shows in the same section; the
    classic title's Shift drop does the same (`sectionFrame:OnTitleClickOrDrop`).
- **The panel** (`panelProto:FileCursorItem`, `next/panel.lua`): for `"gear set"` it says "Gear sets are made in the
  Equipment Manager."; for `"plugin"`, "A plugin fills X: items can't be added to it."; in both the item stays on the
  cursor. Otherwise the item goes back to its slot (`ClearCursor`) and the bags are recalculated
  (`bags/Rederive { resetLayout, buttons }`). So an item of a set added by hand elsewhere, dropped on its set's header,
  goes back to its set (`"natural"`). The classic title's Shift drop (`sectionFrame:OnTitleClickOrDrop`) refuses a gear
  set's title the same way (`categories:IsGearSet`); before §12 it made a category of yours of the set's name.
- Coverage: `spec/categories_spec.lua` ("filing an item dropped on a category's header", "GetCustomCategory
  without the item's Added Items"), `spec/refresh_pipeline_spec.lua` ("an item's natural category"),
  `spec/next/drag_spec.lua` ("the header").

## 10. Hide In: a category kept out of a bag

Asked (issue #1222, 2026-11-01): hiding was retired (§6) because players hid a category and then wondered where its
items went, and tabs do it better; but players who turn tabs off asked for it back. Agreed: a per-bag switch beside Used
In, asking first, and the bag's footer saying how many items are hidden.

- **Stored on the category** as `hidden = { [kind] = true }` (shown everywhere: no field). Yours in its saved filter, a
  plugin's in its saved state (`saveState`, restored by `CreateCategory` and `DB:CreateOrUpdateCategory`), as its color is.
- **API:** `categories:UpdateCategory(ctx, name, { hidden = { [kind] = true|false } })` (the bags named are set, the others
  kept; recalculates the bags, with `categories/Changed`) and `categories:HiddenIn(name, kind)` (a group by's sections as
  their category; a built-in category is never hidden, and neither is a category in a bag that does not use it: §11).
- **Different from Used In:** off, a category does not apply in that bag and its items fall through to what they would be
  otherwise; hidden, they are its items and nothing shows them. A category not used in a bag has nothing to hide there, so
  its switch is off (`SetEnabled`).
- **Where it applies** (`Phase10_PartitionIntoTabs`): an item whose shown category is hidden in the kind leaves its tab's
  `items`, so it has no cell and its category no section, for either design. Its gap goes too. Its tab counts it
  (`tabData.hiddenItems`, by the tab it belongs to, gaps and free slots not counted). Nothing else changes: it keeps its
  data, its search entry and its slot.
- **What still shows it:** Recent Items while it is new (its shown category is Recent Items, so a player sees what they
  looted), and the Show Bags view, whose sections are bags.
- **What still acts on it:** Auto Sell that does not confirm reads categories, not sections (automation.md §2). A confirming
  sale is offered only with a section in the backpack's view (automation.md §4a), so a hidden category is not offered.
- **The footer:** BetterBags Next's free slots line ends " · N hidden" (`panelProto:Draw`, for the tab shown); the classic
  bags write "N hidden" on the footer bar, left of the money (`bagProto:ShowHiddenCount`). **Known limit:** on the classic
  backpack in a narrow window, with many currency icons, it can run over them: the bar has no room rule.
- **The switch:** a row of the Settings tab, "Hide In", next-settings-categories.md §5.
- **Coverage:** `spec/categories_spec.lua`, `spec/database_spec.lua`, `spec/refresh_pipeline_spec.lua` ("hiding a category in
  a bag"), `spec/next/bag_spec.lua`, `spec/frames/bag_draw_ownership_spec.lua`, `spec/next/settings/categories_spec.lua`
  ("hiding it in a bag").

## 11. Blizzard categories, and making one yours (issue #1278)

The issue: categories BetterBags builds from Blizzard's item data ("Junk", "Armor - Cloth", an equipment slot,
"Everything") never showed on the Categories page, so a player could only change one by first dragging an item onto
it. Asked (2026-11-12): list them, "only for categories currently visible in the backpack", marked as Blizzard's, in
the same scroll list ("it's one big scroll list, not two"); clicking one shows a short explanation and a button that
turns it into a category of the player's, whose Blizzard items keep landing in it.

- **What a Blizzard category is.** `items:BlizzardCategory(data)` names the items no category of the player's or a
  plugin's takes: Junk for poor quality, else the equipment slot, else type, subtype, trade skill and expansion as the
  bag's filters say (§5). `items:BuiltInCategory(data)` is where such an item shows: that name, or Everything for an
  ignored one (below). `items:GetCategory` falls through to it. The Categories page lists a backpack section as a
  Blizzard category when the items it shows are where `BuiltInCategory` puts them and no category has the name
  (next-settings-categories.md §5).
- **A Blizzard category groups nothing.** A longer Blizzard name ("Consumable - Potion") is never a section of a
  shorter one ("Consumable"), converted or not: the page's and the category picker's `isShownIn` take the "name - ..."
  prefix only for a category of that name that is not `blizzard`.
- **Converting** (`categories:Convert(ctx, name)`): makes a saved category with that exact name, marked
  `blizzard = true`, with no rule and no items, on top of the order (like any new category, §7). Since a section and
  its settings are found by name, Blizzard's items keep landing in it and take its color, Hide In, automation and so
  on. It returns false for a name a category already has. Like `CreateCategory`, it leaves recalculating the bags to the
  caller. The Categories page's button, an item dropped on a Blizzard header in BetterBags Next (`FileItem`, §9) and
  the classic title's Shift drop all convert this way, so there is one kind of converted category however it was
  made. Categories a player made by dropping onto a Blizzard header before this change are not marked (nothing at load
  can tell them apart); they behave as ordinary categories.
- **It never groups** (asked: "disable group by on Blizzard converted categories ... including on search strings! we
  just ignore the group clause"). The Settings tab hides Group By for one, and `normalizeRule` (`DB:NormalizeCategories`,
  every load) strips a trailing "group by <word>" clause from its rule without setting `groupBy`, and never copies the
  group by a plugin left in its rule (`searchCategory.groupBy`, the old place) onto it. The data never holds a
  group by for one, so the runtime group-by readers (`GroupedCategory`, `RefreshSearchCache`, the vendor) are unchanged.
- **Ignored Items go to Everything** (asked: "yes, send to everything"). An item a converted category ignores has no
  other Blizzard category to fall to, so `BuiltInCategory` sends it to "Everything" (what BetterBags names an item with
  no category) when the category of its Blizzard name, used in its bag, ignores it. Items the category takes by its rule
  or Added Items are passed over as for any category (§8) and then reach this check too.
- **Named after a Blizzard category, a category is a converted one** (asked: "naming something onto a blizzard name
  should work as a converted one"). A Blizzard category's name is one Blizzard's data gives an item in the bags read
  (`items:KnowsBlizzardCategory(name)`: `BlizzardCategory` of every item read, whatever section shows it now, the
  backpack's, the bank's once opened, the guild bank's). `CreateCategory` marks a new category of yours (`save`, not a
  plugin's) with such a name `blizzard` and drops its group by: New Category, Enter to Make Category, the picker's new
  category, a plugin adding an item to a new saved category. `RenameCategory` sets `blizzard` by the new name: renamed
  onto one it becomes converted (its group by dropped; the page asks first when it groups), renamed away from one it
  becomes ordinary.
- **Renaming makes an ordinary category** (asked: "accept with a warning that it's making a new category
  technically"), unless the new name is a Blizzard category's (above); Blizzard's items stay in the Blizzard section of
  the old name. The rename dialog says so. Pins and tab assignments move with the rename (`DB:RenameCategory`), as for
  any category.
- **A category of yours becomes converted when Blizzard's data starts giving items its name** (asked, of a name not
  known when the category was made: "the thing we need to make sure is we have uniform behavior ... i would prefer
  hidden changes to non-uniform behavior"). Phase 6 keeps each item's Blizzard name with its own category
  (`derived.blizzard`, worked out again only when the own category is: data-loader.md §18). Once a read commits (Phase
  11, before `items/Refresh<Kind>/Done`), `categories:ConvertNamed(ctx, names)` gets the set of those names. Each saved
  category of yours with one of them that is not converted yet becomes converted: `blizzard = true`, its group by
  dropped and its group by's sections forgotten (`forgetSections`: in memory, saved, and their pins and tabs). A
  change starts a new generation, sends `categories/Changed` and queues one `bags/Rederive { resetLayout, buttons }`
  (requests made during a read wait their turn: refresh-scheduler.md). So a Blizzard name always means a converted
  category, whether the name was known when the category was made or learned later; the cost of the uniform rule is
  that a Group By the player set can be turned off without asking when it happens on a read (on Rename the page asks).
  An item read before its data loaded names no Blizzard category (its expansion reads 0: data-loader.md §19), here and
  in `KnowsBlizzardCategory`, so a wrong name never converts a category. Cost (not measured in game): one more
  `BlizzardCategory` call per item whose own category is worked out again (none on a `categoriesUnchanged` derive),
  and one pass over the committed items per read with a lookup per distinct name.
- **Coverage of naming and converting on sight:** `spec/categories_spec.lua` (made, renamed, `ConvertNamed` with its
  sections forgotten), `spec/refresh_pipeline_spec.lua` (`KnowsBlizzardCategory`; the names a read hands over, held
  items included, kept, worked out again with the filters, none read cold), `spec/database_migration_spec.lua` (the
  rule's old group by), `spec/next/settings/categories_spec.lua` (the rename question).
- **Deleting** turns it back into a Blizzard category. The delete scrub (§2) also clears the pins and tab assignment
  saved under its name, which the Blizzard section had before converting.
- **Whether a bag uses a category decides everything it does there** (asked: "we don't want dual behavior for
  options"). A converted category turned off in a bag leaves that bag's section of its name to Blizzard: no color, no
  Hide In, no automation, no Ignored Items. `categories:CategoryIn(name, kind)` is the one lookup: the category of that
  name (a group by's section resolves to its category) while `enabled[kind]` is on, else nil. `AutomationOf`,
  `SkipsRecentOf`, `HiddenIn`, `ConfirmsSaleOf`, `DepositOf` and `ItemOrderOf` (item-sort.md §5) take `(name, kind)` and
  go through it; the classic
  sections' color (`views.lua` `GetOrCreateSection`, the view's kind) and the ignore check above do too. Automation
  passes the backpack's kind (it acts on backpack items only). For a category that is not converted nothing changes:
  items only land in it in bags that use it. The Categories page counts an item under a category only in bags that use
  it (next-settings-categories.md §5).
- **The page:** next-settings-categories.md §5.
- **Coverage:** `spec/categories_spec.lua` ("CategoryIn", "Blizzard categories made yours (Convert)", "does nothing in a
  bag that does not use the category", FileItem), `spec/refresh_pipeline_spec.lua` ("an item a category of its Blizzard
  category's name ignores", BuiltInCategory against a real read), `spec/database_migration_spec.lua` (the group by
  clause), `spec/automation_spec.lua` ("asks what a category does in the backpack"), `spec/views/views_spec.lua` (a
  section's color per bag), `spec/frames/bag_draw_ownership_spec.lua` (the classic Shift drop),
  `spec/next/categorypicker_spec.lua` (a converted category's exact name), and the page's specs.
- **Reviews** (CLAUDE.md, Prime Directive #2). The first found a deleted or renamed category shown as Blizzard's until
  the bags were recalculated, and a converted category counting longer Blizzard names; the second, piles a merged stack
  hides listed, Everything never listed, and unconverted Blizzard rows counting longer names. All fixed test-first.
  New Category, the picker's new category and renaming onto a Blizzard category's name used to make an unmarked
  category; the user chose converting them (above).

## 12. Gear sets are categories (issue #1333)

The issue: `items:GetCategory` returned `"Gear: " .. equipmentSets[1]` right after Recent Items, before every category,
so an item in an equipment set stayed in its set whatever it was added to by hand (its Added Items row faded, "Shows in
Gear: X instead.") or matched by a rule, even a rule at the top of the order (a rule `category = 'gear:'` matched set
items and still lost). Reproduced against the real Items and Search modules before the fix. Asked (2026-11-15): "gear
categories are treated as special hard coded things, it's time we undo the hard coding and make them function like
other categories correctly"; the bag's Equipment Set switch stays; a set's category follows a rename of its set, "so
long as we can't rename the category in BetterBags"; no Auto Sell or Auto Deposit rows for one. How it is saved, asked
after two rejected designs (settings per character, pointers to categories): "no pointers, everything goes in the global
profile. it's keyed by the id of the gear set ... if the user renames or moves something on one character, it affects
the other -- the user should make individual profiles. sloppy, but for now it's the right thing"; and a set this
character deletes is forgotten: "we just watch the event".

- **What the client does with set IDs** (measured on WoW: Forever 1.60.1, five `/bbdb` captures, data-driven.md
  "Equipment sets and their IDs"): IDs start at 0 and stay the same across reloads; a rename keeps the ID; deleting set 0
  did not renumber 1 and 2; the next new set reused the freed 0; `GetEquipmentSetIDs` lists sets in the order they were
  made, not by ID ([1, 2, 0] after the reuse). Retail and other characters were not captured.
- **Saved in the profile, by set ID** (`profile.gearSets[setID]`, a `GearSetRecord`: `DB:GetGearSet`, `SetGearSet`,
  `UpdateGearSet`, `RenameGearSet`, `DeleteGearSet`). A record holds what the player set for the set's category (Used
  In, color, place in the order, Hide In, Ignored Items, item order, Skip Recent Items, and the automation fields, which
  nothing sets for one) and the name it last had, `"Gear: " .. setName`. Its pins and tabs are saved under that name, as
  every category's are (`customSectionSort`, `categoryToGroup`). Every character of the profile shares a set ID's
  record: character B's set 0 takes the category character A gave its set 0. Separate profiles keep characters apart.
  Nothing is saved as a plugin's (`ephemeralCategoryFilters`): `saveState` writes a gear set's settings to its record.
- **In memory** (`categories:SyncGearSets(ctx, sets)`, called by `EquipmentSets:Update(ctx)` after it reads the sets,
  so at the start of every sweep, before the items get their categories, data-loader.md §14, and at its `OnEnable`):
  for each of this character's sets, a category named `"Gear: " .. setName`, marked with its set's ID (`gearSet`), made
  from its record (`gearSetsByID`). `EquipmentSets:GetSets()` lists `{ id, name }` per set in the client's order, leaving
  out a set the client gives no name (`GetEquipmentSetInfo` may return nothing: `MayReturnNothing`,
  EquipmentManagerDocumentation.lua); none on Vanilla and Anniversary, whose `Update` returns early.
  `categories:IsGearSet(name)` says whether a name is one (a category of yours of that name is not). Nothing changes,
  and no generation starts, when the sets are the same; otherwise a new generation and one `categories/Changed`.
- **A set with no record is new**: its record is made (`newGearSetRecord`), used in every bag, and its category goes on
  top of the order (§7), so after the update gear sets still come before every rule until the player moves one. They are
  made from the client's last set to its first, so the first ends on top and an item in two sets still shows in the
  first by default, as it always did.
- **Renamed** (in the Equipment Manager, or on another character of the profile whose set has the ID; Blizzard's rename
  keeps the set's ID: `C_EquipmentSet.ModifyEquipmentSet(setID, name, icon)`, `PaperDollFrame.lua`): a set whose name
  differs from its record's. Its settings stay with the ID; its pins and tabs move to the new name only when they are
  its own: no other category has the old name (`gearSetOwns`; a category of yours of that name, made since on another
  character, keeps its own), and no other set's saved settings use the old or the new name, as the records are or as
  this sweep's renames leave them (`sharedName`; asked: a rename moves them "only when no other set's saved settings use
  either name"; "messy, but do it"). Pins and tabs are kept by name, so a name two sets use (sets of one name under
  different IDs on two characters) keeps its own: moved on every login, A's (0 "DPS", 1 "Tank") Tank pin was written
  over by B's (0 "Tank") rename DPS to Tank and taken away again by A's rename back. In that case they do not follow the
  rename. Renames are worked out together (`categories:renameGearSets`, `DB:RenameGearSets`): two
  characters of the profile whose sets have each other's names under their IDs swap them at every switch, so a name
  another set is leaving this sweep is free (their pins and tabs stay with the names). A category in memory
  is renamed in place, and `categories/Changed` names both, as `RenameCategory` does, so the Categories page keeps it
  chosen, shown or not (next-settings-categories.md §5). A rename made while BetterBags was not loaded is found the same
  way. A set renamed onto a name another category has gets no category and its record stays as it was, until the name
  is free; its items go to that category meanwhile (below).
- **Deleted on this character** (`EquipmentSets:SetsChanged`, from `EQUIPMENT_SETS_CHANGED`; asked: "we just watch the
  event"): once the client says its sets changed, the next `Update` takes a set the last one read and this one does not
  for one this character deleted, and `categories:ForgetGearSets(ctx, ids)` forgets it before the sync: its record; its
  pins and tabs when its name is its own (`gearSetOwns`) and no other set's saved settings use it (`sharedName`, as for
  a rename: another character's set of the name keeps its pin); the older entry its record was copied from (`older`, kept
  through renames) unless a category of yours or a plugin's now has that name (another gear set's never reads the
  entry under its name); and its category in memory (asked: "deleted should mean
  deleted"; `DB:DeleteGearSet(id, bags, older)`). An entry the set never copied is left alone. So a set the client later
  gives the freed ID, or one made again under either name, starts fresh, on top. On a shared profile this also clears
  that ID's settings for other characters, and the older entry for another character's set of that name that has no
  record yet (older versions' entries hold only Used In).
- **Skipped, never deleted:** a record of a set this character does not have (another character's), and a set no longer
  listed without the client saying its sets changed: its category leaves memory, its record stays. One case the reads
  cannot tell apart: a set deleted and another made that the client gives its ID, both before the next sweep, reads as a
  rename (the new set takes the old one's settings).
- **Older profiles.** Older versions saved gear sets' sections as dynamic categories by name (`test.lua`: `"Gear: Tank"`,
  `"Gear: Ret"` with `dynamic = true` and no place), and the build before this one saved gear set categories by name as
  plugins' (`ephemeralCategoryFilters`). A set with no record copies what was saved under its category's name into its
  record (`newGearSetRecord`, which names the entry it copied: `older`; asked: "the first time the set has no record"),
  on top unless it had a place. Those entries
  are left alone: not loaded (`categories:OnEnable` skips a dynamic `"Gear: "` entry but a group by's sections:
  `isOlderGearSet`), not changed (the record holds copies), and deleted only with their set, by the player (above), so a
  set made again under the name starts fresh.
- **A set another category is named after** (yours, or a plugin's) gets no category and no record; that category is
  the set's (issue #1368; asked 2026-11-18: give the set's items to the category of its name). `gearSetOf` takes it for
  a set whose name no gear set category has: the bag's Equipment Set switch, the category's Used In and its Ignored
  Items apply as for a set's category, and it competes by the order as a set's would; only an item added to it by hand
  stays whatever the rules (`GetCustomCategory`'s `added`, §6). Why: older versions labeled a set's items
  `"Gear: " .. setName` ahead of every category, so a category of yours of that name (made by hand to style the
  section, a rule named after it, or made by the classic Shift title drop on the set's header) held every item of the
  set. The first build of this design sent them where they would go without a set, so such a rule's
  `category = "Gear: X"` matched nothing and a bare set name matched only item names (reproduced on the real modules
  over `test.lua`, the build before #1333 against this one). The category stays yours: it is renamed, deleted and
  exported as yours, and has Added Items; deleting it gives the set a category of its own at the next sweep. When yours
  and a plugin's both have the name, yours takes the items, as `GetCategoryByName` (the section's settings) reads yours.
  Not built for (the review's, not seen): a set whose `"Gear: "` name is a group by's section of another category
  (a set "Tank - Armor" beside your "Gear: Tank" grouped by type) puts its items in that section, whose own Ignored
  Items are empty, so the parent's do not apply to them.
- **Plugins' older calls** (`IsCategoryEnabled`, `ToggleCategory`, `EnableCategory`, `DisableCategory`,
  `SetCategoryState`) answer a gear set's Used In from its category and save it to its record (`setEphemeralEnabled`),
  never to an older entry of its name.
- **Open, the user's to decide** (found by the review of the shared-name rule, reproduced on the real modules over
  `test.lua`): a pin or tab can still be written over. A rename held back leaves the set's pins under its old name, which
  no record has any more (another character's login renamed that set's record), so `sharedName` cannot see it; a later
  rename onto that name moves its pins over them (A: 0 "A", 1 "B"; B: 0 "B", 1 "C"; B renames "C" to "A": A's set 0
  pin is replaced for good). Closing it means not moving pins and tabs onto a name that already has some, which narrows
  when they follow a rename further, so it was asked, not built.
- **Follows from the rule as asked:** a record of a set no character has any more (a character left the profile, a set
  deleted while BetterBags was not loaded) keeps its name in use, so renames from or onto it never move pins and tabs;
  and two renames of one character's sets in one sweep that rotate names (only while BetterBags was not loaded) leave
  the pins with the names, not the sets.
- **Not built for:** two or more renames of sets in memory in one sweep (a swap, a chain) send one `categories/Changed`
  per rename, and the Categories page, following each in turn, ends on the other set's category. Each rename fires its
  own `EQUIPMENT_SETS_CHANGED` and a sweep follows it, so this needs an order not seen.
- **Where its items go** (`categories:GetCustomCategory`): an item added by hand to a category of yours is in it,
  whatever the order (§7). Else its gear set's category (`gearSetOf`: the bag's Equipment Set switch on, the category
  used in the bag, not ignoring the item; for a set with none, the category of yours or the plugin's named after it,
  above; for an item in several sets, the one higher in the order, where before it was always the first set) and a plugin's (`pluginCategoryOf`: its list, else a category function) compete by the order
  (`before`). The winner competes with rules in `items:GetCategory` as a plugin's list does (§6): the lower priority
  number wins, the list on a tie. So a gear set is part of the item's own category, which rules are matched against
  (data-loader.md §8): README's `category = "gear:"` keeps working, and a rule above the set takes its items.
- **The bag's Equipment Set switch** (`filterGearSet`, `GetCategoryFilter(kind, "GearSet")`) still turns gear sets off
  in a bag; each set's Used In narrows it (asked: "this is fine for now").
- **Never renamed here.** `categories:RenameCategory` returns false for one; the Categories page shows no Export, Rename
  or Delete for it (as for a plugin's). Nothing is added to it by hand: `FileItem` returns `"gear set"` (§9), the
  picker lists it disabled, "Made by the Equipment Manager" (next-category-picker.md), and the page has no Added Items
  tab for it.
- **No automation rows.** `Automation:BlockedReason` never sells, destroys or deposits an item in a set
  (`data/automation.lua`), so the Automation tab hides its Merchants and Bank sections for one; Skip Recent Items stays
  (next-settings-categories.md §5). This is also why the old priority is no longer needed: #586 (2024) asked for gear
  sets to beat rules after a player nearly sold set weapons a rule put in a sell category.
- **Not exported.** Export Categories (`DB:ExportSettings`) takes the profile's category tables; `gearSets` is not among
  them.
- **Coverage:** `spec/categories_spec.lua` ("gear sets": made, on top, saved by ID, the same sets, an item's set, Added
  Items winning, a plugin's list and a category function by the order, two sets and the first by default, ignored, Used
  In and the switch, the next session, renamed in game, a record of another name for the ID, deleted, a set this
  character does not have, older entries copied once and left alone, a group by's sections, a category of yours of the
  name, one of yours and a plugin's taking the set's items by the order, a rename onto it, no rename, header drops),
  `spec/equipmentsets_spec.lua` ("the sets' categories": the list, a
  set with no name, deletions only after the event, an ID reused before the next read),
  `spec/debug_dump_harness_spec.lua` (the real Default profile: its older entries, two characters sharing set 0, a
  deletion through the event, the freed ID fresh; a rule and a list of yours named after a set taking its items, the
  profile's rules above the list taking theirs), `spec/database_spec.lua` ("a gear set's category"),
  `spec/refresh_pipeline_spec.lua` ("gear set labeling": Added Items, a rule above and below, a rule's `category`, a
  rule above a category of yours named after the set), `spec/next/merchant_spec.lua` (the vendor's copy of that),
  `spec/next/settings/categories_spec.lua` (the heading and tabs, a renamed category kept chosen),
  `spec/next/settings/content_spec.lua`, `spec/next/categorypicker_spec.lua`, `spec/next/drag_spec.lua` (the header)
  and `spec/frames/bag_draw_ownership_spec.lua` (the classic Shift drop).
- **Review of this design** (CLAUDE.md, Prime Directive #2), reproduced on the real modules over `test.lua`: renames
  applied one at a time wiped one set's pins and tabs when two sets took each other's names; a delete or rename cleared
  or moved the pins and tabs of a category of yours that had the record's name; the older plugin calls read and wrote a
  gear set's Used In in an older entry; the remaking of a category deleted another way had no test. All fixed
  test-first. The older entry copied again after a deletion: the user chose "deleted should mean deleted" (above); its
  review found a set renamed after copying leaving the copied entry behind, and deleting by the current name taking an
  entry the set never copied, fixed test-first by naming the copied entry in the record; and the one after it, the
  copied entry kept when another gear set had taken its name (after a swap, in one order of deletion), fixed
  test-first. Records made by the build before `older` existed (only a developer's saved variables) delete no older
  entry. The second, aimed at those
  fixes, found `DB:RenameCategory` unchanged (the old move fuzzed against take-then-put over 200,000 states), two sets
  of one name under different IDs on two characters losing a pin (the user chose: pins move only when no other set uses
  either name, above), the page after several
  renames in one sweep (not built for, above), and three untested branches (another category in memory holding a
  record's old name, a name left by another set, the retail bank's per-bank-type tabs), now each caught by a test.
- **Reviews** (CLAUDE.md, Prime Directive #2), of the build before this design (by name, renames followed in memory):
  an item in two sets showing in the client's last; the Categories page losing a renamed set's category (hidden or not);
  a group by's section named "Gear: ..." taken for an older gear set category; a set with no name failing every sweep;
  older categories taken over at no place falling below rules. All fixed test-first and kept. Its cross-character
  finding (a saved set ID taken for another character's set) led to the user's choice above: a set ID is the profile's.
