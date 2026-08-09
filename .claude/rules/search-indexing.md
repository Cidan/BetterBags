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
