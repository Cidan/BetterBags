# Search Indexing and Clean-Sweep Optimization Rules

This document defines the architecture, design guidelines, and API contracts for search indexing within BetterBags.

## Architectural Guidelines

### 1. Unidirectional, Clean-Sweep Indexing (State Independence)
Historically, the search engine indexes were updated incrementally via imperative `search:Add(currentItem)` and `search:Remove(previousItem)` calls inside the main database update loops. This introduced state desynchronization, ghost index entries, and complex circular dependencies.
- **Rule:** Search indexing is state-independent and resolved cleanly from scratch (clean sweep) on every database context update.
- **Mechanism:** The entire search index is wiped via `search:Wipe()` and completely rebuilt from the latest flat visible items model using `search:IndexItems(currentItems)` inside the refresh pipeline.

### 2. Zero-Tooltip-Scanning Overhead on Unchanged Items
- **Rule:** Wiping the index and rebuilding from scratch must remain computationally cheap and prevent redundant tooltip scanning.
- **Optimization:** We decouple heavy text extraction from the indexing loop. Tooltips are scanned during the data-farming phase (Phase 2), caching the results inside `itemInfo.tooltipText`. The search engine simply indexes the cached strings without invoking the WoW client API, keeping the entire indexing loop synchronous and instant.

### 3. API Contract and Lookup Support
- **Wipe:** Wipes all indexed data fields (ngrams, numbers, bools, and fullText indices).
- **IndexItems:** The entry point for the clean-sweep indexing.
  ```lua
  local search = addon:GetModule('Search')
  search:IndexItems(currentItems)
  ```
- **Downward Compatibility:** The search engine fully supports legacy matching and query execution APIs (`search:Search()`, `search:EvaluateQuery()`, `search:isInIndex()`, and `search:DefaultSearch()`), ensuring no downstream views, filters, or dynamic category rules are broken.

### 4. Single Global Index Shared by Both Bags (Cross-Kind Clean Sweep)
There is exactly **one** search index (`search.indicies`), and it is shared by the backpack and the bank. Because `search:IndexItems` is a clean sweep (`search:Wipe()` followed by re-adding), the "latest flat visible items model" it is handed must be the **complete cross-kind model**, not a single bag's items. Indexing only one kind evicts the other bag from the global index.
- **Failure Mode (bank-only search filtering everything):** `items:ProcessRefresh` runs per kind, and a full refresh (`data/refresh.lua:RequestUpdate`) processes the **bank first and the backpack second**. If `Phase8_EnrichCategories` indexes only the current kind's `itemData`, the backpack's clean sweep wipes the bank's freshly-indexed entries. The live search box (`frames/search.lua:UpdateSearch` -> `search:Search(text)` -> `bag:Search`) then evaluates against a global index that contains only backpack slotkeys, so every bank item resolves to `found = false` and the bank appears to filter out all items for any query. Only the bank breaks, because it is never the last kind indexed. See `spec/refresh_pipeline_spec.lua` ("keeps both bags searchable in the shared global index after a full refresh").
- **Rule:** In `Phase8_EnrichCategories`, build the index from this kind's fresh `itemData` **unioned with the other kind's last-committed `slotInfo[otherKind].itemsBySlotKey`**, then call `search:IndexItems(combinedItems)`. The current kind uses its fresh, not-yet-committed data; the other kind uses its committed data (it committed earlier in the same frame for a full refresh, or on a previous refresh otherwise). This keeps both bags present in the global index after every refresh.
- **Why per-kind computations are unaffected:** The `isSearchResult` loop only reads `searchResults[currentItem.slotkey]` for this kind's `itemData`, and `RefreshSearchCache` writes/reads `searchCache[kind][slotkey]` only, while `GetCategory` reads `searchCache[data.kind][data.slotkey]` for the item's own kind. A cross-kind slotkey therefore can never be read back through the wrong kind, so widening the index to both bags does not change category resolution — it only restores live search.
