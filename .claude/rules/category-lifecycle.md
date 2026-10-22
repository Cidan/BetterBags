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
true; the partition no longer drops "hidden" categories.

**Resolution** (`items:GetCategory`, and the vendor's copy in `next/merchant.lua`): a rule's match
and an item placed by hand compete by priority, the lower number winning; at equal priority the item
stays where it was placed (before, the rule won ties). A category with a group by shows a hand-placed
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
