# Search Indexing and Clean-Sweep Optimization Rules

This document defines the architecture, design guidelines, and API contracts for search indexing within BetterBags.

## Architectural Guidelines

### 1. Unidirectional, Clean-Sweep Indexing (State Independence)
Historically, the search engine indexes were updated incrementally via imperative `search:Add(currentItem)` and `search:Remove(previousItem)` calls inside the main database update loops. This introduced state desynchronization, ghost index entries, and complex circular dependencies.
- **Rule:** Search indexing is state-independent and resolved cleanly from scratch (clean sweep) on every database context update.
- **Mechanism:** The entire search index is wiped via `search:Wipe()` and completely rebuilt from the latest flat visible items model using `search:IndexItems(currentItems)` inside the refresh pipeline.
- **Roadmap:** Re-indexing only changed items is planned but deliberately deferred until the clean-sweep pipeline is bug-free; see `docs/roadmap.md` ("Incremental search indexing") for the constraints it must preserve.

### 2. Zero-Tooltip-Scanning Overhead on Unchanged Items
- **Rule:** Wiping the index and rebuilding from scratch must remain computationally cheap and prevent redundant tooltip scanning.
- **Optimization:** We decouple heavy text extraction from the indexing loop. Tooltips are scanned during the data-farming phase (Phase 2), caching the results inside `itemInfo.tooltipText`. The search engine simply indexes the cached strings without invoking the WoW client API, keeping the entire indexing loop synchronous and instant.

### 2a. The Tooltip Index Is Full-Text Only (No Prefix N-grams)
`search:addStringToIndex` stores two structures per string: `fullText[value]` (the whole lowercased string, used by substring matching) and `ngrams[prefix]` for **every prefix** of the string (used by `=` / `!=` "starts with" matching). Building the prefixes is quadratic in string length (`prefix = prefix .. c`, one new string and one table per character).
- **Failure mode (fixed):** tooltip text is the whole tooltip joined together, commonly 300-600+ characters, and the v0.5.0 clean sweep re-indexes every item of both bags on every sweep (including a one-slot change). The tooltip prefixes were 85-95% of each sweep: in the `test.lua` harness (176-slot backpack, local Lua 5.1) a targeted sweep cost ~24-39 ms at 300-character tooltips and ~54-111 ms at 600, plus tens of MB of garbage per sweep once bank items were also indexed. Users saw 100+ ms hitches from the timer-resumed half of each refresh, and a large spike at login where several full sweeps run back to back.
- **Rule:** an index created with `search:CreateIndex(name, true)` sets `fullTextOnly` and stores **no** prefix n-grams (`addStringToIndex` / `removeStringFromIndex` skip the prefix loop). The `tooltip` index is the only such index. With it, the same sweeps take ~6-14 ms regardless of tooltip length. Short fields (`name`, `type`, `category`, ...) keep their prefix n-grams.
- **Query semantics:** on a `fullTextOnly` index, `isInIndex` (`=`) returns the substring matches from `isFullTextMatch`, and `isNotInIndex` (`!=`) returns the negated set of those matches. This is checked **before** the number/boolean branches, so `tooltip = 70` is a text match, not a numeric lookup. Plain searches (`DefaultSearch`) and `%=` were already substring matches over `fullText` and are unchanged. The old `tooltip = x` meant "the tooltip starts with x", which is effectively a name search, so nothing useful was lost. User docs: `README.md` "Search".
- **Coverage:** `spec/search_spec.lua` ("Tooltip index (full text only)").

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
