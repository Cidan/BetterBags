# Custom Category Lifecycle & Orphan Prevention

This document defines the invariants for creating, renaming, and **deleting** BetterBags
custom categories, and how orphaned categories are prevented and healed.

## 1. Category storage is spread across many side tables

A custom category's name is a key in **multiple** independent profile tables (`core/database.lua`):

- `customCategoryFilters[name]` — persistent categories (`save = true`). The authoritative
  filter. `GetItemCategory` / `GetAllItemCategories` read this.
- `ephemeralCategoryFilters[name]` — persisted-but-ephemeral categories (`save = false`),
  including dynamic (`dynamic = true`) and groupBy sub-categories (`"Parent - Suffix"`,
  `isGroupBySubcategory = true`). `itemList` is emptied here.
- `customCategoryIndex[itemID] = name` — per-item assignment for persistent categories.
- `categoryToGroup[kind][name]` (and, on retail bank, `categoryToGroup[kind][groupID][name]`)
  — tab/group assignment.
- `categoryOptions[name]` — `{ shown = … }` visibility.
- `customSectionSort[kind][name] = index` — the config "Pinned" ordering.

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

**Failure mode (the "undeletable dynamic category" bug):** the config Categories pane's
`categoryPaneProto:LoadPinnedItems` (`config/categorypane.lua`) inserts **every**
`customSectionSort[kind]` entry into the list with no existence check. A deleted-but-still-pinned
category therefore reappears forever under "Pinned". Selecting it makes
`categoryPaneProto:UpdateDetailPanel` call `GetCategoryByName` → `nil` → it falls through to
`ShowDynamicCategoryDetail`, which showed "This is a dynamic category. It cannot be edited or
deleted." with no delete button and no item list — so the user could neither delete it nor see
its (non-existent) contents. It is **self-perpetuating**: `UpdatePinnedItems` rebuilds
`customSectionSort` from the current list, re-persisting the ghost every time the pane is
touched. Coverage: `spec/database_spec.lua` ("DeleteItemCategory scrubs pinned sort, options,
and group for all kinds", "…scrubs grouped sub-categories from side tables").

## 3. Self-heal existing corrupted profiles

`DB:PruneOrphanedSectionSort()` (called once from `DB:Migrate`) removes every
`customSectionSort[kind]` entry whose name exists in **neither** `customCategoryFilters` **nor**
`ephemeralCategoryFilters` — i.e. a delete-orphan. Valid persistent and persisted-ephemeral
(dynamic/groupBy) pins are keyed by a real store entry and are preserved. Coverage:
`spec/database_spec.lua` ("PruneOrphanedSectionSort drops pins with no backing category…").

## 4. UI escape hatch for any unfindable category

`categoryPaneProto:ShowDynamicCategoryDetail` now carries a **"Remove Category"** button that
calls `categories:DeleteCategory` on the selected name. Because `GetCategoryByName == nil` is
the only route into that panel and genuine in-memory dynamic/groupBy categories are *findable*
(they route to the manual/search panels instead), everything reaching this panel is effectively
an orphan or a persisted-but-unloaded ephemeral — both are safe to scrub. This covers the
sub-case a migration prune cannot (a non-dynamic ephemeral pin still present in
`ephemeralCategoryFilters` but never reloaded into memory by the `if category.dynamic` guard in
`categories:OnEnable`). Do **not** drop that reload guard to "fix" this — it intentionally keeps
transient non-dynamic ephemerals out of the list; the correct levers are the delete/prune
scrub (§2, §3) and this removal button.

## 5. Built-in category names, and settings that follow a renamed one

Items no custom or search category claims are named by `items:GetCategory`
(`data/items.lua`) from the enabled filters, joined with " - ": item type, subtype,
trade skill, expansion. Their settings live in the same side tables as a custom category's
(§1), keyed by that name: `categoryOptions` (hidden), `categoryToGroup` (tab/group),
`customSectionSort` (pinned order).

- **A subtype equal to its type is not repeated** (issue #183). Quest items are type
  "Quest" and subtype "Quest", and with Type and Subtype on they read "Quest - Quest"; the
  subtype is now skipped when it equals the type added before it, so they read "Quest"
  (or "Quest - Classic" with Expansion). The subtype alone (Type off) is unchanged.
- **Renaming a built-in category moves its settings.** `DB:RenameRepeatedTypeCategories`
  (run from `DB:Migrate`, before `PruneOrphanedSectionSort`) moves `categoryOptions` and
  `categoryToGroup[kind]` entries (including the retail bank's per-bank-type tables) from a
  name that repeated its type to the current name. It skips custom and persisted-ephemeral
  categories (a user may have named one "X - X"), keeps a setting already saved under the
  current name, and ignores legacy name = group entries at the top level of
  `categoryToGroup` (left by profiles from before groups were split by bag kind; nothing
  reads them). It is idempotent: once renamed, no name repeats its type.
- Pinned order is not moved: `PruneOrphanedSectionSort` (§3) drops the pins of every
  built-in category on every load (open issue #1107), so there is nothing to carry over.
  Any future change to how `GetCategory` composes names needs the same kind of migration.

Coverage: `spec/items_spec.lua` ("Category names from type and subtype (issue #183)") and
`spec/database_migration_spec.lua` ("category names that repeated their item type"; each guard
was mutation-tested).
