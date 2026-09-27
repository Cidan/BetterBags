# BetterBags Roadmap

Planned work that is deliberately deferred. Each item states why it waits and what it has to
preserve when it is picked up.

## Incremental search indexing

**Status:** planned, not started. Deferred until the clean-sweep ("pure") pipeline has had its
remaining bugs worked out, so that any regression can be attributed to one change at a time.

### Today

Every data sweep rebuilds the whole search index from scratch: `items:Phase8_EnrichCategories`
(`data/items.lua`) unions this bag's fresh items with the other bag's last-committed items and
calls `search:IndexItems`, which wipes every index and re-adds every item
(`data/search.lua`). A sweep triggered by a single changed slot therefore re-indexes the whole
backpack, plus the whole bank and warbank once they have been visited this session. This was a
deliberate v0.5.0 choice: v0.4.x updated the index incrementally with `search:Add` /
`search:Remove` per changed slot and suffered from ghost and out-of-sync entries
(see `.claude/rules/search-indexing.md` §1).

The dominant cost of the rebuild was storing every prefix of each item's tooltip text, which is
quadratic in tooltip length. That was removed separately (the tooltip index is now full-text
only), bringing a 176-slot backpack sweep from roughly 24–110 ms down to roughly 6–14 ms in the
local Lua 5.1 benchmark. The rebuild is still proportional to the total number of indexed items
on every sweep, however small the change.

### Goal

Re-index only the items whose indexed data changed in a sweep, and stop re-indexing the other
bag's unchanged items on every sweep, while keeping the index exactly equal to what a clean
rebuild would produce.

### What it has to preserve

- **Equivalence with a clean rebuild.** The incremental index must match `search:IndexItems`
  over the same items after every sweep. A test that runs both over randomized
  add/move/remove/re-categorize sequences and compares the indexes is the acceptance gate.
- **Cross-bag index.** The single global index must keep both bags searchable
  (`.claude/rules/search-indexing.md` §4).
- **Category changes.** `Phase8_EnrichCategories` re-resolves categories after the search cache
  refreshes and updates the category index via `search:UpdateCategoryIndex`; an item whose
  category changes without its slot changing must still be re-indexed.
- **Moves and virtual-stack re-roots.** A slot's contents can change identity (GUID) without the
  slot key changing, and the same item can move between slots in one sweep; removal must use
  the previously indexed values, not the new ones.
- **Full wipes.** Wipe refreshes (`bags/FullRefreshAll`, `BAG_CONTAINER_UPDATE`,
  `EQUIPMENT_SETS_CHANGED`, first load) must still produce a clean index.
