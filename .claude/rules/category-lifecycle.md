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
  (automation.md). `itemList` is empty here: the plugin gives its items again each session.
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
pane (since replaced by the category manager, next-settings.md §5, which lists what is pinned the same
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

A bag's Categories tab (`next/settings/bagcategories.lua`, next-settings.md §5; before it the
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
`DB:ImportSettings`; it changes nothing a second time):
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
also only won ties). A category with a group by shows a hand-placed
item in its sub-category for the item (`items:GroupedCategory`), made as for rule matches
(`items:ensureSubcategory`: the same bags, color and priority).

**Where it is edited**: the Categories page defines categories; each bag's Categories tab arranges
them (next-settings.md §5). The search box's Enter to Make Category opens the Categories page with
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
  category. The Categories page's list shows it (next-settings.md §5) and the rules are tried in it
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
  gave it, else its own; a category made again, and a group by's section, keep theirs.
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
- The tab: next-settings.md §5. Coverage: `spec/categories_spec.lua` ("Ignored Items"),
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
  - else a plugin's category: nothing: `"plugin"` (a plugin fills it; adding would make a category of
    yours with its name, hiding the plugin's);
  - else: added to the category's Added Items (`AddPermanentItemToCategory`, which takes it from the
    category it was in), the category no longer ignoring it (§8): `"added"`. A built-in category's name
    gets a category of yours with that name, which shows in the same section, as the classic title's
    Shift drop always made one.
- **The panel** (`panelProto:FileCursorItem`, `next/panel.lua`): a gear set's section ("Gear: ", no
  category of that name) takes nothing ("Gear sets are made in the Equipment Manager."); a plugin's
  says "A plugin fills X: items can't be added to it."; in both the item stays on the cursor.
  Otherwise the item goes back to its slot (`ClearCursor`) and the bags are recalculated
  (`bags/Rederive { resetLayout, buttons }`).
- **Known limit:** an item in a gear set shows in its gear set whatever it is added to: gear sets come
  first in `GetCategory`, before any category (as on the classic bags).
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
  their category; a built-in category is never hidden).
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
- **The switch:** a row of the Settings tab, "Hide In", next-settings.md §5.
- **Coverage:** `spec/categories_spec.lua`, `spec/database_spec.lua`, `spec/refresh_pipeline_spec.lua` ("hiding a category in
  a bag"), `spec/next/bag_spec.lua`, `spec/frames/bag_draw_ownership_spec.lua`, `spec/next/settings/categories_spec.lua`
  ("hiding it in a bag").
