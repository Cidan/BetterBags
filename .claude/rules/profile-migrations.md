# Profile Migration Rules

This document defines the architecture, design guidelines, and API contracts for saved-variable migrations in `DB:Migrate()` (`core/database.lua`).

## Architectural Guidelines

### 1. Defaults Are Already Merged Before Migrate Runs
`DB:OnInitialize` creates the database with `LibStub('AceDB-3.0'):New(addonName .. 'DB', const.DATABASE_DEFAULTS, true)` and then calls `DB:Migrate()`. AceDB's `initSection` runs `copyDefaults(tbl, defaults)` on the first access of `db.profile`, which is `Migrate`'s own first statement. For every table-valued default key, `copyDefaults` does `if not rawget(dest, k) then rawset(dest, k, {}) end` and recurses, so any key present in `DATABASE_DEFAULTS` but absent from the saved profile is *created before migration code can look at it*.
- **Rule:** A migration must never infer anything about the saved data from the presence, absence, or shape of a key that `DATABASE_DEFAULTS` declares. By the time it runs, that key reflects the defaults, not the player's file.
- **Worked example:** `const.BAG_KIND.BACKPACK` is `0`, and pre-scoping profiles stored `profile.groups` as a flat map keyed by group ID starting at `1`, so key `0` never existed in saved data. The kind-scoping migration decided "already converted" by testing whether `profile.groups[BACKPACK]` was a namespace. AceDB had just created it from the new defaults, so the test passed for every legacy profile in existence: the conversion was skipped, its completion flag was set, and the player's groups plus their `categoryToGroup` assignments were left at the top level where no accessor reads them.
- **Corollary:** `removeDefaults` runs on logout and deletes any value equal to its default, so absence from a `SavedVariables` file also proves nothing about what was in memory. A group identical to the default backpack group disappears from disk entirely.

### 2. Repair Passes Are Idempotent and Unflagged
A one-shot flag cannot repair the profiles a buggy one-shot pass already flagged, and the flag is written before anyone knows whether the conversion was correct.
- **Rule:** Data-shape conversions run on every load and are written so that a converted profile is a no-op, rather than being gated on a `__migrated` marker.
- **Mechanism:** `migrateFlatGroupData()` (local to `core/database.lua`, called unconditionally from `DB:Migrate`) collects legacy entries, moves them, and clears their old keys. Re-running it finds nothing to collect.
- **Consequence:** Completion markers become dead weight. `__groupsScopedByKind` and `__bankDefaultTabsFixed` are now deleted from the profile by `Migrate` instead of being set.
- **Ordering:** Widen scalar-to-table fields (`groupCounter`) *before* the pass, since re-homing allocates IDs from them.

### 3. Discriminate Shapes by Fields the Shape Owns
- **Rule:** Tell two data shapes apart using fields that only one shape can have, never by container keys that defaults or unrelated writes could produce.
- **Contract:** `isFlatGroup(value)` reports a legacy group object by testing for `name`, `id`, or `order` directly on the value. A kind namespace maps group IDs to groups and so never carries those fields, whichever key it sits under.

### 4. Bag Kind Keys Overlap Legacy IDs
`BAG_KIND.BACKPACK` is `0` and `BAG_KIND.BANK` is `1`, and legacy group IDs start at `1`. A pre-scoping profile can therefore hold a group object at the exact key that now means "the bank namespace".
- **Rule:** Collect every legacy entry before rewriting any container key, and only clear a top-level key when it is not itself a bag kind key.
- **Failure mode this prevents:** the `hasBank` scan in `DB:Migrate` iterates `pairs(profile.groups[BAG_KIND.BANK])` and reads `group.isDefault`. When that key holds a group object, the scan walks the group's own field *values* and errors with `attempt to index a number value` on the first numeric field.

### 5. Merge Into Scoped Data, Never Replace It
Players keep using the addon after a failed conversion, so a profile can hold both stale flat values and newer scoped ones for the same category.
- **Rule:** A conversion fills gaps in the scoped table and leaves existing entries alone; it does not overwrite them and does not reassign the container.
- **Contract:** `migrateFlatGroupData` writes `categoryToGroup[kind][name]` only when it is `nil`. A scoped assignment can only have been made after the flat one was orphaned, so it is the newer of the two.

### 6. Keep ID Counters Ahead of Re-Homed Data
`DB:CreateGroup` allocates `groupCounter[kind] + 1`, so a counter that lags behind a re-homed group hands out an ID that is already in use.
- **Rule:** After moving anything keyed by an auto-incremented ID, raise the counter to the highest ID in use for that kind.
- **Contract:** When a re-homed group's original ID is taken, `migrateFlatGroupData` allocates a fresh ID from the counter and rewrites the `categoryToGroup` entries that referenced the old one, so no assignment is orphaned by the move.

## Testing Contract
Migration behavior is covered by `spec/database_migration_spec.lua`, which loads the real `DB:Migrate` (it does **not** stub it) and drives `DB.data.profile` directly. A migration change needs cases for: the legacy shape, the shape a previously-broken migration left behind, an already-converted profile, and a second `DB:Migrate()` call proving the pass is idempotent.
