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
- `collapsedSections[kind][name]` — collapse state.
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
and `customCategoryIndex`, leaving `customSectionSort`, `categoryOptions`, `collapsedSections`
and `categoryToGroup` behind.

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
collapse, and group for all kinds", "…scrubs grouped sub-categories from side tables").

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
